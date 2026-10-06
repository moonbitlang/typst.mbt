// Binary parsing utils.
//
// Port of `ttf-parser` 0.25.1 `src/parser.rs`.
//
// Type mapping used throughout this package: `u8` -> `Byte`, `u16` ->
// `UInt16`, `i16` -> `Int16`, `u32` -> `UInt`, `i32` -> `Int`, `u64` ->
// `UInt64`, `f32` -> `Float`, `usize` -> `Int`. Raw data is a `BytesView`.
//
// Unlike upstream, internal parsing code reports failures by raising
// `Malformed` (the moral equivalent of Rust's `?` on `Option`); public
// accessors keep upstream's `Option` results.

///|
/// Raised when data is malformed or out of bounds.
pub suberror Malformed derive(Debug)

///|
/// Unwraps an option or raises `Malformed` (Rust's `?` on `Option`).
pub fn[T] req(x : T?) -> T raise Malformed {
  match x {
    Some(v) => v
    None => raise Malformed
  }
}

///|
/// Converts a raising computation into an option.
pub fn[T] opt(f : () -> T raise Malformed) -> T? {
  try f() catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// A trait for parsing raw binary data of fixed size.
///
/// This is a low-level, internal trait that should not be used directly.
pub(open) trait FromData {
  /// Object's raw data size.
  fn size() -> Int
  /// Parses an object from a raw data (`data.length() == size()`).
  fn parse(BytesView) -> Self raise Malformed
}

///|
/// A trait for parsing raw binary data of variable size.
pub(open) trait FromSlice {
  fn parse_slice(BytesView) -> Self raise Malformed
}

///|
pub impl FromData for Unit with fn size() {
  0
}

///|
pub impl FromData for Unit with fn parse(_) {
  ()
}

///|
pub impl FromData for Byte with fn size() {
  1
}

///|
pub impl FromData for Byte with fn parse(data) {
  data[0]
}

///|
pub impl FromData for UInt16 with fn size() {
  2
}

///|
pub impl FromData for UInt16 with fn parse(data) {
  be_u16(data, 0)
}

///|
pub impl FromData for Int16 with fn size() {
  2
}

///|
pub impl FromData for Int16 with fn parse(data) {
  Int16::reinterpret_from_uint16(be_u16(data, 0))
}

///|
pub impl FromData for UInt with fn size() {
  4
}

///|
pub impl FromData for UInt with fn parse(data) {
  be_u32(data, 0)
}

///|
pub impl FromData for Int with fn size() {
  4
}

///|
pub impl FromData for Int with fn parse(data) {
  be_u32(data, 0).reinterpret_as_int()
}

///|
pub impl FromData for UInt64 with fn size() {
  8
}

///|
pub impl FromData for UInt64 with fn parse(data) {
  (be_u32(data, 0).to_uint64() << 32) | be_u32(data, 4).to_uint64()
}

///|
#inline
fn be_u16(data : BytesView, i : Int) -> UInt16 {
  ((data[i].to_int() << 8) | data[i + 1].to_int()).to_uint16()
}

///|
#inline
fn be_u32(data : BytesView, i : Int) -> UInt {
  (data[i].to_uint() << 24) |
  (data[i + 1].to_uint() << 16) |
  (data[i + 2].to_uint() << 8) |
  data[i + 3].to_uint()
}

///|
/// A u24 number.
///
/// Stored as u32, but encoded as 3 bytes in the font.
pub(all) struct U24(UInt) derive(Eq, Debug)

///|
pub impl FromData for U24 with fn size() {
  3
}

///|
pub impl FromData for U24 with fn parse(data) {
  U24((data[0].to_uint() << 16) | (data[1].to_uint() << 8) | data[2].to_uint())
}

///|
/// A 16-bit signed fixed number with the low 14 bits of fraction (2.14).
pub(all) struct F2DOT14(Int16) derive(Eq, Debug)

///|
/// Converts i16 to f32.
pub fn F2DOT14::to_f32(self : F2DOT14) -> Float {
  Float::from_int(self.0.to_int()) / 16384.0
}

///|
pub fn F2DOT14::apply_float_delta(self : F2DOT14, delta : Float) -> Float {
  self.to_f32() + Float::from_double(delta.to_double() * (1.0 / 16384.0))
}

///|
pub impl FromData for F2DOT14 with fn size() {
  2
}

///|
pub impl FromData for F2DOT14 with fn parse(data) {
  F2DOT14(FromData::parse(data))
}

///|
/// A 32-bit signed fixed-point number (16.16).
pub(all) struct Fixed(Float) derive(Eq, Debug)

///|
pub impl FromData for Fixed with fn size() {
  4
}

///|
pub impl FromData for Fixed with fn parse(data) {
  let n : Int = FromData::parse(data)
  Fixed(Float::from_int(n) / 65536.0)
}

///|
pub fn Fixed::apply_float_delta(self : Fixed, delta : Float) -> Float {
  self.0 + Float::from_double(delta.to_double() * (1.0 / 65536.0))
}

///|
/// Rust's `f32 as i32` cast (saturating, NaN -> 0).
pub fn f32_as_i32(v : Float) -> Int {
  if v.is_nan() {
    0
  } else if v >= 2147483648.0 {
    0x7fffffff
  } else if v <= -2147483648.0 {
    -0x80000000
  } else {
    v.to_int()
  }
}

///|
/// `TryNumFrom<f32> for i32`.
pub fn try_i32_from_f32(v : Float) -> Int? {
  // Float as int truncates toward zero, so we want to allow values
  // in the exclusive range `(MIN-1, MAX+1)`.
  let min : Float = -2147483648.0
  let max_p1 : Float = 2147483648.0
  if v >= min && v < max_p1 {
    Some(v.to_int())
  } else {
    None
  }
}

///|
/// `TryNumFrom<f32> for i16`.
pub fn try_i16_from_f32(v : Float) -> Int16? {
  match try_i32_from_f32(v) {
    Some(v) if v >= -32768 && v <= 32767 => Some(Int16::from_int(v))
    _ => None
  }
}

///|
/// `TryNumFrom<f32> for u16`.
pub fn try_u16_from_f32(v : Float) -> UInt16? {
  match try_i32_from_f32(v) {
    Some(v) if v >= 0 && v <= 65535 => Some(v.to_uint16())
    _ => None
  }
}

///|
/// `TryNumFrom<f32> for u8`.
pub fn try_u8_from_f32(v : Float) -> Byte? {
  match try_i32_from_f32(v) {
    Some(v) if v >= 0 && v <= 255 => Some(v.to_byte())
    _ => None
  }
}

///|
/// Rust's `data.get(start..end)`.
pub fn slice_get(data : BytesView, start : Int, end : Int) -> BytesView? {
  if start >= 0 && start <= end && end <= data.length() {
    Some(data[start:end])
  } else {
    None
  }
}

///|
/// Rust's `data.get(start..)`.
pub fn slice_from(data : BytesView, start : Int) -> BytesView? {
  if start >= 0 && start <= data.length() {
    Some(data[start:])
  } else {
    None
  }
}

///|
/// Raising version of `slice_get`.
pub fn slice_r(
  data : BytesView,
  start : Int,
  end : Int,
) -> BytesView raise Malformed {
  if start >= 0 && start <= end && end <= data.length() {
    data[start:end]
  } else {
    raise Malformed
  }
}

///|
/// Raising version of `slice_from`.
pub fn slice_from_r(data : BytesView, start : Int) -> BytesView raise Malformed {
  if start >= 0 && start <= data.length() {
    data[start:]
  } else {
    raise Malformed
  }
}

///|
/// An empty byte view.
pub let empty_data : BytesView = b""[:]

///|
/// A slice-like container that converts internal binary data only on access.
///
/// Array values are stored in a continuous data chunk.
#valtype
pub struct LazyArray16[_] {
  data : BytesView
}

///|
pub impl[T] Default for LazyArray16[T] with fn default() {
  { data: empty_data, }
}

///|
pub extend LazyArray16 with Default::{default}

///|
/// Creates a new `LazyArray`.
pub fn[T] LazyArray16::new(data : BytesView) -> LazyArray16[T] {
  { data, }
}

///|
/// The raw data.
pub fn[T] LazyArray16::data(self : LazyArray16[T]) -> BytesView {
  self.data
}

///|
/// Returns a value at `index`.
pub fn[T : FromData] LazyArray16::get(
  self : LazyArray16[T],
  index : UInt16,
) -> T? {
  if index < self.len() {
    let size = T::size()
    let start = index.to_int() * size
    try T::parse(self.data[start:start + size]) catch {
      _ => None
    } noraise {
      v => Some(v)
    }
  } else {
    None
  }
}

///|
/// Raising version of `get`.
pub fn[T : FromData] LazyArray16::get_r(
  self : LazyArray16[T],
  index : UInt16,
) -> T raise Malformed {
  if index < self.len() {
    let size = T::size()
    let start = index.to_int() * size
    T::parse(self.data[start:start + size])
  } else {
    raise Malformed
  }
}

///|
/// Returns the last value.
pub fn[T : FromData] LazyArray16::last(self : LazyArray16[T]) -> T? {
  if !self.is_empty() {
    self.get(self.len() - 1)
  } else {
    None
  }
}

///|
/// Returns sub-array.
pub fn[T : FromData] LazyArray16::slice(
  self : LazyArray16[T],
  start : UInt16,
  end : UInt16,
) -> LazyArray16[T]? {
  let size = T::size()
  match slice_get(self.data, start.to_int() * size, end.to_int() * size) {
    Some(data) => Some({ data, })
    None => None
  }
}

///|
/// Returns array's length.
pub fn[T : FromData] LazyArray16::len(self : LazyArray16[T]) -> UInt16 {
  let size = T::size()
  if size == 0 {
    0
  } else {
    (self.data.length() / size).to_uint16()
  }
}

///|
/// Checks if array is empty.
pub fn[T : FromData] LazyArray16::is_empty(self : LazyArray16[T]) -> Bool {
  self.len() == 0
}

///|
/// Performs a binary search using specified closure.
pub fn[T : FromData] LazyArray16::binary_search_by(
  self : LazyArray16[T],
  f : (T) -> Int,
) -> (UInt16, T)? {
  // Based on Rust std implementation.
  let mut size = self.len()
  if size == 0 {
    return None
  }
  let mut base : UInt16 = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    // mid is always in [0, size), that means mid is >= 0 and < size.
    // mid >= 0: by definition
    // mid < size: mid = size / 2 + size / 4 + size / 8 ...
    guard self.get(mid) is Some(v) else { return None }
    let cmp = f(v)
    base = if cmp > 0 { base } else { mid }
    size -= half
  }

  // base is always in [0, size) because base <= mid.
  guard self.get(base) is Some(value) else { return None }
  if f(value) == 0 {
    Some((base, value))
  } else {
    None
  }
}

