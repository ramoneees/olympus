#!/usr/bin/env bash
#
# OpenClaw Baremetal Migration — Task 7 (Remote Setup)
# Run this on the olympus node (192.168.50.11) AFTER the local export script.
#
# What it does:
#   1. Extracts PVC data from tarball to ~/.openclaw/
#   2. Moves .env into place
#   3. Overlays baremetal-adapted config (pre-copied by local script)
#   4. Creates systemd service and starts OpenClaw
#
set -euo pipefail

USER="$(whoami)"
HOME_DIR="$(eval echo ~$USER)"
OPENCLAW_DIR="$HOME_DIR/.openclaw"
MIGRATION_DIR="/tmp/openclaw-migration"

echo "═══════════════════════════════════════════════════════"
echo " OpenClaw Baremetal Migration — Task 7 (REMOTE)"
echo " User:    $USER"
echo " Home:    $HOME_DIR"
echo " Target:  $OPENCLAW_DIR"
echo "═══════════════════════════════════════════════════════"
echo ""

# Verify migration files exist
if [ ! -f "$MIGRATION_DIR/openclaw-data.tar.gz" ]; then
  echo "❌ ERROR: $MIGRATION_DIR/openclaw-data.tar.gz not found"
  echo "   Run the local export script first (openclaw-migrate-baremetal.sh from your Mac)"
  exit 1
fi

if [ ! -f "$MIGRATION_DIR/.env" ]; then
  echo "❌ ERROR: $MIGRATION_DIR/.env not found"
  echo "   Run the local export script first (openclaw-migrate-baremetal.sh from your Mac)"
  exit 1
fi

# ─── Extract PVC data ───────────────────────────────────────────
echo "━━━ Extracting PVC data ━━━"

mkdir -p "$OPENCLAW_DIR"/{config,workspaces,credentials,canvas,cron,data/extensions}

tar xzf "$MIGRATION_DIR/openclaw-data.tar.gz" -C "$OPENCLAW_DIR"

chown -R "$USER:$USER" "$OPENCLAW_DIR"

for f in openclaw.json cron/jobs.json credentials/google-calendar/gcp-oauth.keys.json; do
  if [ -f "$OPENCLAW_DIR/$f" ]; then
    echo "    ✅ $f"
  else
    echo "    ⚠️  $f NOT FOUND (may not exist in PVC)"
  fi
done

if [ -f "$OPENCLAW_DIR/credentials/ticktick/tokens.json" ]; then
  echo "    ✅ credentials/ticktick/tokens.json (OAuth preserved)"
elif [ -d "$OPENCLAW_DIR/credentials/ticktick" ]; then
  echo "    ⚠️  TickTick dir exists but tokens.json missing"
  ls -la "$OPENCLAW_DIR/credentials/ticktick/" 2>/dev/null || true
else
  echo "    ⚠️  No TickTick credentials dir — will need re-auth"
fi

echo ""

# ─── Place .env ─────────────────────────────────────────────────
echo "━━━ Placing .env file ━━━"

cp "$MIGRATION_DIR/.env" "$OPENCLAW_DIR/.env"
chmod 600 "$OPENCLAW_DIR/.env"

KEY_COUNT=$(grep -c '=' "$OPENCLAW_DIR/.env" || true)
echo "  ✅ .env in place with $KEY_COUNT keys (chmod 600)"
echo ""

# ─── Overlay baremetal config ───────────────────────────────────
echo "━━━ Overlaying baremetal-adapted config ━━━"

if [ -f "$MIGRATION_DIR/openclaw.json5" ]; then
  cp "$MIGRATION_DIR/openclaw.json5" "$OPENCLAW_DIR/openclaw.json"
  echo "  ✅ openclaw.json (baremetal config) copied"
else
  echo "  ⚠️  openclaw.json5 not found in migration dir — keeping PVC version"
fi

if [ -d "$MIGRATION_DIR/config" ]; then
  cp -r "$MIGRATION_DIR/config/"* "$OPENCLAW_DIR/config/" 2>/dev/null || true
  echo "  ✅ config/ files updated"
fi

if [ -d "$MIGRATION_DIR/workspaces" ]; then
  cp -r "$MIGRATION_DIR/workspaces/"* "$OPENCLAW_DIR/workspaces/" 2>/dev/null || true
  echo "  ✅ workspaces/ updated"
fi

find "$OPENCLAW_DIR" -name "*.json" -o -name "*.json5" | while read f; do
  if grep -q '/home/node/' "$f" 2>/dev/null; then
    sed -i "s|/home/node/|$HOME_DIR/|g" "$f"
    echo "  Fixed paths in $(basename $f)"
  fi
done

for f in "$OPENCLAW_DIR/openclaw.json" "$OPENCLAW_DIR/config/"*.json5; do
  if [ -f "$f" ] && grep -q 'svc.cluster.local' "$f" 2>/dev/null; then
    sed -i 's|http://litellm\.olympus\.svc\.cluster\.local:4000|http://192.168.50.10:30400|g' "$f"
    sed -i 's|http://n8n\.olympus\.svc\.cluster\.local:5678|http://192.168.50.11:30567|g' "$f"
    sed -i 's|http://ollama\.olympus\.svc\.cluster\.local:11434|http://192.168.50.11:31434|g' "$f"
    echo "  Fixed K8s DNS in $(basename $f)"
  fi
done

chown -R "$USER:$USER" "$OPENCLAW_DIR/credentials"
echo ""

# ─── Create systemd unit ────────────────────────────────────────
echo "━━━ Creating systemd service ━━━"

OPENCLAW_BIN="$(which openclaw 2>/dev/null || echo /usr/local/bin/openclaw)"
NODE_BIN="$(which node 2>/dev/null || echo /usr/bin/node)"

echo "  OpenClaw binary: $OPENCLAW_BIN"
echo "  Node binary:     $NODE_BIN"

sudo tee /etc/systemd/system/openclaw.service > /dev/null <<EOF
[Unit]
Description=OpenClaw Multi-Agent AI Gateway
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$OPENCLAW_DIR
EnvironmentFile=$OPENCLAW_DIR/.env
ExecStart=$OPENCLAW_BIN
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=60

StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
EOF

echo "  ✅ /etc/systemd/system/openclaw.service created"

sudo systemctl daemon-reload
sudo systemctl enable openclaw

echo ""
echo "━━━ Starting OpenClaw... ━━━"
sudo systemctl start openclaw

sleep 5
if systemctl is-active --quiet openclaw; then
  echo "  ✅ OpenClaw is ACTIVE (running)"
else
  echo "  ⚠️  OpenClaw may still be starting. Checking logs..."
  journalctl -u openclaw --since "10 sec ago" --no-pager 2>/dev/null || true
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo " Migration COMPLETE"
echo ""
echo " Useful commands:"
echo "   systemctl status openclaw"
echo "   journalctl -u openclaw -f"
echo "   curl -s http://localhost:18789/__openclaw__/api/health"
echo ""
echo " Next: Tell Sisyphus to continue with Tasks 8+9 (K8s cleanup + docs)"
echo "═══════════════════════════════════════════════════════"
