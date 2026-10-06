// Port of `typst-library/src/foundations/scope.rs`.

///|
/// An in-development feature that should be enabled.
pub(all) enum Feature {
  Html
  Bundle
  A11yExtras
} derive(Eq, Hash, Debug)

///|
pub fn Feature::all() -> Array[Feature] {
  [Html, Bundle, A11yExtras]
}

///|
pub impl Show for Feature with fn output(self, logger) {
  logger.write_string(
    match self {
      Html => "html"
      Bundle => "bundle"
      A11yExtras => "a11y-extras"
    },
  )
}

///|
pub fn Feature::from_str(s : String) -> Feature? {
  match s {
    "html" => Some(Html)
    "bundle" => Some(Bundle)
    "a11y-extras" => Some(A11yExtras)
    _ => None
  }
}

///|
/// A selection of in-development features that should be enabled.
pub(all) struct Features(Array[Feature]) derive(Eq, Hash)

///|
pub fn Features::all() -> Features {
  Features(Feature::all())
}

///|
pub fn Features::none() -> Features {
  Features([])
}

///|
pub fn Features::is_enabled(self : Features, feature : Feature) -> Bool {
  self.0.contains(feature)
}

///|
/// Categories of Typst's standard library (used for documentation).
pub(all) enum Category {
  Foundations
  Introspection
  Layout
  DataLoading
  Math
  Model
  Symbols
  Text
  Visualize
  Format
  Pdf
  Html
  Svg
  Png
  Bundle
} derive(Eq, Hash, Debug)

///|
/// Describes a deprecation of a binding.
pub(all) struct Deprecation {
  message : String
  until : String?
} derive(Eq, Hash, Debug)

///|
pub fn Deprecation::new() -> Deprecation {
  { message: "item is deprecated", until: None, }
}

///|
pub fn Deprecation::with_message(
  self : Deprecation,
  message : String,
) -> Deprecation {
  { ..self, message, }
}

///|
pub fn Deprecation::with_until(
  self : Deprecation,
  version : String,
) -> Deprecation {
  { ..self, until: Some(version), }
}

///|
pub fn Deprecation::to_hinted(self : Deprecation) -> HintedString {
  let s = HintedString::new(self.message)
  if self.until is Some(v) {
    s.hint("it will be removed in Typst \{v}")
  }
  s
}

///|
/// Accesses bindings, checking features and emitting deprecation warnings
/// (upstream `BindingGuard`).
pub(all) struct BindingGuard {
  features : Features
  emit : (HintedString) -> Unit
}

///|
/// A guard that never emits warnings.
pub fn BindingGuard::silent(features : Features) -> BindingGuard {
  { features, emit: _ => (), }
}

///|
/// What kind of construct captured a binding.
pub(all) enum Capturer {
  /// Captured by a function / closure.
  Function
  /// Captured by a context expression.
  Context
} derive(Eq, Hash, Debug)

///|
pub impl Show for Capturer with fn output(self, logger) {
  logger.write_string(
    match self {
      Function => "function"
      Context => "context expression"
    },
  )
}

///|
priv enum BindingKind {
  Normal
  Captured(Capturer)
} derive(Eq, Hash)

///|
/// Documentation metadata for a binding.
pub(all) struct BindingDocumentation {
  name : String
  title : String
  docs : String
} derive(Eq, Hash)

///|
priv struct BindingInfo {
  mut category : Category?
  mut feature : Feature?
  mut deprecation : Deprecation?
  mut documentation : BindingDocumentation?
  /// The fingerprint of the fields above (not upstream: the info of a
  /// standard library binding is shared by all of its captured copies, and
  /// its documentation is long).
  hash : LazyFingerprint
} derive(Eq, Hash)

///|
/// A bound value with metadata.
pub struct Binding {
  /// The bound value.
  mut value : Value
  priv kind : BindingKind
  /// The span of the binding.
  span : @syntax.Span
  priv mut check_access : Bool
  priv mut info : BindingInfo?
}

