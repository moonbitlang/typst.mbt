# A Typst-to-EDSL translator (design, revision 2)

Status: revision 2. Revision 1 (a draft with source preludes, rule
continuations, merged text and a relaxed comparison) was rejected by the
Codex review `docs/edsl-reviews/convert-plan-1.md`; this revision adopts its
replacement design. Section 12 maps the review's items to sections.

Purpose: stress-test the EDSL of `doc/` (`docs/edsl-design.md`) by
converting existing Typst documents — upstream's test suite and
documentation — to MoonBit, compiling the result and comparing it with the
Typst path. Every disagreement is a bug in (a) EDSL lowering, (b) the
translator, (c) an engine assumption that only held for evaluator-built
content, or (d) a gap in what the EDSL can express. The translator is not a
Typst-to-MoonBit compiler: what it cannot type stays Typst source, and how
much stays source is data.

## 1. The governing fact

An EDSL description is a **deferred computation**: it is lowered when the
document is compiled, each time it is used. A Typst expression is evaluated
once, where it stands, in source order. A translation is therefore sound
only if moving the evaluation of each translated expression to its use
sites cannot be observed. This decides most of the rules below: which
bindings may become MoonBit variables (5), which arguments may be
reordered (4.3), and why fallback fragments never get copies of
definitions (6).

## 2. Units and worlds

- A **case** of the suite is one test of a suite file: the body with its
  annotations stripped (`split_tests`, `strip_notes`), in the main file
  `tests/suite/<file>` of the test world (`test_library()` with the test
  globals, colours, features and small-page styles; the test fonts and
  assets; the fixed date). Its identity is (suite file, test name, ordinal
  in the file). Both paths run in this world: the Typst path compiles the
  main source, the EDSL path lowers the generated document with the same
  world as its base.
- The documentation corpus (`.repos/typst/docs`) is inventoried separately
  (section 10): its files are chapters and library modules of one document
  with a world of its own, not 72 independent documents.

## 3. The API table

`scripts/docgen.py` writes `doc/convert/api_gen.mbt` from the same data
that generates the constructors. Per element function: the Typst path, the
EDSL type, whether it has a constructor, a set rule and a selector, and per
parameter the Typst field, the MoonBit name, the MoonBit type and how it is
passed (`Pos`: a positional parameter of the constructor; `PosOpt`:
positional in Typst but a labelled parameter in the EDSL; `Named`;
`Variadic`); the fields that take positional arguments in the function's
order; the settable fields; the selector's fields; and the **lowering
order** of the constructor's and the set rule's arguments (the order in
which the generated code pushes them, which is the order `Lower::args`
evaluates them in). Function facades (`Lorem`, `PolygonRegular`,
`Paint::tiling`) are listed likewise. The handwritten constructs the
translator emits (`Equation`, `Quoted`, `Symbol`, selectors, units,
paints, strokes, sides) are few and are written out in the translator with
a test that compiles an example of each. Paths that are not in the table
are not typed; they are reachable through `Call`/`Value::call` (T2).

## 4. Translation

The translator walks the AST (`syntax/ast`) with three judgments: a markup
or code stream to a sequence of content descriptions, an expression
against a facade type to a typed MoonBit expression, and an expression to
a `Value` description. Text for fragments is taken from the syntax nodes
(`full_text`), never re-printed.

### 4.1 Markup: one description per evaluator expression

The stream is iterated like `Markup::exprs` (a newline directly after a
statement without a semicolon is no expression). Each expression becomes
the description that lowers to what `eval_expr` produces for it:

