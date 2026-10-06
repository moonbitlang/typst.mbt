// A [Naming Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/name) implementation.

///|
/// A list of [name ID](https://docs.microsoft.com/en-us/typography/opentype/spec/name#name-ids)'s.
pub let name_id_copyright_notice : UInt16 = 0

///|
pub let name_id_family : UInt16 = 1

///|
pub let name_id_subfamily : UInt16 = 2

///|
pub let name_id_unique_id : UInt16 = 3

///|
pub let name_id_full_name : UInt16 = 4

///|
pub let name_id_version : UInt16 = 5

///|
pub let name_id_post_script_name : UInt16 = 6

///|
pub let name_id_trademark : UInt16 = 7

///|
pub let name_id_manufacturer : UInt16 = 8

///|
pub let name_id_designer : UInt16 = 9

///|
pub let name_id_description : UInt16 = 10

///|
pub let name_id_vendor_url : UInt16 = 11

///|
pub let name_id_designer_url : UInt16 = 12

///|
pub let name_id_license : UInt16 = 13

///|
pub let name_id_license_url : UInt16 = 14

///|
pub let name_id_typographic_family : UInt16 = 16

///|
pub let name_id_typographic_subfamily : UInt16 = 17

///|
pub let name_id_compatible_full : UInt16 = 18

///|
pub let name_id_sample_text : UInt16 = 19

///|
pub let name_id_post_script_cid : UInt16 = 20

///|
pub let name_id_wws_family : UInt16 = 21

///|
pub let name_id_wws_subfamily : UInt16 = 22

///|
pub let name_id_light_background_palette : UInt16 = 23

///|
pub let name_id_dark_background_palette : UInt16 = 24

///|
pub let name_id_variations_post_script_name_prefix : UInt16 = 25

///|
/// A [platform ID](https://docs.microsoft.com/en-us/typography/opentype/spec/name#platform-ids).
pub(all) enum PlatformId {
  Unicode
  Macintosh
  Iso
  Windows
  Custom
} derive(Eq, Debug)

///|
pub impl FromData for PlatformId with fn size() {
  2
}

///|
pub impl FromData for PlatformId with fn parse(data) {
  let n : UInt16 = FromData::parse(data)
  match n {
    0 => Unicode
    1 => Macintosh
    2 => Iso
    3 => Windows
    4 => Custom
    _ => raise Malformed
  }
}

///|
fn is_unicode_encoding(platform_id : PlatformId, encoding_id : UInt16) -> Bool {
  // https://docs.microsoft.com/en-us/typography/opentype/spec/name#windows-encoding-ids
  let windows_symbol_encoding_id : UInt16 = 0
  let windows_unicode_bmp_encoding_id : UInt16 = 1
  match platform_id {
    Unicode => true
    Windows =>
      encoding_id == windows_symbol_encoding_id ||
      encoding_id == windows_unicode_bmp_encoding_id
    _ => false
  }
}

///|
priv struct NameRecord {
  platform_id : PlatformId
  encoding_id : UInt16
  language_id : UInt16
  name_id : UInt16
  length : UInt16
  offset : Offset16
}

///|
impl FromData for NameRecord with fn size() {
  12
}

///|
impl FromData for NameRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    platform_id: s.read(),
    encoding_id: s.read(),
    language_id: s.read(),
    name_id: s.read(),
    length: s.read(),
    offset: s.read(),
  }
}

///|
/// A [Name Record](https://docs.microsoft.com/en-us/typography/opentype/spec/name#name-records).
pub(all) struct Name {
  /// A platform ID.
  platform_id : PlatformId
  /// A platform-specific encoding ID.
  encoding_id : UInt16
  /// A language ID.
  language_id : UInt16
  /// A [Name ID](https://docs.microsoft.com/en-us/typography/opentype/spec/name#name-ids).
  name_id : UInt16
  /// A raw name data.
  ///
  /// Can be in any encoding. Can be empty.
  name : BytesView
}

///|
/// Returns the Name's data as a UTF-8 string.
///
/// Only Unicode names are supported. And since they are stored as UTF-16BE,
/// we can't return `&str` and have to allocate a `String`.
///
/// Supports:
/// - Unicode Platform ID
/// - Windows Platform ID + Symbol
/// - Windows Platform ID + Unicode BMP
pub fn Name::to_string(self : Name) -> String? {
  if self.is_unicode() {
    self.name_from_utf16_be()
  } else {
    None
  }
}

