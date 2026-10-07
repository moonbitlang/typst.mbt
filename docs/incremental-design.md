# Incremental compilation: design

Status: design, not implemented. Revision 4 (2026-10-07). Revisions 1 and
2 were reviewed by Codex (`docs/reviews/incremental-design-{1,2}.md`), both
with the verdict "request changes"; revision 3 answered the second review;
revision 4 records the coordinator's decisions (section 11), costs the
alternative for module equality (5.4) and answers a third review
(`docs/reviews/incremental-design-3.md`, "request changes", on 5.2, 5.4 and
9.1); what it changed in answer has not been reviewed. Upstream
`e58a63af`, comemo 0.5.1. Measurements: aarch64 macOS, native release,
`--ignore-system-fonts`, PDF output, other agents building on the same
machine (medians of five; the spread is given where it matters).

The port recompiles from scratch in `typst watch`. Upstream keeps comemo's
caches between compilations and recompiles a small edit in a fraction of the
time. This document says what the port must keep, how a kept result learns
that it is still valid, what it costs in memory, and in which order to build
it. Section 3 has the measurements the order rests on.

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
  their age exceeds `max_age`. Where the port deviates (section 10) it is stricter, with one
  exception that is said there (equality of modules).
- The numbers for what is not built are a probe's, which validated less
  than the design does: they are upper bounds of the gain.

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
  starts: a watching process holds them while it waits.
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
| `layout_document_impl`, `layout_document_for_bundle_impl` | library, content, styles | W I T S R (the bundle variant also L) | not memoized (`layout/pages.mbt`) | only when nothing changed |
| `layout_page_run_impl` | library, children, initial styles | W I T S R L | not memoized (`layout/pages_run.mbt`) | decks (a run per slide); else only when nothing changed |
| `layout_fragment_impl` | library, content, styles, regions, column | W I T S R L | `memoized_layout`, per compilation; key also has the resolved locator and the whole route | yes |
| `layout_single_impl`, `layout_multi_impl` | library, block, styles, region(s) | W I T S R L | not memoized (`layout/flow_collect.mbt`) | yes: 40 % of what is left of `long.typ` |
| `layout_par_impl` | library, par, styles, region, expand, situation | W I T S R L | `memoized_layout`, per compilation | yes |
| counter `sequence_impl` | library, counter, selector | W I T S R | `memoize`, per compilation | small |
| state `sequence_impl` | library, state | W I T S R | not memoized, on purpose: its values may hold what compares by identity (`library/memo.mbt`, header) | not measured |
| `html_document_impl`, `html_document_for_bundle_impl`, `html_block_fragment_impl` | as the paged ones; the fragment also `whitespace` | W I T S R (L) | not memoized (`html/`) | not measured (no HTML document here) |
| `bundle_impl`, bundle `export_pdf`/`png`/`svg`/`html` | bundle parts / document, options | W I T S R / the link resolver (not `export_png`) | not memoized (`bundle/`) | not measured |
| `Image::new_impl`, `RasterImage::new_impl` | kind, alt, scaling / data, format, icc | none | not memoized: `RasterImage::new` decodes on every layout of the image (`library/image_raster.mbt`) | yes: 71 % of the deck, 73 % of `showcase.typ` |
| `SvgImage::new`, `SvgImage::with_fonts_images` | data (, families, file) | none / W | not memoized (`library/image_svg.mbt`) | not visible in `showcase.typ` (one small SVG) |
| `PdfDocument::new`, `PdfImage::new` | data / document, page | none | decode cache (`pdf_document_cache`) / cheap | no |
| `Packed<RawElem>::highlight` | element, routines, styles | none | not memoized (`library/text_raw.mbt`, `raw_elem_synthesize`) | yes: half of what is left of `showcase.typ`, a fifth of the handbook |
| `RawSyntax::decode`, `RawTheme::decode` | bytes | none | decode caches | no |
| `Bibliography::decode`, `CslStyle::from_data`, `from_archived`, `Works::generate_impl` | data / style / elements | none / W I T S R | decode caches; `works_cache` keeps the last introspector's works | not visible |
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
| `sys.inputs`, features, formats, routines: the library | `World::library()`, once per compilation (`typst/lib.mbt`, `compile_with`); then `Engine.library` | the library is part of every key (5.3) |
| the main file | `World::main()`, once per compilation (`compile_impl`), outside of every memoized function, as upstream | nothing depends on it but the source it names |
| the traced span | `Engine.traced` | in the key (closure calls, layouts) or validated by its answers (modules); unchanged |

