// Port of upstream `typst-syntax/src/parser.rs`.

///|
/// Picked by gut feeling.
let max_depth : Int = 256

///|
/// Parses a source file as top-level markup.
pub fn parse(text : String) -> SyntaxNode {
  let p = Parser::new(text, 0, Markup)
  markup_exprs(p, true, SyntaxSet::of([End]))
  p.finish_into(Markup)
}

///|
/// Parses top-level code.
pub fn parse_code(text : String) -> SyntaxNode {
  let p = Parser::new(text, 0, Code)
  code_exprs(p, SyntaxSet::of([End]))
  p.finish_into(Code)
}

///|
/// Parses top-level math.
pub fn parse_math(text : String) -> SyntaxNode {
  let p = Parser::new(text, 0, Math)
  math_exprs(p, SyntaxSet::of([End])) |> ignore
  p.finish_into(Math)
}

///|
/// Parses markup expressions until a stop condition is met.
fn markup(
  p : Parser,
  at_start : Bool,
  wrap_trivia : Bool,
  stop_set : SyntaxSet,
) -> Unit {
  let m = if wrap_trivia { p.before_trivia() } else { p.marker() }
  markup_exprs(p, at_start, stop_set)
  if wrap_trivia {
    p.flush_trivia()
  }
  p.wrap(m, Markup)
}

///|
/// Parses a sequence of markup expressions.
fn markup_exprs(p : Parser, at_start : Bool, stop_set : SyntaxSet) -> Unit {
  if !p.check_depth_until(stop_set) {
    return
  }
  let mut at_start = at_start || p.had_newline()
  let nesting = Ref::new(0)
  // Keep going if we're at a nested right-bracket regardless of the stop set.
  while !p.at_set(stop_set) || (nesting.val > 0 && p.at(RightBracket)) {
    markup_expr(p, at_start, nesting)
    at_start = p.had_newline()
  }
}

///|
/// Reparses a subsection of markup incrementally.
fn reparse_markup(
  text : String,
  start : Int,
  end : Int,
  at_start : Ref[Bool],
  nesting : Ref[Int],
  top_level : Bool,
) -> Array[SyntaxNode]? {
  let p = Parser::new(text, start, Markup)
  at_start.val = at_start.val || p.had_newline()
  while !p.end() && p.current_start() < end {
    // If not top-level and at a new RightBracket, stop the reparse.
    if !top_level && nesting.val == 0 && p.at(RightBracket) {
      break
    }
    markup_expr(p, at_start.val, nesting)
    at_start.val = p.had_newline()
  }
  if p.balanced && p.current_start() == end {
    Some(p.nodes)
  } else {
    None
  }
}

///|
/// Parses a single markup expression.
fn markup_expr(p : Parser, at_start : Bool, nesting : Ref[Int]) -> Unit {
  p.with_depth(() => {
    match p.current() {
      LeftBracket => {
        nesting.val += 1
        p.convert_and_eat(Text)
      }
      RightBracket if nesting.val > 0 => {
        nesting.val -= 1
        p.convert_and_eat(Text)
      }
      RightBracket => {
        p.unexpected()
        p.hint("try using a backslash escape: \\]")
      }
      Shebang => p.eat()
      Text | Linebreak | Escape | Shorthand | SmartQuote | Link | Label =>
        p.eat()
      Raw => p.eat()
      Hash => embedded_code_expr(p)
      Star => strong(p)
      Underscore => emph(p)
      HeadingMarker if at_start => heading(p)
      ListMarker if at_start => list_item(p)
      EnumMarker if at_start => enum_item(p)
      TermMarker if at_start => term_item(p)
      RefMarker => reference(p)
      Dollar => equation(p)
      HeadingMarker | ListMarker | EnumMarker | TermMarker | Colon =>
        p.convert_and_eat(Text)
      _ => p.unexpected()
    }
  })
}

///|
/// Parses strong content: `*Strong*`.
fn strong(p : Parser) -> Unit {
  p.with_nl_mode(StopParBreak, () => {
    let m = p.marker()
    p.assert_at(Star)
    markup(p, false, true, SyntaxSet::of([Star, RightBracket, End]))
    let had_closing = p.expect_closing_delimiter(m, Star)
    p.wrap(m, Strong)
    if had_closing && p.nodes[m].len() == 2 {
      p.nodes[m].warn("no text within stars")
      p.nodes[m].hint(
        "using multiple consecutive stars (e.g. **) has no additional effect",
      )
    }
  })
}

///|
/// Parses emphasized content: `_Emphasized_`.
fn emph(p : Parser) -> Unit {
  p.with_nl_mode(StopParBreak, () => {
    let m = p.marker()
    p.assert_at(Underscore)
    markup(p, false, true, SyntaxSet::of([Underscore, RightBracket, End]))
    let had_closing = p.expect_closing_delimiter(m, Underscore)
    p.wrap(m, Emph)
    if had_closing && p.nodes[m].len() == 2 {
      p.nodes[m].warn("no text within underscores")
      p.nodes[m].hint(
        "using multiple consecutive underscores (e.g. __) has no additional effect",
      )
    }
  })
}

///|
/// Parses a section heading: `= Introduction`.
fn heading(p : Parser) -> Unit {
  p.with_nl_mode(Stop, () => {
    let m = p.marker()
    p.assert_at(HeadingMarker)
    markup(p, false, false, SyntaxSet::of([Label, RightBracket, End]))
    p.wrap(m, Heading)
  })
}

///|
/// Parses an item in a bullet list: `- ...`.
fn list_item(p : Parser) -> Unit {
  p.with_nl_mode(RequireColumn(p.current_column()), () => {
    let m = p.marker()
    p.assert_at(ListMarker)
    markup(p, true, false, SyntaxSet::of([RightBracket, End]))
    p.wrap(m, ListItem)
  })
}

///|
/// Parses an item in an enumeration (numbered list): `+ ...` or `1. ...`.
fn enum_item(p : Parser) -> Unit {
  p.with_nl_mode(RequireColumn(p.current_column()), () => {
    let m = p.marker()
    p.assert_at(EnumMarker)
    markup(p, true, false, SyntaxSet::of([RightBracket, End]))
    p.wrap(m, EnumItem)
  })
}

///|
/// Parses an item in a term list: `/ Term: Details`.
fn term_item(p : Parser) -> Unit {
  p.with_nl_mode(RequireColumn(p.current_column()), () => {
    let m = p.marker()
    p.with_nl_mode(Stop, () => {
      p.assert_at(TermMarker)
      markup(p, false, false, SyntaxSet::of([Colon, RightBracket, End]))
    })
    p.expect(Colon) |> ignore
    markup(p, true, false, SyntaxSet::of([RightBracket, End]))
    p.wrap(m, TermItem)
  })
}

///|
/// Parses a reference: `@target`, `@target[..]`.
fn reference(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(RefMarker)
  if p.directly_at(LeftBracket) {
    content_block(p)
  }
  p.wrap(m, Ref)
}

