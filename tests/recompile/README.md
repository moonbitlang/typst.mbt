# Compiling again

A process that compiles a world again and again (`typst watch`, a preview,
a language server) may keep results of one compilation for the next. The
danger of doing so is a result that is stale and looks right. The
`recompile` stage is the test that must be there before any cache outlives a
compilation: it keeps one world, edits its files again and again, and after
every edit requires what the compilation gave to be exactly what a
compilation from scratch of the same files gives. (With one exception
that is upstream's own, accepted only where it is proven to be: "As
upstream's watch".)

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
does; a file that was a source before is then the source that
`Source::replace` made of the one the slot had: its text replaced and its
tree reparsed in part, so the nodes outside of the reparsed range keep
their span numbers (they are the nodes of the old tree; only where the
numbers around the new nodes run out are neighbours renumbered, as
copies). That
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

**The documents** (121 by default, and the three of the sequences that are
pinned to upstream's watch, below):

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
- 4 projects written for this stage (`docs/`), because the suite has no
  document of several files: `book` (a main file that includes chapters,
  which import a shared module, which reads a JSON file; CSV, TOML, YAML,
  text, a bibliography in an author-date style with citations inside
  blocks, images, a syntax and a theme, a file that is read both as a
  module and as text), `chain` (imports in a chain and in a diamond over
  one data file, a function that reads the file when it is called, every
  file a document of its own), `notes` (pages computed from the
  document, with functions that read the date and `sys.inputs`) and
  `linked` (an SVG that links a PNG, as an image, in a tiling that is
  handed to functions and in one that a function captured: what the pages
  show is in a file that no element names, and whose bytes are in no
  element).
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
the SVG and the PDF, byte for byte; the diagnostics of the PDF export; and
the images of the pages as a watching compiler leaves them (below).
Spans are compared as what they point at in the world of their own
compilation (file, line, column, byte range), not as numbers: that is exact
about what a user sees, and a span number that a reparsed source no longer
has is written as unresolved, which differs. Location hashes are compared
as their order of appearance. Besides, the document of every step is
exported once more after the next compilation and must be what it was: a
host may hold a document while it compiles the next.

**The page images** are the one thing that `typst watch` keeps across
compilations by a fingerprint today, so the stage does what it does. With
one image per page (`typst watch main.typ page-{p}.png`) the CLI keeps the
hash of every page and writes a page again only if its hash is not what
it was after the compilation before (`cli/compile.mbt`, `ExportCache`).
The watch loop of a sequence has that cache (`PageFiles` in
`recompile_compare.mbt`): it renders the pages whose hash changed and
keeps the image it had of every other page. A reference has no cache and
renders all of them. Both must have the same pixels on every page (at 36
ppi: what is tested is whether a page was written again, not how it is
drawn). That fails where the hash of a page says less than its pixels:
the fingerprint of some item of a frame leaves out something that shows.
It did for an SVG image whose linked image changed (`project/linked`;
"Mutation checks").

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
  (syntaxes and themes of `raw`, bibliographies, CSL styles, PDF
  documents, plugins and the results of their calls). The stage calls
  `@library.evict(1)` before every reference, so a reference decodes
  everything again.
- The results kept by content (`library/memo_content.mbt`: decoded raster
  images, highlighted raw text, the PDF exporter's images), which are
  found by what upstream hashes and are not asked with memoization off.
- The memoized calls (`layout_store`, the counter sequence, the works of
  a bibliography, `closure_store` in `library/memo.mbt`, the capture
  analysis of `eval/captures.mbt`) and the module evaluations of
  `eval/import.mbt`. They end with their compilation today. The second
  reference of every step runs with memoization off, which does not ask
  the first five at all; the module evaluations, of the main file too,
  end with the scope that stored them (a compilation is one,
  `library/tracked_world.mbt`).
- The fonts (`Font` objects, shared by all worlds of the runner) and what
  is computed from a font alone: shaping faces and plans
  (`layout/inline_shaping.mbt`), glyph frames, outlines and boxes
  (`library/font_color.mbt`, `svg/text.mbt`), hashes of font data.
- The interned file ids (`syntax/path.mbt`), parsed numbering patterns,
  constant tables that are built on first use, hayagriva's built-in styles
  and locales.

(The whole list of what the process keeps, with what each thing is found
by, is in section 5.5 of `docs/incremental-design.md`, "As built". Two
things were on this list that are gone: tables of the syntaxes and themes
of `raw` that were found by the path as it was written, and a cell with
the last works of a bibliography that was found by the engine's
introspector object.)

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

## As upstream's watch

The stage requires a recompilation to give what a compilation from scratch
gives. There is one kind of difference that it accepts, in one place,
because upstream has it and the port follows upstream in it (decided by the
owner on 2026-10-11: module equality exactly as upstream).

**What differs.** Upstream compares modules by the identity of their inner
data (`PartialEq for Module`: the name and `Arc::ptr_eq`) and finds
memoized calls by the hashes of their arguments (comemo), a module's being
its name and what it holds. The two do not agree: a call that is found
again returns what it returned before, and if that holds a module, it is
the module of an earlier evaluation, which `==` tells from the module of
the same file evaluated now. The smallest document:

    // a.typ
    #let v = 1
    // comment 0

    // main.typ
    #import "a.typ" as m
    #let get() = m
    #get() == m

A comment in `a.typ` changes. The file is evaluated again and gives a new
module with the hash of the old one; the main file is evaluated again too
(it read `a.typ`), `get` is a closure with the hash it had, and `get()` is
found: it returns the old module. `typst watch` of the upstream binary
then shows `false` where `typst compile` shows `true`, until an edit
changes what the module holds. The port's memoized calls take modules by
their hashes too (`modules_memo_equal` in `library/memo.mbt`), so it will
show the same as soon as closure calls are kept from one compilation to
the next. It does not yet: nothing is kept. With every store kept (the
experiment below) it shows exactly what upstream's watch shows.

**What is accepted.** A step of a *pinned sequence* at which the watch
loop gave what upstream's watch gave. Pinned sequences are the fixtures of
`tests/recompile/upstream/` (`getter.json`: the document above, five
steps; `nan.json`: the same with a module that exports `float.nan`,
whose hash has the bits of the float, three steps; `modules.json`: a
module through a getter, as an argument inside a dictionary and through
another file that imported it, next to a state's value and a queried
element, which upstream's watch gets right, nine steps). `scripts/gen_recompile_upstream.py <upstream binary>` generates
them: it runs `typst watch` of the upstream binary on the project, writes
the files of every step, and records the SVG that the watching process
wrote and the SVG of a fresh `typst compile` of the same files. The
documents draw boxes and no text (a black box for `true`, a red one for
`false`), so that their SVG is the same bytes whatever the fonts of a
world, in upstream's CLI and here. Like `scripts/watch_check.py`, whose
sessions it uses, the script needs the upstream binary and real file
events and is run by hand (`--check` compares with what is committed);
the stage reads the fixtures and needs neither.

A pinned sequence runs like any other (group `recompile upstream` of the
summary and of `scripts/ci/stages.tsv`): the watch loop with the
fixture's edits, then the two references of every step. At every step
(`pinned_verdict` in `tests/runner/recompile_pinned.mbt`, which is the
only place where a recompilation that differs from a reference passes):

1. The reference must give upstream's fresh SVG, byte for byte. That
   holds in every run and with nothing kept: it says that the fixture is
   of these files and that the port's answer from scratch is upstream's.
2. If the watch loop gave what the reference gives, the step passes.
3. Otherwise it passes only if upstream's watch gave something else than
   upstream's fresh compilation at this step, the watch loop's SVG is
   that recorded SVG, byte for byte, and the dependencies, the
   diagnostics and the diagnostics of the PDF export are those of the
   reference. The step is counted, and the run says how many there were.

Everything else fails: a difference at a step where upstream's watch
agrees with a fresh compilation (the port is stale where upstream is not:
a bug in a key or in a validation), pages that are neither a fresh
compilation's nor upstream's watch's, and upstream's pages with other
dependencies or diagnostics. Nothing of this applies to the sweeps and
random sequences of the other documents: there a recompilation gives
what a fresh compilation gives, or the sequence fails. (None of those
documents compares modules. A document that does and is edited at random
would need a fixture per sequence; it is pinned instead.)

The run prints, for example with every store kept:

    recompile: 17 steps are pinned to upstream's watch
    (tests/recompile/upstream); upstream's watch gives something else than
    a fresh compilation at 13 of them, and the watch loop gave upstream's
    watch output instead of a fresh compilation's at 13

and with nothing kept, as the tree is, `at 0`. With `-v` every accepted
step is a line (`NOTE upstream/getter :: step=1 (a comment in a.typ): as
upstream's watch, not as a fresh compilation`). `scripts/recompile_soak.py`
does not compile such a step again in a new process (the runner marks it,
`as-upstream.txt`): a new process gives a fresh compilation.

**What this gives up.** That a recompilation always gives what a
compilation from scratch gives: where modules are compared with `==`
after a call returned one, it gives what upstream's watch gives. And the
references without memoization of such steps are references of a fresh
compilation, as everywhere, not of the loop.

**What it cannot hide.** The acceptance needs a byte-identical SVG that
was recorded from the upstream binary for exactly these files and this
step. A stale result of the port in a pinned document passes only if it
draws the page that upstream's watch drew: the same boxes, each a
comparison of modules or a value that depends on none, on a document of
one page (a document with another number of pages has no SVG to compare
and fails). A stale value in a document of the other 237 sequences is not
looked at by this rule at all. What the rule does not look at, at a step
it accepts: the frames, the introspector's answers, the PDF and the page
images of the loop, which differ from the reference's there by what the
boxes show (it requires the dependencies and the diagnostics to be the
reference's).

## Running

```sh
moon run tests/runner --target native --release -- recompile [filter] [-v]
python3 scripts/ci/stages.py recompile      # the verdict CI uses
```

`--check-reads` also runs the recording check of the tracked world on
every compilation of the stage (`@library.set_memo_check`: every result
that a store keeps is computed a second time from scratch, and the world
reads of its entry must be what that run asked of the world): a line
`READS <document> seed=.. sequence=..: ..` per entry that differs and a
total at the end (`read check: 125391 entries checked, 0 differ in 0
cases`). The stage's own verdict must be the same with it.

The default run is the CI run: 124 documents, 240 sequences (234, 3 with
packages and 3 pinned to upstream's watch in `scripts/ci/stages.tsv`), 1438
steps and 4292 compilations with their exports, about 40 s on an M-series
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

| Mutation | Failing sequences, of 237 | First at | Seen in |
|---|---|---|---|
| 1. `eval/import.mbt`: the module entries outlive their scope (`eval_memo_kept` is `true`: `EvalMemos::of` does not drop the entries of closed scopes) and their world reads are not validated (`world.validate(memo.reads)` in `eval_source_memoized` is `true`): the bug that the watch work found | 122 | step 1 in 94 of them, the first compilation after the first (`project/book`, sweep) | the dependencies in 117 (a module that is found again does not read its files, so they are no longer watched), the diagnostics in 23, the pages in 26 |
| 2. `library/memo.mbt`, `memoize`: the store is not cleared when the generation changes (the layout memo, the counter memo and the works of a bibliography outlive the compilation), and `world.validate(entry.world)` is `true` | 69 | step 1 in 61 of them (`bench/tiny`, sweep, first) | the pages in 68 of them; in one the dependencies and the diagnostics alone (works that are found do not read the bibliography file) |
| 3. `library/memo.mbt`, `memoized_closure`: the store is not cleared, and `engine.world.validate(self.world)` in `ClosureEntry::matches` is `true` | 12 | step 1 in 9 of them | the dependencies in 6 (a function that reads a file is not called again), the pages in 7 |

These are the three mutations of the stage's first version, on the code
as it is since the tracked world (`library/tracked_world.mbt`; step 1 of
slice 1 of `docs/incremental-design.md`): every entry of the three stores
keeps what its call read of the world and is only taken if the world
still answers the same, so "the store is not cleared" alone no longer
makes a result stale, and each mutation also turns that validation off.
With the validation left on, the same three give:

| The store outlives its compilation, world reads validated | Failing sequences | What is left |
|---|---|---|
| 1. module entries | 0 | (4 before step 3 of the design: three at "everything back", where a file that has an earlier text again has other span numbers and an entry was found by the text of its file, and one diagnostic with a tracepoint too many, since the error that an entry kept was the object that every import adds a tracepoint to. An entry is found by the fingerprint of its source now and keeps a copy of its errors) |
| 2. layouts and counter sequences, and since step 2 of the design the works of a bibliography (the same kind of store) | 0 | |
| 3. closure calls | 0 | |

That is what the validation is for. What else a kept result depends on
(state outside the arguments, identity, mutable results: sections 5.3 to
5.5 of the design) is steps 2 to 4 of its slice 1, and step 4 ran the
experiment with every store kept at once ("With every store kept",
below). The date, the fonts, `sys.inputs` and the files that a call reads
are no longer among the things a key does not hold: they are the reads
and the library of the entry.

What the recording itself is worth cannot be seen by this stage while
nothing is kept; the recording check can (`--check-reads`, below).

Two more, for the state that step 2 of the design repaired (state that a
result depends on and that is neither an argument nor a recorded read;
the design's section 5.5), run on the default stage of 237 sequences:

| Mutation | Failing sequences | First at | Seen in |
|---|---|---|---|
| 4. `library/visualize_hash.mbt`: the fingerprint of an SVG image leaves out the images it links (`SvgImage::links`), as it did | 3 | `project/linked`, the step of the sweep in which `art/photo.png` gets the content of `art/other.png`; `suite/visualize/image.typ` `image-svg-linked-many-formats`, sweep and random sequence | the page images: the page hashes as before, so the loop keeps the image it had, and the reference has other pixels. Nothing else differs: the frames, the SVG and the PDF of the loop are those of the reference. This is what `typst watch` did with PNG pages |
| 5. `library/bibliography.mbt`: `Works::generate` finds the works by their elements alone in a cache of the process that `evict` drops with the decode caches (what the cell of the last works was for two calls that share an introspector object: a result found without its key holding the file and without a read of it) | 7 | the sweep of `project/book` (from its eighth step on), and sweeps and random sequences of the suite's bibliography and citation tests (`bibliography-basic`, `bibliography-multiple-files`, `bibliography-before-content`, `issue-3481-cite-location` twice, `issue-785-cite-locate`) | the pages in all of them, the diagnostics in six (a document that compiles from scratch fails in the loop). Also `paged`: 15 tests fail, and `paged --check-reads`: 6 entries in 3 tests |

With the seed that the failure prints, every one of them is repeated by
`recompile --only=<document> --seed=1 -v` on the mutated tree.

### With every store kept

Step 4 of the design's slice 1 (identity and ownership; "Step 4 as built"
in its section 8) ended with the experiment that says whether the stores
can be kept: all of them at once. A local change, never committed:
`memoize` and `memoized_closure` do not empty their stores when a
compilation starts, the module entries outlive their scope
(`eval_memo_kept`), `evict(1)`, which the stage calls before every
reference, drops them all (so that references are computed from
scratch), and `pinned_as_upstream_expected` is 13. Validation is on.

| Every store kept, and | Failing sequences, of 240 | What |
|---|---|---|
| nothing else | 0 | the watch loop gave upstream's watch output at the 13 pinned steps at which upstream's watch differs from a fresh compilation, byte for byte, and a fresh compilation's at every other step of every sequence |
| mutation 1 (module entries: world reads not validated) | 126 | first `bench/showcase`, sweep, step 2; the pinned sequences and their count fail with it |
| mutation 2 (layouts, counter sequences, works) | 69 | first `bench/tiny`, sweep, step 1 |
| mutation 3 (closure calls) | 12 | first `project/book`, sweep, step 1 |
| an entry takes any introspector for the one it was computed with, and its introspector reads are not validated | the runner aborts (exit status 134) | `project/notes`; the `paged` stage too: a kept layout holds locations that the introspector of the iteration does not know |
| the library is not compared, in all three stores | 1 | `project/notes`, sweep, steps 2 to 4 (`sys.inputs` changes) |
| the sink of an entry that is found is not replayed | 9 | `query-running-header` and the four convergence tests of the suite: a warning that a fresh compilation gives is missing |
| the stores take modules by identity instead of by their hashes | 2 | `upstream/modules`, steps 1 to 6 and 8: "the pages are not what upstream's watch gives either"; and the count of accepted steps (6, expected 13) |

`scripts/recompile_soak.py --minutes 10` with that runner (every store
kept, nothing else): 124 documents, seeds 1000 to 1004, 620 runs, 3040
sequences, 34 594 steps, 102 372 compilations, 1835 steps compiled again
in new processes, no failure and no abort.

So with every store kept and validation on, a recompilation gives what a
compilation from scratch gives in all of this, and what upstream's watch
gives where the two differ. What that does not show is what the edits
do not reach (below, "What it does not cover"), and it is not the change
that keeps the stores: ages and eviction are step 5.

All the counts of this section were measured again on the tree that has
both step 2 and step 3 of the design (237 sequences: the project
`linked` is two of them): 122, 69 and 12 without validation, none with
it, 3 and 7.

The first mutation fails in half of all sequences since step 3 (19 before
it, of 235): the main file's evaluation is an entry of the same store, so a store
that is kept without validation answers every recompilation whose main
file is the source it was, whatever else changed.

What the mutations showed about the stage and about the engine (as first
run, before the tracked world: the keys of memoized calls then held none
of what is listed at the end; the counts were 17, 67 and 13):

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
  character deleted: the source that was edited (reparsed in part) has
  one error more than a parse of the new text ("expected pattern" besides
  "the character `#` is not valid in code"). Upstream does the same: its `typst
  watch` prints both errors after that edit and its `typst compile` one.
  The port follows the reparser (the `reparse` stage compares the two), so
  the stage does not call this a failure: it checks every source of every
  step against a parse (`RecompileWorld::reparsed`), counts the steps
  where they differ and does not compare those. (Found by the soak: seed
  2000, `suite/introspection/locate.typ/locate-between-pages`, the second
  random sequence, after 12 edits.)

Otherwise no step of any sequence differed from its references: in the
default run, and in the soak runs of `scripts/recompile_soak.py`, which
were made while the stage grew:

- an hour on 18 cores with its first version (seeds 1000 to 1038 on the
  120 documents of the default run with four random sequences of 12 edits
  and the sweep each: 4,680 runs, 261,196 steps, 783,588 compilations;
  seeds 5000 to 5006 on the 99 documents with packages: 693 runs, 15,470
  steps, 46,410 compilations). 21 runs aborted, and aborted again from
  scratch: 20 of them were `box-inset-ratio` (see "Running"), one was the
  PNG below;
- 18 minutes with the fonts, the introspector and the references in new
  processes (seeds 2000 to 2004 and 6000 to 6002: 897 runs, 37,578 steps,
  112,734 compilations, 2,391 steps compiled again in a process of their
  own), which found the reparsed tree above;
- 10 minutes with the stage as it is (seeds 3000 to 3004 and 7000 to
  7001: 798 runs, 36,453 steps, 105,707 compilations, 2,196 steps compiled
  again in a process of their own): nothing.

Found on the way, not by a step that differs (neither is about compiling
again, and neither was fixed with the stage; the first has been since):

- **A PNG with a damaged header killed the process or was accepted.** The
  PNG reader did not check the checksums of chunks. With one bit of the
  width flipped (`flip-bit @16` of a 16 by 16 image, in the soak) upstream
  reports `failed to decode image (Format error decoding Png: CRC error:
  ...)`; the port, depending on the bit, reported another error, aborted
  in an allocation or in `PngExpander::row`, or compiled the document with
  the damaged image. Reduction: `tests/recompile/docs/book/data/squares.png`
  with byte 16 xor `0x04` (abort) or `0x80` (accepted), and
  `#image("p.png")`. Fixed since: the decoder is a port of the `png`
  crate's, with an oracle of damaged files (`codecs/png_oracle_test.mbt`;
  AGENTS.md, "PNG decoding").
- **Two files, one relative path, two themes.** (Fixed since: the decoded
  syntaxes and the theme are kept with the field, as upstream's `Derived`
  does; `typst/content_memo_wbtest.mbt`, "the same relative path in two
  directories".) `raw_theme_derived` and
  `raw_syntaxes_derived` (`library/text_raw.mbt`) were tables of the
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
  `reset`, `dependencies`), and `SystemWorld::reset` is upstream's. One
  level down there was a difference, which is gone: upstream's `Source` is
  copy-on-write (`Arc::make_mut` in `Source::replace` and in the
  reparser), so whoever holds a source or a syntax node of the compilation
  before keeps what it held, and the port's `Source` and `SyntaxNode` were
  objects that `Source::replace` edited in place. Now an edit returns a
  new source and copies the nodes it writes to (`syntax/source.mbt`,
  `syntax/reparser.mbt`; the rule is in the header of `syntax/node.mbt`):
  a cache that keeps a closure, a module or content across a reset keeps
  the nodes they were made from. This stage does not show that (nothing
  reads a node of an earlier compilation yet); `syntax/persistent_test.mbt`,
  `syntax/persistent_property_test.mbt` and `typst/persistent_wbtest.mbt`
  do.
- **Aborts.** A document can make the compiler abort where upstream
  panics: `box(inset: (left: 100%), block(width: 10pt))` measured with
  `width: auto` is "frame size must be finite" here and `assertion failed:
  size.is_finite()` there. A watching process dies of it in both.

## What it does not cover

- Only paged documents with their SVG, their PDF and small images of
  their pages: not the HTML and bundle targets, not PNG at the resolution
  and with the options of an export, no export options but the document's
  own. In particular not what the CLI's cache of page hashes does when
  only the options of the export change, which a document can set
  (`#set format.png(ppi: 72)`): the cache holds the hash of the page and
  not the options, as upstream's does, so `typst watch` keeps the PNG of
  the old resolution in both programs. The page images of this stage
  have one resolution.
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
