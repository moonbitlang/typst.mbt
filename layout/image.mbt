// Port of `typst-layout/src/image.rs`.

///|
/// Layout the image.
pub fn layout_image(
  elem : @library.ImageElem,
  engine : @library.Engine,
  _locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let image = elem.decode(engine, styles)

  // Determine the image's pixel aspect ratio.
  let pxw = image.width()
  let pxh = image.height()
  let px_ratio = pxw / pxh

  // Determine the region's aspect ratio.
  let region_ratio = region.size.x.ratio_to(region.size.y)

  // Find out whether the image is wider or taller than the region.
  let wide = px_ratio > region_ratio

  // The space into which the image will be placed according to its fit.
  let target = if region.expand.x && region.expand.y {
    // If both width and height are forced, take them.
    region.size
  } else if region.expand.x {
    // If just width is forced, take it.
    @library.Axes::new(
      region.size.x,
      region.size.y.min(region.size.x.div_by(px_ratio)),
    )
  } else if region.expand.y {
    // If just height is forced, take it.
    @library.Axes::new(
      region.size.x.min(region.size.y.times(px_ratio)),
      region.size.y,
    )
  } else {
    // If neither is forced, take the natural image size at the image's DPI
    // bounded by the available space.
    //
    // Division by DPI is fine since it's guaranteed to be positive.
    let dpi = image.dpi().unwrap_or(@library.image_default_dpi)
    let natural = @library.Axes::new(pxw, pxh).map(v => {
      @library.Abs::inches(v / dpi)
    })
    @library.Axes::new(
      natural.x.min(region.size.x).min(region.size.y.times(px_ratio)),
      natural.y.min(region.size.y).min(region.size.x.div_by(px_ratio)),
    )
  }

  // Compute the actual size of the fitted image.
  let fit = elem.fit(styles)
  let fitted = match fit {
    Cover | Contain =>
      if wide == (fit == Contain) {
        @library.Axes::new(target.x, target.x.div_by(px_ratio))
      } else {
        @library.Axes::new(target.y.times(px_ratio), target.y)
      }
    Stretch => target
  }

  // First, place the image in a frame of exactly its size and then resize
  // the frame to the target size, center aligning the image in the process.
  let frame = @library.Frame::soft(fitted)
  frame.push(@library.Point::zero(), Image(image, fitted, elem.pack().span()))
  frame.resize(target, @library.Axes::splat(Center)) |> ignore

  // Create a clipping group if only part of the image should be visible.
  if fit == Cover && !target.fits(fitted) {
    frame.clip(@library.Curve::rect(frame.size()))
  }
  frame
}
