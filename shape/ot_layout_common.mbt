// Port of rustybuzz 0.20.1 `src/hb/ot_layout_common.rs`.

// lookup_flags

///|
const LOOKUP_FLAG_RIGHT_TO_LEFT : Int = 0x0001

///|
// ot_layout_common.rs:10; unused upstream too.
#warnings("-unused_value")
const LOOKUP_FLAG_IGNORE_BASE_GLYPHS : Int = 0x0002

///|
// ot_layout_common.rs:11; unused upstream too.
#warnings("-unused_value")
const LOOKUP_FLAG_IGNORE_LIGATURES : Int = 0x0004

///|
const LOOKUP_FLAG_IGNORE_MARKS : Int = 0x0008

///|
const LOOKUP_FLAG_IGNORE_FLAGS : Int = 0x000E

///|
const LOOKUP_FLAG_USE_MARK_FILTERING_SET : Int = 0x0010

///|
const LOOKUP_FLAG_MARK_ATTACHMENT_TYPE_MASK : Int = 0xFF00

///|
priv struct PositioningTable {
  inner : @otf.LayoutTable
  lookups : Array[PositioningLookup]
}

///|
fn PositioningTable::new(inner : @otf.LayoutTable) -> PositioningTable {
  let lookups = inner.lookups.iter().map(PositioningLookup::parse).to_array()
  { inner, lookups, }
}

///|
/// Collect this coverage table into a set digest.
fn coverage_collect(this : @otf.Coverage, set_digest : SetDigest) -> Unit {
  match this {
    Format1(glyphs~) =>
      for glyph in glyphs.iter() {
        set_digest.add(glyph.0.to_int())
      }
    Format2(records~) =>
      for record in records.iter() {
        set_digest.add_range(record.start.0.to_int(), record.end.0.to_int())
      }
  }
}

///|
priv struct PositioningLookup {
  subtables : Array[@otf.PositioningSubtable]
  set_digest : SetDigest
  props : UInt
}

///|
fn PositioningLookup::parse(lookup : @otf.Lookup) -> PositioningLookup {
  let subtables : Array[@otf.PositioningSubtable] = lookup.subtables
    .iter()
    .to_array()
  let set_digest = SetDigest::new()
  for subtable in subtables {
    coverage_collect(subtable.coverage(), set_digest)
  }
  { subtables, set_digest, props: lookup_props(lookup), }
}

///|
priv struct SubstitutionTable {
  inner : @otf.LayoutTable
  lookups : Array[SubstLookup]
}

///|
fn SubstitutionTable::new(inner : @otf.LayoutTable) -> SubstitutionTable {
  let lookups = inner.lookups.iter().map(SubstLookup::parse).to_array()
  { inner, lookups, }
}

///|
priv struct SubstLookup {
  subtables : Array[@otf.SubstitutionSubtable]
  set_digest : SetDigest
  reverse : Bool
  props : UInt
}

///|
fn SubstLookup::parse(lookup : @otf.Lookup) -> SubstLookup {
  let subtables : Array[@otf.SubstitutionSubtable] = lookup.subtables
    .iter()
    .to_array()
  let set_digest = SetDigest::new()
  let mut reverse = !subtables.is_empty()
  for subtable in subtables {
    coverage_collect(subtable.coverage(), set_digest)
    reverse = reverse && subtable.is_reverse()
  }
  { subtables, set_digest, reverse, props: lookup_props(lookup), }
}

///|
/// lookup_props is a 32-bit integer where the lower 16-bit is LookupFlag and
/// higher 16-bit is mark-filtering-set if the lookup uses one.
/// Not to be confused with glyph_props which is very similar.
fn lookup_props(lookup : @otf.Lookup) -> UInt {
  let mut props = lookup.flags.0.to_uint()
  if lookup.mark_filtering_set is Some(set) {
    props = props | (set.to_uint() << 16)
  }
  props
}
