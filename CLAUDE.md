# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OLYMPUS is a personal homelab Kubernetes infrastructure project with an integrated multi-agent AI orchestration system. It is Infrastructure-as-Code (IaC) — primarily YAML manifests for a self-hosted k3s cluster running on two physical servers.

## Infrastructure

- **Cluster**: k3s v1.34.5+k3s1, two nodes
  - **Server 1 (control plane)**: NiPoGi N100, 192.168.50.70, 16GB RAM
  - **Server 2 (GPU worker)**: Ryzen 5600X, 64GB RAM, RTX 2080 8GB
- **Ingress**: Traefik (bundled with k3s)
- **Development machine**: macOS with kubectl v1.35.2, Helm, k9s, kubeconfig pointing to 192.168.50.70:6443

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
- `infrastructure/` — ArgoCD-managed infra (Longhorn, Traefik config, AdGuard, monitoring)
- `databases/` — Shared database instances (PostgreSQL, MariaDB, Redis)
- `apps/` — One directory per application, each with `values.yaml` + `ingress.yaml`
- `olympus/` — GPU-pinned workloads (Ollama, LiteLLM, OpenClaw, Jellyfin, etc.)
- `monitoring/` — Prometheus stack, Loki, Grafana
- `argocd/` — ArgoCD Application manifests (root app-of-apps pattern)

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

An AI orchestration layer using OpenClaw, with agents specialized by role:

| Agent | Role | Model |
|-------|------|-------|
| **Hermes** (orchestrator) | Routes tasks, coordinates agents | MiniMax-M2.5 (DashScope cloud) |
| **Hephaestus** | Developer/Code | qwen3-coder-plus (DashScope cloud) |
| **Prometheus** | Infrastructure/IaC | qwen3-coder-plus (DashScope cloud) |
| **Athena** | Research/Docs | MiniMax-M2.5 (DashScope cloud) |
| **Plutus** | Finance (LOCAL ONLY, no cloud) | deepseek-r1:7b (local Ollama) |
| **Themis** | Strategy & Audit | MiniMax-M2.5 (DashScope cloud) |
| **Mnemosyne** | Memory Curator | qwen3:8b (local Ollama) |

**LLM routing**: All traffic through LiteLLM (unified proxy) → Ollama (local) or DashScope/OpenRouter (cloud).

**Memory architecture**: File-based (Markdown in agent workspaces) with SQLite+sqlite-vec vector index. Embeddings via nomic-embed-text-v2 through LiteLLM. Hybrid search (BM25 + vector), memory flush before context compaction, session memory indexing enabled.

## Key Services Stack

- **Comms**: Mattermost + Hermes bot
- **Tasks**: Vikunja
- **GitOps**: ArgoCD + Gitea
- **Storage**: Longhorn
- **Databases**: PostgreSQL (pgvector), MariaDB, Redis
- **Finance**: Firefly III, Invoice Ninja
- **Automation**: n8n
- **Auth**: Authentik (SSO), Vaultwarden
- **GPU**: NVIDIA GPU Operator (Helm)
- **Monitoring**: Prometheus + Grafana (kube-prometheus-stack), Loki + Promtail (logs)

## Privacy Constraint

Plutus (finance agent) must use LOCAL models exclusively — never route financial data through cloud APIs.

## Architecture Documentation

Detailed architecture is in `docs/homelab_architecture.html`.
