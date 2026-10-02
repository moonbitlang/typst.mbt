// Port of `typst-layout/src/grid/layouter.rs`.
//
// Upstream's `GridLayouter` borrows the grid and mutates copies of the
// (`Copy`) regions in place; here the regions are immutable values that are
// replaced (`self.regions = ...`), and the header slices of the grid are
// `ArrayView`s.

///|
/// Performs grid layout.
priv struct GridLayouter {
  /// The grid of cells.
  grid : @library.CellGrid
  /// The regions to layout children into.
  mut regions : @library.Regions
  /// The locators for the each cell in the cell grid.
  cell_locators : Map[@library.Axes[Int], @library.Locator]
  /// The inherited styles.
  styles : @library.StyleChain
  /// Resolved column sizes.
  rcols : Array[@library.Abs]
  /// The sum of `rcols`.
  mut width : @library.Abs
  /// Resolved row sizes, by region.
  rrows : Array[Array[RowPiece]]
  /// The amount of unbreakable rows remaining to be laid out in the
  /// current unbreakable row group. While this is positive, no region breaks
  /// should occur.
  mut unbreakable_rows_left : Int
  /// Rowspans not yet laid out because not all of their spanned rows were
  /// laid out yet.
  mut rowspans : Array[Rowspan]
  /// Grid layout state for the current region.
  current : Current
  /// Frames for finished regions.
  mut finished : Array[@library.Frame]
  /// The amount and height of header rows on each finished region.
  finished_header_rows : Array[FinishedHeaderRowInfo]
  /// Whether this is an RTL grid.
  is_rtl : Bool
  /// Currently repeating headers, one per level. Sorted by increasing
  /// levels.
  ///
  /// Note that some levels may be absent, in particular level 0, which does
  /// not exist (so all levels are >= 1).
  repeating_headers : Array[@library.Header]
  /// Headers, repeating or not, awaiting their first successful layout.
  /// Sorted by increasing levels.
  mut pending_headers : ArrayView[@library.Repeatable[@library.Header]]
  /// Next headers to be processed.
  mut upcoming_headers : ArrayView[@library.Repeatable[@library.Header]]
  /// State of the row being currently laid out.
  ///
  /// This is kept as a field to avoid passing down too many parameters from
  /// `layout_row` into called functions, which would then have to pass them
  /// down to `push_row`, which reads these values.
  mut row_state : RowState
  /// The span of the grid element.
  span : @syntax.Span
}

///|
/// Grid layout state for the current region. This should be reset or updated
/// on each region break.
priv struct Current {
  /// The initial size of the current region before we started subtracting.
  mut initial : @library.Axes[@library.Abs]
  /// The height of the region after repeated headers were placed and footers
  /// prepared. This also includes pending repeating headers from the start,
  /// even if they were not repeated yet, since they will be repeated in the
  /// next region anyway (bar orphan prevention).
  ///
  /// This is used to quickly tell if any additional space in the region has
  /// been occupied since then, meaning that additional space will become
  /// available after a region break (see
  /// [GridLayouter::may_progress_with_repeats]).
  mut initial_after_repeats : @library.Abs
  /// Whether `layouter.regions.may_progress()` was `true` at the top of the
  /// region.
  mut could_progress_at_top : Bool
  /// Rows in the current region.
  mut lrows : Array[Row]
  /// The amount of repeated header rows at the start of the current region.
  /// Thus, excludes rows from pending headers (which were placed for the
  /// first time).
  ///
  /// Note that `repeating_headers` and `pending_headers` can change if we
  /// find a new header inside the region (not at the top), so this field
  /// is required to access information from the top of the region.
  ///
  /// This information is used on finish region to calculate the total height
  /// of resolved header rows at the top of the region, which is used by
  /// multi-page rowspans so they can properly skip the header rows at the
  /// top of each region during layout.
  mut repeated_header_rows : Int
  /// The end bound of the row range of the last repeating header at the
  /// start of the region.
  ///
  /// The last row might have disappeared from layout due to being empty, so
  /// this is how we can become aware of where the last header ends without
  /// having to check the vector of rows. Line layout uses this to determine
  /// when to prioritize the last lines under a header.
  ///
  /// A value of zero indicates no repeated headers were placed.
  mut last_repeated_header_end : Int
  /// Stores the length of `lrows` before a sequence of rows equipped with
  /// orphan prevention was laid out. In this case, if no more rows without
  /// orphan prevention are laid out after those rows before the region ends,
  /// the rows will be removed, and there may be an attempt to place them
  /// again in the new region. Effectively, this is the mechanism used for
  /// orphan prevention of rows.
  ///
  /// At the moment, this is only used by repeated headers (they aren't laid
  /// out if alone in the region) and by new headers, which are moved to the
  /// `pending_headers` vector and so will automatically be placed again
  /// until they fit and are not orphans in at least one region (or exactly
  /// one, for non-repeated headers).
  mut lrows_orphan_snapshot : Int?
  /// The height of effectively repeating headers, that is, ignoring
  /// non-repeating pending headers, in the current region.
  ///
  /// This is used by multi-page auto rows so they can inform cell layout on
  /// how much space should be taken by headers if they break across regions.
  /// In particular, non-repeating headers only occupy the initial region,
  /// but disappear on new regions, so they can be ignored.
  ///
  /// This field is reset on each new region and properly updated by
  /// `layout_auto_row` and `layout_relative_row`, and should not be read
  /// before all header rows are fully laid out. It is usually fine because
  /// header rows themselves are unbreakable, and unbreakable rows do not
  /// need to read this field at all.
  ///
  /// This height is not only computed at the beginning of the region. It is
  /// updated whenever a new header is found, subtracting the height of
  /// headers which stopped repeating and adding the height of all new
  /// headers.
  mut repeating_header_height : @library.Abs
  /// The height for each repeating header that was placed in this region.
  /// Note that this includes headers not at the top of the region, before
  /// their first repetition (pending headers), and excludes headers removed
  /// by virtue of a new, conflicting header being found (short-lived
  /// headers).
  ///
  /// This is used to know how much to update `repeating_header_height` by
  /// when finding a new header and causing existing repeating headers to
  /// stop.
  repeating_header_heights : Array[@library.Abs]
  /// The simulated footer height for this region.
  ///
  /// The simulation occurs before any rows are laid out for a region.
  mut footer_height : @library.Abs
}

///|
/// Data about the row being laid out right now.
priv struct RowState {
  /// If this is `Some`, this will be updated by the currently laid out row's
  /// height if it is auto or relative. This is used for header height
  /// calculation.
  mut current_row_height : @library.Abs?
  /// This is `true` when laying out non-short lived headers and footers.
  /// That is, headers and footers which are not immediately followed or
  /// preceded (respectively) by conflicting headers and footers of same or
  /// lower level, or the end or start of the table (respectively), which
  /// would cause them to never repeat, even once.
  ///
  /// If this is `false`, the next row to be laid out will remove an active
  /// orphan snapshot and will flush pending headers, as there is no risk
  /// that they will be orphans anymore.
  in_active_repeatable : Bool
  /// This is `false` if a header row is laid out the first time, and `false`
  /// for any other time. For footers it's the opposite, this will be `true`
  /// the last time the footer is laid out, and `false` for all previous
  /// occurrences.
  is_being_repeated : Bool
}

///|
fn RowState::default() -> RowState {
  {
    current_row_height: None,
    in_active_repeatable: false,
    is_being_repeated: false,
  }
}

///|
/// Data about laid out repeated header rows for a specific finished region.
priv struct FinishedHeaderRowInfo {
  /// The amount of repeated headers at the top of the region.
  repeated_amount : Int
  /// The end bound of the row range of the last repeated header at the top
  /// of the region.
  last_repeated_header_end : Int
  /// The total height of repeated headers at the top of the region.
  repeated_height : @library.Abs
}

