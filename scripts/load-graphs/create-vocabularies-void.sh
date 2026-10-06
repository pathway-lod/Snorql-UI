#!/usr/bin/env bash
# scripts/load-graphs/create-vocabularies-void.sh
#
# Generate a VoID description for the vocabularies graph loaded in Virtuoso.
# The graph holds the term definitions for every vocabulary PlantMetWiki uses
# or defines, loaded by load-vocabularies.sh:
#   wp.ttl    WikiPathways vocabulary  (https://vocabularies.wikipathways.org/wp.owl)
#   gpml.ttl  GPML vocabulary          (https://vocabularies.wikipathways.org/gpml.owl)
#   void.ttl  VoID vocabulary          (https://github.com/cygri/void)
#   pmw.ttl   PlantMetWiki vocabulary  (vocab/pmw.ttl in this repository)
#
# The output TTL is written to db/data/void-vocabularies.ttl and loaded into
# Virtuoso under the graph/void named graph so it is queryable via SPARQL.
#
# Usage:
#   bash scripts/load-graphs/create-vocabularies-void.sh
#   bash scripts/load-graphs/create-vocabularies-void.sh --output /path/to/out.ttl
#   bash scripts/load-graphs/create-vocabularies-void.sh --no-load   # write TTL only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/config.sh"

HOST_DATA_DIR="${REPO_ROOT}/db/data"
VOID_FILE="${HOST_DATA_DIR}/void-vocabularies.ttl"
VOID_GRAPH="http://rdf-plantmetwiki.bioinformatics.nl/void"
VOCAB_GRAPH="${VOCAB_GRAPH_URI:-http://rdf-plantmetwiki.bioinformatics.nl/graph/vocabularies}"
PMW_VOCAB="http://rdf-plantmetwiki.bioinformatics.nl/vocab/"
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

# ── Query Virtuoso for current triple count and the pmw: vocabulary version ────
echo "Querying Virtuoso for vocabularies graph metadata ..."

TRIPLES=$(docker exec -i "$VIRTUOSO_CONTAINER" \
  isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" \
  exec="SPARQL SELECT (COUNT(*) AS ?n) WHERE { GRAPH <${VOCAB_GRAPH}> { ?s ?p ?o } };" \
  2>/dev/null | grep -E '^[0-9]+' | head -1 | tr -d ' ')

PMW_VERSION=$(docker exec -i "$VIRTUOSO_CONTAINER" \
  isql "${VIRTUOSO_ISQL_PORT:-1111}" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" \
  exec="SPARQL SELECT ?v WHERE { GRAPH <${VOCAB_GRAPH}> { <${PMW_VOCAB}> <http://www.w3.org/2002/07/owl#versionInfo> ?v } };" \
  2>/dev/null | grep -E '^[0-9]' | head -1 | tr -d ' \r')

TODAY=$(date +%Y-%m-%d)

PMW_FILE="${REPO_ROOT}/vocab/pmw.ttl"
BYTE_SIZE=""
if [ -f "$PMW_FILE" ]; then
  BYTE_SIZE=$(wc -c < "$PMW_FILE" | tr -d ' ')
fi

echo "  Triples     : ${TRIPLES:-unknown}"
echo "  pmw version : ${PMW_VERSION:-unknown}"
echo "  Date        : $TODAY"

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

<${VOCAB_GRAPH}> a void:Dataset ;
    dcterms:title "Vocabulary definitions for PlantMetWiki"@en ;
    dcterms:description "Machine-readable term definitions for every vocabulary PlantMetWiki uses or defines, so that the data model is resolvable from the SPARQL endpoint itself. Contains the WikiPathways wp: and gpml: vocabularies as SKOS concept schemes, the VoID vocabulary, and the PlantMetWiki vocabulary (pmw:), which defines the terms this resource introduces for information the WikiPathways vocabularies do not cover: biosynthetic gene cluster membership and the PlantCyc/GPML key-value property layer. Loaded by scripts/load-graphs/load-vocabularies.sh."@en ;
    dcterms:source <https://vocabularies.wikipathways.org/wp.owl> ,
                   <https://vocabularies.wikipathways.org/gpml.owl> ,
                   <https://github.com/cygri/void> ,
                   <${PMW_VOCAB}> ;
    void:vocabulary <http://vocabularies.wikipathways.org/wp#> ,
                    <http://vocabularies.wikipathways.org/gpml#> ,
                    <http://rdfs.org/ns/void#> ,
                    <${PMW_VOCAB}> ;
    void:sparqlEndpoint <https://plantmetwiki.bioinformatics.nl/sparql> ;
    dcterms:license <https://creativecommons.org/publicdomain/zero/1.0/> ;
    pav:createdOn "${TODAY}"^^xsd:date ;
    dcterms:modified "${TODAY}"^^xsd:date ;
    dcterms:publisher <http://rdf-plantmetwiki.bioinformatics.nl/organization/wur-plant-sciences> ;
    prov:wasGeneratedBy [
        a prov:Activity ;
        dcterms:description "load-vocabularies.sh: fetch the wp:, gpml: and VoID vocabularies from their canonical URLs, add vocab/pmw.ttl from this repository, and bulk-load all four into the vocabularies named graph"@en ;
        prov:used <https://vocabularies.wikipathways.org/wp.owl> ,
                  <https://vocabularies.wikipathways.org/gpml.owl> ,
                  <https://github.com/cygri/void> ,
                  <${PMW_VOCAB}>
    ] .
EOF

if [ -n "$PMW_VERSION" ] && [ "$PMW_VERSION" != "unknown" ]; then
  printf "\n<${PMW_VOCAB}> a owl:Ontology ;\n    owl:versionInfo \"${PMW_VERSION}\" .\n" >> "$VOID_FILE"
fi

if [ -n "$TRIPLES" ] && [ "$TRIPLES" != "unknown" ]; then
  echo "<${VOCAB_GRAPH}> void:triples ${TRIPLES} ." >> "$VOID_FILE"
fi

if [ -n "$BYTE_SIZE" ]; then
  echo "<${PMW_VOCAB}> dcat:byteSize ${BYTE_SIZE} ." >> "$VOID_FILE"
fi

echo "  ✔ Written: $VOID_FILE"

# ── Load into Virtuoso ─────────────────────────────────────────────────────────
# Delegate to reload-void.sh: it clears <graph/void> and reloads every
# void-*.ttl, then republishes /.well-known/void. Loading only this file would
# append to the graph (leaving the previous run's dcterms:modified and
# void:triples next to the new ones) and would not update /.well-known/void.
if [ "$LOAD" = true ]; then
  if [ "$VOID_FILE" != "${HOST_DATA_DIR}/void-vocabularies.ttl" ]; then
    echo "  [SKIP] --output is outside db/data/void-*.ttl; not loading. Copy it there and run scripts/reload-void.sh."
  else
    bash "${REPO_ROOT}/scripts/reload-void.sh"
    echo "  ✔ Loaded into <${VOID_GRAPH}>"
  fi
fi