///|
/// Parses a mathematical equation: `$x$`, `$ x^2 $`.
fn equation(p : Parser) -> Unit {
  let m = p.marker()
  p.enter_modes(Math, Continue, () => {
    p.assert_at(Dollar)
    math(p, SyntaxSet::of([Dollar, End]))
    p.expect_closing_delimiter(m, Dollar) |> ignore
  })
  p.wrap(m, Equation)
}

///|
/// Parses the contents of a mathematical equation: `x^2 + 1`.
fn math(p : Parser, stop_set : SyntaxSet) -> Unit {
  let m = p.marker()
  math_exprs(p, stop_set) |> ignore
  p.wrap(m, Math)
}

///|
/// Parses a sequence of math expressions. Returns the number of expressions
/// parsed (including errors).
fn math_exprs(p : Parser, stop_set : SyntaxSet) -> Int {
  if !p.check_depth_until(stop_set) {
    return 1
  }
  let mut count = 0
  while !p.at_set(stop_set) {
    if p.at_set(math_expr_set) {
      math_expr(p)
    } else {
      p.unexpected()
    }
    count += 1
  }
  count
}

///|
/// Parses a single math expression.
fn math_expr(p : Parser) -> Unit {
  math_expr_prec(p, 0, SyntaxSet::new())
}

///|
let math_func_prec : Int = 2

///|
let math_root_prec : Int = 2

///|
/// Parses a math expression with at least the given precedence.
fn math_expr_prec(p : Parser, min_prec : Int, stop_set : SyntaxSet) -> Unit {
  p.with_depth(() => {
    let m = p.marker()
    let mut continuable = false
    match p.current() {
      Hash => embedded_code_expr(p)
      // The lexer manages creating full MathFieldAccess nodes if needed.
      MathIdent | MathFieldAccess => {
        continuable = true
        p.eat()
        // Parse a function call for an identifier or field access.
        if math_func_prec >= min_prec && p.directly_at(LeftParen) {
          math_args(p)
          p.wrap(m, MathCall)
          continuable = false
        }
      }
      LeftBrace | LeftParen => math_delimited(p)
      RightBrace if p.current_text() == "|]" => p.convert_and_eat(MathShorthand)
      Dot | Bang | Comma | Semicolon | RightBrace | RightParen =>
        p.convert_and_eat(MathText)
      MathText => {
        continuable = is_math_alphabetic(p.current_text())
        p.eat()
      }
      Linebreak | MathAlignPoint | MathShorthand => p.eat()
      MathPrimes | Escape | Str => {
        continuable = true
        p.eat()
      }
      Root => {
        p.eat()
        let m2 = p.marker()
        math_expr_prec(p, math_root_prec, SyntaxSet::new())
        math_unparen(p, m2)
        p.wrap(m, MathRoot)
      }
      _ => p.expected("expression")
    }

    // Maybe recognize an implicit function call.
    if continuable &&
      math_func_prec >= min_prec &&
      !p.had_trivia() &&
      p.at_set(SyntaxSet::of([LeftBrace, LeftParen])) {
      math_delimited(p)
      p.wrap(m, Math)
    }

    // Parse infix and postfix operators.
    while !p.at_set(stop_set) {
      let op_kind = p.current()
      let had_trivia = p.had_trivia()
      guard math_op(op_kind, had_trivia) is Some((wrapper, infix_assoc, prec)) &&
        prec >= min_prec else {
        break
      }
      // Prepare a chaining set for the attachment operators.
      let mut chain_set = if wrapper == MathAttach {
        SyntaxSet::of([Hat, Underscore]).remove(op_kind)
      } else {
        SyntaxSet::new()
      }

      // Eat the operator itself.
      if op_kind == Bang {
        p.convert_and_eat(MathText)
      } else {
        p.eat()
      }

      // Slash is the only operator that removes parens from its left operand.
      if wrapper == MathFrac {
        math_unparen(p, m)
      }

      // Parse the operator's right operand.
      if infix_assoc is Some(assoc) {
        let prec = match assoc {
          Left => prec + 1
          Right => prec
        }
        let m_rhs = p.marker()
        math_expr_prec(p, prec, chain_set)
        math_unparen(p, m_rhs)
      }

      // Avoid interrupting a chain when initially parsing a prime.
      if !(op_kind == MathPrimes && p.at_set(stop_set)) {
        // Parse chained attachment operators as a single attachment.
        while p.at_set(chain_set) {
          chain_set = chain_set.remove(p.current())
          p.eat()
          let m_chain_rhs = p.marker()
          math_expr_prec(p, prec, chain_set)
          math_unparen(p, m_chain_rhs)
        }
      }

      // Finish the operator by wrapping from its left operand.
      p.wrap(m, wrapper)
    }
  })
}

///|
/// Precedence and wrapper kinds for infix and postfix math operators.
fn math_op(kind : SyntaxKind, had_trivia : Bool) -> (SyntaxKind, Assoc?, Int)? {
  match kind {
    Slash => Some((MathFrac, Some(Left), 1))
    Underscore => Some((MathAttach, Some(Right), 2))
    Hat => Some((MathAttach, Some(Right), 2))
    MathPrimes if !had_trivia => Some((MathAttach, None, 2))
    Bang if !had_trivia => Some((Math, None, 3))
    _ => None
  }
}

///|
/// Whether text counts as alphabetic in math.
fn is_math_alphabetic(text : String) -> Bool {
  let chars = text.iter().collect()
  if chars.length() == 1 {
    let c = chars[0]
    @unicode.is_alphabetic(c) ||
    @unicode.default_math_class(c) is Some(Alphabetic)
  } else {
    chars.iter().all(@unicode.is_alphabetic)
  }
}

///|
/// Parse matched delimiters in math: `[x + y]`.
fn math_delimited(p : Parser) -> Unit {
  let m = p.marker()
  if p.current_text() == "[|" {
    p.convert_and_eat(MathShorthand)
  } else {
    p.convert_and_eat(MathText)
  }
  let m_body = p.marker()
  math_exprs(p, SyntaxSet::of([Dollar, End, RightBrace, RightParen])) |> ignore
  if p.at_set(SyntaxSet::of([RightBrace, RightParen])) {
    p.wrap(m_body, Math)
    if p.current_text() == "|]" {
      p.convert_and_eat(MathShorthand)
    } else {
      p.convert_and_eat(MathText)
    }
    p.wrap(m, MathDelimited)
  } else {
    // If we had no closing delimiter, just produce a math sequence.
    p.wrap(m, Math)
  }
}

///|
/// Remove one set of parentheses (if any) from a previously parsed expression
/// by converting to non-expression kinds.
fn math_unparen(p : Parser, m : Int) -> Unit {
  guard m < p.nodes.length() else { return }
  let node = p.nodes[m]
  if node.kind() != MathDelimited {
    return
  }
  let children = node.children_mut()
  if children.length() >= 2 {
    let first = children[0]
    let last = children[children.length() - 1]
    if first.leaf_text() == "(" && last.leaf_text() == ")" {
      first.convert_to_kind(LeftParen)
      last.convert_to_kind(RightParen)
      // Only convert if we did have regular parens.
      node.convert_to_kind(Math)
    }
  }
}

