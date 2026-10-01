// CMYK to sRGB conversion (upstream: an 8-bit `moxcms` 0.8.1 transform from
// typst-assets' `CMYK-to-XYZ.icc` profile to `ColorProfile::new_srgb()` with
// perceptual intent, see `Cmyk::to_rgba` in `visualize/color.rs`).
//
// `moxcms` builds a 17^4 grid by evaluating the profile's `mft2` pipeline in
// `f32` (input curves, quadlinear CLUT interpolation, output curves, Lab v2
// to v4, Lab to XYZ, XYZ to linear sRGB and the sRGB gamma table), quantizes
// it to integers and interpolates it at runtime in Q0.15 fixed point (the
// aarch64 NEON `TransformLut4To3NeonQ0_15` executor with `rdm`, which the
// reference outputs were produced with). Fused multiply-adds (`mlaf`) are
// emulated exactly.

///|
/// Grid size of the precomputed 4D lookup table (`GRID_SIZE`).
let cmyk_grid_size : Int = 17

///|
/// Exact single-precision fused multiply-add `a * b + c` (computed in double
/// precision with round-to-odd, then rounded to `Float`).
fn f32_fma(a : Float, b : Float, c : Float) -> Float {
  let p = a.to_double() * b.to_double() // exact
  let cd = c.to_double()
  let s = p + cd
  // TwoSum: the rounding error of `s`.
  let bb = s - p
  let err = p - (s - bb) + (cd - bb)
  let s = if err != 0.0 && s != 0.0 {
    let bits = s.reinterpret_as_uint64()
    if (bits & 1UL) == 0UL {
      // Round to odd: move one ulp towards the exact value.
      let toward_larger_magnitude = (err > 0.0) == (s > 0.0)
      (if toward_larger_magnitude { bits + 1UL } else { bits - 1UL }).reinterpret_as_double()
    } else {
      s
    }
  } else {
    s
  }
  Float::from_double(s)
}

///|
/// `moxcms` `mlaf(acc, a, b)` on aarch64: `a * b + acc`, fused.
fn mlaf(acc : Float, a : Float, b : Float) -> Float {
  f32_fma(a, b, acc)
}

///|
/// Rust `f32::round` (half away from zero).
fn f32_round(x : Float) -> Float {
  Float::from_double(rust_round(x.to_double()))
}

///|
/// Rust `f32 as i32` (saturating truncation).
fn f32_as_int(x : Float) -> Int {
  if x.is_nan() {
    0
  } else {
    let d = x.to_double()
    if d >= 2147483647.0 {
      2147483647
    } else if d <= -2147483648.0 {
      -2147483648
    } else {
      d.to_int()
    }
  }
}

///|
/// `moxcms` `uint16_number_to_float_fast`.
fn u16_to_f32(a : Int) -> Float {
  Float::from_int(a) * (Float::from_int(1) / 65535.0)
}

///|
/// `moxcms` `lut_interp_linear_float`.
fn lut_interp_linear_float(x : Float, table : ArrayView[Float]) -> Float {
  let value = f32_max(f32_min(x, 1.0), 0.0) *
    Float::from_int(table.length() - 1)
  let upper = f32_as_int(f32_ceil(value))
  let lower = f32_as_int(f32_floor(value))
  let diff = Float::from_int(upper) - value
  let tu = table[upper]
  mlaf(mlaf(tu, tu, -diff), table[lower], diff)
}

///|
/// `moxcms` `lerp` on the CLUT: `a - a * t + b * t` with fused operations.
fn lerp3(
  a : (Float, Float, Float),
  b : (Float, Float, Float),
  t : Float,
) -> (Float, Float, Float) {
  (
    mlaf(mlaf(a.0, a.0, -t), b.0, t),
    mlaf(mlaf(a.1, a.1, -t), b.1, t),
    mlaf(mlaf(a.2, a.2, -t), b.2, t),
  )
}

