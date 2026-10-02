// Port of `typst-layout/src/grid/rowspans.rs`.

///|
/// All information needed to layout a single rowspan.
priv struct Rowspan {
  /// First column of this rowspan.
  x : Int
  /// First row of this rowspan.
  y : Int
  /// The disambiguator for laying out the cells.
  disambiguator : Int
  /// Amount of rows spanned by the cell at (x, y).
  rowspan : Int
  /// Whether all rows of the rowspan are part of an unbreakable row group.
  /// This is true e.g. in headers and footers, regardless of what the user
  /// specified for the parent cell's `breakable` field.
  mut is_effectively_unbreakable : Bool
  /// The horizontal offset of this rowspan in all regions.
  ///
  /// This is the offset from the text direction start, meaning that, on RTL
  /// grids, this is the offset from the right of the grid, whereas, on LTR
  /// grids, it is the offset from the left.
  dx : @library.Abs
  /// The vertical offset of this rowspan in the first region.
  mut dy : @library.Abs
  /// The index of the first region this rowspan appears in.
  mut first_region : Int
  /// The full height in the first region this rowspan appears in, for
  /// relative sizing.
  mut region_full : @library.Abs
  /// The vertical space available for this rowspan in each region.
  heights : Array[@library.Abs]
  /// The index of the largest resolved spanned row so far.
  /// Once a spanned row is resolved and its height added to `heights`, this
  /// number is increased. Older rows, even if repeated through e.g. a
  /// header, will no longer contribute height to this rowspan.
  ///
  /// This is `None` if no spanned rows were resolved in `finish_region` yet.
  mut max_resolved_row : Int?
  /// See [RowState::is_being_repeated].
  is_being_repeated : Bool
}

///|
/// The output of the simulation of an unbreakable row group.
priv struct UnbreakableRowGroup {
  /// The rows in this group of unbreakable rows.
  /// Includes their indices and their predicted heights.
  rows : Array[(Int, @library.Abs)]
  /// The total height of this row group.
  mut height : @library.Abs
}

///|
fn UnbreakableRowGroup::default() -> UnbreakableRowGroup {
  { rows: [], height: @library.Abs::zero(), }
}

///|
/// Data used to measure a cell in an auto row.
priv struct CellMeasurementData {
  /// The available width for the cell across all regions.
  width : @library.Abs
  /// The available height for the cell in its first region.
  /// Infinite when the auto row is unbreakable.
  height : @library.Abs
  /// The backlog of heights available for the cell in later regions.
  ///
  /// (Upstream distinguishes the current backlog from a `custom_backlog`
  /// built from scratch, which is only a borrowing concern.)
  backlog : ArrayView[@library.Abs]
  /// The full height of the first region of the cell.
  /// Infinite when the auto row is unbreakable.
  full : @library.Abs
  /// The height of the last repeated region to use in the measurement pod,
  /// if any.
  last : @library.Abs?
  /// The total height of previous rows spanned by the cell in the current
  /// region (so far).
  height_in_this_region : @library.Abs
  /// The amount of previous regions spanned by the cell.
  /// They are skipped for measurement purposes.
  frames_in_previous_regions : Int
}

///|
/// Layout a rowspan over the already finished regions, plus the current
/// region's frame and height of resolved header rows, if it wasn't
/// finished yet (because we're being called from `finish_region`, but note
/// that this function is also called once after all regions are finished,
/// in which case `current_region_data` is `None`).
///
/// We need to do this only once we already know the heights of all
/// spanned rows, which is only possible after laying out the last row
/// spanned by the rowspan (or some row immediately after the last one).
fn GridLayouter::layout_rowspan(
  self : GridLayouter,
  rowspan_data : Rowspan,
  current_region_data : (@library.Frame, @library.Abs)?,
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  let {
    x,
    y,
    disambiguator,
    rowspan,
    is_effectively_unbreakable,
    dx,
    dy,
    first_region,
    region_full,
    heights,
    is_being_repeated,
    ..
  } = rowspan_data
  guard heights is [first_height, .. backlog] else {
    // Nothing to layout.
    return
  }
  let cell = self.grid.cell(x, y).unwrap()
  let width = self.cell_spanned_width(cell, x)
  // In RTL cells expand to the left, thus the position
  // must additionally be offset by the cell's width.
  let dx = if self.is_rtl { self.width - (dx + width) } else { dx }

  // Prepare regions.
  let size = @library.Axes::new(width, first_height)
  let mut pod = @library.Regions::from_region(
    @library.LayoutRegion::new(size, @library.Axes::splat(true)),
  )
  pod = { ..pod, backlog, }
  if !is_effectively_unbreakable &&
    self.grid.rows[y:y + rowspan].iter().any(row => row == Auto) {
    // If the rowspan spans an auto row and is breakable, it will see
    // '100%' as the full page height, at least at its first region.
    // This is consistent with how it is measured, and with how
    // non-rowspan cells behave in auto rows.
    pod = { ..pod, full: region_full, }
  }

  // Push the layouted frames directly into the finished frames.
  let locator = self.cell_locator(@library.Axes::new(x, y), disambiguator)
  let fragment = layout_cell(
    cell,
    engine,
    locator,
    self.styles,
    pod,
    is_being_repeated,
  ).into_frames()

  // Clever trick to process finished header rows:
  // - If there are grid headers, the vector will be filled with one
  // finished header row height per region, so, chaining with the height
  // for the current one, we get the header row height for each region.
  //
  // - But if there are no grid headers, the vector will be empty, so in
  // theory the regions and resolved header row heights wouldn't match.
  // But that's fine - 'current_header_row_height' can only be either
  // 'Some(zero)' or 'None' in such a case, and for all other rows we
  // append infinite zeros. That is, in such a case, the resolved header
  // row height is always zero, so that's our fallback.
  let finished_header_rows = self.finished_header_rows.map(info => {
    info.repeated_height
  })
  let targets = self.finished.copy()
  if current_region_data is Some((current_region, current_header_row_height)) {
    targets.push(current_region)
    finished_header_rows.push(current_header_row_height)
  }
  for k in first_region..<targets.length() {
    let i = k - first_region
    guard fragment.get(i) is Some(frame) else { break }
    let header_dy = finished_header_rows.get(k).unwrap_or(@library.Abs::zero())
    let dy = if i == 0 {
      // At first, we draw the rowspan starting at its expected
      // vertical offset in the first region.
      dy
    } else {
      // The rowspan continuation starts after the header (thus,
      // at a position after the sum of the laid out header
      // rows). Without a header, this is zero, so the rowspan can
      // start at the very top of the region as usual.
      header_dy
    }
    targets[k].push_frame(@library.Point::new(dx, dy), frame)
  }
}

