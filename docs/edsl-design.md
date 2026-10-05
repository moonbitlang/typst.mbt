# A MoonBit EDSL for typst.mbt (design, revision 2)

Status: revision 2, addressing the first review (15 findings). Package:
`moonbitlang/typst/doc` (imported as `@doc`).

## 0. Summary of the design

1. Authors build an immutable **description tree** of typed MoonBit values
   (`Heading(...)`, `Par(...)`, `Set(...)`, `Show(...)`). Building it needs no
   engine, world or I/O, and records the author's source locations.
2. `Document::compile` **lowers** the tree inside one explicit build
   environment, through exactly the paths the Typst evaluator uses: element
   construction via `Func::element(elem).call(engine, context, args)`, set rules
   via `elem.set(engine, args).spanned(span).liftable()`, show rules via
   `ShowableSelector::from_value` and `Recipe::new`. The EDSL never constructs
   element storage directly, so every custom constructor, cast, field parser,
   default and fold applies unchanged.
3. MoonBit closures enter the engine as a new **host-callback** function kind
   with its own identity and memo rules (section 8).
4. Provenance has three explicit tiers (section 9). Engine spans point into a
   per-compilation **origin buffer**: a real virtual source file listing every
   origin, so every span consumer keeps working.
5. Quality requirement: anything Typst can typeset, the EDSL can express, and
   the 4-page showcase rewritten in the EDSL must produce frames identical to
   its Typst twin (section 14).

## 1. Goals and non-goals

Goals: let AI agents (primary authors) and humans (reviewers) produce
high-quality documents from MoonBit with one language and one type checker;
structure that cannot be silently malformed; rendered regions that map back
to source for review comments; every output format the engine supports.

Non-goals: a new typesetter (the engine is the existing faithful port);
replacing Typst markup (it stays as the test harness and as an escape hatch);
Typst Universe packages from the EDSL (only through `Markup`).

## 2. Verified language facts

Checked with moon 0.1.20260920:

1. True constructors are `fn T::T(...) -> T`, callable as `T(...)`; function
   names must be lowercase, so each constructor needs a real type.
2. `#callsite(autofill(loc, args_loc))` works on true constructors and yields
   the whole call's range and one optional range per argument (labelled ones
   included). It does **not** give locations of expressions nested inside an
   argument (array elements, string escapes, interpolations).
3. Where the expected type is `Array[&IntoContent]`, string literals and
   element values in an array literal coerce to the trait object. Existing
   typed arrays (`Array[Heading]`) do not coerce: use `Seq(xs)`.
4. An enum case `Pt(Double)` accepts `Pt(11)` and `Pt(11.5)`; `impl Add` gives
   mixed-unit sums.

## 3. Placement

Package `doc/` in the `moonbitlang/typst` module. Its generated part
(`doc/elements_gen.mbt`) comes from a **new generator** `scripts/docgen.py`
that reads the element metadata (the same source as `elemgen.py`) and emits
author-facing argument lists; it does not reuse `viewgen.py`'s storage
access (views remain for reading content in show rules). Only the engine's
public API is used, so the package can later move to its own module.

A separate consumer package, `doc/examples/`, contains every example in this
document as compiled code, so the documented API cannot drift from the real
one.

## 4. Description tree and lowering

```moonbit
/// Anything usable where content is expected. Implemented by String
/// (literal text), every element description, Seq, Markup, Context, ...
pub(open) trait IntoContent {
  into_node(Self) -> Node            // pure; no engine access
}

/// An immutable description, lowered later.
pub(all) enum Node {
  Text(String, Origin)               // literal text, never parsed
  Call(ElemCall)                     // an element constructor call
  Seq(Array[Node])
  Styled(Array[Rule], Node, Origin)
  Labelled(Node, String, Origin)
  Space; Parbreak; Linebreak(justify~ : Bool)
  Context(HostCallback, Origin)
  Markup(String, Origin)
  Value(@library.Value, Origin)      // escape hatch for any engine value
}

pub struct ElemCall {
  elem : String                      // engine element name
  pos : Array[Arg]                   // positional, in order
  named : Array[(String, Arg)]       // only the arguments that were passed
  origin : Origin
}
```

Lowering (`doc/lower.mbt`) runs once per compilation, inside the build
environment of section 11:

- `Text(s)` lowers to Typst's string-to-content conversion (`TextElem` via
  `IntoContent for Str` in `library/cast.mbt`), **not** markup evaluation.
