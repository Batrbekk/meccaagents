import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, and, lt, desc } from 'drizzle-orm';
import { messages, threads } from '../db/schema.js';
import { NotFoundError } from '../lib/errors.js';
import { publish } from '../lib/pubsub.js';
import { enqueueAgentJob } from '../workers/agent-runner.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const ThreadIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});
type ThreadIdParams = Static<typeof ThreadIdParams>;

const GetMessagesQuery = Type.Object({
  cursor: Type.Optional(Type.String({ description: 'ISO 8601 date for cursor-based pagination' })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 50 })),
});
type GetMessagesQuery = Static<typeof GetMessagesQuery>;

const CreateMessageBody = Type.Object({
  content: Type.String({ minLength: 1 }),
  metadata: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
  parentMessageId: Type.Optional(Type.String({ format: 'uuid' })),
});
type CreateMessageBody = Static<typeof CreateMessageBody>;

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function messageRoutes(fastify: FastifyInstance) {
  // ----- GET /threads/:id/messages -----
  fastify.get<{ Params: ThreadIdParams; Querystring: GetMessagesQuery }>(
    '/:id/messages',
    {
      preHandler: [fastify.authenticate],
      schema: {
        params: ThreadIdParams,
        querystring: GetMessagesQuery,
      },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { id } = request.params;
      const { cursor, limit: rawLimit } = request.query;
      const limit = rawLimit ?? 50;

      // Verify thread exists
      const [thread] = await db
        .select({ id: threads.id })
        .from(threads)
        .where(eq(threads.id, id))
        .limit(1);

      if (!thread) throw new NotFoundError('Thread');

      // Build conditions
      const conditions = cursor
        ? and(eq(messages.threadId, id), lt(messages.createdAt, new Date(cursor)))
        : eq(messages.threadId, id);

      const rows = await db
        .select()
        .from(messages)
        .where(conditions)
        .orderBy(desc(messages.createdAt))
        .limit(limit + 1); // fetch one extra to determine if there's a next page

      const hasMore = rows.length > limit;
      const result = hasMore ? rows.slice(0, limit) : rows;
      const nextCursor = hasMore && result.length > 0
        ? result[result.length - 1]!.createdAt.toISOString()
        : null;

      return {
        messages: result.map((m) => ({
          id: m.id,
          threadId: m.threadId,
          senderType: m.senderType,
          senderId: m.senderId,
          content: m.content,
          metadata: m.metadata,
          status: m.status,
          parentMessageId: m.parentMessageId,
          createdAt: m.createdAt,
        })),
        nextCursor,
      };
    },
  );

  // ----- POST /threads/:id/messages -----
  fastify.post<{ Params: ThreadIdParams; Body: CreateMessageBody }>(
    '/:id/messages',
    {
      preHandler: [fastify.authenticate],
      schema: {
        params: ThreadIdParams,
        body: CreateMessageBody,
      },
    },
    async (request, reply) => {
      const db = fastify.db;
      const { id } = request.params;
      const { content, metadata, parentMessageId } = request.body;

      // Verify thread exists
      const [thread] = await db
        .select({ id: threads.id })
        .from(threads)
        .where(eq(threads.id, id))
        .limit(1);

      if (!thread) throw new NotFoundError('Thread');

      const [message] = await db
        .insert(messages)
        .values({
          threadId: id,
          senderType: 'user',
          senderId: request.user.id,
          content,
          metadata: metadata ?? {},
          parentMessageId: parentMessageId ?? null,
        })
        .returning();

      // Broadcast via Redis Pub/Sub
      await publish(`thread:${id}:messages`, {
        id: message!.id,
        threadId: message!.threadId,
        senderType: message!.senderType,
        senderId: message!.senderId,
        content: message!.content,
        metadata: message!.metadata,
        status: message!.status,
        parentMessageId: message!.parentMessageId,
        createdAt: message!.createdAt,
      });

      // Trigger the orchestrator agent to process the user message
      await enqueueAgentJob({
        threadId: id,
        agentSlug: 'orchestrator',
        userMessage: content,
      });

      return reply.status(201).send(message);
    },
  );
}
