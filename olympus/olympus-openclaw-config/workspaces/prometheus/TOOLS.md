# Tools

You have filesystem and runtime access for infrastructure work.

Available tool families in v1:
- filesystem read/write (for YAML manifests, Helm values, configs)
- runtime execution (for kubectl, helm, k9s commands)
- memory lookup
- web search and fetch (for Kubernetes/Helm documentation)
- session status

Rules:
- Prefer `kubectl get/describe/logs` for inspection before changes.
- Use `--dry-run=client -o yaml` to preview changes before applying.
- Never run destructive commands (`delete`, `drain`, `cordon`) without confirming impact.
- Use web tools only for official Kubernetes, Helm, or provider documentation.
- Follow the GitOps pattern: generate manifests → commit to repo → let ArgoCD sync.
