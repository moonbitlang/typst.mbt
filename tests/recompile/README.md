# Compiling again

A process that compiles a world again and again (`typst watch`, a preview,
a language server) may keep results of one compilation for the next. The
danger of doing so is a result that is stale and looks right. The
`recompile` stage is the test that must be there before any cache outlives a
compilation: it keeps one world, edits its files again and again, and after
every edit requires what the compilation gave to be exactly what a
compilation from scratch of the same files gives.

Today nothing is kept across compilations (`library/memo.mbt`: the memoized
calls end with their compilation; `@library.evict` drops what is kept by
content), so the stage passes by construction, and a failure is a bug. The
first one of this kind was found by hand: the memo of module evaluations was
found again by world identity and the file's own text, so a module was
reused after a file that it imports had changed (`typst/recompile_wbtest.mbt`).
The stage finds that class mechanically (see "Mutation checks").

## What runs

`tests/runner/recompile_stage.mbt` (the stage), `recompile_world.mbt` (the
world), `recompile_edits.mbt` (the edits), `recompile_compare.mbt` (what is
compared), `recompile_docs.mbt` (the documents); each header says what the
file guarantees.

**The world** is the CLI's: files are kept in `@kit.FileStore`, the store of
`cli/world.mbt` (a port of typst-kit's), over a loader that reads memory
instead of the disk. After an edit the world is reset as `SystemWorld::reset`
does; a file that was a source before is then the same `Source` object with
its text replaced and its tree reparsed in place (`Source::replace`), so
the nodes outside of the reparsed range keep their span numbers. That
matters: span numbers are in the keys of memoized calls and in the hashes of
located elements, and a fresh parse numbers the same text differently.

**A sequence** is a document and a list of edits. It runs in two phases.
First the watch loop, with nothing else in between: compile, and for every
edit change the files, `reset`, compile with the exports, `@library.evict(10)`
(`cli/watch.mbt`). Then, for every step, a fresh world of the files as they
were at that step is compiled twice, as it is and with memoization off, and
both must give what the loop gave (the documents that take long have the
second only). The phases are not interleaved: a cache
that keeps the last compilation only would otherwise never be asked for the
step before, and the stage would pass without testing it.

**The documents** (120 by default):

- 3 of `bench/` (`tiny`, `long`, `showcase`: the documents whose
  recompilation `scripts/watch_check.py --bench` measures; `longer`, which
  is `long` five times, only with `--all`).
- 111 tests of upstream's suite, listed by name in `recompile_docs.mbt`:
  those whose pages are computed from the document (counters, state,
  queries, locations, outline, bibliography and citations, footnotes,
  figures and references, page numbering, `context`, `measure`, `layout`,
  the convergence tests), those that import and include files or a package,
  and those that load data (JSON, CSV, TOML, YAML, XML, CBOR, text, bytes,
  PNG, JPEG, GIF, WebP, SVG with linked images, PDF, pixmaps, syntaxes and
  themes of `raw`, bibliographies, plugins). Some fail on purpose. Tests
  that upstream only evaluates are compiled to pages like the others.
- 3 projects written for this stage (`docs/`), because the suite has no
  document of several files: `book` (a main file that includes chapters,
  which import a shared module, which reads a JSON file; CSV, TOML, YAML,
  text, a bibliography in an author-date style with citations inside
  blocks, images, a syntax and a theme, a file that is read both as a
  module and as text), `chain` (imports in a chain and in a diamond over
  one data file, a function that reads the file when it is called, every
  file a document of its own) and `notes` (pages computed from the
  document, with functions that read the date and `sys.inputs`).
- 3 documents with real packages (`tests/packages/docs`: a touying deck, an
  ilm book with a bibliography, cmarker with its plugin and a Markdown
  file), if `.repos/typst-packages` is there; all 99 with `--all`. They
  have a summary line of their own (`recompile packages`).

**The edits** are seeded (`recompile_edits.mbt`); the files that can be
edited are the main file and every file that a compilation reported as a
dependency, in a package or not.

- The *sweep* changes everything a document depends on once, each with the
  rest as it is: the date and `sys.inputs` (if a file reads them), the
  fonts (the family of the default font goes away for one step), the main
  file, every other file (at most 16; one, and not the fonts, for the
  documents that take long: `bench/long`, `bench/showcase` and those with
  packages), with an edit after which the file is still what its readers
  expect (text inserted, a block added at the end of a paragraph, a digit
  of a number or of a set rule; for data a digit, a letter or the content
  of another file of its kind); a change that breaks the document is
  undone with the next; at the end everything is back to what it was at
  first. A kept result that depends on something its key does not hold is
  found here without luck.
- *Random sequences* (one of 6 edits per document by default): the edits
  above; edits that do not care about syntax (a `#`, a bracket, an unknown
  function, a `panic`, an import of a file that is not there, the letters
  of a string, a range or a line deleted, the file truncated, a byte that
  is not UTF-8, a bit of a binary file flipped); a byte order mark; a file
  removed, and created again; a file back to a content it had (A, B, A);
  the same bytes written again; nothing; two files at once; the date;
  `sys.inputs`; the fonts; another file of the project as the main file,
  and back. What an edit breaks is usually repaired by the next, since a
  project that stays broken tests little.

**What is compared** after every step (`recompile_compare.mbt`): the
dependencies (`FileStore::dependencies`, read before anything else touches
the world: a file that drops out is no longer watched); the errors and
warnings in their order with their hints and tracepoints; the pages in the
`paged` stage's `typst-frame-v1` format (every item, tag and glyph); what
the document's introspector answers (labelled elements, headings, figures,
metadata: their positions, the numbering and supplement of their pages);
the SVG and the PDF, byte for byte; the diagnostics of the PDF export.
Spans are compared as what they point at in the world of their own
compilation (file, line, column, byte range), not as numbers: that is exact
about what a user sees, and a span number that a reparsed source no longer
has is written as unresolved, which differs. Location hashes are compared
as their order of appearance. Besides, the document of every step is
exported once more after the next compilation and must be what it was: a
host may hold a document while it compiles the next.

