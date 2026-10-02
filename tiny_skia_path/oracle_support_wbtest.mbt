// Helpers for the generated oracle tests (oracle_wbtest.mbt): dump formats
// identical to oracle/src/bin/gen_tiny_skia_path_tests.rs, and `bulk_fuzz`,
// a mirror of the generator's RNG-driven fuzzing loop.

///|
fn f(b : UInt) -> Float {
  Float::reinterpret_from_uint(b)
}

///|
fn hx(v : Float) -> String {
  let s = v.reinterpret_as_uint().to_string(radix=16)
  pad0(s, 8)
}

///|
/// Long dumps are compared by length + FNV-1a 64 hash + a short prefix.
fn dg(s : String) -> String {
  if s.length() <= 400 {
    return s
  }
  let mut h : UInt64 = 0xcbf29ce484222325UL
  for i in 0..<s.length() {
    h = h ^ s.code_unit_at(i).to_int().to_uint64()
    h = h * 0x100000001b3UL
  }
  let b = StringBuilder()
  b.write_string("#\{s.length()} ")
  b.write_string(pad0(h.to_string(radix=16), 16))
  b.write_char(' ')
  for i, c in s {
    if i >= 100 {
      break
    }
    b.write_char(c)
  }
  b.to_string()
}

///|
fn pad0(s : String, n : Int) -> String {
  let b = StringBuilder()
  for _ in s.length()..<n {
    b.write_char('0')
  }
  b.write_string(s)
  b.to_string()
}

///|
fn dverb(v : PathVerb) -> String {
  match v {
    Move => "Move"
    Line => "Line"
    Quad => "Quad"
    Cubic => "Cubic"
    Close => "Close"
  }
}

///|
fn dpt(p : Point) -> String {
  hx(p.x) + "," + hx(p.y)
}

///|
fn drect(r : Rect?) -> String {
  match r {
    None => "None"
    Some(r) =>
      "\{hx(r.left())},\{hx(r.top())},\{hx(r.right())},\{hx(r.bottom())}"
  }
}

///|
fn dnzrect(r : NonZeroRect?) -> String {
  match r {
    None => "None"
    Some(r) =>
      "\{hx(r.left())},\{hx(r.top())},\{hx(r.right())},\{hx(r.bottom())}"
  }
}

///|
fn dintrect(r : IntRect?) -> String {
  match r {
    None => "None"
    Some(r) => "\{r.x()},\{r.y()},\{r.width()},\{r.height()}"
  }
}

///|
fn dsize(s : Size?) -> String {
  match s {
    None => "None"
    Some(s) => "\{hx(s.width())},\{hx(s.height())}"
  }
}

///|
fn dintsize(s : IntSize?) -> String {
  match s {
    None => "None"
    Some(s) => "\{s.width()},\{s.height()}"
  }
}

///|
fn dts(t : Transform) -> String {
  "\{hx(t.sx)},\{hx(t.ky)},\{hx(t.kx)},\{hx(t.sy)},\{hx(t.tx)},\{hx(t.ty)}"
}

///|
fn dts_opt(t : Transform?) -> String {
  match t {
    None => "None"
    Some(t) => dts(t)
  }
}

///|
fn ts_of(s : String) -> Transform {
  let v : Array[Float] = []
  let mut b : UInt = 0
  for c in s + "," {
    if c == ',' {
      v.push(Float::reinterpret_from_uint(b))
      b = 0
    } else if c >= 'a' {
      b = b * 16 + (c.to_int() - 'a'.to_int() + 10).reinterpret_as_uint()
    } else {
      b = b * 16 + (c.to_int() - '0'.to_int()).reinterpret_as_uint()
    }
  }
  Transform::from_row(v[0], v[1], v[2], v[3], v[4], v[5])
}

///|
fn ddash(d : StrokeDash?) -> String {
  match d {
    None => "None"
    Some(d) => "\{hx(d.offset)},\{hx(d.first_len)},\{d.first_index}"
  }
}

///|
fn stroke_of(w : Float, ml : Float, cap : Int, join : Int) -> Stroke {
  {
    width: w,
    miter_limit: ml,
    line_cap: match cap {
      0 => Butt
      1 => Round
      _ => Square
    },
    line_join: match join {
      0 => Miter
      1 => MiterClip
      2 => Round
      _ => Bevel
    },
    dash: None,
  }
}

///|
fn dpath(p : Path?) -> String {
  match p {
    None => "None"
    Some(p) => {
      let s = StringBuilder()
      let iter = p.segments()
      while iter.next() is Some(seg) {
        match seg {
          MoveTo(a) => s.write_string("M \{dpt(a)} ")
          LineTo(a) => s.write_string("L \{dpt(a)} ")
          QuadTo(a, b) => s.write_string("Q \{dpt(a)} \{dpt(b)} ")
          CubicTo(a, b, c) => s.write_string("C \{dpt(a)} \{dpt(b)} \{dpt(c)} ")
          Close => s.write_string("Z ")
        }
      }
      s.write_string("| b " + drect(Some(p.bounds())))
      s.to_string()
    }
  }
}

///|
/// xorshift64* (mirrors `Rng` of the generator).
priv struct Rng {
  mut s : UInt64
}

///|
fn Rng::next(self : Rng) -> UInt {
  self.s = self.s ^ (self.s >> 12)
  self.s = self.s ^ (self.s << 25)
  self.s = self.s ^ (self.s >> 27)
  ((self.s * 0x2545F4914F6CDD1DUL) >> 32).to_uint()
}

