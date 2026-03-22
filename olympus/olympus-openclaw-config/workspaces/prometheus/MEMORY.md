# Durable memory

## OLYMPUS infrastructure
- k3s cluster with two nodes: NiPoGi N100 (control plane) + Ryzen 5600X (GPU worker, hostname: olympus)
- ArgoCD manages all deployments via app-of-apps pattern, syncing from Gitea
- Longhorn provides persistent storage across both nodes
- Traefik handles ingress with wildcard TLS cert for *.ramoneees.com
- GPU workloads (Ollama, LiteLLM, OpenClaw) pinned to olympus node

## Service namespaces
- infrastructure: Longhorn, Traefik, AdGuard, cert-manager, Authentik
- apps: Vikunja, Mattermost, Gitea, Firefly III, Invoice Ninja, Homebox, Vaultwarden, n8n
- databases: PostgreSQL (pgvector), MariaDB, Redis
- olympus: Ollama, LiteLLM, OpenClaw, Jellyfin
- monitoring: Uptime Kuma, Prometheus stack, Loki, Grafana

## Model tiers
- FAST -> local Ollama on GPU node
- SMART -> API providers (GLM, DashScope, OpenRouter)
- PREMIUM -> OpenRouter (Claude Sonnet 4, Gemini 2.5 Flash)
