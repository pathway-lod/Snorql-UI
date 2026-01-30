#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Virtuoso CORS Configuration Script
# =============================================================================
# Enables CORS on Virtuoso's /sparql endpoint so browser apps (Snorql-UI)
# can query the endpoint across origins.
#
# This script does NOT read .env itself.
# It expects environment variables to already be set (typically by:
#   - Docker Compose exporting them, or
#   - your wrapper script doing: set -a; source .env; set +a
#
# Required env vars (from .env):
#   VIRTUOSO_CONTAINER
#   VIRTUOSO_ISQL_PORT
#   VIRTUOSO_USER
#   VIRTUOSO_PASSWORD
#   VIRTUOSO_HTTP_PORT
#   CORS_ORIGINS
# =============================================================================

missing=0
for v in VIRTUOSO_CONTAINER VIRTUOSO_ISQL_PORT VIRTUOSO_USER VIRTUOSO_PASSWORD VIRTUOSO_HTTP_PORT CORS_ORIGINS; do
  if [[ -z "${!v:-}" ]]; then
    echo "❌ Missing required environment variable: $v"
    missing=1
  fi
done

if [[ "$missing" -eq 1 ]]; then
  echo ""
  echo "This script expects variables to be exported already."
  echo "Example:"
  echo "  set -a; source .env; set +a"
  echo "  ./scripts/enable-cors.sh"
  exit 1
fi

echo "============================================"
echo "Virtuoso CORS Configuration"
echo "============================================"
echo ""
echo "Container:    ${VIRTUOSO_CONTAINER}"
echo "ISQL Port:    ${VIRTUOSO_ISQL_PORT}"
echo "HTTP Port:    ${VIRTUOSO_HTTP_PORT}"
echo "CORS Origins: ${CORS_ORIGINS}"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${VIRTUOSO_CONTAINER}$"; then
  echo "❌ Error: Container '${VIRTUOSO_CONTAINER}' is not running."
  echo "Start it with: docker compose up -d"
  exit 1
fi

echo "Enabling CORS on /sparql endpoint..."
echo ""

# Virtuoso may take a few seconds after container start before ISQL accepts connections.
max_tries=20
try=1
while true; do
  if docker exec -i "${VIRTUOSO_CONTAINER}" \
      isql "localhost:${VIRTUOSO_ISQL_PORT}" "${VIRTUOSO_USER}" "${VIRTUOSO_PASSWORD}" <<EOF
-- Remove existing /sparql virtual host definition (ignore errors if missing)
DB.DBA.VHOST_REMOVE (lpath=>'/sparql');

-- Recreate with CORS enabled
DB.DBA.VHOST_DEFINE (
  lpath=>'/sparql',
  ppath=>'/!sparql/',
  is_dav=>1,
  vsp_user=>'dba',
  opts=>vector('cors', '${CORS_ORIGINS}', 'browse_sheet', '', 'noinherit', 'yes')
);

checkpoint;
quit;
EOF
  then
    break
  fi

  if [[ "$try" -ge "$max_tries" ]]; then
    echo ""
    echo "❌ Error: Failed to enable CORS after ${max_tries} attempts."
    echo "Check Virtuoso logs:"
    echo "  docker logs ${VIRTUOSO_CONTAINER} --tail 200"
    exit 1
  fi

  echo "⏳ Virtuoso not ready yet (attempt ${try}/${max_tries})... retrying in 2s"
  try=$((try+1))
  sleep 2
done

echo ""
echo "============================================"
echo "CORS enabled successfully!"
echo "============================================"
echo ""
echo "Test from browser console:"
echo "  fetch('http://localhost:${VIRTUOSO_HTTP_PORT}/sparql?query=SELECT+*+WHERE+%7B%3Fs+%3Fp+%3Fo%7D+LIMIT+1')"
echo "    .then(r => r.text())"
echo "    .then(console.log)"
echo ""