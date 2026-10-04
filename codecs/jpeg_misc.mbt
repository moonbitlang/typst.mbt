// Port of `zune-jpeg` (v0.5.15) `src/misc.rs`.

///|
/// Undo run length encoding of coefficients by placing them in natural order.
///
/// This is an index from position-in-bitstream to position-in-row-major-order.
let un_zigzag : ReadOnlyArray[Int] = [
  0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
  41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15,
  23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62,
  63,
  // Prevent overflowing
   63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63,
]

///|
/// Set up component parameters.
///
/// This modifies the components in place setting up details needed by other
/// parts of the decoder.
fn setup_component_params(img : JpegDecoder) -> Unit raise DecodeErrors {
  // in case of adobe app14 being present, zero may indicate either CMYK if
  // components are 4 or RGB if components are 3.
  if img.components.length() == 3 && img.input_colorspace == CMYK {
    img.input_colorspace = RGB
  }
  for component in img.components {
    // compute interleaved image info
    // h_max contains the maximum horizontal component
    img.h_max = @cmp.maximum(img.h_max, component.horizontal_sample)
    // v_max contains the maximum vertical component
    img.v_max = @cmp.maximum(img.v_max, component.vertical_sample)
    img.mcu_width = img.h_max * 8
    img.mcu_height = img.v_max * 8
    // Number of MCU's per width
    img.mcu_x = div_ceil(img.width, img.mcu_width)
    // Number of MCU's per height
    img.mcu_y = div_ceil(img.height, img.mcu_height)
    if img.h_max != 1 || img.v_max != 1 {
      // interleaved images have horizontal and vertical sampling factors
      // not equal to 1.
      img.is_interleaved = true
    }
    // Extract quantization tables from the arrays into components
    guard img.qt_tables[component.quantization_table_number] is Some(qt_table) else {
      raise DqtError(
        "No quantization table for component \{component.component_id.debug()}",
      )
    }
    // (upstream also computes the unused `x`, `w2` and `y` fields here)
    component.quantization_table = qt_table
    // initially stride contains its horizontal sub-sampling
    component.width_stride *= img.mcu_x * 8
  }
  // Sampling factors are one thing that suck: this fixes a specific problem
  // with images like (2 2) None, (2 1) H, (2 1) H.
  let mut handle_that_annoying_bug = false
  for c in img.components {
    if c.component_id == Y {
      if c.horizontal_sample == 2 || c.vertical_sample == 2 {
        handle_that_annoying_bug = true
      }
      break
    }
  }
  if handle_that_annoying_bug {
    for comp in img.components {
      if comp.component_id != Y &&
        (comp.horizontal_sample != 1 || comp.vertical_sample != 1) {
        comp.fix_an_annoying_bug = 2
      }
    }
  }
  if img.is_mjpeg {
    fill_default_mjpeg_tables(
      img.is_progressive,
      img.dc_huffman_tables,
      img.ac_huffman_tables,
    )
  }
  // check colorspace matches
  if img.input_colorspace.num_components() > img.components.length() {
    if img.input_colorspace == YCCK {
      // Some images may have YCCK format (from adobe app14 segment) which is
      // supposed to be 4 components but only 3 components; treat it as YCbCr.
      img.input_colorspace = YCbCr
    } else if img.components.length() > 0 {
      // (non-strict mode) Defaulting to multisample to decode
      img.input_colorspace = MultiBand(img.components.length())
    }
  }
}

///|
fn div_ceil(a : Int, b : Int) -> Int {
  let d = a / b
  if a % b != 0 {
    d + 1
  } else {
    d
  }
}

///|
/// Calculate the padded width of a row for the given sub-sampling ratio.
fn calculate_padded_width(actual_width : Int, sub_sample : SampleRatios) -> Int {
  match sub_sample {
    NoSample | V =>
      // None+V sends one MCU row, so that's a simple calculation
      (actual_width + 7) / 8 * 8
    H | HV =>
      // sends two rows, width can be expanded by up to 15 more bytes
      (actual_width + 15) / 16 * 16
    Generic(h, _) =>
      (actual_width + @cmp.maximum(h * 8 - 1, 0)) / (h * 8) * (h * 8)
  }
}

///|
/// Fill in the default Huffman tables of MJPEG streams (Section K.3.3).
fn fill_default_mjpeg_tables(
  is_progressive : Bool,
  dc_huffman_tables : FixedArray[HuffmanTable?],
  ac_huffman_tables : FixedArray[HuffmanTable?],
) -> Unit {
  let dc_values = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
  ]
  if dc_huffman_tables[0] is None {
    // Table K.3
    dc_huffman_tables[0] = Some(
      HuffmanTable::new_unfilled(
        [
          0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00,
        ],
        dc_values,
        true,
        is_progressive,
      ),
    ) catch {
      _ => abort("invalid default table")
    }
  }
  if dc_huffman_tables[1] is None {
    // Table K.4
    dc_huffman_tables[1] = Some(
      HuffmanTable::new_unfilled(
        [
          0x00, 0x00, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
          0x00, 0x00, 0x00, 0x00, 0x00,
        ],
        dc_values,
        true,
        is_progressive,
      ),
    ) catch {
      _ => abort("invalid default table")
    }
  }
  if ac_huffman_tables[0] is None {
    // Table K.5
    ac_huffman_tables[0] = Some(
      HuffmanTable::new_unfilled(
        [
          0x00, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04,
          0x04, 0x00, 0x00, 0x01, 0x7D,
        ],
        [
          0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
          0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
          0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
          0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
          0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
          0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
          0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
          0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
          0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
          0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
          0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
          0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
          0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
          0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
        ],
        false,
        is_progressive,
      ),
    ) catch {
      _ => abort("invalid default table")
    }
  }
  if ac_huffman_tables[1] is None {
    // Table K.6
    ac_huffman_tables[1] = Some(
      HuffmanTable::new_unfilled(
        [
          0x00, 0x00, 0x02, 0x01, 0x02, 0x04, 0x04, 0x03, 0x04, 0x07, 0x05, 0x04,
          0x04, 0x00, 0x01, 0x02, 0x77,
        ],
        [
          0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41,
          0x51, 0x07, 0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
          0xA1, 0xB1, 0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0, 0x15, 0x62, 0x72, 0xD1,
          0x0A, 0x16, 0x24, 0x34, 0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26,
          0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44,
          0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
          0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74,
          0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
          0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A,
          0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4,
          0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7,
          0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA,
          0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3, 0xF4,
          0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
        ],
        false,
        is_progressive,
      ),
    ) catch {
      _ => abort("invalid default table")
    }
  }
}
