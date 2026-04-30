#!/usr/bin/env bash

# Script to download the NCBITaxon OWL file and load it into Virtuoso for use in Snorql-UI.

#This script is run as part of the data upload process in plantmetwiki-upload-data.sh, but can also be run independently if needed.

#TODO: Make sure that license information is included in the downloaded file, and that it is properly attributed when used in Snorql-UI. 

set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo "❌ .env file not found"
  exit 1
fi

: "${VIRTUOSO_CONTAINER:?Missing VIRTUOSO_CONTAINER in .env}"
: "${VIRTUOSO_PASSWORD:?Missing VIRTUOSO_PASSWORD in .env}"

HOST_IMPORT_DIR="${HOST_IMPORT_DIR:-db/import}"
CONTAINER_IMPORT_DIR="${CONTAINER_IMPORT_DIR:-/database/import}"

NCBITAXON_URL="${NCBITAXON_URL:-http://purl.obolibrary.org/obo/ncbitaxon.owl}"
NCBITAXON_FILE="${NCBITAXON_FILE:-ncbitaxon.owl}"
NCBITAXON_GRAPH_URI="${NCBITAXON_GRAPH_URI:-http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon}"

HOST_FILE="${HOST_IMPORT_DIR}/${NCBITAXON_FILE}"

mkdir -p "$HOST_IMPORT_DIR"

echo "🌿 Downloading NCBITaxon..."
wget -O "$HOST_FILE" "$NCBITAXON_URL"

if command -v rapper >/dev/null 2>&1; then
  echo "🔎 Validating RDF/XML..."
  rapper -i rdfxml "$HOST_FILE" -c
else
  echo "ℹ️ rapper not found; skipping validation"
fi

echo "📦 Loading NCBITaxon into Virtuoso..."
docker exec -i "$VIRTUOSO_CONTAINER" isql 1111 dba "$VIRTUOSO_PASSWORD" <<SQL
SPARQL CLEAR GRAPH <${NCBITAXON_GRAPH_URI}>;

DELETE FROM DB.DBA.load_list
WHERE ll_file = '${CONTAINER_IMPORT_DIR}/${NCBITAXON_FILE}';

ld_dir('${CONTAINER_IMPORT_DIR}', '${NCBITAXON_FILE}', '${NCBITAXON_GRAPH_URI}');
rdf_loader_run();
checkpoint;
SQL

echo "✅ Loaded NCBITaxon into:"
echo "   ${NCBITAXON_GRAPH_URI}"