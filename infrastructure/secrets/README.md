# OLYMPUS Agent Secrets — Kubernetes Secret Management

> ⚠️ **NEVER commit actual token values to git**
> ⚠️ **Use Sealed Secrets or External Secrets Operator for GitOps**
> ⚠️ **Plutus secrets must be pinned to olympus node only**

## Secret Naming Convention

```
{service}-agent-secrets
```

All agent tokens for a given service are grouped into a single Kubernetes Secret.

## Namespace Placement Rules

| Namespace | Secrets | Rationale |
|-----------|---------|-----------|
| `apps` | vikunja, mattermost, firefly, invoiceninja, homebox, gitea, n8n | Application-layer services |
| `infrastructure` | authentik | SSO/auth infrastructure |
| `monitoring` | uptimekuma | Monitoring stack |
| `databases` | pgvector, redis | Database credentials for Mnemosyne |
| `olympus` | Per-agent runtime secrets (combined) | Agent deployment namespace |

## Creating Secrets — kubectl Commands

### apps namespace

```bash
# Vikunja — all agent tokens
kubectl create secret generic vikunja-agent-secrets \
  --namespace apps \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_HERMES_TOKEN=<TOKEN_VALUE> \
  --from-literal=VIKUNJA_HEPHAESTUS_TOKEN=<TOKEN_VALUE> \
  --from-literal=VIKUNJA_PROMETHEUS_TOKEN=<TOKEN_VALUE> \
  --from-literal=VIKUNJA_ATHENA_TOKEN=<TOKEN_VALUE> \
  --from-literal=VIKUNJA_PLUTUS_TOKEN=<TOKEN_VALUE> \
  --from-literal=VIKUNJA_THEMIS_TOKEN=<TOKEN_VALUE> \
  --from-literal=VIKUNJA_MNEMOSYNE_TOKEN=<TOKEN_VALUE>

# Mattermost — Hermes bot
kubectl create secret generic mattermost-agent-secrets \
  --namespace apps \
  --from-literal=MATTERMOST_URL=https://chat.ramoneees.com \
  --from-literal=MATTERMOST_BOT_TOKEN=<TOKEN_VALUE> \
  --from-literal=MATTERMOST_CHANNEL_GENERAL=<CHANNEL_ID> \
  --from-literal=MATTERMOST_CHANNEL_ALERTS=<CHANNEL_ID> \
  --from-literal=MATTERMOST_CHANNEL_FINANCE=<CHANNEL_ID> \
  --from-literal=MATTERMOST_CHANNEL_INFRA=<CHANNEL_ID> \
  --from-literal=MATTERMOST_CHANNEL_CODE=<CHANNEL_ID> \
  --from-literal=MATTERMOST_WEBHOOK_GENERAL=<WEBHOOK_URL> \
  --from-literal=MATTERMOST_WEBHOOK_ALERTS=<WEBHOOK_URL>

# Firefly III — Plutus (rw) + Themis (ro)
kubectl create secret generic firefly-agent-secrets \
  --namespace apps \
  --from-literal=FIREFLY_API_URL=https://firefly.ramoneees.com/api/v1 \
  --from-literal=FIREFLY_PLUTUS_TOKEN=<TOKEN_VALUE> \
  --from-literal=FIREFLY_THEMIS_TOKEN=<TOKEN_VALUE>

# Invoice Ninja — Plutus
kubectl create secret generic invoiceninja-agent-secrets \
  --namespace apps \
  --from-literal=INVOICE_NINJA_URL=https://invoice.ramoneees.com/api/v1 \
  --from-literal=INVOICE_NINJA_API_TOKEN=<TOKEN_VALUE> \
  --from-literal=INVOICE_NINJA_COMPANY_TOKEN=<TOKEN_VALUE>

# Gitea — Hephaestus (rw) + Prometheus (rw iac) + Themis (ro)
kubectl create secret generic gitea-agent-secrets \
  --namespace apps \
  --from-literal=GITEA_URL=https://git.ramoneees.com \
  --from-literal=GITEA_HEPHAESTUS_TOKEN=<TOKEN_VALUE> \
  --from-literal=GITEA_PROMETHEUS_TOKEN=<TOKEN_VALUE> \
  --from-literal=GITEA_THEMIS_TOKEN=<TOKEN_VALUE>

# Homebox — Athena (ro)
kubectl create secret generic homebox-agent-secrets \
  --namespace apps \
  --from-literal=HOMEBOX_URL=https://homebox.ramoneees.com/api/v1 \
  --from-literal=HOMEBOX_ATHENA_TOKEN=<TOKEN_VALUE>

# n8n — webhook URLs for Hermes
kubectl create secret generic n8n-agent-secrets \
  --namespace apps \
  --from-literal=N8N_WEBHOOK_BASE_URL=http://n8n.apps.svc.cluster.local:5678/webhook \
  --from-literal=N8N_FIREFLY_WEBHOOK=<WEBHOOK_PATH> \
  --from-literal=N8N_INVOICE_WEBHOOK=<WEBHOOK_PATH>
```

