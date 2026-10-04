// Port of `typst-library/src/foundations/ops.rs`: operations on values.

///|
fn[T] mismatch(fmt : String) -> T raise HintedError {
  bail(fmt)
}

///|
fn too_large() -> String {
  "value is too large"
}

///|
fn checked_add_i64(a : Int64, b : Int64) -> Int64 raise HintedError {
  let r = a + b
  if (a >= 0L) == (b >= 0L) && (r >= 0L) != (a >= 0L) {
    bail(too_large())
  }
  r
}

///|
fn checked_sub_i64(a : Int64, b : Int64) -> Int64 raise HintedError {
  let r = a - b
  if (a >= 0L) != (b >= 0L) && (r >= 0L) != (a >= 0L) {
    bail(too_large())
  }
  r
}

///|
fn checked_mul_i64(a : Int64, b : Int64) -> Int64 raise HintedError {
  if a == 0L || b == 0L {
    return 0L
  }
  let r = a * b
  if r / b != a ||
    (a == -1L && b == @int64.min_value) ||
    (b == -1L && a == @int64.min_value) {
    bail(too_large())
  }
  r
}

///|
/// Compare strings by code points (= UTF-8 byte order, like Rust).
pub fn compare_str(a : String, b : String) -> Int {
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let { cp: ca, idx: ni, } = @unicode.decode_at(a, i)
    let { cp: cb, idx: nj, } = @unicode.decode_at(b, j)
    if ca != cb {
      return if ca < cb { -1 } else { 1 }
    }
    i = ni
    j = nj
  }
  if i < a.length() {
    1
  } else if j < b.length() {
    -1
  } else {
    0
  }
}

///|
/// Join a value with another value.
pub fn join(lhs : Value, rhs : Value) -> Value raise HintedError {
  match (lhs, rhs) {
    (a, None) => a
    (None, b) => b
    (Symbol(a), Symbol(b)) => Str(a.get() + b.get())
    (Str(a), Str(b)) => Str(a + b)
    (Str(a), Symbol(b)) => Str(a + b.get())
    (Symbol(a), Str(b)) => Str(a.get() + b)
    (Bytes(a), Bytes(b)) => Bytes(a.concat(b))
    (Content(a), Content(b)) => Content(a.add(b))
    (Content(a), Symbol(b)) => Content(a.add(SymbolElem::packed(b.get())))
    (Content(a), Str(b)) => Content(a.add(TextElem::packed(b)))
    (Str(a), Content(b)) => Content(TextElem::packed(a).add(b))
    (Symbol(a), Content(b)) => Content(SymbolElem::packed(a.get()).add(b))
    (Array(a), Array(b)) => Array(a.concat(b))
    (Dict(a), Dict(b)) => Dict(a.merge(b))
    (Args(a), Args(b)) => Args(a.merge(b))
    (a, b) => mismatch("cannot join \{a.ty()} with \{b.ty()}")
  }
}

///|
/// Unwraps the result of a checked decimal operation (upstream
/// `.ok_or_else(too_large)?`).
fn decimal_or_too_large(result : Decimal?) -> Decimal raise HintedError {
  match result {
    Some(d) => d
    None => bail(too_large())
  }
}

///|
/// Apply the unary plus operator to a value.
pub fn pos(value : Value) -> Value raise HintedError {
  match value {
    Int(_)
    | Float(_)
    | Decimal(_)
    | Length(_)
    | Angle(_)
    | Ratio(_)
    | Relative(_)
    | Fraction(_) => value
    Symbol(_)
    | Str(_)
    | Bytes(_)
    | Content(_)
    | Array(_)
    | Dict(_)
    | Datetime(_) => mismatch("cannot apply unary '+' to \{value.ty()}")
    Dyn(d) =>
      if d.is_alignment() {
        mismatch("cannot apply unary '+' to \{d.ty()}")
      } else {
        mismatch("cannot apply '+' to \{d.ty()}")
      }
    v => mismatch("cannot apply '+' to \{v.ty()}")
  }
}