### 5.2 The tracked world

**The reads.** A read is one of

    Source(FileId) | File(FileId) | Book | Font(Int) | Today(Duration?)

and its answer has a 128-bit fingerprint:

- `Source(id)`: for a source, upstream's `Hash for Source`: the id, the
  text and the numbered tree. The tree is in it because span numbers are
  not a function of the text: a file that is edited and edited back has the
  old text and new numbers where it was reparsed, and a module evaluated
  from the old tree holds spans that are now other nodes' or nobody's. The
  fingerprint is computed once per state of a source: `Source` gets a
  revision number (process-wide counter, set when it is made and by every
  `edit` that changes it; `replace` with the same text changes nothing), and
  the fingerprints are kept by revision. For an error, the error
  (`FileError` derives `Hash`; `NotFound` holds the path).
- `File(id)`: the length and the bytes, as upstream's `Bytes` hashes; kept
  for the `Bytes` object the world returned last for the id, so a world
  that returns the same object pays nothing. The CLI's file store reloads
  a file that is read after a reset, so there every file that is read is
  hashed once per compilation, as upstream.
- `Book`: the book's infos; kept in the `FontBook` until it is changed
  (`FontBook::push`).
- `Font(index)`: `Fingerprint for Font` as it is: the data's hash by the
  identity of the data (`font_data_hash`, `library/visualize_hash.mbt`) and
  the index; a constant for `None`.
- `Today(offset)`: the date or its absence, per offset.

**The hooks.** `Engine.world` becomes a `TrackedWorld`: a struct with one
private field, the `&World`, and the five methods; `library` and `main` are
not among them. Engine code has no `&World`. The leaf reads of today's
code (the list was checked in review 1, finding 10):

| read | where |
| --- | --- |
| `source` | `eval/import.mbt` `import_file`; `library/decimal.mbt` `warn_on_float_literal`; `library/engine.mbt` `world_range` (called for tracepoints in `eval/call.mbt`, `eval/import.mbt`, `library/styles.mbt`, `library/grid_resolve.mbt`) |
| `file` | `eval/import.mbt` `resolve_package`; `library/loading.mbt` `DataSource::load` (every loading function and element: `read`, `json`, `image`, `bibliography`, raw syntaxes and themes, plugins, ...); `library/pdf_standard.mbt` (attachments); `library/image_svg.mbt` (linked images) |
| `book`, `font` | `layout/inline_shaping.mbt` (four places), `layout/inline_line.mbt`, `layout/math.mbt`; `library/image_svg.mbt`; `library/text.mbt` `check_font_list` (book) |
| `today` | `library/datetime.mbt` |

and what carries a `&World` to them, each of which gets the tracked one:
`SharedShapingContext::world` and `MathShapingContext.world`
(`layout/inline_shaping.mbt`, `layout/math_shaping.mbt`); the font and
image resolvers of `library/image_svg.mbt`, which keep it for the parser's
callbacks; `BibliographyElem::keys`, `database` and `csl_style`
(`library/bibliography.mbt`); `DataSource::load` and `load_many`.

