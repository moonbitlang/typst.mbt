// Port of `hayro-syntax/src/object/number.rs`: numbers.

///|
let powers_of_10 : ReadOnlyArray[Double] = [
  1.0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9, 1.0e10, 1.0e11,
  1.0e12, 1.0e13, 1.0e14, 1.0e15, 1.0e16, 1.0e17, 1.0e18, 1.0e19,
]

///|
/// A number.
pub(all) enum Number {
  Real(Double)
  Integer(Int64)
} derive(Eq, Debug)

///|
/// Returns the number as a f64.
pub fn Number::as_f64(self : Number) -> Double {
  match self {
    Real(r) => r
    Integer(i) => i.to_double()
  }
}

///|
/// Returns the number as a f32.
pub fn Number::as_f32(self : Number) -> Float {
  match self {
    Real(r) => Float::from_double(r)
    Integer(i) => Float::from_int64(i)
  }
}

///|
/// Returns the number as an i64 (truncating, saturating like Rust `as`).
pub fn Number::as_i64(self : Number) -> Int64 {
  match self {
    Real(r) => f64_to_i64_sat(r)
    Integer(i) => i
  }
}

///|
/// Rust's saturating `f64 as i64`.
fn f64_to_i64_sat(r : Double) -> Int64 {
  if r.is_nan() {
    0L
  } else if r >= 9223372036854775807.0 {
    9223372036854775807L
  } else if r <= -9223372036854775808.0 {
    -9223372036854775807L - 1L
  } else {
    r.to_int64()
  }
}

///|
/// Create a new `Number` from an f32 number.
pub fn Number::from_f32(num : Float) -> Number {
  Real(num.to_double())
}

///|
/// Create a new `Number` from an i32 number.
pub fn Number::from_i32(num : Int) -> Number {
  Integer(num.to_int64())
}

///|
fn is_digit(byte : Byte) -> Bool {
  byte is (b'0'..=b'9')
}

///|
fn is_digit_or_minus(byte : Byte) -> Bool {
  is_digit(byte) || byte == b'-'
}

///|
fn skip_number(r : Reader) -> Unit? {
  let has_sign = r.forward_if(b => b == b'+' || b == b'-') is Some(_)
  // Some PDFs have weird trailing minuses, so try to accept those as well.
  guard r.peek_byte() is Some(peeked) else { return None }
  match peeked {
    b'.' => {
      guard r.read_byte() is Some(_) else { return None }
      // See PDFJS-9252 - treat a single . as 0.
      r.forward_while(is_digit_or_minus)
    }
    b'0'..=b'9' | b'-' => {
      guard r.forward_while_1(is_digit_or_minus) is Some(_) else { return None }
      if r.forward_tag(b".") is Some(_) {
        r.forward_while(is_digit_or_minus)
      }
    }
    // See PDFJS-bug1753983 - accept just + or - as a zero.
    // ALso see PDFJS-bug1953099, where the sign is followed by a show
    // text string operand, requiring us to allow '<' and '(' as well.
    b if has_sign && (is_white_space_character(b) || b is (b'(' | b'<')) => ()
    _ => return None
  }
  // See issue 994. Don't accept numbers that are followed by a regular character.
  if r.peek_byte() is Some(b) && is_regular_character(b) {
    return None
  }
  Some(())
}

///|
pub impl Skippable for Number with fn skip(r, _) {
  skip_number(r)
}

///|
pub impl Readable for Number with fn read(r, _) {
  let old_offset = r.offset()
  match read_number_inner(r) {
    Some(n) => Some(n)
    None => {
      r.jump(old_offset)
      None
    }
  }
}

///|
fn read_number_inner(r : Reader) -> Number? {
  guard r.peek_byte() is Some(peeked) else { return None }
  let negative = match peeked {
    b'-' => {
      r.forward()
      true
    }
    b'+' => {
      r.forward()
      false
    }
    _ => false
  }
  let mut mantissa : UInt64 = 0
  let mut has_dot = false
  let mut decimal_shift = 0
  let mut has_digits = false
  while true {
    match r.peek_byte() {
      Some(b'0'..=b'9') => {
        let d = r.read_byte().unwrap()
        mantissa = mantissa * 10UL + (d.to_int() - 48).to_uint64()
        has_digits = true
        if has_dot {
          decimal_shift += 1
        }
      }
      Some(b'.') if !has_dot => {
        r.forward()
        has_dot = true
      }
      // Some weird PDFs have trailing minus in the fraction of number.
      Some(b'-') if has_digits => {
        r.forward()
        r.forward_while(is_digit_or_minus)
        break
      }
      _ => break
    }
  }
  if !has_digits {
    if negative || has_dot {
      // Treat numbers like just `-`, `+` or `-.` as zero.
      return Some(Integer(0))
    }
    return None
  }
  // See issue 994. Don't accept numbers that are followed by a regular character
  // without any white space in-between.
  if r.peek_byte() is Some(b) && is_regular_character(b) {
    return None
  }
  if !has_dot {
    let value = if negative {
      -mantissa.reinterpret_as_int64()
    } else {
      mantissa.reinterpret_as_int64()
    }
    Some(Integer(value))
  } else {
    let mut value = mantissa.to_double()
    if decimal_shift > 0 {
      if decimal_shift < powers_of_10.length() {
        value = value / powers_of_10[decimal_shift]
      } else {
        value = value / powi_f64(10.0, decimal_shift)
      }
    }
    if negative {
      value = -value
    }
    Some(Real(value))
  }
}