///|
fn FinishedHeaderRowInfo::default() -> FinishedHeaderRowInfo {
  {
    repeated_amount: 0,
    last_repeated_header_end: 0,
    repeated_height: @library.Abs::zero(),
  }
}

///|
/// Details about a resulting row piece.
priv struct RowPiece {
  /// The height of the segment.
  height : @library.Abs
  /// The index of the row.
  y : Int
}

///|
/// Produced by initial row layout, auto and relative rows are already finished,
/// fractional rows not yet.
priv enum Row {
  /// Finished row frame of auto or relative row with y index.
  /// The last parameter indicates whether or not this is the last region
  /// where this row is laid out, and it can only be false when a row uses
  /// `layout_multi_row`, which in turn is only used by breakable auto rows.
  Frame(@library.Frame, Int, Bool)
  /// Fractional row with y index and disambiguator.
  Fr(@library.Fr, Int, Int)
}

///|
/// Returns the `y` index of this row.
fn Row::index(self : Row) -> Int {
  match self {
    Frame(_, y, _) => y
    Fr(_, y, _) => y
  }
}

///|
/// Rust's `Iterator::sum` for lengths: the neutral element of float sums is
/// `-0.0`, which is visible in the output through signed zeros.
fn abs_sum(iter : Iter[@library.Abs]) -> @library.Abs {
  iter.fold(init=@library.Abs::raw(-0.0), (acc, x) => acc + x)
}

///|
/// `usize::saturating_sub`.
fn saturating_sub(a : Int, b : Int) -> Int {
  if a > b {
    a - b
  } else {
    0
  }
}

///|
/// Sets the height of the first region (upstream `regions.size.y = height`).
fn with_height(
  regions : @library.Regions,
  y : @library.Abs,
) -> @library.Regions {
  { ..regions, size: { ..regions.size, y, }, }
}

///|
/// Create a new grid layouter.
///
/// This prepares grid layout by unifying content and gutter tracks.
fn GridLayouter::new(
  grid : @library.CellGrid,
  regions : @library.Regions,
  locator : @library.Locator,
  styles : @library.StyleChain,
  span : @syntax.Span,
) -> GridLayouter {
  // We use these regions for auto row measurement. Since at that moment,
  // columns are already sized, we can enable horizontal expansion.
  let regions = { ..regions, expand: @library.Axes::new(true, false), }

  // Prepare the locators for each cell in the cell grid.
  let locator = locator.split()
  let cell_locators = Map([])
  for y in 0..<grid.rows.length() {
    for x in 0..<grid.cols.length() {
      guard grid.entry(x, y) is Some(Cell(cell)) else { continue }
      cell_locators[@library.Axes::new(x, y)] = locator.next(cell.body.span())
    }
  }
  {
    grid,
    regions,
    cell_locators,
    styles,
    rcols: Array::make(grid.cols.length(), @library.Abs::zero()),
    width: @library.Abs::zero(),
    rrows: [],
    unbreakable_rows_left: 0,
    rowspans: [],
    finished: [],
    finished_header_rows: [],
    is_rtl: @library.TextElem::dir_in(styles).resolve(styles) == RTL,
    repeating_headers: [],
    upcoming_headers: grid.headers[:],
    pending_headers: [][:],
    row_state: RowState::default(),
    current: {
      initial: regions.size,
      initial_after_repeats: regions.size.y,
      could_progress_at_top: regions.may_progress(),
      lrows: [],
      repeated_header_rows: 0,
      last_repeated_header_end: 0,
      lrows_orphan_snapshot: None,
      repeating_header_height: @library.Abs::zero(),
      repeating_header_heights: [],
      footer_height: @library.Abs::zero(),
    },
    span,
  }
}

///|
/// Sets the remaining height of the current region.
fn GridLayouter::set_height(self : GridLayouter, y : @library.Abs) -> Unit {
  self.regions = with_height(self.regions, y)
}

///|
/// Create a [Locator] for use in [layout_cell].
fn GridLayouter::cell_locator(
  self : GridLayouter,
  pos : @library.Axes[Int],
  disambiguator : Int,
) -> @library.Locator {
  let mut cell_locator = self.cell_locators.get(pos).unwrap().relayout()

  // The disambiguator is used for repeated cells, e.g. in repeated headers.
  if disambiguator > 0 {
    cell_locator = cell_locator
      .split()
      .next_inner(@library.U128::from_u64(disambiguator.to_uint64()))
  }
  cell_locator
}

///|
/// Determines the columns sizes and then layouts the grid row-by-row.
fn GridLayouter::layout(
  self : GridLayouter,
  engine : @library.Engine,
) -> @library.Fragment raise @library.SourceError {
  self.measure_columns(engine)
  if self.grid.footer is Some(footer) && footer.repeated {
    // Ensure rows in the first region will be aware of the
    // possible presence of the footer.
    self.prepare_footer(footer.inner, engine, 0)
    self.set_height(self.regions.size.y - self.current.footer_height)
    self.current.initial_after_repeats = self.regions.size.y
  }
  let mut y = 0
  let mut consecutive_header_count = 0
  while y < self.grid.rows.length() {
    if self.upcoming_headers.get(consecutive_header_count) is Some(next_header) &&
      next_header.inner.range.contains(y) {
      consecutive_header_count = self.place_new_headers(
        consecutive_header_count, engine,
      )
      y = next_header.inner.range.end

      // Skip header rows during normal layout.
      continue
    }
    if self.grid.footer is Some(footer) &&
      footer.repeated &&
      y >= footer.inner.start {
      if y == footer.inner.start {
        self.layout_footer(footer.inner, engine, self.finished.length(), false)
        self.flush_orphans()
      }
      y = footer.inner.end
      continue
    }
    self.layout_row(y, engine, 0)

    // After the first non-header row is placed, pending headers are no
    // longer orphans and can repeat, so we move them to repeating
    // headers.
    //
    // Note that this is usually done in `push_row`, since the call to
    // `layout_row` above might trigger region breaks (for multi-page
    // auto rows), whereas this needs to be called as soon as any part
    // of a row is laid out. However, it's possible a row has no
    // visible output and thus does not push any rows even though it
    // was successfully laid out, in which case we additionally flush
    // here just in case.
    self.flush_orphans()
    y += 1
  }
  self.finish_region(engine, true)

  // Layout any missing rowspans.
  // There are only two possibilities for rowspans not yet laid out
  // (usually, a rowspan is laid out as soon as its last row, or any row
  // after it, is laid out):
  // 1. The rowspan was fully empty and only spanned fully empty auto
  // rows, which were all prevented from being laid out. Those rowspans
  // are ignored by 'layout_rowspan', and are not of any concern.
  //
  // 2. The rowspan's last row was an auto row at the last region which
  // was not laid out, and no other rows were laid out after it. Those
  // might still need to be laid out, so we check for them.
  let rowspans = self.rowspans
  self.rowspans = []
  for rowspan in rowspans {
    self.layout_rowspan(rowspan, None, engine)
  }
  self.render_fills_strokes()
}

///|
/// Layout a row with a certain initial state, returning the final state.
fn GridLayouter::layout_row_with_state(
  self : GridLayouter,
  y : Int,
  engine : @library.Engine,
  disambiguator : Int,
  initial_state : RowState,
) -> RowState raise @library.SourceError {
  // Keep a copy of the previous value in the stack, as this function can
  // call itself recursively (e.g. if a region break is triggered and a
  // header is placed), so we shouldn't outright overwrite it, but rather
  // save and later restore the state when back to this call.
  let previous = self.row_state
  self.row_state = initial_state

  // Keep it as a separate function to allow inlining the return below,
  // as it's usually not needed.
  self.layout_row_internal(y, engine, disambiguator)
  let state = self.row_state
  self.row_state = previous
  state
}

