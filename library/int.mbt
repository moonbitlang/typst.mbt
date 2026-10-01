// Port of `typst-library/src/foundations/int.rs`: the `int` type's
// constructor, methods and constants, plus `Endianness` and `ToInt`.

///|
/// The maximum integer (`int.max`).
fn impl_i64_const_max() -> Value {
  Int(@int64.MAX_VALUE)
}

///|
/// The minimum integer (`int.min`).
fn impl_i64_const_min() -> Value {
  Int(@int64.MIN_VALUE)
}

///|
/// Default of `int(base:)`: `Spanned::new(Base::Default, Span::detached())`.
fn impl_i64_construct__base_default() -> @syntax.Spanned[Base] raise SourceError {
  { v: Default, span: @syntax.Span::detached(), }
}

///|
/// Converts a value to an integer. Raises an error if there is an attempt
/// to parse an invalid string or produce an integer that doesn't fit into a
/// 64-bit signed integer.
fn impl_i64_construct(
  value_ : @syntax.Spanned[ToInt],
  base_ : @syntax.Spanned[Base],
) -> Int64 raise SourceError {
  match value_.v {
    Int(n) =>
      match base_.v {
        User(_) => bail_at(base_.span, "base is only supported for strings")
        Default => n
      }
    Str(s) => {
      let base_value = base_.v.value()
      let radix = if base_value >= 2L && base_value <= 36L {
        base_value.to_int()
      } else {
        bail_at(base_.span, "base must be between 2 and 36")
      }
      let digits = if s.has_prefix("-") {
        Some(s.unsafe_substring(start=1, end=s.length()))
      } else if s.has_prefix(minus_sign) {
        Some(s.unsafe_substring(start=minus_sign.length(), end=s.length()))
      } else {
        None
      }
      match digits {
        // Negative (without minus)
        Some(s) => {
          // Parse the digits part into u64
          //  => abs(i64::MIN) fits into u64
          let bigger = u64_from_str_radix(s, radix) catch {
            kind => raise parse_str_error(kind, base_).into_source(value_.span)
          }
          // Number wouldn't fit into i64
          if bigger > 0x8000_0000_0000_0000UL {
            raise parse_str_error(NegOverflow, base_).into_source(value_.span)
          }
          (0UL - bigger).reinterpret_as_int64()
        }
        // Positive
        None =>
          i64_from_str_radix(s, radix) catch {
            kind => raise parse_str_error(kind, base_).into_source(value_.span)
          }
      }
    }
  }
}

///|
/// Convert a hinted string into a source error at a span.
fn HintedString::into_source(
  self : HintedString,
  span : @syntax.Span,
) -> SourceError {
  SourceError([self.into_error_at(span)])
}

///|
/// Calculates the sign of an integer.
fn impl_i64_signum(self_ : Int64) -> Int64 raise HintedError {
  if self_ > 0L {
    1L
  } else if self_ < 0L {
    -1L
  } else {
    0L
  }
}

///|
/// Calculates the bitwise NOT of an integer.
fn impl_i64_bit_not(self_ : Int64) -> Int64 raise HintedError {
  self_.lnot()
}

///|
/// Calculates the bitwise AND between two integers.
fn impl_i64_bit_and(self_ : Int64, rhs_ : Int64) -> Int64 raise HintedError {
  self_ & rhs_
}

///|
/// Calculates the bitwise OR between two integers.
fn impl_i64_bit_or(self_ : Int64, rhs_ : Int64) -> Int64 raise HintedError {
  self_ | rhs_
}

///|
/// Calculates the bitwise XOR between two integers.
fn impl_i64_bit_xor(self_ : Int64, rhs_ : Int64) -> Int64 raise HintedError {
  self_ ^ rhs_
}

///|
/// Shifts the operand's bits to the left by the specified amount.
fn impl_i64_bit_lshift(self_ : Int64, shift_ : U32) -> Int64 raise HintedError {
  // Rust's `checked_shl` only fails if the shift exceeds the bit width.
  let shift = shift_.get()
  if shift >= 64L {
    bail("the result is too large")
  }
  self_ << shift.to_int()
}

