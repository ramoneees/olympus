#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# OLYMPUS Agent Account Creation Script
# Creates agent accounts across all Phase 4 services via REST APIs
# Usage: ./scripts/create-agent-accounts.sh [--dry-run]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CREDENTIALS_FILE="$REPO_ROOT/.secrets/agent-credentials.env"
DRY_RUN=false
ERRORS=0

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Parse args ──────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run  Print what would be created without making API calls"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────
log_ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
log_fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
log_skip() { echo -e "  ${YELLOW}⊘${NC} $1"; }
log_info() { echo -e "  ${CYAN}→${NC} $1"; }
log_manual() { echo -e "  ${YELLOW}⚠${NC} $1"; }
section()  { echo -e "\n${BOLD}── $1 ──${NC}"; }
mask()     { echo "****"; }

# ── Load credentials ────────────────────────────────────────
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
  echo -e "${RED}ERROR: $CREDENTIALS_FILE not found${NC}"
  echo "Create it first — see .secrets/README.md"
  exit 1
fi

# shellcheck disable=SC1090
source "$CREDENTIALS_FILE"

# ── Validate admin tokens ──────────────────────────────────
validate_admin_tokens() {
  local missing=0
  for var in VIKUNJA_ADMIN_TOKEN MATTERMOST_ADMIN_TOKEN GITEA_ADMIN_USER GITEA_ADMIN_PASSWORD FIREFLY_ADMIN_TOKEN AUTHENTIK_ADMIN_TOKEN; do
    val="${!var:-}"
    if [[ -z "$val" || "$val" == "FILL_BEFORE_RUNNING" ]]; then
      echo -e "${RED}ERROR: $var is not set in $CREDENTIALS_FILE${NC}"
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    echo -e "${RED}Fill in all admin tokens before running this script.${NC}"
    exit 1
  fi
}

# ── Service health checks ──────────────────────────────────
check_service() {
  local name="$1" url="$2"
  if $DRY_RUN; then
    log_info "[dry-run] Would check $name at $url"
    return 0
  fi
  if curl -sf --max-time 5 -o /dev/null "$url"; then
    log_ok "$name is reachable"
    return 0
  else
    log_fail "$name is NOT reachable at $url"
    return 1
  fi
}

# ── Base64 for Gitea basic auth ─────────────────────────────
gitea_basic_auth() {
  echo -n "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" | base64
}

# ════════════════════════════════════════════════════════════
# VIKUNJA
# ════════════════════════════════════════════════════════════
VIKUNJA_URL="https://tasks.ramoneees.com"
VIKUNJA_API="$VIKUNJA_URL/api/v1"
VIKUNJA_POD=""

vikunja_get_pod() {
  if [[ -z "$VIKUNJA_POD" ]]; then
    VIKUNJA_POD=$(kubectl get pods -n apps -l app=vikunja -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  echo "$VIKUNJA_POD"
}

vikunja_user_exists() {
  local username="$1"
  local pod
  pod=$(vikunja_get_pod)
  kubectl exec -n apps "$pod" -c vikunja -- /app/vikunja/vikunja user list 2>/dev/null | grep -q "$username" || return 1
}

create_vikunja_user() {
  local username="$1" email="$2" password="$3"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Vikunja user: $username ($email) password=$(mask)"
    return 0
  fi

  if vikunja_user_exists "$username"; then
    log_skip "Vikunja user '$username' already exists"
    return 0
  fi

  local pod output
  pod=$(vikunja_get_pod)
  output=$(kubectl exec -n apps "$pod" -c vikunja -- \
    /app/vikunja/vikunja user create \
    --username "$username" \
    --email "$email" \
    --password "$password" 2>&1 || true)

  if echo "$output" | grep -qi "created\|success"; then
    log_ok "Vikunja user '$username' created (password=$(mask))"
  elif echo "$output" | grep -qi "exists\|already"; then
    log_skip "Vikunja user '$username' already exists"
  else
    log_fail "Vikunja user '$username' — $output"
  fi
}

create_vikunja_project() {
  local title="$1"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Vikunja project: $title"
    return 0
  fi

  # Check if project exists
  local projects
  projects=$(curl -sf -H "Authorization: Bearer $VIKUNJA_ADMIN_TOKEN" \
    "$VIKUNJA_API/projects" 2>/dev/null || echo "[]")

  if echo "$projects" | grep -q "\"title\":\"$title\""; then
    log_skip "Vikunja project '$title' already exists"
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X PUT "$VIKUNJA_API/projects" \
    -H "Authorization: Bearer $VIKUNJA_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"$title\"}")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Vikunja project '$title' created"
  else
    log_fail "Vikunja project '$title' — HTTP $http_code"
  fi
}

