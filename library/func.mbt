// Port of `typst-library/src/foundations/func.rs`.

///|
/// Describes a function parameter of a native function or element.
pub(all) struct ParamInfo {
  /// The parameter's name.
  name : String
  /// Documentation for the parameter.
  docs : String
  /// Describe what values this parameter accepts.
  input : () -> CastInfo
  /// Creates an instance of the parameter's default value.
  default : (() -> Value)?
  /// Is the parameter positional?
  positional : Bool
  /// Is the parameter named?
  named : Bool
  /// Can the parameter be given any number of times?
  variadic : Bool
  /// Is the parameter required?
  required : Bool
  /// Is the parameter settable with a set rule?
  settable : Bool
}

///|
/// The signature of a native function implementation.
pub type NativeFn = (Engine, Context, Args) -> Value raise SourceError

///|
/// Defines a native function.
pub struct NativeFuncData {
  /// The implementation of the function.
  function : NativeFn
  /// The function's normal name (e.g. `align`), as exposed to Typst.
  name : String
  /// The function's title case name (e.g. `Align`).
  title : String
  /// Documentation for this function.
  docs : String
  /// Search keywords.
  keywords : Array[String]
  /// Whether this function makes use of context.
  contextual : Bool
  /// Definitions in the scope of the function.
  priv mut scope : Scope?
  priv scope_init : () -> Scope
  /// Information about the parameters of the function.
  params : Array[ParamInfo]
  /// Information about the return value of this function.
  returns : () -> CastInfo
}

///|
pub fn NativeFuncData::new(
  name~ : String,
  title~ : String,
  docs? : String = "",
  keywords? : Array[String] = [],
  contextual? : Bool = false,
  scope? : () -> Scope = Scope::new,
  params? : Array[ParamInfo] = [],
  returns? : () -> CastInfo = () => Any,
  function : NativeFn,
) -> NativeFuncData {
  {
    function,
    name,
    title,
    docs,
    keywords,
    contextual,
    scope: None,
    scope_init: scope,
    params,
    returns,
  }
}

///|
/// The scope of the native function.
pub fn NativeFuncData::scope(self : NativeFuncData) -> Scope {
  match self.scope {
    Some(s) => s
    None => {
      let s = (self.scope_init)()
      self.scope = Some(s)
      s
    }
  }
}

///|
/// The syntax node of a closure or context expression.
pub(all) enum ClosureNode {
  /// A regular closure. Must always be castable to an `ast::Closure`.
  Closure(@syntax.SyntaxNode)
  /// Synthetic closure used for `context` expressions. Can be any `ast::Expr`
  /// and has no parameters.
  Context(@syntax.SyntaxNode)
}

///|
/// A user-defined closure.
pub struct Closure {
  /// The closure's syntax node.
  node : ClosureNode
  /// Default values of named parameters.
  defaults : Array[Value]
  /// Captured values from outer scopes.
  captured : Scope
  /// The number of positional parameters in the closure.
  num_pos_params : Int
}

///|
/// The kind of a function.
pub(all) enum FuncInner {
  /// A native Rust function.
  Native(NativeFuncData)
  /// A function for an element.
  Element(Element)
  /// A user-defined closure.
  Closure(Closure)
  /// A nested function with pre-applied arguments.
  With(Func, Args)
}

///|
/// A mapping from argument values to a return value.
pub struct Func {
  /// The internal representation.
  inner : FuncInner
  /// The span with which errors are reported when this function is called.
  span : @syntax.Span
}

///|
pub fn Func::from_inner(inner : FuncInner) -> Func {
  { inner, span: @syntax.Span::detached(), }
}

///|
/// A native function.
pub fn Func::native(data : NativeFuncData) -> Func {
  Func::from_inner(Native(data))
}

///|
/// An element function.
pub fn Func::element(elem : Element) -> Func {
  Func::from_inner(Element(elem))
}

///|
/// A closure.
pub fn Func::closure(closure : Closure) -> Func {
  Func::from_inner(Closure(closure))
}

///|
/// The function's name (e.g. `min`).
pub fn Func::name(self : Func) -> String? {
  match self.inner {
    Native(native) => Some(native.name)
    Element(elem) => Some(elem.name())
    Closure(closure) => closure.name()
    With(func, _) => func.name()
  }
}

