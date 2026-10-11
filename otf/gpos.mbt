// A [Glyph Positioning Table](https://docs.microsoft.com/en-us/typography/opentype/spec/gpos)
// implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/gpos.rs`.

// A heavily modified port of https://github.com/harfbuzz/rustybuzz implementation
// originally written by https://github.com/laurmaedje

///|
/// A [Device Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#devVarIdxTbls)
/// hinting values.
struct HintingDevice {
  start_size : UInt16
  end_size : UInt16
  delta_format : UInt16
  delta_values : LazyArray16[UInt16]
}

///|
/// Returns X-axis delta.
pub fn HintingDevice::x_delta(
  self : HintingDevice,
  units_per_em : UInt16,
  pixels_per_em : (UInt16, UInt16)?,
) -> Int? {
  guard pixels_per_em is Some((ppem, _)) else { return None }
  self.get_delta(ppem, units_per_em)
}

///|
/// Returns Y-axis delta.
pub fn HintingDevice::y_delta(
  self : HintingDevice,
  units_per_em : UInt16,
  pixels_per_em : (UInt16, UInt16)?,
) -> Int? {
  guard pixels_per_em is Some((_, ppem)) else { return None }
  self.get_delta(ppem, units_per_em)
}

///|
fn HintingDevice::get_delta(
  self : HintingDevice,
  ppem : UInt16,
  scale : UInt16,
) -> Int? {
  let f = self.delta_format.to_int()
  if ppem == 0 || ppem < self.start_size || ppem > self.end_size {
    return None
  }
  let s = (ppem - self.start_size).to_int()
  guard self.delta_values.get((s >> (4 - f)).to_uint16()) is Some(byte) else {
    return None
  }
  let bits = byte.to_int() >> (16 - (((s & ((1 << (4 - f)) - 1)) + 1) << f))
  let mask = 0xFFFF >> (16 - (1 << f))
  let mut delta = (bits & mask).to_int64()
  if delta >= ((mask + 1) >> 1).to_int64() {
    delta -= (mask + 1).to_int64()
  }
  let r = delta * scale.to_int64() / ppem.to_int64()
  if r >= -2147483648L && r <= 2147483647L {
    Some(r.to_int())
  } else {
    None
  }
}

///|
pub impl Debug for HintingDevice with fn to_repr(_) {
  Repr::literal("HintingDevice { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend HintingDevice with @debug.Debug::{to_repr}

///|
/// A [Device Table](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#devVarIdxTbls)
/// indexes into [Item Variation Store](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#IVS).
pub(all) struct VariationDevice {
  outer_index : UInt16
  inner_index : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VariationDevice with @debug.Debug::{to_repr}

///|
/// A [Device Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#devVarIdxTbls).
pub(all) enum Device {
  Hinting(HintingDevice)
  Variation(VariationDevice)
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Device with @debug.Debug::{to_repr}

///|
fn Device::parse(data : BytesView) -> Device? {
  try {
    let s = Stream::new(data)
    let first = s.read_u16()
    let second = s.read_u16()
    let format = s.read_u16()
    match format {
      1..<=3 => {
        let start_size = first
        let end_size = second
        // Wrapping u16 arithmetic, like upstream in release mode.
        let count = ((1 : UInt16) + (end_size - start_size)) >>
          (4 - format.to_int())
        let delta_values = s.read_array16(count)
        Some(
          Hinting({ start_size, end_size, delta_format: format, delta_values, }),
        )
      }
      0x8000 => Some(Variation({ outer_index: first, inner_index: second, }))
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
priv struct ValueFormatFlags(Byte)

///|
fn ValueFormatFlags::x_placement(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x01) != 0
}

///|
fn ValueFormatFlags::y_placement(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x02) != 0
}

///|
fn ValueFormatFlags::x_advance(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x04) != 0
}

///|
fn ValueFormatFlags::y_advance(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x08) != 0
}

///|
fn ValueFormatFlags::x_placement_device(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x10) != 0
}

///|
fn ValueFormatFlags::y_placement_device(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x20) != 0
}

///|
fn ValueFormatFlags::x_advance_device(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x40) != 0
}

///|
fn ValueFormatFlags::y_advance_device(self : ValueFormatFlags) -> Bool {
  (self.0 & 0x80) != 0
}

