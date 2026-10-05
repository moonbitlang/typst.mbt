// Port of `typst-library/src/visualize/gradient.rs` (value-level parts;
// sampling at coordinates and export helpers are layout concerns).

///|
/// A color gradient.
pub(all) enum Gradient {
  Linear(LinearGradient)
  Radial(RadialGradient)
  Conic(ConicGradient)
} derive(Eq)

///|
/// A gradient that interpolates between two colors along an axis.
pub(all) struct LinearGradient {
  /// The color stops of this gradient.
  stops : Array[(Color, Ratio)]
  /// The direction of this gradient.
  angle : Angle
  /// The color space in which to interpolate the gradient.
  space : ColorSpace
  /// The relative placement of the gradient.
  relative : Smart[RelativeTo]
  /// Whether to anti-alias the gradient (used for sharp gradients).
  anti_alias : Bool
} derive(Eq)

///|
/// A gradient that interpolates between two colors along a circle.
pub(all) struct RadialGradient {
  /// The color stops of this gradient.
  stops : Array[(Color, Ratio)]
  /// The center of last circle of this gradient.
  center : Axes[Ratio]
  /// The radius of last circle of this gradient.
  radius : Ratio
  /// The center of the focal circle of this gradient.
  focal_center : Axes[Ratio]
  /// The radius of the focal circle of this gradient.
  focal_radius : Ratio
  /// The color space in which to interpolate the gradient.
  space : ColorSpace
  /// The relative placement of the gradient.
  relative : Smart[RelativeTo]
  /// Whether to anti-alias the gradient (used for sharp gradients).
  anti_alias : Bool
} derive(Eq)

///|
/// A gradient that interpolates between two colors radially around a center
/// point.
pub(all) struct ConicGradient {
  /// The color stops of this gradient.
  stops : Array[(Color, Ratio)]
  /// The direction of this gradient.
  angle : Angle
  /// The center of last circle of this gradient.
  center : Axes[Ratio]
  /// The color space in which to interpolate the gradient.
  space : ColorSpace
  /// The relative placement of the gradient.
  relative : Smart[RelativeTo]
  /// Whether to anti-alias the gradient (used for sharp gradients).
  anti_alias : Bool
} derive(Eq)

///|
fn gradient_too_few_stops(span : @syntax.Span) -> SourceDiagnostic {
  SourceDiagnostic::error_at(span, "a gradient must have at least two stops").with_hint(
    "try filling the shape with a single color instead",
  )
}

///|
fn impl_gradient_linear__space_default() -> @syntax.Spanned[Smart[ColorSpace]] raise SourceError {
  { v: Auto, span: @syntax.Span::detached(), }
}

///|
fn impl_gradient_linear__dir_default() -> Dir raise SourceError {
  LTR
}

///|
/// Creates a new linear gradient, in which colors transition along a straight
/// line.
fn impl_gradient_linear(
  args : Args,
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[GradientStop]],
  space_ : @syntax.Spanned[Smart[ColorSpace]],
  relative_ : Smart[RelativeTo],
) -> Gradient raise SourceError {
  let angle = match args.named("angle") {
    Some((angle : Angle)) => angle
    None =>
      match args.named("dir") {
        Some((dir : Dir)) =>
          match dir {
            LTR => Angle::rad(0.0)
            RTL => Angle::rad(@math.PI)
            TTB => Angle::rad(@math.PI / 2.0)
            BTT => Angle::rad(3.0 * (@math.PI / 2.0))
          }
        None => Angle::rad(0.0)
      }
  }
  if stops_.length() < 2 {
    bail_diag(gradient_too_few_stops(span))
  }
  let (stops, space) = process_stops(stops_, space_)
  Linear({ stops, angle, space, relative: relative_, anti_alias: true, })
}

///|
fn impl_gradient_radial__space_default() -> @syntax.Spanned[Smart[ColorSpace]] raise SourceError {
  { v: Auto, span: @syntax.Span::detached(), }
}