///|
/// Performs a binary search by specified `key`.
pub fn[T : FromData + Compare] LazyArray16::binary_search(
  self : LazyArray16[T],
  key : T,
) -> (UInt16, T)? {
  self.binary_search_by(p => Compare::compare(p, key))
}

///|
/// Iterates over the array values.
pub fn[T : FromData] LazyArray16::iter(self : LazyArray16[T]) -> Iter[T] {
  let len = self.len()
  let mut index : UInt16 = 0
  Iter::new(fn() {
    if index < len {
      index += 1
      self.get(index - 1)
    } else {
      None
    }
  })
}

///|
/// A slice-like container that converts internal binary data only on access.
///
/// This is a low-level, internal structure that should not be used directly.
#valtype
pub struct LazyArray32[_] {
  data : BytesView
}

///|
pub impl[T] Default for LazyArray32[T] with fn default() {
  { data: empty_data, }
}

///|
pub extend LazyArray32 with Default::{default}

///|
/// Creates a new `LazyArray`.
pub fn[T] LazyArray32::new(data : BytesView) -> LazyArray32[T] {
  { data, }
}

///|
/// Returns a value at `index`.
pub fn[T : FromData] LazyArray32::get(
  self : LazyArray32[T],
  index : UInt,
) -> T? {
  if index < self.len() {
    let size = T::size()
    let start = index.reinterpret_as_int() * size
    try T::parse(self.data[start:start + size]) catch {
      _ => None
    } noraise {
      v => Some(v)
    }
  } else {
    None
  }
}