///|
/// Checks if a row contains the beginning of one or more rowspan cells.
/// If so, adds them to the rowspans vector.
fn GridLayouter::check_for_rowspans(
  self : GridLayouter,
  disambiguator : Int,
  y : Int,
) -> Unit {
  let offsets = points(self.rcols.iter())
  for x in 0..<self.rcols.length() {
    let dx = offsets[x]
    guard self.grid.cell(x, y) is Some(cell) else { continue }
    let rowspan = self.grid.effective_rowspan_of_cell(cell)
    if rowspan > 1 {
      // Rowspan detected. We will lay it out later.
      self.rowspans.push({
        x,
        y,
        disambiguator,
        rowspan,
        // The field below will be updated in
        // 'check_for_unbreakable_rows'.
        is_effectively_unbreakable: !cell.breakable,
        dx,
        // The four fields below will be updated in 'finish_region'.
        dy: @library.Abs::zero(),
        first_region: 0x7FFFFFFF,
        region_full: @library.Abs::zero(),
        heights: [],
        max_resolved_row: None,
        is_being_repeated: self.row_state.is_being_repeated,
      })
    }
  }
}

///|
/// Checks if the upcoming rows will be grouped together under an
/// unbreakable row group, and, if so, advances regions until there is
/// enough space for them. This can be needed, for example, if there's an
/// unbreakable rowspan crossing those rows.
fn GridLayouter::check_for_unbreakable_rows(
  self : GridLayouter,
  current_row : Int,
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  if self.unbreakable_rows_left == 0 {
    // By default, the amount of unbreakable rows starting at the
    // current row is dynamic and depends on the amount of upcoming
    // unbreakable cells (with or without a rowspan setting).
    let mut amount_unbreakable_rows = None
    if self.grid.footer is Some(footer) &&
      !footer.repeated &&
      current_row >= footer.inner.start {
      // Non-repeated footer, so keep it unbreakable.
      //
      // TODO(subfooters): This will become unnecessary
      // once non-repeated footers are treated differently and
      // have widow prevention.
      amount_unbreakable_rows = Some(
        self.grid.rows.length() - footer.inner.start,
      )
    }
    let row_group = self.simulate_unbreakable_row_group(
      current_row,
      amount_unbreakable_rows,
      self.regions,
      engine,
      0,
    )

    // Skip to fitting region.
    while !self.regions.size.y.fits(row_group.height) &&
          self.may_progress_with_repeats() {
      self.finish_region(engine, false)
    }

    // Update unbreakable rows left.
    self.unbreakable_rows_left = row_group.rows.length()
  }
  if self.unbreakable_rows_left > 1 {
    // Mark rowspans as effectively unbreakable where applicable
    // (if all of their spanned rows would be in the same unbreakable
    // row group).
    // Not needed if only one unbreakable row is left, since, then,
    // no rowspan will be effectively unbreakable, at least necessarily.
    // Note that this function is called after 'check_for_rowspans' and
    // potentially updates the amount of remaining unbreakable rows, so
    // it wouldn't be accurate to only check for this condition in that
    // function. We need to check here instead.
    for rowspan_data in self.rowspans {
      if rowspan_data.y == current_row {
        rowspan_data.is_effectively_unbreakable = rowspan_data.is_effectively_unbreakable ||
          self.unbreakable_rows_left >= rowspan_data.rowspan
      }
    }
  }
}

///|
/// Simulates a group of unbreakable rows, starting with the index of the
/// first row in the group. If `amount_unbreakable_rows` is `None`, keeps
/// adding rows to the group until none have unbreakable cells in common.
/// Otherwise, adds specifically the given amount of rows to the group.
///
/// This is used to figure out how much height the next unbreakable row
/// group (if any) needs.
fn GridLayouter::simulate_unbreakable_row_group(
  self : GridLayouter,
  first_row : Int,
  amount_unbreakable_rows : Int?,
  regions : @library.Regions,
  engine : @library.Engine,
  disambiguator : Int,
) -> UnbreakableRowGroup raise @library.SourceError {
  let row_group = UnbreakableRowGroup::default()
  let mut unbreakable_rows_left = amount_unbreakable_rows.unwrap_or(0)
  for y in first_row..<self.grid.rows.length() {
    let row = self.grid.rows[y]
    if amount_unbreakable_rows is None {
      // When we don't set a fixed amount of unbreakable rows,
      // determine the amount based on the rowspan of unbreakable
      // cells in rows.
      let additional_unbreakable_rows = self.check_for_unbreakable_cells(y)
      unbreakable_rows_left = unbreakable_rows_left.max(
        additional_unbreakable_rows,
      )
    }
    if unbreakable_rows_left == 0 {
      // This check is in case the first row does not have any
      // unbreakable cells. Therefore, no unbreakable row group
      // is formed.
      break
    }
    let height = match row {
      Rel(v) => v.resolve(self.styles).relative_to(regions.base().y)

      // No need to pass the regions to the auto row, since
      // unbreakable auto rows are always measured with infinite
      // height, ignore backlog, and do not invoke the rowspan
      // simulation procedure at all.
      Auto =>
        self
        .measure_auto_row(
          engine,
          disambiguator,
          y,
          false,
          unbreakable_rows_left,
          Some(row_group),
        )
        .unwrap()
        .get(0)
        .unwrap_or(@library.Abs::zero())
      // Fractional rows don't matter when calculating the space
      // needed for unbreakable rows
      Fr(_) => @library.Abs::zero()
    }
    row_group.height = row_group.height + height
    row_group.rows.push((y, height))
    unbreakable_rows_left -= 1
    if unbreakable_rows_left == 0 {
      // This second check is necessary so we can tell distinct
      // but consecutive unbreakable row groups apart. If the
      // unbreakable row group ended at this row, we stop before
      // checking the next one.
      break
    }
  }
  row_group
}

