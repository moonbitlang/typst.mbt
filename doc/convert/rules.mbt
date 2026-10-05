// Rules (docs/edsl-convert.md, section 4.5): set rules, show-set rules,
// show rules with host callbacks or value transformations, and selectors.

///|
/// `set path(args)` (section 4.5): the typed `SetX(..)` or the generic
/// `Set(path, named, positional=..)`.
fn Tr::set_rule(self : Tr, rule : @ast.SetRule, env : Env) -> Code raise Bail {
  if rule.condition() is Some(_) {
    raise Bail("set-if")
  }
  // Only element functions have set rules; anything else is an error of
  // the evaluator.
  guard self.global_path(rule.target(), env) is Some(path) &&
    self.lookup(path) is Some(Func(func)) &&
    func.to_element() is Some(_) else {
    raise Bail("set")
  }
  if find_elem(path) is Some(elem) &&
    elem.set &&
    self.try_sig(Sig::of_set(elem), path, rule.args(), env) is Some(code) {
    return code
  }
  let args = self.generic_args(path, rule.args(), env, true)
  self.hatch = true
  { code: "Set(\{mbt_str(path)}\{args})", total: false, }
}

///|
/// `show selector: transform` (section 4.5).
fn Tr::show_rule(self : Tr, rule : @ast.ShowRule, env : Env) -> Code raise Bail {
  let transform = unparen(rule.transform())
  guard rule.selector() is Some(selector) else {
    // `show: transform` applies a value to the rest of the sequence. (A
    // set rule or a closure has no value form.)
    guard !(transform is SetRule(_)) else { raise Bail("show-set") }
    let value = self.value(transform, env)
    return { code: "ShowWith::all(\{value.code})", total: false, }
  }
  let (selector, typed_view) = self.selector(selector, env)
  match transform {
    SetRule(set) => {
      let set = self.set_rule(set, env)
      self.typed += 1
      { code: "ShowSet(\{selector}, \{set.code})", total: false, }
    }
    Closure(closure) => self.show_closure(selector, typed_view, closure, env)
    _ => {
      let value = self.value(transform, env)
      { code: "ShowWith(\{selector}, \{value.code})", total: false, }
    }
  }
}

///|
/// The selector of a show rule: the EDSL expression, and whether its
/// matches are seen through a typed element view.
fn Tr::selector(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
) -> (String, Bool) raise Bail {
  match unparen(expr) {
    Str(string) => ("Select::literal(\{mbt_str(string.get())})", false)
    Label(label) => ("Select::label(\{mbt_str(label.get())})", false)
    FuncCall(call) => {
      let args = call.args().items().collect()
      // `regex("..")`.
      if self.global_path(call.callee(), env) is Some("regex") {
        guard self.lookup("regex") is Some(Type(_) | Func(_)) &&
          args.length() == 1 &&
          args[0] is Pos(Str(pattern)) else {
          raise Bail("selector")
        }
        return ("Select::regex(\{mbt_str(pattern.get())})", false)
      }
      // `path.where(field: value, ..)`.
      guard call.callee() is FieldAccess(access) &&
        access.field().get() == "where" &&
        self.element_path(access.target(), env) is Some(path) else {
        raise Bail("selector")
      }
      let fields : Array[(String, @ast.Expr)] = []
      for arg in args {
        guard arg is Named(named) else { raise Bail("selector") }
        let name = named.name().get()
        if fields.iter().any(f => f.0 == name) {
          raise Bail("selector")
        }
        fields.push((name, named.expr()))
      }
      if find_elem(path) is Some(elem) &&
        elem.select != "" &&
        self.typed_where(elem, fields, env) is Some(code) {
        return (code, true)
      }
      // The fields as values, in source order.
      let parts : Array[String] = []
      for field in fields {
        let value = self.value(field.1, env)
        parts.push("(\{mbt_str(field.0)}, \{value.code})")
      }
      self.hatch = true
      ("Select::elem(\{mbt_str(path)}, where_=[\{parts.join(", ")}])", false)
    }
    target => {
      guard self.element_path(target, env) is Some(path) else {
        raise Bail("selector")
      }
      match find_elem(path) {
        Some(elem) if elem.select != "" => ("Select::\{elem.select}()", true)
        _ => {
          self.hatch = true
          ("Select::elem(\{mbt_str(path)})", false)
        }
      }
    }
  }
}

///|
/// A global path that resolves to an element function.
fn Tr::element_path(self : Tr, expr : @ast.Expr, env : Env) -> String? {
  guard expr is (Ident(_) | FieldAccess(_)) &&
    self.global_path(expr, env) is Some(path) &&
    self.lookup(path) is Some(Func(func)) &&
    func.to_element() is Some(_) else {
    return None
  }
  Some(path)
}

