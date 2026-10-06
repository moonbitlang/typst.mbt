// Port of the resolved forms of `typst-library/src/visualize/stroke.rs`:
// `Stroke<Abs>` (`ResolvedStroke` here), `DashPattern<Abs, DashLength<Abs>>`
// and `FixedStroke`.

///|
/// A stroke whose lengths have been resolved (upstream `Stroke<Abs>`).
pub(all) struct ResolvedStroke {
  /// The stroke's paint.
  paint : Smart[Paint]
  /// The stroke's thickness.
  thickness : Smart[Abs]
  /// The stroke's line cap.
  cap : Smart[LineCap]
  /// The stroke's line join.
  join : Smart[LineJoin]
  /// The stroke's line dash pattern.
  dash : Smart[ResolvedDashPattern?]
  /// The miter limit.
  miter_limit : Smart[Ratio]
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResolvedStroke with Eq::{not_equal, equal}

///|
/// A resolved dash pattern (upstream `DashPattern<Abs, DashLength<Abs>>`).
pub(all) struct ResolvedDashPattern {
  /// The dash array.
  array : Array[ResolvedDashLength]
  /// The dash phase.
  phase : Abs
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResolvedDashPattern with Eq::{not_equal, equal}

///|
/// A resolved dash length (upstream `DashLength<Abs>`).
pub(all) enum ResolvedDashLength {
  LineWidth
  Length(Abs)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResolvedDashLength with Eq::{not_equal, equal}

///|
/// Resolve the length, taking the thickness into account (upstream
/// `DashLength::finish`).
pub fn ResolvedDashLength::finish(
  self : ResolvedDashLength,
  width : Abs,
) -> Abs {
  match self {
    LineWidth => width
    Length(l) => l
  }
}

///|
/// Resolve the stroke's lengths (upstream `Resolve for Stroke`).
pub fn Stroke::resolve(self : Stroke, styles : StyleChain) -> ResolvedStroke {
  {
    paint: self.paint,
    thickness: self.thickness.map(l => l.resolve(styles)),
    cap: self.cap,
    join: self.join,
    dash: self.dash.map(dash => {
      dash.map(dash => {
        array: dash.array.map(l => {
          match l {
            DashLength::LineWidth => ResolvedDashLength::LineWidth
            DashLength::Length(l) =>
              ResolvedDashLength::Length(l.resolve(styles))
          }
        }),
        phase: dash.phase.resolve(styles),
      })
    }),
    miter_limit: self.miter_limit,
  }
}

///|
/// Upstream `Fold for Stroke<T>` at `T = Abs`.
pub impl Fold for ResolvedStroke with fn fold(self, outer) {
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
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResolvedStroke with Fold::{fold}

///|
/// Convert back to a stroke with (already resolved) lengths (upstream
/// `Stroke<Abs>::map(Length::from)`).
pub fn ResolvedStroke::to_length_stroke(self : ResolvedStroke) -> Stroke {
  {
    paint: self.paint,
    thickness: self.thickness.map(Length::from_abs),
    cap: self.cap,
    join: self.join,
    dash: self.dash.map(dash => {
      dash.map(dash => {
        array: dash.array.map(l => {
          match l {
            ResolvedDashLength::LineWidth => DashLength::LineWidth
            ResolvedDashLength::Length(l) =>
              DashLength::Length(Length::from_abs(l))
          }
        }),
        phase: Length::from_abs(dash.phase),
      })
    }),
    miter_limit: self.miter_limit,
  }
}

///|
/// Unpack the stroke, filling missing fields from the `default`.
pub fn ResolvedStroke::unwrap_or(
  self : ResolvedStroke,
  default : FixedStroke,
) -> FixedStroke {
  let thickness = self.thickness.unwrap_or(default.thickness)
  let dash = match self.dash {
    Custom(dash) =>
      dash.map(dash => FixedDashPattern::{
        array: dash.array.map(l => l.finish(thickness)),
        phase: dash.phase,
      })
    Auto => default.dash
  }
  {
    paint: self.paint.unwrap_or(default.paint),
    thickness,
    cap: self.cap.unwrap_or(default.cap),
    join: self.join.unwrap_or(default.join),
    dash,
    miter_limit: self.miter_limit.unwrap_or(default.miter_limit),
  }
}

///|
/// Unpack the stroke, filling missing fields with the default values.
pub fn ResolvedStroke::unwrap_or_default(self : ResolvedStroke) -> FixedStroke {
  self.unwrap_or(FixedStroke::default())
}

///|
/// A fully specified stroke of a geometric shape.
pub(all) struct FixedStroke {
  /// The stroke's paint.
  paint : Paint
  /// The stroke's thickness.
  thickness : Abs
  /// The stroke's line cap.
  cap : LineCap
  /// The stroke's line join.
  join : LineJoin
  /// The stroke's line dash pattern.
  dash : FixedDashPattern?
  /// The miter limit. Defaults to 4.0, same as `tiny-skia`.
  miter_limit : Ratio
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FixedStroke with Eq::{not_equal, equal}

///|
/// A fully resolved dash pattern (upstream `DashPattern<Abs, Abs>`).
pub(all) struct FixedDashPattern {
  /// The dash array.
  array : Array[Abs]
  /// The dash phase.
  phase : Abs
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FixedDashPattern with Eq::{not_equal, equal}

///|
/// Create a stroke from a paint and a thickness.
pub fn FixedStroke::from_pair(paint : Paint, thickness : Abs) -> FixedStroke {
  { ..FixedStroke::default(), paint, thickness, }
}

///|
pub impl Default for FixedStroke with fn default() {
  {
    paint: Solid(color_black),
    thickness: Abs::pt(1.0),
    cap: Butt,
    join: Miter,
    dash: None,
    miter_limit: Ratio::new(4.0),
  }
}

///|
pub extend FixedStroke with Default::{default}
