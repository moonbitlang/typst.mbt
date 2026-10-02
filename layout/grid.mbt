// Port of `typst-layout/src/grid/mod.rs`.
//
// The grid layouter is split like upstream: `grid_layouter.mbt`
// (`layouter.rs`), `grid_lines.mbt` (`lines.rs`), `grid_repeated.mbt`
// (`repeated.rs`) and `grid_rowspans.mbt` (`rowspans.rs`).

///|
/// Layout the cell into the given regions.
///
/// The `disambiguator` indicates which instance of this cell this should be
/// layouted as. For normal cells, it is always `0`, but for headers and
/// footers, it indicates the index of the header/footer among all. See the
/// [Locator] docs for more details on the concepts behind this.
pub fn layout_cell(
  cell : @library.Cell,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
  is_repeated : Bool,
) -> @library.Fragment raise @library.SourceError {
  // HACK: manually generate tags for table and grid cells. Ideally table and
  // grid cells could just be marked as locatable, but the tags are somehow
  // considered significant for layouting. This hack together with a check in
  // the grid layouter makes the test suite pass.
  let locator = locator.split()
  let mut tags = None
  if @library.TableCell::of(cell.body) is Some(table_cell) {
    let table_cell = table_cell.with_is_repeated(is_repeated)
    tags = Some(generate_tags(table_cell.pack(), locator, engine))
  } else if @library.GridCell::of(cell.body) is Some(grid_cell) {
    let grid_cell = grid_cell.with_is_repeated(is_repeated)
    tags = Some(generate_tags(grid_cell.pack(), locator, engine))
  }
  let locator = locator.next(cell.body.span())
  let fragment = layout_fragment(engine, cell.body, locator, styles, regions)

  // Manually insert tags.
  let frames = fragment.into_frames()
  if tags is Some((elem, loc, key)) && frames.length() > 0 {
    let flags : @library.TagFlags = { introspectable: true, tagged: true, }
    let first = frames[0]
    if frames.length() == 1 {
      first.prepend(@library.Point::zero(), Tag(Start(elem, flags)))
      first.push(@library.Point::zero(), Tag(End(loc, key, flags)))
    } else {
      // If there is more than one frame, set the logical parent of all
      // frames to the cell, which converts them to group frames. Then
      // prepend the start and end tags containing no content. The first
      // frame is also a logical child to guarantee correct ordering
      // in the introspector, since logical children are currently
      // inserted immediately after the start tag of the parent element
      // preceding any content within the parent element's tags.
      for frame in frames {
        frame.set_parent(@library.FrameParent::new(loc, Yes))
      }
      frames[0].prepend_multiple(
        [
          (@library.Point::zero(), @library.FrameItem::Tag(Start(elem, flags))),
          (
            @library.Point::zero(),
            @library.FrameItem::Tag(End(loc, key, flags)),
          ),
        ].iter(),
      )
    }
  }
  @library.Fragment::frames(frames)
}

///|
fn generate_tags(
  cell : @library.Content,
  locator : @library.SplitLocator,
  engine : @library.Engine,
) -> (@library.Content, @library.Location, @library.U128) {
  let key = @library.hash128(cell)
  let loc = locator.next_location(engine, key, cell.span())
  (cell.located(loc), loc, key)
}

///|
/// Layout the grid.
pub fn layout_grid(
  elem : @library.GridElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let grid = elem.grid().unwrap()
  GridLayouter::new(grid, regions, locator, styles, elem.pack().span()).layout(
    engine,
  )
}

///|
/// Layout the table.
pub fn layout_table(
  elem : @library.TableElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let grid = elem.grid().unwrap()
  GridLayouter::new(grid, regions, locator, styles, elem.pack().span()).layout(
    engine,
  )
}
