// Port of `typst-library/src/foundations/ty.rs`.

///|
/// Static data describing a native type.
pub struct NativeTypeData {
  /// The type's normal name (e.g. `str`), as exposed to Typst.
  name : String
  /// The type's long name (e.g. `string`), for error messages.
  long_name : String
  /// The function's title case name (e.g. `String`).
  title : String
  /// The version of Typst this type was introduced in.
  since : Since?
  /// The documentation for this type as a string.
  docs : String
  /// A list of alternate search terms for this type.
  keywords : Array[String]
  /// The constructor for this type, set when the scope is built.
  priv mut constructor_ : NativeFuncData?
  /// The associated scope, built lazily.
  priv mut scope : Scope?
  /// Builds the scope (and constructor) on first access.
  priv mut scope_init : (NativeTypeData) -> Unit
}

///|
pub fn NativeTypeData::new(
  name~ : String,
  long_name~ : String,
  title~ : String,
  since? : Since,
  docs~ : String,
  keywords? : Array[String] = [],
) -> NativeTypeData {
  {
    name,
    long_name,
    title,
    since,
    docs,
    keywords,
    constructor_: None,
    scope: None,
    scope_init: _ => (),
  }
}

///|
/// Register the scope builder of a native type. `init` must set the scope
/// via [NativeTypeData::set_scope] and may set a constructor.
pub fn NativeTypeData::register(
  self : NativeTypeData,
  init : (NativeTypeData) -> Unit,
) -> Unit {
  self.scope_init = init
  self.scope = None
}

///|
pub fn NativeTypeData::set_scope(self : NativeTypeData, scope : Scope) -> Unit {
  self.scope = Some(scope)
}

///|
pub fn NativeTypeData::set_constructor(
  self : NativeTypeData,
  ctor : NativeFuncData,
) -> Unit {
  self.constructor_ = Some(ctor)
}

///|
fn NativeTypeData::ensure(self : NativeTypeData) -> Unit {
  if self.scope is None {
    self.scope = Some(Scope::new())
    (self.scope_init)(self)
  }
}

///|
/// Describes a kind of value.
pub struct Type(NativeTypeData)

///|
pub impl Eq for Type with fn equal(self, other) {
  physical_equal(self.0, other.0)
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Type with Eq::{not_equal, equal}

///|
pub impl Hash for Type with fn hash_combine(self, hasher) {
  hasher.combine_string(self.0.name)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Type with Hash::{hash, hash_combine}

///|
/// Order by long name (upstream `Ord for Type`).
pub impl Compare for Type with fn compare(self, other) {
  compare_str(self.0.long_name, other.0.long_name)
}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Type with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
/// The type's short name, how in code it is referenced (e.g. `str`).
pub fn Type::short_name(self : Type) -> String {
  self.0.name
}

///|
/// The type's long name, for use in diagnostics (e.g. `string`).
pub fn Type::long_name(self : Type) -> String {
  self.0.long_name
}

///|
/// The type's title case name, for use in documentation (e.g. `String`).
pub fn Type::title(self : Type) -> String {
  self.0.title
}

///|
/// The version of Typst this type was introduced in.
pub fn Type::since(self : Type) -> Since? {
  self.0.since
}

///|
/// Documentation for the type (as Markdown).
pub fn Type::docs(self : Type) -> String {
  self.0.docs
}

///|
/// Search keywords for the type.
pub fn Type::keywords(self : Type) -> ArrayView[String] {
  self.0.keywords[:]
}

///|
/// Get the type's constructor.
pub fn Type::constructor_(self : Type) -> Func raise HintedError {
  self.0.ensure()
  match self.0.constructor_ {
    Some(data) => Func::native(data)
    None => bail("type \{self} does not have a constructor")
  }
}

///|
/// The type's associated scope that holds sub-definitions.
pub fn Type::scope(self : Type) -> Scope {
  self.0.ensure()
  self.0.scope.unwrap()
}

///|
/// Get a field from this type's scope, if possible.
pub fn Type::field(
  self : Type,
  field : String,
  guard_ : BindingGuard,
) -> Value raise HintedError {
  match self.scope().get(field) {
    Some(binding) =>
      binding.read(guard_, "access field `\{field}` on type \{self}").shared()
    None => bail("type \{self} does not contain field `\{field}`")
  }
}

///|
/// Upstream `Repr for Type`.
pub fn Type::repr(self : Type) -> String {
  if self == Type::auto() {
    "type(auto)"
  } else if self == Type::none() {
    "type(none)"
  } else {
    self.short_name()
  }
}

///|
/// Upstream `Display for Type`: the long name.
pub impl Show for Type with fn output(self, logger) {
  logger.write_string(self.long_name())
}

///|
// `output` is not named here: the `extend` of `Reflect` makes it a method of the type.
pub extend Type with Show::{to_string}

///|
/// Determines a value's type (upstream `Type::construct`).
fn impl_type_construct(value_ : Value) -> Type {
  value_.ty()
}
