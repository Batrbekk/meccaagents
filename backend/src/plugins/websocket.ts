import fp from 'fastify-plugin';
import ws from '@fastify/websocket';
import type { FastifyInstance } from 'fastify';

export default fp(async (fastify: FastifyInstance) => {
  await fastify.register(ws, {
    options: {
      maxPayload: 64 * 1024, // 64KB max message size
      clientTracking: true,
    },
  });
});
