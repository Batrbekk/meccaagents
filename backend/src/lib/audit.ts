import { auditLog } from '../db/schema.js';
import { logger } from './logger.js';
import type { DrizzleDB } from '../agents/types.js';

/**
 * Insert an audit-log entry. Fire-and-forget: swallows errors so callers
 * are never blocked by audit failures.
 */
export async function logAudit(
  db: DrizzleDB,
  entry: {
    actorType: 'user' | 'agent' | 'system';
    actorId: string;
    action: string;
    resourceType: string;
    resourceId?: string;
    details?: object;
    ipAddress?: string;
  },
): Promise<void> {
  try {
    await db.insert(auditLog).values({
      actorType: entry.actorType,
      actorId: entry.actorId,
      action: entry.action,
      resourceType: entry.resourceType,
      resourceId: entry.resourceId ?? null,
      details: entry.details ?? null,
      ipAddress: entry.ipAddress ?? null,
    });
  } catch (err) {
    logger.error(err, 'Failed to write audit log entry');
  }
}
