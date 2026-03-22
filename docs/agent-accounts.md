# OLYMPUS Agent Accounts & Token Structure

> Comprehensive reference for all agent identities, service accounts, and credential storage.

## Email Routing

All agent emails route via **Cloudflare Email Routing** to the owner's personal inbox.
Catch-all is enabled as a safety net.

| Agent | Email |
|-------|-------|
| Hermes | hermes@ramoneees.com |
| Hephaestus | hephaestus@ramoneees.com |
| Prometheus | prometheus@ramoneees.com |
| Athena | athena@ramoneees.com |
| Plutus | plutus@ramoneees.com |
| Themis | themis@ramoneees.com |
| Mnemosyne | mnemosyne@ramoneees.com |

---

## Access Matrix

### Hermes (Orchestrator)

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read/Write | `hermes-vikunja-token` | `vikunja-agent-secrets` | apps |
| Mattermost | Read/Write (bot) | `hermes-mattermost-bot` | `mattermost-agent-secrets` | apps |
| n8n | Webhook triggers | n/a (webhook URLs) | `n8n-agent-secrets` | apps |

Hermes is the central orchestrator — delegates tasks to other agents via Vikunja, communicates via Mattermost bot, and receives webhook events from n8n.

### Hephaestus (Developer/Code)

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read/Write (own project) | `hephaestus-vikunja-token` | `vikunja-agent-secrets` | apps |
| Gitea | Read/Write (repos) | `hephaestus-gitea-token` | `gitea-agent-secrets` | apps |

Hephaestus works on code tasks — commits to Gitea repos and tracks work in his own Vikunja project.

### Prometheus (Infrastructure/IaC)

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read/Write (own project) | `prometheus-vikunja-token` | `vikunja-agent-secrets` | apps |
| Gitea | Read/Write (IaC repos) | `prometheus-gitea-token` | `gitea-agent-secrets` | apps |
| Uptime Kuma | Read-only | `prometheus-uptimekuma-key` | `uptimekuma-agent-secrets` | monitoring |
| Authentik | Read-only | `prometheus-authentik-token` | `authentik-agent-secrets` | infrastructure |

Prometheus monitors infrastructure health, manages IaC repos, and reads auth events.

### Athena (Research/Docs)

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read/Write (own project) | `athena-vikunja-token` | `vikunja-agent-secrets` | apps |
| Homebox | Read-only | `athena-homebox-token` | `homebox-agent-secrets` | apps |

Athena handles research tasks and can query physical inventory via Homebox.

### Plutus (Finance) — LOCAL ONLY

> **CRITICAL: Plutus tokens NEVER leave the LAN. All secrets pinned to olympus node only.**

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read/Write (own project) | `plutus-vikunja-token` | `vikunja-agent-secrets` | apps |
| Firefly III | Read/Write | `plutus-firefly-token` | `firefly-agent-secrets` | apps |
| Invoice Ninja | Read/Write | `plutus-invoiceninja-token` | `invoiceninja-agent-secrets` | apps |

Plutus runs exclusively on local models (deepseek-r1:7b). Financial data never touches cloud APIs.

### Themis (Strategy & Audit)

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read all + approve | `themis-vikunja-token` | `vikunja-agent-secrets` | apps |
| Gitea | Read-only | `themis-gitea-token` | `gitea-agent-secrets` | apps |
| Firefly III | Read-only | `themis-firefly-token` | `firefly-agent-secrets` | apps |

Themis audits work across agents — reads all Vikunja projects, reviews Gitea commits, and audits financial records.

### Mnemosyne (Memory Curator)

| Service | Permission | Token Name | K8s Secret | Namespace |
|---------|-----------|------------|------------|-----------|
| Vikunja | Read all | `mnemosyne-vikunja-token` | `vikunja-agent-secrets` | apps |
| PostgreSQL (pgvector) | Read/Write | `mnemosyne-pgvector-creds` | `pgvector-agent-secrets` | databases |
| Redis | Read/Write | `mnemosyne-redis-creds` | `redis-agent-secrets` | databases |

Mnemosyne maintains the shared memory layer — reads all task history for episodic memory, writes embeddings to pgvector, and manages short-term state in Redis.

---

## Token Naming Convention

```
{agent}-{service}-{type}
```

Examples:
- `hermes-vikunja-token`
- `plutus-firefly-token`
- `prometheus-authentik-token`
- `mnemosyne-pgvector-creds`

## Secret Naming Convention

```
{service}-agent-secrets
```

All agent tokens for a given service are stored in a single secret per service:
- `vikunja-agent-secrets` — all 7 agents' Vikunja tokens
- `firefly-agent-secrets` — Plutus (rw) + Themis (ro) tokens
- `gitea-agent-secrets` — Hephaestus + Prometheus + Themis tokens
- `mattermost-agent-secrets` — Hermes bot token + channel IDs + webhooks

## Namespace Placement

| Namespace | Secrets |
|-----------|---------|
| `apps` | vikunja, mattermost, firefly, invoiceninja, homebox, gitea, n8n |
| `infrastructure` | authentik |
| `monitoring` | uptimekuma |
| `databases` | pgvector, redis (Mnemosyne credentials) |
| `olympus` | Per-agent combined runtime secrets (aggregated from above) |

## Runtime Secret Distribution

Each agent deployment in the `olympus` namespace gets a combined secret with all the credentials it needs:

```
hermes-runtime-secrets      → vikunja + mattermost + n8n tokens
hephaestus-runtime-secrets  → vikunja + gitea tokens
prometheus-runtime-secrets  → vikunja + gitea + uptimekuma + authentik tokens
athena-runtime-secrets      → vikunja + homebox tokens
plutus-runtime-secrets      → vikunja + firefly + invoiceninja tokens (LOCAL ONLY)
themis-runtime-secrets      → vikunja + gitea + firefly tokens
mnemosyne-runtime-secrets   → vikunja + pgvector + redis credentials
```
