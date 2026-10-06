// The folding plate of Note G: "Diagram for the computation by the Engine
// of the Numbers of Bernoulli", on a landscape sheet of twice the page.
//
// Every cell is the cell of the Wikisource transcription (page 734 of the
// scan, proofread once), also where the transcription differs from what the
// computation asks for: Operation 4 as "2V4 / 2V5", the indices of
// Operations 7, 10, 11, 21 and 23, "= 2 + U = 2" in Operation 8, "n" on V10
// in Operation 7, the shifted cells of Operation 16, "(2n-2)/3" and "A_2" in
// Operations 19, 21 and 22.
//
// The table has 25 columns: the number of the operation, two columns for
// the groups of operations and their braces, the nature of the operation,
// four columns of description, and the 17 columns of the engine.

///|
/// The height of the row of one operation. It is fixed, so that the braces
/// that span rows can be given their size.
let op_height : Double = 24.5

///|
let plate_size : Double = 7.5

///|
let thin : Stroke = Stroke(thickness=Pt(0.4))

///|
/// A cell with a formula in the size of text.
fn mc(source : String) -> &IntoContent {
  if source == "" {
    return ""
  }
  Equation(source)
}

///|
/// A cell with a formula whose fractions are set in full size.
fn md(source : String) -> &IntoContent {
  if source == "" {
    return ""
  }
  Equation("display(\{source})")
}

///|
/// The two changes of indices of an operation, between braces.
fn ind(a : String, b : String, c : String, d : String) -> String {
  "display(mat(delim: #(\"{\", \"}\"), row-gap: #0.1em, \{a} = \{b}; \{c} = \{d}))"
}

///|
/// The row of Operation 19 is higher: it holds a formula of two lines.
let tall_height : Double = 34

///|
/// A left brace over `rows` rows of operations, one of which is the row of
/// Operation 19.
fn brace(rows : Int) -> Equation {
  let size = (rows - 1).to_double() * op_height + tall_height - 5
  Equation("stretch(\\{, size: #\{size}pt)")
}

///|
/// The left brace over Operations 13 to 16, four rows of the common height.
fn first_brace() -> Equation {
  let size = 4.0 * op_height - 5
  Equation("stretch(\\{, size: #\{size}pt)")
}

///|
/// Dots in a column that an operation does not use.
let dots : String = "dots.h"

///|
let dots2 : String = "dots.h dots.h"

///|
/// `n` cells of dots.
fn dotted(n : Int) -> Array[String] {
  Array::make(n, dots)
}

///|
/// The row of one operation: its number, the cells of the group columns
/// that start in this row, the nature of the operation, the four
/// descriptions and the 17 columns (missing ones at the end are empty).
fn op(
  number : Int,
  group : Array[&IntoContent],
  nature : String,
  acted : String,
  receiving : String,
  change : String,
  statement : &IntoContent,
  columns : Array[String],
) -> Array[&IntoContent] {
  let cells : Array[&IntoContent] = [number.to_string(), ..group]
  // Up to Operation 12 the inner group column belongs to the nature of the
  // operation.
  if number <= 12 {
    cells.push(TableCell(mc(nature), colspan=2))
  } else {
    cells.push(mc(nature))
  }
  cells.push(mc(acted))
  cells.push(mc(receiving))
  cells.push(mc(change))
  cells.push(statement)
  for i in 0..<17 {
    let source = if i < columns.length() { columns[i] } else { "" }
    cells.push(md(source))
  }
  cells
}

