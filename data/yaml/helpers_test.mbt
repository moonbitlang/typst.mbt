// Test helpers: a canonical rendering of parse results that matches the
// `canon` function used to query the upstream Typst oracle.

///|
/// Typst's `repr` for strings.
fn typst_str_repr(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for c in s {
    match c {
      '\u{0}' => buf.write_string("\\u{0}")
      '\'' => buf.write_char('\'')
      '"' => buf.write_string("\\\"")
      _ => {
        let d = @unicode.rust_debug_char(c)
        buf.write_string(d.unsafe_substring(start=1, end=d.length() - 1))
      }
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// Typst's `repr` for floats.
fn typst_float_repr(f : Double) -> String {
  if f.is_nan() {
    "float.nan"
  } else if f.is_inf() {
    if f < 0.0 {
      "-float.inf"
    } else {
      "float.inf"
    }
  } else {
    @serde.format_debug(f)
  }
}

///|
/// Mirrors the oracle's `canon` function (dictionaries with `IndexMap`
/// insertion semantics).
fn canon(d : @serde.Data) -> String {
  match d {
    None => "none"
    Bool(b) => b.to_string()
    Int(i) => i.to_string()
    Float(f) => "f" + typst_float_repr(f)
    Str(s) => typst_str_repr(s)
    Bytes(_) => "bytes"
    Seq(items) => "[" + items.map(canon).join(", ") + "]"
    Map(entries) => {
      let keys : Array[String] = []
      let values : Map[String, @serde.Data] = Map([])
      for entry in entries {
        let (k, v) = entry
        if !values.contains(k) {
          keys.push(k)
        }
        values.set(k, v)
      }
      "{" +
      keys
      .map(k => typst_str_repr(k) + ": " + canon(values.get(k).unwrap()))
      .join(", ") +
      "}"
    }
  }
}

///|
/// A float from its decimal representation (or `inf`, `-inf`, `nan`).
fn flt(s : String) -> @serde.Data {
  match s {
    "inf" => Float(@double.infinity)
    "-inf" => Float(@double.neg_infinity)
    "nan" => Float(@double.not_a_number)
    _ => Float(@string.parse_double(s) catch { _ => abort("bad float") })
  }
}

///|
fn show_error(err : @yaml.YamlError) -> String {
  let @yaml.YamlError(message~, location~) = err
  match location {
    Some(loc) => "err:\{message} at \{loc.line}:\{loc.column}"
    None => "err:\{message}"
  }
}

///|
fn show_parse(input : Bytes) -> String {
  try @yaml.parse(input) catch {
    err => show_error(err)
  } noraise {
    d => "ok:" + canon(d)
  }
}

///|
fn show_encode(value : @serde.Data) -> String {
  try @yaml.to_string(value) catch {
    @yaml.YamlError(message~, ..) => "err:" + message
  } noraise {
    s => "ok:" + s
  }
}
