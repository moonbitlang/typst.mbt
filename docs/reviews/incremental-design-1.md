# Codex review of docs/incremental-design.md, revision 1 (gpt-6-astra, xhigh, 2026-10-07)

Reviewed: commit `92b9369` (revision 1). Static review, read-only. The
prompt asked Codex to attack soundness (a stale result that is reused), the
completeness of the list of world reads, fidelity to comemo 0.5.1 and to
upstream, whether the slices are sound on their own, the measurements and
the acceptance section; it was given the document and the code paths, not
conclusions. Verdict: REQUEST CHANGES, 15 findings and a list of what it
checked and found right.

## What changed in revision 2, and what did not

Every code claim of the review that a change rests on was read again in
the code before the change was made.

| # | finding | disposition |
| --- | --- | --- |
| 1 | The errors a module entry keeps and the diagnostics of a kept sink are mutable; an import adds a tracepoint to the kept error on every reuse | Accepted. 5.3 (sink): diagnostics are copied when an entry stores them and when it hands them out. A fixed scenario and mutation check 18 in 9.1; the comparison counts tracepoints |
| 2 | `compilation_epoch` does not identify a nested compilation, so a stamp of the outer one would pass in the inner one with another world | Accepted. 5.2: scopes with a token of their own, their own table and log, restored on leaving, also by an error. The stamp is said to cover world reads only. Mutation check 17 |
| 3 | Standalone evaluation (`eval_string`, the CLI's `eval` and `query`, `Document::lower`) has no boundary: an import inside it finds module entries without a new epoch | Accepted. 5.2: every such entry point opens a scope; no store is consulted outside of one. Step 1 of slice 1 |
| 4 | Checking identity flags in keys does not protect results that hold identity-compared values (a module that holds a plugin's module without functions outlives the plugin cache's entry); "identified and equal fingerprints" is not enough for module equality when the modules hold host functions | Accepted, with another remedy than the one proposed. Not done: a transitive identity check of every result when it is stored (it would fingerprint the result of every closure call). Done instead (5.4): the modules of plugins are identified by the plugin's bytes and transitions, after which the engine makes no value that compares by identity alone; the four ways such a value can enter a kept result are listed, each with what closes it; module equality also requires the same host functions in the order the fingerprints visit them; the checked mode of 9.1 checks the invariant per entry. The sentence that IDE tracing is the only difference now says under which condition |
| 5 | The identity of an introspector is no guarantee that it answers the same: `query` hands out the array it keeps; a kept document's metadata arrays and options are shared too | Accepted. 5.3: `query` returns a view or a copy, a kept document owns its introspector; 5.4: what a document copy covers. Placed in slice 3, where a document is first kept: until then the shortcut is used within a compilation, as today |
| 6 | `RawElem::highlight` calls `routines.html_span_filled`; upstream hashes the routines; slice 0b's key lacked them | Accepted. The library object is in 0b's key |
| 7 | `doc`'s origin listing changes during a compilation, so the answers of the world are not stable for it | Accepted. 5.2: a scope is told its volatile files; a read of one is never answered from the table, and an entry that recorded one ends with its scope. Mutation check 19 |
| 8 | `works_cache` returns works by introspector identity although computing them reads the `.bib` file and the CSL style from the world | Accepted, and it is worse than the review says: it is reachable in `watch` once layouts are kept (a paragraph with a citation that found the works in the cache has no read of the `.bib` file). New section 5.5 with two rules for state outside the arguments and the audit against them; `Works::generate` becomes an entry of `memoize` (step 2 of slice 1); mutation check 16 |
| 9 | "The copied path per edit" understates what an edit writes: descendants of renumbered siblings, the root on fallback, inner records and children arrays; `Source::root`, `Source::lines` and `synthesize` are public ways to write | Accepted for the edit itself: 5.4 lists what is copied. Not accepted: making `synthesize` on a published root or a write through `Source::lines` take part in revisions. They are contract violations by a host, like changing a world during a compilation; 5.4 states the contract. (MoonBit has no read-only view of a tree to hand out instead.) |
| 10 | The leaf reads are right, but a `&World` is carried by the shaping contexts, the SVG resolvers, the bibliography functions and convergence analysis; host functions can capture anything; `Library` has a `mut` field and a mutable array | Accepted. 5.2 lists the carriers and says which run outside of memoized calls; the contract of a host function; 5.3: a library is immutable after it is built |
| 11 | Wrong or imprecise statements about upstream's signatures and about comemo (bundle locator, bundle exports, HTML fragment, math glyph keys, "every function hashes the library", the accelerator, "only hashes are kept", the debug check) | Accepted, all of them: sections 1 and 4, and the checked mode is no longer called comemo's equivalent |
| 12 | `evict(0)` does not drop the font, shaping and glyph caches; a table by the identity of bytes keeps the bytes | Accepted. 6.3 says what is true today and registers these caches with `evict(0)`; 6.1: the fingerprint tables age |
| 13 | Slice boundaries: 0b blocked by 6; 0c must keep tagging and spans per occurrence; step 2 of slice 1 was not a no-op (module equality); slice 3 must copy on insertion too | Accepted. Section 8 |
| 14 | The probe validated less than the design; "everywhere", "nothing is gained" and the ratio rule contradicted the tables; decode counts were used for the export | Accepted. 3.5 corrected and a sixth point added; section 8 says what the probe skipped and that expectations are restated after step 1; 0c's gain is "not established" with its smallest experiment; 9.2 states a ratio rule that the tables do not contradict and no absolute targets |
| 15 | The acceptance section misses these scenarios; fonts, `today` and the checked mode are under-specified; `evict(0)` is not a cold process | Accepted. 9.1: fixed scenarios, three references (a fresh process among them), the font and date cases, the checked mode compares identity flags |

## The review

REQUEST CHANGES

Static review only; no files modified. Below, `U/` means `.repos/typst/crates/`, and `C/` means `~/.cargo/registry/src/*/comemo-0.5.1/src/`.

1. **Required — §5.4/§10: retained module errors are mutable, and import tracing mutates the cached result.**

   `EvalMemo` stores the original diagnostic array and raises that same array on both insertion and hits (`eval/import.mbt:267`, `eval/import.mbt:350`, `eval/import.mbt:368`, `eval/import.mbt:389`). The enclosing import calls `trace`, which appends directly to each diagnostic’s `trace` array (`eval/import.mbt:24`, `library/diag.mbt:358`).

   **Scenario:** `main.typ` imports `bad.typ`, which contains an error. Compile once, then append a comment to `main.typ`. The main entry misses; the unchanged `bad.typ` entry matches its source, library, route, traced answers and World reads. Its error already contains the first compilation’s import trace; the second import appends another. A fresh compilation has one current trace.

   Require diagnostic snapshots on storage and delivery, including nested `trace` and `hints` arrays. Sink delivery also shares diagnostic objects today (`library/engine.mbt:375`, `library/engine.mbt:391`); “sink unchanged” needs an ownership audit.

2. **Required — §5.2: `compilation_epoch` cannot identify the proposed nested validation scopes.**

   Nested `with_layout_memo` calls receive a new memo generation, but `compilation_counter` advances only at depth zero (`library/memo.mbt:116`, `library/memo.mbt:119`). Thus the proposed separate nested answer tables still share the proposed validity stamp.

   **Scenario:** outer World A and nested World B share a Library and identical source files, but return `"A"` and `"B"` for `data.txt`. A validates an imported module reading that file. A host callback compiles B; the entry’s source/library key matches and its epoch stamp suppresses validation against B’s table. B receives `"A"`; a fresh B compilation produces `"B"`. Host functions receive the Engine and can initiate such nesting (`library/func.mbt:355`).

   Use a unique validation-scope token for every compilation invocation, restoring it with its table/log on unwind. Also state explicitly that the stamp skips **only World validation**; introspector/context/route checks still apply within the same compilation.

3. **Required — §5.2/§8: standalone evaluation has no adequate boundary.**

   `note_evaluation` is called inside `eval_source`, and advances the epoch only for a root route outside compilation (`eval/lib.mbt:22`, `library/memo.mbt:153`). `eval_string`/`eval_string_mapped` reach `eval_root`, which resets route and tracing but establishes no evaluation epoch (`eval/lib.mbt:88`, `eval/lib.mbt:110`, `eval/lib.mbt:135`). An imported-module hit returns before reaching `eval_source` (`eval/import.mbt:330`, `eval/import.mbt:349`).

   **Scenario:** evaluate a string importing `m.typ`, where `m.typ` reads `data.txt`; change only `data.txt`; evaluate the same string again. The imported source/library still match, and the previous answer table/stamp can authorize the old result.

   Define an outer evaluation scope before lookup for standalone evaluation and `Document::lower`, which also lacks a compilation wrapper (`doc/compile.mbt:439`). CLI `query` and `eval` use these entry points (`cli/query.mbt:114`, `cli/eval.mbt:96`). Deferring **memoization of strings** is fine; deferring their lifecycle is not.

4. **Required — §5.4: checking identity flags only in keys does not protect identity-bearing results.**

   Closure entries store `output.shared()` without rejecting identity-bearing outputs (`library/memo.mbt:1198`); module entries likewise retain arbitrary module contents (`eval/import.mbt:383`). An exportless plugin produces a nonidentified module (`library/plugin.mbt:386`), while plugin loads have their own independent cache (`library/plugin.mbt:242`).

   **Scenario:** `holder.typ` exports `p = plugin("empty.wasm")`, where the valid plugin exports memory but no functions. Keep importing `holder.typ` while its module entry stays hot and the underlying plugin-load entry ages out. Then add `p == plugin("empty.wasm")` to the main document. The holder’s source and recorded file bytes still match, so it returns the old plugin module; the direct load creates another. The comparison is false. After clearing all stores, both loads share the newly created module and it is true (`library/module.mbt:188`).

   Require identity checks on retained **outputs and sink contents**, transitively, or a specified lifetime relationship between producer and enclosing caches.

   The proposed module equality also needs a qualification: `canonical()` does not certify identity-free contents (`library/module.mbt:76`). Module hashing traverses the scope and propagates nested identity flags (`library/value_hash.mbt:365`). Two identified modules containing distinct host closures with the same cross-compilation key can have equal fingerprints while their fields are distinguishable (`library/func.mbt:149`). “Identified + equal fingerprint” is insufficient; the claim that IDE tracing is the only observable difference is false.

5. **Required — §5.3/§5.4/§8.3: introspector identity is not currently an immutability guarantee.**

   `ElementIntrospector::query` stores an `Array[Content]` and returns that same mutable array, including on subsequent hits (`library/introspector.mbt:695`, `library/introspector.mbt:834`). `PagedIntrospector` and `Introspector` forward it unchanged (`layout/introspect.mbt:73`, `library/introspector.mbt:255`). Yet memo validation accepts backend identity without replaying reads (`library/memo.mbt:254`).

   **Scenario:** compile a document with headings; a host obtains a query result and clears it. The backend’s query answer has changed without changing its proposed serial. A retained document shares that backend, and entries computed against it can pass the identity shortcut despite changed answers. A fresh document’s corresponding query still contains the headings.

   Make query results immutable or return independent arrays; define the cached document’s ownership of its introspector. Document copying must also cover metadata arrays and format options, not just the outer record: `DocumentInfo.author`/`keywords` are mutable arrays, and `options()` exposes the options object (`library/document.mbt:273`, `layout/document.mbt:53`).

6. **Required — §8.0b: highlighting has an omitted input before slice 1 exists.**

   `RawElem::highlight` reads `engine.routines()`; HTML highlighting invokes `routines.html_span_filled` (`library/text_raw.mbt:210`, `library/text_raw.mbt:357`). Embedders can supply that routine (`library/routines.mbt:67`, `library/lib.mbt:441`). Upstream explicitly hashes `routines` as a highlighting argument (`U/typst-library/src/text/raw.rs:528`).

   **Scenario:** compile identical raw content/styles for HTML under two libraries whose `html_span_filled` implementations differ. The proposed `(element, styles)` cache hits across them, has no World reads to invalidate, and returns the first routine’s content.

   Include routines/library identity in **slice 0b itself**. Moving derived themes into fields does not fix this omission.

7. **Required — §5.2/§7: the EDSL violates the assumed compilation-wide stability of World answers.**

   Registering an origin appends to the listing and invalidates its cached Source (`doc/origin.mbt:383`). `SessionWorld.source` and `.file` expose that changing listing (`doc/session.mbt:55`, `doc/session.mbt:63`). Callback results undergo further lowering during compilation (`doc/session.mbt:166`).

   **Scenario:** a retained plain Typst helper reads `<edsl-origins>` when its contents are L. In the next session, an early read seeds the answer table with L; callback lowering then appends an origin before invoking that helper. Its unchanged key and cached answer fingerprint still match L, although an uncached invocation now reads the extended listing. The helper need not have a HostFunc in its key.

   Specify versioned answers/invalidation for virtual files, or exclude their dependent entries from retention. Merely dropping callback-keyed entries does not establish the required World invariant.

8. **Required — §4/§6.3: `works_cache` is another dependency-hiding global cache.**

   `Works::generate` accepts its last result solely by introspector object identity and equal bibliography/citation elements (`library/bibliography.mbt:645`, `library/bibliography.mbt:657`). Its miss path reads bibliography and CSL data from the World (`library/bibliography.mbt:794`). Those elements retain sources that are loaded again by `database` and `derived_style`; they do not universally contain the loaded data claimed in §8 (`library/bibliography.mbt:119`, `library/bibliography.mbt:481`).

   **Scenario:** a host retains an introspector containing the same bibliography elements, changes the `.bib` title or CSL file, and calls `Works::generate` with the current World. The cached Works entry matches without performing any World read and returns old formatted content; clearing it produces the new content.

   This is a concrete public-API case, not a demonstrated ordinary-watch path. Nevertheless, the design supports retained Worlds and must clear, validate or replace this cache before claiming complete dependency tracking.

9. **Required — §5.4: “the copied path per edit” understates both mutation coverage and cost.**

   Renumbering recursively writes descendants, not merely sibling roots (`syntax/node.mbt:650`, `syntax/node.mbt:661`). Reparse fallback overwrites the root, and unsuccessful local replacement can precede fallback (`syntax/reparser.mbt:41`, `syntax/reparser.mbt:147`). Copying node wrappers while sharing mutable inner records/children is insufficient.

   Other public mutation paths remain: `Source::root` exposes the actual node; `Source::lines` exposes mutable Lines; synthesis rewrites spans, numbering bounds and diagnostic hints (`syntax/source.mbt:50`, `syntax/source.mbt:69`, `syntax/node.mbt:836`, `syntax/node.mbt:889`).

   **Scenario:** after a Source fingerprint is cached by its revision, a host synthesizes its exposed root without calling `Source::edit`. The revision-based fingerprint lookup and retained entry still match, but a fresh evaluation sees different diagnostic spans/hints.

   Specify recursive persistence for every affected subtree and either prohibit these mutations after publication or make them participate in revision/snapshot management. Ordinary `eval_string` synthesizes newly parsed trees, which is safe (`eval/lib.mbt:80`).

10. **Required — §5.2: the leaf-read census is substantially correct; the migration and host contracts are incomplete.**

   I found no additional built-in filesystem/clock bypass in the requested engine packages. However, replacing `Engine.world` alone does not cover all raw-World carriers:

   - `SharedShapingContext::world`, including `MathShapingContext`, exposes/stores `&World` (`layout/inline_shaping.mbt:1187`, `layout/math_shaping.mbt:119`).
   - SVG font/image resolvers store it and use it through parsing callbacks (`library/image_svg.mbt:86`, `library/image_svg.mbt:243`, `library/image_svg.mbt:415`).
   - Bibliography `keys`, `database`, `csl_style`, and convergence-history evaluation take raw Worlds (`library/bibliography.mbt:99`, `library/bibliography.mbt:121`, `library/convergence.mbt:114`, `library/convergence.mbt:151`).
   - Native/host callbacks receive Engine but may also capture arbitrary external data or another World (`library/func.mbt:149`, `library/func.mbt:324`, `library/func.mbt:355`).

   List these propagation points and specify dependency/purity requirements for callbacks. A private wrapper field cannot constrain captured references. Likewise, a Library serial requires an explicit immutability/versioning contract: Library currently exposes mutable features and a mutable formats array (`library/engine.mbt:186`).

11. **Required — §1/§4: several “upstream” signatures and comemo descriptions are inaccurate.**

   Correct the inventory before using it to derive keys:

   | Claim | Code |
   |---|---|
   | Bundle document locator is hashed | It is tracked: `U/typst-layout/src/pages/mod.rs:110`. |
   | Bundle exports have no tracked inputs | PDF, SVG and HTML track `LateLinkResolver`: `U/typst-bundle/src/export.rs:91`, `:115`, `:148`. |
   | HTML fragment is simply “as the paged ones” | It additionally hashes `whitespace`: `U/typst-html/src/fragment.rs:52`. |
   | Math glyph keys are “world reads, styles, text” | World is tracked; class/math size and stretch or features are hashed: `U/typst-layout/src/math/fragment/glyph.rs:105`, `:143`. |
   | Every memoized compiler function hashes Library | Highlighting takes Routines; the math functions above take neither Library nor Routines. |
   | PDF raster conversion key is just image | Upstream takes image and interpolation; the proposal’s slice-0c table correctly includes interpolation. |

   Comemo’s accelerator caches **validation return hashes per tracking ID**, not arbitrary actual method results once per reference (`C/input.rs:81`, `C/track.rs:25`). Eviction invalidates old accelerator IDs (`C/accelerate.rs:24`, `:41`).

   “Only hashes are kept” needs narrowing: cached outputs and tracked-call payloads are retained (`C/memoize.rs:183`, `C/tree.rs:117`). Its debug nondeterminism checks detect inconsistent call sequences/answers; they do not rerun hits and compare outputs (`C/tree.rs:99`, `C/constraint.rs:117`). The proposed checked mode is different, not an equivalent implementation.

12. **Required — §6.3: `evict(0)` does not establish the stated font-cache bound.**

   The existing eviction function clears the listed decode/plugin caches but no font, shaping or glyph caches (`library/memo.mbt:175`). `font_data_hashes` itself strongly retains every Bytes object inserted (`library/visualize_hash.mbt:453`, `:467`); shaping and glyph maps similarly retain font-keyed entries (`layout/inline_shaping.mbt:17`, `:48`, `library/font_color.mbt:66`).

   Replacing fonts repeatedly therefore retains old fonts, even when the host follows the stated `evict(0)` advice. Specify actual clearing/aging registrations or withdraw that bound. The new identity-keyed byte-hash cache needs the same treatment: a table retaining the bytes cannot rely on those bytes becoming unreachable to remove its entry.

13. **Required clarification; optional optimization — §8: the slices need stronger boundaries.**

   **0a** is independent of World: raster decoding, EXIF, DPI and ICC resolution use the supplied inputs (`library/image_raster.mbt:72`). **0b** is blocked by finding 6. **0c** can be independent if it caches `convert_raster`, preserving per-occurrence tagging, locations and error spans outside it (`pdf/image.mbt:16`, `:25`, `:37`, `:186`).

   **1** needs findings 1–10 resolved before retention. Step 1.2 is not literally a results no-op: its module-equality change affects observable equality immediately (`library/module.mbt:188`).

   **2** has no obvious later-slice dependency, provided `CellGrid` equality is implemented and measured; today its nonidentical case returns false (`library/memo.mbt:384`).

   **3** needs copies at insertion as well as delivery. The generic helper already does both, but its new copy functions must include all page frames and document state (`library/memo.mbt:264`, `:289`); page finalization consumes several frames (`layout/pages_finalize.mbt:56`, `:63`, `:71`).

   Cheaper first work: compilation-local raster reuse and export-local conversion/stream reuse already remove repeated work without cross-compilation lifetime machinery. Deferring SVG/string memoization is optional; migrating their World plumbing and evaluation scopes is required now.

14. **Required — §3/§9.2: the measurements do not support the acceptance thresholds or all stated conclusions.**

   The probe deliberately omits closure/layout World validation and exact argument checks (§3.1, `docs/incremental-design.md:145`). Production costs additionally include read collection/merging, numbered-source hashing, persistent edits, structural `CellGrid` comparison and safe result copies. The current memo implementation performs exact comparisons and copies (`library/memo.mbt:252`, `:264`, `:289`); bypassing them is not a measurement of the proposed implementation.

   Specific inconsistencies:

   - “Block level … everywhere” is contradicted by deck unchanged **319 → 320 ms**, middle **326 → 331 ms** (§3.3).
   - “Nothing is gained” on package-wide edits overstates the table: touying’s existing kept stores give **151 → 116 ms** (§3.3).
   - §9.2 permits approximately **2.7×** upstream while simultaneously forbidding ratios above cold **2.2–2.5×**. Showcase’s end edit is **19/7 ≈ 2.71×**.
   - The image counts concern different stages: **228 decodes versus 72 export conversions**. They do not justify extrapolating one stage’s savings to the other; 0c is explicitly unprototyped (`docs/incremental-design.md:277`, `:686`).

   Require validated measurements before fixing the 10% gate. Treat these rows as optimistic experiments, not established targets.

15. **Required — §9: the acceptance suite misses the counterexamples above.**

   Add explicit checks for repeated failed imports after main-only edits; nested Worlds with different answers and exception unwinding; standalone string evaluations between updates; a hot parent surviving plugin-child eviction; identified modules containing identity-bearing fields; mutation of returned query arrays/document options/metadata; EDSL virtual-file growth; retained-introspector bibliography regeneration; and highlighting under different routines.

   Separate font-book mutation from replacement of font bytes with unchanged metadata, plus removal/reordering of indices. Upstream explicitly permits validation with obsolete font indices (`U/typst-library/src/lib.rs:85`), whereas the port’s trait does not state that requirement (`library/engine.mbt:133`). Test `today` with distinct offsets and `None`/success transitions, not just a changed successful date (`library/datetime.mbt:305`).

   The checked mode must compare observable identity behavior and independent snapshots: equal fingerprints alone cannot detect finding 4 (`library/utils_hash.mbt:336`). An `evict(0)` reference is not a wholly cold process given finding 12; include a fresh-process reference for global-cache tests.

16. **Checked — no change required for these narrower claims.**

   Eviction arithmetic matches comemo’s implementation: increment, retain `age <= max_age`, reset hits to zero; its comment is misleading, the design’s rule is correct (`C/memoize.rs:150`, `:166`).

   A validated comemo hit emits reads to the enclosing constraint, including accelerated validations; mutable calls are replayed (`C/input.rs:93`, `:138`, `C/memoize.rs:57`).

   Upstream Source hashing includes the numbered tree, including spans and numbering bounds (`U/typst-syntax/src/source.rs:27`, `U/typst-syntax/src/node.rs:17`, `:639`).

   Upstream FileSlot really reuses and edits its Source; so does the port (`U/typst-kit/src/files.rs:213`, `kit/files.mbt:223`).

   Watch resets files/date and then evicts after recompilation; reset does not rescan fonts (`cli/world.mbt:132`, `cli/watch.mbt:97`, `:103`).

   Existing frame cloning and state-value sharing support their stated ownership rules; they do not establish ownership for the additional objects identified above (`library/frame.mbt:79`, `library/state.mbt:144`, `:156`, `library/counter.mbt:291`).
