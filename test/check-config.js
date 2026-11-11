// Sanity checks for this instance's config.js and files, run with plain node (no dependencies):
//   node test/check-config.js
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
global.window = {};
require(path.join(ROOT, 'config.js'));
const c = window.SNORQL_CONFIG;

assert.ok(c, 'window.SNORQL_CONFIG is defined');
assert.strictEqual(c.endpoint, 'https://plantmetwiki.bioinformatics.nl/sparql');
assert.strictEqual(c.examplesRepo, 'https://github.com/pathway-lod/SPARQLQueries');
assert.strictEqual(c.examplesFormat, 'index');
assert.strictEqual(c.bitlyToken, '', 'no Bitly token of another instance');
for (const t of Object.keys(c.autocompleteTypes)) {
  const a = c.autocompleteTypes[t];
  assert.ok(a.valueField, `autocomplete type ${t} has a valueField`);
  assert.ok(typeof a.sparql === 'string' || Array.isArray(a.staticValues), `autocomplete type ${t} has a source`);
}

// Every local image referenced from config.js must be in images/.
const footerItems = (c.footer || []).flat();
const refs = [c.logo && c.logo.src, c.favicon].concat(footerItems.map((i) => i && i.image));
for (const ref of refs.filter((r) => typeof r === 'string' && r.startsWith('assets/images/'))) {
  assert.ok(fs.existsSync(path.join(ROOT, 'images', ref.slice('assets/images/'.length))), `missing image ${ref}`);
}

// script.sh rewrites these keys line by line, so each must stay on one line.
const src = fs.readFileSync(path.join(ROOT, 'config.js'), 'utf8');
for (const k of ['endpoint', 'examplesRepo', 'examplesBranch', 'examplesFormat', 'examplesIndexUrl', 'defaultGraph', 'title', 'welcomeTitle', 'welcomeMessage', 'bitlyToken']) {
  assert.ok(new RegExp('^    ' + k + ': ".*",?$', 'm').test(src), `${k} is a single-line string`);
}

// head-extra.html holds valid JSON-LD.
const head = fs.readFileSync(path.join(ROOT, 'head-extra.html'), 'utf8');
const m = head.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
assert.ok(m, 'head-extra.html has a JSON-LD block');
JSON.parse(m[1]);

console.log('config.js and files: ok');
