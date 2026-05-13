# Prometheus Alerting — Medium & Future Improvements

Generated: 2026-05-13
Status: Implemented core alerting; these items are tracked here for future work.

## Context

The olympus cluster now has PrometheusRules covering core pod/deployment failures.
See `olympus/monitoring/alerts.yaml` for what's currently deployed.

---

## Medium Priority (needs investigation before implementing)

### 1. LitellmHighErrorRate

**What**: Alert when litellm error rate exceeds 5% over 5 minutes.
**Why it matters**: API failures, upstream provider issues, Redis/DB connectivity problems.
**Blocker**: The exact Prometheus metric name for litellm request failures is unconfirmed.
Litellm's `/metrics` endpoint is scraped via ServiceMonitor, but the counter name
(`litellm_requests_failed_total`, `litellm_failed_requests_total`, etc.) needs verification.

**Verification steps**:
```bash
# Port-forward litellm metrics
kubectl port-forward -n olympus svc/litellm 4000

# Scrape and look for failure-related metrics
curl -s http://localhost:4000/metrics | grep -i fail
```

Once confirmed, add to `olympus/monitoring/alerts.yaml`:
```promql
- alert: LitellmHighErrorRate
  expr: |
    rate(litellm_requests_failed_total[5m]) / rate(litellm_requests_total[5m]) > 0.05
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "litellm error rate above 5%"
```

### 2. n8n ServiceMonitor (workflow-level alerting)

**What**: Scrape n8n's `/metrics` endpoint to enable error-rate and workflow-stuck alerts.
**Why it matters**: Currently n8n only alerts on pod-level down. Workflow failures/stalls go undetected.
**Blocker**: n8n exposes Prometheus metrics but it requires `N8N_METRICS=true` env var.
Not all n8n editions include this. Community Edition may not have it.

**Verification steps**:
1. Check n8n docs for your edition — does it support `/metrics`?
2. If yes, add to `olympus/n8n/deployment.yaml`:
   ```yaml
   - name: N8N_METRICS
     value: "true"
   ```
3. Add to existing ServiceMonitor at `olympus/litellm/servicemonitor.yaml` (create one for n8n on port 5678).

Then enable alerts like:
- `N8nWorkflowFailure` — if n8n exposes `n8n_workflow_failed_total` counter
- `N8nWorkflowStuck` — if there's an "old execution running" metric

---

## Future Improvements (requires significant setup)

### 1. Ollama ServiceMonitor / PodMonitor

**What**: Add a PodMonitor to scrape ollama and get an `up{job="olympus/ollama"}` metric.
**Why**: Currently ollama has no `/metrics` endpoint and no ServiceMonitor.
Without it, `OllamaDown` can only be detected via `kube_pod_status_phase`.
**Effort**: Ollama doesn't expose Prometheus metrics natively. Would need:
- A sidecar prometheus-agent or use `n8n/node-exporter` as a workaround
- Or instrument ollama with a `/metrics` proxy sidecar

### 2. LibreChat ServiceMonitor

**What**: Add metrics scraping for LibreChat to alert on API error rates.
**Why**: Currently LibreChat can only be monitored via pod uptime.
**Effort**: LibreChat doesn't expose Prometheus metrics. Would need instrumentation.

### 3. MongoDB ServiceMonitor (olympus namespace)

**What**: Add ServiceMonitor for the mongodb StatefulSet in olympus.
**Why**: MongoDB is a dependency of LibreChat but has no observability.
**Effort**: MongoDB has an exporter (`mongodb_exporter`) but requires a sidecar or operator.

### 4. Mariadb Metrics

**What**: Enable the Bitnami metrics sidecar for mariadb (disabled by default).
**Why**: mariadb currently has no Prometheus metrics at all.
**Effort**: Add `--metrics` flag to the mariadb Helm values in `databases/mariadb/values.yaml`.
Then add a ServiceMonitor.

### 5. GPU Monitoring for Ollama

**What**: Alert if GPU becomes unavailable to ollama.
**Why**: Ollama is the only GPU workload. GPU driver crashes or device loss would be silent.
**Effort**: Requires `nvidia-dcgm` exporter or `gpu-operator` with prometheus metrics.
Current cluster uses `gpu-operator` but DCGM metrics may not be scraped.

### 6. TLS Certificate Expiration Alerts

**What**: Alert before ingress TLS certs expire (cert-manager certificates).
**Why**: Wildcard cert from Let's Encrypt expires in ~90 days. Renewal failures go unnoticed.
**Effort**: Requires `cert-manager` `Certificate` resources to be scraped,
or a dedicated certificate-expiry exporter (e.g., `cert-manager-approver`).

### 7. CronJob Stuck Alerts

**What**: Alert when backup CronJobs run longer than expected (e.g., pg-backup active >60m).
**Why**: A stuck backup job silently fails to complete and the next run overlaps.
**Effort**: Requires `kube_job_status_active` comparison against an `activeDeadlineSeconds`
or a threshold on job duration. More complex PromQL.

### 8. LitellmHighLatency

**What**: Alert on P95 request latency from litellm.
**Why**: Slow responses indicate upstream API throttling, Redis latency, or model overload.
**Effort**: Requires verifying `litellm_request_duration_seconds` histogram exists and
configuring appropriate buckets for your latency SLO.

### 9. LitellmRedisConnectionFailure

**What**: Alert when litellm can't reach Redis (used for caching + rate limiting).
**Why**: Redis failures degrade litellm to direct upstream calls, increasing latency/cost.
**Effort**: Depends on litellm exposing a Redis connection error metric.
Verify via `curl -s http://localhost:4000/metrics | grep -i redis`.

### 10. Database Connection Pool Exhaustion

**What**: Alert when litellm's PostgreSQL connection pool is near limit (pool max=10).
**Why**: Pool exhaustion means spend tracking queries fail and new requests are rejected.
**Effort**: Requires `pg_stat_activity` metric scraping from the litellm database,
or litellm-specific connection pool metrics (if exposed).