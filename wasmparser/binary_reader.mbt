// Port of wasmparser 0.228.0 `src/binary_reader.rs`.
//
// Not ported: `read_u7` (binary_reader.rs:295), whose only callers are the
// subsection readers of the name and linking custom sections
// (readers.rs:294); wasmi does not read those sections.

///|
let wasm_magic_number : Bytes = b"\x00asm"

///|
pub(all) enum BinaryReaderErrorKind {
  Custom
  Invalid
} derive(Eq, Debug)

///|
/// A binary reader for WebAssembly modules.
///
/// `Display` (`Show`/`to_string`) is `"{message} (at offset 0x{offset:x})"`.
pub suberror BinaryReaderError {
  BinaryReaderError(
    message~ : String,
    kind~ : BinaryReaderErrorKind,
    offset~ : Int,
    needed_hint~ : Int?
  )
}

///|
pub impl Show for BinaryReaderError with fn output(self, logger) {
  let BinaryReaderError(message~, offset~, ..) = self
  logger.write_string(message)
  logger.write_string(" (at offset 0x")
  logger.write_string(offset.to_string(radix=16))
  logger.write_string(")")
}

///|
fn BinaryReaderError::new_kind(
  kind : BinaryReaderErrorKind,
  message : String,
  offset : Int,
) -> BinaryReaderError {
  BinaryReaderError(message~, kind~, offset~, needed_hint=None)
}

///|
pub fn BinaryReaderError::new(
  message : String,
  offset : Int,
) -> BinaryReaderError {
  BinaryReaderError::new_kind(Custom, message, offset)
}

///|
fn BinaryReaderError::invalid(msg : String, offset : Int) -> BinaryReaderError {
  BinaryReaderError::new_kind(Invalid, msg, offset)
}

///|
fn BinaryReaderError::eof(offset : Int, needed_hint : Int) -> BinaryReaderError {
  BinaryReaderError(
    message="unexpected end-of-file",
    kind=Custom,
    offset~,
    needed_hint=Some(needed_hint),
  )
}

///|
fn BinaryReaderError::kind(self : BinaryReaderError) -> BinaryReaderErrorKind {
  let BinaryReaderError(kind~, ..) = self
  kind
}

///|
/// Get this error's message.
pub fn BinaryReaderError::message(self : BinaryReaderError) -> String {
  let BinaryReaderError(message~, ..) = self
  message
}

///|
/// Get the offset within the Wasm binary where the error occurred.
pub fn BinaryReaderError::offset(self : BinaryReaderError) -> Int {
  let BinaryReaderError(offset~, ..) = self
  offset
}

///|
/// The hint of how many more bytes are needed, for "unexpected end-of-file"
/// errors.
pub fn BinaryReaderError::needed_hint(self : BinaryReaderError) -> Int? {
  let BinaryReaderError(needed_hint~, ..) = self
  needed_hint
}

///|
fn BinaryReaderError::with_message(
  self : BinaryReaderError,
  message : String,
) -> BinaryReaderError {
  let BinaryReaderError(kind~, offset~, needed_hint~, ..) = self
  BinaryReaderError(message~, kind~, offset~, needed_hint~)
}

///|
/// `clear_hint` of `parser.rs`.
fn BinaryReaderError::clear_hint(self : BinaryReaderError) -> BinaryReaderError {
  let BinaryReaderError(message~, kind~, offset~, ..) = self
  BinaryReaderError(message~, kind~, offset~, needed_hint=None)
}

///|
/// `bail!(offset, ...)`.
fn[T] bail(offset : Int, message : String) -> T raise BinaryReaderError {
  raise BinaryReaderError::new(message, offset)
}

