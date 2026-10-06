// Regression test: random scenes (the generator of `tests/skdiff`) whose
// pixel hashes were recorded from upstream tiny-skia 0.12.

///|
struct Rng {
  mut s : UInt
}

///|
fn Rng::next(self : Rng) -> UInt {
  let mut x = self.s
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.s = x
  x
}

///|
fn Rng::below(self : Rng, n : UInt) -> UInt {
  self.next() % n
}

///|
fn Rng::belowi(self : Rng, n : Int) -> Int {
  (self.next() % n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn Rng::f(self : Rng, lo : Float, hi : Float) -> Float {
  let u = Float::from_uint(self.next() >> 8) / 16777216.0
  lo + (hi - lo) * u
}

///|
fn Rng::bool(self : Rng) -> Bool {
  (self.next() & 1) == 1
}

///|
fn rand_color(r : Rng) -> Color {
  let a = if r.bool() { 255 } else { r.belowi(256) }
  let rr = r.belowi(256)
  let g = r.belowi(256)
  let b = r.belowi(256)
  Color::from_rgba8(rr, g, b, a)
}

///|
fn rand_path(r : Rng, w : Float, h : Float) -> @path.Path? {
  let pb = @path.PathBuilder::new()
  let contours = 1 + r.belowi(3)
  for _ in 0..<contours {
    let x = r.f(-10.0, w + 10.0)
    let y = r.f(-10.0, h + 10.0)
    pb.move_to(x, y)
    let segs = 1 + r.belowi(5)
    for _ in 0..<segs {
      match r.belowi(4) {
        0 | 1 => {
          let x = r.f(-10.0, w + 10.0)
          let y = r.f(-10.0, h + 10.0)
          pb.line_to(x, y)
        }
        2 => {
          let x1 = r.f(-10.0, w + 10.0)
          let y1 = r.f(-10.0, h + 10.0)
          let x = r.f(-10.0, w + 10.0)
          let y = r.f(-10.0, h + 10.0)
          pb.quad_to(x1, y1, x, y)
        }
        _ => {
          let x1 = r.f(-10.0, w + 10.0)
          let y1 = r.f(-10.0, h + 10.0)
          let x2 = r.f(-10.0, w + 10.0)
          let y2 = r.f(-10.0, h + 10.0)
          let x = r.f(-10.0, w + 10.0)
          let y = r.f(-10.0, h + 10.0)
          pb.cubic_to(x1, y1, x2, y2, x, y)
        }
      }
    }
    if r.bool() {
      pb.close()
    }
  }
  if r.belowi(5) == 0 {
    let x = r.f(0.0, w)
    let y = r.f(0.0, h)
    let ww = r.f(1.0, w)
    let hh = r.f(1.0, h)
    if @path.Rect::from_xywh(x, y, ww, hh) is Some(rect) {
      pb.push_oval(rect)
    }
  }
  pb.finish()
}

///|
fn rand_transform(r : Rng) -> @path.Transform {
  match r.belowi(5) {
    0 | 1 => @path.Transform::identity()
    2 => {
      let x = r.f(-5.0, 5.0)
      let y = r.f(-5.0, 5.0)
      @path.Transform::from_translate(x, y)
    }
    3 => {
      let sx = r.f(0.3, 2.0)
      let sy = r.f(0.3, 2.0)
      let tx = r.f(-5.0, 5.0)
      let ty = r.f(-5.0, 5.0)
      @path.Transform::from_scale(sx, sy).post_translate(tx, ty)
    }
    _ => {
      let a = r.f(0.3, 1.5)
      let b = r.f(-0.5, 0.5)
      let c = r.f(-0.5, 0.5)
      let d = r.f(0.3, 1.5)
      let e = r.f(-5.0, 5.0)
      let f = r.f(-5.0, 5.0)
      @path.Transform::from_row(a, b, c, d, e, f)
    }
  }
}

///|
let blend_modes : Array[BlendMode] = [
  Clear,
  Source,
  Destination,
  SourceOver,
  DestinationOver,
  SourceIn,
  DestinationIn,
  SourceOut,
  DestinationOut,
  SourceAtop,
  DestinationAtop,
  Xor,
  Plus,
  Modulate,
  Screen,
  Overlay,
  Darken,
  Lighten,
  ColorDodge,
  ColorBurn,
  HardLight,
  SoftLight,
  Difference,
  Exclusion,
  Multiply,
  Hue,
  Saturation,
  Color,
  Luminosity,
]

///|
fn rand_spread(r : Rng) -> SpreadMode {
  match r.belowi(3) {
    0 => Pad
    1 => Reflect
    _ => Repeat
  }
}

///|
fn rand_stops(r : Rng) -> Array[GradientStop] {
  let n = 1 + r.belowi(5)
  let v = []
  let mut pos = r.f(-0.2, 0.5)
  for _ in 0..<n {
    let c = rand_color(r)
    v.push(GradientStop::new(pos, c))
    pos += r.f(0.0, 0.5)
  }
  v
}

///|
fn rand_pixmap(r : Rng) -> Pixmap {
  let w = 1U + r.below(8)
  let h = 1U + r.below(8)
  let p = Pixmap::new(w, h).unwrap()
  let px = p.pixels()
  for i in 0..<px.length() {
    let rr = r.belowi(256)
    let g = r.belowi(256)
    let b = r.belowi(256)
    let a = r.belowi(256)
    px[i] = ColorU8::from_rgba(rr, g, b, a).premultiply().0
  }
  p
}

///|
fn rand_quality(r : Rng) -> FilterQuality {
  match r.belowi(3) {
    0 => Nearest
    1 => Bilinear
    _ => Bicubic
  }
}

///|
fn rand_shader(r : Rng, w : Float, h : Float, patt : Pixmap) -> Shader {
  match r.belowi(6) {
    0 | 1 => SolidColor(rand_color(r))
    2 => {
      let sx = r.f(0.0, w)
      let sy = r.f(0.0, h)
      let ex = r.f(0.0, w)
      let ey = r.f(0.0, h)
      let stops = rand_stops(r)
      let mode = rand_spread(r)
      let ts = rand_transform(r)
      LinearGradient::new(
        @path.Point::from_xy(sx, sy),
        @path.Point::from_xy(ex, ey),
        stops,
        mode,
        ts,
      ).unwrap_or(SolidColor(color_black))
    }
    3 => {
      let sx = r.f(0.0, w)
      let sy = r.f(0.0, h)
      let s = @path.Point::from_xy(sx, sy)
      let sr : Float = if r.bool() { 0.0 } else { r.f(0.0, w / 2.0) }
      let e = if r.bool() {
        s
      } else {
        let x = r.f(0.0, w)
        let y = r.f(0.0, h)
        @path.Point::from_xy(x, y)
      }
      let er = r.f(0.0, w)
      let stops = rand_stops(r)
      let mode = rand_spread(r)
      let ts = rand_transform(r)
      RadialGradient::new(s, sr, e, er, stops, mode, ts).unwrap_or(
        SolidColor(color_black),
      )
    }
    4 => {
      let cx = r.f(0.0, w)
      let cy = r.f(0.0, h)
      let a0 = r.f(-90.0, 180.0)
      let a1 = a0 + r.f(0.0, 400.0)
      let stops = rand_stops(r)
      let mode = rand_spread(r)
      let ts = rand_transform(r)
      SweepGradient::new(@path.Point::from_xy(cx, cy), a0, a1, stops, mode, ts).unwrap_or(
        SolidColor(color_black),
      )
    }
    _ => {
      let mode = rand_spread(r)
      let q = rand_quality(r)
      let op : Float = if r.bool() { 1.0 } else { r.f(0.0, 1.0) }
      let ts = rand_transform(r)
      Pattern::new(patt, mode, q, op, ts)
    }
  }
}

///|
fn rand_paint(r : Rng, w : Float, h : Float, patt : Pixmap) -> Paint {
  let paint = Paint::default()
  paint.shader = rand_shader(r, w, h, patt)
  paint.anti_alias = r.belowi(4) != 0
  paint.blend_mode = if r.bool() {
    SourceOver
  } else {
    blend_modes[r.belowi(29)]
  }
  paint.colorspace = match r.belowi(8) {
    0 => Gamma2
    1 => SimpleSRGB
    2 => FullSRGBGamma
    _ => Linear
  }
  paint.force_hq_pipeline = r.belowi(4) == 0
  paint
}

///|
fn rand_mask(r : Rng, w : UInt, h : UInt) -> Mask? {
  if r.belowi(3) != 0 {
    return None
  }
  let m = Mask::new(w, h).unwrap()
  if rand_path(r, Float::from_uint(w), Float::from_uint(h)) is Some(p) {
    let fr : FillRule = if r.bool() { Winding } else { EvenOdd }
    let aa = r.bool()
    let ts = rand_transform(r)
    m.fill_path(p, fr, aa, ts)
  }
  if r.bool() {
    if rand_path(r, Float::from_uint(w), Float::from_uint(h)) is Some(p) {
      m.intersect_path(p, Winding, true, @path.Transform::identity())
    }
  }
  Some(m)
}

///|
fn fnv(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
fn scene(seed : UInt, stroke_widths : Bool, hair : Bool) -> Pixmap {
  let r : Rng = { s: (seed * 2654435761U + 12345U) | 1U, }
  for _ in 0..<4 {
    r.next() |> ignore
  }
  let w = 8U + r.below(70)
  let h = 8U + r.below(70)
  let wf = Float::from_uint(w)
  let hf = Float::from_uint(h)
  let pixmap = Pixmap::new(w, h).unwrap()
  if r.bool() {
    pixmap.fill(rand_color(r))
  }
  let n = 1 + r.belowi(4)
  for _ in 0..<n {
    let patt = rand_pixmap(r)
    let kind = r.belowi(6)
    let paint = rand_paint(r, wf, hf, patt)
    let mask = rand_mask(r, w, h)
    let ts = rand_transform(r)
    match kind {
      0 | 1 =>
        if rand_path(r, wf, hf) is Some(p) {
          let fr : FillRule = if r.bool() { Winding } else { EvenOdd }
          pixmap.fill_path(p, paint, fr, ts, mask)
        }
      2 =>
        if rand_path(r, wf, hf) is Some(p) {
          let width : Float = match r.belowi(4) {
            0 => 0.0
            1 => r.f(0.0, 1.0)
            _ => if stroke_widths { r.f(0.0, 6.0) } else { 0.0 }
          }
          let line_cap : @path.LineCap = match r.belowi(3) {
            0 => Butt
            1 => Round
            _ => Square
          }
          let line_join : @path.LineJoin = match r.belowi(4) {
            0 => Miter
            1 => MiterClip
            2 => Round
            _ => Bevel
          }
          let miter_limit = r.f(1.0, 6.0)
          let width : Float = if hair { 0.0 } else { width }
          let mut dash = None
          if stroke_widths && r.belowi(4) == 0 {
            let a = r.f(0.5, 5.0)
            let b = r.f(0.5, 5.0)
            let off = r.f(0.0, 5.0)
            dash = @path.StrokeDash::new([a, b], off)
          }
          let stroke : @path.Stroke = {
            width,
            miter_limit,
            line_cap,
            line_join,
            dash,
          }
          pixmap.stroke_path(p, paint, stroke, ts, mask)
        }
      3 | 4 => {
        let x = r.f(-5.0, wf)
        let y = r.f(-5.0, hf)
        let ww = r.f(0.0, wf)
        let hh = r.f(0.0, hf)
        if @path.Rect::from_xywh(x, y, ww, hh) is Some(rect) {
          pixmap.fill_rect(rect, paint, ts, mask)
        }
      }
      _ => {
        let opacity : Float = if r.bool() { 1.0 } else { r.f(0.0, 1.0) }
        let quality = rand_quality(r)
        let pp : PixmapPaint = {
          opacity,
          blend_mode: paint.blend_mode,
          quality,
        }
        let x = r.below(w + 10).reinterpret_as_int() - 5
        let y = r.below(h + 10).reinterpret_as_int() - 5
        pixmap.draw_pixmap(x, y, patt, pp, ts, mask)
      }
    }
  }
  pixmap
}

///|
fn hex16(x : UInt64) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for i = 15; i >= 0; i = i - 1 {
    sb.write_char(digits[((x >> (i * 4)) & 0xF).to_int()].unsafe_to_char())
  }
  sb.to_string()
}

///|
test "scenes match upstream tiny-skia" {
  let expected = [
    "05dad4dd8aa5a852", "204a31d65458035c", "6bff818ec237d8e5", "e94bf87f1d573e25",
    "aff63b2327ff85c5", "bee82eabab5d2de4", "2456fc44d96cd1cd", "05942b4e39d11b25",
    "345cc2bf4ee421c4", "f24a1cf51311bcb3", "450e757298860fa2", "2493a579928ea08e",
    "c7c393003f147982", "02d718fe08399379", "b73726236bd676e0", "25499f32eb9b3867",
    "183cea4d4839d75a", "d5d698b846d8eee0", "750ed5fd79074155", "bcc280150784f599",
    "a4314b9faf5ef263", "0621709c32ebb3a1", "c6af94bd431eaaaf", "4a9c32e4a3640675",
    "96dfaef5fad33364", "6e00ea6e3112b991", "8ab711185503b3bb", "e5193b21dda6c5b1",
    "6ff1893e21e60998", "f66a7b9f8b667963", "976f9cd19b44890f", "fbf374df266019c4",
    "44ffb17af5869b7d", "a2490d6641b4ea1e", "e32c355954a647ec", "36f20b45c79bf68e",
    "3b84d7fe55b54085", "16523c35053cc68d", "d085542c8ef75848", "75ce4027a5fc2f45",
  ]
  for i, h in expected {
    let p = scene(i.reinterpret_as_uint(), true, false)
    assert_eq(hex16(fnv(p.data())), h)
  }
}
