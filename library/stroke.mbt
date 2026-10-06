// Port of `typst-library/src/visualize/stroke.rs` (`Stroke<Length>`; the
// resolved `Stroke<Abs>` and `FixedStroke` are layout concerns).

///|
/// Defines how to draw a line.
pub(all) struct Stroke {
  /// The stroke's paint.
  paint : Smart[Paint]
  /// The stroke's thickness.
  thickness : Smart[Length]
  /// The stroke's line cap.
  cap : Smart[LineCap]
  /// The stroke's line join.
  join : Smart[LineJoin]
  /// The stroke's line dash pattern.
  dash : Smart[DashPattern?]
  /// The miter limit.
  miter_limit : Smart[Ratio]
} derive(Eq)

///|
pub impl Default for Stroke with fn default() {
  {
    paint: Auto,
    thickness: Auto,
    cap: Auto,
    join: Auto,
    dash: Auto,
    miter_limit: Auto,
  }
}

///|
/// Create a stroke from a paint and a thickness.
pub fn Stroke::from_pair(paint : Paint, thickness : Length) -> Stroke {
  { ..Stroke::default(), paint: Custom(paint), thickness: Custom(thickness), }
}

///|
/// Create a stroke from a paint and a thickness given as values (upstream
/// `Stroke::from_pair` in `ops::add`).
pub fn stroke_from_pair(a : Value, b : Value) -> Value raise HintedError {
  let (paint, thickness) = match (a, b) {
    (Length(l), p) | (p, Length(l)) => (Paint::from_value(p), l)
    _ => bail("cannot create a stroke from \{a.ty()} and \{b.ty()}")
  }
  Stroke::from_pair(paint, thickness).into_value()
}

///|
/// Create a new stroke from a dictionary or the individual components.
fn impl_stroke_construct(args : Args) -> Stroke raise SourceError {
  match args.eat() {
    Some((stroke : Stroke)) => return stroke
    None => ()
  }
  let paint : Smart[Paint] = args.named("paint").unwrap_or(Auto)
  let thickness : Smart[Length] = args.named("thickness").unwrap_or(Auto)
  let cap : Smart[LineCap] = args.named("cap").unwrap_or(Auto)
  let join : Smart[LineJoin] = args.named("join").unwrap_or(Auto)
  let dash : Smart[DashPattern?] = args.named("dash").unwrap_or(Auto)
  let miter_limit : Smart[Double] = args.named("miter-limit").unwrap_or(Auto)
  {
    paint,
    thickness,
    cap,
    join,
    dash,
    miter_limit: miter_limit.map(Ratio::new),
  }
}

///|
pub fn Stroke::repr(self : Stroke) -> String {
  let r = StringBuilder()
  let { paint, thickness, cap, join, dash, miter_limit, } = self
  if cap.is_auto() && join.is_auto() && dash.is_auto() && miter_limit.is_auto() {
    match (paint, thickness) {
      (Custom(paint), Custom(thickness)) => {
        r.write_string(thickness.repr())
        r.write_string(" + ")
        r.write_string(paint.repr())
      }
      (Custom(paint), Auto) => r.write_string(paint.repr())
      (Auto, Custom(thickness)) => r.write_string(thickness.repr())
      (Auto, Auto) => r.write_string("stroke()")
    }
  } else {
    r.write_char('(')
    let mut sep = ""
    if paint is Custom(paint) {
      r.write_string(sep)
      r.write_string("paint: ")
      r.write_string(paint.repr())
      sep = ", "
    }
    if thickness is Custom(thickness) {
      r.write_string(sep)
      r.write_string("thickness: ")
      r.write_string(thickness.repr())
      sep = ", "
    }
    if cap is Custom(cap) {
      r.write_string(sep)
      r.write_string("cap: ")
      r.write_string(cap.repr())
      sep = ", "
    }
    if join is Custom(join) {
      r.write_string(sep)
      r.write_string("join: ")
      r.write_string(join.repr())
      sep = ", "
    }
    if dash is Custom(dash) {
      r.write_string(sep)
      r.write_string("dash: ")
      match dash {
        Some(dash) => r.write_string(dash.repr())
        None => r.write_string("none")
      }
      sep = ", "
    }
    if miter_limit is Custom(miter_limit) {
      r.write_string(sep)
      r.write_string("miter-limit: ")
      r.write_string(Value::Float(miter_limit.get()).repr())
    }
    r.write_char(')')
  }
  r.to_string()
}

