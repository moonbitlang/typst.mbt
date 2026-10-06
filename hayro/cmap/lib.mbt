// Port of `hayro-cmap/src/lib.rs`.
//
// A parser for cmap files, as they are found in PDFs.
//
// This package provides a parser for cmap files and allows you to
// - Map character codes from text-showing operators to CID identifiers.
// - Map CIDs to Unicode characters or strings.
//
// Typst builds hayro without the `embed-cmaps` feature, so `load_embedded`
// always returns `None` and `CMap::parse` does not recognize the binary
// `bcmap` format. The binary format parser (`bcmap*.mbt`) is still ported and
// can be used with an explicitly loaded `Bundle` (see `CMap::parse_with_bundle`).

///|
/// Look up an embedded binary cmap by name.
///
/// Returns `None` when the `embed-cmaps` feature is not enabled (which is the
/// case for Typst).
pub fn load_embedded(_name : CMapName) -> Bytes? {
  None
}

///|
/// A CID (Character Identifier).
pub type Cid = UInt

///|
/// Let's limit the number of nested `usecmap` references to 16.
const MAX_NESTING_DEPTH : Int = 16

///|
/// A parsed cmap.
pub struct CMap {
  priv metadata : Metadata
  // Note that we don't actually use this, because Acrobat _seems_ to ignore
  // it, too.
  priv _codespace_ranges : Array[CodespaceRange]
  priv cid_ranges : PartitionedRanges
  priv notdef_ranges : PartitionedRanges
  priv bf_entries : Array[BfRange]
  priv base : CMap?
}

///|
/// Parse a cmap from raw bytes.
///
/// The `get_cmap` callback is used to recursively resolve cmaps that
/// are referenced via `usecmap`.
pub fn CMap::parse(data : BytesView, get_cmap : (CMapName) -> Bytes?) -> CMap? {
  parse_inner(data, get_cmap, 0, None)
}

///|
/// Parse a cmap like `CMap::parse` with the `embed-cmaps` feature enabled:
/// data in the binary `bcmap` format is decoded with the tables of `bundle`.
pub fn CMap::parse_with_bundle(
  data : BytesView,
  get_cmap : (CMapName) -> Bytes?,
  bundle : Bundle,
) -> CMap? {
  parse_inner(data, get_cmap, 0, Some(bundle))
}

///|
/// Create an Identity-H cmap.
pub fn CMap::identity_h() -> CMap {
  CMap::identity(Horizontal, b"Identity-H")
}

///|
/// Create an Identity-V cmap.
pub fn CMap::identity_v() -> CMap {
  CMap::identity(Vertical, b"Identity-V")
}

///|
fn CMap::identity(writing_mode : WritingMode, name : Bytes) -> CMap {
  let cid_ranges = PartitionedRanges::new()
  cid_ranges.push(2, { range: { start: 0, end: 0xFFFF, }, cid_start: 0, })
  {
    metadata: {
      character_collection: Some({ family: AdobeIdentity, supplement: 0, }),
      name: Some(name),
      writing_mode: Some(writing_mode),
    },
    _codespace_ranges: [],
    cid_ranges,
    notdef_ranges: PartitionedRanges::new(),
    bf_entries: [],
    base: None,
  }
}

///|
/// Return the metadata of this cmap.
pub fn CMap::metadata(self : CMap) -> Metadata {
  self.metadata
}

///|
/// Look up the CID code of a character code.
///
/// Returns `None` if the code does not match any range for the given byte
/// length.
pub fn CMap::lookup_cid_code(self : CMap, code : UInt, byte_len : Int) -> Cid? {
  // Note that, in theory, we are supposed to first check the code space range
  // whether the entry exists in the first place. However, from my experiments
  // Acrobat mostly seems to ignore this, so we do that as well.

  guard self.cid_ranges.get(byte_len) is Some(cid_ranges) else { return None }
  guard self.notdef_ranges.get(byte_len) is Some(notdef_ranges) else {
    return None
  }
  if find_in_ranges(cid_ranges, code, r => r.range) is Some(entry) {
    guard code >= entry.range.start else { return None }
    let offset = code - entry.range.start
    // `checked_add`.
    let cid = entry.cid_start + offset
    return if cid < entry.cid_start { None } else { Some(cid) }
  } else if find_in_ranges(notdef_ranges, code, r => r.range) is Some(entry) {
    // For `.notdef` ranges, all codes map to the same `.notdef` CID, so
    // no adding of the offset here.
    return Some(entry.cid_start)
  }

  // See pdfjs_bug920426, it uses bf chars for encoding the characters
  // of a text-showing operator, so try that as well. We don't want to
  // recurse though, only check the bf chars of this level.
  if self.lookup_bf_string_inner(code, false) is Some(Char(lookup)) {
    return Some(lookup.to_int().reinterpret_as_uint())
  }

  // If we still haven't found anything, check the base cmap.
  match self.base {
    Some(b) => b.lookup_cid_code(code, byte_len)
    None => None
  }
}