///|
/// Checks if one or more of the cells at the given row are unbreakable.
/// If so, returns the largest rowspan among the unbreakable cells;
/// the spanned rows must, as a result, be laid out in the same region.
fn GridLayouter::check_for_unbreakable_cells(
  self : GridLayouter,
  y : Int,
) -> Int {
  let mut max = 0
  for x in 0..<self.grid.cols.length() {
    guard self.grid.cell(x, y) is Some(cell) else { continue }
    if !cell.breakable {
      max = max.max(self.grid.effective_rowspan_of_cell(cell))
    }
  }
  max
}

///|
/// Used by `measure_auto_row` to gather data needed to measure the cell.
fn GridLayouter::prepare_auto_row_cell_measurement(
  self : GridLayouter,
  parent : @library.Axes[Int],
  cell : @library.Cell,
  breakable : Bool,
  row_group_data : UnbreakableRowGroup?,
) -> CellMeasurementData {
  let rowspan = self.grid.effective_rowspan_of_cell(cell)

  // This function is used to subtract the expected header and footer
  // height from each upcoming region size in the current backlog and
  // last region.
  let subtract_header_footer_height_from_regions = () => {
    // Only breakable auto rows need to update their backlogs based
    // on the presence of a header or footer, given that unbreakable
    // auto rows don't depend on the backlog, as they only span one
    // region.
    if breakable &&
      (
        !self.repeating_headers.is_empty() ||
        !self.pending_headers.is_empty() ||
        (self.grid.footer is Some(footer) && footer.repeated)
      ) {
      // Subtract header and footer height from all upcoming regions
      // when measuring the cell, including the last repeated region.
      //
      // This will update the 'custom_backlog' vector with the
      // updated heights of the upcoming regions.
      //
      // We predict that header height will only include that of
      // repeating headers, as we can assume non-repeating headers in
      // the first region have been successfully placed, unless
      // something didn't fit on the first region of the auto row,
      // but we will only find that out after measurement, and if
      // that happens, we discard the measurement and try again.
      let mapped_regions = self.regions.map(size => {
        @library.Axes::new(
          size.x,
          size.y -
          self.current.repeating_header_height -
          self.current.footer_height,
        )
      })

      // Callees must use the custom backlog instead of the current
      // backlog.
      return (mapped_regions.backlog, mapped_regions.last)
    }

    // No need to change the backlog or last region.
    (self.regions.backlog, self.regions.last)
  }

  // Each declaration, from top to bottom:
  // 1. The height available to the cell in the first region.
  // Usually, this will just be the size remaining in the current
  // region.
  // 2. The backlog of upcoming region heights to specify as
  // available to the cell.
  // 3. The full height of the first region of the cell.
  // 4. Height of the last repeated region to use in the measurement pod.
  // 5. The total height of the cell covered by previously spanned
  // rows in this region. This is used by rowspans to be able to tell
  // how much the auto row needs to expand.
  // 6. The amount of frames laid out by this cell in previous
  // regions. When the cell isn't a rowspan, this is always zero.
  // These frames are skipped after measuring.
  let (
    height,
    backlog,
    full,
    last,
    height_in_this_region,
    frames_in_previous_regions,
  ) = if rowspan == 1 {
    // Not a rowspan, so the cell only occupies this row. Therefore:
    // 1. When we measure the cell below, use the available height
    // remaining in the region as the height it has available.
    // However, if the auto row is unbreakable, measure with infinite
    // height instead to see how much content expands.
    // 2. Use the region's backlog and last region when measuring,
    // however subtract the expected header and footer heights from
    // each upcoming size, if there is a header or footer.
    // 3. Use the same full region height.
    // 4. No height occupied by this cell in this region so far.
    // 5. Yes, this cell started in this region.
    let height = if breakable {
      self.regions.size.y
    } else {
      @library.Abs::inf()
    }
    let (backlog, last) = subtract_header_footer_height_from_regions()
    let full = if breakable { self.regions.full } else { @library.Abs::inf() }
    (height, backlog, full, last, @library.Abs::zero(), 0)
  } else {
    // Height of the rowspan covered by spanned rows in the current
    // region.
    let laid_out_height = abs_sum(
      self.current.lrows
      .iter()
      .filter_map(row => {
        match row {
          Frame(frame, y, _) if parent.y <= y && y < parent.y + rowspan =>
            Some(frame.height())
          // Either we have a row outside of the rowspan, or a
          // fractional row, whose size we can't really guess.
          _ => None
        }
      }),
    )

    // If we're currently simulating an unbreakable row group, also
    // consider the height of previously spanned rows which are in
    // the row group but not yet laid out.
    let group_rows : Array[(Int, @library.Abs)] = match row_group_data {
      Some(row_group) => row_group.rows
      None => []
    }
    let unbreakable_height = abs_sum(
      group_rows
      .iter()
      .filter(row => parent.y <= row.0 && row.0 < parent.y + rowspan)
      .map(row => row.1),
    )
    let height_in_this_region = laid_out_height + unbreakable_height

    // Ensure we will measure the rowspan with the correct heights.
    // For that, we will gather the total height spanned by this
    // rowspan in previous regions.
    let found = self.rowspans
      .iter()
      .find_first(data => data.x == parent.x && data.y == parent.y)
    if found is Some(data) &&
      data.heights is [rowspan_height, .. rowspan_other_heights] {
      let rowspan_full = data.region_full
      // The rowspan started in a previous region (as it already
      // has at least one region height).
      // Therefore, its initial height will be the height in its
      // first spanned region, and the backlog will be the
      // remaining heights, plus the current region's size, plus
      // the current backlog.
      let frames_in_previous_regions = rowspan_other_heights.length() + 1
      let custom_backlog = rowspan_other_heights.to_owned()
      custom_backlog.push(
        if breakable {
          // Here we are calculating the available height for a
          // rowspan from the top of the current region, so
          // we have to use initial header heights (note that
          // header height can change in the middle of the
          // region).
          self.current.initial_after_repeats
        } else {
          // When measuring unbreakable auto rows, infinite
          // height is available for content to expand.
          @library.Abs::inf()
        },
      )
      if breakable {
        // This auto row is breakable. Therefore, join the
        // rowspan's already laid out heights with the current
        // region's height and current backlog to ensure a good
        // level of accuracy in the measurements.
        //
        // Assume only repeating headers will survive starting at
        // the next region.
        for size in self.regions.backlog {
          custom_backlog.push(
            size -
            self.current.repeating_header_height -
            self.current.footer_height,
          )
        }
      }
      // Otherwise, no extra backlog if this is an unbreakable auto row.
      // Ensure, when measuring, that the rowspan can be laid out through
      // all spanned rows which were already laid out so far, but don't go
      // further than this region.
      let last = self.regions.last.map(size => {
        size - self.current.repeating_header_height - self.current.footer_height
      })
      (
        rowspan_height,
        custom_backlog[:],
        rowspan_full,
        last,
        height_in_this_region,
        frames_in_previous_regions,
      )
    } else {
      // The rowspan started in the current region, as its vector
      // of heights in regions is currently empty.
      // Therefore, the initial height it has available will be
      // the current available size, plus the size spanned in
      // previous rows in this region (and/or unbreakable row
      // group, if it's being simulated).
      // The backlog and full will be that of the current region.
      // However, use infinite height instead if we're measuring an
      // unbreakable auto row.
      let height = if breakable {
        height_in_this_region + self.regions.size.y
      } else {
        @library.Abs::inf()
      }
      let (backlog, last) = subtract_header_footer_height_from_regions()
      let full = if breakable { self.regions.full } else { @library.Abs::inf() }
      (height, backlog, full, last, height_in_this_region, 0)
    }
  }
  let width = self.cell_spanned_width(cell, parent.x)
  {
    width,
    height,
    backlog,
    full,
    last,
    height_in_this_region,
    frames_in_previous_regions,
  }
}

