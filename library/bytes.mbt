// Minimal part of `typst-library/src/foundations/bytes.rs` needed by the
// data loading functions: the `bytes` constructor (upstream
// `Bytes::construct` with the `ToBytes` cast).
// TODO: port the rest of `bytes.rs` (replacing the `BytesValue` placeholder).

///|
/// Converts a value to bytes.
fn impl_bytes_construct(value_ : Value) -> Value raise HintedError {
  if reflect_castable((Ty::new() : Ty[String]), value_) {
    let s : String = value_.cast()
    return Bytes(BytesValue(@utf8.encode(s)))
  }
  match value_ {
    Array(array) => {
      let buf = Buffer()
      for item in array.items {
        match item {
          Int(byte) if byte >= 0L && byte <= 255L =>
            buf.write_byte(byte.to_int().to_byte())
          Int(_) => bail("number must be between 0 and 255")
          value =>
            raise HintedError(
              cast_error((Ty::new() : Ty[Int64]), value),
            )
        }
      }
      Bytes(BytesValue(buf.to_bytes()))
    }
    Bytes(_) => value_
    v =>
      raise HintedError(
        CastInfo::Union([
          Type(Type::str()),
          Type(Type::array()),
          Type(Type::bytes()),
        ]).error(v),
      )
  }
}
