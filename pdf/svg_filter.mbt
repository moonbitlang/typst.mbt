// Port of `krilla-svg/src/filter.rs`.

///|
/// Render a filter into a surface by rasterizing it with `resvg` and drawing
/// the image.
///
/// Returns `None` if converting the filter was unsuccessful.
///
/// TODO: there is no resvg port yet, so the rasterization step is a hook
/// that draws nothing (see `svg_rasterize_filter`).
fn svg_filter_render(
  group : @usvg.Group,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit? {
  guard group.layer_bounding_box().transform(group.transform())
    is Some(layer_bbox) else {
    return None
  }
  let raster_scale = {
    // Find out what dimensions the SVG will actually have in user space units
    // inside of the PDF.
    // Note that this is not a 100% accurate, because the `ctm` method of
    // surface will only return the transform in the current content stream,
    // so it's not accurate in case we are currently in a XObject. But it's as
    // good as it gets.
    guard group
      .layer_bounding_box()
      .transform(svg_transform_to_usvg(surface.ctm()))
      .bind(r => r.transform(group.transform()))
      is Some(actual_bbox) else {
      return None
    }
    // Calculate the necessary scale in the x/y direction, and take the
    // maximum of that.
    let scale = {
      let (x_scale, y_scale) = (
        actual_bbox.width() / layer_bbox.width(),
        actual_bbox.height() / layer_bbox.height(),
      )
      f32_max(x_scale, y_scale) * process_context.svg_settings.filter_scale
    }
    let max_scale = {
      // Let's try to avoid generating images that have more than 5000 pixels
      // in either direction.
      let pixel_threshold : Float = 5000.0
      let (x_scale, y_scale) = (
        pixel_threshold / layer_bbox.width(),
        pixel_threshold / layer_bbox.height(),
      )
      // Take the minimum of that.
      f32_min(x_scale, y_scale)
    }

    // Take whichever is smaller.
    f32_min(scale, max_scale)
  }
  guard @tiny_skia_path.Size::from_wh(
      layer_bbox.width() * raster_scale,
      layer_bbox.height() * raster_scale,
    )
    is Some(pixmap_size) else {
    return None
  }
  let width = pixmap_size.width().to_double().round().to_int()
  let height = pixmap_size.height().to_double().round().to_int()
  guard width > 0 && height > 0 else { return None }
  let initial_transform = @tiny_skia_path.Transform::from_scale(
      raster_scale, raster_scale,
    )
    .pre_concat(
      @tiny_skia_path.Transform::from_translate(
        -layer_bbox.x(),
        -layer_bbox.y(),
      ),
    )
    // This one is a hack because resvg::render_node will take the absolute
    // layer bbox into consideration and translate by -layer_bbox.x() and
    // -layer_bbox.y(), but we don't want that, so we inverse it.
    .pre_concat(
      @tiny_skia_path.Transform::from_translate(
        group.abs_layer_bounding_box().x(),
        group.abs_layer_bounding_box().y(),
      ),
    )
  guard svg_rasterize_filter(group, initial_transform, width, height)
    is Some(image) else {
    return None
  }
  guard @export.Size::from_wh(
      layer_bbox.width().to_double(),
      layer_bbox.height().to_double(),
    )
    is Some(size) else {
    return None
  }
  surface.push_transform(
    @export.Transform::from_translate(
      layer_bbox.x().to_double(),
      layer_bbox.y().to_double(),
    ),
  )
  surface.draw_image(image, size)
  surface.pop()
  Some(())
}

///|
/// Rasterize a filtered group into an RGBA image of the given size (krilla:
/// `resvg::render_node` into a `tiny_skia::Pixmap`, demultiplied and passed
/// to `Image::from_rgba8`).
///
/// TODO: needs the resvg port; until then nothing is drawn.
fn svg_rasterize_filter(
  group : @usvg.Group,
  initial_transform : @tiny_skia_path.Transform,
  width : Int,
  height : Int,
) -> @export.Image? {
  ignore(group)
  ignore(initial_transform)
  ignore(width)
  ignore(height)
  None
}

///|
/// Rust's `f32::max` (ignoring NaN operands).
fn f32_max(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// Rust's `f32::min` (ignoring NaN operands).
fn f32_min(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else {
    b
  }
}
