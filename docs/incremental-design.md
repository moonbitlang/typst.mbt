# Incremental compilation: design

Status: design, not implemented. Revision 1 (2026-10-07), upstream
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
  155 ms to 24 ms. What they need to be sound across compilations is one thing the
  port does not have: a record of what each result read from the world.
- Three functions that upstream memoizes and the port does not are worth
  more than that on documents with images or code, and they help the first
  compilation too: decoding a raster image (71 % of a deck with 28 PNGs),
  highlighting raw text (half of what is left of `showcase.typ`),
  converting an image for the PDF (97 % of what is left of the deck).
- Then the block level of the flow (`layout_single_impl`,
  `layout_multi_impl`): `long.typ` 92 ms to 56 ms. The page run and the
  document only pay for a compilation in which nothing changed.
- What is left after all of it is the document-level realization, the flow
  around the cached blocks, and the PDF writer, 1.6 to 2.6 and 3.1 to 4
  times upstream's: after an edit at the end of `long.typ` the port would take
  57 ms where upstream takes 23 ms. That ratio is the one-shot ratio of the
  two programs; closing it is not incremental compilation.
- The design mirrors comemo: results are found by a fingerprint of their
  hashed arguments, are valid if the tracked arguments answer the recorded
  questions as before, age by one with every `evict` and are dropped at
  `max_age`. Where the port deviates (section 10) it is stricter, with one
  exception that is said there (equality of the modules of files).

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
- Only hashes are kept of arguments and of return values. Two arguments
  with one hash are one argument.
- `Tracked::call` asks an accelerator first: per tracked reference a map
  from the hash of a call to the hash of its result, so a call is made once
  per reference (`accelerate.rs`). `evict` clears the accelerators.
- `comemo::evict(max_age)` adds one to the age of every entry and removes
  those above `max_age`; a hit sets the age to zero (`CacheData::evict`,
  `lookup`). `typst watch` calls `comemo::evict(10)` after every
  recompilation (`typst-cli/src/watch.rs:83`).
- The tracked world is `library`, `book`, `main`, `source(id)`,
  `file(id)`, `font(index)`, `today(offset)`
  (`typst-library/src/lib.rs:62`). Every memoized function of the compiler
  also takes `library: &LazyHash<Library>` as a hashed argument.
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
  `syntax/reparser.mbt`) change the tree in place: `SyntaxNode::
  replace_children` and `update_parent` (`syntax/node.mbt`) change the
  children, lengths and numbering bounds of the nodes on the path from the
  root to the edit, `InnerNode::numberize` renumbers the siblings in the
  range it had to widen, and a failed incremental reparse overwrites the
  root's data. A closure holds the node of its body (`Closure.node`,
  `library/func.mbt`). So, unlike upstream, a closure of the previous
  compilation whose body contains or adjoins the edit sees its tree change
  under it (section 5.4).
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
   paragraphs: a factor of 2.4 (`long.typ`, `longer.typ`), 3 to 5
   (handbook, `showcase.typ`), 5 to 6 (touying) after a small edit. Nothing
   is gained when an edit reaches everything (the deck's theme value, the
   package edits): then the work is the work.
2. Three missing functions dominate documents with images or code, in a
   first compilation too: decoding (the deck 2.6 times faster,
   `showcase.typ` 1.4 times, at once), highlighting (`showcase.typ` 71 ms
   to 50 ms per recompilation, the handbook 92 ms to 74 ms), the PDF's
   images (290 ms of every compilation of the deck).
3. The block level is the next step everywhere: 35 to 40 % of what is left
   of the bench documents, 10 to 25 % of the others.
4. Page runs and the document pay when nothing changed (a file saved
   without a change, a comment, a bibliography entry that is not cited) and
   for decks, where a run is a slide: the touying document 13 ms to 7 ms
   unchanged, 18 ms to 17 ms after an edit. Hashing the children for the
   key costs 4 to 5 ms per iteration of `longer.typ`.
