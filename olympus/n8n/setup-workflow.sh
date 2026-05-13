#!/bin/bash
# Import prometheus-alerts workflow into n8n via REST API
set -e

N8N_URL="${N8N_URL:-https://n8n.ramoneees.com}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Get n8n API token from secret
N8N_TOKEN="$(kubectl get secret n8n-secret -n olympus -o jsonpath='{.data.n8n-api-token}' 2>/dev/null | base64 -d || echo "")"

if [ -z "$N8N_TOKEN" ]; then
  echo "Error: n8n-api-token not found in n8n-secret"
  echo "Create it with: kubectl patch secret n8n-secret -n olympus -p '{\"stringData\":{\"n8n-api-token\":\"'$(openssl rand -base64 32)'\"}}'"
  exit 1
fi

WORKFLOW_JSON="$(cat "$SCRIPT_DIR/workflows/prometheus-alerts.json")"

echo "Importing prometheus-alerts workflow into n8n at $N8N_URL..."
RESPONSE=$(curl -s -X POST "${N8N_URL}/rest/workflows" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: ${N8N_TOKEN}" \
  -d "${WORKFLOW_JSON}")

if echo "$RESPONSE" | grep -q '"id"'; then
  echo "Success: workflow imported"
else
  echo "Response: $RESPONSE"
  echo "Note: If workflow already exists (409), use PUT to update instead."
fi