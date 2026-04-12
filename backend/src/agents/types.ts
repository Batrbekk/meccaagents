import type { drizzle } from 'drizzle-orm/postgres-js';
import type * as schema from '../db/schema.js';

/**
 * The Drizzle DB instance type used throughout the agents layer.
 */
export type DrizzleDB = ReturnType<typeof drizzle<typeof schema>>;

/**
 * OpenRouter-compatible tool definition (function calling).
 */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: {
      type: 'object';
      properties: Record<string, unknown>;
      required?: string[];
    };
  };
}

/**
 * Context passed to tool-call handlers.
 */
export interface ToolContext {
  db: DrizzleDB;
  threadId: string;
  agentSlug: string;
}

/**
 * The response returned by BaseAgent.execute().
 */
export interface AgentResponse {
  content: string;
  toolCalls: Array<{
    name: string;
    args: Record<string, unknown>;
    result: unknown;
  }>;
  usage: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

/**
 * Data shape for BullMQ agent jobs.
 */
export interface AgentJobData {
  threadId: string;
  agentSlug: string;
  userMessage: string;
  triggeredBy?: string;
}
