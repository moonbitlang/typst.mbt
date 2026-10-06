# Codex review of docs/edsl-ports.md, revision 1 (gpt-6-astra, xhigh, 2026-10-06)

The proposal needs changes before approval. Most facade additions are feasible without changing the engine, but the provenance claim, callback composition, lint guarantees, and reduced equivalence standard are not sound as written.

I reviewed the proposal, revision 8, the five named ports, additional helpers, and the published 0.1.4 interface. This was a static review; I did not rebuild or modify files.

**1. Marks: implementable, but the claimed provenance mechanism does not exist.**

[Proposal lines 130–132](/Users/dii/git/typst.mbt/docs/edsl-ports.md:130) say section 12.4 maps through removed mark characters. It explicitly says the opposite: engine offsets are hints, and exact mapping requires a separately reviewed engine change through slicing, directional embedding, and case conversion ([revision 8, §12.4](/Users/dii/git/typst.mbt/docs/edsl-design.md:1494)).

`Pieces` assigns distinct **synthetic spans**, not positions in the original string. Its counter shortens ranges in an origin-listing token; it contains no input-text offset map ([doc/lower.mbt:370](/Users/dii/git/typst.mbt/doc/lower.mbt:370)). `resolve_glyph` returns the engine offset unchanged, except for suppressing known unreliable offsets ([doc/origin.mbt:660](/Users/dii/git/typst.mbt/doc/origin.mbt:660)). The newer source-character matcher requires the entire rendered text to match the literal; removing marks breaks that condition ([doc/review_locate.mbt:96](/Users/dii/git/typst.mbt/doc/review_locate.mbt:96)).

A marks parser can therefore preserve call/argument origins and distinct pieces without engine changes. It cannot promise the proposed character mapping using existing machinery. Either retain honest argument-level fallback or propose the missing mapping work separately.

The semantic amendment also needs to be explicit:

- Revision 8 guarantees `_`, `*`, backslashes, and other punctuation remain literal in `Prose`, including ordinary interpolated strings ([design:327](/Users/dii/git/typst.mbt/docs/edsl-design.md:327)). Opt-in marks can reasonably amend that guarantee, but “interpolation works as before” is insufficient: `Para("\{data}", marks=true)` necessarily parses punctuation supplied by `data`, unless authors use `Lit(data)`.
- Specify nesting, unmatched delimiters, escaping order, multiline code, link destinations containing parentheses, empty labels, and placeholders inside code/link syntax. Define “word boundary” for Chinese and Unicode.
- Specify functional twins, not “Typst markup of the same shape.” `**strong**` is the proposed syntax, not Typst’s strong syntax. The twin should use `strong(...)`, `emph(...)`, `raw(...)`, and `link(...)`, with literal text and the established `Prose` whitespace/quote expansion. Raw markup and `raw("")` even differ for the empty case ([design:273](/Users/dii/git/typst.mbt/docs/edsl-design.md:273)).

The evidence supports convenience, but not the assertion that four authors wrote the same parser. H2 combines a `c("x")` helper with parsers ([proposal:54](/Users/dii/git/typst.mbt/docs/edsl-ports.md:54)); the evaluation port uses the former ([typst-evaluation:113](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/typst-evaluation/typst-evaluation.mbtx:113)). The Chinese parser supports `{{tag}}` and `__dimmed__`, whereas minisql uses `__emphasis__` ([tun-poc-zh:233](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/tun-poc-zh/tun-poc-zh.mbtx:233), [minisql:311](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/minisql-field-report/minisql-field-report.mbtx:311)). A separately named `MarkedProse`, initially in an optional package, is a cheaper way to explore this without expanding `Prose`’s contract immediately.

**2. `Layout` needs a `Ctx`, and the kit must respect callback creation rules.**

The engine already supplies both location and styles to the layout callback. No engine change is needed for a typed wrapper. However, the proposed `size => ...` signature omits the `Ctx` required by `cx.measure`. Use a fallible signature such as `(Size, Ctx) -> &IntoContent raise`, backed by the existing host-function path ([layout/rules.mbt:1121](/Users/dii/git/typst.mbt/layout/rules.mbt:1121), [doc/context.mbt:89](/Users/dii/git/typst.mbt/doc/context.mbt:89)).

