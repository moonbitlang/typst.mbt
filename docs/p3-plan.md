# P3 plan: realization, introspection and the `html` stage

Goal: a new differential stage `html` (oracle: `oracle/src/html.rs`, goldens in
`tests/golden/html`, 508 suite cases) that runs `typst::compile` with the
HTML target and encodes the document exactly like upstream
(`typst_html::html` with `pretty: true`).

This plan was drafted with Codex (gpt-6-astra) review; upstream references
are to the pinned revision.

Keep the Value-backed representation and add typed views over it. For convergence, preserve **two distinct layers: recorded introspector reads for iteration control, and high-level introspections for diagnostics**. Full 508-case parity also requires some layout/SVG and bibliography support.

References below are to pinned revision `e58a63af09032a486b12241d08ebd04131483221`. No files were modified.

1. **Replace comemo with explicit read recording.**

   - The explicit upstream API is **`Engine::introspect<I: Introspect>(…) -> I::Output`**: it evaluates the inquiry and appends `Introspection::new(inquiry)` to the sink. `Sink::introspections()` exposes those requests. It does **not** currently store their outputs. See [engine.rs:104](.repos/typst/crates/typst-library/src/engine.rs:104), [convergence.rs:93](.repos/typst/crates/typst-library/src/introspection/convergence.rs:93).

   - **High-level replay alone is not an exact replacement for `Constraint::validate`.** An inquiry can reduce a changing query result to an unchanged boolean; comemo still detects the changing lower-level result. Upstream explicitly documents this distinction and permits suppressing convergence warnings despite failed comemo validation. See [convergence.rs:37](.repos/typst/crates/typst-library/src/introspection/convergence.rs:37).

   - Implement a library-owned `Introspector` facade over a target-specific backend, with an optional iteration recorder. At each public introspector method boundary, record **method + immutable arguments + result fingerprint**, including error results before raising. Replay those calls against the newly built introspector with recording disabled. Cover the whole tracked trait: query variants, counts, locator, page/position/numbering/supplement, anchor, document and path—not just `query`. This replaces the tracked boundary at [introspector.rs:28](.repos/typst/crates/typst-library/src/introspection/introspector.rs:28).

   - Separately port high-level request variants and their diagnostic logic: queries, counters, state, locations, measurement, link anchors and bibliography. `Engine::introspect` records these in call order. At exhaustion, replay **the last iteration’s requests** against `[empty, I₁, I₂, I₃, I₄, I₅]`, using fresh engines and disposable sinks. Compare outputs from `I₄` and `I₅`; include `Result` success/error distinctions. Counters/state require an engine because they execute user functions. See [convergence.rs:215](.repos/typst/crates/typst-library/src/introspection/convergence.rs:215), [counter.rs:787](.repos/typst/crates/typst-library/src/introspection/counter.rs:787).

   - Port the driver literally: feature check; target style; evaluate once; create output using the previous introspector; validate; stop after at most five creations. Retain evaluation diagnostics and only the accepted/final iteration’s sink. Then append convergence warnings and promote delayed errors. Immediate creation errors propagate directly. See [typst/lib.rs:100](.repos/typst/crates/typst/src/lib.rs:100).

