# A MoonBit EDSL for typst.mbt (design, revision 8)

Status: revision 8, approved (`docs/edsl-reviews/review-8.md`), with the
clarifications of the implementation review
(`docs/edsl-reviews/impl-review-1.md`) worked in: the occurrence of a
callback invocation (11.2), the collector's scope in validation (11.4),
label-valued expressions in sequences (13), keyed origins of plain strings
and the structural deduplication key (12.2), long strings passed as values
(12.4), settable optional bodies (8) and the pixel comparison of all twins
(16.2). Revisions 3 to 6 resolved the items of
`docs/edsl-reviews/review-2.md` to `review-5.md`. Revision 8 resolves
`review-7.md`: `extra` entries that name an optional positional field are
passed in the field's positional place (6.1), the gradient constructors are
phase 1 throughout, and the wording of 11.4 is limited to what the
fingerprint traversal visits. Revision 7 made two changes:

1. **Section 6, plain values first** (new, at the request of the project
   owner after reading the showcase): a plain value is written plainly
   (`margin=Sides(x=Cm(2.2))`, `header=Context() <| ...`, `level=2`); the
   explicit `auto`/`none` states are spelled by the value family instead
   of wrapping every value in `Custom(..)`/`Some(..)`. Gradients get typed
   constructors. Sections 6.1, 6.2, 6.4 and 6.5 are new; the examples and
   the generated signatures throughout follow.
2. **Section 11.4, convergence validation, is narrowed** in response to
   `docs/edsl-reviews/review-6.md`: the recorder validates host functions
   by identity, which is what this design needs, and no longer attempts to
   make validation exact for values with lossy fingerprints. Reviews 3 to 6
   showed that this cannot be done piecemeal inside validation; it belongs
   in the fingerprints and is separate engine work.

Section 19 maps each review finding to the section that resolves it. Packages: `moonbitlang/typst/doc` (imported as `@doc`),
`doc/system`, `doc/examples`, `doc/twins`.

The examples of this document are compiled code: `doc/examples/
design_examples.mbt` contains each of them, and its tests compile them to
PDF, SVG and PNG with the in-memory world.

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
   qualified instead (`@doc.Heading(...)`). Like enum constructors, a true
   constructor needs neither when the expected type is its own type
   (`numbering=Numbering("1.")`).
10. `with` and `and` are keywords and cannot be method names; `moon fmt`
    rewrites a trailing callback with several parameters as
    `f(a) <| ((x, y) => { ... })` (`f(a) <| (x, y) => { ... }` parses and
    type-checks, but the formatter adds the parentheses; a one-parameter
    callback stays `f() <| x => { ... }`). The callback is the last
    positional parameter, so `f(a, (x, y) => { ... })` is the same call
    without the extra parentheses and is stable under `moon fmt`: the
    documents of `doc/twins` use this spelling. A braced
    body that is a single identifier (`(it, _) => { it }`) parses as a
    record literal; `it` alone or `{ Content(it) }` is meant.
11. An enum may have cases named `None` and `Auto` (the engine's own
    `Value` has both). Where the expected type is that enum, `fill=None`
    resolves to the enum's case; `Option`'s `None` is unaffected
    everywhere else in consumer packages. Inside the package that defines
    such enums a bare `None` can be ambiguous and is written
    `Option::None`.
12. A static method (`Sides::auto()`, `Paint::linear(..)`) needs its type
    in scope (`using @doc { type Sides }`) or qualification; a method call
    on a bare enum case (`Blue.at(..)`) does not resolve, so such helpers
    are static functions with typed parameters (`Paint::stop(Blue, ..)`).

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
  `elemgen.py`) and the reviewed specification in the script (the element
  list with qualified paths and review notes); it does not reuse
  `viewgen.py`'s storage access. It also writes `doc/elements_coverage.txt`.

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
  of a `Seq` or `Document` styles the children after it, exactly as a rule
  inside a Typst block (section 8). Rules are allowed nowhere else.
- A plain **`String`** is literal text, never parsed: it lowers to
  `Value::Str(s).display()` — the `TextElem` that Typst's string-to-content
  conversion creates — spanned with its origin. Twin: `#"s"` inside a content
  block. `Lit(s)` is the same with a location of its own (a `String` inside
  an array has the array argument's location, fact 2; each such child of a
  sequence still gets a span of its own inside that argument's span,
  section 12.2, pieces).
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
  everything lowered inside `body` (section 12.2), including a plain string
  body, whose origin is the enclosing argument under the key. It does not
  change the lowered content. A key that starts with the noncharacter
  U+FDD2 is an error (lowering's own occurrences use it, section 12.2).
- **`Space()`** is markup's space element (`SpaceElem::shared()`), for
  authors who need Typst's collapsing space rather than a `" "` text.
  **`Space::newline()`** is the space markup produces for a line break in
  the source (`SpaceElem::shared_with_newline()`): realization discards it
  next to text of a writing system without spaces (Chinese, Japanese).
  Converted markup needs it to keep the original's behaviour; authors write
  the string without a space instead.

### 4.3 What markup writes with punctuation

A plain string is never parsed, so the constructs that Typst markup spells
with punctuation have constructors, and the characters are written as such:

| Markup | EDSL |
|---|---|
| `"quoted"`, `'quoted'` (smart quotes by language and nesting) | `Quoted("quoted")`, `Quoted("quoted", double=false)`: a `smartquote` element before and after the body; twin `[#smartquote()#body#smartquote()]` |
| an apostrophe `'` inside a word | the character `’` in the string (what the smart quote resolves to in every language) |
| `--`, `---`, `...`, `~`, `-?`, escapes (`\#`) | the characters `–`, `—`, `…`, U+00A0, U+00AD, `#` in the string. (Markup evaluates these to symbol values, displayed as `symbol` elements that realization turns into text; `Symbol("—")`, the twin of `#symbol("—")`, is that element for converted markup.) |
| a line break or several spaces in the source | one `" "` in the string; `Space()`/`Space::newline()` only for the collapsing behaviour |
| a blank line | a new `Par(..)`, or `Parbreak()` between pieces of inline content |
| `= Heading`, `- item`, `+ item`, `/ term: text` | `Heading(..)`, `List([..])`/`ListItem(..)`, `Enum([..])`/`EnumItem(..)`, `Terms([..])`/`TermsItem(..)` |
| `` `raw` ``, `$x$`, `@label`, `<label>` | `Raw(..)`, `Equation(..)`, `Ref(..)`, `label=` or `Labelled(..)` |

`Raw(text)` is the `raw` function: its lines are the lines of the string,
so `Raw("")` has one empty line. The raw without lines that markup's
` `` ` writes has no function form in Typst and none in the EDSL
(`Markup` evaluates it; `docs/edsl-convert.md`, section 4.8).

Plain strings are deliberately not scanned for quotes: a document that
needs a straight `"` or `'` as text can write it, and `Quoted` is explicit
about what the language decides. Running text is written with `Prose`
(4.4), where quotes are smart and white space is markup's.

### 4.4 Prose

Running text with inline elements is noisy as a sequence of fragments:

```moonbit
Par(Seq(["Code blocks are highlighted with a port of ", Raw("syntect"),
         " and Typst’s bundled syntaxes:"]))
```

`Prose` takes the text as one string with the inline descriptions
interpolated into it; with MoonBit's multiline strings (`$|` lines
interpolate, `#|` lines do not) and the pipe operator:

```moonbit
(
  $|Code blocks are highlighted with a port of \{Raw("syntect")}
  $|and Typst's bundled syntaxes:
) |> Prose
```

```moonbit
pub fn Prose::Prose(text : String, quotes? : Bool = true,
                    loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Prose
```

**What the text means.** The string is not markup. Exactly three things
in it are not literal text:

1. **White space** (space, tab, line feed, carriage return). A run of
   white space between two pieces is one space element, markup's
   collapsing `space` (so a line break of the string is a space, and
   next to Chinese or Japanese text it is no space, as in markup:
   the run lowers to `Space::newline()` if it contains a line break and to
   `Space()` otherwise). A line break is a line feed, a carriage return,
   or a carriage return followed by a line feed (one break), as in
   markup. A run with two or more line breaks (a blank line) is a
   paragraph break, `parbreak()`. White space at the start and at the end
   of the text is dropped.
2. **The quote characters** `"` and `'` are `smartquote(double: true)` and
   `smartquote(double: false)`: the engine resolves them by language and
   nesting, and an apostrophe is a single quote, as in markup. With
   `quotes=false` they are literal text.
3. **Placeholders** of interpolated descriptions (below).

Everything else is literal text, one text element per run between those:
`*`, `_`, `#`, `$`, `@`, `<`, `\\`, `~`, `--` from the author or from data
are never interpreted. An interpolated string or number (`\{name}`,
`\{count}`) is part of the text like what surrounds it (its white space
and quotes are treated like the rest); `\{Lit(s)}` inserts a string
verbatim.

The result is inline content, a sequence. As an element's body it is that
body (`Par(Prose(..))`, `caption=Prose(..)`, `Footnote(Prose(..))`, a
table cell); directly in a `Document` or `Seq` it forms paragraphs the way
markup does (realization collects the inline content between blocks, and a
blank line of the prose separates two paragraphs). An interpolated block
element (a `Heading`, a `Figure`) interrupts the paragraph, as in markup.
A plain `String` keeps its meaning: literal text, the twin of `#"..."`.

**Twin.** The content block with one `#"word"` per text run, markup's
white space where the prose has white space (a line break where it has
one), `#smartquote(double: ..)` for the quotes, `#parbreak()` for a blank
line and the interpolated expressions in place:

| EDSL | Typst twin |
|---|---|
| `Prose("a \"b\" \{Emph("c")}.")` | `[#"a" #smartquote(double: true)#"b"#smartquote(double: true) #emph[#"c"]#"."]` |
| `Prose("one\ntwo\n\nthree")` | `[#"one"`⏎`#"two"#parbreak()#"three"]` |

**Interpolation: `Show` is the hook, `Debug` is for people.** `\{x}` in
a string calls `Show` for `x`. The description types that are content of
their own — the generated element, function-facade and view types,
`Content`, `Seq`, `Lit`, `Labelled`, `Keyed`, `Space`, `Symbol`, `Quoted`,
`Markup`, `Equation`, `Call`, `Context`, the counter updates,
`ContentView` and `Prose` itself — implement `@builtin.Show` by writing a
**placeholder**. (The rule types do not, so interpolating a rule does not
compile; nor do `Value`, the state markers `NoneValue`/`AutoValue` and
`Document`: `Content(x)` wraps anything that is content.) What a
description is made of is shown by core's `Debug` trait, which every
description type implements, rules, values and `Document` included, with a
readable representation in constructor syntax:

