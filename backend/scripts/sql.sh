#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# sql.sh — run SQL against the Sous Supabase database via the Management API.
#
# Usage:
#   ./scripts/sql.sh "select count(*) from users"     # inline query
#   ./scripts/sql.sh -f db/migrations/0001_bugs.sql   # run a file
#
# Requires SUPABASE_ACCESS_TOKEN (a scoped Supabase personal access token with
# Database: Read-write on this project) and SUPABASE_URL in backend/.env.
# The project ref is derived from SUPABASE_URL — never hardcode it.
#
# NOTE: this runs against PRODUCTION. Reads are safe; think before writing.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

: "${SUPABASE_ACCESS_TOKEN:?Error: SUPABASE_ACCESS_TOKEN is not set (check backend/.env)}"
: "${SUPABASE_URL:?Error: SUPABASE_URL is not set (check backend/.env)}"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 \"<sql>\"  |  $0 -f <file.sql>" >&2
  exit 1
fi

if [[ "$1" == "-f" ]]; then
  [[ $# -eq 2 ]] || { echo "Usage: $0 -f <file.sql>" >&2; exit 1; }
  [[ -f "$2" ]]  || { echo "Error: no such file: $2" >&2; exit 1; }
  SQL="$(cat "$2")"
  LABEL="$2"
else
  SQL="$1"
  LABEL="inline query"
fi

REF="$(printf '%s' "$SUPABASE_URL" | sed -E 's#https://([a-z0-9]+)\.supabase\.co.*#\1#')"
[[ -n "$REF" ]] || { echo "Error: could not derive project ref from SUPABASE_URL" >&2; exit 1; }

PAYLOAD="$(jq -Rs '{query: .}' <<<"$SQL")"
RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

echo "Running $LABEL against project $REF ..." >&2

HTTP_CODE=$(curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
  -X POST "https://api.supabase.com/v1/projects/${REF}/database/query" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  echo "Error: HTTP $HTTP_CODE" >&2
  jq . "$RESPONSE_FILE" 2>/dev/null || cat "$RESPONSE_FILE" >&2
  exit 1
fi

jq . "$RESPONSE_FILE" 2>/dev/null || cat "$RESPONSE_FILE"
