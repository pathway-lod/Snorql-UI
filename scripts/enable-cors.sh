#!/bin/bash
# =============================================================================
# Virtuoso CORS Configuration Script
# =============================================================================
# This script enables CORS (Cross-Origin Resource Sharing) on Virtuoso's
# /sparql endpoint, allowing browser-based applications to make SPARQL
# queries from different origins.
#
# Why CORS is needed:
#   Browsers enforce same-origin policy, blocking requests from web pages
#   to different domains. Without CORS enabled, Snorql-UI running at
#   http://localhost:8088 cannot query Virtuoso at http://localhost:8890.
#
# Prerequisites:
#   - Virtuoso container running (see docker-compose.example.yml)
#   - Wait ~10-30 seconds after container start for Virtuoso to be ready
#
# Usage:
#   ./scripts/enable-cors.sh
#
# With custom settings:
#   VIRTUOSO_CONTAINER=my-virtuoso CORS_ORIGINS="http://localhost:8088" ./scripts/enable-cors.sh
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Source shared configuration if available (provides defaults for
# VIRTUOSO_CONTAINER, VIRTUOSO_ISQL_PORT, VIRTUOSO_USER, VIRTUOSO_PASSWORD,
# CORS_ORIGINS). Override any value via environment variables.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

# Fallback defaults if config.sh not found
VIRTUOSO_CONTAINER="${VIRTUOSO_CONTAINER:-my-virtuoso}"
VIRTUOSO_ISQL_PORT="${VIRTUOSO_ISQL_PORT:-1111}"
VIRTUOSO_USER="${VIRTUOSO_USER:-dba}"
VIRTUOSO_PASSWORD="${VIRTUOSO_PASSWORD:-dba123}"
CORS_ORIGINS="${CORS_ORIGINS:-*}"

# ---------------------------------------------------------------------------
# Main Script
# ---------------------------------------------------------------------------

echo "============================================"
echo "Virtuoso CORS Configuration"
echo "============================================"
echo ""
echo "Container:    $VIRTUOSO_CONTAINER"
echo "ISQL Port:    $VIRTUOSO_ISQL_PORT"
echo "CORS Origins: $CORS_ORIGINS"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${VIRTUOSO_CONTAINER}$"; then
    echo "Error: Container '$VIRTUOSO_CONTAINER' is not running."
    echo "Start it with: docker-compose up -d virtuoso"
    exit 1
fi

echo "Enabling CORS on /sparql endpoint..."
echo ""

# Execute SQL commands to reconfigure the virtual host with CORS
docker exec -i "$VIRTUOSO_CONTAINER" isql "$VIRTUOSO_ISQL_PORT" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" <<EOF
-- Remove existing /sparql virtual host definition
DB.DBA.VHOST_REMOVE (lpath=>'/sparql');

-- Recreate with CORS enabled
DB.DBA.VHOST_DEFINE (
  lpath=>'/sparql',
  ppath=>'/!sparql/',
  is_dav=>1,
  vsp_user=>'dba',
  opts=>vector('cors', '$CORS_ORIGINS', 'browse_sheet', '', 'noinherit', 'yes')
);

-- Persist changes
checkpoint;
quit;
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "CORS enabled successfully!"
    echo "============================================"
    echo ""
    echo "Test from browser console:"
    echo "  fetch('http://localhost:8890/sparql?query=SELECT+*+WHERE+{?s+?p+?o}+LIMIT+1')"
    echo "    .then(r => r.text())"
    echo "    .then(console.log)"
    echo ""
else
    echo ""
    echo "Error: Failed to enable CORS. Check Virtuoso logs."
    exit 1
fi
