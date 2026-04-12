import { logger } from '../lib/logger.js';

const GRAPH_API = 'https://graph.facebook.com/v19.0';

// ── Response types ─────────────────────────────────────────────────

interface IGMediaContainer {
  id: string;
}

interface IGPublishResult {
  id: string;
}

interface IGStatusResponse {
  status_code: string;
}

export interface IGComment {
  id: string;
  text: string;
  username: string;
  timestamp: string;
}

export interface IGMedia {
  id: string;
  caption: string;
  media_type: string;
  timestamp: string;
  permalink: string;
}

export interface IGConversation {
  id: string;
  participants: string[];
}

// ── Client ─────────────────────────────────────────────────────────

/**
 * Instagram Graph API client.
 *
 * Requires an Instagram Business Account ID and a long-lived
 * Facebook Page access token with `instagram_basic`,
 * `instagram_content_publish`, and `instagram_manage_comments` scopes.
 */
export class InstagramClient {
  constructor(
    private accessToken: string,
    private igUserId: string,
  ) {
    if (!accessToken) {
      logger.warn('InstagramClient instantiated without an access token — API calls will fail');
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────

  private async request<T>(
    method: string,
    path: string,
    body?: Record<string, unknown>,
  ): Promise<T> {
    const url = new URL(`${GRAPH_API}${path}`);
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
        'Instagram Graph API request failed',
      );
      throw new Error(`Instagram API error (${res.status}): ${text.slice(0, 300)}`);
    }

    return (await res.json()) as T;
  }

  /**
   * Poll a media container until its status is FINISHED or until
   * `timeoutMs` has elapsed.
   */
  private async waitForContainer(
    containerId: string,
    timeoutMs = 60_000,
  ): Promise<void> {
    const start = Date.now();
    const interval = 3_000;

    while (Date.now() - start < timeoutMs) {
      const { status_code } = await this.request<IGStatusResponse>(
        'GET',
        `/${containerId}?fields=status_code`,
      );

      if (status_code === 'FINISHED') return;

      if (status_code === 'ERROR') {
        throw new Error(`Media container ${containerId} entered ERROR state`);
      }

      await new Promise((resolve) => setTimeout(resolve, interval));
    }

    throw new Error(
      `Timed out waiting for container ${containerId} (${timeoutMs}ms)`,
    );
  }

  // ── Public API ───────────────────────────────────────────────────

  /**
   * Publish a single image post.
   */
  async publishImage(
    imageUrl: string,
    caption: string,
  ): Promise<{ id: string }> {
    // Step 1 — create media container
    const container = await this.request<IGMediaContainer>(
      'POST',
      `/${this.igUserId}/media`,
      { image_url: imageUrl, caption },
    );

    // Step 2 — publish
    const result = await this.request<IGPublishResult>(
      'POST',
      `/${this.igUserId}/media_publish`,
      { creation_id: container.id },
    );

    logger.info({ mediaId: result.id }, 'Instagram image published');
    return { id: result.id };
  }

  /**
   * Publish a carousel (2–10 images).
   */
  async publishCarousel(
    imageUrls: string[],
    caption: string,
  ): Promise<{ id: string }> {
    if (imageUrls.length < 2 || imageUrls.length > 10) {
      throw new Error('Carousel requires between 2 and 10 images');
    }

    // Step 1 — create individual image containers
    const children: string[] = [];
    for (const url of imageUrls) {
      const container = await this.request<IGMediaContainer>(
        'POST',
        `/${this.igUserId}/media`,
        { image_url: url, is_carousel_item: true },
      );
      children.push(container.id);
    }

    // Step 2 — create carousel container
    const carousel = await this.request<IGMediaContainer>(
      'POST',
      `/${this.igUserId}/media`,
      { media_type: 'CAROUSEL', caption, children },
    );

    // Step 3 — publish
    const result = await this.request<IGPublishResult>(
      'POST',
      `/${this.igUserId}/media_publish`,
      { creation_id: carousel.id },
    );

    logger.info({ mediaId: result.id, count: imageUrls.length }, 'Instagram carousel published');
    return { id: result.id };
  }

