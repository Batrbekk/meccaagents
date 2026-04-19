import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import cookie from '@fastify/cookie';
import multipart from '@fastify/multipart';
import { loggerConfig } from './lib/logger.js';
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
import integrationRoutes from './routes/integrations.js';
import webhookRoutes from './routes/webhooks.js';
import analyticsRoutes from './routes/analytics.js';
import auditRoutes from './routes/audit.js';
import toolLogsExportRoutes from './routes/tool-logs-export.js';

const app = Fastify({
  logger: loggerConfig,
  trustProxy: true,
});

// Allow empty body with Content-Type: application/json (e.g. POST /approvals/:id/approve)
app.addContentTypeParser(
  'application/json',
  { parseAs: 'string' },
  (_request, body, done) => {
    const str = (body as string).trim();
    if (!str) {
      done(null, {});
      return;
    }
    try {
      done(null, JSON.parse(str));
    } catch (err) {
      done(err as Error, undefined);
    }
  },
);

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
  max: 1000,
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

// --- Load integration keys from DB into env on startup ---
try {
  const { decrypt } = await import('./lib/crypto.js');
  const rows = await app.sql`SELECT service, label, credentials FROM integrations WHERE is_active = true`;
  let waCount = 0;
  for (const row of rows) {
    try {
      const creds = JSON.parse(decrypt(row.credentials));
      if (row.service === 'openrouter' && creds.apiKey) {
        process.env.OPENROUTER_API_KEY = creds.apiKey;
        app.log.info('Loaded OpenRouter API key from DB');
      }
      if (row.service === 'notion' && creds.integrationToken) {
        process.env.NOTION_TOKEN = creds.integrationToken;
      }
      if (row.service === 'whatsapp' && creds.apiKey) {
        waCount++;
      }
    } catch { /* skip invalid */ }
  }
  if (waCount > 0) {
    app.log.info(`Loaded ${waCount} WhatsApp account(s) from DB`);
  }
} catch { /* DB not ready yet, skip */ }

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
await app.register(integrationRoutes, { prefix: '/integrations' });
await app.register(webhookRoutes, { prefix: '/webhooks' });
await app.register(analyticsRoutes, { prefix: '/analytics' });
await app.register(auditRoutes, { prefix: '/audit-log' });
await app.register(toolLogsExportRoutes, { prefix: '/tool-logs' });

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
