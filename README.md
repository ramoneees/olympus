# OLYMPUS

A personal homelab Kubernetes infrastructure with an integrated multi-agent AI orchestration system. Pure GitOps — YAML manifests for a self-hosted k3s cluster running on two physical servers, automatically synced via Flux CD.

## Infrastructure

| Node | Hardware | IP | Role |
|------|----------|----|------|
| Server 1 | NiPoGi N100, 16GB RAM | 192.168.50.10 | Control plane |
| Server 2 | Ryzen 5600X, 64GB RAM, RTX 2080 8GB | — | GPU worker |

- **Cluster**: k3s v1.34.5+k3s1
- **Ingress**: Traefik (bundled with k3s)
- **Storage**: Longhorn (distributed block storage)
- **TLS**: Wildcard cert for `*.ramoneees.com`, reflected across namespaces via kubernetes-reflector

## GitOps Workflow

```
Edit YAML → git push to Gitea → Flux CD auto-sync → cluster applies changes
```

No manual `kubectl apply` after initial bootstrap. Flux CD reconciles from `clusters/olympus/` with layered Kustomizations.

## Repo Structure

```
bootstrap/          One-time installs (MetalLB, cert-manager, Flux CD)
├── install.sh      Bootstrap script
infrastructure/     Flux-managed infra
├── longhorn/       Distributed storage
├── traefik/        Ingress configuration
databases/          Shared database instances
├── postgresql/     PostgreSQL with pgvector
├── mariadb/        MariaDB
├── redis/          Redis
apps/               Application workloads
├── mattermost/     Team chat (chat.ramoneees.com)
├── gitea/          Git hosting
├── vikunja/        Task management (tasks.ramoneees.com)
├── firefly-iii/    Finance tracking + cron + data importer (firefly.ramoneees.com)
├── invoice-ninja/  Invoicing
├── authentik/      SSO/Identity provider
├── vaultwarden/    Password manager
├── uptime-kuma/    Uptime monitoring
├── cloudbeaver/    Database web UI
├── homebox/        Home inventory
├── adguard/        DNS ad-blocking
olympus/            GPU-pinned workloads
├── vllm/           Local LLM inference (vLLM)
├── litellm/        Unified LLM proxy
├── hermes-agent/   Hermes Agent (baremetal, nousresearch.com)
├── openwebui/   Web UI for LLM chat
├── jellyfin/       Media server
├── n8n/            Workflow automation
├── nextcloud/      File sync & collaboration
├── browserless/    Headless browser service
├── firefox/        Browser instance
├── agents-avatars/ Agent profile images
├── olympus-agent-config/  Agent configuration
monitoring/         Observability stack
├── kube-prometheus-stack/    Prometheus + Grafana
├── loki/           Log aggregation
clusters/olympus/    Flux Kustomizations + Git sources
├── sources.yaml    GitRepository + HelmRepository sources
├── namespaces.yaml Namespaces Kustomization
├── infrastructure.yaml Infra layer
├── databases.yaml  Databases layer
├── apps.yaml       Apps layer
├── olympus.yaml    GPU/Olympus layer
├── monitoring.yaml Monitoring layer
docs/               Architecture documentation
```

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Mattermost | chat.ramoneees.com | Team communications |
| Vikunja | tasks.ramoneees.com | Task management |
| Firefly III | firefly.ramoneees.com | Personal finance |
| Data Importer | firefly-import.ramoneees.com | Firefly III data import |
| Invoice Ninja | invoice.ramoneees.com | Invoicing |
| Gitea | git.ramoneees.com | Git hosting |
| Uptime Kuma | status.ramoneees.com | Uptime monitoring |
| Vaultwarden | vault.ramoneees.com | Password manager |
| AdGuard | adguard.ramoneees.com | DNS ad-blocking |
| CloudBeaver | db.ramoneees.com | Database web UI |
| Homebox | homebox.ramoneees.com | Home inventory |
| Authentik | — | SSO / Identity (ingress pending) |
| Grafana | — | Dashboards & monitoring (ingress pending) |
| OpenWebUI | ai.ramoneees.com | Web UI for LLM chat |
| Hermes Agent | hermes-agent.nousresearch.com | Multi-agent AI orchestrator (baremetal) |
| Jellyfin | — | Media server (ingress pending) |
| n8n | — | Workflow automation (ingress pending) |
| Nextcloud | — | File sync (ingress pending) |

## OLYMPUS Multi-Agent System

An AI orchestration layer powered by Hermes Agent (running baremetal via nousresearch.com), with specialized agents communicating through Mattermost and coordinated by a central orchestrator.

### Agents

| Agent | Role | Model | Locality |
|-------|------|-------|----------|
| **Hermes** | Orchestrator — routes tasks, coordinates agents | GLM-5-Turbo | Cloud |
| **Hephaestus** | Developer — code generation & review | phi4-mini | Local (GPU/vLLM) |
| **Prometheus** | Infrastructure — IaC & DevOps | phi4-mini | Local (GPU/vLLM) |
| **Athena** | Researcher — docs & knowledge | GLM-5-Turbo | Cloud |
| **Plutus** | Finance — LOCAL ONLY, no cloud APIs | phi4-mini | Local (GPU/vLLM) |
| **Themis** | Strategy & Audit | GLM-5-Turbo | Cloud |
| **Mnemosyne** | Memory Curator | phi4-mini | Local (GPU/vLLM) |

### LLM Routing

```
vLLM (local GPU inference) → LiteLLM (unified proxy) → Cloud APIs (fallback)
```

### Memory Architecture

| Layer | Backend | Purpose |
|-------|---------|---------|
| Short-term | Redis | Conversation context |
| Long-term | PostgreSQL + pgvector (nomic-embed-text-v2) | Semantic search over past interactions |
| Episodic | Vikunja audit trail | Task history & decision log |

### Privacy Constraint

Plutus (finance agent) must use **local models exclusively** — financial data never routes through cloud APIs.

## Getting Started

### Prerequisites

- Two servers on the same network
- k3s installed on both nodes
- `kubectl`, `helm`, and `k9s` on your dev machine
- Kubeconfig pointing to the control plane (192.168.50.10:6443)

### Bootstrap

```bash
# One-time setup (before Flux CD exists)
./bootstrap/install.sh
```

This installs MetalLB, cert-manager, and Flux CD. After bootstrap, all changes are managed through GitOps.

### Day-to-Day

```bash
# All changes go through git
git commit && git push   # Flux CD auto-syncs from Gitea

# Debugging
k9s                        # Interactive cluster monitor
kubectl logs <pod>         # View pod logs
kubectl get pods -A        # List all pods
kubectl describe pod <pod> # Pod events and status
```

## Conventions

- Secrets use Kubernetes Secrets with placeholder templates — never commit real values
- All persistent storage via Longhorn PVCs
- Every service gets a Traefik IngressRoute with TLS via `wildcard-ramoneees-com-tls`
- GPU workloads use `nodeSelector: kubernetes.io/hostname: olympus`
- Resource requests and limits on every pod
- Namespaces: `infrastructure`, `databases`, `apps`, `olympus`, `monitoring`

## Architecture Documentation

Detailed interactive architecture diagram available in `docs/homelab_architecture.html`.
