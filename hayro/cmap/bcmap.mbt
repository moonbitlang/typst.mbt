// Port of `hayro-cmap/src/bcmap/mod.rs`.
//
// Inspired by pdf.js, we use a custom binary format to optionally embed
// the required cmaps in a space-efficient manner. However, we don't use
// their format description but have a custom one. For more information,
// see <https://github.com/LaurenzV/cmap-resources/tree/hayro>.

///|
let bcmap_magic : Bytes = b"bcmap"

///|
const BCMAP_VERSION : Int = 0x01

///|
const BCMAP_FILE_HEADER_SIZE : Int = 10

///|
const SEG_HEADER_SIZE : Int = 5

///|
const SEGMENT_RANGE_1B : Int = 0x01

///|
const SEGMENT_SINGLE_1B : Int = 0x02

///|
const SEGMENT_RANGE_2B : Int = 0x03

///|
const SEGMENT_SINGLE_2B : Int = 0x04

///|
const SEGMENT_RANGE_3B : Int = 0x05

///|
const SEGMENT_SINGLE_3B : Int = 0x06

///|
const SEGMENT_RANGE_4B : Int = 0x07

///|
const SEGMENT_SINGLE_4B : Int = 0x08

///|
const SEGMENT_USECMAP : Int = 0x09

///|
const SEGMENT_NOTDEF : Int = 0x0A

///|
const SEGMENT_WMODE : Int = 0x0B

///|
const SEGMENT_CODESPACE : Int = 0x0C

///|
const SEGMENT_NAME : Int = 0x0D

///|
const SEGMENT_CID_SYSTEM_INFO : Int = 0x0E

///|
const SEGMENT_BF_RANGE_VARIABLE : Int = 0x0F

///|
const SEGMENT_BF_SINGLE_VARIABLE : Int = 0x10

///|
const SEGMENT_BF_SINGLE_1U : Int = 0x11

///|
const SEGMENT_BF_SINGLE_2U : Int = 0x12

///|
const SEGMENT_BF_SINGLE_3U : Int = 0x13

///|
const SEGMENT_BF_SINGLE_4U : Int = 0x14

///|
const SEGMENT_BF_RANGE_1U : Int = 0x15

///|
const SEGMENT_BF_RANGE_2U : Int = 0x16