```moonbit
debug(Heading("Title", level=2))             // Heading("Title", level=2)
debug_inspect(Prose("a \{Emph("b")}"), content="Prose([\"a\", Space, Emph(\"b\")])")
println("built \{Repr(heading)}")            // in a string: Repr, not the bare value
```

`debug(v)`, `debug_inspect(v, ..)` in tests and `\{Repr(v)}` in strings
are the ways to print a description; plain `\{v}`, `v.to_string()` and
`println(v)` give the placeholder and belong to `Prose` only.

A placeholder is the noncharacter U+FDD0, a decimal number in canonical
spelling (no leading zeros, at most 18 digits) and U+FDD1. The number
names the description in a **process-wide table** (`prose_table`), like
the serial of a callback; numbers are 64-bit and never reused. `Prose`
splits its text at the placeholders, **takes** the descriptions out of the
table and puts them into its sequence, so the description keeps its
structure and its own origin (the constructor call inside `\{..}` has its
own call site).

- *Lifetime.* An entry lives from the interpolation to the `Prose` call
  that consumes it — normally the next call. Nothing of the table is part
  of a description, a session or an output; a compilation never reads it
  except to word an error (below). Entries of strings that never reach a
  `Prose` (a description printed with `println` instead of `debug`) stay
  pending. The table holds the 65,536 newest pending entries: beyond
  that the oldest is dropped, and a `Prose` whose text still names it
  fails with `an interpolated description of this text was already used
  by another Prose or Para, or dropped because more than 65536 descriptions
  were interpolated since` (below the oldest pending number the table cannot
  tell a consumed entry from a dropped one). A
  program that builds more than that many strings before turning the
  first into `Prose` must build and consume them in smaller batches.
- *One use.* The text of a `Prose` can be used once: a second `Prose` of
  the same string value finds its descriptions taken and is an error at
  lowering (`an interpolated description of this text was already used by
  another Prose or Para`). Building the string again (a loop, a function)
  creates new placeholders.
- *Reserved characters.* In the text of `Prose` the two delimiter
  characters are reserved: a delimiter that is not part of a placeholder
  with a number that an interpolation was given is an error (`the text of
  Prose contains a reserved character (U+FDD0)`). Text that reproduces a
  pending placeholder exactly — the delimiters around the number of a
  description that is interpolated but not yet consumed — cannot be told
  from the interpolation; data that may contain these noncharacters must
  be inserted with `\{Lit(data)}`, never interpolated as a bare string.
  `Lit` protects the delimiter characters as such; a string that spells a
  complete placeholder of a number that was given out is not
  representable anywhere (lowering rejects it as a leak).
- *Callbacks.* `Prose` and the interpolation are pure constructions that
  run when the author's code runs, also inside a layout-time callback
  (section 11.5): the callback builds its string and its `Prose` in one
  go, what it interpolated is consumed when the constructor returns, and
  the numbers never reach the result, so repeated or skipped invocations
  (memoization) cannot be observed in any output. The table is shared
  state only in the two limits above (the cap and the reserved
  characters). Views are interpolated like descriptions
  (`Prose("§ \{it}")` in a show callback).

**Leaks are errors, never output.** A placeholder is only meaningful in
the text of `Prose`. Lowering checks every string it turns into engine
data or looks up by — literal text (`String`, `Lit`), string values
(`Value::str`, the text of `Raw`, paths, labels, the source of `Markup`
and `Equation`) and names (dictionary keys, argument names of `Call` and
`extra`, the paths of `Call`, `Set` and `Value::global`, scope names, the
keys of `Keyed`, the directory of a `Document`) — for a complete
placeholder with a number that was given out (a delimiter character alone
is ordinary, if unusual, text, which upstream's suite has), also the
string that a called function returns, and fails
with `` `Emph` was interpolated into a string that is not the text of
`Prose` or `Para` `` (naming the interpolated constructor from the table, if
it is still there) at the string's origin, with the hint to use `Prose`,
`Para` or `Seq`. The text of a `Prose` that contains the delimiter characters
without a valid placeholder is rejected (`the text of Prose contains a
reserved character (U+FDD0)`); a rule smuggled in through `Content(..)` is
rejected (`` `SetText` is a rule and cannot be interpolated into prose ``).
All are located errors at the `Prose` call or the offending string
(the directory of a `Document`, which has no argument origin of its own
at that point, is reported without a location).
The check is on the strings the EDSL hands to the engine, not on what
Typst code computes from them: a placeholder that reaches Typst code in an
escaped spelling (the string re-encoded as a Typst string literal with
`\u{fdd0}` escapes and evaluated by `eval` or `Markup`) is rebuilt by that
code as ordinary text of noncharacters and a number. If the rebuilt
string is itself the result of the call, it is still caught (results that
are strings are checked); inside content or a collection that Typst code
returns it is not, and engine values are not scanned. No description is
lost or confused by that, and it does not happen by accident.

**Origins.** The `Prose` call is one origin. Its text runs, quotes and
paragraph breaks all resolve to its `text` argument, like plain strings in
an array resolve to the array's (tier 1; the engine offset of a glyph is
relative to its text run, so tier 2 narrows within the run, not within the
whole string), but **each has a span of its own** inside the argument's
span (section 12.2, pieces), as each expression of the twin has: the engine hashes spans into the keys of located elements — two
paragraphs of one `Prose` with the same words are different elements, as
in markup — and deduplicates diagnostics by span. Its spaces have no span,
like `Space()`. Interpolated descriptions keep their own origins. `Lit`
gives a text a location of its own in the EDSL source where that matters.

**`Para`** (added by `docs/edsl-ports.md`, section 3.1). `Prose` is inline
content, so two of them next to each other in a sequence are one paragraph
with nothing between them. A paragraph of running text is

```moonbit
(
  $|Each dot is one complete trial of all nine milestones.
)
|> Para
Para("One line.", justify=true)
```

`Para(text, quotes~, ..)` is `Par(Prose(text, quotes~), ..)` with the
options of `Par`, and everything above holds for its text (the messages
name `Para`). Twin: `par(..)[..]` around the expansion of the prose. It is
**one origin**: the call of `par` has the site of the `Para` call, and the
text runs, quotes and breaks are pieces of that call's `text` argument,
from the counter of that argument (section 12.2); neither a `Par` nor a
`Prose` is registered. A paragraph break inside the text (a blank line) is
what it is in `par[..]`: the engine's warning, and no second paragraph.

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

### 6.1 Field states: plain values first

Every settable field keeps the engine's full value domain and the difference
between absent, `auto`, `none` and a value. The **common case — a plain
value — is written plainly**; the explicit `auto` and `none` states are
spelled by the value's family, not by wrappers around every value:

| State | The author writes |
|---|---|
| absent (inherit from the style chain) | nothing: the argument is omitted, no named argument is passed |
| a value | the value: `level=2`, `width=Pct(80)`, `fill=Luma(246)`, `numbering=Numbering("1.")`, `margin=Sides(x=Cm(2.2), top=Cm(2.6))`, `header=Context() <| cx => { ... }`, `caption="A caption"` |
| explicit `auto` | by family, see below |
| explicit `none` | by family, see below |

| Value family | Parameter type | `auto` | `none` |
|---|---|---|---|
| enum facades (`Length`, `Spacing`, `Sizing`, `Paint`, `Alignment`, `Dir`) | the enum | its case `Auto`: `width=Auto` | its case `None`: `fill=None` |
| struct facades (`Stroke`, `Numbering`, `Supplement`, `Sides[T]`, `Corners[T]`, `Cells[T]`) | the struct | `Sides::auto()`, `Supplement::auto()` | `Stroke::none()`, `Numbering::none()` |
| content | `&IntoContent` | `AutoValue()` | `NoneValue()` |
| scalars and lists (`Bool`, `Int64`, `Double`, `String`, `Array[String]`) | the scalar | `extra=[("level", Value::auto())]` | `extra=[("lang", Value::none())]` |

- The engine's `Smart<T>` and `Option<T>` layers are therefore **erased
  from the parameter type**: `Smart<Rel<Length>>` is `Length`,
  `Option<Paint>` and `Smart<Option<Paint>>` are `Paint`,
  `Smart<Option<Content>>` is `&IntoContent`,
  `Smart<Margin<Smart<Rel<Length>>>>` is `Sides[Length]`,
  `Smart<NonZeroUsize>` is `Int64`. A generated signature reads like the
  Typst documentation of the function.
- By fact 5 the enum cases resolve without imports wherever the parameter
  type is the enum, and `None` resolves to the enum's case there
  (`fill=None` with `fill? : Paint`), while `Option`'s `None` is unaffected
  elsewhere.
- `extra? : Array[(String, Value)]` is a parameter of every generated
  constructor and set rule: arguments by **field name**, each passed the way
  the Typst function takes that field. It gives scalars their rare explicit
  `auto`/`none`, and it reaches every field the typed parameters do not
  cover yet (section 7.1) without leaving the typed constructor.
  - An entry for a **named** field is a named argument after the typed ones
    (a later argument wins, as in Typst).
  - An entry for an **optional positional** field of the function (the
    reviewed mappings of section 7.2: `enum.item.number`, `place.alignment`,
    `columns.count`, `rotate.angle`, an optional body, ...) is passed
    **positionally, in the field's place**, and replaces the typed argument
    if both are given (the last such entry wins); Typst takes these fields
    only positionally, so a named argument would be `unexpected argument`.
    `EnumItem("x", extra=[("number", Value::auto())])` is
    `enum.item(auto)[x]`, and `SetEnumItem(extra=[("number",
    Value::auto())])` is `set enum.item(auto)`: an explicit `auto` resets
    a number that a set rule would otherwise make the item inherit. The
    generator derives the positional names from the element metadata, the
    same data that makes the typed parameter positional.
  - A **required** positional field (`par.body`) has no state besides its
    value and is not an `extra` name: the entry stays a named argument and
    fails with Typst's `unexpected argument: body`.
- **Which states a field accepts is the engine's cast**, as for units
  (6.3): `Text("x", size=Auto)` fails with Typst's `expected length, found
  auto` at the `size` argument. The generated documentation of each
  constructor lists, per parameter, the states the engine type accepts.
- Integers are `Int64` wherever the engine stores `i64`, `usize` or
  `NonZeroUsize` (literals need no suffix; range and non-zero checks are the
  engine casts'). `Double` is used for `f64`.

### 6.2 The decision, and what was tried

Revisions 3 to 6 mirrored the engine's nesting in the parameter types
(`level? : Smart[Int64]`, `fill? : Paint?`,
`margin? : Smart[Sides[Smart[Length]]]`), which keeps the three explicit
states in the signature but makes the common case noisy:

```moonbit
// revisions 3–6
SetPage(margin=Custom(Sides(x=Custom(Cm(2.2)), top=Custom(Cm(2.6)))),
        header=Custom(Some(Context() <| cx => { ... })))
