// Port of `hayro-jpeg2000/src/j2c/idwt.rs`: performing the inverse discrete
// wavelet transform, as specified in Annex F.
//
// The `f32x8` code paths are ported lane by lane (see `math.mbt`); where the
// SIMD and the scalar remainder code differ (the 5-3 predict step of the
// vertical filter), both are kept.

///|
/// The output from performing the IDWT operation.
priv struct IDWTOutput {
  /// The buffer that will hold the final coefficients.
  coefficients : FloatVec
  /// The rect that the coefficients belong to. This will be equivalent
  /// to the rectangle that forms the smallest decomposition level. It does
  /// not have to be equivalent to the original size of the tile, as the
  /// sub-bands that form a tile aren't necessarily aligned to it. Therefore,
  /// the samples need to be trimmed to the tile rectangle afterward.
  mut rect : IntRect
}

///|
fn IDWTOutput::default() -> IDWTOutput {
  {
    coefficients: FloatVec::new(),
    rect: IntRect::from_ltrb(0, 0, 0xFFFFFFFF, 0xFFFFFFFF),
  }
}

///|
/// Apply the inverse discrete wavelet transform (see Annex F). The output
/// will be transformed samples covering the rectangle of the smallest
/// decomposition level.
fn idwt_apply(
  storage : DecompositionStorage,
  tile_ctx : TileDecodeContext,
  component_idx : Int,
  header : Header,
  transform : WaveletTransform,
) -> Unit {
  let tile_decompositions = storage.tile_decompositions[component_idx]
  let d_start = tile_decompositions.decompositions_start
  let mut d_len = tile_decompositions.decompositions_end - d_start
  // If we requested a lower resolution level, we can skip some decompositions.
  d_len = if d_len > header.skipped_resolution_levels {
    d_len - header.skipped_resolution_levels
  } else {
    0
  }
  let ll_sub_band = storage.sub_bands[tile_decompositions.first_ll_sub_band]

  // To explain a bit why we have this scratch buffer and another coefficient
  // buffer: During IDWT, we need to continuously interleave the 4 sub-bands
  // into a new buffer, which is then either returned or used as the input
  // for the next decomposition, etc. It would be very inefficient if we
  // kept allocating new buffers each time. Therefore, we try to reuse them,
  // not only for all decompositions of a single tile, but all decompositions
  // of _all_ tiles.
  // Due to the fact that the output from the previous iteration might be
  // used as the input of the next, we need two separate buffers, which
  // are continuously swapped.
  let scratch_buf = tile_ctx.idwt_scratch_buffer
  let output = tile_ctx.idwt_output
  if d_len == 0 {
    // Single decomposition, just copy the coefficients from the sub-band.
    let len = ll_sub_band.coefficients_end - ll_sub_band.coefficients_start
    output.coefficients.resize(0)
    output.coefficients.resize(len)
    storage.coefficients.data.blit_to(
      output.coefficients.data,
      len~,
      src_offset=ll_sub_band.coefficients_start,
    )
    output.rect = ll_sub_band.rect
    return
  }

  // (The buffers are reserved upfront upstream; `FloatVec::resize` grows
  // them on demand.)

  // Determine which buffer we should use first, such that the `coefficients`
  // array will always hold the final values.
  let mut use_scratch = d_len % 2 == 0
  let mut temp_rect = filter_2d(
    storage.coefficients.data,
    ll_sub_band.coefficients_start,
    if use_scratch {
      scratch_buf
    } else {
      output.coefficients
    },
    storage.decompositions[d_start],
    transform,
    storage,
  )
  for d in 1..<d_len {
    let decomposition = storage.decompositions[d_start + d]
    use_scratch = !use_scratch
    temp_rect = if use_scratch {
      filter_2d(
        output.coefficients.data,
        0,
        scratch_buf,
        decomposition,
        transform,
        storage,
      )
    } else {
      filter_2d(
        scratch_buf.data,
        0,
        output.coefficients,
        decomposition,
        transform,
        storage,
      )
    }
  }
  output.rect = temp_rect
}

