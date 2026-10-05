// Port of `typst-library/src/foundations/calc.rs`: calculations and
// processing of numeric values. The module itself is built in `lib.mbt`
// (`calc_module`).

///|
/// Calculates the absolute value of a numeric value.
fn impl_calc_abs(value_ : ToAbs) -> Value raise HintedError {
  value_.0
}

///|
/// A value of which the absolute value can be taken.
pub(all) struct ToAbs(Value)

///|
pub impl Reflect for ToAbs with fn input() {
  CastInfo::Type(Type::int())
  .union_with(Type(Type::float()))
  .union_with(Type(Type::length()))
  .union_with(Type(Type::angle()))
  .union_with(Type(Type::ratio()))
  .union_with(Type(Type::fraction()))
  .union_with(Type(Type::decimal()))
}

///|
pub impl Reflect for ToAbs with fn output() {
  ToAbs::input()
}

///|
pub impl Reflect for ToAbs with fn castable(v) {
  v
  is (Int(_)
  | Float(_)
  | Length(_)
  | Angle(_)
  | Ratio(_)
  | Fraction(_)
  | Decimal(_))
}

///|
pub impl FromValue for ToAbs with fn from_value(v) {
  match v {
    Int(v) =>
      match i64_checked_abs(v) {
        Some(a) => ToAbs(Int(a))
        None => bail(calc_too_large())
      }
    Float(v) => ToAbs(Float(v.abs()))
    Length(v) =>
      match v.try_abs() {
        Some(a) => ToAbs(Length(a))
        None => bail("cannot take absolute value of this length")
      }
    Angle(v) => ToAbs(Angle(v.abs()))
    Ratio(v) => ToAbs(Ratio(v.abs()))
    Fraction(v) => ToAbs(Fraction(v.abs()))
    Decimal(v) => ToAbs(Decimal(v.abs()))
    v => raise HintedError(ToAbs::input().error(v))
  }
}

///|
/// Raises a value to some exponent.
fn impl_calc_pow(
  span : @syntax.Span,
  base_ : DecNum,
  exponent_ : @syntax.Spanned[Num],
) -> DecNum raise SourceError {
  let exponent = exponent_
  match exponent.v {
    _ if exponent.v.float() == 0.0 && base_.is_zero() =>
      bail_at(span, "zero to the power of zero is undefined")
    Int(i) if !fits_i32(i) => bail_at(exponent.span, "exponent is too large")
    Float(f) if !is_normal(f) && f != 0.0 =>
      bail_at(exponent.span, "exponent may not be infinite, subnormal, or NaN")
    _ => ()
  }
  match (base_, exponent.v) {
    (Int(a), Int(b)) if b >= 0L =>
      match i64_checked_pow(a, b) {
        Some(v) => Int(v)
        None => bail_at(span, calc_too_large())
      }
    (Decimal(a), Int(b)) =>
      match a.checked_powi(b) {
        Some(v) => Decimal(v)
        None => bail_at(span, calc_too_large())
      }
    (a, b) => {
      let a = match a.float() {
        Some(a) => a
        None =>
          raise SourceError([
            cant_apply_to_decimal_and_float().into_error_at(span),
          ])
      }
      let result = if a == f64_consts_e {
        libm_exp(b.float())
      } else if a == 2.0 {
        libm_exp2(b.float())
      } else if b is Int(b) {
        Scalar::new(a).powi(b.to_int()).get()
      } else {
        libm_pow(a, b.float())
      }
      if result.is_nan() {
        bail_at(span, "the result is not a real number")
      }
      Float(result)
    }
  }
}

///|
/// Raises a value to some exponent of e.
fn impl_calc_exp(
  span : @syntax.Span,
  exponent_ : @syntax.Spanned[Num],
) -> Double raise SourceError {
  let exponent = exponent_
  match exponent.v {
    Int(i) if !fits_i32(i) => bail_at(exponent.span, "exponent is too large")
    Float(f) if !is_normal(f) && f != 0.0 =>
      bail_at(exponent.span, "exponent may not be infinite, subnormal, or NaN")
    _ => ()
  }
  let result = libm_exp(exponent.v.float())
  if result.is_nan() {
    bail_at(span, "the result is not a real number")
  }
  result
}

///|
/// Calculates the square root of a number.
fn impl_calc_sqrt(value_ : @syntax.Spanned[Num]) -> Double raise SourceError {
  if value_.v.float() < 0.0 {
    bail_at(value_.span, "cannot take square root of negative number")
  }
  value_.v.float().sqrt()
}

