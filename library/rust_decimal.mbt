// Port of the parts of the `rust_decimal` crate (1.43.0, as used by the
// oracle) that Typst's `decimal` type relies on.
//
// A `RustDecimal` is a 96-bit unsigned mantissa, a sign and a scale in
// `0..=28`: its value is `(-1)^negative * mantissa / 10^scale`. The
// arithmetic below reproduces rust_decimal's results exactly (including the
// scale of results, rounding of digits that do not fit, signed zeros and
// overflow detection). Where rust_decimal works on 32-bit limbs we compute
// with big integers and apply the same rounding rules.

///|
/// A rust_decimal `Decimal`.
struct RustDecimal {
  /// The mantissa, always in `0..2^96`.
  mantissa : @bigint.BigInt
  /// The scale (number of fractional digits), in `0..=28`.
  scale : Int
  /// The sign bit (may be set for zero).
  negative : Bool
} derive(Hash)

///|
/// The maximum supported scale.
let rd_max_scale : Int = 28

///|
let big_zero : @bigint.BigInt = @bigint.BigInt::from_int(0)

///|
let big_one : @bigint.BigInt = @bigint.BigInt::from_int(1)

///|
let big_ten : @bigint.BigInt = @bigint.BigInt::from_int(10)

///|
/// `2^96`: mantissas must be strictly below this.
let overflow_u96 : @bigint.BigInt = big_one << 96

///|
let rd_pow10_table : Array[@bigint.BigInt] = {
  let out = [big_one]
  for i in 1..<80 {
    out.push(out[i - 1] * big_ten)
  }
  out
}

///|
/// `10^n` as a big integer.
fn rd_pow10(n : Int) -> @bigint.BigInt {
  if n < rd_pow10_table.length() {
    rd_pow10_table[n]
  } else {
    let mut r = rd_pow10_table[rd_pow10_table.length() - 1]
    for _ in (rd_pow10_table.length() - 1)..<n {
      r = r * big_ten
    }
    r
  }
}

///|
fn big_is_odd(n : @bigint.BigInt) -> Bool {
  n.land(big_one) == big_one
}

///|
/// Creates a decimal without normalizing the sign of zero.
fn RustDecimal::raw(
  mantissa : @bigint.BigInt,
  negative : Bool,
  scale : Int,
) -> RustDecimal {
  { mantissa, scale, negative, }
}

///|
/// rust_decimal's `Decimal::from_parts`: a zero is always positive.
fn RustDecimal::from_parts(
  mantissa : @bigint.BigInt,
  negative : Bool,
  scale : Int,
) -> RustDecimal {
  { mantissa, scale, negative: negative && !mantissa.is_zero(), }
}

///|
let rd_zero : RustDecimal = RustDecimal::raw(big_zero, false, 0)

///|
let rd_one : RustDecimal = RustDecimal::raw(big_one, false, 0)

///|
fn RustDecimal::is_zero(self : RustDecimal) -> Bool {
  self.mantissa.is_zero()
}

///|
/// Conversion from `i64`.
fn RustDecimal::from_i64(n : Int64) -> RustDecimal {
  if n >= 0L {
    RustDecimal::raw(@bigint.BigInt::from_int64(n), false, 0)
  } else {
    RustDecimal::raw(-@bigint.BigInt::from_int64(n), true, 0)
  }
}

///|
fn RustDecimal::abs(self : RustDecimal) -> RustDecimal {
  { ..self, negative: false, }
}

///|
/// `Neg for Decimal`: flips the sign bit (also for zero).
fn RustDecimal::neg(self : RustDecimal) -> RustDecimal {
  { ..self, negative: !self.negative, }
}

///|
/// rust_decimal's `cmp_impl`: compares values exactly; zeros are equal
/// regardless of sign and scale.
fn RustDecimal::cmp(self : RustDecimal, other : RustDecimal) -> Int {
  if other.is_zero() {
    return if self.is_zero() { 0 } else if self.negative { -1 } else { 1 }
  }
  if self.is_zero() {
    return if other.negative { 1 } else { -1 }
  }
  if self.negative != other.negative {
    return if self.negative { -1 } else { 1 }
  }
  let scale = if self.scale > other.scale { self.scale } else { other.scale }
  let a = self.mantissa * rd_pow10(scale - self.scale)
  let b = other.mantissa * rd_pow10(scale - other.scale)
  let ord = a.compare(b)
  if self.negative {
    -ord
  } else {
    ord
  }
}

