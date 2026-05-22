#!/usr/bin/env bash
# scripts/local-dev.sh
#
# Serve Snorql-UI locally for development without Docker.
# Reads configuration from .env (same variables as docker-compose).
#
# Usage:
#   ./scripts/local-dev.sh           # serves on port 8088
#   ./scripts/local-dev.sh 3000      # custom port
#
# Requirements:
#   - python3 (for the HTTP server)
#   - .env file in the repo root (copy from .env.example)
#
# The script creates a temporary working copy, injects the endpoint
# and other settings into snorql.js (same logic as script.sh in Docker),
# and serves the files at http://localhost:<PORT>/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8088}"

# ── Load .env ──────────────────────────────────────────────────────────────
ENV_FILE="$REPO_ROOT/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found. Copy .env.example → .env and configure it."
  exit 1
fi
# Parse .env manually to handle unquoted values and comments safely
while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    value="${value%%#*}"          # strip inline comments
    value="${value%"${value##*[![:space:]]}"}"  # rtrim
    value="${value#\"}" ; value="${value%\"}"   # strip surrounding quotes
    export "$key=$value"
done < "$ENV_FILE"

# ── Resolve endpoint (allow CLI override) ──────────────────────────────────
ENDPOINT="${SNORQL_ENDPOINT:-http://localhost:8890/sparql}"
EXAMPLES_REPO="${SNORQL_EXAMPLES_REPO:-}"
TITLE="${SNORQL_TITLE:-PlantMetWiki SPARQL Explorer}"
GRAPH="${DEFAULT_GRAPH:-}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Snorql-UI — local dev server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Endpoint:    $ENDPOINT"
echo " Examples:    $EXAMPLES_REPO"
echo " Title:       $TITLE"
echo " Port:        $PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Create temp working copy ───────────────────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$REPO_ROOT/." "$TMPDIR/"

# ── Inject settings (macOS-compatible sed) ─────────────────────────────────
SED_INPLACE=(-i '')        # macOS
if sed --version 2>/dev/null | grep -q GNU; then
  SED_INPLACE=(-i)         # GNU/Linux
fi

JS="$TMPDIR/assets/js/snorql.js"
HTML="$TMPDIR/index.html"

sed "${SED_INPLACE[@]}" \
  "s|var _endpoint = .*;|var _endpoint = \"${ENDPOINT}\";|" "$JS"

if [[ -n "$EXAMPLES_REPO" ]]; then
  sed "${SED_INPLACE[@]}" \
    "s|var _examples_repo = .*;|var _examples_repo = \"${EXAMPLES_REPO}\";|" "$JS"
fi

sed "${SED_INPLACE[@]}" \
  "s|var _defaultGraph = .*;|var _defaultGraph = \"${GRAPH}\";|" "$JS"

sed "${SED_INPLACE[@]}" \
  "s|<title>.*</title>|<title>${TITLE}</title>|" "$HTML"

echo ""
echo "✔ Configuration applied."
echo "  Open → http://localhost:${PORT}/"
echo "  Press Ctrl+C to stop."
echo ""

# ── Serve ──────────────────────────────────────────────────────────────────
cd "$TMPDIR"
python3 -m http.server "$PORT"
