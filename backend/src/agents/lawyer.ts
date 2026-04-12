import { BaseAgent } from './base-agent.js';
import { openrouter } from '../lib/openrouter.js';
import { publish } from '../lib/pubsub.js';
import { approvalTasks } from '../db/schema.js';
import { searchDocuments, createRawSql } from '../lib/rag.js';
import { generateLegalDocument } from '../tools/legal-document.js';
import { logger } from '../lib/logger.js';
import type { ToolDefinition, ToolContext } from './types.js';
import type postgres from 'postgres';

type Sql = postgres.Sql;

/**
 * LawyerAgent — handles legal questions, contract generation, risk analysis,
 * and document search using RAG (Retrieval-Augmented Generation).
 *
 * Tools:
 *  - search_documents: semantic search over indexed documents (pgvector)
 *  - check_legal_risks: AI-powered legal risk analysis
 *  - generate_contract: generate and format legal documents
 *  - web_search: search for current legislation and legal info
 */
export class LawyerAgent extends BaseAgent {
  private rawSql: Sql | null = null;

  constructor() {
    super('lawyer');
  }

  /**
   * Lazily create a raw postgres connection for vector queries.
   */
  private getSql(): Sql {
    if (!this.rawSql) {
      this.rawSql = createRawSql();
    }
    return this.rawSql;
  }

  // ── Tool definitions ────────────────────────────────────────────────