Not tracked, because they run outside of every memoized call, as upstream:
`compile_impl` and `hint_invalid_main_file` (`main`, the main source) and
`compile_with` (`library`). `@library.analyze` is not among them: it runs
inside the compilation (`typst/lib.mbt`, `compile_with`), and the engines
that `History::compute` builds (`library/convergence.mbt`) replay
introspections, which enter the counter sequence's store and call the
document's functions. They get the scope's tracked world. Hosts (the CLI's
diagnostics and dependencies, `kit/diagnostics.mbt`, `doc`'s review) keep
their own `&World`.

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
data and index).

**Scopes.** A scope is a stretch of work in which one world is fixed and
during which results may be looked up: a compilation (`compile_with`,
through `with_layout_memo`), and each evaluation that is not inside one:
`eval_string` and `eval_string_mapped` (`eval/lib.mbt`; the CLI's `eval`
and the field evaluation of `query`), `eval_source` with the root route,
`Document::lower` (`doc/compile.mbt`). Entering a scope takes a new token
from a process-wide counter and starts with an empty table of answers and
an empty log; leaving it, also by an error, restores those of the scope
around it. A compilation inside another (a host function that compiles) is
a scope of its own, with its own world. No store is consulted outside of a
scope: inside a compilation all of them, inside an evaluation the module
store only, as today. (Today the module store is also consulted outside:
`eval_source_memoized` runs for every import, and only an `eval_source`
with the root route advances the epoch that empties it; an evaluated
string that imports does not.)

**The answers of a scope.** Since the world is fixed, the fingerprint of a
read's answer is computed at most once per scope: a table from read to
fingerprint. This is what comemo's accelerator does for the hashes of
validation calls, per tracked reference and until `evict`; the port has no
tracked references and uses the scope.

Worlds whose files change during a scope exist: `doc`'s `SessionWorld`
serves the origin listing, which grows whenever an origin is registered,
also while callbacks are lowered during layout, and markup snippets whose
files come into being then (`Registry::register` and `Registry::snippet`,
`doc/origin.mbt`; their ids are interned from the paths `<edsl-origins>`
and `<edsl-markup-N>`, so Typst code can name them). Such files are
declared by a predicate on file ids that the entry point of a scope takes
(`compile_with` gets a parameter). `doc`'s predicate is by path, not by
what the registry holds at the moment: the project-rooted ids that
`virtual_file` makes in the session's directory for `<edsl-origins>` and
for `<edsl-markup-N>` with any `N`, so that a snippet that does not exist
yet, whose read today falls through to the caller's world, is covered.
The engines of `History::compute` use the scope's predicate. Three rules
follow from it.