///|
/// Parse an argument list in math: `(a, b; c, d; size: #50%)`.
fn math_args(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(LeftParen)
  let seen : @hashset.HashSet[String] = @hashset.HashSet([])
  while !p.at_set(SyntaxSet::of([End, Dollar, RightParen])) {
    math_arg(p, seen)
    match p.current() {
      End | Dollar | RightParen => ()
      Semicolon | Comma => p.eat()
      _ => p.expected("comma or semicolon")
    }
  }
  p.expect_closing_delimiter(m, RightParen) |> ignore
  p.wrap(m, MathArgs)
}

///|
/// Parses a single argument in a math argument list.
fn math_arg(p : Parser, seen : @hashset.HashSet[String]) -> Unit {
  let m = p.marker()
  let start = p.current_start()
  let mut arg_kind : SyntaxKind? = None
  if p.lexer.maybe_math_spread_arg(start) is Some(spread) {
    // Parses a spread argument: `..args`.
    arg_kind = Some(Spread)
    p.token.node = spread
    p.eat()
  } else if p.lexer.maybe_math_named_arg(start) is Some(named) {
    // Parses a named argument: `thickness: #12pt`.
    arg_kind = Some(Named)
    p.token.node = named
    let text = p.current_text()
    p.eat()
    p.convert_and_eat(Colon)
    if !seen.add_and_check(text) {
      p.nodes[m].convert_to_error("duplicate argument: \{text}")
    }
  }

  // Parses the argument itself.
  let m_arg = p.marker()
  let count = math_exprs(
    p,
    SyntaxSet::of([End, Dollar, Comma, Semicolon, RightParen]),
  )
  if count == 0 {
    // Named arguments require a value.
    if arg_kind is Some(Named) {
      p.expected("expression")
    }
  }

  // Wrap math function arguments to join adjacent math content or create an
  // empty 'Math' node for when we have 0 args.
  if count != 1 {
    p.wrap(m_arg, Math)
  }
  if arg_kind is Some(kind) {
    p.wrap(m, kind)
  }
}

///|
/// Parses the contents of a code block.
fn code(p : Parser, stop_set : SyntaxSet) -> Unit {
  let m = p.marker()
  code_exprs(p, stop_set)
  p.wrap(m, Code)
}

///|
/// Parses a sequence of code expressions.
fn code_exprs(p : Parser, stop_set : SyntaxSet) -> Unit {
  if !p.check_depth_until(stop_set) {
    return
  }
  while !p.at_set(stop_set) {
    p.with_nl_mode(ContextualContinue, () => {
      if !p.at_set(code_expr_set) {
        p.unexpected()
        return
      }
      code_expr(p)
      if !p.at_set(stop_set) && !p.eat_if(Semicolon) {
        p.expected("semicolon or line break")
        if p.at(Label) {
          p.hint("labels can only be applied in markup mode")
          p.hint("try wrapping your code in a markup block (`[ ]`)")
        }
      }
    })
  }
}

///|
/// Parses an atomic code expression embedded in markup or math.
fn embedded_code_expr(p : Parser) -> Unit {
  p.enter_modes(Code, Stop, () => {
    p.assert_at(Hash)
    if p.had_trivia() || p.end() {
      p.expected("expression")
      return
    }
    let stmt = p.at_set(stmt_set)
    code_expr_prec(p, true, 0)

    // Note: 2d math arguments rely on the `directly_at` check.
    let semi = (stmt || p.directly_at(Semicolon)) && p.eat_if(Semicolon)
    if stmt && !semi && !p.end() && !p.at(RightBracket) {
      p.expected("semicolon or line break")
    }
  })
}

///|
/// Parses a single code expression.
fn code_expr(p : Parser) -> Unit {
  code_expr_prec(p, false, 0)
}

///|
/// Parses a code expression with at least the given precedence.
fn code_expr_prec(p : Parser, atomic : Bool, min_prec : Int) -> Unit {
  p.with_depth(() => {
    let m = p.marker()
    if p.at_set(unary_op_set) {
      if !atomic {
        guard UnOp::from_kind(p.current()) is Some(op)
        p.eat()
        code_expr_prec(p, atomic, op.precedence())
        p.wrap(m, Unary)
      } else {
        p.unexpected()
        p.hint(
          "to use a unary operator here, wrap the entire expression in parentheses",
        )
      }
    } else {
      code_primary(p, atomic)
    }
    while true {
      if p.directly_at(LeftParen) || p.directly_at(LeftBracket) {
        args(p)
        p.wrap(m, FuncCall)
        continue
      }
      let at_field_or_method = p.directly_at(Dot) &&
        p.lexer.copy().next().0 == Ident
      if atomic && !at_field_or_method {
        break
      }
      if p.eat_if(Dot) {
        p.expect(Ident) |> ignore
        p.wrap(m, FieldAccess)
        continue
      }
      let binop = if p.at_set(binary_op_set) {
        BinOp::from_kind(p.current())
      } else if min_prec <= BinOp::NotIn.precedence() && p.eat_if(Not) {
        if p.at(In) {
          Some(BinOp::NotIn)
        } else {
          p.expected("keyword `in`")
          break
        }
      } else {
        None
      }
      if binop is Some(op) {
        let mut prec = op.precedence()
        if prec < min_prec {
          break
        }
        match op.assoc() {
          Left => prec += 1
          Right => ()
        }
        p.eat()
        code_expr_prec(p, false, prec)
        p.wrap(m, Binary)
        continue
      }
      break
    }
  })
}

///|
/// Parses a primary in a code expression.
fn code_primary(p : Parser, atomic : Bool) -> Unit {
  let m = p.marker()
  match p.current() {
    Ident => {
      p.eat()
      if !atomic && p.at(Arrow) {
        p.wrap(m, Params)
        p.assert_at(Arrow)
        code_expr(p)
        p.wrap(m, Closure)
      }
    }
    Underscore if !atomic => {
      p.eat()
      if p.at(Arrow) {
        p.wrap(m, Params)
        p.eat()
        code_expr(p)
        p.wrap(m, Closure)
      } else if p.eat_if(Eq) {
        code_expr(p)
        p.wrap(m, DestructAssignment)
      } else {
        p.nodes[m].expected("expression")
      }
    }
    LeftBrace => code_block(p)
    LeftBracket => content_block(p)
    LeftParen => expr_with_paren(p, atomic)
    Dollar => equation(p)
    Let => let_binding(p)
    Set => set_rule(p)
    Show => show_rule(p)
    Context => contextual(p, atomic)
    If => conditional(p)
    While => while_loop(p)
    For => for_loop(p)
    Import => module_import(p)
    Include => module_include(p)
    Break => break_stmt(p)
    Continue => continue_stmt(p)
    Return => return_stmt(p)
    Raw => p.eat()
    None | Auto | Int | Float | Bool | Numeric | Str | Label => p.eat()
    // Consume erroneous tokens for things like `#12p`, `#]`, or `#"abc\"`.
    _ if atomic => p.unexpected()
    _ => p.expected("expression")
  }
}

