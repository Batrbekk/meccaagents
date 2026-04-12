import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, desc, lt, and } from 'drizzle-orm';
import { agentConfigs, toolLogs } from '../db/schema.js';
import { NotFoundError, ForbiddenError } from '../lib/errors.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const AgentSlugParams = Type.Object({
  slug: Type.String({ minLength: 1 }),
});
type AgentSlugParams = Static<typeof AgentSlugParams>;

const UpdateConfigBody = Type.Object({
  systemPrompt: Type.Optional(Type.String()),
  model: Type.Optional(Type.String()),
  temperature: Type.Optional(Type.Number({ minimum: 0, maximum: 2 })),
  tools: Type.Optional(Type.Array(Type.Unknown())),
  isActive: Type.Optional(Type.Boolean()),
});
type UpdateConfigBody = Static<typeof UpdateConfigBody>;

const LogsQuery = Type.Object({
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 50 })),
  cursor: Type.Optional(
    Type.String({ description: 'ISO 8601 date cursor for pagination (createdAt)' }),
  ),
});
type LogsQuery = Static<typeof LogsQuery>;

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function agentRoutes(fastify: FastifyInstance) {
  // ----- GET /agents -----
  fastify.get(
    '/',
    {
      preHandler: [fastify.authenticate],
    },
    async (_request, _reply) => {
      const db = fastify.db;
      const redis = fastify.redis;

      const configs = await db.select().from(agentConfigs).orderBy(agentConfigs.slug);

      // Enrich each agent config with its live status from Redis
      const agents = await Promise.all(
        configs.map(async (config) => {
          const status = (await redis.get(`agent:status:${config.slug}`)) ?? 'idle';
          return { ...config, status };
        }),
      );

      return { agents };
    },
  );

  // ----- GET /agents/:slug/config -----
  fastify.get<{ Params: AgentSlugParams }>(
    '/:slug/config',
    {
      preHandler: [fastify.authenticate],
      schema: { params: AgentSlugParams },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { slug } = request.params;

      const [config] = await db
        .select()
        .from(agentConfigs)
        .where(eq(agentConfigs.slug, slug))
        .limit(1);

      if (!config) throw new NotFoundError('Agent config');

      return config;
    },
  );

  // ----- PUT /agents/:slug/config (owner only) -----
  fastify.put<{ Params: AgentSlugParams; Body: UpdateConfigBody }>(
    '/:slug/config',
    {
      preHandler: [fastify.authenticate],
      schema: { params: AgentSlugParams, body: UpdateConfigBody },
    },
    async (request, _reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can update agent configs');
      }

      const db = fastify.db;
      const { slug } = request.params;
      const { systemPrompt, model, temperature, tools, isActive } = request.body;

      // Build the SET clause dynamically so we only update provided fields
      const updates: Record<string, unknown> = { updatedAt: new Date() };
      if (systemPrompt !== undefined) updates.systemPrompt = systemPrompt;
      if (model !== undefined) updates.model = model;
      if (temperature !== undefined) updates.temperature = temperature;
      if (tools !== undefined) updates.tools = tools;
      if (isActive !== undefined) updates.isActive = isActive;

      const [updated] = await db
        .update(agentConfigs)
        .set(updates)
        .where(eq(agentConfigs.slug, slug))
        .returning();

      if (!updated) throw new NotFoundError('Agent config');

      return updated;
    },
  );

  // ----- GET /agents/:slug/logs -----
  fastify.get<{ Params: AgentSlugParams; Querystring: LogsQuery }>(
    '/:slug/logs',
    {
      preHandler: [fastify.authenticate],
      schema: { params: AgentSlugParams, querystring: LogsQuery },
    },
    async (request, _reply) => {
      const db = fastify.db;
      const { slug } = request.params;
      const { cursor, limit: rawLimit } = request.query;
      const limit = rawLimit ?? 50;

      // Build conditions
      const conditions = [eq(toolLogs.agentSlug, slug)];
      if (cursor) {
        conditions.push(lt(toolLogs.createdAt, new Date(cursor)));
      }

      const where = conditions.length === 1 ? conditions[0]! : and(...conditions);

      const rows = await db
        .select()
        .from(toolLogs)
        .where(where)
        .orderBy(desc(toolLogs.createdAt))
        .limit(limit + 1);

      const hasMore = rows.length > limit;
      const result = hasMore ? rows.slice(0, limit) : rows;
      const nextCursor =
        hasMore && result.length > 0
          ? result[result.length - 1]!.createdAt.toISOString()
          : null;

      return { logs: result, nextCursor };
    },
  );
}
