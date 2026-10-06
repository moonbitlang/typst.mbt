// Port of `typst-eval/src/code.rs`.

///|
fn eval_code(
  vm : Vm,
  code : @ast.Code,
) -> @library.Value raise @library.SourceError {
  let exprs = code.exprs().collect()
  eval_code_exprs(vm, exprs[:])
}

///|
/// Evaluate a stream of expressions.
fn eval_code_exprs(
  vm : Vm,
  exprs : ArrayView[@ast.Expr],
) -> @library.Value raise @library.SourceError {
  let flow = vm.flow
  vm.flow = None
  let mut output : @library.Value = None
  let mut i = 0
  while i < exprs.length() {
    let expr = exprs[i]
    i += 1
    let span = expr.span()
    let value : @library.Value = match expr {
      SetRule(set) => {
        let styles = eval_set_rule(vm, set)
        if vm.flow is Some(_) {
          break
        }
        let tail = eval_code_exprs(vm, exprs[i:]).display()
        i = exprs.length()
        Content(tail.styled_with_map(styles))
      }
      ShowRule(show) => {
        let recipe = eval_show_rule(vm, show)
        if vm.flow is Some(_) {
          break
        }
        let tail = eval_code_exprs(vm, exprs[i:]).display()
        i = exprs.length()
        Content(styled_with_recipe(vm, tail, recipe))
      }
      _ => eval_expr(vm, expr)
    }
    output = @library.at(span, () => @library.join(output, value))
    if vm.flow is Some(event) {
      warn_for_discarded_content(vm, event, output)
      break
    }
  }
  if flow is Some(_) {
    vm.flow = flow
  }
  output
}

///|
/// Apply a recipe to content (upstream `Content::styled_with_recipe`).
fn styled_with_recipe(
  vm : Vm,
  content : @library.Content,
  recipe : @library.Recipe,
) -> @library.Content raise @library.SourceError {
  if recipe.selector is None {
    recipe.apply(vm.engine, vm.context, content)
  } else {
    content.styled(Recipe(recipe))
  }
}

