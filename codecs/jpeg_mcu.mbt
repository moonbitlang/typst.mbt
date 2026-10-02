// Port of `zune-jpeg` (v0.5.15) `src/mcu.rs`: baseline decoding of MCUs and
// their post processing (up-sampling and color conversion).
//
// The decoder runs in non-strict mode (as configured by the `image` crate),
// so recoverable errors terminate decoding and leave the rest of the image
// filled like upstream.

///|
/// The size of a DC block for a MCU.
const DCT_BLOCK : Int = 64

///|
priv enum McuContinuation {
  Ok
  AnotherSos
  /// Found an inter-scan marker (DHT/DQT/DRI/COM/APP) that needs handling.
  /// The caller should parse it and scan for the next SOS.
  InterScanMarker(Marker)
  Terminate
}

///|
/// Check for existence of DC and AC Huffman tables.
fn JpegDecoder::check_tables(self : JpegDecoder) -> Unit raise DecodeErrors {
  // check that dc and AC tables exist outside the hot path
  for component in self.components {
    let id = component.component_id.debug()
    if component.dc_huff_table >= MAX_COMPONENTS {
      raise HuffmanDecode("No Huffman DC table for component \{id} ")
    }
    if self.dc_huffman_tables[component.dc_huff_table] is None {
      raise HuffmanDecode("No DC table for component \{id}")
    }
    if component.ac_huff_table >= MAX_COMPONENTS {
      raise HuffmanDecode("No Huffman AC table for component \{id} ")
    }
    if self.ac_huffman_tables[component.ac_huff_table] is None {
      raise HuffmanDecode("No AC table for component \{id}")
    }
  }
}

///|
/// Fill `pixels[from..]` with 128.
fn fill_128(pixels : FixedArray[Byte], from : Int) -> Unit {
  for i in from..<pixels.length() {
    pixels[i] = b'\x80'
  }
}

