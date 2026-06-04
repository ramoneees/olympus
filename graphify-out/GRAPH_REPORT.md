# Graph Report - /Users/ramoneees/Documents/sandbox/olympus  (2026-05-16)

## Corpus Check
- 90 files · ~500 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 90 nodes · 106 edges · 19 communities (12 shown, 7 thin omitted)
- Extraction: 81% EXTRACTED · 19% INFERRED · 0% AMBIGUOUS · INFERRED: 20 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Mundados Application Stack|Mundados Application Stack]]
- [[_COMMUNITY_AILLM Infrastructure|AI/LLM Infrastructure]]
- [[_COMMUNITY_GitOps & Data Infrastructure|GitOps & Data Infrastructure]]
- [[_COMMUNITY_Incident Management & Routing|Incident Management & Routing]]
- [[_COMMUNITY_Agent Applications|Agent Applications]]
- [[_COMMUNITY_n8n Workflow Automation|n8n Workflow Automation]]
- [[_COMMUNITY_GPU & Monitoring Stack|GPU & Monitoring Stack]]
- [[_COMMUNITY_Storage & Backups|Storage & Backups]]
- [[_COMMUNITY_Database Provisioning|Database Provisioning]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]

## God Nodes (most connected - your core abstractions)
1. `mundados Kustomization (app-of-resources)` - 9 edges
2. `mundados-postgres StatefulSet (PostGIS + pgvector)` - 8 edges
3. `n8n Deployment` - 7 edges
4. `mundados-minio Deployment (S3/Object Store)` - 7 edges
5. `Mundados Live Fixes (troubleshooting log)` - 7 edges
6. `PDF Tool Sidecar (Flask API)` - 6 edges
7. `mundados-forja Job (Clojure ETL/Forge)` - 6 edges
8. `mundados-recolha CronJob (Python ETL collector)` - 6 edges
9. `n8n Kustomization` - 5 edges
10. `Incident Routing AlertmanagerConfig` - 5 edges

## Surprising Connections (you probably didn't know these)
- `n8n Deployment` --conceptually_related_to--> `Apps Kustomization`  [INFERRED]
  olympus/n8n/deployment.yaml → apps/kustomization.yaml
- `Route: Mundados Alerts` --conceptually_related_to--> `Apps Kustomization`  [INFERRED]
  monitoring/alertmanager-config/alertmanager-config.yaml → apps/kustomization.yaml
- `Route: Critical Severity` --conceptually_related_to--> `Apps Kustomization`  [INFERRED]
  monitoring/alertmanager-config/alertmanager-config.yaml → apps/kustomization.yaml
- `k3s Cluster` --implements--> `Flux CD`  [EXTRACTED]
  README.md → CLAUDE.md
- `Flux CD` --references--> `Gitea`  [EXTRACTED]
  CLAUDE.md → apps/gitea/values.yaml

## Communities (19 total, 7 thin omitted)

### Community 0 - "Mundados Application Stack"
Cohesion: 0.22
Nodes (19): mundados-config ConfigMap, mundados-recolha CronJob (Python ETL collector), mundados-minio Deployment (S3/Object Store), mundados-portal Deployment (Next.js), mundados IngressRoute (Traefik), mundados-create-buckets Job (MinIO bucket provisioning), mundados-forja Job (Clojure ETL/Forge), mundados-seed-rag Job (RAG data seeding) (+11 more)

### Community 1 - "AI/LLM Infrastructure"
Cohesion: 0.22
Nodes (10): LiteLLM ConfigMap, LiteLLM Deployment, n8n Deployment, PDF Toolkit Sidecar, Ollama Deployment, Ollama Model Pull Job, Olympus Workload Alerts, PDF Toolkit API Documentation (+2 more)

### Community 2 - "GitOps & Data Infrastructure"
Cohesion: 0.25
Nodes (8): Mnemosyne (Memory), ArgoCD, Flux CD, Gitea, k3s Cluster, Mnemosyne Memory (pgvector), PostgreSQL (pgvector), Redis

### Community 3 - "Incident Management & Routing"
Cohesion: 0.43
Nodes (8): Incident Routing AlertmanagerConfig, Critical Receiver, Mundados Webhook Receiver, Warning Receiver, Route: Critical Severity, Route: Mundados Alerts, n8n Service (NodePort), Apps Kustomization

### Community 4 - "Agent Applications"
Cohesion: 0.29
Nodes (7): Plutus (Finance), Firefly III, Invoice Ninja, LibreChat, LiteLLM, MariaDB, Ollama

### Community 5 - "n8n Workflow Automation"
Cohesion: 0.57
Nodes (7): n8n Data PVC, n8n Deployment, n8n Kustomization, n8n Pod Reader Role, n8n Pod Reader RoleBinding (apps namespace), n8n Pod Reader RoleBinding (olympus namespace), n8n ServiceAccount

### Community 6 - "GPU & Monitoring Stack"
Cohesion: 0.33
Nodes (6): PDF Decrypt Endpoint, PDF Extract Pages Endpoint, PDF Extract Text Endpoint, PDF Metadata Endpoint, PDF Tool Sidecar (Flask API), PDF to Images Endpoint

### Community 7 - "Storage & Backups"
Cohesion: 0.4
Nodes (5): Hermes (Orchestrator), Mattermost, n8n, OpenClaw, Vikunja

### Community 8 - "Database Provisioning"
Cohesion: 0.4
Nodes (5): Monitoring Kustomization (olympus), MundadosForjaJobFailed Alert, MundadosPortalDown Alert, MundadosRecolhaJobFailed Alert, MundadosRecolhaMissed Alert

### Community 9 - "Community 9"
Cohesion: 0.67
Nodes (3): Grafana, Loki, Prometheus

## Knowledge Gaps
- **40 isolated node(s):** `PDF Toolkit API Documentation`, `Ollama Model Pull Job`, `Redis Master`, `PostgreSQL Database`, `OLYMPUS README` (+35 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `n8n Deployment` connect `n8n Workflow Automation` to `Incident Management & Routing`, `GPU & Monitoring Stack`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `PDF Tool Sidecar (Flask API)` connect `GPU & Monitoring Stack` to `n8n Workflow Automation`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `Mundados Live Fixes (troubleshooting log)` connect `Mundados Application Stack` to `Community 12`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `mundados-postgres StatefulSet (PostGIS + pgvector)` (e.g. with `mundados-portal Deployment (Next.js)` and `mundados-minio Deployment (S3/Object Store)`) actually correct?**
  _`mundados-postgres StatefulSet (PostGIS + pgvector)` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `n8n Deployment` (e.g. with `Apps Kustomization` and `n8n Pod Reader Role`) actually correct?**
  _`n8n Deployment` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `mundados-minio Deployment (S3/Object Store)` (e.g. with `mundados-recolha CronJob (Python ETL collector)` and `mundados-forja Job (Clojure ETL/Forge)`) actually correct?**
  _`mundados-minio Deployment (S3/Object Store)` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PDF Toolkit API Documentation`, `Ollama Model Pull Job`, `Redis Master` to the rest of the system?**
  _40 weakly-connected nodes found - possible documentation gaps or missing edges._