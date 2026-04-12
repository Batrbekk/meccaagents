import { logger } from './logger.js';

const EMBEDDING_MODEL = 'openai/text-embedding-3-small';
const EMBEDDING_DIMENSION = 1536;

/**
 * Generate a single embedding vector for the given text using OpenRouter's
 * embedding endpoint (proxied OpenAI text-embedding-3-small).
 */
export async function generateEmbedding(text: string): Promise<number[]> {
  const [embedding] = await generateEmbeddings([text]);
  if (!embedding) {
    throw new Error('Failed to generate embedding: empty response');
  }
  return embedding;
}

/**
 * Generate embedding vectors for multiple texts in a single API call.
 */
export async function generateEmbeddings(texts: string[]): Promise<number[][]> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY is required for embeddings');
  }

  const baseUrl = (
    process.env.OPENROUTER_BASE_URL ?? 'https://openrouter.ai/api/v1'
  ).replace(/\/+$/, '');

  const res = await fetch(`${baseUrl}/embeddings`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: texts,
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '(unreadable)');
    throw new Error(
      `Embedding request failed (${res.status}): ${body.slice(0, 500)}`,
    );
  }

  const json = (await res.json()) as {
    data?: Array<{ embedding: number[]; index: number }>;
  };

  if (!json.data || json.data.length === 0) {
    throw new Error('Embedding response contained no data');
  }

  // Sort by index to preserve input order
  const sorted = [...json.data].sort((a, b) => a.index - b.index);

  logger.debug(
    { count: sorted.length, dimension: sorted[0]?.embedding.length },
    'Embeddings generated',
  );

  return sorted.map((d) => d.embedding);
}

export { EMBEDDING_DIMENSION };