Block(it, fill=Some(Luma(246)), width=Custom(Pct(100)),
      stroke=Sides(all=Some(Stroke(thickness=Pt(0.5), paint=Luma(220)))))
// revision 7
SetPage(margin=Sides(x=Cm(2.2), top=Cm(2.6)),
        header=Context() <| cx => { ... })
Block(it, fill=Luma(246), width=Pct(100),
      stroke=Sides(all=Stroke(thickness=Pt(0.5), paint=Luma(220))))
```

For an API whose authors are AI agents and whose reviewers are humans, the
second form is the goal. Three ways to get it were compiled
(moon 0.1.20260920):

1. **Adapter parameters** — `width? : &IntoSmartLength` with impls for
   `Length` and an `Auto` marker, or a generic `fn[L : IntoSmartLength]`.
   Rejected on evidence: with a trait-object or generic parameter the
   unqualified unit constructors stop resolving (`The value identifier Pt
   is unbound`, fact 5), which would trade `Custom(Pct(80))` for
   `@doc.Pct(80)` or an import list of every case, and each family needs
   one trait per state combination.
2. **Constructor overloads** — MoonBit has none; a second constructor per
   element for the explicit states doubles the generated API.
3. **States inside the value families** (chosen): the facade enums gain the
   cases `Auto` and `None`, the facade structs static constructors, content
   two marker descriptions. It compiles as intended —
   `width=Pct(80)`, `width=Auto`, `fill=None`,
   `margin=Sides(x=Cm(2.2), top=Auto)`, `header=NoneValue()` — needs no
   imports beyond the constructors used, and keeps the generated `.mbti`
   readable (`width? : Length`, `margin? : Sides[Length]`,
   `header? : &IntoContent`).

What is given up is the type-level statement of which explicit states a
field accepts. It is replaced by (a) the generated documentation, (b) the
engine's cast error at the argument's location, with Typst's message, and
(c) the fact that the mistake is the rare case: a wrongly placed `Auto` or
`None`, not a missing wrapper on every value. The four states stay
expressible for every field (6.1), which is what the twins and the escape
hatch `extra` are tested for.

### 6.3 Units

```moonbit
/// Lengths and ratios: everything Typst writes as `11pt`, `2em`, `50%` and
/// their sums. One type for the engine's `Length`, `Rel<Length>`, `Ratio`.
pub(all) enum Length {
  Auto; None                                        // explicit states (6.1)
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
  Auto; None                                        // explicit states (6.1)
  Fr(Double)
  Pt(Double); Mm(Double); Cm(Double); In(Double); Em(Double); Pct(Double)
  Rel(Length)                                       // any composed length
}
/// The engine's `Sizing` and track sizes: additionally `auto`.
pub(all) enum Sizing {
  Auto; None
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
  the engine's value operators in source order. A leaf is the value of the
  corresponding numeric literal, made by the evaluator's own conversion
  `Value::numeric(x, unit)`: `Pt(x)` is `x pt` (a `Value::Length`; likewise
  `mm`, `cm`, `in`, `em`), `Pct(x)` is `x%` (a `Value::Ratio` of `x / 100`),
  `Fr(x)` is `x fr`, `Deg`/`Rad` are angles. `Sum(a, b)` is
  `@library.add(lower(a), lower(b))`, `Diff` is `sub`, `Neg` is `neg`,
  `Scaled(a, k)` is `mul(lower(a), Float(k))`. So `Pt(11) + Em(0.5)` is a
  length, `Pt(1) + Pct(50)` a relative length and `Pct(50)` a ratio, with
  the floating-point evaluation order of the Typst expression
  `11pt + 0.5em`.
- **Legal conversions** are the field's engine cast: a `Pct` in a field of
  engine type `Length` fails with the engine's cast message at that
  argument (`expected length, found ratio`), and so does a state the field
  does not accept (`expected length, found auto`). Arithmetic on a state
  is Typst's operator error (`cannot add auto and length`). The unit shorthands of `Spacing`/`Sizing` (`Pt(40)`) lower like
  `Rel(Pt(40))`; `Fr(x)` lowers to `Value::Fraction`.
- Track lists (`TrackSizings`) are `Array[Sizing]`:
  `columns=[Auto, Fr(1), Pt(40)]`.

### 6.4 Other value facades

All are immutable and lowered through Typst's public functions or values.

| Engine type | EDSL | Example |
|---|---|---|
| `Paint`, `Color` (with `Option`/`Smart`) | `enum Paint { Auto; None; Rgb(String); Luma(Int); Black; White; Red; ...; Value(Value) }` (Typst's named colours, lowered to the global bindings `black`, `red`, ...) and the typed gradient constructors `Paint::linear(stops, angle?, ..)`, `Paint::radial(stops, ..)`, `Paint::conic(stops, ..)`; `Paint::stop(color, Pct(30))` positions a stop (static, by fact 12) | `fill=Rgb("#1f4e79")`, `fill=Paint::linear([Rgb("#1f4e79"), Rgb("#7fc8a9")], angle=Deg(20))` |
| `Stroke` | `Stroke(paint?, thickness?, cap?, join?, dash?, miter_limit?)` → `stroke(...)`; `Stroke::none()`, `Stroke::auto()` | `Stroke(thickness=Pt(0.5), paint=Luma(220))` |
| `Sides<T>`, `Margin<T>` | `Sides[T]`: `Sides(all?, x?, y?, left?, top?, right?, bottom?, rest?)`; `all` lowers to the bare value, the others to Typst's dictionary; combining `all` with a side is a lowering error; `Sides::auto()`, `Sides::none()` for the field as a whole | `inset=Sides(all=Pt(9))`, `margin=Sides(x=Cm(2.2), top=Auto)` |
| `Corners<T>` | `Corners[T]`: `Corners(all?, top?, ..., top_left?, ...)`, same rule | `radius=Corners(all=Pt(4))` |
| `Alignment` and its subsets | `enum Alignment { Auto; None; Start; Left; Center; Right; End; Top; Horizon; Bottom; Both(Alignment, Alignment) }` with `impl Add` | `Center + Horizon` |
| `Numbering` | `Numbering(pattern)`; `Numbering::func() <| (numbers, cx) => { ... }`; `Numbering::none()` | `numbering=Numbering("1.1")` |
| `Supplement` | `Supplement(content)`; `Supplement::func() <| (it, cx) => { ... }`; `Supplement::none()`, `Supplement::auto()` | |
| `Celled<T>` | `Cells[T]`: `Cells::all(v)`, `Cells::columns([..])`, `Cells() <| (x, y) => { ... }` | section 7.3 |
| `DataSource` | `&IntoSource`, implemented by `String` (a path), `Bytes`, `Array[String]` (several paths, where the field takes them) and `Source` (`Path`, `Bytes`, `Many`) | `Image("chart.png")`, `Bibliography(["a.bib", "b.yml"])` |
| `TrackSizings` | `Array[Sizing]`; `Sizing::repeat(n, size?)` is Typst's count shorthand | `columns=[Auto, Fr(1)]`, `columns=Sizing::repeat(5)` for `columns: 5` |
| colour maps | `Paint::map(name)`: the stops `..color.map.<name>` (a spread value, section 13) | `Paint::conic(Paint::map("rainbow"))` |
| `Tiling` | `Paint::tiling(body, size?, spacing?, offset?, angle?, relative?)` (generated from the function's metadata) | `fill=Paint::tiling(Line(..), size=(Pt(8), Pt(8)))` |
| `FontWeight`, `Dir` | enums (`Bold`, `Weight(450)`; `Ltr`, `Rtl`, `Auto`) | `weight=Bold` |
| other string enums | `String`, as written in Typst, in phase 1 (`fit="cover"`); generated enums in phase 2 | |
| `LinkTarget` | `enum LinkTarget { Url(String); ToLabel(String); Dest(Value) }` | `Link(Url("https://.."))` |
| anything else | `Value` (section 13), also through `extra` | `Value::call("tiling", ...)` |

`pub trait ToValue { to_value(Self) -> Value }` (sealed) is implemented by
all of these, by `Bool`, `Int`, `Int64`, `Double`, `String`, `Array[T]`,
`Content` and `Value`; it is the bound of generic facades such as
`Cells[T]` and `Sides[T]`.

**Typed value constructors** (the three gradient constructors in phase 1;
colour spaces, tilings, dash patterns, dates in phase 2) follow the rule of
the elements: where
the engine has a native function (`gradient.linear`), the facade is a
constructor with that function's parameters — positional ones first,
settable ones as optional labelled parameters with plain values — and it
lowers by calling the function. Phase 1 writes the three gradient
constructors by hand; phase 2 generates the function facades from the
manifest's function metadata, as `docgen.py` does for elements. The
generator has the mechanism (`FUNCS` in `scripts/docgen.py`): a function
that returns content becomes a content type (`Lorem(words)`,
`PolygonRegular(vertices?, size?, fill?, stroke?)`), a function that
returns a value a static method of its facade (`Paint::tiling(..)`). The
list is the functions the full showcase needs; the other value functions
(colour spaces, dash patterns, dates) remain `Value::call`.

### 6.5 Before and after

The reduced showcase (`doc/twins/showcase.mbt`), revision 6 and revision 7:

```moonbit
// revision 6
SetPage(
  paper="a4",
  margin=Custom(Sides(x=Custom(Cm(2.2)), top=Custom(Cm(2.6)), bottom=Custom(Cm(2.4)))),
  header=Custom(Some(Context() <| cx => { ... })),
)
SetHeading(numbering=Some(Numbering("1.1")))
Show(Select::heading(level=Custom(1))) <| (it, _) => { ... }
Block(
  it,
  fill=Some(Luma(246)),
  inset=Sides(all=Pt(9)),
  radius=Corners(all=Pt(4)),
  width=Custom(Pct(100)),
  stroke=Sides(all=Some(Stroke(thickness=Pt(0.5), paint=Luma(220)))),
)
let title_fill : Paint = Value(
  Value::call(
    "gradient.linear",
    positional=[Value::paint(Rgb("#1f4e79")), Value::paint(Rgb("#2e86ab")), Value::paint(Rgb("#7fc8a9"))],
    named=[("angle", Value::angle(Deg(20)))],
  ),
)
Text("1234567890", number_type=Custom("old-style"))
Figure(Image("glacier.jpg", width=Custom(Pct(100))), caption=Some("A JPEG photo, embedded as is."))
Table(
  cells,
  align=Cells::columns([Custom(Left), Custom(Left), Custom(Right), Custom(Right)]),
  fill=Cells() <| (_, y) => { if y > 0 && y % 2 == 1 { Some(Luma(247)) } else { None } },
)
Raw(rust_code, lang=Some("rust"), block=true)

// revision 7
SetPage(
  paper="a4",
  margin=Sides(x=Cm(2.2), top=Cm(2.6), bottom=Cm(2.4)),
  header=Context() <| cx => { ... },
)
SetHeading(numbering=Numbering("1.1"))
Show(Select::heading(level=1)) <| (it, _) => { ... }
Block(
  it,
  fill=Luma(246),
  inset=Sides(all=Pt(9)),
  radius=Corners(all=Pt(4)),
  width=Pct(100),
  stroke=Sides(all=Stroke(thickness=Pt(0.5), paint=Luma(220))),
)
let title_fill = Paint::linear(
  [Rgb("#1f4e79"), Rgb("#2e86ab"), Rgb("#7fc8a9")],
  angle=Deg(20),
)
Text("1234567890", number_type="old-style")
Figure(Image("glacier.jpg", width=Pct(100)), caption="A JPEG photo, embedded as is.")
Table(
  cells,
  align=Cells::columns([Left, Left, Right, Right]),
  fill=Cells() <| (_, y) => { if y > 0 && y % 2 == 1 { Luma(247) } else { None } },
)
Raw(rust_code, lang="rust", block=true)
```

The explicit states, where a document needs them:

```moonbit
Block("x", fill=None, width=Auto)                         // fill: none, width: auto
SetPage(header=NoneValue(), margin=Sides::auto())         // header: none, margin: auto
Heading("x", numbering=Numbering::none())                 // numbering: none
Heading("x", extra=[("level", Value::auto())])            // level: auto (a scalar)
```

## 7. Elements (generated)

### 7.1 Signature rule

```moonbit
#callsite(autofill(loc, args_loc))
/// `heading`: A section heading.
///
/// Explicit states besides a value:
/// - `level`: `auto` as `extra` with `Value::auto()`
/// - `numbering`: `none` as `Numbering::none()`
/// - `supplement`: `auto` as `Supplement::auto()`, `none` as `Supplement::none()`
/// - `bookmarked`: `auto` as `extra` with `Value::auto()`
/// - `hanging_indent`: `auto` as `Auto`
pub fn Heading::Heading(
  body : &IntoContent,
  level? : Int64,
  depth? : Int64,
  offset? : Int64,
  numbering? : Numbering,
  supplement? : Supplement,
  outlined? : Bool,
  bookmarked? : Bool,
  hanging_indent? : Length,
  extra? : Array[(String, Value)],
  label? : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Heading                          // a description; pure, never raises
```

- One type and true constructor per **public element function**. The
  generator's specification lists them by qualified Typst path with the
  element they denote; a test resolves every listed path in the library's
  scope (as `Call` does) and checks that it is the element function whose
  handle the constructor stores. Elements without a public function
  (`context`, `sequence`, `styled`, `space`, tags, counter/state update and
  display elements, ...) get no constructor; they are the audited list of
  section 5.3 or products of public functions. The phase-2 coverage test
  walks the library's scope tree (the global scope, the scopes of functions
  and types, and the `math`, `html`, `pdf` modules) for completeness.
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
  section 6 (plain values: the engine's `Smart`/`Option` layers are
  erased); then `extra? : Array[(String, Value)]` (section 6.1) and
  `label? : String`, before the autofilled locations; a callback
  parameter, if any, is the last positional one. The generated
  documentation lists the explicit states each parameter accepts and how
  they are written, as shown above.
- Constructors are pure and do not raise: validation happens during
  lowering, where errors point to the call or the argument.
- Field types the type table does not cover yet are **left out of the typed
  parameters and listed in the generated coverage report**; they stay
  reachable through `extra` on the same constructor, and through
  `Call`/`Set` (section 13). Phase 2 ends when that list is empty.
- **Reserved parameter names**: `extra`, `label`, `loc`, `args_loc`. The generator
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
| `block`, `box` | `Block(body, ...)` | the optional positional body is required; the body-less form is `Call("block", ..)` |
| `rect`, `square`, `circle`, `ellipse`, `title` | `Rect(body?, ...)` | the optional positional body is a labelled parameter passed positionally |
| `align` | `Align(alignment, body)` | the optional positional `alignment` is required and first |
| `place`, `rotate`, `columns`, `enum.item` | `Place(body, alignment?, ...)` | an optional positional parameter is labelled and passed positionally before the body |
| `image` | `Image(source : &IntoSource, ...)` | `String` (path) or `Bytes` |
| `raw` | `Raw(text : String, block?, lang?, ...)` | text is a string, not content |
| `figure` | `Figure(body, caption? : &IntoContent, ...)` | caption content is wrapped by the engine's cast |
| `equation` | `Equation(source : String, block?, numbering?, ..., scope?)` | section 13 |
| `table`, `grid` | `Table(children, columns?, ..., gutter?)` | external `gutter`, parse hooks |
| `v`, `h` | `V(amount : Spacing, weak?)` | internal `attach` not exposed |
| `math.equation` | `SetEquation(..)`, `Select::equation(..)`, `EquationView` | generated without a constructor: the constructor is the handwritten `Equation(source, ..)` |
| `bibliography` | `Bibliography(sources : &IntoSource, title?, full?, style? : String, ..)` | one path, bytes or several sources; `style` is a CSL name or path |
| `cite` | `Cite(key : String, supplement?, form?, style?)` | `key` is the label name |
| `scale` | `Scale(body, factor?, x?, y?, ..)` | the external positional `factor` is labelled and passed positionally |
| `polygon`, `curve` | `Polygon(vertices : Array[(Length, Length)], ..)`, `Curve(components, ..)` with `CurveMove`/`CurveLine`/`CurveQuad`/`CurveCubic`/`CurveClose` | a variadic parameter of values is a typed array |

Each generated type's documentation carries its review note with the
functional twin (`scripts/docgen.py`, `review=`).

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
    align=Cells::columns([Left, Right]),
    fill=Cells() <| (_, y) => { if y > 0 && y % 2 == 1 { Luma(247) } else { None } },
  ),
  caption="Differential test stages.",
  label="stages",
)
```

## 8. Rules: set, show, show-set

```moonbit
Document([
  SetPage(paper="a4", margin=Sides(x=Cm(2.2), top=Cm(2.6))),
  SetText(font=["Libertinus Serif"], size=Pt(11), lang="en"),
  SetPar(justify=true, leading=Em(0.62)),
  SetHeading(numbering=Numbering("1.1")),
  Show(Select::heading(level=1)) <| (it, _) => {
    Seq([V(Em(0.6)), Block(Text(it, fill=Rgb("#1f4e79"))), V(Em(0.2))])
  },
  ShowSet(Select::figure(), SetText(size=Pt(9))),
  Heading("Text and paragraphs"),
  Par("..."),
])
```

- A rule is a description that is only valid as a **direct child of a
  `Document` or a `Seq`**. It styles the children after it in that sequence
  and nothing outside it, exactly as `#set`/`#show` inside a Typst content
  block: lowering a sequence follows `eval_markup_exprs` — on a set rule,
  the remaining children are lowered as the tail and pushed as
  `tail.styled_with_map(styles)`; on a show rule, as
  `tail.styled(Recipe(recipe))`.
