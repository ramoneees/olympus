# Memory strategy

## v1 memory (works immediately)

Use OpenClaw's native memory per agent:
- `MEMORY.md`
- `memory/*.md`
- `memory_search`
- `memory_get`

This is the safest source of truth for v1.

## Shared memory target

Do not replace native memory in v1.
Instead, add a future custom plugin/service backed by:
- pgvector
- mxbai-embed-large via Ollama

This shared layer should be responsible for:
- cross-agent retrieval
- namespace isolation
- deduplication
- relevance ranking
- optional prompt injection later

## Namespaces
- `/memory/personal`
- `/memory/finance`
- `/memory/projects`
- `/memory/knowledge`

## Mnemosyne later

Mnemosyne should eventually decide:
- what is worth saving
- which namespace it belongs to
- when low-value context should be pruned or ignored
