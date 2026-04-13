const BASE = process.env.API_URL ?? 'http://localhost:3000';

export async function api(path: string, opts?: RequestInit): Promise<Response> {
  return fetch(`${BASE}${path}`, opts);
}

export async function login(
  email = 'batyr@cannect.ai',
  password = 'admin123',
): Promise<{ accessToken: string; user: { id: string; email: string; name: string; role: string } }> {
  const res = await api('/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new Error(`Login failed: ${res.status}`);
  return res.json() as any;
}

export function authHeaders(token: string): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

export async function createThread(
  token: string,
  title = 'Test Thread',
): Promise<{ id: string; title: string }> {
  const res = await api('/threads', {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ title }),
  });
  if (!res.ok) throw new Error(`Create thread failed: ${res.status}`);
  return res.json() as any;
}

export async function sendMessage(
  token: string,
  threadId: string,
  content: string,
): Promise<{ id: string; content: string }> {
  const res = await api(`/threads/${threadId}/messages`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ content }),
  });
  if (!res.ok) throw new Error(`Send message failed: ${res.status}`);
  return res.json() as any;
}

export async function deleteThread(token: string, threadId: string): Promise<void> {
  await api(`/threads/${threadId}`, {
    method: 'DELETE',
    headers: authHeaders(token),
  });
}
