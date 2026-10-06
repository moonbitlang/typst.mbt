// The twins of the kit on input that the elements reject. The pairs of
// `kit.mbt` are documents that compile, which the `edsl` stage compares;
// here the Typst function and the element are given the same wrong rows
// and have to say the same.

///|
/// The message of the first error of a document, `""` if it compiles.
fn first_error(document : Document) -> String {
  let report = document.compile_paged(@doc.DocWorld::in_memory())
  if report.errors.is_empty() {
    ""
  } else {
    report.errors[0].message
  }
}

///|
/// The same for the Typst function `data-table` called with `arguments`.
fn typst_error(arguments : String) -> String {
  first_error(
    Document([Markup(data_table_typ + "#data-table(" + arguments + ")")]),
  )
}

///|
test "data-table: the function rejects what the element rejects, in its words" {
  let three : Array[@doc.Sizing] = [Auto, Auto, Auto]
  let two : Array[@doc.Sizing] = [Auto, Auto]
  let none : Array[&@doc.IntoContent] = []
  // The arguments of the function, and the element with the same.
  let cases : Array[(String, String, () -> @kit.DataTable)] = [
    (
      "a row with a cell too few",
      "columns: (auto, auto, auto), ([A], [B], [C]), (([a], [b], [c]), ([d], [e]))",
      () => {
        @kit.DataTable(
          ["A", "B", "C"],
          [["a", "b", "c"], ["d", "e"]],
          columns=three,
        )
      },
    ),
    (
      "a row with a cell too many",
      "columns: (auto, auto), (), (([a], [b]), ([c], [d], [e]))",
      () => @kit.DataTable(none, [["a", "b"], ["c", "d", "e"]], columns=two),
    ),
    (
      "a head that does not fit",
      "columns: (auto, auto), ([A],), (([a], [b]),)",
      () => @kit.DataTable(["A"], [["a", "b"]], columns=two),
    ),
    (
      "a row beside a cell from above",
      "columns: (auto, auto, auto), (), ((table.cell(rowspan: 2)[t], [b], [c]), ([d], [e], [f]))",
      () => {
        @kit.DataTable(
          none,
          [[TableCell("t", rowspan=2), "b", "c"], ["d", "e", "f"]],
          columns=three,
        )
      },
    ),
    (
      "a span into a cell from above",
      "columns: (auto, auto, auto), (), (([a], table.cell(rowspan: 2)[t], [c]), (table.cell(colspan: 2)[w],))",
      () => {
        @kit.DataTable(
          none,
          [["a", TableCell("t", rowspan=2), "c"], [TableCell("w", colspan=2)]],
          columns=three,
        )
      },
    ),
    (
      "a span below the last row",
      "columns: (auto, auto, auto), (), (([a], [b], table.cell(rowspan: 3)[t]), ([d], [e]))",
      () => {
        @kit.DataTable(
          none,
          [["a", "b", TableCell("t", rowspan=3)], ["d", "e"]],
          columns=three,
        )
      },
    ),
    (
      "a cell of the head that spans rows",
      "columns: (auto, auto, auto), (table.cell(rowspan: 2)[A], [B], [C]), (([b], [c]),)",
      () => {
        @kit.DataTable(
          [TableCell("A", rowspan=2), "B", "C"],
          [["b", "c"]],
          columns=three,
        )
      },
    ),
    (
      "a cell with a position",
      "columns: (auto, auto, auto), (), (([a], table.cell(x: 0)[b], [c]),)",
      () => {
        @kit.DataTable(none, [["a", TableCell("b", x=0), "c"]], columns=three)
      },
    ),
    (
      "a line in a row",
      "columns: (auto, auto, auto), (), (([a], [b], [c], table.hline()),)",
      () => {
        @kit.DataTable(
          none,
          [["a", "b", "c", @doc.TableHline()]],
          columns=three,
        )
      },
    ),
    (
      "no columns",
      "columns: (), ([A],), (([a],),)",
      () => @kit.DataTable(["A"], [["a"]], columns=[]),
    ),
    (
      "the fill of a frame without a frame",
      "columns: (auto, auto), frame-fill: white, ([A], [B]), (([a], [b]),)",
      () => {
        @kit.DataTable(["A", "B"], [["a", "b"]], columns=two, frame_fill=White)
      },
    ),
  ]
  let messages : Array[String] = []
  for entry in cases {
    let (name, arguments, build) = entry
    let message = first_error(Document([build()]))
    assert_true(message != "")
    // (Typst's `assert` puts its own words before the message.)
    assert_eq(typst_error(arguments), "assertion failed: " + message)
    messages.push("\{name}: \{message}")
  }
  inspect(
    messages.join("\n"),
    content=(
      #|a row with a cell too few: `rows[1]` has cells for 2 columns: this `DataTable` has 3 columns
      #|a row with a cell too many: `rows[1]` has cells for 3 columns: this `DataTable` has 2 columns
      #|a head that does not fit: `head` has cells for 1 column: this `DataTable` has 2 columns
      #|a row beside a cell from above: `rows[1]` has cells for 3 columns beside the 1 that cells of the rows above take: this `DataTable` has 3 columns
      #|a span into a cell from above: a cell of `rows[1]` spans into a column that a cell of the rows above takes
      #|a span below the last row: a cell of `rows[0]` spans rows below the last row of `rows`
      #|a cell of the head that spans rows: a cell of `head` spans rows: the header of a `DataTable` is one row
      #|a cell with a position: `rows[0]` has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells
      #|a line in a row: `rows[0]` has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells
      #|no columns: a `DataTable` needs its `columns`: a track for every cell of a row
      #|the fill of a frame without a frame: a `DataTable` has a frame only with a `radius`: `frame_fill` is the fill of the frame
    ),
  )
  // A fill that is none is an argument too.
  assert_eq(
    typst_error("columns: (auto,), frame-fill: none, ([A],), ()"),
    "assertion failed: " +
    first_error(
      Document([@kit.DataTable(["A"], [], columns=[Auto], frame_fill=None)]),
    ),
  )
  // And both take rows that fit, with spans over columns and rows.
  let fits = "columns: (auto, auto, auto), ([A], table.cell(colspan: 2)[B]), ((table.cell(rowspan: 2)[t], [b], [c]), ([e], [f]), (table.cell(colspan: 3)[w],))"
  assert_eq(typst_error(fits), "")
  assert_eq(
    first_error(
      Document([
        @kit.DataTable(
          ["A", TableCell("B", colspan=2)],
          [
            [TableCell("t", rowspan=2), "b", "c"],
            ["e", "f"],
            [TableCell("w", colspan=3)],
          ],
          columns=three,
        ),
      ]),
    ),
    "",
  )
}