- `Call` builds an engine `Args` value (positional and named items, each with
  its argument span) and calls `Func::element(elem).call(engine, context, args)`
  — the path `#heading("Introduction", level: 2)` takes in the evaluator. Custom
  constructors (`text(body, ..)` styling its body, `page(..)` producing page
  breaks and a flush, `link(url)` synthesizing its body), argument casts,
  parsers with shared locals, resource loading (images, bibliographies) and
  the leftover-argument check all apply unchanged.
- `Seq` lowers to `Content::sequence` with Typst's flattening (empty sequence →
  empty content, singletons unwrapped exactly as the evaluator does).
- `Labelled(n, l)` attaches label `l` to the lowered content with the same
  rules as markup label attachment (`eval/markup.mbt`): unlabellable content
  raises the evaluator's error/warning, a sequence attaches to its last
  eligible element.
- Lowering errors carry the node's origin and are reported as diagnostics
  (section 9), never aborts.

### 4.1 Field states

Every settable field keeps the engine's full value domain and the difference
between absent, `auto`, `none` and a value:

| Author writes | Meaning | Lowered as |
|---|---|---|
| argument omitted | not set: inherit from the style chain | no named argument |
| `level=Auto` | explicitly automatic, overriding an inherited value | `Value::Auto` |
| `numbering=None` | explicitly none | `Value::None` |
| `level=Some(2)` / `numbering=Some(Numbering("1."))` | a value | the cast value |

So optional fields have type `Smart[T]?`, `T??` or `T?` exactly as the engine
field type nests them (`level? : Smart[Int]`, `numbering? : Numbering?`,
`supplement? : Smart[Supplement?]` where `Supplement` is content or a host
callback). Values are validated by the engine's casts during lowering, so
`level=Some(0)` fails with the engine's own error at the author's location.
Convenience: string adapters such as `Numbering("1.")` are true constructors
of the EDSL `Numbering` type, cast by the engine like a Typst string.

## 5. Elements (generated)

```moonbit
#callsite(autofill(loc, args_loc))
pub fn Heading::Heading(
  body : &IntoContent,
  level? : Smart[Int],
  depth? : Int,
  offset? : Int,
  numbering? : Numbering?,
  supplement? : Smart[Supplement?],
  outlined? : Bool,
  bookmarked? : Smart[Bool],
  hanging_indent? : Smart[Rel],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Heading                          // a description; pure, never raises
```

- One type and true constructor per element function. Required fields become
  positional parameters in the engine's order; variadic fields (`list(..items)`,
  `table(..children)`) take `Array[&IntoContent]` or a typed child array
  (`Array[TableChild]` with `Cell(...)`, `Header(...)`, `Hline(...)`); settable
  fields become optional labelled parameters typed per section 4.1.
- Constructors are pure and do not raise: validation happens during lowering,
  where the engine has the full context, and errors point to the call.
- Names are the Typst function names in UpperCamelCase (`Heading`, `Par`,
  `Figure`, `Table`, `Image`, `Strong`, `Emph`, `Link`, `Ref`, `Cite`,
  `Footnote`, `Raw`, `List`, `Enum`, `Grid`, `Block`, `Box`, `Align`, `Pad`,
  `Place`, `Page`, `Columns`, `Equation`, …). The generator owns a reviewed
  rename table for collisions:

  | Typst | EDSL | Reason |
  |---|---|---|
  | `align` element | `Align` | values are `Alignment::Left/Center/...` |
  | `raw` element | `Raw` | the engine-value escape hatch is `EngineValue` |
  | `list`, `box`, `ref` | `List`, `Box`, `Ref` | qualified as `@doc.List` etc. where core names collide in a scope |
  | `text` (styles its body) | `Text` | literal text is a plain `String` |

- Authors import the package and qualify (`@doc.Heading`) or bring names into
  scope with the package's `using` list in `moon.pkg`; examples in
  `doc/examples` use the latter.
- `Elem(name, positional~, named~)` is the generic escape hatch: it uses the
  same `Args` model (positional and named, with spans), so variadic and
  positional arguments are representable.

## 6. Rules: set, show, show-set

Rules form one **ordered** list, exactly like consecutive rules in a Typst
block:

