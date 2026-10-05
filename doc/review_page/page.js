// The preview page of the review loop (docs/edsl-review.md, slices 1 and
// 2). Every page has a layer of invisible shapes (`svg.hit`), one per
// word, shape and image with a source location: `data-o` is the number of
// the origin, `data-i` the number of the word. The data (`#review-data`)
// has the table of origins and the words in reading order.
//
// `Core` builds the feedback record of a selection. It applies the rules
// of the library (`doc/review_feedback.mbt`) to the same data and needs no
// document: `scripts/review_page_check.mjs` runs it on the records that
// the library put into the page.
const Core = (() => {
  'use strict';
  let D = null;
  const load = (data) => { D = data; };

  // What joins a word to the text it continues: nothing if it touches the
  // word before it, a gap if other words are between.
  const joint = (last, i, word) => (last !== i - 1 ? ' … ' : word[2] ? ' ' : '');

  function textOf(from, to) {
    let out = '';
    for (let i = from; i <= to; i++) out += (i > from && D.words[i][2] ? ' ' : '') + D.words[i][1];
    return out;
  }

  function originJson(id, rendered, pieces) {
    const o = D.origins[id];
    const out = { file: o.file, module: o.module, constructor: o.kind };
    if (o.param !== undefined) out.parameter = o.param + 1;
    if (o.keys) out.keys = o.keys;
    out.start = [o.range[0], o.range[1]];
    out.end = [o.range[2], o.range[3]];
    out.rendered_text = rendered;
    out.pieces = pieces;
    return out;
  }

  const record = (comment, text, pages, origins) => ({
    format: 'typst.mbt review feedback 1', document: D.title, comment, selected_text: text, pages, origins,
  });

  // The record for the words `from..=to`.
  function feedback(from, to, comment) {
    const pages = [], order = [], found = new Map(), places = new Map();
    for (let i = from; i <= to; i++) {
      const word = D.words[i], [page, text, , origin, piece] = word;
      if (!pages.includes(page)) pages.push(page);
      let entry = found.get(origin);
      if (!entry) {
        entry = { pieces: [], rendered: '', last: -1 };
        found.set(origin, entry);
        order.push(origin);
      }
      entry.rendered += (entry.last >= 0 ? joint(entry.last, i, word) : '') + text;
      entry.last = i;
      const place = places.get(piece);
      if (place) {
        entry.pieces[place.at] += joint(place.last, i, word) + text;
        place.last = i;
      } else {
        places.set(piece, { at: entry.pieces.length, last: i });
        entry.pieces.push(text);
      }
    }
    return record(comment, textOf(from, to), pages,
      order.map((id) => originJson(id, found.get(id).rendered, found.get(id).pieces)));
  }

  // The record for a shape or an image with the origin `id` on a page.
  const objectFeedback = (id, page, comment) => record(comment, '', [page], [originJson(id, '', [])]);

  const quoted = (text) => {
    const cs = Array.from(text);
    return '"' + cs.slice(0, 240).map((c) => (c === '"' ? '\\"' : c === '\\' ? '\\\\' : c === '\n' ? '\\n' : c)).join('') +
      (cs.length > 240 ? '…' : '') + '"';
  };

  const location = (o) => `${o.file}:${o.start[0]}:${o.start[1]}-${o.end[0]}:${o.end[1]}`;
  const call = (o) => `${o.constructor}(..)` + (o.parameter === undefined ? '' : `, parameter ${o.parameter}`);
  const shared = (o) => `${o.pieces.length} pieces of this argument are selected; they share this location, which is the argument as a whole.`;

  function toText(f) {
    const pages = (f.pages.length === 1 ? 'page ' : 'pages ') + f.pages.join(', ');
    let out = `Review comment on ${quoted(f.document)} (a document rendered from MoonBit source by typst.mbt)\n`;
    out += `Comment: ${f.comment === '' ? '(none)' : f.comment}\n`;
    out += f.selected_text === ''
      ? `Selected: a shape or an image (${pages})\n`
      : `Selected text: ${quoted(f.selected_text)} (${pages})\n`;
    f.origins.forEach((o, i) => {
      out += `Source ${i + 1} of ${f.origins.length}: ${location(o)}, ${call(o)}`;
      if (o.keys) out += `, data key ${o.keys.map(quoted).join(' / ')}`;
      out += '\n';
      if (o.rendered_text !== '') out += `  rendered: ${quoted(o.rendered_text)}\n`;
      if (o.pieces.length > 1) out += `  ${shared(o)}\n`;
    });
    return out + 'Locations are constructor calls and their arguments in the MoonBit source (line:column, columns in code points), not positions inside a string.\n';
  }

  // The records that the library made for some selections must be the
  // records made here. Returns the differences.
  function check() {
    const bad = [];
    const same = (what, f, json, text) => {
      if (JSON.stringify(f) !== JSON.stringify(json)) bad.push(`${what}: the record differs from the library's`);
      if (toText(f) !== text) bad.push(`${what}: the text differs from the library's`);
    };
    for (const [from, to, json, text] of D.samples) same(`words ${from} to ${to}`, feedback(from, to, json.comment), json, text);
    for (const [id, page, json, text] of D.objects) same(`origin ${id}`, objectFeedback(id, page, json.comment), json, text);
    return bad;
  }

  return { load, feedback, objectFeedback, toText, textOf, location, call, shared, check };
})();

