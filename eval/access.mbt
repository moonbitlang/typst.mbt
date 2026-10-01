// Port of `typst-eval/src/access.rs`.
//
// Upstream returns `&mut Value`; here a [Place] gives get/set access to the
// location, so copy-on-write containers can be replaced in their parent.

///|
/// A mutable location holding a value.
pub struct Place {
  get : () -> @library.Value
  set : (@library.Value) -> Unit
}

///|
/// Read the value at the place for mutation: shared containers are copied
/// and the copy is stored back, so the result can be mutated in place.
fn Place::get_mut(self : Place) -> @library.Value {
  match (self.get)() {
    Array(a) if a.shared => {
      let copy = a.copy()
      (self.set)(Array(copy))
      Array(copy)
    }
    Dict(d) if d.shared => {
      let copy = d.copy()
      (self.set)(Dict(copy))
      Dict(copy)
    }
    v => v
  }
}

///|
/// Access an expression mutably.
fn access(vm : Vm, expr : @ast.Expr) -> Place raise @library.SourceError {
  match expr {
    Ident(v) => access_ident(vm, v)
    Parenthesized(v) => access(vm, v.expr())
    FieldAccess(v) => access_field_place(vm, v)
    FuncCall(v) => access_func_call(vm, v)
    _ => {
      eval_expr(vm, expr) |> ignore
      @library.bail_at(expr.span(), "cannot mutate a temporary value")
    }
  }
}

///|
fn access_ident(
  vm : Vm,
  ident : @ast.Ident,
) -> Place raise @library.SourceError {
  let span = ident.span()
  let name = ident.get()
  if vm.inspected == Some(span) {
    let guard_ = @library.BindingGuard::silent(vm.engine.library.features)
    try vm.scopes.get(name, guard_) catch {
      _ => ()
    } noraise {
      value => vm.trace(value)
    }
  }
  let binding = @library.at(span, () => {
    vm.scopes.get_mut(name, vm.guard_at(span))
  })
  { get: () => binding.value, set: v => binding.set_value(v), }
}

///|
fn access_field_place(
  vm : Vm,
  access : @ast.FieldAccess,
) -> Place raise @library.SourceError {
  let dict = access_dict(vm, access)
  let field = access.field().get()
  if !dict.contains(field) {
    raise @library.SourceError([
      @library.HintedString::new(@library.missing_key(field))
      .with_hint("use `insert` to add or update values")
      .into_error_at(access.span()),
    ])
  }
  { get: () => dict.map[field], set: v => dict.map[field] = v, }
}

///|
fn access_func_call(
  vm : Vm,
  call : @ast.FuncCall,
) -> Place raise @library.SourceError {
  if call.callee() is FieldAccess(access_expr) {
    let method = access_expr.field()
    if is_accessor_method(method.get()) {
      let span = call.span()
      let args = eval_args(vm, call.args()).spanned(span)
      let value = access(vm, access_expr.target())
      return trace_call(vm, Some(method.get()), span, () => {
        call_method_access(value, method.get(), args, span)
      })
    }
  }
  eval_expr(vm, FuncCall(call)) |> ignore
  @library.bail_at(call.span(), "cannot mutate a temporary value")
}

///|
/// Access a dictionary mutably for field assignment.
fn access_dict(
  vm : Vm,
  access_expr : @ast.FieldAccess,
) -> @library.Dict raise @library.SourceError {
  let place = access(vm, access_expr.target())
  match place.get_mut() {
    Dict(dict) => dict
    value => {
      let ty = value.ty()
      let span = access_expr.target().span()
      if value is (Symbol(_) | Content(_) | Module(_) | Func(_) | Args(_)) {
        @library.bail_at(span, "cannot mutate fields on \{ty}")
      } else if @library.fields_on(ty).is_empty() {
        @library.bail_at(span, "\{ty} does not have accessible fields")
      } else {
        raise @library.SourceError([
          @library.HintedString::new("fields on \{ty} are not yet mutable")
          .with_hint(
            "try creating a new \{ty} with the updated field value instead",
          )
          .into_error_at(span),
        ])
      }
    }
  }
}