Also correct “available size”: it is `regions.base()`, the outer container’s base dimensions, not necessarily remaining page space. Upstream explicitly documents the block boundary, restrictions on page-relative placement/pagebreaks, and potentially infinite dimensions ([upstream layout.rs:27](/Users/dii/git/typst.mbt/.repos/typst/crates/typst-library/src/layout/layout.rs:27)). `Cards`, `Flow`, and auto-width `Canvas` need policies for infinite or unusable widths.

The larger composability issue is unacknowledged. Creating a `Layout` or `Context` description inside another callback is currently rejected. This affects, for example, a show callback constructing `Cards`, or a `Cards` layout callback constructing measurement-based `Chip`s. The same issue applies to freshly created `Cells` callbacks in a `DataTable` returned from a callback ([doc/session.mbt:97](/Users/dii/git/typst.mbt/doc/session.mbt:97)).

Revision 8 deliberately reserves lifting this restriction for a separate identity/convergence design ([design:1206](/Users/dii/git/typst.mbt/docs/edsl-design.md:1206)). The proposal must choose among preconstructed callback-bearing values, context-taking eager helper variants, documented restrictions, or that larger change. Nesting `Context` inside `Layout` is not a valid workaround.

**3. The typed additions need more precise contracts.**

| Addition | Assessment |
|---|---|
| `Para` | Feasible as `Par(Prose(text, ...), ...)`, preserving evaluator calls. Its twin is `par` containing the **functional Prose expansion**, not arbitrary `#par[text]`. Existing `Par` and `Prose` provide the necessary paths ([elements_gen:279](/Users/dii/git/typst.mbt/doc/elements_gen.mbt:279), [prose:175](/Users/dii/git/typst.mbt/doc/prose.mbt:175)). Define argument-location remapping and ownership of generated origins; blindly forwarding one `loc/args_loc` to differently shaped constructors is unsafe because registry entries deduplicate by location and key path ([origin:159](/Users/dii/git/typst.mbt/doc/origin.mbt:159)). |
| `Box(baseline=Length)` | Implementable, but only exposes the **shift** form. The engine accepts `auto`, vertical alignment, relative length, or `(at:, shift:)`, and folds the two fields independently ([container:304](/Users/dii/git/typst.mbt/library/container.mbt:304), [container:370](/Users/dii/git/typst.mbt/library/container.mbt:370)). Either call this a deliberate subset with an escape hatch, or expose a baseline facade. Its twin is `box(baseline: value, ...)`; a length does not mean “set the baseline to this coordinate.” |
| `TextEdge` | A shared superset enum is possible under revision 8’s runtime-cast policy. It does not make all combinations valid: top accepts ascender/cap-height/x-height/baseline/bounds; bottom accepts baseline/descender/bounds ([text:385](/Users/dii/git/typst.mbt/library/text.mbt:385), [text:491](/Users/dii/git/typst.mbt/library/text.mbt:491)). Document these constraints or use separate edge types. Lower to existing strings/lengths and test constructors and set rules. |
| `Dash` | Presets are straightforward. `Pattern(Array[Length], phase~)` omits Typst’s `"dot"`/line-width entry ([stroke:523](/Users/dii/git/typst.mbt/library/stroke.mbt:523)). It also needs explicit `auto`/`none` and a migration/escape policy for today’s `dash : Value` ([facades:76](/Users/dii/git/typst.mbt/doc/facades.mbt:76)). `Solid` should lower to `"solid"`; do not silently equate it with `none`, since the engine represents an empty pattern and no pattern differently ([stroke:16](/Users/dii/git/typst.mbt/library/stroke.mbt:16), [stroke:392](/Users/dii/git/typst.mbt/library/stroke.mbt:392)). |
| Paint methods | Feasible through deferred native calls; the public native wrappers already take the receiver explicitly, so a new engine method mechanism is unnecessary ([funcs_gen:16349](/Users/dii/git/typst.mbt/library/funcs_gen.mbt:16349), [funcs_gen:16817](/Users/dii/git/typst.mbt/library/funcs_gen.mbt:16817)). They accept **colors**, whereas `Paint` also represents gradients and tilings ([paint:5](/Users/dii/git/typst.mbt/library/paint.mbt:5)). Specify rejection of unsupported paints and ratio units. |
| `Length::sizing/spacing` | Straightforward aliases for `Rel(self)`, with no engine change. Both current `Rel` cases already preserve the underlying value ([units:90](/Users/dii/git/typst.mbt/doc/units.mbt:90), [units:131](/Users/dii/git/typst.mbt/doc/units.mbt:131)). |
| `Upper` / `Lower` | Feasible native-function wrappers. Specify a content twin such as `upper[#body]`: string uppercasing eagerly changes the string, while content uppercasing installs a text case property, so `upper("x")` is not structurally interchangeable ([case:17](/Users/dii/git/typst.mbt/library/case.mbt:17)). |
| `Outline(title=NoneValue())` | Already implemented, including in published 0.1.4. The interface accepts `&IntoContent`, `NoneValue` implements it, and lowering preserves its `none` value ([published interface:1032](/Users/dii/.moon/cache/deps/v1/sources/moonbitlang/typst/0.1.4/doc/pkg.generated.mbti:1032), [published interface:1077](/Users/dii/.moon/cache/deps/v1/sources/moonbitlang/typst/0.1.4/doc/pkg.generated.mbti:1077), [lower:814](/Users/dii/git/typst.mbt/doc/lower.mbt:814)). Reclassify T9 as discoverability/documentation. |

