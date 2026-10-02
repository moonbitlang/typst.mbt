// Port of `typst-layout/src/pad.rs`.

///|
/// Layout the padded content.
pub fn layout_pad(
  elem : @library.PadElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let padding = @library.Sides::new(
    elem.left(styles).resolve(styles),
    elem.top(styles).resolve(styles),
    elem.right(styles).resolve(styles),
    elem.bottom(styles).resolve(styles),
  )
  let pod = regions.map(size => shrink(size, padding))

  // Layout child into padded regions.
  let fragment = layout_fragment(engine, elem.body(), locator, styles, pod)
  for frame in fragment.iter() {
    grow(frame, padding)
  }
  fragment
}

///|
/// Shrink a region size by an inset relative to the size itself.
pub fn shrink(
  size : @library.Axes[@library.Abs],
  inset : @library.Sides[@library.Rel[@library.Abs]],
) -> @library.Axes[@library.Abs] {
  size.sub_size(inset.sum_by_axis().relative_to(size))
}

///|
/// Shrink the components of possibly multiple `Regions` by an inset relative
/// to the regions themselves. Returns the shrunk `(size, full, backlog,
/// last)`.
pub fn shrink_multiple(
  size : @library.Axes[@library.Abs],
  full : @library.Abs,
  backlog : Array[@library.Abs],
  last : @library.Abs?,
  inset : @library.Sides[@library.Rel[@library.Abs]],
) -> (
  @library.Axes[@library.Abs],
  @library.Abs,
  Array[@library.Abs],
  @library.Abs?,
) {
  let summed = inset.sum_by_axis()
  let size = size.sub_size(summed.relative_to(size))
  let full = full - summed.y.relative_to(full)
  let backlog = backlog.map(item => item - summed.y.relative_to(item))
  let last = last.map(v => v - summed.y.relative_to(v))
  (size, full, backlog, last)
}

///|
/// Grow a frame's size by an inset relative to the grown size.
/// This is the inverse operation to `shrink()`.
///
/// For the horizontal axis the derivation looks as follows.
/// (Vertical axis is analogous.)
///
/// Let w be the grown target width,
///     s be the given width,
///     l be the left inset,
///     r be the right inset,
///     p = l + r.
///
/// We want that: w - l.resolve(w) - r.resolve(w) = s
///
/// Thus: w - l.resolve(w) - r.resolve(w) = s
///   <=> w - p.resolve(w) = s
///   <=> w - p.rel * w - p.abs = s
///   <=> (1 - p.rel) * w = s + p.abs
///   <=> w = (s + p.abs) / (1 - p.rel)
pub fn grow(
  frame : @library.Frame,
  inset : @library.Sides[@library.Rel[@library.Abs]],
) -> Unit {
  // Apply the padding inversely such that the grown size padded
  // yields the frame's size.
  let padded = frame
    .size()
    .zip_map(inset.sum_by_axis(), (s, p) => {
      (s + p.abs).div_by(1.0 - p.rel.get())
    })
  let inset = inset.relative_to(padded)
  let offset = @library.Point::new(inset.left, inset.top)

  // Grow the frame and translate everything in the frame inwards.
  frame.set_size(padded)
  frame.translate(offset)
}