create_vikunja_label() {
  local title="$1"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Vikunja label: $title"
    return 0
  fi

  # Check if label exists
  local labels
  labels=$(curl -sf -H "Authorization: Bearer $VIKUNJA_ADMIN_TOKEN" \
    "$VIKUNJA_API/labels" 2>/dev/null || echo "[]")

  if echo "$labels" | grep -q "\"title\":\"$title\""; then
    log_skip "Vikunja label '$title' already exists"
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X PUT "$VIKUNJA_API/labels" \
    -H "Authorization: Bearer $VIKUNJA_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"$title\"}")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Vikunja label '$title' created"
  else
    log_fail "Vikunja label '$title' — HTTP $http_code"
  fi
}

run_vikunja() {
  section "Vikunja (tasks.ramoneees.com)"
  check_service "Vikunja" "$VIKUNJA_URL" || return 1

  # Create agent accounts
  create_vikunja_user "hermes"     "hermes@ramoneees.com"     "$VIKUNJA_HERMES_PASSWORD"
  create_vikunja_user "hephaestus" "hephaestus@ramoneees.com" "$VIKUNJA_HEPHAESTUS_PASSWORD"
  create_vikunja_user "prometheus" "prometheus@ramoneees.com"  "$VIKUNJA_PROMETHEUS_PASSWORD"
  create_vikunja_user "athena"     "athena@ramoneees.com"      "$VIKUNJA_ATHENA_PASSWORD"
  create_vikunja_user "plutus"     "plutus@ramoneees.com"      "$VIKUNJA_PLUTUS_PASSWORD"
  create_vikunja_user "themis"     "themis@ramoneees.com"      "$VIKUNJA_THEMIS_PASSWORD"
  create_vikunja_user "mnemosyne"  "mnemosyne@ramoneees.com"   "$VIKUNJA_MNEMOSYNE_PASSWORD"

  # Create projects
  echo ""
  for project in Hermes Hephaestus Prometheus Athena Plutus Themis OLYMPUS-Audit; do
    create_vikunja_project "$project"
  done

  # Create labels
  echo ""
  for label in delegated in-progress pending-review approved rejected financial infra code; do
    create_vikunja_label "$label"
  done
}

# ════════════════════════════════════════════════════════════
# MATTERMOST
# ════════════════════════════════════════════════════════════
MATTERMOST_URL="https://chat.ramoneees.com"
MATTERMOST_API="$MATTERMOST_URL/api/v4"

mattermost_user_exists() {
  local username="$1"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    "$MATTERMOST_API/users/username/$username")
  [[ "$http_code" =~ ^2 ]]
}

