# OpenClaw Multi-Agent System

**Generated:** 2026-03-27
**Scope:** olympus/olympus-openclaw-config/

## OVERVIEW

OpenClaw v1 multi-agent orchestration system — 13 specialized AI agents coordinated by Hermes, with MCP tool integrations for calendar, tasks, and workflows.

## STRUCTURE

```
olympus-openclaw-config/
├── openclaw.json              # Root config (MCP servers, agent bindings)
├── config/
│   ├── agents.list.v1-full.json5  # 13-agent roster + tool policies
│   ├── agents.defaults.json5      # Shared defaults (memory, compaction)
│   ├── models.providers.json5     # LiteLLM model catalog
│   ├── tools.global.json5         # Loop detection, web config
│   └── plugins.v1.json5           # Enabled plugins (mattermost, whatsapp)
├── workspaces/                # Per-agent prompt packs
│   └── <agent>/               # AGENTS.md, TOOLS.md, MEMORY.md, HEARTBEATS.md
├── docs/                      # Routing strategy, tool policy docs
└── shared-memory/             # Cross-agent memory domains (finance, projects)
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add new agent | config/agents.list.v1-full.json5 + create workspaces/&lt;agent&gt;/ |
| Configure MCP tools | openclaw.json → mcp.servers block |
| Change routing rules | docs/routing.md + workspaces/hermes/AGENTS.md |
| Adjust tool policies | agents.list.*.json5 → tools.allow/deny arrays |
| Add model provider | config/models.providers.json5 → litellm.models |
| Configure channels | openclaw.json → channels (mattermost, whatsapp) |

## CONVENTIONS

- **Hermes** is default entrypoint (default: true), workspace at /home/node/.openclaw/workspaces/hermes
- **MCP tools** (google-calendar, ticktick, n8n) are HERMES-ONLY — subagents cannot access them
- **Plutus** uses LOCAL models only (deepseek-r1:7b) — financial data never leaves cluster
- **Agent prompts** use 6-file pack: AGENTS.md, SOUL.md, TOOLS.md, IDENTITY.md, USER.md, MEMORY.md
- **Memory**: builtin backend, embeddings via nomic-embed-text-v2 through LiteLLM (local)

## ROUTING MAP

| Domain | Agent | Model |
|--------|-------|-------|
| Orchestration | Hermes | glm-5-turbo (cloud) |
| Code/Dev | Hephaestus | qwen3-coder-plus (cloud) |
| Research | Athena | MiniMax-M2.5 (cloud) |
| Finance (LOCAL) | Plutus | deepseek-r1:7b (local) |
| K8s/Infra | Prometheus | qwen3-coder-plus (cloud) |
| Audit/Risk | Themis | MiniMax-M2.5 (cloud) |
| Bias/Critique | Nemesis | MiniMax-M2.5 (cloud) |
| Writing | Calliope | MiniMax-M2.5 (cloud) |
| Communication | Iris | MiniMax-M2.5 (cloud) |
| Wellness | Asclepius | MiniMax-M2.5 (cloud) |
| Monitoring | Argus | MiniMax-M2.5 (cloud) |
| Memory | Mnemosyne | qwen3:8b (local) |
| Planning/GTD | Persephone | MiniMax-M2.5 (cloud) |

## MCP SERVERS

Defined in openclaw.json lines 100-154:
- google-calendar: npx @cocal/google-calendar-mcp (OAuth)
- ticktick: https://mcp.ticktick.com (streamable-http, OAuth)
- n8n: http://n8n.olympus.svc.cluster.local:5678/mcp-server/http
- sequential-thinking: npx @modelcontextprotocol/server-sequential-thinking
- kubernetes: npx kubernetes-mcp-server --disable-destructive
- filesystem/postgres/web-search-prime/web-reader/zreader

## ANTI-PATTERNS

- DO NOT give subagents (Hephaestus, Athena, etc.) access to google-calendar or ticktick MCPs
- DO NOT route Plutus financial data through cloud APIs
- DO NOT point root config at plugins.future.example.json5 — it's a template
- DO NOT add exec/process tools to Hermes — orchestration only

## KEY FILES

| File | Purpose |
|------|---------|
| openclaw.json | Root config — MCP servers, gateway, hooks, channels |
| config/agents.list.v1-full.json5 | Full agent definitions with per-agent tool allow/deny |
| workspaces/hermes/AGENTS.md | Hermes routing map and delegation rules |
| workspaces/hermes/TOOLS.md | MCP tool usage guidance (direct calls, no delegation) |
| workspaces/hermes/HEARTBEATS.md | Daily/weekly briefing automation |
| docs/routing.md | Single-domain vs multi-domain routing strategy |
