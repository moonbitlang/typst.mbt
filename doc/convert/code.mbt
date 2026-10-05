// Embedded code of a markup stream (docs/edsl-convert.md, sections 4.2,
// 4.6 and 5): bindings, content blocks, context, and the expressions whose
// value is displayed.

///|
/// The value of a global path, resolved statically in the library's
/// scope (`None`: no such global).
fn Tr::lookup(self : Tr, path : String) -> @library.Value? {
  let mut value : @library.Value? = None
  for segment in path.split(".") {
    let segment = segment.to_owned()
    let scope = match value {
      None => self.lib.global.scope()
      Some(target) =>
        match target.scope() {
          Some(scope) => scope
          None => return None
        }
    }
    match scope.get(segment) {
      Some(binding) => value = Some(binding.value)
      None => return None
    }
  }
  value
}

///|
/// The qualified path of a global (section 4.2): an identifier that is no
/// user binding, or a field access on a path that is a module, a function
/// or a type (whose fields are its scope; a field access on any other
/// value is a field or a method of that value).
fn Tr::global_path(self : Tr, expr : @ast.Expr, env : Env) -> String? {
  match expr {
    Ident(ident) => {
      let name = ident.get()
      if env.vars.contains(name) {
        None
      } else {
        Some(name)
      }
    }
    FieldAccess(access) => {
      guard self.global_path(access.target(), env) is Some(prefix) else {
        return None
      }
      match self.lookup(prefix) {
        Some(Module(_) | Func(_) | Type(_)) =>
          Some(prefix + "." + access.field().get())
        _ => None
      }
    }
    _ => None
  }
}

///|
/// Translate an embedded code expression of a markup stream.
fn Tr::code_item(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
) -> Array[Op] raise Bail {
  match expr {
    LetBinding(binding) => self.let_binding(binding, env)
    SetRule(rule) => [Push(self.set_rule(rule, env))]
    ShowRule(rule) => [Push(self.show_rule(rule, env))]
    _ => [Push(self.content(expr, env))]
  }
}

///|
/// A literal with a static type (section 5): the MoonBit expression and
/// its type. Only literals whose evaluation is total and has no identity.
fn Tr::literal(self : Tr, expr : @ast.Expr, env : Env) -> (String, Ty)? {
  match expr {
    Parenthesized(p) => self.literal(p.expr(), env)
    Int(int) =>
      match int.get() {
        Ok(value) => Some((value.to_string(), TInt))
        Err(_) => None
      }
    Float(float) => Some((float_literal(float.get()), TFloat))
    Str(string) => Some((mbt_str(string.get()), TStr))
    Bool(bool) => Some((bool.get().to_string(), TBool))
    Numeric(numeric) => {
      let (value, unit) = numeric.get()
      match length_unit(unit) {
        Some(ctor) => Some(("\{ctor}(\{float_literal(value)})", TLength))
        None => None
      }
    }
    Unary(unary) =>
      // A sign on a number literal.
      match (unary.op(), unary.expr()) {
        (Neg, Int(int)) =>
          match int.get() {
            Ok(value) => Some(("-\{value}", TInt))
            Err(_) => None
          }
        (Neg, Float(float)) => Some(("-" + float_literal(float.get()), TFloat))
        (Pos, Int(_)) | (Pos, Float(_)) => self.literal(unary.expr(), env)
        _ => None
      }
    Ident(ident) =>
      // A named colour constant that is not shadowed.
      if !env.vars.contains(ident.get()) &&
        color_constant(ident.get()) is Some(case) {
        Some(("@doc.Paint::\{case}", TPaint))
      } else {
        None
      }
    _ => None
  }
}

///|
/// A float literal that MoonBit reads as the same `Double`.
fn float_literal(value : Double) -> String {
  let text = value.to_string()
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else if text.contains("n") || text.contains("N") || text.contains("i") {
    // NaN and infinities have no literal.
    "(\{text} : Double)"
  } else {
    text + ".0"
  }
}

