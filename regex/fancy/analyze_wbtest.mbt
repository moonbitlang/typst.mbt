// Port of the unit tests of `fancy-regex` 0.16.2 `src/analyze.rs`.

///|
/// The error of analyzing the parsed pattern, if any.
fn analyze_err(re : String, explicit_capture_group_0 : Bool) -> FancyError? {
  let tree = Expr::parse_tree(re) catch { e => abort(e.to_string()) }
  try analyze(tree, explicit_capture_group_0) catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
fn analyze_ok(re : String, explicit_capture_group_0 : Bool) -> Bool {
  analyze_err(re, explicit_capture_group_0) is None
}

///|
test "invalid_backref_zero" {
  assert_eq(analyze_err(".\\0", false), Some(CompileError(InvalidBackref(0))))
  assert_eq(analyze_err(".\\0", true), Some(CompileError(InvalidBackref(0))))
  assert_eq(analyze_err("(.)\\0", false), Some(CompileError(InvalidBackref(0))))
  assert_eq(analyze_err("(.)\\0", true), Some(CompileError(InvalidBackref(0))))
  assert_eq(
    analyze_err("(.)\\0\\1", false),
    Some(CompileError(InvalidBackref(0))),
  )
}

///|
test "invalid_backref_no_captures" {
  assert_eq(analyze_err("aa\\1", false), Some(CompileError(InvalidBackref(1))))
  assert_eq(
    analyze_err("aaaa\\2", false),
    Some(CompileError(InvalidBackref(2))),
  )
}

///|
test "invalid_backref_with_captures" {
  assert_eq(
    analyze_err("a(a)\\2", false),
    Some(CompileError(InvalidBackref(2))),
  )
  assert_eq(
    analyze_err("a(a)\\2\\1", false),
    Some(CompileError(InvalidBackref(2))),
  )
}

///|
test "invalid_backref_with_captures_explict_capture_group_zero" {
  assert_eq(
    analyze_err("(a(b)\\2)c", true),
    Some(CompileError(InvalidBackref(2))),
  )
  assert_eq(
    analyze_err("(a(b)\\1\\2)c", true),
    Some(CompileError(InvalidBackref(2))),
  )
  assert_eq(analyze_err("(a\\1)b", true), Some(CompileError(InvalidBackref(1))))
  assert_eq(
    analyze_err("(a(b))\\2", true),
    Some(CompileError(InvalidBackref(2))),
  )
}

///|
test "allow_analysis_of_self_backref" {
  // even if it will never match, see issue 103
  assert_true(analyze_ok("(.\\1)", false))
  assert_true(analyze_ok("((.\\1))", true))
  assert_true(analyze_ok("(([ab]+)\\1b)", false))
  // in the following scenario it can match
  assert_true(analyze_ok("(([ab]+?)(?(1)\\1| )c)+", false))
}

///|
test "allow_backref_even_when_capture_group_occurs_after_backref" {
  assert_true(analyze_ok("\\1(.)", false))
  assert_true(analyze_ok("(\\1(.))", true))
}

///|
test "valid_backref_occurs_after_capture_group" {
  assert_true(analyze_ok("(.)\\1", false))
  assert_true(analyze_ok("((.)\\1)", true))
  assert_true(analyze_ok("((.)\\2\\2)\\1", false))
  assert_true(analyze_ok("(.)\\1(.)\\2", false))
  assert_true(analyze_ok("(.)foo(.)\\2", false))
  assert_true(analyze_ok("(.)(foo)(.)\\3\\2\\1", false))
  assert_true(analyze_ok("(.)(foo)(.)\\3\\1", false))
  assert_true(analyze_ok("(.)(foo)(.)\\2\\1", false))
}

///|
test "feature_not_yet_supported" {
  assert_true(
    analyze_err("(a)\\g<1>", false)
    is Some(CompileError(FeatureNotYetSupported(_))),
  )
  assert_true(
    analyze_err("(a)\\k<1-0>", false)
    is Some(CompileError(FeatureNotYetSupported(_))),
  )
}

///|
test "subroutine_call_undefined" {
  assert_true(
    analyze_err("\\g<wrong_name>(?<different_name>a)", false)
    is Some(CompileError(SubroutineCallTargetNotFound(_, _))),
  )
}

///|
test "is_literal" {
  let tree = Expr::parse_tree("abc")
  let info = analyze(tree, false)
  assert_eq(info.is_literal(), true)
}

///|
test "is_literal_with_repeat" {
  let tree = Expr::parse_tree("abc*")
  let info = analyze(tree, false)
  assert_eq(info.is_literal(), false)
}

///|
test "anchored_for_starttext_assertions" {
  let tree = Expr::parse_tree("^(\\w+)\\1")
  assert_eq(can_compile_as_anchored(tree.expr), true)
  let tree = Expr::parse_tree("^")
  assert_eq(can_compile_as_anchored(tree.expr), true)
}

///|
test "backref_inherits_group_size_info" {
  // Test that backrefs properly inherit min_size and const_size from referenced groups
  let tree = Expr::parse_tree("(abc)\\1")
  let info = analyze(tree, false)
  // The concatenation should have min_size = 3 + 3 = 6 (group + backref)
  assert_eq(info.min_size, 6)
  assert_true(info.const_size)

  // Test with a variable-length group
  let tree = Expr::parse_tree("(a+)\\1")
  let info = analyze(tree, false)
  // The group has min_size = 1, but const_size = false due to the +
  // So the total should be min_size = 2, const_size = false
  assert_eq(info.min_size, 2)
  assert_true(!info.const_size)

  // Test with optional group
  let tree = Expr::parse_tree("(a?)\\1")
  let info = analyze(tree, false)
  // Both group and backref can be empty, so min_size = 0
  assert_eq(info.min_size, 0)
  assert_true(!info.const_size)
}

///|
test "backref_forward_reference" {
  // Test forward references (backref before group definition)
  // These should use conservative defaults but still work
  let tree = Expr::parse_tree("\\1(abc)")
  let info = analyze(tree, false)
  // Forward ref gets min_size=0, group gets min_size=3, total=3
  assert_eq(info.min_size, 3)
  // Forward ref sets const_size=false, so overall is false
  assert_true(!info.const_size)
}

///|
test "backref_in_lookbehind" {
  assert_true(analyze_ok("(hello)(?<=\\b\\1)", false))
  assert_true(analyze_ok("(..)(?<=\\1\\1)", false))
  assert_true(analyze_ok("(abc)(?<=\\1)def", false))
}

///|
test "not_anchored_for_startline_assertions" {
  let tree = Expr::parse_tree("(?m)^(\\w+)\\1")
  assert_eq(can_compile_as_anchored(tree.expr), false)
}