///|
/// Calculates the real nth root of a number.
fn impl_calc_root(
  radicand_ : Double,
  index_ : @syntax.Spanned[Int64],
) -> Double raise SourceError {
  let radicand = radicand_
  let index = index_
  if index.v == 0L {
    bail_at(index.span, "cannot take the 0th root of a number")
  } else if radicand < 0.0 {
    if index.v % 2L == 0L {
      bail_at(
        index.span,
        "negative numbers do not have a real nth root when n is even",
      )
    } else {
      -libm_pow(-radicand, 1.0 / index.v.to_double())
    }
  } else {
    libm_pow(radicand, 1.0 / index.v.to_double())
  }
}

///|
/// Calculates the sine of an angle.
fn impl_calc_sin(angle_ : AngleLike) -> Double raise HintedError {
  match angle_ {
    Angle(a) => a.sin()
    Int(n) => libm_sin(n.to_double())
    Float(n) => libm_sin(n)
  }
}

///|
/// Calculates the cosine of an angle.
fn impl_calc_cos(angle_ : AngleLike) -> Double raise HintedError {
  match angle_ {
    Angle(a) => a.cos()
    Int(n) => libm_cos(n.to_double())
    Float(n) => libm_cos(n)
  }
}

///|
/// Calculates the tangent of an angle.
fn impl_calc_tan(angle_ : AngleLike) -> Double raise HintedError {
  match angle_ {
    Angle(a) => a.tan()
    Int(n) => libm_tan(n.to_double())
    Float(n) => libm_tan(n)
  }
}

///|
/// Calculates the arcsine of a number.
fn impl_calc_asin(value_ : @syntax.Spanned[Num]) -> Angle raise SourceError {
  let val = value_.v.float()
  if val < -1.0 || val > 1.0 {
    bail_at(value_.span, "value must be between -1 and 1")
  }
  Angle::asin(val)
}

///|
/// Calculates the arccosine of a number.
fn impl_calc_acos(value_ : @syntax.Spanned[Num]) -> Angle raise SourceError {
  let val = value_.v.float()
  if val < -1.0 || val > 1.0 {
    bail_at(value_.span, "value must be between -1 and 1")
  }
  Angle::acos(val)
}

///|
/// Calculates the arctangent of a number.
fn impl_calc_atan(value_ : Num) -> Angle raise HintedError {
  Angle::atan(value_.float())
}

///|
/// Calculates the four-quadrant arctangent of a coordinate.
fn impl_calc_atan2(x_ : Num, y_ : Num) -> Angle raise HintedError {
  Angle::atan2(y_.float(), x_.float())
}

///|
/// Calculates the hyperbolic sine of a hyperbolic angle.
fn impl_calc_sinh(value_ : Double) -> Double raise HintedError {
  libm_sinh(value_)
}

///|
/// Calculates the hyperbolic cosine of a hyperbolic angle.
fn impl_calc_cosh(value_ : Double) -> Double raise HintedError {
  libm_cosh(value_)
}

///|
/// Calculates the hyperbolic tangent of a hyperbolic angle.
fn impl_calc_tanh(value_ : Double) -> Double raise HintedError {
  libm_tanh(value_)
}

///|
/// Calculates the inverse hyperbolic sine of a number.
fn impl_calc_asinh(value_ : Double) -> Double raise HintedError {
  libm_asinh(value_)
}

///|
/// Calculates the inverse hyperbolic cosine of a number.
fn impl_calc_acosh(
  value_ : @syntax.Spanned[Double],
) -> Double raise SourceError {
  let val = value_.v
  if val < 1.0 {
    bail_at(value_.span, "value must be greater than or equal to 1")
  }
  libm_acosh(val)
}

///|
/// Calculates the inverse hyperbolic tangent of a number.
fn impl_calc_atanh(
  value_ : @syntax.Spanned[Double],
) -> Double raise SourceError {
  let val = value_.v
  if val <= -1.0 || val >= 1.0 {
    bail_at(value_.span, "value must be between -1 and 1 (exclusive)")
  }
  libm_atanh(val)
}

///|
/// Default of `calc.log(base:)`: `Spanned::detached(10.0)`.
fn impl_calc_log__base_default() -> @syntax.Spanned[Double] raise SourceError {
  { v: 10.0, span: @syntax.Span::detached(), }
}