///|
/// Reparses a full content or code block.
fn reparse_block(text : String, start : Int, end : Int) -> SyntaxNode? {
  let p = Parser::new(text, start, Code)
  block(p)
  if p.balanced && p.prev_end() == end && p.nodes.length() > 0 {
    Some(p.nodes[0])
  } else {
    None
  }
}

///|
/// Parses a content or code block.
fn block(p : Parser) -> Unit {
  match p.current() {
    LeftBracket => content_block(p)
    LeftBrace => code_block(p)
    _ => p.expected("block")
  }
}

///|
/// Parses a code block: `{ let x = 1; x + 2 }`.
fn code_block(p : Parser) -> Unit {
  let m = p.marker()
  p.enter_modes(Code, Continue, () => {
    p.assert_at(LeftBrace)
    code(p, SyntaxSet::of([RightBrace, RightBracket, RightParen, End]))
    p.expect_closing_delimiter(m, RightBrace) |> ignore
  })
  p.wrap(m, CodeBlock)
}

///|
/// Parses a content block: `[*Hi* there!]`.
fn content_block(p : Parser) -> Unit {
  let m = p.marker()
  p.enter_modes(Markup, Continue, () => {
    p.assert_at(LeftBracket)
    markup(p, true, true, SyntaxSet::of([RightBracket, End]))
    p.expect_closing_delimiter(m, RightBracket) |> ignore
  })
  p.wrap(m, ContentBlock)
}

///|
/// Parses a let binding: `let x = 1`.
fn let_binding(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Let)
  let m2 = p.marker()
  let mut closure = false
  let mut other = false
  if p.eat_if(Ident) {
    if p.directly_at(LeftParen) {
      params(p)
      closure = true
    }
  } else {
    pattern(p, false, @hashset.HashSet([]), None)
    other = true
  }
  let ok = if closure || other { p.expect(Eq) } else { p.eat_if(Eq) }
  if ok {
    code_expr(p)
  }
  if closure {
    p.wrap(m2, Closure)
  }
  p.wrap(m, LetBinding)
}

///|
/// Parses a set rule: `set text(...)`.
fn set_rule(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Set)
  let m2 = p.marker()
  p.expect(Ident) |> ignore
  while p.eat_if(Dot) {
    p.expect(Ident) |> ignore
    p.wrap(m2, FieldAccess)
  }
  args(p)
  if p.eat_if(If) {
    code_expr(p)
  }
  p.wrap(m, SetRule)
}

///|
/// Parses a show rule: `show heading: it => emph(it.body)`.
fn show_rule(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Show)
  let m2 = p.before_trivia()
  if !p.at(Colon) {
    code_expr(p)
  }
  if p.eat_if(Colon) {
    code_expr(p)
  } else {
    p.expected_at(m2, "colon")
  }
  p.wrap(m, ShowRule)
}

///|
/// Parses a contextual expression: `context text.lang`.
fn contextual(p : Parser, atomic : Bool) -> Unit {
  let m = p.marker()
  p.assert_at(Context)
  code_expr_prec(p, atomic, 0)
  p.wrap(m, Contextual)
}

///|
/// Parses an if-else conditional: `if x { y } else { z }`.
fn conditional(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(If)
  code_expr(p)
  block(p)
  if p.eat_if(Else) {
    if p.at(If) {
      conditional(p)
    } else {
      block(p)
    }
  }
  p.wrap(m, Conditional)
}

///|
/// Parses a while loop: `while x { y }`.
fn while_loop(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(While)
  code_expr(p)
  block(p)
  p.wrap(m, WhileLoop)
}

///|
/// Parses a for loop: `for x in y { z }`.
fn for_loop(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(For)
  let seen = @hashset.HashSet([])
  pattern(p, false, seen, None)
  if p.at(Comma) {
    let node = p.eat_and_get()
    node.unexpected()
    node.hint("destructuring patterns must be wrapped in parentheses")
    if p.at_set(pattern_set) {
      pattern(p, false, seen, None)
    }
  }
  p.expect(In) |> ignore
  code_expr(p)
  block(p)
  p.wrap(m, ForLoop)
}

///|
/// Parses a module import: `import "utils.typ": a, b, c`.
fn module_import(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Import)
  code_expr(p)
  if p.eat_if(As) {
    p.expect(Ident) |> ignore
  }
  if p.eat_if(Colon) {
    if p.at(LeftParen) {
      p.with_nl_mode(Continue, () => {
        let m2 = p.marker()
        p.assert_at(LeftParen)
        import_items(p)
        p.expect_closing_delimiter(m2, RightParen) |> ignore
      })
    } else if !p.eat_if(Star) {
      import_items(p)
    }
  }
  p.wrap(m, ModuleImport)
}

///|
/// Parses items to import from a module: `a, b, c`.
fn import_items(p : Parser) -> Unit {
  let m = p.marker()
  while !p.current().is_terminator() {
    let item_marker = p.marker()
    if !p.eat_if(Ident) {
      p.unexpected()
    }
    // Nested import path: `a.b.c`
    while p.eat_if(Dot) {
      p.expect(Ident) |> ignore
    }
    p.wrap(item_marker, ImportItemPath)
    // Rename imported item.
    if p.eat_if(As) {
      p.expect(Ident) |> ignore
      p.wrap(item_marker, RenamedImportItem)
    }
    if !p.current().is_terminator() {
      p.expect(Comma) |> ignore
    }
  }
  p.wrap(m, ImportItems)
}

///|
/// Parses a module include: `include "chapter1.typ"`.
fn module_include(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Include)
  code_expr(p)
  p.wrap(m, ModuleInclude)
}

///|
/// Parses a break from a loop: `break`.
fn break_stmt(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Break)
  p.wrap(m, LoopBreak)
}

///|
/// Parses a continue in a loop: `continue`.
fn continue_stmt(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Continue)
  p.wrap(m, LoopContinue)
}

///|
/// Parses a return from a function: `return`, `return x + 1`.
fn return_stmt(p : Parser) -> Unit {
  let m = p.marker()
  p.assert_at(Return)
  if p.at_set(code_expr_set) {
    code_expr(p)
  }
  p.wrap(m, FuncReturn)
}

