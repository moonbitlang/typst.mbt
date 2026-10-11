# Codex review of docs/incremental-design.md, revision 4: step 1 of slice 1 (gpt-6-astra, xhigh, 2026-10-07)

Reviewed: commit `68aea3a` (revision 4 as merged with slice 0). Static
review, read-only. A narrow round, made before step 1 of slice 1 ("Scopes
and recording") was built, on what that step builds and the earlier rounds
contested: section 5.2 (the tracked world: reads and fingerprints, hooks,
carriers, the contract of a world, scopes, the answers of a scope, volatile
files, recording, hits, costs), step 1 of slice 1 in section 8, and the
parts of 9.1 that belong to it (mutation checks 1 to 7, 17, 19, 21 and the
checked mode as far as recording needs it). Three things were asked for: a
world read that the list of hooks misses (from a search of the code, not
from the list); an input on which a result that 5.2 validates is stale;
whatever in step 1 cannot be built as written, with seven questions the
text leaves open. Verdict: REQUEST CHANGES, "repairable within this
design". Eight findings (six required, two recommended), a census of every
world read and carrier, decisions on the seven questions, and what it
checked and found right. It found no leaf read that the table of 5.2
lacks; the table's gaps were carriers and the library that
`History::compute` took from the world.

The answers below are revision 5 of those sections and the code of step 1
(`library/tracked_world.mbt`, `library/memo_check.mbt`). The text of
revision 5 has not been reviewed; the code was, at the end of the step.

## What changed, and what did not

| # | finding | disposition |
| --- | --- | --- |
| 1 | Nothing says which world owns the scope at hand: the answers and the log are ambient state, so an engine of an outer scope that is used while a nested scope of another world is open gets the inner table. And a result that comes back from a foreign world carries dependencies that the enclosing call's log does not hold | Accepted, by another structure than the one proposed (an owner check on ambient state). The answers and the log are the tracked world's own state (5.2, "Scopes"): a tracked world is in a scope or not, an engine reads and records through the one it holds, and no state is shared between two worlds, so there is nothing to mismatch. Whether an evaluation joins a scope is decided by its world being in one, not by the route. A read through any other tracked world while a memoized call of this one is in progress marks that call like a volatile read: it is not stored (5.2, "A read through another world"). Unit tests for both |
| 2 | The library is compared by module entries only; a closure or layout entry made under one library is found under another (`eval("sys.inputs.x")`). `History::compute` takes the library from the raw world, which the tracked world does not have | Accepted. Step 1 compares the library object by identity in every entry of the three stores; step 3 replaces it by the serial number in the key. `analyze`, `Introspection.diagnose` and `History::compute` are handed the compilation's library with its tracked world (a change of `analyze`'s signature) |
| 3 | The fingerprint of a source needs the revision that section 8 gave to step 3. Text or identity alone is no substitute (the numbered tree is part of the answer). Revision caching is sound with in-place edits only if every mutation advances the revision, and `Source::root` and `Source::with_root` let two sources share a tree. Until then: the full fingerprint once per scope | Accepted that the fingerprint of a source belongs to step 1. What the finding asked for under it arrived from elsewhere while the step was built: the persistent edits of step 3 were merged (pull request 64), and with them a `Source` never changes and a published tree is not written to (the header of `syntax/node.mbt`), so there is no revision to advance and no alias to edit through: the object is the state. Not accepted: hashing the tree, once per scope or at all. The fingerprint is equal only where the id, the text and the numbered tree are, and costs less: a source that `Source::new` made is fingerprinted by id and text, since its tree is a function of them (`Source::is_pristine`), the result of an edit by id and the number of the object (`Source::serial`), which no other source has. Hashing a megabyte of text takes 0.7 ms, hashing its tree 25 ms; the tree hash once per scope is what the probe measured at 4.7 ms for the touying document, three times the budget of a compilation |
| 4 | "Unchanged during a scope" does not cover mutation through what a world returned: `FontBook::select_family` and `families` hand out the book's arrays, `FontInfo` has public arrays; a fingerprint kept in the book would not see a write to them | Accepted as a contract (5.2): what a world returns is read-only for everyone; a book changes by `FontBook::push` (which gives it a new state number) or by being replaced; bytes are immutable; a source changes by `Source::edit`. Not done: copies or views of the book's arrays (the callers are the shaping paths that ask per text run). What step 1 measured went further than the finding: the answers of `book` and `font` are the objects, not hashes of the infos and of the data (3 ms and 24 ms with system fonts), so the contract also says that a world hands out the objects it has |
| 5 | Volatility plumbing: `Document::lower` and standalone evaluations do not pass through `compile_with`; and a module entry stored for a real file must not be found where that file is volatile, which its recorded reads do not say (its own source is read before they start) | Accepted. The predicate is given when the tracked world is made (`TrackedWorld::new(world, volatile_files~)`), so every scope of that world has it: the compilation (`compile_with` passes its new parameter on), `Document::lower`, an evaluation, and the engines of `History::compute`, which hold the compilation's tracked world. `eval_source_memoized` asks the predicate for the file itself before it looks up or stores |
| 6 | The checked mode of 9.1 compares results and sinks; with nothing kept across compilations a missing read changes neither. Step 1 needs an oracle for the dependencies themselves, independent of the hooks under test, for every stored entry | Accepted: `@library.set_memo_check` (9.1, "The recording check"; `library/memo_check.mbt`; the runner's `--check-reads`). Every entry that a store is about to keep is computed once more from scratch (the stores set aside, isolated logs) under a spy below the tracked world, which notes every call of the raw world with a fingerprint of the answer; the entry's reads must be those, with the same answers. A volatile read in such a run is a difference like any other. Differing from the proposal: the comparison is of the ordered lists, not of sets (validation relies on the order of first reads to ask the world for nothing that a run from scratch does not ask; a difference in order would be a finding); and the opaque `works_cache` is neither bypassed nor made to taint its callers: it is found by the identity of the engine's introspector, of which every memoized call has an object of its own (`track_with`), so a memoized call only finds works that it generated itself, reads included; no entry of 1.5 million differed (9.1). It stays step 2's for the rule it breaks. Rejected candidates leave nothing in the log (validation notes the reads of an entry only when it is taken). The table of evidence per mutation check is in 9.1 |
| 7 | The world log must be finalized on every path, raising or returning, before any decision about storing; `memoize` publishes into a store whose generation changed during the call | Accepted. 5.2, "Recording": `reads_end` before cacheability, volatility and generation are looked at, `reads_abort` when the call raises (what it read stays in the log for the calls around it). `memoize` got the guard that `memoized_closure` had |
| 8 | Shaping asks for the book and a font per text run: "one push per read" and a scan when the call ends are not shown to meet the budget; suppress a read that is already in the recording interval of the call in progress | Accepted. 5.2, "Recording": per read of the scope the position of its last push; a read whose position lies in the part of the innermost call is not pushed again (comemo's `MergedSink::emit` stops at the first constraint that has the call). A read that is only in the caller's part is pushed for the call inside. Nothing is logged while no memoized call is in progress. Measured in 5.2, "Costs" |
| census | Carriers the list of 5.2 did not name: `EvalMemo.world`, `ShapingContext.world`, the parameters of `apply_shift`, `get_font`, `math_shape` and the glyph constructors of `layout/math_glyph.mbt`, `Bibliography::load`, `CslSource::derived_style`, `RawSyntax::load`, `RawTheme::load`, the stored `Introspection.diagnose`, `Lowering::trace_range` (`doc`) | The list of 5.2 is the census now. `EvalMemo.world` is gone (an entry belongs to a scope) |
| 3(c) | A public constructor that opens no scope and has no accessor for the raw world; outside of a scope reads pass through and the three stores are off; "no store" does not mean the caches by content of slice 0 | As built; said in 5.2 |
| found right | Read timing around calls (`import_file`, arguments, the manifest); diagnostics are dependencies (`world_range`); `Engine::delay` does not move reads; hits merge after a stamp; source and file reads are distinct; errors with their paths, for sources and files; fonts and an index of an older book; `today` per offset; reloaded bytes; process-wide tokens; an unordered set is enough for validity; volatile paths by name | "Errors for both sources and files" is said in 5.2 |

## The review of the code

The code of step 1 was reviewed at its end (the same model, high effort,
2026-10-11, the diff of the branch; read-only). Verdict: REQUEST CHANGES,
five findings, all taken:

| # | finding | what was done |
| --- | --- | --- |
| 1 | An entry that is found for another world does not mark the calls in progress of this one: `validate` pushed its reads without the notification that a tracked read gives | `validate` gives it for every entry with reads. Test: "a call that reads through another tracked world is not kept" |
| 2 | A compilation of another world inside a memoized call can depend on that world without a tracked read (its library and main file are read around the tracked methods; it can fail before anything else) | Opening a scope marks the calls in progress of the other worlds. Same test |
| 3 | Two package errors with one message (`MalformedArchive(None)` and `MalformedArchive(Some("archive malformed"))`) had one fingerprint | A failed answer is fingerprinted by its payload, not by its message. Test: "an entry is rejected if one answer differs" |
| 4 | The second run of the recording check made new modules, while the repeated call holds those of the first run: a call that compares modules took another branch and read another file | An import in the second run evaluates the file again and gives the module that the entry set aside holds. Test: "the second run of the check sees the modules of the first" |
| 5 | Module entries that keep an error were not checked | They are. Test: "a module that failed at the top level is checked too" |

It found the exits of the three stores, the position check of the log,
the shared read lists and their stamps, the fingerprints of sources and
the scopes of evaluations outside of a compilation right.

## The review

REQUEST CHANGES — **step 1 only**. The problems are repairable within this design.

I reviewed revision 4 against commit `68aea3a`, excluding concurrent implementation changes in the working tree. This was static review; I modified nothing and ran no builds or tests.

1. **Required — Specify which world owns the active scope, and enforce it before both lookup and recording.**

   Section 5.2 gives `TrackedWorld` only a raw-world field, while the answer table and log are ambient state. It does not specify what happens when an outer engine is used while a nested scope for another world is active.

   A concrete counterexample is a host harness with worlds A and B, the same library, and the same function `f() = read("x.txt")`; A serves `"A"`, B serves `"B"`. Open A’s scope, enter B’s compilation, and have its callback invoke `f` through the saved A engine and then through B’s engine. An implementation that simply consults the current ambient table can associate A’s result with B’s scope, or reuse A’s answer fingerprint for B’s lookup. Neither world changed during either scope.

   Relevant entry points are `eval/lib.mbt:72` (`eval_string`), `:96` (`eval_string_mapped`), `:190` (`routines_eval_string`), and `typst/lib.mbt:102` (`compile_with`). Testing the route is insufficient: `eval_root` explicitly replaces it with a root route at `eval/lib.mbt:135`.

   **Smallest text change:** make the scope record its world identity and kind. Require every world-dependent memo lookup and tracked read to match that owner. Ordinary internal evaluation reuses the matching scope; an explicit nested compilation/evaluation creates another. Reject use of an outer engine under a different active owner, unless a separately specified reentry mechanism handles it.

   Also specify nested-result propagation: restoring the outer log alone does not record dependencies of a foreign-world result returned to an enclosing memoized call. Until dependencies can identify multiple worlds, conservatively make that enclosing call uncacheable. A host closure whose result depends on an unkeyed captured world is outside the stated host-function contract.

2. **Required — Compare `Library` identity in every world-dependent entry now, and pass it explicitly through convergence analysis.**

   `EvalMemo` already compares library identity at `eval/import.mbt:333`. Generic `memoize` does not (`library/memo.mbt:266`), and the closure key does not (`:1071`).

   A concrete harness can evaluate one closure:

   ```typst
   #let f() = eval("sys.inputs.x")
   ```

   Then call that same closure, with otherwise identical arguments/context, through two engines whose libraries have different `sys.inputs.x`. `eval_root` obtains globals from the current engine’s library (`eval/lib.mbt:148`), so the calls differ while their recorded world-read sets can both be empty. The current closure key does not distinguish them.

   This is reachable through public engine construction or the explicit library parameter of `eval_source` (`eval/lib.mbt:5`). `compile_with` itself does **not** accept a library argument: it obtains `world.library()` at `typst/lib.mbt:108`; its evaluation callback can nevertheless construct an engine or call `eval_source` with another library.

   There is also a literal migration gap: `History::compute` builds an engine using `world.library()` at `library/convergence.mbt:159`, but the proposed wrapper has no such method.

   **Smallest text change:** step 1 retains and compares the library object by identity in all three stores; step 3 replaces that with the serial. Pass the compilation’s library alongside its tracked world through `analyze`, `Introspection.diagnose`, and `History::compute`. Normal `History::compute` does not currently introduce a second library, but it must not recover one through a raw-world escape hatch.

3. **Required — Resolve the source-fingerprint prerequisite before implementing the answer table.**

   Section 5.2 requires a full source fingerprint and a revision-indexed cache (`docs/incremental-design.md:409`), while step 3 schedules both the revision and fingerprint (`:1055`). Step 1 cannot implement its stated `Source(id)` answers using the current source representation alone: `syntax/source.mbt:15` has no revision.

   Fingerprinting only text or source identity is not an acceptable interim substitution. The numbered tree affects diagnostics and closures.

   In-place reparsing does **not inherently** make revision caching unsound: advancing the revision after every mutation is sufficient for that object. However, the current API exposes mutable aliases: `Source::root` returns the tree at `syntax/source.mbt:50`, and `Source::with_root` retains a supplied tree at `:40`. Two sources can therefore share a tree; editing one can change the other’s numbered tree without advancing the other’s proposed revision.

   **Smallest text change:** move full source fingerprinting and its revision/invalidation mechanism into step 1, while leaving persistent edits and the module-key change in step 3. State that cached revisions cover **all** tree mutations and prohibit independently editable sources sharing mutable trees. Until that condition is established, compute the full source fingerprint once per scope without reusing a revision-cached hash across scopes.

4. **Required — Extend the world contract to cover mutation through returned objects.**

   “Unchanged during a scope” is insufficient for the proposed persistent fingerprint caches.

   `FontBook::select_family` returns its internal mutable index array (`library/font_book.mbt:120`); `families` also exposes those arrays (`:84`). Consider a library-defined host function returning:

   ```text
   engine.world.book().select_family("example").length()
   ```

   Store its result in one scope. Between scopes, clear the returned family array. The next scope has a stable world, but the fresh answer differs while the book’s `infos` fingerprint is unchanged—even recomputing that fingerprint would not detect this mutation. Public `FontInfo` arrays provide additional mutation paths.

   **Smallest text change:** declare returned book metadata and its arrays borrowed read-only; supported changes are `FontBook::push` or replacement by a newly constructed book, with fingerprint invalidation. Apply the corresponding rule to sources and immutable bytes. Otherwise the fingerprint must cover/version every permitted mutation, not just `push`.

5. **Required — Finish volatility plumbing and reject volatile module inputs before lookup.**

   Two details remain unspecified.

   * `Document::lower` bypasses `compile_with` (`doc/compile.mbt:439`, calling `lower_initial` at `:449`). Adding only a `compile_with` parameter does not supply its scope predicate. Standalone `eval_string`/`eval_string_mapped` similarly need an explicit scope option or an enclosing host scope. Internal calls must inherit the current predicate.
   * Section 5.2 prohibits **storing** a module whose own source is volatile, but its existing-entry rejection checks recorded reads. The module’s own source is fetched before its recording interval (`eval/import.mbt:240`, lookup at `:330`), so an old entry need not contain that read. A stable-world entry for `<edsl-origins>` can therefore pass the stated read-set test when that id is volatile in the new world.

   The future full source key can prevent an incorrect result at that particular lookup, but it does not implement the design’s stronger promise that such an entry is never taken or stamped.

   **Smallest text change:** specify a common scope-options path for compilation, standalone evaluation, and `Document::lower`; internal evaluation and History inherit it unchanged. Before module lookup **and** insertion, reject caching when `source.id()` is volatile.

6. **Required — Step 1’s checked mode must compare dependencies directly and independently.**

   The proposed checked mode compares results and sinks (`docs/incremental-design.md:1250`), not the recorded world reads. With stores cleared between compilations and an immutable world within each scope, omitting a dependency usually leaves those comparisons passing. Mutation checks 1–6 cannot establish recording completeness through changed outputs in this step.

   **Smallest text change:** add a recording oracle for every stored entry, including stored module errors:

   * Run the same call with world-dependent stores disabled and isolated recording state.
   * Compare canonical sets of **read plus answer fingerprint**, including transitive reads and volatility.
   * Observe underlying world calls through an audit path independent of the recording switches being mutated. Two runs using the same broken hook prove nothing.
   * Keep candidate validation separate from call recording. Rejected candidates’ speculative reads must not pollute the caller’s dependency set; merge only the accepted entry’s dependencies.
   * Exercise entries at insertion as well as hits, so entries never reused are checked.
   * Treat a volatile read found by the oracle as a failure, rather than assuming it cannot occur because the entry was found.

   The remaining `works_cache` needs an explicit transitional policy. `Works::generate` returns its old result before `prepare` and the file loads (`library/bibliography.mbt:657`, `:677`, `:794`). Thus a cold recorded execution and warm shadow execution can legitimately make different reads today. This is the already-known step-2 issue, not a new 5.5 finding. For an exact recording invariant in step 1, temporarily bypass that opaque cache while collecting entries, or mark affected callers uncacheable. Disabling it only in the shadow is insufficient.

   The mutation fixtures should establish:

   | Checks | Step-1 evidence required |
   |---|---|
   | 1–6 | Independent audit detects each omitted read/answer, including errors, separate offsets, Book and Font independently. |
   | 7 | A reused child contributes its reads through **each** of the three stores, including a cached module error. |
   | 17 | Nested scopes preserve distinct tokens, owners, tables and logs; restoration does not reset the counter. |
   | 19 | Audit knows the correct normalized volatile paths independently of the mutated predicate; test both insertion suppression and existing-entry rejection. |
   | 21 | The file-reading producer actually executes inside `History::compute`, and its enclosing recorded call sees the read. |

   Future cross-compilation output mutations can remain scheduled with persistence. They cannot substitute for this step’s recording oracle.

7. **Recommended — State unconditional log finalization explicitly.**

   There are several materially different exit paths. Generic `memoize` finalizes introspection/sink effects on error and before its cacheability return (`library/memo.mbt:289`, `:296`, `:300`). `memoized_closure` finalizes before checking whether nested compilation changed its store generation (`:1149`, `:1173`). Module evaluation converts errors into stored results before finalization (`eval/import.mbt:358`, `:373`).

   **Smallest text change:** require world-log finalization and propagation on every returning or raising path, before cacheability, volatility, or generation-based decisions about storage. An unstored child’s reads still belong to its caller. Do not publish an entry into a store whose generation changed during the call; generic `memoize` currently lacks the closure store’s corresponding guard.

   A fatal invariant abort need not produce an entry. An ordinary `guard … else { return … }` does not excuse losing dependencies.

8. **Recommended — Make hot-read suppression part of the recording design.**

   `get_font_and_covers` obtains the book and fonts repeatedly (`layout/inline_shaping.mbt:1250`, `:1256`, `:1284`); empty-run measurement, hyphens and baseline shifting add more calls. “Usually one to five reads” describes the deduplicated set, not the number of pushes or subsequent scans.

   Static inspection cannot establish the 1%/5% budgets. A push for every read might meet them, but the text supplies no basis for that conclusion.

   **Smallest text change:** permit constant-time suppression when a read is already present in the **current call’s recording interval**. A per-read last-log-position or recording-frame membership marker can do this. A read appearing only before the child’s start must still be recorded for that child. Compaction must update the bookkeeping, and volatile taint must propagate independently. Avoid repeated linear `contains` scans over the undeduplicated log.

The complete census follows. **Covered** means named by the leaf table or its explicit catch-all; **omitted carrier** means the migration list does not enumerate it.

| Leaf read | Concrete locations | Assessment |
|---|---|---|
| `Source(id)` | `eval/import.mbt:234` `import_file`, read `:240` | Covered. |
| `Source(id)` | `library/decimal.mbt:339` `warn_on_float_literal`, read `:341` | Covered; the caught failure is still a dependency. |
| `Source(id)` | `library/engine.mbt:158` `world_range`, read `:162` | Covered. Only numbered spans read a source; detached/range spans do not. |
| `File(id)` | `eval/import.mbt:406` `resolve_package`, manifest read `:416` | Covered. |
| `File(id)` | `library/loading.mbt:68` `DataSource::load`, read `:77` | Covered. Bytes inputs do not read the world. |
| `File(id)` | `library/pdf_standard.mbt:757` `pdf_attach_elem_data_parse`, read `:771` | Covered. |
| `File(id)` | `library/image_svg.mbt:459` `SvgImageResolver::load_or_error`, read `:501` | Covered. |
| `Book`, `Font` | `layout/inline_shaping.mbt:715` `ShapedText::measure`, reads `:734`, `:735` | Covered. |
| `Book`, `Font` | `layout/inline_shaping.mbt:850` `ShapedText::hyphen`, reads `:858`, `:888` | Covered. |
| `Book`, `Font` | `layout/inline_shaping.mbt:1242` `get_font_and_covers`, reads `:1250`, `:1256`, `:1284` | Covered. “Four places” corresponds to four font-call sites across three functions. |
| `Book`, `Font` | `layout/inline_line.mbt:503` `apply_shift`, reads `:516`, `:517` | Covered leaf; raw parameter needs migration. |
| `Book`, `Font` | `layout/math.mbt:597` `get_font`, reads `:606`, `:609` | Covered leaf; raw parameter needs migration. |
| `Book` | `library/image_svg.mbt:61` `SvgImage::with_fonts_images`, read `:85` | Covered. |
| `Font` | `library/image_svg.mbt:351` `SvgFontResolver::load`, read `:356` | Covered. |
| `Book` | `library/text.mbt:282` `check_font_list`, read `:283` | Covered. |
| `Today(offset)` | `library/datetime.mbt:301` `impl_datetime_today`, read `:309` | Covered. |
| `Library` | `library/convergence.mbt:151` `History::compute`, read `:159` | Missing migration decision: replace with explicitly carried library, not a sixth tracked-world method. |
| `main`, main `source`, `library` | `typst/lib.mbt:76`, `:77`, `:108`; `hint_invalid_main_file` source probe `:225` | Correctly exempt for their present top-level use. |

I found **no additional production leaf among the five tracked methods** beyond these. The table’s incompleteness is principally in carriers and the History library read.

| Carrier or forwarding path | Concrete locations | Assessment |
|---|---|---|
| `Engine.world`; route clone | `library/engine.mbt:193`, `:259` | Central migration. |
| Source evaluator and stored module world | `eval/lib.mbt:5`, engine `:25`; `eval/import.mbt:255` `EvalMemo.world`, call `:359`, stored field `:376` | `EvalMemo.world` omitted from carrier list. Preserve raw-world identity semantics deliberately if retained temporarily; do not compare freshly allocated wrapper identities. |
| Ordinary shaping context and trait | `layout/inline_shaping.mbt:1097` `shape`, construction `:1109`; `ShapingContext:1169`; `SharedShapingContext::world:1187`; implementation `:1204` | Trait covered; concrete `ShapingContext.world` omitted by name. |
| Math shaping | `layout/math_shaping.mbt:5` `math_shape`, implementation `:26`; `MathShapingContext:118`; trait implementation `:132` | Struct covered; function parameters also require migration. |
| Math glyph forwarding and capture | `layout/math_glyph.mbt:28` `synthetic`, `:48` `new`, `:93` `planned`, captured `world` in `shape` at `:102`, `:130` `base` | Omitted carriers. |
| Baseline shifting | `layout/inline_line.mbt:503` `apply_shift`; callers `layout/inline_collect.mbt:226`, `:240`, and `layout/inline_line.mbt:633` | Parameter omitted from carrier list. |
| Math font selection | `layout/math.mbt:597` `get_font`; callers `:20`, `:67`, `:417` | Parameter omitted from carrier list. |
| SVG parser and retained resolvers | `library/image_svg.mbt:61`; `SvgFontResolver:239`, constructor `:256`; `SvgImageResolver:413`, constructor `:424`; parser callbacks `:91`, `:93`, `:98` | Covered. Includes the retained book used by selection/fallback. |
| Data loading | `library/loading.mbt:68` `DataSource::load`; `:97` `load_many` | Covered. |
| Bibliography helpers | `library/bibliography.mbt:98` `keys`, `:119` `database`, `:134` `csl_style`; `:181` `Bibliography::load`; `:481` `CslSource::derived_style` | First three covered; last two omitted carriers. |
| Raw-text loaders | `library/text_raw.mbt:609` `RawSyntax::load`; `:821` `RawTheme::load` | Omitted carriers, though their file reads are covered by the loading leaf. |
| Convergence callbacks | `library/convergence.mbt:25` `analyze`; stored `Introspection.diagnose:114`; closure at `:123`; `History::compute:151` | History covered in prose; stored function signature must explicitly be included. |
| Diagnostic range callbacks | `eval/call.mbt:145` `trace_call`; `eval/import.mbt:25`, `:38`, `:188`, `:198`; `library/styles.mbt:319`; `library/grid_resolve.mbt:106`, `:172` | Covered callers. |
| EDSL range lookup | `doc/lower.mbt:218` `Lowering::trace_range`, call `:222` | Missing from the table’s `world_range` callers; this uses the engine world and must be tracked. |

All engine-world data-loading forwards are:

| Path | Calls |
|---|---|
| Basic loaders | `library/read.mbt:19`, `json.mbt:13`, `yaml.mbt:13`, `toml.mbt:12`, `xml.mbt:17`, `csv.mbt:26`, `cbor.mbt:13`, `plugin.mbt:13` |
| Images and ICC | `library/image.mbt:22`, `:37`, decode fallbacks `:65`, `:82`, SVG handoff `:107` |
| Bibliography/style | `library/bibliography.mbt:55`, `:93`, `:105`, `:127`, `:141`, `:185`, `:408`, `:490`, `:794`, `:795`, `:930` |
| Raw syntaxes/themes | `library/text_raw.mbt:613`, `:741`, `:825`, `:868`, `:901`, `:922` |

The structs retaining an **Engine**, rather than a separate raw world, inherit the wrapper change:

`eval/vm.mbt:8` `Vm`; `realize/realize.mbt:49` `State`; `layout/flow_collect.mbt:27` `Collector`; `layout/flow_compose.mbt:99` `Composer`; `layout/math.mbt:318` `MathContext`; `html/convert.mbt:531` `Converter`; `html/mathml.mbt:263` `MathContext`; `library/math_ir_resolve.mbt:25` `MathResolver`; `library/grid_resolve.mbt:1133` `CellGridResolver`; `library/bibliography.mbt:1337` `ShowCtx`; `doc/lower.mbt:8` `Lowering`.

Fresh engine constructions are at `typst/lib.mbt:140`, `eval/lib.mbt:25`, `library/convergence.mbt:158`, `library/bibliography.mbt:1441`, and the host sites below. Engine record updates are at `eval/lib.mbt:135`, `library/memo.mbt:284` and `:1128`, `library/bibliography.mbt:673`, `library/counter.mbt:327` and `:352`, `library/state.mbt:135`, `library/eval_funcs.mbt:72`, and `library/engine.mbt:259`. These must preserve the world wrapper and scope ownership.

The host boundary census is:

| Host | Raw worlds, reads, and engine handoffs |
|---|---|
| `typst` | Public `compile:39`, `trace:54`, `compile_impl:69`, `compile_with:102`; evaluation callback captures raw world at `:74` and hands it to `eval_source:83`; layout engine `:140`; analysis handoff `:160`. |
| `doc` | `Session.base`, `doc/session.mbt:6`; `SessionWorld` forwards library/source/file/book/font/today at `:45`, `:55`, `:63`, `:71`, `:76`, `:81`, with main at `:50`. `Document::lower_initial` builds Engine at `doc/compile.mbt:340`; compile callback `:422` enters `compile_with:426`; standalone lower calls it at `:449`. |
| `doc` diagnostics/review | `Resolver.world`, `doc/compile.mbt:164`; source/file reads `:188`, `:198`; report construction `:380`. These remain host reads. |
| `doc` world implementation | `doc/world.mbt:30` constructor retains loader/font/date callbacks; World methods `:131`, `:136`, `:141`, `:164`, `:169`, `:174`, `:179`. `doc/system/system.mbt:65`, `:68`, `:79`, `:80` supplies host loaders/fonts/date. |
| CLI evaluation | `cli/eval.mbt:13` raw main-source preload; library `:87`; Engine `:88`; mapped evaluation `:96`. `ExpressionWorld:152` retains `SystemWorld`; World methods `:167`, `:172`, `:177`, `:182`, `:187`, `:196`, `:201` delegate or supply expression bytes. |
| CLI query | `cli/query.mbt:12` compile dispatcher; preload `:63`; library `:104`; Engine `:105`; `eval_string:114`. |
| CLI compilation/watch | Compiler handoffs `cli/compile.mbt:416`, `:422`, `:436`; `SystemWorld` methods `cli/world.mbt:162`, `:167`, `:172`, `:177`, `:182`, `:187`, `:192`; reset `:132`; watch reset/compile at `cli/watch.mbt:97`, `:100`. |
| `kit` | `DiagnosticWorld`, `kit/diagnostics.mbt:5`; raw-world printing argument `:36`; retained `WorldFiles.world:140`; source/file reads `:152`, `:175`. `FileStore::source:47`, `file:64`, reset `:105` in `kit/files.mbt` remain host storage. |
| Runner world implementations | `tests/runner/test_world.mbt:48`; `recompile_world.mbt:341`; `packages_stage.mbt:25`; `TwinWorld` retains raw base at `edsl_stage.mbt:24` and implements World at `:30`. |
| Runner engine/evaluation handoffs | Engines at `test_world.mbt:365`, `realize_stage.mbt:34`; `eval_source` calls at `test_world.mbt:547`, `realize_stage.mbt:19`, `edsl_stage.mbt:361`, `edsl_suite.mbt:354`. |
| Runner compilation handoffs | `bundle_stage.mbt:67`, `paged_stage.mbt:46`, `svg_stage.mbt:32`, `render_stage.mbt:46`, `usvg_images_stage.mbt:20`, `pdf_semantic.mbt:118`, `packages_stage.mbt:222`, `edsl_stage.mbt:398`, `edsl_suite.mbt:394`, `recompile_compare.mbt:207`, `test_world.mbt:668`. |
| Runner raw diagnostics/source inspection | `test_world.mbt:604`, `:624`, source `:631`; `paged_stage.mbt:83`, source `:89`; `recompile_compare.mbt:74`, source `:77`, report arguments `:101`, `:142`; `packages_stage.mbt:159`; raw-base helpers `edsl_stage.mbt:315`, `:335`, source inspection `:549`. |

Test-only migration sites also include engines in `doc/elements_wbtest.mbt:7`, `library/introspection_wbtest.mbt:62`, `realize/realize_test.mbt:44`, and the engine update in `html/semantics_wbtest.mbt:116`. `typst/oracle_helpers_wbtest.mbt:91` calls `world_range` for host diagnostics and needs an intentional host-side replacement or unrecorded wrapper.

I found no additional raw-world leaf in `realize`, `html`, `bundle`, `svg`, `pdf`, or `render`. Their engine flows or exported font/image values lead back to the leaves above. Generated wrappers did not add another world-reading path.

For dependencies reaching results without another world call:

* I found no additional process-wide, file-derived bypass beyond the cases already identified in 5.5. The existing `works_cache` matters to step 1’s recording oracle as described above.
* `Source` is an explicit evaluator input at `eval/lib.mbt:11`; it is not a `Value`/`DynValue` payload. Closures retain syntax nodes (`library/func.mbt:101`, `:104`). That is the source-key and ownership problem already assigned to later steps, not an extra world hook.
* Reads through `Engine.library` include globals/math scopes, routines, styles, native rules, features and formats (`library/engine.mbt:171`). They require library identity in the key; the five world-read tags do not cover them.

My decisions on **3(a)–3(g)** are:

| Item | Decision |
|---|---|
| **(a) Source revisions** | Full id/text/numbered-tree fingerprinting belongs in step 1. Move the revision mechanism with it if using revision caching. In-place edits are compatible with that cache only when every mutation invalidates it and mutable tree aliases cannot bypass the revision. Otherwise use a full hash once per scope until step 3. |
| **(b) Library** | Compare object identity in every entry now. Keep each library immutable while in use. History should receive the selected library explicitly. Two libraries can meet through public engines/evaluation callbacks even though ordinary `compile_with` selects just one. |
| **(c) Constructor/privacy** | Provide a public wrapper constructor for hosts; wrapping must neither open a scope nor mint a scope token. It must not expose an unwrapping accessor. Package privacy alone cannot enforce this inside `library`, so retain a source audit. Outside a scope, tracked methods should pass through unrecorded, with the three world-dependent stores disabled. This preserves direct host/tool use. Clarify that “no store” excludes pure content caches, which intentionally work during export outside compilation (`library/memo_content.mbt:24`). |
| **(d) Scope selection** | Ambient state is sound only with enforced owner matching and synchronous save/restore. Scope kind/owner, not route shape or “some compilation is active,” decides whether evaluation joins a scope. Foreign-world reentry needs rejection or an explicitly isolated, dependency-safe mechanism. |
| **(e) Costs** | The budget remains an empirical acceptance criterion. One push per read is not statically justified. Suppress duplicates already in the current recording interval, preserve child membership and volatile taint, and measure that implementation. |
| **(f) Volatile plumbing** | Incomplete as written. `Document::lower`, standalone evaluations and host-created scopes need the same options; internal eval and History inherit them. Check a module’s own volatile id on lookup as well as insertion. |
| **(g) Checked recording** | Compare canonical dependency sets and answer hashes against an independent audit, not read order/count or outputs alone. Resolve the temporary Works exception explicitly. Cache warmth is not a general permission to omit dependencies. |

For (g), these specific caches do **not** justify differing world-read sets:

| Cache | Why the world dependency remains visible |
|---|---|
| Bibliography decode | `Bibliography::load` calls `load_many` at `library/bibliography.mbt:185` before the decode cache at `:193`. |
| CSL decode | File load at `library/bibliography.mbt:408` precedes `from_data` and its cache at `:427`. |
| Raw syntax/theme decode | Loads at `library/text_raw.mbt:613`, `:825` precede caches at `:619`, `:831`. |
| Raster/PDF content caches | They consume already-loaded bytes/images. Loading happens before their lookup, or the loaded content is itself an argument. |
| `data_hash` / font data hashes | Identity accelerates hashing immutable bytes; it does not replace the world call that obtained them. |
| Rustybuzz faces/shape plans | `layout/inline_shaping.mbt:22`, `:52` consume a supplied `FontInstance`; neither cache miss reads a world. |
| Glyph/outline caches | They consume supplied font/glyph data, not a world font index. |
| Raw highlighting | Complete derived companions are in its input; no world read occurs on either path. Missing companions trigger world loading and prohibit storing the highlight result (`library/text_raw.mbt:265`, `:267`, `:740`, `:867`). |
| SVG resolver font map | `library/image_svg.mbt:337` suppresses repeated loads within one freshly constructed resolver. It does not hide the first dependency across compilations. |

What I checked and found right:

* **Read timing around calls:** `import_file` fetches the source before the module entry begins; that read belongs to the enclosing call, while the module’s own source must be covered by its future full-source input key. Likewise, argument-evaluation reads belong to the caller; the child consumes the resulting keyed values. Package-manifest loading at `eval/import.mbt:416` correctly belongs to the importing caller.
* **Diagnostics are dependencies:** `world_range` is not safely dismissible as presentation. `library/diag.mbt:354` and `:359` use ranges to decide whether to append tracepoints at `:365`; those errors can be stored in module entries. The proposed tracked `world_range` covers this, including reads after an inner failed call has finished but while its enclosing module is still recording.
* **Delayed errors:** `Engine::delay` runs its function immediately (`library/engine.mbt:222`); only the errors are delayed. It does not move world reads past the recording interval. History is the actual later replay path, and revision 4 correctly brings it inside the tracked compilation.
* **Hit propagation:** section 5.2 correctly requires merging a reused entry’s reads even after its stamp skips validation. This must apply to generic entries, closure entries and both successful/error module entries.
* **Separate source/file observations:** the two tags must remain distinct. The file store strips a BOM while producing a source (`kit/files.mbt:204`); raw bytes can change while source text does not.
* **Failures:** record the failed operation and fingerprint the complete error, including paths. Make explicit that the error rule applies to **both** `Source` and `File` answers; currently it is written only under the Source bullet.
* **Fonts:** whole-book metadata covers fallback coverage decisions, including characters for which no font is selected. Font validation must tolerate an old book’s index against a new book. `Font(index)` uses a content hash accelerated by bytes identity, not identity as the fingerprint (`library/visualize_hash.mbt:456`, `:473`).
* **Dates:** `Today(None)` and each explicit offset are different reads. A single cached “today” value would be wrong; the design correctly avoids that.
* **Bytes reloads/watch:** CLI reset invalidates file slots (`cli/world.mbt:132`, `kit/files.mbt:105`); later reads reload bytes. Rehashing a new bytes object is necessary and correctly acknowledged.
* **Stamps:** a fresh process-wide token per scope handles sequential reuse of the same world object and nested scopes, provided the world stays fixed for the entire open scope. Do not derive tokens from depth/generation, reset them during eviction/restoration, or silently wrap the counter. The volatility predicate must also stay fixed for that scope.
* **Unordered constraints:** for deterministic immutable world methods, an unordered set of `(read, answer fingerprint)` pairs is equivalent for validity. Comemo’s `constraint.rs:35` validates those equalities; its ordered representation supports lookup, and `tree.rs:99` can extract calls in the tree’s order. Order becomes semantically relevant for mutable answers, cross-world confusion, or side effects—cases this contract must exclude or taint. Volatile reads cannot be collapsed into an ordinary stable pair.
* **Revision 4’s volatile-path correction:** declaring normalized project paths, including future snippet names, is right. It covers failed reads before a snippet exists and avoids confusing package paths with the session’s project files.
