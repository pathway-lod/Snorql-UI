#!/usr/bin/env bash
# scripts/load-plantmetwiki-data.sh
#
# Load all PlantMetWiki RDF files from db/data/ into the local Virtuoso instance.
#
# Run AFTER download-plantmetwiki-data.py has populated db/data/.
#
# Named graphs loaded:
#   Pathway core RDF      → graph/pathways
#   Taxonomy extra        → graph/gpml-taxonomy-extra
#   Properties extra      → graph/gpml-properties-extra
#   NCBI IRI mappings     → graph/ncbi-iri-mappings
#   VoID (pathway)        → void
#   BGC plantiSMASH       → graph/bgc-plantismash
#   BGC MIBiG             → graph/bgc-mibig
#   VoID (BGC)            → void
#
# Usage:
#   bash scripts/load-plantmetwiki-data.sh
#   bash scripts/load-plantmetwiki-data.sh --clear    # drop graphs before loading
#   bash scripts/load-plantmetwiki-data.sh --check    # show graph counts only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"    # loads .env → VIRTUOSO_CONTAINER, PASSWORD, etc.

BASE_GRAPH="http://rdf-plantmetwiki.bioinformatics.nl"
DATA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/db/data"
CLEAR_GRAPHS=false
CHECK_ONLY=false

for arg in "$@"; do
  case $arg in
    --clear) CLEAR_GRAPHS=true ;;
    --check) CHECK_ONLY=true   ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────

isql() {
  docker exec -i "$VIRTUOSO_CONTAINER" \
    isql "$VIRTUOSO_ISQL_PORT" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" "$@"
}

check_virtuoso() {
  echo "Checking Virtuoso is reachable ..."
  if ! docker ps --format "{{.Names}}" | grep -q "^${VIRTUOSO_CONTAINER}$"; then
    echo "[ERROR] Container '${VIRTUOSO_CONTAINER}' is not running."
    echo "  Start it with: docker compose up -d virtuoso"
    exit 1
  fi
  echo "  ✔ Container running"
}

clear_graph() {
  local graph="$1"
  echo "  Clearing <${graph}> ..."
  isql <<EOF
SPARQL CLEAR GRAPH <${graph}>;
checkpoint;
quit;
EOF
}

load_file() {
  local fname="$1"
  local graph="$2"
  local fpath="$DATA_DIR/$fname"

  if [[ ! -f "$fpath" ]]; then
    echo "  [SKIP] $fname — not found in db/data/"
    return
  fi

  local size_mb
  size_mb=$(du -m "$fpath" | cut -f1)
  echo "  Loading $fname  (${size_mb} MB) → <${graph}>"

  # Copy file into container's database dir and use bulk loader
  # Copy to /tmp inside container (/tmp is always in Virtuoso DirsAllowed)
  docker cp "$fpath" "${VIRTUOSO_CONTAINER}:/tmp/${fname}"

  isql <<EOF
-- Register the file for bulk loading
ld_dir('/tmp', '${fname}', '${graph}');

-- Run the bulk loader
rdf_loader_run();

-- Checkpoint to persist
checkpoint;

-- Clean up the load list entry
DELETE FROM DB.DBA.LOAD_LIST WHERE ll_file = '/tmp/${fname}';

quit;
EOF

  # Remove file from container after loading
  docker exec "$VIRTUOSO_CONTAINER" rm -f "/tmp/${fname}"
  echo "    ✔ Done"
}

check_graphs() {
  echo ""
  echo "── Graph summary ──────────────────────────────────────────────────────"
  isql <<'EOF'
SPARQL
SELECT ?g (COUNT(*) AS ?triples)
WHERE { GRAPH ?g { ?s ?p ?o } }
GROUP BY ?g
ORDER BY DESC(?triples);
quit;
EOF
}