///|
/// Rescales an oversized mantissa (`>= 2^96`) or scale (`> 28`) into range,
/// like `Buf24::rescale`: drops the fewest digits needed, rounding half to
/// even (taking all dropped digits into account). Returns `None` on
/// overflow.
fn rd_rescale(mantissa : @bigint.BigInt, scale : Int) -> (@bigint.BigInt, Int)? {
  if mantissa < overflow_u96 && scale <= rd_max_scale {
    return Some((mantissa, scale))
  }
  let mut k = if scale > rd_max_scale { scale - rd_max_scale } else { 0 }
  while mantissa / rd_pow10(k) >= overflow_u96 {
    k += 1
  }
  if k > scale {
    return None
  }
  let mut q = rd_round_half_even(mantissa, k)
  let mut scale = scale - k
  if q >= overflow_u96 {
    // Rounding carried over 96 bits: scale down once more.
    if scale == 0 {
      return None
    }
    q = rd_round_half_even(q, 1)
    scale -= 1
  }
  Some((q, scale))
}

///|
/// `mantissa / 10^k`, rounded half to even.
fn rd_round_half_even(mantissa : @bigint.BigInt, k : Int) -> @bigint.BigInt {
  if k == 0 {
    return mantissa
  }
  let p = rd_pow10(k)
  let q = mantissa / p
  let r = mantissa - q * p
  let twice = r * @bigint.BigInt::from_int(2)
  if twice > p || (twice == p && big_is_odd(q)) {
    q + big_one
  } else {
    q
  }
}

///|
/// rust_decimal's `add_impl`/`sub_impl`.
fn rd_add_sub(
  d1 : RustDecimal,
  d2 : RustDecimal,
  subtract : Bool,
) -> RustDecimal? {
  if d1.is_zero() {
    // 0 - x or 0 + x
    let mut result = d2
    if subtract && !d2.is_zero() {
      result = { ..d2, negative: !d2.negative, }
    }
    return Some(result)
  }
  if d2.is_zero() {
    // x - 0 or x + 0
    return Some(d1)
  }
  let scale = if d1.scale > d2.scale { d1.scale } else { d2.scale }
  let a = d1.mantissa * rd_pow10(scale - d1.scale)
  let b = d2.mantissa * rd_pow10(scale - d2.scale)
  let effective_subtract = subtract != (d1.negative != d2.negative)
  let (magnitude, negative) = if effective_subtract {
    if a >= b {
      (a - b, d1.negative)
    } else {
      (b - a, !d1.negative)
    }
  } else {
    (a + b, d1.negative)
  }
  match rd_rescale(magnitude, scale) {
    Some((m, s)) => Some(RustDecimal::from_parts(m, negative, s))
    None => None
  }
}

///|
fn RustDecimal::checked_add(
  self : RustDecimal,
  other : RustDecimal,
) -> RustDecimal? {
  rd_add_sub(self, other, false)
}

///|
fn RustDecimal::checked_sub(
  self : RustDecimal,
  other : RustDecimal,
) -> RustDecimal? {
  rd_add_sub(self, other, true)
}

///|
/// `Add for Decimal` (panics on overflow).
fn RustDecimal::add(self : RustDecimal, other : RustDecimal) -> RustDecimal {
  match self.checked_add(other) {
    Some(d) => d
    None => abort("Addition overflowed")
  }
}

///|
/// `Sub for Decimal` (panics on overflow).
fn RustDecimal::sub(self : RustDecimal, other : RustDecimal) -> RustDecimal {
  match self.checked_sub(other) {
    Some(d) => d
    None => abort("Subtraction overflowed")
  }
}

///|
let u32_limit : @bigint.BigInt = big_one << 32

///|
/// rust_decimal's `mul_impl`.
fn RustDecimal::checked_mul(
  self : RustDecimal,
  other : RustDecimal,
) -> RustDecimal? {
  if self.is_zero() || other.is_zero() {
    return Some(rd_zero)
  }
  let scale = self.scale + other.scale
  let negative = self.negative != other.negative
  let product = self.mantissa * other.mantissa
  if self.mantissa < u32_limit && other.mantissa < u32_limit {
    // Two 32-bit integers.
    if scale > rd_max_scale {
      if scale > rd_max_scale + 19 {
        return Some(rd_zero)
      }
      let q = rd_round_half_even(product, scale - rd_max_scale)
      return Some(RustDecimal::from_parts(q, negative, rd_max_scale))
    }
    return Some(RustDecimal::from_parts(product, negative, scale))
  }
  if product >= overflow_u96 || scale > rd_max_scale {
    match rd_rescale(product, scale) {
      // The sign is kept even if the result was rounded to zero.
      Some((m, s)) => Some(RustDecimal::raw(m, negative, s))
      None => None
    }
  } else {
    Some(RustDecimal::raw(product, negative, scale))
  }
}

