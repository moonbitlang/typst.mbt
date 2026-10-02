// Port of `typst-library/src/text/font/color.rs`: utilities for color font
// handling.

///|
/// Whether this glyph should be rendered via simple outlining instead of via
/// `glyph_frame`.
pub fn should_outline(font : FontInstance, glyph_id : UInt16) -> Bool {
  guard font.ttf() is Some(ttf) else { return true }
  let g = @otf.GlyphId(glyph_id)
  (
    ttf.tables().glyf is Some(_) ||
    ttf.tables().cff is Some(_) ||
    ttf.tables().cff2 is Some(_)
  ) &&
  !(ttf.glyph_raster_image(g, 0xFFFF) is Some(img) && img.format == PNG) &&
  !ttf.is_color_glyph(g) &&
  ttf.glyph_svg_image(g) is None
}

///|
/// A frame that can draw a glyph.
pub(all) struct GlyphFrame {
  upem : Abs
  item : GlyphFrameItem
}

///|
/// The font unit square.
pub fn GlyphFrame::size(self : GlyphFrame) -> Axes[Abs] {
  Axes::splat(self.upem)
}

///|
/// Upstream `From<GlyphFrame> for Frame`.
pub fn GlyphFrame::to_frame(self : GlyphFrame) -> Frame {
  let frame = Frame::soft(Axes::splat(self.upem))
  match self.item {
    Tofu(pos, shape) =>
      frame.push(pos, FrameItem::Shape(shape, @syntax.Span::detached()))
    Image(pos, image, size) =>
      frame.push(pos, FrameItem::Image(image, size, @syntax.Span::detached()))
  }
  frame
}

///|
/// The glyph item that is drawn.
pub(all) enum GlyphFrameItem {
  /// A fallback rectangle.
  Tofu(Point, Shape)
  /// An image glyph.
  Image(Point, Image, Axes[Abs])
}

///|
/// The position of the glyph item inside the parent frame.
pub fn GlyphFrameItem::pos(self : GlyphFrameItem) -> Point {
  match self {
    Tofu(pos, _) => pos
    Image(pos, _, _) => pos
  }
}

///|
/// Memoized results of [glyph_frame] (upstream `#[comemo::memoize]`).
let glyph_frame_cache : Map[(FontInstance, UInt16), GlyphFrame?] = {}

///|
/// Returns a frame representing a glyph and whether it is a fallback tofu
/// frame.
///
/// Should only be called on glyphs for which [`should_outline`] returns false.
///
/// The glyphs are sized in font units, `text.item.size` is not taken into
/// account.
pub fn glyph_frame(font : FontInstance, glyph_id : UInt16) -> GlyphFrame? {
  match glyph_frame_cache.get((font, glyph_id)) {
    Some(frame) => frame
    None => {
      let frame = glyph_frame_impl(font, glyph_id)
      glyph_frame_cache[(font, glyph_id)] = frame
      frame
    }
  }
}

///|
fn glyph_frame_impl(font : FontInstance, glyph_id : UInt16) -> GlyphFrame? {
  let upem = Abs::pt(font.units_per_em())
  if draw_glyph(font, upem, glyph_id) is Some(frame) {
    return Some(frame)
  }

  // Generate a fallback tofu if the glyph couldn't be drawn, unless it is
  // the space glyph. Then, an empty frame does the job. (This happens for
  // some rare CBDT fonts, which don't define a bitmap for the space, but
  // also don't have a glyf or CFF table.)
  let space = match font.ttf() {
    Some(ttf) => ttf.glyph_index(' ')
    None => None
  }
  let not_space = space != Some(@otf.GlyphId(glyph_id))
  if not_space {
    Some(draw_fallback_tofu(font, upem, glyph_id))
  } else {
    None
  }
}

///|
/// Tries to draw a glyph.
fn draw_glyph(
  font : FontInstance,
  upem : Abs,
  glyph_id : UInt16,
) -> GlyphFrame? {
  guard font.ttf() is Some(ttf) else { return None }
  let g = @otf.GlyphId(glyph_id)
  let kind = match ttf.glyph_raster_image(g, 0xFFFF) {
    Some(raster_image) if raster_image.format == PNG =>
      draw_raster_glyph(font, upem, raster_image)
    _ =>
      if ttf.is_color_glyph(g) {
        draw_colr_glyph(font, g)
      } else if ttf.glyph_svg_image(g) is Some(_) {
        draw_svg_glyph(font, g)
      } else {
        None
      }
  }
  kind.map(kind => GlyphFrame::{ upem, item: kind, })
}

