// Port of `hayro-syntax/src/filter/dct.rs` (on the zune-jpeg port in
// `codecs/`).

///|
/// Rust's saturating `f32 as u8` cast (NaN becomes 0).
fn f32_as_u8(v : Float) -> Int {
  if v.is_nan() {
    0
  } else if v <= 0.0 {
    0
  } else if v >= 255.0 {
    255
  } else {
    v.to_int()
  }
}

///|
fn dct_decode(
  data : BytesView,
  params : Dict,
  image_params : ImageDecodeParams,
) -> FilterResult? {
  if image_params.width.reinterpret_as_uint() > 65535 ||
    image_params.height.reinterpret_as_uint() > 65535 {
    return None
  }

  // Some PDFs have weird JPEGs where the JPEG metadata is completely wrong
  // (for example indicating that one of the dimensions is u16::MAX), but the
  // metadata in the PDF image dictionary is correct. Therefore, we first
  // validate the JPEG metadata and patch the data if any of the dimensions
  // are too large (if they are too small, they will just be padded later on).
  guard maybe_patch_jpeg_dimensions(data, image_params) is Some(data) else {
    return None
  }
  let options : @codecs.DecoderOptions = {
    ..@codecs.DecoderOptions::default(),
    max_width: 65535,
    max_height: 65535,
  }
  let decoder = @codecs.JpegDecoder::new_with_options(data, options)
  decoder.decode_headers() catch {
    _ => return None
  }
  let color_transform : Byte? = params.get("ColorTransform")
  let input_color_space = decoder.input_colorspace().unwrap()
  let mut out_colorspace : @codecs.ColorSpace = match
    image_params.num_components {
    Some(num_components) if !(num_components is (1 | 3 | 4)) => {
      // `NonZeroU32::new(num_components as u32)?`
      if num_components == 0 {
        return None
      }
      MultiBand(num_components)
    }
    _ =>
      match input_color_space {
        YCbCr =>
          match color_transform {
            None | Some(1) => RGB
            _ => YCbCr
          }
        RGB => RGB
        Luma => Luma
        // TODO: Find test case with color transform on cmyk
        CMYK => CMYK
        YCCK => YCCK
        _ => RGB
      }
  }

  // In case image had APP14 marker, we might have to override the colorspace.
  if input_color_space == CMYK && decoder.info_components().unwrap() == 3 {
    out_colorspace = RGB
  }
  decoder.set_options({ ..@codecs.DecoderOptions::default(), out_colorspace, })
  let decoded = decoder.decode() catch { _ => return None }
  let decoded = if out_colorspace == YCCK {
    // See <https://github.com/mozilla/pdf.js/blob/69595a29192b7704733404a42a2ebb537601117b/src/core/jpg.js#L1331>
    let buf = decoded.to_fixedarray()
    let mut i = 0
    while i < buf.length() {
      // (`chunks_mut(4)`: a trailing chunk may be shorter.)
      let n = @cmp.minimum(4, buf.length() - i)
      let y = buf[i].to_float()
      let cb : Float = if n > 1 { buf[i + 1].to_float() } else { 0 }
      let cr : Float = if n > 2 { buf[i + 2].to_float() } else { 0 }
      if n > 2 {
        buf[i] = f32_as_u8((434.456 : Float) - y - (1.402 : Float) * cr).to_byte()
        buf[i + 1] = f32_as_u8(
          (119.541 : Float) - y + (0.344 : Float) * cb + (0.714 : Float) * cr,
        ).to_byte()
        buf[i + 2] = f32_as_u8((481.816 : Float) - y - (1.772 : Float) * cb).to_byte()
      } else {
        // upstream panics on the out of bounds index
        panic()
      }
      i += 4
    }
    Bytes::from_array(buf)
  } else {
    decoded
  }
  let (width, height) = decoder.dimensions().unwrap()
  let image_data : ImageData = {
    alpha: None,
    color_space: match out_colorspace {
      RGB | YCbCr => Some(Rgb)
      Luma => Some(Gray)
      YCCK | CMYK => Some(Cmyk)
      MultiBand(_) => None
    },
    bits_per_component: 8,
    width,
    height,
  }
  Some({ data: decoded[:], image_data: Some(image_data), })
}

///|
fn maybe_patch_jpeg_dimensions(
  data : BytesView,
  image_params : ImageDecodeParams,
) -> BytesView? {
  guard find_sof_marker(data) is Some(sof_offset) else { return None }
  let height_offset = sof_offset + 5
  let width_offset = sof_offset + 7
  guard height_offset + 1 < data.length() && width_offset + 1 < data.length() else {
    return None
  }
  let jpeg_height = (data[height_offset].to_int() << 8) |
    data[height_offset + 1].to_int()
  let jpeg_width = (data[width_offset].to_int() << 8) |
    data[width_offset + 1].to_int()
  let jpeg_area = jpeg_width.to_uint64() * jpeg_height.to_uint64()
  let image_area = image_params.width.reinterpret_as_uint().to_uint64() *
    image_params.height.reinterpret_as_uint().to_uint64()
  let need_patch = jpeg_area > image_area
  if !need_patch {
    return Some(data)
  }
  // (`as u16`)
  let target_w = image_params.width & 0xFFFF
  let target_h = image_params.height & 0xFFFF
  let patched = data.to_fixedarray()
  patched[height_offset] = (target_h >> 8).to_byte()
  patched[height_offset + 1] = (target_h & 0xFF).to_byte()
  patched[width_offset] = (target_w >> 8).to_byte()
  patched[width_offset + 1] = (target_w & 0xFF).to_byte()
  Some(Bytes::from_array(patched)[:])
}

///|
fn find_sof_marker(data : BytesView) -> Int? {
  let mut i = 0
  while i + 1 < data.length() {
    if data[i] != 0xFF {
      i += 1
      continue
    }
    let marker = data[i + 1].to_int()

    // Note: Not sure if 100% correct/robust, is AI-generated.
    match marker {
      // All SOF markers carry dimensions: SOF0–SOF15, excluding
      // 0xC4 (DHT), 0xC8 (JPG), 0xCC (DAC) which are not frame markers.
      0xC0..=0xCF if marker != 0xC4 && marker != 0xC8 && marker != 0xCC =>
        return Some(i)
      // Skip padding bytes (0xFF followed by 0xFF).
      0xFF => {
        i += 1
        continue
      }
      // SOI (0xD8), EOI (0xD9), TEM (0x01) and stuffed byte (0x00)
      // are standalone markers with no payload.
      0xD8 | 0xD9 | 0x01 | 0x00 => {
        i += 2
        continue
      }
      // All other markers have a 2-byte length field — skip over them.
      _ => {
        guard i + 3 < data.length() else { return None }
        let seg_len = (data[i + 2].to_int() << 8) | data[i + 3].to_int()
        i = i + 2 + seg_len
      }
    }
  }
  None
}
