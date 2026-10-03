// Port of `hayro-jpeg2000/src/j2c/bitplane.rs`: bitplane decoding, described
// in Annex D.
//
// JPEG2000 groups the samples of each component into their constituent
// bit planes and uses a special context-modeling approach to encode the
// bits using the arithmetic encoder. In this stage, we need to "revert" the
// context-modeling so that we can extract the magnitudes and signs of each
// sample.
//
// Some of the references are taken from the
// "JPEG2000 Standard for Image Compression" book instead of the specification.
//
// The bit-packed per-coefficient state (`CoefficientState`,
// `NeighborSignificances`, `Coefficient`) lives in flat arrays of the
// context; `Position`s are passed as padded `(index_x, index_y)` pairs.
// `Option<()>` results become `Bool`s, and `BitDecoder::read_bit` returns
// -1 for `None`.

///|
/// Decode the layers of the given code block into coefficients.
///
/// The result will be stored in the form of a vector of signs and magnitudes
/// in the bitplane decoder context.
fn bitplane_decode(
  code_block : CodeBlock,
  sub_band_type : SubBandType,
  total_bitplanes : Int,
  style : CodeBlockStyle,
  tile_ctx : TileDecodeContext,
  storage : DecompositionStorage,
  strict : Bool,
) -> Unit raise DecodeError {
  tile_ctx.bit_plane_decode_context.reset(
    code_block, sub_band_type, style, total_bitplanes, strict,
  )
  tile_ctx.bit_plane_decode_buffers.reset()
  if !decode_inner(
      code_block,
      storage,
      tile_ctx.bit_plane_decode_context,
      tile_ctx.bit_plane_decode_buffers,
    ) {
    raise Decoding(CodeBlockDecodeFailure)
  }
}

///|
fn decode_inner(
  code_block : CodeBlock,
  storage : DecompositionStorage,
  ctx : BitPlaneDecodeContext,
  bp_buffers : BitPlaneDecodeBuffers,
) -> Bool {
  bp_buffers.reset()
  let mut last_segment_idx = 0
  let mut coding_passes = 0

  // Build a list so that we can associate coding passes with their segments
  // and data more easily.
  for l in code_block.layers_start..<code_block.layers_end {
    let layer = storage.layers[l]
    if layer.segments is Some((start, end)) {
      for s in start..<end {
        let segment = storage.segments[s]
        if segment.idx != last_segment_idx {
          if segment.idx != last_segment_idx + 1 {
            abort("assertion failed: segment.idx == last_segment_idx + 1")
          }
          bp_buffers.segment_ranges.push(bp_buffers.combined_len)
          bp_buffers.segment_coding_passes.push(coding_passes)
          last_segment_idx += 1
        }
        bp_buffers.extend_from(segment.data)
        coding_passes = (coding_passes + segment.coding_pases) & 0xFF
      }
    }
  }
  bp_buffers.segment_ranges.push(bp_buffers.combined_len)
  bp_buffers.segment_coding_passes.push(coding_passes)
  let is_normal_mode = !ctx.style.selective_arithmetic_coding_bypass &&
    !ctx.style.termination_on_each_pass
  if is_normal_mode {
    // Only one termination per code block, so we can just decode the
    // whole range in one single go, processing all coding passes at once.
    let decoder = ArithmeticDecoder::new(
      bp_buffers.combined_layers,
      0,
      bp_buffers.combined_len,
    )
    let end = if code_block.number_of_coding_passes < ctx.max_coding_passes {
      code_block.number_of_coding_passes
    } else {
      ctx.max_coding_passes
    }
    if ctx.can_use_fast_path() {
      if !fast_path_handle_coding_passes(0, end, ctx, decoder) {
        return false
      }
    } else if !handle_coding_passes(0, end, ctx, decoder) {
      return false
    }
  } else {
    // Otherwise, each segment introduces a termination. For "termination on
    // each pass", each segment only covers one coding pass
    // and a termination is introduced every time. Otherwise, for only
    // arithmetic coding bypass, terminations are introduced based on the
    // exact index of the covered coding passes (see Table D.9).
    for segment in 0..<(bp_buffers.segment_coding_passes.length() - 1) {
      let start_coding_pass = bp_buffers.segment_coding_passes[segment]
      let next = bp_buffers.segment_coding_passes[segment + 1]
      let end_coding_pass = if next < ctx.max_coding_passes {
        next
      } else {
        ctx.max_coding_passes
      }
      let data_start = bp_buffers.segment_ranges[segment]
      let data_end = bp_buffers.segment_ranges[segment + 1]
      let use_arithmetic = if ctx.style.selective_arithmetic_coding_bypass {
        if start_coding_pass <= 9 {
          true
        } else {
          // Only for cleanup pass.
          start_coding_pass % 3 == 0
        }
      } else {
        true
      }
      if use_arithmetic {
        let decoder = ArithmeticDecoder::new(
          bp_buffers.combined_layers,
          data_start,
          data_end - data_start,
        )
        if !handle_coding_passes(
            start_coding_pass, end_coding_pass, ctx, decoder,
          ) {
          return false
        }
      } else {
        let decoder = BypassDecoder::new(
          Bytes::from_array(
            bp_buffers.combined_layers.exact_view(
              start=data_start,
              end=data_end,
            ),
          )[:],
          ctx.strict,
        )
        if !handle_coding_passes(
            start_coding_pass, end_coding_pass, ctx, decoder,
          ) {
          return false
        }
      }
    }
  }
  true
}

///|
fn[D : BitDecoder] handle_coding_passes(
  start : Int,
  end : Int,
  ctx : BitPlaneDecodeContext,
  decoder : D,
) -> Bool {
  let reset_context_probabilities = ctx.style.reset_context_probabilities
  for coding_pass in start..<end {
    let current_bitplane = (coding_pass + 2) / 3
    ctx.current_bit_position = (ctx.bitplanes - 1 - current_bitplane) & 0xFF

    // The first bitplane only has a cleanup pass, all other bitplanes
    // are in the order SPP -> MRR -> C.
    match coding_pass % 3 {
      0 => {
        if !cleanup_pass(ctx, decoder) {
          return false
        }
        if ctx.style.segmentation_symbols {
          let b0 = decoder.bd_read_bit(ctx.contexts, 18)
          if b0 < 0 {
            return false
          }
          let b1 = decoder.bd_read_bit(ctx.contexts, 18)
          if b1 < 0 {
            return false
          }
          let b2 = decoder.bd_read_bit(ctx.contexts, 18)
          if b2 < 0 {
            return false
          }
          let b3 = decoder.bd_read_bit(ctx.contexts, 18)
          if b3 < 0 {
            return false
          }
          if (b0 != 1 || b1 != 0 || b2 != 1 || b3 != 0) && ctx.strict {
            return false
          }
        }
        ctx.reset_for_next_bitplane()
      }
      1 => if !significance_propagation_pass(ctx, decoder) { return false }
      _ => if !magnitude_refinement_pass(ctx, decoder) { return false }
    }
    if reset_context_probabilities {
      ctx.reset_contexts()
    }
  }
  true
}

///|
// We only allow 31 bit planes because we need one bit for the sign.
const BITPLANE_BIT_SIZE : Int = 31

///|
const SIGNIFICANCE_SHIFT : Int = 7

///|
const HAS_MAGNITUDE_REFINEMENT_SHIFT : Int = 6

///|
const HAS_ZERO_CODING_SHIFT : Int = 5

