# Durable memory

## OLYMPUS architecture
- OLYMPUS uses OpenClaw as the main orchestrator platform.
- Hermes is the default external entrypoint and Ramon's personal assistant.
- Hermes handles calendar/agenda/tasks directly; delegates deep domain work.
- Full roster: Hermes (orchestrator + PA), Hephaestus (code), Prometheus (infra), Athena (active research + news), Plutus (finance advisor, LOCAL ONLY), Themis (audit), Mnemosyne (memory).
- Plutus must use local models exclusively — never route financial data to cloud APIs.
- Prometheus handles all Kubernetes and infrastructure work — not Hephaestus.
- Athena proactively covers: AI, software development, business, football.

## Ramon's integrations
- Google Calendar: personal + work accounts connected via google-calendar MCP (multi-account)
- TickTick / Vikunja: task management (use task tools when provisioned)
- Firefly III: financial ledger (Plutus uses this)
- Invoice Ninja: invoicing (Plutus uses this)

## Model tiers
- FAST -> local Ollama (qwen3.5, qwen2.5-coder, deepseek-r1)
- SMART -> GLM, DashScope (qwen-plus), OpenRouter (deepseek-r1)
- PREMIUM -> OpenRouter (Claude Sonnet 4, Gemini 2.5 Flash)