2. **Generate typed views and field operations; retain Value storage.**

   - Generate `HeadingElem(Content)`-style wrappers with a private checked invariant; `Content::to_packed_heading() -> HeadingElem?`, `HeadingElem::new(required…)`, `pack()`, and metadata forwarding. Generate immutable `with_*`/`without_*` replacements, consistent with existing `Content`; do not expose mutable aliases to its slots. Upstream’s erased native rules likewise validate the element before invoking a typed rule: [styles.rs:1111](.repos/typst/crates/typst-library/src/foundations/styles.rs:1111).

   - Suggested mechanical translation: `elem.body` → `elem.body()`; `elem.level.get(styles)` → `elem.level(styles)`; `styles.get(HeadingElem::level)` → `HeadingElem::level_in(styles)`. Generate separate property constructors such as `HeadingElem::set_level(value) -> Property`.

   | Field kind | Generated API and semantics |
   |---|---|
   | Required | `body() -> T`; constructor requires it; no style fallback. |
   | Settable | `level(styles) -> T`, `level_local() -> T?`, `with_level(T)`, `without_level()`, style-only getter/property constructor. |
   | Synthesized | Raw getter returns `T?`; synthesis writes `Some(T)`; no default or style lookup. |
   | Ghost | Style-only getter/property constructor; no instance storage. |
   | Internal | Typed access by generated field ID; excluded from user reflection. |
   | External | Documentation/parameter metadata only; no stored field/view accessor. |
   | Fold/resolve | Fold through `get_value_with_local`; generate a separate resolving getter returning the resolved type. |

   - Preserve **unset versus explicitly `none`**: a field of type `Option[T]` needs an outer option for slot presence. `#[positional]` alone does not make a field required; variadic implies required, and required implies positional. Internal fields with custom `#[parse]` can participate in construction/set parsing. The authoritative macro definitions are [elem.rs:57](.repos/typst/crates/typst-macros/src/elem.rs:57), [elem.rs:199](.repos/typst/crates/typst-macros/src/elem.rs:199), [elem.rs:298](.repos/typst/crates/typst-macros/src/elem.rs:298), [elem.rs:637](.repos/typst/crates/typst-macros/src/elem.rs:637).

   - **`resolve` is not an elem attribute at this revision.** The macro installs typed field metadata and fold callbacks; `Settable::resolve` performs `get_cloned(styles).resolve(styles)`. Non-folded local values win directly; folded locals combine with the already-folded style result. Preserve that order and avoid resolving twice. See [elem.rs:467](.repos/typst/crates/typst-macros/src/elem.rs:467), [field.rs:495](.repos/typst/crates/typst-library/src/foundations/content/field.rs:495).

   - Add generator storage codecs for internal payloads, independently of user-facing casts. For example, `TagElem.tag` is required/internal and contains a native `Tag`; give it a typed internal `DynValue` carrier. Do not leave required P3 types mapped to permissive `Value` fallbacks. See [tag.rs:63](.repos/typst/crates/typst-library/src/introspection/tag.rs:63).

3. **Keep dependency interfaces in `library`; assemble implementations in `typst`.**

   - Dependency direction: `eval → library`, `realize → library`, `html → library`, `typst → {library, eval, realize, html}`. HTML invokes realization through `Routines`; the driver installs callbacks. Add `rules`, `realize`, `layout_frame`, `html_mathml_body`, and `html_span_filled` to the existing eval callbacks. Upstream defines precisely these boundaries: [routines.rs:51](.repos/typst/crates/typst-library/src/routines.rs:51), [typst/lib.rs:329](.repos/typst/crates/typst/src/lib.rs:329).

   - `library` owns shared runtime types: `Target`, output/introspector interfaces, `ElementIntrospector[P]` and builder, query recorder, convergence diagnostics, locations/locators/tags, counters/state, element capabilities, native-rule registry, realization kinds and `(Content, StyleChain)` pairs. Replace Rust arena lifetimes with owned/shared immutable values. Upstream already places realization support types in `library` specifically to break dependencies: [routines.rs:114](.repos/typst/crates/typst-library/src/routines.rs:114).

   - `realize` owns traversal, preparation, show-rule execution, grouping, spacing and regex rules. Preserve preparation order: pre-synthesis for selector matching; collect user show-set rules; assign location; built-in ShowSet; synthesis with combined styles; materialization; tag snapshot; mark prepared. See [realize/lib.rs:437](.repos/typst/crates/typst-realize/src/lib.rs:437).

   - `NativeRuleMap` belongs in `library`, keyed by `(Element, Target)`, with checked erased closures wrapping typed views. Preserve its initial special rules and register-versus-replace assertions. HTML registers its rules from `html`. See [styles.rs:990](.repos/typst/crates/typst-library/src/foundations/styles.rs:990).

   - `html` owns `HtmlDocument`, DOM, conversion, rule implementations, CSS processing, encoding, MathML, anchor assignment and `HtmlIntrospector`. **One deliberate package adjustment:** with the existing closed `DynValue` and library-owned generated elements, keep HTML element field types/codecs—`HtmlTag`, attributes, CSS property storage, etc.—in `library` or a dependency beneath it. Do not introduce `library → html`. `HtmlElem` directly stores these types upstream: [format.rs:205](.repos/typst/crates/typst-html/src/format.rs:205).