- A read of a volatile file is not answered from the table, and it marks
  the log. A memoized call whose part of the log holds the mark is not
  stored, also when it ends with an error that would be kept (a module's);
  the mark survives the deduplication at the end of a call and stays for
  the callers.
- A module entry is not stored for a file that is volatile itself (its
  source is read before the entry's part of the log starts,
  `eval/import.mbt`, `import_file`).
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

**Recording.** One log per scope, like `route_query_log`
(`library/memo.mbt`): a memoized call notes where the log is when it starts;
a tracked method pushes its read (an integer: a tag and the file id, font
index or offset); when the call ends, what was pushed since is
deduplicated, paired with the fingerprints from the table and kept in the
entry, and the log is cut back to the deduplicated reads, which are
thereby the caller's too. A failed read is pushed before it raises.

**On a hit.** An entry is valid for the world if none of its reads is
volatile in this scope and, for each of them, the table's fingerprint is
the entry's. An entry that passed is stamped with the scope's token and its world reads
are not checked again in that scope. The stamp is about the world only: the arguments, the context, the
route and the introspector reads are checked on every lookup, as today.
The reads of a reused entry are pushed to the log, as if the call had run:
the same merge that `note_route_queries` and `IntrospectionRecorder::
merge_into` do today, and what comemo does by emitting validated calls to
the outer constraint.

**Costs.** Not measured: nothing of this exists. Stated so that slice 1
can be held to them. Recording: one push per read; reads are imports and
loads (tens to hundreds per compilation) and font lookups during shaping
(per text run and family). Per entry: a deduplication of what is typically
one to five reads, and as many table lookups. Per hit: the same lookups,
once per entry and scope. Per scope: one fingerprint per file that is read
and whose `Bytes` or revision is new. The probe measured the upper end of
the last item: hashing every file a document read, sources with their
trees, takes 0.9 ms for `showcase.typ` (4 files, 1.4 MB), 3.2 ms for the
deck (47 files, 2.4 MB) and 4.7 ms for the touying document (31 files,
0.8 MB, mostly source trees). With revisions the sources cost that once;
the 2.4 MB of images cost it in every compilation of the deck unless the
file store hands back the `Bytes` it had when a reload gives equal bytes
(a comparison instead of a hash; `kit/files.mbt`, not upstream's, listed
under "not scheduled"). The budget for recording plus validation is 1 % of
a from-scratch compilation and 5 % of a recompilation in which everything
hits; slice 1 measures both (`long.typ`, a touying document) before
anything is kept, and the expectations of section 8 are corrected by what
it finds.

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
  needs an introspector that answers the same forever. Today
  `ElementIntrospector::query` hands out the array it keeps
  (`library/introspector.mbt`), which a caller could change, and a host
  may keep an introspector and use it in a later scope. `query` returns a
  view or a copy before anything is kept (slice 1). An entry keeps the
  introspector alive only for the shortcut; it becomes a serial number of
  the introspector (6.2).
- **Route, context, traced span.** Unchanged: in the key or recorded per
  entry today, and none of it depends on the compilation.
- **Sink.** Replayed as today. What travels in it is not all immutable.
  Diagnostics are objects whose `trace` and `hints` are appended to
  (`@library.trace`, `library/diag.mbt`), and so are the errors that a
  module entry keeps: an import of a file with an error adds a tracepoint
  to the kept error, again on every reuse. Traced values come with a
  `Styles` that `@typst.trace` hands to its caller and `Styles::unset` can
  change. The rule of 5.4 for mutable results applies to the sink and to
  kept errors.
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
by the fingerprint of its source, not by its text (today: text).

**Locations.** A location is a hash of the locator and the element. The
resolved locator is in the key of every layout entry, so a reused frame
holds the locations a fresh layout would compute.

**Modules.** Typst compares modules by identity. Today a compilation has
one module object per evaluated file, so for these modules an equal
fingerprint is the same object (`ModuleInner.identified`). Across
compilations that is false: a file whose text changed in a comment is
evaluated again and gives a module with the old fingerprint, while a kept
closure call that returned the old module is reused, and `==` between the
two is `false` where a from-scratch compilation has one object and says
`true`. Upstream has this: its memoization compares hashes, its modules
compare by pointer. The port cannot intern the modules (no weak
references: the table would keep every version of the main file's content)
and does not copy the quirk. Two identified modules are equal if they are
the same object, or if their names and fingerprints are equal and, where
the fingerprints carry `fingerprint_identity`, they visit the same host
functions and unidentified modules, as objects, in the same order (the
comparison that `IntrospectionRecorder::validate` makes for the results of
reads, `fingerprint_output_hosts`). That is the relation the stores
already use: a closure that captured one of two such modules has the hash
of the one that captured the other (`closures_equal`), so whatever the
fingerprint does not tell apart is one value for every kept call, and `==`
must not tell it apart either. A relation that compares what the modules
hold with Typst's `==` instead does not do that: a module that exports
`float.nan` would differ from its own re-evaluation, and a function that
returns the module it captured would then return one that is unequal to
the current one (review 3, finding 2). The fingerprint has the float's
bits, ends on cycles and is kept with the module.

For this the fingerprint must tell apart what `==` tells apart inside a
module. One thing it does not, today and within one compilation: native
functions, elements and types compare by their descriptor object
(`library/func.mbt`, `library/element.mbt`, `library/ty.mbt`) and
fingerprint by name, title and documentation, by key, by long name
(`library/value_hash.mbt`). Two native functions that a host makes with the
same texts are one argument for every memoized call, and a closure that
captured a module holding the one is found for the module holding the
other (review 3, finding 3). Upstream hashes the descriptor's address
(`typst-utils/src/static.rs:32`, `Hash for Static`). A descriptor gets a
process-wide number when it is made, and that number is its fingerprint.
(Tests that pin the fingerprint of a value that holds a descriptor change.)

Then two objects for one evaluated file are indistinguishable. This
changes `==` from the
moment it is merged, in every compilation, wherever two such objects with
equal contents meet. In a from-scratch compilation that is: a file that
is evaluated twice (under IDE tracing a file that holds the traced span is
evaluated again for an evaluated string, `ModuleInner`'s doc comment), and
the modules of two libraries that a host brings into one evaluation (each
`Library` builds its own `math`, `calc`, `sys`). Upstream says `false` in
both, the port then `true` if what they hold is equal.

The modules of plugins become identified in all cases. Today one without
functions is not (`Plugin::into_module`, `library/plugin.mbt`): its
fingerprint is that of an empty scope, and it compares by identity, which
only works while the cache of loaded plugins lives exactly as long as
everything that holds its modules. A plugin's module gets the hash of the
plugin's bytes (and of its transitions) in its fingerprint; two loads of
the same bytes in the same state are then equal and others are not, with
and without functions, which is what upstream's `==` says for them in a
from-scratch compilation.

**Equality by content, or identity kept.** Both ways, costed.

(a) *By content*, as above. It differs from upstream where a compilation
from scratch holds two module objects with equal contents. No document that
the command line compiles does: a file has one module there (a second
evaluation needs another answer of the route or of the traced span, and
there is no traced span), and `sys.inputs` holds strings. The two cases
need a host. One document for the first, a line for the second:

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

| how `r` is obtained | upstream | port today | port with (a) |
| --- | --- | --- | --- |
| the command line (`typst query main.typ "<r>" --field value`, with `#metadata(r) <r>` for the last line) | `true` | `true` | `true` |
| `trace` at the last `r` of `main.typ` | `true` | `true` | `true` |
| `trace` at the `v` of `probe`'s body: `a.typ` holds the traced span and is evaluated once with it and once, for the string, without | `false` | `false` | `true` |
| two libraries | `false` | `false` | `true` |

Upstream's column is a throwaway program on the oracle's dependencies that
calls `typst::trace` with a world in memory, the port's a throwaway test
beside `typst/memo_trace_wbtest.mbt`; neither is in the repository. The
last column is not run, (a) does not exist: it is what the rule gives (the
two modules of `a.typ` bind `probe` to closures with one hash; the two
`math` modules bind the same native functions and symbols, which are one
object each in a process, `library/funcs_gen.mbt`). Review 3 looked for a
document that the command line compiles with two such modules (a file
under two routes, `include`, a package under two names, `eval` with a
scope, `plugin`, `std` and `math` reached two ways, a file that fails) and
found none (its finding 11).

(b) *Identity kept.* A module entry that is valid hands out the object it
has; a file that is evaluated again gets a new object, also when what it
holds is equal. Upstream's `==` then holds in every compilation from
scratch. To be sound across compilations it needs three things.

- The new object must not be taken for the old one by a key. Today it is:
  a closure that captured the old module and one that captured the new
  have one hash (`closures_equal`, `library/value_hash.mbt`), so a kept
  call of the first is found for the second and returns what holds the old
  object. The module's identity has to enter what makes two keys
  interchangeable. That can be its fingerprint (a number per evaluation,
  against the rule that a fingerprint covers what upstream's `Hash`
  covers), a second component of every key beside the fingerprint, or a
  comparison of closures by what they captured instead of by their hash
  (a walk of the captured scopes on every lookup).
- The producer of an identity must live as long as anything that holds
  the identity is found: the module entry of that source in that state,
  and for a plugin's module the entry of its load or transition. Otherwise
  the file is evaluated again next to a kept holder of the old object,
  which is the shape of review 1, finding 4. A hit has to renew exactly
  those entries, and the limit of four entries per key must not push them
  out.
- Hits. After an edit that leaves a file's module equal (a comment, white
  space), everything that holds the module as a value misses once. With
  `#import "utils.typ"` and `utils.f(..)`, which is how touying's files use
  each other, that is every closure of every importing file. A proxy for
  it, with the probe: an edit of `touying/0.8.0/src/utils.typ` that
  changes the module's fingerprint and none of its bindings (text appended
  to the file, which also changes what an `include` of it would give;
  nothing includes it). The touying document then recompiles in 137 ms,
  with 3171 closure calls and all 19 paragraphs computed again, against
  34 ms and 18 calls for a comment in the same file when closures that
  captured equal modules are equal (which is today's comparison and
  (a)'s). From scratch it is 155 ms. It is the probe's number, with what
  the probe leaves out (section 8), and no implementation of (b).

The recommendation is (a). It differs from upstream in two cases that need
a host and in no document the command line compiles. (b) buys agreement in
those two cases with keys that carry module identities, a rule between
stores, and a recompilation close to from scratch after a comment in a
shared file of a package.

**What compares by identity.** By Typst's `==` (`library/ops.mbt`,
`library/func.mbt`, `library/dyn.mbt`; the inventory is in review 2,
finding 11): native functions, element functions and types, by their
descriptor; host functions; modules that are not identified. Everything
else compares by value (closures by their hash, plugins by their bytes and
transitions), or is never equal (styles, gradients, tilings). Descriptors
are objects of the process: the generated ones are made once, on first use,
and shared by every library (`library/funcs_gen.mbt`,
`library/types_gen.mbt`; the tables of `library/html_typed.mbt`,
`library/accent.mbt`, `library/lr.mbt`), and a host can make more
(`NativeFuncData::new`, the constructors of types and elements). With
their number as their fingerprint (above) they need no flag: equal
fingerprints are the same descriptor. What is left that compares by
identity and that a fingerprint does not identify is what a host brings:
host functions and modules it builds. Their fingerprints carry
`fingerprint_identity`. Such a value can enter a kept result, which
includes its sink (traced values) and its kept errors, in five ways, and
each is closed:

- from an argument, a captured variable or the context of the call: the
  key carries the flag, and an entry whose key carries it ends with its
  compilation (new: it could only be found again by the same objects, which
  `doc` makes per compilation, `Session.hosts`);
- from an introspector read: the read is marked (`reads.lossy`) and the
  entry is only valid for the introspector it was computed with (as
  today);
- from the library's scope: the library is in the key;
- from a frame's tags: such a frame is not kept (`frame_cacheable`, as
  today);
