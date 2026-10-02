// Port of `moxcms::gamma` (CICP transfer functions and their tables).
//
// Deviation: the logarithmic / HLG transfer functions use `@math`'s
// `log10`/`exp`/`ln` instead of the correctly rounded `pxfm` versions (they are
// only reached for profiles with such a CICP tag).

///|
let f_pow : (Double, Double) -> Double = @pxfm.f_pow

///|
/// Linear transfer function for sRGB.
fn srgb_to_linear(gamma : Double) -> Double {
  if gamma < 0.0 {
    0.0
  } else if gamma < 12.92 * 0.0030412825601275209 {
    gamma * (1.0 / 12.92)
  } else if gamma < 1.0 {
    f_pow((gamma + 0.0550107189475866) / 1.0550107189475866, 2.4)
  } else {
    1.0
  }
}

///|
/// Gamma transfer function for sRGB.
fn srgb_from_linear(linear : Double) -> Double {
  if linear < 0.0 {
    0.0
  } else if linear < 0.0030412825601275209 {
    linear * 12.92
  } else if linear < 1.0 {
    fmla_d(1.0550107189475866, f_pow(linear, 1.0 / 2.4), -0.0550107189475866)
  } else {
    1.0
  }
}

///|
/// Linear transfer function for Rec.709.
fn rec709_to_linear(gamma : Double) -> Double {
  if gamma < 0.0 {
    0.0
  } else if gamma < 4.5 * 0.018053968510807 {
    gamma * (1.0 / 4.5)
  } else if gamma < 1.0 {
    f_pow((gamma + 0.09929682680944) / 1.09929682680944, 1.0 / 0.45)
  } else {
    1.0
  }
}

///|
/// Gamma transfer function for Rec.709.
fn rec709_from_linear(linear : Double) -> Double {
  if linear < 0.0 {
    0.0
  } else if linear < 0.018053968510807 {
    linear * 4.5
  } else if linear < 1.0 {
    fmla_d(1.09929682680944, f_pow(linear, 0.45), -0.09929682680944)
  } else {
    1.0
  }
}

///|
/// Linear transfer function for Smpte 428.
fn smpte428_to_linear(gamma : Double) -> Double {
  let scale = 1.0 / 0.91655527974030934
  f_pow(@pxfm.min_f64(@pxfm.max_f64(gamma, 0.0), 1.0), 2.6) * scale
}

///|
/// Gamma transfer function for Smpte 428.
fn smpte428_from_linear(linear : Double) -> Double {
  let power_value = 1.0 / 2.6
  f_pow(0.91655527974030934 * @pxfm.max_f64(linear, 0.0), power_value)
}

///|
/// Linear transfer function for Smpte 240.
fn smpte240_to_linear(gamma : Double) -> Double {
  if gamma < 0.0 {
    0.0
  } else if gamma < 4.0 * 0.022821585529445 {
    gamma / 4.0
  } else if gamma < 1.0 {
    f_pow((gamma + 0.111572195921731) / 1.111572195921731, 1.0 / 0.45)
  } else {
    1.0
  }
}

///|
/// Gamma transfer function for Smpte 240.
fn smpte240_from_linear(linear : Double) -> Double {
  if linear < 0.0 {
    0.0
  } else if linear < 0.022821585529445 {
    linear * 4.0
  } else if linear < 1.0 {
    fmla_d(1.111572195921731, f_pow(linear, 0.45), -0.111572195921731)
  } else {
    1.0
  }
}

///|
/// Gamma transfer function for Log100.
fn log100_from_linear(linear : Double) -> Double {
  if linear <= 0.01 {
    0.0
  } else {
    1.0 + @math.log10(@pxfm.min_f64(linear, 1.0)) / 2.0
  }
}

///|
/// Linear transfer function for Log100.
fn log100_to_linear(gamma : Double) -> Double {
  // The function is non-bijective so choose the middle of [0, 0.00316227766f].
  let mid_interval = 0.01 / 2.0
  if gamma <= 0.0 {
    mid_interval
  } else {
    @math.pow(10.0, 2.0 * (@pxfm.min_f64(gamma, 1.0) - 1.0))
  }
}