- **Anywhere else a rule is a lowering error** (review-3, issue B): as a
  single content argument (`Par(SetText(..))`), inside `Keyed`/`Labelled`,
  and in particular as an entry of a **variadic argument array**
  (`Table([SetText(..), "a", "b"])`). The error is `rules are only allowed
  directly in `Document` and `Seq``, at the rule, with the hint to wrap the
  rule and the content it styles in `Seq([..])`. A variadic array is never
  given sequence semantics: every entry is lowered on its own and passed as
  exactly one positional argument, so cells, headers and footers reach the
  element function as the author wrote them. Styling a whole table is a rule
  before the table in the enclosing sequence; styling one cell is a `Seq`
  inside that cell. (Typst has the same restriction: `set` and `show` are
  only allowed directly in code and content blocks.)
- **`SetX(...)`** (one generated type per element with settable fields —
  every field the function does not require, an optional positional body
  included: `SetRect(body="x")` is `set rect([x])`; all parameters
  optional, no `label`) lowers to
  `elem.set(engine, args.spanned(span)).spanned(span).liftable()`. Custom
  set parsers, repeated properties and folding (relative sizes compose,
  strokes and insets fold) behave identically; realization still decides
  `outside`.
- **`Show(selector) <| (it, cx) => { ... }`**: the selector description
  (section 9) is lowered to a value and cast to `ShowableSelector` under
  `at(selector_span, ..)`, so location/before/after selectors and nested
  regex selectors are rejected with Typst's messages. The recipe is
  `Recipe::new(Some(selector), Func(host), span)`.
- **`ShowSet(selector, rule : &SetRule)`** takes exactly one set rule, like
  `show sel: set f(..)`. It lowers the selector as above, the rule as a set
  rule (`Styles`, spanned and liftable as above), and builds
  `Recipe::new(Some(selector), Style(styles), span)`. Several show-set rules
  are several `ShowSet` values, in order. `SetRule` is the sealed trait of
  the `SetX` types and of the generic `Set`.
- **Recipe checks**: after building a recipe, lowering runs the evaluator's
  `check_show_page_rule` and `check_show_par_set_block` through the public
  `@eval.check_recipe(engine, recipe)` (engine change; the evaluator calls
  the same function). `Show(Select::page())` thus warns
  `` `show page` is not supported and has no effect``.
- A show rule without a selector (`show: f`) is plain function application
  in MoonBit (`template(Seq([...]))`) and needs no construct.
- **`ShowWith(selector, transform : Value)`** is the show rule whose
  transformation is a value — a Typst function (`show link: underline` is
  `ShowWith(Select::link(), Value::global("underline"))`), content or a
  string — cast to a transformation at the `transform` argument like the
  evaluator casts the right-hand side of a show rule.
  **`ShowWith::all(transform)`** is `show: transform`: like the evaluator's
  `styled_with_recipe`, a rule without a selector is applied to the rest of
  the sequence at once (`recipe.apply`) instead of styling it. These are the
  value-level hatch for rules, as `Set` is for set rules; converted Typst
  code needs them for transformations that are not MoonBit callbacks.

## 9. Selectors and views

```moonbit
pub struct Selector[W]            // opaque; W is the view type of its matches
pub fn Select::heading(level? : Int64, depth? : Int64, ...) -> Selector[HeadingView]
pub fn Select::label(name : String) -> Selector[ContentView]
pub fn Select::literal(text : String) -> Selector[ContentView]      // show "text": ..
pub fn Select::regex(pattern : String) -> Selector[ContentView]
pub fn Select::elem(path : String, where_? : Array[(String, Value)]) -> Selector[ContentView]
pub fn[A, B] Selector::or(self : Selector[A], other : Selector[B]) -> Selector[ContentView]
pub fn[A, B] Selector::and_(self : Selector[A], other : Selector[B]) -> Selector[ContentView]
```

