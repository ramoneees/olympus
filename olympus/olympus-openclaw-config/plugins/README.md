# OLYMPUS plugin plan

This folder documents the **future plugin surface**, not a shipped implementation.

## Planned plugin IDs

### olympus-shared-memory
Purpose:
- shared semantic memory across agents
- pgvector backend
- mxbai-embed-large embeddings via Ollama

Expected responsibilities:
- upsert shared memory items
- semantic search across namespaces
- enforce namespace and ACL rules
- optionally inject relevant context into prompts later

Possible tool IDs:
- `shared_memory_search`
- `shared_memory_get`
- `shared_memory_upsert`
- `shared_memory_link`

Namespaces:
- `/memory/personal`
- `/memory/finance`
- `/memory/projects`
- `/memory/knowledge`

### olympus-google-tools
Purpose:
- Google Workspace integrations through service-account or delegated auth

Possible tool families:
- calendar search / read
- Gmail search / read
- Drive file lookup
- Docs / Sheets export or read

### olympus-slack-tools
Purpose:
- Slack read/write or channel context integrations

### olympus-dev-tools
Purpose:
- higher-level developer actions beyond built-in fs/runtime tools

Possible tool IDs:
- `docs_search`
- `code_runner`
- `repo_insights`

### olympus-knowledge-tools
Purpose:
- note system and document tooling

Possible tool IDs:
- `obsidian_search`
- `vector_db_search`
- `document_parser`

### olympus-finance-tools
Purpose:
- Firefly III
- Invoice Ninja
- exchange rates
- crypto prices
- finance report automation

Possible tool IDs:
- `firefly_api`
- `invoice_ninja`
- `exchange_rate`
- `crypto_prices`
- `finance_reports`

### olympus-audit-tools
Purpose:
- audit and scenario analysis support

Possible tool IDs:
- `risk_analysis`
- `data_query`
- `audit_tools`

## Principle

Do not wire these plugin IDs into the active `plugins.v1.json5` until the actual plugin manifests exist. Use `plugins.future.example.json5` as the future target shape.
