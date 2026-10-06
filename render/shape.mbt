// Port of `typst-render/src/shape.rs`.

///|
/// Render a geometrical shape into the canvas.
fn render_shape(
  canvas : @skia.Pixmap,
  state : State,
  shape : @library.Shape,
) -> Unit raise RenderPanic {
  let ts = state.transform
  let path = match shape.geometry {
    Line(target) => {
      let builder = @path.PathBuilder::new()
      builder.line_to(to_f32(target.x), to_f32(target.y))
      builder.finish()
    }
    Rect(size) => {
      let w = to_f32(size.x)
      let h = to_f32(size.y)
      if w < 0.0 || h < 0.0 {
        // Skia doesn't normally allow for negative dimensions, but
        // Typst supports them, so we apply a transform if needed
        // Because this operation is expensive according to tiny-skia's
        // docs, we prefer to not apply it if not needed
        let transform = @path.Transform::from_scale(
          @skia.signum(w),
          @skia.signum(h),
        )
        @path.Rect::from_xywh(0.0, 0.0, @skia.fabs(w), @skia.fabs(h))
        .bind(rect => rect.transform(transform))
        .map(rect => @path.PathBuilder::from_rect(rect))
      } else {
        @path.Rect::from_xywh(0.0, 0.0, w, h).map(rect => {
          @path.PathBuilder::from_rect(rect)
        })
      }
    }
    Curve(curve) => convert_curve(curve)
  }
  guard path is Some(path) else { return }
  if shape.fill is Some(fill) {
    let paint = to_sk_paint(fill, state, false, Some(shape), false)
    if shape.geometry is Rect(_) {
      paint.anti_alias = false
    }
    let rule : @skia.FillRule = match shape.fill_rule {
      NonZero => Winding
      EvenOdd => EvenOdd
    }
    canvas.fill_path(path, paint, rule, ts, state.mask)
  }
  if shape.stroke is Some(stroke) {
    let width = to_f32(stroke.thickness)

    // Don't draw zero-pt stroke.
    if width > 0.0 {
      let dash = stroke.dash.bind(to_sk_dash_pattern)
      let paint = to_sk_paint(
        stroke.paint,
        state,
        false,
        Some(shape),
        stroke.paint is Gradient(_),
      )
      let sk_stroke : @path.Stroke = {
        width,
        line_cap: to_sk_line_cap(stroke.cap),
        line_join: to_sk_line_join(stroke.join),
        dash,
        miter_limit: Float::from_double(stroke.miter_limit.get()),
      }
      canvas.stroke_path(path, paint, sk_stroke, ts, state.mask)
    }
  }
}

///|
/// Convert a Typst curve into a tiny-skia path.
fn convert_curve(curve : @library.Curve) -> @path.Path? {
  let builder = @path.PathBuilder::new()
  for elem in curve.0 {
    match elem {
      Move(p) => builder.move_to(to_f32(p.x), to_f32(p.y))
      Line(p) => builder.line_to(to_f32(p.x), to_f32(p.y))
      Cubic(p1, p2, p3) =>
        builder.cubic_to(
          to_f32(p1.x),
          to_f32(p1.y),
          to_f32(p2.x),
          to_f32(p2.y),
          to_f32(p3.x),
          to_f32(p3.y),
        )
      Close => builder.close()
    }
  }
  builder.finish()
}

///|
fn to_sk_line_cap(cap : @library.LineCap) -> @path.LineCap {
  match cap {
    Butt => Butt
    Round => Round
    Square => Square
  }
}

///|
fn to_sk_line_join(join : @library.LineJoin) -> @path.LineJoin {
  match join {
    Miter => Miter
    Round => Round
    Bevel => Bevel
  }
}

///|
fn to_sk_dash_pattern(dash : @library.FixedDashPattern) -> @path.StrokeDash? {
  // tiny-skia only allows dash patterns with an even number of elements,
  // while pdf allows any number.
  let pattern_len = dash.array.length()
  let len = if pattern_len % 2 == 1 { 2 * pattern_len } else { pattern_len }
  let dash_array = Array::makei(len, i => to_f32(dash.array[i % pattern_len]))
  @path.StrokeDash::new(dash_array, to_f32(dash.phase))
}
