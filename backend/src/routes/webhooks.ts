import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { eq } from 'drizzle-orm';
import { threads, messages, integrations } from '../db/schema.js';
import { decrypt } from '../lib/crypto.js';
import { publish } from '../lib/pubsub.js';
import {
  verifyMetaSignature,
  verify360DialogSignature,
  checkReplayProtection,
} from '../lib/webhook-verify.js';
import { WhatsAppClient } from '../tools/whatsapp.js';
import { enqueueAgentJob } from '../workers/agent-runner.js';
import { logger } from '../lib/logger.js';

// ── Raw body capture ────────────────────────────────────────────────────
declare module 'fastify' {
  interface FastifyRequest {
    rawBody?: string;
  }
}

// ── Credential helpers ──────────────────────────────────────────────────

interface WhatsAppAccount {
  id: string;
  label: string | null;
  apiKey: string;
}

interface InstagramCredentials {
  appSecret: string;
  verifyToken: string;
}

/**
 * Load ALL active WhatsApp accounts from the DB.
 */
async function getAllWhatsAppAccounts(
  fastify: FastifyInstance,
): Promise<WhatsAppAccount[]> {
  const accounts: WhatsAppAccount[] = [];

  try {
    const rows = await fastify.db
      .select({
        id: integrations.id,
        label: integrations.label,
        credentials: integrations.credentials,
      })
      .from(integrations)
      .where(eq(integrations.service, 'whatsapp'));

    for (const row of rows) {
      try {
        const parsed = JSON.parse(decrypt(row.credentials)) as { apiKey?: string };
        if (parsed.apiKey) {
          accounts.push({
            id: row.id,
            label: row.label,
            apiKey: parsed.apiKey,
          });
        }
      } catch { /* skip invalid */ }
    }
  } catch { /* DB error */ }

  // Fallback to env
  if (accounts.length === 0) {
    const envKey = process.env.WHATSAPP_API_KEY;
    if (envKey) {
      accounts.push({ id: 'env', label: 'Default', apiKey: envKey });
    }
  }

  return accounts;
}

async function getInstagramCredentials(
  fastify: FastifyInstance,
): Promise<InstagramCredentials> {
  try {
    const [row] = await fastify.db
      .select({ credentials: integrations.credentials })
      .from(integrations)
      .where(eq(integrations.service, 'instagram'))
      .limit(1);

    if (row) {
      const parsed = JSON.parse(decrypt(row.credentials)) as InstagramCredentials;
      if (parsed.appSecret) return parsed;
    }
  } catch {
    // fall through to env vars
  }

  return {
    appSecret: process.env.META_APP_SECRET ?? '',
    verifyToken: process.env.META_VERIFY_TOKEN ?? '',
  };
}

// ── Thread upsert helper ────────────────────────────────────────────────

async function findOrCreateThread(
  fastify: FastifyInstance,
  channel: string,
  externalId: string,
): Promise<string> {
  const title = `${channel}: ${externalId}`;

  const [existing] = await fastify.db
    .select({ id: threads.id })
    .from(threads)
    .where(eq(threads.title, title))
    .limit(1);

  if (existing) return existing.id;

  const [created] = await fastify.db
    .insert(threads)
    .values({ title })
    .returning({ id: threads.id });

  return created!.id;
}

// ── Plugin ──────────────────────────────────────────────────────────────