///|
/// Layout the given row with the default row state.
fn GridLayouter::layout_row(
  self : GridLayouter,
  y : Int,
  engine : @library.Engine,
  disambiguator : Int,
) -> Unit raise @library.SourceError {
  self.layout_row_with_state(y, engine, disambiguator, RowState::default())
  |> ignore
}

///|
/// Layout the given row using the current state.
fn GridLayouter::layout_row_internal(
  self : GridLayouter,
  y : Int,
  engine : @library.Engine,
  disambiguator : Int,
) -> Unit raise @library.SourceError {
  // Skip to next region if current one is full, but only for content
  // rows, not for gutter rows, and only if we aren't laying out an
  // unbreakable group of rows.
  let is_content_row = !self.grid.is_gutter_track(y)
  if self.unbreakable_rows_left == 0 && self.regions.is_full() && is_content_row {
    self.finish_region(engine, false)
  }
  if is_content_row {
    // Gutter rows have no rowspans or possibly unbreakable cells.
    self.check_for_rowspans(disambiguator, y)
    self.check_for_unbreakable_rows(y, engine)
  }

  // Don't layout gutter rows at the top of a region.
  if is_content_row || !self.current.lrows.is_empty() {
    match self.grid.rows[y] {
      Auto => self.layout_auto_row(engine, disambiguator, y)
      Rel(v) => self.layout_relative_row(engine, disambiguator, v, y)
      Fr(v) => {
        if !self.row_state.in_active_repeatable {
          self.flush_orphans()
        }
        self.current.lrows.push(Row::Fr(v, y, disambiguator))
      }
    }
  }
  self.unbreakable_rows_left = saturating_sub(self.unbreakable_rows_left, 1)
}

///|
/// Which line position to look for in the list of lines for a track, such
/// that placing lines with those positions will correspond to placing them
/// before the given track index.
///
/// If the index represents a gutter track, this means the list of lines will
/// actually correspond to the list of lines in the previous index, so we must
/// look for lines positioned after the previous index, and not before, to
/// determine which lines should be placed before gutter.
///
/// Note that the maximum index is always an odd number when there's gutter,
/// so we must check for it to ensure we don't give it the same treatment as a
/// line before a gutter track.
fn GridLayouter::expected_line_position(
  self : GridLayouter,
  index : Int,
  is_max_index : Bool,
) -> @library.LinePosition {
  if self.grid.is_gutter_track(index) && !is_max_index {
    After
  } else {
    Before
  }
}

