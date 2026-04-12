import { logger } from '../lib/logger.js';

const NOTION_BASE = 'https://api.notion.com/v1';
const NOTION_VERSION = '2022-06-28';

export interface NotionLead {
  name: string;
  phone?: string;
  email?: string;
  source: string; // whatsapp | instagram | manual
  status: string; // new | in_progress | proposal_sent | closed_won | closed_lost
  notes?: string;
}

export interface NotionLeadRecord {
  id: string;
  name: string;
  status: string;
}

/**
 * Notion API client for CRM lead management.
 *
 * For MVP the token and databaseId come from env vars
 * `NOTION_TOKEN` and `NOTION_DATABASE_ID` as fallback.
 * In production they will be read from the encrypted integrations table.
 */
export class NotionClient {
  private token: string;

  constructor(token?: string) {
    this.token = token ?? process.env.NOTION_TOKEN ?? '';

    if (!this.token) {
      logger.warn('NotionClient instantiated without a token — CRM calls will fail');
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────

  private headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.token}`,
      'Notion-Version': NOTION_VERSION,
      'Content-Type': 'application/json',
    };
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    const url = `${NOTION_BASE}${path}`;

    const init: RequestInit = {
      method,
      headers: this.headers(),
    };

    if (body !== undefined) {
      init.body = JSON.stringify(body);
    }

    const res = await fetch(url, init);

    if (!res.ok) {
      const text = await res.text().catch(() => '(unreadable)');
      logger.error(
        { status: res.status, path, body: text.slice(0, 500) },
        'Notion API request failed',
      );
      throw new Error(`Notion API error (${res.status}): ${text.slice(0, 300)}`);
    }

    return (await res.json()) as T;
  }

  // ── Public API ──────────────────────────────────────────────────────

  /**
   * Create a new page (lead) in a Notion database.
   */
  async createLead(
    databaseId: string,
    lead: NotionLead,
  ): Promise<{ id: string; url: string }> {
    const properties: Record<string, unknown> = {
      Name: { title: [{ text: { content: lead.name } }] },
      Source: { select: { name: lead.source } },
      Status: { select: { name: lead.status } },
    };

    if (lead.phone) {
      properties.Phone = { rich_text: [{ text: { content: lead.phone } }] };
    }

    if (lead.email) {
      properties.Email = { email: lead.email };
    }

    if (lead.notes) {
      properties.Notes = { rich_text: [{ text: { content: lead.notes } }] };
    }

    const result = await this.request<{ id: string; url: string }>(
      'POST',
      '/pages',
      {
        parent: { database_id: databaseId },
        properties,
      },
    );

    logger.info({ leadId: result.id, name: lead.name }, 'Notion lead created');

    return { id: result.id, url: result.url };
  }

  /**
   * Update an existing lead's status and/or notes.
   */
  async updateLead(
    pageId: string,
    updates: { status?: string; notes?: string },
  ): Promise<void> {
    const properties: Record<string, unknown> = {};

    if (updates.status) {
      properties.Status = { select: { name: updates.status } };
    }

    if (updates.notes) {
      properties.Notes = { rich_text: [{ text: { content: updates.notes } }] };
    }

    await this.request('PATCH', `/pages/${pageId}`, { properties });

    logger.info({ pageId, updates }, 'Notion lead updated');
  }

  /**
   * Query leads from a database, optionally filtered by status.
   */
  async queryLeads(
    databaseId: string,
    status?: string,
  ): Promise<NotionLeadRecord[]> {
    const body: Record<string, unknown> = {};

    if (status) {
      body.filter = {
        property: 'Status',
        select: { equals: status },
      };
    }

    const result = await this.request<{
      results: Array<{
        id: string;
        properties: {
          Name?: { title?: Array<{ text?: { content?: string } }> };
          Status?: { select?: { name?: string } };
        };
      }>;
    }>('POST', `/databases/${databaseId}/query`, body);

    return result.results.map((page) => ({
      id: page.id,
      name: page.properties.Name?.title?.[0]?.text?.content ?? '(unnamed)',
      status: page.properties.Status?.select?.name ?? 'unknown',
    }));
  }
}
