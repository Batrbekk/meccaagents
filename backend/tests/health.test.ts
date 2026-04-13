import { describe, it, expect } from 'vitest';
import { api } from './setup.js';

describe('Health', () => {
  it('GET /health returns ok', async () => {
    const res = await api('/health');
    expect(res.status).toBe(200);
    const data = await res.json() as { status: string };
    expect(data.status).toBe('ok');
  });

  it('GET /ready returns ready with db and redis ok', async () => {
    const res = await api('/ready');
    expect(res.status).toBe(200);
    const data = await res.json() as { status: string; db: string; redis: string };
    expect(data.status).toBe('ready');
    expect(data.db).toBe('ok');
    expect(data.redis).toBe('ok');
  });
});
