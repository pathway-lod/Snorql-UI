#!/bin/bash
# =============================================================================
# Virtuoso RDF Data Loading Example Script
# =============================================================================
# This script demonstrates how to load RDF data into a Virtuoso instance.
# Customize the variables below for your specific use case.
#
# Prerequisites:
#   - Virtuoso container running (see docker-compose.example.yml)
#   - isql-v command available (installed with Virtuoso client tools)
#     OR use docker exec to run isql inside the container
#
# Usage:
#   1. Copy this script and customize the variables
#   2. Make it executable: chmod +x load-rdf-example.sh
#   3. Run: ./load-rdf-example.sh
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Source shared configuration if available (provides defaults for
# VIRTUOSO_CONTAINER, VIRTUOSO_HOST, VIRTUOSO_ISQL_PORT, VIRTUOSO_USER,
# VIRTUOSO_PASSWORD). Override any value via environment variables.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"

# Fallback defaults if config.sh not found
VIRTUOSO_HOST="${VIRTUOSO_HOST:-localhost}"
VIRTUOSO_ISQL_PORT="${VIRTUOSO_ISQL_PORT:-1111}"
VIRTUOSO_USER="${VIRTUOSO_USER:-dba}"
VIRTUOSO_PASSWORD="${VIRTUOSO_PASSWORD:-dba123}"
VIRTUOSO_CONTAINER="${VIRTUOSO_CONTAINER:-my-virtuoso}"

# ---------------------------------------------------------------------------
# Script-Specific Configuration - Customize these for your data
# ---------------------------------------------------------------------------

# RDF data source (URL or local file path accessible to Virtuoso)
# For URLs, Virtuoso will fetch the data directly
# For local files, they must be in Virtuoso's allowed directories
RDF_DATA_URL="http://example.org/data.ttl"
# Or use a local file (must be accessible from within the container):
# RDF_DATA_FILE="/database/data.ttl"

# Target graph URI for the loaded data
GRAPH_URI="http://example.org/my-graph"

# RDF format: auto, ttl, rdf, n3, nq, etc.
RDF_FORMAT="auto"

# ---------------------------------------------------------------------------
# Loading Methods
# ---------------------------------------------------------------------------

# Method 1: Load from URL using SPARQL LOAD (requires SPARQL_UPDATE=true)
load_from_url() {
    echo "Loading RDF data from URL: $RDF_DATA_URL"
    echo "Target graph: $GRAPH_URI"

    docker exec -i "$VIRTUOSO_CONTAINER" isql "$VIRTUOSO_ISQL_PORT" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" <<EOF
SPARQL LOAD <$RDF_DATA_URL> INTO GRAPH <$GRAPH_URI>;
checkpoint;
quit;
EOF
}

# Method 2: Load local file using Virtuoso's bulk loader
# Files must be in DirsAllowed (typically /database or /opt/virtuoso-opensource/vad)
load_local_file() {
    local file_path="$1"
    local graph="$2"

    echo "Loading local file: $file_path"
    echo "Target graph: $graph"

    docker exec -i "$VIRTUOSO_CONTAINER" isql "$VIRTUOSO_ISQL_PORT" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" <<EOF
-- Register file for bulk loading
ld_dir('/database', '$(basename "$file_path")', '$graph');

-- Execute the bulk loader
rdf_loader_run();

-- Checkpoint to persist changes
checkpoint;

-- Show loading status
SELECT * FROM DB.DBA.LOAD_LIST;
quit;
EOF
}

# Method 3: Clear a graph before loading (useful for updates)
clear_graph() {
    local graph="$1"
    echo "Clearing graph: $graph"

    docker exec -i "$VIRTUOSO_CONTAINER" isql "$VIRTUOSO_ISQL_PORT" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" <<EOF
SPARQL CLEAR GRAPH <$graph>;
checkpoint;
quit;
EOF
}

# Method 4: Check loaded graphs and triple counts
check_graphs() {
    echo "Listing graphs and triple counts..."

    docker exec -i "$VIRTUOSO_CONTAINER" isql "$VIRTUOSO_ISQL_PORT" "$VIRTUOSO_USER" "$VIRTUOSO_PASSWORD" <<EOF
SPARQL SELECT ?g (COUNT(*) as ?triples) WHERE { GRAPH ?g { ?s ?p ?o } } GROUP BY ?g ORDER BY DESC(?triples);
quit;
EOF
}

# ---------------------------------------------------------------------------
# Main Script
# ---------------------------------------------------------------------------

echo "============================================"
echo "Virtuoso RDF Data Loading Script"
echo "============================================"
echo ""
echo "This is an example script. Uncomment the function"
echo "call below that matches your use case."
echo ""

# Uncomment ONE of the following to run:

# Load from URL:
# load_from_url

# Load local file (copy file to virtuoso-data/ first):
# load_local_file "/database/mydata.ttl" "$GRAPH_URI"

# Clear a graph before reloading:
# clear_graph "$GRAPH_URI"

# Check current graphs:
# check_graphs

echo ""
echo "Edit this script and uncomment the appropriate function call."
echo "See comments above for usage instructions."
