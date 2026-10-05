// `Value` forms (docs/edsl-convert.md, section 4.4): literals, array and
// dictionary literals of value forms (literal keys, no spreads), content
// blocks, global paths, calls of global paths and translated variables.
// Nothing else has a value form.

///|
/// The `Value` form of an expression (section 4.4), as an expression of
/// type `@doc.Value` (which is content in a stream: its display). A
/// value-level hatch (T2).
fn Tr::value(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  self.hatch = true
  match expr {
    Parenthesized(p) => self.value(p.expr(), env)
    None(_) => { code: "Value::none()", total: true, }
    Auto(_) => { code: "Value::auto()", total: true, }
    Bool(_) | Int(_) | Float(_) | Str(_) =>
      match self.literal(expr, env) {
        Some((code, ty)) => { code: value_of(code, ty), total: true, }
        None => raise Bail("literal")
      }
    Numeric(_) => { code: numeric_value(expr), total: true, }
    Unary(unary) =>
      // A sign on a number.
      match (unary.op(), unparen(unary.expr())) {
        (Neg | Pos, Int(_) | Float(_)) =>
          match self.literal(expr, env) {
            Some((code, ty)) => { code: value_of(code, ty), total: true, }
            None => raise Bail("operator")
          }
        (Neg | Pos, Numeric(_)) => { code: numeric_value(expr), total: false, }
        // Typst's negation, applied when the value is lowered.
        (Neg, _) => {
          let operand = self.value(unary.expr(), env)
          self.hatch = true
          { code: "Value::neg(\{operand.code})", total: false, }
        }
        _ => raise Bail("operator")
      }
    // The description calls `label`.
    Label(label) =>
      { code: "Value::label(\{mbt_str(label.get())})", total: false, }
    Array(array) => {
      let parts : Array[String] = []
      let mut total = true
      for item in array_items(array) {
        let value = self.value(item, env)
        total = total && value.total
        parts.push(value.code)
      }
      { code: "Value::array([\{parts.join(", ")}])", total, }
    }
    Dict(dict) => {
      let parts : Array[String] = []
      let keys : Array[String] = []
      let mut total = true
      for item in dict.items() {
        // An identifier or a string literal as the key; a computed key
        // has no form.
        let (key, expr) = match item {
          Named(named) => (named.name().get(), named.expr())
          Keyed(keyed) =>
            match keyed.key() {
              Str(string) => (string.get(), keyed.expr())
              _ => raise Bail("dictionary-key")
            }
          Spread(_) => raise Bail("spread")
        }
        // A duplicate key is an error of the evaluator.
        if keys.contains(key) {
          raise Bail("dictionary-key")
        }
        keys.push(key)
        let value = self.value(expr, env)
        total = total && value.total
        parts.push("(\{mbt_str(key)}, \{value.code})")
      }
      { code: "Value::dict([\{parts.join(", ")}])", total, }
    }
    ContentBlock(block) => {
      let content = self.stream(block.body(), env)
      { code: "Value::content(\{content.code})", total: content.total, }
    }
    Ident(ident) =>
      match env.vars.get(ident.get()) {
        Some((variable, ty)) => { code: value_of(variable, ty), total: true, }
        None => self.global(expr, env, "unknown-name")
      }
    FieldAccess(_) => self.global(expr, env, "field-access")
    FuncCall(call) =>
      match self.function_method(call, env) {
        Some((method_name, receiver)) => {
          // `f.with(..)`, `f.where(..)` on a function of the library: the
          // method_name of the type `function` with the function as its
          // first argument, which is how Typst calls it.
          let path = "function." + method_name
          let args = self.generic_args(path, call.args(), env, false)
          let receiver = "Value::global(\{mbt_str(receiver)})"
          let args = match args.strip_prefix(", positional=[") {
            Some(rest) => ", positional=[\{receiver}, \{rest}"
            None => ", positional=[\{receiver}]\{args}"
          }
          self.hatch = true
          { code: "Value::call(\{mbt_str(path)}\{args})", total: false, }
        }
        None => {
          let path = self.call_path(call, env)
          self.call_value(path, call.args(), env)
        }
      }
    Closure(_) => raise Bail("closure")
    // Arithmetic is Typst's operator, applied when the value is lowered
    // (left operand first, as in Typst). Comparisons, `and`/`or` (which
    // do not evaluate both operands), `in` and assignments have no form.
    Binary(binary) => {
      let method_name = match binary.op() {
        Add => "add"
        Sub => "sub"
        Mul => "mul"
        Div => "div"
        _ => raise Bail("operator")
      }
      let lhs = self.value(binary.lhs(), env)
      let rhs = self.value(binary.rhs(), env)
      self.hatch = true
      { code: "Value::\{method_name}(\{lhs.code}, \{rhs.code})", total: false, }
    }
    _ => raise Bail(construct_of(expr))
  }
}

///|
/// A global path that resolves in the library: `Value::global(path)`.
fn Tr::global(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
  otherwise : String,
) -> Code raise Bail {
  guard self.global_path(expr, env) is Some(path) &&
    self.lookup(path) is Some(_) else {
    raise Bail(otherwise)
  }
  // Reading a binding can warn (deprecations); a named colour constant
  // does not.
  {
    code: "Value::global(\{mbt_str(path)})",
    total: color_constant(path) is Some(_),
  }
}

///|
/// A numeric literal with a unit as a value. A sign is the facade's
/// negation for lengths and ratios; fractions and angles have none.
fn numeric_value(expr : @ast.Expr) -> String raise Bail {
  match unparen(expr) {
    Numeric(numeric) =>
      match numeric.get() {
        (value, Fr) => "Value::fr(\{number(value)})"
        (_, Deg) | (_, Rad) => "Value::angle(\{angle_literal(expr)})"
        _ => "Value::length(\{signed_length(expr)})"
      }
    _ => "Value::length(\{signed_length(expr)})"
  }
}

///|
/// A length literal with its signs as the facade's negations.
fn signed_length(expr : @ast.Expr) -> String raise Bail {
  match unparen(expr) {
    Numeric(numeric) => {
      let (value, unit) = numeric.get()
      guard length_unit(unit) is Some(ctor) else { raise Bail("operator") }
      "\{ctor}(\{number(value)})"
    }
    Unary(unary) =>
      match unary.op() {
        Neg => "Neg(\{signed_length(unary.expr())})"
        Pos => signed_length(unary.expr())
        Not => raise Bail("operator")
      }
    _ => raise Bail("operator")
  }
}

///|
/// `f.with(..)` or `f.where(..)` where `f` is a global path that is a
/// function and the method_name is not a member of its scope: the method_name name
/// and the path of the function. (A proven receiver type and an audited
/// method_name, docs/edsl-convert.md, section 4.4.)
fn Tr::function_method(
  self : Tr,
  call : @ast.FuncCall,
  env : Env,
) -> (String, String)? {
  guard call.callee() is FieldAccess(access) else { return None }
  let method_name = access.field().get()
  guard method_name == "with" || method_name == "where" else { return None }
  guard self.global_path(access.target(), env) is Some(receiver) &&
    self.lookup(receiver) is Some(Func(_)) &&
    self.lookup(receiver + "." + method_name) is None else {
    return None
  }
  Some((method_name, receiver))
}