///|
fn impl_gradient_radial__center_default() -> Axes[Ratio] raise SourceError {
  Axes::new(Ratio::new(0.5), Ratio::new(0.5))
}

///|
fn impl_gradient_radial__radius_default() -> @syntax.Spanned[Ratio] raise SourceError {
  { v: Ratio::new(0.5), span: @syntax.Span::detached(), }
}

///|
fn impl_gradient_radial__focal_radius_default() -> @syntax.Spanned[Ratio] raise SourceError {
  { v: Ratio::new(0.0), span: @syntax.Span::detached(), }
}

///|
/// Creates a new radial gradient, in which colors radiate away from an
/// origin.
fn impl_gradient_radial(
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[GradientStop]],
  space_ : @syntax.Spanned[Smart[ColorSpace]],
  relative_ : Smart[RelativeTo],
  center_ : Axes[Ratio],
  radius_ : @syntax.Spanned[Ratio],
  focal_center_ : Smart[Axes[Ratio]],
  focal_radius_ : @syntax.Spanned[Ratio],
) -> Gradient raise SourceError {
  if stops_.length() < 2 {
    bail_diag(gradient_too_few_stops(span))
  }
  if focal_radius_.v.get() > radius_.v.get() {
    bail_at(
      focal_radius_.span,
      "the focal radius must be smaller than the end radius",
      hints=["try using a focal radius of `0%` instead"],
    )
  }
  let focal_center = focal_center_.unwrap_or(center_)
  let dx = focal_center.x.get() - center_.x.get()
  let dy = focal_center.y.get() - center_.y.get()
  if @math.hypot(dx, dy) >= radius_.v.get() - focal_radius_.v.get() {
    bail_at(span, "the focal circle must be inside of the end circle", hints=[
      "try using a focal center of `auto` instead",
    ])
  }
  let (stops, space) = process_stops(stops_, space_)
  Radial({
    stops,
    center: center_,
    radius: radius_.v,
    focal_center,
    focal_radius: focal_radius_.v,
    space,
    relative: relative_,
    anti_alias: true,
  })
}

///|
fn impl_gradient_conic__angle_default() -> Angle raise SourceError {
  Angle::zero()
}

///|
fn impl_gradient_conic__space_default() -> @syntax.Spanned[Smart[ColorSpace]] raise SourceError {
  { v: Auto, span: @syntax.Span::detached(), }
}

///|
fn impl_gradient_conic__center_default() -> Axes[Ratio] raise SourceError {
  Axes::new(Ratio::new(0.5), Ratio::new(0.5))
}

///|
/// Creates a new conic gradient, in which colors change radially around a
/// center point.
fn impl_gradient_conic(
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[GradientStop]],
  angle_ : Angle,
  space_ : @syntax.Spanned[Smart[ColorSpace]],
  relative_ : Smart[RelativeTo],
  center_ : Axes[Ratio],
) -> Gradient raise SourceError {
  if stops_.length() < 2 {
    bail_diag(gradient_too_few_stops(span))
  }
  let (stops, space) = process_stops(stops_, space_)
  Conic({
    stops,
    angle: angle_,
    center: center_,
    space,
    relative: relative_,
    anti_alias: true,
  })
}

///|
fn impl_gradient_sharp__smoothness_default() -> @syntax.Spanned[Ratio] raise SourceError {
  { v: Ratio::zero(), span: @syntax.Span::detached(), }
}

