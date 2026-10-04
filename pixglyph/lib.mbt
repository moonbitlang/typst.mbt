// A port of the `pixglyph` crate (v0.6.1): OpenType glyph rendering.
//
// - Render glyph outlines into coverage bitmaps.
// - Place glyphs at subpixel offsets and scale them to subpixel sizes. This is
//   important if you plan to render more than a single glyph since inter-glyph
//   spacing will look off if every glyph origin must be pixel-aligned.
// - No font data structure you have to store somewhere. Just owned glyphs
//   which you can load individually from a font, cache if you care about
//   performance, and then render at any size.
//
// All arithmetic is `f32` (`Float`) exactly as upstream, so that the
// coverage bitmaps are bit-identical.

///|
/// A loaded glyph that is ready for rendering.
pub struct Glyph {
  /// The number of font design units per em unit.
  priv units_per_em : UInt16
  /// The glyph bounding box.
  priv bbox : @otf.Rect
  /// The path segments.
  priv segments : Array[Segment]
}

///|
/// A path segment.
priv enum Segment {
  /// A straight line.
  Line(Point, Point)
  /// A quadratic bezier curve.
  Quad(Point, Point, Point)
  /// A cubic bezier curve.
  Cubic(Point, Point, Point, Point)
}

///|
/// Load the glyph with the given `glyph_id` from the face.
///
/// Returns `None` if the glyph does not exist or the outline is malformed.
pub fn Glyph::load(face : @otf.Face, glyph_id : @otf.GlyphId) -> Glyph? {
  let builder = Builder::default()
  guard face.outline_glyph(glyph_id, builder) is Some(bbox) else { return None }

  // CFF2 does not have an `endchar` operator and ttf-parser does not emit
  // explicit `.close()` calls for CFF2 outlines. Having an unclosed path
  // can have adverse effects on the render, so we explicitly close the
  // path. Note that this is a no-op if the path was already closed
  // through ttf-parser.
  builder.close_path()
  Some({ units_per_em: face.units_per_em(), bbox, segments: builder.segments, })
}

///|
/// Rasterize the glyph.
///
/// # Placing & scaling
/// The values of `x` and `y` determine the subpixel positions at which the
/// glyph origin should reside in some larger pixel raster (i.e. a canvas
/// which you render text into).
///
/// The `size` defines how many pixels should correspond to `1em`
/// horizontally and vertically.
///
/// # Rendering into a larger canvas
/// The result of rasterization is a coverage bitmap along with position and
/// sizing data for it. The returned `left` and `top` values define on top of
/// which pixels in your canvas you should blend each of these new pixels.
pub fn Glyph::rasterize(
  self : Glyph,
  x : Float,
  y : Float,
  size : Float,
) -> Bitmap {
  // Scale is in pixel per em, but curve data is in font design units, so
  // we have to divide by units per em.
  let s = size / Float::from_int(self.units_per_em.to_int())

  // Determine the pixel-aligned bounding box of the glyph in the larger
  // pixel raster. For y, we flip and sign and min/max because Y-up. We
  // add a bit of horizontal slack to prevent floating problems when the
  // curve is directly at the border (only needed horizontally due to
  // row-by-row data layout).
  let slack : Float = 0.01
  let left = (x + s * i16f(self.bbox.x_min) - slack).floor().to_int()
  let right = (x + s * i16f(self.bbox.x_max) + slack).ceil().to_int()
  let top = (y - s * i16f(self.bbox.y_max)).floor().to_int()
  let bottom = (y - s * i16f(self.bbox.y_min)).ceil().to_int()
  let width = (right - left).reinterpret_as_uint()
  let height = (bottom - top).reinterpret_as_uint()

  // Create function to transform individual points.
  let dx = x - Float::from_int(left)
  let dy = y - Float::from_int(top)
  let t = (p : Point) => point(dx + p.x * s, dy - p.y * s)

  // Draw!
  let canvas = Canvas::new(width, height)
  for segment in self.segments {
    match segment {
      Line(p0, p1) => canvas.line(t(p0), t(p1))
      Quad(p0, p1, p2) => canvas.quad(t(p0), t(p1), t(p2))
      Cubic(p0, p1, p2, p3) => canvas.cubic(t(p0), t(p1), t(p2), t(p3))
    }
  }
  { left, top, width, height, coverage: canvas.accumulate(), }
}

