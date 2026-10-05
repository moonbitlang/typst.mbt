# A MoonBit EDSL for typst.mbt (design, revision 3)

Status: revision 3. It resolves every PARTIAL item and the new issues N1–N5 of
`docs/edsl-reviews/review-2.md`; section 19 maps each finding to the section
that resolves it. Packages: `moonbitlang/typst/doc` (imported as `@doc`),
`doc/system`, `doc/examples`, `doc/twins`.

## 0. Summary of the design

1. Authors build **opaque, immutable description values** with typed MoonBit
   constructors (`Heading(...)`, `Par(...)`, `SetText(...)`, `Show(...)`).
   Building them needs no engine, world or I/O, and records the author's
   call-site locations.
2. `Document::compile_paged(world)` **lowers** descriptions inside one
   compilation *session*. Lowering produces every engine value through
   Typst's public functions, exactly as the evaluator does:
   `Func::call(engine, context, args)` for element and native functions,
   `Element::set(engine, args).spanned(span).liftable()` for set rules,
   `ShowableSelector::from_value` + `Recipe::new` + the evaluator's recipe
   checks for show rules. A short, audited list (section 5.3) covers the
   constructs that have no public function.
3. Descriptions created by callbacks during layout are lowered by the same
   code with the invocation's engine and context (section 5.2).
4. MoonBit closures enter the engine as a new **host function** kind with its
   own identity, fingerprint, memo and convergence rules (section 11).
5. Provenance is an **append-only origin registry** per session, exposed to
   the engine as a real virtual source file so that every span consumer keeps
   working, and returned with every report, on success and on failure
   (sections 12 and 14).
6. Quality requirement: anything Typst can typeset, the EDSL can express
   (generated constructors plus escape hatches), and each construct is
   specified against a functional Typst twin under a defined normalizer
   (section 16).

## 1. Goals and non-goals

Goals: let AI agents (primary authors) and humans (reviewers) produce
high-quality documents from MoonBit with one language and one type checker;
structure that cannot be silently malformed; rendered regions that map back
to source for review comments; every output format the engine supports.

Non-goals: a new typesetter (the engine is the existing faithful port);
replacing Typst markup (it stays as the test harness and as an escape hatch);
structured math (math stays a Typst math string); Typst Universe packages
from the EDSL (only through `Markup`).

## 2. Verified language facts

Checked with moon 0.1.20260920 / moonc v0.10.14 in scratch packages (a
library package and a consumer package). Facts 5–9 are new in this revision
and decide API questions below.

1. True constructors are `fn T::T(...) -> T`, callable as `T(...)`; function
   names must be lowercase, so each constructor needs a real type.
2. `#callsite(autofill(loc, args_loc))` works on true constructors (and on
   methods). `loc` is the call's range; `args_loc` holds one optional range
   **per declared parameter, in declaration order** (labelled ones included,
   `None` for omitted ones). Ranges of expressions nested inside an argument
   (array elements, interpolations) are not available. `SourceLoc` prints as
   `file:line:col-line:col@module`.
3. Where the expected type is `Array[&IntoContent]`, string literals and
   description values in an array literal coerce to the trait object. A
   parameter of type `&IntoContent` accepts one string or one description
   value, but **not** a heterogeneous array literal (`["a", h]` is inferred
   as `Array[String]` and fails).
4. Enum cases taking `Double` accept integer literals (`Pt(11)`); `impl Add`
   gives sums within one enum.
5. Enum constructors of another package resolve **without qualification only
   when the expected type is that concrete enum** (`size=Pt(11)` with
   `size? : Length`). With a trait-object or generic parameter the same call
   fails with `The value identifier Pt is unbound`. This rules out
   `IntoSmart`-style adapter parameters (section 6.2).
6. `f(a, b) <| (x, y) => { ... }` passes the callback as the last positional
   argument, also for generic constructors (`Show[V]`) and inside a labelled
   argument (`fill=Cells() <| (x, y) => { ... }`). Arrow callbacks take their
   effect from the expected type, so a callback parameter declared
   `(V, Ctx) -> &IntoContent raise` may call raising operations and raise any
   error.
7. In a callback whose result type is `&IntoContent`, the *tail expression*
   and `return` coerce a description value to the trait object, but the
   branches of an `if`/`match` are unified first: `if c { Seq([...]) } else
   { it }` fails when the branch types differ. Authors use `return` or the
   type eraser `Content(x)` (section 4.2).
8. A type named `Show` shadows the prelude trait `Show` in every package
   that brings it into scope (`derive(Show)` then fails with `The type Show
   is not a trait`); the trait stays reachable as `@builtin.Show`. Likewise
   `Ref` shadows the prelude type, reachable as `@ref.Ref`.
9. Names come into scope with a `using` declaration, e.g.
   `using @doc { type Heading, type Par, type Seq }`; anything can be
   qualified instead (`@doc.Heading(...)`).

## 3. Packages

| Package | Contents | Depends on |
|---|---|---|
| `doc` | description values, generated constructors, lowering, sessions, reports, `DocWorld::in_memory`, export to bytes/strings | `syntax`, `library`, `eval`, `typst`, `layout`, `pdf`, `svg`, `render`, `typst_assets/fonts` |
| `doc/system` | `@system.world(root=...)` (files under a root, embedded/system/extra fonts, packages, date) and file writing | `doc`, `kit`, `kit/platform` |
| `doc/examples` | every example of this document as compiled code | `doc`, `doc/system` |
| `doc/twins` | the twin corpus of section 16: EDSL builders with their Typst sources | `doc` |

- `doc` performs no OS access, so it also serves wasm-gc in a browser; OS
  access is confined to `doc/system`.
- Only public APIs of the engine packages are used, so the packages can move
  to their own module later. The engine additions this design needs are
  listed in section 18 (phase 1).
- `doc/elements_gen.mbt` is produced by a **new generator**
  `scripts/docgen.py` (section 7). It reads `gen/manifest.json` (the source of
  `elemgen.py`) and a reviewed specification file; it does not reuse
  `viewgen.py`'s storage access.

## 4. Description values

### 4.1 Representation

```moonbit
/// Anything usable where content is expected: String (literal text), every
/// description type, show-rule views, user types.
pub(open) trait IntoContent {
  into_content(Self) -> Content       // pure; no engine access
}

/// An opaque, immutable description. Its representation is private.
pub struct Content { priv node : Node }
```

`Node` is a private enum (literal text, element call, sequence, rule,
labelled, keyed, context, markup, engine value, space, engine content). There
is **no public node type and no public mutable field** (N4):

- every constructor converts its inputs on entry: `&IntoContent` arguments
  through `into_content()`, arrays by copying the converted elements into a
  private array, values into a private value description (section 6). A
  caller mutating an array after the call does not affect the description.
- a description can only contain descriptions that existed before it, so
  cycles cannot be built.
- user implementations of `IntoContent` run once, when the value is passed to
  a constructor; they are covered by the purity contract of section 11.5.

### 4.2 Structural constructors

```moonbit
pub fn Seq::Seq(children : Array[&IntoContent], loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Seq
pub fn[T : IntoContent] Seq::of(items : Array[T]) -> Seq      // existing typed arrays
pub fn Lit::Lit(text : String, loc~ : SourceLoc) -> Lit       // text with its own location
pub fn Labelled::Labelled(body : &IntoContent, label : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Labelled
pub fn Keyed::Keyed(key : String, body : &IntoContent) -> Keyed
pub fn Content::Content(body : &IntoContent) -> Content      // type eraser
pub fn Space::Space() -> Space
```

(`#callsite(autofill(...))` is on every constructor that has `loc~`; it is
omitted in the listings.) `Parbreak()`, `Linebreak(justify?)` and
`Pagebreak(...)` are ordinary generated element constructors.

Parameter shapes mirror the Typst signature: a content parameter is one
`&IntoContent`; a variadic parameter is an `Array[&IntoContent]`. Several
pieces of content are joined explicitly:

