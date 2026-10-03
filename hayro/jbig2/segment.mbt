// Port of `hayro-jbig2/src/segment.rs`: segment parsing for JBIG2 bitstreams
// (Section 7.2).
//
// This module handles parsing of individual segment headers and defines
// the segment types used in JBIG2.

///|
/// "The segment type is a number between 0 and 63, inclusive. Not all values
/// are allowed." (7.3)
priv enum SegmentType {
  /// Symbol dictionary – see 7.4.2. (type 0)
  SymbolDictionary
  /// Intermediate text region – see 7.4.3. (type 4)
  IntermediateTextRegion
  /// Immediate text region – see 7.4.3. (type 6)
  ImmediateTextRegion
  /// Immediate lossless text region – see 7.4.3. (type 7)
  ImmediateLosslessTextRegion
  /// Pattern dictionary – see 7.4.4. (type 16)
  PatternDictionary
  /// Intermediate halftone region – see 7.4.5. (type 20)
  IntermediateHalftoneRegion
  /// Immediate halftone region – see 7.4.5. (type 22)
  ImmediateHalftoneRegion
  /// Immediate lossless halftone region – see 7.4.5. (type 23)
  ImmediateLosslessHalftoneRegion
  /// Intermediate generic region – see 7.4.6. (type 36)
  IntermediateGenericRegion
  /// Immediate generic region – see 7.4.6. (type 38)
  ImmediateGenericRegion
  /// Immediate lossless generic region – see 7.4.6. (type 39)
  ImmediateLosslessGenericRegion
  /// Intermediate generic refinement region – see 7.4.7. (type 40)
  IntermediateGenericRefinementRegion
  /// Immediate generic refinement region – see 7.4.7. (type 42)
  ImmediateGenericRefinementRegion
  /// Immediate lossless generic refinement region – see 7.4.7. (type 43)
  ImmediateLosslessGenericRefinementRegion
  /// Page information – see 7.4.8. (type 48)
  PageInformation
  /// End of page – see 7.4.9. (type 49)
  EndOfPage
  /// End of stripe – see 7.4.10. (type 50)
  EndOfStripe
  /// End of file – see 7.4.11. (type 51)
  EndOfFile
  /// Profiles – see 7.4.12. (type 52)
  Profiles
  /// Tables – see 7.4.13. (type 53)
  Tables
  /// Colour palette – see 7.4.16. (type 54)
  ColourPalette
  /// Extension - see 7.4.14. (type 62)
  Extension
}

///|
/// "All other segment types are reserved and must not be used." (7.3)
fn SegmentType::from_type_value(value : Int) -> SegmentType raise DecodeError {
  match value {
    0 => SymbolDictionary
    4 => IntermediateTextRegion
    6 => ImmediateTextRegion
    7 => ImmediateLosslessTextRegion
    16 => PatternDictionary
    20 => IntermediateHalftoneRegion
    22 => ImmediateHalftoneRegion
    23 => ImmediateLosslessHalftoneRegion
    36 => IntermediateGenericRegion
    38 => ImmediateGenericRegion
    39 => ImmediateLosslessGenericRegion
    40 => IntermediateGenericRefinementRegion
    42 => ImmediateGenericRefinementRegion
    43 => ImmediateLosslessGenericRefinementRegion
    48 => PageInformation
    49 => EndOfPage
    50 => EndOfStripe
    51 => EndOfFile
    52 => Profiles
    53 => Tables
    54 => ColourPalette
    62 => Extension
    _ => raise Segment(UnknownType)
  }
}

///|
/// A parsed segment header (7.2.1).
priv struct SegmentHeader {
  /// "This four-byte field contains the segment's segment number. The valid
  /// range of segment numbers is 0 through 4294967295 (0xFFFFFFFF) inclusive."
  /// (7.2.2)
  segment_number : UInt
  /// "Bits 0-5: Segment type. See 7.3." (7.2.3)
  segment_type : SegmentType
  /// "Bit 7: Deferred non-retain. If this bit is 1, this segment is flagged
  /// as retained only by itself and its attached extension segments." (7.2.3)
  _retain_flag : Bool
  /// "This field encodes the number of the page to which this segment belongs.
  /// The first page must be numbered '1'. This field may contain a value of
  /// zero; this value indicates that this segment is not associated with any
  /// page." (7.2.6)
  _page_association : UInt
  /// "This field contains the segment numbers of the segments that this segment
  /// refers to, if any." (7.2.5)
  referred_to_segments : Array[UInt]
  /// "This 4-byte field contains the length of the segment's segment data part,
  /// in bytes." (7.2.7)
  ///
  /// `None` means the length was unknown (0xFFFFFFFF), which is only valid for
  /// immediate generic region segments in sequential organization.
  data_length : UInt?
}

