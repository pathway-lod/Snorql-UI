// PlantMetWiki SPARQL Explorer: configuration of the shared Snorql-UI engine
// (wikipathways/Snorql-UI). The engine reads window.SNORQL_CONFIG; see FORK.md there.
// script.sh rewrites endpoint, examplesRepo, title, ... from environment variables at
// container start, so keep those keys on one line each.
window.SNORQL_CONFIG = {
    endpoint: "https://plantmetwiki.bioinformatics.nl/sparql",
    examplesRepo: "https://github.com/pathway-lod/SPARQLQueries",
    examplesBranch: "master",
    // Where the examples come from:
    //   "index" - the published index of .ttl examples (index.json on the examples-index
    //             branch of examplesRepo, built by tools/examples); examples have permanent
    //             identifiers (?example=WPQ036), versions and metadata. When the repository
    //             has no index yet, the .rq files are listed instead.
    //   "rq"    - .rq files with comment headers in examplesRepo (the default).
    examplesFormat: "index",
    // Base URL of the published index when it is not the examples-index branch of
    // examplesRepo (e.g. a local copy for development). Empty: use that branch.
    examplesIndexUrl: "",
    defaultGraph: "",
    title: "PlantMetWiki SPARQL Explorer",
    poweredByLink: "https://github.com/wikipathways/Snorql-UI",
    poweredByLabel: "Snorql",
    showLiteralType: false,
    renderers: {
        enableSVGRenderer: false,
        enableSMILESRenderer: false
    },
    // Optional navbar linkout buttons, rendered in array order by linkouts.js.
    // Keep the live default EMPTY so existing deployments render unchanged.
    // Each entry: { label, url, authors?, icon? }
    //   label   - button text (shown as plain text; HTML is escaped)
    //   url     - http/https/mailto only; other schemes (javascript:/data:) are rejected
    //   authors - optional; used as the accessible name (aria-label/title) when present
    //   icon    - optional Bootstrap-3 glyphicon suffix, e.g. "book" -> glyphicon-book
    //             (allowlisted to [a-z0-9-]; invalid suffixes are dropped)
    // SECURITY: this array is untrusted input — do not remove the escaping or
    // the URL scheme allowlist in assets/js/linkouts.js. See FORK.md.
    // Example:
    //   linkouts: [
    //     { label: "Tutorial", url: "https://example.org/tutorial", icon: "book" },
    //     { label: "Credits",  url: "https://example.org/about", authors: "Jane Doe et al." }
    //   ],
    linkouts: [
        { label: "Tutorial", url: "https://pathway-lod.github.io/SPARQLTutorials/", icon: "book" },
        { label: "Paper", url: "https://doi.org/10.64898/2026.07.22.733699", icon: "file",
          authors: "Read the PlantMetWiki preprint on bioRxiv" }
    ],
    // WikiPathways label for the endpoint field; index.html keeps the generic default.
    endpointLabel: "SPARQL Endpoint:",
    logo: { src: "assets/images/plantmetwiki-logo.png", alt: "PlantMetWiki", height: 90 },
    metaDescription: "SPARQL Explorer for PlantMetWiki, a FAIR knowledge graph of plant metabolic pathways",
    metaAuthor: "Elena Del Pup",
    footer: [
        [
            { image: "https://mirrors.creativecommons.org/presskit/icons/zero.svg", alt: "CC0", height: 22,
              url: "http://creativecommons.org/publicdomain/zero/1.0", title: "Explorer licensed under CC0 1.0 (public domain)" },
            " ",
            { image: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png", alt: "GitHub", height: 22,
              url: "https://github.com/pathway-lod/Snorql-UI", title: "PlantMetWiki on GitHub" },
            " ",
            { image: "assets/images/zenodo-icon-black.svg", alt: "Zenodo", height: 22,
              url: "https://zenodo.org/communities/plantmetwiki/records?q=&l=list&p=1&s=10", title: "PlantMetWiki community on Zenodo" },
            " ",
            { image: "assets/images/yummydata-logo.png", alt: "YummyData", height: 22,
              url: "https://yummydata.org/endpoint/182", title: "Check PlantMetWiki's SPARQL endpoint score on YummyData" },
            " ",
            { image: "assets/images/fair-checker-logo.png", alt: "FAIR-Checker", height: 20,
              url: "https://fair-checker.france-bioinformatique.fr/check",
              title: "Assess PlantMetWiki with FAIR-Checker: paste https://plantmetwiki.bioinformatics.nl/ and run the check" },
            " Please cite: Del Pup et al., bioRxiv 2026, ",
            { label: "doi:10.64898/2026.07.22.733699", url: "https://doi.org/10.64898/2026.07.22.733699" }
        ],
        [
            "Powered by ", { label: "WikiPathways", url: "https://wikipathways.org/" },
            " (doi:", { label: "10.1093/nar/gkad960", url: "https://doi.org/10.1093/nar/gkad960" }, ") and ",
            { label: "Snorql", url: "https://github.com/wikipathways/Snorql-UI" },
            ". Includes modified data derived from the ", { label: "PlantCyc / PMN databases", url: "https://plantcyc.org" },
            ", \u00a9 Carnegie Institution for Science, under the ",
            { label: "PMN Open Database License", url: "https://plantcyc.org/?webform=license-agreement" }, "."
        ]
    ],
    // Optional branding (applied by assets/js/branding.js). Leave a key out to
    // keep the markup in index.html. Text is set as plain text and URLs are
    // allowlisted; there is no raw-HTML option. Colours go in assets/css/theme.css.
    // Example:
    //   logo: { src: "assets/images/my-logo.png", alt: "My SPARQL", height: 50 },
    //   favicon: "assets/images/my-favicon.png",
    //   endpointLabel: "SPARQL Endpoint",
    //   metaDescription: "Explore my data with SPARQL",
    //   metaAuthor: "My Team",
    //   footer: [
    //     { label: "My project", url: "https://example.org" }, " | ",
    //     { label: "Source", url: "https://github.com/me/my-snorql" },
    //     " | Data: ", { label: "CC-BY 4.0", url: "https://creativecommons.org/licenses/by/4.0/", title: "Data licence" },
    //     " ", { image: "assets/images/partner.png", url: "https://example.org", alt: "Partner", height: 25 }
    //   ],
    namespaces: {
        rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        owl: "http://www.w3.org/2002/07/owl#",
        xsd: "http://www.w3.org/2001/XMLSchema#",
        dc: "http://purl.org/dc/elements/1.1/",
        dcterms: "http://purl.org/dc/terms/",
        foaf: "http://xmlns.com/foaf/0.1/",
        wp: "http://vocabularies.wikipathways.org/wp#",
        gpml: "http://vocabularies.wikipathways.org/gpml#",
        pmw: "http://rdf-plantmetwiki.bioinformatics.nl/pathways/",
        v: "http://rdf-plantmetwiki.bioinformatics.nl/vocab/",
        ncbi: "http://purl.obolibrary.org/obo/NCBITaxon_"
    },
    autocompleteTypes: {
        pathway: {
            sparql: 'PREFIX dcterms: <http://purl.org/dc/terms/>\n' +
                'PREFIX dc: <http://purl.org/dc/elements/1.1/>\n' +
                'PREFIX wp: <http://vocabularies.wikipathways.org/wp#>\n' +
                'SELECT DISTINCT (str(?pcId) AS ?id) (str(?title) AS ?name) WHERE {\n' +
                '  ?pw a wp:Pathway ; dcterms:identifier ?pcId ; dc:title ?title .\n' +
                '  FILTER(STRSTARTS(STR(?pcId), \"PC\"))\n' +
                '} ORDER BY ?pcId',
            valueField: 'id',
            labelField: 'name',
            placeholder: 'Type pathway ID or name...'
        },
        species: {
            sparql: 'PREFIX wp: <http://vocabularies.wikipathways.org/wp#>\n' +
                'SELECT DISTINCT ?species WHERE {\n' +
                '  ?pw a wp:Pathway ; wp:organismName ?species .\n' +
                '} ORDER BY ?species',
            valueField: 'species',
            placeholder: 'Type species name...'
        },
        entityType: {
            sparql: null,
            staticValues: ['GeneProduct', 'Metabolite', 'Protein', 'Rna', 'Complex'],
            valueField: 'value',
            placeholder: 'Select entity type...'
        },
        datasource: {
            sparql: null,
            staticValues: ['ChEBI', 'Chemspider', 'Ensembl', 'Entrez Gene',
                           'HMDB', 'HGNC Accession Number', 'PubChem',
                           'Rhea', 'Uniprot', 'Wikidata'],
            valueField: 'value',
            placeholder: 'Select datasource...'
        },
        interactionType: {
            sparql: null,
            staticValues: ['Binding', 'Catalysis', 'ComplexBinding', 'Conversion',
                           'Inhibition', 'Stimulation', 'TranscriptionTranslation', 'Translocation'],
            valueField: 'value',
            placeholder: 'Select interaction type...'
        },
        community: {
            sparql: 'PREFIX wp: <http://vocabularies.wikipathways.org/wp#>\n' +
                'SELECT DISTINCT (REPLACE(STR(?tag), "^.*Curation:", "") AS ?community) WHERE {\n' +
                '  ?pw a wp:Pathway ; wp:ontologyTag ?tag .\n' +
                '  FILTER(STRSTARTS(STR(?tag), "http://vocabularies.wikipathways.org/wp#Curation:"))\n' +
                '} ORDER BY ?community',
            valueField: 'community',
            placeholder: 'Type community name...'
        }
    },
    welcomeTitle: "SPARQL Query Explorer",
    welcomeMessage: "<p>Browse and run SPARQL queries against PlantMetWiki, the knowledge graph of plant metabolic pathways.</p><ul><li><strong>Browse examples</strong> in the tree on the right to find a query</li><li><strong>Edit parameters</strong> to customize queries for your needs</li><li><strong>Write your own SPARQL</strong> directly in the editor below</li></ul>",

    // ---- Phase 9: Query Reliability knobs ----
    // queryTimeoutMs: XHR timeout in milliseconds. Hung requests fail in bounded
    // time instead of polling indefinitely. Forks for federated/heavy queries
    // may bump this to 120000 or higher. (RELIAB-05)
    queryTimeoutMs: 60000,

    // maxGetUrlBytes: Single threshold gating BOTH the GET→POST method switch
    // and the permalink refusal. Computed against the prefixed, URL-encoded
    // query length. 4000 is conservative (well below nginx 8KB default and
    // Cloudflare 8KB limit). (RELIAB-03 + RELIAB-04)
    maxGetUrlBytes: 4000,

    // sendPrefixBlock: Controls PREFIX block delivery to the endpoint.
    //   'auto'  — used-only token-scan; prepend only prefixes the query
    //             references and that are NOT already declared inline (default).
    //   true    — force-prepend ALL CONFIG.namespaces entries not already
    //             declared inline (predictable, slightly heavier URL).
    //   false   — skip prepending entirely (rely on server-registered prefixes;
    //             best for Virtuoso-only forks). (RELIAB-01)
    sendPrefixBlock: 'auto',

    // bitlyToken: Bitly access token used by "Get Permalink" to shorten the ?q= URL.
    // It is visible to anyone who loads the page, so use a token with no other rights.
    // Empty string = no shortening; the full permalink is shown. Set at container start
    // with SNORQL_BITLY_TOKEN (an empty value disables shortening).
    bitlyToken: ""
};