```moonbit
Par(Seq(["Typeset with ", Emph("care"), "."]))
```

- **`Seq(children)`** lowers each child (section 5) and builds
  `Content::sequence(lowered)`. Nesting is **preserved**: a child that is a
  sequence stays one child; zero children give empty content and one child
  is returned as is. Its functional twin is the Typst content block
  `[#a#b#c]` (`eval_markup_exprs`, `eval/markup.mbt`): one inserted
  expression result per child, joined by `Content::sequence`. It is *not*
  `a + b + c` (`Content::add` concatenates sequences).
- A **rule** (`SetText(...)`, `Show(...)`, `ShowSet(...)`) among the children
  styles the children after it, exactly as a rule inside a Typst block
  (section 8).
- A plain **`String`** is literal text, never parsed: it lowers to
  `Value::Str(s).display()` — the `TextElem` that Typst's string-to-content
  conversion creates — spanned with its origin. Twin: `#"s"` inside a content
  block. `Lit(s)` is the same with a location of its own (a `String` inside
  an array shares the array argument's location, fact 2).
- **`Labelled(body, label)`** is the twin of `[#body<label>]`: `body` is
  lowered as **one inserted expression result** and the label is attached to
  that result as a whole, whether it is an element, a styled wrapper or a
  sequence (the upstream test `label-text-styled-and-sequence` checks the label on
  the sequence itself). The label value comes from Typst's `label(name)` function
  (`native_label_construct`), so an empty name fails with `label name must
  not be empty` at the label argument. If the result is `Unlabellable`, the
  evaluator's warning ``label `<x>` is not attached to anything`` is emitted
  and the content is returned unchanged; if it already carries a label, the
  warning `content labelled multiple times` (with its hint) is emitted and
  the new label replaces the old one. Every generated element constructor
  also takes `label? : String`, which is exactly `Labelled(elem, label)`.
- **`Keyed(key, body)`** attaches a runtime occurrence key to the origins of
  everything lowered inside `body` (section 12.2). It does not change the
  lowered content.
- **`Space()`** is markup's space element (`SpaceElem::shared()`), for
  authors who need Typst's collapsing space rather than a `" "` text.

## 5. Lowering

### 5.1 Initial lowering

`compile_*` creates a *session* (origin registry, host-function table, markup
snippet table) and lowers the document once, before layout, in the
evaluator's environment (`eval_source`, `eval/lib.mbt`): an `Engine` with the
world, the library, `Introspector::empty()`, the compilation's sink and
traced span and `Route::root()`, and **`Context::none()`**. Contextual
functions therefore fail during initial lowering with Typst's `can only be
used when context is known`, as they do at the top level of a Typst file.

Lowering stops at the first error, like evaluation; the error is a
diagnostic at the node's origin (section 12), not an abort.

### 5.2 Callback-result lowering

A show, context, numbering or cell callback returns description values that
did not exist before (`Block(Seq([it, Line(length=Pct(100))]))`). The host
function that wraps the callback (section 11) lowers the result with the
same code, using

- the **engine and context of that invocation** (the context the engine
  passes to the function: location and styles for `context`, styles and the
  matched element's location for show rules, the display site's context for
  numberings, styles for cell callbacks), and
- the **session** captured by the host function, so origins of callback-made
  nodes are registered lazily in the same append-only registry (section
  12.2), and the report owns them.

Errors raised by the callback or by lowering its result propagate as the
function call's error; realization delays them like any show-rule error.

### 5.3 What lowering calls

| Description | Lowering | Path in the evaluator |
|---|---|---|
| element constructor `Heading(...)`, `Call("table.cell", ...)` | build `Args` (positional and named items with their argument spans), `func = Func::element(elem).spanned(span)`, call `func.call(engine, context, args)` inside `trace(.., Call(func.name()), span, ..)`, then `.spanned(span)` | `call_func` (`eval/call.mbt`), `eval_expr`'s final `value.spanned(span)` (`eval/code.mbt`) |
| value functions (`rgb`, `stroke`, `label`, `counter`, `numbering`, selectors' `where`/`or`, ...) | the native function (`native_color_rgb()` ...) called the same way | same |
| `SetText(...)` | `elem.set(engine, args.spanned(span)).spanned(span).liftable()` | `eval_set_rule` (`eval/rules.mbt`) |
| `Show`, `ShowSet` | section 8 | `eval_show_rule` |
| `Markup`, `Equation` | section 13 | `eval_string` with mapped spans |

Element construction therefore runs custom constructors (`text` styling its
body, `page` producing page breaks and a flush), argument casts, parse hooks
with shared locals, resource loading and the leftover-argument check
(`args.finish()`) unchanged.

**Span attachment and tracing** (finding 5). `Func::call` does not span its
result, so lowering does what the evaluator does around it:

- `Args.span` and the function span are the node's span; each `Arg` has
  `span` and `value.span` set to its argument's span (the autoloc range of
  that argument). Cast errors therefore point at the argument.
- the call runs inside `@library.trace(world_range, Call(name), span, ..)`,
  so errors from nested calls get the same call trace points as in Typst.
- the result is `value.display().spanned(span)`: content without a span gets
  the node's span, as `eval_expr` and `eval_markup_exprs` do.
- a `String` in content position is lowered by the EDSL itself to a spanned
  `TextElem` and passed as a content value, so its glyphs carry the origin
  (in Typst, `#heading("x")` leaves the text detached; this differs only in
  spans, which the normalizer of section 16 erases).

**Audited exceptions** (N2): constructs for which Typst has no public
function. Each uses the storage path of the evaluator; nothing else may
build element storage directly, and a test enumerates `Content::new` /
`from_fields` uses in `doc` against this list.

| Construct | Lowering | Evaluator counterpart |
|---|---|---|
| `Context() <| f` | `Content::new(context_elem(), [(context_elem_func, Func(host))]).spanned(span)` | `eval_contextual` (the element function reports `cannot be constructed manually`) |
| `Seq` | `Content::sequence` | `eval_markup_exprs` |
| rules inside a sequence | `tail.styled_with_map(styles)`, `tail.styled(Recipe(recipe))` | `eval_markup_exprs`, `styled_with_recipe` |
| `Labelled` | `Content::labelled` with the warnings above | label attachment in `eval_markup_exprs` |
| `String`, `Lit` | `Value::Str(s).display()` | markup text / `Value::display` |
| `Space()` | `SpaceElem::shared()` | `space_content` |
| view re-emission (section 9) | the matched engine content itself | the `it` argument of a show rule |
| `Equation(source)` | body of the evaluator's math-mode result (section 13) | `eval_root` |

Counter and state **updates are not exceptions**: `counter(key).step()`,
`counter(key).update(..)` and `state(key, init).update(..)` are public
functions returning content, and are called as functions.

## 6. Values

### 6.1 Field states

Every settable field keeps the engine's full value domain and the difference
between absent, `auto`, `none` and a value. The EDSL type nests exactly as
the engine type does:

| Engine type | Parameter | Author writes | Lowered |
|---|---|---|---|
| any | `x? : T` omitted | nothing | no named argument (inherit) |
| `Smart<T>` | `x? : Smart[T]` | `level=Auto`, `level=Custom(2)` | `Value::Auto` / value |
| `Option<T>` | `x? : T?` | `numbering=None`, `numbering=Some(Numbering("1."))` | `Value::None` / value |
| `Smart<Option<T>>` | `x? : Smart[T?]` | `supplement=Custom(None)` | nested |
| `T` | `x? : T` | `depth=2` | value |

`Smart` is the engine's `@library.Smart[T]` (`Auto | Custom(T)`); by fact 5
authors write `Auto` and `Custom(v)` without importing it. Values are
validated by the engine's casts during lowering, so `level=Custom(0)` fails
with the engine's own message at the `level` argument.

### 6.2 The `Smart` facade decision