One kind of step is counted and not compared: a step in which a source was
reparsed into a tree that a parse of its text does not give
(`RecompileWorld::reparsed`; the run says how many there were). Upstream's
reparser has such cases, the port follows it, and the pages of another tree
are not stale pages (see "Findings").

## The reference, and what it cannot see through

A reference is a new world: a new file store (every source parsed from
scratch) and a new library object. It shares with the worlds before it only
what the process shares:

- What `@library.evict` drops: the caches of data decoded from bytes
  (syntaxes and themes of `raw`, bibliographies, CSL styles, the works of a
  document, PDF documents, plugins and the results of their calls), and two
  tables that are found by the *path as written*, not by content
  (`raw_theme_derived`, `raw_syntaxes_derived` in `library/text_raw.mbt`;
  see "Findings"). The stage calls `@library.evict(1)` before every
  reference, so a reference decodes everything again.
- The memoized calls (`layout_store`, the counter sequence, `closure_store`
  in `library/memo.mbt`, the capture analysis of `eval/captures.mbt`) and
  the module evaluations of `eval/import.mbt`. They end with their
  compilation today. The second reference of every step runs with
  memoization off, which does not ask the first four at all; the module
  evaluations are found by world identity, and the world is new.
- The fonts (`Font` objects, shared by all worlds of the runner) and what
  is computed from a font alone: shaping faces and plans
  (`layout/inline_shaping.mbt`), glyph frames, outlines and boxes
  (`library/font_color.mbt`, `svg/text.mbt`), hashes of font data.
- The interned file ids (`syntax/path.mbt`), parsed numbering patterns,
  constant tables that are built on first use, hayagriva's built-in styles
  and locales.

So a reference in the same process is as good as two rules: **a cache that
is added must be off with `set_layout_memo_enabled(false)` or be dropped by
`evict(1)`**. A cache that follows neither could make the watch loop and
both references wrong together. For that there are references in another
process: `--snapshots=DIR` writes the files of every step before it is
compiled and a digest of what it gave, `--replay=<snapshot>` compiles one
snapshot as the first compilation of a process, and
`scripts/recompile_soak.py` compares the two for a few steps of every run.
That check is not in CI (a process per step); run the soak before a cache
lands.

## Running

```sh
moon run tests/runner --target native --release -- recompile [filter] [-v]
python3 scripts/ci/stages.py recompile      # the verdict CI uses
```

The default run is the CI run: 120 documents, 235 sequences (232 and 3 in `scripts/ci/stages.tsv`), 1407
steps and 4199 compilations with their exports, about 35 s on an M-series
machine. `--sequences=N` and `--steps=N` size
the random sequences of every document, `--seed=N` and `--rounds=N` choose
the seeds, `--all` adds `bench/longer` and every document with packages,
`--only=NAME` runs one document, `--list` prints what the first compilation
of every document gives, `--edits` what the kinds of edits did (counted on
the references, not on the watch loop), `--trace` every edit before it
runs.

A failure is one line, and with `-v` the edits up to the failing step and
the first difference:

```
FAIL project/book :: seed=1 sequence=sweep step=17 of 22 (also at 20): frames, svg, pdf differ from a fresh compilation without memoization
```

