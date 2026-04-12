import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq } from 'drizzle-orm';
import { integrations } from '../db/schema.js';
import { encrypt, decrypt } from '../lib/crypto.js';
import { NotFoundError, ForbiddenError, ValidationError } from '../lib/errors.js';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const ServiceParams = Type.Object({
  service: Type.String(),
});
type ServiceParams = Static<typeof ServiceParams>;

const UpdateIntegrationBody = Type.Object({
  credentials: Type.Record(Type.String(), Type.Unknown()),
});
type UpdateIntegrationBody = Static<typeof UpdateIntegrationBody>;

// Supported services
const SUPPORTED_SERVICES = [
  'openrouter',
  'whatsapp',
  'instagram',
  'tiktok',
  'threads',
  'notion',
] as const;

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function integrationRoutes(fastify: FastifyInstance) {
  // ----- GET /integrations -----
  fastify.get(
    '/',
    { preHandler: [fastify.authenticate] },
    async () => {
      const rows = await fastify.db
        .select({
          id: integrations.id,
          service: integrations.service,
          isActive: integrations.isActive,
          updatedAt: integrations.updatedAt,
        })
        .from(integrations);

      // Build a map of existing integrations
      const existing = new Map(rows.map((r) => [r.service, r]));

      // Return all supported services with status
      return SUPPORTED_SERVICES.map((service) => {
        const row = existing.get(service);
        return {
          service,
          isActive: row?.isActive ?? false,
          connected: !!row,
          updatedAt: row?.updatedAt ?? null,
        };
      });
    },
  );

  // ----- PUT /integrations/:service -----
  fastify.put<{ Params: ServiceParams; Body: UpdateIntegrationBody }>(
    '/:service',
    {
      preHandler: [fastify.authenticate],
      schema: {
        params: ServiceParams,
        body: UpdateIntegrationBody,
      },
    },
    async (request, reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can manage integrations');
      }

      const { service } = request.params;
      const { credentials } = request.body;

      if (!SUPPORTED_SERVICES.includes(service as typeof SUPPORTED_SERVICES[number])) {
        throw new ValidationError(`Unsupported service: ${service}`);
      }

      // Encrypt credentials
      const encrypted = encrypt(JSON.stringify(credentials));

      // Upsert
      const [row] = await fastify.db
        .insert(integrations)
        .values({
          service,
          credentials: encrypted,
          isActive: true,
          updatedAt: new Date(),
        })
        .onConflictDoUpdate({
          target: integrations.service,
          set: {
            credentials: encrypted,
            isActive: true,
            updatedAt: new Date(),
          },
        })
        .returning();

      return reply.status(200).send({
        service: row!.service,
        isActive: row!.isActive,
        updatedAt: row!.updatedAt,
      });
    },
  );

  // ----- POST /integrations/:service/test -----
  fastify.post<{ Params: ServiceParams }>(
    '/:service/test',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ServiceParams },
    },
    async (request) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can test integrations');
      }

      const { service } = request.params;

      // Load credentials
      const [row] = await fastify.db
        .select()
        .from(integrations)
        .where(eq(integrations.service, service))
        .limit(1);

      if (!row) throw new NotFoundError(`Integration "${service}"`);

      let creds: Record<string, unknown>;
      try {
        creds = JSON.parse(decrypt(row.credentials));
      } catch {
        return { success: false, error: 'Failed to decrypt credentials' };
      }

      // Test each service
      try {
        switch (service) {
          case 'openrouter': {
            const res = await fetch('https://openrouter.ai/api/v1/key', {
              headers: { Authorization: `Bearer ${creds.apiKey}` },
            });
            if (!res.ok) throw new Error(`OpenRouter API returned ${res.status}`);
            const data = await res.json() as Record<string, unknown>;
            return { success: true, details: { remaining: data.remaining } };
          }

          case 'whatsapp': {
            const res = await fetch('https://waba.360dialog.io/v1/health', {
              headers: { 'D360-API-KEY': String(creds.apiKey) },
            });
            return { success: res.ok, details: { status: res.status } };
          }

          case 'instagram': {
            const res = await fetch(
              `https://graph.facebook.com/v19.0/me?access_token=${creds.accessToken}`,
            );
            if (!res.ok) throw new Error(`Graph API returned ${res.status}`);
            const data = await res.json() as Record<string, unknown>;
            return { success: true, details: { id: data.id, name: data.name } };
          }

          case 'threads': {
            const res = await fetch(
              `https://graph.threads.net/v1.0/me?access_token=${creds.accessToken}`,
            );
            if (!res.ok) throw new Error(`Threads API returned ${res.status}`);
            const data = await res.json() as Record<string, unknown>;
            return { success: true, details: { id: data.id } };
          }

          case 'tiktok': {
            // TikTok uses Playwright session — check via microservice
            const playwrightUrl = process.env.PLAYWRIGHT_SERVICE_URL ?? 'http://playwright-service:3100';
            const res = await fetch(`${playwrightUrl}/api/sessions/tiktok/status`);
            const data = await res.json() as Record<string, unknown>;
            return { success: !!data.valid, details: data };
          }

          case 'notion': {
            const res = await fetch('https://api.notion.com/v1/users/me', {
              headers: {
                Authorization: `Bearer ${creds.token}`,
                'Notion-Version': '2022-06-28',
              },
            });
            if (!res.ok) throw new Error(`Notion API returned ${res.status}`);
            const data = await res.json() as Record<string, unknown>;
            return { success: true, details: { name: data.name, type: data.type } };
          }

          default:
            return { success: false, error: `Test not implemented for ${service}` };
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        return { success: false, error: message };
      }
    },
  );

  // ----- DELETE /integrations/:service -----
  fastify.delete<{ Params: ServiceParams }>(
    '/:service',
    {
      preHandler: [fastify.authenticate],
      schema: { params: ServiceParams },
    },
    async (request) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can manage integrations');
      }

      const { service } = request.params;

      await fastify.db
        .update(integrations)
        .set({ isActive: false, updatedAt: new Date() })
        .where(eq(integrations.service, service));

      return { success: true };
    },
  );
}
