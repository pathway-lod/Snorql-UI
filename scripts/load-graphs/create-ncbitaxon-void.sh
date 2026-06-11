#!/usr/bin/env bash
# scripts/load-graphs/create-ncbitaxon-void.sh
#
# Generate a VoID description for the NCBITaxon graph loaded in Virtuoso.
# The graph contains a data-driven MIREOT subset of the OBO Foundry NCBITaxon
# release, extracted with ROBOT and loaded by load-ncbitaxon.sh.
#
# The output TTL is written to db/data/void-ncbitaxon.ttl and loaded into
# Virtuoso under the graph/void named graph so it is queryable via SPARQL.
#
# Usage:
#   bash scripts/load-graphs/create-ncbitaxon-void.sh
#   bash scripts/load-graphs/create-ncbitaxon-void.sh --output /path/to/out.ttl
#   bash scripts/load-graphs/create-ncbitaxon-void.sh --no-load   # write TTL only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/config.sh"

HOST_DATA_DIR="${REPO_ROOT}/db/data"
VOID_FILE="${HOST_DATA_DIR}/void-ncbitaxon.ttl"
VOID_GRAPH="http://rdf-plantmetwiki.bioinformatics.nl/void"
NCBITAXON_GRAPH="http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon"
LOAD=true

while [ $# -gt 0 ]; do
  case "$1" in
    --output) VOID_FILE="$2"; shift 2 ;;
    --no-load) LOAD=false; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

isql() {
  docker exec -i "$VIRTUOSO_CONTAINER" \
    isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" "$@"
}

# ── Query Virtuoso for current triple count and NCBITaxon version ─────────────
echo "Querying Virtuoso for NCBITaxon graph metadata ..."

TRIPLES=$(docker exec -i "$VIRTUOSO_CONTAINER" \
  isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" \
  exec="SPARQL SELECT (COUNT(*) AS ?n) WHERE { GRAPH <${NCBITAXON_GRAPH}> { ?s ?p ?o } };" \
  2>/dev/null | grep -E '^[0-9]+' | head -1 | tr -d ' ')

# owl:versionIRI looks like: http://purl.obolibrary.org/obo/ncbitaxon/2026-05-13/ncbitaxon.owl
VERSION=$(docker exec -i "$VIRTUOSO_CONTAINER" \
  isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" \
  exec="SPARQL SELECT ?v WHERE { GRAPH <${NCBITAXON_GRAPH}> { <http://purl.obolibrary.org/obo/ncbitaxon.owl> <http://www.w3.org/2002/07/owl#versionIRI> ?v } };" \
  2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | tr -d ' \r')

TODAY=$(date +%Y-%m-%d)

SUBSET_FILE="${HOST_DATA_DIR}/ncbitaxon-plantmetwiki-subset.owl"
BYTE_SIZE=""
if [ -f "$SUBSET_FILE" ]; then
  BYTE_SIZE=$(wc -c < "$SUBSET_FILE" | tr -d ' ')
fi

echo "  Triples : ${TRIPLES:-unknown}"
echo "  Version : ${VERSION:-unknown}"
echo "  Date    : $TODAY"

# ── Write VoID TTL ─────────────────────────────────────────────────────────────
cat > "$VOID_FILE" <<EOF
@prefix void:    <http://rdfs.org/ns/void#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix pav:     <http://purl.org/pav/> .
@prefix dcat:    <http://www.w3.org/ns/dcat#> .
@prefix foaf:    <http://xmlns.com/foaf/0.1/> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .
@prefix prov:    <http://www.w3.org/ns/prov#> .
@prefix owl:     <http://www.w3.org/2002/07/owl#> .

<http://rdf-plantmetwiki.bioinformatics.nl/organization/wur-plant-sciences> a foaf:Organization ;
    foaf:name "Wageningen University & Research, Department of Plant Sciences"@en ;
    foaf:homepage <https://www.wur.nl/> .

<${NCBITAXON_GRAPH}> a void:Dataset ;
    dcterms:title "NCBITaxon MIREOT subset for PlantMetWiki"@en ;
    dcterms:description "Data-driven MIREOT subset of the OBO Foundry NCBITaxon release containing all taxa present in the PlantMetWiki taxonomy-extra graph and their complete ancestor lineages up to the ontology root. Extracted with ROBOT (https://github.com/ontodev/robot) using the MIREOT method (--method MIREOT --lower-terms taxa-seed.txt). Loaded into the local Virtuoso SPARQL endpoint as a named graph."@en ;
    dcterms:source <http://purl.obolibrary.org/obo/ncbitaxon.owl> ;
    dcterms:references <http://purl.obolibrary.org/obo/ncbitaxon.owl> ;
    void:vocabulary <http://purl.obolibrary.org/obo/NCBITaxon_> ;
    void:sparqlEndpoint <https://sparql-plantmetwiki.bioinformatics.nl/sparql> ;
    pav:createdOn "${TODAY}"^^xsd:date ;
    dcterms:modified "${TODAY}"^^xsd:date ;
    dcterms:publisher <http://rdf-plantmetwiki.bioinformatics.nl/organization/wur-plant-sciences> ;
    prov:wasGeneratedBy [
        a prov:Activity ;
        dcterms:description "ROBOT extract --method MIREOT on the full NCBITaxon release; seed taxa derived from all wp:organism triples in graph/gpml-taxonomy-extra"@en ;
        prov:used <http://purl.obolibrary.org/obo/ncbitaxon.owl>
    ] .
EOF

if [ -n "$VERSION" ] && [ "$VERSION" != "unknown" ]; then
  printf "\n<http://purl.obolibrary.org/obo/ncbitaxon.owl> a owl:Ontology ;\n    owl:versionIRI <http://purl.obolibrary.org/obo/ncbitaxon/${VERSION}/ncbitaxon.owl> .\n" >> "$VOID_FILE"
fi

if [ -n "$TRIPLES" ] && [ "$TRIPLES" != "unknown" ]; then
  echo "<${NCBITAXON_GRAPH}> void:triples ${TRIPLES} ." >> "$VOID_FILE"
fi

if [ -n "$BYTE_SIZE" ]; then
  echo "<${NCBITAXON_GRAPH}> dcat:byteSize ${BYTE_SIZE} ." >> "$VOID_FILE"
fi

echo "  ✔ Written: $VOID_FILE"

# ── Load into Virtuoso ─────────────────────────────────────────────────────────
if [ "$LOAD" = true ]; then
  FNAME="$(basename "$VOID_FILE")"
  docker cp "$VOID_FILE" "${VIRTUOSO_CONTAINER}:/tmp/${FNAME}"
  isql <<ISQL
ld_dir('/tmp', '${FNAME}', '${VOID_GRAPH}');
rdf_loader_run();
checkpoint;
SPARQL SELECT (COUNT(*) AS ?triples) WHERE { GRAPH <${VOID_GRAPH}> { ?s ?p ?o } };
quit;
ISQL
  docker exec "$VIRTUOSO_CONTAINER" rm -f "/tmp/${FNAME}"
  echo "  ✔ Loaded into <${VOID_GRAPH}>"
fi