///|
/// The case of `@doc.Length` for a numeric unit (`None`: not a length or
/// ratio).
fn length_unit(unit : @ast.NumericUnit) -> String? {
  match unit {
    Pt => Some("Pt")
    Mm => Some("Mm")
    Cm => Some("Cm")
    In => Some("In")
    Em => Some("Em")
    Percent => Some("Pct")
    Rad | Deg | Fr => None
  }
}

///|
/// The case of `@doc.Paint` for one of Typst's named colour constants.
fn color_constant(name : String) -> String? {
  match name {
    "black" => Some("Black")
    "gray" => Some("Gray")
    "silver" => Some("Silver")
    "white" => Some("White")
    "navy" => Some("Navy")
    "blue" => Some("Blue")
    "aqua" => Some("Aqua")
    "teal" => Some("Teal")
    "eastern" => Some("Eastern")
    "purple" => Some("Purple")
    "fuchsia" => Some("Fuchsia")
    "maroon" => Some("Maroon")
    "red" => Some("Red")
    "orange" => Some("Orange")
    "yellow" => Some("Yellow")
    "olive" => Some("Olive")
    "green" => Some("Green")
    "lime" => Some("Lime")
    _ => None
  }
}

///|
/// `let name = literal` (section 5): a MoonBit `let`, and the empty
/// content the evaluator pushes for the statement.
fn Tr::let_binding(
  self : Tr,
  binding : @ast.LetBinding,
  env : Env,
) -> Array[Op] raise Bail {
  let construct = construct_of(LetBinding(binding))
  guard binding.kind() is Normal(Normal(Ident(ident))) &&
    binding.init() is Some(init) else {
    raise Bail(construct)
  }
  let name = ident.get()
  if self.mutated.contains(name) {
    raise Bail("let-mutated")
  }
  guard self.literal(init, env) is Some((code, ty)) else {
    raise Bail(construct)
  }
  let variable = self.variable(name)
  env.vars[name] = (variable, ty)
  let annotation = match ty {
    TInt => "Int64"
    TFloat => "Double"
    TStr => "String"
    TBool => "Bool"
    TLength => "@doc.Length"
    TPaint => "@doc.Paint"
    TView(_) => abort("a view is no literal")
  }
  self.typed += 1
  [
    Stmt("let \{variable} : \{annotation} = \{code}"),
    Push({ code: "Seq([])", total: true, }),
  ]
}

///|
/// `context expr` (section 4.6): a host callback whose result is the
/// expression as a fragment, evaluated with the invocation's context.
fn Tr::contextual(
  self : Tr,
  contextual : @ast.Contextual,
  env : Env,
) -> Code raise Bail {
  let body = contextual.body()
  if env.in_callback ||
    escapes(body.to_untyped(), false, false) ||
    !self.not_label(body, env) {
    raise Bail("context")
  }
  let text = "#{" + body.to_untyped().full_text() + "}"
  let scope = self.scope([body.to_untyped()], env)
  let fragment = self.markup_fragment(
    "context",
    "callback",
    text,
    scope,
    recorded=contextual.to_untyped().full_text(),
  )
  self.typed += 1
  { code: "Context(_ => \{fragment})", total: false, }
}

///|
/// An expression whose value is displayed in a content stream (`#expr`),
/// or passed as a content argument.
fn Tr::content(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  match expr {
    ContentBlock(block) => self.stream(block.body(), env)
    Parenthesized(p) => self.content(p.expr(), env)
    Contextual(contextual) => self.contextual(contextual, env)
    // A string is displayed as text, which a MoonBit string lowers to.
    Str(string) => { code: mbt_str(string.get()), total: true, }
    Ident(ident) =>
      match env.vars.get(ident.get()) {
        Some((variable, TStr)) => { code: variable, total: true, }
        Some((variable, TView(_))) => { code: variable, total: true, }
        Some((variable, ty)) => {
          self.hatch = true
          { code: value_of(variable, ty), total: true, }
        }
        None => self.value(expr, env)
      }
    FuncCall(call) => self.call(call, env)
    _ => self.value(expr, env)
  }
}
