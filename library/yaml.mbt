// Port of `typst-library/src/loading/yaml.rs`.

///|
/// Reads structured data from a YAML file.
///
/// The file must contain a valid YAML object or array. The function returns
/// a dictionary, an array or, depending on the YAML file, another YAML data
/// type.
fn impl_yaml(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Value raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  within(loaded, () => {
    let data = @yaml.parse(loaded.data) catch {
      error => raise LoadErr(format_yaml_error(error))
    }
    Value::from_serde(data)
  })
}

///|
/// Encode structured data into a YAML string.
fn impl_yaml_encode(value_ : @syntax.Spanned[Value]) -> String raise SourceError {
  let { v: value, span } = value_
  @yaml.to_string(value.to_serde(true)) catch {
    @yaml.YamlError(message~, ..) =>
      bail_at(span, "failed to encode value as YAML (\{message})")
  }
}

///|
/// Format the user-facing YAML error message.
pub fn format_yaml_error(error : @yaml.YamlError) -> LoadError {
  let @yaml.YamlError(message~, location~) = error
  let pos = match location {
    Some(loc) => {
      let line_col = LineCol::one_based(loc.line, loc.column)
      ReportTextPos::full(loc.index, loc.index, line_col)
    }
    None => NoPos
  }
  LoadError::text(pos, "failed to parse YAML", message)
}
