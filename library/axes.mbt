// Port of `typst-library/src/layout/axes.rs`.

///|
/// A container with a horizontal and vertical component.
pub(all) struct Axes[T] {
  /// The horizontal component.
  x : T
  /// The vertical component.
  y : T
} derive(Default, Eq, Hash, Debug)

///|
/// Create a new instance from the two components.
pub fn[T] Axes::new(x : T, y : T) -> Axes[T] {
  { x, y, }
}

///|
/// Create a new instance with two equal components.
pub fn[T] Axes::splat(v : T) -> Axes[T] {
  { x: v, y: v, }
}

///|
/// Map the individual fields with `f`.
pub fn[T, U] Axes::map(self : Axes[T], f : (T) -> U) -> Axes[U] {
  { x: f(self.x), y: f(self.y), }
}

///|
/// Zip two instances into an instance over a tuple.
pub fn[T, U] Axes::zip(self : Axes[T], other : Axes[U]) -> Axes[(T, U)] {
  { x: (self.x, other.x), y: (self.y, other.y), }
}

///|
/// Apply a function to this and another-instance componentwise.
pub fn[T, V, U] Axes::zip_map(
  self : Axes[T],
  other : Axes[V],
  f : (T, V) -> U,
) -> Axes[U] {
  { x: f(self.x, other.x), y: f(self.y, other.y), }
}

///|
/// Whether a condition is true for at least one of fields.
pub fn[T] Axes::any(self : Axes[T], f : (T) -> Bool) -> Bool {
  f(self.x) || f(self.y)
}

///|
/// Whether a condition is true for both fields.
pub fn[T] Axes::all(self : Axes[T], f : (T) -> Bool) -> Bool {
  f(self.x) && f(self.y)
}

///|
/// The component for the given axis (upstream `Get<Axis>`).
pub fn[T] Axes::get(self : Axes[T], axis : Axis) -> T {
  match axis {
    X => self.x
    Y => self.y
  }
}

///|
/// Unwrap the individual fields.
pub fn[T] Axes::unwrap_or_smart(
  self : Axes[Smart[T]],
  other : Axes[T],
) -> Axes[T] {
  { x: self.x.unwrap_or(other.x), y: self.y.unwrap_or(other.y), }
}

///|
pub impl[T : Reflect] Reflect for Axes[T] with fn input() {
  ignore(T::input)
  Type(Type::array())
}

///|
pub impl[T : Reflect] Reflect for Axes[T] with fn output() {
  ignore(T::output)
  Type(Type::array())
}

///|
pub impl[T : Reflect] Reflect for Axes[T] with fn castable(value) {
  ignore(T::castable)
  value is Array(_)
}

///|
pub impl[T : FromValue] FromValue for Axes[T] with fn from_value(value) {
  let array : Arr = value.cast()
  match array.items {
    [a, b] => Axes::new(a.cast(), b.cast())
    _ =>
      bail_hinted("array must contain exactly two items", [
        "the first item determines the value for the X axis and the second item the value for the Y axis",
      ])
  }
}

///|
pub impl[T : IntoValue] IntoValue for Axes[T] with fn into_value(self) {
  Array(Arr::from_array([self.x.into_value(), self.y.into_value()]))
}

///|
pub extend Axes with IntoValue::{into_value}

///|
/// The two layouting axes.
pub(all) enum Axis {
  /// The horizontal axis.
  X
  /// The vertical  axis.
  Y
} derive(Eq, Hash, Debug)

///|
/// The other axis.
pub fn Axis::other(self : Axis) -> Axis {
  match self {
    X => Y
    Y => X
  }
}

///|
fn axis_input() -> CastInfo {
  Union([Value(Str("horizontal"), ""), Value(Str("vertical"), "")])
}

///|
pub impl Reflect for Axis with fn input() {
  axis_input()
}

///|
pub impl Reflect for Axis with fn output() {
  axis_input()
}

///|
pub impl Reflect for Axis with fn castable(value) {
  value is Str("horizontal" | "vertical")
}

///|
pub impl IntoValue for Axis with fn into_value(self) {
  match self {
    X => Str("horizontal")
    Y => Str("vertical")
  }
}

///|
pub impl FromValue for Axis with fn from_value(value) {
  match value {
    Str("horizontal") => X
    Str("vertical") => Y
    _ => raise HintedError(axis_input().error(value))
  }
}
