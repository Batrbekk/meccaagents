import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { login, authHeaders, createThread, sendMessage, deleteThread, api } from './setup.js';

describe('Messages', () => {
  let token: string;
  let threadId: string;

  beforeAll(async () => {
    const data = await login();
    token = data.accessToken;
    const thread = await createThread(token, 'Messages Test Thread');
    threadId = thread.id;
  });

  afterAll(async () => {
    await deleteThread(token, threadId).catch(() => {});
  });

  it('GET /threads/:id/messages — returns empty list for new thread', async () => {
    const res = await api(`/threads/${threadId}/messages`, {
      headers: authHeaders(token),
    });
    expect(res.status).toBe(200);
    const data = await res.json() as { messages: unknown[]; nextCursor: string | null };
    expect(data.messages).toBeDefined();
    expect(Array.isArray(data.messages)).toBe(true);
    expect(data.nextCursor).toBeNull();
  });

  it('POST /threads/:id/messages — creates message', async () => {
    const msg = await sendMessage(token, threadId, 'Hello from test');
    expect(msg.id).toBeDefined();
    expect(msg.content).toBe('Hello from test');
  });

  it('GET /threads/:id/messages — returns created message', async () => {
    const res = await api(`/threads/${threadId}/messages`, {
      headers: authHeaders(token),
    });
    const data = await res.json() as { messages: Array<{ content: string }> };
    expect(data.messages.length).toBeGreaterThanOrEqual(1);
    expect(data.messages.some((m) => m.content === 'Hello from test')).toBe(true);
  });

  it('POST /threads/:id/messages — 400 without content', async () => {
    const res = await api(`/threads/${threadId}/messages`, {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it('GET /threads/:id/messages — 404 for non-existent thread', async () => {
    const res = await api('/threads/00000000-0000-0000-0000-000000000000/messages', {
      headers: authHeaders(token),
    });
    expect(res.status).toBe(404);
  });

  it('Cursor pagination works', async () => {
    // Send a few more messages
    await sendMessage(token, threadId, 'Msg 2');
    await sendMessage(token, threadId, 'Msg 3');

    // Get first page with limit=1
    const res1 = await api(`/threads/${threadId}/messages?limit=1`, {
      headers: authHeaders(token),
    });
    const page1 = await res1.json() as { messages: unknown[]; nextCursor: string | null };
    expect(page1.messages.length).toBe(1);
    expect(page1.nextCursor).toBeDefined();

    // Get second page
    const res2 = await api(`/threads/${threadId}/messages?limit=1&cursor=${page1.nextCursor}`, {
      headers: authHeaders(token),
    });
    const page2 = await res2.json() as { messages: unknown[]; nextCursor: string | null };
    expect(page2.messages.length).toBe(1);
  });
});
