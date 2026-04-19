-- Multi-account integrations: allow multiple accounts per service (e.g. 3 WhatsApp numbers)
ALTER TABLE "integrations" DROP CONSTRAINT IF EXISTS "integrations_service_unique";
ALTER TABLE "integrations" ADD COLUMN IF NOT EXISTS "label" text;
CREATE INDEX IF NOT EXISTS "idx_integrations_service" ON "integrations" USING btree ("service");
