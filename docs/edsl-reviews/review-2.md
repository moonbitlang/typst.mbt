codex
Revision 2 still needs changes. The main remaining blocker is that callbacks can create description nodes during layout, while their provenance must supposedly be allocated before lowering.

The saved review contains **17 distinct findings, duplicated**, rather than 15. I assessed all 17 below. “RESOLVED” means the design addresses the finding; it does not mean the proposed implementation already exists.

1. **PARTIAL — Faithful element construction.**

   The dispatch is now correct: [design:102](/Users/dii/git/typst.mbt/docs/edsl-design.md:102) uses `Func::element(...).call`, whose element branch invokes construction and then `args.finish()`. Custom constructors and parsers therefore execute. [func.mbt:276](/Users/dii/git/typst.mbt/library/func.mbt:276), [element.mbt:326](/Users/dii/git/typst.mbt/library/element.mbt:326)

   However, the generator rule that required fields become required positional parameters remains incorrect. `LinkElem.body` is marked required in metadata, but its parser permits omission for URL destinations. Thus the stated generator would make the promised `Link(url)` impossible. `TextElem` likewise has both an external required `body` and a required stored `text`, although construction accepts only the former. [design:157](/Users/dii/git/typst.mbt/docs/edsl-design.md:157), [manifest.json:6426](/Users/dii/git/typst.mbt/gen/manifest.json:6426), [link.mbt:19](/Users/dii/git/typst.mbt/library/link.mbt:19), [upstream text/mod.rs:852](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/text/mod.rs:852)

   **Fix:** Specify reviewed constructor-signature overrides for custom constructors/parsers. Storage metadata alone is insufficient.

2. **PARTIAL — Explicit construction environment.**

   Immutable descriptions lowered inside a compilation environment solve eager `Image(...)` construction and independently assembled fragments. But “lowering runs once” does not cover descriptions created by show/context callbacks, explicitly permitted at [design:226](/Users/dii/git/typst.mbt/docs/edsl-design.md:226). Their construction needs the current callback’s engine/context and the same provenance owner.

   **Fix:** Define separate initial-tree lowering and callback-result lowering. Initial lowering should use the evaluator’s non-contextual environment; callback lowering should use the actual invocation context. The evaluator deliberately starts source evaluation with `Context::none()`. [eval/lib.mbt:19](/Users/dii/git/typst.mbt/eval/lib.mbt:19) See new issue N1.

3. **PARTIAL — Host identity, fingerprints, memoization and convergence.**

   Fresh identities, identity equality, identity-bearing fingerprints and rejection of new layout-time host callbacks address the original capture-collision problem. The proposed flag correctly reaches frame cacheability and prevents memo reuse across introspectors for identity-bearing recorded reads. [design:266](/Users/dii/git/typst.mbt/docs/edsl-design.md:266), [memo.mbt:139](/Users/dii/git/typst.mbt/library/memo.mbt:139), [memo.mbt:500](/Users/dii/git/typst.mbt/library/memo.mbt:500)

   The convergence guarantee is still only asserted. `RecordedRead` stores an expected hash and a hash-producing replay function; `validate` compares those hashes regardless of the identity/lossy flag. Setting `fingerprint_identity` cannot implement “never compared by fingerprint alone.” [introspector.mbt:202](/Users/dii/git/typst.mbt/library/introspector.mbt:202), [introspector.mbt:460](/Users/dii/git/typst.mbt/library/introspector.mbt:460), [introspector.mbt:506](/Users/dii/git/typst.mbt/library/introspector.mbt:506)

   **Fix:** Specify the recorder change: retain an expected result or an exact validation closure, using identity-aware recursive comparison where required. Do not simply reject every identity-bearing convergence check—that would make stable queries containing host functions fail to converge.

4. **RESOLVED — Autoloc versus source-character mapping.**

   The three tiers, explicit source provider, restriction to plain literals, array-argument fallback and located `T(...)` constructor address the original overclaim. [design:292](/Users/dii/git/typst.mbt/docs/edsl-design.md:292) This matches the actual information available: `SourceLoc` identifies a source range, while `ArgsLoc` contains optional argument locations, not decoded-string mappings. [autoloc.mbt:24](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:24), [autoloc.mbt:94](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:94)

   Allocation and retention of these origins remain separate problems under findings 5 and N1/N5.

5. **PARTIAL — Span encoding and integration.**

   A real UTF-8 origin buffer makes range spans compatible with `world_range` and diagnostic line lookup. Checking endpoints against **8,388,607**, rather than allowing saturation, is correct. [span.mbt:95](/Users/dii/git/typst.mbt/syntax/span.mbt:95), [engine.mbt:122](/Users/dii/git/typst.mbt/library/engine.mbt:122), [diagnostics.mbt:138](/Users/dii/git/typst.mbt/kit/diagnostics.mbt:138)

   Three details remain unresolved:

   - Per-markup virtual files fall outside the “one file ID” account. Their reuse and capacity policy is unspecified; interner exhaustion aborts. [design:343](/Users/dii/git/typst.mbt/docs/edsl-design.md:343), [syntax/path.mbt:83](/Users/dii/git/typst.mbt/syntax/path.mbt:83)
   - The proposed long-text fallback cannot detect overflow from glyph offsets alone: collection can replace an overflowing offset with zero, and shaping saturates other offsets. [inline_collect.mbt:359](/Users/dii/git/typst.mbt/layout/inline_collect.mbt:359), [inline_shaping.mbt:637](/Users/dii/git/typst.mbt/layout/inline_shaping.mbt:637)
   - `Func::call` does not attach the node span to constructed content. `Content::from_fields` starts detached; the evaluator separately spans displayed expressions and wraps calls with tracing. [content.mbt:29](/Users/dii/git/typst.mbt/library/content.mbt:29), [eval/markup.mbt:77](/Users/dii/git/typst.mbt/eval/markup.mbt:77), [eval/call.mbt:121](/Users/dii/git/typst.mbt/eval/call.mbt:121)

   **Fix:** Specify span attachment and tracing explicitly, bound/reuse snippet IDs, and retain overflow information or conservatively downgrade whole oversized text origins.