4. **Sequence by interface barriers, then parallel ownership.**

   | Work unit | Ownership / dependency | Reviewable completion |
   |---|---|---|
   | A. Contracts + generator | One owner for `elemgen.py`, `typemap.py`, generated files and shared runtime signatures | Typed views, internal codecs, recorder/backend contracts, expanded `Routines` |
   | B. Introspection | After A’s contracts; dedicated library introspection files | Locator/tag builder, selectors, recorded reads, high-level diagnostics; connect existing counter/state code and real Count hooks |
   | C. Realization | After typed APIs; `realize/*` | Full show/preparation/grouping pipeline with synthetic introspectors |
   | D. HTML foundation | Parallel with B/C; DOM/tag/attr/CSS/encode files | Exact serialization from hand-built DOM, including failure diagnostics |
   | E. HTML semantics | After C/D APIs | Native rules, conversion, document finalization, HTML introspector and anchors |
   | F. Driver + runner | Scaffold against A; integrate after B/E | `html` stage, feature handling, five-iteration loop, pretty output and diagnostic parity |
   | G. Coverage closure | Split by element families after first end-to-end pass | MathML, tables, references/footnotes, bibliography, images and frame/SVG cases |

   - During B/C/D, a fourth agent can own F’s scaffold and test harness. Later split E/G by files or element families. Keep one integrator for rule registration and shared hooks; regenerate generated files after merges rather than resolving generated conflicts manually.
   - **Critical path:** A → C → E → F, with B required before convergence-dependent acceptance. D runs alongside B/C. Full parity adds whichever of bibliography or frame/layout/SVG remains longest.
   - First end-to-end slice: plain text → paragraph realization → default HTML document → pretty encoding → warning output. Then add contextual target/query/state/counter tests, followed by links and non-convergence.
   - Mirror the oracle’s exact selection and formatting: only `html` targets, per-test features, `pretty=true`, export errors and warnings. Preserve the eval baseline throughout. See [oracle/html.rs:19](oracle/src/html.rs:19), [oracle/html.rs:44](oracle/src/html.rs:44).

5. **Treat these as the main fidelity risks.**

   - **Fingerprint equality differs from Typst equality.** `0` and `0.0` must differ for convergence. Content hashing includes metadata, span and payload beyond ordinary content equality. Implement a dedicated structural fingerprint matching upstream’s hashed information; do not reuse `Value::Eq`, `Content::Eq` or `repr`. `LazyHash` can lose its caching, but not its comparison semantics. See [convergence.rs:240](.repos/typst/crates/typst-library/src/introspection/convergence.rs:240), [content/raw.rs:354](.repos/typst/crates/typst-library/src/foundations/content/raw.rs:354).

   - **Location identity must survive reruns.** Replace the current `Location(UInt64)` with 128-bit storage. Preserve root/link/split boundaries, per-key disambiguators, synthetic variants and measurement lookup. Removing memoization does not justify removing locator boundaries. Upstream uses SipHash-128 with `usize` hashed as `u64`; matching the hash algorithm alone does not reproduce Rust payload hashing. Separate stable identity correctness from any requirement for identical numeric hashes. See [locator.rs:162](.repos/typst/crates/typst-library/src/introspection/locator.rs:162), [locator.rs:263](.repos/typst/crates/typst-library/src/introspection/locator.rs:263), [hash.rs:9](.repos/typst/crates/typst-utils/src/hash.rs:9).

   - **Introspection order is conceptual, not simply DOM order.** Preserve tag ranges, duplicate-location handling and parent insertions. HTML builds its introspector before assigning anchors, then augments its anchor map; validation must see that completed map. See [introspector.rs:560](.repos/typst/crates/typst-library/src/introspection/introspector.rs:560), [document.rs:68](.repos/typst/crates/typst-html/src/document.rs:68).

   - **Output ordering is explicit.** Attributes are an ordered vector, CSS properties are sorted by name, and link IDs are assigned during DOM traversal. Preserve these structures rather than imposing blanket map sorting. See [dom.rs:377](.repos/typst/crates/typst-html/src/dom.rs:377), [css/encode.rs:31](.repos/typst/crates/typst-html/src/css/encode.rs:31), [link.rs:48](.repos/typst/crates/typst-html/src/link.rs:48).

   - **Full HTML parity crosses the proposed P3 boundary.** The goldens contain six cases with SVG output and five with embedded image data, plus bibliography cases. `html.frame` switches to `Target::Paged`, invokes `layout_frame`, then exports SVG. Plan those dependencies explicitly; a DOM-only implementation cannot complete all 508 cases. See [convert.rs:140](.repos/typst/crates/typst-html/src/convert.rs:140), [encode.rs:400](.repos/typst/crates/typst-html/src/encode.rs:400).