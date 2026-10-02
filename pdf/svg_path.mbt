// Port of `krilla-svg/src/path.rs`.

///|
/// Render a path into a surface.
fn svg_path_render(
  path : @usvg.Path,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit {
  if !path.is_visible() {
    return
  }
  match path.paint_order() {
    FillAndStroke =>
      svg_draw_path(path, path.fill(), path.stroke(), surface, process_context)
    StrokeAndFill => {
      svg_draw_path(path, None, path.stroke(), surface, process_context)
      svg_draw_path(path, path.fill(), None, surface, process_context)
    }
  }
}

///|
/// Render a filled and/or stroked path into a surface.
fn svg_draw_path(
  path : @usvg.Path,
  fill : @usvg.Fill?,
  stroke : @usvg.Stroke?,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit {
  let fill = fill.map(f => {
    svg_convert_fill(
      f,
      surface,
      process_context,
      @tiny_skia_path.Transform::identity(),
    )
  })
  let stroke = stroke.map(s => {
    svg_convert_stroke(
      s,
      surface,
      process_context,
      @tiny_skia_path.Transform::identity(),
    )
  })

  // Otherwise the exporter will fill with black by default.
  if fill is Some(_) || stroke is Some(_) {
    surface.set_fill(fill)
    surface.set_stroke(stroke)
    surface.draw_path(svg_path_to_export(path))
  }
}
