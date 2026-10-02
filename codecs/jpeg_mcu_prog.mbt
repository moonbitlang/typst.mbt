// Port of `zune-jpeg` (v0.5.15) `src/mcu_prog.rs`: progressive decoding.

///|
/// Decode a progressive image.
///
/// This routine decodes a progressive image, stopping if it finds any error.
fn JpegDecoder::decode_mcu_ycbcr_progressive(
  self : JpegDecoder,
  pixels : FixedArray[Byte],
) -> Unit raise DecodeErrors {
  setup_component_params(self)
  // memory location for decoded pixels for components
  let block : FixedArray[FixedArray[Int]] = FixedArray::make(MAX_COMPONENTS, [])
  let mut seen_scans = 1
  if self.input_colorspace == Luma && self.is_interleaved {
    // Grayscale image with down-sampled component, resetting component
    // details
    self.reset_params()
  }
  if self.is_interleaved {
    // this helps us catch component errors.
    self.set_upsampling()
  }
  let mut mcu_width = 0
  let mut mcu_height = 0
  if self.is_interleaved {
    mcu_width = self.mcu_x
    mcu_height = self.mcu_y
  } else {
    mcu_width = (self.width + 7) / 8
    mcu_height = (self.height + 7) / 8
  }
  if self.is_interleaved &&
    self.input_colorspace.num_components() > 1 &&
    self.out_colorspace.num_components() == 1 &&
    (self.sample_ratio == V || self.sample_ratio == HV) {
    // set coeff to be 2 to ensure that we increment two rows for every mcu
    // processed also
    mcu_height *= self.v_max
    mcu_height /= self.h_max
    self.coeff = 2
  }
  mcu_width *= 64
  for i in 0..<self.input_colorspace.num_components() {
    let comp = self.components[i]
    let len = mcu_width *
      comp.vertical_sample *
      comp.horizontal_sample *
      mcu_height
    block[i] = FixedArray::make(len, 0)
  }
  let stream = BitStream::new_progressive(
    self.succ_low,
    self.spec_start,
    self.spec_end,
  )
  // there are multiple scans in the stream, this should resolve the first
  // scan
  self.parse_entropy_coded_data(stream, block) catch {
    // (non-strict) Go process it and return as much as we can, exiting here
    _ => return self.finish_progressive_decoding(block, pixels)
  }
  // extract marker
  guard stream.marker is Some(m) else {
    raise FormatStatic("Marker missing where expected")
  }
  stream.marker = None
  let mut marker = m
  // if marker is EOI, we are done, otherwise continue scanning.
  while marker != EOI {
    match marker {
      SOS => {
        parse_sos(self)
        stream.update_progressive_params(
          self.succ_high,
          self.succ_low,
          self.spec_start,
          self.spec_end,
        )
        // after every SOS, marker, parse data for that scan.
        // Do not error out too fast, allows the decoder to continue as much
        // as possible even after errors
        self.parse_entropy_coded_data(stream, block) catch {
          _ => break
        }
        // extract marker, might either indicate end of image or we continue
        // scanning(hence the continue statement to determine).
        marker = get_marker(self.stream, stream) catch { _ => break }
        seen_scans += 1
        if seen_scans > MAX_SCANS {
          raise Format("Too many scans, exceeded limit of \{MAX_SCANS}")
        }
        stream.reset()
        continue
      }
      RST(_) => self.handle_rst(stream)
      _ => self.parse_marker_inner(marker)
    }
    // If we can't get the marker, just break away
    marker = get_marker(self.stream, stream) catch { _ => break }
  }
  self.finish_progressive_decoding(block, pixels)
}

///|
/// Reset progressive parameters.
fn JpegDecoder::reset_prog_params(
  self : JpegDecoder,
  stream : BitStream,
) -> Unit {
  stream.reset()
  for c in self.components {
    c.dc_pred = 0
  }
  // Also reset JPEG restart intervals (`usize::MAX` is -1 here)
  self.todo = if self.restart_interval != 0 {
    self.restart_interval
  } else {
    -1
  }
}