///|
/// A parsed segment with its header and data.
priv struct Segment {
  /// The segment header.
  header : SegmentHeader
  /// The segment data (borrowed slice).
  data : BytesView
}

///|
/// Parse a segment header (7.2).
fn parse_segment_header(reader : Reader) -> SegmentHeader raise DecodeError {
  // 7.2.2: Segment number
  // "This four-byte field contains the segment's segment number. The valid
  // range of segment numbers is 0 through 4294967295 (0xFFFFFFFF) inclusive.
  // As mentioned before, it is possible for there to be gaps in the segment
  // numbering."
  let segment_number = ok_or(reader.read_u32(), eof)

  // 7.2.3: Segment header flags
  // "This is a 1-byte field."
  let flags = ok_or(reader.read_byte(), eof).to_int()

  // "Bits 0-5: Segment type. See 7.3."
  let segment_type = SegmentType::from_type_value(flags & 0x3F)

  // "Bit 6: Page association field size. See 7.2.6."
  let page_association_long = (flags & 0x40) != 0

  // "Bit 7: Deferred non-retain. If this bit is 1, this segment is flagged as
  // retained only by itself and its attached extension segments."
  let retain_flag = (flags & 0x80) == 0

  // 7.2.4: Referred-to segment count and retention flags
  // "This field contains one or more bytes indicating how many other segments
  // are referred to by this segment, and which segments contain data that is
  // needed after this segment."
  //
  // "The three most significant bits of the first byte in this field determine
  // the length of the field. If the value of this three-bit subfield is between
  // 0 and 4, then the field is one byte long. If the value of this three-bit
  // subfield is 7, then the field is at least five bytes long. This three-bit
  // subfield must not contain values of 5 and 6."
  let count_and_retention = ok_or(reader.read_byte(), eof).to_int()
  let short_count = (count_and_retention >> 5) & 0x07
  if short_count == 5 || short_count == 6 {
    raise Segment(InvalidReferredCount)
  }
  let referred_to_count : UInt = if short_count < 7 {
    // Short form: "Bits 5-7: Count of referred-to segments. This field may
    // take on values between zero and four."
    short_count.reinterpret_as_uint()
  } else {
    // Long form: "In the case where the field is in the long format (at least
    // five bytes long), it is composed of an initial four-byte field, followed
    // by a succession of one-byte fields."
    //
    // "Bits 0-28: Count of referred-to segments. This specifies the number of
    // segments that this segment refers to."
    // "Bits 29-31: Indication of long-form format. This field must contain the
    // value 7."
    let rest = ok_or(reader.read_bytes(3), eof)
    ((count_and_retention & 0x1F).reinterpret_as_uint() << 24) |
    (rest[0].to_uint() << 16) |
    (rest[1].to_uint() << 8) |
    rest[2].to_uint()
  }

  // Skip retention flag bytes in long form.
  // "The first one-byte field following the initial four-byte field is formatted
  // as follows: Bit 0: Retain bit for this segment. Bit 1-7: Retain bits for
  // referred-to segments."
  if short_count == 7 {
    // Number of retention bytes: ceil((referred_to_count + 1) / 8)
    let retention_bytes = (referred_to_count.to_int64() + 1 + 7) / 8
    ok_or(reader.skip_bytes(retention_bytes), eof)
  }

  // 7.2.5: Referred-to segment numbers
  // "When the current segment's number is 256 or less, then each referred-to
  // segment number is one byte long. Otherwise, when the current segment's
  // number is 65536 or less, each referred-to segment number is two bytes long.
  // Otherwise, each referred-to segment number is four bytes long."
  let referred_to_segments = []
  for _ in 0U..<referred_to_count {
    let referred = if segment_number <= 256 {
      ok_or(reader.read_byte(), eof).to_uint()
    } else if segment_number <= 65536 {
      ok_or(reader.read_u16(), eof)
    } else {
      ok_or(reader.read_u32(), eof)
    }

    // If a segment refers to other segments, it must refer to only segments
    // with lower segment numbers.
    if referred >= segment_number {
      raise Segment(InvalidReference)
    }
    referred_to_segments.push(referred)
  }

  // 7.2.6: Segment page association
  // "This field is one byte long if this segment's page association field size
  // flag bit is 0, and is four bytes long if this segment's page association
  // field size flag bit is 1."
  let page_association = if page_association_long {
    ok_or(reader.read_u32(), eof)
  } else {
    ok_or(reader.read_byte(), eof).to_uint()
  }

  // 7.2.7: Segment data length
  // "This 4-byte field contains the length of the segment's segment data part,
  // in bytes."
  //
  // "If the segment's type is 'Immediate generic region', then the length field
  // may contain the value 0xFFFFFFFF. This value is intended to mean that the
  // length of the segment's data part is unknown at the time that the segment
  // header is written."
  let data_length_raw = ok_or(reader.read_u32(), eof)
  let data_length = if data_length_raw == 0xFFFFFFFF {
    None
  } else {
    Some(data_length_raw)
  }
  {
    segment_number,
    segment_type,
    _retain_flag: retain_flag,
    _page_association: page_association,
    referred_to_segments,
    data_length,
  }
}