- made by a host function during the call: one that is reached through a
  value is in the key, with the flag; one that the library defines must
  not make one per call (the contract of 5.2).

The engine's own functions create none. This is an invariant, not
something an entry checks when it is stored (that would fingerprint every
result); the checked mode of 9.1 checks it.

**Mutable results.** The rule: what an entry keeps and what it hands out
are different objects wherever the type can be written, on storing and on
every hit. As today: frames are cloned (copy on write), values are marked
shared. New, each a copy or a read-only view: diagnostics, in sinks and in
kept errors, with their `trace` and `hints`; the `Styles` of traced
values; a kept document, with its pages' frames, its `DocumentInfo` (whose
`author` and `keywords` are arrays) and its format options (it shares only
its introspector, whose answers are views, 5.3); `Works`, whose accessors
return its arrays today (`library/bibliography.mbt`); the `HintedError`
that the plugin caches keep and raise again (`library/plugin.mbt`). The
introspections of a sink hold closures over selectors and locations, which
nothing writes.

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
| capture table (`eval/captures.mbt`) | per compilation | per compilation (5.4) |
| world answers, log (new) | | per scope |
| shape plans, rustybuzz faces, overhang tables, `font_data_hashes`, glyph outlines, bitmaps, colour glyph frames, and the instances a font keeps of itself (`OtfFontFace.instances`, `library/font.mbt`) | process or font object, by font, glyph, variation coordinates, shaping features; nothing ever drops them, `evict` included | registered with `evict`: dropped by `evict(0)`, otherwise kept. They grow with the fonts, glyphs, variation coordinates and feature sets a session has used, not with its edits; a document that animates a variation axis, or a host that replaces font data, frees them with `evict(0)` |
| numbering patterns | process, by pattern string | aged |
| raw syntaxes and themes, bibliographies, CSL styles, PDF documents, plugins and their calls | dropped as a whole every `max_age`-th `evict` | aged per entry |
| decoded raster and SVG images, highlighted raw text (section 8, slice 0) | not kept | aged per entry |
| CLI `ExportCache` | per watch session | unchanged |