5. What is then left is not memoization: the document-level realization
   (which upstream repeats too), the flow, and the PDF writer, 1.6 to 2.6
   and 3.1 to 4 times upstream's.

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
| `layout_document_impl`, `layout_document_for_bundle_impl` | library, content, styles (, locator) | W I T S R | not memoized (`layout/pages.mbt`) | only when nothing changed |
| `layout_page_run_impl` | library, children, initial styles | W I T S R L | not memoized (`layout/pages_run.mbt`) | decks (a run per slide); else only when nothing changed |
| `layout_fragment_impl` | library, content, styles, regions, column | W I T S R L | `memoized_layout`, per compilation; key also has the resolved locator and the whole route | yes |
| `layout_single_impl`, `layout_multi_impl` | library, block, styles, region(s) | W I T S R L | not memoized (`layout/flow_collect.mbt`) | yes: 40 % of what is left of `long.typ` |
| `layout_par_impl` | library, par, styles, region, expand, situation | W I T S R L | `memoized_layout`, per compilation | yes |
| counter `sequence_impl` | library, counter, selector | W I T S R | `memoize`, per compilation | small |
| state `sequence_impl` | library, state | W I T S R | not memoized, on purpose: its values may hold what compares by identity (`library/memo.mbt`, header) | not measured |
| `html_document_impl`, `html_document_for_bundle_impl`, `html_block_fragment_impl` | as the paged ones | W I T S R (L) | not memoized (`html/`) | not measured (no HTML document here) |
| `bundle_impl`, bundle `export_pdf`/`png`/`svg`/`html` | bundle parts | W I T S R / none | not memoized (`bundle/`) | not measured |
| `Image::new_impl`, `RasterImage::new_impl` | kind, alt, scaling / data, format, icc | none | not memoized: `RasterImage::new` decodes on every layout of the image (`library/image_raster.mbt`) | yes: 71 % of the deck, 73 % of `showcase.typ` |
| `SvgImage::new`, `SvgImage::with_fonts_images` | data (, families, file) | none / W | not memoized (`library/image_svg.mbt`) | not visible in `showcase.typ` (one small SVG) |
| `PdfDocument::new`, `PdfImage::new` | data / document, page | none | decode cache (`pdf_document_cache`) / cheap | no |
| `Packed<RawElem>::highlight` | element, styles | none | not memoized (`library/text_raw.mbt`, `raw_elem_synthesize`) | yes: half of what is left of `showcase.typ`, a fifth of the handbook |
| `RawSyntax::decode`, `RawTheme::decode` | bytes | none | decode caches | no |
| `Bibliography::decode`, `CslStyle::from_data`, `from_archived`, `Works::generate_impl` | data / style / elements | none / W I T S R | decode caches; `works_cache` keeps the last introspector's works | not visible |
| `Plugin::call`, `transition`, `module` | plugin, arguments / bytes | none | decode caches (`library/plugin.mbt`) | not measured |
| `Font::instantiate`, `instantiate_impl`, `glyph_frame`, `font_overhang_table`, `create_shape_plan` | font (, variations, glyph, shaping key) | none | process caches | already there |
| math `GlyphFragment::planned`, `base` | world reads, styles, text | W | not memoized (`layout/math_glyph.mbt`) | not visible (equations are 19 % of what is left of `long.typ`, all of it removed by the block level) |
| `TextItem::bbox`, `determine_prefix_widths`, `process_stops`, `Bytes::lines`, `localized_str`, `parse_language_bundle`, `CslStyle::input` | their arguments | none | not memoized | not visible |
| typst-pdf `convert_raster`, `build_font`, `convert_pdf` | image / font | none | not memoized: per export, and `convert_raster` per occurrence of an image (`pdf/image.mbt`, `handle_image`) | yes: 97 % of what is left of the deck |
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
| the date | `World::today(offset)` | recorded read, fingerprint of the date |
| `sys.inputs`, features, formats: the library | `World::library()`, once per compilation (`typst/lib.mbt`, `compile_with`); then `Engine.library` | the library is part of every key (5.3) |
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
- `Today(offset)`: the date or its absence.