///|
/// Creates a sharp version of this gradient.
fn impl_gradient_sharp(
  self_ : Gradient,
  steps_ : @syntax.Spanned[USize],
  smoothness_ : @syntax.Spanned[Ratio],
) -> Gradient raise SourceError {
  let n = steps_.v.0.to_int()
  if n < 2 {
    bail_at(steps_.span, "sharp gradients must have at least two stops")
  }
  if smoothness_.v.get() < 0.0 || smoothness_.v.get() > 1.0 {
    bail_at(smoothness_.span, "smoothness must be between 0 and 1")
  }
  let smoothness = smoothness_.v.get()
  let colors : Array[Color] = []
  for i in 0..<n {
    let c = self_.sample(Ratio(Ratio::new(i.to_double() / (n - 1).to_double())))
    colors.push(c)
    colors.push(c)
  }
  let positions : Array[Double] = []
  let index_to_progress = (i : Int) => i.to_double() * 1.0 / n.to_double()
  let progress = smoothness * 1.0 / (4.0 * n.to_double())
  for i in 0..<n {
    let mut j = 2 * i
    positions.push(index_to_progress(i))
    if j > 0 {
      positions[j] += progress
    }
    j += 1
    positions.push(index_to_progress(i + 1))
    if j < colors.length() - 1 {
      positions[j] -= progress
    }
  }
  let stops = dedup_stops(colors.mapi((i, c) => (c, Ratio::new(positions[i]))))
  match self_ {
    Linear(linear) => Linear({ ..linear, stops, anti_alias: false, })
    Radial(radial) => Radial({ ..radial, stops, anti_alias: false, })
    Conic(conic) => Conic({ ..conic, stops, anti_alias: false, })
  }
}

///|
/// Rust `Vec::dedup` on color stops.
fn dedup_stops(stops : Array[(Color, Ratio)]) -> Array[(Color, Ratio)] {
  let out : Array[(Color, Ratio)] = []
  for stop in stops {
    match out.last() {
      Some(last) if last.0 == stop.0 && last.1 == stop.1 => ()
      _ => out.push(stop)
    }
  }
  out
}

///|
/// Repeats this gradient a given number of times, optionally mirroring it at
/// every second repetition.
fn impl_gradient_repeat(
  self_ : Gradient,
  repetitions_ : @syntax.Spanned[USize],
  mirror_ : Bool,
) -> Gradient raise SourceError {
  let n = repetitions_.v.0.to_int()
  if n == 0 {
    bail_at(repetitions_.span, "must repeat at least once")
  }
  let all : Array[(Color, Ratio)] = []
  for i in 0..<n {
    let stops = self_
      .stops_ref()
      .map(stop => {
        let (color, offset) = stop
        let r = offset.get()
        if i % 2 == 1 && mirror_ {
          (color, Ratio::new((i.to_double() + 1.0 - r) / n.to_double()))
        } else {
          (color, Ratio::new((i.to_double() + r) / n.to_double()))
        }
      })
    if i % 2 == 1 && mirror_ {
      stops.rev_in_place()
    }
    all.push_iter(stops.iter())
  }
  let stops = dedup_stops(all)
  match self_ {
    Linear(linear) => Linear({ ..linear, stops, })
    Radial(radial) => Radial({ ..radial, stops, })
    Conic(conic) => Conic({ ..conic, stops, })
  }
}

///|
/// Returns the kind of this gradient.
fn impl_gradient_kind(self_ : Gradient) -> Func raise HintedError {
  Func::native(
    match self_ {
      Linear(_) => native_gradient_linear()
      Radial(_) => native_gradient_radial()
      Conic(_) => native_gradient_conic()
    },
  )
}

///|
/// Returns the stops of this gradient.
fn impl_gradient_stops(
  self_ : Gradient,
) -> Array[GradientStop] raise HintedError {
  self_.stops_ref().map(stop => { color: stop.0, offset: Some(stop.1), })
}

///|
/// Returns the mixing space of this gradient.
fn impl_gradient_space(self_ : Gradient) -> ColorSpace raise HintedError {
  self_.space()
}

///|
/// Returns the relative placement of this gradient.
fn impl_gradient_relative(
  self_ : Gradient,
) -> Smart[RelativeTo] raise HintedError {
  self_.relative()
}

///|
/// Returns the angle of this gradient.
fn impl_gradient_angle(self_ : Gradient) -> Angle? raise HintedError {
  match self_ {
    Linear(linear) => Some(linear.angle)
    Radial(_) => None
    Conic(conic) => Some(conic.angle)
  }
}

