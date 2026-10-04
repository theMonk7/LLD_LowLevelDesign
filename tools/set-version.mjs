#!/usr/bin/env node
// Stamps one cache-busting version onto every asset reference: the <link>/<script>
// in index.html AND the internal `import ... from './x.js'` specifiers, which the
// browser caches separately and would otherwise serve stale against a fresh app.js.
// Run: node tools/set-version.mjs [version]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const HTML = path.join(ROOT, 'docs', 'index.html');
const JS_DIR = path.join(ROOT, 'docs', 'assets', 'js');

const html = fs.readFileSync(HTML, 'utf8');
const current = Number((html.match(/app\.css\?v=(\d+)/) || [])[1] || 0);
const version = Number(process.argv[2] || current + 1);

fs.writeFileSync(HTML, html
  .replace(/(assets\/css\/app\.css)(\?v=\d+)?/g, `$1?v=${version}`)
  .replace(/(assets\/js\/app\.js)(\?v=\d+)?/g, `$1?v=${version}`));

let touched = 0;
for (const f of fs.readdirSync(JS_DIR).filter((x) => x.endsWith('.js'))) {
  const p = path.join(JS_DIR, f);
  const src = fs.readFileSync(p, 'utf8');
  const out = src.replace(/(from\s+['"]\.\/[\w.-]+\.js)(\?v=\d+)?(['"])/g, `$1?v=${version}$3`);
  if (out !== src) { fs.writeFileSync(p, out); touched += 1; }
}

console.log(`version ${version} — index.html + ${touched} module file(s) stamped`);
