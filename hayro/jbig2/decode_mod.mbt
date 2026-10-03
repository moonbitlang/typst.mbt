// Port of `hayro-jbig2/src/decode/mod.rs`: region and dictionary segment
// parsing and decoding.

///|
/// A decoded region bitmap with its combination operator.
priv struct RegionBitmap {
  /// The decoded bitmap.
  bitmap : Bitmap
  /// How to combine this region with the page bitmap.
  combination_operator : CombinationOperator
}

///|
/// "These operators describe how the segment's bitmap is to be combined with
/// the page bitmap." (7.4.1.5)
priv enum CombinationOperator {
  /// 0 OR
  Or
  /// 1 AND
  And
  /// 2 XOR
  Xor
  /// 3 XNOR
  Xnor
  /// 4 REPLACE
  Replace
}

///|
fn CombinationOperator::from_value(
  value : Int,
) -> CombinationOperator raise DecodeError {
  match value & 0x07 {
    0 => Or
    1 => And
    2 => Xor
    3 => Xnor
    4 => Replace
    _ => raise Region(InvalidCombinationOperator)
  }
}

///|
/// Template used for arithmetic of generic regions.
///
/// - Generic regions: `GBTEMPLATE` (7.4.6.2)
/// - Symbol dictionaries: `SDTEMPLATE` (7.4.2.1.1)
/// - Pattern dictionaries: `HDTEMPLATE` (7.4.4.1.1)
/// - Halftone regions: `HTEMPLATE` (7.4.5.1.1)
/// - Gray-scale images: `GSTEMPLATE` (Annex C)
priv enum Template {
  /// Template 0
  ///
  /// Context bits: 16 (Figure 3).
  Template0
  /// Template 1
  ///
  /// Context bits: 13 (Figure 4).
  Template1
  /// Template 2
  ///
  /// Context bits: 10 (Figure 5).
  Template2
  /// Template 3
  ///
  /// Context bits: 10 (Figure 6).
  Template3
}

///|
fn Template::from_byte(value : Int) -> Template {
  match value & 0x03 {
    0 => Template0
    1 => Template1
    2 => Template2
    _ => Template3
  }
}

///|
/// Number of context bits for this template (6.2.5.3).
fn Template::context_bits(self : Template) -> Int {
  match self {
    Template0 => 16
    Template1 => 13
    Template2 | Template3 => 10
  }
}

///|
/// Number of adaptive template pixels (6.2.5.3).
fn Template::adaptive_template_pixels(self : Template) -> Int {
  match self {
    Template0 => 4
    Template1 | Template2 | Template3 => 1
  }
}

///|
/// Parsed region segment information field (7.4.1).
///
/// "A region segment information field contains the following subfields, as
/// shown in Figure 30:
/// - Region segment bitmap width – see 7.4.1.1.
/// - Region segment bitmap height – see 7.4.1.2.
/// - Region segment bitmap X location – see 7.4.1.3.
/// - Region segment bitmap Y location – see 7.4.1.4.
/// - Region segment flags – see 7.4.1.5." (7.4.1)
priv struct RegionSegmentInfo {
  /// "This four-byte field gives the width in pixels of the bitmap encoded
  /// in this segment." (7.4.1.1)
  width : UInt
  /// "This four-byte field gives the height in pixels of the bitmap encoded
  /// in this segment." (7.4.1.2)
  mut height : UInt
  /// "This four-byte field gives the horizontal offset in pixels of the bitmap
  /// encoded in this segment relative to the page bitmap." (7.4.1.3)
  x_location : UInt
  /// "This four-byte field gives the vertical offset in pixels of the bitmap
  /// encoded in this segment relative to the page bitmap." (7.4.1.4)
  y_location : UInt
  /// "Bits 0-2: External combination operator." (7.4.1.5)
  combination_operator : CombinationOperator
  /// "Bit 3: Colour extension flag (COLEXTFLAG). This field specifies whether
  /// the region segment is extended to represent coloured bitmap." (7.4.1.5)
  _colour_extension : Bool
}

