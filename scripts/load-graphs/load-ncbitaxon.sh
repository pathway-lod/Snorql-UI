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
#   bash scripts/load-graphs/load-ncbitaxon.sh --subset taxslim           # OBO slim
#   bash scripts/load-graphs/load-ncbitaxon.sh --subset taxslim-disjoint
#   bash scripts/load-graphs/load-ncbitaxon.sh --subset plantmetwiki      # data-driven (recommended)
#   bash scripts/load-graphs/load-ncbitaxon.sh --check                    # count only
#
# Variants available from OBO Foundry:
#   ncbitaxon.owl                                          (full release, ~1.8 GB)
#   ncbitaxon/subsets/taxslim.owl                          (slim subset, ~38 MB)
#   ncbitaxon/subsets/taxslim-disjoint-over-in-taxon.owl   (slim + disjointness)
#
# The "plantmetwiki" subset is generated on demand with ROBOT (via Docker).
# It contains only the taxa present in db/data/all_gpml_taxonomy_extra-*.ttl
# and their complete ancestors up to the ontology root.  The result is a few MB.
# Prerequisites: Docker must be available (used to run obolibrary/robot).
# Steps performed:
#   1. Extract unique taxon IRIs from the taxonomy-extra bundle → taxa-seed.txt
#   2. Run: docker run obolibrary/robot extract --method MIREOT ...
#   3. Load the resulting ncbitaxon-plantmetwiki-subset.owl into Virtuoso

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
    ROBOT_EXTRACT=false
    ;;
  taxslim)
    URL="http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.owl"
    FILE="ncbitaxon-taxslim.owl"
    ROBOT_EXTRACT=false
    ;;
  taxslim-disjoint)
    URL="http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim-disjoint-over-in-taxon.owl"
    FILE="ncbitaxon-taxslim-disjoint.owl"
    ROBOT_EXTRACT=false
    ;;
  plantmetwiki)
    # Data-driven subset: only the taxa present in the taxonomy-extra bundle
    # + their full lineage up to the ontology root, extracted with ROBOT MIREOT.
    # Requires the full ncbitaxon.owl in db/data/ and Docker for ROBOT.
    URL="http://purl.obolibrary.org/obo/ncbitaxon.owl"
    FILE="ncbitaxon-plantmetwiki-subset.owl"
    ROBOT_EXTRACT=true
    ;;
  *)
    echo "ERROR: unknown --subset value: $SUBSET"
    echo "Valid: full, taxslim, taxslim-disjoint, plantmetwiki"
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

# 2. ROBOT extract (plantmetwiki subset only)
if [ "${ROBOT_EXTRACT:-false}" = true ]; then
  FULL_OWL="${HOST_DATA_DIR}/ncbitaxon.owl"
  SEED_FILE="${HOST_DATA_DIR}/taxa-seed.txt"
  SUBSET_FILE="${HOST_DATA_DIR}/${FILE}"

  if [ ! -f "$FULL_OWL" ]; then
    echo "ERROR: ${FULL_OWL} not found."
    echo "  The plantmetwiki subset requires the full ncbitaxon.owl as input."
    echo "  Download it first:"
    echo "    bash scripts/load-graphs/load-ncbitaxon.sh --subset full"
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running. ROBOT requires Docker."
    exit 1
  fi

  echo "Extracting seed taxon IRIs from taxonomy-extra bundle ..."
  TAXONOMY_BUNDLES=( "${HOST_DATA_DIR}"/all_gpml_taxonomy_extra-*.ttl )
  if [ ${#TAXONOMY_BUNDLES[@]} -eq 0 ] || [ ! -f "${TAXONOMY_BUNDLES[0]}" ]; then
    echo "ERROR: No all_gpml_taxonomy_extra-*.ttl found in ${HOST_DATA_DIR}."
    echo "  Run scripts/load-plantmetwiki-data.sh first."
    exit 1
  fi

  grep -ohE 'ncbi:[0-9]+' "${TAXONOMY_BUNDLES[@]}" \
    | sort -u \
    | sed 's|ncbi:|http://purl.obolibrary.org/obo/NCBITaxon_|' \
    > "$SEED_FILE"
  echo "  ✔ $(wc -l < "$SEED_FILE") unique taxa written to taxa-seed.txt"

  echo "Running ROBOT extract (MIREOT) via Docker ..."
  echo "  Input : ncbitaxon.owl"
  echo "  Seeds : taxa-seed.txt  (lower terms)"
  echo "  Output: ${FILE}"
  echo "  (This reads the full ontology — allow a few minutes and ~4 GB RAM)"
  docker run --rm \
    -v "${HOST_DATA_DIR}:/work" -w /work \
    obolibrary/robot \
    robot extract \
      --method MIREOT \
      --input ncbitaxon.owl \
      --lower-terms taxa-seed.txt \
      --output "${FILE}"

  SIZE=$(du -h "${SUBSET_FILE}" | cut -f1)
  echo "  ✔ Subset written: ${FILE}  (${SIZE})"
  echo ""
  echo "  The full ncbitaxon.owl and taxa-seed.txt can be removed once the"
  echo "  subset is confirmed working:"
  echo "    rm ${HOST_DATA_DIR}/ncbitaxon.owl"
  echo "    rm ${HOST_DATA_DIR}/taxa-seed.txt"
  echo ""
fi

# 3. Optional rapper validation
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
