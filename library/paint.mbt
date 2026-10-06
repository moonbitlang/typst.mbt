// Port of `typst-library/src/visualize/paint.rs`.

///|
/// How a fill or stroke should be painted.
pub(all) enum Paint {
  /// A solid color.
  Solid(Color)
  /// A gradient.
  Gradient(Gradient)
  /// A tiling.
  Tiling(Tiling)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Paint with Eq::{not_equal, equal}

///|
/// Unwraps a solid color used for text rendering.
pub fn Paint::unwrap_solid(self : Paint) -> Color {
  match self {
    Solid(color) => color
    Gradient(_) | Tiling(_) => abort("expected solid color")
  }
}

///|
/// Gets the relative coordinate system for this paint.
pub fn Paint::relative(self : Paint) -> Smart[RelativeTo] {
  match self {
    Solid(_) => Auto
    Gradient(gradient) => gradient.relative()
    Tiling(tiling) => tiling.relative()
  }
}

///|
/// Turns this paint into a paint for a text decoration.
///
/// If this paint is a gradient, it will be converted to a gradient with
/// relative set to `RelativeTo::Parent`.
pub fn Paint::as_decoration(self : Paint) -> Paint {
  match self {
    Solid(color) => Solid(color)
    Gradient(gradient) => Gradient(gradient.with_relative(Parent))
    Tiling(tiling) => Tiling(tiling.with_relative(Parent))
  }
}

///|
pub fn Paint::repr(self : Paint) -> String {
  match self {
    Solid(color) => color.repr()
    Gradient(gradient) => gradient.repr()
    Tiling(tiling) => tiling.repr()
  }
}

///|
pub impl Reflect for Paint with fn input() {
  Color::input()
  .union_with(Type(Type::gradient()))
  .union_with(Type(Type::tiling()))
}

///|
pub impl Reflect for Paint with fn output() {
  Paint::input()
}

///|
pub impl Reflect for Paint with fn castable(v) {
  v is (Color(_) | Gradient(_) | Tiling(_))
}

///|
pub extend Paint with Reflect::{output, input, castable}

///|
pub impl IntoValue for Paint with fn into_value(self) {
  match self {
    Solid(color) => Color(color)
    Gradient(gradient) => Gradient(gradient)
    Tiling(tiling) => Tiling(tiling)
  }
}

///|
pub extend Paint with IntoValue::{into_value}

///|
pub impl FromValue for Paint with fn from_value(v) {
  match v {
    Color(color) => Solid(color)
    Gradient(gradient) => Gradient(gradient)
    Tiling(tiling) => Tiling(tiling)
    v => raise HintedError(Paint::input().error(v))
  }
}

///|
pub extend Paint with FromValue::{from_value}
