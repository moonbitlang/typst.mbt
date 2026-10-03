// Port of `hayro-jbig2/src/gray_scale.rs`: gray-scale image decoding
// procedure (Annex C).
//
// (hayro builds hayro-jbig2 with the `simd` feature; `xor_planes` and
// `extract_bits` use `u32x8` integer ops of `simd.rs` (xor, and, unsigned
// `simd_gt`, `select`, or), which are ported lane by lane here: they are
// bit-identical to the scalar fallback of `simd.rs`.)

///|
/// Input parameters to the gray-scale image decoding procedure (Table C.1).
priv struct GrayScaleParams {
  /// `GSMMR` - Specifies whether MMR is used.
  use_mmr : Bool
  /// `GSBPP` - The number of bits per gray-scale value.
  bits_per_pixel : UInt
  /// `GSW` - The width of the gray-scale image.
  width : UInt
  /// `GSH` - The height of the gray-scale image.
  height : UInt
  /// `GSTEMPLATE` - The template used to code the gray-scale bitplanes.
  template : Template
  /// `GSKIP` - A mask indicating which values should be skipped.
  /// None if `GSUSESKIP` = 0.
  skip_mask : FixedArray[UInt]?
}

///|
/// The gray-scale image decoding procedure (Annex C, C.5).
///
/// Returns `GSVALS`: the decoded gray-scale image array, GSW × GSH pixels.
fn decode_gray_scale_image(
  data : BytesView,
  params : GrayScaleParams,
  ctx : ScratchBuffers,
) -> FixedArray[UInt] raise DecodeError {
  // Table C.1: "GSMMR specifies whether MMR is used."
  if params.use_mmr {
    gray_decode_mmr(data, params)
  } else {
    gray_decode_arithmetic(data, params, ctx)
  }
}

///|
/// The gray-scale image decoding procedure using MMR (Annex C, C.5).
///
/// Table C.4: "MMR = GSMMR"
fn gray_decode_mmr(
  data : BytesView,
  params : GrayScaleParams,
) -> FixedArray[UInt] raise DecodeError {
  // `GSW` - The width of the gray-scale image.
  let width = params.width
  // `GSH` - The height of the gray-scale image.
  let height = params.height
  // `GSBPP` - The number of bits per gray-scale value.
  let bits_per_pixel = params.bits_per_pixel
  let stride = stride_of(width)
  let mut offset = 0
  decode_bitplanes(width, height, stride, bits_per_pixel, fn(
    _,
    bitplane,
  ) raise DecodeError {
    // Table C.4: "GBW = GSW, GBH = GSH"
    // (`&data[offset..]` panics if `offset` is past the end.)
    if offset > data.length() {
      abort("hayro-jbig2: gray-scale bitplane offset out of range")
    }
    offset += decode_bitmap_mmr(bitplane, data[offset:])
  })
}

///|
/// The gray-scale image decoding procedure using arithmetic coding (Annex C, C.5).
///
/// Table C.4: "GBTEMPLATE = GSTEMPLATE, TPGDON = 0, USESKIP = GSUSESKIP, SKIP = GSKIP"
fn gray_decode_arithmetic(
  data : BytesView,
  params : GrayScaleParams,
  ctx : ScratchBuffers,
) -> FixedArray[UInt] raise DecodeError {
  // `GSW` - The width of the gray-scale image.
  let width = params.width
  // `GSH` - The height of the gray-scale image.
  let height = params.height
  if width > MAX_DIMENSION || height > MAX_DIMENSION {
    raise Overflow(BitmapDimension)
  }

  // `GSBPP` - The number of bits per gray-scale value.
  let bits_per_pixel = params.bits_per_pixel
  let stride = stride_of(width)
  // `GSKIP` - The skip mask (if GSUSESKIP = 1).
  let skip_mask = params.skip_mask
  let skip_stride = stride_of(width)
  // `GSTEMPLATE` - The template used for bitplane decoding.
  let template = params.template

  // Table C.4: Adaptive template pixel positions.
  let at_pixels : FixedArray[AdaptiveTemplatePixel] = match template {
    Template0 =>
      [{ x: 3, y: -1, }, { x: -3, y: -1, }, { x: 2, y: -2, }, { x: -2, y: -2, }]
    Template1 =>
      [
        { x: 3, y: -1, },
        // Unused.
        AdaptiveTemplatePixel::default(),
        AdaptiveTemplatePixel::default(),
        AdaptiveTemplatePixel::default(),
      ]
    Template2 | Template3 =>
      [
        { x: 2, y: -1, },
        // Unused.
        AdaptiveTemplatePixel::default(),
        AdaptiveTemplatePixel::default(),
        AdaptiveTemplatePixel::default(),
      ]
  }
  let decoder = ArithmeticDecoder::new(data)
  let contexts = ctx.reset_contexts(1 << template.context_bits())

  // (Upstream's `gs_decode_loop!` macro, instantiated per template with
  // `ContextGatherer::gather_template{0,1,2,3}_default`.)
  decode_bitplanes(width, height, stride, bits_per_pixel, fn(_, bitplane) {
    // Table C.4: "GBW = GSW, GBH = GSH, TPGDON = 0"
    let gatherer = ContextGatherer::new(template, at_pixels)
    for y in 0U..<height {
      gatherer.start_row(bitplane, y)
      for x in 0U..<width {
        gatherer.maybe_reload_buffers(bitplane, x)

        // Table C.4: "USESKIP = GSUSESKIP, SKIP = GSKIP"
        if skip_mask is Some(mask) {
          let word_idx = (y * skip_stride + x / 32).reinterpret_as_int()
          let bit_pos = (31U - x % 32).reinterpret_as_int()
          if ((mask[word_idx] >> bit_pos) & 1) != 0 {
            // Still need to update the context.
            let _ = gatherer.gather_default(bitplane, x)
            continue
          }
        }
        let context = gatherer.gather_default(bitplane, x)
        let pixel = decoder.read_bit(contexts, context)
        let value = pixel.reinterpret_as_int()
        if value != 0 {
          bitplane.set_pixel(x, y, value)
          gatherer.update_current_row(x, value)
        }
      }
    }
  })
}

