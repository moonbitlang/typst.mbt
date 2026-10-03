// Port of `hayro-jbig2/src/decode/generic_refinement.rs`: generic refinement
// region segment parsing and decoding (7.4.7, 6.3).

///|
/// Generic refinement region decoding procedure (6.3).
fn generic_refinement_decode(
  header : GenericRefinementRegionHeader,
  reference : Bitmap,
  ctx : ScratchBuffers,
) -> RegionBitmap raise DecodeError {
  let region = Bitmap::new_with(
    header.region_info.width,
    header.region_info.height,
    header.region_info.x_location,
    header.region_info.y_location,
    false,
  )
  generic_refinement_decode_into(header, reference, region, ctx)
  {
    bitmap: region,
    combination_operator: header.region_info.combination_operator,
  }
}

///|
/// `i32::try_from(r).ok().and_then(|r| i32::try_from(h).ok().and_then(|h| r.checked_sub(h)))`.
fn reference_offset(r : UInt, h : UInt) -> Int? {
  if r > 0x7FFFFFFF || h > 0x7FFFFFFF {
    return None
  }
  // Both are non-negative `i32`s, so the difference can't overflow.
  Some(r.reinterpret_as_int() - h.reinterpret_as_int())
}

///|
/// Decode a generic refinement region directly into an existing bitmap.
fn generic_refinement_decode_into(
  header : GenericRefinementRegionHeader,
  reference : Bitmap,
  region : Bitmap,
  ctx : ScratchBuffers,
) -> Unit raise DecodeError {
  let data = header.data

  // Validate that the region fits within the reference bitmap.
  // When referring to another segment, dimensions must match exactly (7.4.7.5).
  // When using the page bitmap as reference, the region must fit within the page.
  if header.region_info.width > reference.width ||
    header.region_info.height > reference.height {
    raise Region(InvalidDimension)
  }
  let reference_dx = ok_or(
    reference_offset(reference.x_location, header.region_info.x_location),
    Overflow(ReferenceOffset),
  )
  let reference_dy = ok_or(
    reference_offset(reference.y_location, header.region_info.y_location),
    Overflow(ReferenceOffset),
  )
  let decoder = ArithmeticDecoder::new(data)
  let num_context_bits = header.template.context_bits()
  let contexts = ctx.reset_contexts(1 << num_context_bits)
  generic_refinement_decode_bitmap(
    decoder,
    contexts,
    region,
    reference,
    reference_dx,
    reference_dy,
    header.template,
    header.adaptive_template_pixels,
    header.tpgron,
  )
}

///|
/// Parsed generic refinement region segment header (7.4.7.1).
priv struct GenericRefinementRegionHeader {
  region_info : RegionSegmentInfo
  template : RefinementTemplate
  tpgron : Bool
  adaptive_template_pixels : Array[AdaptiveTemplatePixel]
  data : BytesView
}

///|
/// Parse a generic refinement region segment header (7.4.7.1).
fn generic_refinement_parse(
  reader : Reader,
) -> GenericRefinementRegionHeader raise DecodeError {
  let region_info = parse_region_segment_info(reader)
  let flags = ok_or(reader.read_byte(), eof).to_int()
  let template = RefinementTemplate::from_byte(flags)
  let tpgron = (flags & 0x02) != 0
  let adaptive_template_pixels = if template == RTemplate0 {
    parse_refinement_at_pixels(reader)
  } else {
    []
  }
  let data = ok_or(reader.tail(), eof)
  { region_info, template, tpgron, adaptive_template_pixels, data, }
}

///|
fn refinement_has_default_at_pixels(
  at_pixels : Array[AdaptiveTemplatePixel],
) -> Bool {
  at_pixels.length() >= 2 &&
  at_pixels[0].x == -1 &&
  at_pixels[0].y == -1 &&
  at_pixels[1].x == -1 &&
  at_pixels[1].y == -1
}