///|
/// The `2D_SR` procedure illustrated in Figure F.6.
fn filter_2d(
  // The LL sub band of the given decomposition level.
  input : FixedArray[Float],
  input_offset : Int,
  coefficients : FloatVec,
  decomposition : Decomposition,
  transform : WaveletTransform,
  storage : DecompositionStorage,
) -> IntRect {
  // First interleave all sub-bands into a single buffer.
  interleave_samples(input, input_offset, decomposition, coefficients, storage)
  if decomposition.rect.width() > 0 && decomposition.rect.height() > 0 {
    filter_horizontal(coefficients.data, decomposition.rect, transform)
    filter_vertical(coefficients.data, decomposition.rect, transform)
  }
  decomposition.rect
}

///|
/// The `2D_INTERLEAVE` procedure described in F.3.3.
fn interleave_samples(
  input : FixedArray[Float],
  input_offset : Int,
  decomposition : Decomposition,
  coefficients : FloatVec,
  storage : DecompositionStorage,
) -> Unit {
  let width = decomposition.rect.width().reinterpret_as_int()
  let height = decomposition.rect.height().reinterpret_as_int()

  // The cleaner way would be to first clear and then resize, so that we
  // have a clean buffer with just zeroes. However, this is actually not
  // necessary, because when interleaving and generating the border values
  // we will replace all the data anyway, so we can save the cost of
  // the clear operation.
  coefficients.resize(width * height)
  let { x0: u0, x1: u1, y0: v0, y1: v1, } = decomposition.rect
  let band = storage.coefficients.data
  let hl = storage.sub_bands[decomposition.sub_bands[0]].coefficients_start
  let lh = storage.sub_bands[decomposition.sub_bands[1]].coefficients_start
  let hh = storage.sub_bands[decomposition.sub_bands[2]].coefficients_start

  // See Figure F.8.
  let num_u_low = (div_ceil_u32(u1, 2) - div_ceil_u32(u0, 2)).reinterpret_as_int()
  let num_u_high = (u1 / 2 - u0 / 2).reinterpret_as_int()
  let num_v_low = (div_ceil_u32(v1, 2) - div_ceil_u32(v0, 2)).reinterpret_as_int()
  let num_v_high = (v1 / 2 - v0 / 2).reinterpret_as_int()

  // Depending on whether the start row is even or odd, either LL/HL comes first
  // or HL/HH.

  let (first_w, second_w) = if u0 % 2 == 0 {
    (num_u_low, num_u_high)
  } else {
    (num_u_high, num_u_low)
  }
  let even_row_start = if v0 % 2 == 0 { 0 } else { 1 }
  let odd_row_start = if v0 % 2 == 0 { 1 } else { 0 }
  let out = coefficients.data

  // Determine whether LL or HL is the band in the first column.
  if u0 % 2 == 0 {
    interleave_rows(
      input, input_offset, band, hl, first_w, second_w, out, width, height, even_row_start,
      num_v_low,
    )
  } else {
    interleave_rows(
      band, hl, input, input_offset, first_w, second_w, out, width, height, even_row_start,
      num_v_low,
    )
  }

  // Determine whether LH or HH is the band in the first column.
  if u0 % 2 == 0 {
    interleave_rows(
      band, lh, band, hh, first_w, second_w, out, width, height, odd_row_start, num_v_high,
    )
  } else {
    interleave_rows(
      band, hh, band, lh, first_w, second_w, out, width, height, odd_row_start, num_v_high,
    )
  }
}

///|
fn interleave_rows(
  first_band : FixedArray[Float],
  first_offset : Int,
  second_band : FixedArray[Float],
  second_offset : Int,
  first_w : Int,
  second_w : Int,
  output : FixedArray[Float],
  width : Int,
  height : Int,
  start_row : Int,
  num_rows : Int,
) -> Unit {
  for v in 0..<num_rows {
    let out_row = start_row + v * 2
    if out_row >= height {
      break
    }
    let first_row = first_offset + v * first_w
    let second_row = second_offset + v * second_w
    let out_slice = out_row * width
    interleave_row(
      first_band, first_row, first_w, second_band, second_row, second_w, output,
      out_slice,
    )
  }
}

