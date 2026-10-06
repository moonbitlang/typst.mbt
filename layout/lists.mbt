// Port of `typst-layout/src/lists.rs`.

///|
/// Layout the list.
pub fn layout_list(
  elem : @library.ListElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let indent = elem.indent(styles)
  let body_indent = elem.body_indent(styles)
  let tight = elem.tight(styles)
  let gutter = match elem.spacing(styles) {
    Custom(spacing) => spacing
    Auto =>
      if tight {
        @library.ParElem::leading_in(styles)
      } else {
        @library.ParElem::spacing_in(styles)
      }
  }
  let is_rtl = @library.TextElem::dir_in(styles).resolve(styles) == RTL
  let depth = @library.ListElem::depth_in(styles).0

  // Use the user's preferred vertical alignment. Among other things, it
  // avoids '#set align' interference with the list.
  let marker_align = elem.marker_align(styles)
  let baseline_align = marker_align.y() is None
  let marker = list_marker_resolve(
    elem.marker(styles),
    engine,
    styles,
    depth.to_int(),
  ).aligned(marker_align)
  let items = []
  for item in elem.children() {
    // Text in wide lists shall always turn into paragraphs.
    let mut body = item.body()
    if !tight {
      body = body.add(@library.ParbreakElem::new().pack())
    }
    let body = body.styled(@library.ListElem::set_depth(@library.Depth(1L)))
    let item : ItemContent = {
      marker: @library.pdf_marker_tag(ListItemLabel, marker),
      body: @library.pdf_marker_tag(ListItemBody, body),
    }
    items.push(item)
  }
  let layouter = ListLayouter::new(
    gutter,
    elem.pack().span(),
    indent,
    body_indent,
    baseline_align,
    is_rtl,
    styles,
  )
  layout_items(layouter, items, engine, locator, styles, regions)
}

///|
/// Resolve the marker for the given depth (upstream `ListMarker::resolve`).
fn list_marker_resolve(
  marker : @library.ListMarker,
  engine : @library.Engine,
  styles : @library.StyleChain,
  depth : Int,
) -> @library.Content raise @library.SourceError {
  match marker {
    Content(list) =>
      if list.is_empty() {
        @library.Content::empty()
      } else {
        list[depth % list.length()]
      }
    Func(func) =>
      func
      .call_values(engine, @library.Context::new(styles~), [
        Int(depth.to_int64()),
      ])
      .display()
  }
}

///|
/// Layout the enumeration.
pub fn layout_enum(
  elem : @library.EnumElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let numbering = elem.numbering(styles)
  let reversed = elem.reversed(styles)
  let indent = elem.indent(styles)
  let body_indent = elem.body_indent(styles)
  let tight = elem.tight(styles)
  let gutter = match elem.spacing(styles) {
    Custom(spacing) => spacing
    Auto =>
      if tight {
        @library.ParElem::leading_in(styles)
      } else {
        @library.ParElem::spacing_in(styles)
      }
  }
  let is_rtl = @library.TextElem::dir_in(styles).resolve(styles) == RTL
  let items = []
  let children = elem.children()
  let mut number : Int64 = match elem.start(styles) {
    Custom(start) => start.0
    Auto => if reversed { children.length().to_int64() } else { 1L }
  }
  let parents = @library.EnumElem::parents_in(styles).map(p => p.0)
  let full = elem.full(styles)

  // Horizontally align based on the given respective parameter. Vertically
  // align to the top to avoid inheriting `horizon` or `bottom` alignment
  // from the context and having the number be displaced in relation to the
  // item it refers to.
  let number_align = elem.number_align(styles)
  let baseline_align = number_align.y() is None
  for item in children {
    number = match item.number(styles) {
      Custom(n) => n.0
      Auto => number
    }
    let context = @library.Context::new(styles~)
    let resolved = if full {
      parents.push(number)
      let content = numbering
        .apply(engine, context, item.pack().span(), parents[:])
        .display()
      parents.pop() |> ignore
      content
    } else {
      match numbering {
        Pattern(pattern) =>
          @library.TextElem::packed(
            pattern.apply_kth(
              engine,
              item.pack().span(),
              parents.length(),
              number,
            ),
          )
        Func(_) =>
          numbering
          .apply(engine, context, item.pack().span(), [number])
          .display()
      }
    }

    // Disable overhang as a workaround to end-aligned dots glitching and
    // decreasing spacing between numbers and items.
    let resolved = resolved
      .aligned(number_align)
      .styled(@library.TextElem::set_overhang(false))

    // Text in wide enums shall always turn into paragraphs.
    let mut body = item.body()
    if !tight {
      body = body.add(@library.ParbreakElem::new().pack())
    }
    let body = body.styled(
      @library.EnumElem::set_parents([@library.U64(number)]),
    )
    let item : ItemContent = {
      marker: @library.pdf_marker_tag(ListItemLabel, resolved),
      body: @library.pdf_marker_tag(ListItemBody, body),
    }
    items.push(item)
    number = if reversed {
      if number > 0L {
        number - 1L
      } else {
        0L
      }
    } else if number == @int64.MAX_VALUE {
      number
    } else {
      number + 1L
    }
  }
  let layouter = ListLayouter::new(
    gutter,
    elem.pack().span(),
    indent,
    body_indent,
    baseline_align,
    is_rtl,
    styles,
  )
  layout_items(layouter, items, engine, locator, styles, regions)
}

