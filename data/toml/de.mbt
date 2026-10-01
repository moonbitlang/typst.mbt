// Deserialization: what upstream Typst's `ValueVisitor` observes when
// `toml::from_str::<Dict>` drives `toml_edit::de`.

///|
/// Parses a TOML document (`toml::from_str::<typst::Dict>`).
///
/// Returns a `Data::Map` with the entries in document order. Datetimes are
/// exposed the way `toml_edit::de::DatetimeDeserializer` presents them to
/// `deserialize_any`: as a single-entry map from `@serde.toml_datetime_field`
/// to the `Display` output of the `toml_datetime::Datetime`.
pub fn parse(input : String) -> @serde.Data raise TomlError {
  let root = parse_document(@utf8.encode(input))
  table_to_data(root)
}

///|
fn table_to_data(table : Table) -> @serde.Data {
  let entries = []
  for k, item in table.items {
    entries.push((k, item_to_data(item)))
  }
  Map(entries)
}

///|
fn item_to_data(item : Item) -> @serde.Data {
  match item {
    IValue(v) => value_to_data(v)
    ITable(t) => table_to_data(t)
    IArrayOfTables(ts) => Seq(ts.map(table_to_data))
  }
}

///|
fn value_to_data(v : TValue) -> @serde.Data {
  match v {
    VString(s) => Str(s)
    VInteger(n) => Int(n)
    VFloat(f) => Float(f)
    VBoolean(b) => Bool(b)
    VDatetime(d) => Map([(@serde.toml_datetime_field, Str(d.to_display()))])
    VArray(vs) => Seq(vs.map(value_to_data))
    VInlineTable(t) => {
      let entries = []
      for k, v in t.items {
        entries.push((k, value_to_data(v)))
      }
      Map(entries)
    }
  }
}
