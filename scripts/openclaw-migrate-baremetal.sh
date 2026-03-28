#!/usr/bin/env bash
#
# OpenClaw Baremetal Migration — Tasks 4+5
# Run this on your LOCAL machine (Mac) that has kubectl access to the cluster.
#
# What it does:
#   1. Exports PVC data from K8s to a tarball
#   2. Extracts K8s secrets to a .env file
#   3. SCPs both to the olympus node
#
# Prerequisites:
#   - kubectl access to the k3s cluster
#   - SSH access to olympus (192.168.50.11)
#   - python3 (for base64 decoding secrets)
#
set -euo pipefail

# ─── CONFIG ──────────────────────────────────────────────────────
OLYMPUS_HOST="192.168.50.11"
OLYMPUS_USER="ramoneees"
REMOTE_DIR="/tmp/openclaw-migration"
LOCAL_TMP="/tmp/openclaw-migration"

echo "═══════════════════════════════════════════════════════"
echo " OpenClaw Baremetal Migration — Tasks 4+5 (LOCAL)"
echo " Target:  $OLYMPUS_USER@$OLYMPUS_HOST"
echo "═══════════════════════════════════════════════════════"
echo ""

# Cleanup any previous migration pod
kubectl delete pod openclaw-export -n olympus 2>/dev/null || true

# ─── TASK 4: Export PVC data ─────────────────────────────────────
echo "━━━ TASK 4: Exporting PVC data from K8s ━━━"

# Create temp dir
rm -rf "$LOCAL_TMP"
mkdir -p "$LOCAL_TMP"

# Launch debug pod mounting the PVC
echo "  Creating export pod..."
kubectl run openclaw-export \
  --image=busybox \
  --restart=Never \
  -n olympus \
  --overrides='{
    "spec": {
      "nodeSelector": {"kubernetes.io/hostname": "olympus"},
      "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "openclaw-data"}}],
      "containers": [{"name": "export", "image": "busybox", "command": ["sleep", "3600"], "volumeMounts": [{"mountPath": "/data", "name": "data"}]}]
    }
  }' 2>/dev/null || true

echo "  Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/openclaw-export -n olympus --timeout=120s

echo "  Copying data to local tarball (this may take a minute)..."
kubectl exec openclaw-export -n olympus -- tar czf - -C /data . > "$LOCAL_TMP/openclaw-data.tar.gz"

echo "  Cleaning up export pod..."
kubectl delete pod openclaw-export -n olympus --force

echo "  ✅ PVC data exported ($LOCAL_TMP/openclaw-data.tar.gz)"
echo "     Size: $(du -h "$LOCAL_TMP/openclaw-data.tar.gz" | cut -f1)"
echo ""

# ─── TASK 5: Extract secrets ────────────────────────────────────
echo "━━━ TASK 5: Extracting secrets from K8s ━━━"

kubectl get secret openclaw-secrets -n olympus -o json | \
  python3 -c "
import sys, json, base64
d = json.load(sys.stdin)
for k, v in d['data'].items():
    try:
        print(f'{k}={base64.b64decode(v).decode()}')
    except Exception:
        print(f'{k}={base64.b64decode(v).hex()}')
" > "$LOCAL_TMP/.env"

chmod 600 "$LOCAL_TMP/.env"

KEY_COUNT=$(grep -c '=' "$LOCAL_TMP/.env" || true)
echo "  ✅ .env created with $KEY_COUNT keys (chmod 600)"
echo ""

# ─── COPY BAREMETAL CONFIG FROM LOCAL REPO ──────────────────────
echo "━━━ Copying baremetal config from local repo ━━━"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/../olympus/olympus-openclaw-config"

if [ -d "$CONFIG_SRC" ]; then
  mkdir -p "$LOCAL_TMP/config"
  cp "$CONFIG_SRC/openclaw.json5" "$LOCAL_TMP/openclaw.json5"
  cp -r "$CONFIG_SRC/config/"* "$LOCAL_TMP/config/" 2>/dev/null || true
  mkdir -p "$LOCAL_TMP/workspaces"
  cp -r "$CONFIG_SRC/workspaces/"* "$LOCAL_TMP/workspaces/" 2>/dev/null || true
  echo "  ✅ Config files staged from local repo"
else
  echo "  ⚠️  $CONFIG_SRC not found — remote script will skip config overlay"
fi
echo ""

# ─── TRANSFER TO OLYMPUS NODE ───────────────────────────────────
echo "━━━ Transferring data to olympus node ━━━"

ssh "$OLYMPUS_USER@$OLYMPUS_HOST" "mkdir -p $REMOTE_DIR"

scp "$LOCAL_TMP/openclaw-data.tar.gz" "$OLYMPUS_USER@$OLYMPUS_HOST:$REMOTE_DIR/"
scp "$LOCAL_TMP/.env" "$OLYMPUS_USER@$OLYMPUS_HOST:$REMOTE_DIR/"

if [ -f "$LOCAL_TMP/openclaw.json5" ]; then
  scp "$LOCAL_TMP/openclaw.json5" "$OLYMPUS_USER@$OLYMPUS_HOST:$REMOTE_DIR/"
  scp -r "$LOCAL_TMP/config" "$OLYMPUS_USER@$OLYMPUS_HOST:$REMOTE_DIR/"
  scp -r "$LOCAL_TMP/workspaces" "$OLYMPUS_USER@$OLYMPUS_HOST:$REMOTE_DIR/"
  echo "  ✅ All files + config transferred"
else
  echo "  ✅ Data files transferred (no config overlay)"
fi
echo ""

# ─── COPY REMOTE SCRIPT ─────────────────────────────────────────
scp "$SCRIPT_DIR/openclaw-setup-remote.sh" "$OLYMPUS_USER@$OLYMPUS_HOST:$REMOTE_DIR/setup-remote.sh"
echo "  ✅ Remote setup script copied"
echo ""

# ─── DONE ────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════"
echo " Tasks 4+5 COMPLETE (data exported + transferred)"
echo ""
echo " NEXT: Run on olympus:"
echo ""
echo "   ssh $OLYMPUS_USER@$OLYMPUS_HOST"
echo "   bash $REMOTE_DIR/setup-remote.sh"
echo ""
echo "═══════════════════════════════════════════════════════"