`level=2` through an adapter (`level? : &SmartInt`, or a generic parameter)
was rejected on evidence: by fact 5 a trait-object or generic parameter
breaks unqualified unit and enum constructors (`width=Pct(80)` no longer
resolves), which is a settled decision, and it hides the three states from
the signature. `Custom(v)` keeps signatures honest (the type shows that
`auto` is legal), is uniform (one rule: `Smart` is `Auto`/`Custom`, `Option`
is `None`/`Some`), and a missing wrapper is a precise type error (`expected
Smart[Length], has type Length`).

Integers are `Int64` wherever the engine stores `i64`, `usize` or
`NonZeroUsize` (literals need no suffix; range and non-zero checks are the
engine casts'). `Double` is used for `f64` and `Ratio`-free scalars.

### 6.3 Units

```moonbit
/// Lengths and ratios: everything Typst writes as `11pt`, `2em`, `50%` and
/// their sums. One type for the engine's `Length`, `Rel<Length>`, `Ratio`.
pub(all) enum Length {
  Pt(Double); Mm(Double); Cm(Double); In(Double)    // absolute
  Em(Double)                                        // font-relative
  Pct(Double)                                       // ratio: Pct(50) is 50%
  Sum(Length, Length); Diff(Length, Length)         // from `+`, `-`
  Neg(Length)                                       // from unary `-`
  Scaled(Length, Double)                            // from `.scale(k)`
}
pub impl Add for Length; pub impl Sub for Length; pub impl Neg for Length
pub fn Length::scale(self : Length, factor : Double) -> Length

/// The engine's `Spacing`: a length/ratio or a fraction.
pub(all) enum Spacing {
  Fr(Double)
  Pt(Double); Mm(Double); Cm(Double); In(Double); Em(Double); Pct(Double)
  Rel(Length)                                       // any composed length
}
/// The engine's `Sizing` and track sizes: additionally `auto`.
pub(all) enum Sizing {
  Auto
  Fr(Double)
  Pt(Double); Mm(Double); Cm(Double); In(Double); Em(Double); Pct(Double)
  Rel(Length)
}
pub(all) enum Angle { Deg(Double); Rad(Double) }
```

- **`Fr` and `Angle` are not lengths**: `Fr` exists only as a case of
  `Spacing` and `Sizing`, so `Pt(1) + Fr(1)` does not type-check; MoonBit's
  `Add` is homogeneous, so mixed-unit sums exist only inside `Length`.
- **Promotion** is Typst's own. A `Length` tree is lowered bottom-up with
  the engine's value operators in source order: leaves are `Pt(x)` →
  `Value::Length(Abs::pt(x))` (likewise `mm`, `cm`, `in`), `Em(x)` → an em
  length, `Pct(x)` → `Value::Ratio(x / 100)`; `Sum(a, b)` is
  `@library.add(lower(a), lower(b))`, `Diff` is `sub`, `Neg` is `neg`,
  `Scaled(a, k)` is `mul(lower(a), Float(k))`. So `Pt(11) + Em(0.5)` is a
  length, `Pt(1) + Pct(50)` a relative length and `Pct(50)` a ratio, with
  the floating-point evaluation order of the Typst expression
  `11pt + 0.5em`.
- **Legal conversions** are the field's engine cast: a `Pct` in a field of
  engine type `Length` fails with the engine's cast message at that
  argument. The unit shorthands of `Spacing`/`Sizing` (`Pt(40)`) lower like
  `Rel(Pt(40))`; `Fr(x)` lowers to `Value::Fraction`.
- Track lists (`TrackSizings`) are `Array[Sizing]`:
  `columns=[Auto, Fr(1), Pt(40)]`.

### 6.4 Other value facades

All are immutable and lowered through Typst's public functions or values.

| Engine type | EDSL | Example |
|---|---|---|
| `Paint`, `Color` | `enum Paint { Rgb(String); Luma(Int); Black; White; Red; ...; Value(Value) }` (Typst's named colours, lowered to the global bindings `black`, `red`, ...) | `fill=Rgb("#1f4e79")` → `rgb("#1f4e79")` |
| `Stroke` | `Stroke(paint?, thickness?, cap?, join?, dash?, miter_limit?)` → `stroke(...)` | `Stroke(thickness=Pt(0.5), paint=Luma(220))` |
| `Sides<T>`, `Margin<T>` | `Sides(all?, x?, y?, left?, top?, right?, bottom?)`; `all` lowers to the bare value, the others to the dictionary; combining `all` with a side is a lowering error | `inset=Sides(all=Some(Pt(9)))` |
| `Corners<T>` | `Corners(all?, top?, ..., top_left?, ...)`, same rule | |
| `Alignment` | `enum Alignment { Left; Center; Right; Start; End; Top; Horizon; Bottom; Both(Alignment, Alignment) }` with `impl Add` | `Center + Horizon` |
| `Numbering` | `Numbering(pattern)`; `Numbering::with() <| (numbers, cx) => { ... }` | `Some(Numbering("1.1"))` |
| `Supplement` | `Supplement(content)`; `Supplement::with() <| (it, cx) => { ... }` | |
| `Celled<T>` | `Cells::all(v)`, `Cells::columns([..])`, `Cells() <| (x, y) => { ... }` | section 7.3 |
| `DataSource` | `Source::path(String)`, `Source::bytes(Bytes)`; path parameters also accept a plain `String` via the generated signature | `Image("chart.png")` |
| string enums (`FontWeight`, `Dir`, ...) | generated enums from the cast table of the manifest | `weight=Bold` |
| anything else | `Value` (section 13) | `Value::call("gradient.linear", ...)` |

`pub trait ToValue { to_value(Self) -> Value }` (sealed) is implemented by
all of these, by `Bool`, `Int`, `Int64`, `Double`, `String`, `Smart[T]`,
`T?`, `Array[T]`, `Content` and `Value`; it is the bound of generic
facades such as `Cells[T]` and `Sides[T]`.

## 7. Elements (generated)

### 7.1 Signature rule

```moonbit
#callsite(autofill(loc, args_loc))
pub fn Heading::Heading(
  body : &IntoContent,
  level? : Smart[Int64],
  depth? : Int64,
  offset? : Int64,
  numbering? : Numbering?,
  supplement? : Smart[Supplement?],
  outlined? : Bool,
  bookmarked? : Smart[Bool],
  hanging_indent? : Smart[Length],
  label? : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Heading                          // a description; pure, never raises
```

- One type and true constructor per **public element function**: the
  generator walks the library's scope tree (the global scope, the scopes of
  functions and types, and the `math`, `html`, `pdf` modules), not the list
  of element structs. Elements without a public function (`context`,
  `sequence`, `styled`, `space`, tags, counter/state update and display
  elements, ...) get no constructor; they are the audited list of section
  5.3 or products of public functions.
- **Names** are the qualified Typst path in UpperCamelCase: `heading` →
  `Heading`, `table.cell` → `TableCell`, `grid.cell` → `GridCell`,
  `table.header` → `TableHeader`, `enum.item` → `EnumItem`, `math.frac` →
  `MathFrac`. Names are therefore unique although element names are not
  (`cell`, `header`, `footer`, `hline`, `vline`, `item`, `line`, ... occur
  several times). A description stores the **`@library.Element` handle**
  (`@library.heading_elem()`, `@library.table_cell_elem()`), never a name
  (N3).
- Required parameters are positional in the engine's order; variadic ones
  are an array; settable ones are optional labelled parameters typed per
  section 6; `label? : String` comes last before the autofilled locations;
  a callback parameter, if any, is the last positional one.
- Constructors are pure and do not raise: validation happens during
  lowering, where errors point to the call or the argument.
- Field types the type table does not cover yet are **left out of the typed
  constructor and listed in the generated coverage report**; they stay
  reachable through `Call`/`Set` (section 13). Phase 2 ends when that list is
  empty.
- **Reserved parameter names**: `label`, `loc`, `args_loc`. The generator
  fails if an element has a constructor parameter with one of these names
  (none does today; `cite.key` is why the occurrence key is the wrapper
  `Keyed`, not a parameter).

### 7.2 Constructor-signature overrides

Storage metadata is not the constructor signature (finding 1): `link.body`
is "required" but its parser lets a URL destination omit it; `text` has an
external `body` and a stored `text`; `block.body` is an optional positional.
The specification file therefore carries a **reviewed override per element
whose construction is not the plain field list**: every element with a
`construct` hook, a `parse` hook on any field, an external field, or an
optional positional field. The generator refuses to emit such an element
without an entry. Each entry states the EDSL parameters, their mapping to
positional/named arguments and its functional twin. Phase-1 entries:

| Element | EDSL signature | Notes |
|---|---|---|
| `text` | `Text(body, font?, size?, fill?, weight?, ...)` | settable fields only; no `text` parameter; `size`/`fill`/`font` are passed named |
| `link` | `Link(dest : LinkTarget, body? : &IntoContent)` | `body` omitted → no second positional argument (the parser synthesizes it for URLs) |
| `page` | `Page(body, paper?, width?, ...)` | `paper` is external and resolved by the parser |
| `block`, `box`, `rect`, ... | `Block(body, ...)`; `Block::empty(...)` for no body | optional positional body |
| `align`, `place`, `rotate`, `scale`, `move`, `pad` | `Align(alignment, body)` etc. | optional positional settable first, as in Typst |
| `image` | `Image(source : &IntoSource, ...)` | `String` (path) or `Bytes` |
| `raw` | `Raw(text : String, block?, lang?, ...)` | text is a string, not content |
| `figure` | `Figure(body, caption? : &IntoContent?, ...)` | caption content is wrapped by the engine's cast |
| `equation` | `Equation(source : String, block?, numbering?, ..., scope?)` | section 13 |
| `table`, `grid` | `Table(children, columns?, ..., gutter?)` | external `gutter`, parse hooks |
| `v`, `h` | `V(amount : Spacing, weak?)` | internal `attach` not exposed |

`LinkTarget` and `IntoSource` are small facades (`Url(String)`,
`ToLabel(String)`, ...; `String` and `Bytes`).

### 7.3 Example

```moonbit
Figure(
  Table(
    [
      TableHeader([Strong("Stage"), Strong("Tests")]),
      "syntax", "3 792",
      "paged", TableCell("2 299", colspan=1),
    ],
    columns=[Auto, Fr(1)],
    align=Cells::columns([Custom(Left), Custom(Right)]),
    fill=Cells() <| (_, y) => { if y > 0 && y % 2 == 1 { Some(Luma(247)) } else { None } },
  ),
  caption=Some("Differential test stages."),
  label="stages",
)
```

## 8. Rules: set, show, show-set

```moonbit
Document([
  SetPage(paper="a4", margin=Custom(Sides(x=Custom(Cm(2.2)), top=Custom(Cm(2.6))))),
  SetText(font=["Libertinus Serif"], size=Pt(11), lang="en"),
  SetHeading(numbering=Some(Numbering("1.1"))),
  Show(Select::heading(level=1)) <| (it, _) => {
    Seq([V(Em(0.6)), Block(Text(it, fill=Rgb("#1f4e79"))), V(Em(0.2))])
  },
  ShowSet(Select::figure(), SetText(size=Pt(9))),
  Heading("Text and paragraphs"),
  Par("..."),
])
```

- A rule is a description like any other and appears **in a sequence**
  (`Document`, `Seq`, a variadic children array). It styles the children
  after it in that sequence and nothing outside it, exactly as `#set`/`#show`
  inside a Typst content block: lowering a sequence follows
  `eval_markup_exprs` — on a set rule, the remaining children are lowered as
  the tail and pushed as `tail.styled_with_map(styles)`; on a show rule, as
  `tail.styled(Recipe(recipe))`. A rule in a single-content position
  (`Par(SetText(...))`) is the sequence containing only that rule.
- **`SetX(...)`** (one generated type per element with settable fields; all
  parameters optional, no `label`) lowers to
  `elem.set(engine, args.spanned(span)).spanned(span).liftable()`. Custom
  set parsers, repeated properties and folding (relative sizes compose,
  strokes and insets fold) behave identically; realization still decides
  `outside`.
- **`Show(selector) <| (it, cx) => { ... }`**: the selector description
  (section 9) is lowered to a value and cast with
  `ShowableSelector::from_value` under `at(selector_span, ..)`, so
  location/before/after selectors and nested regex selectors are rejected
  with Typst's messages. The recipe is
  `Recipe::new(Some(selector), Func(host), span)`.
- **`ShowSet(selector, rule : &SetRule)`** (finding 10) takes exactly one
  set rule, like `show sel: set f(..)`. It lowers the selector as above, the
  rule as a set rule (`Styles`, spanned and liftable as above), and builds
  `Recipe::new(Some(selector), Style(styles), span)`. Several show-set rules
  are several `ShowSet` values, in order. `SetRule` is the sealed trait of
  the `SetX` types.
- **Recipe checks**: after building a recipe, lowering runs the evaluator's
  `check_show_page_rule` and `check_show_par_set_block`, which become one
  public function `@eval.check_recipe(engine, recipe)` (engine change; the
  evaluator calls the same function). `Show(Select::page())` thus warns
  `` `show page` is not supported and has no effect``.
- A show rule without a selector (`show: f`) is plain function application
  in MoonBit (`template(Seq([...]))`) and needs no construct.

## 9. Selectors and views

```moonbit
pub struct Selector[V]            // opaque; V is the view type of its matches
pub fn Select::heading(level? : Int64, ...) -> Selector[HeadingView]
pub fn Select::label(name : String) -> Selector[ContentView]
pub fn Select::text(text : String) -> Selector[ContentView]
pub fn Select::regex(pattern : String) -> Selector[ContentView]
pub fn Select::elem(path : String, where_? : Array[(String, Value)]) -> Selector[ContentView]
pub fn[A, B] Selector::or(self : Selector[A], other : Selector[B]) -> Selector[ContentView]
```

- `Select::<elem>(field? ...)` is generated per element; with field
  arguments it lowers to `elem.where(field: value)` (`native_func_where`),
  otherwise to the element function. `label`, `regex`, `or`, `and`,
  `before`, `after` lower through `label(..)`, `regex(..)` and the
  `selector` methods. Legality is checked by the consumer's cast:
  `ShowableSelector` for rules, `LocatableSelector` for queries, counters
  and `at` arguments (section 10).
- A **view** wraps the exact engine content the engine passed to the
  callback (for show rules `elem.guarded(guard)` with its location and
  prepared state). `impl IntoContent for HeadingView` re-emits that content
  unchanged, so wrapping it does not restart the rule; constructing a fresh
  `Heading(...)` in the callback creates a new element that the rule may
  match again, exactly as in Typst.
- Views read fields through the engine's field access: `it.body()`,
  `it.level(cx)` (resolved with the callback's styles; raises without
  styles). Phase 1 has `ContentView` (`func_name()`, `field(name)`,
  `text()`, `label()`, `engine()`) and typed views for the phase-1
  elements; phase 2 generates all.

## 10. Context and introspection

```moonbit
SetPage(header=Custom(Some(Context() <| cx => {
  if cx.counter(Counter::page()).get()[0] > 1 {
    return Seq([Emph("typst.mbt"), H(Fr(1)), cx.counter(Counter::page()).display(Numbering("1 / 1"), both=true)])
  }
  Seq([])
})))
```

### 10.1 `Ctx`

A `Ctx` wraps the engine and the `Context` of one callback invocation plus an
**invocation token**. The host function invalidates the token when the
callback returns; every operation on the `Ctx` and on handles derived from
it (`CounterHandle`, `StateHandle`) checks it first and raises
`context used outside of its callback` otherwise.

All operations call Typst's public functions with the invocation's engine
and context, so capability errors, casts and tracked introspection
(`engine.introspect`, recorded reads) are Typst's:

| Operation | Function called | Needs |
|---|---|---|
| `cx.location() -> Location raise` | `here()` | location |
| `cx.counter(c).get() -> Array[Int64] raise` | `counter.get` | location |
| `cx.counter(c).at(sel)`, `.final()` | `counter.at`, `counter.final` | context, selector cast by `LocatableSelector` |
| `cx.counter(c).display(numbering?, both?) -> Content raise` | `counter.display` | location (numbering from styles if omitted) |
| `cx.state(s).get()`, `.at(sel)`, `.final() -> Value raise` | `state.get/at/final` | location / context |
| `cx.query(sel : Selector[V]) -> Array[V] raise` | `query` | location or styles; selector cast by `LocatableSelector` |
| `cx.measure(body, width?, height?) -> Size raise` | `measure` | styles **and** location |
| `cx.styles() -> @library.StyleChain raise` | — (`Context::get_styles`) | styles |

What each callback kind receives is the engine's choice, documented and
tested: `Context`: location and styles; `Show`: styles, and a location only
if the matched element has one; numbering and supplement callbacks: the
context of the display site; cell callbacks receive no `Ctx`. A missing
capability raises Typst's `can only be used when context is known` at the
operation's call site (the operations are `#callsite(autofill(loc))`
methods, so the span is the `cx.query(...)` call).

