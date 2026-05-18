# OpenClaude — Gitea Webhook Setup & Testing Guide

## Prerequisites

- OpenClaude pod running (`kubectl get pods -n olympus -l app=openclaude`)
- n8n workflows imported and active
- `openclaude-secret` applied with real credentials

---

## Step 1: Build and Push the Docker Image

```bash
cd olympus/openclaude
docker build -t git.ramoneees.com/olympus/openclaude:latest .
docker push git.ramoneees.com/olympus/openclaude:latest
```

> The Gitea container registry is at `git.ramoneees.com`. You must be logged in:
> `docker login git.ramoneees.com`

---

## Step 2: Apply the Secret

Fill in real values and apply manually (never commit):

```bash
kubectl apply -f olympus/openclaude/secrets.yaml -n olympus
```

Required values in `openclaude-secret`:
- `litellm-master-key` — LiteLLM master key (`sk-...`)
- `gitea-api-token` — Gitea token with `repo` scope
- `brave-api-key` — Brave Search API key (or leave PLACEHOLDER if using `ddg`)

---

## Step 3: Import n8n Workflows

### Option A: n8n UI (Manual Import)

1. Open https://n8n.ramoneees.com
2. **Workflows → Import from File** for each JSON:
   - `olympus/openclaude/n8n-workflow.json` → PR Code Review
   - `olympus/openclaude/n8n-backup-digest-workflow.json` → Backup Health Digest
   - `olympus/openclaude/n8n-validation-workflow.json` → Push Manifest Validation
3. The Prometheus Alert Handler (`olympus/n8n/workflows/prometheus-alerts.json`) replaces the existing workflow — import and **overwrite by ID**.

### Option B: n8n API

```bash
N8N_URL=https://n8n.ramoneees.com
N8N_API_KEY=<your-api-key>

curl -X POST "$N8N_URL/api/v1/workflows" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @olympus/openclaude/n8n-workflow.json
```

---

## Step 4: Configure n8n Credentials

In n8n → Credentials → New:

**Gitea API Token** (type: `HTTP Header Auth`):
- Name: `Gitea API Token`
- Header Name: `Authorization`
- Header Value: `token <your-gitea-token>`

**Hermes Webhook Secret** — already in Notify Hermes sub-workflow.

---

## Step 5: Activate n8n Workflows

In n8n UI, toggle each workflow **Active**:
1. Gitea PR Code Review
2. Daily Backup Health Digest
3. Gitea Push Manifest Validation
4. Prometheus Alert Handler (was previously inactive — now activate)

---

## Step 6: Configure Gitea Webhooks

### Code Review Webhook (per repo)

For each repo you want reviewed:

1. Go to `https://git.ramoneees.com/<owner>/<repo>/settings/hooks`
2. **Add Webhook → Gitea**
3. Settings:
   - **Target URL**: `https://n8n.ramoneees.com/webhook/gitea-pr-review`
   - **HTTP Method**: POST
   - **Content Type**: `application/json`
   - **Trigger On**: Pull Request (check: Created, Synchronized)
4. Click **Add Webhook**, then **Test Delivery**

### Pre-Sync Validation Webhook (olympus infra repo only)

1. Go to `https://git.ramoneees.com/olympus/olympus/settings/hooks`
2. **Add Webhook → Gitea**
3. Settings:
   - **Target URL**: `https://n8n.ramoneees.com/webhook/gitea-push-validate`
   - **HTTP Method**: POST
   - **Content Type**: `application/json`
   - **Trigger On**: Push
4. Click **Add Webhook**

---

## Step 7: End-to-End Testing

### Test 1: PR Code Review

```bash
# Create a test branch and PR
git checkout -b test/openclaude-review
echo "# test" >> README.md
git add README.md && git commit -m "test: OpenClaude review trigger"
git push origin test/openclaude-review
# Open a PR in Gitea UI — within 2 minutes, a comment should appear
```

Expected: Comment on PR starting with `[AI Review - QUICK]`

### Test 2: Deep Review (label trigger)

1. On the test PR, add label `deep-review` in Gitea
2. Push another commit to the branch
3. Expected: Comment starting with `[AI Review - DEEP]`

### Test 3: Manifest Validation

```bash
git checkout main
# Edit any YAML in olympus/
echo "# test" >> olympus/openclaude/service.yaml
git add olympus/openclaude/service.yaml
git commit -m "test: trigger validation"
git push
# Check the commit on Gitea — a comment should appear within 60s
```

### Test 4: Alert Triage

```bash
# Send a test alert to n8n
curl -X POST https://n8n.ramoneees.com/webhook/prometheus-alerts \
  -H "Content-Type: application/json" \
  -d '{"status":"firing","alerts":[{"labels":{"alertname":"TestAlert","severity":"warning","namespace":"olympus"},"annotations":{"summary":"Test alert for OpenClaude triage","description":"This is a test"}}]}'
# Check Mattermost for enriched alert notification
```

### Test 5: Backup Digest (manual trigger)

In n8n → Workflows → Daily Backup Health Digest → **Execute Workflow**
Expected: Digest message delivered to Mattermost via Hermes

---

## Troubleshooting

### OpenClaude pod not ready
```bash
kubectl describe pod -n olympus -l app=openclaude
kubectl logs -n olympus deploy/openclaude -c openclaude
kubectl logs -n olympus deploy/openclaude -c http-adapter
```

### HTTP adapter health check
```bash
kubectl exec -n olympus deploy/openclaude -c http-adapter -- \
  curl -s http://localhost:8080/health
# Expected: {"status":"ok"}
```

### gRPC not listening
```bash
kubectl exec -n olympus deploy/openclaude -c openclaude -- \
  curl -v telnet://localhost:50051 2>&1 | head -5
```

### n8n workflow not triggering
- Check Gitea webhook delivery log: `https://git.ramoneees.com/<repo>/settings/hooks`
- Check n8n execution history for the workflow

### Review comment not appearing
- Check n8n execution log for errors
- Verify `gitea-api-token` credential has `repo` write scope
- Test Gitea API directly:
  ```bash
  curl -H "Authorization: token <token>" \
    https://git.ramoneees.com/api/v1/repos/<owner>/<repo>/issues/1/comments \
    -X POST -H "Content-Type: application/json" \
    -d '{"body":"test comment"}'
  ```

### Image pull errors
```bash
# Verify the image was pushed
curl -s https://git.ramoneees.com/v2/olympus/openclaude/tags/list \
  -H "Authorization: Basic $(echo -n 'user:token' | base64)"
```
