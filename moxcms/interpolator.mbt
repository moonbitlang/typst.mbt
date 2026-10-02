// Port of `moxcms::conversions::interpolator::BarycentricWeight` and the
// aarch64 Q0.15 trilinear interpolator (`neon::interpolator_q0_15`), emulated
// lane by lane.

///|
/// `LUT_SAMPLING`
let lut_sampling : Int = 255

///|
priv struct BarycentricWeight {
  x : Int
  x_n : Int
  w : Int
}

///|
/// `BarycentricWeight::<i16>::create_ranged_256::<GRID_SIZE>()`.
fn create_ranged_256_q0_15(grid_size : Int) -> FixedArray[BarycentricWeight] {
  FixedArray::makei(256, index => {
    let scale_c = Float::from_int(1) / Float::from_int(lut_sampling)
    let x = index * (grid_size - 1) / lut_sampling
    let x_n = @cmp.minimum(x + 1, grid_size - 1)
    let scale = Float::from_int(grid_size - 1) * scale_c
    let q = Float::from_int((1 << 15) - 1)
    let dr = @pxfm.f32_as_i16(
      @pxfm.max_f32(
        @pxfm.min_f32(
          @pxfm.round_f32(
            fmla(Float::from_int(index), scale, -Float::from_int(x)) * q,
          ),
          32767.0,
        ),
        -32767.0,
      ),
    )
    { x, x_n, w: dr, }
  })
}

///|
/// Saturate to `i16`.
fn sat_i16(x : Int64) -> Int {
  if x > 32767L {
    32767
  } else if x < -32768L {
    -32768
  } else {
    x.to_int()
  }
}

///|
/// NEON `SQRDMLAH` on one 16-bit lane: `sat((a << 16) + 2 * b * c + 2^15) >> 16`.
fn qrdmlah_s16(a : Int, b : Int, c : Int) -> Int {
  sat_i16(
    ((a.to_int64() << 16) + 2L * b.to_int64() * c.to_int64() + 32768L) >> 16,
  )
}

///|
/// NEON `SQRDMLSH` on one 16-bit lane: `sat((a << 16) - 2 * b * c + 2^15) >> 16`.
fn qrdmlsh_s16(a : Int, b : Int, c : Int) -> Int {
  sat_i16(
    ((a.to_int64() << 16) - 2L * b.to_int64() * c.to_int64() + 32768L) >> 16,
  )
}

///|
/// `TrilinearNeonQ0_15::interpolate` (one channel lane) on the cube starting
/// at `table` (in grid points).
fn trilinear_q0_15(
  lut : FixedArray[Int],
  table : Int,
  grid_size : Int,
  weights : FixedArray[BarycentricWeight],
  in_r : Int,
  in_g : Int,
  in_b : Int,
  ch : Int,
) -> Int {
  let lut_r = weights[in_r]
  let lut_g = weights[in_g]
  let lut_b = weights[in_b]
  let x = lut_r.x
  let y = lut_g.x
  let z = lut_b.x
  let x_n = lut_r.x_n
  let y_n = lut_g.x_n
  let z_n = lut_b.x_n
  let dr = lut_r.w
  let dg = lut_g.w
  let db = lut_b.w
  let fetch = (x : Int, y : Int, z : Int) => {
    lut[(table + x * grid_size * grid_size + y * grid_size + z) * 3 + ch]
  }
  let c000 = fetch(x, y, z)
  let c100 = fetch(x_n, y, z)
  let c010 = fetch(x, y_n, z)
  let c110 = fetch(x_n, y_n, z)
  let c001 = fetch(x, y, z_n)
  let c101 = fetch(x_n, y, z_n)
  let c011 = fetch(x, y_n, z_n)
  let c111 = fetch(x_n, y_n, z_n)
  let c00 = qrdmlah_s16(qrdmlsh_s16(c000, c000, dr), c100, dr)
  let c10 = qrdmlah_s16(qrdmlsh_s16(c010, c010, dr), c110, dr)
  let c01 = qrdmlah_s16(qrdmlsh_s16(c001, c001, dr), c101, dr)
  let c11 = qrdmlah_s16(qrdmlsh_s16(c011, c011, dr), c111, dr)
  let c0 = qrdmlah_s16(qrdmlsh_s16(c00, c00, dg), c10, dg)
  let c1 = qrdmlah_s16(qrdmlsh_s16(c01, c01, dg), c11, dg)
  qrdmlah_s16(qrdmlsh_s16(c0, c0, db), c1, db)
}
