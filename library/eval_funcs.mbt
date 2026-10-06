// `eval` (`typst-library/src/foundations/mod.rs`), the `SyntaxMode` cast
// (`foundations/cast.rs`) and the methods of the `function` type
// (`foundations/func.rs`).

///|
pub impl Reflect for @syntax.SyntaxMode with fn input() {
  Union([
    Value(Str("markup"), "Evaluate as markup, as in a Typst file."),
    Value(Str("math"), "Evaluate as math, as in an equation."),
    Value(Str("code"), "Evaluate as code, as after a hash."),
  ])
}

///|
pub impl Reflect for @syntax.SyntaxMode with fn output() {
  input_of((Ty::new() : Ty[@syntax.SyntaxMode]))
}

///|
pub impl Reflect for @syntax.SyntaxMode with fn castable(v) {
  v is Str("markup" | "math" | "code")
}

///|
pub impl IntoValue for @syntax.SyntaxMode with fn into_value(self) {
  Str(
    match self {
      Markup => "markup"
      Math => "math"
      Code => "code"
    },
  )
}

///|
pub impl FromValue for @syntax.SyntaxMode with fn from_value(v) {
  match v {
    Str("markup") => Markup
    Str("math") => Math
    Str("code") => Code
    v => raise HintedError(cast_error((Ty::new() : Ty[@syntax.SyntaxMode]), v))
  }
}

///|
fn impl_eval__mode_default() -> @syntax.SyntaxMode {
  Code
}

///|
fn impl_eval__scope_default() -> Dict {
  Dict::new()
}

///|
/// Evaluates a string as Typst code.
fn impl_eval(
  engine : Engine,
  source_ : @syntax.Spanned[String],
  mode_ : @syntax.SyntaxMode,
  scope_ : Dict,
) -> Value raise SourceError {
  let { v: text, span, } = source_
  let scope = Scope::new()
  for key, value in scope_.iter() {
    scope.bind(key, Binding::new(value, span)) |> ignore
  }
  // We create a new, detached introspector for string evaluation.
  let engine = { ..engine, introspector: Introspector::empty(), }
  (engine.library.routines.eval_string)(
    engine,
    Context::none(),
    text,
    span,
    mode_,
    scope,
  )
}

///|
/// Returns a new function that has the given arguments pre-applied.
fn impl_func_with(self_ : Func, args : Args) -> Func {
  let span = self_.span()
  { inner: With(self_, args.take()), span, }
}