///|
/// Returns array's length.
pub fn[T : FromData] LazyArray32::len(self : LazyArray32[T]) -> UInt {
  let size = T::size()
  if size == 0 {
    0
  } else {
    (self.data.length() / size).reinterpret_as_uint()
  }
}

///|
/// Checks if the array is empty.
pub fn[T : FromData] LazyArray32::is_empty(self : LazyArray32[T]) -> Bool {
  self.len() == 0
}

///|
/// Performs a binary search using specified closure.
pub fn[T : FromData] LazyArray32::binary_search_by(
  self : LazyArray32[T],
  f : (T) -> Int,
) -> (UInt, T)? {
  let mut size = self.len()
  if size == 0 {
    return None
  }
  let mut base : UInt = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    guard self.get(mid) is Some(v) else { return None }
    let cmp = f(v)
    base = if cmp > 0 { base } else { mid }
    size -= half
  }
  guard self.get(base) is Some(value) else { return None }
  if f(value) == 0 {
    Some((base, value))
  } else {
    None
  }
}

///|
/// Performs a binary search by specified `key`.
pub fn[T : FromData + Compare] LazyArray32::binary_search(
  self : LazyArray32[T],
  key : T,
) -> (UInt, T)? {
  self.binary_search_by(p => Compare::compare(p, key))
}