mattermost_get_user_id() {
  local username="$1"
  local user_id
  # Try regular user lookup first
  user_id=$(curl -sf -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    "$MATTERMOST_API/users/username/$username" 2>/dev/null | \
    grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  # If not found, check bots (bots have a user_id but aren't in /users/username/)
  if [[ -z "$user_id" ]]; then
    user_id=$(curl -sf -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
      "$MATTERMOST_API/bots" 2>/dev/null | \
      grep -o "\"user_id\":\"[^\"]*\",\"username\":\"$username\"" | \
      grep -o '"user_id":"[^"]*"' | head -1 | cut -d'"' -f4)
  fi
  echo "$user_id"
}

mattermost_get_team_id() {
  # Get first available team
  curl -sf -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    "$MATTERMOST_API/teams" 2>/dev/null | \
    grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

create_mattermost_bot() {
  if $DRY_RUN; then
    log_info "[dry-run] Would create Mattermost bot: hermes"
    return 0
  fi

  if mattermost_user_exists "hermes"; then
    log_skip "Mattermost bot 'hermes' already exists"
    # Ensure bot is on the team (bots need explicit team membership)
    local bot_user_id team_id
    bot_user_id=$(mattermost_get_user_id "hermes")
    team_id=$(mattermost_get_team_id)
    if [[ -n "$bot_user_id" && -n "$team_id" ]]; then
      curl -sf -X POST "$MATTERMOST_API/teams/$team_id/members" \
        -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"team_id\": \"$team_id\", \"user_id\": \"$bot_user_id\"}" > /dev/null 2>&1 || true
    fi
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$MATTERMOST_API/bots" \
    -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "username": "hermes",
      "display_name": "Hermes",
      "description": "OLYMPUS Orchestrator"
    }')

  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | head -1)

  if [[ "$http_code" =~ ^2 ]]; then
    local bot_user_id
    bot_user_id=$(echo "$body" | grep -o '"user_id":"[^"]*"' | head -1 | cut -d'"' -f4)

    # Generate bot token
    local token_response
    token_response=$(curl -sf \
      -X POST "$MATTERMOST_API/users/$bot_user_id/tokens" \
      -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"description": "OLYMPUS Hermes bot token"}')

    local bot_token
    bot_token=$(echo "$token_response" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [[ -n "$bot_token" ]]; then
      log_ok "Mattermost bot 'hermes' created with token"
      # Update credentials file with bot token
      sed -i.bak "s|^MATTERMOST_HERMES_BOT_TOKEN=.*|MATTERMOST_HERMES_BOT_TOKEN=$bot_token|" "$CREDENTIALS_FILE"
      rm -f "${CREDENTIALS_FILE}.bak"
      log_info "Bot token saved to $CREDENTIALS_FILE"
    else
      log_ok "Mattermost bot 'hermes' created (token generation failed — do manually)"
    fi
  else
    log_fail "Mattermost bot 'hermes' — HTTP $http_code"
  fi
}

create_mattermost_user() {
  local username="$1" email="$2" password="$3" display_name="$4"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Mattermost user: $username ($email) password=$(mask)"
    return 0
  fi

  if mattermost_user_exists "$username"; then
    log_skip "Mattermost user '$username' already exists"
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$MATTERMOST_API/users" \
    -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"$email\",
      \"username\": \"$username\",
      \"password\": \"$password\",
      \"first_name\": \"$display_name\"
    }")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Mattermost user '$username' created (password=$(mask))"

    # Add user to team
    local user_id team_id
    user_id=$(mattermost_get_user_id "$username")
    team_id=$(mattermost_get_team_id)
    if [[ -n "$user_id" && -n "$team_id" ]]; then
      curl -sf -X POST "$MATTERMOST_API/teams/$team_id/members" \
        -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"team_id\": \"$team_id\", \"user_id\": \"$user_id\"}" > /dev/null 2>&1
    fi
  else
    log_fail "Mattermost user '$username' — HTTP $http_code"
  fi
}

create_mattermost_channel() {
  local name="$1" display_name="$2" type="$3" team_id="$4"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Mattermost channel: $name ($type)"
    return 0
  fi

  # Check if channel exists
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    "$MATTERMOST_API/teams/$team_id/channels/name/$name")

  if [[ "$http_code" =~ ^2 ]]; then
    log_skip "Mattermost channel '$name' already exists"
    return 0
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$MATTERMOST_API/channels" \
    -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"team_id\": \"$team_id\",
      \"name\": \"$name\",
      \"display_name\": \"$display_name\",
      \"type\": \"$type\"
    }")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Mattermost channel '$name' created ($type)"
  else
    log_fail "Mattermost channel '$name' — HTTP $http_code"
  fi
}

