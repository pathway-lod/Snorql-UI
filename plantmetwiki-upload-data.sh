#!/usr/bin/env bash

# Script to upload PlantMetWiki RDF data into Virtuoso for use in Snorql-UI

set -euo pipefail

# --------------------------------------------------
# Resolve repository root
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# --------------------------------------------------
# Load environment variables from .env
# --------------------------------------------------
if [ -f .env ]; then
  echo "🔧 Loading environment from .env"
  set -a
  source .env
  set +a
else
  echo "❌ .env file not found. Please create it first:"
  echo "   cp .env.example .env"
  exit 1
fi

# --------------------------------------------------
# Validate required variables
# --------------------------------------------------
: "${VIRTUOSO_CONTAINER:?Missing VIRTUOSO_CONTAINER in .env}"
: "${VIRTUOSO_PASSWORD:?Missing VIRTUOSO_PASSWORD in .env}"

# --------------------------------------------------
# Loader configuration
# --------------------------------------------------
LOAD_DIR="${LOAD_DIR:-/database/scripts}"
LOAD_SCRIPT="${LOAD_SCRIPT:-./load.sh}"
LOAD_LOG="${LOAD_LOG:-load.log}"

# Use interactive mode only if running in a terminal
DOCKER_EXEC_FLAGS=()
if [ -t 0 ] && [ -t 1 ]; then
  DOCKER_EXEC_FLAGS=(-it)
fi

# --------------------------------------------------
# Run core PlantMetWiki loader
# --------------------------------------------------
echo "📦 Loading core PlantMetWiki RDF into Virtuoso..."
echo "  Container : ${VIRTUOSO_CONTAINER}"
echo "  Directory : ${LOAD_DIR}"
echo "  Script    : ${LOAD_SCRIPT}"

docker exec "${DOCKER_EXEC_FLAGS[@]}" "${VIRTUOSO_CONTAINER}" /bin/bash -lc \
  "cd '${LOAD_DIR}' && ${LOAD_SCRIPT} '${LOAD_LOG}' '${VIRTUOSO_PASSWORD}'"

# --------------------------------------------------
# Optional: Load NCBITaxon graph
# --------------------------------------------------
if [ "${LOAD_NCBITAXON:-false}" = "true" ]; then
  echo
  echo "🌿 Loading NCBITaxon graph..."

  NCBITAXON_LOADER="${SCRIPT_DIR}/scripts/load-graphs/load-ncbitaxon.sh"

  if [ ! -x "${NCBITAXON_LOADER}" ]; then
    echo "❌ NCBITaxon loader not found or not executable:"
    echo "   ${NCBITAXON_LOADER}"
    echo
    echo "Fix with:"
    echo "   chmod +x scripts/load-graphs/load-ncbitaxon.sh"
    exit 1
  fi

  "${NCBITAXON_LOADER}"
else
  echo
  echo "ℹ️ Skipping NCBITaxon graph load."
  echo "   To enable:"
  echo "   LOAD_NCBITAXON=true ./plantmetwiki-upload-data.sh"
fi

# --------------------------------------------------
# Friendly output
# --------------------------------------------------
echo
echo "✅ Upload complete. You can now explore the data at:"
echo

if [ -n "${SNORQL_PORT:-}" ]; then
  echo "🧭 SPARQL Explorer (Snorql UI):"
  echo "   http://localhost:${SNORQL_PORT}/"
fi

if [ -n "${VIRTUOSO_HTTP_PORT:-}" ]; then
  echo "🔗 Direct SPARQL endpoint:"
  echo "   http://localhost:${VIRTUOSO_HTTP_PORT}/sparql"
fi

if [ -n "${DEFAULT_GRAPH:-}" ]; then
  echo "📦 Default graph:"
  echo "   ${DEFAULT_GRAPH}"
fi

if [ "${LOAD_NCBITAXON:-false}" = "true" ] && [ -n "${NCBITAXON_GRAPH_URI:-}" ]; then
  echo "🌿 NCBITaxon graph:"
  echo "   ${NCBITAXON_GRAPH_URI}"
fi