### infrastructure namespace

```bash
# Authentik — Prometheus (ro)
kubectl create secret generic authentik-agent-secrets \
  --namespace infrastructure \
  --from-literal=AUTHENTIK_URL=https://auth.ramoneees.com \
  --from-literal=AUTHENTIK_PROMETHEUS_TOKEN=<TOKEN_VALUE>
```

### monitoring namespace

```bash
# Uptime Kuma — Prometheus (ro)
kubectl create secret generic uptimekuma-agent-secrets \
  --namespace monitoring \
  --from-literal=UPTIME_KUMA_URL=https://status.ramoneees.com \
  --from-literal=UPTIME_KUMA_API_KEY=<TOKEN_VALUE>
```

### databases namespace

```bash
# PostgreSQL pgvector — Mnemosyne (rw)
kubectl create secret generic pgvector-agent-secrets \
  --namespace databases \
  --from-literal=PGVECTOR_HOST=postgresql.databases.svc.cluster.local \
  --from-literal=PGVECTOR_PORT=5432 \
  --from-literal=PGVECTOR_DATABASE=olympus_memory \
  --from-literal=PGVECTOR_USER=mnemosyne \
  --from-literal=PGVECTOR_PASSWORD=<TOKEN_VALUE>

# Redis — Mnemosyne (rw)
kubectl create secret generic redis-agent-secrets \
  --namespace databases \
  --from-literal=REDIS_HOST=redis.databases.svc.cluster.local \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=REDIS_PASSWORD=<TOKEN_VALUE>
```

### olympus namespace — per-agent runtime secrets

```bash
# Hermes runtime (combined)
kubectl create secret generic hermes-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=MATTERMOST_URL=https://chat.ramoneees.com \
  --from-literal=MATTERMOST_BOT_TOKEN=<TOKEN_VALUE> \
  --from-literal=N8N_WEBHOOK_BASE_URL=http://n8n.apps.svc.cluster.local:5678/webhook

# Hephaestus runtime
kubectl create secret generic hephaestus-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=GITEA_URL=https://git.ramoneees.com \
  --from-literal=GITEA_TOKEN=<TOKEN_VALUE>

# Prometheus runtime
kubectl create secret generic prometheus-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=GITEA_URL=https://git.ramoneees.com \
  --from-literal=GITEA_TOKEN=<TOKEN_VALUE> \
  --from-literal=UPTIME_KUMA_URL=https://status.ramoneees.com \
  --from-literal=UPTIME_KUMA_API_KEY=<TOKEN_VALUE> \
  --from-literal=AUTHENTIK_URL=https://auth.ramoneees.com \
  --from-literal=AUTHENTIK_TOKEN=<TOKEN_VALUE>

# Athena runtime
kubectl create secret generic athena-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=HOMEBOX_URL=https://homebox.ramoneees.com/api/v1 \
  --from-literal=HOMEBOX_TOKEN=<TOKEN_VALUE>

# Plutus runtime — LOCAL NODE ONLY
kubectl create secret generic plutus-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=FIREFLY_API_URL=https://firefly.ramoneees.com/api/v1 \
  --from-literal=FIREFLY_TOKEN=<TOKEN_VALUE> \
  --from-literal=INVOICE_NINJA_URL=https://invoice.ramoneees.com/api/v1 \
  --from-literal=INVOICE_NINJA_API_TOKEN=<TOKEN_VALUE> \
  --from-literal=INVOICE_NINJA_COMPANY_TOKEN=<TOKEN_VALUE>

# Themis runtime
kubectl create secret generic themis-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=GITEA_URL=https://git.ramoneees.com \
  --from-literal=GITEA_TOKEN=<TOKEN_VALUE> \
  --from-literal=FIREFLY_API_URL=https://firefly.ramoneees.com/api/v1 \
  --from-literal=FIREFLY_TOKEN=<TOKEN_VALUE>

# Mnemosyne runtime
kubectl create secret generic mnemosyne-runtime-secrets \
  --namespace olympus \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_TOKEN=<TOKEN_VALUE> \
  --from-literal=PGVECTOR_HOST=postgresql.databases.svc.cluster.local \
  --from-literal=PGVECTOR_PORT=5432 \
  --from-literal=PGVECTOR_DATABASE=olympus_memory \
  --from-literal=PGVECTOR_USER=mnemosyne \
  --from-literal=PGVECTOR_PASSWORD=<TOKEN_VALUE> \
  --from-literal=REDIS_HOST=redis.databases.svc.cluster.local \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=REDIS_PASSWORD=<TOKEN_VALUE>
```

## Referencing Secrets in Deployments

```yaml
# In agent Deployment spec:
spec:
  containers:
  - name: agent
    envFrom:
    - secretRef:
        name: hermes-runtime-secrets  # or whichever agent
```

## Labels

All secrets follow the standard label structure:

```yaml
labels:
  app.kubernetes.io/part-of: olympus
  app.kubernetes.io/component: agent-secrets
```