///|
/// Draws a fallback tofu box with the advance width of the glyph.
fn draw_fallback_tofu(
  font : FontInstance,
  upem : Abs,
  glyph_id : UInt16,
) -> GlyphFrame {
  let advance = match font.ttf() {
    Some(ttf) =>
      match ttf.glyph_hor_advance(@otf.GlyphId(glyph_id)) {
        Some(advance) => Abs::pt(advance.to_int().to_double())
        None => upem.div_by(3.0)
      }
    None => upem.div_by(3.0)
  }
  let inset = advance.times(0.15)
  let height = upem.times(0.7)
  let pos = Point::new(inset, upem - height)
  let size = Axes::new(advance - inset.times(2.0), height)
  let thickness = upem.div_by(20.0)
  let stroke = { ..FixedStroke::default(), thickness, }
  let shape = Geometry::Rect(size).stroked(stroke)
  { upem, item: Tofu(pos, shape), }
}

///|
/// Draws a raster glyph in a frame.
///
/// Supports only PNG images.
fn draw_raster_glyph(
  font : FontInstance,
  upem : Abs,
  raster_image : @otf.RasterGlyphImage,
) -> GlyphFrameItem? {
  let data = raster_image.data.to_bytes()
  let raster = RasterImage::plain(data, Exchange(Png)) catch {
    _ => return None
  }
  let image = Image::plain(Raster(raster))
  let scale = upem.div_by(raster_image.pixels_per_em.to_int().to_double())
  let image_width = scale.times(image.width())
  let image_height = scale.times(image.height())
  let x_offset = scale.times(raster_image.x.to_int().to_double())
  let mut y_offset = scale.times(raster_image.y.to_int().to_double())
  // Apple Color emoji doesn't provide offset information (or at least
  // not in a way ttf-parser understands), so we artificially shift their
  // baseline to make it look good.
  if @unicode.to_lowercase(font.font().info().family) == "apple color emoji" {
    // This factor is taken from krilla.
    y_offset = y_offset - upem.times(0.125)
  }
  let position = Point::new(-x_offset, -(image_height + y_offset))
  let size = Axes::new(image_width, image_height)
  Some(Image(position, image, size))
}

///|
/// Draws a glyph from the COLR table into the frame.
fn draw_colr_glyph(
  font : FontInstance,
  glyph_id : @otf.GlyphId,
) -> GlyphFrameItem? {
  guard colr_glyph_to_svg(font, glyph_id) is Some(svg_string) else {
    return None
  }
  let ttf = font.ttf().unwrap()
  let bbox = ttf.global_bounding_box()
  let width = bbox.width().to_int().to_double()
  let height = bbox.height().to_int().to_double()
  let x_min = bbox.x_min.to_int().to_double()
  let y_max = bbox.y_max.to_int().to_double()
  let data = @utf8.encode(svg_string)
  let svg = SvgImage::new(data) catch { _ => return None }
  let image = Image::plain(Svg(svg))
  let position = Point::new(Abs::pt(x_min), Abs::pt(-y_max))
  let size = Axes::new(Abs::pt(width), Abs::pt(height))
  Some(Image(position, image, size))
}

///|
/// Convert a COLR glyph into an SVG file.
fn colr_glyph_to_svg(font : FontInstance, glyph_id : @otf.GlyphId) -> String? {
  let svg = @xmlwriter.XmlWriter::new(@xmlwriter.Options::default())
  let ttf = font.ttf().unwrap()
  let bbox = ttf.global_bounding_box()
  let width = bbox.width().to_int().to_double()
  let height = bbox.height().to_int().to_double()
  let x_min = bbox.x_min.to_int().to_double()
  let y_max = bbox.y_max.to_int().to_double()
  let tx = -x_min
  let ty = -y_max
  svg.start_element("svg")
  svg.write_attribute("xmlns", "http://www.w3.org/2000/svg")
  svg.write_attribute("xmlns:xlink", "http://www.w3.org/1999/xlink")
  svg.write_attribute("width", rust_display_f64(width))
  svg.write_attribute("height", rust_display_f64(height))
  svg.write_attribute(
    "viewBox",
    "0 0 \{rust_display_f64(width)} \{rust_display_f64(height)}",
  )
  let gradient_index = 1
  let clip_path_index = 1
  svg.start_element("g")
  svg.write_attribute(
    "transform",
    "matrix(1 0 0 -1 0 0) matrix(1 0 0 1 \{rust_display_f64(tx)} \{rust_display_f64(ty)})",
  )
  let glyph_painter : GlyphPainter = {
    face: ttf,
    svg,
    path_buf: StringBuilder::new(),
    gradient_index,
    clip_path_index,
    palette_index: 0,
    transform: @otf.Transform::default(),
    outline_transform: @otf.Transform::default(),
    transforms_stack: [@otf.Transform::default()],
  }
  guard ttf.paint_color_glyph(
      glyph_id,
      0,
      @otf.RgbaColor::new(b'\x00', b'\x00', b'\x00', b'\xFF'),
      glyph_painter,
    )
    is Some(_) else {
    return None
  }
  svg.end_element()
  Some(svg.end_document())
}

