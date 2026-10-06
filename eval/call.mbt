// Port of `typst-eval/src/call.rs`.

///|
fn eval_func_call(
  vm : Vm,
  call : @ast.FuncCall,
) -> @library.Value raise @library.SourceError {
  let span = call.span()
  let callee = call.callee()
  @library.at(span, () => vm.engine.route.check_call_depth())

  // Try to evaluate as a call to an associated function or field.
  if callee is FieldAccess(access_expr) {
    let target_expr = access_expr.target()
    let field = access_expr.field()
    let (target, maybe_args) = if is_mutating_method(field.get()) {
      match maybe_resolve_mutating(vm, target_expr, field, call.args(), span) {
        Ok(value) => return value
        Err((target, args)) => (target, Some(args))
      }
    } else {
      (eval_expr(vm, target_expr), None)
    }
    let args = () => {
      match maybe_args {
        Some(args) => args
        None => eval_args(vm, call.args()).spanned(span)
      }
    }
    match
      eval_field_callee(
        vm,
        access_expr.to_untyped(),
        field.get(),
        field.span(),
        target,
        false,
      ) {
      Func(func) => call_func(vm, func, args(), span)
      Method(func, target) => {
        let args = args()
        args.insert(0, target_expr.span(), target)
        call_func(vm, func, args, span)
      }
      NonFunc(_, err) =>
        raise @library.SourceError([err.into_error_at(callee.span())])
    }
  } else {
    // Function call order: we evaluate the callee before the arguments.
    let callee_value = eval_expr(vm, callee)
    let func : @library.Func = @library.at(callee.span(), () => {
      callee_value.cast() catch {
        @library.HintedError(err) =>
          raise @library.HintedError(hint_if_shadowed_std(vm, callee, err))
      }
    })
    let args = eval_args(vm, call.args()).spanned(span)
    call_func(vm, func, args, span)
  }
}

///|
fn eval_math_call(
  vm : Vm,
  math_call : @ast.MathCall,
) -> @library.Value raise @library.SourceError {
  let span = math_call.span()
  let callee = math_call.callee()
  let mut target_span = @syntax.Span::detached()
  @library.at(span, () => vm.engine.route.check_call_depth())
  let result = match callee {
    MathIdent(ident) => {
      let callee_value = eval_math_ident(vm, ident)
      vm.trace_at(ident.span(), callee_value)
      try callee_value.cast() catch {
        @library.HintedError(err) => FieldCallee::NonFunc(callee_value, err)
      } noraise {
        func => FieldCallee::Func(func)
      }
    }
    MathFieldAccess(access_expr) => {
      let target_expr = access_expr.target()
      target_span = target_expr.span()
      let field = access_expr.field()
      let target = eval_math_access(vm, target_expr)
      if is_mutating_method(field.get()) && target is (Array(_) | Dict(_)) {
        @library.bail_at(span, "cannot call mutating methods in math", hints=[
          "try using code mode to call the method: `#\{math_call.to_untyped().full_text()}`",
        ])
      }
      eval_field_callee(
        vm,
        access_expr.to_untyped(),
        field.get(),
        field.span(),
        target,
        true,
      )
    }
  }
  let args = math_call.args()
  match result {
    Func(func) => {
      let args = eval_math_args(vm, args).spanned(span)
      call_func(vm, func, args, span)
    }
    Method(func, target) => {
      let args = eval_math_args(vm, args).spanned(span)
      args.insert(0, target_span, target)
      call_func(vm, func, args, span)
    }
    NonFunc(callee_value, _) => {
      let parens = unparse_math_args(vm, args, callee)
      Content(callee_value.display().spanned(callee.span()).add(parens))
    }
  }
}

///|
/// Call a function, tracing errors.
fn call_func(
  vm : Vm,
  func : @library.Func,
  args : @library.Args,
  span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  let func = func.spanned(span)
  trace_call(vm, func.name(), span, () => func.call(vm.engine, vm.context, args))
}

