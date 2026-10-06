// Port of `typst-library/src/layout/sides.rs`.

///|
/// A container with left, top, right and bottom components.
pub(all) struct Sides[T] {
  /// The value for the left side.
  left : T
  /// The value for the top side.
  top : T
  /// The value for the right side.
  right : T
  /// The value for the bottom side.
  bottom : T
} derive(Default, Eq, Hash, Debug)

///|
/// Create a new instance from the four components.
pub fn[T] Sides::new(left : T, top : T, right : T, bottom : T) -> Sides[T] {
  { left, top, right, bottom, }
}

///|
/// Create an instance with four equal components.
pub fn[T] Sides::splat(value : T) -> Sides[T] {
  { left: value, top: value, right: value, bottom: value, }
}

///|
/// Map the individual fields with `f`.
pub fn[T, U] Sides::map(self : Sides[T], f : (T) -> U) -> Sides[U] {
  {
    left: f(self.left),
    top: f(self.top),
    right: f(self.right),
    bottom: f(self.bottom),
  }
}

///|
/// Zip two instances into one.
pub fn[T, U] Sides::zip(self : Sides[T], other : Sides[U]) -> Sides[(T, U)] {
  {
    left: (self.left, other.left),
    top: (self.top, other.top),
    right: (self.right, other.right),
    bottom: (self.bottom, other.bottom),
  }
}

///|
/// An iterator over the sides, starting with the left side, clockwise.
pub fn[T] Sides::iter(self : Sides[T]) -> Iter[T] {
  [self.left, self.top, self.right, self.bottom].iter()
}

///|
/// Map two adjacent sides into a corner `f`.
pub fn[T, U] Sides::map_corners(self : Sides[T], f : (T, T) -> U) -> Corners[U] {
  {
    top_left: f(self.left, self.top),
    top_right: f(self.top, self.right),
    bottom_right: f(self.right, self.bottom),
    bottom_left: f(self.bottom, self.left),
  }
}

///|
/// Whether all sides are equal.
pub fn[T : Eq] Sides::is_uniform(self : Sides[T]) -> Bool {
  self.left == self.top && self.top == self.right && self.right == self.bottom
}

///|
/// Unwrap-or the individual sides.
pub fn[T] Sides::unwrap_or(self : Sides[T?], default : T) -> Sides[T] {
  self.map(v => v.unwrap_or(default))
}

///|
/// The component for the given side (upstream `Get<Side>`).
pub fn[T] Sides::get(self : Sides[T], side : Side) -> T {
  match side {
    Left => self.left
    Top => self.top
    Right => self.right
    Bottom => self.bottom
  }
}

///|
pub impl[T : Reflect] Reflect for Sides[T?] with fn input() {
  T::input().union_with(Type(Type::dict()))
}

///|
pub impl[T : Reflect] Reflect for Sides[T?] with fn output() {
  T::output().union_with(Type(Type::dict()))
}

///|
pub impl[T : Reflect] Reflect for Sides[T?] with fn castable(value) {
  value is Dict(_) || T::castable(value)
}

///|
pub impl[T : IntoValue + Eq] IntoValue for Sides[T?] with fn into_value(self) {
  if self.is_uniform() && self.left is Some(left) {
    return IntoValue::into_value(left)
  }
  let dict = Dict::new()
  let handle = (key : String, component : T?) => {
    if component is Some(c) {
      dict.insert(key, IntoValue::into_value(c))
    }
  }
  handle("left", self.left)
  handle("top", self.top)
  handle("right", self.right)
  handle("bottom", self.bottom)
  Dict(dict)
}

///|
pub extend Sides with IntoValue::{into_value}

///|
pub impl[T : FromValue] FromValue for Sides[T?] with fn from_value(value) {
  let expected_keys = ["left", "top", "right", "bottom", "x", "y", "rest"]
  if value is Dict(dict) {
    if dict.is_empty() {
      return Sides::splat(None)
    } else if dict.map.keys().any(key => expected_keys.contains(key)) {
      let dict = dict.copy()
      let take = (key : String) => {
        if dict.contains(key) {
          Some(T::from_value(dict.take(key)))
        } else {
          None
        }
      }
      let rest = take("rest")
      let x = take("x") |> opt_or(rest)
      let y = take("y") |> opt_or(rest)
      let sides = {
        left: take("left") |> opt_or(x),
        top: take("top") |> opt_or(y),
        right: take("right") |> opt_or(x),
        bottom: take("bottom") |> opt_or(y),
      }
      dict.finish(expected_keys)
      return sides
    }
  }
  if castable_of((Ty::new() : Ty[T]), value) {
    Sides::splat(Some(T::from_value(value)))
  } else if value is Dict(dict) {
    let keys = dict.map.keys().collect()
    // Do not hint at expected_keys, because T may be castable from Dict
    // objects with other sets of expected keys.
    bail(Dict::unexpected_keys(keys, None))
  } else {
    raise HintedError(
      input_of((Ty::new() : Ty[T])).union_with(Type(Type::dict())).error(value),
    )
  }
}

///|
/// The four sides of objects.
pub(all) enum Side {
  /// The left side.
  Left
  /// The top side.
  Top
  /// The right side.
  Right
  /// The bottom side.
  Bottom
} derive(Eq, Hash, Debug)

///|
/// The opposite side.
pub fn Side::inv(self : Side) -> Side {
  match self {
    Left => Right
    Top => Bottom
    Right => Left
    Bottom => Top
  }
}

///|
/// The next side, clockwise.
pub fn Side::next_cw(self : Side) -> Side {
  match self {
    Left => Top
    Top => Right
    Right => Bottom
    Bottom => Left
  }
}

///|
/// The next side, counter-clockwise.
pub fn Side::next_ccw(self : Side) -> Side {
  match self {
    Left => Bottom
    Top => Left
    Right => Top
    Bottom => Right
  }
}

///|
/// The first corner of the side in clockwise order.
pub fn Side::start_corner(self : Side) -> Corner {
  match self {
    Left => BottomLeft
    Top => TopLeft
    Right => TopRight
    Bottom => BottomRight
  }
}

///|
/// The second corner of the side in clockwise order.
pub fn Side::end_corner(self : Side) -> Corner {
  self.next_cw().start_corner()
}

///|
/// Return the corresponding axis.
pub fn Side::axis(self : Side) -> Axis {
  match self {
    Left | Right => Y
    Top | Bottom => X
  }
}

///|
pub impl Reflect for Side with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for Side with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for Side with fn castable(value) {
  value is Dyn(Alignment(_))
}

///|
pub impl IntoValue for Side with fn into_value(self) {
  Alignment::from_side(self).into_value()
}

///|
pub impl FromValue for Side with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) =>
      match align {
        H(Left) => Left
        H(Right) => Right
        V(Top) => Top
        V(Bottom) => Bottom
        _ => bail("cannot convert this alignment to a side")
      }
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
pub impl[T : Fold] Fold for Sides[T?] with fn fold(self, outer) {
  // Usually, folding an inner `None` with an `outer` prefers the explicit
  // `None`. However, here `None` means unspecified and thus we want
  // `outer`, so we use `fold_or` to opt into such behavior.
  self.zip(outer).map(p => fold_or(p.0, p.1))
}

///|
pub extend Sides with Fold::{fold}

///|
/// Rust `Option::or`: keeps `self` if it is `Some`, otherwise `other`.
fn[T] opt_or(this : T?, other : T?) -> T? {
  match this {
    Some(_) => this
    None => other
  }
}
