import { SignJWT, jwtVerify, type JWTPayload } from 'jose';
import { nanoid } from 'nanoid';

export interface TokenPayload extends JWTPayload {
  sub: string;
  role: string;
}

function getSecret(): Uint8Array {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET is required');
  return new TextEncoder().encode(secret);
}

export async function generateAccessToken(userId: string, role: string): Promise<string> {
  return new SignJWT({ role })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(process.env.JWT_ACCESS_TTL ?? '24h')
    .sign(getSecret());
}

export function generateRefreshToken(): string {
  return nanoid(64);
}

export async function verifyAccessToken(token: string): Promise<TokenPayload> {
  const { payload } = await jwtVerify(token, getSecret());
  return payload as TokenPayload;
}
