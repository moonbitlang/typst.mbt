// Port of `moxcms::trc` (tone reproduction curves).

///|
pub(all) enum ToneReprCurve {
  /// Sampled curve (`u16` entries).
  Lut(FixedArray[Int])
  /// Parametric curve parameters.
  Parametric(FixedArray[Float])
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ToneReprCurve with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ToneReprCurve with @debug.Debug::{to_repr}

///|
let f_powf : (Float, Float) -> Float = @pxfm.f_powf

///|
priv struct ParametricCurve {
  g : Float
  a : Float
  b : Float
  c : Float
  d : Float
  e : Float
  f : Float
}

///|
fn ParametricCurve::new(params : FixedArray[Float]) -> ParametricCurve? {
  // convert from the variable number of parameters contained in profiles to a
  // unified representation.
  let g = params[0]
  match params.length() - 1 {
    0 => Some({ g, a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0, })
    2 => {
      let a = params[1]
      let b = params[2]
      Some({ g, a, b, c: 0.0, d: -b / a, e: 0.0, f: 0.0, })
    }
    3 => {
      let a = params[1]
      let b = params[2]
      let c = params[3]
      Some({ g, a, b, c: 0.0, d: -b / a, e: c, f: c, })
    }
    4 =>
      Some({
        g,
        a: params[1],
        b: params[2],
        c: params[3],
        d: params[4],
        e: 0.0,
        f: 0.0,
      })
    6 =>
      Some({
        g,
        a: params[1],
        b: params[2],
        c: params[3],
        d: params[4],
        e: params[5],
        f: params[6],
      })
    _ => None
  }
}

///|
fn ParametricCurve::is_linear(self : ParametricCurve) -> Bool {
  (self.g - 1.0).abs() < 1.0e-5 &&
  (self.a - 1.0).abs() < 1.0e-5 &&
  self.b.abs() < 1.0e-5 &&
  self.c.abs() < 1.0e-5
}

///|
fn ParametricCurve::eval(self : ParametricCurve, x : Float) -> Float {
  if x < self.d {
    self.c * x + self.f
  } else {
    f_powf(self.a * x + self.b, self.g) + self.e
  }
}

///|
fn is_finite_f32(x : Float) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
fn ParametricCurve::invert(self : ParametricCurve) -> ParametricCurve? {
  // First check if the function is continuous at the cross-over point d.
  let d1 = f_powf(self.a * self.d + self.b, self.g) + self.e
  let d2 = self.c * self.d + self.f
  if (d1 - d2).abs() > 0.1 {
    return None
  }
  let d = d1
  let one = Float::from_int(1)
  let a = one / f_powf(self.a, self.g)
  let b = -self.e / f_powf(self.a, self.g)
  let g = one / self.g
  let e = -self.b / self.a
  let (c, f) = if d <= 0.0 {
    (one, Float::from_int(0))
  } else {
    (one / self.c, -self.f / self.c)
  }
  // if self.d > 0. and self.c == 0 as is likely with type 1 and 2 parametric
  // function then c and f will not be finite.
  if !(is_finite_f32(g) &&
    is_finite_f32(a) &&
    is_finite_f32(b) &&
    is_finite_f32(c) &&
    is_finite_f32(d) &&
    is_finite_f32(e) &&
    is_finite_f32(f)) {
    return None
  }
  Some({ g, a, b, c, d, e, f, })
}

///|
fn u8_fixed_8number_to_float(x : Int) -> Float {
  // 0x0000 = 0.
  // 0x0100 = 1.
  // 0xffff = 255  + 255/256
  Float::from_double(x.to_double() / 256.0)
}

///|
fn passthrough_table(depth : Depth, n : Int) -> FixedArray[Float] {
  let gamma_table = FixedArray::make(n, Float::from_int(0))
  let max_value = if depth.finite {
    (1 << depth.bit_depth) - 1
  } else {
    not_finite_linear_table_size - 1
  }
  let cap_values = if depth.finite {
    1 << depth.bit_depth
  } else {
    not_finite_linear_table_size
  }
  guard cap_values <= n else { abort("Invalid lut table construction") }
  let scale_value = 1.0 / max_value.to_double()
  for i in 0..<cap_values {
    gamma_table[i] = Float::from_double(i.to_double() * scale_value)
  }
  gamma_table
}

///|
fn linear_forward_table(
  depth : Depth,
  n : Int,
  gamma : Int,
) -> FixedArray[Float] {
  let gamma_table = FixedArray::make(n, Float::from_int(0))
  let gamma_float = u8_fixed_8number_to_float(gamma)
  let max_value = if depth.finite {
    (1 << depth.bit_depth) - 1
  } else {
    not_finite_linear_table_size - 1
  }
  let cap_values = if depth.finite {
    1 << depth.bit_depth
  } else {
    not_finite_linear_table_size
  }
  guard cap_values <= n else { abort("Invalid lut table construction") }
  let scale_value = 1.0 / max_value.to_double()
  for i in 0..<cap_values {
    gamma_table[i] = Float::from_double(
      f_pow(i.to_double() * scale_value, gamma_float.to_double()),
    )
  }
  gamma_table
}

///|
fn lut_interp_linear_float(x : Float, table : ArrayView[Float]) -> Float {
  let value = @pxfm.max_f32(@pxfm.min_f32(x, 1.0), 0.0) *
    Float::from_int(table.length() - 1)
  let upper = @pxfm.f32_as_i32(value.ceil())
  let lower = @pxfm.f32_as_i32(value.floor())
  let diff = Float::from_int(upper) - value
  let tu = table[upper]
  mlaf(neg_mlaf(tu, tu, diff), table[lower], diff)
}

///|
fn lut_interp_linear(input_value : Double, table : FixedArray[Int]) -> Float {
  let mut input_value = input_value
  if table.length() == 0 {
    return Float::from_double(input_value)
  }
  input_value *= (table.length() - 1).to_double()
  let upper = @pxfm.f64_as_i32(input_value.ceil())
  let lower = @pxfm.f64_as_i32(input_value.floor())
  let clamp_idx = (i : Int) => {
    // `(i as usize).min(len - 1)`; a negative `i` wraps to a huge `usize`.
    if i < 0 || i > table.length() - 1 {
      table.length() - 1
    } else {
      i
    }
  }
  let w0 = table[clamp_idx(upper)].to_double()
  let w1 = 1.0 - (upper.to_double() - input_value)
  let w2 = table[clamp_idx(lower)].to_double()
  let w3 = upper.to_double() - input_value
  let value = Float::from_double(mlaf_d(w2 * w3, w0, w1))
  value * (Float::from_int(1) / 65535.0)
}

///|
fn linear_lut_interpolate(
  depth : Depth,
  n : Int,
  table : FixedArray[Int],
) -> FixedArray[Float] {
  let gamma_table = FixedArray::make(n, Float::from_int(0))
  let max_value = if depth.finite {
    (1 << depth.bit_depth) - 1
  } else {
    not_finite_linear_table_size - 1
  }
  let cap_values = if depth.finite {
    1 << depth.bit_depth
  } else {
    not_finite_linear_table_size
  }
  guard cap_values <= n else { abort("Invalid lut table construction") }
  let scale_value = 1.0 / max_value.to_double()
  for i in 0..<cap_values {
    gamma_table[i] = lut_interp_linear(i.to_double() * scale_value, table)
  }
  gamma_table
}

///|
fn m_clamp(a : Float, min : Float, max : Float) -> Float {
  if a > max {
    max
  } else if a >= min {
    a
  } else {
    // a < min or a is NaN
    min
  }
}

///|
fn linear_curve_parametric(
  depth : Depth,
  n : Int,
  params : FixedArray[Float],
) -> FixedArray[Float]? {
  guard ParametricCurve::new(params) is Some(params) else { return None }
  let gamma_table = FixedArray::make(n, Float::from_int(0))
  let max_value = if depth.finite {
    (1 << depth.bit_depth) - 1
  } else {
    not_finite_linear_table_size - 1
  }
  let cap_value = if depth.finite {
    1 << depth.bit_depth
  } else {
    not_finite_linear_table_size
  }
  let scale_value = Float::from_int(1) / Float::from_int(max_value)
  for i in 0..<@cmp.minimum(cap_value, n) {
    let x = Float::from_int(i) * scale_value
    gamma_table[i] = m_clamp(params.eval(x), 0.0, 1.0)
  }
  Some(gamma_table)
}

///|
fn linear_curve_parametric_s(
  n : Int,
  params : FixedArray[Float],
) -> FixedArray[Float]? {
  guard ParametricCurve::new(params) is Some(params) else { return None }
  let gamma_table = FixedArray::make(n, Float::from_int(0))
  let scale_value = Float::from_int(1) / Float::from_int(n - 1)
  for i in 0..<n {
    let x = Float::from_int(i) * scale_value
    gamma_table[i] = m_clamp(params.eval(x), 0.0, 1.0)
  }
  Some(gamma_table)
}

///|
fn make_gamma_linear_table(depth : Depth, n : Int) -> FixedArray[Float] {
  let table = FixedArray::make(65536, Float::from_int(0))
  let max_range = if depth.finite {
    Float::from_double(
      1.0 / ((n - 1).to_double() / (1 << depth.bit_depth).to_double()),
    )
  } else {
    Float::from_double(1.0 / (n - 1).to_double())
  }
  for v in 0..<n {
    if depth.finite {
      table[v] = depth.as_t(@pxfm.round_f32(Float::from_int(v) * max_range))
    } else {
      table[v] = Float::from_int(v) * max_range
    }
  }
  table
}

///|
/// `lut_interp_linear_gamma_impl` (integer path, finite types).
fn lut_interp_linear_gamma_impl(
  depth : Depth,
  n : Int,
  input_value : Int,
  table : FixedArray[Int],
) -> Float {
  // Start scaling input_value to the length of the array: GAMMA_CAP*(length-1).
  // We'll divide out the GAMMA_CAP next
  let mut value = input_value.reinterpret_as_uint() *
    (table.length() - 1).reinterpret_as_uint()
  let cap_value = (n - 1).reinterpret_as_uint()
  // equivalent to ceil(value/GAMMA_CAP)
  let upper = (value + cap_value - 1U) / cap_value
  // equivalent to floor(value/GAMMA_CAP)
  let lower = value / cap_value
  // interp is the distance from upper to value scaled to 0..GAMMA_CAP
  let interp = value % cap_value
  let lw_value = table[lower.reinterpret_as_int()].reinterpret_as_uint()
  let hw_value = table[upper.reinterpret_as_int()].reinterpret_as_uint()
  // the table values range from 0..65535
  value = mlaf_u32(hw_value * interp, lw_value, cap_value - interp)
  // round and scale
  let max_colors = (1 << depth.bit_depth) - 1
  let div = (n - 1) * 65535 / max_colors
  value += (div / 2).reinterpret_as_uint()
  value /= div.reinterpret_as_uint()
  // `u32 as u8` truncates.
  Float::from_uint(value & 0xffU)
}

///|
/// `lut_interp_linear_gamma_impl_f32` (float types).
fn lut_interp_linear_gamma_impl_f32(
  n : Int,
  input_value : Int,
  table : FixedArray[Int],
) -> Float {
  let guess = input_value.reinterpret_as_uint() *
    (table.length() - 1).reinterpret_as_uint()
  let cap_value = (n - 1).reinterpret_as_uint()
  let upper = (guess + cap_value - 1U) / cap_value
  let lower = guess / cap_value
  let interp = guess % cap_value
  let lw_value = table[lower.reinterpret_as_int()]
  let hw_value = table[upper.reinterpret_as_int()]
  let mut value = mlaf(
    Float::from_int(hw_value) * Float::from_uint(interp),
    Float::from_int(lw_value),
    Float::from_int(n - 1) - Float::from_uint(interp),
  )
  // max_colors = 1 for non finite types
  value /= Float::from_int((n - 1) * 65535)
  value
}

///|
fn make_gamma_lut(
  depth : Depth,
  n : Int,
  table : FixedArray[Int],
) -> FixedArray[Float] {
  let new_table = FixedArray::make(65536, Float::from_int(0))
  for v in 0..<n {
    new_table[v] = if depth.finite {
      lut_interp_linear_gamma_impl(depth, n, v, table)
    } else {
      lut_interp_linear_gamma_impl_f32(n, v, table)
    }
  }
  new_table
}

///|
fn lut_interp_linear16(input_value : Int, table : FixedArray[Int]) -> Int {
  // Start scaling input_value to the length of the array: 65535*(length-1).
  // We'll divide out the 65535 next
  let mut value = input_value.reinterpret_as_uint() *
    (table.length() - 1).reinterpret_as_uint()
  let upper = ((value + 65534U) / 65535U).reinterpret_as_int() & 0xffff // ceil
  let lower = (value / 65535U).reinterpret_as_int() & 0xffff // floor
  // interp is the distance from upper to value scaled to 0..65535
  let interp = value % 65535U
  value = (
      table[upper].reinterpret_as_uint() * interp +
      table[lower].reinterpret_as_uint() * (65535U - interp)
    ) /
    65535U
  value.reinterpret_as_int() & 0xffff
}

///|
fn make_gamma_pow_table(
  depth : Depth,
  n : Int,
  gamma : Float,
) -> FixedArray[Float] {
  let table = FixedArray::make(65536, Float::from_int(0))
  let scale = Float::from_int(1) / Float::from_int(n - 1)
  let cap = Float::from_int((1 << depth.bit_depth) - 1)
  if depth.finite {
    for v in 0..<n {
      table[v] = depth.as_t(
        @pxfm.round_f32(cap * f_powf(Float::from_int(v) * scale, gamma)),
      )
    }
  } else {
    for v in 0..<n {
      table[v] = cap * f_powf(Float::from_int(v) * scale, gamma)
    }
  }
  table
}

///|
fn make_gamma_parametric_table(
  depth : Depth,
  n : Int,
  parametric_curve : ParametricCurve,
) -> FixedArray[Float] {
  let table = FixedArray::make(65536, Float::from_int(0))
  let scale = Float::from_int(1) / Float::from_int(n - 1)
  let cap = Float::from_int((1 << depth.bit_depth) - 1)
  if depth.finite {
    for v in 0..<n {
      table[v] = depth.as_t(
        @pxfm.round_f32(cap * parametric_curve.eval(Float::from_int(v) * scale)),
      )
    }
  } else {
    for v in 0..<n {
      table[v] = cap * parametric_curve.eval(Float::from_int(v) * scale)
    }
  }
  table
}

///|
fn compare_parametric(src : ArrayView[Float], dst : ArrayView[Float]) -> Bool {
  let n = @cmp.minimum(src.length(), dst.length())
  for i in 0..<n {
    if (src[i] - dst[i]).abs() > 1.0e-4 {
      return false
    }
  }
  true
}

///|
fn lut_inverse_interp16(value : Int, lut_table : FixedArray[Int]) -> Int {
  let mut l = 1 // 'int' Give spacing for negative values
  let mut r = 0x10000
  let mut x = 0
  let length = lut_table.length()
  let mut num_zeroes = 0
  for item in lut_table {
    if item == 0 {
      num_zeroes += 1
    } else {
      break
    }
  }
  if num_zeroes == 0 && value == 0 {
    return 0
  }
  let mut num_of_polys = 0
  for i = length - 1; i >= 0; i = i - 1 {
    if lut_table[i] == 0xffff {
      num_of_polys += 1
    } else {
      break
    }
  }
  // Does the curve belong to this case?
  if num_zeroes > 1 || num_of_polys > 1 {
    // Identify if value fall downto 0 or FFFF zone
    if value == 0 {
      return 0
    }
    // else restrict to valid zone
    if num_zeroes > 1 {
      let a_0 = (num_zeroes - 1) * 0xffff / (length - 1)
      l = a_0 - 1
    }
    if num_of_polys > 1 {
      let b_0 = (length - 1 - num_of_polys) * 0xffff / (length - 1)
      r = b_0 + 1
    }
  }
  if r <= l {
    // If this happens LutTable is not invertible
    return 0
  }
  while r > l {
    x = (l + r) / 2
    let res = lut_interp_linear16((x - 1) & 0xffff, lut_table)
    if res == value {
      // Found exact match.
      return (x - 1) & 0xffff
    }
    if res > value {
      r = x - 1
    } else {
      l = x + 1
    }
  }
  // Not found, should we interpolate?
  // Get surrounding nodes
  let val2 = (length - 1).to_double() * ((x - 1).to_double() / 65535.0)
  let cell0 = @pxfm.f64_as_i32(val2.floor())
  let cell1 = @pxfm.f64_as_i32(val2.ceil())
  if cell0 == cell1 {
    return x & 0xffff
  }
  let y0 = lut_table[cell0].to_double()
  let x0 = 65535.0 * cell0.to_double() / (length - 1).to_double()
  let y1 = lut_table[cell1].to_double()
  let x1 = 65535.0 * cell1.to_double() / (length - 1).to_double()
  let a = (y1 - y0) / (x1 - x0)
  let b = mlaf_d(y0, -a, x0)
  if a.abs() < 0.01 {
    return x & 0xffff
  }
  let f = (value.to_double() - b) / a
  if f < 0.0 {
    return 0
  }
  if f >= 65535.0 {
    return 0xffff
  }
  @pxfm.f64_as_u16((f + 0.5).floor())
}

///|
fn invert_lut(table : FixedArray[Int], out_length : Int) -> FixedArray[Int] {
  // For now, we invert the lut by creating a lut of size out_length and
  // attempting to look up a value for each entry using lut_inverse_interp16
  let output = FixedArray::make(out_length, 0)
  let scale_value = 65535.0 / (out_length - 1).to_double()
  for i in 0..<out_length {
    let x = i.to_double() * scale_value
    let input = @pxfm.f64_as_u16((x + 0.5).floor())
    output[i] = lut_inverse_interp16(input, table)
  }
  output
}

///|
fn ToneReprCurve::build_linearize_table(
  self : ToneReprCurve,
  depth : Depth,
  n : Int,
) -> FixedArray[Float]? {
  match self {
    Parametric(params) => linear_curve_parametric(depth, n, params)
    Lut(data) =>
      match data.length() {
        0 => Some(passthrough_table(depth, n))
        1 => Some(linear_forward_table(depth, n, data[0]))
        _ => Some(linear_lut_interpolate(depth, n, data))
      }
  }
}

///|
fn srgb_parametric() -> FixedArray[Float] {
  let one = Float::from_int(1)
  [
    Float::from_double(2.4),
    one / Float::from_double(1.055),
    Float::from_double(0.055) / Float::from_double(1.055),
    one / Float::from_double(12.92),
    Float::from_double(0.04045),
  ]
}

///|
fn ToneReprCurve::build_gamma_table(
  self : ToneReprCurve,
  depth : Depth,
  n : Int,
) -> FixedArray[Float]? {
  match self {
    Parametric(params) => {
      if params.length() == 5 {
        let srgb_params = srgb_parametric()
        let rec709_params = create_rec709_parametric()
        let lc_params = FixedArray::make(5, Float::from_int(0))
        for i in 0..<5 {
          lc_params[i] = params[i]
        }
        if compare_parametric(lc_params[:], srgb_params[:]) {
          return Some(TransferCharacteristics::Srgb.make_gamma_table(depth, n))
        }
        if compare_parametric(lc_params[:], rec709_params[:]) {
          return Some(TransferCharacteristics::Bt709.make_gamma_table(depth, n))
        }
      }
      guard ParametricCurve::new(params) is Some(parametric_curve) else {
        return None
      }
      if parametric_curve.invert() is Some(x) {
        return Some(make_gamma_parametric_table(depth, n, x))
      }
      let gamma_table_uint = FixedArray::make(n, 0)
      let inverted_size = n
      guard linear_curve_parametric_s(n, params) is Some(gamma_table) else {
        return None
      }
      for i in 0..<n {
        gamma_table_uint[i] = @pxfm.f32_as_u16(gamma_table[i] * 65535.0)
      }
      let inverted = invert_lut(gamma_table_uint, inverted_size)
      Some(make_gamma_lut(depth, n, inverted))
    }
    Lut(data) =>
      match data.length() {
        0 => Some(make_gamma_linear_table(depth, n))
        1 =>
          Some(
            make_gamma_pow_table(
              depth,
              n,
              Float::from_int(1) / u8_fixed_8number_to_float(data[0]),
            ),
          )
        _ => {
          let mut inverted_size = data.length()
          if inverted_size < 256 {
            inverted_size = 256
          }
          let inverted = invert_lut(data, inverted_size)
          Some(make_gamma_lut(depth, n, inverted))
        }
      }
  }
}

///|
/// Produces LUT for Gray transfer curve.
fn ColorProfile::build_gray_linearize_table(
  self : ColorProfile,
  depth : Depth,
  n : Int,
) -> FixedArray[Float] raise CmsError {
  guard self.gray_trc is Some(trc) else { raise BuildTransferFunction }
  guard trc.build_linearize_table(depth, n) is Some(t) else {
    raise BuildTransferFunction
  }
  t
}

///|
fn ColorProfile::build_linearize_table_for(
  self : ColorProfile,
  trc : ToneReprCurve?,
  depth : Depth,
  n : Int,
  use_cicp : Bool,
) -> FixedArray[Float] raise CmsError {
  if use_cicp {
    if self.cicp is Some(c) {
      let tc = c.transfer_characteristics
      if tc.has_transfer_curve() {
        return tc.make_linear_table(depth, n)
      }
    }
  }
  guard trc is Some(trc) else { raise BuildTransferFunction }
  guard trc.build_linearize_table(depth, n) is Some(t) else {
    raise BuildTransferFunction
  }
  t
}

///|
/// Produces LUT for Red transfer curve.
fn ColorProfile::build_r_linearize_table(
  self : ColorProfile,
  depth : Depth,
  n : Int,
  use_cicp : Bool,
) -> FixedArray[Float] raise CmsError {
  self.build_linearize_table_for(self.red_trc, depth, n, use_cicp)
}

///|
/// Produces LUT for Green transfer curve.
fn ColorProfile::build_g_linearize_table(
  self : ColorProfile,
  depth : Depth,
  n : Int,
  use_cicp : Bool,
) -> FixedArray[Float] raise CmsError {
  self.build_linearize_table_for(self.green_trc, depth, n, use_cicp)
}

///|
/// Produces LUT for Blue transfer curve.
fn ColorProfile::build_b_linearize_table(
  self : ColorProfile,
  depth : Depth,
  n : Int,
  use_cicp : Bool,
) -> FixedArray[Float] raise CmsError {
  self.build_linearize_table_for(self.blue_trc, depth, n, use_cicp)
}

///|
/// Builds gamma table checking CICP for Transfer characteristics first.
fn ColorProfile::build_gamma_table(
  self : ColorProfile,
  trc : ToneReprCurve?,
  depth : Depth,
  n : Int,
  use_cicp : Bool,
) -> FixedArray[Float] raise CmsError {
  if use_cicp {
    if self.cicp is Some(c) {
      let tc = c.transfer_characteristics
      if tc.has_transfer_curve() {
        return tc.make_gamma_table(depth, n)
      }
    }
  }
  guard trc is Some(trc) else { raise BuildTransferFunction }
  guard trc.build_gamma_table(depth, n) is Some(t) else {
    raise BuildTransferFunction
  }
  t
}

///|
/// Check if all TRC are the same.
fn ColorProfile::are_all_trc_the_same(self : ColorProfile) -> Bool {
  if self.color_space == Gray {
    return true
  }
  if (self.red_trc, self.green_trc, self.blue_trc)
    is (Some(red_trc), Some(green_trc), Some(blue_trc)) {
    match (red_trc, green_trc, blue_trc) {
      (Lut(lut0), Lut(lut1), Lut(lut2)) =>
        if lut0 == lut1 || lut1 == lut2 {
          return true
        }
      (Parametric(lut0), Parametric(lut1), Parametric(lut2)) =>
        if lut0 == lut1 || lut1 == lut2 {
          return true
        }
      _ => return false
    }
  }
  false
}

///|
/// Checks if profile is matrix shaper, have same TRC and TRC is linear.
fn ColorProfile::is_linear_matrix_shaper(self : ColorProfile) -> Bool {
  if !self.is_matrix_shaper() {
    return false
  }
  if !self.are_all_trc_the_same() {
    return false
  }
  if self.red_trc is Some(red_trc) {
    return match red_trc {
      Lut(lut) => {
        if lut.length() == 0 {
          return true
        }
        if is_curve_linear16(lut) {
          return true
        }
        false
      }
      Parametric(params) =>
        if ParametricCurve::new(params) is Some(curve) {
          curve.is_linear()
        } else {
          false
        }
    }
  }
  false
}

///|
/// `helpers::ToneReprCurve::is_linear`.
fn ToneReprCurve::is_linear(self : ToneReprCurve) -> Bool {
  match self {
    Lut(lut) => {
      if lut.length() == 0 {
        return true
      }
      if lut.length() == 1 {
        let gamma = Float::from_int(1) / u8_fixed_8number_to_float(lut[0])
        if (gamma - 1.0).abs() < 1.0e-4 {
          return true
        }
      }
      is_curve_linear16(lut)
    }
    Parametric(parametric) => {
      if parametric.length() == 0 {
        return true
      }
      if parametric.length() == 1 && parametric[0] == 1.0 {
        return true
      }
      false
    }
  }
}

///|
/// `matan::is_curve_linear16`.
fn is_curve_linear16(curve : FixedArray[Int]) -> Bool {
  let scale = Float::from_int(1) / Float::from_int(curve.length() - 1) * 65535.0
  for index, value in curve {
    let quantized = @pxfm.f32_as_u16(
      @pxfm.round_f32(Float::from_int(index) * scale),
    )
    let diff = (quantized - value).abs()
    if diff > 0x0f {
      return false
    }
  }
  true
}