///|
/// Parse the region segment information field (7.4.1).
fn parse_region_segment_info(
  reader : Reader,
) -> RegionSegmentInfo raise DecodeError {
  // 7.4.1.1: Region segment bitmap width
  let width = ok_or(reader.read_u32(), eof)
  // 7.4.1.2: Region segment bitmap height
  let height = ok_or(reader.read_u32(), eof)
  // 7.4.1.3: Region segment bitmap X location
  let x_location = ok_or(reader.read_u32(), eof)
  // 7.4.1.: Region segment bitmap Y location
  let y_location = ok_or(reader.read_u32(), eof)

  // 7.4.1.5: Region segment flags
  let flags = ok_or(reader.read_byte(), eof).to_int()

  // "Bits 0-2: External combination operator."
  let combination_operator = CombinationOperator::from_value(flags)

  // "Bit 3: Colour extension flag (COLEXTFLAG)."
  let colour_extension = (flags & 0x08) != 0

  // "Bits 4-7: Reserved; must be 0."
  if (flags & 0xF0) != 0 {
    raise Region(InvalidCombinationOperator)
  }
  {
    width,
    height,
    x_location,
    y_location,
    combination_operator,
    _colour_extension: colour_extension,
  }
}

///|
/// Adaptive template pixel position for generic and refinement regions (6.2.5.4, Figure 7).
///
/// (`x`/`y` are upstream's `i8`s.)
priv struct AdaptiveTemplatePixel {
  x : Int
  y : Int
}

///|
fn AdaptiveTemplatePixel::default() -> AdaptiveTemplatePixel {
  { x: 0, y: 0, }
}

///|
/// `byte as i8`.
fn i8_of(byte : Byte) -> Int {
  let v = byte.to_int()
  if v >= 128 {
    v - 256
  } else {
    v
  }
}

///|
/// Parse refinement adaptive template pixels (used by symbol dictionary and text region).
///
/// Used for:
/// - Symbol dictionary refinement AT flags (7.4.2.1.3): SDRATX1/SDRATY1, SDRATX2/SDRATY2
/// - Text region refinement AT flags (7.4.3.1.3): SBRATX1/SBRATY1, SBRATX2/SBRATY2
/// - Generic refinement region AT flags (7.4.7.3): GRATX1/GRATY1, GRATX2/GRATY2
fn parse_refinement_at_pixels(
  reader : Reader,
) -> Array[AdaptiveTemplatePixel] raise DecodeError {
  let x1 = i8_of(ok_or(reader.read_byte(), eof))
  let y1 = i8_of(ok_or(reader.read_byte(), eof))
  let x2 = i8_of(ok_or(reader.read_byte(), eof))
  let y2 = i8_of(ok_or(reader.read_byte(), eof))
  [{ x: x1, y: y1, }, { x: x2, y: y2, }]
}

///|
/// Template used for refinement arithmetic coding (7.4.7.2).
///
/// - Generic refinement regions: `GRTEMPLATE` (7.4.7.2)
/// - Symbol dictionaries: `SDRTEMPLATE` (7.4.2.1.1)
/// - Text regions: `SBRTEMPLATE` (7.4.3.1.1)
priv enum RefinementTemplate {
  /// Template 0: 13 pixels (6.3.5.3, Figure 12)
  RTemplate0
  /// Template 1: 10 pixels (6.3.5.3, Figure 13)
  RTemplate1
} derive(Eq)

///|
fn RefinementTemplate::from_byte(value : Int) -> RefinementTemplate {
  if (value & 0x01) == 0 {
    RTemplate0
  } else {
    RTemplate1
  }
}

///|
/// Number of context bits for this template (6.3.5.3).
fn RefinementTemplate::context_bits(self : RefinementTemplate) -> Int {
  match self {
    RTemplate0 => 13
    RTemplate1 => 10
  }
}
