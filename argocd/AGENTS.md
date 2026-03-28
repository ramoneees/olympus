# ArgoCD GitOps Applications

**Generated:** 2026-03-27
**Scope:** argocd/

## OVERVIEW

ArgoCD Application manifests using App-of-Apps pattern — root aggregates all child apps, automated sync with self-healing enabled.

## STRUCTURE

```
argocd/
├── root.yaml           # App-of-Apps root (path: argocd)
├── namespaces.yaml     # Namespace provisioning (sync wave: -1)
├── apps.yaml           # Gitea + gitea-config
├── apps-phase4.yaml    # Phase 4: vaultwarden, mattermost, vikunja, firefly-iii, etc.
├── infrastructure.yaml # Longhorn, GPU operator, Traefik, secrets
├── databases.yaml      # PostgreSQL, MariaDB, Redis, backups
├── monitoring.yaml     # kube-prometheus-stack, Loki, Promtail
├── olympus.yaml        # GPU workloads: Ollama, LiteLLM, n8n, Open WebUI + OpenClaw ingress routing
└── adguard.yaml        # AdGuard DNS
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add new app | Create Application manifest, add to appropriate *.yaml |
| Change sync policy | Any *.yaml → spec.syncPolicy |
| Add namespace | namespaces.yaml → add Namespace resource |
| Debug sync | kubectl get application -n argocd |
| View app status | argocd.ramoneees.com |

## CONVENTIONS

All Application manifests follow this pattern:
```yaml
spec:
  project: default
  source:
    repoURL: http://gitea-web.apps.svc.cluster.local:3000/ramoneees/olympus.git
    targetRevision: main
    path: <path-to-manifests>  # OR chart + helm for Helm
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Multi-source Apps
Some apps (e.g., Gitea) use multiple sources:
- Helm chart for the application
- Git repo for values.yaml and ingress manifests

### Sync Wave Order
1. **namespaces.yaml** (wave: -1) — creates infrastructure, databases, apps, olympus, monitoring
2. **infrastructure** — storage (Longhorn), networking (Traefik), GPU operator
3. **databases** — PostgreSQL, MariaDB, Redis
4. **apps + olympus** — application workloads + AI stack
5. **monitoring** — observability stack

## ANTI-PATTERNS

- DO NOT use `kubectl apply` directly — all changes via git push to Gitea
- DO NOT skip CreateNamespace=true for apps in new namespaces
- DO NOT disable selfHeal unless debugging — breaks GitOps guarantees

## CHILD APPS BY FILE

| File | Apps |
|------|------|
| apps.yaml | gitea, gitea-config |
| apps-phase4.yaml | vaultwarden, authentik, uptime-kuma, mattermost, vikunja, firefly-iii, invoice-ninja, homebox, cloudbeaver |
| infrastructure.yaml | longhorn, gpu-operator, traefik, sealed-secrets |
| databases.yaml | postgresql, mariadb, redis, db-backups |
| monitoring.yaml | kube-prometheus-stack, loki, promtail, monitoring-ingress |
| olympus.yaml | ollama, litellm, openclaw (ingress routing only), n8n, openwebui |
| adguard.yaml | adguard |

## REPOSITORY SOURCE

All apps reference: `http://gitea-web.apps.svc.cluster.local:3000/ramoneees/olympus.git`
- Cluster-internal Gitea service
- Target revision: main
- ArgoCD auto-syncs on git push
