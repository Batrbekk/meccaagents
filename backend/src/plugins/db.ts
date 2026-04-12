import fp from 'fastify-plugin';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from '../db/schema.js';
import type { FastifyInstance } from 'fastify';

declare module 'fastify' {
  interface FastifyInstance {
    db: ReturnType<typeof drizzle>;
    sql: ReturnType<typeof postgres>;
  }
}

export default fp(async (fastify: FastifyInstance) => {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL is required');

  const sql = postgres(connectionString, { max: 20 });
  const db = drizzle(sql, { schema });

  fastify.decorate('db', db);
  fastify.decorate('sql', sql);

  fastify.addHook('onClose', async () => {
    await sql.end();
    fastify.log.info('Database connection closed');
  });
});
