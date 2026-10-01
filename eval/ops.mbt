// Port of `typst-eval/src/ops.rs`.

///|
fn eval_unary(
  vm : Vm,
  unary : @ast.Unary,
) -> @library.Value raise @library.SourceError {
  let expr = unary.expr()
  let value = eval_expr(vm, expr) catch {
    err => {
      overflowing_int_negation_error(unary, expr)
      raise err
    }
  }
  @library.at(unary.span(), () => {
    match unary.op() {
      Pos => @library.pos(value)
      Neg => @library.neg(value)
      Not => @library.not_(value)
    }
  })
}

///|
fn eval_binary(
  vm : Vm,
  binary : @ast.Binary,
) -> @library.Value raise @library.SourceError {
  match binary.op() {
    Add => apply_binary(binary, vm, @library.add)
    Sub => apply_binary(binary, vm, @library.sub)
    Mul => apply_binary(binary, vm, @library.mul)
    Div => apply_binary(binary, vm, @library.div)
    And => apply_binary(binary, vm, @library.and_)
    Or => apply_binary(binary, vm, @library.or_)
    Eq => apply_binary(binary, vm, @library.eq_)
    Neq => apply_binary(binary, vm, @library.neq)
    Lt => apply_binary(binary, vm, @library.lt)
    Leq => apply_binary(binary, vm, @library.leq)
    Gt => apply_binary(binary, vm, @library.gt)
    Geq => apply_binary(binary, vm, @library.geq)
    In => apply_binary_with(binary, vm, @library.in_)
    NotIn => apply_binary_with(binary, vm, @library.not_in)
    Assign => apply_assignment(binary, vm, (_, b) => b)
    AddAssign => apply_assignment(binary, vm, @library.add)
    SubAssign => apply_assignment(binary, vm, @library.sub)
    MulAssign => apply_assignment(binary, vm, @library.mul)
    DivAssign => apply_assignment(binary, vm, @library.div)
  }
}

///|
/// Apply a basic binary operation.
fn apply_binary(
  binary : @ast.Binary,
  vm : Vm,
  op : (@library.Value, @library.Value) -> @library.Value raise @library.HintedError,
) -> @library.Value raise @library.SourceError {
  let lhs = eval_expr(vm, binary.lhs())
  // Short-circuit boolean operations.
  if (binary.op() == And && lhs is Bool(false)) ||
    (binary.op() == Or && lhs is Bool(true)) {
    return lhs
  }
  let rhs = eval_expr(vm, binary.rhs())
  @library.at(binary.span(), () => op(lhs, rhs))
}

///|
/// Apply a binary operation that needs a binding guard.
fn apply_binary_with(
  binary : @ast.Binary,
  vm : Vm,
  op : (@library.BindingGuard, @library.Value, @library.Value) -> @library.Value raise @library.HintedError,
) -> @library.Value raise @library.SourceError {
  let lhs = eval_expr(vm, binary.lhs())
  let rhs = eval_expr(vm, binary.rhs())
  let guard_ = vm.guard_at(@syntax.Span::detached())
  @library.at(binary.span(), () => op(guard_, lhs, rhs))
}

///|
/// Apply an assignment operation.
fn apply_assignment(
  binary : @ast.Binary,
  vm : Vm,
  op : (@library.Value, @library.Value) -> @library.Value raise @library.HintedError,
) -> @library.Value raise @library.SourceError {
  let rhs = eval_expr(vm, binary.rhs())
  let lhs = binary.lhs()
  // An assignment to a dictionary field is different from a normal access
  // since it can create the field instead of just modifying it.
  if binary.op() == Assign && lhs is FieldAccess(access_expr) {
    let dict = access_dict(vm, access_expr)
    dict.insert(access_expr.field().get(), rhs.shared())
    return None
  }
  let location = access(vm, lhs)
  let old = (location.get)()
  (location.set)(None)
  let new = @library.at(binary.span(), () => op(old, rhs)) catch {
    e => {
      (location.set)(old)
      raise e
    }
  }
  (location.set)(new.shared())
  None
}

///|
/// Provide a custom error message when a negated integer literal overflows.
fn overflowing_int_negation_error(
  unary : @ast.Unary,
  expr : @ast.Expr,
) -> Unit raise @library.SourceError {
  if expr is Int(int) &&
    unary.op() == Neg &&
    int.get() is Err(PosOverflow(base~, max_plus_one~)) {
    if max_plus_one {
      @library.bail_at(unary.span(), "cannot write minimum integer manually", hints=[
        "Typst integers are always initially positive", "2^63 does not fit into a signed 64-bit integer",
        "try writing `int.min`",
      ])
    } else {
      let error = @library.SourceDiagnostic::error_at(
        unary.span(),
        "integer value is too small",
      ).with_hint("value does not fit into a signed 64-bit integer")
      if base is None {
        error.hint(
          "a floating point number could approximately represent this value",
        )
        error.hint(
          "you can use a floating point number by appending a dot: `\{expr.to_untyped().leaf_text()}.`",
        )
      }
      @library.bail_diag(error)
    }
  }
}