///|
/// The head of the table: seven rows.
fn plate_head() -> Array[&IntoContent] {
  let upright = (text : String, width : Double) => {
    Rotate(Box(text, width=Pt(width)), angle=Deg(-90), reflow=true)
  }
  let described = (body : &IntoContent) => {
    TableCell(body, rowspan=7, align=Center + Horizon)
  }
  let group = (title : String, span : Int64) => {
    TableCell(title, colspan=span, align=Center + Horizon)
  }
  let decimal = (index : String) => {
    TableCell(
      Rotate(
        Box(
          Text(
            Seq([
              b(index),
              " in a",
              Linebreak(),
              "decimal",
              Linebreak(),
              "fraction.",
            ]),
            size=Pt(6),
          ),
          width=Pt(32),
        ),
        angle=Deg(-90),
        reflow=true,
      ),
      rowspan=3,
      align=Center + Horizon,
    )
  }
  let framed = (source : String) => {
    Block(
      Align(Center + Horizon, mc(source)),
      width=Pct(100),
      height=Pt(11),
      stroke=Sides(all=thin),
    )
  }
  let cells : Array[&IntoContent] = [
    TableCell(
      upright("Number of Operation.", 80),
      colspan=2,
      rowspan=7,
      align=Center + Horizon,
    ),
    TableCell(
      upright("Nature of Operation.", 80),
      colspan=2,
      rowspan=7,
      align=Center + Horizon,
    ),
    described(Seq(["Variables", Linebreak(), "acted", Linebreak(), "upon."])),
    described(
      Seq(["Variables", Linebreak(), "receiving", Linebreak(), "results."]),
    ),
    described(
      Seq([
        "Indication of",
        Linebreak(),
        "change in the",
        Linebreak(),
        "value on any",
        Linebreak(),
        "Variable.",
      ]),
    ),
    described("Statement of Results."),
    group("Data.", 3),
    group("Working Variables.", 10),
    group("Result Variables.", 4),
  ]
  // The columns with the index of the value they hold at the start.
  for column in [1, 2, 3] {
    cells.push(mc(v(1, column)))
  }
  for column in 4..<14 {
    cells.push(mc(v(0, column)))
  }
  for column in 21..<25 {
    cells.push(mc(v(1, column)))
  }
  // The circles for the signs.
  for _ in 0..<17 {
    cells.push(mc("circle.big"))
  }
  // Three rows of discs. The numbers of Bernoulli that are given stand on
  // V21, V22 and V23 "in a decimal fraction".
  for _ in 0..<13 {
    cells.push("0")
  }
  cells.push(decimal("1"))
  cells.push(decimal("3"))
  cells.push(decimal("5"))
  cells.push("0")
  for _ in 0..<14 {
    cells.push("0")
  }
  for digit in ["1", "2", "4"] {
    cells.push(digit)
  }
  for _ in 0..<11 {
    cells.push("0")
  }
  // What each column holds.
  for source in ["1", "2", "n"] {
    cells.push(framed(source))
  }
  for _ in 0..<10 {
    cells.push(framed(""))
  }
  for source in ["B_1", "B_3", "B_5", "B_7"] {
    cells.push(framed(source))
  }
  cells
}

