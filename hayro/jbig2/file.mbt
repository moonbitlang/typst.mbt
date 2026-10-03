// Port of `hayro-jbig2/src/file.rs`: file format parsing for JBIG2
// bitstreams (Annex D of ITU-T T.88).
//
// This module handles parsing of standalone JBIG2 files in both sequential
// and random-access organization formats.

///|
/// "There are two standalone file organizations possible for a JBIG2 bitstream."
/// (Annex D)
priv enum FileOrganization {
  /// "This is a standalone file organization. This organization is intended for
  /// streaming applications, where the decoder is guaranteed to begin at the start
  /// of the bitstream and decode everything up to the end of the bitstream."
  /// (D.1)
  Sequential
  /// "This is a standalone file organization. This organization is intended for
  /// random-access applications, where the decoder might want to process parts of
  /// the file in an arbitrary order." (D.2)
  RandomAccess
}

///|
/// Parsed file header.
///
/// "A file header contains the following fields, in order:
/// ID string – see D.4.1.
/// File header flags – see D.4.2.
/// Number of pages – see D.4.3." (D.4)
priv struct FileHeader {
  /// The file organization type.
  organization : FileOrganization
  /// The number of pages in the file, if known.
  _number_of_pages : UInt?
  /// "If this bit is 0, no generic region segments uses the templates with
  /// 12 AT pixels. If the file contains one or more generic region segments
  /// using such templates, this bit must be 1." (D.4.2, Bit 2)
  _uses_extended_templates : Bool
  /// "If this bit is 0, no region segment is extended to be coloured. If the
  /// file contains one or more coloured region segments, this bit must be 1."
  /// (D.4.2, Bit 3)
  _contains_coloured_regions : Bool
}

///|
/// A parsed JBIG2 file.
priv struct File {
  /// The file header.
  _header : FileHeader
  /// The segments in the file.
  segments : Array[Segment]
}

///|
/// "This is an 8-byte sequence containing 0x97 0x4A 0x42 0x32 0x0D 0x0A 0x1A 0x0A."
/// (D.4.1)
let file_header_id : Bytes = b"\x97\x4A\x42\x32\x0D\x0A\x1A\x0A"

///|
/// Parse a standalone JBIG2 file.
fn parse_file(data : BytesView) -> File raise DecodeError {
  let reader = Reader::new(data)
  let header = parse_file_header(reader)
  let segments = parse_segments(reader, header.organization)

  // Technically shouldn't be necessary because the spec mandates that segments
  // are in sorted order, but just to be safe.
  let segments = sort_segments(segments)
  { _header: header, segments, }
}

///|
/// `segments.sort_by_key(|seg| seg.header.segment_number)` (a stable sort;
/// MoonBit's `sort_by` is unstable, so ties are broken by the original index).
fn sort_segments(segments : Array[Segment]) -> Array[Segment] {
  let indexed = segments.mapi((i, s) => (s, i))
  indexed.sort_by((a, b) => {
    let c = a.0.header.segment_number.compare(b.0.header.segment_number)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  indexed.map(p => p.0)
}

///|
fn parse_file_header(reader : Reader) -> FileHeader raise DecodeError {
  // D.4.1: ID string
  let id = ok_or(reader.read_bytes(8), eof)
  if id != file_header_id[:] {
    raise Format(InvalidHeader)
  }

  // D.4.2: File header flags
  let flags = ok_or(reader.read_byte(), eof).to_int()

  // "Bit 0: File organization type. If this bit is 0, the file uses the
  // random-access organization. If this bit is 1, the file uses the
  // sequential organization." (D.4.2)
  let organization = if (flags & 0x01) != 0 { Sequential } else { RandomAccess }

  // "Bit 1: Unknown number of pages. If this bit is 0, then the number of
  // pages contained in the file is known. If this bit is 1, then the number
  // of pages contained in the file was not known at the time that the file
  // header was coded." (D.4.2)
  let unknown_page_count = (flags & 0x02) != 0

  // "Bit 2: If this bit is 0, no generic region segments uses the templates
  // with 12 AT pixels." (D.4.2)
  let uses_extended_templates = (flags & 0x04) != 0

  // "Bit 3: If this bit is 0, no region segment is extended to be coloured."
  // (D.4.2)
  let contains_coloured_regions = (flags & 0x08) != 0

  // "Bits 4-7: Reserved; must be 0." (D.4.2)
  if (flags & 0xF0) != 0 {
    raise Format(ReservedBits)
  }

  // D.4.3: Number of pages
  // "This is a 4-byte field, and is not present if the 'unknown number of
  // pages' bit was 1." (D.4.3)
  let number_of_pages = if unknown_page_count {
    None
  } else {
    Some(ok_or(reader.read_u32(), eof))
  }
  {
    organization,
    _number_of_pages: number_of_pages,
    _uses_extended_templates: uses_extended_templates,
    _contains_coloured_regions: contains_coloured_regions,
  }
}

///|
fn parse_segments(
  reader : Reader,
  organization : FileOrganization,
) -> Array[Segment] raise DecodeError {
  let segments = []
  match organization {
    Sequential => parse_segments_sequential(reader, segments)
    RandomAccess => parse_segments_random_access(reader, segments)
  }
  segments
}

///|
/// Parse segments in sequential organization.
///
/// "In this organization, the file structure looks like Figure D.1. A file header
/// is followed by a sequence of segments. The two parts of each segment are stored
/// together: first the segment header then the segment data." (D.1)
fn parse_segments_sequential(
  reader : Reader,
  segments : Array[Segment],
) -> Unit raise DecodeError {
  while true {
    if reader.at_end() {
      break
    }
    let segment = parse_segment(reader)

    // "If a file contains an end of file segment, it must be the last segment."
    // (7.4.11)
    let is_eof = segment.header.segment_type is EndOfFile
    segments.push(segment)
    if is_eof {
      break
    }
  }
}

///|
/// Parse segments in random-access organization.
///
/// "In this organization, the file structure looks like Figure D.2. A file header
/// is followed by a sequence of segments headers; the last segment header is
/// followed by the data for the first segment, then the data for the second
/// segment, and so on." (D.2)
fn parse_segments_random_access(
  reader : Reader,
  segments : Array[Segment],
) -> Unit raise DecodeError {
  let headers = []
  while true {
    if reader.at_end() {
      break
    }
    let header = parse_segment_header(reader)

    // "If a file contains an end of file segment, it must be the last segment."
    // (7.4.11)
    let is_eof = header.segment_type is EndOfFile
    headers.push(header)
    if is_eof {
      break
    }
  }

  // Then, read all segment data.
  for header in headers {
    segments.push(parse_segment_data(reader, header))
  }
}