| Markup | EDSL | Evaluator |
|---|---|---|
| text | a string | `TextElem::packed` |
| space | `Space()`, `Space::newline()` from `had_newline()` | `space_content` |
| `\` line break, blank line | `Linebreak()`, `Parbreak()` | the elements |
| escape `\#`, shorthand `~` `--` | `Symbol("..")` (new, section 9) | a `Symbol` value, displayed as `SymbolElem` |
| `"`, `'` | `Smartquote(double=true/false)` | `eval_smart_quote` sets `double` |
| `*a*`, `_a_` | `Strong(..)`, `Emph(..)` | |
| raw | `Raw(text, block=b, lang=..)` with `lines().join("\n")` | `eval_raw` |
| `https://..` | `Link(Url(".."))` | `LinkElem::from_url` |
| `<label>` | `Value::label("..")` in the sequence | the evaluator's attachment rule, which the EDSL applies to label values in sequences |
| `@key`, `@key[supp]` | `Ref("key", supplement=Supplement(..))` | `eval_ref` |
| `= Heading` | `Heading(body, depth=n)` | `eval_heading` sets `depth` |
| `- a`, `+ a`, `3. a`, `/ t: d` | `ListItem(..)`, `EnumItem(.., number=n)`, `TermsItem(..)` as siblings | the item elements; realization groups them |
| `$x$`, `$ x $` | `Equation(source, block=b)` | `eval_equation` |
| `#expr` | section 4.2 | `value.display()` |

Text is **not merged** and paragraphs and lists are **not inferred**: a
show rule on `text` observes how text is split, and the discarding of
newline spaces depends on the realized neighbours. (The handwritten
documents of `doc/twins/bench.mbt` are an author's equivalents of
particular documents, not a lowering rule.) A content block is `Seq([..])`
of its stream; a stream with exactly one description that is not a rule is
that description, as `Content::sequence` returns a single child.

An equation is `Equation(source, block=..)` with the text of its math node
if no identifier of the math is a user binding; with user bindings that
are translated variables (section 5) it gets them as `scope=`; otherwise
it is not typed (section 6).

A syntax tree with errors is not translated at all: the document is one
fragment (section 6), so its diagnostics are the front end's.

### 4.2 Calls

A callee is a **global path** if it is an identifier, or a field access
chain of identifiers, whose root is not a user binding. The path is
resolved statically in the library's scope; a chain is only a path while
each prefix is a module, a function or a type (so `table.cell`,
`math.equation`, `calc.pow` are paths, `red.lighten` is a method call on a
value).

- A path with a constructor in the table: the typed constructor. The
  call's positional arguments (trailing content blocks included) are
  matched to the function's positional fields: all to the variadic field if
  that is the only positional one; to the required ones in order if the
  count is theirs; to all positional fields in the function's order if the
  count is theirs; otherwise the call is not typed. Each argument is
  translated against its parameter's type (4.3). A named argument of a
  field that is not a typed parameter, or whose expression has no typed
  form but a `Value` form, goes through `extra=` (T2), which the EDSL
  passes named, or in the positional place for optional positional fields.
  A named argument for a field that Typst takes positionally only, a
  duplicate named argument or a spread argument make the call a generic
  `Call(path, positional=.., named=..)` with `Value::spread` (T2).
- Any other path: `Call(path, ..)` in a content stream, `Value::call(path,
  ..)` as a value (T2).
- Methods on values, calls of user functions, closures and everything
  else: not typed (section 6).

**Evaluation order.** Typst evaluates arguments in source order; the EDSL
lowers them in the constructor's lowering order (section 3), `Call` its
positional before its named ones. A translated argument is **total** if
its lowering cannot fail or warn: literals, typed facade values built from
literals, and content whose stream contains only text, spaces, symbols,
smart quotes, breaks and `Strong`/`Emph`/`Heading`/item elements of such.
A call is typed only if its arguments that are not total keep their source
order under the lowering order; otherwise it is not typed.

### 4.3 Typed values

An expression is translated against a parameter type only from its
syntactic form, so the typed expression lowers to the value the evaluator
computes:

