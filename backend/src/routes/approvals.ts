import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, and, lt, desc } from 'drizzle-orm';
import { approvalTasks } from '../db/schema.js';
import { NotFoundError, ForbiddenError } from '../lib/errors.js';
import { logger } from '../lib/logger.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const ApprovalIdParams = Type.Object({
  id: Type.String({ format: 'uuid' }),
});
type ApprovalIdParams = Static<typeof ApprovalIdParams>;

const ListApprovalsQuery = Type.Object({
  status: Type.Optional(
    Type.String({ description: 'Filter by status (pending, approved, rejected, modified)' }),
  ),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 50 })),
  cursor: Type.Optional(
    Type.String({ description: 'ISO 8601 date cursor for pagination (requestedAt)' }),
  ),
});
type ListApprovalsQuery = Static<typeof ListApprovalsQuery>;

const RejectBody = Type.Object({
  notes: Type.Optional(Type.String()),
});
type RejectBody = Static<typeof RejectBody>;

const ModifyBody = Type.Object({
  payload: Type.Record(Type.String(), Type.Unknown()),
  notes: Type.Optional(Type.String()),
});
type ModifyBody = Static<typeof ModifyBody>;

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function approvalRoutes(fastify: FastifyInstance) {
  // ----- GET /approvals -----
  fastify.get<{ Querystring: ListApprovalsQuery }>(
    '/',
    {
      preHandler: [fastify.authenticate],
      schema: { querystring: ListApprovalsQuery },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { status, cursor, limit: rawLimit } = request.query;
      const limit = rawLimit ?? 50;

      // Build conditions array
      const conditions = [];
      if (status) {
        conditions.push(eq(approvalTasks.status, status));
      }
      if (cursor) {
        conditions.push(lt(approvalTasks.requestedAt, new Date(cursor)));
      }

      const where =
        conditions.length === 0
          ? undefined
          : conditions.length === 1
            ? conditions[0]
            : and(...conditions);

      const rows = await db
        .select()
        .from(approvalTasks)
        .where(where)
        .orderBy(desc(approvalTasks.requestedAt))
        .limit(limit + 1);

      const hasMore = rows.length > limit;
      const result = hasMore ? rows.slice(0, limit) : rows;
      const nextCursor =
        hasMore && result.length > 0
          ? result[result.length - 1]!.requestedAt.toISOString()
          : null;

      return { approvals: result, nextCursor };
    },
  );

  // ----- GET /approvals/:id -----
  fastify.get<{ Params: ApprovalIdParams }>(
    '/:id',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ApprovalIdParams },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { id } = request.params;

      const [task] = await db
        .select()
        .from(approvalTasks)
        .where(eq(approvalTasks.id, id))
        .limit(1);

      if (!task) throw new NotFoundError('Approval task');

      return task;
    },
  );

  // ----- POST /approvals/:id/approve (owner only) -----
  fastify.post<{ Params: ApprovalIdParams }>(
    '/:id/approve',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ApprovalIdParams },
    },
    async (request, reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can approve tasks');
      }

      const db = fastify.db;
      const { id } = request.params;

      const [updated] = await db
        .update(approvalTasks)
        .set({
          status: 'approved',
          resolvedAt: new Date(),
          resolvedBy: request.user.id,
        })
        .where(eq(approvalTasks.id, id))
        .returning();

      if (!updated) throw new NotFoundError('Approval task');

      // Return without the heavy payload to avoid serialization issues
      return {
        id: updated.id,
        agentSlug: updated.agentSlug,
        actionType: updated.actionType,
        status: updated.status,
        resolvedAt: updated.resolvedAt,
        resolvedBy: updated.resolvedBy,
        notes: updated.notes,
        requestedAt: updated.requestedAt,
        threadId: updated.threadId,
        messageId: updated.messageId,
      };
    },
  );

  // ----- POST /approvals/:id/reject (owner only) -----
  fastify.post<{ Params: ApprovalIdParams; Body: RejectBody }>(
    '/:id/reject',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ApprovalIdParams, body: RejectBody },
    },
    async (request, _reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can reject tasks');
      }

      const db = fastify.db;
      const { id } = request.params;
      const { notes } = request.body;

      const [updated] = await db
        .update(approvalTasks)
        .set({
          status: 'rejected',
          resolvedAt: new Date(),
          resolvedBy: request.user.id,
          notes: notes ?? null,
        })
        .where(eq(approvalTasks.id, id))
        .returning();

      if (!updated) throw new NotFoundError('Approval task');

      return updated;
    },
  );

  // ----- POST /approvals/:id/modify (owner only) -----
  fastify.post<{ Params: ApprovalIdParams; Body: ModifyBody }>(
    '/:id/modify',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ApprovalIdParams, body: ModifyBody },
    },
    async (request, _reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can modify tasks');
      }

      const db = fastify.db;
      const { id } = request.params;
      const { payload, notes } = request.body;

      const [updated] = await db
        .update(approvalTasks)
        .set({
          payload,
          status: 'modified',
          resolvedAt: new Date(),
          resolvedBy: request.user.id,
          notes: notes ?? null,
        })
        .where(eq(approvalTasks.id, id))
        .returning();

      if (!updated) throw new NotFoundError('Approval task');

      return updated;
    },
  );
}
