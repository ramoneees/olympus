  # OLYMPUS v1 for OpenClaw

This pack gives you an implementable **v1** for the OLYMPUS multi-agent system on top of OpenClaw.

## What is included

- A **root `openclaw.json`** that uses `$include` so the config stays modular.
- A **functional v1 agent list** with:
  - `hermes` (dispatcher / orchestrator)
  - `hephaestus` (development)
  - `athena` (research)
- A **v1 + finance** agent list that adds `plutus`.
- A **v1 full** agent list that adds both `plutus` and `themis`.
- Workspace prompt packs (`AGENTS.md`, `SOUL.md`, `TOOLS.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`) for every agent.
- A **future plugin template** f  or shared pgvector memory and external tools.

## Design assumptions

1. **Single OpenClaw Gateway**.
2. **Hermes is the only default external entrypoint**.
3. Hermes delegates to specialists using OpenClaw sub-agents.
4. Strong isolation is enforced primarily through:
   - per-agent workspaces
   - per-agent tool allow/deny
   - Docker sandboxing
5. **Built-in memory stays native to OpenClaw** in v1.
6. **Shared pgvector memory is treated as a future custom plugin/service**, not as a replacement for native OpenClaw memory.

## Important Ollama note

This pack assumes the Gateway can reach your Ollama server at `http://127.0.0.1:11434`.

That is the easiest way to preserve OpenClaw's **implicit Ollama model discovery**. In practice, on a two-machine setup, the cleanest options are:

- an SSH tunnel from the Mini PC to the main server
- a local reverse proxy on the Mini PC
- a Tailscale/private-network endpoint exposed locally on the Mini PC

If you do **not** want that local endpoint, create an explicit `models.providers.ollama` block and manually define the model catalog.

## Suggested environment variables

Put these in `~/.openclaw/.env` or your service environment:

```bash
OLLAMA_API_KEY=ollama-local
ZAI_API_KEY=...
MINIMAX_API_KEY=...
OPENROUTER_API_KEY=...
BRAVE_API_KEY=...
# Optional if you use Qwen OAuth
# no static key required after provider login
# Optional future integrations
PGVECTOR_DSN=postgresql://user:pass@host:5432/olympus
FIREFLY_BASE_URL=https://firefly.example.com
FIREFLY_TOKEN=...
INVOICE_NINJA_BASE_URL=https://ninja.example.com
INVOICE_NINJA_TOKEN=...
GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
SLACK_BOT_TOKEN=xoxb-...
```

## Install path

Recommended layout:

```text
~/.openclaw/
├── openclaw.json
├── config/
│   ├── agents.defaults.json5
│   ├── agents.list.v1.json5
│   ├── bindings.v1.json5
│   ├── models.providers.json5
│   ├── plugins.v1.json5
│   └── tools.global.json5
└── olympus/
    └── workspaces/
        ├── hermes/
        ├── hephaestus/
        ├── athena/
        ├── plutus/
        └── themis/
```

## Activation steps

1. Copy the root `openclaw.json` and the `config/` directory into `~/.openclaw/`.
2. Copy the agent workspace folders into `~/.openclaw/olympus/workspaces/`.
3. Make sure the Gateway sees Ollama at `127.0.0.1:11434`.
4. Enable and log in to Qwen only if you want `qwen-portal/coder-model`.
5. Start or restart the Gateway.
6. Validate with:

```bash
openclaw config validate
openclaw models list
openclaw agents list --bindings
openclaw sandbox explain --agent hermes
openclaw dashboard
```

## Switching versions

- **Current root config** points to `config/agents.list.v1.json5`.
- To add finance, swap to `config/agents.list.v1-finance.json5`.
- To add strategy/audit too, swap to `config/agents.list.v1-full.json5`.

## Future plugin mapping

See:

- `config/plugins.future.example.json5`
- `plugins/README.md`

Those files define the intended shape for:

- shared pgvector memory
- Google integrations
- Slack integrations
- finance tools (Firefly / Invoice Ninja)
- specialized dev / knowledge plugins