///|
/// Linear transfer function for Log100Sqrt10.
fn log100_sqrt10_to_linear(gamma : Double) -> Double {
  let mid_interval = 0.00316227766 / 2.0
  if gamma <= 0.0 {
    mid_interval
  } else {
    @math.pow(10.0, 2.5 * (@pxfm.min_f64(gamma, 1.0) - 1.0))
  }
}

///|
/// Gamma transfer function for Log100Sqrt10.
fn log100_sqrt10_from_linear(linear : Double) -> Double {
  if linear <= 0.00316227766 {
    0.0
  } else {
    1.0 + @math.log10(@pxfm.min_f64(linear, 1.0)) / 2.5
  }
}

///|
/// Gamma transfer function for Bt.1361.
fn bt1361_from_linear(linear : Double) -> Double {
  if linear < -0.25 {
    -0.25
  } else if linear < 0.0 {
    fmla_d(-0.27482420670236, f_pow(-4.0 * linear, 0.45), 0.02482420670236)
  } else if linear < 0.018053968510807 {
    linear * 4.5
  } else if linear < 1.0 {
    fmla_d(1.09929682680944, f_pow(linear, 0.45), -0.09929682680944)
  } else {
    1.0
  }
}

///|
/// Linear transfer function for Bt.1361.
fn bt1361_to_linear(gamma : Double) -> Double {
  if gamma < -0.25 {
    -0.25
  } else if gamma < 0.0 {
    f_pow((gamma - 0.02482420670236) / -0.27482420670236, 1.0 / 0.45) / -4.0
  } else if gamma < 4.5 * 0.018053968510807 {
    gamma / 4.5
  } else if gamma < 1.0 {
    f_pow((gamma + 0.09929682680944) / 1.09929682680944, 1.0 / 0.45)
  } else {
    1.0
  }
}

///|
/// Pure gamma transfer function.
fn pure_gamma_function(x : Double, gamma : Double) -> Double {
  if x <= 0.0 {
    0.0
  } else if x >= 1.0 {
    1.0
  } else {
    f_pow(x, gamma)
  }
}

///|
fn iec61966_to_linear(gamma : Double) -> Double {
  if gamma < -4.5 * 0.018053968510807 {
    f_pow((-gamma + 0.09929682680944) / -1.09929682680944, 1.0 / 0.45)
  } else if gamma < 4.5 * 0.018053968510807 {
    gamma / 4.5
  } else {
    f_pow((gamma + 0.09929682680944) / 1.09929682680944, 1.0 / 0.45)
  }
}

///|
fn iec61966_from_linear(v : Double) -> Double {
  if v < -0.018053968510807 {
    fmla_d(-1.09929682680944, f_pow(-v, 0.45), 0.09929682680944)
  } else if v < 0.018053968510807 {
    v * 4.5
  } else {
    fmla_d(1.09929682680944, f_pow(v, 0.45), -0.09929682680944)
  }
}

///|
/// Linear transfer function for PQ.
fn pq_to_linear(gamma : Double) -> Double {
  if gamma > 0.0 {
    let pow_gamma = f_pow(gamma, 1.0 / 78.84375)
    let num = @pxfm.max_f64(pow_gamma - 0.8359375, 0.0)
    let den = @pxfm.max_f64(
      mlaf_d(18.8515625, -18.6875, pow_gamma),
      -1.7976931348623157e308,
    )
    f_pow(num / den, 1.0 / 0.1593017578125)
  } else {
    0.0
  }
}

///|
/// Gamma transfer function for PQ.
fn pq_from_linear(linear : Double) -> Double {
  if linear > 0.0 {
    let linear = linear.clamp(min=0.0, max=1.0)
    let pow_linear = f_pow(linear, 0.1593017578125)
    let num = fmla_d(0.1640625, pow_linear, -0.1640625)
    let den = mlaf_d(1.0, 18.6875, pow_linear)
    f_pow(1.0 + num / den, 78.84375)
  } else {
    0.0
  }
}

