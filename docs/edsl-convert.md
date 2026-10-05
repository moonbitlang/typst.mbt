# A Typst-to-EDSL translator (design, revision 5)

Status: revision 5, approved by the Codex review
`docs/edsl-reviews/convert-plan-5.md`, with its five minor narrowings worked
in (the audited call list, spreads after named arguments, stroke
shorthands, integer literals, the `Numbering` forms). Revision 1 (a draft with source preludes, rule
continuations, merged text and a relaxed comparison) was rejected by the
Codex review `docs/edsl-reviews/convert-plan-1.md`; revision 2 adopted its
replacement design; revision 3 narrows the rules that review 2
(`convert-plan-2.md`) showed unsound: label-valued expressions, callback
wrappers, `eval` as a value fallback, eager view reads, collection spreads,
content boundaries and the encoding of frame tags; revision 4 narrows
further after review 3 (`convert-plan-3.md`): audited non-label calls, a
location for every text, no nested callbacks, a strict definition of total
arguments, no typed stroke dictionaries, literal dictionary keys, and no
translation of trees with syntax warnings; revision 5 applies review 4
(`convert-plan-4.md`): `+` and `str.at` in the non-label proof, total
components for `Sides`/`Corners`, raw values in selectors, no writes in
`context` wrappers, an origin for every inserted value, integer track
counts, and only the operators the facades have; and the first finding of
the sweep (the empty raw of markup). Section 12 maps the reviews' items
to sections.

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
| text | `Lit("..")`: a description with a location of its own for every text expression (plain strings of one array share the array's location, so diagnostics at two texts, e.g. from a show rule on `text`, would be deduplicated into one) | `TextElem::packed` |
| space | `Space()`, `Space::newline()` from `had_newline()` | `space_content` |
| `\` line break, blank line | `Linebreak()`, `Parbreak()` | the elements |
| escape `\#`, shorthand `~` `--` | `Symbol("..")` (new, section 9) | a `Symbol` value, displayed as `SymbolElem` |
| `"`, `'` | `Smartquote(double=true/false)` | `eval_smart_quote` sets `double` |
| `*a*`, `_a_` | `Strong(..)`, `Emph(..)` | |
| raw | `Raw(text, block=b, lang=..)` with `lines().join("\n")`, if the raw has at least one line: the evaluator's raw keeps its lines, and a raw without lines (` `` `) is not `raw("")`, which has one empty line; it is not typed | `eval_raw` |
| `https://..` | `Link(Url(".."))` | `LinkElem::from_url` |
| `<label>` | `Call("label", positional=[Value::str("..")])` in the sequence (a label-valued inserted expression with a location of its own) | the evaluator's attachment rule, which the EDSL applies to label values in sequences |
| `@key`, `@key[supp]` | `Ref("key", supplement=Supplement(..))` | `eval_ref` |
| `= Heading` | `Heading(body, depth=n)` | `eval_heading` sets `depth` |
| `- a`, `+ a`, `3. a`, `/ t: d` | `ListItem(..)`, `EnumItem(.., number=n)`, `TermsItem(..)` as siblings | the item elements; realization groups them |
| `$x$`, `$ x $` | `Equation(source, block=b)` | `eval_equation` |
| `#expr` | section 4.2 | `value.display()` |

Text is **not merged** and paragraphs and lists are **not inferred**: a
show rule on `text` observes how text is split, and the discarding of
newline spaces depends on the realized neighbours. (The handwritten
documents of `doc/twins/bench.mbt` are an author's equivalents of
particular documents, not a lowering rule.) A content block is always
`Seq([..])` of its stream, also with one description: `Seq` displays an
inserted value like markup does (`[#1]` is content, `Seq([Value::int(1)])`),
while the bare value as an argument would be the value. Every expression
of the stream has a description, also those that display nothing: a typed
`let` (section 5) leaves `Seq([])`, the empty content the evaluator pushes
for it. Every inserted value of a stream that is a bare `Value` (a
displayed variable, a global) is wrapped as `Keyed("<n>", value)` with a
number unique in the document: a bare value in an array shares the
array's location with its siblings, and the engine deduplicates
diagnostics by location and message; the key gives each its own origin
and does not change the content.

An equation is `Equation(source, block=..)` with the text of its math node
if no identifier of the math is a user binding; with user bindings that
are translated variables (section 5) it gets them as `scope=`; otherwise
it is not typed (section 6).

A syntax tree with errors or warnings (`**` warns `no text within
stars`) is not translated at all: the document is one fragment (section
6), so its diagnostics are the front end's.

### 4.2 Calls

A callee is a **global path** if it is an identifier, or a field access
chain of identifiers, whose root is not a user binding. The path is
resolved statically in the library's scope; a chain is only a path while
each prefix is a module, a function or a type (so `table.cell`,
`math.equation`, `calc.pow` are paths, `red.lighten` is a method call on a
value).

- The path `label`, and `eval`: not typed (their results can be labels,
  section 6.1).
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
  `Call(path, positional=.., named=..)` with `Value::spread` (T2). A call
  with a spread after a named argument is not typed at all (`Call` passes
  its positional arguments, the spreads among them, before the named
  ones, and a later argument of the same name wins); the same holds for
  the generic set rule.
- Any other path: `Call(path, ..)` in a content stream, `Value::call(path,
  ..)` as a value (T2).
- Methods on values, calls of user functions, closures and everything
  else: not typed (section 6).

**Evaluation order.** Typst evaluates arguments in source order; the EDSL
lowers them in the constructor's lowering order (section 3), `Call` its
positional before its named ones. A translated argument is **total** if
its exact lowering is proven unable to fail or warn; literal operands
alone do not establish that (`Luma(300)` calls `luma` and fails). The
total forms are: boolean, integer, float and string literals; one numeric
literal with a length, ratio, fraction or angle unit; a named colour
constant; `none` and `auto`; `Sides`, `Corners`, `Cells` and arrays of
total values (they lower to dictionaries and arrays without a call); a
translated variable; and content whose stream contains only text, spaces,
symbols, smart quotes, breaks and `Strong`/`Emph`/`Heading`/item elements
of such. Everything else — sums, `rgb`, `luma`, strokes, alignments
combined with `+`, calls, fragments — is not total.
A call is typed only if its arguments that are not total keep their source
order under the lowering order; otherwise it is not typed.

### 4.3 Typed values

An expression is translated against a parameter type only from its
syntactic form, so the typed expression lowers to the value the evaluator
computes:

| Type | Typst forms |
|---|---|
| `&IntoContent` | a content block; a string literal; `none`/`auto` as `NoneValue()`/`AutoValue()`; a `context` expression as its callback (4.6); any expression with a `Value` form |
| `Bool`, `Int64`, `Double`, `String` | the literal (with a sign); a translated variable of that type. An integer literal only if it parses before its sign is applied (`-9223372036854775808` is Typst's error `cannot write minimum integer manually`) and fits the parameter (`Luma(Int)`, `Weight(Int)`) |
| `Length` | numeric literals with a length or ratio unit; sums, differences and negations of those (the facade lowers them with Typst's operators); `auto`/`none` |
| `Spacing`, `Sizing` | one numeric literal (a fraction, a length or a ratio); a `Length` form as `Rel(..)`; `auto`/`none`. No arithmetic with fractions (the facades have none) |
| `Angle` | one numeric literal with an angle unit (the facade has no operators and no states) |
| `Paint` | a named colour constant; `rgb("#..")`; `luma(int)`; `none`/`auto`; any `Value` form as `Value(..)` (T2) |
| `Stroke` | a numeric literal with a length unit; a named colour constant, `rgb("#..")` or `luma(int)`; the sum of the two; `none`/`auto`. Ratios, relative lengths and paints that are arbitrary `Value` forms are not typed shorthands (the facade's `stroke(..)` call would validate them while the arguments are lowered); they use `extra`. (A dictionary literal stays a dictionary, through `extra`: Typst validates its fields when the element function casts it, the facade would validate them while the arguments are lowered.) |
| `Alignment` | the constants; `a + b` of two constants; `auto`/`none` |
| `Dir`, `FontWeight` | the constants (a weight also as an integer literal) |
| `Numbering` | a string literal; `none`. Content and functions stay `Value` forms through `extra` |
| `Supplement`, `LinkTarget` | a string; content; a label literal |
| `&IntoSource` | a string literal, unchanged (section 9: the document's directory resolves it) |
| `Sides[T]`, `Corners[T]` | a dictionary literal with the side keys, only when every component is total (the facade lowers its fields in a fixed order, not in source order); otherwise one `T` as `all=`. A dictionary with a component that is not total stays a dictionary, through `Value::dict` and `extra` |
| `Cells[T]` | one `T` (`Cells::all`); an array literal of `T` (`Cells::columns`) |
| `Array[Sizing]`, `Array[String]`, `(Length, Length)` | an array literal; one value. An integer track count stays an integer, through `extra` (Typst validates it; `Sizing::repeat` would not) |
| `Value` | section 4.4 |

No MoonBit arithmetic, comparison or string operation is ever emitted for
a Typst operator: overflow, division, ordering and diagnostics are
Typst's.

### 4.4 `Value` forms (T2)

Literals; array literals and dictionary literals with identifier or
string-literal keys, of `Value` forms and without spreads
(`Value::spread` exists only among the arguments of a call; a computed
key has no form); a content
block; a global path as `Value::global(path)`; a call of a global path as
`Value::call`; a translated variable; `a + b`, `a - b`, `a * b`, `a / b`
and `-a` of `Value` forms as `a.add(b)` ... `a.neg()` (the EDSL applies
Typst's operator when the value is lowered, left operand first; such a
value is not total); `f.with(..)` and `f.where(..)` where `f` is a global
path that is a function and the method is not a member of its scope, as
`Value::call("function.with", positional=[Value::global(f), ..])` (how
Typst calls the method: the receiver type is proven, the method audited).
Nothing else has a `Value` form; in particular closures, comparisons,
`and`/`or`/`in` and other methods do not (section 6.3).

### 4.5 Rules

- `set path(args)`: `SetX(..)` for a path with a set rule in the table,
  with the rules of 4.2 for the settable fields; positional arguments are
  matched to the settable positional fields in order (for `text`, a length
  is `size` and a colour `fill`, as its parse hooks take them); otherwise
  `Set(path, named, positional=..)` (T2; `positional` is new, section 9).
  `set .. if ..` is not typed.
- `show sel: set ..`: `ShowSet(selector, rule)`.
- `show sel: transform` with a selector of the forms: an element path with
  a selector in the table; its `.where(..)` as `Select::<elem>(field=..)`
  only where the typed form of each field lowers to the raw value of the
  Typst argument (boolean, integer and string literals, one numeric
  literal, a named constant) — `where` keeps its arguments as they are and
  matching compares them with the stored fields, so a constructor
  shorthand (`stroke: 1pt` as `Stroke(thickness=..)`) would select other
  elements; otherwise `Select::elem(path, where_=[..])` with `Value`
  forms (T2); a string
  (`Select::literal`), `regex("..")` (`Select::regex`), a label
  (`Select::label`); another element path as `Select::elem(path, ..)`
  (T2). The transform:
  - a closure literal `x => body` or `(x) => body` (exactly one
    positional parameter that is an identifier; no named parameters, whose
    defaults Typst evaluates when the closure is created, and no sink)
    whose body is a content block or an element constructor call that
    translates with the parameter bound to the callback's view, used only
    as content (which re-emits the matched element), outside a callback
    (a rule or `context` inside the body would be a callback created
    inside a callback, which the EDSL rejects; the body is translated
    with that restriction, so such bodies take the next form). Field reads of the
    view are not translated: the MoonBit callback would perform them
    while it builds its result, before anything of the result is lowered,
    which is not Typst's order. The result is the host callback
    `Show(sel, (it, _) => ..)`;
  - any other closure literal of that parameter shape whose body is
    proven not to be a label (section 6.1) and has no escaping `return`,
    outside a callback: the host callback `Show(sel, (it, _) =>
    Markup("#(<closure>)(<arg>)", scope=[("<arg>", Value::content(it)),
    ..]))`, a fragment (T3) that applies the Typst closure to the matched
    element with the invocation's context; `<arg>` is a name that does
    not occur in the closure. Creating the closure cannot fail (no
    defaults), so doing it per invocation is not observable;
  - any other expression with a `Value` form (a function path such as
    `underline`, content, a string): `ShowWith(sel, value)` (T2; new,
    section 9), which builds the recipe from the value like the evaluator;
  - anything else: the rule is a statement that is not typed.
- `show: transform` (no selector) with a `Value` form of the transform:
  `ShowWith::all(value)`, which applies the recipe to the rest of the
  sequence immediately, like `styled_with_recipe`.
- A rule is a description in the stream, so it styles the descriptions
  after it in the same `Seq`/`Document`, as in Typst.

### 4.6 Context

`context expr`, outside a callback, where `expr` is proven not to be a
label (section 6.1), has no `return` outside a closure of its own (the
evaluator's contextual closure would consume it, a fragment cannot) and
contains no assignment or mutating method call (the contextual closure
captures its outer bindings read-only, with its own error message; a
fragment would reach them through its scope):
`Context(_ => Markup("#{<expr>}", scope=..))`, a host callback whose
result is a fragment evaluated with the invocation's context (T3).
Otherwise, and inside a callback (the EDSL's creation rule forbids
creating callbacks there), the `context` expression is an expression item
(section 6.1): it evaluates to content.

### 4.7 The readable mode: `Prose`

`Lit` for every word is exact and unreadable. `Prose` (`docs/edsl-design.md`,
section 4.4) writes running text as one string, and its lowering is a
sequence of text runs, markup spaces, smart quotes and paragraph breaks —
the evaluator's structure for plain markup. With `--prose` the translator
emits a stream as `Prose("..")` instead of `Seq([..])` **exactly when
`Prose` splits the emitted text into the stream's expressions**: the
stream has no rule and no statement, no white space at its edges (which
`Prose` drops; a content block `[ a ]` has spaces there), no two adjacent
texts (markup's lexer also splits text at punctuation such as `-` and
`.`; `Prose` would join them into one run), and no text with a quote or
white space character. A space becomes a space or a line break (for a
source newline), a paragraph break a blank line, a smart quote its
character, every other description an interpolation (bound to a variable
first if its code is long).

The structure is the same in both modes; what differs is the origin of the
text runs, which share the location of the `Prose` text (so diagnostics
that differ only in the text run they concern would be deduplicated). The
sweep is run in both modes: the exact mode is the reference, the readable
mode additionally tests `Prose` on real paragraphs.

## 5. Bindings

A `let name = init` becomes a MoonBit `let` only if `init` is a literal
whose evaluation is total and has no identity — an integer, float, string
or boolean literal (with a sign), a numeric literal of a length or ratio,
a named colour constant — and `name` is never assigned or mutated anywhere
in the document (`=`, `+=`, ..., destructuring assignment, `push`, `pop`,
`insert`, `remove` on it). The variable has that static type; a use is the
variable where its type is expected, its `Value` (`Value::int(v)`, ...) as
a `Value` form, and that value in a content stream (displayed like `#v`).
The `let` itself leaves `Seq([])` in its stream (4.1).
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
   assignment), contains no `break`/`continue`/`return` outside a loop or
   closure of its own, and is **proven not to evaluate to a label**,
   becomes `Markup("#<expr>", scope=[..])`: one inserted expression
   result, exactly the child the evaluator pushes (`eval_string` of one
   expression returns its display). A label result would be attached to
   the content before the expression by the evaluator, which a fragment
   cannot do. The proof is by form: literals other than labels, content
   blocks, closures, array and dictionary literals, unary operations,
   binary operations other than `+`, `a + b` where both operands are of
   these forms (`none + <x>` is the label), `context` and `include`
   expressions, global paths,
   translated variables, and conditionals, loops and code blocks whose
   branches, bodies and statements are of these forms. A call is of these
   forms only with an audited guarantee for the resolved function and
   receiver: a global path that resolves to an element function (its
   result is content); a global path in the audited list (`lorem`, `rgb`,
   `luma`, `counter`, `state`, `repr`, `str`, `int`, `float`, `range`,
   `datetime`, `stroke`, the gradient constructors, `tiling`; not
   `numbering`, which returns what its function returns); a method in the
   audited list of its receiver's type where the receiver is a call of
   `counter` (`step`, `update`, `get`, `at`, `final`: arrays and content;
   not `display`, which forwards a numbering function's result), a call
   of `state` (`update`), or a
   string literal (every `str` method except `at`, which returns its
   `default`). No other call qualifies: `join`,
   `first`, `at`, `calc.min` and user functions can return a label.
   Its scope holds the translated variables it mentions.
2. **Whole streams.** If a markup stream contains a statement that is not
   typed, an expression item that is not typed and not proven to be no
   label (or that has escaping control flow), or a markup expression that
   is not typed, the **whole stream** is one fragment: the body of its
   content block as `Markup(<body source>, scope=..)`, or the whole
   document. The fragment contains every definition, rule and use of the
   stream in source order, so scoping, captures, mutation, rule tails,
   label attachment and evaluation order are the front end's. If the
   stream mentions names bound by untyped statements of an *enclosing*
   stream, the enclosing stream is the fragment (and so on outwards; the
   document as one fragment has no outer names). A code block (`{ .. }`)
   is typed only as a whole expression by rule 1 (its joins are
   `library.join`, which `Seq` is not).
3. **No value fragments.** An argument expression without a typed or
   `Value` form (a closure such as `fill: (x, y) => ..`, a method call, an
   operator) makes its call not typed; the call is then an expression item
   or its stream a fragment. Typst's `eval` function is not used as a
   value fallback: it evaluates with one synthesized span, so diagnostics
   of the evaluated code that differ only in their location collapse, and
   inside callbacks it would lose the context.
4. **Structure is preserved.** A fragment by rule 1 is one child of the
   sequence; a fragment by rule 2 is the whole sequence. The lowered
   content of a converted document therefore has the same structural dump
   as the evaluated content of its original, also where it is fragments.
5. **Tiers.** T1: typed constructors, rules, callbacks only. T2: at least
   one value-level hatch (`Value::..`, `Call`, `Set`, `ShowWith`,
   `extra=`), no source evaluation. T3: at least one fragment (`Markup`)
   or math string (`Equation`); the table reports documents whose
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
   normalized frames are equal in each mode (spans and glyph span
   offsets erased, locations numbered by first occurrence), and each side
   equals itself across the two modes. The element of a start tag is
   encoded with the structural dump of phase 1 (element identity, every
   stored field, labels; locations in fields by their number), not with
   the realization dump of the `paged` stage, which prints element names
   and public fields only: content that callbacks produce during layout
   is compared structurally here.
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
| 7 value fallback, source context | 6.3 (no value fragments, no `eval` fallback), 9 (`dir`) |
| 8, 9 comparison | section 7: the twin normalizer, structure, both memo modes and cross-mode, expected failures |
| 10 callbacks and tiers | 4.5, 4.6, 6.5 |
| 11 build | section 8 |
| 12 order and measurements | section 11 |

Review 2 (revision 3):

| Review-2 item | Resolution |
|---|---|
| expression fragments can return labels (6.1) | 6.1: only expressions proven by form not to be labels; otherwise the stream is the fragment (6.2) |
| show wrapper: closure construction timing, label results (4.5) | 4.5: closures with exactly one positional identifier parameter (no defaults), body proven not a label, no escaping `return`; a fresh argument name |
| `Context(_ => Markup(..))` and `return`, labels (4.6) | 4.6: excluded; such `context` expressions are expression items |
| content/value boundary, empty statement results (4.1, 5) | 4.1: content blocks are always `Seq([..])`; a typed `let` leaves `Seq([])` |
| `eval` is not diagnostic-equivalent; plain strings share an origin (6.3, 4.1) | 6.3: no value fragments at all; 4.1: `Lit` for labelled text |
| eager view reads in callbacks (4.5) | 4.5: translated callbacks use the view only as content |
| collection spreads (4.4) | 4.4: spread-free literals only |
| frame tags use the realization dump (7) | 7.2: tags are encoded structurally |
| wrapper argument hygiene; `ShowWith::all` | 4.5 |

Review 3 (revision 4):

| Review-3 item | Resolution |
|---|---|
| the non-label proof admits labels (`join`, `calc.min`) | 6.1: calls qualify only with an audited guarantee for the resolved function and receiver type |
| `Lit` only before labels is insufficient | 4.1: `Lit` for every text expression |
| nested host callbacks in the typed callback form | 4.5: outside a callback, body translated with that restriction |
| literal-built facades are not total (`luma(300)`) | 4.2: the total forms are enumerated |
| stroke dictionaries validate early | 4.3: no typed form; a dictionary through `extra` |
| computed dictionary keys | 4.4: identifier or string-literal keys |
| syntax warnings disappear | 4.1: trees with errors or warnings are not translated |

Review 4 (revision 5):

| Review-4 item | Resolution |
|---|---|
| `none + <x>`, `"".at(0, default: <x>)` are labels | 6.1: `+` needs both operands proven; `str.at` is excluded |
| reordering inside `Sides`/`Corners` | 4.3: typed only with total components |
| constructor shorthands in selectors | 4.5: `Select::<elem>(..)` only for raw-value-preserving fields, else `Select::elem` with `Value` forms |
| `context` wrapper and captured-binding writes | 4.6: no assignment or mutating call in the expression |
| inserted values share an origin | 4.1: `Keyed` with a unique number; labels as `Call("label", ..)` |
| count shorthand bypasses validation | 4.3: integer counts stay integers through `extra` |
| typed forms without an API | 4.3: rows split by what the facades have |