///|
/// Used in `measure_auto_row` to prepare a rowspan's `sizes` vector.
/// Returns `true` if we'll need to run a simulation to more accurately
/// expand the auto row based on the rowspan's demanded size, or `false`
/// otherwise.
fn GridLayouter::prepare_rowspan_sizes(
  self : GridLayouter,
  auto_row_y : Int,
  sizes : Array[@library.Abs],
  cell : @library.Cell,
  parent_y : Int,
  rowspan : Int,
  unbreakable_rows_left : Int,
  measurement_data : CellMeasurementData,
) -> Bool {
  if sizes.length() <= 1 &&
    (match sizes.get(0) {
      None => true
      Some(first_frame_size) =>
        first_frame_size <= measurement_data.height_in_this_region
    }) {
    // Ignore a rowspan fully covered by rows in previous
    // regions and/or in the current region.
    sizes.clear()
    return false
  }
  if sizes.get(0) is Some(first_frame_size) {
    // Subtract already covered height from the size requested
    // by this rowspan to the auto row in the first region.
    sizes[0] = (first_frame_size - measurement_data.height_in_this_region).max(
      @library.Abs::zero(),
    )
  }
  let last_spanned_row = parent_y + rowspan - 1

  // When the rowspan is unbreakable, or all of its upcoming
  // spanned rows are in the same unbreakable row group, its
  // spanned gutter will certainly be in the same region as all
  // of its other spanned rows, thus gutters won't be removed,
  // and we can safely reduce how much the auto row expands by
  // without using simulation.
  let is_effectively_unbreakable_rowspan = !cell.breakable ||
    auto_row_y + unbreakable_rows_left > last_spanned_row

  // If the rowspan doesn't end at this row and the grid has
  // gutter, we will need to run a simulation to find out how
  // much to expand this row by later. This is because gutters
  // spanned by this rowspan might be removed if they appear
  // around a pagebreak, so the auto row might have to expand a
  // bit more to compensate for the missing gutter height.
  // However, unbreakable rowspans aren't affected by that
  // problem.
  if auto_row_y != last_spanned_row &&
    !sizes.is_empty() &&
    self.grid.has_gutter &&
    !is_effectively_unbreakable_rowspan {
    return true
  }

  // We can only predict the resolved size of upcoming fixed-size
  // rows, but not fractional rows. In the future, we might be
  // able to simulate and circumvent the problem with fractional
  // rows. Relative rows are currently always measured relative
  // to the first region as well.
  // We can ignore auto rows since this is the last spanned auto
  // row.
  let will_be_covered_height = abs_sum(
    self.grid.rows
    .iter()
    .drop(auto_row_y + 1)
    .take(last_spanned_row - auto_row_y)
    .map(row => {
      match row {
        Rel(v) => v.resolve(self.styles).relative_to(self.regions.base().y)
        _ => @library.Abs::zero()
      }
    }),
  )

  // Remove or reduce the sizes of the rowspan at the current or future
  // regions where it will already be covered by further rows spanned by
  // it.
  subtract_end_sizes(sizes, will_be_covered_height)

  // No need to run a simulation for this rowspan.
  false
}