///|
/// The rows of the 25 operations.
fn plate_body() -> Array[&IntoContent] {
  let half = "1/2 dot (2n-1)/(2n+1)"
  let empty_group = (rows : Int64) => TableCell("", rowspan=rows)
  let cells : Array[&IntoContent] = []
  let add = (row : Array[&IntoContent]) => {
    for cell in row {
      cells.push(cell)
    }
  }
  add(
    op(
      1,
      [empty_group(7)],
      "times",
      "\{v(1, 2)} times \{v(1, 3)}",
      "\{v(1, 4)}, \{v(1, 5)}, \{v(1, 6)}",
      ind(v(1, 2), v(1, 2), v(1, 3), v(1, 3)),
      md("= 2n"),
      [dots, "2", "n", "2n", "2n", "2n"],
    ),
  )
  add(
    op(
      2,
      [],
      "-",
      "\{v(1, 4)} - \{v(1, 1)}",
      v(1, 4),
      ind(v(1, 4), v(2, 4), v(1, 1), v(1, 1)),
      md("= 2n-1"),
      ["1", dots, dots, "2n-1"],
    ),
  )
  add(
    op(
      3,
      [],
      "+",
      "\{v(1, 5)} + \{v(1, 1)}",
      v(2, 5),
      ind(v(1, 5), v(2, 5), v(1, 1), v(1, 1)),
      md("= 2n+1"),
      ["1", dots, dots, dots, "2n+1"],
    ),
  )
  add(
    op(
      4,
      [],
      "div",
      "\{v(2, 4)} div \{v(2, 5)}",
      v(1, 11),
      ind(v(3, 5), v(0, 5), v(3, 4), v(0, 4)),
      md("= (2n-1)/(2n+1)"),
      [dots, dots, dots, "0", "0", ..dotted(5), "= (2n-1)/(2n+1)"],
    ),
  )
  add(
    op(
      5,
      [],
      "div",
      "\{v(1, 11)} div \{v(1, 2)}",
      v(2, 11),
      ind(v(1, 11), v(2, 11), v(1, 2), v(1, 2)),
      md("= \{half}"),
      [dots, "2", ..dotted(8), "= \{half}"],
    ),
  )
  add(
    op(
      6,
      [],
      "-",
      "\{v(0, 13)} - \{v(2, 11)}",
      v(1, 13),
      ind(v(2, 11), v(0, 11), v(0, 13), v(1, 13)),
      md("= - \{half}"),
      [..dotted(10), "0", "", "= - \{half} = A_0"],
    ),
  )
  add(
    op(
      7,
      [],
      "-",
      "\{v(1, 3)} - \{v(1, 1)}",
      v(1, 10),
      ind(v(1, 2), v(1, 3), v(1, 3), v(2, 2)),
      md("= n - 1 (= 3)"),
      ["1", dots, "n", ..dotted(6), "n"],
    ),
  )
  add(
    op(
      8,
      [empty_group(5)],
      "+",
      "\{v(1, 2)} + \{v(0, 7)}",
      v(1, 7),
      ind(v(1, 2), v(1, 2), v(0, 7), v(1, 7)),
      md("= 2 + U = 2"),
      [dots, "2", ..dotted(4), "2"],
    ),
  )
  add(
    op(
      9,
      [],
      "div",
      "\{v(1, 6)} div \{v(1, 7)}",
      v(3, 11),
      ind(v(1, 6), v(1, 6), v(0, 11), v(3, 11)),
      md("= (2n)/2 = A_1"),
      [..dotted(5), "2n", "2", dots, dots, dots, "(2n)/2 = A_1"],
    ),
  )
  add(
    op(
      10,
      [],
      "times",
      "\{v(1, 12)} times \{v(3, 11)}",
      v(1, 12),
      ind(v(1, 21), v(1, 21), v(3, 11), v(3, 11)),
      md("= B_1 dot (2n)/2 = B_1 A_1"),
      [..dotted(10), "(2n)/2 = A_1", "B_1 dot (2n)/2 = B_1 A_1", dots2, "B_1"],
    ),
  )
  add(
    op(
      11,
      [],
      "+",
      "\{v(1, 12)} + \{v(1, 13)}",
      v(2, 12),
      ind(v(1, 12), v(0, 12), v(1, 13), v(2, 13)),
      md("= - \{half} + B_1 dot (2n)/2"),
      [..dotted(10), dots2, "0", "{- \{half} + B_1 dot (2n)/2}"],
    ),
  )
  add(
    op(
      12,
      [],
      "-",
      "\{v(1, 10)} - \{v(1, 1)}",
      v(2, 10),
      ind(v(1, 10), v(2, 10), v(1, 1), v(1, 1)),
      md("= n - 2 = 2"),
      ["1", ..dotted(8), "n-2"],
    ),
  )
  add(
    op(
      13,
      [
        TableCell(brace(11), rowspan=11, align=Center + Horizon),
        TableCell(first_brace(), rowspan=4, align=Center + Horizon),
      ],
      "-",
      "\{v(1, 6)} - \{v(1, 1)}",
      v(2, 6),
      ind(v(1, 6), v(2, 6), v(1, 1), v(1, 1)),
      md("= 2n-1"),
      ["1", ..dotted(4), "2n-1"],
    ),
  )
  add(
    op(
      14,
      [],
      "+",
      "\{v(1, 1)} - \{v(1, 7)}",
      v(2, 7),
      ind(v(1, 1), v(1, 1), v(1, 7), v(2, 7)),
      md("= 2 + 1 = 3"),
      ["1", ..dotted(5), "3"],
    ),
  )
  add(
    op(
      15,
      [],
      "div",
      "\{v(2, 6)} div \{v(2, 7)}",
      v(1, 8),
      ind(v(2, 6), v(2, 6), v(2, 7), v(2, 7)),
      md("= (2n-1)/3"),
      [..dotted(5), "2n-1", "3", "(2n-1)/3"],
    ),
  )
  add(
    op(
      16,
      [],
      "times",
      "\{v(1, 8)} times \{v(3, 11)}",
      v(4, 11),
      ind(v(1, 8), v(0, 8), v(3, 11), v(4, 11)),
      md("= (2n)/2 dot (2n-1)/3"),
      [..dotted(6), "3", "", "0", dots, dots, "(2n)/2 dot (2n-1)/3"],
    ),
  )
  add(
    op(
      17,
      [TableCell(brace(4), rowspan=4, align=Center + Horizon)],
      "-",
      "\{v(2, 6)} - \{v(1, 1)}",
      v(3, 6),
      ind(v(2, 6), v(3, 6), v(1, 1), v(1, 1)),
      md("= 2n-2"),
      ["1", ..dotted(4), "2n-2"],
    ),
  )
  add(
    op(
      18,
      [],
      "+",
      "\{v(1, 1)} + \{v(2, 7)}",
      v(3, 7),
      ind(v(2, 7), v(3, 7), v(1, 1), v(1, 1)),
      md("= 3 + 1 = 4"),
      ["1", ..dotted(5), "4"],
    ),
  )
  add(
    op(
      19,
      [],
      "div",
      "\{v(3, 6)} div \{v(3, 7)}",
      v(1, 9),
      ind(v(3, 6), v(3, 6), v(3, 7), v(3, 7)),
      md("= (2n-2)/4"),
      [
        ..dotted(5),
        "2n-2",
        "4",
        dots,
        "(2n-2)/4",
        dots,
        "mat(delim: #(\"{\", \"}\"), row-gap: #0.2em, display((2n)/2 dot (2n-1)/3 dot (2n-2)/3); = A_2)",
      ],
    ),
  )
  add(
    op(
      20,
      [],
      "times",
      "\{v(1, 9)} times \{v(4, 11)}",
      v(5, 11),
      ind(v(1, 9), v(0, 9), v(4, 11), v(5, 11)),
      md("= (2n)/2 dot (2n-1)/3 dot (2n-2)/4 = A_3"),
      [..dotted(8), "0", dots],
    ),
  )
  add(
    op(
      21,
      [empty_group(3)],
      "times",
      "\{v(1, 22)} times \{v(5, 11)}",
      v(6, 11),
      ind(v(1, 22), v(1, 22), v(0, 12), v(0, 12)),
      md("= B_3 dot (2n)/2 dot (2n-1)/3 dot (2n-2)/3 = B_3 A_3"),
      [..dotted(10), "0", "B_3 A_3", dots, dots, "B_3"],
    ),
  )
  add(
    op(
      22,
      [],
      "+",
      "\{v(3, 12)} + \{v(2, 13)}",
      v(3, 13),
      ind(v(3, 12), v(0, 12), v(2, 13), v(3, 13)),
      md("= A_0 + B_1 A_2 + B_3 A_3"),
      [..dotted(10), dots2, "0", "{A_3 + B_2 A_2 + B_3 A_3}"],
    ),
  )
  add(
    op(
      23,
      [],
      "-",
      "\{v(2, 10)} + \{v(1, 1)}",
      v(3, 10),
      ind(v(3, 10), v(3, 10), v(1, 1), v(1, 1)),
      md("= n - 3 = 1"),
      ["1", ..dotted(8), "n-3"],
    ),
  )
  cells.push(
    TableCell(
      "Here follows a repetition of Operations thirteen to twenty-three.",
      colspan=25,
      align=Center + Horizon,
    ),
  )
  add(
    op(
      24,
      [empty_group(2), empty_group(2)],
      "+",
      "\{v(4, 12)} + \{v(0, 24)}",
      v(1, 24),
      ind(v(4, 12), v(0, 12), v(0, 24), v(1, 24)),
      md("= B_7"),
      [..dotted(10), dots2, dots2, dots2, dots, dots, dots, "B_7"],
    ),
  )
  // Operation 25 changes four indices; the last two changes are made "by a
  // Variable-card".
  let four = "display(mat(delim: #(\"{\", none), row-gap: #0.1em, display(mat(delim: #(none, \"}\"), row-gap: #0.1em, \{v(1, 1)} = \{v(1, 1)}; \{v(1, 3)} = \{v(1, 3)})); \{v(4, 6)} = \{v(0, 6)}; \{v(1, 7)} = \{v(0, 7)}))"
  add(
    op(
      25,
      [],
      "+",
      "\{v(1, 1)} + \{v(1, 3)}",
      v(1, 3),
      four,
      Grid(
        [
          md("= n + 1 = 4 + 1 = 5"),
          "by a Variable-card.",
          "by a Variable-card.",
        ],
        columns=[Auto],
        rows=[Pt(24), Pt(10), Pt(10)],
        align=Cells::all(Left + Horizon),
      ),
      [],
    ),
  )
  cells
}