///|
/// Shifts the operand's bits to the right by the specified amount.
fn impl_i64_bit_rshift(
  self_ : Int64,
  shift_ : U32,
  logical_ : Bool,
) -> Int64 raise HintedError {
  let shift = shift_.get()
  if logical_ {
    if shift >= 64L {
      // Excessive logical right shift would be equivalent to setting
      // all bits to zero.
      0L
    } else {
      // Reinterpret the signed integer's bits as unsigned to perform a
      // logical right shift, and then reinterpret back as signed.
      (self_.reinterpret_as_uint64() >> shift.to_int()).reinterpret_as_int64()
    }
  } else {
    // Saturate at -1 (negative) or 0 (otherwise) on excessive arithmetic
    // right shift.
    let shift = if shift > 63L { 63 } else { shift.to_int() }
    self_ >> shift
  }
}

///|
/// Default of `int.from-bytes(endian:)`.
fn impl_i64_from_bytes__endian_default() -> Endianness raise SourceError {
  Little
}

///|
/// Converts bytes to an integer.
fn impl_i64_from_bytes(
  bytes_ : Value,
  endian_ : Endianness,
  signed_ : Bool,
) -> Int64 raise HintedError {
  let bytes = bytes_cast_b(bytes_)
  let len = bytes.length()
  if len == 0 {
    return 0L
  } else if len > 8 {
    bail("too many bytes to convert to a 64 bit number")
  }

  // `decimal` will hold the part of the buffer that should be filled with
  // the input bytes, `rest` will remain as is or be filled with 0xFF for
  // negative numbers if signed is true.
  //
  // - big-endian: `decimal` will be the rightmost bytes of the buffer.
  // - little-endian: `decimal` will be the leftmost bytes of the buffer.
  let buf = FixedArray::make(8, b'\x00')
  let (decimal_start, rest_start, rest_end) = match endian_ {
    Big => (8 - len, 0, 8 - len)
    Little => (0, len, 8)
  }
  for i in 0..<len {
    buf[decimal_start + i] = bytes[i]
  }

  // Perform sign-extension if necessary.
  if signed_ {
    let most_significant_byte = match endian_ {
      Big => buf[decimal_start]
      Little => buf[decimal_start + len - 1]
    }
    if (most_significant_byte.to_int() & 0b1000_0000) != 0 {
      for i in rest_start..<rest_end {
        buf[i] = b'\xFF'
      }
    }
  }
  let mut out = 0UL
  for i in 0..<8 {
    let byte = match endian_ {
      Big => buf[i]
      Little => buf[7 - i]
    }
    out = (out << 8) | byte.to_uint64()
  }
  out.reinterpret_as_int64()
}

///|
/// Default of `int.to-bytes(endian:)`.
fn impl_i64_to_bytes__endian_default() -> Endianness raise SourceError {
  Little
}

///|
/// Converts an integer to bytes.
fn impl_i64_to_bytes(
  self_ : Int64,
  endian_ : Endianness,
  size_ : USize,
) -> Value raise HintedError {
  let array = int64_to_bytes(self_, endian_)
  let size = size_.get().to_int()
  let buf = FixedArray::make(size, b'\x00')
  match endian_ {
    Big => {
      // Copy the bytes from the array to the buffer, starting from the end
      // of the buffer.
      let buf_start = if size > 8 { size - 8 } else { 0 }
      let array_start = if size < 8 { 8 - size } else { 0 }
      for i in 0..<(8 - array_start) {
        buf[buf_start + i] = array[array_start + i]
      }
    }
    Little => {
      // Copy the bytes from the array to the buffer, starting from the
      // beginning of the buffer.
      let end = if size < 8 { size } else { 8 }
      for i in 0..<end {
        buf[i] = array[i]
      }
    }
  }
  bytes_into_value_b(Bytes::from_array(buf))
}

///|
/// The 8 bytes of an integer in the given byte order (Rust's
/// `i64::to_{be,le}_bytes`).
fn int64_to_bytes(n : Int64, endian : Endianness) -> FixedArray[Byte] {
  let u = n.reinterpret_as_uint64()
  FixedArray::makei(8, i => {
    let shift = match endian {
      Big => (7 - i) * 8
      Little => i * 8
    }
    ((u >> shift) & 0xFFUL).to_byte()
  })
}

