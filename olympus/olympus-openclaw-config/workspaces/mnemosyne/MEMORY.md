# Durable memory

## Memory system architecture
- Short-term: Redis at redis.databases.svc.cluster.local:6379
- Long-term: PostgreSQL + pgvector at postgresql.databases.svc.cluster.local:5432/olympus_memory
- Episodic: Vikunja task history (read-only source of truth)
- Embedding model: nomic-embed-text-v2 via Ollama (fallback: mxbai-embed-large)

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
