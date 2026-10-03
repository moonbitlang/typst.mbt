// Port of `hayro-jpeg2000/src/lib.rs` (hayro rev d8e24e2, hayro-jpeg2000
// 0.4.0, features `std` + `simd` on aarch64 as hayro uses it; the `image`
// integration is not ported): a memory-safe JPEG 2000 decoder.
//
// `hayro-jpeg2000` can decode both raw JPEG 2000 codestreams (`.j2c`) and images wrapped
// inside the JP2 container format. The decoder supports the vast majority of features
// defined in the JPEG2000 core coding system (ISO/IEC 15444-1) as well as some color
// spaces from the extensions (ISO/IEC 15444-2). There are still some missing pieces
// for some "obscure" features(like for example support for progression order
// changes in tile-parts), but all features that actually commonly appear in real-life
// images should be supported (if not, please open an issue!).
//
// The decoder abstracts away most of the internal complexity of JPEG2000
// and yields decoded image components, which can be inspected directly or packed
// into a simple 8-bit image with either greyscale, RGB, CMYK or an ICC-based color
// space.
//
// Module names become file names (`j2c/bitplane.rs` -> `j2c_bitplane.mbt`);
// `log.rs` (no-op logging macros without the `logging` feature) is not
// ported. Rust's `u32` arithmetic is reproduced with `UInt` (wrapping, as in
// a release build), `u8`/`u16` values are `Int`s.

///|
/// JP2 signature box: 00 00 00 0C 6A 50 20 20
let jp2_magic : Bytes = b"\x00\x00\x00\x0C\x6A\x50\x20\x20"

///|
/// Codestream signature: FF 4F FF 51 (SOC + SIZ markers)
let codestream_magic : Bytes = b"\xFF\x4F\xFF\x51"

///|
/// Settings to apply during decoding.
pub(all) struct DecodeSettings {
  /// Whether palette indices should be resolved.
  ///
  /// JPEG2000 images can be stored in two different ways. First, by storing
  /// RGB values (depending on the color space) for each pixel. Secondly, by
  /// only storing a single index for each channel, and then resolving the
  /// actual color using the index.
  ///
  /// If you disable this option, in case you have an image with palette
  /// indices, they will not be resolved, but instead a grayscale image
  /// will be returned, with each pixel value corresponding to the palette
  /// index of the location.
  resolve_palette_indices : Bool
  /// Whether strict mode should be enabled when decoding.
  ///
  /// It is recommended to leave this flag disabled, unless you have a
  /// specific reason not to.
  strict : Bool
  /// A hint for the target resolution that the image should be decoded at.
  target_resolution : (UInt, UInt)?
} derive(Debug)

///|
pub impl Default for DecodeSettings with fn default() {
  { resolve_palette_indices: true, strict: false, target_resolution: None, }
}

///|
/// A JPEG2000 image or codestream.
pub struct Image {
  /// The codestream containing the data to decode.
  priv codestream : BytesView
  /// The header of the J2C codestream.
  priv header : Header
  /// The JP2 boxes of the image. In the case of a raw codestream, we
  /// will synthesize the necessary boxes.
  priv boxes : ImageBoxes
  /// Settings that should be applied during decoding.
  priv settings : DecodeSettings
  /// Whether the image has an alpha channel.
  priv has_alpha : Bool
  /// The color space of the image.
  priv color_space : ColorSpace
}

///|
/// Try to create a new JPEG2000 image from the given data.
pub fn Image::new(
  data : BytesView,
  settings : DecodeSettings,
) -> Image raise DecodeError {
  if starts_with(data, jp2_magic) {
    jp2_parse(data, settings)
  } else if starts_with(data, codestream_magic) {
    j2c_parse(data, settings)
  } else {
    raise Format(InvalidSignature)
  }
}

///|
fn starts_with(data : BytesView, prefix : Bytes) -> Bool {
  if data.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if data[i] != prefix[i] {
      return false
    }
  }
  true
}

///|
/// Whether the image has an alpha channel.
pub fn Image::has_alpha(self : Image) -> Bool {
  self.has_alpha
}

///|
/// The color space of the image.
pub fn Image::color_space(self : Image) -> ColorSpace {
  self.color_space
}

