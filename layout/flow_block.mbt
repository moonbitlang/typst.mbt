// Port of `typst-layout/src/flow/block.rs`.

///|
/// Lay this out as an unbreakable block.
pub fn layout_single_block(
  elem : @library.BlockElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  // Fetch sizing properties.
  let width = elem.width(styles)
  let height = elem.height(styles)
  let inset = sides_rel_or_zero(resolve_sides_rel(elem.inset(styles), styles))

  // Build the pod regions.
  let pod = unbreakable_pod(
    sizing_from_smart(width),
    height,
    inset,
    styles,
    region.size,
  )

  // Layout the body.
  let body = elem.body(styles)
  let frame = match body {
    // If we have no body, just create one frame. Its size will be adjusted
    // below.
    None => @library.Frame::hard(@library.Axes::zero_size())

    // If we have content as our body, just layout it.
    Some(Content(body)) =>
      layout_frame(engine, body, locator.relayout(), styles, pod)

    // If we have a child that wants to layout with just access to the base
    // region, give it that.
    Some(SingleLayouter(callback)) =>
      callback.call(engine, locator, styles, pod)

    // If we have a child that wants to layout with full region access, we
    // layout it.
    Some(MultiLayouter(callback)) => {
      let expand = pod.expand
        .bitor(region.expand)
        .bitand(pod.size.map(@library.Abs::is_finite))
      let pod = { ..pod, expand, }
      callback
      .call(engine, locator, styles, @library.Regions::from_region(pod))
      .into_frame()
    }
  }

  // Explicit blocks are boundaries for gradient relativeness.
  if body is (None | Some(Content(_))) {
    frame.set_kind(Hard)
  }

  // Enforce a correct frame size on the expanded axes. Do this before
  // applying the inset, since the pod shrunk.
  frame.set_size(pod.expand.select(pod.size, frame.size()))

  // Apply the inset.
  if !inset.is_zero() {
    grow(frame, inset)
  }

  // Prepare fill and stroke.
  let fill = elem.fill(styles)
  let stroke = sides_fixed_stroke(
    resolve_sides_stroke(elem.stroke(styles), styles),
  )

  // Only fetch these if necessary (for clipping or filling/stroking).
  let outset = () => {
    sides_rel_or_zero(resolve_sides_rel(elem.outset(styles), styles))
  }
  let radius = () => {
    corners_rel_or_zero(resolve_corners_rel(elem.radius(styles), styles))
  }

  // Clip the contents, if requested.
  if elem.clip(styles) {
    frame.clip(clip_rect(frame.size(), radius(), stroke, outset()))
  }

  // Add fill and/or stroke.
  if fill is Some(_) || any_stroke(stroke) {
    fill_and_stroke(frame, fill, stroke, outset(), radius(), elem.pack().span())
  }

  // Assign label to each frame in the fragment.
  if elem.pack().label() is Some(label) {
    frame.label(label)
  }
  frame
}

