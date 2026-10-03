// Port of `wasmi_core/src/global.rs`.

///|
/// An error that may occur upon operating on global variables.
pub(all) suberror GlobalError {
  /// Occurs when trying to write to an immutable global variable.
  ImmutableWrite
  /// Occurs when trying writing a value with mismatching type to a global variable.
  TypeMismatch
} derive(Debug)

///|
pub impl Show for GlobalError with fn output(self, logger) {
  let message = match self {
    ImmutableWrite => "tried to write to immutable global variable"
    TypeMismatch =>
      "tried to write value of non-matching type to global variable"
  }
  logger.write_string(message)
}

///|
/// The mutability of a global variable.
pub(all) enum Mutability {
  /// The value of the global variable is a constant.
  Const
  /// The value of the global variable is mutable.
  Var
} derive(Eq, Hash, Debug)

///|
/// Returns `true` if this mutability is [`Mutability::Const`].
pub fn Mutability::is_const(self : Mutability) -> Bool {
  self is Const
}

///|
/// Returns `true` if this mutability is [`Mutability::Var`].
pub fn Mutability::is_mut(self : Mutability) -> Bool {
  self is Var
}

///|
/// The type of a global variable.
pub struct GlobalType {
  /// The value type of the global variable.
  content : ValType
  /// The mutability of the global variable.
  mutability : Mutability
} derive(Eq, Hash, Debug)

///|
/// Creates a new [`GlobalType`] from the given [`ValType`] and [`Mutability`].
pub fn GlobalType::new(
  content : ValType,
  mutability : Mutability,
) -> GlobalType {
  { content, mutability, }
}

///|
/// Returns the [`ValType`] of the global variable.
pub fn GlobalType::content(self : GlobalType) -> ValType {
  self.content
}

///|
/// Returns the [`Mutability`] of the global variable.
pub fn GlobalType::mutability(self : GlobalType) -> Mutability {
  self.mutability
}

///|
/// A global variable entity.
pub struct Global {
  /// The current value of the global variable.
  mut value : UntypedVal
  /// The type of the global variable.
  ty : GlobalType
}

///|
/// Creates a new global entity with the given initial value and mutability.
pub fn Global::new(initial_value : TypedVal, mutability : Mutability) -> Global {
  {
    ty: GlobalType::new(initial_value.ty(), mutability),
    value: initial_value.untyped(),
  }
}

///|
/// Returns the [`GlobalType`] of the global variable.
pub fn Global::ty(self : Global) -> GlobalType {
  self.ty
}

///|
/// Sets a new value to the global variable.
///
/// # Errors
///
/// - If the [`Global`] is immutable.
/// - If `new_value` does not match the type of the [`Global`].
pub fn Global::set(
  self : Global,
  new_value : TypedVal,
) -> Unit raise GlobalError {
  if !self.ty().mutability().is_mut() {
    raise ImmutableWrite
  }
  if self.ty().content() != new_value.ty() {
    raise TypeMismatch
  }
  self.value = new_value.untyped()
}

///|
/// Returns the current [`TypedVal`] of the [`Global`].
pub fn Global::get(self : Global) -> TypedVal {
  TypedVal::new(self.ty().content(), self.value)
}

///|
/// Returns the current [`UntypedVal`] of the [`Global`].
pub fn Global::get_untyped(self : Global) -> UntypedVal {
  self.value
}

///|
/// Writes the [`UntypedVal`] of the [`Global`] without any checks.
///
/// # Note
///
/// Replaces writes through upstream's `Global::get_untyped_ptr` (a raw
/// pointer to the value used by the executor for `global.set`).
pub fn Global::set_untyped(self : Global, value : UntypedVal) -> Unit {
  self.value = value
}