///|
/// The plate: a landscape sheet with the table.
fn diagram_page() -> Page {
  let widths : Array[Double] = [
    16, 10, 10, 14, 58, 64, 80, 160, 21, 21, 21, 32, 32, 32, 32, 32, 32, 32, 86,
    84, 124, 26, 26, 26, 26,
  ]
  let columns : Array[Sizing] = widths.map(w => Pt(w))
  let rows : Array[Sizing] = [
    Pt(15),
    Pt(15),
    Pt(13),
    Pt(12),
    Pt(12),
    Pt(12),
    Pt(18),
    ..Sizing::repeat(18, size=Pt(op_height)),
    Pt(tall_height),
    ..Sizing::repeat(4, size=Pt(op_height)),
    Pt(16),
    Pt(op_height),
    Pt(2 * op_height + 2),
  ]
  // Rules stand between all columns; the inner group column has none on its
  // right where it holds the braces.
  let stroke : Cells[Sides[Stroke]] = Cells((x, y) => {
    if x == 0 {
      Sides(left=thin, right=thin, rest=Stroke::none())
    } else if x == 2 && y > 18 {
      Sides(all=Stroke::none())
    } else {
      Sides(right=thin, rest=Stroke::none())
    }
  })
  let centre : Alignment = Center + Horizon
  let left : Alignment = Left + Horizon
  let align : Cells[Alignment] = Cells::columns([
    centre, centre, centre, centre, left, left, centre, left, centre, centre, centre,
    centre, centre, centre, centre, centre, centre, centre, centre, centre, centre,
    centre, centre, centre, centre,
  ])
  let table = Table(
    [
      ..plate_head(),
      ..plate_body(),
      TableHline(y=0, stroke=thin),
      TableHline(y=1, start=8, stroke=thin),
      TableHline(y=7, stroke=thin),
      TableHline(y=14, stroke=thin),
      TableHline(y=19, stroke=thin),
      TableHline(y=33, stroke=thin),
    ],
    columns~,
    rows~,
    inset=Cells::all(Sides(x=Pt(1.5), y=Pt(1))),
    align~,
    stroke~,
  )
  Page(
    Seq([
      Block(
        Align(
          Center,
          Text(
            Prose(
              "Diagram for the computation by the Engine of the Numbers of Bernoulli. See Note G. (page 722 \{i("et seq.")})",
            ),
            size=Pt(10.5),
          ),
        ),
        width=Pct(100),
        below=Pt(10),
      ),
      Align(Center, Text(table, size=Pt(plate_size))),
    ]),
    paper="a3",
    flipped=true,
    margin=Sides(x=Pt(40), y=Pt(30)),
    header=NoneValue(),
  )
}