///|
// The ValueRecord struct constrain either i16 values or Offset16 offsets
// and the total size depend on how many flags are enabled.
fn ValueFormatFlags::size(self : ValueFormatFlags) -> Int {
  // The high 8 bits are not used, so make sure we ignore them using 0xFF.
  2 * self.0.to_int().popcnt()
}

///|
impl FromData for ValueFormatFlags with fn size() {
  2
}

///|
impl FromData for ValueFormatFlags with fn parse(data) {
  // There is no data in high 8 bits, so skip it.
  ValueFormatFlags(data[1])
}

///|
/// A [Value Record](https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#value-record).
pub(all) struct ValueRecord {
  /// Horizontal adjustment for placement, in design units.
  x_placement : Int16
  /// Vertical adjustment for placement, in design units.
  y_placement : Int16
  /// Horizontal adjustment for advance, in design units — only used for horizontal layout.
  x_advance : Int16
  /// Vertical adjustment for advance, in design units — only used for vertical layout.
  y_advance : Int16
  /// A [`Device`] table with horizontal adjustment for placement.
  x_placement_device : Device?
  /// A [`Device`] table with vertical adjustment for placement.
  y_placement_device : Device?
  /// A [`Device`] table with horizontal adjustment for advance.
  x_advance_device : Device?
  /// A [`Device`] table with vertical adjustment for advance.
  y_advance_device : Device?
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValueRecord with @debug.Debug::{to_repr}

///|
pub impl Default for ValueRecord with fn default() {
  {
    x_placement: 0,
    y_placement: 0,
    x_advance: 0,
    y_advance: 0,
    x_placement_device: None,
    y_placement_device: None,
    x_advance_device: None,
    y_advance_device: None,
  }
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValueRecord with Default::{default}

///|
// Raises only on parsing error.
fn ValueRecord::parse(
  table_data : BytesView,
  s : Stream,
  flags : ValueFormatFlags,
) -> ValueRecord raise Malformed {
  let mut x_placement : Int16 = 0
  let mut y_placement : Int16 = 0
  let mut x_advance : Int16 = 0
  let mut y_advance : Int16 = 0
  let mut x_placement_device = None
  let mut y_placement_device = None
  let mut x_advance_device = None
  let mut y_advance_device = None
  if flags.x_placement() {
    x_placement = s.read_i16()
  }
  if flags.y_placement() {
    y_placement = s.read_i16()
  }
  if flags.x_advance() {
    x_advance = s.read_i16()
  }
  if flags.y_advance() {
    y_advance = s.read_i16()
  }
  if flags.x_placement_device() {
    let offset : Offset16? = s.read()
    if offset is Some(offset) {
      x_placement_device = device_at(table_data, offset)
    }
  }
  if flags.y_placement_device() {
    let offset : Offset16? = s.read()
    if offset is Some(offset) {
      y_placement_device = device_at(table_data, offset)
    }
  }
  if flags.x_advance_device() {
    let offset : Offset16? = s.read()
    if offset is Some(offset) {
      x_advance_device = device_at(table_data, offset)
    }
  }
  if flags.y_advance_device() {
    let offset : Offset16? = s.read()
    if offset is Some(offset) {
      y_advance_device = device_at(table_data, offset)
    }
  }
  {
    x_placement,
    y_placement,
    x_advance,
    y_advance,
    x_placement_device,
    y_placement_device,
    x_advance_device,
    y_advance_device,
  }
}

///|
/// `data.get(offset..).and_then(Device::parse)`.
fn device_at(data : BytesView, offset : Offset16) -> Device? {
  match slice_from(data, offset.to_usize()) {
    Some(data) => Device::parse(data)
    None => None
  }
}

///|
/// An array of
/// [Value Records](https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#value-record).
struct ValueRecordsArray {
  // We have to store the original table data because ValueRecords can have
  // a offset to Device tables and offset is from the beginning of the table.
  table_data : BytesView
  // A slice that contains all ValueRecords.
  data : BytesView
  // Number of records.
  len : UInt16
  // Size of the single record.
  value_len : Int
  // Flags, used during ValueRecord parsing.
  flags : ValueFormatFlags
}

///|
fn ValueRecordsArray::parse(
  table_data : BytesView,
  count : UInt16,
  flags : ValueFormatFlags,
  s : Stream,
) -> ValueRecordsArray raise Malformed {
  {
    table_data,
    flags,
    len: count,
    value_len: flags.size(),
    data: s.read_bytes(count.to_int() * flags.size()),
  }
}

///|
/// Returns array's length.
pub fn ValueRecordsArray::len(self : ValueRecordsArray) -> UInt16 {
  self.len
}

///|
/// Checks if the array is empty.
pub fn ValueRecordsArray::is_empty(self : ValueRecordsArray) -> Bool {
  self.len == 0
}

///|
/// Returns a [`ValueRecord`] at index.
pub fn ValueRecordsArray::get(
  self : ValueRecordsArray,
  index : UInt16,
) -> ValueRecord? {
  let start = index.to_int() * self.value_len
  let end = start + self.value_len
  guard slice_get(self.data, start, end) is Some(data) else { return None }
  let s = Stream::new(data)
  opt(() => ValueRecord::parse(self.table_data, s, self.flags))
}

///|
pub impl Debug for ValueRecordsArray with fn to_repr(_) {
  Repr::literal("ValueRecordsArray { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValueRecordsArray with @debug.Debug::{to_repr}

///|
/// A [Single Adjustment Positioning Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#SP).
pub(all) enum SingleAdjustment {
  Format1(coverage~ : Coverage, value~ : ValueRecord)
  Format2(coverage~ : Coverage, values~ : ValueRecordsArray)
}

///|
fn SingleAdjustment::parse(
  data : BytesView,
) -> SingleAdjustment raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let flags : ValueFormatFlags = s.read()
      let value = ValueRecord::parse(data, s, flags)
      SingleAdjustment::Format1(coverage~, value~)
    }
    2 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let flags : ValueFormatFlags = s.read()
      let count = s.read_u16()
      let values = ValueRecordsArray::parse(data, count, flags, s)
      SingleAdjustment::Format2(coverage~, values~)
    }
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn SingleAdjustment::coverage(self : SingleAdjustment) -> Coverage {
  match self {
    Format1(coverage~, ..) => coverage
    Format2(coverage~, ..) => coverage
  }
}

///|
/// A [`ValueRecord`] pairs set used by [`PairAdjustment`].
struct PairSet {
  data : BytesView
  flags : (ValueFormatFlags, ValueFormatFlags)
  record_len : Int
}

///|
fn PairSet::parse(
  data : BytesView,
  flags : (ValueFormatFlags, ValueFormatFlags),
) -> PairSet? {
  try {
    let s = Stream::new(data)
    let count = s.read_u16()
    // Max len is 34, so u8 is just enough.
    let record_len = 2 + flags.0.size() + flags.1.size()
    let data = s.read_bytes(count.to_int() * record_len)
    Some({ data, flags, record_len, })
  } catch {
    _ => None
  }
}

///|
fn PairSet::binary_search(self : PairSet, second : GlyphId) -> BytesView? {
  // Based on Rust std implementation.
  let mut size = self.data.length() / self.record_len
  if size == 0 {
    return None
  }
  let get_record = (index : Int) => {
    let start = index * self.record_len
    let end = start + self.record_len
    slice_get(self.data, start, end)
  }
  let get_glyph = (data : BytesView) => {
    GlyphId(((data[0].to_int() << 8) | data[1].to_int()).to_uint16())
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    // mid is always in [0, size), that means mid is >= 0 and < size.
    // mid >= 0: by definition
    // mid < size: mid = size / 2 + size / 4 + size / 8 ...
    guard get_record(mid) is Some(rec) else { return None }
    let cmp = Compare::compare(get_glyph(rec), second)
    base = if cmp > 0 { base } else { mid }
    size -= half
  }

  // base is always in [0, size) because base <= mid.
  guard get_record(base) is Some(value) else { return None }
  if Compare::compare(get_glyph(value), second) == 0 {
    Some(value)
  } else {
    None
  }
}

///|
/// Returns a [`ValueRecord`] pair using the second glyph.
pub fn PairSet::get(
  self : PairSet,
  second : GlyphId,
) -> (ValueRecord, ValueRecord)? {
  guard self.binary_search(second) is Some(record_data) else { return None }
  let s = Stream::new(record_data)
  s.advance(2) // GlyphId
  try {
    // Note: upstream resolves device offsets relative to the pair set
    // records data (`self.data`), not the subtable.
    let a = ValueRecord::parse(self.data, s, self.flags.0)
    let b = ValueRecord::parse(self.data, s, self.flags.1)
    Some((a, b))
  } catch {
    _ => None
  }
}

///|
pub impl Debug for PairSet with fn to_repr(_) {
  Repr::literal("PairSet { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PairSet with @debug.Debug::{to_repr}

// Essentially a `LazyOffsetArray16` but stores additional data required to parse [`PairSet`].

///|
/// A list of [`PairSet`]s.
struct PairSets {
  data : BytesView
  // Zero offsets must be ignored, therefore we're using `Option<Offset16>`.
  offsets : LazyArray16[Offset16?]
  flags : (ValueFormatFlags, ValueFormatFlags)
}

///|
fn PairSets::new(
  data : BytesView,
  offsets : LazyArray16[Offset16?],
  flags : (ValueFormatFlags, ValueFormatFlags),
) -> PairSets {
  { data, offsets, flags, }
}

///|
/// Returns a value at `index`.
pub fn PairSets::get(self : PairSets, index : UInt16) -> PairSet? {
  guard self.offsets.get(index) is Some(Some(offset)) else { return None }
  match slice_from(self.data, offset.to_usize()) {
    Some(data) => PairSet::parse(data, self.flags)
    None => None
  }
}

///|
/// Returns array's length.
pub fn PairSets::len(self : PairSets) -> UInt16 {
  self.offsets.len()
}

///|
/// Checks if the array is empty.
pub fn PairSets::is_empty(self : PairSets) -> Bool {
  self.offsets.is_empty()
}

///|
pub impl Debug for PairSets with fn to_repr(_) {
  Repr::literal("PairSets { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PairSets with @debug.Debug::{to_repr}

///|
/// A [`ValueRecord`] pairs matrix used by [`PairAdjustment`].
struct ClassMatrix {
  // We have to store table's original slice,
  // because offsets in ValueRecords are from the begging of the table.
  table_data : BytesView
  matrix : BytesView
  counts : (UInt16, UInt16)
  flags : (ValueFormatFlags, ValueFormatFlags)
  record_len : Int
}

///|
fn ClassMatrix::parse(
  table_data : BytesView,
  counts : (UInt16, UInt16),
  flags : (ValueFormatFlags, ValueFormatFlags),
  s : Stream,
) -> ClassMatrix raise Malformed {
  let count = counts.0.to_int64() * counts.1.to_int64()
  // Max len is 32, so u8 is just enough.
  let record_len = flags.0.size() + flags.1.size()
  let len = count * record_len.to_int64()
  if len > 0x7fffffffL {
    raise Malformed
  }
  let matrix = s.read_bytes(len.to_int())
  { table_data, matrix, counts, flags, record_len, }
}

///|
/// Returns a [`ValueRecord`] pair using specified classes.
pub fn ClassMatrix::get(
  self : ClassMatrix,
  classes : (UInt16, UInt16),
) -> (ValueRecord, ValueRecord)? {
  if classes.0 >= self.counts.0 || classes.1 >= self.counts.1 {
    return None
  }
  let idx = classes.0.to_int64() * self.counts.1.to_int64() +
    classes.1.to_int64()
  let start = idx * self.record_len.to_int64()
  if start > self.matrix.length().to_int64() {
    return None
  }
  let record = self.matrix[start.to_int():]
  let s = Stream::new(record)
  try {
    let a = ValueRecord::parse(self.table_data, s, self.flags.0)
    let b = ValueRecord::parse(self.table_data, s, self.flags.1)
    Some((a, b))
  } catch {
    _ => None
  }
}

///|
pub impl Debug for ClassMatrix with fn to_repr(_) {
  Repr::literal("ClassMatrix { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ClassMatrix with @debug.Debug::{to_repr}

///|
/// A [Pair Adjustment Positioning Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#PP).
pub(all) enum PairAdjustment {
  Format1(coverage~ : Coverage, sets~ : PairSets)
  Format2(
    coverage~ : Coverage,
    classes~ : (ClassDefinition, ClassDefinition),
    matrix~ : ClassMatrix
  )
}

///|
fn PairAdjustment::parse(data : BytesView) -> PairAdjustment raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let f0 : ValueFormatFlags = s.read()
      let f1 : ValueFormatFlags = s.read()
      let flags = (f0, f1)
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      PairAdjustment::Format1(
        coverage~,
        sets=PairSets::new(data, offsets, flags),
      )
    }
    2 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let f0 : ValueFormatFlags = s.read()
      let f1 : ValueFormatFlags = s.read()
      let flags = (f0, f1)
      let c0 = ClassDefinition::parse_r(s.read_at_offset16(data))
      let c1 = ClassDefinition::parse_r(s.read_at_offset16(data))
      let classes = (c0, c1)
      let n0 = s.read_u16()
      let n1 = s.read_u16()
      let counts = (n0, n1)
      PairAdjustment::Format2(
        coverage~,
        classes~,
        matrix=ClassMatrix::parse(data, counts, flags, s),
      )
    }
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn PairAdjustment::coverage(self : PairAdjustment) -> Coverage {
  match self {
    Format1(coverage~, ..) => coverage
    Format2(coverage~, ..) => coverage
  }
}

///|
priv struct EntryExitRecord {
  entry_anchor_offset : Offset16?
  exit_anchor_offset : Offset16?
}

///|
impl FromData for EntryExitRecord with fn size() {
  4
}

///|
impl FromData for EntryExitRecord with fn parse(data) {
  let s = Stream::new(data)
  { entry_anchor_offset: s.read(), exit_anchor_offset: s.read(), }
}

///|
/// A list of entry and exit [`Anchor`] pairs.
struct CursiveAnchorSet {
  data : BytesView
  records : LazyArray16[EntryExitRecord]
}

///|
/// Returns an entry [`Anchor`] at index.
pub fn CursiveAnchorSet::entry(
  self : CursiveAnchorSet,
  index : UInt16,
) -> Anchor? {
  guard self.records.get(index) is Some(record) else { return None }
  guard record.entry_anchor_offset is Some(offset) else { return None }
  match slice_from(self.data, offset.to_usize()) {
    Some(data) => Anchor::parse(data)
    None => None
  }
}

///|
/// Returns an exit [`Anchor`] at index.
pub fn CursiveAnchorSet::exit(
  self : CursiveAnchorSet,
  index : UInt16,
) -> Anchor? {
  guard self.records.get(index) is Some(record) else { return None }
  guard record.exit_anchor_offset is Some(offset) else { return None }
  match slice_from(self.data, offset.to_usize()) {
    Some(data) => Anchor::parse(data)
    None => None
  }
}

///|
/// Returns the number of items.
pub fn CursiveAnchorSet::len(self : CursiveAnchorSet) -> UInt16 {
  self.records.len()
}

///|
/// Checks if the set is empty.
pub fn CursiveAnchorSet::is_empty(self : CursiveAnchorSet) -> Bool {
  self.records.is_empty()
}

///|
pub impl Debug for CursiveAnchorSet with fn to_repr(_) {
  Repr::literal("CursiveAnchorSet { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CursiveAnchorSet with @debug.Debug::{to_repr}

///|
/// A [Cursive Attachment Positioning Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#CAP).
pub(all) struct CursiveAdjustment {
  coverage : Coverage
  sets : CursiveAnchorSet
}

///|
fn CursiveAdjustment::parse(
  data : BytesView,
) -> CursiveAdjustment raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let records = s.read_array16(count)
      { coverage, sets: { data, records, }, }
    }
    _ => raise Malformed
  }
}

///|
/// A [Mark-to-Base Attachment Positioning Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#MBP).
pub(all) struct MarkToBaseAdjustment {
  /// A mark coverage.
  mark_coverage : Coverage
  /// A base coverage.
  base_coverage : Coverage
  /// A list of mark anchors.
  marks : MarkArray
  /// An anchors matrix.
  anchors : AnchorMatrix
}

///|
fn MarkToBaseAdjustment::parse(
  data : BytesView,
) -> MarkToBaseAdjustment raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let mark_coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let base_coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let class_count = s.read_u16()
      let marks = MarkArray::parse(s.read_at_offset16(data))
      let anchors = AnchorMatrix::parse(s.read_at_offset16(data), class_count)
      { mark_coverage, base_coverage, marks, anchors, }
    }
    _ => raise Malformed
  }
}

///|
/// A [Mark-to-Ligature Attachment Positioning Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#MLP).
pub(all) struct MarkToLigatureAdjustment {
  mark_coverage : Coverage
  ligature_coverage : Coverage
  marks : MarkArray
  ligature_array : LigatureArray
}

///|
fn MarkToLigatureAdjustment::parse(
  data : BytesView,
) -> MarkToLigatureAdjustment raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let mark_coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let ligature_coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let class_count = s.read_u16()
      let marks = MarkArray::parse(s.read_at_offset16(data))
      let ligature_array = LigatureArray::parse(
        s.read_at_offset16(data),
        class_count,
      )
      { mark_coverage, ligature_coverage, marks, ligature_array, }
    }
    _ => raise Malformed
  }
}

