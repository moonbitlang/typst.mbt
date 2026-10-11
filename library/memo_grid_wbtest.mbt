// A cell grid as an argument of a memoized call (`memo_grid.mbt`; slice 2
// of `docs/incremental-design.md`): two grids that were built from the same
// cells are one argument, and two that differ in one component of what
// upstream's `#[derive(PartialEq, Hash)]` of the grid types covers
// (`typst-library/src/layout/grid/resolve.rs`) are two, to the comparison
// and to the fingerprint.

///|
fn grid_test_stroke(thickness : Double) -> ResolvedStroke {
  {
    paint: Custom(Solid(color_black)),
    thickness: Custom(Abs::pt(thickness)),
    cap: Auto,
    join: Auto,
    dash: Auto,
    miter_limit: Auto,
  }
}

///|
fn grid_test_cell(text : String) -> Cell {
  {
    body: TextElem::packed(text),
    fill: Some(Solid(color_white)),
    colspan: 1,
    rowspan: 1,
    stroke: Sides::splat(Some(grid_test_stroke(1.0))),
    stroke_overridden: Sides::splat(false),
    breakable: true,
  }
}

///|
fn grid_test_line(index : Int) -> Line {
  {
    index,
    start: 0,
    end: Some(2),
    stroke: Some(grid_test_stroke(2.0)),
    position: Before,
  }
}

///|
/// A grid of two columns and three rows with a header, a footer, a merged
/// entry and lines, every part of it a new object.
fn grid_test_grid() -> CellGrid {
  {
    entries: [
      Cell({ ..grid_test_cell("a"), colspan: 2, }),
      Merged(0),
      Cell(grid_test_cell("b")),
      Cell(grid_test_cell("c")),
      Cell(grid_test_cell("d")),
      Cell(grid_test_cell("e")),
    ],
    cols: [Auto, Rel(Rel::new(Ratio::zero(), Length::from_abs(Abs::pt(30.0))))],
    rows: [Auto, Fr(Fr::new(1.0)), Auto],
    vlines: [[grid_test_line(0)], [], [grid_test_line(2)]],
    hlines: [[], [grid_test_line(1)], [], []],
    headers: [
      {
        inner: {
          range: { start: 0, end: 1, },
          level: NonZeroU32(1),
          short_lived: false,
        },
        repeated: true,
      },
    ],
    footer: Some({ inner: { start: 2, end: 3, level: 1, }, repeated: true, }),
    has_gutter: false,
  }
}

///|
/// The grid with one entry replaced.
fn grid_test_with_entry(i : Int, entry : Entry) -> CellGrid {
  let grid = grid_test_grid()
  grid.entries[i] = entry
  grid
}

///|
/// The grid with its first vertical line replaced.
fn grid_test_with_line(line : Line) -> CellGrid {
  let grid = grid_test_grid()
  grid.vlines[0][0] = line
  grid
}

