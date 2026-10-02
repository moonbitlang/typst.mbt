// Port of the parts of `pxfm::double_double` used by `f_pow` / `f_powf`
// (the aarch64 FMA variants).

///|
priv struct DoubleDouble {
  lo : Double
  hi : Double
}

///|
fn DoubleDouble::new(lo : Double, hi : Double) -> DoubleDouble {
  { lo, hi, }
}

///|
fn DoubleDouble::from_bit_pair(lo : UInt64, hi : UInt64) -> DoubleDouble {
  { lo: lo.reinterpret_as_double(), hi: hi.reinterpret_as_double(), }
}

///|
/// Valid only for |a| > b.
fn DoubleDouble::from_exact_add(a : Double, b : Double) -> DoubleDouble {
  let r_hi = a + b
  let t = r_hi - a
  let r_lo = b - t
  DoubleDouble::new(r_lo, r_hi)
}

///|
fn DoubleDouble::from_full_exact_add(a : Double, b : Double) -> DoubleDouble {
  let r_hi = a + b
  let t1 = r_hi - a
  let t2 = r_hi - t1
  let t3 = b - t1
  let t4 = a - t2
  let r_lo = t3 + t4
  DoubleDouble::new(r_lo, r_hi)
}

///|
fn DoubleDouble::add(a : DoubleDouble, b : DoubleDouble) -> DoubleDouble {
  let s = a.hi + b.hi
  let d = s - a.hi
  let l = b.hi - d + (a.hi + (d - s)) + (a.lo + b.lo)
  DoubleDouble::new(l, s)
}

///|
/// Valid only |a.hi| > |b|.
fn DoubleDouble::add_f64(a : DoubleDouble, b : Double) -> DoubleDouble {
  let t = DoubleDouble::from_exact_add(a.hi, b)
  let l = a.lo + t.lo
  { lo: l, hi: t.hi, }
}

///|
fn DoubleDouble::f64_add(b : Double, a : DoubleDouble) -> DoubleDouble {
  let t = DoubleDouble::from_exact_add(b, a.hi)
  let l = a.lo + t.lo
  { lo: l, hi: t.hi, }
}

///|
fn DoubleDouble::from_exact_mult(a : Double, b : Double) -> DoubleDouble {
  let r_hi = a * b
  let r_lo = fma(a, b, -r_hi)
  DoubleDouble::new(r_lo, r_hi)
}

///|
fn DoubleDouble::quick_mult(a : DoubleDouble, b : DoubleDouble) -> DoubleDouble {
  let r = DoubleDouble::from_exact_mult(a.hi, b.hi)
  let t1 = fma(a.hi, b.lo, r.lo)
  let t2 = fma(a.lo, b.hi, t1)
  { lo: t2, hi: r.hi, }
}

///|
fn DoubleDouble::mult(a : DoubleDouble, b : DoubleDouble) -> DoubleDouble {
  let { hi: ch, lo: cl1, } = DoubleDouble::from_exact_mult(a.hi, b.hi)
  let tl0 = a.lo * b.lo
  let tl1 = fma(a.hi, b.lo, tl0)
  let cl2 = fma(a.lo, b.hi, tl1)
  let cl3 = cl1 + cl2
  DoubleDouble::from_exact_add(ch, cl3)
}

///|
fn DoubleDouble::quick_mult_f64(a : DoubleDouble, b : Double) -> DoubleDouble {
  let h = b * a.hi
  let l = fma(b, a.lo, fma(b, a.hi, -h))
  { lo: l, hi: h, }
}

///|
fn DoubleDouble::quick_mul_add(
  a : DoubleDouble,
  b : DoubleDouble,
  c : DoubleDouble,
) -> DoubleDouble {
  let { hi: h, lo: r, } = DoubleDouble::quick_mult(a, b)
  let { hi: p, lo: q, } = DoubleDouble::add_f64(c, h)
  DoubleDouble::new(r + q, p)
}

///|
/// Accurate reciprocal: 1 / self.
fn DoubleDouble::recip(self : DoubleDouble) -> DoubleDouble {
  let y = 1.0 / self.hi
  let e1 = fma(-self.hi, y, 1.0)
  let e2 = fma(-self.lo, y, e1)
  let e = y * e2
  DoubleDouble::new(e, y)
}

///|
fn DoubleDouble::to_f64(self : DoubleDouble) -> Double {
  self.lo + self.hi
}

///|
fn dd_quick_polyeval6(
  x : DoubleDouble,
  a0 : DoubleDouble,
  a1 : DoubleDouble,
  a2 : DoubleDouble,
  a3 : DoubleDouble,
  a4 : DoubleDouble,
  a5 : DoubleDouble,
) -> DoubleDouble {
  let x2 = DoubleDouble::quick_mult(x, x)
  let u0 = DoubleDouble::quick_mul_add(x, a5, a4)
  let u1 = DoubleDouble::quick_mul_add(x, a3, a2)
  let u2 = DoubleDouble::quick_mul_add(x, a1, a0)
  let v0 = DoubleDouble::quick_mul_add(x2, u0, u1)
  DoubleDouble::quick_mul_add(x2, v0, u2)
}

///|
fn dd_quick_polyeval10(
  x : DoubleDouble,
  a : FixedArray[DoubleDouble],
) -> DoubleDouble {
  let x2 = DoubleDouble::quick_mult(x, x)
  let x4 = DoubleDouble::quick_mult(x2, x2)
  let x8 = DoubleDouble::quick_mult(x4, x4)
  let p0 = DoubleDouble::quick_mul_add(x, a[1], a[0])
  let p1 = DoubleDouble::quick_mul_add(x, a[3], a[2])
  let p2 = DoubleDouble::quick_mul_add(x, a[5], a[4])
  let p3 = DoubleDouble::quick_mul_add(x, a[7], a[6])
  let p4 = DoubleDouble::quick_mul_add(x, a[9], a[8])
  let q0 = DoubleDouble::quick_mul_add(x2, p1, p0)
  let q1 = DoubleDouble::quick_mul_add(x2, p3, p2)
  let r0 = DoubleDouble::quick_mul_add(x4, q1, q0)
  DoubleDouble::quick_mul_add(x8, p4, r0)
}

///|
/// `f_polyeval3(x, a0, a1, a2) = a0 + x * (a1 + x * a2)` with FMAs.
fn f_polyeval3(x : Double, a0 : Double, a1 : Double, a2 : Double) -> Double {
  fma(x, fma(x, a2, a1), a0)
}
