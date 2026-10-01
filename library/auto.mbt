// Port of `typst-library/src/foundations/auto.rs`.

///|
/// A value that can be automatically determined.
pub(all) enum Smart[T] {
  /// The value should be determined smartly based on the circumstances.
  Auto
  /// A specific value.
  Custom(T)
} derive(Eq, Hash, Debug)

///|
pub impl[T] Default for Smart[T] with fn default() {
  Auto
}

///|
/// Whether the value is `Auto`.
pub fn[T] Smart::is_auto(self : Smart[T]) -> Bool {
  self is Auto
}

///|
/// Whether this holds a custom value.
pub fn[T] Smart::is_custom(self : Smart[T]) -> Bool {
  self is Custom(_)
}

///|
/// Whether this is a `Smart::Custom(x)` and `f(x)` is true.
pub fn[T] Smart::is_custom_and(self : Smart[T], f : (T) -> Bool) -> Bool {
  match self {
    Auto => false
    Custom(x) => f(x)
  }
}

///|
/// Returns the contained custom value.
///
/// If the value is [`Smart::Auto`], returns `None`.
pub fn[T] Smart::custom(self : Smart[T]) -> T? {
  match self {
    Auto => None
    Custom(x) => Some(x)
  }
}

///|
/// Map the contained custom value with `f`.
pub fn[T, U] Smart::map(self : Smart[T], f : (T) -> U) -> Smart[U] {
  match self {
    Auto => Auto
    Custom(x) => Custom(f(x))
  }
}

///|
/// Map the contained custom value with `f` if it contains a custom value,
/// otherwise returns `default`.
pub fn[T, U] Smart::map_or(self : Smart[T], default : U, f : (T) -> U) -> U {
  match self {
    Auto => default
    Custom(x) => f(x)
  }
}

///|
/// Keeps `self` if it contains a custom value, otherwise returns `other`.
pub fn[T] Smart::or_(self : Smart[T], other : Smart[T]) -> Smart[T] {
  match self {
    Custom(x) => Custom(x)
    Auto => other
  }
}

///|
/// Keeps `self` if it contains a custom value, otherwise returns the
/// output of the given function.
pub fn[T] Smart::or_else(self : Smart[T], f : () -> Smart[T]) -> Smart[T] {
  match self {
    Custom(x) => Custom(x)
    Auto => f()
  }
}

///|
/// Returns `Auto` if `self` is `Auto`, otherwise calls the provided
/// function on the contained value and returns the result.
pub fn[T, U] Smart::and_then(self : Smart[T], f : (T) -> Smart[U]) -> Smart[U] {
  match self {
    Auto => Auto
    Custom(x) => f(x)
  }
}

///|
/// Returns the contained custom value or a provided default value.
pub fn[T] Smart::unwrap_or(self : Smart[T], default : T) -> T {
  match self {
    Auto => default
    Custom(x) => x
  }
}

///|
/// Returns the contained custom value or computes a default value.
pub fn[T] Smart::unwrap_or_else(self : Smart[T], f : () -> T) -> T {
  match self {
    Auto => f()
    Custom(x) => x
  }
}

///|
/// Removes a single level of nesting, returns `Auto` if the inner or outer
/// value is `Auto`.
pub fn[T] Smart::flatten(self : Smart[Smart[T]]) -> Smart[T] {
  match self {
    Custom(Auto) | Auto => Auto
    Custom(Custom(v)) => Custom(v)
  }
}

///|
/// Upstream `From<Option<T>> for Smart<T>`.
pub fn[T] Smart::from_option(value : T?) -> Smart[T] {
  match value {
    Some(v) => Custom(v)
    None => Auto
  }
}

// The `auto` value itself (upstream `AutoValue`).

///|
/// The input cast info of `AutoValue`.
fn auto_value_input() -> CastInfo {
  Type(Type::auto())
}

///|
pub impl[T : Reflect] Reflect for Smart[T] with fn input() {
  T::input().union_with(auto_value_input())
}

///|
pub impl[T : Reflect] Reflect for Smart[T] with fn output() {
  T::output().union_with(auto_value_input())
}

///|
pub impl[T : Reflect] Reflect for Smart[T] with fn castable(value) {
  value is Auto || T::castable(value)
}

///|
pub impl[T : IntoValue] IntoValue for Smart[T] with fn into_value(self) {
  match self {
    Custom(v) => v.into_value()
    Auto => Value::Auto
  }
}

///|
pub impl[T : FromValue] FromValue for Smart[T] with fn from_value(value) {
  match value {
    Value::Auto => Auto
    v if T::castable(v) => Custom(T::from_value(v))
    _ =>
      raise HintedError(T::input().union_with(auto_value_input()).error(value))
  }
}
