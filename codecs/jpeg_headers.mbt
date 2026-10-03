// Port of `zune-jpeg` (v0.5.15) `src/headers.rs`: decoding of the JPEG
// marker segments.

///|
/// **B.2.4.2 Huffman table-specification syntax**
fn parse_huffman(decoder : JpegDecoder) -> Unit raise DecodeErrors {
  // Read the length of the Huffman table
  let len = decoder.stream.get_u16_be_err()
  if len < 2 {
    raise FormatStatic("Invalid Huffman length in image")
  }
  let mut dht_length = len - 2
  while dht_length > 16 {
    // HT information
    let ht_info = decoder.stream.read_u8_err()
    // third bit indicates whether the huffman encoding is DC or AC type
    let dc_or_ac = (ht_info >> 4) & 0xF
    // Indicate the position of this table, should be less than 4;
    let index = ht_info & 0xF
    // read the number of symbols
    let num_symbols = FixedArray::make(17, 0)
    if index >= MAX_COMPONENTS {
      raise HuffmanDecode(
        "Invalid DHT index \{index}, expected between 0 and 3",
      )
    }
    if dc_or_ac > 1 {
      raise HuffmanDecode("Invalid DHT position \{dc_or_ac}, should be 0 or 1")
    }
    let counts = decoder.stream.read_exact_bytes(16)
    for i in 0..<16 {
      num_symbols[i + 1] = counts[i].to_int()
    }
    dht_length -= 1 + 16
    let mut symbols_sum = 0
    for v in num_symbols {
      symbols_sum += v
    }
    // The sum of the number of symbols cannot be greater than 256;
    if symbols_sum > 256 {
      raise FormatStatic(
        "Encountered Huffman table with excessive length in DHT",
      )
    }
    if symbols_sum > dht_length {
      raise HuffmanDecode(
        "Excessive Huffman table of length \{symbols_sum} found when header length is \{dht_length}",
      )
    }
    dht_length -= symbols_sum
    // A table containing symbols in increasing code length
    let symbols = FixedArray::make(256, 0)
    let read = decoder.stream.read_exact_bytes(symbols_sum)
    for i in 0..<symbols_sum {
      symbols[i] = read[i].to_int()
    }
    // store
    match dc_or_ac {
      0 =>
        decoder.dc_huffman_tables[index] = Some(
          HuffmanTable::new(num_symbols, symbols, true, decoder.is_progressive),
        )
      _ =>
        decoder.ac_huffman_tables[index] = Some(
          HuffmanTable::new(num_symbols, symbols, false, decoder.is_progressive),
        )
    }
  }
  if dht_length > 0 {
    raise FormatStatic("Bogus Huffman table definition")
  }
}

///|
/// **B.2.4.1 Quantization table-specification syntax**
fn parse_dqt(img : JpegDecoder) -> Unit raise DecodeErrors {
  // read length
  let len = img.stream.get_u16_be_err()
  if len < 2 {
    raise FormatStatic("Invalid DQT length. Length should be greater than 2")
  }
  let mut qt_length = len - 2
  // A single DQT header may have multiple QT's
  while qt_length > 0 {
    let qt_info = img.stream.read_u8_err()
    // 0 = 8 bit otherwise 16 bit dqt
    let precision = qt_info >> 4
    // last 4 bits give us position
    let table_position = qt_info & 0x0f
    let precision_value = 64 * (precision + 1)
    if ((precision_value + 1) & 0xFFFF) > qt_length {
      raise DqtError(
        "Invalid QT table bytes left :\{qt_length}. Too small to construct a valid qt table which should be \{precision_value + 1} long",
      )
    }
    let dct_table = match precision {
      0 => {
        let qt_values = img.stream.read_exact_bytes(64)
        qt_length -= precision_value + 1
        // carry out un zig-zag here
        un_zig_zag(i => qt_values[i].to_int())
      }
      1 => {
        // 16 bit quantization tables
        let qt_values = FixedArray::make(64, 0)
        for i in 0..<64 {
          qt_values[i] = img.stream.get_u16_be_err()
        }
        qt_length -= precision_value + 1
        un_zig_zag(i => qt_values[i])
      }
      _ =>
        raise DqtError(
          "Expected QT precision value of either 0 or 1, found \{precision}",
        )
    }
    if table_position >= MAX_COMPONENTS {
      raise DqtError(
        "Too large table position for QT :\{table_position}, expected between 0 and 3",
      )
    }
    img.qt_tables[table_position] = Some(dct_table)
  }
}