///|
fn bcmap_parse(
  data : BytesView,
  get_cmap : (CMapName) -> Bytes?,
  depth : Int,
  bundle : Bundle,
) -> CMap? {
  // While in theory we can assume that all binary cmaps are valid, it can
  // of course happen that an invalid one has been passed from outside, so
  // we still need to do proper validation.

  if data.length() < 6 ||
    !has_prefix(data, bcmap_magic) ||
    data[5].to_int() != BCMAP_VERSION {
    return None
  }
  let reader = BReader::new(data)
  guard reader.read_bytes(6) is Some(_) else { return None } // Skip magic + version.
  guard reader.read_u32() is Some(file_len) else { return None }
  let file_len = file_len.reinterpret_as_int()
  let delta_table = bundle.delta_table
  let count_table = bundle.count_table
  let mut cmap_name = None
  let mut character_collection = None
  let mut writing_mode = None
  let mut base : CMap? = None
  let _codespace_ranges = []
  let cid_ranges = PartitionedRanges::new()
  let notdef_ranges = PartitionedRanges::new()
  let bf_entries = []

  // Start parsing all segments of the file.
  guard file_len >= BCMAP_FILE_HEADER_SIZE && file_len <= data.length() else {
    return None
  }
  let reader = BReader::new(data[BCMAP_FILE_HEADER_SIZE:file_len])
  while !reader.at_end() {
    guard reader.read_u8() is Some(seg_type) else { return None }
    guard reader.read_u32() is Some(seg_len) else { return None }
    let seg_len = seg_len.to_uint64()
    guard seg_len >= SEG_HEADER_SIZE.to_uint64() else { return None }
    let payload_len = seg_len - SEG_HEADER_SIZE.to_uint64()
    guard payload_len <= 0x7FFFFFFFUL else { return None }
    guard reader.read_bytes(payload_len.to_int()) is Some(payload) else {
      return None
    }
    match seg_type {
      SEGMENT_NAME => cmap_name = Some(payload.to_owned())
      SEGMENT_CID_SYSTEM_INFO => {
        // Format: Each string is 0-terminated.
        let r = BReader::new(payload)
        let registry = r.eat_until(b => b == 0)
        guard r.read_u8() is Some(_) else { return None }
        let ordering = r.eat_until(b => b == 0)
        guard r.read_u8() is Some(_) else { return None }
        guard r.read_u16() is Some(supplement) else { return None }
        character_collection = Some({
          family: CidFamily::from_registry_ordering(registry, ordering),
          supplement,
        })
      }
      SEGMENT_USECMAP => {
        guard get_cmap(CMapName::from_bytes(payload)) is Some(base_data) else {
          return None
        }
        guard parse_inner(base_data, get_cmap, depth, Some(bundle)) is Some(b) else {
          return None
        }
        base = Some(b)
      }
      SEGMENT_WMODE => {
        guard payload.length() > 0 else { return None }
        writing_mode = match payload[0] {
          0 => Some(Horizontal)
          1 => Some(Vertical)
          _ => None
        }
      }
      SEGMENT_CODESPACE =>
        if parse_codespace(payload, _codespace_ranges) is None {
          return None
        }
      SEGMENT_NOTDEF =>
        if parse_notdef(payload, notdef_ranges) is None {
          return None
        }
      SEGMENT_RANGE_1B
      | SEGMENT_RANGE_2B
      | SEGMENT_RANGE_3B
      | SEGMENT_RANGE_4B => {
        let bw = (seg_type + 1) / 2
        if parse_cid_segment(
            payload,
            cid_ranges,
            bw,
            delta_table,
            Some(count_table),
          )
          is None {
          return None
        }
      }
      SEGMENT_SINGLE_1B
      | SEGMENT_SINGLE_2B
      | SEGMENT_SINGLE_3B
      | SEGMENT_SINGLE_4B => {
        let bw = (seg_type + 1) / 2
        if parse_cid_segment(payload, cid_ranges, bw, delta_table, None) is None {
          return None
        }
      }
      SEGMENT_BF_RANGE_VARIABLE =>
        if parse_bf_segment(
            payload,
            bf_entries,
            delta_table,
            Some(count_table),
            None,
          )
          is None {
          return None
        }
      SEGMENT_BF_SINGLE_VARIABLE =>
        if parse_bf_segment(payload, bf_entries, delta_table, None, None)
          is None {
          return None
        }
      SEGMENT_BF_RANGE_1U =>
        if parse_bf_segment(
            payload,
            bf_entries,
            delta_table,
            Some(count_table),
            Some(1),
          )
          is None {
          return None
        }
      SEGMENT_BF_RANGE_2U =>
        if parse_bf_segment(
            payload,
            bf_entries,
            delta_table,
            Some(count_table),
            Some(2),
          )
          is None {
          return None
        }
      SEGMENT_BF_SINGLE_1U =>
        if parse_bf_segment(payload, bf_entries, delta_table, None, Some(1))
          is None {
          return None
        }
      SEGMENT_BF_SINGLE_2U =>
        if parse_bf_segment(payload, bf_entries, delta_table, None, Some(2))
          is None {
          return None
        }
      SEGMENT_BF_SINGLE_3U =>
        if parse_bf_segment(payload, bf_entries, delta_table, None, Some(3))
          is None {
          return None
        }
      SEGMENT_BF_SINGLE_4U =>
        if parse_bf_segment(payload, bf_entries, delta_table, None, Some(4))
          is None {
          return None
        }
      _ => return None
    }
  }
  cid_ranges.sort()
  notdef_ranges.sort()
  stable_sort_by_start(bf_entries, e => e.range.start)
  Some({
    metadata: { character_collection, name: cmap_name, writing_mode, },
    _codespace_ranges,
    cid_ranges,
    notdef_ranges,
    bf_entries,
    base,
  })
}

///|
fn parse_codespace(
  payload : BytesView,
  ranges : Array[CodespaceRange],
) -> Unit? {
  let r = BReader::new(payload)
  guard r.read_u8() is Some(n_ranges) else { return None }
  for _ in 0..<n_ranges {
    guard r.read_u8() is Some(bw) else { return None }
    guard r.read_n_bytes(bw) is Some(low) else { return None }
    guard r.read_n_bytes(bw) is Some(high) else { return None }
    ranges.push({ number_bytes: bw, low, high, })
  }
  Some(())
}

///|
fn parse_notdef(payload : BytesView, ranges : PartitionedRanges) -> Unit? {
  let r = BReader::new(payload)
  guard r.read_u8() is Some(bw) else { return None }
  guard r.read_u16() is Some(n_entries) else { return None }
  for _ in 0..<n_entries {
    guard r.read_n_bytes(bw) is Some(start) else { return None }
    guard r.read_n_bytes(bw) is Some(end) else { return None }
    guard r.read_u16() is Some(cid) else { return None }
    ranges.push(bw, {
      range: { start, end, },
      cid_start: cid.reinterpret_as_uint(),
    })
  }
  Some(())
}

