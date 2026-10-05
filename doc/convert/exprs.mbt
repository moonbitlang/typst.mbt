// Calls, values and rules (docs/edsl-convert.md, sections 4.2 to 4.5).
//
// TODO: these are the entry points of the typed translation; until they
// are implemented they raise, so every call and rule is a fragment.

///|
/// A call (section 4.2) as content: a typed constructor, a generic `Call`,
/// or not typed.
fn Tr::call(self : Tr, call : @ast.FuncCall, env : Env) -> Code raise Bail {
  ignore((self, env))
  raise Bail(construct_of(FuncCall(call)))
}

///|
/// The `Value` form of an expression (section 4.4), as an expression of
/// type `@doc.Value` (which is content in a stream: its display).
fn Tr::value(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  ignore((self, env))
  raise Bail(construct_of(expr))
}

///|
/// An expression against a parameter type of the EDSL (section 4.3), given
/// as the MoonBit type of the parameter (`"Length"`, `"Sides[Stroke]"`,
/// `"&IntoContent"`, ...). `None`: the expression has no typed form.
fn Tr::typed(self : Tr, expr : @ast.Expr, ty : String, env : Env) -> Code? {
  ignore((self, expr, ty, env))
  None
}

///|
/// `set path(args)` (section 4.5).
fn Tr::set_rule(self : Tr, rule : @ast.SetRule, env : Env) -> Code raise Bail {
  ignore((self, env))
  raise Bail(construct_of(SetRule(rule)))
}

///|
/// `show selector: transform` (section 4.5).
fn Tr::show_rule(self : Tr, rule : @ast.ShowRule, env : Env) -> Code raise Bail {
  ignore((self, env))
  raise Bail(construct_of(ShowRule(rule)))
}
