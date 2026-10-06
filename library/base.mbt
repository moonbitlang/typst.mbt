// Port of `Base` (typst-library/src/foundations/str.rs) and of Rust's integer
// parsing in a radix (`i64::from_str_radix`, `u64::from_str_radix`), shared
// by the ports of int.rs and str.rs. Formatting in a radix is
// [format_int_with_base] (repr.rs).

///|
/// Similar to `Option<i64>`, but the default value casts to `10` rather than
/// `none`, so that the right default value is documented.
pub(all) enum Base {
  Default
  User(Int64)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Base with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Base with @debug.Debug::{to_repr}

///|
/// The numeric value of the base.
pub fn Base::value(self : Base) -> Int64 {
  match self {
    Default => 10L
    User(b) => b
  }
}

///|
pub impl Reflect for Base with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for Base with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for Base with fn castable(v) {
  v is Int(_)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Base with Reflect::{output, input, castable}

///|
pub impl IntoValue for Base with fn into_value(self) {
  Int(self.value())
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Base with IntoValue::{into_value}

///|
pub impl FromValue for Base with fn from_value(v) {
  match v {
    Int(v) => User(v)
    v => cast_fail_with(Type(Type::int()), v)
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Base with FromValue::{from_value}

///|
/// Rust's `std::num::IntErrorKind`.
pub(all) suberror IntErrorKind {
  /// Value being parsed is empty.
  Empty
  /// Contains an invalid digit in its context.
  InvalidDigit
  /// Integer is too large to store in target integer type.
  PosOverflow
  /// Integer is too small to store in target integer type.
  NegOverflow
  /// Value was zero (for non-zero types).
  Zero
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IntErrorKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IntErrorKind with @debug.Debug::{to_repr}

///|
/// Rust's `char::to_digit` applied to a UTF-16 code unit.
fn radix_digit(c : Int, radix : Int) -> Int? {
  let d = if c >= '0'.to_int() && c <= '9'.to_int() {
    c - '0'.to_int()
  } else if c >= 'a'.to_int() && c <= 'z'.to_int() {
    c - 'a'.to_int() + 10
  } else if c >= 'A'.to_int() && c <= 'Z'.to_int() {
    c - 'A'.to_int() + 10
  } else {
    return None
  }
  if d < radix {
    Some(d)
  } else {
    None
  }
}

///|
/// Split off Rust's optional sign for `from_str_radix`. Returns whether the
/// number is positive and where the digits start.
fn radix_sign(s : String, signed : Bool) -> (Bool, Int) raise IntErrorKind {
  if s.is_empty() {
    raise Empty
  }
  let first = s.code_unit_at(0).to_int()
  let plus = '+'.to_int()
  let minus = '-'.to_int()
  if (first == plus || first == minus) && s.length() == 1 {
    raise InvalidDigit
  }
  if first == plus {
    (true, 1)
  } else if first == minus && signed {
    (false, 1)
  } else {
    (true, 0)
  }
}

///|
/// Rust's `i64::from_str_radix` (`radix` must be in `2..=36`).
pub fn i64_from_str_radix(s : String, radix : Int) -> Int64 raise IntErrorKind {
  let (positive, start) = radix_sign(s, true)
  let r = radix.to_int64()
  let max = @int64.MAX_VALUE
  let min = @int64.MIN_VALUE
  let mut result = 0L
  for i in start..<s.length() {
    let d = match radix_digit(s.code_unit_at(i).to_int(), radix) {
      Some(d) => d.to_int64()
      None => raise InvalidDigit
    }
    if positive {
      if result > max / r {
        raise PosOverflow
      }
      result = result * r
      if result > max - d {
        raise PosOverflow
      }
      result = result + d
    } else {
      if result < min / r {
        raise NegOverflow
      }
      result = result * r
      if result < min + d {
        raise NegOverflow
      }
      result = result - d
    }
  }
  result
}

///|
/// Rust's `u64::from_str_radix` (`radix` must be in `2..=36`).
pub fn u64_from_str_radix(s : String, radix : Int) -> UInt64 raise IntErrorKind {
  let (_, start) = radix_sign(s, false)
  let r = radix.to_uint64()
  let max = 0xFFFF_FFFF_FFFF_FFFFUL
  let mut result = 0UL
  for i in start..<s.length() {
    let d = match radix_digit(s.code_unit_at(i).to_int(), radix) {
      Some(d) => d.to_uint64()
      None => raise InvalidDigit
    }
    if result > max / r {
      raise PosOverflow
    }
    result = result * r
    if result > max - d {
      raise PosOverflow
    }
    result = result + d
  }
  result
}
