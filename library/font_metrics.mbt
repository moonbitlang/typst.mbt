// Port of `typst-library/src/text/font/metrics.rs`.

///|
/// Metrics of a font.
pub(all) struct FontMetrics {
  /// How many font units represent one em unit.
  units_per_em : Double
  /// The distance from the baseline to the typographic ascender.
  ascender : Em
  /// The approximate height of uppercase letters.
  cap_height : Em
  /// The approximate height of non-ascending lowercase letters.
  x_height : Em
  /// The distance from the baseline to the typographic descender.
  descender : Em
  /// Recommended metrics for a strikethrough line.
  strikethrough : LineMetrics
  /// Recommended metrics for an underline.
  underline : LineMetrics
  /// Recommended metrics for an overline.
  overline : LineMetrics
  /// Metrics for subscripts, if provided by the font.
  subscript : ScriptMetrics?
  /// Metrics for superscripts, if provided by the font.
  superscript : ScriptMetrics?
  /// Metrics for math layout (computed lazily).
  priv math : Ref[MathConstants?]
}

///|
/// Extract the font's metrics.
pub fn FontMetrics::from_ttf(ttf : @otf.Face) -> FontMetrics {
  let units_per_em = ttf.units_per_em().to_int().to_double()
  let to_em = (units : Int16) => {
    Em::from_units(units.to_int().to_double(), units_per_em)
  }
  let ascender = to_em(ttf.typographic_ascender().unwrap_or(ttf.ascender()))
  let cap_height = match ttf.capital_height() {
    Some(h) if h > 0 => to_em(h)
    _ => ascender
  }
  let x_height = match ttf.x_height() {
    Some(h) if h > 0 => to_em(h)
    _ => ascender
  }
  let descender = to_em(ttf.typographic_descender().unwrap_or(ttf.descender()))
  let strikeout = ttf.strikeout_metrics()
  let underline = ttf.underline_metrics()
  let strikethrough : LineMetrics = {
    position: match strikeout {
      Some(s) => to_em(s.position)
      None => Em::new(0.25)
    },
    thickness: match opt_or(strikeout, underline) {
      Some(s) => to_em(s.thickness)
      None => Em::new(0.06)
    },
  }
  let underline_ : LineMetrics = {
    position: match underline {
      Some(s) => to_em(s.position)
      None => Em::new(-0.2)
    },
    thickness: match opt_or(underline, strikeout) {
      Some(s) => to_em(s.thickness)
      None => Em::new(0.06)
    },
  }
  let overline : LineMetrics = {
    position: cap_height + Em::new(0.1),
    thickness: underline_.thickness,
  }
  let subscript = ttf
    .subscript_metrics()
    .map(metrics => ScriptMetrics::{
      width: to_em(metrics.x_size),
      height: to_em(metrics.y_size),
      horizontal_offset: to_em(metrics.x_offset),
      vertical_offset: -to_em(metrics.y_offset),
    })
  let superscript = ttf
    .superscript_metrics()
    .map(metrics => ScriptMetrics::{
      width: to_em(metrics.x_size),
      height: to_em(metrics.y_size),
      horizontal_offset: to_em(metrics.x_offset),
      vertical_offset: to_em(metrics.y_offset),
    })
  {
    units_per_em,
    ascender,
    cap_height,
    x_height,
    descender,
    strikethrough,
    underline: underline_,
    overline,
    superscript,
    subscript,
    math: Ref(None),
  }
}

///|
/// Look up a vertical metric.
pub fn FontMetrics::vertical(
  self : FontMetrics,
  metric : VerticalFontMetric,
) -> Em {
  match metric {
    Ascender => self.ascender
    CapHeight => self.cap_height
    XHeight => self.x_height
    Baseline => Em::zero()
    Descender => self.descender
  }
}

