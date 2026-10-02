// Port of `krilla-svg/src/util.rs` (krilla-svg 0.8.1): conversions from usvg
// types to the exporter's types.

///|
/// Convert a usvg `SpreadMethod` into an exporter `SpreadMethod`.
fn svg_convert_spread_method(
  spread_method : @usvg.SpreadMethod,
) -> @export.SpreadMethod {
  match spread_method {
    Pad => Pad
    Reflect => Reflect
    Repeat => Repeat
  }
}

///|
/// Convert a usvg `Stop` into an exporter `Stop`.
fn svg_convert_stop(stop : @usvg.Stop) -> @export.Stop {
  let color = stop.color()
  {
    offset: stop.offset().get().to_double(),
    color: Regular(Rgb(color.red, color.green, color.blue)),
    opacity: stop.opacity().get().to_double(),
  }
}

///|
/// Convert a usvg `Paint` into an exporter `Paint`.
///
/// The additional transform is needed because in krilla, a transform to a
/// shape will also apply the transform to the paint server. However, in the
/// case of SVG glyphs, we don't want the transform to be shifted for each
/// glyph we draw (since we draw them separately instead of in a glyph run),
/// so we need to apply an additional inverse transform to counter that
/// effect.
fn svg_convert_paint(
  paint : @usvg.Paint,
  surface : @export.Surface,
  process_context : SvgProcessContext,
  additional_transform : @tiny_skia_path.Transform,
) -> @export.Paint {
  match paint {
    Color(c) =>
      if c.red == c.green && c.green == c.blue {
        // Use gray-scale color if possible.
        Color(Regular(Luma(c.red)))
      } else {
        Color(Regular(Rgb(c.red, c.green, c.blue)))
      }
    LinearGradient(lg) =>
      LinearGradient({
        x1: lg.x1().to_double(),
        y1: lg.y1().to_double(),
        x2: lg.x2().to_double(),
        y2: lg.y2().to_double(),
        transform: svg_transform_to_export(
          additional_transform.pre_concat(lg.transform()),
        ),
        spread_method: svg_convert_spread_method(lg.spread_method()),
        stops: lg.stops().map(svg_convert_stop),
        anti_alias: false,
      })
    RadialGradient(rg) =>
      RadialGradient({
        cx: rg.cx().to_double(),
        cy: rg.cy().to_double(),
        cr: rg.r().get().to_double(),
        fx: rg.fx().to_double(),
        fy: rg.fy().to_double(),
        fr: 0.0,
        transform: svg_transform_to_export(
          additional_transform.pre_concat(rg.transform()),
        ),
        spread_method: svg_convert_spread_method(rg.spread_method()),
        stops: rg.stops().map(svg_convert_stop),
        anti_alias: false,
      })
    Pattern(pat) => {
      // krilla: `stream_builder.surface()` ... `stream_builder.finish()`.
      let sub_surface = surface.stream_surface()
      svg_group_render(pat.root(), sub_surface, process_context)
      let stream = sub_surface.finish_stream()
      let rect = pat.rect()
      Pattern({
        stream,
        transform: svg_transform_to_export(
          additional_transform
          .pre_concat(pat.transform())
          .pre_concat(
            @tiny_skia_path.Transform::from_translate(rect.x(), rect.y()),
          ),
        ),
        width: rect.width().to_double(),
        height: rect.height().to_double(),
      })
    }
  }
}

///|
/// Convert a usvg `LineCap` into an exporter `LineCap`.
fn svg_convert_line_cap(line_cap : @usvg.LineCap) -> @export.LineCap {
  match line_cap {
    Butt => Butt
    Round => Round
    Square => Square
  }
}

///|
/// Convert a usvg `LineJoin` into an exporter `LineJoin`.
fn svg_convert_line_join(line_join : @usvg.LineJoin) -> @export.LineJoin {
  match line_join {
    Miter => Miter
    MiterClip => Miter
    Round => Round
    Bevel => Bevel
  }
}

///|
/// Convert a usvg `FillRule` into an exporter `FillRule`.
fn svg_convert_fill_rule(fill_rule : @usvg.FillRule) -> @export.FillRule {
  match fill_rule {
    NonZero => NonZero
    EvenOdd => EvenOdd
  }
}

///|
/// Convert a usvg `Fill` into an exporter `Fill`.
fn svg_convert_fill(
  fill : @usvg.Fill,
  surface : @export.Surface,
  process_context : SvgProcessContext,
  additional_transform : @tiny_skia_path.Transform,
) -> @export.Fill {
  {
    paint: svg_convert_paint(
      fill.paint(),
      surface,
      process_context,
      additional_transform,
    ),
    opacity: fill.opacity().get().to_double(),
    rule: svg_convert_fill_rule(fill.rule()),
  }
}

