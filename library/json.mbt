// Port of `typst-library/src/loading/json.rs`.

///|
/// Reads structured data from a JSON file.
///
/// The file must contain a valid JSON value, such as object or array. The
/// function returns a dictionary, an array or, depending on the JSON file,
/// another JSON data type.
fn impl_json(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Value raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  let raw = loaded.data
  // If the file starts with a UTF-8 Byte Order Mark (BOM), return a friendly
  // error message.
  if raw.length() >= 3 &&
    raw[0] == b'\xef' &&
    raw[1] == b'\xbb' &&
    raw[2] == b'\xbf' {
    bail_diag(
      LoadError::text(
        LineCol(LineCol::one_based(1, 1)),
        "failed to parse JSON",
        "unexpected Byte Order Mark",
      )
      .within(loaded)
      .with_hint("JSON requires UTF-8 without a BOM"),
    )
  }
  within(loaded, () => {
    let data = @json.from_slice(raw) catch {
      err => {
        let pos = LineCol::one_based(err.line(), err.column())
        raise LoadErr(
          LoadError::text(LineCol(pos), "failed to parse JSON", err.message()),
        )
      }
    }
    Value::from_serde(data)
  })
}

///|
/// Encodes structured data into a JSON string.
// Cannot fail; upstream's error is serde_json's, unreachable for a `Value`
// (typst-library/src/loading/json.rs:134).
#warnings("-unused_error_type")
fn impl_json_encode(
  value_ : @syntax.Spanned[Value],
  pretty_ : Bool,
) -> String raise SourceError {
  // Serialization into JSON cannot fail for Typst values.
  @json.to_string(value_.v.to_serde(true), pretty=pretty_)
}
