// `DataTable` (docs/edsl-ports.md, section 4; findings H5, N9 and S5):
// what it expands to, the check of its rows, the header on every page,
// rows that are not split, the lines it draws with and without a frame and
// at the end of a page, the looks that are the table's and the rules of
// the document that reach its cells, and the provenance of its parts. The
// pairs with a Typst twin are in `doc/twins/kit.mbt`. The page is that of
// `cards_test.mbt`: 200pt by 120pt with 10pt margins and 10pt text, so a
// row of one line is 16.6pt high (5pt of inset above and below).

///|
using @doc {
  type SetTable,
  type SetTableCell,
  type ShowSet,
  type TableCell,
  type TableHeader,
  type TableHline,
  type TableVline,
}

///|
/// The rule of the tables of these tests.
let rule : Stroke = Stroke(thickness=Pt(0.5), paint=Luma(120))

///|
/// A head and `count` rows of two cells: `a0`, `b0`, `a1`, ..
let head : Array[&IntoContent] = ["A", "B"]

///|
fn two_columns(count : Int) -> Array[Array[&IntoContent]] {
  Array::makei(count, i => ["a\{i}", "b\{i}"])
}

///|
/// The lines of a compiled document, one line each.
fn rules(report : @doc.CompileReport[@layout.PagedDocument]) -> String raise {
  listing(of_kind(drawn(report), "line"))
}

