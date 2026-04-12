import Fastify from 'fastify';
import { SessionManager } from './session-manager.js';

const app = Fastify({ logger: true });
const sessions = new SessionManager('/app/sessions');

// --- Health ---
app.get('/api/health', async () => ({
  status: 'ok',
  sessions: await sessions.listSessions(),
}));

// --- Session Management ---
app.get('/api/sessions', async () => {
  return sessions.listSessions();
});

app.get<{ Params: { platform: string } }>(
  '/api/sessions/:platform/status',
  async (request) => {
    const { platform } = request.params;
    const isValid = await sessions.isSessionValid(platform);
    return { platform, valid: isValid };
  },
);

app.post<{ Params: { platform: string } }>(
  '/api/sessions/:platform/save',
  async (request) => {
    const { platform } = request.params;
    await sessions.saveCurrentSession(platform);
    return { success: true, platform };
  },
);

// --- TikTok Operations ---
app.post<{ Body: { videoPath: string; caption: string; hashtags?: string[] } }>(
  '/api/tiktok/post',
  async (request) => {
    const { videoPath, caption, hashtags } = request.body;
    // TODO: Implement in Phase 4
    return {
      success: false,
      message: 'TikTok posting will be implemented in Phase 4',
      params: { videoPath, caption, hashtags },
    };
  },
);

app.get<{ Params: { videoId: string } }>(
  '/api/tiktok/comments/:videoId',
  async (request) => {
    const { videoId } = request.params;
    // TODO: Implement in Phase 4
    return {
      videoId,
      comments: [],
      message: 'Comment scraping will be implemented in Phase 4',
    };
  },
);

app.post<{ Body: { profileUrl: string } }>(
  '/api/tiktok/scrape-profile',
  async (request) => {
    const { profileUrl } = request.body;
    // TODO: Implement in Phase 4
    return {
      profileUrl,
      data: null,
      message: 'Profile scraping will be implemented in Phase 4',
    };
  },
);

// --- General Utilities ---
app.post<{ Body: { url: string } }>(
  '/api/screenshot',
  async (request) => {
    const { url } = request.body;
    // TODO: Implement screenshot capture
    return {
      url,
      screenshot: null,
      message: 'Screenshot capture will be implemented in Phase 4',
    };
  },
);

// --- Start ---
const port = Number(process.env.PLAYWRIGHT_PORT ?? 3100);
try {
  await app.listen({ port, host: '0.0.0.0' });
  app.log.info(`Playwright service listening on port ${port}`);
  app.log.info('noVNC should be available at http://localhost:6080');
} catch (err) {
  app.log.fatal(err, 'Failed to start Playwright service');
  process.exit(1);
}
