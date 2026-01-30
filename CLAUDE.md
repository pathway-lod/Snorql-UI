# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Snorql-UI for PlantMetWiki (Plant Metabolic Pathways Wiki) - a modern web-based SPARQL query interface. This is a fork of [wikipathways/Snorql-UI](https://github.com/wikipathways/Snorql-UI) customized for the PlantMetWiki project.

**Live Instance:** [sparql-plantmetwiki.bioinformatics.nl](https://sparql-plantmetwiki.bioinformatics.nl/)

This is a pure frontend application (no backend) built with HTML5, CSS3, jQuery, and Bootstrap 3. The UI includes a CodeMirror-based SPARQL editor with syntax highlighting and fetches query examples from GitHub repositories.

## Development & Deployment

### Local Development
No build system exists - this is static HTML/CSS/JS. Open `index.html` directly in a browser or serve via any HTTP server.

### Docker Deployment
```bash
# Set up configuration
cp docker-compose.example.yml docker-compose.yml
cp .env.example .env
# Edit .env with your settings

# Start services
docker compose up -d
```

Services exposed (default ports):
- Snorql UI: http://localhost:8088
- Virtuoso SPARQL endpoint: http://localhost:8890/sparql

### Configuration

The `.env` file is the **single source of truth** for all configuration:

```
.env
 ├── Docker Compose (reads automatically)
 │     └── Container env vars → script.sh
 └── Shell scripts (via scripts/config.sh)
       └── enable-cors.sh, load-rdf-example.sh
```

**Key variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `SNORQL_ENDPOINT` | `http://localhost:8890/sparql` | SPARQL endpoint URL |
| `SNORQL_EXAMPLES_REPO` | - | GitHub repo with .rq files |
| `SNORQL_TITLE` | `My SPARQL Explorer` | Browser tab title |
| `VIRTUOSO_PASSWORD` | `dba123` | Virtuoso admin password |
| `VIRTUOSO_HTTP_PORT` | `8890` | Virtuoso HTTP port |
| `SNORQL_PORT` | `8088` | Snorql UI port |

See `.env.example` for all available variables.

Configuration is injected at container startup via `script.sh` which uses sed to modify `snorql.js` and `index.html`.

## Architecture

### Key Files

| File | Purpose |
|------|---------|
| `.env.example` | Template for all configuration variables |
| `docker-compose.example.yml` | Docker Compose template with variable substitution |
| `scripts/config.sh` | Shared config for shell scripts (sources .env) |
| `scripts/data-loader.sh` | Generic RDF loader with validation (template for custom loaders) |
| `scripts/load.sh.template` | Virtuoso bulk load script template |
| `script.sh` | Docker entrypoint - injects config via sed |
| `assets/js/snorql.js` | Core logic: SPARQL execution, result rendering, GitHub example fetching |
| `assets/js/script.js` | jQuery event handlers: query button, export, fullscreen, permalink |
| `assets/js/sparql.js` | SPARQL protocol implementation and JSON result transformation |
| `assets/js/namespaces.js` | RDF namespace prefix definitions (rdf, rdfs, owl, wikidata, etc.) |

### PlantMetWiki Customizations

This fork includes PlantMetWiki-specific branding:
- Custom logo: `assets/images/plantmetwiki-logo.png`
- Custom CSS styling for PlantMetWiki brand colors
- Tutorial link to PlantMetWiki SPARQL tutorials
- Footer with PlantCyc/PMN attribution
- Default examples repo: `https://github.com/pathway-lod/SPARQLQueries`

### Data Flow

1. User enters SPARQL query in CodeMirror editor
2. `script.js` handles button click, calls `doQuery()` from `snorql.js`
3. `sparql.js` SPARQL.Service sends GET request to configured endpoint
4. Results rendered as HTML table with special handling for:
   - SVG images (embedded in table cells)
   - SMILES chemical structures (rendered via CDKDepict service)
   - URIs (converted to clickable QNames using namespace prefixes)

### GitHub Examples Integration

The examples panel fetches `.rq` files from any GitHub repository using the GitHub API:
- Standard repos: `https://github.com/owner/repo`
- Nested folders: `https://api.github.com/repos/owner/repo/contents/folder`

Tree structure built from GitHub API response, displayed via bootstrap-treeview plugin.

### Cookie Persistence
- `endpoint`: Stores user's custom SPARQL endpoint
- `examplesrepo`: Stores user's custom examples repository
- `cookieDecision`: Tracks GDPR cookie consent

## External Dependencies (CDN/bundled)

- jQuery 3.x
- Bootstrap 3.3
- CodeMirror (with SPARQL mode, fullscreen addon)
- bootstrap-treeview
- Bitly API for permalink shortening

## Customization Quick Reference

| Change | File | Variable/Location |
|--------|------|-------------------|
| SPARQL endpoint | `.env` | `SNORQL_ENDPOINT` |
| Examples repo | `.env` | `SNORQL_EXAMPLES_REPO` |
| Page title | `.env` | `SNORQL_TITLE` |
| Ports | `.env` | `SNORQL_PORT`, `VIRTUOSO_HTTP_PORT` |
| Virtuoso password | `.env` | `VIRTUOSO_PASSWORD` |
| Logo | `assets/images/` | Replace image files |
| Footer | `index.html` | Edit `<footer>` section |
| Namespaces | `assets/js/namespaces.js` | `snorql_namespacePrefixes` |
| Bitly token | `assets/js/script.js` | `accessToken` (line 180) |
| Default graph | `.env` | `DEFAULT_GRAPH` |

## Syncing with Upstream

This fork is based on [wikipathways/Snorql-UI](https://github.com/wikipathways/Snorql-UI). To sync with upstream:

```bash
git remote add upstream https://github.com/wikipathways/Snorql-UI.git
git fetch upstream
git merge upstream/master
```

Resolve conflicts by keeping PlantMetWiki branding in `index.html` while accepting new features from upstream.

## Git Commit Guidelines

- Do NOT include "Co-Authored-By: Claude" or any Claude/AI attribution in commit messages
- Do NOT mention Claude or AI assistance in any content pushed to GitHub