///|
/// Compute the negation of a value.
pub fn neg(value : Value) -> Value raise HintedError {
  match value {
    Int(v) => if v == @int64.min_value { bail(too_large()) } else { Int(-v) }
    Float(v) => Float(-v)
    Decimal(v) => Decimal(v.neg())
    Length(v) => Length(-v)
    Angle(v) => Angle(-v)
    Ratio(v) => Ratio(-v)
    Relative(v) => Relative(-v)
    Fraction(v) => Fraction(-v)
    Duration(v) => Duration(v.neg())
    Datetime(_) => mismatch("cannot apply unary '-' to \{value.ty()}")
    v => mismatch("cannot apply '-' to \{v.ty()}")
  }
}

///|
/// Compute the sum of two values.
pub fn add(lhs : Value, rhs : Value) -> Value raise HintedError {
  match (lhs, rhs) {
    (a, None) => a
    (None, b) => b
    (Int(a), Int(b)) => Int(checked_add_i64(a, b))
    (Int(a), Float(b)) => Float(a.to_double() + b)
    (Float(a), Int(b)) => Float(a + b.to_double())
    (Float(a), Float(b)) => Float(a + b)
    (Decimal(a), Decimal(b)) => Decimal(decimal_or_too_large(a.checked_add(b)))
    (Decimal(a), Int(b)) =>
      Decimal(decimal_or_too_large(a.checked_add(Decimal::from_int(b))))
    (Int(a), Decimal(b)) =>
      Decimal(decimal_or_too_large(Decimal::from_int(a).checked_add(b)))
    (Angle(a), Angle(b)) => Angle(a + b)
    (Length(a), Length(b)) => Length(a + b)
    (Length(a), Ratio(b)) => Relative(Rel::from_ratio(b) + Rel::from_abs(a))
    (Length(a), Relative(b)) => Relative(b + Rel::from_abs(a))
    (Ratio(a), Length(b)) => Relative(Rel::from_ratio(a) + Rel::from_abs(b))
    (Ratio(a), Ratio(b)) => Ratio(a + b)
    (Ratio(a), Relative(b)) => Relative(b + Rel::from_ratio(a))
    (Relative(a), Length(b)) => Relative(a + Rel::from_abs(b))
    (Relative(a), Ratio(b)) => Relative(a + Rel::from_ratio(b))
    (Relative(a), Relative(b)) => Relative(a + b)
    (Fraction(a), Fraction(b)) => Fraction(a + b)
    (Symbol(a), Symbol(b)) => Str(a.get() + b.get())
    (Str(a), Str(b)) => Str(a + b)
    (Str(a), Symbol(b)) => Str(a + b.get())
    (Symbol(a), Str(b)) => Str(a.get() + b)
    (Bytes(a), Bytes(b)) => Bytes(a.concat(b))
    (Content(a), Content(b)) => Content(a.add(b))
    (Content(a), Symbol(b)) => Content(a.add(SymbolElem::packed(b.get())))
    (Content(a), Str(b)) => Content(a.add(TextElem::packed(b)))
    (Str(a), Content(b)) => Content(TextElem::packed(a).add(b))
    (Symbol(a), Content(b)) => Content(SymbolElem::packed(a.get()).add(b))
    (Array(a), Array(b)) => Array(a.concat(b))
    (Dict(a), Dict(b)) => Dict(a.merge(b))
    (Args(a), Args(b)) => Args(a.merge(b))
    (Color(_), Length(_))
    | (Length(_), Color(_))
    | (Gradient(_), Length(_))
    | (Length(_), Gradient(_))
    | (Tiling(_), Length(_))
    | (Length(_), Tiling(_)) => stroke_from_pair(lhs, rhs)
    (Duration(a), Duration(b)) => Duration(a.add(b))
    (Datetime(a), Duration(b)) => Datetime(a.add_duration(b))
    (Duration(a), Datetime(b)) => Datetime(b.add_duration(a))
    (Dyn(a), Dyn(b)) =>
      match a.add_dyn(b) {
        Some(v) => v
        None => mismatch("cannot add \{a.ty()} and \{b.ty()}")
      }
    (a, b) => mismatch("cannot add \{a.ty()} and \{b.ty()}")
  }
}

