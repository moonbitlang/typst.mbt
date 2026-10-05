// Port of `typst-eval/src/flow.rs`.

///|
/// The maximum number of loop iterations.
let max_iterations : Int = 10000

///|
/// A control flow event that occurred during evaluation.
pub(all) enum FlowEvent {
  /// Stop iteration in a loop.
  Break(@syntax.Span)
  /// Skip the remainder of the current iteration in a loop.
  Continue(@syntax.Span)
  /// Stop execution of a function early, optionally returning an explicit
  /// value. The final boolean indicates whether the return was conditional.
  Return(@syntax.Span, @library.Value?, Bool)
}

///|
/// Return an error stating that this control flow is forbidden.
pub fn FlowEvent::forbidden(self : FlowEvent) -> @library.SourceDiagnostic {
  match self {
    Break(span) =>
      @library.SourceDiagnostic::error_at(span, "cannot break outside of loop")
    Continue(span) =>
      @library.SourceDiagnostic::error_at(
        span, "cannot continue outside of loop",
      )
    Return(span, _, _) =>
      @library.SourceDiagnostic::error_at(
        span, "cannot return outside of function",
      )
  }
}

///|
/// Mark a pending return as conditional.
fn mark_conditional_return(vm : Vm) -> Unit {
  if vm.flow is Some(Return(span, value, _)) {
    vm.flow = Some(Return(span, value, true))
  }
}

///|
fn eval_conditional(
  vm : Vm,
  c : @ast.Conditional,
) -> @library.Value raise @library.SourceError {
  let condition = c.condition()
  let cond = eval_expr(vm, condition)
  let output = if @library.at(condition.span(), () => cond.cast()) {
    eval_expr(vm, c.if_body())
  } else {
    match c.else_body() {
      Some(else_body) => eval_expr(vm, else_body)
      None => None
    }
  }
  mark_conditional_return(vm)
  output
}

///|
fn eval_while_loop(
  vm : Vm,
  w : @ast.WhileLoop,
) -> @library.Value raise @library.SourceError {
  let flow = vm.flow
  vm.flow = None
  let mut output : @library.Value = None
  let mut i = 0
  let condition = w.condition()
  let body = w.body()
  while ({
          let c = eval_expr(vm, condition)
          @library.at(condition.span(), () => c.cast())
        }) {
    if i == 0 &&
      is_invariant(condition.to_untyped()) &&
      !can_diverge(body.to_untyped()) {
      @library.bail_at(condition.span(), "condition is always true")
    } else if i >= max_iterations {
      @library.bail_at(w.span(), "loop seems to be infinite")
    }
    let value = eval_expr(vm, body)
    output = @library.at(body.span(), () => @library.join(output, value))
    match vm.flow {
      Some(Break(_)) => {
        vm.flow = None
        break
      }
      Some(Continue(_)) => vm.flow = None
      Some(Return(_, _, _)) => break
      None => ()
    }
    i += 1
  }
  if flow is Some(_) {
    vm.flow = flow
  }
  mark_conditional_return(vm)
  output
}

///|
fn eval_for_loop(
  vm : Vm,
  f : @ast.ForLoop,
) -> @library.Value raise @library.SourceError {
  let flow = vm.flow
  vm.flow = None
  let mut output : @library.Value = None
  let pattern = f.pattern()
  let iterable = eval_expr(vm, f.iterable())
  let iterable_type = iterable.ty()
  let run = (values : Array[@library.Value]) => {
    vm.scopes.enter()
    for value in values {
      destructure(vm, pattern, value)
      let body = f.body()
      let value = eval_expr(vm, body)
      output = @library.at(body.span(), () => @library.join(output, value))
      match vm.flow {
        Some(Break(_)) => {
          vm.flow = None
          break
        }
        Some(Continue(_)) => vm.flow = None
        Some(Return(_, _, _)) => break
        None => ()
      }
    }
    vm.scopes.exit()
  }
  match (pattern, iterable) {
    (_, Array(array)) => run(array.items.map(v => v.shared()))
    (_, Dict(dict)) =>
      run(
        dict.map
        .iter()
        .map(p => {
          @library.Value::Array(
            @library.Arr::from_array([Str(p.0), p.1.shared()]),
          )
        })
        .collect(),
      )
    (Normal(_) | Placeholder(_), Str(str)) =>
      run(@unicode.graphemes(str).map(g => @library.Value::Str(g.to_owned())))
    (Normal(_) | Placeholder(_), Bytes(bytes)) =>
      run(bytes.0.iter().map(b => @library.Value::Int(b.to_int64())).collect())
    (Destructuring(_), Str(_) | Bytes(_)) =>
      @library.bail_at(
        pattern.span(),
        "cannot destructure values of \{iterable_type}",
      )
    _ =>
      @library.bail_at(f.iterable().span(), "cannot loop over \{iterable_type}")
  }
  if flow is Some(_) {
    vm.flow = flow
  }
  mark_conditional_return(vm)
  output
}

///|
/// Whether the expression always evaluates to the same value.
fn is_invariant(expr : @syntax.SyntaxNode) -> Bool {
  match @ast.Expr::from_untyped(expr) {
    Some(Ident(_)) => false
    Some(MathIdent(_)) => false
    Some(FieldAccess(access)) => is_invariant(access.target().to_untyped())
    Some(FuncCall(call)) =>
      is_invariant(call.callee().to_untyped()) &&
      is_invariant(call.args().to_untyped())
    _ => expr.children().iter().all(is_invariant)
  }
}

///|
/// Whether the expression contains a break or return.
fn can_diverge(expr : @syntax.SyntaxNode) -> Bool {
  expr.kind() is (Break | Return) || expr.children().iter().any(can_diverge)
}
