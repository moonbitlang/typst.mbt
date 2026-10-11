// The exact comparison of cell grids as arguments of memoized calls (not
// upstream: comemo takes an argument by its hash; see `memo.mbt` for why
// the port's stores also compare, [values_memo_equal]).
//
// A grid or table element holds its resolved cells in the synthesized
// `grid` field (upstream `Arc<CellGrid>`, `layout/grid/mod.rs:412`,
// `model/table.rs:281`), which every realization makes anew, and the block
// that a grid is laid out as captures that element (`BlockElem::
// multi_layouter`). So a grid is part of the key of the block's layout
// (`layout_multi_impl`) and of every layout around it, and the comparison
// must say that two grids with the same cells are the same argument, or a
// table is never found again.
//
// What is compared is what upstream's `#[derive(PartialEq, Hash)]` of the
// grid types covers (`typst-library/src/layout/grid/resolve.rs`): of a
// `CellGrid` (:657) the entries, the column and row tracks, the vertical
// and horizontal lines, the headers, the footer and whether it has
// gutters; of an `Entry` (:628) the cell or the parent it is merged with;
// of a `Cell` (:571) the body, the fill, the spans, the stroke of every
// side, which sides were overridden and whether it is breakable; of a
// `Line` (:396) the index, the start, the end, the stroke and the
// position; of a `Header` (:426) the range, the level and whether it is
// short-lived; of a `Footer` (:445) the start, the end and the level; of a
// `Repeatable` (:470) the child and whether it repeats. These are also
// what [Fingerprint] for [CellGrid] writes (`grid_resolve.mbt`), field by
// field.
//
// Where the comparison is finer than `==`: the body of a cell is compared
// like every content of a key ([content_memo_equal]: all stored fields,
// also the internal and synthesized ones, which Typst's `==` skips), and
// a tiling in a fill or a stroke with the host closures of its frame as
// objects ([hosts_memo_equal], as for a tiling that is a value).

///|
/// Whether two cell grids are one argument of a memoized call.
fn cell_grids_memo_equal(a : CellGrid, b : CellGrid) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  // The cheap parts first: two grids that differ usually differ in their
  // shape.
  guard a.has_gutter == b.has_gutter &&
    a.entries.length() == b.entries.length() &&
    a.cols == b.cols &&
    a.rows == b.rows &&
    a.headers == b.headers &&
    a.footer == b.footer &&
    line_groups_memo_equal(a.vlines, b.vlines) &&
    line_groups_memo_equal(a.hlines, b.hlines) else {
    return false
  }
  for i in 0..<a.entries.length() {
    match (a.entries[i], b.entries[i]) {
      (Cell(x), Cell(y)) => if !cells_memo_equal(x, y) { return false }
      (Merged(x), Merged(y)) => if x != y { return false }
      _ => return false
    }
  }
  true
}

///|
/// [cell_grids_memo_equal] for one cell.
fn cells_memo_equal(a : Cell, b : Cell) -> Bool {
  physical_equal(a, b) ||
  (
    a.colspan == b.colspan &&
    a.rowspan == b.rowspan &&
    a.breakable == b.breakable &&
    a.stroke_overridden == b.stroke_overridden &&
    paints_memo_equal(a.fill, b.fill) &&
    side_strokes_memo_equal(a.stroke, b.stroke) &&
    content_memo_equal(a.body, b.body)
  )
}

///|
/// The lines before every track of one direction.
fn line_groups_memo_equal(
  a : Array[Array[Line]],
  b : Array[Array[Line]],
) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    let x = a[i]
    let y = b[i]
    if x.length() != y.length() {
      return false
    }
    for j in 0..<x.length() {
      let l = x[j]
      let m = y[j]
      if l.index != m.index ||
        l.start != m.start ||
        l.end != m.end ||
        l.position != m.position ||
        !strokes_memo_equal(l.stroke, m.stroke) {
        return false
      }
    }
  }
  true
}

///|
/// The strokes of the four sides of a cell (most cells share one object for
/// all of their sides, and with the other cells of their grid).
fn side_strokes_memo_equal(
  a : Sides[ResolvedStroke?],
  b : Sides[ResolvedStroke?],
) -> Bool {
  physical_equal(a, b) ||
  (
    strokes_memo_equal(a.left, b.left) &&
    strokes_memo_equal(a.top, b.top) &&
    strokes_memo_equal(a.right, b.right) &&
    strokes_memo_equal(a.bottom, b.bottom)
  )
}

///|
/// A resolved stroke: `==`, and the host closures of a tiling that is its
/// paint as objects.
fn strokes_memo_equal(a : ResolvedStroke?, b : ResolvedStroke?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) =>
      physical_equal(x, y) ||
      (
        x == y &&
        (match (x.paint, y.paint) {
          (Custom(Tiling(s)), Custom(Tiling(t))) => hosts_memo_equal(s, t)
          _ => true
        })
      )
    _ => false
  }
}

///|
/// A fill: `==`, and the host closures of a tiling's frame as objects.
fn paints_memo_equal(a : Paint?, b : Paint?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(Tiling(x)), Some(Tiling(y))) => x == y && hosts_memo_equal(x, y)
    (Some(x), Some(y)) => x == y
    _ => false
  }
}
