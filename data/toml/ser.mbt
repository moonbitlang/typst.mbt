// Serialization: `toml::to_string` / `toml::to_string_pretty` of a value
// driven by upstream Typst's `impl Serialize for Value`.
//
// The pipeline mirrors the crates: `toml_edit::ser::ValueSerializer` builds a
// `toml_edit::Value` (maps become inline tables, `None` map values are
// skipped), `toml::fmt::DocumentFormatter` turns inline tables / arrays of
// inline tables outside of values into (array-of-)tables and formats arrays,
// and `impl Display for DocumentMut` (`toml_edit::encode`) writes it out.

///|
/// A serialized `toml_edit::Value`.
priv enum SValue {
  SString(String)
  SInteger(Int64)
  SFloat(Double)
  SBoolean(Bool)
  SArray(Array[SValue])
  SInlineTable(Array[(String, SValue)])
}

///|
/// A formatted `toml_edit::Item`.
priv enum SItem {
  SIValue(SValue)
  SITable(STable)
  SIArrayOfTables(Array[STable])
}

///|
/// A formatted `toml_edit::Table`.
priv struct STable {
  items : Array[(String, SItem)]
  implicit : Bool
}

///|
/// Serializes a value as a TOML document (`toml::to_string` when `pretty` is
/// false, `toml::to_string_pretty` otherwise). The root must be a map; on
/// failure the message is the `Display` of `toml::ser::Error` (e.g.
/// `unsupported None value`) and there is no span.
pub fn to_string(value : @serde.Data, pretty~ : Bool) -> String raise TomlError {
  let v = match serialize_value(value) {
    Ok(v) => v
    Err(message) => raise TomlError(message~, span=None)
  }
  // `write_document`: `Item::Value(value).into_table()`
  guard v is SInlineTable(items) else {
    raise TomlError(message="unsupported rust type", span=None)
  }
  let root = format_table(items, pretty)
  encode_document(root, pretty)
}

///|
/// `toml_edit::ser::ValueSerializer`.
fn serialize_value(value : @serde.Data) -> Result[SValue, String] {
  match value {
    None => Err("unsupported None value")
    Bool(b) => Ok(SBoolean(b))
    Int(n) => Ok(SInteger(n))
    // Discard sign of NaN when serialized using Serde.
    Float(f) => Ok(SFloat(if f.is_nan() { f.abs() } else { f }))
    Str(s) => Ok(SString(s))
    // `serialize_bytes`: `value.serialize(self)`, i.e. a sequence of `u8`s.
    Bytes(b) => Ok(SArray(b.to_array().map(x => SInteger(x.to_int64()))))
    Seq(items) => {
      let values = []
      for item in items {
        match serialize_value(item) {
          Ok(v) => values.push(v)
          Err(e) => return Err(e)
        }
      }
      Ok(SArray(values))
    }
    Map(entries) => {
      let items : Array[(String, SValue)] = []
      for entry in entries {
        let (k, v) = entry
        // `SerializeInlineTable::serialize_value` with `MapValueSerializer`:
        // a `None` value is skipped.
        if v is None {
          continue
        }
        match serialize_value(v) {
          Ok(v) =>
            match items.search_by(e => e.0 == k) {
              Some(idx) => items[idx] = (k, v)
              None => items.push((k, v))
            }
          Err(e) => return Err(e)
        }
      }
      Ok(SInlineTable(items))
    }
  }
}

///|
/// `DocumentFormatter::visit_table_mut` on a table built from an inline table
/// (`InlineTable::into_table`).
fn format_table(items : Array[(String, SValue)], pretty : Bool) -> STable {
  let formatted = items.map(kv => (kv.0, format_item(kv.1, pretty)))
  // Empty tables could be semantically meaningful, so make sure they are not
  // implicit
  { items: formatted, implicit: !items.is_empty(), }
}

///|
/// `DocumentFormatter::visit_item_mut` for an item whose parent is not a
/// value.
fn format_item(v : SValue, pretty : Bool) -> SItem {
  match v {
    SInlineTable(items) => SITable(format_table(items, pretty))
    SArray(values) if !values.is_empty() &&
      values.iter().all(x => x is SInlineTable(_)) =>
      SIArrayOfTables(
        values.map(x => {
          guard x is SInlineTable(items) else { abort("unreachable") }
          format_table(items, pretty)
        }),
      )
    v => SIValue(v)
  }
}