///|
const CLEANUP_SKIP_MASK : Int = 0xA0 // (1 << SIGNIFICANCE_SHIFT) | (1 << HAS_ZERO_CODING_SHIFT)

///|
const REFINEMENT_PASS_MASK : Int = 0xA0 // (1 << SIGNIFICANCE_SHIFT) | (1 << HAS_ZERO_CODING_SHIFT)

// Bit-packed coefficient state (only 3 bits used):
// - Bit 7: significance state (set when first non-zero bit is encountered)
// - Bit 6: has had magnitude refinement pass
// - Bit 5: zero coded in current bitplane's significance propagation pass

// `Coefficient`: the magnitude in bits 0-30 and the sign in bit 31.

///|
fn coefficient_get(v : UInt) -> Int {
  let magnitude = (v & 0x7FFFFFFF).reinterpret_as_int()
  // Map sign (0 for positive, 1 for negative) to 1, -1.
  magnitude * (1 - 2 * (v >> 31).reinterpret_as_int())
}

///|
const COEFFICIENTS_PADDING : Int = 1

// Store the significances of each neighbor for a specific coefficient.
// The order from MSB to LSB is as follows:
//
// top-left, top, top-right, left, bottom-left, right, bottom-right, bottom.
//
// See the `context_label_sign_coding` method for why we aren't simply using
// row-major order.

///|
priv struct BitPlaneDecodeBuffers {
  mut combined_layers : FixedArray[Byte]
  mut combined_len : Int
  segment_ranges : Array[Int]
  segment_coding_passes : Array[Int]
}

///|
fn BitPlaneDecodeBuffers::default() -> BitPlaneDecodeBuffers {
  {
    combined_layers: FixedArray::make(0, b'\x00'),
    combined_len: 0,
    segment_ranges: [],
    segment_coding_passes: [],
  }
}

///|
fn BitPlaneDecodeBuffers::reset(self : BitPlaneDecodeBuffers) -> Unit {
  self.combined_len = 0
  self.segment_ranges.clear()
  self.segment_coding_passes.clear()

  // The design of these two buffers is that the ranges are stored
  // as [idx, idx + 1), so we need to store the first 0 when resetting.
  self.segment_ranges.push(0)
  self.segment_coding_passes.push(0)
}

///|
fn BitPlaneDecodeBuffers::extend_from(
  self : BitPlaneDecodeBuffers,
  data : BytesView,
) -> Unit {
  let new_len = self.combined_len + data.length()
  if new_len > self.combined_layers.length() {
    let cap = if self.combined_layers.length() * 2 > new_len {
      self.combined_layers.length() * 2
    } else {
      new_len
    }
    let buf = FixedArray::make(cap, b'\x00')
    self.combined_layers.blit_to(buf, len=self.combined_len)
    self.combined_layers = buf
  }
  self.combined_layers.blit_from_bytesview(self.combined_len, data)
  self.combined_len = new_len
}

///|
priv struct BitPlaneDecodeContext {
  /// A vector of bit-packed fields for each coefficient in the code-block.
  mut coefficient_states : FixedArray[Int]
  /// Stripe-column state for the fast path.
  mut stripe_flags : FixedArray[UInt]
  mut stripe_flags_len : Int
  /// The neighbor significances for each coefficient.
  mut neighbor_significances : FixedArray[Int]
  /// The magnitude and signs of each coefficient that is successively built
  /// as we advance through the bitplanes.
  mut coefficients : FixedArray[UInt]
  /// The number of (padded) coefficients of the current code-block.
  mut num_coefficients : Int
  /// The width of the code-block we are processing.
  mut width : Int
  /// The width of the code-block we are processing, with padding.
  mut padded_width : Int
  /// The height of the code-block we are processing.
  mut height : Int
  /// The code-block style for the current code-block.
  mut style : CodeBlockStyle
  /// The number of bitplanes (minus implicitly missing bitplanes) to decode.
  mut bitplanes : Int
  /// Whether strict mode is enabled. (Never set by `reset` upstream, so it
  /// stays `false`.)
  strict : Bool
  /// The maximum number of coding passes to process.
  mut max_coding_passes : Int
  /// The type of sub-band the current code block belongs to.
  mut sub_band_type : SubBandType
  /// The arithmetic decoder contexts for each context label.
  contexts : FixedArray[Int]
  /// The bit position for the current bitplane.
  mut current_bit_position : Int
}

///|
fn BitPlaneDecodeContext::default() -> BitPlaneDecodeContext {
  {
    coefficient_states: FixedArray::make(0, 0),
    stripe_flags: FixedArray::make(0, 0),
    stripe_flags_len: 0,
    coefficients: FixedArray::make(0, 0),
    neighbor_significances: FixedArray::make(0, 0),
    num_coefficients: 0,
    width: 0,
    padded_width: COEFFICIENTS_PADDING * 2,
    height: 0,
    style: CodeBlockStyle::default(),
    bitplanes: 0,
    max_coding_passes: 0,
    strict: false,
    sub_band_type: LowLow,
    contexts: FixedArray::make(19, 0),
    current_bit_position: 0,
  }
}

///|
fn BitPlaneDecodeContext::can_use_fast_path(
  self : BitPlaneDecodeContext,
) -> Bool {
  self.height % 4 == 0 && !self.style.vertically_causal_context
}

///|
/// Completely reset context so that it can be reused for a new code-block.
fn BitPlaneDecodeContext::reset(
  self : BitPlaneDecodeContext,
  code_block : CodeBlock,
  sub_band_type : SubBandType,
  code_block_style : CodeBlockStyle,
  total_bitplanes : Int,
  strict : Bool,
) -> Unit raise DecodeError {
  let width = code_block.rect.width().reinterpret_as_int()
  let height = code_block.rect.height().reinterpret_as_int()
  let padded_width = width + COEFFICIENTS_PADDING * 2
  let padded_height = height + COEFFICIENTS_PADDING * 2
  let num_coefficients = padded_width * padded_height
  if self.coefficients.length() < num_coefficients {
    self.coefficients = FixedArray::make(num_coefficients, 0)
    self.neighbor_significances = FixedArray::make(num_coefficients, 0)
    self.coefficient_states = FixedArray::make(num_coefficients, 0)
  } else {
    self.coefficients.fill(0, end=num_coefficients)
    self.neighbor_significances.fill(0, end=num_coefficients)
    self.coefficient_states.fill(0, end=num_coefficients)
  }
  self.num_coefficients = num_coefficients
  let stripe_flags_len = ((height + 3) / 4 + 2) * padded_width
  if self.stripe_flags.length() < stripe_flags_len {
    self.stripe_flags = FixedArray::make(stripe_flags_len, 0)
  } else {
    self.stripe_flags.fill(0, end=stripe_flags_len)
  }
  self.stripe_flags_len = stripe_flags_len
  self.width = width
  self.padded_width = padded_width
  self.height = height
  self.sub_band_type = sub_band_type
  self.style = code_block_style
  self.reset_contexts()

  // "The maximum number of bit-planes available for the representation of
  // coefficients in any sub-band, b, is given by Mb as defined in Equation
  // (E-2). In general however, the number of actual bit-planes for which
  // coding passes are generated is Mb – P, where the number of missing most
  // significant bit-planes, P, may vary from code-block to code-block."

  // See issue 399. If this subtraction fails the file is in theory invalid,
  // but we still try to be lenient.
  self.bitplanes = if strict {
    if total_bitplanes < code_block.missing_bit_planes {
      raise Decoding(InvalidBitplaneCount)
    }
    total_bitplanes - code_block.missing_bit_planes
  } else if total_bitplanes < code_block.missing_bit_planes {
    0
  } else {
    total_bitplanes - code_block.missing_bit_planes
  }
  self.max_coding_passes = if self.bitplanes == 0 {
    0
  } else {
    (1 + 3 * (self.bitplanes - 1)) & 0xFF
  }
  if self.max_coding_passes < code_block.number_of_coding_passes && strict {
    raise Decoding(TooManyCodingPasses)
  }
}