///|
/// Performs a simulation to predict by how much height the last spanned
/// auto row will have to expand, given the current sizes of the auto row
/// in each region and the pending rowspans' data (parent Y, rowspan amount
/// and vector of requested sizes).
fn GridLayouter::simulate_and_measure_rowspans_in_auto_row(
  self : GridLayouter,
  y : Int,
  resolved : Array[@library.Abs],
  pending_rowspans : Array[(Int, Int, Array[@library.Abs])],
  unbreakable_rows_left : Int,
  row_group_data : UnbreakableRowGroup?,
  disambiguator : Int,
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  let mut disambiguator = disambiguator
  // To begin our simulation, we have to unify the sizes demanded by
  // each rowspan into one simple vector of sizes, as if they were
  // all a single rowspan. These sizes will be appended to
  // 'resolved' once we finish our simulation.
  let simulated_sizes : Array[@library.Abs] = []
  let last_resolved_size = resolved.last()
  let mut max_spanned_row = y
  for pending in pending_rowspans {
    let (parent_y, rowspan, sizes) = pending
    let mut k = 0
    for i in 0..<resolved.length() {
      guard k < sizes.length() else { break }
      // First, we update the already resolved sizes as required
      // by this rowspan. No need to simulate this since the auto row
      // will already expand throughout already resolved regions.
      // Our simulation, therefore, won't otherwise change already
      // resolved sizes, other than, perhaps, the last one (at the
      // last currently resolved region, at which we can expand).
      resolved[i] = resolved[i].max(sizes[k])
      k += 1
    }
    for i in 0..<simulated_sizes.length() {
      guard k < sizes.length() else { break }
      // The remaining sizes are exclusive to rowspans, since
      // other cells in this row didn't require as many regions.
      // We will perform a simulation to see how much of these sizes
      // does the auto row actually need to expand by, and how much
      // is already covered by upcoming rows spanned by the rowspans.
      simulated_sizes[i] = simulated_sizes[i].max(sizes[k])
      k += 1
    }
    for i in k..<sizes.length() {
      simulated_sizes.push(sizes[i])
    }
    max_spanned_row = max_spanned_row.max(parent_y + rowspan - 1)
  }
  if simulated_sizes.is_empty() && resolved.last() == last_resolved_size {
    // The rowspans already fit in the already resolved sizes.
    // No need for simulation.
    return
  }

  // We will be updating the last resolved size (expanding the auto
  // row) as needed. Therefore, consider it as part of the simulation.
  // At the end, we push it back.
  if resolved.pop() is Some(modified_last_resolved_size) {
    simulated_sizes.insert(0, modified_last_resolved_size)
  }

  // Prepare regions for simulation.
  // If we're currently inside an unbreakable row group simulation,
  // subtract the current row group height from the available space
  // when simulating rowspans in said group.
  let mut simulated_regions = self.regions
  simulated_regions = with_height(
    simulated_regions,
    simulated_regions.size.y -
    (match row_group_data {
      Some(row_group) => row_group.height
      None => @library.Abs::zero()
    }),
  )
  for _ in 0..<resolved.length() {
    // Ensure we start at the region where we will expand the auto
    // row.
    // Note that we won't accidentally call '.next()' once more than
    // desired (we won't skip the last resolved frame, where we will
    // expand) because we popped the last resolved size from the
    // resolved vector, above.
    simulated_regions = simulated_regions.next()
    disambiguator += 1

    // Subtract the repeating header and footer height, since that's
    // the height we used when subtracting from the region backlog's
    // heights while measuring cells.
    simulated_regions = with_height(
      simulated_regions,
      simulated_regions.size.y -
      (self.current.repeating_header_height + self.current.footer_height),
    )
  }
  if last_resolved_size is Some(original_last_resolved_size) {
    // We're now at the (current) last region of this auto row.
    // Consider resolved height as already taken space.
    simulated_regions = with_height(
      simulated_regions,
      simulated_regions.size.y - original_last_resolved_size,
    )
  }

  // Now we run the simulation to check how much the auto row needs to
  // grow to ensure that rowspans have the height they need.
  let simulations_stabilized = self.run_rowspan_simulation(
    y, max_spanned_row, simulated_regions, simulated_sizes, engine, last_resolved_size,
    unbreakable_rows_left, disambiguator,
  )
  if !simulations_stabilized {
    // If the simulation didn't stabilize above, we will just pretend
    // all gutters were removed, as a best effort. That means the auto
    // row will expand more than it normally should, but there isn't
    // much we can do.
    let covered = []
    for row_y in (y + 1)..<(max_spanned_row + 1) {
      if row_y >= self.grid.rows.length() {
        break
      }
      if self.grid.is_gutter_track(row_y) {
        continue
      }
      covered.push(
        match self.grid.rows[row_y] {
          Rel(v) => v.resolve(self.styles).relative_to(self.regions.base().y)
          _ => @library.Abs::zero()
        },
      )
    }
    let will_be_covered_height = abs_sum(covered.iter())
    subtract_end_sizes(simulated_sizes, will_be_covered_height)
  }
  resolved.append(simulated_sizes)
}

