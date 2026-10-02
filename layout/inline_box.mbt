// Port of `typst-layout/src/inline/box.rs`.

///|
/// Lay out a box as part of inline layout.
pub fn layout_box(
  elem : @library.BoxElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
) -> @library.Frame raise @library.SourceError {
  // Fetch sizing properties.
  let width = elem.width(styles)
  let height = elem.height(styles)
  let inset = sides_rel_or_zero(resolve_sides_rel(elem.inset(styles), styles))

  // Build the pod region.
  let pod = unbreakable_pod(
    width,
    sizing_from_smart(height),
    inset,
    styles,
    region,
  )

  // Layout the body.
  let frame = match elem.body(styles) {
    // If we have no body, just create an empty frame. If necessary, its
    // size will be adjusted below.
    None => @library.Frame::hard(@library.Axes::zero_size())

    // If we have a child, layout it into the body. Boxes are boundaries for
    // gradient relativeness, so we set the `FrameKind` to `Hard`.
    Some(body) =>
      layout_frame(engine, body, locator, styles, pod).with_kind(Hard)
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

  // Assign label to the frame.
  if elem.pack().label() is Some(label) {
    frame.label(label)
  }

  // Apply baseline shift. Do this after setting the size and applying the
  // inset, so that a relative shift is resolved relative to the final
  // height.
  let baseline = elem.baseline(styles)
  let align = baseline.at()
  if align is Custom(align) {
    frame.set_baseline(align.position(frame.height()))
  }
  let shift = baseline.shift().resolve(styles).relative_to(frame.height())
  if !shift.is_zero() {
    frame.set_baseline(frame.baseline() - shift)
  }
  frame
}
