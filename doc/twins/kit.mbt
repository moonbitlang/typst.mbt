// Twins of the kit (docs/edsl-ports.md, section 4): an element of
// `doc/kit` is an expansion into constructors of `doc`, and its twin is a
// Typst function with the same expansion, written with the same
// primitives. The documents below call the element and the function with
// the same arguments.
//
// Two things differ between a Typst function and an element, and the
// documents are written around them:
// - the definition of the function is an expression of the markup, whose
//   value is `none`: the EDSL document starts with `Value::none()`;
// - an expression in the body of the function has one span for all calls
//   of the function, while every call of the element is a call site of its
//   own. Two calls that make equal elements (two empty grids) therefore
//   make one element twice for Typst (one key, told apart by their order)
//   and two elements for the EDSL, which the frame dump shows in the
//   numbers of the keys. No document here calls an element twice with
//   arguments that make equal elements; using one description twice is
//   the same on both sides.

///|
using @doc {type Pad, type SetGrid, type SetTable, type Stroke}

///|
/// The Typst functions of the kit's elements: one string each, since the
/// definition of a function is an expression of the markup.
///
/// `cards`: the items are the positional arguments; the named ones are
/// those of `@kit.Cards` with Typst's names. Like the element it passes on
/// only the arguments that it was given (`pick`), so that the fields of
/// the primitives that were not set stay unset.
let kit_typ : String =
  #|#let cards(..args) = {
  #|  let items = args.pos()
  #|  let named = args.named()
  #|  let pick(..keys) = {
  #|    let out = (:)
  #|    for key in keys.pos() {
  #|      if key in named { out.insert(key, named.at(key)) }
  #|    }
  #|    out
  #|  }
  #|  // One row of equally wide cards unless the caller says otherwise.
  #|  let columns = named.at("columns", default: (1fr,) * items.len())
  #|  let look = pick("fill", "stroke", "inset")
  #|  if "radius" not in named or items.len() == 0 {
  #|    // The cells draw the cards.
  #|    return grid(
  #|      columns: columns,
  #|      ..pick("gutter", "column-gutter", "row-gutter"),
  #|      ..items.map(item => grid.cell(..look, item)),
  #|    )
  #|  }
  #|  // The rows are measured one by one, which an `auto` column forbids.
  #|  assert(
  #|    columns.len() > 0 and auto not in columns,
  #|    message: "`Cards` with a `radius` cannot have an `Auto` column: its rows are measured one by one, and an `auto` column is as wide as the widest card of all rows",
  #|  )
  #|  // A card as a block: what is measured (without a height) and what is
  #|  // placed (with the height of its row). The grid only places them.
  #|  let card(item, ..size) = block(
  #|    width: 100%,
  #|    ..size,
  #|    ..look,
  #|    radius: named.radius,
  #|    item,
  #|  )
  #|  layout(size => {
  #|    let cells = ()
  #|    let start = 0
  #|    while start < items.len() {
  #|      let row = items.slice(start, calc.min(start + columns.len(), items.len()))
  #|      // The row, as the grid lays it out at the width of the region.
  #|      let probe = grid(
  #|        columns: columns,
  #|        inset: 0pt,
  #|        ..pick("gutter", "column-gutter"),
  #|        ..row.map(item => card(item, breakable: false)),
  #|      )
  #|      let height = if size.width.pt() == float.inf {
  #|        measure(probe).height
  #|      } else {
  #|        measure(probe, width: size.width).height
  #|      }
  #|      cells += row.map(item => if height > size.height {
  #|        // No page holds this row: its cards may break.
  #|        card(item)
  #|      } else {
  #|        card(item, height: height, breakable: false)
  #|      })
  #|      start += columns.len()
  #|    }
  #|    grid(
  #|      columns: columns,
  #|      inset: 0pt,
  #|      ..pick("gutter", "column-gutter", "row-gutter"),
  #|      ..cells,
  #|    )
  #|  })
  #|};

