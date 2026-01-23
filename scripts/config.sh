#!/bin/bash
# =============================================================================
# Shared Configuration for Snorql-UI Scripts
# =============================================================================
# This file contains common configuration variables used by multiple scripts.
# Source this file from other scripts to maintain consistent defaults.
#
# Variables can be overridden in three ways (in order of precedence):
#   1. Environment variables (highest priority)
#   2. .env file in the project root (recommended - single source of truth)
#   3. Default values defined in this file
#
# Usage in other scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   [ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"
# =============================================================================

# ---------------------------------------------------------------------------
# Source .env file if it exists (same file used by Docker Compose)
# ---------------------------------------------------------------------------
# This ensures shell scripts use the same configuration as Docker Compose.
# The .env file should be in the project root directory (parent of scripts/).

_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_ROOT="$(cd "$_CONFIG_DIR/.." && pwd)"

if [ -f "$_PROJECT_ROOT/.env" ]; then
    # Export variables from .env (skip comments and empty lines)
    set -a
    source "$_PROJECT_ROOT/.env"
    set +a
fi

unset _CONFIG_DIR _PROJECT_ROOT

# ---------------------------------------------------------------------------
# Virtuoso Connection Settings
# ---------------------------------------------------------------------------

# Docker container name (must match docker-compose.yml)
export VIRTUOSO_CONTAINER="${VIRTUOSO_CONTAINER:-my-virtuoso}"

# Virtuoso host for external connections (when not using Docker exec)
export VIRTUOSO_HOST="${VIRTUOSO_HOST:-localhost}"

# Virtuoso ISQL port (internal port, typically 1111)
export VIRTUOSO_ISQL_PORT="${VIRTUOSO_ISQL_PORT:-1111}"

# Virtuoso admin credentials
export VIRTUOSO_USER="${VIRTUOSO_USER:-dba}"
export VIRTUOSO_PASSWORD="${VIRTUOSO_PASSWORD:-dba123}"

# ---------------------------------------------------------------------------
# CORS Settings
# ---------------------------------------------------------------------------

# CORS allowed origins for the /sparql endpoint
# Use '*' for development/testing or to support federated queries (SERVICE keyword)
# Use specific origin for production (e.g., "http://yourdomain.com")
export CORS_ORIGINS="${CORS_ORIGINS:-*}"

# ---------------------------------------------------------------------------
# Port Settings
# ---------------------------------------------------------------------------

# Virtuoso HTTP port (external port mapped to container's 8890)
export VIRTUOSO_HTTP_PORT="${VIRTUOSO_HTTP_PORT:-8890}"

# ---------------------------------------------------------------------------
# Snorql-UI Settings
# ---------------------------------------------------------------------------

# Docker container name (must match docker-compose.yml)
export SNORQL_CONTAINER="${SNORQL_CONTAINER:-my-snorql}"

# Snorql HTTP port (external port mapped to container's 80)
export SNORQL_PORT="${SNORQL_PORT:-8088}"

# SPARQL endpoint URL (as seen from browser)
export SNORQL_ENDPOINT="${SNORQL_ENDPOINT:-http://localhost:8890/sparql}"