- `Select::<elem>(field? ...)` is generated per element (`Select::heading`,
  `Select::table_cell`, `Select::text` for the `text` element). Its optional
  parameters are the element's named settable fields with their field
  types; with arguments it lowers to `elem.where(field: value)`
  (`native_func_where`), otherwise to the element function. `label`,
  `regex`, `or`, `and_` lower through `label(..)`, `regex(..)` and the
  `selector` methods (`before`/`after`/`within` follow in phase 2).
  Legality is checked by the consumer's cast: `ShowableSelector` for rules,
  `LocatableSelector` for queries, counters and `at` arguments (section 10).
- A **view** wraps the exact engine content the engine passed to the
  callback (for show rules `elem.guarded(guard)` with its location and
  prepared state). `impl IntoContent for HeadingView` re-emits that content
  unchanged, so wrapping it does not restart the rule; constructing a fresh
  `Heading(...)` in the callback creates a new element that the rule may
  match again, exactly as in Typst.
- Views read fields through the engine's field access. Phase 1 has
  `ContentView` (`func_name()`, `field(name)`, `content_field(name)`,
  `text()`, `label()`; `field` returns an opaque `Value` that can be
  passed on; `engine()` and `engine_field(name)` give read-only access to
  the engine content and values for inspection), and per element a typed
  view with
  `view()` and an accessor for each required content field (`it.body()`);
  phase 2 generates typed accessors for all fields (style-resolved ones
  take `cx`).

## 10. Context and introspection

```moonbit
SetPage(header=Context() <| cx => {
  let page = cx.counter(Counter::page())
  if page.get()[0] > 1 {
    return Seq([Emph("typst.mbt"), H(Fr(1)), page.display(numbering=Numbering("1 / 1"), both=true)])
  }
  Seq([])
})
```

### 10.1 `Ctx`

A `Ctx` wraps the engine and the `Context` of one callback invocation plus an
**invocation token**. The host function invalidates the token when the
callback returns; every operation on the `Ctx` and on handles derived from
it (`CounterHandle`, `StateHandle`) checks it first and raises
`context used outside of its callback` otherwise.

All operations call Typst's public functions with the invocation's engine
and context, so capability errors, casts and tracked introspection
(`engine.introspect`, recorded reads) are Typst's. What each needs is what
the function needs (review-3, issue E; `library/counter.mbt`,
`library/state.mbt`, `library/query.mbt`, `library/measure.mbt`):

| Operation | Function called | Needs |
|---|---|---|
| `cx.location() -> Location raise` | `here()` | location |
| `cx.counter(c).get() -> Array[Int64] raise` | `counter.get` | location |
| `cx.counter(c).final_value() -> Array[Int64] raise` | `counter.final` | location |
| `cx.counter(c).at(sel) -> Array[Int64] raise` | `counter.at` | location or styles; `sel` cast by `LocatableSelector` and resolved uniquely |
| `cx.counter(c).display(numbering?, both?) -> Content raise` | `counter.display` | location; without `numbering`, styles for the counted element's numbering |
| `cx.state(s).get() -> Value raise` | `state.get` | location |
| `cx.state(s).at(sel)`, `.final_value()` | `state.at`, `state.final` | location or styles |
| `cx.query(sel : Selector[W]) -> Array[W] raise` | `query` | location or styles; `sel` cast by `LocatableSelector` |
| `cx.measure(body, width?, height?) -> Size raise` | `measure` | styles **and** location |
| `cx.styles() -> @library.StyleChain raise` | — (`Context::get_styles`) | styles |

What each callback kind receives is the engine's choice:

| Callback | Context passed by the engine | Source |
|---|---|---|
| `Context() <| cx => ..` | location and styles | `context_rule` |
| `Show(sel) <| (it, cx) => ..` | styles; a location only if the matched element has one | `visit_show_rules` |
| `Numbering::func() <| (numbers, cx) => ..` | the context of the caller that applies the numbering (`Numbering::apply`): for `counter.display` the calling context | `library/numbering.mbt` |
| `Supplement::func() <| (it, cx) => ..` | **styles only** (`Context::new(styles~)`) | `Supplement::resolve` |
| `Cells() <| (x, y) => ..` | styles only; the callback receives no `Ctx` | `library/grid.mbt` |

A missing capability raises Typst's `can only be used when context is
known` at the operation's call site (the operations are
`#callsite(autofill(loc))` methods, so the span is the `cx.query(...)`
call). Tests cover each row of both tables.

Callback signatures are fallible and may raise any error:
`(W, Ctx) -> &IntoContent raise` (show), `(Ctx) -> &IntoContent raise`
(context), `(Array[Int64], Ctx) -> &IntoContent raise` (numbering),
`(ContentView, Ctx) -> &IntoContent raise` (supplement),
`(Int, Int) -> T raise` (cells). `SourceError`s pass through; any other
error becomes an error diagnostic at the callback's origin with the error's
`to_string()` as message.

### 10.2 Counters and state

```moonbit
pub fn Counter::page() -> Counter
pub fn[W] Counter::of(sel : Selector[W]) -> Counter        // counter(heading), counter(figure.where(..))
pub fn Counter::named(key : String) -> Counter
pub fn CounterStep::CounterStep(counter : Counter, level? : Int64, ...) -> CounterStep
pub fn CounterUpdate::CounterUpdate(counter : Counter, values : Array[Int64], ...) -> CounterUpdate
// phase 2
pub fn CounterUpdate::func(counter : Counter, ..., f : (Array[Int64]) -> Array[Int64] raise) -> CounterUpdate
pub fn State::State(key : String, init : Value) -> State
pub fn StateUpdate::StateUpdate(state : State, value : Value, ...) -> StateUpdate
pub fn StateUpdate::func(state : State, ..., f : (Value) -> Value raise) -> StateUpdate
```

Updates are content placed in the document, as in Typst; there is no
captured mutation. They lower to `counter(key).step(level: n)`,
`counter(key).update(values)` (one value or an array for multi-level
counters), `counter(key).update(host)` and `state(key, init).update(..)`.
A state always carries its initial value; reading it gives a `Value`.
Phase 1 implements counters (`Counter`, `CounterStep`, `CounterUpdate`
with values); state and functional updates are phase 2.

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
- **Fingerprint**: a discriminant, the `key` and the function span. It
  sets `fingerprint_identity`, like closures do, and the new flag
  `fingerprint_host`, which lets the recorder find results that hold host
  functions (11.4).

### 11.2 Identity

A callback description gets a process-wide serial number when it is
constructed. A session maps serial → `HostFunc`, so **each callback
description is one host function per compilation**, wherever and however
often it is lowered (initially or inside callback results), like a Typst
closure value used in several places. Its `key` is
`hash128("edsl-host", origin, rank)`, where `rank` counts the host functions
of the session in order of first lowering: unique within the compilation and
reproducible across runs (it does not depend on the serial).

A description can still occur several times (the same `Context` value
under two `Keyed` wrappers). Each occurrence wraps the one host function in
a function value with the occurrence's own span, and the engine passes a
function's span back as the span of the call's arguments
(`Func::call_values`). An invocation therefore knows the occurrence it runs
for: its span and key path are those of that occurrence, for the origins of
the content it returns and for its diagnostics. A call from elsewhere (Typst
code in a snippet) runs for the occurrence lowered first.

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

`IntrospectionRecorder::validate` compares, for every recorded read, the
fingerprint of the recorded result with the fingerprint of the result on
the new introspector. A fingerprint cannot express identity: for a host
function it writes the `key`. The recorder therefore also validates host
functions **by identity** (`library/introspector.mbt`,
`library/utils_hash.mbt`, `library/value_hash.mbt`):

```moonbit
priv struct RecordedRead {
  name : String
  expected : U128                 // fingerprint of the result
  replay : (Introspector) -> U128
  hosts : Array[HostFunc]?        // new: the host functions in the result
}
```

- A fingerprint computation can **collect the host functions it visits**:
  `fingerprint_hosts_in(f)` runs `f` and returns them in visiting order
  (the `Host` branch of `Fingerprint for Func` pushes the function into an
  active collector). Content caches the fingerprint of its fields together
  with the fingerprint flags; a new flag, `fingerprint_host`, marks cached
  fingerprints that visited a host function, and a collector recomputes
  exactly those instead of using the cache, so it sees every host function
  **that the fingerprint traversal visits** without re-hashing anything
  else. The traversal is the fingerprint's own: where a fingerprint does
  not descend (the frames of a tiling, the other lossy cases below), it
  visits neither Typst closures nor host functions, and such a result keeps
  its existing lossy validation.
- `Introspector::record` computes the result's fingerprint as before; if
  its flags contain `fingerprint_host`, it stores the collected host
  functions with the read. Nothing changes for the 16 read methods
  themselves.
- `validate`: for a read without host functions, `replay(i) == expected`,
  as before. For a read with host functions, the fingerprint of the
  replayed result is computed in a collector — of the result only, as when
  the read was recorded: computing the result may fingerprint other values
  (a query hashes its selector, which can hold host functions too), and
  those are not collected (`hash128_output`) — and the read validates iff
  the fingerprints are equal **and**
  the same number of host functions was visited **and** they are pairwise
  the same `HostFunc` objects. The two computations fingerprint values
  with equal fingerprints by the same traversal, so the lists correspond
  position by position.
- A **stable query containing host functions converges**: under the
  creation rule (11.2) the content in both introspectors holds the same
  `HostFunc` objects. Two different host functions visited by the
  fingerprint never validate against each other, also if a host gave them
  the same key (a tested case). Typst closures created during layout are
  validated by their structural fingerprint where the traversal visits
  them, as before and as upstream's hash-based validation does.
- **Termination and cost**: validation performs exactly the fingerprint
  computations it performed before, on the same values; the collector adds
  no traversal of its own. Reads without host functions are untouched.
- **Agreement with the non-convergence analysis**
  (`library/convergence.mbt`), which compares the fingerprints of
  inquiry outputs: with distinct keys for distinct host functions — which
  the EDSL guarantees by construction (11.2: one key per host function of a
  session, from its rank) — equal fingerprints imply the same host
  functions, so identity validation and the fingerprint-based history agree.
  The identity check is the engine's enforcement of that contract of
  `HostFunc::new`, not a second notion of convergence.

**Not changed, deliberately: lossy fingerprints.** Some engine values are
fingerprinted through a rounded repr or partially (gradients, tilings,
strokes, the contents of modules bound in a scope; `mark_fingerprint_lossy`).
Two such values can have equal fingerprints, and a recorded result
differing only there validates — in the convergence loop and in the
non-convergence analysis alike. That is the port's existing behaviour for
every Typst document and is independent of host functions. Revisions 3 to 6
tried to tighten it inside validation (exact comparison of flagged results);
reviews 3 to 6 showed that this cannot be done piecemeal: each comparison
rule opened another path (closure captures, nested modules, resolved grids,
tiling frames with their own closures, the separate fingerprint-based
history). The sound fix is at the source — exact fingerprints for those
value types, which then serve validation, the history analysis and
memoization at once — and it is engine work of its own, outside this
design. One fingerprint defect found on the way is fixed here because it
is a plain bug with a local fix: `Element::fingerprint` wrote the element's
name, which is not unique (`grid.cell` and `table.cell` are both `cell`);
every element now has a unique key (its accessor name, emitted by
`elemgen.py`), which is its fingerprint.

