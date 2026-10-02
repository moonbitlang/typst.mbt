// Port of rustybuzz 0.20.1 `src/hb/common.rs` `mod tests_features`.

///|
fn check_feature(text : String, tag : String, value : UInt, start : UInt, end : UInt) -> Unit raise {
  let f = @shape.Feature::from_str(text).unwrap()
  assert_eq(f.tag, @otf.Tag::from_str(tag))
  assert_eq(f.value, value)
  assert_eq(f.start, start)
  assert_eq(f.end, end)
}

///|
test "parse features" {
  let max = 0xFFFFFFFFU
  check_feature("kern", "kern", 1, 0, max)
  check_feature("+kern", "kern", 1, 0, max)
  check_feature("-kern", "kern", 0, 0, max)
  check_feature("kern=0", "kern", 0, 0, max)
  check_feature("kern=1", "kern", 1, 0, max)
  check_feature("kern=2", "kern", 2, 0, max)
  check_feature("kern[]", "kern", 1, 0, max)
  check_feature("kern[:]", "kern", 1, 0, max)
  // `5..` is start=5, end=MAX.
  check_feature("kern[5:]", "kern", 1, 5, max)
  // `..=5` is start=0, end=5.
  check_feature("kern[:5]", "kern", 1, 0, 5)
  check_feature("kern[3:5]", "kern", 1, 3, 5)
  // `3..=4`.
  check_feature("kern[3]", "kern", 1, 3, 4)
  check_feature("kern[3:5]=2", "kern", 2, 3, 5)
  check_feature("kern[3;5]=2", "kern", 2, 3, 5)
  check_feature("kern[:-1]", "kern", 1, 0, max)
  // `u32::MAX as usize..`.
  check_feature("kern[-1]", "kern", 1, max, max)
  check_feature("kern=on", "kern", 1, 0, max)
  check_feature("kern=off", "kern", 0, 0, max)
  check_feature("kern=oN", "kern", 1, 0, max)
  check_feature("kern=oFf", "kern", 0, 0, max)
}

///|
test "parse variations" {
  let v = @shape.Variation::from_str("wght=500").unwrap()
  assert_eq(v.tag, @otf.Tag::from_str("wght"))
  assert_eq(v.value, Float::from_int(500))
  assert_eq(@shape.Variation::from_str("wght=").is_empty(), true)
}