///|
/// The function's title case name (e.g. `Minimum`).
pub fn Func::title(self : Func) -> String? {
  match self.inner {
    Native(native) => Some(native.title)
    Element(elem) => Some(elem.title())
    Closure(_) => None
    With(func, _) => func.title()
  }
}

///|
/// Whether the function is known to be contextual.
pub fn Func::contextual(self : Func) -> Bool? {
  match self.inner {
    Native(native) => Some(native.contextual)
    _ => None
  }
}

///|
/// The function's associated scope of sub-definitions.
pub fn Func::scope(self : Func) -> Scope? {
  match self.inner {
    Native(native) => Some(native.scope())
    Element(elem) => Some(elem.scope())
    Closure(_) => None
    With(func, _) => func.scope()
  }
}

///|
/// Get a field from this function's scope, if possible.
pub fn Func::field(
  self : Func,
  field : String,
  guard_ : BindingGuard,
) -> Value raise HintedError {
  guard self.scope() is Some(scope) else {
    bail("cannot access fields on user-defined functions")
  }
  match scope.get(field) {
    Some(binding) => binding.read(guard_, "access field `\{field}`").shared()
    None =>
      match self.name() {
        Some(name) =>
          bail("function `\{name}` does not contain field `\{field}`")
        None => bail("function does not contain field `\{field}`")
      }
  }
}

///|
/// Extract the element function, if it is one.
pub fn Func::to_element(self : Func) -> Element? {
  match self.inner {
    Element(elem) => Some(elem)
    _ => None
  }
}

///|
/// Extract the native function data, if it is one.
pub fn Func::to_native(self : Func) -> NativeFuncData? {
  match self.inner {
    Native(native) => Some(native)
    _ => None
  }
}

///|
/// Call the function with the given context and arguments.
pub fn Func::call(
  self : Func,
  engine : Engine,
  context : Context,
  args : Args,
) -> Value raise SourceError {
  match self.inner {
    Native(native) => {
      let value = (native.function)(engine, context, args)
      args.finish()
      value
    }
    Element(elem) => {
      let value = elem.construct(engine, args)
      args.finish()
      Content(value)
    }
    Closure(closure) =>
      (engine.routines().eval_closure)(self, closure, engine, context, args)
    With(func, pre) => {
      let items = pre.items.map(a => {
        span: a.span,
        name: a.name,
        value: { v: a.value.v.shared(), span: a.value.span, },
      })
      for a in args.items {
        items.push(a)
      }
      args.items.clear()
      args.items.append(items)
      func.call(engine, context, args)
    }
  }
}

///|
/// Call the function with positional values.
pub fn Func::call_values(
  self : Func,
  engine : Engine,
  context : Context,
  values : ArrayView[Value],
) -> Value raise SourceError {
  self.call(engine, context, Args::new(self.span, values))
}

///|
/// The function's span.
pub fn Func::span(self : Func) -> @syntax.Span {
  self.span
}

///|
/// Attach a span to this function if it doesn't already have one.
pub fn Func::spanned(self : Func, span : @syntax.Span) -> Func {
  if self.span.is_detached() {
    { inner: self.inner, span, }
  } else {
    self
  }
}

///|
/// Returns a new function that has the given arguments pre-applied.
pub fn Func::with_args(self : Func, args : Args) -> Func {
  { inner: With(self, args.take()), span: self.span, }
}

///|
/// Upstream `Repr for Func`.
pub fn Func::repr(self : Func) -> String {
  let default = "(..) => .."
  match self.inner {
    Native(native) => native.name
    Element(elem) => elem.name()
    Closure(closure) => closure.name().unwrap_or(default)
    With(_, _) => default
  }
}

///|
/// Upstream `PartialEq for Func` (identity of the inner representation).
pub impl Eq for Func with fn equal(self, other) {
  match (self.inner, other.inner) {
    (Native(a), Native(b)) => physical_equal(a, b)
    (Element(a), Element(b)) => a == b
    (Closure(a), Closure(b)) => physical_equal(a, b)
    (With(f1, a1), With(f2, a2)) => f1 == f2 && a1 == a2
    _ => false
  }
}

///|
/// The name of the closure, if it has one.
pub fn Closure::name(self : Closure) -> String? {
  match self.node {
    Closure(node) => (closure_name_hook.val)(node)
    Context(_) => None
  }
}

///|
/// Extracts the name of a closure node (installed by the eval package,
/// which owns the typed AST).
pub let closure_name_hook : Ref[(@syntax.SyntaxNode) -> String?] = Ref::new(_ => {
  None
})
