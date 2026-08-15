# Cloudflare Tunnel Setup

## Prerequisites

1. Go to https://one.dash.cloudflare.com → Networks → Tunnels
2. Create or select a tunnel for each service
3. Copy the tunnel token (format: `eyJhIjoi...`)

## Apply tokens

After replacing the token values in the secrets files (or using the script below):

```bash
# Set your tokens as environment variables
export CLOUDFLARE_TUNNEL_CLOUDBEAVER="eyJhIjoi..."
export CLOUDFLARE_TUNNEL_GRAFANA="eyJhIjoi..."
export CLOUDFLARE_TUNNEL_WESERVE="eyJhIjoi..."

# Apply all 3 tunnel secrets at once
kubectl create secret generic cloudbeaver-tunnel-secret \
  --namespace=apps \
  --from-literal=tunnel-token="$CLOUDFLARE_TUNNEL_CLOUDBEAVER" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic grafana-tunnel-secret \
  --namespace=monitoring \
  --from-literal=tunnel-token="$CLOUDFLARE_TUNNEL_GRAFANA" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic weserve-tunnel-secret \
  --namespace=apps \
  --from-literal=tunnel-token="$CLOUDFLARE_TUNNEL_WESERVE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart tunnel pods to pick up new tokens
kubectl rollout restart deploy cloudbeaver-tunnel -n apps
kubectl rollout restart deploy grafana-tunnel -n monitoring
kubectl rollout restart deploy weserve-tunnel -n apps
```

## Verify

```bash
kubectl logs deploy/cloudbeaver-tunnel -n apps --tail=5
kubectl logs deploy/grafana-tunnel -n monitoring --tail=5
kubectl logs deploy/weserve-tunnel -n apps --tail=5
```

You should see "Registered tunnel connection" in the logs.

## Services exposed

| Service | Tunnel | Internal target |
|---------|--------|----------------|
| Cloudbeaver | cloudbeaver-tunnel | cloudbeaver.apps.svc:8989 |
| Grafana | grafana-tunnel | kube-prometheus-stack-grafana.monitoring.svc:80 |
| Weserve | weserve-tunnel | weserve.apps.svc:80 |

## Cloudflare Tunnel config

Each tunnel needs an ingress rule in the Cloudflare dashboard pointing to the
internal service. The tunnel token embeds the tunnel ID + account credentials.
The ingress routing is configured in the Cloudflare dashboard, not in k8s.
