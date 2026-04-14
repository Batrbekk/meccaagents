import { eq } from 'drizzle-orm';
import { agentConfigs, toolLogs } from '../db/schema.js';
import { getOpenRouter, type ChatMessage } from '../lib/openrouter.js';
import { logger } from '../lib/logger.js';
import type { DrizzleDB, ToolDefinition, ToolContext, AgentResponse } from './types.js';

const MAX_TOOL_ITERATIONS = 5;

export abstract class BaseAgent {
  slug: string;

  constructor(slug: string) {
    this.slug = slug;
  }

  /**
   * Load the agent's configuration from the `agent_configs` table.
   */
  async getConfig(db: DrizzleDB) {
    const [config] = await db
      .select()
      .from(agentConfigs)
      .where(eq(agentConfigs.slug, this.slug))
      .limit(1);

    if (!config) {
      throw new Error(`Agent config not found for slug: ${this.slug}`);
    }
    return config;
  }

  /**
   * Execute a full agent turn: build messages, call OpenRouter, handle tool
   * calls in a loop, and return the final response.
   */
  async execute(params: {
    db: DrizzleDB;
    threadId: string;
    userMessage: string;
    context: Array<{ role: string; content: string }>;
  }): Promise<AgentResponse> {
    const { db, threadId, userMessage, context } = params;
    const config = await this.getConfig(db);

    // Build the conversation messages array
    const conversationMessages: ChatMessage[] = [
      { role: 'system', content: config.systemPrompt },
      ...context.map((m) => ({
        role: m.role as ChatMessage['role'],
        content: m.content,
      })),
      { role: 'user' as const, content: userMessage },
    ];

    // Merge agent-defined tools with any tools stored in config
    const tools = this.getTools();
    let allToolCalls: Array<{ name: string; args: Record<string, unknown>; result: unknown }> = [];
    let totalUsage = { promptTokens: 0, completionTokens: 0, totalTokens: 0 };

    for (let iteration = 0; iteration < MAX_TOOL_ITERATIONS; iteration++) {
      const client = getOpenRouter();
      const response = await client.chat({
        model: config.model,
        temperature: config.temperature,
        messages: conversationMessages,
        tools: tools.length > 0 ? tools : undefined,
      });

      // Accumulate usage
      if (response.usage) {
        totalUsage.promptTokens += response.usage.promptTokens ?? 0;
        totalUsage.completionTokens += response.usage.completionTokens ?? 0;
        totalUsage.totalTokens += response.usage.totalTokens ?? 0;
      }

      // No tool calls -- we're done
      if (!response.toolCalls || response.toolCalls.length === 0) {
        return {
          content: response.content ?? '',
          toolCalls: allToolCalls,
          usage: totalUsage,
        };
      }

      // Process each tool call
      for (const toolCall of response.toolCalls) {
        const toolName = toolCall.function.name;
        const toolArgs = JSON.parse(toolCall.function.arguments ?? '{}') as Record<string, unknown>;
        const startMs = Date.now();

        let result: unknown;
        let status: 'success' | 'error' = 'success';
        let errorMessage: string | undefined;

        try {
          result = await this.handleToolCall(toolName, toolArgs, {
            db,
            threadId,
            agentSlug: this.slug,
          });
        } catch (err) {
          status = 'error';
          errorMessage = err instanceof Error ? err.message : String(err);
          result = { error: errorMessage };
          logger.error({ err, toolName, toolArgs, agent: this.slug }, 'Tool call failed');
        }

        const durationMs = Date.now() - startMs;

        // Log tool call to the database
        await db.insert(toolLogs).values({
          agentSlug: this.slug,
          toolName,
          input: toolArgs,
          output: result as Record<string, unknown>,
          durationMs,
          status,
          errorMessage: errorMessage ?? null,
        });

        allToolCalls.push({ name: toolName, args: toolArgs, result });

        // Append the assistant's tool-call message and the tool result to
        // the conversation so OpenRouter can continue reasoning.
        conversationMessages.push({
          role: 'assistant',
          content: JSON.stringify({
            tool_calls: [
              {
                id: toolCall.id,
                type: 'function',
                function: { name: toolName, arguments: toolCall.function.arguments },
              },
            ],
          }),
        });

        conversationMessages.push({
          role: 'tool',
          content: JSON.stringify(result),
          tool_call_id: toolCall.id,
        });
      }
    }

    // If we exhausted iterations, return what we have
    logger.warn({ agent: this.slug, threadId }, 'Max tool iterations reached');
    return {
      content: 'I completed several steps but reached my processing limit. Here is what I accomplished so far.',
      toolCalls: allToolCalls,
      usage: totalUsage,
    };
  }

  /**
   * Return the tool definitions available to this agent.
   * Override in subclasses to provide agent-specific tools.
   */
  abstract getTools(): ToolDefinition[];

  /**
   * Handle a specific tool call. Override in subclasses.
   */
  abstract handleToolCall(
    name: string,
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown>;
}