  /**
   * Publish a reel (video).
   *
   * The video is uploaded by URL; the API processes it asynchronously,
   * so we poll the container status before publishing (max 60 s).
   */
  async publishReel(
    videoUrl: string,
    caption: string,
  ): Promise<{ id: string }> {
    // Step 1 — create reel container
    const container = await this.request<IGMediaContainer>(
      'POST',
      `/${this.igUserId}/media`,
      { video_url: videoUrl, caption, media_type: 'REELS' },
    );

    // Step 2 — poll until processing finishes
    await this.waitForContainer(container.id, 60_000);

    // Step 3 — publish
    const result = await this.request<IGPublishResult>(
      'POST',
      `/${this.igUserId}/media_publish`,
      { creation_id: container.id },
    );

    logger.info({ mediaId: result.id }, 'Instagram reel published');
    return { id: result.id };
  }

  /**
   * Get comments on a media object.
   */
  async getComments(
    mediaId: string,
  ): Promise<IGComment[]> {
    const result = await this.request<{ data: IGComment[] }>(
      'GET',
      `/${mediaId}/comments?fields=id,text,username,timestamp`,
    );
    return result.data;
  }

  /**
   * Reply to a comment.
   */
  async replyToComment(
    commentId: string,
    text: string,
  ): Promise<{ id: string }> {
    const result = await this.request<{ id: string }>(
      'POST',
      `/${commentId}/replies`,
      { message: text },
    );

    logger.info({ commentId, replyId: result.id }, 'Instagram comment reply sent');
    return { id: result.id };
  }

  /**
   * Get recent media for the connected Instagram account.
   */
  async getRecentMedia(
    limit = 25,
  ): Promise<Array<{
    id: string;
    caption: string;
    mediaType: string;
    timestamp: string;
    permalink: string;
  }>> {
    const result = await this.request<{ data: IGMedia[] }>(
      'GET',
      `/${this.igUserId}/media?fields=id,caption,media_type,timestamp,permalink&limit=${limit}`,
    );

    return result.data.map((m) => ({
      id: m.id,
      caption: m.caption,
      mediaType: m.media_type,
      timestamp: m.timestamp,
      permalink: m.permalink,
    }));
  }

  /**
   * Get conversations (DM threads) for the Instagram account.
   */
  async getConversations(): Promise<IGConversation[]> {
    const result = await this.request<{
      data: Array<{
        id: string;
        participants: { data: Array<{ id: string }> };
      }>;
    }>('GET', `/${this.igUserId}/conversations`);

    return result.data.map((c) => ({
      id: c.id,
      participants: c.participants.data.map((p) => p.id),
    }));
  }

  /**
   * Send a direct message to a user.
   */
  async sendDirectMessage(
    recipientId: string,
    text: string,
  ): Promise<{ id: string }> {
    const result = await this.request<{ id: string }>(
      'POST',
      `/${this.igUserId}/messages`,
      {
        recipient: { id: recipientId },
        message: { text },
      },
    );

    logger.info({ recipientId, messageId: result.id }, 'Instagram DM sent');
    return { id: result.id };
  }

  /**
   * Exchange a short-lived or expiring long-lived token for a new
   * 60-day long-lived token.
   *
   * Requires `FACEBOOK_APP_ID` and `FACEBOOK_APP_SECRET` env vars.
   */
  async refreshToken(): Promise<string> {
    const appId = process.env.FACEBOOK_APP_ID;
    const appSecret = process.env.FACEBOOK_APP_SECRET;

    if (!appId || !appSecret) {
      throw new Error(
        'FACEBOOK_APP_ID and FACEBOOK_APP_SECRET must be set to refresh tokens',
      );
    }

    const url = new URL(`${GRAPH_API}/oauth/access_token`);
    url.searchParams.set('grant_type', 'fb_exchange_token');
    url.searchParams.set('client_id', appId);
    url.searchParams.set('client_secret', appSecret);
    url.searchParams.set('fb_exchange_token', this.accessToken);

    const res = await fetch(url.toString());

    if (!res.ok) {
      const text = await res.text().catch(() => '(unreadable)');
      throw new Error(`Token refresh failed (${res.status}): ${text.slice(0, 300)}`);
    }

    const data = (await res.json()) as { access_token: string };
    this.accessToken = data.access_token;

    logger.info('Instagram access token refreshed');
    return data.access_token;
  }
}
