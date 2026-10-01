// Minimal stand-ins for `Bytes`/`Version` APIs used by the ports of
// array.rs, int.rs and float.rs until the real ports of bytes.rs and
// version.rs land (duplicates are dropped when merging those).

///|
/// Upstream `Bytes::new`.
pub fn BytesValue::new(data : Bytes) -> BytesValue {
  BytesValue(data)
}

///|
/// Upstream `Bytes::as_slice`.
pub fn BytesValue::as_slice(self : BytesValue) -> Bytes {
  self.0
}

///|
/// Upstream `Version::values`.
pub fn Version::values(self : Version) -> Array[Int] {
  self.0
}

///|
/// Cast a value to bytes (upstream `Bytes: FromValue`).
pub fn bytes_cast_b(v : Value) -> Bytes raise HintedError {
  match v {
    Bytes(b) => b.as_slice()
    v => cast_fail_with(Type(Type::bytes()), v)
  }
}

///|
/// Wrap raw bytes into a value (upstream `Bytes::new(..).into_value()`).
pub fn bytes_into_value_b(b : Bytes) -> Value {
  Bytes(BytesValue::new(b))
}
