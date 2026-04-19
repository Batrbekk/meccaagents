import { Queue, Worker } from 'bullmq';
import { Redis } from 'ioredis';
import { Client as MinioClient } from 'minio';
import { drizzle } from 'drizzle-orm/postgres-js';
import { desc, eq } from 'drizzle-orm';
import postgres from 'postgres';
import * as schema from '../db/schema.js';
import { messages } from '../db/schema.js';
import { publish } from '../lib/pubsub.js';
import { logger } from '../lib/logger.js';
import { OrchestratorAgent } from '../agents/orchestrator.js';
import { ContentAgent } from '../agents/content.js';
import { SalesAgent } from '../agents/sales.js';
import { SMMAgent } from '../agents/smm.js';
import { LawyerAgent } from '../agents/lawyer.js';
import type { BaseAgent } from '../agents/base-agent.js';
import type { AgentJobData } from '../agents/types.js';

// ── Redis connection for BullMQ ──────────────────────────────────────
const redisUrl = process.env.REDIS_URL;
if (!redisUrl) throw new Error('REDIS_URL is required for agent-runner worker');

const connection = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  enableReadyCheck: true,
  retryStrategy: (times: number) => Math.min(times * 200, 5000),
});

// ── Database connection ──────────────────────────────────────────────
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error('DATABASE_URL is required for agent-runner worker');

const sql = postgres(databaseUrl, { max: 10 });
const db = drizzle(sql, { schema });

// ── MinIO client for generating presigned URLs ──────────────────────
const minio = new MinioClient({
  endPoint: process.env.MINIO_ENDPOINT ?? 'minio',
  port: Number(process.env.MINIO_PORT ?? 9000),
  useSSL: false,
  accessKey: process.env.MINIO_ROOT_USER ?? 'minioadmin',
  secretKey: process.env.MINIO_ROOT_PASSWORD ?? 'changeme',
});
const MINIO_BUCKET = process.env.MINIO_BUCKET ?? 'agentteam-files';

// ── Load integration keys from DB into env (same as app.ts) ─────────
try {
  const { decrypt } = await import('../lib/crypto.js');
  const integrationRows = await sql`SELECT service, credentials FROM integrations WHERE is_active = true`;
  for (const row of integrationRows) {
    try {
      const creds = JSON.parse(decrypt(row.credentials));
      if (row.service === 'openrouter' && creds.apiKey) {
        process.env.OPENROUTER_API_KEY = creds.apiKey;
        logger.info('Worker: Loaded OpenRouter API key from DB');
      }
      if (row.service === 'notion' && creds.integrationToken) {
        process.env.NOTION_TOKEN = creds.integrationToken;
      }
    } catch { /* skip invalid */ }
  }
} catch (err) {
  logger.warn({ err }, 'Worker: Failed to load integration keys from DB');
}

// ── BullMQ Queue ─────────────────────────────────────────────────────
const QUEUE_NAME = 'agent-run';

export const agentQueue = new Queue<AgentJobData>(QUEUE_NAME, {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: { count: 1000 },
    removeOnFail: { count: 500 },
  },
});

// ── Helper: enqueue an agent job ─────────────────────────────────────
export async function enqueueAgentJob(data: AgentJobData): Promise<void> {
  await agentQueue.add('run', data, {
    // Deduplicate by threadId + agentSlug within a short window
    jobId: `${data.threadId}:${data.agentSlug}:${Date.now()}`,
  });
  logger.info({ agentSlug: data.agentSlug, threadId: data.threadId }, 'Agent job enqueued');
}

// ── Agent registry ───────────────────────────────────────────────────

/**
 * Resolve an agent class instance by slug.
 * As new agents are created, add them here.
 */
function resolveAgent(slug: string): BaseAgent {
  switch (slug) {
    case 'orchestrator':
      return new OrchestratorAgent();
    case 'content':
      return new ContentAgent();
    case 'sales':
      return new SalesAgent();
    case 'smm':
      return new SMMAgent();
    case 'lawyer':
      return new LawyerAgent();
    default:
      throw new Error(`Unknown agent slug: ${slug}`);
  }
}

// ── Dedicated Redis connection for status updates ────────────────────
// BullMQ's connection is reserved; use a separate one for SET/PUBLISH.
const statusRedis = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  enableReadyCheck: true,
  retryStrategy: (times: number) => Math.min(times * 200, 5000),
});

async function setAgentStatus(slug: string, status: 'thinking' | 'idle'): Promise<void> {
  await statusRedis.set(`agent:status:${slug}`, status);
  // Also publish status change for real-time UI updates
  await publish('agent:status', { agent: slug, status });
}

// ── BullMQ Worker ────────────────────────────────────────────────────

