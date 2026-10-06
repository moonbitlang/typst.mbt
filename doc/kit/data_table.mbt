// `DataTable` (docs/edsl-ports.md, section 4; findings H5 and N9, and the
// rows of section 2.4 on auto columns and on the sides of a stroke): a
// table of data that is given by rows.

///|
/// A table of data: a header, rows of cells, a rule under each row, and a
/// rounded frame if it is given a `radius`.
///
/// ```mbt nocheck
/// DataTable(
///   ["Bed", "Crop", "Harvest"],
///   beds.map(bed => [bed.name, bed.crop, fixed(bed.kilograms, 1)]),
///   columns=[Auto, Fr(1), Auto],
///   align=Cells::columns([Left, Left, Right]),
///   stroke=Stroke(thickness=Pt(0.5), paint=Luma(180)),
///   radius=Corners(all=Pt(4)),
/// )
/// ```
///
/// It is a `Table`: the head in a `TableHeader`, then the cells of the
/// rows in their order, under `SetTableCell(breakable=..)`:
///
/// ```mbt nocheck
/// Seq([
///   SetTableCell(breakable=false),
///   Table([TableHeader(head), ..cells], columns~, inset~, align~, fill~,
///     stroke=Cells::all(Sides(bottom=stroke, rest=Stroke::none()))),
/// ])
/// ```
///
/// and with `radius`, that sequence in `Block(.., fill=frame_fill,
/// stroke=Sides(all=stroke), radius~, clip=true)`, the table ending with
/// `TableHline(stroke=Stroke::none())`. What it does that a `Table` of the
/// same cells does not:
///
/// - **The cells are given by rows, and every row is checked.** A `Table`
///   takes one array of cells and starts a new row whenever the columns
///   are full: a row with a cell too many or too few moves every cell
///   after it, without a diagnostic. Here a row whose cells do not fill
///   the columns is an error when the document is compiled, at the `rows`
///   argument under the key of that row, and the message names the row. A
///   `TableCell` among the cells is counted with its `colspan`, and its
///   `rowspan` takes its columns in the rows below: a row that cells from
///   above fill is `[]`. An item that a table does not place in its row (a
///   `TableCell` with an `x` or a `y`, a `TableHline`, a `TableVline`, a
///   header, a footer) is an error. A cell of the head cannot span rows:
///   the header is one row. The count reads the descriptions
///   (`@doc.Content::table_cell_spans`), so three things are one column
///   for it whatever the engine makes of them: a `Markup` (which is a cell
///   with a span only if its source is nothing but one), a span that is
///   computed, and a cell under a rule of the document that sets spans.
///   There the check is not the engine's count (a row with such a
///   `Markup` is reported although it fits): a cell that spans is written
///   as a `TableCell` with its span.
/// - **The header repeats** on every page that the table continues on
///   (`TableHeader`). Without a head (`[]`) there is no header.
/// - **A row is not split** at the end of a page: its cells are
///   unbreakable (by a rule, which a table inside a cell inherits), and it
///   moves to the next page as a whole. A row that is
///   higher than a page fits no page and leaves it, without a diagnostic,
///   like any unbreakable block: for a table with such rows,
///   `breakable=true`.
/// - **The only lines are the rules.** `stroke` is the rule under each
///   row. The other sides of the cells have no stroke, explicitly: a
///   stroke that names one side leaves the others to the table's default,
///   which draws every line of the grid (docs/edsl-guide.md, section 6.4).
/// - **The frame** (with `radius`): a block with rounded corners around
///   the table, outlined in `stroke`, that clips the fills of the cells to
///   its corners. It is as wide as the table. The table then has no rule
///   under its last row, which the frame closes. A table that continues
///   on the next page is framed on each page, on all four sides (the
///   engine draws every part of a broken block as a whole box), and has
///   no rule under the last row of a page either: the line that ends the
///   table ends each of its parts. (Without a frame the rule under the
///   last row of a page is drawn, as under every row.)
/// - **The surface** of a framed table is the frame's, `frame_fill`: on a
///   page that is not white, the white that the table stands on. It is not
///   the fill of every cell (`fill=Cells::all(..)`). The engine paints the
///   fill of a block, then its outline, then what is in the block, clipped
///   at the inner edge of the outline. So the frame's fill is beneath the
///   outline, which comes out as the outline of a filled box, in every
///   part of a table that continues on the next page. A fill of the cells
///   is painted after the outline, and where the two meet, in the pixels
///   that the outline covers in part, it takes some of the outline away:
///   its inner edge is lighter, by an amount that depends on where the
///   edge falls among the pixels. `fill` is for the cells that differ from
///   the surface (a header, a marked row), whose fill meets the outline in
///   that way in their rows, as in any clipped block.
///
/// It does not measure and creates no callback: it can be built anywhere,
/// also inside a callback. (A `Cells` function that the caller passes is
/// the caller's callback, and is created where the caller creates it.)
///
/// Parameters, with the names and types of `Table`, `TableCell` and
/// `Block`:
///
/// - `head`, `rows`: the cells. A cell is anything that is content, or a
///   `TableCell` for a cell with a span or a look of its own.
/// - `columns`: the table's tracks. Required: a column for every cell of
///   a row, and Typst's `Auto` columns do not share the width as the
///   columns of an HTML table do (docs/edsl-guide.md, section 6.1), so
///   the widths are the author's choice.
/// - `inset`, `align`, `fill`: the table's, per cell (`Cells::all`,
///   `Cells::columns` for the columns, or a function of the column and
///   the row); by default the table's. The row of a cell counts the
///   header: with a head, row 0 is the header and row `i + 1` is
///   `rows[i]`. Numbers to the right: `align=Cells::columns([Left,
///   Right])`. A marked row: `fill=Cells((_, y) => ..)`. (The surface of
///   a framed table is not a `fill` of its cells: `frame_fill`.)
/// - `stroke`: one `Stroke`, the rule under each row and the outline of
///   the frame; by default the default stroke (1pt, black; for the rules,
///   what a `SetTable(stroke=..)` of the document sets).
///   `Stroke::none()`: no lines. A cell with other lines has them as its
///   own (`TableCell(.., stroke=Sides(top=..))`).
/// - `radius`: the corners of the frame, and the choice of a frame.
/// - `frame_fill`: `Block`'s `fill`, for the frame; by default none. It
///   has the name of its part because `fill` is the table's, per cell: a
///   `Table` and a `Block` both have a `fill`, and the element is the
///   table. Without `radius` there is no frame, and it is an error at
///   `frame_fill`. (A frame with square corners: `radius=Corners(all=
///   Pt(0))`.)
/// - `breakable`: `TableCell`'s, for every cell. The default, `false`, is
///   the element's own: a row of data is not split. A `TableCell` of the
///   caller can say otherwise for itself.
/// - `key`: the key of row `i` (`rows[i]`), for the review loop; by
///   default its index (`"0"`, `"1"`, ..). Rows from data that is sorted
///   or filtered keep their identity with a key from the data
///   (`key=i => beds[i].id`). Two rows with one key are not told apart.
///   A key that `Keyed` does not take (one that starts with U+FDD2) is an
///   error at `key`.
///
/// Not parameters: the text. The size of the table's text, the style of
/// the header and of a column are rules of the document, which reach the
/// cells of the element as they reach the cells of any table: `SetText`
/// before it, `ShowSet(Select::table_cell(y=0), SetText(..))` for the
/// header, `ShowSet(Select::table_cell(x=2), SetText(..))` for a column
/// (the later rule wins where both match). `Table`'s other parameters
/// (`rows`, the gutters) are set by `SetTable(..)` before the element,
/// as for any table.
///
/// What a `Table` can have and a `DataTable` cannot: cells with a position,
/// lines and a footer among the rows, a header of more than one row, a
/// frame in another stroke than the rules. A table with those is a
/// `Table`.
///
/// For what reads descriptions (the lint of adjacent text, `Para`) it is a
/// block, with a frame and without.
///
/// Provenance: the call. A cell that is a plain string resolves to the
/// `head` argument, or to the `rows` argument under the key of its row
/// (every cell of a row is `Keyed` with it, so descriptions of the caller
/// in a row have that key too); an error in `fill` is at `fill`, one in
/// `frame_fill` at `frame_fill`.
///
/// Twin: the function `data-table` of `doc/twins/kit.mbt`.
pub struct DataTable {
  priv composite : @doc.Composite
}