export default async function webhookRoutes(fastify: FastifyInstance) {
  // Capture raw body for signature verification
  fastify.addHook(
    'preParsing',
    async (request: FastifyRequest, _reply: FastifyReply, payload) => {
      const chunks: Buffer[] = [];
      for await (const chunk of payload as AsyncIterable<Buffer>) {
        chunks.push(chunk);
      }
      const raw = Buffer.concat(chunks).toString('utf8');
      request.rawBody = raw;

      const { Readable } = await import('node:stream');
      return Readable.from([raw]);
    },
  );

  // ================================================================
  // POST /webhooks/whatsapp
  // Try all WhatsApp accounts to find the matching one by signature
  // ================================================================
  fastify.post(
    '/whatsapp',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const accounts = await getAllWhatsAppAccounts(fastify);

      const signature = (request.headers['x-signature'] as string) ?? '';
      const rawBody = request.rawBody ?? JSON.stringify(request.body);

      // Find the account whose API key matches the signature
      let matchedAccount: WhatsAppAccount | null = null;
      for (const account of accounts) {
        if (verify360DialogSignature(rawBody, signature, account.apiKey)) {
          matchedAccount = account;
          break;
        }
      }

      if (!matchedAccount) {
        logger.warn('WhatsApp webhook: no matching account for signature');
        return reply.status(401).send({ error: 'Invalid signature' });
      }

      // ── Parse incoming message ────────────────────────────────────
      const parsed = WhatsAppClient.parseIncoming(request.body);
      if (!parsed) {
        return reply.status(200).send({ status: 'ignored' });
      }

      // ── Replay protection ─────────────────────────────────────────
      const isNew = await checkReplayProtection(
        fastify.redis,
        parsed.messageId,
        Math.floor(parsed.timestamp.getTime() / 1000),
      );

      if (!isNew) {
        logger.debug({ messageId: parsed.messageId }, 'WhatsApp duplicate event — skipping');
        return reply.status(200).send({ status: 'duplicate' });
      }

      // ── Persist ───────────────────────────────────────────────────
      const accountLabel = matchedAccount.label ?? 'WhatsApp';
      const threadId = await findOrCreateThread(
        fastify,
        `WhatsApp (${accountLabel})`,
        `+${parsed.from}`,
      );

      const content = parsed.text ?? `[${parsed.type}]`;
      const [savedMessage] = await fastify.db
        .insert(messages)
        .values({
          threadId,
          senderType: 'user',
          senderId: parsed.from,
          content,
          metadata: {
            channel: 'whatsapp',
            whatsappAccountId: matchedAccount.id,
            whatsappAccountLabel: matchedAccount.label,
            externalMessageId: parsed.messageId,
            contactName: parsed.name ?? null,
            mediaUrl: parsed.mediaUrl ?? null,
            messageType: parsed.type,
          },
        })
        .returning();

      // ── Broadcast via Redis Pub/Sub ───────────────────────────────
      if (savedMessage) {
        await publish(`thread:${threadId}:messages`, {
          id: savedMessage.id,
          threadId: savedMessage.threadId,
          senderType: savedMessage.senderType,
          senderId: savedMessage.senderId,
          content: savedMessage.content,
          metadata: savedMessage.metadata,
          status: savedMessage.status,
          parentMessageId: savedMessage.parentMessageId,
          createdAt: savedMessage.createdAt,
        });
      }

      // ── Trigger Sales agent ───────────────────────────────────────
      await enqueueAgentJob({
        threadId,
        agentSlug: 'sales',
        userMessage: content,
        triggeredBy: 'whatsapp-webhook',
      });

      return reply.status(200).send({ status: 'ok' });
    },
  );

  // ================================================================
  // POST /webhooks/instagram
  // ================================================================
  fastify.post(
    '/instagram',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const creds = await getInstagramCredentials(fastify);

      const signature = (request.headers['x-hub-signature-256'] as string) ?? '';
      const rawBody = request.rawBody ?? JSON.stringify(request.body);

      if (!creds.appSecret || !verifyMetaSignature(rawBody, signature, creds.appSecret)) {
        logger.warn('Instagram webhook: invalid signature');
        return reply.status(401).send({ error: 'Invalid signature' });
      }

      const body = request.body as Record<string, unknown>;
      const entries = (body.entry ?? []) as Array<Record<string, unknown>>;

      for (const entry of entries) {
        // ── Direct Messages ───────────────────────────────────────
        const messagingEvents = (entry.messaging ?? []) as Array<Record<string, unknown>>;
        for (const event of messagingEvents) {
          const sender = event.sender as Record<string, string> | undefined;
          const message = event.message as Record<string, unknown> | undefined;
          if (!sender?.id || !message) continue;

          const msgId = message.mid as string;
          const text = (message.text as string) ?? '';
          const eventTimestamp = event.timestamp as number | undefined;

          const isNew = await checkReplayProtection(
            fastify.redis,
            msgId,
            eventTimestamp ? Math.floor(eventTimestamp / 1000) : undefined,
          );
          if (!isNew) continue;

          const threadId = await findOrCreateThread(
            fastify,
            'Instagram DM',
            sender.id,
          );

          const [saved] = await fastify.db
            .insert(messages)
            .values({
              threadId,
              senderType: 'user',
              senderId: sender.id,
              content: text || '[media]',
              metadata: {
                channel: 'instagram_dm',
                externalMessageId: msgId,
              },
            })
            .returning();

          if (saved) {
            await publish(`thread:${threadId}:messages`, {
              id: saved.id,
              threadId: saved.threadId,
              senderType: saved.senderType,
              senderId: saved.senderId,
              content: saved.content,
              metadata: saved.metadata,
              status: saved.status,
              parentMessageId: saved.parentMessageId,
              createdAt: saved.createdAt,
            });
          }

          await enqueueAgentJob({
            threadId,
            agentSlug: 'sales',
            userMessage: text || '[media]',
            triggeredBy: 'instagram-dm-webhook',
          });
        }

        // ── Comments ────────────────────────────────────────────────
        const changes = (entry.changes ?? []) as Array<Record<string, unknown>>;
        for (const change of changes) {
          if (change.field !== 'comments') continue;

          const value = change.value as Record<string, unknown> | undefined;
          if (!value) continue;

          const commentId = value.id as string | undefined;
          const commentText = value.text as string | undefined;
          const from = value.from as Record<string, string> | undefined;

          if (!commentId || !from?.id) continue;

          const isNew = await checkReplayProtection(fastify.redis, commentId);
          if (!isNew) continue;

          const threadId = await findOrCreateThread(
            fastify,
            'Instagram Comment',
            from.id,
          );

          const [saved] = await fastify.db
            .insert(messages)
            .values({
              threadId,
              senderType: 'user',
              senderId: from.id,
              content: commentText ?? '[comment]',
              metadata: {
                channel: 'instagram_comment',
                externalCommentId: commentId,
                commenterName: from.name ?? null,
              },
            })
            .returning();

          if (saved) {
            await publish(`thread:${threadId}:messages`, {
              id: saved.id,
              threadId: saved.threadId,
              senderType: saved.senderType,
              senderId: saved.senderId,
              content: saved.content,
              metadata: saved.metadata,
              status: saved.status,
              parentMessageId: saved.parentMessageId,
              createdAt: saved.createdAt,
            });
          }

          await enqueueAgentJob({
            threadId,
            agentSlug: 'smm',
            userMessage: commentText ?? '[comment]',
            triggeredBy: 'instagram-comment-webhook',
          });
        }
      }

      return reply.status(200).send({ status: 'ok' });
    },
  );

  // ================================================================
  // GET /webhooks/instagram  (Meta verification challenge)
  // ================================================================
  fastify.get(
    '/instagram',
    async (
      request: FastifyRequest<{
        Querystring: {
          'hub.mode'?: string;
          'hub.challenge'?: string;
          'hub.verify_token'?: string;
        };
      }>,
      reply: FastifyReply,
    ) => {
      const mode = request.query['hub.mode'];
      const challenge = request.query['hub.challenge'];
      const token = request.query['hub.verify_token'];

      if (mode !== 'subscribe' || !challenge || !token) {
        return reply.status(400).send({ error: 'Missing verification parameters' });
      }

      const creds = await getInstagramCredentials(fastify);

      if (token !== creds.verifyToken) {
        logger.warn('Instagram webhook verification: token mismatch');
        return reply.status(403).send({ error: 'Invalid verify token' });
      }

      return reply.type('text/plain').send(challenge);
    },
  );
}