export const agentWorker = new Worker<AgentJobData>(
  QUEUE_NAME,
  async (job) => {
    const { threadId, agentSlug, userMessage, triggeredBy } = job.data;

    logger.info(
      { jobId: job.id, agentSlug, threadId, triggeredBy },
      'Processing agent job',
    );

    const agent = resolveAgent(agentSlug);

    try {
      // 1. Set agent status to thinking
      await setAgentStatus(agentSlug, 'thinking');

      // 2. Load last 20 messages from the thread as context (including metadata for files)
      const recentMessages = await db
        .select({
          senderType: messages.senderType,
          senderId: messages.senderId,
          content: messages.content,
          metadata: messages.metadata,
          createdAt: messages.createdAt,
        })
        .from(messages)
        .where(eq(messages.threadId, threadId))
        .orderBy(desc(messages.createdAt))
        .limit(20);

      // Reverse to chronological order and build context with file support
      const chronological = recentMessages.reverse().filter((m) => m.content != null);

      // Only load images for the LAST user message with files (to avoid context bloat)
      let lastUserWithFilesIdx = -1;
      for (let i = chronological.length - 1; i >= 0; i--) {
        const meta = chronological[i]!.metadata as Record<string, unknown> | null;
        const files = (meta?.files as Array<Record<string, unknown>> | undefined) ?? [];
        if (chronological[i]!.senderType === 'user' && files.some((f) => ((f.mimeType as string) || '').startsWith('image/'))) {
          lastUserWithFilesIdx = i;
          break;
        }
      }

      const context: Array<{
        role: string;
        content: string;
        fileUrls?: Array<{ url: string; mimeType: string; name: string }>;
      }> = [];

      for (let idx = 0; idx < chronological.length; idx++) {
        const m = chronological[idx]!;
        const entry: (typeof context)[number] = {
          role: m.senderType === 'user' ? 'user' : 'assistant',
          content: m.content!,
        };

        // Extract file info from metadata
        const meta = m.metadata as Record<string, unknown> | null;
        const metaFiles = (meta?.files as Array<Record<string, unknown>> | undefined) ?? [];

        // Only load actual image data for the last user message with images
        const shouldLoadImages = idx === lastUserWithFilesIdx;

        if (metaFiles.length > 0 && shouldLoadImages) {
          const fileUrls: Array<{ url: string; mimeType: string; name: string }> = [];
          for (const f of metaFiles) {
            const fileId = f.id as string | undefined;
            const name = (f.name ?? f.originalName ?? 'file') as string;
            const mime = (f.mimeType ?? '') as string;

            if (fileId) {
              try {
                const [fileRow] = await db
                  .select({ storagePath: schema.files.storagePath })
                  .from(schema.files)
                  .where(eq(schema.files.id, fileId))
                  .limit(1);

                if (fileRow) {
                  const isImage = mime.startsWith('image/');
                  if (isImage) {
                    // For images: read from MinIO and encode as base64 data URL
                    // (presigned URLs use internal Docker hostname, unreachable by OpenRouter)
                    const chunks: Buffer[] = [];
                    const stream = await minio.getObject(MINIO_BUCKET, fileRow.storagePath);
                    for await (const chunk of stream) {
                      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
                    }
                    const base64 = Buffer.concat(chunks).toString('base64');
                    const dataUrl = `data:${mime};base64,${base64}`;
                    fileUrls.push({ url: dataUrl, mimeType: mime, name });
                  } else {
                    // For non-image files: just describe them (agent can't download anyway)
                    fileUrls.push({ url: `[file:${fileId}]`, mimeType: mime, name });
                  }
                }
              } catch (err) {
                logger.warn({ err, fileId }, 'Failed to load file for agent context');
              }
            }
          }
          if (fileUrls.length > 0) {
            entry.fileUrls = fileUrls;
          }
        }

        context.push(entry);
      }

      // 3. Execute the agent
      const result = await agent.execute({
        db,
        threadId,
        userMessage,
        context,
      });

      // 4. Save the agent's response as a new message
      const [savedMessage] = await db
        .insert(messages)
        .values({
          threadId,
          senderType: 'agent',
          senderId: agentSlug,
          content: result.content,
          metadata: {
            toolCalls: result.toolCalls,
            usage: result.usage,
            triggeredBy: triggeredBy ?? null,
          },
          status: 'sent',
        })
        .returning();

      // 5. Broadcast the message via Redis Pub/Sub
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

      logger.info(
        { jobId: job.id, agentSlug, threadId, tokens: result.usage.totalTokens },
        'Agent job completed',
      );
    } catch (err) {
      logger.error(
        { err, jobId: job.id, agentSlug, threadId },
        'Agent job failed',
      );
      throw err; // Let BullMQ handle retries
    } finally {
      // 6. Reset agent status to idle
      await setAgentStatus(agentSlug, 'idle');
    }
  },
  {
    connection,
    concurrency: 3,
  },
);

// ── Worker events ────────────────────────────────────────────────────

agentWorker.on('completed', (job) => {
  logger.debug({ jobId: job?.id }, 'Agent job completed');
});

agentWorker.on('failed', (job, err) => {
  logger.error({ jobId: job?.id, err: err.message }, 'Agent job failed permanently');
});

agentWorker.on('error', (err) => {
  logger.error({ err }, 'Agent worker error');
});

// ── Graceful shutdown ────────────────────────────────────────────────

async function shutdown() {
  logger.info('Shutting down agent-runner worker...');
  await agentWorker.close();
  await agentQueue.close();
  await statusRedis.quit();
  await connection.quit();
  await sql.end();
  logger.info('Agent-runner worker shut down.');
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

logger.info({ concurrency: 3, queue: QUEUE_NAME }, 'Agent-runner worker started');