///|
/// Iterates over the array values.
pub fn[T : FromData] LazyArray32::iter(self : LazyArray32[T]) -> Iter[T] {
  let len = self.len()
  let mut index : UInt = 0
  Iter::new(fn() {
    if index < len {
      index += 1
      self.get(index - 1)
    } else {
      None
    }
  })
}

///|
/// A [`LazyArray16`]-like container, but data is accessed by offsets.
///
/// Unlike [`LazyArray16`], internal storage is not continuous.
///
/// Multiple offsets can point to the same data.
#valtype
pub struct LazyOffsetArray16[_] {
  data : BytesView
  // Zero offsets must be ignored, therefore we're using `Option<Offset16>`.
  offsets : LazyArray16[Offset16?]
}

///|
pub impl[T] Default for LazyOffsetArray16[T] with fn default() {
  { data: empty_data, offsets: LazyArray16::default(), }
}

///|
/// Creates a new `LazyOffsetArray16`.
pub fn[T] LazyOffsetArray16::new(
  data : BytesView,
  offsets : LazyArray16[Offset16?],
) -> LazyOffsetArray16[T] {
  { data, offsets, }
}

///|
/// Parses `LazyOffsetArray16` from raw data.
pub fn[T] LazyOffsetArray16::parse(
  data : BytesView,
) -> LazyOffsetArray16[T] raise Malformed {
  let s = Stream::new(data)
  let count : UInt16 = s.read()
  let offsets = s.read_array16(count)
  { data, offsets, }
}