add_mattermost_user_to_channel() {
  local username="$1" channel_name="$2" team_id="$3"

  if $DRY_RUN; then
    log_info "[dry-run] Would add $username to channel $channel_name"
    return 0
  fi

  local user_id channel_id
  user_id=$(mattermost_get_user_id "$username")

  channel_id=$(curl -sf -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    "$MATTERMOST_API/teams/$team_id/channels/name/$channel_name" 2>/dev/null | \
    grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [[ -z "$user_id" || -z "$channel_id" ]]; then
    log_fail "Could not resolve user '$username' or channel '$channel_name'"
    return 1
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$MATTERMOST_API/channels/$channel_id/members" \
    -H "Authorization: Bearer $MATTERMOST_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"$user_id\"}")

  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Added $username → #$channel_name"
  else
    log_skip "Could not add $username → #$channel_name (HTTP $http_code)"
  fi
}

run_mattermost() {
  section "Mattermost (chat.ramoneees.com)"
  check_service "Mattermost" "$MATTERMOST_URL" || return 1

  # Hermes bot
  create_mattermost_bot

  # Regular user accounts
  create_mattermost_user "prometheus"  "prometheus@ramoneees.com"  "$MATTERMOST_PROMETHEUS_PASSWORD"  "Prometheus"
  create_mattermost_user "hephaestus"  "hephaestus@ramoneees.com"  "$MATTERMOST_HEPHAESTUS_PASSWORD"  "Hephaestus"
  create_mattermost_user "athena"      "athena@ramoneees.com"      "$MATTERMOST_ATHENA_PASSWORD"      "Athena"
  create_mattermost_user "plutus"      "plutus@ramoneees.com"      "$MATTERMOST_PLUTUS_PASSWORD"      "Plutus"
  create_mattermost_user "themis"      "themis@ramoneees.com"      "$MATTERMOST_THEMIS_PASSWORD"      "Themis"

  # Get team ID for channel operations
  local team_id
  if ! $DRY_RUN; then
    team_id=$(mattermost_get_team_id)
    if [[ -z "$team_id" ]]; then
      log_fail "Could not get Mattermost team ID — skipping channels"
      return 1
    fi
  else
    team_id="dry-run-team-id"
  fi

  # Create channels
  echo ""
  create_mattermost_channel "olympus-general"  "OLYMPUS General"  "O" "$team_id"
  create_mattermost_channel "olympus-alerts"   "OLYMPUS Alerts"   "O" "$team_id"
  create_mattermost_channel "olympus-infra"    "OLYMPUS Infra"    "O" "$team_id"
  create_mattermost_channel "olympus-code"     "OLYMPUS Code"     "O" "$team_id"
  create_mattermost_channel "olympus-finance"  "OLYMPUS Finance"  "P" "$team_id"
  create_mattermost_channel "olympus-log"      "OLYMPUS Log"      "O" "$team_id"

  # Add agents to channels
  echo ""
  log_info "Adding agents to channels..."

  # All agents → olympus-general, olympus-log
  for agent in hermes prometheus hephaestus athena plutus themis; do
    add_mattermost_user_to_channel "$agent" "olympus-general" "$team_id"
    add_mattermost_user_to_channel "$agent" "olympus-log" "$team_id"
  done

  # Specific channel memberships
  add_mattermost_user_to_channel "hermes"     "olympus-alerts"  "$team_id"
  add_mattermost_user_to_channel "prometheus" "olympus-alerts"  "$team_id"
  add_mattermost_user_to_channel "prometheus" "olympus-infra"   "$team_id"
  add_mattermost_user_to_channel "hermes"     "olympus-infra"   "$team_id"
  add_mattermost_user_to_channel "hephaestus" "olympus-code"    "$team_id"
  add_mattermost_user_to_channel "hermes"     "olympus-code"    "$team_id"
  add_mattermost_user_to_channel "plutus"     "olympus-finance" "$team_id"
  add_mattermost_user_to_channel "hermes"     "olympus-finance" "$team_id"
  add_mattermost_user_to_channel "themis"     "olympus-finance" "$team_id"
}

# ════════════════════════════════════════════════════════════
# GITEA
# ════════════════════════════════════════════════════════════
GITEA_URL="https://git.ramoneees.com"
GITEA_API="$GITEA_URL/api/v1"

