// Port of pic-scale's `filter_weights.rs` (the parts used by the u8 paths).

///|
/// `FilterWeights<f32>` as produced by `generate_weights`: `out_size`
/// kernels of `kernel_size` taps each; kernel `i` applies to the source
/// pixels `bounds_start[i] .. bounds_start[i] + bounds_size[i]`.
priv struct FilterWeights {
  weights : FixedArray[Float]
  bounds_start : FixedArray[Int]
  bounds_size : FixedArray[Int]
  kernel_size : Int
  distinct_elements : Int
}

///|
/// `FilterWeights<i16>` after `numerical_approximation::<i16, 15>(0)`
/// (`aligned_size == kernel_size` as the alignment is 0).
priv struct FixedWeights {
  weights : FixedArray[Int]
  bounds_start : FixedArray[Int]
  bounds_size : FixedArray[Int]
  aligned_size : Int
  /// Whether every weight is an `i16` value (the contract of the v128 rdm
  /// kernels, checked once here: the weights are not modified afterwards).
  weights_fit_i16 : Bool
}

///|
/// `f64::round` (half away from zero).
fn round_f64(x : Double) -> Double {
  let t = x.trunc()
  let d = x - t
  if d >= 0.5 {
    t + 1.0
  } else if d <= -0.5 {
    t - 1.0
  } else {
    t
  }
}

///|
/// Quantizes one kernel into fixed point, keeping the tap sum at exactly
/// `precision_scale` (`quantize_kernel`). The values are integers, so they
/// are kept as `Int` (the `f64` arithmetic of upstream is exact on them).
fn quantize_kernel(
  weights : FixedArray[Float],
  offset : Int,
  kernel_size : Int,
  taps : Int,
  precision_scale : Int,
  lower_bound : Int,
  upper_bound : Int,
  scratch : FixedArray[Int],
  order : Array[Int],
) -> Unit {
  let mut sum = 0
  for i in 0..<kernel_size {
    let q = round_f64(
      weights[offset + i].to_double() * precision_scale.to_double(),
    )
    let q = if q > upper_bound.to_double() {
      upper_bound
    } else if q < lower_bound.to_double() {
      lower_bound
    } else {
      q.to_int()
    }
    scratch[i] = q
    if i < taps {
      sum += q
    }
  }
  let mut residual = precision_scale - sum
  if residual == 0 || taps == 0 {
    return
  }
  order.clear()
  for i in 0..<taps {
    order.push(i)
  }
  // order.sort_unstable_by(|&a, &b| scratch[b].abs().partial_cmp(&scratch[a].abs()))
  sort_unstable_by(order, fn(a, b) { scratch[b].abs() < scratch[a].abs() })
  for i in order {
    let delta = if residual > 0 {
      @cmp.minimum(residual, upper_bound - scratch[i])
    } else {
      @cmp.maximum(residual, lower_bound - scratch[i])
    }
    scratch[i] += delta
    residual -= delta
    if residual == 0 {
      break
    }
  }
}

///|
/// `FilterWeights<f32>::numerical_approximation::<i16, PRECISION>(0)`.
fn FilterWeights::numerical_approximation_i16(
  self : FilterWeights,
  precision : Int,
) -> FixedWeights {
  let align = self.kernel_size
  let precision_scale = 1 << precision
  let output_kernel = FixedArray::make(self.distinct_elements * align, 0)
  let lower_bound = -32768
  let upper_bound = 32767
  let scratch = FixedArray::make(self.kernel_size, 0)
  let order : Array[Int] = Array(capacity=self.kernel_size)
  // `chunks_exact(kernel_size)` zipped with the bounds.
  let chunks = if self.kernel_size == 0 {
    0
  } else {
    self.weights.length() / self.kernel_size
  }
  let n = @cmp.minimum(
    @cmp.minimum(chunks, self.distinct_elements),
    self.bounds_size.length(),
  )
  for k in 0..<n {
    quantize_kernel(
      self.weights,
      k * self.kernel_size,
      self.kernel_size,
      @cmp.minimum(self.bounds_size[k], self.kernel_size),
      precision_scale,
      lower_bound,
      upper_bound,
      scratch,
      order,
    )
    for i in 0..<align {
      output_kernel[k * align + i] = scratch[i]
    }
  }
  let fixed : FixedWeights = {
    weights: output_kernel,
    bounds_start: self.bounds_start.copy(),
    bounds_size: self.bounds_size.copy(),
    aligned_size: align,
    weights_fit_i16: weights_fit_i16(output_kernel, 0, output_kernel.length()),
  }
  // `quantize_kernel` clamps to `lower_bound..=upper_bound`.
  guard fixed.weights_fit_i16 else { abort("weights out of the i16 range") }
  fixed
}

///|
/// Whether `weights[off..off + n]` are `i16` values (`numerical_approximation_
/// i16` clamps them; the v128 kernels hold them in `i16` lanes).
fn weights_fit_i16(weights : FixedArray[Int], off : Int, n : Int) -> Bool {
  for j in 0..<n {
    let w = weights[off + j]
    if w < -32768 || w > 32767 {
      return false
    }
  }
  true
}