///|
/// Reset each context to the initial state defined in table D.7.
fn BitPlaneDecodeContext::reset_contexts(self : BitPlaneDecodeContext) -> Unit {
  self.contexts.fill(0)
  self.contexts[0] = 4
  self.contexts[17] = 3
  self.contexts[18] = 46
}

///|
/// Reset state that is transient for each bitplane that is decoded.
fn BitPlaneDecodeContext::reset_for_next_bitplane(
  self : BitPlaneDecodeContext,
) -> Unit {
  let states = self.coefficient_states
  for i in 0..<self.num_coefficients {
    states[i] = states[i] & ((1 << HAS_ZERO_CODING_SHIFT) ^ 0xFF)
  }
}

///|
fn BitPlaneDecodeContext::index(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Int {
  x + y * self.padded_width
}

///|
fn BitPlaneDecodeContext::set_sign(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
  sign : Int,
) -> Unit {
  let idx = self.index(x, y)
  self.coefficients[idx] = self.coefficients[idx] |
    (sign.reinterpret_as_uint() << 31)
}

///|
fn BitPlaneDecodeContext::is_significant(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Bool {
  ((self.coefficient_states[self.index(x, y)] >> SIGNIFICANCE_SHIFT) & 1) == 1
}

///|
fn BitPlaneDecodeContext::set_significant(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Unit {
  let pw = self.padded_width
  let idx = x + y * pw
  self.coefficient_states[idx] = self.coefficient_states[idx] |
    (1 << SIGNIFICANCE_SHIFT)

  // Update all neighbors so they know this coefficient is significant now.
  let ns = self.neighbor_significances
  // top-left: set_bottom_right
  ns[idx - pw - 1] = ns[idx - pw - 1] | (1 << 1)
  // top: set_bottom
  ns[idx - pw] = ns[idx - pw] | 1
  // top-right: set_bottom_left
  ns[idx - pw + 1] = ns[idx - pw + 1] | (1 << 3)
  // left: set_right
  ns[idx - 1] = ns[idx - 1] | (1 << 2)
  // right: set_left
  ns[idx + 1] = ns[idx + 1] | (1 << 4)
  // bottom-left: set_top_right
  ns[idx + pw - 1] = ns[idx + pw - 1] | (1 << 5)
  // bottom: set_top
  ns[idx + pw] = ns[idx + pw] | (1 << 6)
  // bottom-right: set_top_left
  ns[idx + pw + 1] = ns[idx + pw + 1] | (1 << 7)
}

///|
fn BitPlaneDecodeContext::set_zero_coded(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Unit {
  let idx = self.index(x, y)
  self.coefficient_states[idx] = self.coefficient_states[idx] |
    (1 << HAS_ZERO_CODING_SHIFT)
}

///|
fn BitPlaneDecodeContext::set_magnitude_refined(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Unit {
  let idx = self.index(x, y)
  self.coefficient_states[idx] = self.coefficient_states[idx] |
    (1 << HAS_MAGNITUDE_REFINEMENT_SHIFT)
}

///|
fn BitPlaneDecodeContext::magnitude_refinement(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Int {
  (self.coefficient_states[self.index(x, y)] >> HAS_MAGNITUDE_REFINEMENT_SHIFT) &
  1
}

///|
fn BitPlaneDecodeContext::should_decode_cleanup(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Bool {
  // Checks that it's not significant and not zero-coded.
  (self.coefficient_states[self.index(x, y)] & CLEANUP_SKIP_MASK) == 0
}

///|
fn BitPlaneDecodeContext::should_decode_refinement(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Bool {
  // Checks that it's significant and not zero-coded.
  (self.coefficient_states[self.index(x, y)] & REFINEMENT_PASS_MASK) ==
  1 << SIGNIFICANCE_SHIFT
}

///|
fn BitPlaneDecodeContext::push_magnitude_bit(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
  bit : Int,
) -> Unit {
  let idx = self.index(x, y)
  self.coefficients[idx] = self.coefficients[idx] |
    shl_u32(bit.reinterpret_as_uint(), self.current_bit_position)
}

///|
fn BitPlaneDecodeContext::sign(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Int {
  (self.coefficients[self.index(x, y)] >> 31).reinterpret_as_int()
}

///|
fn BitPlaneDecodeContext::neighbor_in_next_stripe(
  self : BitPlaneDecodeContext,
  y : Int,
) -> Bool {
  // `pos.bottom().real_y()` is `y` and `pos.real_y()` is `y - 1`.
  y < self.height && y >> 2 > (y - 1) >> 2
}

///|
fn BitPlaneDecodeContext::neighborhood_significance_states(
  self : BitPlaneDecodeContext,
  x : Int,
  y : Int,
) -> Int {
  let neighbors = self.neighbor_significances[self.index(x, y)]
  if self.style.vertically_causal_context && self.neighbor_in_next_stripe(y) {
    // Needed for vertically causal context.
    neighbors & 0b11110100
  } else {
    neighbors
  }
}

///|
/// Perform the cleanup pass, specified in D.3.4.
///
/// See also the flow chart in Figure 7.3 in the JPEG2000 book.
fn[D : BitDecoder] cleanup_pass(
  ctx : BitPlaneDecodeContext,
  decoder : D,
) -> Bool {
  // "Each bit-plane of a code-block is scanned in a particular order.
  // Starting at the top left, the first four coefficients of the
  // first column are scanned, followed by the first four coefficients of
  // the second column and so on, until the right side of the code-block
  // is reached. The scan then returns to the left of the code-block and
  // the second set of four coefficients in each column is scanned. The
  // process is continued to the bottom of the code-block. If the
  // code-block height is not divisible by 4, the last set of coefficients
  // scanned in each column will contain fewer than 4 members."
  let width = ctx.width
  let height = ctx.height
  let mut base_row = 0
  while base_row < height {
    let row_end = if base_row + 4 < height { base_row + 4 } else { height }
    for x in 0..<width {
      let px = x + COEFFICIENTS_PADDING
      let mut py = base_row + COEFFICIENTS_PADDING
      while py - 1 < row_end {
        if ctx.should_decode_cleanup(px, py) {
          let real_y = py - 1
          let use_rl = real_y % 4 == 0 &&
            height - real_y >= 4 &&
            ctx.neighborhood_significance_states(px, py) == 0 &&
            ctx.neighborhood_significance_states(px, py + 1) == 0 &&
            ctx.neighborhood_significance_states(px, py + 2) == 0 &&
            ctx.neighborhood_significance_states(px, py + 3) == 0
          let mut bit = 0
          let mut skip = false
          if use_rl {
            // "If the four contiguous coefficients in the column being scanned are all decoded
            // in the cleanup pass and the context label for all is 0 (including context
            // coefficients from previous magnitude, significance and cleanup passes), then the
            // unique run-length context is given to the arithmetic decoder along with the bit
            // stream."
            let b = decoder.bd_read_bit(ctx.contexts, 17)
            if b < 0 {
              return false
            }
            if b == 0 {
              // "If the symbol 0 is returned, then all four contiguous coefficients in
              // the column remain insignificant and are set to zero."
              py += 3
              skip = true
            } else {
              // "Otherwise, if the symbol 1 is returned, then at least
              // one of the four contiguous coefficients in the column is
              // significant. The next two bits, returned with the
              // UNIFORM context (index 46 in Table C.2), denote which
              // coefficient from the top of the column down is the first
              // to be found significant."
              let n0 = decoder.bd_read_bit(ctx.contexts, 18)
              if n0 < 0 {
                return false
              }
              let n1 = decoder.bd_read_bit(ctx.contexts, 18)
              if n1 < 0 {
                return false
              }
              let num_zeroes = (n0 << 1) | n1
              py += num_zeroes
              bit = 1
            }
          } else {
            let ctx_label = context_label_zero_coding(px, py, ctx)
            bit = decoder.bd_read_bit(ctx.contexts, ctx_label)
            if bit < 0 {
              return false
            }
          }
          if !skip && bit == 1 {
            ctx.push_magnitude_bit(px, py, bit)
            decode_sign_bit(px, py, ctx, decoder) |> ignore
            ctx.set_significant(px, py)
          }
        }
        py += 1
      }
    }
    base_row += 4
  }
  true
}

///|
/// Perform the significance propagation pass (Section D.3.1).
///
/// See also the flow chart in Figure 7.4 in the JPEG2000 book.
fn[D : BitDecoder] significance_propagation_pass(
  ctx : BitPlaneDecodeContext,
  decoder : D,
) -> Bool {
  let width = ctx.width
  let height = ctx.height
  let mut base_row = 0
  while base_row < height {
    let row_end = if base_row + 4 < height { base_row + 4 } else { height }
    for x in 0..<width {
      let px = x + COEFFICIENTS_PADDING
      let mut py = base_row + COEFFICIENTS_PADDING
      while py - 1 < row_end {
        // "The significance propagation pass only includes bits of coefficients
        // that were insignificant (the significance state has yet to be set)
        // and have a non-zero context."
        if !ctx.is_significant(px, py) &&
          ctx.neighborhood_significance_states(px, py) != 0 {
          let ctx_label = context_label_zero_coding(px, py, ctx)
          let bit = decoder.bd_read_bit(ctx.contexts, ctx_label)
          if bit < 0 {
            return false
          }
          ctx.set_zero_coded(px, py)

          // "If the value of this bit is 1 then the significance
          // state is set to 1 and the immediate next bit to be decoded is
          // the sign bit for the coefficient. Otherwise, the significance
          // state remains 0."
          if bit == 1 {
            ctx.push_magnitude_bit(px, py, bit)
            if !decode_sign_bit(px, py, ctx, decoder) {
              return false
            }
            ctx.set_significant(px, py)
          }
        }
        py += 1
      }
    }
    base_row += 4
  }
  true
}

///|
/// Perform the magnitude refinement pass, specified in Section D.3.3.
///
/// See also the flow chart in Figure 7.5 in the JPEG2000 book.
fn[D : BitDecoder] magnitude_refinement_pass(
  ctx : BitPlaneDecodeContext,
  decoder : D,
) -> Bool {
  let width = ctx.width
  let height = ctx.height
  let mut base_row = 0
  while base_row < height {
    let row_end = if base_row + 4 < height { base_row + 4 } else { height }
    for x in 0..<width {
      let px = x + COEFFICIENTS_PADDING
      let mut py = base_row + COEFFICIENTS_PADDING
      while py - 1 < row_end {
        if ctx.should_decode_refinement(px, py) {
          let ctx_label = context_label_magnitude_refinement_coding(px, py, ctx)
          let bit = decoder.bd_read_bit(ctx.contexts, ctx_label)
          if bit < 0 {
            return false
          }
          if bit == 1 {
            ctx.push_magnitude_bit(px, py, bit)
          }
          ctx.set_magnitude_refined(px, py)
        }
        py += 1
      }
    }
    base_row += 4
  }
  true
}

///|
/// Decode a sign bit (Section D.3.2).
fn[D : BitDecoder] decode_sign_bit(
  x : Int,
  y : Int,
  ctx : BitPlaneDecodeContext,
  decoder : D,
) -> Bool {
  let packed = context_label_sign_coding(x, y, ctx)
  let ctx_label = packed & 0xFF
  let xor_bit = packed >> 8
  let b = decoder.bd_read_bit(ctx.contexts, ctx_label)
  if b < 0 {
    return false
  }
  let sign_bit = if decoder.bd_is_bypass() { b } else { b ^ xor_bit }
  ctx.set_sign(x, y, sign_bit)
  true
}

///|
/// Based on Table D.2.
fn context_label_sign_coding(
  x : Int,
  y : Int,
  ctx : BitPlaneDecodeContext,
) -> Int {
  // A lot of subtleties going on here, all in the interest of achieving
  // the best performance. Fundamentally, we need to determine the
  // significances as well as signs of the four neighbors (i.e. not
  // including the diagonal neighbors) and based on what the sum of signs
  // is, we assign a context label.

  // First, let's get all neighbor significances and mask out the diagonals.
  let significances = ctx.neighborhood_significance_states(x, y) & 0b0101_0101

  // Get all the signs.
  let left_sign = ctx.sign(x - 1, y)
  let right_sign = ctx.sign(x + 1, y)
  let top_sign = ctx.sign(x, y - 1)
  let bottom_sign = if ctx.style.vertically_causal_context &&
    ctx.neighbor_in_next_stripe(y) {
    0
  } else {
    ctx.sign(x, y + 1)
  }

  // Due to the specific layout of `NeighborSignificances`, direct neighbors
  // and diagonals are interleaved. Therefore, we create a new bit-packed
  // representation that indicates whether the top/left/right/bottom sign
  // is positive, negative, or insignificant. We need two bits for this.
  // 00 represents insignificant, 01 positive and 10 negative. 11
  // is an invalid combination.
  let signs = (top_sign << 6) |
    (left_sign << 4) |
    (right_sign << 2) |
    bottom_sign
  let negative_significances = significances & signs
  let positive_significances = significances & (signs ^ 0xFF)
  let merged_significances = (
      (negative_significances << 1) | positive_significances
    ) &
    0xFF

  // Now we can just perform one single lookup!
  sign_context_lookup[merged_significances]
}

///|
/// Return the context label for zero coding (Section D.3.1).
fn context_label_zero_coding(
  x : Int,
  y : Int,
  ctx : BitPlaneDecodeContext,
) -> Int {
  let neighbors = ctx.neighborhood_significance_states(x, y)

  // Once again, the neighbors field is bit-packed, so we can just generate
  // a table for all u8 values and assign the correct context based on the
  // exact value of that field.
  match ctx.sub_band_type {
    LowLow | LowHigh => zero_ctx_ll_lh_lookup[neighbors]
    HighLow => zero_ctx_hl_lookup[neighbors]
    HighHigh => zero_ctx_hh_lookup[neighbors]
  }
}

///|
/// Return the context label for magnitude refinement coding (Table D.4).
fn context_label_magnitude_refinement_coding(
  x : Int,
  y : Int,
  ctx : BitPlaneDecodeContext,
) -> Int {
  // If magnitude refined, then 16.
  let m1 = ctx.magnitude_refinement(x, y) * 16
  // Else: If at least one neighbor is significant then 15, else 14.
  let n = ctx.neighborhood_significance_states(x, y)
  let m2 = 14 + (if n < 1 { n } else { 1 })
  if m1 > m2 {
    m1
  } else {
    m2
  }
}

///|
// We use a trait so that we can mock the arithmetic decoder for tests.
priv trait BitDecoder {
  fn bd_is_bypass(Self) -> Bool
  /// Read a bit using the given context, -1 for `None`.
  fn bd_read_bit(Self, FixedArray[Int], Int) -> Int
}

///|
impl BitDecoder for ArithmeticDecoder with fn bd_is_bypass(_) {
  false
}

///|
impl BitDecoder for ArithmeticDecoder with fn bd_read_bit(self, contexts, label) {
  self.read_bit(contexts, label)
}

///|
priv struct BypassDecoder {
  reader : BitReader
  strict : Bool
}

///|
fn BypassDecoder::new(data : BytesView, strict : Bool) -> BypassDecoder {
  { reader: BitReader::new(data), strict, }
}

///|
impl BitDecoder for BypassDecoder with fn bd_is_bypass(_) {
  true
}

///|
impl BitDecoder for BypassDecoder with fn bd_read_bit(self, _, _) {
  match self.reader.read_bits_with_stuffing(1) {
    Some(b) => b.reinterpret_as_int()
    None =>
      if !self.strict {
        // If not in strict mode, just pad with ones. Not sure if
        // zeroes would be better here, but since the arithmetic decoder
        // is also padded with 0xFF maybe 1 is the better choice?
        1
      } else {
        // We have too little data, return `None`.
        -1
      }
  }
}

// mod fast_path

// Note: Credit where credit is due, this fast path borrows some core ideas
// from the OpenJPEG implementation (e.g. the idea to bitpack state into u32),
// but has been adapted to more naturally work with our implementation.

///|
fn fast_path_handle_coding_passes(
  start : Int,
  end : Int,
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
) -> Bool {
  let reset_context_probabilities = ctx.style.reset_context_probabilities
  for coding_pass in start..<end {
    let current_bitplane = (coding_pass + 2) / 3
    ctx.current_bit_position = (ctx.bitplanes - 1 - current_bitplane) & 0xFF
    match coding_pass % 3 {
      0 => {
        fp_cleanup_pass(ctx, decoder)
        if ctx.style.segmentation_symbols {
          let b0 = decoder.read_bit(ctx.contexts, 18)
          let b1 = decoder.read_bit(ctx.contexts, 18)
          let b2 = decoder.read_bit(ctx.contexts, 18)
          let b3 = decoder.read_bit(ctx.contexts, 18)
          if (b0 != 1 || b1 != 0 || b2 != 1 || b3 != 0) && ctx.strict {
            return false
          }
        }
        fp_reset_for_next_bitplane(ctx)
      }
      1 => fp_significance_propagation_pass(ctx, decoder)
      _ => fp_magnitude_refinement_pass(ctx, decoder)
    }
    if reset_context_probabilities {
      ctx.reset_contexts()
    }
  }
  true
}

///|
fn fp_cleanup_pass(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
) -> Unit {
  let zero_contexts = fp_zero_context_lookup(ctx.sub_band_type)
  let width = ctx.width
  let stride = ctx.padded_width
  let stripe_count = ctx.height / 4
  let padding = COEFFICIENTS_PADDING
  let mut flag_base = padding * stride + padding
  let mut coefficient_base = padding * stride + padding
  let stripe_flags = ctx.stripe_flags
  for _ in 0..<stripe_count {
    for x in 0..<width {
      let flag_idx = flag_base + x
      let coefficient_idx = coefficient_base + x
      let mut flags = stripe_flags[flag_idx]
      let use_rl = flags == 0
      if use_rl {
        let bit = decoder.read_bit(ctx.contexts, 17)
        if bit == 1 {
          let mut num_zeroes = decoder.read_bit(ctx.contexts, 18)
          num_zeroes = (num_zeroes << 1) | decoder.read_bit(ctx.contexts, 18)
          flags = fp_cleanup_from_run_length(
            ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
            num_zeroes,
          )
        }
      } else {
        flags = fp_cleanup_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          0, true, false,
        )
        flags = fp_cleanup_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          1, true, false,
        )
        flags = fp_cleanup_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          2, true, false,
        )
        flags = fp_cleanup_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          3, true, false,
        )
      }
      stripe_flags[flag_idx] = flags & (FLAG_ZERO_CODED_ALL ^ 0xFFFFFFFF)
    }
    flag_base += stride
    coefficient_base += 4 * stride
  }
}

///|
fn fp_cleanup_from_run_length(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
  zero_contexts : FixedArray[Int],
  flag_idx : Int,
  coefficient_idx : Int,
  stride : Int,
  flags : UInt,
  num_zeroes : Int,
) -> UInt {
  let mut flags = flags
  match num_zeroes {
    0 => {
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 0,
        false, true,
      )
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 1,
        false, false,
      )
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 2,
        false, false,
      )
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 3,
        false, false,
      )
    }
    1 => {
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 1,
        false, true,
      )
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 2,
        false, false,
      )
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 3,
        false, false,
      )
    }
    2 => {
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 2,
        false, true,
      )
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 3,
        false, false,
      )
    }
    _ =>
      flags = fp_cleanup_coefficient(
        ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags, 3,
        false, true,
      )
  }
  flags
}

