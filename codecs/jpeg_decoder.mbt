// Port of `zune-jpeg` (v0.5.15) `src/decoder.rs`: the JPEG decoder instance,
// header decoding and the entry point of pixel decoding. Metadata that Typst
// does not observe (EXIF, XMP, IPTC, gain maps) is validated like upstream
// but not stored.

///|
/// Maximum components.
const MAX_COMPONENTS : Int = 4

///|
/// The image color spaces the decoder deals with (upstream
/// `zune_core::colorspace::ColorSpace`).
///
/// Only the color spaces the JPEG decoder produces or the `image` crate
/// requests are ported.
priv enum ColorSpace {
  RGB
  YCbCr
  Luma
  YCCK
  CMYK
  MultiBand(Int)
} derive(Eq)

///|
/// Number of color channels present for a certain colorspace.
fn ColorSpace::num_components(self : ColorSpace) -> Int {
  match self {
    RGB | YCbCr => 3
    YCCK | CMYK => 4
    Luma => 1
    MultiBand(n) => n
  }
}

///|
fn ColorSpace::debug(self : ColorSpace) -> String {
  match self {
    RGB => "RGB"
    YCbCr => "YCbCr"
    Luma => "Luma"
    YCCK => "YCCK"
    CMYK => "CMYK"
    MultiBand(n) => "MultiBand(\{n})"
  }
}

///|
/// An encapsulation of an ICC chunk.
priv struct ICCChunk {
  seq_no : Int
  num_markers : Int
  data : BytesView
}

///|
/// An extended XMP segment.
priv struct ExtendedXmpSegment {
  offset : UInt
  total_size : UInt
  guid : Bytes
  data_len : Int
}

///|
/// A JPEG decoder instance.
priv struct JpegDecoder {
  /// Image width (from the SOF).
  mut width : Int
  /// Image height (from the SOF).
  mut height : Int
  /// Number of components (from the SOF).
  mut info_components : Int
  /// Image sub-sampling ratio.
  mut sample_ratio : SampleRatios
  /// Quantization tables.
  qt_tables : FixedArray[FixedArray[Int]?]
  /// DC Huffman tables with a maximum of 4 tables for each component
  dc_huffman_tables : FixedArray[HuffmanTable?]
  /// AC Huffman tables with a maximum of 4 tables for each component
  ac_huffman_tables : FixedArray[HuffmanTable?]
  /// Image components
  mut components : Array[Components]
  /// maximum horizontal component of all channels in the image
  mut h_max : Int
  /// maximum vertical component of all channels in the image
  mut v_max : Int
  /// mcu's width (interleaved scans)
  mut mcu_width : Int
  /// MCU height (interleaved scans)
  mut mcu_height : Int
  /// Number of MCU's in the x plane
  mut mcu_x : Int
  /// Number of MCU's in the y plane
  mut mcu_y : Int
  /// Is the image interleaved?
  mut is_interleaved : Bool
  /// Image input colorspace
  mut input_colorspace : ColorSpace
  /// Is the image progressive?
  mut is_progressive : Bool
  /// Start of spectral scan
  mut spec_start : Int
  /// End of spectral scan
  mut spec_end : Int
  /// Successive approximation bit position high
  mut succ_high : Int
  /// Successive approximation bit position low
  mut succ_low : Int
  /// Number of components in the scan.
  mut num_scans : Int
  /// For a scan, check if any component has vertical/horizontal sampling.
  mut scan_subsampled : Bool
  z_order : FixedArray[Int]
  /// restart markers
  mut restart_interval : Int
  /// MCUs until the next restart marker (`usize`, wrapping).
  mut todo : Int
  /// The output colorspace (upstream `DecoderOptions::jpeg_get_out_colorspace`).
  out_colorspace : ColorSpace
  /// byte-stream
  stream : ZReader
  /// Indicate whether headers have been decoded
  mut headers_decoded : Bool
  mut seen_sof : Bool
  icc_data : Array[ICCChunk]
  mut is_mjpeg : Bool
  mut coeff : Int
  /// Extended XMP segments
  mut extended_xmp_segments : Array[ExtendedXmpSegment]
}

///|
/// Maximum progressive scans (upstream `DecoderOptions::jpeg_get_max_scans`
/// default).
const MAX_SCANS : Int = 100

