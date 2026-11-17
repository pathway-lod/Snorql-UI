## PlantMetWiki SPARQL Explorer

The SPARQL Explorer of PlantMetWiki (Plant Metabolic Pathways Wiki), and the Docker setup that
serves it in front of the PlantMetWiki Virtuoso endpoint.

**Live instance:** [plantmetwiki.bioinformatics.nl](https://plantmetwiki.bioinformatics.nl/)

**Local instance (Docker):**
- Explorer: http://localhost:8088 (or `SNORQL_PORT`)
- Virtuoso SPARQL endpoint: http://localhost:8890/sparql

## How this repository is built

The explorer itself is the shared Snorql-UI engine,
[wikipathways/Snorql-UI](https://github.com/wikipathways/Snorql-UI), published as the Docker
image `ghcr.io/wikipathways/snorql-ui`. This repository holds only what is PlantMetWiki's own,
copied on top of that image by the `Dockerfile`:

| File | What it is |
|---|---|
| `config.js` | Endpoint, examples repository, branding (logo, footer), navbar links, namespaces, autocomplete |
| `theme.css` | PlantMetWiki styling (header with title, footer) |
| `images/` | Logo and footer icons |
| `head-extra.html` | schema.org JSON-LD for FAIR assessment tools, inserted into the page's `<head>` |
| `httpd-proxy.conf` | Apache: `/sparql` to Virtuoso, service description, VoID, dereferenceable IRIs, example IRIs |
| `sd.ttl`, `vocab/pmw.ttl` | SPARQL service description and the PlantMetWiki vocabulary |
| `scripts/`, `plantmetwiki-*.sh` | Loading the PlantMetWiki data into Virtuoso |

Updating the engine is a change of its tag. With docker compose, the tag comes from
`SNORQL_ENGINE` in `.env` (default in `docker-compose.yml`), which overrides the `ENGINE` default
in the `Dockerfile`; keep the three the same. After changing it, rebuild the explorer with
`docker compose up -d --build snorql`. The engine's own documentation, including all `config.js`
options, is in its
[FORK.md](https://github.com/wikipathways/Snorql-UI/blob/master/FORK.md).

`node test/check-config.js` checks `config.js`, the images it refers to and the JSON-LD.

## SPARQL examples

The examples panel shows the queries of
[pathway-lod/SPARQLQueries](https://github.com/pathway-lod/SPARQLQueries). Each example is a
Turtle file with a permanent identifier (`PMWQ012`), a version and metadata; the explorer reads
the index that the repository's CI publishes on its `examples-index` branch. How to write one is
described in that repository's `AUTHORING.md`.

- Link to an example: `https://plantmetwiki.bioinformatics.nl/?example=PMWQ012`, or a version of
  it: `&version=1.0.0`. Old links with a file path (`?example=2.PlantMetWiki/....rq`) still work.
- Each example also has an IRI,
  `https://plantmetwiki.bioinformatics.nl/.well-known/sparql-examples/PMWQ012`: browsers are sent
  to the explorer, RDF clients asking for Turtle to the whole collection at
  `https://plantmetwiki.bioinformatics.nl/.well-known/sparql-examples` (see `httpd-proxy.conf`).

## Get a URL for a query with JavaScript

- if you want to get a URL for your query (automatically generated for example) without using the permanent link, then you can use the following JavaScript code:

```javascript
// the explorer URL followed by the query variable 'q'
let endpoint = "https://plantmetwiki.bioinformatics.nl/?q=";

// The SPARQL query itself
let sparql = `SELECT DISTINCT ?dataset (str(?titleLit) as ?title) ?date ?license
WHERE {
   ?dataset a void:Linkset ;
   dcterms:title ?titleLit .
   OPTIONAL {
	 ?dataset dcterms:license ?license ;
	   pav:createdOn ?date .
   }
}`;

// create the URL from the explorer URL and the URI-encoded query string
let encodedQueryUrl = endpoint + encodeURI(sparql);
```


## Quick Start

1. Copy the example configuration:
   ```bash
   cp .env.example .env
   ```
2. Edit `.env` if needed. Empty `SNORQL_*` values keep the PlantMetWiki settings of `config.js`;
   set `SNORQL_ENDPOINT=http://localhost:8890/sparql` to use the local Virtuoso.
3. Start the services:
   ```bash
   docker compose up -d --build
   ```
4. Open http://localhost:8088 (or whichever port you set as `SNORQL_PORT` in `.env`)

## Configuration

### Using .env Files

The easiest way to configure Snorql-UI is with a `.env` file. This file serves as the **single source of truth** for both Docker Compose and shell scripts.

```bash
# Copy the template
cp .env.example .env

# Edit with your settings
nano .env

# Verify configuration
docker compose config

# Start services
docker compose up -d
```

The `.env` file is gitignored, so your local configuration won't be committed.

**How configuration flows:**

```
.env (single source of truth)
    │
    ├── Docker Compose (reads .env automatically)
    │       └── Container environment variables
    │               └── the engine's script.sh (applies the SNORQL_* values at startup)
    │
    └── Shell scripts (via scripts/config.sh)
            └── enable-cors.sh, load-rdf-example.sh, etc.
```

Shell scripts in `scripts/` source `config.sh`, which automatically loads your `.env` file. This means you only need to edit `.env` once - both Docker Compose and shell scripts will use the same values.

### Environment Variables

All variables can be set in `.env`, exported in your shell, or hardcoded in `docker-compose.yml`.

**Snorql-UI Settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SNORQL_CONTAINER` | `my-snorql` | Docker container name |
| `SNORQL_PORT` | `8088` | HTTP port for web interface |
| `SNORQL_ENGINE` | `ghcr.io/wikipathways/snorql-ui:1.5.1` | Engine image the explorer is built on |
| `SNORQL_ENDPOINT` | (empty: `config.js`) | SPARQL endpoint URL (as seen from browser) |
| `SNORQL_EXAMPLES_REPO` | (empty: `config.js`) | GitHub repository with the example queries |
| `SNORQL_EXAMPLES_INDEX_URL` | (empty) | Base URL of the examples index, when not the repository's `examples-index` branch |
| `SNORQL_TITLE` | (empty: `config.js`) | Browser tab title |
| `DEFAULT_GRAPH` | (empty) | Default RDF graph |

**Virtuoso Settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `VIRTUOSO_CONTAINER` | `my-virtuoso` | Docker container name |
| `VIRTUOSO_HOST` | `localhost` | Hostname for external connections |
| `VIRTUOSO_HTTP_PORT` | `8890` | HTTP/SPARQL endpoint port |
| `VIRTUOSO_ISQL_PORT` | `1111` | ISQL port for data loading |
| `VIRTUOSO_USER` | `dba` | Database admin username |
| `VIRTUOSO_PASSWORD` | `dba123` | Database admin password |
| `SPARQL_UPDATE` | `false` | Allow SPARQL UPDATE queries |
| `CORS_ORIGINS` | `*` | CORS allowed origins |

### URL Parameters

`?example=PMWQ012` opens an example (see [SPARQL examples](#sparql-examples)). You can override the SPARQL endpoint via URL parameter:
```
http://localhost:8088/?endpoint=http://other-endpoint/sparql
```

This is useful for linking to the UI with a specific endpoint pre-configured.


## Docker Compose

### Commands

```bash
# Start services in background
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# View logs for specific service
docker-compose logs -f snorql

# Rebuild after code changes
docker-compose up -d --build
```

### Ports

| Port | Service |
|------|---------|
| 8088 | Snorql-UI web interface |
| 8890 | Virtuoso HTTP/SPARQL endpoint |
| 1111 | Virtuoso ISQL (for data loading) |

### Data Persistence

To persist Virtuoso data between container restarts, uncomment the volumes section in `docker-compose.yml`:

```yaml
virtuoso:
  volumes:
    - ./virtuoso-data:/database
```

Create the directory first: `mkdir virtuoso-data`


## Updating PlantMetWiki data

Use this procedure whenever a new RDF release is published on Zenodo (concept DOI `10.5281/zenodo.17967619`).

### 1. Remove old versioned TTL files

The download script skips files that already exist, so old versioned files must be deleted first. Static files that do not change between releases (`mibig.ttl`, `plantismash.ttl`, `ncbitaxon*.owl`) can be left in place.

```bash
rm db/data/all-plantcyc*.ttl
rm db/data/all_gpml_taxonomy_extra-plantcyc*.ttl
rm db/data/all_gpml_properties_extra-plantcyc*.ttl
rm db/data/void-plantcyc*.ttl
```

### 2. Download the latest release from Zenodo

The script resolves the concept DOI to the latest published record automatically. Use `--skip-bgc` to leave the BGC crosslink files untouched.

```bash
python scripts/download-plantmetwiki-data.py --skip-bgc
```

Files are written to `db/data/`. The script prints the Zenodo version and lists everything it downloaded.

### 3. Reload Virtuoso

`--clear` drops all existing PlantMetWiki named graphs before loading, so no triples from the previous release survive.

```bash
bash scripts/load-plantmetwiki-data.sh --clear
```

### 4. Verify

```bash
bash scripts/load-plantmetwiki-data.sh --check
```

This prints triple counts per named graph. Check that the numbers are plausible (core pathway graph `graph/pathways` should be a few million triples, and only one release should be present).

### 5. Refresh the vocabularies VoID

```bash
bash scripts/load-graphs/create-vocabularies-void.sh
```

See [Vocabularies](#vocabularies) below.

### Vocabularies

`load-plantmetwiki-data.sh` also runs `scripts/load-graphs/load-vocabularies.sh` (disable with `LOAD_VOCABULARIES=false`). It loads the WikiPathways `wp:`/`gpml:` vocabularies, the VoID vocabulary and the PlantMetWiki vocabulary (`vocab/pmw.ttl`) into `graph/vocabularies`, so the classes used in the data have `rdfs:label`s. It can be run on its own at any time.

After (re)loading the vocabularies, describe the graph in the VoID so `/.well-known/void` stays complete:

```bash
bash scripts/load-graphs/create-vocabularies-void.sh
```

It reads the triple count and the `pmw:` version from Virtuoso, writes `db/data/void-vocabularies.ttl`, and then runs `scripts/reload-void.sh` (clears and reloads `graph/void` from every `db/data/void-*.ttl` and republishes `/.well-known/void`). Use `--no-load` to only write the file. See [Generate VoID metadata for the vocabularies graph](#generate-void-metadata-for-the-vocabularies-graph) for what it records.

### Linked Data and VoID

- The merged VoID is published at `/.well-known/void` (served as `text/turtle`) by the load scripts; `bash scripts/reload-void.sh` republishes it.
- Resource IRIs under `http://rdf-plantmetwiki.bioinformatics.nl/` (`/pathways/`, `/Pathway/`, `/id/`, `/dataset/`, `/vocab/`, …) are dereferenceable: `httpd-proxy.conf` answers RDF requests (`Accept: text/turtle`, `application/rdf+xml`, `application/n-triples`) with the resource's triples from Virtuoso, and redirects browsers to the explorer with a query for the resource filled in.
- The PlantMetWiki vocabulary (`vocab/pmw.ttl`) is served as Turtle at its namespace URI, `/vocab/`.

---

## Customization

| Change | Where |
|---|---|
| SPARQL endpoint, examples repository, page title | `config.js` (or `SNORQL_ENDPOINT`, `SNORQL_EXAMPLES_REPO`, `SNORQL_TITLE` in `.env`) |
| Logo, footer, navbar links, meta description | `config.js` (`logo`, `footer`, `linkouts`, `metaDescription`) |
| Colours and layout | `theme.css` |
| Namespaces shown as prefixes in results | `config.js` (`namespaces`) |
| Autocomplete lists for example parameters | `config.js` (`autocompleteTypes`) |
| Structured data in the page | `head-extra.html` |
| Engine version | `SNORQL_ENGINE` in `.env` (default in `docker-compose.yml`, `ENGINE` in the `Dockerfile` for a plain `docker build`), then `docker compose up -d --build snorql` |

## Loading RDF Data

If using the included Virtuoso container, you can load RDF data using the example script:

```bash
# See scripts/load-rdf-example.sh for detailed instructions
./scripts/load-rdf-example.sh
```

Basic Virtuoso data loading via isql:
```bash
# Connect to Virtuoso container
docker exec -it my-virtuoso isql 1111 dba dba123

# Load data from URL
SPARQL LOAD <http://example.org/data.ttl> INTO GRAPH <http://example.org/graph>;
checkpoint;
quit;
```


## Enabling CORS on Virtuoso

For browser-based SPARQL queries to work, CORS (Cross-Origin Resource Sharing) must be enabled on Virtuoso's `/sparql` endpoint. Without CORS, browsers block requests from web pages (e.g., Snorql-UI at `localhost:8088`) to different origins (e.g., Virtuoso at `localhost:8890`).

### Quick Setup

After starting Virtuoso, run the CORS configuration script:

```bash
./scripts/enable-cors.sh
```

### Production Setup

For production, restrict CORS to your specific domain:

```bash
CORS_ORIGINS="http://yourdomain.com" ./scripts/enable-cors.sh
```

### Custom Configuration

The script supports these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VIRTUOSO_CONTAINER` | `my-virtuoso` | Docker container name |
| `VIRTUOSO_ISQL_PORT` | `1111` | ISQL connection port |
| `VIRTUOSO_USER` | `dba` | Database username |
| `VIRTUOSO_PASSWORD` | `dba123` | Database password |
| `CORS_ORIGINS` | `*` | Allowed origins (`*` = all) |

For persistent configuration, set variables in your `.env` file. Shell scripts automatically read this file via `scripts/config.sh`.

### Verification

Test CORS from your browser console:

```javascript
fetch('http://localhost:8890/sparql?query=SELECT+*+WHERE+{?s+?p+?o}+LIMIT+1')
  .then(r => r.text())
  .then(console.log)
```

If CORS is working, you'll see SPARQL results. If not, you'll see a CORS error.


## Adopting for Your Own SPARQL Endpoint

For an explorer of another endpoint, start from the engine: its
[FORK.md](https://github.com/wikipathways/Snorql-UI/blob/master/FORK.md) describes the same kind of
instance repository as this one (a `Dockerfile` `FROM` the engine image plus `config.js`,
`theme.css` and images). The data loading scripts here can be reused for any RDF data:

### Automated Data Loading with Quality Control

For automated/scheduled data updates, use `scripts/data-loader.sh` as a template. This script includes:

- **Download verification** - Checks each file download succeeds
- **Turtle validation** - Uses `rapper` to validate RDF syntax before loading
- **Load verification** - Confirms all files reached `ll_state = 2` (success)
- **Dry-run mode** - Validate without loading (`--dry-run`)

```bash
# Configure for your data source
export DATA_SOURCE="http://your-data-server.org/rdf"
export DATA_FILES="mydata.ttl vocabulary.ttl"
export VIRTUOSO_CONTAINER="my-virtuoso"
export VIRTUOSO_PASSWORD="dba123"
export GRAPH_URI="http://example.org/graph/"

# Run the loader
./scripts/data-loader.sh

# Or validate only (dry run)
./scripts/data-loader.sh --dry-run
```

Edit the script's CONFIGURATION section to set defaults for your deployment, then schedule with cron for automatic updates.

### Tips

- **Multiple data files:** Add multiple `ld_dir()` commands in `load.sh` or use wildcards
- **Turtle validation:** Install `raptor2-utils` (`sudo apt-get install raptor2-utils`) for syntax validation
- **Federated queries:** The template includes grants for SPARQL federation (SERVICE keyword)
- **Namespace prefixes:** Also add them to `namespaces` in `config.js` so URIs display as compact QNames in the UI


## Local Development Workflow for PlantMetWiki

A complete local stack — Snorql-UI served from your machine, with a local Virtuoso loaded with the latest PlantMetWiki RDF — is provided through three scripts in `scripts/`:

```
scripts/download-plantmetwiki-data.py   # fetch latest TTLs from Zenodo
scripts/load-plantmetwiki-data.sh       # bulk-load TTLs into local Virtuoso
scripts/enable-cors.sh                  # allow browser queries to the local Virtuoso
```

### Step 1 — Configure `.env`

Copy `.env.example` to `.env` and check that the variables match your local setup:

```bash
cp .env.example .env
```

To query the local Virtuoso, set `SNORQL_ENDPOINT` in `.env`. Left empty, it keeps the production
endpoint from `config.js`. Key values for local development:
```
SNORQL_ENDPOINT=http://localhost:8890/sparql   # local Virtuoso (empty = production endpoint)
VIRTUOSO_HTTP_PORT=8890
SNORQL_PORT=8088
```

### Step 2 — Start the local Virtuoso

```bash
docker compose up -d virtuoso
```

This pulls `openlink/virtuoso-opensource-7:7.2.11` and mounts `./db` as `/database` inside the container (so the database persists across restarts).

### Step 3 — Download the latest RDF data from Zenodo

```bash
python scripts/download-plantmetwiki-data.py
```

The script resolves two Zenodo concept DOIs and downloads to `db/data/`:

| Source | Concept DOI | Files |
|---|---|---|
| Pathway RDF (`gpml-to-rdf`) | `10.5281/zenodo.17967619` | `all-*.ttl.gz`, `all_gpml_taxonomy_extra-*.ttl.gz`, `all_gpml_properties_extra-*.ttl.gz`, `void-*.ttl` |
| BGC crosslink RDF (`map-to-rdf`) | GitHub release `bgc-v1.0` | `plantismash.ttl`, `mibig.ttl`, `void-bgc.ttl` |

`.gz` files are decompressed automatically; existing files in `db/data/` are skipped.

### Step 4 — Load the data into Virtuoso

```bash
bash scripts/load-plantmetwiki-data.sh
```

The script copies each TTL to `/tmp` inside the container (always allowed by Virtuoso's `DirsAllowed`), runs `ld_dir()` + `rdf_loader_run()`, then prints a graph summary. Loading order goes small-to-large so the 300 MB core bundle is loaded last.

Named graphs created:

| TTL file | Named graph |
|---|---|
| `all-*.ttl` | `http://rdf-plantmetwiki.bioinformatics.nl/graph/pathways` |
| `all_gpml_taxonomy_extra-*.ttl` | `…/graph/gpml-taxonomy-extra` |
| `all_gpml_properties_extra-*.ttl` | `…/graph/gpml-properties-extra` |
| `ncbi_iri_mappings-*.ttl` | `…/graph/ncbi-iri-mappings` |
| `plantismash.ttl` | `…/graph/bgc-plantismash` |
| `mibig.ttl` | `…/graph/bgc-mibig` |
| `void-*.ttl` (both) | `…/void` |

Flags:
- `--clear` — drop all graphs before loading (use when re-loading a fresh build)
- `--check` — just print current graph triple counts

### Step 5 — Enable CORS on the local Virtuoso

```bash
set -a; source .env; set +a
bash scripts/enable-cors.sh
```

This is mandatory: without CORS, the browser blocks SPARQL requests from `localhost:8088` to `localhost:8890`. The default config (`CORS_ORIGINS=*`) accepts requests from any origin — fine for local dev, restrict in production.

### Step 6 — Start the explorer locally

```bash
docker compose up -d --build snorql
```

Then open **http://localhost:8088/**. With `SNORQL_ENDPOINT=http://localhost:8890/sparql` in `.env`
the explorer queries your local Virtuoso; with the variable empty it uses the production endpoint
from `config.js`. After changing `.env`, run the same command again, then
`bash scripts/reload-void.sh` to put `/.well-known/void` back (it lives in the container, not in the image).

### Refreshing the data after a new release

When `gpml-to-rdf` or `map-to-rdf` publishes a new Zenodo version:

```bash
rm db/data/*.ttl                                       # clear old files
python scripts/download-plantmetwiki-data.py           # fetch latest
bash scripts/load-plantmetwiki-data.sh --clear         # rebuild graphs in Virtuoso
```

### Optional: load the NCBITaxon ontology

To resolve NCBI Taxonomy URIs (`NCBITaxon_<id>`) locally — for label lookups and reasoning without a federated query to BioPortal — load the OBO Foundry release of NCBITaxon into a dedicated graph.

We use OBO Foundry rather than BioPortal because the **OBO version is CC0** (public domain), while BioPortal mirrors are not freely redistributable.

#### Recommended: data-driven MIREOT subset (`--subset plantmetwiki`)

This option extracts only the taxa actually present in the PlantMetWiki taxonomy-extra graph plus their complete ancestor lineages using [ROBOT](https://github.com/ontodev/robot)'s MIREOT method. The result is ~1.4 MB / 17,707 triples instead of the 1.8 GB full release.

**Prerequisite:** download `robot.jar` from the [ROBOT releases page](https://github.com/ontodev/robot/releases) and place it at `db/robot.jar` (gitignored). Java 11+ is required (the conda `plantmetwiki-rdf` environment provides this).

```bash
# Download robot.jar (one-time setup):
curl -L -o db/robot.jar https://github.com/ontodev/robot/releases/download/v1.9.6/robot.jar

# Extract subset and load into Virtuoso:
bash scripts/load-graphs/load-ncbitaxon.sh --subset plantmetwiki
```

The script automatically uses `db/robot.jar` if present, falling back to the `obolibrary/robot` Docker image only if the JAR is not found. Override with `ROBOT_JAR=/path/to/robot.jar` or `ROBOT_HEAP=4g` if needed.

> **Note:** The Docker fallback can fail with out-of-memory errors when Virtuoso is also running, because Docker's memory cap may be insufficient for the ROBOT JVM. The local JAR approach uses system RAM and is more reliable.

#### Other variants

```bash
# Full release (~1.8 GB, 21.7 M triples — full label and hierarchy coverage):
bash scripts/load-graphs/load-ncbitaxon.sh

# OBO slim subset (~38 MB — labels for major taxa only):
bash scripts/load-graphs/load-ncbitaxon.sh --subset taxslim
bash scripts/load-graphs/load-ncbitaxon.sh --subset taxslim-disjoint

# Check what's currently loaded:
bash scripts/load-graphs/load-ncbitaxon.sh --check
```

Or load NCBITaxon together with the rest of the data:

```bash
LOAD_NCBITAXON=true bash scripts/load-plantmetwiki-data.sh
LOAD_NCBITAXON=true NCBITAXON_SUBSET=plantmetwiki bash scripts/load-plantmetwiki-data.sh
```

The ontology is loaded into:
```
http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon
```

#### Generate VoID metadata for the NCBITaxon graph

After loading, generate machine-readable provenance (VoID + PROV-O) that records the triple count, ontology version, subset method, and ROBOT tooling:

```bash
bash scripts/load-graphs/create-ncbitaxon-void.sh
```

This writes `db/data/void-ncbitaxon.ttl` and loads it into the `graph/void` named graph. Re-run whenever the NCBITaxon graph is reloaded. The TTL records:
- `dcterms:source` / `dcterms:references` → OBO Foundry `ncbitaxon.owl`
- `void:vocabulary` → NCBITaxon IRI namespace (`purl.obolibrary.org/obo/NCBITaxon_`)
- `owl:versionIRI` → the loaded release date (e.g. `2026-05-13`)
- `void:triples` → live count queried from Virtuoso
- `prov:wasGeneratedBy` → ROBOT MIREOT activity with `prov:used` source ontology

#### Generate VoID metadata for the vocabularies graph

The vocabularies graph gets the same treatment, so every named graph on the endpoint has a
machine-readable provenance record:

```bash
bash scripts/load-graphs/create-vocabularies-void.sh
```

This writes `db/data/void-vocabularies.ttl` and then runs `scripts/reload-void.sh`, which clears and
reloads the `graph/void` named graph from every `db/data/void-*.ttl` and republishes `/.well-known/void`.
Run it after `load-vocabularies.sh` (it reads the live triple count and `pmw:` version), and re-run
whenever `load-vocabularies.sh` is re-run. The TTL records:
- `dcterms:source` → the four inputs: `wp.owl`, `gpml.owl`, the VoID vocabulary, and `vocab/pmw.ttl`
- `void:vocabulary` → the `wp:`, `gpml:`, `void:` and `pmw:` namespaces
- `owl:versionInfo` → the `pmw:` vocabulary version, queried live from the graph
- `void:triples` → live count queried from Virtuoso
- `dcat:byteSize` → size of `vocab/pmw.ttl`
- `prov:wasGeneratedBy` → `load-vocabularies.sh` activity with `prov:used` on all four inputs

#### Verify the loaded graph

Label lookup:

```sparql
PREFIX ncbi: <http://purl.obolibrary.org/obo/NCBITaxon_>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?label WHERE {
  GRAPH <http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon> {
    ncbi:33090 rdfs:label ?label .
  }
}
```

Cross-graph join (pathway taxa → NCBI labels):

```sparql
PREFIX wp:   <http://vocabularies.wikipathways.org/wp#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?taxon ?label (COUNT(DISTINCT ?pwy) AS ?n)
WHERE {
  GRAPH <http://rdf-plantmetwiki.bioinformatics.nl/graph/gpml-taxonomy-extra> {
    ?pwy wp:organism ?taxon .
  }
  GRAPH <http://rdf-plantmetwiki.bioinformatics.nl/graph/ncbitaxon> {
    ?taxon rdfs:label ?label .
  }
}
GROUP BY ?taxon ?label
ORDER BY DESC(?n)
```

| Variant | Triples | Size | Recommended for |
|---|---|---|---|
| `plantmetwiki` ⭐ | ~17,700 | ~1.4 MB | PlantMetWiki — only taxa in the dataset + ancestors |
| `taxslim` | ~500 K | ~38 MB | Local dev — labels for major taxa |
| `taxslim-disjoint` | ~500 K + axioms | ~38 MB | Reasoning experiments |
| `full` | ~21.7 M | ~1.8 GB | Full label and hierarchy coverage |

### Legacy data loading (kept for compatibility)

The older start-and-load scripts are still present:

```bash
./plantmetwiki-rebuild.sh       # starts the stack and enables CORS (does not rebuild the snorql image)
./plantmetwiki-upload-data.sh   # loads data using the old loader
```

The script-based workflow above is recommended instead.

## Deploying Production Hostnames for PlantMetWiki

Public UI:
`https://plantmetwiki.bioinformatics.nl` → container port 8088

Public SPARQL endpoint:
`https://plantmetwiki.bioinformatics.nl/sparql` → container port 8890

After a change to the engine tag (`SNORQL_ENGINE`) or to a file that the `Dockerfile` copies into
the image (`config.js`, `theme.css`, `images/`, `head-extra.html`, `httpd-proxy.conf`, `sd.ttl`,
`vocab/pmw.ttl`), rebuild and restart the explorer:

```bash
docker compose up -d --build snorql
bash scripts/reload-void.sh   # republish /.well-known/void, which lives in the container
```

The rebuild recreates the snorql container, and the merged VoID at `/.well-known/void` is not part of
the image, so it returns 404 until `reload-void.sh` copies it back in.

`./plantmetwiki-rebuild.sh up` runs `docker compose up -d` without `--build`, so on its own it keeps
the existing snorql image and does not pick up such changes.

##  Changing the ports to the exposed ones for the URL 
Port summary: change them in the .env file 
```bash
8890 → VIRTUOSO_HTTP_PORT : Virtuoso UI + SPARQL       (http://localhost:8890/sparql) 
8088 → SNORQL_PORT : SNORQL user interface      (http://localhost:8088/)
```

