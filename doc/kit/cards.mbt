// `Cards` (docs/edsl-ports.md, section 4; findings H3 and S3): cards in
// rows, the cards of a row equally high.

///|
/// Cards in rows: each item is drawn as a card, and the cards of a row are
/// as high as the highest of them.
///
/// ```mbt nocheck
/// Cards(["One line.", long_text, third], gutter=[Pt(8)], inset=Sides(all=Pt(8)),
///   fill=Luma(245))
/// ```
///
/// A `Block` per card does not do this: it is as high as its own content,
/// a fixed `height` does not grow with the content, and `height=Pct(100)`
/// in a grid cell is the height of the region, not of the row
/// (docs/edsl-guide.md, section 7).
///
/// **Without `radius`** the cards are the cells of a `Grid`: the items in
/// `GridCell(item, fill=.., stroke=.., inset=..)`, the tracks the
/// grid's. The engine makes the cells of a row equally high. The corners
/// are square: a cell has no radius. It does not measure, so it can be
/// built anywhere, also inside a callback. A row that does not fit the
/// rest of the page is broken as the grid breaks rows: what fits stays, and
/// the rest of every card of the row continues on the next page.
///
/// **With `radius`** a cell cannot draw the card. **Measures**: the cards
/// are `Block(item, width=Pct(100), fill=.., stroke=.., inset=..,
/// radius=.., breakable=false)` in a `Grid` with the same tracks, and each
/// row is measured first, as a grid of that one row at the width of the
/// enclosing region (`Layout`), to give its cards the height of the row.
/// The cards are the same boxes as without a radius. It creates a
/// callback, so it cannot be built inside one (a show rule, a `Context`, a
/// `Layout`): build it before and capture it.
///
/// - A card is not split: a row that does not fit the rest of the page
///   moves to the next page as a whole, and pages break between rows.
/// - A row that is higher than the enclosing region (the page between its
///   margins) fits no page. Its cards are breakable blocks of their own
///   height instead: nothing leaves the page, and the cards of that row
///   are not equally high where they end.
/// - In a region without a width (a page with `width: auto`, or while the
///   cards are measured without one) the rows are measured without a
///   width, as the grid is laid out there: fractional columns have no
///   width in an unbounded region, with or without `radius`.
/// - A column cannot be `Auto` (nor `columns` be empty, which is one `auto`
///   column for the engine): an `auto` column is as wide as the widest card
///   of all its rows, which a row that is measured alone does not know. It
///   is an error at `columns`.
/// - The grid only places the blocks: its cells have no inset, whatever
///   the document sets for grids (`SetGrid(inset=..)` is the inset of the
///   cards without a radius; with one, it is `SetBlock`'s or `inset`).
/// - A row is measured as the first row of a grid. A rule of the document
///   that depends on the row of a cell (`show grid.cell.where(y: 1): ..`)
///   does not reach the measurement of the later rows, and can make a card
///   higher than was measured.
///
/// Parameters, with the names and types of `Grid` and of `GridCell` and
/// `Block`:
///
/// - `columns`: the tracks. The default is one `1fr` column per item: one
///   row of equally wide cards. (This default is the element's own: `Grid`
///   has one `auto` column, which puts the cards one under the other.)
/// - `gutter`, `column_gutter`, `row_gutter`: the grid's; none by default.
/// - `fill`, `stroke`, `inset`: of every card; by default the cell's or
///   block's (no fill, no stroke, no inset: set them).
/// - `radius`: of every card, and the choice of the second form.
///
/// An item is the body of a card, in both forms (a `GridCell` among the
/// items is not a cell of the grid: for cells of your own, use `Grid`). A
/// row with fewer items than columns is left open: there is no card where
/// there is no item. No items: nothing.
///
/// Provenance: the call. An item that is a plain string resolves to the
/// `items` argument under the key of its index (`"0"`, `"1"`, ..: every
/// card is `Keyed` with it, so descriptions of the caller inside a card
/// have that key too); an error in `fill` is at `fill`.
///
/// Twin: the function `cards` of `doc/twins/kit.mbt`, a `grid` of
/// `grid.cell`s, or a `layout` that measures each row and returns a `grid`
/// of `block`s.
pub struct Cards {
  priv composite : @doc.Composite
}