The seed, the document and the sequence identify it (the same command with
`--only=project/book --seed=1` runs it again); the edits, both sides of
what differs and the edited files of the failing step and the one before
are in `_build/recompile/<document>/seed<N>-sequence-<name>/`.

`scripts/recompile_soak.py --minutes 60` runs seed after seed, one process
per document, with longer random sequences and the references in new
processes. An edit can make the compiler abort where upstream panics
(`#box(inset: (left: 100%), ..)` measured in infinite space is a frame of
infinite size in both), and the runner with it; the script compiles the
snapshot that was being compiled in a new process to tell whether the abort
is about compiling again. (`layout/container.typ` `box-inset-ratio` was in
the list and aborted in this way for a digit of its `range(10)`; it was
replaced.)

## Mutation checks

That the stage catches stale results was shown by putting three bugs in,
one at a time, and running the default stage (seed 1). They are not in the
tree; to repeat one, change the code as said, build the runner in release
and run `recompile -v`.

| Mutation | Failing sequences, of 235 | First at | Seen in |
|---|---|---|---|
| 1. `eval/import.mbt`, `EvalMemos::of`: the entries are not cleared when the epoch changes (the bug that the watch work found) | 17 | step 1 in 13 of them, the first compilation after the first (`project/book`, sweep) | the dependencies in 12 (a module that is found again does not read its files, so they are no longer watched), the diagnostics in 3, the pages in 4 |
| 2. `library/memo.mbt`, `memoize`: the store is not cleared when the generation changes (the layout memo and the counter memo outlive the compilation) | 67 | step 1 in 60 of them (`bench/tiny`, sweep, first) | the pages, in all of them |
| 3. `library/memo.mbt`, `memoized_closure`: the store is not cleared | 13 | step 0 in 6 of them (the first compilation of a document, after other documents), step 1 in 4 | the dependencies in 6 (a function that reads a file is not called again), the pages in 7 |

With the seed that the failure prints, every one of them is repeated by
`recompile --only=<document> --seed=1 -v` on the mutated tree.

What the mutations showed about the stage and about the engine:

- Mutation 1 is found without an edit of the right file: the files that a
  reused module would have read are missing from the dependencies after
  *any* recompilation, also after an edit that changes nothing. Without
  the comparison of the dependencies it is found where a file two imports
  away changes (`suite/scripting/import.typ` `import-nested-item`, the
  projects).
- Mutations 2 and 3 are seen by the reference without memoization only. A
  fresh world with memoization on is served by the same store, which lives
  in the process, and is stale in the same way (in a few sequences it is
  the reference that is wrong, and the watch loop right). That is why
  every step has both references.
- Random edits alone found mutation 2 in 2 of 242 sequences and mutation 3
  mostly through dependencies: an edit of a source changes the content
  that a result is found by. What is stale is a result that depends on
  something that is *not* in its key, and those things have to be changed
  one by one with everything else left alone. That is the sweep. With it
  mutation 2 fails where the date changes (a header that prints
  `datetime.today()` is laid out by a memoized call), where the fonts
  change (nearly every document), and in `project/book` where nothing but
  a syntax definition of `raw` or the bibliography file changes; mutation
  3 fails where the date or `sys.inputs` change (`project/notes`: functions
  without arguments that read them), where the fonts change (a function
  that measures) and where a data file changes that a function reads when
  it is called (`project/chain`, `lookup`).
- So the keys of today's memoized calls do not hold: the date,
  `sys.inputs`, the files that are read during a call, the fonts, and the
  data of `Derived` fields. The last is the port's own: upstream stores the
  decoded data in the field (`Derived<S, D>` is hashed with both parts);
  the port stores the source only and finds the data again by it. An image
  holds its bytes (a change of an image file was never stale), a
  bibliography and the syntaxes and themes of `raw` do not.

## Findings

On `main` (4877742) the stage found one thing, and it is upstream's:

