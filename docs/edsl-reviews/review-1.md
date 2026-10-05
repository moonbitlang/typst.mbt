codex
The architecture is viable, but the design needs changes before implementation. The main problems are construction semantics, callback memoization, and the provenance contract—not the choice to build engine values directly.

I checked the current MoonBit sources, the pinned Rust upstream, the generators, and local autoloc definitions. Findings below are ordered by priority.

1. **BLOCKER — Generated element views are not equivalent to Typst constructors.**

   Sections 3 and 5 suggest deriving constructors from `viewgen.py`, but that generator produces access to **already normalized storage**. It skips external fields and constructs content directly with `Content::new`; getters abort when stored values have unexpected types. See [viewgen.py:125](/Users/dii/git/typst.mbt/scripts/viewgen.py:125) and [elem_views_gen.mbt:5](/Users/dii/git/typst.mbt/library/elem_views_gen.mbt:5).

   Typst construction instead runs custom constructors, argument casts, field parsers, and shared parser locals through [Element::construct](/Users/dii/git/typst.mbt/library/element.mbt:326). Concrete counterexamples:

   - `text(body, ...)` styles existing content; it does not construct a text node. [text_hooks.mbt:18](/Users/dii/git/typst.mbt/library/text_hooks.mbt:18)
   - `page(body, ...)` constructs a styled sequence containing page breaks and a flush element; it does not construct a page node. [page.mbt:9](/Users/dii/git/typst.mbt/library/page.mbt:9)
   - `page(paper: ...)` derives width and height through parsers sharing local state. [page.mbt:69](/Users/dii/git/typst.mbt/library/page.mbt:69)
   - `link(url)` synthesizes an omitted body from the URL. [link.mbt:19](/Users/dii/git/typst.mbt/library/link.mbt:19)
   - Images and bibliographies load and validate resources during construction. [image.mbt:16](/Users/dii/git/typst.mbt/library/image.mbt:16), [bibliography.mbt:44](/Users/dii/git/typst.mbt/library/bibliography.mbt:44)

   The special text/page behavior also exists in the pinned Rust sources: [text/mod.rs:946](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/text/mod.rs:946), [page.rs:504](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/layout/page.rs:504).

   **Change:** Generate author-facing arguments, then lower them through `Func::element(...).call(...)` and `Element::set(...)`. This preserves parsing, validation, and leftover-argument checks. Allow direct field construction only for explicitly audited cases, including special internal constructs such as `ContextElem`. Use generated views primarily for reading content.

2. **BLOCKER — Constructors need an explicit build environment, but none exists in the proposed signatures.**

   `Heading` stores only `Content`; `IntoContent` receives no context; `Image("chart.png")` and `Markup(...)` are evaluated before the enclosing `Document(...)` call. Yet faithful construction requires an `Engine`, resource access, a diagnostic sink, and the proposed span table. [engine.mbt:157](/Users/dii/git/typst.mbt/library/engine.mbt:157), [image.mbt:16](/Users/dii/git/typst.mbt/library/image.mbt:16)

   A “per-compilation” table created by `doc.compile()` is too late for constructors that already attached spans. It also leaves unanswered how separately built content, repeated compilation, multiple documents, and callbacks constructing content during layout share provenance.

   **Change:** Choose one construction model explicitly:

   - An explicit `BuildContext` owning the world, origins, and diagnostics, passed to eager constructors.
   - Immutable EDSL construction descriptions carrying origins, lowered once inside `Document` using that environment.

   Specify how documents combine independently built fragments, how callback construction accesses the same environment, and how compiled outputs retain their provenance resolver. Avoid an implicit global “current document.”

3. **BLOCKER — Wrapping capturing MoonBit closures as native functions is unsafe with the existing fingerprint/memo rules.**

   Section 7’s bridge is callable, but its memo semantics are incomplete:

   - Native functions compare by `NativeFuncData` identity. [func.mbt:353](/Users/dii/git/typst.mbt/library/func.mbt:353)
   - Their fingerprint contains name/title/docs and the function span; it omits the function implementation and captures. Only the `Closure` branch sets `fingerprint_identity`. [value_hash.mbt:251](/Users/dii/git/typst.mbt/library/value_hash.mbt:251)
   - Frame cacheability relies on that identity flag to reject results containing newly created closures. [memo.mbt:496](/Users/dii/git/typst.mbt/library/memo.mbt:496)
   - Recorded introspector reads use fingerprints and flags to decide whether results can be reused across introspectors. [introspector.mbt:202](/Users/dii/git/typst.mbt/library/introspector.mbt:202), [memo.mbt:139](/Users/dii/git/typst.mbt/library/memo.mbt:139)

   Thus two callbacks constructed at the same site with different captures can have identical fingerprints. Direct memo-input equality protects some cases, but does not fix callbacks appearing in cached result tags or recorded query results. Furthermore, convergence validation itself compares fingerprints; adding a lossy flag alone does not repair that path. [introspector.mbt:506](/Users/dii/git/typst.mbt/library/introspector.mbt:506)

   **Change:** Introduce an explicit host-callback representation distinguishing static native functions from capturing callbacks. Define identity, capture fingerprinting, cacheability, and convergence behavior together. Preserve one identity per constructed callback, while retaining fresh identities for callbacks constructed during separate invocations. Never intern callbacks solely by source location.

   Until that machinery exists, restrict callbacks to pre-layout handles with immutable, explicitly represented captures, and reject unsupported callback creation during layout.

4. **BLOCKER — Autoloc cannot provide the promised exact source mapping by itself.**

   Section 9 overstates the available information. `SourceLoc` contains a source range; `ArgsLoc` contains optional ranges for call arguments. Neither contains literal syntax, decoded-to-source offsets, nor locations for individual expressions nested inside an array. [autoloc.mbt:24](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:24), [autoloc.mbt:94](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:94)

   For `Par(["a", Strong("b"), "c"])`, the outer call records one array-argument range. The plain strings have no individual autoloc-bearing calls. An `IntoContent for String` implementation cannot recover their original locations.

   Further counterexamples include escaped characters, interpolation, multiline strings, concatenated strings, variables, and text loaded from data. A rendered byte offset does not identify the corresponding MoonBit source character. Ligatures and combining sequences also make glyph-to-character mapping non-bijective.

   **Change:** Define separate guarantees:

   - Constructor/argument-expression provenance.
   - Runtime text byte-range provenance.
   - Exact MoonBit source-character mapping, available only with an accompanying source map or source-analysis step.

   Provide an explicitly located text constructor for array entries, preserve existing child origins, and represent unavailable character mappings honestly. Exact source excerpts require retained source snapshots or a source provider; autoloc alone cannot supply them.

