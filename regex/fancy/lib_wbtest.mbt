// Port of the unit tests of `fancy-regex` 0.16.2 `src/lib.rs`.

///|
test "to_str_concat_alt" {
  let e = Concat([
    Alt([make_literal("a"), make_literal("b")]),
    make_literal("c"),
  ])
  assert_eq(expr_to_str(e), "(?:a|b)c")
}

///|
test "to_str_rep_concat" {
  let e = Repeat(
    child=Concat([make_literal("a"), make_literal("b")]),
    lo=2,
    hi=3,
    greedy=true,
  )
  assert_eq(expr_to_str(e), "(?:ab){2,3}")
}

///|
test "to_str_group_alt" {
  let e = Group(Alt([make_literal("a"), make_literal("b")]))
  assert_eq(expr_to_str(e), "(a|b)")
}

///|
test "as_str_debug" {
  let s = "(a+)b\\1"
  let regex = Regex::new(s)
  assert_eq(s, regex.as_str())
  assert_eq(s, regex.to_string())
}

///|
test "display" {
  let s = "(a+)b\\1"
  let regex = Regex::new(s)
  assert_eq(s, "\{regex}")
}

///|
test "to_str_repeat" {
  fn repeat(lo : Int, hi : Int, greedy : Bool) -> Expr {
    Repeat(child=make_literal("a"), lo~, hi~, greedy~)
  }

  assert_eq(expr_to_str(repeat(2, 2, true)), "a{2}")
  assert_eq(expr_to_str(repeat(2, 2, false)), "a{2}?")
  assert_eq(expr_to_str(repeat(2, 3, true)), "a{2,3}")
  assert_eq(expr_to_str(repeat(2, 3, false)), "a{2,3}?")
  assert_eq(expr_to_str(repeat(2, USIZE_MAX, true)), "a{2,}")
  assert_eq(expr_to_str(repeat(2, USIZE_MAX, false)), "a{2,}?")
  assert_eq(expr_to_str(repeat(0, 1, true)), "a?")
  assert_eq(expr_to_str(repeat(0, 1, false)), "a??")
  assert_eq(expr_to_str(repeat(0, USIZE_MAX, true)), "a*")
  assert_eq(expr_to_str(repeat(0, USIZE_MAX, false)), "a*?")
  assert_eq(expr_to_str(repeat(1, USIZE_MAX, true)), "a+")
  assert_eq(expr_to_str(repeat(1, USIZE_MAX, false)), "a+?")
}

///|
test "escape" {
  // non-special punctuation is not quoted.
  assert_eq(escape("@foo"), "@foo")

  // Check typical usage.
  assert_eq(escape("fo*o"), "fo\\*o")

  // Check that multibyte characters are handled correctly.
  assert_eq(escape("fø*ø"), "fø\\*ø")
}

///|
test "trailing_positive_lookahead_wrap_capture_group_fixup" {
  let s = "a+(?=c)"
  let regex = Regex::new(s)
  // trailing positive lookahead for an otherwise easy pattern should avoid going through the VM
  assert_true(regex.inner is Wrap(explicit_capture_group_0=true, ..))
  assert_eq(s, regex.as_str())
}

///|
test "easy_regex" {
  let s = "(a+)b"
  let regex = Regex::new(s)
  // easy pattern should avoid going through the VM, and capture group 0 should be implicit
  assert_true(regex.inner is Wrap(explicit_capture_group_0=false, ..))
  assert_eq(s, regex.as_str())
}

///|
test "hard_regex" {
  let s = "(a+)(?>c)"
  let regex = Regex::new(s)
  // hard regex should be compiled into a VM
  assert_true(regex.inner is Fancy(_))
  assert_eq(s, regex.as_str())
}
