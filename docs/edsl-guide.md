# Writing documents with the EDSL: a guide

What fourteen ports of HTML pages to the EDSL (`docs/edsl-ports.md`) showed
an author needs to know and could not find. It describes the package `doc`
as it is in this repository; it proposes nothing. `docs/edsl-design.md` is
the reference for the API.

Every MoonBit sample below is a function of `doc/examples/guide/guide.mbt`,
named in the line above the sample, and is compiled with the package
(`python3 scripts/edsl_guide_check.py` checks that the samples here are the
text of that file, and the error of section 8 the one its test expects, but
for its line and column numbers).
What the guide says a sample does is checked by a test of
`doc/examples/guide/guide_test.mbt`; what it says about the findings of the
ports, by `doc/ports_findings_test.mbt`. Section 9 lists which test checks
what, and the few statements that no test can check.

## 1. The prelude

A package that writes documents imports `doc` (and `doc/system` for files,
fonts and the date) in its `moon.pkg`:

```pkg
import {
  "moonbitlang/typst/doc",
  "moonbitlang/typst/doc/system",
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
  type Prose,
  type Lit,
  type Seq,
  type Emph,
  type Block,
  type Box,
  type Grid,
  type Table,
  type Rect,
  type Line,
  type Highlight,
  type Outline,
  type Call,
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

## 2. A paragraph is a `Par`

Text in a sequence is inline content. Two inline items that follow each
other (a `Prose`, a string, a `Text`) are one paragraph with nothing between
them, and nothing is reported (`run_together`):

```moonbit
pub fn run_together() -> Seq {
  Seq([Prose("The first ends here."), Prose("The second starts here.")])
}
```

is typeset as the one line "The first ends here.The second starts here.".
Each paragraph is a `Par` (`paragraphs`):

```moonbit
pub fn paragraphs() -> Seq {
  Seq([
    Par(Prose("The first ends here.")),
    Par(Prose("The second starts here.")),
  ])
}
```

Block-level elements between inline items (a heading, a block, a table, a
list) separate them as well; only neighbours that are both inline run
together.

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

## 4. Values that have no typed form yet

### 4.1 `Rel`: a `Length` as a `Sizing` or a `Spacing`

`Length`, `Sizing` and `Spacing` are three enums with the same cases, so
`Pt(8)` is accepted wherever one of them is expected. A value that already
is a `Length` (a sum, the result of a function) is not: it is wrapped in
`Rel(..)`, a case of `Sizing` and of `Spacing` (`composed_lengths`):

```moonbit
pub fn composed_lengths() -> Seq {
  let narrow : Length = Pct(50) - Pt(10)
  let gap : Length = Pt(11) + Em(0.5)
  let bar = Rect(width=Pct(100), height=Pt(5), fill=Luma(200))
  Seq([
    Grid([bar, bar], columns=[Rel(narrow), Fr(1)]),
    Block(bar, above=Rel(gap)),
  ])
}
```

A helper that computes sizes can return `Length` and be used for widths
(`Length`), tracks (`Rel(..)`) and gaps (`Rel(..)`) alike.

### 4.2 `Call`: any function of Typst

`Call(path, positional=.., named=..)` calls a function of Typst's standard
library by its name; `Value::content(..)` passes content to it. There is no
`Upper` constructor, but there is `upper` (`upper_case`):

```moonbit
pub fn upper_case() -> Call {
  Call("upper", positional=[Value::content(Seq(["quiet ", Emph("words")]))])
}
```

The content keeps its structure: the emphasis stays. (`s.to_upper()` on a
MoonBit string is the other way, for plain strings.) `Value::call(..)` is
the same call as a value, for an argument (4.4).

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

A field without a typed parameter is set through `extra`, by its Typst name
and with a `Value`. `doc/elements_coverage.txt` lists these fields; the
ports needed `top-edge` and `bottom-edge` (of `text` and `highlight`) and
`baseline` (of `box`). The dash of a `Stroke` is a `Value`, and an operation
on a colour is a call of Typst's function (`untyped_fields`):

```moonbit
pub fn untyped_fields() -> Seq {
  let edges = [
    ("top-edge", Value::str("x-height")),
    ("bottom-edge", Value::str("baseline")),
  ]
  let lowered = [("baseline", Value::length(Pt(2)))]
  let half = Value::call("color.transparentize", positional=[
    Value::paint(Rgb("#1d7586")),
    Value::length(Pct(50)),
  ])
  Seq([
    Par(Highlight("tight", extra=edges)),
    Par(Seq(["A chip ", Box("moved down", fill=Luma(230), extra=lowered)])),
    Line(length=Pt(60), stroke=Stroke(dash=Value::str("dotted"))),
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

## 5. Fonts

A document can only use the fonts of its world. The embedded ones are
Libertinus Serif (the default), New Computer Modern, New Computer Modern
Math and DejaVu Sans Mono: there is no sans-serif family among them.

`@system.world(..)` builds the world from three sources, each of which can
be turned off: the embedded fonts (`embedded_fonts`, default true), the
fonts of the system (`system_fonts`, default true) and the font files below
the directories of `font_paths` (searched recursively). With the system's
fonts the output depends on the machine, and the port that turned them on
measured a run of 39 s instead of 5 s (section 2.5 of the ports document).
For a font that is not embedded, put its files into a directory of the
project and name that directory (`fonts_of`):

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
- A character that no font of the world covers is not reported: it is set
  as glyph 0 of a font (the font's mark for a missing character, usually
  an empty box), and `warnings` is empty. Text in a script the embedded
  fonts do not cover (CJK, for example) needs a font from `font_paths`,
  and only the rendered page shows that it is missing.
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
| A stroke that names one side leaves the other sides to the outer value, which for a table is its default stroke | `rest=Stroke::none()` |
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
`Auto`; columns of prose get fractions.

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
break; it stays a character of the text.

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
only the rules.

`Stroke::none()` is no stroke. `Stroke(paint=None)` is not: the paint of a
stroke cannot be `none`, and compiling it is the error `expected color,
gradient, tiling, or auto, found none`.

### 6.5 Quotes

`Prose` turns straight quotes into typographic ones by Typst's rules: `'`
after a letter is an apostrophe, after a digit a prime, so "#1770's" is set
as "#1770′s". Write the apostrophe as the character it is, or turn the
quotes off for that text (`apostrophes`):

```moonbit
pub fn apostrophes() -> Seq {
  Seq([
    Par(Prose("Issue #1770’s fix is in.")),
    Par(Prose("Issue #1770's fix is in.", quotes=false)),
  ])
}
```

A plain string (not `Prose`) is never changed.

## 7. Cards of equal height

Cards in a row should be equally high. A `Block` does not do that: it is as
high as its own content. Two things that look like the way do something
else, and neither is reported:

- a fixed `height` does not grow: content that needs more runs out below
  the block (and a block that is split at a page break loses the space at
  the break, so its content can run out although it fits the height);
- `height=Pct(100)` is the height of the region (at the top level of a
  document: the page between its margins), not of the row: every card
  becomes that high, over a page break.

The cells of a grid row are equally high. So the grid draws the cards: the
fill, the stroke and the inset are the cells', and the items are plain
content (`cards`):

```moonbit
pub fn cards(items : Array[&IntoContent], columns? : Int = 2) -> Grid {
  Grid(
    items,
    columns=Sizing::repeat(columns, size=Fr(1)),
    gutter=[Pt(8)],
    inset=Cells::all(Sides(all=Pt(8))),
    fill=Cells::all(Luma(245)),
    stroke=Cells::all(Sides(all=Stroke(paint=Luma(200), thickness=Pt(0.5)))),
  )
}
```

A card that differs from the others is a `GridCell(body, fill=.., ..)`
among the items. The corners are square: a cell has no radius.

## 8. Callbacks cannot be created inside a callback

Five constructors take a function that the engine calls during layout:
`Context`, `Show`, `Cells(f)`, `Numbering::func` and `Supplement::func`.
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
  at doc/examples/guide/guide.mbt:234:14 (Cells)
  hint: create the callback before compiling and capture it
  hint: or use the `cx` of the enclosing callback
  while showing heading element at doc/examples/guide/guide.mbt:237:5 (Heading)
```

The location is the callback that came too late. It bites where it is not
visible: a helper that builds a striped table (a `Cells` function) or
measures (`Context`) works at the top level and fails when it is called
from a show rule or from a `Context` callback. The ways out:

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

## 9. What is checked where

`G` is `doc/examples/guide/guide_test.mbt`, `F` is
`doc/ports_findings_test.mbt`.

| Statement | Test |
|---|---|
| The samples compile, and all but `stripes_in_show` without errors or warnings | G "the samples compile to PDF without warnings" |
| 2: inline items run together, `Par` separates | G "section 2: ..", F "S1: .." |
| 3: `note` at the call, `plain_note` in the helper | G "section 3: a helper with `#callsite` .." |
| 3: the five rules about what the location covers | G "section 3: what the location of a helper covers" |
| 4.1 to 4.4 | G "section 4: ..", F "T1: .." to "T4: ..", "T6: ..", "T7: ..", "T9: .." |
| 4.4: errors of untyped values and their locations | F "T2: ..", "T3: .." |
| 5: `font_paths`, an unknown family, a world without fonts | G "section 5: fonts come from the world" |
| 5: a character without a glyph is not reported | F "S4: .." |
| 6.1 to 6.5 | G the five "section 6: .." tests, F "S5: ..", "S6: ..", "T10: .." |
| 7: cells are equally high, blocks are not; fixed and relative heights | G "section 7: ..", F "S2a: ..", "S2b: ..", "S3: .." |
| 8: the error, its hints and location, and the captured callback | G "section 8: .." |

Not checked by a test of this repository:

- the compiler's errors and warnings of section 1 (4099, 4051,
  `unused_type_declaration`): a test cannot contain code that does not
  compile. They were observed with moonc v0.10.14.
- the script form of section 1: a script names a published version of the
  package. It was run by hand against `moonbitlang/typst@0.1.4`, where the
  declaration, `trait IntoContent` and a `#callsite` helper behave as in a
  package.
- the 39 s of section 5, which is the ports' measurement.
