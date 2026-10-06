// Port of read-fonts 0.39.2 `src/tables/hdmx.rs` and
// `generated/generated_hdmx.rs`: the Horizontal Device Metrics table.

///|
/// The [Horizontal Device Metrics](https://learn.microsoft.com/en-us/typography/opentype/spec/hdmx) table.
pub struct Hdmx {
  priv data : FontData
  priv num_glyphs : Int
}

///|
/// `Hdmx::MIN_SIZE`: the version (u16), the number of records (u16) and the
/// size of a record (u32).
const HDMX_MIN_SIZE : Int = 8

///|
/// The `hdmx` table (upstream `TableProvider::hdmx`).
pub fn FontRef::hdmx(self : FontRef) -> Hdmx raise ReadError {
  let num_glyphs = self.maxp().num_glyphs()
  let data = self.expect_data_for_tag("hdmx")
  Hdmx::read(data, num_glyphs)
}

///|
/// A constructor that requires additional arguments.
///
/// This type requires some external state in order to be
/// parsed.
pub fn Hdmx::read(data : FontData, num_glyphs : Int) -> Hdmx raise ReadError {
  if data.len() < HDMX_MIN_SIZE {
    raise OutOfBounds
  }
  { data, num_glyphs, }
}

///|
/// Table version number (set to 0).
pub fn Hdmx::version(self : Hdmx) -> Int {
  u16_at(self.data, 0)
}

///|
/// Number of device records.
pub fn Hdmx::num_records(self : Hdmx) -> Int {
  u16_at(self.data, 2)
}

///|
/// Size of device record, 32-bit aligned.
pub fn Hdmx::size_device_record(self : Hdmx) -> UInt {
  u32_at(self.data, 4)
}

///|
/// Array of device records (upstream `ComputedArray<DeviceRecord>`): the
/// records are read lazily from data that holds `num_records` items of
/// `size_device_record` bytes each, or is empty if the table is too short
/// for them (upstream `unwrap_or_default`).
priv struct HdmxRecords {
  /// The length of each item.
  item_len : Int64
  len : Int64
  data : FontData
  num_glyphs : Int
}

///|
fn Hdmx::records(self : Hdmx) -> HdmxRecords {
  let item_len = self.size_device_record().to_int64()
  let start = HDMX_MIN_SIZE.to_int64()
  // `records_byte_range`
  let end = start + self.num_records().to_int64() * item_len
  if end > self.data.len().to_int64() {
    return {
      item_len: 0,
      len: 0,
      data: FontData::empty(),
      num_glyphs: self.num_glyphs,
    }
  }
  // The range fits in the data, hence in an `Int`.
  let data = match self.data.slice(start.to_int(), end.to_int()) {
    Some(data) => data
    None => FontData::empty()
  }
  // `ComputedArray::new`
  let len = if item_len == 0 { 0L } else { data.len().to_int64() / item_len }
  { item_len, len, data, num_glyphs: self.num_glyphs, }
}

///|
/// `ComputedArray::get`.
fn HdmxRecords::get(self : HdmxRecords, idx : Int64) -> DeviceRecord? {
  let item_start = idx * self.item_len
  if item_start > self.data.len().to_int64() {
    return None
  }
  guard self.data.split_off(item_start.to_int()) is Some(data) else {
    return None
  }
  // `DeviceRecord::read_with_args`
  try {
    let pixel_size = data.read_u8(0)
    let max_width = data.read_u8(1)
    let widths = data.read_array(2, self.num_glyphs, 1)
    Some({ pixel_size, max_width, widths: widths.as_bytes(), })
  } catch {
    _ => None
  }
}

///|
/// Returns for the device record that exactly matches the given
/// size (as ppem).
pub fn Hdmx::record_for_size(self : Hdmx, size : Int) -> DeviceRecord? {
  let records = self.records()
  // Need a custom binary search because we're working with
  // ComputedArray
  let mut lo = 0L
  let mut hi = records.len
  while lo < hi {
    let mid = (lo + hi) / 2
    guard records.get(mid) is Some(record) else { return None }
    if record.pixel_size < size {
      lo = mid + 1
    } else if record.pixel_size > size {
      hi = mid
    } else {
      return Some(record)
    }
  }
  None
}

///|
pub struct DeviceRecord {
  /// Pixel size for following widths (as ppem).
  pixel_size : Int
  /// Maximum width.
  max_width : Int
  /// Array of glyphs (numGlyphs is from the 'maxp' table).
  widths : BytesView
}

///|
/// Pixel size for following widths (as ppem).
pub fn DeviceRecord::pixel_size(self : DeviceRecord) -> Int {
  self.pixel_size
}

///|
/// Maximum width.
pub fn DeviceRecord::max_width(self : DeviceRecord) -> Int {
  self.max_width
}

///|
/// Array of widths, indexed by glyph id.
pub fn DeviceRecord::widths(self : DeviceRecord) -> BytesView {
  self.widths
}
