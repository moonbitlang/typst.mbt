# Incremental compilation: design

Status: slice 0, steps 1 and 2 of slice 1 (5.5, "As built") and the
engine half of its step 3 are built (section 8, "Step 3 as built"); the
rest is design.
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
  kept errors. (Kept errors: built in step 3, a module entry keeps a copy
  of its errors and hands out a copy on every hit. The diagnostics and
  traced values of sinks are step 4's.)
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
Step 1 is built.

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
  has one tracepoint each time (5.3; `eval/import_wbtest.mbt`, "the error
  an entry keeps is not the one an import adds its tracepoint to");
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
   caches a `SourceResult`); module evaluations keep theirs, as a copy
   that is copied again for every caller.
6. **Results that hold identity-compared values are not kept** (frames,
   introspector reads), entries keyed by them end with their compilation,
   the state sequence is not memoized.
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
    fingerprinted by a number given when they are made** (5.4); upstream
    hashes their address. Today's port fingerprints their texts.
11. **Looser than upstream: the modules of files, plugins and libraries
    compare by their fingerprints** (5.4). Differs from upstream in a
    from-scratch compilation where two such objects with equal contents
    meet: a file evaluated twice under IDE tracing, modules of two
    libraries in one evaluation.
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
  SVG's linked images, deviation 12). In upstream that call is
  `Image::new_impl` itself, which every image goes through: checked with
  the binary of `e58a63af`, two SVG files of the same bytes next to a red
  and a blue `img.png` are two red squares, as images, as tilings and in
  the PDF.

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
   module.)

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