///|
priv struct RefinementContextGatherer {
  template : RefinementTemplate
  at_pixels : Array[AdaptiveTemplatePixel]
  use_default_at : Bool
  reference_dx : Int
  reference_dy : Int
  mut reg_y : UInt
  mut reg_cur_x : UInt
  mut reg_m1 : UInt
  mut reg_cur : UInt
  mut ref_cur_x : UInt
  mut ref_m1 : UInt
  mut ref_cur : UInt
  mut ref_p1 : UInt
  mut ctx : Int
}

///|
const REF_SHIFT_MASK_T0_DEFAULT : Int = 0b1_1001_1011_0110

///|
const REF_SHIFT_MASK_T0_CUSTOM : Int = 0b0_1000_1011_0110

///|
const REF_SHIFT_MASK_T1 : Int = 0b11_0001_1010

///|
fn RefinementContextGatherer::new(
  template : RefinementTemplate,
  at_pixels : Array[AdaptiveTemplatePixel],
  reference_dx : Int,
  reference_dy : Int,
) -> RefinementContextGatherer {
  let use_default_at = template == RTemplate0 &&
    refinement_has_default_at_pixels(at_pixels)
  {
    template,
    at_pixels,
    use_default_at,
    reference_dx,
    reference_dy,
    reg_y: 0,
    reg_cur_x: 0,
    reg_m1: 0,
    reg_cur: 0,
    ref_cur_x: 0,
    ref_m1: 0,
    ref_cur: 0,
    ref_p1: 0,
    ctx: 0,
  }
}

///|
fn RefinementContextGatherer::start_row(
  self : RefinementContextGatherer,
  region : Bitmap,
  reference : Bitmap,
  y : UInt,
) -> Unit {
  self.reg_y = y
  let ref_y = y.reinterpret_as_int() - self.reference_dy
  // This will on purpose wrap to a very large `u32` for negative values, such that
  // they resolve to 0 in `ContextGatherer::load_word`.
  let ref_x0 = (-self.reference_dx).reinterpret_as_uint()
  self.reg_cur_x = 0
  self.reg_m1 = if y >= 1 { load_word(region, y - 1, 0) } else { 0 }
  self.reg_cur = 0
  self.ref_cur_x = 0
  self.ref_m1 = load_word(reference, (ref_y - 1).reinterpret_as_uint(), 0)
  self.ref_cur = load_word(reference, ref_y.reinterpret_as_uint(), 0)
  self.ref_p1 = load_word(reference, (ref_y + 1).reinterpret_as_uint(), 0)
  self.ctx = match self.template {
    RTemplate1 => {
      let rbx = ref_x0 - self.ref_cur_x
      let reg_m1_0 = get_buf_pixel(self.reg_m1, 0)
      let ref_cur_m1 = get_buf_pixel(self.ref_cur, rbx - 1)
      let ref_cur_0 = get_buf_pixel(self.ref_cur, rbx)
      let ref_p1_0 = get_buf_pixel(self.ref_p1, rbx)
      (reg_m1_0 << 7) | (ref_cur_m1 << 3) | (ref_cur_0 << 2) | ref_p1_0
    }
    RTemplate0 if self.use_default_at => {
      let rbx = ref_x0 - self.ref_cur_x
      let reg_m1_0 = get_buf_pixel(self.reg_m1, 0)
      let ref_m1_m1 = get_buf_pixel(self.ref_m1, rbx - 1)
      let ref_m1_0 = get_buf_pixel(self.ref_m1, rbx)
      let ref_cur_m1 = get_buf_pixel(self.ref_cur, rbx - 1)
      let ref_cur_0 = get_buf_pixel(self.ref_cur, rbx)
      let ref_p1_m1 = get_buf_pixel(self.ref_p1, rbx - 1)
      let ref_p1_0 = get_buf_pixel(self.ref_p1, rbx)
      (reg_m1_0 << 10) |
      (ref_m1_m1 << 7) |
      (ref_m1_0 << 6) |
      (ref_cur_m1 << 4) |
      (ref_cur_0 << 3) |
      (ref_p1_m1 << 1) |
      ref_p1_0
    }
    RTemplate0 => {
      let rbx = ref_x0 - self.ref_cur_x
      let reg_m1_0 = get_buf_pixel(self.reg_m1, 0)
      let ref_m1_0 = get_buf_pixel(self.ref_m1, rbx)
      let ref_cur_m1 = get_buf_pixel(self.ref_cur, rbx - 1)
      let ref_cur_0 = get_buf_pixel(self.ref_cur, rbx)
      let ref_p1_m1 = get_buf_pixel(self.ref_p1, rbx - 1)
      let ref_p1_0 = get_buf_pixel(self.ref_p1, rbx)
      (reg_m1_0 << 10) |
      (ref_m1_0 << 6) |
      (ref_cur_m1 << 4) |
      (ref_cur_0 << 3) |
      (ref_p1_m1 << 1) |
      ref_p1_0
    }
  }
}