///|
/// Add lines and backgrounds.
fn GridLayouter::render_fills_strokes(self : GridLayouter) -> @library.Fragment {
  let finished = self.finished
  self.finished = []
  let frame_amount = finished.length()
  for frame_index, frame in finished {
    let rows = self.rrows[frame_index]
    let finished_header_rows = self.finished_header_rows.get(frame_index)
    if self.rcols.is_empty() || rows.is_empty() {
      continue
    }

    // Render grid lines.
    // We collect lines into a vector before rendering so we can sort
    // them based on thickness, such that the lines with largest
    // thickness are drawn on top; and also so we can prepend all of
    // them at once in the frame, as calling prepend() for each line,
    // and thus pushing all frame items forward each time, would result
    // in quadratic complexity.
    let lines : Array[
      (@library.Abs, StrokePriority, @library.Point, @library.FrameItem),
    ] = []

    // Render vertical lines.
    // Render them first so horizontal lines have priority later.
    for x, dx in points(self.rcols.iter()) {
      let dx = if self.is_rtl { self.width - dx } else { dx }
      let is_end_border = x == self.grid.cols.length()
      let expected_vline_position = self.expected_line_position(
        x, is_end_border,
      )
      let vlines_at_column = match
        self.grid.vlines.get(
          if !self.grid.has_gutter {
            x
          } else if is_end_border {
            // The end border has its own vector of lines, but
            // dividing it by 2 and flooring would give us the
            // vector of lines with the index of the last column.
            // Add 1 so we get the border's lines.
            x / 2 + 1
          } else {
            // If x is a gutter column, this will round down to the
            // index of the previous content column, which is
            // intentional - the only lines which can appear before
            // a gutter column are lines for the previous column
            // marked with "LinePosition::After". Therefore, we get
            // the previous column's lines. Worry not, as
            // 'generate_line_segments' will correctly filter lines
            // based on their LinePosition for us.
            //
            // If x is a content column, this will correctly return
            // its index before applying gutters, so nothing
            // special here (lines with "LinePosition::After" would
            // then be ignored for this column, as we are drawing
            // lines before it, not after).
            x / 2
          },
        ) {
        Some(lines) =>
          lines.filter(line => line.position == expected_vline_position)
        None => []
      }
      let tracks = rows.map(row => (row.y, row.height))

      // Determine all different line segments we have to draw in
      // this column, and convert them to points and shapes.
      //
      // Even a single, uniform line might generate more than one
      // segment, if it happens to cross a colspan (over which it
      // must not be drawn).
      let segments = generate_line_segments(
        self.grid,
        tracks,
        x,
        vlines_at_column,
        vline_stroke_at_row,
      )
      for segment in segments {
        let { stroke, offset: dy, length, priority, } = segment
        let stroke = stroke.unwrap_or_default()
        let thickness = stroke.thickness
        let half = thickness.div_by(2.0)
        let target = @library.Point::with_y(length + thickness)
        let vline = @library.Geometry::Line(target).stroked(stroke)
        lines.push(
          (
            thickness,
            priority,
            @library.Point::new(dx, dy - half),
            @library.FrameItem::Shape(vline, self.span),
          ),
        )
      }
    }

    // Render horizontal lines.
    // They are rendered second as they default to appearing on top.
    // First, calculate their offsets from the top of the frame.
    let hline_offsets = points(rows.iter().map(piece => piece.height))

    // Additionally, determine their indices (the indices of the
    // rows they are drawn on top of). In principle, this will
    // correspond to the rows' indices directly, except for the
    // last hline index, which must be (amount of rows) in order to
    // draw the table's bottom border.
    let hline_indices = rows.map(piece => piece.y)
    hline_indices.push(self.grid.rows.length())

    // Converts a row to the corresponding index in the vector of
    // hlines.
    let hline_index_of_row = (y : Int) => {
      if !self.grid.has_gutter {
        y
      } else if y == self.grid.rows.length() {
        y / 2 + 1
      } else {
        // Check the vlines loop for an explanation regarding
        // these index operations.
        y / 2
      }
    }
    let get_hlines_at = (y : Int) => {
      self.grid.hlines.get(hline_index_of_row(y)).unwrap_or([])
    }
    let mut prev_y : Int? = None
    for i, y in hline_indices {
      let dy = hline_offsets[i]
      // Position of lines below the row index in the previous iteration.
      let expected_prev_line_position = match prev_y {
        Some(prev_y) =>
          self.expected_line_position(
            prev_y + 1,
            prev_y + 1 == self.grid.rows.length(),
          )
        None => @library.LinePosition::Before
      }

      // Header's lines at the bottom have priority when repeated.
      // This will store the end bound of the last header if the
      // current iteration is calculating lines under it.
      let last_repeated_header_end_above = match finished_header_rows {
        Some(info) if prev_y is Some(_) && i == info.repeated_amount =>
          Some(info.last_repeated_header_end)
        _ => None
      }

      // If some grid rows were omitted between the previous resolved
      // row and the current one, we ensure lines below the previous
      // row don't "disappear" and are considered, albeit with less
      // priority. However, don't do this when we're below a header,
      // as it must have more priority instead of less, so it is
      // chained later instead of before (stored in the
      // 'header_hlines' variable below). The exception is when the
      // last row in the header is removed, in which case we append
      // both the lines under the row above us and also (later) the
      // lines under the header's (removed) last row.
      let prev_lines = match prev_y {
        Some(prev_y) if prev_y + 1 != y &&
          (match last_repeated_header_end_above {
            None => true
            Some(last_repeated_header_end) =>
              prev_y + 1 != last_repeated_header_end
          }) => get_hlines_at(prev_y + 1)
        _ => []
      }
      let expected_hline_position = self.expected_line_position(
        y,
        y == self.grid.rows.length(),
      )
      let hlines_at_y = get_hlines_at(y).filter(line => {
        line.position == expected_hline_position
      })
      let top_border_hlines = if prev_y is None && y != 0 {
        // For lines at the top of the region, give priority to
        // the lines at the top border.
        get_hlines_at(0)
      } else {
        []
      }
      let mut expected_header_line_position = @library.LinePosition::Before
      let header_hlines = match (last_repeated_header_end_above, prev_y) {
        (Some(header_end_above), Some(prev_y)) if !self.grid.has_gutter ||
          (match self.grid.rows[prev_y] {
            Rel(length) => length.is_zero()
            _ => false
          }) => {
          // For lines below a header, give priority to the
          // lines originally below the header rather than
          // the lines of what's below the repeated header.
          // However, no need to do that when we're laying
          // out the header for the first time, since the
          // lines being normally laid out then will be
          // precisely the lines below the header.
          //
          // Additionally, we don't repeat lines above the row
          // below the header when gutter is enabled, since, in
          // that case, there will be a gutter row between header
          // and content, so no lines should overlap. The
          // exception is when the gutter at the end of the
          // header has a size of zero, which happens when only
          // column-gutter is specified, for example. In that
          // case, we still repeat the line under the gutter.
          expected_header_line_position = self.expected_line_position(
            header_end_above,
            header_end_above == self.grid.rows.length(),
          )
          get_hlines_at(header_end_above)
        }
        _ => []
      }

      // The effective hlines to be considered at this row index are
      // chained in order of increasing priority:
      // 1. Lines from the row right above us, if needed;
      // 2. Lines from the current row (usually, only those are
      // present);
      // 3. Lines from the top border (above the top cells, hence
      // 'before' position only);
      // 4. Lines from the header above us, if present.
      let hlines_at_row = []
      for line in prev_lines {
        if line.position == expected_prev_line_position {
          hlines_at_row.push(line)
        }
      }
      hlines_at_row.append(hlines_at_y)
      for line in top_border_hlines {
        if line.position == Before {
          hlines_at_row.push(line)
        }
      }
      for line in header_hlines {
        if line.position == expected_header_line_position {
          hlines_at_row.push(line)
        }
      }
      let tracks = self.rcols.mapi((x, col) => (x, col))

      // Normally, given an hline above row y, the row above it is
      // 'y - 1' (if y > 0). However, sometimes that's not true, for
      // example if 'y - 1' is in a previous region, or if 'y - 1'
      // was an empty auto row which was removed. Therefore, we tell
      // the hlines at this index which row is actually above them in
      // the laid out region so they can include that row's bottom
      // strokes in the folding process.
      let local_top_y = prev_y

      // When we're in the last region, the bottom border stroke
      // doesn't necessarily gain priority like it does in previous
      // regions.
      let in_last_region = frame_index + 1 == frame_amount

      // Determine all different line segments we have to draw in
      // this row, and convert them to points and shapes.
      let segments = generate_line_segments(
        self.grid,
        tracks,
        y,
        hlines_at_row,
        (grid, y, x, stroke) => {
          hline_stroke_at_column(
            grid, rows, local_top_y, last_repeated_header_end_above, in_last_region,
            y, x, stroke,
          )
        },
      )
      for segment in segments {
        let { stroke, offset: dx, length, priority, } = segment
        let stroke = stroke.unwrap_or_default()
        let thickness = stroke.thickness
        let half = thickness.div_by(2.0)
        let dx = if self.is_rtl { self.width - dx - length } else { dx }
        let target = @library.Point::with_x(length + thickness)
        let hline = @library.Geometry::Line(target).stroked(stroke)
        // Draw later (after we sort all lines below.)
        lines.push(
          (
            thickness,
            priority,
            @library.Point::new(dx - half, dy),
            @library.FrameItem::Shape(hline, self.span),
          ),
        )
      }
      prev_y = Some(y)
    }

    // Sort by increasing thickness, so that we draw larger strokes
    // on top. When the thickness is the same, sort by priority.
    //
    // Sorting by thickness avoids layering problems where a smaller
    // hline appears "inside" a larger vline. When both have the same
    // size, hlines are drawn on top (since the sort is stable, and
    // they are pushed later).
    let order = Array::makei(lines.length(), i => i)
    order.sort_by((a, b) => {
      let (ta, pa, _, _) = lines[a]
      let (tb, pb, _, _) = lines[b]
      let c = Compare::compare(ta, tb)
      if c != 0 {
        return c
      }
      let c = Compare::compare(pa, pb)
      if c != 0 {
        return c
      }
      Compare::compare(a, b)
    })

    // Render cell backgrounds.
    // We collect them into a vector so they can all be prepended at
    // once to the frame, together with lines.
    let fills : Array[(@library.Point, @library.FrameItem)] = []

    // Reverse with RTL so that later columns start first.
    let mut dx = @library.Abs::zero()
    for x, col in self.rcols {
      let mut dy = @library.Abs::zero()
      for row in rows {
        // We want to only draw the fill starting at the parent
        // positions of cells. However, sometimes the parent
        // position is absent from the current region, either
        // because the first few rows of a rowspan were empty auto
        // rows and thus removed from layout, or because the parent
        // cell was in a previous region (in which case we'd want
        // to draw its fill again, in the current region).
        // Therefore, we first analyze the parent position to see
        // if the current row would be the first row spanned by the
        // parent cell in this region. If so, this means we have to
        // start drawing the cell's fill here. If not, we ignore
        // the position `(x, row.y)`, as its fill will already have
        // been rendered before.
        //
        // Note: In the case of gutter rows, we have to check the
        // row below before discarding them fully, because a
        // gutter row might be the first row spanned by a rowspan
        // in this region (e.g. if the first row was empty and
        // therefore removed), so its fill could start in that
        // gutter row. That's why we use
        // 'effective_parent_cell_position'.
        let parent = match self.grid.effective_parent_cell_position(x, row.y) {
          // Ensure this is the first column spanned by the
          // cell before drawing its fill, otherwise we
          // already rendered its fill in a previous
          // iteration of the outer loop (and/or this is a
          // gutter column, which we ignore).
          //
          // Additionally, we should only draw the fill when
          // this row is the local parent Y for this cell,
          // that is, the first row spanned by the cell's
          // parent in this region, because if the parent
          // cell's fill was already drawn in a previous
          // region, we must render it again in later regions
          // spanned by that cell. Note that said condition
          // always holds when the current cell has a rowspan
          // of 1 and we're not currently at a gutter row.
          Some(parent) if parent.x == x &&
            (
              parent.y == row.y ||
              (match first_row_from(rows, parent.y) {
                Some(first_spanned_row) => first_spanned_row.y == row.y
                None => false
              })
            ) => Some(parent)
          _ => None
        }
        if parent is Some(parent) {
          let cell = self.grid.cell(parent.x, parent.y).unwrap()
          if cell.fill is Some(fill) {
            let rowspan = self.grid.effective_rowspan_of_cell(cell)
            let height = if rowspan == 1 {
              row.height
            } else {
              abs_sum(
                rows
                .iter()
                .filter(row => parent.y <= row.y && row.y < parent.y + rowspan)
                .map(row => row.height),
              )
            }
            let width = self.cell_spanned_width(cell, x)
            let mut pos = @library.Point::new(dx, dy)
            if self.is_rtl {
              // In RTL cells expand to the left, thus the
              // position must additionally be offset by the
              // cell's width.
              pos = { ..pos, x: self.width - (dx + width), }
            }
            let size = @library.Axes::new(width, height)
            let rect = @library.Geometry::Rect(size).filled(fill)
            fills.push((pos, @library.FrameItem::Shape(rect, self.span)))
          }
        }
        dy = dy + row.height
      }
      dx = dx + col
    }

    // Now we render each fill and stroke by prepending to the frame,
    // such that both appear below cell contents. Fills come first so
    // that they appear below lines.
    for i in order {
      let (_, _, point, shape) = lines[i]
      fills.push((point, shape))
    }
    frame.prepend_multiple(fills.iter())
  }
  @library.Fragment::frames(finished)
}