///|
/// Decode MCUs and carry out post processing.
fn JpegDecoder::decode_mcu_ycbcr_baseline(
  self : JpegDecoder,
  pixels : FixedArray[Byte],
) -> Unit raise DecodeErrors {
  setup_component_params(self)
  // check dc and AC tables
  self.check_tables()
  let mut mcu_width = 0
  let mut mcu_height = 0
  if self.is_interleaved {
    // set upsampling functions
    self.set_upsampling()
    mcu_width = self.mcu_x
    mcu_height = self.mcu_y
  } else {
    // For non-interleaved images( (1*1) subsampling)
    // number of MCU's are the widths (+7 to account for paddings) divided by 8.
    mcu_width = (self.width + 7) / 8
    mcu_height = (self.height + 7) / 8
  }
  if self.is_interleaved &&
    self.input_colorspace.num_components() > 1 &&
    self.out_colorspace.num_components() == 1 &&
    (self.sample_ratio == V || self.sample_ratio == HV) {
    // when converting from YcbCr to grayscale, we need to take into account
    // mcu height since the MCU decoding needs to take it into account for
    // padding purposes and the post processor parses two rows per mcu width.
    mcu_height *= self.v_max
    mcu_height /= self.h_max
    self.coeff = 2
  }
  if self.input_colorspace == Luma && self.is_interleaved {
    // Grayscale image with down-sampled component, resetting component
    // details
    self.reset_params()
    // (`u16` arithmetic upstream)
    mcu_width = ((self.width + 7) & 0xFFFF) / 8
    mcu_height = ((self.height + 7) & 0xFFFF) / 8
  }
  let width = self.width
  let padded_width = calculate_padded_width(width, self.sample_ratio)
  let stream = BitStream::new()
  let tmp = FixedArray::make(DCT_BLOCK, 0)
  let comp_len = self.components.length()
  for pos, comp in self.components {
    // Allocate only needed components.
    //
    // For special colorspaces i.e YCCK and CMYK, just allocate all of the
    // needed components.
    if @cmp.minimum(self.out_colorspace.num_components() - 1, pos) == pos ||
      comp_len == 4 {
      // allocate enough space to hold a whole MCU width
      let len = comp.width_stride * comp.vertical_sample * 8
      comp.needed = true
      comp.raw_coeff = FixedArray::make(len, 0)
    } else {
      comp.needed = false
    }
  }

  // If all components are contained in the first scan of MCUs, then we can
  // process into (upsampled) pixels immediately after each MCU, for
  // convenience we use each row of MCUS. Otherwise, we must first wait until
  // following SOS provide the remaining components.
  let all_components_in_first_scan = self.num_scans == self.components.length()
  let progressive_mcus : FixedArray[FixedArray[Int]] = FixedArray::make(4, [])
  if !all_components_in_first_scan {
    for k, component in self.components {
      if k >= 4 {
        break
      }
      let len = mcu_width *
        component.vertical_sample *
        component.horizontal_sample *
        mcu_height *
        64
      progressive_mcus[k] = FixedArray::make(len, 0)
    }
  }
  let pixels_written = Ref(0)
  let is_hv = if self.is_interleaved { 1 } else { 0 }
  let mut max_stride = 0
  for c in self.components {
    max_stride = @cmp.maximum(max_stride, c.width_stride)
  }
  let upsampler_scratch_space = FixedArray::make(is_hv * max_stride * 8, 0)
  let mut restart = true
  while restart {
    restart = false
    for i in 0..<mcu_height {
      if stream.overread_by > 0 {
        fill_128(pixels, pixels_written.val)
        // Premature end of buffer
        break
      }
      // decode a whole MCU width,
      // this takes into account interleaved components.
      let terminate = self.decode_mcu_width(
        !all_components_in_first_scan,
        mcu_width,
        i,
        tmp,
        stream,
        progressive_mcus,
      )
      // process that width up until it's impossible.
      if all_components_in_first_scan {
        self.post_process(
          pixels, i, mcu_height, width, padded_width, pixels_written, upsampler_scratch_space,
        )
      }
      match terminate {
        Ok => ()
        AnotherSos =>
          if all_components_in_first_scan {
            // More than one SOS despite already having all components
            return
          } else {
            restart = true
            break
          }
        InterScanMarker(marker) =>
          // Handle inter-scan markers (DHT/DQT/etc) uniformly here.
          if self.advance_to_next_sos(marker, stream) {
            restart = true
            break
          } else {
            // Hit EOI
            break
          }
        Terminate => {
          // Got terminate signal, will not process further
          fill_128(pixels, pixels_written.val)
          return
        }
      }
    }
  }
  if !all_components_in_first_scan {
    self.finish_baseline_decoding(progressive_mcus, mcu_width, pixels)
  }
  // Ensure we read EOI
  if !stream.seen_eoi {
    let _ = get_marker(self.stream, stream) catch { _ => EOI }
  }
}

///|
/// Process all MCUs when baseline decoding has been processing them
/// component-after-component.
fn JpegDecoder::finish_baseline_decoding(
  self : JpegDecoder,
  block : FixedArray[FixedArray[Int]],
  _mcu_width : Int,
  pixels : FixedArray[Byte],
) -> Unit raise DecodeErrors {
  let mcu_height = self.mcu_y
  // Size of our output image(width*height)
  let is_hv = if self.is_interleaved { 1 } else { 0 }
  let upsampler_scratch_space = FixedArray::make(
    is_hv * self.components[0].width_stride,
    0,
  )
  let width = self.width
  let padded_width = calculate_padded_width(width, self.sample_ratio)
  for pos, comp in self.components {
    // Mark only needed components for computing output colors.
    comp.needed = @cmp.minimum(self.out_colorspace.num_components() - 1, pos) ==
      pos ||
      self.input_colorspace == YCCK ||
      self.input_colorspace == CMYK
  }
  let pixels_written = Ref(0)
  // dequantize and idct have been performed, only color convert.
  for i in 0..<mcu_height {
    for position, component in self.components {
      if !component.needed {
        continue
      }
      let b = block[position]
      let step = b.length() / mcu_height
      // where we will be reading our pixels from.
      copy_ints(component.raw_coeff, 0, b, i * step, step)
    }
    // process that whole stripe of MCUs
    self.post_process(
      pixels, i, mcu_height, width, padded_width, pixels_written, upsampler_scratch_space,
    )
  }
}