///|
/// Create a new decoder (upstream `JpegDecoder::new_with_options` with the
/// options of the `image` crate: non-strict mode, no dimension limits).
fn JpegDecoder::new(
  data : BytesView,
  out_colorspace : ColorSpace,
) -> JpegDecoder {
  {
    width: 0,
    height: 0,
    info_components: 0,
    sample_ratio: NoSample,
    qt_tables: FixedArray::make(MAX_COMPONENTS, None),
    dc_huffman_tables: FixedArray::make(MAX_COMPONENTS, None),
    ac_huffman_tables: FixedArray::make(MAX_COMPONENTS, None),
    components: [],
    h_max: 1,
    v_max: 1,
    mcu_height: 0,
    mcu_width: 0,
    mcu_x: 0,
    mcu_y: 0,
    is_interleaved: false,
    is_progressive: false,
    spec_start: 0,
    spec_end: 0,
    succ_high: 0,
    succ_low: 0,
    num_scans: 0,
    scan_subsampled: false,
    input_colorspace: YCbCr,
    z_order: FixedArray::make(MAX_COMPONENTS, 0),
    restart_interval: 0,
    todo: 0x7fff_ffff,
    out_colorspace,
    stream: ZReader::new(data),
    headers_decoded: false,
    seen_sof: false,
    icc_data: [],
    is_mjpeg: false,
    coeff: 1,
    extended_xmp_segments: [],
  }
}

///|
/// Return the number of bytes required to hold a decoded image frame.
fn JpegDecoder::output_buffer_size(self : JpegDecoder) -> Int {
  self.width * self.height * self.out_colorspace.num_components()
}

