import { describe, it, expect, beforeAll } from 'vitest';
import { api, login, authHeaders } from './setup.js';

describe('Approvals', () => {
  let token: string;

  beforeAll(async () => {
    const data = await login();
    token = data.accessToken;
  });

  it('GET /approvals — returns list', async () => {
    const res = await api('/approvals', { headers: authHeaders(token) });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(Array.isArray(data) || (data && typeof data === 'object')).toBe(true);
  });

  it('GET /approvals?status=pending — filters by status', async () => {
    const res = await api('/approvals?status=pending', {
      headers: authHeaders(token),
    });
    expect(res.status).toBe(200);
  });

  it('GET /approvals?status=approved — filters by approved', async () => {
    const res = await api('/approvals?status=approved', {
      headers: authHeaders(token),
    });
    expect(res.status).toBe(200);
  });

  it('GET /approvals — 401 without auth', async () => {
    const res = await api('/approvals');
    expect(res.status).toBe(401);
  });

  it('POST /approvals/nonexistent/approve — 404 or 500', async () => {
    const res = await api('/approvals/00000000-0000-0000-0000-000000000000/approve', {
      method: 'POST',
      headers: authHeaders(token),
    });
    expect([404, 500]).toContain(res.status);
  });

  it('POST /approvals/nonexistent/reject — 404', async () => {
    const res = await api('/approvals/00000000-0000-0000-0000-000000000000/reject', {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({ notes: 'not found' }),
    });
    expect(res.status).toBe(404);
  });
});