///|
/// `Buf12::find_scale`: the largest power of ten (at most 9) by which the
/// quotient can be scaled without exceeding 96 bits or the maximum scale.
/// `None` if no scaling is possible while the scale is negative.
fn rd_find_scale(quotient : @bigint.BigInt, scale : Int) -> Int? {
  let limit = if rd_max_scale - scale < 9 { rd_max_scale - scale } else { 9 }
  let mut x = 0
  while x < limit && quotient * rd_pow10(x + 1) < overflow_u96 {
    x += 1
  }
  // Scaling by the full 10^9 is accepted without checking the scale.
  if x < 9 && x + scale < 0 {
    None
  } else {
    Some(x)
  }
}

///|
/// `unscale_from_overflow`: divides a quotient that overflowed 96 bits by
/// ten, rounding half to even (or up if `sticky`).
fn rd_unscale_from_overflow(
  quotient : @bigint.BigInt,
  scale : Int,
  sticky : Bool,
) -> (@bigint.BigInt, Int)? {
  let scale = scale - 1
  if scale < 0 {
    return None
  }
  let q = quotient / big_ten
  let rem = (quotient - q * big_ten).to_int()
  let q = if rem > 5 || (rem == 5 && (sticky || big_is_odd(q))) {
    q + big_one
  } else {
    q
  }
  Some((q, scale))
}

///|
/// The `unscale` step of division: strips trailing zeros like rust_decimal
/// (which only strips eight zeros at once if the low 32 bits are zero).
fn rd_unscale(q : @bigint.BigInt, scale : Int) -> (@bigint.BigInt, Int) {
  let mut q = q
  let mut scale = scale
  let low = fn(q : @bigint.BigInt, mask : Int64) -> Int64 {
    q.land(@bigint.BigInt::from_int64(mask)).to_int64()
  }
  let try_div = fn(q : @bigint.BigInt, p : Int) -> @bigint.BigInt? {
    let pp = rd_pow10(p)
    let d = q / pp
    if d * pp == q {
      Some(d)
    } else {
      None
    }
  }
  while low(q, 0xFFFFFFFFL) == 0L && scale >= 8 {
    match try_div(q, 8) {
      Some(d) => {
        q = d
        scale -= 8
      }
      None => break
    }
  }
  if low(q, 0xFL) == 0L && scale >= 4 {
    if try_div(q, 4) is Some(d) {
      q = d
      scale -= 4
    }
  }
  if low(q, 0x3L) == 0L && scale >= 2 {
    if try_div(q, 2) is Some(d) {
      q = d
      scale -= 2
    }
  }
  if low(q, 0x1L) == 0L && scale >= 1 {
    if try_div(q, 1) is Some(d) {
      q = d
      scale -= 1
    }
  }
  (q, scale)
}

///|
/// rust_decimal's `div_impl`.
fn RustDecimal::checked_div(
  self : RustDecimal,
  other : RustDecimal,
) -> RustDecimal? {
  if other.is_zero() {
    return None
  }
  if self.is_zero() {
    return Some(rd_zero)
  }
  let mut scale = self.scale - other.scale
  let negative = self.negative != other.negative
  let divisor = other.mantissa
  let mut quotient = self.mantissa / divisor
  let mut remainder = self.mantissa - quotient * divisor
  let mut require_unscale = false
  if !remainder.is_zero() || scale < 0 {
    let mut power_scale = 0
    while true {
      if remainder.is_zero() {
        // If the scale is positive then we're actually done.
        if scale >= 0 {
          break
        }
        power_scale = if -scale < 9 { -scale } else { 9 }
      } else {
        require_unscale = true
        let will_overflow = if scale == rd_max_scale {
          true
        } else {
          match rd_find_scale(quotient, scale) {
            Some(s) => power_scale = s
            None => return None
          }
          power_scale == 0
        }
        if will_overflow {
          // No more scaling can be done, but the remainder is non-zero so
          // we round if necessary.
          let twice = remainder * @bigint.BigInt::from_int(2)
          if twice > divisor || (twice == divisor && big_is_odd(quotient)) {
            quotient = quotient + big_one
            if quotient >= overflow_u96 {
              match rd_unscale_from_overflow(quotient, scale, true) {
                Some((q, s)) => {
                  quotient = q
                  scale = s
                }
                None => return None
              }
            }
          }
          break
        }
      }
      // Do some scaling.
      let power = rd_pow10(power_scale)
      scale += power_scale
      quotient = quotient * power
      if quotient >= overflow_u96 {
        return None
      }
      let scaled = remainder * power
      let rq = scaled / divisor
      remainder = scaled - rq * divisor
      quotient = quotient + rq
      if quotient >= overflow_u96 {
        match rd_unscale_from_overflow(quotient, scale, !remainder.is_zero()) {
          Some((q, s)) => {
            quotient = q
            scale = s
          }
          None => return None
        }
        break
      }
    }
  }
  if require_unscale {
    let (q, s) = rd_unscale(quotient, scale)
    quotient = q
    scale = s
  }
  Some(RustDecimal::from_parts(quotient, negative, scale))
}

