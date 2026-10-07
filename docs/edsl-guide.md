# Writing documents with the EDSL: a guide

What fourteen ports of HTML pages to the EDSL (`docs/edsl-ports.md`) showed
an author needs to know and could not find. It describes the package `doc`
as it is in this repository; it proposes nothing. `docs/edsl-design.md` is
the reference for the API.

Every MoonBit sample below is a function of `doc/examples/guide/guide.mbt`,
named in the line above the sample, and is compiled with the package
(`python3 scripts/edsl_guide_check.py` checks that the samples here are the
text of that file, and the errors of sections 7.2 and 8 the ones their
tests expect, but for their line and column numbers).
What the guide says a sample does is checked by a test of
`doc/examples/guide/guide_test.mbt`; what it says about the findings of the
ports, by `doc/ports_findings_test.mbt`. Section 10 lists which test checks
what, and the few statements that no test can check.

## 1. The prelude

A package that writes documents imports `doc` (and `doc/system` for files,
fonts and the date, `doc/kit` for the elements of section 7, `doc/format`
for numbers as text and for soft breaks) in its `moon.pkg`:

```pkg
import {
  "moonbitlang/typst/doc",
  "moonbitlang/typst/doc/system",
  "moonbitlang/typst/doc/kit",
  "moonbitlang/typst/doc/format",
}
```

and names what it uses once, in one `using` declaration. This is the one of
`guide.mbt`:

```moonbit
using @doc {
  type Document,
  type SetPage,
  type SetText,
  type Heading,
  type Par,
  type Para,
  type Prose,
  type Lit,
  type Seq,
  type Keyed,
  type Emph,
  type Text,
  type Raw,
  type Block,
  type Box,
  type Grid,
  type Table,
  type Rect,
  type Line,
  type Highlight,
  type Outline,
  type Call,
  type Set,
  type Equation,
  type Upper,
  type Layout,
  type Show,
  type ShowSet,
  type Select,
  type Cells,
  type Sides,
  type Stroke,
  type Paint,
  type Length,
  type Sizing,
  type Value,
  type NoneValue,
  type DocWorld,
  trait IntoContent,
}
```

With it a document is written without the `@doc.` prefix (`first_document`):

```moonbit
pub fn first_document() -> Document {
  let ink : Paint = Rgb("#12283f")
  Document([
    SetPage(width=Pt(240), height=Pt(160), margin=Sides(all=Pt(12))),
    SetText(size=Pt(10), fill=ink),
    Heading("Prelude"),
    Par("Enum cases and value constructors need no prefix."),
    Block(
      "A framed block.",
      inset=Sides(all=Pt(6)),
      stroke=Sides(all=Stroke(paint=ink, thickness=Pt(0.5))),
      radius=Corners(all=Pt(3)),
    ),
    Block("No stroke.", stroke=Sides::none()),
  ])
}
```

The rules, as the compiler applies them (moonc v0.10.14):

- `type X` gives the type's name, its constructor `X(..)` and its functions
  `X::f(..)`.
- `IntoContent` is a trait and is listed as `trait IntoContent`. As
  `type IntoContent` it is an error (4099, "is a trait, not a type").
- The declaration holds for the whole package: every file sees the names,
  and a name that is listed in two declarations is an error (4051,
  "declared twice"). Test files ending in `_test.mbt` are a package of their
  own and need their own declaration (or the prefix).
- An element constructor (`Heading`, `Block`, `Grid`, ..) has to be listed:
  it is called where the parameter is `&IntoContent`, which does not say
  which type is meant.
- Enum cases need neither prefix nor listing where the parameter's type is
  the enum: `Pt(10)`, `Rgb("#12283f")`, `Luma(240)`, `Fr(1)`, `Center`,
  `Bold`.
- The same holds for the constructor of a value type where the parameter
  has that type (`Sides(..)`, `Stroke(..)`, `Corners(..)`):
  `Corners(all=Pt(3))` above is found without `Corners` in the list. A type
  that is listed and only used in this way is reported as unused
  (`unused_type_declaration`), and `moon check --deny-warn`, which CI runs,
  makes that an error. List such a type when its name is written (`let ink
  : Paint`, a parameter type) or one of its functions is called: `Sides`
  and `Stroke` are in the list above for `Sides::none()` and
  `Stroke::none()`, `Cells` for `Cells::all(..)`.

A script (a single `.mbtx` file run with `moon run`) has the imports in the
file, with the version of the published package, and then the same
declaration:

```
import {
  "moonbitlang/typst@0.1.4/doc",
  "moonbitlang/typst@0.1.4/doc/system",
}

using @doc {
  type Document,
  trait IntoContent,
}
```

## 2. A paragraph is a `Para`

Text in a sequence is inline content. Two inline items that follow each
other (a `Prose`, a string, a `Text`) are one paragraph with nothing between
them (`run_together`):

```moonbit
pub fn run_together() -> Seq {
  Seq([Prose("The first ends here."), Prose("The second starts here.")])
}
```

is typeset as the one line "The first ends here.The second starts here.".
It compiles without an error or a warning. A paragraph of text is a `Para`
(`paragraphs`):

```moonbit
pub fn paragraphs() -> Seq {
  Seq([
    Heading("Notes"),
    Para("The first ends here."),
    (
      $|The second starts here, with a "quoted" word
      $|and \{Emph("stressed")} ones on its second line.
    )
    |> Para,
    Para("The third is justified.", justify=true),
  ])
}
```

`Para(text, ..)` is a paragraph as it is in Typst source: text between two
paragraph breaks. The text is the text of a `Prose` (white space is
reflowed, `"` and `'` are smart quotes unless `quotes=false`, interpolated
descriptions are the descriptions). A click on a word of it leads to the
text argument of the `Para` call. Two `Para`s are two paragraphs wherever
a paragraph can be (not inside a `Par`), and a blank line in the text of
one is a paragraph break, too.
The options are those of `par` (`justify`, `leading`, `spacing`,
`linebreaks`, `hanging_indent`, and `extra` for the others); they are set
for the paragraphs of the text (`set par(..)`), so they also hold for a
paragraph inside it (a footnote, a box with paragraphs).

A paragraph of a paper has displayed formulas in it. Interpolate them
(`with_display`):

```moonbit
pub fn with_display() -> Seq {
  let indent = Value::dict([
    ("amount", Value::length(Em(1.5))),
    ("all", Value::bool(true)),
  ])
  Seq([
    Set("par", [("first-line-indent", indent)]),
    (
      $|The sum of the first numbers is
      $|\{Equation("sum_(k=1)^n k = (n (n + 1)) / 2", block=true)}
      $|which the next paragraph uses.
    )
    |> Para,
    Para("A new paragraph."),
  ])
}
```

For the engine a block ends the paragraph, and the text after it is a
paragraph of its own. `Para` keeps that text from being indented like a new
paragraph (for a block that the description shows: a formula, a list, a
figure; not for one that a callback or a `Call` makes), so with the indent
above "which the next paragraph uses." starts at the margin and "A new
paragraph." is indented. About first-line indents, which are the engine's:

- with `all: true` every paragraph that starts at the start edge is
  indented, also the first one and the one after a heading (but not the
  first one of a list item);