///|
/// Performs a simulation of laying out multiple rowspans (consolidated
/// into a single vector of simulated sizes) ending in a certain auto row
/// in order to find out how much the auto row will need to expand to cover
/// the rowspans' requested sizes, considering how much size has been
/// covered by other rows and by gutter between rows.
///
/// For example, for a rowspan cell containing a block of 8pt of height
/// spanning rows (1pt, auto, 0.5pt, 0.5pt), with a gutter of 1pt between
/// each row, we have that the rows it spans provide 1pt + 0.5pt + 0.5pt
/// = 2pt of height, plus 1pt + 1pt + 1pt = 3pt of gutter, with a total of
/// 2pt + 3pt = 5pt of height already covered by fixed-size rows and
/// gutters. This means that the auto row must (under normal conditions)
/// expand by 3pt (8pt - 5pt) so that the rowspan has enough height across
/// rows to fully draw its contents.
///
/// However, it's possible that the last row is sent to the next page to
/// respect a pagebreak, and then the 1pt gutter before it disappears. This
/// would lead to our rowspan having a height of 7pt available if we fail
/// to predict this situation when measuring the auto row.
///
/// The algorithm below will, thus, attempt to simulate the layout of each
/// spanned row, considering the space available in the current page and in
/// upcoming pages (through the region backlog), in order to predict which
/// rows will be sent to a new page and thus have their preceding gutter
/// spacing removed (meaning the auto row has to grow a bit more). After
/// simulating, we subtract the total height spanned by upcoming rows and
/// gutter from the total rowspan height - this will be how much our auto
/// row has to expand. We then simulate again to check if, if the auto row
/// expanded by that amount, that would prompt the auto row to need to
/// expand even more, because expanding the auto row might cause some other
/// larger gutter spacing to disappear (leading to the rowspan having less
/// space available instead of more); if so, we update the amount to expand
/// and run the simulation again. Otherwise (if it should expand by the
/// same amount, meaning we predicted correctly, or by less, meaning the
/// auto row will be a bit larger than it should be, but that's a
/// compromise we're willing to accept), we conclude the simulation
/// (consider it stabilized) and return the result.
///
/// Tries up to 5 times. If two consecutive simulations stabilize, then
/// we subtract the predicted expansion height (`amount_to_grow`) from the
/// total height requested by rowspans (the `requested_rowspan_height`) to
/// obtain how much height is covered by upcoming rows, according to our
/// simulation, and the result of that operation is used to reduce or
/// remove heights from the end of the vector of simulated sizes, such that
/// the remaining heights are exactly how much the auto row should expand
/// by. Then, we return `true`.
///
/// If the simulations don't stabilize (they return 5 different and
/// successively larger values), aborts and returns `false`.
fn GridLayouter::run_rowspan_simulation(
  self : GridLayouter,
  y : Int,
  max_spanned_row : Int,
  simulated_regions : @library.Regions,
  simulated_sizes : Array[@library.Abs],
  engine : @library.Engine,
  last_resolved_size : @library.Abs?,
  unbreakable_rows_left : Int,
  disambiguator : Int,
) -> Bool raise @library.SourceError {
  let mut simulated_regions = simulated_regions
  let mut disambiguator = disambiguator
  // The max amount this row can expand will be the total size requested
  // by rowspans which was not yet resolved. It is worth noting that,
  // earlier, we pushed the last resolved size to 'simulated_sizes' as
  // row expansion starts with it, so it's possible a rowspan requested
  // to extend that size (we will see, through the simulation, if that's
  // needed); however, we must subtract that resolved size from the total
  // sum of sizes, as it was already resolved and thus the auto row will
  // already grow by at least that much in the last resolved region (we
  // would grow by the same size twice otherwise).
  let requested_rowspan_height = abs_sum(simulated_sizes.iter()) -
    last_resolved_size.unwrap_or(@library.Abs::zero())

  // The amount the row will effectively grow by, according to the latest
  // simulation.
  let mut amount_to_grow = @library.Abs::zero()

  // Try to simulate up to 5 times. If it doesn't stabilize at a value
  // which, when used and combined with upcoming spanned rows, covers all
  // of the requested rowspan height, we give up.
  for _attempt in 0..<5 {
    let rowspan_simulator = RowspanSimulator::new(
      disambiguator,
      simulated_regions,
      self.current,
    )
    let total_spanned_height = rowspan_simulator.simulate_rowspan_layout(
      y, max_spanned_row, amount_to_grow, requested_rowspan_height, unbreakable_rows_left,
      self, engine,
    )

    // If the total height spanned by upcoming spanned rows plus the
    // current amount we predict the auto row will have to grow (from
    // the previous iteration) are larger than the size requested by
    // rowspans, this means the auto row will grow enough in order to
    // cover the requested rowspan height, so we stop the simulation.
    //
    // If that's not yet the case, we will simulate again and make the
    // auto row grow even more, and do so until either the auto row has
    // grown enough, or we tried to do so over 5 times.
    //
    // A flaw of this approach is that we consider rowspans' content to
    // be contiguous. That is, we treat rowspans' requested heights as
    // a simple number, instead of properly using the vector of
    // requested heights in each region. This can lead to some
    // weirdness when using multi-page rowspans with content that
    // reacts to the amount of space available, including paragraphs.
    // However, this is probably the best we can do for now.
    if (total_spanned_height + amount_to_grow).fits(requested_rowspan_height) {
      // Reduce sizes by the amount to be covered by upcoming spanned
      // rows, which is equivalent to the amount that we don't grow.
      // We reduce from the end as that's where the spanned rows will
      // cover. The remaining sizes will all be covered by the auto
      // row instead (which will grow by those sizes).
      subtract_end_sizes(
        simulated_sizes,
        requested_rowspan_height - amount_to_grow,
      )
      if last_resolved_size is Some(last_resolved_size) {
        // Ensure the first simulated size is at least as large as
        // the last resolved size (its initial value). As it was
        // already resolved before, we must not reduce below the
        // resolved size to avoid problems with non-rowspan cells.
        if simulated_sizes.get(0) is Some(first_simulated_size) {
          simulated_sizes[0] = first_simulated_size.max(last_resolved_size)
        } else {
          simulated_sizes.push(last_resolved_size)
        }
      }
      return true
    }

    // For the next simulation, we will test if the auto row can grow
    // by precisely how much rowspan height is not covered by upcoming
    // spanned rows, according to the current simulation.
    // We know that the new amount to grow is larger (and thus the
    // auto row only expands between each simulation), because we
    // checked above if
    // 'total_spanned_height + (now old_)amount_to_grow >= requested_rowspan_height',
    // which was false, so it holds that
    // 'total_spanned_height + old_amount_to_grow < requested_rowspan_height'
    // Thus,
    // 'old_amount_to_grow < requested_rowspan_height - total_spanned_height'
    // Therefore, by definition, 'old_amount_to_grow < amount_to_grow'.
    let old_amount_to_grow = amount_to_grow
    amount_to_grow = requested_rowspan_height - total_spanned_height

    // We advance the 'regions' variable accordingly, so that, in the
    // next simulation, we consider already grown space as final.
    // That is, we effectively simulate how rows would be placed if the
    // auto row grew by precisely the new value of 'amount_to_grow'.
    let mut extra_amount_to_grow = amount_to_grow - old_amount_to_grow
    while extra_amount_to_grow > @library.Abs::zero() &&
          simulated_regions.size.y < extra_amount_to_grow {
      extra_amount_to_grow = extra_amount_to_grow -
        simulated_regions.size.y.max(@library.Abs::zero())
      simulated_regions = simulated_regions.next()
      simulated_regions = with_height(
        simulated_regions,
        simulated_regions.size.y -
        (self.current.repeating_header_height + self.current.footer_height),
      )
      disambiguator += 1
    }
    simulated_regions = with_height(
      simulated_regions,
      simulated_regions.size.y - extra_amount_to_grow,
    )
  }

  // Simulation didn't succeed in 5 attempts.
  false
}