Callback signatures are fallible and may raise any error:
`(V, Ctx) -> &IntoContent raise` (show), `(Ctx) -> &IntoContent raise`
(context), `(Array[Int64], Ctx) -> &IntoContent raise` (numbering),
`(Int, Int) -> T raise` (cells). `SourceError`s pass through; any other
error becomes an error diagnostic at the callback's origin with the error's
`to_string()` as message.

### 10.2 Counters and state

```moonbit
pub fn Counter::page() -> Counter
pub fn[V] Counter::of(sel : Selector[V]) -> Counter        // counter(heading), counter(figure.where(..))
pub fn Counter::named(key : String) -> Counter
pub fn CounterStep::CounterStep(counter : Counter, level? : Int64, ...) -> CounterStep
pub fn CounterUpdate::CounterUpdate(counter : Counter, values : Array[Int64], ...) -> CounterUpdate
pub fn CounterUpdate::with(counter : Counter, f : (Array[Int64]) -> Array[Int64] raise) -> CounterUpdate
pub fn State::State(key : String, init : Value) -> State
pub fn StateUpdate::StateUpdate(state : State, value : Value, ...) -> StateUpdate
pub fn StateUpdate::with(state : State, f : (Value) -> Value raise) -> StateUpdate
```

Updates are content placed in the document, as in Typst; there is no
captured mutation. They lower to `counter(key).step(level: n)`,
`counter(key).update(values)` (one value or an array for multi-level
counters), `counter(key).update(host)` and `state(key, init).update(..)`.
A state always carries its initial value; reading it gives a `Value`
(typed accessors `as_int()`, `as_str()`, ... raise on mismatch). Phase 1
implements counters; state and functional updates are phase 2.