///|
/// An expression that starts with a parenthesis.
fn expr_with_paren(p : Parser, atomic : Bool) -> Unit {
  if atomic {
    // Atomic expressions aren't modified by operators that follow them, so
    // our first guess of array/dict will be correct.
    parenthesized_or_array_or_dict(p) |> ignore
    return
  }

  // If we've seen this position before and have a memoized result, restore it
  // and return. Otherwise, get a key to this position and a checkpoint to
  // restart from in case we make a wrong prediction.
  guard p.restore_memo_or_checkpoint() is Some((memo_key, checkpoint)) else {
    return
  }
  let prev_len = checkpoint.node_len
  let kind = parenthesized_or_array_or_dict(p)

  // If '=>' or '=' follows, we must backtrack and reparse as either a
  // parameter list or a destructuring.
  if p.at(Arrow) {
    p.restore(checkpoint)
    let m = p.marker()
    params(p)
    if !p.expect(Arrow) {
      return
    }
    code_expr(p)
    p.wrap(m, Closure)
  } else if p.at(Eq) && kind != Parenthesized {
    p.restore(checkpoint)
    let m = p.marker()
    destructuring_or_parenthesized(p, true, @hashset.HashSet([]))
    if !p.expect(Eq) {
      return
    }
    code_expr(p)
    p.wrap(m, DestructAssignment)
  } else {
    return
  }

  // Memoize result if we backtracked.
  p.memoize_parsed_nodes(memo_key, prev_len)
}

///|
/// State for array/dictionary parsing.
priv struct GroupState {
  mut count : Int
  /// Whether this is just a single expression in parens: `(a)`.
  mut maybe_just_parens : Bool
  /// The kind to wrap as (if we've figured it out yet).
  mut kind : SyntaxKind?
  /// Store named arguments so we can give an error if they're repeated.
  seen : @hashset.HashSet[String]
}

///|
/// Parses either a parenthesized expression, an array, or a dictionary.
fn parenthesized_or_array_or_dict(p : Parser) -> SyntaxKind {
  let state : GroupState = {
    count: 0,
    maybe_just_parens: true,
    kind: None,
    seen: @hashset.HashSet([]),
  }
  let m = p.marker()
  p.with_nl_mode(Continue, () => {
    p.assert_at(LeftParen)
    if p.eat_if(Colon) {
      state.kind = Some(Dict)
    }
    while !p.current().is_terminator() {
      if !p.at_set(array_or_dict_item_set) {
        p.unexpected()
        continue
      }
      array_or_dict_item(p, state)
      state.count += 1
      if !p.current().is_terminator() && p.expect(Comma) {
        state.maybe_just_parens = false
      }
    }
    p.expect_closing_delimiter(m, RightParen) |> ignore
  })
  let kind = if state.maybe_just_parens && state.count == 1 {
    Parenthesized
  } else {
    state.kind.unwrap_or(Array)
  }
  p.wrap(m, kind)
  kind
}

///|
/// Parses a single item in an array or dictionary.
fn array_or_dict_item(p : Parser, state : GroupState) -> Unit {
  let m = p.marker()
  if p.eat_if(Dots) {
    // Parses a spread item: `..item`.
    code_expr(p)
    p.wrap(m, Spread)
    state.maybe_just_parens = false
    return
  }
  code_expr(p)
  if p.eat_if(Colon) {
    // Parses a named/keyed pair: `name: item` or `"key": item`.
    code_expr(p)
    let node = p.nodes[m]
    let pair_kind : SyntaxKind = if node.kind() == Ident {
      Named
    } else {
      Keyed
    }
    let key = match node.kind() {
      Ident => Some(node.leaf_text())
      Str => Some(unescape_str_literal(node.leaf_text()))
      _ => None
    }
    if key is Some(key) && !state.seen.add_and_check(key) {
      node.convert_to_error("duplicate key: \{key}")
    }
    p.wrap(m, pair_kind)
    state.maybe_just_parens = false
    if state.kind is Some(Array) {
      p.nodes[m].expected("expression")
    } else {
      state.kind = Some(Dict)
    }
  } else if state.kind is Some(Dict) {
    // Parses a positional item.
    p.nodes[m].expected("named or keyed pair")
  } else {
    state.kind = Some(Array)
  }
}

///|
/// Parses a function call's argument list: `(12pt, y)`.
fn args(p : Parser) -> Unit {
  if !p.directly_at(LeftParen) && !p.directly_at(LeftBracket) {
    p.expected("argument list")
    if p.at(LeftParen) || p.at(LeftBracket) {
      p.hint("there may not be any spaces before the argument list")
    }
  }
  let m = p.marker()
  if p.at(LeftParen) {
    let m2 = p.marker()
    p.with_nl_mode(Continue, () => {
      p.assert_at(LeftParen)
      let seen = @hashset.HashSet([])
      while !p.current().is_terminator() {
        if !p.at_set(arg_set) {
          p.unexpected()
          continue
        }
        arg(p, seen)
        if !p.current().is_terminator() {
          p.expect(Comma) |> ignore
        }
      }
      p.expect_closing_delimiter(m2, RightParen) |> ignore
    })
  }
  while p.directly_at(LeftBracket) {
    content_block(p)
  }
  p.wrap(m, Args)
}

///|
/// Parses a single argument in an argument list.
fn arg(p : Parser, seen : @hashset.HashSet[String]) -> Unit {
  let m = p.marker()
  // Parses a spread argument: `..args`.
  if p.eat_if(Dots) {
    code_expr(p)
    p.wrap(m, Spread)
    return
  }
  // Parses a normal positional argument or an argument name.
  let was_at_expr = p.at_set(code_expr_set)
  let text = p.current_text()
  code_expr(p)

  // Parses a named argument: `thickness: 12pt`.
  if p.eat_if(Colon) {
    // Recover from bad argument name.
    if was_at_expr {
      if p.nodes[m].kind() != Ident {
        p.nodes[m].expected("identifier")
      } else if !seen.add_and_check(text) {
        p.nodes[m].convert_to_error("duplicate argument: \{text}")
      }
    }
    code_expr(p)
    p.wrap(m, Named)
  }
}

///|
/// Parses a closure's parameters: `(x, y)`.
fn params(p : Parser) -> Unit {
  let m = p.marker()
  p.with_nl_mode(Continue, () => {
    p.assert_at(LeftParen)
    let seen = @hashset.HashSet([])
    let sink = Ref::new(false)
    while !p.current().is_terminator() {
      if !p.at_set(param_set) {
        p.unexpected()
        continue
      }
      param(p, seen, sink)
      if !p.current().is_terminator() {
        p.expect(Comma) |> ignore
      }
    }
    p.expect_closing_delimiter(m, RightParen) |> ignore
  })
  p.wrap(m, Params)
}

///|
/// Parses a single parameter in a parameter list.
fn param(p : Parser, seen : @hashset.HashSet[String], sink : Ref[Bool]) -> Unit {
  let m = p.marker()
  // Parses argument sink: `..sink`.
  if p.eat_if(Dots) {
    if p.at_set(pattern_leaf_set) {
      pattern_leaf(p, false, seen, Some("parameter"))
    }
    p.wrap(m, Spread)
    let had = sink.val
    sink.val = true
    if had {
      p.nodes[m].convert_to_error("only one argument sink is allowed")
    }
    return
  }
  // Parses a normal positional parameter or a parameter name.
  let was_at_pat = p.at_set(pattern_set)
  pattern(p, false, seen, Some("parameter"))

  // Parses a named parameter: `thickness: 12pt`.
  if p.eat_if(Colon) {
    // Recover from bad parameter name.
    if was_at_pat && p.nodes[m].kind() != Ident {
      p.nodes[m].expected("identifier")
    }
    code_expr(p)
    p.wrap(m, Named)
  }
}

