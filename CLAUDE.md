# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OLYMPUS is a personal homelab Kubernetes infrastructure project. It is Infrastructure-as-Code (IaC) — primarily YAML manifests for a self-hosted k3s cluster running on two physical servers.

## Infrastructure

- **Cluster**: k3s v1.34.5+k3s1, two nodes
  - **Server 1 (control plane)**: NiPoGi N100, 192.168.50.10, 16GB RAM
  - **Server 2 (GPU worker)**: Ryzen 5600X, 64GB RAM, RTX 2080 8GB
- **Ingress**: Traefik (bundled with k3s)
- **Development machine**: macOS with kubectl v1.35.2, Helm, k9s, kubeconfig pointing to 192.168.50.10:6443

## Commands

```bash
# Bootstrap (one-time, before Flux exists)
./bootstrap/install.sh

# Day-to-day — all changes go through git, Flux syncs automatically
git commit && git push   # Flux auto-syncs from Gitea

# Flux status
flux get kustomizations            # Layer-level sync status
flux get helmreleases -A           # Helm release status
flux reconcile source git olympus  # Force immediate sync

# Debugging
k9s                                # Interactive cluster monitor
kubectl logs <pod>                 # View pod logs
kubectl get pods -A                # List all pods
kubectl describe pod <pod>         # Pod events and status
```

## Repo Structure

- `bootstrap/` — One-time manual installs (MetalLB, cert-manager, Flux CD). Applied via `install.sh`.
- `clusters/olympus/` — Flux CD entrypoint: GitRepository/HelmRepository sources and layer Kustomizations
- `infrastructure/` — Flux-managed infra (Longhorn, Traefik config, GPU Operator, Reloader, Weave GitOps)
- `databases/` — Shared database instances (PostgreSQL, MariaDB, Redis)
- `apps/` — One directory per application, each with `values.yaml` + `ingress.yaml`
- `olympus/` — AI/GPU workloads (Ollama, LiteLLM, OpenWebUI, n8n)
- `monitoring/` — Prometheus stack, Loki, Promtail, Grafana
- `scripts/` — Utility scripts (SSH firewall, etc.)

## GitOps Workflow

Edit YAML manifests → commit/push to Gitea (olympus repo) → Flux CD auto-sync → cluster applies changes. No manual `kubectl apply` after bootstrap.

Flux uses a layered Kustomization hierarchy with dependency ordering:
```
namespaces → infrastructure → databases → apps / olympus / monitoring
```

Helm-based apps use `HelmRelease` CRDs alongside existing `values.yaml` files. Plain YAML apps have `kustomization.yaml` files listing their resources. Stakater Reloader handles automatic pod restarts on ConfigMap/Secret changes.

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
- **Flux**: `databases` Kustomization syncs `databases/backups/`, `infrastructure` Kustomization syncs `infrastructure/longhorn-extras/`

## Key Services Stack

- **GitOps**: Flux CD v2 + Gitea (dashboard at `https://flux.ramoneees.com`)
- **Storage**: Longhorn
- **Databases**: PostgreSQL (pgvector), MariaDB, Redis
- **Finance**: Firefly III, Invoice Ninja
- **Automation**: n8n (Execute Command node enabled)
- **GPU**: NVIDIA GPU Operator (Helm)
- **AI**: Ollama (local inference), LiteLLM (proxy), OpenWebUI (chat UI at ai.ramoneees.com)

## Monitoring Stack

- **Prometheus**: Metrics collection, 15-day retention, 20Gi storage — `https://prometheus.ramoneees.com`
- **Grafana**: Dashboards with Prometheus + Loki datasources — `https://grafana.ramoneees.com`
- **Alertmanager**: Alert routing, 2Gi storage — `https://alertmanager.ramoneees.com`
- **Loki**: Log aggregation (SingleBinary mode), 7-day retention, 10Gi storage
- **Promtail**: DaemonSet log collector shipping to Loki
- k3s-incompatible components disabled: kubeEtcd, kubeControllerManager, kubeScheduler, kubeProxy

## Architecture Documentation

Detailed architecture is in `docs/homelab_architecture.html`.