///|
fn fp_cleanup_coefficient(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
  zero_contexts : FixedArray[Int],
  flag_idx : Int,
  column_coefficient_idx : Int,
  stride : Int,
  flags : UInt,
  coefficient_in_stripe : Int,
  check_flags : Bool,
  already_known_significant : Bool,
) -> UInt {
  let shift = coefficient_in_stripe * FLAGS_PER_COEFFICIENT
  if !check_flags ||
    (flags & ((FLAG_SIGNIFICANT_THIS | FLAG_ZERO_CODED_THIS) << shift)) == 0 {
    if !already_known_significant {
      let ctx_label = zero_contexts[((flags >> shift) &
        FLAG_SIGNIFICANT_NEIGHBORS).reinterpret_as_int()]
      if decoder.read_bit(ctx.contexts, ctx_label) == 0 {
        return flags
      }
    }
    let coefficient_idx = column_coefficient_idx +
      coefficient_in_stripe * stride
    fp_push_magnitude_bit(ctx, coefficient_idx, 1)
    let sign = fp_decode_sign_bit(
      ctx, decoder, flag_idx, flags, coefficient_in_stripe,
    )
    fp_set_sign(ctx, coefficient_idx, sign)
    return fp_set_significant(
      ctx, flag_idx, stride, flags, coefficient_in_stripe, sign,
    )
  }
  flags
}

