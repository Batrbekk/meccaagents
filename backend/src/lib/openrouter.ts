import { logger } from './logger.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_call_id?: string;
}

export interface ChatTool {
  type: string;
  function?: {
    name: string;
    description: string;
    parameters: object;
  };
}

export interface ChatParams {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  max_tokens?: number;
  tools?: ChatTool[];
  stream?: boolean;
  response_format?: { type: string };
}

export interface ToolCall {
  id: string;
  type: string;
  function: { name: string; arguments: string };
}

export interface ChatResponse {
  content: string | null;
  toolCalls: ToolCall[] | null;
  usage: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
  model: string;
}

export interface ImageParams {
  model: string;
  prompt: string;
  modalities?: string[];
  imageConfig?: { aspectRatio?: string; imageSize?: string };
}

export interface ImageResult {
  images: Array<{ url: string }>;
  model: string;
}

export interface VideoParams {
  model: string;
  prompt: string;
  aspectRatio?: string;
  duration?: number;
  resolution?: string;
  generateAudio?: boolean;
}

export interface VideoJob {
  pollingUrl: string;
}

export interface VideoResult {
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  urls?: string[];
  error?: string;
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

export class OpenRouterError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public responseBody?: string,
  ) {
    super(message);
    this.name = 'OpenRouterError';
  }
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

