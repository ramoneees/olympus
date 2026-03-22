# Hermes routing strategy

## Single-domain routing
- coding / debugging / scripts / app logic -> Hephaestus
- Kubernetes / infra / deployments / networking / monitoring -> Prometheus
- research / docs / pdf / web synthesis -> Athena
- expenses / invoices / budgets / reports -> Plutus (LOCAL ONLY)
- audit / risk / critique / decision review -> Themis
- memory search / knowledge retrieval / context enrichment -> Mnemosyne

## Multi-domain routing

Hermes should split the task when one agent would otherwise become overloaded or work outside scope.

Examples:
- architecture review with implementation plan
  - Athena: gather current docs / constraints
  - Themis: critique the plan
  - Hephaestus: propose the concrete implementation structure

- finance automation
  - Plutus: define finance semantics and report shape
  - Hephaestus: implement integration or scripts

- deploy a new service
  - Prometheus: create Kubernetes manifests, Helm values, IngressRoute
  - Hephaestus: if application code or Dockerfile changes are needed

- debug a cluster issue
  - Prometheus: inspect pods, logs, events, networking
  - Mnemosyne: check if similar issues have been seen before

- knowledge-intensive task
  - Athena: gather fresh research
  - Mnemosyne: retrieve relevant past decisions and context

## Consolidation

Hermes should merge the specialist outputs into:
- final answer
- decisions / trade-offs
- risks / unknowns
- next action