///|
/// Compute the difference of two values.
pub fn sub(lhs : Value, rhs : Value) -> Value raise HintedError {
  match (lhs, rhs) {
    (Int(a), Int(b)) => Int(checked_sub_i64(a, b))
    (Int(a), Float(b)) => Float(a.to_double() - b)
    (Float(a), Int(b)) => Float(a - b.to_double())
    (Float(a), Float(b)) => Float(a - b)
    (Decimal(a), Decimal(b)) => Decimal(decimal_or_too_large(a.checked_sub(b)))
    (Decimal(a), Int(b)) =>
      Decimal(decimal_or_too_large(a.checked_sub(Decimal::from_int(b))))
    (Int(a), Decimal(b)) =>
      Decimal(decimal_or_too_large(Decimal::from_int(a).checked_sub(b)))
    (Angle(a), Angle(b)) => Angle(a - b)
    (Length(a), Length(b)) => Length(a - b)
    (Length(a), Ratio(b)) => Relative(Rel::from_ratio(-b) + Rel::from_abs(a))
    (Length(a), Relative(b)) => Relative(-b + Rel::from_abs(a))
    (Ratio(a), Length(b)) => Relative(Rel::from_ratio(a) + Rel::from_abs(-b))
    (Ratio(a), Ratio(b)) => Ratio(a - b)
    (Ratio(a), Relative(b)) => Relative(-b + Rel::from_ratio(a))
    (Relative(a), Length(b)) => Relative(a + Rel::from_abs(-b))
    (Relative(a), Ratio(b)) => Relative(a + Rel::from_ratio(-b))
    (Relative(a), Relative(b)) => Relative(a - b)
    (Fraction(a), Fraction(b)) => Fraction(a - b)
    (Duration(a), Duration(b)) => Duration(a.sub(b))
    (Datetime(a), Duration(b)) => Datetime(a.sub_duration(b))
    (Datetime(a), Datetime(b)) => Duration(a.sub_datetime(b))
    (a, b) => mismatch("cannot subtract \{b.ty()} from \{a.ty()}")
  }
}