///|
/// Checks that the current Name data has a Unicode encoding.
pub fn Name::is_unicode(self : Name) -> Bool {
  is_unicode_encoding(self.platform_id, self.encoding_id)
}

///|
fn Name::name_from_utf16_be(self : Name) -> String? {
  let units : LazyArray16[UInt16] = LazyArray16::new(self.name)
  let buf = StringBuilder()
  let n = units.len().to_int()
  let mut i = 0
  while i < n {
    let c = units.get(i.to_uint16()).unwrap().to_int()
    if c >= 0xD800 && c <= 0xDBFF {
      // A high surrogate must be followed by a low surrogate.
      if i + 1 >= n {
        return None
      }
      let d = units.get((i + 1).to_uint16()).unwrap().to_int()
      if !(d >= 0xDC00 && d <= 0xDFFF) {
        return None
      }
      buf.write_char(
        (0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00)).unsafe_to_char(),
      )
      i += 2
    } else if c >= 0xDC00 && c <= 0xDFFF {
      return None
    } else {
      buf.write_char(c.unsafe_to_char())
      i += 1
    }
  }
  Some(buf.to_string())
}

///|
/// Returns a Name language.
pub fn Name::language(self : Name) -> Language {
  if self.platform_id == Windows {
    Language::windows_language(self.language_id)
  } else if self.platform_id == Macintosh &&
    self.encoding_id == 0 &&
    self.language_id == 0 {
    English_UnitedStates
  } else {
    Unknown
  }
}

///|
/// A list of face names.
struct Names {
  records : LazyArray16[NameRecord]
  storage : BytesView
}

///|
pub impl Default for Names with fn default() {
  { records: LazyArray16::default(), storage: empty_data, }
}

///|
pub extend Names with Default::{default}

///|
/// Returns a name at index.
pub fn Names::get(self : Names, index : UInt16) -> Name? {
  guard self.records.get(index) is Some(record) else { return None }
  let name_start = record.offset.to_usize()
  let name_end = name_start + record.length.to_int()
  guard slice_get(self.storage, name_start, name_end) is Some(name) else {
    return None
  }
  Some({
    platform_id: record.platform_id,
    encoding_id: record.encoding_id,
    language_id: record.language_id,
    name_id: record.name_id,
    name,
  })
}

///|
/// Returns a number of name records.
pub fn Names::len(self : Names) -> UInt16 {
  self.records.len()
}

///|
/// Checks if there are any name records.
pub fn Names::is_empty(self : Names) -> Bool {
  self.records.is_empty()
}

///|
/// An iterator over face names (stops at the first unparsable name, like
/// upstream).
pub fn Names::iter(self : Names) -> Iter[Name] {
  let len = self.len()
  let mut index : UInt16 = 0
  Iter::new(fn() {
    if index < len {
      index += 1
      self.get(index - 1)
    } else {
      None
    }
  })
}

///|
/// A [Naming Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/name).
pub struct NameTable {
  /// A list of names.
  names : Names
}

///|
pub impl Default for NameTable with fn default() {
  { names: Names::default(), }
}

///|
pub extend NameTable with Default::{default}

///|
/// Parses a table from raw data.
pub fn NameTable::parse(data : BytesView) -> NameTable? {
  // https://docs.microsoft.com/en-us/typography/opentype/spec/name#naming-table-format-1
  let lang_tag_record_size : UInt16 = 4
  let s = Stream::new(data)
  try {
    let version = s.read_u16()
    let count = s.read_u16()
    let storage_offset = (s.read() : Offset16).to_usize()
    if version == 0 {
      // Do nothing.
    } else if version == 1 {
      let lang_tag_count = s.read_u16()
      let lang_tag_len = req(
        u16_checked_mul(lang_tag_count, lang_tag_record_size),
      )
      s.advance(lang_tag_len.to_int()) // langTagRecords
    } else {
      // Unsupported version.
      return None
    }
    let records = s.read_array16(count)
    if s.offset() < storage_offset {
      s.advance(storage_offset - s.offset())
    }
    let storage = s.tail_r()
    Some({ names: { records, storage, }, })
  } catch {
    _ => None
  }
}
