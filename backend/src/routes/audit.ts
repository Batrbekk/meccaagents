import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, and, lt, gte, desc, sql } from 'drizzle-orm';
import { auditLog } from '../db/schema.js';
import { ForbiddenError } from '../lib/errors.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const AuditLogQuery = Type.Object({
  actorType: Type.Optional(Type.String({ description: 'Filter by actor type (user, agent, system)' })),
  action: Type.Optional(Type.String({ description: 'Filter by action' })),
  resourceType: Type.Optional(Type.String({ description: 'Filter by resource type' })),
  from: Type.Optional(Type.String({ description: 'ISO 8601 start date (inclusive)' })),
  to: Type.Optional(Type.String({ description: 'ISO 8601 end date (exclusive)' })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 50 })),
  cursor: Type.Optional(
    Type.String({ description: 'ISO 8601 date cursor for pagination (createdAt)' }),
  ),
});
type AuditLogQuery = Static<typeof AuditLogQuery>;

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function auditRoutes(fastify: FastifyInstance) {
  // ----- GET /audit-log (owner only) -----
  fastify.get<{ Querystring: AuditLogQuery }>(
    '/',
    {
      preHandler: [fastify.authenticate],
      schema: { querystring: AuditLogQuery },
    },
    async (request, _reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can view the audit log');
      }

      const db = fastify.db;
      const { actorType, action, resourceType, from, to, cursor, limit: rawLimit } = request.query;
      const limit = rawLimit ?? 50;

      // Build conditions
      const conditions = [];

      if (actorType) {
        conditions.push(eq(auditLog.actorType, actorType));
      }
      if (action) {
        conditions.push(eq(auditLog.action, action));
      }
      if (resourceType) {
        conditions.push(eq(auditLog.resourceType, resourceType));
      }
      if (from) {
        conditions.push(gte(auditLog.createdAt, new Date(from)));
      }
      if (to) {
        conditions.push(lt(auditLog.createdAt, new Date(to)));
      }
      if (cursor) {
        conditions.push(lt(auditLog.createdAt, new Date(cursor)));
      }

      const where =
        conditions.length === 0
          ? undefined
          : conditions.length === 1
            ? conditions[0]
            : and(...conditions);

      const rows = await db
        .select()
        .from(auditLog)
        .where(where)
        .orderBy(desc(auditLog.createdAt))
        .limit(limit + 1);

      const hasMore = rows.length > limit;
      const result = hasMore ? rows.slice(0, limit) : rows;
      const nextCursor =
        hasMore && result.length > 0
          ? result[result.length - 1]!.createdAt.toISOString()
          : null;

      return { entries: result, nextCursor };
    },
  );
}
