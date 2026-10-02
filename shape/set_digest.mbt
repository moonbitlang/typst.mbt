// Port of rustybuzz 0.20.1 `src/hb/set_digest.rs`.
//
// `hb_set_digest_t` is the combiner of bits patterns with shifts 4, 0 and 9
// over 64-bit masks; it is flattened into three masks here.

///|
priv struct SetDigest {
  mut m4 : UInt64
  mut m0 : UInt64
  mut m9 : UInt64
}

///|
fn SetDigest::new() -> SetDigest {
  { m4: 0, m0: 0, m9: 0, }
}

///|
fn SetDigest::copy(self : SetDigest) -> SetDigest {
  { m4: self.m4, m0: self.m0, m9: self.m9, }
}

///|
fn digest_mask_for(g : Int, shift : Int) -> UInt64 {
  1UL << ((g.to_uint64() >> shift) & 63).to_int()
}

///|
/// `hb_set_digest_bits_pattern_t::add_range` on one mask.
fn digest_add_range(mask : UInt64, a : Int, b : Int, shift : Int) -> UInt64 {
  if mask == 0xFFFFFFFFFFFFFFFFUL {
    return mask
  }
  // (b >> shift) - (a >> shift) in u64 (wraps when b < a).
  let d = (b.to_uint64() >> shift) - (a.to_uint64() >> shift)
  if d >= 63 {
    0xFFFFFFFFFFFFFFFFUL
  } else {
    let ma = digest_mask_for(a, shift)
    let mb = digest_mask_for(b, shift)
    mask | (mb + (mb - ma) - (if mb < ma { 1UL } else { 0UL }))
  }
}

///|
fn SetDigest::add(self : SetDigest, g : Int) -> Unit {
  self.m4 = self.m4 | digest_mask_for(g, 4)
  self.m0 = self.m0 | digest_mask_for(g, 0)
  self.m9 = self.m9 | digest_mask_for(g, 9)
}

///|
fn SetDigest::add_range(self : SetDigest, a : Int, b : Int) -> Unit {
  self.m4 = digest_add_range(self.m4, a, b, 4)
  self.m0 = digest_add_range(self.m0, a, b, 0)
  self.m9 = digest_add_range(self.m9, a, b, 9)
}

///|
fn SetDigest::may_have(self : SetDigest, o : SetDigest) -> Bool {
  (self.m4 & o.m4) != 0 && (self.m0 & o.m0) != 0 && (self.m9 & o.m9) != 0
}

///|
fn SetDigest::may_have_glyph(self : SetDigest, g : Int) -> Bool {
  (self.m4 & digest_mask_for(g, 4)) != 0 &&
  (self.m0 & digest_mask_for(g, 0)) != 0 &&
  (self.m9 & digest_mask_for(g, 9)) != 0
}
