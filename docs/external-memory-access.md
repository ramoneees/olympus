# Connecting External Tools to Mnemosyne Memory (pgvector)

This guide shows how to connect external tools (like Obsidian sync) to the unified memory database.

## Quick Connect

**Database**: `postgresql.databases.svc.cluster.local:5432/mnemosyne`
**User**: `mnemosyne`
**Password**: Get from `postgresql-secret` or create dedicated secret
**Embedding Model**: `bge-m3` (1024 dimensions)

## For Obsidian Sync Tool

### 1. Get the Database Password

```bash
# Get mnemosyne user password (if you created one)
kubectl get secret postgresql-secret -n databases -o jsonpath='{.data.postgres-password}' | base64 -d
```

### 2. Connection String

```
postgresql://mnemosyne:<PASSWORD>@postgresql.databases.svc.cluster.local:5432/mnemosyne?sslmode=disable
```

### 3. Example INSERT (for your Obsidian sync script)

```sql
INSERT INTO memory_entries (
    namespace,
    content,
    embedding,
    source_agent,
    confidence,
    metadata
) VALUES (
    '/memory/obsidian',                                    -- Namespace for Obsidian notes
    'Your note content here...',                           -- Note text
    '[1.0, 2.0, 3.0, ...]'::vector(1024),                  -- bge-m3 embedding (1024 dims)
    'obsidian-sync',                                       -- Your tool name
    0.95,                                                  -- Confidence score
    '{"file_path": "vault/note.md", "tags": ["idea", "project"]}'::jsonb
);
```

### 4. Generate Embeddings via LiteLLM/Ollama

```bash
# From within your cluster or with port-forward
curl -X POST http://litellm.olympus.svc.cluster.local:4000/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${LITELLM_API_KEY}" \
  -d '{
    "model": "bge-m3",
    "input": "Your note content here"
  }'
```

Response:
```json
{
  "data": [{
    "embedding": [0.1, 0.2, 0.3, ...]  // 1024 floats
  }]
}
```

### 5. Query Similar Notes

```sql
-- Find notes similar to a query embedding
SELECT 
    content,
    metadata->>'file_path' as file,
    1 - (embedding <=> '[your_query_embedding]'::vector) as similarity
FROM memory_entries
WHERE namespace = '/memory/obsidian'
ORDER BY embedding <=> '[your_query_embedding]'::vector
LIMIT 10;
```

## Namespaces Available

| Namespace | Purpose | Access |
|-----------|---------|--------|
| `/memory/obsidian` | Your Obsidian notes | External tools (you) |
| `/memory/personal` | Personal preferences | Agents + External |
| `/memory/projects` | Project knowledge | Agents + External |
| `/memory/knowledge` | Vetted references | Agents + External |
| `/memory/finance` | Financial data | Plutus only (restricted) |

## Useful Queries

### Check your Obsidian entries
```sql
SELECT 
    metadata->>'file_path' as file,
    LEFT(content, 100) as preview,
    timestamp
FROM memory_entries
WHERE namespace = '/memory/obsidian'
ORDER BY timestamp DESC
LIMIT 20;
```

### Stats by namespace
```sql
SELECT * FROM memory_by_namespace;
```

### Search across all your data (excluding finance)
```sql
SELECT 
    namespace,
    content,
    1 - (embedding <=> '[query_embedding]'::vector) as similarity
FROM memory_entries
WHERE namespace != '/memory/finance'
ORDER BY embedding <=> '[query_embedding]'::vector
LIMIT 10;
```

## Files Reference

- **Schema**: `databases/postgresql/mnemosyne-schema-bge-m3.sql`
- **Secret Template**: `infrastructure/secrets/agent-secrets-template/memory-db-access-template.yaml`
- **Permissions**: `databases/postgresql/grant-memory-permissions.sql`

## Security Notes

- The `mnemosyne` user has full read/write access to all namespaces
- Finance namespace (`/memory/finance`) is logically separated but not access-restricted at DB level
- Use the `memory_writer` role for external tools if you create dedicated users
- All connections are internal cluster traffic (no SSL required)