///|
/// Structure with the content for each list item.
priv struct ItemContent {
  /// The item marker.
  marker : @library.Content
  /// The item body.
  body : @library.Content
}

///|
/// Layout data shared across all list items.
priv struct ListLayouter {
  /// Gutter spacing between items.
  gutter : @library.Length
  /// Span of the list/enum element.
  span : @syntax.Span
  /// List indent from the text start.
  indent : @library.Abs
  /// Indent between the marker and the body.
  body_indent : @library.Abs
  /// Whether baseline alignment should be enabled. When disabled, markers
  /// control their own alignment.
  baseline_align : Bool
  /// Whether RTL was the chosen text direction.
  is_rtl : Bool
  /// Maximum measured width of a marker, so they may align horizontally
  /// relative to each other.
  mut marker_width : @library.Abs
  /// If the list may not expand to fill the whole region (e.g. if `width:
  /// auto` was used), then this holds the measured width of an item body, so
  /// they may align horizontally relative to each other.
  mut body_width : @library.Abs?
}

///|
/// Create a new list layouter with defaults for values that will be
/// calculated later.
fn ListLayouter::new(
  gutter : @library.Length,
  span : @syntax.Span,
  indent : @library.Length,
  body_indent : @library.Length,
  baseline_align : Bool,
  is_rtl : Bool,
  styles : @library.StyleChain,
) -> ListLayouter {
  let indent = indent.resolve(styles)
  let body_indent = body_indent.resolve(styles)
  {
    gutter,
    span,
    indent,
    body_indent,
    baseline_align,
    is_rtl,

    // These will be calculated later.
    marker_width: @library.Abs::zero(),
    body_width: None,
  }
}

///|
/// Layout list items.
///
/// This is done in 4 steps:
///
/// 1. Compute marker widths for horizontal marker alignment;
/// 2. If necessary (when within a `width: auto` block or page), compute body
///    widths as well for horizontal body alignment to work;
/// 3. Generate list item layouters, each of which is responsible for
///    vertical marker alignment (baseline-aligned or not, depending on user
///    settings);
/// 4. Pass each list item to the stack layouter. The stack layouter makes it
///    possible for them to expand to the full available width, allowing for
///    center or right alignment to work within the item body.
fn layout_items(
  layouter : ListLayouter,
  items : Array[ItemContent],
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  // Store locators used during measuring to ensure the same locators will be
  // used later when laying out. This is needed to make introspection work
  // properly.
  let locator = locator.split()
  let locators = items.map(item => {
    let marker_locator = locator.next(item.marker.span())
    let body_locator = locator.next(item.body.span())
    (marker_locator, body_locator)
  })
  layouter.marker_width = measure_markers(
    layouter, items, locators, engine, styles, regions,
  )
  if regions.size.x.to_raw().is_inf() || !regions.expand.x {
    layouter.body_width = Some(
      measure_bodies(layouter, items, locators, engine, styles, regions),
    )
  }
  let cells = []
  for i, item in items {
    let (marker_locator, body_locator) = locators[i]
    cells.push(
      StackLayoutChild::CustomLayouter((engine, styles, regions) => {
        layout_item(
          item, layouter, engine, marker_locator, body_locator, styles, regions,
        )
      }),
    )
  }
  layout_stack_internal(
    cells,
    layouter.span,
    Some(Rel(@library.Rel::from_abs(layouter.gutter))),
    TTB,
    engine,
    // This locator should not be used by cells.
    locator.next(()),
    styles,
    regions,
  )
}