///|
/// The width of the image.
pub fn Image::width(self : Image) -> UInt {
  self.header.size_data.image_width()
}

///|
/// The height of the image.
pub fn Image::height(self : Image) -> UInt {
  self.header.size_data.image_height()
}

///|
/// The original bit depth of the image. You usually don't need to do anything
/// with this parameter, it just exists for informational purposes.
pub fn Image::original_bit_depth(self : Image) -> Int {
  // Note that this only works if all components have the same precision.
  self.header.component_infos[0].size_info.precision
}

///|
/// Decode the image and return its decoded components.
pub fn Image::decode(
  self : Image,
  decoder_context : DecoderContext,
) -> DecodedImage raise DecodeError {
  let settings = self.settings
  decode_codestream(self.codestream, self.header, decoder_context)
  let decoded_image = {
    decoded_components: decoder_context.channel_data,
    boxes: self.boxes.clone(),
  }

  // Resolve palette indices.
  if settings.resolve_palette_indices {
    let components = decoded_image.decoded_components.copy()
    decoded_image.decoded_components.clear()
    let resolved = resolve_palette_indices(components, decoded_image.boxes)
    decoded_image.decoded_components.append(resolved)
  }
  if decoded_image.boxes.channel_definition is Some(cdef) {
    // Sort by the channel association. Note that this will only work if
    // each component is referenced only once.
    let n = if decoded_image.decoded_components.length() <
      cdef.channel_definitions.length() {
      decoded_image.decoded_components.length()
    } else {
      cdef.channel_definitions.length()
    }
    let components = Array::makei(n, i => {
      let key = match cdef.channel_definitions[i].association {
        WholeImage => 0xFFFF
        Colour(c) => c
      }
      (decoded_image.decoded_components[i], key)
    })
    let components = stable_sort_by_key(components, c => c.1)
    decoded_image.decoded_components.clear()
    for c in components {
      decoded_image.decoded_components.push(c.0)
    }
  }

  // Note that this is only valid if all images have the same bit depth.
  let bit_depth = decoded_image.decoded_components[0].bit_depth
  convert_color_space(decoded_image, bit_depth)
  decoded_image
}

///|
fn resolve_alpha_and_color_space(
  boxes : ImageBoxes,
  header : Header,
  settings : DecodeSettings,
) -> (ColorSpace, Bool) raise DecodeError {
  let mut num_components = header.component_infos.length()

  // Override number of components with what is actually in the palette box
  // in case we resolve them.
  if settings.resolve_palette_indices && boxes.palette is Some(palette_box) {
    num_components = palette_box.columns.length()
  }
  let mut has_alpha = false
  if boxes.channel_definition is Some(cdef) {
    let last = cdef.channel_definitions[cdef.channel_definitions.length() - 1]
    has_alpha = last.channel_type == Opacity
  }
  let mut color_space = get_color_space(boxes, num_components)

  // If we didn't resolve palette indices, we need to assume grayscale image.
  if !settings.resolve_palette_indices && boxes.palette is Some(_) {
    has_alpha = false
    color_space = Gray
  }
  let actual_num_components = header.component_infos.length()

  // Validate the number of channels.
  if boxes.palette is None &&
    actual_num_components !=
    ((color_space.num_channels() + (if has_alpha { 1 } else { 0 })) & 0xFF) {
    if !settings.strict &&
      actual_num_components == color_space.num_channels() + 1 &&
      !has_alpha {
      // See OPENJPEG test case orb-blue10-lin-j2k. Assume that we have an
      // alpha channel in this case.
      has_alpha = true
    } else if actual_num_components == 1 ||
      (actual_num_components == 2 && has_alpha) {
      // Color space is invalid, attempt to repair.
      color_space = Gray
    } else if actual_num_components == 3 {
      color_space = RGB
    } else if actual_num_components == 4 {
      if has_alpha {
        color_space = RGB
      } else {
        color_space = CMYK
      }
    } else {
      raise Validation(TooManyChannels)
    }
  }
  (color_space, has_alpha)
}

///|
/// The color space of the image.
pub(all) enum ColorSpace {
  /// A grayscale image.
  Gray
  /// An RGB image.
  RGB
  /// A CMYK image.
  CMYK
  /// An unknown color space.
  /// The number of channels of the color space.
  Unknown(num_channels~ : Int)
  /// An image based on an ICC profile.
  /// The raw data of the ICC profile.
  Icc(
    profile~ : Bytes,
    /// The number of channels used by the ICC profile.
    num_channels~ : Int
  )
} derive(Debug, Eq)