///|
/// Returns the center of this gradient.
fn impl_gradient_center(self_ : Gradient) -> Axes[Ratio]? raise HintedError {
  match self_ {
    Linear(_) => None
    Radial(radial) => Some(radial.center)
    Conic(conic) => Some(conic.center)
  }
}

///|
/// Returns the radius of this gradient.
fn impl_gradient_radius(self_ : Gradient) -> Ratio? raise HintedError {
  match self_ {
    Radial(radial) => Some(radial.radius)
    _ => None
  }
}

///|
/// Returns the focal-center of this gradient.
fn impl_gradient_focal_center(
  self_ : Gradient,
) -> Axes[Ratio]? raise HintedError {
  match self_ {
    Radial(radial) => Some(radial.focal_center)
    _ => None
  }
}

///|
/// Returns the focal-radius of this gradient.
fn impl_gradient_focal_radius(self_ : Gradient) -> Ratio? raise HintedError {
  match self_ {
    Radial(radial) => Some(radial.focal_radius)
    _ => None
  }
}

///|
/// Sample the gradient at a given position.
fn impl_gradient_sample(
  self_ : Gradient,
  t_ : RatioOrAngle,
) -> Color raise HintedError {
  self_.sample(t_)
}

///|
/// Samples the gradient at multiple positions at once and returns the
/// results as an array.
fn impl_gradient_samples(
  self_ : Gradient,
  ts_ : Array[RatioOrAngle],
) -> Arr raise HintedError {
  Arr::from_array(ts_.map(t => Value::Color(self_.sample(t))))
}

///|
/// Sample the gradient at a given position.
pub fn Gradient::sample(self : Gradient, t : RatioOrAngle) -> Color {
  let value = t.to_ratio().get()
  sample_stops(self.stops_ref(), self.space(), value)
}

///|
/// Clones this gradient, but with a different relative placement.
pub fn Gradient::with_relative(
  self : Gradient,
  relative : RelativeTo,
) -> Gradient {
  match self {
    Linear(linear) => Linear({ ..linear, relative: Custom(relative), })
    Radial(radial) => Radial({ ..radial, relative: Custom(relative), })
    Conic(conic) => Conic({ ..conic, relative: Custom(relative), })
  }
}

///|
/// Returns a reference to the stops of this gradient.
pub fn Gradient::stops_ref(self : Gradient) -> Array[(Color, Ratio)] {
  match self {
    Linear(linear) => linear.stops
    Radial(radial) => radial.stops
    Conic(conic) => conic.stops
  }
}

///|
/// Returns the mixing space of this gradient.
pub fn Gradient::space(self : Gradient) -> ColorSpace {
  match self {
    Linear(linear) => linear.space
    Radial(radial) => radial.space
    Conic(conic) => conic.space
  }
}

///|
/// Returns the relative placement of this gradient.
pub fn Gradient::relative(self : Gradient) -> Smart[RelativeTo] {
  match self {
    Linear(linear) => linear.relative
    Radial(radial) => radial.relative
    Conic(conic) => conic.relative
  }
}

///|
/// Whether the gradient should be anti-aliased.
pub fn Gradient::anti_alias(self : Gradient) -> Bool {
  match self {
    Linear(linear) => linear.anti_alias
    Radial(radial) => radial.anti_alias
    Conic(conic) => conic.anti_alias
  }
}

///|
/// Returns the relative placement of this gradient, handling the special
/// case of `auto`.
pub fn Gradient::unwrap_relative(self : Gradient, on_text : Bool) -> RelativeTo {
  self.relative().unwrap_or_else(() => if on_text { Parent } else { Self_ })
}

///|
pub fn Gradient::repr(self : Gradient) -> String {
  match self {
    Radial(radial) => radial.repr()
    Linear(linear) => linear.repr()
    Conic(conic) => conic.repr()
  }
}

///|
/// Rust `f64::rem_euclid`.
fn f64_rem_euclid(x : Double, rhs : Double) -> Double {
  let r = x % rhs
  if r < 0.0 {
    r + rhs.abs()
  } else {
    r
  }
}

