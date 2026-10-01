// Port of `typst-library/src/loading/cbor.rs`.

///|
/// Reads structured data from a CBOR file.
///
/// The file must contain a valid CBOR serialization. The function returns a
/// dictionary, an array or, depending on the CBOR file, another CBOR data
/// type.
fn impl_cbor(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Value raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  within(loaded, () => {
    let data = @cbor.from_slice(loaded.data) catch {
      error => raise LoadErr(format_cbor_error(error))
    }
    Value::from_serde(data)
  })
}

///|
/// Format a user-facing error encountered while parsing a CBOR file
/// (ciborium's `Display` implementation just forwards to `Debug`).
fn format_cbor_error(error : @cbor.CborError) -> LoadError {
  LoadError::binary("failed to parse CBOR", error.message())
}

///|
/// Encode structured data into CBOR bytes.
fn impl_cbor_encode(value_ : @syntax.Spanned[Value]) -> Value {
  // Serialization into CBOR cannot fail for Typst values.
  Bytes(BytesValue(@cbor.to_bytes(value_.v.to_serde(false))))
}