///|
/// Auxiliary structure holding state during rowspan simulation.
priv struct RowspanSimulator {
  /// The number of finished regions.
  mut finished : Int
  /// The state of regions during the simulation.
  mut regions : @library.Regions
  /// The total height of headers in the currently simulated region.
  mut header_height : @library.Abs
  /// The total height of footers in the currently simulated region.
  mut footer_height : @library.Abs
  /// Whether `self.regions.may_progress()` was `true` at the top of the
  /// region, indicating we can progress anywhere in the current region,
  /// even right after a repeated header.
  mut could_progress_at_top : Bool
  /// Available height after laying out repeated headers at the top of the
  /// currently simulated region.
  mut initial_after_repeats : @library.Abs
  /// The total spanned height so far in the simulation.
  mut total_spanned_height : @library.Abs
  /// Height of the latest spanned gutter row in the simulation.
  /// Zero if it was removed.
  mut latest_spanned_gutter_height : @library.Abs
}

///|
/// Creates new rowspan simulation state with the given regions and initial
/// header and footer heights. Other fields should always start as zero.
fn RowspanSimulator::new(
  finished : Int,
  regions : @library.Regions,
  current : Current,
) -> RowspanSimulator {
  {
    finished,
    regions,
    // There can be no new headers or footers within a multi-page
    // rowspan, since headers and footers are unbreakable, so
    // assuming the repeating header height and footer height
    // won't change is safe.
    header_height: current.repeating_header_height,
    footer_height: current.footer_height,
    could_progress_at_top: current.could_progress_at_top,
    initial_after_repeats: current.initial_after_repeats,
    total_spanned_height: @library.Abs::zero(),
    latest_spanned_gutter_height: @library.Abs::zero(),
  }
}

///|
/// Calculates the total spanned height of the rowspan.
/// Stops calculating if, at any point in the simulation, the value of
/// `total_spanned_height + amount_to_grow` becomes larger than
/// `requested_rowspan_height`, as the results are not going to become any
/// more useful after that point.
fn RowspanSimulator::simulate_rowspan_layout(
  self : RowspanSimulator,
  y : Int,
  max_spanned_row : Int,
  amount_to_grow : @library.Abs,
  requested_rowspan_height : @library.Abs,
  unbreakable_rows_left : Int,
  layouter : GridLayouter,
  engine : @library.Engine,
) -> @library.Abs raise @library.SourceError {
  let mut unbreakable_rows_left = unbreakable_rows_left
  for spanned_y in (y + 1)..<(max_spanned_row + 1) {
    let row = layouter.grid.rows[spanned_y]
    if (self.total_spanned_height + amount_to_grow).fits(
        requested_rowspan_height,
      ) {
      // Stop the simulation, as the combination of upcoming
      // spanned rows (so far) and the current amount the auto
      // row expands by has already fully covered the height the
      // rowspans need.
      return self.total_spanned_height
    }
    let is_gutter = layouter.grid.is_gutter_track(spanned_y)
    if unbreakable_rows_left == 0 {
      // Simulate unbreakable row groups, and skip regions until
      // they fit. There is no risk of infinite recursion, as
      // no auto rows participate in the simulation, so the
      // unbreakable row group simulator won't recursively call
      // 'measure_auto_row' or (consequently) this function.
      let row_group = layouter.simulate_unbreakable_row_group(
        spanned_y,
        None,
        self.regions,
        engine,
        0,
      )
      while !self.regions.size.y.fits(row_group.height) &&
            self.may_progress_with_repeats() {
        self.finish_region(layouter, engine)
      }
      unbreakable_rows_left = row_group.rows.length()
    }
    match row {
      // Fixed-size spanned rows are what we are interested in.
      // They contribute a fixed amount of height to our rowspan.
      Rel(v) => {
        let height = v
          .resolve(layouter.styles)
          .relative_to(self.regions.base().y)
        self.total_spanned_height = self.total_spanned_height + height
        if is_gutter {
          self.latest_spanned_gutter_height = height
        }
        let mut skipped_region = false
        while unbreakable_rows_left == 0 &&
              !self.regions.size.y.fits(height) &&
              self.may_progress_with_repeats() {
          self.finish_region(layouter, engine)
          skipped_region = true
        }
        if !skipped_region || !is_gutter {
          // No gutter at the top of a new region, so don't
          // account for it if we just skipped a region.
          self.regions = with_height(self.regions, self.regions.size.y - height)
        }
      }
      Auto =>
        // We only simulate for rowspans which end at the
        // current auto row. Therefore, there won't be any
        // further auto rows.
        abort("unreachable")
      // For now, we ignore fractional rows on simulation.
      Fr(_) =>
        if is_gutter {
          self.latest_spanned_gutter_height = @library.Abs::zero()
        }
    }
    unbreakable_rows_left = saturating_sub(unbreakable_rows_left, 1)
  }
  self.total_spanned_height
}

