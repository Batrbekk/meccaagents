import { Redis } from 'ioredis';

const redisUrl = process.env.REDIS_URL;
if (!redisUrl) throw new Error('REDIS_URL is required for pubsub');

// Publisher uses a standard connection
const publisher = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  enableReadyCheck: true,
  retryStrategy: (times: number) => Math.min(times * 200, 5000),
});

// Subscriber MUST use a separate connection (ioredis requirement)
const subscriber = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  enableReadyCheck: true,
  retryStrategy: (times: number) => Math.min(times * 200, 5000),
});

publisher.on('error', (err: Error) => console.error('PubSub publisher error:', err));
subscriber.on('error', (err: Error) => console.error('PubSub subscriber error:', err));

/**
 * Publish a JSON-serialized message to a Redis channel.
 */
export async function publish(channel: string, data: object): Promise<void> {
  await publisher.publish(channel, JSON.stringify(data));
}

/**
 * Subscribe to a Redis channel. Incoming messages are JSON-parsed before
 * being forwarded to the callback.
 */
export async function subscribe(
  channel: string,
  callback: (data: unknown) => void,
): Promise<void> {
  await subscriber.subscribe(channel);
  subscriber.on('message', (ch: string, message: string) => {
    if (ch === channel) {
      try {
        callback(JSON.parse(message));
      } catch {
        // If JSON parsing fails, pass raw string
        callback(message);
      }
    }
  });
}

/**
 * Unsubscribe from a Redis channel.
 */
export async function unsubscribe(channel: string): Promise<void> {
  await subscriber.unsubscribe(channel);
}

/**
 * Gracefully close both publisher and subscriber connections.
 */
export async function closePubSub(): Promise<void> {
  await publisher.quit();
  await subscriber.quit();
}