///|
/// The result of rasterizing a glyph.
pub(all) struct Bitmap {
  /// Horizontal pixel position (from the left) at which the bitmap should be
  /// placed in the larger raster.
  left : Int
  /// Vertical pixel position (from the top) at which the bitmap should be
  /// placed in the larger raster.
  top : Int
  /// The width of the coverage bitmap in pixels.
  width : UInt
  /// The height of the coverage bitmap in pixels.
  height : UInt
  /// How much each pixel should be covered, `0` means 0% coverage and `255`
  /// means 100% coverage.
  ///
  /// The length of this vector is `width * height`, with the values being
  /// stored row-by-row.
  coverage : Bytes
}

///|
/// Upstream's `Debug` impl shows everything but the coverage.
pub impl Show for Bitmap with fn output(self, logger) {
  logger.write_string(
    "Bitmap { left: \{self.left}, top: \{self.top}, width: \{self.width}, height: \{self.height} }",
  )
}

///|
/// Builds the glyph outline.
priv struct Builder {
  segments : Array[Segment]
  mut start : Point?
  mut last : Point
}

///|
fn Builder::default() -> Builder {
  { segments: [], start: None, last: point(0.0, 0.0), }
}

///|
fn Builder::close_path(self : Builder) -> Unit {
  if self.start is Some(start) {
    self.start = None
    self.segments.push(Line(self.last, start))
    self.last = start
  }
}

///|
impl @otf.OutlineBuilder for Builder with fn move_to(self, x, y) {
  self.start = Some(point(x, y))
  self.last = point(x, y)
}

///|
impl @otf.OutlineBuilder for Builder with fn line_to(self, x, y) {
  self.segments.push(Line(self.last, point(x, y)))
  self.last = point(x, y)
}

///|
impl @otf.OutlineBuilder for Builder with fn quad_to(self, x1, y1, x2, y2) {
  self.segments.push(Quad(self.last, point(x1, y1), point(x2, y2)))
  self.last = point(x2, y2)
}

///|
impl @otf.OutlineBuilder for Builder with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x3,
  y3,
) {
  self.segments.push(
    Cubic(self.last, point(x1, y1), point(x2, y2), point(x3, y3)),
  )
  self.last = point(x3, y3)
}

///|
impl @otf.OutlineBuilder for Builder with fn close(self) {
  self.close_path()
}

// Accumulation, line and quad drawing taken from here:
// https://github.com/raphlinus/font-rs
//
// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// The internal rendering buffer.
priv struct Canvas {
  w : Int
  h : Int
  a : FixedArray[Float]
}

///|
/// Create a completely uncovered canvas.
fn Canvas::new(w : UInt, h : UInt) -> Canvas {
  {
    w: w.reinterpret_as_int(),
    h: h.reinterpret_as_int(),
    a: FixedArray::make((w * h + 4).reinterpret_as_int(), 0.0),
  }
}

///|
/// Return the accumulated coverage values.
fn Canvas::accumulate(self : Canvas) -> Bytes {
  // A plain loop with `min` and `to_int` spelled out (the closure call and
  // the core float helpers are not inlined; performance). `acc.abs().min(1.0)`
  // is in `[0, 1]` or NaN-free `1.0`, so the product is in `[0, 255]`.
  let n = self.w * self.h
  guard n >= 0 && n <= self.a.length() else { abort("canvas out of bounds") }
  let out = FixedArray::make(n, b'\x00')
  let mut acc : Float = 0.0
  for i in 0..<n {
    acc = acc + self.a.unsafe_get(i)
    let v = acc.abs()
    // `Float::min(v, 1.0)`: NaN yields the other operand.
    let v : Float = if v < 1.0 { v } else { 1.0 }
    out.unsafe_set(i, f32_to_i32_unchecked((255.0 : Float) * v).to_byte())
  }
  Bytes::from_fixedarray(out)
}

///|
/// Truncating conversion of a float known to be in the `Int` range.
fn f32_to_i32_unchecked(x : Float) -> Int = "%f32.to_i32"