Gate: all differential stages unchanged (section 17). Unit tests
(`library/validate_hosts_wbtest.mbt`, `library/validate_elements_wbtest.mbt`,
`typst/fingerprint_wbtest.mbt`): host functions compare by identity and
fingerprint by key; the collector finds host functions in content, arrays
and closure captures, in order, also through cached content fingerprints,
and does not change fingerprints; a recorded query validates with the same
host function and not with another one, also with an equal key, also when
captured by closures created anew; closures created anew with equal
captures validate; elements with the same name have different
fingerprints, also as recorded query results; no two distinct functions of
the standard library share a fingerprint.

### 11.5 Purity contract and determinism check

Callbacks and custom `IntoContent` implementations may run any number of
times, including zero (memo reuse); results must depend only on their
arguments, the `Ctx` and captured immutable data. Mutating captured state or
engine values and reading external resources are unsupported.

Memoization must not change results, so tests compile with memoization on
and off (`@library.set_layout_memo_enabled`, an engine switch added for
this) and compare. A `check_determinism` helper (phase 2, a debug
heuristic): with a frozen world, compile twice with memoization off and
compare normalized frames (section 16), diagnostics and recorded
introspections; report the origins of callbacks invoked on differing paths
as candidates. It cannot prove purity.

## 12. Provenance

### 12.1 Tiers

1. **Call provenance (always exact)**: every node knows its constructor
   call's `SourceLoc` and argument ranges; every engine span of the session
   resolves to exactly one origin (and, for argument spans, the argument).
2. **Runtime text provenance (engine offset, not claimed exact)**: for a
   glyph of a text node, the origin (exact, tier 1), the occurrence key
   (`Keyed`) and the *engine offset*: the glyph's span offset as the engine
   recorded it. It equals the byte offset in the node's string unless the
   engine preprocessed the text; section 12.4 lists the cases and why no
   exactness is claimed.
3. **Source-character provenance (best effort, needs a source provider)**:
   mapping an offset to a character of the `.mbt` file. Only for a single
   plain string literal argument and only when a source provider supplies
   the file; escapes, interpolation, concatenation and variables report
   tiers 1 and 2 only; ligatures and clusters map to the cluster's range. It
   inherits tier 2's caveat.

### 12.2 The origin registry

Source-site identity and runtime occurrence identity are separate:

- a **site** is a constructor call: its `SourceLoc`, its `ArgsLoc` and the
  constructor name;
- an **origin** is a site plus the key path of the enclosing `Keyed`
  wrappers (`["row-17"]`, usually empty).

A session owns one registry: a map from origin (site location string, key
path; the map's key encodes the path structurally, each key with its
length, so no choice of keys makes two paths collide) to an entry, and the
**origin listing**, a text with one line per entry:

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
- **Pieces.** In markup every expression has a span of its own, and the
  engine relies on it: the key of a located element is the hash of the
  element **including the spans** of it and of its children (upstream
  `Hash for RawContent`, `typst-realize`'s `prepare`), so two paragraphs
  with the same words are different elements, while two elements that are
  equal including their spans — one expression laid out twice — share
  their key and are told apart by their order (`SplitLocator`; measurement
  finds an element by its key, `Introspector::locator`). Diagnostics are
  deduplicated by span and message. What has no location of its own inside
  a located argument would all have the span of that argument: the plain
  strings and values in the array of `Seq`/`Document`, the text runs,
  quotes and paragraph breaks of `Prose`, the quotes of `Quoted`, the
  arguments that share a location (the arguments of a generic call, the
  entries of a variadic array or of `extra`), and the arguments of call
  values (`Value::call(..)`), at any depth. Lowering gives each of these
  **pieces** a span of its own from one counter per argument (`Pieces` in
  `doc/lower.mbt`): the k-th is the **sub-range** that ends `k` bytes
  before the end of the argument's token (or of the call's line, for
  arguments without a location), which resolves to the same origin and
  argument (`Origins::resolve` accepts any sub-range of a token). One
  counter serves everything below the argument, so the spans are distinct
  however the pieces are nested, and lowering the same description again
  gives the same spans. The first argument of a call value has the span
  of the call; the operands of an operator and the items of an array or
  dictionary value have the span of the value. When the sub-ranges run out
  (after as many pieces as the token has bytes, some 40 to 90), the next
  ones are the sub-ranges of the same argument in a **further occurrence**
  of the origin: an entry under the keys of the origin plus a key that
  starts with the noncharacter U+FDD2, one more line of the listing per
  block of pieces, however long the text. No `Keyed` key can name such an
  occurrence (a key that starts with U+FDD2 is an error), and `Origins`
  does not report these keys: the pieces of all blocks resolve to the one
  origin. The spans of a further occurrence are bytes of another line
  than the call, so for trace-point suppression they count as the first
  byte of the argument (or line) of the origin itself
  (`Lowering::trace_range`): a later piece is inside every earlier one and
  inside the call's line, in every block, so an error at any argument is
  inside its call, the arguments of a call value, which are taken after
  the call's own span, are inside that, and no span of another line
  contains them. The values of a `Markup`/`Equation` scope and the
  selector and transformation values of a show rule are located arguments
  in this sense (the scope values share the call's line).
  **Under `Keyed`.** A plain string or value inside `Keyed(key, ..)` is
  a piece of the enclosing argument under the keys: of the argument's
  token (or line) in the origin's occurrence under the keys. The pieces
  of an argument under one path of keys have a counter of their own
  (`Lowering::keyed`): the first body is that token itself, a second body
  under the same keys — another cell of a row whose cells have the row's
  key — is the next piece, and what is inside a body takes further
  pieces from that counter. The counters of an argument's key paths are
  in one table of that argument, so a path is one counter however the
  wrappers that spell it are nested (also inside a call value under a
  key). So two bodies under one key are never equal including their
  spans, like two strings without a key.
  **Reuse.** A description with a site of its own that is used twice
  (`let e = Emph("x")`, `Seq([e, e])`) has the spans of its site in both
  places, like the expression of a function that is called twice
  (`#let e() = emph[x]`, `#e()#e()`): equal elements with equal spans,
  which share their key. What has no location of its own has no identity
  either: a string or a value (`let v = Value::call("grid", ..)`) that is
  used in two places — two children of a sequence, two scope bindings,
  two arguments — is lowered in each place and is a piece in each place,
  like the expression written twice (descriptions are deferred
  computations, lowered where they are used). One scope binding that the
  source uses twice (`Markup("#a #a", scope=[("a", v)])`) is one value
  used twice by Typst.
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
constructor name, the key path and the argument index. Spans of snippet
files resolve to the `Markup`/`Equation` origin plus the byte range inside
the snippet. Spans of other files (Typst sources imported by `Markup`, data
files) are not origins; reports resolve them as file locations (section
14.2). Detached spans (shapes the engine generates) have no origin;
previews fall back to the nearest enclosing tagged element (phase 3).

The IDE adaptation (finding 16): upstream `jump_from_click` looks the span
up in a parsed Typst source (`source.find(span)`), which an origin listing
cannot satisfy. The EDSL does not use that path: a click or region resolves
glyph spans with `Origins::resolve`, which needs no syntax tree.

### 12.4 Text offsets

`Origins::resolve_glyph(span, span_offset) -> TextOrigin?` returns the
glyph's origin and its **engine offset**. The offset is what the engine
stores per glyph: the byte offset of the glyph's cluster within the text
run that paragraph collection built for the glyph's text element. It is the
offset in the node's string only if nothing changed the text on the way, and
several things can (review-3, issue C):

- paragraph collection prepends a directional embedding character when a
  run's direction differs from the paragraph's and applies case mapping
  (`collect_inline`, `layout/inline_collect.mbt`), shifting or remapping
  offsets;
- a text or regex show rule slices a text element; the slices keep the
  span but their offsets restart (`slice_textual`, `realize/realize.mbt`);
- raw text adds the `span-offset` style per highlighted piece, which
  shaping adds before saturating at 65,535; collection replaces an offset
  above 65,535 by zero (`layout/inline_shaping.mbt`).

None of this is recorded in a glyph, and it cannot be recovered afterwards:
comparing the node's string at the offset with the cluster's text proves
nothing, because a shifted offset can land on equal text (repeated
characters; `"ŉaA"` upper-cased is `"ʼNAA"`, where the glyph of the source
`a` reports offset 3, at which the source has the unique `A`). Therefore:

- **the EDSL never reports a text offset as exact.** `TextOrigin` has the
  origin (exact) and `engine_offset : Int?`, documented as a hint for
  narrowing within the node's text;
- the offset is `None` where it is known to be unreliable from lowering
  alone: an origin that lowered a string longer than 65,535 UTF-8 bytes —
  as text, as a string value (`Value::str`, the text of `Raw`) or as the
  string result of a call (`Call("lorem", ..)`) — is marked (sticky), and
  its glyphs report no offset;
- exact offsets would need the engine to carry an offset map through
  slicing, embedding and case mapping without changing the laid-out frames.
  That is outside this design; if phase 3 adds it, it is an engine change
  with its own review, and until then tier 3 is a best-effort hint as well.

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

A document that lives elsewhere names its directory:
`Document(children, dir="chapters/intro")` puts the session's virtual files
(the origin listing and the snippets) into that directory of the project,
so relative paths in arguments and in `Markup` fragments resolve as they
would in a Typst file there. Path strings are still passed unchanged. The
directory must be a path inside the project (lowering fails otherwise);
each distinct directory uses its own interned file ids (1 + the snippet
slots in use).

## 13. Escape hatches

```moonbit
pub fn Markup::Markup(source : String, scope? : Array[(String, Value)], loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Markup
pub fn Equation::Equation(source : String, block? : Bool, numbering? : Numbering,
  number_align? : Alignment, supplement? : Supplement, alt? : String,
  scope? : Array[(String, Value)], extra? : Array[(String, Value)], label? : String,
  loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Equation
pub fn Call::Call(path : String, positional? : Array[Value], named? : Array[(String, Value)], label? : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Call
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
  `::dict([(k, v)])`, `::content(c)`, `::label(name)`, `::global(path)`
  (a binding of the global scope, e.g. `"red"`),
  `::call(path, positional?, named?)`, and the typed `::paint`, `::stroke`,
  `::alignment`, `::sizing`. `a.add(b)`, `a.sub(b)`, `a.mul(b)`,
  `a.div(b)` and `a.neg()` are Typst's operators `+`, `-`, `*`, `/` and
  unary `-` on values: they are applied when the value is lowered, the
  left operand first, with Typst's results and error messages (`1pt +
  red` is a stroke, `"a" + 1` fails with `cannot add string and
  integer`). `Value::spread(v)` among the positional
  arguments of a call is Typst's `..v` (the evaluator's rule: an array
  gives positional arguments, a dictionary named ones, `arguments` both,
  `none` nothing, anything else `cannot spread <type>`); anywhere else it
  is a lowering error. A `Value` is also what a view's `field(name)`
  returns, and it is content (`impl IntoContent for Value`): as an
  argument the value itself, in a sequence its display, like `#value` in
  markup. There is deliberately **no constructor from a raw
  `@library.Value` or `@library.Content`** (review-5, issue B): the
  generic hatch is calling Typst functions, which covers everything Typst
  can express, while a host-built engine value could be malformed in ways
  the engine cannot check — the engine's own traversals (fingerprints,
  reprs, equality) assume the finite, acyclic values that Typst evaluation
  produces, and the port's arrays, dictionaries and frames are mutable
  objects.