///|
/// Returns a value at `index`.
pub fn[T : FromSlice] LazyOffsetArray16::get(
  self : LazyOffsetArray16[T],
  index : UInt16,
) -> T? {
  guard self.offsets.get(index) is Some(Some(offset)) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(data) else {
    return None
  }
  try T::parse_slice(data) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns array's length.
pub fn[T] LazyOffsetArray16::len(self : LazyOffsetArray16[T]) -> UInt16 {
  self.offsets.len()
}

///|
/// Checks if array is empty.
pub fn[T] LazyOffsetArray16::is_empty(self : LazyOffsetArray16[T]) -> Bool {
  self.len() == 0
}

///|
/// An iterator over the values (stops at the first unparsable value, like
/// upstream's iterator).
pub fn[T : FromSlice] LazyOffsetArray16::iter(
  self : LazyOffsetArray16[T],
) -> Iter[T] {
  let len = self.len()
  let mut index : UInt16 = 0
  Iter::new(fn() {
    if index < len {
      index += 1
      self.get(index - 1)
    } else {
      None
    }
  })
}

///|
/// A streaming binary parser.
pub struct Stream {
  data : BytesView
  mut offset : Int
}

///|
pub impl Default for Stream with fn default() {
  { data: empty_data, offset: 0, }
}

///|
pub extend Stream with Default::{default}

///|
/// Creates a new `Stream` parser.
pub fn Stream::new(data : BytesView) -> Stream {
  { data, offset: 0, }
}

///|
/// Creates a new `Stream` parser at offset.
///
/// Returns `None` when `offset` is out of bounds.
pub fn Stream::new_at(data : BytesView, offset : Int) -> Stream? {
  if offset >= 0 && offset <= data.length() {
    Some({ data, offset, })
  } else {
    None
  }
}

///|
/// Raising version of `new_at`.
pub fn Stream::new_at_r(
  data : BytesView,
  offset : Int,
) -> Stream raise Malformed {
  if offset >= 0 && offset <= data.length() {
    { data, offset, }
  } else {
    raise Malformed
  }
}

///|
/// Copies the stream (Rust's `Clone`).
pub fn Stream::copy(self : Stream) -> Stream {
  { data: self.data, offset: self.offset, }
}

///|
/// The whole data of the stream.
pub fn Stream::data(self : Stream) -> BytesView {
  self.data
}

///|
/// Checks that stream reached the end of the data.
pub fn Stream::at_end(self : Stream) -> Bool {
  self.offset >= self.data.length()
}

///|
/// Jumps to the end of the stream.
///
/// Useful to indicate that we parsed all the data.
pub fn Stream::jump_to_end(self : Stream) -> Unit {
  self.offset = self.data.length()
}

///|
/// Returns the current offset.
pub fn Stream::offset(self : Stream) -> Int {
  self.offset
}

///|
/// Returns the trailing data.
///
/// Returns `None` when `Stream` is reached the end.
pub fn Stream::tail(self : Stream) -> BytesView? {
  slice_from(self.data, self.offset)
}

///|
/// Raising version of `tail`.
pub fn Stream::tail_r(self : Stream) -> BytesView raise Malformed {
  slice_from_r(self.data, self.offset)
}

///|
/// Advances by the specified `len`.
///
/// Doesn't check bounds.
pub fn Stream::advance(self : Stream, len : Int) -> Unit {
  self.offset += len
}

///|
/// Advances by the specified `len` and checks for bounds.
pub fn Stream::advance_checked(
  self : Stream,
  len : Int,
) -> Unit raise Malformed {
  if self.offset + len <= self.data.length() {
    self.advance(len)
  } else {
    raise Malformed
  }
}

///|
/// Parses the type from the steam.
///
/// Raises when there is not enough data left in the stream
/// or the type parsing failed.
pub fn[T : FromData] Stream::read(self : Stream) -> T raise Malformed {
  let size = T::size()
  let start = self.offset
  if start < 0 || start + size > self.data.length() {
    raise Malformed
  }
  self.offset = start + size
  T::parse(self.data[start:start + size])
}

///|
/// Option-returning version of `read`.
pub fn[T : FromData] Stream::read_opt(self : Stream) -> T? {
  try self.read() catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Parses the type from the steam at offset.
pub fn[T : FromData] Stream::read_at(
  data : BytesView,
  offset : Int,
) -> T raise Malformed {
  let size = T::size()
  if offset < 0 || offset + size > data.length() {
    raise Malformed
  }
  T::parse(data[offset:offset + size])
}

///|
/// Reads a `u8`.
pub fn Stream::read_u8(self : Stream) -> Byte raise Malformed {
  if self.offset < 0 || self.offset + 1 > self.data.length() {
    raise Malformed
  }
  let v = self.data[self.offset]
  self.offset += 1
  v
}

///|
/// Reads a `u16`.
pub fn Stream::read_u16(self : Stream) -> UInt16 raise Malformed {
  if self.offset < 0 || self.offset + 2 > self.data.length() {
    raise Malformed
  }
  let v = be_u16(self.data, self.offset)
  self.offset += 2
  v
}

///|
/// Reads an `i16`.
pub fn Stream::read_i16(self : Stream) -> Int16 raise Malformed {
  Int16::reinterpret_from_uint16(self.read_u16())
}

///|
/// Reads a `u32`.
pub fn Stream::read_u32(self : Stream) -> UInt raise Malformed {
  if self.offset < 0 || self.offset + 4 > self.data.length() {
    raise Malformed
  }
  let v = be_u32(self.data, self.offset)
  self.offset += 4
  v
}

///|
/// Reads an `i32`.
pub fn Stream::read_i32(self : Stream) -> Int raise Malformed {
  self.read_u32().reinterpret_as_int()
}

///|
/// Reads N bytes from the stream.
pub fn Stream::read_bytes(
  self : Stream,
  len : Int,
) -> BytesView raise Malformed {
  let start = self.offset
  if start < 0 || len < 0 || start + len > self.data.length() {
    raise Malformed
  }
  self.offset = start + len
  self.data[start:start + len]
}

///|
/// Reads the next `count` types as a slice.
pub fn[T : FromData] Stream::read_array16(
  self : Stream,
  count : UInt16,
) -> LazyArray16[T] raise Malformed {
  let len = count.to_int() * T::size()
  LazyArray16::new(self.read_bytes(len))
}

///|
/// Reads the next `count` types as a slice.
pub fn[T : FromData] Stream::read_array32(
  self : Stream,
  count : UInt,
) -> LazyArray32[T] raise Malformed {
  let len = count.to_uint64() * T::size().to_uint64()
  if len > 0x7fffffffUL {
    raise Malformed
  }
  LazyArray32::new(self.read_bytes(len.to_int()))
}

///|
/// Reads an offset and returns the data at it.
pub fn Stream::read_at_offset16(
  self : Stream,
  data : BytesView,
) -> BytesView raise Malformed {
  let offset : Offset16 = self.read()
  slice_from_r(data, offset.to_usize())
}

///|
/// A common offset methods.
pub(open) trait Offset: FromData {
  /// Converts the offset to `usize`.
  fn to_usize(Self) -> Int
  /// Whether the offset is zero.
  fn is_null(Self) -> Bool
}

///|
/// Zero offsets are parsed as `None`.
pub impl[T : Offset] FromData for T? with fn size() {
  size_of((None : T?))
}

///|
fn[T : FromData] size_of(_witness : T?) -> Int {
  T::size()
}

///|
pub impl[T : Offset] FromData for T? with fn parse(data) {
  let offset : T = FromData::parse(data)
  if Offset::is_null(offset) {
    None
  } else {
    Some(offset)
  }
}

///|
/// A type-safe u16 offset.
pub(all) struct Offset16(UInt16) derive(Eq, Debug)

///|
pub impl Offset for Offset16 with fn to_usize(self) {
  self.0.to_int()
}

///|
pub impl Offset for Offset16 with fn is_null(self) {
  self.0 == 0
}

///|
pub extend Offset16 with Offset::{is_null, to_usize}

///|
pub impl FromData for Offset16 with fn size() {
  2
}

///|
pub impl FromData for Offset16 with fn parse(data) {
  Offset16(be_u16(data, 0))
}

///|
/// A type-safe u24 offset.
pub(all) struct Offset24(UInt) derive(Eq, Debug)

///|
pub impl Offset for Offset24 with fn to_usize(self) {
  self.0.reinterpret_as_int()
}

///|
pub impl Offset for Offset24 with fn is_null(self) {
  self.0 == 0
}

///|
pub extend Offset24 with Offset::{is_null, to_usize}

///|
pub impl FromData for Offset24 with fn size() {
  3
}

///|
pub impl FromData for Offset24 with fn parse(data) {
  let n : U24 = FromData::parse(data)
  Offset24(n.0)
}

///|
/// A type-safe u32 offset.
pub(all) struct Offset32(UInt) derive(Eq, Debug)

///|
/// Converts the offset to `usize`. Offsets that do not fit into a
/// non-negative `Int` map to `Int::max_value`, so that bounds checks fail.
pub impl Offset for Offset32 with fn to_usize(self) {
  let v = self.0.reinterpret_as_int()
  if v < 0 {
    0x7fffffff
  } else {
    v
  }
}

///|
pub impl Offset for Offset32 with fn is_null(self) {
  self.0 == 0
}

///|
pub extend Offset32 with Offset::{is_null, to_usize}

///|
pub impl FromData for Offset32 with fn size() {
  4
}

///|
pub impl FromData for Offset32 with fn parse(data) {
  Offset32(be_u32(data, 0))
}

///|
pub fn i16_bound(min : Int16, val : Int16, max : Int16) -> Int16 {
  let v = if max < val { max } else { val }
  if min > v {
    min
  } else {
    v
  }
}

///|
pub fn f32_bound(min : Float, val : Float, max : Float) -> Float {
  if val > max {
    return max
  } else if val < min {
    return min
  }
  val
}

///|
/// `u16::checked_sub`.
pub fn u16_checked_sub(a : UInt16, b : UInt16) -> UInt16? {
  if a >= b {
    Some(a - b)
  } else {
    None
  }
}

///|
/// `u16::checked_add`.
pub fn u16_checked_add(a : UInt16, b : UInt16) -> UInt16? {
  let r = a.to_int() + b.to_int()
  if r <= 0xFFFF {
    Some(r.to_uint16())
  } else {
    None
  }
}

///|
/// `u16::checked_mul`.
pub fn u16_checked_mul(a : UInt16, b : UInt16) -> UInt16? {
  let r = a.to_int() * b.to_int()
  if r <= 0xFFFF {
    Some(r.to_uint16())
  } else {
    None
  }
}

///|
/// `u32::checked_add`.
pub fn u32_checked_add(a : UInt, b : UInt) -> UInt? {
  let r = a + b
  if r < a {
    None
  } else {
    Some(r)
  }
}

///|
/// `u32::checked_sub`.
pub fn u32_checked_sub(a : UInt, b : UInt) -> UInt? {
  if a >= b {
    Some(a - b)
  } else {
    None
  }
}

///|
/// `usize::checked_add` (on non-negative `Int`s).
pub fn usize_checked_add(a : Int, b : Int) -> Int? {
  let r = a.to_int64() + b.to_int64()
  if r > 0x7fffffffL || r < 0L {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// `usize::checked_sub` (on non-negative `Int`s).
pub fn usize_checked_sub(a : Int, b : Int) -> Int? {
  if a >= b {
    Some(a - b)
  } else {
    None
  }
}

///|
/// `u16::try_from(i32)`.
pub fn u16_try_from_int(v : Int) -> UInt16? {
  if v >= 0 && v <= 0xFFFF {
    Some(v.to_uint16())
  } else {
    None
  }
}

///|
/// `i16::try_from(i32)`.
pub fn i16_try_from_int(v : Int) -> Int16? {
  if v >= -32768 && v <= 32767 {
    Some(Int16::from_int(v))
  } else {
    None
  }
}

///|
/// `u16::try_from(u32)`.
pub fn u16_try_from_u32(v : UInt) -> UInt16? {
  if v <= 0xFFFF {
    Some(v.reinterpret_as_int().to_uint16())
  } else {
    None
  }
}

///|
/// `i16 as u16`.
pub fn i16_as_u16(v : Int16) -> UInt16 {
  v.to_int().to_uint16()
}

///|
/// `u16 as i16`.
pub fn u16_as_i16(v : UInt16) -> Int16 {
  Int16::reinterpret_from_uint16(v)
}

///|
/// `u16::from(u8)`.
pub fn u16_from_u8(v : Byte) -> UInt16 {
  v.to_int().to_uint16()
}

///|
/// `i16::saturating_add`.
pub fn i16_saturating_add(a : Int16, b : Int16) -> Int16 {
  let r = a.to_int() + b.to_int()
  if r > 32767 {
    32767
  } else if r < -32768 {
    -32768
  } else {
    Int16::from_int(r)
  }
}