```moonbit
Styled(
  [
    Set(TextStyle(size=Pt(11), lang="en")),
    Set(HeadingStyle(numbering=Some(Numbering("1.")))),
    Show(Select::heading(level=1), fn(h, cx) { Text(h, fill=accent) }),
    ShowSet(Select::figure(), [Set(TextStyle(size=Pt(9)))]),
  ],
  body,
)
```

- `Set(XStyle(...))` lowers to `elem.set(engine, args).spanned(span).liftable()`
  — the evaluator's own path (`eval/rules.mbt`), so custom set parsers,
  repeated properties and folding (relative sizes compose, strokes and insets
  fold) behave identically; realization still decides `outside`.
- `Show(selector, f)` lowers the selector through `ShowableSelector::from_value`
  (so location/before/after and nested regex selectors are rejected exactly as
  in Typst) and builds `Recipe::new(selector, Transformation::Func(callback), span)`.
- Lowering `Styled(rules, body)` applies the rules in order, right-nested as
  the evaluator nests `#set`/`#show` over the rest of a block.
- `Document(rules=[...], body=[...])` is `Styled` at the top level.

### 6.1 Show-rule callbacks

The callback receives a **view wrapping the exact engine content** the
recipe matched (with its location, prepared state and recursion guard), plus
a `Ctx`:

```moonbit
Show(Select::heading(), fn(h : HeadingView, cx : Ctx) -> &IntoContent {
  Block([h, Line(length=Pct(100))])     // h re-emits the matched element unchanged
})
```

`HeadingView` implements `IntoContent` by returning the original content, so
wrapping does not restart the rule; reading fields uses the generated views.
Constructing a *fresh* `Heading(...)` inside the callback creates a new element
that the rule may match again, exactly as in Typst. Selectors are typed
(`Select::heading(...) : Selector[HeadingView]`); heterogeneous combinations
(`Select::or(...)`) give `Selector[ContentView]`.

## 7. Context and introspection

```moonbit
Context(fn(cx : Ctx) -> &IntoContent { Text(cx.counter(Counter::page()).display(cx)) })
PageNumber()   // sugar for the above
```

- `Ctx` is valid only during the callback invocation. It is a handle with an
  invocation token; using it after the callback returns raises a clear error.
- Operations reuse the engine's contextual paths, so they register tracked
  introspection exactly like Typst: `location()`, `counter(key).get/at/final/display`,
  `state(key).get/at/final`, typed `query(Selector[V]) -> Array[V]`,
  `measure(content)` (measurement locator and inherited styles as in
  `library/measure.mbt`).
- State and counter **updates are content**, as in Typst
  (`library/state.mbt`): `StateUpdate(key, value)` and
  `CounterUpdate(key, Step | Set(n) | Update(callback))` are nodes placed in
  the document; there is no captured mutation.

## 8. Host callbacks

Show callbacks, context callbacks, numbering/supplement functions and
per-cell table callbacks are MoonBit closures. They enter the engine as a new
function kind:

```moonbit
pub(all) enum FuncInner {
  ...
  Host(HostFunc)   // a MoonBit closure supplied by the EDSL
}
```

Contract (engine changes in `library/func.mbt`, `library/value_hash.mbt`,
`library/memo.mbt`, `library/introspector.mbt`):

- **Identity**: each `HostFunc` gets a fresh identity when its description is
  lowered (one per callback occurrence per compilation); equality is identity.
  Callbacks are never interned by source location.
- **Fingerprint**: hashes the origin and identity and sets
  `fingerprint_identity` (as `Closure` does), so memo entries, frame
  cacheability (`frame_cacheable`) and recorded introspection reads treat
  results that contain host callbacks as identity-bearing: never reused across
  invocations where a fresh callback would have been created, and never
  compared by fingerprint alone in convergence validation.
- **Creation during layout**: phase 1 allows host callbacks only in the
  description tree (created before lowering). A callback that returns content
  containing new host callbacks is rejected with a diagnostic until
  layout-time creation has its own identity scheme (phase 2).
- **Purity contract**: callbacks may run any number of times, including zero
  (memo reuse); results must depend only on their arguments and the `Ctx`.
  Mutating captured state or engine values, or reading external resources, is
  unsupported. The same contract covers custom `IntoContent` implementations.
- **Determinism check** (debug heuristic): with a frozen world (fonts,
  resources, date), compile twice with memoization off and compare normalized
  frames, diagnostics and introspection observations; report the origins of
  callbacks invoked on differing paths as candidates. It cannot prove purity.

## 9. Provenance