## 11. Host functions

### 11.1 Engine representation

```moonbit
// library/func.mbt
pub(all) enum FuncInner {
  ...
  Host(HostFunc)                 // a host (MoonBit) closure
}
pub struct HostFunc {
  call : NativeFn                // (Engine, Context, Args) -> Value raise SourceError
  key : U128                     // identity key, unique per callback and compilation
}
pub fn HostFunc::new(key : U128, call : NativeFn) -> HostFunc
pub fn Func::host(f : HostFunc) -> Func
```

- `Func::call`: `(f.call)(engine, context, args)` followed by
  `args.finish()`, as for native functions.
- `name`, `title`, `scope`, `contextual`: `None`; `repr`: `(..) => ..`, the
  repr of an anonymous Typst closure, so content and frame dumps do not
  distinguish host functions from closures.
- **Equality** (`Func ==`, memo input equality): the same `HostFunc` object.
- **Fingerprint**: a discriminant, the `key` and the function span, and it
  sets `fingerprint_identity` like closures do.

### 11.2 Identity

A callback description gets a process-wide serial number when it is
constructed. A session maps serial → `HostFunc`, so **each callback
description is one host function per compilation**, wherever and however
often it is lowered (initially or inside callback results), like a Typst
closure value used in several places. Its `key` is
`hash128("edsl-host", origin, rank)`, where `rank` counts the host functions
of the session in order of first lowering: unique within the compilation and
reproducible across runs (it does not depend on the serial).

**Creation rule (phase 1)**: callbacks must be constructed before
`compile_*` is called. A callback description whose serial is not below the
session's starting serial was constructed during the compilation (inside
another callback); lowering it fails with `callbacks cannot be created
inside a callback` and a hint to construct it outside and capture it, or to
use the `cx` of the enclosing callback. Ordinary descriptions created by
callbacks are unrestricted (section 5.2). Under this rule every host
function exists before layout and keeps its object and key for all layout
iterations, which is what the rules below rely on. Lifting the rule needs a
key derived from the creating invocation (creator key, argument and context
fingerprints, recorded reads); that is phase 3 and will be reviewed on its
own.

### 11.3 Memoization

Host functions follow the closure rules of `library/memo.mbt` without new
cases: a fingerprint containing one has `fingerprint_identity` set, so
frames whose tags hold host functions are not cached (`frame_cacheable`),
memo inputs compare them by identity (`funcs_memo_equal` falls back to
`==`), and a memoized result whose recorded reads contain one is not reused
across introspectors (`reads.lossy`). This is conservative under the
creation rule (identities are stable) and stays correct when the rule is
lifted.

### 11.4 Convergence validation (engine change)

Today `IntrospectionRecorder::validate` compares, for every recorded read,
the fingerprint of the recorded result with the fingerprint of the result on
the new introspector, whatever the flags of that fingerprint. Revision 3
changes the recorder (`library/introspector.mbt`):

```moonbit
priv struct RecordedRead {
  name : String
  expected : U128                          // fingerprint of the result
  replay : (Introspector) -> U128
  exact : ((Introspector) -> Bool)?        // new
}
```

- `Introspector::record` gets the recorded result and, from the read
  methods whose results can hold values (`query`, `query_first`,
  `query_unique`, `query_label`, `query_labelled`, `page_numbering`,
  `page_supplement`), a comparison closure. If the result's fingerprint
  flags are non-zero (lossy or identity), the read keeps
  `exact = i => validate_equal(result, recompute(i))`.
- `validate` requires `replay(i) == expected` **and**, if present,
  `exact(i)`.
- `validate_equal` walks both results in parallel (content fields, arrays,
  dictionaries, styles, arguments, dynamic values, like
  `values_memo_equal`) and compares leaves as follows:
  - **host functions**: the same `HostFunc` object;
  - **Typst closures**: equal structural fingerprints. This is the present
    and upstream behaviour (comemo validates by hash; a closure created
    during layout has a new identity in every iteration and must still
    converge);
  - **gradients and tilings**: the types' own equality (their fingerprints
    go through a rounded repr);
  - **other leaves**: equal fingerprints, and for leaves whose fingerprint
    is marked lossy (dynamic values hashed through their repr) also the
    engine's `==`.
- A **stable query containing host functions converges**: under the
  creation rule the content in both introspectors holds the same `HostFunc`
  objects, so identity comparison succeeds. The check no longer depends on
  128-bit fingerprints being collision-free for identity-bearing or lossy
  results; for results with exact fingerprints it is unchanged, and so is
  its cost.
- `recorder.lossy` and the memo's reuse rule are unchanged.

Gate: this changes validation only for flagged results, and all
differential stages must stay byte-identical (section 17).

### 11.5 Purity contract and determinism check

