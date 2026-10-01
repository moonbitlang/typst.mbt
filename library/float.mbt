// Port of `typst-library/src/foundations/float.rs`: the `float` type's
// constructor, methods and constants, plus `ToFloat`.

///|
/// Positive infinity (`float.inf`).
fn impl_f64_const_inf() -> Value {
  Float(@double.infinity)
}

///|
/// A NaN value, as defined by the IEEE 754 standard (`float.nan`).
fn impl_f64_const_nan() -> Value {
  Float(@double.not_a_number)
}

///|
/// Converts a value to a float.
fn impl_f64_construct(value_ : ToFloat) -> Double raise HintedError {
  value_.0
}

///|
/// Checks if a float is not a number.
fn impl_f64_is_nan(self_ : Double) -> Bool raise HintedError {
  self_.is_nan()
}

///|
/// Checks if a float is infinite.
fn impl_f64_is_infinite(self_ : Double) -> Bool raise HintedError {
  self_.is_inf()
}

///|
/// Calculates the sign of a floating point number (Rust's `f64::signum`).
fn impl_f64_signum(self_ : Double) -> Double raise HintedError {
  if self_.is_nan() {
    self_
  } else if self_.reinterpret_as_int64() < 0L {
    -1.0
  } else {
    1.0
  }
}

///|
/// Default of `float.from-bytes(endian:)`.
fn impl_f64_from_bytes__endian_default() -> Endianness raise SourceError {
  Little
}

///|
/// Interprets bytes as a float.
fn impl_f64_from_bytes(
  bytes_ : BytesValue,
  endian_ : Endianness,
) -> Double raise HintedError {
  let bytes = bytes_.as_slice()
  // Convert slice to an array of length 4 or 8.
  let len = bytes.length()
  if len == 8 || len == 4 {
    let mut bits = 0UL
    for i in 0..<len {
      let byte = match endian_ {
        Big => bytes[i]
        Little => bytes[len - 1 - i]
      }
      bits = (bits << 8) | byte.to_uint64()
    }
    if len == 8 {
      return bits.reinterpret_as_double()
    } else {
      return bits.to_uint().reinterpret_as_float().to_double()
    }
  }
  bail("bytes must have a length of 4 or 8")
}

///|
/// Default of `float.to-bytes(endian:)`.
fn impl_f64_to_bytes__endian_default() -> Endianness raise SourceError {
  Little
}

///|
/// Converts a float to bytes.
fn impl_f64_to_bytes(
  self_ : Double,
  endian_ : Endianness,
  size_ : U32,
) -> BytesValue raise HintedError {
  let (bits, len) = match size_.get() {
    8L => (self_.reinterpret_as_uint64(), 8)
    4L => (self_.to_float().reinterpret_as_uint().to_uint64(), 4)
    _ => bail("size must be either 4 or 8")
  }
  let buf = FixedArray::makei(len, i => {
    let shift = match endian_ {
      Big => (len - 1 - i) * 8
      Little => i * 8
    }
    ((bits >> shift) & 0xFFUL).to_byte()
  })
  BytesValue::new(Bytes::from_array(buf))
}

///|
/// A value that can be cast to a float.
pub(all) struct ToFloat(Double)

///|
pub impl Reflect for ToFloat with fn input() {
  CastInfo::Type(Type::float())
  .union_with(Type(Type::bool()))
  .union_with(Type(Type::int()))
  .union_with(Type(Type::decimal()))
  .union_with(Type(Type::ratio()))
  .union_with(Type(Type::str()))
}

///|
pub impl Reflect for ToFloat with fn output() {
  ToFloat::input()
}

///|
pub impl Reflect for ToFloat with fn castable(v) {
  v
  is (Float(_) | Int(_) | Bool(_) | Decimal(_) | Ratio(_) | Str(_) | Symbol(_))
}

///|
pub impl FromValue for ToFloat with fn from_value(v) {
  match v {
    Float(v) => ToFloat(v)
    Int(v) => ToFloat(v.to_double())
    Bool(v) => ToFloat(if v { 1.0 } else { 0.0 })
    Decimal(v) =>
      match v.to_f64() {
        Some(f) => ToFloat(f)
        None => bail("invalid float: \{v.to_string()}")
      }
    Ratio(v) => ToFloat(v.get())
    Str(_) | Symbol(_) => {
      let s = (FromValue::from_value(v) : String)
      match parse_float(s) {
        Some(f) => ToFloat(f)
        None => bail("invalid float: \{s}")
      }
    }
    v => raise HintedError(ToFloat::input().error(v))
  }
}

///|
/// Parse a float like Rust's `str::parse::<f64>` after replacing the Unicode
/// minus sign (upstream `parse_float`).
fn parse_float(s : String) -> Double? {
  rust_parse_f64(s.replace_all(old=minus_sign, new="-"))
}

///|
/// Rust's `str::parse::<f64>`: an optional sign followed by `inf`,
/// `infinity`, `nan` (case-insensitive) or a decimal number with an optional
/// fraction and exponent.
pub fn rust_parse_f64(s : String) -> Double? {
  let n = s.length()
  let mut i = 0
  let mut negative = false
  if i < n && (s.code_unit_at(i) == '+' || s.code_unit_at(i) == '-') {
    negative = s.code_unit_at(i) == '-'
    i += 1
  }
  let rest = s.unsafe_substring(start=i, end=n).to_lower()
  if rest == "inf" || rest == "infinity" {
    return Some(if negative { -@double.infinity } else { @double.infinity })
  }
  if rest == "nan" {
    return Some(@double.not_a_number)
  }
  let is_digit = (j : Int) => {
    j < n && s.code_unit_at(j) >= '0' && s.code_unit_at(j) <= '9'
  }
  let int_start = i
  while is_digit(i) {
    i += 1
  }
  let int_digits = i - int_start
  let mut frac_digits = 0
  let mut frac_start = i
  if i < n && s.code_unit_at(i) == '.' {
    i += 1
    frac_start = i
    while is_digit(i) {
      i += 1
    }
    frac_digits = i - frac_start
  }
  if int_digits == 0 && frac_digits == 0 {
    return None
  }
  let mut exp = ""
  if i < n && (s.code_unit_at(i) == 'e' || s.code_unit_at(i) == 'E') {
    i += 1
    let exp_start = i
    if i < n && (s.code_unit_at(i) == '+' || s.code_unit_at(i) == '-') {
      i += 1
    }
    let digits_start = i
    while is_digit(i) {
      i += 1
    }
    if i == digits_start {
      return None
    }
    exp = "e" + s.unsafe_substring(start=exp_start, end=i)
  }
  if i != n {
    return None
  }
  // Normalize into a form every decimal parser accepts.
  let int_part = if int_digits == 0 {
    "0"
  } else {
    s.unsafe_substring(start=int_start, end=int_start + int_digits)
  }
  let frac_part = if frac_digits == 0 {
    "0"
  } else {
    s.unsafe_substring(start=frac_start, end=frac_start + frac_digits)
  }
  let text = (if negative { "-" } else { "" }) +
    int_part +
    "." +
    frac_part +
    exp
  // The syntax is valid, so a failure means the value is out of range,
  // which Rust maps to infinity.
  Some(@string.parse_double(text)) catch {
    _ => Some(if negative { -@double.infinity } else { @double.infinity })
  }
}