///|
/// The fields of a stroke (upstream `fields::field`); `None` if missing.
pub fn Stroke::field(self : Stroke, field : String) -> Value? {
  match field {
    "paint" => Some(self.paint.into_value())
    "thickness" => Some(self.thickness.into_value())
    "cap" => Some(self.cap.into_value())
    "join" => Some(self.join.into_value())
    "dash" => Some(self.dash.into_value())
    "miter-limit" =>
      Some(self.miter_limit.map(limit => limit.get()).into_value())
    _ => None
  }
}

///|
pub impl Fold for Stroke with fn fold(self, outer) {
  {
    paint: self.paint.or_(outer.paint),
    thickness: self.thickness.or_(outer.thickness),
    cap: self.cap.or_(outer.cap),
    join: self.join.or_(outer.join),
    dash: self.dash.or_(outer.dash),
    miter_limit: self.miter_limit.or_(outer.miter_limit),
  }
}

///|
pub impl Reflect for Stroke with fn input() {
  Length::input()
  .union_with(Color::input())
  .union_with(Type(Type::gradient()))
  .union_with(Type(Type::tiling()))
  .union_with(Type(Type::dict()))
  .union_with(Type(Type::stroke()))
}

///|
pub impl Reflect for Stroke with fn output() {
  Type(Type::stroke())
}

///|
pub impl Reflect for Stroke with fn castable(v) {
  v
  is (Dyn(Stroke(_)) | Length(_) | Color(_) | Gradient(_) | Tiling(_) | Dict(_))
}

///|
pub extend Stroke with Reflect::{output, input, castable}

///|
pub impl IntoValue for Stroke with fn into_value(self) {
  Dyn(Stroke(self))
}

///|
pub impl FromValue for Stroke with fn from_value(v) {
  match v {
    Dyn(Stroke(stroke)) => stroke
    Length(thickness) => { ..Stroke::default(), thickness: Custom(thickness), }
    Color(color) => { ..Stroke::default(), paint: Custom(Solid(color)), }
    Gradient(gradient) =>
      { ..Stroke::default(), paint: Custom(Gradient(gradient)), }
    Tiling(tiling) => { ..Stroke::default(), paint: Custom(Tiling(tiling)), }
    Dict(dict) => {
      let dict = dict.copy()
      // Get a value by key, accepting either Auto or something convertible
      // to type T.
      let paint : Smart[Paint] = stroke_dict_take(dict, "paint")
      let thickness : Smart[Length] = stroke_dict_take(dict, "thickness")
      let cap : Smart[LineCap] = stroke_dict_take(dict, "cap")
      let join : Smart[LineJoin] = stroke_dict_take(dict, "join")
      let dash : Smart[DashPattern?] = stroke_dict_take(dict, "dash")
      let miter_limit : Smart[Double] = stroke_dict_take(dict, "miter-limit")
      dict.finish(["paint", "thickness", "cap", "join", "dash", "miter-limit"])
      {
        paint,
        thickness,
        cap,
        join,
        dash,
        miter_limit: miter_limit.map(Ratio::new),
      }
    }
    v => raise HintedError(Stroke::input().error(v))
  }
}

///|
/// The line cap of a stroke.
pub(all) enum LineCap {
  /// Square stroke cap with the edge at the stroke's end point.
  Butt
  /// Circular stroke cap centered at the stroke's end point.
  Round
  /// Square stroke cap centered at the stroke's end point.
  Square
} derive(Eq, Hash, Debug)

///|
fn LineCap::name(self : LineCap) -> String {
  match self {
    Butt => "butt"
    Round => "round"
    Square => "square"
  }
}

///|
pub fn LineCap::repr(self : LineCap) -> String {
  repr_str(self.name())
}

///|
pub impl Reflect for LineCap with fn input() {
  Union([
    Value(
      Str("butt"),
      "Square stroke cap with the edge at the stroke's end point.",
    ),
    Value(
      Str("round"),
      "Circular stroke cap centered at the stroke's end point.",
    ),
    Value(
      Str("square"),
      "Square stroke cap centered at the stroke's end point.",
    ),
  ])
}

