// Port of `typst-layout/src/repeat.rs`.

///|
/// Layout the repeated content.
pub fn layout_repeat(
  elem : @library.RepeatElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let pod = @library.LayoutRegion::new(
    region.size,
    @library.Axes::new(false, false),
  )
  let piece = layout_frame(engine, elem.body(), locator, styles, pod)
  let size = @library.Axes::new(region.size.x, piece.height())
  if !size.is_finite_size() {
    @library.bail_at(elem.pack().span(), "repeat with no size restrictions")
  }
  let frame = @library.Frame::soft(size)
  if piece.has_baseline() {
    frame.set_baseline(piece.baseline())
  }
  let mut gap = elem.gap(styles).resolve(styles)
  let fill = region.size.x
  let width = piece.width()

  // We need to fit the body N times, but the number of gaps is (N - 1):
  // N * w + (N - 1) * g ≤ F
  // where N - body count (count)
  //       w - body width (width)
  //       g - gap width (gap)
  //       F - available space to fill (fill)
  //
  // N * w + N * g - g ≤ F
  // N * (w + g) ≤ F + g
  // N ≤ (F + g) / (w + g)
  // N = ⌊(F + g) / (w + g)⌋
  let count = (fill + gap).ratio_to(width + gap).floor()
  let remaining = (fill + gap) % (width + gap)
  let justify = elem.justify(styles)
  if justify {
    gap = gap + remaining.div_by(count - 1.0)
  }
  let align = @library.AlignElem::alignment_in(styles).resolve(styles)
  let mut offset = @library.Abs::zero()
  if count == 1.0 || !justify {
    offset = offset + align.x.position(remaining)
  }
  if width.to_raw() > 0.0 {
    // `count as usize` saturates (and maps NaN to zero).
    let n = if count.is_nan() || count <= 0.0 {
      0
    } else if count >= 1000.0 {
      1000
    } else {
      count.to_int()
    }
    for _ in 0..<n {
      frame.push_frame(@library.Point::with_x(offset), piece.clone())
      offset = offset + (width + gap)
    }
  }
  frame
}
