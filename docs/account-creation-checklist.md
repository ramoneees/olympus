# OLYMPUS Agent Account Creation Checklist

Run `./scripts/create-agent-accounts.sh` first, then work through this list.

## Pre-requisites

- [ ] Connected to LAN or WireGuard VPN
- [ ] Admin tokens filled in `.secrets/agent-credentials.env`
- [ ] All Phase 4 services are running (check via `kubectl get pods -A`)

---

## Automated (script handles these)

### Vikunja (tasks.ramoneees.com)
- [ ] hermes account created
- [ ] hephaestus account created
- [ ] prometheus account created
- [ ] athena account created
- [ ] plutus account created
- [ ] themis account created
- [ ] mnemosyne account created
- [ ] Project: Hermes created
- [ ] Project: Hephaestus created
- [ ] Project: Prometheus created
- [ ] Project: Athena created
- [ ] Project: Plutus created
- [ ] Project: Themis created
- [ ] Project: OLYMPUS-Audit created
- [ ] Labels created: delegated, in-progress, pending-review, approved, rejected, financial, infra, code

### Mattermost (chat.ramoneees.com)
- [ ] Hermes bot account created
- [ ] prometheus account created
- [ ] hephaestus account created
- [ ] athena account created
- [ ] plutus account created
- [ ] themis account created
- [ ] Channel: olympus-general (public) created
- [ ] Channel: olympus-alerts (public) created
- [ ] Channel: olympus-infra (public) created
- [ ] Channel: olympus-code (public) created
- [ ] Channel: olympus-finance (private) created
- [ ] Channel: olympus-log (public) created
- [ ] Agents added to relevant channels

### Gitea (gitea.ramoneees.com)
- [ ] hephaestus account created
- [ ] prometheus account created
- [ ] themis account created
- [ ] hephaestus added to olympus-gitops (write)
- [ ] prometheus added to olympus-gitops (write)
- [ ] themis added to olympus-gitops (read)

### Firefly III (firefly.ramoneees.com)
- [ ] plutus account created
- [ ] themis account created

### Authentik (auth.ramoneees.com)
- [ ] prometheus account created

---

## Manual (UI required — no API available)

### Invoice Ninja (invoice.ramoneees.com)
- [ ] Create plutus account via UI
  - URL: https://invoice.ramoneees.com → Settings → Users → Add User
  - Email: plutus@ramoneees.com
  - Password: see `INVOICENINJA_PLUTUS_PASSWORD` in `.secrets/agent-credentials.env`

### Uptime Kuma (status.ramoneees.com)
- [ ] Create prometheus account via UI
  - URL: https://status.ramoneees.com → Settings → Security
  - Email: prometheus@ramoneees.com
  - Password: see `UPTIMEKUMA_PROMETHEUS_PASSWORD` in `.secrets/agent-credentials.env`

### Homebox (homebox.ramoneees.com)
- [ ] Invite athena via UI
  - URL: https://homebox.ramoneees.com → Profile → Invite User
  - Email: athena@ramoneees.com
  - Password: see `HOMEBOX_ATHENA_PASSWORD` in `.secrets/agent-credentials.env`

### Uptime Kuma monitors
- [ ] Add HTTP monitors for all running services (60s interval):
  - Vikunja, Firefly III, Invoice Ninja, Mattermost, Authentik,
    Vaultwarden, Homebox, Cloudbeaver, AdGuard, Traefik,
    Ollama, LiteLLM, OpenClaw

---

## Token generation (log in as each agent and generate)

### Vikunja
- [ ] Log in as hermes → Settings → API Tokens → Create token named `hermes-vikunja-token`
- [ ] Log in as hephaestus → Settings → API Tokens → Create token named `hephaestus-vikunja-token`
- [ ] Log in as prometheus → Settings → API Tokens → Create token named `prometheus-vikunja-token`
- [ ] Log in as athena → Settings → API Tokens → Create token named `athena-vikunja-token`
- [ ] Log in as plutus → Settings → API Tokens → Create token named `plutus-vikunja-token`
- [ ] Log in as themis → Settings → API Tokens → Create token named `themis-vikunja-token`
- [ ] Log in as mnemosyne → Settings → API Tokens → Create token named `mnemosyne-vikunja-token`

### Mattermost
- [ ] Hermes bot token is generated during script execution — record it

### Gitea
- [ ] Log in as hephaestus → Settings → Applications → Generate token named `hephaestus-gitea-token`
- [ ] Log in as prometheus → Settings → Applications → Generate token named `prometheus-gitea-token`
- [ ] Log in as themis → Settings → Applications → Generate token named `themis-gitea-token`

### Firefly III
- [ ] Log in as plutus → Profile → OAuth → Create Personal Access Token named `plutus-firefly-token`
- [ ] Log in as themis → Profile → OAuth → Create Personal Access Token named `themis-firefly-token` (read scope)

### Invoice Ninja
- [ ] Log in as plutus → Settings → API Tokens → Generate token named `plutus-invoiceninja-token`

### Uptime Kuma
- [ ] Log in as prometheus → Settings → API Keys → Generate key named `prometheus-uptimekuma-key`

### Authentik
- [ ] Log in as prometheus → generate service account token named `prometheus-authentik-token`

### Homebox
- [ ] Log in as athena → Profile → Generate API token named `athena-homebox-token`

---

## After all tokens generated

- [ ] Paste every token into the matching `*_TOKEN=` field in `.secrets/agent-credentials.env`
- [ ] Copy entire `.secrets/` directory contents to Vaultwarden as a secure note
- [ ] Create Kubernetes secrets from templates:
  ```bash
  # Replace PLACEHOLDER values in templates with real tokens, then seal:
  for f in infrastructure/secrets/agent-secrets-template/*.yaml; do
    kubeseal --format yaml \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=infrastructure \
      < "$f" > "${f%.yaml}-sealed.yaml"
  done
  ```
- [ ] Commit only the sealed secrets (never the plain templates with real values)
- [ ] Verify agents can authenticate by testing one API call per service
