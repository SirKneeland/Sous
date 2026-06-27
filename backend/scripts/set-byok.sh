#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# set-byok.sh — toggle BYOK eligibility for a Sous user
# Usage: ./scripts/set-byok.sh <userId> <true|false>
# ---------------------------------------------------------------------------

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <userId> <true|false>" >&2
  exit 1
fi

USER_ID="$1"
ELIGIBLE="$2"

if [[ "$ELIGIBLE" != "true" && "$ELIGIBLE" != "false" ]]; then
  echo "Error: second argument must be exactly 'true' or 'false', got: '$ELIGIBLE'" >&2
  exit 1
fi

# Load .env from backend directory (relative to this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

: "${ADMIN_API_KEY:?Error: ADMIN_API_KEY is not set (check .env or export it)}"
: "${BACKEND_URL:?Error: BACKEND_URL is not set (check .env or export it)}"

URL="${BACKEND_URL%/}/api/v1/admin/users/${USER_ID}/byok-eligible"

echo "Setting byok_eligible=${ELIGIBLE} for user ${USER_ID} ..."

HTTP_CODE=$(curl -s -o /tmp/set-byok-response.json -w "%{http_code}" \
  -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: ${ADMIN_API_KEY}" \
  -d "{\"eligible\": ${ELIGIBLE}}")

BODY=$(cat /tmp/set-byok-response.json)
rm -f /tmp/set-byok-response.json

echo "HTTP $HTTP_CODE"
echo "$BODY"

if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  echo "" >&2
  echo "Error: request failed with HTTP $HTTP_CODE" >&2
  exit 1
fi
