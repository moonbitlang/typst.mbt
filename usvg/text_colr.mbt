// Port of `usvg` 0.47.0 `src/text/colr.rs`: a best-effort conversion of
// COLR glyphs into SVG (the same code as Typst's `GlyphPainter` in
// `typst-library/src/text/font/color.rs`, of which `library/font_color.mbt`
// is a port; copied here since usvg cannot depend on `library`). Upstream's
// warnings (`println!`) are dropped.

///|
/// Formats a 2D path for the SVG (upstream `ColrBuilder`).
priv struct ColrBuilder {
  buf : StringBuilder
}

///|
impl @otf.OutlineBuilder for ColrBuilder with fn move_to(self, x, y) {
  self.buf.write_string("M \{rust_display_f32(x)} \{rust_display_f32(y)} ")
}

///|
impl @otf.OutlineBuilder for ColrBuilder with fn line_to(self, x, y) {
  self.buf.write_string("L \{rust_display_f32(x)} \{rust_display_f32(y)} ")
}

///|
impl @otf.OutlineBuilder for ColrBuilder with fn quad_to(self, x1, y1, x, y) {
  self.buf.write_string(
    "Q \{rust_display_f32(x1)} \{rust_display_f32(y1)} \{rust_display_f32(x)} \{rust_display_f32(y)} ",
  )
}

///|
impl @otf.OutlineBuilder for ColrBuilder with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.buf.write_string(
    "C \{rust_display_f32(x1)} \{rust_display_f32(y1)} \{rust_display_f32(x2)} \{rust_display_f32(y2)} \{rust_display_f32(x)} \{rust_display_f32(y)} ",
  )
}

///|
impl @otf.OutlineBuilder for ColrBuilder with fn close(self) {
  self.buf.write_string("Z ")
}

///|
// NOTE: This is only a best-effort translation of COLR into SVG. It's not feature-complete
// and it's also not possible to make it feature-complete using just raw SVG features.
priv struct GlyphPainter {
  face : @otf.Face
  svg : @xmlwriter.XmlWriter
  path_buf : StringBuilder
  mut gradient_index : Int
  mut clip_path_index : Int
  palette_index : UInt16
  mut transform : @otf.Transform
  mut outline_transform : @otf.Transform
  transforms_stack : Array[@otf.Transform]
}

///|
fn GlyphPainter::write_gradient_stops(
  self : GlyphPainter,
  stops : @otf.GradientStopsIter,
) -> Unit {
  while stops.next() is Some(stop) {
    self.svg.start_element("stop")
    self.svg.write_attribute("offset", rust_display_f32(stop.stop_offset))
    self.write_color_attribute("stop-color", stop.color)
    let opacity = Float::from_int(stop.color.alpha.to_int()) / 255.0
    self.svg.write_attribute("stop-opacity", rust_display_f32(opacity))
    self.svg.end_element()
  }
}

///|
fn GlyphPainter::write_color_attribute(
  self : GlyphPainter,
  name : String,
  color : @otf.RgbaColor,
) -> Unit {
  self.svg.write_attribute(
    name,
    "rgb(\{color.red.to_int()}, \{color.green.to_int()}, \{color.blue.to_int()})",
  )
}

///|
fn GlyphPainter::write_transform_attribute(
  self : GlyphPainter,
  name : String,
  ts : @otf.Transform,
) -> Unit {
  if ts.is_default() {
    return
  }
  self.svg.write_attribute(
    name,
    "matrix(\{rust_display_f32(ts.a)} \{rust_display_f32(ts.b)} \{rust_display_f32(ts.c)} \{rust_display_f32(ts.d)} \{rust_display_f32(ts.e)} \{rust_display_f32(ts.f)})",
  )
}

///|
fn GlyphPainter::write_spread_method_attribute(
  self : GlyphPainter,
  extend_ : @otf.GradientExtend,
) -> Unit {
  self.svg.write_attribute(
    "spreadMethod",
    match extend_ {
      Pad => "pad"
      Repeat => "repeat"
      Reflect => "reflect"
    },
  )
}