///|
/// Draws an SVG glyph in a frame.
fn draw_svg_glyph(
  font : FontInstance,
  glyph_id : @otf.GlyphId,
) -> GlyphFrameItem? {
  // TODO: Our current conversion of the SVG table works for Twitter Color Emoji,
  // but might not work for others. See also: https://github.com/RazrFalcon/resvg/pull/776
  guard font.ttf() is Some(ttf) else { return None }
  guard ttf.glyph_svg_image(glyph_id) is Some(doc) else { return None }
  let mut data = doc.data.to_bytes()

  // Decompress SVGZ.
  if data.length() >= 2 && data[0] == b'\x1f' && data[1] == b'\x8b' {
    data = @codecs.gzip_decompress(data[:]) catch { _ => return None }
  }

  // Parse and simplify the SVG.
  guard bytes_to_str(data[:]) is Some(xml) else { return None }
  let document = @xml.Document::parse(xml) catch { _ => return None }
  let opts = @usvg.Options::default()
  let tree = @usvg.Tree::from_xmltree(document, opts) catch { _ => return None }
  let data = tree.to_string({
    ..@usvg.WriteOptions::default(),
    indent: None,
    attributes_indent: None,
  })

  // The SVG coordinates and the font coordinates are not the same: the Y axis
  // is mirrored. But the origin of the axes are the same (which means that
  // the horizontal axis in the SVG document corresponds to the baseline). See
  // the reference for more details:
  // https://learn.microsoft.com/en-us/typography/opentype/spec/svg#coordinate-systems-and-glyph-metrics
  //
  // Using this SVG directly can result in a cropped glyph. In order to avoid
  // clipping issues, we apply a translate transform so the top-left corner of
  // the bounding box is moved into the origin (0, 0) to make it fully fit
  // into the view port defined by `viewBox="0 0 width height"`, like a
  // conventional SVG.
  let bbox = tree.root().bounding_box()
  let view_box = Rect::new(
    Point::new(
      Abs::pt(bbox.left().to_double()),
      Abs::pt(bbox.top().to_double()),
    ),
    Point::new(
      Abs::pt(bbox.right().to_double()),
      Abs::pt(bbox.bottom().to_double()),
    ),
  )
  let data = fixup_svg(data, view_box)
  let svg = SvgImage::new(@utf8.encode(data)) catch { _ => return None }
  let image = Image::plain(Svg(svg))
  let position = Point::new(view_box.min.x, view_box.min.y)
  let size = view_box.size()
  Some(Image(position, image, size))
}