Their sizes were not measured. The smallest experiment: print the number
of entries of each after `longer.typ` and after the `packages` stage.

## 7. The process boundary

- **`typst watch`** (`cli/watch.mbt`): one process, one `SystemWorld`, one
  `Library`. Everything above applies; the loop already calls
  `world.reset()` before and `@library.evict(10)` after a recompilation.
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
  they give the same answers, as with comemo.
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
  own.

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

### Slice 1: the tracked world, and the existing stores kept

One slice because nothing may be kept before all of it is there. Five
steps, each merged on its own; results cannot become stale before step 5.

1. **Scopes and recording.** Scopes (5.2) at every entry point, replacing
   `compilation_epoch` and `note_evaluation`; `TrackedWorld` in the engine
   and in what carries a world (5.2); the log, the answers of a scope, the
   reads in every entry of `memoize`, `memoized_closure` and
   `eval_source_memoized`, validated on a hit (true while stores die with
   their compilation); volatile files, declared by `doc`, whose readers
   are not stored: this part changes behaviour at once, for a `doc`
   document that reads its own virtual files. Files:
   `library/engine.mbt`, `library/memo.mbt`, the call sites and carriers of
   5.2, `eval/import.mbt`, `eval/lib.mbt`, `typst/lib.mbt`,
   `doc/compile.mbt`. Measured here: the overhead against the budget of
   5.2.