///|
/// A half-open range of byte offsets (`core::ops::Range<usize>`).
pub(all) struct Range {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
/// A binary reader of the WebAssembly structures and types.
///
/// The buffer is the window `data[start:start + len]`.
pub struct BinaryReader {
  priv data : Bytes
  priv start : Int
  priv len : Int
  priv mut position : Int
  priv mut original_offset : Int
  priv mut features : WasmFeatures
}

///|
/// Creates a new binary reader which will parse the `data` provided.
///
/// The `original_offset` provided is used for byte offsets in errors that
/// are generated. That offset is added to the current position in `data`.
/// This can be helpful when `data` is just a window of a view into a larger
/// wasm binary perhaps not even entirely stored locally.
///
/// The returned binary reader will have all features known to this crate
/// enabled. To reject binaries that aren't valid unless a certain feature
/// is enabled use the [`BinaryReader::new_features`] constructor instead.
pub fn BinaryReader::new(
  data : BytesView,
  original_offset : Int,
) -> BinaryReader {
  BinaryReader::new_features(data, original_offset, WasmFeatures::all())
}

///|
/// Creates a new binary reader which will parse the `data` provided.
///
/// The `features` argument provided controls which WebAssembly features are
/// active when parsing this data. Wasm features typically don't affect
/// parsing too too much and are generally more applicable during
/// validation, but features and proposals will often reinterpret
/// previously-invalid constructs as now-valid things meaning something
/// slightly different.
pub fn BinaryReader::new_features(
  data : BytesView,
  original_offset : Int,
  features : WasmFeatures,
) -> BinaryReader {
  {
    data: data.data(),
    start: data.start_offset(),
    len: data.length(),
    position: 0,
    original_offset,
    features,
  }
}

///|
/// `Clone`.
pub fn BinaryReader::clone(self : BinaryReader) -> BinaryReader {
  {
    data: self.data,
    start: self.start,
    len: self.len,
    position: self.position,
    original_offset: self.original_offset,
    features: self.features,
  }
}

///|
/// Copies the state of `other` into `self` (`*self = other`).
fn BinaryReader::assign(self : BinaryReader, other : BinaryReader) -> Unit {
  // Only used for clones of `self`, which share the buffer.
  self.position = other.position
  self.original_offset = other.original_offset
  self.features = other.features
}

///|
/// "Shrinks" this binary reader to retain only the buffer left-to-parse.
///
/// The primary purpose of this method is to change the return value of the
/// `range()` method. That method returns the range of the original buffer
/// within the wasm binary so calling `range()` on the returned
/// `BinaryReader` will return a smaller range than if `range()` is called
/// on `self`.
///
/// Otherwise parsing values from either `self` or the return value should
/// return the same thing.
pub fn BinaryReader::shrink(self : BinaryReader) -> BinaryReader {
  {
    data: self.data,
    start: self.start + self.position,
    len: self.len - self.position,
    position: 0,
    original_offset: self.original_offset + self.position,
    features: self.features,
  }
}

///|
/// Gets the original position of the binary reader.
pub fn BinaryReader::original_position(self : BinaryReader) -> Int {
  self.original_offset + self.position
}

///|
/// Returns the currently active set of wasm features that this reader is
/// using while parsing.
pub fn BinaryReader::features(self : BinaryReader) -> WasmFeatures {
  self.features
}

///|
/// Sets the wasm features active while parsing to the `features` specified.
pub fn BinaryReader::set_features(
  self : BinaryReader,
  features : WasmFeatures,
) -> Unit {
  self.features = features
}

///|
/// Returns a range from the starting offset to the end of the buffer.
pub fn BinaryReader::range(self : BinaryReader) -> Range {
  { start: self.original_offset, end: self.original_offset + self.len, }
}

///|
/// The part of the buffer that is left to parse.
pub fn BinaryReader::remaining_buffer(self : BinaryReader) -> BytesView {
  self.data[self.start + self.position:self.start + self.len]
}

///|
fn BinaryReader::ensure_has_byte(
  self : BinaryReader,
) -> Unit raise BinaryReaderError {
  if self.position < self.len {
    ()
  } else {
    raise BinaryReaderError::eof(self.original_position(), 1)
  }
}

///|
fn BinaryReader::ensure_has_bytes(
  self : BinaryReader,
  len : Int,
) -> Unit raise BinaryReaderError {
  // `self.position + len <= self.buffer.len()`, without overflowing.
  if len <= self.len - self.position {
    ()
  } else {
    let hint = self.position + len - self.len
    raise BinaryReaderError::eof(self.original_position(), hint)
  }
}

///|
fn BinaryReader::external_kind_from_byte(
  byte : Byte,
  offset : Int,
) -> ExternalKind raise BinaryReaderError {
  match byte {
    0x00 => Func
    0x01 => Table
    0x02 => Memory
    0x03 => Global
    0x04 => Tag
    x =>
      raise BinaryReader::invalid_leading_byte_error(x, "external kind", offset)
  }
}

///|
/// Reads a variable-length 32-bit size from the byte stream while checking
/// against a limit.
pub fn BinaryReader::read_size(
  self : BinaryReader,
  limit : Int,
  desc : String,
) -> Int raise BinaryReaderError {
  let pos = self.original_position()
  let size = self.read_var_u32()
  if size > limit.reinterpret_as_uint() {
    bail(pos, "\{desc} size is out of bounds")
  }
  size.reinterpret_as_int()
}

///|
/// Reads a variable-length 32-bit size from the byte stream while checking
/// against a limit, and returns it; the caller then reads that many items
/// (upstream `read_iter`).
fn BinaryReader::read_iter(
  self : BinaryReader,
  limit : Int,
  desc : String,
) -> Int raise BinaryReaderError {
  self.read_size(limit, desc)
}

///|
fn BinaryReader::read_memarg(
  self : BinaryReader,
  max_align : Byte,
) -> MemArg raise BinaryReaderError {
  let flags_pos = self.original_position()
  let mut flags = self.read_var_u32()
  let memory = if self.features.multi_memory() && (flags & (1U << 6)) != 0 {
    flags = flags ^ (1U << 6)
    self.read_var_u32()
  } else {
    0
  }
  let align = if flags >= 1U << 6 {
    raise BinaryReaderError::new(
      "malformed memop alignment: alignment too large", flags_pos,
    )
  } else {
    flags.to_byte()
  }
  let offset = if self.features.memory64() {
    self.read_var_u64()
  } else {
    self.read_var_u32().to_uint64()
  }
  { align, max_align, offset, memory, }
}

///|
fn BinaryReader::read_ordering(
  self : BinaryReader,
) -> Ordering raise BinaryReaderError {
  let byte = self.read_var_u32()
  match byte {
    0 => SeqCst
    1 => AcqRel
    x =>
      raise BinaryReaderError::new(
        "invalid atomic consistency ordering \{x}",
        self.original_position() - 1,
      )
  }
}

///|
fn BinaryReader::read_br_table(
  self : BinaryReader,
) -> BrTable raise BinaryReaderError {
  let cnt = self.read_size(MAX_WASM_BR_TABLE_SIZE, "br_table")
  let targets = []
  for _ in 0..<cnt {
    targets.push(self.read_var_u32())
  }
  let default = self.read_var_u32()
  { targets, default, }
}

///|
/// Returns whether the `BinaryReader` has reached the end of the file.
pub fn BinaryReader::eof(self : BinaryReader) -> Bool {
  self.position >= self.len
}

///|
/// Returns the `BinaryReader`'s current position.
pub fn BinaryReader::current_position(self : BinaryReader) -> Int {
  self.position
}

///|
/// Returns the number of bytes remaining in the `BinaryReader`.
pub fn BinaryReader::bytes_remaining(self : BinaryReader) -> Int {
  self.len - self.position
}

///|
/// Advances the `BinaryReader` `size` bytes, and returns a slice from the
/// current position of `size` length.
///
/// # Errors
/// If `size` exceeds the remaining length in `BinaryReader`.
pub fn BinaryReader::read_bytes(
  self : BinaryReader,
  size : Int,
) -> BytesView raise BinaryReaderError {
  self.ensure_has_bytes(size)
  let start = self.position
  self.position += size
  self.data[self.start + start:self.start + self.position]
}

///|
/// Skips `size` bytes (`read_bytes` without the returned slice).
fn BinaryReader::skip_bytes(
  self : BinaryReader,
  size : Int,
) -> Unit raise BinaryReaderError {
  self.ensure_has_bytes(size)
  self.position += size
}

///|
/// Reads a length-prefixed list of bytes from this reader and returns a
/// new `BinaryReader` to read that list of bytes.
pub fn BinaryReader::read_reader(
  self : BinaryReader,
) -> BinaryReader raise BinaryReaderError {
  let size = self.read_var_u32()
  self.skip(reader => reader.skip_bytes_u32(size))
}

///|
/// `read_bytes(size as usize)` for a `u32` size (which may exceed `Int`).
fn BinaryReader::skip_bytes_u32(
  self : BinaryReader,
  size : UInt,
) -> Unit raise BinaryReaderError {
  if size > 0x7FFF_FFFFU {
    // Larger than any buffer.
    let hint = self.position.to_int64() +
      size.to_uint64().reinterpret_as_int64() -
      self.len.to_int64()
    raise BinaryReaderError::eof(self.original_position(), hint.to_int())
  }
  self.skip_bytes(size.reinterpret_as_int())
}

///|
/// `read_bytes(size as usize)` for a `u32` size (which may exceed `Int`).
fn BinaryReader::read_bytes_u32(
  self : BinaryReader,
  size : UInt,
) -> BytesView raise BinaryReaderError {
  let start = self.position
  self.skip_bytes_u32(size)
  self.data[self.start + start:self.start + self.position]
}

///|
/// Advances the `BinaryReader` four bytes and returns a `u32`.
/// # Errors
/// If `BinaryReader` has less than four bytes remaining.
pub fn BinaryReader::read_u32(
  self : BinaryReader,
) -> UInt raise BinaryReaderError {
  self.ensure_has_bytes(4)
  let p = self.start + self.position
  let word = self.data[p].to_uint() |
    (self.data[p + 1].to_uint() << 8) |
    (self.data[p + 2].to_uint() << 16) |
    (self.data[p + 3].to_uint() << 24)
  self.position += 4
  word
}

///|
/// Advances the `BinaryReader` eight bytes and returns a `u64`.
/// # Errors
/// If `BinaryReader` has less than eight bytes remaining.
pub fn BinaryReader::read_u64(
  self : BinaryReader,
) -> UInt64 raise BinaryReaderError {
  self.ensure_has_bytes(8)
  let p = self.start + self.position
  let mut word = 0UL
  for i in 0..<8 {
    word = word | (self.data[p + i].to_uint64() << (8 * i))
  }
  self.position += 8
  word
}

///|
/// Advances the `BinaryReader` a single byte.
///
/// # Errors
///
/// If `BinaryReader` has no bytes remaining.
pub fn BinaryReader::read_u8(
  self : BinaryReader,
) -> Byte raise BinaryReaderError {
  if self.position >= self.len {
    raise self.eof_err()
  }
  let b = self.data[self.start + self.position]
  self.position += 1
  b
}

///|
fn BinaryReader::eof_err(self : BinaryReader) -> BinaryReaderError {
  BinaryReaderError::eof(self.original_position(), 1)
}

///|
/// Advances the `BinaryReader` up to four bytes to parse a variable
/// length integer as a `u32`.
///
/// # Errors
///
/// If `BinaryReader` has less than one or up to four bytes remaining, or
/// the integer is larger than 32 bits.
pub fn BinaryReader::read_var_u32(
  self : BinaryReader,
) -> UInt raise BinaryReaderError {
  // Optimization for single byte i32.
  let byte = self.read_u8()
  if (byte & 0x80) == 0 {
    byte.to_uint()
  } else {
    self.read_var_u32_big(byte)
  }
}

///|
fn BinaryReader::read_var_u32_big(
  self : BinaryReader,
  byte : Byte,
) -> UInt raise BinaryReaderError {
  let mut result = (byte & 0x7F).to_uint()
  let mut shift = 7
  while true {
    let byte = self.read_u8()
    result = result | ((byte & 0x7F).to_uint() << shift)
    if shift >= 25 && byte.to_int() >> (32 - shift) != 0 {
      let msg = if (byte & 0x80) != 0 {
        "invalid var_u32: integer representation too long"
      } else {
        "invalid var_u32: integer too large"
      }
      // The continuation bit or unused bits are set.
      raise BinaryReaderError::new(msg, self.original_position() - 1)
    }
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  result
}

///|
/// Advances the `BinaryReader` up to four bytes to parse a variable
/// length integer as a `u64`.
///
/// # Errors
///
/// If `BinaryReader` has less than one or up to eight bytes remaining, or
/// the integer is larger than 64 bits.
pub fn BinaryReader::read_var_u64(
  self : BinaryReader,
) -> UInt64 raise BinaryReaderError {
  // Optimization for single byte u64.
  let byte = self.read_u8().to_uint64()
  if (byte & 0x80) == 0 {
    byte
  } else {
    self.read_var_u64_big(byte)
  }
}

///|
fn BinaryReader::read_var_u64_big(
  self : BinaryReader,
  byte : UInt64,
) -> UInt64 raise BinaryReaderError {
  let mut result = byte & 0x7F
  let mut shift = 7
  while true {
    let byte = self.read_u8().to_uint64()
    result = result | ((byte & 0x7F) << shift)
    if shift >= 57 && byte >> (64 - shift) != 0 {
      let msg = if (byte & 0x80) != 0 {
        "invalid var_u64: integer representation too long"
      } else {
        "invalid var_u64: integer too large"
      }
      // The continuation bit or unused bits are set.
      raise BinaryReaderError::new(msg, self.original_position() - 1)
    }
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  result
}

///|
/// Executes `f` to skip some data in this binary reader and then returns a
/// reader which will read the skipped data.
pub fn BinaryReader::skip(
  self : BinaryReader,
  f : (BinaryReader) -> Unit raise BinaryReaderError,
) -> BinaryReader raise BinaryReaderError {
  let start = self.position
  f(self)
  {
    data: self.data,
    start: self.start + start,
    len: self.position - start,
    position: 0,
    original_offset: self.original_offset + start,
    features: self.features,
  }
}

///|
/// Advances the `BinaryReader` past a WebAssembly string. This method does
/// not perform any utf-8 validation.
/// # Errors
/// If `BinaryReader` has less than four bytes, the string's length exceeds
/// the remaining bytes, or the string length
/// exceeds `limits::MAX_WASM_STRING_SIZE`.
pub fn BinaryReader::skip_string(
  self : BinaryReader,
) -> Unit raise BinaryReaderError {
  let len = self.read_var_u32()
  if len > MAX_WASM_STRING_SIZE.reinterpret_as_uint() {
    raise BinaryReaderError::new(
      "string size out of bounds",
      self.original_position() - 1,
    )
  }
  self.skip_bytes(len.reinterpret_as_int())
}

///|
/// Advances the `BinaryReader` up to four bytes to parse a variable
/// length integer as a `i32`.
/// # Errors
/// If `BinaryReader` has less than one or up to four bytes remaining, or
/// the integer is larger than 32 bits.
pub fn BinaryReader::read_var_i32(
  self : BinaryReader,
) -> Int raise BinaryReaderError {
  // Optimization for single byte i32.
  let byte = self.read_u8()
  if (byte & 0x80) == 0 {
    byte.to_int() << 25 >> 25
  } else {
    self.read_var_i32_big(byte)
  }
}

///|
/// `(byte << 1) as i8` as an `Int`.
fn sign_and_unused(byte : Byte) -> Int {
  let b = (byte.to_int() << 1) & 0xFF
  if b >= 128 {
    b - 256
  } else {
    b
  }
}

///|
fn BinaryReader::read_var_i32_big(
  self : BinaryReader,
  byte : Byte,
) -> Int raise BinaryReaderError {
  let mut result = (byte & 0x7F).to_int()
  let mut shift = 7
  while true {
    let byte = self.read_u8()
    result = result | ((byte & 0x7F).to_int() << shift)
    if shift >= 25 {
      let continuation_bit = (byte & 0x80) != 0
      let sign_and_unused_bit = sign_and_unused(byte) >> (32 - shift)
      if continuation_bit ||
        (sign_and_unused_bit != 0 && sign_and_unused_bit != -1) {
        let msg = if continuation_bit {
          "invalid var_i32: integer representation too long"
        } else {
          "invalid var_i32: integer too large"
        }
        raise BinaryReaderError::new(msg, self.original_position() - 1)
      }
      return result
    }
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  let ashift = 32 - shift
  result << ashift >> ashift
}

///|
/// Advances the `BinaryReader` up to four bytes to parse a variable
/// length integer as a signed 33 bit integer, returned as a `i64`.
/// # Errors
/// If `BinaryReader` has less than one or up to five bytes remaining, or
/// the integer is larger than 33 bits.
pub fn BinaryReader::read_var_s33(
  self : BinaryReader,
) -> Int64 raise BinaryReaderError {
  // Optimization for single byte.
  let byte = self.read_u8()
  if (byte & 0x80) == 0 {
    return sign_and_unused(byte).to_int64() >> 1
  }
  let mut result = (byte & 0x7F).to_int64()
  let mut shift = 7
  while true {
    let byte = self.read_u8()
    result = result | ((byte & 0x7F).to_int64() << shift)
    if shift >= 25 {
      let continuation_bit = (byte & 0x80) != 0
      let sign_and_unused_bit = sign_and_unused(byte) >> (33 - shift)
      if continuation_bit ||
        (sign_and_unused_bit != 0 && sign_and_unused_bit != -1) {
        raise BinaryReaderError::new(
          "invalid var_s33: integer representation too long",
          self.original_position() - 1,
        )
      }
      return result
    }
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  let ashift = 64 - shift
  result << ashift >> ashift
}

///|
/// Advances the `BinaryReader` up to eight bytes to parse a variable
/// length integer as a 64 bit integer, returned as a `i64`.
/// # Errors
/// If `BinaryReader` has less than one or up to eight bytes remaining, or
/// the integer is larger than 64 bits.
pub fn BinaryReader::read_var_i64(
  self : BinaryReader,
) -> Int64 raise BinaryReaderError {
  let mut result : Int64 = 0
  let mut shift = 0
  while true {
    let byte = self.read_u8()
    result = result | ((byte & 0x7F).to_int64() << shift)
    if shift >= 57 {
      let continuation_bit = (byte & 0x80) != 0
      let sign_and_unused_bit = sign_and_unused(byte) >> (64 - shift)
      if continuation_bit ||
        (sign_and_unused_bit != 0 && sign_and_unused_bit != -1) {
        let msg = if continuation_bit {
          "invalid var_i64: integer representation too long"
        } else {
          "invalid var_i64: integer too large"
        }
        raise BinaryReaderError::new(msg, self.original_position() - 1)
      }
      return result
    }
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  let ashift = 64 - shift
  result << ashift >> ashift
}

///|
/// Advances the `BinaryReader` four bytes to parse a 32 bit floating point
/// number, returned as `Ieee32`.
/// # Errors
/// If `BinaryReader` has less than four bytes remaining.
pub fn BinaryReader::read_f32(
  self : BinaryReader,
) -> Ieee32 raise BinaryReaderError {
  let value = self.read_u32()
  Ieee32(value)
}

///|
/// Advances the `BinaryReader` eight bytes to parse a 64 bit floating point
/// number, returned as `Ieee64`.
/// # Errors
/// If `BinaryReader` has less than eight bytes remaining.
pub fn BinaryReader::read_f64(
  self : BinaryReader,
) -> Ieee64 raise BinaryReaderError {
  let value = self.read_u64()
  Ieee64(value)
}

///|
/// (internal) Reads a fixed-size WebAssembly string from the module.
fn BinaryReader::internal_read_string(
  self : BinaryReader,
  len : UInt,
) -> String raise BinaryReaderError {
  self.skip_bytes_u32(len)
  let len = len.reinterpret_as_int()
  match decode_utf8(self.data, self.start + self.position - len, len) {
    Some(s) => s
    None =>
      raise BinaryReaderError::new(
        "malformed UTF-8 encoding",
        self.original_position() - 1,
      )
  }
}

///|
/// Reads a WebAssembly string from the module.
///
/// # Errors
///
/// If `BinaryReader` has less than up to four bytes remaining, the string's
/// length exceeds the remaining bytes, the string's length exceeds
/// `limits::MAX_WASM_STRING_SIZE`, or the string contains invalid utf-8.
pub fn BinaryReader::read_string(
  self : BinaryReader,
) -> String raise BinaryReaderError {
  let len = self.read_var_u32()
  if len > MAX_WASM_STRING_SIZE.reinterpret_as_uint() {
    raise BinaryReaderError::new(
      "string size out of bounds",
      self.original_position() - 1,
    )
  }
  self.internal_read_string(len)
}

///|
/// Reads a unlimited WebAssembly string from the module.
///
/// Note that this is similar to [`BinaryReader::read_string`] except that
/// it will not limit the size of the returned string by
/// `limits::MAX_WASM_STRING_SIZE`.
pub fn BinaryReader::read_unlimited_string(
  self : BinaryReader,
) -> String raise BinaryReaderError {
  let len = self.read_var_u32()
  self.internal_read_string(len)
}

///|
/// Decodes `len` bytes of `data` at `start` as UTF-8 like Rust's
/// `str::from_utf8`: `None` for any invalid sequence (overlong encodings,
/// surrogates, code points above U+10FFFF, truncated sequences).
fn decode_utf8(data : Bytes, start : Int, len : Int) -> String? {
  let buf = StringBuilder(size_hint=len)
  let end = start + len
  let mut i = start
  while i < end {
    let b0 = data[i].to_int()
    if b0 < 0x80 {
      buf.write_char(b0.unsafe_to_char())
      i += 1
      continue
    }
    let (need, min, init) = if b0 >= 0xC2 && b0 <= 0xDF {
      (1, 0x80, b0 & 0x1F)
    } else if b0 >= 0xE0 && b0 <= 0xEF {
      (2, 0x800, b0 & 0x0F)
    } else if b0 >= 0xF0 && b0 <= 0xF4 {
      (3, 0x10000, b0 & 0x07)
    } else {
      return None
    }
    // Not enough bytes left.
    if i + need >= end {
      return None
    }
    let mut c = init
    for k in 1..<=need {
      let b = data[i + k].to_int()
      if (b & 0xC0) != 0x80 {
        return None
      }
      c = (c << 6) | (b & 0x3F)
    }
    if c < min || c > 0x10FFFF || (c >= 0xD800 && c <= 0xDFFF) {
      return None
    }
    buf.write_char(c.unsafe_to_char())
    i += need + 1
  }
  Some(buf.to_string())
}

///|
fn[T] BinaryReader::invalid_leading_byte(
  self : BinaryReader,
  byte : Byte,
  desc : String,
) -> T raise BinaryReaderError {
  raise BinaryReader::invalid_leading_byte_error(
    byte,
    desc,
    self.original_position() - 1,
  )
}

///|
fn BinaryReader::invalid_leading_byte_error(
  byte : Byte,
  desc : String,
  offset : Int,
) -> BinaryReaderError {
  BinaryReaderError::new(
    "invalid leading byte (0x\{byte.to_int().to_string(radix=16)}) for \{desc}",
    offset,
  )
}

///|
fn BinaryReader::peek(self : BinaryReader) -> Byte raise BinaryReaderError {
  self.ensure_has_byte()
  self.data[self.start + self.position]
}

///|
fn BinaryReader::read_block_type(
  self : BinaryReader,
) -> BlockType raise BinaryReaderError {
  let b = self.peek()

  // Block types are encoded as either 0x40, a `valtype`, or `s33`. All
  // current `valtype` encodings are negative numbers when encoded with
  // sleb128, but it's also required that valtype encodings are in their
  // canonical form. For example an overlong encoding of -1 as `0xff 0x7f`
  // is not valid and it is required to be `0x7f`. This means that we
  // can't simply match on the `s33` that pops out below since reading the
  // whole `s33` might read an overlong encoding.
  //
  // To test for this the first byte `b` is inspected. The highest bit,
  // the continuation bit in LEB128 encoding, must be clear. The next bit,
  // the sign bit, must be set to indicate that the number is negative. If
  // these two conditions hold then we're guaranteed that this is a
  // negative number.
  //
  // After this a value type is read directly instead of looking for an
  // indexed value type.
  if (b & 0x80) == 0 && (b & 0x40) != 0 {
    if b == 0x40 {
      self.position += 1
      return Empty
    }
    return Type(ValType::from_reader(self))
  }

  // Not empty or a singular type, so read the function type index
  let idx = self.read_var_s33()
  if idx >= 0L && idx <= 0xFFFF_FFFFL {
    FuncType(idx.to_int().reinterpret_as_uint())
  } else {
    raise BinaryReaderError::new(
      "invalid function type",
      self.original_position(),
    )
  }
}

///|
/// Reads the next available `Operator`.
///
/// This is upstream's `visit_operator` with the `OperatorFactory` visitor:
/// the immediates are decoded in the same order and with the same errors.
///
/// # Errors
///
/// If `BinaryReader` has less bytes remaining than required to parse
/// the `Operator`.
pub fn BinaryReader::read_operator(
  self : BinaryReader,
) -> Operator raise BinaryReaderError {
  let pos = self.original_position()
  let code = self.read_u8()
  match code {
    0x00 => Unreachable
    0x01 => Nop
    0x02 => Block(blockty=self.read_block_type())
    0x03 => Loop(blockty=self.read_block_type())
    0x04 => If(blockty=self.read_block_type())
    0x05 => Else
    0x06 => Try(blockty=self.read_block_type())
    0x07 => Catch(tag_index=self.read_var_u32())
    0x08 => Throw(tag_index=self.read_var_u32())
    0x09 => Rethrow(relative_depth=self.read_var_u32())
    0x0a => ThrowRef
    0x0b => End
    0x0c => Br(relative_depth=self.read_var_u32())
    0x0d => BrIf(relative_depth=self.read_var_u32())
    0x0e => BrTable(targets=self.read_br_table())
    0x0f => Return
    0x10 => Call(function_index=self.read_var_u32())
    0x11 => {
      let index = self.read_var_u32()
      let table = self.read_table_index_or_zero_if_not_reference_types()
      let type_index = index
      let table_index = table
      CallIndirect(type_index~, table_index~)
    }
    0x12 => ReturnCall(function_index=self.read_var_u32())
    0x13 => {
      let type_index = self.read_var_u32()
      let table_index = self.read_var_u32()
      ReturnCallIndirect(type_index~, table_index~)
    }
    0x14 => CallRef(type_index=self.read_var_u32())
    0x15 => ReturnCallRef(type_index=self.read_var_u32())
    0x18 => Delegate(relative_depth=self.read_var_u32())
    0x19 => CatchAll
    0x1a => Drop
    0x1b => Select
    0x1f => TryTable(try_table=TryTable::from_reader(self))
    0x20 => LocalGet(local_index=self.read_var_u32())
    0x21 => LocalSet(local_index=self.read_var_u32())
    0x22 => LocalTee(local_index=self.read_var_u32())
    0x23 => GlobalGet(global_index=self.read_var_u32())
    0x24 => GlobalSet(global_index=self.read_var_u32())
    0x25 => TableGet(table=self.read_var_u32())
    0x26 => TableSet(table=self.read_var_u32())
    0x28 => I32Load(memarg=self.read_memarg(2))
    0x29 => I64Load(memarg=self.read_memarg(3))
    0x2a => F32Load(memarg=self.read_memarg(2))
    0x2b => F64Load(memarg=self.read_memarg(3))
    0x2c => I32Load8S(memarg=self.read_memarg(0))
    0x2d => I32Load8U(memarg=self.read_memarg(0))
    0x2e => I32Load16S(memarg=self.read_memarg(1))
    0x2f => I32Load16U(memarg=self.read_memarg(1))
    0x30 => I64Load8S(memarg=self.read_memarg(0))
    0x31 => I64Load8U(memarg=self.read_memarg(0))
    0x32 => I64Load16S(memarg=self.read_memarg(1))
    0x33 => I64Load16U(memarg=self.read_memarg(1))
    0x34 => I64Load32S(memarg=self.read_memarg(2))
    0x35 => I64Load32U(memarg=self.read_memarg(2))
    0x36 => I32Store(memarg=self.read_memarg(2))
    0x37 => I64Store(memarg=self.read_memarg(3))
    0x38 => F32Store(memarg=self.read_memarg(2))
    0x39 => F64Store(memarg=self.read_memarg(3))
    0x3a => I32Store8(memarg=self.read_memarg(0))
    0x3b => I32Store16(memarg=self.read_memarg(1))
    0x3c => I64Store8(memarg=self.read_memarg(0))
    0x3d => I64Store16(memarg=self.read_memarg(1))
    0x3e => I64Store32(memarg=self.read_memarg(2))
    0x3f => {
      let mem = self.read_memory_index_or_zero_if_not_multi_memory()
      MemorySize(mem~)
    }
    0x40 => {
      let mem = self.read_memory_index_or_zero_if_not_multi_memory()
      MemoryGrow(mem~)
    }
    0x41 => I32Const(value=self.read_var_i32())
    0x42 => I64Const(value=self.read_var_i64())
    0x43 => F32Const(value=self.read_f32())
    0x44 => F64Const(value=self.read_f64())
    0x45 => I32Eqz
    0x46 => I32Eq
    0x47 => I32Ne
    0x48 => I32LtS
    0x49 => I32LtU
    0x4a => I32GtS
    0x4b => I32GtU
    0x4c => I32LeS
    0x4d => I32LeU
    0x4e => I32GeS
    0x4f => I32GeU
    0x50 => I64Eqz
    0x51 => I64Eq
    0x52 => I64Ne
    0x53 => I64LtS
    0x54 => I64LtU
    0x55 => I64GtS
    0x56 => I64GtU
    0x57 => I64LeS
    0x58 => I64LeU
    0x59 => I64GeS
    0x5a => I64GeU
    0x5b => F32Eq
    0x5c => F32Ne
    0x5d => F32Lt
    0x5e => F32Gt
    0x5f => F32Le
    0x60 => F32Ge
    0x61 => F64Eq
    0x62 => F64Ne
    0x63 => F64Lt
    0x64 => F64Gt
    0x65 => F64Le
    0x66 => F64Ge
    0x67 => I32Clz
    0x68 => I32Ctz
    0x69 => I32Popcnt
    0x6a => I32Add
    0x6b => I32Sub
    0x6c => I32Mul
    0x6d => I32DivS
    0x6e => I32DivU
    0x6f => I32RemS
    0x70 => I32RemU
    0x71 => I32And
    0x72 => I32Or
    0x73 => I32Xor
    0x74 => I32Shl
    0x75 => I32ShrS
    0x76 => I32ShrU
    0x77 => I32Rotl
    0x78 => I32Rotr
    0x79 => I64Clz
    0x7a => I64Ctz
    0x7b => I64Popcnt
    0x7c => I64Add
    0x7d => I64Sub
    0x7e => I64Mul
    0x7f => I64DivS
    0x80 => I64DivU
    0x81 => I64RemS
    0x82 => I64RemU
    0x83 => I64And
    0x84 => I64Or
    0x85 => I64Xor
    0x86 => I64Shl
    0x87 => I64ShrS
    0x88 => I64ShrU
    0x89 => I64Rotl
    0x8a => I64Rotr
    0x8b => F32Abs
    0x8c => F32Neg
    0x8d => F32Ceil
    0x8e => F32Floor
    0x8f => F32Trunc
    0x90 => F32Nearest
    0x91 => F32Sqrt
    0x92 => F32Add
    0x93 => F32Sub
    0x94 => F32Mul
    0x95 => F32Div
    0x96 => F32Min
    0x97 => F32Max
    0x98 => F32Copysign
    0x99 => F64Abs
    0x9a => F64Neg
    0x9b => F64Ceil
    0x9c => F64Floor
    0x9d => F64Trunc
    0x9e => F64Nearest
    0x9f => F64Sqrt
    0xa0 => F64Add
    0xa1 => F64Sub
    0xa2 => F64Mul
    0xa3 => F64Div
    0xa4 => F64Min
    0xa5 => F64Max
    0xa6 => F64Copysign
    0xa7 => I32WrapI64
    0xa8 => I32TruncF32S
    0xa9 => I32TruncF32U
    0xaa => I32TruncF64S
    0xab => I32TruncF64U
    0xac => I64ExtendI32S
    0xad => I64ExtendI32U
    0xae => I64TruncF32S
    0xaf => I64TruncF32U
    0xb0 => I64TruncF64S
    0xb1 => I64TruncF64U
    0xb2 => F32ConvertI32S
    0xb3 => F32ConvertI32U
    0xb4 => F32ConvertI64S
    0xb5 => F32ConvertI64U
    0xb6 => F32DemoteF64
    0xb7 => F64ConvertI32S
    0xb8 => F64ConvertI32U
    0xb9 => F64ConvertI64S
    0xba => F64ConvertI64U
    0xbb => F64PromoteF32
    0xbc => I32ReinterpretF32
    0xbd => I64ReinterpretF64
    0xbe => F32ReinterpretI32
    0xbf => F64ReinterpretI64
    0xc0 => I32Extend8S
    0xc1 => I32Extend16S
    0xc2 => I64Extend8S
    0xc3 => I64Extend16S
    0xc4 => I64Extend32S
    0xd0 => RefNull(hty=HeapType::from_reader(self))
    0xd1 => RefIsNull
    0xd2 => RefFunc(function_index=self.read_var_u32())
    0xd3 => RefEq
    0xd4 => RefAsNonNull
    0xd5 => BrOnNull(relative_depth=self.read_var_u32())
    0xd6 => BrOnNonNull(relative_depth=self.read_var_u32())
    0xe0 => ContNew(cont_type_index=self.read_var_u32())
    0xe1 => {
      let argument_index = self.read_var_u32()
      let result_index = self.read_var_u32()
      ContBind(argument_index~, result_index~)
    }
    0xe2 => Suspend(tag_index=self.read_var_u32())
    0xe3 => {
      let cont_type_index = self.read_var_u32()
      let resume_table = ResumeTable::from_reader(self)
      Resume(cont_type_index~, resume_table~)
    }
    0xe4 => {
      let cont_type_index = self.read_var_u32()
      let tag_index = self.read_var_u32()
      let resume_table = ResumeTable::from_reader(self)
      ResumeThrow(cont_type_index~, tag_index~, resume_table~)
    }
    0xe5 => {
      let cont_type_index = self.read_var_u32()
      let tag_index = self.read_var_u32()
      Switch(cont_type_index~, tag_index~)
    }
    0x1c => {
      let results = self.read_var_u32()
      if results != 1 {
        raise BinaryReaderError::new("invalid result arity", self.position)
      }
      TypedSelect(ty=ValType::from_reader(self))
    }
    0xfb => self.read_0xfb_operator(pos)
    0xfc => self.read_0xfc_operator(pos)
    // The validator always has a SIMD visitor (`simd` cargo feature on).
    0xfd => self.read_0xfd_operator(pos)
    0xfe => self.read_0xfe_operator(pos)
    _ => bail(pos, "illegal opcode: 0x\{code.to_int().to_string(radix=16)}")
  }
}

///|
/// `cast_flags:08b`.
fn binary8(x : Byte) -> String {
  let buf = StringBuilder()
  for i = 7; i >= 0; i = i - 1 {
    buf.write_char(if ((x.to_int() >> i) & 1) != 0 { '1' } else { '0' })
  }
  buf.to_string()
}

///|
fn BinaryReader::read_0xfb_operator(
  self : BinaryReader,
  pos : Int,
) -> Operator raise BinaryReaderError {
  let code = self.read_var_u32()
  match code {
    0x0 => {
      let type_index = self.read_var_u32()
      let struct_type_index = type_index
      StructNew(struct_type_index~)
    }
    0x01 => {
      let type_index = self.read_var_u32()
      let struct_type_index = type_index
      StructNewDefault(struct_type_index~)
    }
    0x02 => {
      let type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      let struct_type_index = type_index
      StructGet(struct_type_index~, field_index~)
    }
    0x03 => {
      let type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      let struct_type_index = type_index
      StructGetS(struct_type_index~, field_index~)
    }
    0x04 => {
      let type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      let struct_type_index = type_index
      StructGetU(struct_type_index~, field_index~)
    }
    0x05 => {
      let type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      let struct_type_index = type_index
      StructSet(struct_type_index~, field_index~)
    }
    0x06 => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArrayNew(array_type_index~)
    }
    0x07 => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArrayNewDefault(array_type_index~)
    }
    0x08 => {
      let type_index = self.read_var_u32()
      let n = self.read_var_u32()
      let array_type_index = type_index
      let array_size = n
      ArrayNewFixed(array_type_index~, array_size~)
    }
    0x09 => {
      let type_index = self.read_var_u32()
      let data_index = self.read_var_u32()
      let array_type_index = type_index
      let array_data_index = data_index
      ArrayNewData(array_type_index~, array_data_index~)
    }
    0x0a => {
      let type_index = self.read_var_u32()
      let elem_index = self.read_var_u32()
      let array_type_index = type_index
      let array_elem_index = elem_index
      ArrayNewElem(array_type_index~, array_elem_index~)
    }
    0x0b => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArrayGet(array_type_index~)
    }
    0x0c => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArrayGetS(array_type_index~)
    }
    0x0d => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArrayGetU(array_type_index~)
    }
    0x0e => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArraySet(array_type_index~)
    }
    0x0f => ArrayLen
    0x10 => {
      let type_index = self.read_var_u32()
      let array_type_index = type_index
      ArrayFill(array_type_index~)
    }
    0x11 => {
      let type_index_dst = self.read_var_u32()
      let type_index_src = self.read_var_u32()
      let array_type_index_dst = type_index_dst
      let array_type_index_src = type_index_src
      ArrayCopy(array_type_index_dst~, array_type_index_src~)
    }
    0x12 => {
      let type_index = self.read_var_u32()
      let data_index = self.read_var_u32()
      let array_type_index = type_index
      let array_data_index = data_index
      ArrayInitData(array_type_index~, array_data_index~)
    }
    0x13 => {
      let type_index = self.read_var_u32()
      let elem_index = self.read_var_u32()
      let array_type_index = type_index
      let array_elem_index = elem_index
      ArrayInitElem(array_type_index~, array_elem_index~)
    }
    0x14 => RefTestNonNull(hty=HeapType::from_reader(self))
    0x15 => RefTestNullable(hty=HeapType::from_reader(self))
    0x16 => RefCastNonNull(hty=HeapType::from_reader(self))
    0x17 => RefCastNullable(hty=HeapType::from_reader(self))
    0x1a => AnyConvertExtern
    0x1b => ExternConvertAny
    0x1c => RefI31
    0x1d => I31GetS
    0x1e => I31GetU
    0x18 => {
      let pos = self.original_position()
      let cast_flags = self.read_u8()
      let relative_depth = self.read_var_u32()
      let (from_type_nullable, to_type_nullable) = match cast_flags {
        0b00 => (false, false)
        0b01 => (true, false)
        0b10 => (false, true)
        0b11 => (true, true)
        _ => bail(pos, "invalid cast flags: \{binary8(cast_flags)}")
      }
      let from_heap_type = HeapType::from_reader(self)
      let from_ref_type = match
        RefType::new(from_type_nullable, from_heap_type) {
        Some(t) => t
        None => bail(pos, "implementation error: type index too large")
      }
      let to_heap_type = HeapType::from_reader(self)
      let to_ref_type = match RefType::new(to_type_nullable, to_heap_type) {
        Some(t) => t
        None => bail(pos, "implementation error: type index too large")
      }
      BrOnCast(relative_depth~, from_ref_type~, to_ref_type~)
    }
    0x19 => {
      let pos = self.original_position()
      let cast_flags = self.read_u8()
      let relative_depth = self.read_var_u32()
      let (from_type_nullable, to_type_nullable) = match cast_flags {
        0 => (false, false)
        1 => (true, false)
        2 => (false, true)
        3 => (true, true)
        _ => bail(pos, "invalid cast flags: \{binary8(cast_flags)}")
      }
      let from_heap_type = HeapType::from_reader(self)
      let from_ref_type = match
        RefType::new(from_type_nullable, from_heap_type) {
        Some(t) => t
        None => bail(pos, "implementation error: type index too large")
      }
      let to_heap_type = HeapType::from_reader(self)
      let to_ref_type = match RefType::new(to_type_nullable, to_heap_type) {
        Some(t) => t
        None => bail(pos, "implementation error: type index too large")
      }
      BrOnCastFail(relative_depth~, from_ref_type~, to_ref_type~)
    }
    _ => bail(pos, "unknown 0xfb subopcode: 0x\{code.to_string(radix=16)}")
  }
}

