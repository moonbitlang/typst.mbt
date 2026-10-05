#!/usr/bin/env node
// Check the review preview's script against the library
// (docs/edsl-review.md, slices 2 to 4): the page carries the records that
// the library made for some selections and its answers for some source
// lines, and the script's own code must give the same ones.
//
//   moon run doc/examples/review --target native --release -- preview showcase -o preview.html
//   node scripts/review_page_check.mjs preview.html
//
// Opening the page in a browser with `#selftest` runs the same check and,
// in addition, compares the browser's hit testing with the library's.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const path = process.argv[2];
if (!path) {
  console.error('usage: node scripts/review_page_check.mjs preview.html');
  process.exit(2);
}
const html = readFileSync(path, 'utf8');
const open = '<script type="application/json" id="review-data">';
const start = html.indexOf(open);
const end = html.indexOf('</script>', start);
if (start < 0 || end < 0) {
  console.error('no review data in ' + path);
  process.exit(2);
}
const data = JSON.parse(html.slice(start + open.length, end));

// The page embeds the script; the source file must be the embedded one.
const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(join(here, '..', 'doc', 'review_page', 'page.js'), 'utf8');
if (!html.includes(source.trim())) {
  console.error('the page was not generated from the current doc/review_page/page.js');
  process.exit(1);
}
const module = { exports: {} };
new Function('module', source)(module);
const Core = module.exports;
Core.load(data);
const bad = Core.check();
console.log(`${data.samples.length + data.objects.length} feedback records, ${data.finds.length} source lines, ${bad.length} differences`);
for (const line of bad.slice(0, 30)) console.log('  ' + line);
process.exit(bad.length ? 1 : 0);