///|
fn RowspanSimulator::simulate_header_footer_layout(
  self : RowspanSimulator,
  layouter : GridLayouter,
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  // We can't just use the initial header/footer height on each region,
  // because header/footer height might vary depending on region size if
  // it contains rows with relative lengths. Therefore, we re-simulate
  // headers and footers on each new region.
  // It's true that, when measuring cells, we reduce each height in the
  // backlog to consider the initial header and footer heights; however,
  // our simulation checks what happens AFTER the auto row, so we can
  // just use the original backlog from `self.regions`.
  let disambiguator = self.finished
  let (repeating_headers, header_height) = if !layouter.repeating_headers.is_empty() ||
    !layouter.pending_headers.is_empty() {
    // Only repeating headers have survived after the first region
    // break.
    let repeating_headers = layouter.repeating_headers.copy()
    for header in layouter.pending_headers {
      if header.as_repeated() is Some(header) {
        repeating_headers.push(header)
      }
    }
    let header_height = layouter.simulate_header_height(
      repeating_headers,
      self.regions,
      engine,
      disambiguator,
    )
    (Some(repeating_headers), header_height)
  } else {
    (None, @library.Abs::zero())
  }
  let footer_height = if layouter.grid.footer is Some(footer) &&
    footer.as_repeated() is Some(footer) {
    layouter.simulate_footer(footer, self.regions, engine, disambiguator).height
  } else {
    @library.Abs::zero()
  }
  let mut skipped_region = false

  // Skip until we reach a fitting region for both header and footer.
  while !self.regions.size.y.fits(header_height + footer_height) &&
        self.regions.may_progress() {
    self.regions = self.regions.next()
    self.finished += 1
    skipped_region = true
  }
  if repeating_headers is Some(repeating_headers) {
    self.header_height = if skipped_region {
      // Simulate headers again, at the new region, as
      // the full region height may change.
      layouter.simulate_header_height(
        repeating_headers,
        self.regions,
        engine,
        disambiguator,
      )
    } else {
      header_height
    }
  }
  if layouter.grid.footer is Some(footer) &&
    footer.as_repeated() is Some(footer) {
    self.footer_height = if skipped_region {
      // Simulate footers again, at the new region, as
      // the full region height may change.
      layouter.simulate_footer(footer, self.regions, engine, disambiguator).height
    } else {
      footer_height
    }
  }

  // Consume the header's and footer's heights from the new region,
  // but don't consider them spanned. The rowspan does not go over the
  // header or footer (as an invariant, any rowspans spanning any header
  // or footer rows are fully contained within that header's or footer's rows).
  self.regions = with_height(
    self.regions,
    self.regions.size.y - (self.header_height + self.footer_height),
  )
  self.initial_after_repeats = self.regions.size.y
}

///|
fn RowspanSimulator::finish_region(
  self : RowspanSimulator,
  layouter : GridLayouter,
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  // If a row was pushed to the next region, the immediately
  // preceding gutter row is removed.
  self.total_spanned_height = self.total_spanned_height -
    self.latest_spanned_gutter_height
  self.latest_spanned_gutter_height = @library.Abs::zero()
  self.regions = self.regions.next()
  self.finished += 1
  self.could_progress_at_top = self.regions.may_progress()
  self.simulate_header_footer_layout(layouter, engine)
}

///|
/// Similar to [GridLayouter::may_progress_with_repeats] but for rowspan
/// simulation.
fn RowspanSimulator::may_progress_with_repeats(self : RowspanSimulator) -> Bool {
  self.could_progress_at_top ||
  (
    self.regions.last is Some(_) &&
    self.regions.size.y != self.initial_after_repeats
  )
}

///|
/// Subtracts some size from the end of a vector of sizes.
/// For example, subtracting 5pt from \[2pt, 1pt, 3pt\] will result in \[1pt\].
fn subtract_end_sizes(
  sizes : Array[@library.Abs],
  subtract : @library.Abs,
) -> Unit {
  let mut subtract = subtract
  while subtract > @library.Abs::zero() &&
        (match sizes.last() {
          Some(size) => size <= subtract
          None => false
        }) {
    subtract = subtract - sizes.pop().unwrap()
  }
  if subtract > @library.Abs::zero() && sizes.last() is Some(last_size) {
    sizes[sizes.length() - 1] = last_size - subtract
  }
}