Two Paint details would change the evidence ports’ output:

- `transparentize(t)` multiplies existing alpha by `1-t`; it is not an absolute alpha setter. The Chinese helper implements an absolute CSS alpha byte ([color:657](/Users/dii/git/typst.mbt/library/color.mbt:657), [color:1241](/Users/dii/git/typst.mbt/library/color.mbt:1241), [tun-poc-zh:122](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/tun-poc-zh/tun-poc-zh.mbtx:122)). Name the operation honestly or define the conversion, including already-transparent inputs.
- Typst’s default mix space is Oklab; the port explicitly mixes in sRGB. Specify weights, mixing space, and rounding before promising unchanged pages ([color:1790](/Users/dii/git/typst.mbt/library/color.mbt:1790), [tun-poc-zh:127](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/tun-poc-zh/tun-poc-zh.mbtx:127)).

**4. Construction-time `Sides` errors contradict the accepted architecture; located errors need a reproducer.**

`Sides::zero()` is a useful `Sides[Length]` convenience whose twin is uniform `0pt`. But “`Sides::none()` given to a length-typed parameter raises at construction” is not the current model:

- `Sides[T]` stores a generic explicit state; conversion is nonfallible ([facades:239](/Users/dii/git/typst.mbt/doc/facades.mbt:239), [facades:290](/Users/dii/git/typst.mbt/doc/facades.mbt:290)).
- The generator deliberately erases `Smart`/`Option` layers, so the facade type alone does not encode a field’s complete acceptance rules ([docgen.py:236](/Users/dii/git/typst.mbt/scripts/docgen.py:236)).
- Constructors explicitly do not raise; invalid descriptions become located diagnostics during lowering ([content.mbt:50](/Users/dii/git/typst.mbt/doc/content.mbt:50)). Revision 8 intentionally leaves legal conversion to the field’s engine cast ([design:709](/Users/dii/git/typst.mbt/docs/edsl-design.md:709)).

Keep that rule and improve the located diagnostic. Early validation would need an explicit architectural amendment and field-specific metadata, not just a generic `Sides` method.

For T10, the inspected path already attaches the holding argument’s span to nested value calls; `Stroke` then uses `Args::named`, which attaches that span to cast errors ([lower:662](/Users/dii/git/typst.mbt/doc/lower.mbt:662), [lower:823](/Users/dii/git/typst.mbt/doc/lower.mbt:823), [stroke:57](/Users/dii/git/typst.mbt/library/stroke.mbt:57), [args:183](/Users/dii/git/typst.mbt/library/args.mbt:183)). The relevant published lowering path has the same span logic ([published lower:662](/Users/dii/.moon/cache/deps/v1/sources/moonbitlang/typst/0.1.4/doc/lower.mbt:662)).