///|
/// Look up a bf string in the cmap. This is usually
/// used for mapping character codes to Unicode codepoints in a
/// `ToUnicode` cmap.
///
/// Returns `None` if no mapping is available.
pub fn CMap::lookup_bf_string(self : CMap, code : UInt) -> BfString? {
  self.lookup_bf_string_inner(code, true)
}

///|
fn CMap::lookup_bf_string_inner(
  self : CMap,
  code : UInt,
  recurse : Bool,
) -> BfString? {
  if find_in_ranges(self.bf_entries, code, e => e.range) is Some(entry) {
    // `u16::try_from(code - entry.range.start)`.
    let diff = code - entry.range.start
    guard diff <= 0xFFFFU else { return None }
    let offset = diff.reinterpret_as_int()
    return if offset == 0 {
      decode_utf16(entry.dst_base)
    } else {
      let units = entry.dst_base.copy()
      guard units.last() is Some(last) else { return None }
      // `checked_add` on `u16`.
      let sum = last + offset
      guard sum <= 0xFFFF else { return None }
      units[units.length() - 1] = sum
      decode_utf16(units)
    }
  }
  if recurse {
    match self.base {
      Some(b) => b.lookup_bf_string(code)
      None => None
    }
  } else {
    None
  }
}

///|
fn is_high_surrogate(u : Int) -> Bool {
  u >= 0xD800 && u <= 0xDBFF
}

///|
fn is_low_surrogate(u : Int) -> Bool {
  u >= 0xDC00 && u <= 0xDFFF
}

///|
/// Decode UTF-16 code units: a single character becomes `BfString::Char`,
/// several characters `BfString::String`; ill-formed UTF-16 yields `None`.
fn decode_utf16(units : Array[Int]) -> BfString? {
  // `core::char::decode_utf16(..).next()?.ok()?`
  guard units.length() > 0 else { return None }
  let u0 = units[0]
  let (first, first_len) = if is_high_surrogate(u0) {
    guard units.length() > 1 && is_low_surrogate(units[1]) else { return None }
    (0x10000 + ((u0 - 0xD800) << 10) + (units[1] - 0xDC00), 2)
  } else if is_low_surrogate(u0) {
    return None
  } else {
    (u0, 1)
  }
  if first_len == units.length() {
    Some(Char(first.unsafe_to_char()))
  } else {
    // `String::from_utf16(units).ok()?`
    let sb = StringBuilder()
    let mut i = 0
    while i < units.length() {
      let u = units[i]
      if is_high_surrogate(u) {
        guard i + 1 < units.length() && is_low_surrogate(units[i + 1]) else {
          return None
        }
        let c = 0x10000 + ((u - 0xD800) << 10) + (units[i + 1] - 0xDC00)
        sb.write_char(c.unsafe_to_char())
        i += 2
      } else if is_low_surrogate(u) {
        return None
      } else {
        sb.write_char(u.unsafe_to_char())
        i += 1
      }
    }
    Some(String(sb.to_string()))
  }
}

///|
/// Binary search over entries sorted by `range.start`, mirroring Rust's
/// `slice::binary_search_by` (including which of several matching entries is
/// found).
fn[T] find_in_ranges(
  entries : Array[T],
  code : UInt,
  range : (T) -> Range,
) -> T? {
  // -1: Less, 0: Equal, 1: Greater.
  let cmp = fn(entry : T) -> Int {
    let r = range(entry)
    if code < r.start {
      1
    } else if code > r.end {
      -1
    } else {
      0
    }
  }
  let mut size = entries.length()
  if size == 0 {
    return None
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    if cmp(entries[mid]) != 1 {
      base = mid
    }
    size -= half
  }
  if cmp(entries[base]) == 0 {
    Some(entries[base])
  } else {
    None
  }
}

///|
/// A range with a start and end code.
priv struct Range {
  start : UInt
  end : UInt
}

///|
/// A range of character codes mapped to CIDs.
priv struct CidRange {
  range : Range
  cid_start : Cid
}

///|
priv struct PartitionedRanges {
  buckets : FixedArray[Array[CidRange]]
}

///|
fn PartitionedRanges::new() -> PartitionedRanges {
  { buckets: [[], [], [], []], }
}

///|
fn PartitionedRanges::push(
  self : PartitionedRanges,
  byte_len : Int,
  range : CidRange,
) -> Unit {
  if byte_len >= 1 && byte_len <= 4 {
    self.buckets[byte_len - 1].push(range)
  }
}

///|
fn PartitionedRanges::get(
  self : PartitionedRanges,
  byte_len : Int,
) -> Array[CidRange]? {
  if byte_len >= 1 && byte_len <= 4 {
    Some(self.buckets[byte_len - 1])
  } else {
    None
  }
}

///|
fn PartitionedRanges::sort(self : PartitionedRanges) -> Unit {
  for bucket in self.buckets {
    stable_sort_by_start(bucket, r => r.range.start)
  }
}

