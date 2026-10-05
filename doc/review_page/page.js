// The preview page of the review loop (docs/edsl-review.md, slice 1).
// Every page has a layer of invisible shapes (`svg.hit`), one per glyph
// run, shape and image with a source location; `data-o` is the number of
// the origin in the table `#review-origins`. The browser finds the shape
// under the pointer; this script shows its origin.
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const origins = JSON.parse($('review-origins').textContent);
  const layers = Array.from(document.querySelectorAll('svg.hit'));
  $('doc-meta').textContent = layers.length + (layers.length === 1 ? ' page' : ' pages');

  // `Constructor(..)`, with the parameter if the location is an argument.
  const call = (o) => (o.param === undefined
    ? `${o.kind}(..)`
    : `${o.kind}(..), parameter ${o.param + 1}`);
  const range = (o) => {
    const [l0, c0, l1, c1] = o.range;
    return l0 === l1
      ? `line ${l0}, columns ${c0} to ${c1}`
      : `line ${l0}, column ${c0} to line ${l1}, column ${c1}`;
  };

  let marked = [];
  function mark(id, here) {
    for (const el of marked) el.classList.remove('on', 'hit-here');
    marked = id === null ? [] : Array.from(document.querySelectorAll(`svg.hit [data-o="${id}"]`));
    for (const el of marked) el.classList.add('on');
    if (here) here.classList.add('hit-here');
  }

  function show(target) {
    const hit = target && target.closest ? target.closest('[data-o]') : null;
    $('empty').hidden = true;
    $('none').hidden = hit !== null;
    $('found').hidden = hit === null;
    if (hit === null) {
      mark(null, null);
      return;
    }
    const id = Number(hit.getAttribute('data-o'));
    const o = origins[id];
    mark(id, hit);
    $('where').textContent = `${o.file}:${o.range[0]}:${o.range[1]}`;
    $('call').textContent = call(o);
    $('file').textContent = o.module ? `${o.file} (module ${o.module})` : o.file;
    $('range').textContent = range(o) + (o.param === undefined ? ' (the call)' : ' (the argument)');
    const keys = o.keys || [];
    $('key-label').hidden = $('key').hidden = keys.length === 0;
    $('key').textContent = keys.join(' / ');
    const pages = new Set(marked.map((el) => el.closest('svg.hit').getAttribute('data-page')));
    $('drawn').textContent = `${marked.length} ${marked.length === 1 ? 'piece' : 'pieces'} on page ${Array.from(pages).join(', ')}`;
    $('note').textContent = 'Everything this call or argument produced is highlighted. The location is the constructor call, not a position inside its text.';
  }

  // The self-test (`#selftest` in the address): for the points that the
  // library answered when the page was made (`#review-probes`), the shape
  // that the browser finds must carry the library's origin.
  function selftest() {
    const probes = JSON.parse($('review-probes').textContent);
    const bar = document.querySelector('.bar'), panel = $('panel');
    bar.hidden = panel.hidden = true;
    const bad = [];
    const shapes = Array.from(document.querySelectorAll('svg.hit [data-o]'));
    // Twice: the second time with every shape marked, which must not
    // change what is hit.
    for (const round of [0, 1]) {
      if (round === 1) for (const el of shapes) el.classList.add('on', 'hit-here');
      for (const [page, x, y, want] of probes) {
        const layer = layers[page - 1];
        const scale = () => layer.getBoundingClientRect().width / layer.viewBox.baseVal.width;
        // Elements are only found inside the viewport.
        window.scrollBy(0, layer.getBoundingClientRect().top + y * scale() - window.innerHeight / 2);
        const box = layer.getBoundingClientRect();
        const el = document.elementFromPoint(box.left + x * scale(), box.top + y * scale());
        const hit = el && el.closest ? el.closest('[data-o]') : null;
        const got = hit === null ? -1 : Number(hit.getAttribute('data-o'));
        if (got !== want) bad.push(`page ${page} at (${x}, ${y})${round ? ', marked' : ''}: the page finds ${got}, the library ${want}`);
      }
    }
    for (const el of shapes) el.classList.remove('on', 'hit-here');
    bar.hidden = panel.hidden = false;
    window.scrollTo(0, 0);
    $('selftest').hidden = false;
    $('selftest').textContent = bad.length === 0
      ? `Self-test passed: at ${probes.length} points the page finds the origin that the library finds, also with every shape marked.`
      : `Self-test: ${bad.length} of ${probes.length} points differ from the library.\n` + bad.slice(0, 20).join('\n');
  }
  if (window.location.hash === '#selftest') selftest();

  // A click on a page: the layer's shape under the pointer, if any. (A
  // click elsewhere on the page says that nothing with a source is there.)
  $('pages').addEventListener('click', (event) => {
    if (event.target.closest && event.target.closest('.page')) show(event.target);
  });
})();