Callbacks and custom `IntoContent` implementations may run any number of
times, including zero (memo reuse); results must depend only on their
arguments, the `Ctx` and captured immutable data. Mutating captured state or
engine values and reading external resources are unsupported.

`check_determinism` (debug heuristic): with a frozen world, compile twice
with memoization off and compare normalized frames (section 16),
diagnostics and recorded introspections; report the origins of callbacks
invoked on differing paths as candidates. It cannot prove purity.

## 12. Provenance

### 12.1 Tiers

1. **Call provenance (always exact)**: every node knows its constructor
   call's `SourceLoc` and argument ranges.
2. **Runtime text provenance**: for glyphs of a text node, the byte range
   within the string that reached layout (glyph span offset), and the
   occurrence key (`Keyed`). Exact when the string reaches layout unchanged;
   see 12.4 for the limits.
3. **Source-character provenance (best effort, needs a source provider)**:
   mapping a runtime offset to a character of the `.mbt` file. Only for a
   single plain string literal argument and only when a source provider
   supplies the file; escapes, interpolation, concatenation and variables
   report tier 2 only; ligatures and clusters map to the cluster's range.

### 12.2 The origin registry

Source-site identity and runtime occurrence identity are separate:

- a **site** is a constructor call: its `SourceLoc`, its `ArgsLoc` and the
  constructor name;
- an **origin** is a site plus the key path of the enclosing `Keyed`
  wrappers (`["row-17"]`, usually empty).

A session owns one registry: a map from origin (site location string, key
path) to an entry, and the **origin listing**, a text with one line per
entry:

```
report.mbt:42:5-42:31@acme/report Par a0=report.mbt:42:9-42:30@acme/report
report.mbt:57:9-57:40@acme/report TableCell key="row-17" a0=report.mbt:57:19-57:26@acme/report
```

- The registry is **append-only**. An entry is created the first time an
  origin is lowered — during initial lowering or lazily when a callback
  result is lowered — and its line is appended. Existing lines never move,
  so a span, once handed to the engine, denotes the same origin in every
  layout iteration; lowering the same origin again (the next iteration,
  another invocation, a memo-skipped call that never happens) finds the
  existing entry. Deduplication by origin also bounds the listing by the
  number of distinct call sites and keys, not by the number of nodes.
- **Spans** are range spans into the listing (`Span::from_range(id, start,
  end)`): a node's span is its line; an argument's span is the `aN=...`
  token of that argument inside the line. Argument spans are thus contained
  in the node's span, like real source, which is what trace-point
  suppression (`library/diag.mbt`) assumes. A `String` child uses the span
  of the argument it was passed in.
- The session wraps the caller's world: `source(id)` and `file(id)` of the
  listing's file id return the current listing (and those of snippet ids
  the snippet texts, section 13); everything else is delegated. Diagnostics,
  hints, traces and `world_range` therefore see real byte ranges of a real
  file.
- **Limits are checked, never saturated**: range endpoints are 23-bit
  (`Span::from_range` saturates above 8,388,607). Appending a line that
  would end beyond that fails the lowering with `too many distinct origins`
  (a hint names `Keyed` usage as the usual cause). At roughly 100–200 bytes
  per line this is about 50,000 distinct origins.
- **File ids**: the listing is the project-root file `/<edsl-origins>`,
  interned by path, so every session of a process uses the same id; snippet
  files are `/<edsl-markup-N>` with `N` below a fixed cap (section 13). The
  EDSL thus uses at most 1 + 4096 of the 65,535 interned ids, whatever the
  number of compilations. Stale contents cannot be observed through an old
  report because reports resolve from their own snapshot (section 14.2).

### 12.3 Resolution

`Origins::resolve(span) -> Origin?` maps a range span of the listing id to
its entry (binary search over line starts) and, if the range is an argument
token, the argument index. `Origin` has `file`, the line/column range, the
constructor name, the key path and the argument index/range. Spans of
snippet files resolve to the `Markup`/`Equation` origin plus the byte range
inside the snippet. Detached spans (shapes the engine generates) have no
origin; previews fall back to the nearest enclosing tagged element (phase 3).

The IDE adaptation (finding 16): upstream `jump_from_click` looks the span
up in a parsed Typst source (`source.find(span)`), which an origin listing
cannot satisfy. The EDSL does not use that path: a click or region resolves
glyph spans with `Origins::resolve`, which needs no syntax tree.

### 12.4 Text offsets and long text

Glyph span offsets are 16-bit: paragraph collection replaces an offset above
65,535 by zero and shaping saturates sums (`layout/inline_collect.mbt`,
`layout/inline_shaping.mbt`), so overflow cannot be detected from a glyph.
Lowering therefore records it up front: when a text node's string is longer
than 65,535 UTF-8 bytes, its origin entry is marked `long-text` (sticky),
and the resolver reports **tier 1 only** for every glyph of that origin.
For other origins the offset is exact for text that reaches layout
unchanged; text rewritten by the engine (case transforms, text show rules,
smart quotes, hyphenation inserts) yields the offset in the rewritten text,
which the resolver reports as tier 2 with `exact=false` when the node's
string no longer contains the glyph's range.

### 12.5 Resource paths

Origins also take part in path resolution, because Typst resolves a path
string relative to the file of the argument's span (`PathOrStr::resolve`,
`DataSource::load`). The synthetic files are **project-root files**, so:

- a path string in the EDSL (`Image("assets/chart.png")`, bibliography and
  CSL files, raw syntaxes and themes) resolves exactly as it would in a
  Typst main file at the project root: relative to the root. The string is
  passed unchanged — it is not pre-rooted — so the stored source value, the
  `network access is not supported` hint for URLs and all error messages
  are Typst's. Twin: the same call in `/main.typ`.
- dependencies **inside** loaded files keep the engine's rules: an SVG's
  `href` resolves relative to the SVG file; for byte-backed SVGs relative to
  the span's file, i.e. the project root.
- `import`/`include` and paths inside `Markup` resolve relative to the
  snippet file, i.e. the project root as well.

A document needing another base uses root-relative paths or a world rooted
elsewhere; a per-document base directory is not part of this design.

## 13. Escape hatches

```moonbit
pub fn Markup::Markup(source : String, scope? : Array[(String, Value)], loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Markup
pub fn Equation::Equation(source : String, block? : Bool, numbering? : Numbering?,
  number_align? : Alignment, supplement? : Smart[Supplement?], alt? : String?,
  scope? : Array[(String, Value)], label? : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Equation
pub fn Call::Call(path : String, positional? : Array[Value], named? : Array[(String, Value)], loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Call
pub fn Set::Set(path : String, named : Array[(String, Value)], loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Set
```