///|
/// Determine all column sizes.
fn GridLayouter::measure_columns(
  self : GridLayouter,
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  // Sum of sizes of resolved relative tracks.
  let mut rel = @library.Abs::zero()

  // Sum of fractions of all fractional tracks.
  let mut fr = @library.Fr::zero()

  // Resolve the size of all relative columns and compute the sum of all
  // fractional tracks.
  for x, col in self.grid.cols {
    match col {
      Auto => ()
      Rel(v) => {
        let resolved = v.resolve(self.styles).relative_to(self.regions.base().x)
        self.rcols[x] = resolved
        rel = rel + resolved
      }
      Fr(v) => fr = fr + v
    }
  }

  // Size that is not used by fixed-size columns.
  let available = self.regions.size.x - rel
  if available >= @library.Abs::zero() {
    // Determine size of auto columns.
    let (auto, count) = self.measure_auto_columns(engine, available)

    // If there is remaining space, distribute it to fractional columns,
    // otherwise shrink auto columns.
    let remaining = available - auto
    if remaining >= @library.Abs::zero() {
      self.grow_fractional_columns(remaining, fr)
    } else {
      self.shrink_auto_columns(available, count)
    }
  }

  // Sum up the resolved column sizes once here.
  self.width = abs_sum(self.rcols.iter())
}

///|
/// Total width spanned by the cell (among resolved columns).
/// Includes spanned gutter columns.
fn GridLayouter::cell_spanned_width(
  self : GridLayouter,
  cell : @library.Cell,
  x : Int,
) -> @library.Abs {
  let colspan = self.grid.effective_colspan_of_cell(cell)
  abs_sum(self.rcols.iter().drop(x).take(colspan))
}

///|
/// Measure the size that is available to auto columns.
fn GridLayouter::measure_auto_columns(
  self : GridLayouter,
  engine : @library.Engine,
  available : @library.Abs,
) -> (@library.Abs, Int) raise @library.SourceError {
  let mut auto = @library.Abs::zero()
  let mut count = 0
  let all_frac_cols = []
  for x, col in self.grid.cols {
    if col.is_fractional() {
      all_frac_cols.push(x)
    }
  }

  // Determine size of auto columns by laying out all cells in those
  // columns, measuring them and finding the largest one.
  for x, col in self.grid.cols {
    if col != Auto {
      continue
    }
    let mut resolved = @library.Abs::zero()
    for y in 0..<self.grid.rows.length() {
      // We get the parent cell in case this is a merged position.
      guard self.grid.parent_cell_position(x, y) is Some(parent) else {
        continue
      }
      if parent.y != y {
        // Don't check the width of rowspans more than once.
        continue
      }
      let cell = self.grid.cell(parent.x, parent.y).unwrap()
      let colspan = self.grid.effective_colspan_of_cell(cell)
      if colspan > 1 {
        let mut last_spanned_auto_col = None
        let end = (parent.x + colspan).min(self.grid.cols.length())
        for cx = end - 1; cx >= parent.x; cx = cx - 1 {
          if self.grid.cols[cx] == Auto {
            last_spanned_auto_col = Some(cx)
            break
          }
        }
        if last_spanned_auto_col != Some(x) {
          // A colspan only affects the size of the last spanned
          // auto column.
          continue
        }
      }
      if colspan > 1 &&
        self.regions.size.x.is_finite() &&
        !all_frac_cols.is_empty() &&
        all_frac_cols
        .iter()
        .all(fx => parent.x <= fx && fx < parent.x + colspan) {
        // Additionally, as a heuristic, a colspan won't affect the
        // size of auto columns if it already spans all fractional
        // columns, since those would already expand to provide all
        // remaining available after auto column sizing to that
        // cell. However, this heuristic is only valid in finite
        // regions (pages without 'auto' width), since otherwise
        // the fractional columns don't expand at all.
        continue
      }

      // Sum the heights of spanned rows to find the expected
      // available height for the cell, unless it spans a fractional
      // or auto column.
      let rowspan = self.grid.effective_rowspan_of_cell(cell)
      let height = {
        let mut acc : @library.Abs? = Some(@library.Abs::zero())
        for row in self.grid.rows.iter().drop(y).take(rowspan) {
          // For relative rows, we can already resolve the correct
          // base and for auto and fr we could only guess anyway.
          match row {
            Rel(v) =>
              acc = acc.map(acc => {
                acc + v.resolve(self.styles).relative_to(self.regions.base().y)
              })
            _ => {
              acc = None
              break
            }
          }
        }
        acc.unwrap_or(self.regions.base().y)
      }

      // Don't expand this auto column more than the cell actually
      // needs. To do this, we check how much the other, previously
      // resolved columns provide to the cell in terms of width
      // (if it is a colspan), and subtract this from its expected
      // width when comparing with other cells in this column. Note
      // that, since this is the last auto column spanned by this
      // cell, all other auto columns will already have been resolved
      // and will be considered.
      // Only fractional columns will be excluded from this
      // calculation, which can lead to auto columns being expanded
      // unnecessarily when cells span both a fractional column and
      // an auto column. One mitigation for this is the heuristic
      // used above to not expand the last auto column spanned by a
      // cell if it spans all fractional columns in a finite region.
      let already_covered_width = self.cell_spanned_width(cell, parent.x)
      let size = @library.Axes::new(available, height)
      let pod = @library.LayoutRegion::new(size, @library.Axes::splat(false))
      let locator = self.cell_locator(parent, 0)
      let frame = layout_cell(
        cell,
        engine,
        locator,
        self.styles,
        @library.Regions::from_region(pod),
        self.row_state.is_being_repeated,
      ).into_frame()
      resolved = resolved.max(frame.width() - already_covered_width)
    }
    self.rcols[x] = resolved
    auto = auto + resolved
    count += 1
  }
  (auto, count)
}

///|
/// Distribute remaining space to fractional columns.
fn GridLayouter::grow_fractional_columns(
  self : GridLayouter,
  remaining : @library.Abs,
  fr : @library.Fr,
) -> Unit {
  if fr.get() == 0.0 {
    return
  }
  for x, col in self.grid.cols {
    if col is Fr(v) {
      self.rcols[x] = v.share(fr, remaining)
    }
  }
}

///|
/// Redistribute space to auto columns so that each gets a fair share.
fn GridLayouter::shrink_auto_columns(
  self : GridLayouter,
  available : @library.Abs,
  count : Int,
) -> Unit {
  let mut last = @library.Abs::zero()
  let mut fair = -@library.Abs::inf()
  let mut redistribute = available
  let mut overlarge = count
  let mut changed = true

  // Iteratively remove columns that don't need to be shrunk.
  while changed && overlarge > 0 {
    changed = false
    last = fair
    fair = redistribute.div_by(overlarge.to_double())
    for x, col in self.grid.cols {
      let rcol = self.rcols[x]
      // Remove an auto column if it is not overlarge (rcol <= fair),
      // but also hasn't already been removed (rcol > last).
      if col == Auto && rcol <= fair && rcol > last {
        redistribute = redistribute - rcol
        overlarge -= 1
        changed = true
      }
    }
  }

  // Redistribute space fairly among overlarge columns.
  for x, col in self.grid.cols {
    if col == Auto && self.rcols[x] > fair {
      self.rcols[x] = fair
    }
  }
}

