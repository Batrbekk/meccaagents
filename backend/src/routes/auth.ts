import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { Type, type Static } from '@sinclair/typebox';
import { eq } from 'drizzle-orm';
import { users, sessions } from '../db/schema.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { generateAccessToken, generateRefreshToken } from '../lib/jwt.js';
import {
  UnauthorizedError,
  ValidationError,
  ForbiddenError,
} from '../lib/errors.js';

// --- Request schemas ---

const RegisterBody = Type.Object({
  email: Type.String({ format: 'email' }),
  name: Type.String({ minLength: 1 }),
  password: Type.String({ minLength: 8 }),
});
type RegisterBodyType = Static<typeof RegisterBody>;

const LoginBody = Type.Object({
  email: Type.String({ format: 'email' }),
  password: Type.String({ minLength: 1 }),
});
type LoginBodyType = Static<typeof LoginBody>;

// --- Constants ---

const REFRESH_TOKEN_EXPIRY_DAYS = 180;
const COOKIE_NAME = 'refresh_token';

function refreshCookieOptions(expires: Date) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict' as const,
    path: '/auth',
    expires,
  };
}

// --- Plugin ---

export default async function authRoutes(fastify: FastifyInstance) {
  // Auth plugin is registered globally in app.ts — no need to re-register here

  // =========================
  // POST /auth/register
  // =========================
  fastify.post<{ Body: RegisterBodyType }>(
    '/register',
    {
      schema: {
        body: RegisterBody,
      },
    },
    async (request: FastifyRequest<{ Body: RegisterBodyType }>, reply: FastifyReply) => {
      const { email, name, password } = request.body;

      // Check if any users exist
      const existingUsers = await fastify.db.select({ id: users.id }).from(users).limit(1);
      const isFirstUser = existingUsers.length === 0;

      if (!isFirstUser) {
        // Only an authenticated owner can register new users
        const header = request.headers.authorization;
        if (!header?.startsWith('Bearer ')) {
          throw new ForbiddenError('Only owners can register new users');
        }

        try {
          await fastify.authenticate(request, reply);
        } catch {
          throw new ForbiddenError('Only owners can register new users');
        }

        if (request.user.role !== 'owner') {
          throw new ForbiddenError('Only owners can register new users');
        }
      }

      // Check if email is already taken
      const existing = await fastify.db
        .select({ id: users.id })
        .from(users)
        .where(eq(users.email, email))
        .limit(1);

      if (existing.length > 0) {
        throw new ValidationError('Email already registered');
      }

      const passwordHash = await hashPassword(password);

      const [user] = await fastify.db
        .insert(users)
        .values({
          email,
          name,
          passwordHash,
          role: 'owner',
        })
        .returning({
          id: users.id,
          email: users.email,
          name: users.name,
          role: users.role,
        });

      return reply.status(201).send({ user });
    },
  );

  // =========================
  // POST /auth/login
  // =========================
  fastify.post<{ Body: LoginBodyType }>(
    '/login',
    {
      schema: {
        body: LoginBody,
      },
    },
    async (request: FastifyRequest<{ Body: LoginBodyType }>, reply: FastifyReply) => {
      const { email, password } = request.body;

      const [user] = await fastify.db
        .select()
        .from(users)
        .where(eq(users.email, email))
        .limit(1);

      if (!user) {
        throw new UnauthorizedError('Invalid email or password');
      }

      if (!user.isActive) {
        throw new UnauthorizedError('Account is deactivated');
      }

      const valid = await verifyPassword(user.passwordHash, password);
      if (!valid) {
        throw new UnauthorizedError('Invalid email or password');
      }

      // Update last login
      await fastify.db
        .update(users)
        .set({ lastLoginAt: new Date() })
        .where(eq(users.id, user.id));

      // Generate tokens
      const accessToken = await generateAccessToken(user.id, user.role);
      const refreshToken = generateRefreshToken();
      const refreshTokenHash = await hashPassword(refreshToken);

      // Create session
      const tokenFamily = crypto.randomUUID();
      const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

      await fastify.db.insert(sessions).values({
        userId: user.id,
        refreshTokenHash,
        tokenFamily,
        deviceInfo: request.headers['user-agent'] ?? null,
        expiresAt,
      });

      // Set refresh token cookie
      reply.setCookie(COOKIE_NAME, refreshToken, refreshCookieOptions(expiresAt));

      return {
        accessToken,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
        },
      };
    },
  );

  // =========================
  // POST /auth/refresh
  // =========================
  fastify.post(
    '/refresh',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const refreshToken = request.cookies[COOKIE_NAME];
      if (!refreshToken) {
        throw new UnauthorizedError('No refresh token provided');
      }

      // Find matching session by iterating active sessions
      const allSessions = await fastify.db
        .select()
        .from(sessions)
        .orderBy(sessions.createdAt);

      let matchedSession: typeof allSessions[number] | null = null;

      for (const session of allSessions) {
        const isMatch = await verifyPassword(session.refreshTokenHash, refreshToken);
        if (isMatch) {
          matchedSession = session;
          break;
        }
      }

      if (!matchedSession) {
        // THEFT DETECTION: token not found — it may have been rotated already.
        // We can't identify the family from the token alone without a match,
        // so just reject.
        throw new UnauthorizedError('Invalid refresh token');
      }

      // Check expiry
      if (matchedSession.expiresAt < new Date()) {
        await fastify.db.delete(sessions).where(eq(sessions.id, matchedSession.id));
        throw new UnauthorizedError('Refresh token expired');
      }

      // Get user
      const [user] = await fastify.db
        .select()
        .from(users)
        .where(eq(users.id, matchedSession.userId))
        .limit(1);

      if (!user || !user.isActive) {
        throw new UnauthorizedError('User not found or deactivated');
      }

      // ROTATION: invalidate old session, create new one with same family
      await fastify.db.delete(sessions).where(eq(sessions.id, matchedSession.id));

      const newRefreshToken = generateRefreshToken();
      const newRefreshTokenHash = await hashPassword(newRefreshToken);
      const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

      await fastify.db.insert(sessions).values({
        userId: user.id,
        refreshTokenHash: newRefreshTokenHash,
        tokenFamily: matchedSession.tokenFamily,
        deviceInfo: request.headers['user-agent'] ?? null,
        expiresAt,
      });

      // Check for THEFT: if there are multiple sessions in the same family,
      // it means the old token was reused after rotation — invalidate all.
      const familySessions = await fastify.db
        .select({ id: sessions.id })
        .from(sessions)
        .where(eq(sessions.tokenFamily, matchedSession.tokenFamily));

      if (familySessions.length > 1) {
        // Theft detected — invalidate entire family
        await fastify.db
          .delete(sessions)
          .where(eq(sessions.tokenFamily, matchedSession.tokenFamily));

        reply.clearCookie(COOKIE_NAME, { path: '/auth' });
        throw new UnauthorizedError('Token reuse detected — all sessions invalidated');
      }

      const accessToken = await generateAccessToken(user.id, user.role);

      reply.setCookie(COOKIE_NAME, newRefreshToken, refreshCookieOptions(expiresAt));

      return { accessToken };
    },
  );

  // =========================
  // POST /auth/logout
  // =========================
  fastify.post(
    '/logout',
    { preHandler: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const refreshToken = request.cookies[COOKIE_NAME];

      if (refreshToken) {
        // Find and delete the matching session
        const allSessions = await fastify.db
          .select()
          .from(sessions)
          .where(eq(sessions.userId, request.user.id));

        for (const session of allSessions) {
          const isMatch = await verifyPassword(session.refreshTokenHash, refreshToken);
          if (isMatch) {
            await fastify.db.delete(sessions).where(eq(sessions.id, session.id));
            break;
          }
        }
      }

      reply.clearCookie(COOKIE_NAME, { path: '/auth' });
      return { message: 'Logged out' };
    },
  );
}
