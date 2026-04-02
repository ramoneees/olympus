# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OLYMPUS is a personal homelab Kubernetes infrastructure project with an integrated multi-agent AI orchestration system. It is Infrastructure-as-Code (IaC) — primarily YAML manifests for a self-hosted k3s cluster running on two physical servers.

## Infrastructure

- **Cluster**: k3s v1.34.5+k3s1, two nodes
  - **Server 1 (control plane)**: NiPoGi N100, 192.168.50.10, 16GB RAM
  - **Server 2 (GPU worker)**: Ryzen 5600X, 64GB RAM, RTX 2080 8GB
- **Ingress**: Traefik (bundled with k3s)
- **Development machine**: macOS with kubectl v1.35.2, Helm, k9s, kubeconfig pointing to 192.168.50.10:6443

## Commands

```bash
# Bootstrap (one-time, before ArgoCD exists)
./bootstrap/install.sh

# Day-to-day — all changes go through git, ArgoCD syncs automatically
git commit && git push   # ArgoCD auto-syncs from Gitea

# Debugging
k9s                                # Interactive cluster monitor
kubectl logs <pod>                 # View pod logs
kubectl get pods -A                # List all pods
kubectl describe pod <pod>         # Pod events and status
```

## Repo Structure

- `bootstrap/` — One-time manual installs (MetalLB, cert-manager, ArgoCD). Applied via `install.sh`.
- `infrastructure/` — ArgoCD-managed infra (Longhorn, Traefik config, AdGuard, GPU Operator)
- `databases/` — Shared database instances (PostgreSQL, MariaDB, Redis)
- `apps/` — One directory per application, each with `values.yaml` + `ingress.yaml`
- `olympus/` — AI/GPU workloads (Ollama, LiteLLM, OpenClaw, Open WebUI, n8n, Jellyfin)
- `olympus/olympus-openclaw-config/` — OpenClaw agent configuration source (JSON5 configs + workspace files)
- `olympus/openclaw/` — OpenClaw K8s manifests (deployment, configmap, secrets, ingress)
- `monitoring/` — Prometheus stack, Loki, Promtail, Grafana
- `argocd/` — ArgoCD Application manifests (root app-of-apps pattern)
- `scripts/` — Utility scripts (SSH firewall, etc.)

## GitOps Workflow

Edit YAML manifests → commit/push to Gitea (olympus repo) → ArgoCD auto-sync → cluster applies changes. No manual `kubectl apply` after bootstrap.

## Conventions

- All secrets use Kubernetes Secrets with placeholder templates in `secrets.yaml` files — never commit real values
- All persistent storage via Longhorn PVCs, no hostPath except where unavoidable
- Every service gets a Traefik IngressRoute with TLS via the `wildcard-ramoneees-com-tls` secret
- GPU/heavy workloads use `nodeSelector: kubernetes.io/hostname: olympus`
- Resource requests and limits on every pod
- Namespaces: `infrastructure`, `databases`, `apps`, `olympus`, `monitoring`
- Wildcard TLS secret is reflected across namespaces via kubernetes-reflector

## Backup Strategy

3-layer backup with Backblaze B2 (eu-central-003 region):

| Time (UTC) | Layer | Job | Target |
|------------|-------|-----|--------|
| 02:00 daily | L1 | PostgreSQL SQL dump | Local PVC `db-backups` |
| 03:00 daily | L1 | MariaDB SQL dump | Local PVC `db-backups` |
| 04:00 daily | L3 | rclone sync dumps → B2 | `olympus-sql-dumps` bucket |
| 05:00 daily | L2 | Longhorn snapshot PG | `olympus-longhorn-backups` bucket |
| 05:15 daily | L2 | Longhorn snapshot MariaDB | `olympus-longhorn-backups` bucket |
| 05:30 daily | L2 | Longhorn snapshot Redis | `olympus-longhorn-backups` bucket |
| Sun 06:00 | Verify | Restore test from B2 | Temp PostgreSQL DB |

- **Layer 1** (local): CronJobs in `databases/backups/` — 7-day retention, gzipped dumps
- **Layer 2** (Longhorn → B2): RecurringJobs in `infrastructure/longhorn-extras/` — 7-backup retention, volumes opt in via labels
- **Layer 3** (off-cluster): rclone CronJob syncs PVC to B2 — `databases/backups/rclone-sync-cronjob.yaml`
- **Verify**: Weekly restore test — `databases/backups/restore-verify-cronjob.yaml`
- **Alerts**: PrometheusRules in `databases/backups/alerts.yaml` — fires on job failures and staleness
- **ArgoCD**: `db-backups` app syncs `databases/backups/`, `longhorn-extras` app syncs `infrastructure/longhorn-extras/`

## OLYMPUS Multi-Agent Architecture

An AI orchestration layer using OpenClaw, with 13 specialized agents:

| Agent | Role | Model | Tool Profile |
|-------|------|-------|-------------|
| **Hermes** (orchestrator) | Routes tasks, coordinates agents | glm-5-turbo (cloud) | full (deny exec/write) + sessions |
| **Hephaestus** | Developer/Code | qwen3-coder-plus (cloud) | coding (sandboxed) |
| **Prometheus** | Infrastructure/IaC | qwen3-coder-plus (cloud) | coding |
| **Athena** | Research/Docs | MiniMax-M2.5 (cloud) | minimal + web + MCP web readers |
| **Plutus** | Finance | MiniMax-M2.7 (cloud, hardened) | minimal + read/write + MCP firefly-iii |
| **Themis** | Strategy & Audit | MiniMax-M2.5 (cloud) | minimal + read + web |
| **Mnemosyne** | Memory Curator | qwen3:8b (local Ollama) | minimal + memory |
| **Nemesis** | Critique & Bias Detection | MiniMax-M2.5 (cloud) | minimal + memory + sessions_spawn |
| **Iris** | Communication & Messaging | MiniMax-M2.5 (cloud) | minimal + read + memory + message |
| **Calliope** | Writing & Content | MiniMax-M2.5 (cloud) | minimal + read + memory + sessions_spawn |
| **Asclepius** | Health & Wellness | MiniMax-M2.5 (cloud) | minimal + memory + message |
| **Argus** | Monitoring & Alerts | MiniMax-M2.5 (cloud) | minimal + memory + MCP kubernetes |
| **Persephone** | Planning & GTD | MiniMax-M2.5 (cloud) | minimal + memory + sessions_spawn |

### LLM Routing

All model traffic through LiteLLM (unified proxy) → Ollama (local) or DashScope/OpenRouter (cloud). Models are referenced with `litellm/` prefix in agent configs. LiteLLM runs in `olympus` namespace at `http://litellm.olympus.svc.cluster.local:4000`.

### Memory Architecture

- **Backend**: Built-in (SQLite + sqlite-vec vector index)
- **File storage**: Markdown files in agent workspaces (`/home/node/.openclaw/workspaces/<agent>/`)
- **Embeddings**: `nomic-embed-text-v2` via LiteLLM → Ollama (local, never leaves cluster)
- **Search**: Hybrid (BM25 text 0.3 + vector 0.7), MMR diversity, 30-day temporal decay
- **Memory flush**: Enabled — agents persist durable memories before context compaction (threshold: 4000 tokens)
- **Session memory**: Experimental cross-session recall enabled, indexed via `memory_search`
- **Embedding cache**: 50,000 entries
- **Sync thresholds**: 100KB or 50 messages triggers re-indexing

### Communication Channels

- **Mattermost**: Hermes bot integration with DM pairing, callback via `https://openclaw.ramoneees.com`
- **WhatsApp**: Self-chat mode with allowlist
- **Gateway**: Port 18789, token auth, accessible at `https://openclaw.ramoneees.com`
- **Hooks**: Enabled (boot-md, command-logger, session-memory)

### Container Runtime

- Image: `ghcr.io/openclaw/openclaw:latest`
- Homebrew (Linuxbrew) at `/home/linuxbrew/.linuxbrew` for skill dependencies
- npm global installs at `/home/node/.openclaw/npm-global`
- PVC-backed data at `/home/node/.openclaw` (10Gi Longhorn)
- Sandbox mode: off (tool allow/deny lists provide per-agent isolation)

## Key Services Stack

- **Comms**: Mattermost + Hermes bot
- **Tasks**: Vikunja
- **GitOps**: ArgoCD + Gitea
- **Storage**: Longhorn
- **Databases**: PostgreSQL (pgvector), MariaDB, Redis
- **Finance**: Firefly III, Invoice Ninja
- **Automation**: n8n (Execute Command node enabled)
- **Auth**: Authentik (SSO), Vaultwarden
- **GPU**: NVIDIA GPU Operator (Helm)
- **AI**: Ollama (local inference), LiteLLM (proxy), OpenClaw (orchestration), Open WebUI (chat UI at ai.ramoneees.com)

## Monitoring Stack

- **Prometheus**: Metrics collection, 15-day retention, 20Gi storage — `https://prometheus.ramoneees.com`
- **Grafana**: Dashboards with Prometheus + Loki datasources — `https://grafana.ramoneees.com`
- **Alertmanager**: Alert routing, 2Gi storage — `https://alertmanager.ramoneees.com`
- **Loki**: Log aggregation (SingleBinary mode), 7-day retention, 10Gi storage
- **Promtail**: DaemonSet log collector shipping to Loki
- k3s-incompatible components disabled: kubeEtcd, kubeControllerManager, kubeScheduler, kubeProxy

## Privacy Constraint

Plutus (finance agent) uses a cloud model (MiniMax-M2.7 via OpenRouter) for budget reasons. To mitigate data exposure: `web_fetch` is denied (no outbound HTTP to arbitrary URLs), filesystem access is limited to `read`+`write` (no `edit`/`apply_patch`), and financial queries go through the `firefly-iii` MCP (structured API, not raw data). Memory embeddings use local Ollama (nomic-embed-text-v2 via LiteLLM), so Plutus memory search remains local-safe.

## Architecture Documentation

Detailed architecture is in `docs/homelab_architecture.html`.