- **`Call(path, ...)`** calls any public function by its qualified name and
  is content (its displayed result, as `#f(..)` in markup); `Value::call`
  is the same as a value. As in markup, an inserted expression in a
  sequence (`Call`, or a `Value` used as content) whose value is a **label**
  is not displayed but attached to the content before it, with the
  evaluator's rule and warnings (`Seq([Heading("x"), Value::label("h")])` is
  `[#heading[x]#label("h")]`), also when the expression is wrapped in
  `Keyed`, which never changes the lowered content. As an argument, a
  `Value` is the argument itself (`caption=NoneValue()`). **`Set(path, named, positional?)`** is the generic set rule (`set text(8pt, red)` is `Set("text", [], positional=[..])`).
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
pub fn[T : @library.Output] Document::compile(self : Document, world : &@library.World, lints? : Bool = true) -> CompileReport[T]
pub fn Document::compile_paged(self : Document, world : &@library.World, lints? : Bool = true) -> CompileReport[@layout.PagedDocument]
pub fn Document::lower(self : Document, world : &@library.World, lints? : Bool = true) -> CompileReport[@library.Content]   // tests, tools

pub struct CompileReport[T] {
  // private: output : T?, and a resolver for the diagnostics of exports
  errors : Array[Diagnostic]          // empty iff there is an output
  warnings : Array[Diagnostic]        // the engine's
  lints : Array[Lint]                 // the EDSL's (docs/edsl-ports.md, section 6); empty with lints=false
  origins : Origins                   // immutable snapshot
}
pub struct Lint {
  kind : LintKind                     // AdjacentInline (L1); later lints add cases
  message : String
  hints : Array[Hint]
  location : Location?                // the origin as the review loop has it
}
pub fn Lint::render(self : Lint) -> String
pub fn[T] CompileReport::output(self : CompileReport[T]) -> T?
pub fn[T] CompileReport::unwrap(self : CompileReport[T]) -> T raise DocError
pub fn CompileReport::pdf(self : CompileReport[@layout.PagedDocument], options? : @pdf.PdfOptions) -> ExportReport[Bytes]
pub fn CompileReport::svg_pages(self : CompileReport[@layout.PagedDocument], options? : @svg.SvgOptions) -> ExportReport[Array[String]]
pub fn CompileReport::png_pages(self : CompileReport[@layout.PagedDocument], ppi? : Double) -> ExportReport[Array[Bytes]]

pub struct ExportReport[T] {          // same accessors as CompileReport
  errors : Array[Diagnostic]
  warnings : Array[Diagnostic]        // compilation warnings, then export warnings
  origins : Origins
}

