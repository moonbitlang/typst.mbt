// Differential tests against `pxfm` 0.1.30 (expected hashes produced by the
// oracle in moxcms/oracle).

///|
priv struct Rng {
  mut state : UInt
}

///|
fn Rng::next(self : Rng) -> UInt {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  x
}

///|
priv struct Fnv {
  mut h : UInt64
}

///|
fn Fnv::new() -> Fnv {
  { h: 0xcbf29ce484222325UL, }
}

///|
fn Fnv::byte(self : Fnv, b : UInt64) -> Unit {
  self.h = (self.h ^ b) * 0x100000001b3UL
}

///|
fn Fnv::u32(self : Fnv, v : UInt) -> Unit {
  let v = v.to_uint64()
  for i in 0..<4 {
    self.byte((v >> (8 * i)) & 0xffUL)
  }
}

///|
fn Fnv::u64(self : Fnv, v : UInt64) -> Unit {
  for i in 0..<8 {
    self.byte((v >> (8 * i)) & 0xffUL)
  }
}

///|
fn powf_hash(n : Int) -> UInt64 {
  let rng = { state: 2463534242U, }
  let h = Fnv::new()
  for _ in 0..<n {
    let a = Float::reinterpret_from_uint((rng.next() >> 9) | 0x3f800000U) - 1.0
    let x = a + Float::from_uint(rng.next() & 1U)
    let y = Float::from_uint(rng.next() >> 8) / 16777216.0 * 5.0 + 0.05
    h.u32(f_powf(x, y).reinterpret_as_uint())
  }
  h.h
}

///|
fn pow_hash(n : Int) -> UInt64 {
  let rng = { state: 2463534242U, }
  let h = Fnv::new()
  for _ in 0..<n {
    let hi = (rng.next() >> 12).to_uint64()
    let lo = rng.next().to_uint64()
    let x = (0x3ff0000000000000UL | (hi << 32) | lo).reinterpret_as_double() -
      1.0
    let y = (rng.next() >> 8).to_double() / 16777216.0 * 5.0 + 0.05
    h.u64(f_pow(x, y).reinterpret_as_uint64())
  }
  h.h
}

///|
test "f_powf matches pxfm" {
  assert_eq(powf_hash(1000), 0x36844b260d781870UL)
  assert_eq(powf_hash(1000000), 0x0b0001182270b046UL)
}

///|
test "f_pow matches pxfm" {
  assert_eq(pow_hash(1000), 0x3b83bd717fd97d30UL)
  assert_eq(pow_hash(1000000), 0xee4f2aea0cb672adUL)
}

///|
test "table sizes" {
  assert_eq(pow_inverse.length(), 182)
  assert_eq(pow_log_inv.length(), 364)
  assert_eq(exp2_mid1.length(), 128)
  assert_eq(powf_r2.length(), 193)
  assert_eq(log2_r_td.length(), 384)
  assert_eq(log2_r2_dd.length(), 386)
  assert_eq(exp_reduce_t0.length(), 128)
  assert_eq(exp_reduce_t1.length(), 128)
  assert_eq(log_reduction_f32.length(), 128)
  assert_eq(log2_r.length(), 128)
}

///|
test "fma matches exact big integer evaluation" {
  let rng = { state: 88172645U, }
  let rnd = (lo_e : UInt, range : UInt) => {
    let hi = rng.next().to_uint64()
    let lo = rng.next().to_uint64()
    let e = (rng.next() % range + lo_e).to_uint64()
    let bits = (((hi << 32) | lo) & 0x800fffffffffffffUL) | (e << 52)
    bits.reinterpret_as_double()
  }
  for i in 0..<20000 {
    // Exponents in [-100, 99], and over the whole range (incl. subnormals,
    // overflow) every 8th iteration.
    let (lo_e, range) = if i % 8 == 0 { (0U, 2047U) } else { (923U, 200U) }
    let a = rnd(lo_e, range)
    let b = rnd(lo_e, range)
    let c = rnd(lo_e, range)
    let want = fma_exact(a, b, c).reinterpret_as_uint64()
    if !a.is_inf() && !b.is_inf() && !c.is_inf() && !(a * b).is_inf() {
      assert_eq(fma(a, b, c).reinterpret_as_uint64(), want)
      assert_eq(soft_fma(a, b, c).reinterpret_as_uint64(), want)
    }
    // Heavy cancellation.
    let c2 = -(a * b)
    if !c2.is_inf() && !a.is_inf() && !b.is_inf() {
      let want = fma_exact(a, b, c2).reinterpret_as_uint64()
      assert_eq(fma(a, b, c2).reinterpret_as_uint64(), want)
      assert_eq(soft_fma(a, b, c2).reinterpret_as_uint64(), want)
    }
  }
}

///|
test "software fmaf matches fmaf" {
  let rng = { state: 2463534242U, }
  for i in 0..<200000 {
    let mask = if i % 4 == 0 { 0xffffffffU } else { 0x83ffffffU }
    let bias = if i % 4 == 0 { 0U } else { 0x3c000000U }
    let f = () => Float::reinterpret_from_uint((rng.next() & mask) | bias)
    let a = f()
    let b = f()
    let c = f()
    let want = fmaf(a, b, c)
    let got = soft_fmaf(a, b, c)
    assert_true(
      got.reinterpret_as_uint() == want.reinterpret_as_uint() ||
      (got.is_nan() && want.is_nan()),
    )
  }
}