///|
/// `impl Display for DocumentMut`.
fn encode_document(root : STable, pretty : Bool) -> String {
  let tables : Array[(STable, Array[String], Bool)] = []
  visit_nested_tables(root, [], false, tables)
  // All tables lack a position, so the (stable) sort keeps visiting order.
  let buf = StringBuilder()
  let first_table = Ref(true)
  for t in tables {
    let (table, path, is_array) = t
    visit_table(buf, table, path, is_array, first_table, pretty)
  }
  buf.to_string()
}

///|
/// `encode::visit_nested_tables`.
fn visit_nested_tables(
  table : STable,
  path : Array[String],
  is_array_of_tables : Bool,
  out : Array[(STable, Array[String], Bool)],
) -> Unit {
  out.push((table, path.copy(), is_array_of_tables))
  for kv in table.items {
    let (key, value) = kv
    match value {
      SITable(t) => {
        path.push(key)
        visit_nested_tables(t, path, false, out)
        ignore(path.pop())
      }
      SIArrayOfTables(ts) =>
        for t in ts {
          path.push(key)
          visit_nested_tables(t, path, true, out)
          ignore(path.pop())
        }
      SIValue(_) => ()
    }
  }
}

///|
/// `encode::visit_table`.
fn visit_table(
  buf : StringBuilder,
  table : STable,
  path : Array[String],
  is_array_of_tables : Bool,
  first_table : Ref[Bool],
  pretty : Bool,
) -> Unit {
  let children = []
  for kv in table.items {
    if kv.1 is SIValue(v) {
      children.push((kv.0, v))
    }
  }
  let is_visible_std_table = !(table.implicit && children.is_empty())
  if path.is_empty() {
    // don't print header for the root node
    if !children.is_empty() {
      first_table.val = false
    }
  } else if is_array_of_tables || is_visible_std_table {
    if first_table.val {
      first_table.val = false
    } else {
      buf.write_char('\n')
    }
    let (open, close) = if is_array_of_tables {
      ("[[", "]]")
    } else {
      ("[", "]")
    }
    buf.write_string(open)
    buf.write_string(path.map(to_key_repr).join("."))
    buf.write_string(close)
    buf.write_char('\n')
  }
  // print table body
  for kv in children {
    buf.write_string(to_key_repr(kv.0))
    buf.write_string(" = ")
    encode_value(buf, kv.1, pretty)
    buf.write_char('\n')
  }
}

///|
/// `encode::encode_value` (without decor, which callers write).
fn encode_value(buf : StringBuilder, v : SValue, pretty : Bool) -> Unit {
  match v {
    SString(s) => buf.write_string(to_string_repr(s, None, None))
    SInteger(n) => buf.write_string(n.to_string())
    SFloat(f) => buf.write_string(to_f64_repr(f))
    SBoolean(b) => buf.write_string(if b { "true" } else { "false" })
    SArray(values) => {
      // `DocumentFormatter::visit_array_mut`
      let multiline = pretty && values.length() > 1
      buf.write_char('[')
      for k, elem in values {
        if k > 0 {
          buf.write_char(',')
        }
        if multiline {
          buf.write_string("\n    ")
        } else if k > 0 {
          buf.write_char(' ')
        }
        encode_value(buf, elem, pretty)
      }
      if multiline {
        buf.write_string(",\n")
      }
      buf.write_char(']')
    }
    SInlineTable(items) => {
      buf.write_char('{')
      let len = items.length()
      for k, kv in items {
        if k != 0 {
          buf.write_char(',')
        }
        buf.write_char(' ')
        buf.write_string(to_key_repr(kv.0))
        buf.write_string(" = ")
        encode_value(buf, kv.1, pretty)
        if k == len - 1 {
          buf.write_char(' ')
        }
      }
      buf.write_char('}')
    }
  }
}

///|
/// `encode::to_f64_repr`.
fn to_f64_repr(f : Double) -> String {
  let negative = f.reinterpret_as_uint64() >> 63 != 0
  if f.is_nan() {
    if negative {
      "-nan"
    } else {
      "nan"
    }
  } else if f == 0.0 {
    if negative {
      "-0.0"
    } else {
      "0.0"
    }
  } else if !f.is_inf() && f.floor() == f {
    // `f % 1.0 == 0.0`
    @serde.format_display(f) + ".0"
  } else {
    @serde.format_display(f)
  }
}

///|
/// `encode::StringStyle`.
priv enum StringStyle {
  NewlineTriple
  OnelineTriple
  OnelineSingle
} derive(Eq)