///|
/// Calculates the logarithm of a number.
fn impl_calc_log(
  span : @syntax.Span,
  value_ : @syntax.Spanned[Num],
  base_ : @syntax.Spanned[Double],
) -> Double raise SourceError {
  let number = value_.v.float()
  if number <= 0.0 {
    bail_at(value_.span, "value must be strictly positive")
  }
  if !is_normal(base_.v) {
    bail_at(base_.span, "base may not be zero, NaN, infinite, or subnormal")
  }
  let result = if base_.v == f64_consts_e {
    libm_log(number)
  } else if base_.v == 2.0 {
    libm_log2(number)
  } else if base_.v == 10.0 {
    libm_log10(number)
  } else {
    libm_log(number) / libm_log(base_.v)
  }
  if result.is_inf() || result.is_nan() {
    bail_at(span, "the result is not a real number")
  }
  result
}

///|
/// Calculates the natural logarithm of a number.
fn impl_calc_ln(
  span : @syntax.Span,
  value_ : @syntax.Spanned[Num],
) -> Double raise SourceError {
  let number = value_.v.float()
  if number <= 0.0 {
    bail_at(value_.span, "value must be strictly positive")
  }
  let result = libm_log(number)
  if result.is_inf() {
    bail_at(span, "result close to -inf")
  }
  result
}

///|
/// Calculates the error function of a number.
fn impl_calc_erf(value_ : Double) -> Double raise HintedError {
  libm_erf(value_)
}

///|
/// Calculates the factorial of a number.
fn impl_calc_fact(number_ : U64) -> Int64 raise HintedError {
  match fact_impl(1UL, number_.get().reinterpret_as_uint64()) {
    Some(v) => v
    None => bail(calc_too_large())
  }
}

///|
/// Calculates a permutation.
fn impl_calc_perm(base_ : U64, numbers_ : U64) -> Int64 raise HintedError {
  let base = base_.get().reinterpret_as_uint64()
  let numbers = numbers_.get().reinterpret_as_uint64()
  // By convention.
  if base < numbers {
    return 0L
  }
  match fact_impl(base - numbers + 1UL, base) {
    Some(v) => v
    None => bail(calc_too_large())
  }
}

///|
/// Calculates the product of a range of numbers. Used to calculate
/// permutations. Returns `None` if the result is larger than `i64::MAX`.
fn fact_impl(start : UInt64, end : UInt64) -> Int64? {
  // By convention
  if end + 1UL < start {
    return Some(0L)
  }
  let real_start = if start > 1UL { start } else { 1UL }
  let mut count = 1UL
  let mut i = real_start
  while i <= end {
    count = match u64_checked_mul(count, i) {
      Some(c) => c
      None => return None
    }
    if i == end {
      break
    }
    i = i + 1UL
  }
  u64_to_i64(count)
}

///|
/// Calculates a binomial coefficient.
fn impl_calc_binom(n_ : U64, k_ : U64) -> Int64 raise HintedError {
  match
    binom_impl(
      n_.get().reinterpret_as_uint64(),
      k_.get().reinterpret_as_uint64(),
    ) {
    Some(v) => v
    None => bail(calc_too_large())
  }
}

///|
/// Calculates a binomial coefficient, with `n` the upper coefficient and `k`
/// the lower coefficient. Returns `None` if the result is larger than
/// `i64::MAX`.
fn binom_impl(n : UInt64, k : UInt64) -> Int64? {
  if k > n {
    return Some(0L)
  }
  // By symmetry
  let real_k = if n - k < k { n - k } else { k }
  if real_k == 0UL {
    return Some(1L)
  }
  let mut result = 1UL
  let mut i = 0UL
  while i < real_k {
    result = match u64_checked_mul(result, n - i) {
      Some(r) => r / (i + 1UL)
      None => return None
    }
    i = i + 1UL
  }
  u64_to_i64(result)
}

///|
/// Calculates the greatest common divisor of two integers.
fn impl_calc_gcd(a_ : Int64, b_ : Int64) -> Int64 raise HintedError {
  let mut a = a_
  let mut b = b_
  while b != 0L {
    let temp = b
    b = match i64_checked_rem(a, b) {
      Some(r) => r
      None => bail(calc_too_large())
    }
    a = temp
  }
  match i64_checked_abs(a) {
    Some(a) => a
    None => bail(calc_too_large())
  }
}

///|
/// Calculates the least common multiple of two integers.
fn impl_calc_lcm(a_ : Int64, b_ : Int64) -> Int64 raise HintedError {
  let a = a_
  let b = b_
  if a == b {
    return match i64_checked_abs(a) {
      Some(a) => a
      None => bail(calc_too_large())
    }
  }
  let gcd = impl_calc_gcd(a, b)
  let result = match i64_checked_div(a, gcd) {
    Some(q) =>
      match i64_checked_mul(q, b) {
        Some(v) => i64_checked_abs(v)
        None => None
      }
    None => None
  }
  match result {
    Some(v) => v
    None => bail(calc_too_large())
  }
}