///|
/// rust_decimal's `rem_impl`: the remainder has the sign of the dividend and
/// the larger of both scales.
fn RustDecimal::checked_rem(
  self : RustDecimal,
  other : RustDecimal,
) -> RustDecimal? {
  if other.is_zero() {
    return None
  }
  if self.is_zero() {
    return Some(rd_zero)
  }
  let scale = if self.scale > other.scale { self.scale } else { other.scale }
  let a = self.mantissa * rd_pow10(scale - self.scale)
  let b = other.mantissa * rd_pow10(scale - other.scale)
  let ord = a.compare(b)
  if ord == 0 {
    return Some(rd_zero)
  } else if ord < 0 {
    return Some(self)
  }
  let r = a - a / b * b
  Some(RustDecimal::from_parts(r, self.negative, scale))
}

///|
/// Truncates the mantissa to the given (smaller) scale. Returns the result
/// and whether a non-zero digit was discarded.
fn RustDecimal::truncate_to(
  self : RustDecimal,
  scale : Int,
) -> (RustDecimal, Bool) {
  if self.scale <= scale {
    return (self, false)
  }
  if self.is_zero() {
    return ({ ..self, scale, }, false)
  }
  let p = rd_pow10(self.scale - scale)
  let q = self.mantissa / p
  let discarded = q * p != self.mantissa
  (RustDecimal::raw(q, self.negative, scale), discarded)
}

///|
/// Returns the integer part (the sign is kept, even for zero).
fn RustDecimal::trunc(self : RustDecimal) -> RustDecimal {
  self.truncate_to(0).0
}

///|
/// Returns the fractional part.
fn RustDecimal::fract(self : RustDecimal) -> RustDecimal {
  self.sub(self.trunc())
}

///|
fn RustDecimal::floor(self : RustDecimal) -> RustDecimal {
  if self.scale == 0 {
    return self
  }
  let (floored, had_fraction) = self.truncate_to(0)
  if self.negative && had_fraction {
    floored.sub(rd_one)
  } else {
    floored
  }
}

///|
fn RustDecimal::ceil(self : RustDecimal) -> RustDecimal {
  if self.scale == 0 {
    return self
  }
  let (truncated, had_fraction) = self.truncate_to(0)
  if !self.negative && had_fraction {
    truncated.add(rd_one)
  } else {
    truncated
  }
}

///|
fn RustDecimal::is_integer(self : RustDecimal) -> Bool {
  if self.scale == 0 || self.is_zero() {
    return true
  }
  let p = rd_pow10(self.scale)
  self.mantissa / p * p == self.mantissa
}

///|
/// `normalize`: strips trailing zeros (zero becomes positive with scale 0).
fn RustDecimal::normalize(self : RustDecimal) -> RustDecimal {
  if self.is_zero() {
    return rd_zero
  }
  let mut m = self.mantissa
  let mut scale = self.scale
  while scale > 0 {
    let q = m / big_ten
    if q * big_ten != m {
      break
    }
    m = q
    scale -= 1
  }
  RustDecimal::raw(m, self.negative, scale)
}

///|
/// `round_dp_with_strategy(dp, MidpointAwayFromZero)`.
fn RustDecimal::round_dp_away_from_zero(
  self : RustDecimal,
  dp : Int,
) -> RustDecimal {
  if self.scale <= dp {
    return self
  }
  if self.is_zero() {
    return RustDecimal::raw(big_zero, self.negative, dp)
  }
  let diff = self.scale - dp
  let p = rd_pow10(diff)
  let value = self.mantissa / p
  let portion = self.mantissa - value * p
  let cap = rd_pow10(diff - 1) * @bigint.BigInt::from_int(5)
  let value = if portion >= cap { value + big_one } else { value }
  RustDecimal::from_parts(value, self.negative, dp)
}

///|
/// `set_scale`: changes the scale without touching the mantissa.
fn RustDecimal::set_scale(self : RustDecimal, scale : Int) -> RustDecimal? {
  if scale > rd_max_scale {
    None
  } else {
    Some({ ..self, scale, })
  }
}

