// Port of `typst-layout/src/pages/finalize.rs`.

///|
/// Piece together the inner page frame and the marginals. We can only do
/// this at the very end because inside/outside margins require knowledge of
/// the physical page number, which is unknown during parallel layout.
fn finalize_page(
  engine : @library.Engine,
  counter : @library.ManualPageCounter,
  tags : Array[@library.Tag],
  layouted : LayoutedPage,
) -> Page raise @library.SourceError {
  let {
    inner,
    margin,
    margin_two_sided,
    bleed,
    bleed_two_sided,
    binding,
    header,
    footer,
    background,
    foreground,
    fill,
    numbering,
    supplement,
  } = layouted
  let mut margin = margin
  let mut bleed = bleed

  // If two sided, left becomes inside and right becomes outside. Thus, for
  // left-bound pages, we want to swap on even pages and for right-bound
  // pages, we want to swap on odd pages.
  let swap = binding.swap(counter.physical())
  if margin_two_sided && swap {
    margin = { ..margin, left: margin.right, right: margin.left, }
  }
  if bleed_two_sided && swap {
    bleed = { ..bleed, left: bleed.right, right: bleed.left, }
  }

  // Create a frame for the full page.
  let frame = @library.Frame::hard(inner.size().add_size(margin.sum_by_axis()))

  // Add tags.
  for tag in tags {
    frame.push(@library.Point::zero(), Tag(tag))
  }
  tags.clear()
  let bleed_origin = @library.Point::new(-bleed.left, -bleed.top)

  // Add the "before" marginals. The order in which we push things here is
  // important as it affects the relative ordering of introspectable elements
  // and thus how counters resolve.
  if background is Some(background) {
    frame.push_frame(bleed_origin, background)
  }
  if header is Some(header) {
    frame.push_frame(@library.Point::with_x(margin.left), header)
  }

  // Add the inner contents.
  frame.push_frame(@library.Point::new(margin.left, margin.top), inner)

  // Add the "after" marginals.
  if footer is Some(footer) {
    let y = frame.height() - footer.height()
    frame.push_frame(@library.Point::new(margin.left, y), footer)
  }
  if foreground is Some(foreground) {
    frame.push_frame(bleed_origin, foreground)
  }

  // Apply counter updates from within the page to the manual page counter.
  counter.visit(engine, frame)

  // Get this page's number and then bump the counter for the next page.
  let number = counter.logical()
  counter.step()
  {
    frame,
    bleed,
    fill,
    numbering,
    supplement,
    number: number.reinterpret_as_uint64(),
  }
}