///|
/// Rounds a number down to the nearest integer.
fn impl_calc_floor(value_ : DecNum) -> Int64 raise HintedError {
  match value_ {
    Int(n) => n
    Float(n) =>
      convert_float_to_int(n.floor()) catch {
        _ => bail(calc_too_large())
      }
    Decimal(n) =>
      match n.floor().to_i64() {
        Some(i) => i
        None => bail(calc_too_large())
      }
  }
}

///|
/// Rounds a number up to the nearest integer.
fn impl_calc_ceil(value_ : DecNum) -> Int64 raise HintedError {
  match value_ {
    Int(n) => n
    Float(n) =>
      convert_float_to_int(n.ceil()) catch {
        _ => bail(calc_too_large())
      }
    Decimal(n) =>
      match n.ceil().to_i64() {
        Some(i) => i
        None => bail(calc_too_large())
      }
  }
}

///|
/// Returns the integer part of a number.
fn impl_calc_trunc(value_ : DecNum) -> Int64 raise HintedError {
  match value_ {
    Int(n) => n
    Float(n) =>
      convert_float_to_int(n.trunc()) catch {
        _ => bail(calc_too_large())
      }
    Decimal(n) =>
      match n.trunc().to_i64() {
        Some(i) => i
        None => bail(calc_too_large())
      }
  }
}

///|
/// Returns the fractional part of a number.
fn impl_calc_fract(value_ : DecNum) -> DecNum raise HintedError {
  match value_ {
    Int(_) => Int(0L)
    Float(n) => Float(n - n.trunc())
    Decimal(n) => Decimal(n.fract())
  }
}

///|
/// Rounds a number to the nearest integer or to the given number of digits.
fn impl_calc_round(
  value_ : DecNum,
  digits_ : Int64,
) -> DecNum raise HintedError {
  match value_ {
    Int(n) =>
      match round_int_with_precision(n, saturate_i16(digits_)) {
        Some(v) => Int(v)
        None => bail(calc_too_large())
      }
    Float(n) => Float(round_with_precision(n, saturate_i16(digits_)))
    Decimal(n) => {
      let digits = if digits_ > 2147483647L {
        2147483647
      } else if digits_ < -2147483648L {
        -2147483648
      } else {
        digits_.to_int()
      }
      match n.round(digits) {
        Some(v) => Decimal(v)
        None => bail(calc_too_large())
      }
    }
  }
}

///|
/// Port of `typst_utils::round_int_with_precision`: rounds an integer to the
/// given number of (negative) digits. Returns `None` on overflow.
pub fn round_int_with_precision(value : Int64, precision : Int) -> Int64? {
  if precision >= 0 {
    return Some(value)
  }
  let digits = -precision
  let ten_to_digits = match i64_checked_pow(10L, (digits - 1).to_int64()) {
    Some(t) => t
    // Larger than any possible amount of integer digits.
    None => return Some(0L)
  }

  // Divide by 10^(digits - 1).
  //
  // We keep the last digit we want to remove as the first digit of this
  // number, so we can check it with mod 10 for rounding purposes.
  let truncated = value / ten_to_digits
  if truncated == 0L {
    return Some(0L)
  }
  let last = truncated % 10L
  let last_abs = if last < 0L { -last } else { last }
  let rounded = if last_abs >= 5L {
    // Round away from zero (towards the next multiple of 10).
    //
    // This may overflow in the particular case of rounding MAX/MIN
    // with -1.
    let signum = if truncated > 0L { 1L } else { -1L }
    match i64_checked_add(truncated, signum * (10L - last_abs)) {
      Some(r) => r
      None => return None
    }
  } else {
    // Just replace the last digit with zero, since it's < 5.
    truncated - last
  }

  // Multiply back by 10^(digits - 1).
  //
  // May overflow / underflow, in which case we fail.
  i64_checked_mul(rounded, ten_to_digits)
}

///|
/// Clamps a number between a minimum and maximum value.
fn impl_calc_clamp(
  span : @syntax.Span,
  value_ : DecNum,
  min_ : DecNum,
  max_ : @syntax.Spanned[DecNum],
) -> DecNum raise SourceError {
  // Ignore if there are incompatible types (decimal and float) since that
  // will cause `apply3` below to error before calling clamp, avoiding a
  // panic.
  let invalid = min_
    .apply2(max_.v, (min, max) => max < min, (min, max) => max < min, (min, max) => {
      max.compare(min) < 0
    })
    .unwrap_or(false)
  if invalid {
    bail_at(max_.span, "max must be greater than or equal to min")
  }
  match
    value_.apply3(
      min_,
      max_.v,
      (v, min, max) => if v < min { min } else if v > max { max } else { v },
      (v, min, max) => {
        let mut x = v
        if x < min {
          x = min
        }
        if x > max {
          x = max
        }
        x
      },
      (v, min, max) => {
        if v.compare(min) < 0 {
          min
        } else if v.compare(max) > 0 {
          max
        } else {
          v
        }
      },
    ) {
    Some(v) => v
    None =>
      raise SourceError([cant_apply_to_decimal_and_float().into_error_at(span)])
  }
}