///|
/// The bitplane decoding and gray value computation procedure (C.5).
///
/// The closure `decode_next` is called for each bitplane, receiving the bitplane
/// index (`GSBPP`-1 down to 0) and a zeroed bitmap to decode into.
fn decode_bitplanes(
  width : UInt,
  height : UInt,
  stride : UInt,
  bits_per_pixel : UInt,
  decode_next : (UInt, Bitmap) -> Unit raise DecodeError,
) -> FixedArray[UInt] raise DecodeError {
  let size = width.to_int64() * height.to_int64()
  // (Upstream allocates up to 65535 × 65535 values here; such sizes exceed
  // MoonBit's array limit.)
  if size > 0x7FFFFFFFL {
    abort("hayro-jbig2: gray-scale image too large")
  }
  let size = size.to_int()
  // `GSVALS` - The decoded gray-scale image array.
  let values = FixedArray::make(size, 0U)
  let bitplane = Bitmap::new(width, height)
  let prev_plane = FixedArray::make(bitplane.data.length(), 0U)
  let mut j = bits_per_pixel
  while j > 0 {
    j -= 1
    bitplane.data.fill(0)
    decode_next(j, bitplane)

    // Done every time except the first time.
    if j < bits_per_pixel - 1 {
      // C.5 step 3b: "GSPLANES[J][x, y] = GSPLANES[J + 1][x, y] XOR GSPLANES[J][x, y]"
      xor_planes(bitplane.data, prev_plane)
    }

    // C.5 step 4: "GSVALS[x, y] = sum(J=0 to GSBPP-1) GSPLANES[J][x, y] * 2^J"
    extract_bits(bitplane.data, values, width, height, stride, j)

    // C.5 step 3c: "Set J = J - 1."
    bitplane.data.blit_to(prev_plane, len=prev_plane.length())
  }
  values
}

///|
fn xor_planes(plane : FixedArray[UInt], prev : FixedArray[UInt]) -> Unit {
  // (The `u32x8` chunks and the scalar tail compute the same lane-wise xor.)
  for i in 0..<plane.length() {
    plane[i] = plane[i] ^ prev[i]
  }
}

///|
fn extract_bits(
  data : FixedArray[UInt],
  values : FixedArray[UInt],
  width : UInt,
  height : UInt,
  stride : UInt,
  j : UInt,
) -> Unit {
  // (The `u32x8` path tests `(word & BIT_MASKS[bit_offset + lane]) > 0` per
  // lane and ors in `1 << j`, which is exactly the scalar tail's test.)
  let bit_value = 1U << j.reinterpret_as_int()
  let width = width.reinterpret_as_int()
  let stride = stride.reinterpret_as_int()
  for y in 0..<height.reinterpret_as_int() {
    let row_data = y * stride
    let row_vals = y * width
    for x in 0..<width {
      let word_idx = row_data + x / 32
      let bit_pos = 31 - x % 32
      if ((data[word_idx] >> bit_pos) & 1) != 0 {
        values[row_vals + x] = values[row_vals + x] | bit_value
      }
    }
  }
}