///|
/// Lay this out as a breakable block.
pub fn layout_multi_block(
  elem : @library.BlockElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  // Fetch sizing properties.
  let width = elem.width(styles)
  let height = elem.height(styles)
  let inset = sides_rel_or_zero(resolve_sides_rel(elem.inset(styles), styles))

  // Build the pod regions.
  let pod = breakable_pod(
    sizing_from_smart(width),
    height,
    inset,
    styles,
    regions,
  )

  // Layout the body.
  let body = elem.body(styles)
  let fragment = match body {
    // If we have no body, just create one frame plus one per backlog region.
    // We create them zero-sized; if necessary, their size will be adjusted
    // below.
    None => {
      let frames = []
      frames.push(@library.Frame::hard(@library.Axes::zero_size()))
      if pod.expand.y {
        let mut iter = pod
        while !iter.backlog.is_empty() {
          frames.push(@library.Frame::hard(@library.Axes::zero_size()))
          iter = iter.next()
        }
      }
      @library.Fragment::frames(frames)
    }

    // If we have content as our body, just layout it.
    Some(Content(body)) => {
      let mut fragment = layout_fragment(
        engine,
        body,
        locator.relayout(),
        styles,
        pod,
      )

      // If the body is automatically sized and produced more than one
      // fragment, ensure that the width was consistent across all regions.
      // If it wasn't, we need to relayout with expansion.
      let frames = fragment.as_slice()
      let mut inconsistent = false
      for i in 1..<frames.length() {
        if !frames[i - 1].width().approx_eq(frames[i].width()) {
          inconsistent = true
          break
        }
      }
      if !pod.expand.x && inconsistent {
        let mut max_width = @library.Abs::zero()
        let mut first = true
        for frame in fragment.iter() {
          // `Iterator::max` (last maximum on ties).
          if first || frame.width().to_raw() >= max_width.to_raw() {
            max_width = frame.width()
          }
          first = false
        }
        let pod = {
          ..pod,
          size: @library.Axes::new(max_width, pod.size.y),
          expand: @library.Axes::new(true, pod.expand.y),
        }
        fragment = layout_fragment(engine, body, locator, styles, pod)
      }
      fragment
    }

    // If we have a child that wants to layout with just access to the base
    // region, give it that.
    Some(SingleLayouter(callback)) => {
      let pod = @library.LayoutRegion::new(pod.base(), pod.expand)
      @library.Fragment::frame(callback.call(engine, locator, styles, pod))
    }

    // If we have a child that wants to layout with full region access, we
    // layout it.
    //
    // For auto-sized multi-layouters, we propagate the outer expansion so
    // that they can decide for themselves. We also ensure again to only
    // expand if the size is finite.
    Some(MultiLayouter(callback)) => {
      let expand = pod.expand
        .bitor(regions.expand)
        .bitand(pod.size.map(@library.Abs::is_finite))
      let pod = { ..pod, expand, }
      callback.call(engine, locator, styles, pod)
    }
  }

  // Prepare fill and stroke.
  let fill = elem.fill(styles)
  let stroke = sides_fixed_stroke(
    resolve_sides_stroke(elem.stroke(styles), styles),
  )

  // Only fetch these if necessary (for clipping or filling/stroking).
  let outset = () => {
    sides_rel_or_zero(resolve_sides_rel(elem.outset(styles), styles))
  }
  let radius = () => {
    corners_rel_or_zero(resolve_corners_rel(elem.radius(styles), styles))
  }

  // Fetch/compute these outside of the loop.
  let clip = elem.clip(styles)
  let has_fill_or_stroke = fill is Some(_) || any_stroke(stroke)
  let has_inset = !inset.is_zero()
  let is_explicit = body is (None | Some(Content(_)))

  // Skip filling, stroking and labeling the first frame if it is empty and
  // a non-empty one follows.
  let mut skip_first = false
  if fragment.as_slice() is [first, .. rest] {
    skip_first = first.is_empty() && rest.iter().any(frame => !frame.is_empty())
  }

  // Post-process to apply insets, clipping, fills, and strokes.
  for i, pair in fragment.iter().zip(pod.iter()).to_array() {
    let (frame, region) = pair

    // Explicit blocks are boundaries for gradient relativeness.
    if is_explicit {
      frame.set_kind(Hard)
    }

    // Enforce a correct frame size on the expanded axes. Do this before
    // applying the inset, since the pod shrunk.
    frame.set_size(pod.expand.select(region, frame.size()))

    // Apply the inset.
    if has_inset {
      grow(frame, inset)
    }

    // Clip the contents, if requested.
    if clip {
      frame.clip(clip_rect(frame.size(), radius(), stroke, outset()))
    }

    // Add fill and/or stroke.
    if has_fill_or_stroke && (i > 0 || !skip_first) {
      fill_and_stroke(
        frame,
        fill,
        stroke,
        outset(),
        radius(),
        elem.pack().span(),
      )
    }
  }

  // Assign label to each frame in the fragment.
  if elem.pack().label() is Some(label) {
    // Skip empty orphan frames, as a label would make them non-empty.
    for i, frame in fragment.as_slice() {
      if i == 0 && skip_first {
        continue
      }
      frame.label(label)
    }
  }
  fragment
}