///|
/// Determines the minimum of a sequence of values.
fn impl_calc_min(
  span : @syntax.Span,
  values_ : Array[@syntax.Spanned[Value]],
) -> Value raise SourceError {
  minmax(span, values_, -1)
}

///|
/// Determines the maximum of a sequence of values.
fn impl_calc_max(
  span : @syntax.Span,
  values_ : Array[@syntax.Spanned[Value]],
) -> Value raise SourceError {
  minmax(span, values_, 1)
}

///|
/// Find the minimum or maximum of a sequence of values.
fn minmax(
  span : @syntax.Span,
  values : Array[@syntax.Spanned[Value]],
  goal : Int,
) -> Value raise SourceError {
  if values.is_empty() {
    bail_at(span, "expected at least one value")
  }
  let mut extremum = values[0].v
  for i in 1..<values.length() {
    let { v, span, } = values[i]
    let ordering = at(span, () => compare(v, extremum))
    if ordering == goal {
      extremum = v
    }
  }
  extremum
}

///|
/// Determines whether an integer is even.
fn impl_calc_even(value_ : Int64) -> Bool raise HintedError {
  value_ % 2L == 0L
}

///|
/// Determines whether an integer is odd.
fn impl_calc_odd(value_ : Int64) -> Bool raise HintedError {
  value_ % 2L != 0L
}

///|
/// Calculates the remainder of two numbers.
fn impl_calc_rem(
  span : @syntax.Span,
  dividend_ : DecNum,
  divisor_ : @syntax.Spanned[DecNum],
) -> DecNum raise SourceError {
  if divisor_.v.is_zero() {
    bail_at(divisor_.span, "divisor must not be zero")
  }
  let result = dividend_.apply2(
    divisor_.v,
    // `checked_rem` can only overflow on `i64::MIN % -1` which is
    // mathematically zero.
    (a, b) => Some(DecNum::Int(i64_checked_rem(a, b).unwrap_or(0L))),
    (a, b) => Some(DecNum::Float(a % b)),
    (a, b) => a.checked_rem(b).map(d => DecNum::Decimal(d)),
  )
  match result {
    None =>
      raise SourceError([cant_apply_to_decimal_and_float().into_error_at(span)])
    Some(None) => bail_at(span, "dividend too small compared to divisor")
    Some(Some(v)) => v
  }
}

///|
/// Performs euclidean division of two numbers.
fn impl_calc_div_euclid(
  span : @syntax.Span,
  dividend_ : DecNum,
  divisor_ : @syntax.Spanned[DecNum],
) -> DecNum raise SourceError {
  if divisor_.v.is_zero() {
    bail_at(divisor_.span, "divisor must not be zero")
  }
  let result = dividend_.apply2(
    divisor_.v,
    (a, b) => i64_checked_div_euclid(a, b).map(i => DecNum::Int(i)),
    (a, b) => Some(DecNum::Float(f64_div_euclid(a, b))),
    (a, b) => a.checked_div_euclid(b).map(d => DecNum::Decimal(d)),
  )
  match result {
    None =>
      raise SourceError([cant_apply_to_decimal_and_float().into_error_at(span)])
    Some(None) => bail_at(span, calc_too_large())
    Some(Some(v)) => v
  }
}

///|
/// This calculates the least nonnegative remainder of a division.
fn impl_calc_rem_euclid(
  span : @syntax.Span,
  dividend_ : DecNum,
  divisor_ : @syntax.Spanned[DecNum],
) -> DecNum raise SourceError {
  if divisor_.v.is_zero() {
    bail_at(divisor_.span, "divisor must not be zero")
  }
  let result = dividend_.apply2(
    divisor_.v,
    // `checked_rem_euclid` can only overflow on `i64::MIN % -1` which
    // is mathematically zero.
    (a, b) => Some(DecNum::Int(i64_checked_rem_euclid(a, b).unwrap_or(0L))),
    (a, b) => Some(DecNum::Float(rem_euclid(a, b))),
    (a, b) => a.checked_rem_euclid(b).map(d => DecNum::Decimal(d)),
  )
  match result {
    None =>
      raise SourceError([cant_apply_to_decimal_and_float().into_error_at(span)])
    Some(None) => bail_at(span, "dividend too small compared to divisor")
    Some(Some(v)) => v
  }
}