///|
/// Layout a row with automatic height. Such a row may break across multiple
/// regions.
fn GridLayouter::layout_auto_row(
  self : GridLayouter,
  engine : @library.Engine,
  disambiguator : Int,
  y : Int,
) -> Unit raise @library.SourceError {
  // Determine the size for each region of the row. If the first region
  // ends up empty for some column, skip the region and remeasure.
  let resolved = match
    self.measure_auto_row(
      engine,
      disambiguator,
      y,
      true,
      self.unbreakable_rows_left,
      None,
    ) {
    Some(resolved) => resolved
    None => {
      self.finish_region(engine, false)
      self
      .measure_auto_row(
        engine,
        disambiguator,
        y,
        false,
        self.unbreakable_rows_left,
        None,
      )
      .unwrap()
    }
  }

  // Nothing to layout.
  if resolved.is_empty() {
    return
  }

  // Layout into a single region.
  if resolved is [first] {
    let frame = self.layout_single_row(engine, disambiguator, first, y)
    self.push_row(frame, y, true)
    if self.row_state.current_row_height is Some(row_height) {
      // Add to header height, as we are in a header row.
      self.row_state.current_row_height = Some(row_height + first)
    }
    return
  }

  // Expand all but the last region.
  // Skip the first region if the space is eaten up by an fr row.
  let len = resolved.length()
  let skip = if self.current.lrows.iter().any(row => row is Fr(_, _, _)) {
    1
  } else {
    0
  }
  for i, region in self.regions.iter().take(len - 1).collect() {
    if i < skip {
      continue
    }
    // Subtract header and footer heights from the region height when
    // it's not the first. Ignore non-repeating headers as they only
    // appear on the first region by definition.
    resolved[i] = resolved[i].max(
      region.y -
      (if i > 0 {
        self.current.repeating_header_height + self.current.footer_height
      } else {
        @library.Abs::zero()
      }),
    )
  }

  // Layout into multiple regions.
  let fragment = self.layout_multi_row(engine, disambiguator, resolved, y)
  let len = fragment.len()
  for i, frame in fragment.into_frames() {
    self.push_row(frame, y, i + 1 == len)
    if i + 1 < len {
      self.finish_region(engine, false)
    }
  }
}

///|
/// Measure the regions sizes of an auto row. The option is always `Some(_)`
/// if `can_skip` is false.
/// If `unbreakable_rows_left` is positive, this function shall only return
/// a single frame. Useful when an unbreakable rowspan crosses this auto
/// row.
/// The `row_group_data` option is used within the unbreakable row group
/// simulator to predict the height of the auto row if previous rows in the
/// group were placed in the same region.
fn GridLayouter::measure_auto_row(
  self : GridLayouter,
  engine : @library.Engine,
  disambiguator : Int,
  y : Int,
  can_skip : Bool,
  unbreakable_rows_left : Int,
  row_group_data : UnbreakableRowGroup?,
) -> Array[@library.Abs]? raise @library.SourceError {
  let breakable = unbreakable_rows_left == 0
  let resolved : Array[@library.Abs] = []
  let pending_rowspans : Array[(Int, Int, Array[@library.Abs])] = []
  for x in 0..<self.rcols.length() {
    // Get the parent cell in case this is a merged position.
    guard self.grid.parent_cell_position(x, y) is Some(parent) else {
      // Skip gutter columns.
      continue
    }
    if parent.x != x {
      // Only check the height of a colspan once.
      continue
    }
    // The parent cell is never a gutter or merged position.
    let cell = self.grid.cell(parent.x, parent.y).unwrap()
    let rowspan = self.grid.effective_rowspan_of_cell(cell)
    if rowspan > 1 {
      let mut last_spanned_auto_row = None
      let end = (parent.y + rowspan).min(self.grid.rows.length())
      for ry = end - 1; ry >= parent.y; ry = ry - 1 {
        if self.grid.rows[ry] == Auto {
          last_spanned_auto_row = Some(ry)
          break
        }
      }
      if last_spanned_auto_row != Some(y) {
        // A rowspan should only affect the height of its last
        // spanned auto row.
        continue
      }
    }
    let measurement_data = self.prepare_auto_row_cell_measurement(
      parent, cell, breakable, row_group_data,
    )
    let size = @library.Axes::new(
      measurement_data.width,
      measurement_data.height,
    )
    let backlog = measurement_data.backlog
    let pod = if !breakable {
      // Force cell to fit into a single region when the row is
      // unbreakable, even when it is a breakable rowspan, as a best
      // effort.
      let mut pod = @library.Regions::from_region(
        @library.LayoutRegion::new(size, self.regions.expand),
      )
      pod = { ..pod, full: measurement_data.full, }
      if measurement_data.frames_in_previous_regions > 0 {
        // Best effort to conciliate a breakable rowspan which
        // started at a previous region going through an
        // unbreakable auto row. Ensure it goes through previously
        // laid out regions, but stops at this one when measuring.
        pod = { ..pod, backlog, }
      }
      pod
    } else {
      // This row is breakable, so measure the cell normally, with
      // the initial height and backlog determined previously.
      {
        ..self.regions,
        size,
        backlog,
        full: measurement_data.full,
        last: measurement_data.last,
      }
    }
    let locator = self.cell_locator(parent, disambiguator)
    let frames = layout_cell(
      cell,
      engine,
      locator,
      self.styles,
      pod,
      self.row_state.is_being_repeated,
    ).into_frames()

    // HACK: Also consider frames empty if they only contain tags (see
    // `is_empty_frame`). Table and grid cells need to be locatable for pdf
    // accessibility, but the introspection tags interfere with the
    // layouting.

    // Skip the first region if one cell in it is empty. Then,
    // remeasure.
    let fpr = measurement_data.frames_in_previous_regions
    if fpr < frames.length() &&
      can_skip &&
      breakable &&
      is_empty_frame(frames[fpr]) &&
      frames[fpr + 1:].iter().any(frame => !is_empty_frame(frame)) {
      return None
    }

    // Skip frames from previous regions if applicable.
    let sizes = frames.iter().drop(fpr).map(frame => frame.height()).collect()

    // Don't expand this row more than the cell needs.
    // To figure out how much height the cell needs, we must first
    // subtract, from the cell's expected height, the already resolved
    // heights of its spanned rows. Note that this is the last spanned
    // auto row, so all previous auto rows were already resolved, as
    // well as fractional rows in previous regions.
    // Additionally, we subtract the heights of fixed-size rows which
    // weren't laid out yet, since those heights won't change in
    // principle.
    // Upcoming fractional rows are ignored.
    // Upcoming gutter rows might be removed, so we need to simulate
    // them.
    if rowspan > 1 {
      let should_simulate = self.prepare_rowspan_sizes(
        y,
        sizes,
        cell,
        parent.y,
        rowspan,
        unbreakable_rows_left,
        measurement_data,
      )
      if should_simulate {
        // Rowspan spans gutter and is breakable. We'll need to
        // run a simulation to predict how much this auto row needs
        // to expand so that the rowspan's contents fit into the
        // table.
        pending_rowspans.push((parent.y, rowspan, sizes))
        continue
      }
    }
    let common = resolved.length().min(sizes.length())
    for i in 0..<common {
      resolved[i] = resolved[i].max(sizes[i])
    }

    // New heights are maximal by virtue of being new. Note that
    // this extend only uses the rest of the sizes iterator.
    for i in common..<sizes.length() {
      resolved.push(sizes[i])
    }
  }

  // Simulate the upcoming regions in order to predict how much we need
  // to expand this auto row for rowspans which span gutter.
  if !pending_rowspans.is_empty() {
    self.simulate_and_measure_rowspans_in_auto_row(
      y, resolved, pending_rowspans, unbreakable_rows_left, row_group_data, disambiguator,
      engine,
    )
  }
  Some(resolved)
}

