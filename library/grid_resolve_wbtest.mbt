// Unit tests for cell grid resolution (`layout/grid/resolve.rs`).

///|
fn tc(text : String) -> TableChild {
  Item(Cell(TableCell::new(TextElem::packed(text)).0))
}

///|
fn tcell(text : String, f : (TableCell) -> TableCell) -> TableChild {
  Item(Cell(f(TableCell::new(TextElem::packed(text))).0))
}

///|
fn titem(text : String) -> TableItem {
  Cell(TableCell::new(TextElem::packed(text)).0)
}

///|
fn usize(v : Int) -> Smart[USize] {
  Custom(USize(v.to_int64()))
}

///|
fn nz(v : Int) -> NonZeroUSize {
  NonZeroUSize(v.to_int64())
}

///|
/// Resolves a table and renders its entries row by row: `text@x,y` for
/// cells (`-` for empty ones, with `/CxR` for spans) and `^parent` for
/// merged positions.
fn render_table(
  columns : Int,
  children : Array[TableChild],
  gutter~ : Bool = false,
) -> String raise SourceError {
  let elem = TableElem::new(children)
    .with_columns(TrackSizings(Array::make(columns, Sizing::Auto)))
    .with_column_gutter(
      TrackSizings(if gutter { [Sizing::Rel(Rel::zero())] } else { [] }),
    )
  let grid = table_to_cellgrid(
    elem,
    wb_engine(Introspector::empty()),
    StyleChain::empty(),
  )
  let rows = []
  let cols = grid.non_gutter_column_count()
  let mut row = []
  for i, entry in grid.entries {
    row.push(
      match entry {
        Cell(cell) => {
          let body = TableCell::TableCell(cell.body)
          let text = match TextElem::of(body.body()) {
            Some(t) => t.text()
            None => "-"
          }
          let pos = match (body.x_local(), body.y_local()) {
            (Some(Custom(x)), Some(Custom(y))) => "@\{x.get()},\{y.get()}"
            _ => "@?"
          }
          let span = if cell.colspan != 1 || cell.rowspan != 1 {
            "/\{cell.colspan}x\{cell.rowspan}"
          } else {
            ""
          }
          text + pos + span
        }
        Merged(parent) => "^\{parent}"
      },
    )
    if (i + 1) % cols == 0 {
      rows.push(row.join(" "))
      row = []
    }
  }
  let mut out = rows.join(" | ")
  for header in grid.headers {
    out += " H\{header.inner.range.start}..\{header.inner.range.end}"
    if header.inner.short_lived {
      out += "!"
    }
  }
  if grid.footer is Some(footer) {
    out += " F\{footer.inner.start}..\{footer.inner.end}"
    if footer.repeated {
      out += "r"
    }
  }
  for y, lines in grid.hlines {
    for _ in lines {
      out += " hline@\{y}"
    }
  }
  out
}

///|
fn render_err(f : () -> String raise SourceError) -> String {
  f() catch {
    SourceError(errors) =>
      errors
      .map(e => ([e.message] + e.hints.map(h => h.v)).join(" | "))
      .join("; ")
  }
}

///|
test "auto placement fills rows" {
  inspect(
    render_table(2, [tc("a"), tc("b"), tc("c")]),
    content="a@0,0 b@1,0 | c@0,1 -@1,1",
  )
}

///|
test "fixed positions are skipped by auto cells" {
  inspect(
    render_table(2, [
      tcell("x", c => c.with_x(usize(0)).with_y(usize(0))),
      tc("a"),
      tc("b"),
    ]),
    content="x@0,0 a@1,0 | b@0,1 -@1,1",
  )
  inspect(
    render_table(3, [tc("a"), tcell("y", c => c.with_y(usize(1))), tc("b")]),
    content="a@0,0 b@1,0 -@2,0 | y@0,1 -@1,1 -@2,1",
  )
  inspect(
    render_table(2, [tc("a"), tcell("x", c => c.with_x(usize(0))), tc("b")]),
    content="a@0,0 b@1,0 | x@0,1 -@1,1",
  )
}

///|
test "colspan and rowspan merge positions" {
  inspect(
    render_table(3, [
      tcell("a", c => c.with_colspan(nz(2))),
      tcell("b", c => c.with_rowspan(nz(2))),
      tc("c"),
      tc("d"),
    ]),
    content="a@0,0/2x1 ^0 b@2,0/1x2 | c@0,1 d@1,1 ^2",
  )
}

///|
test "headers and footers" {
  inspect(
    render_table(2, [
      Header(TableHeader::new([titem("h1"), titem("h2")]).0),
      tc("a"),
      Footer(TableFooter::new([titem("f")]).0),
    ]),
    content="h1@0,0 h2@1,0 | a@0,1 -@1,1 | f@0,2 -@1,2 H0..1 F2..3r",
  )
  // Only headers and footers: the footer does not repeat and the header is
  // short-lived.
  inspect(
    render_table(1, [
      Header(TableHeader::new([titem("h")]).0),
      Footer(TableFooter::new([titem("f")]).0),
    ]),
    content="h@0,0 | f@0,1 H0..1! F1..2",
  )
  // Gutter doubles the indices and includes adjacent gutter rows.
  inspect(
    render_table(
      1,
      [
        Header(TableHeader::new([titem("h")]).0),
        tc("a"),
        Footer(TableFooter::new([titem("f")]).0),
      ],
      gutter=true,
    ),
    content="h@0,0 | a@0,1 | f@0,2 H0..2 F3..5r",
  )
}

///|
test "header after a partially filled row starts a new row" {
  inspect(
    render_table(2, [tc("a"), Header(TableHeader::new([titem("h")]).0)]),
    content="a@0,0 -@1,0 | h@0,1 -@1,1 H1..2!",
  )
}

///|
test "auto hlines go below the last auto cell" {
  inspect(
    render_table(2, [
      Item(HLine(TableHLine::new().0)),
      tc("a"),
      tc("b"),
      Item(HLine(TableHLine::new().0)),
      tc("c"),
    ]),
    content="a@0,0 b@1,0 | c@0,1 -@1,1 hline@0 hline@1",
  )
}

///|
test "placement errors" {
  inspect(
    render_err(() => {
      render_table(2, [
        tcell("x", c => c.with_x(usize(0)).with_y(usize(0))),
        tcell("y", c => c.with_x(usize(0)).with_y(usize(0))),
      ])
    }),
    content="attempted to place a second cell at column 0, row 0 | try specifying your cells in a different order",
  )
  inspect(
    render_err(() => {
      render_table(2, [tc("a"), tcell("b", c => c.with_colspan(nz(2)))])
    }),
    content="cell's colspan would cause it to exceed the available column(s) | try placing the cell in another position or reducing its colspan",
  )
  inspect(
    render_err(() => render_table(2, [tcell("x", c => c.with_x(usize(2)))])),
    content="cell could not be placed at invalid column 2",
  )
  inspect(
    render_err(() => {
      render_table(1, [Footer(TableFooter::new([titem("f")]).0), tc("a")])
    }),
    content="footer must end at the last row",
  )
  inspect(
    render_err(() => {
      render_table(1, [
        Header(TableHeader::new([titem("h")]).0),
        tcell("x", c => c.with_y(usize(0))),
      ])
    }),
    content="cell would conflict with header also spanning row 0 | try moving the cell or the header",
  )
}