///|
fn GlyphPainter::paint_solid(
  self : GlyphPainter,
  color : @otf.RgbaColor,
) -> Unit {
  self.svg.start_element("path")
  self.write_color_attribute("fill", color)
  let opacity = Float::from_int(color.alpha.to_int()) / 255.0
  self.svg.write_attribute("fill-opacity", rust_display_f32(opacity))
  self.write_transform_attribute("transform", self.outline_transform)
  self.svg.write_attribute("d", self.path_buf.to_string())
  self.svg.end_element()
}

///|
fn GlyphPainter::paint_linear_gradient(
  self : GlyphPainter,
  gradient : @otf.LinearGradient,
) -> Unit {
  let gradient_id = "lg\{self.gradient_index}"
  self.gradient_index += 1
  let gradient_transform = paint_transform(
    self.outline_transform,
    self.transform,
  )

  // TODO: We ignore x2, y2. Have to apply them somehow.
  // TODO: The way spreadMode works in ttf and svg is a bit different. In SVG, the spreadMode
  // will always be applied based on x1/y1 and x2/y2. However, in TTF the spreadMode will
  // be applied from the first/last stop. So if we have a gradient with x1=0 x2=1, and
  // a stop at x=0.4 and x=0.6, then in SVG we will always see a padding, while in ttf
  // we will see the actual spreadMode. We need to account for that somehow.
  self.svg.start_element("linearGradient")
  self.svg.write_attribute("id", gradient_id)
  self.svg.write_attribute("x1", rust_display_f32(gradient.x0))
  self.svg.write_attribute("y1", rust_display_f32(gradient.y0))
  self.svg.write_attribute("x2", rust_display_f32(gradient.x1))
  self.svg.write_attribute("y2", rust_display_f32(gradient.y1))
  self.svg.write_attribute("gradientUnits", "userSpaceOnUse")
  self.write_spread_method_attribute(gradient.extend_)
  self.write_transform_attribute("gradientTransform", gradient_transform)
  self.write_gradient_stops(
    gradient.stops(self.palette_index, self.face.variation_coordinates()),
  )
  self.svg.end_element()
  self.svg.start_element("path")
  self.svg.write_attribute("fill", "url(#\{gradient_id})")
  self.write_transform_attribute("transform", self.outline_transform)
  self.svg.write_attribute("d", self.path_buf.to_string())
  self.svg.end_element()
}

///|
fn GlyphPainter::paint_radial_gradient(
  self : GlyphPainter,
  gradient : @otf.RadialGradient,
) -> Unit {
  let gradient_id = "rg\{self.gradient_index}"
  self.gradient_index += 1
  let gradient_transform = paint_transform(
    self.outline_transform,
    self.transform,
  )
  self.svg.start_element("radialGradient")
  self.svg.write_attribute("id", gradient_id)
  self.svg.write_attribute("cx", rust_display_f32(gradient.x1))
  self.svg.write_attribute("cy", rust_display_f32(gradient.y1))
  self.svg.write_attribute("r", rust_display_f32(gradient.r1))
  self.svg.write_attribute("fr", rust_display_f32(gradient.r0))
  self.svg.write_attribute("fx", rust_display_f32(gradient.x0))
  self.svg.write_attribute("fy", rust_display_f32(gradient.y0))
  self.svg.write_attribute("gradientUnits", "userSpaceOnUse")
  self.write_spread_method_attribute(gradient.extend_)
  self.write_transform_attribute("gradientTransform", gradient_transform)
  self.write_gradient_stops(
    gradient.stops(self.palette_index, self.face.variation_coordinates()),
  )
  self.svg.end_element()
  self.svg.start_element("path")
  self.svg.write_attribute("fill", "url(#\{gradient_id})")
  self.write_transform_attribute("transform", self.outline_transform)
  self.svg.write_attribute("d", self.path_buf.to_string())
  self.svg.end_element()
}

///|
fn GlyphPainter::paint_sweep_gradient(
  _self : GlyphPainter,
  _ : @otf.SweepGradient,
) -> Unit {
  ()
}

///|
fn paint_transform(
  outline_transform : @otf.Transform,
  transform : @otf.Transform,
) -> @otf.Transform {
  let outline_transform = Transform::from_row(
    outline_transform.a,
    outline_transform.b,
    outline_transform.c,
    outline_transform.d,
    outline_transform.e,
    outline_transform.f,
  )
  let gradient_transform = Transform::from_row(
    transform.a,
    transform.b,
    transform.c,
    transform.d,
    transform.e,
    transform.f,
  )
  let gradient_transform = outline_transform
    .invert()
    // Upstream warns: Failed to calculate transform for gradient in glyph.
    .unwrap_or(Transform::default())
    .pre_concat(gradient_transform)
  {
    a: gradient_transform.sx,
    b: gradient_transform.ky,
    c: gradient_transform.kx,
    d: gradient_transform.sy,
    e: gradient_transform.tx,
    f: gradient_transform.ty,
  }
}