///|
/// `moxcms` `Hypercube::quadlinear_vec3`.
fn quadlinear_vec3(
  clut : FixedArray[Float],
  grid : Int,
  lin_x : Float,
  lin_y : Float,
  lin_z : Float,
  lin_w : Float,
) -> (Float, Float, Float) {
  let lin_x = f32_max(lin_x, 0.0)
  let lin_y = f32_max(lin_y, 0.0)
  let lin_z = f32_max(lin_z, 0.0)
  let lin_w = f32_max(lin_w, 0.0)
  let scale = Float::from_int(grid - 1)
  let x = f32_as_int(f32_min(f32_floor(lin_x * scale), scale))
  let y = f32_as_int(f32_min(f32_floor(lin_y * scale), scale))
  let z = f32_as_int(f32_min(f32_floor(lin_z * scale), scale))
  let w = f32_as_int(f32_min(f32_floor(lin_w * scale), scale))
  let x_n = f32_as_int(f32_min(f32_ceil(lin_x * scale), scale))
  let y_n = f32_as_int(f32_min(f32_ceil(lin_y * scale), scale))
  let z_n = f32_as_int(f32_min(f32_ceil(lin_z * scale), scale))
  let w_n = f32_as_int(f32_min(f32_ceil(lin_w * scale), scale))
  let x_d = lin_x * scale - Float::from_int(x)
  let y_d = lin_y * scale - Float::from_int(y)
  let z_d = lin_z * scale - Float::from_int(z)
  let w_d = lin_w * scale - Float::from_int(w)
  let z_stride = grid
  let y_stride = grid * grid
  let x_stride = grid * grid * grid
  let r = (x : Int, y : Int, z : Int, w : Int) => {
    let start = (x * x_stride + y * y_stride + z * z_stride + w) * 3
    (clut[start], clut[start + 1], clut[start + 2])
  }
  let r_x1 = lerp3(r(x, y, z, w), r(x_n, y, z, w), x_d)
  let r_x2 = lerp3(r(x, y_n, z, w), r(x_n, y_n, z, w), x_d)
  let r_y1 = lerp3(r_x1, r_x2, y_d)
  let r_x3 = lerp3(r(x, y, z_n, w), r(x_n, y, z_n, w), x_d)
  let r_x4 = lerp3(r(x, y_n, z_n, w), r(x_n, y_n, z_n, w), x_d)
  let r_y2 = lerp3(r_x3, r_x4, y_d)
  let r_z1 = lerp3(r_y1, r_y2, z_d)
  let r_x1 = lerp3(r(x, y, z, w_n), r(x_n, y, z, w_n), x_d)
  let r_x2 = lerp3(r(x, y_n, z, w_n), r(x_n, y_n, z, w_n), x_d)
  let r_y1 = lerp3(r_x1, r_x2, y_d)
  let r_x3 = lerp3(r(x, y, z_n, w_n), r(x_n, y, z_n, w_n), x_d)
  let r_x4 = lerp3(r(x, y_n, z_n, w_n), r(x_n, y_n, z_n, w_n), x_d)
  let r_y2 = lerp3(r_x3, r_x4, y_d)
  let r_z2 = lerp3(r_y1, r_y2, z_d)
  lerp3(r_z1, r_z2, w_d)
}

///|
/// `moxcms` `f_1` of the Lab to XYZ conversion.
fn lab_f_1(t : Float) -> Float {
  let limit : Float = Float::from_int(24) / 116.0
  if t <= limit {
    Float::from_int(108) / 841.0 * (t - Float::from_int(16) / 116.0)
  } else {
    t * t * t
  }
}

///|
/// `moxcms` `Lab::to_pcs_xyz`.
fn lab_to_pcs_xyz(l : Float, a : Float, b : Float) -> (Float, Float, Float) {
  let device_l = l * 100.0
  let device_a = mlaf(-128.0, a, 255.0)
  let device_b = mlaf(-128.0, b, 255.0)
  let y = (device_l + 16.0) / 116.0
  // `Chromaticity::D50.to_xyz()`.
  let d50_x : Float = 0.34567
  let d50_y : Float = 0.35850
  let reciprocal = Float::from_int(1) / d50_y
  let wp_x = d50_x * reciprocal
  let wp_y : Float = 1.0
  let wp_z = (Float::from_int(1) - d50_x - d50_y) * reciprocal
  let x = lab_f_1(mlaf(y, 0.002, device_a)) * wp_x
  let y1 = lab_f_1(y) * wp_y
  let z = lab_f_1(mlaf(y, -0.005, device_b)) * wp_z
  let scale = 1.0 + 32767.0 / 32768.0
  (
    Float::from_double(x.to_double() / scale),
    Float::from_double(y1.to_double() / scale),
    Float::from_double(z.to_double() / scale),
  )
}

///|
/// `moxcms` `MatrixStage` row: `x * m0 + y * m1 + z * m2` with fused
/// operations.
fn matrix_row(x : Float, y : Float, z : Float, m : FixedArray[Float]) -> Float {
  mlaf(mlaf(x * m[0], y, m[1]), z, m[2])
}

///|
/// The inverse of the sRGB profile's colorant matrix
/// (`ColorProfile::new_srgb().rgb_to_xyz_matrix().inverse()` in `moxcms`,
/// D50-adapted, computed in `f64`).
let srgb_xyz_to_rgb_d50 : FixedArray[Double] = [
  3.135943378956364, -1.6186452789750814, -0.49088075237649664, -0.9786401066803629,
  1.916001955909481, 0.03346461697728635, 0.07198041691508127, -0.22910802546197936,
  1.4053805920915055,
]