///|
/// Builds the pod region for an unbreakable sized container.
fn unbreakable_pod(
  width : @library.Sizing,
  height : @library.Sizing,
  inset : @library.Sides[@library.Rel[@library.Abs]],
  styles : @library.StyleChain,
  base : @library.Axes[@library.Abs],
) -> @library.LayoutRegion {
  // Resolve the size.
  let mut size = @library.Axes::new(
    match width {
      // - For auto, the whole region is available.
      // - Fr is handled outside and already factored into the `region`, so
      //   we can treat it equivalently to 100%.
      Auto | Fr(_) => base.x
      // Resolve the relative sizing.
      Rel(rel) => rel.resolve(styles).relative_to(base.x)
    },
    match height {
      Auto | Fr(_) => base.y
      Rel(rel) => rel.resolve(styles).relative_to(base.y)
    },
  )

  // Take the inset, if any, into account.
  if !inset.is_zero() {
    size = shrink(size, inset)
  }

  // If the child is manually, the size is forced and we should enable
  // expansion.
  let expand = @library.Axes::new(
    width != Auto && size.x.is_finite(),
    height != Auto && size.y.is_finite(),
  )
  @library.LayoutRegion::new(size, expand)
}

///|
/// Builds the pod regions for a breakable sized container.
fn breakable_pod(
  width : @library.Sizing,
  height : @library.Sizing,
  inset : @library.Sides[@library.Rel[@library.Abs]],
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Regions {
  let base = regions.base()

  // The vertical region sizes we're about to build. If the block has a fixed
  // height, things are very different, so we handle that case completely
  // separately.
  let (first, full, backlog, last) = match height {
    // If the block is automatically sized, we can just inherit the regions.
    Auto | Fr(_) =>
      (regions.size.y, regions.full, regions.backlog.to_owned(), regions.last)
    Rel(rel) => {
      // Resolve the sizing to a concrete size.
      let resolved = rel.resolve(styles).relative_to(base.y)

      // Since we're manually sized, the resolved size is the base height.
      let full = resolved

      // Distribute the fixed height across a start region and a backlog.
      let (first, backlog) = distribute_height(resolved, regions)

      // If the height is manually sized, we don't want a final repeatable
      // region.
      (first, full, backlog, None)
    }
  }

  // Resolve the horizontal sizing to a concrete width and combine `width`
  // and `first` into `size`.
  let mut size = @library.Axes::new(
    match width {
      Auto | Fr(_) => regions.size.x
      Rel(rel) => rel.resolve(styles).relative_to(base.x)
    },
    first,
  )

  // Take the inset, if any, into account, applying it to the individual
  // region components.
  let mut full = full
  let mut backlog = backlog
  let mut last = last
  if !inset.is_zero() {
    let (s, f, b, l) = shrink_multiple(size, full, backlog, last, inset)
    size = s
    full = f
    backlog = b
    last = l
  }

  // If the child is manually, the size is forced and we should enable
  // expansion.
  let expand = @library.Axes::new(
    width != Auto && size.x.is_finite(),
    height != Auto && size.y.is_finite(),
  )
  { size, full, backlog: backlog[:], last, expand, }
}

///|
/// Distribute a fixed height spread over existing regions into a new first
/// height and a new backlog.
///
/// Note that, if the given height fits within the first region, no backlog
/// is generated and the first region's height shrinks to fit exactly the
/// given height. In particular, negative and zero heights always fit in any
/// region, so such heights are always directly returned as the new first
/// region height.
fn distribute_height(
  height : @library.Abs,
  regions : @library.Regions,
) -> (@library.Abs, Array[@library.Abs]) {
  // Build new region heights from old regions.
  let buf = []
  let mut remaining = height
  let mut regions = regions

  // Negative and zero heights always fit, so just keep them.
  // No backlog is generated.
  if remaining.to_raw() <= 0.0 {
    buf.push(remaining)
    return (buf[0], buf[1:].to_owned())
  }
  while true {
    // This clamp is safe (min <= max), as 'remaining' won't be negative due
    // to the initial check above (on the first iteration) and due to
    // stopping on 'remaining.approx_empty()' below (for the second iteration
    // onwards).
    let limited = regions.size.y.clamp(@library.Abs::zero(), remaining)
    buf.push(limited)
    remaining = remaining - limited
    if remaining.approx_empty() ||
      !regions.may_break() ||
      (!regions.may_progress() && limited.approx_empty()) {
      break
    }
    regions = regions.next()
  }

  // If there is still something remaining, apply it to the last region (it
  // will overflow, but there's nothing else we can do).
  if !remaining.approx_empty() && buf.length() > 0 {
    let last = buf.length() - 1
    buf[last] = buf[last] + remaining
  }

  // Distribute the heights to the first region and the backlog. There is no
  // last region, since the height is fixed.
  (buf[0], buf[1:].to_owned())
}