- without it (`first-line-indent: 1.5em`) a paragraph is indented if it
  follows a paragraph. A `Para` after a `Para` that *ends* with a formula
  follows a block and is not indented; give it the indent by hand
  (`extra=[("first-line-indent", Value::dict([("all", Value::bool(true))]))]`
  keeps the document's amount), or set `all` for the document;
- a `show par: set par(first-line-indent: ..)` of the document wins over
  both the options of a `Para` and what it does after a formula.

A list written as the next item after a `Para` is set off from it like
after a blank line in Typst source; a list that belongs to the paragraph is
interpolated into its text like the formula, where it attaches to the line
before it.

`Par(body)` is the `par` element: one paragraph with its properties as
arguments, for inline content (`Par(Seq(["A chip ", Box(..)]))`). It cannot
hold a block: a displayed formula in `Par(Prose(..))` is dropped with the
warning `block may not occur inside of a paragraph and was ignored`, and a
blank line in that text with `parbreak may not occur ..`. `Prose` is the
text inside something else (a caption, a cell, the body of a `Text`).

Block-level elements between inline items (a heading, a block, a table, a
list) separate them as well; only neighbours that are both inline run
together.

### Lints

What compiles but is probably not what was meant is reported by the EDSL's
lints, in the `lints` of the report (`warnings` are the engine's). Print
them like the warnings (`lints_of`):

```moonbit
pub fn lints_of(document : Document) -> Array[String] {
  let compiled = document.compile_paged(DocWorld::in_memory())
  compiled.lints.map(lint => lint.render())
}
```

For `run_together` it gives:

```text
lint[adjacent-inline]: this text and the text before it are typeset as one paragraph with nothing between them: "…first ends here.The second start…"
  at doc/examples/guide/guide.mbt:70:44 (Prose, argument 1)
  hint: the text before it (doc/examples/guide/guide.mbt:70:14 (Prose, argument 1))
  hint: a paragraph of text is `Para(..)`; pieces of one paragraph go in one `Par(Seq([..]))`
```

This lint (`AdjacentInline`) looks at the arrays of `Document` and `Seq`.
Two `Prose` that follow each other are always reported: a `Prose` drops the
white space at its edges, so there is never anything between them. Other
text next to text (a string, or a `Text`, `Strong`, `Emph` or `Link` around
a string or a `Prose`) is reported if the array also holds a block (a
heading, a table, a `Para`, a `Block`, a spacing, ..): then the array is a
flow of blocks, and the two are probably meant as two paragraphs (the lint
is a heuristic: one paragraph that is composed of several text items
directly between blocks is reported, too; write it as one `Par(Seq([..]))`).
Without a block the array can be the body of one paragraph
(`Par(Seq(["Typeset with ", Emph("care"), "."]))`), so nothing is reported.
The lint does not look into callbacks, `Call` or `Markup`.
`compile_paged(world, lints=false)` turns the lints off. Section 9 has the
other lints, which read the pages.

## 3. Helpers that keep the caller's location

Every constructor records where it was called; that is where a diagnostic
points and what a click on the page leads to. A helper function that builds
an element therefore puts all its uses on one line: its own (`plain_note`):

```moonbit
pub fn plain_note(body : &IntoContent) -> Block {
  Block(body, inset=Sides(all=Pt(6)), fill=Luma(240))
}
```

A helper can pass on the location of its own call instead (`note`):

```moonbit
#callsite(autofill(loc, args_loc))
pub fn note(
  body : &IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Block {
  Block(body, inset=Sides(all=Pt(6)), fill=Luma(240), loc~, args_loc~)
}
```

In `notes`, the text "in the helper" resolves to the line of `plain_note`
that passes `body` to `Block`, and the text "at the call" to its own line
and column in `notes`:

```moonbit
pub fn notes() -> Seq {
  Seq([
    Lit("before"),
    plain_note("in the helper"),
    note("at the call"),
    Lit("after"),
  ])
}
```

What the passed location covers:

- `loc` is the call of the helper, `args_loc` the locations of its
  arguments, one per declared parameter of the helper in the order of the
  declaration. The constructor reads them by position, as the locations of
  its own parameters: if the helper's first parameter is a label and its
  second the body, the text of the body resolves to the label's argument.
  So the helper's leading parameters should be the constructor's: the body
  first, as in `note`.
- Pass both. With `loc~` alone the element is at the call, but its
  arguments are the ones written in the helper, and the text of the body
  resolves to the helper's line.
- Only what the helper passes through is at the call. A constructor that
  the helper wraps around its parameters (a `Seq` of a title and the body,
  a `Strong`) is on the helper's line, and so is the text inside it.
- Pass the location to one constructor. Origins are recorded by location:
  several constructors with one location are one origin, named after the
  one that is lowered first, and the text of the others is reported as an
  argument of that one.
- An error in an argument that the helper supplies itself (a wrong inset)
  is reported at the call of the helper, not inside it.

Rows that a loop builds from data are on one line too, with or without a
helper; `Keyed(key, ..)` tells them apart (section 4.2 of the design).

## 4. Conversions, calls, explicit states and untyped values

### 4.1 `sizing()` and `spacing()`: a `Length` as a `Sizing` or a `Spacing`

`Length`, `Sizing` and `Spacing` are three enums with the same cases, so
`Pt(8)` is accepted wherever one of them is expected. A value that already
is a `Length` (a sum, the result of a function) is not: it is converted
with `.sizing()` or `.spacing()` (`composed_lengths`):

```moonbit
pub fn composed_lengths() -> Seq {
  let narrow : Length = Pct(50) - Pt(10)
  let gap : Length = Pt(11) + Em(0.5)
  let bar = Rect(width=Pct(100), height=Pt(5), fill=Luma(200))
  Seq([
    Grid([bar, bar], columns=[narrow.sizing(), Fr(1)]),
    Block(bar, above=gap.spacing()),
  ])
}
```

A helper that computes sizes can return `Length` and be used for widths
(`Length`), tracks (`.sizing()`) and gaps (`.spacing()`) alike. Both are
the case `Rel(length)` of their enum, which can be written as well.

### 4.2 `Call`: any function of Typst

`Call(path, positional=.., named=..)` calls a function of Typst's standard
library by its name, for what has no constructor; `Value::content(..)`
passes content to it (`roman_numeral`):

```moonbit
pub fn roman_numeral() -> Call {
  Call("numbering", positional=[Value::str("I."), Value::int(4)])
}
```

`Value::call(..)` is the same call as a value, for an argument (4.4).

Text case has constructors, `Upper(body)` and `Lower(body)`, which the
ports did not have and wrote as `Call("upper", ..)` (`upper_case`):

```moonbit
pub fn upper_case() -> Upper {
  Upper(Seq(["quiet ", Emph("words")]))
}
```

The content keeps its structure: the emphasis stays. (`s.to_upper()` on a
MoonBit string is the other way, for plain strings.)

### 4.3 `NoneValue()`: no content

Where a parameter takes content, "none" is not an absent argument (that is
the default) but the value `NoneValue()`: an outline without its title, a
figure without a caption, a page without a header (`untitled_outline`):

```moonbit
pub fn untitled_outline() -> Outline {
  Outline(title=NoneValue())
}
```

`AutoValue()` is `auto` in the same positions. For other parameters the
explicit states are cases or functions of the parameter's type: `fill=None`,
`width=Auto`, `Numbering::none()`, `Stroke::none()`, `Sides::auto()`; the
documentation of each constructor lists them.

### 4.4 `extra` and `Value`: fields and values without a facade

What the ports needed untyped is typed now: the edges of text
(`top_edge`, `bottom_edge` of `Text`, `SetText` and `Highlight`), the
baseline shift of a box (`Box(baseline=..)`), the dash of a stroke (`Dash`:
`Dotted`, `Dashed`, .., `Pattern([Len(Pt(4)), Dot], phase=Pt(0))`) and the
operations on a colour (`transparentize`, `lighten`, `darken`, `mix`,
with percentages as numbers) (`typed_fields`):

```moonbit
pub fn typed_fields() -> Seq {
  let teal : Paint = Rgb("#1d7586")
  Seq([
    Par(Highlight("tight", top_edge=XHeight, bottom_edge=Baseline)),
    Par(Seq(["A chip ", Box("moved down", fill=Luma(230), baseline=Pt(2))])),
    Line(length=Pt(60), stroke=Stroke(dash=Dotted)),
    Rect(width=Pt(20), height=Pt(10), fill=teal.transparentize(50)),
  ])
}
```

`transparentize(50)` scales the alpha the colour has (Typst's meaning); it
does not set it. `a.mix(b, weight=30)` gives `b` 30 percent, in Oklab
unless `space=` says otherwise (`Srgb`, `LinearRgb`, ..).

A field without a typed parameter is set through `extra`, by its Typst name
and with a `Value`; `doc/elements_coverage.txt` lists these fields. The
same way reaches the forms of a field that its typed parameter does not
have (the baseline of a box as an alignment). A dash as any value is
`RawValue(..)`, a paint `Paint::Value(..)` (`untyped_fields`):

```moonbit
pub fn untyped_fields() -> Seq {
  let indent = Value::dict([
    ("amount", Value::length(Em(1))),
    ("all", Value::bool(true)),
  ])
  let half = Value::call("color.transparentize", positional=[
    Value::paint(Rgb("#1d7586")),
    Value::length(Pct(50)),
  ])
  Seq([
    Par("Indented.", extra=[("first-line-indent", indent)]),
    Line(length=Pt(60), stroke=Stroke(dash=RawValue(Value::str("dotted")))),
    Rect(width=Pt(20), height=Pt(10), fill=Paint::Value(half)),
  ])
}
```

These values are checked when the document is compiled, not by the type
checker: a wrong name (`"dots"`, `"descender"` as a top edge) is the
engine's error, located at the argument that holds the value.

Two things about a box in a line, which the ports met when they built
chips:

- An inset keeps the text of the box on the line's baseline and makes the
  line higher by the vertical inset. The vertical padding as an `outset`
  draws the same rectangle and leaves the line as it is.
- `baseline` moves the box down by the given length.

`Chip` of the kit (section 7.3) is the box with its padding divided that
way.

### 4.5 `Layout`: the size of the container

`Layout((size, cx) => ..)` is content that is made when its container is
laid out, from the container's size in points (`half_width`):

```moonbit
pub fn half_width() -> Layout {
  Layout((size, cx) => {
    let label = cx.measure(Block("half", inset=Sides(all=Pt(4))))
    Seq([
      Rect(width=Pt(size.width / 2), height=Pt(label.baseline), fill=Luma(200)),
      Block("half", inset=Sides(all=Pt(4))),
    ])
  })
}
```

- `size` is the width and height of the enclosing container (a block or
  box with that dimension, a grid cell, the page between its margins), not
  the space that is left in it. A dimension that nothing bounds is
  infinite (`size.height.is_inf()`): the height of a page with `height:
  auto`, and both while the content is measured.
- `cx` is the context of a `Context` callback: `cx.measure(body)` gives
  the `width`, the `height` and the `baseline` of content, the distance of
  the first line's baseline from the top. For one line of text with
  Typst's default edges that is its height; for a block with insets, as
  here, it is not.
- It is a callback: section 8 holds for it.

## 5. Fonts

A document can only use the fonts of its world. The embedded ones are
Typst's, Libertinus Serif (the default), New Computer Modern, New Computer
Modern Math and DejaVu Sans Mono, and a sans-serif family of the EDSL's
own: IBM Plex Sans in regular, italic, bold, bold italic and medium
(`weight=Medium`).

The sans-serif family is used by naming it (`sans_report`); headings,
`Strong` and `Emph` are then its own bold and italic:

```moonbit
pub fn sans_report() -> Seq {
  Seq([
    SetText(font=["IBM Plex Sans"]),
    Heading("Build times"),
    Para("Debug: 11 s. Release: \{Emph("eight times")} that."),
  ])
}
```

```text
"Build times" IBMPlexSans-Bold
"Debug: 11 s. Release: " IBMPlexSans-Regular
"eight times" IBMPlexSans-Italic
" that." IBMPlexSans-Regular
```

It is in the world by its name only. For a character that the font of a
text lacks, the engine takes the font of the world that has it and is most
similar to the text's font (not the first one: among equals the family
with the shorter name), so a family that is added to a world takes
characters from the fonts that had them: with IBM Plex Sans, the check
mark, some arrows and currency signs of serif text, for example. The
worlds of `doc` therefore leave it out of that choice. A document that does
not name the family is laid out as if it were not there, which is also
what the Typst command line gives for the same source. To have it for the
characters that the text's font lacks, name it after that font
(`sans_for_symbols`):

```moonbit
pub fn sans_for_symbols() -> SetText {
  SetText(font=["Libertinus Serif", "IBM Plex Sans"])
}
```

The family has Latin, Cyrillic and Greek letters and the punctuation and
symbols of reports (curly quotes, dashes, the ellipsis, ×, −, ±, →, ≤, ≥,
≠, ≈, •, €, ✓) in all of its faces. It lacks ⇒, ▲, ▼, ■, ●, ○, ◆, ★, ✗,
☐ and ☑: in a text set in it they come from the Typst fonts (a serif or
monospaced glyph, not a missing one). Its upright faces are an earlier
release (3.2) than its italics (3.005), with the same metrics; the italics
have 51 characters more, of which a report may have the hyphens U+2010 and
U+2011 (non-breaking): in upright text these two come from Libertinus
Serif.

`@system.world(..)` builds the world from three sources, each of which can
be turned off: the embedded fonts (`embedded_fonts`, default true), the
fonts of the system (`system_fonts`, default true) and the font files below
the directories of `font_paths` (searched recursively). With the system's
fonts the output depends on the machine, and the port that turned them on
measured a run of 39 s instead of 5 s (section 2.5 of the ports document).
For a font that is not embedded, put its files into a directory of the
project and name that directory (`fonts_of`); files of IBM Plex Sans that
a document brings this way are used instead of the embedded ones:

```moonbit
pub fn fonts_of(dir : String) -> DocWorld raise @system.SystemError {
  @system.world(embedded_fonts=false, system_fonts=false, font_paths=[dir])
}
```

(`fonts_of` leaves out the embedded fonts as well, so that its test shows
where the fonts come from; a document normally keeps them.) Without OS
access, `DocWorld::in_memory(fonts=[bytes, ..])` takes the files' bytes.

A family is used by naming it; the list is tried in order
(`font_families`):

```moonbit
pub fn font_families() -> SetText {
  SetText(font=["DejaVu Sans Mono", "Libertinus Serif"])
}
```

What is and is not reported:

- A family that the world does not have is a warning (`unknown font
  family: ..`) at the `font` argument, and the next family of the list is
  used.
- A character that no font of the world covers is no warning of the
  engine: it is set as glyph 0 of a font (the font's mark for a missing
  character, usually an empty box), and `warnings` is empty. It is a lint
  (`MissingGlyph`, section 9). Text in a script the embedded fonts do not
  cover (CJK, for example) needs a font from `font_paths`.
- In a world without any font, each named family is a warning and the text
  is not on the page at all.

## 6. Typst's behaviour that surprised

The engine is a faithful port of Typst, so these stay. Each has a way to
say what is meant.

| Behaviour | What to write |
|---|---|
| An `Auto` column takes the width of its content; several columns of prose do not share the width in proportion | fractions as weights: `columns=[Fr(1), Fr(2)]` |
| `sticky` ties a block to the block after it; a heading and a paragraph under it do not both stay with what follows | the paragraph in a sticky `Block`, or one sticky `Block` around the two |
| `raw` sets its text to 0.8em, and sizes set around it are multiplied with that | a show-set rule on `raw` with an absolute size |
| A stroke that names one side leaves the other sides to the outer value, which for a table is its default stroke | `rest=Stroke::none()`; for a table of data, `DataTable` (section 7.2), which names them |
| Smart quotes: `'` after a digit is a prime | the character `’`, or `quotes=false` |

### 6.1 Columns

(`prose_table`)

```moonbit
pub fn prose_table(columns : Array[Sizing]) -> Table {
  let short = "A short remark."
  let long = "A description that needs several lines of its own in this table."
  Table([short, long], columns~, fill=Cells::all(Luma(240)))
}
```

In a width of 180pt, `prose_table([Auto, Auto])` gives the first column the
74.8pt that its text needs on one line and the second the remaining
105.2pt, where the long text takes three lines. `prose_table([Fr(1),
Fr(2)])` gives 60pt and 120pt whatever the cells hold. Columns that are
narrower than their content and should stay so (a label, a number) are
`Auto`; columns of prose get fractions. (That is why `DataTable`, section
7.2, has no default for its columns.)

### 6.2 Sticky blocks

A heading is sticky: it moves to the next page with the block after it
instead of staying at the foot of the page. A paragraph is not. So in
(`loose_title`)

```moonbit
pub fn loose_title(next : &IntoContent) -> Seq {
  Seq([Heading("Results"), Par("Sorted by name."), next])
}
```

the heading stays with the paragraph, and both stay behind when `next` does
not fit the page. Consecutive sticky blocks are a group, so the paragraph as
a sticky block of its own (`Block("Sorted by name.", sticky=true)`) moves
with `next`, and the heading with it. Or the two are one sticky block
(`kept_title`):

```moonbit
pub fn kept_title(next : &IntoContent) -> Seq {
  Seq([
    Block(Seq([Heading("Results"), Par("Sorted by name.")]), sticky=true),
    next,
  ])
}
```

### 6.3 The size of raw text

In 10pt text `Raw("code")` is 8pt. `Text(Raw("code"), size=Em(0.9))` is
7.2pt, and so is `Text(Raw("code"), size=Pt(9))`: the 0.8em of `raw` applies
to the size that is set around it. A show-set rule on `raw` takes effect
after the 0.8em, so there an absolute size is the size of the raw text
(`code_size`):

```moonbit
pub fn code_size() -> ShowSet {
  ShowSet(Select::raw(), SetText(size=Pt(9)))
}
```

An em size in that rule is multiplied with the 0.8em again (`Em(0.9)` gives
7.2pt in 10pt text).

Raw text is not hyphenated and breaks only where text may break (at a
space), so a long identifier in a narrow table cell runs over the cell's
border. A zero-width space (U+200B) in the string is a place where it may
break; it stays a character of the text. `soft_breaks` of `doc/format`
inserts them (section 7.2).

### 6.4 The sides of a stroke

`Sides(bottom=rule)` as the stroke of a table's cells draws the rule below
each row, and the table's default stroke (1pt, black) on the other sides.
`rest` names them (`ruled_table`):

```moonbit
pub fn ruled_table(cells : Array[&IntoContent]) -> Table {
  let rule = Stroke(thickness=Pt(0.5), paint=Luma(120))
  Table(
    cells,
    columns=[Auto, Auto],
    stroke=Cells::all(Sides(bottom=rule, rest=Stroke::none())),
  )
}
```

A `Grid` has no default stroke, so there `Sides(bottom=rule)` alone draws
only the rules. A table of data with a rule under each row is `DataTable`
(section 7.2): its `stroke` is the rule, and it names the other sides.

`Stroke::none()` is no stroke. `Stroke(paint=None)` is not: the paint of a
stroke cannot be `none`, and compiling it is the error `expected color,
gradient, tiling, or auto, found none`.

### 6.5 Quotes

`Prose` and `Para` turn straight quotes into typographic ones by Typst's
rules: `'` after a letter is an apostrophe, after a digit a prime, so
"#1770's" is set as "#1770′s". Write the apostrophe as the character it is,
or turn the quotes off for that text (`apostrophes`):

```moonbit
pub fn apostrophes() -> Seq {
  Seq([
    Para("Issue #1770’s fix is in."),
    Para("Issue #1770's fix is in.", quotes=false),
  ])
}
```

A plain string (not the text of a `Prose` or `Para`) is never changed.

## 7. The kit: cards, tables of data, chips, drawings

The kit is a package of its own (`moonbitlang/typst/doc/kit`, section 1),
with elements that are made of the ones of `doc`: each is what the ports
wrote by hand in every script, with the choices of section 6 made. An
element says in its documentation what it is made of, and rules of the
document reach those parts as they reach them anywhere.

```moonbit
using @kit {type Cards, type DataTable, type Chip, type Canvas}
```

### 7.1 Cards of equal height

Cards in a row should be equally high. A `Block` does not do that: it is as
high as its own content. Two things that look like the way do something
else, and the engine reports neither:

- a fixed `height` does not grow: content that needs more runs out below
  the block, which a lint reports (`OutsideContainer`, section 9); and a
  block that is split at a page break loses the space at the break, so
  its content can run out although it fits the height, which no lint
  sees;
- `height=Pct(100)` is the height of the region (at the top level of a
  document: the page between its margins), not of the row: every card
  becomes that high, over a page break.

`Cards` does it. The items are the bodies of the cards; the fill, the
stroke and the inset are those of every card (`cards`):

```moonbit
pub fn cards(items : Array[&IntoContent]) -> Cards {
  Cards(
    items,
    gutter=[Pt(8)],
    inset=Sides(all=Pt(8)),
    fill=Luma(245),
    stroke=Sides(all=Stroke(paint=Luma(200), thickness=Pt(0.5))),
  )
}
```

Underneath, the cards are the cells of a grid, and the engine makes the
cells of a row equally high: the look is the cells'.

- The parameters are the grid's and the cell's, with their names and
  types. Without `columns` there is one row of equally wide cards;
  `columns=Sizing::repeat(3, size=Fr(1))` is three to a row, and a last
  row with fewer cards is left open.
- A cell has no radius. With `radius` the cards are rounded blocks, and
  every row is measured first to give its blocks one height
  (`rounded_cards`):

```moonbit
pub fn rounded_cards(items : Array[&IntoContent]) -> Cards {
  Cards(
    items,
    columns=Sizing::repeat(3, size=Fr(1)),
    gutter=[Pt(8)],
    inset=Sides(all=Pt(8)),
    fill=Luma(245),
    radius=Corners(all=Pt(4)),
  )
}
```

- The cards are the same boxes in both forms. They differ at the end of a
  page: the grid breaks a row of cells like any row, and a rounded card is
  not split (its row moves to the next page).
- Measuring needs a callback, so `Cards` with a `radius` cannot be built
  inside a callback (section 8), and its columns cannot be `Auto`.
  Without a `radius` there is neither limit.
- On the page it is one call: a click on a card leads to the `Cards(..)`
  call, a selection in a card to the string or the description that you
  passed as its item.

### 7.2 A table of data

A `Table` takes its cells as one array and starts a new row whenever the
columns are full. A table that is built from data is a loop that pushes
cells, and a row with a cell too few moves every cell after it one column
to the left: the document compiles. Around each table the ports wrote the
same fifty lines: a header that repeats, a rule under each row with the
other sides named (6.4), a function for the alignment of the numbers, a
rounded frame.

`DataTable` takes the head and the rows (`harvest_table`):

```moonbit
pub fn harvest_table(rows : Array[Array[&IntoContent]]) -> DataTable {
  DataTable(
    ["Bed", "Crop", "Harvest (kg)"],
    rows,
    columns=[Auto, Fr(1), Auto],
    align=Cells::columns([Left, Left, Right]),
    stroke=Stroke(thickness=Pt(0.5), paint=Luma(120)),
  )
}
```

- Every row has to fill the columns. One that does not (`short_row`):

```moonbit
pub fn short_row() -> DataTable {
  harvest_table([["North", "Beans", "4.5"], ["South", "12.0"]])
}
```

  is an error when the document is compiled, at the `rows` argument under
  the key of the row:

```text
error: `rows[1]` has cells for 2 columns: this `DataTable` has 3 columns
  at doc/examples/guide/guide.mbt:313:5 (DataTable, argument 2, key "1")
```

  A cell that spans columns or rows is a `TableCell`
  (`TableCell("Both beds", colspan=2)`) and is counted with its spans.
  The count reads what you wrote, not what the engine makes of it: a
  `Markup` is one column for it, and so is a span that a rule of the
  document sets.
- `columns` is required, for the reason of 6.1: fractions for the columns
  of text, `Auto` for the columns of labels, numbers and chips.
- The header is on every page that the table continues on, and a row is
  not split at the end of a page: it moves to the next page as a whole.
  (A row that is higher than a page fits none and leaves it; a table
  whose rows are paragraphs is `breakable=true`.)
- `stroke` is one stroke: the rule under each row. The cells have no other
  line (6.4).
- `inset`, `align` and `fill` are the table's, per cell.
  `Cells::columns([..])` is one value per column: that is how the numbers
  go to the right.

The looks that the ports gave their tables are parameters of the element
or rules of the document (`styled_table`):

```moonbit
pub fn styled_table(rows : Array[Array[&IntoContent]], marked : Int) -> Seq {
  let head = ["Bed", "Crop", "Harvest (kg)"]
  let fill : Cells[Paint] = Cells((_, y) => {
    // Row 0 is the header, row `i + 1` is `rows[i]`.
    if y == 0 {
      Luma(235)
    } else if y == marked + 1 {
      Rgb("#fdf3d7")
    } else {
      None
    }
  })
  Seq([
    SetText(size=Pt(9)),
    ShowSet(Select::table_cell(x=2), SetText(font=["DejaVu Sans Mono"])),
    ShowSet(
      Select::table_cell(y=0),
      SetText(
        font=["Libertinus Serif"],
        size=Pt(7),
        weight=SemiBold,
        fill=Luma(90),
        tracking=Pt(0.3),
      ),
    ),
    DataTable(
      head.map(label => label.to_upper() as &IntoContent),
      rows,
      columns=[Auto, Fr(1), Auto],
      inset=Cells::all(Sides(x=Pt(8), y=Pt(5))),
      align=Cells::columns([Left, Left, Right]),
      fill~,
      stroke=Stroke(thickness=Pt(0.5), paint=Luma(180)),
      radius=Corners(all=Pt(4)),
      frame_fill=White,
    ),
  ])
}
```

- `radius` puts the table in a rounded frame, outlined in `stroke`, that
  clips the fills of the cells at its corners. The table then has no rule
  under its last row, and none under the last row of a page: the frame
  closes the table on every page. (Written by hand, with a rule under
  every row but the table's last, the engine draws the rule under the last
  row of a page on the outline of the frame.)
- `frame_fill` is the surface of a framed table: on a page that is not
  white, the white that the table stands on. It is the fill of the frame,
  beneath its outline, and each part of a table that continues on the next
  page is a filled box. The surface is not the fill of every cell
  (`fill=Cells::all(White)`): the engine paints what is in a clipped block
  after the block's outline, up to the outline's inner edge, and a fill
  there takes some of the outline away in the pixels that the outline
  covers in part. At 110 pixels per inch, the left side of a frame at
  10pt from the edge of the page, outlined with 0.5pt in grey 120 on a
  page in grey 225, has an inner column of pixels of 173 around a filled
  frame and of 187 around filled cells; 5pt to the right, 213 and 240
  (how much depends on where the side falls among the pixels). `fill` is
  for the cells that differ from the surface: here the header and the
  marked row. Without `radius` there is no frame, and
  `frame_fill` is an error.
- The text is not a parameter. Rules before the table reach its cells: a
  `SetText` for the size of the table's text, a show-set rule on the cells
  of row 0 for the header and on the cells of a column for that column.
  Where two match, the later rule wins: the header's rule names the font
  again, so that the header of the numbers is not monospaced.
- The header in small capitals is that rule and `to_upper` on the strings
  of the head: capitals are other characters, not a property of text, and
  a size, a weight, a colour and a tracking are (`SetText`). Every table
  of the documents that were rebuilt with the kit has these five lines,
  each with its own numbers; the element has no parameter for them, as it
  has none for any text.
- A fill that depends on the row is a `Cells` function, as for any table.
  Its row counts the header: row 0 is the header, and row `i + 1` is
  `rows[i]`. It is a callback (section 8): `styled_table` creates one and
  cannot be called inside a callback. `DataTable` creates none.
- A cell of a row resolves to the `rows` argument under the key of its
  row, which is its index. Rows from data that is sorted or filtered keep
  their identity with `key=i => data[i].id`.
- What `Table` has and `DataTable` does not (`rows`, the gutters) is set
  by a `SetTable(..)` before it.

A long word of inline code in a narrow column runs over its cell (6.3).
`soft_breaks` of `doc/format` gives it places to break (`code_cell`):

```moonbit
pub fn code_cell(code : String) -> Raw {
  Raw(@format.soft_breaks(code))
}
```

It inserts a zero-width space after each `_ / . : -`. They are characters
of the text: a reader who copies the name out of the PDF copies them too.

### 7.3 Chips

A status label in a line of text or in a cell is a box. By the two facts
of 4.4, its padding above and below has to be the box's outset: as an
inset it makes the line with the label higher than the others. And a box
is laid out in the width of its line, so a label of two words in a narrow
column is broken inside its box. `Chip` is the box with both settled
(`status`):

```moonbit
pub fn status(label : String, done~ : Bool) -> Text {
  let soft : Paint = if done { Rgb("#dff3e4") } else { Rgb("#fdf3d7") }
  let ink : Paint = if done { Rgb("#1c6b33") } else { Rgb("#8a5a00") }
  Text(
    Chip(label, fill=soft, radius=Corners(all=Pt(8))),
    size=Pt(7),
    weight=SemiBold,
    fill=ink,
  )
}
```

- The label stands on the baseline of its line, and the line is as high
  as without the chip. What is drawn above and below the label needs the
  room there: the leading of the paragraph, the inset of the cell.
- The spaces of the label are no-break spaces, so it is not broken at a
  space. (Only spaces are changed: a label can still be broken after a
  hyphen.) A chip that is wider than its column runs out of it (its box
  is as wide as the column, its text goes on): a column of chips is
  `Auto`.
- The style of the label is a `Text` around the chip. The paddings are in
  em (`inset=Sides(x=Em(0.6))` and `outset=Sides(y=Em(0.3))` unless they
  are given), so they follow that size.
- `fill`, `stroke` and `radius` are the box's; a chip without them is its
  label with room around it.
- `Chip::of(body, ..)` is the same box around content that is not a
  string. The element cannot change the spaces of content: that body can
  be broken.
- It creates no callback, so it can be built anywhere, also in a row of a
  `DataTable` and inside a callback.

### 7.4 A drawing: `Canvas`

A chart or a diagram is content that is placed by coordinates. Every port
with one wrote the same helpers for it: a block of a fixed size, a `Place`
per item, a label that is put on its baseline by a guess at the height of
its letters, a triangle for the head of an arrow. Two of these go wrong
without a diagnostic. A block with a fixed height is split at the end of a
page, and what is placed in it is then drawn from the top of its first
part, over the footnotes and the margin. And the guess (`0.72 × size`) is
not the font's (0.66 for the default one): every label is a little too
high. `Canvas` is the block, which is not split, and its items are the
placed things (`harvest_chart`):

```moonbit
pub fn harvest_chart(beds : Array[(String, Double)], top : Double) -> Layout {
  let grid = Stroke(paint=Luma(200), thickness=Pt(0.5))
  Layout((size, _) => {
    let left = 36.0
    let x = (kilograms : Double) => {
      left + kilograms / top * (size.width - left - 24.0)
    }
    let bottom = beds.length().to_double() * 14.0
    let items : Array[&IntoContent] = []
    for tick in @format.ticks(0.0, top, 6) {
      items.push(Canvas::line((x(tick), 0.0), (x(tick), bottom), stroke=grid))
      items.push(
        Canvas::place(
          (x(tick), bottom + 3.0),
          @format.fixed(tick, 0),
          anchor=(Center, Top),
        ),
      )
    }
    for i, bed in beds {
      let (name, kilograms) = bed
      let middle = i.to_double() * 14.0 + 7.0
      items.push(
        Keyed(
          name,
          Seq([
            Canvas::place((left - 4.0, middle), name, anchor=(Right, Horizon)),
            Canvas::rect(
              (left, middle - 5.0),
              x(kilograms) - left,
              10.0,
              fill=Rgb("#2a78d6"),
            ),
            Canvas::place(
              (x(kilograms) + 3.0, middle),
              @format.fixed(kilograms, 1),
              anchor=(Left, Horizon),
            ),
          ]),
        ),
      )
    }
    Text(Canvas(size.width, bottom + 12.0, items), size=Pt(7))
  })
}
```

- The origin is the top left corner of the canvas, x grows to the right
  and y down, as for `Place`; the unit is the point, and a point is `(x,
  y)`. A y axis that grows upwards is the scale's matter (`y = v => bottom
  - v / top * height`), like every scale: a scale is one line of the
  chart, and `@format.ticks` gives the values of its ticks.
- An item is made by `Canvas::place` (content at a point), `Canvas::line`,
  `Canvas::rect`, `Canvas::circle`, `Canvas::curve` or `Canvas::arrow`.
  Positions and sizes are numbers; `stroke`, `fill` and `radius` are those
  of `Line`, `Rect`, `Circle` and `Curve`, with their types.
- `anchor` says which point of the body is at the point: `(Left | Center
  | Right, Top | Horizon | Bottom)`, `(Left, Top)` unless it is given. The
  engine does the aligning: nothing is measured, and nothing is guessed.
  `Horizon` of a line of text is the middle between the top of its
  capitals and its baseline, which is what centres a label on a bar. A
  line of text ends at its baseline, so `Bottom` puts it on a baseline.
- A canvas has a fixed size. One that is as wide as its container is built
  in a `Layout` (section 4.5), from the width that it gives, as here: the
  canvas and these items create no callback, so they can be built inside
  one. (The ports typed the width of the page in, which is wrong as soon
  as a margin changes.)
- An item is content, and the items are an array of content, drawn in
  their order: several items are one in a `Seq`, and `Keyed(key, ..)`
  gives the items of one row of the data its key. A click on a bar leads to the line of its
  `Canvas::rect`, with the key of its bed: every item is a call of its
  own, not a part of the canvas.
- The style of the labels is a `Text` around the canvas, or around the
  body of a label. A rule is not an item; it goes into a `Seq` with the
  items that it is for.
- What is placed outside the canvas is drawn there. `clip=true` cuts it
  off at the edge, with the half of a stroke that lies on it.
- A drawing in other units (the coordinates of an SVG) is scaled as a
  whole: `Scale(canvas, factor=Pct(56.7), reflow=true)`. That scales its
  strokes and its text too, which a factor on the coordinates does not.
- A canvas that does not fit the rest of the page moves to the next page.
  One that is higher than a page leaves it; a lint reports what of it is
  outside the page (`OutsidePage`, section 9), and what an item draws
  outside of its canvas (`OutsideContainer`).

Boxes and arrows (`year`):

```moonbit
pub fn year() -> Canvas {
  let pen = Stroke(paint=Luma(90), thickness=Pt(0.8))
  let waiting = Stroke(paint=Luma(90), thickness=Pt(0.8), dash=Dashed)
  let stage = (x : Double, name : String) => {
    Seq([
      Canvas::rect(
        (x, 0.0),
        50.0,
        20.0,
        stroke=Sides(all=pen),
        radius=Corners(all=Pt(3)),
      ),
      Canvas::place((x + 25.0, 10.0), name, anchor=(Center, Horizon)),
    ])
  }
  Canvas(180.0, 44.0, [
    stage(0.0, "sow"),
    stage(65.0, "plant"),
    stage(130.0, "harvest"),
    Canvas::arrow((50.0, 10.0), [LineTo((65.0, 10.0))], stroke=pen),
    Canvas::arrow((115.0, 10.0), [LineTo((130.0, 10.0))], stroke=waiting),
    Canvas::arrow(
      (155.0, 20.0),
      [CubicTo((155.0, 42.0), (25.0, 42.0), (25.0, 20.0))],
      stroke=pen,
    ),
  ])
}
```

- An arrow is a path with a head at its end: from its first point through
  its segments, `LineTo(end)`, `QuadTo(control, end)` and `CubicTo(first,
  second, end)` (the components of `Curve`, in the coordinates of the
  canvas). Two `LineTo`s are an arrow with a bend; `Canvas::curve` takes
  the same path without a head.
- The head points where the path arrives: along the last line, or along
  the tangent at the end of a curve. It is a triangle as long and as wide
  as `head` (5.5pt unless it is given), and the path ends inside it. It
  is filled in the paint that the stroke names; for a stroke without a
  paint that is black, so an arrow in a colour says so in its `stroke`.
  A dashed arrow is a dashed stroke.
- A box with its text is a `Canvas::rect` and a `Canvas::place` at its
  centre with the anchor `(Center, Horizon)`.
- There are no nodes with names and no edges that find their way: where a
  box is and where an arrow starts is the caller's arithmetic.

A number and its unit, of two sizes, on one baseline (`number_and_unit`):

```moonbit
pub fn number_and_unit() -> Canvas {
  Canvas(80.0, 24.0, [
    Canvas::place(
      (40.0, 20.0),
      Text("38", size=Pt(20)),
      anchor=(Right, Baseline),
    ),
    Canvas::place((42.0, 20.0), "kg", anchor=(Left, Baseline)),
  ])
}
```

- The anchor `Baseline` puts the first baseline of the body at the point,
  whatever the body is (text with its descenders in its box, a block with
  an inset, several lines). The item measures for it (`Size.baseline`,
  section 4.5), so it creates a callback, and section 8 holds for it: it
  cannot be built inside a callback, and therefore not for a canvas that
  is built in a `Layout` for its width. There, `Bottom` does for a line of
  text, and for anything else the callback measures with its own context
  (`cx.measure(body).baseline`; with `width=Pt(size.width)` for a body
  that is broken into lines in the canvas) and anchors at `Top`.

## 8. Callbacks cannot be created inside a callback

Six constructors take a function that the engine calls during layout:
`Context`, `Layout`, `Show`, `Cells(f)`, `Numbering::func` and
`Supplement::func`.
Each must be created before the document is compiled. One that is created
while a callback runs is an error when it is reached (`stripes_in_show`):

```moonbit
pub fn stripes_in_show() -> Seq {
  Seq([
    Show(Select::heading()) <| ((it, _) => {
      Grid(
        [it, "row 1", "row 2"],
        fill=Cells((_, y) => if y % 2 == 1 { Luma(230) } else { None }),
      )
    }),
    Heading("Striped"),
  ])
}
```

```text
error: callbacks cannot be created inside a callback
  at doc/examples/guide/guide.mbt:481:14 (Cells)
  hint: create the callback before compiling and capture it
  hint: or use the `cx` of the enclosing callback
  while showing heading element at doc/examples/guide/guide.mbt:484:5 (Heading)
```

The location is the callback that came too late. It bites where it is not
visible: a helper that builds a striped table (a `Cells` function) or
measures (`Context`, `Layout`) works at the top level and fails when it is called
from a show rule or from a `Context` callback. An element of the kit that
measures is such a helper, and its documentation says so (`Cards` with a
`radius`, an item of a `Canvas` with the anchor `Baseline`; `Cards`
without a radius, `DataTable`, `Chip`, `Canvas` and its other items create
no callback).
The ways out:

- create the callback once, outside, and capture it (`stripes_captured`):

```moonbit
pub fn stripes_captured() -> Seq {
  let stripes : Cells[Paint] = Cells((_, y) => {
    if y % 2 == 1 {
      Luma(230)
    } else {
      None
    }
  })
  Seq([
    Show(Select::heading()) <| ((it, _) => {
      Grid([it, "row 1", "row 2"], fill=stripes)
    }),
    Heading("Striped"),
  ])
}
```

- where the value does not depend on the cell, use no function:
  `Cells::all(v)` and `Cells::columns([..])` are values and can be built
  anywhere;
- inside a `Context` callback, use the `cx` it was given (`cx.measure(..)`,
  `cx.query(..)`) instead of a nested `Context`. (The `cx` of a `Show`
  callback has what the engine gives a show rule: the styles, and a
  location only if the matched element has one; section 10.1 of the
  design.)

A callback description can be used any number of times, also in the result
of another callback; it is its creation that has to come first.

## 9. Lints: what a report says of a document that compiles

A document that compiles can still be wrong on the page, and the engine
says nothing. The EDSL looks for four such things; what it finds is in the
`lints` of the report (section 2 prints them: `lints_of`), each with its
kind, a message, the place in the source, hints and, for what was found on
a page, the page. `warnings` stay the engine's. `compile_paged(world,
lints=false)` turns all of them off.

One reads the description (section 2: `AdjacentInline`). The other three
read the laid-out pages, so they are in the report of `compile_paged`
only: `lower` and a compilation to another output (`compile` for HTML)
have no pages, and a document with errors has none either. They look at
every glyph of the document once; on a report of 18 pages that took
0.35 ms of a compilation of 70 ms, and on one of 100 pages 3 ms of about 400 ms
(section 10 says what was measured).

**A character that no font has** (`MissingGlyph`). The fonts of the world
are tried in the order of section 5; what none of them has is drawn as the
first font's glyph for a missing character, usually an empty box
(`shipped_card`, with the embedded fonts):

```moonbit
pub fn shipped_card() -> Block {
  Block("Shipped \u{1F680} today", fill=Luma(235), inset=Sides(all=Pt(4)))
}
```

```text
lint[missing-glyph]: no font of this text has a glyph for "🚀" (U+1F680): it is drawn as the missing glyph of Libertinus Serif
  at doc/examples/guide/guide.mbt:519:9 (Block, argument 1)
  on page 1
  hint: use a font that has it: name its family in the `font` of `SetText` or `Text` (with `fallback=false` only those are tried, otherwise every font of the world); a font that is not embedded comes from `font_paths` or from the system's fonts (docs/edsl-guide.md, section 5)
```

- The place is the argument that has the character, the font is the one
  that drew the box. One call and one character are one lint, with a
  count: a table of a hundred rows from one function is one lint that says
  "100 times", under the key of its first row.
- A character that shows nothing is named by its code point (`U+0001`).
  Characters that are ignored by default (a soft hyphen, a joiner, a
  variation selector, a zero width space) are not glyphs at all next to
  text that a font has, and a tab or a line break is none either. Inside
  a run that no font has, the engine draws the box for each of them, and
  each is reported: an emoji of three people joined by U+200D is three
  boxes for the people and two for the joiners.
- In a line of more than 65,535 bytes the pages do not say which character
  a glyph is; the lint then quotes the start of the line.
- Not seen: text in a world without any font (it is not on the page at
  all, and the engine warns only of a family that is named); what a font
  draws for a character that it does have (an empty glyph, a "last
  resort" font's own boxes, and the box that the engine draws for a
  bitmap glyph that it cannot decode).

**Content outside the page** (`OutsidePage`). Text, a shape or an image
that leaves the page by more than a point (`wide_row`, on a page of
200pt):

```moonbit
pub fn wide_row() -> Grid {
  Grid(["Sown", "Planted", "Harvested"], columns=[Pt(90), Pt(90), Pt(90)])
}
```

```text
lint[outside-page]: text leaves the page at the right by 31.7pt
  at doc/examples/guide/guide.mbt:525:8 (Grid, argument 1)
  on page 1
  hint: what is outside the page is cut off: look for a width, a height or an offset that puts it there, a block that cannot break and is higher than the page, a word or a row that is wider
```

- The page is the paper: the margin is on it (a header, a page number, a
  footnote, what is placed there), and so is the bleed of
  `SetPage(bleed=..)`. A background that covers the page is on it; the
  page's fill is not an item at all.
- What counts is what is drawn, since that is what is cut off: of a glyph
  the box of its outline (not its line, which is higher than its
  letters), of a shape its interior and its stroke with its dashes, of
  an image its box; through every rotation and scaling around it. A clip
  around it counts as the box of the clip: what round corners or a
  turned clip cut away beyond that can still be reported. So a full stop
  that hangs over the edge of a justified line is reported on a page
  without a margin, and half of a 4pt stroke on the edge is.
- The side and the amount are those of the farthest item of the call, and
  "(the farthest of 5)" counts its lines or shapes. What the engine drew
  without a source location (the marker of a list item, a decoration) has
  the place of the element that it is part of, and a hint says so; a page
  number that leaves the page has no place, only its page.
- Not seen: what is inside the page but over other content, or past the
  edge of a column or a cell; a glyph that is a bitmap or an SVG document
  only (an emoji of a colour font), which has no outline to measure.

**Content outside a block or box of a fixed size** (`OutsideContainer`).
A `Block` or `Box` that is given a width or a height in absolute units is
that size whatever is in it (section 7.1), and so is what is built from
one, like the `Canvas` of section 7.4 (`labelled_bar`, `low_card`):

```moonbit
pub fn labelled_bar() -> Canvas {
  Canvas(120.0, 16.0, [
    Canvas::rect((0.0, 2.0), 90.0, 12.0, fill=Luma(200)),
    Canvas::place((94.0, 8.0), "1,204 requests", anchor=(Left, Horizon)),
  ])
}
```

```text
lint[outside-container]: text leaves its container (Canvas, 120pt by 16pt) at the right by 30.9pt
  at doc/examples/guide/guide.mbt:534:32 (Canvas::place, argument 2, key "1")
  on page 1
  hint: the container (doc/examples/guide/guide.mbt:532:3 (Canvas))
  hint: a block or box with a size of its own does not grow with its content, and cuts nothing off unless `clip=true`
```

```moonbit
pub fn low_card() -> Block {
  Block(
    "Water the beds in the morning, before the sun is on them.",
    width=Pt(90),
    height=Pt(24),
    fill=Luma(235),
  )
}
```

```text
lint[outside-container]: text leaves its container (Block, 90pt by 24pt) at the bottom by 8.7pt
  at doc/examples/guide/guide.mbt:542:5 (Block, argument 1)
  on page 1
  hint: the container (doc/examples/guide/guide.mbt:541:3 (Block))
  hint: a block or box with a size of its own does not grow with its content, and cuts nothing off unless `clip=true`
```

- The place is what left, the first hint is the container. Only the sides
  that were given count: with a width alone, a word that cannot break is
  found at the right, and the height is the content's.
- Nothing is cut off in a container, so what counts is where content was
  set, as the engine sets it: a glyph between its baseline and the cap
  height (the descenders of the last line are below every block, and a
  card that is as high as its lines has them outside by the engine's
  choice), a shape at its path (a stroke is half outside of what it goes
  around), and a mark that hangs over the end of a line is let hang. What
  the container draws itself (its fill and stroke, with an `outset`) is
  not its content. What is placed outside on purpose is still outside,
  and reported: `clip=true` says that it is meant to be cut.
- A container that is built while the page is laid out (in a `Layout`,
  for a canvas as wide as its column) is seen like any other.
- Not seen: a block that is split at the end of a page (each part is
  lower than the block, so nothing tells that it is that block: `Canvas`
  and the measured `Cards` are not split); a size in per cent or em, or
  from a set rule; a block made by Typst source (`Markup`, `Call`); the
  cells of a grid or a table, `Rect` and the other shapes with a body, a
  column.
- How a block is found on the page: the pages do not record which block
  had its size given, or which frame is the frame of which call. The
  EDSL notes the size of the call and what it lowers inside the call's
  arguments, and takes a frame of that size that holds such content for
  the block's. So a container is not seen if nothing in it tells: if it
  is empty, or if all that is in it is also used outside of it (one
  `label` value, or the calls of one helper function, in two different
  charts say nothing of either chart; in two charts that one function
  builds they do). And an element that gives its block a fill and also
  draws shapes of its own in it has them taken for the fill.

## 10. What is checked where

`G` is `doc/examples/guide/guide_test.mbt`, `F` is
`doc/ports_findings_test.mbt`.

| Statement | Test |
|---|---|
| The samples compile, and all but `stripes_in_show` without errors or warnings | G "the samples compile to PDF without warnings" |
| 2: inline items run together, `Para` separates; the lint, where it reports and where not; a blank line in a `Para`; a displayed formula in a `Para` and in a `Par` | G "section 2: ..", F "S1: .." |
| 2: what the engine does with paragraphs, blocks and first-line indents; `Para` is typeset like `Par(Prose(..))` where there is no block; a click leads to its text argument | `doc/para_test.mbt` (the "engine: .." tests first); with the source file, `doc/examples/review` "source characters: the text of a Para .." |
| 2: what the lint takes for text and for a block | `doc/lint_test.mbt`, `doc/lint_wbtest.mbt` |
| 3: `note` at the call, `plain_note` in the helper | G "section 3: a helper with `#callsite` .." |
| 3: the five rules about what the location covers | G "section 3: what the location of a helper covers" |
| 4.1 to 4.5 | G "section 4: ..", F "T1: .." to "T7: ..", "T9: ..", "T11: .." |
| 4.4: errors of untyped values and their locations | F "T2: ..", "T3: .." |
| 5: `font_paths`, an unknown family, a world without fonts | G "section 5: fonts come from the world" |
| 5: the sans-serif family by its name, its faces, a document that does not name it, the family after the text's font | G "section 5: the embedded sans-serif family" |
| 5: the family's files and releases, its entries in the two worlds, that a document which does not name it has the SVG and the PDF of a world without it, what it covers and lacks, the caller's files of the family | `doc/sans_test.mbt`, `doc/system/system_test.mbt` |
| 5: a character without a glyph is no warning, and a lint | F "S4: .." |
| 6.1 to 6.5 | G the five "section 6: .." tests, F "S5: ..", "S6: ..", "T10: .." |
| 7.1: `Cards` in both forms, blocks are not equally high; fixed and relative heights | G "section 7: the cards ..", `doc/kit/cards_test.mbt`, F "S2a: ..", "S2b: ..", "S3: .." |
| 7.2: the rows of a `DataTable` and their check, its lines, the header and the rows over pages; the frame and its surface (in pixels: `doc/kit/data_table_test.mbt`, "the surface of a frame"), the fills and the rules for its text; soft breaks in a cell | G "section 7: a table of data ..", "section 7: the looks ..", "section 7: inline code ..", `doc/kit/data_table_test.mbt`, F "S5: .." |
| 7.3: a `Chip` on the baseline of its line, the height of the line, one line in a narrow column | G "section 7: a chip ..", `doc/kit/chip_test.mbt`, F "T1: .." |
| 7.4: a `Canvas` as wide as its container, its labels at their anchors, a click on a bar; arrows, labels on one baseline, the anchor that measures | G "section 7: a chart on a canvas ..", "section 7: arrows on a canvas ..", `doc/kit/canvas_test.mbt`, F "S2a: ..", "T11: .." |
| 8: the error, its hints and location, and the captured callback | G "section 8: .." |
| 9: the three lints of the pages on the samples, and that they are off with `lints=false` and without pages | G "section 9: .." |
| 9: what each lint of the pages reports and does not (the characters that are no glyphs, the bleed and the margin, what is turned, scaled and clipped, the sides of a container, what hangs, a block that is split), and what the engine's frames say of a block | `doc/lint_frames_test.mbt` (the "engine: .." test), `doc/lint_frames_wbtest.mbt`, F "S2a: ..", "S2b: ..", "S4: .." |

Not checked by a test of this repository:

- the compiler's errors and warnings of section 1 (4099, 4051,
  `unused_type_declaration`): a test cannot contain code that does not
  compile. They were observed with moonc v0.10.14.
- the script form of section 1: a script names a published version of the
  package. It was run by hand against `moonbitlang/typst@0.1.4`, where the
  declaration, `trait IntoContent` and a `#callsite` helper behave as in a
  package.
- the 39 s of section 5, which is the ports' measurement.
- the times of section 9: a release build, the in-memory world, a
  synthetic report of headings, paragraphs, tables, cards of a fixed size
  and drawings (30,536 and 174,092 glyphs, two call sites of containers);
  the lints of the pages were timed alone, over 20 runs. A document whose
  content is mostly outside of something is slower: what leaves is
  measured exactly.