///|
/// `checked_powi` (`MathematicalOps`).
fn RustDecimal::checked_powi(self : RustDecimal, exp : Int64) -> RustDecimal? {
  // For negative exponents we change x^-y into 1 / x^y.
  if exp >= 0L {
    return rd_powu_wide(self, exp.reinterpret_as_uint64())
  }
  let pow = match rd_powu_wide(self, (-exp).reinterpret_as_uint64()) {
    Some(p) => p
    None => return None
  }
  rd_one.checked_div(pow)
}

///|
/// `powu_wide`.
fn rd_powu_wide(base : RustDecimal, exp : UInt64) -> RustDecimal? {
  if exp == 0UL {
    return Some(rd_one)
  }
  if base.is_zero() {
    return Some(rd_zero)
  }
  if base.cmp(rd_one) == 0 {
    return Some(rd_one)
  }
  if exp == 1UL {
    return Some(base)
  }
  if exp == 2UL {
    return base.checked_mul(base)
  }
  // Number of squarings = bit_length - 1.
  let squarings = 63 - exp.clz()
  if squarings < 10 {
    rd_powu_narrow(base, exp)
  } else {
    rd_powu_192(base, exp)
  }
}

///|
/// Exponentiation by squaring using 96-bit decimals.
fn rd_powu_narrow(base : RustDecimal, exp : UInt64) -> RustDecimal? {
  let mut product = rd_one
  let mut mask = exp
  let mut power = base
  for n in 0..<(64 - exp.clz()) {
    if n > 0 {
      power = match power.checked_mul(power) {
        Some(p) => p
        None => return None
      }
      mask = mask >> 1
    }
    if (mask & 1UL) > 0UL {
      product = match product.checked_mul(power) {
        Some(p) => p
        None => return None
      }
    }
  }
  Some(product.normalize())
}

// `DecWide`: 192-bit mantissa decimals, ported on 32-bit limbs because their
// rounding is irregular.

///|
priv struct DecWide {
  data : FixedArray[UInt]
  scale : Int
  negative : Bool
}

///|
fn DecWide::from_decimal(d : RustDecimal) -> DecWide {
  let data = FixedArray::make(6, 0U)
  let words = rd_words(d.mantissa)
  data[0] = words.0
  data[1] = words.1
  data[2] = words.2
  { data, scale: d.scale, negative: d.negative, }
}

///|
fn rd_words(m : @bigint.BigInt) -> (UInt, UInt, UInt) {
  let mask = @bigint.BigInt::from_uint64(0xFFFFFFFFUL)
  (m.land(mask).to_uint(), (m >> 32).land(mask).to_uint(), (m >> 64).to_uint())
}

///|
fn rd_from_words(lo : UInt, mid : UInt, hi : UInt) -> @bigint.BigInt {
  (@bigint.BigInt::from_uint(hi) << 64) +
  (@bigint.BigInt::from_uint(mid) << 32) +
  @bigint.BigInt::from_uint(lo)
}

///|
fn upper_word_n(data : FixedArray[UInt], n : Int) -> Int {
  let mut i = n - 1
  while i > 0 {
    if data[i] > 0U {
      return i
    }
    i -= 1
  }
  0
}

///|
fn DecWide::is_zero(self : DecWide) -> Bool {
  self.data.iter().all(w => w == 0U)
}

///|
fn wide_add_one(data : FixedArray[UInt]) -> Unit {
  let mut carry = 1UL
  for i in 0..<data.length() {
    carry += data[i].to_uint64()
    data[i] = carry.to_uint()
    carry = carry >> 32
    if carry == 0UL {
      break
    }
  }
}

///|
fn div_buf_by_power(
  data : FixedArray[UInt],
  upper : Ref[Int],
  power : UInt,
) -> Unit {
  let mut remainder = 0U
  let u = upper.val
  for i = u; i >= 0; i = i - 1 {
    let num = data[i].to_uint64() + (remainder.to_uint64() << 32)
    data[i] = (num / power.to_uint64()).to_uint()
    remainder = num.to_uint() - data[i] * power
  }
  if data[u] == 0U && u > 0 {
    upper.val = u - 1
  }
  let power_half = power >> 1
  if remainder > power_half || (remainder == power_half && (data[0] & 1U) != 0U) {
    wide_add_one(data)
  }
}

///|
let powers_10_u32 : FixedArray[UInt] = [
  1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
]