///|
/// Convert a usvg `Stroke` into an exporter `Stroke`.
fn svg_convert_stroke(
  stroke : @usvg.Stroke,
  surface : @export.Surface,
  process_context : SvgProcessContext,
  additional_transform : @tiny_skia_path.Transform,
) -> @export.Stroke {
  let dash : @export.StrokeDash? = match stroke.dasharray() {
    Some(dash_array) =>
      Some({
        offset: stroke.dashoffset().to_double(),
        array: dash_array.map(v => v.to_double()),
      })
    None => None
  }
  {
    paint: svg_convert_paint(
      stroke.paint(),
      surface,
      process_context,
      additional_transform,
    ),
    width: stroke.width().get().to_double(),
    miter_limit: stroke.miterlimit().get().to_double(),
    line_cap: svg_convert_line_cap(stroke.linecap()),
    line_join: svg_convert_line_join(stroke.linejoin()),
    opacity: stroke.opacity().get().to_double(),
    dash,
  }
}

///|
/// Convert a usvg `BlendMode` into an exporter blend mode (a PDF blend mode
/// name).
fn svg_convert_blend_mode(blend_mode : @usvg.BlendMode) -> String {
  match blend_mode {
    Normal => "Normal"
    Multiply => "Multiply"
    Screen => "Screen"
    Overlay => "Overlay"
    Darken => "Darken"
    Lighten => "Lighten"
    ColorDodge => "ColorDodge"
    ColorBurn => "ColorBurn"
    HardLight => "HardLight"
    SoftLight => "SoftLight"
    Difference => "Difference"
    Exclusion => "Exclusion"
    Hue => "Hue"
    Saturation => "Saturation"
    Color => "Color"
    Luminosity => "Luminosity"
  }
}

///|
/// Convert a usvg `MaskType` into the exporter's mask type (whether the mask
/// is a luminosity mask; otherwise it is an alpha mask).
fn svg_convert_mask_type(mask_type : @usvg.MaskType) -> Bool {
  match mask_type {
    Luminance => true
    Alpha => false
  }
}

///|
/// krilla-svg `RectExt::to_clip_path`.
fn svg_rect_to_clip_path(rect : @export.Rect) -> @export.Path {
  let path_builder = @export.PathBuilder::new()
  path_builder.move_to(rect.left, rect.top)
  path_builder.line_to(rect.right, rect.top)
  path_builder.line_to(rect.right, rect.bottom)
  path_builder.line_to(rect.left, rect.bottom)
  path_builder.close()
  path_builder.finish().unwrap()
}

///|
/// krilla-svg `KrillaTransformExt::to_usvg`.
fn svg_transform_to_usvg(
  transform : @export.Transform,
) -> @tiny_skia_path.Transform {
  @tiny_skia_path.Transform::from_row(
    Float::from_double(transform.sx),
    Float::from_double(transform.ky),
    Float::from_double(transform.kx),
    Float::from_double(transform.sy),
    Float::from_double(transform.tx),
    Float::from_double(transform.ty),
  )
}

///|
/// krilla-svg `UsvgTransformExt::to_krilla`.
fn svg_transform_to_export(
  transform : @tiny_skia_path.Transform,
) -> @export.Transform {
  @export.Transform::from_row(
    transform.sx.to_double(),
    transform.ky.to_double(),
    transform.kx.to_double(),
    transform.sy.to_double(),
    transform.tx.to_double(),
    transform.ty.to_double(),
  )
}

///|
/// krilla-svg `PathExt::to_krilla`.
fn svg_path_to_export(path : @usvg.Path) -> @export.Path {
  let pb = @export.PathBuilder::new()
  for seg in path.data().segments().iter() {
    match seg {
      MoveTo(p) => pb.move_to(p.x.to_double(), p.y.to_double())
      LineTo(p) => pb.line_to(p.x.to_double(), p.y.to_double())
      QuadTo(p1, p2) =>
        pb.quad_to(
          p1.x.to_double(),
          p1.y.to_double(),
          p2.x.to_double(),
          p2.y.to_double(),
        )
      CubicTo(p1, p2, p3) =>
        pb.cubic_to(
          p1.x.to_double(),
          p1.y.to_double(),
          p2.x.to_double(),
          p2.y.to_double(),
          p3.x.to_double(),
          p3.y.to_double(),
        )
      Close => pb.close()
    }
  }
  pb.finish().unwrap()
}
