import { createHmac, timingSafeEqual } from 'node:crypto';
import type { Redis } from 'ioredis';

// ── Replay protection constants ───────────────────────────────────────
const REPLAY_TTL_SECONDS = 300; // 5 minutes
const MAX_AGE_MS = REPLAY_TTL_SECONDS * 1000;

// ── Meta (Instagram / Threads) ────────────────────────────────────────

/**
 * Verify the `X-Hub-Signature-256` header sent by Meta webhooks.
 *
 * Meta computes HMAC-SHA256 of the raw request body using the App Secret
 * and sends the result as `sha256=<hex>`.
 */
export function verifyMetaSignature(
  payload: string,
  signature: string,
  appSecret: string,
): boolean {
  const prefix = 'sha256=';
  if (!signature.startsWith(prefix)) return false;

  const expected = createHmac('sha256', appSecret)
    .update(payload, 'utf8')
    .digest('hex');

  const received = signature.slice(prefix.length);

  if (expected.length !== received.length) return false;

  return timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(received, 'hex'),
  );
}

// ── 360dialog (WhatsApp) ──────────────────────────────────────────────

/**
 * Verify the `X-Signature` header sent by 360dialog webhooks.
 *
 * 360dialog computes HMAC-SHA256 of the raw request body using the API
 * key and sends the hex digest.
 */
export function verify360DialogSignature(
  payload: string,
  signature: string,
  apiKey: string,
): boolean {
  const expected = createHmac('sha256', apiKey)
    .update(payload, 'utf8')
    .digest('hex');

  if (expected.length !== signature.length) return false;

  return timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(signature, 'hex'),
  );
}

// ── Replay protection ─────────────────────────────────────────────────

/**
 * Guard against replayed or duplicated webhook events.
 *
 * 1. If a `timestamp` is provided, reject events older than 5 minutes.
 * 2. Attempt to SET the eventId key in Redis with NX + EX 300.
 *    If the key already exists the event is a duplicate.
 *
 * @returns `true` when the event is **new** and should be processed,
 *          `false` when it should be discarded (duplicate / stale).
 */
export async function checkReplayProtection(
  redis: Redis,
  eventId: string,
  timestamp?: number,
): Promise<boolean> {
  // Reject stale events
  if (timestamp !== undefined) {
    const age = Date.now() - timestamp * 1000; // timestamp is unix seconds
    if (age > MAX_AGE_MS) return false;
  }

  // SET NX EX — returns "OK" only when the key was newly created
  const result = await redis.set(
    `webhook:dedup:${eventId}`,
    '1',
    'EX',
    REPLAY_TTL_SECONDS,
    'NX',
  );

  return result === 'OK';
}
