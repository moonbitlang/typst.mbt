// Port of `typst-library/src/visualize/curve.rs` (element field types; the
// `Curve` geometry is a layout concern).

///|
/// A component used for curve creation: one of the curve elements.
pub(all) struct CurveComponent(Content)

///|
pub impl Reflect for CurveComponent with fn input() {
  Content::input()
}

///|
pub impl Reflect for CurveComponent with fn output() {
  Content::output()
}

///|
pub impl Reflect for CurveComponent with fn castable(v) {
  Content::castable(v)
}

///|
pub impl IntoValue for CurveComponent with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for CurveComponent with fn from_value(v) {
  let content = Content::from_value(v)
  let elem = content.elem()
  if elem == curve_move_elem() ||
    elem == curve_line_elem() ||
    elem == curve_quad_elem() ||
    elem == curve_cubic_elem() ||
    elem == curve_close_elem() {
    CurveComponent(content)
  } else {
    bail("expecting a curve element")
  }
}

///|
/// How to close a curve.
pub(all) enum CloseMode {
  /// Closes the curve with a smooth segment that takes into account the
  /// control point opposite the start point.
  Smooth
  /// Closes the curve with a straight line.
  Straight
} derive(Eq, Hash, Debug)

///|
pub impl Default for CloseMode with fn default() {
  Smooth
}

///|
pub impl Reflect for CloseMode with fn input() {
  Union([
    Value(
      Str("smooth"),
      "Closes the curve with a smooth segment that takes into account the\ncontrol point opposite the start point.",
    ),
    Value(Str("straight"), "Closes the curve with a straight line."),
  ])
}

///|
pub impl Reflect for CloseMode with fn output() {
  CloseMode::input()
}

///|
pub impl Reflect for CloseMode with fn castable(v) {
  v is Str("smooth" | "straight")
}

///|
pub impl IntoValue for CloseMode with fn into_value(self) {
  match self {
    Smooth => Str("smooth")
    Straight => Str("straight")
  }
}

///|
pub impl FromValue for CloseMode with fn from_value(v) {
  match v {
    Str("smooth") => Smooth
    Str("straight") => Straight
    v => raise HintedError(CloseMode::input().error(v))
  }
}