///|
/// Replace or insert the size attributes (viewBox, width and height), and
/// insert a group with a transform that translates the `viewBox` so that the
/// top-left point is at the origin (0, 0).
///
/// Works on the UTF-16 string like upstream on the UTF-8 one; all scanned
/// syntax is ASCII.
fn fixup_svg(svg : String, view_box : Rect) -> String {
  let mut viewbox_range : (Int, Int)? = None
  let mut width_range : (Int, Int)? = None
  let mut height_range : (Int, Int)? = None
  let n = svg.length()
  let mut cursor = 0
  // `s.eat_until("<svg"); s.expect("<svg")`
  match svg.find("<svg") {
    Some(i) => cursor = i + 4
    None => abort("expected <svg")
  }
  let svg_attr_start = cursor
  let is_ws = (c : Int) => c is (0x20 | 0x09 | 0x0A | 0x0D)
  while true {
    // `!s.eat_if('>') && !s.done()`
    if cursor < n && svg.unsafe_get(cursor).to_int() == '>'.to_int() {
      cursor += 1
      break
    }
    if cursor >= n {
      break
    }
    // `s.eat_whitespace()` (Unicode whitespace; the writer only emits ASCII).
    while cursor < n && is_ws(svg.unsafe_get(cursor).to_int()) {
      cursor += 1
    }
    let start = cursor
    // `s.eat_until('=')`
    while cursor < n && svg.unsafe_get(cursor).to_int() != '='.to_int() {
      cursor += 1
    }
    let attr_name = svg
      .unsafe_substring(start~, end=cursor)
      .trim(chars=" \t\n\r")
    // Eat the equal sign and the quote.
    if cursor < n {
      cursor += 1
    } else {
      abort("expected =")
    }
    while cursor < n && svg.unsafe_get(cursor).to_int() != '"'.to_int() {
      cursor += 1
    }
    if cursor < n {
      cursor += 1
    } else {
      abort("expected \"")
    }
    while true {
      if cursor < n && svg.unsafe_get(cursor).to_int() == '"'.to_int() {
        cursor += 1
        break
      }
      if cursor >= n {
        break
      }
      cursor += 1
    }
    match attr_name.to_string() {
      "viewBox" => viewbox_range = Some((start, cursor))
      "width" => width_range = Some((start, cursor))
      "height" => height_range = Some((start, cursor))
      _ => ()
    }
  }
  let svg_body_start = cursor
  guard svg.rev_find("</svg>") is Some(svg_body_end) else { return svg }
  let mut svg = svg.unsafe_substring(start=0, end=svg_body_end) +
    "</g>" +
    svg.unsafe_substring(start=svg_body_end, end=n)
  svg = svg.unsafe_substring(start=0, end=svg_body_start) +
    "<g transform=\"translate(\{rust_display_f64(-view_box.min.x.to_pt())} \{rust_display_f64(-view_box.min.y.to_pt())})\">" +
    svg.unsafe_substring(start=svg_body_start, end=svg.length())
  let size = view_box.size()
  let edits = [
    (
      viewbox_range,
      "viewBox=\"0 0 \{rust_display_f64(size.x.to_pt())} \{rust_display_f64(size.y.to_pt())}\"",
    ),
    (width_range, "width=\"\{rust_display_f64(size.x.to_pt())}\""),
    (height_range, "height=\"\{rust_display_f64(size.y.to_pt())}\""),
  ]

  // Sort edits by ranges; missing ranges will be moved to the start (a
  // stable sort by the range start).
  let indexed = edits.mapi((i, e) => (i, e))
  indexed.sort_by((a, b) => {
    let key = (e : ((Int, Int)?, String)) => {
      match e.0 {
        Some((s, _)) => s
        None => -1
      }
    }
    let c = key(a.1).compare(key(b.1))
    if c != 0 {
      c
    } else {
      a.0.compare(b.0)
    }
  })

  // Replace or insert the attribute. Iterate in reverse, so the modifying the
  // string doesn't affect the ranges of the edits that are applied later on.
  for i = indexed.length() - 1; i >= 0; i = i - 1 {
    let (range, str) = indexed[i].1
    match range {
      Some((s, e)) =>
        svg = svg.unsafe_substring(start=0, end=s) +
          str +
          svg.unsafe_substring(start=e, end=svg.length())
      None =>
        svg = svg.unsafe_substring(start=0, end=svg_attr_start) +
          " " +
          str +
          svg.unsafe_substring(start=svg_attr_start, end=svg.length())
    }
  }
  svg
}

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
  self.write_spread_method_attribute(gradient.extend)
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
  self.write_spread_method_attribute(gradient.extend)
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
/// `tiny_skia_path::Transform` (row form `sx ky kx sy tx ty`).
priv struct SkTransform {
  sx : Float
  ky : Float
  kx : Float
  sy : Float
  tx : Float
  ty : Float
} derive(Eq)

///|
let sk_identity : SkTransform = {
  sx: 1.0,
  ky: 0.0,
  kx: 0.0,
  sy: 1.0,
  tx: 0.0,
  ty: 0.0,
}

///|
fn SkTransform::is_identity(self : SkTransform) -> Bool {
  self == sk_identity
}

///|
fn SkTransform::has_scale(self : SkTransform) -> Bool {
  self.sx != 1.0 || self.sy != 1.0
}

///|
fn SkTransform::has_skew(self : SkTransform) -> Bool {
  self.kx != 0.0 || self.ky != 0.0
}

///|
fn SkTransform::has_translate(self : SkTransform) -> Bool {
  self.tx != 0.0 || self.ty != 0.0
}

///|
fn SkTransform::is_scale_translate(self : SkTransform) -> Bool {
  (self.has_scale() || self.has_translate()) && !self.has_skew()
}

///|
fn SkTransform::is_finite(self : SkTransform) -> Bool {
  let fin = (x : Float) => !x.is_nan() && !x.is_inf()
  fin(self.sx) &&
  fin(self.ky) &&
  fin(self.kx) &&
  fin(self.sy) &&
  fin(self.tx) &&
  fin(self.ty)
}

