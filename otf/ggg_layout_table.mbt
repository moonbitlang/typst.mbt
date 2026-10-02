// Port of `ttf-parser` 0.25.1 `src/ggg/layout_table.rs`.

///|
/// A [Layout Table](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#table-organization).
pub(all) struct LayoutTable {
  /// A list of all supported scripts.
  scripts : ScriptList
  /// A list of all supported features.
  features : FeatureList
  /// A list of all lookups.
  lookups : LookupList
  /// Used to substitute an alternate set of lookup tables
  /// to use for any given feature under specified conditions.
  variations : FeatureVariations?
}

///|
/// Parses a layout table (`GSUB` or `GPOS`) from raw data.
pub fn LayoutTable::parse(data : BytesView) -> LayoutTable? {
  try {
    let s = Stream::new(data)
    let major_version = s.read_u16()
    let minor_version = s.read_u16()
    if major_version != 1 {
      return None
    }
    let scripts = RecordList::parse(s.read_at_offset16(data))
    let features = RecordList::parse(s.read_at_offset16(data))
    let lookups = LazyOffsetArray16::parse(s.read_at_offset16(data))
    let mut variations_offset : Offset32? = None
    if minor_version >= 1 {
      variations_offset = s.read()
    }
    let variations = match variations_offset {
      Some(offset) =>
        match slice_from(data, offset.to_usize()) {
          Some(data) => FeatureVariations::parse(data)
          None => None
        }
      None => None
    }
    Some({ scripts, features, lookups, variations, })
  } catch {
    _ => None
  }
}

///|
/// An index in [`ScriptList`].
pub type ScriptIndex = UInt16

///|
/// An index in [`LanguageSystemList`].
pub type LanguageIndex = UInt16

///|
/// An index in [`FeatureList`].
pub type FeatureIndex = UInt16

///|
/// An index in [`LookupList`].
pub type LookupIndex = UInt16

///|
/// An index in [`FeatureVariations`].
pub type VariationIndex = UInt

///|
/// A trait to parse item in [`RecordList`].
///
/// Internal use only.
pub(open) trait RecordListItem {
  /// Parses raw data.
  fn parse(Tag, BytesView) -> Self raise Malformed
}

///|
/// A data storage used by [`ScriptList`], [`LanguageSystemList`] and [`FeatureList`] data types.
struct RecordList[T] {
  data : BytesView
  records : LazyArray16[TagRecord]
}

///|
fn[T] RecordList::parse(data : BytesView) -> RecordList[T] raise Malformed {
  let s = Stream::new(data)
  let count = s.read_u16()
  let records = s.read_array16(count)
  { data, records, }
}

///|
/// Returns a number of items in the RecordList.
pub fn[T] RecordList::len(self : RecordList[T]) -> UInt16 {
  self.records.len()
}

///|
/// Checks that RecordList is empty.
pub fn[T] RecordList::is_empty(self : RecordList[T]) -> Bool {
  self.records.is_empty()
}

///|
/// Returns RecordList value by index.
pub fn[T : RecordListItem] RecordList::get(
  self : RecordList[T],
  index : UInt16,
) -> T? {
  guard self.records.get(index) is Some(record) else { return None }
  guard slice_from(self.data, record.offset.to_usize()) is Some(data) else {
    return None
  }
  try T::parse(record.tag, data) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns RecordList value by [`Tag`].
pub fn[T : RecordListItem] RecordList::find(
  self : RecordList[T],
  tag : Tag,
) -> T? {
  guard self.records.binary_search_by(record => {
      Compare::compare(record.tag, tag)
    })
    is Some((_, record)) else {
    return None
  }
  guard slice_from(self.data, record.offset.to_usize()) is Some(data) else {
    return None
  }
  try T::parse(record.tag, data) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns RecordList value index by [`Tag`].
pub fn[T] RecordList::index(self : RecordList[T], tag : Tag) -> UInt16? {
  self.records
  .binary_search_by(record => Compare::compare(record.tag, tag))
  .map(p => p.0)
}

///|
/// Creates an iterator over the values.
pub fn[T] RecordList::into_iter(self : RecordList[T]) -> RecordListIter[T] {
  { list: self, index: 0, }
}

///|
/// Iterates over the values (stops at the first unparsable value).
pub fn[T : RecordListItem] RecordList::iter(self : RecordList[T]) -> Iter[T] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over [`RecordList`] values.
struct RecordListIter[T] {
  list : RecordList[T]
  mut index : UInt16
}

///|
/// Returns the next value.
pub fn[T : RecordListItem] RecordListIter::next(self : RecordListIter[T]) -> T? {
  if self.index < self.list.len() {
    self.index += 1
    self.list.get(self.index - 1)
  } else {
    None
  }
}

///|
/// A list of [`Script`] records.
pub type ScriptList = RecordList[Script]

///|
/// A list of [`LanguageSystem`] records.
pub type LanguageSystemList = RecordList[LanguageSystem]

///|
/// A list of [`Feature`] records.
pub type FeatureList = RecordList[Feature]

///|
priv struct TagRecord {
  tag : Tag
  offset : Offset16
}

///|
impl FromData for TagRecord with fn size() {
  6
}

///|
impl FromData for TagRecord with fn parse(data) {
  let s = Stream::new(data)
  { tag: s.read(), offset: s.read(), }
}

///|
/// A [Script Table](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#script-table-and-language-system-record).
pub(all) struct Script {
  /// Script tag.
  tag : Tag
  /// Default language.
  default_language : LanguageSystem?
  /// List of supported languages, excluding the default one. Listed alphabetically.
  languages : LanguageSystemList
}

///|
pub impl RecordListItem for Script with fn parse(tag, data) {
  let s = Stream::new(data)
  let mut default_language = None
  let offset : Offset16? = s.read()
  if offset is Some(offset) {
    let sub = slice_from_r(data, offset.to_usize())
    default_language = try
      (RecordListItem::parse(Tag::from_str("dflt"), sub) : LanguageSystem)
    catch {
      _ => None
    } noraise {
      v => Some(v)
    }
  }
  let languages : LanguageSystemList = RecordList::parse(s.tail_r())
  // Offsets are relative to this table.
  let languages : LanguageSystemList = { data, records: languages.records, }
  { tag, default_language, languages, }
}

///|
/// A [Language System Table](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#language-system-table).
pub(all) struct LanguageSystem {
  /// Language tag.
  tag : Tag
  /// Index of a feature required for this language system.
  required_feature : FeatureIndex?
  /// Array of indices into the FeatureList, in arbitrary order.
  feature_indices : LazyArray16[FeatureIndex]
}

///|
pub impl RecordListItem for LanguageSystem with fn parse(tag, data) {
  let s = Stream::new(data)
  let _lookup_order : Offset16 = s.read() // Unsupported.
  let required_feature = match s.read_u16() {
    0xFFFF => None
    v => Some(v)
  }
  let count = s.read_u16()
  let feature_indices = s.read_array16(count)
  { tag, required_feature, feature_indices, }
}

///|
/// A [Feature](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#feature-table).
pub(all) struct Feature {
  tag : Tag
  lookup_indices : LazyArray16[LookupIndex]
}

///|
pub impl RecordListItem for Feature with fn parse(tag, data) {
  let s = Stream::new(data)
  let _params_offset : Offset16 = s.read() // Unsupported.
  let count = s.read_u16()
  let lookup_indices = s.read_array16(count)
  { tag, lookup_indices, }
}