///|
/// Parses a binding or reassignment pattern.
fn pattern(
  p : Parser,
  reassignment : Bool,
  seen : @hashset.HashSet[String],
  dupe : String?,
) -> Unit {
  p.with_depth(() => {
    match p.current() {
      Underscore => p.eat()
      LeftParen => destructuring_or_parenthesized(p, reassignment, seen)
      _ => pattern_leaf(p, reassignment, seen, dupe)
    }
  })
}

///|
/// Parses a destructuring pattern or just a parenthesized pattern.
fn destructuring_or_parenthesized(
  p : Parser,
  reassignment : Bool,
  seen : @hashset.HashSet[String],
) -> Unit {
  let sink = Ref::new(false)
  let mut count = 0
  let maybe_just_parens = Ref::new(true)
  let m = p.marker()
  p.with_nl_mode(Continue, () => {
    p.assert_at(LeftParen)
    while !p.current().is_terminator() {
      if !p.at_set(destructuring_item_set) {
        p.unexpected()
        continue
      }
      destructuring_item(p, reassignment, seen, maybe_just_parens, sink)
      count += 1
      if !p.current().is_terminator() && p.expect(Comma) {
        maybe_just_parens.val = false
      }
    }
    p.expect_closing_delimiter(m, RightParen) |> ignore
  })
  if maybe_just_parens.val && count == 1 && !sink.val {
    p.wrap(m, Parenthesized)
  } else {
    p.wrap(m, Destructuring)
  }
}

///|
/// Parses an item in a destructuring pattern.
fn destructuring_item(
  p : Parser,
  reassignment : Bool,
  seen : @hashset.HashSet[String],
  maybe_just_parens : Ref[Bool],
  sink : Ref[Bool],
) -> Unit {
  let m = p.marker()
  // Parse destructuring sink: `..rest`.
  if p.eat_if(Dots) {
    if p.at_set(pattern_leaf_set) {
      pattern_leaf(p, reassignment, seen, None)
    }
    p.wrap(m, Spread)
    let had = sink.val
    sink.val = true
    if had {
      p.nodes[m].convert_to_error("only one destructuring sink is allowed")
    }
    return
  }

  // Parse a normal positional pattern or a destructuring key.
  let was_at_pat = p.at_set(pattern_set)

  // We must use a full checkpoint here (can't just clone the lexer) because
  // there may be trivia between the identifier and the colon we need to skip.
  let checkpoint = p.checkpoint()
  if !(p.eat_if(Ident) && p.at(Colon)) {
    p.restore(checkpoint)
    pattern(p, reassignment, seen, None)
  }

  // Parse named destructuring item.
  if p.eat_if(Colon) {
    // Recover from bad named destructuring.
    if was_at_pat && p.nodes[m].kind() != Ident {
      p.nodes[m].expected("identifier")
    }
    pattern(p, reassignment, seen, None)
    p.wrap(m, Named)
    maybe_just_parens.val = false
  }
}

///|
/// Parses a leaf in a pattern - either an identifier or an expression
/// depending on whether it's a binding or reassignment pattern.
fn pattern_leaf(
  p : Parser,
  reassignment : Bool,
  seen : @hashset.HashSet[String],
  dupe : String?,
) -> Unit {
  if p.current().is_keyword() {
    p.eat_and_get().expected("pattern")
    return
  } else if !p.at_set(pattern_leaf_set) {
    p.expected("pattern")
    return
  }
  let m = p.marker()
  let text = p.current_text()

  // We parse an atomic expression even though we only want an identifier for
  // better error recovery.
  code_expr_prec(p, true, 0)
  if !reassignment {
    let node = p.nodes[m]
    if node.kind() == Ident {
      if !seen.add_and_check(text) {
        node.convert_to_error("duplicate \{dupe.unwrap_or("binding")}: \{text}")
      }
    } else {
      node.expected("pattern")
    }
  }
}

///|
/// Manages parsing a stream of tokens into a tree of [SyntaxNode]s.
priv struct Parser {
  /// The source text shared with the lexer.
  text : String
  /// A lexer over the source text with multiple modes.
  lexer : Lexer
  /// The newline mode: whether to insert a temporary end at newlines.
  mut nl_mode : AtNewline
  /// The current token under inspection, not yet present in `nodes`.
  mut token : Token
  /// Whether the parser has the expected set of open/close delimiters.
  mut balanced : Bool
  /// Nodes representing the concrete syntax tree of previously parsed text.
  nodes : Array[SyntaxNode]
  /// Parser checkpoints for a given text index.
  memo : MemoArena
  /// The current expression nesting depth.
  mut depth : Int
}

///|
/// A single token returned from the lexer with a cached kind and a record of
/// preceding trivia.
priv struct Token {
  /// The kind of the current token.
  mut kind : SyntaxKind
  /// The node of the current token, ready to be eaten.
  mut node : SyntaxNode
  /// The number of preceding trivia before this token.
  mut n_trivia : Int
  /// Whether this token's preceding trivia contained a newline.
  newline : Newline?
  /// The index into `text` of the start of our current token.
  start : Int
  /// The index into `text` of the end of the previous token.
  mut prev_end : Int
}

///|
fn Token::copy(self : Token) -> Token {
  {
    kind: self.kind,
    node: self.node,
    n_trivia: self.n_trivia,
    newline: self.newline,
    start: self.start,
    prev_end: self.prev_end,
  }
}

///|
/// Information about newlines in a group of trivia.
priv struct Newline {
  /// The column of the start of the next token in its line.
  column : Int?
  /// Whether any of our newlines were paragraph breaks.
  parbreak : Bool
}

///|
/// How to proceed with parsing when at a newline.
priv enum AtNewline {
  /// Continue at newlines.
  Continue
  /// Stop at any newline.
  Stop
  /// Continue only if there is a continuation with `else` or `.` (Code only).
  ContextualContinue
  /// Stop only at a parbreak, not normal newlines (Markup only).
  StopParBreak
  /// Require that the token's column be greater or equal to a column.
  RequireColumn(Int)
} derive(Eq)

///|
/// Whether to stop at a newline or continue based on the current context.
fn AtNewline::stop_at(
  self : AtNewline,
  newline : Newline,
  kind : SyntaxKind,
) -> Bool {
  match self {
    Continue => false
    Stop => true
    ContextualContinue =>
      match kind {
        Else | Dot => false
        _ => true
      }
    StopParBreak => newline.parbreak
    RequireColumn(min_col) =>
      match newline.column {
        Some(column) => column <= min_col
        None => false
      }
  }
}

///|
/// Create a new parser starting from the given text offset and syntax mode.
fn Parser::new(text : String, offset : Int, mode : SyntaxMode) -> Parser {
  let lexer = Lexer::new(text, mode)
  lexer.jump(offset)
  let nl_mode = AtNewline::Continue
  let nodes = []
  let token = Parser::lex(nodes, lexer, nl_mode)
  {
    text,
    lexer,
    nl_mode,
    token,
    balanced: true,
    nodes,
    memo: { arena: [], memo_map: {}, },
    depth: 0,
  }
}