///|
#inline
fn RefinementContextGatherer::maybe_reload_buffers(
  self : RefinementContextGatherer,
  region : Bitmap,
  reference : Bitmap,
  x : UInt,
) -> Unit {
  if x + 1 >= self.reg_cur_x + WORD_BITS {
    let new_start = if x >= 1 { x - 1 } else { 0 }
    self.reg_cur_x = new_start
    self.reg_m1 = if self.reg_y >= 1 {
      load_word(region, self.reg_y - 1, new_start)
    } else {
      0
    }
    self.reg_cur = load_word(region, self.reg_y, new_start)
  }
  let ref_x_signed = x.reinterpret_as_int() - self.reference_dx
  if ref_x_signed < 0 {
    self.ref_cur_x = 0
    self.ref_m1 = 0
    self.ref_cur = 0
    self.ref_p1 = 0
  } else {
    let ref_x = ref_x_signed.reinterpret_as_uint()
    if ref_x + 1 >= self.ref_cur_x + WORD_BITS || ref_x < self.ref_cur_x {
      let new_start = if ref_x >= 1 { ref_x - 1 } else { 0 }
      let ref_y = self.reg_y.reinterpret_as_int() - self.reference_dy
      self.ref_cur_x = new_start
      self.ref_m1 = load_word(
        reference,
        (ref_y - 1).reinterpret_as_uint(),
        new_start,
      )
      self.ref_cur = load_word(
        reference,
        ref_y.reinterpret_as_uint(),
        new_start,
      )
      self.ref_p1 = load_word(
        reference,
        (ref_y + 1).reinterpret_as_uint(),
        new_start,
      )
    }
  }
}

///|
#inline
fn extract_3bits(buf : UInt, rbx : UInt) -> UInt {
  if rbx == 0 || rbx >= WORD_BITS - 1 {
    // Near word boundary, fall back to individual extraction.
    let b0 = get_buf_pixel(buf, rbx - 1).reinterpret_as_uint()
    let b1 = get_buf_pixel(buf, rbx).reinterpret_as_uint()
    let b2 = get_buf_pixel(buf, rbx + 1).reinterpret_as_uint()
    (b0 << 2) | (b1 << 1) | b2
  } else {
    // Fast path: shift and mask 3 bits at once.
    (buf >> (WORD_SHIFT - rbx - 1).reinterpret_as_int()) & 0b111
  }
}

///|
#inline
fn RefinementContextGatherer::tpgr_all_same(
  self : RefinementContextGatherer,
  x : UInt,
) -> Bool {
  let ref_x = (x.reinterpret_as_int() - self.reference_dx).reinterpret_as_uint()
  let rbx = ref_x - self.ref_cur_x
  let m1 = extract_3bits(self.ref_m1, rbx)
  let cur = extract_3bits(self.ref_cur, rbx)
  let p1 = extract_3bits(self.ref_p1, rbx)

  // Check that all 9 pixels are the same.
  m1 == cur && cur == p1 && (cur == 0 || cur == 0b111)
}

///|
#inline
fn RefinementContextGatherer::ref_center_pixel(
  self : RefinementContextGatherer,
  x : UInt,
) -> Int {
  let ref_x = (x.reinterpret_as_int() - self.reference_dx).reinterpret_as_uint()
  let rbx = ref_x - self.ref_cur_x
  get_buf_pixel(self.ref_cur, rbx)
}