///|
fn interleave_row(
  first : FixedArray[Float],
  first_start : Int,
  first_len : Int,
  second : FixedArray[Float],
  second_start : Int,
  second_len : Int,
  output : FixedArray[Float],
  output_start : Int,
) -> Unit {
  // (The SIMD `zip_low`/`zip_high` chunks are the same interleaving.)
  let num_pairs = if first_len < second_len { first_len } else { second_len }
  if num_pairs > 0 {
    check_range(first, first_start, first_start + num_pairs)
    check_range(second, second_start, second_start + num_pairs)
    check_range(output, output_start, output_start + num_pairs * 2)
  }
  for i in 0..<num_pairs {
    output.unsafe_set(output_start + i * 2, first.unsafe_get(first_start + i))
    output.unsafe_set(
      output_start + i * 2 + 1,
      second.unsafe_get(second_start + i),
    )
  }

  // Handle extra element if first is longer.
  if first_len > num_pairs {
    output[output_start + num_pairs * 2] = first[first_start + num_pairs]
  }
}

///|
/// The `HOR_SR` procedure from F.3.4.
fn filter_horizontal(
  coefficients : FixedArray[Float],
  rect : IntRect,
  transform : WaveletTransform,
) -> Unit {
  let width = rect.width().reinterpret_as_int()
  let height = rect.height().reinterpret_as_int()
  for row in 0..<height {
    filter_row(
      coefficients,
      row * width,
      width,
      rect.x0.reinterpret_as_int() & 1,
      transform,
    )
  }
}

///|
/// The `1D_SR` procedure from F.3.6.
fn filter_row(
  scanline : FixedArray[Float],
  start : Int,
  width : Int,
  x0_parity : Int,
  transform : WaveletTransform,
) -> Unit {
  if width == 1 {
    if x0_parity != 0 {
      scanline[start] = scanline[start] * 0.5
    }
    return
  }
  match transform {
    Reversible53 => reversible_filter_53r(scanline, start, width, x0_parity)
    Irreversible97 => irreversible_filter_97i(scanline, start, width, x0_parity)
  }
}

///|
/// The 1D FILTER 5-3R procedure from F.3.8.1.
fn reversible_filter_53r(
  scanline : FixedArray[Float],
  start : Int,
  width : Int,
  x0_parity : Int,
) -> Unit {
  let first_even = x0_parity
  let first_odd = 1 - first_even

  // Equation (F-5).
  // Originally: for i in (start / 2)..(end / 2 + 1).
  filter_step_horizontal(scanline, start, width, first_even, OP_53_PREDICT)

  // Equation (F-6).
  // Originally: for i in (start / 2)..(end / 2).
  filter_step_horizontal(scanline, start, width, first_odd, OP_53_UPDATE)
}

// Table F.4.

///|
/// `NEG_ALPHA` (1.586_134_3).
let neg_alpha : Float = Float::reinterpret_from_uint(0x3FCB0673)

///|
/// `NEG_BETA` (0.052_980_117).
let neg_beta : Float = Float::reinterpret_from_uint(0x3D5901AE)

///|
/// `NEG_GAMMA` (-0.882_911_1).
let neg_gamma : Float = Float::reinterpret_from_uint(0xBF620676)

///|
/// `NEG_DELTA` (-0.443_506_87).
let neg_delta : Float = Float::reinterpret_from_uint(0xBEE31355)

///|
/// `KAPPA` (1.230_174_1).
let kappa : Float = Float::reinterpret_from_uint(0x3F9D7658)

///|
/// `INV_KAPPA` (`1.0 / KAPPA`).
let inv_kappa : Float = (1.0 : Float) / kappa

///|
/// The 1D Filter 9-7I procedure from F.3.8.2.
fn irreversible_filter_97i(
  scanline : FixedArray[Float],
  start : Int,
  width : Int,
  x0_parity : Int,
) -> Unit {
  let first_even = x0_parity
  let first_odd = 1 - first_even
  let (k0, k1) = if first_even == 0 {
    (kappa, inv_kappa)
  } else {
    (inv_kappa, kappa)
  }

  // Step 1 and 2.
  // Originally: for i in (start / 2 - 1)..(end / 2 + 2).
  // Originally: for i in (start / 2 - 2)..(end / 2 + 2).
  let mut i = 0
  while i < width - 1 {
    scanline[start + i] = scanline[start + i] * k0
    scanline[start + i + 1] = scanline[start + i + 1] * k1
    i += 2
  }
  if width % 2 == 1 {
    scanline[start + width - 1] = scanline[start + width - 1] * k0
  }

  // Step 3.
  // Originally: for i in (start / 2 - 1)..(end / 2 + 2).
  filter_step_horizontal(scanline, start, width, first_even, OP_97_DELTA)

  // Step 4.
  // Originally: for i in (start / 2 - 1)..((x0 + width) / 2 + 1).
  filter_step_horizontal(scanline, start, width, first_odd, OP_97_GAMMA)

  // Step 5.
  // Originally: for i in (start / 2)..(end / 2 + 1).
  filter_step_horizontal(scanline, start, width, first_even, OP_97_BETA)

  // Step 6.
  // Originally: for i in (start / 2)..(end / 2).
  filter_step_horizontal(scanline, start, width, first_odd, OP_97_ALPHA)
}

