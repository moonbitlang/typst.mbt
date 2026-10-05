// Fallback fragments (docs/edsl-convert.md, section 6): Typst source kept
// as source and evaluated by the front end. A fragment is the unchanged
// text of syntax nodes; the translated variables it mentions are passed as
// its scope. Nothing is copied into a fragment and nothing escapes it.

///|
/// A MoonBit string literal.
fn mbt_str(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => {
        let code = c.to_int()
        if code < 0x20 ||
          code == 0x7f ||
          code == 0x2028 ||
          code == 0x2029 ||
          code == 0xfeff ||
          (code >= 0x80 && code < 0xa0) ||
          (code >= 0x200b && code <= 0x200f) ||
          (code >= 0x202a && code <= 0x202e) ||
          (code >= 0x2060 && code <= 0x206f) {
          out.write_string("\\u{" + code.to_string(radix=16) + "}")
        } else {
          out.write_char(c)
        }
      }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// The identifiers that occur in a node (a superset of its free names).
fn idents_of(node : @syntax.SyntaxNode, out : Map[String, Unit]) -> Unit {
  match node.kind() {
    Ident | MathIdent => out[node.leaf_text()] = ()
    _ =>
      for child in node.children() {
        idents_of(child, out)
      }
  }
}

///|
/// The methods that mutate their receiver.
let mutating_methods : Array[String] = ["push", "pop", "insert", "remove"]

///|
/// The root identifier of an access path (`a` in `a.b.at(0).c`).
fn root_ident(expr : @ast.Expr) -> String? {
  match expr {
    Ident(ident) => Some(ident.get())
    FieldAccess(access) => root_ident(access.target())
    FuncCall(call) => root_ident(call.callee())
    Parenthesized(p) => root_ident(p.expr())
    _ => None
  }
}

///|
/// Collect the names that are assigned or mutated anywhere below a node:
/// their bindings are not translated (docs/edsl-convert.md, section 5).
fn mutated_names(node : @syntax.SyntaxNode, out : Map[String, Unit]) -> Unit {
  match @ast.Expr::from_untyped(node) {
    Some(Binary(binary)) =>
      if binary.op() is (Assign | AddAssign | SubAssign | MulAssign | DivAssign) {
        if root_ident(binary.lhs()) is Some(name) {
          out[name] = ()
        }
      }
    Some(DestructAssignment(assign)) =>
      for ident in assign.pattern().bindings() {
        out[ident.get()] = ()
      }
    Some(FuncCall(call)) =>
      if call.callee() is FieldAccess(access) &&
        mutating_methods.contains(access.field().get()) {
        if root_ident(access.target()) is Some(name) {
          out[name] = ()
        }
      }
    _ => ()
  }
  for child in node.children() {
    mutated_names(child, out)
  }
}

///|
/// Whether a node has control flow that escapes it: a `break` or
/// `continue` outside a loop of its own, or a `return` outside a closure
/// of its own.
fn escapes(
  node : @syntax.SyntaxNode,
  in_loop : Bool,
  in_closure : Bool,
) -> Bool {
  match node.kind() {
    LoopBreak | LoopContinue => return !in_loop
    FuncReturn => if !in_closure { return true }
    _ => ()
  }
  let in_loop = in_loop || node.kind() is (ForLoop | WhileLoop)
  // A closure body is its own function: loops outside do not reach in.
  let (in_loop, in_closure) = if node.kind() is Closure {
    (false, true)
  } else {
    (in_loop, in_closure)
  }
  for child in node.children() {
    if escapes(child, in_loop, in_closure) {
      return true
    }
  }
  false
}

///|
/// Whether a syntax tree has errors (the accessors of the AST return
/// placeholders for such trees, so they are never translated).
fn has_errors(node : @syntax.SyntaxNode) -> Bool {
  if node.kind().is_error() {
    return true
  }
  for child in node.children() {
    if has_errors(child) {
      return true
    }
  }
  false
}

///|
/// The value description of a translated variable.
fn value_of(mbt : String, ty : Ty) -> String {
  match ty {
    TInt => "Value::int(\{mbt})"
    TFloat => "Value::float(\{mbt})"
    TStr => "Value::str(\{mbt})"
    TBool => "Value::bool(\{mbt})"
    TLength => "Value::length(\{mbt})"
    TPaint => "Value::paint(\{mbt})"
    TView(_) => "Value::content(\{mbt})"
  }
}

///|
/// The scope of a fragment: the translated variables that its nodes
/// mention, as the entries of a MoonBit array literal.
fn Tr::scope(
  self : Tr,
  nodes : ArrayView[@syntax.SyntaxNode],
  env : Env,
) -> Array[String] {
  ignore(self)
  let names : Map[String, Unit] = Map([])
  for node in nodes {
    idents_of(node, names)
  }
  let entries : Array[String] = []
  for name, bind in env.vars {
    if names.contains(name) {
      entries.push("(\{mbt_str(name)}, \{value_of(bind.0, bind.1)})")
    }
  }
  entries
}

///|
/// Record a fragment.
fn Tr::record(
  self : Tr,
  construct : String,
  kind : String,
  text : String,
) -> Unit {
  let bytes = @syntax.utf8_len(text)
  self.fallbacks.push({ construct, kind, bytes, })
  self.fallback_bytes += bytes
}

///|
/// A content fragment: `Markup(source, scope=[..])`.
fn Tr::markup_fragment(
  self : Tr,
  construct : String,
  kind : String,
  text : String,
  scope : Array[String],
  recorded? : String = text,
) -> String {
  self.record(construct, kind, recorded)
  if scope.is_empty() {
    "Markup(\{mbt_str(text)})"
  } else {
    "Markup(\{mbt_str(text)}, scope=[\{scope.join(", ")}])"
  }
}

///|
/// A value fragment (section 6.3): `eval(source, scope: (..))` in code
/// mode. Only during initial lowering.
fn Tr::eval_fragment(
  self : Tr,
  construct : String,
  text : String,
  scope : Array[String],
) -> String {
  self.record(construct, "value", text)
  if scope.is_empty() {
    "Value::call(\"eval\", positional=[Value::str(\{mbt_str(text)})])"
  } else {
    "Value::call(\"eval\", positional=[Value::str(\{mbt_str(text)})], named=[(\"scope\", Value::dict([\{scope.join(", ")}]))])"
  }
}