export class OpenRouterClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(
    apiKey?: string,
    baseUrl?: string,
  ) {
    this.apiKey = apiKey ?? process.env.OPENROUTER_API_KEY ?? '';
    this.baseUrl = (
      baseUrl ?? process.env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1'
    ).replace(/\/+$/, '');

    if (!this.apiKey) {
      logger.warn('OpenRouterClient instantiated without an API key');
    }
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  private headers(): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${this.apiKey}`,
    };
  }

  /**
   * Perform a fetch with automatic retry on 429 and 5xx errors.
   *
   * - 429: exponential backoff, up to 3 retries (1 s, 2 s, 4 s)
   * - 5xx: single retry after 2 s
   * - Others: throw immediately
   */
  private async fetchWithRetry(
    url: string,
    init: RequestInit,
  ): Promise<Response> {
    const maxRetries429 = 3;
    const base429DelayMs = 1000;
    let retries429 = 0;
    let retried5xx = false;

    // eslint-disable-next-line no-constant-condition
    while (true) {
      const res = await fetch(url, init);

      if (res.ok || res.status === 202) {
        return res;
      }

      const bodySnippet = await res.text().catch(() => '(unreadable)');

      // 429 — rate limit
      if (res.status === 429 && retries429 < maxRetries429) {
        retries429++;
        const delay = base429DelayMs * Math.pow(2, retries429 - 1);
        logger.warn(
          { status: res.status, attempt: retries429, delay },
          `OpenRouter 429 rate-limited — retrying in ${delay} ms`,
        );
        await this.sleep(delay);
        continue;
      }

      // 5xx — server error, retry once
      if (res.status >= 500 && res.status < 600 && !retried5xx) {
        retried5xx = true;
        const delay = 2000;
        logger.warn(
          { status: res.status, delay },
          `OpenRouter ${res.status} server error — retrying in ${delay} ms`,
        );
        await this.sleep(delay);
        continue;
      }

      throw new OpenRouterError(
        res.status,
        `OpenRouter request failed (${res.status}): ${bodySnippet.slice(0, 500)}`,
        bodySnippet,
      );
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  // -----------------------------------------------------------------------
  // 1. Text Chat — non-streaming
  // -----------------------------------------------------------------------

  async chat(params: ChatParams): Promise<ChatResponse> {
    const body: Record<string, unknown> = {
      model: params.model,
      messages: params.messages,
    };
    if (params.temperature !== undefined) body.temperature = params.temperature;
    if (params.max_tokens !== undefined) body.max_tokens = params.max_tokens;
    if (params.tools !== undefined) body.tools = params.tools;
    if (params.response_format !== undefined) body.response_format = params.response_format;
    body.stream = false;

    const res = await this.fetchWithRetry(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    const json = (await res.json()) as Record<string, unknown>;
    return this.parseChatResponse(json);
  }

  // -----------------------------------------------------------------------
  // 1. Text Chat — streaming
  // -----------------------------------------------------------------------

  async *chatStream(params: ChatParams): AsyncGenerator<string> {
    const body: Record<string, unknown> = {
      model: params.model,
      messages: params.messages,
      stream: true,
    };
    if (params.temperature !== undefined) body.temperature = params.temperature;
    if (params.max_tokens !== undefined) body.max_tokens = params.max_tokens;
    if (params.tools !== undefined) body.tools = params.tools;
    if (params.response_format !== undefined) body.response_format = params.response_format;

    // Streaming requests should still honour retry for the initial connection.
    const res = await this.fetchWithRetry(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    if (!res.body) {
      throw new OpenRouterError(0, 'OpenRouter streaming response has no body');
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        // Keep the last (possibly incomplete) line in the buffer.
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed || !trimmed.startsWith('data: ')) continue;

          const payload = trimmed.slice(6); // strip "data: "
          if (payload === '[DONE]') return;

          try {
            const chunk = JSON.parse(payload) as {
              choices?: Array<{
                delta?: { content?: string };
              }>;
            };
            const delta = chunk.choices?.[0]?.delta?.content;
            if (delta) {
              yield delta;
            }
          } catch {
            // Non-JSON SSE line — skip.
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }

  // -----------------------------------------------------------------------
  // 2. Image Generation
  // -----------------------------------------------------------------------

  async generateImage(params: ImageParams): Promise<ImageResult> {
    const messages: ChatMessage[] = [
      { role: 'user', content: params.prompt },
    ];

    const body: Record<string, unknown> = {
      model: params.model,
      messages,
      modalities: params.modalities ?? ['image'],
    };

    if (params.imageConfig) {
      const cfg: Record<string, unknown> = {};
      if (params.imageConfig.aspectRatio !== undefined) cfg.aspect_ratio = params.imageConfig.aspectRatio;
      if (params.imageConfig.imageSize !== undefined) cfg.image_size = params.imageConfig.imageSize;
      body.image_config = cfg;
    }

    const res = await this.fetchWithRetry(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    const json = (await res.json()) as {
      model?: string;
      choices?: Array<{
        message?: {
          images?: string[];
        };
      }>;
    };

    const rawImages = json.choices?.[0]?.message?.images ?? [];
    return {
      images: rawImages.map((url) => ({ url })),
      model: json.model ?? params.model,
    };
  }

  // -----------------------------------------------------------------------
  // 3. Video Generation (async polling)
  // -----------------------------------------------------------------------

  async generateVideo(params: VideoParams): Promise<VideoJob> {
    const body: Record<string, unknown> = {
      model: params.model,
      prompt: params.prompt,
    };
    if (params.aspectRatio !== undefined) body.aspect_ratio = params.aspectRatio;
    if (params.duration !== undefined) body.duration = params.duration;
    if (params.resolution !== undefined) body.resolution = params.resolution;
    if (params.generateAudio !== undefined) body.generate_audio = params.generateAudio;

    const res = await this.fetchWithRetry(`${this.baseUrl}/videos`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    // Expect HTTP 202 with a polling URL header or body field.
    const json = (await res.json()) as { polling_url?: string };
    const pollingUrl =
      res.headers.get('location') ??
      res.headers.get('x-polling-url') ??
      json.polling_url;

    if (!pollingUrl) {
      throw new OpenRouterError(
        res.status,
        'OpenRouter video generation response did not include a polling URL',
      );
    }

    return { pollingUrl };
  }

  async pollVideo(pollingUrl: string): Promise<VideoResult> {
    const res = await this.fetchWithRetry(pollingUrl, {
      method: 'GET',
      headers: this.headers(),
    });

    const json = (await res.json()) as {
      status?: string;
      urls?: string[];
      url?: string;
      error?: string;
    };

    const status = (json.status ?? 'pending') as VideoResult['status'];
    const urls = json.urls ?? (json.url ? [json.url] : undefined);

    return {
      status,
      urls,
      error: json.error,
    };
  }

  async generateVideoAndWait(
    params: VideoParams,
    maxWaitMs = 300_000,
  ): Promise<VideoResult> {
    const job = await this.generateVideo(params);
    const pollIntervalMs = 5000;
    const deadline = Date.now() + maxWaitMs;

    while (Date.now() < deadline) {
      const result = await this.pollVideo(job.pollingUrl);

      if (result.status === 'completed' || result.status === 'failed') {
        return result;
      }

      logger.info(
        { status: result.status, pollingUrl: job.pollingUrl },
        'Video generation in progress — polling again',
      );
      await this.sleep(pollIntervalMs);
    }

    return { status: 'failed', error: `Timed out after ${maxWaitMs} ms` };
  }

  // -----------------------------------------------------------------------
  // 5. Utility
  // -----------------------------------------------------------------------

  async getBalance(): Promise<{ remaining: number }> {
    const res = await this.fetchWithRetry(`${this.baseUrl}/key`, {
      method: 'GET',
      headers: this.headers(),
    });

    const json = (await res.json()) as {
      data?: { limit_remaining?: number };
      limit_remaining?: number;
    };

    const remaining =
      json.data?.limit_remaining ??
      json.limit_remaining ??
      0;

    return { remaining };
  }

  // -----------------------------------------------------------------------
  // Response parsers
  // -----------------------------------------------------------------------

  private parseChatResponse(json: Record<string, unknown>): ChatResponse {
    const choices = json.choices as
      | Array<{
          message?: {
            content?: string | null;
            tool_calls?: Array<{
              id: string;
              type: string;
              function: { name: string; arguments: string };
            }>;
          };
        }>
      | undefined;

    const message = choices?.[0]?.message;
    const usage = json.usage as
      | {
          prompt_tokens?: number;
          completion_tokens?: number;
          total_tokens?: number;
        }
      | undefined;

    const toolCalls = message?.tool_calls?.length
      ? message.tool_calls.map((tc) => ({
          id: tc.id,
          type: tc.type,
          function: { name: tc.function.name, arguments: tc.function.arguments },
        }))
      : null;

    return {
      content: message?.content ?? null,
      toolCalls,
      usage: {
        promptTokens: usage?.prompt_tokens ?? 0,
        completionTokens: usage?.completion_tokens ?? 0,
        totalTokens: usage?.total_tokens ?? 0,
      },
      model: (json.model as string) ?? '',
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton
// ---------------------------------------------------------------------------

export const openrouter = new OpenRouterClient();
