import { BaseAgent } from './base-agent.js';
import { openrouter } from '../lib/openrouter.js';
import { publish } from '../lib/pubsub.js';
import { approvalTasks } from '../db/schema.js';
import { logger } from '../lib/logger.js';
import type { ToolDefinition, ToolContext } from './types.js';

/**
 * ContentAgent — generates content plans, scripts, images, and videos.
 *
 * Every generative action creates an approval task so a human can
 * approve / reject / modify the output before it goes live.
 */
export class ContentAgent extends BaseAgent {
  constructor() {
    super('content');
  }

  // ── Tool definitions ────────────────────────────────────────────────

  getTools(): ToolDefinition[] {
    return [
      {
        type: 'function',
        function: {
          name: 'generate_content_plan',
          description:
            'Generate a content plan for specified platforms over a given period.',
          parameters: {
            type: 'object',
            properties: {
              topic: {
                type: 'string',
                description: 'The topic or theme for the content plan',
              },
              period: {
                type: 'string',
                enum: ['week', 'month'],
                description: 'The planning period',
              },
              platforms: {
                type: 'array',
                items: { type: 'string' },
                description:
                  'Target platforms (e.g. instagram, tiktok, youtube)',
              },
            },
            required: ['topic', 'period', 'platforms'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'write_script',
          description:
            'Write a script for a short-form or long-form piece of content.',
          parameters: {
            type: 'object',
            properties: {
              topic: {
                type: 'string',
                description: 'The topic of the script',
              },
              format: {
                type: 'string',
                enum: ['reels', 'tiktok', 'post', 'story'],
                description: 'The content format',
              },
              duration_seconds: {
                type: 'number',
                description: 'Desired duration in seconds (optional)',
              },
            },
            required: ['topic', 'format'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'generate_image',
          description:
            'Generate an image using AI based on a text prompt.',
          parameters: {
            type: 'object',
            properties: {
              prompt: {
                type: 'string',
                description: 'The image generation prompt',
              },
              aspect_ratio: {
                type: 'string',
                description:
                  'Aspect ratio (e.g. "1:1", "16:9", "9:16"). Defaults to "1:1".',
              },
            },
            required: ['prompt'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'generate_video',
          description:
            'Generate a video using AI based on a text prompt.',
          parameters: {
            type: 'object',
            properties: {
              prompt: {
                type: 'string',
                description: 'The video generation prompt',
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
    ];
  }

  // ── Tool handler dispatch ───────────────────────────────────────────

  async handleToolCall(
    name: string,
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    switch (name) {
      case 'generate_content_plan':
        return this.generateContentPlan(args, context);
      case 'write_script':
        return this.writeScript(args, context);
      case 'generate_image':
        return this.generateImage(args, context);
      case 'generate_video':
        return this.generateVideo(args, context);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  }

  // ── Tool implementations ────────────────────────────────────────────

  private async generateContentPlan(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const topic = args.topic as string;
    const period = args.period as 'week' | 'month';
    const platforms = args.platforms as string[];

    const config = await this.getConfig(context.db);

    const response = await openrouter.chat({
      model: config.model,
      temperature: config.temperature,
      messages: [
        {
          role: 'system',
          content:
            'You are a professional social-media content strategist. Create detailed, actionable content plans.',
        },
        {
          role: 'user',
          content: `Create a ${period}ly content plan for the topic "${topic}" targeting these platforms: ${platforms.join(', ')}. Include post types, suggested captions, optimal posting times, and hashtag strategies.`,
        },
      ],
    });

    const planText = response.content ?? '';

    // Create approval task
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'content',
        actionType: 'content_plan',
        payload: {
          content: planText,
          topic,
          period,
          platforms,
        },
        status: 'pending',
        threadId: context.threadId,
      })
      .returning();

    // Notify via pubsub
    await publish(`thread:${context.threadId}:approvals`, {
      type: 'new_approval',
      approval: task,
    });

    logger.info(
      { approvalId: task!.id, threadId: context.threadId },
      'Content plan approval task created',
    );

    return {
      plan: planText,
      approvalId: task!.id,
      status: 'pending_approval',
    };
  }

  private async writeScript(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const topic = args.topic as string;
    const format = args.format as 'reels' | 'tiktok' | 'post' | 'story';
    const durationSeconds = args.duration_seconds as number | undefined;

    const config = await this.getConfig(context.db);

    const durationNote = durationSeconds
      ? ` The content should be approximately ${durationSeconds} seconds long.`
      : '';

    const response = await openrouter.chat({
      model: config.model,
      temperature: config.temperature,
      messages: [
        {
          role: 'system',
          content:
            'You are a professional content writer and scriptwriter specializing in social media content. Write engaging, concise scripts.',
        },
        {
          role: 'user',
          content: `Write a ${format} script about "${topic}".${durationNote} Include hook, body, and call-to-action. Format it clearly with scene directions if applicable.`,
        },
      ],
    });

    const scriptText = response.content ?? '';

    return {
      script: scriptText,
      format,
      topic,
      durationSeconds: durationSeconds ?? null,
    };
  }

  private async generateImage(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const prompt = args.prompt as string;
    const aspectRatio = (args.aspect_ratio as string) ?? '1:1';

    logger.info(
      { prompt, aspectRatio, threadId: context.threadId },
      'Generating image via OpenRouter',
    );

    const result = await openrouter.generateImage({
      model: 'black-forest-labs/flux-1.1-pro',
      prompt,
      imageConfig: { aspectRatio },
    });

    const imageUrl = result.images[0]?.url ?? null;

    logger.info(
      { imageUrl: imageUrl ? '(received)' : '(none)', model: result.model },
      'Image generation complete',
    );

    // Create approval task
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'content',
        actionType: 'generated_image',
        payload: {
          imageUrl,
          prompt,
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
      'Image approval task created',
    );

    return {
      imageUrl,
      approvalId: task!.id,
      status: 'pending_approval',
      model: result.model,
    };
  }

  private async generateVideo(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const prompt = args.prompt as string;
    const duration = args.duration as number | undefined;

    logger.info(
      { prompt, duration, threadId: context.threadId },
      'Generating video via OpenRouter',
    );

    const result = await openrouter.generateVideoAndWait(
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
        `Video generation failed: ${result.error ?? 'unknown error'}`,
      );
    }

    const videoUrls = result.urls ?? [];

    logger.info(
      { videoUrls, status: result.status },
      'Video generation complete',
    );

    // Create approval task
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'content',
        actionType: 'generated_video',
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
      'Video approval task created',
    );

    return {
      videoUrls,
      approvalId: task!.id,
      status: 'pending_approval',
    };
  }
}
