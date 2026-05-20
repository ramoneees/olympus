# Mundados Live Fixes - 2026-05-15

## Issues Found

### 1. CRITICAL: PostgreSQL Password Mismatch

**Symptom**: Portal returns 503 on `/api/v1/health`, restarts every ~90s.

**Root cause**: The `mundados-secrets` secret contains password `gErsWtjRq5B/LpJw38B7t6yd4xvkHOZS` for user `mundata`, but the postgres instance rejects all connections:

```
FATAL:  password authentication failed for user "mundata"
DETAIL:  Connection matched file "/var/lib/postgresql/data/pgdata/pg_hba.conf" line 128: "host all all all scram-sha-256"
```

The secret value (`database-url`) decodes to:
```
postgresql://mundata:gErsWtjRq5B/LpJw38B7t6yd4xvkHOZS@postgres-svc.apps.svc.cluster.local:5432/mundata
```

**Note**: The password contains `/` which may have been URL-decoded incorrectly, or the postgres pod was initialized with a different password (e.g., from the old postgres image before registry change). The postgres pod was recreated with the new image but likely retains the old pgdata PVC which has the old password hash.

**Fix**: Reset the postgres password to match the secret:
```bash
kubectl exec mundados-postgres-0 -n apps -- psql -U mundata -d mundata -c "ALTER USER mundata WITH PASSWORD 'gErsWtjRq5B/LpJw38B7t6yd4xvkHOZS';"
```
Or better: update the secret to match the actual postgres password.

**Additional issue**: DB only has PostGIS/Tiger system tables — no application schema. Migrations `V001__initial_schema.sql` and `V002__add_stg_ine.sql` have not been run:
```bash
ls db/migrations/
  V001__initial_schema.sql   # Creates dwh, meta, stg_* schemas and dims
  V002__add_stg_ine.sql      # Adds staging tables
```

### 2. mundados-forja CronJob Missed or Job Failed

**Symptom**: Forja hasn't run in expected time, or spawned Job hit backoff limit.

**Root cause**: Unknown — pod logs not available (cleaned up). Likely fails due to:
- Missing/invalid DB connection (same password issue as portal)
- Missing S3 buckets (minio may not be ready when job runs)
- Missing litellm API key or endpoint

**Schedule**: Forja runs as CronJob at `0 3 * * *` (3am UTC), 1h after recolha (2am).

**Fix**: After fixing the password issue, force a manual run:
```bash
kubectl create job mundados-forja-manual --from=cronjob/mundados-forja -n apps
```

### 3. mundados-recolha CronJob Not Yet Run

**Status**: CronJob exists, schedule `0 2 * * *`, no runs yet.
- Image: `git.ramoneees.com/ramoneees/mundados-recolha:latest` (correct)
- Next run: 02:00 UTC

**Risk**: Will likely fail with same DB password issue as portal.

## Current State (2026-05-15 ~16:30 UTC)

| Component | Status | Notes |
|-----------|--------|-------|
| mundados-postgres-0 | Running (1/1) | DB up but rejecting auth for `mundata` |
| mundados-minio | Running (1/1) | Healthy, S3 on port 9000 |
| mundados-portal | CrashLoopBackOff | 503 on health — DB auth failure |
| mundados-forja | Failed | Backoff limit exceeded, pod cleaned up |
| mundados-recolha | Pending | CronJob, next at 02:00 |
| mundados-create-buckets | Complete | Buckets created |

## Images

All images built for `linux/amd64` and pushed to `git.ramoneees.com/ramoneees/`:

| Image | Tag | Notes |
|-------|-----|-------|
| `mundados-postgres` | latest | Based on postgis/postgis:16-3.4 + pgvector |
| `mundados-portal` | latest | Next.js 16.2.3 — Dockerfile fixed: pnpm approve-builds via `--ignore-scripts` + rebuild |
| `mundados-recolha` | latest | Python ETL (uv, psycopg2, s3fs) |
| `mundados-forja` | latest | Clojure (eclipse-temurin:17-jdk-alpine) |

### Portal Dockerfile Fixes Applied

1. **pnpm approve-builds**: Added `--ignore-scripts` to install, then `pnpm rebuild esbuild sharp unrs-resolver` (pnpm 11 requires explicit build approval)
2. **tsconfig exclude**: Added `tests` to `exclude` array — Next.js was type-checking vitest test setup files and failing

## Portal Dockerfile (current state)

```dockerfile
FROM node:22-alpine AS base
WORKDIR /app

FROM base AS deps
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile --ignore-scripts \
    && pnpm rebuild esbuild sharp unrs-resolver

FROM base AS builder
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
COPY --from=/app/node_modules ./node_modules ./node_modules
COPY . .
COPY --from=deps /app/package.json ./package.json
COPY --from=deps /app/pnpm-lock.yaml* ./pnpm-lock.yaml*
RUN pnpm run build

FROM base AS runner
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV NODE_ENV=production
WORKDIR /app
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["node", "server.js"]
```

## ArgoCD vs Flux

- **ArgoCD**: Dead. `argocd` namespace stuck in `Terminating` since 2026-04-09.
- **Flux CD**: Active. GitRepository `olympus` → Kustomizations: apps, databases, infrastructure, monitoring, namespaces, olympus.
- All mundados changes synced via Flux `apps` kustomization.

## Registry Change

All manifests updated: `registry.ramoneees.com` → `git.ramoneees.com/ramoneees/`

Files modified:
- `apps/mundados/deployment-portal.yaml`
- `apps/mundados/cronjob-recolha.yaml`
- `apps/mundados/job-seed-rag.yaml`
- `apps/mundados/job-forja.yaml`
- `apps/mundados/statefulset-postgres.yaml`
