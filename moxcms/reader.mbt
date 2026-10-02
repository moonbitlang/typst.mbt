// Port of `moxcms::reader` (ICC tag readers).
//
// Offsets and sizes are `UInt64` (Rust `usize` on a 64-bit target); the
// `safe_add`/`safe_mul` overflow checks of upstream can never fail for the
// 32-bit inputs involved unless noted.

///|
/// Produces the nearest float to `a` with a maximum error of 1/1024.
fn s15_fixed16_number_to_float(a : Int) -> Float {
  Float::from_int(a) / 65536.0
}

///|
fn s15_fixed16_number_to_double(a : Int) -> Double {
  a.to_double() / 65536.0
}

///|
fn uint16_number_to_float(a : UInt) -> Float {
  Float::from_uint(a) / 65535.0
}

///|
fn uint16_number_to_float_fast(a : Int) -> Float {
  Float::from_int(a) * (Float::from_int(1) / 65535.0)
}

///|
fn uint8_number_to_float_fast(a : Int) -> Float {
  Float::from_int(a) * (Float::from_int(1) / 255.0)
}

///|
fn trim_end_nul(s : String) -> String {
  let mut end = s.length()
  while end > 0 && s.code_unit_at(end - 1) == 0 {
    end -= 1
  }
  s[:end].to_owned()
}

///|
/// `String::from_utf8_lossy`.
fn utf8_lossy(b : BytesView) -> String {
  @utf8.decode_lossy(b, ignore_bom=false)
}

///|
/// `String::from_utf16_lossy` of big-endian UTF-16 data (an odd trailing
/// byte is ignored, like `chunks_exact(2)`).
fn utf16be_lossy(b : BytesView) -> String {
  let units = Array::makei(b.length() / 2, i => {
    (b[2 * i].to_int() << 8) | b[2 * i + 1].to_int()
  })
  let sb = StringBuilder()
  let mut i = 0
  while i < units.length() {
    let u = units[i]
    if u >= 0xd800 && u <= 0xdbff {
      if i + 1 < units.length() &&
        units[i + 1] >= 0xdc00 &&
        units[i + 1] <= 0xdfff {
        let c = 0x10000 + ((u - 0xd800) << 10) + (units[i + 1] - 0xdc00)
        sb.write_char(c.unsafe_to_char())
        i += 2
        continue
      }
      sb.write_char('\u{FFFD}')
    } else if u >= 0xdc00 && u <= 0xdfff {
      sb.write_char('\u{FFFD}')
    } else {
      sb.write_char(u.unsafe_to_char())
    }
    i += 1
  }
  sb.to_string()
}

///|
fn sub(slice : BytesView, start : UInt64, end : UInt64) -> BytesView {
  slice[start.to_int():end.to_int()]
}

///|
fn len64(slice : BytesView) -> UInt64 {
  slice.length().to_uint64()
}

///|
/// Parses the Unicode section of a desc tag at `unicode_offset`. Returns
/// `(language_code, string)`, or `None` if truncated.
fn read_desc_unicode(
  tag : BytesView,
  unicode_offset : UInt64,
) -> (UInt, String)? {
  if len64(tag) < unicode_offset + 8UL {
    return None
  }
  let header = sub(tag, unicode_offset, unicode_offset + 8UL)
  let language_code = be_u32(header, 0)
  let unicode_length = be_u32(header, 4).to_uint64()
  if unicode_length == 0UL {
    return Some((language_code, ""))
  }
  let byte_length = unicode_length * 2UL
  let str_start = unicode_offset + 8UL
  if len64(tag) < str_start + byte_length {
    return None
  }
  let uc_data = sub(tag, str_start, str_start + byte_length)
  Some((language_code, trim_end_nul(utf16be_lossy(uc_data))))
}

