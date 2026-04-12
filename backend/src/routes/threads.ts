import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, desc, sql } from 'drizzle-orm';
import { threads, messages } from '../db/schema.js';
import { NotFoundError, ForbiddenError } from '../lib/errors.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const CreateThreadBody = Type.Object({
  title: Type.String({ minLength: 1, maxLength: 500 }),
});
type CreateThreadBody = Static<typeof CreateThreadBody>;

const ThreadIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});
type ThreadIdParams = Static<typeof ThreadIdParams>;

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function threadRoutes(fastify: FastifyInstance) {
  // ----- GET /threads -----
  fastify.get(
    '/',
    {
      preHandler: [fastify.authenticate],
    },
    async (_request: FastifyRequest, _reply: FastifyReply) => {
      const db = fastify.db;

      // Subquery: latest message per thread
      const lastMsg = db
        .select({
          threadId: messages.threadId,
          content: messages.content,
          senderType: messages.senderType,
          senderId: messages.senderId,
          createdAt: messages.createdAt,
          rn: sql<number>`ROW_NUMBER() OVER (PARTITION BY ${messages.threadId} ORDER BY ${messages.createdAt} DESC)`.as(
            'rn',
          ),
        })
        .from(messages)
        .as('last_msg');

      const rows = await db
        .select({
          id: threads.id,
          title: threads.title,
          isArchived: threads.isArchived,
          createdAt: threads.createdAt,
          createdBy: threads.createdBy,
          lastMessageContent: lastMsg.content,
          lastMessageSenderType: lastMsg.senderType,
          lastMessageSenderId: lastMsg.senderId,
          lastMessageCreatedAt: lastMsg.createdAt,
        })
        .from(threads)
        .leftJoin(
          lastMsg,
          sql`${lastMsg.threadId} = ${threads.id} AND ${lastMsg.rn} = 1`,
        )
        .where(eq(threads.isArchived, false))
        .orderBy(desc(sql`COALESCE(${lastMsg.createdAt}, ${threads.createdAt})`));

      return rows.map((r) => ({
        id: r.id,
        title: r.title,
        isArchived: r.isArchived,
        createdAt: r.createdAt,
        createdBy: r.createdBy,
        lastMessage: r.lastMessageContent
          ? {
              content: r.lastMessageContent,
              senderType: r.lastMessageSenderType,
              senderId: r.lastMessageSenderId,
              createdAt: r.lastMessageCreatedAt,
            }
          : null,
      }));
    },
  );

  // ----- POST /threads -----
  fastify.post<{ Body: CreateThreadBody }>(
    '/',
    {
      preHandler: [fastify.authenticate],
      schema: { body: CreateThreadBody },
    },
    async (request, reply) => {
      const db = fastify.db;
      const { title } = request.body;

      const [thread] = await db
        .insert(threads)
        .values({
          title,
          createdBy: request.user.id,
        })
        .returning();

      return reply.status(201).send(thread);
    },
  );

  // ----- POST /threads/:id/archive -----
  fastify.post<{ Params: ThreadIdParams }>(
    '/:id/archive',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ThreadIdParams },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { id } = request.params;

      const [updated] = await db
        .update(threads)
        .set({ isArchived: true })
        .where(eq(threads.id, id))
        .returning();

      if (!updated) throw new NotFoundError('Thread');

      return { success: true };
    },
  );

  // ----- DELETE /threads/:id (owner only) -----
  fastify.delete<{ Params: ThreadIdParams }>(
    '/:id',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ThreadIdParams },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { id } = request.params;

      // Fetch thread to check ownership
      const [thread] = await db
        .select()
        .from(threads)
        .where(eq(threads.id, id))
        .limit(1);

      if (!thread) throw new NotFoundError('Thread');
      if (thread.createdBy !== request.user.id) {
        throw new ForbiddenError('Only the thread owner can delete it');
      }

      // Hard delete — messages cascade via FK
      await db.delete(threads).where(eq(threads.id, id));

      return { success: true };
    },
  );
}