///|
/// Consume the parser, generating a single top-level node.
fn Parser::finish_into(self : Parser, kind : SyntaxKind) -> SyntaxNode {
  guard self.at(End) else { abort("parser did not reach the end") }
  SyntaxNode::inner_owned(kind, self.nodes)
}

///|
fn Parser::current(self : Parser) -> SyntaxKind {
  self.token.kind
}

///|
fn Parser::at(self : Parser, kind : SyntaxKind) -> Bool {
  self.token.kind == kind
}

///|
fn Parser::at_set(self : Parser, set : SyntaxSet) -> Bool {
  set.contains(self.token.kind)
}

///|
fn Parser::end(self : Parser) -> Bool {
  self.at(End)
}

///|
/// If we're at the given `kind` with no preceding trivia tokens.
fn Parser::directly_at(self : Parser, kind : SyntaxKind) -> Bool {
  self.token.kind == kind && !self.had_trivia()
}

///|
fn Parser::had_trivia(self : Parser) -> Bool {
  self.token.n_trivia > 0
}

///|
fn Parser::had_newline(self : Parser) -> Bool {
  self.token.newline is Some(_)
}

///|
/// The number of characters until the most recent newline from the start of
/// the current token.
fn Parser::current_column(self : Parser) -> Int {
  match self.token.newline {
    Some({ column: Some(column), .. }) => column
    _ => self.lexer.column(self.token.start)
  }
}

///|
/// The current token's text.
fn Parser::current_text(self : Parser) -> String {
  self.text.unsafe_substring(start=self.token.start, end=self.current_end())
}

///|
fn Parser::current_start(self : Parser) -> Int {
  self.token.start
}

///|
fn Parser::current_end(self : Parser) -> Int {
  self.lexer.cursor()
}

///|
fn Parser::prev_end(self : Parser) -> Int {
  self.token.prev_end
}

///|
/// A marker that will point to the current token once it's been eaten.
fn Parser::marker(self : Parser) -> Int {
  self.nodes.length()
}

///|
/// A marker that will point to first trivia before this token.
fn Parser::before_trivia(self : Parser) -> Int {
  self.nodes.length() - self.token.n_trivia
}

///|
/// Eat the current node and return it for in-place mutation.
fn Parser::eat_and_get(self : Parser) -> SyntaxNode {
  let offset = self.nodes.length()
  self.eat()
  self.nodes[offset]
}

///|
/// Eat the token if at `kind`. Returns `true` if eaten.
fn Parser::eat_if(self : Parser, kind : SyntaxKind) -> Bool {
  let at = self.at(kind)
  if at {
    self.eat()
  }
  at
}

///|
/// Assert that we are at the given kind and eat it.
fn Parser::assert_at(self : Parser, kind : SyntaxKind) -> Unit {
  guard self.token.kind == kind else {
    abort("parser expected \{kind}, found \{self.token.kind}")
  }
  self.eat()
}

///|
/// Convert the current token's kind and eat it.
fn Parser::convert_and_eat(self : Parser, kind : SyntaxKind) -> Unit {
  self.token.node.convert_to_kind(kind)
  self.eat()
}

///|
/// Eat the current token and prepare a new one.
fn Parser::eat(self : Parser) -> Unit {
  self.nodes.push(self.token.node)
  self.token = Parser::lex(self.nodes, self.lexer, self.nl_mode)
}

///|
/// Detach the parsed trivia nodes from this token (but not newline info) so
/// that subsequent wrapping will include the trivia.
fn Parser::flush_trivia(self : Parser) -> Unit {
  self.token.n_trivia = 0
  self.token.prev_end = self.token.start
}

///|
/// Wrap the nodes from a marker up to (but excluding) the current token in a
/// new inner node of the given kind.
fn Parser::wrap(self : Parser, from : Int, kind : SyntaxKind) -> Unit {
  let to = self.before_trivia()
  let from = if from < to { from } else { to }
  let children = self.nodes[from:to].to_array()
  let rest = self.nodes[to:].to_array()
  self.nodes.truncate(from)
  self.nodes.push(SyntaxNode::inner_owned(kind, children))
  self.nodes.append(rest)
}

///|
/// Wrap the nodes from a marker up to the current token in a new error node.
fn Parser::wrap_error(self : Parser, from : Int, message : String) -> Unit {
  let to = self.before_trivia()
  let from = if from < to { from } else { to }
  let buf = StringBuilder()
  for i in from..<to {
    buf.write_string(self.nodes[i].full_text())
  }
  let rest = self.nodes[to:].to_array()
  self.nodes.truncate(from)
  self.nodes.push(SyntaxNode::error(message, buf.to_string()))
  self.nodes.append(rest)
}

///|
/// Parse within the [SyntaxMode] for subsequent tokens. This may re-lex the
/// final token on exit.
fn Parser::enter_modes(
  self : Parser,
  mode : SyntaxMode,
  stop : AtNewline,
  func : () -> Unit,
) -> Unit {
  let previous = self.lexer.mode
  self.lexer.set_mode(mode)
  self.with_nl_mode(stop, func)
  if mode != previous {
    self.lexer.set_mode(previous)
    self.lexer.jump(self.token.prev_end)
    self.nodes.truncate(self.nodes.length() - self.token.n_trivia)
    self.token = Parser::lex(self.nodes, self.lexer, self.nl_mode)
  }
}

///|
/// Parse within the [AtNewline] mode for subsequent tokens.
fn Parser::with_nl_mode(
  self : Parser,
  mode : AtNewline,
  func : () -> Unit,
) -> Unit {
  let previous = self.nl_mode
  self.nl_mode = mode
  func()
  self.nl_mode = previous
  if self.token.newline is Some(newline) && mode != previous {
    // Restore our actual token's kind or insert a fake end.
    let actual_kind = self.token.node.kind()
    if self.nl_mode.stop_at(newline, actual_kind) {
      self.token.kind = End
    } else {
      self.token.kind = actual_kind
    }
  }
}

///|
/// Move the lexer forward and prepare the current token.
fn Parser::lex(
  nodes : Array[SyntaxNode],
  lexer : Lexer,
  nl_mode : AtNewline,
) -> Token {
  let prev_end = lexer.cursor()
  let mut start = prev_end
  let (k, n) = lexer.next()
  let mut kind = k
  let mut node = n
  let mut n_trivia = 0
  let mut space_with_newline = false
  let mut parbreak = false
  while kind.is_trivia() {
    space_with_newline = space_with_newline || kind == SpaceWithNewline
    parbreak = parbreak || kind == Parbreak
    n_trivia += 1
    nodes.push(node)
    start = lexer.cursor()
    let (k, n) = lexer.next()
    kind = k
    node = n
  }
  let newline = if space_with_newline || parbreak {
    let column = if lexer.mode == Markup {
      Some(lexer.column(start))
    } else {
      None
    }
    let newline = { column, parbreak, }
    if nl_mode.stop_at(newline, kind) {
      // Insert a temporary `End` to halt the parser.
      kind = End
    }
    Some(newline)
  } else {
    None
  }
  { kind, node, n_trivia, newline, start, prev_end, }
}