///|
/// `s - floor(mul_add(left + right, 0.25, 0.5))` (scalar 5-3 predict).
const OP_53_PREDICT : Int = 0

///|
/// `s + floor((left + right) * 0.5)` (5-3 update).
const OP_53_UPDATE : Int = 1

///|
/// `mul_add(left + right, NEG_DELTA, s)`.
const OP_97_DELTA : Int = 2

///|
/// `mul_add(left + right, NEG_GAMMA, s)`.
const OP_97_GAMMA : Int = 3

///|
/// `mul_add(left + right, NEG_BETA, s)`.
const OP_97_BETA : Int = 4

///|
/// `mul_add(left + right, NEG_ALPHA, s)`.
const OP_97_ALPHA : Int = 5

///|
/// `s1 - ((s2 + s3 + 2.0) * 0.25).floor()` (the `f32x8` 5-3 predict).
const OP_53_PREDICT_SIMD : Int = 6

///|
fn lift(op : Int, s : Float, left : Float, right : Float) -> Float {
  match op {
    OP_53_PREDICT => s - floor_f32(mul_add(left + right, 0.25, 0.5))
    OP_53_UPDATE => s + floor_f32((left + right) * 0.5)
    OP_97_DELTA => mul_add(left + right, neg_delta, s)
    OP_97_GAMMA => mul_add(left + right, neg_gamma, s)
    OP_97_BETA => mul_add(left + right, neg_beta, s)
    OP_97_ALPHA => mul_add(left + right, neg_alpha, s)
    _ => s - floor_f32((left + right + 2.0) * 0.25)
  }
}

///|
/// `lift` for `scanline[i]` with `i` from `from` to `end` (exclusive) in
/// steps of two, with the neighbors `i - 1` and `i + 1` (the operation is
/// dispatched once per row; the indices are checked once upfront).
fn lift_middle(
  op : Int,
  scanline : FixedArray[Float],
  from : Int,
  end : Int,
) -> Unit {
  if from >= end {
    return
  }
  check_range(scanline, from - 1, end + 1)
  let mut i = from
  match op {
    OP_53_PREDICT =>
      while i < end {
        let s = scanline.unsafe_get(i)
        let l = scanline.unsafe_get(i - 1)
        let r = scanline.unsafe_get(i + 1)
        scanline.unsafe_set(i, s - floor_f32(mul_add(l + r, 0.25, 0.5)))
        i += 2
      }
    OP_53_UPDATE =>
      while i < end {
        let s = scanline.unsafe_get(i)
        let l = scanline.unsafe_get(i - 1)
        let r = scanline.unsafe_get(i + 1)
        scanline.unsafe_set(i, s + floor_f32((l + r) * 0.5))
        i += 2
      }
    OP_53_PREDICT_SIMD =>
      while i < end {
        let s = scanline.unsafe_get(i)
        let l = scanline.unsafe_get(i - 1)
        let r = scanline.unsafe_get(i + 1)
        scanline.unsafe_set(i, s - floor_f32((l + r + 2.0) * 0.25))
        i += 2
      }
    _ => {
      let c = lift_coefficient(op)
      while i < end {
        let s = scanline.unsafe_get(i)
        let l = scanline.unsafe_get(i - 1)
        let r = scanline.unsafe_get(i + 1)
        scanline.unsafe_set(i, mul_add(l + r, c, s))
        i += 2
      }
    }
  }
}

///|
/// Abort unless `start..end` is within `data` (like a Rust slice index).
fn check_range(data : FixedArray[Float], start : Int, end : Int) -> Unit {
  if start < 0 || end > data.length() {
    abort("index out of bounds")
  }
}