///|
/// Run `f`, adding a call trace point to its errors.
fn[T] trace_call(
  vm : Vm,
  name : String?,
  span : @syntax.Span,
  f : () -> T raise @library.SourceError,
) -> T raise @library.SourceError {
  @library.trace(
    s => @library.world_range(vm.engine.world, s),
    () => Call(name),
    span,
    f,
  )
}

///|
/// Resolve a call to a mutating method, either calling it directly or
/// returning the target and arguments.
fn maybe_resolve_mutating(
  vm : Vm,
  target : @ast.Expr,
  field : @ast.Ident,
  args : @ast.Args,
  span : @syntax.Span,
) -> Result[@library.Value, (@library.Value, @library.Args)] raise @library.SourceError {
  let args = eval_args(vm, args).spanned(span)
  let place = access(vm, target)
  match (place.get)() {
    Dict(_) as target if !is_dict_mutating_method(field.get()) =>
      Err((target.shared(), args))
    Array(_) | Dict(_) =>
      Ok(
        trace_call(vm, Some(field.get()), span, () => {
          call_method_mut(place, field.get(), args, span)
        }),
      )
    target => Err((target.shared(), args))
  }
}

///|
/// The callee of a field access call.
priv enum FieldCallee {
  /// A method call where the target is passed as the first argument.
  Method(@library.Func, @library.Value)
  /// A normal function call.
  Func(@library.Func)
  /// A non-function value (an error, except in math).
  NonFunc(@library.Value, @library.HintedString)
}

///|
/// Evaluate the callee of a field access call.
fn eval_field_callee(
  vm : Vm,
  access_node : @syntax.SyntaxNode,
  field : String,
  field_span : @syntax.Span,
  target : @library.Value,
  in_math : Bool,
) -> FieldCallee raise @library.SourceError {
  let guard_ = vm.guard_at(field_span)
  let mut is_method_call = false
  let callee_value = match target.ty().scope().get(field) {
    Some(method) => {
      is_method_call = true
      let ty = target.ty().short_name()
      @library.at(field_span, () => {
        method.read(guard_, "call method `\{field}` on \{ty}")
      })
    }
    None =>
      match target {
        Content(content) if content.elem().scope().get(field) is Some(method) => {
          is_method_call = true
          @library.at(field_span, () => {
            method.read(guard_, "call method `\{field}` on content")
          })
        }
        Symbol(_) | Type(_) | Module(_) =>
          @library.at(field_span, () => target.field(field, guard_))
        Func(func) =>
          try target.field(field, guard_) catch {
            @library.HintedError(err) =>
              if func.to_element() is Some(element) &&
                element.settable_field_accessor(field) is Some(accessor) {
                let styles = @library.at(field_span, () => {
                  vm.context.get_styles()
                })
                let callee_value = accessor(styles)
                @library.bail_diag(
                  disallowed_field_call_error(
                    callee_value, access_node, field, target, in_math,
                  ),
                )
              } else {
                raise @library.SourceError([err.into_error_at(field_span)])
              }
          } noraise {
            v => v
          }
        _ =>
          try target.field(field, guard_) catch {
            _ => {
              let (kind, name) = element_or_type_with_name(target)
              @library.bail_at(
                access_node.span(),
                "\{kind} \{name} has no method `\{field}`",
              )
            }
          } noraise {
            callee_value =>
              @library.bail_diag(
                disallowed_field_call_error(
                  callee_value, access_node, field, target, in_math,
                ),
              )
          }
      }
  }
  vm.trace_at(access_node.span(), callee_value)
  try callee_value.cast() catch {
    @library.HintedError(err) => NonFunc(callee_value, err)
  } noraise {
    func => if is_method_call { Method(func, target) } else { Func(func) }
  }
}

