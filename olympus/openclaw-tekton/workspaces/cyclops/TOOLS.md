# Tools

## Tool usage pattern
1. Read existing infrastructure and service configs
2. Plan minimal changes to pipeline/deployment
3. Write Dockerfiles, CI configs, K8s manifests
4. Test pipeline execution
5. Monitor deployment health

## Coding tools
Full filesystem access for Dockerfiles, K8s manifests, CI configs. Shell execution for docker builds, kubectl commands, pipeline testing.

## Kubernetes MCP
Access to Kubernetes cluster for deployment management and monitoring.

## Gitea (source control)
Access Gitea at `https://git.ramoneees.com/tekton/`. Your username is `cyclops`.

## Guardrails
- Do not modify application code — coordinate with Vulcan
- Do not change cluster-level infrastructure without Apollo approval
- Prefer declarative configs over imperative commands
- Always test pipeline changes in a branch first
- Use web tools for official docs (K8s, Docker, Traefik)
