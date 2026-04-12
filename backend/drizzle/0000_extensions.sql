-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";

-- After Drizzle creates the document_chunks table,
-- alter the embedding column to use vector type:
-- ALTER TABLE document_chunks ALTER COLUMN embedding TYPE vector(1536) USING embedding::vector(1536);
-- CREATE INDEX idx_document_chunks_embedding ON document_chunks USING ivfflat (embedding vector_cosine_ops);
