///|
/// Renders a deserialized value compactly for assertions: maps as
/// `{"k": v, ...}`, sequences as `[...]`, strings quoted (with `\n`, `\t`,
/// `\r`, `\"`, `\\` and `\u{..}` escapes), floats via Rust `Debug`
/// formatting with an `f` suffix, and datetimes as `D(<Display>)`.
fn render(v : @serde.Data) -> String {
  match v {
    Map([(k, Str(s))]) if k == @serde.toml_datetime_field => "D(\{s})"
    Map(kv) =>
      "{" + kv.map(p => quote(p.0) + ": " + render(p.1)).join(", ") + "}"
    Seq(xs) => "[" + xs.map(render).join(", ") + "]"
    Float(f) => @serde.format_debug(f) + "f"
    Str(s) => quote(s)
    Int(n) => n.to_string()
    Bool(b) => b.to_string()
    None => "none"
    Bytes(_) => "bytes"
  }
}

///|
fn quote(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      c if c.to_int() < 0x20 || c.to_int() == 0x7f =>
        buf.write_string("\\u{\{c.to_int().to_string(radix=16)}}")
      c => buf.write_char(c)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// Parses `input` and renders the result (`ok <value>`) or the error
/// (`err <start>..<end>: <message>`).
fn run_parse(input : String) -> String {
  try @toml.parse(input) catch {
    @toml.TomlError(message~, span~) =>
      match span {
        Some((s, e)) => "err \{s}..\{e}: \{message}"
        None => "err: \{message}"
      }
  } noraise {
    v => "ok " + render(v)
  }
}

///|
/// Serializes `value` and returns the output or `ERR <message>`.
fn run_ser(value : @serde.Data, pretty : Bool) -> String {
  @toml.to_string(value, pretty~) catch {
    @toml.TomlError(message~, ..) => "ERR " + message
  }
}

///|
#callsite(autofill(loc))
fn check_parse(
  input : String,
  expected : String,
  loc~ : SourceLoc,
) -> Unit raise {
  let actual = run_parse(input)
  if actual != expected {
    fail(
      "parse \{quote(input)}:\n  expected \{expected}\n  actual   \{actual}",
      loc~,
    )
  }
}

///|
#callsite(autofill(loc))
fn check_ser(
  value : @serde.Data,
  pretty : Bool,
  expected : String,
  loc~ : SourceLoc,
) -> Unit raise {
  let actual = run_ser(value, pretty)
  if actual != expected {
    fail(
      "to_string(pretty=\{pretty}):\n  expected \{quote(expected)}\n  actual   \{quote(actual)}",
      loc~,
    )
  }
}