///|
/// What is wrong with the cells of a table that is given by rows: the row
/// (`-1`: the head) and the message.
priv struct Misfit {
  row : Int
  message : String
}

///|
/// The name of a row in a message.
fn row_name(row : Int) -> String {
  if row < 0 {
    "`head`"
  } else {
    "`rows[\{row}]`"
  }
}

///|
/// A number of columns in a message.
fn columns_of(count : Int) -> String {
  if count == 1 {
    "1 column"
  } else {
    "\{count} columns"
  }
}

///|
/// The first row of `rows` (the head first, as row `-1`, if it has cells)
/// whose cells do not fill `columns` columns, as a table places them: each
/// cell in the next column that no cell from a row above takes, over as
/// many columns and rows as it spans.
fn misfit(
  columns : Int,
  head : Array[@doc.Content],
  rows : Array[Array[@doc.Content]],
) -> Misfit? {
  // Per column: how many rows from here on a cell from above takes it,
  // and the row of that cell.
  let taken = Array::make(columns, 0)
  let from = Array::make(columns, 0)
  let first = if head.is_empty() { 0 } else { -1 }
  for row in first..<rows.length() {
    let cells = if row < 0 { head } else { rows[row] }
    let spans : Array[(Int, Int)] = []
    let mut own = 0
    for cell in cells {
      guard cell.table_cell_spans() is Some((colspan, rowspan)) else {
        return Some({
          row,
          message: "\{row_name(row)} has an item that a table does not place in its row (a `TableCell` with an `x` or a `y`, a line, a header or a footer): the rows of a `DataTable` hold cells",
        })
      }
      // (More columns than the table has are too many, however many.)
      let colspan = if colspan > columns { columns + 1 } else { colspan }
      spans.push((colspan, rowspan))
      own += colspan
    }
    let mut above = 0
    for column in 0..<columns {
      if taken[column] > 0 {
        above += 1
      }
    }
    if own + above != columns {
      let beside = if above == 0 {
        ""
      } else {
        " beside the \{above} that cells of the rows above take"
      }
      return Some({
        row,
        message: "\{row_name(row)} has cells for \{columns_of(own)}\{beside}: this `DataTable` has \{columns_of(columns)}",
      })
    }
    // The cells in their columns. (The count leaves every cell its
    // columns unless one from above is in its way: `at` is a column.)
    let below = Array::make(columns, 0)
    let mut column = 0
    for span in spans {
      let (colspan, rowspan) = span
      while column < columns && taken[column] > 0 {
        column += 1
      }
      for at in column..<(column + colspan) {
        guard at < columns && taken[at] == 0 else {
          return Some({
            row,
            message: "a cell of \{row_name(row)} spans into a column that a cell of the rows above takes",
          })
        }
        below[at] = rowspan - 1
      }
      column += colspan
    }
    for column in 0..<columns {
      if taken[column] > 0 {
        taken[column] -= 1
      } else {
        taken[column] = below[column]
        from[column] = row
      }
    }
    // The header is one row.
    if row < 0 && taken.iter().any(rest => rest > 0) {
      return Some({
        row,
        message: "a cell of `head` spans rows: the header of a `DataTable` is one row",
      })
    }
  }
  for column in 0..<columns {
    if taken[column] > 0 {
      return Some({
        row: from[column],
        message: "a cell of \{row_name(from[column])} spans rows below the last row of `rows`",
      })
    }
  }
  None
}