gitea_user_exists() {
  local username="$1"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Basic $(gitea_basic_auth)" \
    "$GITEA_API/users/$username")
  [[ "$http_code" =~ ^2 ]]
}

create_gitea_user() {
  local username="$1" email="$2" password="$3"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Gitea user: $username ($email) password=$(mask)"
    return 0
  fi

  if gitea_user_exists "$username"; then
    log_skip "Gitea user '$username' already exists"
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$GITEA_API/admin/users" \
    -H "Authorization: Basic $(gitea_basic_auth)" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"$username\",
      \"email\": \"$email\",
      \"password\": \"$password\",
      \"must_change_password\": false,
      \"send_notify\": false,
      \"source_id\": 0,
      \"login_name\": \"$username\"
    }")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Gitea user '$username' created (password=$(mask))"
  else
    log_fail "Gitea user '$username' — HTTP $http_code"
  fi
}

gitea_add_collaborator() {
  local owner="$1" repo="$2" username="$3" permission="$4"

  if $DRY_RUN; then
    log_info "[dry-run] Would add $username to $owner/$repo ($permission)"
    return 0
  fi

  # Check if already a collaborator
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Basic $(gitea_basic_auth)" \
    "$GITEA_API/repos/$owner/$repo/collaborators/$username")

  if [[ "$http_code" =~ ^2 ]]; then
    log_skip "Gitea: '$username' is already a collaborator on $owner/$repo"
    return 0
  fi

  response=$(curl -s -w "\n%{http_code}" \
    -X PUT "$GITEA_API/repos/$owner/$repo/collaborators/$username" \
    -H "Authorization: Basic $(gitea_basic_auth)" \
    -H "Content-Type: application/json" \
    -d "{\"permission\": \"$permission\"}")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Gitea: '$username' added to $owner/$repo ($permission)"
  else
    log_fail "Gitea: '$username' → $owner/$repo — HTTP $http_code"
  fi
}

run_gitea() {
  section "Gitea (gitea.ramoneees.com)"
  check_service "Gitea" "$GITEA_URL" || return 1

  create_gitea_user "hephaestus" "hephaestus@ramoneees.com" "$GITEA_HEPHAESTUS_PASSWORD"
  create_gitea_user "prometheus"  "prometheus@ramoneees.com"  "$GITEA_PROMETHEUS_PASSWORD"
  create_gitea_user "themis"      "themis@ramoneees.com"      "$GITEA_THEMIS_PASSWORD"

  # Add collaborators to olympus-gitops repo
  # Assumes the repo is owned by the admin user
  echo ""
  local repo_owner="$GITEA_ADMIN_USER"
  gitea_add_collaborator "$repo_owner" "olympus" "hephaestus" "write"
  gitea_add_collaborator "$repo_owner" "olympus" "prometheus"  "write"
  gitea_add_collaborator "$repo_owner" "olympus" "themis"      "read"
}

# ════════════════════════════════════════════════════════════
# FIREFLY III
# ════════════════════════════════════════════════════════════
FIREFLY_URL="https://firefly.ramoneees.com"
FIREFLY_API="$FIREFLY_URL/api/v1"

create_firefly_user() {
  local email="$1" role="$2" agent_name="$3"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Firefly III user: $email (role=$role)"
    return 0
  fi

  # Check if user exists by listing users
  local users
  users=$(curl -sf \
    -H "Authorization: Bearer $FIREFLY_ADMIN_TOKEN" \
    -H "Accept: application/json" \
    "$FIREFLY_API/users" 2>/dev/null || echo '{"data":[]}')

  if echo "$users" | grep -q "\"email\":\"$email\""; then
    log_skip "Firefly III user '$email' already exists"
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$FIREFLY_API/users" \
    -H "Authorization: Bearer $FIREFLY_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
      \"email\": \"$email\",
      \"blocked\": false,
      \"role\": \"$role\"
    }")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Firefly III user '$agent_name' ($email) created (role=$role)"
  else
    log_fail "Firefly III user '$agent_name' — HTTP $http_code"
  fi
}

