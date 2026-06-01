#!/usr/bin/env bash
# scripts/load-graphs/load-ncbitaxon.sh
#
# Download the NCBITaxon ontology (OBO Foundry) and load it into the local
# Virtuoso instance as a named graph. Lets the SPARQL endpoint resolve
# `http://purl.obolibrary.org/obo/NCBITaxon_<id>` URIs locally without
# needing a federated query against BioPortal.
#
# Source ontology: https://obofoundry.org/ontology/ncbitaxon.html
# License: CC0 1.0 Universal (Public Domain).
#
# Usage:
#   bash scripts/load-graphs/load-ncbitaxon.sh
#   bash scripts/load-graphs/load-ncbitaxon.sh --subset taxslim         # smaller
#   bash scripts/load-graphs/load-ncbitaxon.sh --subset taxslim-disjoint
#   bash scripts/load-graphs/load-ncbitaxon.sh --check                  # count only
#
# Variants available from OBO Foundry:
#   ncbitaxon.owl                                          (full release, ~1.3 GB)
#   ncbitaxon/subsets/taxslim.owl                          (slim subset)
#   ncbitaxon/subsets/taxslim-disjoint-over-in-taxon.owl   (slim + disjointness)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load shared config (sources .env into the environment)
source "${REPO_ROOT}/scripts/config.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
SUBSET="full"
CHECK_ONLY=false
HOST_DATA_DIR="${REPO_ROOT}/db/data"
GRAPH_URI="${NCBITAXON_GRAPH_URI:-http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon}"

while [ $# -gt 0 ]; do
  case "$1" in
    --subset=*)  SUBSET="${1#*=}"; shift ;;
    --subset)    SUBSET="${2:-full}"; shift 2 ;;
    --check)     CHECK_ONLY=true; shift ;;
    -h|--help)   sed -n '2,22p' "$0"; exit 0 ;;
    *)           echo "Unknown option: $1"; exit 1 ;;
  esac
done

case "$SUBSET" in
  full)
    URL="http://purl.obolibrary.org/obo/ncbitaxon.owl"
    FILE="ncbitaxon.owl"
    ;;
  taxslim)
    URL="http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.owl"
    FILE="ncbitaxon-taxslim.owl"
    ;;
  taxslim-disjoint)
    URL="http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim-disjoint-over-in-taxon.owl"
    FILE="ncbitaxon-taxslim-disjoint.owl"
    ;;
  *)
    echo "ERROR: unknown --subset value: $SUBSET"
    echo "Valid: full, taxslim, taxslim-disjoint"
    exit 1
    ;;
esac

DEST="${HOST_DATA_DIR}/${FILE}"

isql() {
  docker exec -i "$VIRTUOSO_CONTAINER" \
    isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" "$@"
}

check_virtuoso() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${VIRTUOSO_CONTAINER}$"; then
    echo "ERROR: Container '${VIRTUOSO_CONTAINER}' is not running."
    echo "  Start it with: docker compose up -d virtuoso"
    exit 1
  fi
}

# ── Check-only ───────────────────────────────────────────────────────────────

if [ "$CHECK_ONLY" = true ]; then
  check_virtuoso
  echo "Checking <${GRAPH_URI}> ..."
  isql <<EOF
SPARQL SELECT (COUNT(*) AS ?triples) WHERE { GRAPH <${GRAPH_URI}> { ?s ?p ?o } };
quit;
EOF
  exit 0
fi

# ── Main ─────────────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " NCBITaxon ontology loader"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Subset: $SUBSET"
echo "  URL:    $URL"
echo "  Target: $DEST"
echo "  Graph:  $GRAPH_URI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_virtuoso

# 1. Download (skip if file exists)
if [ -f "$DEST" ]; then
  echo "[SKIP] $FILE already in db/data/  ($(du -h "$DEST" | cut -f1))"
else
  mkdir -p "$HOST_DATA_DIR"
  echo "Downloading $URL ..."
  if command -v wget >/dev/null 2>&1; then
    wget -O "$DEST" "$URL"
  else
    curl -L -o "$DEST" "$URL"
  fi
  echo "  ✔ $(du -h "$DEST" | cut -f1)"
fi

# 2. Optional rapper validation
if command -v rapper >/dev/null 2>&1; then
  echo "Validating RDF/XML syntax with rapper ..."
  if rapper -i rdfxml -c "$DEST" >/dev/null 2>&1; then
    echo "  ✔ valid"
  else
    echo "  WARNING: rapper validation reported issues — continuing"
  fi
else
  echo "[INFO] rapper not installed; skipping syntax validation"
fi

# 3. Copy to /tmp inside container and load (consistent with load-plantmetwiki-data.sh)
echo "Copying file into container's /tmp/ ..."
docker cp "$DEST" "${VIRTUOSO_CONTAINER}:/tmp/${FILE}"

echo "Loading into <${GRAPH_URI}> (full release can take several minutes) ..."
isql <<EOF
SPARQL CLEAR GRAPH <${GRAPH_URI}>;

DELETE FROM DB.DBA.LOAD_LIST WHERE ll_file = '/tmp/${FILE}';

ld_dir('/tmp', '${FILE}', '${GRAPH_URI}');
rdf_loader_run();
checkpoint;

SPARQL SELECT (COUNT(*) AS ?triples) WHERE { GRAPH <${GRAPH_URI}> { ?s ?p ?o } };
quit;
EOF

# 4. Clean up
docker exec "$VIRTUOSO_CONTAINER" rm -f "/tmp/${FILE}"

echo ""
echo "✔ NCBITaxon loaded into <${GRAPH_URI}>"
echo ""
echo "Test query (label for Viridiplantae, NCBITaxon_33090):"
cat <<'SPARQL'

PREFIX ncbi: <http://purl.obolibrary.org/obo/NCBITaxon_>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?label
WHERE {
    GRAPH <http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon> {
        ncbi:33090 rdfs:label ?label .
    }
}
SPARQL