///|
#callsite(autofill(loc, args_loc))
pub fn DataTable::DataTable(
  head : Array[&@doc.IntoContent],
  rows : Array[Array[&@doc.IntoContent]],
  columns~ : Array[@doc.Sizing],
  inset? : @doc.Cells[@doc.Sides[@doc.Length]],
  align? : @doc.Cells[@doc.Alignment],
  fill? : @doc.Cells[@doc.Paint],
  stroke? : @doc.Stroke,
  radius? : @doc.Corners[@doc.Length],
  frame_fill? : @doc.Paint,
  breakable? : Bool = false,
  key? : (Int) -> String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> DataTable {
  // The keys of the rows. (`key` is a function of the caller: it runs
  // before the hook, where what it builds has its own call sites.)
  let keys = Array::makei(rows.length(), row => {
    match key {
      Some(key) => key(row)
      None => row.to_string()
    }
  })
  // The parameters by their index in this declaration, for `site.arg`:
  // head 0, rows 1, columns 2, inset 3, align 4, fill 5, stroke 6, radius
  // 7, frame_fill 8, breakable 9, key 10.
  let composite = @doc.Composite("DataTable", loc, args_loc, site => {
    // (Copies, and the caller's content converted once: a description
    // does not change when the caller's arrays do.)
    let tracks = columns.copy()
    let head = head.map(cell => @doc.Content(cell))
    let rows = rows.map(row => row.map(cell => @doc.Content(cell)))
    if tracks.is_empty() {
      return site.invalid(
        "a `DataTable` needs its `columns`: a track for every cell of a row",
        arg=2,
      )
    }
    // The fill of a frame that is not there would be dropped without a
    // word.
    if frame_fill is Some(_) && radius is None {
      return site.invalid(
        "a `DataTable` has a frame only with a `radius`: `frame_fill` is the fill of the frame",
        arg=8,
      )
    }
    // A key that `Keyed` does not take is an error at `key`, not at the
    // cells that would carry it.
    for row, key in keys {
      if key.has_prefix("\u{FDD2}") {
        return site.invalid(
          "the key of `rows[\{row}]` starts with a reserved character (U+FDD2)",
          arg=10,
        )
      }
    }
    if misfit(tracks.length(), head, rows) is Some(misfit) {
      return if misfit.row < 0 {
        site.invalid(misfit.message, arg=0)
      } else {
        @doc.Content(
          @doc.Keyed(keys[misfit.row], site.invalid(misfit.message, arg=1)),
        )
      }
    }
    let children : Array[&@doc.IntoContent] = []
    if !head.is_empty() {
      children.push(
        @doc.TableHeader(
          site.arg(0, head.map(cell => cell as &@doc.IntoContent)),
        ),
      )
    }
    for row, cells in rows {
      for cell in cells {
        children.push(@doc.Keyed(keys[row], cell))
      }
    }
    if radius is Some(_) {
      // The frame closes the table: no rule under its last row, nor under
      // the last row of a page (a line without a stroke takes away the
      // lines at its place, and the line that ends a table ends each of
      // its parts).
      children.push(@doc.TableHline(stroke=@doc.Stroke::none()))
    }
    // The rule, or the default stroke.
    let rule = match stroke {
      Some(stroke) => stroke
      None => @doc.Stroke()
    }
    let table = @doc.Table(
      site.arg(1, children),
      columns=site.arg(2, tracks),
      inset?=site.arg(3, inset),
      align?=site.arg(4, align),
      fill?=site.arg(5, fill),
      // (The sides that are not named would be the table's default
      // stroke: they are named.)
      stroke=@doc.Cells::all(
        @doc.Sides(bottom=site.arg(6, rule), rest=@doc.Stroke::none()),
      ),
    )
    let ruled = @doc.Seq([
      @doc.SetTableCell(breakable=site.arg(9, breakable)),
      table,
    ])
    match radius {
      None => @doc.Content(ruled)
      Some(radius) =>
        @doc.Content(
          @doc.Block(
            ruled,
            // (Beneath the outline, which is beneath the cells: "The
            // surface" above.)
            fill?=site.arg(8, frame_fill),
            stroke=@doc.Sides(all=site.arg(6, rule)),
            radius=site.arg(7, radius),
            clip=true,
          ),
        )
    }
  })
  { composite, }
}

///|
pub impl @doc.IntoContent for DataTable with fn into_content(self) {
  @doc.IntoContent::into_content(self.composite)
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataTable with @doc.IntoContent::{into_content}

///|
/// Interpolation into the text of `Prose`.
pub impl Show for DataTable with fn output(self, logger) {
  Show::output(self.composite, logger)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataTable with Show::{to_string, output}

///|
pub impl @debug.Debug for DataTable with fn to_repr(self) {
  @debug.Debug::to_repr(self.composite)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataTable with @debug.Debug::{to_repr}