2. **State outside the arguments** (5.5): the raw element's derived data,
   if slice 0b has not done it; `Works::generate` as an entry of `memoize`;
   the linked images in an SVG image's fingerprint and equality.
3. **Sources.** Persistent edits in `syntax/reparser.mbt`,
   `syntax/node.mbt` and `syntax/source.mbt`, the revision, the fingerprint
   of a source. Module evaluations keyed by the source's fingerprint and
   valid by their world reads instead of by world identity and text; the
   main file through the same store (`typst/lib.mbt`); the library made
   only by its builder, immutable, with its serial number in every key
   (5.3).
4. **Identity and ownership.** Descriptors fingerprinted by their number;
   plugin modules identified by their bytes; module equality (5.4; this
   step changes `==` where two modules with equal contents meet, in every
   compilation); entries whose key carries
   `fingerprint_identity` end with their compilation; the introspector's
   `query` returns a view or a copy, and its serial number replaces the
   object in entries; the copies and views of 5.4's rule for mutable
   results.
5. **Ages.** `evict` as in 6.1; the stores stop clearing themselves, one
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
  has one tracepoint each time (5.3);
- a compilation inside a host function, on another world with the same
  sources and other data files, and the same that fails with an error:
  each world gets its own answers, also afterwards (5.2);
- `eval_string` outside of a compilation, twice, with a data file changed
  in between that an imported module reads (5.2);
