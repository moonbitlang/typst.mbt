// Port of `typst-library/src/loading/csv.rs`.

///|
fn impl_csv__delimiter_default() -> Delimiter {
  Delimiter::default()
}

///|
fn impl_csv__row_type_default() -> RowType {
  RowArray
}

///|
/// Reads structured data from a CSV file.
///
/// The CSV file will be read and parsed into a 2-dimensional array of
/// strings: Each row in the CSV file will be represented as an array of
/// strings, and all rows will be collected into a single array. Header rows
/// will not be stripped.
fn impl_csv(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
  delimiter_ : Delimiter,
  row_type_ : RowType,
) -> Arr raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  let has_headers = row_type_ == RowDict
  let reader = @csv.Reader::new(
    loaded.data,
    delimiter=delimiter_.0.to_int().to_byte(),
    has_headers~,
  )

  // Counting lines from 1 by default.
  let mut line_offset = 1
  let mut headers : Array[String]? = None
  if has_headers {
    // Counting lines from 2 because we have a header.
    line_offset += 1
    headers = Some(
      within(loaded, () => {
        reader.headers() catch {
          err => raise LoadErr(format_csv_error(err, 1))
        }
      }),
    )
  }
  let array : Array[Value] = []
  let mut line = 0
  while true {
    // Original solution was to use line from error, but that is incorrect
    // with `has_headers` set to `false`. See issue:
    // https://github.com/BurntSushi/rust-csv/issues/184
    let current = line + line_offset
    let row = within(loaded, () => {
      reader.read_record() catch {
        err => raise LoadErr(format_csv_error(err, current))
      }
    })
    guard row is Some(row) else { break }
    line += 1
    let item : Value = match headers {
      Some(headers) => {
        let dict = Dict::new()
        let n = if headers.length() < row.length() {
          headers.length()
        } else {
          row.length()
        }
        for i in 0..<n {
          dict.insert(headers[i], Str(row[i]))
        }
        Dict(dict)
      }
      None => Array(Arr::from_array(row.map(field => Value::Str(field))))
    }
    array.push(item)
  }
  Arr::from_array(array)
}

///|
/// The delimiter to use when parsing CSV files.
pub(all) struct Delimiter(Char) derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Delimiter with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Delimiter with Hash::{hash, hash_combine}

///|
pub fn Delimiter::default() -> Delimiter {
  Delimiter(',')
}

///|
pub impl Reflect for Delimiter with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for Delimiter with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for Delimiter with fn castable(v) {
  reflect_castable((Ty::new() : Ty[String]), v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Delimiter with Reflect::{output, input, castable}

///|
pub impl IntoValue for Delimiter with fn into_value(self) {
  Str(self.0.to_string())
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Delimiter with IntoValue::{into_value}

///|
pub impl FromValue for Delimiter with fn from_value(v) {
  if !reflect_castable((Ty::new() : Ty[String]), v) {
    raise HintedError(cast_error((Ty::new() : Ty[Delimiter]), v))
  }
  // Upstream `char` cast.
  let s : String = v.cast()
  let chars = s.to_array()
  guard chars.length() == 1 else { bail("expected exactly one character") }
  let c = chars[0]
  if c.to_int() < 0x80 {
    Delimiter(c)
  } else {
    bail("delimiter must be an ASCII character")
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Delimiter with FromValue::{from_value}

///|
/// The type of parsed rows.
///
/// (The variants are named `RowArray`/`RowDict` instead of upstream's
/// `Array`/`Dict` to avoid clashing with `Value::Array`/`Value::Dict`.)
pub(all) enum RowType {
  RowArray
  RowDict
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RowType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RowType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RowType with @debug.Debug::{to_repr}

///|
pub impl Reflect for RowType with fn input() {
  Type(Type::type_())
}

///|
pub impl Reflect for RowType with fn output() {
  Type(Type::type_())
}

///|
pub impl Reflect for RowType with fn castable(v) {
  v is Type(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RowType with Reflect::{output, input, castable}

///|
pub impl IntoValue for RowType with fn into_value(self) {
  match self {
    RowArray => Type(Type::array())
    RowDict => Type(Type::dict())
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RowType with IntoValue::{into_value}

///|
pub impl FromValue for RowType with fn from_value(v) {
  match v {
    Type(ty) =>
      if ty == Type::array() {
        RowArray
      } else if ty == Type::dict() {
        RowDict
      } else {
        bail("expected `array` or `dictionary`")
      }
    v => raise HintedError(cast_error((Ty::new() : Ty[RowType]), v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RowType with FromValue::{from_value}

///|
/// Format the user-facing CSV error message.
fn format_csv_error(err : @csv.CsvError, line : Int) -> LoadError {
  let msg = "failed to parse CSV"
  let @csv.CsvError(kind) = err
  let pos = match kind.position() {
    Some(pos) => ReportTextPos::Range(pos.byte, pos.byte)
    None => LineCol(LineCol::one_based(line, 1))
  }
  match kind {
    Utf8(..) => LoadError::text(pos, msg, "file is not valid UTF-8")
    UnequalLengths(expected_len~, len~, ..) => {
      let err = "found \{len} instead of \{expected_len} fields in line \{line}"
      LoadError::text(pos, msg, err)
    }
  }
}
