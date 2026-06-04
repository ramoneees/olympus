# AGENTS.md

Guide for AI agents working on the OLYMPUS homelab Kubernetes infrastructure.

## Project Summary

OLYMPUS is a GitOps-managed k3s Kubernetes cluster with:
- **2 nodes**: Control plane (N100, 16GB) + GPU worker (Ryzen 5600X, 64GB, RTX 2080)
- **GitOps**: Flux CD auto-syncs from Gitea → no manual `kubectl apply`
- **Workloads**: Self-hosted apps (Mattermost, Firefly III, Vikunja, etc.) + AI agents (Hermes Agent)

## Repository Structure

```
bootstrap/              One-time setup (MetalLB, cert-manager, Flux CD)
infrastructure/         Longhorn, Traefik, GPU Operator, AdGuard, secrets/
databases/              PostgreSQL, MariaDB, Redis + backup jobs
apps/                   Application workloads (one dir per app)
olympus/                GPU-pinned workloads
  ├── hermes-agent/              Hermes Agent (baremetal, nousresearch.com)
  ├── vllm/                     Local LLM inference (phi4-mini)
  ├── tei/                      Local embeddings (bge-m3)
  ├── litellm/                  Unified LLM proxy
  ├── n8n/                      Workflow automation
  └── openwebui/    Web UI for LLM chat
monitoring/             Prometheus, Grafana, Loki, Promtail
clusters/olympus/       Flux Kustomizations + Git sources (see clusters/olympus/)
scripts/                Utility scripts
```

**Subdirectory guides:** `olympus/hermes-agent/`, `clusters/olympus/`

## Making Changes

### Workflow

1. **Edit YAML manifests** in the appropriate directory
2. **Commit and push** to Gitea
3. **Flux CD auto-syncs** — changes apply automatically

No manual `kubectl apply` after bootstrap. The cluster watches this repo.

### Where to Put Things

| What | Where |
|------|-------|
| New app | `apps/<app-name>/` with `values.yaml` + `ingress.yaml` |
| Infra component | `infrastructure/<component>/` |
| Database | `databases/<db-type>/` |
| AI/GPU workload | `olympus/<workload>/` |
| Flux Kustomization / HelmRelease | `clusters/olympus/<layer>.yaml` |

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

### App Structure Pattern

Most apps follow this structure:
```
apps/<app-name>/
├── deployment.yaml    # or values.yaml for Helm charts
├── ingress.yaml       # Traefik IngressRoute
└── secrets.yaml       # Template with PLACEHOLDER values
```

## Validation

Before considering a change complete:

1. **Syntax check**: `kubectl apply --dry-run=client -f <file.yaml>`
2. **Flux sync**: `flux get kustomizations` and `flux get helmreleases -A`
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

# Force Flux reconcile (if auto-sync delayed)
flux reconcile kustomization <name>
flux reconcile helmrelease <name> --namespace <ns>

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## Hard Constraints

1. **Never commit real secrets** — use placeholder templates (see `infrastructure/secrets/agent-secrets-template/`)
2. **Never use `kubectl apply` directly** — all changes via git push to Gitea
3. **Never bypass Longhorn** for persistent storage
4. **GPU workloads must have resource limits** — prevent node starvation
5. **Plutus agent must use local models only** — no cloud APIs for financial data
6. **Hermes MCP tools are non-delegatable** — calendar/tasks/n8n MCPs are Hermes-only
7. **Hermes Agent is baremetal** — runs on ourmetal node via nousresearch.com endpoint; do not re-add as K8s Deployment

## Key Services

| Service | URL | Purpose |
|---------|-----|---------|
| Flux CD | (CLI) `flux get kustomizations` | GitOps controller |
| Gitea | git.ramoneees.com | Git hosting |
| Mattermost | chat.ramoneees.com | Team chat |
| Vikunja | tasks.ramoneees.com | Task management |
| Firefly III | firefly.ramoneees.com | Finance tracking |
| OpenWebUI | ai.ramoneees.com | Web UI for LLM chat |
| Hermes Agent | hermes-agent.nousresearch.com | Multi-agent AI orchestrator (baremetal) |
| Grafana | grafana.ramoneees.com | Monitoring dashboards |

## Multi-Agent System (Hermes Agent)

OLYMPUS runs specialized AI agents via Hermes Agent (baremetal at https://hermes-agent.nousresearch.com/):

| Agent | Role | Model |
|-------|------|-------|
| Hermes | Orchestrator | glm-5-turbo (cloud) |
| Hephaestus | Developer | qwen3-coder-plus (cloud) |
| Prometheus | Infrastructure | qwen3-coder-plus (cloud) |
| Athena | Research | MiniMax-M2.5 (cloud) |
| Plutus | Finance | deepseek-r1:7b (local only) |
| Themis | Strategy/Audit | MiniMax-M2.5 (cloud) |
| Mnemosyne | Memory Curator | qwen3:8b (local) |
| Nemesis | Bias/Critique | MiniMax-M2.5 (cloud) |
| Calliope | Writing | MiniMax-M2.5 (cloud) |
| Iris | Communication | MiniMax-M2.5 (cloud) |
| Asclepius | Wellness | MiniMax-M2.5 (cloud) |
| Argus | Monitoring | MiniMax-M2.5 (cloud) |
| Persephone | Planning/GTD | MiniMax-M2.5 (cloud) |

Agent configs: `olympus/hermes-agent/config/`
Workspace prompts: `olympus/hermes-agent/workspaces/<agent>/`

See `olympus/hermes-agent/` for Hermes Agent configuration.

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
- Will this break Flux reconcile if applied incorrectly?