///|
/// `tiny_skia_path::Transform::invert`.
fn SkTransform::invert(self : SkTransform) -> SkTransform? {
  // Allow the trivial case to be inlined.
  if self.is_identity() {
    return Some(self)
  }
  if self.is_scale_translate() {
    if self.has_scale() {
      let inv_x : Float = 1.0 / self.sx
      let inv_y : Float = 1.0 / self.sy
      Some({
        sx: inv_x,
        ky: 0.0,
        kx: 0.0,
        sy: inv_y,
        tx: -self.tx * inv_x,
        ty: -self.ty * inv_y,
      })
    } else {
      // translate only
      Some({ ..sk_identity, tx: -self.tx, ty: -self.ty, })
    }
  } else {
    let dcross = (a : Double, b : Double, c : Double, d : Double) => {
      a * b - c * d
    }
    let det = dcross(
      self.sx.to_double(),
      self.sy.to_double(),
      self.kx.to_double(),
      self.ky.to_double(),
    )
    // Since the determinant is on the order of the cube of the matrix members,
    // compare to the cube of the default nearly-zero constant (although an
    // estimate of the condition number would be better if it wasn't so expensive).
    let nearly_zero : Float = 1.0 / 4096.0
    let tolerance = nearly_zero * nearly_zero * nearly_zero
    if Float::from_double(det).abs() <= tolerance {
      return None
    }
    let inv_det = 1.0 / det
    let dcross_dscale = (a : Float, b : Float, c : Float, d : Float) => {
      Float::from_double(
        dcross(a.to_double(), b.to_double(), c.to_double(), d.to_double()) *
        inv_det,
      )
    }
    let inv_ts : SkTransform = {
      sx: Float::from_double(self.sy.to_double() * inv_det),
      ky: Float::from_double(-self.ky.to_double() * inv_det),
      kx: Float::from_double(-self.kx.to_double() * inv_det),
      sy: Float::from_double(self.sx.to_double() * inv_det),
      tx: dcross_dscale(self.kx, self.ty, self.sy, self.tx),
      ty: dcross_dscale(self.ky, self.tx, self.sx, self.ty),
    }
    if inv_ts.is_finite() {
      Some(inv_ts)
    } else {
      None
    }
  }
}

///|
/// `tiny_skia_path::Transform::pre_concat` (`concat(self, other)`).
fn SkTransform::pre_concat(self : SkTransform, b : SkTransform) -> SkTransform {
  let a = self
  let mul_add_mul = (a : Float, b : Float, c : Float, d : Float) => {
    Float::from_double(
      a.to_double() * b.to_double() + c.to_double() * d.to_double(),
    )
  }
  if a.is_identity() {
    b
  } else if b.is_identity() {
    a
  } else if !a.has_skew() && !b.has_skew() {
    // just scale and translate
    {
      sx: a.sx * b.sx,
      ky: 0.0,
      kx: 0.0,
      sy: a.sy * b.sy,
      tx: a.sx * b.tx + a.tx,
      ty: a.sy * b.ty + a.ty,
    }
  } else {
    {
      sx: mul_add_mul(a.sx, b.sx, a.kx, b.ky),
      ky: mul_add_mul(a.ky, b.sx, a.sy, b.ky),
      kx: mul_add_mul(a.sx, b.kx, a.kx, b.sy),
      sy: mul_add_mul(a.ky, b.kx, a.sy, b.sy),
      tx: mul_add_mul(a.sx, b.tx, a.kx, b.ty) + a.tx,
      ty: mul_add_mul(a.ky, b.tx, a.sy, b.ty) + a.ty,
    }
  }
}

///|
fn paint_transform(
  outline_transform : @otf.Transform,
  transform : @otf.Transform,
) -> @otf.Transform {
  let outline_transform : SkTransform = {
    sx: outline_transform.a,
    ky: outline_transform.b,
    kx: outline_transform.c,
    sy: outline_transform.d,
    tx: outline_transform.e,
    ty: outline_transform.f,
  }
  let gradient_transform : SkTransform = {
    sx: transform.a,
    ky: transform.b,
    kx: transform.c,
    sy: transform.d,
    tx: transform.e,
    ty: transform.f,
  }
  let gradient_transform = outline_transform
    .invert()
    // In theory, we should error out. But the transform shouldn't ever be uninvertible, so let's ignore it.
    .unwrap_or(sk_identity)
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
