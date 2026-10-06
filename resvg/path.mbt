// Port of `resvg/src/path.rs`.

///|
/// Upstream `path::render`.
fn render_path(
  path : @usvg.Path,
  blend_mode : @skia.BlendMode,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  if !path.is_visible() {
    return
  }
  if path.paint_order() == FillAndStroke {
    fill_path(path, blend_mode, ctx, transform, pixmap) |> ignore
    stroke_path(path, blend_mode, ctx, transform, pixmap) |> ignore
  } else {
    stroke_path(path, blend_mode, ctx, transform, pixmap) |> ignore
    fill_path(path, blend_mode, ctx, transform, pixmap) |> ignore
  }
}

///|
fn fill_path(
  path : @usvg.Path,
  blend_mode : @skia.BlendMode,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit? {
  guard path.fill() is Some(fill) else { return None }

  // Horizontal and vertical lines cannot be filled. Skip.
  if path.data().bounds().width() == 0.0 || path.data().bounds().height() == 0.0 {
    return None
  }
  let rule : @skia.FillRule = match fill.rule() {
    NonZero => Winding
    EvenOdd => EvenOdd
  }
  let paint = @skia.Paint::default()
  match fill.paint() {
    Color(c) =>
      paint.set_color_rgba8(c.red, c.green, c.blue, fill.opacity().to_u8())
    LinearGradient(lg) => {
      guard convert_linear_gradient(lg, fill.opacity()) is Some(s) else {
        return None
      }
      paint.shader = s
    }
    RadialGradient(rg) => {
      guard convert_radial_gradient(rg, fill.opacity()) is Some(s) else {
        return None
      }
      paint.shader = s
    }
    Pattern(pattern) => {
      guard render_pattern_pixmap(pattern, ctx, transform)
        is Some((patt_pix, patt_ts)) else {
        return None
      }
      paint.shader = @skia.Pattern::new(
        patt_pix,
        Repeat,
        Bicubic,
        fill.opacity().get(),
        patt_ts,
      )
    }
  }
  paint.anti_alias = path.rendering_mode().use_shape_antialiasing()
  paint.blend_mode = blend_mode
  pixmap.fill_path(path.data(), paint, rule, transform, None)
  Some(())
}

///|
fn stroke_path(
  path : @usvg.Path,
  blend_mode : @skia.BlendMode,
  ctx : Context,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit? {
  guard path.stroke() is Some(stroke) else { return None }
  let paint = @skia.Paint::default()
  match stroke.paint() {
    Color(c) =>
      paint.set_color_rgba8(c.red, c.green, c.blue, stroke.opacity().to_u8())
    LinearGradient(lg) => {
      guard convert_linear_gradient(lg, stroke.opacity()) is Some(s) else {
        return None
      }
      paint.shader = s
    }
    RadialGradient(rg) => {
      guard convert_radial_gradient(rg, stroke.opacity()) is Some(s) else {
        return None
      }
      paint.shader = s
    }
    Pattern(pattern) => {
      guard render_pattern_pixmap(pattern, ctx, transform)
        is Some((patt_pix, patt_ts)) else {
        return None
      }
      paint.shader = @skia.Pattern::new(
        patt_pix,
        Repeat,
        Bicubic,
        stroke.opacity().get(),
        patt_ts,
      )
    }
  }
  paint.anti_alias = path.rendering_mode().use_shape_antialiasing()
  paint.blend_mode = blend_mode
  pixmap.stroke_path(path.data(), paint, stroke.to_tiny_skia(), transform, None)
  Some(())
}

///|
fn convert_linear_gradient(
  gradient : @usvg.LinearGradient,
  opacity : @usvg.NormalizedF32,
) -> @skia.Shader? {
  let (mode, points) = convert_base_gradient(
    gradient.spread_method(),
    gradient.stops(),
    opacity,
  )
  @skia.LinearGradient::new(
    @path.Point::from_xy(gradient.x1(), gradient.y1()),
    @path.Point::from_xy(gradient.x2(), gradient.y2()),
    points,
    mode,
    gradient.transform(),
  )
}

///|
fn convert_radial_gradient(
  gradient : @usvg.RadialGradient,
  opacity : @usvg.NormalizedF32,
) -> @skia.Shader? {
  let (mode, points) = convert_base_gradient(
    gradient.spread_method(),
    gradient.stops(),
    opacity,
  )
  @skia.RadialGradient::new(
    @path.Point::from_xy(gradient.fx(), gradient.fy()),
    gradient.fr().get(),
    @path.Point::from_xy(gradient.cx(), gradient.cy()),
    gradient.r().get(),
    points,
    mode,
    gradient.transform(),
  )
}

///|
fn convert_base_gradient(
  spread_method : @usvg.SpreadMethod,
  stops : Array[@usvg.Stop],
  opacity : @usvg.NormalizedF32,
) -> (@skia.SpreadMode, Array[@skia.GradientStop]) {
  let mode : @skia.SpreadMode = match spread_method {
    Pad => Pad
    Reflect => Reflect
    Repeat => Repeat
  }
  let points = Array(capacity=stops.length())
  for stop in stops {
    let alpha = stop.opacity() * opacity
    let color = @skia.Color::from_rgba8(
      stop.color().red,
      stop.color().green,
      stop.color().blue,
      alpha.to_u8(),
    )
    points.push(@skia.GradientStop::new(stop.offset().get(), color))
  }
  (mode, points)
}

///|
fn render_pattern_pixmap(
  pattern : @usvg.Pattern,
  ctx : Context,
  transform : @path.Transform,
) -> (@skia.Pixmap, @path.Transform)? {
  let (sx, sy) = {
    let ts2 = transform.pre_concat(pattern.transform())
    ts2.get_scale()
  }
  let rect = pattern.rect()
  guard @path.IntSize::from_wh(
      f32_to_u32(@skia.roundf(rect.width() * sx)),
      f32_to_u32(@skia.roundf(rect.height() * sy)),
    )
    is Some(img_size) else {
    return None
  }
  guard @skia.Pixmap::new(img_size.width(), img_size.height()) is Some(pixmap) else {
    return None
  }
  let transform = @path.Transform::from_scale(sx, sy)
  render_nodes(pattern.root(), ctx, transform, pixmap)
  let mut ts = @path.Transform::default()
  ts = ts.pre_concat(pattern.transform())
  ts = ts.pre_translate(rect.x(), rect.y())
  ts = ts.pre_scale(1.0 / sx, 1.0 / sy)
  Some((pixmap, ts))
}