if (typeof module !== 'undefined' && module.exports) module.exports = Core;

if (typeof document !== 'undefined') (() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const data = JSON.parse($('review-data').textContent);
  Core.load(data);
  const layers = Array.from(document.querySelectorAll('svg.hit'));
  const shapes = Array.from(document.querySelectorAll('svg.hit [data-o]'));
  $('doc-meta').textContent = layers.length + (layers.length === 1 ? ' page' : ' pages');
  // The boxes of each word.
  const boxes = new Map();
  for (const el of shapes) {
    if (!el.hasAttribute('data-i')) continue;
    const i = Number(el.getAttribute('data-i'));
    if (!boxes.has(i)) boxes.set(i, []);
    boxes.get(i).push(el);
  }

  // The selection: words `from..=to` (`anchor` is where it started), or a
  // shape or image (`object`: its element).
  const state = { from: -1, to: -1, anchor: -1, object: null, extend: false, comments: [] };
  const key = 'typst.mbt review: ' + data.title;
  try { state.comments = JSON.parse(localStorage.getItem(key) || '[]'); } catch (e) { state.comments = []; }
  // (What another version of the page stored is not a list of records.)
  state.comments = (Array.isArray(state.comments) ? state.comments : []).filter((f) =>
    f && f.format === 'typst.mbt review feedback 1' && Array.isArray(f.origins) && Array.isArray(f.pages) &&
    typeof f.comment === 'string' && typeof f.selected_text === 'string');
  const persist = () => { try { localStorage.setItem(key, JSON.stringify(state.comments)); } catch (e) { /* kept in the page only */ } };

  const current = () => {
    const comment = $('comment').value.trim();
    if (state.object) {
      return Core.objectFeedback(Number(state.object.getAttribute('data-o')),
        Number(state.object.closest('svg.hit').getAttribute('data-page')), comment);
    }
    return state.from < 0 ? null : Core.feedback(state.from, state.to, comment);
  };

  let marked = [];
  function mark() {
    for (const el of marked) el.classList.remove('on');
    marked = [];
    if (state.object) marked.push(state.object);
    else for (let i = state.from; i >= 0 && i <= state.to; i++) for (const el of boxes.get(i) || []) marked.push(el);
    for (const el of marked) el.classList.add('on');
  }

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }

  function render(nothing) {
    mark();
    const f = current();
    $('empty').hidden = f !== null || nothing;
    $('none').hidden = !(f === null && nothing);
    $('found').hidden = f === null;
    if (f === null) return;
    $('selected').textContent = f.selected_text === '' ? 'A shape or an image' : '“' + f.selected_text + '”';
    $('where').textContent = (f.pages.length === 1 ? 'Page ' : 'Pages ') + f.pages.join(', ') +
      (f.origins.length === 1 ? '' : ` · ${f.origins.length} source locations`);
    $('extend').hidden = state.object !== null;
    const list = $('mapping');
    list.textContent = '';
    for (const o of f.origins) {
      const card = el('section', 'origin');
      card.appendChild(el('p', 'loc', `${o.file}:${o.start[0]}:${o.start[1]}`));
      card.appendChild(el('code', '', Core.call(o)));
      const facts = el('p', 'meta', o.start[0] === o.end[0]
        ? `line ${o.start[0]}, columns ${o.start[1]} to ${o.end[1]}`
        : `line ${o.start[0]}, column ${o.start[1]} to line ${o.end[0]}, column ${o.end[1]}`);
      facts.textContent += o.parameter === undefined ? ' (the call)' : ' (the argument)';
      if (o.keys) facts.textContent += ` · data key ${o.keys.join(' / ')}`;
      card.appendChild(facts);
      if (o.rendered_text !== '') card.appendChild(el('p', 'rendered', '“' + o.rendered_text + '”'));
      if (o.pieces.length > 1) card.appendChild(el('p', 'note', Core.shared(o)));
      list.appendChild(card);
    }
    $('output').value = Core.toText(f);
    $('status').textContent = state.extend ? 'Click the word where the selection should end.' : '';
  }

  function selectWords(a, b) {
    state.object = null;
    state.from = Math.min(a, b);
    state.to = Math.max(a, b);
    render(false);
  }
  function clear(nothing) {
    state.object = null;
    state.from = state.to = state.anchor = -1;
    state.extend = false;
    $('extend').setAttribute('aria-pressed', 'false');
    render(nothing);
  }
  const wordOf = (target) => {
    const box = target && target.closest ? target.closest('[data-i]') : null;
    return box === null ? -1 : Number(box.getAttribute('data-i'));
  };

  // Dragging with a mouse selects from the word where the button went
  // down to the word under the pointer. (A finger scrolls the page; on a
  // touch screen a tap selects a word and "Extend" the range to another.)
  let drag = -1, dragged = false;
  $('pages').addEventListener('pointerdown', (event) => {
    drag = event.pointerType === 'mouse' && event.button === 0 ? wordOf(event.target) : -1;
    dragged = false;
    if (drag >= 0) event.preventDefault();
  });
  $('pages').addEventListener('pointermove', (event) => {
    if (drag < 0) return;
    const word = wordOf(document.elementFromPoint(event.clientX, event.clientY));
    if (word < 0 || (word === drag && !dragged)) return;
    dragged = true;
    state.anchor = drag;
    selectWords(drag, word);
  });
  window.addEventListener('pointerup', () => { drag = -1; });

  // A click selects the word, shape or image under the pointer; with
  // "Extend" (or the shift key) the words from the first word to this
  // one. A click on a page where nothing has a source says so.
  $('pages').addEventListener('click', (event) => {
    if (!(event.target.closest && event.target.closest('.page'))) return;
    if (dragged) { dragged = false; return; }
    const hit = event.target.closest('[data-o]');
    const word = wordOf(event.target);
    // The gap between two words belongs to their text; it is nothing to
    // select.
    if (hit !== null && hit.hasAttribute('data-g')) return;
    if (hit === null) {
      clear(true);
    } else if (word < 0) {
      clear(false);
      state.object = hit;
      render(false);
    } else if ((state.extend || event.shiftKey) && state.anchor >= 0) {
      state.extend = false;
      $('extend').setAttribute('aria-pressed', 'false');
      selectWords(state.anchor, word);
    } else {
      state.anchor = word;
      selectWords(word, word);
    }
  });
  $('extend').addEventListener('click', () => {
    state.extend = !state.extend && state.anchor >= 0;
    $('extend').setAttribute('aria-pressed', String(state.extend));
    render(false);
  });
  $('clear').addEventListener('click', () => clear(false));
  $('comment').addEventListener('input', () => {
    const f = current();
    if (f) $('output').value = Core.toText(f);
  });

  // Copy: the clipboard if the page may use it; otherwise the text is put
  // into its text area and selected, to be copied by hand.
  function copy(text, area, status) {
    const byHand = () => {
      area.value = text;
      area.focus();
      area.select();
      let done = false;
      try { done = document.execCommand('copy'); } catch (e) { done = false; }
      status.textContent = done ? 'Copied.' : 'The text is selected below: copy it with Ctrl+C or ⌘C.';
    };
    area.value = text;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => { status.textContent = 'Copied.'; }, byHand);
    } else {
      byHand();
    }
  }
  $('copy').addEventListener('click', () => {
    const f = current();
    if (f) copy(Core.toText(f), $('output'), $('status'));
  });
  $('copy-json').addEventListener('click', () => {
    const f = current();
    if (f) copy(JSON.stringify(f, null, 2), $('output'), $('status'));
  });

  // The list of comments.
  const allText = () => state.comments.map((f, i) =>
    `--- comment ${i + 1} of ${state.comments.length} ---\n${Core.toText(f)}`).join('\n');
  function renderList() {
    const list = $('list');
    list.textContent = '';
    state.comments.forEach((f, i) => {
      const item = el('li', 'comment');
      item.appendChild(el('p', 'said', f.comment));
      const o = f.origins[0];
      item.appendChild(el('p', 'meta', (f.selected_text === '' ? 'A shape or an image' : '“' + f.selected_text + '”') +
        (o ? ` · ${o.file}:${o.start[0]}:${o.start[1]}` : '')));
      const remove = el('button', '', 'Remove');
      remove.type = 'button';
      remove.addEventListener('click', () => { state.comments.splice(i, 1); persist(); renderList(); });
      item.appendChild(remove);
      list.appendChild(item);
    });
    $('count').textContent = String(state.comments.length);
    $('list-empty').hidden = state.comments.length > 0;
    $('list-tools').hidden = state.comments.length === 0;
    $('all').value = allText();
  }
  $('add').addEventListener('click', () => {
    const f = current();
    if (!f) return;
    if (f.comment === '') {
      $('status').textContent = 'Write a comment first.';
      $('comment').focus();
      return;
    }
    state.comments.push(f);
    persist();
    $('comment').value = '';
    $('status').textContent = 'Added to the list below.';
    renderList();
  });
  $('copy-all').addEventListener('click', () => copy(allText(), $('all'), $('list-status')));
  $('copy-all-json').addEventListener('click', () => copy(JSON.stringify(state.comments, null, 2), $('all'), $('list-status')));
  renderList();

  // The self-test (`#selftest` in the address): the browser must find the
  // origin that the library found at each probe, also when every shape is
  // marked, and the feedback records must be the library's.
  function selftest() {
    const bar = document.querySelector('.bar'), panel = $('panel');
    bar.hidden = panel.hidden = true;
    const bad = Core.check();
    for (const round of [0, 1]) {
      if (round === 1) for (const shape of shapes) shape.classList.add('on');
      for (const [page, x, y, want] of data.probes) {
        const layer = layers[page - 1];
        const scale = () => layer.getBoundingClientRect().width / layer.viewBox.baseVal.width;
        // Elements are only found inside the viewport.
        window.scrollBy(0, layer.getBoundingClientRect().top + y * scale() - window.innerHeight / 2);
        const box = layer.getBoundingClientRect();
        const found = document.elementFromPoint(box.left + x * scale(), box.top + y * scale());
        const hit = found && found.closest ? found.closest('[data-o]') : null;
        const got = hit === null ? -1 : Number(hit.getAttribute('data-o'));
        if (got !== want) bad.push(`page ${page} at (${x}, ${y})${round ? ', marked' : ''}: the page finds ${got}, the library ${want}`);
      }
    }
    for (const shape of shapes) shape.classList.remove('on');
    bar.hidden = panel.hidden = false;
    window.scrollTo(0, 0);
    $('selftest').hidden = false;
    $('selftest').textContent = bad.length === 0
      ? `Self-test passed: at ${data.probes.length} points the page finds the origin that the library finds, also with every shape marked, and ${data.samples.length + data.objects.length} feedback records equal the library's.`
      : `Self-test: ${bad.length} differences from the library.\n` + bad.slice(0, 20).join('\n');
  }
  if (window.location.hash === '#selftest') selftest();
})();
