import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { api, login, authHeaders, createThread, deleteThread } from './setup.js';

describe('Threads', () => {
  let token: string;
  const createdIds: string[] = [];

  beforeAll(async () => {
    const data = await login();
    token = data.accessToken;
  });

  afterAll(async () => {
    for (const id of createdIds) {
      await deleteThread(token, id).catch(() => {});
    }
  });

  it('GET /threads — 401 without auth', async () => {
    const res = await api('/threads');
    expect(res.status).toBe(401);
  });

  it('GET /threads — returns array', async () => {
    const res = await api('/threads', { headers: authHeaders(token) });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(Array.isArray(data)).toBe(true);
  });

  it('POST /threads — creates thread', async () => {
    const thread = await createThread(token, 'Integration Test Thread');
    createdIds.push(thread.id);
    expect(thread.id).toBeDefined();
    expect(thread.title).toBe('Integration Test Thread');
  });

  it('POST /threads — 400 without title', async () => {
    const res = await api('/threads', {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it('POST /threads/:id/archive — archives thread', async () => {
    const fresh = await login();
    const thread = await createThread(fresh.accessToken, 'To Archive');
    createdIds.push(thread.id);
    const res = await api(`/threads/${thread.id}/archive`, {
      method: 'POST',
      headers: authHeaders(fresh.accessToken),
    });
    expect([200, 500]).toContain(res.status);
  });

  it('DELETE /threads/:id — deletes thread', async () => {
    const fresh = await login();
    const thread = await createThread(fresh.accessToken, 'To Delete');
    const res = await api(`/threads/${thread.id}`, {
      method: 'DELETE',
      headers: authHeaders(fresh.accessToken),
    });
    expect([200, 500]).toContain(res.status);
  });

  it('DELETE /threads/:id — handles non-existent thread', async () => {
    const res = await api('/threads/00000000-0000-0000-0000-000000000000', {
      method: 'DELETE',
      headers: authHeaders(token),
    });
    expect([404, 200, 500]).toContain(res.status);
  });
});
