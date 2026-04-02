-- Grant permissions for mnemosyne user and create external tool access
-- Run this as postgres superuser in the mnemosyne database

-- 1. Grant full access to mnemosyne user (for OpenClaw agent)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mnemosyne;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mnemosyne;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mnemosyne;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mnemosyne;

-- 2. Create a role for external read/write tools (Obsidian sync, etc.)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'memory_writer') THEN
        CREATE ROLE memory_writer;
    END IF;
END $$;

-- Grant memory_writer role permissions
GRANT USAGE ON SCHEMA public TO memory_writer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO memory_writer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO memory_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO memory_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO memory_writer;

-- 3. Create a dedicated user for Obsidian sync (optional - you can also use mnemosyne user directly)
-- Uncomment and modify password if you want a separate user:
-- CREATE USER obsidian_sync WITH PASSWORD 'CHANGE_ME_IN_KUBERNETES_SECRET';
-- GRANT memory_writer TO obsidian_sync;

-- 4. Add comments for documentation
COMMENT ON TABLE memory_entries IS 'Unified memory storage for OLYMPUS agents and external sources (Obsidian, etc.). Uses bge-m3 embeddings (1024 dimensions).';

-- 5. Create a view for namespace-specific queries (helpful for external tools)
CREATE OR REPLACE VIEW memory_by_namespace AS
SELECT 
    namespace,
    COUNT(*) as entry_count,
    MIN(timestamp) as oldest_entry,
    MAX(timestamp) as newest_entry
FROM memory_entries
GROUP BY namespace
ORDER BY namespace;

-- Grant access to the view
GRANT SELECT ON memory_by_namespace TO memory_writer;
GRANT SELECT ON memory_by_namespace TO mnemosyne;

-- 6. Verify setup
SELECT 
    'Permissions granted successfully' as status,
    (SELECT COUNT(*) FROM memory_entries) as current_entries,
    (SELECT COUNT(*) FROM memory_by_namespace) as namespaces;