| Type | Typst forms |
|---|---|
| `&IntoContent` | a content block; a string literal; `none`/`auto` as `NoneValue()`/`AutoValue()`; any expression with a `Value` form |
| `Bool`, `Int64`, `Double`, `String` | the literal (with a sign); a translated variable of that type |
| `Length`, `Spacing`, `Sizing`, `Angle` | numeric literals by unit; sums, differences and negations of those (the facade lowers them with Typst's operators); `auto`/`none` |
| `Paint` | a named colour constant; `rgb("#..")`; `luma(int)`; `none`/`auto`; any `Value` form as `Value(..)` (T2) |
| `Stroke` | a length; a paint; `length + paint`; a dictionary literal of stroke fields; `none`/`auto` |
| `Alignment`, `Dir`, `FontWeight` | the constants; `a + b` |
| `Numbering`, `Supplement`, `LinkTarget` | a string; content; a label literal |
| `&IntoSource` | a string literal, unchanged (section 9: the document's directory resolves it) |
| `Sides[T]`, `Corners[T]` | a dictionary literal with the side keys; otherwise one `T` as `all=` |
| `Cells[T]` | one `T` (`Cells::all`); an array literal of `T` (`Cells::columns`) |
| `Array[Sizing]`, `Array[String]`, `(Length, Length)` | an array literal; the count shorthand as `Sizing::repeat(n)`; one value |
| `Value` | section 4.4 |

No MoonBit arithmetic, comparison or string operation is ever emitted for
a Typst operator: overflow, division, ordering and diagnostics are
Typst's.

### 4.4 `Value` forms (T2)

Literals; array and dictionary literals of `Value` forms (with
`Value::spread` for spreads); a content block; a global path as
`Value::global(path)`; a call of a global path as `Value::call`; a
translated variable. Nothing else has a `Value` form.

### 4.5 Rules

- `set path(args)`: `SetX(..)` for a path with a set rule in the table,
  with the rules of 4.2 for the settable fields; positional arguments are
  matched to the settable positional fields in order (for `text`, a length
  is `size` and a colour `fill`, as its parse hooks take them); otherwise
  `Set(path, named, positional=..)` (T2; `positional` is new, section 9).
  `set .. if ..` is not typed.
- `show sel: set ..`: `ShowSet(selector, rule)`.
- `show sel: transform` with a selector of the forms: an element path with
  a selector in the table, its `.where(..)` with typed fields, a string
  (`Select::literal`), `regex("..")` (`Select::regex`), a label
  (`Select::label`); another element path as `Select::elem(path, ..)`
  (T2). The transform:
  - a closure literal with one positional parameter whose body is a
    content block or an element constructor call that translates with the
    parameter bound to the callback's view (`it` as content re-emits the
    element; `it.field` is `view.field("field")`): the host callback
    `Show(sel, (it, _) => ..)`;
  - any other closure literal, outside a callback: the host callback
    `Show(sel, (it, _) => Markup("#(<closure>)(it)", scope=[("it",
    Value::content(it)), ..]))`, a fragment (T3) that applies the Typst
    closure to the matched element with the invocation's context;
  - any other expression with a `Value` form (a function path such as
    `underline`, content, a string): `ShowWith(sel, value)` (T2; new,
    section 9), which builds the recipe from the value like the evaluator.
- `show: transform` (no selector) with a `Value` form of the transform:
  `ShowWith(value)`, which applies the recipe to the rest of the sequence
  immediately, like `styled_with_recipe`.
- A rule is a description in the stream, so it styles the descriptions
  after it in the same `Seq`/`Document`, as in Typst.

### 4.6 Context

`context expr`, outside a callback: `Context(_ => Markup("#{<expr>}",
scope=..))`, a host callback whose result is a fragment evaluated with the
invocation's context (T3). Inside a callback it stays in the enclosing
fragment (the EDSL's creation rule forbids creating callbacks there).

## 5. Bindings

A `let name = init` becomes a MoonBit `let` only if `init` is a literal
whose evaluation is total and has no identity — an integer, float, string
or boolean literal (with a sign), a numeric literal of a length or ratio,
a named colour constant — and `name` is never assigned or mutated anywhere
in the document (`=`, `+=`, ..., destructuring assignment, `push`, `pop`,
`insert`, `remove` on it). The variable has that static type; a use is the
variable where its type is expected, its `Value` (`Value::int(v)`, ...) as
a `Value` form, and that value in a content stream (displayed like `#v`).
Fragments that mention the name get the value in their `scope`. A
translated name that is rebound in the same scope by a binding that is not
translated ends the typed part of that stream (section 6).

Every other binding form (calls, content, arrays, closures, destructuring,
`let` without a value) is a statement that is not typed.

## 6. Fallback fragments

What is not typed stays Typst source, evaluated by the front end. There
are no copied definitions, no continuations and no partial regions; the
rules are:

1. **Expression items.** An embedded expression `#expr` of a markup stream
   that is not typed, is no statement (`let`, `set`, `show`, `import`,
   `include`, assignment) and contains no `break`/`continue`/`return`
   outside a loop or closure of its own, becomes `Markup("#<expr>",
   scope=[..])`: one inserted expression result, exactly the child the
   evaluator pushes (`eval_string` of one expression returns its display).
   Its scope holds the translated variables it mentions. If it mentions a
   name that is bound by a statement that was not typed, rule 2 applies
   instead.
2. **Whole streams.** If a markup stream contains a statement that is not
   typed, an expression item that needs it, or an untypable label
   attachment, the **whole stream** is one fragment: the body of its
   content block as `Markup(<body source>, scope=..)`, or the whole
   document. The fragment contains every definition, rule and use of the
   stream in source order, so scoping, captures, mutation, rule tails,
   label attachment and evaluation order are the front end's. If the
   stream mentions names bound by untyped statements of an *enclosing*
   stream, the enclosing stream is the fragment (and so on outwards; the
   document as one fragment has no outer names). A code block (`{ .. }`)
   is typed only as a whole expression by rule 1 (its joins are
   `library.join`, which `Seq` is not).
3. **Values.** An argument expression without a typed or `Value` form
   that is closed over translated variables — typically a closure literal
   (`fill: (x, y) => ..`, a numbering function) — is
   `Value::call("eval", [source], scope: ..)` during initial lowering
   only: there `eval`'s `Context::none()` and empty introspector are also
   the lowering's. Inside a callback there is no value fallback; the item
   is a fragment by rule 1. Its evaluation order is checked like any
   argument that is not total (4.2).
4. **Structure is preserved.** A fragment by rule 1 is one child of the
   sequence; a fragment by rule 2 is the whole sequence. The lowered
   content of a converted document therefore has the same structural dump
   as the evaluated content of its original, also where it is fragments.
5. **Tiers.** T1: typed constructors, rules, callbacks only. T2: at least
   one value-level hatch (`Value::..`, `Call`, `Set`, `ShowWith`,
   `extra=`), no source evaluation. T3: at least one fragment (`Markup`,
   `eval`) or math string (`Equation`); the table reports documents whose
   only source evaluation is math strings separately (T3m). T4: no
   conversion under this contract, with the reason (section 9 lists the
   known ones). The tier says how the document was expressed, not whether
   it is equal.

For each fragment the manifest records the construct that forced it and
its byte range in the original; the fallback ratio of a document is the
union of those ranges over its length.

## 7. Comparison

For every case, in the test world:

1. **Evaluation**: `Document::lower` against `eval_source`. Both fail or
   both succeed; the diagnostics (errors and warnings after the engine's
   deduplication: severity, message, hints, whether located) are equal;
   the lowered and the evaluated content have the same structural dump
   (`StructDumper`: element identity, every stored field, labels, styles
   with `liftable`, recipes; spans omitted, functions by repr).
2. **Layout**, for cases that upstream compiles to a paged document
   (`is_paged`): `Document::compile_paged` against `@typst.compile`, with
   memoization on and off. Same status and diagnostics; on success the
   normalized frames are equal in each mode (the `edsl` stage's twin
   normalizer: spans and glyph span offsets erased, locations numbered by
   first occurrence, tags with their elements), and each side equals
   itself across the two modes.
3. **Export**, with memoization on: the SVG of every page, the PDF bytes
   and the PNG pixels are equal; export failures are compared as
   diagnostics.

A case that expects errors passes when both paths report the same ones.
The first failing phase and its first difference are recorded. Nothing is
normalized beyond provenance: a difference in text segmentation, tags,
query results or convergence is a failure to classify.

## 8. Build protocol

- `doc/convert` is a pure library: source text, path and library in;
  generated function bodies and the manifest data out.
- The runner gets `edsl-convert [filter]` (writes the generated code and
  `manifest.tsv`) and `edsl-suite [filter]` (compares). Generated code
  goes to gitignored files `tests/edsl_gen/s<k>/gen_*.mbt` in committed
  **stub shard packages** (a `moon.pkg` and one file each), so the tree
  builds without generated code; shards are filled by generated size.
  Generated files only register builders in `fn init` with the committed
  registry package `tests/edsl_gen/registry` (case id, tier, a function
  reference; nothing is built at initialization; the stage sorts by case
  id and checks the registry against the manifest).
- The generator must not depend on what it generates:
  `scripts/edsl_convert.sh` removes the generated files, builds the
  runner, **copies the binary**, runs the copy to generate, and runs
  `moon check` on the shards. Cases whose code does not type-check are
  recorded in the manifest with the compiler's first message
  (`compile-error`, a translator bug, permanently), and regenerated as
  whole-document fragments so the sweep can run; the check is repeated.
- One function `case_<n>` per case; names and tiers are data. Generated
  code uses real constructor calls (each with its own call site) and no
  shared helper.

## 9. EDSL additions and known limits

The plan needs these additions to the EDSL; each is a gap (class d) found
by planning, specified in `docs/edsl-design.md` and tested by a twin:

- `Document(children, dir=..)`: the directory, relative to the project
  root, in which the document's virtual files (origin listing, snippets)
  live, so that relative paths in arguments and fragments resolve as in
  the original file (default: the root). Path strings are passed
  unchanged.
- `Symbol(text)`: the display of a symbol value, markup's escapes and
  shorthands (twin `#symbol("..")`).
- `ShowWith(selector, transform)` / `ShowWith::all(transform)`: a show
  rule whose transform is a value (a Typst function, content), with and
  without a selector.
- `Set(path, named, positional=..)`: positional arguments of the generic
  set rule.
- `Space::newline()`.

Known T4 reasons: the main file imports or includes itself by path (the
EDSL document has no source file); a test that depends on the name of the
main file.

## 10. The documentation corpus

`.repos/typst/docs` is one document (`main.typ` imports the package
`@typst/docs` and includes chapters) rendered by upstream's
`docs/src/world.rs` with a custom library (`stdx`, custom elements and
rules). The plan: inventory the 72 files (entry point, chapters, library
modules; prose and code bytes), try the entry point with the port's CLI,
and convert the files that evaluate on their own in the standard world.
Files that are modules (exports, no content) are counted as such, not as
converted documents; what the missing world blocks is reported as blocked.

## 11. Order of work and measurements

1. The comparator (section 7) and the whole-document fragment baseline on
   the suite: every case as `Document([Markup(source)], dir=..)`. This
   measures the fragment machinery itself (paths, routes, diagnostics).
2. Exact markup (4.1), typed literal arguments and constructors (4.2,
   4.3), T2 calls and rules (4.4, 4.5), callbacks (4.5, 4.6), bindings
   (5), expression fragments (6).
3. The documentation inventory (10).

Per case the manifest has: id, attributes, tier (and T3m), typed and
fragment counts, fragment constructs with byte ranges, fallback ratio,
first-attempt compile status; the stage adds per phase: evaluation status,
diagnostics, structure, frames (memo on, off, cross), SVG, PDF, PNG, and
the first failing phase. The report aggregates per suite directory.

## 12. Resolution of review 1

| Review item | Resolution |
|---|---|
| 1 units and worlds; documentation corpus | sections 2 and 10 |
| 2 API description | section 3: one table with pass kinds, positional order, settable and selector fields, lowering order; handwritten facades written out and tested |
| 3 intermediate judgments, facts | section 4 (three judgments); the facts that are used are totality (4.2), mutation (5) and control flow (6); everything unknown is not typed |
| 4 mirror markup, no merging, symbols | 4.1; `Symbol` (9) |
| 5 argument order, `extra`, bindings, joins, arithmetic | 4.2 (order check), 4.2 (`extra` only for named and optional positional fields), 5 (literals only), 6.2 (code blocks and loops are fragments), 4.3 (no MoonBit operators) |
| 6 fallback regions | section 6: no preludes, no continuations, expression items or whole streams |
| 7 value fallback, source context | 6.3 (`eval` only during initial lowering), 9 (`dir`) |
| 8, 9 comparison | section 7: the twin normalizer, structure, both memo modes and cross-mode, expected failures |
| 10 callbacks and tiers | 4.5, 4.6, 6.5 |
| 11 build | section 8 |
| 12 order and measurements | section 11 |