///|
fn fp_significance_propagation_pass(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
) -> Unit {
  let zero_contexts = fp_zero_context_lookup(ctx.sub_band_type)
  let width = ctx.width
  let stride = ctx.padded_width
  let stripe_count = ctx.height / 4
  let padding = COEFFICIENTS_PADDING
  let mut flag_base = padding * stride + padding
  let mut coefficient_base = padding * stride + padding
  let stripe_flags = ctx.stripe_flags
  for _ in 0..<stripe_count {
    for x in 0..<width {
      let flag_idx = flag_base + x
      let coefficient_idx = coefficient_base + x
      let mut flags = stripe_flags[flag_idx]
      if flags != 0 {
        flags = fp_significance_propagation_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          0,
        )
        flags = fp_significance_propagation_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          1,
        )
        flags = fp_significance_propagation_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          2,
        )
        flags = fp_significance_propagation_coefficient(
          ctx, decoder, zero_contexts, flag_idx, coefficient_idx, stride, flags,
          3,
        )
      }
      stripe_flags[flag_idx] = flags
    }
    flag_base += stride
    coefficient_base += 4 * stride
  }
}

///|
fn fp_significance_propagation_coefficient(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
  zero_contexts : FixedArray[Int],
  flag_idx : Int,
  column_coefficient_idx : Int,
  stride : Int,
  flags : UInt,
  coefficient_in_stripe : Int,
) -> UInt {
  let shift = coefficient_in_stripe * FLAGS_PER_COEFFICIENT
  let shifted_flags = flags >> shift
  let should_propagate = (
      shifted_flags & (FLAG_SIGNIFICANT_THIS | FLAG_ZERO_CODED_THIS)
    ) ==
    0 &&
    (shifted_flags & FLAG_SIGNIFICANT_NEIGHBORS) != 0
  if should_propagate {
    let ctx_label = zero_contexts[(shifted_flags & FLAG_SIGNIFICANT_NEIGHBORS).reinterpret_as_int()]
    let bit = decoder.read_bit(ctx.contexts, ctx_label)
    let flags = flags | (FLAG_ZERO_CODED_THIS << shift)
    if bit == 1 {
      let coefficient_idx = column_coefficient_idx +
        coefficient_in_stripe * stride
      fp_push_magnitude_bit(ctx, coefficient_idx, bit)
      let sign = fp_decode_sign_bit(
        ctx, decoder, flag_idx, flags, coefficient_in_stripe,
      )
      fp_set_sign(ctx, coefficient_idx, sign)
      return fp_set_significant(
        ctx, flag_idx, stride, flags, coefficient_in_stripe, sign,
      )
    }
    return flags
  }
  flags
}