///|
/// Linear transfer function for HLG.
fn hlg_to_linear(gamma : Double) -> Double {
  if gamma < 0.0 {
    return 0.0
  }
  if gamma <= 0.5 {
    f_pow(gamma * gamma * (1.0 / 3.0), 1.2)
  } else {
    f_pow(
      (@math.exp((gamma - 0.55991073) / 0.17883277) + 0.28466892) / 12.0,
      1.2,
    )
  }
}

///|
/// Gamma transfer function for HLG.
fn hlg_from_linear(linear : Double) -> Double {
  // Scale from extended SDR range to [0.0, 1.0].
  let mut linear = linear.clamp(min=0.0, max=1.0)
  // Inverse OOTF followed by OETF.
  linear = f_pow(linear, 1.0 / 1.2)
  if linear < 0.0 {
    0.0
  } else if linear <= 1.0 / 12.0 {
    (3.0 * linear).sqrt()
  } else {
    fmla_d(0.17883277, @math.ln(fmla_d(12.0, linear, -0.28466892)), 0.55991073)
  }
}

///|
fn trc_linear(v : Double) -> Double {
  @pxfm.max_f64(@pxfm.min_f64(v, 1.0), 0.0)
}

///|
fn TransferCharacteristics::linearize(
  self : TransferCharacteristics,
  v : Double,
) -> Double {
  match self {
    Reserved => 0.0
    Bt709 | Bt601 | Bt202010bit | Bt202012bit => rec709_to_linear(v)
    Unspecified => 0.0
    Bt470M => pure_gamma_function(v, 2.2)
    Bt470Bg => pure_gamma_function(v, 2.8)
    Smpte240 => smpte240_to_linear(v)
    Linear => trc_linear(v)
    Log100 => log100_to_linear(v)
    Log100sqrt10 => log100_sqrt10_to_linear(v)
    Iec61966 => iec61966_to_linear(v)
    Bt1361 => bt1361_to_linear(v)
    Srgb => srgb_to_linear(v)
    Smpte2084 => pq_to_linear(v)
    Smpte428 => smpte428_to_linear(v)
    Hlg => hlg_to_linear(v)
  }
}

///|
fn TransferCharacteristics::gamma(
  self : TransferCharacteristics,
  v : Double,
) -> Double {
  match self {
    Reserved => 0.0
    Bt709 | Bt601 | Bt202010bit | Bt202012bit => rec709_from_linear(v)
    Unspecified => 0.0
    Bt470M => pure_gamma_function(v, 1.0 / 2.2)
    Bt470Bg => pure_gamma_function(v, 1.0 / 2.8)
    Smpte240 => smpte240_from_linear(v)
    Linear => trc_linear(v)
    Log100 => log100_from_linear(v)
    Log100sqrt10 => log100_sqrt10_from_linear(v)
    Iec61966 => iec61966_from_linear(v)
    Bt1361 => bt1361_from_linear(v)
    Srgb => srgb_from_linear(v)
    Smpte2084 => pq_from_linear(v)
    Smpte428 => smpte428_from_linear(v)
    Hlg => hlg_from_linear(v)
  }
}

///|
fn TransferCharacteristics::make_linear_table(
  self : TransferCharacteristics,
  depth : Depth,
  n : Int,
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
    gamma_table[i] = Float::from_double(
      self.linearize(i.to_double() * scale_value),
    )
  }
  gamma_table
}

///|
fn TransferCharacteristics::make_gamma_table(
  self : TransferCharacteristics,
  depth : Depth,
  n : Int,
) -> FixedArray[Float] {
  let table = FixedArray::make(65536, Float::from_int(0))
  let max_range = 1.0 / (n - 1).to_double()
  let max_value = ((1 << depth.bit_depth) - 1).to_double()
  if depth.finite {
    for v in 0..<n {
      table[v] = depth.as_t(
        @pxfm.round_f32(
          Float::from_double(self.gamma(v.to_double() * max_range) * max_value),
        ),
      )
    }
  } else {
    for v in 0..<n {
      table[v] = Float::from_double(self.gamma(v.to_double() * max_range))
    }
  }
  table
}