///|
/// Create a new binding with a span marking its definition site.
pub fn Binding::new(value : Value, span : @syntax.Span) -> Binding {
  { value, kind: Normal, span, check_access: false, info: None, }
}

///|
/// Create a binding without a span.
pub fn Binding::detached(value : Value) -> Binding {
  Binding::new(value, @syntax.Span::detached())
}

///|
fn Binding::init_info(self : Binding) -> BindingInfo {
  match self.info {
    Some(info) => {
      // The caller modifies the info.
      info.hash.reset()
      info
    }
    None => {
      let info = {
        category: None,
        feature: None,
        deprecation: None,
        documentation: None,
        hash: LazyFingerprint::new(),
      }
      self.info = Some(info)
      info
    }
  }
}

///|
/// Marks this binding as belonging to a category.
pub fn Binding::with_category(self : Binding, category : Category) -> Binding {
  self.init_info().category = Some(category)
  self
}

///|
/// Marks this binding as gated by a feature.
pub fn Binding::with_feature(self : Binding, feature : Feature) -> Binding {
  let info = self.init_info()
  info.feature = Some(feature)
  self.check_access = true
  self
}

///|
/// Marks this binding as deprecated.
pub fn Binding::with_deprecation(
  self : Binding,
  deprecation : Deprecation,
) -> Binding {
  let info = self.init_info()
  info.deprecation = Some(deprecation)
  self.check_access = true
  self
}

///|
/// Attaches documentation to the binding.
pub fn Binding::with_documentation(
  self : Binding,
  documentation : BindingDocumentation,
) -> Binding {
  self.init_info().documentation = Some(documentation)
  self
}

///|
/// Errors that can occur when accessing a binding.
pub(all) enum BindingError {
  /// The binding was captured and is read-only.
  Captured(Capturer)
  /// The binding is gated by a disabled feature.
  Feature(Feature)
}

///|
/// Convert the error into a message saying `what` cannot be done.
pub fn BindingError::cannot(self : BindingError, what : String) -> HintedString {
  match self {
    Captured(capturer) =>
      HintedString::new(
        "variables from outside the \{capturer} are read-only and cannot be modified",
      )
    Feature(feature) => feature_cannot(feature, what)
  }
}

///|
fn feature_cannot(feature : Feature, what : String) -> HintedString {
  HintedString::new(
    "cannot \{what} because the `\{feature}` feature is not enabled",
  )
  .with_hint("try enabling the `\{feature}` feature")
  .with_hint("see https://typst.app/help/compiler-features for more details")
}

///|
fn Binding::check(self : Binding, guard_ : BindingGuard) -> Feature? {
  guard self.info is Some(info) else { return None }
  if info.feature is Some(feature) && !guard_.features.is_enabled(feature) {
    return Some(feature)
  }
  if info.deprecation is Some(d) {
    (guard_.emit)(d.to_hinted())
  }
  None
}

///|
/// Read the value, checking features and emitting deprecation warnings.
/// `what` describes the access for error messages (e.g. "access variable
/// `x`").
pub fn Binding::read(
  self : Binding,
  guard_ : BindingGuard,
  what : String,
) -> Value raise HintedError {
  if self.check_access && self.check(guard_) is Some(feature) {
    raise HintedError(feature_cannot(feature, what))
  }
  self.value
}

///|
/// Check write access to the value.
pub fn Binding::check_write(
  self : Binding,
  guard_ : BindingGuard,
  what : String,
) -> Unit raise HintedError {
  if self.check_access && self.check(guard_) is Some(feature) {
    raise HintedError(feature_cannot(feature, what))
  }
  if self.kind is Captured(capturer) {
    raise HintedError(BindingError::Captured(capturer).cannot(what))
  }
}

///|
/// Overwrite the bound value.
pub fn Binding::set_value(self : Binding, value : Value) -> Unit {
  self.value = value
}

///|
/// Create a copy of the binding for closure capturing.
pub fn Binding::capture(self : Binding, capturer : Capturer) -> Binding {
  {
    value: self.value.shared(),
    kind: Captured(capturer),
    span: self.span,
    check_access: self.check_access,
    info: self.info,
  }
}