///|
fn JpegDecoder::parse_entropy_coded_data(
  self : JpegDecoder,
  stream : BitStream,
  buffer : FixedArray[FixedArray[Int]],
) -> Unit raise DecodeErrors {
  self.reset_prog_params(stream)
  if self.num_scans > self.input_colorspace.num_components() {
    raise Format(
      "Number of scans \{self.num_scans} cannot be greater than number of components, \{self.input_colorspace.num_components()}",
    )
  }
  if self.num_scans == 1 {
    // Safety checks
    if self.spec_end != 0 && self.spec_start == 0 {
      raise FormatStatic("Can't merge DC and AC corrupt jpeg")
    }
    // non interleaved data, process one block at a time in trivial scanline
    // order
    let k = self.z_order[0]
    if k >= self.components.length() {
      raise Format("Cannot find component \{k}, corrupt image")
    }
    // For non-interleaved scans, iterate over the component's actual
    // data-unit grid.
    let component = self.components[k]
    let mcu_width = div_ceil(
      self.width * component.horizontal_sample,
      self.h_max * 8,
    )
    let mcu_height = div_ceil(
      self.height * component.vertical_sample,
      self.v_max * 8,
    )
    for i in 0..<mcu_height {
      for j in 0..<mcu_width {
        if self.spec_start != 0 && self.succ_high == 0 && stream.eob_run > 0 {
          // handle EOB runs here.
          stream.eob_run -= 1
        } else {
          let start = 64 * (j + i * (self.components[k].width_stride / 8))
          let data = buffer[k]
          if start + 64 > data.length() {
            raise FormatStatic("Slice to Small")
          }
          if self.spec_start == 0 {
            let pos = self.components[k].dc_huff_table & (MAX_COMPONENTS - 1)
            guard self.dc_huffman_tables[pos] is Some(dc_table) else {
              raise FormatStatic("Huffman table at index  {} not initialized")
            }
            if self.succ_high == 0 {
              // first scan for this mcu
              stream.decode_prog_dc_first(
                self.stream,
                dc_table,
                data,
                start,
                self.components[k],
              )
            } else {
              // refining scans for this MCU
              stream.decode_prog_dc_refine(self.stream, data, start)
            }
          } else {
            let pos = self.components[k].ac_huff_table
            if pos >= MAX_COMPONENTS {
              raise Format("No huffman table for component:\{pos}")
            }
            guard self.ac_huffman_tables[pos] is Some(ac_table) else {
              raise Format("Huffman table at index  \{pos} not initialized")
            }
            if self.succ_high == 0 {
              stream.decode_mcu_ac_first(self.stream, ac_table, data, start)
            } else {
              // refinement scan
              stream.decode_mcu_ac_refine(self.stream, ac_table, data, start)
            }
          }
        }
        self.todo -= 1
        self.handle_rst_main(stream)
      }
    }
  } else {
    if self.spec_end != 0 {
      raise HuffmanDecode("Can't merge dc and AC corrupt jpeg")
    }
    // process scan n elements in order
    for k in 0..<self.num_scans {
      let n = self.z_order[k]
      if n >= self.components.length() {
        raise Format("Cannot find component \{n}, corrupt image")
      }
      let component = self.components[n]
      if component.dc_huff_table >= MAX_COMPONENTS {
        raise Format(
          "No huffman table for component:\{component.dc_huff_table}",
        )
      }
      if self.dc_huffman_tables[component.dc_huff_table] is None {
        raise Format(
          "Huffman table at index  \{component.dc_huff_table} not initialized",
        )
      }
    }
    // Interleaved scan
    for i in 0..<self.mcu_y {
      for j in 0..<self.mcu_x {
        // process scan n elements in order
        for k in 0..<self.num_scans {
          let n = self.z_order[k]
          let component = self.components[n]
          guard self.dc_huffman_tables[component.dc_huff_table]
            is Some(huff_table) else {
            raise FormatStatic("Huffman table at index not initialized")
          }
          for v_samp in 0..<component.vertical_sample {
            for h_samp in 0..<component.horizontal_sample {
              let x2 = j * component.horizontal_sample + h_samp
              let y2 = i * component.vertical_sample + v_samp
              let position = 64 * (x2 + y2 * component.width_stride / 8)
              let buf_n = buffer[n]
              if position >= buf_n.length() {
                raise FormatStatic("Invalid image")
              }
              if self.succ_high == 0 {
                stream.decode_prog_dc_first(
                  self.stream,
                  huff_table,
                  buf_n,
                  position,
                  component,
                )
              } else {
                stream.decode_prog_dc_refine(self.stream, buf_n, position)
              }
            }
          }
        }
        // We want wrapping subtraction here because it means we get a
        // higher number in the case this underflows
        self.todo -= 1
        // after every scan that's a mcu, count down restart markers.
        self.handle_rst_main(stream)
      }
    }
  }
}

