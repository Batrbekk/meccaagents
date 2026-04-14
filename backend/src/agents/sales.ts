import { BaseAgent } from './base-agent.js';
import { getOpenRouter } from '../lib/openrouter.js';
import { publish } from '../lib/pubsub.js';
import { approvalTasks } from '../db/schema.js';
import { logger } from '../lib/logger.js';
import { NotionClient } from '../tools/notion.js';
import type { ToolDefinition, ToolContext } from './types.js';

/**
 * SalesAgent — manages leads in a Notion CRM, generates professional
 * sales responses, and queues proposals for human approval.
 */
export class SalesAgent extends BaseAgent {
  constructor() {
    super('sales');
  }

  // ── Tool definitions ────────────────────────────────────────────────

  getTools(): ToolDefinition[] {
    return [
      {
        type: 'function',
        function: {
          name: 'create_lead',
          description:
            'Create a new lead in the Notion CRM database.',
          parameters: {
            type: 'object',
            properties: {
              name: {
                type: 'string',
                description: 'Full name of the lead',
              },
              phone: {
                type: 'string',
                description: 'Phone number (optional)',
              },
              email: {
                type: 'string',
                description: 'Email address (optional)',
              },
              source: {
                type: 'string',
                enum: ['whatsapp', 'instagram', 'manual'],
                description: 'Lead source channel',
              },
              notes: {
                type: 'string',
                description: 'Additional notes about the lead (optional)',
              },
            },
            required: ['name', 'source'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'update_lead_status',
          description:
            'Update the status and/or notes of an existing lead in Notion CRM.',
          parameters: {
            type: 'object',
            properties: {
              leadId: {
                type: 'string',
                description: 'The Notion page ID of the lead',
              },
              status: {
                type: 'string',
                enum: [
                  'new',
                  'in_progress',
                  'proposal_sent',
                  'closed_won',
                  'closed_lost',
                ],
                description: 'New status for the lead',
              },
              notes: {
                type: 'string',
                description: 'Updated notes (optional)',
              },
            },
            required: ['leadId', 'status'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'generate_response',
          description:
            'Generate a professional sales response to a client message using AI.',
          parameters: {
            type: 'object',
            properties: {
              clientMessage: {
                type: 'string',
                description: 'The message received from the client',
              },
              context: {
                type: 'string',
                description:
                  'Additional context about the client or deal (optional)',
              },
            },
            required: ['clientMessage'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'send_proposal',
          description:
            'Queue a sales proposal for human approval before sending it to a lead.',
          parameters: {
            type: 'object',
            properties: {
              leadName: {
                type: 'string',
                description: 'Name of the lead the proposal is for',
              },
              proposalText: {
                type: 'string',
                description: 'The full proposal text to be sent',
              },
              channel: {
                type: 'string',
                enum: ['whatsapp', 'instagram'],
                description: 'Delivery channel for the proposal',
              },
            },
            required: ['leadName', 'proposalText', 'channel'],
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
      case 'create_lead':
        return this.createLead(args, context);
      case 'update_lead_status':
        return this.updateLeadStatus(args, context);
      case 'generate_response':
        return this.generateResponse(args, context);
      case 'send_proposal':
        return this.sendProposal(args, context);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  private getNotionClient(): NotionClient {
    return new NotionClient();
  }

  private getDatabaseId(): string {
    const id = process.env.NOTION_DATABASE_ID;
    if (!id) {
      throw new Error(
        'NOTION_DATABASE_ID is not configured. Please set it in environment variables or integrations.',
      );
    }
    return id;
  }

  // ── Tool implementations ────────────────────────────────────────────

  private async createLead(
    args: Record<string, unknown>,
    _context: ToolContext,
  ): Promise<unknown> {
    const name = args.name as string;
    const phone = args.phone as string | undefined;
    const email = args.email as string | undefined;
    const source = args.source as string;
    const notes = args.notes as string | undefined;

    const notion = this.getNotionClient();
    const databaseId = this.getDatabaseId();

    const result = await notion.createLead(databaseId, {
      name,
      phone,
      email,
      source,
      status: 'new',
      notes,
    });

    logger.info(
      { leadId: result.id, name, source },
      'Lead created in Notion CRM',
    );

    return {
      leadId: result.id,
      url: result.url,
      name,
      source,
      status: 'new',
    };
  }

  private async updateLeadStatus(
    args: Record<string, unknown>,
    _context: ToolContext,
  ): Promise<unknown> {
    const leadId = args.leadId as string;
    const status = args.status as string;
    const notes = args.notes as string | undefined;

    const notion = this.getNotionClient();

    await notion.updateLead(leadId, { status, notes });

    logger.info({ leadId, status }, 'Lead status updated in Notion CRM');

    return {
      leadId,
      status,
      updated: true,
    };
  }

  private async generateResponse(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const clientMessage = args.clientMessage as string;
    const additionalContext = args.context as string | undefined;

    const config = await this.getConfig(context.db);

    const contextNote = additionalContext
      ? `\n\nAdditional context about the client/deal: ${additionalContext}`
      : '';

    const response = await getOpenRouter().chat({
      model: config.model,
      temperature: config.temperature,
      messages: [
        {
          role: 'system',
          content:
            'You are a professional sales representative. Generate clear, persuasive, and friendly responses to client messages. Keep the tone professional but warm. Respond in the same language as the client message.',
        },
        {
          role: 'user',
          content: `Generate a professional sales response to the following client message:\n\n"${clientMessage}"${contextNote}`,
        },
      ],
    });

    const responseText = response.content ?? '';

    return {
      response: responseText,
      clientMessage,
    };
  }

  private async sendProposal(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const leadName = args.leadName as string;
    const proposalText = args.proposalText as string;
    const channel = args.channel as 'whatsapp' | 'instagram';

    // Create approval task
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'sales',
        actionType: 'send_proposal',
        payload: {
          leadName,
          proposalText,
          channel,
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
      { approvalId: task!.id, threadId: context.threadId, leadName, channel },
      'Proposal approval task created',
    );

    return {
      approvalId: task!.id,
      status: 'pending_approval',
      message: `Proposal for ${leadName} queued for approval (delivery via ${channel})`,
    };
  }
}