///|
pub impl Reflect for LineCap with fn output() {
  LineCap::input()
}

///|
pub impl Reflect for LineCap with fn castable(v) {
  v is Str("butt" | "round" | "square")
}

///|
pub extend LineCap with Reflect::{output, input, castable}

///|
pub impl IntoValue for LineCap with fn into_value(self) {
  Str(self.name())
}

///|
pub impl FromValue for LineCap with fn from_value(v) {
  match v {
    Str("butt") => Butt
    Str("round") => Round
    Str("square") => Square
    v => raise HintedError(LineCap::input().error(v))
  }
}

///|
/// The line join of a stroke.
pub(all) enum LineJoin {
  /// Segments are joined with sharp edges. Sharp bends exceeding the miter
  /// limit are bevelled instead.
  Miter
  /// Segments are joined with circular corners.
  Round
  /// Segments are joined with a bevel (a straight edge connecting the butts
  /// of the joined segments).
  Bevel
} derive(Eq, Hash, Debug)

///|
fn LineJoin::name(self : LineJoin) -> String {
  match self {
    Miter => "miter"
    Round => "round"
    Bevel => "bevel"
  }
}

///|
pub fn LineJoin::repr(self : LineJoin) -> String {
  repr_str(self.name())
}

///|
pub impl Reflect for LineJoin with fn input() {
  Union([
    Value(
      Str("miter"),
      "Segments are joined with sharp edges. Sharp bends exceeding the miter\nlimit are bevelled instead.",
    ),
    Value(Str("round"), "Segments are joined with circular corners."),
    Value(
      Str("bevel"),
      "Segments are joined with a bevel (a straight edge connecting the butts\nof the joined segments).",
    ),
  ])
}

///|
pub impl Reflect for LineJoin with fn output() {
  LineJoin::input()
}

///|
pub impl Reflect for LineJoin with fn castable(v) {
  v is Str("miter" | "round" | "bevel")
}

///|
pub extend LineJoin with Reflect::{output, input, castable}

///|
pub impl IntoValue for LineJoin with fn into_value(self) {
  Str(self.name())
}

///|
pub impl FromValue for LineJoin with fn from_value(v) {
  match v {
    Str("miter") => Miter
    Str("round") => Round
    Str("bevel") => Bevel
    v => raise HintedError(LineJoin::input().error(v))
  }
}

///|
/// A line dash pattern.
pub(all) struct DashPattern {
  /// The dash array.
  array : Array[DashLength]
  /// The dash phase.
  phase : Length
} derive(Eq)

///|
pub fn DashPattern::repr(self : DashPattern) -> String {
  let r = StringBuilder()
  r.write_string("(array: (")
  for i, elem in self.array {
    if i != 0 {
      r.write_string(", ")
    }
    r.write_string(elem.repr())
  }
  r.write_string("), phase: ")
  r.write_string(self.phase.repr())
  r.write_char(')')
  r.to_string()
}

///|
fn DashPattern::from_array(array : Array[DashLength]) -> DashPattern {
  { array, phase: Length::zero(), }
}

///|
fn dash_pt(pt : Double) -> DashLength {
  Length(Length::from_abs(Abs::pt(pt)))
}

