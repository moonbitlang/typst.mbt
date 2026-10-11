# Incremental compilation: design

Status: all four slices are built. Slices 0 and 1 (5.5, "As built";
section 8, "Step 3 as built", "Step 4 as built" and "Step 5 as built"):
the stores of memoized calls outlive their compilation, with comemo's
ages, and `typst watch` recompiles a small edit in a fraction of a first
compilation. Slice 2 (section 8, "Slice 2 as built"): the block level of
the flow is kept. Slice 3 (section 8, "Slice 3 as built"): page runs and
the document are kept, and a recompilation after which the content is
what it was is the export and little else. The two were built at the same
time on two branches; section 8, "Slices 2 and 3 together", has them
measured as one.
Module equality was decided by the owner on 2026-10-11, against the
recommendation of revisions 3 and 4: exactly as upstream (5.4, "Modules").
Revision 5 (2026-10-07) of sections 5.2, 8 (slice 1, step 1) and 9.1 (the
recording check); revision 4 elsewhere. Revisions 1 and
2 were reviewed by Codex (`docs/reviews/incremental-design-{1,2}.md`), both
with the verdict "request changes"; revision 3 answered the second review;
revision 4 records the coordinator's decisions (section 11), costs the
alternative for module equality (5.4) and answers a third review
(`docs/reviews/incremental-design-3.md`, "request changes", on 5.2, 5.4 and
9.1); what it changed in answer to that has not been reviewed outside of
5.2. A fourth review (`docs/reviews/incremental-design-4.md`, "request
changes", repairable) was of what step 1 builds, before it was built;
revision 5 answers it and says what was built. Upstream
`e58a63af`, comemo 0.5.1. Measurements: aarch64 macOS, native release,
`--ignore-system-fonts`, PDF output, other agents building on the same
machine (medians of five; the spread is given where it matters).

The port recompiled from scratch in `typst watch` when this was written.
Upstream keeps comemo's caches between compilations and recompiles a small
edit in a fraction of the time. This document says what the port must keep,
how a kept result learns that it is still valid, what it costs in memory,
and in which order to build it. Section 3 has the measurements the order
rests on; "Step 5 as built" in section 8 has what the existing stores,
kept, gave.

## 0. Summary

- Keeping the stores that exist today (module evaluations, closure calls,
  `layout_par_impl`, `layout_fragment_impl`, the counter sequence) between
  two compilations buys, after a one-character edit at the end: `long.typ`
  234 ms to 96 ms, `longer.typ` 1247 ms to 503 ms, a touying document
  155 ms to 24 ms. What they need to be sound across compilations: a
  record of what each result read from the world, which the port does not
  have; syntax trees that an edit does not change under a closure that is
  kept; and three places repaired where a file is hidden from the results
  that depend on it (the themes of raw text, the works of a bibliography,
  the images an SVG links).
- Three functions that upstream memoizes and the port does not are worth
  more than that on documents with images or code, and they help the first
  compilation too: decoding a raster image (71 % of a deck with 28 PNGs),
  highlighting raw text (`showcase.typ` 71 ms to 50 ms per recompilation),
  the images of the PDF (`handle_image`, 97 % of what is left of the deck,
  half of it conversion and half compression).
- Then the block level of the flow (`layout_single_impl`,
  `layout_multi_impl`): `long.typ` 92 ms to 56 ms. The page run and the
  document pay most for a compilation in which nothing changed, and a
  little for a deck after an edit (the touying document 25 ms to 21 ms).
- What is left after all of it is the document-level realization, the flow
  around the cached blocks, and the PDF writer, 1.6 to 2.6 and 3.1 to 4
  times upstream's: after an edit at the end of `long.typ` the port would take
  57 ms where upstream takes 23 ms, which is the ratio of the two programs
  in a first compilation of that document (240 ms to 100 ms). Closing that
  is not incremental compilation.
- The design mirrors comemo: results are found by a fingerprint of their
  hashed arguments, are valid if the tracked arguments answer the recorded
  questions as before, age by one with every `evict` and are dropped when
  their age exceeds `max_age`. Where the port deviates (section 10) it is
  stricter. Modules are compared as upstream compares them, with what
  that costs: a recompilation can give what upstream's `typst watch`
  gives where that is not what a compilation from scratch gives (5.4).
- The numbers for what is not built are a probe's, which validated less
  than the design does: they are upper bounds of the gain. For slice 1
  they held (section 8, "Step 5 as built": the first line of this summary
  as measured is `long.typ` 243 ms to 96.7 ms, `longer.typ` 1260 ms to 509 ms,
  the touying document 167 ms to 25.9 ms).

## 1. What upstream does

Read in `~/.cargo/registry/src/*/comemo-0.5.1` and `.repos/typst`.

- A memoized function has hashed arguments and tracked arguments
  (`Tracked<T>`, `TrackedMut<T>`). The key is a 128-bit SipHash-1-3 of the
  hashed arguments (`memoize.rs`, `memoize`). Each function has one cache: a
  `CallTree` from the key to a decision tree whose inner nodes are tracked
  calls and whose edges are the hashes of their return values (`tree.rs`).
- A lookup walks the tree: it performs each recorded call on the tracked
  arguments of the current call and follows the edge of the returned hash
  (`CallTree::get`, `Input::call` in `input.rs`). There is no entry if an
  edge is missing. Each call it performs is also emitted to the constraint
  of the enclosing memoized function ("we do _not_ replay the constraints
  in another way"), which is how the reads of a reused call become reads of
  its caller.
- On a hit the mutable calls (the sink's) are replayed and the output is
  cloned. On a miss the function runs with a fresh `Constraint` attached to
  its tracked arguments, and the deduplicated sequence of immutable calls
  with their return hashes is inserted with the output (`constraint.rs`).
- Of the hashed arguments only the hash is kept, of the return value of a
  tracked call only its hash (the output of the memoized function and the
  tracked calls with their arguments are kept). Two arguments with one hash
  are one argument.
- When a lookup validates, `Input::call` asks an accelerator first: per
  tracking id (one per `track()`) a map from the hash of a call to the hash
  of its result, so that validation makes a call once per id
  (`input.rs`, `accelerate.rs`). `evict` retires the ids and clears the
  maps.
- `comemo::evict(max_age)` adds one to the age of every entry and removes
  those above `max_age`; a hit sets the age to zero (`CacheData::evict`,
  `lookup`). `typst watch` calls `comemo::evict(10)` after every
  recompilation (`typst-cli/src/watch.rs:83`).
- The tracked world is `library`, `book`, `main`, `source(id)`,
  `file(id)`, `font(index)`, `today(offset)`
  (`typst-library/src/lib.rs:62`). The memoized functions that build an
  engine also take `library: &LazyHash<Library>` as a hashed argument;
  `highlight` takes the routines.
- Between compilations the CLI resets its file slots; a slot that is read
  again reloads the bytes and calls `Source::replace` on the source it had
  (`typst-kit/src/files.rs`, `FileSlot::source`), which reparses
  incrementally and keeps the span numbers of the nodes it does not touch.
  `Source` is `Arc<LazyHash<SourceInner>>` and its syntax nodes are
  `Arc`s: an edit goes through `Arc::make_mut`, so whoever still holds the
  old source or a node of it (a closure of the previous compilation) keeps
  the old one.
- 59 functions are memoized (`grep -rn "comemo::memoize" .repos/typst/crates
  --include='*.rs' | wc -l`). Section 4 lists them.

## 2. What the port does today

(As it was when the design was written. Since then: slice 0, the
persistent edits of step 3 of slice 1, and step 1 of slice 1, which
changed what this section and the inventory of section 4 say about the
stores: their entries keep what the call read of the world and compare
the library (5.2), `compilation_epoch` is gone, and a module entry
belongs to a scope. Step 2, after which the last paragraph of this
section is history: the tables of raw text and the cell of the works are
gone, and an SVG image is also the images it links (5.5, "As built").
And the engine half of step 3: a module evaluation is
found by the fingerprint of its source, and the main file goes through
the same store.)

- `library/memo.mbt`: `memoize` (used by `memoized_layout` for
  `layout_par_impl` and `layout_fragment_impl`, and by the counter sequence
  in `library/counter.mbt`) and `memoized_closure`. An entry is found by a
  fingerprint and keeps its arguments, which must also be equal
  (`values_memo_equal`); it keeps the introspector it was computed with,
  the recorded introspector reads (`IntrospectionRecorder`, replayed to
  validate against another introspector and merged into the caller's
  recorder), and the sink effects. A key holds at most four entries
  (`memo_max_entries`). `with_layout_memo` gives every compilation a new
  `memo_generation`, and a store clears itself when it sees a new one.
- `eval/import.mbt`, `eval_source_memoized`: the modules of imported files,
  by file id, valid for the same world object, the same library object and
  the same source text, and for a route and a traced span that give the
  recorded answers. `EvalMemos::of` drops them when
  `@library.compilation_epoch()` changes. The main file does not go through
  it (`typst/lib.mbt`, `compile_impl` calls `@eval.eval_source`).
- `eval/captures.mbt`: the capture analysis and the node fingerprint of a
  closure expression, by span and node identity, for one compilation.
- The worlds. `kit/files.mbt` is a port of typst-kit's file store:
  `FileStore::reset` keeps the source of a parsed slot as stale, and
  `FileSlot::source` calls `source.replace(text)` on it. So the CLI's world
  (`cli/world.mbt`, `SystemWorld::reset`, called by `cli/watch.mbt` before
  every recompilation) keeps its `Source` objects and edits them, as
  upstream's does. `doc`'s `DocWorld` (`doc/world.mbt`) parses a file once
  and keeps the source for its lifetime; a compilation of `doc` runs in a
  `SessionWorld` (`doc/session.mbt`) that is made for that compilation.
- `Source::replace` and `Source::edit` (`syntax/source.mbt`,
  `syntax/reparser.mbt`) changed the tree in place when this was written:
  `SyntaxNode::replace_children` and `update_parent` (`syntax/node.mbt`)
  changed the children, lengths and numbering bounds of the nodes on the
  path from the root to the edit, `InnerNode::numberize` renumbered the
  siblings in the range it had to widen, and a failed incremental reparse
  overwrote the root's data. A closure holds the node of its body
  (`Closure.node`, `library/func.mbt`). So, unlike upstream, a closure of
  the previous compilation whose body contains or adjoins the edit saw its
  tree change under it (section 5.4). (No longer: the syntax half of step
  3 of slice 1 is built, see "As built" in 5.4.)
- What outlives a compilation: the content-keyed decode caches that
  `@library.evict` drops as a whole on every `max_age`-th call (raw
  syntaxes and themes, bibliographies, CSL styles, PDF documents, plugins
  and their calls), process-wide caches by font or key that are never
  dropped (shape plans and rustybuzz faces in `layout/inline_shaping.mbt`,
  overhang tables, glyph outlines and bitmaps in `svg/text.mbt` and
  `render/text.mbt`, `glyph_frame_cache`, font instances, numbering
  patterns, `font_data_hashes`), and the CLI's page cache for PNG and SVG
  (`ExportCache`, `cli/compile.mbt`).
- The stores are not dropped when a compilation ends but when the next one
  starts: a watching process holds them while it waits. (Since step 5 of
  slice 1 they are not dropped at all: `evict` ages them.)
- Two caches are keyed by less than what their values depend on, which is
  harmless while nothing outlives a compilation (5.5): the syntaxes and
  themes of raw elements by their source (`raw_syntaxes_derived`,
  `raw_theme_derived`, `library/text_raw.mbt`), and the last works of a
  bibliography by the introspector (`works_cache`,
  `library/bibliography.mbt`). And one value's fingerprint covers less
  than what it was built from: an SVG image's does not cover the images it
  links.

## 3. Measurements

### 3.1 The probe

A throwaway patch (not committed; appendix A) on `origin/main` at
`4877742`. With a file `typst-probe.conf` in the working directory,
`typst compile` compiles the document `repeat + 1` times in one process,
calling `SystemWorld::reset` in between as `watch` does and, if asked,
rewriting a file with one more character inserted each time. Switches:

- `keep`: the stores survive (`with_layout_memo` keeps the generation and
  the epoch), the main file goes through `eval_source_memoized`, and a
  module is only reused if every file read during its evaluation is what it
  was (compared as text and bytes). The capture table is still dropped per
  compilation. Nothing else is validated: closure calls and layout results
  are reused on their keys and introspector reads alone, which is unsound
  (a closure that reads a file) but does not happen in these documents.
- `imgmemo`, `hlmemo`: `RasterImage::new` by its data, `RawElem::highlight`
  by element and styles.
- `block`, `run`, `doc`: `layout_single_impl` and `layout_multi_impl`
  through `memoized_layout`; `layout_page_run` and
  `layout_document_common` through `memoize`, on the key alone.
- `noargs`: layout entries are found by their key alone, like comemo's.

Timers around the evaluation, each layout iteration and the export; `sample`
(`/usr/bin/sample`, 1 ms) on a process that repeats the recompilation for
"where the rest goes". Upstream's numbers are the status lines of
`typst watch` on a copy of the same files with the same edits
(`scripts/watch_check.py`'s `Session`), its phases are from `--timings`
(which slows a compilation with many function calls: phases are given for
the bench documents only).

Documents: `bench/long.typ` (25 pages), `bench/longer.typ` (121 pages),
`bench/showcase.typ` (4 pages; a JPEG, an SVG, a PDF, raw blocks, a
bibliography), `tests/packages/docs/touying/theme-metropolis.typ` (touying
0.8.0), `tests/packages/docs/ilm/bakers-handbook.typ` (ilm 2.1.1, a
bibliography file), and a stand-in for the private deck: 13 slides on
touying 0.6.1's metropolis theme in 39 pages, 28 distinct PNG files (six
images of typst-dev-assets, each copy with a `tEXt` chunk of its own) and a
theme file of its own that every slide uses (generated by the probe's
`mkdeck.py`, appendix A). The stand-in is heavier than the private deck:
every image is laid out on three subslides.

Edits: one character appended to the main file ("end"); one inserted in
the middle ("middle": in `long.typ` and `longer.typ` that is the body of
the loop that makes every section, so every heading changes); in an
imported file ("theme comment": inside a comment of the deck's theme file;
"theme value" and "package file": a digit added to a length that every
slide uses; "bib file": the handbook's `.bib`).

### 3.2 Upper bound: the stores that exist, kept

`keep` alone: what the stores of today would give if they were valid.
Milliseconds; "first" is the first compilation of the process (it also
parses fonts and fills the process caches), "today" a recompilation with
the stores dropped, which is what `watch` does now.

| document | first | today | kept, nothing changed | of which evaluation | layout | export | kept, edit at the end |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `long.typ` | 240 | 235 | 89 | 0.1 | 52 | 36 | 96 |
| `longer.typ` | 1225 | 1216 | 498 | 0.1 | 320 | 175 | 503 |
| `showcase.typ` | 345 | 268 | 51 | 0.5 | 33 | 16 | 49 |
| deck | 1710 | 1690 | 431 | 1.5 | 140 | 289 | 456 |
| touying | 198 | 159 | 19 | 1.5 | 13 | 4.8 | 24 |
| handbook | 172 | 92 | 27 | 0.1 | 12 | 15 | 30 |

Evaluation disappears (the main module is found again, or evaluated with
every closure call found). Layout does not: three iterations of
document-level realization and of the flow, with every paragraph and
fragment found. The export is untouched.

### 3.3 After an edit, with what is missing added

Recompilation after the edit, in milliseconds. "kept" is `keep` alone;
"+ slice 0" adds `imgmemo` and `hlmemo`; "+ blocks" adds `block` and
`noargs`; "+ runs, document" adds `run` and `doc`. Upstream is the status
line of its `watch` (without `--timings`).

| document | edit | today | kept | + slice 0 | + blocks | + runs, document | upstream | ratio |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `long.typ` | none | 235 | 89 | 88 | 53 | 37 | 11.0 | 3.3 |
| | end | 234 | 96 | 92 | 56 | 57 | 22.8 | 2.5 |
| | middle (every section) | 236 | 101 | 102 | 70 | 68 | 27.9 | 2.4 |
| `longer.typ` | none | 1216 | 498 | 499 | 304 | 171 | 53.8 | 3.2 |
| | end | 1247 | 503 | 507 | 313 | 307 | 118 | 2.6 |
| | middle (every section) | 1225 | 569 | 565 | 375 | 366 | 138 | 2.7 |
| `showcase.typ` | none | 268 | 51 | 21 | 18 | 14 | 5.2 | 2.7 |
| | end | 268 | 49 | 24 | 19 | 19 | 7.0 | 2.7 |
| | middle | 267 | 48 | 24 | 20 | 19 | 8.3 | 2.3 |
| deck | none | 1690 | 431 | 319 | 320 | 307 | 6.4 | 48 |
| | end | 1792 | 456 | 332 | 322 | 327 | 16.7 | 20 |
| | middle | 1768 | 458 | 326 | 331 | 329 | 17.2 | 19 |
| | theme comment | 1746 | 452 | 311 | 312 | 308 | 5.9 | 52 |
| | theme value | 1743 | 1597 | 378 | 375 | 393 | 43.5 | 9.0 |
| touying | none | 159 | 19 | 18 | 13 | 6.8 | 3.0 | 2.3 |
| | end | 155 | 24 | 22 | 18 | 17 | 10.7 | 1.5 |
| | middle | 153 | 29 | 27 | 25 | 21 | 13.8 | 1.6 |
| | package file | 151 | 116 | 114 | 109 | 111 | 83.4 | 1.3 |
| handbook | none | 92 | 27 | 26 | 24 | 15 | 4.7 | 3.1 |
| | end | 93 | 30 | 30 | 26 | 25 | 9.1 | 2.7 |
| | middle | 92 | 31 | 31 | 26 | 25 | 9.3 | 2.7 |
| | bib file | 92 | 28 | 28 | 25 | 16 | 10.2 | 1.6 |
| | package file | 93 | 86 | 79 | 78 | 76 | 21.0 | 3.6 |

The ratio is the last probe column over upstream. Three kinds of rows are
above 3. Where nothing or only a comment changed, only the export runs,
and the ratio is the PDF writer's. The deck's rows are its export: 290 to
305 ms of each, the images (3.4); without the export the deck takes 2, 21,
24, 2 and 88 ms. The handbook's package edit changes the footer of every
page: upstream repeats 502 of its 571 line-breaking runs (counted in its
`--timings`) and lays out the 29 page runs on several threads; the port has
one.

Slice 0 in a first compilation (no stores kept): `showcase.typ` 345 ms to
245 ms with the image and 229 ms with the highlighting as well; the deck
1710 ms to 651 ms; the handbook 172 ms to 164 ms.

### 3.4 Where the rest goes

The phases of the last probe column after an edit at the end, against
upstream's (`--timings`):

| document | | evaluation | layout | export |
| --- | --- | ---: | ---: | ---: |
| `long.typ` | probe | 2.4 | 18 | 37 |
| | upstream | 1.5 | 11 | 12 |
| `longer.typ` | probe | 12 | 126 | 170 |
| | upstream | 6.5 | 57 | 54 |
| `showcase.typ` | probe | 0.7 | 4.4 | 14 |
| | upstream | 1.0 | 1.7 | 4.4 |
| handbook | probe | 1.2 | 8.3 | 15 |
| | upstream | 0.8 | 4.5 | 3.7 |

Samples of the repeating process (shares of a recompilation):

- `long.typ`, stores kept, nothing else: layout 59 % (the equations 19 %,
  document-level realization 15 %), export 40 %. With everything, after an
  edit at the end: export 64 %, document-level realization 19 %, the flow
  5 %, evaluation 4 %, validating introspector reads 3 %.
- `showcase.typ` with the image kept, after an edit at the end: realization
  55 %, of which nine tenths are `RawElem::highlight` (syntect's regular
  expressions), export 35 %.
- The deck today: `RasterImage::new` 71 % (228 decodings of 28 images, one
  per layout of an image), export 16 %. With everything, nothing changed:
  `handle_image` 97 %, about half of it converting the samples (72
  conversions per export, 137 to 143 ms) and half compressing them.
- The touying document today: evaluation 70 %.

### 3.5 What follows

1. The existing stores are most of it where the time is evaluation and
   paragraphs: a factor of 2.4 to 2.5 (`long.typ`, `longer.typ`), 3 (the
   handbook), 5 to 6 (`showcase.typ`, touying) after a small edit. An edit
   that reaches everything leaves little: the touying document's package
   edit 151 ms to 116 ms (the other modules of the package), the
   handbook's 93 ms to 86 ms, the deck's theme value nothing.
2. Three missing functions dominate documents with images or code, in a
   first compilation too: decoding (the deck 2.6 times faster,
   `showcase.typ` 1.4 times, at once), highlighting (`showcase.typ` 71 ms
   to 50 ms per recompilation, the handbook 92 ms to 74 ms), the PDF's
   images (290 ms of every compilation of the deck).
3. The block level is the next step for documents of text: 38 to 39 % of
   what is left of the bench documents, 13 to 21 % of `showcase.typ`, the
   touying document and the handbook, nothing for the deck.
4. Page runs and the document pay when nothing changed (a file saved
   without a change, a comment, a bibliography entry that is not cited) and
   for decks, where a run is a slide: the touying document 13 ms to 7 ms
   unchanged, 18 ms to 17 ms after an edit at the end and 25 ms to 21 ms
   after one in the middle. Hashing the children for the key costs 4 to
   5 ms per iteration of `longer.typ`.
5. What is then left is not memoization: the document-level realization
   (which upstream repeats too), the flow, and the PDF writer, 1.6 to 2.6
   and 3.1 to 4 times upstream's.
6. All of this is a probe that validated less than the design will (3.1,
   section 8): the gains are upper bounds, and the first step of slice 1
   measures what recording and validation take away from them.

## 4. Inventory

Upstream's 59 memoized functions, by what the port does with them. "Per
compilation" is `memo_generation`; "process" is a cache that is never
dropped; "decode cache" is dropped as a whole by `@library.evict`.
Tracked arguments are abbreviated: W world, I introspector, T traced,
S sink (mutable), R route, C context, L locator.

| upstream function | hashed arguments | tracked | port | matters (section 3) |
| --- | --- | --- | --- | --- |
| `typst_eval::eval` | library, source | W T S R | `eval_source_memoized`, imports only, per compilation; key: file id; valid for world and library identity, source text, route and traced answers | yes: 70 % of a touying document |
| `eval_closure` | func, closure, library, args | W I T S R C | `memoized_closure`, per compilation; key: func, args, traced span; exact arguments; context, route, introspector tracked; world assumed fixed | yes, with `eval` |
| `eval_string` | library, string, spans, mode, scope | W I S C (+T, R made inside) | not memoized (`eval/lib.mbt`, `eval_string`) | not measured: no document here evaluates strings in a loop |
| `layout_document_impl`, `layout_document_for_bundle_impl` | library, content, styles | W I T S R (the bundle variant also L) | not memoized (`layout/pages.mbt`). Since slice 3: `memoized_pages`, kept across compilations; key: content, styles, route (the bundle variant: the resolved locator too) | only when nothing changed |
| `layout_page_run_impl` | library, children, initial styles | W I T S R L | not memoized (`layout/pages_run.mbt`). Since slice 3: `memoized_pages`, kept across compilations; key: children with their styles, initial styles, the resolved locator, route | decks (a run per slide); else only when nothing changed |
| `layout_fragment_impl` | library, content, styles, regions, column | W I T S R L | `memoized_layout`, per compilation; key also has the resolved locator and the whole route | yes |
| `layout_single_impl`, `layout_multi_impl` | library, block, styles, region(s) | W I T S R L | not memoized (`layout/flow_collect.mbt`); since slice 2 `memoized_layout`, keyed like fragments (section 8, "Slice 2 as built") | yes: 40 % of what is left of `long.typ` |
| `layout_par_impl` | library, par, styles, region, expand, situation | W I T S R L | `memoized_layout`, per compilation | yes |
| counter `sequence_impl` | library, counter, selector | W I T S R | `memoize`, per compilation | small |
| state `sequence_impl` | library, state | W I T S R | not memoized, on purpose: its values may hold what compares by identity (`library/memo.mbt`, header) | not measured |
| `html_document_impl`, `html_document_for_bundle_impl`, `html_block_fragment_impl` | as the paged ones; the fragment also `whitespace` | W I T S R (L) | not memoized (`html/`) | not measured (no HTML document here) |
| `bundle_impl`, bundle `export_pdf`/`png`/`svg`/`html` | bundle parts / document, options | W I T S R / the link resolver (not `export_png`) | not memoized (`bundle/`) | not measured |
| `Image::new_impl`, `RasterImage::new_impl` | kind, alt, scaling / data, format, icc | none | not memoized: `RasterImage::new` decodes on every layout of the image (`library/image_raster.mbt`) | yes: 71 % of the deck, 73 % of `showcase.typ` |
| `SvgImage::new`, `SvgImage::with_fonts_images` | data (, families, file) | none / W | not memoized (`library/image_svg.mbt`); since step 2 of slice 1 the image is identified by its linked images too (5.5) | not visible in `showcase.typ` (one small SVG) |
| `PdfDocument::new`, `PdfImage::new` | data / document, page | none | decode cache (`pdf_document_cache`) / cheap | no |
| `Packed<RawElem>::highlight` | element, routines, styles | none | not memoized (`library/text_raw.mbt`, `raw_elem_synthesize`) | yes: half of what is left of `showcase.typ`, a fifth of the handbook |
| `RawSyntax::decode`, `RawTheme::decode` | bytes | none | decode caches | no |
| `Bibliography::decode`, `CslStyle::from_data`, `from_archived`, `Works::generate_impl` | data / style / elements | none / W I T S R | decode caches; `works_cache` kept the last introspector's works; since step 2 of slice 1 `Works::generate` is an entry of `memoize`, per compilation (5.5) | not visible |
| `Plugin::call`, `transition`, `module` | plugin, arguments / bytes | none | decode caches (`library/plugin.mbt`) | not measured |
| `Font::instantiate`, `instantiate_impl`, `glyph_frame`, `font_overhang_table`, `create_shape_plan` | font (, variations, glyph, shaping key) | none | process caches | already there |
| math `GlyphFragment::planned`, `base` | styles, text or glyph, class, math size, stretch or features | W | not memoized (`layout/math_glyph.mbt`) | not visible (equations are 19 % of what is left of `long.typ`, all of it removed by the block level) |
| `TextItem::bbox`, `determine_prefix_widths`, `process_stops`, `Bytes::lines`, `localized_str`, `parse_language_bundle`, `CslStyle::input` | their arguments | none | not memoized | not visible |
| typst-pdf `convert_raster`, `build_font`, `convert_pdf` | image, interpolate / font / PDF image | none | not memoized: per export, and `convert_raster` per occurrence of an image (`pdf/image.mbt`, `handle_image`) | yes: 97 % of what is left of the deck |
| typst-svg `WebImage::new`, `to_base64_url`, `convert_geometry_to_path` | image / geometry | none | not memoized | not measured (PDF output) |
| typst-render `build_texture`, gradient `cached`, glyph `rasterize` | image and size / gradient / glyph | none | glyph bitmaps: process cache (`render/text.mbt`); the others not memoized | not measured (PDF output) |

In five lines: (1) evaluation: modules and closure calls are memoized per
compilation, the main file and `eval_string` are not; (2) layout:
paragraphs and fragments per compilation, blocks, page runs and the
document not; (3) introspection: the counter sequence yes, the state
sequence deliberately not; (4) decoding: fonts, shape plans, syntaxes,
themes, bibliographies and plugins are kept by content, raster and SVG
images and highlighted raw text are not kept at all; (5) export: nothing
is kept but the CLI's page hashes for PNG and SVG.

## 5. Validity across compilations

### 5.1 What can change between two compilations of one world

| what | how the engine reads it | how a result learns of a change |
| --- | --- | --- |
| text of a source file | `World::source(id)` | recorded read, fingerprint of the source (5.2) |
| bytes of a file (data, images, package manifests) | `World::file(id)` | recorded read, fingerprint of the bytes |
| a file appears or disappears, becomes unreadable or a directory | the same calls raise a `FileError` | the read is recorded with the fingerprint of the error |
| package files | the same calls with a package root | the same |
| fonts | `World::book()`, `World::font(index)` | recorded reads, fingerprints of the book and of the font |
| the date | `World::today(offset)` | recorded read, fingerprint of the answer |
| `sys.inputs`, features, formats, routines: the library | `World::library()`, once per compilation (`typst/lib.mbt`, `compile_with`); then `Engine.library` | the library is compared by identity in every entry (step 1 of slice 1) and becomes part of every key (5.3) |
| the main file | `World::main()`, once per compilation (`compile_impl`), outside of every memoized function, as upstream | nothing depends on it but the source it names, which is read through the tracked world and is the key of its evaluation (step 3) |
| the traced span | `Engine.traced` | in the key (closure calls, layouts) or validated by its answers (modules); unchanged |

### 5.2 The tracked world

Revision 5 of this section, after the fourth review
(`docs/reviews/incremental-design-4.md`) and as built in step 1 of slice 1
(`library/tracked_world.mbt`).

**The reads.** A read is one of

    Source(FileId) | File(FileId) | Book | Font(Int) | Today(Duration?)

and its answer has a 128-bit fingerprint:

- `Source(id)`: upstream hashes a source as its id, its text and its
  numbered tree (`typst-syntax/src/source.rs`, `SourceInner`), once per
  state. The tree is in it because span numbers are not a function of the
  text: a file that is edited and edited back has the old text and new
  numbers where it was reparsed, and a module evaluated from the old tree
  holds spans that are now other nodes' or nobody's. The port's fingerprint
  is equal only where upstream's is and does not hash the tree: hashing a
  megabyte of text takes 0.7 ms, hashing its tree 25 ms. A `Source` never
  changes (5.4, as built: an edit returns another source). It has a number
  that no other source of the process has (`Source::serial`) and knows
  whether it is pristine: made by `Source::new`, not by an edit and not
  around a tree that was given (`with_root`). A pristine source is
  fingerprinted by its id and its text, since parsing and numbering are
  deterministic and its tree is a function of the two; any other by its id
  and its number. The fingerprint of a text is kept in the source. Two
  parses of one text in two `Source` objects are the same answer; the
  result of an edit is the same answer only as the same object. (Revision
  4 had a revision counter here, for a source that an edit changed in
  place; with sources that never change the object is the state.)
- `File(id)`: the length and the bytes, as upstream's `Bytes` hashes; kept
  by the identity of the `Bytes` object (`data_hash`), so a world that
  returns the same object pays nothing. The CLI's file store reloads a
  file that is read after a reset, so there every file that is read is
  hashed once per compilation, as upstream.
- A failed read of a source or of a file: the error, by kind and with its
  payload (`FileError` derives `Hash`; `NotFound` holds the path).
- `Book`: the state of the book object: `FontBook::edition`, zero for a
  book without fonts and otherwise a number that no other state of any
  book has, a new one with every `FontBook::push`. Upstream's world hands
  out `&LazyHash<FontBook>` and comemo compares the hash of the infos; the
  port did so at first, and hashing the infos of a system's fonts with
  their coverage (1354 faces on macOS 26) took 3 ms of every process, 1 %
  of a compilation that uses them. So two books with the same infos are
  two answers.
- `Font(index)`: the font object (`Font::serial`), a constant for `None`.
  Upstream compares `Hash for Font`, the hash of the data and the index;
  the port did so at first, and the data of one system font collection
  (PingFang, which `bench/showcase.typ` uses) took 24 ms to hash, 8 % of
  that compilation. So two font objects of the same data are two answers.
  (`Fingerprint for Font` and `==` stay upstream's: where a font is in a
  key or in a frame's hash it is its data and index.)
- `Today(offset)`: the date or its absence, per offset.

The two identities are stricter than upstream and cost reuse only where a
world makes a new book or new font objects for a later compilation; the
worlds of the CLI, of `doc` and of the runner keep theirs. Section 10 has
them as a deviation.

**The tracked world.** `Engine.world` is a `TrackedWorld`: the `&World` in
a private field, the predicate for its volatile files (below), and, while
it is in a scope, the state of the scope. Its methods are the five reads;
`library` and `main` are not among them. A host makes one where it builds
an engine (`TrackedWorld::new(world, volatile_files~)`); making one opens
no scope and takes no token, and there is no way back to the raw world.
MoonBit's privacy is per package, so for `library` itself "only
`tracked_world.mbt` reads the raw field" is a convention, which
`scripts/tracked_world_check.py` holds together with two more: a raw
`&World` is named in engine code only where a compilation is entered
(`typst/lib.mbt`), and `World::library` and `World::main` are called only
there. Outside of a scope the five methods pass through, and nothing is
looked up or stored in the three stores of memoized calls for an engine
that holds the world. (The caches by content of slice 0 are not stores in
this sense: they depend on no world and work wherever memoization is on.)

**The hooks.** The leaf reads, as the fourth review's search of the code
found them (it found none that the list of revision 4 lacked):

| read | where |
| --- | --- |
| `source` | `eval/import.mbt` `import_file`; `library/decimal.mbt` `warn_on_float_literal`; `library/engine.mbt` `world_range` (called for tracepoints in `eval/call.mbt` `trace_call`, `eval/import.mbt`, `library/styles.mbt`, `library/grid_resolve.mbt`, `doc/lower.mbt` `Lowering::trace_range`: a tracepoint is only added if the range says so, `library/diag.mbt`, and the error is kept by a module entry, so the read is a dependency and not presentation) |
| `file` | `eval/import.mbt` `resolve_package`; `library/loading.mbt` `DataSource::load` (every loading function and element: `read`, `json`, `yaml`, `toml`, `xml`, `csv`, `cbor`, `plugin`, `image` with its ICC profile, bibliographies and CSL styles, raw syntaxes and themes); `library/pdf_standard.mbt` `pdf_attach_elem_data_parse`; `library/image_svg.mbt` `SvgImageResolver::load_or_error` (linked images) |
| `book`, `font` | `layout/inline_shaping.mbt` `ShapedText::measure`, `ShapedText::hyphen`, `get_font_and_covers`; `layout/inline_line.mbt` `apply_shift`; `layout/math.mbt` `get_font`; `library/image_svg.mbt` `SvgImage::with_fonts_images` (book), `SvgFontResolver::load` (font); `library/text.mbt` `check_font_list` (book) |
| `today` | `library/datetime.mbt` `impl_datetime_today` |

and what carries a world to them, each of which holds the tracked one:
`Engine.world` and whatever holds an engine; `ShapingContext.world`,
`MathShapingContext.world` and `SharedShapingContext::world`
(`layout/inline_shaping.mbt`, `layout/math_shaping.mbt`); the parameters
of `math_shape`, of `GlyphFragment::planned` and `base` and the closure in
`planned` (`layout/math_glyph.mbt`), of `apply_shift` and of `get_font`;
`SvgFontResolver.world` and `SvgImageResolver.world`, which keep it for
the parser's callbacks; `BibliographyElem::keys`, `database` and
`csl_style`, `Bibliography::load` and `CslSource::derived_style`
(`library/bibliography.mbt`); `RawSyntax::load` and `RawTheme::load`
(`library/text_raw.mbt`); `DataSource::load` and `load_many`; `analyze`,
the stored `Introspection.diagnose` and `History::compute`
(`library/convergence.mbt`).

Not tracked, because they run outside of every memoized call, as upstream:
`compile_impl` (`main`) and `compile_with` (`library`). (In step 1 also
the source of the main file and, in `hint_invalid_main_file`, that of its
`.typ` sibling, which were asked of the raw world. Since step 3 they are
read through the tracked world, still outside of every memoized call, and
`scripts/tracked_world_check.py` allows no tracked read of a raw world
where a compilation is entered.) `@library.analyze` is not among them: it runs
inside the compilation (`typst/lib.mbt`), and the engines that
`History::compute` builds (`library/convergence.mbt`) replay
introspections, which enter the counter sequence's store and call the
document's functions. They get the compilation's tracked world, and its
library with it: `History::compute` asked the raw world for the library,
which the tracked world does not have. Hosts (the CLI's diagnostics and
dependencies, `kit/diagnostics.mbt`, `doc`'s review) keep their own
`&World`.

A host function gets the engine and can capture anything else. The
contract is the one a native function has: what it returns depends on its
arguments and on what it reads through the engine, and it does not make a
new value that compares by identity on every call (a host function, a
module, a descriptor of a function, element or type). The design relies
on it only for host functions that a library defines in its scope, which
the library's serial number covers (5.3). Any other host function is in
the fingerprint of whatever holds it, with `fingerprint_identity` set, and
such entries end with their compilation (5.4).

**The contract of a world**, as today plus what validation needs: it does
not change during a scope (below); `font(index)` may be asked for an index
of an older book and answers `None` or whatever is there now (upstream's
doc comment of `World::font`); `today` answers the same for the same
offset during a scope; a font is what its data and index say it is
(`Fingerprint for Font` covers those two, as upstream's `Hash`: a face
that a host passes to `Font::new` must not behave differently for the same
data and index). During a scope it hands out the same book object and,
for an index, the same font object: an answer is the object (above), and
a world that makes a book per call looks like a world that changes (the
default of `World::book`, a book without fonts, is one answer whatever
object it is). And what a world returns is read-only for everyone, the
host included, since the identity of an answer is kept in the object: a
book changes by `FontBook::push` or by being replaced by another book
(not through the arrays that `FontBook::select_family` and `families` hand
out, nor through those of a `FontInfo`); bytes are immutable; a source
never changes (`Source::edit` and `Source::replace` return another one,
`Source::root` and `Source::lines` are for reading, `Source::with_root`
publishes the tree it is given: the header of `syntax/node.mbt`).

**Scopes.** A scope is a stretch of work in which one world is fixed and
during which results may be looked up. `TrackedWorld::scoped(f)` runs `f`
in one: if the world is in a scope already, `f` just runs; otherwise a
scope is opened with a new token from a process-wide counter, an empty
table of answers and an empty log, and closed when `f` returns or raises.
The entry points: `compile_with`, which makes the tracked world of the
compilation and runs all of it, `with_layout_memo` included, in its scope;
`eval_source`, `eval_string` and `eval_string_mapped` (`eval/lib.mbt`),
which run in the scope of their world if it is in one (the main file and
`eval` during a compilation) and in one of their own otherwise (the CLI's
`eval`, the field evaluation of `query`); `Document::lower`
(`doc/compile.mbt`). What decides is the world of the engine at hand, not
the route. This replaces `compilation_epoch` and `note_evaluation`, and
the `evaluation_begin` and `evaluation_end` that stood in for the latter
(pull request 65). Outside of a compilation that gives three cases. A
string that a host evaluates and every file it imports, directly or
through another module, are one scope, so a file is one module in it (the
route of a string is the root like that of a file evaluated on its own,
which is why the route cannot decide). All fragments of one
`Document::lower` are one scope, which the lowering opens around them. Two
evaluations of a host in a row are two scopes, and the second sees the
files as they are then. (`typst/recompile_wbtest.mbt`,
`typst/tracked_world_wbtest.mbt`, `doc/volatile_test.mbt`.)

The table and the log are the tracked world's, not state of the process
like the route and traced-file logs of `library/memo.mbt`. So a
compilation inside another (a host function that compiles) is a scope of
its own with its own answers, and an engine of the outer scope that is
used while the inner one is open reads and records where it always did.

The stores: `memoize` and `memoized_closure` are consulted in a
compilation (`with_layout_memo`) for an engine whose world is in a scope;
the module store (`eval_source_memoized`) in any scope. In step 1 a module
entry is found in the scope that stored it only, and dropped once that
scope is closed and another scope asks: it is found by the text of its
file until step 3, and its own source is read before its reads start, so
its reads do not say all that it was made of. (Before, the module store
was also consulted outside of every compilation: an evaluated string that
imports found the modules of the evaluation before it.) Since step 3 a
module entry is found by the fingerprint of its source, in any scope that
is open, and is valid by its reads; its scope only says when it is
dropped, which is as before (section 8, "Step 3 as built").

**A read through another world.** The log of a world holds the reads of
that world. A memoized call that reaches another tracked world (a host
function that evaluates or compiles with a world of its own, or that kept
an engine) returns something that may depend on reads its entry would not
hold. So a read through any tracked world, in a scope or not, marks the
calls in progress of every other tracked world as a volatile read does:
they are not stored. Two things count as such a read: an entry with reads
that is looked up for another world (its reads are that world's), and a
scope of another world that is opened (a compilation reads its library
and its main file around the tracked methods and may fail before it reads
anything else).

**The answers of a scope.** Since the world is fixed, the fingerprint of a
read's answer is computed at most once per scope: a table from read to
fingerprint (sources and files by file id, fonts by index). This is what
comemo's accelerator does for the hashes of validation calls, per tracked
reference and until `evict`; the answers live until their scope ends. The
world is still asked for the answer itself by every read.

Worlds whose files change during a scope exist: `doc`'s `SessionWorld`
serves the origin listing, which grows whenever an origin is registered,
also while callbacks are lowered during layout, and markup snippets whose
files come into being then (`Registry::register` and `Registry::snippet`,
`doc/origin.mbt`; their ids are interned from the paths `<edsl-origins>`
and `<edsl-markup-N>`, so Typst code can name them). Such files are
declared by a predicate on file ids that is given when the tracked world
is made, so that every scope of that world has it: `compile_with` takes it
as a parameter and passes it on, `Document::lower` makes its tracked world
with it, and the engines of `History::compute` hold the compilation's
tracked world. `doc`'s predicate is by path, not by what the registry
holds at the moment (`Registry::changes`): the listing, and the
project-rooted ids that `virtual_file` makes in the session's directory
for `<edsl-markup-N>` with any `N`, so that a snippet that does not exist
yet, whose read today falls through to the caller's world, is covered.
Three rules follow from it.

- A read of a volatile file is not answered from the table, and it marks
  the log (a count of such reads that a call compares with what it was
  when the call started). A memoized call whose part of the log holds the
  mark is not stored, also when it ends with an error that would be kept
  (a module's); the mark stays for the callers.
- A module entry is neither looked up nor stored for a file that is
  volatile itself (its source is read before the entry's part of the log
  starts, `eval/import.mbt`, `import_file`).
- An entry that exists is not taken if one of its source or file reads is
  volatile in the scope at hand, whatever the file answers now. Stores
  cross worlds and file ids are interned by path: an entry that another
  world stored for a real file `<edsl-origins>` must not be found, and
  stamped, in a session whose listing happens to start equal.

So nothing that depends on a volatile file, directly or through a call, is
ever found, in its scope or in another. (What `doc` builds from its registry without the world,
the spans of lowered content, is not affected: equal content with equal
spans means the same under any session's registry, since spans are
resolved through the registry of the report at hand, `doc/review_click.mbt`,
`doc/lint_frames.mbt`.)

**Recording.** A memoized call notes where the log is when it starts
(`reads_begin`). A tracked method pushes its read (the number the scope
gave it) unless no memoized call is in progress, or the read is already in
the part of the innermost one: the scope keeps, per read, where it was
pushed last, so that is a comparison and not a search (comemo's
`MergedSink::emit` does not go on to the constraint around once the inner
one has the call). Shaping asks for the book and a font per text run; a
paragraph logs each once. A read that is only in the caller's part is
pushed again for the call inside. A failed read is pushed before it
raises. When the call returns (`reads_end`), what was pushed since is
deduplicated in the order of first occurrence, paired with the
fingerprints from the table and returned for the entry, and the log is cut
back to the deduplicated reads, which are thereby the caller's too. When
it raises (`reads_abort`), nothing is returned and its reads stay in the
log: a call around it may go on (`Engine::delay` puts errors aside). Both
happen on every path, before anything is decided about storing: an entry
is not stored if its call was not cacheable, read a volatile file, or the
store's generation changed during the call (a nested compilation), and
its reads are its caller's all the same.

**On a hit.** World reads are the last condition of a hit that is looked
at, after the key, the arguments, the library, the context, the route and
the introspector reads. An entry is valid for the world if none of its
reads is volatile in this scope and, for each of them in the order in
which the call first made them, the table's fingerprint is the entry's; a
read the scope has no answer for is made for that. The check stops at the
first read that differs. Since a call is a function of its arguments and
of the answers it got, a read is thereby only made if a run of the call
from scratch would make it too: validation asks a watching host for no
file that the compilation does not depend on. (For validity alone the
order would not matter.) An entry that passed is stamped with the scope's
token and its world reads are not checked again in that scope. The stamp is about the world only: the arguments, the context, the
route and the introspector reads are checked on every lookup, as today.
The reads of an entry that is taken are pushed to the log, as if the call
had run: the same merge that `note_route_queries` and
`IntrospectionRecorder::merge_into` do today, and what comemo does by
emitting validated calls to the outer constraint. The reads of a candidate
that is rejected are not.

**The library** is compared by identity in every entry of the three
stores in step 1 (module entries did so before): a closure that evaluates
`sys.inputs.x` reads nothing of the world, and two libraries can meet in
one compilation through an engine that a host builds. Step 3 replaces the
comparison by the serial number in the key (5.3).

**Costs.** Measured in step 1 (aarch64 macOS, native release, other
agents building on the same machine). The budget for recording plus
validation was set before anything existed: 1 % of a from-scratch
compilation and 5 % of a recompilation in which everything hits.

What is paid where:

- Per read: one check whether another world is recording, the slot of the
  read in the scope's table, and a comparison of the position of its last
  push with the start of the call in progress. A read that is in the
  scope's answers and in the part of the call in progress allocates
  nothing.
- Per memoized call: two integers saved and restored; for a call that
  read something, a deduplication of its part of the log (a mark per slot,
  no search) and a lookup among the last eight read lists the scope made.
  Entries with the same reads share one list: most calls of a compilation
  read what a call before them read (the book and the fonts of the text),
  so a compilation of `bench/long.typ` allocates 45 objects in
  `tracked_world.mbt` in all (of 7.7 million, 88 more than the base), one
  of the touying document 159 (of 8.3 million, 440 more;
  `scripts/alloc_sites.py`).
- Per hit: for an entry without reads a test; otherwise the stamp, and the
  pushes of the merge, which the position check mostly drops.
- Per scope and file: a fingerprint of a source or of bytes that are new.
  A megabyte of text is hashed in 0.7 ms and its tree in 25 ms, which is
  why a source is not fingerprinted by its tree (above): the touying
  document's 0.8 MB of sources cost 0.5 ms once per `Source` object, not
  18 ms, and the result of an edit costs nothing. Bytes are hashed once per object (`data_hash`), as before for the
  caches by content; the CLI's file store reloads a file that is read
  after a reset, so there every file that is read is hashed once per
  compilation, as upstream (the 2.4 MB of the deck's images: 3.2 ms by the
  probe), unless the store hands back the `Bytes` it had when a reload
  gives equal bytes (`kit/files.mbt`, "not scheduled").
- Books and fonts: nothing, since their answers are the objects. As hashes
  they were what broke the budget: 3 ms and 24 ms in every compilation of
  `bench/showcase.typ` with system fonts (8 % by the first measurement).

Against the base of the step (`main` at `12e58c4` with the renames that
the toolchain of 2026-10-10 needs, both built with it), the least of
twelve runs each, in turns (instructions retired and cycles of
`/usr/bin/time -l`; the instruction counts repeat to 0.02 %, the least
cycles to between 0.3 and 0.8 %):

| workload | instructions before | after | change | cycles before | after | change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 66.1 M | 64.5 M | -2.4 % | 23.7 M | 23.0 M | -2.9 % |
| `query long.typ heading` | 2961.3 M | 2962.4 M | +0.04 % | 721.3 M | 722.7 M | +0.2 % |
| `long.typ` to PDF | 3521.8 M | 3525.3 M | +0.10 % | 841.0 M | 848.0 M | +0.8 % |
| `query longer.typ heading` | 14847.7 M | 14870.4 M | +0.15 % | 3566.6 M | 3542.8 M | -0.7 % |
| `showcase.typ` to PDF, system fonts | 4374.8 M | 4371.9 M | -0.07 % | 987.2 M | 985.7 M | -0.1 % |
| `showcase.typ` to PDF, embedded fonts | 3807.8 M | 3805.9 M | -0.05 % | 808.8 M | 808.4 M | -0.05 % |
| touying `theme-metropolis.typ` to PDF | 2642.0 M | 2663.3 M | +0.81 % | 677.3 M | 678.9 M | +0.2 % |
| ilm `bakers-handbook.typ` to PDF | 2343.0 M | 2344.4 M | +0.06 % | 562.8 M | 564.3 M | +0.3 % |

Wall time, 40 runs each in turns (hyperfine):

| workload | before: median (least) | after: median (least) | median | least |
| --- | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 7.3 ms (7.1) | 7.2 ms (6.9) | -1.8 % | -3.1 % |
| `query long.typ heading` | 211.1 ms (204.9) | 216.2 ms (208.2) | +2.4 % | +1.6 % |
| `long.typ` to PDF | 259.5 ms (243.3) | 260.8 ms (251.9) | +0.5 % | +3.5 % |
| `query longer.typ heading` | 1126.3 ms (1041.0) | 1090.3 ms (1035.9) | -3.2 % | -0.5 % |
| `showcase.typ` to PDF, system fonts | 298.6 ms (287.7) | 298.3 ms (294.3) | -0.1 % | +2.3 % |
| touying `theme-metropolis.typ` to PDF | 203.2 ms (197.6) | 203.6 ms (199.1) | +0.2 % | +0.8 % |

These spread by more than the budget (the medians between -3.2 % and
+2.4 %, with no sign in common with the instruction counts): on this
machine a difference of one per cent is not a thing wall time shows.

First compilation and recompilation in a watch session (medians of five
sessions with five edits each, one character appended; the durations of
the status lines; step 1 recompiles from scratch like the base, nothing
is kept yet):

| document | build | first compilation: median (least to most) | recompilation: median (least to most) |
| --- | --- | ---: | ---: |
| `long.typ` | base | 262.9 ms (254.8 to 338.4) | 265.0 ms (256.0 to 473.5) |
| | step 1 | 261.0 ms (255.3 to 339.7) | 266.5 ms (238.2 to 331.6) |
| `longer.typ` | base | 1290 ms (1240 to 1290) | 1350 ms (1230 to 1460) |
| | step 1 | 1290 ms (1290 to 1310) | 1340 ms (1260 to 1480) |
| `showcase.typ` | base | 247.5 ms (242.8 to 250.7) | 56.4 ms (52.8 to 58.4) |
| | step 1 | 247.7 ms (247.0 to 250.5) | 57.4 ms (54.6 to 68.2) |
| touying `theme-metropolis.typ` | base | 210.1 ms (206.4 to 213.4) | 179.9 ms (154.4 to 192.1) |
| | step 1 | 212.0 ms (206.9 to 219.4) | 178.5 ms (156.0 to 196.1) |

So recording costs up to 0.15 % of the instructions of a compilation of
the bench documents and 0.8 % of the touying document, whose closure
calls each save and restore the log's position and compare the library;
in cycles and in time it is inside what the machine's spread lets one
see. The budget of 1 % holds. The second budget cannot be measured before
something is kept: a recompilation in which everything hits does not exist
in step 1. What can be said: the hits of a compilation (every layout of
the second and later introspection iterations, every repeated closure
call) are in the numbers above, and validating an entry in another scope
is one table lookup per read of its list, once per list and scope, plus
the fingerprint of each file that is new. Step 5 measures it when it
keeps the first store.


### 5.3 The other inputs of a kept result

- **Library.** Upstream hashes it (or its routines) into the key of every
  memoized function that builds an engine or calls a routine. The port
  gives a `Library` a serial number and writes it into every key. For
  that a library must be made in one place and never change: `Library`
  stops being a record that anyone can build or update (today
  `pub(all)`; `tests/runner/realize_stage.mbt` makes libraries by record
  update), its `features` loses its `mut`, every way to derive a library
  from another goes through `LibraryBuilder` and takes a new number, and
  nothing reachable from it (scopes, styles, rules, `sys.inputs`, formats)
  is written after `build`. Two libraries with equal contents do not share
  results; a host that wants reuse keeps its library, as the CLI does.
- **Introspector.** Unchanged: the recorded reads are replayed on the
  introspector of the call (`IntrospectionRecorder::validate`), with the
  shortcut for the introspector the entry was computed with. Across
  compilations the shortcut applies when the document is reused, since the
  next iteration then runs on the same introspector object. The shortcut
  needs an introspector that answers the same forever.
  `ElementIntrospector::query` handed out the array it keeps
  (`library/introspector.mbt`), which a caller could change, and a host
  may keep an introspector and use it in a later scope. Since step 4
  `query` returns a view, and an entry keeps the number of its
  introspector instead of the object (`Introspector::serial`; 6.2).
- **Route, context, traced span.** Unchanged: in the key or recorded per
  entry today, and none of it depends on the compilation.
- **Sink.** Replayed as today. What travels in it is not all immutable.
  Diagnostics are objects whose `trace` and `hints` are appended to
  (`@library.trace`, `library/diag.mbt`), and so are the errors that a
  module entry keeps: an import of a file with an error adds a tracepoint
  to the kept error, again on every reuse. Traced values come with a
  `Styles` that `@typst.trace` hands to its caller and `Styles::unset` can
  change. The rule of 5.4 for mutable results applies to the sink and to
  kept errors. (Kept errors: built in step 3, a module entry keeps a copy
  of its errors and hands out a copy on every hit. The diagnostics and
  traced values of sinks: built in step 4, `Sink::kept` and
  `Sink::extend_from_kept`.)
- **Locator.** In the key, fully resolved (stricter than upstream's tracked
  locator; section 10).

### 5.4 Identity, spans, locations

**Syntax trees.** An edit must not change a node that a kept value holds.
Today it does (section 2). Two things would then be wrong: the capture
table would hand the old analysis and node fingerprint to a closure made
from a node that has changed (the table is by node identity), and a closure
of the previous compilation would run a body that its cached fingerprint no
longer describes. The design makes edits persistent, which is what
`Arc::make_mut` gives upstream. `Source::edit` works on a copy of every
node it writes, with its inner record and its children array: the nodes on
the path from the root to the edit (`update_parent`, `replace_children`);
every node, with all its descendants, in the range of siblings that
`InnerNode::numberize` renumbers; and the root itself when the incremental
reparse fails and the file is parsed anew. The source then installs the
new root and a new line index. A reparse that fails halfway has written
copies only. The contract that goes with it: a tree that is in a `Source`
is written by `Source::edit` alone; `SyntaxNode::synthesize` and
`synthesize_ranges` are for trees that are not (the evaluator applies them
to freshly parsed strings, `eval/lib.mbt`), and `Source::root` and
`Source::lines` are for reading. The cost is the copied path per edit, and
the renumbered siblings in the rare case that numbers run out. The capture
table stays per compilation; with persistent trees it could be kept
longer, which is not proposed before it is measured (it is part of the
evaluation column of 3.4).

*As built* (the syntax half of step 3; the header of `syntax/node.mbt` is
the contract, with every function that writes to a node and whom it is
for). The copies are the ones named above, and they are enough: the
reparser writes through `children_mut`, `update_parent` and
`replace_children` only, each on a node that it copied itself
(`SyntaxNode::make_mut`: the node, its inner record, its children array,
the warnings around it; the root in `reparse`, a child in `try_reparse`
before the recursive call), and `numberize` after an edit writes to the
replacement, which the parser just made, and to the neighbours that
`replace_children` takes into the renumbered range, which it replaces by
`deep_clone`s first. A path node keeps its span number (only the nodes of
a renumbered range get new ones), so a copy differs from the node before
in its children, its length, its count of descendants and its diagnosis.
Upstream copies the same records, and only if they are shared.

It goes further than this section proposed in one point: a `Source` and a
`Lines` are immutable too, and `Source::edit`/`replace`
(`Lines::edit`/`replace`) return the edited value. Whoever holds a source
across an edit has what a clone taken before the edit is upstream
(`source.rs:24`, `:107`); the file slot of a world keeps the source that
`replace` returned (`kit/files.mbt`). A source therefore has one state for
its lifetime: its fingerprint (5.2) can be kept in the object, as
upstream's `LazyHash` is, and the revision number of 5.2 is not needed to
tell states apart.

Measured (`moon run tests/edit_bench --target native --release`; one
character inserted or removed, the source before the edit dropped; the best
of three rounds on a machine that was not quiet, so a few per cent are
noise). "In place" is the port before (68aea3a), "persistent" the copies
alone, "now" with the line starts and the diagnosis flags as value types
(they were an allocation per line behind the edit and per child of the
edited node):

| `Source::edit` | in place | persistent | now | parse |
| --- | ---: | ---: | ---: | ---: |
| `bench/longer.typ` (555 bytes, the edit 17 nodes deep), time | 6.3 µs | 7.3 µs | 6.7 µs | 60 µs |
| allocations | 279 | 371 | 267 | 3 230 |
| a source of 1 MB (51 842 children of the root), start, time | 3.4 ms | 3.4 ms | 3.2 ms | 85 to 91 ms |
| middle | 2.6 ms | 2.8 ms | 2.5 ms | |
| end | 2.4 ms | 3.0 ms | 2.0 ms | |
| allocations: start, middle, end | 34 867, 17 711, 51 908 | 34 894, 17 723, 51 940 | 121, 331, 94 | 3.78 million (4.27 before) |

`Source::replace` adds the comparison of the two texts (2 to 4 ms for 1 MB,
unchanged). An edit was linear in the file before, with a small constant,
and is: the text is copied, the line starts behind the edit are computed
again, and the reparser walks the children of the node it edits for their
lengths and their diagnosis (a profile of the edit at the end of the 1 MB
source: a third the text, half those walks). What persistence adds is five
allocations per node on the path (the node, its record, its children
array), one reference per child of each, copied and counted, and a copy of
the line starts before the edit: in these runs 1 µs for the small source
and up to 0.6 ms for the large one at its end, where the line starts were
35 000 objects to count and are a block of values now. The `reparse` stage
(30 336 edits) takes 1.79 s instead of 1.78 s (and 0.17 s more with its
new check that the source before each edit is unchanged), the `recompile`
stage 33.9 s instead of 34.0 s, and a compilation from scratch what it
took (`bench/long.typ`: 228 ms and 231 ms).

**Spans.** A kept result holds spans: in content, in frames (glyphs,
links, tags), in the diagnostics of its sink. They are valid if the nodes
they name are still in their sources with the same numbers. That follows
from the keys: a span enters a result from an argument (content and
closures are hashed with their spans), from a source that was read (its
fingerprint covers the numbered tree) or from an introspector read (its
result is fingerprinted with its spans). So a module evaluation is keyed
by the fingerprint of its source, not by its text (built in step 3; it
was the text).

**Locations.** A location is a hash of the locator and the element. The
resolved locator is in the key of every layout entry, so a reused frame
holds the locations a fresh layout would compute.

**Modules.** Decided by the owner on 2026-10-11: exactly as upstream,
plugins included. Built in step 4 (section 8, "Step 4 as built"). What
revisions 3 and 4 recommended instead, equality by fingerprint, and the
alternative it was costed against are below as history.

Upstream has two rules that do not agree.

- `==` compares the objects (`typst-library/src/foundations/module.rs`,
  `PartialEq for Module`):

      self.name == other.name && Arc::ptr_eq(&self.inner, &other.inner)

- A memoized call is found by the hashes of its arguments (comemo keeps
  nothing else of them), and `Hash for Module` is derived: the name and
  the inner data, which is the scope, the content and the file id.

So two module objects that hold the same are two values to `==` and one
argument to every memoized call, and a call that is found returns what it
returned before, whichever module it is asked about now. The port has
both rules as they are: `Eq for Module` is the line above
(`library/module.mbt`), and the exact comparison that an entry makes of
its arguments takes a module by its fingerprint (`modules_memo_equal`,
`library/memo.mbt`). It took modules by identity before, behind a flag of
the fingerprint (`fingerprint_identity` for the modules that
`Module::canonical` had not marked): the port was the stricter one, and
that is gone with `Module::canonical`. Two consequences, both upstream's.

*Within one compilation.* Where a document has two modules with one
hash, a call at one call site (the same function, arguments with the
same spans) that is given the second returns what it returned for the
first. A document compiled by the command line gets two such modules
from two plugins that export no function: their modules are empty
scopes. These answers of a compilation from scratch changed in the port,
to upstream's (`typst query` of the upstream binary of `e58a63af`, with
`a` and `b` the modules of two such plugins, `id(m) = m`,
`capture(m) = () => m`, `pick(d) = d.m`):

| expression | upstream | port before | port now |
| --- | --- | --- | --- |
| `(a, b).map(m => m == a)` | `(true, true)` | `(true, false)` | `(true, true)` |
| `(a, b).map(same)` with `same(m) = m == a` | `(true, true)` | `(true, false)` | `(true, true)` |
| `(b, a).map(m => m == a)` | `(false, false)` | `(false, true)` | `(false, false)` |
| `(a, b).map(id).map(m => (m == a, m == b))` | `((true, false), (true, false))` | `((true, false), (false, true))` | as upstream |
| in `for m in (a, b)`: `id(m) == m` | `(true, false)` | `(true, true)` | `(true, false)` |
| the same with `pick((m: m)) == m` and with `id((m, (m: m))).at(1).m == m` | `(true, false)` | `(true, true)` | `(true, false)` |
| the same with `(capture(m))() == m` | `(true, false)` | `(true, false)` | `(true, false)` |
| `(a, b).map(both.with(b))` with `both(m, n) = m == n` | `(false, false)` | `(false, true)` | `(false, false)` |
| `(a, b).map(m => held(metadata(m)))` with `held(body) = body.value == a` | `(true, true)` | `(true, false)` | `(true, true)` |
| `a == b`, `capture(a) == capture(b)` | `false`, `true` | the same | the same |
| at two call sites: `id(a) == a`, `id(b) == b` | `true`, `true` | the same | the same |

(The getter in the loop was upstream's answer before: a closure's
equality is its hash, upstream's and the port's, so the call of the
getter that captured `b` was answered as the call of the getter that
captured `a`. That hole of the old rule, identity for a module that is
an argument and its hash for one that a closure captured, is an
inconsistency that the decision removes.) The rows are
the cases "modules: .." of `typst/oracle_wbtest.mbt`, generated from the
upstream binary. Such a document says something else with the port's
memoization off, where every call is computed; upstream has no such
mode, and the cases are of a kind of their own (`memoized`) that is not
compared with it.

Two other ways to two modules with one hash need a host, and the port
answers as upstream does (`typst/modules_wbtest.mbt`): a file that is
evaluated twice (under IDE tracing a file that holds the traced span is
evaluated again for an evaluated string: `m == n` is `false` for the
document of the table below), and the modules of two libraries that a
host brings into one evaluation (`sys.inputs.m == math` is `false`, and
`(sys.inputs.m, math).map(id)` is the first module twice).

*Across compilations.* A kept call returns the module of an earlier
evaluation, and the file is evaluated again whenever anything it read
has changed. With

    // a.typ
    #let v = 1
    // comment 0

    // main.typ
    #import "a.typ" as m
    #let get() = m
    #get() == m

and a comment of `a.typ` changed, `typst watch` of the upstream binary
shows `false` and `typst compile` shows `true`: the new module has the
hash of the old one, `get` is a closure with the hash it had, and `get()`
is found. It stays so for every edit that leaves the hash of the module
as it was, and an edit that changes what the module holds gives `true`
again. The same for the module as an argument (`pick((m: m)) == m`) and
through another file (`held == theirs()`, with `b.typ` importing `a.typ`
and exporting the module and a getter). A state's value and a queried
element that hold the module compare as in a fresh compilation: their
context expressions are found again as a whole, comparison included.

The port does not show this yet, since nothing is kept from one
compilation to the next. With every store kept (the experiment of "Step 4
as built") it shows exactly it: the watch loop's SVG is upstream's
watch's, byte for byte, at each of the 13 steps of the three recorded
sessions at which upstream's watch differs from a fresh compilation, and
a fresh compilation's at the other four.

*What is given up.* The guarantee that a recompilation gives what a
compilation from scratch gives. It holds for everything but `==` between
a module that a found call returned and the module of the same file now
(or between two such results). The harness requires it everywhere else
and accepts that one difference only where it is proven to be upstream's:
at a step of a sequence that was recorded from the upstream binary's
`typst watch`, if the pages are byte for byte what upstream's watch
wrote (9.1, "As upstream's watch"; `tests/recompile/README.md`).

*Plugins.* Unchanged, which is upstream's: the module of a plugin is an
anonymous module of its functions, whose hashes carry the plugin (its
bytes and its transitions). Two plugins without functions have one hash
and are told apart by `==` alone (`(a == b, capture(a) == capture(b))` is
`(false, true)`, the second because closures compare by their hash). A
plugin's module is the same argument after the cache that made it was
dropped, with or without functions; to `==` the new module is another
object, as upstream's is once comemo has dropped the result of
`Plugin::module`. One thing follows for step 5: upstream drops that
result when it was not used for `max_age` evictions, and the port drops
its plugin caches as a whole on every `max_age`-th `evict`, used or not.
Once closure calls are kept, a document that compares a plugin's module
with one that a found call returned would say `false` after every tenth
compilation where upstream's watch says `true`. The plugin caches get
ages before that (6.1 has them among the caches that do).

*Interning.* One object per fingerprint would make `==` and the hashes
agree. A simple bounded interner cannot be used safely: one that keeps
its modules keeps every version of the main file's content (5 MB per
edit of `longer.typ`, 6.2), and one that forgets by age can forget a
module that a kept closure call, or a host, still holds, after which the
same contents are two objects again. Weak references, which the runtime
does not have, or a lifetime that is tied to every holder would do it;
both are machinery that neither rule needs. And interning by fingerprint
gives the equality of the alternative (a) below, not upstream's.

*History: the two alternatives that were costed* (revisions 3 and 4;
neither is built).

(a) *Equality by fingerprint.* Two modules are equal if they are the
same object, or if their names and fingerprints are equal and, where the
fingerprints cover host functions, those are the same objects in the same
order. `==` then agrees with what the stores take for one value, and a
recompilation gives what a compilation from scratch gives also where
modules are compared. It differs from upstream wherever a compilation
from scratch holds two module objects with equal contents:

    // a.typ
    #let probe(v) = v

    // main.typ
    #import "a.typ" as m
    #let n = eval("import \"a.typ\" as m; m", mode: "code")
    #let r = (m == n)
    #m.probe(r)
    #r

    // with a host that put another library's `math` into `sys.inputs`
    #let r = (sys.inputs.m == math)

| how `r` is obtained | upstream, and the port | with (a) |
| --- | --- | --- |
| the command line (`typst query main.typ "<r>" --field value`, with `#metadata(r) <r>` for the last line) | `true` | `true` |
| `trace` at the last `r` of `main.typ` | `true` | `true` |
| `trace` at the `v` of `probe`'s body: `a.typ` holds the traced span and is evaluated once with it and once, for the string, without | `false` | `true` |
| two libraries | `false` | `true` |

(Upstream's column was a throwaway program on the oracle's dependencies
that calls `typst::trace` with a world in memory; the port's is
`typst/modules_wbtest.mbt`.) It was recommended because the differences
needed a host. A review of the two open decisions
(`_build/codex-decisions.txt`, not in the repository) showed that this
was too narrow: with the modules of plugins identified by their bytes,
as (a) had them, `capture(a) == capture(b)` for two plugins without
functions is `false` in a document that the command line compiles, where
upstream says `true`.

(b) *Identity kept, and keys that carry it.* A module entry that is
valid hands out the object it has, and the identity of a module enters
what makes two keys interchangeable (a number per evaluation in the
fingerprint, a second component of every key, or a comparison of
closures by what they captured). Upstream's `==` then holds in every
compilation from scratch and after an edit. It needs the producer of an
identity to live as long as anything that holds it is found, and after
an edit that leaves a file's module equal, everything that holds the
module as a value misses once. A proxy for that, with the probe of
section 3: text appended to `touying/0.8.0/src/utils.typ`, which changes
the module's fingerprint and none of its bindings, recompiles the
touying document in 137 ms with 3171 closure calls and all 19 paragraphs
computed again, against 34 ms and 18 calls for a comment in the same
file when closures that captured equal modules are equal, and 155 ms
from scratch. These are a probe's numbers of a proxy, not measurements
of two implementations.

What was decided is neither: `==` is upstream's as in (b), and the
stores take modules by their hashes as upstream's do, so nothing misses
after a comment (the 34 ms) and nothing but upstream's own difference is
observable.

**What compares by identity.** By Typst's `==` (`library/ops.mbt`,
`library/func.mbt`, `library/dyn.mbt`; the inventory is in review 2,
finding 11): native functions, element functions and types, by their
descriptor; host functions; modules. Everything else compares by value
(closures by their hash, plugins by their bytes and transitions), or is
never equal (styles, gradients, tilings).

*Descriptors* are objects of the process: the generated ones are made
once, on first use, and shared by every library
(`library/funcs_gen.mbt`, `library/types_gen.mbt`; the tables of
`library/html_typed.mbt`, `library/accent.mbt`, `library/lr.mbt`), and a
host can make more (`NativeFuncData::new`, the constructors of types and
elements). Upstream hashes a descriptor as its address
(`typst-utils/src/static.rs:32`, `Hash for Static`: `state.write_usize(
self.0 as *const T as usize)`; `Type(Static<NativeTypeData>)`,
`Element(Static<ContentVtable>)` and `FuncInner::Native(Static<
NativeFuncData>)` derive `Hash` over it). The port fingerprinted texts:
a function's name, title and documentation, an element's key, a type's
long name, so two descriptors that a host makes with the same texts were
one value to everything that compares by fingerprint (review 3, finding
3). Built in step 4: a descriptor gets a number when it is made that no
other descriptor of the process has (`descriptor_serial`,
`library/func.mbt`), and that number is its fingerprint. Equal
fingerprints are the same descriptor; no flag is needed.

*Modules* compare by identity for `==` and are taken by their hashes by
the stores, as upstream's are (above): no flag either.

What is left that compares by identity and that the stores must not take
by a fingerprint is what upstream does not have: host functions. Their
fingerprint is a key of the host's, promised to be unique within a
compilation, and it carries `fingerprint_identity`. An entry compares the
host functions in its arguments as objects, also where a closure or a
module holds them (`closures_memo_equal`, `modules_memo_equal`: the same
host functions in the order in which the fingerprint visits them). Such a
value can enter a kept result, which includes its sink (traced values)
and its kept errors, in five ways, and each is closed:

- from an argument, a captured variable or the context of the call: the
  key carries the flag, and an entry whose key carries it ends with its
  compilation (built in step 4, one rule for every store: `MemoKey`,
  `library/memo.mbt`; it could only be found again by the same objects,
  which `doc` makes per compilation, `Session.hosts`);
- from an introspector read: the read is marked (`reads.lossy`) and the
  entry is only valid for the introspector it was computed with (as
  before; by its number since step 4);
- from the library's scope: the library is in the key;
- from a frame's tags: such a frame is not kept (`frame_cacheable`, as
  before);
- made by a host function during the call: one that is reached through a
  value is in the key, with the flag; one that the library defines must
  not make one per call (the contract of 5.2).

The engine's own functions create none. This is an invariant, not
something an entry checks when it is stored (that would fingerprint every
result); the checked mode of 9.1 checks it.

**Mutable results.** The rule: what an entry keeps and what it hands out
are different objects wherever the type can be written, on storing and on
every hit. As before: frames are cloned (copy on write), values are marked
shared. Built in step 4, each a copy or a read-only view (the table of
every store and cache is in section 8, "Step 4 as built"): diagnostics,
in sinks and in kept errors, with their `trace` and `hints`; the `Styles`
of traced values; the list of entries that `Works` hands out for a
bibliography (`library/bibliography.mbt`); the `HintedError` that the
plugin caches keep and raise again (`library/plugin.mbt`) and the errors
of a `CachedCell`; what an introspector's `query` returns. Not built,
because nothing keeps one yet (slice 3): a kept document, with its pages'
frames, its `DocumentInfo` (whose `author` and `keywords` are arrays) and
its format options (it shares only its introspector, whose answers are
views, 5.3). (Built in slice 3, section 8, "Slice 3 as built", "Copies":
as said here, and one thing more that this rule did not see. A
copy-on-write clone of a frame shares its groups, as objects, with the
frame it was made of, so the document that a host is handed gets frames
and groups of its own at every depth, `Frame::deep_clone`.) The introspections of a sink hold closures over selectors
and locations, which nothing writes.

### 5.5 State outside the arguments

A kept result is only as good as the claim that the function read nothing
but its arguments and its tracked inputs. Two rules for the process-wide
state the engine has (every top-level `let` of a `Ref`, `Map` or `Array`
in `library`, `eval`, `realize`, `layout`, `html`, `typst`, `syntax` was
looked at):

1. A cache that is not a store is a function of its key, and computing a
   missing value reads neither the world nor the introspector.
2. What is derived from a file is either part of the value that names the
   file, covered by that value's fingerprint and equality, or is read
   through the tracked world by every call that uses it. A recorded read
   does not replace the first: it invalidates the call that built the
   value, not a call that is handed an equal-looking value later.

| state | rule |
| --- | --- |
| `raw_syntax_cache`, `raw_theme_cache`, `csl_style_cache`, `pdf_document_cache` (by bytes); `bibliography_cache` (by sources and bytes); `plugin_*_cache` (by the hash of plugin and arguments); `numbering_pattern_cache`; `glyph_frame_cache`, `overhang_tables`, `rusty_faces`, `shape_plans` (by font instance); `font_data_hashes` (by the identity of bytes); cells of constants | 1 holds |
| `route_*`, `traced_file_*`, `fingerprint_*`, `lazy_*`, `spare_shaping_buffer` | scratch of a call in progress |
| `raw_syntaxes_derived`, `raw_theme_derived` (`library/text_raw.mbt`) | **breaks 2.** The syntaxes and the theme of a raw element are filed by their source when the field is parsed and looked up by source when the element is highlighted. The element's fingerprint covers a path. A layout entry keyed by the element and its styles would be reused after the theme file changed. The element has the fields upstream uses (`raw_elem_syntaxes_derived`, `raw_elem_theme_derived`, unused): the loaded data goes there, as for images, and the tables go away |
| `works_cache` (`library/bibliography.mbt`) | **breaks 1.** `Works::generate` returns the last works for the same introspector object and equal elements; computing them reads the bibliography and the CSL style from the world (`BibliographyElem::database`, `CslSource::derived_style` load the sources again). A call that finds the works recorded no read of the `.bib` file. It becomes an entry of `memoize`, as upstream memoizes `generate_impl`: key the library and the bibliography and citation elements by their fingerprints (spans and locations included; today's `elems == bibs_and_groups` is Typst's loose equality), the route and the traced span; world reads, introspector reads and sink recorded; so that its reads become its callers' |
| bibliography and CSL sources in elements | 2 holds once `works_cache` is fixed: the elements hold paths, and `database` and `derived_style` read through the world |
| `image_elem_source_derived`, `image_elem_icc_derived` | 2 holds: the loaded data is in the element, and `ImageElem::decode` reads through the world where it is not |
| the images an SVG links (`library/image_svg.mbt`) | **breaks 2.** Decoding an SVG reads its linked images from the world; the equality and the fingerprint of an `SvgImage` cover its bytes and fonts, not those images (`library/visualize_hash.mbt`). The layout that decoded it has the read. A value that holds the decoded image does not show it: a tiling lays out its body when it is made and keeps the frame, and a closure call that is handed a tiling made after the linked PNG changed finds its entry for the old one. Upstream's `SvgImage` hashes the same two things. The image keeps the fingerprints of the files it loaded, and its fingerprint and equality include them |
| the file id interner (`syntax/path.mbt`), syntect's scopes, usvg's ids | not caches: identities that kept values hold. Never reset |

**As built** (step 2 of slice 1). The three rows that break a rule are
repaired; the first was before this step.

*Raw text.* Done by slice 0b: the tables are gone, the decoded syntaxes
and the theme are in the companion fields `syntaxes-derived` and
`theme-derived` with their sources (`raw_derived_pair`,
`library/text_raw.mbt`), and `typst/content_memo_wbtest.mbt` has the two
directories that name different themes by one relative path.

*The works of a bibliography.* Upstream
(`typst-library/src/model/bibliography.rs:711` to `:758`): `generate`
makes the introspection that lists the bibliographies and citation groups
and hands the list to `generate_impl`, which is memoized with the library
and that list hashed and the world, the introspector, the traced span, the
sink and the route tracked. The list's hash has the loaded data in it,
since an element's `sources` and `style` are `Derived` values whose two
parts are both hashed: a changed `.bib` file is another key. `Works::
generate` is now that, as an entry of `memoize` (`works_store`):

- The key is the fingerprints of the elements, with spans and locations,
  and the traced span (stricter than upstream, like every entry); the
  entry keeps the elements for the exact comparison; the library is
  compared by identity.
- The files are not in the key, because the port's elements hold the
  sources only. `generate_impl` loads them (`BibliographyElem::database`,
  `csl_style`, and `CslSource::derived_style` for the style of a
  citation), through the tracked world, and decoding is found by the
  bytes. So the `.bib` file, the CSL style and every other file that is
  named are world reads of the entry: it is only taken if they answer the
  same, and its reads become those of the call that finds it, as if it
  had loaded them. That is rule 2's second way, and it is how a change of
  the file invalidates the works: the read `File(refs.bib)` of the entry
  has another fingerprint, the entry is rejected, the works are generated
  from the new data, and every call around is recomputed for the same
  reason, since the read is in its entry too.
- The introspector reads (the query of a bibliography's `target`) and the
  sink are recorded and replayed as for every entry.
- The route is not in the key, unlike the design above said and unlike the
  layouts' and the counter sequence's. Upstream tracks it and the call
  asks it nothing (`show_math` evaluates with a route of its own), so
  upstream has one result per list of elements. With the whole route in
  the key the works were generated once per depth at which a citation or
  a bibliography is shown, in every iteration: 7 times instead of 3 for
  the ilm handbook, which the cell had at 3. `memoize` got what a closure
  call has, for the entries that ask for it (`tracks_route`): what the
  call asks of routes is noticed (depth checks, `Route::contains`, a
  routed entry found inside), a call that asked is not kept, and a hit
  does not bind the closure call around it to its depth. What is asked
  of routes is noted in state of the process, which cannot tell one
  route from another, and the math of an entry is evaluated from the
  root of a new route: its depth checks counted as questions to the
  tracked route, and a bibliography with a formula in a title was
  generated for every citation (the review of this step found it).
  `show_math` runs in `with_own_route`, which sets that state aside.
  The same holds for every `eval_string`, whose other callers are not
  treated so: a closure that calls `eval` gets its depth bounds from the
  checks on the route of the evaluated string too, which finds it at
  fewer depths than upstream would and is not wrong.
- Errors that the works keep (a key that no bibliography has, a style
  without a bibliography) are raised as copies, as upstream clones them
  (`:764`, `:780`): `trace` adds tracepoints to the errors it catches, and
  the same works now serve every call of an iteration and the iterations
  after it.

What it changes besides: the works were generated once per memoized call
that asked for them (every block or cell with a citation in it, in every
layout); they are generated once per list of elements now (the book of
`tests/recompile/docs`: 13 times, now 3; a table of twelve cells that
cite: 75, now 3; the handbook and `showcase.typ`: 3 and 3, whose citations
are all at the top of the flow, where the cell worked). With
memoization off they are generated for every call, where the cell used
to answer the top of the flow: no cache that the runner's comparison
cannot turn off is left.

*SVG images.* Upstream (`typst-library/src/visualize/image/svg.rs`):
`Hash for SvgImageInner` covers the data and a hash of the fonts that were
used (`:143`), not the linked images. `with_fonts_images` is memoized
(`:52`) with the data, the families and the file of the SVG hashed and the
world tracked; `ImageResolver::load_or_error` reads the linked file through
that world (`:481`), so the read is in the constraint of the call and of
every memoized call around it. That is what the port has had since step 1:
the read is the tracked world's (`SvgImageResolver::load_or_error`), and
the recording check sees it. What upstream does not have is an identity
that tells two decoded images apart, and it shows: `Image::new_impl` is
memoized on the hash of the kind (`image/mod.rs:447`), so of two SVG files
with the same bytes in two directories, each next to its own `photo.png`,
both show the first photo, on the page, in a tiling and in the PDF
(`e58a63af`; the port showed both, and does). And a watching upstream
keeps the first photo after the file changed. So the port does not mirror
the hash: an `SvgImage` keeps `data_hash` of every linked file it loaded,
in order (`SvgImage::links`), and its equality, its `Hash` and its
fingerprint include them (deviation 12). The fonts have the same gap, which
the review of this step found: upstream hashes a font when it is first
loaded, so `font_hash` says which fonts a tree uses and not what for. An
SVG with a text in each of two fonts and a third text that names none is
one image whichever of the two the third text got from the families of
the text around the image (in a function `shown(font) = text(font: font,
image("t.svg"))` the two images also have one span). The tree is a
function of the data and of what the two resolvers answered, so the
image also keeps the answers of the font resolver in order, as places in
its list of fonts (`SvgImage::selections`; `doc/svg_identity_test.mbt`
has the SVG, with the embedded fonts). What the links repair today, with
nothing kept across compilations: the hash of a page. `typst watch` with
one image per page exports a page again only if its hash changed
(`cli/compile.mbt`, `ExportCache`), and the page of an SVG whose linked
image changed hashed the same, so its PNG kept the old photo. What it
repairs for step 5 is the tiling of the table above.

*Everything else*, from the code (every top-level `let` of `library`,
`layout`, `eval`, `realize`, `html`, `pdf`, `svg`, `render`, `typst`,
`syntax` and `bundle` whose type is not a scalar or a `ReadOnlyArray`,
and the mutable fields of what outlives a call; the other packages have
constant tables, the counters of wasmi and usvg, the out-parameter cells
of `shape` (`unsafe_cell`, `match_end_cell`, `component_count_cell`:
written by a call and read before the next call, see `out_cell`), and
what `doc` and the CLI keep for themselves):

| state | what it is | verdict |
| --- | --- | --- |
| `layout_store`, `counter_sequence_store` (`MemoStore`), `closure_store`, `works_store`; `eval_memo` (`eval/import.mbt`) | the stores of memoized calls: found by key, taken by their arguments, library, context, route, introspector reads and world reads | stores; they end with their compilation (modules: with their scope) until step 5 |
| `capture_sites` (`eval/captures.mbt`) | the capture analysis of a closure or context expression, by span and node object, for one compilation | rule 1: a function of the node, which never changes since the persistent edits |
| `raw_syntax_cache`, `raw_theme_cache`, `csl_style_cache` (by bytes), `bibliography_cache` (by sources and bytes), `pdf_document_cache` (by bytes), `plugin_call_cache`, `plugin_transition_cache` (by the hash of plugin, function and arguments), `plugin_module_cache` (by hash and bytes) | the decode caches that `evict` drops as a whole | rule 1. For step 4: the plugin caches raise the errors they keep as the kept objects, and a plugin's module is one object only until its cache is dropped |
| `raster_image_cache`, `raw_highlight_cache`, `pdf`'s `raster_cache` (`ContentCache`) | slice 0: by upstream's hash, with ages | rule 1 |
| `numbering_pattern_cache` | parsed patterns by their string | rule 1 |
| `glyph_frame_cache`, `overhang_tables`, `rusty_faces`, `shape_plans`; `svg`'s `glyph_paths`, `glyph_bboxes`; `render`'s `pixglyphs` | by font instance (data, index, variations) and glyph, the plans also by direction, script, language and features, the paths also by scale | rule 1: functions of the font's data. Never dropped (6.3) |
| `font_data_hashes`, `data_hashes` | hashes by the identity of `Bytes` | rule 1; an entry keeps its object, so an identity is not reused |
| in objects: `FontBook.selected` and `covering`; `OtfFontFace.instances`; `StyleChain.memo_hash`; the `LazyFingerprint` of closures, tilings, modules and capture sites; `RasterImage.hash`; the memo of a `Source`; `ElementIntrospector.queries`; the scopes and parameters of native functions, types and elements | what an object computes once of itself | rule 1 with the object as the key: a book's caches are cleared by `push`, with which its edition changes; an introspector's query cache is by the selector's hash, as upstream's, and hands out its arrays (step 4) |
| `CachedCell` (`layout/flow_collect.mbt`) | the last layout of a child of a flow, by region, in the child that one flow layout collected (upstream's `CachedCell`) | scratch of that layout: every use is inside the call that made it. It keeps errors and raises them as kept (step 4) |
| `accent_funcs_cell`, `lr_funcs_cell`, `codex_sym_cell`, `codex_emoji_cell`, `color_map_cell`, `sequence_elem_cell`, `styled_elem_cell`, `space_shared_cell`, `space_newline_cell`, `html_typed_funcs_cell`, `lorem_chain_cell`, `cmyk_grid_cell`, `raw_theme_cell`, the 443 cells of generated elements and functions and the 39 type descriptors, `scopes_registered`, the hooks of an element descriptor (`<elem>_init`); hayagriva's styles, locales and collation table, hypher's tries, the normalization indices | constants that are built on first use | written once |
| `exception_map`, `shorthand_systems`, `rd_pow10_table`, `fallback_families`, `empty_style_head`, `empty_lifecycle`, `text_base_local_styles`, the `*_default_value`s, `no_route_queries`, `no_world_reads`, `volatile_world_reads`, the grouping rules of `realize`, `routines`, the syntax sets | constants in containers | nothing writes to them (looked at every use) |
| `route_shift_lo`, `route_shift_hi`, `route_shift_scopes`, `route_query_log`, `route_query_scopes`, `traced_file_log`, `traced_file_scopes`, `fingerprint_flags`, `fingerprint_hosts`, `fingerprint_output_hosts`, `lazy_depth`, `lazy_cut`, `spare_shaping_buffer`, `spare_hasher`, `recording_worlds`, `open_world_scopes`, `compilation_depth`, `memo_generation`, the recording check's own | scratch of calls in progress | put back when the call ends |
| `memo_enabled`, `memo_counter`, `evictions`, `evictors`, `closure_memo_counts`, `works_generations` | switches, counts and the list of evictors | no result depends on them |
| `font_serials`, `font_book_editions`, `source_serials`, `world_scope_tokens`, the file id interner, syntect's scope repository and pattern counter, usvg's ids | identities | never reset |

Nothing else breaks a rule. Three things on the list are step 4's (the
rule for mutable results of 5.4): errors that the plugin caches and a
`CachedCell` keep and raise, the arrays that a `Works`, a
`RenderedBibliography` and an introspector's query hand out, and the
module of a plugin after its cache was dropped.

*Review.* One round by Codex on the diff of the step, asked for state
that a memoized call reads and that is neither in its key nor in its
recorded reads; the verdict was "request changes" with three findings.
Two are repaired and said above where they belong: the fonts of an SVG
image (which font for which text), and the math of a bibliography entry
(a route of its own). The third is about the harness and is the
paragraph that follows.

One thing outside the engine is of the same kind and is left as it is,
because it is upstream's CLI: the export cache of `typst watch` holds the
hash of a page and not the options the page is exported with, and those
can come from the document (`#set format.png(ppi: 72)`). After an edit of
that number alone the port and upstream both keep the PNG of the old
resolution (checked with both binaries). The `recompile` stage renders at
a fixed resolution and does not see it.

*Cost.* Against the base of the step (`main` at `95acf25`), the least of
twelve runs each in turns, both binaries in one directory (the path of
the executable alone moves the count of `tiny.typ` by 0.4 %):

| workload | instructions before | after | change |
| --- | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.7 M | 64.7 M | +0.01 % |
| `query long.typ heading` | 2962.2 M | 2963.5 M | +0.04 % |
| `long.typ` to PDF | 3525.3 M | 3526.2 M | +0.03 % |
| `showcase.typ` to PDF, embedded fonts | 3806.7 M | 3807.0 M | +0.01 % |
| `showcase.typ` to PDF, system fonts | 4374.3 M | 4379.7 M | +0.12 % |
| touying `theme-metropolis.typ` to PDF | 2664.8 M | 2663.9 M | -0.03 % |
| ilm `bakers-handbook.typ` to PDF | 2344.5 M | 2344.0 M | -0.02 % |
| the book of `tests/recompile/docs` to PDF | 1735.6 M | 1403.0 M | -19.2 % |
| `linked` of `tests/recompile/docs` to PDF | 78.7 M | 78.8 M | +0.14 % |

Nothing moves but the book, whose citations are inside blocks: the works
of a document whose citations are at the top of the flow were generated
three times before and are generated three times now. In a watch session
(five sessions of five edits at the end, the durations of the status
lines) the book's first compilation goes from 127.5 ms to 103.5 ms and
its recompilation from 75.1 ms to 56.6 ms; `long.typ`, `showcase.typ` and
the handbook are where they were, inside a spread of a few per cent, and
so are the workloads of `bench/run.sh`. The `recompile` stage takes 40 s
where it took 35 s: one document more, and the images of every page of
every reference.

## 6. Lifetime and memory

### 6.1 Ages

comemo's rule. Every entry of every store has an age. `@library.evict
(max_age)` adds one to each and drops those above `max_age`; a hit sets the
age to zero. A compilation no longer clears the stores (what ends with a
compilation or a scope by 5.2 and 5.4 is never stored or is dropped then:
entries keyed by a host's values, readers of volatile files); a process
that never calls `evict` keeps the rest, as a process using comemo does, and
`evict(0)` drops everything. `typst watch` calls `evict(10)` after each
recompilation, where it calls it today: `max_age` is upstream's 10
(decided, section 11). What that holds, for `longer.typ`: 116 MB with
nothing changed and 358 MB after ten edits that each changed every
heading, both measured (6.2); eleven times the stores of one compilation,
about 1.1 GB, if ten edits in a row each changed every paragraph, which is
not measured. Slice 1 measures the peak in the harness's soak run before
it is merged (section 8). Four entries per key stay the
limit (`memo_max_entries`, first in, first out): comemo's tree has no such
limit, and none of the measured documents reaches it.

The stores register themselves with `evict` (comemo's `register_evictor`):
modules, closure calls, layouts, counter sequences, works, the new ones of
section 8, and the decode caches that are dropped as a whole today, which
get ages like the rest (a syntax or bibliography that is still in use is
then not decoded again every tenth compilation). The fingerprints of
sources by revision and of bytes by file id are tables that hold what they
describe; their entries age like the rest.

*As built* (step 5 of slice 1; section 8, "Step 5 as built", has the
whole of it). As above, with these differences. The fingerprint of a
source is kept in the source (5.2) and that of bytes in `data_hashes`,
which is swept as before, so there is no table of them to age. Module
evaluations have a limit of twelve per source, not four, which `evict(10)`
never reaches: there the ages decide, as comemo's (both limits count
what is young only: deviation 4). Entries that end with
their compilation (a host closure in the key) are dropped when the
outermost compilation ends. `evict` may be called during a compilation
and then spares the module evaluations of open scopes. With memoization
off a compilation neither takes nor leaves anything. The measured peaks
are in "Step 5 as built", "Memory".

### 6.2 What a store costs

Live bytes of the allocator (mimalloc's `mi_heap_visit_blocks`, after
`mi_collect`), measured after one compilation and after dropping the
stores one by one:

| document | live | memo stores | module memo, capture table | everything else |
| --- | ---: | ---: | ---: | ---: |
| `long.typ` | 34.9 MB | 20.3 | 0.0 | 14.5 |
| `longer.typ` | 116.2 | 101.4 | 0.0 | 14.8 |
| `showcase.typ` | 101.8 | 78.9 | 0.0 | 22.9 |
| deck | 460.6 | 434.4 | 0.7 | 25.5 |
| touying | 51.3 | 10.5 | 1.6 | 39.2 |
| handbook | 29.8 | 5.9 | 0.0 | 23.9 |

"Memo stores" is what `layout_store`, the closure store and the counter
store hold that nothing else does. That is today's state: the stores are
most of the heap of a waiting `typst watch`. The deck's 434 MB and the 79
MB of `showcase.typ` are decoded images, one copy per layout that decoded
one, each kept by the frames of a layout entry; with slice 0a the deck's
whole heap is 101 MB and that of `showcase.typ` 64 MB.

Kept without eviction (with slice 0's caches), the heap grows per
recompilation by:

| document | edit at the end | an edit that reaches everything |
| --- | ---: | ---: |
| `long.typ` | 1.1 MB | 4.9 MB (every heading) |
| `longer.typ` | 5.4 | 24.2 (every heading) |
| `showcase.typ` | 1.8 | 1.7 |
| deck | 0.2 | 5.1 (theme value) |
| touying | 0.2 | 7.8 (package file) |
| handbook | 1.1 | 6.3 (package file) |

An edit at the end of a one-file document costs a new module, which is
the content of the whole file (`longer.typ`: 5 MB), and little else.

What an entry holds besides its result, and what the design changes:

- its arguments, for the exact comparison (content, style chains, closure
  arguments). Measured by finding layout entries by their key alone: the
  stores of `long.typ` shrink from 20.3 to 19.4 MB, of `longer.typ` from
  101.4 to 96.6 MB. Five per cent: the exact comparison stays.
- the introspector of its compilation and iteration (`MemoEntry.backend`,
  `ClosureEntry.backend`), which holds every located element and position
  of a document. Kept across compilations that is up to `max_age` times
  the iterations. The entry keeps a serial number of the introspector
  instead; the shortcut compares numbers.
- its introspector reads with their replay closures, its world reads, its
  sink: small.

The bound is not a number of bytes but comemo's: what the last `max_age`
compilations used. With `max_age` 10 that is between one and eleven times
the stores of one compilation: for `longer.typ` 116 MB if nothing changes,
170 MB after ten edits at the end, 358 MB after ten edits of every heading
(all measured), and about 1.1 GB if ten edits in a row each changed every
paragraph (eleven times 101 MB; not measured). Upstream's bound has the
same shape.

### 6.3 Caches that are not memoized calls

| cache | today | design |
| --- | --- | --- |
| capture table (`eval/captures.mbt`) | per compilation | per compilation (5.4). As built: confirmed in step 5, with its cost (section 8, "Step 5 as built") |
| world answers, log (new) | | per scope |
| shape plans, rustybuzz faces, overhang tables, `font_data_hashes`, glyph outlines, bitmaps, colour glyph frames, and the instances a font keeps of itself (`OtfFontFace.instances`, `library/font.mbt`) | process or font object, by font, glyph, variation coordinates, shaping features; nothing ever drops them, `evict` included | registered with `evict`: dropped by `evict(0)`, otherwise kept. They grow with the fonts, glyphs, variation coordinates and feature sets a session has used, not with its edits; a document that animates a variation axis, or a host that replaces font data, frees them with `evict(0)`. Not built in step 5: they are as they were, never dropped, also not by `evict(0)` (they are functions of a font's data, so a reference of the harness that shares them shares no result that could be stale; what is open is the memory of a host that replaces fonts) |
| numbering patterns | process, by pattern string | aged. As built (step 5): a `ContentCache` by the hash of the string |
| raw syntaxes and themes, bibliographies, CSL styles, PDF documents, plugins and their calls | dropped as a whole every `max_age`-th `evict` | aged per entry. As built (step 5): each a `ContentCache` |
| decoded raster and SVG images, highlighted raw text (section 8, slice 0) | not kept | aged per entry |
| CLI `ExportCache` | per watch session | unchanged |

Their sizes were not measured. The smallest experiment: print the number
of entries of each after `longer.typ` and after the `packages` stage.

## 7. The process boundary

- **`typst watch`** (`cli/watch.mbt`): one process, one `SystemWorld`, one
  `Library`. Everything above applies; the loop already calls
  `world.reset()` before and `@library.evict(10)` after a recompilation.
  (As built in step 5 of slice 1: nothing in `cli/` changed. The loop was
  upstream's already; what changed is that the stores no longer empty
  themselves.)
- **A host that keeps a world** (`@typst.compile`): the contract is
  comemo's. The world may change between compilations and not during one;
  the host calls `@library.evict(n)` between compilations or memory grows
  with every distinct compilation; it keeps its `Library` and, for a file
  that changed, returns the source that `Source::replace` or `Source::edit`
  of the file's last source returned (as built, 5.4: an edit returns a new
  source that shares the nodes it did not touch; for an unchanged file,
  `replace` returns the same object). A host that makes a new `Source` for
  a changed file gets
  the numbering of a fresh parse, which differs from the old one in most of
  the file: little that came from that file is found again. A world that
  returns the same `Bytes` object for an unchanged file saves its hashing.
  Stores are process-wide, so two worlds in one process share results where
  they give the same answers, as with comemo. (As built: the doc comment
  of `@typst.compile_with` is this contract.)
- **`typst compile`, `query`, `eval`**: one compilation, nothing to reuse;
  slice 0 and the block level are what they get. The evaluation of
  `eval`'s and `query`'s strings is a scope of its own (5.2).
- **The EDSL** (`doc`): a script is a process per run, and nothing here
  crosses a process. Within a process, a second compilation of `doc` runs
  in a new `SessionWorld` with new host functions for its callbacks
  (`doc/session.mbt`): results that involve a callback end with their
  compilation (5.4), results that read the session's virtual files end
  with their scope (5.2), the rest is reusable where the lowered content
  is equal, which includes its spans (the origin numbering of
  `doc/lower.mbt`). The design does nothing for `doc` beyond not breaking
  it: no persistent cache, no stable identities for callbacks. If a
  long-lived `doc` host appears (a preview server), that is a design of its
  own. (As built in step 5: one thing more. A compilation or lowering of
  `doc` ends with `@library.evict(10)`, as a recompilation of `typst
  watch` does. Without it a process that compiles many documents would
  hold all of them where it held one before the stores were kept, and a
  `doc` user has no reason to know that `evict` exists.)

## 8. Slices

The order follows section 3: first what is worth most and needs nothing
new, then the machinery with the stores that exist, then the missing
functions by their measured gain. Slices 1 to 3 each end with the harness
of section 9 green; every slice ends with its rows of section 3.3 measured
again. The
expected numbers are the probe's and are optimistic: the probe validated
no world reads for closure calls and layouts, compared no arguments where
it found entries by key, copied no diagnostics and no documents, and
edited trees in place. Slice 1's first step measures what recording and
validation cost; the expectations of the later slices are restated then.

### Slice 0: three functions upstream memoizes, by content

No new machinery: each is a pure function of what is in its key, so it can
be kept for a compilation, an export or the process without validation.
Each helps a single compilation. It needs nothing of the harness and is
being built first (decided, section 11).

| step | key | files | expected |
| --- | --- | --- | --- |
| 0a `RasterImage::new` (upstream `RasterImage::new_impl`) | the data's hash, kept by the identity of the `Bytes` as `font_data_hash` keeps a font's; format; ICC profile | `library/image_raster.mbt`, `library/memo.mbt` (dropped by `evict` like the decode caches of today until slice 1 gives it ages) | the deck: first compilation 1710 ms to 651 ms, recompilation 1690 ms to 501 ms, heap 461 MB to 101 MB; `showcase.typ`: 345 ms to 245 ms, 268 ms to 71 ms |
| 0b `RawElem::highlight` | the element, the style chain, and the library object (the function calls `routines.html_span_filled`; upstream hashes the routines) | `library/text_raw.mbt`; first the raw element's derived data (5.5) | `showcase.typ`: recompilation 71 ms to 50 ms; the handbook: 92 ms to 74 ms |
| 0c `convert_raster` (typst-pdf): one conversion per image and export, then kept between exports; tagging, locations and error spans stay per occurrence in `handle_image` | the raster image, `interpolate` | `pdf/image.mbt`, `pdf/convert.mbt` | not established: an export of the deck converts 72 times for 28 images (137 to 143 ms of 290 to 305 ms). The conversion cache is built first and its gain measured. What the rest of `handle_image` costs, the compression, per image and per occurrence, is measured with it; the change in `moonbitlang/pdflite` (an image keeps its encoded stream) follows only if that number is worth it (decided, section 11) |

Risk: memory (decoded pixels of every image of the last `max_age`
compilations: 6.2). Left out: SVG images (`SvgImage::with_fonts_images`
reads fonts and linked files from the world: slice 1), the PDF writer's
own speed.

*As built* (0c, and the change in pdflite that was to follow it only if
the number was worth it). The conversion cache came first
(`convert_raster` in `pdf/image.mbt`: `raster_cache`, a `ContentCache`
keyed by `RasterImage::hash128()` and `interpolate`). With it, what was
left of an export of an image deck was compression in pdflite, repeated in
every export: 365 of the 371 ms of a second export of the deck below. So
the second half was built.

What krilla does. An image is `Arc<ImageRepr>`, and its samples exist in
it only compressed: `Image::from_custom` calls `deflate_encode` (zlib,
level 6, no predictor) on the colour channel and on the alpha channel when
the image is made (`SampledRepr`; on another thread with `rayon`), and
`Image::serialize` writes those bytes with `FilterStreamBuilder::
new_from_deflated` into whatever document is given the image. The
dictionary is made per document: the colour space (device or ICC-based by
`no_device_cs`), the profile (dropped if the version does not support
it), `/Interpolate`, the reference of the mask, the validation errors,
the check of 16-bit samples against the version. Between documents
nothing is shared but the image itself, and typst-pdf hands the same image
to a later export because `convert_raster` is memoized.

What pdflite 0.3.9 has (`export/image.mbt`). `ImageData::Deflated(Bytes,
Bytes?)`, the zlib streams of the colour samples and of the alpha channel,
and `Image::deflated()`, which makes it from `Samples` with the function
that `Document::finish` compresses samples with. The questions, as they
were decided:

- Where the cache lives: in the image value, as in krilla. pdflite has no
  table of images, takes no cache object and needs no evictor. An
  `@export.Image` is a struct that callers build as a literal, so a field
  was not an option; a case of `ImageData` breaks only code that matches
  on all its cases, of which there is none outside pdflite.
- The key: there is none across documents. A table by `image.key` would
  have made the caller's key, which today means "the same image in this
  document", mean "the same samples in every document of the process";
  as built, two images with equal fields and other samples cannot meet,
  because nothing is looked up. Inside a document an image is embedded
  once per `key` and `interpolate`, as before. What the kept bytes depend
  on is the samples and nothing else: not the version, the standard, the
  colour space, the profile or `interpolate` (two entries of
  `raster_cache` that differ in `interpolate` hold the same streams
  twice, as upstream's two images do).
- Lifetime: the entry of `raster_cache`, which has comemo's ages and is
  dropped by `@library.evict` through `register_evictor`, as before.
- Determinism: a PDF is byte for byte what it was, from kept images or
  not. `Samples` and `Deflated` are written by one function in pdflite,
  and here the exporter is still given `Samples` when memoization is off,
  so a comparison of PDFs with memoization on and off compares the two
  forms: the `recompile` stage, `pdf/image_wbtest.mbt` and
  `doc/pdf_images_test.mbt` (the `edsl` stage exports with memoization on
  only).
- Memory: what is kept is the compressed streams (about the size of the
  images in the file) and no longer the converted samples; nothing else
  read them. An image is compressed right after it is converted, so the
  samples of one image are alive at a time in a first export, not those
  of all.

Measured (aarch64 macOS, native release, medians of five; the deck is
`bench/mkdeck.py`'s: 43 pages, 28 PNGs of 1440 x 900, half with an alpha
channel, drawn 72 times, 127 MB of samples in 42 streams, an 11 MB file;
upstream is 0.15.1 with its threads). `tests/pdf_bench`, the export
alone, in one process:

| document | | export 1 | export 2 | peak footprint, one export | three |
| --- | --- | ---: | ---: | ---: | ---: |
| deck | before | 397 ms | 371 ms | 301 MB | 359 MB |
| | after | 397 | 6.0 | 229 | 294 |
| `showcase.typ` | before | 16.5 | 14.1 | 141 | 143 |
| | after | 16.4 | 13.7 | 141 | 143 |
| `longer.typ` | before | 184 | 188 | 161 | 167 |
| | after | 183 | 189 | 161 | 167 |

`typst watch` to a PDF (the durations of the status lines: a compilation
and its export), a first compilation and five edits at the end of the main
file:

| document | | first | after an edit | RSS after the first | after the last | peak |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| deck | before | 579 ms | 420 ms | 298 MB | 335 MB | 351 MB |
| | after | 588 | 53 | 236 | 255 | 267 |
| | upstream | 80 | 15 | 293 | 320 | 336 |
| | upstream, `--jobs 1` | 485 | 14 | 208 | 244 | 255 |
| `showcase.typ` | before | 242 | 56 | 169 | 171 | 179 |
| | after | 248 | 57 | 169 | 172 | 180 |
| | upstream | 169 | 8 | 141 | 156 | 164 |
| `longer.typ` | before | 1300 | 1350 | 183 | 186 | 195 |
| | after | 1290 | 1330 | 183 | 186 | 195 |
| | upstream | 514 | 123 | 313 | 1144 | 1200 |

The 53 ms of the deck after an edit are its compilation (47 ms) and the
6 ms of the export. `showcase.typ` (a JPEG, which is embedded as it is)
and `longer.typ` (no image) do not change. The files are the same bytes
before and after, in every session and round.

Not kept, and so compressed in every export: images inside SVGs and
bitmap glyphs (their images are made per export: `pdf/svg_image.mbt`,
`pdf/color_glyph.mbt`), ICC profiles (krilla deflates a profile when it
is made), content streams (krilla memoizes their deflation) and fonts.

### Slice 1: the tracked world, and the existing stores kept

One slice because nothing may be kept before all of it is there. Five
steps, each merged on its own; results cannot become stale before step 5.
All five are built.

1. **Scopes and recording.** Built (`library/tracked_world.mbt`,
   `library/memo_check.mbt`). Scopes (5.2) at every entry point, replacing
   `compilation_epoch` and `note_evaluation`; `TrackedWorld` in the engine
   and in what carries a world (5.2), with `scripts/tracked_world_check.py`
   for what the types do not hold; the fingerprints of answers (a source
   by its text or by its number, a book and a font by the object); the log, the answers of a scope, the reads in
   every entry of `memoize`, `memoized_closure` and
   `eval_source_memoized`, validated on a hit; the library compared by
   identity in every entry; volatile files, declared by `doc`, whose
   readers are not stored, and reads through another tracked world,
   likewise. Validation is true on a hit while stores die with their
   compilation, with one exception: an engine with another world or
   library that is used inside a compilation shares the closure and layout
   stores, where the world was assumed fixed before and is validated now.
   What changes behaviour at once: a `doc` document that reads its own
   virtual files gets what they hold at that moment; an evaluation outside
   of a compilation is a scope of its own, so its modules are not those of
   the evaluation before; nothing is memoized for an engine whose world is
   in no scope; a call that reads through a second tracked world is not
   kept. Since validation cannot fail yet, what proves the recording is
   the recording check of 9.1, the unit tests of the stores
   (`library/tracked_world_wbtest.mbt`, `typst/tracked_world_wbtest.mbt`,
   `doc/volatile_test.mbt`) and the mutation checks that belong to this
   step (9.1). Files: `syntax/source.mbt`, `library/engine.mbt`,
   `library/memo.mbt`, `library/convergence.mbt`, `library/font.mbt`,
   `library/font_book.mbt`, the call sites and carriers of 5.2,
   `eval/import.mbt`, `eval/lib.mbt`, `typst/lib.mbt`, `doc/compile.mbt`,
   `doc/origin.mbt`, `doc/session.mbt`, the hosts that build engines
   (`cli/eval.mbt`, `cli/query.mbt`, `tests/runner`). Measured: the
   overhead against the budget of 5.2 ("Costs").
2. **State outside the arguments** (5.5): the raw element's derived data,
   if slice 0b has not done it; `Works::generate` as an entry of `memoize`;
   the linked images in an SVG image's fingerprint and equality. Built
   (5.5, "As built"; the raw element's part was slice 0b's):
   `library/bibliography.mbt` (`works_store`), `library/memo.mbt`
   (`tracks_route`), `library/image_svg.mbt` and
   `library/visualize_hash.mbt` (`SvgImage::links`). What proves it:
   `typst/state_outside_wbtest.mbt`, `library/works_wbtest.mbt`, the
   recording check, the page images of the `recompile` stage with the
   project `linked`, the scenario `linked` of `scripts/watch_check.py`,
   and the mutation checks of 9.1 that belong to this step. It changes one
   output: the pages that `typst watch` writes as images after an image
   that an SVG links has changed. It costs nothing that can be measured,
   and a document with citations inside blocks compiles faster (5.5,
   "Cost").
3. **Sources.** Built, the library last ("Step 3 as built" below).
   Persistent edits in `syntax/reparser.mbt`,
   `syntax/node.mbt` and `syntax/source.mbt` (built: "As built" in 5.4;
   the fingerprint of a source is step 1's, and with sources that never
   change it needs no revision). Module evaluations keyed by the source's
   fingerprint and valid by their world reads instead of by their scope
   and text; the main file through the same store (`typst/lib.mbt`), whose
   source is then read through the tracked world; the library made only
   by its builder, immutable, with its serial number in every key in place
   of the comparison by identity (5.3).
4. **Identity and ownership.** Built ("Step 4 as built" below), with
   module equality as the owner decided it and not as this line had it:
   descriptors fingerprinted by their number; modules exactly as
   upstream's (`==` by identity, memoized calls by hash; plugins
   unchanged); entries whose key carries `fingerprint_identity`, which is
   host functions alone now, end with their compilation; the
   introspector's `query` returns a view, and its number replaces the
   object in entries; the copies and views of 5.4's rule for mutable
   results; and the harness accepts upstream's own difference between a
   recompilation and a fresh compilation where it is pinned (9.1).
5. **Ages.** Built ("Step 5 as built" below). `evict` as in 6.1; the
   stores stop clearing themselves, one
   store per commit in the order modules, closure calls, layouts, counter
   sequences and works, each with the harness and its numbers. Before the
   last of them is merged: the peak of the live heap over the harness's
   soak run (more edits than `max_age`, among them edits that reach every
   paragraph), for `longer.typ` and a package document, in place of the
   bound of 6.1 that is not measured.

Expected (the "kept" and "+ slice 0" columns of 3.3, optimistic as said):
`long.typ` 234 ms to 92 ms after an edit at the end, `longer.typ` 1247 ms
to 507 ms, `showcase.typ` 71 ms (after slice 0a) to 24 ms, the touying
document 155 ms to 22 ms, the handbook 93 ms to 30 ms, the deck 501 ms
(after slice 0a) to 332 ms.

Risk: this is the slice from which a stale result can come. What guards it
is section 9, in particular the checks that break one validation at a time.
Left out: every function that is not memoized today.

#### Step 3 as built (the engine half)

The syntax half (persistent edits) is in 5.4. This is the rest of the
step: `eval/import.mbt`, `eval/lib.mbt`, `typst/lib.mbt`, with what they
needed in `library` (`source_fingerprint`, `RouteShifts`,
`SourceDiagnostic::clone`). Nothing is kept from one compilation to the
next yet: a module entry still ends with the scope that stored it, and
only step 5 changes that. What changed is what an entry is found by and
what makes it valid, so that step 5 can keep it.

**Upstream's key, and the port's.** Upstream:

    #[comemo::memoize]
    pub fn eval(
        world: Tracked<dyn World + '_>,
        library: &LazyHash<Library>,
        traced: Tracked<Traced>,
        sink: TrackedMut<Sink>,
        route: Tracked<Route>,
        source: &Source,
    ) -> SourceResult<Module>

The key is the hash of `library` and of `source`; `Hash for Source` is
that of `SourceInner` behind a `LazyHash` (`typst-syntax/src/source.rs`):
the id, the text with its line index, and the root, a numbered tree. The
world, the traced span and the route are tracked: a result is taken if
they give the answers that the evaluation got. The sink's mutations are
replayed. The function is one for the main file (`compile_impl`) and for
imports (`import_file`).

The port, `eval_source` (public, memoized) around `eval_source_impl`:

| | upstream | port |
| --- | --- | --- |
| the source | its hash: id, text, numbered tree | found by `@library.source_fingerprint`: the id and the text of a source that `Source::new` parsed, the id and the number of the object for the result of an edit (step 1's fingerprint of the world's answer, 5.2); and the entry keeps the source and is only taken for the same one (`same_source`: one object, or two parses of one text of one file) |
| the library | its hash | compared by identity, as in step 1 (5.3 has what replaces it) |
| the world | tracked | the recorded reads, validated last (`TrackedWorld::validate`, step 1) |
| the route | tracked: `contains`, `within` | the answers of `contains` for the ids that were asked (as before), and the depth: by how much the route may be deeper or shallower without changing the answer of a depth check of the evaluation (`RouteShifts`, as closure calls have it; new) |
| the traced span | tracked: `get` | the answers for the files whose code ran (as before) |
| the sink | replayed | replayed |
| the result | a clone of the stored `SourceResult` | the module; an error as a copy of the stored one (below) |

Where the port's key differs: two sources that were edited into the same
tree are two keys (upstream: one hash); the source is also compared, not
only hashed (deviation 3 of section 10, for this store too: the
fingerprint of a parsed text is kept in the source by a public setter,
and before this step the comparison of the texts stood behind it); two
libraries with equal contents are two (deviation 7); and nothing is kept
for a file that changes during its scope (5.2).

The depth is not a deviation but one that is gone. A module entry did not
have it, so a file that was imported near the top and then from inside a
deep recursion was found there although its own calls no longer fit the
maximum call depth: the port compiled a document for which upstream
reports "maximum function call depth exceeded" (it evaluates the file
again, since `Route::within` gave another answer). In one compilation,
before anything is kept; with a kept store the same entry would also be
taken where a compilation from scratch fails. (`typst/oracle_wbtest.mbt`,
"memo: a file is evaluated again where the route is too deep for its
calls".)

**A file that is edited and edited back.** With `Source::replace`, as the
CLI's file store does it, the source after the second edit has the first
text and other span numbers where it was reparsed. It is another source:
its fingerprint is the number of a new object, its module is evaluated
again, and so is every module that read it. That is a miss where the
text is what it was, and it is upstream's miss (the hash of the reparsed
tree is another). It costs what any edit of that file costs, since an
edit evaluates the file again anyway; what an undo could save is the
evaluation, not the layout, which is found by content and spans, of
which the reparse changed few. A world that parses the text anew
(`Source::new`: the runner's worlds, a host that reads its files into
new sources) hands out the first tree again, number for number, and
finds the entries of the first compilation: that is sound, the tree is a
function of id and text. No attempt is made to recognize the old text in
an edited source (it would need the tree of the first parse to compare
the numbers with).

**The experiment with a kept store** (as in step 1; a local change that
is not in the tree: the module entries outlive their scope, validation
on). The failing sequences of the `recompile` stage, of 235, in two
variants: as step 1 ran it, where a reference is a fresh world that is
answered from the same store; and with the store dropped by `evict(1)`,
which the stage calls before every reference, so that references are
computed from scratch.

| the module store kept | references from the same store | references from scratch |
| --- | ---: | ---: |
| before this step | 4 | 4 |
| found by the fingerprint, valid by reads and depth (the first commit) | 1 | |
| and the kept errors copied | 0 | |
| the step as committed (with the review's fixes) | 0 | 0 |

The four: `project/book`, `project/notes` and
`suite/visualize/rect.typ` at "everything back" (frames: the old text
with other span numbers), and `import-cyclic-in-other-file` (a
tracepoint too many), which is the one that the first commit leaves. As
committed the main file is an entry too, so every compilation of the
watch loops asks the store: of 2121 evaluations of files in them
709 were found and 1412 computed. The second variant is the
one to trust: a reference that is answered from the same store can be
wrong together with the watch loop, which is how a mutation that leaves
the library out passed at first.

**Kept errors.** A module entry that failed kept the array of
diagnostics that it raised, and `@library.trace` appends its tracepoint
to the diagnostics that pass through an import: every import that found
the entry added one to the kept error. Not only across compilations: a
file that fails and is imported from two `context` blocks (the errors are
delayed, so both imports run) was reported with two tracepoints where
upstream reports one. Upstream never writes to what its cache holds:
comemo inserts `output.clone()` and returns `entry.output.clone()`
(`memoize.rs`), and `Trace for SourceResult` adds the tracepoint through
`errors.make_mut()` (`typst-library/src/diag.rs`), which copies a vector
that is shared, as the trace of a diagnostic is copied when it is pushed
to. The entry keeps a copy of the errors and hands out a copy on every
hit (`own_result`); what a caller does to the errors it got does not
reach the entry. The modules, arrays of file ids and read lists of an
entry are not written by anyone. Its sink still shares its diagnostics
and traced values with the sinks it is replayed into: step 4.

**The main file.** `compile_impl` calls `eval_source`, which is the
memoized function now, so the main file's evaluation is an entry like
any other: found again in the same compilation where something imports
the main file (a `context` block can: its route is the layout's), and
later, when entries are kept, by a compilation whose main file is the
source it was. Its source is read through the tracked world, like that
of its `.typ` sibling in `hint_invalid_main_file`; both are outside of
every memoized call, as upstream's are, so nothing records them. What is
left of the raw world where a compilation is entered is `main()` and
`library()`, and `scripts/tracked_world_check.py` reports every other
use of it there.

**The mutation checks of step 3.** Each put in by hand, one at a time,
never committed; what must fail is a unit test, the script, or the
`recompile` stage with the module store kept (the experiment above, with
references from scratch; as committed the stage cannot see any of them,
its stores end with their compilation).

| what was broken | what exposed it |
| --- | --- |
| a source is its id and text to the module store (key and comparison), not its span numbers (number 8 of the table in 9.1) | `eval/import_wbtest.mbt`, "the same text with other span numbers is another source (A, B, A)": the kept error of the first parse is reported, with a span that is not in the tree. Kept store: 55 sequences, wherever a file has an earlier text again (the main file is an entry) |
| every source is fingerprinted by its text, also the result of an edit (the answer of the world's `source`; the module store still compares the source) | that test, and `library/tracked_world_wbtest.mbt`, "an entry is rejected if one answer differs". Kept store: 2 sequences (`project/chain`, `import-cyclic-in-other-file`: a module that is taken although a file it imported has other span numbers) |
| the main file's source is read of the raw world | `scripts/tracked_world_check.py` and nothing else, by construction: the read is outside of every memoized call, as upstream's is, the entry of the main file is found by the source it is handed, and what imports the main file reads it through the tracked world itself. Kept store: 0 |
| a kept error is handed out as the object it is (number 18 there) | `eval/import_wbtest.mbt`, two tests; `typst/oracle_wbtest.mbt`, the two "a file that fails, imported .." cases, in one compilation. Kept store: 1 sequence (`import-cyclic-in-other-file`) |
| the library is not compared (number 12 there) | `library/tracked_world_wbtest.mbt`, "the library is compared (`sys.inputs`)" (step 1's); `eval/import_wbtest.mbt`, "the library is part of what an entry is for" |
| an entry is taken for any source with its fingerprint (review) | `eval/import_wbtest.mbt`, "an entry is only taken for the source it was computed for" |
| the recording check substitutes any entry's module (review) | `eval/import_wbtest.mbt`, "the recording check repeats an import with the module of the world at hand" |

The recording check (`--check-reads`) on the step as committed: `paged`
33 373 entries, `edsl` 82 716, `recompile` 124 041,
`packages` 1 307 438, no difference (the main file of every
compilation is an entry now, which is what the numbers are more than
step 1's).

**Costs.** As in 5.2: against the base of the step (`main` at `95acf25`),
the least of twelve runs each, in turns (instructions retired and cycles
of `/usr/bin/time -l`).

| workload | instructions, before | cycles, before | instructions, after | cycles, after |
| --- | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.5 M | 26.8 M | 64.7 M (+0.33 %) | 27.0 M (+0.7 %) |
| `query long.typ heading` | 2964.8 M | 730.2 M | 2965.1 M (+0.01 %) | 745.3 M (+2.1 %) |
| `long.typ` to PDF | 3526.4 M | 857.8 M | 3527.2 M (+0.02 %) | 868.4 M (+1.2 %) |
| `query longer.typ heading` | 14877.5 M | 3756.7 M | 14882.3 M (+0.03 %) | 3725.2 M (-0.8 %) |
| `showcase.typ` to PDF, system fonts | 4404.1 M | 1021.7 M | 4402.3 M (-0.04 %) | 1026.9 M (+0.5 %) |
| `showcase.typ` to PDF, embedded fonts | 3807.1 M | 822.3 M | 3809.5 M (+0.06 %) | 816.4 M (-0.7 %) |
| touying `theme-metropolis.typ` to PDF | 2663.0 M | 694.6 M | 2668.0 M (+0.19 %) | 704.8 M (+1.5 %) |

First compilation and recompilation in a watch session (medians of five
sessions with five edits each, one character appended; nothing is kept
yet, so a recompilation is a compilation from scratch in all builds):

| document | build | first compilation: median (least to most) | recompilation: median (least to most) |
| --- | --- | ---: | ---: |
| `long.typ` | before | 249.5 ms (247.0 to 259.5) | 252.4 ms (243.8 to 261.7) |
|  | step 3 | 258.3 ms (251.2 to 266.1) | 267.4 ms (255.2 to 371.8) |
| `longer.typ` | before | 1360.0 ms (1340.0 to 1370.0) | 1410.0 ms (1360.0 to 1450.0) |
|  | step 3 | 1280.0 ms (1250.0 to 1360.0) | 1320.0 ms (1220.0 to 1440.0) |
| `showcase.typ` | before | 252.6 ms (235.1 to 261.2) | 55.7 ms (47.8 to 95.2) |
|  | step 3 | 250.4 ms (245.5 to 272.2) | 56.1 ms (49.8 to 78.5) |
| touying `theme-metropolis.typ` | before | 247.6 ms (206.2 to 276.3) | 231.5 ms (169.2 to 341.4) |
|  | step 3 | 264.0 ms (216.5 to 275.9) | 202.0 ms (178.5 to 371.4) |

The sessions ran while other builds used the machine: their medians
differ by several per cent in both directions, with no sign in common
with the instruction counts, which are what the step is judged by: up to
+0.06 % on the bench documents, +0.2 % on the touying document and
+0.3 % (0.2 M instructions) on `tiny.typ`; the cycles are within their
spread. The budget of 5.2 (1 % of a compilation from scratch) holds.

What the step adds to a compilation: the fingerprint of the main file's
source (a hash of its text, once per source object), an entry for the
main file with its reads, and per import two integers for the depth.

**Review.** One round by Codex on the diff, "request changes". Fixed:
the store took a fingerprint's word for the source (the entry keeps and
compares it now); the second run of the recording check took the module
of any entry for an import, whatever its reads (it takes the one that is
valid for its world); a rule of the check script that another name for
the world got around (the script lists the uses it allows). Not
changed: `Source::serial` and `Font::serial`, step 1's, are counters of
32 bits, which come round after 2^32 sources or fonts of one process;
the fingerprint of a world's answer is what could then be equal for two
sources, and a module entry compares the source itself.

#### Step 4 as built

Identity and ownership: what the stores take for one value, and who can
write to what they keep. Nothing is kept from one compilation to the next
yet; that is step 5, and this step is what it needs first. On module
equality the step does not build what line 4 of the list above had (the
recommendation of revisions 3 and 4): the owner decided on 2026-10-11 that
modules are exactly upstream's (5.4, "Modules"), and that is built.

**Descriptors.** Upstream: a native function, an element and a type are
a `Static<T>`, which compares by `ptr::eq` and hashes as its address
(`typst-utils/src/static.rs:26` and `:32`). The port compared by the
object too and fingerprinted texts (`Fingerprint for Func`: name, title
and documentation; `for Element`: the key; `for Type`: the long name). A
closure's equality is its hash, which covers what it captured as a
fingerprint, so of two native functions with the same texts a closure
that captured the one was the closure that captured the other, and a
memoized call of the first was answered for the second, in one
compilation. Now a descriptor has a number that no other descriptor of
the process has (`descriptor_serial`, 64 bits), and that number is its
fingerprint. `library/descriptor_identity_wbtest.mbt` has the hole (three
tests that fail with the texts) and looks at the standard library: of
its 296 native functions, 111 elements and 36 types that scopes reach, no
two share their texts, so the hole was a host's (a library with two such
functions, mutation check 22).

What a fingerprint of a descriptor flows into: every fingerprint of
content has its element's, so location keys (`hash128(elem)` in
`realize.mbt`, upstream's `typst_utils::hash128(&elem)` in `prepare`),
the keys of every store, the hashes of pages. Upstream's `Hash for
RawContent` (`content/raw.rs:363`) is the element, which is the address
of its vtable, then the meta data, the hash of the fields and the span:
a location there depends on where the process was loaded, as it depends
here on the order in which the process first used its elements. Nothing
that is written to an output may be derived from the value of such a
hash, and nothing is: the uses of `hash128` in the engine are the
locator, locations and their variants, the keys of what is located
(`prepare`, the cells of a grid, the markers of line numbers), the keys
and results of recorded introspector reads, the convergence check, the
hash of a page in the CLI's export cache, which lives in one process,
and one that never sees a descriptor (the hash of a raster image in the
PDF exporter). SVG ids
hash geometry, fonts and paints (`svg/hash.mbt`). The `svg` stage is
2299 of 2299 byte-identical before and after, `packages svg` 99 of 99,
and the cases of `typst/oracle_wbtest.mbt` that pin which elements share
a location key (generated from the upstream binary) pass unchanged.

**Modules: as upstream.** 5.4 has the rule, the answers of a compilation
from scratch that changed and the documents. In the code:
`ModuleInner.identified` and `Module::canonical` are gone, a module's
fingerprint sets no flag, and `values_memo_equal` takes a module by its
fingerprint (`modules_memo_equal`). The modules of plugins are what they
were. Tests: the cases "modules: .." of `typst/oracle_wbtest.mbt` (the
upstream binary's answers), `library/plugin_identity_wbtest.mbt`
(two plugins without functions; a plugin's module after its cache was
dropped), `typst/modules_wbtest.mbt` (tracing, two libraries),
`eval/import_wbtest.mbt` ("a call that is found again returns the module
of the evaluation before": the two evaluations run in one compilation, so
the closure call is kept between them, with a module that exports
`float.nan`).

**One rule for what a key's flags mean.** Before, each store decided for
itself, and none decided this: `memoize` asked nothing of its key (its
stores are emptied when a compilation starts), `memoized_closure` asked
only whether the fingerprint was lossy, and highlighted raw text, which
is kept by content across compilations already, asked nothing either (an
entry whose styles held a host closure stayed for `max_age` evictions).
Now `memo_fingerprint` returns a `MemoKey`, the fingerprint with its
flags, and two functions of it are the rule for all three
(`library/memo.mbt`): `MemoKey::memoizable` (nothing is looked up or
kept under a lossy fingerprint) and `MemoKey::compilation` with
`compilation_finds` (an entry whose key holds a host closure ends with
the compilation that stored it; outside of a compilation it is kept for
nobody). The key of a closure call has the flags of the function, of the
arguments and of the parts of the context that calls asked for. The
module store has no such key: an entry is a source and a library,
compared as objects. For results the two places are what they were:
`frame_cacheable` and `reads.lossy`.

Host closures are compared as objects wherever an entry compares its
arguments, also where they are behind a hash: `closures_memo_equal` and
`modules_memo_equal` compare the host closures that two closures or two
modules hold, in the order in which the fingerprint visits them
(`same_hosts`), and so do tilings, strokes and decorations, whose frames
and paints the comparison leaves to `==` (`hosts_memo_equal`). The key of
a host closure is only promised to be unique within a compilation; with
these the promise is not relied on where an entry is taken.

**Mutable results.** Every store and cache, with what it keeps, what it
hands out, who writes (searched for, not inferred from types), and what
changed:

| store or cache | keeps | hands out | who could write | changed |
| --- | --- | --- | --- | --- |
| `layout_store` (`memoize`) | frames, as `frame.clone()` of the result; the arguments; the sink | a clone of each frame, on every hit (frames are copy on write); the first caller has the frames it computed | callers move and mutate frames (`push_frame`, `translate`, ..): the clones | as before |
| `counter_sequence_store` | the array of `(CounterState, page)` | the array | the three users in `library/counter.mbt` copy the state they step (`state.copy()`); nothing writes to the array | handed out as a view |
| `works_store` | the `Works`: two private maps; errors; rendered bibliographies with a public `entries` array | the `Works`; of a bibliography, `Works::bibliography` | the maps: `generate_impl` alone. The `entries`: any caller (a `pub(all)` array) | `bibliography` returns a `RenderedBibliography` with a copy of the array. Errors were raised as copies already (step 2) |
| closure store (`memoized_closure`) | the function, a copy of the arguments with their containers marked shared (`Args::copy`), the context, the result marked shared | the result | the evaluator copies a marked array or dictionary before it writes (`Arr::make_mut`). A value of the type `arguments` has no mark and is consumed by reading (`Args::eat`): engine code builds new ones and never consumes one that is a value, a host function can | a result that is `arguments` is kept as a copy and handed out as a copy (`kept_value`) |
| the sink of an entry (the three stores above and the module store) | diagnostics (warnings, delayed errors), introspections, traced values with their styles | appended to the caller's sink | `trace` and `SourceDiagnostic::hint` append to a diagnostic that somebody holds: a delayed error that is promoted is raised through whoever compiled; a host has the warnings of the sink it passed. `Styles::unset`, `apply` on the styles `@typst.trace` returned. The engine writes to styles it made or copied, never to one it was given (every `Styles::set`, `unset`, `apply`, `apply_one` was looked at) | the entry keeps a copy of the sink (`Sink::kept`) and replays copies (`Sink::extend_from_kept`): diagnostics cloned, styles copied, values through `kept_value`. A call without effects keeps no sink |
| module store (`eval_source`) | the source, the module or the errors as a copy, the sink, reads | the module; the errors as a copy (step 3) | a module's scope is a `Scope` that `Module::scope` hands out: nothing writes to it after the evaluation that built it (the `Vm` that did is gone); a host could | the sink, as above |
| `CachedCell` (`layout/flow_collect.mbt`) | the last result of a child's layout by region: frames, or errors | frames, which its callers clone; errors | `trace` on the errors that the caller catches | keeps the errors as a copy, raises copies |
| plugin caches (`plugin_module_cache`, `plugin_call_cache`, `plugin_transition_cache`) | a module, bytes, or a `HintedError` | the same | `HintedString::hint` on an error that was caught (engine code turns it into a diagnostic with `at`, which copies the hints; a host can add one) | errors raised as copies (`raise_kept`) |
| `raw_highlight_cache` (slice 0) | the element, the styles, the lines as a copy of the array | a copy of the array, of immutable content | callers get their own array | ends with its compilation if the key holds a host closure (the rule above) |
| `raster_image_cache`, `pdf`'s `raster_cache` (slice 0) | a `RasterImage` (private fields) or its error; the exporter's image as compressed bytes or a message | the image; the error as a copy (`HintedString::clone`); the exporter's image | nothing writes to a decoded image or to its compressed streams | as before |
| the decode caches (`raw_syntax_cache`, `raw_theme_cache`, `bibliography_cache`, `csl_style_cache`, `pdf_document_cache`) | decoded data; no errors (a failure is decoded again) | the data | a `Bibliography`'s entries and index are written by `decode` alone; syntaxes, themes, styles and PDF documents are read | as before |
| `numbering_pattern_cache` | parsed patterns | the pattern | `Numbering::trimmed` makes a copy with the flag | as before |
| `ElementIntrospector.queries` | per selector, the array of elements | the array, to every caller of `query`, to recorded reads, and as the input that the works entry keeps | nothing in the engine wrote to it (`impl_query` maps it, the others iterate); the signature let anyone | `Introspector::query`, `IntrospectorBackend::query`, `ElementIntrospector::query` and `query_introspection` hand out an `ArrayView` |
| an entry's introspector (`MemoEntry`, `ClosureEntry`) | the backend object, to recognize it | nothing | | the entry keeps `Introspector::serial`, a number per `Introspector::new` (zero for the empty ones), and no longer the backend with every located element of its document |
| `capture_sites`, `data_hashes`, the caches by font | (5.5, "As built") | immutable data | | as before |

A kept document (pages, `DocumentInfo`, options) is slice 3's: no store
keeps one. `Content` is immutable by the engine's rule (its `fields`
array and `lifecycle` are objects that code of the package could write
to and does not).

(Slice 3, as built: two rows more. The store of page runs keeps the
`LayoutedPage`s of a run as clones of what was laid out and hands out
clones, to `finalize_page`, which moves their frames and does not write
to them. The store of documents keeps a clone of the document with a
copy of its info and of its format options and the introspector itself;
`layout_document` hands out a document whose frames and groups are its
own at every depth, with an info and options of its own and the same
introspector, to hosts, which can write to all of it. And one row
changes: a clone of a frame shares its groups with the frame it was
made of, so the "clones" of the first row are safe for callers that
write through the frame's methods, which is every caller inside the
engine, and not for a holder of a group that it took out of
`Frame::items`. Section 8, "Slice 3 as built", "Copies".)

*The view, and what a copy would cost.* `query` could have returned a
copy of the kept array instead. Measured, instructions of a compilation,
the least of twelve runs in turns: `longer.typ` to PDF 17 327.0 M with
the view and 17 326.9 M with a copy, `query longer.typ heading` 14 685.7 M
and 14 688.3 M (+0.02 %), the touying document 2652.0 M and 2653.8 M
(+0.07 %), glossarium's `observatory-handbook.typ` 1000.1 M and 1000.2 M,
hydra's `book-headers.typ` 791.2 M and 791.6 M (+0.05 %). A copy is
within what the count repeats to, and the view is free and says in the
type what the copy would only do: the view it is.

**The harness: as upstream's watch.** With modules as upstream's, a
recompilation with kept closure calls differs from a fresh compilation
where a document compares modules (5.4). `scripts/gen_recompile_upstream.
py` records the upstream binary's `typst watch` on three small projects
(`tests/recompile/upstream/`: `getter`, `nan`, `modules`; 17 steps, at 13
of which upstream's watch gives something else than upstream's fresh
compilation), and the `recompile` stage runs them as sequences of their
own (`tests/runner/recompile_pinned.mbt`, `pinned_verdict`;
`tests/recompile/README.md`, "As upstream's watch"): a fresh compilation
must give upstream's fresh SVG at every step, and the watch loop may give
upstream's watch SVG instead of a fresh compilation's only at a step
where upstream's watch does, byte for byte, with the dependencies and the
diagnostics of a fresh compilation and with page images and a PDF that
are those of its own document. The number of steps that are accepted
this way is part of the verdict: zero as the tree is, 13 once closure
calls are kept (`pinned_as_upstream_expected`).

**The experiment with every store kept** (a local change that is not in
the tree: `memoize` and `memoized_closure` do not empty their stores when
a compilation starts, module entries outlive their scope, `evict(1)`,
which the stage calls before every reference, drops all of them, so that
references are computed from scratch; validation is on). The `recompile`
stage: 240 sequences, none fails; the watch loop gave upstream's watch
output at the 13 pinned steps at which upstream's watch differs from a
fresh compilation, byte for byte, and a fresh compilation's everywhere
else, including the four pinned steps at which upstream's watch agrees
with one. `scripts/recompile_soak.py --minutes 10` with that runner:
124 documents, seeds 1000 to 1004, 620 runs, 3040 sequences, 34 594
steps, 102 372 compilations, 1835 steps compiled again in new processes,
no failure and no abort. (Run three times with the same result: before
the review of the step, on the step as committed, and after `main` with
the native performance work of pull request 74, which changed the
hashers, was merged into the branch. Before the fixtures existed the
stage was also run on the 237 sequences of the other documents alone:
none failed. None of those documents compares modules.)

What upstream's rule means, then, in the sequences of the stage: no
sequence of the 121 documents differs from a compilation from scratch
with every store kept, and the three pinned projects differ at 13 of
their 17 steps, as the upstream binary's watch does on the same files
and edits (the first box of `getter` and `nan`, the first three of
`modules`, red after a comment in `a.typ` and until an edit changes what
the module holds). The port's command line with every store kept gives
the same boxes in a real watch session (the sessions of
`scripts/watch_check.py`). No difference was found that upstream's watch
does not show.

**Mutation checks.** Each put in by hand, one at a time, never
committed. Unit tests first:

| what was broken | what exposed it |
| --- | --- |
| descriptors are fingerprinted by their texts (number 22 of the table in 9.1; the code as it was) | `library/descriptor_identity_wbtest.mbt`, 2 tests: two native functions with the same texts have one fingerprint and their getters are equal closures; "a memoized call is not answered for a twin of what it captured" (the second getter is answered with the first function) |
| an entry with a host closure in its key is found by any compilation (`compilation_finds`) | `library/memo_identity_wbtest.mbt`, 3 tests, one per store: the closure store, a layout, highlighted raw text (the tests keep the stores over two compilations) |
| closures are one argument by their hash alone (`closures_memo_equal` without the host closures) | the same file: "closures that captured two host closures with one key are two arguments" |
| tilings are one argument if `==` says so | the same file: "tilings and strokes that hold two host closures with one key are two arguments" |
| memoized calls take modules by identity, as the port did (number 13, turned round) | `typst/oracle_wbtest.mbt`, "modules: two modules with one hash are two to `==` and one argument of a memoized call" (the upstream binary's answers); `library/plugin_identity_wbtest.mbt`, both tests; `library/memo_identity_wbtest.mbt`, 2 tests |
| a kept sink is replayed as the objects it holds (number 18, for sinks) | `library/memo_owned_wbtest.mbt`, 3 tests (the closure store, a layout, traced `arguments`); `eval/import_wbtest.mbt`, "the warnings an entry keeps are not those of the sinks it is replayed into" |
| the works hand out the bibliography they keep | `library/memo_owned_wbtest.mbt`, "the entries of a rendered bibliography are the caller's" |
| a plugin cache raises the error it keeps | the same file, "an error that a plugin cache keeps is raised as a copy" |
| a `CachedCell` keeps and raises the errors of its layout | `layout/cached_cell_wbtest.mbt` |
| an entry takes any introspector for the one it was computed with | `library/memo_owned_wbtest.mbt`, "an entry knows its introspector by a number, not by the object" |
| `arguments` are kept and handed out as the object they are | the same file, "arguments that a kept call returned or traced are copies" |

A query that hands out the kept array has no test that can fail: with
the view a caller that writes to it does not compile.

And on the `recompile` stage with every store kept (the experiment
above, plus the mutation), of 240 sequences:

| what was broken | failing sequences | what exposed it |
| --- | ---: | --- |
| nothing | 0 | (13 pinned steps as upstream's watch) |
| module entries: world reads not validated (number 1 of the README's mutations) | 126 | first `bench/showcase`, sweep, step 2: dependencies and pages; all three pinned sequences fail too, and their count (1 accepted step, 13 expected) |
| layouts, counter sequences, works: world reads not validated (number 2 there) | 69 | first `bench/tiny`, sweep, step 1: pages |
| closure calls: world reads not validated (number 3 there) | 12 | first `project/book`, sweep, step 1: pages |
| the introspector an entry was computed with is taken for any other, and its reads are not validated (number 11 of 9.1) | the runner aborts | `project/notes` and the `paged` stage end with exit status 134: a kept layout holds locations that the introspector of the iteration does not know. (`bench/tiny` passes: it asks its introspector nothing) |
| the library is not compared, in all three stores (number 12) | 1 | `project/notes`, sweep, steps 2 to 4 (`sys.inputs` changes) |
| the sink of an entry that is found is not replayed (number 14) | 9 | first `suite/introspection/query.typ` `query-running-header`, and the four convergence tests: diagnostics (a warning that a fresh compilation gives is missing) |
| the stores take modules by identity (number 13, turned round) | 2 | `upstream/modules`, steps 1 to 6 and 8: "the pages are not what upstream's watch gives either" (the call `pick((m: m))` is computed again, upstream's is found); and the count of accepted steps, 6 where 13 are expected |

The three mutations of the README give with every store kept what they
gave with one store kept each (122, 69 and 12 of 237: the four more of
the first are the pinned sequences and their count).

**The recording check** (`--check-reads`) on the step as committed:
`paged` 33 509 entries, `edsl` 82 738, `recompile` 125 391, `packages`
1 307 462, no difference.

**Costs.** Against the base of the step (`main` at `07194be`), the least
of twelve runs each in turns, both binaries in one directory
(instructions retired and cycles of `/usr/bin/time -l`):

| workload | instructions before | after | cycles before | after |
| --- | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.7 M | 64.6 M (-0.18 %) | 25.4 M | 24.8 M (-2.1 %) |
| `long.typ` to PDF | 3525.4 M | 3514.9 M (-0.30 %) | 842.5 M | 832.6 M (-1.2 %) |
| `longer.typ` to PDF | 17 513.8 M | 17 345.3 M (-0.96 %) | 4155.6 M | 4102.7 M (-1.3 %) |
| `query longer.typ heading` | 14 876.1 M | 14 710.2 M (-1.11 %) | 3696.8 M | 3624.2 M (-2.0 %) |
| `showcase.typ` to PDF, embedded fonts | 3807.5 M | 3803.9 M (-0.10 %) | 823.3 M | 820.0 M (-0.4 %) |
| touying `theme-metropolis.typ` to PDF | 2665.9 M | 2652.7 M (-0.49 %) | 679.6 M | 675.6 M (-0.6 %) |
| glossarium `observatory-handbook.typ` to PDF | 1006.7 M | 1000.2 M (-0.64 %) | 265.7 M | 264.5 M (-0.4 %) |
| hydra `book-headers.typ` to PDF | 794.1 M | 791.1 M (-0.38 %) | 209.6 M | 208.3 M (-0.6 %) |
| ilm `bakers-handbook.typ` to PDF | 2343.8 M | 2338.6 M (-0.22 %) | 558.3 M | 550.7 M (-1.3 %) |

The step costs nothing: it saves 0.1 to 1.1 % of the instructions of a
compilation, since the fingerprint of an element is a number where it
was a string, and every fingerprint of content has one. The budget of
5.2 (1 % of a compilation from scratch) is not touched.

**Review.** One round by Codex on the diff of the step, asked for two
different arguments that a key takes for one, a kept value that a caller
can still write to, an identity-dependent entry that survives its
compilation, and a case in which the pinned sequences hide a stale
result; the verdict was "request changes".

Fixed:

- *A kept value that a caller can still write to:* a value of the type
  `arguments` that a closure call returned or traced. `Value::shared`
  marks arrays and dictionaries; `arguments` have no mark, and the way
  native code reads them consumes them. A store keeps a copy and hands
  out copies (`kept_value`).
- *Two arguments that a key takes for one:* two tilings (or strokes, or
  decorations) whose frames hold closures that captured two host closures
  with one key. The comparison of arguments leaves a tiling's frame to
  `==`, which takes a closure by its hash. It needs a host that gives two
  functions one key within a compilation, against `HostFunc`'s contract;
  the host closures of such values are compared as objects now, as for
  closures and modules (`hosts_memo_equal`).
- *The pinned sequences:* a step was accepted on its SVG alone, with the
  dependencies and the diagnostics of a fresh compilation; a page image
  that the loop had kept from the step before, or a PDF that was not the
  document's, would have passed with it. Both are compared with what the
  loop's own document gives now. And nothing required the acceptance to
  happen at all once stores are kept: the number of accepted steps is
  part of the verdict (`pinned_as_upstream_expected`).
- The fixture generator took a recompilation that ended with errors for a
  recompilation; it requires a successful one before it reads the SVG.
- The numbers of descriptors and of introspectors were counters of 32
  bits; they are 64.
- A third fixture that the test of the fixtures and `stages.tsv` did not
  know yet.

Looked for and not found: an entry that depends on a host closure and
survives its compilation (with the stores kept as the tests keep them),
a path on which a descriptor is still fingerprinted by a text, a
difference from upstream in a compilation from scratch besides the
module cases of 5.4, a new allocation on the path of a lookup.

Not changed: where the comparison of arguments asks `==` for a value
that is none of the above and could hold a closure, a host closure in it
is still taken by its key (no such value is known; "For step 5" below).

**For step 5.**

- The plugin caches get comemo's ages before closure calls are kept
  (5.4, "Plugins"): dropped as a whole on every tenth `evict`, they make
  a plugin's module a new object while kept calls hold the old one, and
  `==` between the two is `false` where upstream's watch, whose entry of
  `Plugin::module` is still in use, says `true`. That would be a
  difference that upstream does not show.
- `pinned_as_upstream_expected` (`tests/runner/recompile_pinned.mbt`)
  becomes 13 with the commit that keeps the closure store, and the
  stage's references must still be computed from scratch: the stage
  calls `evict(1)` before every reference, which will no longer empty
  stores that have ages (it must become `evict(0)`, or the references
  are answered from the loop's entries).
- An entry with a host closure in its key ends with its compilation by
  `MemoKey::compilation`, which is `memo_generation`: the number of the
  `with_layout_memo` in progress. A compilation inside another has its
  own; the outer one finds its entries again afterwards.
- The module store has no rule for host closures and needs none while a
  module can only hold those of its library, which is part of what an
  entry is for. A host that puts a host closure into `sys.inputs` gets a
  new library with every change of the inputs.
- Where the comparison of arguments asks `==` for a value that is not a
  tiling, a stroke or a decoration and that could hold a closure, a host
  closure in it is still taken by its key. No such value is known.
- Entries no longer hold their introspector, so what 6.2 measured for
  "the introspector of its compilation and iteration" is gone from what
  a kept entry costs.
- The capture table stays per compilation (5.4).
- With the port's memoization off, a document with two modules of one
  hash says something else than with it on (and than upstream): the
  references "without memoization" of the stage are references of what
  a compilation from scratch computes, and the oracle cases of the kind
  `memoized` are not compared with memoization off.

#### Step 5 as built

Ages. The stores of memoized calls outlive their compilation, which is
what the four steps before this one were for, and `typst watch`
recompiles a small edit in a fraction of a first compilation. Nothing in
`cli/watch.mbt` changed: its loop was upstream's already (`world.reset()`,
the compilation, `@library.evict(10)` where upstream calls
`comemo::evict(10)`, `typst-cli/src/watch.rs:83`). What changed is that
nothing empties a store any more.

**comemo's rule, and where it is in the port.** `comemo/src/memoize.rs`:

    pub fn evict(max_age: usize) {                       // :100
        for subevict in EVICTORS.read().iter() { subevict(max_age); }
        accelerate::evict();
    }
    fn evict(&mut self, max_age: usize) {                // :150, CacheData
        self.tree.retain(|entry| {
            let age = entry.age.get_mut();
            *age += 1;
            *age <= max_age
        });
    }
    .inspect(|entry| entry.age.store(0, Ordering::SeqCst))   // :166, lookup

An entry is inserted with age zero (`:183`), every `evict` adds one and
keeps it while the age is at most `max_age`, a hit sets it to zero, and
`evict(0)` drops everything. So an entry survives `max_age` evictions
without a hit and goes with the next. Every store has exactly that:

| store | entry | found by, valid by | a hit | evictor | limit per key |
| --- | --- | --- | --- | --- | --- |
| module evaluations (`eval/import.mbt`, `eval_memo`) | `EvalMemo.age` | the source's fingerprint; the same source, library, route answers and depth, traced answers, world reads (step 3) | `age = 0` | `EvalMemos::evict`, registered with the first entry | 12 of age zero (`eval_memo_max_entries`) |
| closure calls (`library/memo.mbt`, `closure_store`) | `ClosureEntry.age` | function, arguments, traced span, asked parts of the context; arguments exactly, library, route, introspector reads, world reads | `age = 0` | `ClosureStore::evict` | 4 of age zero (`memo_max_entries`) |
| what the calls of one function and arguments asked of their contexts (`ClosureStore.asked`) | the eviction count of its last use, above the three flag bits | the fingerprint of function and arguments | written when it differs from the count of now: once per fingerprint between two evictions | the same evictor | one value |
| layouts (`layout_store`), counter sequences (`counter_sequence_store`), works (`works_store`): `memoize` | `MemoEntry.age` | the key of the call; arguments exactly, library, introspector reads, world reads (the works: route tracked) | `age = 0` | `MemoStore::evict`, one per store | 4 of age zero |
| results by content: decoded raster images, highlighted raw text, the PDF exporter's images (slice 0) | `ContentEntry.age` | what upstream hashes | `age = 0` | `ContentCache::evict` | one per key (raw text: 4) |
| decode caches: syntaxes and themes of `raw`, bibliographies, CSL styles, PDF documents, plugin modules, plugin calls and transitions, numbering patterns | the same (`ContentCache`, new in this step) | the hash of the bytes (plugins: of plugin, function and arguments; patterns: of the string) | `age = 0` | the same | one per key |

`@library.evict(max_age)` calls every registered evictor and sweeps the
hashes of data (`data_hashes`, as before). There is no list of caches in
`evict` any more: the count of calls and the wholesale drop on every
`max_age`-th call are gone.

**The order.** One store per commit, each with the `recompile` stage, the
recording check and its mutation (the numbers are in "Mutation checks"
and "Measured" below):

1. the decode caches get ages, the plugin sequence of upstream's watch is
   recorded and pinned, the references of the stage are computed after
   `evict(0)`;
2. module evaluations are kept;
3. closure calls are kept, and `pinned_as_upstream_expected` is 16;
4. layouts are kept;
5. the counter sequence and the works are kept, and `MemoStore` loses its
   generation;
6. the hosts;
7. what the review found (below), with a fifth sequence of upstream's
   watch (`pinned_as_upstream_expected` is 18), and the accelerator of
   introspector reads.

**What the earlier steps had left for this one.**

*Plugins* (5.4, "Plugins"; "For step 5" of step 4). Upstream memoizes
`Plugin::module(bytes)` (`typst-library/src/foundations/plugin.rs`), so
the module of a plugin is one object for as long as comemo's entry lives,
and `==` compares module objects. With closure calls kept, a document can
see the age of that entry. What upstream's watch does was recorded with
the upstream binary (`plugin.rs:261`; `scripts/gen_recompile_upstream.py`,
scenario `plugin`; `tests/recompile/upstream/plugin.json`, 15 steps): a
project with three plugins that export no function, one loaded by the main
file and two by imported files, with getters `mine() = q`, `early() = p`,
`late() = r` in the main file and the boxes `mine() == q`, `early() == p`,
`late() == r`.

| step | what changes | upstream's watch | a fresh compilation |
| --- | --- | --- | --- |
| 1 to 10 | the main file (a comment) | true, true, true | the same |
| 11 | a comment in the file that loads `p`: ten evictions after `p` was loaded | true, true, true: the entry is alive, the plugin is the module it was | the same |
| 12 | a comment in the file that loads `r`: eleven evictions after | true, true, **false**: the entry was evicted, `r` is loaded again as another module, and `late()` is found and returns the old one | true, true, true |
| 13, 14 | the main file; the first file again | true, true, **false** | true, true, true |

The plugin of the main file is asked for in every compilation and stays
one module for the whole session. The port's plugin caches were dropped
as a whole on every tenth `evict`, used or not: at step 10 all three
modules would have been dropped, and steps 11 to 14 would show `false`
where upstream shows `true`. They are `ContentCache`s now, the watch loop
gives upstream's boxes at all 15 steps, and the stage's count of pinned
steps fails if an entry lives one eviction longer or shorter (mutation
checks). A fixture can hold binary
files (hexadecimal, `binary`).

*The other decode caches.* None of their results compares by identity
(a syntax and a theme compare by the hash of their bytes, 5.5; a
bibliography, a CSL style and a PDF document are data), so for them the
ages are what 6.1 wanted them for: what is in use is not decoded again
every tenth compilation. They were arrays searched by comparing bytes, or
maps keyed by the bytes; they are found by `data_hash` now, which is
computed once per `Bytes` object.

*The module store* is registered with `evict` (above).

*Limits per key.* `memo_max_entries` (4, first in, first out) was a
limit of entries of one compilation, since a store was emptied when the
next one started. Kept across compilations as it was, it would drop the
first result of a key when the key got its fifth, whatever its age, and
that can be seen (the review found it): a function that reads a file and
returns a module it captured has one result per content of the file, and
upstream's watch still finds the first result after six contents, with
the module of that evaluation, which is not `==` to the module of now
(`tests/recompile/upstream/limit.json`, recorded from the upstream
binary: `false` at the two steps where a content comes back). comemo has
no limit. So the limit is on the entries that were stored or found since
the last `evict` (age zero): within a compilation it is what it was, in a
process that never evicts every entry is young and it bounds the store as
before, and in a process that evicts, an entry of an earlier compilation
goes by its age, as comemo's. A key then holds at most four results per
eviction that is still within `max_age`. Module entries had no limit;
they have the same rule with 12 (`eval_memo_max_entries`), and an entry
that a scope that is still open stored or took is not dropped for it, so
within a compilation a file is one module for every import that asks the
same, as upstream.

*The references of the stage* are computed after `evict(0)`, with
memoization on and off, and share nothing with the watch loop; the
mutation checks below show by what. (`evict(1)`, which the stage called
while only the decode caches outlived a compilation, does not empty what
has an age. It happened to be enough for the loop's entries, each of
which the loop's own `evict(10)` has made one eviction old; `evict(0)`
does not rest on that.)

*`eval_memo_kept`*, the private switch of the tests of steps 3 and 4, is
gone. `memo_test_next_compilation` (step 4's tests) stays: it starts a
compilation by hand without ending the one before, so that what its tests
show is that an entry with a host closure in its key is not found, not
that it was dropped.

*The capture table* (`eval/captures.mbt`) stays per compilation. With
persistent trees an entry would be valid forever (rule 1 of 5.5 with the
node as the key), so this is a question of cost alone. What a kept table
would save is the analysis and the node hash of the closure and context
expressions that a recompilation evaluates, and those are the expressions
of the files that changed: the module of every other file is found as a
whole, with its closures, which hold their captured scopes and the cached
hash of their node. Measured against a build that never drops the table
(medians of fifteen recompilations in three watch sessions): the touying
document after an edit of its main file 23.9 ms with the table dropped and
23.1 ms with it kept, after an edit of a file of the package 117 ms and
116 ms, the project `notes` 8.2 ms and 8.2 ms; the differences are inside
the spread. What it would cost is a table that holds a node of every
expression of every version of every file, with ages and an evictor. It
stays as it is.

**With memoization off** (`set_layout_memo_enabled(false)`), a compilation
takes nothing from an earlier one and leaves nothing for a later one.
`memoize` and `memoized_closure` are not asked (as before), the results
kept by content neither, and the module store answers within the scope
only: an entry that such an evaluation stores ends with its scope
(`EvalMemo.scoped`), and it takes no entry of a scope that is closed
(`EvalMemo::lives`). The store cannot simply be off, since a file is one
module for all imports of a compilation with or without memoization.
Found by a test that passed for the wrong reason: `typst/modules_wbtest.
mbt` compiles one document with memoization on and then off, and the
second compilation found the first's evaluation of the main file, with
the answers of memoized calls in it. So `evict(0)` is a first compilation
with memoization, and `evict(0)` with the switch off is a clean slate;
the decode caches do not ask the switch (a plugin loaded twice in one
compilation is one module, which a document can see), and `evict(0)`
empties them.

**`evict` at any time.** Upstream calls it between compilations. Here a
host function can call it inside one (a compilation of `doc` inside a
callback ends with it). Nothing holds on to an array of entries across
the call it memoizes (the module store read its array before the
evaluation and pushed to it after; it reads the store again), and the
evaluations of files that an open scope stored or took are not dropped
or aged: a file that is imported again in that compilation must be the
module it was (deviation 17). The scope that keeps an entry is the
outermost open one that stored or took it (scopes nest; the review found
that an entry taken by an outer scope from a scope inside it went with
the inner one).

**Entries that end with their compilation** (a host closure in the key,
`MemoKey::compilation`) were emptied with their store when the next
compilation started. Now the rule of step 4 is what keeps a later
compilation from finding them (`compilation_finds`), and they are dropped
when the outermost compilation ends (`end_compilation_entries`; a store
registers for it with its first such entry, so a process without host
closures runs nothing), since nothing can find them afterwards. The same
for what belongs to them (the review): highlighted raw text under styles
with a host closure, and what the calls of a function with a host
closure asked of their contexts.

**The recording check** (`--check-reads`) computes every entry that is
about to be kept a second time. With kept stores an entry that is found
is not computed, so fewer entries are checked (the `recompile` stage:
80 787, where step 4 had 125 391). Its second run must leave no trace in
what has an age: the stores are set aside as before, and a
`ContentCache` neither makes an entry young nor takes a new one while it
runs. Without that, the stage under `--check-reads` gave upstream's watch
output at 13 of the 16 steps that were pinned then: the second run
evaluates the files that the first run found evaluated, so the plugins of
the imported files were asked for in every compilation and never got old.
And a call of the second run answers what the first run was answered
(`ClosureStore::original`, as an import of the second run gives the
module of the first): the first run may have found the call, with the
module of an earlier evaluation, and a document that reads one file or
another by comparing that module with the module of now would read the
other file in a run that computes the call (the review; `typst/
tracked_world_wbtest.mbt`). The check on the step as committed: `paged`
33 509 entries, `edsl` 82 738, `recompile` 80 787, `packages` 1 307 462,
no difference.

**Hosts.**

- *`typst watch`*: as above. The scenarios of `scripts/watch_check.py`
  pass on native and on wasm (14 scenarios on native; on wasm 13, and
  `links` skipped as before: that build cannot tell a symbolic link);
  five of them are new, `pinned-*`, which replay the fixtures of
  `tests/recompile/upstream`
  with both binaries: there, and nowhere else in that script, the output
  of a recompilation is compared with what upstream's watch wrote and
  not with a fresh `typst compile`.
- *`typst compile`, `query`, `eval`*: one compilation, nothing found,
  nothing evicted. What the machinery costs them is below ("Measured").
- *A host that keeps a world* (`@typst.compile`, `compile_with`): the
  contract of section 7, now in the doc comment of `compile_with`. It
  keeps its library, book, fonts and sources as objects and calls
  `evict`.
- *`doc`*: a compilation or a lowering ends with `@library.evict(10)`
  (deviation 20). A script that compiles one document does not notice.
  When a process compiles several: the layout of content that is equal
  with its origins, the calls of Typst functions (from `Markup` and from
  packages), the evaluations of imported files and packages (validated
  against the new session's world, whose files answer the same) and what
  is kept by content are found again; what involves a callback has a
  host function in its key and ends with its compilation; what read the
  origin listing or a snippet read a volatile file and was never kept
  (`doc/volatile_test.mbt`, whose count of reads changed: a later
  lowering reads a data file once to see that the kept evaluation is not
  for it, and once to evaluate).
- *The runner*: a stage that compares with upstream's compilation from
  scratch calls `@library.evict(0)` before every compilation
  (`runner_slate`), so that a case is a first compilation whatever ran
  before it and whatever the filter is. `--keep-memo` makes that
  `evict(10)`: the cases of a stage then share the stores like the
  compilations of a host with many worlds. `paged --keep-memo`: 2299 of
  2299 pass, and so they do with no eviction between the cases at all
  (the runner of the commit before `runner_slate`; 335 MB instead of
  235 MB).
- *Unit tests* share a process per package and call the same functions
  with the same arguments, so a test whose expectations count
  computations starts with `evict(0)` (`memo_test_begin`, `read_test`,
  `with_empty_store`, the works tests). The tests that relied on a fresh
  store, each looked at: the closure-store and tracked-world tests of
  `library` (8 tests found the entries of the tests before them: the
  helpers evict); "each compilation has its own results", which is no
  longer true and is now a test of the ages; highlighted raw text
  outside of a compilation (its count of entries); the works tests of
  `typst`, whose helper compiles a document and then asks for the works
  with the document's introspector, and finds what the compilation
  generated (the helper evicts); the depth test of the module store (a
  second world with the same file finds the first world's evaluation);
  `typst/modules_wbtest.mbt` (above: the store boundary was wrong, not
  the test); `doc/volatile_test.mbt` (above). `moon test`: 6156 tests,
  none failing.

**Mutation checks.** Each put in by hand (a script per mutation, applied
to a copy of the tree, never committed), on the default `recompile` stage
of the final tree: 242 sequences. `tests/recompile/README.md` has the
table in full; in short:

| what was broken (number in 9.1) | failing sequences | first exposed at |
| --- | ---: | --- |
| module entries: world reads not validated (README 1) | 127 | `bench/showcase`, sweep, step 2; the watch loop gives upstream's watch output at 1 of the 18 pinned steps |
| layouts, counter sequences, works: world reads not validated (README 2) | 69 | `bench/tiny`, sweep, step 1 |
| closure calls: world reads not validated (README 3) | 13 | `project/book`, sweep, step 1; the watch loop gives upstream's watch output at 16 of the 18 pinned steps |
| all three at once | 176 | `bench/tiny`, sweep, step 1; the watch loop gives upstream's watch output at 1 of the 18 pinned steps |
| `import_file` reads the source around the tracked method [1] | 47 | `project/book`, sweep, step 1; the watch loop gives upstream's watch output at 1 of the 18 pinned steps |
| `DataSource::load` reads the file around the tracked method [2] | 88 | `bench/showcase`, sweep, step 2; the watch loop gives upstream's watch output at 13 of the 18 pinned steps |
| `resolve_package` reads the manifest around the tracked method [3] | 9 | `suite/scripting/import.typ/import-from-package-items`, sweep, step 1 |
| a failed read is not recorded [4] | 9 | `suite/model/bibliography.typ/bibliography-multiple-files`, random sequence, step 5 |
| `today` does not record [5] | 5 | `project/book`, sweep, step 1 |
| `book` does not record [6a] | 0 | no sequence: the stage's edit of the fonts changes the book and the fonts, and the other read rejects the entry (with neither recorded: the row below). `library/tracked_world_wbtest.mbt`, 4 tests; `paged --check-reads`: 22 964 of 33 509 entries differ, in 1683 tests |
| `font` does not record [6b] | 0 | no sequence, for the same reason. The same 4 tests; `paged --check-reads`: 22 800 entries differ, in 1657 tests |
| neither `book` nor `font` records [6a and 6b] | 68 | `bench/tiny`, sweep, step 1 |
| the reads of an entry that is taken are not noted for the calls around it [7] | 15 | `project/book`, sweep, step 11; the watch loop gives upstream's watch output at 17 of the 18 pinned steps |
| a source is its id and text to the module store, also after an edit [8] | 61 | `bench/tiny`, random sequence, step 3; the watch loop gives upstream's watch output at 15 of the 18 pinned steps |
| the reparser writes to the nodes it is given (`SyntaxNode::make_mut` copies nothing) [9] | 0 | no sequence: a recompilation evaluates the file that changed again, with the capture analysis and the closure hashes of its nodes as they are now, and finds nothing that was made from the nodes as they were. `syntax/persistent_test.mbt` (4 tests), `syntax/persistent_property_test.mbt`, `typst/persistent_wbtest.mbt` ("a closure of an earlier evaluation runs the body it was made from") |
| the capture table finds an analysis by span alone [10] | 0 | no sequence (the table is per compilation). `eval/captures_wbtest.mbt`, "captures: kept per node for one compilation": the test executable aborts |
| the introspector reads of an entry are not validated [11] | the runner aborts (exit status 134) | before the first sequence is done, as in step 4: a kept layout holds locations that the introspector at hand does not know |
| the library is not compared, in all three stores [12] | 1 | `project/notes`, sweep, step 2 |
| the stores take modules by identity instead of by their hashes [13] | 1 | `upstream/modules`, the pinned sequence, step 1; the watch loop gives upstream's watch output at 11 of the 18 pinned steps |
| the sink of an entry that is found is not replayed [14] | 11 | `suite/introspection/query.typ/query-running-header`, random sequence, step 5 |
| an entry that was validated in any scope passes in every scope [17] | 176 | `bench/tiny`, sweep, step 1; the watch loop gives upstream's watch output at 1 of the 18 pinned steps |
| a module entry hands out the errors it keeps [18] | 1 | `suite/scripting/import.typ/import-cyclic-in-other-file`, sweep, step 2 |
| no file is volatile [19] | 0 | no sequence (no document of the stage has a file that changes during a scope). `doc/volatile_test.mbt`, `library/tracked_world_wbtest.mbt` (2), `typst/tracked_world_wbtest.mbt`: 4 tests |
| the equality of an SVG image leaves out the images it links [20b] | 0 | no sequence. `library/works_wbtest.mbt` ("svg: an image is its data, its fonts, .."), `typst/state_outside_wbtest.mbt` ("svg: a tiling of an SVG is as good as the images the SVG links") |
| native functions are fingerprinted by their names [22] | 0 | no sequence (no two functions of the standard library share a name). `library/descriptor_identity_wbtest.mbt`, 3 tests |
| the fingerprint of an SVG image leaves out the images it links [20a] (README 4) | 3 | `project/linked`, sweep, step 5 |
| the works are found by their elements alone, without a read of the files [16] (README 5) | 1 | `suite/model/bibliography.typ/bibliography-multiple-files`, sweep, step 3 |
| the plugin caches are also dropped as a whole on every tenth `evict`, as they were | 1 | `upstream/plugin`, the pinned sequence, step 8; the watch loop gives upstream's watch output at 15 of the 18 pinned steps |
| a `ContentCache` drops an entry one eviction early (`age >= max_age`) | 1 | `upstream/plugin`, the pinned sequence, step 11; the watch loop gives upstream's watch output at 15 of the 18 pinned steps |
| a `ContentCache` keeps an entry one eviction longer | 0 | the watch loop gives upstream's watch output at 15 of the 18 pinned steps; no sequence fails by itself: the pinned plugin sequence gives a fresh compilation's pages where upstream's watch does not |
| a hit does not make an entry of a store young | 0 | the watch loop gives upstream's watch output at 15 of the 18 pinned steps; no sequence fails by itself |
| the limit per key counts every entry, whatever its age (as it did) | 0 | the watch loop gives upstream's watch output at 17 of the 18 pinned steps; no sequence fails by itself: the pinned sequence `limit` gives a fresh compilation's pages at the step where the first content comes back. `library/memo_closure_wbtest.mbt`, "the limit per key is on what no eviction has seen yet" |
| a hit in a second run of the recording check makes a `ContentCache` entry young (`--check-reads`) | 0 | the watch loop gives upstream's watch output at 15 of the 18 pinned steps; the count of pinned steps, under `--check-reads` only |
| a closure call of the second run of the recording check goes on with what it computed (`--check-reads`) | 0 | no sequence under `--check-reads` (no document of the stage reads a file by a comparison of modules). `typst/tracked_world_wbtest.mbt`, "the recording check: a call of the second run answers what the first run was answered" |
| an entry with a host closure in its key is found by any compilation, and is not dropped when its own ends | 0 | no sequence (no host closure in the stage). `library/memo_identity_wbtest.mbt`, 4 tests |
| what ends with its compilation is not dropped when the outermost compilation ends | 0 | no sequence. `library/memo_identity_wbtest.mbt`, 2 tests |
| with memoization off an evaluation takes the entries of earlier scopes | 0 | no sequence (a reference of the stage starts after `evict(0)`). `eval/import_wbtest.mbt` ("with memoization off an entry ends with its scope"), `typst/modules_wbtest.mbt` |
| an outer scope does not become the keeper of a module entry that it takes from a scope inside it | 0 | no sequence. `eval/import_wbtest.mbt`, "an outer scope keeps an entry that it took from a scope inside it" |
| the accelerator of introspector reads has one answer per introspector, whatever the read | the runner aborts (exit status 134) | before the first sequence is done |
| the accelerator of introspector reads answers for any introspector | the runner aborts (exit status 134) | before the first sequence is done |

"No sequence" rows are mutations of things that no document of the
stage can reach (a host closure, a volatile file, two functions with one
name) or that another check is for; each is exposed by the tests named.
Three rows fail no sequence by themselves and are caught by the count of
pinned steps alone, which is why the count is part of the verdict: an
entry that lives one eviction longer, a hit that does not make an entry
young, and the limit per key as it was. The stage's edit of the fonts
changes the book and the fonts together, so `book` and `font` not
recording are each hidden by the other there (6a, 6b) and are seen
together (68 sequences) and one by one by the recording check.

That the references share nothing with the loop: with no eviction before
a reference and everything else as it is, 0 sequences fail (a
reference is a new world with a library object of its own, and no entry
of the loop is one for it); with the library not compared and the
validation of world reads off besides, 181 fail, 115 of
those failures seen by the reference without memoization alone, since
the reference with memoization is then answered from the loop's stores
and is wrong with it (with `evict(0)` and the same three validations
off: 176, 4 by that reference alone). `evict(0)` is
what makes the reference with memoization independent when everything
else fails, and memoization off what makes the second reference so.

**Soak.** `scripts/recompile_soak.py` on the final tree: 126 documents,
seeds 9000 to 9012, 36.9 minutes with 12 jobs (while the other gates of
the step ran on the machine): 1638 runs, 7930 sequences, 90 237 steps, 267
045 compilations, 4849 steps compiled again as the first compilation of a
new process; 0 failures, 0 aborts.

**Measured.** aarch64 macOS, native release, PDF output,
`--ignore-system-fonts`, `scripts/watch_check.py --bench`: per document
five watch sessions of every binary in turns, each a first compilation and
five edits of every kind (every edit from the file as it was at first; the
durations of the status lines; medians of the 25 recompilations, of the
five first compilations). The machine was not quiet (other builds, the
mutation checks of this step, and three groups of documents measured at
once): the least of a row is up to 24 % below its median, and the same
sessions on a quieter machine were 5 % faster throughout (`long.typ` after
an edit at the end 91 ms). "Before" is `main` at `e4eb440`; the columns
after it are the commits of this step, each with the stores named so far
kept, and "as merged" is the step with what the review changed and the
accelerator of introspector reads (below); upstream is the binary of
`e58a63af` with its threads, and the ratio is of the last two columns.

| document | edit | before | modules | + closure calls | + layouts | + counters, works | as merged | upstream | ratio |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `long.typ` | first compilation | 239 | 252 | 254 | 242 | 245 | 241 | 113 | 2.1 |
| | end | 243 | 246 | 245 | 95.3 | 97.1 | 96.7 | 25.8 | 3.8 |
| | middle | 244 | 248 | 244 | 111 | 109 | 106 | 29.6 | 3.6 |
| | comment | 243 | 249 | 246 | 101 | 103 | 102 | 14.2 | 7.2 |
| `longer.typ` | first compilation | 1240 | 1260 | 1240 | 1230 | 1230 | 1220 | 542 | 2.2 |
| | end | 1260 | 1290 | 1260 | 528 | 540 | 509 | 131 | 3.9 |
| | middle | 1260 | 1310 | 1280 | 576 | 598 | 555 | 152 | 3.6 |
| | comment | 1270 | 1310 | 1300 | 580 | 613 | 545 | 67.9 | 8.0 |
| `showcase.typ` | first compilation | 251 | 250 | 247 | 251 | 272 | 264 | 176 | 1.5 |
| | end | 55.2 | 55.4 | 55.0 | 27.0 | 27.2 | 26.7 | 8.8 | 3.0 |
| | middle | 55.0 | 55.3 | 56.3 | 26.9 | 26.1 | 25.5 | 8.7 | 2.9 |
| | imported | 57.4 | 56.7 | 56.0 | 27.7 | 28.6 | 28.1 | 10.3 | 2.7 |
| | comment | 56.7 | 55.1 | 56.6 | 27.3 | 26.0 | 27.3 | 7.1 | 3.9 |
| touying | first compilation | 204 | 206 | 205 | 205 | 202 | 204 | 161 | 1.3 |
| | end | 167 | 153 | 48.6 | 27.2 | 26.6 | 25.9 | 12.8 | 2.0 |
| | middle | 167 | 155 | 48.3 | 26.8 | 26.9 | 26.6 | 13.5 | 2.0 |
| | imported | 165 | 160 | 128 | 122 | 123 | 122 | 95.5 | 1.3 |
| | comment | 168 | 156 | 44.5 | 21.5 | 21.8 | 21.7 | 3.7 | 5.8 |
| handbook | first compilation | 168 | 173 | 173 | 166 | 172 | 170 | 118 | 1.4 |
| | end | 80.6 | 78.1 | 76.6 | 32.0 | 31.9 | 31.6 | 11.5 | 2.8 |
| | middle | 78.3 | 78.5 | 76.4 | 32.5 | 32.8 | 30.9 | 11.4 | 2.7 |
| | imported | 90.7 | 89.5 | 88.3 | 81.5 | 81.8 | 81.4 | 28.8 | 2.8 |
| | comment | 79.0 | 81.7 | 78.4 | 32.9 | 31.8 | 31.4 | 5.5 | 5.7 |
| `book` | first compilation | 97.4 | 102 | 98.8 | 97.6 | 98.4 | 97.0 | 71.9 | 1.3 |
| | end | 34.2 | 33.5 | 32.8 | 17.6 | 12.7 | 12.8 | 4.4 | 2.9 |
| | middle | 33.5 | 33.8 | 33.0 | 17.6 | 12.7 | 12.9 | 5.1 | 2.5 |
| | imported | 34.2 | 34.0 | 34.2 | 21.9 | 17.1 | 16.9 | 6.7 | 2.5 |
| | comment | 34.1 | 34.3 | 32.8 | 17.9 | 13.2 | 12.9 | 2.8 | 4.6 |
| `chain` | first compilation | 5.3 | 6.1 | 6.0 | 5.4 | 5.4 | 5.4 | 4.2 | 1.3 |
| | end | 3.9 | 3.8 | 3.5 | 3.3 | 3.2 | 3.3 | 1.4 | 2.3 |
| | middle | 3.8 | 3.7 | 3.7 | 3.1 | 3.0 | 3.0 | 1.4 | 2.2 |
| | imported | 3.8 | 3.6 | 3.6 | 3.0 | 3.0 | 3.0 | 1.0 | 3.0 |
| | comment | 3.8 | 3.6 | 3.6 | 2.9 | 3.0 | 2.9 | 1.0 | 2.8 |
| `notes` | first compilation | 17.0 | 18.1 | 17.2 | 17.7 | 17.4 | 17.0 | 9.8 | 1.7 |
| | end | 15.6 | 16.0 | 14.7 | 8.6 | 8.6 | 8.6 | 3.8 | 2.3 |
| | middle | 15.4 | 16.4 | 14.5 | 8.9 | 8.8 | 8.7 | 3.6 | 2.4 |
| | imported | 15.6 | 16.1 | 14.9 | 10.5 | 10.6 | 10.3 | 4.6 | 2.2 |
| | comment | 15.9 | 16.3 | 14.6 | 8.6 | 8.9 | 8.6 | 3.0 | 2.9 |
| `linked` | first compilation | 3.7 | 3.6 | 3.6 | 3.6 | 3.7 | 3.6 | 3.8 | 1.0 |
| | end | 3.0 | 3.0 | 3.0 | 2.8 | 2.5 | 2.6 | 1.5 | 1.7 |
| | middle | 2.5 | 2.6 | 2.6 | 2.6 | 2.4 | 2.3 | 1.6 | 1.5 |
| | comment | 2.6 | 2.6 | 2.5 | 2.2 | 2.2 | 2.1 | 1.2 | 1.7 |
| deck | first compilation | 576 | 582 | 583 | 576 | 583 | 580 | 109 | 5.3 |
| | end | 51.6 | 51.9 | 41.2 | 18.8 | 18.4 | 18.2 | 15.9 | 1.1 |
| | middle | 51.2 | 52.8 | 40.6 | 20.6 | 18.1 | 17.6 | 16.0 | 1.1 |
| | comment | 50.7 | 51.6 | 40.6 | 17.9 | 17.8 | 17.3 | 14.5 | 1.2 |

The edits: "end" is a character appended to the main file; "middle" an
edit in the middle of it (in `long.typ` and `longer.typ` the body of the
loop that makes every section: every heading changes); "imported" a
change of a value in an imported file that reaches the pages (the size of
a text in the theme of the touying deck and in the running header of the
handbook, an inset in the shared module of `book` and `notes`, a word in
`chain`'s `d.typ`, the title of an entry of `showcase.typ`'s
bibliography); "comment" a comment appended to the main file, after
which nothing on the pages changes. `book`, `chain`, `notes` and `linked`
are the projects of `tests/recompile/docs`; the deck is `bench/mkdeck.
py`'s (43 pages, 28 PNGs, no package).

Against the expectations of 3.3 (the "kept" column for the documents of
text, "+ slice 0" for those with images and code, since slice 0 is
built), after an edit at the end:

| document | expected | measured | first compilation, before and after |
| --- | ---: | ---: | ---: |
| `long.typ` | 96 | 96.7 | 239 and 241 |
| `longer.typ` | 503 | 509 | 1240 and 1220 |
| `showcase.typ` | 24 | 26.7 | 251 and 264 |
| touying | 24 | 25.9 | 204 and 204 |
| handbook | 30 | 31.6 | 168 and 170 |
| deck | 332 (before slice 0c; 53 as measured with it) | 18.2 | 576 and 580 |

No row misses its expectation by more than a tenth (`showcase.typ`: 11 %).
The others of 3.3: `long.typ` after an edit of every heading 106 ms where
the probe had 101; `longer.typ` after the same 555 ms where the probe had
569; the touying document after an edit in the middle 26.6 ms where the
probe had 29; after an edit of a file of its package 122 ms where the
probe had 116; the handbook after an edit in the middle 30.9 ms where the
probe had 31; after an edit of a file of its package 81.4 ms where the
probe had 86. So what the probe gave for the stores that exist, kept, is
what they give with every read recorded and validated, every argument
compared and every kept thing copied: the optimism that section 8 warned
of did not cost anything that these sessions can show. Against upstream
the ratio after an edit at the end is 1.7 to 3.9 (it was up to 13, for the
touying document), which is the ratio of the first compilations (1.0 to
2.2) times what the block level, the page runs and the document are for
(3.3, the later columns). It is largest after a comment, 3.9 to 8.0 for
the bench and package documents, where upstream finds its page runs and
its document again and the port lays out and exports as after any edit.
The deck is at 1.1: its recompilation was the export of its images, which
slice 0c took away, and what is left is evaluation and paragraphs. Each
store, in the columns: the modules alone are worth a little where a
package is evaluated (the touying document 167 ms to 153 ms), closure
calls are the evaluation of a package document (to 49 ms), layouts are
most of the rest everywhere, and the works of a bibliography are a third
of what was left of `book`, whose citations are inside blocks (17.6 ms to
12.7 ms). The counter sequence, kept, made `longer.typ` slower until its
reads had an accelerator (540 ms and 528 ms; as merged 509 ms). A first
compilation is what it was (the first row of every document; the
differences have no sign in common and are within the spread).

*What a first compilation and a one-shot `typst compile` pay.* Against
the base of the step (`main` at `e4eb440`), the least of twelve runs each
in turns, both binaries in one directory (instructions retired and cycles
of `/usr/bin/time -l`):

| workload | instructions before | after | change | cycles before | after | change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.9 M | 64.9 M | +0.04 % | 34.3 M | 33.7 M | -1.6 % |
| `long.typ` to PDF | 3267.8 M | 3261.2 M | -0.20 % | 833.3 M | 816.7 M | -2.0 % |
| `longer.typ` to PDF | 15980.5 M | 15823.9 M | -0.98 % | 4100.8 M | 3969.6 M | -3.2 % |
| `query longer.typ heading` | 13551.7 M | 13385.7 M | -1.23 % | 3616.0 M | 3322.4 M | -8.1 % |
| `showcase.typ` to PDF, embedded fonts | 3784.0 M | 3783.9 M | -0.00 % | 839.3 M | 875.3 M | +4.3 % |
| touying `theme-metropolis.typ` to PDF | 2600.1 M | 2598.5 M | -0.06 % | 704.2 M | 695.8 M | -1.2 % |
| ilm `bakers-handbook.typ` to PDF | 2283.3 M | 2281.4 M | -0.08 % | 602.4 M | 582.3 M | -3.3 % |
| the book of `tests/recompile/docs` to PDF | 1381.7 M | 1381.7 M | +0.00 % | 346.5 M | 352.0 M | +1.6 % |

An entry has one field more (its age), a module entry three, the lookup
of the module store asks whether memoization is on, a compilation that
ends asks whether a store has entries to drop (none has without host
closures), and a store no longer compares its generation and clears. No
evictor runs. Before the review's changes the counts were between
-0.6 % (`tiny.typ`) and +0.06 % (`longer.typ`); what the table has
besides is the accelerator of introspector reads, which saves 1 % of a
compilation of `longer.typ`. The cycles are of a busy machine and within
their spread. The budget of 5.2, 1 % of a compilation from scratch, is
not touched; the first compilations of the watch sessions are in the
table above.

*The second budget of 5.2*: validation at most 5 % of a recompilation in
which everything hits. Such a recompilation exists now: the main file
written again with the bytes it has. Sampled (`/usr/bin/sample`, 1 ms, 8 s
of a watching process that is made to recompile again and again; shares
of the samples inside compilations, of 900 to 5200 samples per document):

| document | world reads validated | of which the world answering | introspector reads validated | arguments compared | keys fingerprinted | layout of the document | export |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `long.typ` | 0.1 % | 0.0 % | 0.5 % | 2.8 % | 3.9 % | 59.6 % | 37.3 % |
| `longer.typ` | 0.0 % | 0.0 % | 1.4 % | 3.7 % | 4.3 % | 59.8 % | 35.4 % |
| `showcase.typ` | 3.5 % | 1.6 % | 0.5 % | 2.6 % | 1.3 % | 35.0 % | 58.7 % |
| touying | 8.1 % | 8.1 % | 2.5 % | 1.8 % | 4.8 % | 62.2 % | 27.1 % |
| handbook | 0.6 % | 0.5 % | 1.8 % | 3.2 % | 3.4 % | 42.1 % | 53.6 % |

The validation of world reads is `TrackedWorld::validate`. For
`long.typ`, `longer.typ` and the handbook it is a sample or two. For
`showcase.typ` it is 3.5 %: the CLI's file store reads every dependency
again after a reset, as upstream's does, so its image, its PDF, its SVG
and its bibliography are read and their bytes hashed in every
recompilation (2 MB). For the touying document it is 8.1 % (2 ms), all
of it below `slot_of`, in the world: 32 files, the document, the package
and its imports, 0.8 MB, each read, decoded and compared with the source
that the slot had. comemo validates by making the same calls on
upstream's world, which reads the same files. The bookkeeping of the
tracked world (the stamp, the slots, the pushes) is under 0.2 %
everywhere, so the budget holds for what it was set for; what the world
does to answer is over it for a document with a large package, and what
would take that away is not in this design's scope: a file store that
does not read a file whose modification time is what it was (5.2,
"Costs"; "not scheduled"). The other validations are the ones that
existed before anything was kept: introspector reads replayed (0.5 to
2.5 % with the accelerator below; 2.4 to 7.1 % without it), arguments
compared exactly (2 to 4 %, deviation 3), keys fingerprinted (1 to 5 %).

**Memory.** The resident set size of the watching process (`ps`, after
the status line; `scripts/watch_check.py --bench-memory`), PDF output,
after the first compilation and after 10, 50 and 200 edits, every edit a
text that the session has not had. "Before" is the base of the step,
which emptied its stores when a compilation started.

| document | edits | binary | first | after 10 | after 50 | after 200 | peak |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| longer | at the end | before | 171 MB | 174 MB | 174 MB | 174 MB | 174 MB |
| longer | at the end | after | 171 MB | 219 MB | 224 MB | 224 MB | 224 MB |
| longer | at the end | upstream | 319 MB | 1974 MB | 2163 MB | 2213 MB | 2213 MB |
| longer | every heading | before | 171 MB | 175 MB | 175 MB | 175 MB | 175 MB |
| longer | every heading | after | 171 MB | 310 MB | 324 MB | 324 MB | 324 MB |
| longer | every heading | upstream | 320 MB | 2174 MB | 2404 MB | 2436 MB | 2436 MB |
| longer | every heading, a character longer each time | before | 171 MB | 175 MB | 176 MB | 199 MB | 199 MB |
| longer | every heading, a character longer each time | after | 171 MB | 307 MB | 335 MB | 596 MB | 596 MB |
| longer | every heading, a character longer each time | upstream | 325 MB | 2174 MB | 2554 MB | 3719 MB | 3719 MB |
| longer | every paragraph | before | 171 MB | 175 MB | 175 MB | 175 MB | 175 MB |
| longer | every paragraph | after | 171 MB | 947 MB | 1030 MB | 1030 MB | 1030 MB |
| longer | every paragraph | upstream | 325 MB | 2762 MB | 3122 MB | 3190 MB | 3190 MB |
| touying | at the end | before | 82 MB | 86 MB | 86 MB | 86 MB | 86 MB |
| touying | at the end | after | 82 MB | 86 MB | 87 MB | 87 MB | 87 MB |
| touying | at the end | upstream | 86 MB | 109 MB | 109 MB | 111 MB | 113 MB |
| touying | in the middle | before | 82 MB | 85 MB | 85 MB | 85 MB | 85 MB |
| touying | in the middle | after | 82 MB | 86 MB | 86 MB | 87 MB | 87 MB |
| touying | in the middle | upstream | 86 MB | 105 MB | 110 MB | 107 MB | 110 MB |
| touying | the theme of the package | before | 83 MB | 91 MB | 92 MB | 92 MB | 92 MB |
| touying | the theme of the package | after | 82 MB | 151 MB | 159 MB | 159 MB | 159 MB |
| touying | the theme of the package | upstream | 82 MB | 245 MB | 286 MB | 294 MB | 296 MB |
| deck | at the end | before | 236 MB | 256 MB | 256 MB | 256 MB | 256 MB |
| deck | at the end | after | 236 MB | 255 MB | 256 MB | 257 MB | 257 MB |
| deck | at the end | upstream | 246 MB | 308 MB | 301 MB | 316 MB | 323 MB |
| deck | in the middle | before | 236 MB | 256 MB | 256 MB | 256 MB | 256 MB |
| deck | in the middle | after | 236 MB | 256 MB | 256 MB | 256 MB | 256 MB |
| deck | in the middle | upstream | 285 MB | 350 MB | 314 MB | 316 MB | 376 MB |
| deck | every slide | before | 234 MB | 255 MB | 255 MB | 256 MB | 256 MB |
| deck | every slide | after | 236 MB | 259 MB | 260 MB | 260 MB | 260 MB |
| deck | every slide | upstream | 277 MB | 349 MB | 339 MB | 362 MB | 376 MB |

Every row of the port is flat from 50 edits on and within a tenth of
that after 10 (but the rows of the edit that grows, below): the ages
work, and what a session holds is what its last eleven compilations used.
The plateaus of `longer.typ`: 224 MB for edits at the end (50 MB more
than a process that keeps nothing: an edit at the end is a new module,
the content of the whole file, 6.2), 324 MB for edits of every heading
(6.2 measured 358 MB of live heap after ten such edits), and 1030 MB for
edits of every paragraph, which is the bound that 6.1 gave as "about
1.1 GB" and did not measure: eleven times the layouts of the document.
Upstream holds 2.2 GB, 2.4 GB and 3.2 GB in the same sessions. A deck of
images does not grow (its images are kept by content since slice 0; the
layouts of a slide are small), and a package document grows by what its
slides are (87 MB, and 159 MB when every edit changes the theme). The
rows "a character longer each time" are of an edit after which the
document itself grows over 200 edits, in all three programs: they are
there to say that the edit of the first measurement was not one to show
a plateau with.

Bounds. Every store and every cache with an age is bounded by what the
last `max_age` + 1 compilations used. What has no age: the caches by
font, each with a limit of entries since the review (above); the capture
table, of one compilation; the hashes of data by identity, swept as
before. In a process that never evicts, a key holds at most four results
and a source twelve evaluations, and the number of keys is what the
process computed, as with comemo.

**The accelerator of introspector reads.** Not asked for by the design,
and found by the watch numbers: with the counter sequence kept,
`longer.typ` recompiled 2 to 6 % slower than with the layouts alone
(the table above; in sessions on a quieter machine 499 ms and 480 ms
after an edit at the end, 554 ms and 531 ms in the middle). An entry is validated by replaying its introspector reads, and
every result that an earlier iteration or compilation left under a key
is a candidate. The read of a counter sequence is the query of all the
counter's updates, whose fingerprint is that of every heading of the
document, and each candidate computed it again before it was rejected.
comemo has an accelerator for exactly this (`comemo/src/accelerate.rs`:
per tracked value a map from the hash of a call to the hash of its
result, "so that validation makes a call once per id"). The port has it
now for the introspector (`ReadAccelerator` in `library/introspector.
mbt`): the fingerprint of the answer to a read, by the key of the read,
for the introspector that was asked last (an introspector answers the
same forever and has a number, step 4). `longer.typ` after an edit at the
end, in those sessions: 461 ms; a first compilation gains too (1185 ms
to 1150 ms; 1 % of its instructions, above), since the iterations of one
compilation validate the same reads.

**Review.** One round by Codex (`gpt-6-astra`, reasoning effort xhigh)
on the diff of the step up to the hosts, asked for an edit sequence after
which a kept entry is found although something it depended on changed
(anything not in its key, its recorded world reads or its recorded
introspector reads: process state, identity, order of evaluation, a
cache that was evicted under it), for a reference in the harness that is
not independent of the watch loop, for differences from comemo's ages
that a document can see, and for unbounded growth. The verdict was
"request changes". It found no stale result (it names what it looked at:
the stamps and shared lists of world reads, volatile reads, keys and the
comparison of arguments, library, context, route and tracing, the
validation of introspector reads, nested compilations, memoization off)
and no cache that carries a result past `evict(0)`, and it checked the
ages against comemo 0.5.1 line by line. Seven findings.

Fixed:

- *The limit per key against comemo's ages* (an upstream difference that
  a document can see): above, "Limits per key". Its reproduction is the
  fifth pinned sequence.
- *The recording check rejects a correct entry* where a document
  branches on the identity of a module that a found call returned:
  above, `ClosureStore::original`.
- *An outer scope loses a module entry that it took from a scope inside
  it*: above, the outermost open scope keeps it.
- *What ends with its compilation leaves things behind* (highlighted raw
  text, the `asked` records): above.
- *Caches by font that grow with a session's edits.* The caches by font
  are functions of their keys and no `evict` knows them (6.3), but three
  have more than a font in their key or hold what a host can make again
  and again: the outlines of the SVG exporter (the scale of a glyph: a
  watch session to SVG adds an outline per glyph and text size tried),
  shape plans (the features of the text), the hashes of font data by the
  identity of the `Bytes`. Each of the caches by font has a limit now and
  is emptied when it is full (65 536 outlines, boxes, bitmaps and colour
  glyph frames, 4096 shape plans, 1024 faces and overhang tables, 256
  font data hashes, the oldest first for the last).
- *The twin of the `edsl` stages was evaluated after the lowering*, whose
  evaluations of imported files it could take: `runner_slate` before it.

Not changed, with the reason:

- *`eval_string` is not memoized* (upstream memoizes it,
  `typst-eval/src/lib.rs:101`). With two plugins without functions, whose
  modules have one hash, `for m in (a, b) { eval("m", scope: (m: m)) == m }`
  is `(true, false)` in upstream, which finds the first evaluation again,
  and `(true, true)` here. This is a difference in a compilation from
  scratch, older than this step and of the kind of 5.4's table; the
  design has `eval_string` under "not scheduled" (its world plumbing is
  slice 1's, so nothing stands in its way any more). It is recorded in
  section 10 and is the first thing to build after this step if the
  quirk is to be reproduced.
- *A host that never evicts and holds modules* still sees the limit of
  twelve evaluations per source where comemo would keep a thirteenth.
  That is deviation 4, which bounds a process that never evicts; comemo
  does not bound it.
- *`evict(0)` does not empty the caches by font* (6.3's design). A
  reference of the harness shares them with the loop. They hold no
  result that can be stale; with the limits above they are bounded.

**For slices 2 and 3.**

- A new memoized function (blocks, page runs, the document) is a
  `MemoStore`: it has ages, an evictor, the limit of four per key and the
  drop at the end of a compilation without doing anything. What it must
  bring is what every entry needs (key, exact arguments, cacheable
  results, copies) and its mutation: the validation of its world reads
  off must fail sequences of the `recompile` stage, and
  `pinned_as_upstream_expected` must still be 16.
- Page runs and documents are slice 3's first kept results that hold a
  whole document's frames: 6.2's numbers for what a store costs are per
  layout entry and do not cover them. The memory table above is the
  baseline to measure against.
- After a recompilation in which everything hits, what is left is the
  document-level realization, the flow and the export (the table of the
  second budget: layout of the document 35 to 62 %, export 27 to 59 %),
  which is what slices 2 and 3 are for, and then the PDF writer, which
  no slice is for.
- The introspector reads of a layout entry are validated by replaying
  them (0.5 to 2.5 % of such a recompilation). Slice 3's document entry
  would make the introspector of an unchanged document the same object
  in the next iteration and compilation, and the shortcut by its number
  (step 4) would then skip the replay.
- A recompilation reads every dependency again (the CLI's file store
  after `reset`, as upstream's). For a document with a large package that
  is the largest part of what validation costs.
- `evict(0)` does not drop the caches by font (6.3). A reference of the
  harness shares them with the loop; they are functions of their keys
  and have limits.
- The limits per key (four results, twelve evaluations) count what is
  young (deviation 4). A key's entries are searched in order, the oldest
  first, and each candidate is compared with the arguments exactly before
  it is validated: under `evict(10)` a key can hold up to 44 results, and
  a slice whose keys collect many should measure that search.
- The accelerator of introspector reads is for the introspector that was
  asked last. A slice that validates against two introspectors in turns
  (a document entry that is validated against the introspector of the
  iteration before) would thrash it: make it a table by introspector
  then.
- `eval_string` is not memoized (the review; section 10). It is the one
  place where a compilation from scratch is known to differ from
  upstream's in what `==` says of modules.

### Slice 2: the block level

`layout_single_impl` and `layout_multi_impl` through `memoized_layout`,
with the keys of upstream's signatures plus the resolved locator and the
route, as fragments have them. Files: `layout/flow_collect.mbt`,
`library/memo.mbt`.

One thing in the way: `dyns_memo_equal` answers `false` for two `CellGrid`
values that are not the same object, and a table's block holds one, made
anew by every realization. With that, no table is ever found again (the
probe: 38 block layouts per iteration of `long.typ`, which has 36 tables,
missed in every compilation until entries were found by their keys alone).
The comparison gets a real case for `CellGrid`; what it costs is measured
with the slice.

Expected ("+ blocks"): `long.typ` 92 ms to 56 ms, `longer.typ` 507 ms to
313 ms, the touying document 22 ms to 18 ms, the handbook 30 ms to 26 ms,
nothing for the deck. Risk: low; the machinery is the fragments'. Left
out: the locator as a tracked argument (section 10).

#### Slice 2 as built

The layouts of blocks are memoized: every block, table, grid, list, shape,
image and display equation of a flow is found again by a later
introspection iteration and by a later compilation, like a paragraph.
After an edit at the end, `bench/long.typ` recompiles in 57 ms where it
took 97 ms, `longer.typ` in 282 ms where it took 503 ms ("Measured"
below).

**Upstream's functions, and the port's keys.**
`typst-layout/src/flow/collect.rs`:

    #[comemo::memoize]                                   // :420
    fn layout_single_impl(
        world: Tracked<dyn World + '_>,
        library: &LazyHash<Library>,
        introspector: Tracked<dyn Introspector + '_>,
        traced: Tracked<Traced>,
        sink: TrackedMut<Sink>,
        route: Tracked<Route>,
        elem: &Packed<BlockElem>,
        locator: Tracked<Locator>,
        styles: StyleChain,
        region: Region,
    ) -> SourceResult<Frame>

and `layout_multi_impl` (`:520`), the same with `regions: Regions` and
`SourceResult<Fragment>`. To comemo, `library`, `elem`, `styles` and
`region` or `regions` are hashed, the world, the introspector, the traced
span, the route and the locator are tracked, and the sink is tracked
mutably (its calls are replayed). In the port
(`layout/flow_collect.mbt`, the two functions under their names, each
with its body in `layout_single_compute` and `layout_multi_compute`):

| argument | upstream | the port |
| --- | --- | --- |
| `elem` | hashed | in the key (`Fingerprint for Content`), and kept and compared (`content_memo_equal`, deviation 3) |
| `styles` | hashed | in the key (`StyleChain::memo_hash`), kept and compared (`chain_memo_equal`) |
| `region` | hashed (`size`, `expand`) | in the key: both sizes, both flags |
| `regions` | hashed (`size`, `expand`, `full`, `backlog`, `last`) | in the key: the sizes, the flags, `full`, the backlog with its length, `last` with whether there is one |
| `library` | hashed | compared as an object by the store (deviation 7) |
| `locator` | tracked | the resolved locator in the key (`Locator::memo_hash`, deviation 1) |
| `route` | tracked | the whole route in the key (`Route::memo_hash`, deviation 1) |
| `traced` | tracked | the span in the key (in `memoize`, deviation 2) |
| `world` | tracked | the reads of the call recorded and validated (`TrackedWorld`, 5.2) |
| `introspector` | tracked | the reads of the call recorded and replayed to validate |
| `sink` | tracked mutably | a copy kept and replayed |

Both go through `memoized_layout`, the store of paragraphs and fragments,
with a key that starts with the name of the function, so they have what
that store has without a line of their own: ages and the evictor, the
limit of four young results per key, the end with its compilation of an
entry whose key holds a host closure, the recording check. Errors are not
kept (deviation 5); the `CachedCell` of the child keeps the last one, as
before.

**What was in the way: the grid.** As the design said. Verified first,
with the two functions memoized and the comparison as it was: a
recompilation of `long.typ` found 359 block layouts and computed 114, in
every compilation: 38 per iteration in three iterations, the number of
the probe, of a document with 36 tables. `dyns_memo_equal` answered `false` for two
`CellGrid` values that are not the same object, and the synthesized
`grid` field of a grid or table (upstream `Arc<CellGrid>`,
`layout/grid/mod.rs:412`, `model/table.rs:281`) is made anew by every
realization. With the comparison below: 473 found, none computed.

The comparison (`library/memo_grid.mbt`, `cell_grids_memo_equal`) covers
what upstream's `#[derive(PartialEq, Hash)]` of the grid types covers
(`typst-library/src/layout/grid/resolve.rs`), which is also what the
port's `Fingerprint for CellGrid` writes, field by field:

| type | upstream | compared |
| --- | --- | --- |
| `CellGrid` | `:657` | `entries`, `cols`, `rows`, `vlines`, `hlines`, `headers`, `footer`, `has_gutter` |
| `Entry` | `:628` | a cell, or the parent it is merged with |
| `Cell` | `:571` | `body`, `fill`, `colspan`, `rowspan`, `stroke` (four sides), `stroke_overridden`, `breakable` |
| `Line` | `:396` | `index`, `start`, `end`, `stroke`, `position` |
| `Header`, `Footer` | `:426`, `:445` | `range` (`start`, `end`), `level`, `short_lived` |
| `Repeatable` | `:470` | the child, `repeated` |

It is finer than `==` where every comparison of arguments is: the body of
a cell by all stored fields (`content_memo_equal`), and a tiling in a
fill or a stroke with the host closures of its frame as objects
(`hosts_memo_equal`). The cheap parts are compared first.

*What it costs.* Counted (a counter in a local build): a compilation of
`long.typ` makes 108 grids that are fingerprinted (36 tables in three
iterations), fingerprints each once and compares 114 pairs, for 473 block
lookups; the table document below 30, 30 and 35 per recompilation. So
the fingerprint of a grid is computed once per realized grid, not per
lookup: it is part of the fingerprint of the element that holds it, which
a `Content` caches (`data_hash`), and that is where upstream's `LazyHash`
is (the fields of a packed element). There is nothing to cache besides.
Sampled (`/usr/bin/sample`, 1 ms, a watching process that recompiles
after edits at the end; shares of the samples inside compilations):

| document | a recompilation | the grids fingerprinted | the grids compared | all arguments compared | for scale: the grids resolved (realization) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `long.typ` (36 tables, 25 pages) | 57 ms | 2.2 % | 0.7 % | 3.4 % | 5.1 % |
| 30 tables of 408 cells each (12 240 cells, 42 pages) | 150 ms | 4.8 % | 1.9 % | 2.2 % | 11.3 % |

A third of the fingerprint is the strokes of the cells, four per cell,
each written as the value it would be (`fingerprint_stroke`): the place
to look if a table document needs it.

**The other values that the comparison takes for different although they
are the same.** Looked for in `values_memo_equal`, `dyns_memo_equal` and
the `Eq` of every type they leave to `==`:

- `CellGrid` was the only case of `DynValue` that answered by identity.
  Every other payload either has a case that walks into it (states,
  counters, selectors, tags, the layout callbacks, the lines of raw
  text) or an `Eq` that compares what it holds (alignments, directions,
  regular expressions, spot colorants, strokes and decorations with
  their paints, locations, paths, CSS properties, loaded data, syntaxes
  and themes by the hash of their bytes).
- A value that is not equal to itself: a float that is NaN (`float.nan`
  as a value; a length that is NaN is equal to itself). `==` says
  `false`, so it is the same argument only as the same object (the
  comparison starts with identity, which is why a later iteration of one
  compilation finds it), and after an edit of its file the paragraph,
  the block or the closure call that holds it is computed again. Held
  by: any field of an element, any style property, any argument of a
  closure call, directly or in an array or a dictionary. Upstream hashes
  the bits and finds it. Not changed here: it is the comparison of every
  store, not the block level's, what it costs is a computation, and a
  NaN in content is rare.
- A module is taken by its hash (the owner's decision, 5.4), a closure by
  its hash and its host closures, a native function, an element and a
  type by the descriptor: none of them says
  "different" for the same thing.

**Layout callbacks: looser than upstream, and one case closed.**
Upstream's `InlineCallback`, `BlockSingleCallback` and
`BlockMultiCallback` hash their captured element and their function
pointer (`layout/container.rs:609`, `#[derive(Hash)]`; `PartialEq`
compares the captured element alone, `:648`). A function has no identity
here, and the port's fingerprint of a callback is its kind and its
captured element. That is the same key as long as an element type has
one callback per kind, which holds for the show rules of
`layout/rules.mbt` (22 element types with a block callback and one with
an inline callback besides, each with one function per kind). It did not hold between them and
`BlockElem::multi_layouter_content`, which captures any content (the
test runner's `bounds`): a block that lays out a `pad` element with
`layout_pad` and one that lays out the same element with a host's
function had one fingerprint and compared equal. No document was found
that puts two such blocks at one place with the same styles (the element
of a rule is prepared, the content that a function is handed is not, and
one inside the other is another locator), but with blocks memoized that
is the key of a layout, so the two are told apart now
(`BlockMultiCallback.typed`, in the fingerprint and in the comparison;
`library/memo_callback_wbtest.mbt`). What remains is the rule: one
callback per kind for an element type, and one function for equal
content among the callbacks for plain content (section 10, item 21).

**Mutable results.** `memoize` keeps `copy(output)` and hands out
`copy(entry.output)`, and for a layout `copy` is a copy-on-write clone
of every frame (`Frame::clone`: the item array is shared and both frames
are marked; the first write through either copies the array and clones
the groups in it, `frame.mbt`). That is what both functions return (a
`Frame`, kept as a fragment of one, and a `Fragment`), so it covers them
as it covers paragraphs:

- The callers: `SingleChild::layout`, `MultiChild::layout_full` and
  through it `MultiSpill::layout`. Each keeps what it gets in its
  `CachedCell` and hands out clones, so the copies of the store are a
  second layer here: with either of them removed for blocks alone no
  test and no sequence fails (below); the rule is tested at the store
  (`library/memo_frames_wbtest.mbt`, which fails without either).
- Tags are items like any other, with their content, which is immutable.
  A frame whose tags hold a host closure, or whose text or shapes are
  painted with a tiling whose frame holds one, is not kept
  (`frame_cacheable`, asked for every frame of a result, at every
  depth): a block's frame has nothing that a fragment's has not (its
  fill and stroke are shapes).
- What a clone does not protect: a frame taken out of a group of an
  `items()` view and written to directly. The nested frame is one object
  in the store's array and in the caller's until the caller's array is
  copied, and a write that does not go through the frame that owns the
  array copies nothing. `items()` is a read-only view by the contract of
  `frame.mbt`; every write to a frame in the engine and in the exporters
  was looked at (`grep` for the methods that write, on anything reached
  through `.frame`): `Frame::hide` goes into groups after the copy, and
  `layout/pages.mbt` writes to the frame of a page it made. A host that
  holds a document and does it writes to what the stores keep, for
  paragraphs and fragments since step 5 and for blocks now. It would
  take a deep copy per hit to rule that out, and the same host can write
  to the glyphs of a text item, which no copy of frames reaches; the
  line is where `frame.mbt` draws it. `typst/block_memo_wbtest.mbt`,
  "the frames of a kept layout are not those of the document", is the
  test of what holds: every page of a document hidden, moved, resized,
  emptied, and the next compilation finds the layouts as they were.

**Tests** (each fails without what it names):

- `library/memo_grid_wbtest.mbt`: two grids built from the same cells
  are one argument (the test of the comparison as it was: `false`); 40
  grids that differ from it in one component each are other arguments,
  to the comparison and to the fingerprint, and the same inside an
  element; host closures in a body, a fill, a stroke and the stroke of a
  line are compared as objects.
- `typst/block_memo_wbtest.mbt`, with `@layout.block_memo_stats()`, the
  number of block layouts that were found and that were computed: a
  table, a grid, blocks in blocks, a block that breaks and shapes are
  found by the next compilation (none computed) and after an edit at the
  end (at most two computed); blocks are found by the later iterations
  of one compilation; tables that differ in a cell, a fill, a stroke,
  the stroke of one cell, a column size, a header flag, a line or a
  footer are laid out, with the table that did not change found, and
  give the pages of a compilation without memoization; one block at
  three places is three layouts; a block that breaks is laid out for
  the regions it gets; the same block under other styles; a block that
  reads a file, one that queries the document and one under another
  library are laid out again; a host's block on routes of two depths
  and under two libraries that its callback tells apart; the warnings
  of a block that is found are reported again; the frames.
- `library/memo_callback_wbtest.mbt`, `library/memo_frames_wbtest.mbt`.

**The document of the stage.** `tests/recompile/docs/blocks` (the README
there describes it): what the block level keeps, and four blocks whose
layout depends on what is neither their text nor their styles. The
existing documents exposed the validations of world reads and of
introspector reads for blocks alone (40 and 25 documents), but not the
locator, the regions after the first, the library and the sink, each of
which the new document exposes: 127 documents, 244 sequences, 1476
steps, 4406 compilations; none fails, and the watch loop gives
upstream's watch output at the 18 pinned steps.

**Mutation checks.** Each put in by a script on the tree, one at a time,
never committed; the default `recompile` stage (244 sequences, seed 1)
and the tests above. A mutation "for blocks" is behind a switch that
only the two functions pass, so that the paragraphs and fragments inside
a block, which have the same validations, do not hide it.

| what was broken, for blocks alone (number in 9.1) | failing sequences | first exposed at; tests |
| --- | ---: | --- |
| the world reads of an entry are not validated [1 to 6, for this store] | 47, in 40 documents | `project/blocks`, sweep, step 2 (the fonts); "a block that reads a file is laid out again when the file changes" |
| the introspector reads of an entry are not validated [11] | 42, in 25 documents | `bench/long`, sweep, step 0 (the second iteration of the first compilation); 3 tests |
| the locator is not in the key | 2 | `project/blocks`, sweep, step 0; "the same block at three places is three layouts" |
| the regions are not in the key of `layout_multi_impl` | 10 | `bench/long`, sweep, step 0; 2 tests |
| the region is not in the key of `layout_single_impl` | 14 | `bench/long`, sweep, step 0; 1 test |
| the backlog and `last` are not in the key | 2 | `project/blocks`, sweep, step 0; "a block that breaks is laid out for the regions it gets" |
| the styles are neither in the key nor compared | 17 | `project/book`, sweep, step 5; "the same block under other styles is another layout" |
| the sink of an entry that is found is not replayed [14] | 2 | `project/blocks`, sweep, step 0 (a warning is missing); "the warnings of a block that is found are reported again" |
| the route is not in the key | 0 | no sequence: in a document the route of a layout is as deep as the layout is nested, and what is nested differently has another locator. "a block is laid out for the route it is on": a host's block on routes of two depths, the deeper one a level too deep |
| the library is not compared [12] | 0 | no sequence: a block of a document that can tell two libraries apart has another key under each (the closure of a `context` block captured `sys`; default styles are in the chain). "a block whose callback asks the library is laid out per library": a host's callback that asks for a feature |
| an entry keeps the frames its caller has; an entry hands out the frames it keeps | 0 and 0 | nothing: `CachedCell` clones |
| the same two for every layout of the store | 40 and 26 | `bench/long`, sweep, step 0; `library/memo_frames_wbtest.mbt` |
| the grid comparison as it was (equal only as the same object) | 0 | all of `library/memo_grid_wbtest.mbt` and the block tests that find a table; `long.typ` computes 114 block layouts in every recompilation |
| the grid comparison leaves out one component (31 mutations, one per field compared), compares a body with `==`, or leaves the host closures of a fill or a stroke to `==` (3) | 0 | each fails "a grid that differs in one component .." at the grid that differs in it, or "host closures in a body, a fill and a stroke .." |
| a callback for plain content is the callback of its content's rule, to the fingerprint or to the comparison | 0 | `library/memo_callback_wbtest.mbt` |

Two mutations fail no sequence because no document can tell: the route
(determined by where a layout is) and the library (determined by what a
block holds); each has a test with a host's callback, which the review
asked for. One pair is exposed by nothing: the copies for blocks alone,
a second layer under `CachedCell`'s. The grid comparison cannot fail a
sequence: a grid is a function of the fields of its element and of the
styles, which are in the key themselves, so two different grids never
meet under one key in a document, and a too coarse comparison is only
ever asked about grids that are equal. It is a unit under test, one grid
per component, and so is its fingerprint (no two of the 41 grids share
one). `tests/recompile/README.md`, "The block level", has the table in
full.

**The recording check** (`--check-reads`): `paged` 45 820 entries,
`edsl` 122 459, `recompile` 116 341, `packages` 1 359 403; no entry
differs, and the verdicts of the stages are what they are without it
(the 18 pinned steps included). There are more entries than before
(`paged` 33 509, `recompile` 80 787): every block is one.

**Soak.** `scripts/recompile_soak.py --minutes 20` with the runner of the
slice and cold references (three steps of every run compiled again as
the first compilation of a new process): 127 documents, seeds 12000 to
12009, 30.0 minutes with 10 jobs (the runs in flight are finished; the
mutation checks and the measurements of the slice ran beside it): 1270
runs, 6150 sequences, 70 015 steps, 207 225 compilations, 3760 cold
references; 0 failures, 0 aborts.

**Measured.** As in step 5: aarch64 macOS, native release, PDF output,
`--ignore-system-fonts`, `scripts/watch_check.py --bench`, five watch
sessions of every binary in turns, each a first compilation and five
edits of every kind; medians of the 25 recompilations and of the five
first compilations, milliseconds. "Before" is `main` at `565eac6`. The
machine was not quiet (the mutation checks of this slice and the
conversion sweep ran on it): the least of a row is up to a tenth below
its median.

| document | edit | before | after | upstream | after / upstream |
| --- | --- | ---: | ---: | ---: | ---: |
| `long.typ` | first compilation | 239 | 234 | 111 | 2.1 |
|  | end | 97.0 | 56.6 | 25.3 | 2.2 |
|  | middle | 106 | 67.7 | 29.3 | 2.3 |
|  | comment | 101 | 59.9 | 14.0 | 4.3 |
| `longer.typ` | first compilation | 1170 | 1130 | 523 | 2.2 |
|  | end | 503 | 282 | 125 | 2.3 |
|  | middle | 547 | 335 | 148 | 2.3 |
|  | comment | 510 | 307 | 67.3 | 4.6 |
| `showcase.typ` | first compilation | 240 | 239 | 164 | 1.5 |
|  | end | 23.9 | 20.4 | 7.9 | 2.6 |
|  | middle | 24.3 | 20.3 | 8.0 | 2.6 |
|  | imported | 26.0 | 22.3 | 9.2 | 2.4 |
|  | comment | 24.2 | 20.2 | 6.4 | 3.1 |
| touying | first compilation | 198 | 195 | 147 | 1.3 |
|  | end | 24.8 | 19.3 | 10.8 | 1.8 |
|  | middle | 25.9 | 20.5 | 11.4 | 1.8 |
|  | imported | 116 | 114 | 86.7 | 1.3 |
|  | comment | 20.3 | 14.6 | 3.5 | 4.2 |
| handbook | first compilation | 156 | 156 | 105 | 1.5 |
|  | end | 28.8 | 25.8 | 9.6 | 2.7 |
|  | middle | 28.0 | 25.9 | 9.9 | 2.6 |
|  | imported | 74.4 | 73.7 | 22.1 | 3.3 |
|  | comment | 28.5 | 25.8 | 5.3 | 4.9 |
| `book` | first compilation | 92.6 | 93.6 | 70.1 | 1.3 |
|  | end | 11.7 | 11.5 | 4.2 | 2.7 |
|  | middle | 12.1 | 11.3 | 4.6 | 2.5 |
|  | imported | 15.8 | 15.8 | 6.5 | 2.4 |
|  | comment | 12.2 | 11.6 | 2.6 | 4.5 |
| `chain` | first compilation | 5.0 | 4.9 | 3.8 | 1.3 |
|  | end | 2.9 | 2.9 | 1.2 | 2.4 |
|  | middle | 2.6 | 2.8 | 1.2 | 2.2 |
|  | imported | 2.6 | 2.6 | 0.9 | 2.9 |
|  | comment | 2.6 | 2.5 | 0.9 | 2.9 |
| `notes` | first compilation | 15.3 | 15.6 | 8.4 | 1.9 |
|  | end | 7.6 | 6.9 | 2.9 | 2.4 |
|  | middle | 7.6 | 7.3 | 3.0 | 2.5 |
|  | imported | 9.5 | 9.0 | 3.6 | 2.5 |
|  | comment | 7.9 | 7.0 | 2.5 | 2.8 |
| `linked` | first compilation | 3.3 | 3.2 | 3.0 | 1.1 |
|  | end | 2.4 | 2.4 | 1.2 | 1.9 |
|  | middle | 2.2 | 2.1 | 1.4 | 1.5 |
|  | comment | 2.0 | 2.0 | 1.0 | 2.0 |
| deck | first compilation | 544 | 555 | 77.3 | 7.2 |
|  | end | 15.2 | 15.3 | 14.5 | 1.1 |
|  | middle | 16.4 | 16.3 | 13.9 | 1.2 |
|  | comment | 14.8 | 16.0 | 13.3 | 1.2 |

Against the "+ blocks" column of 3.3, after an edit at the end:

| document | expected | measured |
| --- | ---: | ---: |
| `long.typ` | 92 to 56 | 97.0 to 56.6 |
| `longer.typ` | 507 to 313 | 503 to 282 |
| touying | 22 to 18 | 24.8 to 19.3 |
| handbook | 30 to 26 | 28.8 to 25.8 |
| deck | nothing | 15.2 and 15.3 |

No row misses. `longer.typ` gains more than the probe had (221 ms where
it had 194); the probe's tree was `main` of a week before, without the
accelerator of introspector reads and the native work of pull request 74,
and the difference was not looked into. Where blocks buy little, they are not what is left: `showcase.typ` (its
recompilation is the export of its images and its raw blocks, 24 ms to
20 ms), the projects (12 ms and under), the deck (paragraphs and
images), and an edit of a package's theme, after which every block has
other styles (the touying document 117 ms to 114 ms, the handbook 74 ms
both). After a comment the port still lays out the flow and exports
(`long.typ` 60 ms where upstream takes 14): that is slice 3's.

*Where the rest goes* after an edit at the end of `long.typ` (sampled as
above, shares of a recompilation): export 61 %; the layout of the
document 31 %, of which the document-level realization is 16 points (5
of them resolving the grids of the tables, which upstream repeats too)
and the flow 12, with the block level in it: its keys, its comparisons
and the one block that is laid out are 6; evaluation 5 %.

*What a first compilation and a one-shot `typst compile` pay.* Against
the base of the slice, the least of twelve runs each in turns
(instructions retired and cycles of `/usr/bin/time -l`):

| workload | instructions before | after | change | cycles before | after | change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.5 M | 64.5 M | -0.02 % | 24.5 M | 24.8 M | +1.32 % |
| `long.typ` to PDF | 3260.1 M | 3139.5 M | -3.70 % | 779.5 M | 757.5 M | -2.82 % |
| `longer.typ` to PDF | 15816.1 M | 15205.0 M | -3.86 % | 3812.5 M | 3695.7 M | -3.06 % |
| `query longer.typ heading` | 13372.8 M | 12746.9 M | -4.68 % | 3280.2 M | 3153.7 M | -3.86 % |
| `showcase.typ` to PDF | 3779.0 M | 3731.9 M | -1.25 % | 825.2 M | 818.0 M | -0.87 % |
| touying `theme-metropolis.typ` to PDF | 2597.5 M | 2564.2 M | -1.28 % | 680.0 M | 665.7 M | -2.10 % |
| ilm `bakers-handbook.typ` to PDF | 2279.6 M | 2270.4 M | -0.41 % | 547.6 M | 550.0 M | +0.42 % |
| the book of `tests/recompile/docs` to PDF | 1380.8 M | 1381.4 M | +0.04 % | 333.5 M | 336.5 M | +0.91 % |
| the blocks of `tests/recompile/docs` to PDF | 309.3 M | 308.9 M | -0.16 % | 89.2 M | 89.0 M | -0.29 % |
| 30 tables of 408 cells to PDF | 14016.8 M | 14492.1 M | +3.39 % | 3464.9 M | 3700.8 M | +6.81 % |

A first compilation gains where a document needs more than one
introspection iteration, since the blocks of the first are found by the
second (`long.typ` and `longer.typ` have three: 3.7 and 3.9 %), and pays
nothing that can be measured where blocks are few. It pays where a
document is all tables and converges in one iteration, the last row: a
key per table, which is the fingerprint of its children and of its grid
(what upstream hashes for the same key), an entry, and one walk over its
frames (`frame_cacheable`), without a hit to pay it back: 3.4 % of the
instructions, and 46 MB of the peak, since the entries keep their
arguments (deviation 3: the realized table with its grid) until the
process ends. The budget of 5.2, 1 % of a compilation from scratch, holds
for every document of the measurements and not for that one.

**Memory.** `scripts/watch_check.py --bench-memory`, `longer.typ`, the
resident set size of the watching process after the first compilation
and after 10, 50 and 200 edits, every edit a text that the session has
not had:

| edits | binary | first | after 10 | after 50 | after 200 | peak |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| at the end | before | 171 MB | 219 MB | 224 MB | 224 MB | 224 MB |
| at the end | after | 188 MB | 237 MB | 241 MB | 241 MB | 241 MB |
| at the end | upstream | 311 MB | 1963 MB | 2202 MB | 2255 MB | 2255 MB |
| every heading | before | 171 MB | 311 MB | 324 MB | 324 MB | 324 MB |
| every heading | after | 189 MB | 341 MB | 357 MB | 357 MB | 357 MB |
| every heading | upstream | 313 MB | 2163 MB | 2375 MB | 2417 MB | 2417 MB |
| every paragraph | before | 171 MB | 1024 MB | 1111 MB | 1111 MB | 1111 MB |
| every paragraph | after | 188 MB | 1294 MB | 1409 MB | 1409 MB | 1409 MB |
| every paragraph | upstream | 312 MB | 2984 MB | 3355 MB | 3421 MB | 3421 MB |

Every plateau is still one: what a session holds is what its last eleven
compilations used. The entries of blocks add 17 MB to a first
compilation of `longer.typ` (121 pages, 180 tables) and to a session
of edits at the end, 33 MB where
every heading changes, and 298 MB (27 %) where every edit changes the
size of the text, after which every block of the document is another
layout: eleven generations of all of them. What an entry of a block
keeps is what an entry of a paragraph keeps, the arguments (the realized
element, with its grid for a table: deviation 3), the reads and the
frames; the frames share their item arrays with the page that the block
went into until one of the two is written to, so they cost less than
they hold.


**Review.** One round by Codex (`gpt-6-astra`, reasoning effort high)
on the diff of the slice, asked for two blocks that the key takes for
one, a kept frame that a caller can write to, and an input of the block
layout that is neither in the key nor in the recorded reads (regions,
the locator, styles reached through the content, the engine's route),
and whether the mutations that nothing exposed are equivalent. The
verdict was "approve": no defect found for any of the three, by reading
(the grid types against upstream's fields; the encoding of the regions;
the callback sites of `layout/rules.mbt`; every consumer of the frames
through distribution, composition, page finalization and the exporters;
the process state that layout reads).

Taken up:

- *The route and the library are not equivalent mutants.* A host can
  tell: one block with a callback of its own, laid out from a root
  locator on routes of depth 70 and 71, whose callback checks the layout
  depth (the second must fail); and a callback that returns another
  frame under a library with another feature. Both are tests now
  (above); a document cannot do either.
- *Coverage of the grid test*: no variant for the start of a header's
  range alone, and the override flags varied on one side. Four grids
  more.

Agreed with and not changed:

- Two host callbacks of one kind that capture equal content and do
  different things have one key. That is the rule of deviation 21 (one
  function for equal content), older than this slice for fragments.
- A frame taken out of a group of an `items()` view and written to is
  the store's (above, "Mutable results"): the contract of `frame.mbt`.
- The copies of the store for blocks alone are equivalent mutants under
  the callers there are.
- The mutation of the styles removes them from the key and from the
  comparison together; with the hash alone removed the comparison still
  rejects the entry.

It ran nothing (its sandbox was read-only and the test executables it
found were older than the tree).

**For slice 3 and later.**

- The flow around the blocks and the document-level realization are
  what a recompilation of a document of text still does besides the
  export (28 % of `long.typ` after an edit at the end, and the same
  after a comment): page runs and the document.
- A block that keeps being found does not ask for the paragraphs inside
  it, which then get old and go after eleven evictions, as comemo's do
  under a memoized call that hits. An edit inside such a block lays out
  all of its paragraphs again.
- The comparison of arguments calls a NaN another argument (above).
- `frame_cacheable` walks the frames of every result, so the frames of a
  block inside a block inside a block are walked three times in a
  compilation that computes all three. Not visible in the documents
  here (0.3 % of the table document).
- The fingerprint of a grid writes every stroke of every cell as a value
  (a third of it).

### Slice 3: page runs and the document

`layout_page_run` and `layout_document_common` (and the bundle variant,
whose locator upstream tracks and the port puts in the key) through
`memoize`, keyed like upstream's `layout_page_run_impl` and
`layout_document_impl`. Pages and documents are copied when stored and
when handed out (5.4): `finalize_page` consumes the frames of a
`LayoutedPage` (`layout/pages_finalize.mbt`). Files:
`layout/pages_run.mbt`, `layout/pages.mbt`, `layout/document.mbt`.
Slices 2 and 3 do not depend on each other.

Expected ("+ runs, document"): nothing changed: `long.typ` 53 ms to 37 ms,
`longer.typ` 304 ms to 171 ms, the touying document 13 ms to 7 ms; a
bibliography entry that is not cited: the handbook 25 ms to 16 ms; after an
edit of a deck: 18 ms to 17 ms. Risk: low. What it does not buy: anything
after an edit of a document that is one page run.

#### Slice 3 as built

Page runs and the document are kept. A recompilation in which the content
of the document is what it was (a save without a change, a comment that
is edited) no longer lays anything out: `longer.typ` 462 ms to 178 ms,
the touying document 20.5 ms to 7.7 ms, and what is left of it is the
export. Slice 2 was built at the same time on another branch and is not
in these numbers.

**Upstream's functions and the port's keys.** `H` hashed, `T` tracked,
`M` tracked mutably (comemo records the calls and replays them).

| upstream | world | library | introspector | traced | sink | route | locator | the rest |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `layout_page_run_impl` (`typst-layout/src/pages/run.rs:78`) | T | H | T | T | M | T | T | `children: &[Pair]` H, `initial: StyleChain` H |
| `layout_document_impl` (`pages/mod.rs:55`) | T | H | T | T | M | T | none (`Locator::root()` inside) | `content` H, `styles` H |
| `layout_document_for_bundle_impl` (`pages/mod.rs:102`) | T | H | T | T | M | T | T | `content` H, `styles` H |
| the port, all three (`layout_page_run_impl` in `layout/pages_run.mbt`; `layout_document_impl`, `layout_document_for_bundle_impl` in `layout/pages.mbt`) | recorded reads, validated in the scope of the lookup | compared as an object | recorded reads, replayed; or the same introspector by its number | in the key | kept as a copy, replayed as copies | in the key, whole (deviation 1) | in the key, resolved (deviation 1) | in the key by fingerprint, and kept for the exact comparison (deviation 3) |

The key of a page run is the name of the function, the number of
children, each child's fingerprint and the hash of its style chain, the
hash of the initial styles, the resolved locator and the route; that of a
document the name, the content's fingerprint, the hash of the styles, the
route, and for the bundle variant the resolved locator. `memoize` adds the
traced span. The two document functions have one store and their names in
the key (upstream: a cache per function).

Both go through `memoize` (`library/memo.mbt`), so an entry has what every
entry of a `MemoStore` has: comemo's age, the evictor, four results per
key among those that no `evict` has seen, the end with its compilation if
its key holds a host closure, and the recording check. What is new is in
`library/memo_pages.mbt`: `PageMemo[T]` and `memoized_pages`, a store for
results that are not frames (the layout package's `Array[LayoutedPage]`
and `PagedDocument`), with the copy and the test for what may be kept
given by the caller, the exact comparison of a run's children
(`PagesInput`: content by `content_memo_equal`, style chains by
`chain_memo_equal`), and counters of calls that were found and computed
(`@layout.page_run_memo_stats`, `document_memo_stats`). An entry keeps the
children of a run in an array of its own: the view of the call is into
the array of the realization, which page collection writes to
(`migrate_unterminated_tags`; it does so before any run is laid out, so
this is a guard against a later change, not a repair).

**The introspection loop.** `compile_scoped` (`typst/lib.mbt`; upstream
`typst/src/lib.rs:151` and `:159`) lays the document out up to five
times, each time against the introspector of the document before, and
stops when the reads of a layout give the same answers on its own
document. A compilation of three iterations leaves three document
entries under one key, which differ in the introspector they were
computed with and in their reads. How a later compilation finds them:

- The first iteration asks with an empty introspector. All empty
  introspectors have the number zero (`Introspector::serial`), and the
  entry of an earlier first iteration was computed with one: found
  without a replay.
- A document that is found is handed out with the introspector it had
  (below, "Copies"): the same object, with the same number. So the
  second iteration asks with the introspector that the entry of the
  earlier second iteration was computed with, and that one is found by
  the number too. And so on: in a recompilation in which the content is
  what it was, no read of a document entry is replayed to find it.
- What the loop then validates is the reads of each document against
  that document's own introspector (the convergence check), which the
  compilation that laid the documents out validated too. That is where
  the accelerator comes in (below).
- After an edit the document is another key. Its page runs are asked
  for, in the first iteration with an empty introspector (found by the
  number) and in the later ones with the introspectors of the new
  documents: there the entries of the compilation before are validated
  by replaying their reads, and a run is found if what it read of the
  document is what it was (a slide of a deck whose page number and
  running header did not change).

Five documents under one key and four results per key: a document that
does not converge loses the entry of its first iteration to that of its
fifth. In a watching process the next compilation lays out the first
iteration again and finds the other four by their reads, after which all
five are there (the limit counts what no `evict` has seen); a process
that never evicts lays such a document out again every time
(`typst/pages_memo_wbtest.mbt`, "a document that is found says what its
layout said").

*How many reads, and what replaying them costs.* A document entry of
`longer.typ` records 760 distinct introspector reads in the first
iteration (against the empty introspector) and 1736 in each of the next
two; `long.typ` 157 and 353, the touying document 114 and 186, the
handbook 97, 186 and 200. Replaying them is cheap, because the queries
of an introspector are cached and the fingerprint of content is kept in
the content: the three convergence checks of a compilation of
`longer.typ` take 1.05 ms together when every read is replayed (a first
compilation), 1.13 ms in a recompilation that finds all three documents
with the accelerator as it was, and 0.25 ms with the table below. That
is 0.7 % of such a recompilation (162 ms, of which 158 ms are the export
and 3.5 ms everything else) and 0.2 % of one after an edit. Finding the
three entries themselves replays nothing (the numbers above) and takes
0.5 ms: the comparison of the arguments, which are the objects they
were, and the validation of the world reads.

**The accelerator of introspector reads** (`ReadAccelerator`,
`library/introspector.mbt`) was the answers of the introspector that was
asked last (step 5). Within a compilation that is enough: the lookups of
an iteration validate against one introspector, then the convergence
check against the next, which is the one the following iteration asks.
What it did not serve is the next compilation: the documents that are
found have the introspectors they had, and the answers that the
compilation before computed for them were gone. It is a table by the
number of the introspector now, with these bounds: an introspector that
was not asked since the `evict` before the last is dropped with its
answers (the introspector of a document that changed); of one that
stays, the answers that were not asked for since then are dropped too
(two generations: found by the review, below); at most sixteen
introspectors in a process that never evicts; and no table for the empty
introspectors, which all have the number zero and are asked the reads of
every later document (their answers are kept while the empty
introspector is the one that is asked, as before). comemo drops its
accelerator with every `evict` (`comemo/src/memoize.rs:100`), so this
keeps more than upstream does, of what cannot be stale: an introspector
answers the same for as long as it lives. What it buys is the 0.9 ms
above, a quarter of what a recompilation of `longer.typ` that finds
everything does besides exporting.

**Copies** (5.4, "Mutable results"). Share with copy-on-write where the
engine goes on with a result, copy the structure where a host gets it.

- *The pages of a run* (`copy_layouted_pages`): other `LayoutedPage`s
  with copy-on-write clones of the five frames (`Frame::clone`: the
  array of items is shared and both frames are marked), when the entry
  is stored and for every caller. `finalize_page` moves the frames of
  what it is handed into the frame of the page (`push_frame`: a group
  that holds the frame, or its items copied in), which no longer reaches
  the entry's. The fill, the numbering and the supplement are values.
- *What a document entry keeps* (`PagedDocument::kept`): another
  document with other pages, whose frames are copy-on-write clones,
  another info (`DocumentInfo::copy`: the authors and the keywords are
  arrays) and other format options (`DocumentFormatOptions::copy`). It
  shares its introspector, which is made once of the pages as they were
  laid out and whose answers are for reading
  (`PagedIntrospector::frame_link_targets` handed out its set; it hands
  out a copy now).
- *What a caller of `layout_document` gets*, computed or found
  (`PagedDocument::owned`): a document whose frames share no frame and
  no group with anything that is kept, at any depth
  (`Frame::deep_clone`, new). A copy-on-write clone is not enough for a
  holder that the engine does not know. It protects writes through the
  methods of the frame that was cloned; but the clone shares its groups,
  as objects, with what it was cloned from, `GroupItem` has public
  mutable fields and its frame has `Frame`'s methods, and the pages of a
  document are clones of the frames that the entries of the document,
  of its page runs, of paragraphs and of fragments keep. A host that
  takes a group out of `Frame::items` and sets its transform, or empties
  its frame, wrote to all of them (the review found it; it was true of
  the kept paragraphs since they were first kept, for any holder of a
  document). The deep copy makes new frames and groups and shares the
  other items, which are values: the glyphs of a text, the curve of a
  shape, an image, the content of a tag are not copied, here or anywhere
  else in the engine.

What the copies cost, for `longer.typ` (121 pages; timers around the
copies in a watching process, medians of fifteen recompilations):

| | per document | per recompilation (three iterations) |
| --- | ---: | ---: |
| the pages of the run, cloned (when stored, and when found) | 0.01 ms | 0.03 ms |
| a document, cloned (what an entry keeps) | 0.013 ms | 0.04 ms |
| a document with frames of its own (what a caller gets) | 0.6 ms | 1.7 to 2.0 ms |

That is 1.1 to 1.2 % of a recompilation in which everything is found and
0.15 % of a first compilation. Two thirds of it are for the documents of
the first two iterations, of which the loop uses the introspector and
nothing else; saving that needs a way to say that a document will not
leave the engine (a method of `Output`), which was not worth a change of
the trait.

Tests (`typst/pages_memo_wbtest.mbt`): a host writes to the frames of
every page (`push`, `translate`, `hide`, `set_size`), to the title, the
authors and the keywords, to the format options, and to every group at
every depth (transform, clip, label, the innermost frames emptied), of a
document that was computed and of one that was found; the next
compilation, the one after an edit of another page run, and the one
after that give the pages that a compilation from scratch gives.

**What a hit replays.** `memoize` does it for every store: the sink of
the call (warnings, delayed errors, the introspections that `analyze`
names in the warning of a document that does not converge, traced
values), as copies; the introspector reads, into the recorder of the
caller, which for a document is the constraint of the loop; the world
reads, which are validated in the scope at hand and noted for the calls
around (that is also what keeps the files of a found document among the
dependencies that `typst watch` watches); and for a closure call around
it, that the result is that of this depth of the route. For the document
there is one thing more, which is not replayed but kept: the introspector
of the document that is handed out, with its number, its page count and
its locations, is the one that the later iterations were computed with.

**Found on the way.**

- *A comment appended to a file can change the content.* Where the
  markup ended with a space it then ends with the space before the
  comment and the space after it, and spaces are content. So the first
  comment after another state of the file can lay the document out, and
  an edit of the comment's text alone finds it. What the first one costs
  depends on the file: in the test of this slice the page runs are found
  (the realization drops the spaces); in `longer.typ` the run is laid out
  too (429 ms, where the following take 176 ms and an edit at the end
  414 ms); in the touying document nothing changes (10.3 ms and 7.4 ms).
  Upstream's keys say the same, and its watch shows it: 97 ms for the
  first comment in `longer.typ`, 62 ms for the following, 114 ms for an
  edit at the end. The rows "comment" below are medians of five edits of
  which the first is of this kind.
- *A layout in which a function call failed read the file of the call.*
  Upstream's `Trace::trace` asks the tracked world for the range of the
  call (`typst-library/src/diag.rs:588`, `world.range(span)`, a read of the
  source), and the port reads the same (`world_range`). In the first
  iteration of many documents a `locate` or a query of something that
  an empty document does not have fails inside a function, the error is
  delayed and gone when a later iteration succeeds, and the entries of
  that iteration (the document, its page run) depend on the file: they
  are laid out again after every edit of it, also one that changes
  nothing they hold. As upstream.
- *What is beneath a result that is found gets old.* A document that is
  found asks for none of its page runs, paragraphs or closure calls, and
  what is not asked for in ten evictions is dropped. After eleven
  recompilations in a row in which the document was found, an edit is
  close to a first compilation: the touying document 149 ms (19 ms
  otherwise), `longer.typ` 1220 ms (427 ms). Upstream does the same, by
  the same rule: 111 ms (10 ms) and 522 ms (123 ms).
- *The locator of a run seldom decides.* The children of a run are
  realized content, which holds the locations of its elements, so two
  runs at two places have other children. The key's locator is what
  tells apart runs without children: empty pages one after the other,
  whose footers and headers get their locations from it.

**Memory.** The resident set size of the watching process
(`scripts/watch_check.py --bench-memory`), PDF output, after the first
compilation and after 10, 50 and 200 edits, every edit a text that the
session has not had. "Before" is `main` at `565eac6` (step 5's table,
measured again); upstream is the binary of `e58a63af`.

| document | edits | binary | first | after 10 | after 50 | after 200 | peak |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| longer | at the end | before | 171 MB | 219 MB | 224 MB | 224 MB | 224 MB |
| longer | at the end | after | 188 MB | 584 MB | 624 MB | 624 MB | 624 MB |
| longer | at the end | upstream | 313 MB | 1961 MB | 2179 MB | 2238 MB | 2238 MB |
| longer | every heading | before | 171 MB | 310 MB | 324 MB | 324 MB | 324 MB |
| longer | every heading | after | 188 MB | 654 MB | 701 MB | 701 MB | 701 MB |
| longer | every heading | upstream | 312 MB | 2163 MB | 2341 MB | 2410 MB | 2410 MB |
| longer | every paragraph | before | 171 MB | 1024 MB | 1112 MB | 1112 MB | 1112 MB |
| longer | every paragraph | after | 188 MB | 1339 MB | 1455 MB | 1455 MB | 1455 MB |
| longer | every paragraph | upstream | 312 MB | 2978 MB | 3368 MB | 3424 MB | 3424 MB |
| touying | at the end | before | 82 MB | 86 MB | 86 MB | 86 MB | 86 MB |
| touying | at the end | after | 83 MB | 95 MB | 97 MB | 97 MB | 97 MB |
| touying | in the middle | before | 82 MB | 86 MB | 86 MB | 86 MB | 86 MB |
| touying | in the middle | after | 83 MB | 93 MB | 96 MB | 96 MB | 96 MB |
| touying | the theme of the package | before | 82 MB | 151 MB | 159 MB | 159 MB | 159 MB |
| touying | the theme of the package | after | 83 MB | 165 MB | 174 MB | 174 MB | 174 MB |
| deck | at the end | before | 236 MB | 254 MB | 256 MB | 256 MB | 256 MB |
| deck | at the end | after | 233 MB | 258 MB | 259 MB | 260 MB | 260 MB |
| deck | every slide | before | 236 MB | 257 MB | 259 MB | 259 MB | 259 MB |
| deck | every slide | after | 233 MB | 262 MB | 263 MB | 263 MB | 263 MB |

A kept document holds every frame of its pages, and so does the entry of
a page run; a compilation of three iterations leaves three of each, and
an edit of a document that is one page run changes all six keys. With
ages up to ten that is the frames of eleven compilations. The first
compilation holds 17 MB more than before (188 MB for 171 MB), an edit at
the end of `longer.typ` leaves 39.6 MB where it left 4.8 MB (a new
module), and the plateaus are 624 MB, 701 MB and 1455 MB where step 5
had 224 MB, 324 MB and 1112 MB: 2.8, 2.2 and 1.3 times. Upstream holds
2238 MB, 2410 MB and 3424 MB in the same sessions; the port is at 28 %,
29 % and 42 % of that. A deck does not show it (its runs are small, and
most of them are found: 97 MB for 86 MB, and 260 MB for 256 MB with
images).

*Where it goes.* The same session with parts left out (fourteen edits at
the end; megabytes per edit at the plateau):

| | per edit |
| --- | ---: |
| before the slice | 4.8 |
| page runs and documents kept | 39.6 |
| the same, the entries of runs without their children | 34.5 |
| documents kept, page runs not | 33.0 |
| page runs kept, documents not | 33.3 |

So the children that a run entry keeps for the exact comparison are 5 MB
per edit (three realizations of the document), and the frames are 28 MB,
which the run and the document share (a document's pages are clones of
the run's): about 9 MB per iteration, for 121 pages. They are frames
that no other entry holds, so not those of paragraphs, which the layout
entries keep once and every page shares. What the flow builds anew in
every iteration and in every compilation is what no entry keeps: the
blocks (`longer.typ` has 180 tables and 180 equations) and the page
frames around them. How the 28 MB divide between the two was not
measured. The block level is slice 2: with it a page run that is laid
out again holds clones of kept block frames, and what an edit leaves
should come down towards the children and the page frames; that is to
be measured when the two slices are together. (It was, and this
paragraph's supposition was wrong: the frames are 2.6 MB of what an edit
leaves, and the rest is the realized content of each iteration, which
the children, the tags of the page frames and the document's
introspector reach. "Slices 2 and 3 together", "Memory".)

*A bound, proposed and not built.* The plateau more than doubles for
edits at the end, so here is what a smaller age for the entries of these
two stores gives (an entry goes when it was not found in `n` evictions,
where every other store has ten), measured with a build that has it:

| `longer.typ`, plateau | at the end | every heading |
| --- | ---: | ---: |
| step 5 | 224 MB | 324 MB |
| age 10 (as built) | 624 MB | 701 MB |
| age 2 | 314 MB | 409 MB |
| age 1 | 280 MB | 376 MB |

What it costs in hits. An entry of a page run is asked for only when the
document is not found, so every recompilation that finds the document
(a save without a change, a comment) makes the runs older: with age 1
one such recompilation, with age 2 two, and the next edit lays every run
out again. Measured, an edit at the end after such recompilations: the
touying document 22 to 24 ms where it takes 18 to 19.5 ms, the handbook
30 ms where it takes 26 ms (the blocks and paragraphs beneath the runs
are still found). And a document that goes back to a content it had (an
edit and its reverse where the spans come back, a toggled value) finds
its documents and runs for two compilations instead of ten.

What it costs in principle. It would be the first age that is not
comemo's, and section 8 of step 5 has the rule for a reason: an entry
that goes earlier than upstream's is computed where upstream's watch
finds it, and computing is not the same as finding where a kept call
beneath returns the module of an earlier evaluation (5.4). A document
that compares modules inside a layout, is found for more than `n`
compilations while an imported file changes in a comment, and is then
edited elsewhere, would show a comparison that upstream's watch does not
show at that step. No document of the stage does that, and the count of
pinned steps would not notice.

So it is not built. The port holds at most 42 % of what upstream holds
in these sessions; the frames that make the difference to step 5 are
probably the block level's to share; and the decision is
the owner's once that is measured. If it is taken, the place is the
evictor that a `PageMemo` registers (`library/memo.mbt`, `memoize`:
`register_evictor(max_age => store.evict(max_age))`), and its mutation is
a pinned sequence that upstream's watch must be recorded for.

**Mutation checks.** Each put in by hand (a script per mutation, applied to a
copy of the tree, never committed), on the default `recompile` stage of
the final tree (244 sequences) and on the unit tests of the slice: T is
`typst/pages_memo_wbtest.mbt` (12 tests), L `layout/pages_run_wbtest.mbt`,
A `library/read_accelerator_wbtest.mbt` (6 tests). The numbers in
brackets are those of 9.1.

| what was broken | failing sequences | first exposed at, and what else exposes it |
| --- | ---: | --- |
| page runs: the world reads of an entry are not validated [1 to 6, for this store] | 56 | `bench/tiny`, sweep, step 1 (the fonts); T, "a layout that failed inside a function read the file for its tracepoint" |
| documents: the same | 70 | `bench/tiny`, sweep, step 1; the same test |
| page runs: the introspector reads of an entry are not validated [11] | 35 | `project/pages`, sweep, step 1; `suite/introspection/counter.typ/counter-page` at step 0 (the first compilation differs from one without memoization: a later iteration takes the run of the first); T, all tests |
| documents: the same [11] | 132 | `bench/long`, sweep, step 0 (the document of the first iteration is taken for the second, and the compilation ends with it); T, all tests |
| page runs: the introspector reads of an entry that is found are not its caller's | 3 | `suite/introspection/counter.typ/counter-page`, sweep, step 2; T, 4 tests |
| documents: the same (the constraint of the loop stays empty, and the loop stops after the first iteration that finds its document) | 67 | `project/book`, sweep, step 19; the watch loop gives upstream's watch output at 13 of the 18 pinned steps; T, 7 tests |
| page runs and documents: the sink of an entry that is found is not replayed [14] | 15 | `suite/introspection/query.typ/query-running-header`, random sequence, step 6; `locate-missing-label`, sweep, step 1 (a delayed error is gone); T, "a document that is found says what its layout said" |
| page runs and documents: the library is not compared [12] | 0 | no sequence: the libraries of the stage differ in `sys.inputs`, which the main file is evaluated with, to other content and another key. T, "a document and a page run are those of their library" |
| page runs: the locator is not in the key | 2 | `project/pages`, the sweep and the random sequence, step 0 (its empty pages; none before the project had them: the children of a run hold their locations); T, "runs with the same children are told apart by where they are" |
| the document of a bundle: the locator is not in the key | 0 | no sequence, and the `bundle` stage passes (39 of 39: no bundle of the suite has two documents with the same content). T, "the documents of a bundle are told apart by where they are" |
| page runs: the styles of the children are neither in the key nor compared | 7 | `suite/introspection/counter.typ/counter-display-matching-numbering-full`, random sequence, step 4; `query-complex`, sweep, step 2 |
| page runs: the initial styles are neither in the key nor compared | 2 | `suite/scripting/import.typ/import-nested-item`, random sequence, step 1; `suite/loading/json.typ/json-decode-number`, sweep, step 2 |
| page runs: an entry hands out the pages it keeps | 0 | no sequence and no document: `finalize_page` moves the frames it is handed and does not write to them. L (a caller that writes) |
| documents: an entry keeps the document that it hands on (`kept` is the identity) | 0 | no sequence (the stage exports a held document again; it does not write to one). T, "what a caller writes to a document it was handed is not written to the kept one" |
| documents: what an entry keeps has the info it was made of; the format options | 0, 0 | the same test, for each |
| documents: a caller gets the frames and groups of the kept layouts (`owned` is the identity) | 0 | no sequence. T, "what a caller writes to a group inside a page it was handed is written to no kept layout" |
| documents: what an entry keeps has the page frames it was made of, not clones | 0 | nothing, and nothing can: since the caller gets frames of its own it never holds what the entry keeps. The clone is the cheap half of `PagedDocument::kept` being a document of its own, not what protects the entry |
| page runs and documents: every result may be kept (`cacheable` is always true) | 0 | nothing: `edsl` 51 of 51, `library/memo_identity_wbtest.mbt` 7 of 7. An entry whose key holds a host closure ends with its compilation, and a result that got one from an introspector read is taken for that introspector only; the test is the rule of every kept layout (`frame_cacheable`), kept here as there |
| the accelerator answers for any introspector | the runner aborts (exit status 134) | before the first sequence is done, as in step 5: a kept layout holds locations that the introspector at hand does not know. A, 5 tests; T, 7 tests |
| the accelerator has one answer per introspector, whatever the read | the runner aborts | the same; A, all tests; T, 4 tests |
| the accelerator: a new introspector starts with the older answers of the one asked before it | the runner aborts | the same; A, "answers stay for the compilation after the one that asked" |
| the accelerator: the answers of an introspector that stays are never dropped | 0 | A, "of an introspector that stays, the answers that are no longer asked for go" (growth, not a wrong answer) |
| the accelerator keeps a table for the empty introspectors too | 0 | A, "the answers of the empty introspectors are not a table" (growth, not a wrong answer) |

The count of pinned steps is 18 under every mutation that lets the stage
finish, but the one named. Of the failing sequences, two of the page
runs' reads, five of the documents' reads and five of the documents'
merge are among the three with packages and the five pinned ones.
Three rows are of copies that no document can reach and that unit tests
hold; two (`cacheable`, the clone in `kept`) are of guards that nothing
can reach, and are said to be that.

**The recording check** (`--check-reads`), with the page-level entries
among those that are computed a second time: `paged` 39 031 entries
(33 509 before the slice), `edsl` 83 019 (82 738), `recompile` 95 466
(80 787), `packages` 1 309 051 (1 307 462); no difference, and the
`recompile` stage accepts its 18 pinned steps under it.

**Soak.** `scripts/recompile_soak.py --minutes 20` on the tree with the
review's changes, cold references included: 127 documents, seeds 9100 to
9107, 21.3 minutes with 12 jobs: 1016 runs, 4920 sequences, 55 995
steps, 165 729 compilations, 3008 steps compiled again as the first
compilation of a new process; 0 failures, 0 aborts.

**Measured.** aarch64 macOS, native release, PDF output,
`--ignore-system-fonts`, `scripts/watch_check.py --bench`: per document
five watch sessions of every binary in turns, each a first compilation
and five edits of every kind; medians of the 25 recompilations and of the
five first compilations, in milliseconds. "Before" is `main` at
`565eac6` (step 5 as merged), upstream the binary of `e58a63af` with its
threads, the ratio that of the last two columns. The machine was not
quiet (the mutation checks of this slice were building beside it): the
least of a row is up to a tenth below its median.

| document | edit | before | after | upstream | ratio |
| --- | --- | ---: | ---: | ---: | ---: |
| `long.typ` | first compilation | 234 | 225 | 106 | 2.1 |
|  | end | 89.1 | 84.6 | 23.5 | 3.6 |
|  | middle | 97.5 | 94.9 | 27.8 | 3.4 |
|  | comment | 91.6 | 37.6 | 13.5 | 2.8 |
| `longer.typ` | first compilation | 1120 | 1100 | 506 | 2.2 |
|  | end | 436 | 414 | 114 | 3.6 |
|  | middle | 484 | 457 | 133 | 3.4 |
|  | comment | 462 | 178 | 62.6 | 2.8 |
| `showcase.typ` | first compilation | 232 | 227 | 156 | 1.5 |
|  | end | 23.1 | 21.7 | 7.2 | 3.0 |
|  | middle | 22.9 | 21.8 | 7.3 | 3.0 |
|  | imported | 23.9 | 23.7 | 8.5 | 2.8 |
|  | comment | 21.6 | 15.8 | 6.2 | 2.5 |
| touying | first compilation | 193 | 191 | 141 | 1.4 |
|  | end | 23.3 | 19.5 | 10.8 | 1.8 |
|  | middle | 24.5 | 19.7 | 11.7 | 1.7 |
|  | imported | 116 | 112 | 87.1 | 1.3 |
|  | comment | 20.5 | 7.7 | 3.5 | 2.2 |
| handbook | first compilation | 154 | 156 | 106 | 1.5 |
|  | end | 27.4 | 25.6 | 9.4 | 2.7 |
|  | middle | 28.1 | 26.7 | 9.7 | 2.8 |
|  | imported | 72.5 | 72.8 | 21.9 | 3.3 |
|  | comment | 28.0 | 17.0 | 5.1 | 3.3 |
| `book` | first compilation | 100 | 96.3 | 71.5 | 1.3 |
|  | end | 13.1 | 13.0 | 4.3 | 3.0 |
|  | middle | 15.6 | 15.0 | 5.1 | 2.9 |
|  | imported | 20.6 | 21.4 | 6.7 | 3.2 |
|  | comment | 12.5 | 10.7 | 2.9 | 3.7 |
| `chain` | first compilation | 5.1 | 5.2 | 3.8 | 1.4 |
|  | end | 3.1 | 3.2 | 1.3 | 2.5 |
|  | middle | 2.9 | 3.0 | 1.2 | 2.5 |
|  | imported | 2.9 | 2.5 | 0.9 | 2.8 |
|  | comment | 2.9 | 2.5 | 0.9 | 2.8 |
| `notes` | first compilation | 16.1 | 17.1 | 8.8 | 1.9 |
|  | end | 8.4 | 7.9 | 3.1 | 2.5 |
|  | middle | 8.5 | 7.7 | 3.0 | 2.6 |
|  | imported | 10.2 | 9.4 | 3.9 | 2.4 |
|  | comment | 8.2 | 7.0 | 2.7 | 2.6 |
| `linked` | first compilation | 3.3 | 3.3 | 3.1 | 1.1 |
|  | end | 2.5 | 2.4 | 1.2 | 2.0 |
|  | middle | 2.2 | 2.1 | 1.3 | 1.6 |
|  | comment | 2.1 | 1.7 | 0.9 | 1.9 |
| deck | first compilation | 574 | 571 | 82.8 | 6.9 |
|  | end | 18.2 | 18.5 | 15.8 | 1.2 |
|  | middle | 18.4 | 19.4 | 15.8 | 1.2 |
|  | comment | 18.3 | 17.4 | 15.9 | 1.1 |

The edits are those of step 5's table. "Comment" is a comment appended to
the main file, another text each time: the first of a session's five
follows another kind of edit and changes the content (above, "Found on
the way"), the other four change the comment alone, and the median is of
those.

Against the expectations of 3.3 ("+ runs, document"; the rows of that
column in which the page level decides):

| document | edit | expected | measured | before |
| --- | --- | ---: | ---: | ---: |
| `long.typ` | nothing on the pages changes | 37 | 37.6 | 91.6 |
| `longer.typ` | nothing on the pages changes | 171 | 178 | 462 |
| touying | nothing on the pages changes | 7 | 7.7 | 20.5 |
| handbook | nothing on the pages changes (3.3: a bibliography entry that is not cited, 16) | 16 | 17.0 | 28.0 |
| touying | end | 17 | 19.5 | 23.3 |
| touying | middle | 21 | 19.7 | 24.5 |

The rows in which nothing on the pages changes are where they were
expected, although the expectation had the block level beneath: a
document that is found asks for nothing beneath it, so that level is not
in these rows. The deck's rows after an edit were expected with the
block level too (18 ms to 17 ms was the page runs' part) and are 2 ms
above without it at the end and below in the middle: after an edit at
the end of the touying document 55 of 63 calls for a page run are found
and the 8 that are laid out take 0.6 ms together; the handbook finds 25
of 29. A document that is one page run lays that run out in every
iteration, as before (three computed, none found). Its rows are 3 to
5 % below "before" all the same (`long.typ` 89 ms to 85 ms after an edit
at the end, `longer.typ` 436 ms to 414 ms), and so are its first
compilations, where the slice only adds work (below): no entry explains
that, and it is within what the place of a binary in a round of
sessions does. The image deck does not change: its recompilation is its
export. `book` after a comment is 10.7 ms and not its export's 6 ms: the
document of its first iteration read the main file for a tracepoint
(above) and is laid out after every edit of it.

Against upstream the rows in which nothing changes went from 3.9 to 8.0
times (step 5) to 2.2 to 3.3 times for the bench and package documents,
which is where the ratios of the other rows are: what is left there is
the PDF writer's ratio.

*What a first compilation and a one-shot `typst compile` pay.* Against
`main` at `565eac6`, the least of twelve runs each in turns
(instructions retired and cycles of `/usr/bin/time -l`):

| workload | instructions before | after | change | cycles before | after | change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.6 M | 64.6 M | -0.00 % | 23.2 M | 23.4 M | +1.0 % |
| `long.typ` to PDF | 3261.3 M | 3272.4 M | +0.34 % | 777.3 M | 776.1 M | -0.2 % |
| `longer.typ` to PDF | 15819.1 M | 15876.2 M | +0.36 % | 3755.4 M | 3746.0 M | -0.3 % |
| `query longer.typ heading` | 13372.0 M | 13415.3 M | +0.32 % | 3227.7 M | 3240.2 M | +0.4 % |
| `showcase.typ` to PDF, embedded fonts | 3779.6 M | 3779.4 M | -0.01 % | 801.3 M | 797.9 M | -0.4 % |
| touying `theme-metropolis.typ` to PDF | 2599.5 M | 2589.4 M | -0.39 % | 688.9 M | 680.2 M | -1.3 % |
| ilm `bakers-handbook.typ` to PDF | 2280.4 M | 2283.4 M | +0.13 % | 560.7 M | 562.4 M | +0.3 % |
| the book of `tests/recompile/docs` to PDF | 1381.1 M | 1384.4 M | +0.24 % | 336.2 M | 339.5 M | +1.0 % |
| the pages of `tests/recompile/docs` to PDF | 309.0 M | 309.7 M | +0.22 % | 93.9 M | 92.5 M | -1.5 % |

The keys of the document and of the run are fingerprints of the content
and of the realized children, which the keys of the paragraphs then find
computed; besides that a compilation pays the test for what may be kept
(a walk over the frames of every page, twice per iteration), the stores
of three run entries and three document entries, and three deep copies
of the document's frames. The touying document gains: 16 of its 60 calls
for a page run are found within the compilation, in the later
iterations (the handbook: 4 of 29). The budget of 5.2 (1 % of a
compilation from scratch) holds with a third of it.

*What is left after a recompilation in which everything is found*, by
phase (timers of a throwaway build around the phases, in a watching
process; medians of fifteen recompilations; milliseconds). "The same
bytes" is the main file written again as it is; "a comment" is the text
of a comment at its end changed.

| | `longer.typ`, the same bytes | a comment | touying, the same bytes | a comment |
| --- | ---: | ---: | ---: | ---: |
| the recompilation (status line) | 162 | 176 | 7.5 | 7.9 |
| evaluation: the main module found, or evaluated with every closure call found | 0.24 | 12.2 | 1.70 | 2.06 |
| realization of the document | 0 | 0 | 0 | 0 |
| the key of the document (a fingerprint of the content) | 0.00 | 2.03 | 0.00 | 0.00 |
| finding the three document entries: the exact comparison of the content, the validation of world reads | 0.50 | 3.58 | 0.07 | 0.08 |
| the convergence checks (introspector reads, from the table) | 0.25 | 0.25 | 0.03 | 0.03 |
| copies: three documents with frames of their own | 1.95 | 1.73 | 0.21 | 0.22 |
| the rest of the compilation (the world's reset, scopes) | 0.5 | 0.3 | 0.1 | 0.1 |
| export (PDF) | 158 | 156 | 5.3 | 5.4 |

After a save without a change, 98 % of `longer.typ` and 71 % of the
touying document is the PDF writer; after a comment, 89 % and 68 %, and
the rest is the evaluation of the main file (its closure calls are
found, its content is built again) and the comparison of the content
that it gave with the content that the entry keeps (3.1 ms: the
fingerprints are equal, and deviation 3 compares them field by field
when the objects are not the same). For the touying document the
evaluation's 1.7 ms is the world: 32 files read and compared, as step 5
found. So what comes after this slice for these recompilations is not
memoization: it is the PDF writer (158 ms where upstream takes about 55
for the document), and for package documents a file store that does not
read a file whose modification time is what it was.

And after an edit at the end, for comparison (the same timers):
`longer.typ` 440 ms: evaluation 12, realization of the document 43 (three
iterations), the key of the run 9, the flow of the run 204 (three
iterations, the paragraphs found), storing the run 4, the introspectors of
the new documents 4, the document's key, lookup and copies 6, the
convergence checks 1, export 155. The touying document 19.9 ms:
evaluation 6.2, realization 2.9, the 63 lookups of page runs 2.5 (keys
1.2, validation and copies 1.3), the 8 runs that are laid out 0.6,
finalization 0.6, introspectors 0.8, the document 0.5, export 5.4.

**Review.** One round by Codex (`gpt-6-astra`, reasoning effort high,
read-only) on the diff of the first five commits (page runs, the
document, the accelerator's table, the tests, the project), asked for an
input of the page-run or document layout that is neither in the key nor
in the recorded reads, a kept page that a caller can write to, a hit
that fails to replay something that later iterations or exporters depend
on, unbounded growth, a wrong answer of the accelerator's table, and any
change of a compilation from scratch. The verdict was "request changes",
with three findings and no stale result. It names what it looked at and
found sound: the inputs (children and their styles, initial styles,
content, resolved locators, routes, traced spans, the library, the
recorded world and introspector reads), the position of a run (the
physical number, the parity pages, two-sided margins, pending tags and
the manual page counter are the finalization's; floats, footnotes,
columns and line numbers of the root flow are made per call), the replay
(reads into the enclosing recorder, world reads validated and handed on,
warnings, delayed errors, introspections, traced values), the copies of
the info and the format options, the answers of the accelerator
(numbers, the empty introspectors, nested validation and eviction), the
lifecycle of the two stores, and the paths of a compilation from scratch
and with memoization off.

Fixed, all three:

- *A document that is handed out shares groups with what is kept*
  (above, "Copies"): `Frame::deep_clone`, `PagedDocument::owned`, and the
  test that writes to every group at every depth.
- *The answers of an introspector that stays are never dropped*: two
  generations (above, the accelerator; `library/read_accelerator_wbtest.
  mbt`, "of an introspector that stays, the answers that are no longer
  asked for go"). Its scenario is a document whose first iteration is
  found in every compilation while a later iteration changes (a file
  that only a later iteration reads): the introspector of that first
  document is asked new reads forever.
- *The same document's introspector caches every query it is asked*
  (`ElementIntrospector.queries`, upstream's `QueryCache`, which has no
  bound either; it did not matter while no document lived longer than
  its compilation or its host): the cache is emptied when it holds
  65 536 results.

Not changed, from the first finding: what the items of a frame hold
besides frames is shared between what is kept and what is handed out
(the glyphs of a text, the items of a curve, the stops of a gradient, the
frame of a tiling, the pieces of a numbering pattern), and some of it is
an array with public access. Copying it would copy every glyph of a
document for every caller. It is the engine's contract for values, as
for content: nothing writes to them, and nothing in the repository does
(a search for writes to the fields of a group outside of
`library/frame.mbt` finds the decoder of the runner's replay stage and
tests, which build their own frames, and one for writes to the glyphs of
a text finds the shapers, which build theirs).

**HTML and the bundle** are not built (section 4; "not scheduled").
What they would take, now that the store is generic:

- `html_document_impl` and `html_document_for_bundle_impl`
  (`typst-html/src/document.rs:46` and `:101`) have the signatures of the
  paged functions. They are `memoized_pages` with an `HtmlDocument`:
  the key as above; a copy of the document, which is a tree of
  `HtmlElement`s that are written to after they are made (the anchors of
  linked elements are assigned in `html_document`, inside the memoized
  function upstream), so the copy is of the tree, with the frames in it
  cloned; the introspector shared; and the test for what may be kept
  over the frames and the content in the tree.
- `html_block_fragment_impl` (`typst-html/src/fragment.rs:42`) is
  `layout_fragment_impl` with other results: a `PageMemo[Array[HtmlNode]]`
  with `whitespace` in the key.
- `bundle_impl` (`typst-bundle/src/lib.rs:151`) returns a bundle of
  documents and assets; its documents are those of
  `layout_document_for_bundle` and `html_document_for_bundle`, of which
  the first is kept since this slice. A kept bundle is a copy of each of
  them and a shared bundle introspector. The four `export_*` functions
  of `typst-bundle/src/export.rs` are memoized on the document and the
  options with the link resolver tracked: results by content
  (`library/memo_content.mbt`) once a document has a fingerprint, which
  it has (`Fingerprint for Page`).
- None of the measured documents is HTML or a bundle, so none of it was
  measured.

**For what comes after.**

- After a recompilation in which everything is found, what is left is
  the export: 98 % of `longer.typ` (158 of 162 ms) and 71 % of the touying
  document (5.3 of 7.5 ms), and the table above for the rest. The PDF
  writer takes three times upstream's time for the same pages.
- After an edit, the document-level realization, the flow of the page
  run around the kept paragraphs and the export are what is left;
  slice 2 is for the flow. The document level adds, per iteration of
  `longer.typ`, 0.7 ms for the key of the document, 3 ms for the key of
  the run (the fingerprints of its children, which the paragraphs' keys
  then find computed), 1.2 ms for the exact comparison and the test of
  what may be kept, and 1.5 ms for the introspector of the new document.
- The memory of a session was supposed here to be dominated by the
  frames of blocks that no entry keeps and every iteration lays out
  again (above), to be measured again when slice 2 is merged, before
  deciding on a smaller age. It was measured, and it is the realized
  content of each iteration, not the frames ("Slices 2 and 3 together",
  "Memory").
- A document entry is only as good as the content is stable: every edit
  of the main file that changes a span changes the key. What would find
  more is below the document (the block level) or beside it (page runs,
  for documents that are made of many).

#### Slices 2 and 3 together

The two slices were built on two branches from one base (`565eac6`) and
measured alone, each in its note above. This is the tree that has both:
the block level merged into the branch of the page level. What each note
says of its own slice holds; what is here is what changes when the three
levels (blocks, page runs, the document) are in one tree.

**What interacts.** A result that is found asks for nothing beneath it,
and a result that is laid out finds what is beneath it. So:

- A document that is found asks for no page run, and a page run that is
  found asks for no block. Six tests of slice 2 expected a block to be
  asked for by a compilation that now finds the document or the run
  around it; they lay the run out again where they meant "the blocks are
  found" (a rectangle more at the end), and say that nothing is asked
  where they compiled the same text twice.
- A page run that is laid out again finds its blocks, and their reads
  are not made. They must be reads of the run's entry and of the
  document: `memoize` merges the reads of an entry that is found into
  the recorder of its caller, at every level. The test
  (`typst/layers_memo_wbtest.mbt`, "the reads of a block that is found
  are those of the run and of the document around it"): a block reads
  the final value of a counter; the rectangle beside it changes, so the
  run is laid out and the block found; then another run steps the
  counter once more, and the run of the block, whose children are what
  they were, is rejected by the read that the block made two
  compilations ago. With the reads of a found block not merged
  (mutation below) the page shows the old value.
- All three found: a block that warns, in a run, in a document. Whichever
  level is found, the warning is reported once, as from scratch, and
  the counters of the three stores say that nothing beneath the level
  that was found was asked ("a block found inside a run found inside a
  document found says what a compilation from scratch says").
- The frames. Slice 2's review noted that a frame taken out of a group
  of an `items()` view and written to is the store's object. For a
  paged document that is closed: what `layout_document` returns has
  frames and groups of its own at every depth (`Frame::deep_clone`),
  also where they came from kept blocks, and the test writes to every
  group of a document and then lays the run out again of the kept
  blocks ("what a caller writes to the groups of a document is written
  to no kept block"). What else a host can reach:
  - the frame of an `html.frame` element in an HTML document, which is
    the clone of a kept fragment: a deep copy since this merge
    (`html/convert.mbt`; the last test of that file fails without it);
  - the documents of a bundle: the paged ones are those of
    `layout_document_for_bundle`, the HTML ones have the frames above;
  - `@layout.layout_fragment`, `layout_frame` and the other layout
    functions of the engine, called by a host directly: they return
    clones, as the engine needs them. A host that calls them and writes
    to a group calls `deep_clone` first; nothing in the repository does
    (`doc` compiles and reads);
  - what an item holds besides frames (glyphs, curves, the content of
    tags) is shared everywhere, as before: items are values.

**The stage.** 128 documents (slice 2's project `blocks` and slice 3's
`pages`), 246 sequences (238, 3 with packages, 5 pinned), 1489 steps,
4445 compilations; none fails, and the watch loop gives upstream's watch
output at the 18 pinned steps.

**Mutation checks**, all of both slices again on the merged tree (75
mutations: a script per mutation in four copies of the tree, never
committed), with one more for the two levels together.
`tests/recompile/README.md` has the tables. In short, against each
slice alone (failing sequences of the default stage; alone of 244,
together of 246):

| what was broken | alone | together |
| --- | ---: | ---: |
| blocks: world reads not validated | 47 | 47 |
| blocks: introspector reads not validated | 42 | 42 |
| blocks: the reads of an entry that is found are not its caller's (new) | | 4 |
| blocks: the locator, the regions of `layout_multi_impl`, the region of `layout_single_impl`, the backlog and `last` not in the key | 2, 10, 14, 2 | 2, 10, 16, 2 |
| blocks: the styles neither in the key nor compared; the sink not replayed | 17, 2 | 18, 2 |
| blocks: the route not in the key; the library not compared; the two copies | 0 | 0 (the same tests) |
| `memoize` keeps what it returns; hands out what it keeps | 40, 26 | 33, 18 |
| the grid comparison: as it was, 29 clauses left out one by one, 3 looser, 2 for callbacks | unit tests | the same unit tests, every one |
| page runs: world reads; introspector reads not validated | 56, 35 | 61, 39 |
| documents: the same | 70, 132 | 73, 134 |
| page runs: reads of a found entry not the caller's; documents: the same | 3, 67 | 3, 70 |
| page level: the sink not replayed | 15 | 17 |
| page runs: the locator; the children's styles; the initial styles | 2, 7, 2 | 2, 7, 3 |
| page level: the library; the bundle's locator; the copies (five); the deep copy; `cacheable` | 0 | 0 (the same tests; the frame of an HTML document: one test more) |
| the accelerator: three that give a wrong answer | the runner aborts | the runner aborts |

No mutation that a sequence saw alone is hidden by the other slice: the
counts are what they were or higher (the documents of the other slice's
project), but for the two copies of `memoize`, which fewer sequences
see (33 and 18 for 40 and 26) because a page run that is found hands on
frames that `finalize_page` does not write to and asks for no block. The
count of pinned steps is 18 under every mutation that lets the stage
finish but two of the documents' (11 with their reads not validated, 13
with their reads not merged).

**Gates on the merged tree.** `moon test --target native -j16`: 6197
tests, none failing. `moon check` on native, wasm-gc and wasm: the five
known warnings. Every stage of `scripts/ci/stages.py` (locally all but
the two that fail on this machine without the change: one stale golden
of `pdf-semantic`, short inputs of `wasm-validate`). The recording check:
`paged` 51 339 entries, `edsl` 122 740, `recompile` 131 678, `packages`
1 360 939; no entry differs, 18 pinned steps under it.
`scripts/tracked_world_check.py`: nothing. `scripts/watch_check.py`: 14
scenarios pass on native. The EDSL conversion sweep: 4549 cases pass,
none fails. The soak: 128 documents, seeds 9300 to 9311, 21.9 minutes
with 8 jobs: 1536 runs, 7440 sequences, 84 712 steps, 250 752
compilations, 4548 cold references; 0 failures, 0 aborts.

**Measured.** As in the notes above (five watch sessions per binary and
document, medians of 25 recompilations, milliseconds). "Step 5" is
`main` at `565eac6`; "blocks" and "pages" are the two slices alone, from
their own notes (other sessions on the same machine: compare them with
their own "before" there, not with these columns to the millisecond).

| document | edit | step 5 | blocks | pages | both | upstream | both / upstream |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `long.typ` | first compilation | 235 | 234 | 225 | 233 | 107 | 2.2 |
|  | end | 91.1 | 56.6 | 84.6 | 55.7 | 24.1 | 2.3 |
|  | middle | 103 | 67.7 | 94.9 | 64.1 | 28.0 | 2.3 |
|  | comment | 96.5 | 59.9 | 37.6 | 41.5 | 13.9 | 3.0 |
| `longer.typ` | first compilation | 1180 | 1130 | 1100 | 1090 | 523 | 2.1 |
|  | end | 485 | 282 | 414 | 278 | 127 | 2.2 |
|  | middle | 544 | 335 | 457 | 335 | 144 | 2.3 |
|  | comment | 560 | 307 | 178 | 201 | 65.2 | 3.1 |
| `showcase.typ` | first compilation | 239 | 239 | 227 | 234 | 165 | 1.4 |
|  | end | 24.1 | 20.4 | 21.7 | 20.0 | 8.3 | 2.4 |
|  | middle | 25.2 | 20.3 | 21.8 | 20.5 | 8.4 | 2.4 |
|  | imported | 26.8 | 22.3 | 23.7 | 23.3 | 9.7 | 2.4 |
|  | comment | 25.5 | 20.2 | 15.8 | 17.9 | 6.8 | 2.6 |
| touying | first compilation | 191 | 195 | 191 | 192 | 145 | 1.3 |
|  | end | 24.8 | 19.3 | 19.5 | 18.8 | 10.8 | 1.7 |
|  | middle | 25.0 | 20.5 | 19.7 | 19.6 | 11.9 | 1.6 |
|  | imported | 113 | 114 | 112 | 112 | 86.1 | 1.3 |
|  | comment | 21.1 | 14.6 | 7.7 | 7.5 | 3.5 | 2.1 |
| handbook | first compilation | 158 | 156 | 156 | 159 | 104 | 1.5 |
|  | end | 27.4 | 25.8 | 25.6 | 25.5 | 9.7 | 2.6 |
|  | middle | 27.6 | 25.9 | 26.7 | 25.0 | 9.7 | 2.6 |
|  | imported | 73.8 | 73.7 | 72.8 | 73.8 | 22.9 | 3.2 |
|  | comment | 26.8 | 25.8 | 17.0 | 16.8 | 5.3 | 3.2 |
| `book` | first compilation | 93.2 | 93.6 | 96.3 | 93.7 | 68.8 | 1.4 |
|  | end | 11.1 | 11.5 | 13.0 | 10.8 | 4.3 | 2.5 |
|  | middle | 11.4 | 11.3 | 15.0 | 11.1 | 4.6 | 2.4 |
|  | imported | 15.0 | 15.8 | 21.4 | 15.0 | 6.5 | 2.3 |
|  | comment | 11.2 | 11.6 | 10.7 | 7.5 | 2.5 | 3.0 |
| `chain` | first compilation | 5.0 | 4.9 | 5.2 | 5.1 | 3.8 | 1.3 |
|  | end | 2.9 | 2.9 | 3.2 | 2.9 | 1.1 | 2.6 |
|  | middle | 2.6 | 2.8 | 3.0 | 2.8 | 1.1 | 2.5 |
|  | imported | 2.6 | 2.6 | 2.5 | 2.2 | 0.8 | 2.8 |
|  | comment | 2.5 | 2.5 | 2.5 | 2.3 | 0.8 | 2.9 |
| `notes` | first compilation | 16.5 | 15.6 | 17.1 | 16.4 | 8.5 | 1.9 |
|  | end | 7.7 | 6.9 | 7.9 | 6.8 | 3.1 | 2.2 |
|  | middle | 8.1 | 7.3 | 7.7 | 6.9 | 2.8 | 2.5 |
|  | imported | 9.5 | 9.0 | 9.4 | 8.8 | 3.8 | 2.3 |
|  | comment | 7.8 | 7.0 | 7.0 | 6.3 | 2.5 | 2.5 |
| `linked` | first compilation | 3.2 | 3.2 | 3.3 | 3.1 | 3.0 | 1.0 |
|  | end | 2.2 | 2.4 | 2.4 | 2.1 | 1.2 | 1.8 |
|  | middle | 1.9 | 2.1 | 2.1 | 1.9 | 1.2 | 1.6 |
|  | comment | 1.7 | 2.0 | 1.7 | 1.6 | 0.9 | 1.8 |
| deck | first compilation | 558 | 555 | 571 | 558 | 77.7 | 7.2 |
|  | end | 16.1 | 15.3 | 18.5 | 15.4 | 14.5 | 1.1 |
|  | middle | 16.1 | 16.3 | 19.4 | 15.5 | 14.7 | 1.1 |
|  | comment | 16.8 | 16.0 | 17.4 | 14.3 | 13.1 | 1.1 |

(Measured in two halves. The first four documents with other builds
running beside them, as every table of this document so far. The other
six were first measured on the machine at rest and came out two to
three times slower in their short recompilations for every binary,
upstream's too (a process that wakes for a few milliseconds on an idle
machine is, it seems, not given a fast core at once). They were measured
again with two busy processes beside them, which is the state of the
earlier tables, and those are the rows above.)

The two slices add up where they are about different recompilations, and
the better one decides where they are about the same:

- *After an edit* (end, middle) the block level decides, and the page
  level adds little to it: `long.typ` 91 ms to 56 ms (blocks alone 57,
  pages alone 85), `longer.typ` 485 ms to 278 ms (282, 414), the touying
  document 24.8 ms to 18.8 ms (19.3, 19.5: either level finds what the
  edit left alone, and both do not find it twice).
- *After a comment*, where nothing on the pages changes, the page level
  decides: `long.typ` 97 ms to 42 ms (blocks alone 60), `longer.typ`
  560 ms to 201 ms (307), the touying document 21.1 ms to 7.5 ms (14.6),
  the handbook 26.8 ms to 16.8 ms (25.8). `book` gains from having both:
  11.2 ms to 7.5 ms, where either alone left it at 11 (the document of
  its first iteration is laid out after every edit of the main file, for
  the tracepoint; with blocks kept that layout finds its blocks).
- *An edit of an imported file that reaches every page* (the theme of the
  touying deck, the header of the handbook) is what it was, with either
  and with both: every layout has other styles.
- *A first compilation* is within the spread of step 5's in every row.

Against upstream, for the bench and package documents (`long.typ`,
`longer.typ`, `showcase.typ`, the touying document, the handbook), the
merged tree is at 1.7 to 2.6 times after an edit at the end and 2.1 to
3.2 times after a comment, where step 5 had 2.0 to 3.9 and 3.9 to 8.0.
That is near the ratios of the first compilations (1.3 to 2.2): what is
left is what both programs do in every recompilation, the export and
the document-level realization (below).

*What a first compilation and a one-shot `typst compile` pay*
(instructions retired, the least of twelve runs each in turns; "blocks"
is the merged tree with the page level switched off):

| workload | step 5 | blocks | merged | merged against step 5 |
| --- | ---: | ---: | ---: | ---: |
| `tiny.typ` to PDF | 64.7 M | 64.8 M | 64.8 M | +0.20 % |
| `long.typ` to PDF | 3261.8 M | 3140.7 M | 3145.9 M | -3.55 % |
| `longer.typ` to PDF | 15819.1 M | 15200.5 M | 15231.9 M | -3.71 % |
| `query longer.typ heading` | 13373.3 M | 12749.8 M | 12768.9 M | -4.52 % |
| `showcase.typ` to PDF | 3784.0 M | 3734.1 M | 3735.2 M | -1.29 % |
| touying `theme-metropolis.typ` to PDF | 2597.1 M | 2563.7 M | 2571.4 M | -0.99 % |
| ilm `bakers-handbook.typ` to PDF | 2279.5 M | 2270.9 M | 2272.8 M | -0.29 % |
| the book of `tests/recompile/docs` to PDF | 1380.7 M | 1380.7 M | 1380.8 M | +0.01 % |
| the pages of `tests/recompile/docs` to PDF | 308.8 M | 308.4 M | 310.0 M | +0.39 % |
| the blocks of `tests/recompile/docs` to PDF | 309.0 M | 307.6 M | 309.3 M | +0.10 % |
| 30 tables of 408 cells to PDF | 11957.2 M | 12427.0 M | 12440.1 M | +4.04 % |

The page level adds 0.1 to 0.5 % to what the block level gives or takes
(`long.typ` -3.71 % with blocks alone, -3.55 % with both), within its
budget by itself. The last row is slice 2's stress document as its note
describes it, made again (30 tables of 8 columns and 51 rows, 39 pages,
one iteration, 36 828 block lookups of which 38 are found): +3.9 % with
blocks alone and +4.0 % with both. That row is over the budget of 5.2
for the reason that slice 2's note gives, and the page level is 0.1 of
it.

**Memory.** `scripts/watch_check.py --bench-memory`, resident set size
after 200 edits (the plateau; megabytes):

| document | edits | step 5 | blocks | pages | merged | upstream |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `longer.typ` | first compilation | 171 | 188 | 188 | 199 | 313 |
| | at the end | 224 | 241 | 624 | 492 | 2217 |
| | every heading | 324 | 357 | 701 | 581 | 2437 |
| | every paragraph | 1112 | 1409 | 1455 | 1578 | 3412 |
| touying | at the end | 86 | | 97 | 96 | |
| | in the middle | 86 | | 96 | 95 | |
| | the theme of the package | 159 | | 174 | 181 | |
| deck | at the end | 256 | | 260 | 256 | |
| | every slide | 259 | | 263 | 263 | |

(An empty cell was not measured.)

*Does the block level bring the page level's plateau down?* Partly: for
edits at the end 624 MB to 492 MB, for edits of every heading 701 MB to
581 MB. Not to slice 2's 241 MB, and the note of slice 3 was wrong about
why. It supposed that the 28 MB of frames per edit were frames of
blocks that every iteration lays out anew. The frames were the smaller
part. Taken apart on the merged tree (the same session with parts of
the entries left out; megabytes that an edit at the end leaves at the
plateau, three iterations):

| | per edit |
| --- | ---: |
| the page level off (slice 2 alone): the module of the main file | 4.7 |
| run entries with neither frames nor children: their reads, sinks, keys | 5.0 |
| run entries with frames and without children | 15.3 |
| run entries as they are (no document kept) | 20.4 |
| document entries without frames: the introspector, the info | 16.5 |
| document entries as they are (no run kept) | 20.2 |
| both, with no frames in either | 24.0 |
| both as they are | 26.6 |

So an edit leaves 21.9 MB in the two page-level stores, of which the run
entries alone would hold 15.7 and the document entries alone 15.5: they
share 9.3. The frames themselves are 2.6 MB (the last two rows); the
block level did take the rest of them (slice 3 alone: 28). What the
entries hold is the *realized content* of each iteration, three times
per compilation: the document-level realization makes every element of
the document anew (the located copy of each paragraph, heading and
table, a table with its resolved grid), and each iteration's is reached
from three places that are kept: the children of the run (deviation 3:
the arguments are kept for the exact comparison; 5.1 MB that nothing
else reaches), the tags in the page frames (10.3 MB with the frames,
for a run entry without its children), and the elements of the
document's introspector (11.8 MB with its maps and its cached queries,
for a document entry without its frames). A block that is found keeps
the element it was laid out for; the element that the next realization
makes for the same block is another object, held by the run around it.
The sinks are not it (1738 introspections per layout), nor the reads.

*Per store, at the plateau of edits at the end* (entries counted by a
throwaway build after the fourteenth edit; bytes from the table above
times eleven compilations, so an estimate):

| store | entries | estimate |
| --- | ---: | ---: |
| module evaluations | 11 | 52 MB |
| page runs | 33 | 173 MB alone |
| documents | 33 | 170 MB alone; 241 MB with the runs (102 MB shared) |
| layouts: paragraphs, fragments, blocks | 371, 954, 1721 | within the 199 MB of the first compilation, which had 360, 24 845 and 12 988 |
| closure calls | 2700 | as in step 5 |

(The layouts shrink because of what both notes say: what is beneath a
block that is found is not asked for and goes after eleven evictions.
The resident set does not shrink with them.)

*The numbers for a decision on a smaller age.* Not built: an age that is
not comemo's is the owner's decision (slice 3's note has what it costs
in principle). On the merged tree, an age of `n` evictions for the
entries of page runs and documents and ten for everything else:

| `longer.typ`, plateau (MB) | at the end | every heading | every paragraph |
| --- | ---: | ---: | ---: |
| step 5 | 224 | 324 | 1112 |
| blocks alone | 241 | 357 | 1409 |
| merged, age 10 (as built) | 492 | 581 | 1578 |
| merged, age 2 | 301 | 409 | 1448 |
| merged, age 1 | 279 | 390 | 1433 |
| upstream | 2217 | 2437 | 3412 |

It would save 191 to 213 MB of 492 for edits at the end, 172 to 191 of
581 for edits of every heading, and 130 to 145 of 1578 where every
paragraph changes (there the layouts of eleven generations are most of
it, at any age of the page level). What it costs in hits on the merged
tree is less than for slice 3 alone, because a run that is laid out
again finds its blocks. An edit at the end after one, two and three
recompilations that found the document: the touying document 18.5, 19.2
and 20.1 ms with age 1 where it takes 18.6, 17.9 and 17.5 ms as built
(slice 3 alone: 22 to 24 for 18 to 19.5), the handbook 25.4 to 26.7 ms
for 25.2 to 26.2. (After twelve such recompilations everything beneath
the document is gone at any age of the page level, as in upstream: the
touying document 152 ms, the handbook 80 ms, `longer.typ` 1130 ms.) So
the cost in time is one or two milliseconds of an edit that follows a
save without a change; what remains is the cost in principle, an age
that is not comemo's. The merged tree at age ten holds 22 %, 24 % and
46 % of upstream's resident set in these sessions.

Two things would bring the plateau down without touching an age, and
neither is built: not keeping the children of a run (59 MB of the 492;
it is deviation 3 for one store, and comemo keeps no argument), and
realizing to the elements that the kept blocks hold (so that an
iteration makes no second copy of what is found), which is a change of
realization, not of a store.

**What is left**, by phase, with both slices in (timers of a throwaway
build in a watching process, medians of fifteen recompilations,
milliseconds).

*After a recompilation in which everything is found* ("the same bytes":
the main file written again as it is; "a comment": the text of a comment
at its end changed):

| | `longer.typ`, the same bytes | a comment | touying, the same bytes | a comment |
| --- | ---: | ---: | ---: | ---: |
| the recompilation (status line) | 164 | 180 | 7.6 | 7.5 |
| evaluation: the main module found, or evaluated with every closure call found | 0.23 | 12.5 | 1.73 | 2.12 |
| realization of the document, page runs, blocks | 0 | 0 | 0 | 0 |
| the key of the document | 0.01 | 1.98 | 0.00 | 0.00 |
| finding the three document entries (the exact comparison of the content, the world reads) | 0.58 | 3.57 | 0.07 | 0.07 |
| the convergence checks | 0.26 | 0.24 | 0.03 | 0.03 |
| three documents with frames of their own | 2.35 | 1.58 | 0.18 | 0.19 |
| the rest of the compilation | 0.4 | 0.5 | 0.1 | 0.0 |
| export (PDF) | 156 | 158 | 5.1 | 5.0 |

Nothing changed here with the block level: what is found at the top asks
for nothing beneath. 95 % of `longer.typ` and 67 % of the touying
document is the PDF writer after a save without a change; after a
comment 88 % and 67 %, and the rest is the evaluation of the main file
and the comparison of its content.

*After an edit at the end*, where the document and its page run are laid
out again and what is beneath them is found:

| | `long.typ` | `longer.typ` | touying | handbook |
| --- | ---: | ---: | ---: | ---: |
| the recompilation (status line) | 53.8 | 265 | 18.1 | 25.5 |
| evaluation | 2.70 | 12.3 | 6.19 | 1.40 |
| the key of the document, finding nothing | 0.73 | 4.42 | 0.26 | 0.23 |
| realization of the document (three iterations) | 8.21 | 41.4 | 2.63 | 4.79 |
| the keys of the page runs | 1.73 | 8.81 | 1.18 | 0.29 |
| page runs: found, laid out | 0, 3 | 0, 3 | 61, 2 | 26, 3 |
| the flow of the runs that are laid out | 4.67 | 26.3 | 0.17 | 1.01 |
| blocks asked for in it, laid out | 473, 0 | 2343, 0 | 0, 0 | 6, 0 |
| storing and finding the runs (comparison, the test of the frames, validation) | 0.48 | 3.47 | 0.82 | 1.96 |
| finalizing the pages | 0.20 | 1.44 | 0.48 | 0.54 |
| the introspectors of the new documents | 0.78 | 4.65 | 0.62 | 0.36 |
| three documents with frames of their own | 0.14 | 0.84 | 0.10 | 0.06 |
| the convergence checks | 0.15 | 0.93 | 0.19 | 0.13 |
| export (PDF) | 33.2 | 156 | 4.98 | 14.5 |

(A paragraph that is not in a block is asked for by the flow and found;
the blocks of `long.typ` and `longer.typ` are their tables, equations
and the cells in them, each found at the top and not asked beneath.)
With both levels, the flow of `longer.typ` is 26 ms where the page
level alone had 204 ms and step 5 more; what a recompilation after an
edit does now is, in this order: the export (62 % of `long.typ`, 59 %
of `longer.typ`, 28 % of the touying document, 57 % of the handbook),
the realization of the document (15 %, 16 %, 15 %, 19 %), evaluation
(5 %, 5 %, 34 %, 5 %), and then the keys of the page level (the
fingerprints of the content and of the realized children: 4 % of
`longer.typ`), the flow, and the introspectors. Evaluation and layout
together, the `G` of 9.2 against upstream's phases of 3.4: `long.typ`
20.0 ms for 12.5, 1.6; `longer.typ` 105 ms for 63.5, 1.7; the handbook
10.7 ms for 5.3, 2.0. All are under the 2.5 that the design asked for
after slice 3.

What comes after the two slices is therefore not memoization: the PDF
writer, three times upstream's for the same pages (156 ms for about 55
of `longer.typ`), and the document-level realization, which upstream
repeats in every iteration too and which is also what every kept page
run and document holds in memory (above).

### Not scheduled

Each needs a document that shows it, then follows the pattern of slice 2:
`eval_string` as a memoized call (its scope is slice 1's);
`SvgImage::with_fonts_images` (its world plumbing is slice 1's); the HTML
document and fragments; the bundle; the state sequence (first the rule
under which its values can be kept); the capture table across
compilations; the locator as a tracked argument; keeping a file's `Bytes`
when a reload gives equal bytes (`kit/files.mbt`). And outside of this
design: the speed of the PDF writer and of realization, which are what is
left (3.4).

## 9. Acceptance

### 9.1 Correctness: what the design needs from the harness

The harness (`recompile-harness`, in progress elsewhere) applies seeded
edits to documents in one process and requires each recompilation to equal
a compilation from scratch. For this design it must have:

**Three references.** (a) The same world after `@library.evict(0)`,
compiled again: this compares everything, span numbers included, since the
sources and their edit history are the same. (b) A new world on the same
files: this catches state that survives in the world or in sources, and
must compare spans as file ranges, since a fresh parse numbers differently.
(c) For a sample of steps, a fresh process on the same files (the CLI):
`evict(0)` is only as complete as the list of registered caches.

**What is compared.** Diagnostics (errors and warnings with their spans
resolved to ranges, hints, tracepoints: their number too), the frames of
every page (the `paged` stage's dump, with spans), the introspector's
answers the export uses (outline, labels), and the bytes of PDF and SVG.

**As upstream's watch.** (Since the decision on module equality, 5.4.)
One difference between a recompilation and a compilation from scratch is
upstream's own and is not a stale result: `==` between a module that a
kept call returned and the module of the same file evaluated now. The
harness accepts it at the steps of sequences that are recorded from the
upstream binary's `typst watch` (`tests/recompile/upstream/`,
`scripts/gen_recompile_upstream.py`), and only if the pages of the step
are byte for byte what upstream's watch wrote there, the dependencies and
diagnostics are those of a compilation from scratch, and the other
outputs are those of the same document; a compilation from scratch of
every such step must give what upstream's gives. Every accepted step is
counted, and the count is part of the verdict. A difference that
upstream's watch does not show is a failure like any other. Built in
step 4 (`tests/runner/recompile_pinned.mbt`; `tests/recompile/README.md`
has the rule in full).

**Edits.** Text inserted, deleted and replaced at random offsets of the
main file, of imported files and of package files; in code, markup, math,
raw text, comments, closure bodies and next to them; an edit and its
reverse (the text is old, the span numbers are not); several files in one
step; a file rewritten with the same bytes. Files created, deleted,
replaced by a directory: import targets, images, data files, a package
manifest's `entrypoint`. Bytes changed of: an image, a `.bib` file and a
CSL style (cited and shown on a page whose other content does not change),
a `.tmTheme`, a `.sublime-syntax`, a file read with `read` inside a
function, an image linked from an SVG, a plugin. The fonts: an entry added
to the book that shadows a family in use; the bytes of a font replaced
under an unchanged book; a font removed, so that indices of the old book
are asked of the new one. The date: another day, `today` with two offsets,
a world that stops knowing the date. `sys.inputs` (a new library), the
main file. Sequences longer than `max_age + 2`, with `max_age` 0, 1 and
10, and with `evict` not called at all.

**Scenarios that random edits will not find**, each a fixed test:

- a file with an error, imported; the main file edited twice: the error
  has one tracepoint each time (5.3; `eval/import_wbtest.mbt`, "the error
  an entry keeps is not the one an import adds its tracepoint to");
- a compilation inside a host function, on another world with the same
  sources and other data files, and the same that fails with an error:
  each world gets its own answers, also afterwards (5.2);
- `eval_string` outside of a compilation, twice, with a data file changed
  in between that an imported module reads (5.2);
- a module that holds a plugin's module without functions, kept in use
  while the plugin's own cache entry ages out, then compared with a new
  load (5.4; `library/plugin_identity_wbtest.mbt`: the same argument,
  another object to `==`, as upstream's);
- two compilations whose libraries differ in `html_span_filled`, raw text
  in HTML (slice 0b);
- a host that keeps a document and changes the array a query returned, the
  document's authors, its format options (5.3, 5.4); the styles that
  `@typst.trace` returned, then the same trace again; the entries of a
  bibliography that `Works` returned, then the works again; a hint added
  to the error of a plugin call that was caught, then the same call (5.4);
- a value that hides a file, handed through a function: a tiling whose
  body is an SVG that links a PNG, passed through `id(x) = x` and used as a
  fill; the PNG changes (5.5). The same with a raw element and its theme;
- within one scope of `doc`: a function that reads the origin listing,
  called twice, then a callback that registers an origin and a snippet,
  then the function again, and a read of the new snippet's file (5.2);
- a document that does not converge, whose counter update calls a function
  that reads a file; the file changes: the convergence warning and the
  pages (5.2);
- two libraries made from one builder with different rules or routines,
  the same document under each (5.3);
- a file that exports `float.nan` and is imported as a module; a function
  `get() = m` in the main file and `get() == m` on the page; a comment in
  the imported file changes (5.4). Since the decision on module equality
  this is the difference that is upstream's: `false` in a watching
  process. Pinned to the upstream binary's watch
  (`tests/recompile/upstream/`, below);
- a library with two native functions that have the same name, title and
  documentation; a file that exports one of them, chosen by `read`; a
  function `get() = m.x` in the main file; the choice changes (5.4);
- a call stored under a plain world that read a real file named
  `<edsl-origins>`, then a `doc` session in that directory whose listing
  starts with the same bytes and grows (5.2).

**Mutation checks.** The harness is only evidence if it fails when a
validation is missing. Each of these, switched on by a build flag, must
make it fail, and the flag list is part of the stage:

| # | what is broken | which edit must expose it |
| --- | --- | --- |
| 1 | `import_file` does not record its source read | edit of an imported file |
| 2 | `DataSource::load` does not record its file read | changed bytes of a data file or image |
| 3 | `resolve_package` does not record the manifest | changed `entrypoint` |
| 4 | a failed read is not recorded | a missing import target is created |
| 5 | `today` is not recorded | the date changes under `datetime.today()` |
| 6a | `book` is not recorded | a font is added that shadows a family in use |
| 6b | `font` is not recorded | a font's bytes are replaced under an unchanged book |
| 7 | the reads of a reused call are not pushed to the log | `read` inside a function called from a kept closure call or module |
| 8 | modules are keyed by text, not by the numbered tree | an edit and its reverse; the diagnostic of a later error must point to the right range |
| 9 | the reparser changes nodes in place | an edit inside and next to a closure body whose closure a kept result holds |
| 10 | the capture table finds an analysis by span alone, without the node | an edit after which another closure expression has the span of an old one, both evaluated in one compilation (as `eval/captures_wbtest.mbt` tests today) |
| 11 | introspector reads are not validated across compilations | an edit that moves a heading to another page under an outline |
| 12 | the library is not in the key | `sys.inputs` changes |
| 13 | (turned round by the decision on module equality) the stores take modules by identity instead of by their hashes, as the port did | the sequences pinned to upstream's watch: where upstream's watch shows a stale module passed as an argument (`pick((m: m)) == m`), the port then computes the call again and shows what neither upstream's watch nor a fresh compilation shows |
| 14 | the sink of a reused entry is not replayed | a warning inside a kept closure call must be reported by every recompilation |
| 15 | raw elements keep their theme by path | changed bytes of a `.tmTheme` |
| 16 | `Works::generate` keeps its last result by introspector | changed bytes of the `.bib` file, with two paragraphs that cite: the second one found the works of the first under the same introspector, and it must be the one that is kept and found |
| 17 | the stamp of one scope is taken for another's | the nested compilation above |
| 18 | diagnostics are shared with entries | the imported error above |
| 19 | the predicate calls a volatile file stable | the `doc` scenarios above (one flag for the listing, one for a snippet that does not exist yet) |
| 20a | an SVG image's fingerprint leaves out its linked images | the tiling above, captured by a function instead of passed to one (an argument is also compared exactly, which would hide the fault) |
| 20b | an SVG image's equality leaves out its linked images | the tiling above, passed to `id` |
| 21 | the engines of `History::compute` get the untracked world | the document above that does not converge; the call that reads the file must run inside the history, not be found from the layout |
| 22 | descriptors are fingerprinted by their texts | the two native functions above |

Each flag removes one recording, one validation, one replay or one copy,
and each scenario must show that the entry in question was found (the
counters of 9.2), or the check proves nothing.

**The recording check** (step 1 of slice 1; `library/memo_check.mbt`,
`@library.set_memo_check`, the runner's `--check-reads`). While nothing is
kept across compilations, a missing world read changes no output and the
harness cannot see it; the checked mode below compares results, which a
missing read does not change either. What can fail is this: every result
that a store is about to keep (of `memoize`, of `memoized_closure`, of the
module store) is computed once more, from scratch, and the world reads its
entry keeps must be what that run asked of the world, read for read, in
the order of first occurrence, with the same fingerprints of the answers.

- What the run asked is seen from below the hooks under test: the raw
  world of a tracked world is wrapped in a spy that notes every call of
  `source`, `file`, `book`, `font` and `today` with a fingerprint it
  computes of the answer. A tracked method that does not record, a path on
  which reads are dropped, and a read that reaches the world around the
  tracked methods all show as a read of the spy that the entry lacks; a
  read of a volatile file in the run of a kept entry shows too.
- From scratch: the stores are set aside for the run and start empty, so
  nothing in it is taken from an entry whose reads are the thing under
  test, and every call inside it runs at least once and asks the world
  itself. A read that an entry merges into its caller on a hit is thereby
  compared with the read that a run makes. Inside the run nothing is
  checked again, so the check costs each entry one memoized computation of
  what is under it.
- Isolated from the call it repeats: a sink and an introspection recorder
  of its own; the context's read flags, the route's shift bounds, the
  route-query and traced-file logs, the fingerprint flags, the counts of
  closure calls and the world's log are put back.
- With the modules of the first run: a file that the run imports is
  evaluated again, for its reads, but the import gives the module that
  the entry set aside holds. The repeated call has modules of the first
  run in its arguments and captures, and modules compare by identity; a
  run with new ones can take another branch and read another file.
- A module entry that keeps an error is checked like one that keeps a
  module: its evaluation fails again, and what it read until then is
  compared.

It does not compare results, and it cannot see a host function that reads
something that is not the world. A cache of the process that hides a read
(5.5) would show as a read that the entry has and the second run lacks.
`works_cache` does not show: it is found by the identity of the engine's
introspector, and every memoized call has an introspector object of its
own (`track_with`), so within one memoized call the works are generated
by that call before they are found by it; it stays a violation of rule 1
of 5.5 for step 2, outside of what this check sees. (Step 2 replaced it
by an entry of `memoize`, which the check does see: with it the stages
have 31 211, 390, 351, 1 307 363, 82 589 and 120 825 entries, still none
that differs.)

Run over every document of the `paged`, `html`, `bundle`, `packages`,
`edsl` and `recompile` stages it checks 1.54 million entries (31 075,
328, 351, 1 307 339, 82 567 and 120 000) and finds no difference; the
outputs of the stages are what they are without it. On the way it found
one thing: a world whose `book` makes a new book for every call, which the
trait's default did (5.2: a book is the same answer only as the same
object; a book without fonts is now one answer whatever object it is).

**The mutation checks of step 1.** Of the table below, 1 to 7, 17, 19 and
21 are about what step 1 builds; no edit can expose them yet, since
nothing is kept. Each was put in by hand (never committed), one at a
time, and must make the recording check or a unit test fail. "Check" is
`--check-reads` (the number of entries that differ, and the first
document); the tests are `library/tracked_world_wbtest.mbt` (L),
`typst/tracked_world_wbtest.mbt` (T), `doc/volatile_test.mbt` and
`doc/volatile_wbtest.mbt` (D).

| # | what was broken | what exposed it |
| --- | --- | --- |
| 1 | `import_file` reads the source around the tracked method | check: `paged` 5 entries in 4 tests, first `scripting/import.typ` `import-basic` (the module of `chap2.typ` kept nothing and asked for `chap1.typ`); the projects of `recompile` 390 (`project/book`); `packages` `cmarker/levelling-report`. T: "a module's reads are those of the call that imports it" |
| 2 | `DataSource::load` reads the file around the tracked method | check: `paged` 165 entries in 21 tests, first `model/par.typ` `par-semantic-align` (a bibliography file); `recompile` projects 1268; `packages` `cmarker/allotment-notes` (`plugin.wasm`). T: four tests |
| 3 | `resolve_package` reads the manifest around the tracked method | no document of the suites: they import packages from the main file, outside of every memoized call. T: "the manifest of a package is a read of the call that imports it" |
| 4 | a failed read is not recorded | no document of the suites. L: "a failed read is kept, also of a call that goes on", "an entry is rejected if one answer differs" (a file that appears); T: "a module that failed is found with its reads", "reads at every level, of files that are there and files that are not" |
| 5 | `today` does not record | check: `recompile` projects 1264 entries (`project/book`: a closure that asks for the date); nothing in `paged`. L: three tests |
| 6a | `book` does not record | check: `paged` 22 843 entries in 1661 tests (first `math/op.typ` `math-op-scripts-vs-limits`), `recompile` projects 19 366, `packages` 1014. L: five tests |
| 6b | `font` does not record | check: `paged` 22 796 entries in 1657 tests, `recompile` projects 19 366, `packages` 1014. L: four tests |
| 7 | the reads of an entry that is taken are not pushed to the log | check: `paged` 228 entries in 63 tests (first `model/par.typ` `par-semantic`), `recompile` projects 756 (a module found again: `chapters/intro.typ` lacks the JSON file of `lib/shared.typ`), `packages` 37. Per store: L "the reads of an entry that is taken are its caller's" (`memoize`), L "closure calls keep them, are rejected by them and hand them on", T "a module's reads are those of the call that imports it, computed or found" |
| 17 | an entry with any stamp passes | L: eight tests, among them "the stamp of one scope is not taken for another's" and "an entry is rejected if one answer differs". No document: the stores end with their compilation |
| 19 | (a) the engine takes no file for volatile | L: "what reads a volatile file is not kept, nor what is around it", "an entry with a read that is volatile in the scope at hand is not taken"; T: "the module of a file that changes during the scope is not kept"; D: "a function that reads the origin listing is not answered from an earlier call" (the second call shows the listing of the first) |
| | (b) `doc`'s predicate calls the listing stable; (c) it knows only the snippets that exist | D: "the files that change during a session: the listing and every snippet slot, by path" |
| | (d) a module entry is kept for a file that is volatile itself | T: "the module of a file that changes during the scope is not kept" |
| 21 | the engines of `History::compute` get another tracked world | nothing fails, and nothing can be stale: an engine cannot hold an untracked world, and a tracked world of its own is in no scope, so its calls are not memoized (`paged`: 73 entries fewer, the same pages). The call that reads a file inside the history is checked in T: "a function that reads a file, called from the history of a document that does not converge" |

And for what revision 5 added: the library is not compared (L: "the
library is compared (`sys.inputs`)"); a read through another tracked
world does not mark the calls in progress (L: "a call that reads through
another tracked world is not kept"); the reads of a call that raised are
dropped (L and T: three tests); the reads of a call that returned are not
left for its caller (check: `paged` 22 938 entries, 18 tests); a read
that is in the caller's part of the log is not logged for the call inside
(check: `paged` 2368 entries in 254 tests, first `text/raw.typ`
`raw-theme`; L: two tests). One mutation nothing exposes: `memoize`
storing into a store whose generation changed during the call (a nested
compilation) has no effect while a store is emptied when it sees another
generation.

**The mutation checks of step 2.** 15 was slice 0b's. 16, 20a and 20b are
this step's; each was put in by hand, never committed, and run against
the tests of the step (S: `typst/state_outside_wbtest.mbt`, L:
`library/works_wbtest.mbt`), the recording check and the `recompile`
stage, which since this step also keeps the page hashes of a watching
compiler and its page images (`tests/recompile/README.md`).

| # | what was broken | what exposed it |
| --- | --- | --- |
| 16 | (a) the works are found by the engine's introspector object and the elements again, in a cell (the code as it was) | S: "one engine in two scopes, with a bibliography that changes in between" (the second scope has the book of the first), "an entry of the store is found by its key and taken if the files answer the same", "a CSL style that changes behind its path", "generated once for all the calls of an iteration that cite" (75 generations for 3). Not the recording check and no document, as said above: a memoized call has an introspector object of its own, so the cell hid no read from an entry, only from a host that keeps an engine |
| | (b) the works are found by their elements alone, in a cache of the process that `evict` drops with the decode caches (what the cell is as soon as two calls share an introspector object) | check: `paged` 6 entries in 3 tests (the entry of a layout has the read of the `.bib` file that its run from scratch, which finds the works, does not make); the `recompile` stage: 7 sequences, among them the sweeps of `bibliography-multiple-files` and `bibliography-before-content`; `paged`: 15 tests |
| 20a | the fingerprint of an SVG image leaves out its linked images | the `recompile` stage: 3 sequences, "page images differ from a fresh compilation" at the step of the sweep that gives `art/photo.png` the content of another PNG (`project/linked`, the project of this step) and in the sweep and the random sequence of `image-svg-linked-many-formats`: the page hashed the same, so the watch loop kept its image. S: "a linked image that changes is another page", "a tiling of an SVG is as good as the images the SVG links". L: "an image is its data, its fonts and the data of the images it links". `scripts/watch_check.py`, scenario `linked` (what the code before the step fails) |
| 20b | the equality of an SVG image leaves them out | S: "a tiling of an SVG is as good as the images the SVG links"; L: the same test as for 20a. No document: nothing that compares arguments is kept across compilations yet |
| | the equality of an SVG image leaves out which font was chosen for what | `doc/svg_identity_test.mbt`: "an image is also which font was chosen for which text" (two pages with other pixels and one image) |
| | the math of a bibliography entry is evaluated without `with_own_route` | S: "math in an entry is evaluated on a route of its own" (the works are generated again by the second call) |
| | the works raise the errors they keep, not copies | L: "the errors they keep are copies for whoever catches them" (the second catch sees the tracepoint and the hint of the first) |
| | a call that asked its route is kept by an entry that tracks its route | L: "a call that tracks its route is found on every route, unless it asked one" |
| | a hit of an entry that tracks its route binds the closure call around it to its depth | L: "what is asked of a route inside a tracking call is the caller's too" |

Of the scenarios 16 and 20a ask for (an edit that must expose the fault
through a kept result), the works one is there as far as it can be before
step 5: the entry that is kept and found within a compilation is the one
that the edit of the `.bib` file must reject, and (b) is that fault. The
tiling "captured by a function" and "passed to `id`" are pages of
`project/linked`; they pass by construction until closure calls are kept,
and are there for the step that keeps them.

**A checked mode.** A build flag under which a hit is followed by a shadow
run of the function and a comparison.

- What runs: the function, captures, arguments and context of the call at
  hand, not what the entry kept (a copy of the arguments is taken before
  the lookup, since a closure call consumes them), with the route,
  locator, traced span and world of the call.
- Isolated from the call: every store off, so that nothing kept goes into
  it; a sink, an introspection recorder and a world log of its own; the
  context's read flags, the route's shift bounds, the route-query and
  traced-file logs saved before and restored after. It stores nothing and
  replays nothing. It asks the same table of answers as the call, so it
  does not test that table (mutation checks 1 to 6 do), and it never meets
  a volatile file (such an entry is not found, 5.2).
- Compared, by fingerprint (which has spans, locations, lifecycles and
  the bits of floats) and by the exact comparison where the fingerprint is
  flagged (host functions as objects): the
  result, by kind: a value; frames; a module (by its hash, as the stores
  take it: with stores off its imports are new objects); pages and a document with their
  frames, info and options; works with their maps and errors; a counter
  sequence. The sink: diagnostics with spans, hints and traces, traced
  values and styles. Introspections are closures and cannot be compared:
  their number is. Shared flags of arrays and dictionaries are not part
  of it.
- The invariant of 5.4, by reachability: every host function in the kept
  result is, as an object, reachable from the key, from the library, or
  from the result of one of the entry's introspector reads.

comemo has nothing like it (its debug
assertions catch a memoized function whose tracked calls differ between
two runs: `tree.rs`, `MissingCall`; `constraint.rs`); it is what makes
"equal to from scratch" checkable per entry instead of per document. The
harness runs a subset of its seeds in it.

### 9.2 Performance

The gate is on what incremental compilation is about, evaluation plus
layout; the export is not incremental in either program and is reported
beside it. For a document and an edit, with both programs on the same
machine, the same files and options, medians of five recompilations:

    G = (port: evaluation + layout) / (upstream: evaluation + layout)

from the port's phase timers (to be added to `watch`'s status behind a
flag) and upstream's `--timings` (`eval` and the `iter` events). After
slice 3, `G` is at most 2.5 for every row of 3.3 in which something
changes, with one exception that is listed and not gated: the handbook's
package edit, in which every page run is laid out again and upstream uses
several threads (the probe: 3.2). A row whose five times spread by more
than 15 % is measured again. `--timings` slows upstream where many
functions are called, which makes `G` lenient for the package documents;
their total times are reported with it.

What the probe gives for `G` after an edit at the end (3.4): `long.typ`
1.6, `longer.typ` 2.2, `showcase.typ` 1.9, the handbook 1.8. For the
totals, with the first compilations for comparison:

| document | first compilation: port / upstream | ratio | after an edit at the end, probe / upstream | ratio |
| --- | ---: | ---: | ---: | ---: |
| `long.typ` | 240 / 100 | 2.4 | 57 / 22.8 | 2.5 |
| `longer.typ` | 1225 / 500 | 2.5 | 307 / 118 | 2.6 |
| `showcase.typ` | 345 / 153 (229 after slice 0) | 2.3 (1.5) | 19 / 7.0 | 2.7 |
| deck | 1710 / 131 (651 after slice 0a) | 13 (5.0) | 327 / 16.7 | 20 |
| touying | 198 / 144 | 1.4 | 17 / 10.7 | 1.5 |
| handbook | 172 / 100 | 1.7 | 25 / 9.1 | 2.7 |

The totals after an edit are worse than the first compilations' where the
export is most of a recompilation (60 % for the handbook, 73 % for
`showcase.typ`, 93 % for the deck): the PDF writer is 3 to 4 times
upstream's, and for images far more until slice 0c. The numbers of 3.3 are
not targets: they are restated after the first step of slice 1 has measured
recording and validation, and each slice reports its rows against that.

Measured locally with `scripts/watch_check.py --bench`, extended to the
documents and edits of section 3 (it needs the upstream binary and real
file events, like the rest of that script). In CI, where times mean
little: the harness reports, per step, the hits and misses of every store,
and a fixed list of scenarios pins them (after an edit at the end of
`long.typ`: one module evaluated, no closure called, at most two
paragraphs and one block laid out, no image decoded). A change that makes
a store miss shows as a count.

## 10. Deviations from upstream

Kept or introduced, each stricter than upstream unless said:

1. **The locator and the route are in layout keys in full** (upstream
   tracks them). A result is not reused at another position in its flow
   even if it never asked where it is. Reason: what it would take to track
   them (a second level of keys, as `ClosureStore.asked` has for the
   context) is not justified by a measurement yet. Blocks since slice 2:
   a block that never asks where it is (a shape, a block of text without
   located elements) is laid out once per place, where upstream finds the
   layout of the first place for every other.
2. **The traced span is in the keys of closure calls and layouts**
   (upstream tracks `Traced::get`). Only IDE tracing sees it.
3. **Arguments are also compared exactly** (`values_memo_equal`), not only
   by fingerprint, and are therefore kept. Reason: host closures compare
   by identity and fingerprint by a key of the host's. (Modules were a
   second reason until step 4; they are taken by their hashes now, as
   upstream's.) 6.2 has the cost.
4. **At most four entries per key** (`memo_max_entries`, first in, first
   out) and twelve evaluations per source (`eval_memo_max_entries`),
   **among those that no `evict` has seen yet** (step 5). comemo has no
   limit. Within a compilation, and in a process that never evicts, the
   limit is what it always was; in a process that evicts, an entry of an
   earlier compilation is not counted and goes by its age, as comemo's
   does, because the difference can be seen there
   (`tests/recompile/upstream/limit.json`). An evaluation that an open
   scope stored or took is not dropped for the limit.
5. **Errors are not kept** by `memoize` and `memoized_closure` (upstream
   caches a `SourceResult`); module evaluations keep theirs, as a copy
   that is copied again for every caller.
6. **Results that hold host closures are not kept** (frames,
   introspector reads), entries keyed by them end with their compilation
   (step 4), the state sequence is not memoized.
7. **The library is identified by a serial number**, not by its hash.
8. **The answers of the world are kept per scope**, comemo's accelerator
   per tracked reference and until `evict`. Same observable behaviour
   under the same contract. A world may declare files that change during a
   scope, which comemo's contract does not allow. The answer of a source
   is fingerprinted by its text if it was never edited and by its revision
   otherwise (5.2): equal only where upstream's hash of the text and the
   numbered tree is, and unequal for two sources that were edited into the
   same tree, which upstream's hash would call equal. A font book and a
   font are the same answer only as the same object (a book: in the same
   state), where upstream compares the hash of the infos and of the data:
   hashing them cost 1 % and 8 % of a compilation with system fonts. A
   call that reads through a second tracked world is not kept (comemo
   would record the calls on both).
9. **Persistent edits are upstream's semantics for nodes, not a
   deviation.** Upstream's nodes are `Arc`s that are written through
   `Arc::make_mut`: every write to an inner node goes through
   `SyntaxNode::inner_and_span_mut` (`typst-syntax/src/node.rs:85`, the
   `make_mut` at `:91`), which the renumbering (`numberize`, `:516`) and
   the replacement of children use. Whoever holds a node keeps what it
   had. The port cannot ask whether a node is shared and copies always; no
   holder of a node can tell the difference. What deviated was the port
   as it was, which wrote in place. A `Source` was to be another matter
   and stay one object that an edit changes for everyone who holds it
   (upstream's is a handle whose clone keeps the old state, `source.rs:24`,
   `make_mut` at `:107`), on the ground that nothing that is kept holds a
   `Source`. As built it does not stay so: a `Source` never changes and an
   edit returns a new one (5.4), which is what a clone is upstream, for
   every holder and without a rule about who may hold one. The difference
   to upstream that remains is in the signature: `edit` and `replace`
   return the source instead of changing `self`.
10. **Descriptors of native functions, elements and types are
    fingerprinted by a number given when they are made** (5.4, built in
    step 4); upstream hashes their address. The port fingerprinted their
    texts. Not a deviation in what can be observed: both are a number per
    object that depends on the process.
11. **Modules: none.** (This item was "looser than upstream: the modules
    of files, plugins and libraries compare by their fingerprints", the
    recommendation of revisions 3 and 4. The owner decided otherwise on
    2026-10-11: `==` and the stores treat modules exactly as upstream's
    do, 5.4. The port's earlier deviation in the other direction, modules
    as identity-compared arguments of memoized calls, is gone too.)
12. **An SVG image's fingerprint and equality include the images it links**
    (5.5); upstream's cover its bytes and fonts. Built in step 2 of slice
    1, with which font was chosen for which text besides (upstream's hash
    has the fonts that were loaded). It is the one deviation here that shows without a watching
    process: upstream memoizes `Image::new_impl` on that hash, so two SVG
    files with the same bytes next to different linked images are one
    image there, and the port shows two.
13. **Not memoized**: the rows of section 4 that say so.
14. **One thread**: upstream lays out page runs in parallel.
15. **The works of a bibliography are found by their elements and by what
    their call read of the world** (5.5, "As built"), where upstream's
    elements carry the loaded bibliography and style in their hash. The
    same results are found again; the port's elements hold the sources
    only. Not stricter and not looser: another place for the same data.

16. **A compilation with memoization off takes and leaves nothing**
    (step 5; comemo has no such switch). The stores and the results kept
    by content are neither asked nor written, and an evaluation of a file
    ends with its scope, as every evaluation did before step 5: the module
    store must still answer inside the scope, since a file is one module
    in a compilation.
17. **`evict` during a compilation spares the evaluations of files that
    an open scope stored or took** (step 5). comemo would drop them, and
    upstream never evicts during a compilation; here a host function can
    (a compilation of `doc` inside a callback ends with `evict(10)`), and
    a file that is imported again afterwards must be the module it was.
18. **Entries whose key holds a host closure are dropped when the
    outermost compilation ends** (step 5), not when they are old: nothing
    can find them afterwards (deviation 6).
19. **What the closure calls of one function and arguments asked of their
    contexts is kept with the time of its last use**, an eviction count,
    instead of an age per object (step 5; comemo has no such table: its
    tree asks the context call by call). It goes when it was not asked
    for in more than `max_age` evictions, which is never before an entry
    under it.
20. **`doc` evicts** (step 5): a compilation or lowering of `doc` ends
    with `evict(10)`. Upstream has no such host.
21. **A layout callback is its kind and its captured element** (slice 2),
    in fingerprints and in the comparison of arguments. Upstream hashes
    the function pointer too (`layout/container.rs:609`). Not stricter:
    the same key only while an element type has one callback per kind,
    which the show rules of `layout/rules.mbt` keep, and while equal
    content gets one function from whoever makes callbacks for plain
    content (`BlockElem::multi_layouter_content`, which is told apart
    from the callbacks of the rules: `BlockMultiCallback.typed`).

Upstream quirks the port reproduces since step 4 (the owner's decision
on module equality, 5.4):

- Two modules with one hash are one argument for comemo, and for the
  port's stores: two plugins without functions, a file evaluated twice,
  the modules of two libraries (`typst/oracle_wbtest.mbt`, "modules: ..";
  `typst/modules_wbtest.mbt`).
- A module that a kept result returns and the module of the same file
  evaluated again are different objects and compare unequal: what
  `typst watch` shows after a comment in an imported file is not what
  `typst compile` shows (`tests/recompile/upstream/`). Since step 5 the
  port's watch shows it, at the 18 steps of the five recorded sessions at
  which upstream's does.
- The module of a plugin is the same object for as long as comemo's
  result of `Plugin::module` lives, and another after that: a kept call
  that returns it agrees with the plugin loaded again up to ten evictions
  after the plugin was last loaded and disagrees from the eleventh on
  (`tests/recompile/upstream/plugin.json`).

Upstream quirks the port does not reproduce:

- `eval_string` is memoized upstream (`typst-eval/src/lib.rs:101`) and
  not here (section 4; "not scheduled"). Two evaluated strings with
  equal hashed arguments are one call for comemo, and two modules with
  one hash are equal arguments: with the modules `a` and `b` of two
  plugins without functions, `for m in (a, b) { eval("m", scope: (m: m))
  == m }` is `(true, false)` in upstream, whose second evaluation is the
  first one found, and `(true, true)` here (checked with both binaries
  by the review of step 5). A difference in a compilation from scratch.

- Two values with one hash are one argument for comemo where the port
  compares arguments exactly and the comparison is finer than the hash.
  For modules it no longer is (above). A value that is not equal to
  itself is the case that costs: a float that is NaN, in a field of an
  element or in an argument, is found again by comemo (it hashes the
  bits) and here only as the same object, which a later iteration has
  and a later compilation of an edited file has not (section 8, "Slice 2
  as built").
- comemo keeps a result whose constraint is satisfied even if the nested
  results it was built from were evicted and recomputed as other objects.
  The port has the same structure; it is harmless here because nothing
  that is made during a compilation and kept compares by identity (5.4).
- A value built from a file whose hash does not cover the file is reused
  by a memoized call that is handed it again after the file changed (an
  SVG's linked images, deviation 12). In upstream that call is
  `Image::new_impl` itself, which every image goes through: checked with
  the binary of `e58a63af`, two SVG files of the same bytes next to a red
  and a blue `img.png` are two red squares, as images, as tilings and in
  the PDF.

Slice 3 (page runs and the document), each stricter than upstream or the
same in what can be observed:

- **The locator of the bundle's document and of a page run is in the key,
  resolved** (upstream tracks it): deviation 1, for two more functions.
- **A document that is handed out is a deep copy of its frames and
  groups**, and what an entry keeps is a copy-on-write clone
  (`PagedDocument::owned`, `kept`). Upstream's `PagedDocument: Clone`
  shares pages and frames, which nobody can write to there. Nothing to
  observe but the time (0.6 ms per document of 121 pages).
- **A kept document and the documents it is handed out as have one
  introspector object**, as upstream's share an `Arc`. Its
  `frame_link_targets` hands out a copy of the set.
- **The answers of the read accelerator outlive an `evict`** by one
  (comemo drops its accelerator with every `evict`): those that the
  compilation before asked for. Not observable: an introspector answers
  the same for as long as it lives.
- **An `ElementIntrospector` forgets its cached queries when it has
  65 536** (upstream's `QueryCache` has no bound). Not observable.
- **Not built**: a smaller age for the entries of page runs and
  documents (section 8, "Slice 3 as built", "Memory"). It would be the
  first age that is not comemo's.

## 11. Decisions and open questions

Decided on 2026-10-07 by the coordinator of this work:

- `max_age` is upstream's 10. The measured and the unmeasured bound are in
  6.1, and slice 1 measures the peak in the harness's soak run.
- Slice 0c is the conversion cache in `pdf/` first, with its measured gain;
  the change in `moonbitlang/pdflite` follows only if the measurement says
  that compression is worth it.
- Persistent edits in the reparser: accepted (section 10, item 9: they are
  upstream's semantics).
- Slice 0 is built first, before the harness, which it does not need.
- A third review round on 5.2, 5.4 and 9.1: `docs/reviews/
  incremental-design-3.md`. Its verdict is "request changes"; its nine
  findings are answered in this revision, and those answers are not
  reviewed.

Decided on 2026-10-11 by the owner:

- **Module equality: exactly as upstream**, and plugins consistent with
  upstream. `==` compares the objects, the stores take modules by their
  hashes. This overrules the recommendation of 5.4 in revisions 3 and 4
  (equality by fingerprint, deviation 11 as it was) and is neither of the
  two alternatives that were costed there, which stay in 5.4 as history.
  What is given up is the guarantee that a recompilation always gives
  what a compilation from scratch gives: where a document compares a
  module that a kept call returned, the port will give what upstream's
  `typst watch` gives. The harness requires equality with a compilation
  from scratch everywhere else and accepts this difference only at steps
  that are pinned to the upstream binary's recorded watch output (9.1).
  Built in step 4.

Leaning towards "accepted" by the coordinator; the owner may overrule:

1. (Decided, above: module equality.)
2. **The public surface.** `Library` stops being a record that hosts can
   build or update, and `Introspector::query` returns a view. `doc` and
   other hosts see both. In a minor version? (Step 1 made its part of the
   change: `Engine.world` is a `TrackedWorld`, `compile_with` has a
   parameter for volatile files and hands its callback the tracked world,
   `eval_source`, `world_range`, `analyze`, the loading functions and
   `SvgImage::with_fonts_images` take the tracked world,
   `compilation_epoch` and `note_evaluation` are gone; `CHANGELOG.md`.
   Step 3 added to the surface and changed one behaviour: `eval_source`
   is memoized, so two calls in one scope with the same source give one
   module. Step 4 made the introspector's part: `Introspector::query`,
   `IntrospectorBackend::query` and `ElementIntrospector::query` return a
   view, `memo_fingerprint` returns a `MemoKey`, `Module::canonical` is
   gone.)

## Appendix A. The probe

Not in the repository: measurement code that skips validation must not be
one flag away from a release. What it was, so that a number here can be
measured again, and so that it is clear what it did not do: no world reads
recorded or validated for closure calls and layouts, no copies of
diagnostics or documents, trees edited in place, the prototypes found by
key alone.

- `library/memo.mbt`: a flag under which `with_layout_memo` does not
  advance `memo_counter` and `compilation_counter` after the first
  compilation; counters of hits and misses; a clock and named timers;
  `ProbeMemo`, a `MemoStore` whose entries are found by the key alone; the
  `noargs` input of `memoized_layout`; a counter of its own for the capture
  table's generation (`eval/captures.mbt` reads that one).
- `eval/import.mbt`: a log of the files read (`import_file`,
  `resolve_package`, `DataSource::load`); every `EvalMemo` keeps the reads
  of its evaluation with the text or bytes they gave and is only reused if
  the world gives the same; an entry point that sends the main file
  through `eval_source_memoized` (`typst/lib.mbt` calls it under the flag).
- `layout/flow_collect.mbt`, `layout/pages_run.mbt`, `layout/pages.mbt`:
  the three prototypes of 3.1, with the keys of section 8. `layout/flow.mbt`
  and `layout/inline.mbt`: counters. `library/image_raster.mbt`: the cache
  of decoded images by their bytes; `library/text_raw.mbt`: highlighted
  lines by `(element, styles)`.
- `kit/platform`: `mi_collect` and `mi_heap_visit_blocks` of the runtime's
  allocator, summing `used * block_size` over the heap's areas.
- `cli/compile.mbt`: the loop (`typst-probe.conf`: `keep`, `repeat`,
  `edit`, `marker`, `insert`, the switches, `live`), which prints one line
  of timers and counters per compilation.

Drivers (Python, outside the tree): a matrix of configurations and edits
that prints the median of the recompilations; `sample` for ten seconds on
the repeating process and inclusive shares by symbol; `typst watch` of the
upstream binary through `scripts/watch_check.py`'s `Session` with the same
edits; the generator of the stand-in deck.

Commands, with `P` the probe build of `cli` and `U`
`.repos/typst/target/release/typst`, both with `--ignore-system-fonts
--package-path <packages> --package-cache-path <packages>
--creation-timestamp 43200`:

    P compile long.typ out.pdf      # typst-probe.conf: keep=1, repeat=5, edit=..
    U watch long.typ out.pdf --no-fullscreen [--timings t-{n}.json]
    /usr/bin/sample <pid of P> 8 -file report.txt