///|
/// Add to a value in the accumulation buffer.
///
/// `linestart` is `y * w` for a row `y < h`, below the buffer length, so
/// `x < len - linestart` cannot overflow (upstream adds `usize`s).
#inline
fn Canvas::add(self : Canvas, linestart : Int, x : Int, delta : Float) -> Unit {
  let a = self.a
  if x >= 0 && x < a.length() - linestart {
    let i = linestart + x
    a.unsafe_set(i, a.unsafe_get(i) + delta)
  }
}

///|
/// Draw a straight line.
fn Canvas::line(self : Canvas, p0 : Point, p1 : Point) -> Unit {
  if (p0.y - p1.y).abs() <= f32_epsilon {
    return
  }
  let (dir, p0, p1) : (Float, Point, Point) = if p0.y < p1.y {
    (1.0, p0, p1)
  } else {
    (-1.0, p1, p0)
  }
  let dxdy = (p1.x - p0.x) / (p1.y - p0.y)
  let mut x = p0.x
  let y0 = f32_to_usize(p0.y)
  if p0.y < 0.0 {
    x = x - p0.y * dxdy
  }
  let y1 = min_int(self.h, f32_to_usize(f32_ceil(p1.y)))
  for y in y0..<y1 {
    let linestart = y * self.w
    let dy = f32_min(Float::from_int(y + 1), p1.y) -
      f32_max(Float::from_int(y), p0.y)
    let xnext = x + dxdy * dy
    let d = dy * dir
    let x0 = if x < xnext { x } else { xnext }
    let x1 = if x < xnext { xnext } else { x }
    let x0floor = f32_floor(x0)
    let x0i = f32_to_i32(x0floor)
    let x1ceil = f32_ceil(x1)
    let x1i = f32_to_i32(x1ceil)
    if x1i <= x0i + 1 {
      let xmf = (0.5 : Float) * (x + xnext) - x0floor
      self.add(linestart, x0i, d - d * xmf)
      self.add(linestart, x0i + 1, d * xmf)
    } else {
      let s = (1.0 : Float) / (x1 - x0)
      let x0f = x0 - x0floor
      let a0 = (0.5 : Float) * s * ((1.0 : Float) - x0f) * ((1.0 : Float) - x0f)
      let x1f = x1 - x1ceil + 1.0
      let am = (0.5 : Float) * s * x1f * x1f
      self.add(linestart, x0i, d * a0)
      if x1i == x0i + 2 {
        self.add(linestart, x0i + 1, d * ((1.0 : Float) - a0 - am))
      } else {
        let a1 = s * ((1.5 : Float) - x0f)
        self.add(linestart, x0i + 1, d * (a1 - a0))
        for xi in (x0i + 2)..<(x1i - 1) {
          self.add(linestart, xi, d * s)
        }
        let a2 = a1 + Float::from_int(x1i - x0i - 3) * s
        self.add(linestart, x1i - 1, d * ((1.0 : Float) - a2 - am))
      }
      self.add(linestart, x1i, d * am)
    }
    x = xnext
  }
}

///|
/// Draw a quadratic bezier curve.
fn Canvas::quad(self : Canvas, p0 : Point, p1 : Point, p2 : Point) -> Unit {
  // How much does the curve deviate from a straight line?
  let devsq = hypot2(p0 - mul(2.0, p1) + p2)

  // Check if the curve is already flat enough.
  if devsq < 0.333 {
    self.line(p0, p2)
    return
  }

  // Estimate the required number of subdivisions for flattening.
  let tol : Float = 3.0
  let n = (1.0 : Float) + f32_min(f32_floor((tol * devsq).sqrt().sqrt()), 30.0)
  let nu = f32_to_usize(n)
  let step = (1.0 : Float) / n

  // Flatten the curve.
  let mut t : Float = 0.0
  let mut p = p0
  for _ in 0..<(nu - 1) {
    t = t + step

    // Evaluate the curve at `t` using De Casteljau and draw a line from
    // the last point to the new evaluated point.
    let p01 = lerp(t, p0, p1)
    let p12 = lerp(t, p1, p2)
    let pt = lerp(t, p01, p12)
    self.line(p, pt)

    // Then set the evaluated point as the start point of the new line.
    p = pt
  }

  // Draw a final line.
  self.line(p, p2)
}