///|
/// An array or ligature anchor matrices.
struct LigatureArray {
  data : BytesView
  class_count : UInt16
  offsets : LazyArray16[Offset16]
}

///|
fn LigatureArray::parse(
  data : BytesView,
  class_count : UInt16,
) -> LigatureArray raise Malformed {
  let s = Stream::new(data)
  let count = s.read_u16()
  let offsets = s.read_array16(count)
  { data, class_count, offsets, }
}

///|
/// Returns an [`AnchorMatrix`] at index.
pub fn LigatureArray::get(
  self : LigatureArray,
  index : UInt16,
) -> AnchorMatrix? {
  guard self.offsets.get(index) is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(data) else {
    return None
  }
  opt(() => AnchorMatrix::parse(data, self.class_count))
}

///|
/// Returns the array length.
pub fn LigatureArray::len(self : LigatureArray) -> UInt16 {
  self.offsets.len()
}

///|
/// Checks if the array is empty.
pub fn LigatureArray::is_empty(self : LigatureArray) -> Bool {
  self.offsets.is_empty()
}

///|
pub impl Debug for LigatureArray with fn to_repr(_) {
  Repr::literal("LigatureArray { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LigatureArray with @debug.Debug::{to_repr}

///|
priv struct MarkRecord {
  class : Class
  mark_anchor : Offset16
}

///|
impl FromData for MarkRecord with fn size() {
  4
}

///|
impl FromData for MarkRecord with fn parse(data) {
  let s = Stream::new(data)
  { class: s.read(), mark_anchor: s.read(), }
}

///|
/// A [Mark Array](https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#mark-array-table).
struct MarkArray {
  data : BytesView
  array : LazyArray16[MarkRecord]
}

///|
fn MarkArray::parse(data : BytesView) -> MarkArray raise Malformed {
  let s = Stream::new(data)
  let count = s.read_u16()
  let array = s.read_array16(count)
  { data, array, }
}

///|
/// Returns contained data at index.
pub fn MarkArray::get(self : MarkArray, index : UInt16) -> (Class, Anchor)? {
  guard self.array.get(index) is Some(record) else { return None }
  guard slice_from(self.data, record.mark_anchor.to_usize()) is Some(data) else {
    return None
  }
  guard Anchor::parse(data) is Some(anchor) else { return None }
  Some((record.class, anchor))
}

///|
/// Returns the array length.
pub fn MarkArray::len(self : MarkArray) -> UInt16 {
  self.array.len()
}

///|
/// Checks if the array is empty.
pub fn MarkArray::is_empty(self : MarkArray) -> Bool {
  self.array.is_empty()
}

///|
pub impl Debug for MarkArray with fn to_repr(_) {
  Repr::literal("MarkArray { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MarkArray with @debug.Debug::{to_repr}

///|
/// An [Anchor Table](https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#anchor-tables).
///
/// The *Anchor Table Format 2: Design Units Plus Contour Point* is not supported.
pub(all) struct Anchor {
  /// Horizontal value, in design units.
  x : Int16
  /// Vertical value, in design units.
  y : Int16
  /// A [`Device`] table with horizontal value.
  x_device : Device?
  /// A [`Device`] table with vertical value.
  y_device : Device?
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Anchor with @debug.Debug::{to_repr}

///|
fn Anchor::parse(data : BytesView) -> Anchor? {
  try {
    let s = Stream::new(data)
    let format = s.read_u16()
    if !(format >= 1 && format <= 3) {
      return None
    }
    let x = s.read_i16()
    let y = s.read_i16()
    let mut x_device = None
    let mut y_device = None

    // Note: Format 2 is not handled since there is currently no way to
    // get a glyph contour point by index.

    if format == 3 {
      let x_offset : Offset16? = s.read()
      x_device = match x_offset {
        Some(offset) => device_at(data, offset)
        None => None
      }
      let y_offset : Offset16? = s.read()
      y_device = match y_offset {
        Some(offset) => device_at(data, offset)
        None => None
      }
    }
    Some({ x, y, x_device, y_device, })
  } catch {
    _ => None
  }
}

///|
/// An [`Anchor`] parsing helper.
pub struct AnchorMatrix {
  priv data : BytesView
  /// Number of rows in the matrix.
  rows : UInt16
  /// Number of columns in the matrix.
  cols : UInt16
  priv matrix : LazyArray32[Offset16?]
}

///|
fn AnchorMatrix::parse(
  data : BytesView,
  cols : UInt16,
) -> AnchorMatrix raise Malformed {
  let s = Stream::new(data)
  let rows = s.read_u16()
  let count = rows.to_uint() * cols.to_uint()
  let matrix = s.read_array32(count)
  { data, rows, cols, matrix, }
}

///|
/// Returns an [`Anchor`] at position.
pub fn AnchorMatrix::get(
  self : AnchorMatrix,
  row : UInt16,
  col : UInt16,
) -> Anchor? {
  let idx = row.to_uint() * self.cols.to_uint() + col.to_uint()
  guard self.matrix.get(idx) is Some(Some(offset)) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(data) else {
    return None
  }
  Anchor::parse(data)
}

///|
pub impl Debug for AnchorMatrix with fn to_repr(_) {
  Repr::literal("AnchorMatrix { ... }")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnchorMatrix with @debug.Debug::{to_repr}

///|
/// A [Mark-to-Mark Attachment Positioning Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#MMP).
pub(all) struct MarkToMarkAdjustment {
  mark1_coverage : Coverage
  mark2_coverage : Coverage
  marks : MarkArray
  mark2_matrix : AnchorMatrix
}

///|
fn MarkToMarkAdjustment::parse(
  data : BytesView,
) -> MarkToMarkAdjustment raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let mark1_coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let mark2_coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let class_count = s.read_u16()
      let marks = MarkArray::parse(s.read_at_offset16(data))
      let mark2_matrix = AnchorMatrix::parse(
        s.read_at_offset16(data),
        class_count,
      )
      { mark1_coverage, mark2_coverage, marks, mark2_matrix, }
    }
    _ => raise Malformed
  }
}

///|
/// A glyph positioning
/// [lookup subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gpos#table-organization)
/// enumeration.
pub(all) enum PositioningSubtable {
  Single(SingleAdjustment)
  Pair(PairAdjustment)
  Cursive(CursiveAdjustment)
  MarkToBase(MarkToBaseAdjustment)
  MarkToLigature(MarkToLigatureAdjustment)
  MarkToMark(MarkToMarkAdjustment)
  Context(ContextLookup)
  ChainContext(ChainedContextLookup)
}

///|
pub impl LookupSubtable for PositioningSubtable with fn parse(data, kind) {
  positioning_subtable_parse(data, kind)
}

///|
#deprecated("call as `LookupSubtable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PositioningSubtable with LookupSubtable::{parse}

///|
fn positioning_subtable_parse(
  data : BytesView,
  kind : UInt16,
) -> PositioningSubtable raise Malformed {
  match kind {
    1 => PositioningSubtable::Single(SingleAdjustment::parse(data))
    2 => Pair(PairAdjustment::parse(data))
    3 => Cursive(CursiveAdjustment::parse(data))
    4 => MarkToBase(MarkToBaseAdjustment::parse(data))
    5 => MarkToLigature(MarkToLigatureAdjustment::parse(data))
    6 => MarkToMark(MarkToMarkAdjustment::parse(data))
    7 => PositioningSubtable::Context(ContextLookup::parse(data))
    8 => PositioningSubtable::ChainContext(ChainedContextLookup::parse(data))
    9 => parse_extension_lookup(data, positioning_subtable_parse)
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn PositioningSubtable::coverage(self : PositioningSubtable) -> Coverage {
  match self {
    Single(t) => t.coverage()
    Pair(t) => t.coverage()
    Cursive(t) => t.coverage
    MarkToBase(t) => t.mark_coverage
    MarkToLigature(t) => t.mark_coverage
    MarkToMark(t) => t.mark1_coverage
    Context(t) => t.coverage()
    ChainContext(t) => t.coverage()
  }
}