///|
fn fp_magnitude_refinement_pass(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
) -> Unit {
  let width = ctx.width
  let stride = ctx.padded_width
  let stripe_count = ctx.height / 4
  let padding = COEFFICIENTS_PADDING
  let mut flag_base = padding * stride + padding
  let mut coefficient_base = padding * stride + padding
  let stripe_flags = ctx.stripe_flags
  for _ in 0..<stripe_count {
    for x in 0..<width {
      let flag_idx = flag_base + x
      let coefficient_idx = coefficient_base + x
      let mut flags = stripe_flags[flag_idx]
      if flags != 0 {
        flags = fp_magnitude_refinement_coefficient(
          ctx, decoder, coefficient_idx, stride, flags, 0,
        )
        flags = fp_magnitude_refinement_coefficient(
          ctx, decoder, coefficient_idx, stride, flags, 1,
        )
        flags = fp_magnitude_refinement_coefficient(
          ctx, decoder, coefficient_idx, stride, flags, 2,
        )
        flags = fp_magnitude_refinement_coefficient(
          ctx, decoder, coefficient_idx, stride, flags, 3,
        )
      }
      stripe_flags[flag_idx] = flags
    }
    flag_base += stride
    coefficient_base += 4 * stride
  }
}

///|
fn fp_magnitude_refinement_coefficient(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
  column_coefficient_idx : Int,
  stride : Int,
  flags : UInt,
  coefficient_in_stripe : Int,
) -> UInt {
  let shift = coefficient_in_stripe * FLAGS_PER_COEFFICIENT
  let shifted_flags = flags >> shift
  let should_decode_refinement = (
      shifted_flags & (FLAG_SIGNIFICANT_THIS | FLAG_ZERO_CODED_THIS)
    ) ==
    FLAG_SIGNIFICANT_THIS
  if should_decode_refinement {
    let ctx_label = fp_magnitude_refinement_context(shifted_flags)
    let bit = decoder.read_bit(ctx.contexts, ctx_label)
    if bit == 1 {
      fp_push_magnitude_bit(
        ctx,
        column_coefficient_idx + coefficient_in_stripe * stride,
        bit,
      )
    }
    return flags | (FLAG_MAGNITUDE_REFINED_THIS << shift)
  }
  flags
}

///|
fn fp_decode_sign_bit(
  ctx : BitPlaneDecodeContext,
  decoder : ArithmeticDecoder,
  flag_idx : Int,
  flags : UInt,
  coefficient_in_stripe : Int,
) -> Int {
  let shift = coefficient_in_stripe * FLAGS_PER_COEFFICIENT
  let shifted_flags = flags >> shift
  let left_flags = ctx.stripe_flags[flag_idx - 1]
  let right_flags = ctx.stripe_flags[flag_idx + 1]
  let top_sign = if coefficient_in_stripe == 0 {
    (flags >> FLAG_SIGN_TOP_STRIPE_SHIFT) & 1
  } else {
    (flags >> (FLAG_SIGN_THIS_SHIFT + (coefficient_in_stripe - 1) * 3)) & 1
  }
  let bottom_sign = (
      flags >>
      (
        FLAG_SIGN_BOTTOM_THIS_SHIFT +
        coefficient_in_stripe * FLAGS_PER_COEFFICIENT
      )
    ) &
    1
  let left_sign = (left_flags >> (FLAG_SIGN_THIS_SHIFT + shift)) & 1
  let right_sign = (right_flags >> (FLAG_SIGN_THIS_SHIFT + shift)) & 1
  let lookup = left_sign |
    (if (shifted_flags & FLAG_SIGNIFICANT_TOP) != 0 { 1U << 1 } else { 0 }) |
    (right_sign << 2) |
    (if (shifted_flags & FLAG_SIGNIFICANT_LEFT) != 0 { 1U << 3 } else { 0 }) |
    (top_sign << 4) |
    (if (shifted_flags & FLAG_SIGNIFICANT_RIGHT) != 0 { 1U << 5 } else { 0 }) |
    (bottom_sign << 6) |
    (if (shifted_flags & FLAG_SIGNIFICANT_BOTTOM) != 0 { 1U << 7 } else { 0 })
  let packed = sign_context_stripe_lookup[lookup.reinterpret_as_int()]
  decoder.read_bit(ctx.contexts, packed & 0xFF) ^ (packed >> 8)
}

///|
fn fp_zero_context_lookup(sub_band_type : SubBandType) -> FixedArray[Int] {
  match sub_band_type {
    LowLow | LowHigh => zero_ctx_ll_lh_stripe_lookup
    HighLow => zero_ctx_hl_stripe_lookup
    HighHigh => zero_ctx_hh_stripe_lookup
  }
}

///|
fn fp_magnitude_refinement_context(flags : UInt) -> Int {
  if (flags & FLAG_MAGNITUDE_REFINED_THIS) != 0 {
    16
  } else if (flags & FLAG_SIGNIFICANT_NEIGHBORS) != 0 {
    15
  } else {
    14
  }
}

///|
fn fp_reset_for_next_bitplane(ctx : BitPlaneDecodeContext) -> Unit {
  let stripe_flags = ctx.stripe_flags
  let mask = FLAG_ZERO_CODED_ALL ^ 0xFFFFFFFF
  for i in 0..<ctx.stripe_flags_len {
    stripe_flags[i] = stripe_flags[i] & mask
  }
}

///|
fn fp_push_magnitude_bit(
  ctx : BitPlaneDecodeContext,
  idx : Int,
  bit : Int,
) -> Unit {
  ctx.coefficients[idx] = ctx.coefficients[idx] |
    shl_u32(bit.reinterpret_as_uint(), ctx.current_bit_position)
}

///|
fn fp_set_sign(ctx : BitPlaneDecodeContext, idx : Int, sign : Int) -> Unit {
  ctx.coefficients[idx] = ctx.coefficients[idx] |
    ((sign & 0xFF).reinterpret_as_uint() << 31)
}

