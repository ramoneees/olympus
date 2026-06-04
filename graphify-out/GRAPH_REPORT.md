# Graph Report - /Users/ramoneees/Documents/sandbox/olympus  (2026-06-04)

## Corpus Check
- Corpus is ~40,975 words - fits in a single context window. You may not need a graph.

## Summary
- 174 nodes · 210 edges · 24 communities (16 shown, 8 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 37 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Alerting & Backup Prompts|Alerting & Backup Prompts]]
- [[_COMMUNITY_Mundados GitOps Management|Mundados GitOps Management]]
- [[_COMMUNITY_AlertManager Routing & N8N|AlertManager Routing & N8N]]
- [[_COMMUNITY_OpenWebUI Tool Framework|OpenWebUI Tool Framework]]
- [[_COMMUNITY_LLM Deployment Stack|LLM Deployment Stack]]
- [[_COMMUNITY_Invoice Ninja Tool|Invoice Ninja Tool]]
- [[_COMMUNITY_OpenClaw HTTP Adapter|OpenClaw HTTP Adapter]]
- [[_COMMUNITY_AI-Git-Bot & Gitea Runner|AI-Git-Bot & Gitea Runner]]
- [[_COMMUNITY_Olympus Core Infrastructure|Olympus Core Infrastructure]]
- [[_COMMUNITY_Agent Services (FinanceAI)|Agent Services (Finance/AI)]]
- [[_COMMUNITY_PDF Processing Pipeline|PDF Processing Pipeline]]
- [[_COMMUNITY_Agent Orchestration|Agent Orchestration]]
- [[_COMMUNITY_Mundados Alerts|Mundados Alerts]]
- [[_COMMUNITY_Monitoring Stack|Monitoring Stack]]
- [[_COMMUNITY_Cert-Manager & Traefik|Cert-Manager & Traefik]]
- [[_COMMUNITY_Network Infrastructure|Network Infrastructure]]
- [[_COMMUNITY_Code Review Prompts|Code Review Prompts]]
- [[_COMMUNITY_LiteLLM Networking|LiteLLM Networking]]
- [[_COMMUNITY_Readme Documentation|Readme Documentation]]
- [[_COMMUNITY_Longhorn Storage|Longhorn Storage]]
- [[_COMMUNITY_Hephaestus Agent|Hephaestus Agent]]
- [[_COMMUNITY_Prometheus Agent|Prometheus Agent]]

## God Nodes (most connected - your core abstractions)
1. `LiteLLM ConfigMap (Model Router)` - 13 edges
2. `mundados Kustomization (app-of-resources)` - 9 edges
3. `Ollama Service` - 9 edges
4. `mundados-postgres StatefulSet (PostGIS + pgvector)` - 8 edges
5. `LiteLLM Deployment` - 7 edges
6. `n8n Deployment` - 7 edges
7. `mundados-minio Deployment (S3/Object Store)` - 7 edges
8. `Mundados Live Fixes (troubleshooting log)` - 7 edges
9. `Tools` - 7 edges
10. `PDF Tool Sidecar (Flask API)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Ollama Model Pull Job` --semantically_similar_to--> `pgvector Reindex Job (nomic→bge-m3)`  [INFERRED] [semantically similar]
  olympus/ollama/model-pull-job.yaml → databases/postgresql/pgvector-reindex-job.yaml
- `Backup Health Digest Prompt` --conceptually_related_to--> `MariaDB HelmRelease`  [INFERRED]
  olympus/openclaude/prompts/backup-digest.md → databases/mariadb/helmrelease.yaml
- `DatabaseBackupMissing Alert` --references--> `PostgreSQL HelmRelease`  [INFERRED]
  olympus/monitoring/alerts.yaml → databases/postgresql/helmrelease.yaml
- `n8n Deployment` --conceptually_related_to--> `Apps Kustomization`  [INFERRED]
  olympus/n8n/deployment.yaml → apps/kustomization.yaml
- `Route: Mundados Alerts` --conceptually_related_to--> `Apps Kustomization`  [INFERRED]
  monitoring/alertmanager-config/alertmanager-config.yaml → apps/kustomization.yaml

## Hyperedges (group relationships)
- **LiteLLM Claude Code Routing Tier System** — litellm_claude_opus_routing, litellm_claude_sonnet_routing, litellm_claude_haiku_routing, litellm_smart_routing, litellm_coding_routing, litellm_agents_routing, litellm_personal_routing [EXTRACTED 1.00]
- **Database HelmRelease Layer (Bitnami Charts)** — postgresql_helmrelease, mariadb_helmrelease, redis_helmrelease [INFERRED 0.95]
- **OpenClaude Automated SRE/Review Prompts Suite** — alert_triage_prompt, backup_health_digest_prompt, quick_code_review_prompt, deep_architecture_review_prompt, manifest_validation_prompt [INFERRED 0.85]

## Communities (24 total, 8 thin omitted)

### Community 0 - "Alerting & Backup Prompts"
Cohesion: 0.12
Nodes (26): Alert Triage System Prompt, Backup Health Digest Prompt, BackupJobStuck Alert, DatabaseBackupMissing Alert, Databases Layer Kustomization, Embedding Migrations Tracking Table, Agents Routing Group, Claude Haiku 4-5 Routing Group (+18 more)