///|
/// Section:`B.2.2 Frame header syntax`
fn parse_start_of_frame(img : JpegDecoder) -> Unit raise DecodeErrors {
  if img.seen_sof {
    raise SofError("Two Start of Frame Markers")
  }
  // Get length of the frame header
  let length = img.stream.get_u16_be_err()
  // usually 8, but can be 12 and 16, we currently support only 8
  let dt_precision = img.stream.read_u8_err()
  if dt_precision != 8 {
    raise SofError(
      "The library can only parse 8-bit images, the image has \{dt_precision} bits of precision",
    )
  }
  // read and set the image height.
  let img_height = img.stream.get_u16_be_err()
  img.height = img_height
  // read and set the image width
  let img_width = img.stream.get_u16_be_err()
  img.width = img_width
  if img_width > img.max_width {
    raise Format(
      "Image width \{img_width} greater than width limit \{img.max_width}. If use `set_limits` if you want to support huge images",
    )
  }
  if img_height > img.max_height {
    raise Format(
      "Image height \{img_height} greater than height limit \{img.max_height}. If use `set_limits` if you want to support huge images",
    )
  }

  // Check image width or height is zero
  if img_width == 0 || img_height == 0 {
    raise ZeroError
  }
  // Number of components for the image.
  let num_components = img.stream.read_u8_err()
  if num_components == 0 {
    raise SofError("Number of components cannot be zero.")
  }
  let expected = 8 + 3 * num_components
  // length should be equal to num components
  if length != expected {
    raise SofError(
      "Length of start of frame differs from expected \{expected},value is \{length}",
    )
  }
  if num_components == 1 {
    // SOF sets the number of image components
    img.input_colorspace = Luma
  }
  if num_components == 4 && img.input_colorspace == YCbCr {
    // https://entropymine.wordpress.com/2018/10/22/how-is-a-jpeg-images-color-type-determined/
    img.input_colorspace = CMYK
  }
  // set number of components
  img.info_components = num_components
  let components = []
  for pos in 0..<num_components {
    // read 3 bytes for each component
    let temp = img.stream.read_exact_bytes(3)
    // create a component.
    components.push(Components::from(temp, pos))
  }
  img.seen_sof = true
  img.components = components
  let mut h_max = 1
  let mut v_max = 1
  for comp in img.components {
    h_max = @cmp.maximum(h_max, comp.horizontal_sample)
    v_max = @cmp.maximum(v_max, comp.vertical_sample)
  }
  img.sample_ratio = match (h_max, v_max) {
    (1, 1) => NoSample
    (1, 2) => V
    (2, 1) => H
    (2, 2) => HV
    (hs, vs) => Generic(hs, vs)
  }
}

