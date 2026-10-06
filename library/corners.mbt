// Port of `typst-library/src/layout/corners.rs`.

///|
/// A container with components for the four corners of a rectangle.
pub(all) struct Corners[T] {
  /// The value for the top left corner.
  top_left : T
  /// The value for the top right corner.
  top_right : T
  /// The value for the bottom right corner.
  bottom_right : T
  /// The value for the bottom left corner.
  bottom_left : T
} derive(Default, Eq, Hash, Debug)

///|
/// Create a new instance from the four components.
pub fn[T] Corners::new(
  top_left : T,
  top_right : T,
  bottom_right : T,
  bottom_left : T,
) -> Corners[T] {
  { top_left, top_right, bottom_right, bottom_left, }
}

///|
/// Create an instance with four equal components.
pub fn[T] Corners::splat(value : T) -> Corners[T] {
  {
    top_left: value,
    top_right: value,
    bottom_right: value,
    bottom_left: value,
  }
}

///|
/// Map the individual fields with `f`.
pub fn[T, U] Corners::map(self : Corners[T], f : (T) -> U) -> Corners[U] {
  {
    top_left: f(self.top_left),
    top_right: f(self.top_right),
    bottom_right: f(self.bottom_right),
    bottom_left: f(self.bottom_left),
  }
}

///|
/// Zip two instances into one.
pub fn[T, U] Corners::zip(
  self : Corners[T],
  other : Corners[U],
) -> Corners[(T, U)] {
  {
    top_left: (self.top_left, other.top_left),
    top_right: (self.top_right, other.top_right),
    bottom_right: (self.bottom_right, other.bottom_right),
    bottom_left: (self.bottom_left, other.bottom_left),
  }
}

///|
/// An iterator over the corners, starting with the top left corner,
/// clockwise.
pub fn[T] Corners::iter(self : Corners[T]) -> Iter[T] {
  [self.top_left, self.top_right, self.bottom_right, self.bottom_left].iter()
}

///|
/// Whether all corners are equal.
pub fn[T : Eq] Corners::is_uniform(self : Corners[T]) -> Bool {
  self.top_left == self.top_right &&
  self.top_right == self.bottom_right &&
  self.bottom_right == self.bottom_left
}

///|
/// Unwrap-or the individual corners.
pub fn[T] Corners::unwrap_or(self : Corners[T?], default : T) -> Corners[T] {
  self.map(v => v.unwrap_or(default))
}

///|
/// The component for the given corner (upstream `Get<Corner>`).
pub fn[T] Corners::get(self : Corners[T], corner : Corner) -> T {
  match corner {
    TopLeft => self.top_left
    TopRight => self.top_right
    BottomRight => self.bottom_right
    BottomLeft => self.bottom_left
  }
}

///|
pub impl[T : Reflect] Reflect for Corners[T?] with fn input() {
  T::input().union_with(Type(Type::dict()))
}

///|
pub impl[T : Reflect] Reflect for Corners[T?] with fn output() {
  T::output().union_with(Type(Type::dict()))
}

///|
pub impl[T : Reflect] Reflect for Corners[T?] with fn castable(value) {
  value is Dict(_) || T::castable(value)
}

///|
pub impl[T : IntoValue + Eq] IntoValue for Corners[T?] with fn into_value(self) {
  if self.is_uniform() && self.top_left is Some(top_left) {
    return IntoValue::into_value(top_left)
  }
  let dict = Dict::new()
  let handle = (key : String, component : T?) => {
    if component is Some(c) {
      dict.insert(key, IntoValue::into_value(c))
    }
  }
  handle("top-left", self.top_left)
  handle("top-right", self.top_right)
  handle("bottom-right", self.bottom_right)
  handle("bottom-left", self.bottom_left)
  Dict(dict)
}

///|
pub impl[T : FromValue] FromValue for Corners[T?] with fn from_value(value) {
  let expected_keys = [
    "top-left", "top-right", "bottom-right", "bottom-left", "left", "top", "right",
    "bottom", "rest",
  ]
  if value is Dict(dict) {
    if dict.is_empty() {
      return Corners::splat(None)
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
      let left = take("left") |> opt_or(rest)
      let top = take("top") |> opt_or(rest)
      let right = take("right") |> opt_or(rest)
      let bottom = take("bottom") |> opt_or(rest)
      let corners = {
        top_left: take("top-left") |> opt_or(top) |> opt_or(left),
        top_right: take("top-right") |> opt_or(top) |> opt_or(right),
        bottom_right: take("bottom-right") |> opt_or(bottom) |> opt_or(right),
        bottom_left: take("bottom-left") |> opt_or(bottom) |> opt_or(left),
      }
      dict.finish(expected_keys)
      return corners
    }
  }
  if castable_of((Ty::new() : Ty[T]), value) {
    Corners::splat(Some(T::from_value(value)))
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
pub impl[T : Fold] Fold for Corners[T?] with fn fold(self, outer) {
  // Usually, folding an inner `None` with an `outer` prefers the explicit
  // `None`. However, here `None` means unspecified and thus we want
  // `outer`, so we use `fold_or` to opt into such behavior.
  self.zip(outer).map(p => fold_or(p.0, p.1))
}

///|
/// The four corners of a rectangle.
pub(all) enum Corner {
  /// The top left corner.
  TopLeft
  /// The top right corner.
  TopRight
  /// The bottom right corner.
  BottomRight
  /// The bottom left corner.
  BottomLeft
} derive(Eq, Hash, Debug)

///|
/// The opposite corner.
pub fn Corner::inv(self : Corner) -> Corner {
  match self {
    TopLeft => BottomRight
    TopRight => BottomLeft
    BottomRight => TopLeft
    BottomLeft => TopRight
  }
}

///|
/// The next corner, clockwise.
pub fn Corner::next_cw(self : Corner) -> Corner {
  match self {
    TopLeft => TopRight
    TopRight => BottomRight
    BottomRight => BottomLeft
    BottomLeft => TopLeft
  }
}

///|
/// The next corner, counter-clockwise.
pub fn Corner::next_ccw(self : Corner) -> Corner {
  match self {
    TopLeft => BottomLeft
    TopRight => TopLeft
    BottomRight => TopRight
    BottomLeft => BottomRight
  }
}

///|
/// The next side, clockwise.
pub fn Corner::side_cw(self : Corner) -> Side {
  match self {
    TopLeft => Top
    TopRight => Right
    BottomRight => Bottom
    BottomLeft => Left
  }
}

///|
/// The next side, counter-clockwise.
pub fn Corner::side_ccw(self : Corner) -> Side {
  match self {
    TopLeft => Left
    TopRight => Top
    BottomRight => Right
    BottomLeft => Bottom
  }
}