///|
/// `key::to_key_repr`.
fn to_key_repr(key : String) -> String {
  let mut bare = !key.is_empty()
  for c in key {
    let n = c.to_int()
    if n >= 0x80 || !is_unquoted_char(n) {
      bare = false
      break
    }
  }
  if bare {
    key
  } else {
    to_string_repr(key, Some(OnelineSingle), None)
  }
}

///|
/// `encode::to_string_repr`.
fn to_string_repr(
  value : String,
  style : StringStyle?,
  literal : Bool?,
) -> String {
  let (style, literal) = infer_style(value, style, literal)
  let output = StringBuilder()
  if literal {
    output.write_string(
      match style {
        NewlineTriple => "'''\n"
        OnelineTriple => "'''"
        OnelineSingle => "'"
      },
    )
    output.write_string(value)
    output.write_string(
      match style {
        NewlineTriple | OnelineTriple => "'''"
        OnelineSingle => "'"
      },
    )
  } else {
    output.write_string(
      match style {
        NewlineTriple => "\"\"\"\n"
        OnelineTriple | OnelineSingle => "\""
      },
    )
    for ch in value {
      match ch {
        '\u{8}' => output.write_string("\\b")
        '\u{9}' => output.write_string("\\t")
        '\u{a}' =>
          match style {
            NewlineTriple => output.write_char('\n')
            _ => output.write_string("\\n")
          }
        '\u{c}' => output.write_string("\\f")
        '\u{d}' => output.write_string("\\r")
        '\u{22}' => output.write_string("\\\"")
        '\u{5c}' => output.write_string("\\\\")
        c if c.to_int() <= 0x1f || c.to_int() == 0x7f => {
          let hex = c.to_int().to_string(radix=16).to_upper()
          output.write_string("\\u")
          output.write_string("0".repeat(4 - hex.length()))
          output.write_string(hex)
        }
        c => output.write_char(c)
      }
    }
    output.write_string(
      match style {
        NewlineTriple => "\"\"\""
        OnelineTriple | OnelineSingle => "\""
      },
    )
  }
  output.to_string()
}

///|
/// `encode::infer_style`.
fn infer_style(
  value : String,
  style : StringStyle?,
  literal : Bool?,
) -> (StringStyle, Bool) {
  match (style, literal) {
    (Some(style), Some(literal)) => (style, literal)
    (None, Some(literal)) => (infer_all_style(value).0, literal)
    (Some(style), None) => (style, infer_literal(value))
    (None, None) => infer_all_style(value)
  }
}

///|
/// `encode::infer_literal`: `LITERAL_CHAR` is a set of byte ranges, compared
/// against chars, so only chars up to U+00FF can be literal chars.
fn infer_literal(value : String) -> Bool {
  if !(value.contains("\"") || value.contains("\\")) {
    return false
  }
  for c in value {
    let n = c.to_int()
    if n > 0xff || !is_literal_char(n) {
      return false
    }
  }
  true
}

///|
/// `encode::infer_all_style`.
fn infer_all_style(value : String) -> (StringStyle, Bool) {
  let mut ty = OnelineSingle
  // found consecutive single quotes
  let mut max_found_singles = 0
  let mut found_singles = 0
  let mut prefer_literal = false
  let mut can_be_pretty = true
  for ch in value {
    if can_be_pretty {
      if ch == '\'' {
        found_singles += 1
        if found_singles >= 3 {
          can_be_pretty = false
        }
      } else {
        if found_singles > max_found_singles {
          max_found_singles = found_singles
        }
        found_singles = 0
      }
      match ch {
        '\t' => ()
        '"' => prefer_literal = true
        '\\' => prefer_literal = true
        '\n' => ty = NewlineTriple
        // Escape codes are needed if any ascii control characters are
        // present, including \b \f \r.
        c if c.to_int() <= 0x1f || c.to_int() == 0x7f => can_be_pretty = false
        _ => ()
      }
    } else if ch == '\n' {
      // the string cannot be represented as pretty, still check if it
      // should be multiline
      ty = NewlineTriple
    }
  }
  if found_singles > 0 && value.has_suffix("'") {
    // We cannot escape the ending quote so we must use """
    can_be_pretty = false
  }
  if !prefer_literal {
    can_be_pretty = false
  }
  if !can_be_pretty {
    return (ty, false)
  }
  if found_singles > max_found_singles {
    max_found_singles = found_singles
  }
  if ty == OnelineSingle && max_found_singles >= 1 {
    // no newlines, but must use ''' because it has ' in it
    ty = OnelineTriple
  }
  (ty, true)
}
