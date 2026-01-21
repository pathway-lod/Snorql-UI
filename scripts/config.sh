#!/bin/bash
# =============================================================================
# Shared Configuration for Snorql-UI Scripts
# =============================================================================
# This file contains common configuration variables used by multiple scripts.
# Source this file from other scripts to maintain consistent defaults.
#
# Variables can be overridden in three ways (in order of precedence):
#   1. Environment variables (highest priority)
#   2. Values set in this file
#   3. Built-in defaults in individual scripts (if config.sh not found)
#
# Usage in other scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   [ -f "$SCRIPT_DIR/config.sh" ] && source "$SCRIPT_DIR/config.sh"
# =============================================================================

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
