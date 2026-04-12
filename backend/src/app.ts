import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import cookie from '@fastify/cookie';
import multipart from '@fastify/multipart';
import { logger } from './lib/logger.js';
import { errorHandler } from './lib/errors.js';
import dbPlugin from './plugins/db.js';
import redisPlugin from './plugins/redis.js';
import minioPlugin from './plugins/minio.js';
import wsPlugin from './plugins/websocket.js';
import authPlugin from './plugins/auth.js';
import authRoutes from './routes/auth.js';
import threadRoutes from './routes/threads.js';
import messageRoutes from './routes/messages.js';
import wsRoutes from './routes/ws.js';
import fileRoutes from './routes/files.js';
import approvalRoutes from './routes/approvals.js';
import agentRoutes from './routes/agents.js';

const app = Fastify({
  logger,
  trustProxy: true,
});

// --- Global error handler ---
app.setErrorHandler(errorHandler);

// --- Security & middleware ---
await app.register(helmet, {
  contentSecurityPolicy: false, // API only, no HTML
});

await app.register(cors, {
  origin: process.env.CORS_ORIGINS?.split(',') ?? ['http://localhost:3000'],
  credentials: true,
});

await app.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute',
});

await app.register(cookie);

await app.register(multipart, {
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
    files: 5,
  },
});

// --- Plugins ---
await app.register(dbPlugin);
await app.register(redisPlugin);
await app.register(minioPlugin);
await app.register(wsPlugin);
await app.register(authPlugin);

// --- Health checks ---
app.get('/health', async () => ({ status: 'ok' }));

app.get('/ready', async (request) => {
  try {
    await app.sql`SELECT 1`;
    await app.redis.ping();
    return { status: 'ready', db: 'ok', redis: 'ok' };
  } catch (err) {
    request.log.error(err, 'Readiness check failed');
    return { status: 'not_ready' };
  }
});

// --- Routes ---
await app.register(authRoutes, { prefix: '/auth' });
await app.register(threadRoutes, { prefix: '/threads' });
await app.register(messageRoutes, { prefix: '/threads' });
await app.register(wsRoutes, { prefix: '/threads' });
await app.register(fileRoutes, { prefix: '/files' });
await app.register(approvalRoutes, { prefix: '/approvals' });
await app.register(agentRoutes, { prefix: '/agents' });
// await app.register(integrationRoutes, { prefix: '/integrations' });
// await app.register(webhookRoutes, { prefix: '/webhooks' });

// --- Graceful shutdown ---
const signals: NodeJS.Signals[] = ['SIGINT', 'SIGTERM'];
for (const signal of signals) {
  process.on(signal, async () => {
    app.log.info(`Received ${signal}, shutting down gracefully...`);
    await app.close();
    process.exit(0);
  });
}

// --- Start ---
const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? '0.0.0.0';

try {
  await app.listen({ port, host });
  app.log.info(`Server listening on ${host}:${port}`);
} catch (err) {
  app.log.fatal(err, 'Failed to start server');
  process.exit(1);
}

export default app;