///|
/// Layout a row with relative height. Such a row cannot break across
/// multiple regions, but it may force a region break.
fn GridLayouter::layout_relative_row(
  self : GridLayouter,
  engine : @library.Engine,
  disambiguator : Int,
  v : @library.Rel[@library.Length],
  y : Int,
) -> Unit raise @library.SourceError {
  let resolved = v.resolve(self.styles).relative_to(self.regions.base().y)
  let frame = self.layout_single_row(engine, disambiguator, resolved, y)
  if self.row_state.current_row_height is Some(row_height) {
    // Add to header height, as we are in a header row.
    self.row_state.current_row_height = Some(row_height + resolved)
  }

  // Skip to fitting region, but only if we aren't part of an unbreakable
  // row group. We use 'may_progress_with_repeats' to stop trying if we
  // would skip to a region with the same height and where the same
  // headers would be repeated.
  let height = frame.height()
  while self.unbreakable_rows_left == 0 &&
        !self.regions.size.y.fits(height) &&
        self.may_progress_with_repeats() {
    self.finish_region(engine, false)

    // Don't skip multiple regions for gutter and don't push a row.
    if self.grid.is_gutter_track(y) {
      return
    }
  }
  self.push_row(frame, y, true)
}

///|
/// Layout a row with fixed height and return its frame.
fn GridLayouter::layout_single_row(
  self : GridLayouter,
  engine : @library.Engine,
  disambiguator : Int,
  height : @library.Abs,
  y : Int,
) -> @library.Frame raise @library.SourceError {
  if !self.width.is_finite() {
    @library.bail_at(self.span, "cannot create grid with infinite width")
  }
  if !height.is_finite() {
    @library.bail_at(self.span, "cannot create grid with infinite height")
  }
  let output = @library.Frame::soft(@library.Axes::new(self.width, height))
  let mut offset = @library.Point::zero()
  for x, rcol in self.rcols {
    if self.grid.cell(x, y) is Some(cell) {
      // Rowspans have a separate layout step
      if cell.rowspan == 1 {
        let width = self.cell_spanned_width(cell, x)
        let size = @library.Axes::new(width, height)
        let mut pod = @library.Regions::from_region(
          @library.LayoutRegion::new(size, @library.Axes::splat(true)),
        )
        if self.grid.rows[y] == Auto && self.unbreakable_rows_left == 0 {
          // Cells at breakable auto rows have lengths relative
          // to the entire page, unlike cells in unbreakable auto
          // rows.
          pod = { ..pod, full: self.regions.full, }
        }
        let locator = self.cell_locator(@library.Axes::new(x, y), disambiguator)
        let frame = layout_cell(
          cell,
          engine,
          locator,
          self.styles,
          pod,
          self.row_state.is_being_repeated,
        ).into_frame()
        let mut pos = offset
        if self.is_rtl {
          // In RTL cells expand to the left, thus the position
          // must additionally be offset by the cell's width.
          pos = { ..pos, x: self.width - (pos.x + width), }
        }
        output.push_frame(pos, frame)
      }
    }
    offset = { ..offset, x: offset.x + rcol, }
  }
  output
}

///|
/// Layout a row spanning multiple regions.
fn GridLayouter::layout_multi_row(
  self : GridLayouter,
  engine : @library.Engine,
  disambiguator : Int,
  heights : Array[@library.Abs],
  y : Int,
) -> @library.Fragment raise @library.SourceError {
  // Prepare frames.
  let outputs = heights.map(h => {
    @library.Frame::soft(@library.Axes::new(self.width, h))
  })

  // Prepare regions.
  let size = @library.Axes::new(self.width, heights[0])
  let mut pod = @library.Regions::from_region(
    @library.LayoutRegion::new(size, @library.Axes::splat(true)),
  )
  pod = { ..pod, full: self.regions.full, backlog: heights[1:], }

  // Layout the row.
  let mut offset = @library.Point::zero()
  for x, rcol in self.rcols {
    if self.grid.cell(x, y) is Some(cell) {
      // Rowspans have a separate layout step
      if cell.rowspan == 1 {
        let width = self.cell_spanned_width(cell, x)
        pod = { ..pod, size: { ..pod.size, x: width, }, }

        // Push the layouted frames into the individual output frames.
        let locator = self.cell_locator(@library.Axes::new(x, y), disambiguator)
        let fragment = layout_cell(
          cell,
          engine,
          locator,
          self.styles,
          pod,
          self.row_state.is_being_repeated,
        )
        for i, frame in fragment.into_frames() {
          if i >= outputs.length() {
            break
          }
          let mut pos = offset
          if self.is_rtl {
            // In RTL cells expand to the left, thus the
            // position must additionally be offset by the
            // cell's width.
            pos = { ..pos, x: self.width - (offset.x + width), }
          }
          outputs[i].push_frame(pos, frame)
        }
      }
    }
    offset = { ..offset, x: offset.x + rcol, }
  }
  @library.Fragment::frames(outputs)
}

///|
/// Push a row frame into the current region.
/// The `is_last` parameter must be `true` if this is the last frame which
/// will be pushed for this particular row. It can be `false` for rows
/// spanning multiple regions.
fn GridLayouter::push_row(
  self : GridLayouter,
  frame : @library.Frame,
  y : Int,
  is_last : Bool,
) -> Unit {
  if !self.row_state.in_active_repeatable {
    // There is now a row after the rows equipped with orphan
    // prevention, so no need to keep moving them anymore.
    self.flush_orphans()
  }
  self.set_height(self.regions.size.y - frame.height())
  self.current.lrows.push(Row::Frame(frame, y, is_last))
}

