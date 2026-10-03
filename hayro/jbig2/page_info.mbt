// Port of `hayro-jbig2/src/page_info.rs`: page information segment parsing
// (7.4.8).

///|
/// Parsed page information segment (7.4.8).
priv struct PageInformation {
  /// "This is a four-byte value containing the width in pixels of the page's
  /// bitmap." (7.4.8.1)
  width : UInt
  /// "This is a four-byte value containing the height in pixels of the page's
  /// bitmap." (7.4.8.2)
  height : UInt
  /// "This is a four-byte value containing the resolution of the original page
  /// medium, measured in pixels/metre in the horizontal direction. If this
  /// value is unknown, then this field must contain 0x00000000." (7.4.8.3)
  ///
  /// `None` means unknown resolution.
  _x_resolution : UInt?
  /// "This is a four-byte value containing the resolution of the original page
  /// medium, measured in pixels/metre in the vertical direction. If this value
  /// is unknown, then this field must contain 0x00000000." (7.4.8.4)
  ///
  /// `None` means unknown resolution.
  _y_resolution : UInt?
  /// Page segment flags (7.4.8.5).
  flags : PageFlags
  /// Page striping information (7.4.8.6).
  _striping : PageStriping
}

///|
fn PageInformation::default() -> PageInformation {
  {
    width: 0,
    height: 0,
    _x_resolution: None,
    _y_resolution: None,
    flags: {
      _is_lossless: false,
      _might_contain_refinements: false,
      default_pixel: 0,
      _default_combination_operator: Or,
      _requires_auxiliary_buffers: false,
      _combination_operator_overridden: false,
      _might_contain_coloured: false,
    },
    _striping: { _is_striped: false, _max_stripe_size: 0, },
  }
}

///|
/// Page segment flags (7.4.8.5, Figure 56).
priv struct PageFlags {
  /// "Bit 0: Page is eventually lossless. If this bit is 0, then the file does
  /// not contain a lossless representation of the original (pre-coding) page.
  /// If this bit is 1, then the file contains enough information to reconstruct
  /// the original page." (7.4.8.5)
  _is_lossless : Bool
  /// "Bit 1: Page might contain refinements. If this bit is 0, then no
  /// refinement region segment may be associated with the page. If this bit
  /// is 1, then such segments may be associated with the page." (7.4.8.5)
  _might_contain_refinements : Bool
  /// "Bit 2: Page default pixel value. This bit contains the initial value for
  /// every pixel in the page, before any region segments are decoded or drawn."
  /// (7.4.8.5)
  default_pixel : Int
  /// "Bits 3-4: Page default combination operator." (7.4.8.5)
  _default_combination_operator : CombinationOperator
  /// "Bit 5: Page requires auxiliary buffers. If this bit is 0, then no region
  /// segment requiring an auxiliary buffer may be associated with the page."
  /// (7.4.8.5)
  _requires_auxiliary_buffers : Bool
  /// "Bit 6: Page combination operator overridden. If this bit is 0, then every
  /// direct region segment associated with this page must use the page's default
  /// combination operator. If this bit is 1, then direct region segments
  /// associated with this page may use any combination operators." (7.4.8.5)
  _combination_operator_overridden : Bool
  /// "Bit 7: Page might contain coloured segment. If this bit is 0, then no
  /// segment with colour extension may be associated with the page." (7.4.8.5)
  _might_contain_coloured : Bool
}

///|
/// Page striping information (7.4.8.6, Figure 57).
priv struct PageStriping {
  /// "Bit 15: Page is striped. If the 'page is striped' bit is 1, then the page
  /// may have end of stripe segments associated with it." (7.4.8.6)
  ///
  /// "If the page's bitmap height is unknown (indicated by a page bitmap height
  /// of 0xFFFFFFFF) then the 'page is striped' bit must be 1." (7.4.8.6)
  _is_striped : Bool
  /// "Bits 0-14: Maximum stripe size." (7.4.8.6)
  ///
  /// "The maximum size of each stripe (the distance between an end of stripe
  /// segment's end row and the end row of the previous end of stripe segment,
  /// or 0 in the case of the first end of stripe segment) must be no more than
  /// the page's maximum stripe size." (7.4.8.6)
  _max_stripe_size : UInt
}

///|
/// Parse a page information segment (7.4.8).
fn parse_page_information(reader : Reader) -> PageInformation raise DecodeError {
  // 7.4.8.1: Page bitmap width
  let width = ok_or(reader.read_u32(), eof)

  // 7.4.8.2: Page bitmap height
  let height = ok_or(reader.read_u32(), eof)

  // 7.4.8.3: Page X resolution
  let _x_resolutionraw = ok_or(reader.read_u32(), eof)
  let x_resolution = if _x_resolutionraw == 0 {
    None
  } else {
    Some(_x_resolutionraw)
  }

  // 7.4.8.4: Page Y resolution
  let y_resolution_raw = ok_or(reader.read_u32(), eof)
  let y_resolution = if y_resolution_raw == 0 {
    None
  } else {
    Some(y_resolution_raw)
  }

  // 7.4.8.5: Page segment flags
  let flags_byte = ok_or(reader.read_byte(), eof)
  let flags = parse_page_flags(flags_byte.to_int())

  // 7.4.8.6: Page striping information
  let striping_raw = ok_or(reader.read_u16(), eof)
  let striping : PageStriping = {
    _is_striped: (striping_raw & 0x8000) != 0,
    _max_stripe_size: striping_raw & 0x7FFF,
  }
  {
    width,
    height,
    _x_resolution: x_resolution,
    _y_resolution: y_resolution,
    flags,
    _striping: striping,
  }
}

///|
fn parse_page_flags(flags : Int) -> PageFlags {
  let combo_bits = (flags >> 3) & 0x03
  let _default_combination_operator : CombinationOperator = match combo_bits {
    0 => Or
    1 => And
    2 => Xor
    _ => Xnor
  }
  {
    _is_lossless: (flags & 0x01) != 0,
    _might_contain_refinements: (flags & 0x02) != 0,
    default_pixel: (flags >> 2) & 0x01,
    _default_combination_operator,
    _requires_auxiliary_buffers: (flags & 0x20) != 0,
    _combination_operator_overridden: (flags & 0x40) != 0,
    _might_contain_coloured: (flags & 0x80) != 0,
  }
}