///|
fn read_huffman_column(
  r : BReader,
  table : HuffmanTable,
  n_entries : Int,
) -> Array[UInt]? {
  guard r.read_u32() is Some(len) else { return None }
  guard r.read_bytes(len.reinterpret_as_int()) is Some(data) else {
    return None
  }
  let reader = BReader::new(data)
  let out = []
  for _ in 0..<n_entries {
    guard table.decode(reader) is Some(v) else { return None }
    out.push(v)
  }
  Some(out)
}

///|
fn parse_cid_segment(
  payload : BytesView,
  ranges : PartitionedRanges,
  byte_width : Int,
  delta_table : HuffmanTable,
  count_table : HuffmanTable?,
) -> Unit? {
  let r = BReader::new(payload)
  guard r.read_u16() is Some(n_entries) else { return None }
  if n_entries == 0 {
    return Some(())
  }

  // There are two types of CID segments, all of which are stored in a columnar
  // fastion in the file:
  // For the first type, we have a simple mapping from a single code to a single
  // CID. In this case, the data stream first contains all codes using delta-coding,
  // encoded using huffman coding. This is followed by all CIDs, stored as
  // u16 (either as a raw CID, or as `0` in case the CID is +1 the previous CID).
  //
  // For the second type, we have a range of consecutive codes, which map
  // to a range of consecutive CIDs. In this case, we have an additional "count"
  // column that stores how many codes are mapped consecutively. These are also
  // encoded using huffman coding.

  // Read deltas for the start code points.
  guard read_huffman_column(r, delta_table, n_entries) is Some(deltas) else {
    return None
  }

  // Read the counts for each consecutive code range.
  let mut counts = []
  if count_table is Some(ct) {
    guard read_huffman_column(r, ct, n_entries) is Some(c) else { return None }
    counts = c
  }

  // Read the CIDs and reconstruct the character codes that map to them.
  let is_range = count_table is Some(_)
  let mut prev_end : UInt? = None
  let mut prev_cid : UInt? = None
  let mut prev_range_len : UInt = 0
  for i in 0..<n_entries {
    guard r.read_u16() is Some(raw_cid) else { return None }

    // Note that start deltas and counts are encoded minus one, so we
    // need to add one when reconstructing them.

    // Reconstruct start code.
    let start = match prev_end {
      Some(pe) => pe + 1 + deltas[i]
      None => deltas[i]
    }

    // Reconstruct end code.
    let end = if is_range { start + counts[i] + 1 } else { start }

    // CID 0 means it's consecutive to the last seen CID, plus 1.
    let cid = if raw_cid == 0 {
      match prev_cid {
        Some(pc) => pc + prev_range_len + 1
        None => 0
      }
    } else {
      raw_cid.reinterpret_as_uint()
    }
    ranges.push(byte_width, { range: { start, end, }, cid_start: cid, })
    prev_end = Some(end)
    prev_cid = Some(cid)
    prev_range_len = end - start
  }
  Some(())
}

///|
fn parse_bf_segment(
  payload : BytesView,
  entries : Array[BfRange],
  delta_table : HuffmanTable,
  count_table : HuffmanTable?,
  fixed_units : Int?,
) -> Unit? {
  let r = BReader::new(payload)
  guard r.read_u16() is Some(n_entries) else { return None }
  guard read_huffman_column(r, delta_table, n_entries) is Some(deltas) else {
    return None
  }

  // Read counts for range segments.
  let mut counts = []
  if count_table is Some(ct) {
    guard read_huffman_column(r, ct, n_entries) is Some(c) else { return None }
    counts = c
  }
  let is_range = count_table is Some(_)
  let mut prev_end : UInt? = None
  for i in 0..<n_entries {
    // Fixed-width segments encode destinations without a length prefix.
    let n_units = match fixed_units {
      Some(nu) => nu
      None => {
        guard r.read_u8() is Some(nu) else { return None }
        nu
      }
    }
    let dst_base = []
    for _ in 0..<n_units {
      guard r.read_u16() is Some(u) else { return None }
      dst_base.push(u)
    }
    let start = match prev_end {
      Some(pe) => pe + 1 + deltas[i]
      None => deltas[i]
    }
    let end = if is_range { start + counts[i] + 1 } else { start }
    entries.push({ range: { start, end, }, dst_base, })
    prev_end = Some(end)
  }
  Some(())
}