///|
fn GlyphPainter::clip_with_path(self : GlyphPainter, path : String) -> Unit {
  let clip_id = "cp\{self.clip_path_index}"
  self.clip_path_index += 1
  self.svg.start_element("clipPath")
  self.svg.write_attribute("id", clip_id)
  self.svg.start_element("path")
  self.write_transform_attribute("transform", self.outline_transform)
  self.svg.write_attribute("d", path)
  self.svg.end_element()
  self.svg.end_element()
  self.svg.start_element("g")
  self.svg.write_attribute("clip-path", "url(#\{clip_id})")
}

///|
impl @otf.ColrPainter for GlyphPainter with fn outline_glyph(self, glyph_id) {
  self.path_buf.reset()
  let builder : ColrBuilder = { buf: self.path_buf, }
  match self.face.outline_glyph(glyph_id, builder) {
    Some(_) => ()
    None => return
  }
  // `builder.finish()`: remove the trailing space.
  let s = self.path_buf.to_string()
  if s != "" {
    self.path_buf.reset()
    self.path_buf.write_string(s.unsafe_substring(start=0, end=s.length() - 1))
  }

  // We have to write outline using the current transform.
  self.outline_transform = self.transform
}

///|
impl @otf.ColrPainter for GlyphPainter with fn push_layer(self, mode) {
  self.svg.start_element("g")
  // TODO: Need to figure out how to represent the other blend modes
  // in SVG.
  let mode = match mode {
    SourceOver => "normal"
    Screen => "screen"
    Overlay => "overlay"
    Darken => "darken"
    Lighten => "lighten"
    ColorDodge => "color-dodge"
    ColorBurn => "color-burn"
    HardLight => "hard-light"
    SoftLight => "soft-light"
    Difference => "difference"
    Exclusion => "exclusion"
    Multiply => "multiply"
    Hue => "hue"
    Saturation => "saturation"
    Color => "color"
    Luminosity => "luminosity"
    _ => "normal"
  }
  self.svg.write_attribute(
    "style",
    "mix-blend-mode: \{mode}; isolation: isolate",
  )
}

///|
impl @otf.ColrPainter for GlyphPainter with fn pop_layer(self) {
  self.svg.end_element() // g
}

///|
impl @otf.ColrPainter for GlyphPainter with fn push_transform(self, transform) {
  self.transforms_stack.push(self.transform)
  self.transform = @otf.Transform::combine(self.transform, transform)
}

///|
impl @otf.ColrPainter for GlyphPainter with fn paint(self, paint) {
  match paint {
    Solid(color) => self.paint_solid(color)
    LinearGradient(lg) => self.paint_linear_gradient(lg)
    RadialGradient(rg) => self.paint_radial_gradient(rg)
    SweepGradient(sg) => self.paint_sweep_gradient(sg)
  }
}

///|
impl @otf.ColrPainter for GlyphPainter with fn pop_transform(self) {
  if self.transforms_stack.pop() is Some(ts) {
    self.transform = ts
  }
}

///|
impl @otf.ColrPainter for GlyphPainter with fn push_clip(self) {
  self.clip_with_path(self.path_buf.to_string())
}

///|
impl @otf.ColrPainter for GlyphPainter with fn pop_clip(self) {
  self.svg.end_element()
}

///|
impl @otf.ColrPainter for GlyphPainter with fn push_clip_box(self, clipbox) {
  let x_min = rust_display_f32(clipbox.x_min)
  let x_max = rust_display_f32(clipbox.x_max)
  let y_min = rust_display_f32(clipbox.y_min)
  let y_max = rust_display_f32(clipbox.y_max)
  let clip_path = "M \{x_min} \{y_min} L \{x_max} \{y_min} L \{x_max} \{y_max} L \{x_min} \{y_max} Z"
  self.clip_with_path(clip_path)
}