///|
fn fp_set_significant(
  ctx : BitPlaneDecodeContext,
  flag_idx : Int,
  stride : Int,
  flags : UInt,
  coefficient_in_stripe : Int,
  sign : Int,
) -> UInt {
  let shift = coefficient_in_stripe * FLAGS_PER_COEFFICIENT
  let sign = sign.reinterpret_as_uint()
  let stripe_flags = ctx.stripe_flags
  stripe_flags[flag_idx - 1] = stripe_flags[flag_idx - 1] |
    (FLAG_SIGNIFICANT_RIGHT << shift)
  let flags = flags |
    (((sign << FLAG_SIGN_THIS_SHIFT) | FLAG_SIGNIFICANT_THIS) << shift)
  stripe_flags[flag_idx + 1] = stripe_flags[flag_idx + 1] |
    (FLAG_SIGNIFICANT_LEFT << shift)
  if coefficient_in_stripe == 0 {
    let top = flag_idx - stride
    stripe_flags[top] = stripe_flags[top] |
      (sign << FLAG_SIGN_BOTTOM_STRIPE_SHIFT) |
      (FLAG_SIGNIFICANT_BOTTOM << LAST_COEFFICIENT_SHIFT)
    stripe_flags[top - 1] = stripe_flags[top - 1] |
      (FLAG_SIGNIFICANT_BOTTOM_RIGHT << LAST_COEFFICIENT_SHIFT)
    stripe_flags[top + 1] = stripe_flags[top + 1] |
      (FLAG_SIGNIFICANT_BOTTOM_LEFT << LAST_COEFFICIENT_SHIFT)
  }
  if coefficient_in_stripe == 3 {
    let bottom = flag_idx + stride
    stripe_flags[bottom] = stripe_flags[bottom] |
      (sign << FLAG_SIGN_TOP_STRIPE_SHIFT) |
      FLAG_SIGNIFICANT_TOP
    stripe_flags[bottom - 1] = stripe_flags[bottom - 1] |
      FLAG_SIGNIFICANT_TOP_RIGHT
    stripe_flags[bottom + 1] = stripe_flags[bottom + 1] |
      FLAG_SIGNIFICANT_TOP_LEFT
  }
  flags
}

// State for a single stripe is stored in a bit-packed u32.
//
// Significance states:
//   0: lane 0 top-left
//   1: lane 0 top
//   2: lane 0 top-right
//   3: lane 0 left, lane 1 top-left
//   4: lane 0 this, lane 1 top
//   5: lane 0 right, lane 1 top-right
//   6: lane 0 bottom-left, lane 1 left, lane 2 top-left
//   7: lane 0 bottom, lane 1 this, lane 2 top
//   8: lane 0 bottom-right, lane 1 right, lane 2 top-right
//   9: lane 1 bottom-left, lane 2 left, lane 3 top-left
//   10: lane 1 bottom, lane 2 this, lane 3 top
//   11: lane 1 bottom-right, lane 2 right, lane 3 top-right
//   12: lane 2 bottom-left, lane 3 left
//   13: lane 2 bottom, lane 3 this
//   14: lane 2 bottom-right, lane 3 right
//   15: lane 3 bottom-left
//   16: lane 3 bottom
//   17: lane 3 bottom-right
//
// Top stripe-boundary sign:
//   18: sign above the stripe
//
// Per-lane coefficient states:
//   19: lane 0 sign
//   20: lane 0 magnitude-refined
//   21: lane 0 zero-coded
//   22: lane 1 sign
//   23: lane 1 magnitude-refined
//   24: lane 1 zero-coded
//   25: lane 2 sign
//   26: lane 2 magnitude-refined
//   27: lane 2 zero-coded
//   28: lane 3 sign
//   29: lane 3 magnitude-refined
//   30: lane 3 zero-coded
//
// Bottom stripe-boundary sign:
//   31: sign below the stripe

///|
const FLAGS_PER_COEFFICIENT : Int = 3

///|
const LAST_COEFFICIENT_SHIFT : Int = 9 // 3 * FLAGS_PER_COEFFICIENT

///|
const FLAG_SIGNIFICANT_TOP_LEFT : UInt = 0x1 // 1 << 0

///|
const FLAG_SIGNIFICANT_TOP : UInt = 0x2 // 1 << 1

///|
const FLAG_SIGNIFICANT_TOP_RIGHT : UInt = 0x4 // 1 << 2

///|
const FLAG_SIGNIFICANT_LEFT : UInt = 0x8 // 1 << 3

///|
const FLAG_SIGNIFICANT_THIS : UInt = 0x10 // 1 << 4

///|
const FLAG_SIGNIFICANT_RIGHT : UInt = 0x20 // 1 << 5

///|
const FLAG_SIGNIFICANT_BOTTOM_LEFT : UInt = 0x40 // 1 << 6

///|
const FLAG_SIGNIFICANT_BOTTOM : UInt = 0x80 // 1 << 7

///|
const FLAG_SIGNIFICANT_BOTTOM_RIGHT : UInt = 0x100 // 1 << 8

///|
/// All neighbors (everything but `FLAG_SIGNIFICANT_THIS`).
const FLAG_SIGNIFICANT_NEIGHBORS : UInt = 0x1EF

///|
const FLAG_SIGN_TOP_STRIPE_SHIFT : Int = 18

///|
const FLAG_SIGN_THIS_SHIFT : Int = 19

///|
const FLAG_MAGNITUDE_REFINED_THIS : UInt = 0x100000 // 1 << 20

///|
const FLAG_ZERO_CODED_THIS : UInt = 0x200000 // 1 << 21

///|
const FLAG_SIGN_BOTTOM_THIS_SHIFT : Int = 22

///|
const FLAG_SIGN_BOTTOM_STRIPE_SHIFT : Int = 31

///|
/// (1 << 21) | (1 << 24) | (1 << 27) | (1 << 30)
const FLAG_ZERO_CODED_ALL : UInt = 0x49200000

// Those are basically the same as the lookup tables in the default path,
// but changed such that it works with the layout of a flag.

///|
let sign_context_stripe_lookup : FixedArray[Int] = build_sign_context_lookup()

///|
fn build_sign_context_lookup() -> FixedArray[Int] {
  let out = FixedArray::make(256, 0)
  for lookup in 0..<256 {
    let left_sign = lookup & 1
    let top_significance = (lookup >> 1) & 1
    let right_sign = (lookup >> 2) & 1
    let left_significance = (lookup >> 3) & 1
    let top_sign = (lookup >> 4) & 1
    let right_significance = (lookup >> 5) & 1
    let bottom_sign = (lookup >> 6) & 1
    let bottom_significance = (lookup >> 7) & 1
    let significances = (top_significance << 6) |
      (left_significance << 4) |
      (right_significance << 2) |
      bottom_significance
    let signs = (top_sign << 6) |
      (left_sign << 4) |
      (right_sign << 2) |
      bottom_sign
    let merged_significances = ((significances & signs) << 1) |
      (significances & signs.lnot())
    out[lookup] = sign_context_lookup[merged_significances]
  }
  out
}

///|
let zero_ctx_ll_lh_stripe_lookup : FixedArray[Int] = build_zero_context_lookup(
  zero_ctx_ll_lh_lookup,
)

///|
let zero_ctx_hl_stripe_lookup : FixedArray[Int] = build_zero_context_lookup(
  zero_ctx_hl_lookup,
)