///|
/// Decode a whole MCU width (upstream `decode_mcu_width` and
/// `inner_decode_mcu_width`; `progressive_buf` is upstream's `PROGRESSIVE`).
fn JpegDecoder::decode_mcu_width(
  self : JpegDecoder,
  progressive_buf : Bool,
  mcu_width : Int,
  mcu_height : Int,
  tmp : FixedArray[Int],
  stream : BitStream,
  progressive : FixedArray[FixedArray[Int]],
) -> McuContinuation raise DecodeErrors {
  let sampled = self.scan_subsampled
  let num_scans = self.num_scans
  // How much of the head of `tmp` was written by the last MCU decoding?
  let mut clobber_more_than_4x4 = true
  // For non-interleaved scans (PROGRESSIVE=true), each scan contains a single
  // component and we iterate over that component's actual data unit count.
  let mut scan_du_width = if progressive_buf {
    let k = self.z_order[0]
    let comp = self.components[k]
    (self.width * comp.horizontal_sample + self.h_max * 8 - 1) /
    (self.h_max * 8)
  } else {
    mcu_width
  }
  // In malformed scans that list multiple components, clamp to the smallest
  // row capacity to avoid writing past the row buffer.
  if progressive_buf && num_scans > 1 {
    let mut min_du = 0
    for s in 0..<num_scans {
      let d = self.components[self.z_order[s]].width_stride / 8
      min_du = if s == 0 { d } else { @cmp.minimum(min_du, d) }
    }
    scan_du_width = @cmp.minimum(scan_du_width, min_du)
  }
  for j in 0..<scan_du_width {
    // iterate over components
    for s in 0..<num_scans {
      let k = self.z_order[s]
      let component = self.components[k]
      guard self.dc_huffman_tables[component.dc_huff_table % MAX_COMPONENTS]
        is Some(dc_table) else {
        raise FormatStatic("DC table not found")
      }
      guard self.ac_huffman_tables[component.ac_huff_table % MAX_COMPONENTS]
        is Some(ac_table) else {
        raise FormatStatic("AC table not found")
      }
      let qt_table = component.quantization_table
      let (channel, channel_off) = if progressive_buf {
        let offset = mcu_height *
          component.width_stride *
          8 *
          component.vertical_sample
        // Small stopgap for https://github.com/etemesi254/zune-image/issues/362
        if offset >= progressive[k].length() {
          raise FormatStatic("Would panic on slice iteration")
        }
        (progressive[k], offset)
      } else {
        (component.raw_coeff, 0)
      }
      let component_samples_needed = component.needed
      let v_step = if sampled && !progressive_buf {
        component.vertical_sample
      } else {
        1
      }
      for v_samp in 0..<v_step {
        let h_step = if sampled && !progressive_buf {
          component.horizontal_sample
        } else {
          1
        }
        for h_samp in 0..<h_step {
          let result = if component_samples_needed {
            // Fill the array with zeroes, decode_mcu_block expects a zero
            // based array.
            let clobber_len = if !clobber_more_than_4x4 { 32 } else { 64 }
            for z in 0..<clobber_len {
              tmp[z] = 0
            }
            stream.decode_mcu_block(
              self.stream,
              dc_table,
              ac_table,
              qt_table,
              tmp,
              component,
            ) catch {
              _ => -1
            }
          } else {
            // We do not touch tmp so there is no need to reset it.
            stream.discard_mcu_block(self.stream, dc_table, ac_table) catch {
              _ => -1
            }
          }
          // If an error occurs we can either propagate it as an error or
          // print it and call terminate (non-strict mode).
          if result < 0 {
            return Terminate
          }
          let len = result
          if component_samples_needed {
            // tmp was only written partially, note that len is in ZigZag
            // order.
            clobber_more_than_4x4 = len > 10
            let idct_position = if progressive_buf {
              // For non-interleaved, j indexes data units directly
              j * 8
            } else {
              // derived from stb and rewritten for my tastes
              let c2 = v_samp * 8
              let c3 = (j * component.horizontal_sample + h_samp) * 8
              component.width_stride * c2 + c3
            }
            let pos = channel_off + idct_position
            if pos > channel.length() {
              raise Panic("slice index out of range")
            }
            if len <= 1 {
              idct_int_1x1(tmp, channel, pos, component.width_stride)
            } else if len <= 10 {
              idct4x4(tmp, channel, pos, component.width_stride)
            } else {
              //  call idct.
              idct_int(tmp, channel, pos, component.width_stride)
            }
          }
        }
      }
    }
    self.todo = self.todo - 1
    if self.todo == 0 {
      self.handle_rst_main(stream)
      continue
    }
    if stream.marker is Some(_) && stream.bits_left == 0 {
      break
    }
  }
  self.check_stream_marker_after_mcu_width(stream)
}