6. **PARTIAL — Resource-root resolution.**

   Converting direct resource arguments to `RootedPath` avoids resolving them relative to the origin filename. [loading.mbt:49](/Users/dii/git/typst.mbt/library/loading.mbt:49), [library/path.mbt:72](/Users/dii/git/typst.mbt/library/path.mbt:72)

   However, the blanket policy at [design:333](/Users/dii/git/typst.mbt/docs/edsl-design.md:333) does not match the unchanged engine:

   - SVG references resolve relative to the **SVG file**, so `assets/chart.svg` containing `href="plot.png"` loads `assets/plot.png`. Byte-backed SVGs instead use the argument span’s file ID, so diagnostic origins still affect resolution. [image.mbt:91](/Users/dii/git/typst.mbt/library/image.mbt:91), [image_svg.mbt:474](/Users/dii/git/typst.mbt/library/image_svg.mbt:474)
   - `eval_string_mapped` has no independent import-base parameter. Imports evaluated inside its string resolve through their mapped spans. [eval/lib.mbt:88](/Users/dii/git/typst.mbt/eval/lib.mbt:88), [eval/import.mbt:212](/Users/dii/git/typst.mbt/eval/import.mbt:212)
   - Pre-rooting changes observable values: image construction stores the supplied source value, so a string source becomes a path value. It also bypasses the string-specific network-access hint. [image.mbt:16](/Users/dii/git/typst.mbt/library/image.mbt:16), [loading.mbt:61](/Users/dii/git/typst.mbt/library/loading.mbt:61)

   **Fix:** Distinguish direct document resources from dependencies inside loaded files. Either anchor synthetic files at the virtual project root while preserving strings, or introduce an explicit resolution mechanism. Define functional twins for any intentional source-value changes.

7. **PARTIAL — Absent, auto, none and custom values.**

   The four-state distinction and `numbering? : Numbering?` are correct. Internally, that parameter is `Numbering??`: omission is `None`, explicit none is `Some(None)`, and explicit numbering is `Some(Some(n))`.

   But `level=Some(2)` is inconsistent with `level? : Smart[Int]`. Repository `Smart` has `Auto` and **`Custom`**, not `Some`. [design:128](/Users/dii/git/typst.mbt/docs/edsl-design.md:128), [auto.mbt:5](/Users/dii/git/typst.mbt/library/auto.mbt:5)

   The claimed full value domain also conflicts with using 32-bit `Int` for fields whose engine representations contain `Int64`. [design:144](/Users/dii/git/typst.mbt/docs/edsl-design.md:144), [int_casts_gen.mbt:439](/Users/dii/git/typst.mbt/library/int_casts_gen.mbt:439)

   **Fix:** Use `Custom(2)` with a defined `Smart` facade, and suitable 64-bit author-facing integers before engine validation—or explicitly document narrower limits.

8. **RESOLVED — Set-rule ordering, folding and flags.**

   The ordered rule collection, right nesting, and `Element::set(...).spanned(...).liftable()` match evaluation. Leaving `outside` to realization is correct. This preserves repeated properties and folding rather than reducing styles to a last-value dictionary. [design:201](/Users/dii/git/typst.mbt/docs/edsl-design.md:201), [eval/rules.mbt:27](/Users/dii/git/typst.mbt/eval/rules.mbt:27), [styles.mbt:539](/Users/dii/git/typst.mbt/library/styles.mbt:539), [realize.mbt:669](/Users/dii/git/typst.mbt/realize/realize.mbt:669)

9. **PARTIAL — Text, sequences and labels.**

   Literal strings now have the correct functional interpretation. The actual conversion is `FromValue for Content`, whose string branch constructs `TextElem`. [cast.mbt:481](/Users/dii/git/typst.mbt/library/cast.mbt:481)

   The sequence and label specifications are still wrong:

   - `Content::sequence` handles empty/singleton cases but **does not recursively flatten**. `Content::add`, used by the proposed Typst twin, has different sequence concatenation behavior. [content.mbt:404](/Users/dii/git/typst.mbt/library/content.mbt:404), [content.mbt:483](/Users/dii/git/typst.mbt/library/content.mbt:483)
   - Markup label attachment scans preceding expression results; it does not descend into a returned sequence to label its last eligible child. The upstream test explicitly checks the label on the sequence itself. [design:111](/Users/dii/git/typst.mbt/docs/edsl-design.md:111), [eval/markup.mbt:47](/Users/dii/git/typst.mbt/eval/markup.mbt:47), [upstream label.typ:52](/Users/dii/git/typst.mbt/.repos/typst/tests/suite/foundations/label.typ:52)

   **Fix:** Define whether `Seq` preserves nesting or concatenates, and choose the matching twin. Specify `Labelled(n,l)` against one inserted expression result, preserving wrappers/sequences, duplicate-label warnings and empty-name validation.

10. **PARTIAL — Show-rule lifecycle and selectors.**

    Preserving the exact matched content resolves the guard/location/preparation problem. The engine passes `elem.guarded(guard_)` to the recipe, and the proposed view can return that unchanged. Show-selector validation also selects the correct cast path. [design:214](/Users/dii/git/typst.mbt/docs/edsl-design.md:214), [realize.mbt:369](/Users/dii/git/typst.mbt/realize/realize.mbt:369), [selector.mbt:425](/Users/dii/git/typst.mbt/library/selector.mbt:425)

    `ShowSet` still appears only as an example/test requirement; its lowering is not defined. Furthermore, `Recipe::new` alone omits evaluator warnings for unsupported `show page` and obsolete paragraph/block-spacing rules. [eval/rules.mbt:51](/Users/dii/git/typst.mbt/eval/rules.mbt:51), [eval/rules.mbt:65](/Users/dii/git/typst.mbt/eval/rules.mbt:65)

    **Fix:** Specify `Transformation::Style` lowering, including selector validation and ordered set styles, and share the evaluator’s recipe checks.