///|
/// The text runs of each page, in the order of the frames.
fn page_texts(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String raise {
  let all = of_kind(drawn(report), "text")
  let out : Array[String] = []
  for page in 1..<=pages(report) {
    let texts = all.filter(run => run.page == page).map(run => run.text)
    out.push("p\{page}: " + texts.join(" "))
  }
  out.join("\n")
}

///|
test "data table: a table with a header, a rule under each row, and a frame" {
  // The expansion without a frame.
  assert_eq(
    lowered([
      @kit.DataTable(["A", Emph("B")], [["a", "b"], ["c", Emph("d")]], columns=[
        Auto,
        Fr(1),
      ]),
    ]),
    lowered([
      Seq([
        SetTableCell(breakable=false),
        Table(
          [TableHeader(["A", Emph("B")]), "a", "b", "c", Emph("d")],
          columns=[Auto, Fr(1)],
          stroke=Cells::all(Sides(bottom=Stroke(), rest=Stroke::none())),
        ),
      ]),
    ]),
  )
  // With a frame, and everything that is passed on.
  let inset : Cells[Sides[@doc.Length]] = Cells::all(Sides(x=Pt(6), y=Pt(4)))
  let align : Cells[@doc.Alignment] = Cells::columns([Left, Right])
  let fill : Cells[@doc.Paint] = Cells::all(Luma(240))
  assert_eq(
    lowered([
      @kit.DataTable(
        head,
        two_columns(1),
        columns=[Auto, Fr(1)],
        inset~,
        align~,
        fill~,
        stroke=rule,
        radius=round,
        breakable=true,
      ),
    ]),
    lowered([
      Block(
        Seq([
          SetTableCell(breakable=true),
          Table(
            [
              TableHeader(["A", "B"]),
              "a0",
              "b0",
              TableHline(stroke=Stroke::none()),
            ],
            columns=[Auto, Fr(1)],
            inset~,
            align~,
            fill~,
            stroke=Cells::all(Sides(bottom=rule, rest=Stroke::none())),
          ),
        ]),
        radius=round,
        stroke=Sides(all=rule),
        clip=true,
      ),
    ]),
  )
  // Without a head there is no header; without rows there are none.
  assert_eq(
    lowered([@kit.DataTable([], two_columns(1), columns=[Auto, Auto])]),
    lowered([
      Seq([
        SetTableCell(breakable=false),
        Table(
          ["a0", "b0"],
          columns=[Auto, Auto],
          stroke=Cells::all(Sides(bottom=Stroke(), rest=Stroke::none())),
        ),
      ]),
    ]),
  )
  assert_eq(
    lowered([@kit.DataTable(head, [], columns=[Auto, Auto])]),
    lowered([
      Seq([
        SetTableCell(breakable=false),
        Table(
          [TableHeader(["A", "B"])],
          columns=[Auto, Auto],
          stroke=Cells::all(Sides(bottom=Stroke(), rest=Stroke::none())),
        ),
      ]),
    ]),
  )
  // It prints as its name around what it is made of: the cells of a row
  // under the key of the row.
  debug_inspect(
    @kit.DataTable(["A"], [["a"], ["b"]], columns=[Auto], radius=round),
    content=(
      #|DataTable(
      #|  Block(
      #|    Seq(
      #|      [
      #|        SetTableCell(breakable=false),
      #|        Table(
      #|          columns=[auto],
      #|          stroke={ "bottom": stroke, "rest": none },
      #|          TableHeader("A"),
      #|          Keyed("0", "a"),
      #|          Keyed("1", "b"),
      #|          TableHline(stroke=none),
      #|        ),
      #|      ],
      #|    ),
      #|    stroke=stroke,
      #|    radius=3pt,
      #|    clip=true,
      #|  ),
      #|)
    ),
  )
}

///|
test "data table: every row has to fill the columns" {
  // A row with a cell too few, in a table of three columns.
  let line = line_here() + 4
  let short = compile([
    @kit.DataTable(
      ["A", "B", "C"],
      [["a", "b", "c"], ["d", "e"], ["f", "g", "h"]],
      columns=[Auto, Auto, Auto],
    ),
  ])
  inspect(
    errors(short),
    content=(
      #|`rows[1]` has cells for 2 columns: this `DataTable` has 3 columns
    ),
  )
  // The error is at the `rows` argument, under the key of the row.
  inspect(
    error_place(short),
    content=(
      #|DataTable a1 1
    ),
  )
  assert_eq(error_origin(short).start_line, line)
  // What a `Table` of the same cells does (finding N9): it compiles, and
  // every cell after the short row is one column to the left.
  let shifted = compile([
    Table(["A", "B", "C", "a", "b", "c", "d", "e", "f", "g", "h"], columns=[
      Auto,
      Auto,
      Auto,
    ]),
  ])
  inspect(errors(shifted) + warnings(shifted), content="")
  let column = (report : @doc.CompileReport[@layout.PagedDocument], text) => {
    pt(of_kind(drawn(report), "text").filter(run => run.text == text)[0].x)
  }
  assert_eq(column(shifted, "f"), column(shifted, "C"))
  // The messages: too many cells, a head that does not fit, no columns.
  let message = (table : @kit.DataTable) => {
    let report = compile([table])
    "\{errors(report)} [\{error_place(report)}]"
  }
  inspect(
    message(
      @kit.DataTable(
        ["A", "B"],
        [["a", "b"], ["c", "d", "e"]],
        columns=[Auto, Auto],
        key=row => "row \{row}",
      ),
    ),
    content=(
      #|`rows[1]` has cells for 3 columns: this `DataTable` has 2 columns [DataTable a1 row 1]
    ),
  )
  inspect(
    message(@kit.DataTable(["A"], [["a", "b"]], columns=[Auto, Auto])),
    content=(
      #|`head` has cells for 1 column: this `DataTable` has 2 columns [DataTable a0]
    ),
  )
  inspect(
    message(@kit.DataTable(["A"], [["a"]], columns=[])),
    content=(
      #|a `DataTable` needs its `columns`: a track for every cell of a row [DataTable a2]
    ),
  )
  // An empty row is a row.
  inspect(
    message(@kit.DataTable([], [["a", "b"], []], columns=[Auto, Auto])),
    content=(
      #|`rows[1]` has cells for 0 columns: this `DataTable` has 2 columns [DataTable a1 1]
    ),
  )
}

///|
test "data table: cells that span columns and rows are counted" {
  // A cell over two columns, and one over two rows, whose column the next
  // row leaves out.
  let report = compile([
    @kit.DataTable(
      ["A", TableCell("B and C", colspan=2)],
      [
        ["a", "b", "c"],
        [TableCell("wide", colspan=2), "d"],
        [Keyed("mine", TableCell("tall", rowspan=2)), "e", "f"],
        ["g", "h"],
        [TableCell("all", colspan=3)],
      ],
      columns=[Pt(50), Pt(50), Pt(50)],
      stroke=rule,
    ),
  ])
  inspect(errors(report) + warnings(report), content="")
  // Each row is where it is written: `g` and `h` in the second and the
  // third column, beside the cell from the row above.
  inspect(
    lines_of_text(report),
    content=(
      #|p1 15.0,21.6 "A"
      #|p1 65.0,21.6 "B and C"
      #|p1 15.0,38.2 "a"
      #|p1 65.0,38.2 "b"
      #|p1 115.0,38.2 "c"
      #|p1 15.0,54.7 "wide"
      #|p1 115.0,54.7 "d"
      #|p1 65.0,71.3 "e"
      #|p1 115.0,71.3 "f"
      #|p1 15.0,71.3 "tall"
      #|p1 65.0,87.9 "g"
      #|p1 115.0,87.9 "h"
      #|p1 15.0,104.5 "all"
    ),
  )
  // The rule under a row ends where a cell goes on into the next row.
  inspect(
    rules(report),
    content=(
      #|p1 line 9.8,26.6 150.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 150.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,59.7 150.5x0.0 0.5 luma(47.06%)
      #|p1 line 59.8,76.3 100.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,92.9 150.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,109.5 150.5x0.0 0.5 luma(47.06%)
    ),
  )
  // What does not fit, with the spans counted.
  let message = (head : Array[&IntoContent], rows : Array[Array[&IntoContent]]) => {
    let report = compile([
      @kit.DataTable(head, rows, columns=[Auto, Auto, Auto]),
    ])
    "\{errors(report)} [\{error_place(report)}]"
  }
  inspect(
    message([], [[TableCell("wide", colspan=2), "b", "c"]]),
    content=(
      #|`rows[0]` has cells for 4 columns: this `DataTable` has 3 columns [DataTable a1 0]
    ),
  )
  inspect(
    message([], [[TableCell("tall", rowspan=2), "b", "c"], ["d", "e", "f"]]),
    content=(
      #|`rows[1]` has cells for 3 columns beside the 1 that cells of the rows above take: this `DataTable` has 3 columns [DataTable a1 1]
    ),
  )
  inspect(
    message([], [
      ["a", TableCell("tall", rowspan=2), "c"],
      [TableCell("wide", colspan=2)],
    ]),
    content=(
      #|a cell of `rows[1]` spans into a column that a cell of the rows above takes [DataTable a1 1]
    ),
  )
  inspect(
    message([], [["a", "b", TableCell("tall", rowspan=3)], ["d", "e"]]),
    content=(
      #|a cell of `rows[0]` spans rows below the last row of `rows` [DataTable a1 0]
    ),
  )
  inspect(
    message([TableCell("A", rowspan=2), "B", "C"], [["b", "c"]]),
    content=(
      #|a cell of `head` spans rows: the header of a `DataTable` is one row [DataTable a0]
    ),
  )
  // An item that a table does not place in its row is not a cell of a
  // row: a cell with a position, a line.
  inspect(
    message([], [["a", TableCell("b", x=0), "c"]]),
    content=(
      #|`rows[0]` has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells [DataTable a1 0]
    ),
  )
  inspect(
    message([], [["a", "b", "c", TableHline()]]),
    content=(
      #|`rows[0]` has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells [DataTable a1 0]
    ),
  )
  inspect(
    message(["A", "B", TableVline()], []),
    content=(
      #|`head` has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells [DataTable a0]
    ),
  )
  // The count reads descriptions: a cell that a callback makes is one
  // column for it, whatever the callback returns.
  let unseen = compile([
    @kit.DataTable([], [[Context(_ => "a"), "b", "c"]], columns=[
      Auto,
      Auto,
      Auto,
    ]),
  ])
  inspect(errors(unseen), content="")
}

///|
test "data table: the header is on every page, and a row is not split" {
  // Rows of one line: five fit a page under the header.
  let report = compile([
    @kit.DataTable(head, two_columns(8), columns=[Fr(1), Fr(1)]),
  ])
  inspect(errors(report) + warnings(report), content="")
  inspect(
    page_texts(report),
    content=(
      #|p1: A B a0 b0 a1 b1 a2 b2 a3 b3 a4 b4
      #|p2: A B a5 b5 a6 b6 a7 b7
    ),
  )
  // A row of five lines that does not fit what is left of the page moves
  // to the next page as a whole.
  let long = "word ".repeat(18)
  let rows : Array[Array[&IntoContent]] = [
    ["a0", "b0"],
    ["a1", "b1"],
    ["a2", long],
    ["a3", "b3"],
  ]
  let whole = compile([@kit.DataTable(head, rows, columns=[Pt(40), Fr(1)])])
  inspect(errors(whole) + warnings(whole), content="")
  inspect(
    page_texts(whole),
    content=(
      #|p1: A B a0 b0 a1 b1
      #|p2: A B a2 word word word word word  word word word word word  word word word word word  word word word  a3 b3
    ),
  )
  // With `breakable=true` it is split, as a table splits its rows.
  let split = compile([
    @kit.DataTable(head, rows, columns=[Pt(40), Fr(1)], breakable=true),
  ])
  inspect(
    page_texts(split),
    content=(
      #|p1: A B a0 b0 a1 b1 a2 word word word word word  word word word word word 
      #|p2: A B word word word word word  word word word  a3 b3
    ),
  )
  // A cell of the caller can say otherwise for itself, but a row is as
  // breakable as its least breakable cell.
  let one = compile([
    @kit.DataTable(
      head,
      [
        ["a0", "b0"],
        ["a1", "b1"],
        ["a2", TableCell(long, breakable=true)],
        ["a3", "b3"],
      ],
      columns=[Pt(40), Fr(1)],
    ),
  ])
  assert_eq(page_texts(one), page_texts(whole))
}

///|
test "data table: a row that is higher than the page" {
  // The engine's fact: a row of unbreakable cells that no page holds
  // leaves the page, without a diagnostic.
  let tall = "word ".repeat(60)
  let rows : Array[Array[&IntoContent]] = [["a0", "b0"], ["a1", tall]]
  let report = compile([@kit.DataTable(head, rows, columns=[Pt(40), Fr(1)])])
  inspect(errors(report) + warnings(report), content="")
  assert_true(drawn(report).iter().any(d => d.y > 120.0))
  // With `breakable=true` everything is on a page.
  let split = compile([
    @kit.DataTable(head, rows, columns=[Pt(40), Fr(1)], breakable=true),
  ])
  inspect(errors(split) + warnings(split), content="")
  for d in drawn(split) {
    assert_true(d.y >= 9.0 && d.y <= 110.5)
  }
  assert_true(pages(split) > 1)
}

///|
test "data table: the only lines are the rules under the rows" {
  let report = compile([
    @kit.DataTable(head, two_columns(2), columns=[Fr(1), Fr(1)], stroke=rule),
  ])
  inspect(errors(report) + warnings(report), content="")
  // Three horizontal lines, under the header and under each row; no
  // vertical line, and none above the header.
  inspect(
    rules(report),
    content=(
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,59.7 180.5x0.0 0.5 luma(47.06%)
    ),
  )
  // What a table does with a stroke that names the bottom only (section
  // 2.4 of the ports document): the other sides are the table's default
  // stroke.
  let named = compile([
    Table(
      ["A", "B", "a0", "b0"],
      columns=[Fr(1), Fr(1)],
      stroke=Cells::all(Sides(bottom=rule)),
    ),
  ])
  inspect(
    rules(named),
    content=(
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 10.0,9.5 0.0x34.2 1.0 luma(0%)
      #|p1 line 100.0,9.5 0.0x34.2 1.0 luma(0%)
      #|p1 line 190.0,9.5 0.0x34.2 1.0 luma(0%)
      #|p1 line 9.5,10.0 181.0x0.0 1.0 luma(0%)
    ),
  )
  // Without `stroke` the rule is the default stroke, or what the document
  // sets for tables; `Stroke::none()` is no line.
  let plain = compile([@kit.DataTable(head, [], columns=[Fr(1), Fr(1)])])
  inspect(
    rules(plain),
    content=(
      #|p1 line 9.5,26.6 181.0x0.0 1.0 luma(0%)
    ),
  )
  let set = compile([
    Seq([
      SetTable(stroke=Cells::all(Sides(all=rule))),
      @kit.DataTable(head, [], columns=[Fr(1), Fr(1)]),
    ]),
  ])
  inspect(
    rules(set),
    content=(
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
    ),
  )
  let none = compile([
    @kit.DataTable(
      head,
      two_columns(2),
      columns=[Fr(1), Fr(1)],
      stroke=Stroke::none(),
    ),
  ])
  inspect(rules(none), content="")
  // Other lines are asked for by the cell that has them.
  let asked = compile([
    @kit.DataTable(
      head,
      [[TableCell("a0", stroke=Sides(right=rule)), "b0"]],
      columns=[Fr(1), Fr(1)],
      stroke=rule,
    ),
  ])
  inspect(
    rules(asked),
    content=(
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 100.0,26.3 0.0x17.1 0.5 luma(47.06%)
    ),
  )
}

///|
test "data table: the frame, and the end of a page" {
  let framed = compile([
    @kit.DataTable(
      head,
      two_columns(8),
      columns=[Fr(1), Fr(1)],
      fill=Cells::all(Luma(240)),
      stroke=rule,
      radius=round,
    ),
  ])
  inspect(errors(framed) + warnings(framed), content="")
  // On each page: the frame around the rows of that page, as wide as the
  // table, and a rule under the header and under every row but the last
  // of the page.
  inspect(
    listing(drawn(framed).filter(d => d.kind != "text" && d.fill == "")),
    content=(
      #|p1 box 10.0,10.0 180.0x99.5 stroke 0.5 luma(47.06%)
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,59.7 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,76.3 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,92.9 180.5x0.0 0.5 luma(47.06%)
      #|p2 box 10.0,10.0 180.0x66.3 stroke 0.5 luma(47.06%)
      #|p2 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p2 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p2 line 9.8,59.7 180.5x0.0 0.5 luma(47.06%)
    ),
  )
  // The frame is the box around the cells of its page.
  let frames = of_kind(drawn(framed), "box").filter(d => d.fill == "")
  let cells = of_kind(drawn(framed), "box").filter(d => d.fill != "")
  for frame in frames {
    let mut bottom = 0.0
    for cell in cells.filter(cell => cell.page == frame.page) {
      assert_true(cell.x >= frame.x && cell.x + cell.w <= frame.x + frame.w)
      bottom = if cell.y + cell.h > bottom { cell.y + cell.h } else { bottom }
    }
    assert_eq(pt(bottom), pt(frame.y + frame.h))
  }
  // Without a frame the rule under the last row of a page is drawn, like
  // the rule under every row.
  let open = compile([
    @kit.DataTable(head, two_columns(8), columns=[Fr(1), Fr(1)], stroke=rule),
  ])
  inspect(
    rules(open),
    content=(
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,59.7 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,76.3 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,92.9 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,109.5 180.5x0.0 0.5 luma(47.06%)
      #|p2 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p2 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p2 line 9.8,59.7 180.5x0.0 0.5 luma(47.06%)
      #|p2 line 9.8,76.3 180.5x0.0 0.5 luma(47.06%)
    ),
  )
  // What the hand-written tables of the ports did (a rule under every row
  // but the table's last, in a clipped block): the engine draws the rule
  // under the last row of a page, on the outline of the frame.
  let last = 8
  let by_hand = compile([
    Block(
      Table(
        [TableHeader(head), ..two_columns(8).flatten()],
        columns=[Fr(1), Fr(1)],
        stroke=Cells((_, y) => {
          if y == last {
            Sides::none()
          } else {
            Sides(bottom=rule, rest=Stroke::none())
          }
        }),
      ),
      radius=round,
      stroke=Sides(all=rule),
      clip=true,
    ),
  ])
  inspect(
    listing(drawn(by_hand).filter(d => d.kind != "text" && d.page == 1)),
    content=(
      #|p1 box 10.0,10.0 180.0x99.5 stroke 0.5 luma(47.06%)
      #|p1 line 9.8,26.6 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,43.2 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,59.7 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,76.3 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,92.9 180.5x0.0 0.5 luma(47.06%)
      #|p1 line 9.8,109.5 180.5x0.0 0.5 luma(47.06%)
    ),
  )
  // A frame in a narrower place is as wide as its table.
  let narrow = compile([
    @kit.DataTable(head, two_columns(1), columns=[Auto, Auto], radius=round),
  ])
  inspect(
    listing(of_kind(drawn(narrow), "box")),
    content=(
      #|p1 box 10.0,10.0 38.8x33.2 stroke 1.0 luma(0%)
    ),
  )
}

///|
test "data table: alignment, fills and insets are the table's, per cell" {
  // Numbers to the right: an alignment per column.
  let rows : Array[Array[&IntoContent]] = [
    ["first", "7"],
    ["second", "1,204"],
    ["third", "38"],
  ]
  let fill : Cells[@doc.Paint] = Cells((_, y) => {
    // (Row 0 is the header; row 2 is `rows[1]`.)
    if y == 0 {
      Luma(200)
    } else if y == 2 {
      Luma(240)
    } else {
      None
    }
  })
  let report = compile([
    @kit.DataTable(
      ["Name", "Count"],
      rows,
      columns=[Fr(1), Pt(60)],
      inset=Cells::all(Sides(x=Pt(8), y=Pt(3))),
      align=Cells::columns([Left, Right]),
      fill~,
      stroke=rule,
    ),
  ])
  inspect(errors(report) + warnings(report), content="")
  inspect(
    listing(drawn(report).filter(d => d.kind != "line")),
    content=(
      #|p1 box 10.0,10.0 120.0x12.6 luma(78.43%)
      #|p1 box 10.0,35.2 120.0x12.6 luma(94.12%)
      #|p1 box 130.0,10.0 60.0x12.6 luma(78.43%)
      #|p1 box 130.0,35.2 60.0x12.6 luma(94.12%)
      #|p1 text 18.0,19.6 10.0pt "Name"
      #|p1 text 156.6,19.6 10.0pt "Count"
      #|p1 text 18.0,32.2 10.0pt "first"
      #|p1 text 177.4,32.2 10.0pt "7"
      #|p1 text 18.0,44.7 10.0pt "second"
      #|p1 text 161.2,44.7 10.0pt "1,204"
      #|p1 text 18.0,57.3 10.0pt "third"
      #|p1 text 172.7,57.3 10.0pt "38"
    ),
  )
  // The numbers end 8pt before the end of their column.
  for run in of_kind(drawn(report), "text") {
    if run.text == "Count" || run.text == "7" || run.text == "1,204" {
      assert_eq(pt(run.x + run.w), "182.0")
    }
  }
}

///|
test "data table: the text is styled by the rules of the document" {
  // The size of the table's text, the header and a column: rules before
  // the element, which reach its cells.
  let report = compile([
    Seq([
      SetText(size=Pt(8)),
      ShowSet(Select::table_cell(x=1), SetText(font=["DejaVu Sans Mono"])),
      ShowSet(Select::table_cell(y=0), SetText(size=Pt(6), weight=Bold)),
      @kit.DataTable(
        ["NAME", "COUNT"],
        [["first", "7"], ["second", "1204"]],
        columns=[Fr(1), Auto],
        radius=round,
      ),
    ]),
    "after",
  ])
  inspect(errors(report) + warnings(report), content="")
  // The header in its size, the second column in its font (and its cell
  // of the header in both), the text after the sequence as before.
  inspect(
    of_kind(drawn(report), "text")
    .map(run => "\{run.text}: \{pt(run.h)}pt \{run.family}")
    .join("\n"),
    content=(
      #|NAME: 6.0pt Libertinus Serif
      #|COUNT: 6.0pt DejaVu Sans Mono
      #|first: 8.0pt Libertinus Serif
      #|7: 8.0pt DejaVu Sans Mono
      #|second: 8.0pt Libertinus Serif
      #|1204: 8.0pt DejaVu Sans Mono
      #|after: 10.0pt Libertinus Serif
    ),
  )
  // `Table`'s other parameters come from a set rule, as for any table.
  let spaced = compile([
    Seq([
      SetTable(row_gutter=[Pt(4)]),
      @kit.DataTable(head, two_columns(1), columns=[Fr(1), Fr(1)], stroke=rule),
    ]),
  ])
  inspect(errors(spaced), content="")
  inspect(
    lines_of_text(spaced),
    content=(
      #|p1 15.0,21.6 "A"
      #|p1 105.0,21.6 "B"
      #|p1 15.0,42.2 "a0"
      #|p1 105.0,42.2 "b0"
    ),
  )
}

///|
test "data table: it has no callback, and can be built anywhere" {
  let report = compile([
    Show(Select::heading()) <| ((it, _) => {
      @kit.DataTable(["Heading"], [[it]], columns=[Fr(1)], radius=round)
    }),
    Heading("Head"),
    Context(_ => {
      @kit.DataTable(
        head,
        two_columns(1),
        columns=[Fr(1), Fr(1)],
        align=Cells::columns([Left, Right]),
      )
    }),
  ])
  inspect(errors(report) + warnings(report), content="")
  inspect(
    lines_of_text(report),
    content=(
      #|p1 15.0,24.0 "Heading"
      #|p1 15.0,43.1 "Head"
      #|p1 15.0,67.1 "A"
      #|p1 179.1,67.1 "B"
      #|p1 15.0,83.7 "a0"
      #|p1 175.4,83.7 "b0"
    ),
  )
  // A `Cells` function is a callback of the caller: it is created where
  // the caller writes it.
  let late = compile([
    Context(_ => {
      @kit.DataTable(
        head,
        two_columns(1),
        columns=[Fr(1), Fr(1)],
        fill=Cells((_, y) => if y == 0 { Luma(200) } else { None }),
      )
    }),
  ])
  inspect(
    errors(late),
    content=(
      #|callbacks cannot be created inside a callback
    ),
  )
  let fill : Cells[@doc.Paint] = Cells((_, y) => {
    if y == 0 {
      Luma(200)
    } else {
      None
    }
  })
  let early = compile([
    Context(_ => {
      @kit.DataTable(head, two_columns(1), columns=[Fr(1), Fr(1)], fill~)
    }),
  ])
  inspect(errors(early), content="")
}

///|
test "data table: a long word in a narrow column, with soft breaks" {
  // Finding S5: inline code without a place to break leaves its cell.
  let name = "garden_bed_watering_schedule"
  let table = (cell : &IntoContent) => {
    compile([
      @kit.DataTable(["Name", "Use"], [[cell, "x"]], columns=[Pt(80), Fr(1)]),
    ])
  }
  let unbroken = table(@doc.Raw(name))
  let run = of_kind(drawn(unbroken), "text").filter(run => run.text == name)[0]
  assert_true(run.x + run.w > 90.0)
  // `soft_breaks` gives it places to break: after each `_`.
  let broken = table(@doc.Raw(@format.soft_breaks(name)))
  inspect(errors(broken) + warnings(broken), content="")
  let runs = of_kind(drawn(broken), "text").filter(run => {
    run.text != "x" && run.text != "Name" && run.text != "Use"
  })
  inspect(
    runs.map(run => run.text.replace_all(old="\u{200B}", new="")).join("|"),
    content=(
      #|garden_bed_|watering_|schedule
    ),
  )
  for run in runs {
    assert_true(run.x + run.w <= 85.0)
  }
}

///|
test "data table: provenance" {
  let own = Emph("stressed")
  let line = line_here() + 2
  let report = compile([
    @kit.DataTable(
      ["Head", own],
      [["plain", own], ["plain", Seq(["in ", "a sequence"])]],
      columns=[Fr(1), Fr(1)],
      fill=Cells::all(Luma(240)),
      radius=round,
    ),
  ])
  inspect(errors(report), content="")
  // A string of the head is the `head` argument; a string of a row is
  // the `rows` argument under the key of its row; a description of the
  // caller is at its own call, under that key too.
  inspect(
    text_args(report),
    content=(
      #|Head: DataTable a0 | stressed: Emph a0 | plain: DataTable a1 0 | stressed: Emph a0 0 | plain: DataTable a1 1 | in a sequence: Seq a0 1
    ),
  )
  // A click on a cell, where there is no text: the call.
  let cell = of_kind(drawn(report), "box").filter(d => d.fill != "")[0]
  guard report.origin_at(1, cell.x + cell.w - 2.0, cell.y + 2.0) is Some(origin) else {
    fail("no origin at the cell")
  }
  assert_eq(origin.kind, "DataTable")
  assert_eq(origin.param, None)
  assert_eq(origin.start_line, line)
  // Rows from a loop over data are distinct occurrences: by their index,
  // or by the key that the data gives.
  let beds = [("north", "beans"), ("south", "chard"), ("west", "beans")]
  let rows : Array[Array[&IntoContent]] = beds.map(bed => [bed.0, bed.1])
  inspect(
    text_args(compile([@kit.DataTable([], rows, columns=[Fr(1), Fr(1)])])),
    content=(
      #|north: DataTable a1 0 | beans: DataTable a1 0 | south: DataTable a1 1 | chard: DataTable a1 1 | west: DataTable a1 2 | beans: DataTable a1 2
    ),
  )
  inspect(
    text_args(
      compile([
        Keyed(
          "beds",
          @kit.DataTable([], rows, columns=[Fr(1), Fr(1)], key=row => {
            "bed:" + beds[row].0
          }),
        ),
      ]),
    ),
    content=(
      #|north: DataTable a1 beds/bed:north | beans: DataTable a1 beds/bed:north | south: DataTable a1 beds/bed:south | chard: DataTable a1 beds/bed:south | west: DataTable a1 beds/bed:west | beans: DataTable a1 beds/bed:west
    ),
  )
  // An error in an argument is at that argument, with and without a
  // frame: every argument that is passed on and can be wrong.
  let paint : @doc.Paint = Value(@doc.Value::str("x"))
  let failing : Array[(String, (Corners[@doc.Length]?) -> @kit.DataTable)] = [
    (
      "columns",
      radius => @kit.DataTable(head, [], columns=[None, Auto], radius?),
    ),
    (
      "inset",
      radius => {
        @kit.DataTable(
          head,
          [],
          columns=[Auto, Auto],
          inset=Cells::all(Sides::none()),
          radius?,
        )
      },
    ),
    (
      "align",
      radius => {
        @kit.DataTable(
          head,
          [],
          columns=[Auto, Auto],
          align=Cells::all(Both(Left, Right)),
          radius?,
        )
      },
    ),
    (
      "fill",
      radius => {
        @kit.DataTable(
          head,
          [],
          columns=[Auto, Auto],
          fill=Cells::all(paint),
          radius?,
        )
      },
    ),
    (
      "stroke",
      radius => {
        @kit.DataTable(
          head,
          [],
          columns=[Auto, Auto],
          stroke=Stroke(paint~),
          radius?,
        )
      },
    ),
  ]
  let places : Array[String] = []
  for entry in failing {
    let (name, build) = entry
    let plain = compile([build(None)])
    let framed = compile([build(Some(round))])
    assert_true(errors(plain) != "" && errors(framed) != "")
    assert_eq(error_place(framed), error_place(plain))
    places.push("\{name}: \{error_place(plain)}")
  }
  inspect(
    places.join(" | "),
    content=(
      #|columns: DataTable a2 | inset: DataTable a3 | align: DataTable a4 | fill: DataTable a5 | stroke: DataTable a6
    ),
  )
  let radius = compile([
    @kit.DataTable(head, [], columns=[Auto, Auto], radius=Corners(all=Auto)),
  ])
  inspect(
    errors(radius),
    content=(
      #|expected relative length or dictionary, found auto
    ),
  )
  inspect(
    error_place(radius),
    content=(
      #|DataTable a7
    ),
  )
  // An error in a cell is in its row: at the cell's own call under the
  // key of the row.
  let in_row = compile([
    @kit.DataTable(head, [["a0", "b0"], ["a1", @doc.Text("b1", fill=paint)]], columns=[
      Auto,
      Auto,
    ]),
  ])
  inspect(
    errors(in_row),
    content=(
      #|expected color, gradient, or tiling, found string
    ),
  )
  inspect(
    error_place(in_row),
    content=(
      #|Text a6 1
    ),
  )
  // The description is what it was built from: the arrays of the caller
  // can change afterwards.
  let columns : Array[Sizing] = [Fr(1), Fr(1)]
  let cells : Array[Array[&IntoContent]] = [["a0", "b0"]]
  let labels : Array[&IntoContent] = ["A", "B"]
  let built = @kit.DataTable(labels, cells, columns~)
  let before = lines_of_text(compile([built]))
  columns.push(Fr(1))
  cells[0].push("c0")
  cells.push(["a1"])
  labels[0] = "changed"
  assert_eq(lines_of_text(compile([built])), before)
}
