// Port of `ttf-parser` 0.25.1 `src/ggg/feature_variations.rs`.

///|
/// A [Feature Variations Table](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#featurevariations-table).
struct FeatureVariations {
  data : BytesView
  records : LazyArray32[FeatureVariationRecord]
}

///|
fn FeatureVariations::parse(data : BytesView) -> FeatureVariations? {
  try {
    let s = Stream::new(data)
    let major_version = s.read_u16()
    s.advance(2) // minor version
    if major_version != 1 {
      return None
    }
    let count = s.read_u32()
    let records = s.read_array32(count)
    Some({ data, records, })
  } catch {
    _ => None
  }
}

///|
/// Returns a [`VariationIndex`] for variation coordinates.
pub fn FeatureVariations::find_index(
  self : FeatureVariations,
  coords : ArrayView[NormalizedCoordinate],
) -> VariationIndex? {
  for i = 0U; i < self.records.len(); i = i + 1 {
    guard self.records.get(i) is Some(record) else { return None }
    let offset = record.conditions.to_usize()
    guard slice_from(self.data, offset) is Some(sub) else { return None }
    guard ConditionSet::parse(sub) is Some(set) else { return None }
    if set.evaluate(coords) {
      return Some(i)
    }
  }
  None
}

///|
/// Returns a [`Feature`] at specified indices.
pub fn FeatureVariations::find_substitute(
  self : FeatureVariations,
  feature_index : FeatureIndex,
  variation_index : VariationIndex,
) -> Feature? {
  guard self.records.get(variation_index) is Some(record) else { return None }
  let offset = record.substitutions.to_usize()
  guard slice_from(self.data, offset) is Some(sub) else { return None }
  guard FeatureTableSubstitution::parse(sub) is Some(subst) else { return None }
  subst.find_substitute(feature_index)
}

///|
priv struct FeatureVariationRecord {
  conditions : Offset32
  substitutions : Offset32
}

///|
impl FromData for FeatureVariationRecord with fn size() {
  8
}

///|
impl FromData for FeatureVariationRecord with fn parse(data) {
  let s = Stream::new(data)
  { conditions: s.read(), substitutions: s.read(), }
}

///|
priv struct ConditionSet {
  data : BytesView
  conditions : LazyArray16[Offset32]
}

///|
fn ConditionSet::parse(data : BytesView) -> ConditionSet? {
  try {
    let s = Stream::new(data)
    let count = s.read_u16()
    let conditions = s.read_array16(count)
    Some({ data, conditions, })
  } catch {
    _ => None
  }
}

///|
fn ConditionSet::evaluate(
  self : ConditionSet,
  coords : ArrayView[NormalizedCoordinate],
) -> Bool {
  self.conditions
  .iter()
  .all(offset => {
    match slice_from(self.data, offset.to_usize()) {
      Some(data) =>
        match Condition::parse(data) {
          Some(c) => c.evaluate(coords)
          None => false
        }
      None => false
    }
  })
}

///|
priv enum Condition {
  Format1(
    axis_index~ : UInt16,
    filter_range_min~ : Int16,
    filter_range_max~ : Int16
  )
}

///|
fn Condition::parse(data : BytesView) -> Condition? {
  try {
    let s = Stream::new(data)
    let format = s.read_u16()
    match format {
      1 => {
        let axis_index = s.read_u16()
        let filter_range_min = s.read_i16()
        let filter_range_max = s.read_i16()
        Some(Format1(axis_index~, filter_range_min~, filter_range_max~))
      }
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
fn Condition::evaluate(
  self : Condition,
  coords : ArrayView[NormalizedCoordinate],
) -> Bool {
  let Format1(axis_index~, filter_range_min~, filter_range_max~) = self
  let i = axis_index.to_int()
  let coord : Int16 = if i < coords.length() { coords[i].get() } else { 0 }
  filter_range_min <= coord && coord <= filter_range_max
}

///|
priv struct FeatureTableSubstitution {
  data : BytesView
  records : LazyArray16[FeatureTableSubstitutionRecord]
}

///|
fn FeatureTableSubstitution::parse(
  data : BytesView,
) -> FeatureTableSubstitution? {
  try {
    let s = Stream::new(data)
    let major_version = s.read_u16()
    s.advance(2) // minor version
    if major_version != 1 {
      return None
    }
    let count = s.read_u16()
    let records = s.read_array16(count)
    Some({ data, records, })
  } catch {
    _ => None
  }
}

///|
fn FeatureTableSubstitution::find_substitute(
  self : FeatureTableSubstitution,
  feature_index : FeatureIndex,
) -> Feature? {
  for record in self.records.iter() {
    if record.feature_index == feature_index {
      let offset = record.feature.to_usize()
      guard slice_from(self.data, offset) is Some(data) else { return None }
      // TODO: set tag
      return try
        (RecordListItem::parse(Tag::from_str("DFLT"), data) : Feature)
      catch {
        _ => None
      } noraise {
        v => Some(v)
      }
    }
  }
  None
}

///|
priv struct FeatureTableSubstitutionRecord {
  feature_index : FeatureIndex
  feature : Offset32
}

///|
impl FromData for FeatureTableSubstitutionRecord with fn size() {
  6
}

///|
impl FromData for FeatureTableSubstitutionRecord with fn parse(data) {
  let s = Stream::new(data)
  { feature_index: s.read(), feature: s.read(), }
}
