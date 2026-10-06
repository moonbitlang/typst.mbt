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
/// The cards are the cells of a `Grid`: the items in `GridCell(item,
/// fill=.., stroke=.., inset=..)`, the tracks the grid's. The engine makes
/// the cells of a row equally high. The corners are square: a cell has no
/// radius. It does not measure, so it can be built anywhere, also inside a
/// callback. A row that does not fit the rest of the page is broken as the
/// grid breaks rows: what fits stays, and the rest of every card of the row
/// continues on the next page.
///
/// Parameters, with the names and types of `Grid` and of `GridCell`:
///
/// - `columns`: the tracks. The default is one `1fr` column per item: one
///   row of equally wide cards. (This default is the element's own: `Grid`
///   has one `auto` column, which puts the cards one under the other.)
/// - `gutter`, `column_gutter`, `row_gutter`: the grid's; none by default.
/// - `fill`, `stroke`, `inset`: of every card; by default the cell's (no
///   fill, no stroke, no inset: set them).
///
/// An item is the body of a card (a `GridCell` among the items is not a
/// cell of the grid: for cells of your own, use `Grid`). A row with fewer
/// items than columns is left open: there is no card where there is no
/// item. No items: nothing.
///
/// Provenance: the call. An item that is a plain string resolves to the
/// `items` argument under the key of its index (`"0"`, `"1"`, ..: every
/// card is `Keyed` with it, so descriptions of the caller inside a card
/// have that key too); an error in `fill` is at `fill`.
///
/// Twin: the function `cards` of `doc/twins/kit.mbt`, a `grid` of
/// `grid.cell`s.
pub struct Cards {
  priv composite : @doc.Composite
}

///|
/// The call of a `Cards`: its site and its arguments. The parameters by
/// their index in the declaration of `Cards::Cards`, for `site.arg`: items
/// 0, columns 1, gutter 2, column_gutter 3, row_gutter 4, fill 5, stroke 6,
/// inset 7.
priv struct Call {
  site : @doc.CompositeSite
  /// The caller's content, converted once.
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
/// The grid of the cards.
fn Call::grid(self : Call, cells : Array[&@doc.IntoContent]) -> @doc.Grid {
  let site = self.site
  @doc.Grid(
    cells,
    columns=site.arg(1, self.tracks),
    gutter?=site.arg(2, self.gutter),
    column_gutter?=site.arg(3, self.column_gutter),
    row_gutter?=site.arg(4, self.row_gutter),
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
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Cards {
  let composite = @doc.Composite("Cards", loc, args_loc, site => {
    let call : Call = {
      site,
      items: items.map(item => @doc.Content(item)),
      tracks: match columns {
        Some(columns) => columns
        // One row of equally wide cards.
        None => @doc.Sizing::repeat(items.length(), size=Fr(1))
      },
      gutter,
      column_gutter,
      row_gutter,
      fill,
      stroke,
      inset,
    }
    // The cells draw the cards.
    let cells : Array[&@doc.IntoContent] = []
    for k in 0..<items.length() {
      cells.push(call.cell(k))
    }
    call.grid(cells)
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