///|
/// `lift` for the columns `from..to` of the row at `cur`, with the rows at
/// `above` and `below` as neighbors (the operation is dispatched once; the
/// indices are checked once upfront).
fn lift_rows(
  op : Int,
  scanline : FixedArray[Float],
  cur : Int,
  above : Int,
  below : Int,
  from : Int,
  to : Int,
) -> Unit {
  if from >= to {
    return
  }
  check_range(scanline, cur + from, cur + to)
  check_range(scanline, above + from, above + to)
  check_range(scanline, below + from, below + to)
  match op {
    OP_53_PREDICT =>
      for col in from..<to {
        let s = scanline.unsafe_get(cur + col)
        let a = scanline.unsafe_get(above + col)
        let b = scanline.unsafe_get(below + col)
        scanline.unsafe_set(cur + col, s - floor_f32(mul_add(a + b, 0.25, 0.5)))
      }
    OP_53_UPDATE =>
      for col in from..<to {
        let s = scanline.unsafe_get(cur + col)
        let a = scanline.unsafe_get(above + col)
        let b = scanline.unsafe_get(below + col)
        scanline.unsafe_set(cur + col, s + floor_f32((a + b) * 0.5))
      }
    OP_53_PREDICT_SIMD =>
      for col in from..<to {
        let s = scanline.unsafe_get(cur + col)
        let a = scanline.unsafe_get(above + col)
        let b = scanline.unsafe_get(below + col)
        scanline.unsafe_set(cur + col, s - floor_f32((a + b + 2.0) * 0.25))
      }
    _ => {
      let c = lift_coefficient(op)
      for col in from..<to {
        let s = scanline.unsafe_get(cur + col)
        let a = scanline.unsafe_get(above + col)
        let b = scanline.unsafe_get(below + col)
        scanline.unsafe_set(cur + col, mul_add(a + b, c, s))
      }
    }
  }
}

///|
fn lift_coefficient(op : Int) -> Float {
  match op {
    OP_97_DELTA => neg_delta
    OP_97_GAMMA => neg_gamma
    OP_97_BETA => neg_beta
    _ => neg_alpha
  }
}

///|
fn filter_step_horizontal(
  scanline : FixedArray[Float],
  start : Int,
  width : Int,
  first : Int,
  op : Int,
) -> Unit {
  if first == 0 {
    let left = periodic_symmetric_extension_left(0, 1)
    let right = periodic_symmetric_extension_right(0, 1, width)
    scanline[start] = lift(
      op,
      scanline[start],
      scanline[start + left],
      scanline[start + right],
    )
  }
  let middle_start = if first == 0 { 2 } else { 1 }
  lift_middle(op, scanline, start + middle_start, start + width - 1)
  if width > 1 && (width - 1) % 2 == first {
    let i = width - 1
    let left = periodic_symmetric_extension_left(i, 1)
    let right = periodic_symmetric_extension_right(i, 1, width)
    scanline[start + i] = lift(
      op,
      scanline[start + i],
      scanline[start + left],
      scanline[start + right],
    )
  }
}

///|
fn filter_step_vertical(
  scanline : FixedArray[Float],
  height : Int,
  width : Int,
  simd_width : Int,
  first : Int,
  op_simd : Int,
  op_scalar : Int,
) -> Unit {
  let mut row = first
  while row < height {
    let row_above = periodic_symmetric_extension_left(row, 1)
    let row_below = periodic_symmetric_extension_right(row, 1, height)
    let cur = row * width
    let above = row_above * width
    let below = row_below * width

    // Process SIMD chunks.
    lift_rows(op_simd, scanline, cur, above, below, 0, simd_width)

    // Process scalar remainder.
    lift_rows(op_scalar, scanline, cur, above, below, simd_width, width)
    row += 2
  }
}

///|
/// Part of the `1D_EXTR` procedure, defined in F.3.7.
///
/// Applies the period symmetric extension on the left side.
fn periodic_symmetric_extension_left(idx : Int, offset : Int) -> Int {
  if offset > idx {
    offset - idx
  } else {
    idx - offset
  }
}

///|
/// Part of the `1D_EXTR` procedure, defined in F.3.7.
///
/// Applies the period symmetric extension on the right side.
fn periodic_symmetric_extension_right(
  idx : Int,
  offset : Int,
  length : Int,
) -> Int {
  let new_idx = idx + offset
  if new_idx >= length {
    let overshoot = new_idx - length
    length - 2 - overshoot
  } else {
    new_idx
  }
}