///|
/// What the engine makes of a length, as far as it matters for a track.
priv enum Evaluated {
  IsAuto
  IsNone
  Other
}

///|
/// What a length evaluates to. Typst adds `none` as nothing, so
/// `auto + none` is `auto`; every other operation on `auto` or `none` is an
/// error or a length.
fn evaluated(length : @doc.Length) -> Evaluated {
  match length {
    Auto => IsAuto
    None => IsNone
    Sum(a, b) =>
      match (evaluated(a), evaluated(b)) {
        (IsNone, other) | (other, IsNone) => other
        _ => Other
      }
    _ => Other
  }
}

///|
/// Whether a track is `auto`.
fn is_auto(track : @doc.Sizing) -> Bool {
  match track {
    Auto => true
    Rel(length) => evaluated(length) is IsAuto
    _ => false
  }
}

///|
/// The call of a `Cards`: its site and its arguments. The parameters by
/// their index in the declaration of `Cards::Cards`, for `site.arg`: items
/// 0, columns 1, gutter 2, column_gutter 3, row_gutter 4, fill 5, stroke 6,
/// inset 7, radius 8.
priv struct Call {
  site : @doc.CompositeSite
  /// The caller's content, converted once (the callback of the second
  /// form runs whenever the cards are laid out).
  items : Array[@doc.Content]
  /// `columns`, or its default.
  tracks : Array[@doc.Sizing]
  gutter : Array[@doc.Sizing]?
  column_gutter : Array[@doc.Sizing]?
  row_gutter : Array[@doc.Sizing]?
  fill : @doc.Paint?
  stroke : @doc.Sides[@doc.Stroke]?
  inset : @doc.Sides[@doc.Length]?
}

///|
/// The grid of the cards, or of one row of them (`rows=false`: without the
/// gutter between rows). `blocks`: the cards are blocks in its cells, and
/// the cells have no inset, whatever the document sets for grids: the
/// look is the blocks', and an inset that depends on the row would not be
/// the same where a row is measured, as the first row of a grid, and where
/// it is placed.
fn Call::grid(
  self : Call,
  cells : Array[&@doc.IntoContent],
  rows~ : Bool,
  blocks~ : Bool,
) -> @doc.Grid {
  let site = self.site
  @doc.Grid(
    cells,
    columns=site.arg(1, self.tracks),
    gutter?=site.arg(2, self.gutter),
    column_gutter?=site.arg(3, self.column_gutter),
    row_gutter?=if rows { site.arg(4, self.row_gutter) } else { None },
    inset?=if blocks { Some(@doc.Cells::all(@doc.Sides::zero())) } else { None },
  )
}

///|
/// The card of item `k` as a cell.
fn Call::cell(self : Call, k : Int) -> @doc.Keyed {
  let site = self.site
  @doc.Keyed(
    k.to_string(),
    @doc.GridCell(
      site.arg(0, self.items[k]),
      inset?=site.arg(7, self.inset),
      fill?=site.arg(5, self.fill),
      stroke?=site.arg(6, self.stroke),
    ),
  )
}

///|
/// The card of item `k` as a block. What is measured (without a height)
/// and what is placed (with the height of its row) is this block around
/// the same item under the same key.
fn Call::block(
  self : Call,
  k : Int,
  radius : @doc.Corners[@doc.Length],
  height? : @doc.Sizing,
  breakable? : Bool,
) -> @doc.Keyed {
  let site = self.site
  @doc.Keyed(
    k.to_string(),
    @doc.Block(
      site.arg(0, self.items[k]),
      // (A block is as wide as its content unless it is told: the card
      // fills its column.)
      width=Pct(100),
      height?,
      breakable?,
      fill?=site.arg(5, self.fill),
      stroke?=site.arg(6, self.stroke),
      radius=site.arg(8, radius),
      inset?=site.arg(7, self.inset),
    ),
  )
}

