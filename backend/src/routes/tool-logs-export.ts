import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, and, gte, lt, desc } from 'drizzle-orm';
import { toolLogs } from '../db/schema.js';
import { ForbiddenError } from '../lib/errors.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const ExportQuery = Type.Object({
  agentSlug: Type.Optional(Type.String({ description: 'Filter by agent slug' })),
  toolName: Type.Optional(Type.String({ description: 'Filter by tool name' })),
  status: Type.Optional(Type.String({ description: 'Filter by status (success | error)' })),
  from: Type.Optional(Type.String({ description: 'ISO 8601 start date (inclusive)' })),
  to: Type.Optional(Type.String({ description: 'ISO 8601 end date (exclusive)' })),
});
type ExportQuery = Static<typeof ExportQuery>;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Escape a value for CSV: wrap in quotes if it contains commas, quotes, or newlines. */
function csvEscape(value: string): string {
  if (value.includes(',') || value.includes('"') || value.includes('\n')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function toolLogsExportRoutes(fastify: FastifyInstance) {
  // ----- GET /tool-logs/export (owner only) -----
  fastify.get<{ Querystring: ExportQuery }>(
    '/export',
    {
      preHandler: [fastify.authenticate],
      schema: { querystring: ExportQuery },
    },
    async (request, reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can export tool logs');
      }

      const db = fastify.db;
      const { agentSlug, toolName, status, from, to } = request.query;

      // Build conditions
      const conditions = [];

      if (agentSlug) {
        conditions.push(eq(toolLogs.agentSlug, agentSlug));
      }
      if (toolName) {
        conditions.push(eq(toolLogs.toolName, toolName));
      }
      if (status) {
        conditions.push(eq(toolLogs.status, status));
      }
      if (from) {
        conditions.push(gte(toolLogs.createdAt, new Date(from)));
      }
      if (to) {
        conditions.push(lt(toolLogs.createdAt, new Date(to)));
      }

      const where =
        conditions.length === 0
          ? undefined
          : conditions.length === 1
            ? conditions[0]
            : and(...conditions);

      // Stream CSV via async iteration over batches
      const BATCH_SIZE = 500;
      let cursor: Date | null = null;
      let firstBatch = true;

      reply.raw.writeHead(200, {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': 'attachment; filename="tool-logs.csv"',
        'Transfer-Encoding': 'chunked',
      });

      // CSV header
      reply.raw.write('timestamp,agent,tool,status,duration_ms,error\n');

      // eslint-disable-next-line no-constant-condition
      while (true) {
        // Build per-batch conditions: base filters + cursor
        const batchConditions = where ? [where] : [];
        if (cursor) {
          batchConditions.push(lt(toolLogs.createdAt, cursor));
        }

        const batchWhere =
          batchConditions.length === 0
            ? undefined
            : batchConditions.length === 1
              ? batchConditions[0]
              : and(...batchConditions);

        const rows = await db
          .select({
            createdAt: toolLogs.createdAt,
            agentSlug: toolLogs.agentSlug,
            toolName: toolLogs.toolName,
            status: toolLogs.status,
            durationMs: toolLogs.durationMs,
            errorMessage: toolLogs.errorMessage,
          })
          .from(toolLogs)
          .where(batchWhere)
          .orderBy(desc(toolLogs.createdAt))
          .limit(BATCH_SIZE);

        if (rows.length === 0) break;

        for (const row of rows) {
          const line = [
            csvEscape(row.createdAt.toISOString()),
            csvEscape(row.agentSlug),
            csvEscape(row.toolName),
            csvEscape(row.status),
            String(row.durationMs ?? ''),
            csvEscape(row.errorMessage ?? ''),
          ].join(',');

          reply.raw.write(line + '\n');
        }

        // If we got fewer than BATCH_SIZE rows, we're done
        if (rows.length < BATCH_SIZE) break;

        // Move cursor to the last row's createdAt
        cursor = rows[rows.length - 1]!.createdAt;
        firstBatch = false;
      }

      reply.raw.end();
      // Return reply to signal Fastify we handled the response ourselves
      return reply;
    },
  );
}