///|
/// Parse a complete segment (header + data).
fn parse_segment(reader : Reader) -> Segment raise DecodeError {
  let header = parse_segment_header(reader)
  parse_segment_data(reader, header)
}

///|
/// Parse segment data for a previously parsed header.
///
/// "If the segment's type is 'Immediate generic region', then the length field
/// may contain the value 0xFFFFFFFF. This value is intended to mean that the
/// length of the segment's data part is unknown at the time that the segment
/// header is written." (7.2.7)
fn parse_segment_data(
  reader : Reader,
  header : SegmentHeader,
) -> Segment raise DecodeError {
  let data = match header.data_length {
    Some(len) => ok_or(reader.read_bytes(len.to_int64()), eof)
    None => {
      // "In order for the decoder to correctly decode the segment, it needs to
      // read the four-byte row count field, which is stored in the last four
      // bytes of the segment's data part. These four bytes can be detected
      // without knowing the length of the data part in advance: if MMR is 1,
      // they are preceded by the two-byte sequence 0x00 0x00; if MMR is 0, they
      // are preceded by the two-byte sequence 0xFF 0xAC." (7.4.6.4)
      let len = scan_for_immediate_generic_region_size(reader)
      ok_or(reader.read_bytes(len.to_int64()), eof)
    }
  }
  { header, data, }
}

///|
/// Scan for the end of an immediate generic region segment with unknown length.
///
/// "The form of encoding used by the segment may be determined by examining
/// the eighteenth byte of its segment data part, and the end sequences can
/// occur anywhere after that eighteenth byte." (7.2.7)
fn scan_for_immediate_generic_region_size(
  reader : Reader,
) -> Int raise DecodeError {
  let scan = reader.clone()
  let start_offset = scan.byte_pos()
  ok_or(scan.skip_bytes(17), eof)
  let flags = ok_or(scan.read_byte(), eof).to_int()
  let uses_mmr = (flags & 1) != 0

  // "if MMR is 1, they are preceded by the two-byte sequence 0x00 0x00;
  // if MMR is 0, they are preceded by the two-byte sequence 0xFF 0xAC."
  let (m0, m1) : (Byte, Byte) = if uses_mmr {
    (0x00, 0x00)
  } else {
    (0xFF, 0xAC)
  }

  // Search for the end marker. The marker is followed by a 4-byte row count.
  while scan.peek_bytes(6) is Some(bytes) {
    if bytes[0] == m0 && bytes[1] == m1 {
      // Found the marker. Total size is current offset + 2 (marker) + 4 (row count) - start.
      return scan.byte_pos() - start_offset + 2 + 4
    }
    ok_or(scan.skip_bytes(1), eof)
  }
  raise Segment(MissingEndMarker)
}