///|
fn JpegDecoder::check_stream_marker_after_mcu_width(
  self : JpegDecoder,
  stream : BitStream,
) -> McuContinuation raise DecodeErrors {
  // After all interleaved components, that's an MCU handle stream markers.
  //
  // In some corrupt images, it may occur that header markers occur in the
  // stream; libjpeg-turbo allows it, so we also allow it.
  if stream.marker is Some(m) {
    if m == EOI {
      // acknowledge and ignore EOI marker.
      stream.marker = None
      stream.seen_eoi = true
    } else if m is RST(_) {
      if self.todo == 0 {
        self.handle_rst(stream)
      }
    } else if m == SOS {
      self.parse_marker_inner(m)
      stream.marker = None
      stream.reset()
      return AnotherSos
    } else if m is (DHT | DQT | DRI | COM | APP(_)) {
      // For non-interleaved images, setup markers can appear between scans.
      stream.marker = None
      return InterScanMarker(m)
    } else {
      // Marker found within Huffman Stream, possibly corrupt jpeg
      self.parse_marker_inner(m)
      stream.marker = None
      stream.reset()
      return Terminate
    }
  }
  Ok
}

///|
/// Scan for the next SOS marker, parsing setup markers along the way.
///
/// Returns `true` if a SOS was found and `false` at EOI.
fn JpegDecoder::advance_to_next_sos(
  self : JpegDecoder,
  first_marker : Marker,
  stream : BitStream,
) -> Bool raise DecodeErrors {
  // Limit iterations to prevent DoS from malicious files.
  let max_inter_scan_markers = 64
  // Parse the first marker that triggered this call
  self.parse_marker_inner(first_marker)
  stream.reset()
  for _ in 0..<max_inter_scan_markers {
    let marker = get_marker(self.stream, stream)
    match marker {
      SOS => {
        self.parse_marker_inner(SOS)
        stream.reset()
        return true
      }
      EOI => {
        stream.seen_eoi = true
        return false
      }
      DHT | DQT | DRI | COM => self.parse_marker_inner(marker)
      APP(_) => self.parse_marker_inner(marker)
      _ => {
        // Non-strict: skip unknown marker
        let length = self.stream.get_u16_be_err()
        if length >= 2 {
          self.stream.skip(length - 2)
        }
      }
    }
  }
  raise FormatStatic("Too many markers between scans (exceeded limit of 64)")
}

///|
/// Handle RST markers. No-op if not using restarts.
fn JpegDecoder::handle_rst(self : JpegDecoder, stream : BitStream) -> Unit {
  self.todo = self.restart_interval
  if stream.marker is Some(marker) {
    // Found a marker
    match marker {
      RST(_) => {
        // reset stream
        stream.reset()
        // Initialize dc predictions to zero for all components
        for c in self.components {
          c.dc_pred = 0
        }
      }
      // (EOI and the markers that can appear between scans are left for the
      // caller; other markers only warn in non-strict mode)
      _ => ()
    }
  }
}