///|
/// Measure marker.
fn measure_markers(
  list : ListLayouter,
  items : Array[ItemContent],
  locators : Array[(@library.Locator, @library.Locator)],
  engine : @library.Engine,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Abs raise @library.SourceError {
  let available_width = regions.size.x - list.indent - list.body_indent

  // Measure markers, so we can align them horizontally relative to the
  // largest width.
  let mut marker_width = @library.Abs::zero()
  for i, item in items {
    let (marker_locator, _) = locators[i]
    let marker = layout_frame(
      engine,
      item.marker,
      marker_locator.relayout(),
      styles,
      @library.LayoutRegion::new(
        @library.Axes::new(available_width, @library.Abs::inf()),
        @library.Axes::splat(false),
      ),
    )
    marker_width = marker_width.max(marker.width())
  }

  // Redistribute width if necessary. It is okay to do this before measuring
  // the body (thus effectively checking for the width in two places) since a
  // non-zero-width body would cause an overlarge marker to surpass page
  // width regardless. That is, this check doesn't affect the semantics of
  // the other check, but it is necessary in case we don't measure the body
  // at all.
  marker_width.min(available_width)
}

///|
/// Infinite space or `width: auto` used. Both would prevent the list from
/// expanding to fit, breaking alignment. Therefore, restrict the list size to
/// the size of the largest item, prompting list items to align between
/// themselves instead of relative to the full page width.
fn measure_bodies(
  list : ListLayouter,
  items : Array[ItemContent],
  locators : Array[(@library.Locator, @library.Locator)],
  engine : @library.Engine,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Abs raise @library.SourceError {
  let available_width = regions.size.x - list.indent - list.body_indent
  let mut measured_body_width = @library.Abs::zero()
  for i, item in items {
    let (_, body_locator) = locators[i]
    let body = layout_frame(
      engine,
      item.body,
      body_locator.relayout(),
      styles,
      @library.LayoutRegion::new(
        @library.Axes::new(available_width, @library.Abs::inf()),
        @library.Axes::splat(false),
      ),
    )
    measured_body_width = measured_body_width.max(body.width())
  }

  // If marker and body together exceed the page width, the marker gets the
  // space it requested and the body the rest. This makes some sense since
  // the marker comes first, is unlikely to be large, and is unlikely to be
  // able to wrap. It also keeps consistency between the case where we
  // measure the body and the case where we don't.
  measured_body_width.min(available_width - list.marker_width)
}

///|
/// Layout the item, with support for vertical marker alignment.
fn layout_item(
  item : ItemContent,
  list : ListLayouter,
  engine : @library.Engine,
  marker_locator : @library.Locator,
  body_locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let layouter = ItemLayouter::new(
    item, list, marker_locator, body_locator, styles, regions,
  )
  let mut marker = layouter.layout_marker(
    @library.LayoutRegion::new(
      @library.Axes::new(list.marker_width, regions.base().y),
      @library.Axes::new(true, false),
    ),
    engine,
  )
  let body = Ref(layouter.layout_body(layouter.body_regions, engine))
  if layouter.list.baseline_align {
    layouter.baseline_align(marker, body, engine)
  } else {
    marker = layouter.vertical_align(marker, body.val, engine)
  }
  layouter.finish(marker, body.val)
}

///|
/// Layout data for a specific item.
///
/// Its methods assume only `layout_marker` and `layout_body` are used to
/// layout the item's contents.
priv struct ItemLayouter {
  /// Item content to layout.
  item : ItemContent
  /// List-wide layout data.
  list : ListLayouter
  /// Locator used to measure and layout the marker (must be the same to
  /// avoid introspection bugs).
  marker_locator : @library.Locator
  /// Locator used to measure and layout the body (must be the same to avoid
  /// introspection bugs).
  body_locator : @library.Locator
  /// Stylechain at this item's location.
  styles : @library.StyleChain
  /// The first body's non-empty frame.
  mut first_frame : Int
  /// The item's regions, but adapted for the body's expected width.
  body_regions : @library.Regions
  /// Total body indent from the left of the region, as well as its offset
  /// from the top of the region.
  ///
  /// Vertical offset is always zero without baseline alignment.
  mut body_offset : @library.Point
  /// Resolved marker indent from the left of the region, as well as its
  /// offset from the top of the region.
  ///
  /// Vertical offset is always zero without baseline alignment.
  mut marker_offset : @library.Point
}

///|
/// Begin item layout by resolving default values of attributes.
fn ItemLayouter::new(
  item : ItemContent,
  list : ListLayouter,
  marker_locator : @library.Locator,
  body_locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> ItemLayouter {
  let total_body_indent = list.indent + list.marker_width + list.body_indent

  // Restrict the body to the available space.
  let body_regions = match list.body_width {
    Some(body_width) =>
      {
        ..regions,
        size: { ..regions.size, x: body_width, },
        expand: { ..regions.expand, x: true, },
      }
    None =>
      {
        ..regions,
        size: { ..regions.size, x: regions.size.x - total_body_indent, },
      }
  }
  {
    item,
    list,
    marker_locator,
    body_locator,
    styles,
    first_frame: 0,
    body_regions,
    body_offset: @library.Point::with_x(total_body_indent),
    marker_offset: @library.Point::with_x(list.indent),
  }
}

///|
/// Layout the list marker with the given region data.
fn ItemLayouter::layout_marker(
  self : ItemLayouter,
  region : @library.LayoutRegion,
  engine : @library.Engine,
) -> @library.Frame raise @library.SourceError {
  layout_frame(
    engine,
    self.item.marker,
    self.marker_locator.relayout(),
    self.styles,
    region,
  )
}

///|
/// Layout the list body with the given region data.
fn ItemLayouter::layout_body(
  self : ItemLayouter,
  regions : @library.Regions,
  engine : @library.Engine,
) -> @library.Fragment raise @library.SourceError {
  let fragment = layout_fragment(
    engine,
    self.item.body,
    self.body_locator.relayout(),
    self.styles,
    regions,
  )

  // Update the first non-empty frame (ignoring a frame with only tags due to
  // a forced region break). If the first frame is not virtually empty, then
  // keep the default of 0.
  if should_skip_first_frame(fragment) {
    self.first_frame = 1
  }
  fragment
}

///|
/// Ensure baselines are aligned by either increasing the marker's offset, if
/// the marker is above the body and should thus be moved down, or by both
/// increasing the body's offset and relayouting it with less space, if the
/// body is above the marker.
fn ItemLayouter::baseline_align(
  self : ItemLayouter,
  marker : @library.Frame,
  body_fragment : Ref[@library.Fragment],
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  // Difference between marker and body baselines, for alignment. A positive
  // 'diff' means that the marker is above and must move down, whereas a
  // negative 'diff' means that the marker is below, so the body must be
  // moved down instead.
  let diff = if marker.has_baseline() &&
    body_fragment.val.as_slice().get(self.first_frame) is Some(first) &&
    first.has_baseline() {
    first.baseline() - marker.baseline()
  } else {
    // One of the frames has no natural baseline, so baseline alignment is
    // disabled.
    @library.Abs::zero()
  }
  if diff.to_raw() >= 0.0 {
    // Marker's baseline is above the body's baseline, so we can align them
    // by moving the baseline downwards, without moving the body.
    self.marker_offset = { ..self.marker_offset, y: diff, }
  } else {
    // Marker's baseline is below the body's baseline, so move the body down
    // to avoid overflowing the marker into something above the list (item).
    //
    // To do this, we layout the body again but with '-diff' less space (that
    // is, '+diff' more space, as it is negative), and then move the result
    // '-diff' units downwards. Of course, this could theoretically generate a
    // new result that is even worse - but there is only so much we can do
    // with a finite number of iterations.
    let regions = {
      ..self.body_regions,
      size: { ..self.body_regions.size, y: self.body_regions.size.y + diff, },
    }
    body_fragment.val = self.layout_body(regions, engine)
    self.body_offset = { ..self.body_offset, y: -diff, }
  }
}

///|
/// Called when explicit marker alignment was specified. Re-layout the marker
/// with the same height as the body's first frame so it may align itself
/// vertically with the body.
fn ItemLayouter::vertical_align(
  self : ItemLayouter,
  marker : @library.Frame,
  body : @library.Fragment,
  engine : @library.Engine,
) -> @library.Frame raise @library.SourceError {
  // 'Measuring' the height of an 'auto row'.
  let height = match body.as_slice().get(self.first_frame) {
    // Don't align if the body is too short.
    Some(body_first) => body_first.height().max(marker.height())
    // Body appears to be fully empty, so the marker should not align.
    None => marker.height()
  }
  let region = @library.LayoutRegion::new(
    @library.Axes::new(self.list.marker_width, height),
    @library.Axes::splat(true),
  )
  self.layout_marker(region, engine)
}

///|
/// Finish list item layout by indenting the body's frames and add the marker
/// to the first non-empty frame.
// Cannot fail; keeps upstream's `SourceResult<Fragment>`
// (typst-layout/src/lists.rs:585).
#warnings("-unused_error_type")
fn ItemLayouter::finish(
  self : ItemLayouter,
  marker : @library.Frame,
  body_fragment : @library.Fragment,
) -> @library.Fragment raise @library.SourceError {
  // Collect the item's frames. Here, we add the marker to the first
  // non-empty frame, and additionally indent the whole body so it appears
  // after the marker.
  let frames = []
  for i, body_frame in body_fragment.into_frames() {
    let width = self.body_offset.x + body_frame.width()
    let mut height = body_frame.height() + self.body_offset.y
    if i == self.first_frame {
      // Also consider the marker height, but only for the frame into which
      // it will be placed.
      height = height.max(marker.height() + self.marker_offset.y)
    }
    let frame = @library.Frame::soft(@library.Axes::new(width, height))
    let mut body_pos = self.body_offset
    if self.list.is_rtl {
      // In RTL, items expand to the left, thus the position must
      // additionally be offset by the full width. However, since the body is
      // always at the end, it will expand to the right in LTR, and therefore
      // to the left in RTL. That is, its leftmost corner must be at the left
      // of the frame, since it now expands to the left.
      //
      // Or, mathematically:
      // body_pos.x = width - (body_frame.width() + body_pos.x)
      //            = self.body_offset.x + body_frame.width() -
      //                  - (body_frame.width() + self.body_offset.x)
      //            = 0.
      body_pos = { ..body_pos, x: @library.Abs::zero(), }
    }

    // Only place the marker on the first non-empty frame.
    if i == self.first_frame {
      let mut marker_pos = self.marker_offset
      if self.list.is_rtl {
        marker_pos = {
          ..marker_pos,
          x: width - (self.list.marker_width + marker_pos.x),
        }
      }
      frame.push_frame(marker_pos, marker.clone())
    }
    frame.push_frame(body_pos, body_frame)
    frames.push(frame)
  }
  @library.Fragment::frames(frames)
}

///|
/// Check whether the first frame is essentially empty (only contains tags).
/// This usually indicates a forced region break, which we should ignore.
fn should_skip_first_frame(fragment : @library.Fragment) -> Bool {
  let frames = fragment.as_slice()
  fragment.len() > 1 &&
  is_empty_frame(frames[0]) &&
  frames[1:].iter().any(f => !is_empty_frame(f))
}

///|
/// Check if a frame is empty (taken from grid layouting).
///
/// HACK: Also consider frames empty if they only contain tags. Table and
/// grid cells need to be locatable for pdf accessibility, but the
/// introspection tags interfere with the layouting.
fn is_empty_frame(frame : @library.Frame) -> Bool {
  frame.items().iter().all(entry => entry.1 is Tag(_))
}