///|
/// Return the number of expected channels for the color space.
pub fn ColorSpace::num_channels(self : ColorSpace) -> Int {
  match self {
    Gray => 1
    RGB => 3
    CMYK => 4
    Unknown(num_channels~) => num_channels
    Icc(num_channels~, ..) => num_channels
  }
}

///|
/// The decoded components of the image.
pub fn DecodedImage::components(
  self : DecodedImage,
) -> ArrayView[ComponentData] {
  self.decoded_components[:]
}

///|
/// Return the decoded image as interleaved unsigned 8-bit sample data.
pub fn DecodedImage::data_u8(self : DecodedImage) -> Bytes {
  let components = self.components()
  let buffer_size = components[0].samples().length() * components.length()
  let buf = FixedArray::make(buffer_size, b'\x00')
  self.store_u8_into(buf)
  Bytes::from_array(buf[:])
}

///|
/// Store the decoded image as interleaved unsigned 8-bit sample data into `buf`.
///
/// The buffer must have the correct size.
pub fn DecodedImage::store_u8_into(
  self : DecodedImage,
  buf : FixedArray[Byte],
) -> Unit {
  interleave_and_convert(self, buf)
}

///|
fn interleave_and_convert(image : DecodedImage, buf : FixedArray[Byte]) -> Unit {
  let components = image.decoded_components
  let num_components = components.length()
  let mut all_same_bit_depth = true
  for component in components[1:] {
    if component.bit_depth != components[0].bit_depth {
      all_same_bit_depth = false
    }
  }
  let max_len = components[0].container.original_len
  if all_same_bit_depth && components[0].bit_depth == 8 && num_components <= 4 {
    // Fast path for the common case.
    match num_components {
      // Gray-scale.
      1 => {
        let c0 = components[0].container.data
        let n = if buf.length() < c0.length() {
          buf.length()
        } else {
          c0.length()
        }
        for i in 0..<n {
          buf[i] = f32_to_u8(round_f32(c0[i])).to_byte()
        }
      }
      // Gray-scale with alpha.
      2 => {
        let c0 = components[0].container.data
        let c1 = components[1].container.data
        let mut o = 0
        for i in 0..<max_len {
          buf[o] = f32_to_u8(round_f32(c0[i])).to_byte()
          buf[o + 1] = f32_to_u8(round_f32(c1[i])).to_byte()
          o += 2
        }
      }
      // RGB
      3 => {
        let c0 = components[0].container.data
        let c1 = components[1].container.data
        let c2 = components[2].container.data
        let mut o = 0
        for i in 0..<max_len {
          buf[o] = f32_to_u8(round_f32(c0[i])).to_byte()
          buf[o + 1] = f32_to_u8(round_f32(c1[i])).to_byte()
          buf[o + 2] = f32_to_u8(round_f32(c2[i])).to_byte()
          o += 3
        }
      }
      // RGBA or CMYK.
      4 => {
        let c0 = components[0].container.data
        let c1 = components[1].container.data
        let c2 = components[2].container.data
        let c3 = components[3].container.data
        let mut o = 0
        for i in 0..<max_len {
          buf[o] = f32_to_u8(round_f32(c0[i])).to_byte()
          buf[o + 1] = f32_to_u8(round_f32(c1[i])).to_byte()
          buf[o + 2] = f32_to_u8(round_f32(c2[i])).to_byte()
          buf[o + 3] = f32_to_u8(round_f32(c3[i])).to_byte()
          o += 4
        }
      }
      _ => abort("unreachable")
    }
  } else {
    // Slow path that also requires us to scale to 8 bit.
    let mul_factor : Float = 255.0
    let mut o = 0
    for sample in 0..<max_len {
      for channel in components {
        let divisor = (shl_u32(1, channel.bit_depth) - 1).to_float()
        buf[o] = f32_to_u8(
          round_f32(channel.container.data[sample] / divisor * mul_factor),
        ).to_byte()
        o += 1
      }
    }
  }
}

