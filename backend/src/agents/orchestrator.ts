import { BaseAgent } from './base-agent.js';
import { enqueueAgentJob } from '../workers/agent-runner.js';
import { logger } from '../lib/logger.js';
import type { ToolDefinition, ToolContext } from './types.js';

const AGENT_SLUGS = ['lawyer', 'content', 'smm', 'sales'] as const;
type AgentSlug = (typeof AGENT_SLUGS)[number];

/**
 * The Orchestrator agent receives every user message and decides which
 * specialist agent(s) should handle it.  It can either use the
 * `route_to_agent` tool (via the LLM) or detect explicit @mentions in
 * the message text.
 */
export class OrchestratorAgent extends BaseAgent {
  constructor() {
    super('orchestrator');
  }

  getTools(): ToolDefinition[] {
    return [
      {
        type: 'function',
        function: {
          name: 'route_to_agent',
          description:
            'Route the current task to a specialist agent. Use this when the user request should be handled by a specific agent.',
          parameters: {
            type: 'object',
            properties: {
              agent: {
                type: 'string',
                enum: [...AGENT_SLUGS],
                description: 'The slug of the target agent',
              },
              task_summary: {
                type: 'string',
                description:
                  'A brief summary of what the agent should do, including all relevant context from the conversation',
              },
            },
            required: ['agent', 'task_summary'],
          },
        },
      },
    ];
  }

  async handleToolCall(
    name: string,
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    if (name !== 'route_to_agent') {
      throw new Error(`Unknown tool: ${name}`);
    }

    const agent = args.agent as string;
    const taskSummary = args.task_summary as string;

    if (!AGENT_SLUGS.includes(agent as AgentSlug)) {
      throw new Error(`Invalid agent slug: ${agent}. Valid agents: ${AGENT_SLUGS.join(', ')}`);
    }

    logger.info(
      { agent, taskSummary, threadId: context.threadId },
      'Orchestrator routing to agent',
    );

    await enqueueAgentJob({
      threadId: context.threadId,
      agentSlug: agent,
      userMessage: taskSummary,
      triggeredBy: 'orchestrator',
    });

    return {
      routed: true,
      agent,
      task_summary: taskSummary,
      message: `Task has been routed to the ${agent} agent.`,
    };
  }

  /**
   * Override execute to first check for @mentions. If an explicit @mention
   * is found, route directly without calling the LLM.
   */
  async execute(params: {
    db: import('./types.js').DrizzleDB;
    threadId: string;
    userMessage: string;
    context: Array<{ role: string; content: string }>;
  }) {
    const mentionedAgents = this.detectMentions(params.userMessage);

    if (mentionedAgents.length > 0) {
      logger.info(
        { agents: mentionedAgents, threadId: params.threadId },
        'Orchestrator detected @mentions, routing directly',
      );

      const routed: string[] = [];

      for (const agent of mentionedAgents) {
        await enqueueAgentJob({
          threadId: params.threadId,
          agentSlug: agent,
          userMessage: params.userMessage,
          triggeredBy: 'orchestrator',
        });
        routed.push(agent);
      }

      return {
        content: `Routing your message to: ${routed.join(', ')}. They will respond shortly.`,
        toolCalls: routed.map((a) => ({
          name: 'route_to_agent',
          args: { agent: a, task_summary: params.userMessage },
          result: { routed: true, agent: a },
        })),
        usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 },
      };
    }

    // No @mentions -- fall through to LLM-based routing
    return super.execute(params);
  }

  /**
   * Detect @agent mentions in the message text.
   * Matches patterns like @lawyer, @content, @smm, @sales.
   */
  private detectMentions(message: string): AgentSlug[] {
    const found: AgentSlug[] = [];
    for (const slug of AGENT_SLUGS) {
      const pattern = new RegExp(`@${slug}\\b`, 'i');
      if (pattern.test(message)) {
        found.push(slug);
      }
    }
    return found;
  }
}
