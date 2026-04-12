import { generateEmbedding, generateEmbeddings, EMBEDDING_DIMENSION } from './embeddings.js';
import { logger } from './logger.js';
import postgres from 'postgres';

// Re-export for convenience
export { EMBEDDING_DIMENSION };

type Sql = postgres.Sql;

// ---------------------------------------------------------------------------
// Text chunking
// ---------------------------------------------------------------------------

/**
 * Default chunk size in characters (~500 tokens at ~4 chars/token).
 */
const DEFAULT_CHUNK_SIZE = 2000;

/**
 * Default overlap in characters (~50 tokens).
 */
const DEFAULT_OVERLAP = 200;

/**
 * Chunk text into overlapping segments.
 *
 * Strategy:
 * 1. Split into paragraphs (double newline).
 * 2. Greedily combine paragraphs into chunks up to `chunkSize`.
 * 3. If a single paragraph exceeds `chunkSize`, split it by sentences.
 * 4. Overlap the tail of each chunk into the next.
 */
export function chunkText(
  text: string,
  chunkSize: number = DEFAULT_CHUNK_SIZE,
  overlap: number = DEFAULT_OVERLAP,
): string[] {
  if (!text || text.trim().length === 0) return [];

  // Split by double-newline (paragraphs) while preserving structure
  const paragraphs = text
    .split(/\n{2,}/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);

  if (paragraphs.length === 0) return [];

  const chunks: string[] = [];
  let current = '';

  for (const para of paragraphs) {
    // If adding this paragraph would exceed the chunk size, finalize current
    if (current.length > 0 && current.length + para.length + 2 > chunkSize) {
      chunks.push(current.trim());

      // Start next chunk with overlap from the end of the current chunk
      if (overlap > 0 && current.length > overlap) {
        current = current.slice(-overlap);
      } else {
        current = '';
      }
    }

    // If a single paragraph is larger than chunkSize, split by sentences
    if (para.length > chunkSize) {
      // Finalize anything accumulated
      if (current.trim().length > 0) {
        chunks.push(current.trim());
        current = '';
      }

      const sentences = splitSentences(para);
      let sentenceChunk = '';

      for (const sentence of sentences) {
        if (sentenceChunk.length + sentence.length + 1 > chunkSize) {
          if (sentenceChunk.trim().length > 0) {
            chunks.push(sentenceChunk.trim());
            if (overlap > 0 && sentenceChunk.length > overlap) {
              sentenceChunk = sentenceChunk.slice(-overlap);
            } else {
              sentenceChunk = '';
            }
          }
        }
        sentenceChunk += (sentenceChunk.length > 0 ? ' ' : '') + sentence;
      }

      if (sentenceChunk.trim().length > 0) {
        current = sentenceChunk;
      }
      continue;
    }

    current += (current.length > 0 ? '\n\n' : '') + para;
  }

  // Don't forget the last chunk
  if (current.trim().length > 0) {
    chunks.push(current.trim());
  }

  return chunks;
}

/**
 * Split text into sentences. Handles common abbreviations and decimals.
 */
function splitSentences(text: string): string[] {
  // Split on sentence-ending punctuation followed by whitespace and a capital letter
  return text
    .split(/(?<=[.!?])\s+(?=[A-ZА-ЯЁ])/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

// ---------------------------------------------------------------------------
// Document indexing
// ---------------------------------------------------------------------------

export interface IndexResult {
  chunksCreated: number;
}

/**
 * Process an uploaded file: chunk the text, generate embeddings, and store
 * the chunks in the `document_chunks` table.
 *
 * @param sql - A raw `postgres` SQL tagged-template instance
 * @param fileId - The UUID of the file in the `files` table
 * @param text - The extracted text content of the file
 * @returns The number of chunks created
 */
export async function indexDocument(
  sql: Sql,
  fileId: string,
  text: string,
): Promise<number> {
  const chunks = chunkText(text);

  if (chunks.length === 0) {
    logger.warn({ fileId }, 'No chunks generated from document text');
    return 0;
  }

  logger.info({ fileId, chunkCount: chunks.length }, 'Generating embeddings for document chunks');

  // Generate embeddings for all chunks in a single batch call
  const embeddings = await generateEmbeddings(chunks);

  // Insert all chunks using raw SQL (pgvector requires ::vector cast)
  for (let i = 0; i < chunks.length; i++) {
    const embeddingStr = `[${embeddings[i]!.join(',')}]`;

    await sql`
      INSERT INTO document_chunks (id, file_id, content, embedding, chunk_index, created_at)
      VALUES (
        gen_random_uuid(),
        ${fileId},
        ${chunks[i]!},
        ${embeddingStr}::vector,
        ${i},
        now()
      )
    `;
  }

  logger.info({ fileId, chunksCreated: chunks.length }, 'Document indexed successfully');
  return chunks.length;
}

// ---------------------------------------------------------------------------
// Semantic search
// ---------------------------------------------------------------------------

export interface SearchResult {
  id: string;
  fileId: string;
  content: string;
  chunkIndex: number;
  similarity: number;
}

/**
 * Search for relevant document chunks using cosine similarity (pgvector).
 *
 * @param sql - A raw `postgres` SQL tagged-template instance
 * @param query - The search query text
 * @param limit - Maximum number of results (default: 5)
 * @returns Matching chunks sorted by similarity (descending)
 */
export async function searchDocuments(
  sql: Sql,
  query: string,
  limit: number = 5,
): Promise<SearchResult[]> {
  const queryEmbedding = await generateEmbedding(query);
  const embeddingStr = `[${queryEmbedding.join(',')}]`;

  const rows = await sql`
    SELECT
      id,
      file_id,
      content,
      chunk_index,
      1 - (embedding <=> ${embeddingStr}::vector) AS similarity
    FROM document_chunks
    ORDER BY embedding <=> ${embeddingStr}::vector
    LIMIT ${limit}
  `;

  return rows.map((row) => ({
    id: row.id as string,
    fileId: row.file_id as string,
    content: row.content as string,
    chunkIndex: row.chunk_index as number,
    similarity: parseFloat(row.similarity as string),
  }));
}

// ---------------------------------------------------------------------------
// Helper: create a postgres connection from DATABASE_URL
// ---------------------------------------------------------------------------

/**
 * Create a raw postgres SQL instance from DATABASE_URL.
 * Useful when only the Drizzle DB is available but raw SQL is needed.
 */
export function createRawSql(): Sql {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required for RAG operations');
  }
  return postgres(databaseUrl, { max: 5 });
}
