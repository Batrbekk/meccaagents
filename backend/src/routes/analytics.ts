import type { FastifyInstance } from 'fastify';
import { sql } from 'drizzle-orm';
import { agentConfigs, toolLogs, messages, threads, approvalTasks } from '../db/schema.js';

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function analyticsRoutes(fastify: FastifyInstance) {
  // ----- GET /analytics/agents -----
  fastify.get(
    '/agents',
    {
      preHandler: [fastify.authenticate],
    },
    async (_request, _reply) => {
      const db = fastify.db;
      const redis = fastify.redis;

      // Fetch all agent configs
      const configs = await db.select().from(agentConfigs).orderBy(agentConfigs.slug);

      const now = new Date();
      const todayStart = new Date(now);
      todayStart.setUTCHours(0, 0, 0, 0);
      const todayISO = todayStart.toISOString();

      const weekStart = new Date(now);
      weekStart.setUTCDate(weekStart.getUTCDate() - 7);
      const weekISO = weekStart.toISOString();

      // Aggregate tool_logs stats per agent in a single query
      const statsRows = await db
        .select({
          agentSlug: toolLogs.agentSlug,
          totalCalls: sql<number>`count(*)::int`,
          callsToday: sql<number>`count(*) filter (where ${toolLogs.createdAt} >= ${todayISO}::timestamptz)::int`,
          callsThisWeek: sql<number>`count(*) filter (where ${toolLogs.createdAt} >= ${weekISO}::timestamptz)::int`,
          avgDurationMs: sql<number>`coalesce(avg(${toolLogs.durationMs}), 0)::real`,
          errorCount: sql<number>`count(*) filter (where ${toolLogs.status} = 'error')::int`,
        })
        .from(toolLogs)
        .groupBy(toolLogs.agentSlug);

      // Aggregate pending approvals per agent
      const pendingRows = await db
        .select({
          agentSlug: approvalTasks.agentSlug,
          pendingApprovals: sql<number>`count(*)::int`,
        })
        .from(approvalTasks)
        .where(sql`${approvalTasks.status} = 'pending'`)
        .groupBy(approvalTasks.agentSlug);

      // Index maps for fast lookup
      const statsMap = new Map(statsRows.map((r) => [r.agentSlug, r]));
      const pendingMap = new Map(pendingRows.map((r) => [r.agentSlug, r.pendingApprovals]));

      // Build response, enriching each agent with Redis status and stats
      const agents = await Promise.all(
        configs.map(async (config) => {
          const status = (await redis.get(`agent:status:${config.slug}`)) ?? 'idle';
          const s = statsMap.get(config.slug);
          const totalCalls = s?.totalCalls ?? 0;

          return {
            slug: config.slug,
            displayName: config.displayName,
            isActive: config.isActive,
            status,
            stats: {
              totalCalls,
              callsToday: s?.callsToday ?? 0,
              callsThisWeek: s?.callsThisWeek ?? 0,
              avgDurationMs: Math.round(s?.avgDurationMs ?? 0),
              errorRate: totalCalls > 0 ? Number(((s?.errorCount ?? 0) / totalCalls).toFixed(4)) : 0,
              pendingApprovals: pendingMap.get(config.slug) ?? 0,
            },
          };
        }),
      );

      return { agents };
    },
  );

  // ----- GET /analytics/overview -----
  fastify.get(
    '/overview',
    {
      preHandler: [fastify.authenticate],
    },
    async (_request, _reply) => {
      const db = fastify.db;

      // Total messages
      const [msgCount] = await db
        .select({ count: sql<number>`count(*)::int` })
        .from(messages);

      // Total threads
      const [threadCount] = await db
        .select({ count: sql<number>`count(*)::int` })
        .from(threads);

      // Total approvals
      const [approvalCount] = await db
        .select({ count: sql<number>`count(*)::int` })
        .from(approvalTasks);

      // Approvals by status
      const approvalsByStatusRows = await db
        .select({
          status: approvalTasks.status,
          count: sql<number>`count(*)::int`,
        })
        .from(approvalTasks)
        .groupBy(approvalTasks.status);

      const approvalsByStatus: Record<string, number> = {};
      for (const row of approvalsByStatusRows) {
        approvalsByStatus[row.status] = row.count;
      }

      // Messages per day for last 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setUTCDate(sevenDaysAgo.getUTCDate() - 7);
      sevenDaysAgo.setUTCHours(0, 0, 0, 0);
      const sevenDaysISO = sevenDaysAgo.toISOString();

      const messagesLast7Days = await db
        .select({
          date: sql<string>`to_char(${messages.createdAt}::date, 'YYYY-MM-DD')`,
          count: sql<number>`count(*)::int`,
        })
        .from(messages)
        .where(sql`${messages.createdAt} >= ${sevenDaysISO}::timestamptz`)
        .groupBy(sql`${messages.createdAt}::date`)
        .orderBy(sql`${messages.createdAt}::date`);

      // Top agents by usage (tool calls count)
      const topAgentsByUsage = await db
        .select({
          slug: toolLogs.agentSlug,
          calls: sql<number>`count(*)::int`,
        })
        .from(toolLogs)
        .groupBy(toolLogs.agentSlug)
        .orderBy(sql`count(*) desc`)
        .limit(10);

      return {
        totalMessages: msgCount?.count ?? 0,
        totalThreads: threadCount?.count ?? 0,
        totalApprovals: approvalCount?.count ?? 0,
        approvalsByStatus,
        messagesLast7Days,
        topAgentsByUsage,
      };
    },
  );
}
