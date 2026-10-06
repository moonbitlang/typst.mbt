// Port of `typst-library/src/foundations/bytes.rs`.

///|
/// A sequence of bytes.
///
/// This is conceptually similar to an array of integers between `{0}` and
/// `{255}`, but represented much more efficiently. You can iterate over it
/// using a for loop.
pub struct BytesValue(Bytes) derive(Eq, Hash)

///|
/// Create a buffer from a byte sequence.
pub fn BytesValue::new(data : Bytes) -> BytesValue {
  BytesValue(data)
}

///|
/// Create a buffer from a string (encoded as UTF-8).
pub fn BytesValue::from_string(data : String) -> BytesValue {
  BytesValue(@utf8.encode(data))
}

///|
/// Return `true` if the length is 0.
pub fn BytesValue::is_empty(self : BytesValue) -> Bool {
  self.0.length() == 0
}

///|
/// Return a view into the bytes.
pub fn BytesValue::as_slice(self : BytesValue) -> Bytes {
  self.0
}

///|
/// Try to view the bytes as a UTF-8 string (`None` if they are not valid
/// UTF-8).
pub fn BytesValue::as_str(self : BytesValue) -> String? {
  Some(@utf8.decode(self.0, ignore_bom=false)) catch {
    _ => None
  }
}

///|
/// Try to turn the bytes into a `Str` (`None` if they are not valid UTF-8).
pub fn BytesValue::to_str(self : BytesValue) -> String? {
  self.as_str()
}

///|
/// The length in bytes.
pub fn BytesValue::len(self : BytesValue) -> Int {
  self.0.length()
}

///|
/// Resolve an index or throw an out of bounds error.
fn BytesValue::locate(
  self : BytesValue,
  index : Int64,
) -> Int raise HintedError {
  match self.locate_opt(index) {
    Some(i) => i
    None => bail(bytes_out_of_bounds(index, self.len()))
  }
}

///|
/// Resolve an index, if it is within bounds.
///
/// `index == len` is considered in bounds.
fn BytesValue::locate_opt(self : BytesValue, index : Int64) -> Int? {
  let len = self.0.length().to_int64()
  let wrapped = if index >= 0L { index } else { len + index }
  if wrapped >= 0L && wrapped <= len {
    Some(wrapped.to_int())
  } else {
    None
  }
}

///|
/// Converts a value to bytes (upstream `Bytes::construct`).
///
/// - Strings are encoded in UTF-8.
/// - Arrays of integers between `{0}` and `{255}` are converted directly. The
///   dedicated byte representation is much more efficient than the array
///   representation and thus typically used for large byte buffers (e.g.
///   image data).
fn impl_bytes_construct(value_ : ToBytes) -> BytesValue {
  value_.0
}

///|
/// The length in bytes (upstream `Bytes::len`).
fn impl_bytes_len(self_ : BytesValue) -> USize {
  USize(self_.len().to_int64())
}

///|
/// Returns the byte at the specified index. Returns the default value if the
/// index is out of bounds or fails with an error if no default value was
/// specified (upstream `Bytes::at`).
fn impl_bytes_at(
  self_ : BytesValue,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  match self_.locate_opt(index_) {
    Some(i) if i < self_.len() => Int(self_.0[i].to_int64())
    _ =>
      match default_ {
        Some(v) => v
        None => bail(bytes_out_of_bounds_no_default(index_, self_.len()))
      }
  }
}

///|
/// Extracts a subslice of the bytes (upstream `Bytes::slice`). Fails with an
/// error if the start or end index is out of bounds.
fn impl_bytes_slice(
  self_ : BytesValue,
  start_ : Int64,
  end_ : Int64?,
  count_ : Int64?,
) -> BytesValue raise HintedError {
  let start = self_.locate(start_)
  let end = match end_ {
    Some(e) => Some(e)
    None => count_.map(c => start.to_int64() + c)
  }
  let end = self_.locate(end.unwrap_or(self_.len().to_int64()))
  let end = if end > start { end } else { start }
  // We could hold a view into the original bytes here instead of making a
  // copy, but it's unclear when that's worth it.
  BytesValue(self_.0[start:end].to_owned())
}

///|
fn impl_bytes_slice__end_default() -> Int64? {
  None
}

///|
/// Upstream `Repr for Bytes`.
pub fn BytesValue::repr(self : BytesValue) -> String {
  "bytes(\{self.len()})"
}

///|
/// Concatenate two byte buffers (upstream `Add for Bytes`).
pub fn BytesValue::concat(self : BytesValue, other : BytesValue) -> BytesValue {
  if other.is_empty() {
    self
  } else if self.is_empty() {
    other
  } else {
    let buf = Buffer(size_hint=self.len() + other.len())
    buf.write_bytes(self.0)
    buf.write_bytes(other.0)
    BytesValue(buf.to_bytes())
  }
}

///|
/// A value that can be cast to bytes.
pub struct ToBytes(BytesValue)

///|
pub impl Reflect for ToBytes with fn input() {
  Union([Type(Type::str()), Type(Type::array()), Type(Type::bytes())])
}

///|
pub impl Reflect for ToBytes with fn output() {
  Union([Type(Type::str()), Type(Type::array()), Type(Type::bytes())])
}

///|
pub impl Reflect for ToBytes with fn castable(v) {
  v is (Str(_) | Symbol(_) | Array(_) | Bytes(_))
}

///|
pub impl FromValue for ToBytes with fn from_value(v) {
  match v {
    Str(_) | Symbol(_) => {
      let s : String = v.cast()
      ToBytes(BytesValue::from_string(s))
    }
    Array(array) => {
      let buf = Buffer(size_hint=array.items.length())
      for item in array.items {
        match item {
          Int(byte) if byte >= 0L && byte <= 255L =>
            buf.write_byte(byte.to_byte())
          Int(_) => bail("number must be between 0 and 255")
          value => raise HintedError(CastInfo::Type(Type::int()).error(value))
        }
      }
      ToBytes(BytesValue(buf.to_bytes()))
    }
    Bytes(b) => ToBytes(b)
    v => raise HintedError(ToBytes::input().error(v))
  }
}

///|
pub impl Reflect for BytesValue with fn input() {
  Type(Type::bytes())
}

///|
pub impl Reflect for BytesValue with fn output() {
  Type(Type::bytes())
}

///|
pub impl Reflect for BytesValue with fn castable(v) {
  v is Bytes(_)
}

///|
pub impl IntoValue for BytesValue with fn into_value(self) {
  Bytes(self)
}

///|
pub impl FromValue for BytesValue with fn from_value(v) {
  match v {
    Bytes(b) => b
    v => raise HintedError(BytesValue::input().error(v))
  }
}

///|
/// The out of bounds access error message.
fn bytes_out_of_bounds(index : Int64, len : Int) -> String {
  "byte index out of bounds (index: \{index}, len: \{len})"
}

///|
/// The out of bounds access error message when no default value was given.
fn bytes_out_of_bounds_no_default(index : Int64, len : Int) -> String {
  "byte index out of bounds (index: \{index}, len: \{len}) and no default value was specified"
}