- The private node of **`Markup`** stores the evaluation mode, the source
  text and the scope as `(name, Value)` pairs (finding 14). It lowers with
  `@eval.eval_string_mapped(engine, context, source, snippet_id, Markup,
  scope)`, where the scope values are lowered first; the context is the
  lowering context (none initially, the invocation's in callbacks). Twin:
  `#eval(source, mode: "markup", scope: (...))`. Syntax and evaluation
  errors point into the snippet and resolve to the `Markup` origin plus the
  position in the string.
- **`Equation(source, ...)`** is the math-string constructor (the settled
  API; an equation from arbitrary content is `Call("math.equation", ..)`).
  It evaluates `source` in math mode with `eval_string_mapped`; the
  evaluator returns an equation element whose `body` is the math content.
  Lowering takes that **body** and calls the element function
  `math.equation(body, block: b, ...)` with `block` always passed
  (default `false`) and the other options only when given. The result has
  the fields of `$x$` (`block: false`) or `$ x $` (`block: true`); there is
  no second wrapper. Twin: `#math.equation(block: b, numbering: n,
  eval(source, mode: "math").body)`.
- **Snippet files.** Each distinct `(origin, source text, mode)` gets a slot
  `N` in the session's snippet table and the file `/<edsl-markup-N>`; the
  same snippet lowered again reuses its slot. Slots are capped at 4096 per
  session (the 23-bit range limit caps a snippet at 8 MiB); exceeding either
  is a lowering error. Slot files are interned by path, so the ids are
  shared by all sessions (section 12.2).
- **`Value`** is the opaque description of a non-content engine value:
  `Value::int(n)`, `::float(x)`, `::bool(b)`, `::str(s)`, `::none()`,
  `::auto()`, `::length(l)`, `::fr(x)`, `::angle(a)`, `::array([..])`,
  `::dict([(k, v)])`, `::content(c)`, `::label(name)`,
  `::call(path, positional?, named?)` and `::engine(v : @library.Value)`.
- **`Call(path, ...)`** calls any public function by its qualified name and
  is content (its displayed result, as `#f(..)` in markup); `Value::call`
  is the same as a value. **`Set(path, named)`** is the generic set rule.
  `path` is resolved like an identifier with field accesses in the
  evaluator: the first segment in the library's global scope, the rest with
  `Value::field` (`table.cell`, `math.equation`, `gradient.linear`). An
  unknown name or a non-function fails with Typst's messages at the call's
  origin. These cover every field the typed constructors do not.

## 14. Compiling and exporting

### 14.1 Engine change: `compile_with`

`typst/lib.mbt` gets

```moonbit
pub fn[T : @library.Output] compile_with(
  world : &@library.World,
  traced : @library.Traced,
  sink : @library.Sink,
  evaluate : () -> @library.Content raise @library.SourceError,
) -> T raise @library.SourceError
```

which is the present `compile_impl` with the evaluation step as a
parameter. It keeps every responsibility in order: the target feature
check (HTML/bundle gates), library and target styles, `evaluate()`, a fresh
memo lifetime, the relayout loop with tracked introspection and recorder
validation, convergence analysis and warnings, and delayed-error promotion.
`compile_impl` becomes `compile_with(world, traced, sink, () => { fetch the
main source; eval_source(..).content() })`, so the Typst path is unchanged.

### 14.2 Sessions and reports

```moonbit
pub fn Document::Document(children : Array[&IntoContent], loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Document
pub fn Document::compile_paged(self : Document, world : &@library.World) -> CompileReport[@layout.PagedDocument]

pub struct CompileReport[T] {
  // private: output : T?
  errors : Array[Diagnostic]          // empty iff there is an output
  warnings : Array[Diagnostic]
  origins : Origins                   // immutable snapshot
}
pub fn[T] CompileReport::output(self : CompileReport[T]) -> T?
pub fn[T] CompileReport::unwrap(self : CompileReport[T]) -> T raise DocError
pub fn CompileReport::pdf(self : CompileReport[@layout.PagedDocument], options? : @pdf.PdfOptions) -> ExportReport[Bytes]
pub fn CompileReport::svg_pages(self : CompileReport[@layout.PagedDocument]) -> ExportReport[Array[String]]
pub fn CompileReport::png_pages(self : CompileReport[@layout.PagedDocument], ppi? : Double) -> ExportReport[Array[Bytes]]

pub struct ExportReport[T] {          // same accessors as CompileReport
  errors : Array[Diagnostic]
  warnings : Array[Diagnostic]        // compilation warnings, then export warnings
  origins : Origins
}

pub struct Diagnostic {
  severity : Severity
  message : String
  hints : Array[String]
  origin : Origin?                    // resolved when the report is built
  trace : Array[TracePoint]           // (description, origin?)
  raw : @library.SourceDiagnostic
}
```

- `compile_paged` creates a session, wraps `world` (section 12.2), runs
  `compile_with` with initial lowering as the evaluation step, deduplicates
  diagnostics like `@typst.compile`, **freezes the registry** into an
  `Origins` snapshot (listing text, entries, snippet texts) and resolves
  every diagnostic's span, hints and trace points against that snapshot.
  This happens on success **and** on failure (N5): a failed compilation
  returns a report with errors, warnings and the origins they refer to.
  `Origins` and `Diagnostic` never consult a world or the interner again,
  so a later compilation reusing the file ids cannot change what an old
  report shows.
- An export on a failed compile report returns the same errors without
  exporting. Otherwise it runs the exporter (`@pdf.pdf`, `@svg.svg`,
  `@render.render`), and returns its output or its errors, with
  `warnings = compile warnings ++ export warnings` and the same `Origins`
  (export diagnostics carry spans of the same registry). Reports compose:
  `doc.compile_paged(world).pdf()`.
- Document settings follow Typst's precedence: `SetDocument(...)` and
  format settings from set rules are in the compiled document; explicit
  export options override them (`PdfOptions::resolve`).
- `Diagnostic::render()` gives `error: message` / `  at file:line:col
  (Constructor, argument n)` / hints / trace; `raw` stays available for
  tools that render with a world.
- HTML (`compile_html`) and bundles compile through their own targets with
  the same session logic (phase 3).

### 14.3 Worlds

`compile_*` takes any `&@library.World`. The EDSL provides:

- `DocWorld::in_memory(files? : Map[String, Bytes], fonts? : Array[Bytes],
  embedded_fonts? : Bool = true, today? : Date, features? : ...)`: project
  files by root-relative path, fonts from bytes plus the embedded Typst
  fonts, a fixed date (or none), a standard library with all formats. For
  tests and browsers.
- `@system.world(root? : String = ".", system_fonts? : Bool = true,
  font_paths? : Array[String], today? : Date)` in `doc/system`: files under
  `root` through `kit`'s `FsRoot`/`FileStore`, packages through
  `SystemPackages`, fonts through `FontStore`, the system or a fixed date;
  plus `@system.write(bytes, path)` helpers.

A world's `main()` is never read by `compile_with`; `DocWorld` returns the
listing id.

## 15. Feature matrix

| Area | Phase | Design |
|---|---|---|
| Page and document setup | 1 | `SetPage`, `SetDocument`, `Page` |
| Typography | 1 | `SetText`/`Text`, `SetPar`/`Par` |
| Headings, outline, numbering | 1 | generated; `Numbering(pattern)` or callback |
| Figures, images (raster, SVG, PDF) | 1 | `Figure`, `Image` |
| Lists, quotes, links, footnotes, references | 1 | generated; `label=`, `Ref` |
| Tables and grids | 1 | `Table`, `Grid`, cells, headers, lines, `Cells` callbacks |
| Math | 1 | `Equation(source, ...)` |
| Code | 1 | `Raw(text, lang?, block?)` |
| Context, counters, query, measure | 1 | section 10 |
| Escape hatches | 1 | `Markup`, `Call`, `Set`, `Value` |
| All remaining elements and fields, typed views and selectors | 2 | generator coverage complete |
| State, functional updates | 2 | section 10.2 |
| Bibliography and citations | 2 | generated `Bibliography`, `Cite` |
| Shapes, gradients, tilings, curves as typed values | 2 | phase 1 through `Call`/`Value::call` |
| HTML and bundle targets | 3 | `compile_html`, target elements |
| Preview provenance, review packaging | 3 | region → origins |
| Callbacks created during layout | 3 | section 11.2 |

## 16. Equivalence: what "the same as Typst" means

### 16.1 Twins

Each construct is specified against a **functional Typst expression** in a
main file at the project root:

| EDSL | Typst twin |
|---|---|
| `Heading("Intro", level=Custom(2))` | `#heading(level: 2)[#"Intro"]` |
| `"some text"` | `#"some text"` in a content block |
| `Seq([a, b, c])` | `[#a#b#c]` |
| `Seq([SetText(size=Pt(9)), a])` | `[#set text(size: 9pt);#a]` |
| `Par(Seq(["a", Emph("b")]))` | `#par[#"a"#emph[#"b"]]` |
| `Labelled(x, "l")`, `label="l"` | `[#x<l>]` |
| `Show(Select::heading()) <| (it, _) => { Block(it) }` | `#show heading: it => block(it)` |
| `ShowSet(Select::figure(), SetText(size=Pt(9)))` | `#show figure: set text(size: 9pt)` |
| `Context() <| cx => { ... }` | `#context { ... }` |
| `Markup(s, scope=...)` | `#eval(s, mode: "markup", scope: (...))` |
| `Equation(s, block=true)` | `#math.equation(block: true, eval(s, mode: "math").body)` |
| `Pt(11) + Em(0.5)` | `11pt + 0.5em` |

### 16.2 Three kinds of equivalence

1. **Structural** (lowering): the lowered content of the EDSL document
   equals the evaluated content of the twin under the **structural dump**:
   the canonical content dump of the test runner (`Dumper::content` in
   `tests/runner/realize_stage.mbt`: sequences, styled content with its
   styles in order, elements with all fields by repr; it has no spans),
   extended for this stage by an option that also prints each element's
   label and each property's `liftable` flag. Functions compare by repr, so
   a host function and the twin's closure both print `(..) => ..`. Diagnostics (errors, warnings, hints) must be equal after
   their spans are reduced to "has a span / detached".
2. **Layout** (behaviour): the paged documents are equal under the
   **frame normalizer**: the `typst-frame-v1` dump of the paged stage with
   (a) every span field replaced by `null` (item spans, glyph spans, format
   option spans), (b) every glyph span offset replaced by `0`, (c)
   locations numbered by first occurrence (the dump already does this, so
   location *relationships* are compared, not hash values), (d) tag content
   through the canonical content dump (functions by repr). Everything else
   — sizes, positions, glyph ids and advances, fonts, paints, images,
   links, tags, page info — is compared bit for bit. The comparison is run
   with memoization on and off.
3. **Export**: SVG text and PDF semantic dumps of the two documents are
   equal (both exporters ignore spans except for diagnostics), and PNG
   pixmaps are byte-identical.

Behavioural tests that have no single twin (callback identity, stale `Ctx`,
creation rule, convergence with host functions in query results, memo on
and off, invalid inputs with their diagnostics) are ordinary tests of the
`doc` package.

## 17. Testing and gates

1. **Twin corpus** (`doc/twins`): pairs of an EDSL builder and a Typst
   source. A new stage of the differential runner, `edsl`
   (`moon run tests/runner --target native -- edsl`), compiles both in the
   same world and checks structural, layout and SVG equivalence; the `doc`
   package's own tests run a subset with the in-memory world.
2. **Milestone (phase 1)**: the *reduced showcase* — `bench/showcase.typ`
   without its *Drawing* and *Citations* sections and without the
   system-font line (page setup with a contextual header and page counter,
   title block, outline, text with footnote and font features, grid, lists,
   quote, math with a labelled equation and a reference, a table with
   stroke/fill callbacks inside a figure, JPEG/SVG/PDF images, highlighted
   code with a show rule, a computed table) — written in the EDSL
   (`doc/twins/showcase.mbt`) is layout- and export-equivalent to its
   functional Typst twin, and its PDF is produced through `doc/examples`.
   Every construct it uses is in phase 1 (section 15). The **full**
   showcase, with typed graphics and the bibliography, is the phase-2
   milestone.
3. **Coverage**: phase 1 — the generator's report lists the element
   functions and fields not yet typed; phase 2 — a test walks the library's
   scope tree and fails if a public element function or field has neither a
   typed parameter nor an entry in the audited exception list.
4. **Rules**: set-rule folding and order, show identity/wrapping/
   fresh-element recursion, regex selectors, invalid selectors, show-set,
   `show page` warning.
5. **Callbacks and context**: one host function per description, memo on
   and off, creation rule, stale `Ctx` and derived handles, capability
   errors per callback kind, a query whose results contain host functions
   converges in the same number of iterations as its closure twin.
6. **Provenance**: a glyph resolves to its node's origin and offset; keyed
   occurrences resolve to different origins of one site; callback-made nodes
   resolve; registry lines never move across iterations; long text
   downgrades; origin and snippet limits; diagnostics of a failed
   compilation resolve from the report alone after another compilation ran.
7. **Examples**: `doc/examples` compiles every example of this document.
8. **Engine gates** for every engine change: all differential stages
   unchanged (syntax/eval/realize 3792, html 508, paged/svg/pdf-semantic/
   render 2299, pdftags 133, bundle 39, wasm-validate 14027, wasm-spec),
   `moon test --target native`, `moon check` on native, wasm-gc and wasm
   without new warnings.

## 18. Phases

1. **Engine**: `compile_with`; `FuncInner::Host`/`HostFunc` with the
   equality, fingerprint and memo rules of section 11; the recorder's exact
   validation; `@eval.check_recipe`; the runner's frame normalizer and
   `edsl` stage. **EDSL**: description values, lowering (initial and
   callback results), the audited exceptions, units and value facades,
   `docgen.py` with the phase-1 element list and overrides, rules,
   selectors and views for those elements, `Ctx` (location, counters,
   query, measure), `Markup`/`Equation`/`Call`/`Set`/`Value`, the origin
   registry with diagnostics and resolution, `DocWorld::in_memory`,
   `doc/system`, PDF/SVG/PNG reports, `doc/examples`, the twin corpus and
   the reduced-showcase milestone.
2. Generator coverage of all public element functions and fields with typed
   views and selectors (coverage test green), state and functional updates,
   bibliography, typed graphics values, the full showcase milestone,
   tier-3 source mapping.
3. Preview provenance (region queries, container fallback, review-comment
   packaging), HTML and bundle targets, callbacks created during layout.

## 19. Resolution index

| Review-2 item | Resolution |
|---|---|
| 1 constructor signatures | 7.2: reviewed per-element signature overrides, enforced by the generator |
| 2 construction environment | 5.1 initial lowering with `Context::none()`; 5.2 callback-result lowering |
| 3 host identity and convergence | 11.2–11.4: one host function per description, creation rule, recorder with exact validation |
| 5 spans | 5.3 span attachment and tracing; 12.2 checked limits and file ids; 12.4 long text; 13 snippet slots |
| 6 resources | 12.5: root-anchored synthetic files, strings passed unchanged |
| 7 smart/none/ints | 6.1, 6.2: `Smart` is `Auto`/`Custom`, adapter rejected on fact 5, `Int64` |
| 9 sequences and labels | 4.2: `Seq` preserves nesting (twin `[#a#b]`), `Labelled` on one expression result |
| 10 show-set, recipe checks | 8: `Transformation::Style`, shared `check_recipe` |
| 11 `Ctx` | 10: capabilities, fallible signatures, tokens on derived handles, counter/state types |
| 12 API coherence | facts 3, 5–9; 4.2 `Seq`/`Seq::of`/`Content`; `label` in signatures; `Keyed`; `SetRule`; `doc/examples` |
| 13 reports | 14.2: `CompileReport`/`ExportReport`, warning propagation |
| 14 markup and math | 13: mode and scope stored, `Equation` on the math body, snippet files |
| 16 equivalence and phasing | 16.2 normalizer and three equivalences; 17.2 reduced milestone; 12.3 IDE adaptation |
| 17 units | 6.3 |
| N1 callback-made nodes | 5.2, 12.2: append-only, deduplicated, lazily extended registry |
| N2 construction rule | 5.3 audited exceptions; 7.1 generator covers public functions |
| N3 element identity | 7.1 `Element` handles and qualified names; 13 path resolution |
| N4 mutable nodes | 4.1 opaque values, snapshots, no cycles |
| N5 provenance ownership | 14.2 reports own origins on success and failure |

## 20. Open questions

1. Whether typed views should resolve style-dependent fields eagerly from
   the callback's styles or take `cx` per accessor (the design takes `cx`).
2. Whether `Sides`/`Corners` need shorthand constructors for the common
   uniform case beyond `all=`.
3. Whether the conservative memo rule for host functions (11.3) should be
   relaxed while the creation rule holds.