///|
/// A shallow copy of the binding.
pub fn Binding::copy(self : Binding) -> Binding {
  {
    value: self.value.shared(),
    kind: self.kind,
    span: self.span,
    check_access: self.check_access,
    info: self.info,
  }
}

///|
pub fn Binding::category(self : Binding) -> Category? {
  self.info.bind(i => i.category)
}

///|
pub fn Binding::feature(self : Binding) -> Feature? {
  self.info.bind(i => i.feature)
}

///|
pub fn Binding::deprecation(self : Binding) -> Deprecation? {
  self.info.bind(i => i.deprecation)
}

///|
/// A map from binding names to values (insertion ordered).
pub struct Scope {
  priv map : Map[String, Binding]
  priv deduplicate : Bool
  priv mut category : Category?
}

///|
pub fn Scope::new() -> Scope {
  { map: {}, deduplicate: false, category: None, }
}

///|
/// Create a new scope with duplication prevention.
pub fn Scope::deduplicating() -> Scope {
  { map: {}, deduplicate: true, category: None, }
}

///|
/// Enter a new category.
pub fn Scope::start_category(self : Scope, category : Category) -> Unit {
  self.category = Some(category)
}

///|
/// Reset the category.
pub fn Scope::reset_category(self : Scope) -> Unit {
  self.category = None
}

///|
/// Bind a value to a name.
pub fn Scope::define_(self : Scope, name : String, value : Value) -> Binding {
  if self.deduplicate && self.map.contains(name) {
    abort("duplicate definition: \{name}")
  }
  let binding = Binding::detached(value)
  if self.category is Some(c) {
    binding.init_info().category = Some(c)
  }
  self.bind(name, binding)
}

///|
/// Inserts a binding into this scope and returns it.
pub fn Scope::bind(self : Scope, name : String, binding : Binding) -> Binding {
  self.map[name] = binding
  binding
}

///|
/// Try to access a binding immutably.
pub fn Scope::get(self : Scope, name : String) -> Binding? {
  self.map.get(name)
}

///|
/// Iterate over all definitions.
pub fn Scope::iter(self : Scope) -> Iter[(String, Binding)] {
  self.map.iter()
}

///|
/// The number of definitions.
pub fn Scope::length(self : Scope) -> Int {
  self.map.length()
}

///|
/// A copy of the scope (bindings are copied).
pub fn Scope::copy(self : Scope) -> Scope {
  let map = Map([])
  for k, v in self.map {
    map[k] = v.copy()
  }
  { map, deduplicate: self.deduplicate, category: self.category, }
}

///|
/// A stack of scopes.
pub(all) struct Scopes {
  /// The active scope.
  mut top : Scope
  /// The stack of lower scopes.
  scopes : Array[Scope]
  /// The standard library.
  base : Library?
}

///|
pub fn Scopes::new(base : Library?) -> Scopes {
  { top: Scope::new(), scopes: [], base, }
}

///|
/// Enter a new scope.
pub fn Scopes::enter(self : Scopes) -> Unit {
  self.scopes.push(self.top)
  self.top = Scope::new()
}

///|
/// Exit the topmost scope.
pub fn Scopes::exit(self : Scopes) -> Unit {
  guard self.scopes.pop() is Some(top) else { abort("no pushed scope") }
  self.top = top
}

///|
/// Try to access a binding immutably.
pub fn Scopes::get_binding(
  self : Scopes,
  name : String,
) -> Binding raise HintedError {
  if self.top.get(name) is Some(b) {
    return b
  }
  for i = self.scopes.length() - 1; i >= 0; i = i - 1 {
    if self.scopes[i].get(name) is Some(b) {
      return b
    }
  }
  if self.base is Some(base) {
    match base.global.scope().get(name) {
      Some(b) => return b
      None => if name == "std" { return base.std }
    }
  }
  raise HintedError(unknown_variable(name))
}

