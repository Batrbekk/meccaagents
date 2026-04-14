import fp from 'fastify-plugin';
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { verifyAccessToken } from '../lib/jwt.js';
import { UnauthorizedError } from '../lib/errors.js';

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    user: { id: string; role: string };
  }
}

export default fp(async (fastify: FastifyInstance) => {
  fastify.decorateRequest('user', null as unknown as { id: string; role: string });

  async function authenticate(request: FastifyRequest, _reply: FastifyReply): Promise<void> {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing or invalid Authorization header');
    }

    const token = header.slice(7);
    try {
      const payload = await verifyAccessToken(token);
      if (!payload.sub) throw new UnauthorizedError('Invalid token payload');
      request.user = { id: payload.sub, role: payload.role };
    } catch (err) {
      if (err instanceof UnauthorizedError) throw err;
      throw new UnauthorizedError('Invalid or expired access token');
    }
  }

  fastify.decorate('authenticate', authenticate);
});
