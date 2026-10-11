///|
/// Port of upstream `test_expr_placeholder`.
test "expr placeholder" {
  let node = @ast.Expr::placeholder().to_untyped()
  assert_true((@ast.cast(node) : @ast.Expr?) is Some(_))
}

///|
/// The first node of the given kind in a tree (pre-order).
fn find_kind(
  node : @syntax.SyntaxNode,
  kind : @syntax.SyntaxKind,
) -> @syntax.SyntaxNode? {
  if node.kind() == kind {
    return Some(node)
  }
  for child in node.children() {
    if find_kind(child, kind) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
/// Parse `code` in code mode and cast the first node of `kind`.
fn[T : @ast.AstNode] first(code : String, kind : @syntax.SyntaxKind) -> T raise {
  let root = @syntax.parse_code(code)
  guard find_kind(root, kind) is Some(node) else {
    fail("no \{kind} in \{code}: \{root.debug_tree()}")
  }
  guard @ast.cast(node) is Some(v) else { fail("cast failed") }
  v
}

///|
/// Parse `text` in markup mode and return the first node of `kind`.
fn markup(text : String, kind : @syntax.SyntaxKind) -> @syntax.SyntaxNode raise {
  let root = @syntax.parse(text)
  guard find_kind(root, kind) is Some(node) else {
    fail("no \{kind} in \{text}: \{root.debug_tree()}")
  }
  node
}

///|
/// Float literals, with the bits Rust's `str::parse::<f64>()` produces
/// (computed with rustc 1.97.1).
test "float literals match Rust" {
  let cases : Array[(String, UInt64)] = [
    ("1e400", 0x7ff0000000000000UL),
    ("1e-400", 0x0000000000000000UL),
    ("1.7976931348623157e308", 0x7fefffffffffffffUL),
    ("1.7976931348623158e308", 0x7fefffffffffffffUL),
    ("1.7976931348623159e308", 0x7ff0000000000000UL),
    ("2.4703282292062327e-324", 0x0000000000000000UL),
    ("2.4703282292062328e-324", 0x0000000000000001UL),
    ("4.9e-324", 0x0000000000000001UL),
    ("9007199254740993.0", 0x4340000000000000UL),
    ("9007199254740993e0", 0x4340000000000000UL),
    ("0.1", 0x3fb999999999999aUL),
    (".5", 0x3fe0000000000000UL),
    ("1.", 0x3ff0000000000000UL),
    ("1e5", 0x40f86a0000000000UL),
    ("1E5", 0x40f86a0000000000UL),
    ("1e+5", 0x40f86a0000000000UL),
    ("1e-5", 0x3ee4f8b588e368f1UL),
    (
      "3.14159265358979323846264338327950288419716939937510582097494459", 0x400921fb54442d18UL,
    ),
    ("2.2250738585072011e-308", 0x000fffffffffffffUL),
    ("2.2250738585072014e-308", 0x0010000000000000UL),
    (
      "0.000000000000000000000000000000000000000000001e-280", 0x0000000000000000UL,
    ),
    ("1e22", 0x4480f0cf064dd592UL),
    ("1e23", 0x44b52d02c7e14af6UL),
    ("8.98846567431158e307", 0x7fe0000000000000UL),
    ("123456789012345678901234567890.5", 0x45f8ee90ff6c373eUL),
    ("0.30000000000000004", 0x3fd3333333333334UL),
    (
      "1.00000000000000011102230246251565404236316680908203125", 0x3ff0000000000000UL,
    ),
    (
      "1.00000000000000011102230246251565404236316680908203124", 0x3ff0000000000000UL,
    ),
    (
      "1.00000000000000011102230246251565404236316680908203126", 0x3ff0000000000001UL,
    ),
    ("7.2057594037927933e16", 0x4370000000000000UL),
    ("1e0400", 0x7ff0000000000000UL),
    ("1e-0", 0x3ff0000000000000UL),
    ("00.00e5", 0x0000000000000000UL),
  ]
  for case in cases {
    let (text, bits) = case
    let float : @ast.FloatLit = first(text, Float)
    assert_eq(float.to_untyped().leaf_text(), text)
    assert_eq(float.get().reinterpret_as_uint64(), bits)
    // The same value as the numeric part of a length (`1.pt` would be a
    // field access).
    if !text.has_suffix(".") {
      let numeric : @ast.Numeric = first(text + "pt", Numeric)
      let (value, unit) = numeric.get()
      assert_eq(value.reinterpret_as_uint64(), bits)
      assert_true(unit is Pt)
    }
  }
}

///|
test "numeric units" {
  let units : Array[(String, @ast.NumericUnit)] = [
    ("12pt", Pt),
    ("1mm", Mm),
    ("2.5cm", Cm),
    ("1in", In),
    ("90deg", Deg),
    ("1rad", Rad),
    ("2em", Em),
    ("1fr", Fr),
    ("50%", Percent),
  ]
  for case in units {
    let (text, unit) = case
    let numeric : @ast.Numeric = first(text, Numeric)
    let (_, u) = numeric.get()
    assert_eq(u, unit)
  }
  let numeric : @ast.Numeric = first("1e2em", Numeric)
  assert_eq(numeric.get().0, 100.0)
}

///|
test "int literals" {
  let show = (text : String) => {
    let int : @ast.IntLit = first(text, Int)
    match int.get() {
      Ok(v) => "Ok(\{v})"
      Err(PosOverflow(base~, max_plus_one~)) =>
        "PosOverflow(\{base.map(b => b.name()).unwrap_or("None")}, \{max_plus_one})"
      Err(InvalidDigit(base, digits)) =>
        "InvalidDigit(\{base.name()}, \{digits})"
    }
  }
  inspect(show("120"), content="Ok(120)")
  inspect(show("9223372036854775807"), content="Ok(9223372036854775807)")
  inspect(show("9223372036854775808"), content="PosOverflow(None, true)")
  inspect(show("9223372036854775809"), content="PosOverflow(None, false)")
  inspect(
    show("99999999999999999999999999"),
    content="PosOverflow(None, false)",
  )
  inspect(show("0xff"), content="Ok(255)")
  inspect(show("0o777"), content="Ok(511)")
  inspect(show("0b101"), content="Ok(5)")
  inspect(show("0x7FFFFFFFFFFFFFFF"), content="Ok(9223372036854775807)")
  inspect(show("0x8000000000000000"), content="PosOverflow(hexadecimal, true)")
  inspect(
    show("0xFFFFFFFFFFFFFFFFF"),
    content="PosOverflow(hexadecimal, false)",
  )
  inspect(
    show("0xFFFFFFFFFFFFFFFFz"),
    content="PosOverflow(hexadecimal, false)",
  )
  inspect(show("0x12z"), content="InvalidDigit(hexadecimal, 12z)")
  inspect(show("0b102"), content="InvalidDigit(binary, 102)")
  inspect(show("0o78"), content="InvalidDigit(octal, 78)")
}

///|
test "strings and escapes" {
  let str : @ast.Str = first(
    "\"a\\n\\t\\\"\\\\\\u{1F600}\\u{D800}\\u{zz}\\q\"",
    Str,
  )
  inspect(
    str.get(),
    content=(
      #|a
      #|	"\😀\u{D800}\u{zz}\q
    ),
  )
  let e : @ast.Escape = @ast.cast(markup("\\u{1F5FA}", Escape)).unwrap()
  assert_eq(e.get(), '\u{1F5FA}')
  let e : @ast.Escape = @ast.cast(markup("\\#", Escape)).unwrap()
  assert_eq(e.get(), '#')
  // Invalid escapes are lexer errors, but the AST must cope with them.
  for text in ["\\u{FFFFFFFFF}", "\\u{D800}", "\\u{}", "\\", ""] {
    let e : @ast.Escape = @ast.cast(@syntax.SyntaxNode::leaf(Escape, text)).unwrap()
    assert_eq(e.get(), '\u{0}')
  }
  let s : @ast.Shorthand = @ast.cast(markup("a -- b", Shorthand)).unwrap()
  assert_eq(s.get(), '\u{2013}')
  let s : @ast.Shorthand = @ast.cast(markup("a~b", Shorthand)).unwrap()
  assert_eq(s.get(), '\u{A0}')
  let s : @ast.MathShorthand = @ast.cast(markup("$a <==> b$", MathShorthand)).unwrap()
  assert_eq(s.get(), '⟺')
}

///|
test "markup accessors" {
  let h : @ast.Heading = @ast.cast(markup("=== Hi", Heading)).unwrap()
  assert_eq(h.depth(), 3)
  let item : @ast.EnumItem = @ast.cast(markup("23. Hi", EnumItem)).unwrap()
  assert_eq(item.number(), Some(23UL))
  // Numbers beyond `u64` (the parser does not produce these).
  let marker = (text : String) => {
    let node = @syntax.SyntaxNode::inner(EnumItem, [
      @syntax.SyntaxNode::leaf(EnumMarker, text),
    ])
    (@ast.cast(node) : @ast.EnumItem?).unwrap().number()
  }
  assert_eq(marker("18446744073709551615."), Some(18446744073709551615UL))
  assert_eq(marker("18446744073709551616."), None)
  assert_eq(marker("+3."), Some(3UL))
  let item : @ast.EnumItem = @ast.cast(markup("+ Hi", EnumItem)).unwrap()
  assert_eq(item.number(), None)
  let label : @ast.Label = @ast.cast(markup("<intro>", Label)).unwrap()
  assert_eq(label.get(), "intro")
  let r : @ast.Ref = @ast.cast(markup("@sec[see]", Ref)).unwrap()
  assert_eq(r.target(), "sec")
  assert_true(r.supplement() is Some(_))
  let raw : @ast.Raw = @ast.cast(markup("```rs\nfn main() {}\n```", Raw)).unwrap()
  assert_true(raw.block())
  assert_eq(raw.lang().map(l => l.get()), Some("rs"))
  assert_eq(raw.lines().map(l => l.get()).to_array(), ["fn main() {}"])
  let raw : @ast.Raw = @ast.cast(markup("`rs code`", Raw)).unwrap()
  assert_true(!raw.block())
  assert_true(raw.lang() is None)
  let binary : @ast.Binary = @ast.cast(markup("#(a not in b)", Binary)).unwrap()
  assert_true(binary.op() is NotIn)
  let comment : @ast.BlockComment = @ast.cast(markup("/* hi */", BlockComment)).unwrap()
  assert_eq(comment.text(), " hi ")
}

///|
test "bare import names" {
  let bare = (code : String) => {
    let import_ : @ast.ModuleImport = first(code, ModuleImport)
    match import_.bare_name() {
      Ok(name) => "Ok(\{name})"
      Err(Dynamic) => "Err(Dynamic)"
      Err(PathInvalid) => "Err(PathInvalid)"
      Err(PackageInvalid) => "Err(PackageInvalid)"
    }
  }
  inspect(bare("import \"a/b/chap1.typ\""), content="Ok(chap1)")
  inspect(bare("import \"a/b/chap1.tar.gz\""), content="Err(PathInvalid)")
  inspect(bare("import \"x/.hidden\""), content="Err(PathInvalid)")
  inspect(bare("import \"module/\""), content="Ok(module)")
  inspect(bare("import \"module/.\""), content="Ok(module)")
  inspect(bare("import \"a/..\""), content="Err(PathInvalid)")
  inspect(bare("import \"\""), content="Err(PathInvalid)")
  inspect(bare("import \"@preview/example:0.1.0\""), content="Ok(example)")
  inspect(bare("import \"@preview/example\""), content="Err(PackageInvalid)")
  inspect(bare("import foo"), content="Ok(foo)")
  inspect(bare("import a.b"), content="Ok(b)")
  inspect(bare("import f()"), content="Err(Dynamic)")
}

///|
/// The AST must never panic, not even on placeholders.
test "accessors on placeholders" {
  let expr = @ast.Expr::placeholder()
  assert_true(expr is None(_))
  assert_true((!expr.is_literal()) is false)
  assert_eq(@ast.LineComment::placeholder().text(), "")
  assert_eq(@ast.BlockComment::placeholder().text(), "")
  assert_eq(@ast.Markup::placeholder().exprs().count(), 0)
  assert_eq(@ast.Text::placeholder().get(), "")
  assert_true(!@ast.Space::placeholder().had_newline())
  assert_eq(@ast.Escape::placeholder().get(), '\u{0}')
  assert_eq(@ast.Shorthand::placeholder().get(), '\u{0}')
  assert_true(!@ast.SmartQuote::placeholder().double())
  ignore(@ast.Strong::placeholder().body())
  ignore(@ast.Emph::placeholder().body())
  let raw = @ast.Raw::placeholder()
  assert_eq(raw.lines().count(), 0)
  assert_true(raw.lang() is None)
  assert_true(!raw.block())
  assert_eq(@ast.RawLang::placeholder().get(), "")
  assert_eq(@ast.Link::placeholder().get(), "")
  assert_eq(@ast.Label::placeholder().get(), "")
  assert_eq(@ast.Ref::placeholder().target(), "")
  assert_true(@ast.Ref::placeholder().supplement() is None)
  assert_eq(@ast.Heading::placeholder().depth(), 1)
  ignore(@ast.Heading::placeholder().body())
  ignore(@ast.ListItem::placeholder().body())
  assert_eq(@ast.EnumItem::placeholder().number(), None)
  ignore(@ast.EnumItem::placeholder().body())
  ignore(@ast.TermItem::placeholder().term())
  ignore(@ast.TermItem::placeholder().description())
  assert_true(!@ast.Equation::placeholder().block())
  ignore(@ast.Equation::placeholder().body())
  assert_eq(@ast.Math::placeholder().exprs().count(), 0)
  assert_true(!@ast.Math::placeholder().was_deparenthesized())
  assert_true(@ast.MathText::placeholder().get() is Grapheme(""))
  assert_eq(@ast.MathIdent::placeholder().as_str(), "")
  ignore(@ast.MathFieldAccess::placeholder().target())
  ignore(@ast.MathFieldAccess::placeholder().field())
  assert_eq(@ast.MathShorthand::placeholder().get(), '\u{0}')
  ignore(@ast.MathCall::placeholder().callee())
  ignore(@ast.MathCall::placeholder().args())
  assert_eq(@ast.MathArgs::placeholder().arg_items().count(), 0)
  assert_eq(@ast.MathArgs::placeholder().content_items().count(), 0)
  let delimited = @ast.MathDelimited::placeholder()
  ignore((delimited.open(), delimited.body(), delimited.close()))
  let attach = @ast.MathAttach::placeholder()
  ignore(attach.base())
  assert_true(attach.bottom() is None && attach.top() is None)
  assert_true(attach.primes() is None)
  assert_eq(@ast.MathPrimes::placeholder().count(), 0)
  ignore(
    (@ast.MathFrac::placeholder().num(), @ast.MathFrac::placeholder().denom()),
  )
  assert_true(@ast.MathRoot::placeholder().index() is None)
  ignore(@ast.MathRoot::placeholder().radicand())
  assert_eq(@ast.Ident::placeholder().get(), "")
  assert_true(!@ast.BoolLit::placeholder().get())
  assert_true(
    @ast.IntLit::placeholder().get() is Err(PosOverflow(base=None, ..)),
  )
  assert_eq(@ast.FloatLit::placeholder().get(), 0.0)
  assert_eq(@ast.Numeric::placeholder().get().0, 0.0)
  assert_eq(@ast.Str::placeholder().get(), "")
  ignore(@ast.CodeBlock::placeholder().body())
  assert_eq(@ast.Code::placeholder().exprs().count(), 0)
  ignore(@ast.ContentBlock::placeholder().body())
  ignore(@ast.Parenthesized::placeholder().expr())
  ignore(@ast.Parenthesized::placeholder().pattern())
  assert_eq(@ast.ArrayLit::placeholder().items().count(), 0)
  assert_eq(@ast.Dict::placeholder().items().count(), 0)
  ignore(@ast.Named::placeholder().name())
  ignore(@ast.Named::placeholder().expr())
  ignore(@ast.Named::placeholder().pattern())
  ignore(@ast.Keyed::placeholder().key())
  ignore(@ast.Keyed::placeholder().expr())
  ignore(@ast.Spread::placeholder().expr())
  assert_true(@ast.Spread::placeholder().sink_ident() is None)
  assert_true(@ast.Spread::placeholder().sink_expr() is None)
  assert_true(@ast.Unary::placeholder().op() is Pos)
  ignore(@ast.Unary::placeholder().expr())
  assert_true(@ast.Binary::placeholder().op() is Add)
  ignore((@ast.Binary::placeholder().lhs(), @ast.Binary::placeholder().rhs()))
  ignore(@ast.FieldAccess::placeholder().target())
  ignore(@ast.FieldAccess::placeholder().field())
  ignore(@ast.FuncCall::placeholder().callee())
  ignore(@ast.FuncCall::placeholder().args())
  assert_eq(@ast.Args::placeholder().items().count(), 0)
  assert_true(!@ast.Args::placeholder().trailing_comma())
  let closure = @ast.Closure::placeholder()
  assert_true(closure.name() is None)
  ignore((closure.params(), closure.body()))
  assert_eq(@ast.Params::placeholder().children().count(), 0)
  assert_eq(@ast.Pattern::placeholder().bindings().length(), 0)
  assert_eq(@ast.Destructuring::placeholder().items().count(), 0)
  assert_eq(@ast.Destructuring::placeholder().bindings().length(), 0)
  let binding = @ast.LetBinding::placeholder()
  assert_true(binding.kind() is Normal(Normal(None(_))))
  assert_true(binding.init() is None)
  ignore(@ast.DestructAssignment::placeholder().pattern())
  ignore(@ast.DestructAssignment::placeholder().value())
  let set = @ast.SetRule::placeholder()
  ignore((set.target(), set.args()))
  assert_true(set.condition() is None)
  assert_true(@ast.ShowRule::placeholder().selector() is None)
  ignore(@ast.ShowRule::placeholder().transform())
  ignore(@ast.Contextual::placeholder().body())
  let cond = @ast.Conditional::placeholder()
  ignore((cond.condition(), cond.if_body()))
  assert_true(cond.else_body() is None)
  ignore(@ast.WhileLoop::placeholder().condition())
  ignore(@ast.WhileLoop::placeholder().body())
  let for_loop = @ast.ForLoop::placeholder()
  ignore((for_loop.pattern(), for_loop.iterable(), for_loop.body()))
  let import_ = @ast.ModuleImport::placeholder()
  ignore(import_.source())
  assert_true(import_.imports() is None)
  assert_true(import_.bare_name() is Err(Dynamic))
  assert_true(import_.new_name() is None)
  assert_eq(@ast.ImportItems::placeholder().iter().count(), 0)
  assert_eq(@ast.ImportItemPath::placeholder().iter().count(), 0)
  ignore(@ast.ImportItemPath::placeholder().name())
  let renamed = @ast.RenamedImportItem::placeholder()
  ignore((renamed.path(), renamed.original_name(), renamed.new_name()))
  ignore(@ast.ModuleInclude::placeholder().source())
  assert_true(@ast.FuncReturn::placeholder().body() is None)
  // Spans of placeholders are detached.
  assert_true(@ast.Raw::placeholder().span().is_detached())
}
