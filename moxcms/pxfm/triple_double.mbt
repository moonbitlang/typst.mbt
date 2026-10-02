// Port of the parts of `pxfm::triple_double` used by `f_pow`.

///|
priv struct TripleDouble {
  hi : Double
  mid : Double
  lo : Double
}

///|
fn TripleDouble::new(lo : Double, mid : Double, hi : Double) -> TripleDouble {
  { hi, mid, lo, }
}

///|
fn add12(a : Double, b : Double) -> DoubleDouble {
  DoubleDouble::from_full_exact_add(a, b)
}

///|
fn mul12(a : Double, b : Double) -> DoubleDouble {
  DoubleDouble::from_exact_mult(a, b)
}

///|
fn add22(a : DoubleDouble, b : DoubleDouble) -> DoubleDouble {
  let { hi: v1, lo: v2, } = DoubleDouble::from_full_exact_add(a.hi, b.hi)
  let v3 = a.lo + b.lo
  let v4 = v2 + v3
  DoubleDouble::from_full_exact_add(v1, v4)
}

///|
fn TripleDouble::quick_mult(b : TripleDouble, a : TripleDouble) -> TripleDouble {
  let { hi: rh, lo: t1, } = DoubleDouble::from_exact_mult(a.hi, b.hi)
  let { hi: t2, lo: t3, } = DoubleDouble::from_exact_mult(a.hi, b.mid)
  let { hi: t4, lo: t5, } = DoubleDouble::from_exact_mult(a.mid, b.hi)
  let { hi: t6, lo: t7, } = DoubleDouble::from_exact_mult(a.mid, b.mid)
  let t12 = fma(a.hi, b.lo, a.lo * b.hi)
  let t13 = fma(a.mid, b.lo, a.lo * b.mid)
  let { hi: t14, lo: t15, } = add12(t1, t6)
  let t16 = t7 + t15
  let t17 = t12 + t13
  let t18 = t16 + t17
  let { hi: t19, lo: t20, } = add12(t14, t18)
  let { hi: t21, lo: t22, } = add22(
    DoubleDouble::new(t3, t2),
    DoubleDouble::new(t4, t5),
  )
  let { hi: rm, lo: rl, } = add22(
    DoubleDouble::new(t22, t21),
    DoubleDouble::new(t20, t19),
  )
  TripleDouble::new(rl, rm, rh)
}

///|
fn TripleDouble::quick_mult_dd(
  b : TripleDouble,
  a : DoubleDouble,
) -> TripleDouble {
  let { hi: rh, lo: t1, } = mul12(a.hi, b.hi)
  let { hi: t2, lo: t3, } = mul12(a.hi, b.mid)
  let { hi: t4, lo: t5, } = mul12(a.hi, b.lo)
  let { hi: t6, lo: t7, } = mul12(a.lo, b.hi)
  let { hi: t8, lo: t9, } = mul12(a.lo, b.mid)
  let t10 = a.lo * b.lo
  let z0 = add22(DoubleDouble::new(t3, t2), DoubleDouble::new(t4, t5))
  let z1 = add22(DoubleDouble::new(t6, t7), DoubleDouble::new(t8, t9))
  let q0 = add22(z0, z1)
  let q1 = add12(t1, t10)
  let { hi: rm, lo: rl, } = add22(q1, q0)
  { hi: rh, mid: rm, lo: rl, }
}

///|
fn TripleDouble::to_f64(self : TripleDouble) -> Double {
  let { hi: t1, lo: t2, } = add12(self.hi, self.mid)
  let t3 = t2 + self.lo
  t1 + t3
}

///|
fn TripleDouble::renormalize(self : TripleDouble) -> TripleDouble {
  let { hi: t1h, lo: t1l, } = DoubleDouble::from_exact_add(self.mid, self.lo)
  let { hi: rh, lo: t2l, } = DoubleDouble::from_exact_add(self.hi, t1h)
  let zml = DoubleDouble::from_exact_add(t2l, t1l)
  TripleDouble::new(zml.lo, zml.hi, rh)
}

///|
fn TripleDouble::neg(self : TripleDouble) -> TripleDouble {
  TripleDouble::new(-self.lo, -self.mid, -self.hi)
}

///|
fn TripleDouble::recip(self : TripleDouble) -> TripleDouble {
  let mut r1 = 1.0 / self.hi
  let { hi: rec_t1, lo: rec_t2, } = DoubleDouble::from_exact_mult(r1, self.hi)
  let rec_t3 = rec_t1 - 1.0
  let { hi: rec_t4, lo: rec_t5, } = add12(rec_t3, rec_t2)
  let { hi: rec_t6, lo: rec_t7, } = mul12(r1, self.mid)
  let { hi: rec_t8, lo: rec_t9, } = add12(-1.0, rec_t6)
  let rec_t10 = rec_t9 + rec_t7
  r1 = -r1
  let { hi: rec_t11, lo: rec_t12, } = add12(rec_t8, rec_t10)
  let z0 = add22(
    DoubleDouble::new(rec_t5, rec_t4),
    DoubleDouble::new(rec_t12, rec_t11),
  )
  let r2hl = DoubleDouble::quick_mult_f64(z0, r1)
  let rec15_16_17 = TripleDouble::quick_mult_dd(self, r2hl)
  let rec18_19_20 = rec15_16_17.renormalize()
  let rec_t18 = -1.0
  let rec_21_22_23 = TripleDouble::quick_mult_dd(
    TripleDouble::new(rec18_19_20.lo, rec18_19_20.mid, rec_t18),
    r2hl,
  ).neg()
  rec_21_22_23.renormalize()
}