///|
/// Compute the product of two values.
pub fn mul(lhs : Value, rhs : Value) -> Value raise HintedError {
  match (lhs, rhs) {
    (Int(a), Int(b)) => Int(checked_mul_i64(a, b))
    (Int(a), Float(b)) => Float(a.to_double() * b)
    (Float(a), Int(b)) => Float(a * b.to_double())
    (Float(a), Float(b)) => Float(a * b)
    (Decimal(a), Decimal(b)) => Decimal(decimal_or_too_large(a.checked_mul(b)))
    (Decimal(a), Int(b)) =>
      Decimal(decimal_or_too_large(a.checked_mul(Decimal::from_int(b))))
    (Int(a), Decimal(b)) =>
      Decimal(decimal_or_too_large(Decimal::from_int(a).checked_mul(b)))
    (Length(a), Int(b)) => Length(a.times(b.to_double()))
    (Length(a), Float(b)) => Length(a.times(b))
    (Length(a), Ratio(b)) => Length(a.times(b.get()))
    (Int(a), Length(b)) => Length(b.times(a.to_double()))
    (Float(a), Length(b)) => Length(b.times(a))
    (Ratio(a), Length(b)) => Length(b.times(a.get()))
    (Angle(a), Int(b)) => Angle(a.times(b.to_double()))
    (Angle(a), Float(b)) => Angle(a.times(b))
    (Angle(a), Ratio(b)) => Angle(a.times(b.get()))
    (Int(a), Angle(b)) => Angle(b.times(a.to_double()))
    (Float(a), Angle(b)) => Angle(b.times(a))
    (Ratio(a), Angle(b)) => Angle(b.times(a.get()))
    (Ratio(a), Ratio(b)) => Ratio(a.mul_ratio(b))
    (Ratio(a), Int(b)) => Ratio(a.times(b.to_double()))
    (Ratio(a), Float(b)) => Ratio(a.times(b))
    (Int(a), Ratio(b)) => Ratio(b.times(a.to_double()))
    (Float(a), Ratio(b)) => Ratio(b.times(a))
    (Relative(a), Int(b)) => Relative(a.times(b.to_double()))
    (Relative(a), Float(b)) => Relative(a.times(b))
    (Relative(a), Ratio(b)) => Relative(a.times(b.get()))
    (Int(a), Relative(b)) => Relative(b.times(a.to_double()))
    (Float(a), Relative(b)) => Relative(b.times(a))
    (Ratio(a), Relative(b)) => Relative(b.times(a.get()))
    (Fraction(a), Int(b)) => Fraction(a.times(b.to_double()))
    (Fraction(a), Float(b)) => Fraction(a.times(b))
    (Fraction(a), Ratio(b)) => Fraction(a.times(b.get()))
    (Int(a), Fraction(b)) => Fraction(b.times(a.to_double()))
    (Float(a), Fraction(b)) => Fraction(b.times(a))
    (Ratio(a), Fraction(b)) => Fraction(b.times(a.get()))
    (Str(a), Int(b)) => Str(str_repeat(a, cast_usize(Int(b))))
    (Int(a), Str(b)) => Str(str_repeat(b, cast_usize(Int(a))))
    (Array(a), Int(b)) => Array(a.repeat(cast_usize(Int(b))))
    (Int(a), Array(b)) => Array(b.repeat(cast_usize(Int(a))))
    (Content(a), Int(b)) => Content(a.repeat(cast_usize(Int(b)).to_int()))
    (Int(a), Content(b)) => Content(b.repeat(cast_usize(Int(a)).to_int()))
    (Int(a), Duration(b)) => Duration(b.mul(a.to_double()))
    (Float(a), Duration(b)) => Duration(b.mul(a))
    (Duration(a), Int(b)) => Duration(a.mul(b.to_double()))
    (Duration(a), Float(b)) => Duration(a.mul(b))
    (a, b) => mismatch("cannot multiply \{a.ty()} with \{b.ty()}")
  }
}

///|
/// Compute the quotient of two values.
pub fn div(lhs : Value, rhs : Value) -> Value raise HintedError {
  if is_zero_value(rhs) {
    bail("cannot divide by zero")
  }
  match (lhs, rhs) {
    (Int(a), Int(b)) => Float(a.to_double() / b.to_double())
    (Int(a), Float(b)) => Float(a.to_double() / b)
    (Float(a), Int(b)) => Float(a / b.to_double())
    (Float(a), Float(b)) => Float(a / b)
    (Decimal(a), Decimal(b)) => Decimal(decimal_or_too_large(a.checked_div(b)))
    (Decimal(a), Int(b)) =>
      Decimal(decimal_or_too_large(a.checked_div(Decimal::from_int(b))))
    (Int(a), Decimal(b)) =>
      Decimal(decimal_or_too_large(Decimal::from_int(a).checked_div(b)))
    (Length(a), Int(b)) => Length(a.div_by(b.to_double()))
    (Length(a), Float(b)) => Length(a.div_by(b))
    (Length(a), Length(b)) => Float(try_div_length(a, b))
    (Length(a), Relative(b)) if b.rel.is_zero() =>
      Float(try_div_length(a, b.abs))
    (Angle(a), Int(b)) => Angle(a.div_by(b.to_double()))
    (Angle(a), Float(b)) => Angle(a.div_by(b))
    (Angle(a), Angle(b)) => Float(a.ratio_to(b))
    (Ratio(a), Int(b)) => Ratio(a.div_by(b.to_double()))
    (Ratio(a), Float(b)) => Ratio(a.div_by(b))
    (Ratio(a), Ratio(b)) => Float(a.ratio_to(b))
    (Ratio(a), Relative(b)) if b.abs.is_zero() => Float(a.ratio_to(b.rel))
    (Relative(a), Int(b)) => Relative(a.div_by(b.to_double()))
    (Relative(a), Float(b)) => Relative(a.div_by(b))
    (Relative(a), Length(b)) if a.rel.is_zero() =>
      Float(try_div_length(a.abs, b))
    (Relative(a), Ratio(b)) if a.abs.is_zero() => Float(a.rel.ratio_to(b))
    (Relative(a), Relative(b)) => Float(try_div_relative(a, b))
    (Fraction(a), Int(b)) => Fraction(a.div_by(b.to_double()))
    (Fraction(a), Float(b)) => Fraction(a.div_by(b))
    (Fraction(a), Fraction(b)) => Float(a.ratio_to(b))
    (Duration(a), Int(b)) => Duration(a.div(b.to_double()))
    (Duration(a), Float(b)) => Duration(a.div(b))
    (Duration(a), Duration(b)) => Float(a.div_duration(b))
    (a, b) => mismatch("cannot divide \{a.ty()} by \{b.ty()}")
  }
}

