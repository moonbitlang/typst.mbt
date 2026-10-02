// Port of `typst-layout/src/inline/finalize.rs`.

///|
/// Turns the selected lines into frames.
fn finalize(
  engine : @library.Engine,
  p : Preparation,
  lines : Array[Line],
  region : @library.Axes[@library.Abs],
  expand : Bool,
  locator : @library.SplitLocator,
) -> @library.Fragment raise @library.SourceError {
  // Determine the resulting width: Full width of the region if we should
  // expand or there's fractional spacing, fit-to-width otherwise.
  let width = if !region.x.is_finite() ||
    (!expand && lines.iter().all(line => @library.is_zero(line.fr()))) {
    let mut max : @library.Abs? = None
    for line in lines {
      max = match max {
        None => Some(line.width)
        Some(m) => Some(m.max(line.width))
      }
    }
    region.x.min(p.config.hanging_indent + max.unwrap_or(@library.Abs::zero()))
  } else {
    region.x
  }

  // Stack the lines into one frame per region.
  let frames = []
  for line in lines {
    frames.push(commit(engine, p, line, width, region.y, locator))
  }
  @library.Fragment::frames(frames)
}