pub struct Diagnostic {
  severity : Severity
  message : String
  hints : Array[Hint]                 // { message : String, location : Location? }
  location : Location?
  trace : Array[TracePoint]           // { description : String, location : Location? }
  raw : @library.SourceDiagnostic
}
pub(all) enum Location {
  Edsl(Origin)                        // a constructor call / argument / range of a Markup source
  File(FileLocation)                  // a range of a project or package file
}
pub struct FileLocation {
  path : String                       // within the project or package
  package_spec : String?              // "@namespace/name:version"
  range : (Int, Int)?                 // bytes, if resolvable
  line : Int; column : Int            // one-based, 0 if unknown
}
```

- `compile` creates a session, wraps `world` (section 12.2), runs
  `compile_with` with initial lowering as the evaluation step, deduplicates
  diagnostics like `@typst.compile`, and **freezes the registry** into an
  `Origins` snapshot (listing text, entries, snippet texts). This happens on
  success **and** on failure (N5): a failed compilation returns a report
  with errors, warnings and the origins they refer to.
- **Every location of every diagnostic is resolved when the report is
  built**, while the world is available (review-3, issue D): the
  diagnostic's span, each hint's span (engine hints are located:
  `DiagSpanned[String]`) and each trace point's span become a `Location`:
  - a span of the session's virtual files → `Edsl(origin)` from the
    snapshot;
  - a numbered span of any other file — a Typst source that a `Markup`
    imported or included, whose errors keep their own spans — →
    `File(..)`: the world's parsed source gives the byte range
    (`Source::range`) and its line table the line and column;
  - a raw range span of another file (data files: JSON, YAML, CSV, ...) →
    `File(..)` with that range, and line/column if the file is UTF-8;
  - a detached span → no location.
  A `Diagnostic` is plain data afterwards: it never consults a world, a
  source or the file-id interner again, so a later compilation reusing the
  virtual file ids, or a changed file, cannot change what an old report
  shows. `raw` remains for tools that render with a world of their own.
- An export on a failed compile report returns the same errors without
  exporting. Otherwise it runs the exporter (`@pdf.pdf`, `@svg.svg`,
  `@render.render`) and returns its output or its errors, with
  `warnings = compile warnings ++ export warnings` and the same `Origins`.
  Export diagnostics are resolved in the same way at export time; for that
  the compile report keeps the snapshot and the world it was compiled with
  (private; this is the only use). Reports compose:
  `doc.compile_paged(world).pdf()`.
- Document settings follow Typst's precedence: `SetDocument(...)` and
  format settings from set rules are in the compiled document; explicit
  export options override them (`PdfOptions::resolve`).
- `Diagnostic::render()` gives `error: message` / `  at file:line:col
  (Constructor, argument n)` / hints / trace.
- `Document::lower` returns the lowered engine content (what the compiler
  would lay out) in the same kind of report; the structural twin tests use
  it.
- HTML (`compile[HtmlDocument]`) and bundles compile through their own
  targets with the same session logic (phase 3).

### 14.3 Worlds

`compile` takes any `&@library.World`. The EDSL provides `DocWorld`, a world
built from callbacks (`DocWorld::new(load~, book~, font~, today?)`, with
the standard library), and two ready-made constructions of it:

- `DocWorld::in_memory(files? : Map[String, Bytes], fonts? : Array[Bytes],
  embedded_fonts? : Bool = true, today? : (Int, Int, Int))` in `doc`:
  project files by root-relative path, fonts from bytes plus the embedded
  Typst fonts, a fixed date (or none), the standard library with the PDF,
  SVG and PNG formats. No OS access: for tests and browsers.
- `@system.world(root? : String = ".", embedded_fonts? : Bool = true,
  system_fonts? : Bool = true, font_paths? : Array[String],
  today? : (Int, Int, Int))` in `doc/system`: files under `root` through
  `kit`'s `FsRoot`, packages through `SystemPackages`, fonts through
  `FontStore`, the system date or a fixed one; plus
  `@system.write(path, bytes)`, `write_text` and `read`.

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
| Linear, radial and conic gradients as typed values | 1 | `Paint::linear`/`radial`/`conic`, `Paint::stop` (6.4) |
| Shapes, tilings, curves, colour spaces as typed values | 2 | phase 1 through `Call`/`Value::call` |
| HTML and bundle targets | 3 | `compile_html`, target elements |
| Preview provenance, review packaging | 3 | region → origins |
| Callbacks created during layout | 3 | section 11.2 |

## 16. Equivalence: what "the same as Typst" means

### 16.1 Twins

Each construct is specified against a **functional Typst expression** in a
main file at the project root:

| EDSL | Typst twin |
|---|---|
| `Heading("Intro", level=2)` | `#heading(level: 2)[#"Intro"]` |
| `Block("x", fill=None, width=Auto)` | `#block(fill: none, width: auto)[#"x"]` |
| `Heading("x", extra=[("level", Value::auto())])` | `#heading(level: auto)[#"x"]` |
| `EnumItem("x", extra=[("number", Value::auto())])` | `#enum.item(auto)[#"x"]` |
| `SetEnumItem(extra=[("number", Value::auto())])` | `#set enum.item(auto)` |
| `Figure("x", caption=NoneValue())` | `#figure(caption: none)[#"x"]` |
| `Paint::linear([Red, Blue], angle=Deg(45))` | `gradient.linear(red, blue, angle: 45deg)` |
| `Value::int(3)` as content | `#3` |
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
   (`Document::lower`) equals the evaluated content of the twin
   (`eval_source`) under the **structural dump**, a dumper of the `edsl`
   stage of its own (review-3, issue F; the canonical dump of the `realize`
   stage is not used because it goes through `Content::fields()`, which
   omits internal fields, and prints non-unique element names). It prints,
   recursively, for **every content node its label** (labels are stored
   independently of the element kind, and `Labelled` may label a sequence
   or a styled wrapper; review-4, issue 4) after the node's encoding:
   - a sequence as the list of its children; styled content as its styles
     in order followed by the child; a property as element, field and
     value with its `liftable` flag; a recipe as its selector (repr) and
     transformation (content, function, or styles);
   - any other element as its **identity** — its name plus an index that
     numbers the distinct `Element` handles of the comparison in order of
     first occurrence, shared by both documents, so `grid.cell` and
     `table.cell` differ — followed by **every stored field** by field id
     with its name (the raw storage, including internal and synthesized
     fields);
   - values: content and arrays recursively; functions by repr (a host
     function and the twin's closure both print `(..) => ..`); everything
     else by repr. The text of a raw element is printed as the lines that
     highlighting sees: the evaluator stores the lines of raw syntax, the
     `raw` function a string that is split into lines, and the two are
     the same raw text when the lines are the same (a raw without lines,
     which only markup can write, differs from `raw("")`, which has one
     empty line; `docs/edsl-convert.md`, section 4.8).
   Provenance is normalized by omission: spans of content, styles, recipes
   and functions are not printed. Diagnostics (errors and warnings with
   their hints) must be equal as messages; whether each has a location is
   compared, not the location.
2. **Layout** (behaviour): the paged documents are equal under the
   **frame normalizer**: the `typst-frame-v1` dump of the paged stage with
   (a) every span field replaced by `null` (item spans, glyph spans, format
   option spans), (b) every glyph span offset replaced by `0`, (c)
   locations numbered by first occurrence (the dump already does this, so
   location *relationships* are compared, not hash values), (d) tag content
   through the canonical content dump (functions by repr). Everything else
   — sizes, positions, glyph ids and advances, fonts, paints, images,
   links, tags, page info — is compared bit for bit. The comparison is run
   with memoization on and off (`set_layout_memo_enabled`).
3. **Export**: the SVG text of every page and the PDF bytes (exported with
   the same options and no timestamp) of the two documents are equal, and so
   are the PNG pixmaps of every page (sizes and pixel buffers, rendered with
   the same resolved options) and the report's PNG export, for every twin.

Behavioural tests that have no single twin (callback identity, stale `Ctx`,
creation rule, convergence with host functions in query results, memo on
and off, invalid inputs with their diagnostics) are ordinary tests of the
`doc` package.

## 17. Testing and gates

1. **Twin corpus** (`doc/twins`): pairs of an EDSL builder and a Typst
   source. A new stage of the differential runner, `edsl`
   (`moon run tests/runner --target native -- edsl`), compiles both in the
   same world (rooted at the corpus' assets, embedded fonts only) and
   checks structural, layout and export equivalence; the `doc` package's
   own tests compare a subset through SVG with the in-memory world.
2. **Milestone (phase 1)**: the *reduced showcase* — `bench/showcase.typ`
   without its *Drawing* and *Citations* sections and without the
   system-font line (page setup with a contextual header and page counter,
   title block, outline, text with footnote and font features, grid, lists,
   quote, math with a labelled equation and a reference, a table with
   stroke/fill callbacks inside a figure, JPEG/SVG/PDF images, highlighted
   code with a show rule, a computed table) — written in the EDSL
   (`doc/twins/showcase.mbt`) is layout- and export-equivalent to its
   functional Typst twin, and its PDF is produced through `doc/examples`.
   Every construct it uses is in phase 1 (section 15), including the title
   block's gradient (`Paint::linear`); a value that is not typed yet would
   go through `Value::call`.
   The **full** showcase, with typed graphics and the bibliography, is the
   phase-2 milestone.
3. **Coverage**: phase 1 — every listed element path resolves to the
   element of its constructor, and the generator's report
   (`doc/elements_coverage.txt`) lists the element structs and fields not
   yet typed; phase 2 — a test walks the library's scope tree and fails if
   a public element function or field has neither a typed parameter nor an
   entry in the audited exception list.
4. **Rules**: set-rule folding and order, show identity/wrapping/
   fresh-element recursion, regex selectors, invalid selectors, show-set,
   `show page` warning, misplaced rules (in a variadic array, as a single
   argument).
5. **Callbacks and context**: one host function per description, memo on
   and off, creation rule, stale `Ctx` and derived handles, the capability
   tables of section 10.1 row by row, a query whose results contain host
   functions converges without a warning; in the engine: the validation
   tests of section 11.4.
6. **Provenance**: a glyph resolves to its node's origin; keyed
   occurrences resolve to different origins of one site; callback-made
   nodes resolve; registry lines never move across iterations; long text
   reports no offset; origin and snippet limits; diagnostics of a failed
   compilation — including one inside a file imported by `Markup`, and a
   located hint — keep their locations after another compilation ran.
7. **Examples**: `doc/examples` compiles every example of this document.
8. **Engine gates** for every engine change: all differential stages
   unchanged (syntax/eval/realize 3792, html 508, paged/svg/pdf-semantic/
   render 2299, pdftags 133, bundle 39, wasm-validate 14027, wasm-spec),
   `moon test --target native`, `moon check` on native, wasm-gc and wasm
   without new warnings.

## 18. Phases

1. **Engine**: `compile_with`; `FuncInner::Host`/`HostFunc` with the
   equality, fingerprint and memo rules of section 11; the recorder's
   identity validation of host functions (`fingerprint_hosts_in`,
   `fingerprint_host`); unique element keys as fingerprints
   (`elemgen.py`); `@eval.check_recipe`;
   `set_layout_memo_enabled`; the runner's frame normalizer, structural
   dump and `edsl` stage. **EDSL**: description values, lowering (initial
   and callback results), the audited exceptions, units and value facades,
   `docgen.py` with the phase-1 element list and review notes, rules,
   selectors and views for those elements, `Ctx` (location, counters,
   query, measure, styles), `Markup`/`Equation`/`Call`/`Set`/`Value`, the
   origin registry with located diagnostics and resolution,
   `DocWorld::in_memory`, `doc/system`, PDF/SVG/PNG reports,
   `doc/examples`, the twin corpus and the reduced-showcase milestone.
2. Generator coverage of all public element functions and fields with typed
   views, selectors and enums (coverage test green), state and functional
   updates, bibliography, typed graphics values, the full showcase
   milestone, tier-3 source mapping, `check_determinism`.
3. Preview provenance (region queries, container fallback, review-comment
   packaging), HTML and bundle targets, callbacks created during layout,
   and — only with an engine-side offset map — exact text offsets.

## 19. Resolution index

Review 7 (revision 8):

| Review-7 item | Resolution |
|---|---|
| 1 explicit states of positional scalar fields (MAJOR; review-2 item 7) | 6.1: an `extra` entry naming an optional positional field is passed in the field's positional place and replaces the typed argument, in constructors and set rules; twin `positional-states` (inherited number against explicit `auto`, a set rule with `auto`, `place`), unit test in `doc/states_test.mbt` |
| 2 gradient documentation (MINOR) | 6.4 `Paint::stop`; 6.4, 15 and 17.2 put the three gradient constructors in phase 1 |
| 3 convergence wording (MINOR) | 11.4: identity is guaranteed for host functions visited by the fingerprint traversal; tilings keep their lossy validation; index entry below corrected |

Review 6 (revision 7):

| Review-6 item | Resolution |
|---|---|
| 1 exact validation vs non-convergence analysis (MAJOR) | 11.4: validation no longer goes beyond fingerprints except for host-function identity, which agrees with the fingerprint-based history under the unique-key contract the EDSL guarantees; exactness for lossy fingerprints is withdrawn from this design (it belongs in the fingerprints) |
| 2 tiling equality and closures (MAJOR) | 11.4: no delegated equality is used any more; tiling results keep their existing lossy validation (the fingerprint does not visit their frames), closures elsewhere validate by their structural fingerprint as before |
| 3 stale index entry (MINOR) | this index is rewritten for the narrowed 11.4 |

Earlier reviews, as they stand in revision 8:

| Item | Resolution |
|---|---|
| review-5 A element fingerprints | 11.4: every element has a unique key, which is its fingerprint (kept: a plain fingerprint bug with a local fix); tests for same-named elements and for all library functions |
| review-5 B termination | 11.4, 13: validation adds no traversal beyond the fingerprint computation; the EDSL still admits no host-built engine values (`Value::engine`/`Content::engine` are not public) |
| review-4 1–3, review-3 A (exactness for lossy results: closure captures, nested modules, resolved grids, termination of the exact comparison) | withdrawn with the narrowing of 11.4: these were consequences of making validation exact for lossy fingerprints, which this design no longer does; 11.4 states the unchanged behaviour and why |
| review-4 4, review-3 F structural dump | 16.2: a dumper of its own with element identities, raw stored fields, `liftable`, and the label of every content node |
| review-3 B rules in variadic arrays | 4.2, 8: rules only as direct children of `Document`/`Seq`; a lowering error elsewhere |
| review-3 C text offsets | 12.1, 12.4: the engine offset is a hint, never reported as exact |
| review-3 D diagnostic locations | 14.2: `Location` = `Edsl(Origin)` or `File(FileLocation)`, resolved when the report is built, with located hints and trace points |
| review-3 E context capabilities | 10.1: both tables |
| review-3 G unit leaves | 6.3: `Value::numeric(x, unit)` |

Review 2 (revision 3):

| Review-2 item | Resolution |
|---|---|
| 1 constructor signatures | 7.2: reviewed per-element signature notes, enforced by the generator |
| 2 construction environment | 5.1 initial lowering with `Context::none()`; 5.2 callback-result lowering |
| 3 host identity and convergence | 11.1–11.4: one host function per description, creation rule, identity equality, key fingerprint, memo rules, identity validation in the recorder; stable queries with host functions converge |
| 5 spans | 5.3 span attachment and tracing; 12.2 checked limits and file ids; 12.4 text offsets; 13 snippet slots |
| 6 resources | 12.5: root-anchored synthetic files, strings passed unchanged |
| 7 absent/auto/none/value and integers | 6.1, 6.2: the four states stay expressible for every field, positional ones included (`extra` passes them positionally); since revision 7 a plain value is written plainly and the explicit states by the value family; `Int64` |
| 8 set rules | 8: sequence-tail nesting only in `Document`/`Seq`; `Element::set(..).spanned(..).liftable()` |
| 9 sequences and labels | 4.2: `Seq` preserves nesting (twin `[#a#b]`), `Labelled` on one expression result |
| 10 show-set, recipe checks | 8: `Transformation::Style`, shared `check_recipe` |
| 11 `Ctx` | 10: capability tables, fallible signatures, tokens on derived handles, counter and state types |
| 12 API coherence | facts 3, 5–12; 4.2 `Seq`/`Seq::of`/`Content`; `label` and `extra` in signatures; `Keyed`; `SetRule`; `doc/examples` compiles every example |
| 13 reports | 14.2: `CompileReport`/`ExportReport`, warning propagation, located diagnostics |
| 14 markup and math | 13: mode and scope stored, `Equation` on the math body, snippet files |
| 16 equivalence and phasing | 16.2 structural dump, frame normalizer, export; 17.2 reduced milestone; 12.3 IDE adaptation |
| 17 units | 6.3 |
| N1 callback-made nodes | 5.2, 12.2: append-only, deduplicated, lazily extended registry |
| N2 construction rule | 5.3 audited exceptions; 7.1 constructors for public functions only |
| N3 element identity | 7.1 `Element` handles and qualified names; 13 path resolution |
| N4 mutable nodes | 4.1 opaque values, snapshots, no cycles |
| N5 provenance ownership | 14.2 reports own origins and resolved locations on success and failure |

## 20. Open questions

1. Whether typed views should resolve style-dependent fields eagerly from
   the callback's styles or take `cx` per accessor (the design takes `cx`).
2. Whether `Sides`/`Corners` need shorthand constructors for the common
   uniform case beyond `all=`, and whether scalars deserve typed explicit
   states instead of `extra` (they are rare; `extra` keeps the scalar
   parameters plain).
4. Exact fingerprints for gradients, tilings, strokes and scope-bound
   modules (11.4): separate engine work, which would make convergence
   validation and the non-convergence analysis exact for every Typst
   document.
3. Whether the conservative memo rule for host functions (11.3) should be
   relaxed while the creation rule holds.