5. **MAJOR — Synthetic range spans are representable, but the encoding and integration contract are missing.**

   The representation permits this approach, with important restrictions:

   - Each `Span::from_range` endpoint has only **23 bits** and silently saturates above `8,388,607`. [span.mbt:95](/Users/dii/git/typst.mbt/syntax/span.mbt:95)
   - File IDs are globally interned 16-bit IDs; exhaustion aborts. Repeatedly allocating unique files is not an unlimited escape hatch. [path.mbt:79](/Users/dii/git/typst.mbt/syntax/path.mbt:79)
   - Glyph span offsets are `UInt16`; some offsets above 65,535 become zero, while others saturate. [inline_collect.mbt:359](/Users/dii/git/typst.mbt/layout/inline_collect.mbt:359), [inline_shaping.mbt:637](/Users/dii/git/typst.mbt/layout/inline_shaping.mbt:637)

   Existing consumers interpret range endpoints as real byte positions. `world_range` returns them directly; diagnostic rendering loads file bytes to compute lines; trace suppression uses range containment. [engine.mbt:122](/Users/dii/git/typst.mbt/library/engine.mbt:122), [diagnostics.mbt:138](/Users/dii/git/typst.mbt/kit/diagnostics.mbt:138), [diag.mbt:266](/Users/dii/git/typst.mbt/library/diag.mbt:266)

   Spans also participate in content fingerprints and hence generated locations. However, **repeated spans do not automatically violate location uniqueness**: `SplitLocator` explicitly disambiguates repeated keys. [value_hash.mbt:299](/Users/dii/git/typst.mbt/library/value_hash.mbt:299), [locator.mbt:133](/Users/dii/git/typst.mbt/library/locator.mbt:133)

   **Change:** Specify a checked encoding, overflow strategy, stable allocation across layout iterations, and a resolver covering diagnostics, hints, traces, previews, and export errors. Separate origin IDs, runtime text offsets, data keys, and document occurrence identity. Retain the table with the compiled artifact.

   Either back spans with meaningful virtual byte buffers or adapt all consumers that assume real ranges. A display-only filename translation is insufficient.

6. **MAJOR — Synthetic filenames also affect resource resolution.**

   The proposed `edsl:<module>/<file>` is not merely a diagnostic name. `FileId` identifies a rooted virtual path, and relative resource strings resolve against the originating span’s file. [path.mbt:115](/Users/dii/git/typst.mbt/syntax/path.mbt:115), [loading.mbt:49](/Users/dii/git/typst.mbt/library/loading.mbt:49), [library/path.mbt:80](/Users/dii/git/typst.mbt/library/path.mbt:80)

   Therefore, attaching an image argument to a synthetic module-directory path does not automatically implement section 10’s “relative to a root directory” policy. Detached spans fail relative filesystem resolution altogether.

   **Change:** Define a resource base independently of the diagnostic origin. Resolve author-facing resource paths into `RootedPath` values during lowering, or deliberately assign synthetic file paths with the required resolution semantics. Apply the same policy to bibliography/CSL files, raw syntax/theme files, markup imports, and SVG dependencies.

7. **MAJOR — Omitted, `auto`, `none`, and custom values must remain distinct.**

   The units table equates `auto` with omission, contradicting section 5. Omission inherits; explicit `auto` overrides an inherited custom value. The engine explicitly preserves this distinction during folding. [auto.mbt:135](/Users/dii/git/typst.mbt/library/auto.mbt:135)

   The sample `Heading` signature also loses valid states:

   - `level` is `Smart[NonZeroUSize]`, not unrestricted `Int`.
   - `numbering` is nullable; `numbering? : Numbering` cannot explicitly disable inherited numbering.
   - `supplement` is `Smart[Supplement?]`, where `Supplement` supports both content and functions. `Smart[&IntoContent]` loses explicit `none` and functional supplements.

   See [elem_views_gen.mbt:12971](/Users/dii/git/typst.mbt/library/elem_views_gen.mbt:12971), [elem_views_gen.mbt:13130](/Users/dii/git/typst.mbt/library/elem_views_gen.mbt:13130), [reference.mbt:6](/Users/dii/git/typst.mbt/library/reference.mbt:6).

   **Change:** Publish a field-state mapping: absent field, `Value::Auto`, `Value::None`, and validated custom value. Deliberate nested optionality is appropriate here: for example, `numbering? : Numbering?`. Preserve the complete engine value domain or explicitly document any initial restriction.

8. **MAJOR — Set rules require ordering, folding, and origin flags, not just property lists.**

   `Styled(...)=styled_with_map(...)` is correct once the styles have correct semantics. The missing part is their construction.

   Evaluated set rules call `.spanned(...).liftable()`. Generated `set_*` methods merely create properties. Realization separately determines `outside`; these flags affect page-level style handling. [eval/rules.mbt:27](/Users/dii/git/typst.mbt/eval/rules.mbt:27), [styles.mbt:104](/Users/dii/git/typst.mbt/library/styles.mbt:104), [realize.mbt:669](/Users/dii/git/typst.mbt/realize/realize.mbt:669)

   Style lists are ordered, and folding can consume every applicable property. For example, relative text sizes compose rather than simply replacing one another. [styles.mbt:539](/Users/dii/git/typst.mbt/library/styles.mbt:539), [text.mbt:259](/Users/dii/git/typst.mbt/library/text.mbt:259)

   **Change:** Define exact rule order and nesting. Preserve repeated properties, custom set parsers, and folding; mark author set rules as liftable while allowing realization to determine `outside`. Consider one ordered `rules` collection instead of separate `set` and `show` arrays, or define their fixed translation explicitly. Add argument locations to style constructors too.