# ── File → graph mapping ──────────────────────────────────────────────────────
# Returns the named graph for a given filename.
get_graph() {
  local fname="$1"
  case "$fname" in
    all-*.ttl)                       echo "${BASE_GRAPH}/graph/pathways" ;;
    all_gpml_taxonomy_extra-*.ttl)   echo "${BASE_GRAPH}/graph/gpml-taxonomy-extra" ;;
    all_gpml_properties_extra-*.ttl) echo "${BASE_GRAPH}/graph/gpml-properties-extra" ;;
    ncbi_iri_mappings-*.ttl)         echo "${BASE_GRAPH}/graph/ncbi-iri-mappings" ;;
    void-*.ttl)                      echo "${BASE_GRAPH}/void" ;;
    plantismash.ttl)                 echo "${BASE_GRAPH}/graph/bgc-plantismash" ;;
    mibig.ttl)                       echo "${BASE_GRAPH}/graph/bgc-mibig" ;;
    *) echo "" ;;
  esac
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PlantMetWiki — load RDF data into local Virtuoso"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Container: $VIRTUOSO_CONTAINER"
echo " Data dir:  $DATA_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_virtuoso

# Ensure /database/data exists inside the container
docker exec "$VIRTUOSO_CONTAINER" mkdir -p /database/data

if [[ "$CHECK_ONLY" == true ]]; then
  check_graphs
  exit 0
fi

if [[ "$CLEAR_GRAPHS" == true ]]; then
  echo ""
  echo "── Clearing existing graphs ───────────────────────────────────────────"
  for graph in \
    "${BASE_GRAPH}/graph/pathways" \
    "${BASE_GRAPH}/graph/gpml-taxonomy-extra" \
    "${BASE_GRAPH}/graph/gpml-properties-extra" \
    "${BASE_GRAPH}/graph/ncbi-iri-mappings" \
    "${BASE_GRAPH}/graph/bgc-plantismash" \
    "${BASE_GRAPH}/graph/bgc-mibig" \
    "${BASE_GRAPH}/void"; do
    clear_graph "$graph"
  done
fi

echo ""
echo "── Loading files ──────────────────────────────────────────────────────"

# Load in order: small files first, large core last
LOAD_ORDER=(
  "void-plantcyc17.0.0-gpml2021.ttl"
  "void-bgc.ttl"
  "ncbi_iri_mappings-plantcyc17.0.0-gpml2021.ttl"
  "all_gpml_taxonomy_extra-plantcyc17.0.0-gpml2021.ttl"
  "plantismash.ttl"
  "mibig.ttl"
  "all_gpml_properties_extra-plantcyc17.0.0-gpml2021.ttl"
  "all-plantcyc17.0.0-gpml2021.ttl"   # largest — load last
)

for fname in "${LOAD_ORDER[@]}"; do
  graph="$(get_graph "$fname")"
  if [[ -z "$graph" ]]; then continue; fi
  load_file "$fname" "$graph"
done

# ── Optional: load NCBITaxon ontology ────────────────────────────────────────
# Enable by setting LOAD_NCBITAXON=true (and optionally NCBITAXON_SUBSET=taxslim)
if [[ "${LOAD_NCBITAXON:-false}" == "true" ]]; then
  echo ""
  echo "── Loading NCBITaxon ontology ─────────────────────────────────────────"
  subset="${NCBITAXON_SUBSET:-full}"
  "${SCRIPT_DIR}/load-graphs/load-ncbitaxon.sh" --subset "$subset"
else
  echo ""
  echo "ℹ  Skipping NCBITaxon graph. To load it:"
  echo "    LOAD_NCBITAXON=true bash scripts/load-plantmetwiki-data.sh"
  echo "    LOAD_NCBITAXON=true NCBITAXON_SUBSET=taxslim bash scripts/load-plantmetwiki-data.sh"
fi

echo ""
echo "── Enabling SPARQL federation grants ─────────────────────────────────"
isql <<EOF
GRANT EXECUTE ON DB.DBA.SPARQL_INSERT_DICT_CONTENT TO "SPARQL";
GRANT EXECUTE ON DB.DBA.SPARQL_DELETE_DICT_CONTENT TO "SPARQL";
GRANT SELECT ON DB.DBA.SPARQL_SINV_2 TO "SPARQL";
GRANT EXECUTE ON DB.DBA.SPARQL_SINV_IMP TO "SPARQL";
checkpoint;
quit;
EOF

check_graphs

echo ""
echo "✔ All data loaded. Run ./scripts/enable-cors.sh if not already done."
echo "  UI → http://localhost:${SNORQL_PORT:-8088}/"