///|
/// Whether a value is a numeric zero.
fn is_zero_value(v : Value) -> Bool {
  match v {
    Int(v) => v == 0L
    Float(v) => v == 0.0
    Decimal(v) => v.is_zero()
    Length(v) => v.is_zero()
    Angle(v) => v.to_raw() == 0.0
    Ratio(v) => v.is_zero()
    Relative(v) => v.rel.is_zero() && v.abs.is_zero()
    Fraction(v) => v.get() == 0.0
    Duration(v) => v.is_zero()
    _ => false
  }
}

///|
/// Try to divide two lengths.
fn try_div_length(a : Length, b : Length) -> Double raise HintedError {
  match a.try_div(b) {
    Some(v) => v
    None => bail("cannot divide these two lengths")
  }
}

///|
/// Try to divide two relative lengths.
fn try_div_relative(
  a : Rel[Length],
  b : Rel[Length],
) -> Double raise HintedError {
  match a.try_div_length(b) {
    Some(v) => v
    None => bail("cannot divide these two relative lengths")
  }
}

///|
/// Compute the logical "not" of a value.
pub fn not_(value : Value) -> Value raise HintedError {
  match value {
    Bool(b) => Bool(!b)
    v => mismatch("cannot apply 'not' to \{v.ty()}")
  }
}

///|
/// Compute the logical "and" of two values.
pub fn and_(lhs : Value, rhs : Value) -> Value raise HintedError {
  match (lhs, rhs) {
    (Bool(a), Bool(b)) => Bool(a && b)
    (a, b) => mismatch("cannot apply 'and' to \{a.ty()} and \{b.ty()}")
  }
}

///|
/// Compute the logical "or" of two values.
pub fn or_(lhs : Value, rhs : Value) -> Value raise HintedError {
  match (lhs, rhs) {
    (Bool(a), Bool(b)) => Bool(a || b)
    (a, b) => mismatch("cannot apply 'or' to \{a.ty()} and \{b.ty()}")
  }
}

///|
/// Compute whether two values are equal.
pub fn eq_(lhs : Value, rhs : Value) -> Value raise HintedError {
  Bool(equal(lhs, rhs))
}

///|
/// Compute whether two values are unequal.
pub fn neq(lhs : Value, rhs : Value) -> Value raise HintedError {
  Bool(!equal(lhs, rhs))
}

///|
/// Compute whether `lhs < rhs`.
pub fn lt(lhs : Value, rhs : Value) -> Value raise HintedError {
  Bool(compare(lhs, rhs) < 0)
}

///|
/// Compute whether `lhs <= rhs`.
pub fn leq(lhs : Value, rhs : Value) -> Value raise HintedError {
  Bool(compare(lhs, rhs) <= 0)
}

