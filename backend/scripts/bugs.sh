#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# bugs.sh — read and triage the in-app bug backlog.
#
# Usage:
#   ./scripts/bugs.sh list [status]        # default: new  (use "all" for every status)
#   ./scripts/bugs.sh show <n|uuid>        # one full report, diagnostic included
#   ./scripts/bugs.sh triage <n> "<notes>" # mark triaged + record notes
#   ./scripts/bugs.sh start <n>            # mark in_progress
#   ./scripts/bugs.sh resolve <n> "<what we did>"
#   ./scripts/bugs.sh wontfix <n> "<why>"
#   ./scripts/bugs.sh dupe <n> <uuid-of-original>
#   ./scripts/bugs.sh tag <n> <tag>[,<tag>...]
#
# <n> is the short number: BUG-17 is just 17.
#
# Statuses: new | triaged | in_progress | fixed | wont_fix | duplicate
# Reports are NEVER deleted — resolving one keeps it as regression-test fodder.
#
# Requires ADMIN_API_KEY and BACKEND_URL in backend/.env.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# ADMIN_API_KEY and BACKEND_URL normally live in Railway, not in backend/.env.
# Rather than keep a second copy of the admin key on disk, pull them from the
# linked Railway project on demand. Requires `railway login` + `railway link`.
RAILWAY_VARS=""
railway_var() {
  if [[ -z "$RAILWAY_VARS" ]]; then
    RAILWAY_VARS="$(railway variables --json 2>/dev/null || true)"
    if [[ -z "$RAILWAY_VARS" ]]; then
      echo "Error: could not read Railway variables. Run 'railway login' and 'railway link', or set $1 in backend/.env." >&2
      exit 1
    fi
  fi
  jq -r --arg k "$1" '.[$k] // empty' <<<"$RAILWAY_VARS"
}

if [[ -z "${ADMIN_API_KEY:-}" ]]; then
  ADMIN_API_KEY="$(railway_var ADMIN_API_KEY)"
  [[ -n "$ADMIN_API_KEY" ]] || { echo "Error: ADMIN_API_KEY not found in backend/.env or Railway." >&2; exit 1; }
fi

if [[ -z "${BACKEND_URL:-}" ]]; then
  DOMAIN="$(railway_var RAILWAY_PUBLIC_DOMAIN)"
  [[ -n "$DOMAIN" ]] || { echo "Error: BACKEND_URL not set and no Railway public domain found." >&2; exit 1; }
  BACKEND_URL="https://${DOMAIN}"
fi

BASE="${BACKEND_URL%/}/api/v1/admin/bugs"

usage() {
  sed -n '5,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

# api <METHOD> <URL> [JSON_BODY]
api() {
  local method="$1" url="$2" body="${3:-}"
  local response http_code
  response="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$response'" RETURN

  if [[ -n "$body" ]]; then
    http_code=$(curl -s -o "$response" -w '%{http_code}' -X "$method" "$url" \
      -H "X-Admin-Key: ${ADMIN_API_KEY}" \
      -H 'Content-Type: application/json' \
      -d "$body")
  else
    http_code=$(curl -s -o "$response" -w '%{http_code}' -X "$method" "$url" \
      -H "X-Admin-Key: ${ADMIN_API_KEY}")
  fi

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "Error: HTTP $http_code" >&2
    jq . "$response" 2>/dev/null >&2 || cat "$response" >&2
    return 1
  fi
  cat "$response"
}

# patch <n> <json>
patch_bug() {
  api PATCH "$BASE/$1" "$2" \
    | jq -r '"BUG-\(.seq) → \(.status)\(if .resolved_at then " (closed \(.resolved_at))" else "" end)"'
}

[[ $# -ge 1 ]] || usage
CMD="$1"; shift

case "$CMD" in
  list)
    STATUS="${1:-new}"
    URL="$BASE?limit=100"
    [[ "$STATUS" != "all" ]] && URL="$URL&status=$STATUS"
    api GET "$URL" | jq -r '
      if .count == 0 then "No bug reports." else
      "\(.count) report(s)\n",
      (.bugs[] |
        "BUG-\(.seq)  [\(.status)]  \(.created_at[0:16] | sub("T"; " "))  v\(.app_version // "?") (\(.build_number // "?"))",
        "          \(.description | gsub("\n"; " ") | .[0:110])",
        (if .triage_notes then "          notes: \(.triage_notes | gsub("\n"; " ") | .[0:110])" else empty end),
        ""
      ) end'
    ;;

  show)
    [[ $# -eq 1 ]] || usage
    api GET "$BASE/$1" | jq -r '
      "# BUG-\(.seq) — \(.status)",
      "",
      "- id: \(.id)",
      "- filed: \(.created_at)",
      "- reporter: \(.user_id // "unknown")",
      "- app: \(.app_version // "?") (\(.build_number // "?")) · iOS \(.ios_version // "?") · \(.device_model // "?")",
      "- state: \(.app_state // "?")",
      (if .tags | length > 0 then "- tags: \(.tags | join(", "))" else empty end),
      (if .duplicate_of then "- duplicate of: \(.duplicate_of)" else empty end),
      (if .resolved_at then "- closed: \(.resolved_at)" else empty end),
      "",
      "## What the user reported",
      "",
      .description,
      (if .expected_behavior then "", "**Expected:** \(.expected_behavior)" else empty end),
      (if .triage_notes then "", "## Triage notes", "", .triage_notes else empty end),
      (if .resolution then "", "## Resolution", "", .resolution else empty end),
      "",
      "## Diagnostic",
      "",
      .diagnostic'
    ;;

  triage)  [[ $# -eq 2 ]] || usage; patch_bug "$1" "$(jq -n --arg n "$2" '{status:"triaged", triageNotes:$n}')" ;;
  start)   [[ $# -eq 1 ]] || usage; patch_bug "$1" '{"status":"in_progress"}' ;;
  resolve) [[ $# -eq 2 ]] || usage; patch_bug "$1" "$(jq -n --arg r "$2" '{status:"fixed", resolution:$r}')" ;;
  wontfix) [[ $# -eq 2 ]] || usage; patch_bug "$1" "$(jq -n --arg r "$2" '{status:"wont_fix", resolution:$r}')" ;;
  dupe)    [[ $# -eq 2 ]] || usage; patch_bug "$1" "$(jq -n --arg d "$2" '{status:"duplicate", duplicateOf:$d}')" ;;
  tag)
    [[ $# -eq 2 ]] || usage
    patch_bug "$1" "$(jq -n --arg t "$2" '{tags: ($t | split(","))}')"
    ;;

  *) usage ;;
esac