///|
/// `chip`: the label or the body is the positional argument; the named
/// ones are those of `@kit.Chip` with Typst's names. A string is a label
/// (`@kit.Chip(..)`), content a body (`@kit.Chip::of(..)`).
let chip_typ : String =
  #|#let chip(body, ..args) = {
  #|  let named = args.named()
  #|  let look = (:)
  #|  for key in ("fill", "stroke", "radius") {
  #|    if key in named { look.insert(key, named.at(key)) }
  #|  }
  #|  box(
  #|    ..look,
  #|    // The padding to the sides in the box, above and below around it.
  #|    inset: named.at("inset", default: (x: 0.6em)),
  #|    outset: named.at("outset", default: (y: 0.3em)),
  #|    // A label is not broken at a space.
  #|    if type(body) == str { body.replace(" ", "\u{a0}") } else { body },
  #|  )
  #|};

///|
/// `data-table`: the head and the rows are the positional arguments, the
/// rows an array of arrays of cells; the named ones are those of
/// `@kit.DataTable` with Typst's names (but `key`, which is not content).
/// It checks the rows as the element does, with its messages.
let data_table_typ : String =
  #|#let data-table(head, rows, ..args) = {
  #|  let named = args.named()
  #|  let columns = named.columns
  #|  let count = columns.len()
  #|  assert(
  #|    count > 0,
  #|    message: "a `DataTable` needs its `columns`: a track for every cell of a row",
  #|  )
  #|  let framed = "radius" in named
  #|  assert(
  #|    framed or "frame-fill" not in named,
  #|    message: "a `DataTable` has a frame only with a `radius`: `frame_fill` is the fill of the frame",
  #|  )
  #|  // The columns and the rows that a cell takes; `none` for what a table
  #|  // does not place in its row.
  #|  let spans(cell) = {
  #|    if type(cell) != content { return (1, 1) }
  #|    let kind = cell.func()
  #|    if kind in (table.hline, table.vline, table.header, table.footer) {
  #|      return none
  #|    }
  #|    if kind != table.cell { return (1, 1) }
  #|    let fields = cell.fields()
  #|    if fields.at("x", default: auto) != auto { return none }
  #|    if fields.at("y", default: auto) != auto { return none }
  #|    (
  #|      calc.max(1, fields.at("colspan", default: 1)),
  #|      calc.max(1, fields.at("rowspan", default: 1)),
  #|    )
  #|  }
  #|  let name(row) = if row < 0 { "`head`" } else { "`rows[" + str(row) + "]`" }
  #|  let columns-of(n) = if n == 1 { "1 column" } else { str(n) + " columns" }
  #|  // Per column: how many rows from here on a cell from above takes it,
  #|  // and the row of that cell.
  #|  let taken = (0,) * count
  #|  let from = (0,) * count
  #|  for row in range(if head.len() == 0 { 0 } else { -1 }, rows.len()) {
  #|    let cells = if row < 0 { head } else { rows.at(row) }
  #|    let all = cells.map(spans)
  #|    assert(
  #|      none not in all,
  #|      message: name(row) + " has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells",
  #|    )
  #|    let own = all.map(span => span.first()).sum(default: 0)
  #|    let above = taken.filter(rest => rest > 0).len()
  #|    let beside = if above == 0 { "" } else {
  #|      " beside the " + str(above) + " that cells of the rows above take"
  #|    }
  #|    assert(
  #|      own + above == count,
  #|      message: name(row) + " has cells for " + columns-of(own) + beside + ": this `DataTable` has " + columns-of(count),
  #|    )
  #|    // The cells in their columns.
  #|    let below = (0,) * count
  #|    let column = 0
  #|    for (colspan, rowspan) in all {
  #|      while column < count and taken.at(column) > 0 { column += 1 }
  #|      for at in range(column, column + colspan) {
  #|        assert(
  #|          at < count and taken.at(at) == 0,
  #|          message: "a cell of " + name(row) + " spans into a column that a cell of the rows above takes",
  #|        )
  #|        below.at(at) = rowspan - 1
  #|      }
  #|      column += colspan
  #|    }
  #|    for column in range(count) {
  #|      if taken.at(column) > 0 {
  #|        taken.at(column) -= 1
  #|      } else {
  #|        taken.at(column) = below.at(column)
  #|        from.at(column) = row
  #|      }
  #|    }
  #|    // The header is one row.
  #|    assert(
  #|      row >= 0 or taken.all(rest => rest == 0),
  #|      message: "a cell of `head` spans rows: the header of a `DataTable` is one row",
  #|    )
  #|  }
  #|  for column in range(count) {
  #|    assert(
  #|      taken.at(column) == 0,
  #|      message: "a cell of " + name(from.at(column)) + " spans rows below the last row of `rows`",
  #|    )
  #|  }
  #|  let look = (:)
  #|  for key in ("inset", "align", "fill") {
  #|    if key in named { look.insert(key, named.at(key)) }
  #|  }
  #|  // The rule, or the default stroke.
  #|  let rule = named.at("stroke", default: stroke())
  #|  let cells = table(
  #|    columns: columns,
  #|    ..look,
  #|    // The sides that are not named would be the table's default stroke.
  #|    stroke: (bottom: rule, rest: none),
  #|    ..if head.len() > 0 { (table.header(..head),) },
  #|    ..rows.flatten(),
  #|    // The frame closes the table, and each of its parts on a page.
  #|    ..if framed { (table.hline(stroke: none),) },
  #|  )
  #|  let ruled = [#set table.cell(breakable: named.at("breakable", default: false));#cells]
  #|  if framed {
  #|    // The surface is the frame's: beneath its outline.
  #|    let surface = if "frame-fill" in named { (fill: named.frame-fill) }
  #|    block(..surface, stroke: rule, radius: named.radius, clip: true, ruled)
  #|  } else {
  #|    ruled
  #|  }
  #|};