///|
/// Try to access a binding immutably in math.
pub fn Scopes::get_binding_in_math(
  self : Scopes,
  name : String,
) -> Binding raise HintedError {
  if self.top.get(name) is Some(b) {
    return b
  }
  for i = self.scopes.length() - 1; i >= 0; i = i - 1 {
    if self.scopes[i].get(name) is Some(b) {
      return b
    }
  }
  if self.base is Some(base) {
    match base.math.scope().get(name) {
      Some(b) => return b
      None => if name == "std" { return base.std }
    }
  }
  let in_global = match self.base {
    Some(base) => base.global.scope().get(name) is Some(_)
    None => false
  }
  raise HintedError(unknown_variable_math(name, in_global))
}

///|
/// Try to access a variable immutably.
pub fn Scopes::get(
  self : Scopes,
  name : String,
  guard_ : BindingGuard,
) -> Value raise HintedError {
  self.get_binding(name).read(guard_, "access variable `\{name}`")
}

///|
/// Try to access a variable immutably in math.
pub fn Scopes::get_in_math(
  self : Scopes,
  name : String,
  guard_ : BindingGuard,
) -> Value raise HintedError {
  self.get_binding_in_math(name).read(guard_, "access variable `\{name}`")
}

///|
/// Try to access a binding mutably (for assignment / in-place mutation).
pub fn Scopes::get_mut(
  self : Scopes,
  name : String,
  guard_ : BindingGuard,
) -> Binding raise HintedError {
  let found = if self.top.get(name) is Some(b) {
    Some(b)
  } else {
    let mut res : Binding? = None
    for i = self.scopes.length() - 1; i >= 0; i = i - 1 {
      if self.scopes[i].get(name) is Some(b) {
        res = Some(b)
        break
      }
    }
    res
  }
  match found {
    Some(b) => {
      b.check_write(guard_, "access variable `\{name}`")
      b
    }
    None =>
      match self.base.bind(base => base.global.scope().get(name)) {
        Some(binding) => {
          binding.read(guard_, "access variable `\{name}`") |> ignore
          raise HintedError(cannot_mutate_constant(name))
        }
        None if name == "std" => raise HintedError(cannot_mutate_constant(name))
        None => raise HintedError(unknown_variable(name))
      }
  }
}

///|
/// Check if an std variable is shadowed.
pub fn Scopes::check_std_shadowed(self : Scopes, name : String) -> Bool {
  guard self.base is Some(base) else { return false }
  if base.global.scope().get(name) is None {
    return false
  }
  if self.top.get(name) is Some(_) {
    return true
  }
  self.scopes.iter().any(s => s.get(name) is Some(_))
}

///|
fn cannot_mutate_constant(name : String) -> HintedString {
  HintedString::new("cannot mutate a constant: \{name}")
}

///|
fn unknown_variable(name : String) -> HintedString {
  let res = HintedString::new("unknown variable `\{name}`")
  if name.contains("-") {
    let count = name.iter().filter(c => c == '-').count()
    let s = if count > 1 { "s" } else { "" }
    res.hint(
      "if you meant to use subtraction, try adding spaces around the minus sign\{s}: `\{name.replace_all(old="-", new=" - ")}`",
    )
  }
  res
}

///|
fn unknown_variable_math(name : String, in_global : Bool) -> HintedString {
  let res = HintedString::new("unknown variable `\{name}`")
  if name is ("none" | "auto" | "false" | "true") {
    res.hint(
      "if you meant to use a literal, try adding a hash before it: `#\{name}`",
    )
  } else if in_global {
    res.hint(
      "`\{name}` is not available directly in math, but is in the standard library",
    )
    res.hint("to access `\{name}` in code mode you can add a hash: `#\{name}`")
    res.hint(
      "or access `\{name}` in math mode by using the `std` module: `std.\{name}`",
    )
  } else {
    let spaced = StringBuilder()
    let mut first = true
    for c in name {
      if !first {
        spaced.write_char(' ')
      }
      spaced.write_char(c)
      first = false
    }
    res.hint(
      "if you meant to display multiple letters as is, try adding spaces between each letter: `\{spaced.to_string()}`",
    )
    res.hint(
      "or if you meant to display this as text, try placing it in quotes: `\"\{name}\"`",
    )
  }
  res
}