///|
let f64_epsilon : Double = 2.220446049250313e-16

///|
/// The common tail of the gradient reprs: space, relative and stops.
fn gradient_repr_tail(
  r : StringBuilder,
  space : ColorSpace,
  relative : Smart[RelativeTo],
  stops : Array[(Color, Ratio)],
  offset_repr : (Ratio) -> String,
) -> Unit {
  if space != Process(Oklab) {
    r.write_string("space: ")
    r.write_string(space.into_value().repr())
    r.write_string(", ")
  }
  if relative.is_custom() {
    r.write_string("relative: ")
    r.write_string(relative.into_value().repr())
    r.write_string(", ")
  }
  for i, stop in stops {
    let (color, offset) = stop
    r.write_char('(')
    r.write_string(color.repr())
    r.write_string(", ")
    r.write_string(offset_repr(offset))
    r.write_char(')')
    if i != stops.length() - 1 {
      r.write_string(", ")
    }
  }
  r.write_char(')')
}

///|
pub fn LinearGradient::repr(self : LinearGradient) -> String {
  let r = StringBuilder()
  r.write_string("gradient.linear(")
  let pi = @math.PI
  let angle = f64_rem_euclid(self.angle.to_rad(), 2.0 * pi)
  if angle.abs() < f64_epsilon {
    // Default value, do nothing
    ()
  } else if (angle - pi / 2.0).abs() < f64_epsilon {
    r.write_string("dir: rtl, ")
  } else if (angle - pi).abs() < f64_epsilon {
    r.write_string("dir: ttb, ")
  } else if (angle - 3.0 * (pi / 2.0)).abs() < f64_epsilon {
    r.write_string("dir: btt, ")
  } else {
    r.write_string("angle: ")
    r.write_string(self.angle.repr())
    r.write_string(", ")
  }
  gradient_repr_tail(r, self.space, self.relative, self.stops, o => o.repr())
  r.to_string()
}

///|
pub fn RadialGradient::repr(self : RadialGradient) -> String {
  let r = StringBuilder()
  r.write_string("gradient.radial(")
  if self.center.x != Ratio::new(0.5) || self.center.y != Ratio::new(0.5) {
    r.write_string("center: (")
    r.write_string(self.center.x.repr())
    r.write_string(", ")
    r.write_string(self.center.y.repr())
    r.write_string("), ")
  }
  if self.radius != Ratio::new(0.5) {
    r.write_string("radius: ")
    r.write_string(self.radius.repr())
    r.write_string(", ")
  }
  if self.focal_center != self.center {
    r.write_string("focal-center: (")
    r.write_string(self.focal_center.x.repr())
    r.write_string(", ")
    r.write_string(self.focal_center.y.repr())
    r.write_string("), ")
  }
  if self.focal_radius != Ratio::zero() {
    r.write_string("focal-radius: ")
    r.write_string(self.focal_radius.repr())
    r.write_string(", ")
  }
  gradient_repr_tail(r, self.space, self.relative, self.stops, o => o.repr())
  r.to_string()
}

///|
pub fn ConicGradient::repr(self : ConicGradient) -> String {
  let r = StringBuilder()
  r.write_string("gradient.conic(")
  let angle = f64_rem_euclid(self.angle.to_rad(), 2.0 * @math.PI)
  if angle.abs() > f64_epsilon {
    r.write_string("angle: ")
    r.write_string(self.angle.repr())
    r.write_string(", ")
  }
  if self.center.x != Ratio::new(0.5) || self.center.y != Ratio::new(0.5) {
    r.write_string("center: (")
    r.write_string(self.center.x.repr())
    r.write_string(", ")
    r.write_string(self.center.y.repr())
    r.write_string("), ")
  }
  gradient_repr_tail(r, self.space, self.relative, self.stops, o => {
    Angle::deg(o.get() * 360.0).repr()
  })
  r.to_string()
}

