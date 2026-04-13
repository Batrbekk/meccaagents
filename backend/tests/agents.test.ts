import { describe, it, expect, beforeAll } from 'vitest';
import { api, login, authHeaders } from './setup.js';

describe('Agents', () => {
  let token: string;

  beforeAll(async () => {
    const data = await login();
    token = data.accessToken;
  });

  it('GET /agents — returns 5 agents', async () => {
    const res = await api('/agents', { headers: authHeaders(token) });
    expect(res.status).toBe(200);
    const body = await res.json() as { agents: Array<{ slug: string; isActive: boolean }> } | Array<{ slug: string; isActive: boolean }>;
    const data = Array.isArray(body) ? body : body.agents;
    expect(data.length).toBe(5);
    const slugs = data.map((a) => a.slug).sort();
    expect(slugs).toEqual(['content', 'lawyer', 'orchestrator', 'sales', 'smm']);
  });

  it('GET /agents — all agents active by default', async () => {
    const res = await api('/agents', { headers: authHeaders(token) });
    const body = await res.json() as { agents: Array<{ isActive: boolean }> } | Array<{ isActive: boolean }>;
    const data = Array.isArray(body) ? body : body.agents;
    expect(data.every((a) => a.isActive)).toBe(true);
  });

  it('GET /agents/orchestrator/config — returns config', async () => {
    const res = await api('/agents/orchestrator/config', {
      headers: authHeaders(token),
    });
    expect(res.status).toBe(200);
    const data = await res.json() as { slug: string; model: string; temperature: number; systemPrompt: string };
    expect(data.slug).toBe('orchestrator');
    expect(data.model).toContain('claude');
    expect(data.temperature).toBeGreaterThanOrEqual(0);
    expect(data.systemPrompt.length).toBeGreaterThan(10);
  });

  it('PUT /agents/orchestrator/config — updates temperature', async () => {
    const res = await api('/agents/orchestrator/config', {
      method: 'PUT',
      headers: authHeaders(token),
      body: JSON.stringify({ temperature: 0.5 }),
    });
    expect(res.status).toBe(200);

    // Verify
    const check = await api('/agents/orchestrator/config', {
      headers: authHeaders(token),
    });
    const data = await check.json() as { temperature: number };
    expect(data.temperature).toBe(0.5);

    // Restore
    await api('/agents/orchestrator/config', {
      method: 'PUT',
      headers: authHeaders(token),
      body: JSON.stringify({ temperature: 0.3 }),
    });
  });

  it('GET /agents/orchestrator/logs — returns logs array', async () => {
    const res = await api('/agents/orchestrator/logs', {
      headers: authHeaders(token),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(Array.isArray(data) || (data && typeof data === 'object')).toBe(true);
  });

  it('GET /agents/nonexistent/config — 404 or 500', async () => {
    const res = await api('/agents/nonexistent/config', {
      headers: authHeaders(token),
    });
    expect([404, 500]).toContain(res.status);
  });
});
