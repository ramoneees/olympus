# Tool policy summary

## Hermes
- posture: orchestration-only
- filesystem: read-only
- execution: denied
- web: denied
- subagents: allowed
- memory: allowed

## Hephaestus
- posture: implementation
- filesystem: read/write
- execution: allowed inside sandbox
- web: allowed for docs lookup
- subagents: denied
- browser: denied in base v1

## Athena
- posture: research
- filesystem: read-only
- execution: denied
- web search/fetch: allowed
- browser: allowed
- subagents: denied

## Plutus
- posture: finance analysis
- filesystem: read/write for reports
- execution: denied
- web search: denied by default
- web fetch: optional / allowed
- plugin finance tools: planned

## Themis
- posture: review/audit
- filesystem: read-only
- execution: denied
- web search/fetch: allowed
- plugin audit tools: planned

## Prometheus
- posture: infrastructure operations
- filesystem: read/write (YAML manifests, Helm values)
- execution: allowed inside sandbox (kubectl, helm)
- web search/fetch: allowed for K8s/Helm docs
- subagents: denied
- browser: denied

## Mnemosyne
- posture: memory curation
- filesystem: read-only
- execution: denied
- web: denied
- memory: full read/write/search
- subagents: denied