///|
fn read_lut_type(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> LutType raise CmsError {
  let tag_size = if tag_size == 0UL {
    tag_size_const.to_uint64()
  } else {
    tag_size
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < 48 {
    raise InvalidProfile
  }
  LutType::try_from(be_u32(tag, 0))
}

///|
fn read_viewing_conditions(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> ViewingConditions? raise CmsError {
  if tag_size < 36UL {
    return None
  }
  if len64(slice) < entry + 36UL {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, entry + 36UL)
  let tag_type = TagTypeDefinition::from(be_u32(tag, 0))
  // Ignore unknown
  if tag_type != DefViewingConditions {
    return None
  }
  let illuminant = Xyz::new(
    s15_fixed16_number_to_float(be_i32(tag, 8)),
    s15_fixed16_number_to_float(be_i32(tag, 12)),
    s15_fixed16_number_to_float(be_i32(tag, 16)),
  )
  let surround = Xyz::new(
    s15_fixed16_number_to_float(be_i32(tag, 20)),
    s15_fixed16_number_to_float(be_i32(tag, 24)),
    s15_fixed16_number_to_float(be_i32(tag, 28)),
  )
  let observer = StandardObserver::from(be_u32(tag, 32))
  Some({ illuminant, surround, observer, })
}

///|
fn read_string_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> ProfileText? raise CmsError {
  let tag_size = if tag_size == 0UL {
    tag_size_const.to_uint64()
  } else {
    tag_size
  }
  if tag_size < 4UL {
    return None
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < 8 {
    return None
  }
  let tag_type = TagTypeDefinition::from(be_u32(tag, 0))
  // Ignore unknown
  if tag_type == Text {
    let str = trim_end_nul(utf8_lossy(tag[8:]))
    return Some(PlainString(str))
  } else if tag_type == MultiLocalizedUnicode {
    if tag.length() < 28 {
      raise InvalidProfile
    }
    let records_count = be_u32(tag, 8).to_uint64()
    let primary_language_code = utf8_lossy(tag[16:18])
    let primary_country_code = utf8_lossy(tag[18:20])
    let first_string_record_length = be_u32(tag, 20).to_uint64()
    let first_record_offset = be_u32(tag, 24).to_uint64()
    if len64(tag) < first_record_offset + first_string_record_length {
      return None
    }
    let resliced = sub(
      tag,
      first_record_offset,
      first_record_offset + first_string_record_length,
    )
    let string_record = utf16be_lossy(resliced)
    let records = [
      {
        language: primary_language_code,
        country: primary_country_code,
        value: string_record,
      },
    ]
    let mut record = 1UL
    while record < records_count {
      // Localizable header must be at least 12 bytes
      let localizable_header_offset = if record == 1UL {
        28UL
      } else {
        28UL + 12UL * (record - 1UL)
      }
      if len64(tag) < localizable_header_offset + 12UL {
        raise InvalidProfile
      }
      let choked = sub(
        tag,
        localizable_header_offset,
        localizable_header_offset + 12UL,
      )
      let language_code = utf8_lossy(choked[0:2])
      let country_code = utf8_lossy(choked[2:4])
      let record_length = be_u32(choked, 4).to_uint64()
      let string_offset = be_u32(choked, 8).to_uint64()
      if len64(tag) < string_offset + record_length {
        return None
      }
      let resliced = sub(tag, string_offset, string_offset + record_length)
      let string_record = utf16be_lossy(resliced)
      records.push({
        country: country_code,
        language: language_code,
        value: string_record,
      })
      record += 1UL
    }
    return Some(Localizable(records))
  } else if tag_type == Description {
    if tag.length() < 12 {
      raise InvalidProfile
    }
    let ascii_length = be_u32(tag, 8).to_uint64()
    let ascii_end = 12UL + ascii_length
    if len64(tag) < ascii_end {
      raise InvalidProfile
    }
    let sliced = sub(tag, 12UL, ascii_end)
    let ascii_string = trim_end_nul(utf8_lossy(sliced))
    // Tolerate truncated desc tags — the Unicode and ScriptCode sections may
    // be missing.
    let unicode_offset = ascii_end
    let (unicode_code, unicode_string) = read_desc_unicode(tag, unicode_offset).unwrap_or(
      (0U, ""),
    )
    return Some(
      Description({
        ascii_string,
        unicode_language_code: unicode_code,
        unicode_string,
        mac_string: "",
        script_code_code: -1,
      }),
    )
  }
  None
}

///|
fn read_lut_table_f32(table : BytesView, lut_type : LutType) -> LutStore {
  if lut_type == Lut16 {
    Store16(FixedArray::makei(table.length() / 2, i => be_u16(table, 2 * i)))
  } else if lut_type == Lut8 {
    Store8(FixedArray::makei(table.length(), i => table[i].to_int()))
  } else {
    abort(
      "This should never happen, report to https://github.com/awxkee/moxcms",
    )
  }
}

///|
fn read_nested_tone_curves(
  slice : BytesView,
  offset : UInt64,
  length : Int,
) -> Array[ToneReprCurve] raise CmsError {
  let mut curve_offset = offset
  let curves = []
  for _ in 0..<length {
    if len64(slice) < curve_offset + 12UL {
      raise InvalidProfile
    }
    let tag_size = Ref(0UL)
    let new_curve = read_trc_tag(slice, curve_offset, 0UL, tag_size)
    match new_curve {
      None => raise InvalidProfile
      Some(curve) => curves.push(curve)
    }
    curve_offset += tag_size.val
    // 4 byte aligned
    if curve_offset % 4UL != 0UL {
      curve_offset += 4UL - curve_offset % 4UL
    }
  }
  curves
}

///|
fn read_lut_abm_type(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
  to_pcs : Bool,
) -> LutWarehouse? raise CmsError {
  if tag_size < 48UL {
    return None
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < 48 {
    raise InvalidProfile
  }
  let tag_type_definition = TagTypeDefinition::from(be_u32(tag, 0))
  if tag_type_definition != MabLut && tag_type_definition != MbaLut {
    return None
  }
  let in_channels = tag[8].to_int()
  let out_channels = tag[9].to_int()
  if in_channels > 4 && out_channels > 4 {
    return None
  }
  let a_curve_offset = be_u32(tag, 28).to_uint64()
  let clut_offset = be_u32(tag, 24).to_uint64()
  let m_curve_offset = be_u32(tag, 20).to_uint64()
  let matrix_offset = be_u32(tag, 16).to_uint64()
  let b_curve_offset = be_u32(tag, 12).to_uint64()
  let (transform, bias) = if matrix_offset != 0UL {
    let matrix_end = matrix_offset + 48UL
    if len64(tag) < matrix_end {
      raise InvalidProfile
    }
    let m_tag = sub(tag, matrix_offset, matrix_end)
    let bias = read_vector_3d(m_tag[36:48])
    let transform = read_matrix_3d(m_tag)
    (transform, bias)
  } else {
    (Matrix3d::identity(), (Default::default() : Vector3d))
  }
  let grid_points = FixedArray::make(16, 0)
  let clut_table = if clut_offset != 0UL {
    // Check if CLUT formed correctly
    if clut_offset + 20UL > len64(tag) {
      raise InvalidProfile
    }
    let clut_sizes_slice = sub(tag, clut_offset, clut_offset + 16UL)
    for i in 0..<16 {
      grid_points[i] = clut_sizes_slice[i].to_int()
    }
    // `u32::safe_mul`.
    let mut clut_size = 1UL
    let u32_max = 0xffffffffUL
    for i in 0..<@cmp.minimum(in_channels, 16) {
      clut_size = clut_size * grid_points[i].to_uint64()
      if clut_size > u32_max {
        raise OverflowingError
      }
    }
    clut_size = clut_size * out_channels.to_uint64()
    if clut_size > u32_max {
      raise OverflowingError
    }
    if clut_size == 0UL {
      raise IncorrectlyFormedLut("Clut size was zero when it shouldn't")
    }
    if clut_size > 10000000UL {
      raise IncorrectlyFormedLut(
        "Clut size exceeded 10_000_000 points what is too big",
      )
    }
    // check LUT dimensions
    let mut grid_stride = 1UL
    let mut last_index = 0UL
    let mut i = @cmp.minimum(in_channels, 16) - 1
    while i >= 0 {
      let dim = grid_points[i].to_uint64()
      if dim == 0UL {
        raise IncorrectlyFormedLut("One of grid dimensions is zero")
      }
      // Overflow is impossible here: all values are far below 2^64.
      last_index = (dim - 1UL) * grid_stride + last_index
      // Multiply stride by next dimension
      grid_stride = grid_stride * dim
      i -= 1
    }
    last_index = last_index * out_channels.to_uint64()
    if last_index >= clut_size {
      raise IncorrectlyFormedLut(
        "Clut size should be at least \{last_index}, but it was \{last_index}",
      )
    }
    let clut_offset20 = clut_offset + 20UL
    let clut_header = sub(tag, clut_offset, clut_offset20)
    let entry_size = clut_header[16].to_int()
    if entry_size != 1 && entry_size != 2 {
      raise InvalidProfile
    }
    let clut_bytes = clut_size * entry_size.to_uint64()
    if clut_bytes > u32_max {
      raise OverflowingError
    }
    let clut_end = clut_offset20 + clut_bytes
    if len64(tag) < clut_end {
      raise InvalidProfile
    }
    let shaped_clut_table = sub(tag, clut_offset20, clut_end)
    Some(
      read_lut_table_f32(
        shaped_clut_table,
        if entry_size == 1 {
          Lut8
        } else {
          Lut16
        },
      ),
    )
  } else {
    None
  }
  let a_curves = if a_curve_offset == 0UL {
    []
  } else {
    read_nested_tone_curves(
      tag,
      a_curve_offset,
      if to_pcs {
        in_channels
      } else {
        out_channels
      },
    )
  }
  let m_curves = if m_curve_offset == 0UL {
    []
  } else {
    read_nested_tone_curves(
      tag,
      m_curve_offset,
      if to_pcs {
        out_channels
      } else {
        in_channels
      },
    )
  }
  let b_curves = if b_curve_offset == 0UL {
    []
  } else {
    read_nested_tone_curves(
      tag,
      b_curve_offset,
      if to_pcs {
        out_channels
      } else {
        in_channels
      },
    )
  }
  Some(
    Multidimensional({
      num_input_channels: in_channels,
      num_output_channels: out_channels,
      matrix: transform,
      clut: clut_table,
      a_curves,
      b_curves,
      m_curves,
      grid_points,
      bias,
    }),
  )
}

///|
fn read_lut_a_to_b_type(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> LutWarehouse? raise CmsError {
  if tag_size < 48UL {
    return None
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < 48 {
    raise InvalidProfile
  }
  let lut_type = LutType::try_from(be_u32(tag, 0))
  guard lut_type == Lut8 || lut_type == Lut16 else { abort("unreachable") }
  if lut_type == Lut16 && tag.length() < 52 {
    raise InvalidProfile
  }
  let num_input_table_entries = if lut_type == Lut8 {
    256
  } else {
    be_u16(tag, 48)
  }
  let num_output_table_entries = if lut_type == Lut8 {
    256
  } else {
    be_u16(tag, 50)
  }
  if num_input_table_entries < 2 ||
    num_input_table_entries > 4096 ||
    num_output_table_entries < 2 ||
    num_output_table_entries > 4096 {
    raise InvalidProfile
  }
  let input_offset = if lut_type == Lut8 { 48 } else { 52 }
  let entry_size = if lut_type == Lut8 { 1 } else { 2 }
  let in_chan = tag[8].to_int()
  let out_chan = tag[9].to_int()
  let is_3_to_4 = in_chan == 3 || out_chan == 4
  let is_4_to_3 = in_chan == 4 || out_chan == 3
  if !is_3_to_4 && !is_4_to_3 {
    raise InvalidProfile
  }
  let grid_points = tag[10].to_int()
  // `(grid_points as u32).safe_powi(in_chan as u32)`
  let mut clut_size = 1UL
  for _ in 0..<in_chan {
    clut_size = clut_size * grid_points.to_uint64()
    if clut_size > 0xffffffffUL {
      raise OverflowingError
    }
  }
  if clut_size < 1UL || clut_size > 10000000UL {
    raise InvalidProfile
  }
  let transform = read_matrix_3d(tag[12:48])
  // `u16::safe_mul`.
  let lut_input_size = num_input_table_entries * in_chan
  if lut_input_size > 0xffff {
    raise OverflowingError
  }
  let linearization_table_end = (lut_input_size * entry_size + input_offset).to_uint64()
  if len64(tag) < linearization_table_end {
    raise InvalidProfile
  }
  let shaped_input_table = sub(
    tag,
    input_offset.to_uint64(),
    linearization_table_end,
  )
  let linearization_table = read_lut_table_f32(shaped_input_table, lut_type)
  let clut_offset = linearization_table_end
  let clut_data_size = clut_size * out_chan.to_uint64() * entry_size.to_uint64()
  if len64(tag) < clut_offset + clut_data_size {
    raise InvalidProfile
  }
  let shaped_clut_table = sub(tag, clut_offset, clut_offset + clut_data_size)
  let clut_table = read_lut_table_f32(shaped_clut_table, lut_type)
  let output_offset = clut_offset + clut_data_size
  let output_size = num_output_table_entries.to_uint64() * out_chan.to_uint64()
  let shaped_output = output_offset + output_size * entry_size.to_uint64()
  if len64(tag) < shaped_output {
    raise InvalidProfile
  }
  let shaped_output_table = sub(tag, output_offset, shaped_output)
  let gamma_table = read_lut_table_f32(shaped_output_table, lut_type)
  Some(
    Lut({
      num_input_table_entries,
      num_output_table_entries,
      num_input_channels: in_chan,
      num_output_channels: out_chan,
      num_clut_grid_points: grid_points,
      matrix: transform,
      input_table: linearization_table,
      clut_table,
      output_table: gamma_table,
      lut_type,
    }),
  )
}

///|
fn read_lut_tag(
  slice : BytesView,
  tag_entry : UInt64,
  tag_size : UInt64,
) -> LutWarehouse? raise CmsError {
  let lut_type = read_lut_type(slice, tag_entry, tag_size)
  if lut_type == Lut8 || lut_type == Lut16 {
    read_lut_a_to_b_type(slice, tag_entry, tag_size)
  } else if lut_type == LutMba || lut_type == LutMab {
    read_lut_abm_type(slice, tag_entry, tag_size, lut_type == LutMab)
  } else {
    None
  }
}

///|
fn read_trc_tag_s(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> ToneReprCurve? raise CmsError {
  read_trc_tag(slice, entry, tag_size, Ref(0UL))
}

///|
fn read_trc_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
  read_size : Ref[UInt64],
) -> ToneReprCurve? raise CmsError {
  if len64(slice) < entry + 4UL {
    return None
  }
  let small_tag = sub(slice, entry, entry + 4UL)
  // We require always recognize tone curves.
  let curve_type = TagTypeDefinition::from(be_u32(small_tag, 0))
  if tag_size != 0UL && tag_size < tag_size_const.to_uint64() {
    return None
  }
  let last_tag_offset = if tag_size != 0UL {
    tag_size + entry
  } else {
    len64(slice)
  }
  if last_tag_offset > len64(slice) {
    raise MalformedTrcCurve("Data exhausted")
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < tag_size_const {
    raise MalformedTrcCurve("Data exhausted")
  }
  if curve_type == LutToneCurve {
    let entry_count = be_u32(tag, 8).to_uint64()
    if entry_count == 0UL {
      return Some(Lut([]))
    }
    if entry_count > 40000UL {
      raise CurveLutIsTooLarge
    }
    let curve_end = entry_count * 2UL + 12UL
    if len64(tag) < curve_end {
      raise MalformedTrcCurve("Curve end ends to early")
    }
    let n = entry_count.to_int()
    let curve_values = FixedArray::makei(n, i => be_u16(tag, 12 + 2 * i))
    read_size.val = curve_end
    Some(Lut(curve_values))
  } else if curve_type == ParametricToneCurve {
    let entry_count = be_u16(tag, 8)
    if entry_count > 4 {
      raise MalformedTrcCurve("Parametric curve has unknown entries count")
    }
    let count_to_length = [1, 3, 4, 5, 7] // PARAMETRIC_CURVE_TYPE
    let n = count_to_length[entry_count]
    if tag.length() < 12 + n * 4 {
      raise MalformedTrcCurve(
        "Parametric curve has unknown entries count exhaust data too early",
      )
    }
    let params = FixedArray::makei(n, i => {
      s15_fixed16_number_to_float(be_i32(tag, 12 + 4 * i))
    })
    if entry_count == 1 || entry_count == 2 {
      // we have a type 1 or type 2 function that has a division by `a`
      let a = params[1]
      if a == 0.0 {
        raise ParametricCurveZeroDivision
      }
    }
    read_size.val = (12 + n * 4).to_uint64()
    Some(Parametric(params))
  } else {
    raise MalformedTrcCurve("Unknown parametric curve tag")
  }
}

///|
fn read_chad_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> Matrix3d? raise CmsError {
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  if len64(slice) - entry < 8UL {
    raise InvalidProfile
  }
  if tag_size < 8UL {
    return None
  }
  if (tag_size - 8UL) / 4UL != 9UL {
    return None
  }
  let tag0 = sub(slice, entry, entry + 8UL)
  let c_type = TagTypeDefinition::from(be_u32(tag0, 0))
  if c_type != S15Fixed16Array {
    raise InvalidProfile
  }
  if slice.length() < 9 * 4 + 8 {
    raise InvalidProfile
  }
  let tag = sub(slice, entry + 8UL, last_tag_offset)
  if tag.length() != 36 {
    raise InvalidProfile
  }
  Some(read_matrix_3d(tag))
}

///|
fn read_tech_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> TechnologySignatures? raise CmsError {
  if tag_size < tag_size_const.to_uint64() {
    raise InvalidProfile
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, entry + 12UL)
  let def = TagTypeDefinition::from(be_u32(tag, 0))
  if def == Signature {
    return Some({ signature: be_u32(tag, 8), })
  }
  None
}

///|
fn read_date_time_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> ColorDateTime? raise CmsError {
  if tag_size < 20UL {
    return None
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, entry + 20UL)
  let def = TagTypeDefinition::from(be_u32(tag, 0))
  if def == DateTime {
    // Upstream reads bytes 8..20 of the whole profile here.
    let tag_value = slice[8:20]
    return Some(ColorDateTime::new_from_slice(tag_value))
  }
  None
}

///|
fn read_meas_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> Measurement? raise CmsError {
  if tag_size < tag_size_const.to_uint64() {
    return None
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, entry + 12UL)
  let def = TagTypeDefinition::from(be_u32(tag, 0))
  if def != Measurement {
    return None
  }
  if 36UL + entry > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, entry + 36UL)
  let observer = StandardObserver::from(be_u32(tag, 8))
  let x = s15_fixed16_number_to_float(be_i32(tag, 12))
  let y = s15_fixed16_number_to_float(be_i32(tag, 16))
  let z = s15_fixed16_number_to_float(be_i32(tag, 20))
  let geometry = MeasurementGeometry::from(be_u32(tag, 24))
  let flare = uint16_number_to_float(be_u32(tag, 28))
  let illuminant = StandardIlluminant::from(be_u32(tag, 32))
  Some({ flare, illuminant, geometry, observer, backing: Xyz::new(x, y, z), })
}

///|
fn read_xyz_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> Xyzd raise CmsError {
  if tag_size < tag_size_const.to_uint64() {
    return (Default::default() : Xyzd)
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, entry + 12UL)
  let def = TagTypeDefinition::from(be_u32(tag, 0))
  if def != Xyz {
    return (Default::default() : Xyzd)
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < 20 {
    raise InvalidProfile
  }
  let x = s15_fixed16_number_to_double(be_i32(tag, 8))
  let y = s15_fixed16_number_to_double(be_i32(tag, 12))
  let z = s15_fixed16_number_to_double(be_i32(tag, 16))
  { x, y, z, }
}

///|
fn read_cicp_tag(
  slice : BytesView,
  entry : UInt64,
  tag_size : UInt64,
) -> CicpProfile? raise CmsError {
  if tag_size < tag_size_const.to_uint64() {
    return None
  }
  let last_tag_offset = tag_size + entry
  if last_tag_offset > len64(slice) {
    raise InvalidProfile
  }
  let tag = sub(slice, entry, last_tag_offset)
  if tag.length() < 12 {
    raise InvalidProfile
  }
  let def = TagTypeDefinition::from(be_u32(tag, 0))
  if def != Cicp {
    return None
  }
  let primaries = CicpColorPrimaries::try_from(tag[8].to_int())
  let transfer_characteristics = TransferCharacteristics::try_from(
    tag[9].to_int(),
  )
  let matrix_coefficients = MatrixCoefficients::try_from(tag[10].to_int())
  let full_range = tag[11] == 1
  Some({
    color_primaries: primaries,
    transfer_characteristics,
    matrix_coefficients,
    full_range,
  })
}

///|
/// `helpers::read_matrix_3d`.
fn read_matrix_3d(arr : BytesView) -> Matrix3d raise CmsError {
  if arr.length() < 36 {
    raise InvalidProfile
  }
  {
    v: FixedArray::makei(9, i => {
      s15_fixed16_number_to_double(be_i32(arr, 4 * i))
    }),
  }
}

///|
/// `helpers::read_vector_3d`.
fn read_vector_3d(arr : BytesView) -> Vector3d raise CmsError {
  if arr.length() < 12 {
    raise InvalidProfile
  }
  {
    v0: s15_fixed16_number_to_double(be_i32(arr, 0)),
    v1: s15_fixed16_number_to_double(be_i32(arr, 4)),
    v2: s15_fixed16_number_to_double(be_i32(arr, 8)),
  }
}