///|
/// The sRGB transfer function for the 8-bit gamma table (`moxcms`
/// `srgb_from_linear`).
fn srgb_from_linear_f64(linear : Double) -> Double {
  if linear < 0.0 {
    0.0
  } else if linear < 0.0030412825601275209 {
    linear * 12.92
  } else if linear < 1.0 {
    1.0550107189475866 * @math.pow(linear, 1.0 / 2.4) - 0.0550107189475866
  } else {
    1.0
  }
}

///|
/// The 8-bit sRGB gamma table with 4096 entries (`make_gamma_table`).
fn srgb_gamma_table() -> FixedArray[Int] {
  let max_range = 1.0 / 4095.0
  FixedArray::makei(4096, v => {
    let g = srgb_from_linear_f64(v.to_double() * max_range)
    f32_as_int(f32_round(Float::from_double(g * 255.0)))
  })
}

///|
/// The precomputed 17^4 grid of 8-bit sRGB values (`[k][c][m][y]` order).
fn cmyk_build_grid() -> FixedArray[Int] {
  let grid = cmyk_icc_grid_points
  let n_in = cmyk_icc_input_entries
  let n_out = cmyk_icc_output_entries
  let input : Array[ArrayView[Float]] = []
  let in_f = FixedArray::makei(cmyk_icc_input_tables.length(), i => {
    u16_to_f32(cmyk_icc_input_tables[i])
  })
  let out_f = FixedArray::makei(cmyk_icc_output_tables.length(), i => {
    u16_to_f32(cmyk_icc_output_tables[i])
  })
  let in_all = Array::makei(in_f.length(), i => in_f[i])
  let out_all = Array::makei(out_f.length(), i => out_f[i])
  for i in 0..<4 {
    input.push(in_all[i * n_in:(i + 1) * n_in])
  }
  let output : Array[ArrayView[Float]] = []
  for i in 0..<3 {
    output.push(out_all[i * n_out:(i + 1) * n_out])
  }
  let clut = FixedArray::makei(cmyk_icc_clut.length(), i => {
    u16_to_f32(cmyk_icc_clut[i])
  })
  let v2_to_v4 = Float::from_int(65535) / 65280.0
  let pcs_scale = Float::from_int(65535) / 32768.0
  let m : FixedArray[Float] = srgb_xyz_to_rgb_d50.map(Float::from_double)
  let gamma = srgb_gamma_table()
  let lut_cap : Float = 4095.0
  let s = cmyk_grid_size
  let recpeq = Float::from_int(1) / Float::from_int(s - 1)
  let out = FixedArray::make(s * s * s * s * 3, 0)
  let mut idx = 0
  for k in 0..<s {
    for c in 0..<s {
      for mm in 0..<s {
        for y in 0..<s {
          let src = [
            Float::from_int(c) * recpeq,
            Float::from_int(mm) * recpeq,
            Float::from_int(y) * recpeq,
            Float::from_int(k) * recpeq,
          ]
          let lx = lut_interp_linear_float(src[0], input[0])
          let ly = lut_interp_linear_float(src[1], input[1])
          let lz = lut_interp_linear_float(src[2], input[2])
          let lw = lut_interp_linear_float(src[3], input[3])
          let (p0, p1, p2) = quadlinear_vec3(clut, grid, lx, ly, lz, lw)
          let l = lut_interp_linear_float(p0, output[0])
          let a = lut_interp_linear_float(p1, output[1])
          let b = lut_interp_linear_float(p2, output[2])
          // Lab v2 to v4.
          let l2 = matrix_row(l, a, b, [v2_to_v4, 0.0, 0.0])
          let a2 = matrix_row(l, a, b, [0.0, v2_to_v4, 0.0])
          let b2 = matrix_row(l, a, b, [0.0, 0.0, v2_to_v4])
          let (x, yy, z) = lab_to_pcs_xyz(l2, a2, b2)
          // XYZ (PCS encoding) to linear sRGB.
          let x1 = matrix_row(x, yy, z, [pcs_scale, 0.0, 0.0])
          let y1 = matrix_row(x, yy, z, [0.0, pcs_scale, 0.0])
          let z1 = matrix_row(x, yy, z, [0.0, 0.0, pcs_scale])
          let rgb = [
            matrix_row(x1, y1, z1, [m[0], m[1], m[2]]),
            matrix_row(x1, y1, z1, [m[3], m[4], m[5]]),
            matrix_row(x1, y1, z1, [m[6], m[7], m[8]]),
          ]
          for ch in 0..<3 {
            let i = f32_as_int(
              f32_max(f32_min(mlaf(0.5, rgb[ch], lut_cap), lut_cap), 0.0),
            )
            // `gamma[i] as f32 * (1 / 255)`, quantized back with
            // `(x * 255).round() as i16`.
            let v = Float::from_int(gamma[i]) *
              (Float::from_int(1) / Float::from_int(255))
            out[idx] = f32_as_int(f32_round(v * 255.0))
            idx += 1
          }
        }
      }
    }
  }
  out
}