///|
/// The named dash patterns (same names as tikz).
let dash_patterns : ReadOnlyArray[(String, String, () -> DashPattern)] = [
  ("solid", "", () => DashPattern::from_array([])),
  (
    "dotted",
    "`{(\"dot\", 2pt)}`",
    () => DashPattern::from_array([LineWidth, dash_pt(2.0)]),
  ),
  (
    "densely-dotted",
    "`{(\"dot\", 1pt)}`",
    () => DashPattern::from_array([LineWidth, dash_pt(1.0)]),
  ),
  (
    "loosely-dotted",
    "`{(\"dot\", 4pt)}`",
    () => DashPattern::from_array([LineWidth, dash_pt(4.0)]),
  ),
  (
    "dashed",
    "`{(3pt, 3pt)}`",
    () => DashPattern::from_array([dash_pt(3.0), dash_pt(3.0)]),
  ),
  (
    "densely-dashed",
    "`{(3pt, 2pt)}`",
    () => DashPattern::from_array([dash_pt(3.0), dash_pt(2.0)]),
  ),
  (
    "loosely-dashed",
    "`{(3pt, 6pt)}`",
    () => DashPattern::from_array([dash_pt(3.0), dash_pt(6.0)]),
  ),
  (
    "dash-dotted",
    "`{(3pt, 2pt, \"dot\", 2pt)}`",
    () => {
      DashPattern::from_array([
        dash_pt(3.0),
        dash_pt(2.0),
        LineWidth,
        dash_pt(2.0),
      ])
    },
  ),
  (
    "densely-dash-dotted",
    "`{(3pt, 1pt, \"dot\", 1pt)}`",
    () => {
      DashPattern::from_array([
        dash_pt(3.0),
        dash_pt(1.0),
        LineWidth,
        dash_pt(1.0),
      ])
    },
  ),
  (
    "loosely-dash-dotted",
    "`{(3pt, 4pt, \"dot\", 4pt)}`",
    () => {
      DashPattern::from_array([
        dash_pt(3.0),
        dash_pt(4.0),
        LineWidth,
        dash_pt(4.0),
      ])
    },
  ),
]

///|
pub impl Reflect for DashPattern with fn input() {
  let infos : Array[CastInfo] = dash_patterns[:].map(p => {
    CastInfo::Value(Str(p.0), p.1)
  })
  infos.push(Type(Type::array()))
  infos.push(Type(Type::dict()))
  Union(infos)
}

///|
pub impl Reflect for DashPattern with fn output() {
  DashPattern::input()
}

///|
pub impl Reflect for DashPattern with fn castable(v) {
  match v {
    Str(s) => dash_patterns.iter().any(p => p.0 == s)
    Array(_) | Dict(_) => true
    _ => false
  }
}

///|
pub extend DashPattern with Reflect::{output, input, castable}

///|
pub impl IntoValue for DashPattern with fn into_value(self) {
  let dict = Dict::new()
  dict.insert("array", IntoValue::into_value(self.array))
  dict.insert("phase", Length(self.phase))
  Dict(dict)
}

///|
pub impl FromValue for DashPattern with fn from_value(v) {
  match v {
    Str(s) =>
      for p in dash_patterns[:] {
        if p.0 == s {
          return (p.2)()
        }
      }
    _ => ()
  }
  match v {
    Array(_) => { array: FromValue::from_value(v), phase: Length::zero(), }
    Dict(dict) => {
      let dict = dict.copy()
      let array : Array[DashLength] = FromValue::from_value(dict.take("array"))
      let phase : Length = match dict.map.get("phase") {
        Some(_) => Length::from_value(dict.take("phase"))
        None => Length::zero()
      }
      dict.finish(["array", "phase"])
      { array, phase, }
    }
    v => raise HintedError(DashPattern::input().error(v))
  }
}

///|
/// The length of a dash in a line dash pattern.
pub(all) enum DashLength {
  LineWidth
  Length(Length)
} derive(Eq)

///|
pub fn DashLength::repr(self : DashLength) -> String {
  match self {
    LineWidth => repr_str("dot")
    Length(v) => v.repr()
  }
}

///|
pub impl Reflect for DashLength with fn input() {
  CastInfo::Value(Str("dot"), "").union_with(Length::input())
}

///|
pub impl Reflect for DashLength with fn output() {
  DashLength::input()
}

///|
pub impl Reflect for DashLength with fn castable(v) {
  v is (Str("dot") | Length(_))
}

///|
pub extend DashLength with Reflect::{output, input, castable}

///|
pub impl IntoValue for DashLength with fn into_value(self) {
  match self {
    LineWidth => Str("dot")
    Length(v) => Length(v)
  }
}

///|
pub impl FromValue for DashLength with fn from_value(v) {
  match v {
    Str("dot") => LineWidth
    Length(l) => Length(l)
    v => raise HintedError(DashLength::input().error(v))
  }
}

///|
/// Get a value by key, accepting either Auto or something convertible to
/// type T (the `take` helper in upstream's `Stroke` cast).
fn[T : FromValue] stroke_dict_take(
  dict : Dict,
  key : String,
) -> Smart[T] raise HintedError {
  match dict.map.get(key) {
    Some(_) => Smart::from_value(dict.take(key))
    None => Auto
  }
}
