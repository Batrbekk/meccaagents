import { logger } from '../lib/logger.js';

const THREADS_API = 'https://graph.threads.net/v1.0';

// ── Response types ─────────────────────────────────────────────────

interface ThreadsContainer {
  id: string;
}

interface ThreadsPublishResult {
  id: string;
}

export interface ThreadsPost {
  id: string;
  text: string;
  timestamp: string;
}

export interface ThreadsReply {
  id: string;
  text: string;
  username: string;
}

// ── Client ─────────────────────────────────────────────────────────

/**
 * Threads API client.
 *
 * Requires a Threads-scoped access token and the Threads user ID.
 * The token must have `threads_basic`, `threads_content_publish`,
 * and `threads_manage_replies` scopes.
 */
export class ThreadsClient {
  constructor(
    private accessToken: string,
    private userId: string,
  ) {
    if (!accessToken) {
      logger.warn('ThreadsClient instantiated without an access token — API calls will fail');
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────

  private async request<T>(
    method: string,
    path: string,
    body?: Record<string, unknown>,
  ): Promise<T> {
    const url = new URL(`${THREADS_API}${path}`);
    url.searchParams.set('access_token', this.accessToken);

    const init: RequestInit = { method };

    if (body !== undefined) {
      init.headers = { 'Content-Type': 'application/json' };
      init.body = JSON.stringify(body);
    }

    const res = await fetch(url.toString(), init);

    if (!res.ok) {
      const text = await res.text().catch(() => '(unreadable)');
      logger.error(
        { status: res.status, path, body: text.slice(0, 500) },
        'Threads API request failed',
      );
      throw new Error(`Threads API error (${res.status}): ${text.slice(0, 300)}`);
    }

    return (await res.json()) as T;
  }

  /**
   * Two-step publish helper: create a container then publish it.
   */
  private async createAndPublish(
    containerPayload: Record<string, unknown>,
  ): Promise<{ id: string }> {
    // Step 1 — create media container
    const container = await this.request<ThreadsContainer>(
      'POST',
      `/${this.userId}/threads`,
      containerPayload,
    );

    // Step 2 — publish
    const result = await this.request<ThreadsPublishResult>(
      'POST',
      `/${this.userId}/threads_publish`,
      { creation_id: container.id },
    );

    return { id: result.id };
  }

  // ── Public API ───────────────────────────────────────────────────

  /**
   * Publish a text-only thread.
   */
  async publishText(text: string): Promise<{ id: string }> {
    const result = await this.createAndPublish({
      media_type: 'TEXT',
      text,
    });

    logger.info({ threadId: result.id }, 'Threads text post published');
    return result;
  }

  /**
   * Publish an image thread with optional text.
   */
  async publishImage(
    imageUrl: string,
    text?: string,
  ): Promise<{ id: string }> {
    const payload: Record<string, unknown> = {
      media_type: 'IMAGE',
      image_url: imageUrl,
    };
    if (text) payload.text = text;

    const result = await this.createAndPublish(payload);

    logger.info({ threadId: result.id }, 'Threads image post published');
    return result;
  }

  /**
   * Publish a video thread with optional text.
   */
  async publishVideo(
    videoUrl: string,
    text?: string,
  ): Promise<{ id: string }> {
    const payload: Record<string, unknown> = {
      media_type: 'VIDEO',
      video_url: videoUrl,
    };
    if (text) payload.text = text;

    const result = await this.createAndPublish(payload);

    logger.info({ threadId: result.id }, 'Threads video post published');
    return result;
  }

  /**
   * Get the authenticated user's recent threads.
   */
  async getRecentThreads(
    limit = 25,
  ): Promise<ThreadsPost[]> {
    const result = await this.request<{ data: ThreadsPost[] }>(
      'GET',
      `/${this.userId}/threads?fields=id,text,timestamp&limit=${limit}`,
    );
    return result.data;
  }

  /**
   * Get replies to a specific thread.
   */
  async getReplies(threadId: string): Promise<ThreadsReply[]> {
    const result = await this.request<{ data: ThreadsReply[] }>(
      'GET',
      `/${threadId}/replies?fields=id,text,username`,
    );
    return result.data;
  }

  /**
   * Reply to an existing thread.
   */
  async replyToThread(
    threadId: string,
    text: string,
  ): Promise<{ id: string }> {
    const result = await this.createAndPublish({
      media_type: 'TEXT',
      text,
      reply_to_id: threadId,
    });

    logger.info({ parentThreadId: threadId, replyId: result.id }, 'Threads reply published');
    return result;
  }
}
