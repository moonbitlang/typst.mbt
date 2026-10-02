// An [SVG Table](https://docs.microsoft.com/en-us/typography/opentype/spec/svg) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/svg.rs`.

///|
/// An [SVG documents](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/svg#svg-document-list).
pub(all) struct SvgDocument {
  /// The SVG document data.
  ///
  /// Can be stored as a string or as a gzip compressed data, aka SVGZ.
  data : BytesView
  /// The first glyph ID for the range covered by this record.
  start_glyph_id : GlyphId
  /// The last glyph ID, *inclusive*, for the range covered by this record.
  end_glyph_id : GlyphId
}

///|
/// Returns the glyphs range (inclusive) as `(start, end)`.
pub fn SvgDocument::glyphs_range(self : SvgDocument) -> (GlyphId, GlyphId) {
  (self.start_glyph_id, self.end_glyph_id)
}

///|
priv struct SvgDocumentRecord {
  start_glyph_id : GlyphId
  end_glyph_id : GlyphId
  svg_doc_offset : Offset32?
  svg_doc_length : UInt
}

///|
fn SvgDocumentRecord::glyphs_range_contains(
  self : SvgDocumentRecord,
  glyph_id : GlyphId,
) -> Bool {
  self.start_glyph_id <= glyph_id && glyph_id <= self.end_glyph_id
}

///|
impl FromData for SvgDocumentRecord with fn size() {
  12
}

///|
impl FromData for SvgDocumentRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    start_glyph_id: s.read(),
    end_glyph_id: s.read(),
    svg_doc_offset: s.read(),
    svg_doc_length: s.read(),
  }
}

///|
/// A list of [SVG documents](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/svg#svg-document-list).
struct SvgDocumentsList {
  data : BytesView
  records : LazyArray16[SvgDocumentRecord]
}

///|
/// Returns SVG document data at index.
///
/// `index` is not a GlyphId. You should use [`find()`](SvgDocumentsList::find) instead.
pub fn SvgDocumentsList::get(
  self : SvgDocumentsList,
  index : UInt16,
) -> SvgDocument? {
  guard self.records.get(index) is Some(record) else { return None }
  guard record.svg_doc_offset is Some(offset) else { return None }
  let offset = offset.to_usize()
  let end = offset.to_int64() +
    record.svg_doc_length.to_uint64().reinterpret_as_int64()
  if end > 0x7fffffffL {
    return None
  }
  slice_get(self.data, offset, end.to_int()).map(data => {
    data,
    start_glyph_id: record.start_glyph_id,
    end_glyph_id: record.end_glyph_id,
  })
}

///|
/// Returns a SVG document data by glyph ID.
pub fn SvgDocumentsList::find(
  self : SvgDocumentsList,
  glyph_id : GlyphId,
) -> SvgDocument? {
  let mut index : UInt16 = 0
  for v in self.records.iter() {
    if v.glyphs_range_contains(glyph_id) {
      return self.get(index)
    }
    index += 1
  }
  None
}

///|
/// Returns the number of SVG documents in the list.
pub fn SvgDocumentsList::len(self : SvgDocumentsList) -> UInt16 {
  self.records.len()
}

///|
/// Checks if the list is empty.
pub fn SvgDocumentsList::is_empty(self : SvgDocumentsList) -> Bool {
  self.records.is_empty()
}

///|
/// Returns an iterator over the documents.
pub fn SvgDocumentsList::into_iter(
  self : SvgDocumentsList,
) -> SvgDocumentsListIter {
  { list: self, index: 0, }
}

///|
/// Iterates over the documents.
pub fn SvgDocumentsList::iter(self : SvgDocumentsList) -> Iter[SvgDocument] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over [`SvgDocumentsList`] values.
struct SvgDocumentsListIter {
  list : SvgDocumentsList
  mut index : UInt16
}

///|
/// Copies the iterator (Rust's `Clone`/`Copy`).
pub fn SvgDocumentsListIter::copy(
  self : SvgDocumentsListIter,
) -> SvgDocumentsListIter {
  { list: self.list, index: self.index, }
}

///|
/// Returns the next document.
pub fn SvgDocumentsListIter::next(self : SvgDocumentsListIter) -> SvgDocument? {
  if self.index < self.list.len() {
    self.index += 1
    self.list.get(self.index - 1)
  } else {
    None
  }
}

///|
/// Returns the number of remaining documents.
pub fn SvgDocumentsListIter::count(self : SvgDocumentsListIter) -> Int {
  let len = self.list.len()
  if len > self.index {
    (len - self.index).to_int()
  } else {
    0
  }
}

///|
/// An [SVG Table](https://docs.microsoft.com/en-us/typography/opentype/spec/svg).
pub(all) struct SvgTable {
  /// A list of SVG documents.
  documents : SvgDocumentsList
}

///|
/// Parses a table from raw data.
pub fn SvgTable::parse(data : BytesView) -> SvgTable? {
  let s = Stream::new(data)
  try {
    s.advance(2) // version
    let doc_list_offset = req((s.read() : Offset32?))
    let s = Stream::new_at_r(data, doc_list_offset.to_usize())
    let count = s.read_u16()
    let records = s.read_array16(count)
    Some({ documents: { data: data[doc_list_offset.to_usize():], records, }, })
  } catch {
    _ => None
  }
}