///|
/// Compute whether `lhs > rhs`.
pub fn gt(lhs : Value, rhs : Value) -> Value raise HintedError {
  Bool(compare(lhs, rhs) > 0)
}

///|
/// Compute whether `lhs >= rhs`.
pub fn geq(lhs : Value, rhs : Value) -> Value raise HintedError {
  Bool(compare(lhs, rhs) >= 0)
}

///|
/// Determine whether two values are equal.
pub fn equal(lhs : Value, rhs : Value) -> Bool {
  match (lhs, rhs) {
    (None, None) => true
    (Auto, Auto) => true
    (Bool(a), Bool(b)) => a == b
    (Int(a), Int(b)) => a == b
    (Float(a), Float(b)) => a == b
    (Decimal(a), Decimal(b)) => a == b
    (Length(a), Length(b)) => a == b
    (Angle(a), Angle(b)) => a == b
    (Ratio(a), Ratio(b)) => a == b
    (Relative(a), Relative(b)) => a == b
    (Fraction(a), Fraction(b)) => a == b
    (Color(a), Color(b)) => a == b
    (Symbol(a), Symbol(b)) => a == b
    (Version(a), Version(b)) => a == b
    (Str(a), Str(b)) => a == b
    (Bytes(a), Bytes(b)) => a == b
    (Label(a), Label(b)) => a == b
    (Content(a), Content(b)) => a == b
    (Array(a), Array(b)) =>
      a.len() == b.len() &&
      a.items.iter().zip(b.items.iter()).all(p => equal(p.0, p.1))
    (Dict(a), Dict(b)) =>
      a.len() == b.len() &&
      a.map
      .iter()
      .all(p => {
        match b.map.get(p.0) {
          Some(v) => equal(p.1, v)
          None => false
        }
      })
    (Func(a), Func(b)) => a == b
    (Args(a), Args(b)) => a == b
    (Type(a), Type(b)) => a == b
    (Module(a), Module(b)) => a == b
    (Datetime(a), Datetime(b)) => a == b
    (Duration(a), Duration(b)) => a == b
    (Dyn(a), Dyn(b)) => a == b
    (Int(i), Float(f)) | (Float(f), Int(i)) => i.to_double() == f
    (Int(i), Decimal(d)) | (Decimal(d), Int(i)) => Decimal::from_int(i) == d
    (Length(len), Relative(rel)) | (Relative(rel), Length(len)) =>
      len == rel.abs && rel.rel.is_zero()
    (Ratio(rat), Relative(rel)) | (Relative(rel), Ratio(rat)) =>
      rat == rel.rel && rel.abs.is_zero()
    _ => false
  }
}

///|
/// Compare two values: `-1`, `0` or `1`.
pub fn compare(lhs : Value, rhs : Value) -> Int raise HintedError {
  match (lhs, rhs) {
    (Bool(a), Bool(b)) => a.compare(b)
    (Int(a), Int(b)) => a.compare(b)
    (Float(a), Float(b)) => try_cmp_floats(a, b)
    (Decimal(a), Decimal(b)) => a.compare(b)
    (Length(a), Length(b)) => try_cmp_lengths(a, b)
    (Angle(a), Angle(b)) => a.compare(b)
    (Ratio(a), Ratio(b)) => a.compare(b)
    (Relative(a), Relative(b)) =>
      match a.partial_cmp_length(b) {
        Some(o) => o
        None =>
          bail("cannot compare \{a.repr_length()} with \{b.repr_length()}")
      }
    (Fraction(a), Fraction(b)) => a.compare(b)
    (Version(a), Version(b)) => a.compare(b)
    (Str(a), Str(b)) => compare_str(a, b)
    (Int(a), Float(b)) => try_cmp_floats(a.to_double(), b)
    (Float(a), Int(b)) => try_cmp_floats(a, b.to_double())
    (Int(a), Decimal(b)) => Decimal::from_int(a).compare(b)
    (Decimal(a), Int(b)) => a.compare(Decimal::from_int(b))
    (Length(a), Relative(b)) if b.rel.is_zero() => try_cmp_lengths(a, b.abs)
    (Ratio(a), Relative(b)) if b.abs.is_zero() => a.compare(b.rel)
    (Relative(a), Length(b)) if a.rel.is_zero() => try_cmp_lengths(a.abs, b)
    (Relative(a), Ratio(b)) if a.abs.is_zero() => a.rel.compare(b)
    (Duration(a), Duration(b)) => a.compare(b)
    (Datetime(a), Datetime(b)) =>
      match a.partial_cmp(b) {
        Some(o) => o
        None => bail("cannot compare \{a.kind()} and \{b.kind()}")
      }
    (Array(a), Array(b)) => try_cmp_arrays(a.items, b.items)
    _ => mismatch("cannot compare \{lhs.ty()} and \{rhs.ty()}")
  }
}

