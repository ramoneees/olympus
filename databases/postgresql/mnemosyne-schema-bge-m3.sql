-- pgvector schema for Mnemosyne shared memory (bge-m3 embeddings: 1024 dimensions)
-- Run this after pgvector extension is enabled: CREATE EXTENSION IF NOT EXISTS vector;
-- Database: mnemosyne

-- Memory entries table with bge-m3 embeddings (1024 dimensions)
CREATE TABLE IF NOT EXISTS memory_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    namespace VARCHAR(255) NOT NULL,                    -- /memory/personal, /memory/finance, /memory/projects, /memory/knowledge
    content TEXT NOT NULL,                              -- The actual memory content
    embedding vector(1024) NOT NULL,                    -- bge-m3 embeddings: 1024 dimensions
    source_agent VARCHAR(100) NOT NULL,                 -- Which agent created this memory
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
    metadata JSONB DEFAULT '{}',                        -- Additional structured metadata
    
    -- Indexing
    CONSTRAINT valid_namespace CHECK (namespace LIKE '/memory/%')
);

-- Create pgvector index for similarity search
-- Using ivfflat with lists tuned for expected dataset size (~50k entries based on MEMORY.md cache size)
-- For 50k entries, sqrt(50000) ≈ 224, so we use 256 lists
CREATE INDEX IF NOT EXISTS idx_memory_embedding 
ON memory_entries 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 256);

-- Index for namespace filtering (common query pattern)
CREATE INDEX IF NOT EXISTS idx_memory_namespace 
ON memory_entries (namespace);

-- Index for timestamp-based temporal queries
CREATE INDEX IF NOT EXISTS idx_memory_timestamp 
ON memory_entries (timestamp DESC);

-- Composite index for namespace + timestamp (common search pattern)
CREATE INDEX IF NOT EXISTS idx_memory_ns_time 
ON memory_entries (namespace, timestamp DESC);

-- Index for source agent tracking
CREATE INDEX IF NOT EXISTS idx_memory_source 
ON memory_entries (source_agent);

-- Comment for documentation
COMMENT ON TABLE memory_entries IS 'Mnemosyne memory storage with bge-m3 embeddings (1024 dimensions)';
COMMENT ON COLUMN memory_entries.embedding IS 'bge-m3 embedding vector (1024 dimensions)';
COMMENT ON COLUMN memory_entries.namespace IS 'Memory namespace: /memory/personal, /memory/finance, /memory/projects, /memory/knowledge';

-- Migration tracking table
CREATE TABLE IF NOT EXISTS embedding_migrations (
    id SERIAL PRIMARY KEY,
    from_model VARCHAR(100) NOT NULL,
    to_model VARCHAR(100) NOT NULL,
    from_dimensions INTEGER NOT NULL,
    to_dimensions INTEGER NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    records_migrated INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'in_progress',           -- in_progress, completed, failed
    error_message TEXT
);

-- Insert migration record
INSERT INTO embedding_migrations (from_model, to_model, from_dimensions, to_dimensions, status)
VALUES ('nomic-embed-text-v2', 'bge-m3', 768, 1024, 'in_progress');
