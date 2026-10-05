// Markup expressions (docs/edsl-convert.md, section 4.1): one description
// per evaluator expression, lowering to what `eval_expr` produces.

///|
/// A typed expression: counts it.
fn Tr::typed_code(self : Tr, code : String, total : Bool) -> Array[Op] {
  self.typed += 1
  [Push({ code, total, })]
}

///|
/// Translate one expression of a markup stream. Raises if it cannot be
/// typed.
fn Tr::item(self : Tr, expr : @ast.Expr, env : Env) -> Array[Op] raise Bail {
  match expr {
    // A plain string would share the location of its array with its
    // siblings; every text gets its own, so diagnostics at two texts stay
    // apart (the engine deduplicates by location and message).
    Text(text) => [Word(text.get())]
    Linebreak(_) => self.typed_code("Linebreak()", true)
    Parbreak(_) => [Break]
    Escape(escape) =>
      self.typed_code("Symbol(\{mbt_str(escape.get().to_string())})", true)
    Shorthand(shorthand) =>
      self.typed_code("Symbol(\{mbt_str(shorthand.get().to_string())})", true)
    SmartQuote(quote) => [Quote(quote.double())]
    Strong(strong) => {
      let body = self.stream(strong.body(), env)
      self.typed_code("Strong(\{body.code})", body.total)
    }
    Emph(emph) => {
      let body = self.stream(emph.body(), env)
      self.typed_code("Emph(\{body.code})", body.total)
    }
    Raw(raw) => {
      let lines = raw.lines().map(line => line.get()).collect()
      // The evaluator's raw keeps its lines: a raw without lines is not
      // `raw("")`, which has one empty line.
      if lines.is_empty() {
        raise Bail("raw-empty")
      }
      let lang = match raw.lang() {
        Some(lang) => ", lang=\{mbt_str(lang.get())}"
        None => ""
      }
      self.typed_code(
        "Raw(\{mbt_str(lines.join("\n"))}, block=\{raw.block()}\{lang})",
        true,
      )
    }
    Link(link) => self.typed_code("Link(Url(\{mbt_str(link.get())}))", false)
    Label(label) => {
      // The EDSL attaches a label-valued inserted expression with the
      // evaluator's rule and warnings; the call has a location of its own.
      self.hatch = true
      [
        Push({
          code: "Call(\"label\", positional=[Value::str(\{mbt_str(label.get())})])",
          total: false,
        }),
      ]
    }
    Ref(reference) => {
      let target = mbt_str(reference.target())
      match reference.supplement() {
        Some(block) => {
          let supplement = self.stream(block.body(), env)
          self.typed_code(
            "Ref(\{target}, supplement=Supplement(\{supplement.code}))",
            supplement.total,
          )
        }
        None => self.typed_code("Ref(\{target})", true)
      }
    }
    Heading(heading) => {
      let body = self.stream(heading.body(), env)
      self.typed_code(
        "Heading(\{body.code}, depth=\{heading.depth()})",
        body.total,
      )
    }
    ListItem(item) => {
      let body = self.stream(item.body(), env)
      self.typed_code("ListItem(\{body.code})", body.total)
    }
    EnumItem(item) => {
      let body = self.stream(item.body(), env)
      let number = match item.number() {
        Some(number) => ", number=\{number}"
        None => ""
      }
      self.typed_code("EnumItem(\{body.code}\{number})", body.total)
    }
    TermItem(item) => {
      let term = self.stream(item.term(), env)
      let description = self.stream(item.description(), env)
      self.typed_code(
        "TermsItem(\{term.code}, \{description.code})",
        term.total && description.total,
      )
    }
    Equation(equation) => self.equation(equation, env)
    _ => self.code_item(expr, env)
  }
}

///|
/// An equation: the math string of its body, with the translated
/// variables it mentions as its scope.
fn Tr::equation(self : Tr, equation : @ast.Equation, env : Env) -> Array[Op] {
  let body = equation.body().to_untyped()
  let source = body.full_text()
  let scope = self.scope([body], env)
  let block = if equation.block() { ", block=true" } else { "" }
  let scope = if scope.is_empty() {
    ""
  } else {
    self.hatch = true
    ", scope=[\{scope.join(", ")}]"
  }
  self.math = true
  self.typed_code("Equation(\{mbt_str(source)}\{block}\{scope})", false)
}

///|
/// The global functions that are audited never to return a label (section
/// 6.1), besides the element functions.
let non_label_functions : Array[String] = [
  "lorem", "rgb", "luma", "counter", "state", "repr", "str", "int", "float", "range",
  "datetime", "stroke", "gradient.linear", "gradient.radial", "gradient.conic", "tiling",
]

///|
/// Whether a call is audited never to return a label: by the function it
/// resolves to, or by its method_name and the type of its receiver.
fn Tr::call_not_label(self : Tr, call : @ast.FuncCall, env : Env) -> Bool {
  match self.global_path(call.callee(), env) {
    Some(path) =>
      non_label_functions.contains(path) ||
      (match self.lookup(path) {
        Some(Func(func)) => func.to_element() is Some(_)
        _ => false
      })
    None => {
      guard call.callee() is FieldAccess(access) else { return false }
      let method_name = access.field().get()
      match access.target() {
        // Every method_name of a string but `at` (which returns its default)
        // returns a string, a number, a boolean, an array or dictionary
        // of those, or `none`.
        Str(_) => method_name != "at"
        FuncCall(receiver) =>
          match self.global_path(receiver.callee(), env) {
            // Not `display`: it forwards a numbering function's result.
            Some("counter") =>
              ["step", "update", "get", "at", "final"].contains(method_name)
            Some("state") => method_name == "update"
            _ => false
          }
        _ => false
      }
    }
  }
}

