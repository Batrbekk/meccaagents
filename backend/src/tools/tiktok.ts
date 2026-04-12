import { logger } from '../lib/logger.js';

const PLAYWRIGHT_URL =
  process.env.PLAYWRIGHT_SERVICE_URL ?? 'http://playwright-service:3100';

// ── Response types ─────────────────────────────────────────────────

export interface TikTokPostResult {
  success: boolean;
  error?: string;
}

export interface TikTokComment {
  username: string;
  text: string;
  likes: number;
}

export interface TikTokProfile {
  followers: number;
  likes: number;
  videos: number;
  recentPosts: Array<Record<string, unknown>>;
}

// ── Client ─────────────────────────────────────────────────────────

/**
 * TikTok client that delegates browser-based automation to a
 * Playwright microservice.
 *
 * The Playwright service manages session cookies, handles CAPTCHAs,
 * and exposes a REST API for TikTok actions that aren't available
 * through an official public API.
 */
export class TikTokClient {
  private baseUrl: string;

  constructor(playwrightUrl?: string) {
    this.baseUrl = playwrightUrl ?? PLAYWRIGHT_URL;
  }

  // ── Internal helpers ─────────────────────────────────────────────

  private async request<T>(
    method: string,
    path: string,
    body?: Record<string, unknown>,
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;

    const init: RequestInit = {
      method,
      headers: { 'Content-Type': 'application/json' },
    };

    if (body !== undefined) {
      init.body = JSON.stringify(body);
    }

    let res: Response;
    try {
      res = await fetch(url, init);
    } catch (err) {
      const message =
        err instanceof Error ? err.message : 'Unknown network error';
      logger.error({ url, error: message }, 'Playwright service unreachable');
      throw new Error(`Playwright service unreachable (${url}): ${message}`);
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '(unreadable)');
      logger.error(
        { status: res.status, path, body: text.slice(0, 500) },
        'Playwright service request failed',
      );
      throw new Error(
        `Playwright service error (${res.status}): ${text.slice(0, 300)}`,
      );
    }

    return (await res.json()) as T;
  }

  // ── Public API ───────────────────────────────────────────────────

  /**
   * Check whether the stored TikTok browser session is still valid.
   */
  async isSessionValid(): Promise<boolean> {
    try {
      const result = await this.request<{ valid: boolean }>(
        'GET',
        '/api/sessions/tiktok/status',
      );
      return result.valid;
    } catch {
      logger.warn('TikTok session check failed — treating as invalid');
      return false;
    }
  }

  /**
   * Post a video to TikTok.
   *
   * `videoPath` should be an absolute path accessible to the Playwright
   * service container (e.g. a shared volume mount).
   */
  async postVideo(
    videoPath: string,
    caption: string,
    hashtags?: string[],
  ): Promise<TikTokPostResult> {
    const result = await this.request<TikTokPostResult>(
      'POST',
      '/api/tiktok/post',
      { videoPath, caption, hashtags: hashtags ?? [] },
    );

    if (result.success) {
      logger.info({ caption: caption.slice(0, 80) }, 'TikTok video posted');
    } else {
      logger.error({ error: result.error }, 'TikTok video post failed');
    }

    return result;
  }

  /**
   * Get comments on a TikTok video by its video ID.
   */
  async getComments(videoId: string): Promise<TikTokComment[]> {
    const result = await this.request<{ comments: TikTokComment[] }>(
      'GET',
      `/api/tiktok/comments/${encodeURIComponent(videoId)}`,
    );
    return result.comments;
  }

  /**
   * Scrape a TikTok profile for follower count, likes, video count,
   * and recent posts.
   */
  async scrapeProfile(profileUrl: string): Promise<TikTokProfile> {
    const result = await this.request<TikTokProfile>(
      'POST',
      '/api/tiktok/scrape-profile',
      { profileUrl },
    );

    logger.info(
      { profileUrl, followers: result.followers },
      'TikTok profile scraped',
    );

    return result;
  }
}