///|
/// A text of `count` words.
fn words(count : Int) -> String {
  Array::make(count, "word").join(" ")
}

///|
/// The twins of the kit.
pub fn kit() -> Array[Twin] {
  let hairline : Sides[Stroke] = Sides(
    all=Stroke(thickness=Pt(0.5), paint=Luma(120)),
  )
  [
    // `Cards` without a radius: the cells of a grid draw the cards.
    twin(
      "kit-cards",
      [
        kit_typ,
        page_typ,
        "#\"Before.\"",
        "#cards(gutter: (6pt,), fill: luma(230), stroke: 0.5pt + luma(120), inset: 4pt, [#\"One.\"], [#\"Two has more words than fit one line of a card.\"], emph[#\"Three.\"])",
        // Tracks of its own, a last row that is not full, and an item
        // that is higher than what is left of the page.
        "#cards(columns: (40pt, 1fr, 2fr), column-gutter: (3pt,), row-gutter: (5pt,), inset: (x: 3pt, y: 2pt), fill: rgb(\"#eef\"), [#\"a\"], [#\"b\"], [#\"c\"], [#\"d\"], [#\"\{words(40)}\"])",
        // Nothing given, and nothing to show.
        "#cards([#\"plain\"], [#\"cards\"])",
        "#cards(fill: red)",
        // In a container, and under a set rule for its primitive.
        "#pad(x: 20pt, cards(columns: (1fr, 1fr), gutter: (4pt,), stroke: 0.5pt + luma(120), [#\"padded\"], [#\"cards in a narrower region\"]))",
        "#[#set grid(inset: 2pt);#cards(fill: luma(230), [#\"set\"], [#\"rule\"])]",
      ],
      () => {
        Document([
          Value::none(),
          page(),
          "Before.",
          @kit.Cards(
            [
              "One.",
              "Two has more words than fit one line of a card.",
              Emph("Three."),
            ],
            gutter=[Pt(6)],
            fill=Luma(230),
            stroke=hairline,
            inset=Sides(all=Pt(4)),
          ),
          @kit.Cards(
            ["a", "b", "c", "d", words(40)],
            columns=[Pt(40), Fr(1), Fr(2)],
            column_gutter=[Pt(3)],
            row_gutter=[Pt(5)],
            inset=Sides(x=Pt(3), y=Pt(2)),
            fill=Rgb("#eef"),
          ),
          @kit.Cards(["plain", "cards"]),
          @kit.Cards([], fill=Red),
          Pad(
            @kit.Cards(
              ["padded", "cards in a narrower region"],
              columns=[Fr(1), Fr(1)],
              gutter=[Pt(4)],
              stroke=hairline,
            ),
            x=Pt(20),
          ),
          Seq([
            SetGrid(inset=Cells::all(Sides(all=Pt(2)))),
            @kit.Cards(["set", "rule"], fill=Luma(230)),
          ]),
        ])
      },
    ),
    // `Cards` with a radius: the rows are measured, the cards are rounded
    // unbreakable blocks of the height of their row.
    twin(
      "kit-cards-radius",
      [
        kit_typ,
        page_typ,
        "#\"Before.\"",
        "#cards(gutter: (6pt,), fill: luma(230), stroke: 0.5pt + luma(120), inset: 4pt, radius: 3pt, [#\"One.\"], [#\"Two has more words than fit one line of a card.\"], emph[#\"Three.\"])",
        // Tracks of its own, corners of their own and a last row that is
        // not full.
        "#cards(columns: (40pt, 1fr, 2fr), column-gutter: (3pt,), row-gutter: (5pt,), inset: (x: 3pt, y: 2pt), fill: rgb(\"#eef\"), radius: (top-left: 6pt, rest: 1pt), [#\"a\"], [#\"b\"], [#\"c\"], [#\"d\"], [#\"\{words(12)}\"])",
        // A row that no page holds: its cards break.
        "#cards(columns: (1fr, 3fr), gutter: (4pt,), fill: luma(230), inset: 3pt, radius: 3pt, [#\"beside\"], [#\"\{words(150)}\"], [#\"after\"])",
        // Nothing but a radius, and nothing to show.
        "#cards(radius: 2pt, [#\"plain\"], [#\"cards\"])",
        "#cards(radius: 2pt)",
        // In a container, and the same cards used twice.
        "#pad(x: 20pt, cards(columns: (1fr, 1fr), gutter: (4pt,), stroke: 0.5pt + luma(120), radius: 4pt, [#\"padded\"], [#\"cards in a narrower region\"]))",
        "#let twice = cards(fill: luma(230), radius: 2pt, inset: 2pt, [#\"used\"], [#\"twice, in two places\"]);#twice#twice",
        // An inset that the document sets for grids is not the cards'.
        "#[#set grid(inset: 5pt);#cards(fill: luma(230), radius: 2pt, [#\"set\"], [#\"rule\"])]",
      ],
      () => {
        let twice = @kit.Cards(
          ["used", "twice, in two places"],
          fill=Luma(230),
          radius=Corners(all=Pt(2)),
          inset=Sides(all=Pt(2)),
        )
        Document([
          Value::none(),
          page(),
          "Before.",
          @kit.Cards(
            [
              "One.",
              "Two has more words than fit one line of a card.",
              Emph("Three."),
            ],
            gutter=[Pt(6)],
            fill=Luma(230),
            stroke=hairline,
            inset=Sides(all=Pt(4)),
            radius=Corners(all=Pt(3)),
          ),
          @kit.Cards(
            ["a", "b", "c", "d", words(12)],
            columns=[Pt(40), Fr(1), Fr(2)],
            column_gutter=[Pt(3)],
            row_gutter=[Pt(5)],
            inset=Sides(x=Pt(3), y=Pt(2)),
            fill=Rgb("#eef"),
            radius=Corners(top_left=Pt(6), rest=Pt(1)),
          ),
          @kit.Cards(
            ["beside", words(150), "after"],
            columns=[Fr(1), Fr(3)],
            gutter=[Pt(4)],
            fill=Luma(230),
            inset=Sides(all=Pt(3)),
            radius=Corners(all=Pt(3)),
          ),
          @kit.Cards(["plain", "cards"], radius=Corners(all=Pt(2))),
          @kit.Cards([], radius=Corners(all=Pt(2))),
          Pad(
            @kit.Cards(
              ["padded", "cards in a narrower region"],
              columns=Sizing::repeat(2, size=Fr(1)),
              gutter=[Pt(4)],
              stroke=hairline,
              radius=Corners(all=Pt(4)),
            ),
            x=Pt(20),
          ),
          // (The binding of `twice` in the markup.)
          Value::none(),
          twice,
          twice,
          Seq([
            SetGrid(inset=Cells::all(Sides(all=Pt(5)))),
            @kit.Cards(
              ["set", "rule"],
              fill=Luma(230),
              radius=Corners(all=Pt(2)),
            ),
          ]),
        ])
      },
    ),
    // `Chip`: a box in a line, its paddings to the sides inside it and
    // above and below around it; a label has no-break spaces.
    twin(
      "kit-chip",
      [
        chip_typ, page_typ, "#par[#\"Two reviews are \"#chip(\"still open\", fill: luma(220), radius: 4pt)#\" and one is \"#text(size: 7pt, weight: \"semibold\", fill: blue, chip(\"done\", stroke: 0.5pt + luma(120), radius: 6pt))#\", which the paragraph goes on about for another line.\"]",
        // In a column that is narrower than the label, and in one that is
        // as wide as its content.
         "#table(columns: (60pt, 1fr), chip(\"awaiting a second review\", fill: luma(230)), [#\"next\"])",
        "#table(columns: (auto, 1fr), chip(\"awaiting a third review\", fill: luma(230)), [#\"next\"])",
        // Paddings of its own, and content.
         "#chip(fill: yellow, inset: (x: 3pt), outset: (y: 2pt, right: 1pt), \"tight\")",
        "#chip(fill: luma(230), [#strong[#\"3\"]#\" to do\"])",
        // Nothing but a label.
         "#chip(\"plain\")",
      ],
      () => {
        Document([
          Value::none(),
          page(),
          Par(
            Seq([
              "Two reviews are ",
              @kit.Chip("still open", fill=Luma(220), radius=Corners(all=Pt(4))),
              " and one is ",
              Text(
                @kit.Chip(
                  "done",
                  stroke=Sides(all=Stroke(thickness=Pt(0.5), paint=Luma(120))),
                  radius=Corners(all=Pt(6)),
                ),
                size=Pt(7),
                weight=SemiBold,
                fill=Blue,
              ),
              ", which the paragraph goes on about for another line.",
            ]),
          ),
          Table(
            [@kit.Chip("awaiting a second review", fill=Luma(230)), "next"],
            columns=[Pt(60), Fr(1)],
          ),
          Table(
            [@kit.Chip("awaiting a third review", fill=Luma(230)), "next"],
            columns=[Auto, Fr(1)],
          ),
          @kit.Chip(
            "tight",
            fill=Yellow,
            inset=Sides(x=Pt(3)),
            outset=Sides(y=Pt(2), right=Pt(1)),
          ),
          @kit.Chip::of(Seq([Strong("3"), " to do"]), fill=Luma(230)),
          @kit.Chip("plain"),
        ])
      },
    ),
    // `DataTable` without a frame: a table with a header, unbreakable
    // cells and a rule under each row.
    twin(
      "kit-data-table",
      [
        data_table_typ,
        page_typ,
        // Cells that span, numbers to the right, a rule of its own.
        "#data-table(columns: (auto, 1fr, auto), align: (left, left, right), stroke: 0.5pt + luma(120), ([#\"Bed\"], [#\"Crop\"], [#\"kg\"]), (([#\"north\"], [#\"beans\"], [#\"4.5\"]), (table.cell(rowspan: 2)[#\"south\"], emph[#\"chard\"], [#\"12.0\"]), ([#\"kale\"], [#\"3.1\"]), (table.cell(colspan: 2)[#\"all beds\"], [#\"19.6\"])))",
        // Nothing but the cells: the default stroke; no head; no rows.
        "#data-table(columns: (1fr, 1fr), ([#\"A\"], [#\"B\"]), (([#\"a\"], [#\"b\"]),))",
        "#data-table(columns: (auto, auto), (), (([#\"no\"], [#\"head\"]),))",
        "#data-table(columns: (auto,), ([#\"No rows\"],), ())",
        // The text is styled by rules of the document, and the table's
        // other parameters by a set rule; a marked row and the fill of the
        // header by a function of the caller.
        "#[#set text(size: 8pt);#set table(row-gutter: (2pt,));#show table.cell.where(x: 1): set text(fill: blue);#show table.cell.where(y: 0): set text(size: 6pt, weight: \"bold\");#data-table(columns: (1fr, auto), inset: (x: 6pt, y: 3pt), fill: (x, y) => if y == 0 { luma(220) } else if y == 2 { luma(240) }, stroke: none, ([#\"NAME\"], [#\"COUNT\"]), (([#\"first\"], [#\"7\"]), ([#\"second\"], [#\"1204\"])))]",
        // Rows that are not split, over pages; and rows that are.
        "#data-table(columns: (40pt, 1fr), stroke: 0.3pt, ([#\"Row\"], [#\"Text\"]), (([#\"one\"], [#\"\{words(30)}\"]), ([#\"two\"], [#\"\{words(45)}\"]), ([#\"three\"], [#\"short\"])))",
        "#data-table(columns: (40pt, 1fr), breakable: true, stroke: 0.6pt, ([#\"Part\"], [#\"Text\"]), (([#\"one\"], [#\"\{words(50)}\"]), ([#\"two\"], [#\"\{words(40)}\"])))",
        // In a container.
        "#pad(x: 20pt, data-table(columns: (1fr, 2fr), stroke: 0.4pt + red, ([#\"In\"], [#\"a pad\"]), (([#\"padded\"], [#\"table\"]),)))",
      ],
      () => {
        let rule = Stroke(thickness=Pt(0.5), paint=Luma(120))
        let fill : Cells[Paint] = Cells((_, y) => {
          if y == 0 {
            Luma(220)
          } else if y == 2 {
            Luma(240)
          } else {
            None
          }
        })
        Document([
          Value::none(),
          page(),
          @kit.DataTable(
            ["Bed", "Crop", "kg"],
            [
              ["north", "beans", "4.5"],
              [TableCell("south", rowspan=2), Emph("chard"), "12.0"],
              ["kale", "3.1"],
              [TableCell("all beds", colspan=2), "19.6"],
            ],
            columns=[Auto, Fr(1), Auto],
            align=Cells::columns([Left, Left, Right]),
            stroke=rule,
          ),
          @kit.DataTable(["A", "B"], [["a", "b"]], columns=[Fr(1), Fr(1)]),
          @kit.DataTable([], [["no", "head"]], columns=[Auto, Auto]),
          @kit.DataTable(["No rows"], [], columns=[Auto]),
          Seq([
            SetText(size=Pt(8)),
            SetTable(row_gutter=[Pt(2)]),
            ShowSet(Select::table_cell(x=1), SetText(fill=Blue)),
            ShowSet(Select::table_cell(y=0), SetText(size=Pt(6), weight=Bold)),
            @kit.DataTable(
              ["NAME", "COUNT"],
              [["first", "7"], ["second", "1204"]],
              columns=[Fr(1), Auto],
              inset=Cells::all(Sides(x=Pt(6), y=Pt(3))),
              fill~,
              stroke=Stroke::none(),
            ),
          ]),
          @kit.DataTable(
            ["Row", "Text"],
            [["one", words(30)], ["two", words(45)], ["three", "short"]],
            columns=[Pt(40), Fr(1)],
            stroke=Stroke(thickness=Pt(0.3)),
          ),
          @kit.DataTable(
            ["Part", "Text"],
            [["one", words(50)], ["two", words(40)]],
            columns=[Pt(40), Fr(1)],
            breakable=true,
            stroke=Stroke(thickness=Pt(0.6)),
          ),
          Pad(
            @kit.DataTable(
              ["In", "a pad"],
              [["padded", "table"]],
              columns=[Fr(1), Fr(2)],
              stroke=Stroke(thickness=Pt(0.4), paint=Red),
            ),
            x=Pt(20),
          ),
        ])
      },
    ),
    // `DataTable` with a radius: the table in a rounded block that clips
    // it, without a rule under the last row of the table and of a page.
    twin(
      "kit-data-table-frame",
      [
        data_table_typ,
        chip_typ,
        page_typ,
        "#\"Before.\"",
        // Over two pages, with chips in a column and fills by row.
        "#data-table(columns: (auto, 1fr, auto), align: (left, left, right), fill: (x, y) => if y == 0 { luma(225) } else if y == 4 { rgb(\"#eef\") }, stroke: 0.5pt + luma(120), radius: 4pt, ([#\"Bed\"], [#\"State\"], [#\"kg\"]), (\{garden_rows_typ()}))",
        // As wide as its table; corners of their own; the default stroke.
        "#data-table(columns: (auto, auto), radius: (top-left: 6pt, rest: 1pt), ([#\"A\"], [#\"B\"]), (([#\"narrow\"], [#\"frame\"]),))",
        // No lines, no head, rows that are split.
        "#data-table(columns: (1fr, 1fr), fill: luma(240), stroke: none, radius: 3pt, breakable: true, (), (([#\"no\"], [#\"lines\"]), ([#\"\{words(40)}\"], [#\"\{words(30)}\"])))",
        // In a container, and the same table used twice.
        "#pad(x: 20pt, data-table(columns: (1fr, 2fr), stroke: 0.4pt + red, radius: 2pt, ([#\"In\"], [#\"a pad\"]), (([#\"padded\"], [#\"table\"]),)))",
        "#let twice = data-table(columns: (1fr, 1fr), stroke: 0.3pt, radius: 5pt, ([#\"Used\"], [#\"twice\"]), (([#\"in two\"], [#\"places\"]),));#twice#twice",
      ],
      () => {
        let fill : Cells[Paint] = Cells((_, y) => {
          if y == 0 {
            Luma(225)
          } else if y == 4 {
            Rgb("#eef")
          } else {
            None
          }
        })
        let twice = @kit.DataTable(
          ["Used", "twice"],
          [["in two", "places"]],
          columns=[Fr(1), Fr(1)],
          stroke=Stroke(thickness=Pt(0.3)),
          radius=Corners(all=Pt(5)),
        )
        Document([
          // (The definitions of the two functions.)
          Value::none(),
          Value::none(),
          page(),
          "Before.",
          @kit.DataTable(
            ["Bed", "State", "kg"],
            garden_rows(),
            columns=[Auto, Fr(1), Auto],
            align=Cells::columns([Left, Left, Right]),
            fill~,
            stroke=Stroke(thickness=Pt(0.5), paint=Luma(120)),
            radius=Corners(all=Pt(4)),
            // (A key is not content: the function has none.)
            key=row => "bed \{row + 1}",
          ),
          @kit.DataTable(
            ["A", "B"],
            [["narrow", "frame"]],
            columns=[Auto, Auto],
            radius=Corners(top_left=Pt(6), rest=Pt(1)),
          ),
          @kit.DataTable(
            [],
            [["no", "lines"], [words(40), words(30)]],
            columns=[Fr(1), Fr(1)],
            fill=Cells::all(Luma(240)),
            stroke=Stroke::none(),
            radius=Corners(all=Pt(3)),
            breakable=true,
          ),
          Pad(
            @kit.DataTable(
              ["In", "a pad"],
              [["padded", "table"]],
              columns=[Fr(1), Fr(2)],
              stroke=Stroke(thickness=Pt(0.4), paint=Red),
              radius=Corners(all=Pt(2)),
            ),
            x=Pt(20),
          ),
          // (The binding of `twice` in the markup.)
          Value::none(),
          twice,
          twice,
        ])
      },
    ),
    // `DataTable` with a surface: the fill of its frame, on a page that
    // is not white.
    twin(
      "kit-data-table-surface",
      [
        data_table_typ,
        chip_typ,
        "#set page(width: 240pt, height: 160pt, margin: 12pt, fill: luma(235));",
        // Over two pages: each part is a filled box. The header and a
        // marked row have a fill of their own.
        "#data-table(columns: (auto, 1fr, auto), align: (left, left, right), fill: (x, y) => if y == 0 { luma(225) } else if y == 4 { rgb(\"#eef\") }, stroke: 0.5pt + luma(120), radius: 4pt, frame-fill: white, ([#\"Bed\"], [#\"State\"], [#\"kg\"]), (\{garden_rows_typ()}))",
        // Square corners; a surface that is not a colour; one that is
        // none.
        "#data-table(columns: (1fr, 1fr), stroke: 0.4pt + luma(120), radius: 0pt, frame-fill: white, ([#\"Square\"], [#\"frame\"]), (([#\"with a\"], [#\"surface\"]),))",
        "#data-table(columns: (1fr, 1fr), stroke: none, radius: (top: 6pt), frame-fill: gradient.linear(white, luma(200)), (), (([#\"a gradient\"], [#\"beneath\"]),))",
        "#data-table(columns: (1fr, 1fr), radius: 3pt, frame-fill: none, ([#\"No\"], [#\"surface\"]), ())",
      ],
      () => {
        let fill : Cells[Paint] = Cells((_, y) => {
          if y == 0 {
            Luma(225)
          } else if y == 4 {
            Rgb("#eef")
          } else {
            None
          }
        })
        Document([
          // (The definitions of the two functions.)
          Value::none(),
          Value::none(),
          SetPage(
            width=Pt(240),
            height=Pt(160),
            margin=Sides(all=Pt(12)),
            fill=Luma(235),
          ),
          @kit.DataTable(
            ["Bed", "State", "kg"],
            garden_rows(),
            columns=[Auto, Fr(1), Auto],
            align=Cells::columns([Left, Left, Right]),
            fill~,
            stroke=Stroke(thickness=Pt(0.5), paint=Luma(120)),
            radius=Corners(all=Pt(4)),
            frame_fill=White,
          ),
          @kit.DataTable(
            ["Square", "frame"],
            [["with a", "surface"]],
            columns=[Fr(1), Fr(1)],
            stroke=Stroke(thickness=Pt(0.4), paint=Luma(120)),
            radius=Corners(all=Pt(0)),
            frame_fill=White,
          ),
          @kit.DataTable(
            [],
            [["a gradient", "beneath"]],
            columns=[Fr(1), Fr(1)],
            stroke=Stroke::none(),
            radius=Corners(top=Pt(6)),
            frame_fill=Paint::linear([White, Luma(200)]),
          ),
          @kit.DataTable(
            ["No", "surface"],
            [],
            columns=[Fr(1), Fr(1)],
            radius=Corners(all=Pt(3)),
            frame_fill=None,
          ),
        ])
      },
    ),
  ]
}

///|
/// Which beds of the framed table are planted.
let garden : Array[Bool] = [
  true, true, false, true, true, false, true, true, true,
]

///|
/// The rows of the framed table: a bed, a chip with its state, a number.
fn garden_rows() -> Array[Array[&@doc.IntoContent]] {
  garden.mapi((i, planted) => {
    let state = if planted {
      @kit.Chip("planted", fill=Luma(225), radius=Corners(all=Pt(5)))
    } else {
      @kit.Chip("lies fallow", stroke=Sides(all=Stroke(thickness=Pt(0.4))))
    }
    let row : Array[&@doc.IntoContent] = [
      "Bed \{i + 1}",
      state,
      "\{i * 3 + 2}.5",
    ]
    row
  })
}

///|
/// The same rows as the arguments of the Typst function.
fn garden_rows_typ() -> String {
  garden
  .mapi((i, planted) => {
    let state = if planted {
      "chip(\"planted\", fill: luma(225), radius: 5pt)"
    } else {
      "chip(\"lies fallow\", stroke: 0.4pt)"
    }
    "([#\"Bed \{i + 1}\"], \{state}, [#\"\{i * 3 + 2}.5\"]),"
  })
  .join(" ")
}