///|
fn try_cmp_floats(a : Double, b : Double) -> Int raise HintedError {
  if a.is_nan() || b.is_nan() {
    bail("cannot compare \{repr_float(a)} with \{repr_float(b)}")
  }
  a.compare(b)
}

///|
fn try_cmp_lengths(a : Length, b : Length) -> Int raise HintedError {
  match a.partial_cmp(b) {
    Some(o) => o
    None => bail("cannot compare \{a.repr()} with \{b.repr()}")
  }
}

///|
/// Try to compare arrays of values lexicographically.
fn try_cmp_arrays(a : Array[Value], b : Array[Value]) -> Int raise HintedError {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let o = compare(a[i], b[i])
    if o != 0 {
      return o
    }
  }
  a.length().compare(b.length())
}

///|
/// Test whether one value is "in" another one.
pub fn in_(
  guard_ : BindingGuard,
  lhs : Value,
  rhs : Value,
) -> Value raise HintedError {
  match contains(guard_, lhs, rhs) {
    Some(b) => Bool(b)
    None => mismatch("cannot apply 'in' to \{lhs.ty()} and \{rhs.ty()}")
  }
}

///|
/// Test whether one value is "not in" another one.
pub fn not_in(
  guard_ : BindingGuard,
  lhs : Value,
  rhs : Value,
) -> Value raise HintedError {
  match contains(guard_, lhs, rhs) {
    Some(b) => Bool(!b)
    None => mismatch("cannot apply 'not in' to \{lhs.ty()} and \{rhs.ty()}")
  }
}

///|
/// Test for containment.
pub fn contains(guard_ : BindingGuard, lhs : Value, rhs : Value) -> Bool? {
  match (lhs, rhs) {
    (Str(a), Str(b)) => Some(b.contains(a))
    (Dyn(a), Str(b)) => a.regex_is_match(b)
    (Str(a), Dict(b)) => Some(b.contains(a))
    (Str(a), Module(b)) =>
      Some(
        match b.scope().get(a) {
          Some(binding) =>
            (try binding.read(guard_, "") catch {
              _ => None
            } noraise {
              _ => Auto
            })
            is Auto
          None => false
        },
      )
    (a, Array(b)) => Some(b.items.iter().any(v => equal(a, v)))
    _ => None
  }
}

///|
/// Cast an integer to `usize` with upstream's error messages.
pub fn cast_usize(v : Value) -> Int64 raise HintedError {
  match v {
    Int(i) => if i < 0L { bail("number must be at least zero") } else { i }
    v => raise HintedError(CastInfo::Type(Type::int()).error(v))
  }
}

///|
/// Repeat a string `n` times.
pub fn str_repeat(s : String, n : Int64) -> String raise HintedError {
  let len = @syntax.utf8_len(s).to_int64()
  if n > 0L && len > 0L && len * n / n != len {
    bail("cannot repeat this string \{n} times")
  }
  let buf = StringBuilder()
  for _ in 0L..<n {
    buf.write_string(s)
  }
  buf.to_string()
}