///|
fn BinaryReader::read_0xfc_operator(
  self : BinaryReader,
  pos : Int,
) -> Operator raise BinaryReaderError {
  let code = self.read_var_u32()
  match code {
    0x00 => I32TruncSatF32S
    0x01 => I32TruncSatF32U
    0x02 => I32TruncSatF64S
    0x03 => I32TruncSatF64U
    0x04 => I64TruncSatF32S
    0x05 => I64TruncSatF32U
    0x06 => I64TruncSatF64S
    0x07 => I64TruncSatF64U
    0x08 => {
      let segment = self.read_var_u32()
      let mem = self.read_var_u32()
      MemoryInit(data_index=segment, mem~)
    }
    0x09 => {
      let segment = self.read_var_u32()
      DataDrop(data_index=segment)
    }
    0x0a => {
      let dst = self.read_var_u32()
      let src = self.read_var_u32()
      MemoryCopy(dst_mem=dst, src_mem=src)
    }
    0x0b => {
      let mem = self.read_var_u32()
      MemoryFill(mem~)
    }
    0x0c => {
      let segment = self.read_var_u32()
      let table = self.read_var_u32()
      TableInit(elem_index=segment, table~)
    }
    0x0d => {
      let segment = self.read_var_u32()
      ElemDrop(elem_index=segment)
    }
    0x0e => {
      let dst_table = self.read_var_u32()
      let src_table = self.read_var_u32()
      TableCopy(dst_table~, src_table~)
    }
    0x0f => {
      let table = self.read_var_u32()
      TableGrow(table~)
    }
    0x10 => {
      let table = self.read_var_u32()
      TableSize(table~)
    }
    0x11 => {
      let table = self.read_var_u32()
      TableFill(table~)
    }
    0x12 => {
      let mem = self.read_var_u32()
      MemoryDiscard(mem~)
    }
    0x13 => I64Add128
    0x14 => I64Sub128
    0x15 => I64MulWideS
    0x16 => I64MulWideU
    _ => bail(pos, "unknown 0xfc subopcode: 0x\{code.to_string(radix=16)}")
  }
}