**The hooks.** `Engine.world` becomes a `TrackedWorld`: a struct with one
private field, the `&World`, and the five methods; `library` and `main` are
not among them. Engine code cannot reach the world another way (as
`Context`'s fields are private today). That is every engine read of
today's code:

| read | where |
| --- | --- |
| `source` | `eval/import.mbt` `import_file`; `library/decimal.mbt` `warn_on_float_literal`; `library/engine.mbt` `world_range` (called for tracepoints in `eval/call.mbt`, `eval/import.mbt`, `library/styles.mbt`, `library/grid_resolve.mbt`) |
| `file` | `eval/import.mbt` `resolve_package`; `library/loading.mbt` `DataSource::load` (every loading function and element: `read`, `json`, `image`, `bibliography`, raw syntaxes and themes, plugins, ...); `library/pdf_standard.mbt` (attachments); `library/image_svg.mbt` (linked images) |
| `book`, `font` | `layout/inline_shaping.mbt` (four places), `layout/inline_line.mbt`, `layout/math.mbt`; `library/image_svg.mbt`; `library/text.mbt` `check_font_list` (book) |
| `today` | `library/datetime.mbt` |

Not tracked, because they are outside of every memoized call, as upstream:
`compile_impl` and `hint_invalid_main_file` (`main`, the main source),
`compile_with` and `@library.analyze` (`library`). Hosts (the CLI's
diagnostics and dependencies, `kit/diagnostics.mbt`, `doc`'s review) keep
their own `&World`.

**The answers of a compilation.** A world does not change during a
compilation (`World`'s contract, which today's memoization relies on too).
So the fingerprint of a read's answer is computed at most once per
compilation: a table from read to fingerprint, emptied when a compilation
starts (`with_layout_memo` at depth zero, and `note_evaluation` outside of
one). This is comemo's accelerator with the lifetime the port can state.

**Recording.** One log for the thread of control, like `route_query_log`
(`library/memo.mbt`): a memoized call notes where the log is when it starts;
a tracked method pushes its read (an integer: a tag and the file id, font
index or offset); when the call ends, what was pushed since is
deduplicated, paired with the fingerprints from the table and kept in the
entry, and the log is cut back to the deduplicated reads, which are
thereby the caller's too. A failed read is pushed before it raises. A
compilation inside another (`compilation_depth`) has a log and a table of
its own, as an evaluated string has a traced-file log of its own today
(`own_traced_begin`).

**On a hit.** An entry is valid if, for each of its reads, the table's
fingerprint is the entry's. A valid entry is stamped with the compilation
epoch and not checked again in that compilation. Its reads are pushed to
the log, as if the call had run: the same merge that `note_route_queries`
and `IntrospectionRecorder::merge_into` do today, and what comemo does by
emitting validated calls to the outer sink.

**Costs.** Not measured: nothing of this exists. Stated so that slice 1
can be held to them. Recording: one push per read; reads are imports and
loads (tens to hundreds per compilation) and font lookups during shaping
(per text run and family). Per entry: a deduplication of what is typically
one to five reads, and as many table lookups. Per hit: the same lookups,
once per entry and compilation. Per compilation: one fingerprint per file
that is read and whose `Bytes` or revision is new. The probe measured the
upper end of the last item: hashing every file a document read, sources
with their trees, takes 0.9 ms for `showcase.typ` (4 files, 1.4 MB), 3.2 ms for the
deck (47 files, 2.4 MB) and 4.7 ms for the touying document (31 files,
0.8 MB, mostly source trees). With revisions the sources cost that once;
the 2.4 MB of images cost it in every compilation of the deck unless the
file store hands back the `Bytes` it had when a reload gives equal bytes
(a comparison instead of a hash; `kit/files.mbt`, not upstream's, listed
under "not scheduled"). The budget for recording plus
validation is 1 % of a from-scratch compilation and 5 % of a recompilation
in which everything hits; slice 1 measures both (`long.typ`, a touying
document) before anything is kept.

### 5.3 The other inputs of a kept result

- **Library.** Upstream hashes it into every key. The port gives a
  `Library` a serial number when it is built and writes it into every key.
  Two libraries with equal contents do not share results; a host that wants
  reuse keeps its library, as the CLI does.
- **Introspector.** Unchanged: the recorded reads are replayed on the
  introspector of the call (`IntrospectionRecorder::validate`), with the
  shortcut for the introspector the entry was computed with. Across
  compilations the shortcut applies when the document is reused, since the
  next iteration then runs on the same introspector object. An entry keeps
  that introspector alive only for the shortcut; it becomes a serial number
  of the introspector (6.2).
- **Route, context, traced span, sink.** Unchanged: all of it is in the key
  or recorded per entry today, and none of it depends on the compilation.
- **Locator.** In the key, fully resolved (stricter than upstream's tracked
  locator; section 10).

### 5.4 Identity, spans, locations

**Syntax trees.** An edit must not change a node that a kept value holds.
Today it does (section 2). Two things would then be wrong: the capture
table would hand the old analysis and node fingerprint to a closure made
from a node that has changed (the table is by node identity), and a closure
of the previous compilation would run a body that its cached fingerprint no
longer describes. The design makes edits persistent, which is what
`Arc::make_mut` gives upstream: `reparse` copies each node it is about to
change (the inner nodes on the path from the root to the edit, and the
siblings it renumbers) and `Source::edit` installs the new root. A node
that the engine has seen is then never written again; a closure keeps the
tree it was made from, and its fingerprint stays that tree's. The cost is
the copied path per edit of a file. The capture table stays per
compilation; with persistent trees it could be kept longer, which is not
proposed before it is measured (it is part of "eval" in section 3.3).

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
closure call that returned the old module (not as an argument: arguments
are compared exactly) is reused, and `==` between the two is `false` where
a from-scratch compilation has one object and says `true`. Upstream has
this: its memoization compares hashes, its modules compare by pointer.
The port cannot intern the modules (no weak references: the table would
keep every version of the main file's content) and does not copy the quirk.
The equality of two identified modules becomes: the same object, or equal
names and equal fingerprints. Then two objects for one evaluated file are
indistinguishable, in any compilation. What differs from upstream is the
one case where upstream's from-scratch compilation has two such objects:
under IDE tracing, a file that holds the traced span is evaluated again
for an evaluated string (`ModuleInner`'s doc comment), and `==` between
those two is `false` upstream and `true` here.

Modules that are not identified (anonymous ones, a plugin without
functions, what an embedder builds) and host closures compare by identity
and their fingerprints carry `fingerprint_identity`. Rules, the first two
as today: a frame whose tags hold one is not kept (`frame_cacheable`); an
introspector read whose result holds one is not validated against another
introspector (`reads.lossy`); and, new, an entry whose key carries the flag
is dropped when its compilation ends. It could only be found again by the
same objects, which `doc` makes per compilation (`Session.hosts`), and
until then it would keep them alive.

**Mutable results.** As today: frames are cloned (copy on write), values
are marked shared, the document of a kept layout is copied before it is
handed out (its `DocumentInfo` is a mutable object).

## 6. Lifetime and memory

### 6.1 Ages

comemo's rule. Every entry of every store has an age. `@library.evict
(max_age)` adds one to each and drops those above `max_age`; a hit sets the
age to zero. A compilation no longer clears anything; a process that never
calls `evict` keeps everything, as a process using comemo does, and
`evict(0)` drops everything. `typst watch` calls `evict(10)` after each
recompilation, where it calls it today. Four entries per key stay the
limit (`memo_max_entries`, first in, first out): comemo's tree has no such
limit, and none of the measured documents reaches it.

The stores register themselves with `evict` (comemo's `register_evictor`):
modules, closure calls, layouts, counter sequences, the new ones of
section 8, and the decode caches that are dropped as a whole today, which
get ages like the rest (a syntax or bibliography that is still in use is
then not decoded again every tenth compilation). Entries of the kept
tables that are derived from keys (fingerprints of sources by revision, of
bytes by file id) are dropped when the thing they describe is.

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
  arguments). Measured by finding
  layout entries by their key alone: the stores of `long.typ` shrink from
  20.3 to 19.4 MB, of `longer.typ` from 101.4 to 96.6 MB. Five per cent:
  the exact comparison stays.
- the introspector of its compilation and iteration (`MemoEntry.backend`,
  `ClosureEntry.backend`), which holds every located element and position
  of a document. Kept across compilations that is up to `max_age` times
  the iterations. The entry keeps a serial number of the introspector
  instead; the shortcut compares numbers.
- its introspector reads with their replay closures, its world reads, its
  sink: small.

The bound is not a number of bytes but comemo's: what the last `max_age`
compilations used. With `max_age` 10 that
is between one and eleven times the stores of one compilation: for
`longer.typ` 116 MB if nothing changes, 170 MB after ten edits at the end,
358 MB after ten edits of every heading (all measured), and about 1.1 GB
if ten edits in a row each changed every paragraph (eleven times 101 MB;
not measured). Upstream's bound has the same shape.

### 6.3 Caches that are not memoized calls

| cache | today | design |
| --- | --- | --- |
| capture table (`eval/captures.mbt`) | per compilation | per compilation (5.4) |
| world answers (new) | | per compilation |
| font book selection, shape plans, rustybuzz faces, overhang tables, font instances, `font_data_hashes` | process, by font | unchanged: bounded by the fonts in use. A world that replaces a font file leaves the old font's entries; a host that does that calls `evict(0)` |
| glyph outlines, bitmaps, colour glyph frames | process, by font and glyph | unchanged, same bound |
| numbering patterns | process, by pattern string | registered with `evict`, aged |
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
  with every distinct compilation; it keeps its `Library` and returns the
  same `Source` object for a file, edited with `Source::replace` or
  `Source::edit`. A host that makes a new `Source` for a changed file gets
  the numbering of a fresh parse, which differs from the old one in most of
  the file: little that came from that file is found again. A world that
  returns the same `Bytes` object for an unchanged file saves its hashing.
  Stores are process-wide, so two worlds in one process share results where
  they give the same answers, as with comemo.
- **`typst compile`**: one compilation, nothing to reuse; slice 0 and the
  block level are what it gets.
- **The EDSL** (`doc`): a script is a process per run, and nothing here
  crosses a process. Within a process, a second compilation of `doc` runs
  in a new `SessionWorld` with new host functions for its callbacks
  (`doc/session.mbt`): results that involve a callback are dropped with
  their compilation (5.4), the rest is reusable where the lowered content
  is equal, which includes its spans (the origin numbering of
  `doc/lower.mbt`). The design does nothing for `doc` beyond not breaking
  it: no persistent cache, no stable identities for callbacks. If a
  long-lived `doc` host appears (a preview server), that is a design of its
  own.

## 8. Slices

The order follows section 3: first what is worth most and needs nothing
new, then the machinery with the stores that exist, then the missing
functions by their measured gain. Every slice ends with the harness of
section 9 green and with its row of section 3.3 measured again; a slice
that does not reach its number within the stated margin is not merged
until it is known why. Expected numbers are the probe's, which validated
less than the design does: a slice may be up to 10 % slower than its row.

### Slice 0: three functions upstream memoizes, by content

No new machinery and nothing kept that depends on the world: each is a
pure function of what is in its key. Each helps a single compilation.

| step | key | files | expected |
| --- | --- | --- | --- |
| 0a `RasterImage::new` (upstream `RasterImage::new_impl`) | the data's hash, kept by the identity of the `Bytes` as `font_data_hash` keeps a font's; format; ICC profile | `library/image_raster.mbt`, `library/memo.mbt` (dropped by `evict` like the decode caches of today until slice 1 gives it ages) | the deck: first compilation 1710 ms to 651 ms, recompilation 1690 ms to 501 ms, heap 461 MB to 101 MB; `showcase.typ`: 345 ms to 245 ms, 268 ms to 71 ms |
| 0b `RawElem::highlight` | the element and the style chain | `library/text_raw.mbt`; first the fix below | `showcase.typ`: recompilation 71 ms to 50 ms; the handbook: 92 ms to 74 ms |
| 0c PDF images: one conversion per image and export instead of one per occurrence, kept between exports by the image (upstream `convert_raster`), the compressed stream kept with it | the raster image, `interpolate` | `pdf/image.mbt`, `pdf/convert.mbt`; `moonbitlang/pdflite` `export` (the image object keeps its encoded stream) | the deck's export, 290 to 305 ms: by the counts of 3.4 a conversion per image instead of per occurrence removes 44 of 72, and keeping them removes the rest; not prototyped |

0b needs a fix that slice 1 needs too. The syntaxes and the theme of a raw
element are not in the element: `raw_elem_syntaxes_parse` and
`raw_elem_theme_parse` load them and file them in two process-wide tables
by their source (`raw_syntaxes_derived`, `raw_theme_derived`), and
`RawSyntax::find` and `RawTheme::derived` look them up by source when the
element is highlighted (`library/text_raw.mbt`). The element's fingerprint
covers a path, not the theme. Within a compilation that is harmless. As
soon as anything keyed by the element or its styles is kept (0b, and every
layout entry of slice 1), a changed theme file gives the old colours. The
element has the fields upstream uses (`raw_elem_syntaxes_derived`,
`raw_elem_theme_derived` in `library/elems_gen.mbt`, unused): the loaded
data goes there, as it does for images and bibliographies, and the two
tables go away.

Risk: memory (decoded pixels of every image of the last `max_age`
compilations: 6.2). Left out: SVG images (`SvgImage::with_fonts_images`
reads fonts and linked files from the world: slice 1), the PDF writer's
own speed.

### Slice 1: the tracked world, and the existing stores kept

One slice because its parts are not sound apart; four steps, each merged
on its own and each a no-op for results until the last.

1. **Recording.** `TrackedWorld` (5.2) replaces `Engine.world`; the log,
   the answers of a compilation, the reads in every entry of `memoize`,
   `memoized_closure` and `eval_source_memoized`, validated on a hit (always
   true while stores die with their compilation). Files:
   `library/engine.mbt`, `library/memo.mbt`, the call sites of 5.2,
   `eval/import.mbt`. Measured here: the overhead against the budget of
   5.2. Checked here: a build flag that makes the harness fail if a kept
   entry has no recorded read for a file its evaluation opened (the world
   wrapper of the harness counts the raw calls).
2. **Sources.** Persistent edits in `syntax/reparser.mbt` and
   `syntax/node.mbt`, the revision in `syntax/source.mbt`, the fingerprint
   of a source in `library`. Module evaluations keyed by the source's
   fingerprint and valid by their world reads instead of by world identity
   and text; the main file through the same store (`typst/lib.mbt`); the
   library's serial number in every key; module equality (5.4); raw
   elements carry their derived data (slice 0b's fix, if 0b is not merged
   yet).
3. **Identity.** Entries whose key carries `fingerprint_identity` are
   dropped when their compilation ends; the introspector's serial number
   replaces the object in entries.
4. **Ages.** `evict` as in 6.1; the stores stop clearing themselves, one
   store per commit in the order modules, closure calls, layouts and
   counter sequences, each with the harness and its numbers.

Expected (the "kept" rows of 3.3): `long.typ` 234 ms to 92 ms after an edit at
the end, `longer.typ` 1247 ms to 507 ms, `showcase.typ` 71 ms (after slice
0a) to 24 ms, the touying document 155 ms to 22 ms, the handbook 93 ms to
30 ms, the deck 501 ms (after slice 0a) to 332 ms.

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
missed in every compilation until entries were found by their keys alone). The comparison gets a real case
for `CellGrid`.

Expected ("+ blocks"): `long.typ` 92 ms to 56 ms, `longer.typ` 507 ms to
313 ms, the touying document 22 ms to 18 ms, the handbook 30 ms to 26 ms.
Risk: low; the machinery is the fragments'. Left out:
the locator as a tracked argument (section 10).

### Slice 3: page runs and the document

`layout_page_run` and `layout_document_common` (and the bundle variant)
through `memoize`, keyed like upstream's `layout_page_run_impl` and
`layout_document_impl`; pages and the document are copied on a hit. Files:
`layout/pages_run.mbt`, `layout/pages.mbt`, `layout/document.mbt`.

Expected ("+ runs, document"): nothing changed: `long.typ` 53 ms to 37 ms,
`longer.typ` 304 ms to 171 ms, the touying document 13 ms to 7 ms; a
bibliography entry that is not cited: the handbook 25 ms to 16 ms; after an
edit of a deck: 18 ms to 17 ms. Risk: low. What it does not buy: anything after an edit
of a document that is one page run.

### Not scheduled

Each needs a document that shows it, then follows the pattern of slice 2:
`eval_string`; `SvgImage::with_fonts_images`; the HTML document and
fragments; the bundle; the state sequence (first the rule under which its
values can be kept); the capture table across compilations; the locator as
a tracked argument; keeping a file's `Bytes` when a reload gives equal
bytes (`kit/files.mbt`). And outside of this design: the speed of the PDF
writer and of realization, which are what is left (3.4).

## 9. Acceptance

### 9.1 Correctness: what the design needs from the harness

The harness (`recompile-harness`, in progress elsewhere) applies seeded
edits to documents in one process and requires each recompilation to equal
a compilation from scratch. For this design it must have:

**Two references.** (a) The same world with every store dropped
(`@library.evict(0)`), compiled again: this compares everything, span
numbers included, since the sources and their edit history are the same.
(b) A new world on the same files: this catches state that survives in the
world or in sources, and must compare spans as file ranges, since a fresh
parse numbers differently.

**What is compared.** Diagnostics (errors and warnings with their spans
resolved to ranges, hints, tracepoints), the frames of every page (the
`paged` stage's dump, with spans), the introspector's answers the export
uses (outline, labels), and the bytes of PDF and SVG.

**Edits.** Text inserted, deleted and replaced at random offsets of the
main file, of imported files and of package files; in code, markup, math,
raw text, comments, closure bodies and next to them; an edit and its
reverse (the text is old, the span numbers are not); several files in one
step; a file rewritten with the same bytes. Files created, deleted,
replaced by a directory: import targets, images, data files, a package
manifest's `entrypoint`. Bytes changed of: an image, a `.bib` file, a CSL
style, a `.tmTheme`, a `.sublime-syntax`, a file read with `read` inside a
function, an image linked from an SVG. The font set (a font added that
shadows a family; one removed), the date, `sys.inputs` (a new library),
the main file. Sequences longer than `max_age + 2`, with `max_age` 0, 1
and 10, and with `evict` not called at all.

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
| 6 | `book` and `font` are not recorded | a font is added that shadows a family in use |
| 7 | the reads of a reused call are not pushed to the log | `read` inside a function called from a kept closure call or module |
| 8 | modules are keyed by text, not by the numbered tree | an edit and its reverse; the diagnostic of a later error must point to the right range |
| 9 | the reparser changes nodes in place | an edit inside and next to a closure body whose closure a kept result holds |
| 10 | the capture table survives a compilation while 9 is on | the same |
| 11 | introspector reads are not validated across compilations | an edit that moves a heading to another page under an outline |
| 12 | the library is not in the key | `sys.inputs` changes |
| 13 | modules compare by identity | a comment-only edit of an imported file whose module the document compares with `==` |
| 14 | the sink of a reused entry is not replayed | a warning inside a kept closure call must be reported by every recompilation |
| 15 | raw elements keep their theme by path | changed bytes of a `.tmTheme` |

**A checked mode.** A build flag under which a hit also runs the function
and compares (fingerprint of the result, sink): comemo's
`debug_assertions` panic for a non-deterministic memoized function has no
equivalent here, and this is the equivalent. The harness runs a subset of
its seeds in it.

### 9.2 Performance

Targets are the probe's rows (3.3) with the 10 % of section 8, and they are
stated against upstream so that they stay meaningful when either program
changes: after slice 3, for every document and edit of section 3, the
recompilation is within 10 % of the last probe column of 3.3, which is
1.3 to 2.7 times upstream's for every edit that changes something, with
the two exceptions explained there (the deck until slice 0c; the
handbook's package edit, where upstream uses its threads). The number to
watch is the ratio: it must not exceed the ratio of the two programs in a
first compilation (2.2 to 2.5 on the bench documents).

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
8. **The answers of the world are kept per compilation**, comemo's
   accelerator per tracked reference and until `evict`. Same observable
   behaviour under the same contract.
9. **Syntax trees are copied where they are edited, always** (upstream:
   where they are shared).
10. **Looser than upstream: the modules of files compare by fingerprint**
    (5.4). Differs from upstream in a from-scratch compilation only under
    IDE tracing.
11. **Not memoized**: the rows of section 4 that say so.
12. **One thread**: upstream lays out page runs in parallel.

Upstream quirks the port does not reproduce:

- Two values with one hash are one argument for comemo: two plugins without
  functions (`library/memo.mbt`, header), and in general anything whose
  `Hash` is coarser than its `==`.
- A module that a kept result returns and the module of the same file
  evaluated again are different objects and compare unequal (deviation 10).
- comemo keeps a result whose constraint is satisfied even if the nested
  results it was built from were evicted and recomputed as other objects;
  the port has the same structure, and it is harmless here only because of
  deviations 6 and 10.

## 11. Open questions

1. Module equality by fingerprint (deviation 10): accepted, or keep
   identity and with it upstream's quirk? The alternative that keeps both
   (interning by fingerprint) needs weak references.
2. `max_age`: upstream's 10, or less for `typst watch` given 6.2?
3. Slice 0c changes `moonbitlang/pdflite`. Is that scheduled with it, or
   does 0c stop at "one conversion per image and export" inside `pdf/`?
4. Persistent edits change a faithfully ported file (`reparser.mbt`). The
   alternative is to keep editing in place and to argue that a changed node
   is never reached from a kept result that is reused (it holds by the
   keys, but nothing checks it). The design prefers the property that can
   be stated locally.
5. Slice 0 does not need the harness. Merge it first?

## Appendix A. The probe

Not in the repository: measurement code that skips validation must not be
one flag away from a release. What it was, so that a number here can be
measured again:

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