///|
/// Whether the typed form of an expression against `ty` lowers to the raw
/// value of the Typst expression: `where` keeps its arguments as they are
/// and matching compares them with the stored fields, so a constructor
/// shorthand (`stroke: 1pt` as `Stroke(thickness=..)`) would select other
/// elements. These are boolean, integer and string literals, one numeric
/// literal and a named constant.
fn keeps_raw_value(expr : @ast.Expr, ty : String) -> Bool {
  match (ty, unparen(expr)) {
    ("Bool", Bool(_)) | ("Int64", Int(_)) | ("String", Str(_)) => true
    ("Length" | "Spacing" | "Sizing" | "Angle", Numeric(_)) => true
    ("Paint" | "Alignment" | "Dir", Ident(_)) => true
    ("FontWeight", Str(_) | Int(_)) => true
    _ => false
  }
}

///|
/// The typed selector `Select::<name>(field=value, ..)` of
/// `path.where(..)`: every field must be a selector field with a typed
/// form, and the arguments that are not total must keep their order (the
/// selector lowers its fields in declaration order).
fn Tr::typed_where(
  self : Tr,
  elem : ApiElem,
  fields : Array[(String, @ast.Expr)],
  env : Env,
) -> String? {
  let mark = self.mark()
  let order = elem.where_[:].to_owned()
  let parts : Array[String] = []
  let slots : Array[Slot] = []
  for field in fields {
    guard order.search(field.0) is Some(at) &&
      elem.param(field.0) is Some((_, name, _, ty)) &&
      keeps_raw_value(field.1, ty) &&
      self.typed(field.1, ty, env) is Some(code) else {
      self.rollback(mark)
      return None
    }
    slots.push({ major: at, minor: 0, total: code.total, })
    parts.push("\{name}=\{code.code}")
  }
  try check_order(slots) catch {
    Bail(_) => {
      self.rollback(mark)
      return None
    }
  } noraise {
    _ => ()
  }
  Some("Select::\{elem.select}(\{parts.join(", ")})")
}

///|
/// Whether `name` occurs as a word in the emitted code (an approximation
/// that only decides whether a callback names its parameter).
fn mentions(code : String, name : String) -> Bool {
  code.contains(name)
}

///|
/// A show rule whose transformation is a closure literal `x => body`
/// (section 4.5): a host callback, outside a callback only.
fn Tr::show_closure(
  self : Tr,
  selector : String,
  typed_view : Bool,
  closure : @ast.Closure,
  env : Env,
) -> Code raise Bail {
  // Exactly one positional identifier parameter: no named parameters
  // (their defaults are evaluated when the closure is created), no sink.
  let params = closure.params().children().collect()
  guard closure.name() is None &&
    params.length() == 1 &&
    params[0] is Pos(Normal(Ident(param))) else {
    raise Bail("show-closure")
  }
  // The EDSL does not create callbacks inside callbacks.
  if env.in_callback {
    raise Bail("show-in-callback")
  }
  let name = param.get()
  let variable = self.variable(name)
  // The typed form: a content block or an element constructor call that
  // translates without fragments, with the parameter bound to the view
  // and used only as content.
  let body = unparen(closure.body())
  if body is (ContentBlock(_) | FuncCall(_)) {
    let mark = self.mark()
    let before = self.fallbacks.length()
    let inner : Env = { vars: env.vars.copy(), in_callback: true, }
    inner.vars[name] = (variable, TView(typed_view))
    let result : Code? = match body {
      ContentBlock(block) => Some(self.stream(block.body(), inner))
      FuncCall(call) =>
        match self.global_path(call.callee(), inner) {
          Some(path) if path != "label" && path != "eval" =>
            self.typed_call(path, call.args(), inner)
          _ => None
        }
      _ => None
    }
    if result is Some(code) && self.fallbacks.length() == before {
      self.typed += 1
      let parameter = if mentions(code.code, variable) { variable } else { "_" }
      return {
        code: "Show(\{selector}, (\{parameter}, _) => \{code.code})",
        total: false,
      }
    }
    self.rollback(mark)
  }
  // The wrapper form: the Typst closure applied to the matched element in
  // a fragment, evaluated with the invocation's context. Its result must
  // not be a label, and no `break`/`continue` may escape it.
  let bound : Env = { vars: env.vars.copy(), in_callback: true, }
  bound.vars[name] = (variable, TView(typed_view))
  let node = closure.to_untyped()
  if !self.not_label(closure.body(), bound) ||
    escapes(closure.body().to_untyped(), false, true) {
    raise Bail("show-closure")
  }
  // A name for the argument that does not occur in the closure.
  let used : Map[String, Unit] = Map([])
  idents_of(node, used)
  let mut argument = "it"
  let mut counter = 0
  while used.contains(argument) || env.vars.contains(argument) {
    counter += 1
    argument = "it\{counter}"
  }
  let scope = [
    "(\{mbt_str(argument)}, Value::content(\{variable}))",
    ..self.scope([node], env),
  ]
  let text = "#(\{node.full_text()})(\{argument})"
  let fragment = self.markup_fragment(
    "show-closure",
    "callback",
    text,
    scope,
    recorded=node.full_text(),
  )
  self.typed += 1
  { code: "Show(\{selector}, (\{variable}, _) => \{fragment})", total: false, }
}