9. **MAJOR — “Equivalent markup” needs a precise definition for text, sequences, and labels.**

   Literal strings are a sensible choice, but they correspond to Typst string-to-content conversion, not arbitrary markup prose. Markup evaluation produces distinct space, paragraph-break, line-break, quote, and symbol elements. [cast.mbt:481](/Users/dii/git/typst.mbt/library/cast.mbt:481), [eval/code.mbt:87](/Users/dii/git/typst.mbt/eval/code.mbt:87)

   Those distinctions are observable to show rules. A text node containing a space is not structurally identical to markup’s `SpaceElem`. Likewise, explicit `Par(...)` content need not equal the pre-layout structure of prose that realization later groups into paragraphs.

   Labels are metadata, not ordinary element fields. Markup attaches a label to the preceding eligible element, skipping `Unlabellable` content and issuing warnings for problematic attachments. [eval/markup.mbt:47](/Users/dii/git/typst.mbt/eval/markup.mbt:47), [content.mbt:99](/Users/dii/git/typst.mbt/library/content.mbt:99)

   **Change:** Define each EDSL operation against an explicit functional Typst expression, such as `#heading("Introduction")`, rather than vaguely against similar-looking syntax. Specify sequence flattening, empty/singleton behavior, and explicit `Space`, `Linebreak`, and `Parbreak`. Define `label=` as a deliberate attachment operation with documented behavior for wrappers, sequences, and unlabellable elements.

10. **MAJOR — Show rules need lifecycle-preserving views and validated selector categories.**

    Passing a typed view is sound if it wraps the exact content supplied by the engine. Realization passes content already guarded against the current recipe. Reconstructing a fresh heading from its fields loses that guard, location, and preparation state, potentially restarting the same show rule. [realize.mbt:369](/Users/dii/git/typst.mbt/realize/realize.mbt:369), [content.mbt:116](/Users/dii/git/typst.mbt/library/content.mbt:116)

    Section 7 also lists selectors without distinguishing their legal uses. The engine rejects location/before/after selectors for show rules, rejects nested regex selectors there, and rejects text selectors for locatable queries. [selector.mbt:351](/Users/dii/git/typst.mbt/library/selector.mbt:351), [selector.mbt:425](/Users/dii/git/typst.mbt/library/selector.mbt:425)

    **Change:** Make `HeadingView.into_content()` preserve the original engine content. Distinguish wrapping the matched element from creating a new element. Validate show selectors and query selectors through their existing cast paths. Preserve recipe order, show-set transformations, delayed errors, and recursion guards. Include tests for identity transforms, wrapping transforms, fresh-element recursion, regex revocation, and invalid selectors.

11. **MAJOR — `Ctx` needs capability, lifetime, typing, and error contracts.**

    A wrapper around `Engine` and `Context` is insufficiently specified. MoonBit callbacks can capture a `Ctx` and reuse it later; that would retain a stale introspector and sink. A general show callback also does not necessarily have a location.

    Existing query operations check contextual access and register an `Introspect` operation. Measurement uses a special measurement locator and inherited styles. [query.mbt:31](/Users/dii/git/typst.mbt/library/query.mbt:31), [measure.mbt:15](/Users/dii/git/typst.mbt/library/measure.mbt:15)

    **Change:** Keep engine internals private, make context-derived operations valid only during the callback invocation, and detect stale use where feasible. Reuse the existing contextual and tracked-introspection paths.

    Specify typed selectors such as `Selector[HeadingView]`, with heterogeneous combinations returning `Content` or an explicit union. Define state initialization and updates as emitted content, rather than captured mutation: the engine’s state update operation constructs a `state-update` element. [state.mbt:203](/Users/dii/git/typst.mbt/library/state.mbt:203)

