import type { FastifyInstance } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq, and } from 'drizzle-orm';
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

const IdParams = Type.Object({
  id: Type.String(),
});
type IdParams = Static<typeof IdParams>;

const CreateIntegrationBody = Type.Object({
  label: Type.Optional(Type.String()),
  credentials: Type.Record(Type.String(), Type.Unknown()),
});
type CreateIntegrationBody = Static<typeof CreateIntegrationBody>;

const UpdateIntegrationBody = Type.Object({
  label: Type.Optional(Type.String()),
  credentials: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
});
type UpdateIntegrationBody = Static<typeof UpdateIntegrationBody>;

// Services that allow multiple accounts
const MULTI_ACCOUNT_SERVICES = ['whatsapp'] as const;

// Supported services
const SUPPORTED_SERVICES = [
  'openrouter',
  'whatsapp',
  'instagram',
  'tiktok',
  'threads',
  'notion',
] as const;

function isMultiAccount(service: string): boolean {
  return (MULTI_ACCOUNT_SERVICES as readonly string[]).includes(service);
}

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function integrationRoutes(fastify: FastifyInstance) {
  // ----- GET /integrations -----
  // Returns all services with their accounts
  fastify.get(
    '/',
    { preHandler: [fastify.authenticate] },
    async () => {
      const rows = await fastify.db
        .select({
          id: integrations.id,
          service: integrations.service,
          label: integrations.label,
          isActive: integrations.isActive,
          updatedAt: integrations.updatedAt,
        })
        .from(integrations);

      // Group rows by service
      const byService = new Map<string, typeof rows>();
      for (const row of rows) {
        const list = byService.get(row.service) ?? [];
        list.push(row);
        byService.set(row.service, list);
      }

      return SUPPORTED_SERVICES.map((service) => {
        const accounts = byService.get(service) ?? [];
        const multiAccount = isMultiAccount(service);

        if (multiAccount) {
          return {
            service,
            multiAccount: true,
            accounts: accounts.map((a) => ({
              id: a.id,
              label: a.label,
              isActive: a.isActive,
              connected: true,
              updatedAt: a.updatedAt,
            })),
            connected: accounts.length > 0,
          };
        }

        // Single-account service
        const row = accounts[0];
        return {
          service,
          multiAccount: false,
          id: row?.id ?? null,
          isActive: row?.isActive ?? false,
          connected: !!row,
          updatedAt: row?.updatedAt ?? null,
        };
      });
    },
  );

  // ----- POST /integrations/:service -----
  // Add a new account for a service (required for multi-account, also works for single)
  fastify.post<{ Params: ServiceParams; Body: CreateIntegrationBody }>(
    '/:service',
    {
      preHandler: [fastify.authenticate],
      schema: {
        params: ServiceParams,
        body: CreateIntegrationBody,
      },
    },
    async (request, reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can manage integrations');
      }

      const { service } = request.params;
      const { label, credentials } = request.body;

      if (!SUPPORTED_SERVICES.includes(service as typeof SUPPORTED_SERVICES[number])) {
        throw new ValidationError(`Unsupported service: ${service}`);
      }

      // For single-account services, check if one already exists
      if (!isMultiAccount(service)) {
        const [existing] = await fastify.db
          .select({ id: integrations.id })
          .from(integrations)
          .where(eq(integrations.service, service))
          .limit(1);

        if (existing) {
          throw new ValidationError(`${service} already has an account. Use PUT to update.`);
        }
      }

      // Set env vars for known services
      setEnvFromCredentials(service, credentials as Record<string, string>);

      const encrypted = encrypt(JSON.stringify(credentials));

      const [row] = await fastify.db
        .insert(integrations)
        .values({
          service,
          label: label ?? null,
          credentials: encrypted,
          isActive: true,
          updatedAt: new Date(),
        })
        .returning();

      return reply.status(201).send({
        id: row!.id,
        service: row!.service,
        label: row!.label,
        isActive: row!.isActive,
        updatedAt: row!.updatedAt,
      });
    },
  );

  // ----- PUT /integrations/:service -----
  // Upsert for single-account services (backward compat)
  fastify.put<{ Params: ServiceParams; Body: CreateIntegrationBody }>(
    '/:service',
    {
      preHandler: [fastify.authenticate],
      schema: {
        params: ServiceParams,
        body: CreateIntegrationBody,
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

      setEnvFromCredentials(service, credentials as Record<string, string>);

      const encrypted = encrypt(JSON.stringify(credentials));

      // For single-account: upsert the single row
      // For multi-account: this updates the first row or creates one
      const [existing] = await fastify.db
        .select({ id: integrations.id })
        .from(integrations)
        .where(eq(integrations.service, service))
        .limit(1);

      let row;
      if (existing) {
        [row] = await fastify.db
          .update(integrations)
          .set({
            credentials: encrypted,
            isActive: true,
            updatedAt: new Date(),
          })
          .where(eq(integrations.id, existing.id))
          .returning();
      } else {
        [row] = await fastify.db
          .insert(integrations)
          .values({
            service,
            credentials: encrypted,
            isActive: true,
            updatedAt: new Date(),
          })
          .returning();
      }

      return reply.status(200).send({
        id: row!.id,
        service: row!.service,
        label: row!.label,
        isActive: row!.isActive,
        updatedAt: row!.updatedAt,
      });
    },
  );

  // ----- PUT /integrations/accounts/:id -----
  // Update a specific account by ID
  fastify.put<{ Params: IdParams; Body: UpdateIntegrationBody }>(
    '/accounts/:id',
    {
      preHandler: [fastify.authenticate],
      schema: {
        params: IdParams,
        body: UpdateIntegrationBody,
      },
    },
    async (request, reply) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can manage integrations');
      }

      const { id } = request.params;
      const { label, credentials } = request.body;

      const [existing] = await fastify.db
        .select()
        .from(integrations)
        .where(eq(integrations.id, id))
        .limit(1);

      if (!existing) throw new NotFoundError('Integration account');

      const updates: Record<string, unknown> = { updatedAt: new Date() };

      if (label !== undefined) {
        updates.label = label;
      }

      if (credentials) {
        setEnvFromCredentials(existing.service, credentials as Record<string, string>);
        updates.credentials = encrypt(JSON.stringify(credentials));
      }

      const [row] = await fastify.db
        .update(integrations)
        .set(updates)
        .where(eq(integrations.id, id))
        .returning();

      return reply.status(200).send({
        id: row!.id,
        service: row!.service,
        label: row!.label,
        isActive: row!.isActive,
        updatedAt: row!.updatedAt,
      });
    },
  );

  // ----- POST /integrations/:service/test -----
  // Test single-account service
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

      const [row] = await fastify.db
        .select()
        .from(integrations)
        .where(eq(integrations.service, service))
        .limit(1);

      if (!row) throw new NotFoundError(`Integration "${service}"`);

      return testIntegrationRow(row);
    },
  );

  // ----- POST /integrations/accounts/:id/test -----
  // Test a specific account by ID
  fastify.post<{ Params: IdParams }>(
    '/accounts/:id/test',
    {
      preHandler: [fastify.authenticate],
      schema: { params: IdParams },
    },
    async (request) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can test integrations');
      }

      const { id } = request.params;

      const [row] = await fastify.db
        .select()
        .from(integrations)
        .where(eq(integrations.id, id))
        .limit(1);

      if (!row) throw new NotFoundError('Integration account');

      return testIntegrationRow(row);
    },
  );

  // ----- DELETE /integrations/:service -----
  // Deactivate single-account service
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

  // ----- DELETE /integrations/accounts/:id -----
  // Delete a specific account by ID (hard delete for multi-account)
  fastify.delete<{ Params: IdParams }>(
    '/accounts/:id',
    {
      preHandler: [fastify.authenticate],
      schema: { params: IdParams },
    },
    async (request) => {
      if (request.user.role !== 'owner') {
        throw new ForbiddenError('Only owners can manage integrations');
      }

      const { id } = request.params;

      await fastify.db
        .delete(integrations)
        .where(eq(integrations.id, id));

      return { success: true };
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function setEnvFromCredentials(service: string, creds: Record<string, string>) {
  if (service === 'openrouter' && creds.apiKey) {
    process.env.OPENROUTER_API_KEY = creds.apiKey;
  } else if (service === 'notion' && creds.integrationToken) {
    process.env.NOTION_TOKEN = creds.integrationToken;
  }
  // WhatsApp keys are per-account, don't set single env var
}

async function testIntegrationRow(
  row: { service: string; credentials: string },
): Promise<{ success: boolean; details?: unknown; error?: string }> {
  let creds: Record<string, unknown>;
  try {
    creds = JSON.parse(decrypt(row.credentials));
  } catch {
    return { success: false, error: 'Failed to decrypt credentials' };
  }

  try {
    switch (row.service) {
      case 'openrouter': {
        const res = await fetch('https://openrouter.ai/api/v1/key', {
          headers: { Authorization: `Bearer ${creds.apiKey}` },
        });
        if (!res.ok) throw new Error(`OpenRouter API returned ${res.status}`);
        const data = (await res.json()) as Record<string, unknown>;
        return { success: true, details: { remaining: data.remaining } };
      }

      case 'whatsapp': {
        const idInstance = String(creds.idInstance ?? '');
        const token = String(creds.apiTokenInstance ?? '');
        if (!idInstance || !token) {
          return { success: false, error: 'Missing idInstance or apiTokenInstance' };
        }
        const res = await fetch(
          `https://api.green-api.com/waInstance${idInstance}/getStateInstance/${token}`,
        );
        if (!res.ok) {
          return { success: false, error: `Green API returned ${res.status}` };
        }
        const data = (await res.json()) as { stateInstance?: string };
        // stateInstance: "authorized" | "notAuthorized" | "blocked" | "sleepMode" | "starting"
        return {
          success: data.stateInstance === 'authorized',
          details: { state: data.stateInstance },
        };
      }

      case 'instagram': {
        const res = await fetch(
          `https://graph.facebook.com/v19.0/me?access_token=${creds.accessToken}`,
        );
        if (!res.ok) throw new Error(`Graph API returned ${res.status}`);
        const data = (await res.json()) as Record<string, unknown>;
        return { success: true, details: { id: data.id, name: data.name } };
      }

      case 'threads': {
        const res = await fetch(
          `https://graph.threads.net/v1.0/me?access_token=${creds.accessToken}`,
        );
        if (!res.ok) throw new Error(`Threads API returned ${res.status}`);
        const data = (await res.json()) as Record<string, unknown>;
        return { success: true, details: { id: data.id } };
      }

      case 'tiktok': {
        const playwrightUrl = process.env.PLAYWRIGHT_SERVICE_URL ?? 'http://playwright-service:3100';
        const res = await fetch(`${playwrightUrl}/api/sessions/tiktok/status`);
        const data = (await res.json()) as Record<string, unknown>;
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
        const data = (await res.json()) as Record<string, unknown>;
        return { success: true, details: { name: data.name, type: data.type } };
      }

      default:
        return { success: false, error: `Test not implemented for ${row.service}` };
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return { success: false, error: message };
  }
}
