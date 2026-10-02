// A [Glyph Definition Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/gdef) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/gdef.rs`.

///|
/// A [glyph class](https://docs.microsoft.com/en-us/typography/opentype/spec/gdef#glyph-class-definition-table).
pub(all) enum GlyphClass {
  Base // = 1
  Ligature // = 2
  Mark // = 3
  Component // = 4
} derive(Eq, Compare, Debug, Hash)

///|
/// A [Glyph Definition Table](https://docs.microsoft.com/en-us/typography/opentype/spec/gdef).
struct GdefTable {
  mut glyph_classes : ClassDefinition?
  mut mark_attach_classes : ClassDefinition?
  mut mark_glyph_coverage_offsets : (BytesView, LazyArray16[Offset32])?
  mut variation_store : ItemVariationStore?
}

///|
pub impl Default for GdefTable with fn default() {
  {
    glyph_classes: None,
    mark_attach_classes: None,
    mark_glyph_coverage_offsets: None,
    variation_store: None,
  }
}

///|
/// Parses a table from raw data.
pub fn GdefTable::parse(data : BytesView) -> GdefTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if !(version == 0x00010000 || version == 0x00010002 || version == 0x00010003) {
      return None
    }
    let glyph_class_def_offset : Offset16? = s.read()
    s.advance(2) // attachListOffset
    s.advance(2) // ligCaretListOffset
    let mark_attach_class_def_offset : Offset16? = s.read()
    let mut mark_glyph_sets_def_offset : Offset16? = None
    if version > 0x00010000 {
      mark_glyph_sets_def_offset = s.read()
    }
    let mut var_store_offset : Offset32? = None
    if version > 0x00010002 {
      var_store_offset = s.read()
    }
    let table : GdefTable = Default::default()
    if glyph_class_def_offset is Some(offset) {
      if slice_from(data, offset.to_usize()) is Some(subdata) {
        table.glyph_classes = ClassDefinition::parse(subdata)
      }
    }
    if mark_attach_class_def_offset is Some(offset) {
      if slice_from(data, offset.to_usize()) is Some(subdata) {
        table.mark_attach_classes = ClassDefinition::parse(subdata)
      }
    }
    if mark_glyph_sets_def_offset is Some(offset) {
      if slice_from(data, offset.to_usize()) is Some(subdata) {
        let s = Stream::new(subdata)
        let format = s.read_u16()
        if format == 1 {
          let count : UInt16? = s.read_opt()
          if count is Some(count) {
            let array : Result[LazyArray16[Offset32], _] = try? s.read_array16(
              count,
            )
            if array is Ok(array) {
              table.mark_glyph_coverage_offsets = Some((subdata, array))
            }
          }
        }
      }
    }
    if var_store_offset is Some(offset) {
      if slice_from(data, offset.to_usize()) is Some(subdata) {
        let s = Stream::new(subdata)
        table.variation_store = ItemVariationStore::parse(s)
      }
    }
    Some(table)
  } catch {
    _ => None
  }
}

///|
/// Checks that face has
/// [Glyph Class Definition Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gdef#glyph-class-definition-table).
pub fn GdefTable::has_glyph_classes(self : GdefTable) -> Bool {
  self.glyph_classes is Some(_)
}

///|
/// Returns glyph's class according to
/// [Glyph Class Definition Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gdef#glyph-class-definition-table).
///
/// Returns `None` when *Glyph Class Definition Table* is not set
/// or glyph class is not set or invalid.
pub fn GdefTable::glyph_class(
  self : GdefTable,
  glyph_id : GlyphId,
) -> GlyphClass? {
  guard self.glyph_classes is Some(classes) else { return None }
  match classes.get(glyph_id) {
    1 => Some(Base)
    2 => Some(Ligature)
    3 => Some(Mark)
    4 => Some(Component)
    _ => None
  }
}

///|
/// Returns glyph's mark attachment class according to
/// [Mark Attachment Class Definition Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gdef#mark-attachment-class-definition-table).
///
/// All glyphs not assigned to a class fall into Class 0.
pub fn GdefTable::glyph_mark_attachment_class(
  self : GdefTable,
  glyph_id : GlyphId,
) -> Class {
  match self.mark_attach_classes {
    Some(def) => def.get(glyph_id)
    None => 0
  }
}

///|
/// Checks that glyph is a mark according to
/// [Mark Glyph Sets Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gdef#mark-glyph-sets-table).
///
/// `set_index` allows checking a specific glyph coverage set.
/// Otherwise all sets will be checked.
pub fn GdefTable::is_mark_glyph(
  self : GdefTable,
  glyph_id : GlyphId,
  set_index : UInt16?,
) -> Bool {
  is_mark_glyph_impl(self, glyph_id, set_index) is Some(_)
}

///|
/// Returns glyph's variation delta at a specified index according to
/// [Item Variation Store Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gdef#item-variation-store-table).
pub fn GdefTable::glyph_variation_delta(
  self : GdefTable,
  outer_index : UInt16,
  inner_index : UInt16,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  match self.variation_store {
    Some(store) => store.parse_delta(outer_index, inner_index, coordinates)
    None => None
  }
}

///|
fn is_mark_glyph_impl(
  table : GdefTable,
  glyph_id : GlyphId,
  set_index : UInt16?,
) -> Unit? {
  guard table.mark_glyph_coverage_offsets is Some((data, offsets)) else {
    return None
  }
  if set_index is Some(set_index) {
    if offsets.get(set_index) is Some(offset) {
      guard slice_from(data, offset.to_usize()) is Some(sub) else {
        return None
      }
      guard Coverage::parse(sub) is Some(table) else { return None }
      if table.contains(glyph_id) {
        return Some(())
      }
    }
  } else {
    for offset in offsets.iter() {
      guard slice_from(data, offset.to_usize()) is Some(sub) else {
        return None
      }
      guard Coverage::parse(sub) is Some(table) else { return None }
      if table.contains(glyph_id) {
        return Some(())
      }
    }
  }
  None
}