///|
/// The second form: the rows measured, the cards blocks of the height of
/// their row.
fn Call::measured(
  self : Call,
  radius : @doc.Corners[@doc.Length],
) -> @doc.Layout {
  let count = self.items.length()
  let per_row = self.tracks.length()
  @doc.Layout((size, cx) => {
    let cells : Array[&@doc.IntoContent] = []
    let mut start = 0
    while start < count {
      let end = if start + per_row < count { start + per_row } else { count }
      // The row, as the grid lays it out at the width of the region: its
      // height is that of its highest card.
      let row : Array[&@doc.IntoContent] = []
      for k in start..<end {
        row.push(self.block(k, radius, breakable=false))
      }
      let row = self.grid(row, rows=false, blocks=true)
      let height = if size.width.is_inf() {
        cx.measure(row).height
      } else {
        cx.measure(row, width=Pt(size.width)).height
      }
      for k in start..<end {
        cells.push(
          if height > size.height {
            // No page holds this row: its cards may break.
            self.block(k, radius)
          } else {
            self.block(k, radius, height=Pt(height), breakable=false)
          },
        )
      }
      start = end
    }
    self.grid(cells, rows=true, blocks=true)
  })
}

///|
#callsite(autofill(loc, args_loc))
pub fn Cards::Cards(
  items : Array[&@doc.IntoContent],
  columns? : Array[@doc.Sizing],
  gutter? : Array[@doc.Sizing],
  column_gutter? : Array[@doc.Sizing],
  row_gutter? : Array[@doc.Sizing],
  fill? : @doc.Paint,
  stroke? : @doc.Sides[@doc.Stroke],
  inset? : @doc.Sides[@doc.Length],
  radius? : @doc.Corners[@doc.Length],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Cards {
  let composite = @doc.Composite("Cards", loc, args_loc, site => {
    let call : Call = {
      site,
      items: items.map(item => @doc.Content(item)),
      // (Copies: a description does not change when the caller's arrays
      // do, and the callback of the second form reads them later.)
      tracks: match columns {
        Some(columns) => columns.copy()
        // One row of equally wide cards.
        None => @doc.Sizing::repeat(items.length(), size=Fr(1))
      },
      gutter: gutter.map(tracks => tracks.copy()),
      column_gutter: column_gutter.map(tracks => tracks.copy()),
      row_gutter: row_gutter.map(tracks => tracks.copy()),
      fill,
      stroke,
      inset,
    }
    guard radius is Some(radius) && !items.is_empty() else {
      // The cells draw the cards.
      let cells : Array[&@doc.IntoContent] = []
      for k in 0..<items.length() {
        cells.push(call.cell(k))
      }
      return @doc.Content(call.grid(cells, rows=true, blocks=false))
    }
    if call.tracks.is_empty() || call.tracks.iter().any(is_auto) {
      return site.invalid(
        "`Cards` with a `radius` cannot have an `Auto` column: its rows are measured one by one, and an `auto` column is as wide as the widest card of all rows",
        arg=1,
      )
    }
    @doc.Content(call.measured(radius))
  })
  { composite, }
}

///|
pub impl @doc.IntoContent for Cards with fn into_content(self) {
  @doc.IntoContent::into_content(self.composite)
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Cards with @doc.IntoContent::{into_content}

///|
/// Interpolation into the text of `Prose`.
pub impl Show for Cards with fn output(self, logger) {
  Show::output(self.composite, logger)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Cards with Show::{to_string, output}

///|
pub impl @debug.Debug for Cards with fn to_repr(self) {
  @debug.Debug::to_repr(self.composite)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Cards with @debug.Debug::{to_repr}
