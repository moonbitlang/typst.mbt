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

The engine keeps what it memoizes across compilations (step 5 of slice 1
of `docs/incremental-design.md`): the evaluations of files, closure calls,
layouts, counter sequences and the works of a bibliography are stores of
the process (`library/memo.mbt`, `eval/import.mbt`), an entry is found by
a later compilation if it is still valid, and `@library.evict(max_age)`
drops what was not found for more than `max_age` calls, as comemo does. So
this stage tests the real thing: its watch loop is `cli/watch.mbt`'s, with
every store kept, and a failure is a stale result. The first one of this
kind was found by hand, before the stage existed: the memo of module
evaluations was found again by world identity and the file's own text, so
a module was reused after a file that it imports had changed
(`typst/recompile_wbtest.mbt`). The stage finds that class mechanically
(see "Mutation checks").

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

**The documents** (123 by default, and the five of the sequences that are
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
- 6 projects written for this stage (`docs/`), because the suite has no
  document of several files: `book` (a main file that includes chapters,
  which import a shared module, which reads a JSON file; CSV, TOML, YAML,
  text, a bibliography in an author-date style with citations inside
  blocks, images, a syntax and a theme, a file that is read both as a
  module and as text), `chain` (imports in a chain and in a diamond over
  one data file, a function that reads the file when it is called, every
  file a document of its own), `notes` (pages computed from the
  document, with functions that read the date and `sys.inputs`),
  `linked` (an SVG that links a PNG, as an image, in a tiling that is
  handed to functions and in one that a function captured: what the pages
  show is in a file that no element names, and whose bytes are in no
  element), `blocks` (what the block level of the flow keeps: tables
  with a header, a footer, lines and a cell that spans, a grid, blocks in
  blocks, a block that breaks across three pages with a footnote of its
  own, shapes, one block three times; and four blocks whose layout
  depends on what is neither their text nor their styles: one reads a
  CSV file while it is laid out, one asks the document about a file that
  is included after it, one reads `sys.inputs`, one warns) and
  `pages` (many page runs, for the runs and the documents
  that a compilation keeps: page set rules in the middle, a header that
  queries the document, a footer with the number of pages and with what
  a function read from a file when the footer was laid out, an outline,
  footnotes across pages, columns, runs that are the same child for
  child and span for span, a blank page for the parity, two-sided
  margins, a second numbering).
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

- What `@library.evict(0)` drops, which the stage calls before every
  reference: everything that has an age. That is the stores of memoized
  calls (`layout_store`, the counter sequence, the works of a
  bibliography, `closure_store` in `library/memo.mbt`; the module
  evaluations of `eval/import.mbt`; since slice 3 the page runs and
  documents of `layout`, with the answers that the read accelerator keeps
  for their introspectors), the results kept by content
  (`library/memo_content.mbt`: decoded raster images, highlighted raw
  text, the PDF exporter's images) and the caches of data decoded from
  bytes (syntaxes and themes of `raw`, bibliographies, CSL styles, PDF
  documents, plugins and the results of their calls, numbering patterns).
  So a reference computes and decodes everything again and shares none
  of it with the loop. (It was `evict(1)` while only the decode caches
  outlived a compilation and were dropped as a whole; an entry with an
  age survives `evict(1)` if it was just found.)
- With memoization off, the second reference of every step, nothing of
  the above is asked at all, and an evaluation of a file takes no entry
  of an earlier scope (`EvalMemo::lives`): that reference would be
  independent of the loop without the `evict(0)` too, which is the point
  of having both.
- The capture analysis of `eval/captures.mbt`, which ends with its
  compilation.
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
is added must be off with `set_layout_memo_enabled(false)` and be dropped by
`evict(0)`**. A cache that follows neither could make the watch loop and
both references wrong together. (That the references do not share the
stores with the loop is itself checked: "Mutation checks", the line with
`evict(1)`.) For that there are references in another
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
their hashes too (`modules_memo_equal` in `library/memo.mbt`), and closure
calls are kept from one compilation to the next, so it shows the same:
exactly what upstream's watch shows, at every step of the recordings.

**What is accepted.** A step of a *pinned sequence* at which the watch
loop gave what upstream's watch gave. Pinned sequences are the fixtures of
`tests/recompile/upstream/` (`getter.json`: the document above, five
steps; `nan.json`: the same with a module that exports `float.nan`,
whose hash has the bits of the float, three steps; `modules.json`: a
module through a getter, as an argument inside a dictionary and through
another file that imported it, next to a state's value and a queried
element, which upstream's watch gets right, nine steps; `plugin.json`:
the modules of three plugins, fifteen steps, and `limit.json`: more
results under one key than the port keeps of one compilation, eight
steps; both below). `scripts/gen_recompile_upstream.py <upstream binary>` generates
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

**Plugins.** `plugin.json` pins what a document can see of an age. The
module of a plugin is memoized by the plugin's bytes (upstream
`Plugin::module`, the port's `plugin_module_cache`) and compares by
identity; comemo drops the result when no compilation asked for it in
more than ten evictions. Three plugins without functions: one that the
main file loads in every compilation, and two that imported files load,
which are not evaluated again while they do not change. The main file
changes ten times. Then a comment in the first imported file: ten
evictions since its plugin was loaded, the entry is alive, the plugin is
the module it was, and the getter that returns the kept module agrees
(`true`, as in a fresh compilation). Then a comment in the second: eleven
evictions, the entry is gone, the plugin is loaded again as another
module, and the getter's module is not it (`false` in upstream's watch,
from then on; `true` in a fresh compilation). The plugin of the main file
is one module for all fifteen steps. The port's caches of plugins had no
ages (they were dropped as a whole on every tenth `evict`); they have
comemo's now, and the fixture fails if an entry lives one eviction longer
or shorter ("Mutation checks").

**The limit per key.** `limit.json` pins that an entry goes when it is
old and for no other reason. The port keeps at most four results under
one key (`memo_max_entries`), which comemo does not. A function that
reads a file and returns the module it captured, `get() = { read("flag.
txt"); m }`, has one result per content of the file. The flag takes six
contents, with a comment in the module's file at every step; then the
first content again: upstream's watch finds the call of the first
compilation, with the module of that evaluation, and `get() == m` is
`false`, as it is a step later for the fourth content. A limit that
dropped the first result when the fifth came would compute the call and
show `true`. So the limit counts the results that no `evict` has seen yet,
and a result of an earlier compilation goes by its age.

The run prints:

    recompile: 40 steps are pinned to upstream's watch
    (tests/recompile/upstream); upstream's watch gives something else than
    a fresh compilation at 18 of them, and the watch loop gave upstream's
    watch output instead of a fresh compilation's at 18

and the stage fails if the last number is not 18
(`pinned_as_upstream_expected`: a store that no longer finds its entries
gives a fresh compilation's pages there, which is a regression too; it
was 0 while nothing was kept). With `-v` every accepted
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
and fails). A stale value in a document of the other 239 sequences is not
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
total at the end (`read check: 116 341 entries checked, 0 differ in 0
cases`; an entry that is found is not computed, and so not checked,
again). The stage's own verdict
must be the same with it, the count of pinned steps included: a second run
of the check must leave no trace in what has an age.