///|
#inline
fn RefinementContextGatherer::update_current_row(
  self : RefinementContextGatherer,
  x : UInt,
  value : Int,
) -> Unit {
  let bx = x - self.reg_cur_x
  let bit_pos = (WORD_SHIFT - bx).reinterpret_as_int()
  let mask = 1U << bit_pos
  self.reg_cur = (self.reg_cur & mask.lnot()) |
    (value.reinterpret_as_uint() << bit_pos)
}

///|
#inline
fn RefinementContextGatherer::gather_template0_default(
  self : RefinementContextGatherer,
  x : UInt,
) -> Int {
  let bx = x - self.reg_cur_x
  let ref_x = (x.reinterpret_as_int() - self.reference_dx).reinterpret_as_uint()
  let rbx = ref_x - self.ref_cur_x
  let new_pixels = (get_buf_pixel(self.reg_m1, bx + 1) << 10) |
    (get_buf_pixel(self.reg_cur, bx - 1) << 9) |
    (get_buf_pixel(self.ref_m1, rbx + 1) << 6) |
    (get_buf_pixel(self.ref_cur, rbx + 1) << 3) |
    get_buf_pixel(self.ref_p1, rbx + 1)
  self.ctx = ((self.ctx << 1) & REF_SHIFT_MASK_T0_DEFAULT) | new_pixels
  self.ctx
}

///|
#inline
fn RefinementContextGatherer::gather_template0_custom(
  self : RefinementContextGatherer,
  region : Bitmap,
  reference : Bitmap,
  x : UInt,
) -> Int {
  let bx = x - self.reg_cur_x
  let ref_x_i = x.reinterpret_as_int() - self.reference_dx
  let rbx = ref_x_i.reinterpret_as_uint() - self.ref_cur_x
  let xi = x.reinterpret_as_int()
  let yi = self.reg_y.reinterpret_as_int()
  let ref_y = yi - self.reference_dy
  let at1 = self.at_pixels[0]
  let at2 = self.at_pixels[1]
  let new_pixels = (
      region.get_pixel(at_coord(xi, at1.x), at_coord(yi, at1.y)) << 12
    ) |
    (get_buf_pixel(self.reg_m1, bx + 1) << 10) |
    (get_buf_pixel(self.reg_cur, bx - 1) << 9) |
    (reference.get_pixel(at_coord(ref_x_i, at2.x), at_coord(ref_y, at2.y)) << 8) |
    (get_buf_pixel(self.ref_m1, rbx + 1) << 6) |
    (get_buf_pixel(self.ref_cur, rbx + 1) << 3) |
    get_buf_pixel(self.ref_p1, rbx + 1)
  self.ctx = ((self.ctx << 1) & REF_SHIFT_MASK_T0_CUSTOM) | new_pixels
  self.ctx
}

///|
#inline
fn RefinementContextGatherer::gather_template1(
  self : RefinementContextGatherer,
  x : UInt,
) -> Int {
  let bx = x - self.reg_cur_x
  let ref_x = (x.reinterpret_as_int() - self.reference_dx).reinterpret_as_uint()
  let rbx = ref_x - self.ref_cur_x
  let new_pixels = (get_buf_pixel(self.reg_m1, bx + 1) << 7) |
    (get_buf_pixel(self.reg_cur, bx - 1) << 6) |
    (get_buf_pixel(self.ref_m1, rbx) << 5) |
    (get_buf_pixel(self.ref_cur, rbx + 1) << 2) |
    get_buf_pixel(self.ref_p1, rbx + 1)
  self.ctx = ((self.ctx << 1) & REF_SHIFT_MASK_T1) | new_pixels
  self.ctx
}

///|
/// Which `gather` function the `refinement_decode_loop!` macro is
/// instantiated with.
priv enum RefinementGather {
  GatherT0Default
  GatherT0Custom
  GatherT1
}