Three tiers, each with an explicit guarantee:

1. **Call provenance (always exact)**: every description node records its
   constructor call's `SourceLoc` and its argument ranges (`ArgsLoc`).
2. **Runtime text provenance (exact)**: for text produced by a node, the byte
   range within the node's runtime string (glyph spans plus offsets); for
   data-driven content, an optional `key` (`Par(..., key="row-17")`).
3. **Source-character provenance (best effort, needs a source provider)**:
   mapping a runtime offset to a character in the `.mbt` file. Available only
   when a source provider supplies the file (preview tooling reads it) and the
   argument is a single plain string literal; escapes, interpolation,
   concatenation and variables report tier 2 only. Ligatures and clusters map
   to the cluster's range. Plain strings inside an array share the array
   argument's range; `T("...")` (a located text constructor) gives an entry its
   own range when needed.

### 9.1 Engine spans: the origin buffer

Each compilation creates **one** virtual source file, `edsl-origins`, whose
text is a listing of origins, one line per node:

```
report.mbt:42:5-42:31 Par args=[42:9-42:30]
report.mbt:43:5-43:61 Figure args=[43:12-43:30, 43:40-43:60]
```

- Node spans are range spans into this buffer (the node's line). Diagnostics,
  hints, traces and `world_range` therefore see real byte ranges in a real
  file; the CLI's renderer shows the origin line, and the EDSL's own renderer
  translates it to `report.mbt:42:5`.
- The buffer is built before lowering and is stable across layout iterations.
  Limits are checked: range endpoints are 23-bit (8 MiB of origin text, about
  100k nodes), and one file id is used per compilation (file ids are interned
  16-bit; the EDSL reuses the same id across compilations of a document by
  path). On overflow, lowering reports an error instead of saturating.
- Text inside a node keeps the engine's own glyph offsets into the runtime
  string; offsets above 65,535 (the glyph span offset width) report tier 1
  only.
- The origin table is retained with the compiled document
  (`CompiledDocument.origins`) for previews and review packaging.

### 9.2 Resource paths

Origins are diagnostic only. Resource paths (`Image("chart.png")`,
bibliography and CSL files, raw syntax/theme files, `Markup` imports, SVG
dependencies) resolve against the document's **resource root** (the
`DocWorld` root, defaulting to the working directory): during lowering they
are turned into `RootedPath` values before construction, so the synthetic
origin file never acts as a base path. `Bytes` sources are accepted
everywhere a path is (`Image(Bytes(data), format=Png)`).

## 10. Escape hatches

- `Markup(source, scope?=[("name", value)])`: evaluated by the existing front
  end with `eval_string_mapped`-style range spans into a per-markup virtual
  file, the document's resource root as import base, and an explicit scope
  (EDSL values injected by name). Errors map to positions inside the string.
- `Equation(math : String, block?=false, numbering?=..., scope?=[...])`:
  evaluated in math mode; math mode returns an equation element, which the
  EDSL configures (block, numbering) instead of wrapping it again.
- `EngineValue(value)`: any engine value.

## 11. Compiling and exporting

Engine change: split `compile_impl` (`typst/lib.mbt`) into evaluation and a
`compile_content` that keeps every responsibility of the current loop:
target feature checks (HTML/bundle gates), library and target styles, fresh
memo lifetime, tracked introspection, convergence warnings and delayed-error
promotion. HTML and bundles compile through their own targets.

```moonbit
let world = DocWorld(root=".", fonts=[EmbeddedFonts, SystemFonts], date=Some(fixed))
let result = doc.compile_paged(world) // Warned[Result[PagedDocument, Array[Diagnostic]]]
let pdf : Bytes = result.to_pdf(standards=[PdfA2b], tagged=true)
doc.write_pdf(world, "out.pdf")       // convenience; returns warnings, raises on errors
doc.write_png(world, "out-{p}.png", ppi=144)
doc.compile_html(world).write("out.html")
```