// Cubic to quad conversion adapted from here:
// https://github.com/linebender/kurbo/blob/master/src/cubicbez.rs
//
// Copyright 2018 The kurbo Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Draw a cubic bezier curve.
fn Canvas::cubic(
  self : Canvas,
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
) -> Unit {
  // How much does the curve deviate?
  let p1x2 = mul(3.0, p1) - p0
  let p2x2 = mul(3.0, p2) - p3
  let err = hypot2(p2x2 - p1x2)

  // Estimate the required number of subdivisions for conversion.
  let tol : Float = 0.333
  let max = (432.0 : Float) * tol * tol
  let n = clamp(f32_ceil(libm_powf(err / max, (1.0 : Float) / 6.0)), 1.0, 20.0)
  let nu = f32_to_usize(n)
  let step = (1.0 : Float) / n
  let step4 = step / 4.0

  // Compute the derivative of the cubic.
  let dp0 = mul(3.0, p1 - p0)
  let dp1 = mul(3.0, p2 - p1)
  let dp2 = mul(3.0, p3 - p2)

  // Convert the cubics to quadratics.
  let mut t : Float = 0.0
  let mut p = p0
  let mut pd = dp0
  for _ in 0..<nu {
    t = t + step

    // Evaluate the curve at `t` using De Casteljau.
    let p01 = lerp(t, p0, p1)
    let p12 = lerp(t, p1, p2)
    let p23 = lerp(t, p2, p3)
    let p012 = lerp(t, p01, p12)
    let p123 = lerp(t, p12, p23)
    let pt = lerp(t, p012, p123)

    // Evaluate the derivative of the curve at `t` using De Casteljau.
    let dp01 = lerp(t, dp0, dp1)
    let dp12 = lerp(t, dp1, dp2)
    let pdt = lerp(t, dp01, dp12)

    // Determine the control point of the quadratic.
    let pc = div(p + pt, 2.0) + mul(step4, pd - pdt)

    // Draw the quadratic.
    self.quad(p, pc, pt)
    p = pt
    pd = pdt
  }
}

///|
/// `f32::EPSILON`.
let f32_epsilon : Float = Float::reinterpret_from_uint(0x34000000)

///|
/// Rust's `f32::clamp` (NaN passes through).
fn clamp(v : Float, min : Float, max : Float) -> Float {
  let mut v = v
  if v < min {
    v = min
  }
  if v > max {
    v = max
  }
  v
}

///|
/// Rust's saturating `f32 as usize` cast (NaN and negatives give 0), capped
/// at `Int::max_value`.
fn f32_to_usize(v : Float) -> Int {
  let i = f32_to_i32(v)
  if i < 0 {
    0
  } else {
    i
  }
}

///|
/// Rust's saturating `f32 as i32` (NaN gives 0), like `Float::to_int`
/// (spelled out: the core helper is not inlined; performance).
#inline
fn f32_to_i32(v : Float) -> Int {
  if v != v {
    0
  } else if v >= 2147483647.0 {
    2147483647
  } else if v <= -2147483648.0 {
    -2147483648
  } else {
    f32_to_i32_unchecked(v)
  }
}

///|
/// `Float::min`: NaN yields the other operand (inlined; performance).
#inline
fn f32_min(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// `Float::max`: NaN yields the other operand (inlined; performance).
#inline
fn f32_max(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn i16f(v : Int16) -> Float {
  Float::from_int(v.to_int())
}

///|
/// A point in 2D.
#valtype
priv struct Point {
  x : Float
  y : Float
}

///|
/// Create a point.
fn point(x : Float, y : Float) -> Point {
  { x, y, }
}

///|
/// Linearly interpolate between two points.
fn lerp(t : Float, p1 : Point, p2 : Point) -> Point {
  { x: p1.x + t * (p2.x - p1.x), y: p1.y + t * (p2.y - p1.y), }
}

///|
/// The squared distance of the point from the origin.
fn hypot2(p : Point) -> Float {
  p.x * p.x + p.y * p.y
}

///|
impl Add for Point with fn add(self, rhs) {
  { x: self.x + rhs.x, y: self.y + rhs.y, }
}

///|
impl Sub for Point with fn sub(self, rhs) {
  { x: self.x - rhs.x, y: self.y - rhs.y, }
}

///|
/// `f32 * Point`.
fn mul(s : Float, p : Point) -> Point {
  { x: s * p.x, y: s * p.y, }
}

///|
/// `Point / f32`.
fn div(p : Point, s : Float) -> Point {
  { x: p.x / s, y: p.y / s, }
}