### Community 1 - "Mundados GitOps Management"
Cohesion: 0.19
Nodes (21): mundados-config ConfigMap, mundados-recolha CronJob (Python ETL collector), mundados-minio Deployment (S3/Object Store), mundados-portal Deployment (Next.js), Flux CD replaces failed ArgoCD, GitOps sync via Flux apps kustomization, mundados IngressRoute (Traefik), mundados-create-buckets Job (MinIO bucket provisioning) (+13 more)

### Community 2 - "AlertManager Routing & N8N"
Cohesion: 0.25
Nodes (15): Incident Routing AlertmanagerConfig, Critical Receiver, Mundados Webhook Receiver, Warning Receiver, Route: Critical Severity, Route: Mundados Alerts, n8n Data PVC, n8n Deployment (+7 more)

### Community 3 - "OpenWebUI Tool Framework"
Cohesion: 0.15
Nodes (9): BaseModel, title: n8n Workflow Trigger description: Trigger n8n workflows via webhook. Usef, Trigger an n8n webhook workflow.         :param webhook_path: Webhook path (e.g., Tools, Valves, title: Web Search (Brave) description: Search the web using Brave Search API. Re, Search the web for current information using Brave Search.         :param query:, Tools (+1 more)

### Community 4 - "LLM Deployment Stack"
Cohesion: 0.16
Nodes (14): LiteLLM ConfigMap, LiteLLM Deployment, LiteLLM ServiceMonitor, LitellmDown Alert, n8n Deployment, PDF Toolkit Sidecar, Ollama Deployment, Ollama Model Pull Job (+6 more)

### Community 5 - "Invoice Ninja Tool"
Cohesion: 0.21
Nodes (6): title: Invoice Ninja description: Manage clients, invoices, and payments in Invo, List clients in Invoice Ninja.         :param search: Optional search term to fi, List invoices in Invoice Ninja.         :param status: Filter by status: draft,, Create a new invoice in Invoice Ninja.         :param client_id: The client ID t, Tools, Valves

### Community 6 - "OpenClaw HTTP Adapter"
Cohesion: 0.2
Nodes (11): app, callOpenClaude(), createClient(), crypto, express, getClient(), grpc, path (+3 more)

### Community 7 - "AI-Git-Bot & Gitea Runner"
Cohesion: 0.24
Nodes (10): AI-Git-Bot Deployment, AI-Git-Bot Kubernetes Secret, AI-Git-Bot Service, AI-Git-Bot IngressRoute, Wildcard TLS Certificate, AI-Git-Bot Kustomization, Gitea Runner Kustomization, Gitea npm Package Registry (+2 more)

### Community 8 - "Olympus Core Infrastructure"
Cohesion: 0.25
Nodes (8): Mnemosyne (Memory), ArgoCD, Flux CD, Gitea, k3s Cluster, Mnemosyne Memory (pgvector), PostgreSQL (pgvector), Redis

### Community 9 - "Agent Services (Finance/AI)"
Cohesion: 0.29
Nodes (7): Plutus (Finance), Firefly III, Invoice Ninja, LibreChat, LiteLLM, MariaDB, Ollama

### Community 10 - "PDF Processing Pipeline"
Cohesion: 0.33
Nodes (6): PDF Decrypt Endpoint, PDF Extract Pages Endpoint, PDF Extract Text Endpoint, PDF Metadata Endpoint, PDF Tool Sidecar (Flask API), PDF to Images Endpoint

### Community 11 - "Agent Orchestration"
Cohesion: 0.4
Nodes (5): Hermes (Orchestrator), Mattermost, n8n, OpenClaw, Vikunja

### Community 12 - "Mundados Alerts"
Cohesion: 0.4
Nodes (5): Monitoring Kustomization (olympus), MundadosForjaJobFailed Alert, MundadosPortalDown Alert, MundadosRecolhaJobFailed Alert, MundadosRecolhaMissed Alert

### Community 13 - "Monitoring Stack"
Cohesion: 0.67
Nodes (3): Grafana, Loki, Prometheus

## Knowledge Gaps
- **71 isolated node(s):** `PDF Toolkit API Documentation`, `Ollama Model Pull Job`, `Redis Master`, `PostgreSQL Database`, `OLYMPUS README` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `LiteLLM ConfigMap (Model Router)` connect `Alerting & Backup Prompts` to `LLM Deployment Stack`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Why does `LiteLLM Deployment` connect `LLM Deployment Stack` to `Alerting & Backup Prompts`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `LiteLLM ConfigMap (Model Router)` (e.g. with `PostgreSQL HelmRelease` and `LiteLLM ServiceMonitor`) actually correct?**
  _`LiteLLM ConfigMap (Model Router)` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `mundados-postgres StatefulSet (PostGIS + pgvector)` (e.g. with `mundados-portal Deployment (Next.js)` and `mundados-minio Deployment (S3/Object Store)`) actually correct?**
  _`mundados-postgres StatefulSet (PostGIS + pgvector)` has 5 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PDF Toolkit API Documentation`, `Ollama Model Pull Job`, `Redis Master` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Alerting & Backup Prompts` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._