///|
fn rescale_buf(
  data : FixedArray[UInt],
  upper : Ref[Int],
  scale : Ref[Int],
  target : Int,
) -> Bool {
  let n = data.length()
  if upper.val <= target && scale.val <= rd_max_scale {
    return true
  }
  let mut rescale_target = if upper.val > target {
    let bits = (upper.val - target) * 32 - data[upper.val].clz()
    (((if bits > 0 { bits } else { 0 }) * 77) >> 8) + 1
  } else {
    0
  }
  let max_scale = if target <= 2 { rd_max_scale } else { 57 }
  if scale.val - rescale_target > max_scale {
    rescale_target = scale.val - max_scale
  }
  if rescale_target <= 0 && upper.val <= target {
    return true
  }
  if rescale_target > scale.val {
    return false
  }
  let mut sticky = 0U
  let mut remainder = 0U
  while rescale_target > 0 || upper.val > target {
    sticky = sticky | remainder
    let power_idx = if rescale_target < 1 {
      1
    } else if rescale_target > 9 {
      9
    } else {
      rescale_target
    }
    let power = powers_10_u32[power_idx]
    remainder = 0U
    for i = upper.val; i >= 0; i = i - 1 {
      let num = data[i].to_uint64() + (remainder.to_uint64() << 32)
      data[i] = (num / power.to_uint64()).to_uint()
      remainder = num.to_uint() - data[i] * power
    }
    while upper.val > 0 && data[upper.val] == 0U {
      upper.val -= 1
    }
    scale.val -= power_idx
    rescale_target -= power_idx
    if upper.val > target && rescale_target <= 0 {
      if scale.val <= 0 {
        return false
      }
      rescale_target = 1
    }
  }
  let sticky_combined = sticky | remainder
  if sticky_combined > 0U &&
    remainder > 0U &&
    ((data[0] & 1U) != 0U || remainder > 1U) {
    let mut carry = true
    for i in 0..<n {
      if carry {
        data[i] = data[i] + 1U
        carry = data[i] == 0U
      } else {
        break
      }
    }
    if carry || (target + 1 < n && data[target + 1] > 0U) {
      if scale.val <= 0 {
        return false
      }
      let power = 10U
      let mut rem2 = 0U
      for i = n - 1; i >= 0; i = i - 1 {
        if data[i] > 0U {
          upper.val = i
          break
        }
      }
      for i = upper.val; i >= 0; i = i - 1 {
        let num = data[i].to_uint64() + (rem2.to_uint64() << 32)
        data[i] = (num / power.to_uint64()).to_uint()
        rem2 = num.to_uint() - data[i] * power
      }
      while upper.val > 0 && data[upper.val] == 0U {
        upper.val -= 1
      }
      scale.val -= 1
    }
  }
  if scale.val < 0 || upper.val > target {
    return false
  }
  true
}

///|
fn DecWide::to_decimal(self : DecWide) -> RustDecimal? {
  let data = self.data.copy()
  let scale = Ref::new(self.scale)
  let upper = Ref::new(upper_word_n(data, 6))
  if upper.val <= 2 && scale.val <= rd_max_scale {
    return Some(
      RustDecimal::from_parts(
        rd_from_words(data[0], data[1], data[2]),
        self.negative,
        scale.val,
      ),
    )
  }
  if !rescale_buf(data, upper, scale, 2) {
    return None
  }
  Some(
    RustDecimal::from_parts(
      rd_from_words(data[0], data[1], data[2]),
      self.negative,
      scale.val,
    ),
  )
}

///|
fn DecWide::checked_mul(self : DecWide, other : DecWide) -> DecWide? {
  if self.is_zero() || other.is_zero() {
    return Some({ data: FixedArray::make(6, 0U), scale: 0, negative: false, })
  }
  let scale = self.scale + other.scale
  let negative = self.negative != other.negative
  let product = FixedArray::make(12, 0U)
  let a = self.data
  let b = other.data
  let a_upper = upper_word_n(a, 6)
  let b_upper = upper_word_n(b, 6)
  for i in 0..<=a_upper {
    let a_word = a[i]
    if a_word == 0U {
      continue
    }
    let mut carry = 0UL
    for j in 0..<=b_upper {
      let pos = i + j
      carry += a_word.to_uint64() * b[j].to_uint64() + product[pos].to_uint64()
      product[pos] = carry.to_uint()
      carry = carry >> 32
    }
    let mut pos = i + b_upper + 1
    while carry > 0UL && pos < 12 {
      carry += product[pos].to_uint64()
      product[pos] = carry.to_uint()
      carry = carry >> 32
      pos += 1
    }
  }
  let upper = Ref::new(upper_word_n(product, 12))
  let scale = Ref::new(scale)
  if upper.val <= 5 {
    let data = FixedArray::make(6, 0U)
    for i in 0..<6 {
      data[i] = product[i]
    }
    let max_wide_scale = 57
    if scale.val > max_wide_scale {
      let mut excess = scale.val - max_wide_scale
      let u = Ref::new(upper_word_n(data, 6))
      while excess > 0 {
        let power_idx = if excess < 9 { excess } else { 9 }
        div_buf_by_power(data, u, powers_10_u32[power_idx])
        excess -= power_idx
        scale.val -= power_idx
      }
    }
    return Some({ data, scale: scale.val, negative, })
  }
  if !rescale_buf(product, upper, scale, 5) {
    return None
  }
  let data = FixedArray::make(6, 0U)
  for i in 0..<6 {
    data[i] = product[i]
  }
  Some({ data, scale: scale.val, negative, })
}

