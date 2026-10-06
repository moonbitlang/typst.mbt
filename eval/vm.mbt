// Port of `typst-eval/src/vm.rs`.

///|
/// A virtual machine.
///
/// Holds the state needed to evaluate Typst sources. A new virtual machine is
/// created for each module evaluation and function call.
pub struct Vm {
  /// The underlying virtual typesetter.
  engine : @library.Engine
  /// A control flow event that is currently happening.
  mut flow : FlowEvent?
  /// The stack of scopes.
  scopes : @library.Scopes
  /// A span that is currently under inspection.
  inspected : @syntax.Span?
  /// Data that is contextually made accessible to code behind the scenes.
  context : @library.Context
}

///|
/// Create a new virtual machine.
pub fn Vm::new(
  engine : @library.Engine,
  context : @library.Context,
  scopes : @library.Scopes,
  target : @syntax.Span,
) -> Vm {
  let inspected = match target.id() {
    Some(id) => {
      // `Traced::get` is tracked (see `@library.note_traced_file`).
      @library.note_traced_file(id)
      engine.traced.get(id)
    }
    None => None
  }
  { engine, context, flow: None, scopes, inspected, }
}

///|
/// Define a variable in the current scope.
pub fn Vm::define_(
  self : Vm,
  ident : @ast.Ident,
  value : @library.Value,
) -> Unit {
  self.bind(ident, @library.Binding::new(value.shared(), ident.span()))
}

///|
/// Insert a binding into the current scope.
pub fn Vm::bind(
  self : Vm,
  ident : @ast.Ident,
  binding : @library.Binding,
) -> Unit {
  // `if let Ok(value) = binding.read(silent guard) { self.trace_at(..) }`:
  // the silent read has no effect, so it is only made for the inspected
  // span (the guard is an allocation here).
  if self.inspects(ident.span()) {
    let guard_ = @library.BindingGuard::silent(self.engine.library.features)
    try binding.read(guard_, "") catch {
      _ => ()
    } noraise {
      value => self.trace(value)
    }
  }
  if ident.get() == "is" {
    self.engine.sink.warn(
      @library.SourceDiagnostic::warning_at(
        ident.span(),
        "`is` will likely become a keyword in future versions and will not be allowed as an identifier",
      ).with_hints([
        "rename this variable to avoid future errors", "try `is_` instead",
      ]),
    )
  }
  self.scopes.top.bind(ident.get(), binding) |> ignore
}

///|
/// Trace a value if the span is inspected.
pub fn Vm::trace_at(
  self : Vm,
  span : @syntax.Span,
  value : @library.Value,
) -> Unit {
  if self.inspects(span) {
    self.trace(value)
  }
}

///|
/// `self.inspected == Some(span)`, which every evaluated expression asks,
/// without the `Some` (an allocation for a span here).
fn Vm::inspects(self : Vm, span : @syntax.Span) -> Bool {
  match self.inspected {
    Some(inspected) => inspected == span
    None => false
  }
}

///|
/// Trace a value.
pub fn Vm::trace(self : Vm, value : @library.Value) -> Unit {
  let styles = self.context.try_styles().map(s => s.to_map())
  self.engine.sink.value(value.shared(), styles)
}

///|
/// A binding guard emitting warnings at `span`.
fn Vm::guard_at(self : Vm, span : @syntax.Span) -> @library.BindingGuard {
  self.engine.binding_guard(span)
}

///|
/// Provide a hint if the callee is a shadowed standard library function.
pub fn hint_if_shadowed_std(
  vm : Vm,
  callee : @ast.Expr,
  err : @library.HintedString,
) -> @library.HintedString {
  if callee is Ident(ident) {
    let name = ident.get()
    if vm.scopes.check_std_shadowed(name) {
      err.hint(
        "use `std.\{name}` to access the shadowed standard library function",
      )
    }
  }
  err
}