///|
/// Calculates the quotient (floored division) of two numbers.
fn impl_calc_quo(
  span : @syntax.Span,
  dividend_ : DecNum,
  divisor_ : @syntax.Spanned[DecNum],
) -> Int64 raise SourceError {
  if divisor_.v.is_zero() {
    bail_at(divisor_.span, "divisor must not be zero")
  }
  let result = dividend_.apply2(
    divisor_.v,
    (a, b) => {
      match i64_checked_div(a, b) {
        // Round towards negative infinity if the fraction is negative.
        Some(q) =>
          Some(
            DecNum::Int(
              if (a < 0L) != (b < 0L) && a % b != 0L {
                q - 1L
              } else {
                q
              },
            ),
          )
        None => None
      }
    },
    (a, b) => Some(DecNum::Float(a / b)),
    (a, b) => {
      match a.checked_div(b) {
        Some(q) => Some(DecNum::Decimal(q))
        None => None
      }
    },
  )
  let divided = match result {
    None =>
      raise SourceError([cant_apply_to_decimal_and_float().into_error_at(span)])
    Some(None) => bail_at(span, calc_too_large())
    Some(Some(v)) => v
  }
  at(span, () => impl_calc_floor(divided))
}

///|
/// Default of `calc.norm(p:)`: `Spanned::detached(2.0)`.
fn impl_calc_norm__p_default() -> @syntax.Spanned[Double] raise SourceError {
  { v: 2.0, span: @syntax.Span::detached(), }
}

///|
/// Calculates the p-norm of a sequence of values.
fn impl_calc_norm(
  p_ : @syntax.Spanned[Double],
  values_ : Array[Double],
) -> Double raise SourceError {
  let p = p_
  if p.v <= 0.0 {
    bail_at(p.span, "p must be greater than zero")
  }
  let abs = values_.map(v => v.abs())
  // `max_by(total_cmp)`: NaN (made positive by `abs`) is the greatest.
  let mut max = 0.0
  for i, v in abs {
    if i == 0 || v.is_nan() || (!max.is_nan() && v >= max) {
      max = v
    }
  }
  if p.v.is_inf() {
    // When p is infinity, the p-norm is the maximum of the absolute values.
    max
  } else if max == 0.0 {
    // When the maximum absolute value is 0, the norm is just 0.
    // This is a special case to avoid division by zero in the trick below.
    0.0
  } else {
    // Compute `max * (sum_i (x_i / max)^p)^(1 / p)` instead of raising
    // `x_i^p` directly, to avoid overflowing.
    let mut sum = -0.0
    for v in abs {
      sum = sum + libm_pow(v / max, p.v)
    }
    max * libm_pow(sum, 1.0 / p.v)
  }
}

///|
/// A value which can be passed to functions that work with integers and
/// floats.
pub(all) enum Num {
  Int(Int64)
  Float(Double)
}

///|
fn Num::float(self : Num) -> Double {
  match self {
    Int(v) => v.to_double()
    Float(v) => v
  }
}

///|
pub impl Reflect for Num with fn input() {
  CastInfo::Type(Type::int()).union_with(Type(Type::float()))
}

///|
pub impl Reflect for Num with fn output() {
  Num::input()
}

///|
pub impl Reflect for Num with fn castable(v) {
  v is (Int(_) | Float(_))
}

///|
pub impl IntoValue for Num with fn into_value(self) {
  match self {
    Int(v) => Int(v)
    Float(v) => Float(v)
  }
}

///|
pub impl FromValue for Num with fn from_value(v) {
  match v {
    Int(v) => Int(v)
    Float(v) => Float(v)
    v => raise HintedError(Num::input().error(v))
  }
}

///|
/// A value which can be passed to functions that work with integers, floats,
/// and decimals.
pub(all) enum DecNum {
  Int(Int64)
  Float(Double)
  Decimal(Decimal)
}

///|
/// Checks if this number is equivalent to zero.
fn DecNum::is_zero(self : DecNum) -> Bool {
  match self {
    Int(i) => i == 0L
    Float(f) => f == 0.0
    Decimal(d) => d.is_zero()
  }
}

///|
/// If this `DecNum` holds an integer or float, returns a float. Otherwise,
/// returns `None`.
fn DecNum::float(self : DecNum) -> Double? {
  match self {
    Int(i) => Some(i.to_double())
    Float(f) => Some(f)
    Decimal(_) => None
  }
}

