// A [Feature Name Table](
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6feat.html) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/feat.rs`.

///|
priv struct FeatureNameRecord {
  feature : UInt16
  setting_table_records_count : UInt16
  // Offset from the beginning of the table.
  setting_table_offset : Offset32
  flags : Byte
  default_setting_index : Byte
  name_index : UInt16
}

///|
impl FromData for FeatureNameRecord with fn size() {
  12
}

///|
impl FromData for FeatureNameRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    feature: s.read(),
    setting_table_records_count: s.read(),
    setting_table_offset: s.read(),
    flags: s.read(),
    default_setting_index: s.read(),
    name_index: s.read(),
  }
}

///|
/// A setting name.
pub(all) struct SettingName {
  /// The setting.
  setting : UInt16
  /// The `name` table index for the feature's name in a 256..32768 range.
  name_index : UInt16
} derive(Debug)

///|
pub impl FromData for SettingName with fn size() {
  4
}

///|
pub impl FromData for SettingName with fn parse(data) {
  let s = Stream::new(data)
  { setting: s.read(), name_index: s.read(), }
}

///|
/// A feature names.
pub(all) struct FeatureName {
  /// The feature's ID.
  feature : UInt16
  /// The feature's setting names.
  setting_names : LazyArray16[SettingName]
  /// The index of the default setting in the `setting_names`.
  default_setting_index : Byte
  /// The feature's exclusive settings. If set, the feature settings are mutually exclusive.
  exclusive : Bool
  /// The `name` table index for the feature's name in a 256..32768 range.
  name_index : UInt16
}

///|
/// A list of feature names.
struct FeatureNames {
  data : BytesView
  records : LazyArray16[FeatureNameRecord]
}

///|
/// Returns a feature name at an index.
pub fn FeatureNames::get(self : FeatureNames, index : UInt16) -> FeatureName? {
  guard self.records.get(index) is Some(record) else { return None }
  guard slice_from(self.data, record.setting_table_offset.to_usize())
    is Some(data) else {
    return None
  }
  let s = Stream::new(data)
  try {
    let setting_names = s.read_array16(record.setting_table_records_count)
    Some({
      feature: record.feature,
      setting_names,
      default_setting_index: if (record.flags & 0x40) != 0 {
        record.default_setting_index
      } else {
        0
      },
      exclusive: (record.flags & 0x80) != 0,
      name_index: record.name_index,
    })
  } catch {
    _ => None
  }
}

///|
/// Finds a feature name by ID.
pub fn FeatureNames::find(
  self : FeatureNames,
  feature : UInt16,
) -> FeatureName? {
  guard self.records.binary_search_by(name => name.feature.compare(feature))
    is Some((index, _)) else {
    return None
  }
  self.get(index)
}

///|
/// Returns the number of feature names.
pub fn FeatureNames::len(self : FeatureNames) -> UInt16 {
  self.records.len()
}

///|
/// Checks if there are any feature names.
pub fn FeatureNames::is_empty(self : FeatureNames) -> Bool {
  self.records.is_empty()
}

///|
/// Returns an iterator over the feature names.
pub fn FeatureNames::into_iter(self : FeatureNames) -> FeatureNamesIter {
  { names: self, index: 0, }
}

///|
/// Iterates over the feature names.
pub fn FeatureNames::iter(self : FeatureNames) -> Iter[FeatureName] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over [`FeatureNames`].
struct FeatureNamesIter {
  names : FeatureNames
  mut index : UInt16
}

///|
/// Returns the next feature name.
pub fn FeatureNamesIter::next(self : FeatureNamesIter) -> FeatureName? {
  if self.index < self.names.len() {
    self.index += 1
    self.names.get(self.index - 1)
  } else {
    None
  }
}

///|
/// A [Feature Name Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6feat.html).
pub(all) struct FeatTable {
  /// A list of feature names. Sorted by `FeatureName.feature`.
  names : FeatureNames
}

///|
/// Parses a table from raw data.
pub fn FeatTable::parse(data : BytesView) -> FeatTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let count = s.read_u16()
    s.advance_checked(6) // reserved
    let records = s.read_array16(count)
    Some({ names: { data, records, }, })
  } catch {
    _ => None
  }
}