///|
let cmyk_grid_cell : Ref[FixedArray[Int]?] = { val: None, }

///|
fn cmyk_grid() -> FixedArray[Int] {
  match cmyk_grid_cell.val {
    Some(g) => g
    None => {
      let g = cmyk_build_grid()
      cmyk_grid_cell.val = Some(g)
      g
    }
  }
}

///|
/// The barycentric weights for 8-bit inputs (`BarycentricWeight::<i16>::
/// create_ranged_256`): `(x, x_n, w)` with `w` in Q0.15.
fn cmyk_weight(index : Int) -> (Int, Int, Int) {
  let s = cmyk_grid_size
  let x = index * (s - 1) / 255
  let x_n = if x + 1 < s - 1 { x + 1 } else { s - 1 }
  let scale = Float::from_int(s - 1) * (Float::from_int(1) / 255.0)
  let q : Float = 32767.0
  let dr = f32_round(
    f32_fma(Float::from_int(index), scale, -Float::from_int(x)) * q,
  )
  let dr = f32_max(f32_min(dr, 32767.0), -32767.0)
  (x, x_n, f32_as_int(dr))
}

///|
/// Saturate to `i16`.
fn sat_i16(x : Int) -> Int {
  if x > 32767 {
    32767
  } else if x < -32768 {
    -32768
  } else {
    x
  }
}

///|
/// NEON `SQRDMLAH` on one lane: `sat((a << 16) + 2 * b * c + 2^15) >> 16`.
fn qrdmlah(a : Int, b : Int, c : Int) -> Int {
  let acc = (a.to_int64() << 16) + 2L * b.to_int64() * c.to_int64() + 32768L
  sat_i16((acc >> 16).to_int())
}

///|
/// NEON `SQRDMLSH` on one lane: `sat((a << 16) - 2 * b * c + 2^15) >> 16`.
fn qrdmlsh(a : Int, b : Int, c : Int) -> Int {
  let acc = (a.to_int64() << 16) - 2L * b.to_int64() * c.to_int64() + 32768L
  sat_i16((acc >> 16).to_int())
}

///|
/// Convert 8-bit CMYK components to 8-bit sRGB.
fn cmyk_to_srgb8(c : Int, m : Int, y : Int, k : Int) -> (Int, Int, Int) {
  let lut = cmyk_grid()
  let s = cmyk_grid_size
  let grid3 = s * s * s
  let (kw, kw_n, t) = cmyk_weight(k)
  let (x, x_n, dr) = cmyk_weight(c)
  let (yy, y_n, dg) = cmyk_weight(m)
  let (z, z_n, db) = cmyk_weight(y)
  let result = [0, 0, 0]
  for ch in 0..<3 {
    let lane = (table : Int) => {
      let fetch = (x : Int, y : Int, z : Int) => {
        lut[(table * grid3 + x * s * s + y * s + z) * 3 + ch]
      }
      let c000 = fetch(x, yy, z)
      let c100 = fetch(x_n, yy, z)
      let c010 = fetch(x, y_n, z)
      let c110 = fetch(x_n, y_n, z)
      let c001 = fetch(x, yy, z_n)
      let c101 = fetch(x_n, yy, z_n)
      let c011 = fetch(x, y_n, z_n)
      let c111 = fetch(x_n, y_n, z_n)
      let c00 = qrdmlah(qrdmlsh(c000, c000, dr), c100, dr)
      let c10 = qrdmlah(qrdmlsh(c010, c010, dr), c110, dr)
      let c01 = qrdmlah(qrdmlsh(c001, c001, dr), c101, dr)
      let c11 = qrdmlah(qrdmlsh(c011, c011, dr), c111, dr)
      let c0 = qrdmlah(qrdmlsh(c00, c00, dg), c10, dg)
      let c1 = qrdmlah(qrdmlsh(c01, c01, dg), c11, dg)
      qrdmlah(qrdmlsh(c0, c0, db), c1, db)
    }
    let a0 = lane(kw)
    let b0 = lane(kw_n)
    let hp = qrdmlsh(a0, a0, t)
    let v = qrdmlah(hp, b0, t)
    result[ch] = if v < 0 { 0 } else if v > 255 { 255 } else { v }
  }
  (result[0], result[1], result[2])
}