///|
fn Rng::below(self : Rng, n : UInt) -> UInt {
  self.next() % n
}

///|
fn Rng::below_f(self : Rng, n : UInt) -> Float {
  Float::from_uint(self.below(n))
}

///|
fn Rng::coord(self : Rng, prev : (Float, Float)) -> (Float, Float) {
  match self.below(10) {
    0 => prev
    1 => (prev.0 + f(0x38D1B717U), prev.1) // 1e-4
    2 => {
      let x = prev.0 + self.below_f(1000) * f(0x3A83126FU) // 1e-3
      (x, prev.1 - 0.5)
    }
    3 | 4 => {
      let x = self.below_f(200) - 50.0
      let y = self.below_f(200) - 50.0
      (x, y)
    }
    _ => {
      let x = Float::from_uint(self.next()) / 4294967296.0 * 300.0 - 100.0
      let y = Float::from_uint(self.next()) / 4294967296.0 * 300.0 - 100.0
      (x, y)
    }
  }
}

///|
/// Returns `(stroke, res_scale)`.
fn Rng::stroke(self : Rng) -> (Stroke, Float) {
  let widths : Array[Float] = [0.1, 1.0, 2.5, 7.0, 15.0, 60.0]
  let miters : Array[Float] = [0.5, 1.0, 1.2, 2.0, 4.0, 30.0]
  let res : Array[Float] = [0.1, 1.0, 1.0, 3.0, 16.0]
  let w = widths[self.below(6).reinterpret_as_int()]
  let m = miters[self.below(6).reinterpret_as_int()]
  let cap = self.below(3).reinterpret_as_int()
  let join = self.below(4).reinterpret_as_int()
  let r = res[self.below(5).reinterpret_as_int()]
  (stroke_of(w, m, cap, join), r)
}

///|
fn random_path(rng : Rng) -> Path? {
  let pb = PathBuilder::new()
  let mut prev : (Float, Float) = (0.0, 0.0)
  let n = 2 + rng.below(7).reinterpret_as_int()
  for i in 0..<n {
    let kind = if i == 0 { 0 } else { rng.below(12).reinterpret_as_int() }
    match kind {
      0 => {
        prev = rng.coord(prev)
        pb.move_to(prev.0, prev.1)
      }
      1 | 2 | 3 => {
        prev = rng.coord(prev)
        pb.line_to(prev.0, prev.1)
      }
      4 | 5 | 6 => {
        let a = rng.coord(prev)
        prev = rng.coord(a)
        pb.quad_to(a.0, a.1, prev.0, prev.1)
      }
      7 | 8 | 9 | 10 => {
        let a = rng.coord(prev)
        let b = rng.coord(a)
        prev = rng.coord(b)
        pb.cubic_to(a.0, a.1, b.0, b.1, prev.0, prev.1)
      }
      _ => pb.close()
    }
  }
  pb.finish()
}

///|
/// Mirrors `bulk_fuzz` of the generator.
fn bulk_fuzz(seed : UInt64, n : Int) -> String {
  let rng = { s: seed, }
  let out = StringBuilder()
  let dash_vals : Array[Float] = [0.0, 0.5, 1.0, 3.0, 7.5, 20.0]
  let dash_offs : Array[Float] = [-5.0, 0.0, 2.5, 11.0]
  let ts_vals : Array[Float] = [-2.0, -0.5, 0.0, 0.3, 1.0, 1.5, 3.0]
  let ts_offs : Array[Float] = [-10.0, 0.0, 7.25]
  for _ in 0..<n {
    let path = random_path(rng)
    out.write_string(dg(dpath(path)))
    out.write_char('\n')
    guard path is Some(path) else { continue }
    out.write_string(drect(path.compute_tight_bounds()))
    out.write_char('\n')
    let (stroke, res) = rng.stroke()
    out.write_string(dg(dpath(path.stroke(stroke, res))))
    out.write_char('\n')
    let len = 2 + 2 * rng.below(2).reinterpret_as_int()
    let arr = Array::makei(len, fn(_) {
      dash_vals[rng.below(6).reinterpret_as_int()]
    })
    let off = dash_offs[rng.below(4).reinterpret_as_int()]
    if StrokeDash::new(arr, off) is Some(d) {
      let dashed = path.dash(d, res)
      out.write_string(dg(dpath(dashed)))
      out.write_char('\n')
      if dashed is Some(dashed) {
        out.write_string(dg(dpath(dashed.stroke(stroke, res))))
        out.write_char('\n')
      }
    }
    let v = Array::make(6, (0.0 : Float))
    for k in 0..<4 {
      v[k] = ts_vals[rng.below(7).reinterpret_as_int()]
    }
    v[4] = ts_offs[rng.below(3).reinterpret_as_int()]
    v[5] = ts_offs[rng.below(3).reinterpret_as_int()]
    let ts = Transform::from_row(v[0], v[1], v[2], v[3], v[4], v[5])
    let t = path.transform(ts)
    out.write_string(dg(dpath(t)))
    out.write_char('\n')
    out.write_string(drect(t.bind(fn(t) { t.compute_tight_bounds() })))
    out.write_char('\n')
    out.write_string(hx(PathStroker::compute_resolution_scale(ts)))
    out.write_char('\n')
  }
  out.to_string()
}