///|
/// Evaluate an expression.
pub fn eval_expr(
  vm : Vm,
  expr : @ast.Expr,
) -> @library.Value raise @library.SourceError {
  let span = expr.span()
  let forbidden = (name : String) => {
    @library.SourceDiagnostic::error_at(
      span,
      "\{name} is only allowed directly in code and content blocks",
    )
  }
  let value : @library.Value = match expr {
    Text(v) => Content(@library.TextElem::packed(v.get()))
    Space(v) => Content(space_content(v.had_newline()))
    Linebreak(_) =>
      Content(@library.Content::new(@library.linebreak_elem(), []))
    Parbreak(_) => Content(@library.Content::new(@library.parbreak_elem(), []))
    Escape(v) => Symbol(@library.Symbol::runtime_char(v.get()))
    Shorthand(v) => Symbol(@library.Symbol::runtime_char(v.get()))
    SmartQuote(v) => Content(eval_smart_quote(v))
    Strong(v) => Content(eval_strong(vm, v))
    Emph(v) => Content(eval_emph(vm, v))
    Raw(v) => Content(eval_raw(v))
    Link(v) => Content(eval_link(v))
    Label(v) => Label(@library.Label(v.get()))
    Ref(v) => Content(eval_ref(vm, v))
    Heading(v) => Content(eval_heading(vm, v))
    ListItem(v) => Content(eval_list_item(vm, v))
    EnumItem(v) => Content(eval_enum_item(vm, v))
    TermItem(v) => Content(eval_term_item(vm, v))
    Equation(v) => Content(eval_equation(vm, v))
    Math(v) => Content(eval_math(vm, v))
    MathText(v) => Content(eval_math_text(v))
    MathIdent(v) => eval_math_ident(vm, v)
    MathFieldAccess(v) => eval_math_field_access(vm, v)
    MathShorthand(v) => Symbol(@library.Symbol::runtime_char(v.get()))
    MathAlignPoint(_) =>
      Content(@library.Content::new(@library.align_point_elem(), []))
    MathCall(v) => eval_math_call(vm, v)
    MathDelimited(v) => Content(eval_math_delimited(vm, v))
    MathAttach(v) => Content(eval_math_attach(vm, v))
    MathPrimes(v) => Content(eval_math_primes(v))
    MathFrac(v) => Content(eval_math_frac(vm, v))
    MathRoot(v) => Content(eval_math_root(vm, v))
    Ident(v) => eval_ident(vm, v)
    None(_) => None
    Auto(_) => Auto
    Bool(v) => Bool(v.get())
    Int(v) =>
      match v.get() {
        Ok(int) => Int(int)
        Err(err) => raise @library.SourceError([int_literal_error(v, err)])
      }
    Float(v) => Float(v.get())
    Numeric(v) => {
      let (n, unit) = v.get()
      @library.Value::numeric(n, convert_unit(unit))
    }
    Str(v) => Str(v.get())
    CodeBlock(v) => eval_code_block(vm, v)
    ContentBlock(v) => Content(eval_content_block(vm, v))
    Array(v) => Array(eval_array(vm, v))
    Dict(v) => Dict(eval_dict(vm, v))
    Parenthesized(v) => eval_expr(vm, v.expr())
    FieldAccess(v) => eval_field_access(vm, v)
    FuncCall(v) => eval_func_call(vm, v)
    Closure(v) => eval_closure_expr(vm, v)
    Unary(v) => eval_unary(vm, v)
    Binary(v) => eval_binary(vm, v)
    LetBinding(v) => eval_let_binding(vm, v)
    DestructAssignment(v) => eval_destruct_assignment(vm, v)
    SetRule(_) => raise @library.SourceError([forbidden("set")])
    ShowRule(_) => raise @library.SourceError([forbidden("show")])
    Contextual(v) => Content(eval_contextual(vm, v))
    Conditional(v) => eval_conditional(vm, v)
    WhileLoop(v) => eval_while_loop(vm, v)
    ForLoop(v) => eval_for_loop(vm, v)
    ModuleImport(v) => eval_module_import(vm, v)
    ModuleInclude(v) => Content(eval_module_include(vm, v))
    LoopBreak(v) => {
      if vm.flow is None {
        vm.flow = Some(Break(v.span()))
      }
      None
    }
    LoopContinue(v) => {
      if vm.flow is None {
        vm.flow = Some(Continue(v.span()))
      }
      None
    }
    FuncReturn(v) => {
      let value = match v.body() {
        Some(body) => Some(eval_expr(vm, body))
        None => None
      }
      if vm.flow is None {
        vm.flow = Some(Return(v.span(), value, false))
      }
      None
    }
  }
  let value = value.spanned(span)
  vm.trace_at(span, value)
  value
}

///|
fn convert_unit(unit : @ast.NumericUnit) -> @library.NumericUnit {
  match unit {
    Pt => Pt
    Mm => Mm
    Cm => Cm
    In => In
    Rad => Rad
    Deg => Deg
    Em => Em
    Fr => Fr
    Percent => Percent
  }
}

///|
fn eval_ident(
  vm : Vm,
  ident : @ast.Ident,
) -> @library.Value raise @library.SourceError {
  let span = ident.span()
  @library.at(span, () => vm.scopes.get(ident.get(), vm.guard_at(span))).shared()
}

///|
fn eval_array(
  vm : Vm,
  arr : @ast.ArrayLit,
) -> @library.Arr raise @library.SourceError {
  let items = arr.items().collect()
  let vec = []
  let mut all_dict_spreads = true
  for i, item in items {
    match item {
      Pos(expr) => {
        all_dict_spreads = false
        vec.push(eval_expr(vm, expr))
      }
      Spread(spread) =>
        match eval_expr(vm, spread.expr()) {
          None => ()
          Array(array) => {
            all_dict_spreads = false
            for v in array.items {
              vec.push(v.shared())
            }
          }
          Dict(_) as v if all_dict_spreads &&
            rest_are_dict_spreads(vm, items[i + 1:]) => {
            let fixed = arr.to_untyped().full_text().replace(old="(", new="(: ")
            @library.bail_at(
              spread.span(),
              "cannot spread \{v.ty()} into array",
              hints=["add a colon to create a dictionary instead: `\{fixed}`"],
            )
          }
          v =>
            @library.bail_at(
              spread.span(),
              "cannot spread \{v.ty()} into array",
            )
        }
    }
  }
  @library.Arr::from_array(vec)
}

