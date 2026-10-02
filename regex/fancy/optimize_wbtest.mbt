// Port of the unit tests of `fancy-regex` 0.16.2 `src/optimize.rs`.

///|
fn expr_to_str(e : Expr) -> String {
  let s = StringBuilder()
  e.to_str(s, 0)
  s.to_string()
}

///|
test "trailing_positive_lookahead_optimized" {
  let tree = Expr::parse_tree("a(?=b)")
  let requires_capture_group_fixup = optimize(tree)
  assert_eq(requires_capture_group_fixup, true)
  assert_eq(expr_to_str(tree.expr), "(a)b")
}

///|
test "standalone_positive_lookahead_optimized" {
  let tree = Expr::parse_tree("(?=b)")
  let requires_capture_group_fixup = optimize(tree)
  assert_eq(requires_capture_group_fixup, true)
  assert_eq(expr_to_str(tree.expr), "()b")
}

///|
test "trailing_positive_lookahead_with_alternative_optimized" {
  let tree = Expr::parse_tree("a(?=b|c)")
  let requires_capture_group_fixup = optimize(tree)
  assert_eq(requires_capture_group_fixup, true)
  assert_eq(expr_to_str(tree.expr), "(a)(?:b|c)")
}

///|
test "trailing_positive_lookahead_moved_even_if_not_easy" {
  let tree = Expr::parse_tree("(a)\\1(?=c)")
  let requires_capture_group_fixup = optimize(tree)
  assert_eq(requires_capture_group_fixup, true)
  assert_eq(
    tree.expr,
    Concat([
      Group(Concat([Group(make_literal("a")), Backref(group=1, casei=false)])),
      make_literal("c"),
    ]),
  )
}

///|
/// Optimize a copy of the parse tree of `re`; returns (fixup, original
/// expr, optimized expr).
fn optimize_copy(re : String) -> (Bool, Expr, Expr) raise FancyError {
  let tree = Expr::parse_tree(re)
  let original = tree.expr
  let optimized_tree = Expr::parse_tree(re)
  let requires_capture_group_fixup = optimize(optimized_tree)
  (requires_capture_group_fixup, original, optimized_tree.expr)
}

///|
test "trailing_positive_lookahead_left_alone_when_self_recursive" {
  let (fixup, original, optimized) = optimize_copy("ab?\\g<0>?(?=a|$)")
  assert_eq(fixup, false)
  assert_eq(optimized, original)
}

///|
test "trailing_negative_lookahead_left_alone" {
  let (fixup, original, optimized) = optimize_copy("a(?!b)")
  assert_eq(fixup, false)
  assert_eq(optimized, original)
}

///|
test "trailing_positive_lookbehind_left_alone" {
  let (fixup, original, optimized) = optimize_copy("(?<=b)")
  assert_eq(fixup, false)
  assert_eq(optimized, original)
}

///|
test "non_trailing_positive_lookahead_left_alone" {
  let (fixup, original, optimized) = optimize_copy("a(?=(b))\\1")
  assert_eq(fixup, false)
  assert_eq(optimized, original)
  let (fixup, original, optimized) = optimize_copy("(?=(b))\\1")
  assert_eq(fixup, false)
  assert_eq(optimized, original)
}