///|
/// Exponentiation by squaring using 192-bit intermediates.
fn rd_powu_192(base : RustDecimal, exp : UInt64) -> RustDecimal? {
  let mut product = DecWide::from_decimal(rd_one)
  let mut mask = exp
  let mut power = DecWide::from_decimal(base)
  for n in 0..<(64 - exp.clz()) {
    if n > 0 {
      power = match power.checked_mul(power) {
        Some(p) => p
        None => return None
      }
      mask = mask >> 1
    }
    if (mask & 1UL) > 0UL {
      product = match product.checked_mul(power) {
        Some(p) => p
        None => return None
      }
    }
  }
  match product.to_decimal() {
    Some(result) => Some(result.normalize())
    None => None
  }
}

///|
/// Parses a decimal exactly (`Decimal::from_str_exact`): fails instead of
/// rounding digits that do not fit.
fn RustDecimal::from_str_exact(s : String) -> RustDecimal? {
  // Only ASCII is valid, so we can work on UTF-16 code units; any other
  // character is rejected below.
  let len = s.length()
  if len == 0 {
    return None
  }
  // Strings of at least 18 bytes take the "big" path, which rejects any
  // further byte once 28 fractional digits were read.
  let big = @syntax.utf8_len(s) >= 18
  let mut i = 0
  let mut negative = false
  if s.code_unit_at(0).to_int() == '-'.to_int() {
    negative = true
    i = 1
  } else if s.code_unit_at(0).to_int() == '+'.to_int() {
    i = 1
  }
  let mut has = false
  let mut point = false
  let mut mantissa = big_zero
  let mut scale = 0
  while i < len {
    let b = s.code_unit_at(i).to_int()
    i += 1
    if b >= '0'.to_int() && b <= '9'.to_int() {
      has = true
      mantissa = mantissa * big_ten + @bigint.BigInt::from_int(b - '0'.to_int())
      if point {
        scale += 1
      }
      if mantissa >= overflow_u96 {
        return None
      }
      if point && big && scale >= rd_max_scale && i < len {
        return None
      }
    } else if b == '.'.to_int() && !point {
      point = true
    } else if b == '_'.to_int() && has {
      ()
    } else {
      return None
    }
  }
  if !has {
    return None
  }
  Some(RustDecimal::from_parts(mantissa, negative, scale))
}

///|
/// `Decimal::from_f64_retain`: converts a float exactly as far as possible.
fn RustDecimal::from_f64_retain(n : Double) -> RustDecimal? {
  if n.is_nan() || n.is_inf() {
    return None
  }
  let raw = n.reinterpret_as_uint64()
  let positive = raw >> 63 == 0UL
  let biased_exponent = ((raw >> 52) & 0x7FFUL).to_int()
  let mantissa = raw & 0x000F_FFFF_FFFF_FFFFUL
  // Handle the special zero case.
  if biased_exponent == 0 && mantissa == 0UL {
    return Some(RustDecimal::raw(big_zero, !positive, 0))
  }
  let mut exponent2 = biased_exponent - 1023
  let mut bits = @bigint.BigInt::from_uint64(mantissa)
  if biased_exponent == 0 {
    // Denormalized number - correct the exponent.
    exponent2 += 1
  } else {
    // Add extra hidden bit to mantissa.
    bits = bits + (big_one << 52)
  }
  exponent2 -= 52
  // base2_to_decimal
  let mut exponent5 = -exponent2
  let mut exponent10 = exponent2
  let five = @bigint.BigInt::from_int(5)
  while exponent5 > 0 {
    if !big_is_odd(bits) {
      exponent10 += 1
      exponent5 -= 1
      bits = bits >> 1
    } else {
      exponent5 -= 1
      let temp = bits * five
      if temp < overflow_u96 {
        bits = temp
      } else {
        exponent10 += 1
        bits = bits >> 1
      }
    }
  }
  let sign_bit = big_one << 95
  while exponent5 < 0 {
    if bits < sign_bit {
      exponent10 -= 1
      exponent5 += 1
      bits = bits << 1
    } else if exponent10 * 2 > -exponent5 {
      return None
    } else {
      exponent5 += 1
      bits = bits / five
    }
  }
  while exponent10 > 0 {
    let temp = bits * big_ten
    if temp < overflow_u96 {
      bits = temp
      exponent10 -= 1
    } else {
      return None
    }
  }
  while exponent10 < -rd_max_scale {
    let q = bits / big_ten
    let rem10 = (bits - q * big_ten).to_int()
    bits = q
    exponent10 += 1
    if bits.is_zero() {
      exponent10 = 0
    } else if rem10 >= 5 {
      bits = bits + big_one
    }
  }
  Some(RustDecimal::raw(bits, !positive, -exponent10))
}

