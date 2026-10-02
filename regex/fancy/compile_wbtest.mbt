// Port of the unit tests of `fancy-regex` 0.16.2 `src/compile.rs`.

///|
test "jumps_for_alternation" {
  let tree : ExprTree = {
    expr: Alt([
      Literal(val="a", casei=false),
      Literal(val="b", casei=false),
      Literal(val="c", casei=false),
    ]),
    backrefs: BitSet::new(),
    named_groups: {},
    contains_subroutines: false,
    self_recursive: false,
  }
  let info = analyze(tree, false)
  let c = Compiler::new(0)
  // Force "hard" so that compiler doesn't just delegate
  c.visit(info, true)
  c.b.add(End)
  let prog = c.b.prog
  assert_eq(prog.length(), 8)
  assert_true(prog[0] is Split(1, 3))
  assert_true(prog[1] is Lit("a"))
  assert_true(prog[2] is Jmp(7))
  assert_true(prog[3] is Split(4, 6))
  assert_true(prog[4] is Lit("b"))
  assert_true(prog[5] is Jmp(7))
  assert_true(prog[6] is Lit("c"))
  assert_true(prog[7] is End)
}

///|
fn compile_prog(re : String) -> Array[Insn] raise FancyError {
  let tree = Expr::parse_tree(re)
  let info = analyze(tree, true)
  let prog = compile(info, true)
  prog.body
}

///|
fn assert_delegate(insn : Insn, re : String) -> Unit raise {
  match insn {
    Delegate(d) => assert_eq(d.pattern, re)
    _ => fail("Expected Insn::Delegate but was \{insn}")
  }
}

///|
test "look_around_pattern_can_be_delegated" {
  let prog = compile_prog("(?=ab*)c")
  assert_eq(prog.length(), 5)
  assert_true(prog[0] is Save(0))
  assert_delegate(prog[1], "ab*")
  assert_true(prog[2] is Restore(0))
  assert_true(prog[3] is Lit("c"))
  assert_true(prog[4] is End)
}

///|
test "easy_concat_can_delegate_end" {
  let prog = compile_prog("(?!x)(?:a|ab)x*")
  assert_eq(prog.length(), 5)
  assert_true(prog[0] is Split(1, 3))
  assert_true(prog[1] is Lit("x"))
  assert_true(prog[2] is FailNegativeLookAround)
  assert_delegate(prog[3], "(?:a|ab)x*")
  assert_true(prog[4] is End)
}

///|
test "hard_concat_can_delegate_const_size_end" {
  let prog = compile_prog("(?:(?!x)(?:a|b)c)x*")
  assert_eq(prog.length(), 6)
  assert_true(prog[0] is Split(1, 3))
  assert_true(prog[1] is Lit("x"))
  assert_true(prog[2] is FailNegativeLookAround)
  assert_delegate(prog[3], "(?:a|b)c")
  assert_delegate(prog[4], "x*")
  assert_true(prog[5] is End)
}

///|
test "hard_concat_can_not_delegate_variable_end" {
  let prog = compile_prog("(?:(?!x)(?:a|ab))x*")
  assert_eq(prog.length(), 9)
  assert_true(prog[0] is Split(1, 3))
  assert_true(prog[1] is Lit("x"))
  assert_true(prog[2] is FailNegativeLookAround)
  assert_true(prog[3] is Split(4, 6))
  assert_true(prog[4] is Lit("a"))
  assert_true(prog[5] is Jmp(7))
  assert_true(prog[6] is Lit("ab"))
  assert_delegate(prog[7], "x*")
  assert_true(prog[8] is End)
}

///|
test "conditional_expression_can_be_compiled" {
  let prog = compile_prog("(?(ab)c|d)")
  assert_eq(prog.length(), 8)
  assert_true(prog[0] is BeginAtomic)
  assert_true(prog[1] is Split(2, 6))
  assert_true(prog[2] is Lit("ab"))
  assert_true(prog[3] is EndAtomic)
  assert_true(prog[4] is Lit("c"))
  assert_true(prog[5] is Jmp(7))
  assert_true(prog[6] is Lit("d"))
  assert_true(prog[7] is End)
}

///|
test "lazy_any_can_be_compiled_explicit_capture_group_zero" {
  let prog = compile_prog("\\O*?((?!a))")
  assert_eq(prog.length(), 9)
  assert_true(prog[0] is Split(3, 1))
  assert_true(prog[1] is Any)
  assert_true(prog[2] is Jmp(0))
  assert_true(prog[3] is Save(0))
  assert_true(prog[4] is Split(5, 7))
  assert_true(prog[5] is Lit("a"))
  assert_true(prog[6] is FailNegativeLookAround)
  assert_true(prog[7] is Save(1))
  assert_true(prog[8] is End)
}