///|
/// One grid per component, each differing from [grid_test_grid] in that
/// component alone.
fn grid_test_variants() -> Array[(String, () -> CellGrid)] {
  let header = (grid : CellGrid) => grid.headers[0].inner
  [
    // `CellGrid` (resolve.rs:657).
    (
      "entries: one more",
      () => {
        let grid = grid_test_grid()
        grid.entries.push(Cell(grid_test_cell("f")))
        grid
      },
    ),
    ("cols", () => { ..grid_test_grid(), cols: [Auto, Auto], }),
    (
      "cols: the size of one",
      () => {
        ..grid_test_grid(),
        cols: [
          Auto,
          Rel(Rel::new(Ratio::zero(), Length::from_abs(Abs::pt(31.0)))),
        ],
      },
    ),
    (
      "rows",
      () => { ..grid_test_grid(), rows: [Auto, Fr(Fr::new(2.0)), Auto], },
    ),
    (
      "vlines: one more",
      () => {
        let grid = grid_test_grid()
        grid.vlines[1].push(grid_test_line(1))
        grid
      },
    ),
    (
      "vlines: before one track more",
      () => {
        let grid = grid_test_grid()
        grid.vlines.push([])
        grid
      },
    ),
    (
      "hlines: one less",
      () => { ..grid_test_grid(), hlines: [[], [], [], []], },
    ),
    ("headers: none", () => { ..grid_test_grid(), headers: [], }),
    ("footer: none", () => { ..grid_test_grid(), footer: None, }),
    ("has_gutter", () => { ..grid_test_grid(), has_gutter: true, }),
    // `Entry` (:628).
    (
      "entry: merged with another parent",
      () => grid_test_with_entry(1, Merged(2)),
    ),
    (
      "entry: a cell where one was merged",
      () => grid_test_with_entry(1, Cell(grid_test_cell("a"))),
    ),
    // `Cell` (:571).
    ("cell: body", () => grid_test_with_entry(3, Cell(grid_test_cell("C")))),
    (
      "cell: fill",
      () => {
        grid_test_with_entry(
          3,
          Cell({ ..grid_test_cell("c"), fill: Some(Solid(color_black)), }),
        )
      },
    ),
    (
      "cell: no fill",
      () => {
        grid_test_with_entry(3, Cell({ ..grid_test_cell("c"), fill: None, }))
      },
    ),
    (
      "cell: colspan",
      () => {
        grid_test_with_entry(3, Cell({ ..grid_test_cell("c"), colspan: 2, }))
      },
    ),
    (
      "cell: rowspan",
      () => {
        grid_test_with_entry(3, Cell({ ..grid_test_cell("c"), rowspan: 2, }))
      },
    ),
    (
      "cell: the stroke of one side",
      () => {
        grid_test_with_entry(
          3,
          Cell({
            ..grid_test_cell("c"),
            stroke: {
              ..Sides::splat(Some(grid_test_stroke(1.0))),
              bottom: Some(grid_test_stroke(1.5)),
            },
          }),
        )
      },
    ),
    (
      "cell: no stroke on one side",
      () => {
        grid_test_with_entry(
          3,
          Cell({
            ..grid_test_cell("c"),
            stroke: { ..Sides::splat(Some(grid_test_stroke(1.0))), left: None, },
          }),
        )
      },
    ),
    (
      "cell: the stroke of the top",
      () => {
        grid_test_with_entry(
          3,
          Cell({
            ..grid_test_cell("c"),
            stroke: {
              ..Sides::splat(Some(grid_test_stroke(1.0))),
              top: Some(grid_test_stroke(0.5)),
            },
          }),
        )
      },
    ),
    (
      "cell: the stroke of the right",
      () => {
        grid_test_with_entry(
          3,
          Cell({
            ..grid_test_cell("c"),
            stroke: {
              ..Sides::splat(Some(grid_test_stroke(1.0))),
              right: Some(grid_test_stroke(0.25)),
            },
          }),
        )
      },
    ),
    (
      "cell: stroke_overridden",
      () => {
        grid_test_with_entry(
          3,
          Cell({
            ..grid_test_cell("c"),
            stroke_overridden: { ..Sides::splat(false), top: true, },
          }),
        )
      },
    ),
    (
      "cell: breakable",
      () => {
        grid_test_with_entry(
          3,
          Cell({ ..grid_test_cell("c"), breakable: false, }),
        )
      },
    ),
    // `Line` (:396).
    (
      "line: index",
      () => grid_test_with_line({ ..grid_test_line(0), index: 1, }),
    ),
    (
      "line: start",
      () => grid_test_with_line({ ..grid_test_line(0), start: 1, }),
    ),
    (
      "line: end",
      () => grid_test_with_line({ ..grid_test_line(0), end: None, }),
    ),
    (
      "line: stroke",
      () => {
        grid_test_with_line({
          ..grid_test_line(0),
          stroke: Some(grid_test_stroke(3.0)),
        })
      },
    ),
    (
      "line: position",
      () => grid_test_with_line({ ..grid_test_line(0), position: After, }),
    ),
    // `Header` (:426), `Repeatable` (:470).
    (
      "header: range",
      () => {
        let grid = grid_test_grid()
        header(grid).range = { start: 0, end: 2, }
        grid
      },
    ),
    (
      "header: level",
      () => {
        ..grid_test_grid(),
        headers: [
          {
            inner: {
              range: { start: 0, end: 1, },
              level: NonZeroU32(2),
              short_lived: false,
            },
            repeated: true,
          },
        ],
      },
    ),
    (
      "header: short_lived",
      () => {
        let grid = grid_test_grid()
        header(grid).short_lived = true
        grid
      },
    ),
    (
      "header: repeated",
      () => {
        let grid = grid_test_grid()
        grid.headers[0] = { ..grid.headers[0], repeated: false, }
        grid
      },
    ),
    // `Footer` (:445).
    (
      "footer: start",
      () => {
        ..grid_test_grid(),
        footer: Some({ inner: { start: 1, end: 3, level: 1, }, repeated: true, }),
      },
    ),
    (
      "footer: end",
      () => {
        ..grid_test_grid(),
        footer: Some({ inner: { start: 2, end: 4, level: 1, }, repeated: true, }),
      },
    ),
    (
      "footer: level",
      () => {
        ..grid_test_grid(),
        footer: Some({ inner: { start: 2, end: 3, level: 2, }, repeated: true, }),
      },
    ),
    (
      "footer: repeated",
      () => {
        ..grid_test_grid(),
        footer: Some({
          inner: { start: 2, end: 3, level: 1, },
          repeated: false,
        }),
      },
    ),
  ]
}