///|
/// Finish rows for one region.
fn GridLayouter::finish_region(
  self : GridLayouter,
  engine : @library.Engine,
  last : Bool,
) -> Unit raise @library.SourceError {
  // The latest rows have orphan prevention (headers) and no other rows
  // were placed, so remove those rows and try again in a new region,
  // unless this is the last region.
  let orphan_snapshot = self.current.lrows_orphan_snapshot
  self.current.lrows_orphan_snapshot = None
  if orphan_snapshot is Some(orphan_snapshot) && !last {
    if orphan_snapshot < self.current.lrows.length() {
      self.current.lrows.truncate(orphan_snapshot)
    }
    self.current.repeated_header_rows = self.current.repeated_header_rows.min(
      orphan_snapshot,
    )
    if orphan_snapshot == 0 {
      // Removed all repeated headers.
      self.current.last_repeated_header_end = 0
    }
  }
  if self.current.lrows.last() is Some(row) &&
    self.grid.is_gutter_track(row.index()) {
    self.current.lrows.pop() |> ignore
    // Remove the last row in the region if it is a gutter row.
    self.current.repeated_header_rows = self.current.repeated_header_rows.min(
      self.current.lrows.length(),
    )
  }

  // If no rows other than the footer have been laid out so far
  // (e.g. due to header orphan prevention), and there are rows
  // beside the footer, then don't lay it out at all.
  //
  // It is worth noting that the footer is made non-repeatable at
  // the grid resolving stage if it is short-lived, that is, if
  // it is at the start of the table (or right after headers at
  // the start of the table).
  //
  // TODO(subfooters): explicitly check for short-lived footers.
  // TODO(subfooters): widow prevention for non-repeated footers with a
  // similar mechanism / when implementing multiple footers.
  let footer_would_be_widow = (
      self.grid.footer is Some(footer) &&
      footer.repeated
    ) &&
    self.current.lrows.is_empty() &&
    self.current.could_progress_at_top
  let mut laid_out_footer_start = None
  if !footer_would_be_widow && self.grid.footer is Some(footer) {
    // Don't layout the footer if it would be alone with the header
    // in the page (hence the widow check), and don't layout it
    // twice (check below).
    //
    // TODO(subfooters): this check can be replaced by a vector of
    // repeating footers in the future, and/or some "pending
    // footers" vector for footers we're about to place.
    if footer.repeated &&
      self.current.lrows.iter().all(row => row.index() < footer.inner.start) {
      laid_out_footer_start = Some(footer.inner.start)
      self.layout_footer(footer.inner, engine, self.finished.length(), true)
    }
  }

  // Determine the height of existing rows in the region.
  let mut used = @library.Abs::zero()
  let mut fr = @library.Fr::zero()
  for row in self.current.lrows {
    match row {
      Frame(frame, _, _) => used = used + frame.height()
      Fr(v, _, _) => fr = fr + v
    }
  }

  // Determine the size of the grid in this region, expanding fully if
  // there are fr rows.
  let mut size = @library.Axes::new(
    self.width.min(self.current.initial.x),
    used.min(self.current.initial.y),
  )
  if fr.get() > 0.0 && self.current.initial.y.is_finite() {
    size = { ..size, y: self.current.initial.y, }
  }

  // The frame for the region.
  let output = @library.Frame::soft(size)
  let mut pos = @library.Point::zero()
  let rrows = []
  let current_region = self.finished.length()
  let mut repeated_header_row_height = @library.Abs::zero()

  // Place finished rows and layout fractional rows.
  let lrows = self.current.lrows
  self.current.lrows = []
  for i, row in lrows {
    let (frame, y, is_last) = match row {
      Frame(frame, y, is_last) => (frame, y, is_last)
      Fr(v, y, disambiguator) => {
        let remaining = self.regions.full - used
        let height = v.share(fr, remaining)
        (self.layout_single_row(engine, disambiguator, height, y), y, true)
      }
    }
    let height = frame.height()
    if i < self.current.repeated_header_rows {
      repeated_header_row_height = repeated_header_row_height + height
    }

    // Ensure rowspans which span this row will have enough space to
    // be laid out over it later.
    for rowspan in self.rowspans {
      if !(rowspan.y <= y && y < rowspan.y + rowspan.rowspan) {
        continue
      }
      if rowspan.max_resolved_row is Some(max_row) && !(y > max_row) {
        continue
      }
      // If the first region wasn't defined yet, it will have the
      // initial value of usize::MAX, so we can set it to the current
      // region's index.
      if rowspan.first_region > current_region {
        rowspan.first_region = current_region
        // The rowspan starts at this region, precisely at this
        // row. In other regions, it will start at dy = 0.
        rowspan.dy = pos.y
        // When we layout the rowspan later, the full size of the
        // pod must be equal to the full size of the first region
        // it appears in.
        rowspan.region_full = self.regions.full
      }
      let amount_missing_heights = saturating_sub(
        current_region + 1,
        rowspan.heights.length() + rowspan.first_region,
      )

      // Ensure the vector of heights is long enough such that the
      // last height is the one for the current region.
      for _ in 0..<amount_missing_heights {
        rowspan.heights.push(@library.Abs::zero())
      }

      // Ensure that, in this region, the rowspan will span at least
      // this row.
      let last_index = rowspan.heights.length() - 1
      rowspan.heights[last_index] = rowspan.heights[last_index] + height
      if is_last {
        // Do not extend the rowspan through this row again, even
        // if it is repeated in a future region.
        rowspan.max_resolved_row = Some(y)
      }
    }

    // We use a for loop over indices to avoid borrow checking
    // problems (we need to mutate the rowspans vector, so we can't
    // have an iterator actively borrowing it). We keep a separate
    // 'i' variable so we can step the counter back after removing
    // a rowspan (see explanation below).
    let mut i = 0
    while self.rowspans.get(i) is Some(rowspan) {
      // Layout any rowspans which end at this row, but only if this is
      // this row's last frame (to avoid having the rowspan stop being
      // laid out at the first frame of the row).
      // Any rowspans ending before this row are laid out even
      // on this row's first frame.
      if (match laid_out_footer_start {
          None => true
          // If this is a footer row, then only lay out this rowspan
          // if the rowspan is contained within the footer.
          Some(footer_start) => y < footer_start || rowspan.y >= footer_start
        }) &&
        (
          rowspan.y + rowspan.rowspan < y + 1 ||
          (rowspan.y + rowspan.rowspan == y + 1 && is_last)
        ) {
        // Rowspan ends at this or an earlier row, so we take
        // it from the rowspans vector and lay it out.
        // It's safe to pass the current region as a possible
        // region for the rowspan to be laid out in, even if
        // the rowspan's last row was at an earlier region,
        // because the rowspan won't have an entry for this
        // region in its 'heights' vector if it doesn't span
        // any rows in this region.
        //
        // Here we don't advance the index counter ('i') because
        // a new element we haven't checked yet in this loop
        // will take the index of the now removed element, so
        // we have to check the same index again in the next
        // iteration.
        let rowspan = self.rowspans.remove(i)
        self.layout_rowspan(
          rowspan,
          Some((output, repeated_header_row_height)),
          engine,
        )
      } else {
        i += 1
      }
    }
    output.push_frame(pos, frame)
    rrows.push({ height, y, })
    pos = { ..pos, y: pos.y + height, }
  }
  self.finish_region_internal(output, rrows, {
    repeated_amount: self.current.repeated_header_rows,
    last_repeated_header_end: self.current.last_repeated_header_end,
    repeated_height: repeated_header_row_height,
  })
  if !last {
    self.current.repeated_header_rows = 0
    self.current.last_repeated_header_end = 0
    self.current.repeating_header_height = @library.Abs::zero()
    self.current.repeating_header_heights.clear()
    let disambiguator = self.finished.length()
    if self.grid.footer is Some(footer) && footer.as_repeated() is Some(footer) {
      self.prepare_footer(footer, engine, disambiguator)
    }

    // Ensure rows don't try to overrun the footer.
    // Note that header layout will only subtract this again if it has
    // to skip regions to fit headers, so there is no risk of
    // subtracting this twice.
    self.set_height(self.regions.size.y - self.current.footer_height)
    self.current.initial_after_repeats = self.regions.size.y
    if !self.repeating_headers.is_empty() || !self.pending_headers.is_empty() {
      // Add headers to the new region.
      self.layout_active_headers(engine)
    }
  }
}

///|
/// Advances to the next region, registering the finished output and
/// resolved rows for the current region in the appropriate vectors.
fn GridLayouter::finish_region_internal(
  self : GridLayouter,
  output : @library.Frame,
  resolved_rows : Array[RowPiece],
  header_row_info : FinishedHeaderRowInfo,
) -> Unit {
  self.finished.push(output)
  self.rrows.push(resolved_rows)
  self.regions = self.regions.next()
  self.current.initial = self.regions.size

  // Repeats haven't been laid out yet, so in the meantime, this will
  // represent the initial height after repeats laid out so far, and will
  // be gradually updated when preparing footers and repeating headers.
  self.current.initial_after_repeats = self.current.initial.y
  self.current.could_progress_at_top = self.regions.may_progress()
  if !self.grid.headers.is_empty() {
    self.finished_header_rows.push(header_row_info)
  }
}

///|
/// Turn an iterator of extents into an iterator of offsets before, in between,
/// and after the extents, e.g. [10mm, 5mm] -> [0mm, 10mm, 15mm].
fn points(extents : Iter[@library.Abs]) -> Array[@library.Abs] {
  let mut offset = @library.Abs::zero()
  let out = [offset]
  for extent in extents {
    offset = offset + extent
    out.push(offset)
  }
  out
}

///|
/// The first resolved row with an index of at least `y` (upstream
/// `rows.iter().find(|row| row.y >= y)`).
fn first_row_from(rows : Array[RowPiece], y : Int) -> RowPiece? {
  for row in rows {
    if row.y >= y {
      return Some(row)
    }
  }
  None
}
