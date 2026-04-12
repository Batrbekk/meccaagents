import {
  pgTable,
  uuid,
  text,
  timestamp,
  boolean,
  real,
  jsonb,
  integer,
  bigint,
  index,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

// ============================
// Users
// ============================
export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  passwordHash: text('password_hash').notNull(),
  role: text('role').notNull().default('owner'), // owner | admin | viewer
  isActive: boolean('is_active').notNull().default(true),
  lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

// ============================
// Sessions (refresh token management with rotation)
// ============================
export const sessions = pgTable(
  'sessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    refreshTokenHash: text('refresh_token_hash').notNull(),
    tokenFamily: uuid('token_family').notNull(),
    deviceInfo: text('device_info'),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_sessions_user').on(t.userId),
    index('idx_sessions_family').on(t.tokenFamily),
  ],
);

// ============================
// Threads (chats)
// ============================
export const threads = pgTable(
  'threads',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    title: text('title').notNull(),
    createdBy: uuid('created_by').references(() => users.id),
    isArchived: boolean('is_archived').notNull().default(false),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_threads_created_by').on(t.createdBy),
  ],
);

// ============================
// Messages
// ============================
export const messages = pgTable(
  'messages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    threadId: uuid('thread_id')
      .notNull()
      .references(() => threads.id, { onDelete: 'cascade' }),
    senderType: text('sender_type').notNull(), // user | agent
    senderId: text('sender_id').notNull(), // user uuid or agent slug
    content: text('content'),
    metadata: jsonb('metadata').default({}), // tool_calls, file_urls, images, etc
    status: text('status').notNull().default('sent'), // sending | sent | error
    parentMessageId: uuid('parent_message_id'), // self-ref for reply-to
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_messages_thread_created').on(t.threadId, t.createdAt),
    index('idx_messages_sender').on(t.senderType, t.senderId),
  ],
);

// ============================
// Approval Tasks
// ============================
export const approvalTasks = pgTable(
  'approval_tasks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    agentSlug: text('agent_slug').notNull(),
    actionType: text('action_type').notNull(),
    payload: jsonb('payload').notNull(),
    status: text('status').notNull().default('pending'), // pending | approved | rejected | modified
    expiresAt: timestamp('expires_at', { withTimezone: true }),
    notes: text('notes'),
    requestedAt: timestamp('requested_at', { withTimezone: true }).notNull().defaultNow(),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
    resolvedBy: uuid('resolved_by').references(() => users.id),
    threadId: uuid('thread_id').references(() => threads.id),
    messageId: uuid('message_id').references(() => messages.id),
  },
  (t) => [
    index('idx_approval_status_requested').on(t.status, t.requestedAt),
    index('idx_approval_thread').on(t.threadId),
  ],
);

// ============================
// Agent Configs
// ============================
export const agentConfigs = pgTable('agent_configs', {
  id: uuid('id').primaryKey().defaultRandom(),
  slug: text('slug').notNull().unique(),
  displayName: text('display_name').notNull(),
  systemPrompt: text('system_prompt').notNull(),
  model: text('model').notNull(),
  temperature: real('temperature').notNull().default(0.7),
  tools: jsonb('tools').notNull().default([]),
  isActive: boolean('is_active').notNull().default(true),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

// ============================
// Tool Logs
// ============================
export const toolLogs = pgTable(
  'tool_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    agentSlug: text('agent_slug').notNull(),
    toolName: text('tool_name').notNull(),
    input: jsonb('input'),
    output: jsonb('output'),
    durationMs: integer('duration_ms'),
    status: text('status').notNull(), // success | error
    errorMessage: text('error_message'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_tool_logs_agent_created').on(t.agentSlug, t.createdAt),
    index('idx_tool_logs_status').on(t.status),
  ],
);

// ============================
// Integrations (credentials encrypted with AES-256-GCM)
// ============================
export const integrations = pgTable('integrations', {
  id: uuid('id').primaryKey().defaultRandom(),
  service: text('service').notNull().unique(),
  credentials: text('credentials').notNull(), // AES-256-GCM encrypted JSON
  isActive: boolean('is_active').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

// ============================
// Files
// ============================
export const files = pgTable(
  'files',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    originalName: text('original_name').notNull(),
    storedName: text('stored_name').notNull(), // UUID-based
    mimeType: text('mime_type').notNull(),
    sizeBytes: bigint('size_bytes', { mode: 'number' }).notNull(),
    storagePath: text('storage_path').notNull(), // MinIO path
    uploadedBy: uuid('uploaded_by').references(() => users.id),
    threadId: uuid('thread_id').references(() => threads.id),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_files_thread').on(t.threadId),
  ],
);

// ============================
// Audit Log
// ============================
export const auditLog = pgTable(
  'audit_log',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    actorType: text('actor_type').notNull(), // user | agent | system
    actorId: text('actor_id').notNull(),
    action: text('action').notNull(),
    resourceType: text('resource_type').notNull(),
    resourceId: text('resource_id'),
    details: jsonb('details'),
    ipAddress: text('ip_address'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_audit_log_created').on(t.createdAt),
    index('idx_audit_log_actor').on(t.actorType, t.actorId),
  ],
);

// ============================
// Document Chunks (RAG for Lawyer agent, pgvector)
// ============================
export const documentChunks = pgTable(
  'document_chunks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    fileId: uuid('file_id')
      .notNull()
      .references(() => files.id, { onDelete: 'cascade' }),
    content: text('content').notNull(),
    // pgvector embedding — stored as vector(1536)
    // Drizzle doesn't have native vector type, use raw SQL in migration
    embedding: text('embedding').notNull(), // placeholder, actual column is vector(1536)
    chunkIndex: integer('chunk_index').notNull(),
    metadata: jsonb('metadata'), // page_number, section, etc
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('idx_document_chunks_file').on(t.fileId),
  ],
);
