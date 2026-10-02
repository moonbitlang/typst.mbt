// Port of `ttf-parser` 0.25.1 `src/ggg/lookup.rs`.

///|
/// A list of [`Lookup`] values.
pub type LookupList = LazyOffsetArray16[Lookup]

///|
/// A [Lookup Table](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#lookup-table).
pub(all) struct Lookup {
  /// Lookup qualifiers.
  flags : LookupFlags
  /// Available subtables.
  subtables : LookupSubtables
  /// Index into GDEF mark glyph sets structure.
  mark_filtering_set : UInt16?
}

///|
pub impl FromSlice for Lookup with fn parse_slice(data) {
  let s = Stream::new(data)
  let kind = s.read_u16()
  let flags : LookupFlags = s.read()
  let count = s.read_u16()
  let offsets = s.read_array16(count)
  let mut mark_filtering_set : UInt16? = None
  if flags.use_mark_filtering_set() {
    mark_filtering_set = Some(s.read_u16())
  }
  { flags, subtables: { kind, data, offsets, }, mark_filtering_set, }
}

///|
/// A trait for parsing Lookup subtables.
///
/// Internal use only.
pub(open) trait LookupSubtable {
  /// Parses raw data.
  fn parse(BytesView, UInt16) -> Self raise Malformed
}

///|
/// A list of lookup subtables.
struct LookupSubtables {
  kind : UInt16
  data : BytesView
  offsets : LazyArray16[Offset16]
}

///|
/// Returns a number of items in the LookupSubtables.
pub fn LookupSubtables::len(self : LookupSubtables) -> UInt16 {
  self.offsets.len()
}

///|
/// Checks if there are any items.
pub fn LookupSubtables::is_empty(self : LookupSubtables) -> Bool {
  self.offsets.is_empty()
}

///|
/// Parses a subtable at index.
///
/// Accepts either `PositioningSubtable` or `SubstitutionSubtable`.
///
/// Technically, we can enforce it at compile time, but it makes code too convoluted.
pub fn[T : LookupSubtable] LookupSubtables::get(
  self : LookupSubtables,
  index : UInt16,
) -> T? {
  guard self.offsets.get(index) is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(data) else {
    return None
  }
  try T::parse(data, self.kind) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Creates an iterator over subtables.
pub fn[T] LookupSubtables::into_iter(
  self : LookupSubtables,
) -> LookupSubtablesIter[T] {
  { data: self, index: 0, }
}

///|
/// Iterates over subtables (stops at the first unparsable subtable).
pub fn[T : LookupSubtable] LookupSubtables::iter(
  self : LookupSubtables,
) -> Iter[T] {
  let it : LookupSubtablesIter[T] = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over lookup subtables.
struct LookupSubtablesIter[T] {
  data : LookupSubtables
  mut index : UInt16
}

///|
/// Returns the next subtable.
pub fn[T : LookupSubtable] LookupSubtablesIter::next(
  self : LookupSubtablesIter[T],
) -> T? {
  if self.index < self.data.len() {
    self.index += 1
    self.data.get(self.index - 1)
  } else {
    None
  }
}

///|
/// Lookup table flags.
pub(all) struct LookupFlags(UInt16) derive(Eq, Debug)

///|
pub fn LookupFlags::right_to_left(self : LookupFlags) -> Bool {
  (self.0 & 0x0001) != 0
}

///|
pub fn LookupFlags::ignore_base_glyphs(self : LookupFlags) -> Bool {
  (self.0 & 0x0002) != 0
}

///|
pub fn LookupFlags::ignore_ligatures(self : LookupFlags) -> Bool {
  (self.0 & 0x0004) != 0
}

///|
pub fn LookupFlags::ignore_marks(self : LookupFlags) -> Bool {
  (self.0 & 0x0008) != 0
}

///|
pub fn LookupFlags::ignore_flags(self : LookupFlags) -> Bool {
  (self.0 & 0x000E) != 0
}

///|
pub fn LookupFlags::use_mark_filtering_set(self : LookupFlags) -> Bool {
  (self.0 & 0x0010) != 0
}

///|
pub fn LookupFlags::mark_attachment_type(self : LookupFlags) -> Byte {
  ((self.0 & 0xFF00) >> 8).to_byte()
}

///|
pub impl FromData for LookupFlags with fn size() {
  2
}

///|
pub impl FromData for LookupFlags with fn parse(data) {
  LookupFlags(FromData::parse(data))
}

///|
fn[T] parse_extension_lookup(
  data : BytesView,
  parse : (BytesView, UInt16) -> T raise Malformed,
) -> T raise Malformed {
  let s = Stream::new(data)
  let format = s.read_u16()
  match format {
    1 => {
      let kind = s.read_u16()
      let offset = (s.read() : Offset32).to_usize()
      parse(slice_from_r(data, offset), kind)
    }
    _ => raise Malformed
  }
}
