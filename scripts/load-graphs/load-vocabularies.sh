#!/usr/bin/env bash
# scripts/load-graphs/load-vocabularies.sh
#
# Load the vocabularies whose classes PlantMetWiki uses into the local Virtuoso
# instance as one named graph, so every class used in the data has an
# rdfs:label in the endpoint (YummyData's Usefulness > Metadata score checks
# for labelled classes in each graph, and it makes results more readable).
#
# Vocabularies loaded:
#   wp.ttl    WikiPathways vocabulary  (https://vocabularies.wikipathways.org/wp.owl)
#   gpml.ttl  GPML vocabulary          (https://vocabularies.wikipathways.org/gpml.owl)
#   void.ttl  VoID vocabulary          (https://github.com/cygri/void)
#   pmw.ttl   PlantMetWiki vocabulary  (vocab/pmw.ttl in this repository)
#
# The WikiPathways .owl files are served as Turtle despite their extension;
# they are saved as .ttl so the Virtuoso bulk loader parses them as Turtle.
#
# Usage:
#   bash scripts/load-graphs/load-vocabularies.sh
#   bash scripts/load-graphs/load-vocabularies.sh --check    # count only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load shared config (sources .env into the environment)
source "${REPO_ROOT}/scripts/config.sh"

HOST_DATA_DIR="${REPO_ROOT}/db/data/vocabularies"
GRAPH_URI="${VOCAB_GRAPH_URI:-http://rdf-plantmetwiki.bioinformatics.nl/graph/vocabularies}"
CHECK_ONLY=false

# local file name → download URL
declare -A SOURCES=(
  [wp.ttl]="https://vocabularies.wikipathways.org/wp.owl"
  [gpml.ttl]="https://vocabularies.wikipathways.org/gpml.owl"
  [void.ttl]="https://raw.githubusercontent.com/cygri/void/master/rdfs/void.ttl"
)

while [ $# -gt 0 ]; do
  case "$1" in
    --check)     CHECK_ONLY=true; shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *)           echo "Unknown option: $1"; exit 1 ;;
  esac
done

isql() {
  docker exec -i "$VIRTUOSO_CONTAINER" \
    isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" "$@"
}

if ! docker ps --format '{{.Names}}' | grep -q "^${VIRTUOSO_CONTAINER}$"; then
  echo "ERROR: Container '${VIRTUOSO_CONTAINER}' is not running."
  echo "  Start it with: docker compose up -d virtuoso"
  exit 1
fi

if [ "$CHECK_ONLY" = true ]; then
  echo "Checking <${GRAPH_URI}> ..."
  isql <<EOF
SPARQL SELECT (COUNT(*) AS ?triples) WHERE { GRAPH <${GRAPH_URI}> { ?s ?p ?o } };
quit;
EOF
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Vocabulary loader"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Target: $HOST_DATA_DIR"
echo "  Graph:  $GRAPH_URI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Download (always re-fetched: the files are small and may be updated)
mkdir -p "$HOST_DATA_DIR"
for file in "${!SOURCES[@]}"; do
  url="${SOURCES[$file]}"
  echo "Downloading $url → $file"
  curl -fsSL -o "${HOST_DATA_DIR}/${file}" "$url"
done
cp "${REPO_ROOT}/vocab/pmw.ttl" "${HOST_DATA_DIR}/pmw.ttl"

FILES=(wp.ttl gpml.ttl void.ttl pmw.ttl)

# 2. Optional rapper validation
if command -v rapper >/dev/null 2>&1; then
  for file in "${FILES[@]}"; do
    if rapper -i turtle -c "${HOST_DATA_DIR}/${file}" >/dev/null 2>&1; then
      echo "  ✔ ${file} valid"
    else
      echo "  WARNING: rapper reported issues in ${file} — continuing"
    fi
  done
else
  echo "[INFO] rapper not installed; skipping syntax validation"
fi

# 3. Copy to /tmp inside container and load (consistent with load-ncbitaxon.sh)
for file in "${FILES[@]}"; do
  docker cp "${HOST_DATA_DIR}/${file}" "${VIRTUOSO_CONTAINER}:/tmp/vocab-${file}"
done

echo "Loading into <${GRAPH_URI}> ..."
isql <<EOF
SPARQL CLEAR GRAPH <${GRAPH_URI}>;

DELETE FROM DB.DBA.LOAD_LIST WHERE ll_file LIKE '/tmp/vocab-%';

ld_dir('/tmp', 'vocab-*.ttl', '${GRAPH_URI}');
rdf_loader_run();
checkpoint;

SPARQL SELECT (COUNT(*) AS ?triples) WHERE { GRAPH <${GRAPH_URI}> { ?s ?p ?o } };
quit;
EOF

# 4. Clean up
for file in "${FILES[@]}"; do
  docker exec "$VIRTUOSO_CONTAINER" rm -f "/tmp/vocab-${file}"
done

echo ""
echo "✔ Vocabularies loaded into <${GRAPH_URI}>"
echo ""
echo "Test query (classes used in the data that still have no label):"
cat <<'SPARQL'

PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT DISTINCT ?c
WHERE {
    ?x a ?c .
    FILTER NOT EXISTS { ?c rdfs:label ?label }
}
SPARQL