///|
fn BinaryReader::read_0xfe_operator(
  self : BinaryReader,
  pos : Int,
) -> Operator raise BinaryReaderError {
  let code = self.read_var_u32()
  match code {
    0x00 => MemoryAtomicNotify(memarg=self.read_memarg(2))
    0x01 => MemoryAtomicWait32(memarg=self.read_memarg(2))
    0x02 => MemoryAtomicWait64(memarg=self.read_memarg(3))
    0x10 => I32AtomicLoad(memarg=self.read_memarg(2))
    0x11 => I64AtomicLoad(memarg=self.read_memarg(3))
    0x12 => I32AtomicLoad8U(memarg=self.read_memarg(0))
    0x13 => I32AtomicLoad16U(memarg=self.read_memarg(1))
    0x14 => I64AtomicLoad8U(memarg=self.read_memarg(0))
    0x15 => I64AtomicLoad16U(memarg=self.read_memarg(1))
    0x16 => I64AtomicLoad32U(memarg=self.read_memarg(2))
    0x17 => I32AtomicStore(memarg=self.read_memarg(2))
    0x18 => I64AtomicStore(memarg=self.read_memarg(3))
    0x19 => I32AtomicStore8(memarg=self.read_memarg(0))
    0x1a => I32AtomicStore16(memarg=self.read_memarg(1))
    0x1b => I64AtomicStore8(memarg=self.read_memarg(0))
    0x1c => I64AtomicStore16(memarg=self.read_memarg(1))
    0x1d => I64AtomicStore32(memarg=self.read_memarg(2))
    0x1e => I32AtomicRmwAdd(memarg=self.read_memarg(2))
    0x1f => I64AtomicRmwAdd(memarg=self.read_memarg(3))
    0x20 => I32AtomicRmw8AddU(memarg=self.read_memarg(0))
    0x21 => I32AtomicRmw16AddU(memarg=self.read_memarg(1))
    0x22 => I64AtomicRmw8AddU(memarg=self.read_memarg(0))
    0x23 => I64AtomicRmw16AddU(memarg=self.read_memarg(1))
    0x24 => I64AtomicRmw32AddU(memarg=self.read_memarg(2))
    0x25 => I32AtomicRmwSub(memarg=self.read_memarg(2))
    0x26 => I64AtomicRmwSub(memarg=self.read_memarg(3))
    0x27 => I32AtomicRmw8SubU(memarg=self.read_memarg(0))
    0x28 => I32AtomicRmw16SubU(memarg=self.read_memarg(1))
    0x29 => I64AtomicRmw8SubU(memarg=self.read_memarg(0))
    0x2a => I64AtomicRmw16SubU(memarg=self.read_memarg(1))
    0x2b => I64AtomicRmw32SubU(memarg=self.read_memarg(2))
    0x2c => I32AtomicRmwAnd(memarg=self.read_memarg(2))
    0x2d => I64AtomicRmwAnd(memarg=self.read_memarg(3))
    0x2e => I32AtomicRmw8AndU(memarg=self.read_memarg(0))
    0x2f => I32AtomicRmw16AndU(memarg=self.read_memarg(1))
    0x30 => I64AtomicRmw8AndU(memarg=self.read_memarg(0))
    0x31 => I64AtomicRmw16AndU(memarg=self.read_memarg(1))
    0x32 => I64AtomicRmw32AndU(memarg=self.read_memarg(2))
    0x33 => I32AtomicRmwOr(memarg=self.read_memarg(2))
    0x34 => I64AtomicRmwOr(memarg=self.read_memarg(3))
    0x35 => I32AtomicRmw8OrU(memarg=self.read_memarg(0))
    0x36 => I32AtomicRmw16OrU(memarg=self.read_memarg(1))
    0x37 => I64AtomicRmw8OrU(memarg=self.read_memarg(0))
    0x38 => I64AtomicRmw16OrU(memarg=self.read_memarg(1))
    0x39 => I64AtomicRmw32OrU(memarg=self.read_memarg(2))
    0x3a => I32AtomicRmwXor(memarg=self.read_memarg(2))
    0x3b => I64AtomicRmwXor(memarg=self.read_memarg(3))
    0x3c => I32AtomicRmw8XorU(memarg=self.read_memarg(0))
    0x3d => I32AtomicRmw16XorU(memarg=self.read_memarg(1))
    0x3e => I64AtomicRmw8XorU(memarg=self.read_memarg(0))
    0x3f => I64AtomicRmw16XorU(memarg=self.read_memarg(1))
    0x40 => I64AtomicRmw32XorU(memarg=self.read_memarg(2))
    0x41 => I32AtomicRmwXchg(memarg=self.read_memarg(2))
    0x42 => I64AtomicRmwXchg(memarg=self.read_memarg(3))
    0x43 => I32AtomicRmw8XchgU(memarg=self.read_memarg(0))
    0x44 => I32AtomicRmw16XchgU(memarg=self.read_memarg(1))
    0x45 => I64AtomicRmw8XchgU(memarg=self.read_memarg(0))
    0x46 => I64AtomicRmw16XchgU(memarg=self.read_memarg(1))
    0x47 => I64AtomicRmw32XchgU(memarg=self.read_memarg(2))
    0x48 => I32AtomicRmwCmpxchg(memarg=self.read_memarg(2))
    0x49 => I64AtomicRmwCmpxchg(memarg=self.read_memarg(3))
    0x4a => I32AtomicRmw8CmpxchgU(memarg=self.read_memarg(0))
    0x4b => I32AtomicRmw16CmpxchgU(memarg=self.read_memarg(1))
    0x4c => I64AtomicRmw8CmpxchgU(memarg=self.read_memarg(0))
    0x4d => I64AtomicRmw16CmpxchgU(memarg=self.read_memarg(1))
    0x4f => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicGet(ordering~, global_index~)
    }
    0x50 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicSet(ordering~, global_index~)
    }
    0x51 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwAdd(ordering~, global_index~)
    }
    0x52 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwSub(ordering~, global_index~)
    }
    0x53 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwAnd(ordering~, global_index~)
    }
    0x54 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwOr(ordering~, global_index~)
    }
    0x55 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwXor(ordering~, global_index~)
    }
    0x56 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwXchg(ordering~, global_index~)
    }
    0x57 => {
      let ordering = self.read_ordering()
      let global_index = self.read_var_u32()
      GlobalAtomicRmwCmpxchg(ordering~, global_index~)
    }
    0x58 => {
      let ordering = self.read_ordering()
      let table_index = self.read_var_u32()
      TableAtomicGet(ordering~, table_index~)
    }
    0x59 => {
      let ordering = self.read_ordering()
      let table_index = self.read_var_u32()
      TableAtomicSet(ordering~, table_index~)
    }
    0x5a => {
      let ordering = self.read_ordering()
      let table_index = self.read_var_u32()
      TableAtomicRmwXchg(ordering~, table_index~)
    }
    0x5b => {
      let ordering = self.read_ordering()
      let table_index = self.read_var_u32()
      TableAtomicRmwCmpxchg(ordering~, table_index~)
    }
    0x5c => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicGet(ordering~, struct_type_index~, field_index~)
    }
    0x5d => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicGetS(ordering~, struct_type_index~, field_index~)
    }
    0x5e => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicGetU(ordering~, struct_type_index~, field_index~)
    }
    0x5f => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicSet(ordering~, struct_type_index~, field_index~)
    }
    0x60 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwAdd(ordering~, struct_type_index~, field_index~)
    }
    0x61 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwSub(ordering~, struct_type_index~, field_index~)
    }
    0x62 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwAnd(ordering~, struct_type_index~, field_index~)
    }
    0x63 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwOr(ordering~, struct_type_index~, field_index~)
    }
    0x64 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwXor(ordering~, struct_type_index~, field_index~)
    }
    0x65 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwXchg(ordering~, struct_type_index~, field_index~)
    }
    0x66 => {
      let ordering = self.read_ordering()
      let struct_type_index = self.read_var_u32()
      let field_index = self.read_var_u32()
      StructAtomicRmwCmpxchg(ordering~, struct_type_index~, field_index~)
    }
    0x67 => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicGet(ordering~, array_type_index~)
    }
    0x68 => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicGetS(ordering~, array_type_index~)
    }
    0x69 => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicGetU(ordering~, array_type_index~)
    }
    0x6a => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicSet(ordering~, array_type_index~)
    }
    0x6b => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwAdd(ordering~, array_type_index~)
    }
    0x6c => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwSub(ordering~, array_type_index~)
    }
    0x6d => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwAnd(ordering~, array_type_index~)
    }
    0x6e => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwOr(ordering~, array_type_index~)
    }
    0x6f => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwXor(ordering~, array_type_index~)
    }
    0x70 => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwXchg(ordering~, array_type_index~)
    }
    0x71 => {
      let ordering = self.read_ordering()
      let array_type_index = self.read_var_u32()
      ArrayAtomicRmwCmpxchg(ordering~, array_type_index~)
    }
    0x72 => RefI31Shared
    0x03 => {
      if self.read_u8() != 0 {
        bail(pos, "nonzero byte after `atomic.fence`")
      }
      AtomicFence
    }
    0x4e => I64AtomicRmw32CmpxchgU(memarg=self.read_memarg(2))
    _ => bail(pos, "unknown 0xfe subopcode: 0x\{code.to_string(radix=16)}")
  }
}

