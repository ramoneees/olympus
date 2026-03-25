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

## OLYMPUS Multi-Agent Architecture

An AI orchestration layer using OpenClaw, with 7 specialized agents:

| Agent | Role | Model | Tool Profile |
|-------|------|-------|-------------|
| **Hermes** (orchestrator) | Routes tasks, coordinates agents | qwen3.5-plus (cloud) | minimal + sessions |
| **Hephaestus** | Developer/Code | qwen3-coder-plus (cloud) | coding |
| **Prometheus** | Infrastructure/IaC | qwen3-coder-plus (cloud) | coding |
| **Athena** | Research/Docs | MiniMax-M2.5 (cloud) | minimal + web |
| **Plutus** | Finance (LOCAL ONLY) | deepseek-r1:7b (local Ollama) | minimal + fs |
| **Themis** | Strategy & Audit | MiniMax-M2.5 (cloud) | minimal + web |
| **Mnemosyne** | Memory Curator | qwen3:8b (local Ollama) | minimal + memory |

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

Plutus (finance agent) must use LOCAL models exclusively — never route financial data through cloud APIs. Memory embeddings use local Ollama (nomic-embed-text-v2 via LiteLLM), so Plutus memory search is also local-safe.

## Architecture Documentation

Detailed architecture is in `docs/homelab_architecture.html`.
