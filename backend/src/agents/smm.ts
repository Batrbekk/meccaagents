import { BaseAgent } from './base-agent.js';
import { getOpenRouter } from '../lib/openrouter.js';
import { publish } from '../lib/pubsub.js';
import { approvalTasks } from '../db/schema.js';
import { logger } from '../lib/logger.js';
import type { ToolDefinition, ToolContext } from './types.js';

/**
 * SMMAgent — analyses social-media trends, writes posts, generates visuals
 * and reels, and queues posts for human approval before publishing.
 */
export class SMMAgent extends BaseAgent {
  constructor() {
    super('smm');
  }

  // ── Tool definitions ────────────────────────────────────────────────

  getTools(): ToolDefinition[] {
    return [
      {
        type: 'function',
        function: {
          name: 'analyze_trends',
          description:
            'Search for and analyze current social media trends on a given topic.',
          parameters: {
            type: 'object',
            properties: {
              topic: {
                type: 'string',
                description: 'The topic to research trends for',
              },
              platform: {
                type: 'string',
                enum: ['instagram', 'tiktok', 'threads', 'twitter', 'youtube'],
                description: 'Target platform to focus on (optional)',
              },
            },
            required: ['topic'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'write_post',
          description:
            'Generate social media post text with hashtags for a specific platform.',
          parameters: {
            type: 'object',
            properties: {
              topic: {
                type: 'string',
                description: 'The topic of the post',
              },
              platform: {
                type: 'string',
                enum: ['instagram', 'tiktok', 'threads'],
                description: 'Target platform',
              },
              tone: {
                type: 'string',
                description:
                  'Desired tone (e.g. professional, casual, humorous, inspirational). Optional.',
              },
            },
            required: ['topic', 'platform'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'create_visual',
          description:
            'Generate an image for a social media post using AI.',
          parameters: {
            type: 'object',
            properties: {
              prompt: {
                type: 'string',
                description: 'Image generation prompt',
              },
              platform: {
                type: 'string',
                enum: ['instagram', 'tiktok', 'threads'],
                description:
                  'Target platform (determines aspect ratio: instagram 1:1, tiktok 9:16, threads 1:1)',
              },
            },
            required: ['prompt', 'platform'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'create_reel',
          description:
            'Generate a short video / reel using AI.',
          parameters: {
            type: 'object',
            properties: {
              prompt: {
                type: 'string',
                description: 'Video generation prompt',
              },
              duration: {
                type: 'number',
                description: 'Desired duration in seconds (optional)',
              },
            },
            required: ['prompt'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'schedule_post',
          description:
            'Queue a social media post for human approval before publishing.',
          parameters: {
            type: 'object',
            properties: {
              platform: {
                type: 'string',
                enum: ['instagram', 'tiktok', 'threads'],
                description: 'Target platform',
              },
              text: {
                type: 'string',
                description: 'The post text / caption',
              },
              mediaUrl: {
                type: 'string',
                description: 'URL of the attached media (image or video). Optional.',
              },
            },
            required: ['platform', 'text'],
          },
        },
      },
    ];
  }

  // ── Tool handler dispatch ───────────────────────────────────────────

  async handleToolCall(
    name: string,
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    switch (name) {
      case 'analyze_trends':
        return this.analyzeTrends(args, context);
      case 'write_post':
        return this.writePost(args, context);
      case 'create_visual':
        return this.createVisual(args, context);
      case 'create_reel':
        return this.createReel(args, context);
      case 'schedule_post':
        return this.schedulePost(args, context);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  }

  // ── Tool implementations ────────────────────────────────────────────

  private async analyzeTrends(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const topic = args.topic as string;
    const platform = args.platform as string | undefined;

    const config = await this.getConfig(context.db);

    const platformNote = platform ? ` on ${platform}` : '';

    const response = await getOpenRouter().chat({
      model: config.model,
      temperature: config.temperature,
      messages: [
        {
          role: 'system',
          content:
            'You are a social media marketing expert. Analyze trends and provide actionable insights.',
        },
        {
          role: 'user',
          content: `Search for current social media trends about "${topic}"${platformNote}. Provide a detailed analysis including: trending formats, popular hashtags, engagement patterns, and recommendations for content strategy.`,
        },
      ],
      tools: [{ type: 'openrouter:web_search' }],
    });

    const analysis = response.content ?? '';

    logger.info(
      { topic, platform, threadId: context.threadId },
      'Trend analysis completed',
    );

    return {
      analysis,
      topic,
      platform: platform ?? 'all',
    };
  }

  private async writePost(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const topic = args.topic as string;
    const platform = args.platform as 'instagram' | 'tiktok' | 'threads';
    const tone = args.tone as string | undefined;

    const config = await this.getConfig(context.db);

    const toneNote = tone ? ` The tone should be ${tone}.` : '';

    const response = await getOpenRouter().chat({
      model: config.model,
      temperature: config.temperature,
      messages: [
        {
          role: 'system',
          content:
            'You are a professional social media copywriter. Write engaging posts optimized for each platform. Always include relevant hashtags.',
        },
        {
          role: 'user',
          content: `Write a ${platform} post about "${topic}".${toneNote} Include appropriate hashtags for ${platform}. Make it engaging and optimized for ${platform}'s algorithm and audience.`,
        },
      ],
    });

    const postText = response.content ?? '';

    return {
      post: postText,
      topic,
      platform,
      tone: tone ?? 'default',
    };
  }

  private async createVisual(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const prompt = args.prompt as string;
    const platform = args.platform as 'instagram' | 'tiktok' | 'threads';

    // Platform-specific aspect ratios
    const aspectRatioMap: Record<string, string> = {
      instagram: '1:1',
      tiktok: '9:16',
      threads: '1:1',
    };
    const aspectRatio = aspectRatioMap[platform] ?? '1:1';

    logger.info(
      { prompt, platform, aspectRatio, threadId: context.threadId },
      'Generating social media visual',
    );

    const result = await getOpenRouter().generateImage({
      model: 'google/gemini-3-pro-image-preview',
      prompt,
      imageConfig: { aspectRatio },
    });

    const imageUrl = result.images[0]?.url ?? null;

    logger.info(
      { imageUrl: imageUrl ? '(received)' : '(none)', model: result.model },
      'Social media visual generation complete',
    );

    // Create approval task
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'smm',
        actionType: 'social_media_visual',
        payload: {
          imageUrl,
          prompt,
          platform,
          aspectRatio,
          model: result.model,
        },
        status: 'pending',
        threadId: context.threadId,
      })
      .returning();

    await publish(`thread:${context.threadId}:approvals`, {
      type: 'new_approval',
      approval: task,
    });

    logger.info(
      { approvalId: task!.id, threadId: context.threadId },
      'Social media visual approval task created',
    );

    return {
      imageUrl,
      approvalId: task!.id,
      status: 'pending_approval',
      platform,
      aspectRatio,
      model: result.model,
    };
  }

  private async createReel(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const prompt = args.prompt as string;
    const duration = args.duration as number | undefined;

    logger.info(
      { prompt, duration, threadId: context.threadId },
      'Generating reel video via OpenRouter',
    );

    const result = await getOpenRouter().generateVideoAndWait(
      {
        model: 'google/veo-2.5-flash',
        prompt,
        duration,
        generateAudio: true,
      },
      300_000, // 5 minute timeout
    );

    if (result.status === 'failed') {
      throw new Error(
        `Reel generation failed: ${result.error ?? 'unknown error'}`,
      );
    }

    const videoUrls = result.urls ?? [];

    logger.info(
      { videoUrls, status: result.status },
      'Reel video generation complete',
    );

    // Create approval task
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'smm',
        actionType: 'social_media_reel',
        payload: {
          videoUrls,
          prompt,
          duration: duration ?? null,
        },
        status: 'pending',
        threadId: context.threadId,
      })
      .returning();

    await publish(`thread:${context.threadId}:approvals`, {
      type: 'new_approval',
      approval: task,
    });

    logger.info(
      { approvalId: task!.id, threadId: context.threadId },
      'Reel approval task created',
    );

    return {
      videoUrls,
      approvalId: task!.id,
      status: 'pending_approval',
    };
  }

  private async schedulePost(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const platform = args.platform as string;
    const text = args.text as string;
    const mediaUrl = args.mediaUrl as string | undefined;

    // Create approval task — actual publishing will be implemented in Phase 4
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'smm',
        actionType: 'publish_post',
        payload: {
          platform,
          text,
          mediaUrl: mediaUrl ?? null,
        },
        status: 'pending',
        threadId: context.threadId,
      })
      .returning();

    await publish(`thread:${context.threadId}:approvals`, {
      type: 'new_approval',
      approval: task,
    });

    logger.info(
      { approvalId: task!.id, threadId: context.threadId, platform },
      'Post publish approval task created',
    );

    return {
      approvalId: task!.id,
      status: 'pending_approval',
      message: `Post for ${platform} queued for approval`,
    };
  }
}
