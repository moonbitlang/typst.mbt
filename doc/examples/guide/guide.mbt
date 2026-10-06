// The samples of docs/edsl-guide.md as compiled code. The section numbers
// refer to that document; `guide_test.mbt` checks what the guide says about
// each sample. `python3 scripts/edsl_guide_check.py` checks that every
// sample of the guide is in this file.

///|
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

///|
/// Section 1: a document written with the prelude.
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

///|
/// Section 2: two inline items in a sequence are one paragraph.
pub fn run_together() -> Seq {
  Seq([
    Heading("Notes"),
    Prose("The first ends here."),
    Prose("The second starts here."),
  ])
}

///|
/// Section 2: a paragraph each.
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

///|
/// Section 2: what the lints say of a document.
pub fn lints_of(document : Document) -> Array[String] {
  let compiled = document.compile_paged(DocWorld::in_memory())
  compiled.lints.map(lint => lint.render())
}

///|
/// Section 3: a helper. What it builds is on its own lines.
pub fn plain_note(body : &IntoContent) -> Block {
  Block(body, inset=Sides(all=Pt(6)), fill=Luma(240))
}

///|
/// Section 3: a helper whose block is on the line of its caller.
#callsite(autofill(loc, args_loc))
pub fn note(
  body : &IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Block {
  Block(body, inset=Sides(all=Pt(6)), fill=Luma(240), loc~, args_loc~)
}

///|
/// Section 3: both helpers between two texts with locations of their own.
pub fn notes() -> Seq {
  Seq([
    Lit("before"),
    plain_note("in the helper"),
    note("at the call"),
    Lit("after"),
  ])
}

///|
/// Section 4.1: a `Length` where a `Sizing` or a `Spacing` is expected.
pub fn composed_lengths() -> Seq {
  let narrow : Length = Pct(50) - Pt(10)
  let gap : Length = Pt(11) + Em(0.5)
  let bar = Rect(width=Pct(100), height=Pt(5), fill=Luma(200))
  Seq([
    Grid([bar, bar], columns=[Rel(narrow), Fr(1)]),
    Block(bar, above=Rel(gap)),
  ])
}

///|
/// Section 4.2: any Typst function by its name.
pub fn upper_case() -> Call {
  Call("upper", positional=[Value::content(Seq(["quiet ", Emph("words")]))])
}

///|
/// Section 4.3: explicit `none` where content is expected.
pub fn untitled_outline() -> Outline {
  Outline(title=NoneValue())
}

///|
/// Section 4.4: fields without a typed parameter, and values the facades
/// do not cover.
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

///|
/// Section 5: a world whose fonts are the files of one directory: nothing
/// embedded, nothing of the system.
pub fn fonts_of(dir : String) -> DocWorld raise @system.SystemError {
  @system.world(embedded_fonts=false, system_fonts=false, font_paths=[dir])
}

///|
/// Section 5: the families to use, in the order of preference.
pub fn font_families() -> SetText {
  SetText(font=["DejaVu Sans Mono", "Libertinus Serif"])
}

///|
/// Section 6, columns: a table with two columns of prose.
pub fn prose_table(columns : Array[Sizing]) -> Table {
  let short = "A short remark."
  let long = "A description that needs several lines of its own in this table."
  Table([short, long], columns~, fill=Cells::all(Luma(240)))
}

///|
/// Section 6, sticky: a heading and a line under it, then the block they
/// belong to.
pub fn loose_title(next : &IntoContent) -> Seq {
  Seq([Heading("Results"), Par("Sorted by name."), next])
}

///|
/// Section 6, sticky: the two as one sticky block.
pub fn kept_title(next : &IntoContent) -> Seq {
  Seq([
    Block(Seq([Heading("Results"), Par("Sorted by name.")]), sticky=true),
    next,
  ])
}

///|
/// Section 6, raw: the size of code, set once and as an absolute length.
pub fn code_size() -> ShowSet {
  ShowSet(Select::raw(), SetText(size=Pt(9)))
}

///|
/// Section 6, strokes: a rule below each row and nothing else.
pub fn ruled_table(cells : Array[&IntoContent]) -> Table {
  let rule = Stroke(thickness=Pt(0.5), paint=Luma(120))
  Table(
    cells,
    columns=[Auto, Auto],
    stroke=Cells::all(Sides(bottom=rule, rest=Stroke::none())),
  )
}

///|
/// Section 6, quotes: the apostrophe as the character it is, or no smart
/// quotes at all.
pub fn apostrophes() -> Seq {
  Seq([
    Para("Issue #1770’s fix is in."),
    Para("Issue #1770's fix is in.", quotes=false),
  ])
}

///|
/// Section 7: cards of one row are equally high: the cells of the grid
/// carry the fill, the stroke and the inset.
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

///|
/// Section 8: a callback that is created inside a callback. Compiling it
/// is an error.
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

///|
/// Section 8: the callback created before compiling, and captured.
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

///|
/// All samples that compile, as one document.
pub fn guide() -> Document {
  Document([
    SetPage(width=Pt(360), height=Pt(480), margin=Sides(all=Pt(24))),
    SetText(size=Pt(10)),
    code_size(),
    run_together(),
    paragraphs(),
    notes(),
    composed_lengths(),
    upper_case(),
    untitled_outline(),
    untyped_fields(),
    prose_table([Fr(1), Fr(2)]),
    loose_title(ruled_table(["a", "b", "c", "d"])),
    kept_title(cards(["One.", "Two, with more text than the first card has."])),
    apostrophes(),
    stripes_captured(),
  ])
}