///|
/// Produce an error when we cannot call a field.
fn disallowed_field_call_error(
  callee_value : @library.Value,
  access_node : @syntax.SyntaxNode,
  field : String,
  target : @library.Value,
  in_math : Bool,
) -> @library.SourceDiagnostic {
  let is_dict = target is Dict(_)
  let is_named = target is Args(_)
  let err = if is_dict {
    @library.SourceDiagnostic::error_at(
      access_node.span(),
      "cannot directly call dictionary keys as functions",
    )
  } else if is_named {
    @library.SourceDiagnostic::error_at(
      access_node.span(),
      "cannot directly call named argument fields as functions",
    )
  } else {
    let (kind, name) = element_or_type_with_name(target)
    @library.SourceDiagnostic::error_at(
      access_node.span(),
      "`\{field}` is not a valid method for \{kind} `\{name}`",
    )
  }
  let is_func = try (callee_value.cast() : @library.Func) catch {
    _ => false
  } noraise {
    _ => true
  }
  if is_func {
    let code = if in_math { "use code mode and " } else { "" }
    let hash = if in_math { "#" } else { "" }
    err.hint(
      "to call the stored function, \{code}wrap the field access in parentheses: `\{hash}(\{access_node.full_text()})(..)`",
    )
  } else if in_math {
    err.hint("try adding a space before the parentheses")
  } else {
    let what = if is_dict {
      "key"
    } else if is_named {
      "argument"
    } else {
      "field"
    }
    err.hint(
      "to access the `\{field}` \{what}, remove the function arguments: `\{access_node.full_text()}`",
    )
  }
  if is_dict {
    err.hint(
      "dictionary keys cannot be used with method syntax as keys could conflict with built-in method names",
    )
  } else if is_named {
    err.hint(
      "named arguments cannot be used with method syntax as argument names could conflict with built-in method names",
    )
  }
  err
}

///|
/// Check if the expression is in a math context and return the kind and name.
fn element_or_type_with_name(value : @library.Value) -> (String, String) {
  match value {
    Content(content) => ("element", content.elem().name())
    _ => ("type", value.ty().long_name())
  }
}

///|
/// Evaluate function call arguments.
fn eval_args(
  vm : Vm,
  args : @ast.Args,
) -> @library.Args raise @library.SourceError {
  let items : Array[@library.Arg] = []
  for arg in args.items() {
    let span = arg.span()
    match arg {
      Pos(expr) =>
        items.push({
          span,
          name: None,
          value: { v: eval_expr(vm, expr), span: expr.span(), },
        })
      Named(named) => {
        let expr = named.expr()
        items.push({
          span,
          name: Some(named.name().get()),
          value: { v: eval_expr(vm, expr), span: expr.span(), },
        })
      }
      Spread(spread) =>
        match eval_expr(vm, spread.expr()) {
          None => ()
          Array(array) =>
            for value in array.items {
              items.push({
                span,
                name: None,
                value: { v: value.shared(), span, },
              })
            }
          Dict(dict) =>
            for key, value in dict.map {
              items.push({
                span,
                name: Some(key),
                value: { v: value.shared(), span, },
              })
            }
          Args(args) => items.append(args.items)
          v => @library.bail_at(spread.span(), "cannot spread \{v.ty()}")
        }
    }
  }
  { span: @syntax.Span::detached(), items, }
}

