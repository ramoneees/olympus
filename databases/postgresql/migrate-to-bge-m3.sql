-- Migration: Reindex from nomic-embed-text-v2 (768d) to bge-m3 (1024d)
-- This script migrates existing memory entries to the new embedding model
-- 
-- IMPORTANT: This requires re-generating ALL embeddings via Ollama.
-- The old vectors (768d) cannot be converted - they must be recomputed.
--
-- Steps:
-- 1. Create new table with bge-m3 schema (1024 dimensions)
-- 2. Export existing content (without embeddings)
-- 3. Regenerate embeddings via Ollama API (bge-m3 model)
-- 4. Import into new table
-- 5. Swap tables or update application config

-- Step 1: Backup existing data (if any exists in pgvector)
-- Note: Current v1 uses SQLite, so this may be empty if pgvector wasn't active yet
CREATE TABLE IF NOT EXISTS memory_entries_backup AS
SELECT * FROM memory_entries WHERE 1=0;  -- Schema only if table exists

-- If table exists with data, backup the content for re-embedding
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'memory_entries') THEN
        -- Backup content without embeddings (we need to regenerate them)
        INSERT INTO memory_entries_backup (id, namespace, content, source_agent, timestamp, confidence, metadata)
        SELECT id, namespace, content, source_agent, timestamp, confidence, metadata
        FROM memory_entries;
        
        -- Drop old table (768d)
        DROP TABLE IF EXISTS memory_entries CASCADE;
    END IF;
END $$;

-- Step 2: Create new table with bge-m3 schema (1024 dimensions)
CREATE TABLE IF NOT EXISTS memory_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    namespace VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1024) NOT NULL,  -- bge-m3: 1024 dimensions
    source_agent VARCHAR(100) NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT valid_namespace CHECK (namespace LIKE '/memory/%')
);

-- Step 3: Create indexes for efficient similarity search
CREATE INDEX idx_memory_embedding ON memory_entries 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 256);  -- Tuned for ~50k entries

CREATE INDEX idx_memory_namespace ON memory_entries (namespace);
CREATE INDEX idx_memory_timestamp ON memory_entries (timestamp DESC);
CREATE INDEX idx_memory_ns_time ON memory_entries (namespace, timestamp DESC);
CREATE INDEX idx_memory_source ON memory_entries (source_agent);

-- Step 4: Create function to regenerate embeddings via Ollama
-- This will be called by the migration job to populate embeddings
CREATE OR REPLACE FUNCTION regenerate_embedding(content_text TEXT)
RETURNS vector(1024) AS $$
DECLARE
    embedding_json JSONB;
    embedding_vector vector(1024);
BEGIN
    -- Note: Actual embedding generation happens in the migration job via HTTP call to Ollama
    -- This function is a placeholder for the schema - the job will do:
    -- curl -X POST http://ollama.olympus.svc.cluster.local:11434/api/embeddings \
    --   -d '{"model": "bge-m3", "prompt": "content_text"}'
    -- and insert the result
    RETURN NULL;  -- Populated by migration job
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create migration tracking
CREATE TABLE IF NOT EXISTS embedding_migrations (
    id SERIAL PRIMARY KEY,
    from_model VARCHAR(100) NOT NULL,
    to_model VARCHAR(100) NOT NULL,
    from_dimensions INTEGER NOT NULL,
    to_dimensions INTEGER NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    records_total INTEGER DEFAULT 0,
    records_processed INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending',  -- pending, in_progress, completed, failed
    error_message TEXT,
    notes TEXT
);

-- Record this migration
INSERT INTO embedding_migrations (
    from_model, to_model, from_dimensions, to_dimensions, 
    status, notes
) VALUES (
    'nomic-embed-text-v2', 'bge-m3', 768, 1024,
    'pending',
    'Migration from nomic-embed-text-v2 (768d) to bge-m3 (1024d). Requires re-embedding all content via Ollama.'
);

-- Step 6: Helper view for migration progress
CREATE OR REPLACE VIEW migration_status AS
SELECT 
    id,
    from_model,
    to_model,
    from_dimensions,
    to_dimensions,
    status,
    records_total,
    records_processed,
    records_failed,
    CASE 
        WHEN records_total > 0 THEN 
            ROUND((records_processed::numeric / records_total::numeric) * 100, 2)
        ELSE 0
    END as progress_percent,
    started_at,
    completed_at,
    EXTRACT(EPOCH FROM (COALESCE(completed_at, NOW()) - started_at))/60 as duration_minutes,
    error_message,
    notes
FROM embedding_migrations
ORDER BY started_at DESC;