///|
/// Parse a start of scan data.
fn parse_sos(image : JpegDecoder) -> Unit raise DecodeErrors {
  // Scan header length
  let ls = image.stream.get_u16_be_err()
  // Number of image components in scan
  let ns = image.stream.read_u8_err()
  let seen = FixedArray::make(MAX_COMPONENTS + 1, -1)
  image.num_scans = ns
  let smallest_size = 6 + 2 * ns
  if ls != smallest_size {
    raise SosError("Bad SOS length \{ls},corrupt jpeg")
  }
  // Check number of components.
  if !(ns >= 1 && ns < 5) {
    raise SosError(
      "Invalid number of components in start of scan \{ns}, expected in range 1..5",
    )
  }
  if image.info_components == 0 {
    raise FormatStatic(
      "Error decoding SOF Marker, Number of components cannot be zero.",
    )
  }
  // consume spec parameters
  image.scan_subsampled = false
  for i in 0..<ns {
    let id = image.stream.read_u8_err()
    if seen.contains(id) {
      raise SofError("Duplicate ID \{id} seen twice in the same component")
    }
    seen[i] = id
    // DC and AC huffman table position
    // top 4 bits contain dc huffman destination table
    // lower four bits contain ac huffman destination table
    let y = image.stream.read_u8_err()
    let mut j = 0
    while j < image.info_components {
      if image.components[j].id == id {
        break
      }
      j += 1
    }
    if j == image.info_components {
      let ids = image.components.map(c => c.id.to_string())
      raise SofError(
        "Invalid component id \{id}, expected one one of [\{ids.join(", ")}]",
      )
    }
    let component = image.components[j]
    component.dc_huff_table = (y >> 4) & 0xF
    component.ac_huff_table = y & 0xF
    image.z_order[i] = j
    if component.vertical_sample != 1 || component.horizontal_sample != 1 {
      image.scan_subsampled = true
    }
  }

  // Collect the component spec parameters
  // Start of spectral / predictor selection. (between 0 and 63)
  image.spec_start = image.stream.read_u8_err()
  // End of spectral selection
  image.spec_end = image.stream.read_u8_err()
  let bit_approx = image.stream.read_u8_err()
  // successive approximation bit position high
  image.succ_high = bit_approx >> 4
  if image.spec_end > 63 {
    raise SosError(
      "Invalid Se parameter \{image.spec_end}, range should be 0-63",
    )
  }
  if image.spec_start > 63 {
    raise SosError(
      "Invalid Ss parameter \{image.spec_start}, range should be 0-63",
    )
  }
  if image.succ_high > 13 {
    raise SosError(
      "Invalid Ah parameter \{image.succ_low}, range should be 0-13",
    )
  }
  // successive approximation bit position low
  image.succ_low = bit_approx & 0xF
  if image.succ_low > 13 {
    raise SosError(
      "Invalid Al parameter \{image.succ_low}, range should be 0-13",
    )
  }
  // skip any bytes not read (always zero)
  image.stream.skip(@cmp.maximum(smallest_size - ls, 0))
}

///|
/// Parse the APP13 (IPTC) segment.
fn parse_app13(decoder : JpegDecoder) -> Unit raise DecodeErrors {
  let iptc_prefix = b"Photoshop 3.0\x00"
  // skip length.
  let mut length = decoder.stream.get_u16_be()
  if length < 2 {
    raise FormatStatic("Too small APP13 length")
  }
  // length bytes.
  length -= 2
  if length > iptc_prefix.length() &&
    decoder.stream.peek_at(0, iptc_prefix.length()) == iptc_prefix {
    // skip bytes we read above.
    decoder.stream.skip(iptc_prefix.length())
    length -= iptc_prefix.length()
    let _ = decoder.stream.peek_at(0, length)
  }
  decoder.stream.skip(length)
}

///|
/// Parse Adobe App14 segment.
fn parse_app14(decoder : JpegDecoder) -> Unit raise DecodeErrors {
  // skip length
  let mut length = decoder.stream.get_u16_be()
  if length < 2 {
    raise FormatStatic("Too small APP14 length")
  }
  if decoder.stream.peek_at(0, 5) == b"Adobe" {
    if length < 14 {
      raise FormatStatic("Too short of a length for App14 segment")
    }
    // move stream 6 bytes to remove adobe id
    decoder.stream.skip(6)
    // skip version, flags0 and flags1
    decoder.stream.skip(5)
    // get color transform
    let transform = decoder.stream.read_u8()
    // https://exiftool.org/TagNames/JPEG.html#Adobe
    match transform {
      0 => decoder.input_colorspace = CMYK
      1 => decoder.input_colorspace = YCbCr
      2 => decoder.input_colorspace = YCCK
      _ => raise Format("Unknown Adobe colorspace \{transform}")
    }
    // length = 2, adobe id = 6, version = 5, transform = 1
    length = @cmp.maximum(length - 14, 0)
  } else {
    length = @cmp.maximum(length - 2, 0)
  }
  // skip any proceeding lengths.
  decoder.stream.skip(length)
}