///|
/// A stable sort by a `UInt` key (Rust's `sort_by` is stable).
fn[T] stable_sort_by_start(arr : Array[T], key : (T) -> UInt) -> Unit {
  let n = arr.length()
  if n < 2 {
    return
  }
  let mut src = arr.copy()
  let mut dst = arr.copy()
  let mut width = 1
  while width < n {
    let mut lo = 0
    while lo < n {
      let mid = if lo + width < n { lo + width } else { n }
      let hi = if lo + 2 * width < n { lo + 2 * width } else { n }
      let mut i = lo
      let mut j = mid
      let mut k = lo
      while k < hi {
        if i < mid && (j >= hi || key(src[i]) <= key(src[j])) {
          dst[k] = src[i]
          i += 1
        } else {
          dst[k] = src[j]
          j += 1
        }
        k += 1
      }
      lo = hi
    }
    let tmp = src
    src = dst
    dst = tmp
    width *= 2
  }
  for i in 0..<n {
    arr[i] = src[i]
  }
}

///|
priv struct BfRange {
  range : Range
  dst_base : Array[Int]
}

///|
/// A codespace range defining valid character code byte sequences.
// Parsed and stored, never read: upstream marks the struct
// `#[allow(dead_code)]` (hayro-cmap/src/lib.rs:592).
#warnings("-unused_field")
priv struct CodespaceRange {
  number_bytes : Int
  low : UInt
  high : UInt
}

///|
/// A Unicode value decoded from a cmap.
pub(all) enum BfString {
  /// A single character.
  Char(Char)
  /// A string.
  String(String)
} derive(Eq, Debug)

///|
pub impl Show for BfString with fn output(self, logger) {
  match self {
    Char(c) => logger.write_string("Char(\{c.to_int()})")
    String(s) => logger.write_string("String(\{s})")
  }
}

///|
/// Metadata extracted from a cmap file.
pub(all) struct Metadata {
  /// The referenced character collection.
  character_collection : CharacterCollection?
  /// The cmap name.
  name : Bytes?
  /// The writing mode.
  writing_mode : WritingMode?
} derive(Eq, Debug)

///|
/// The registry+ordering family of a CID character collection.
pub(all) enum CidFamily {
  /// Adobe-Japan1
  AdobeJapan1
  /// Adobe-GB1
  AdobeGB1
  /// Adobe-CNS1
  AdobeCNS1
  /// Adobe-Korea1
  AdobeKorea1
  /// Adobe-Identity
  AdobeIdentity
  /// A non-predefined registry/ordering pair.
  Custom(registry~ : Bytes, ordering~ : Bytes)
} derive(Eq, Debug)

///|
pub impl Show for CidFamily with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
/// Create a `CidFamily` from raw registry and ordering byte strings.
pub fn CidFamily::from_registry_ordering(
  registry : BytesView,
  ordering : BytesView,
) -> CidFamily {
  if registry == b"Adobe" {
    match ordering {
      b"Japan1" => AdobeJapan1
      b"GB1" => AdobeGB1
      b"CNS1" => AdobeCNS1
      b"Korea1" => AdobeKorea1
      b"Identity" => AdobeIdentity
      _ => Custom(registry=registry.to_owned(), ordering=ordering.to_owned())
    }
  } else {
    Custom(registry=registry.to_owned(), ordering=ordering.to_owned())
  }
}

///|
/// Return the predefined UTF-16 `CMap` that maps Unicode code points to CIDs
/// for this family, if one exists.
pub fn CidFamily::unicode_cmap(self : CidFamily) -> CMapName? {
  match self {
    AdobeJapan1 => Some(UniJisUtf16H)
    AdobeGB1 => Some(UniGbUtf16H)
    AdobeCNS1 => Some(UniCnsUtf16H)
    AdobeKorea1 => Some(UniKsUtf16H)
    AdobeIdentity | Custom(..) => None
  }
}

///|
/// Return the `UCS2` cmap corresponding to the given character collection.
pub fn CidFamily::ucs2_cmap(self : CidFamily) -> CMapName? {
  match self {
    AdobeJapan1 => Some(AdobeJapan1Ucs2)
    AdobeGB1 => Some(AdobeGb1Ucs2)
    AdobeCNS1 => Some(AdobeCns1Ucs2)
    AdobeKorea1 => Some(AdobeKorea1Ucs2)
    AdobeIdentity | Custom(..) => None
  }
}

///|
/// A CID character collection identifying the character set and ordering.
pub(all) struct CharacterCollection {
  /// The registry+ordering family.
  family : CidFamily
  /// The supplement number.
  supplement : Int
} derive(Eq, Debug)

///|
pub impl Show for CharacterCollection with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
/// The writing mode of a cmap.
pub(all) enum WritingMode {
  /// Horizontal writing mode.
  Horizontal
  /// Vertical writing mode.
  Vertical
} derive(Eq, Debug)

///|
pub impl Default for WritingMode with fn default() {
  Horizontal
}

///|
pub impl Show for WritingMode with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}
