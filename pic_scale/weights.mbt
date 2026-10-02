// Port of pic-scale's `math/weights.rs` (`generate_weights::<f32, f64>`, as
// `WeightsGenerator<f32> for u8` calls it) and of the Catmull-Rom kernel of
// `math/bc_spline.rs`, the only filter hayro uses.
//
// `T = f32` arithmetic is done in MoonBit `Float`, `W = f64` in `Double`.
// The MoonBit C backend emits one C statement per operation, so nothing is
// contracted into an FMA (see `contraction_test.mbt`); Rust does not fuse
// either unless `mul_add` is called.

///|
/// `f32::floor` (exact through `f64`).
fn floor_f32(x : Float) -> Float {
  Float::from_double(x.to_double().floor())
}

///|
/// `f32::ceil` (exact through `f64`).
fn ceil_f32(x : Float) -> Float {
  Float::from_double(x.to_double().ceil())
}

///|
/// `f32::round` (half away from zero; exact through `f64`).
fn round_f32(x : Float) -> Float {
  Float::from_double(round_f64(x.to_double()))
}

///|
/// `f32::min` (no NaNs occur here).
fn min_f32(a : Float, b : Float) -> Float {
  if b < a {
    b
  } else {
    a
  }
}

///|
/// `f32::max` (no NaNs occur here).
fn max_f32(a : Float, b : Float) -> Float {
  if b > a {
    b
  } else {
    a
  }
}

///|
/// `f32 as usize` (saturating; the values here are non-negative).
fn f32_to_usize(x : Float) -> Int {
  if x <= 0.0 {
    0
  } else {
    x.to_double().to_int()
  }
}

///|
/// `bc_spline(d, b = 0, c = 0.5)` (`catmull_rom`). The polynomial
/// coefficients are `mla` (= `mul_add` on aarch64) of exact constants, so
/// they are exact: `mla(-6, c, mla(-9, b, 12)) = 9`, `mla(6, c, mla(12, b,
/// -18)) = -15`, `mla(-2, b, 6) = 6`; `mla(-6, c, -b) = -3`, `mla(6, b,
/// 30 * c) = 15`, `mla(-12, b, -48 * c) = -24`, `mla(8, b, 24 * c) = 12`.
fn catmull_rom(d : Float) -> Float {
  let mut x = d
  if x < 0.0 {
    x = -x
  }
  let dp = x * x
  let tp = dp * x
  let one_sixth : Float = Float::from_int(1) / Float::from_int(6)
  if x < 1.0 {
    let a = Float::from_int(9) * tp
    let b = Float::from_int(-15) * dp
    let s = a + b
    let s = s + Float::from_int(6)
    return s * one_sixth
  } else if x < 2.0 {
    let a = Float::from_int(-3) * tp
    let b = Float::from_int(15) * dp
    let c = Float::from_int(-24) * x
    let s = a + b
    let s = s + c
    let s = s + Float::from_int(12)
    return s * one_sixth
  }
  0.0
}

///|
/// `generate_weights::<f32, f64>(ResamplingFunction::CatmullRom, in_size,
/// out_size)`. CatmullRom is a resizable kernel without window, not EWA and
/// not area, so only that branch is ported.
fn generate_weights(in_size : Int, out_size : Int) -> FilterWeights {
  let scale : Float = Float::from_int(in_size) / Float::from_int(out_size)
  // is_resizable_kernel == true
  let filter_scale_cutoff = max_f32(scale, Float::from_int(1))
  // (min_kernel_size as f64 * 2f64).as_() with min_kernel_size = 2
  let filter_base_size : Float = Float::from_int(4)
  let bounds_start = FixedArray::make(out_size, 0)
  let bounds_size = FixedArray::make(out_size, 0)
  let base_size = f32_to_usize(
    round_f32(filter_base_size * filter_scale_cutoff),
  )
  let kernel_size = base_size
  let filter_radius : Float = Float::from_int(base_size) / Float::from_int(2)
  let ones_t : Float = Float::from_int(1)
  let filter_scale = ones_t / filter_scale_cutoff
  let weights : FixedArray[Float] = FixedArray::make(
    kernel_size * out_size,
    0.0,
  )
  let local_filters : FixedArray[Float] = FixedArray::make(kernel_size, 0.0)
  let mut filter_position = 0
  let in_size_f = Float::from_int(in_size)
  let half : Float = Float::from_int(1) / Float::from_int(2)
  for i in 0..<out_size {
    let center_x = min_f32((Float::from_int(i) + half) * scale, in_size_f)
    let mut weights_sum : Double = 0.0
    let start = f32_to_usize(
      max_f32(floor_f32(center_x - filter_radius), Float::from_int(0)),
    )
    let end = f32_to_usize(
      min_f32(
        min_f32(
          ceil_f32(center_x + filter_radius),
          Float::from_int(start) + Float::from_int(kernel_size),
        ),
        in_size_f,
      ),
    )
    let center = center_x - half
    // (start..end).zip(local_filters.iter_mut())
    let mut k = start
    let mut j = 0
    while k < end && j < kernel_size {
      let dx = Float::from_int(k) - center
      let dx = if dx < 0.0 { -dx } else { dx }
      let weight = catmull_rom(dx * filter_scale)
      weights_sum = weights_sum + weight.to_double()
      local_filters[j] = weight
      k += 1
      j += 1
    }
    let size = end - start
    bounds_start[i] = start
    bounds_size[i] = size
    if weights_sum != 0.0 {
      let recpeq : Double = 1.0 / weights_sum
      let n = @cmp.minimum(size, kernel_size)
      for t in 0..<n {
        if filter_position + t < weights.length() {
          let src_w = local_filters[t].to_double()
          weights[filter_position + t] = Float::from_double(src_w * recpeq)
        }
      }
    }
    filter_position += kernel_size
  }
  {
    weights,
    bounds_start,
    bounds_size,
    kernel_size,
    distinct_elements: out_size,
  }
}
