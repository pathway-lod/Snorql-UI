#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Reload ONLY the VoID graph (<…/void>) in the local Virtuoso, from the VoID
# files in db/data/. Use after regenerating VoID (e.g. to pick up a corrected
# void:sparqlEndpoint or the sd:Service) without touching the data graphs.
#
# The /void graph aggregates every void-*.ttl in db/data/:
#   - void-*.ttl        (gpml-to-rdf core VoID + BridgeDb void:Linkset + sd:Service)
#   - void-bgc*.ttl     (map-to-rdf BGC VoID)
#   - void-ncbitaxon*.ttl (create-ncbitaxon-void.sh output, if present)
#   - void-vocabularies*.ttl (create-vocabularies-void.sh output, if present)
#
# Usage:
#   bash scripts/reload-void.sh
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/db/data"
BASE_GRAPH="http://rdf-plantmetwiki.bioinformatics.nl"
VOID_GRAPH="${BASE_GRAPH}/void"

# Load .env (VIRTUOSO_CONTAINER, VIRTUOSO_PASSWORD, SNORQL_CONTAINER) if present
[ -f "$SCRIPT_DIR/../.env" ] && set -a && . "$SCRIPT_DIR/../.env" && set +a
CN="${VIRTUOSO_CONTAINER:-plantmetwiki-virtuoso}"
PW="${VIRTUOSO_PASSWORD:-dba123}"
SNORQL_CN="${SNORQL_CONTAINER:-plantmetwiki-snorql}"

shopt -s nullglob
void_files=("$DATA_DIR"/void-*.ttl)
if [ ${#void_files[@]} -eq 0 ]; then
  echo "ERROR: no void-*.ttl files in $DATA_DIR" >&2
  echo "       Download (download-plantmetwiki-data.py) or regenerate VoID first." >&2
  exit 1
fi

echo "Reloading <$VOID_GRAPH> from:"
printf '  %s\n' "${void_files[@]}"

# Clear the VoID graph once, then load every void file into it.
docker exec -i "$CN" isql 1111 dba "$PW" <<SQL
SPARQL CLEAR GRAPH <$VOID_GRAPH>;
SQL

for f in "${void_files[@]}"; do
  fname="$(basename "$f")"
  docker cp "$f" "$CN:/tmp/$fname"
  docker exec -i "$CN" isql 1111 dba "$PW" <<SQL
ld_dir('/tmp', '$fname', '$VOID_GRAPH');
rdf_loader_run();
checkpoint;
DELETE FROM DB.DBA.LOAD_LIST WHERE ll_file = '/tmp/$fname';
SQL
  docker exec "$CN" rm -f "/tmp/$fname"
done

# Report
n=$(docker exec -i "$CN" isql 1111 dba "$PW" <<SQL | grep -Eo '[0-9]+' | tail -1
SPARQL SELECT (COUNT(*) AS ?n) WHERE { GRAPH <$VOID_GRAPH> { ?s ?p ?o } };
SQL
)
echo "Done. <$VOID_GRAPH> now holds ${n:-?} triples."
echo "Verify the canonical endpoint + service description:"
echo "  ?d void:sparqlEndpoint <$( echo "$BASE_GRAPH" | sed 's|rdf-plantmetwiki|plantmetwiki|' )>  (expect plantmetwiki.bioinformatics.nl/sparql)"

# ── Republish the merged VoID at the .well-known URI ─────────────────────────
# This is *not* baked into the snorql image, so it must be re-copied in on
# every reload regardless of whether the container was recreated in between.
echo ""
if docker ps --format "{{.Names}}" | grep -q "^${SNORQL_CN}$"; then
  WELL_KNOWN_VOID="$(mktemp)"
  cat "${void_files[@]}" > "$WELL_KNOWN_VOID"
  docker exec "$SNORQL_CN" mkdir -p /usr/local/apache2/htdocs/.well-known
  docker cp "$WELL_KNOWN_VOID" "${SNORQL_CN}:/usr/local/apache2/htdocs/.well-known/void"
  # mktemp creates the file 0600 and docker cp preserves that, so Apache
  # (running as daemon) could not read it and answered 403 Forbidden.
  docker exec "$SNORQL_CN" chmod 644 /usr/local/apache2/htdocs/.well-known/void
  rm -f "$WELL_KNOWN_VOID"
  echo "✔ Republished ${#void_files[@]} VoID file(s) → /.well-known/void"
else
  echo "[SKIP] Snorql container '${SNORQL_CN}' not running — /.well-known/void not republished"
fi