///|
/// Whether all remaining items are spreads of dictionaries (upstream evaluates
/// them for this check).
fn rest_are_dict_spreads(vm : Vm, items : ArrayView[@ast.ArrayItem]) -> Bool {
  for item in items {
    match item {
      Spread(spread) => {
        let ok = try eval_expr(vm, spread.expr()) catch {
          _ => false
        } noraise {
          Dict(_) => true
          _ => false
        }
        if !ok {
          return false
        }
      }
      _ => return false
    }
  }
  true
}

///|
fn eval_dict(
  vm : Vm,
  dict : @ast.Dict,
) -> @library.Dict raise @library.SourceError {
  let map = @library.Dict::new()
  let invalid_keys = []
  for item in dict.items() {
    match item {
      Named(named) =>
        map.insert(named.name().get(), eval_expr(vm, named.expr()))
      Keyed(keyed) => {
        let raw_key = keyed.key()
        let key = eval_expr(vm, raw_key)
        let key : String = @library.at(raw_key.span(), () => key.cast()) catch {
          @library.SourceError(errors) => {
            invalid_keys.append(errors)
            ""
          }
        }
        map.insert(key, eval_expr(vm, keyed.expr()))
      }
      Spread(spread) =>
        match eval_expr(vm, spread.expr()) {
          None => ()
          Dict(other) =>
            for k, v in other.map {
              map.insert(k, v.shared())
            }
          v =>
            @library.bail_at(
              spread.span(),
              "cannot spread \{v.ty()} into dictionary",
            )
        }
    }
  }
  if !invalid_keys.is_empty() {
    raise @library.SourceError(invalid_keys)
  }
  map
}

///|
fn eval_code_block(
  vm : Vm,
  block : @ast.CodeBlock,
) -> @library.Value raise @library.SourceError {
  vm.scopes.enter()
  let output = eval_code(vm, block.body())
  vm.scopes.exit()
  output
}

///|
fn eval_content_block(
  vm : Vm,
  block : @ast.ContentBlock,
) -> @library.Content raise @library.SourceError {
  vm.scopes.enter()
  let content = eval_markup(vm, block.body())
  vm.scopes.exit()
  content
}

///|
fn eval_field_access(
  vm : Vm,
  access : @ast.FieldAccess,
) -> @library.Value raise @library.SourceError {
  let target = eval_expr(vm, access.target())
  let field = access.field()
  access_field(vm, target, field.get(), field.span())
}

///|
/// Access a field on a value (with a fallback to settable element fields in
/// context).
fn access_field(
  vm : Vm,
  target : @library.Value,
  field : String,
  field_span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  let err = try target.field(field, vm.guard_at(field_span)) catch {
    @library.HintedError(err) => err
  } noraise {
    value => return value
  }
  if target is Func(func) &&
    func.to_element() is Some(element) &&
    element.settable_field_accessor(field) is Some(accessor) {
    let styles = @library.at(field_span, () => vm.context.get_styles())
    return accessor(styles)
  }
  raise @library.SourceError([err.into_error_at(field_span)])
}

///|
fn eval_contextual(
  vm : Vm,
  contextual : @ast.Contextual,
) -> @library.Content raise @library.SourceError {
  let body = contextual.body()
  let visitor = CapturesVisitor::new(Some(vm.scopes), Context)
  visitor.visit(body.to_untyped())
  let captured = visitor.finish()
  let closure : @library.Closure = {
    node: Context(body.to_untyped()),
    defaults: [],
    captured,
    num_pos_params: 0,
    hash: @library.LazyFingerprint::new(),
  }
  let func = @library.Func::closure(closure).spanned(body.span())
  @library.Content::new(@library.context_elem(), [
    (@library.context_elem_func, Func(func)),
  ]).spanned(body.span())
}