///|
#inline
fn RefinementContextGatherer::gather(
  self : RefinementContextGatherer,
  which : RefinementGather,
  region : Bitmap,
  reference : Bitmap,
  x : UInt,
) -> Int {
  match which {
    GatherT0Default => self.gather_template0_default(x)
    GatherT0Custom => self.gather_template0_custom(region, reference, x)
    GatherT1 => self.gather_template1(x)
  }
}

///|
/// Decode a refinement bitmap (6.3.5.6).
fn generic_refinement_decode_bitmap(
  decoder : ArithmeticDecoder,
  contexts : FixedArray[Byte],
  region : Bitmap,
  reference : Bitmap,
  reference_dx : Int,
  reference_dy : Int,
  gr_template : RefinementTemplate,
  adaptive_template_pixels : Array[AdaptiveTemplatePixel],
  tpgron : Bool,
) -> Unit {
  let gatherer = RefinementContextGatherer::new(
    gr_template, adaptive_template_pixels, reference_dx, reference_dy,
  )

  // Context for SLTP depends on template (Figures 14, 15).
  let sltp_context = match gr_template {
    RTemplate0 => 0b0000000010000
    RTemplate1 => 0b0000001000
  }
  let which : RefinementGather = match gr_template {
    RTemplate0 if gatherer.use_default_at => GatherT0Default
    RTemplate0 => GatherT0Custom
    RTemplate1 => GatherT1
  }

  // (Upstream's `refinement_decode_loop!` macro.)
  let width = region.width
  let height = region.height

  // "1) Set LTP = 0." (6.3.5.6)
  let mut ltp = false

  // "3) Decode each row as follows:" (6.3.5.6)
  for y in 0U..<height {
    // "b) If TPGRON is 1, then decode a bit using the arithmetic entropy
    // coder" (6.3.5.6)
    if tpgron {
      let sltp = decoder.read_bit(contexts, sltp_context)
      // "Let SLTP be the value of this bit. Set: LTP = LTP XOR SLTP"
      ltp = ltp != (sltp != 0)
    }
    gatherer.start_row(region, reference, y)

    // "c) If LTP = 0 then, from left to right, explicitly decode all pixels
    // of the current row of GRREG." (6.3.5.6)
    if !ltp {
      for x in 0U..<width {
        gatherer.maybe_reload_buffers(region, reference, x)
        let context = gatherer.gather(which, region, reference, x)
        let pixel = decoder.read_bit(contexts, context)
        let value = pixel.reinterpret_as_int()
        if value != 0 {
          region.set_pixel(x, y, value)
          gatherer.update_current_row(x, value)
        }
      }
    } else {
      // "d) If LTP = 1 then, from left to right, implicitly decode certain
      // pixels of the current row of GRREG, and explicitly decode the rest."
      // (6.3.5.6)
      for x in 0U..<width {
        gatherer.maybe_reload_buffers(region, reference, x)
        let context = gatherer.gather(which, region, reference, x)

        // "i) Set TPGRPIX equal to 1 if:
        //    - TPGRON is 1 AND;
        //    - a 3 × 3 pixel array in the reference bitmap (Figure 16),
        //      centred at the location corresponding to the current pixel,
        //      contains pixels all of the same value." (6.3.5.6)
        if gatherer.tpgr_all_same(x) {
          // "ii) If TPGRPIX is 1 then implicitly decode the current pixel
          // by setting it equal to its predicted value (TPGRVAL)." (6.3.5.6)
          //
          // "When TPGRPIX is set to 1, set TPGRVAL equal to the current pixel
          // predicted value, which is the common value of the nine adjacent
          // pixels in the 3 × 3 array." (6.3.5.6)
          let val = gatherer.ref_center_pixel(x)
          if val != 0 {
            region.set_pixel(x, y, val)
            gatherer.update_current_row(x, val)
          }
        } else {
          // "iii) Otherwise, explicitly decode the current pixel using the
          // methodology of steps 3 c) i) through 3 c) iii) above." (6.3.5.6)
          let pixel = decoder.read_bit(contexts, context)
          let value = pixel.reinterpret_as_int()
          if value != 0 {
            region.set_pixel(x, y, value)
            gatherer.update_current_row(x, value)
          }
        }
      }
    }
  }
}
