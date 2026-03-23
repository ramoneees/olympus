# Tools

You have filesystem and runtime access for infrastructure work.

Available tool families in v1:
- filesystem read/write (for YAML manifests, Helm values, configs)
- runtime execution (for kubectl, helm, k9s commands)
- memory lookup
- web search and fetch (for Kubernetes/Helm documentation)
- session status

## Monitoring Stack Endpoints

The cluster runs a full observability stack in the `monitoring` namespace. Use these for health checks, diagnostics, and alerting queries.

### Prometheus (metrics)
- **In-cluster**: `http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`
- **External**: `https://prometheus.ramoneees.com`
- **Query API**: `GET /api/v1/query?query=<promql>` — instant query
- **Range query**: `GET /api/v1/query_range?query=<promql>&start=<ts>&end=<ts>&step=<duration>`
- **Targets**: `GET /api/v1/targets` — scrape target health
- **Alerts**: `GET /api/v1/alerts` — active firing/pending alerts
- **Retention**: 15 days

Useful PromQL examples:
```
# Node CPU usage
100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Pod restarts
increase(kube_pod_container_status_restarts_total[1h])

# PVC usage (Longhorn)
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100

# GPU utilization (olympus node)
DCGM_FI_DEV_GPU_UTIL
```

### Grafana (dashboards & visualization)
- **In-cluster**: `http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80`
- **External**: `https://grafana.ramoneees.com`
- **API**: `/api/dashboards/db/<slug>`, `/api/search?query=<term>`
- **Datasources**: Prometheus (default), Loki (logs)

### Loki (logs)
- **In-cluster**: `http://loki.monitoring.svc.cluster.local:3100`
- **Query API**: `GET /loki/api/v1/query_range?query=<logql>&start=<ts>&end=<ts>`
- **Labels**: `GET /loki/api/v1/labels`
- **Retention**: 7 days

Useful LogQL examples:
```
# All logs from a namespace
{namespace="olympus"}

# Error logs from a specific pod
{namespace="olympus", pod=~"openclaw.*"} |= "error"

# ArgoCD sync failures
{namespace=~"argocd.*"} |= "sync" |= "fail"

# k3s kubelet logs
{job="systemd-journal", unit="k3s.service"} |= "error"
```

### Alertmanager (alert routing)
- **In-cluster**: `http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093`
- **External**: `https://alertmanager.ramoneees.com`
- **Active alerts**: `GET /api/v2/alerts`
- **Silences**: `GET /api/v2/silences`

## Rules
- Prefer `kubectl get/describe/logs` for inspection before changes.
- Use `--dry-run=client -o yaml` to preview changes before applying.
- Never run destructive commands (`delete`, `drain`, `cordon`) without confirming impact.
- Use web tools only for official Kubernetes, Helm, or provider documentation.
- Follow the GitOps pattern: generate manifests → commit to repo → let ArgoCD sync.
- Use monitoring APIs to diagnose issues before making infrastructure changes.
- Check Prometheus alerts and Loki logs as the first step when investigating problems.