///|
/// Extra parser state for efficiently recovering from mispredicted parses.
priv struct MemoArena {
  /// A single arena of previously parsed nodes.
  arena : Array[SyntaxNode]
  /// A map from the parser's position to a range of previously parsed nodes
  /// in the arena and a checkpoint of the parser's state.
  memo_map : Map[Int, (Int, Int, PartialState)]
}

///|
/// A checkpoint of the parser which can fully restore it to a previous state.
priv struct Checkpoint {
  node_len : Int
  state : PartialState
}

///|
/// State needed to restore the parser's current token and the lexer.
priv struct PartialState {
  cursor : Int
  lex_mode : SyntaxMode
  token : Token
}

///|
/// Store the already parsed nodes and the parser state into the memo map.
fn Parser::memoize_parsed_nodes(
  self : Parser,
  key : Int,
  prev_len : Int,
) -> Unit {
  let { state, node_len, } = self.checkpoint()
  let memo_start = self.memo.arena.length()
  for i in prev_len..<node_len {
    self.memo.arena.push(self.nodes[i].deep_clone())
  }
  self.memo.memo_map[key] = (memo_start, self.memo.arena.length(), state)
}

///|
/// Try to load a memoized result, return `None` if we did or `Some` (with a
/// checkpoint and a key for the memo map) if we didn't.
fn Parser::restore_memo_or_checkpoint(self : Parser) -> (Int, Checkpoint)? {
  let key = self.current_start()
  match self.memo.memo_map.get(key) {
    Some((start, end, state)) => {
      for i in start..<end {
        self.nodes.push(self.memo.arena[i].deep_clone())
      }
      self.restore_partial(state)
      None
    }
    None => Some((key, self.checkpoint()))
  }
}

///|
/// Restore the parser to the state at a checkpoint.
fn Parser::restore(self : Parser, checkpoint : Checkpoint) -> Unit {
  self.nodes.truncate(checkpoint.node_len)
  self.restore_partial(checkpoint.state)
}

///|
/// Restore parts of the checkpoint excluding the nodes vector.
fn Parser::restore_partial(self : Parser, state : PartialState) -> Unit {
  self.lexer.jump(state.cursor)
  self.lexer.set_mode(state.lex_mode)
  let token = state.token.copy()
  token.node = token.node.deep_clone()
  self.token = token
}

///|
/// Save a checkpoint of the parser state.
fn Parser::checkpoint(self : Parser) -> Checkpoint {
  let token = self.token.copy()
  token.node = token.node.deep_clone()
  {
    node_len: self.nodes.length(),
    state: { cursor: self.lexer.cursor(), lex_mode: self.lexer.mode, token, },
  }
}

///|
/// Consume the given `kind` or produce an error.
fn Parser::expect(self : Parser, kind : SyntaxKind) -> Bool {
  let at = self.at(kind)
  if at {
    self.eat()
  } else if kind == Ident && self.token.kind.is_keyword() {
    self.trim_errors()
    self.eat_and_get().expected(kind.name())
  } else {
    self.balanced = self.balanced && !kind.is_grouping()
    self.expected(kind.name())
  }
  at
}

///|
/// Consume the given closing delimiter or produce an error for the matching
/// opening delimiter at `open`.
fn Parser::expect_closing_delimiter(
  self : Parser,
  open : Int,
  kind : SyntaxKind,
) -> Bool {
  let at = self.eat_if(kind)
  if !at {
    self.nodes[open].convert_to_error("unclosed delimiter")
  }
  at
}

///|
/// Produce an error that the given `thing` was expected. If the parser is at
/// an erroneous token, this will instead eat that token and continue.
fn Parser::expected(self : Parser, thing : String) -> Unit {
  if self.token.kind.is_error() {
    self.trim_errors()
    self.eat()
  } else if !self.after_error() {
    self.expected_at(self.before_trivia(), thing)
  }
}

///|
/// Whether the last non-trivia node is an error.
fn Parser::after_error(self : Parser) -> Bool {
  let m = self.before_trivia()
  m > 0 && self.nodes[m - 1].kind().is_error()
}

///|
/// Produce an error that the given `thing` was expected at the position of
/// the marker `m`.
fn Parser::expected_at(self : Parser, m : Int, thing : String) -> Unit {
  let error = SyntaxNode::error("expected \{thing}", "")
  self.nodes.insert(m, error)
}

///|
/// Add a hint to a trailing error.
fn Parser::hint(self : Parser, hint : String) -> Unit {
  let m = self.before_trivia()
  if m - 1 >= 0 && m - 1 < self.nodes.length() {
    self.nodes[m - 1].hint(hint)
  }
}

///|
/// Consume the next token (if any) and produce an error stating that it was
/// unexpected.
fn Parser::unexpected(self : Parser) -> Unit {
  self.trim_errors()
  self.balanced = self.balanced && !self.token.kind.is_grouping()
  self.eat_and_get().unexpected()
}

///|
/// Remove trailing errors with zero length.
fn Parser::trim_errors(self : Parser) -> Unit {
  let end = self.before_trivia()
  let mut start = end
  while start > 0 &&
        self.nodes[start - 1].kind().is_error() &&
        self.nodes[start - 1].is_empty() {
    start -= 1
  }
  if start < end {
    let rest = self.nodes[end:].to_array()
    self.nodes.truncate(start)
    self.nodes.append(rest)
  }
}

///|
/// Check if the maximum depth has been exceeded. If so, generate an error and
/// return `false`.
fn Parser::check_depth_until(self : Parser, stop_set : SyntaxSet) -> Bool {
  if self.depth < max_depth {
    true
  } else {
    self.depth_check_error(Some(stop_set))
    false
  }
}

///|
/// Run `f` one level deeper, or generate an error if the maximum depth has
/// been exceeded.
fn Parser::with_depth(self : Parser, f : () -> Unit) -> Unit {
  if self.depth < max_depth {
    self.depth += 1
    f()
    self.depth -= 1
  } else {
    self.depth_check_error(None)
  }
}

///|
/// Generate an error for an exceeded maximum depth check.
fn Parser::depth_check_error(self : Parser, stop_set : SyntaxSet?) -> Unit {
  let m = self.marker()
  let mut balance = 0
  self.with_nl_mode(Continue, () => {
    while true {
      if self.at_set(SyntaxSet::of([LeftBracket, LeftBrace, LeftParen])) {
        balance += 1
      } else if self.at_set(
          SyntaxSet::of([RightBracket, RightBrace, RightParen]),
        ) {
        balance = if balance > 0 { balance - 1 } else { 0 }
      }
      self.eat()
      let at_stop = match stop_set {
        None => true
        Some(s) => self.at_set(s)
      }
      if (balance == 0 && at_stop) || self.end() {
        break
      }
    }
  })
  self.wrap_error(m, "maximum parsing depth exceeded")
}