///|
/// Evaluate math function call arguments (with 2D arrays from semicolons).
fn eval_math_args(
  vm : Vm,
  args : @ast.MathArgs,
) -> @library.Args raise @library.SourceError {
  let named : Array[@library.Arg] = []
  let pos : Array[@library.Arg] = []
  let mut two_dim_start : Int? = None
  let drain_into_array = (start : Int, span : @syntax.Span) => {
    let array = pos[start:].iter().map(arg => arg.value.v).collect()
    pos.truncate(start)
    pos.push({
      span,
      name: None,
      value: { v: Array(@library.Arr::from_array(array)), span, },
    })
  }
  for item in args.arg_items() {
    let arg = item.arg
    let span = arg.span()
    match arg {
      Pos(expr) =>
        pos.push({
          span,
          name: None,
          value: { v: eval_expr(vm, expr), span: expr.span(), },
        })
      Named(named_arg) => {
        let expr = named_arg.expr()
        named.push({
          span,
          name: Some(named_arg.name().get()),
          value: { v: eval_expr(vm, expr), span: expr.span(), },
        })
      }
      Spread(spread) =>
        match eval_expr(vm, spread.expr()) {
          None => ()
          Array(array) =>
            for value in array.items {
              pos.push({
                span,
                name: None,
                value: { v: value.shared(), span, },
              })
            }
          Dict(dict) =>
            for key, value in dict.map {
              named.push({
                span,
                name: Some(key),
                value: { v: value.shared(), span, },
              })
            }
          Args(a) =>
            for a in a.items {
              if a.name is None {
                pos.push(a)
              } else {
                named.push(a)
              }
            }
          v => @library.bail_at(spread.span(), "cannot spread \{v.ty()}")
        }
    }
    if item.ends_in_semicolon {
      drain_into_array(two_dim_start.unwrap_or(0), args.span())
      two_dim_start = Some(pos.length())
    }
  }
  if two_dim_start is Some(start) && start != pos.length() {
    drain_into_array(start, args.span())
  }
  named.append(pos)
  { span: @syntax.Span::detached(), items: named, }
}

///|
/// Turn math arguments back into content for non-function callees.
fn unparse_math_args(
  vm : Vm,
  args : @ast.MathArgs,
  callee : @ast.MathAccess,
) -> @library.Content raise @library.SourceError {
  let body = []
  let errors = []
  for item in args.content_items() {
    match item {
      Space(space) =>
        body.push(space_content(space.had_newline()).spanned(space.span()))
      Comma(c, node)
      | Semicolon(c, node)
      | LeftParen(c, node)
      | RightParen(c, node) =>
        body.push(
          @library.SymbolElem::packed(c.to_string()).spanned(node.span()),
        )
      Arg(Pos(expr)) =>
        body.push(eval_expr(vm, expr).display().spanned(expr.span()))
      Arg(Named(named)) => {
        let name = callee.to_untyped().full_text()
        let fixed = named.to_untyped().full_text().replace(old=":", new="\\:")
        let error = @library.SourceDiagnostic::error_at(
          named.span(),
          "named-argument syntax can only be used with functions",
        )
        error.spanned_hint(
          "`\{name}` is not a function",
          @syntax.DiagSpan::from_span(callee.span()),
        )
        error.hint("to render the colon as text, escape it: `\{fixed}`")
        errors.push(error)
      }
      Arg(Spread(spread)) => {
        let name = callee.to_untyped().full_text()
        let fixed = spread.to_untyped().full_text().replace(old="..", new=".. ")
        let error = @library.SourceDiagnostic::error_at(
          spread.span(),
          "spread-argument syntax can only be used with functions",
        )
        error.spanned_hint(
          "`\{name}` is not a function",
          @syntax.DiagSpan::from_span(callee.span()),
        )
        error.hint("to render the dots as text, add a space: `\{fixed}`")
        errors.push(error)
      }
    }
  }
  if !errors.is_empty() {
    raise @library.SourceError(errors)
  }
  @library.Content::new(@library.lr_elem(), [
    (@library.lr_elem_body, Content(@library.SequenceElem::new(body))),
  ]).spanned(args.span())
}

