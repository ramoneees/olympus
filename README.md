# OLYMPUS

A personal homelab Kubernetes infrastructure with an integrated multi-agent AI orchestration system. Pure GitOps — YAML manifests for a self-hosted k3s cluster running on two physical servers, automatically synced via ArgoCD.

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
Edit YAML → git push to Gitea → ArgoCD auto-sync → cluster applies changes
```

No manual `kubectl apply` after initial bootstrap. ArgoCD uses an app-of-apps pattern with phased rollout.

## Repo Structure

```
bootstrap/          One-time installs (MetalLB, cert-manager, ArgoCD)
├── install.sh      Bootstrap script
infrastructure/     ArgoCD-managed infra
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
├── ollama/         Local LLM inference
├── litellm/        Unified LLM proxy
├── openclaw/       Multi-agent orchestrator (baremetal, ingress routing only)
├── openwebui/      LLM chat interface
├── jellyfin/       Media server
├── n8n/            Workflow automation
├── nextcloud/      File sync & collaboration
├── browserless/    Headless browser service
├── firefox/        Browser instance
├── agents-avatars/ Agent profile images
├── olympus-openclaw-config/  Agent configuration
monitoring/         Observability stack
├── kube-prometheus-stack/    Prometheus + Grafana
├── loki/           Log aggregation
argocd/             ArgoCD Application manifests
├── root.yaml       App-of-apps root
├── namespaces.yaml
├── infrastructure.yaml
├── databases.yaml
├── apps.yaml
├── apps-phase4.yaml
├── adguard.yaml
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
| ArgoCD | argocd.ramoneees.com | GitOps deployment |
| Uptime Kuma | status.ramoneees.com | Uptime monitoring |
| Vaultwarden | vault.ramoneees.com | Password manager |
| AdGuard | adguard.ramoneees.com | DNS ad-blocking |
| CloudBeaver | db.ramoneees.com | Database web UI |
| Homebox | homebox.ramoneees.com | Home inventory |
| Authentik | — | SSO / Identity (ingress pending) |
| Grafana | — | Dashboards & monitoring (ingress pending) |
| Open WebUI | — | LLM chat interface (ingress pending) |
| OpenClaw | openclaw.ramoneees.com | Multi-agent AI orchestrator (baremetal) |
| Jellyfin | — | Media server (ingress pending) |
| n8n | — | Workflow automation (ingress pending) |
| Nextcloud | — | File sync (ingress pending) |

## OLYMPUS Multi-Agent System

An AI orchestration layer powered by OpenClaw (running as baremetal systemd on the olympus node), with specialized agents communicating through Mattermost and coordinated by a central orchestrator.

### Agents

| Agent | Role | Model | Locality |
|-------|------|-------|----------|
| **Hermes** | Orchestrator — routes tasks, coordinates agents | GLM-5-Turbo | Cloud |
| **Hephaestus** | Developer — code generation & review | qwen2.5-coder:7b | Local (GPU) |
| **Prometheus** | Infrastructure — IaC & DevOps | qwen2.5-coder:7b | Local (GPU) |
| **Athena** | Researcher — docs & knowledge | GLM-5-Turbo | Cloud |
| **Plutus** | Finance — LOCAL ONLY, no cloud APIs | deepseek-r1:7b | Local (GPU) |
| **Themis** | Strategy & Audit | GLM-5-Turbo | Cloud |
| **Mnemosyne** | Memory Curator | qwen3:8b | Local (GPU) |

### LLM Routing

```
Ollama (local GPU inference) → LiteLLM (unified proxy) → Cloud APIs (fallback)
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
# One-time setup (before ArgoCD exists)
./bootstrap/install.sh
```

This installs MetalLB, cert-manager, and ArgoCD. After bootstrap, all changes are managed through GitOps.

### Day-to-Day

```bash
# All changes go through git
git commit && git push   # ArgoCD auto-syncs from Gitea

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
