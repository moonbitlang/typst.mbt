// Port of `moxcms::conversions::{lut4, lut3x3}` (mft1/mft2 pipelines) and the
// sample grids of `lut3x4`.

///|
fn LutStore::to_clut_f32(self : LutStore) -> FixedArray[Float] {
  match self {
    Store8(store) => store.map(uint8_number_to_float_fast)
    Store16(store) => store.map(uint16_number_to_float_fast)
  }
}

///|
/// `(grid as usize).safe_powi(n)?.safe_mul(m)?` on a 64-bit `usize`.
fn clut_length(grid : Int, n_in : Int, n_out : Int) -> Int raise CmsError {
  let mut v = 1UL
  for _ in 0..<n_in {
    v = v * grid.to_uint64()
    if v > 0x7fffffffUL {
      // Far beyond any table read from a profile (and beyond `Int`).
      raise OverflowingError
    }
  }
  v = v * n_out.to_uint64()
  if v > 0x7fffffffUL {
    raise OverflowingError
  }
  v.to_int()
}

///|
priv struct LutCurves {
  linearization : Array[ArrayView[Float]]
  clut : FixedArray[Float]
  grid_size : Int
  output : Array[ArrayView[Float]]
}

///|
/// `make_lut_4x3` / `make_lut_3x3`.
fn make_lut_nx3(lut : LutDataType, n : Int) -> LutCurves raise CmsError {
  let clut_len = clut_length(
    lut.num_clut_grid_points,
    lut.num_input_channels,
    lut.num_output_channels,
  )
  let entries_in = lut.num_input_table_entries
  let entries_out = lut.num_output_table_entries
  let check_clut = () => {
    let clut_table = lut.clut_table.to_clut_f32()
    if clut_table.length() != clut_len {
      raise MalformedClut({ size: clut_table.length(), expected: clut_len, })
    }
    clut_table
  }
  let check_lin = () => {
    let linearization_table = lut.input_table.to_clut_f32()
    if linearization_table.length() < entries_in * n {
      raise MalformedCurveLutTable({
        size: linearization_table.length(),
        expected: entries_in * n,
      })
    }
    linearization_table
  }
  // `make_lut_4x3` checks the CLUT first, `make_lut_3x3` the input curves.
  let (clut_table, linearization_table) = if n == 4 {
    let c = check_clut()
    (c, check_lin())
  } else {
    let l = check_lin()
    (check_clut(), l)
  }
  let gamma_table = lut.output_table.to_clut_f32()
  if gamma_table.length() < entries_out * 3 {
    raise MalformedCurveLutTable({
      size: gamma_table.length(),
      expected: entries_out * 3,
    })
  }
  let lin_all = Array::from_fixed_array(linearization_table)
  let out_all = Array::from_fixed_array(gamma_table)
  {
    linearization: Array::makei(n, i => {
      lin_all[i * entries_in:(i + 1) * entries_in]
    }),
    clut: clut_table,
    grid_size: lut.num_clut_grid_points,
    output: Array::makei(3, i => out_all[i * entries_out:(i + 1) * entries_out]),
  }
}

///|
fn create_lut4_norm_samples(samples : Int) -> FixedArray[Float] {
  let src = FixedArray::make(
    4 * samples * samples * samples * samples,
    Float::from_int(0),
  )
  let recpeq = Float::from_int(1) / Float::from_int(samples - 1)
  let mut i = 0
  for k in 0..<samples {
    for c in 0..<samples {
      for m in 0..<samples {
        for y in 0..<samples {
          src[i] = Float::from_int(c) * recpeq
          src[i + 1] = Float::from_int(m) * recpeq
          src[i + 2] = Float::from_int(y) * recpeq
          src[i + 3] = Float::from_int(k) * recpeq
          i += 4
        }
      }
    }
  }
  src
}

///|
fn create_lut4(
  samples : Int,
  lut : LutDataType,
  pcs : DataColorSpace,
) -> FixedArray[Float] raise CmsError {
  if lut.num_input_channels != 4 {
    raise UnsupportedProfileConnection
  }
  let src = create_lut4_norm_samples(samples)
  let dest = FixedArray::make(src.length() / 4 * 3, Float::from_int(0))
  // `stage_lut_4x3`
  let l = make_lut_nx3(lut, 4)
  let l_tbl = Hypercube::new(l.clut, l.grid_size, 3)
  // If Source PCS is LAB trilinear should be used; without the `options`
  // feature quadlinear interpolation is used in every case.
  ignore(pcs)
  let n = src.length() / 4
  for p in 0..<n {
    let linear_x = lut_interp_linear_float(src[4 * p], l.linearization[0])
    let linear_y = lut_interp_linear_float(src[4 * p + 1], l.linearization[1])
    let linear_z = lut_interp_linear_float(src[4 * p + 2], l.linearization[2])
    let linear_w = lut_interp_linear_float(src[4 * p + 3], l.linearization[3])
    let clut = l_tbl.quadlinear_vec3(linear_x, linear_y, linear_z, linear_w)
    dest[3 * p] = lut_interp_linear_float(clut.0, l.output[0])
    dest[3 * p + 1] = lut_interp_linear_float(clut.1, l.output[1])
    dest[3 * p + 2] = lut_interp_linear_float(clut.2, l.output[2])
  }
  dest
}

///|
fn create_lut3_samples_norm(samples : Int) -> FixedArray[Float] {
  let src = FixedArray::make(
    3 * samples * samples * samples,
    Float::from_int(0),
  )
  let scale = Float::from_int(1) / (Float::from_int(samples) - 1.0)
  let mut i = 0
  for x in 0..<samples {
    for y in 0..<samples {
      for z in 0..<samples {
        src[i] = Float::from_int(x) * scale
        src[i + 1] = Float::from_int(y) * scale
        src[i + 2] = Float::from_int(z) * scale
        i += 3
      }
    }
  }
  src
}

///|
fn create_lut3x3(
  lut : LutDataType,
  src : FixedArray[Float],
  pcs : DataColorSpace,
) -> FixedArray[Float] raise CmsError {
  if lut.num_input_channels != 3 || lut.num_output_channels != 3 {
    raise UnsupportedProfileConnection
  }
  let dest = FixedArray::make(src.length(), Float::from_int(0))
  // `stage_lut_3x3`
  let l = make_lut_nx3(lut, 3)
  let l_tbl = Cube::new(l.clut, l.grid_size, 3)
  ignore(pcs)
  let n = src.length() / 3
  for p in 0..<n {
    let linear_x = lut_interp_linear_float(src[3 * p], l.linearization[0])
    let linear_y = lut_interp_linear_float(src[3 * p + 1], l.linearization[1])
    let linear_z = lut_interp_linear_float(src[3 * p + 2], l.linearization[2])
    let clut = l_tbl.trilinear_vec3(linear_x, linear_y, linear_z)
    dest[3 * p] = lut_interp_linear_float(clut.0, l.output[0])
    dest[3 * p + 1] = lut_interp_linear_float(clut.1, l.output[1])
    dest[3 * p + 2] = lut_interp_linear_float(clut.2, l.output[2])
  }
  dest
}