///|
/// If this `DecNum` holds an integer or decimal, returns a decimal.
/// Otherwise, returns `None`.
fn DecNum::decimal(self : DecNum) -> Decimal? {
  match self {
    Int(i) => Some(Decimal::from_int(i))
    Float(_) => None
    Decimal(d) => Some(d)
  }
}

///|
/// Tries to apply a function to two decimal or numeric arguments.
///
/// Fails with `None` if one is a float and the other is a decimal.
fn[T] DecNum::apply2(
  self : DecNum,
  other : DecNum,
  int : (Int64, Int64) -> T,
  float : (Double, Double) -> T,
  decimal : (Decimal, Decimal) -> T,
) -> T? {
  match (self, other) {
    (Int(a), Int(b)) => Some(int(a, b))
    (Decimal(a), Decimal(b)) => Some(decimal(a, b))
    (Decimal(a), Int(b)) => Some(decimal(a, Decimal::from_int(b)))
    (Int(a), Decimal(b)) => Some(decimal(Decimal::from_int(a), b))
    (a, b) =>
      match (a.float(), b.float()) {
        (Some(a), Some(b)) => Some(float(a, b))
        _ => None
      }
  }
}

///|
/// Tries to apply a function to three decimal or numeric arguments.
///
/// Fails with `None` if one is a float and the other is a decimal.
fn DecNum::apply3(
  self : DecNum,
  other : DecNum,
  third : DecNum,
  int : (Int64, Int64, Int64) -> Int64,
  float : (Double, Double, Double) -> Double,
  decimal : (Decimal, Decimal, Decimal) -> Decimal,
) -> DecNum? {
  match (self, other, third) {
    (Int(a), Int(b), Int(c)) => Some(Int(int(a, b, c)))
    (Decimal(a), b, c) =>
      match (b.decimal(), c.decimal()) {
        (Some(b), Some(c)) => Some(Decimal(decimal(a, b, c)))
        _ => None
      }
    (a, Decimal(b), c) =>
      match (a.decimal(), c.decimal()) {
        (Some(a), Some(c)) => Some(Decimal(decimal(a, b, c)))
        _ => None
      }
    (a, b, Decimal(c)) =>
      match (a.decimal(), b.decimal()) {
        (Some(a), Some(b)) => Some(Decimal(decimal(a, b, c)))
        _ => None
      }
    (a, b, c) =>
      match (a.float(), b.float(), c.float()) {
        (Some(a), Some(b), Some(c)) => Some(Float(float(a, b, c)))
        _ => None
      }
  }
}

///|
pub impl Reflect for DecNum with fn input() {
  CastInfo::Type(Type::int())
  .union_with(Type(Type::float()))
  .union_with(Type(Type::decimal()))
}

///|
pub impl Reflect for DecNum with fn output() {
  DecNum::input()
}

///|
pub impl Reflect for DecNum with fn castable(v) {
  v is (Int(_) | Float(_) | Decimal(_))
}

///|
pub impl IntoValue for DecNum with fn into_value(self) {
  match self {
    Int(v) => Int(v)
    Float(v) => Float(v)
    Decimal(v) => Decimal(v)
  }
}

///|
pub impl FromValue for DecNum with fn from_value(v) {
  match v {
    Int(v) => Int(v)
    Float(v) => Float(v)
    Decimal(v) => Decimal(v)
    v => raise HintedError(DecNum::input().error(v))
  }
}

///|
/// A value that can be passed to a trigonometric function.
pub(all) enum AngleLike {
  Int(Int64)
  Float(Double)
  Angle(Angle)
}

///|
pub impl Reflect for AngleLike with fn input() {
  CastInfo::Type(Type::int())
  .union_with(Type(Type::float()))
  .union_with(Type(Type::angle()))
}

///|
pub impl Reflect for AngleLike with fn output() {
  AngleLike::input()
}

///|
pub impl Reflect for AngleLike with fn castable(v) {
  v is (Int(_) | Float(_) | Angle(_))
}

///|
pub impl FromValue for AngleLike with fn from_value(v) {
  match v {
    Int(v) => Int(v)
    Float(v) => Float(v)
    Angle(v) => Angle(v)
    v => raise HintedError(AngleLike::input().error(v))
  }
}

///|
/// The error message when the result is too large to be represented.
fn calc_too_large() -> String {
  "the result is too large"
}

///|
/// The hinted error message when trying to apply an operation to decimal and
/// float operands.
fn cant_apply_to_decimal_and_float() -> HintedString {
  HintedString::new("cannot apply this operation to a decimal and a float").with_hint(
    "if loss of precision is acceptable, explicitly cast the decimal to a float with `float(value)`",
  )
}