  getTools(): ToolDefinition[] {
    return [
      {
        type: 'function',
        function: {
          name: 'search_documents',
          description:
            'Search through uploaded legal documents and knowledge base using semantic similarity. Returns relevant document excerpts.',
          parameters: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description:
                  'The search query — describe what legal information you are looking for',
              },
              limit: {
                type: 'number',
                description:
                  'Maximum number of results to return (default: 5)',
              },
            },
            required: ['query'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'check_legal_risks',
          description:
            'Analyze a piece of text (contract clause, business plan, agreement) for potential legal risks, compliance issues, and red flags.',
          parameters: {
            type: 'object',
            properties: {
              text: {
                type: 'string',
                description: 'The text to analyze for legal risks',
              },
              jurisdiction: {
                type: 'string',
                description:
                  'The legal jurisdiction to consider (e.g. "Kazakhstan", "Russia", "International"). Defaults to Kazakhstan.',
              },
            },
            required: ['text'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'generate_contract',
          description:
            'Generate a legal document (contract, NDA, or agreement) based on the provided parameters. Creates an approval task for human review.',
          parameters: {
            type: 'object',
            properties: {
              type: {
                type: 'string',
                enum: ['contract', 'nda', 'agreement'],
                description: 'The type of legal document to generate',
              },
              parties: {
                type: 'array',
                items: { type: 'string' },
                description:
                  'The parties involved in the document (names or company names)',
              },
              terms: {
                type: 'string',
                description:
                  'A description of the key terms, conditions, and specifics to include in the document',
              },
              title: {
                type: 'string',
                description:
                  'Optional title for the document. If omitted, one will be generated.',
              },
            },
            required: ['type', 'parties', 'terms'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'web_search',
          description:
            'Search the web for current legislation, legal precedents, regulatory updates, and legal information.',
          parameters: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description:
                  'The search query — include jurisdiction and specific legal topic',
              },
            },
            required: ['query'],
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
      case 'search_documents':
        return this.searchDocuments(args, context);
      case 'check_legal_risks':
        return this.checkLegalRisks(args, context);
      case 'generate_contract':
        return this.generateContract(args, context);
      case 'web_search':
        return this.webSearch(args, context);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  }

  // ── Tool implementations ────────────────────────────────────────────

  /**
   * Semantic search over indexed document chunks using pgvector.
   */
  private async searchDocuments(
    args: Record<string, unknown>,
    _context: ToolContext,
  ): Promise<unknown> {
    const query = args.query as string;
    const limit = (args.limit as number | undefined) ?? 5;

    logger.info({ query, limit }, 'Lawyer agent: searching documents');

    const results = await searchDocuments(this.getSql(), query, limit);

    if (results.length === 0) {
      return {
        results: [],
        message:
          'No relevant documents found. The knowledge base may be empty or the query may not match any indexed content.',
      };
    }

    return {
      results: results.map((r) => ({
        content: r.content,
        similarity: Math.round(r.similarity * 100) / 100,
        chunkIndex: r.chunkIndex,
        fileId: r.fileId,
      })),
      message: `Found ${results.length} relevant document chunk(s).`,
    };
  }

  /**
   * Analyze text for legal risks using a specialized LLM prompt.
   */
  private async checkLegalRisks(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const text = args.text as string;
    const jurisdiction = (args.jurisdiction as string) ?? 'Kazakhstan';

    const config = await this.getConfig(context.db);

    const response = await openrouter.chat({
      model: config.model,
      temperature: 0.3, // Lower temperature for analytical tasks
      messages: [
        {
          role: 'system',
          content: `You are an expert legal risk analyst specializing in ${jurisdiction} law. Analyze the provided text for:

1. **Legal Risks** — clauses or provisions that could expose parties to liability
2. **Compliance Issues** — potential violations of local regulations or laws
3. **Ambiguities** — vague language that could lead to disputes
4. **Missing Provisions** — important clauses or protections that are absent
5. **Red Flags** — terms that are unusually one-sided or potentially unenforceable

Provide a structured analysis with severity levels (HIGH / MEDIUM / LOW) for each finding.
Always cite the specific part of the text you are referring to.
Respond in the same language as the input text.`,
        },
        {
          role: 'user',
          content: `Please analyze the following text for legal risks:\n\n---\n${text}\n---`,
        },
      ],
    });

    const analysis = response.content ?? 'Unable to generate risk analysis.';

    logger.info(
      { jurisdiction, textLength: text.length, threadId: context.threadId },
      'Legal risk analysis completed',
    );

    return {
      analysis,
      jurisdiction,
      textLength: text.length,
    };
  }

  /**
   * Generate a legal document (contract, NDA, agreement), format it,
   * and create an approval task for human review.
   */
  private async generateContract(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const docType = args.type as 'contract' | 'nda' | 'agreement';
    const parties = args.parties as string[];
    const terms = args.terms as string;
    const titleOverride = args.title as string | undefined;

    const config = await this.getConfig(context.db);

    // Use the LLM to generate the detailed document body based on terms
    const response = await openrouter.chat({
      model: config.model,
      temperature: 0.4,
      messages: [
        {
          role: 'system',
          content: `You are an expert legal document drafter. Generate a professional, detailed ${docType} body text based on the provided terms.

Rules:
- Write clear, precise legal language
- Include all standard clauses for this type of document
- Incorporate the specific terms provided by the user
- Use numbered sections and subsections
- Include governing law, dispute resolution, and termination clauses
- If the terms are described in Russian/Kazakh, write the document in that language
- Do NOT include the title, date, parties header, or signature blocks — only the body content
- The output should be in Markdown format`,
        },
        {
          role: 'user',
          content: `Generate a ${docType} for the following parties: ${parties.join(', ')}\n\nKey terms and conditions:\n${terms}`,
        },
      ],
    });

    const bodyText = response.content ?? '';

    const title =
      titleOverride ??
      `${docType.charAt(0).toUpperCase() + docType.slice(1)} between ${parties.join(' and ')}`;

    // Format into a complete legal document
    const documentText = generateLegalDocument({
      title,
      type: docType,
      parties,
      body: bodyText,
    });

    // Create an approval task so a human can review before finalizing
    const [task] = await context.db
      .insert(approvalTasks)
      .values({
        agentSlug: 'lawyer',
        actionType: 'legal_document',
        payload: {
          documentType: docType,
          title,
          parties,
          terms,
          documentText,
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
      { approvalId: task!.id, docType, threadId: context.threadId },
      'Legal document approval task created',
    );

    return {
      documentPreview: documentText.slice(0, 2000) + (documentText.length > 2000 ? '\n\n...(truncated)' : ''),
      fullLength: documentText.length,
      approvalId: task!.id,
      status: 'pending_approval',
      message: `A ${docType} has been generated and submitted for review. Approval ID: ${task!.id}`,
    };
  }

  /**
   * Web search for current legislation and legal information using
   * OpenRouter's built-in web search tool.
   */
  private async webSearch(
    args: Record<string, unknown>,
    context: ToolContext,
  ): Promise<unknown> {
    const query = args.query as string;

    const config = await this.getConfig(context.db);

    logger.info({ query, threadId: context.threadId }, 'Lawyer agent: web search');

    const response = await openrouter.chat({
      model: config.model,
      temperature: 0.3,
      messages: [
        {
          role: 'system',
          content:
            'You are a legal research assistant. Search for and summarize relevant legal information, legislation, and regulations. Cite your sources. Respond in the same language as the query.',
        },
        {
          role: 'user',
          content: query,
        },
      ],
      tools: [{ type: 'openrouter:web_search' }],
    });

    const searchResult = response.content ?? 'No results found.';

    return {
      result: searchResult,
      query,
    };
  }
}