///|
fn convert_color_space(
  image : DecodedImage,
  bit_depth : Int,
) -> Unit raise DecodeError {
  if image.boxes.color_specification is Some({ color_space: Enumerated(e), }) {
    match e {
      Sycc => sycc_to_rgb(image.decoded_components, bit_depth)
      CieLab(cielab) =>
        cielab_to_rgb(image.decoded_components, bit_depth, cielab)
      _ => ()
    }
  }
}

///|
fn get_color_space(
  boxes : ImageBoxes,
  num_components : Int,
) -> ColorSpace raise DecodeError {
  let colr = match boxes.color_specification {
    Some(c) => c.color_space
    None => ColrColorSpace::Unknown
  }
  match colr {
    Enumerated(e) =>
      match e {
        Cmyk => CMYK
        Srgb => RGB
        RommRgb =>
          // Use an ICC profile to process the RommRGB color space.
          Icc(profile=prophoto_v2_micro_icc, num_channels=3)
        EsRgb => RGB
        Greyscale => Gray
        Sycc => RGB
        CieLab(_) => Icc(profile=lab_icc, num_channels=3)
        _ => raise Format(Unsupported)
      }
    Icc(icc) =>
      match ICCMetadata::from_data(icc) {
        Some(metadata) =>
          Icc(profile=icc, num_channels=metadata.color_space.num_components())
        None =>
          // See OPENJPEG test orb-blue10-lin-jp2.jp2. They seem to
          // assume RGB in this case (even though the image has 4
          // components with no opacity channel, they assume RGBA instead
          // of CMYK).
          RGB
      }
    Unknown =>
      match num_components {
        1 => Gray
        3 => RGB
        4 => CMYK
        _ => Unknown(num_channels=num_components & 0xFF)
      }
  }
}

///|
fn resolve_palette_indices(
  components : Array[ComponentData],
  boxes : ImageBoxes,
) -> Array[ComponentData] raise DecodeError {
  guard boxes.palette is Some(palette) else {
    // Nothing to resolve.
    return components
  }
  let mapping = boxes.component_mapping.unwrap()
  let resolved = []
  for entry in mapping.entries {
    let component_idx = entry.component_index
    guard component_idx < components.length() else {
      raise Color(PaletteResolutionFailed)
    }
    let component = components[component_idx]
    match entry.mapping_type {
      Direct => resolved.push(component.clone())
      Palette(column~) => {
        let column_idx = column
        guard column_idx < palette.columns.length() else {
          raise Color(PaletteResolutionFailed)
        }
        let column_info = palette.columns[column_idx]
        let samples = component.container.truncated()
        let mapped : Array[Float] = Array::new(
          capacity=samples.length() + SIMD_WIDTH,
        )
        for sample in samples {
          let index = f32_to_i64(round_f32(sample))
          guard palette.map(index, column_idx) is Some(value) else {
            raise Color(PaletteResolutionFailed)
          }
          mapped.push(value.to_float())
        }
        resolved.push({
          container: SimdBuffer::new(mapped),
          bit_depth: column_info.bit_depth,
        })
      }
    }
  }
  resolved
}

