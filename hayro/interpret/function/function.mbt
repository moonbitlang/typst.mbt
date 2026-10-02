// Port of `hayro-interpret/src/function/mod.rs`.
//
// PDF functions.
//
// PDF has the concept of functions, representing objects that take a certain
// number of values as input, do some processing on them and then return some
// output.

///|
priv enum FunctionType {
  Type0(Type0)
  Type2(Type2)
  Type3(Type3)
  Type4(Type4)
}

///|
/// A PDF function.
pub struct Function {
  priv inner : FunctionType
}

///|
/// Create a new function.
pub fn Function::new(obj : @hayro_syntax.Object) -> Function? {
  guard @hayro_syntax.dict_or_stream(obj) is Some((dict, stream)) else {
    return None
  }
  guard (dict.get("FunctionType") : Byte?) is Some(function_type) else {
    return None
  }
  let function_type = match function_type {
    0 => {
      guard stream is Some(stream) else { return None }
      guard Type0::new(stream) is Some(t) else { return None }
      Type0(t)
    }
    2 => {
      guard Type2::new(dict) is Some(t) else { return None }
      Type2(t)
    }
    3 => {
      guard Type3::new(dict) is Some(t) else { return None }
      Type3(t)
    }
    4 => {
      guard stream is Some(stream) else { return None }
      guard Type4::new(stream) is Some(t) else { return None }
      Type4(t)
    }
    _ => return None
  }
  Some({ inner: function_type, })
}

///|
/// Evaluate the function with the given input.
pub fn Function::eval(self : Function, input : Array[Float]) -> Array[Float]? {
  match self.inner {
    Type0(t0) => t0.eval(input.copy())
    Type2(t2) => {
      guard input.get(0) is Some(x) else { return None }
      Some(t2.eval(x))
    }
    Type3(t3) => {
      guard input.get(0) is Some(x) else { return None }
      t3.eval(x)
    }
    Type4(t4) => t4.eval(input.copy())
  }
}

///|
/// The bounds at which a (stitching) function's output may change abruptly.
pub fn Function::stitching_bounds(self : Function) -> Array[Float] {
  match self.inner {
    Type3(t3) => t3.stitching_bounds()
    _ => []
  }
}

///|
priv struct Clamper {
  domain : Array[(Float, Float)]
  range : Array[(Float, Float)]?
}

///|
fn Clamper::new(dict : @hayro_syntax.Dict) -> Clamper? {
  guard get_tuple_vec(dict, "Domain") is Some(domain) else { return None }
  let range = get_tuple_vec(dict, "Range")
  Some({ domain, range, })
}

///|
fn Clamper::clamp_input(self : Clamper, input : Array[Float]) -> Unit {
  // (A warning is logged upstream if the domain doesn't match the input.)
  let n = @cmp.minimum(self.domain.length(), input.length())
  for i in 0..<n {
    let (min, max) = self.domain[i]
    input[i] = f32_max(f32_min(input[i], max), min)
  }
}

///|
fn Clamper::clamp_output(self : Clamper, output : Array[Float]) -> Unit {
  if self.range is Some(range) {
    // (A warning is logged upstream if the range doesn't match the output.)
    let n = @cmp.minimum(range.length(), output.length())
    for i in 0..<n {
      let (min, max) = range[i]
      output[i] = f32_max(f32_min(output[i], max), min)
    }
  }
}

///|
/// Linearly interpolate the value `x`, assuming that it lies within the range
/// `x_min` and `x_max`, to the range `y_min` and `y_max`.
pub fn interpolate(
  x : Float,
  x_min : Float,
  x_max : Float,
  y_min : Float,
  y_max : Float,
) -> Float {
  y_min + (x - x_min) * (y_max - y_min) / (x_max - x_min)
}

// Reading of `SmallVec<[(f32, f32); 4]>` (upstream `TupleVec`) and
// `SmallVec<[f32; 4]>` (upstream `Values`) from dictionaries, with the
// semantics of hayro-syntax: the entry is read as an array, and its items are
// collected until the first one that can't be read as the item type. Tuples
// are read as consecutive (possibly indirect) objects.

///|
priv struct F32Pair((Float, Float))

///|
impl @hayro_syntax.Readable for F32Pair with fn read(r, ctx) {
  r.skip_white_spaces_and_comments()
  guard (r.read(ctx) : @hayro_syntax.MaybeRef[Float]?) is Some(t) else {
    return None
  }
  guard t.resolve(ctx) is Some(t) else { return None }
  r.skip_white_spaces_and_comments()
  guard (r.read(ctx) : @hayro_syntax.MaybeRef[Float]?) is Some(u) else {
    return None
  }
  guard u.resolve(ctx) is Some(u) else { return None }
  Some(F32Pair((t, u)))
}

///|
impl @hayro_syntax.ObjectLike for F32Pair with fn from_object(_) {
  None
}

///|
/// `dict.get::<TupleVec>(key)`.
fn get_tuple_vec(
  dict : @hayro_syntax.Dict,
  key : String,
) -> Array[(Float, Float)]? {
  guard (dict.get(key) : @hayro_syntax.Vector[F32Pair]?) is Some(Vector(v)) else {
    return None
  }
  Some(v.map(p => p.0))
}

///|
/// `dict.get::<Values>(key)`.
fn get_values(dict : @hayro_syntax.Dict, key : String) -> Array[Float]? {
  guard (dict.get(key) : @hayro_syntax.Vector[Float]?) is Some(Vector(v)) else {
    return None
  }
  Some(v)
}

// Rust float semantics.

///|
/// `f32::min` (IEEE `minNum`, as compiled for aarch64: NaN is ignored and
/// `-0.0 < +0.0`).
fn f32_min(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_uint() >> 31 == 1U {
    a
  } else {
    b
  }
}

///|
/// `f32::max` (IEEE `maxNum`, as compiled for aarch64: NaN is ignored and
/// `-0.0 < +0.0`).
fn f32_max(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_uint() >> 31 == 0U {
    a
  } else {
    b
  }
}

///|
/// Rust's saturating `f32 as i32`.
fn f32_to_i32(v : Float) -> Int {
  let d = v.to_double()
  if d.is_nan() {
    0
  } else if d >= 2147483647.0 {
    2147483647
  } else if d <= -2147483648.0 {
    -2147483648
  } else {
    d.to_int()
  }
}

///|
/// Rust's saturating `f32 as u32`.
fn f32_to_u32(v : Float) -> UInt {
  let d = v.to_double()
  if d.is_nan() || d <= 0.0 {
    0
  } else if d >= 4294967295.0 {
    4294967295
  } else {
    d.to_uint64().to_uint()
  }
}

///|
/// `f32::round` (half away from zero).
fn f32_round(x : Float) -> Float {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let t = x.trunc()
  let diff = x - t
  if diff >= 0.5 {
    t + 1.0
  } else if diff <= -0.5 {
    t - 1.0
  } else {
    t
  }
}

///|
/// `f32::to_degrees`.
fn f32_to_degrees(x : Float) -> Float {
  // Use a literal for better precision.
  let pis_in_180 : Float = 57.2957795130823208767981548141051703
  x * pis_in_180
}

///|
/// `f32::to_radians`.
fn f32_to_radians(x : Float) -> Float {
  let pi : Float = 3.14159265358979323846264338327950288
  let rads_per_deg = pi / 180.0
  x * rads_per_deg
}