`DocWorld` is a new public world in the `doc` package built from `kit`
components (the CLI's `SystemWorld` stays private): library with explicit
features and formats, a virtual main id, file access under the resource root,
font discovery (embedded, system, extra paths), a frozen or system date, and a
resource snapshot for one compilation. `DocWorld::in_memory(files, fonts)`
serves tests and the browser. Document-level settings (`DocumentStyle`
metadata, PDF standards from `Set`) and explicit export options follow
Typst's precedence (explicit options win).

## 12. Feature matrix

| Area | Phase | Design |
|---|---|---|
| Page and document setup | 1 | `PageStyle(paper=…, margin=…, header=Context(…), footer=…, numbering=…, columns=…)`, `DocumentStyle(title=…, author=…, keywords=…)` |
| Typography | 1 | `TextStyle` (fonts with fallback, features, kerning, ligatures, hyphenation, lang/region, weight/style/stretch), `ParStyle` (justify, leading, spacing, first-line indent) |
| Headings, outline, numbering | 1 | generated; `Numbering(pattern)` or host callback |
| Figures, images | 1 | `Figure`, `Image(path or Bytes, format, alt, page)`; PDF/SVG/raster |
| Lists, quotes, links, footnotes | 1 | generated |
| Tables and grids | 1 | `Table(columns=…, children=[Header(…), Cell(…, colspan=2), Hline(…), …])`, strokes/fills as values or per-cell host callbacks |
| Math | 1 | `Equation(math_string, block, numbering, scope)` |
| Code | 1 | `Raw(text, lang=…, block=…)` |
| Labels and references | 1 | `label=` attachment (section 4), `Ref`, `Cite` |
| Bibliography | 2 | `Bibliography(sources=[path or Bytes], style=Csl(...))`, citation groups |
| Counters, state, query, measure | 2 | section 7 |
| Shapes, gradients, tilings, curves | 2 | generated, values as typed constructors |
| HTML and bundle targets | 3 | target-specific elements and options |
| Layout-time callback creation | 3 | section 8 |

## 13. Equivalence: what "the same as Typst" means

Each EDSL construct is specified against a **functional Typst expression**,
not markup prose:

| EDSL | Typst twin |
|---|---|
| `Heading("Introduction", level=Some(2))` | `#heading("Introduction", level: 2)` |
| `"some text"` | `#"some text"` (string-to-content), not markup prose |
| `Seq([a, Space, b])` | `#(a + [ ] + b)` with an explicit space element |
| `Par([...])` | `#par[...]` (explicit paragraph), not prose that realization groups |
| `Styled([Set(TextStyle(size=Pt(11)))], body)` | `#[#set text(size: 11pt); #body]` |
| `Labelled(Figure(...), "fig:1")` / `label="fig:1"` | `#figure(...) <fig:1>` |

## 14. Testing and the quality milestone

1. **Twin tests**: each construct and each generated element has an EDSL
   document and a functional-Typst twin; both are compiled and their paged
   frames compared for identity (spans excluded), plus PDF semantic dumps.
2. **Coverage test**: enumerate every engine element and settable field and
   fail if the generator emitted no constructor/argument for it.
3. **Showcase milestone**: the 4-page showcase (gradients, math, tables, JPEG/
   SVG/PDF images, code, Arabic and Chinese, citations, headers/footers)
   rewritten in the EDSL must produce frames identical to the Typst version.
   More upstream test documents get EDSL twins over time.
4. **Rules**: tests for set-rule folding and order, show identity/wrapping/
   fresh-element recursion, regex revocation, invalid selectors, show-set.
5. **Callbacks**: identity, memo/cacheability with captures, rejection of
   layout-time creation, stale `Ctx` use.
6. **Provenance**: a glyph maps to its node's origin (tier 1) and runtime
   offset (tier 2); a source-provider test for tier 3; overflow handling.
7. **Examples**: `doc/examples` compiles every documented example.
8. Targets: native, wasm-gc, wasm.

## 15. Phases

1. Engine: `compile_content` split, `FuncInner::Host` with identity and memo
   rules. EDSL: description tree, lowering through element functions and
   `Element::set`, hand-written core (section 12 phase 1 rows), units, colours,
   rules, show views, `DocWorld`, PDF/SVG/PNG output, origin buffer
   diagnostics. Milestone: the showcase twin is frame-identical.
2. Generator for all elements and fields (coverage test green), context and
   introspection, bibliography, graphics.
3. Preview provenance (data attributes, `jump_from_click` port, review-comment
   packaging), HTML/bundle targets, layout-time callbacks.

## 16. Open questions

1. Whether `Ctx` should be passed to every callback or only to context
   callbacks (show callbacks may not have a location).
2. Whether to expose `Node` publicly (for agents that generate documents as
   data) or keep it opaque behind the constructors.
3. How much of the rename table to apply versus requiring qualification.
