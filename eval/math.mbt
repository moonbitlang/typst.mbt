// Port of `typst-eval/src/math.rs`.

///|
fn eval_equation(
  vm : Vm,
  v : @ast.Equation,
) -> @library.Content raise @library.SourceError {
  let body = eval_math(vm, v.body())
  @library.Content::new(@library.equation_elem(), [
    (@library.equation_elem_body, Content(body)),
  ]).with_field(@library.equation_elem_block, Bool(v.block()))
}

///|
fn eval_math(
  vm : Vm,
  v : @ast.Math,
) -> @library.Content raise @library.SourceError {
  let children = []
  for expr in v.exprs() {
    children.push(eval_display(vm, expr))
  }
  @library.Content::sequence(children)
}

///|
fn eval_math_text(v : @ast.MathText) -> @library.Content {
  match v.get() {
    Grapheme(text) => @library.SymbolElem::packed(text)
    Number(text) => @library.TextElem::packed(text)
  }
}

///|
fn eval_math_ident(
  vm : Vm,
  v : @ast.MathIdent,
) -> @library.Value raise @library.SourceError {
  let span = v.span()
  @library.at(span, () => vm.scopes.get_in_math(v.get(), vm.guard_at(span))).shared()
}

///|
fn eval_math_field_access(
  vm : Vm,
  v : @ast.MathFieldAccess,
) -> @library.Value raise @library.SourceError {
  let target = eval_math_access(vm, v.target())
  let field = v.field()
  access_field(vm, target, field.get(), field.span())
}

///|
fn eval_math_access(
  vm : Vm,
  v : @ast.MathAccess,
) -> @library.Value raise @library.SourceError {
  let value = match v {
    MathIdent(ident) => eval_math_ident(vm, ident)
    MathFieldAccess(access) => eval_math_field_access(vm, access)
  }
  vm.trace_at(v.span(), value)
  value
}

///|
fn eval_math_delimited(
  vm : Vm,
  v : @ast.MathDelimited,
) -> @library.Content raise @library.SourceError {
  let open = eval_display(vm, v.open())
  let body = eval_math(vm, v.body())
  let close = eval_display(vm, v.close())
  @library.Content::new(@library.lr_elem(), [
    (@library.lr_elem_body, Content(open.add(body).add(close))),
  ])
}

///|
fn eval_math_attach(
  vm : Vm,
  v : @ast.MathAttach,
) -> @library.Content raise @library.SourceError {
  let base = eval_display(vm, v.base())
  let mut elem = @library.Content::new(@library.math_attach_elem(), [
    (@library.math_attach_elem_base, Content(base)),
  ])
  if v.top() is Some(expr) {
    elem = elem.with_field(
      @library.math_attach_elem_t,
      Content(eval_display(vm, expr)),
    )
  }
  if v.primes() is Some(primes) {
    elem = elem.with_field(
      @library.math_attach_elem_tr,
      Content(eval_math_primes(primes)),
    )
  }
  if v.bottom() is Some(expr) {
    elem = elem.with_field(
      @library.math_attach_elem_b,
      Content(eval_display(vm, expr)),
    )
  }
  elem
}

///|
fn eval_math_primes(v : @ast.MathPrimes) -> @library.Content {
  @library.Content::new(@library.primes_elem(), [
    (@library.primes_elem_count, Int(v.count().to_int64())),
  ])
}

///|
fn eval_math_frac(
  vm : Vm,
  v : @ast.MathFrac,
) -> @library.Content raise @library.SourceError {
  let num_expr = v.num()
  let num = eval_display(vm, num_expr)
  let denom_expr = v.denom()
  let denom = eval_display(vm, denom_expr)
  let num_depar = num_expr is Math(math) && math.was_deparenthesized()
  let denom_depar = denom_expr is Math(math) && math.was_deparenthesized()
  @library.Content::new(@library.frac_elem(), [
    (@library.frac_elem_num, Content(num)),
    (@library.frac_elem_denom, Content(denom)),
  ])
  .with_field(@library.frac_elem_num_deparenthesized, Bool(num_depar))
  .with_field(@library.frac_elem_denom_deparenthesized, Bool(denom_depar))
}

///|
fn eval_math_root(
  vm : Vm,
  v : @ast.MathRoot,
) -> @library.Content raise @library.SourceError {
  let index : @library.Value = match v.index() {
    Some(i) => Content(@library.TextElem::packed(i.to_int().to_string()))
    None => None
  }
  let radicand = eval_display(vm, v.radicand())
  @library.Content::new(@library.root_elem(), [
    (@library.root_elem_radicand, Content(radicand)),
  ]).with_field(@library.root_elem_index, index)
}

///|
/// Evaluate an expression and convert it to content.
fn eval_display(
  vm : Vm,
  expr : @ast.Expr,
) -> @library.Content raise @library.SourceError {
  eval_expr(vm, expr).display().spanned(expr.span())
}