- **Compiling again is not always compiling from scratch, because
  reparsing is not always parsing.** `##let nope #let= 4`, then its first
  character deleted: the source that was edited in place has one error
  more than a parse of the new text ("expected pattern" besides "the
  character `#` is not valid in code"). Upstream does the same: its `typst
  watch` prints both errors after that edit and its `typst compile` one.
  The port follows the reparser (the `reparse` stage compares the two), so
  the stage does not call this a failure: it checks every source of every
  step against a parse (`RecompileWorld::reparsed`), counts the steps
  where they differ and does not compare those. (Found by the soak: seed
  2000, `suite/introspection/locate.typ/locate-between-pages`, the second
  random sequence, after 12 edits.)

Otherwise no step of any sequence differed from its references: the default run, and the
soak runs of `scripts/recompile_soak.py`: an hour on 18 cores (seeds 1000
to 1038 on the 120 documents of the default run with four random sequences
of 12 edits and the sweep each, 4,680 runs, 261,196 steps, 783,588
compilations; seeds 5000 to 5006 on the 99 documents with packages, 693
runs, 15,470 steps, 46,410 compilations), and 18 minutes more with
references in new processes (seeds 2000 to 2004 and 6000 to 6002: 897
runs, 37,578 steps, 112,734 compilations, 2,391 steps compiled again in a
process of their own). 21 runs aborted, and aborted again from scratch: 20
of them were `box-inset-ratio` (see "Running"), one was the PNG below.

Found on the way, not by a step that differs (neither is about compiling
again, and neither is fixed here):

- **A PNG with a damaged header kills the process or is accepted.** The
  PNG reader does not check the checksums of chunks (`codecs/png_decode.mbt`
  says so). With one bit of the width flipped (`flip-bit @16` of a 16 by 16
  image, in the soak) upstream reports `failed to decode image (Format
  error decoding Png: CRC error: ...)`; the port, depending on the bit,
  reports another error, aborts in an allocation or in
  `PngExpander::row`, or compiles the document with the damaged image.
  Reduction: `tests/recompile/docs/book/data/squares.png` with byte 16
  xor `0x04` (abort) or `0x80` (accepted), and `#image("p.png")`.
- **Two files, one relative path, two themes.** `raw_theme_derived` and
  `raw_syntaxes_derived` (`library/text_raw.mbt`) are tables of the
  process that are found by the source *as it was written*. Two files in
  different directories that both say `#set raw(theme: "t.tmTheme")` name
  different files with the same string, and every raw block is highlighted
  with the theme that was parsed last (checked for themes: `a/a.typ` and
  `b/b.typ` with a raw block each, included by `main.typ`: upstream
  colours the number of `a/a.typ` with `a/t.tmTheme`, the port with
  `b/t.tmTheme`). The set rule is evaluated in every compilation, which
  records the theme again, and a reference shows the same pages, so the
  stage cannot see it; it is what its list of process state turned up.
  The fix is to keep the decoded data with the value as upstream does
  (`scripts/typemap.py`: "`Derived<S, D>` casts like its user-visible
  source"), which is not a small change.

And two things that are not bugs today:

- **The CLI's world and upstream's.** `@kit.FileStore` is typst-kit's state
  machine slot for slot (stale sources, byte order marks, invalid UTF-8,
  `reset`, `dependencies`), and `SystemWorld::reset` is upstream's. The
  difference is one level down: upstream's `Source` is copy-on-write
  (`Arc::make_mut` in `Source::replace` and in the reparser), so whoever
  holds a source or a syntax node of the compilation before keeps what it
  held; the port's `Source` and `SyntaxNode` are objects that
  `Source::replace` edits in place (`syntax/source.mbt`,
  `syntax/reparser.mbt`). Nothing reads a node of an earlier compilation
  today. A cache that keeps a closure, a module or content across a reset
  keeps nodes that the next reparse rewrites under it.
- **Aborts.** A document can make the compiler abort where upstream
  panics: `box(inset: (left: 100%), block(width: 10pt))` measured with
  `width: auto` is "frame size must be finite" here and `assertion failed:
  size.is_finite()` there. A watching process dies of it in both.

## What it does not cover

- Only paged documents with their SVG and PDF: not the HTML and bundle
  targets, not PNG, no export options but the document's own.
- The features and the styles of a world's library never change; fonts
  change between two sets only.
- The traced span of the IDE functions (`@typst.trace`).
- Kinds of file errors other than "not found" (a directory, no access),
  files that move, two files with the same text in different directories,
  a package whose manifest names another entry point, dates around
  midnight with offsets.
- Values that print alike and are not alike: elements are compared as
  their `repr`, so a function or a module inside `metadata` that is stale
  and prints as before is not seen.
- That every edit of the sweep reaches the pages: an edit of a module's
  text need not change what it exports (`--edits` says how many did).
- The sweep of a document that takes long edits one other file; the rest
  is left to random sequences and to the soak.
- It tests the engine: the same world compiled through `@typst.compile`, as
  a host that embeds the engine does. It exports both formats where the
  CLI exports one, and resolves the span of every glyph where the CLI
  resolves those of diagnostics. Whether the CLI sees a change at all (file
  events, renames, files that appear), what it prints and what it writes
  is `scripts/watch_check.py`'s, which needs the upstream binary and real
  file events and is not a CI stage.