12. **MAJOR — The public examples are not yet a coherent MoonBit API.**

    Several concrete inconsistencies need executable examples:

    - The introduction passes a one-argument show closure; section 7 specifies two arguments.
    - `HeadingStyle(numbering="1.")` needs an explicit string-to-numbering adapter; the engine `Numbering` is an enum. [numbering.mbt:21](/Users/dii/git/typst.mbt/library/numbering.mbt:21)
    - Constructors advertise validation errors but omit `raise` from their signatures.
    - Heterogeneous style arrays need a common type or conversion trait, which is not defined.
    - `Array[&IntoContent]` supports contextual coercion of literal entries; that does not imply automatic conversion of existing `Array[Heading]` collections.
    - An expected `&IntoContent` does not identify which foreign concrete constructor an unqualified `Heading(...)` denotes. Specify explicit imports or qualified constructors.
    - `standards?=[...]`, `tagged?=true`, and `ppi?=144` misuse optional forwarding; ordinary supplied values use `=`. The proposed “optional `key~`” likewise needs a real optional-parameter signature.

    Constructor lookup and optional forwarding are documented in [MoonBit fundamentals](https://docs.moonbitlang.com/en/latest/language/fundamentals.html); trait-object coercion requires an expected trait-object type. [MoonBit methods](https://docs.moonbitlang.com/en/latest/language/methods.html)

    **Change:** Add a small external consumer package containing every advertised example. Prefer an explicit `Seq(Array[&IntoContent])` plus a generic collection-to-sequence helper. Complete the naming table, including internal API collisions such as element `Align` versus alignment values and `Raw` versus the engine-value escape hatch.

    Also replace `Elem(name, Array[(String, Value)])`: it cannot faithfully represent positional/variadic arguments. The existing argument model distinguishes positional and named arguments and stores their spans. [args.mbt:6](/Users/dii/git/typst.mbt/library/args.mbt:6)

13. **MAJOR — The compile split is feasible, but its preserved responsibilities and world contract must be explicit.**

    `compile_impl` already has a useful boundary between evaluation and `T::create`. The extracted path must retain target-feature checks, library/target styles, fresh memo lifetime, tracked introspection, convergence warnings, and delayed-error promotion. [typst/lib.mbt:74](/Users/dii/git/typst.mbt/typst/lib.mbt:74), [typst/lib.mbt:104](/Users/dii/git/typst.mbt/typst/lib.mbt:104)

    `kit` supplies reusable components, not an existing public ready-to-use world. The CLI’s `SystemWorld` is private. [kit/files.mbt:9](/Users/dii/git/typst.mbt/kit/files.mbt:9), [cli/world.mbt:5](/Users/dii/git/typst.mbt/cli/world.mbt:5)

    **Change:** Specify `DocWorld`’s library/features/formats, virtual main ID, files, fonts, frozen date, and resource snapshot lifetime. Provide an in-memory world and byte/string export methods alongside filesystem writing.

    HTML requires its own compilation target, not conversion of a previously compiled `PagedDocument`; current compilation gates HTML and bundle features. [typst/lib.mbt:75](/Users/dii/git/typst.mbt/typst/lib.mbt:75) Preserve warnings in the high-level API and define precedence between document format settings and explicit export options.

14. **MAJOR — Markup/math escape hatches require evaluation and scope design, and the broader feature surface is incomplete.**

    Math parsing alone does not produce usable content. The existing `eval_string` path parses and evaluates with an engine, context, and scope. Its Math mode returns an equation with `block=false`. Ordinary string evaluation assigns one supplied span to the tree; `eval_string_mapped` supplies internal range spans. [eval/lib.mbt:64](/Users/dii/git/typst.mbt/eval/lib.mbt:64), [eval/lib.mbt:88](/Users/dii/git/typst.mbt/eval/lib.mbt:88), [eval/lib.mbt:139](/Users/dii/git/typst.mbt/eval/lib.mbt:139)

    **Change:** Define escape-hatch scope, parameter injection, import base, evaluation timing, internal error mapping, and block-equation handling. Avoid double-wrapping the equation returned by Math mode.

    Add a feature matrix assigning support or explicit deferral to these missing contracts:

    | Area | Required design decision |
    |---|---|
    | Bibliography | Sources, CSL style, bytes, citation groups/targets, loading errors |
    | Tables/grids | Cells, row/column spans, headers/footers, rules, track sizing, per-cell callbacks |
    | Page/document setup | Paper, margins, headers/footers, numbering, metadata, format settings |
    | State/counters | Typed keys, initialization, update content, `at`/`final` operations |
    | Math | Structured composition and parameter binding beyond interpolated strings |
    | Raw/code | A real raw-text constructor, separate from displaying arbitrary engine values |
    | Images | Byte sources, format hints, alt text, PDF page selection |
    | HTML/bundle | Target-dependent content, attributes, assets, output options |

    These are supported by richer existing engine types: for example, `TableChild`, `Celled[T]`, and `DataSource`. [table.mbt:64](/Users/dii/git/typst.mbt/library/table.mbt:64), [grid.mbt:264](/Users/dii/git/typst.mbt/library/grid.mbt:264), [loading.mbt:5](/Users/dii/git/typst.mbt/library/loading.mbt:5)

15. **MAJOR — The purity and determinism claims are too strong.**

    Section 8 says closures execute on every layout attempt and their results are cached. Actual invocation counts depend on matching, measurement, layout structure, and memo hits. The engine memoizes selected layout operations, not every callback as a standalone function. [memo.mbt:1](/Users/dii/git/typst.mbt/library/memo.mbt:1)

    Compiling twice cannot establish purity. Mutation may leave output unchanged, and an output difference does not uniquely identify its causal callback. Font/resource/date changes can also create differences unrelated to callback purity.

    **Change:** State that callbacks may execute repeatedly or be skipped through memo reuse, with no invocation-count guarantee. Extend the purity contract to custom `IntoContent` implementations and captured mutable engine values. Snapshot inputs.

    Make `check_determinism` a diagnostic heuristic using a frozen world, comparing normalized results, diagnostics, and relevant introspection observations. Instrument callback invocations to report candidate origins; remove the promise that every difference identifies the responsible closure.

16. **MAJOR — Tests and phasing currently cannot establish the claimed equivalence.**

    The existing paged dump includes glyph spans and span offsets, so literal frame-dump identity cannot hold between MoonBit and Typst sources. [frame_dump.mbt:350](/Users/dii/git/typst.mbt/tests/runner/frame_dump.mbt:350)

    Content `repr` snapshots also miss important structure, and ordinary content equality ignores some field categories. [content.mbt:365](/Users/dii/git/typst.mbt/library/content.mbt:365) Native host callbacks cannot be literally identical to evaluator closures: their variants and observable names/reprs differ. [func.mbt:171](/Users/dii/git/typst.mbt/library/func.mbt:171), [func.mbt:340](/Users/dii/git/typst.mbt/library/func.mbt:340)

    **Change:** Define equivalence at separate levels:

    - Constructor/set-rule lowering: normalized fields, absent versus explicit values, labels, ordered styles, flags, warnings, and errors.
    - Layout: normalized frames with provenance excluded and location relationships preserved.
    - Behavior: show order/guards, counters, state, queries, measurements, callback identity, and memo enabled versus disabled.
    - Export: SVG, PNG pixels, HTML semantics, PDF semantics/tags, and bundle contents.
    - Provenance: a separate assertion suite covering Unicode, escapes, arrays, wrappers, repeated/data-driven content, long text, and span-capacity boundaries.

    Test interactions and invalid inputs—not merely each optional field once.

    Provenance cannot wait until phase 3 because it changes construction and ownership. The phase-1 example also already requires show rules, context/page numbering, and references, which the plan places later. Move a minimal provenance implementation and callback bridge into the first vertical slice.

    Finally, upstream `jump_from_click` needs adaptation: its text path loads a Typst source and finds a syntax node. Synthetic table indices do not satisfy that assumption. [jump.rs:268](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-ide/src/jump.rs:268) HTML has text-node spans rather than engine-shaped glyph runs, and some generated frame shapes have detached spans. [html/dom.mbt:9](/Users/dii/git/typst.mbt/html/dom.mbt:9), [frame.mbt:425](/Users/dii/git/typst.mbt/library/frame.mbt:425) Define container-level fallback provenance for regions without an exact leaf origin.

17. **MINOR — Resolve the units policy and retain the proposed package placement.**

    A single `Rel` enum is implementable, but the rationale should acknowledge that MoonBit’s `Add` is homogeneous: `add(Self, Self) -> Self`. Separate types require explicit promotion or another operation for mixed addition. [/builtin/operators.mbt:17](/Users/dii/.moon/lib/core/builtin/operators.mbt:17)

    The engine already represents unresolved lengths and relative lengths directly. [length.mbt:7](/Users/dii/git/typst.mbt/library/length.mbt:7), [rel.mbt:5](/Users/dii/git/typst.mbt/library/rel.mbt:5) Either retain `Rel` with checked, argument-localized conversion errors, or choose typed lengths with explicit relative promotion. Preserve arithmetic evaluation order when lowering `Sum`.

    Keeping `doc/` in this module is appropriate for synchronized generator and engine changes. Same-module placement does not grant access to package-private implementations; design against exported APIs from the start. A later module move can preserve implementation structure, but changes consumer import paths. Consider separating filesystem/export conveniences from the construction package.

The toolchain version stated in the document matches the installed `moon`, and the checked-in evaluation goldens contain 3,792 cases. Custom constructors and the local autoloc types are real; the broad EDSL direction is technically supported.

This was a read-only review. I changed no files and did not run the differential suite. A compiler probe could not complete because `moonc check -no-mi` still attempted to write an AST artifact in the read-only environment.

VERDICT: REQUEST CHANGES
tokens used
219,282
The architecture is viable, but the design needs changes before implementation. The main problems are construction semantics, callback memoization, and the provenance contract—not the choice to build engine values directly.

I checked the current MoonBit sources, the pinned Rust upstream, the generators, and local autoloc definitions. Findings below are ordered by priority.

1. **BLOCKER — Generated element views are not equivalent to Typst constructors.**

   Sections 3 and 5 suggest deriving constructors from `viewgen.py`, but that generator produces access to **already normalized storage**. It skips external fields and constructs content directly with `Content::new`; getters abort when stored values have unexpected types. See [viewgen.py:125](/Users/dii/git/typst.mbt/scripts/viewgen.py:125) and [elem_views_gen.mbt:5](/Users/dii/git/typst.mbt/library/elem_views_gen.mbt:5).

   Typst construction instead runs custom constructors, argument casts, field parsers, and shared parser locals through [Element::construct](/Users/dii/git/typst.mbt/library/element.mbt:326). Concrete counterexamples:

   - `text(body, ...)` styles existing content; it does not construct a text node. [text_hooks.mbt:18](/Users/dii/git/typst.mbt/library/text_hooks.mbt:18)
   - `page(body, ...)` constructs a styled sequence containing page breaks and a flush element; it does not construct a page node. [page.mbt:9](/Users/dii/git/typst.mbt/library/page.mbt:9)
   - `page(paper: ...)` derives width and height through parsers sharing local state. [page.mbt:69](/Users/dii/git/typst.mbt/library/page.mbt:69)
   - `link(url)` synthesizes an omitted body from the URL. [link.mbt:19](/Users/dii/git/typst.mbt/library/link.mbt:19)
   - Images and bibliographies load and validate resources during construction. [image.mbt:16](/Users/dii/git/typst.mbt/library/image.mbt:16), [bibliography.mbt:44](/Users/dii/git/typst.mbt/library/bibliography.mbt:44)

   The special text/page behavior also exists in the pinned Rust sources: [text/mod.rs:946](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/text/mod.rs:946), [page.rs:504](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/layout/page.rs:504).

   **Change:** Generate author-facing arguments, then lower them through `Func::element(...).call(...)` and `Element::set(...)`. This preserves parsing, validation, and leftover-argument checks. Allow direct field construction only for explicitly audited cases, including special internal constructs such as `ContextElem`. Use generated views primarily for reading content.

2. **BLOCKER — Constructors need an explicit build environment, but none exists in the proposed signatures.**

   `Heading` stores only `Content`; `IntoContent` receives no context; `Image("chart.png")` and `Markup(...)` are evaluated before the enclosing `Document(...)` call. Yet faithful construction requires an `Engine`, resource access, a diagnostic sink, and the proposed span table. [engine.mbt:157](/Users/dii/git/typst.mbt/library/engine.mbt:157), [image.mbt:16](/Users/dii/git/typst.mbt/library/image.mbt:16)

   A “per-compilation” table created by `doc.compile()` is too late for constructors that already attached spans. It also leaves unanswered how separately built content, repeated compilation, multiple documents, and callbacks constructing content during layout share provenance.

   **Change:** Choose one construction model explicitly:

   - An explicit `BuildContext` owning the world, origins, and diagnostics, passed to eager constructors.
   - Immutable EDSL construction descriptions carrying origins, lowered once inside `Document` using that environment.

   Specify how documents combine independently built fragments, how callback construction accesses the same environment, and how compiled outputs retain their provenance resolver. Avoid an implicit global “current document.”

3. **BLOCKER — Wrapping capturing MoonBit closures as native functions is unsafe with the existing fingerprint/memo rules.**

   Section 7’s bridge is callable, but its memo semantics are incomplete:

   - Native functions compare by `NativeFuncData` identity. [func.mbt:353](/Users/dii/git/typst.mbt/library/func.mbt:353)
   - Their fingerprint contains name/title/docs and the function span; it omits the function implementation and captures. Only the `Closure` branch sets `fingerprint_identity`. [value_hash.mbt:251](/Users/dii/git/typst.mbt/library/value_hash.mbt:251)
   - Frame cacheability relies on that identity flag to reject results containing newly created closures. [memo.mbt:496](/Users/dii/git/typst.mbt/library/memo.mbt:496)
   - Recorded introspector reads use fingerprints and flags to decide whether results can be reused across introspectors. [introspector.mbt:202](/Users/dii/git/typst.mbt/library/introspector.mbt:202), [memo.mbt:139](/Users/dii/git/typst.mbt/library/memo.mbt:139)

   Thus two callbacks constructed at the same site with different captures can have identical fingerprints. Direct memo-input equality protects some cases, but does not fix callbacks appearing in cached result tags or recorded query results. Furthermore, convergence validation itself compares fingerprints; adding a lossy flag alone does not repair that path. [introspector.mbt:506](/Users/dii/git/typst.mbt/library/introspector.mbt:506)

   **Change:** Introduce an explicit host-callback representation distinguishing static native functions from capturing callbacks. Define identity, capture fingerprinting, cacheability, and convergence behavior together. Preserve one identity per constructed callback, while retaining fresh identities for callbacks constructed during separate invocations. Never intern callbacks solely by source location.

   Until that machinery exists, restrict callbacks to pre-layout handles with immutable, explicitly represented captures, and reject unsupported callback creation during layout.

4. **BLOCKER — Autoloc cannot provide the promised exact source mapping by itself.**

   Section 9 overstates the available information. `SourceLoc` contains a source range; `ArgsLoc` contains optional ranges for call arguments. Neither contains literal syntax, decoded-to-source offsets, nor locations for individual expressions nested inside an array. [autoloc.mbt:24](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:24), [autoloc.mbt:94](/Users/dii/.moon/lib/core/builtin/autoloc.mbt:94)

   For `Par(["a", Strong("b"), "c"])`, the outer call records one array-argument range. The plain strings have no individual autoloc-bearing calls. An `IntoContent for String` implementation cannot recover their original locations.

   Further counterexamples include escaped characters, interpolation, multiline strings, concatenated strings, variables, and text loaded from data. A rendered byte offset does not identify the corresponding MoonBit source character. Ligatures and combining sequences also make glyph-to-character mapping non-bijective.

   **Change:** Define separate guarantees:

   - Constructor/argument-expression provenance.
   - Runtime text byte-range provenance.
   - Exact MoonBit source-character mapping, available only with an accompanying source map or source-analysis step.

   Provide an explicitly located text constructor for array entries, preserve existing child origins, and represent unavailable character mappings honestly. Exact source excerpts require retained source snapshots or a source provider; autoloc alone cannot supply them.

5. **MAJOR — Synthetic range spans are representable, but the encoding and integration contract are missing.**

   The representation permits this approach, with important restrictions:

   - Each `Span::from_range` endpoint has only **23 bits** and silently saturates above `8,388,607`. [span.mbt:95](/Users/dii/git/typst.mbt/syntax/span.mbt:95)
   - File IDs are globally interned 16-bit IDs; exhaustion aborts. Repeatedly allocating unique files is not an unlimited escape hatch. [path.mbt:79](/Users/dii/git/typst.mbt/syntax/path.mbt:79)
   - Glyph span offsets are `UInt16`; some offsets above 65,535 become zero, while others saturate. [inline_collect.mbt:359](/Users/dii/git/typst.mbt/layout/inline_collect.mbt:359), [inline_shaping.mbt:637](/Users/dii/git/typst.mbt/layout/inline_shaping.mbt:637)

   Existing consumers interpret range endpoints as real byte positions. `world_range` returns them directly; diagnostic rendering loads file bytes to compute lines; trace suppression uses range containment. [engine.mbt:122](/Users/dii/git/typst.mbt/library/engine.mbt:122), [diagnostics.mbt:138](/Users/dii/git/typst.mbt/kit/diagnostics.mbt:138), [diag.mbt:266](/Users/dii/git/typst.mbt/library/diag.mbt:266)

   Spans also participate in content fingerprints and hence generated locations. However, **repeated spans do not automatically violate location uniqueness**: `SplitLocator` explicitly disambiguates repeated keys. [value_hash.mbt:299](/Users/dii/git/typst.mbt/library/value_hash.mbt:299), [locator.mbt:133](/Users/dii/git/typst.mbt/library/locator.mbt:133)

   **Change:** Specify a checked encoding, overflow strategy, stable allocation across layout iterations, and a resolver covering diagnostics, hints, traces, previews, and export errors. Separate origin IDs, runtime text offsets, data keys, and document occurrence identity. Retain the table with the compiled artifact.

   Either back spans with meaningful virtual byte buffers or adapt all consumers that assume real ranges. A display-only filename translation is insufficient.

6. **MAJOR — Synthetic filenames also affect resource resolution.**

   The proposed `edsl:<module>/<file>` is not merely a diagnostic name. `FileId` identifies a rooted virtual path, and relative resource strings resolve against the originating span’s file. [path.mbt:115](/Users/dii/git/typst.mbt/syntax/path.mbt:115), [loading.mbt:49](/Users/dii/git/typst.mbt/library/loading.mbt:49), [library/path.mbt:80](/Users/dii/git/typst.mbt/library/path.mbt:80)

   Therefore, attaching an image argument to a synthetic module-directory path does not automatically implement section 10’s “relative to a root directory” policy. Detached spans fail relative filesystem resolution altogether.

   **Change:** Define a resource base independently of the diagnostic origin. Resolve author-facing resource paths into `RootedPath` values during lowering, or deliberately assign synthetic file paths with the required resolution semantics. Apply the same policy to bibliography/CSL files, raw syntax/theme files, markup imports, and SVG dependencies.

7. **MAJOR — Omitted, `auto`, `none`, and custom values must remain distinct.**

   The units table equates `auto` with omission, contradicting section 5. Omission inherits; explicit `auto` overrides an inherited custom value. The engine explicitly preserves this distinction during folding. [auto.mbt:135](/Users/dii/git/typst.mbt/library/auto.mbt:135)

   The sample `Heading` signature also loses valid states:

   - `level` is `Smart[NonZeroUSize]`, not unrestricted `Int`.
   - `numbering` is nullable; `numbering? : Numbering` cannot explicitly disable inherited numbering.
   - `supplement` is `Smart[Supplement?]`, where `Supplement` supports both content and functions. `Smart[&IntoContent]` loses explicit `none` and functional supplements.

   See [elem_views_gen.mbt:12971](/Users/dii/git/typst.mbt/library/elem_views_gen.mbt:12971), [elem_views_gen.mbt:13130](/Users/dii/git/typst.mbt/library/elem_views_gen.mbt:13130), [reference.mbt:6](/Users/dii/git/typst.mbt/library/reference.mbt:6).

   **Change:** Publish a field-state mapping: absent field, `Value::Auto`, `Value::None`, and validated custom value. Deliberate nested optionality is appropriate here: for example, `numbering? : Numbering?`. Preserve the complete engine value domain or explicitly document any initial restriction.

8. **MAJOR — Set rules require ordering, folding, and origin flags, not just property lists.**

   `Styled(...)=styled_with_map(...)` is correct once the styles have correct semantics. The missing part is their construction.

   Evaluated set rules call `.spanned(...).liftable()`. Generated `set_*` methods merely create properties. Realization separately determines `outside`; these flags affect page-level style handling. [eval/rules.mbt:27](/Users/dii/git/typst.mbt/eval/rules.mbt:27), [styles.mbt:104](/Users/dii/git/typst.mbt/library/styles.mbt:104), [realize.mbt:669](/Users/dii/git/typst.mbt/realize/realize.mbt:669)

   Style lists are ordered, and folding can consume every applicable property. For example, relative text sizes compose rather than simply replacing one another. [styles.mbt:539](/Users/dii/git/typst.mbt/library/styles.mbt:539), [text.mbt:259](/Users/dii/git/typst.mbt/library/text.mbt:259)

   **Change:** Define exact rule order and nesting. Preserve repeated properties, custom set parsers, and folding; mark author set rules as liftable while allowing realization to determine `outside`. Consider one ordered `rules` collection instead of separate `set` and `show` arrays, or define their fixed translation explicitly. Add argument locations to style constructors too.

9. **MAJOR — “Equivalent markup” needs a precise definition for text, sequences, and labels.**

   Literal strings are a sensible choice, but they correspond to Typst string-to-content conversion, not arbitrary markup prose. Markup evaluation produces distinct space, paragraph-break, line-break, quote, and symbol elements. [cast.mbt:481](/Users/dii/git/typst.mbt/library/cast.mbt:481), [eval/code.mbt:87](/Users/dii/git/typst.mbt/eval/code.mbt:87)

   Those distinctions are observable to show rules. A text node containing a space is not structurally identical to markup’s `SpaceElem`. Likewise, explicit `Par(...)` content need not equal the pre-layout structure of prose that realization later groups into paragraphs.

   Labels are metadata, not ordinary element fields. Markup attaches a label to the preceding eligible element, skipping `Unlabellable` content and issuing warnings for problematic attachments. [eval/markup.mbt:47](/Users/dii/git/typst.mbt/eval/markup.mbt:47), [content.mbt:99](/Users/dii/git/typst.mbt/library/content.mbt:99)

   **Change:** Define each EDSL operation against an explicit functional Typst expression, such as `#heading("Introduction")`, rather than vaguely against similar-looking syntax. Specify sequence flattening, empty/singleton behavior, and explicit `Space`, `Linebreak`, and `Parbreak`. Define `label=` as a deliberate attachment operation with documented behavior for wrappers, sequences, and unlabellable elements.

10. **MAJOR — Show rules need lifecycle-preserving views and validated selector categories.**

    Passing a typed view is sound if it wraps the exact content supplied by the engine. Realization passes content already guarded against the current recipe. Reconstructing a fresh heading from its fields loses that guard, location, and preparation state, potentially restarting the same show rule. [realize.mbt:369](/Users/dii/git/typst.mbt/realize/realize.mbt:369), [content.mbt:116](/Users/dii/git/typst.mbt/library/content.mbt:116)

    Section 7 also lists selectors without distinguishing their legal uses. The engine rejects location/before/after selectors for show rules, rejects nested regex selectors there, and rejects text selectors for locatable queries. [selector.mbt:351](/Users/dii/git/typst.mbt/library/selector.mbt:351), [selector.mbt:425](/Users/dii/git/typst.mbt/library/selector.mbt:425)

    **Change:** Make `HeadingView.into_content()` preserve the original engine content. Distinguish wrapping the matched element from creating a new element. Validate show selectors and query selectors through their existing cast paths. Preserve recipe order, show-set transformations, delayed errors, and recursion guards. Include tests for identity transforms, wrapping transforms, fresh-element recursion, regex revocation, and invalid selectors.

11. **MAJOR — `Ctx` needs capability, lifetime, typing, and error contracts.**

    A wrapper around `Engine` and `Context` is insufficiently specified. MoonBit callbacks can capture a `Ctx` and reuse it later; that would retain a stale introspector and sink. A general show callback also does not necessarily have a location.

    Existing query operations check contextual access and register an `Introspect` operation. Measurement uses a special measurement locator and inherited styles. [query.mbt:31](/Users/dii/git/typst.mbt/library/query.mbt:31), [measure.mbt:15](/Users/dii/git/typst.mbt/library/measure.mbt:15)

    **Change:** Keep engine internals private, make context-derived operations valid only during the callback invocation, and detect stale use where feasible. Reuse the existing contextual and tracked-introspection paths.

    Specify typed selectors such as `Selector[HeadingView]`, with heterogeneous combinations returning `Content` or an explicit union. Define state initialization and updates as emitted content, rather than captured mutation: the engine’s state update operation constructs a `state-update` element. [state.mbt:203](/Users/dii/git/typst.mbt/library/state.mbt:203)

12. **MAJOR — The public examples are not yet a coherent MoonBit API.**

    Several concrete inconsistencies need executable examples:

    - The introduction passes a one-argument show closure; section 7 specifies two arguments.
    - `HeadingStyle(numbering="1.")` needs an explicit string-to-numbering adapter; the engine `Numbering` is an enum. [numbering.mbt:21](/Users/dii/git/typst.mbt/library/numbering.mbt:21)
    - Constructors advertise validation errors but omit `raise` from their signatures.
    - Heterogeneous style arrays need a common type or conversion trait, which is not defined.
    - `Array[&IntoContent]` supports contextual coercion of literal entries; that does not imply automatic conversion of existing `Array[Heading]` collections.
    - An expected `&IntoContent` does not identify which foreign concrete constructor an unqualified `Heading(...)` denotes. Specify explicit imports or qualified constructors.
    - `standards?=[...]`, `tagged?=true`, and `ppi?=144` misuse optional forwarding; ordinary supplied values use `=`. The proposed “optional `key~`” likewise needs a real optional-parameter signature.

    Constructor lookup and optional forwarding are documented in [MoonBit fundamentals](https://docs.moonbitlang.com/en/latest/language/fundamentals.html); trait-object coercion requires an expected trait-object type. [MoonBit methods](https://docs.moonbitlang.com/en/latest/language/methods.html)

    **Change:** Add a small external consumer package containing every advertised example. Prefer an explicit `Seq(Array[&IntoContent])` plus a generic collection-to-sequence helper. Complete the naming table, including internal API collisions such as element `Align` versus alignment values and `Raw` versus the engine-value escape hatch.

    Also replace `Elem(name, Array[(String, Value)])`: it cannot faithfully represent positional/variadic arguments. The existing argument model distinguishes positional and named arguments and stores their spans. [args.mbt:6](/Users/dii/git/typst.mbt/library/args.mbt:6)

13. **MAJOR — The compile split is feasible, but its preserved responsibilities and world contract must be explicit.**

    `compile_impl` already has a useful boundary between evaluation and `T::create`. The extracted path must retain target-feature checks, library/target styles, fresh memo lifetime, tracked introspection, convergence warnings, and delayed-error promotion. [typst/lib.mbt:74](/Users/dii/git/typst.mbt/typst/lib.mbt:74), [typst/lib.mbt:104](/Users/dii/git/typst.mbt/typst/lib.mbt:104)

    `kit` supplies reusable components, not an existing public ready-to-use world. The CLI’s `SystemWorld` is private. [kit/files.mbt:9](/Users/dii/git/typst.mbt/kit/files.mbt:9), [cli/world.mbt:5](/Users/dii/git/typst.mbt/cli/world.mbt:5)

    **Change:** Specify `DocWorld`’s library/features/formats, virtual main ID, files, fonts, frozen date, and resource snapshot lifetime. Provide an in-memory world and byte/string export methods alongside filesystem writing.

    HTML requires its own compilation target, not conversion of a previously compiled `PagedDocument`; current compilation gates HTML and bundle features. [typst/lib.mbt:75](/Users/dii/git/typst.mbt/typst/lib.mbt:75) Preserve warnings in the high-level API and define precedence between document format settings and explicit export options.

14. **MAJOR — Markup/math escape hatches require evaluation and scope design, and the broader feature surface is incomplete.**

    Math parsing alone does not produce usable content. The existing `eval_string` path parses and evaluates with an engine, context, and scope. Its Math mode returns an equation with `block=false`. Ordinary string evaluation assigns one supplied span to the tree; `eval_string_mapped` supplies internal range spans. [eval/lib.mbt:64](/Users/dii/git/typst.mbt/eval/lib.mbt:64), [eval/lib.mbt:88](/Users/dii/git/typst.mbt/eval/lib.mbt:88), [eval/lib.mbt:139](/Users/dii/git/typst.mbt/eval/lib.mbt:139)

    **Change:** Define escape-hatch scope, parameter injection, import base, evaluation timing, internal error mapping, and block-equation handling. Avoid double-wrapping the equation returned by Math mode.

    Add a feature matrix assigning support or explicit deferral to these missing contracts:

    | Area | Required design decision |
    |---|---|
    | Bibliography | Sources, CSL style, bytes, citation groups/targets, loading errors |
    | Tables/grids | Cells, row/column spans, headers/footers, rules, track sizing, per-cell callbacks |
    | Page/document setup | Paper, margins, headers/footers, numbering, metadata, format settings |
    | State/counters | Typed keys, initialization, update content, `at`/`final` operations |
    | Math | Structured composition and parameter binding beyond interpolated strings |
    | Raw/code | A real raw-text constructor, separate from displaying arbitrary engine values |
    | Images | Byte sources, format hints, alt text, PDF page selection |
    | HTML/bundle | Target-dependent content, attributes, assets, output options |

    These are supported by richer existing engine types: for example, `TableChild`, `Celled[T]`, and `DataSource`. [table.mbt:64](/Users/dii/git/typst.mbt/library/table.mbt:64), [grid.mbt:264](/Users/dii/git/typst.mbt/library/grid.mbt:264), [loading.mbt:5](/Users/dii/git/typst.mbt/library/loading.mbt:5)

15. **MAJOR — The purity and determinism claims are too strong.**

    Section 8 says closures execute on every layout attempt and their results are cached. Actual invocation counts depend on matching, measurement, layout structure, and memo hits. The engine memoizes selected layout operations, not every callback as a standalone function. [memo.mbt:1](/Users/dii/git/typst.mbt/library/memo.mbt:1)

    Compiling twice cannot establish purity. Mutation may leave output unchanged, and an output difference does not uniquely identify its causal callback. Font/resource/date changes can also create differences unrelated to callback purity.

    **Change:** State that callbacks may execute repeatedly or be skipped through memo reuse, with no invocation-count guarantee. Extend the purity contract to custom `IntoContent` implementations and captured mutable engine values. Snapshot inputs.

    Make `check_determinism` a diagnostic heuristic using a frozen world, comparing normalized results, diagnostics, and relevant introspection observations. Instrument callback invocations to report candidate origins; remove the promise that every difference identifies the responsible closure.

16. **MAJOR — Tests and phasing currently cannot establish the claimed equivalence.**

    The existing paged dump includes glyph spans and span offsets, so literal frame-dump identity cannot hold between MoonBit and Typst sources. [frame_dump.mbt:350](/Users/dii/git/typst.mbt/tests/runner/frame_dump.mbt:350)

    Content `repr` snapshots also miss important structure, and ordinary content equality ignores some field categories. [content.mbt:365](/Users/dii/git/typst.mbt/library/content.mbt:365) Native host callbacks cannot be literally identical to evaluator closures: their variants and observable names/reprs differ. [func.mbt:171](/Users/dii/git/typst.mbt/library/func.mbt:171), [func.mbt:340](/Users/dii/git/typst.mbt/library/func.mbt:340)

    **Change:** Define equivalence at separate levels:

    - Constructor/set-rule lowering: normalized fields, absent versus explicit values, labels, ordered styles, flags, warnings, and errors.
    - Layout: normalized frames with provenance excluded and location relationships preserved.
    - Behavior: show order/guards, counters, state, queries, measurements, callback identity, and memo enabled versus disabled.
    - Export: SVG, PNG pixels, HTML semantics, PDF semantics/tags, and bundle contents.
    - Provenance: a separate assertion suite covering Unicode, escapes, arrays, wrappers, repeated/data-driven content, long text, and span-capacity boundaries.

    Test interactions and invalid inputs—not merely each optional field once.

    Provenance cannot wait until phase 3 because it changes construction and ownership. The phase-1 example also already requires show rules, context/page numbering, and references, which the plan places later. Move a minimal provenance implementation and callback bridge into the first vertical slice.

    Finally, upstream `jump_from_click` needs adaptation: its text path loads a Typst source and finds a syntax node. Synthetic table indices do not satisfy that assumption. [jump.rs:268](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-ide/src/jump.rs:268) HTML has text-node spans rather than engine-shaped glyph runs, and some generated frame shapes have detached spans. [html/dom.mbt:9](/Users/dii/git/typst.mbt/html/dom.mbt:9), [frame.mbt:425](/Users/dii/git/typst.mbt/library/frame.mbt:425) Define container-level fallback provenance for regions without an exact leaf origin.

17. **MINOR — Resolve the units policy and retain the proposed package placement.**

    A single `Rel` enum is implementable, but the rationale should acknowledge that MoonBit’s `Add` is homogeneous: `add(Self, Self) -> Self`. Separate types require explicit promotion or another operation for mixed addition. [/builtin/operators.mbt:17](/Users/dii/.moon/lib/core/builtin/operators.mbt:17)

    The engine already represents unresolved lengths and relative lengths directly. [length.mbt:7](/Users/dii/git/typst.mbt/library/length.mbt:7), [rel.mbt:5](/Users/dii/git/typst.mbt/library/rel.mbt:5) Either retain `Rel` with checked, argument-localized conversion errors, or choose typed lengths with explicit relative promotion. Preserve arithmetic evaluation order when lowering `Sum`.

    Keeping `doc/` in this module is appropriate for synchronized generator and engine changes. Same-module placement does not grant access to package-private implementations; design against exported APIs from the start. A later module move can preserve implementation structure, but changes consumer import paths. Consider separating filesystem/export conveniences from the construction package.

The toolchain version stated in the document matches the installed `moon`, and the checked-in evaluation goldens contain 3,792 cases. Custom constructors and the local autoloc types are real; the broad EDSL direction is technically supported.

This was a read-only review. I changed no files and did not run the differential suite. A compiler probe could not complete because `moonc check -no-mi` still attempted to write an AST artifact in the read-only environment.

VERDICT: REQUEST CHANGES

