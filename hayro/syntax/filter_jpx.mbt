// Port of `hayro-syntax/src/filter/jpx.rs` (on `hayro/jpeg2000`).

///|
fn ImageColorSpace::num_components(self : ImageColorSpace) -> Int {
  match self {
    Gray => 1
    Rgb => 3
    Cmyk => 4
    Unknown(num) => num
  }
}

///|
fn jpx_decode(data : BytesView, params : ImageDecodeParams) -> FilterResult? {
  let settings : @jpeg2000.DecodeSettings = {
    resolve_palette_indices: false,
    strict: false,
    target_resolution: params.target_dimension.map(d => {
      (d.0.reinterpret_as_uint(), d.1.reinterpret_as_uint())
    }),
  }
  let image = @jpeg2000.Image::new(data, settings) catch { _ => return None }
  let width = image.width()
  let height = image.height()
  let bpc = match params.bpc {
    Some(b) => b
    None => image.original_bit_depth()
  }
  let cs : ImageColorSpace = match image.color_space() {
    Gray => Gray
    RGB => Rgb
    CMYK => Cmyk
    Unknown(num_channels~) => Unknown(num_channels)
    Icc(num_channels=num_components, ..) =>
      match num_components {
        1 => Gray
        3 => Rgb
        4 => Cmyk
        _ => return None
      }
  }
  let has_alpha = image.has_alpha()
  let decoder_context = @jpeg2000.DecoderContext::default()
  let decoded = image.decode(decoder_context) catch { _ => return None }
  let bitmap = decoded.data_u8()
  let (data0, alpha0) : (Bytes, Bytes?) = if !has_alpha {
    (bitmap, None)
  } else {
    // Extract the alpha channel.
    let total_channels = (cs.num_components() + 1) & 0xFF
    let color_channels = FixedArray::make(
      bitmap.length() / total_channels * cs.num_components(),
      b'\x00',
    )
    let alpha_channel = FixedArray::make(
      bitmap.length() / total_channels,
      b'\x00',
    )
    let mut c = 0
    for i in 0..<(bitmap.length() / total_channels) {
      let sample = i * total_channels
      // `sample.split_last()`: the alpha is the last channel.
      alpha_channel[i] = bitmap[sample + total_channels - 1]
      for j in 0..<(total_channels - 1) {
        color_channels[c] = bitmap[sample + j]
        c += 1
      }
    }
    (
      Bytes::from_array(color_channels[:]),
      Some(Bytes::from_array(alpha_channel[:])),
    )
  }

  let mut data = data0
  let mut alpha = alpha0

  // The decoded image is always 8-bit, so if necessary we have to rescale
  // ourselves.
  if bpc != 8 {
    guard jpx_scale(data, bpc, cs.num_components(), width, height) is Some(d) else {
      return None
    }
    data = d
    alpha = match alpha {
      Some(alpha) => jpx_scale(alpha, bpc, cs.num_components(), width, height)
      None => None
    }
  }
  Some({
    data: data[:],
    image_data: Some({
      alpha,
      color_space: Some(cs),
      bits_per_component: bpc,
      width: width.reinterpret_as_int(),
      height: height.reinterpret_as_int(),
    }),
  })
}

///|
fn jpx_scale(
  data : Bytes,
  bit_per_component : Int,
  num_components : Int,
  width : UInt,
  height : UInt,
) -> Bytes? {
  if bit_per_component == 0 || bit_per_component > 32 {
    return None
  }
  let div_factor : Float = 255.0
  let mul_factor = ((1U << (bit_per_component & 31)) - 1).to_float()
  let bits_per_row = width.to_uint64() *
    num_components.to_uint64() *
    bit_per_component.to_uint64()
  let input_len = (bits_per_row + 7) / 8 * height.to_uint64()
  guard input_len <= 0x7FFFFFFFUL else { return None }
  let input = FixedArray::make(input_len.to_int(), b'\x00')
  let writer = BitWriter::new(input, 0, bit_per_component)
  let components_per_row = num_components * width.reinterpret_as_int()
  let rows = data.length() / components_per_row
  for row in 0..<rows {
    for i in 0..<components_per_row {
      let byte = data[row * components_per_row + i]
      let scaled = jpx_f32_to_u32(
        jpx_round_f32(Float::from_int(byte.to_int()) / div_factor * mul_factor),
      )
      guard writer.write(scaled) is Some(_) else { return None }
    }
    writer.align()
  }
  let final_pos = writer.cur_pos()
  // `input.truncate(final_pos)` (`final_pos` counts bits).
  let len = if final_pos < input.length() { final_pos } else { input.length() }
  Some(Bytes::from_array(input[:len]))
}

///|
/// `f32::round` (half-way cases away from zero).
fn jpx_round_f32(x : Float) -> Float {
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
/// `x as u32` for an `f32` (saturating, NaN maps to 0).
fn jpx_f32_to_u32(x : Float) -> UInt {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 4294967295.0 {
    0xFFFFFFFF
  } else {
    x.to_double().to_int64().reinterpret_as_uint64().to_uint()
  }
}