///|
/// Metrics for a decorative line.
pub(all) struct LineMetrics {
  /// The vertical offset of the line from the baseline. Positive goes
  /// upwards, negative downwards.
  position : Em
  /// The thickness of the line.
  thickness : Em
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LineMetrics with Eq::{not_equal, equal}

///|
/// Metrics for subscripts or superscripts.
pub(all) struct ScriptMetrics {
  /// The width of those scripts, relative to the outer font size.
  width : Em
  /// The height of those scripts, relative to the outer font size.
  height : Em
  /// The horizontal (to the right) offset of those scripts, relative to the
  /// outer font size.
  ///
  /// This is used for italic correction.
  horizontal_offset : Em
  /// The vertical (to the top) offset of those scripts, relative to the outer font size.
  ///
  /// For superscripts, this is positive. For subscripts, this is negative.
  vertical_offset : Em
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ScriptMetrics with Eq::{not_equal, equal}

///|
/// The default subscript metrics (upstream `DEFAULT_SUBSCRIPT_METRICS` in
/// `text/shift.rs`).
pub let default_subscript_metrics : ScriptMetrics = {
  width: Em::new(0.6),
  height: Em::new(0.6),
  horizontal_offset: Em::zero(),
  vertical_offset: Em::new(-0.2),
}

///|
/// The default superscript metrics (upstream `DEFAULT_SUPERSCRIPT_METRICS`
/// in `text/shift.rs`).
pub let default_superscript_metrics : ScriptMetrics = {
  width: Em::new(0.6),
  height: Em::new(0.6),
  horizontal_offset: Em::zero(),
  vertical_offset: Em::new(0.5),
}

///|
/// Constants from the OpenType MATH constants table used in Typst.
///
/// Ones not currently used are omitted.
pub(all) struct MathConstants {
  // This is not from the OpenType MATH spec.
  space_width : Em
  // These are both i16 instead of f64 as they need to go on the StyleChain.
  script_percent_scale_down : Int
  script_script_percent_scale_down : Int
  display_operator_min_height : Em
  axis_height : Em
  accent_base_height : Em
  flattened_accent_base_height : Em
  subscript_shift_down : Em
  subscript_top_max : Em
  subscript_baseline_drop_min : Em
  superscript_shift_up : Em
  superscript_shift_up_cramped : Em
  superscript_bottom_min : Em
  superscript_baseline_drop_max : Em
  sub_superscript_gap_min : Em
  superscript_bottom_max_with_subscript : Em
  space_after_script : Em
  upper_limit_gap_min : Em
  upper_limit_baseline_rise_min : Em
  lower_limit_gap_min : Em
  lower_limit_baseline_drop_min : Em
  stack_top_shift_up : Em
  stack_top_display_style_shift_up : Em
  stack_bottom_shift_down : Em
  stack_bottom_display_style_shift_down : Em
  stack_gap_min : Em
  stack_display_style_gap_min : Em
  stretch_stack_top_shift_up : Em
  stretch_stack_bottom_shift_down : Em
  stretch_stack_gap_above_min : Em
  stretch_stack_gap_below_min : Em
  fraction_numerator_shift_up : Em
  fraction_numerator_display_style_shift_up : Em
  fraction_denominator_shift_down : Em
  fraction_denominator_display_style_shift_down : Em
  fraction_numerator_gap_min : Em
  fraction_num_display_style_gap_min : Em
  fraction_rule_thickness : Em
  fraction_denominator_gap_min : Em
  fraction_denom_display_style_gap_min : Em
  skewed_fraction_vertical_gap : Em
  skewed_fraction_horizontal_gap : Em
  overbar_vertical_gap : Em
  overbar_rule_thickness : Em
  overbar_extra_ascender : Em
  underbar_vertical_gap : Em
  underbar_rule_thickness : Em
  underbar_extra_descender : Em
  radical_vertical_gap : Em
  radical_display_style_vertical_gap : Em
  radical_rule_thickness : Em
  radical_extra_ascender : Em
  radical_kern_before_degree : Em
  radical_kern_after_degree : Em
  radical_degree_bottom_raise_percent : Double
}

///|
fn MathConstants::new(font : FontInstance) -> MathConstants {
  guard font.ttf() is Some(ttf) else {
    return MathConstants::fallback(font, math_thick)
  }
  let space_width = match ttf.glyph_index(' ') {
    Some(id) =>
      match ttf.glyph_hor_advance(id) {
        Some(units) => font.to_em(units.to_int().to_double())
        None => math_thick
      }
    None => math_thick
  }
  match ttf.tables().math {
    Some({ constants: Some(constants), .. }) =>
      MathConstants::from_constants(font, constants, space_width)
    _ => MathConstants::fallback(font, space_width)
  }
}

///|
fn MathConstants::from_constants(
  font : FontInstance,
  constants : @otf.MathConstants,
  space_width : Em,
) -> MathConstants {
  let is_cambria = () => font.font().post_script_name() is Some("CambriaMath")
  let v = (value : @otf.MathValue) => {
    font.to_em(value.value.to_int().to_double())
  }
  {
    space_width,
    script_percent_scale_down: constants.script_percent_scale_down().to_int(),
    script_script_percent_scale_down: constants
    .script_script_percent_scale_down()
    .to_int(),
    display_operator_min_height: font.to_em(
      (if is_cambria() {
        constants.delimited_sub_formula_min_height()
      } else {
        constants.display_operator_min_height()
      })
      .to_int()
      .to_double(),
    ),
    axis_height: v(constants.axis_height()),
    accent_base_height: v(constants.accent_base_height()),
    flattened_accent_base_height: v(constants.flattened_accent_base_height()),
    subscript_shift_down: v(constants.subscript_shift_down()),
    subscript_top_max: v(constants.subscript_top_max()),
    subscript_baseline_drop_min: v(constants.subscript_baseline_drop_min()),
    superscript_shift_up: v(constants.superscript_shift_up()),
    superscript_shift_up_cramped: v(constants.superscript_shift_up_cramped()),
    superscript_bottom_min: v(constants.superscript_bottom_min()),
    superscript_baseline_drop_max: v(constants.superscript_baseline_drop_max()),
    sub_superscript_gap_min: v(constants.sub_superscript_gap_min()),
    superscript_bottom_max_with_subscript: v(
      constants.superscript_bottom_max_with_subscript(),
    ),
    space_after_script: v(constants.space_after_script()),
    upper_limit_gap_min: v(constants.upper_limit_gap_min()),
    upper_limit_baseline_rise_min: v(constants.upper_limit_baseline_rise_min()),
    lower_limit_gap_min: v(constants.lower_limit_gap_min()),
    lower_limit_baseline_drop_min: v(constants.lower_limit_baseline_drop_min()),
    stack_top_shift_up: v(constants.stack_top_shift_up()),
    stack_top_display_style_shift_up: v(
      constants.stack_top_display_style_shift_up(),
    ),
    stack_bottom_shift_down: v(constants.stack_bottom_shift_down()),
    stack_bottom_display_style_shift_down: v(
      constants.stack_bottom_display_style_shift_down(),
    ),
    stack_gap_min: v(constants.stack_gap_min()),
    stack_display_style_gap_min: v(constants.stack_display_style_gap_min()),
    stretch_stack_top_shift_up: v(constants.stretch_stack_top_shift_up()),
    stretch_stack_bottom_shift_down: v(
      constants.stretch_stack_bottom_shift_down(),
    ),
    stretch_stack_gap_above_min: v(constants.stretch_stack_gap_above_min()),
    stretch_stack_gap_below_min: v(constants.stretch_stack_gap_below_min()),
    fraction_numerator_shift_up: v(constants.fraction_numerator_shift_up()),
    fraction_numerator_display_style_shift_up: v(
      constants.fraction_numerator_display_style_shift_up(),
    ),
    fraction_denominator_shift_down: v(
      constants.fraction_denominator_shift_down(),
    ),
    fraction_denominator_display_style_shift_down: v(
      constants.fraction_denominator_display_style_shift_down(),
    ),
    fraction_numerator_gap_min: v(constants.fraction_numerator_gap_min()),
    fraction_num_display_style_gap_min: v(
      constants.fraction_num_display_style_gap_min(),
    ),
    fraction_rule_thickness: v(constants.fraction_rule_thickness()),
    fraction_denominator_gap_min: v(constants.fraction_denominator_gap_min()),
    fraction_denom_display_style_gap_min: v(
      constants.fraction_denom_display_style_gap_min(),
    ),
    skewed_fraction_vertical_gap: v(constants.skewed_fraction_vertical_gap()),
    skewed_fraction_horizontal_gap: v(
      constants.skewed_fraction_horizontal_gap(),
    ),
    overbar_vertical_gap: v(constants.overbar_vertical_gap()),
    overbar_rule_thickness: v(constants.overbar_rule_thickness()),
    overbar_extra_ascender: v(constants.overbar_extra_ascender()),
    underbar_vertical_gap: v(constants.underbar_vertical_gap()),
    underbar_rule_thickness: v(constants.underbar_rule_thickness()),
    underbar_extra_descender: v(constants.underbar_extra_descender()),
    radical_vertical_gap: v(constants.radical_vertical_gap()),
    radical_display_style_vertical_gap: v(
      constants.radical_display_style_vertical_gap(),
    ),
    radical_rule_thickness: v(constants.radical_rule_thickness()),
    radical_extra_ascender: v(constants.radical_extra_ascender()),
    radical_kern_before_degree: v(constants.radical_kern_before_degree()),
    radical_kern_after_degree: v(constants.radical_kern_after_degree()),
    radical_degree_bottom_raise_percent: constants
    .radical_degree_bottom_raise_percent()
    .to_int()
    .to_double() /
    100.0,
  }
}

///|
/// Most of these fallback constants are from the MathML Core
/// spec, with the exceptions of
/// - `flattened_accent_base_height` from Building Math Fonts
/// - `overbar_rule_thickness` and `underbar_rule_thickness`
///   from our best guess
/// - `skewed_fraction_vertical_gap` and `skewed_fraction_horizontal_gap`
///   from our best guess
/// - `script_percent_scale_down` and
///   `script_script_percent_scale_down` from Building Math
///   Fonts as the defaults given in MathML Core have more
///   precision than i16.
///
/// <https://www.w3.org/TR/mathml-core/#layout-constants-mathconstants>
/// <https://github.com/notofonts/math/blob/main/documentation/building-math-fonts/index.md>
fn MathConstants::fallback(
  font : FontInstance,
  space_width : Em,
) -> MathConstants {
  let metrics = font.metrics()
  let em = (x : Double) => Em::new(x)
  let s = (k : Double, e : Em) => Em::new(k * e.get())
  let thickness = metrics.underline.thickness
  {
    space_width,
    script_percent_scale_down: 70,
    script_script_percent_scale_down: 50,
    display_operator_min_height: Em::zero(),
    axis_height: Em::new(metrics.x_height.get() / 2.0),
    accent_base_height: metrics.x_height,
    flattened_accent_base_height: metrics.cap_height,
    subscript_shift_down: metrics.subscript
    .map(metrics => metrics.vertical_offset)
    .unwrap_or(default_subscript_metrics.vertical_offset),
    subscript_top_max: s(0.8, metrics.x_height),
    subscript_baseline_drop_min: Em::zero(),
    superscript_shift_up: metrics.superscript
    .map(metrics => metrics.vertical_offset)
    .unwrap_or(default_superscript_metrics.vertical_offset),
    superscript_shift_up_cramped: Em::zero(),
    superscript_bottom_min: s(0.25, metrics.x_height),
    superscript_baseline_drop_max: Em::zero(),
    sub_superscript_gap_min: s(4.0, thickness),
    superscript_bottom_max_with_subscript: s(0.8, metrics.x_height),
    space_after_script: em(1.0 / 24.0),
    upper_limit_gap_min: Em::zero(),
    upper_limit_baseline_rise_min: Em::zero(),
    lower_limit_gap_min: Em::zero(),
    lower_limit_baseline_drop_min: Em::zero(),
    stack_top_shift_up: Em::zero(),
    stack_top_display_style_shift_up: Em::zero(),
    stack_bottom_shift_down: Em::zero(),
    stack_bottom_display_style_shift_down: Em::zero(),
    stack_gap_min: s(3.0, thickness),
    stack_display_style_gap_min: s(7.0, thickness),
    stretch_stack_top_shift_up: Em::zero(),
    stretch_stack_bottom_shift_down: Em::zero(),
    stretch_stack_gap_above_min: Em::zero(),
    stretch_stack_gap_below_min: Em::zero(),
    fraction_numerator_shift_up: Em::zero(),
    fraction_numerator_display_style_shift_up: Em::zero(),
    fraction_denominator_shift_down: Em::zero(),
    fraction_denominator_display_style_shift_down: Em::zero(),
    fraction_numerator_gap_min: thickness,
    fraction_num_display_style_gap_min: s(3.0, thickness),
    fraction_rule_thickness: thickness,
    fraction_denominator_gap_min: thickness,
    fraction_denom_display_style_gap_min: s(3.0, thickness),
    skewed_fraction_vertical_gap: Em::zero(),
    skewed_fraction_horizontal_gap: em(0.5),
    overbar_vertical_gap: s(3.0, thickness),
    overbar_rule_thickness: thickness,
    overbar_extra_ascender: thickness,
    underbar_vertical_gap: s(3.0, thickness),
    underbar_rule_thickness: thickness,
    underbar_extra_descender: thickness,
    radical_vertical_gap: s(1.25, thickness),
    radical_display_style_vertical_gap: thickness + s(0.25, metrics.x_height),
    radical_rule_thickness: thickness,
    radical_extra_ascender: thickness,
    radical_kern_before_degree: em(5.0 / 18.0),
    radical_kern_after_degree: em(-10.0 / 18.0),
    radical_degree_bottom_raise_percent: 0.6,
  }
}

///|
/// Identifies a vertical metric of a font.
pub(all) enum VerticalFontMetric {
  /// The font's ascender, which typically exceeds the height of all glyphs.
  Ascender
  /// The approximate height of uppercase letters.
  CapHeight
  /// The approximate height of non-ascending lowercase letters.
  XHeight
  /// The baseline on which the letters rest.
  Baseline
  /// The font's ascender, which typically exceeds the depth of all glyphs.
  Descender
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VerticalFontMetric with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VerticalFontMetric with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VerticalFontMetric with @debug.Debug::{to_repr}

///|
/// Upstream `TryInto<VerticalFontMetric> for TopEdgeMetric`.
pub fn TopEdgeMetric::to_vertical(self : TopEdgeMetric) -> VerticalFontMetric? {
  match self {
    Ascender => Some(Ascender)
    CapHeight => Some(CapHeight)
    XHeight => Some(XHeight)
    Baseline => Some(Baseline)
    Bounds => None
  }
}

///|
/// Upstream `TryInto<VerticalFontMetric> for BottomEdgeMetric`.
pub fn BottomEdgeMetric::to_vertical(
  self : BottomEdgeMetric,
) -> VerticalFontMetric? {
  match self {
    Baseline => Some(Baseline)
    Descender => Some(Descender)
    Bounds => None
  }
}

///|
/// Defines how to resolve a `Bounds` text edge.
pub(all) enum TextEdgeBounds {
  /// Set the bounds to zero.
  Zero
  /// Use the bounding box of the given glyph for the bounds.
  Glyph(UInt16)
  /// Use the dimension of the given frame for the bounds.
  Frame(Frame)
}