///|
/// Parse the APP1 segment (EXIF and XMP).
fn parse_app1(decoder : JpegDecoder) -> Unit raise DecodeErrors {
  let xmp_namespace_prefix = b"http://ns.adobe.com/xap/1.0/\x00"
  let extended_xmp_namespace_prefix = b"http://ns.adobe.com/xmp/extension/\x00"
  let extended_xmp_guid_size = 32
  let extended_xmp_total_size_size = 4
  let extended_xmp_offset_size = 4
  let extended_xmp_header_size = extended_xmp_guid_size +
    extended_xmp_total_size_size +
    extended_xmp_offset_size
  // contains exif data
  let mut length = decoder.stream.get_u16_be()
  if length < 2 {
    raise FormatStatic("Too small app1 length")
  }
  // length bytes
  length -= 2
  if length > 6 && decoder.stream.peek_at(0, 6) == b"Exif\x00\x00" {
    // skip bytes we read above
    decoder.stream.skip(6)
    length -= 6
    let _ = decoder.stream.peek_at(0, length)
  } else if length > xmp_namespace_prefix.length() &&
    decoder.stream.peek_at(0, xmp_namespace_prefix.length()) ==
    xmp_namespace_prefix {
    decoder.stream.skip(xmp_namespace_prefix.length())
    length -= xmp_namespace_prefix.length()
    let _ = decoder.stream.peek_at(0, length)
  } else if length > extended_xmp_namespace_prefix.length() &&
    decoder.stream.peek_at(0, extended_xmp_namespace_prefix.length()) ==
    extended_xmp_namespace_prefix {
    decoder.stream.skip(extended_xmp_namespace_prefix.length())
    length -= extended_xmp_namespace_prefix.length()
    if length < extended_xmp_header_size {
      raise FormatStatic("Too small Extended XMP segment")
    }
    let header = decoder.stream.peek_at(0, extended_xmp_header_size)
    let guid = header[0:extended_xmp_guid_size].to_owned()
    let total_size = u32_be(header, extended_xmp_guid_size)
    let offset = u32_be(
      header,
      extended_xmp_guid_size + extended_xmp_total_size_size,
    )
    let data = decoder.stream.peek_at(
      extended_xmp_header_size,
      length - extended_xmp_header_size,
    )
    decoder.extended_xmp_segments.push({
      offset,
      total_size,
      guid,
      data_len: data.length(),
    })
  }
  decoder.stream.skip(length)
}

///|
/// Parse the APP2 segment (ICC profile, gain map metadata, MPF).
fn parse_app2(decoder : JpegDecoder) -> Unit raise DecodeErrors {
  let hdr_meta = b"urn:iso:std:iso:ts:21496:-1\x00"
  let mpf_data = b"MPF\x00"
  let mut length = decoder.stream.get_u16_be()
  if length < 2 {
    raise FormatStatic("Too small app2 segment")
  }
  // length bytes
  length -= 2
  if length > 14 && decoder.stream.peek_at(0, 12) == b"ICC_PROFILE\x00" {
    // skip 12 bytes which indicate ICC profile
    length -= 12
    decoder.stream.skip(12)
    let seq_no = decoder.stream.read_u8()
    let num_markers = decoder.stream.read_u8()
    // deduct the two bytes we read above
    length -= 2
    let data = decoder.stream.peek_at(0, length)
    decoder.icc_data.push({ seq_no, num_markers, data, })
  } else if length > hdr_meta.length() &&
    decoder.stream.peek_at(0, hdr_meta.length()) == hdr_meta {
    length = @cmp.maximum(length - hdr_meta.length(), 0)
    decoder.stream.skip(hdr_meta.length())
    if length == 4 {
      let _ = decoder.stream.get_u16_be()
      let _ = decoder.stream.get_u16_be()
      length -= 4
    } else if length > 4 {
      let data = decoder.stream.peek_at(0, length)
      length -= data.length()
      decoder.stream.skip(data.length())
    }
  } else if length > mpf_data.length() &&
    decoder.stream.peek_at(0, mpf_data.length()) == mpf_data {
    length = @cmp.maximum(length - mpf_data.length(), 0)
    decoder.stream.skip(mpf_data.length())
    let data = decoder.stream.peek_at(0, length)
    length -= data.length()
    decoder.stream.skip(data.length())
  }
  decoder.stream.skip(length)
}

///|
/// Un-zig-zag a quantization table.
fn un_zig_zag(a : (Int) -> Int) -> FixedArray[Int] {
  let output = FixedArray::make(64, 0)
  for i in 0..<64 {
    output[un_zigzag[i]] = a(i)
  }
  output
}