///|
/// The `VER_SR` procedure from F.3.5.
fn filter_vertical(
  scanline : FixedArray[Float],
  rect : IntRect,
  transform : WaveletTransform,
) -> Unit {
  let width = rect.width().reinterpret_as_int()
  let height = rect.height().reinterpret_as_int()
  let y0_parity = rect.y0.reinterpret_as_int() & 1
  if height == 1 {
    if y0_parity != 0 {
      // (SIMD chunks and the scalar remainder both multiply by 0.5.)
      for col in 0..<width {
        scanline[col] = scanline[col] * 0.5
      }
    }
    return
  }
  match transform {
    Reversible53 =>
      reversible_filter_53r_simd(scanline, height, width, y0_parity)
    Irreversible97 =>
      irreversible_filter_97i_simd(scanline, height, width, y0_parity)
  }
}

///|
/// The 1D FILTER 5-3R procedure from F.3.8.1.
fn reversible_filter_53r_simd(
  scanline : FixedArray[Float],
  height : Int,
  width : Int,
  y0_parity : Int,
) -> Unit {
  let first_even = y0_parity
  let first_odd = 1 - first_even
  let simd_width = width / SIMD_WIDTH * SIMD_WIDTH

  // Equation (F-5).
  // Originally: for i in (start / 2)..(end / 2 + 1).
  filter_step_vertical(
    scanline,
    height,
    width,
    simd_width,
    first_even,
    OP_53_PREDICT_SIMD,
    OP_53_PREDICT,
  )

  // Equation (F-6).
  // Originally: for i in (start / 2)..(end / 2).
  filter_step_vertical(
    scanline,
    height,
    width,
    simd_width,
    first_odd,
    OP_53_UPDATE,
    OP_53_UPDATE,
  )
}

///|
/// The 1D Filter 9-7I procedure from F.3.8.2.
fn irreversible_filter_97i_simd(
  scanline : FixedArray[Float],
  height : Int,
  width : Int,
  y0_parity : Int,
) -> Unit {
  // Determine which local row indices correspond to even/odd global positions.
  let first_even = y0_parity
  let first_odd = 1 - first_even
  let simd_width = width / SIMD_WIDTH * SIMD_WIDTH
  let (k0, k1) = if first_even == 0 {
    (kappa, inv_kappa)
  } else {
    (inv_kappa, kappa)
  }

  // Step 1 and 2.
  // Originally: for i in (start / 2 - 1)..(end / 2 + 2).
  // Originally: for i in (start / 2 - 2)..(end / 2 + 2).
  // (SIMD chunks and the scalar remainder are the same products.)
  check_range(scanline, 0, height * width)
  let mut row = 0
  while row < height - 1 {
    let r0 = row * width
    let r1 = (row + 1) * width
    for col in 0..<width {
      scanline.unsafe_set(r0 + col, scanline.unsafe_get(r0 + col) * k0)
      scanline.unsafe_set(r1 + col, scanline.unsafe_get(r1 + col) * k1)
    }
    row += 2
  }
  if height % 2 == 1 {
    let r = (height - 1) * width
    for col in 0..<width {
      scanline.unsafe_set(r + col, scanline.unsafe_get(r + col) * k0)
    }
  }

  // Step 3.
  // Originally: for i in (start / 2 - 1)..(end / 2 + 2).
  filter_step_vertical(
    scanline,
    height,
    width,
    simd_width,
    first_even,
    OP_97_DELTA,
    OP_97_DELTA,
  )

  // Step 4.
  // Originally: for i in (start / 2 - 1)..(end / 2 + 1).
  filter_step_vertical(
    scanline,
    height,
    width,
    simd_width,
    first_odd,
    OP_97_GAMMA,
    OP_97_GAMMA,
  )

  // Step 5.
  // Originally: for i in (start / 2)..(end / 2 + 1).
  filter_step_vertical(
    scanline,
    height,
    width,
    simd_width,
    first_even,
    OP_97_BETA,
    OP_97_BETA,
  )

  // Step 6.
  // Originally: for i in (start / 2)..(end / 2).
  filter_step_vertical(
    scanline,
    height,
    width,
    simd_width,
    first_odd,
    OP_97_ALPHA,
    OP_97_ALPHA,
  )
}
