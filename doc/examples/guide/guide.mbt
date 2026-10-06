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
  Seq([Prose("The first ends here."), Prose("The second starts here.")])
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
/// Section 2: a paragraph with a displayed formula in it. Every paragraph
/// of the page is indented; the text after the formula is not.
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
    Grid([bar, bar], columns=[narrow.sizing(), Fr(1)]),
    Block(bar, above=gap.spacing()),
  ])
}

///|
/// Section 4.2: any Typst function by its name.
pub fn roman_numeral() -> Call {
  Call("numbering", positional=[Value::str("I."), Value::int(4)])
}

///|
/// Section 4.2: text case has constructors.
pub fn upper_case() -> Upper {
  Upper(Seq(["quiet ", Emph("words")]))
}

///|
/// Section 4.3: explicit `none` where content is expected.
pub fn untitled_outline() -> Outline {
  Outline(title=NoneValue())
}

///|
/// Section 4.4: what the ports wrote untyped has typed forms.
pub fn typed_fields() -> Seq {
  let teal : Paint = Rgb("#1d7586")
  Seq([
    Par(Highlight("tight", top_edge=XHeight, bottom_edge=Baseline)),
    Par(Seq(["A chip ", Box("moved down", fill=Luma(230), baseline=Pt(2))])),
    Line(length=Pt(60), stroke=Stroke(dash=Dotted)),
    Rect(width=Pt(20), height=Pt(10), fill=teal.transparentize(50)),
  ])
}

///|
/// Section 4.4: a field without a typed parameter, and values as the
/// facades take them untyped.
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

///|
/// Section 4.5: content that depends on the size of its container.
pub fn half_width() -> Layout {
  Layout((size, cx) => {
    let label = cx.measure(Block("half", inset=Sides(all=Pt(4))))
    Seq([
      Rect(width=Pt(size.width / 2), height=Pt(label.baseline), fill=Luma(200)),
      Block("half", inset=Sides(all=Pt(4))),
    ])
  })
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
using @kit {type Cards, type DataTable, type Chip, type Canvas}

///|
/// Section 7.1: the cards of one row are equally high.
pub fn cards(items : Array[&IntoContent]) -> Cards {
  Cards(
    items,
    gutter=[Pt(8)],
    inset=Sides(all=Pt(8)),
    fill=Luma(245),
    stroke=Sides(all=Stroke(paint=Luma(200), thickness=Pt(0.5))),
  )
}

///|
/// Section 7.1: with rounded corners, three to a row.
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

///|
/// Section 7.2: a table of data, given by rows.
pub fn harvest_table(rows : Array[Array[&IntoContent]]) -> DataTable {
  DataTable(
    ["Bed", "Crop", "Harvest (kg)"],
    rows,
    columns=[Auto, Fr(1), Auto],
    align=Cells::columns([Left, Left, Right]),
    stroke=Stroke(thickness=Pt(0.5), paint=Luma(120)),
  )
}

///|
/// Section 7.2: a row with a cell too few. Compiling it is an error.
pub fn short_row() -> DataTable {
  harvest_table([["North", "Beans", "4.5"], ["South", "12.0"]])
}

///|
/// Section 7.2: the looks. A frame with its surface, a size for the text,
/// a header in small grey capitals, a font for the numbers, and a tint for
/// the row `marked`.
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

///|
/// Section 7.2: inline code in a cell, which may break after `_ / . : -`.
pub fn code_cell(code : String) -> Raw {
  Raw(@format.soft_breaks(code))
}

///|
/// Section 7.3: a status label.
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

///|
/// Section 7.4: a chart of bars that is as wide as its container. A bed is
/// its name and its kilograms; `top` is the end of the scale.
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

///|
/// Section 7.4: boxes and arrows.
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

///|
/// Section 7.4: a number and its unit, of two sizes, on one baseline.
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
/// Section 9: a card with a character that the embedded fonts do not
/// have.
pub fn shipped_card() -> Block {
  Block("Shipped \u{1F680} today", fill=Luma(235), inset=Sides(all=Pt(4)))
}

///|
/// Section 9: a row that is wider than a page of 200pt.
pub fn wide_row() -> Grid {
  Grid(["Sown", "Planted", "Harvested"], columns=[Pt(90), Pt(90), Pt(90)])
}

///|
/// Section 9: a bar and its label, which needs more room than the drawing
/// has beside the bar.
pub fn labelled_bar() -> Canvas {
  Canvas(120.0, 16.0, [
    Canvas::rect((0.0, 2.0), 90.0, 12.0, fill=Luma(200)),
    Canvas::place((94.0, 8.0), "1,204 requests", anchor=(Left, Horizon)),
  ])
}

///|
/// Section 9: a block of a height that its text does not fit.
pub fn low_card() -> Block {
  Block(
    "Water the beds in the morning, before the sun is on them.",
    width=Pt(90),
    height=Pt(24),
    fill=Luma(235),
  )
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
    with_display(),
    notes(),
    composed_lengths(),
    roman_numeral(),
    upper_case(),
    untitled_outline(),
    typed_fields(),
    untyped_fields(),
    half_width(),
    prose_table([Fr(1), Fr(2)]),
    loose_title(ruled_table(["a", "b", "c", "d"])),
    kept_title(cards(["One.", "Two, with more text than the first card has."])),
    rounded_cards([
      "One.", "Two, with more text than the first card has.", "Three.", "Four.",
    ]),
    harvest_table([["North", "Beans", "4.5"], ["South", "Chard", "12.0"]]),
    styled_table(
      [
        ["North", code_cell("garden_bed_watering_schedule"), "4.5"],
        ["South", status("needs water", done=false), "12.0"],
      ],
      1,
    ),
    apostrophes(),
    harvest_chart([("North", 4.5), ("South", 12.0), ("West", 0.4)], 12.0),
    year(),
    number_and_unit(),
    stripes_captured(),
  ])
}