///|
/// Converts a non-negative big integer to the nearest float (ties to even),
/// like Rust's `u128 as f64`.
fn big_to_f64(n : @bigint.BigInt) -> Double {
  let bl = n.bit_length()
  if bl <= 53 {
    return n.to_int64().to_double()
  }
  let mut shift = bl - 53
  let mut m = n >> shift
  let rem = n - (m << shift)
  let half = big_one << (shift - 1)
  if rem > half || (rem == half && big_is_odd(m)) {
    m = m + big_one
    if m.bit_length() > 53 {
      m = m >> 1
      shift += 1
    }
  }
  m.to_int64().to_double() * @math.pow(2.0, shift.to_double())
}

///|
/// LLVM's `powi` (compiler-rt `__powidf2`) as used by Rust's `f64::powi`.
fn rust_powi(a : Double, b : Int) -> Double {
  let recip = b < 0
  let mut a = a
  let mut b = b
  let mut r = 1.0
  while true {
    if (b & 1) != 0 {
      r *= a
    }
    b /= 2
    if b == 0 {
      break
    }
    a *= a
  }
  if recip {
    1.0 / r
  } else {
    r
  }
}

///|
/// `Decimal::as_f64` (the `TryFrom<Decimal> for f64` conversion).
fn RustDecimal::to_f64(self : RustDecimal) -> Double {
  if self.scale == 0 {
    let v = big_to_f64(self.mantissa)
    return if self.negative { -v } else { v }
  }
  let neg = self.negative
  let precision = rd_pow10(self.scale)
  let integral_part = self.mantissa / precision
  let frac_part = self.mantissa - integral_part * precision
  let frac_f64 = big_to_f64(frac_part) / big_to_f64(precision)
  let integral = big_to_f64(integral_part)
  if frac_f64 == 0.0 {
    return if neg { -integral } else { integral }
  }
  let value = integral + frac_f64
  let round_to = rust_powi(10.0, self.scale)
  let rounded = rust_round(value * round_to) / round_to
  if neg {
    -rounded
  } else {
    rounded
  }
}

///|
/// `ToPrimitive::to_i64`: truncates, `None` if out of range.
fn RustDecimal::to_i64(self : RustDecimal) -> Int64? {
  let d = self.trunc()
  let max = @bigint.BigInt::from_int64(@int64.max_value)
  if d.mantissa > max {
    if self.negative && d.mantissa == max + big_one {
      return Some(@int64.min_value)
    }
    return None
  }
  let raw = d.mantissa.to_int64()
  Some(if self.negative { -raw } else { raw })
}

///|
/// rust_decimal's `Display` without the sign (`to_str_internal`).
fn RustDecimal::abs_to_string(self : RustDecimal) -> String {
  let digits = if self.mantissa.is_zero() {
    ""
  } else {
    self.mantissa.to_string()
  }
  let scale = self.scale
  let digits = if digits.length() < scale {
    "0".repeat(scale - digits.length()) + digits
  } else {
    digits
  }
  let chars = digits.to_array()
  let len = chars.length()
  let whole_len = len - scale
  let buf = StringBuilder()
  for i in 0..<len {
    if i == whole_len {
      if i == 0 {
        buf.write_char('0')
      }
      buf.write_char('.')
    }
    buf.write_char(chars[i])
  }
  let out = buf.to_string()
  if out.is_empty() {
    "0"
  } else {
    out
  }
}

///|
/// rust_decimal's `Display`: a `-` for a set sign bit (also for zero).
fn RustDecimal::to_string(self : RustDecimal) -> String {
  if self.negative {
    "-" + self.abs_to_string()
  } else {
    self.abs_to_string()
  }
}