That does not disprove the observation, but it means the proposal has not identified its cause. Add the exact failing constructor/helper and rendered diagnostic before designing a general fix. Preserve precise existing locations; do not replace all nested errors with the outer constructor’s location.

**5. The kit can have functional Typst twins; dropping them is unjustified.**

“No Typst element” does not imply “no Typst twin.” Revision 8 requires functional expressions, including sequences, rules, callbacks, and arithmetic—not one native element per constructor ([design:1793](/Users/dii/git/typst.mbt/docs/edsl-design.md:1793)). Each proposed kit component can have a Typst helper definition using the same primitives.

Testing a component against its own EDSL expansion verifies the wrapper, but provides no independent check of the chosen semantics. “Same frames” also drops structural/diagnostic checks, memoization-on/off comparison, and SVG/PDF/PNG equivalence required by section 16 ([design:1820](/Users/dii/git/typst.mbt/docs/edsl-design.md:1820)). Keep those gates for representative kit twins.

The kit contracts need additional work:

- **Chip / Canvas baseline:** `measure` already returns a baseline, but `Ctx::measure` discards it. Expose a measurement result containing baseline before implementing baseline anchors; this is a facade change, not an engine change ([library/measure.mbt:45](/Users/dii/git/typst.mbt/library/measure.mbt:45), [doc/context.mbt:80](/Users/dii/git/typst.mbt/doc/context.mbt:80)). Bench currently estimates it as `0.72 * size`, exactly the approximation the new API should remove ([bench:342](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/bench/bench.mbtx:342)).
- **Cards / Flow:** define measurement width, surrounding styles, inset accounting, oversized items, pagination, and identical keyed content during measurement and final layout. Measurement uses location-dependent locator machinery, so this matters beyond geometry ([measure:30](/Users/dii/git/typst.mbt/library/measure.mbt:30)). The health port currently measures unkeyed content and renders keyed content; copying that implementation would not establish general introspection correctness ([mooncakes-health:1013](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/mooncakes-health/mooncakes-health.mbtx:1013)).
- **DataTable:** the proposed signature omits column sizing, although both sampled table helpers require it. It also needs a policy for spanning cells, repeated headers, row breaking, and clipped multipage frames ([session-migrations:259](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/session-migrations/session-migrations.mbtx:259), [mooncakes-health:795](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/mooncakes-health/mooncakes-health.mbtx:795), [minisql:509](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/minisql-field-report/minisql-field-report.mbtx:509)).
- **Verbatim:** specify tabs, CRLF, blank/trailing lines, wrapping, and what `lang` means without `raw`. Description interpolation is currently consumed by `Prose`, whose whitespace behavior is unsuitable unchanged ([prose:236](/Users/dii/git/typst.mbt/doc/prose.mbt:236), [prose:216](/Users/dii/git/typst.mbt/doc/prose.mbt:216)). A public-only adapter could preserve whitespace through `Lit` and explicit `Linebreak` descriptions before using `Prose(quotes=false)`; alternatively accept structured lines/spans. The evaluation port already demonstrates the latter composition ([typst-evaluation:176](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/typst-evaluation/typst-evaluation.mbtx:176)).
- **All components:** specify caller-location forwarding and argument mapping, while preserving supplied children’s origins. Row keys alone do not locate generated frames, labels, or formatting errors.

**6. L1–L4 need different data and different guarantees.**