///|
fn eval_closure_expr(
  vm : Vm,
  closure : @ast.Closure,
) -> @library.Value raise @library.SourceError {
  // Evaluate default values of named parameters.
  let defaults = []
  for param in closure.params().children() {
    if param is Named(named) {
      defaults.push(eval_expr(vm, named.expr()))
    }
  }

  // Collect captured variables.
  let visitor = CapturesVisitor::new(Some(vm.scopes), Function)
  visitor.visit(closure.to_untyped())
  let captured = visitor.finish()

  // Define the closure.
  let num_pos_params = closure
    .params()
    .children()
    .filter(p => p is Pos(_))
    .count()
  let closure_data : @library.Closure = {
    node: Closure(closure.to_untyped()),
    defaults,
    captured,
    num_pos_params,
    hash: @library.LazyFingerprint::new(),
  }
  Func(@library.Func::closure(closure_data).spanned(closure.params().span()))
}

///|
/// Call the function in the context with the arguments.
pub fn eval_closure(
  func : @library.Func,
  closure : @library.Closure,
  engine : @library.Engine,
  context : @library.Context,
  args : @library.Args,
) -> @library.Value raise @library.SourceError {
  let (name, params, body) : (@ast.Ident?, @ast.Params?, @ast.Expr) = match
    closure.node {
    Closure(node) => {
      let c = @ast.Closure::from_untyped(node).unwrap()
      (c.name(), Some(c.params()), c.body())
    }
    Context(node) => (None, None, @ast.Expr::from_untyped(node).unwrap())
  }

  // Don't leak the scopes from the call site. Instead, we use the scope of
  // captured variables we collected earlier.
  let scopes = @library.Scopes::new(None)
  scopes.top = closure.captured.copy()

  // Prepare the engine.
  let engine = engine.with_route(@library.Route::extend_(engine.route))

  // Prepare VM.
  let vm = Vm::new(engine, context, scopes, body.span())

  // Provide the closure itself for recursive calls.
  if name is Some(name) {
    vm.define(name, Func(func))
  }
  let num_pos_args = args.to_pos().len()
  let sink_size = num_pos_args - closure.num_pos_params
  let mut sink : @ast.Ident?? = None
  let mut sink_pos_values : Array[@library.Arg]? = None
  let mut default_index = 0
  if params is Some(params) {
    for p in params.children() {
      match p {
        Pos(Normal(Ident(ident))) => vm.define(ident, args.expect(ident.get()))
        Pos(pattern) =>
          destructure(vm, pattern, args.expect("pattern parameter"))
        Spread(spread) => {
          sink = Some(spread.sink_ident())
          if sink_size >= 0 {
            sink_pos_values = Some(args.consume(sink_size))
          }
        }
        Named(named) => {
          let name = named.name()
          let default = closure.defaults[default_index]
          default_index += 1
          let value = match args.named(name.get()) {
            Some(v) => v
            None => default.shared()
          }
          vm.define(name, value)
        }
      }
    }
  }
  if sink is Some(sink) {
    // Remaining args are captured regardless of whether the sink is named.
    let remaining_args = args.take()
    if sink is Some(sink_name) {
      if sink_pos_values is Some(values) {
        remaining_args.items.append(values)
      }
      vm.define(sink_name, Args(remaining_args))
    }
  }

  // Ensure all arguments have been used.
  args.finish()

  // Handle control flow.
  let output = eval_expr(vm, body)
  match vm.flow {
    Some(Return(_, Some(explicit), _)) => return explicit
    Some(Return(_, None, _)) => ()
    Some(flow) => @library.bail_diag(flow.forbidden())
    None => ()
  }
  output
}

///|
/// A visitor that determines which variables to capture for a closure.
pub struct CapturesVisitor {
  priv external : @library.Scopes?
  priv internal : @library.Scopes
  priv captures : @library.Scope
  priv capturer : @library.Capturer
}

///|
/// Create a new visitor for the given external scopes.
pub fn CapturesVisitor::new(
  external : @library.Scopes?,
  capturer : @library.Capturer,
) -> CapturesVisitor {
  {
    external,
    internal: @library.Scopes::new(None),
    captures: @library.Scope::new(),
    capturer,
  }
}

///|
/// Return the scope of captured variables.
pub fn CapturesVisitor::finish(self : CapturesVisitor) -> @library.Scope {
  self.captures
}