///|
/// Whether an expression is proven, by its form, not to evaluate to a
/// label (section 6.1): only then may it be a fragment of its own, since
/// the evaluator attaches a label result to the content before it.
fn Tr::not_label(self : Tr, expr : @ast.Expr, env : Env) -> Bool {
  // The names the expression binds itself (`let`, loop and closure
  // parameters, imports) may hold anything, a label included: they are
  // neither globals nor translated variables.
  let locals : Map[String, Unit] = Map([])
  if !bound_names(expr.to_untyped(), locals) {
    // A wildcard import: any name may be bound.
    return false
  }
  self.not_label_in(expr, env, locals)
}

///|
/// Collect the names that are bound below a node. `false`: a wildcard
/// import binds names that are not known.
fn bound_names(node : @syntax.SyntaxNode, out : Map[String, Unit]) -> Bool {
  match @ast.Expr::from_untyped(node) {
    Some(LetBinding(binding)) =>
      for ident in binding.kind().bindings() {
        out[ident.get()] = ()
      }
    Some(ForLoop(loop_)) =>
      for ident in loop_.pattern().bindings() {
        out[ident.get()] = ()
      }
    Some(Closure(closure)) =>
      // Parameters: every identifier of the parameter list.
      idents_of(closure.params().to_untyped(), out)
    Some(DestructAssignment(assign)) =>
      for ident in assign.pattern().bindings() {
        out[ident.get()] = ()
      }
    Some(ModuleImport(import_)) =>
      match import_.imports() {
        Some(Wildcard) => return false
        _ => idents_of(node, out)
      }
    _ => ()
  }
  for child in node.children() {
    if !bound_names(child, out) {
      return false
    }
  }
  true
}

///|
fn Tr::not_label_in(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
  locals : Map[String, Unit],
) -> Bool {
  match expr {
    Label(_) => false
    None(_)
    | Auto(_)
    | Bool(_)
    | Int(_)
    | Float(_)
    | Numeric(_)
    | Str(_)
    | ContentBlock(_)
    | Closure(_)
    | Array(_)
    | Dict(_)
    | Unary(_)
    | Contextual(_)
    | ModuleInclude(_) => true
    Binary(binary) =>
      match binary.op() {
        Assign | AddAssign | SubAssign | MulAssign | DivAssign => false
        // `none + <x>` is the label.
        Add =>
          self.not_label_in(binary.lhs(), env, locals) &&
          self.not_label_in(binary.rhs(), env, locals)
        _ => true
      }
    Parenthesized(p) => self.not_label_in(p.expr(), env, locals)
    // A translated variable is a literal; a global of the library is no
    // label. A name that the expression binds itself, or that does not
    // exist, is neither.
    Ident(ident) =>
      !locals.contains(ident.get()) &&
      (env.vars.contains(ident.get()) || self.lookup(ident.get()) is Some(_))
    FieldAccess(_) =>
      !rooted_in(expr, locals) &&
      (match self.global_path(expr, env) {
        Some(path) => self.lookup(path) is Some(_)
        None => false
      })
    FuncCall(call) =>
      !rooted_in(call.callee(), locals) && self.call_not_label(call, env)
    Conditional(cond) =>
      self.not_label_in(cond.if_body(), env, locals) &&
      (match cond.else_body() {
        Some(body) => self.not_label_in(body, env, locals)
        None => true
      })
    ForLoop(loop_) => self.not_label_in(loop_.body(), env, locals)
    WhileLoop(loop_) => self.not_label_in(loop_.body(), env, locals)
    CodeBlock(block) => {
      for statement in block.body().exprs() {
        if !(is_statement(statement) ||
          self.not_label_in(statement, env, locals)) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
/// Whether the root identifier of an access path is one of `locals`.
fn rooted_in(expr : @ast.Expr, locals : Map[String, Unit]) -> Bool {
  match root_ident(expr) {
    Some(name) => locals.contains(name)
    None => false
  }
}

///|
/// The construct an expression is, for the fallback records.
fn construct_of(expr : @ast.Expr) -> String {
  match expr {
    LetBinding(binding) =>
      match binding.kind() {
        Closure(_) => "let-function"
        Normal(Normal(_)) => "let"
        Normal(_) => "let-destructuring"
      }
    SetRule(_) => "set"
    ShowRule(_) => "show"
    ModuleImport(_) => "import"
    ModuleInclude(_) => "include"
    ForLoop(_) => "for"
    WhileLoop(_) => "while"
    Conditional(_) => "if"
    CodeBlock(_) => "code-block"
    Closure(_) => "closure"
    Contextual(_) => "context"
    DestructAssignment(_) => "assignment"
    Binary(binary) =>
      if binary.op() is (Assign | AddAssign | SubAssign | MulAssign | DivAssign) {
        "assignment"
      } else {
        "operator"
      }
    Unary(_) => "operator"
    FieldAccess(_) => "field-access"
    FuncCall(call) =>
      match call.callee() {
        FieldAccess(_) => "method_name-call"
        _ => "call"
      }
    Array(_) => "array"
    Dict(_) => "dictionary"
    Ident(_) => "variable"
    _ => "expression"
  }
}
