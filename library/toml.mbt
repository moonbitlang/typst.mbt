// Port of `typst-library/src/loading/toml.rs`.

///|
/// Reads structured data from a TOML file.
///
/// The file must contain a valid TOML table. The function returns a
/// dictionary representing the TOML table.
fn impl_toml(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Dict raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  let raw = within(loaded, () => bytes_as_str(loaded.data))
  within(loaded, () => {
    let data = @toml.parse(raw) catch {
      error => raise LoadErr(format_toml_error(error))
    }
    // Upstream deserializes straight into a `Dict`.
    match data {
      Map(entries) => Dict::from_serde_entries(entries)
      _ => Dict::new()
    }
  })
}

///|
/// Encodes structured data into a TOML string.
fn impl_toml_encode(
  value_ : @syntax.Spanned[Dict],
  pretty_ : Bool,
) -> String raise SourceError {
  let { v: value, span, } = value_
  @toml.to_string(value.to_serde(true), pretty=pretty_) catch {
    @toml.TomlError(message~, ..) =>
      bail_at(span, "failed to encode value as TOML (\{message})")
  }
}

///|
/// Format the user-facing TOML error message.
fn format_toml_error(error : @toml.TomlError) -> LoadError {
  let @toml.TomlError(message~, span~) = error
  let pos = match span {
    Some((start, end)) => ReportTextPos::Range(start, end)
    None => NoPos
  }
  LoadError::text(pos, "failed to parse TOML", message)
}