///|
/// Visit any node and collect all captured variables.
pub fn CapturesVisitor::visit(
  self : CapturesVisitor,
  node : @syntax.SyntaxNode,
) -> Unit {
  match @ast.Expr::from_untyped(node) {
    // Every identifier is a potential variable that we need to capture.
    Some(Ident(ident)) => self.capture(ident.get(), false)
    Some(MathIdent(ident)) => self.capture(ident.get(), true)
    // Code and content blocks create a scope.
    Some(CodeBlock(_) | ContentBlock(_)) => {
      self.internal.enter()
      for child in node.children() {
        self.visit(child)
      }
      self.internal.exit()
    }
    // Don't capture the field of a field access.
    Some(FieldAccess(access)) => self.visit(access.target().to_untyped())
    Some(MathFieldAccess(access)) => self.visit(access.target().to_untyped())
    // A closure contains parameter bindings, which are bound before the
    // body is evaluated. Care must be taken so that the default values of
    // named parameters cannot access previous parameter bindings.
    Some(Closure(expr)) => {
      for param in expr.params().children() {
        if param is Named(named) {
          self.visit(named.expr().to_untyped())
        }
      }
      self.internal.enter()
      if expr.name() is Some(name) {
        self.bind(name)
      }
      for param in expr.params().children() {
        match param {
          Pos(pattern) =>
            for ident in pattern.bindings() {
              self.bind(ident)
            }
          Named(named) => self.bind(named.name())
          Spread(spread) =>
            if spread.sink_ident() is Some(ident) {
              self.bind(ident)
            }
        }
      }
      self.visit(expr.body().to_untyped())
      self.internal.exit()
    }
    // A let expression contains a binding, but that binding is only active
    // after the body is evaluated.
    Some(LetBinding(expr)) => {
      if expr.init() is Some(init) {
        self.visit(init.to_untyped())
      }
      for ident in expr.kind().bindings() {
        self.bind(ident)
      }
    }
    // A for loop contains one or two bindings in its pattern. These are
    // active after the iterable is evaluated but before the body is
    // evaluated.
    Some(ForLoop(expr)) => {
      self.visit(expr.iterable().to_untyped())
      self.internal.enter()
      for ident in expr.pattern().bindings() {
        self.bind(ident)
      }
      self.visit(expr.body().to_untyped())
      self.internal.exit()
    }
    // An import contains items, but these are active only after the path is
    // evaluated.
    Some(ModuleImport(expr)) => {
      self.visit(expr.source().to_untyped())
      if expr.imports() is Some(Items(items)) {
        for item in items.iter() {
          self.bind(item.bound_name())
        }
      }
    }
    _ => {
      // Never capture the name part of a named pair.
      if @ast.Named::from_untyped(node) is Some(named) {
        self.visit(named.expr().to_untyped())
        return
      }
      // Everything else is traversed from left to right.
      for child in node.children() {
        self.visit(child)
      }
    }
  }
}

///|
/// Bind a new internal variable.
fn CapturesVisitor::bind(self : CapturesVisitor, ident : @ast.Ident) -> Unit {
  self.internal.top.bind(ident.get(), @library.Binding::detached(None))
  |> ignore
}

///|
/// Capture a variable if it isn't internal.
fn CapturesVisitor::capture(
  self : CapturesVisitor,
  ident : String,
  in_math : Bool,
) -> Unit {
  if (try self.internal.get_binding(ident) catch {
      _ => false
    } noraise {
      _ => true
    }) {
    return
  }
  if self.captures.get(ident) is Some(_) {
    return
  }
  let binding = match self.external {
    Some(external) => {
      let found = try {
        if in_math {
          external.get_binding_in_math(ident)
        } else {
          external.get_binding(ident)
        }
      } catch {
        _ => return
      }
      found.capture(self.capturer)
    }
    None => @library.Binding::detached(None)
  }
  self.captures.bind(ident, binding) |> ignore
}