///|
test "grid: two grids of the same cells are one argument" {
  let a = Value::Dyn(CellGrid(grid_test_grid()))
  let b = Value::Dyn(CellGrid(grid_test_grid()))
  // No part of the one is an object of the other.
  guard (a, b) is (Dyn(CellGrid(x)), Dyn(CellGrid(y))) else { fail("grids") }
  assert_false(physical_equal(x, y))
  assert_false(physical_equal(x.entries, y.entries))
  assert_true(values_memo_equal(a, b))
  assert_true(values_memo_equal(b, a))
  assert_eq(hash128(a), hash128(b))
  // Inside the element that holds it and the block that captures that
  // element, as a table's is (`BlockElem::multi_layouter`).
  let elem = TextElem::packed("x").elem()
  let table = (grid : Value) => Content::from_fields(elem, [Some(grid)])
  assert_true(content_memo_equal(table(a), table(b)))
  assert_eq(hash128(table(a)), hash128(table(b)))
}

///|
test "grid: a grid that differs in one component is another argument" {
  let base = Value::Dyn(CellGrid(grid_test_grid()))
  let seen : Array[(U128, String)] = [(hash128(base), "the grid")]
  for variant in grid_test_variants() {
    let (name, make) = variant
    let value = Value::Dyn(CellGrid(make()))
    // The comparison, in both directions.
    if values_memo_equal(base, value) || values_memo_equal(value, base) {
      fail("\{name}: equal to the grid")
    }
    // Made again, it is the same argument.
    if !values_memo_equal(value, Dyn(CellGrid(make()))) {
      fail("\{name}: not equal to itself")
    }
    // The fingerprint: no two of them share one.
    let hash = hash128(value)
    if hash != hash128(Value::Dyn(CellGrid(make()))) {
      fail("\{name}: two fingerprints for one grid")
    }
    for other in seen {
      if other.0 == hash {
        fail("\{name}: the fingerprint of \{other.1}")
      }
    }
    seen.push((hash, name))
  }
  // And through the element that holds the grid.
  let elem = TextElem::packed("x").elem()
  let table = (grid : CellGrid) => {
    Content::from_fields(elem, [Some(Dyn(CellGrid(grid)))])
  }
  for variant in grid_test_variants() {
    let (name, make) = variant
    if content_memo_equal(table(grid_test_grid()), table(make())) {
      fail("\{name}: the element is equal")
    }
  }
}

///|
/// Where the comparison is finer than `==` and than the fingerprint: a
/// host closure compares as the object it is, and its part in a
/// fingerprint is a key of the host's.
test "grid: host closures in a body, a fill and a stroke are compared as objects" {
  let one = memo_test_host("same", 1)
  let other = memo_test_host("same", 2)
  let node = @syntax.parse_code("x")
  let elem = TextElem::packed("x").elem()
  let body = (host : HostFunc) => {
    Content::from_fields(elem, [
      Some(test_closure(node, Func(Func::host(host)))),
    ])
  }
  let tiling = (host : HostFunc) => {
    let frame = Frame::soft(Axes::new(Abs::pt(10.0), Abs::pt(10.0)))
    frame.push(
      Point::zero(),
      Tag(Start(body(host), { introspectable: true, tagged: false, })),
    )
    test_tiling(frame)
  }
  let makers : Array[(String, (HostFunc) -> CellGrid)] = [
    (
      "body",
      host => {
        grid_test_with_entry(
          3,
          Cell({ ..grid_test_cell("c"), body: body(host), }),
        )
      },
    ),
    (
      "fill",
      host => {
        grid_test_with_entry(
          3,
          Cell({ ..grid_test_cell("c"), fill: Some(Tiling(tiling(host))), }),
        )
      },
    ),
    (
      "stroke",
      host => {
        grid_test_with_entry(
          3,
          Cell({
            ..grid_test_cell("c"),
            stroke: {
              ..Sides::splat(Some(grid_test_stroke(1.0))),
              right: Some({
                ..grid_test_stroke(1.0),
                paint: Custom(Tiling(tiling(host))),
              }),
            },
          }),
        )
      },
    ),
    (
      "the stroke of a line",
      host => {
        grid_test_with_line({
          ..grid_test_line(0),
          stroke: Some({
            ..grid_test_stroke(2.0),
            paint: Custom(Tiling(tiling(host))),
          }),
        })
      },
    ),
  ]
  for maker in makers {
    let (name, make) = maker
    let a = Value::Dyn(CellGrid(make(one)))
    let b = Value::Dyn(CellGrid(make(other)))
    // One fingerprint, and equal to `==`.
    assert_eq(hash128(a), hash128(b))
    guard (a, b) is (Dyn(CellGrid(x)), Dyn(CellGrid(y))) else { fail("grids") }
    if x != y {
      fail("\{name}: `==` tells them apart")
    }
    // Two arguments.
    if values_memo_equal(a, b) || values_memo_equal(b, a) {
      fail("\{name}: one argument")
    }
    if !values_memo_equal(a, Dyn(CellGrid(make(one)))) {
      fail("\{name}: not equal to itself")
    }
  }
}