///|
/// Post process a row of MCUs: up-sample and color convert into `pixels`.
fn JpegDecoder::post_process(
  self : JpegDecoder,
  pixels : FixedArray[Byte],
  i : Int,
  mcu_height : Int,
  width : Int,
  padded_width : Int,
  pixels_written : Ref[Int],
  upsampler_scratch_space : FixedArray[Int],
) -> Unit raise DecodeErrors {
  let out_colorspace_components = self.out_colorspace.num_components()
  let mut px = pixels_written.val
  // indicates whether image is vertically up-sampled
  let is_vertically_sampled = self.components
    .iter()
    .any(c => c.sample_ratio is (HV | V))
  let mut comp_len = self.components.length()
  // If we are moving from YCbCr -> Luma, we do not allocate storage for other
  // components.
  if out_colorspace_components < comp_len && self.out_colorspace == Luma {
    comp_len = out_colorspace_components
  }
  let empty : Slice = { arr: [], off: 0, len: 0, }
  let color_conv_function = (num_iters : Int, samples : FixedArray[Slice]) => {
    let row_len = width * out_colorspace_components
    let avail = if row_len == 0 { 0 } else { (pixels.length() - px) / row_len }
    let n = @cmp.minimum(avail, num_iters)
    for pos in 0..<n {
      let raw_samples = FixedArray::make(4, empty)
      // iterate over each line, since color-convert needs only one line
      for j in 0..<@cmp.minimum(comp_len, 4) {
        let s = samples[j]
        if (pos + 1) * padded_width > s.len {
          raise FormatStatic("Missing samples")
        }
        raw_samples[j] = s.sub(pos * padded_width, (pos + 1) * padded_width)
      }
      color_convert(
        raw_samples,
        self.input_colorspace,
        self.out_colorspace,
        pixels,
        px,
        row_len,
        width,
        padded_width,
      )
      px += row_len
    }
  }
  if self.is_interleaved && self.out_colorspace != Luma {
    for comp in self.components {
      upsample(
        comp, mcu_height, i, upsampler_scratch_space, is_vertically_sampled,
      )
    }
    if is_vertically_sampled {
      if i > 0 {
        // write the last line, it wasn't up-sampled as we didn't have
        // row_down yet
        let samples = FixedArray::make(4, empty)
        for k, component in self.components {
          if k < 4 {
            samples[k] = Slice::of(component.first_row_upsample_dest)
          }
        }
        let num_iters = self.coeff * self.v_max
        color_conv_function(num_iters, samples)
      }
      // After up-sampling the last row, save any row that can be used for a
      // later up-sampling.
      for component in self.components {
        if component.sample_ratio != H {
          // copy last row to be used for the next color conversion
          let size = component.vertical_sample *
            component.width_stride *
            component.sample_ratio.sample()
          let raw = component.raw_coeff
          if size > raw.length() ||
            size != component.first_row_upsample_dest.length() {
            raise Panic("copy_from_slice: length mismatch")
          }
          copy_ints(
            component.first_row_upsample_dest,
            0,
            raw,
            raw.length() - size,
            size,
          )
        }
      }
    }
    let samples = FixedArray::make(4, empty)
    for k, component in self.components {
      if k < 4 {
        samples[k] = if component.sample_ratio == NoSample {
          Slice::of(component.raw_coeff)
        } else {
          Slice::of(component.upsample_dest)
        }
      }
    }
    // we either do 7 or 8 MCU's depending on the state, this only applies to
    // vertically sampled images
    let is_last_considered = is_vertically_sampled &&
      i != @cmp.maximum(mcu_height - 1, 0)
    let num_iters = (8 - (if is_last_considered { 1 } else { 0 })) *
      self.coeff *
      self.v_max
    color_conv_function(num_iters, samples)
  } else {
    let channels_ref = FixedArray::make(MAX_COMPONENTS, empty)
    for pos, x in self.components {
      channels_ref[pos] = Slice::of(x.raw_coeff)
    }
    if self.sample_ratio is Generic(_, v) {
      color_conv_function(8 * v * self.coeff, channels_ref)
    } else {
      color_conv_function(8 * self.coeff, channels_ref)
    }
  }
  pixels_written.val = px
}