///|
fn JpegDecoder::handle_rst_main(
  self : JpegDecoder,
  stream : BitStream,
) -> Unit raise DecodeErrors {
  if self.todo == 0 {
    let _ = stream.refill(self.stream)
  }
  if self.todo == 0 &&
    self.restart_interval != 0 &&
    stream.marker is None &&
    !stream.seen_eoi {
    // if no marker and we are to reset RST, look for the marker, this
    // matches libjpeg-turbo behaviour
    // In some images, the RST marker on the last section may not be
    // available as it is maybe stopped by an EOI marker
    stream.marker = Some(get_marker(self.stream, stream)) catch {
      _ => stream.marker
    }
  }
  if self.todo == 0 {
    self.handle_rst(stream)
  }
}

///|
fn JpegDecoder::finish_progressive_decoding(
  self : JpegDecoder,
  block : FixedArray[FixedArray[Int]],
  pixels : FixedArray[Byte],
) -> Unit raise DecodeErrors {
  let mcu_height = if self.is_interleaved {
    self.mcu_y
  } else {
    // For non-interleaved images( (1*1) subsampling)
    // number of MCU's are the widths (+7 to account for paddings) divided
    // by 8.
    div_ceil(self.height, 8)
  }
  // Size of our output image(width*height)
  let is_hv = if self.is_interleaved { 1 } else { 0 }
  let upsampler_scratch_space = FixedArray::make(
    is_hv * self.components[0].width_stride,
    0,
  )
  let width = self.width
  let padded_width = calculate_padded_width(width, self.sample_ratio)
  let tmp = FixedArray::make(DCT_BLOCK, 0)
  for pos, comp in self.components {
    // Allocate only needed components.
    if @cmp.minimum(self.out_colorspace.num_components() - 1, pos) == pos ||
      self.input_colorspace == YCCK ||
      self.input_colorspace == CMYK {
      // allocate enough space to hold a whole MCU width
      let len = comp.width_stride * comp.vertical_sample * 8
      comp.needed = true
      comp.raw_coeff = FixedArray::make(len, 0)
    } else {
      comp.needed = false
    }
  }
  let pixels_written = Ref(0)
  // dequantize, idct and color convert.
  for i in 0..<mcu_height {
    for position, component in self.components {
      if !component.needed {
        continue
      }
      let qt_table = component.quantization_table
      // step is the number of pixels this iteration wil be handling
      let b = block[position]
      let step = b.length() / mcu_height
      // where we will be reading our pixels from.
      let start = i * step
      if start + step > b.length() {
        raise Panic("slice index out of range")
      }
      // iterate per effective pixels.
      let mcu_x = component.width_stride / 8
      // iterate per every vertical sample.
      for k in 0..<component.vertical_sample {
        for j in 0..<mcu_x {
          // after writing a single stride, we need to skip 8 rows.
          let width_stride = k * 8 * component.width_stride
          let start2 = j * 64 + width_stride
          if start2 + 64 > step {
            raise FormatStatic("Invalid slice , would panic, invalid image")
          }
          // dequantize
          for z in 0..<64 {
            tmp[z] = b[start + start2 + z] * qt_table[z]
          }
          // determine where to write.
          let sl = component.idct_pos
          if sl > component.raw_coeff.length() {
            raise Panic("slice index out of range")
          }
          component.idct_pos += 8
          // tmp now contains a dequantized block so idct it
          idct_int(tmp, component.raw_coeff, sl, component.width_stride)
        }
        // after every write of 8, skip 7 since idct write stride wise 8
        // times.
        component.idct_pos += 7 * component.width_stride
      }
      component.idct_pos = 0
    }
    // process that width up until it's impossible
    self.post_process(
      pixels, i, mcu_height, width, padded_width, pixels_written, upsampler_scratch_space,
    )
  }
}

///|
fn JpegDecoder::reset_params(self : JpegDecoder) -> Unit {
  // Apparently, grayscale images which can be down sampled exists; reset
  // the image info to appear as if it were a non-sampled image.
  self.h_max = 1
  self.v_max = 1
  self.sample_ratio = NoSample
  self.is_interleaved = false
  self.components[0].vertical_sample = 1
  self.components[0].width_stride = (self.width + 7) / 8 * 8
  self.components[0].horizontal_sample = 1
}

///|
/// Get a marker from the bit-stream.
///
/// This reads until it gets a marker or end of file is encountered.
fn get_marker(
  reader : ZReader,
  stream : BitStream,
) -> Marker raise DecodeErrors {
  if stream.marker is Some(marker) {
    stream.marker = None
    return marker
  }
  // read until we get a marker
  while !reader.eof() {
    let marker = reader.read_u8_err()
    if marker == 255 {
      let mut r = reader.read_u8_err()
      // 0xFF 0XFF(some images may be like that)
      while r == 0xFF {
        r = reader.read_u8_err()
      }
      if r != 0 {
        return Marker::from_u8(r)
      }
    }
  }
  raise ExhaustedData
}