///|
fn JpegDecoder::reassemble_extended_xmp(self : JpegDecoder) -> Unit {
  if self.extended_xmp_segments.is_empty() {
    return
  }
  // Sort by offset (stable)
  let segs = self.extended_xmp_segments.mapi((i, s) => (s, i))
  segs.sort_by((a, b) => {
    let c = a.0.offset.compare(b.0.offset)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  self.extended_xmp_segments = segs.map(s => s.0)
  let guid = self.extended_xmp_segments[0].guid
  let total_size = self.extended_xmp_segments[0].total_size
  // Check for consistency
  for segment in self.extended_xmp_segments {
    if segment.guid != guid || segment.total_size != total_size {
      self.extended_xmp_segments.clear()
      return
    }
  }
  let mut rolling_offset : UInt = 0
  let mut complete = true
  for segment in self.extended_xmp_segments {
    if segment.offset != rolling_offset {
      // Gap or overlap
      complete = false
      break
    }
    rolling_offset += segment.data_len.reinterpret_as_uint()
  }
  if complete && rolling_offset == total_size {
    self.extended_xmp_segments.clear()
  } else if rolling_offset > total_size {
    self.extended_xmp_segments.clear()
  }
  // Else: Incomplete, wait for more.
}

///|
/// Decode the headers (upstream `decode_headers_internal`).
fn JpegDecoder::decode_headers(self : JpegDecoder) -> Unit raise DecodeErrors {
  if self.headers_decoded {
    return
  }
  // First two bytes should be jpeg soi marker
  let magic_bytes = self.stream.get_u16_be_err()
  let mut last_byte = 0
  let mut bytes_before_marker = 0
  if magic_bytes != 0xffd8 {
    raise IllegalMagicBytes(magic_bytes)
  }
  while true {
    // read a byte
    let mut m = self.stream.read_u8_err()
    // AND OF COURSE some images will have fill bytes in their marker
    // bitstreams because why not.
    if (m == 0xFF || m == 0) && last_byte == 0xFF {
      // This handles the edge case where images have markers with fill
      // bytes(0xFF) or byte stuffing (0)
      while m == 0xFF || m == 0x0 {
        last_byte = m
        m = self.stream.read_u8_err()
      }
    }
    // Last byte should be 0xFF to confirm existence of a marker since markers
    // look like OxFF(some marker data)
    if last_byte == 0xFF {
      let n = Marker::from_u8(m)
      // (non-strict mode: extra bytes between headers are ignored)
      bytes_before_marker = 0
      self.parse_marker_inner(n)
      if !self.extended_xmp_segments.is_empty() {
        self.reassemble_extended_xmp()
      }
      // break after reading the start of scan.
      // what follows is the image data
      if n == SOS {
        self.headers_decoded = true
        // Check if image is RGB: the component ids are 'R', 'G' and 'B'.
        let mut is_rgb = self.components.length() == 3
        let chars = [b'R', b'G', b'B']
        for i, comp in self.components {
          if i < 3 {
            is_rgb = is_rgb && comp.id == chars[i].to_int()
          }
        }
        // Image is RGB, change colorspace
        if is_rgb {
          self.input_colorspace = RGB
        }
        return
      }
    }
    last_byte = m
    bytes_before_marker += 1
  }
  ignore(bytes_before_marker)
}

///|
fn JpegDecoder::parse_marker_inner(
  self : JpegDecoder,
  m : Marker,
) -> Unit raise DecodeErrors {
  match m {
    SOF(0) | SOF(1) | SOF(2) => {
      // choose marker
      if !(m == SOF(0) || m == SOF(1)) {
        self.is_progressive = true
      }
      // get components
      parse_start_of_frame(self)
    }
    // Start of Frame Segments not supported (unreachable: `from_u8` only
    // produces SOF(0..=2))
    SOF(_) => raise Format("Unsupported image format")
    //APP(0) segment
    APP(0) => {
      let mut length = self.stream.get_u16_be_err()
      if length < 2 {
        raise Format("Found a marker with invalid length:\{length}\n")
      }
      // skip for now
      if length > 5 {
        let buffer = self.stream.read_exact_bytes(5)
        if buffer == b"AVI1\x00" {
          self.is_mjpeg = true
        }
        length -= 5
      }
      self.stream.skip(@cmp.maximum(length - 2, 0))
    }
    APP(1) => parse_app1(self)
    APP(2) => parse_app2(self)
    // Quantization tables
    DQT => parse_dqt(self)
    // Huffman tables
    DHT => parse_huffman(self)
    // Start of Scan Data
    SOS => parse_sos(self)
    EOI => raise FormatStatic("Premature End of image")
    DAC | DNL =>
      raise Format(
        "Parsing of the following header `\{m.debug()}` is not supported,cannot continue",
      )
    DRI => {
      if self.stream.get_u16_be_err() != 4 {
        raise Format("Bad DRI length, Corrupt JPEG")
      }
      self.restart_interval = self.stream.get_u16_be_err()
      self.todo = self.restart_interval
    }
    APP(14) => parse_app14(self)
    APP(13) => parse_app13(self)
    _ => {
      let length = self.stream.get_u16_be_err()
      if length < 2 {
        raise Format("Found a marker with invalid length:\{length}\n")
      }
      self.stream.skip(length - 2)
    }
  }
}

///|
/// Get the embedded ICC profile if it exists and is correct.
fn JpegDecoder::icc_profile(self : JpegDecoder) -> Bytes? {
  if !self.headers_decoded {
    return None
  }
  let num_markers = self.icc_data.length()
  if num_markers == 0 || num_markers >= 255 {
    return None
  }
  let marker_present : FixedArray[ICCChunk?] = FixedArray::make(256, None)
  // check validity
  for chunk in self.icc_data {
    if chunk.num_markers != num_markers {
      // all the lengths must match
      return None
    }
    if chunk.seq_no == 0 {
      return None
    }
    if marker_present[chunk.seq_no] is Some(_) {
      // duplicate seq_no
      return None
    }
    marker_present[chunk.seq_no] = Some(chunk)
  }
  let data = Buffer()
  // assemble the data now
  for i in 1..<=num_markers {
    guard marker_present[i] is Some(ch) else { return None }
    data.write_bytesview(ch.data)
  }
  Some(data.to_bytes())
}

///|
/// Decode into a pre-allocated buffer.
fn JpegDecoder::decode_into(
  self : JpegDecoder,
  out : FixedArray[Byte],
) -> Unit raise DecodeErrors {
  self.decode_headers()
  let expected_size = self.output_buffer_size()
  if out.length() < expected_size {
    // too small of a size
    raise TooSmallOutput(expected_size, out.length())
  }
  if self.is_progressive {
    self.decode_mcu_ycbcr_progressive(out)
  } else {
    self.decode_mcu_ycbcr_baseline(out)
  }
}

///|
/// Set up-sampling routines in case an image is down sampled.
fn JpegDecoder::set_upsampling(self : JpegDecoder) -> Unit {
  // no sampling, return early
  if self.h_max == self.v_max && self.h_max == 1 {
    return
  }
  for comp in self.components {
    let hs = self.h_max / comp.horizontal_sample
    let vs = self.v_max / comp.vertical_sample
    let samp_factor = match (hs, vs) {
      (1, 1) => {
        comp.sample_ratio = NoSample
        UpSampler::NoOp
      }
      (2, 1) => {
        comp.sample_ratio = H
        Horizontal
      }
      (1, 2) => {
        comp.sample_ratio = V
        Vertical
      }
      (2, 2) => {
        comp.sample_ratio = HV
        HorizontalVertical
      }
      (hs, vs) => {
        comp.sample_ratio = Generic(hs, vs)
        Generic
      }
    }
    comp.setup_upsample_scanline()
    comp.up_sampler = samp_factor
  }
}