run_firefly() {
  section "Firefly III (firefly.ramoneees.com)"
  check_service "Firefly III" "$FIREFLY_URL" || return 1

  create_firefly_user "plutus@ramoneees.com" "owner"  "plutus"
  create_firefly_user "themis@ramoneees.com" "owner"  "themis"

  log_info "Firefly III uses OAuth tokens — generate manually via UI after account creation"
}

# ════════════════════════════════════════════════════════════
# AUTHENTIK
# ════════════════════════════════════════════════════════════
AUTHENTIK_URL="https://auth.ramoneees.com"
AUTHENTIK_API="$AUTHENTIK_URL/api/v3"

create_authentik_user() {
  local username="$1" display_name="$2" email="$3"

  if $DRY_RUN; then
    log_info "[dry-run] Would create Authentik user: $username ($email)"
    return 0
  fi

  # Check if user exists
  local users
  users=$(curl -sf -H "Authorization: Bearer $AUTHENTIK_ADMIN_TOKEN" \
    "$AUTHENTIK_API/core/users/?username=$username" 2>/dev/null || echo '{"results":[]}')

  if echo "$users" | grep -q "\"username\":\"$username\""; then
    log_skip "Authentik user '$username' already exists"
    return 0
  fi

  local response http_code
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "$AUTHENTIK_API/core/users/" \
    -H "Authorization: Bearer $AUTHENTIK_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"$username\",
      \"name\": \"$display_name\",
      \"email\": \"$email\",
      \"is_active\": true,
      \"groups\": [],
      \"attributes\": {\"role\": \"olympus-agent\"}
    }")

  http_code=$(echo "$response" | tail -1)
  if [[ "$http_code" =~ ^2 ]]; then
    log_ok "Authentik user '$username' created"
  else
    log_fail "Authentik user '$username' — HTTP $http_code"
  fi
}

run_authentik() {
  section "Authentik (auth.ramoneees.com)"
  check_service "Authentik" "$AUTHENTIK_URL" || return 1

  create_authentik_user "prometheus" "Prometheus" "prometheus@ramoneees.com"
}

# ════════════════════════════════════════════════════════════
# MANUAL ACCOUNTS (no API available)
# ════════════════════════════════════════════════════════════
print_manual_steps() {
  section "Manual Account Creation Required"

  log_manual "Invoice Ninja — create plutus account manually"
  log_info "  URL: https://invoice.ramoneees.com → Settings → Users → Add User"
  log_info "  Email: plutus@ramoneees.com"
  log_info "  Password: see INVOICENINJA_PLUTUS_PASSWORD in .secrets/agent-credentials.env"
  echo ""

  log_manual "Uptime Kuma — create prometheus account manually"
  log_info "  URL: https://status.ramoneees.com → Settings → Security"
  log_info "  Email: prometheus@ramoneees.com"
  log_info "  Password: see UPTIMEKUMA_PROMETHEUS_PASSWORD in .secrets/agent-credentials.env"
  echo ""

  log_manual "Homebox — invite athena account manually"
  log_info "  URL: https://homebox.ramoneees.com → Profile → Invite User"
  log_info "  Email: athena@ramoneees.com"
  log_info "  Password: see HOMEBOX_ATHENA_PASSWORD in .secrets/agent-credentials.env"
}

# ════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════
main() {
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   OLYMPUS Agent Account Creation                ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo ""

  if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN MODE — no API calls will be made${NC}"
    echo ""
  fi

  if ! $DRY_RUN; then
    validate_admin_tokens
  fi

  # Run all service account creation
  run_vikunja
  run_mattermost
  run_gitea
  run_firefly
  run_authentik
  print_manual_steps

  # Summary
  section "Summary"
  if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Completed with $ERRORS error(s)${NC}"
    echo -e "Review failures above and re-run the script (it is idempotent)."
    exit 1
  else
    echo -e "${GREEN}All automated accounts created successfully!${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Complete manual account creation (see above)"
    echo -e "  2. Generate API tokens — see docs/account-creation-checklist.md"
    echo -e "  3. Fill token values in .secrets/agent-credentials.env"
    echo -e "  4. Copy .secrets/ to Vaultwarden as secure note"
    exit 0
  fi
}

main
