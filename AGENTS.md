# AGENTS.md

Guide for AI agents working on the OLYMPUS homelab Kubernetes infrastructure.

## Project Summary

OLYMPUS is a GitOps-managed k3s Kubernetes cluster with:
- **2 nodes**: Control plane (N100, 16GB) + GPU worker (Ryzen 5600X, 64GB, RTX 2080)
- **GitOps**: ArgoCD auto-syncs from Gitea → no manual `kubectl apply`
- **Workloads**: Self-hosted apps (Mattermost, Firefly III, Vikunja, etc.) + AI agents (OpenClaw)

## Repository Structure

```
bootstrap/              One-time setup (MetalLB, cert-manager, ArgoCD)
infrastructure/         Longhorn, Traefik, GPU Operator, AdGuard
databases/              PostgreSQL, MariaDB, Redis + backup jobs
apps/                   Application workloads (one dir per app)
olympus/                GPU-pinned workloads (Ollama, LiteLLM, OpenClaw, n8n)
  └── olympus-openclaw-config/   Agent configs (JSON5 + workspace prompts)
monitoring/             Prometheus, Grafana, Loki, Promtail
argocd/                 App-of-apps Application manifests
scripts/                Utility scripts
```

## Making Changes

### Workflow

1. **Edit YAML manifests** in the appropriate directory
2. **Commit and push** to Gitea
3. **ArgoCD auto-syncs** — changes apply automatically

No manual `kubectl apply` after bootstrap. The cluster watches this repo.

### Where to Put Things

| What | Where |
|------|-------|
| New app | `apps/<app-name>/` with `values.yaml` + `ingress.yaml` |
| Infra component | `infrastructure/<component>/` |
| Database | `databases/<db-type>/` |
| AI/GPU workload | `olympus/<workload>/` |
| ArgoCD app definition | `argocd/<app>.yaml` |

## Conventions

### Kubernetes Manifests

- **Namespaces**: `infrastructure`, `databases`, `apps`, `olympus`, `monitoring`
- **Storage**: All persistent storage via Longhorn PVCs — no `hostPath` except where unavoidable
- **Ingress**: Traefik IngressRoute with TLS via `wildcard-ramoneees-com-tls` secret
- **GPU pinning**: Add `nodeSelector: kubernetes.io/hostname: olympus` for GPU workloads
- **Resources**: Always define `requests` and `limits` on pods
- **Secrets**: Template files with placeholders — never commit real values

### YAML Style

- 2-space indentation
- Lists on separate lines (not inline)
- Comments for non-obvious choices
- Group related resources in same file when logical

### Helm Values

- Store in `values.yaml` alongside app manifests
- Reference external secrets via `${VAR}` syntax where supported
- Document non-default values with comments

## Validation

Before considering a change complete:

1. **Syntax check**: `kubectl apply --dry-run=client -f <file.yaml>`
2. **ArgoCD sync**: Check `argocd.ramoneees.com` for sync status
3. **Pod health**: `kubectl get pods -n <namespace>`
4. **Logs if needed**: `kubectl logs <pod> -n <namespace>`

## Common Commands

```bash
# Cluster overview
kubectl get pods -A
k9s

# Debug a pod
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace>

# Force ArgoCD sync (if auto-sync delayed)
argocd app sync <app-name>

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## Hard Constraints

1. **Never commit real secrets** — use placeholder templates
2. **Never use `kubectl apply` directly** — all changes via git
3. **Never bypass Longhorn** for persistent storage
4. **GPU workloads must have resource limits** — prevent node starvation
5. **Plutus agent must use local models only** — no cloud APIs for financial data

## Key Services

| Service | URL | Purpose |
|---------|-----|---------|
| ArgoCD | argocd.ramoneees.com | GitOps dashboard |
| Gitea | git.ramoneees.com | Git hosting |
| Mattermost | chat.ramoneees.com | Team chat |
| Vikunja | tasks.ramoneees.com | Task management |
| Firefly III | firefly.ramoneees.com | Finance tracking |
| Open WebUI | ai.ramoneees.com | LLM chat interface |
| Grafana | grafana.ramoneees.com | Monitoring dashboards |

## Multi-Agent System (OpenClaw)

OLYMPUS runs specialized AI agents via OpenClaw:

| Agent | Role | Model |
|-------|------|-------|
| Hermes | Orchestrator | glm-5-turbo (cloud) |
| Hephaestus | Developer | qwen3-coder-plus (cloud) |
| Prometheus | Infrastructure | qwen3-coder-plus (cloud) |
| Athena | Research | MiniMax-M2.5 (cloud) |
| Plutus | Finance | deepseek-r1:7b (local only) |
| Themis | Strategy/Audit | MiniMax-M2.5 (cloud) |
| Mnemosyne | Memory Curator | qwen3:8b (local) |

Agent configs: `olympus/olympus-openclaw-config/config/`
Workspace prompts: `olympus/olympus-openclaw-config/workspaces/<agent>/`

## Backup Architecture

3-layer backup to Backblaze B2:

- **L1 (local)**: SQL dumps to PVC via CronJobs
- **L2 (Longhorn)**: Volume snapshots → B2
- **L3 (off-cluster)**: rclone sync dumps → B2

See `databases/backups/` for backup manifests.

## Questions to Ask Before Acting

- Is this a K8s manifest change or application code?
- Does this affect GPU-pinned workloads?
- Are there existing patterns in similar apps to follow?
- Does this require new secrets? If so, create template only.
- Will this break ArgoCD sync if applied incorrectly?
