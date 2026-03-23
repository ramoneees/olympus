# Durable memory

## Memory system architecture (v1 — active)
- Backend: OpenClaw builtin (SQLite + sqlite-vec), PVC-backed at /home/node/.openclaw
- Embeddings: nomic-embed-text-v2 via LiteLLM → Ollama (local, never leaves cluster)
- Search: hybrid BM25 (0.3) + vector (0.7), MMR diversity, 30-day temporal decay
- Cache: 50,000 embedding entries
- Session memory: experimental cross-session recall enabled
- Tools: memory_search, memory_get, memory_put (native OpenClaw)

## Planned future backends (not active)
- pgvector: postgresql.databases.svc.cluster.local:5432/olympus_memory
- Redis: redis.databases.svc.cluster.local:6379 (ephemeral context)
- Vikunja: episodic task history integration (read-only)

## Namespace organization
- /memory/personal — user profile and preferences
- /memory/finance — financial categorization and conventions (Plutus-owned)
- /memory/projects — project architecture and decisions
- /memory/knowledge — vetted references and documentation

## OLYMPUS context
- Mnemosyne serves all agents as the shared memory backend
- v1 uses OpenClaw native memory; pgvector integration is the next step
- Memory quality directly impacts all agent performance — accuracy over volume

## Model tiers
- FAST -> local Ollama
- SMART -> API providers
- PREMIUM -> strongest remote models when needed