///|
fn cielab_to_rgb(
  components : Array[ComponentData],
  bit_depth : Int,
  lab : CieLab,
) -> Unit raise DecodeError {
  if components.length() < 3 {
    raise Color(LabConversionFailed)
  }
  let l = components[0]
  let a = components[1]
  let b = components[2]
  let prec0 = l.bit_depth
  let prec1 = a.bit_depth
  let prec2 = b.bit_depth

  // Prevent underflows/divisions by zero further below.
  if prec0 < 4 || prec1 < 4 || prec2 < 4 {
    raise Color(LabConversionFailed)
  }
  let rl = lab.rl.unwrap_or(100)
  let ra = lab.ra.unwrap_or(170)
  let rb = lab.ra.unwrap_or(200)
  let ol = lab.ol.unwrap_or(0)
  let oa = lab.oa.unwrap_or(shl_u32(1, (bit_depth - 1) & 0xFF))
  let ob = lab.ob.unwrap_or(
    shl_u32(1, (bit_depth - 2) & 0xFF) + shl_u32(1, (bit_depth - 3) & 0xFF),
  )

  // Copied from OpenJPEG.
  let min_l = -(rl.to_float() * ol.to_float()) /
    (shl_i32(1, prec0) - 1).to_float()
  let max_l = min_l + rl.to_float()
  let min_a = -(ra.to_float() * oa.to_float()) /
    (shl_i32(1, prec1) - 1).to_float()
  let max_a = min_a + ra.to_float()
  let min_b = -(rb.to_float() * ob.to_float()) /
    (shl_i32(1, prec2) - 1).to_float()
  let max_b = min_b + rb.to_float()
  let bit_max = shl_u32(1, bit_depth) - 1

  // Note that we are not doing the actual conversion with the ICC profile yet,
  // just decoding the raw LAB values.
  // We leave applying the ICC profile to the user.
  let divisor_l = (shl_i32(1, prec0) - 1).to_float()
  let divisor_a = (shl_i32(1, prec1) - 1).to_float()
  let divisor_b = (shl_i32(1, prec2) - 1).to_float()
  let scale_l_final = bit_max.to_float() / 100.0
  let scale_ab_final = bit_max.to_float() / 255.0
  let l_offset = min_l * scale_l_final
  let l_scale = (max_l - min_l) / divisor_l * scale_l_final
  let a_offset = (min_a + 128.0) * scale_ab_final
  let a_scale = (max_a - min_a) / divisor_a * scale_ab_final
  let b_offset = (min_b + 128.0) * scale_ab_final
  let b_scale = (max_b - min_b) / divisor_b * scale_ab_final

  // Note that we are not doing the actual conversion with the ICC profile yet,
  // just decoding the raw LAB values.
  // We leave applying the ICC profile to the user.
  let ld = l.container.data
  let ad = a.container.data
  let bd = b.container.data
  let n = min_chunked_len(ld, ad, bd)
  for i in 0..<n {
    ld[i] = fmaf(ld[i], l_scale, l_offset)
    ad[i] = fmaf(ad[i], a_scale, a_offset)
    bd[i] = fmaf(bd[i], b_scale, b_offset)
  }
}

///|
/// The number of elements covered by zipping `chunks_exact_mut(SIMD_WIDTH)`
/// of three buffers.
fn min_chunked_len(
  a : FixedArray[Float],
  b : FixedArray[Float],
  c : FixedArray[Float],
) -> Int {
  let mut n = a.length() / SIMD_WIDTH
  if b.length() / SIMD_WIDTH < n {
    n = b.length() / SIMD_WIDTH
  }
  if c.length() / SIMD_WIDTH < n {
    n = c.length() / SIMD_WIDTH
  }
  n * SIMD_WIDTH
}

///|
fn sycc_to_rgb(
  components : Array[ComponentData],
  bit_depth : Int,
) -> Unit raise DecodeError {
  let offset = shl_u32(1, bit_depth - 1).to_float()
  let max_value = (shl_u32(1, bit_depth) - 1).to_float()
  if components.length() < 3 {
    raise Color(SyccConversionFailed)
  }
  let y = components[0].container.data
  let cb = components[1].container.data
  let cr = components[2].container.data
  let zero : Float = 0.0
  let cr_to_r = Float::reinterpret_from_uint(0x3FB374BC) // 1.402
  let cb_to_g = Float::reinterpret_from_uint(0xBEB03298) // -0.344136
  let cr_to_g = Float::reinterpret_from_uint(0xBF36D19E) // -0.714136
  let cb_to_b = Float::reinterpret_from_uint(0x3FE2D0E5) // 1.772
  let n = min_chunked_len(y, cb, cr)
  for i in 0..<n {
    let y_v = y[i]
    let cb_v = cb[i] - offset
    let cr_v = cr[i] - offset

    // r = y + 1.402 * cr
    let r = fmaf(cr_v, cr_to_r, y_v)
    // g = y - 0.344136 * cb - 0.714136 * cr
    let g = fmaf(cr_v, cr_to_g, fmaf(cb_v, cb_to_g, y_v))
    // b = y + 1.772 * cb
    let b = fmaf(cb_v, cb_to_b, y_v)
    y[i] = neon_max(neon_min(r, max_value), zero)
    cb[i] = neon_max(neon_min(g, max_value), zero)
    cr[i] = neon_max(neon_min(b, max_value), zero)
  }
}
