# Codex review of docs/incremental-design.md, revision 4 (gpt-6-astra, xhigh, 2026-10-07)

Reviewed: commit `4cfb4a1` (revision 4 before its answers to this review:
revision 3 plus the coordinator's decisions and the comparison of the two
ways of module equality in 5.4). Static review, read-only. A narrow round,
asked for by the coordinator: whether the nine findings of round 2 and the
eight findings of round 1 that round 2 called partly resolved are resolved
by the current text; 5.2 (volatile files within a scope); 5.4 (module
equality, the classification of identity, the comparison of the two ways);
9.1 (the checked mode); and sections 0, 6.1, 8, 10 and 11 after revision 4.
Verdict: REQUEST CHANGES. Of the seventeen rechecked findings it found
eleven resolved and six partly (R2-2, R2-3, R2-7, R1-4, R1-7, R1-15), each
of the six by one of its new findings 1 to 6. Nine findings; 10 is the
recheck and 11 what it found right.

The answers below are in revision 4 as committed after this review, and
have not been reviewed.

## What changed, and what did not

| # | finding | disposition |
| --- | --- | --- |
| 1 | Volatility only kept new entries from being stored. An entry that another world stored for a real file with a volatile path is found, and stamped, in a session where that file is volatile; `doc`'s predicate must be by path, for every snippet slot, not by what the registry holds | Accepted. 5.2: three rules (a reader is not stored, also when it ends with a kept error; a module entry is not stored for a volatile file itself; an existing entry with a read that is volatile in the scope at hand is not taken, whatever the file answers), the predicate defined on the ids `virtual_file` makes, and `History::compute` under the same predicate. A fixed scenario; mutation check 19 is "the predicate calls a volatile file stable" |
| 2 | The module comparison of revision 3 (what the modules hold, by `values_memo_equal`) is not reflexive across re-evaluation: a module that exports `float.nan` differs from its re-evaluation, and a kept `get() = m` then returns a module unequal to the current one | Accepted, by going back to the fingerprint as the relation instead of adding a representation-sensitive comparison. Two identified modules are equal if their names and fingerprints are and their flagged constituents (host functions, unidentified modules) are the same objects in visit order. The fingerprint has a float's bits. The reason it is the right relation is now said: it is what `closures_equal` and every key already treat as one value. A fixed scenario |
| 3 | Two native functions with the same texts have one fingerprint, so a closure that captured a module holding the one is found for a module holding the other; the classification was wrong (descriptors are process-wide and lazy, hosts can make more); a fifth way for identity into a result: allocation inside a host or native function | Accepted. The cause is repaired where it is: a descriptor of a native function, element or type is fingerprinted by a number given when it is made, as upstream hashes its address (`typst-utils/src/static.rs:32`); this also closes the hole within one compilation, which exists today. The classification is corrected and the fifth way added. Not done: a mechanism that makes a call uncacheable when a host function allocates an identity inside it. For host functions reached through values the key's flag does it; for those a library defines it is a contract (5.2), which the checked mode's reachability check tests |
| 4 | The shadow run must use the call at hand, not the entry's snapshots, and be isolated in more than its sink (recorder, context read flags, route tracking, traced-file log, world log); volatile reads cannot be reproduced | Accepted. 9.1, "What runs" and "Isolated from the call". Volatile files need nothing: an entry with such a read is not found, so there is no hit to shadow. That the shadow run shares the scope's table of answers and therefore does not test it is said |
| 5 | `values_memo_equal` is not an output oracle (it leaves spans, locations and lifecycles to the fingerprint, uses Typst's numeric equality, rejects distinct `CellGrid`s); introspections cannot be fingerprinted; documents and works are more than frames; stores-off recreates modules | Accepted. 9.1, "Compared": by fingerprint, and by identity where the fingerprint is flagged; per kind of result; introspections by their number only, which is said; shared flags excluded; recreated modules compare equal under 5.4's relation, NaN included |
| 6 | Mutation checks: 20 is hidden by the exact comparison of an argument; 19 was not a runnable single fault; 13 needs a kept getter; 16 and 21 must hit the producer path | Accepted. 20a (fingerprint, with the tiling captured) and 20b (equality, with it passed); 19 as above; 13, 16 and 21 with the fixtures the review names; 22 added for descriptors |
| 7 | Module equality by structural recursion does not terminate on a module that a host makes contain itself, and repeated comparisons of large modules are not cached | Moot with the answer to 2: there is no recursion. Fingerprinting ends on cycles (`library/utils_hash.mbt`) and is kept with the module |
| 8 | The alternative (b) was described too strongly (identity need not enter the fingerprint: a second key component or a comparison of captures would do) and too loosely (which entries a hit must renew); the 137 ms against 34 ms is a proxy, not an implementation | Accepted. 5.4 (b) lists the three places the identity can go, names the producers to renew and the four-entry limit, and calls the measurement a proxy with what it leaves out. The recommendation stands |
| 9 | Text: "dropped at `max_age`"; the exception to "a compilation no longer clears anything"; "every slice ends with the harness green" against slice 0 first; `node.rs:398` is synthesis, not renumbering; a `Source` handle is not a node snapshot | Accepted, all five. Section 0, 6.1, section 8, section 10 item 9 (with `node.rs:85`, `:91`, `:516` and `source.rs:24`, `:107`; a `Source` stays one object that an edit changes, and nothing kept holds one) |
| 11 | Checked and holding: nesting of volatile reads; plugin identity survives the eviction of its producer; no document of the command line has two modules with equal contents; accepting a host function that is reachable from the library | The plugin wording is corrected ("the same bytes in the same state"); the review's search for a command-line document is cited in 5.4; reachability instead of the library's serial number is in 9.1 |

## The review

REQUEST CHANGES

Static review only; no files modified. “Resolved” below means resolved by the proposed text, not implemented. Paths are repository-relative; `U/` denotes `.repos/typst/crates/`.

1. **Required — §5.2: volatility must reject existing entries, not just prevent new entries.**

   The hit rule assumes “an entry has no volatile reads.” That only describes its **creation scope**. Stores may cross Worlds, and a `FileId` is interned by path, not World (`syntax/path.mbt:135`).

   **Scenario:** World A stores a call reading a real `<edsl-origins>` file containing L. World B uses the same Library and sources, but is a doc session whose listing initially contains L. The old call’s key and recorded answers match. Nothing explicitly rejects the hit because that read is now volatile; it can be stamped. After callback lowering grows the listing, the stamped call still returns L. Re-execution returns the longer listing. The actual growth and World interception are at `doc/origin.mbt:383`, `doc/session.mbt:55`, and `doc/session.mbt:166`. The analogous previously-missing-snippet case can retain an obsolete failure.

   Require current-scope volatility checks on candidate entries’ recorded `Source`/`File` dependencies **before accepting or stamping a hit**. Reject the candidate even when its current answer matches. Apply this to module errors and Works as well as closure/layout entries.

   Define doc’s predicate using the normalized **Project-rooted, directory-qualified** IDs produced by `virtual_file`, including every possible future snippet slot—not current registry membership or bare basenames (`doc/origin.mbt:13`, `:32`, `:142`, `:518`). These paths are ordinary project paths; before registration, SessionWorld falls through to the real World (`doc/session.mbt:55`, `:63`).

2. **Required — §5.4: the proposed module comparison still permits stale observable equality for NaNs.**

   The same-object shortcut makes `m == m` reflexive, including a NaN-containing module. It does **not** make two reevaluations interchangeable: distinct Float values containing NaN fail `values_memo_equal` through ordinary floating equality (`library/memo.mbt:328`, `:357`; `library/ops.mbt:451`). `float("nan")` produces such a value (`library/float.mbt:188`; `library/funcs_gen.mbt:7350`; `library/cast.mbt:293`).

   **Scenario:** `a.typ` exports `x = float("nan")`; main imports it as `m`, defines `get() = m`, and displays `get() == m`. Change only an existing trailing comment in `a.typ`, preserving exported bindings’ spans and the module fingerprint. Reevaluation creates M₂. The unchanged getter captures an equal-fingerprinted module, so its closure hash and memo match remain equal (`library/value_hash.mbt:529`, `:556`; `library/memo.mbt:999`). Its recorded World reads are empty: it merely returns its capture. The kept getter returns M₁; proposed module equality says M₁ != M₂. From scratch, the getter returns M₂ and the comparison is true.

   Define module-content interchangeability with a reflexive, representation-sensitive comparison, including NaNs. Merely adding the outer identity shortcut does not close the original module-identity problem.

3. **Required — §5.4: exact module comparison does not close round 2’s descriptor counterexample through closures.**

   Native descriptors compare physically but fingerprint only metadata (`library/func.mbt:416`; `library/value_hash.mbt:574`). Closure equality and memo matching still compare hashes rather than captured values (`library/value_hash.mbt:556`; `library/memo.mbt:489`).

   **Scenario:** retain round 2’s immutable Library containing distinct natives `a` and `b` with identical metadata. An imported module selects `x` using `read("choice.txt")`. Main defines `get() = m.x`. Change the choice from `a` to `b`. Module evaluation correctly invalidates, and direct module-argument comparison now distinguishes the modules. However, `get`’s captured module still has the same fingerprint; its key, arguments and empty read record match. The kept getter returns `a`; from scratch it returns `b`. Comparing with `sys.inputs.b` exposes the difference.

   Strengthen memo interchangeability through closure captures, or otherwise distinguish these identities in memo validation. A module whose only exported closure hides the selected descriptor in its captured scope also defeats the claim that equal module contents are indistinguishable.

   The descriptor classification needs correction too. Generated natives and types are process-wide objects, and HTML/accent/lr tables are process-wide lazy tables—not objects owned by each Library (`library/funcs_gen.mbt:4`, `library/types_gen.mbt:4`, `library/html_typed.mbt:18`, `library/accent.mbt:87`, `library/lr.mbt:108`). Hosts can additionally construct natives, types and elements at runtime (`library/func.mbt:57`, `library/ty.mbt:27`, `library/element.mbt:166`).

   **The missing fifth route is allocation during a called host/native function.** Such a function can create and return a fresh descriptor, HostFunc or Module using public constructors (`library/func.mbt:165`, `:324`, `:355`; `library/module.mbt:43`). Explicitly prohibit identity allocation in cacheable computations, provide stable identities, or propagate non-cacheability to enclosing calls and sinks. The checked invariant currently ignores native/type/element identities entirely.

4. **Required — §9.1: a separate sink does not isolate the shadow execution.**

   A shadow must use the **current invocation’s** function, captures, arguments and contextual state, not substitute the entry’s old snapshots. Finding 3 can otherwise reproduce the stale answer in both runs.

   It also needs a private introspection recorder and saved/restored context-read flags, route tracking, traced-file tracking and World log. These are effects outside Sink: `Introspector::record` writes its recorder (`library/introspector.mbt:228`), Context methods mutate read flags (`library/engine.mbt:683`), and closure execution manages several tracking globals (`library/memo.mbt:1119`, `:1135`). Sharing them can contaminate the real enclosing entry and conceal a missing-read mutation.

   Preserve the current route, locator/location, traced span and World. Reusing the scope’s fixed `today` and nonvolatile World answers is appropriate, but then this check is not an independent test of that answer table. Volatile reads cannot generally be reproduced after a doc callback has changed the registry (`doc/session.mbt:166`); specify exclusion or a genuine snapshot mechanism.

5. **Required — §9.1: “exactly, `values_memo_equal`” is not an exact output oracle.**

   That comparator deliberately relies on an already-equal fingerprint for metadata (`library/memo.mbt:324`). Used alone:

   - It misses Content spans, locations and lifecycle, and argument spans (`library/memo.mbt:474`, `:500`; contrast `library/value_hash.mbt:319`, `:622`).
   - It accepts cross-kind numeric equality and signed-zero equality, while independently produced NaNs can report a false difference (`library/ops.mbt:451`, `:485`).
   - It already handles Styles, Gradient and Tiling specially; using Typst `==` instead would incorrectly reject them (`library/memo.mbt:350`). Distinct CellGrids are currently rejected unconditionally until slice 2’s promised comparison (`library/memo.mbt:384`).
   - “Introspections by their fingerprints” has no defined implementation: a stored Introspection contains an opaque diagnostic closure, not a fingerprintable inquiry description (`library/convergence.mbt:111`, `:119`).

   Specify comparison for every kept output: Values, modules, complete frames/documents, Works maps and embedded errors, counter sequences, and all sink payloads. Documents and Works contain more than page frames (`layout/document.mbt:5`; `library/bibliography.mbt:609`). Shared/COW flags should be ignored as bookkeeping (`library/array.mbt:15`).

   Stores-off execution also recreates imported modules (`eval/import.mbt:349`, `:359`) and plugin modules (`library/plugin.mbt:242`). Proposed content equality can reconcile these identities, but the NaN case in finding 2 causes false differences even without an edit. Under alternative (b), a shadow identity correspondence would be necessary.

6. **Required — §9.1: mutation checks 19 and 20 still need correction; several others need more precise fixtures.**

   **20:** omitting only linked-image fingerprints does not expose the stated direct `id(tiling)` scenario once SVG equality includes those images. The equal key reaches exact Tiling/Frame comparison, which safely rejects the hit (`library/memo.mbt:356`; `library/frame.mbt:558`). Use a closure **capturing** the tiling to test fingerprint coverage independently, and test equality separately.

   **19:** forcing storage while retaining the volatile mark/table bypass leaves unspecified how the entry obtains an answer fingerprint: §5.2 pairs reads with table entries that volatile reads deliberately lack. A runnable single fault is “misclassify this volatile ID as stable,” or test the forbidden insertion directly.

   **13:** require a kept getter returning a captured module, such as finding 2 with an ordinary integer export. Direct `id(m)` can simply miss under identity comparison (`library/memo.mbt:357`).

   **16/21:** assert the relevant producer path, not merely an aggregate hit. Works’ faulty shortcut needs the same introspector object (`library/bibliography.mbt:657`); History must actually compute a World-reading call rather than reuse a previously recorded closure result (`library/convergence.mbt:151`; `library/memo.mbt:1083`). Checks 6a/6b are now separated correctly; check 10 has an existing same-span/different-node fixture (`eval/captures_wbtest.mbt:335`).

7. **Required clarification — §5.4: define the domain and termination of module equality.**

   The identity shortcut handles reflexivity; NaN alone does not prove nontransitivity. Structural comparisons are symmetric. Cycles through closures stop at closure hashes, whose hashing already detects cycles (`library/value_hash.mbt:556`; `library/utils_hash.mbt:701`).

   But hosts can build **directly self-containing identified modules** before publication: `Module::canonical` is public, preserves the supplied Scope, and Scope remains bindable (`library/module.mbt:43`, `:76`; `library/scope.mbt:618`). Two such graphs can have matching terminating fingerprints while recursive module equality loops forever.

   Require visited-pair handling, or explicitly restrict identified modules and enforce that restriction. Separately, repeated comparisons of large distinct module graphs have no proposed comparison-result cache. Measure that traversal; bounded pair caching is an optional optimization under the immutable-publication contract (`library/utils_hash.mbt:578`).

8. **Required clarification — §5.4(b)/§11: the alternative’s stated necessities are too strong and incomplete.**

   Keeping identity requires distinguishing identity in **memo interchangeability**, not necessarily changing semantic `Fingerprint`/upstream Hash. A separate identity component or stricter captured-value comparison is another implementation; the port already separates hashes from argument comparison (`library/memo.mbt:217`, `:252`).

   Renewing “module entries of the sources it read” is insufficiently precise. It needs the exact producer/version whose identity survives, including plugin load/transition producers and entries displaced by the four-entry limit (`library/plugin.mbt:82`, `:87`; `library/memo.mbt:292`). Conversely, an import whose result exposes no module identity does not require that producer’s identity to survive.

   The appended-text experiment is a reasonable **narrow invalidation proxy** for closures capturing the changed module. It is not a measured implementation comparison: appended text also changes includable content (`eval/import.mbt:179`, `:207`), and the probe omitted exact argument comparisons (§8). Keep the 137/34 ms result qualified accordingly.

9. **Required textual corrections — §§0, 6.1, 8, 10.9, 11.**

   - §0 says entries are dropped “at `max_age`”; §6.1 correctly says **above** it after incrementing. Comemo retains `age <= max_age` (`~/.cargo/registry/src/*/comemo-0.5.1/src/memoize.rs:150`).
   - “A compilation no longer clears anything” and “never evict keeps everything” need the explicit exception for §5.4’s compilation-lifetime identity entries.
   - §8’s “every slice ends with the harness … green” conflicts with §§8/11’s explicit slice-0-before-harness decision. Narrow the former.
   - §10.9’s persistence principle holds, but `node.rs:398` is synthesis, not renumbering; renumbering reaches `inner_and_span_mut` at `U/typst-syntax/src/node.rs:517`.
   - Distinguish preserved **node snapshots** from preserved **Source handles**. Upstream cloned Sources retain their old inner object through `Arc::make_mut` (`U/typst-syntax/src/source.rs:24`, `:107`). The port exposes a mutable Source object (`syntax/source.mbt:15`, `:98`), and §5.4 proposes installing a new root into it. “No holder can tell the difference” overclaims unless Source snapshot semantics also change.

10. **Round 2, rechecked — all seventeen requested dispositions.**

   Remaining scenarios are specified in the findings above.

   | Earlier finding | Current disposition |
   |---|---|
   | R2-1: derived SVG fingerprints | **Resolved.** §5.5 adds linked-resource coverage to fingerprint **and equality**, closing the original tiling-through-`id` case (`library/image_svg.mbt:22`, `:501`; `library/visualize_hash.mbt:607`). |
   | R2-2: module/native identity | **Partly.** Direct descriptor fields are distinguished; captured closures still reproduce the stale result in finding 3. |
   | R2-3: volatile files | **Partly.** New volatile computations are excluded; pre-existing entries remain the counterexample in finding 1. |
   | R2-4: mutable outputs | **Resolved.** §5.4 covers traced Styles, Works arrays/errors and plugin HintedError on insertion and delivery (`library/engine.mbt:330`; `library/bibliography.mbt:705`; `library/plugin.mbt:120`). |
   | R2-5: History engines | **Resolved.** §5.2 explicitly supplies tracked Worlds to these engines, which invoke counter computations (`library/convergence.mbt:151`; `library/counter.mbt:285`). |
   | R2-6: constructors/immutability | **Resolved for its three cases.** Builder-only Libraries, bytes/index Font contract and pre-retention query ownership address the cited APIs (`library/engine.mbt:171`; `library/font.mbt:132`; `library/introspector.mbt:255`). |
   | R2-7: checked mode/mutations | **Partly.** Independent sinks and stores-off execution are improvements; findings 4–6 remain. |
   | R2-8: measurements/gate | **Resolved.** §§0/9.2 correct the attribution and define the evaluation-plus-layout gate, repetitions and named exception. |
   | R2-9: state audit/memory | **Resolved.** Sources-plus-bytes bibliography keys and retained variation/feature combinations are now acknowledged (`library/bibliography.mbt:192`; `library/font.mbt:502`). |
   | R1-4: identity-bearing outputs | **Partly.** Plugin identity is addressed; findings 2–3 remain. |
   | R1-5: introspector/document ownership | **Resolved.** Query ownership moves before retention; document copies include metadata/options (`library/introspector.mbt:255`; `layout/document.mbt:5`). |
   | R1-7: changing EDSL World | **Partly.** Finding 1 remains. |
   | R1-10: World carriers/host contract | **Resolved for the cited omissions.** History migration and immutable builder construction now accompany the explicit callback dependency contract (`library/convergence.mbt:151`; `library/lib.mbt:486`). |
   | R1-13: slice prerequisites | **Resolved.** Routine identity, per-occurrence PDF work and query/document ownership are placed before their relevant retention (`library/text_raw.mbt:210`; `pdf/image.mbt:16`). |
   | R1-14: measurement claims | **Resolved.** Probe limitations and the revised gate are explicit (§§8, 9.2). |
   | R1-15: acceptance coverage | **Partly.** Most fixed cases are present; findings 1–6 require additional or corrected coverage. |
   | R1-12: font-cache qualification | **Resolved.** §6.3 includes object-held instances and historical variations/features, with explicit clearing (`library/font.mbt:502`; `library/visualize_hash.mbt:453`). |

11. **Checked and holding, with the qualifications above.**

   - **Volatile nesting:** a clean child hit before or after its parent’s volatile read is safe; the parent remains unstoreable. Deduplication must preserve the mark independently of ordinary reads, including exceptional completion. Existing memo finalization already runs on errors (`library/memo.mbt:275`, `:1135`).
   - **Module boundaries:** an importing module’s inner volatile reads must taint both successful and failed entries (`eval/import.mbt:358`). Its *own* source is read before entering the module store (`eval/import.mbt:240`, `:250`); either explicitly prohibit that entry too or explain why its complete Source key is sufficient. Do not assume the read lies inside its log segment.
   - **Other stores:** Works becomes subject to the same taint rule; pure slice-0 caches may safely retain results keyed by already-loaded bytes/data (`library/bibliography.mbt:794`; `library/image_raster.mbt:72`; `pdf/image.mbt:186`). History must inherit the scope’s volatility predicate as well as its tracked World.
   - **Module hashing:** equal fingerprints are a necessary condition in the proposed relation; otherwise-identical closures capturing equal modules consequently hash equally (`library/value_hash.mbt:349`, `:545`). I found no second module-inner identity comparison requiring a separate change: Value and memo comparison delegate to Module equality (`library/ops.mbt:481`; `library/memo.mbt:357`). Typst dictionaries have String keys, not Module keys (`library/dict.mbt:9`).
   - **Plugins:** bytes plus transition history correctly survives producer-cache eviction; transition hashes include prior history, function and arguments (`library/plugin.mbt:220`, `:346`). Correct “two files are not [equal]” to **different plugin bytes/states**: different paths containing identical bytes already share a load (`library/plugin.mbt:242`).
   - **CLI claim:** the suggested normal CLI routes did not yield an additional fresh-compilation counterexample. Imports/includes converge on the same store; aliases do not manufacture another inner module; package IDs distinguish packages; failed evaluations return errors rather than a second successful module (`eval/import.mbt:179`, `:325`, `:368`, `:401`). `std` and `math` reuse their Library objects (`library/lib.mbt:499`, `:519`). This does not rescue the incremental NaN case.
   - **Provenance:** accepting a HostFunc reachable from the fixed Library but absent from the key is correct; Library inputs can contain arbitrary Values (`library/lib.mbt:466`). Implement this as a separate reachability check, not as inspection of the Library’s serial-number key.
   - **Slice 0c/watch:** conversion remains independent with transforms, tagging and diagnostic spans per occurrence (`pdf/image.mbt:16`, `:20`, `:37`, `:186`). Watch still resets before compilation and evicts afterwards (`cli/watch.mbt:97`, `:103`).
