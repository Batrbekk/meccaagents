import fp from 'fastify-plugin';
import { Client } from 'minio';
import type { FastifyInstance } from 'fastify';

declare module 'fastify' {
  interface FastifyInstance {
    minio: Client;
  }
}

export default fp(async (fastify: FastifyInstance) => {
  const client = new Client({
    endPoint: process.env.MINIO_ENDPOINT ?? 'minio',
    port: Number(process.env.MINIO_PORT ?? 9000),
    useSSL: false,
    accessKey: process.env.MINIO_ROOT_USER ?? 'minioadmin',
    secretKey: process.env.MINIO_ROOT_PASSWORD ?? 'changeme',
  });

  const bucket = process.env.MINIO_BUCKET ?? 'agentteam-files';

  // Ensure bucket exists
  const exists = await client.bucketExists(bucket);
  if (!exists) {
    await client.makeBucket(bucket);
    fastify.log.info(`MinIO bucket "${bucket}" created`);
  }

  fastify.decorate('minio', client);
});
