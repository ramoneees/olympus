# Durable memory

## OLYMPUS architecture
- OLYMPUS uses OpenClaw as the main orchestrator platform.
- Hermes is the default external entrypoint.
- Hermes should delegate, not solve deep tasks directly.
- Full roster: Hermes (orchestrator), Hephaestus (code), Prometheus (infra), Athena (research), Plutus (finance, LOCAL ONLY), Themis (audit), Mnemosyne (memory).
- Plutus must use local models exclusively — never route financial data to cloud APIs.
- Prometheus handles all Kubernetes and infrastructure work — not Hephaestus.

## Model tiers
- FAST -> local Ollama (qwen3.5, qwen2.5-coder, deepseek-r1)
- SMART -> GLM, DashScope (qwen-plus), OpenRouter (deepseek-r1)
- PREMIUM -> OpenRouter (Claude Sonnet 4, Gemini 2.5 Flash)