- a module that holds a plugin's module without functions, kept in use
  while the plugin's own cache entry ages out, then compared with a new
  load (5.4);
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
  the imported file changes (5.4);
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
| 13 | modules compare by identity | a comment-only edit of an imported file; the main file's `get() = m` returns the module it captured, and the page shows `get() == m` (a module passed as an argument proves nothing: it misses under identity) |
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
  flagged (host functions and unidentified modules as objects): the
  result, by kind: a value; frames; a module (5.4's relation: with stores
  off its imports are new objects); pages and a document with their
  frames, info and options; works with their maps and errors; a counter
  sequence. The sink: diagnostics with spans, hints and traces, traced
  values and styles. Introspections are closures and cannot be compared:
  their number is. Shared flags of arrays and dictionaries are not part
  of it.
- The invariant of 5.4, by reachability: every host function and
  unidentified module in the kept result is, as an object, reachable from
  the key, from the library, or from the result of one of the entry's
  introspector reads.

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
   context) is not justified by a measurement yet.
2. **The traced span is in the keys of closure calls and layouts**
   (upstream tracks `Traced::get`). Only IDE tracing sees it.
3. **Arguments are also compared exactly** (`values_memo_equal`), not only
   by fingerprint, and are therefore kept. Reason: host closures and
   unidentified modules compare by identity. 6.2 has the cost.
4. **At most four entries per key.**
5. **Errors are not kept** by `memoize` and `memoized_closure` (upstream
   caches a `SourceResult`); module evaluations keep theirs.
6. **Results that hold identity-compared values are not kept** (frames,
   introspector reads), entries keyed by them end with their compilation,
   the state sequence is not memoized.
7. **The library is identified by a serial number**, not by its hash.
8. **The answers of the world are kept per scope**, comemo's accelerator
   per tracked reference and until `evict`. Same observable behaviour
   under the same contract. A world may declare files that change during a
   scope, which comemo's contract does not allow.
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
    fingerprinted by a number given when they are made** (5.4); upstream
    hashes their address. Today's port fingerprints their texts.
11. **Looser than upstream: the modules of files, plugins and libraries
    compare by their fingerprints** (5.4). Differs from upstream in a
    from-scratch compilation where two such objects with equal contents
    meet: a file evaluated twice under IDE tracing, modules of two
    libraries in one evaluation.
12. **An SVG image's fingerprint and equality include the images it links**
    (5.5); upstream's cover its bytes and fonts.
13. **Not memoized**: the rows of section 4 that say so.
14. **One thread**: upstream lays out page runs in parallel.

Upstream quirks the port does not reproduce:

- Two values with one hash are one argument for comemo: two plugins without
  functions (`library/memo.mbt`, header; with 5.4 they are distinguished
  by their bytes), and in general anything whose `Hash` is coarser than its
  `==`.
- A module that a kept result returns and the module of the same file
  evaluated again are different objects and compare unequal (deviation 11).
- comemo keeps a result whose constraint is satisfied even if the nested
  results it was built from were evicted and recomputed as other objects.
  The port has the same structure; it is harmless here because nothing
  that is made during a compilation and kept compares by identity (5.4).
- A value built from a file whose hash does not cover the file is reused
  by a memoized call that is handed it again after the file changed (an
  SVG's linked images, deviation 12).

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

Leaning towards "accepted" by the coordinator; the owner may overrule:

1. **Module equality by content** (deviation 11). 5.4 costs it against
   keeping identity and recommends it: it differs from upstream in two
   cases that need a host and in no document the command line compiles;
   keeping identity costs a fingerprint that is not upstream's, a rule
   between stores, and 137 ms instead of 34 ms after a comment in a shared
   file of touying. If it is overruled, the harness cannot require
   equality with a compilation from scratch for documents that compare
   modules, or (b) of 5.4 is built.
2. **The public surface.** `compile_with` gets a parameter for volatile
   files, `Library` stops being a record that hosts can build or update,
   and `Introspector::query` returns a view. `doc` and other hosts see all
   three. In a minor version?

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