///|
/// Upstream `Repr for i64` is [repr_int].

///|
/// Represents the byte order used for converting integers and floats to bytes
/// and vice versa.
pub(all) enum Endianness {
  /// Big-endian byte order: The highest-value byte is at the beginning of the
  /// bytes.
  Big
  /// Little-endian byte order: The lowest-value byte is at the beginning of
  /// the bytes.
  Little
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for Endianness with fn input() {
  Union([
    Value(
      Str("big"),
      "Big-endian byte order: The highest-value byte is at the beginning of the\nbytes.",
    ),
    Value(
      Str("little"),
      "Little-endian byte order: The lowest-value byte is at the beginning of\nthe bytes.",
    ),
  ])
}

///|
pub impl Reflect for Endianness with fn output() {
  Endianness::input()
}

///|
pub impl Reflect for Endianness with fn castable(v) {
  v is Str("big" | "little")
}

///|
pub impl IntoValue for Endianness with fn into_value(self) {
  match self {
    Big => Str("big")
    Little => Str("little")
  }
}

///|
pub impl FromValue for Endianness with fn from_value(v) {
  match v {
    Str("big") => Big
    Str("little") => Little
    v => raise HintedError(Endianness::input().error(v))
  }
}

///|
/// A value that can be cast to an integer.
pub(all) enum ToInt {
  Int(Int64)
  Str(String)
}

///|
pub impl Reflect for ToInt with fn input() {
  CastInfo::Type(Type::int())
  .union_with(Type(Type::bool()))
  .union_with(Type(Type::float()))
  .union_with(Type(Type::decimal()))
  .union_with(Type(Type::str()))
}

///|
pub impl Reflect for ToInt with fn output() {
  ToInt::input()
}

///|
pub impl Reflect for ToInt with fn castable(v) {
  v is (Int(_) | Bool(_) | Float(_) | Decimal(_) | Str(_) | Symbol(_))
}

///|
pub impl FromValue for ToInt with fn from_value(v) {
  match v {
    Int(v) => Int(v)
    Bool(v) => Int(if v { 1L } else { 0L })
    Float(v) => Int(convert_float_to_int(v))
    Decimal(v) =>
      match v.to_i64() {
        Some(i) => Int(i)
        None => bail("number too large")
      }
    Str(_) | Symbol(_) => Str((FromValue::from_value(v) : String))
    v => raise HintedError(ToInt::input().error(v))
  }
}

///|
/// Convert a float to an integer, failing if it is out of range (upstream
/// `convert_float_to_int`).
pub fn convert_float_to_int(f : Double) -> Int64 raise HintedError {
  // `i64::MIN as f64 - 1.0` and `i64::MAX as f64 + 1.0` round to -2^63 and
  // 2^63.
  if f <= -9223372036854775808.0 || f >= 9223372036854775808.0 {
    bail("number too large")
  } else if f.is_nan() {
    // Rust's saturating `as` cast maps NaN to zero.
    0L
  } else {
    f.to_int64()
  }
}

///|
/// The error for a failed integer parse (upstream `parse_str_error`).
fn parse_str_error(
  kind : IntErrorKind,
  base : @syntax.Spanned[Base],
) -> HintedString {
  let base = base.v.value()
  match kind {
    Empty => HintedString::new("string must not be empty")
    InvalidDigit =>
      match base {
        10L => HintedString::new("string contains invalid digits")
        _ =>
          HintedString::new(
            "string contains invalid digits for a base \{base} integer",
          )
      }
    PosOverflow =>
      HintedString::new("integer value is too large")
      .with_hint("value does not fit into a signed 64-bit integer")
      .with_hint("try using a floating point number")
    NegOverflow =>
      HintedString::new("integer value is too small")
      .with_hint("value does not fit into a signed 64-bit integer")
      .with_hint("try using a floating point number")
    Zero => abort("unreachable")
  }
}
