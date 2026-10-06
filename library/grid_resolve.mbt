// Port of `typst-library/src/layout/grid/resolve.rs`: resolution of grid and
// table children into a [CellGrid] (cell positioning, row/column spans,
// headers, footers and lines).
//
// Indices are `usize` upstream; here they are `Int`. User-provided indices
// that do not fit are reported as "cell position too large".

///|
/// Largest index we accept (upstream: overflow of `usize` arithmetic).
let max_grid_index : Int64 = 0x3FFFFFFFL

///|
/// Converts a user-provided `usize` into an index, saturating at
/// [max_grid_index] (larger values will then fail the overflow checks).
fn usize_index(v : Int64) -> Int {
  if v > max_grid_index {
    max_grid_index.to_int()
  } else {
    v.to_int()
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// The integers in `start..end`.
fn int_range(start : Int, end : Int) -> Array[Int] {
  let out = []
  for i in start..<end {
    out.push(i)
  }
  out
}

///|
/// `n.next_multiple_of(m)` for non-negative `n` and positive `m`.
fn next_multiple_of(n : Int, m : Int) -> Int {
  let r = n % m
  if r == 0 {
    n
  } else {
    n + (m - r)
  }
}

///|
/// Convert a grid to a cell grid.
pub fn grid_to_cellgrid(
  elem : GridElem,
  engine : Engine,
  styles : StyleChain,
) -> CellGrid raise SourceError {
  let inset = elem.inset(styles)
  let align = elem.align(styles)
  let columns = elem.columns(styles)
  let rows = elem.rows(styles)
  let column_gutter = elem.column_gutter(styles)
  let row_gutter = elem.row_gutter(styles)
  let fill = elem.fill(styles)
  let stroke = ResolvedCelled::resolve_from(elem.stroke(styles), styles)
  let tracks = Axes::new(columns.0, rows.0)
  let gutter = Axes::new(column_gutter.0, row_gutter.0)
  let resolve_item = (item : GridItem) => grid_item_to_resolvable(item, styles)
  let children = elem
    .children()
    .map(child => {
      match child {
        GridChild::Header(header) => {
          let header = GridHeader(header)
          ResolvableGridChild::Header(
            repeat=header.repeat(styles),
            level=header.level(styles),
            span=header.0.span(),
            items=header.children().map(resolve_item),
          )
        }
        GridChild::Footer(footer) => {
          let footer = GridFooter(footer)
          ResolvableGridChild::Footer(
            repeat=footer.repeat(styles),
            span=footer.0.span(),
            items=footer.children().map(resolve_item),
          )
        }
        GridChild::Item(item) => Item(grid_item_to_resolvable(item, styles))
      }
    })
  // Use trace to link back to the grid when a specific cell errors
  trace(
    span => world_range(engine.world, span),
    () => Call(Some("grid")),
    elem.0.span(),
    () => {
      resolve_cellgrid(
        tracks,
        gutter,
        children,
        fill,
        align,
        inset,
        stroke,
        engine,
        styles,
        elem.0.span(),
      )
    },
  )
}

///|
/// Convert a table to a cell grid.
pub fn table_to_cellgrid(
  elem : TableElem,
  engine : Engine,
  styles : StyleChain,
) -> CellGrid raise SourceError {
  let inset = elem.inset(styles)
  let align = elem.align(styles)
  let columns = elem.columns(styles)
  let rows = elem.rows(styles)
  let column_gutter = elem.column_gutter(styles)
  let row_gutter = elem.row_gutter(styles)
  let fill = elem.fill(styles)
  let stroke = ResolvedCelled::resolve_from(elem.stroke(styles), styles)
  let tracks = Axes::new(columns.0, rows.0)
  let gutter = Axes::new(column_gutter.0, row_gutter.0)
  let resolve_item = (item : TableItem) => {
    table_item_to_resolvable(item, styles)
  }
  let children = elem
    .children()
    .map(child => {
      match child {
        TableChild::Header(header) => {
          let header = TableHeader(header)
          ResolvableGridChild::Header(
            repeat=header.repeat(styles),
            level=header.level(styles),
            span=header.0.span(),
            items=header.children().map(resolve_item),
          )
        }
        TableChild::Footer(footer) => {
          let footer = TableFooter(footer)
          ResolvableGridChild::Footer(
            repeat=footer.repeat(styles),
            span=footer.0.span(),
            items=footer.children().map(resolve_item),
          )
        }
        TableChild::Item(item) => Item(table_item_to_resolvable(item, styles))
      }
    })
  // Use trace to link back to the table when a specific cell errors
  trace(
    span => world_range(engine.world, span),
    () => Call(Some("table")),
    elem.0.span(),
    () => {
      resolve_cellgrid(
        tracks,
        gutter,
        children,
        fill,
        align,
        inset,
        stroke,
        engine,
        styles,
        elem.0.span(),
      )
    },
  )
}

///|
/// The line position of a vertical line (shared by grid and table vlines).
fn vline_position(
  position : OuterHAlignment,
  styles : StyleChain,
) -> LinePosition {
  match position {
    Left if resolve_text_dir(styles) == RTL => After
    Right if resolve_text_dir(styles) == RTL => Before
    Start | Left => Before
    End | Right => After
  }
}

///|
/// The line position of a horizontal line.
fn hline_position(position : OuterVAlignment) -> LinePosition {
  match position {
    Top => Before
    Bottom => After
  }
}

///|
fn grid_item_to_resolvable(
  item : GridItem,
  styles : StyleChain,
) -> ResolvableGridItem[GridCell] {
  match item {
    GridItem::HLine(hline) => {
      let hline = GridHLine(hline)
      HLine({
        index: hline.y(styles).map(y => usize_index(y.get())),
        start: usize_index(hline.start(styles).get()),
        end: hline.end(styles).map(end => usize_index(end.get())),
        stroke: hline.stroke(styles).map(s => s.resolve(styles)),
        span: hline.0.span(),
        position: hline_position(hline.position(styles)),
      })
    }
    GridItem::VLine(vline) => {
      let vline = GridVLine(vline)
      VLine({
        index: vline.x(styles).map(x => usize_index(x.get())),
        start: usize_index(vline.start(styles).get()),
        end: vline.end(styles).map(end => usize_index(end.get())),
        stroke: vline.stroke(styles).map(s => s.resolve(styles)),
        span: vline.0.span(),
        position: vline_position(vline.position(styles), styles),
      })
    }
    GridItem::Cell(cell) => Cell(GridCell(cell))
  }
}

///|
fn table_item_to_resolvable(
  item : TableItem,
  styles : StyleChain,
) -> ResolvableGridItem[TableCell] {
  match item {
    TableItem::HLine(hline) => {
      let hline = TableHLine(hline)
      HLine({
        index: hline.y(styles).map(y => usize_index(y.get())),
        start: usize_index(hline.start(styles).get()),
        end: hline.end(styles).map(end => usize_index(end.get())),
        stroke: hline.stroke(styles).map(s => s.resolve(styles)),
        span: hline.0.span(),
        position: hline_position(hline.position(styles)),
      })
    }
    TableItem::VLine(vline) => {
      let vline = TableVLine(vline)
      VLine({
        index: vline.x(styles).map(x => usize_index(x.get())),
        start: usize_index(vline.start(styles).get()),
        end: vline.end(styles).map(end => usize_index(end.get())),
        stroke: vline.stroke(styles).map(s => s.resolve(styles)),
        span: vline.0.span(),
        position: vline_position(vline.position(styles), styles),
      })
    }
    TableItem::Cell(cell) => Cell(TableCell(cell))
  }
}

///|
/// Resolves a cell's stroke override (upstream `cell.stroke.resolve(styles)`).
fn resolve_sides_stroke(
  stroke : Sides[Stroke??],
  styles : StyleChain,
) -> Sides[ResolvedStroke??] {
  stroke.map(side => side.map(inner => inner.map(s => s.resolve(styles))))
}

///|
/// Upstream `cell_stroke.fold(stroke).map(Option::flatten)` plus the
/// `stroke_overridden` computation shared by both cell types.
fn fold_cell_stroke(
  cell_stroke : Sides[ResolvedStroke??],
  stroke : Sides[ResolvedStroke??],
) -> (Sides[ResolvedStroke?], Sides[Bool]) {
  let stroke_overridden = cell_stroke.map(side => side is Some(Some(_)))
  // Using a typical 'Sides' fold, an unspecified side loses to a
  // specified side. Additionally, when both are specified, an inner
  // None wins over the outer Some, and vice-versa. When both are
  // specified and Some, fold occurs.
  //
  // In the end, we flatten because, for layout purposes, an unspecified
  // cell stroke is the same as specifying 'none', so we equate the two
  // concepts.
  let stroke = cell_stroke
    .fold(stroke)
    .map(side => {
      match side {
        Some(inner) => inner
        None => None
      }
    })
  (stroke, stroke_overridden)
}

///|
/// Here we convert the resolved stroke to a regular stroke, however with
/// resolved units (that is, 'em' converted to absolute units). We also
/// convert any stroke unspecified by both the cell and the outer stroke
/// ('None' in the folded stroke) to 'none', that is, all sides are present
/// in the resulting Sides object accessible by show rules on cells.
fn cell_stroke_field(stroke : Sides[ResolvedStroke?]) -> Sides[Stroke??] {
  stroke.map(side => Some(side.map(s => s.to_length_stroke())))
}

///|
/// Upstream `cell.align.set(...)`.
fn cell_align_field(
  align : Smart[Alignment],
  cell_align : Smart[Alignment],
) -> Smart[Alignment] {
  match align {
    Custom(align) =>
      Custom(
        match cell_align {
          Auto => align
          Custom(inner) => inner.fold(align)
        },
      )
    // Don't fold if the grid is using outer alignment. Use the
    // cell's alignment instead (which, in the end, will fold with
    // the outer alignment when it is effectively displayed).
    Auto => cell_align
  }
}

///|
/// Upstream `cell.inset.set(...)`.
fn cell_inset_field(
  inset : Sides[Rel[Length]?],
  cell_inset : Smart[Sides[Rel[Length]?]],
) -> Smart[Sides[Rel[Length]?]] {
  Custom(
    match cell_inset {
      Auto => inset
      Custom(inner) => inner.fold(inset)
    },
  )
}

///|
pub impl ResolvableCell for TableCell with fn resolve_cell(
  self,
  x,
  y,
  fill,
  align,
  inset,
  stroke,
  breakable,
  styles,
  kind,
) {
  let cell = self
  let colspan = cell.colspan(styles)
  let rowspan = cell.rowspan(styles)
  let breakable = cell.breakable(styles).unwrap_or(breakable)
  let fill = cell.fill(styles).unwrap_or(fill)
  let kind = cell.kind_in_chain(styles).or_(kind)
  let cell_stroke = resolve_sides_stroke(cell.stroke(styles), styles)
  let (stroke, stroke_overridden) = fold_cell_stroke(cell_stroke, stroke)
  let cell = cell
    .with_x(Custom(USize(x.to_int64())))
    .with_y(Custom(USize(y.to_int64())))
    .with_fill(Custom(fill))
    .with_align(cell_align_field(align, cell.align(styles)))
    .with_inset(cell_inset_field(inset, cell.inset(styles)))
    .with_stroke(cell_stroke_field(stroke))
    .with_breakable(Custom(breakable))
    .with_kind(kind)
  {
    body: cell.0,
    fill,
    colspan: usize_index(colspan.get()),
    rowspan: usize_index(rowspan.get()),
    stroke,
    stroke_overridden,
    breakable,
  }
}

///|
pub impl ResolvableCell for TableCell with fn cell_x(self, styles) {
  self.x(styles).map(x => usize_index(x.get()))
}

///|
pub impl ResolvableCell for TableCell with fn cell_y(self, styles) {
  self.y(styles).map(y => usize_index(y.get()))
}

///|
pub impl ResolvableCell for TableCell with fn cell_colspan(self, styles) {
  usize_index(self.colspan(styles).get())
}

///|
pub impl ResolvableCell for TableCell with fn cell_rowspan(self, styles) {
  usize_index(self.rowspan(styles).get())
}

///|
pub impl ResolvableCell for TableCell with fn cell_span(self) {
  self.0.span()
}

///|
pub impl ResolvableCell for TableCell with fn default_cell() {
  TableCell::default()
}

///|
pub impl ResolvableCell for GridCell with fn resolve_cell(
  self,
  x,
  y,
  fill,
  align,
  inset,
  stroke,
  breakable,
  styles,
  _kind,
) {
  let cell = self
  let colspan = cell.colspan(styles)
  let rowspan = cell.rowspan(styles)
  let breakable = cell.breakable(styles).unwrap_or(breakable)
  let fill = cell.fill(styles).unwrap_or(fill)
  let cell_stroke = resolve_sides_stroke(cell.stroke(styles), styles)
  let (stroke, stroke_overridden) = fold_cell_stroke(cell_stroke, stroke)
  let cell = cell
    .with_x(Custom(USize(x.to_int64())))
    .with_y(Custom(USize(y.to_int64())))
    .with_fill(Custom(fill))
    .with_align(cell_align_field(align, cell.align(styles)))
    .with_inset(cell_inset_field(inset, cell.inset(styles)))
    .with_stroke(cell_stroke_field(stroke))
    .with_breakable(Custom(breakable))
  {
    body: cell.0,
    fill,
    colspan: usize_index(colspan.get()),
    rowspan: usize_index(rowspan.get()),
    stroke,
    stroke_overridden,
    breakable,
  }
}

///|
pub impl ResolvableCell for GridCell with fn cell_x(self, styles) {
  self.x(styles).map(x => usize_index(x.get()))
}

///|
pub impl ResolvableCell for GridCell with fn cell_y(self, styles) {
  self.y(styles).map(y => usize_index(y.get()))
}

///|
pub impl ResolvableCell for GridCell with fn cell_colspan(self, styles) {
  usize_index(self.colspan(styles).get())
}

///|
pub impl ResolvableCell for GridCell with fn cell_rowspan(self, styles) {
  usize_index(self.rowspan(styles).get())
}

///|
pub impl ResolvableCell for GridCell with fn cell_span(self) {
  self.0.span()
}

///|
pub impl ResolvableCell for GridCell with fn default_cell() {
  GridCell::default()
}

///|
/// Represents an explicit grid line (horizontal or vertical) specified by the
/// user.
pub(all) struct Line {
  /// The index of the track after this line. This will be the index of the
  /// row a horizontal line is above of, or of the column right after a
  /// vertical line.
  ///
  /// Must be within `0..=tracks.len()` (where `tracks` is either `grid.cols`
  /// or `grid.rows`, ignoring gutter tracks, as appropriate).
  mut index : Int
  /// The index of the track at which this line starts being drawn.
  /// This is the first column a horizontal line appears in, or the first row
  /// a vertical line appears in.
  start : Int
  /// The index after the last track through which the line is drawn.
  /// Thus, the line is drawn through tracks `start..end` (note that `end` is
  /// exclusive). `None` indicates the line should go all the way to the end.
  end : Int?
  /// The line's stroke. This is `None` when the line is explicitly used to
  /// override a previously specified line.
  stroke : ResolvedStroke?
  /// The line's position in relation to the track with its index.
  position : LinePosition
} derive(Eq)

///|
/// A range of rows `start..end` (upstream `Range<usize>`).
pub(all) struct RowRange {
  start : Int
  end : Int
} derive(Eq, Hash, Debug)

///|
/// Whether the range contains the given row.
pub fn RowRange::contains(self : RowRange, row : Int) -> Bool {
  self.start <= row && row < self.end
}

///|
/// A repeatable grid header. Starts at the first row.
pub(all) struct Header {
  /// The range of rows included in this header.
  mut range : RowRange
  /// The header's level.
  ///
  /// Higher level headers repeat together with lower level headers. If a
  /// lower level header stops repeating, all higher level headers do as
  /// well.
  level : NonZeroU32
  /// Whether this header cannot be repeated nor should have orphan
  /// prevention because it would be about to cease repetition, either
  /// because it is followed by headers of conflicting levels, or because
  /// it is at the end of the table (possibly followed by some footers at the
  /// end).
  mut short_lived : Bool
} derive(Eq)

///|
/// A repeatable grid footer. Stops at the last row.
pub(all) struct Footer {
  /// The first row included in this footer.
  mut start : Int
  /// The index after the last row included in this footer.
  mut end : Int
  /// The footer's level.
  ///
  /// Used similarly to header level.
  level : Int
} derive(Eq)

///|
/// The footer's range of included rows.
pub fn Footer::range(self : Footer) -> RowRange {
  { start: self.start, end: self.end, }
}

///|
/// A possibly repeatable grid child (header or footer).
///
/// It still exists even when not repeatable, but must not have additional
/// considerations by grid layout, other than for consistency (such as making
/// a certain group of rows unbreakable).
pub(all) struct Repeatable[T] {
  inner : T
  /// Whether the user requested the child to repeat.
  repeated : Bool
} derive(Eq)

///|
/// Returns `Some` if the value is repeated, `None` otherwise.
pub fn[T] Repeatable::as_repeated(self : Repeatable[T]) -> T? {
  if self.repeated {
    Some(self.inner)
  } else {
    None
  }
}

///|
/// Used for cell-like elements which are aware of their final properties in
/// the table, and may have property overrides.
pub(open) trait ResolvableCell {
  /// Resolves the cell's fields, given its coordinates and default grid-wide
  /// fill, align, inset and stroke properties, plus the expected value of
  /// the `breakable` field.
  /// Returns a final Cell.
  fn resolve_cell(
    Self,
    Int,
    Int,
    Paint?,
    Smart[Alignment],
    Sides[Rel[Length]?],
    Sides[ResolvedStroke??],
    Bool,
    StyleChain,
    Smart[TableCellKind],
  ) -> Cell
  /// Returns this cell's column override.
  fn cell_x(Self, StyleChain) -> Smart[Int]
  /// Returns this cell's row override.
  fn cell_y(Self, StyleChain) -> Smart[Int]
  /// The amount of columns spanned by this cell.
  fn cell_colspan(Self, StyleChain) -> Int
  /// The amount of rows spanned by this cell.
  fn cell_rowspan(Self, StyleChain) -> Int
  /// The cell's span, for errors.
  fn cell_span(Self) -> @syntax.Span
  /// An empty cell used to fill positions which weren't explicitly specified
  /// by the user (upstream `Default`).
  fn default_cell() -> Self
}

///|
/// An automatically positionable line (the fields of upstream's
/// `ResolvableGridItem::HLine` and `::VLine`).
pub(all) struct ResolvableLine {
  /// The row above which the horizontal line is drawn, or the column before
  /// which the vertical line is drawn.
  index : Smart[Int]
  start : Int
  end : Int?
  stroke : ResolvedStroke?
  /// The span of the corresponding line element.
  span : @syntax.Span
  /// The line's position. For hlines, "before" means on top of row `y`,
  /// while "after" means below it. For vlines, "before" means to the left of
  /// column `x`, while "after" means to its right (both considering LTR).
  position : LinePosition
}

///|
/// A grid item, possibly affected by automatic cell positioning. Can be either
/// a line or a cell.
pub(all) enum ResolvableGridItem[T] {
  /// A horizontal line in the grid.
  HLine(ResolvableLine)
  /// A vertical line in the grid.
  VLine(ResolvableLine)
  /// A cell in the grid.
  Cell(T)
}

///|
/// Represents a cell in [CellGrid], to be laid out by `GridLayouter`.
pub(all) struct Cell {
  /// The cell's body.
  body : Content
  /// The cell's fill.
  fill : Paint?
  /// The amount of columns spanned by the cell.
  colspan : Int
  /// The amount of rows spanned by the cell.
  rowspan : Int
  /// The cell's stroke.
  stroke : Sides[ResolvedStroke?]
  /// Which stroke sides were explicitly overridden by the cell, over the
  /// grid's global stroke setting.
  ///
  /// This is used to define whether or not this cell's stroke sides should
  /// have priority over adjacent cells' stroke sides, if those don't
  /// override their own stroke properties (and thus have less priority when
  /// defining with which stroke to draw grid lines around this cell).
  stroke_overridden : Sides[Bool]
  /// Whether rows spanned by this cell can be placed in different pages.
  /// By default, a cell spanning only fixed-size rows is unbreakable, while
  /// a cell spanning at least one `auto`-sized row is breakable.
  breakable : Bool
} derive(Eq)

///|
/// Create a simple cell given its body.
pub fn Cell::new(body : Content) -> Cell {
  {
    body,
    fill: None,
    colspan: 1,
    rowspan: 1,
    stroke: Sides::splat(None),
    stroke_overridden: Sides::splat(false),
    breakable: true,
  }
}

///|
/// Indicates whether the line should be drawn before or after the track with
/// its index. This is mostly only relevant when gutter is used, since, then,
/// the position after a track is not the same as before the next
/// non-gutter track.
pub(all) enum LinePosition {
  /// The line should be drawn before its track (e.g. hline on top of a row).
  Before
  /// The line should be drawn after its track (e.g. hline below a row).
  After
} derive(Eq, Hash, Debug)

///|
/// A grid entry.
pub(all) enum Entry {
  /// An entry which holds a cell.
  Cell(Cell)
  /// An entry which is merged with another cell; holds the index of the cell
  /// this entry is merged with (`parent`).
  Merged(Int)
} derive(Eq)

///|
/// Obtains the cell inside this entry, if this is not a merged cell.
pub fn Entry::as_cell(self : Entry) -> Cell? {
  match self {
    Cell(cell) => Some(cell)
    Merged(_) => None
  }
}

///|
/// Any grid child, which can be either a header or an item.
pub(all) enum ResolvableGridChild[T] {
  Header(
    repeat~ : Bool,
    level~ : NonZeroU32,
    span~ : @syntax.Span,
    items~ : Array[ResolvableGridItem[T]]
  )
  Footer(
    repeat~ : Bool,
    span~ : @syntax.Span,
    items~ : Array[ResolvableGridItem[T]]
  )
  Item(ResolvableGridItem[T])
}

///|
/// A grid of cells, including the columns, rows, and cell data.
pub(all) struct CellGrid {
  /// The grid cells.
  entries : Array[Entry]
  /// The column tracks including gutter tracks.
  cols : Array[Sizing]
  /// The row tracks including gutter tracks.
  rows : Array[Sizing]
  /// The vertical lines before each column, or on the end border.
  /// Gutter columns are not included.
  /// Contains up to `cols_without_gutter.len() + 1` vectors of lines.
  vlines : Array[Array[Line]]
  /// The horizontal lines on top of each row, or on the bottom border.
  /// Gutter rows are not included.
  /// Contains up to `rows_without_gutter.len() + 1` vectors of lines.
  hlines : Array[Array[Line]]
  /// The repeatable headers of this grid.
  headers : Array[Repeatable[Header]]
  /// The repeatable footer of this grid.
  footer : Repeatable[Footer]?
  /// Whether this grid has gutters.
  has_gutter : Bool
} derive(Eq)

///|
/// Generates the cell grid, given the tracks and cells.
pub fn CellGrid::new(
  tracks : Axes[Array[Sizing]],
  gutter : Axes[Array[Sizing]],
  cells : Array[Cell],
) -> CellGrid {
  let entries = cells.map(cell => Entry::Cell(cell))
  CellGrid::new_internal(tracks, gutter, [], [], [], None, entries)
}

///|
/// Generates the cell grid, given the tracks and resolved entries.
pub fn CellGrid::new_internal(
  tracks : Axes[Array[Sizing]],
  gutter : Axes[Array[Sizing]],
  vlines : Array[Array[Line]],
  hlines : Array[Array[Line]],
  headers : Array[Repeatable[Header]],
  footer : Repeatable[Footer]?,
  entries : Array[Entry],
) -> CellGrid {
  let cols = []
  let rows = []

  // Number of content columns: Always at least one.
  let num_cols = max_int(tracks.x.length(), 1)

  // Number of content rows: At least as many as given, but also at least
  // as many as needed to place each item.
  let num_rows = {
    let len = entries.length()
    let given = tracks.y.length()
    let needed = len / num_cols + (if len % num_cols > 0 { 1 } else { 0 })
    max_int(given, needed)
  }
  let has_gutter = gutter.any(tracks => !tracks.is_empty())
  let auto = Sizing::Auto
  let zero = Sizing::Rel(Rel::zero())
  let get_or = (tracks : Array[Sizing], idx : Int, default : Sizing) => {
    match tracks.get(idx) {
      Some(t) => t
      None =>
        match tracks.last() {
          Some(t) => t
          None => default
        }
    }
  }

  // Collect content and gutter columns.
  for x in 0..<num_cols {
    cols.push(get_or(tracks.x, x, auto))
    if has_gutter {
      cols.push(get_or(gutter.x, x, zero))
    }
  }

  // Collect content and gutter rows.
  for y in 0..<num_rows {
    rows.push(get_or(tracks.y, y, auto))
    if has_gutter {
      rows.push(get_or(gutter.y, y, zero))
    }
  }

  // Remove superfluous gutter tracks.
  if has_gutter {
    cols.pop() |> ignore
    rows.pop() |> ignore
  }
  { entries, cols, rows, vlines, hlines, headers, footer, has_gutter, }
}

///|
/// Get the grid entry in column `x` and row `y`.
///
/// Returns `None` if it's a gutter cell.
pub fn CellGrid::entry(self : CellGrid, x : Int, y : Int) -> Entry? {
  guard x < self.cols.length() && y < self.rows.length() else {
    abort("grid position out of bounds")
  }
  if self.has_gutter {
    // Even columns and rows are children, odd ones are gutter.
    if x % 2 == 0 && y % 2 == 0 {
      let c = 1 + self.cols.length() / 2
      self.entries.get(y / 2 * c + x / 2)
    } else {
      None
    }
  } else {
    let c = self.cols.length()
    self.entries.get(y * c + x)
  }
}

///|
/// Get the content of the cell in column `x` and row `y`.
///
/// Returns `None` if it's a gutter cell or merged position.
pub fn CellGrid::cell(self : CellGrid, x : Int, y : Int) -> Cell? {
  match self.entry(x, y) {
    Some(entry) => entry.as_cell()
    None => None
  }
}

///|
/// Returns the position of the parent cell of the grid entry at the given
/// position. It is guaranteed to have a non-gutter, non-merged cell at
/// the returned position, due to how the grid is built.
/// - If the entry at the given position is a cell, returns the given
///   position.
/// - If it is a merged cell, returns the parent cell's position.
/// - If it is a gutter cell, returns None.
pub fn CellGrid::parent_cell_position(
  self : CellGrid,
  x : Int,
  y : Int,
) -> Axes[Int]? {
  self
  .entry(x, y)
  .map(entry => {
    match entry {
      Cell(_) => Axes::new(x, y)
      Merged(parent) => {
        let c = self.non_gutter_column_count()
        let factor = if self.has_gutter { 2 } else { 1 }
        Axes::new(factor * (parent % c), factor * (parent / c))
      }
    }
  })
}

///|
/// Returns the position of the actual parent cell of a merged position,
/// even if the given position is gutter, in which case we return the
/// parent of the nearest adjacent content cell which could possibly span
/// the given gutter position. If the given position is not a gutter cell,
/// then this function will return the same as `parent_cell_position` would.
/// If the given position is a gutter cell, but no cell spans it, returns
/// `None`.
///
/// This is useful for lines. A line needs to check if a cell next to it
/// has a stroke override - even at a gutter position there could be a
/// stroke override, since a cell could be merged with two cells at both
/// ends of the gutter cell (e.g. to its left and to its right), and thus
/// that cell would impose a stroke under the gutter. This function allows
/// getting the position of that cell (which spans the given gutter
/// position, if it is gutter), if it exists; otherwise returns None (it's
/// gutter and no cell spans it).
pub fn CellGrid::effective_parent_cell_position(
  self : CellGrid,
  x : Int,
  y : Int,
) -> Axes[Int]? {
  if self.has_gutter {
    // If (x, y) is a gutter cell, we skip it (skip a gutter column and
    // row) to the nearest adjacent content cell, in the direction
    // which merged cells grow toward (increasing x and increasing y),
    // such that we can verify if that adjacent cell is merged with the
    // gutter cell by checking if its parent would come before (x, y).
    // Otherwise, no cell is merged with this gutter cell, and we
    // return None.
    match self.parent_cell_position(x + x % 2, y + y % 2) {
      Some(parent) if parent.x <= x && parent.y <= y => Some(parent)
      _ => None
    }
  } else {
    self.parent_cell_position(x, y)
  }
}

///|
/// Checks if the track with the given index is gutter.
/// Does not check if the index is a valid track.
pub fn CellGrid::is_gutter_track(self : CellGrid, index : Int) -> Bool {
  self.has_gutter && index % 2 == 1
}

///|
/// Returns the effective colspan of a cell, considering the gutters it
/// might span if the grid has gutters.
pub fn CellGrid::effective_colspan_of_cell(self : CellGrid, cell : Cell) -> Int {
  if self.has_gutter {
    2 * cell.colspan - 1
  } else {
    cell.colspan
  }
}

///|
/// Returns the effective rowspan of a cell, considering the gutters it
/// might span if the grid has gutters.
pub fn CellGrid::effective_rowspan_of_cell(self : CellGrid, cell : Cell) -> Int {
  if self.has_gutter {
    2 * cell.rowspan - 1
  } else {
    cell.rowspan
  }
}

///|
pub fn CellGrid::non_gutter_column_count(self : CellGrid) -> Int {
  if self.has_gutter {
    // Calculation: With gutters, we have
    // 'cols = 2 * (non-gutter cols) - 1', since there is a gutter
    // column between each regular column. Therefore,
    // 'floor(cols / 2)' will be equal to
    // 'floor(non-gutter cols - 1/2) = non-gutter-cols - 1',
    // so 'non-gutter cols = 1 + floor(cols / 2)'.
    1 + self.cols.length() / 2
  } else {
    self.cols.length()
  }
}

///|
pub fn CellGrid::non_gutter_row_count(self : CellGrid) -> Int {
  if self.has_gutter {
    // Same calculation as for columns.
    1 + self.rows.length() / 2
  } else {
    self.rows.length()
  }
}

///|
pub fn CellGrid::has_repeated_headers(self : CellGrid) -> Bool {
  self.headers.iter().any(h => h.repeated)
}

///|
/// Resolves and positions all cells in the grid before creating it.
/// Allows them to keep track of their final properties and positions
/// and adjust their fields accordingly.
/// Cells must implement `default_cell` in order to fill positions in the
/// grid which weren't explicitly specified by the user with empty cells.
pub fn[T : ResolvableCell] resolve_cellgrid(
  tracks : Axes[Array[Sizing]],
  gutter : Axes[Array[Sizing]],
  children : Array[ResolvableGridChild[T]],
  fill : Celled[Paint?],
  align : Celled[Smart[Alignment]],
  inset : Celled[Sides[Rel[Length]?]],
  stroke : ResolvedCelled,
  engine : Engine,
  styles : StyleChain,
  span : @syntax.Span,
) -> CellGrid raise SourceError {
  CellGridResolver::{
    tracks,
    gutter,
    fill,
    align,
    inset,
    stroke,
    engine,
    styles,
    span,
  }.resolve(children)
}

///|
priv struct CellGridResolver {
  tracks : Axes[Array[Sizing]]
  gutter : Axes[Array[Sizing]]
  fill : Celled[Paint?]
  align : Celled[Smart[Alignment]]
  inset : Celled[Sides[Rel[Length]?]]
  stroke : ResolvedCelled
  engine : Engine
  styles : StyleChain
  span : @syntax.Span
}

///|
priv enum RowGroupKind {
  Header
  Footer
}

///|
fn RowGroupKind::name(self : RowGroupKind) -> String {
  match self {
    Header => "header"
    Footer => "footer"
  }
}

///|
priv struct RowGroupData {
  /// The range of rows of cells inside this grid row group. The
  /// first and last rows are guaranteed to have cells (an exception
  /// is made when there is gutter, in which case the group range may
  /// be expanded to include an additional gutter row when there is a
  /// repeatable header or footer). This is `None` until the first
  /// cell of the row group is placed, then it is continually adjusted
  /// to fit the cells inside the row group.
  ///
  /// This stays as `None` for fully empty headers and footers.
  mut range : RowRange?
  span : @syntax.Span
  kind : RowGroupKind
  /// Whether this header or footer may repeat.
  repeat : Bool
  /// Level of this header or footer.
  repeatable_level : NonZeroU32
  /// Start of the range of indices of hlines at the top of the row group.
  /// This is always the first index after the last hline before we started
  /// building the row group - any upcoming hlines would appear at least at
  /// this index.
  ///
  /// These hlines were auto-positioned and appeared before any auto-pos
  /// cells, so they will appear at the first possible row (above the
  /// first row spanned by the row group).
  top_hlines_start : Int
  /// End of the range of indices of hlines at the top of the row group.
  ///
  /// This starts as `None`, meaning that, if we stop the loop before we find
  /// any auto-pos cells, all auto-pos hlines after the last hline (after the
  /// index `top_hlines_start`) should be moved to the top of the row group.
  ///
  /// It becomes `Some(index of last hline at the top)` when an auto-pos cell
  /// is found, as auto-pos hlines after any auto-pos cells appear below
  /// them, not at the top of the row group.
  mut top_hlines_end : Int?
}

///|
/// Rows occupied by an existing header (upstream `SmallBitSet`).
priv struct RowSet(Array[Bool])

///|
fn RowSet::insert(self : RowSet, row : Int) -> Unit {
  while self.0.length() <= row {
    self.0.push(false)
  }
  self.0[row] = true
}

///|
fn RowSet::contains(self : RowSet, row : Int) -> Bool {
  row >= 0 && row < self.0.length() && self.0[row]
}

///|
/// The mutable state shared by the iterations of `resolve_grid_child`
/// (upstream passes these as `&mut` arguments).
priv struct ResolveState {
  /// Horizontal lines are only pushed later to be able to check for row
  /// validity, since the amount of rows isn't known until all items were
  /// analyzed. We keep their spans so we can report errors later. The
  /// additional boolean indicates whether the hline had an automatic 'y'
  /// index, and is used to change the index of hlines at the top of a header
  /// or footer.
  pending_hlines : Array[(@syntax.Span, Line, Bool)]
  /// For consistency, only push vertical lines later as well.
  pending_vlines : Array[(@syntax.Span, Line)]
  /// Rows in this set are occupied by an existing header.
  header_rows : RowSet
  headers : Array[Repeatable[Header]]
  /// Stores where the footer is supposed to end, its span, and the actual
  /// footer structure.
  mut footer : (Int, @syntax.Span, Footer)?
  mut repeat_footer : Bool
  /// The position of the next cell with (x: auto, y: auto).
  auto_index : Ref[Int]
  resolved_cells : Array[Entry?]
  /// If true, there has been at least one cell besides headers and
  /// footers. When false, footers at the end are forced to not repeat.
  mut at_least_one_cell : Bool
}

///|
fn[T : ResolvableCell] CellGridResolver::resolve(
  self : CellGridResolver,
  children : Array[ResolvableGridChild[T]],
) -> CellGrid raise SourceError {
  // Number of content columns: Always at least one.
  let columns = max_int(self.tracks.x.length(), 1)
  let has_gutter = self.gutter.any(tracks => !tracks.is_empty())

  // We can't just use the cell's index in the 'cells' vector to
  // determine its automatic position, since cells could have arbitrary
  // positions, so the position of a cell in 'cells' can differ from its
  // final position in 'resolved_cells' (see below).
  // Therefore, we use a counter, 'auto_index', to determine the position
  // of the next cell with (x: auto, y: auto). It is only stepped when
  // a cell with (x: auto, y: auto), usually the vast majority, is found.
  let state = ResolveState::{
    pending_hlines: [],
    pending_vlines: [],
    header_rows: RowSet([]),
    headers: [],
    footer: None,
    repeat_footer: false,
    auto_index: { val: 0, },
    resolved_cells: [],
    at_least_one_cell: false,
  }
  if next_multiple_of(children.length(), columns).to_int64() > max_grid_index {
    bail_at(self.span, "too many cells or lines were given")
  }
  for child in children {
    self.resolve_grid_child(columns, state, child)
  }
  let resolved_cells : Array[Entry] = self.fixup_cells(
    state.resolved_cells,
    columns,
    (Ty::new() : Ty[T]),
  )
  let row_amount = (resolved_cells.length() + columns - 1) / columns
  let (hlines, vlines) = self.collect_lines(
    state.pending_hlines,
    state.pending_vlines,
    has_gutter,
    columns,
    row_amount,
  )
  let footer = self.finalize_headers_and_footers(
    has_gutter,
    state.headers,
    state.footer,
    state.repeat_footer,
    row_amount,
    state.at_least_one_cell,
  )
  CellGrid::new_internal(
    self.tracks,
    self.gutter,
    vlines,
    hlines,
    state.headers,
    footer,
    resolved_cells,
  )
}

///|
/// Resolve a grid child, which can be a header, a footer (both of which
/// are row groups, and thus contain multiple grid items inside them), or
/// a grid item - a cell, an hline or a vline.
///
/// This process consists of placing the child and any sub-items into
/// appropriate positions in the resolved grid. This is mostly relevant for
/// items without fixed positions, such that they must be placed after the
/// previous one, perhaps skipping existing cells along the way.
fn[T : ResolvableCell] CellGridResolver::resolve_grid_child(
  self : CellGridResolver,
  columns : Int,
  state : ResolveState,
  child : ResolvableGridChild[T],
) -> Unit raise SourceError {
  let pending_hlines = state.pending_hlines
  let resolved_cells = state.resolved_cells

  // Data for the row group in this iteration.
  //
  // Note that cells outside headers and footers are grid children
  // with a single cell inside, and thus not considered row groups,
  // in which case this variable remains 'None'.
  let mut row_group_data : RowGroupData? = None

  // Usually, the global auto index is stepped only when a cell with
  // fully automatic position (no fixed x/y) is placed, advancing one
  // position. In that usual case, 'local_auto_index == auto_index'
  // holds, as 'local_auto_index' is what the code below actually
  // updates.
  //
  // However, headers and footers must trigger a rowbreak if the
  // previous row isn't empty, given they cannot occupy only part of a
  // row. Therefore, the initial auto index used by their auto cells
  // should be right below the first empty row.
  //
  // So, we use a separate auto index counter inside the header. It starts
  // below the first non-empty row. If the header only has fixed-position
  // cells, the external counter is unchanged. Otherwise (has auto cells
  // or is empty), the external counter is synchronized and moved to
  // below the header.
  //
  // This ensures lines and cells specified below the header in the
  // source code also appear below it in the final grid/table.
  let local_auto_index = if child is Item(_) {
    // Alias the original auto index.
    state.auto_index
  } else {
    // A mutable copy of the auto index.
    { val: state.auto_index.val, }
  }

  // The first row in which this table group can fit.
  //
  // Within headers and footers, this will correspond to the first
  // fully empty row available in the grid. This is because headers
  // and footers always occupy entire rows, so they cannot occupy
  // a non-empty row.
  let mut first_available_row = 0

  // The cell kind is currently only used for tagged PDF.
  let cell_kind : Smart[TableCellKind] = match child {
    Header(level~, ..) => Custom(Header(level, Column))
    Footer(..) => Custom(Footer)
    Item(_) => Custom(Data)
  }
  let items : Array[ResolvableGridItem[T]] = match child {
    Header(repeat~, level~, span~, items~) => {
      row_group_data = Some({
        range: None,
        span,
        kind: Header,
        repeat,
        repeatable_level: level,
        top_hlines_start: pending_hlines.length(),
        top_hlines_end: None,
      })
      first_available_row = find_next_empty_row(
        resolved_cells,
        local_auto_index.val,
        columns,
      )

      // If any cell in the header is automatically positioned,
      // have it skip to the next empty row. This is to avoid
      // having a header after a partially filled row just add
      // cells to that row instead of starting a new one.
      //
      // Note that the first fully empty row is always after the
      // latest auto-position cell, since each auto-position cell
      // always occupies the first available position after the
      // previous one. Therefore, this will be >= auto_index.
      local_auto_index.val = first_available_row * columns
      items
    }
    Footer(repeat~, span~, items~) => {
      if state.footer is Some(_) {
        bail_at(span, "cannot have more than one footer")
      }
      row_group_data = Some({
        range: None,
        span,
        repeat,
        kind: Footer,
        repeatable_level: NonZeroU32(1L),
        top_hlines_start: pending_hlines.length(),
        top_hlines_end: None,
      })
      first_available_row = find_next_empty_row(
        resolved_cells,
        local_auto_index.val,
        columns,
      )
      local_auto_index.val = first_available_row * columns
      items
    }
    Item(item) => {
      if item is Cell(_) {
        state.at_least_one_cell = true
      }
      [item]
    }
  }
  let mut had_auto_cells = false
  for item in items {
    let cell = match item {
      HLine(line) => {
        let has_auto_y = line.index is Auto
        let y = match line.index {
          Custom(y) => y
          Auto => {
            // Avoid placing the hline inside consecutive
            // rowspans occupying all columns, as it'd just
            // disappear, at least when there's no column
            // gutter.
            skip_auto_index_through_fully_merged_rows(
              resolved_cells, local_auto_index, columns,
            )

            // When no 'y' is specified for the hline, we place
            // it under the latest automatically positioned
            // cell.
            // The current value of the auto index is always
            // the index of the latest automatically positioned
            // cell placed plus one (that's what we do in
            // 'resolve_cell_position'), so we subtract 1 to
            // get that cell's index, and place the hline below
            // its row. The exception is when the auto_index is
            // 0, meaning no automatically positioned cell was
            // placed yet. In that case, we place the hline at
            // the top of the table.
            //
            // Exceptionally, the hline will be placed before
            // the minimum auto index if the current auto index
            // from previous iterations is smaller than the
            // minimum it should have for the current grid
            // child. Effectively, this means that a hline at
            // the start of a header will always appear above
            // that header's first row. Similarly for footers.
            if local_auto_index.val == 0 {
              0
            } else {
              (local_auto_index.val - 1) / columns + 1
            }
          }
        }
        if line.end is Some(end) && end < line.start {
          bail_at(line.span, "line cannot end before it starts")
        }
        let line_ = Line::{
          index: y,
          start: line.start,
          end: line.end,
          stroke: line.stroke,
          position: line.position,
        }

        // Since the amount of rows is dynamic, delay placing
        // hlines until after all cells were placed so we can
        // properly verify if they are valid. Note that we
        // can't place hlines even if we already know they
        // would be in a valid row, since it's possible that we
        // pushed pending hlines in the same row as this one in
        // previous iterations, and we need to ensure that
        // hlines from previous iterations are pushed to the
        // final vector of hlines first - the order of hlines
        // must be kept, as this matters when determining which
        // one "wins" in case of conflict.
        pending_hlines.push((line.span, line_, has_auto_y))
        continue
      }
      VLine(line) => {
        let x = match line.index {
          Custom(x) => x
          Auto => {
            // When no 'x' is specified for the vline, we place
            // it after the latest automatically positioned
            // cell.
            // The current value of the auto index is always
            // the index of the latest automatically positioned
            // cell placed plus one (that's what we do in
            // 'resolve_cell_position'), so we subtract 1 to
            // get that cell's index, and place the vline after
            // its column. The exception is when the auto_index
            // is 0, meaning no automatically positioned cell
            // was placed yet. In that case, we place the vline
            // to the left of the table.
            //
            // Exceptionally, a vline is also placed to the
            // left of the table when specified at the start
            // of a row group, such as a header or footer, that
            // is, when no automatically-positioned cells have
            // been specified for that group yet.
            // For example, this means that a vline at
            // the beginning of a header will be placed to its
            // left rather than after the previous
            // automatically positioned cell. Same for footers.
            let lai = local_auto_index.val
            if lai >= 1 && lai > first_available_row * columns {
              (lai - 1) % columns + 1
            } else {
              0
            }
          }
        }
        if line.end is Some(end) && end < line.start {
          bail_at(line.span, "line cannot end before it starts")
        }
        let line_ = Line::{
          index: x,
          start: line.start,
          end: line.end,
          stroke: line.stroke,
          position: line.position,
        }

        // For consistency with hlines, we only push vlines to
        // the final vector of vlines after processing every
        // cell.
        state.pending_vlines.push((line.span, line_))
        continue
      }
      Cell(cell) => cell
    }
    let cell_span = cell.cell_span()
    let colspan = cell.cell_colspan(self.styles)
    let rowspan = cell.cell_rowspan(self.styles)
    // Let's calculate the cell's final position based on its
    // requested position.
    let resolved_index = {
      let cell_x = cell.cell_x(self.styles)
      let cell_y = cell.cell_y(self.styles)
      had_auto_cells = had_auto_cells || (cell_x is Auto && cell_y is Auto)
      at(cell_span, () => {
        resolve_cell_position(
          cell_x,
          cell_y,
          colspan,
          rowspan,
          state.header_rows,
          state.headers,
          state.footer,
          resolved_cells,
          local_auto_index,
          first_available_row,
          columns,
          row_group_data is Some(_),
        )
      })
    }
    let x = resolved_index % columns
    let y = resolved_index / columns
    if colspan > columns - x {
      bail_at(
        cell_span,
        "cell's colspan would cause it to exceed the available column(s)",
        hints=[
          "try placing the cell in another position or reducing its colspan",
        ],
      )
    }
    let largest_index = columns.to_int64() * (rowspan - 1).to_int64() +
      resolved_index.to_int64() +
      (colspan - 1).to_int64()
    if largest_index > max_grid_index {
      bail_at(cell_span, "cell would span an exceedingly large position", hints=[
        "try reducing the cell's rowspan or colspan",
      ])
    }
    let largest_index = largest_index.to_int()

    // Cell's header or footer must expand to include the cell's
    // occupied positions, if possible.
    if row_group_data is Some(data) {
      let new_range = at(cell_span, () => {
        expand_row_group(
          resolved_cells,
          data.range,
          data.kind,
          first_available_row,
          y,
          rowspan,
          columns,
        )
      })
      data.range = Some(new_range)
      if data.top_hlines_end is None &&
        local_auto_index.val > first_available_row * columns {
        // Auto index was moved, so upcoming auto-pos hlines should
        // no longer appear at the top.
        data.top_hlines_end = Some(pending_hlines.length())
      }
    }

    // Let's resolve the cell so it can determine its own fields
    // based on its final position.
    let cell = self.resolve_cell(cell, x, y, rowspan, cell_kind)
    if largest_index >= resolved_cells.length() {
      // Ensure the length of the vector of resolved cells is
      // always a multiple of 'columns' by pushing full rows every
      // time. Here, we add enough absent positions (later
      // converted to empty cells) to ensure the last row in the
      // new vector length is completely filled. This is
      // necessary so that those positions, even if not
      // explicitly used at the end, are eventually susceptible
      // to show rules and receive grid styling, as they will be
      // resolved as empty cells in a second loop below.
      let new_len = next_multiple_of(largest_index + 1, columns)
      if new_len.to_int64() > max_grid_index {
        bail_at(cell_span, "cell position too large")
      }

      // Here, the cell needs to be placed in a position which
      // doesn't exist yet in the grid (out of bounds). We will
      // add enough absent positions for this to be possible.
      // They must be absent as no cells actually occupy them
      // (they can be overridden later); however, if no cells
      // occupy them as we finish building the grid, then such
      // positions will be replaced by empty cells.
      while resolved_cells.length() < new_len {
        resolved_cells.push(None)
      }
    }

    // The vector is large enough to contain the cell, so we can
    // just index it directly to access the position it will be
    // placed in. However, we still need to ensure we won't try to
    // place a cell where there already is one.
    if resolved_cells[resolved_index] is Some(_) {
      bail_at(
        cell_span,
        "attempted to place a second cell at column \{x}, row \{y}",
        hints=["try specifying your cells in a different order"],
      )
    }
    resolved_cells[resolved_index] = Some(Entry::Cell(cell))

    // Now, if the cell spans more than one row or column, we fill
    // the spanned positions in the grid with Entry::Merged
    // pointing to the original cell as its parent.
    for rowspan_offset in 0..<rowspan {
      let spanned_y = y + rowspan_offset
      let first_row_index = resolved_index + columns * rowspan_offset
      for colspan_offset in 0..<colspan {
        let spanned_x = x + colspan_offset
        if spanned_x == x && spanned_y == y {
          // This is the parent cell.
          continue
        }
        let slot = first_row_index + colspan_offset
        if resolved_cells[slot] is Some(_) {
          bail_at(
            cell_span,
            "cell would span a previously placed cell at column \{spanned_x}, row \{spanned_y}",
            hints=[
              "try specifying your cells in a different order or reducing the cell's rowspan or colspan",
            ],
          )
        }
        resolved_cells[slot] = Some(Merged(resolved_index))
      }
    }
  }
  if row_group_data is Some(row_group) {
    let group_range = match row_group.range {
      Some(group_range) => group_range
      None => {
        // Empty header/footer: consider the header/footer to be
        // automatically positioned at the next empty row after the
        // latest auto index.
        local_auto_index.val = first_available_row * columns
        had_auto_cells = true
        let group_start = first_available_row
        let group_end = group_start + 1
        if resolved_cells.length() <= columns * group_start {
          // Ensure the automatically chosen row actually exists.
          while resolved_cells.length() < columns * (group_start + 1) {
            resolved_cells.push(None)
          }
        }

        // Even though this header or footer is fully empty, we add one
        // default cell to maintain the invariant that each header and
        // footer has at least one 'Some(...)' cell at its first row
        // and at least one at its last row (here they are the same
        // row, of course). This invariant is important to ensure
        // 'find_next_empty_row' will skip through any existing headers
        // and footers without having to loop through them each time.
        // Cells themselves, unfortunately, still have to.
        guard resolved_cells[local_auto_index.val] is None else {
          abort("empty row group position is occupied")
        }
        let kind : TableCellKind = match row_group.kind {
          Header => Header(NonZeroU32(1L), TableHeaderScope::default())
          Footer => Footer
        }
        resolved_cells[local_auto_index.val] = Some(
          Entry::Cell(
            self.resolve_cell(
              T::default_cell(),
              0,
              first_available_row,
              1,
              Custom(kind),
            ),
          ),
        )
        { start: group_start, end: group_end, }
      }
    }
    let top_hlines_end = match row_group.top_hlines_end {
      Some(end) => end
      None => pending_hlines.length()
    }
    if row_group.top_hlines_start <= top_hlines_end &&
      top_hlines_end <= pending_hlines.length() {
      for i in row_group.top_hlines_start..<top_hlines_end {
        let (_, top_hline, has_auto_y) = pending_hlines[i]
        if has_auto_y {
          // Move this hline to the top of the child, as it was
          // placed before the first automatically positioned cell
          // and had an automatic index.
          top_hline.index = group_range.start
        }
      }
    }
    if had_auto_cells {
      // Header/footer was automatically positioned (either by having
      // auto cells or by virtue of being empty), so trigger a
      // rowbreak. Move auto index counter right below it.
      state.auto_index.val = group_range.end * columns
    }
    match row_group.kind {
      Header => {
        let data = Header::{
          // Later on, we have to correct this range in case there
          // is gutter. But only once all cells have been analyzed
          // and the header has fully expanded in the fixup loop
          // below.
          range: group_range,
          level: row_group.repeatable_level,
          // This can only change at a later iteration, if we
          // find a conflicting header or footer right away.
          short_lived: false,
        }
        state.headers.push({ inner: data, repeated: row_group.repeat, })
        for row in group_range.start..<group_range.end {
          state.header_rows.insert(row)
        }
      }
      Footer => {
        // Only check if the footer is at the end later, once we know
        // the final amount of rows.
        state.footer = Some(
          (
            group_range.end,
            row_group.span,
            Footer::{
              // Later on, we have to correct this number in case there
              // is gutter, but only once all cells have been analyzed
              // and the header's and footer's exact boundaries are
              // known. That is because the gutter row immediately
              // before the footer might not be included as part of
              // the footer if it is contained within the header.
              start: group_range.start,
              end: group_range.end,
              level: 1,
            },
          ),
        )
        state.repeat_footer = row_group.repeat
      }
    }
  }
}

///|
/// Fixup phase (final step in cell grid generation):
///
/// 1. Replace absent entries by resolved empty cells, producing a vector
///    of `Entry` from `Option<Entry>`.
///
/// 2. Add enough empty cells to the end of the grid such that it has at
///    least the given amount of rows (must be a multiple of `columns`,
///    and all rows before the last cell must have cells, empty or not,
///    even if the user didn't specify those cells).
///
///    That is necessary, for example, to ensure even unspecified cells
///    can be affected by show rules and grid-wide styling.
fn[T : ResolvableCell] CellGridResolver::fixup_cells(
  self : CellGridResolver,
  resolved_cells : Array[Entry?],
  columns : Int,
  _ty : Ty[T],
) -> Array[Entry] raise SourceError {
  let expected_total_cells = columns.to_int64() *
    self.tracks.y.length().to_int64()
  if expected_total_cells > max_grid_index {
    bail_at(self.span, "too many rows were specified")
  }
  let expected_total_cells = expected_total_cells.to_int()
  let total = max_int(resolved_cells.length(), expected_total_cells)
  let out = []
  for i in 0..<total {
    match resolved_cells.get(i) {
      Some(Some(cell)) => out.push(cell)
      _ => {
        let x = i % columns
        let y = i / columns
        out.push(
          Entry::Cell(self.resolve_cell(T::default_cell(), x, y, 1, Auto)),
        )
      }
    }
  }
  out
}

///|
/// Takes the list of pending lines and evaluates a final list of hlines
/// and vlines (in that order in the returned tuple), detecting invalid
/// line positions in the process.
///
/// For each line type (horizontal and vertical respectively), returns a
/// vector containing one inner vector for every group of lines with the
/// same index.
///
/// For example, an hline above the second row (y = 1) is inside the inner
/// vector at position 1 of the first vector (hlines) returned by this
/// function.
fn CellGridResolver::collect_lines(
  _self : CellGridResolver,
  pending_hlines : Array[(@syntax.Span, Line, Bool)],
  pending_vlines : Array[(@syntax.Span, Line)],
  has_gutter : Bool,
  columns : Int,
  row_amount : Int,
) -> (Array[Array[Line]], Array[Array[Line]]) raise SourceError {
  let hlines : Array[Array[Line]] = []
  let vlines : Array[Array[Line]] = []
  for pending in pending_hlines {
    let (line_span, line, _) = pending
    let y = line.index
    if y > row_amount {
      bail_at(line_span, "cannot place horizontal line at invalid row \{y}")
    }
    if y == row_amount && line.position == After {
      bail_at(
        line_span,
        "cannot place horizontal line at the 'bottom' position of the bottom border (y = \{y})",
        hints=[
          "set the line's position to 'top' or place it at a smaller 'y' index",
        ],
      )
    }
    let line = if line.position == After && (!has_gutter || y + 1 == row_amount) {
      // Just place the line on top of the next row if
      // there's no gutter and the line should be placed
      // after the one with given index.
      //
      // Note that placing after the last row is also the same as
      // just placing on the grid's bottom border, even with
      // gutter.
      Line::{ ..line, index: y + 1, position: Before, }
    } else {
      line
    }
    let y = line.index
    while hlines.length() <= y {
      hlines.push([])
    }
    hlines[y].push(line)
  }
  for pending in pending_vlines {
    let (line_span, line) = pending
    let x = line.index
    if x > columns {
      bail_at(line_span, "cannot place vertical line at invalid column \{x}")
    }
    if x == columns && line.position == After {
      bail_at(
        line_span,
        "cannot place vertical line at the 'end' position of the end border (x = \{columns})",
        hints=[
          "set the line's position to 'start' or place it at a smaller 'x' index",
        ],
      )
    }
    let line = if line.position == After && (!has_gutter || x + 1 == columns) {
      // Just place the line before the next column if
      // there's no gutter and the line should be placed
      // after the one with given index.
      //
      // Note that placing after the last column is also the
      // same as just placing on the grid's end border, even
      // with gutter.
      Line::{ ..line, index: x + 1, position: Before, }
    } else {
      line
    }
    let x = line.index
    while vlines.length() <= x {
      vlines.push([])
    }
    vlines[x].push(line)
  }
  (hlines, vlines)
}

///|
/// Generate the final headers and footers:
///
/// 1. Convert gutter-ignorant to gutter-aware indices if necessary;
/// 2. Expand the header downwards (or footer upwards) to also include
///    an adjacent gutter row to be repeated alongside that header or
///    footer, if there is gutter;
/// 3. Wrap headers and footers in the correct [Repeatable] variant.
fn CellGridResolver::finalize_headers_and_footers(
  _self : CellGridResolver,
  has_gutter : Bool,
  headers : Array[Repeatable[Header]],
  footer : (Int, @syntax.Span, Footer)?,
  repeat_footer : Bool,
  row_amount : Int,
  at_least_one_cell : Bool,
) -> Repeatable[Footer]? raise SourceError {
  headers.sort_by_key(h => h.inner.range.start)

  // Mark consecutive headers in those positions as short-lived:
  // (a) before a header of lower level;
  // (b) right before the end of the table or the final footer;
  // That's because they would stop repeating immediately, so don't even
  // attempt to.
  //
  // It is important to do this BEFORE we update header and footer ranges
  // due to gutter below as 'row_amount' doesn't consider gutter.
  let mut consecutive_header_start = match footer {
    Some((_, _, f)) => f.start
    None => row_amount
  }
  let mut last_consec_level = 0L
  for i = headers.length() - 1; i >= 0; i = i - 1 {
    let header = headers[i].inner
    if header.range.end == consecutive_header_start &&
      header.level.get() >= last_consec_level {
      header.short_lived = true
    } else {
      last_consec_level = header.level.get()
    }
    consecutive_header_start = header.range.start
  }

  // Repeat the gutter below a header (hence why we don't
  // subtract 1 from the gutter case).
  // Don't do this if there are no rows under the header.
  if has_gutter {
    for repeatable in headers {
      let header = repeatable.inner
      // Index of first y is doubled, as each row before it
      // receives a gutter row below.
      let start = header.range.start * 2

      // - 'header.end' is always 'last y + 1'. The header stops
      // before that row.
      // - Therefore, '2 * header.end' will be 2 * (last y + 1),
      // which is the adjusted index of the row before which the
      // header stops, meaning it will still stop right before it
      // even with gutter thanks to the multiplication below.
      // - This means that it will span all rows up to
      // '2 * (last y + 1) - 1 = 2 * last y + 1', which equates
      // to the index of the gutter row right below the header,
      // which is what we want (that gutter spacing should be
      // repeated across pages to maintain uniformity).
      let end = header.range.end * 2

      // If the header occupies the entire grid, ensure we don't
      // include an extra gutter row when it doesn't exist, since
      // the last row of the header is at the very bottom,
      // therefore '2 * last y + 1' is not a valid index.
      let row_amount = max_int(2 * row_amount - 1, 0)
      header.range = { start, end: min_int(end, row_amount), }
    }
  }
  match footer {
    None => None
    Some((footer_end, footer_span, footer)) => {
      if footer_end != row_amount {
        bail_at(footer_span, "footer must end at the last row")
      }

      // Alternatively, never include the gutter in the footer's
      // range and manually add it later on layout. This would allow
      // laying out the gutter as part of both the header and footer,
      // and, if the page only has headers, the gutter row below the
      // header is automatically removed (as it becomes the last), so
      // only the gutter above the footer is kept, ensuring the same
      // gutter row isn't laid out two times in a row. When laying
      // out the footer for real, the mechanism can be disabled.
      let last_header_end = headers.last().map(header => header.inner.range.end)
      if has_gutter {
        // Convert the footer's start index to post-gutter coordinates.
        footer.start = footer.start * 2

        // Include the gutter right before the footer, unless there is
        // none, or the gutter is already included in the header (no
        // rows between the header and the footer).
        if last_header_end != Some(footer.start) {
          footer.start = max_int(footer.start - 1, 0)
        }

        // Adapt footer end but DO NOT include the gutter below it,
        // if it exists. Calculation:
        // - Starts as 'last y + 1'.
        // - The result will be
        // 2 * (last_y + 1) - 1 = 2 * last_y + 1,
        // which is the new index of the last footer row plus one,
        // meaning we do exclude any gutter below this way.
        //
        // It also keeps us within the total amount of rows, so we
        // don't need to '.min()' later.
        footer.end = max_int(2 * footer.end - 1, 0)
      }

      // Don't repeat footers when the table only has headers and
      // footers.
      Some({ inner: footer, repeated: repeat_footer && at_least_one_cell, })
    }
  }
}

///|
/// Resolves the cell's fields based on grid-wide properties.
fn[T : ResolvableCell] CellGridResolver::resolve_cell(
  self : CellGridResolver,
  cell : T,
  x : Int,
  y : Int,
  rowspan : Int,
  kind : Smart[TableCellKind],
) -> Cell raise SourceError {
  // Resolve the breakability of a cell. Cells that span at least one
  // auto-sized row or gutter are considered breakable.
  let breakable = {
    let auto = Sizing::Auto
    let zero = Sizing::Rel(Rel::zero())
    let track_at = (tracks : Array[Sizing], i : Int, default : Sizing) => {
      match tracks.get(i) {
        Some(t) => t
        None =>
          match tracks.last() {
            Some(t) => t
            None => default
          }
      }
    }
    let mut breakable = false
    for i in y..<(y + rowspan) {
      if track_at(self.tracks.y, i, auto) == Sizing::Auto {
        breakable = true
        break
      }
    }
    if !breakable {
      for i in y..<(y + rowspan - 1) {
        if track_at(self.gutter.y, i, zero) == Sizing::Auto {
          breakable = true
          break
        }
      }
    }
    breakable
  }
  let fill = self.fill.resolve(self.engine, self.styles, x, y, None)
  let align = self.align.resolve(self.engine, self.styles, x, y, Auto)
  let inset = self.inset.resolve(
    self.engine,
    self.styles,
    x,
    y,
    Sides::splat(None),
  )
  let stroke = self.stroke.resolve(self.engine, self.styles, x, y)
  cell.resolve_cell(
    x,
    y,
    fill,
    align,
    inset,
    stroke,
    breakable,
    self.styles,
    kind,
  )
}

///|
/// Given the existing range of a row group (header or footer), tries to expand
/// it to fit the new cell placed inside it. If the newly-expanded row group
/// would conflict with existing cells or other row groups, an error is
/// returned. Otherwise, the new `start..end` range of rows in the row group is
/// returned.
fn expand_row_group(
  resolved_cells : Array[Entry?],
  group_range : RowRange?,
  group_kind : RowGroupKind,
  first_available_row : Int,
  cell_y : Int,
  rowspan : Int,
  columns : Int,
) -> RowRange raise HintedError {
  // Ensure each cell in a header or footer is fully contained within it by
  // expanding the header or footer towards this new cell.
  let (new_group_start, new_group_end) = match group_range {
    None => (cell_y, cell_y + rowspan)
    Some(r) => (min_int(r.start, cell_y), max_int(r.end, cell_y + rowspan))
  }

  // This check might be unnecessary with the loop below, but let's keep it
  // here for full correctness.
  //
  // Quickly detect the case:
  // y = 0 => occupied
  // y = 1 => empty
  // y = 2 => header
  // and header tries to expand to y = 0 - invalid, as
  // 'y = 1' is the earliest row it can occupy.
  if new_group_start < first_available_row {
    bail_hinted(
      "cell would cause \{group_kind.name()} to expand to non-empty row \{max_int(first_available_row - 1, 0)}",
      ["try moving its cells to available rows"],
    )
  }
  let new_rows : Array[Int] = match group_range {
    None => int_range(new_group_start, new_group_end)
    Some(r) =>
      // NOTE: 'r.end' is one row AFTER the row group's last row, so it
      // makes sense to check it if 'new_group_end > r.end', that is, if
      // the row group is going to expand. It is NOT a duplicate check,
      // as we hadn't checked it before (in a previous run, it was
      // 'new_group_end' at the exclusive end of the range)!
      int_range(new_group_start, r.start) + int_range(r.end, new_group_end)
  }

  // The check above isn't enough, however, even when the header is expanding
  // upwards, as it might expand upwards towards an occupied row after the
  // first empty row, e.g.
  //
  // y = 0 => occupied
  // y = 1 => empty (first_available_row = 1)
  // y = 2 => occupied
  // y = 3 => header
  //
  // Here, we should bail if the header tries to expand upwards, regardless
  // of the fact that the conflicting row (y = 2) comes after the first
  // available row.
  //
  // Note that simply checking for non-empty rows like below not only
  // prevents conflicts with top-level cells (outside of headers and
  // footers), but also prevents conflicts with other headers or footers,
  // since we have an invariant that even empty headers and footers must
  // contain at least one 'Some(...)' position in 'resolved_cells'.
  for new_y in new_rows {
    let row_start = new_y * columns
    if row_start < resolved_cells.length() {
      let row_end = min_int(row_start + columns, resolved_cells.length())
      for i in row_start..<row_end {
        if resolved_cells[i] is Some(_) {
          bail_hinted(
            "cell would cause \{group_kind.name()} to expand to non-empty row \{new_y}",
            ["try moving its cells to available rows"],
          )
        }
      }
    } else {
      // Received 'None' or an empty slice, so we are expanding the
      // header or footer into new rows, which is always valid and cannot
      // conflict with existing cells. (Note that we only resize
      // 'resolved_cells' after this function is called, so, if this
      // header or footer is at the bottom of the table so far, this loop
      // will end quite early, regardless of where this cell was placed
      // or of its rowspan value.)
      break
    }
  }
  { start: new_group_start, end: new_group_end, }
}

///|
/// Check if a cell's fixed row would conflict with a header or footer.
fn check_for_conflicting_cell_row(
  header_rows : RowSet,
  headers : Array[Repeatable[Header]],
  footer : (Int, @syntax.Span, Footer)?,
  cell_y : Int,
  rowspan : Int,
) -> Unit raise HintedError {
  if !headers.is_empty() {
    for row in cell_y..<(cell_y + rowspan) {
      if header_rows.contains(row) {
        bail_hinted(
          "cell would conflict with header also spanning row \{row}",
          ["try moving the cell or the header"],
        )
      }
    }
  }

  // NOTE: y + rowspan >, not >=, footer.start, to check if the rowspan
  // enters the footer. For example, consider a rowspan of 1: if
  // `y + 1 = footer.start` holds, that means `y < footer.start`, and it
  // only occupies one row (`y`), so the cell is actually not in
  // conflict.
  if footer is Some((_, _, footer)) &&
    cell_y < footer.end &&
    cell_y + rowspan > footer.start {
    let mut row = cell_y
    while !footer.range().contains(row) {
      row = row + 1
    }
    bail_hinted("cell would conflict with footer also spanning row \{row}", [
      "try reducing the cell's rowspan or moving the footer",
    ])
  }
}

///|
/// Translates a (x, y) position to the equivalent index in the final cell
/// vector. Errors if the position would be too large.
fn cell_index(x : Int, y : Int, columns : Int) -> Int raise HintedError {
  let index = y.to_int64() * columns.to_int64() + x.to_int64()
  if index > max_grid_index {
    bail("cell position too large")
  }
  index.to_int()
}

///|
/// Given a cell's requested x and y, the vector with the resolved cell
/// positions, the `auto_index` counter (determines the position of the next
/// `(auto, auto)` cell) and the amount of columns in the grid, returns the
/// final index of this cell in the vector of resolved cells.
///
/// The `first_available_row` parameter is used by headers and footers to
/// indicate the first empty row available. Any rows before those should
/// not be picked by cells with `auto` row positioning, since headers and
/// footers occupy entire rows, and may not conflict with cells outside them.
fn resolve_cell_position(
  cell_x : Smart[Int],
  cell_y : Smart[Int],
  colspan : Int,
  rowspan : Int,
  header_rows : RowSet,
  headers : Array[Repeatable[Header]],
  footer : (Int, @syntax.Span, Footer)?,
  resolved_cells : Array[Entry?],
  auto_index : Ref[Int],
  first_available_row : Int,
  columns : Int,
  in_row_group : Bool,
) -> Int raise HintedError {
  match (cell_x, cell_y) {
    // Fully automatic cell positioning. The cell did not
    // request a coordinate.
    (Auto, Auto) => {
      // Let's find the first available position starting from the
      // automatic position counter, searching in row-major order.
      // Note that the counter ignores any cells with fixed positions,
      // but automatically-positioned cells will avoid conflicts by
      // simply skipping existing cells, headers and footers.
      let resolved_index = find_next_available_position(
        header_rows,
        footer,
        resolved_cells,
        columns,
        auto_index.val,
        false,
      )

      // Ensure the next cell with automatic position will be
      // placed after this one (maybe not immediately after).
      //
      // The calculation below also affects the position of the upcoming
      // automatically-positioned lines, as they are placed below
      // (horizontal lines) or to the right (vertical lines) of the cell
      // that would be placed at 'auto_index'.
      auto_index.val = if colspan == columns {
        // The cell occupies all columns, so no cells can be placed
        // after it until all of its rows have been spanned.
        resolved_index + colspan * rowspan
      } else {
        // The next cell will have to be placed at least after its
        // spanned columns.
        resolved_index + colspan
      }
      resolved_index
    }
    // Cell has chosen at least its column.
    (Custom(cell_x), cell_y) => {
      if cell_x >= columns {
        bail("cell could not be placed at invalid column \{cell_x}")
      }
      match cell_y {
        Custom(cell_y) => {
          // Cell has chosen its exact position.
          //
          // Ensure it doesn't conflict with an existing header or
          // footer (but only if it isn't already in one, otherwise there
          // will already be a separate check).
          if !in_row_group {
            check_for_conflicting_cell_row(
              header_rows, headers, footer, cell_y, rowspan,
            )
          }
          cell_index(cell_x, cell_y, columns)
        }
        Auto => {
          // Cell has only chosen its column.
          // Let's find the first row which has that column available.
          // If in a header or footer, start searching by the first empty
          // row / the header or footer's first row (specified through
          // 'first_available_row'). Otherwise, start searching at the
          // first row.
          let initial_index = cell_index(cell_x, first_available_row, columns)

          // Try each row until either we reach an absent position at the
          // requested column ('Some(None)') or an out of bounds position
          // ('None'), in which case we'd create a new row to place this
          // cell in.
          find_next_available_position(
            header_rows, footer, resolved_cells, columns, initial_index, true,
          )
        }
      }
    }
    // Cell has only chosen its row, not its column.
    (Auto, Custom(cell_y)) => {
      // Ensure it doesn't conflict with an existing header or
      // footer (but only if it isn't already in one, otherwise there
      // will already be a separate check).
      if !in_row_group {
        check_for_conflicting_cell_row(
          header_rows, headers, footer, cell_y, rowspan,
        )
      }

      // Let's find the first column which has that row available.
      let first_row_pos = cell_index(0, cell_y, columns)
      let last_row_pos = first_row_pos + columns
      if last_row_pos.to_int64() > max_grid_index {
        bail("cell position too large")
      }
      for possible_index in first_row_pos..<last_row_pos {
        // Much like in the previous cases, we skip any occupied
        // positions until we either reach an absent position
        // (`Some(None)`) or an out of bounds position (`None`),
        // in which case we can just expand the vector enough to
        // place this cell. In either case, we found an available
        // position.
        if !(resolved_cells.get(possible_index) is Some(Some(_))) {
          return possible_index
        }
      }
      bail_hinted(
        "cell could not be placed in row \{cell_y} because it was full",
        ["try specifying your cells in a different order"],
      )
    }
  }
}

///|
/// Finds the first available position after the initial index in the resolved
/// grid of cells. Skips any non-absent positions (positions which already
/// have cells specified by the user) as well as any headers and footers.
///
/// When `skip_rows` is true, one row is skipped on each iteration, preserving
/// the column. That is used to find a position for a fixed column cell.
fn find_next_available_position(
  header_rows : RowSet,
  footer : (Int, @syntax.Span, Footer)?,
  resolved_cells : Array[Entry?],
  columns : Int,
  initial_index : Int,
  skip_rows : Bool,
) -> Int raise HintedError {
  let mut resolved_index = initial_index
  while true {
    if resolved_cells.get(resolved_index) is Some(Some(_)) {
      // Skip any non-absent cell positions (`Some(None)`) to
      // determine where this cell will be placed. An out of
      // bounds position (thus `None`) is also a valid new
      // position (only requires expanding the vector).
      if skip_rows {
        // Skip one row at a time (cell chose its column, so we don't
        // change it).
        if resolved_index.to_int64() + columns.to_int64() > max_grid_index {
          bail("cell position too large")
        }
        resolved_index = resolved_index + columns
      } else {
        resolved_index = resolved_index + 1
      }
    } else if header_rows.contains(resolved_index / columns) {
      // Skip header rows (can't place a cell inside it from outside it).
      if skip_rows {
        // Ensure the cell's chosen column is kept after the header.
        resolved_index = resolved_index + columns
      } else {
        // Skip to the start of the next row.
        //
        // Add 1 to resolved index to force moving to the next row if
        // this is at the start of one. At the end of one, '+ 1'
        // already pushes to the next one and 'next_multiple_of' does
        // not modify it, so nothing bad happens then either.
        resolved_index = next_multiple_of(resolved_index + 1, columns)
      }
    } else if footer is Some((footer_end, _, footer)) &&
      resolved_index >= footer.start * columns &&
      resolved_index < footer_end * columns {
      // Skip footer, for the same reason.
      resolved_index = footer_end * columns
      if skip_rows {
        // Ensure the cell's chosen column is kept after the
        // footer.
        resolved_index = resolved_index + initial_index % columns
      }
    } else {
      return resolved_index
    }
  }
  panic()
}

///|
/// Computes the `y` of the next available empty row, given the auto index as
/// an initial index for search, since we know that there are no empty rows
/// before automatically-positioned cells, as they are placed sequentially.
fn find_next_empty_row(
  resolved_cells : Array[Entry?],
  auto_index : Int,
  columns : Int,
) -> Int {
  let mut resolved_index = next_multiple_of(auto_index, columns)
  while resolved_index + columns <= resolved_cells.length() &&
        row_any_some(resolved_cells, resolved_index, columns) {
    // Skip non-empty rows.
    resolved_index = resolved_index + columns
  }
  resolved_index / columns
}

///|
fn row_any_some(cells : Array[Entry?], start : Int, columns : Int) -> Bool {
  for i in start..<(start + columns) {
    if cells[i] is Some(_) {
      return true
    }
  }
  false
}

///|
/// Fully merged rows under the cell of latest auto index indicate rowspans
/// occupying all columns, so we skip the auto index until the shortest rowspan
/// ends, such that, in the resulting row, we will be able to place an
/// automatically positioned cell - and, in particular, hlines under it. The
/// idea is that an auto hline will be placed after the shortest such rowspan.
/// Otherwise, the hline would just be placed under the first row of those
/// rowspans and disappear (except at the presence of column gutter).
fn skip_auto_index_through_fully_merged_rows(
  resolved_cells : Array[Entry?],
  auto_index : Ref[Int],
  columns : Int,
) -> Unit {
  // If the auto index isn't currently at the start of a row, that means
  // there's still at least one auto position left in the row, ignoring
  // cells with manual positions, so we wouldn't have a problem in placing
  // further cells or, in this case, hlines here.
  if auto_index.val % columns == 0 {
    while auto_index.val + columns <= resolved_cells.length() &&
          row_all_merged(resolved_cells, auto_index.val, columns) {
      auto_index.val = auto_index.val + columns
    }
  }
}

///|
fn row_all_merged(cells : Array[Entry?], start : Int, columns : Int) -> Bool {
  for i in start..<(start + columns) {
    if !(cells[i] is Some(Merged(_))) {
      return false
    }
  }
  true
}

// Internal codec: cell grids are stored as `Value::Dyn(CellGrid(..))` in the
// internal, synthesized `grid` field of grids and tables. They are never
// exposed to users.

///|
pub impl Reflect for CellGrid with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for CellGrid with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for CellGrid with fn castable(v) {
  v is Dyn(CellGrid(_))
}

///|
pub extend CellGrid with Reflect::{output, input, castable}

///|
pub impl IntoValue for CellGrid with fn into_value(self) {
  Dyn(CellGrid(self))
}

///|
pub impl FromValue for CellGrid with fn from_value(v) {
  match v {
    Dyn(CellGrid(grid)) => grid
    v => raise HintedError(CellGrid::input().error(v))
  }
}

///|
fn fingerprint_stroke(state : SipHasher128, stroke : ResolvedStroke?) -> Unit {
  match stroke {
    None => state.write_discriminant(0)
    Some(stroke) => {
      state.write_discriminant(1)
      state.write(IntoValue::into_value(stroke.to_length_stroke()))
    }
  }
}

///|
fn fingerprint_line(state : SipHasher128, line : Line) -> Unit {
  state.write_usize(line.index)
  state.write_usize(line.start)
  state.write(line.end)
  fingerprint_stroke(state, line.stroke)
  state.write_bool(line.position == After)
}

///|
/// Upstream `#[derive(Hash)]` on `CellGrid`.
pub impl Fingerprint for CellGrid with fn fingerprint(self, state) {
  state.write_usize(self.entries.length())
  for entry in self.entries {
    match entry {
      Cell(cell) => {
        state.write_discriminant(0)
        state.write(cell.body)
        state.write(cell.fill.map(IntoValue::into_value))
        state.write_usize(cell.colspan)
        state.write_usize(cell.rowspan)
        for side in cell.stroke.iter() {
          fingerprint_stroke(state, side)
        }
        for side in cell.stroke_overridden.iter() {
          state.write_bool(side)
        }
        state.write_bool(cell.breakable)
      }
      Merged(parent) => {
        state.write_discriminant(1)
        state.write_usize(parent)
      }
    }
  }
  state.write(self.cols.map(IntoValue::into_value))
  state.write(self.rows.map(IntoValue::into_value))
  for lines in [self.vlines, self.hlines] {
    state.write_usize(lines.length())
    for group in lines {
      state.write_usize(group.length())
      for line in group {
        fingerprint_line(state, line)
      }
    }
  }
  state.write_usize(self.headers.length())
  for header in self.headers {
    state.write_usize(header.inner.range.start)
    state.write_usize(header.inner.range.end)
    state.write(header.inner.level.get())
    state.write_bool(header.inner.short_lived)
    state.write_bool(header.repeated)
  }
  match self.footer {
    None => state.write_discriminant(0)
    Some(footer) => {
      state.write_discriminant(1)
      state.write_usize(footer.inner.start)
      state.write_usize(footer.inner.end)
      state.write_usize(footer.inner.level)
      state.write_bool(footer.repeated)
    }
  }
  state.write_bool(self.has_gutter)
}