///|
/// Returns whether there is an `end` opcode followed by eof remaining in
/// this reader.
pub fn BinaryReader::is_end_then_eof(self : BinaryReader) -> Bool {
  self.len - self.position == 1 && self.data[self.start + self.position] == 0x0b
}

///|
fn BinaryReader::read_lane_index(
  self : BinaryReader,
  max : Byte,
) -> Byte raise BinaryReaderError {
  let index = self.read_u8()
  if index >= max {
    raise BinaryReaderError::new(
      "invalid lane index",
      self.original_position() - 1,
    )
  }
  index
}

///|
fn BinaryReader::read_v128(self : BinaryReader) -> V128 raise BinaryReaderError {
  let bytes = self.read_bytes(16)
  V128(bytes.to_owned())
}

///|
/// `{:#x?}` of a byte slice: pretty-printed `Debug` with hex numbers.
fn pretty_hex_bytes(bytes : BytesView) -> String {
  if bytes.length() == 0 {
    return "[]"
  }
  let buf = StringBuilder()
  buf.write_string("[\n")
  for b in bytes {
    buf.write_string("    0x")
    buf.write_string(b.to_int().to_string(radix=16))
    buf.write_string(",\n")
  }
  buf.write_string("]")
  buf.to_string()
}

///|
fn BinaryReader::read_header_version(
  self : BinaryReader,
) -> UInt raise BinaryReaderError {
  let magic_number = self.read_bytes(4)
  if magic_number != wasm_magic_number[:] {
    raise BinaryReaderError::new(
      "magic header not detected: bad magic number - expected=\{pretty_hex_bytes(wasm_magic_number[:])} actual=\{pretty_hex_bytes(magic_number)}",
      self.original_position() - 4,
    )
  }
  self.read_u32()
}