///|
let zero_ctx_hh_stripe_lookup : FixedArray[Int] = build_zero_context_lookup(
  zero_ctx_hh_lookup,
)

///|
fn build_zero_context_lookup(source : FixedArray[Int]) -> FixedArray[Int] {
  let out = FixedArray::make(512, 0)
  for flags in 0..<512 {
    out[flags] = source[neighbor_byte(flags)]
  }
  out
}

///|
fn neighbor_byte(flags : Int) -> Int {
  let f = flags.reinterpret_as_uint()
  (if (f & FLAG_SIGNIFICANT_TOP_LEFT) != 0 { 1 << 7 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_TOP) != 0 { 1 << 6 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_TOP_RIGHT) != 0 { 1 << 5 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_LEFT) != 0 { 1 << 4 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_BOTTOM_LEFT) != 0 { 1 << 3 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_RIGHT) != 0 { 1 << 2 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_BOTTOM_RIGHT) != 0 { 1 << 1 } else { 0 }) |
  (if (f & FLAG_SIGNIFICANT_BOTTOM) != 0 { 1 } else { 0 })
}

///|
/// `SIGN_CONTEXT_LOOKUP`: each `(label, xor_bit)` is packed as
/// `label | xor_bit << 8`.
let sign_context_lookup : FixedArray[Int] = [
  9, 10, 266, 0, 12, 13, 11, 0, 268, 267, 269, 0, 0, 0, 0, 0, 12, 13, 11, 0, 12,
  13, 11, 0, 9, 10, 266, 0, 0, 0, 0, 0, 268, 267, 269, 0, 9, 10, 266, 0, 268, 267,
  269, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 10, 9,
  0, 13, 13, 12, 0, 267, 267, 268, 0, 0, 0, 0, 0, 13, 13, 12, 0, 13, 13, 12, 0, 10,
  10, 9, 0, 0, 0, 0, 0, 267, 267, 268, 0, 10, 10, 9, 0, 267, 267, 268, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 266, 9, 266, 0, 11, 12, 11,
  0, 269, 268, 269, 0, 0, 0, 0, 0, 11, 12, 11, 0, 11, 12, 11, 0, 266, 9, 266, 0,
  0, 0, 0, 0, 269, 268, 269, 0, 266, 9, 266, 0, 269, 268, 269, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

///|
let zero_ctx_ll_lh_lookup : FixedArray[Int] = [
  0, 3, 1, 3, 5, 7, 6, 7, 1, 3, 2, 3, 6, 7, 6, 7, 5, 7, 6, 7, 8, 8, 8, 8, 6, 7, 6,
  7, 8, 8, 8, 8, 1, 3, 2, 3, 6, 7, 6, 7, 2, 3, 2, 3, 6, 7, 6, 7, 6, 7, 6, 7, 8, 8,
  8, 8, 6, 7, 6, 7, 8, 8, 8, 8, 3, 4, 3, 4, 7, 7, 7, 7, 3, 4, 3, 4, 7, 7, 7, 7, 7,
  7, 7, 7, 8, 8, 8, 8, 7, 7, 7, 7, 8, 8, 8, 8, 3, 4, 3, 4, 7, 7, 7, 7, 3, 4, 3, 4,
  7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 7, 7, 7, 7, 8, 8, 8, 8, 1, 3, 2, 3, 6, 7, 6,
  7, 2, 3, 2, 3, 6, 7, 6, 7, 6, 7, 6, 7, 8, 8, 8, 8, 6, 7, 6, 7, 8, 8, 8, 8, 2, 3,
  2, 3, 6, 7, 6, 7, 2, 3, 2, 3, 6, 7, 6, 7, 6, 7, 6, 7, 8, 8, 8, 8, 6, 7, 6, 7, 8,
  8, 8, 8, 3, 4, 3, 4, 7, 7, 7, 7, 3, 4, 3, 4, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8,
  7, 7, 7, 7, 8, 8, 8, 8, 3, 4, 3, 4, 7, 7, 7, 7, 3, 4, 3, 4, 7, 7, 7, 7, 7, 7, 7,
  7, 8, 8, 8, 8, 7, 7, 7, 7, 8, 8, 8, 8,
]

///|
let zero_ctx_hl_lookup : FixedArray[Int] = [
  0, 5, 1, 6, 3, 7, 3, 7, 1, 6, 2, 6, 3, 7, 3, 7, 3, 7, 3, 7, 4, 7, 4, 7, 3, 7, 3,
  7, 4, 7, 4, 7, 1, 6, 2, 6, 3, 7, 3, 7, 2, 6, 2, 6, 3, 7, 3, 7, 3, 7, 3, 7, 4, 7,
  4, 7, 3, 7, 3, 7, 4, 7, 4, 7, 5, 8, 6, 8, 7, 8, 7, 8, 6, 8, 6, 8, 7, 8, 7, 8, 7,
  8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 6, 8, 6, 8, 7, 8, 7, 8, 6, 8, 6, 8,
  7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 1, 6, 2, 6, 3, 7, 3,
  7, 2, 6, 2, 6, 3, 7, 3, 7, 3, 7, 3, 7, 4, 7, 4, 7, 3, 7, 3, 7, 4, 7, 4, 7, 2, 6,
  2, 6, 3, 7, 3, 7, 2, 6, 2, 6, 3, 7, 3, 7, 3, 7, 3, 7, 4, 7, 4, 7, 3, 7, 3, 7, 4,
  7, 4, 7, 6, 8, 6, 8, 7, 8, 7, 8, 6, 8, 6, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8,
  7, 8, 7, 8, 7, 8, 7, 8, 6, 8, 6, 8, 7, 8, 7, 8, 6, 8, 6, 8, 7, 8, 7, 8, 7, 8, 7,
  8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8, 7, 8,
]

///|
let zero_ctx_hh_lookup : FixedArray[Int] = [
  0, 1, 3, 4, 1, 2, 4, 5, 3, 4, 6, 7, 4, 5, 7, 7, 1, 2, 4, 5, 2, 2, 5, 5, 4, 5, 7,
  7, 5, 5, 7, 7, 3, 4, 6, 7, 4, 5, 7, 7, 6, 7, 8, 8, 7, 7, 8, 8, 4, 5, 7, 7, 5, 5,
  7, 7, 7, 7, 8, 8, 7, 7, 8, 8, 1, 2, 4, 5, 2, 2, 5, 5, 4, 5, 7, 7, 5, 5, 7, 7, 2,
  2, 5, 5, 2, 2, 5, 5, 5, 5, 7, 7, 5, 5, 7, 7, 4, 5, 7, 7, 5, 5, 7, 7, 7, 7, 8, 8,
  7, 7, 8, 8, 5, 5, 7, 7, 5, 5, 7, 7, 7, 7, 8, 8, 7, 7, 8, 8, 3, 4, 6, 7, 4, 5, 7,
  7, 6, 7, 8, 8, 7, 7, 8, 8, 4, 5, 7, 7, 5, 5, 7, 7, 7, 7, 8, 8, 7, 7, 8, 8, 6, 7,
  8, 8, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 8, 8, 7, 7, 8, 8, 8, 8, 8, 8, 8,
  8, 8, 8, 4, 5, 7, 7, 5, 5, 7, 7, 7, 7, 8, 8, 7, 7, 8, 8, 5, 5, 7, 7, 5, 5, 7, 7,
  7, 7, 8, 8, 7, 7, 8, 8, 7, 7, 8, 8, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 8,
  8, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
]