///|
fn powi_f64(x : Double, n : Int) -> Double {
  let mut result = 1.0
  let mut base = x
  let mut exp = n
  while exp > 0 {
    if (exp & 1) == 1 {
      result = result * base
    }
    base = base * base
    exp = exp >> 1
  }
  result
}

///|
pub impl ObjectLike for Number with fn from_object(o) {
  match o {
    Number(n) => Some(n)
    _ => None
  }
}

///|
/// Skip an integer (`int_num!` skip).
fn skip_int(r : Reader) -> Unit? {
  r.forward_if(b => b == b'+' || b == b'-') |> ignore
  guard r.forward_while_1(is_digit) is Some(_) else { return None }
  // We have a float instead of an integer.
  if r.peek_byte() is Some(b'.') {
    return None
  }
  // See issue 994. Don't accept numbers that are followed by a regular character
  // without any white space in-between.
  if r.peek_byte() is Some(b) && is_regular_character(b) {
    return None
  }
  Some(())
}

///|
fn read_int_in_range(r : Reader, min : Int64, max : Int64) -> Int64? {
  guard (r.read_without_context() : Number?) is Some(n) else { return None }
  let v = n.as_i64()
  if v >= min && v <= max {
    Some(v)
  } else {
    None
  }
}

///|
fn int_from_object(o : Object, min : Int64, max : Int64) -> Int64? {
  match o {
    Number(n) => {
      let v = n.as_i64()
      if v >= min && v <= max {
        Some(v)
      } else {
        None
      }
    }
    _ => None
  }
}

// `i32`.

///|
pub impl Readable for Int with fn read(r, _) {
  read_int_in_range(r, -2147483648L, 2147483647L).map(v => v.to_int())
}

///|
pub impl Skippable for Int with fn skip(r, _) {
  skip_int(r)
}

///|
pub impl ObjectLike for Int with fn from_object(o) {
  int_from_object(o, -2147483648L, 2147483647L).map(v => v.to_int())
}

// `i64`.

///|
pub impl Readable for Int64 with fn read(r, _) {
  guard (r.read_without_context() : Number?) is Some(n) else { return None }
  Some(n.as_i64())
}

///|
pub impl ObjectLike for Int64 with fn from_object(o) {
  match o {
    Number(n) => Some(n.as_i64())
    _ => None
  }
}

// `u32`.

///|
pub impl Readable for UInt with fn read(r, _) {
  read_int_in_range(r, 0L, 4294967295L).map(v => {
    v.reinterpret_as_uint64().to_uint()
  })
}

///|
pub impl ObjectLike for UInt with fn from_object(o) {
  int_from_object(o, 0L, 4294967295L).map(v => {
    v.reinterpret_as_uint64().to_uint()
  })
}

// `usize`.

///|
pub impl Readable for UInt64 with fn read(r, _) {
  guard (r.read_without_context() : Number?) is Some(n) else { return None }
  let v = n.as_i64()
  if v >= 0L {
    Some(v.reinterpret_as_uint64())
  } else {
    None
  }
}

///|
pub impl ObjectLike for UInt64 with fn from_object(o) {
  match o {
    Number(n) => {
      let v = n.as_i64()
      if v >= 0L {
        Some(v.reinterpret_as_uint64())
      } else {
        None
      }
    }
    _ => None
  }
}

// `u16`.

///|
pub impl Readable for UInt16 with fn read(r, _) {
  read_int_in_range(r, 0L, 65535L).map(v => v.to_int().to_uint16())
}

///|
pub impl ObjectLike for UInt16 with fn from_object(o) {
  int_from_object(o, 0L, 65535L).map(v => v.to_int().to_uint16())
}

// `u8`.

///|
pub impl Readable for Byte with fn read(r, _) {
  read_int_in_range(r, 0L, 255L).map(v => v.to_int().to_byte())
}

///|
pub impl ObjectLike for Byte with fn from_object(o) {
  int_from_object(o, 0L, 255L).map(v => v.to_int().to_byte())
}

// `f32`.

///|
pub impl Skippable for Float with fn skip(r, _) {
  skip_number(r)
}

///|
pub impl Readable for Float with fn read(r, _) {
  guard (r.read_without_context() : Number?) is Some(n) else { return None }
  Some(Float::from_double(n.as_f64()))
}

///|
pub impl ObjectLike for Float with fn from_object(o) {
  match o {
    Number(n) => Some(Float::from_double(n.as_f64()))
    _ => None
  }
}

// `f64`.

///|
pub impl Readable for Double with fn read(r, _) {
  guard (r.read_without_context() : Number?) is Some(n) else { return None }
  Some(n.as_f64())
}

///|
pub impl ObjectLike for Double with fn from_object(o) {
  match o {
    Number(n) => Some(n.as_f64())
    _ => None
  }
}
