import type { FastifyInstance } from 'fastify';
import type { WebSocket, RawData } from 'ws';
import { verifyAccessToken } from '../lib/jwt.js';
import { subscribe, unsubscribe } from '../lib/pubsub.js';

// Track active connections per thread for cleanup
const threadConnections = new Map<string, Set<WebSocket>>();

export default async function wsRoutes(fastify: FastifyInstance) {
  fastify.get<{ Params: { id: string } }>(
    '/:id/subscribe',
    { websocket: true },
    async (socket, request) => {
      const threadId = request.params.id;
      let authenticated = false;
      let userId: string | null = null;

      // Rate limiting: max 100 messages per minute per connection
      let messageCount = 0;
      const rateLimitInterval = setInterval(() => { messageCount = 0; }, 60_000);

      // Heartbeat: ping every 30s, close if no pong
      let alive = true;
      const heartbeat = setInterval(() => {
        if (!alive) {
          socket.close(1001, 'Heartbeat timeout');
          return;
        }
        alive = false;
        socket.ping();
      }, 30_000);

      socket.on('pong', () => { alive = true; });

      // First message must be auth token
      socket.on('message', async (raw: RawData) => {
        messageCount++;
        if (messageCount > 100) {
          socket.send(JSON.stringify({ error: 'RATE_LIMIT', message: 'Too many messages' }));
          return;
        }

        const data = raw.toString();

        // Auth: first message must be { type: "auth", token: "..." }
        if (!authenticated) {
          try {
            const parsed = JSON.parse(data);
            if (parsed.type !== 'auth' || !parsed.token) {
              socket.send(JSON.stringify({ error: 'AUTH_REQUIRED', message: 'First message must be auth' }));
              socket.close(1008, 'Auth required');
              return;
            }

            const payload = await verifyAccessToken(parsed.token);
            if (!payload.sub) {
              socket.send(JSON.stringify({ error: 'INVALID_TOKEN' }));
              socket.close(1008, 'Invalid token');
              return;
            }

            userId = payload.sub;
            authenticated = true;

            // Track connection
            if (!threadConnections.has(threadId)) {
              threadConnections.set(threadId, new Set());
            }
            threadConnections.get(threadId)!.add(socket);

            // Subscribe to thread messages via Redis Pub/Sub
            const channel = `thread:${threadId}:messages`;
            await subscribe(channel, (message) => {
              if (socket.readyState === socket.OPEN) {
                socket.send(JSON.stringify({ type: 'message', data: message }));
              }
            });

            // Subscribe to approval events
            const approvalChannel = `thread:${threadId}:approvals`;
            await subscribe(approvalChannel, (approval) => {
              if (socket.readyState === socket.OPEN) {
                socket.send(JSON.stringify({ type: 'approval', data: approval }));
              }
            });

            socket.send(JSON.stringify({
              type: 'connected',
              threadId,
              userId,
            }));

            fastify.log.info({ threadId, userId }, 'WS client connected');
          } catch {
            socket.send(JSON.stringify({ error: 'AUTH_FAILED' }));
            socket.close(1008, 'Auth failed');
          }
          return;
        }

        // After auth: handle ping/typing indicators
        try {
          const parsed = JSON.parse(data);

          if (parsed.type === 'ping') {
            socket.send(JSON.stringify({ type: 'pong' }));
          }

          if (parsed.type === 'typing') {
            // Broadcast typing indicator to other connections in same thread
            const connections = threadConnections.get(threadId);
            if (connections) {
              const typingMsg = JSON.stringify({
                type: 'typing',
                userId,
                threadId,
              });
              for (const conn of connections) {
                if (conn !== socket && conn.readyState === conn.OPEN) {
                  conn.send(typingMsg);
                }
              }
            }
          }
        } catch {
          // Ignore malformed messages
        }
      });

      // Cleanup on close
      socket.on('close', async () => {
        clearInterval(heartbeat);
        clearInterval(rateLimitInterval);

        const connections = threadConnections.get(threadId);
        if (connections) {
          connections.delete(socket);
          if (connections.size === 0) {
            threadConnections.delete(threadId);
            // Unsubscribe from Redis when no more listeners
            await unsubscribe(`thread:${threadId}:messages`).catch(() => {});
            await unsubscribe(`thread:${threadId}:approvals`).catch(() => {});
          }
        }

        fastify.log.info({ threadId, userId }, 'WS client disconnected');
      });

      socket.on('error', (err: Error) => {
        fastify.log.error(err, 'WebSocket error');
      });
    },
  );
}