| Lint | What can actually be implemented |
|---|---|
| **L1: adjacent inline children** | A conservative description-level heuristic. `Node` contains generic calls, embedded engine content, evaluations, and opaque callbacks; it has no universal block/inline classification ([content:23](/Users/dii/git/typst.mbt/doc/content.mbt:23)). `Prose` itself expands into adjacent inline nodes ([prose:182](/Users/dii/git/typst.mbt/doc/prose.mbt:182)). Define author-level boundaries, transparent wrappers, handling of rules/whitespace, intentional inline sequences, and unknown callback/show results. A complete semantic guarantee needs information from realization. |
| **L2: `.notdef`** | Mostly feasible from paged frames: glyph ID, text-cluster byte range, text, and span are present ([text_item:5](/Users/dii/git/typst.mbt/library/text_item.mbt:5), [text_item:94](/Users/dii/git/typst.mbt/library/text_item.mbt:94)). Report a cluster/code-point sequence rather than always “the character.” Ranges saturate at 65,535, and existing review code explicitly handles unknown text afterward ([inline_shaping:637](/Users/dii/git/typst.mbt/layout/inline_shaping.mbt:637), [review_select:71](/Users/dii/git/typst.mbt/doc/review_select.mbt:71)). Guaranteeing exact characters in every case needs additional shaping-time data. |
| **L3: fixed-container/page overflow** | Page-boundary geometry checks are possible. The general fixed-container promise is not supported by frames alone. Frames store size/items/kind; groups store transforms/clips, but neither records the fixed-size declaration and its origin ([frame:21](/Users/dii/git/typst.mbt/library/frame.mbt:21), [frame:624](/Users/dii/git/typst.mbt/library/frame.mbt:624)). Some frames are flattened ([frame:298](/Users/dii/git/typst.mbt/library/frame.mbt:298)). Explicit boxes/blocks preserve hard boundaries, but that still does not identify fixed versus automatic sizing or its author ([inline_box:32](/Users/dii/git/typst.mbt/layout/inline_box.mbt:32), [flow_block:236](/Users/dii/git/typst.mbt/layout/flow_block.mbt:236)). Require a layout side channel with container identity, bounds, origin, clipping, and fragment relationships—or narrow the lint. |
| **L4: repeated unkeyed call site** | Count logical occurrences during lowering, including callback results, not merely the initial tree or deduplicated origin registry ([session:152](/Users/dii/git/typst.mbt/doc/session.mbt:152), [origin:179](/Users/dii/git/typst.mbt/doc/origin.mbt:179)). Define deduplication across measurement and layout retries, threshold, and suppression. Runtime descriptions cannot determine whether repetition came from a loop, missing `#callsite`, or deliberate reuse; reuse is explicitly valid ([design:1448](/Users/dii/git/typst.mbt/docs/edsl-design.md:1448)). Phrase this as review ambiguity, not proof of an authoring mistake. |

L3 also cannot catch S3 merely by finding overflowing geometry: an unwanted extra page may have entirely in-bounds content. Its exclusion of clipped containers means it will deliberately miss clipped-off content. These limitations must appear in the success criteria.

**7. Section 2.4 is partly correct, but needs qualification.**

The raw default is indeed `0.8em`, and nested relative text sizes compound ([text_raw:130](/Users/dii/git/typst.mbt/library/text_raw.mbt:130), [text:259](/Users/dii/git/typst.mbt/library/text.mbt:259)). Auto columns use measured content widths, then distribute remaining space to fractional columns or shrink auto columns ([grid_layouter:930](/Users/dii/git/typst.mbt/layout/grid_layouter.mbt:930)). Those are sound documentation topics.

However:

- “Sticky binds one block” is misleading. It attaches to the following block, consecutive sticky blocks form a group, and stickiness can be disabled when moving the group cannot improve the situation ([flow_distribute:473](/Users/dii/git/typst.mbt/layout/flow_distribute.mbt:473)).
- Unspecified stroke sides **inherit**; they are not invariably reset to a universal default. Dictionary parsing leaves them unspecified and folding takes outer values ([sides:124](/Users/dii/git/typst.mbt/library/sides.mbt:124), [sides:273](/Users/dii/git/typst.mbt/library/sides.mbt:273)). `rest=Stroke::none()` is an explicit kit styling choice.
- S2 should distinguish breakable `Block` from inline `Box`: boxes use an unbreakable pod, whereas blocks can produce multiple fragments ([inline_box:17](/Users/dii/git/typst.mbt/layout/inline_box.mbt:17), [flow_block:102](/Users/dii/git/typst.mbt/layout/flow_block.mbt:102)).

**8. Missing alternatives and measurements affect both scope and ordering.**

The ports contain useful cheaper designs that deserve evaluation first:

- Session migrations already gets equal-height cards from grid cell fill/stroke/inset, without `Layout + measure`. Use that for square-corner cards; reserve measurement for requirements such as individually rounded containers ([session-migrations:344](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/session-migrations/session-migrations.mbtx:344)).
- `format` omits the collation helper listed under H7, and `Canvas` does not remove chart tick generation. Either include them or explicitly exclude them from projected helper savings ([mooncakes-health:534](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/mooncakes-health/mooncakes-health.mbtx:534), [bench:200](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/bench/bench.mbtx:200)).
- `break_anywhere` is not the same operation as the port’s punctuation-based break insertion. Specify grapheme handling and effects on extracted/copied text; the existing helper inserts U+200B into raw content ([session-migrations:79](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/session-migrations/session-migrations.mbtx:79)).
- Number/date helpers need actual contracts: negative values, rounding, nonfinite values, locale, timezone. The benchmark’s `fixed` is a narrow arithmetic implementation, and the health report deliberately chooses the timestamp’s UTC zone rather than browser-local time ([bench:120](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/bench/bench.mbtx:120), [mooncakes-health:592](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/mooncakes-health/mooncakes-health.mbtx:592)).
- Document `font_paths` early and keep comparison fonts fixed. The API already supports explicit paths independently of system discovery ([doc/system/system.mbt:22](/Users/dii/git/typst.mbt/doc/system/system.mbt:22)).

Move the guide and reproducible failure fixtures to the beginning. They address several demonstrated discovery failures immediately. Then implement `Para`, the narrow typed gaps, diagnostic fixes supported by reproducers, and `Layout` with measurement baseline. Build one kit component with full twins before committing to the whole package. Prototype L2 early; scope L1/L4 carefully; separate L3’s instrumentation and exact text mapping into explicit design decisions.

The success measure also needs revision:

- The 15,705-line total is reproducible, but a pooled 36% helper share is not “a third of every script.” Define helper boundaries, exclude generated data consistently, and report absolute helper lines and per-port results.
- “Independent authors” overstates the experimental independence: the brief explicitly instructed copying the reference helpers and supplied known findings ([BRIEF:15](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/BRIEF.md:15), [BRIEF:52](/Users/dii/git/typst.mbt/_build/edsl-demo/ports/BRIEF.md:52)). Record which findings were independently discovered versus reused.
- “Every silent failure impossible or linted” is not achievable under these definitions. S3 need not overflow; S6 depends on intended prose. Use per-finding acceptance tests covering prevention, diagnostic, or explicit documented choice.
- “Pages unchanged” conflicts with correcting failures, replacing approximate baselines, changing mix semantics, or adding fonts. Establish synthetic baselines **before** rewriting, then distinguish parity-preserving refactors from approved visual corrections.
- Retain section 16’s structural, layout, export, and memoization gates, and add provenance tests plus compile/layout performance measurements. Helper percentage alone rewards moving complexity rather than reducing it.

**VERDICT: REQUEST CHANGES**

Required changes:

1. Remove the nonexistent text-offset guarantee; specify marks grammar, interpolation behavior, provenance fallback, and exact functional twins.
2. Give `Layout` a fallible callback with `Ctx`; document base-size semantics and resolve callback-bearing kit composition under revision 8’s creation rule.
3. Correct the baseline, edge, dash, and color contracts; retain explicit states and escape paths; classify `Outline(NoneValue())` as already supported.
4. Keep conversion validation in the accepted lowering model unless explicitly redesigning it; supply reproducers for unlocated errors.
5. Restore functional Typst twins and section 16 gates for kit components.
6. Specify kit measurement, baseline, pagination, styling, interpolation, and caller-provenance behavior.
7. Replace the blanket lint promises with implementable contracts and explicitly identify any required engine instrumentation.
8. Correct section 2.4 and the evidence claims; move documentation/reproducers earlier and replace the success measure with reproducible per-finding and per-port gates.

Optional changes:

1. Trial marks in a separately named constructor/package before adding a `Prose` flag.
2. Start the kit with styled-grid cards and a configurable table helper; add measurement-heavy abstractions after those limits are demonstrated.
3. Keep formatting/collation utilities separable from document layout and adopt explicit font fixtures before deciding to embed another family.