// Rust integer and float helpers.

///|
/// Euler's number (`std::f64::consts::E`).
let f64_consts_e : Double = 2.718281828459045

///|
/// Whether an integer fits into an `i32`.
fn fits_i32(i : Int64) -> Bool {
  i >= -2147483648L && i <= 2147483647L
}

///|
/// Rust's `f64::is_normal`.
fn is_normal(f : Double) -> Bool {
  !f.is_nan() && !f.is_inf() && f.abs() >= 2.2250738585072014e-308
}

///|
/// Rust's `i64::saturating_as::<i16>()`.
fn saturate_i16(i : Int64) -> Int {
  if i > 32767L {
    32767
  } else if i < -32768L {
    -32768
  } else {
    i.to_int()
  }
}

///|
/// Rust's `i64::checked_abs`.
fn i64_checked_abs(a : Int64) -> Int64? {
  if a == @int64.MIN_VALUE {
    None
  } else if a < 0L {
    Some(-a)
  } else {
    Some(a)
  }
}

///|
/// Rust's `i64::checked_add`.
fn i64_checked_add(a : Int64, b : Int64) -> Int64? {
  let r = a + b
  if (a >= 0L) == (b >= 0L) && (r >= 0L) != (a >= 0L) {
    None
  } else {
    Some(r)
  }
}

///|
/// Rust's `i64::checked_mul`.
fn i64_checked_mul(a : Int64, b : Int64) -> Int64? {
  if a == 0L || b == 0L {
    return Some(0L)
  }
  if (a == -1L && b == @int64.MIN_VALUE) || (b == -1L && a == @int64.MIN_VALUE) {
    return None
  }
  let r = a * b
  if r / b != a {
    None
  } else {
    Some(r)
  }
}

///|
/// Rust's `i64::checked_div`.
fn i64_checked_div(a : Int64, b : Int64) -> Int64? {
  if b == 0L || (a == @int64.MIN_VALUE && b == -1L) {
    None
  } else {
    Some(a / b)
  }
}

///|
/// Rust's `i64::checked_rem`.
fn i64_checked_rem(a : Int64, b : Int64) -> Int64? {
  if b == 0L || (a == @int64.MIN_VALUE && b == -1L) {
    None
  } else {
    Some(a % b)
  }
}

///|
/// Rust's `i64::checked_div_euclid`.
fn i64_checked_div_euclid(a : Int64, b : Int64) -> Int64? {
  if b == 0L || (a == @int64.MIN_VALUE && b == -1L) {
    return None
  }
  let q = a / b
  if a % b < 0L {
    Some(if b > 0L { q - 1L } else { q + 1L })
  } else {
    Some(q)
  }
}

///|
/// Rust's `i64::checked_rem_euclid`.
fn i64_checked_rem_euclid(a : Int64, b : Int64) -> Int64? {
  if b == 0L || (a == @int64.MIN_VALUE && b == -1L) {
    return None
  }
  let r = a % b
  if r < 0L {
    // `r.wrapping_add(b.wrapping_abs())`
    Some(r + (if b < 0L { -b } else { b }))
  } else {
    Some(r)
  }
}

///|
/// Rust's `i64::checked_pow`.
fn i64_checked_pow(base : Int64, exp : Int64) -> Int64? {
  let mut exp = exp
  if exp == 0L {
    return Some(1L)
  }
  let mut base = base
  let mut acc = 1L
  while true {
    if (exp & 1L) == 1L {
      acc = match i64_checked_mul(acc, base) {
        Some(v) => v
        None => return None
      }
      if exp == 1L {
        return Some(acc)
      }
    }
    exp = exp / 2L
    base = match i64_checked_mul(base, base) {
      Some(v) => v
      None => return None
    }
  }
  None
}

///|
/// Rust's `u64::checked_mul`.
fn u64_checked_mul(a : UInt64, b : UInt64) -> UInt64? {
  if a == 0UL || b == 0UL {
    return Some(0UL)
  }
  let r = a * b
  if r / b != a {
    None
  } else {
    Some(r)
  }
}

///|
/// Rust's `i64::try_from(u64)`.
fn u64_to_i64(v : UInt64) -> Int64? {
  if v > 0x7FFF_FFFF_FFFF_FFFFUL {
    None
  } else {
    Some(v.reinterpret_as_int64())
  }
}

///|
/// Rust's `f64::div_euclid`.
fn f64_div_euclid(a : Double, b : Double) -> Double {
  let q = (a / b).trunc()
  if a % b < 0.0 {
    if b > 0.0 {
      q - 1.0
    } else {
      q + 1.0
    }
  } else {
    q
  }
}
