# Longhorn Engine Consolidation Plan

## Goal

Reclaim CPU reservation headroom on the cluster by consolidating Longhorn volumes onto a single engine image, so the redundant `instance-manager` pods get garbage-collected by Longhorn.

## Why this matters

Each Longhorn engine image in active use requires its own `instance-manager` pod on every node. The cluster currently runs three engine images simultaneously, leaving three IMs per node — each reserving CPU it does not actually consume.

| Node | IMs | CPU reserved per IM | Total reserved | Recoverable |
|---|---|---|---|---|
| olympus | 3 | 1440m | 4320m (36% of 12 cores) | ~2880m |
| homeserver | 3 | 480m | 1440m (36% of 4 cores) | ~960m |

After consolidation, expected node CPU request percentages:
- olympus: 85% → ~61%
- homeserver: 80% → ~56%

## Current state (snapshot 2026-06-03)

```
ei-75a03ec3   v1.11.1   refcount 142   (most volumes)   75d old
ei-c9fa6d45   v1.11.2   refcount 21                     29d old
ei-a4d05f02   v1.12.0   refcount 6                      33h old   ← target
```

Target image: `ei-a4d05f02` (longhorn-engine **v1.12.0**) since it matches the version Longhorn intends to roll out.

## Pre-flight checks

1. Confirm Longhorn manager and engine chart versions match v1.12.0:
   ```bash
   kubectl get helmrelease -n longhorn-system longhorn -o jsonpath='{.spec.chart.spec.version}{"\n"}'
   kubectl -n longhorn-system get cm longhorn-default-setting -o yaml | grep -i default-engine
   ```
2. Verify cluster is healthy (no degraded volumes, no rebuilding replicas):
   ```bash
   kubectl get volumes.longhorn.io -A -o json | jq -r '.items[] | select(.status.state!="attached" and .status.state!="detached") | "\(.metadata.namespace)/\(.metadata.name)\t\(.status.state)\t\(.status.robustness)"'
   kubectl get replicas.longhorn.io -A -o json | jq -r '.items[] | select(.status.currentState!="running" and .status.currentState!="stopped") | "\(.metadata.namespace)/\(.metadata.name)\t\(.status.currentState)"'
   ```
3. Take a verified B2 backup of critical PVCs **before** any engine migration (PostgreSQL, MariaDB, Redis, Gitea, OpenWebUI, n8n). Confirm Layer 3 sync ran successfully last night.

## Migration strategy

Longhorn offers two paths for moving a volume to a new engine image:

### Path A — Live upgrade (preferred for attached volumes)
1. In the Longhorn UI (or via the `volumes.longhorn.io` CRD) set `spec.engineImage` to `longhornio/longhorn-engine:v1.12.0` on each volume.
2. Longhorn upgrades the engine in-place during the next replica rebuild cycle.
3. No downtime for the workload.

### Path B — Detach + reattach (required for any volume Longhorn refuses to live-upgrade)
1. Scale the consuming workload Deployment/StatefulSet to 0.
2. Wait for the PVC's volume to detach.
3. Edit `spec.engineImage` on the volume CR.
4. Scale the workload back up.

Plan to use Path A first; fall back to Path B only when Longhorn reports `Invalid` or `Incompatible` for a given volume.

## Execution order

Migrate from lowest-risk to highest-risk so that any unexpected breakage is caught early on volumes that are safe to lose temporarily:

1. **Stateless / cache-only volumes first** (Valkey replicas, restore-verify scratch volumes).
2. **Application data volumes** (Gitea, n8n, Invoice Ninja, Ghost, Paperclip, Home Assistant, Obsidian CouchDB, Mundados, OpenWebUI).
3. **Backup PVCs** (`db-backups`, `pg-backups`) — these matter, but lossy migration is recoverable from B2.
4. **Shared databases last** — Redis → MariaDB → PostgreSQL (most disruptive if it goes wrong). For each: take a fresh Layer 1 dump before migration.

After each tier, confirm: cluster healthy, no degraded volumes, applications responding.

## Garbage collection

Once an engine image's `refCount` drops to 0, Longhorn automatically deletes the `instance-manager` pod tied to it within a few minutes. To confirm progress between batches:

```bash
kubectl get engineimages.longhorn.io -n longhorn-system
kubectl get instancemanagers.longhorn.io -n longhorn-system
```

If a stale `instance-manager` lingers after `refCount: 0`, restart the longhorn-manager DaemonSet:

```bash
kubectl rollout restart -n longhorn-system daemonset/longhorn-manager
```

## Verification

After all volumes are on v1.12.0:

```bash
# Should show ONE engine image (the new one)
kubectl get engineimages.longhorn.io -n longhorn-system

# Should show 1 IM per node
kubectl get instancemanagers.longhorn.io -n longhorn-system

# Recompute node CPU request percentages
kubectl describe node olympus    | grep -A 8 "Allocated resources"
kubectl describe node homeserver | grep -A 8 "Allocated resources"
```

Acceptance criteria:
- One engine image present (v1.12.0).
- Exactly two `instance-manager` pods cluster-wide (one per node).
- All Longhorn volumes report `state: attached` (or `detached` for volumes whose workload is offline) and `robustness: healthy`.
- olympus CPU requests under 65%; homeserver under 60%.

## Rollback

If a workload misbehaves after migration:

1. Scale the workload to 0 to detach its volume.
2. Edit the volume CR and reset `spec.engineImage` to the previous image reference (the old engine image CR still exists while `refCount > 0`).
3. Scale the workload back up.

If the v1.11.x engine images have already been GC'd, restore the workload from the Layer 2 Longhorn backup in B2 instead.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Live upgrade stalls on a heavily-used volume | Move it to Path B during a quiet window. |
| Database corruption during migration | Take fresh Layer 1 dump immediately before touching DB volumes. |
| Backup PVC migration fails mid-sync | Layer 3 sync to B2 ran earlier the same day. |
| v1.12.0 has an unknown incompatibility | Pin one non-critical volume first; observe for 24h before bulk migration. |

## Follow-ups (out of scope here)

- After consolidation, evaluate lowering Longhorn's `guaranteedInstanceManagerCPU` setting; the default of 12% per node is what produces the 1440m / 480m reservations and may be larger than this cluster actually needs.
- Fix the openclaude container so it can be scaled back up: resolve the `:8080` port conflict between the `openclaude` container and the `http-adapter` sidecar, and update `QUICK_MODEL` to a name LiteLLM actually serves.