The default run is the CI run: 128 documents, 246 sequences (238, 3 with
packages and 5 pinned to upstream's watch in `scripts/ci/stages.tsv`), 1489
steps and 4445 compilations with their exports, about 40 s on an M-series
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

That the stage catches stale results is shown by putting bugs in, one at a
time, and running the default stage (seed 1). They are not in the tree; to
repeat one, change the code as said, build the runner in release and run
`recompile -v`. All numbers are of the tree as it was when a table was
made, with every store kept (242 sequences then; 244 since the project
`blocks`, for the tables of "The block level"); with the seed that a
failure prints, each is
repeated by `recompile --only=<document> --seed=1 -v` on the mutated tree.

The three stores, each with the validation of its world reads off (the
entry is taken whatever the files, the fonts and the date are now):

| Mutation | Failing sequences, of 242 | First at | Seen in |
|---|---|---|---|
| 1. `eval/import.mbt`, `eval_source_memoized`: `world.validate(memo.reads)` is `true` | 127 | `bench/showcase`, sweep, step 2 | the dependencies in most (a module that is found again does not read its files, so they are no longer watched), the diagnostics and the pages; all five pinned sequences and their count |
| 2. `library/memo.mbt`, `memoize` (layouts, counter sequences, works): `world.validate(entry.world)` is `true` | 69 | `bench/tiny`, sweep, step 1 | the pages in all but one; in one the dependencies and the diagnostics alone (works that are found do not read the bibliography file) |
| 3. `library/memo.mbt`, `ClosureEntry::matches`: `engine.world.validate(self.world)` is `true` | 13 | `project/book`, sweep, step 1 | the dependencies (a function that reads a file is not called again), the pages |
| all three at once | 176 | | |

(While the stores were being kept one by one, each mutation was run on the
commit that kept its store, of 241 sequences then: 126 with the module
store alone, 12 with the closure store, 69 with the layouts. Before step 5
the same three mutations needed a second change, the store not being
emptied, and gave 122, 69 and 12 of 237.)

That the references share nothing with the loop:

| Mutation | Failing sequences | What it shows |
|---|---|---|
| no eviction before a reference, nothing else changed | 0 | a reference is a new world with a library object of its own, and no entry of the loop is one for that library |
| no eviction, the library not compared, and the three validations of world reads off | 181, 115 of the failures seen by the reference without memoization alone | the reference with memoization is answered from the stores that the loop filled and is wrong with it; the reference without memoization asks no store and takes no evaluation of an earlier scope |
| `evict(0)` as it is, the three validations off (the row "all three at once") | 176, 4 by that reference alone | both references see what the loop got wrong |
| `evict(1)` instead of `evict(0)`, the three validations off | 176 | the same: `evict(1)` leaves what is young, but every entry of the loop has seen the loop's own `evict(10)` and goes with it. `evict(0)` does not rest on that |

So a reference is independent three times over: its own library, `evict(0)`,
and for the second reference of a step memoization off.

The other things a kept entry is valid by, and what it keeps (the numbers
of section 9.1 of the design in brackets):

| Mutation | Failing sequences, of 242 | First at, and what else exposes it |
|---|---|---|
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

Ages and lifetimes (this step's own):

| Mutation | Failing sequences | What exposes it |
|---|---|---|
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

Two more, for the state that step 2 of the design repaired (state that a
result depends on and that is neither an argument nor a recorded read;
the design's section 5.5):

| Mutation | Failing sequences | First at | Seen in |
|---|---|---|---|
| 4. `library/visualize_hash.mbt`: the fingerprint of an SVG image leaves out the images it links (`SvgImage::links`), as it did | 3 | `project/linked`, the step of the sweep in which `art/photo.png` gets the content of `art/other.png`; `suite/visualize/image.typ` `image-svg-linked-many-formats` | the page images in all three (the page hashes as before, so the loop keeps the image it had), and in one of them the PDF; the frames and the SVG of the loop are those of the reference |
| 5. `library/bibliography.mbt`: `Works::generate` finds the works by their elements alone in a cache of the process (a result found without its key holding the file and without a read of it) | 1 | `suite/model/bibliography.typ/bibliography-multiple-files`, sweep, step 3 | the pages; the dependencies and the diagnostics where the bibliography file is no longer read |

### The block level

The layouts of blocks are entries of the store of layouts since slice 2 of
the design (`layout_single_impl` and `layout_multi_impl` in
`layout/flow_collect.mbt`, upstream's two memoized functions of
`flow/collect.rs`). They have the validations of every entry of that
store, so mutation 2 above is also theirs; to show that the stage sees a
block that is stale *by itself*, each of these is put in for blocks alone
(a switch that only the two functions pass: the paragraphs and fragments
inside a block keep their validations and would otherwise hide it). The
stage has 244 sequences since the project `blocks` was added, which is
the document that several of these need; the tests are those of
`typst/block_memo_wbtest.mbt` (13) and `library/memo_frames_wbtest.mbt`.

| Mutation, for blocks alone | Failing sequences, of 244 | First at | Tests that fail |
|---|---|---|---|
| the world reads of an entry are not validated | 47, in 40 documents | `project/blocks`, sweep, step 2 (the fonts) | "a block that reads a file is laid out again when the file changes" |
| the introspector reads of an entry are not validated | 42, in 25 documents | `bench/long`, sweep, step 0: the first compilation, whose second iteration finds the blocks of the first | 3: "a block whose content queries the document ..", "the same block at three places ..", "a block that breaks .." |
| the locator is not in the key | 2 | `project/blocks`, sweep, step 0 (one block three times: all three say where the first is) | 2: "the same block at three places is three layouts", and the count of what an empty store finds |
| the regions are not in the key of `layout_multi_impl` | 10, in 9 documents | `bench/long`, sweep, step 0 | 2 |
| the region is not in the key of `layout_single_impl` | 14, in 9 documents | `bench/long`, sweep, step 0 | 1 |
| the backlog and `last` are not in the key (the size, the flags and `full` are) | 2 | `project/blocks`, sweep, step 0 (the block that breaks, on the page of its footnote) | "a block that breaks is laid out for the regions it gets" |
| the styles are neither in the key nor compared | 17, in 16 documents | `project/book`, sweep, step 5 | "the same block under other styles is another layout" |
| the sink of an entry that is found is not replayed | 2 | `project/blocks`, sweep, step 0 (the warning of the block that warns is missing) | "the warnings of a block that is found are reported again" |
| the route is not in the key | 0 | no sequence: in a document the route of a layout is as deep as the layout is nested, and what is nested differently has another locator. It decides one thing, the error at the maximum layout depth | "a block is laid out for the route it is on" (a host's block on routes of two depths) |
| the library is not compared | 0 | no sequence: a block of a document that can tell two libraries apart has another key under each (the closure of a `context` block captured `sys` with the inputs; default styles are in the chain). For closure calls and module evaluations the comparison is the first line (the row "[12]" above) | "a block whose callback asks the library is laid out per library" (a host's callback that asks for a feature) |
| an entry keeps the frames that its caller has (no copy when it is stored) | 0 | no sequence and no test: the callers of the two functions keep what they get in a `CachedCell` and hand out clones | |
| an entry hands out the frames that it keeps (no copy when it is found) | 0 | the same | |

The copies, then, for every layout of the store, where they are what
keeps a result from the callers before:

| Mutation | Failing sequences, of 244 | First at | Tests that fail |
|---|---|---|---|
| `memoize` keeps the result that it returns to the caller that computed it | 40, in 25 documents | `bench/long`, sweep, step 0 | `library/memo_frames_wbtest.mbt`, and 2 of the block tests |
| `memoize` hands out the result that it keeps | 26, in 18 documents | `bench/long`, sweep, step 0 | the same test, and 1 of the block tests |

What a block is found by besides its text, styles and place is what it
holds, and for a grid or a table that is the cell grid, which every
realization makes anew. Its comparison (`library/memo_grid.mbt`) cannot
be seen by the stage: a grid is a function of the fields of its element
and of the styles, which are in the key themselves, so two different
grids never meet under one key in a document. It is tested where it can
fail, `library/memo_grid_wbtest.mbt`, with one grid per component:

| Mutation | What fails |
|---|---|
| the comparison as it was: two grids are equal only as the same object | all three tests of that file, and the block tests that find a table: none is found again (`bench/long`: 114 block layouts computed in every recompilation instead of none) |
| the comparison leaves out one of: `has_gutter`; the number of entries; `cols`; `rows`; `headers`; `footer`; `vlines`; `hlines`; the parent of a merged entry; whether an entry is a cell or merged; the cells; a cell's `colspan`, `rowspan`, `breakable`, `stroke_overridden`, `fill`, `stroke`, the stroke of its left, top, right or bottom side, its `body`; a line's `index`, `start`, `end`, `position`, `stroke`; the number of lines before a track (31 mutations) | "a grid that differs in one component is another argument", each at the grid that differs in that component |
| the body of a cell is compared with `==`; the host closures of a tiling in a fill, or in a stroke, are not compared as objects (3 mutations) | "host closures in a body, a fill and a stroke are compared as objects" |
| a callback for plain content has the fingerprint of the callback of its content's rule, or compares equal to it (2 mutations) | `library/memo_callback_wbtest.mbt` |

### Page runs and documents

Slice 3 of the design keeps the layout of every page run and of the
document (`layout/pages_run.mbt`, `layout/pages.mbt`,
`library/memo_pages.mbt`), and the answers of the read accelerator by
introspector (`library/introspector.mbt`); the project `pages` was
written for it. Its mutations, on the tree with them (244 sequences; the
tables above are of the tree before, of 242). Each was put in by hand (a
script per mutation, applied to a copy of the tree, never committed) and
run on the default `recompile` stage and on the unit tests of the slice:
T is `typst/pages_memo_wbtest.mbt` (12 tests), L
`layout/pages_run_wbtest.mbt`, A `library/read_accelerator_wbtest.mbt`
(6 tests). The numbers in brackets are those of section 9.1 of the
design.

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

`scripts/recompile_soak.py --minutes 20` on that tree: 127 documents,
seeds 9100 to 9107, 21.3 minutes with 12 jobs: 1016 runs, 4920
sequences, 55 995 steps, 165 729 compilations, 3008 steps compiled again
as the first compilation of a new process; 0 failures, 0 aborts.

### How the stores came to be kept

Step 4 of the design's slice 1 ended with an experiment: every store kept
at once by a local change, 240 sequences, none failing, 13 pinned steps as
upstream's watch. Step 5 made it real, one store per commit (module
evaluations, closure calls, layouts, then the counter sequence and the
works), each with the stage, the recording check and its mutation above,
after the caches of plugins had got ages and their sequence was pinned; a
review then found the limit per key, whose sequence is the fifth.
`scripts/recompile_soak.py` on the final tree: 126 documents, seeds 9000
to 9012, 36.9 minutes with 12 jobs (while the other gates of the step ran
on the machine): 1638 runs, 7930 sequences, 90 237 steps, 267 045
compilations, 4849 steps compiled again as the first compilation of a new
process; 0 failures, 0 aborts.

What the mutations showed about the stage and about the engine (as first
run, before the tracked world and with one store kept by hand at a time:
the keys of memoized calls then held none of what is listed at the end;
the counts were 17, 67 and 13):

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