11. **PARTIAL — Ctx lifetime, capabilities, typing and errors.**

    Invocation tokens, typed selectors and content-based updates are improvements. However, [design:238](/Users/dii/git/typst.mbt/docs/edsl-design.md:238) does not complete the contract:

    - Query needs contextual access; measurement requires both styles and a location. A show callback may have styles without a location. [engine.mbt:544](/Users/dii/git/typst.mbt/library/engine.mbt:544), [query.mbt:31](/Users/dii/git/typst.mbt/library/query.mbt:31), [measure.mbt:15](/Users/dii/git/typst.mbt/library/measure.mbt:15)
    - Query must validate through `LocatableSelector`, not merely accept any `Selector[V]`. [selector.mbt:351](/Users/dii/git/typst.mbt/library/selector.mbt:351)
    - `state(key)` does not specify initialization or functional updates. Engine state carries an initial `Value`. [state.mbt:9](/Users/dii/git/typst.mbt/library/state.mbt:9)
    - `Step | Set(n)` omits counter levels and multi-component states. [counter.mbt:767](/Users/dii/git/typst.mbt/library/counter.mbt:767)

    **Fix:** Publish fallible operation/callback signatures, capability requirements, state initialization/update types, and full counter-update types. Apply token checks to derived handles too.

12. **PARTIAL — Coherent MoonBit API and examples.**

    The following language choices are sound:

    - `fn T::T(...) -> T` true constructors.
    - `#callsite(autofill(loc, args_loc))` with labelled location parameters.
    - The object-safe `IntoContent` trait and contextual coercion into `Array[&IntoContent]`.
    - Deliberate nested optionality for `numbering`.
    - Ordinary `standards=`, `tagged=` and `ppi=` calls.

    These follow the [constructor/argument rules](https://docs.moonbitlang.com/en/latest/language/fundamentals.html#custom-constructors) and [trait-object rules](https://docs.moonbitlang.com/en/latest/language/methods.html#trait-objects).

    Remaining problems:

    - `level=Some(2)` is wrong for repository `Smart`.
    - The `Context(fn ... )` example calls fallible contextual operations without `raise`; explicit `fn` literals do not infer raising effects. [design:234](/Users/dii/git/typst.mbt/docs/edsl-design.md:234), [MoonBit local-function rules](https://docs.moonbitlang.com/en/latest/language/fundamentals.html#local-functions)
    - `Markup(..., scope?=[...])` and `block?=false` still misuse optional forwarding if intended as calls. [design:343](/Users/dii/git/typst.mbt/docs/edsl-design.md:343)
    - `Seq(xs)` has no specified signature supporting existing typed arrays; `Block([h, Line(...)])` and `Par([...])` lack a stated array-to-content adapter.
    - `label=` and `key=` are advertised but absent from the representative constructor signature.
    - `Rule`/style conversion interfaces are missing, so heterogeneous rule examples cannot yet be checked.

    **Fix:** Supply the missing facade declarations and an external compiling consumer. Prefer an explicitly typed heterogeneous `Seq` constructor plus a separate generic collection helper.

13. **PARTIAL — Compile split and world contract.**

    The listed responsibilities of `compile_content` accurately cover the current target gates, styles, memo lifetime, introspection loop, convergence handling and delayed errors. `DocWorld` now has a useful ownership/input contract, and HTML correctly uses its own target. [design:354](/Users/dii/git/typst.mbt/docs/edsl-design.md:354), [typst/lib.mbt:74](/Users/dii/git/typst.mbt/typst/lib.mbt:74)

    The public result/export contract remains inconsistent: compilation returns `Warned[Result[PagedDocument,...]]`, but the next expression produces bare `Bytes` without defining error handling or preservation of export warnings. PDF export itself returns another `Warned[Result[...]]`. [design:362](/Users/dii/git/typst.mbt/docs/edsl-design.md:362), [pdf/lib.mbt:10](/Users/dii/git/typst.mbt/pdf/lib.mbt:10)

    **Fix:** Define composable compilation/export reports and warning propagation. See N5 for the related provenance ownership defect.

14. **PARTIAL — Markup/math evaluation, scope and feature surface.**

    Mapped evaluation, explicit scope injection and avoiding a second equation wrapper are correct choices. Math mode really returns an equation with `block=false`. [eval/lib.mbt:88](/Users/dii/git/typst.mbt/eval/lib.mbt:88), [eval/lib.mbt:139](/Users/dii/git/typst.mbt/eval/lib.mbt:139)

    But the description representation is only `Markup(String, Origin)`: it has nowhere to retain the advertised scope. Math-mode representation and its relationship to the generated `Equation(body, ...)` constructor are also unspecified. [design:85](/Users/dii/git/typst.mbt/docs/edsl-design.md:85), [design:343](/Users/dii/git/typst.mbt/docs/edsl-design.md:343)

    **Fix:** Represent evaluation mode, scope descriptions and equation options explicitly. Define a distinct math-string convenience constructor if necessary. Specify mapped-file registration/reuse and the import-base behavior identified in finding 6. The feature matrix helps, but does not replace these contracts.

15. **RESOLVED — Purity and determinism claims.**

    Revision 2 correctly removes invocation-count guarantees, permits skipped executions through memo reuse, covers custom `IntoContent` implementations and captured mutation, and describes determinism checking as a frozen-input heuristic reporting candidate origins. [design:279](/Users/dii/git/typst.mbt/docs/edsl-design.md:279) This matches the actual layout-level memoization model. [memo.mbt:120](/Users/dii/git/typst.mbt/library/memo.mbt:120)

16. **PARTIAL — Equivalence tests and phasing.**

    Excluding spans and adding behavioral/provenance tests improves the plan. But “frames identical, spans excluded” still needs an explicit normalizer for span offsets, location relationships and embedded host-versus-evaluator function values. The existing dump includes both glyph spans and offsets. [design:413](/Users/dii/git/typst.mbt/docs/edsl-design.md:413), [frame_dump.mbt:350](/Users/dii/git/typst.mbt/tests/runner/frame_dump.mbt:350)

    The phase-1 showcase requires citations/bibliography, gradients and contextual headers/footers, while their prerequisites remain in phase 2. [design:391](/Users/dii/git/typst.mbt/docs/edsl-design.md:391), [design:433](/Users/dii/git/typst.mbt/docs/edsl-design.md:433)

    **Fix:** Define structural, behavioral and export equivalence separately; include memo-on/off comparisons and invalid inputs. Move showcase prerequisites earlier or reduce the first milestone. Specify the IDE adaptation: upstream click mapping requires `source.find(span)`, which an origin listing does not satisfy. [jump.rs:268](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-ide/src/jump.rs:268)

17. **PARTIAL — Units and package placement.**

    Package placement and explicit reliance on public APIs are resolved. The units policy is not: `Rel`, `Pt`, `Pct` and mixed-unit addition appear without their definitions or conversion rules. [design:51](/Users/dii/git/typst.mbt/docs/edsl-design.md:51), [design:151](/Users/dii/git/typst.mbt/docs/edsl-design.md:151)

    **Fix:** Define one common units representation or explicit promotion rules, legal field conversions, error locations and arithmetic order. `Add` remains homogeneous, and the engine’s `Rel` is generic. [operators.mbt:17](/Users/dii/.moon/lib/core/builtin/operators.mbt:17), [rel.mbt:5](/Users/dii/git/typst.mbt/library/rel.mbt:5)

Revision 2 also introduces these concrete issues:

- **N1 — NEW BLOCKER: The prebuilt origin buffer cannot represent callback-created nodes.**

  The callback example constructs `Block` and `Line` only when invoked; fresh headings are explicitly allowed. Those nodes are absent from the initial description tree, yet every node must already have a line in a buffer built before lowering. Rejecting newly created **host callbacks** does not reject these ordinary nodes. [design:219](/Users/dii/git/typst.mbt/docs/edsl-design.md:219), [design:275](/Users/dii/git/typst.mbt/docs/edsl-design.md:275), [design:308](/Users/dii/git/typst.mbt/docs/edsl-design.md:308)

  **Concrete fix:** Define callback-result lowering and stable lazy origin registration. Existing span allocations must remain unchanged across iterations; source-site identity must be separate from runtime occurrence/text identity. Freeze and retain the resulting source registry with the compilation report. Alternatively, prohibit all callback-created descriptions—but that would invalidate the advertised API.

- **N2 — NEW MAJOR: The unconditional construction rule excludes `Context` and update nodes.**

  “The EDSL never constructs element storage directly” cannot implement `Context` through the required `Func::element(...).call` path: its construct hook always reports `cannot be constructed manually`. The evaluator creates its storage directly. State-update construction has the same restriction. [design:15](/Users/dii/git/typst.mbt/docs/edsl-design.md:15), [context.mbt:7](/Users/dii/git/typst.mbt/library/context.mbt:7), [eval/code.mbt:385](/Users/dii/git/typst.mbt/eval/code.mbt:385), [state.mbt:296](/Users/dii/git/typst.mbt/library/state.mbt:296)

  **Concrete fix:** Restore an explicit audited exception list for evaluator-internal constructs, using the same construction helpers/storage paths as evaluation. Restrict generator coverage to public author-facing operations, rather than every engine element indiscriminately.

- **N3 — NEW MAJOR: `ElemCall.elem : String` has no unambiguous element identity.**

  The new representation stores the “engine element name,” but names are not globally unique. Grid and table cells are both `"cell"`; headers, footers, lines and several other elements also collide. [design:89](/Users/dii/git/typst.mbt/docs/edsl-design.md:89), [elems_gen.mbt:1204](/Users/dii/git/typst.mbt/library/elems_gen.mbt:1204), [elems_gen.mbt:6655](/Users/dii/git/typst.mbt/library/elems_gen.mbt:6655)

  **Concrete fix:** Store an `Element` handle or generated unique element key. Give the generic escape hatch canonical qualified names such as `table.cell` and `grid.cell`, with explicit scope resolution.

- **N4 — NEW MAJOR: The public description representation is mutable and can be cyclic.**

  `pub(all) enum Node` exposes `Seq(Array[Node])` and `Styled(Array[Rule],...)`. MoonBit arrays are mutable references: retaining and mutating the input array changes an already-built description. Public construction also permits a sequence array to contain its own enclosing node, producing a cycle. This contradicts the immutable-tree invariant used by preallocation and lowering. [design:8](/Users/dii/git/typst.mbt/docs/edsl-design.md:8), [design:77](/Users/dii/git/typst.mbt/docs/edsl-design.md:77)

  **Concrete fix:** Make nodes opaque and defensively snapshot collection inputs, or expose a truly immutable representation. If arbitrary graph construction remains public, specify cycle validation and diagnostics.

- **N5 — NEW MAJOR: Provenance ownership contradicts the compilation return type, especially on failure.**

  The design retains origins in `CompiledDocument.origins`, but `compile_paged` returns a bare engine `PagedDocument` inside `Warned[Result[...]]`. Neither that document nor `Warned` contains the promised resolver/source snapshot. On compilation failure there is no compiled document at all, although diagnostics still reference virtual files. Reusing their IDs during a later compilation can then make old diagnostics resolve against different contents. [design:328](/Users/dii/git/typst.mbt/docs/edsl-design.md:328), [design:362](/Users/dii/git/typst.mbt/docs/edsl-design.md:362), [layout/document.mbt:5](/Users/dii/git/typst.mbt/layout/document.mbt:5), [diag.mbt:294](/Users/dii/git/typst.mbt/library/diag.mbt:294)

  **Concrete fix:** Return a compilation report that owns immutable origins and virtual-source snapshots on **both success and failure**. Successful output can contain `CompiledDocument[T]`; export reports should retain that resolver and combine compilation/export warnings.

This was a read-only review against the repository, pinned upstream and MoonBit language documentation. No files were changed. Executable API validation remains unproven: `moonc check -no-mi` attempted to write an AST artifact and was blocked by the read-only sandbox.

VERDICT: REQUEST CHANGES
tokens used
225,689
Revision 2 still needs changes. The main remaining blocker is that callbacks can create description nodes during layout, while their provenance must supposedly be allocated before lowering.

The saved review contains **17 distinct findings, duplicated**, rather than 15. I assessed all 17 below. “RESOLVED” means the design addresses the finding; it does not mean the proposed implementation already exists.

1. **PARTIAL — Faithful element construction.**

   The dispatch is now correct: [design:102](/Users/dii/git/typst.mbt/docs/edsl-design.md:102) uses `Func::element(...).call`, whose element branch invokes construction and then `args.finish()`. Custom constructors and parsers therefore execute. [func.mbt:276](/Users/dii/git/typst.mbt/library/func.mbt:276), [element.mbt:326](/Users/dii/git/typst.mbt/library/element.mbt:326)

   However, the generator rule that required fields become required positional parameters remains incorrect. `LinkElem.body` is marked required in metadata, but its parser permits omission for URL destinations. Thus the stated generator would make the promised `Link(url)` impossible. `TextElem` likewise has both an external required `body` and a required stored `text`, although construction accepts only the former. [design:157](/Users/dii/git/typst.mbt/docs/edsl-design.md:157), [manifest.json:6426](/Users/dii/git/typst.mbt/gen/manifest.json:6426), [link.mbt:19](/Users/dii/git/typst.mbt/library/link.mbt:19), [upstream text/mod.rs:852](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/text/mod.rs:852)

   **Fix:** Specify reviewed constructor-signature overrides for custom constructors/parsers. Storage metadata alone is insufficient.

2. **PARTIAL — Explicit construction environment.**

   Immutable descriptions lowered inside a compilation environment solve eager `Image(...)` construction and independently assembled fragments. But “lowering runs once” does not cover descriptions created by show/context callbacks, explicitly permitted at [design:226](/Users/dii/git/typst.mbt/docs/edsl-design.md:226). Their construction needs the current callback’s engine/context and the same provenance owner.

   **Fix:** Define separate initial-tree lowering and callback-result lowering. Initial lowering should use the evaluator’s non-contextual environment; callback lowering should use the actual invocation context. The evaluator deliberately starts source evaluation with `Context::none()`. [eval/lib.mbt:19](/Users/dii/git/typst.mbt/eval/lib.mbt:19) See new issue N1.

3. **PARTIAL — Host identity, fingerprints, memoization and convergence.**

   Fresh identities, identity equality, identity-bearing fingerprints and rejection of new layout-time host callbacks address the original capture-collision problem. The proposed flag correctly reaches frame cacheability and prevents memo reuse across introspectors for identity-bearing recorded reads. [design:266](/Users/dii/git/typst.mbt/docs/edsl-design.md:266), [memo.mbt:139](/Users/dii/git/typst.mbt/library/memo.mbt:139), [memo.mbt:500](/Users/dii/git/typst.mbt/library/memo.mbt:500)

   The convergence guarantee is still only asserted. `RecordedRead` stores an expected hash and a hash-producing replay function; `validate` compares those hashes regardless of the identity/lossy flag. Setting `fingerprint_identity` cannot implement “never compared by fingerprint alone.” [introspector.mbt:202](/Users/dii/git/typst.mbt/library/introspector.mbt:202), [introspector.mbt:460](/Users/dii/git/typst.mbt/library/introspector.mbt:460), [introspector.mbt:506](/Users/dii/git/typst.mbt/library/introspector.mbt:506)

   **Fix:** Specify the recorder change: retain an expected result or an exact validation closure, using identity-aware recursive comparison where required. Do not simply reject every identity-bearing convergence check—that would make stable queries containing host functions fail to converge.

4. **RESOLVED — Autoloc versus source-character mapping.**

   The three tiers, explicit source provider, restriction to plain literals, array-argument fallback and located `T(...)` constructor address the original overclaim. [design:292](/Users/dii/git/typst.mbt/docs/edsl-design.md:292) This matches the actual information available: `SourceLoc` identifies a source range, while `ArgsLoc` contains optional argument locations, not decoded-string mappings. [autoloc.mbt:24](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:24), [autoloc.mbt:94](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:94)

   Allocation and retention of these origins remain separate problems under findings 5 and N1/N5.

5. **PARTIAL — Span encoding and integration.**

   A real UTF-8 origin buffer makes range spans compatible with `world_range` and diagnostic line lookup. Checking endpoints against **8,388,607**, rather than allowing saturation, is correct. [span.mbt:95](/Users/dii/git/typst.mbt/syntax/span.mbt:95), [engine.mbt:122](/Users/dii/git/typst.mbt/library/engine.mbt:122), [diagnostics.mbt:138](/Users/dii/git/typst.mbt/kit/diagnostics.mbt:138)

   Three details remain unresolved:

   - Per-markup virtual files fall outside the “one file ID” account. Their reuse and capacity policy is unspecified; interner exhaustion aborts. [design:343](/Users/dii/git/typst.mbt/docs/edsl-design.md:343), [syntax/path.mbt:83](/Users/dii/git/typst.mbt/syntax/path.mbt:83)
   - The proposed long-text fallback cannot detect overflow from glyph offsets alone: collection can replace an overflowing offset with zero, and shaping saturates other offsets. [inline_collect.mbt:359](/Users/dii/git/typst.mbt/layout/inline_collect.mbt:359), [inline_shaping.mbt:637](/Users/dii/git/typst.mbt/layout/inline_shaping.mbt:637)
   - `Func::call` does not attach the node span to constructed content. `Content::from_fields` starts detached; the evaluator separately spans displayed expressions and wraps calls with tracing. [content.mbt:29](/Users/dii/git/typst.mbt/library/content.mbt:29), [eval/markup.mbt:77](/Users/dii/git/typst.mbt/eval/markup.mbt:77), [eval/call.mbt:121](/Users/dii/git/typst.mbt/eval/call.mbt:121)

   **Fix:** Specify span attachment and tracing explicitly, bound/reuse snippet IDs, and retain overflow information or conservatively downgrade whole oversized text origins.

6. **PARTIAL — Resource-root resolution.**

   Converting direct resource arguments to `RootedPath` avoids resolving them relative to the origin filename. [loading.mbt:49](/Users/dii/git/typst.mbt/library/loading.mbt:49), [library/path.mbt:72](/Users/dii/git/typst.mbt/library/path.mbt:72)

   However, the blanket policy at [design:333](/Users/dii/git/typst.mbt/docs/edsl-design.md:333) does not match the unchanged engine:

   - SVG references resolve relative to the **SVG file**, so `assets/chart.svg` containing `href="plot.png"` loads `assets/plot.png`. Byte-backed SVGs instead use the argument span’s file ID, so diagnostic origins still affect resolution. [image.mbt:91](/Users/dii/git/typst.mbt/library/image.mbt:91), [image_svg.mbt:474](/Users/dii/git/typst.mbt/library/image_svg.mbt:474)
   - `eval_string_mapped` has no independent import-base parameter. Imports evaluated inside its string resolve through their mapped spans. [eval/lib.mbt:88](/Users/dii/git/typst.mbt/eval/lib.mbt:88), [eval/import.mbt:212](/Users/dii/git/typst.mbt/eval/import.mbt:212)
   - Pre-rooting changes observable values: image construction stores the supplied source value, so a string source becomes a path value. It also bypasses the string-specific network-access hint. [image.mbt:16](/Users/dii/git/typst.mbt/library/image.mbt:16), [loading.mbt:61](/Users/dii/git/typst.mbt/library/loading.mbt:61)

   **Fix:** Distinguish direct document resources from dependencies inside loaded files. Either anchor synthetic files at the virtual project root while preserving strings, or introduce an explicit resolution mechanism. Define functional twins for any intentional source-value changes.

7. **PARTIAL — Absent, auto, none and custom values.**

   The four-state distinction and `numbering? : Numbering?` are correct. Internally, that parameter is `Numbering??`: omission is `None`, explicit none is `Some(None)`, and explicit numbering is `Some(Some(n))`.

   But `level=Some(2)` is inconsistent with `level? : Smart[Int]`. Repository `Smart` has `Auto` and **`Custom`**, not `Some`. [design:128](/Users/dii/git/typst.mbt/docs/edsl-design.md:128), [auto.mbt:5](/Users/dii/git/typst.mbt/library/auto.mbt:5)

   The claimed full value domain also conflicts with using 32-bit `Int` for fields whose engine representations contain `Int64`. [design:144](/Users/dii/git/typst.mbt/docs/edsl-design.md:144), [int_casts_gen.mbt:439](/Users/dii/git/typst.mbt/library/int_casts_gen.mbt:439)

   **Fix:** Use `Custom(2)` with a defined `Smart` facade, and suitable 64-bit author-facing integers before engine validation—or explicitly document narrower limits.

8. **RESOLVED — Set-rule ordering, folding and flags.**

   The ordered rule collection, right nesting, and `Element::set(...).spanned(...).liftable()` match evaluation. Leaving `outside` to realization is correct. This preserves repeated properties and folding rather than reducing styles to a last-value dictionary. [design:201](/Users/dii/git/typst.mbt/docs/edsl-design.md:201), [eval/rules.mbt:27](/Users/dii/git/typst.mbt/eval/rules.mbt:27), [styles.mbt:539](/Users/dii/git/typst.mbt/library/styles.mbt:539), [realize.mbt:669](/Users/dii/git/typst.mbt/realize/realize.mbt:669)

9. **PARTIAL — Text, sequences and labels.**

   Literal strings now have the correct functional interpretation. The actual conversion is `FromValue for Content`, whose string branch constructs `TextElem`. [cast.mbt:481](/Users/dii/git/typst.mbt/library/cast.mbt:481)

   The sequence and label specifications are still wrong:

   - `Content::sequence` handles empty/singleton cases but **does not recursively flatten**. `Content::add`, used by the proposed Typst twin, has different sequence concatenation behavior. [content.mbt:404](/Users/dii/git/typst.mbt/library/content.mbt:404), [content.mbt:483](/Users/dii/git/typst.mbt/library/content.mbt:483)
   - Markup label attachment scans preceding expression results; it does not descend into a returned sequence to label its last eligible child. The upstream test explicitly checks the label on the sequence itself. [design:111](/Users/dii/git/typst.mbt/docs/edsl-design.md:111), [eval/markup.mbt:47](/Users/dii/git/typst.mbt/eval/markup.mbt:47), [upstream label.typ:52](/Users/dii/git/typst.mbt/.repos/typst/tests/suite/foundations/label.typ:52)

   **Fix:** Define whether `Seq` preserves nesting or concatenates, and choose the matching twin. Specify `Labelled(n,l)` against one inserted expression result, preserving wrappers/sequences, duplicate-label warnings and empty-name validation.

10. **PARTIAL — Show-rule lifecycle and selectors.**

    Preserving the exact matched content resolves the guard/location/preparation problem. The engine passes `elem.guarded(guard_)` to the recipe, and the proposed view can return that unchanged. Show-selector validation also selects the correct cast path. [design:214](/Users/dii/git/typst.mbt/docs/edsl-design.md:214), [realize.mbt:369](/Users/dii/git/typst.mbt/realize/realize.mbt:369), [selector.mbt:425](/Users/dii/git/typst.mbt/library/selector.mbt:425)

    `ShowSet` still appears only as an example/test requirement; its lowering is not defined. Furthermore, `Recipe::new` alone omits evaluator warnings for unsupported `show page` and obsolete paragraph/block-spacing rules. [eval/rules.mbt:51](/Users/dii/git/typst.mbt/eval/rules.mbt:51), [eval/rules.mbt:65](/Users/dii/git/typst.mbt/eval/rules.mbt:65)

    **Fix:** Specify `Transformation::Style` lowering, including selector validation and ordered set styles, and share the evaluator’s recipe checks.

11. **PARTIAL — Ctx lifetime, capabilities, typing and errors.**

    Invocation tokens, typed selectors and content-based updates are improvements. However, [design:238](/Users/dii/git/typst.mbt/docs/edsl-design.md:238) does not complete the contract:

    - Query needs contextual access; measurement requires both styles and a location. A show callback may have styles without a location. [engine.mbt:544](/Users/dii/git/typst.mbt/library/engine.mbt:544), [query.mbt:31](/Users/dii/git/typst.mbt/library/query.mbt:31), [measure.mbt:15](/Users/dii/git/typst.mbt/library/measure.mbt:15)
    - Query must validate through `LocatableSelector`, not merely accept any `Selector[V]`. [selector.mbt:351](/Users/dii/git/typst.mbt/library/selector.mbt:351)
    - `state(key)` does not specify initialization or functional updates. Engine state carries an initial `Value`. [state.mbt:9](/Users/dii/git/typst.mbt/library/state.mbt:9)
    - `Step | Set(n)` omits counter levels and multi-component states. [counter.mbt:767](/Users/dii/git/typst.mbt/library/counter.mbt:767)

    **Fix:** Publish fallible operation/callback signatures, capability requirements, state initialization/update types, and full counter-update types. Apply token checks to derived handles too.

12. **PARTIAL — Coherent MoonBit API and examples.**

    The following language choices are sound:

    - `fn T::T(...) -> T` true constructors.
    - `#callsite(autofill(loc, args_loc))` with labelled location parameters.
    - The object-safe `IntoContent` trait and contextual coercion into `Array[&IntoContent]`.
    - Deliberate nested optionality for `numbering`.
    - Ordinary `standards=`, `tagged=` and `ppi=` calls.

    These follow the [constructor/argument rules](https://docs.moonbitlang.com/en/latest/language/fundamentals.html#custom-constructors) and [trait-object rules](https://docs.moonbitlang.com/en/latest/language/methods.html#trait-objects).

    Remaining problems:

    - `level=Some(2)` is wrong for repository `Smart`.
    - The `Context(fn ... )` example calls fallible contextual operations without `raise`; explicit `fn` literals do not infer raising effects. [design:234](/Users/dii/git/typst.mbt/docs/edsl-design.md:234), [MoonBit local-function rules](https://docs.moonbitlang.com/en/latest/language/fundamentals.html#local-functions)
    - `Markup(..., scope?=[...])` and `block?=false` still misuse optional forwarding if intended as calls. [design:343](/Users/dii/git/typst.mbt/docs/edsl-design.md:343)
    - `Seq(xs)` has no specified signature supporting existing typed arrays; `Block([h, Line(...)])` and `Par([...])` lack a stated array-to-content adapter.
    - `label=` and `key=` are advertised but absent from the representative constructor signature.
    - `Rule`/style conversion interfaces are missing, so heterogeneous rule examples cannot yet be checked.

    **Fix:** Supply the missing facade declarations and an external compiling consumer. Prefer an explicitly typed heterogeneous `Seq` constructor plus a separate generic collection helper.

13. **PARTIAL — Compile split and world contract.**

    The listed responsibilities of `compile_content` accurately cover the current target gates, styles, memo lifetime, introspection loop, convergence handling and delayed errors. `DocWorld` now has a useful ownership/input contract, and HTML correctly uses its own target. [design:354](/Users/dii/git/typst.mbt/docs/edsl-design.md:354), [typst/lib.mbt:74](/Users/dii/git/typst.mbt/typst/lib.mbt:74)

    The public result/export contract remains inconsistent: compilation returns `Warned[Result[PagedDocument,...]]`, but the next expression produces bare `Bytes` without defining error handling or preservation of export warnings. PDF export itself returns another `Warned[Result[...]]`. [design:362](/Users/dii/git/typst.mbt/docs/edsl-design.md:362), [pdf/lib.mbt:10](/Users/dii/git/typst.mbt/pdf/lib.mbt:10)

    **Fix:** Define composable compilation/export reports and warning propagation. See N5 for the related provenance ownership defect.

14. **PARTIAL — Markup/math evaluation, scope and feature surface.**

    Mapped evaluation, explicit scope injection and avoiding a second equation wrapper are correct choices. Math mode really returns an equation with `block=false`. [eval/lib.mbt:88](/Users/dii/git/typst.mbt/eval/lib.mbt:88), [eval/lib.mbt:139](/Users/dii/git/typst.mbt/eval/lib.mbt:139)

    But the description representation is only `Markup(String, Origin)`: it has nowhere to retain the advertised scope. Math-mode representation and its relationship to the generated `Equation(body, ...)` constructor are also unspecified. [design:85](/Users/dii/git/typst.mbt/docs/edsl-design.md:85), [design:343](/Users/dii/git/typst.mbt/docs/edsl-design.md:343)

    **Fix:** Represent evaluation mode, scope descriptions and equation options explicitly. Define a distinct math-string convenience constructor if necessary. Specify mapped-file registration/reuse and the import-base behavior identified in finding 6. The feature matrix helps, but does not replace these contracts.

15. **RESOLVED — Purity and determinism claims.**

    Revision 2 correctly removes invocation-count guarantees, permits skipped executions through memo reuse, covers custom `IntoContent` implementations and captured mutation, and describes determinism checking as a frozen-input heuristic reporting candidate origins. [design:279](/Users/dii/git/typst.mbt/docs/edsl-design.md:279) This matches the actual layout-level memoization model. [memo.mbt:120](/Users/dii/git/typst.mbt/library/memo.mbt:120)

16. **PARTIAL — Equivalence tests and phasing.**

    Excluding spans and adding behavioral/provenance tests improves the plan. But “frames identical, spans excluded” still needs an explicit normalizer for span offsets, location relationships and embedded host-versus-evaluator function values. The existing dump includes both glyph spans and offsets. [design:413](/Users/dii/git/typst.mbt/docs/edsl-design.md:413), [frame_dump.mbt:350](/Users/dii/git/typst.mbt/tests/runner/frame_dump.mbt:350)

    The phase-1 showcase requires citations/bibliography, gradients and contextual headers/footers, while their prerequisites remain in phase 2. [design:391](/Users/dii/git/typst.mbt/docs/edsl-design.md:391), [design:433](/Users/dii/git/typst.mbt/docs/edsl-design.md:433)

    **Fix:** Define structural, behavioral and export equivalence separately; include memo-on/off comparisons and invalid inputs. Move showcase prerequisites earlier or reduce the first milestone. Specify the IDE adaptation: upstream click mapping requires `source.find(span)`, which an origin listing does not satisfy. [jump.rs:268](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-ide/src/jump.rs:268)

17. **PARTIAL — Units and package placement.**

    Package placement and explicit reliance on public APIs are resolved. The units policy is not: `Rel`, `Pt`, `Pct` and mixed-unit addition appear without their definitions or conversion rules. [design:51](/Users/dii/git/typst.mbt/docs/edsl-design.md:51), [design:151](/Users/dii/git/typst.mbt/docs/edsl-design.md:151)

    **Fix:** Define one common units representation or explicit promotion rules, legal field conversions, error locations and arithmetic order. `Add` remains homogeneous, and the engine’s `Rel` is generic. [operators.mbt:17](/Users/dii/.moon/lib/core/builtin/operators.mbt:17), [rel.mbt:5](/Users/dii/git/typst.mbt/library/rel.mbt:5)

Revision 2 also introduces these concrete issues:

- **N1 — NEW BLOCKER: The prebuilt origin buffer cannot represent callback-created nodes.**

  The callback example constructs `Block` and `Line` only when invoked; fresh headings are explicitly allowed. Those nodes are absent from the initial description tree, yet every node must already have a line in a buffer built before lowering. Rejecting newly created **host callbacks** does not reject these ordinary nodes. [design:219](/Users/dii/git/typst.mbt/docs/edsl-design.md:219), [design:275](/Users/dii/git/typst.mbt/docs/edsl-design.md:275), [design:308](/Users/dii/git/typst.mbt/docs/edsl-design.md:308)

  **Concrete fix:** Define callback-result lowering and stable lazy origin registration. Existing span allocations must remain unchanged across iterations; source-site identity must be separate from runtime occurrence/text identity. Freeze and retain the resulting source registry with the compilation report. Alternatively, prohibit all callback-created descriptions—but that would invalidate the advertised API.

- **N2 — NEW MAJOR: The unconditional construction rule excludes `Context` and update nodes.**

  “The EDSL never constructs element storage directly” cannot implement `Context` through the required `Func::element(...).call` path: its construct hook always reports `cannot be constructed manually`. The evaluator creates its storage directly. State-update construction has the same restriction. [design:15](/Users/dii/git/typst.mbt/docs/edsl-design.md:15), [context.mbt:7](/Users/dii/git/typst.mbt/library/context.mbt:7), [eval/code.mbt:385](/Users/dii/git/typst.mbt/eval/code.mbt:385), [state.mbt:296](/Users/dii/git/typst.mbt/library/state.mbt:296)

  **Concrete fix:** Restore an explicit audited exception list for evaluator-internal constructs, using the same construction helpers/storage paths as evaluation. Restrict generator coverage to public author-facing operations, rather than every engine element indiscriminately.

- **N3 — NEW MAJOR: `ElemCall.elem : String` has no unambiguous element identity.**

  The new representation stores the “engine element name,” but names are not globally unique. Grid and table cells are both `"cell"`; headers, footers, lines and several other elements also collide. [design:89](/Users/dii/git/typst.mbt/docs/edsl-design.md:89), [elems_gen.mbt:1204](/Users/dii/git/typst.mbt/library/elems_gen.mbt:1204), [elems_gen.mbt:6655](/Users/dii/git/typst.mbt/library/elems_gen.mbt:6655)

  **Concrete fix:** Store an `Element` handle or generated unique element key. Give the generic escape hatch canonical qualified names such as `table.cell` and `grid.cell`, with explicit scope resolution.

- **N4 — NEW MAJOR: The public description representation is mutable and can be cyclic.**

  `pub(all) enum Node` exposes `Seq(Array[Node])` and `Styled(Array[Rule],...)`. MoonBit arrays are mutable references: retaining and mutating the input array changes an already-built description. Public construction also permits a sequence array to contain its own enclosing node, producing a cycle. This contradicts the immutable-tree invariant used by preallocation and lowering. [design:8](/Users/dii/git/typst.mbt/docs/edsl-design.md:8), [design:77](/Users/dii/git/typst.mbt/docs/edsl-design.md:77)

  **Concrete fix:** Make nodes opaque and defensively snapshot collection inputs, or expose a truly immutable representation. If arbitrary graph construction remains public, specify cycle validation and diagnostics.

- **N5 — NEW MAJOR: Provenance ownership contradicts the compilation return type, especially on failure.**

  The design retains origins in `CompiledDocument.origins`, but `compile_paged` returns a bare engine `PagedDocument` inside `Warned[Result[...]]`. Neither that document nor `Warned` contains the promised resolver/source snapshot. On compilation failure there is no compiled document at all, although diagnostics still reference virtual files. Reusing their IDs during a later compilation can then make old diagnostics resolve against different contents. [design:328](/Users/dii/git/typst.mbt/docs/edsl-design.md:328), [design:362](/Users/dii/git/typst.mbt/docs/edsl-design.md:362), [layout/document.mbt:5](/Users/dii/git/typst.mbt/layout/document.mbt:5), [diag.mbt:294](/Users/dii/git/typst.mbt/library/diag.mbt:294)

  **Concrete fix:** Return a compilation report that owns immutable origins and virtual-source snapshots on **both success and failure**. Successful output can contain `CompiledDocument[T]`; export reports should retain that resolver and combine compilation/export warnings.

This was a read-only review against the repository, pinned upstream and MoonBit language documentation. No files were changed. Executable API validation remains unproven: `moonc check -no-mi` attempted to write an AST artifact and was blocked by the read-only sandbox.

VERDICT: REQUEST CHANGES