///|
/// Emits a warning when we discard content while returning unconditionally.
fn warn_for_discarded_content(
  vm : Vm,
  event : FlowEvent,
  joined : @library.Value,
) -> Unit {
  guard event is Return(span, Some(_), false) else { return }
  guard joined is Content(tree) else { return }
  let warning = @library.SourceDiagnostic::warning_at(
    span, "this return unconditionally discards the content before it",
  ).with_hint("try omitting the `return` to automatically join all values")
  let has_update = !tree.traverse(c => {
    !(c.elem() == @library.state_update_elem() ||
    c.elem() == @library.counter_update_elem())
  })
  if has_update {
    warning.hint(
      "state/counter updates are content that must end up in the document to have an effect",
    )
  }
  vm.engine.sink.warn(warning)
}

///|
/// The error for an invalid integer literal.
fn int_literal_error(
  int : @ast.IntLit,
  err : @ast.IntLiteralError,
) -> @library.SourceDiagnostic {
  let span = int.span()
  match err {
    PosOverflow(base~, ..) => {
      let error = @library.SourceDiagnostic::error_at(
        span, "integer value is too large",
      ).with_hint("value does not fit into a signed 64-bit integer")
      if base is None {
        error.hint(
          "a floating point number could approximately represent this value",
        )
        error.hint(
          "you can use a floating point number by appending a dot: `\{int.to_untyped().leaf_text()}.`",
        )
      }
      error
    }
    InvalidDigit(base, digits) => {
      let (start, end, bad_digits) = find_bad_digits(base, digits)
      let sub_range = @syntax.SubRange::new(start + 2, end + 2)
      let hint_span = match sub_range {
        Some(sr) => @syntax.DiagSpan::from_span(span, sub_range=sr)
        None => @syntax.DiagSpan::from_span(span)
      }
      let the_digits_are_invalid = match bad_digits {
        [digit] => "the digit `\{digit}` is invalid"
        [first, last] => "the digits `\{first}` and `\{last}` are invalid"
        _ => {
          let buf = StringBuilder()
          for i in 0..<(bad_digits.length() - 1) {
            buf.write_string("`\{bad_digits[i]}`, ")
          }
          "the digits \{buf.to_string()}and `\{bad_digits[bad_digits.length() - 1]}` are invalid"
        }
      }
      let an = if base == Octal { "n" } else { "" }
      let allowed = match base {
        Hex => "0-9, a-f, A-F"
        Octal => "0-7"
        Binary => "0-1"
      }
      let error = @library.SourceDiagnostic::error_at(
        span,
        "integer contains digits that are not valid for a\{an} \{base.name()} number",
      )
      error.spanned_hint(the_digits_are_invalid, hint_span)
      error.hint("\{base.name()} numbers only allow digits \{allowed}")
      error
    }
  }
}

///|
/// Find the range of invalid digits and the list of invalid digits.
fn find_bad_digits(
  base : @syntax.NonDecimalBase,
  digits : String,
) -> (Int, Int, Array[Char]) {
  let ranges : Array[(Char, Char)] = match base {
    Hex => [('g', 'z'), ('G', 'Z')]
    Octal => [('8', '9')]
    Binary => [('2', '9')]
  }
  let mut start = digits.length()
  let mut end = 0
  let bad = []
  for range in ranges {
    let mut c = range.0.to_int()
    while c <= range.1.to_int() {
      let ch = Int::unsafe_to_char(c)
      match digits.find(ch.to_string()) {
        Some(index) => {
          if index < start {
            start = index
          }
          if index + 1 > end {
            end = index + 1
          }
          bad.push(ch)
        }
        None => ()
      }
      c += 1
    }
  }
  (start, end, bad)
}
