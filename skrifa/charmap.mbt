// Port of skrifa 0.42.1 `src/charmap.rs` (codepoint mapping; variation
// sequences are not supported).

///|
/// Mapping of characters to nominal glyph identifiers.
pub struct Charmap {
  priv codepoint_subtable : CodepointSubtable?
}

///|
priv struct CodepointSubtable {
  subtable : @read_fonts.CmapSubtable
  is_symbol : Bool
}

///|
/// Creates a new character map from the given font.
pub fn Charmap::new(font : FontRef) -> Charmap {
  guard ok(() => font.cmap()) is Some(cmap) else {
    return { codepoint_subtable: None, }
  }
  // MappingSelection::new
  // ENCODING_MS_SYMBOL = 0, ENCODING_MS_UNICODE_CS = 1,
  // ENCODING_APPLE_ID_UNICODE_32 = 4, ENCODING_APPLE_ID_VARIANT_SELECTOR = 5,
  // ENCODING_MS_ID_UCS_4 = 10
  // mapping kinds: None = 0, UnicodeBmp = 1, UnicodeFull = 2, Symbol = 3
  let mut mapping_kind = 0
  let mut selected : CodepointSubtable? = None
  let records = cmap.encoding_records()
  let supported = fn(
    record : @read_fonts.EncodingRecord,
  ) -> @read_fonts.CmapSubtable? {
    match res(() => record.subtable(cmap.offset_data())) {
      Ok(Format4(_) as s) | Ok(Format12(_) as s) => Some(s)
      _ => None
    }
  }
  // This generally follows the same strategy as FreeType, searching the
  // encoding records in reverse and prioritizing UCS-4 subtables over
  // UCS-2. The exception is that we prefer a symbol subtable over all
  // others which matches the behavior of HarfBuzz.
  for i = records.length() - 1; i >= 0; i = i - 1 {
    let record = records[i]
    let kind = match (record.platform_id(), record.encoding_id()) {
      // Unicode variation sequences
      (Unicode, 5) => continue
      // Symbol
      (Windows, 0) => 3
      // Unicode full repertoire
      (Windows, 10) | (Unicode, 4) => 2
      // Unicode BMP only
      (ISO, _) | (Unicode, _) | (Windows, 1) => 1
      _ => continue
    }
    if supported(record) is Some(subtable) {
      if kind > mapping_kind {
        mapping_kind = kind
        selected = Some({ subtable, is_symbol: kind == 3, })
      }
    }
  }
  { codepoint_subtable: selected, }
}

///|
/// Returns true if a suitable Unicode character mapping is available.
pub fn Charmap::has_map(self : Charmap) -> Bool {
  self.codepoint_subtable is Some(_)
}

///|
/// Returns true if a symbol mapping was selected.
pub fn Charmap::is_symbol(self : Charmap) -> Bool {
  match self.codepoint_subtable {
    Some(s) => s.is_symbol
    None => false
  }
}

///|
/// Maps a character to a nominal glyph identifier.
///
/// Returns `None` if a mapping does not exist.
pub fn Charmap::map(self : Charmap, ch : UInt) -> GlyphId? {
  guard self.codepoint_subtable is Some(subtable) else { return None }
  match map_impl(subtable, ch) {
    Some(g) => Some(g)
    None =>
      if subtable.is_symbol && ch <= 0x00FFU {
        // For symbol-encoded OpenType fonts, we duplicate the
        // U+F000..F0FF range at U+0000..U+00FF.
        map_impl(subtable, ch + 0xF000U)
      } else {
        None
      }
  }
}

///|
/// Maps a character to a nominal glyph identifier.
pub fn Charmap::map_char(self : Charmap, ch : Char) -> GlyphId? {
  self.map(ch.to_int().reinterpret_as_uint())
}

///|
fn map_impl(subtable : CodepointSubtable, codepoint : UInt) -> GlyphId? {
  match subtable.subtable.map_codepoint(codepoint) {
    Some(gid) if gid != GlyphId::notdef() => Some(gid)
    _ => None
  }
}