///|
/// What is the gradient relative to.
pub(all) enum RelativeTo {
  /// Relative to itself (its own bounding box).
  Self_
  /// Relative to its parent (the parent's bounding box).
  Parent
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for RelativeTo with fn input() {
  Union([
    Value(Str("self"), "Relative to itself (its own bounding box)."),
    Value(Str("parent"), "Relative to its parent (the parent's bounding box)."),
  ])
}

///|
pub impl Reflect for RelativeTo with fn output() {
  RelativeTo::input()
}

///|
pub impl Reflect for RelativeTo with fn castable(v) {
  v is Str("self" | "parent")
}

///|
pub impl IntoValue for RelativeTo with fn into_value(self) {
  match self {
    Self_ => Str("self")
    Parent => Str("parent")
  }
}

///|
pub impl FromValue for RelativeTo with fn from_value(v) {
  match v {
    Str("self") => Self_
    Str("parent") => Parent
    v => raise HintedError(RelativeTo::input().error(v))
  }
}

///|
/// A color stop.
pub(all) struct GradientStop {
  /// The color for this stop.
  color : Color
  /// The offset of the stop along the gradient.
  offset : Ratio?
} derive(Eq)

///|
pub impl Reflect for GradientStop with fn input() {
  Color::input().union_with(Type(Type::array()))
}

///|
pub impl Reflect for GradientStop with fn output() {
  GradientStop::input()
}

///|
pub impl Reflect for GradientStop with fn castable(v) {
  v is (Color(_) | Array(_))
}

///|
pub impl IntoValue for GradientStop with fn into_value(self) {
  match self.offset {
    Some(offset) => Array(Arr::from_array([Color(self.color), Ratio(offset)]))
    None => Color(self.color)
  }
}

///|
pub impl FromValue for GradientStop with fn from_value(v) {
  match v {
    Color(color) => { color, offset: None, }
    Array(array) =>
      if array.items.length() == 2 {
        {
          color: Color::from_value(array.items[0]),
          offset: Some(Ratio::from_value(array.items[1])),
        }
      } else {
        bail("a color stop must contain exactly two entries")
      }
    v => raise HintedError(GradientStop::input().error(v))
  }
}

///|
/// A ratio or an angle.
pub(all) enum RatioOrAngle {
  Ratio(Ratio)
  Angle(Angle)
} derive(Eq)

///|
/// Converts to a ratio in `[0, 1]`.
pub fn RatioOrAngle::to_ratio(self : RatioOrAngle) -> Ratio {
  let r = match self {
    Ratio(ratio) => ratio.get()
    Angle(angle) =>
      f64_rem_euclid(angle.to_rad(), 2.0 * @math.PI) / (2.0 * @math.PI)
  }
  Ratio::new(clamp_f64(r, 0.0, 1.0))
}

///|
pub impl Reflect for RatioOrAngle with fn input() {
  CastInfo::Type(Type::ratio()).union_with(Type(Type::angle()))
}

///|
pub impl Reflect for RatioOrAngle with fn output() {
  RatioOrAngle::input()
}

///|
pub impl Reflect for RatioOrAngle with fn castable(v) {
  v is (Ratio(_) | Angle(_))
}

///|
pub impl IntoValue for RatioOrAngle with fn into_value(self) {
  match self {
    Ratio(ratio) => Ratio(ratio)
    Angle(angle) => Angle(angle)
  }
}

///|
pub impl FromValue for RatioOrAngle with fn from_value(v) {
  match v {
    Ratio(ratio) => Ratio(ratio)
    Angle(angle) => Angle(angle)
    v => raise HintedError(RatioOrAngle::input().error(v))
  }
}

///|
/// Pre-processes the stops, checking that they are valid and computing the
/// offsets if necessary.
fn process_stops(
  stops : Array[@syntax.Spanned[GradientStop]],
  space : @syntax.Spanned[Smart[ColorSpace]],
) -> (Array[(Color, Ratio)], ColorSpace) raise SourceError {
  let space_span : @syntax.Span? = if space.span.is_detached() {
    None
  } else {
    Some(space.span)
  }
  let has_offset = stops.iter().any(stop => stop.v.offset is Some(_))
  let space = resolve_color_space(space.v, stops.map(s => s.v.color))
  let convert = (s : @syntax.Spanned[GradientStop]) => {
    let color = s.v.color.to_space(space) catch {
      HintedError(err) => {
        let diag = err.into_error_at(s.span)
        if space_span is Some(span) {
          diag.spanned_hint(
            "gradient color mixing space specified here",
            @syntax.DiagSpan::from_span(span),
          )
        }
        raise SourceError([diag])
      }
    }
    (
      { v: { color, offset: s.v.offset, }, span: s.span, } :
      @syntax.Spanned[GradientStop])
  }
  if has_offset {
    let mut last_stop = @double.neg_infinity
    for stop in stops {
      let offset = match stop.v.offset {
        Some(offset) => offset
        None =>
          bail_at(
            stop.span,
            "either all stops must have an offset or none of them can",
            hints=["try adding an offset to all stops"],
          )
      }
      if offset.get() < last_stop {
        bail_at(stop.span, "offsets must be in monotonic order")
      }
      last_stop = offset.get()
    }
    let out : Array[(Color, Ratio)] = []
    for s in stops {
      let stop = convert(s)
      let offset = stop.v.offset.unwrap()
      if offset.get() > 1.0 || offset.get() < 0.0 {
        bail_at(stop.span, "offset must be between 0 and 1")
      }
      out.push((stop.v.color, offset))
    }
    if out[0].1 != Ratio::zero() {
      bail_at(stops[0].span, "first stop must have an offset of 0", hints=[
        "try setting this stop to `0%`",
      ])
    }
    if out[out.length() - 1].1 != Ratio::one() {
      bail_at(
        stops[out.length() - 1].span,
        "last stop must have an offset of 100%",
        hints=["try setting this stop to `100%`"],
      )
    }
    return (out, space)
  }
  let out : Array[(Color, Ratio)] = []
  for i, s in stops {
    let offset = i.to_double() / (stops.length() - 1).to_double()
    out.push((convert(s).v.color, Ratio::new(offset)))
  }
  (out, space)
}

///|
/// Sample the stops at a given position.
fn sample_stops(
  stops : Array[(Color, Ratio)],
  mixing_space : ColorSpace,
  t : Double,
) -> Color {
  let t = clamp_f64(t, 0.0, 1.0)
  // `partition_point(|(_, ratio)| ratio.get() < t)`
  let mut j = 0
  while j < stops.length() && stops[j].1.get() < t {
    j += 1
  }
  if j == 0 {
    while j + 1 < stops.length() && stops[j + 1].1.is_zero() {
      j += 1
    }
    return stops[j].0
  }
  let (col_0, pos_0) = stops[j - 1]
  let (col_1, pos_1) = stops[j]
  let t = (t - pos_0.get()) / (pos_1.get() - pos_0.get())
  // For two colors, positive weights, and `mixing_space` equaling the color
  // space of each color, this function will not return an error. The
  // relevant errors are raised in `process_stops` instead.
  Color::mix_iter(
    [WeightedColor::new(col_0, 1.0 - t), WeightedColor::new(col_1, t)],
    Custom(mixing_space),
  ) catch {
    _ => abort("unreachable: gradient mixing failed")
  }
}

///|
pub impl Reflect for Gradient with fn input() {
  Type(Type::gradient())
}

///|
pub impl Reflect for Gradient with fn output() {
  Type(Type::gradient())
}

///|
pub impl Reflect for Gradient with fn castable(v) {
  v is Gradient(_)
}

///|
pub impl IntoValue for Gradient with fn into_value(self) {
  Gradient(self)
}

///|
pub impl FromValue for Gradient with fn from_value(v) {
  match v {
    Gradient(g) => g
    v => raise HintedError(Gradient::input().error(v))
  }
}