///|
fn BinaryReader::skip_const_expr(
  self : BinaryReader,
) -> Unit raise BinaryReaderError {
  // TODO add skip_operator() method and/or validate ConstExpr operators.
  while true {
    if self.read_operator() is End {
      return
    }
  }
}

///|
fn BinaryReader::read_memory_index_or_zero_if_not_multi_memory(
  self : BinaryReader,
) -> UInt raise BinaryReaderError {
  if self.features.multi_memory() {
    self.read_var_u32()
  } else {
    // Before bulk memory this byte was required to be a single zero
    // byte, not a LEB-encoded zero, so require a precise zero byte.
    match self.read_u8() {
      0 => 0
      _ => bail(self.original_position() - 1, "zero byte expected")
    }
  }
}

///|
fn BinaryReader::read_table_index_or_zero_if_not_reference_types(
  self : BinaryReader,
) -> UInt raise BinaryReaderError {
  if self.features.reference_types() {
    self.read_var_u32()
  } else {
    // Before reference types this byte was required to be a single zero
    // byte, not a LEB-encoded zero, so require a precise zero byte.
    match self.read_u8() {
      0 => 0
      _ => bail(self.original_position() - 1, "zero byte expected")
    }
  }
}

///|
/// Returns the number of `br_table` entries, not including the default
/// label
pub fn BrTable::len(self : BrTable) -> UInt {
  self.targets.length().reinterpret_as_uint()
}

///|
/// Returns whether `BrTable` doesn't have any labels apart from the default one.
pub fn BrTable::is_empty(self : BrTable) -> Bool {
  self.targets.length() == 0
}

///|
/// Returns the default target of this `br_table` instruction.
pub fn BrTable::default(self : BrTable) -> UInt {
  self.default
}

///|
/// Returns the list of targets that this `br_table` instruction will be
/// jumping to, except the default target.
///
/// Upstream parses the targets lazily; they were already parsed (and their
/// errors reported) when the `br_table` was read, so this port keeps them.
pub fn BrTable::targets(self : BrTable) -> ArrayView[UInt] {
  self.targets[:]
}
