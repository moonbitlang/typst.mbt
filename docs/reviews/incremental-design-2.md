# Codex review of docs/incremental-design.md, revision 2 (gpt-6-astra, xhigh, 2026-10-07)

Reviewed: commit `3096ee3` (revision 2). Static review, read-only. The
prompt asked Codex to check each finding of round 1 against the document
and the code again without trusting the author's table, then to attack what
revision 2 introduced (scopes, volatile files, plugin and module identity,
`Works` as an entry, the audit of state outside the arguments, persistent
edits, ownership, the library's serial number), the slices, the acceptance
section and the performance gate. Verdict: REQUEST CHANGES. Of round 1's
fifteen findings it found seven resolved, eight partly; nine new findings
(1 to 9); findings 10 to 12 are its recheck and what it found right.

Revision 3 answers this review and has not been reviewed.

## What changed in revision 3, and what did not

| # | finding | disposition |
| --- | --- | --- |
| 1 | A recorded read does not repair a value whose fingerprint covers less than what it was built from: an SVG image's does not cover the images it links, so a closure call that is handed a tiling made after the linked PNG changed finds its entry for the old one | Accepted. 5.5: rule 2 now says that a recorded read does not replace coverage by the value's fingerprint and equality; the SVG image is a third violation, repaired by keeping the fingerprints of the files it loaded in the image (upstream's `SvgImage` has the same gap: deviation 11 and a quirk not reproduced). Step 2 of slice 1; a fixed scenario and mutation check 20 |
| 2 | "Equal fingerprints and the same host functions" does not make two modules interchangeable: native functions compare by descriptor and fingerprint by name and documentation; a library can hold two with the same; IDE tracing is not the only from-scratch difference (two libraries' modules) | Accepted. 5.4: module equality is now the exact comparison of what the modules hold (`values_memo_equal`, in which functions and types compare as Typst's `==` does), with the fingerprint as a necessary condition; the semantic change is stated with both from-scratch cases. Descriptors are classified as identity-compared values that belong to a library and are covered by its serial number |
| 3 | Volatile files were still unsound within a scope: the stamp suppressed later validation, the log could not hold several answers for one read, and snippets are created after the scope starts | Accepted, with the rule the review calls the simplest: a call that read a volatile file is not stored, and neither is any call around it (the read marks the log). Volatility is a predicate asked at the read, so that a snippet that does not exist yet is covered. 5.2; the fixed scenario is "hit, growth, hit in one scope, and a new snippet"; mutation check 19 is one mechanism now |
| 4 | Copying diagnostics does not complete ownership: traced `Styles`, `Works` and the `HintedError` of the plugin caches are mutable and handed out; introspections hold closures | Accepted. 5.4 states one rule for mutable results (what an entry keeps and what it hands out are different objects, on storing and on every hit) and lists what it applies to; fixed scenarios for the three |
| 5 | Convergence analysis cannot be exempt: `analyze` runs inside the compilation, and its engines enter the counter store and call the document's functions | Accepted. 5.2: the engines of `History::compute` get the scope's tracked world; a fixed scenario and mutation check 21 |
| 6 | Identity and immutability must hold for every constructor: `Library` is a record that tests build by update, so copies would inherit a serial number; a font with a host's own face is fingerprinted by data and index only; query ownership came after the first slice that keeps entries | Accepted. 5.3: a library is made only by its builder and nothing reachable from it is written afterwards; 5.2: the contract of a font; `query` returns a view or a copy in step 4 of slice 1 instead of slice 3. Not done: including a host face's identity in a font's fingerprint. `Fingerprint for Font` is upstream's `Hash` (data and index); a face that behaves differently for the same data breaks the contract of 5.2 |
| 7 | The checked mode contradicted the identity policy (it rejected values from the library and from lossy reads), compared fingerprints (which miss findings 1 and 2), and was not independent (kept descendants, consumed arguments, double replay); mutation checks 6, 10 and 19 were not single faults | Accepted. 9.1: a shadow run with every store off, snapshots of the arguments, its own sink; exact comparison of result and sink; the identity invariant by provenance (key, library, results of introspector reads). Check 6 split, 10 replaced by a fault that exists with persistent trees, 19 one mechanism; each scenario must show that its entry was found |
| 8 | The performance gate was not defined, the summary overclaimed (97 % is `handle_image`, not conversion; page runs and documents also pay after an edit of a deck; "half" for highlighting is a profile share; the phase ratios do not give one ratio for every workload) | Accepted. 9.2 defines `G` (evaluation plus layout, port over upstream, at most 2.5, how it is measured, the tolerance, the one listed exception) and gives the first-compilation ratios beside the totals; section 0 corrected in the four places |
| 9 | The audit: bibliography decoding is keyed by sources and bytes; interners are not caches; the font caches also grow with variation coordinates and feature sets, and a font keeps instances of itself | Accepted. 5.5 and 6.3 |
| 10 | Round 1 rechecked: 4, 5, 7, 10, 13, 14, 15 only partly resolved | Each "partly" points to one of the findings above, where it is answered |
| 11 | The inventory of Typst's `==` per kind of value; the four ways an identity-compared value enters a result must cover sink payloads and need a complete classification | Accepted. 5.4 "What compares by identity" gives the classification and refers to the inventory; the four ways are said to cover the sink and kept errors |
| 12 | Checked and found right: spans of `doc` under another session's registry; what a persistent edit copies; `Source::replace` without a change; two sources for one file id; the key of `Works`; entry points; slice 0; either order of slices 2 and 3; the upstream and comemo corrections; the watch loop | The key of `Works` is in 5.5 as the review states it; "slices 2 and 3 do not depend on each other" is in section 8; the note on step 1 of slice 1 ("always true") is corrected: volatile reads change behaviour at once |

## The review

REQUEST CHANGES

Static review only; no files changed. The round-1 disposition table is in finding 10. New correctness findings come first, ordered by severity.

1. **Required — §5.4–5.5: tracked reads do not repair incomplete fingerprints of derived values.**

   A tiling eagerly lays out its body and retains the resulting frame (`library/tiling.mbt:105`). SVG decoding reads linked images (`library/image_svg.mbt:501`), but SVG equality and fingerprints include only the SVG bytes, resolution flag and fonts—not the linked images (`library/image_svg.mbt:22`, `library/visualize_hash.mbt:607`). Tiling fingerprints include the frame; memo comparison also accepts structurally equal tilings (`library/visualize_hash.mbt:212`, `library/memo.mbt:356`, `library/frame.mbt:558`).

   **Scenario:** construct a tiling containing `tile.svg`, which links a red PNG; pass the tiling through `id(x) = x`, then use its result as a fill. Change only the PNG to blue. World validation correctly rebuilds the tiling, but the new tiling matches the old argument’s fingerprint **and exact memo comparison**. The retained `id` entry recorded no image read and returns the old red tiling. From scratch, it returns blue.

   Include resolved SVG resource dependencies in the value’s fingerprint/equality, or otherwise prevent this reuse. Merely tracking SVG decoding is insufficient. Add this **derived-value-through-a-closure** case to §9.1; a direct linked-SVG edit need not expose it.

2. **Required — §5.4: “same fingerprints and same host functions” does not establish module interchangeability.**

   Native functions compare by object identity, but fingerprint only their name, title and documentation; they neither set the identity flag nor enter the host-function collector (`library/func.mbt:414`, `library/value_hash.mbt:572`). Hosts can create distinct native descriptors with identical metadata (`library/lib.mbt:5`, `library/func.mbt:57`) and supply arbitrary Values through `sys.inputs` (`library/lib.mbt:147`, `library/lib.mbt:466`).

   **Scenario:** an immutable library supplies distinct native functions `a` and `b` with identical metadata. An imported file defines `x` by selecting between them using `read("choice.txt")`. Main passes that module through `id(m) = m`, then compares `id(m).x == sys.inputs.b`. Change the choice from `a` to `b`. Module evaluation invalidates correctly, but the proposed module comparison equates the old and new modules: equal fingerprints, no collected hosts, no unidentified module. The retained `id` returns the module containing `a`; the comparison is false instead of the from-scratch true.

   Extend identity handling to native descriptors, element descriptors and types, or explicitly restrict them to canonical singletons and enforce that restriction. Element and Type equality are also physical identity (`library/element.mbt:134`, `library/ty.mbt:85`).

   The claimed sole from-scratch difference—IDE tracing—is also too narrow: separate library builds create separate identified `math` modules, which hosts can bring into one evaluation (`library/lib.mbt:342`, `library/lib.mbt:389`, `library/lib.mbt:466`). State the actual semantic change.

3. **Required — §5.2: volatile-file handling is still unsound within one scope.**

   The proposed exception bypasses the answer table, but a successful hit still stamps the entry and suppresses subsequent World validation for that scope (`docs/incremental-design.md:482`, `:499`).

   **Scenario:** execute the same closure call reading `<edsl-origins>` twice, establishing a stamped hit; lower another callback result, growing the listing; execute the same call again. Its arguments, context, route and introspector are unchanged. The stamp returns the earlier listing. Executing the function again returns the longer listing. Callback lowering really can add origins during layout (`doc/session.mbt:126`, `:166`); the listing source is reconstructed from the registry (`doc/origin.mbt:526`).

   Two further details need resolution:

   - The log stores only read identifiers and later obtains fingerprints from the table. Volatile answers deliberately have no such table entry; multiple answers to one read cannot be represented by that deduplicated scheme (`docs/incremental-design.md:491`).
   - Snippet IDs are allocated during lowering, after scope entry (`doc/origin.mbt:485`, `:518`; `doc/lower.mbt:1089`). Passing the snippets currently known at entry is insufficient. Newly shadowed IDs—including previously failed reads—need declaration before use.

   Specify dynamic volatility registration and read-time answer recording. The simplest sound rule is to prohibit reuse of entries transitively dependent on volatile reads; otherwise define their versioning and stamp invalidation. Strengthen the fixed test to include **hit, growth, hit in one scope**, plus a newly registered snippet.

4. **Required — §5.3–5.5: diagnostic copying does not complete result ownership.**

   Three additional mutable outputs require explicit treatment:

   - **Traced styles.** `Vm::trace` stores a `Styles` object; sink copying/replay copies only the surrounding arrays/pairs (`eval/vm.mbt:105`, `library/engine.mbt:330`, `:375`). `typst.trace` exposes those styles, and `Styles::unset` mutates them (`typst/lib.mbt:54`, `library/styles.mbt:57`). Trace a contextual expression, mutate its returned styles, then trace again with unchanged inputs. A retained entry replays the mutation; fresh evaluation reconstructs the original styles. Copy Styles on storage and delivery; preserve Value sharing through these snapshots.
   - **Works.** `Works` contains mutable rendered-entry arrays and nested diagnostic arrays. Its public accessors return them directly (`library/bibliography.mbt:609`, `:622`, `:690`, `:705`). Generate works, clear the returned bibliography’s `entries`, then regenerate with unchanged inputs: retaining the proposed entry preserves the cleared bibliography, whereas recomputation restores it. Specify immutable views or copies, including embedded errors.
   - **Hinted errors.** Plugin caches retain and rethrow the same `HintedError`; its hints are mutable (`library/plugin.mbt:92`, `:120`, `library/diag.mbt:209`, `:236`). Catch a plugin error, append a hint, and repeat the call: the cached failure now differs from a fresh call. SourceDiagnostic snapshots do not fix this cache.

   Sink introspections also retain executable closures, not just diagnostic records (`library/engine.mbt:286`, `library/convergence.mbt:119`). Their captured values need an explicit immutability/lifetime invariant. Add separate trace-style, Works-result and hinted-error mutation tests; the existing query/document mutation test covers none of them.

5. **Required — §5.2: convergence analysis cannot be exempted from tracked-engine plumbing.**

   `analyze` runs before `compile_with` leaves `with_layout_memo` (`typst/lib.mbt:124`, `:160`). `History::compute` constructs engines and invokes introspection callbacks (`library/convergence.mbt:151`). Counter callbacks enter `counter_sequence`/`memoize`, and counter updates can call arbitrary Typst functions (`library/counter.mbt:285`, `:325`, `:891`).

   Thus “outside of every memoized call” is not an adequate exemption. These engines can **enter** stores and execute World-reading callbacks. Migrate them to the active tracked World, or explicitly disable all stores throughout history evaluation.

   Add a nonconverging document whose state/counter updater reads a changed file, checking both convergence warnings and subsequent ordinary calls. The current acceptance cases do not exercise this route.

6. **Required — §5.2–5.3: define identity and immutability for all supported constructors, not only normal builders.**

   - **Library serials:** `Library` is a public record (`library/engine.mbt:171`). Existing callers construct different libraries with record updates, including changed features and rules (`tests/runner/realize_stage.mbt:13`, `:17`). Simply adding a builder-assigned serial lets such copies inherit it. Two immutable libraries can then share a key despite different behavior. Require a fresh serial for every semantic copy, or prohibit record construction/update and migrate these callers. Add a same-base-library/different-routines-or-rules test.
   - **Font fingerprints:** the proposed bytes/index answer identifies `Font::from_data`, but `Font::new` accepts an arbitrary backend (`library/font.mbt:132`, `:138`). Two immutable Worlds can return equal bytes/index and book metadata but different backend metrics. World validation accepts the old layout although fresh layout differs; the fingerprint ignores the backend (`library/visualize_hash.mbt:473`). Either constrain custom faces to behavior determined by bytes/index, or include their identity/version. The font-byte replacement test does not cover this.
   - **Introspector lifetime:** copying query arrays is deferred to slice 3, although slice 1 retains entries and preserves the same-backend shortcut. Query arrays are currently exposed directly (`library/introspector.mbt:690`); the shortcut skips validation (`library/memo.mbt:254`). A host can retain a backend, mutate its returned query array, then call an engine helper in a new scope. The retained result reflects the old query; recomputation observes the mutation. Move this ownership prerequisite before slice 1 retention, or explicitly forbid such backend reuse until slice 3.

   Freezing Library must cover scopes, styles, rules, bindings and inputs transitively—not merely `features` and `formats` (`library/engine.mbt:175`, `library/lib.mbt:513`). Lazy initialization itself is not a blocker: registration runs before publication, while descriptor scopes are subsequently filled from their registered builders (`library/lib.mbt:487`, `library/ty.mbt:73`, `library/func.mbt:86`, `library/element.mbt:303`).

7. **Required — §9.1: the checked mode contradicts the identity policy and is not an independent oracle.**

   “Output identity implies key identity” rejects two cases that §5.4 explicitly permits: an identity value obtained from the fixed library, and one obtained from a lossy introspector read pinned to its backend. Module entries have no argument carrying such a library-supplied value; `sys.inputs` can contain it (`library/lib.mbt:147`). Lossy-read tracking is separate from key flags (`library/introspector.mbt:509`).

   Conversely, equal output fingerprints miss findings 1 and 2. Checking only diagnostics also misses traced Values/Styles and retained introspections (`library/engine.mbt:284`).

   Specify:

   - provenance-aware identity assertions covering library and introspector dependencies;
   - independent snapshots of arguments, results and all sink effects;
   - shadow execution that bypasses retained descendants and does not publish entries or replay effects twice.

   A fresh scope alone does not provide these properties. Closure calls consume their arguments (`library/memo.mbt:1111`).

   The mutation checks also need correction:

   - **6:** split omitted book tracking from omitted font tracking.
   - **10:** it explicitly requires mutation 9, so it is not an independent fault. With persistent immutable nodes, retaining node-keyed capture analysis is not inherently incorrect; test wrong-node/revision reuse instead (`eval/captures_wbtest.mbt:325`, `:362`).
   - **19:** separately test table bypass and stamp bypass; otherwise either mechanism can mask the other.
   - Keep the other flags at their individual recording, validation, replay or ownership boundaries. They are implementable as isolated switches; their scenarios must demonstrate that the relevant entry actually hits.

8. **Required — §0, §3, §9.2: the performance gate remains underspecified, and the summary still overclaims.**

   Define the gate explicitly as  
   `incremental_port / incremental_upstream ≤ cold_port / cold_upstream + tolerance`,  
   with matching documents, options, timing boundaries, measured cold denominators, numerical tolerance and enumerated exceptions.

   Currently “every … edit” is followed by exceptions, “what the measurement can resolve” has no decision rule, and the tables omit the corresponding cold-upstream denominators (`docs/incremental-design.md:1020`). The longer-document middle edit is `366/138 ≈ 2.65`, above the quoted bench cold range, without its own stated exception (`:237`).

   Correct the summary:

   - **97% is `handle_image`, not conversion.** Conversion is about half that time (`:30`, `:294`).
   - **Page/document caching is not only useful when unchanged:** touying improves `18→17` after an end edit and `25→21` after a middle edit (`:33`, `:247`).
   - Highlighting’s “half” is a profile attribution, not the measured standalone saving `71→50` (`:29`, `:291`, `:311`).
   - The residual phase ratios do not establish the same whole-document one-shot ratio for every workload (`:35`, `:275`).

9. **Required clarification — §5.5–6.3: separate pure caches, scratch state and durable identity registries; qualify the memory bound.**

   The expanded audit is mostly sound, with these qualifications:

   | State | Recheck |
   |---|---|
   | Raw syntax/theme, CSL, PDF decode caches | Pure decoding keys hold (`library/text_raw.mbt:550`, `:655`; `library/bibliography.mbt:427`; `library/image_pdf.mbt:51`). Bibliography decoding is keyed by **source and bytes**, not bytes alone (`library/bibliography.mbt:192`). |
   | Raw derived tables | The proposed removal addresses the real path-keyed dependency hole (`library/text_raw.mbt:648`, `:676`). |
   | Works | Tracked memoization addresses hidden reads, but needs the ownership correction in finding 4. |
   | Loaded image fields | Raw loaded bytes are covered; decoded SVG dependencies still fail finding 1 (`library/image_svg.mbt:112`, `library/visualize_hash.mbt:607`). |
   | Font instances, metrics, shaping plans | Pure for immutable real-font data plus variations/features (`library/font.mbt:301`, `:526`; `layout/inline_shaping.mbt:39`). |
   | Content/style/closure fingerprints | Depend on immutable published owners; Content resets its data hash when replacing fields, and style chains explicitly assume no subsequent mutation (`library/content.mbt:59`, `library/styles.mbt:434`; closure equality uses cached hashes at `library/value_hash.mbt:556`). |
   | Syntect, regex, bibliography internals | Lazy syntax contexts/first-line tables, compiled regex scratch, archived styles/locales and collation tables are data-derived; YAML error state is reset (`syntect/syntax_set.mbt:195`, `:219`; `regex/nfa.mbt:625`; `bib/hayagriva/archive.mbt:10`, `:29`; `bib/hayagriva/collation.mbt:57`; `bib/hayagriva/io.mbt:111`). |
   | Hayro and plugin pools | Hayro object caches belong to interpreter state; plugin transitions snapshot state and move the used instance (`hayro/interpret/context.mbt:19`; `library/plugin.mbt:346`). Ordinary plugin calls still rely on the existing deterministic-call contract; pooling itself does not reset state (`library/plugin.mbt:327`). |
   | File IDs, syntect scopes, generated identities | These are durable interners/identity allocators, not ordinary evictable caches (`syntax/path.mbt:119`, `:158`; `syntect/scope.mbt:92`; `syntect/syntax_definition.mbt:276`; `usvg/tree.mbt:16`). Do not reset them while values containing their IDs survive. |
   | Shaping scratch | Nested calls take ownership of the spare buffer rather than sharing an active buffer; this holds (`layout/inline_shaping.mbt:1320`). |

   The font-cache bound needs correction: unchanged font files do not bound retained **variation coordinates or shaping-feature combinations**. Both are cache keys (`library/font.mbt:502`, `layout/inline_shaping.mbt:39`). Either age those entries or state that historical combinations accumulate until `evict(0)`. Object-held instance maps must also participate in the promised clearing, not just top-level maps.

10. **Round 1, rechecked — dispositions against revision 2 and code.**

   “Resolved” means the proposed text closes the original scenario, not that anything is implemented.

   | R1 | Status | Recheck |
   |---:|---|---|
   | 1 | **Resolved** | Two-sided diagnostic copying closes accumulating import tracepoints; mutation occurs at `library/diag.mbt:339`. Other mutable outputs remain in finding 4. |
   | 2 | **Resolved** | Unique nested tokens plus error restoration replace the inadequate outer-only epoch (`library/memo.mbt:113`). |
   | 3 | **Resolved** | Explicit evaluation scopes plus the no-store-outside-scope rule close standalone imports, including the current unconditional import-store route (`eval/import.mbt:250`). |
   | 4 | **Partly** | Plugin bytes/transitions and host collection close the empty-plugin/HostFunc examples; native identity and the checked invariant remain wrong—findings 2 and 7. |
   | 5 | **Partly** | Document copies and query-array copies address the objects identified, but query ownership arrives too late—finding 6 (`library/introspector.mbt:690`). |
   | 6 | **Resolved** | Adding Library to 0b’s key covers the routine used by highlighting (`library/text_raw.mbt:204`). |
   | 7 | **Partly** | Volatility is acknowledged, but stamps, recording and dynamically allocated snippets remain unsound—finding 3. |
   | 8 | **Resolved for the original hidden-read scenario** | Moving Works into tracked memoization propagates bibliography/CSL reads (`library/bibliography.mbt:794`). Its key and output ownership still need the qualifications below and finding 4. |
   | 9 | **Resolved under the stated read-only publication contract** | The new copying list covers line storage, reused children, widening renumbering and fallback writes (`syntax/lines.mbt:259`; `syntax/node.mbt:723`, `:794`; `syntax/reparser.mbt:41`). |
   | 10 | **Partly** | Most carriers and the host contract are now explicit; History engines and Library construction remain incomplete—findings 5–6. |
   | 11 | **Resolved** | Corrected bundle locator/export resolver, HTML whitespace, math keys and comemo behavior match the sources cited below. |
   | 12 | **Resolved for clearing; qualification remains** | §6.3 explicitly includes font instances and other font caches in `evict(0)`; the historical-variation bound remains overstated—finding 9 (`library/font.mbt:502`). |
   | 13 | **Partly** | Routine key, per-occurrence PDF work and two-sided document copies are addressed; the earlier introspector prerequisite is still misplaced—finding 6. |
   | 14 | **Partly** | §3.5 and 0c’s unestablished gain are improved; §0 and the ratio gate remain inconsistent/undefined—finding 8. |
   | 15 | **Partly** | Most named cases, font/date variants and fresh-process reference are present; new identity, ownership and scope cases plus independent mutations remain missing—findings 1–7. |

11. **Checked — equality inventory and the four identity routes. No additional change beyond findings 1–2 and 7.**

   | Value family | Actual Typst equality |
   |---|---|
   | None, Auto; Bool, Int, Float, Decimal; Length, Angle, Ratio, Relative, Fraction; Color, Symbol, Version, Str, Bytes, Label, Datetime, Duration | Value equality, with the listed numeric cross-kind cases; floating NaN remains nonreflexive (`library/ops.mbt:445`). |
   | Array, Dict | Recursive Value equality (`library/ops.mbt:465`). |
   | Content | Element identity plus user-visible field equality; ignores spans and other metadata (`library/content.mbt:378`). |
   | Styles, Gradient, Tiling | Typst `==` falls through to **false**, even for matching values. Memo comparison deliberately handles them structurally (`library/ops.mbt:491`, `library/memo.mbt:350`). |
   | Args | Positional and named values; not argument spans (`library/args.mbt:307`). |
   | Type; Module | Descriptor identity; module name plus inner identity today (`library/ty.mbt:85`, `library/module.mbt:188`). |
   | Func: Native, Element, Closure, With, Plugin, Host | Respectively physical descriptor identity, element identity, closure hash, recursive function/arguments, plugin state/name, physical HostFunc identity (`library/func.mbt:414`, `library/plugin.mbt:126`). |
   | Dyn: Alignment, Dir, SpotColorant, Stroke, Location, RootedPath, HtmlCss, Decoration, Loaded | Payload equality; nested values retain their own semantics (`library/dyn.mbt:11`). |
   | Dyn: Counter, State, Selector, CounterUpdate, StateUpdate, Tag | Recursive payload equality, including any nested Func/Value/Content (`library/dyn.mbt:23`; `library/counter.mbt:9`, `:785`; `library/state.mbt:9`, `:271`; `library/selector.mbt:8`; `library/introspection_tag.mbt:5`). |
   | Dyn: Regex | Pattern equality, not compiled-regex identity (`library/str.mbt:894`, `regex/regex.mbt:120`). |
   | Dyn: CellGrid | Derived structural equality; memo comparison currently rejects distinct objects (`library/grid_resolve.mbt:841`, `library/memo.mbt:384`). |
   | Dyn: InlineCallback, BlockSingleCallback, BlockMultiCallback | Captured-content equality, excluding callback function pointers (`library/container.mbt:169`, `:214`, `:301`, `:347`). |
   | Dyn: RawContent | Text/line-text equality, ignoring line spans; memo comparison restores span sensitivity (`library/text_raw.mbt:54`, `library/memo.mbt:387`). |

   Explicit `eval_string` scope values enter closures through captures; context styles are separately checked; library-supplied values, including `sys.inputs`, are covered by Library identity **if it is transitively frozen** (`eval/lib.mbt:148`, `library/memo.mbt:1005`, `library/lib.mbt:147`). The four-route argument therefore needs a complete identity classification and must cover sink payloads, not only the returned Value.

12. **Checked — remaining mechanisms and slice ordering.**

   - **EDSL span collisions alone are not a stale-origin counterexample.** Sessions reuse virtual-file/range space (`doc/origin.mbt:142`, `:518`), but review clicks and lints resolve cached spans through the **current report’s** origins/resolver (`doc/review_click.mbt:249`, `doc/lint_frames.mbt:452`). Equal content and equal spans with different current origin mappings therefore produce the same mapping as fresh compilation. Keep a regression covering review, diagnostics and container lints; do not require session identity merely because span numbers repeat.
   - **Persistent edits:** sharing old children removed from the replacement prefix/suffix is safe until a write reaches them; the design now requires copying those subsequently renumbered descendants. Partial numbering failure and full fallback are covered (`syntax/node.mbt:738`, `:794`; `syntax/reparser.mbt:41`). Unchanged `Source::replace` correctly needs no revision change (`syntax/source.mbt:82`). Process-unique construction revisions plus the full source/tree fingerprint avoid confusing two Source objects for one FileId.
   - **Works key:** explicitly name Library, full fingerprinted bibliography/citation elements—including spans and locations—route and traced state; record World/introspector/sink dependencies. Outputs contain location-keyed maps and backlinks (`library/bibliography.mbt:609`, `:1174`, `:1331`). Reuse across introspectors is sound only when those complete inputs validate; the current loose `elems == bibs_and_groups` is not the specification (`:659`). Upstream’s full signature confirms this (`.repos/typst/crates/typst-library/src/model/bibliography.rs:727`).
   - **Entry points:** trace reaches compilation; CLI query/eval reach string evaluation; `eval_root` is private; `Document::lower` is explicitly added. Direct imports and realization/test helpers are safe under the proposed no-store guard, even without opening scopes (`typst/lib.mbt:54`; `cli/query.mbt:114`; `cli/eval.mbt:96`; `eval/lib.mbt:115`; `eval/import.mbt:212`; `tests/runner/realize_stage.mbt:34`). CLI info does not enter these evaluation paths (`cli/info.mbt:34`). History is the exception in finding 5.
   - **Slice 0:** 0a is independent; 0b is independent only with its stated derived-data prerequisite and stable Library identity; 0c is independent with tagging, transforms, locations and diagnostic spans retained per occurrence (`library/image_raster.mbt:72`; `library/text_raw.mbt:204`; `pdf/image.mbt:186`, `:25`).
   - **Slice 1:** delaying cross-compilation retention until step 5 is correct, but does not justify postponing query ownership to slice 3 or claiming volatile validation is “always true” during step 1. Both can fail inside the already-enabled scopes—findings 3 and 6.
   - **Slices 2 and 3:** either order is sound once slice 1’s prerequisites are complete. Block caching does not require document caching; document caching needs its own frame/document copies and immutable introspector, regardless of block caching (`docs/incremental-design.md:878`, `:896`; `library/memo.mbt:384`).
   - **Upstream/comemo corrections hold:** bundle locator, export resolvers, HTML whitespace and math keys match `.repos/typst/crates/typst-layout/src/pages/mod.rs:102`, `typst-bundle/src/export.rs:87`, `typst-html/src/fragment.rs:42`, `typst-layout/src/math/fragment/glyph.rs:105`. Comemo accelerates return hashes, propagates validated reads, retains outputs, and increments ages before retaining `age <= max_age` (`~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/comemo-0.5.1/src/input.rs:81`, `memoize.rs:140`, `:150`).
   - **Watch boundary holds:** reset refreshes files/date; recompilation precedes eviction; reset does not rescan fonts (`cli/world.mbt:132`, `cli/watch.mbt:97`, `:103`).
