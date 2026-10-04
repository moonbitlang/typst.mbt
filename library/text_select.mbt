// Layout-time text helpers of `typst-library/src/text/*`: font family
// resolution (`families`), variant resolution (`variant`), coverage regexes
// (`Covers::as_regex`), script metrics (`ScriptKind::read_metrics`) and the
// justification limit accessors of `model/par.rs`.

///|
/// The fallback families that are appended when font fallback is enabled.
let fallback_families : Array[FontFamily] = [
  "libertinus serif", "twitter color emoji", "noto color emoji", "apple color emoji",
  "segoe ui emoji",
].map(FontFamily::new)

///|
/// Resolve a prioritized list of the font families.
pub fn families(styles : StyleChain) -> Array[FontFamily] {
  let list = TextElem::font_in(styles).0
  if TextElem::fallback_in(styles) {
    [..list, ..fallback_families]
  } else {
    list
  }
}

///|
/// Resolve the font variant.
pub fn variant(styles : StyleChain) -> FontVariant {
  let mut variant = FontVariant::new(
    TextElem::style_in(styles),
    TextElem::weight_in(styles),
    TextElem::stretch_in(styles),
  )
  let WeightDelta(delta) = TextElem::delta_in(styles)
  let delta = if delta < -32768L {
    -32768
  } else if delta > 32767L {
    32767
  } else {
    delta.to_int()
  }
  variant = { ..variant, weight: variant.weight.thicken(delta), }
  if TextElem::emph_in(styles).0 {
    variant = {
      ..variant,
      style: match variant.style {
        Normal => Italic
        Italic => Normal
        Oblique => Normal
      },
    }
  }
  variant
}

///|
/// The regex for `Covers::LatinInCjk`.
let latin_in_cjk_regex : Regex = Regex::new(
  "[^\u{00B7}\u{2013}\u{2014}\u{2018}\u{2019}\u{201C}\u{201D}\u{2025}-\u{2027}\u{2E3A}]",
) catch {
  _ => abort("latin-in-cjk regex is valid")
}

///|
/// Retrieve the regex for the coverage.
pub fn Covers::as_regex(self : Covers) -> Regex {
  match self {
    LatinInCjk => latin_in_cjk_regex
    Regex(regex) => regex
  }
}

///|
/// The user-specified coverage, if any.
pub fn FontFamily::covers(self : FontFamily) -> Regex? {
  self.covers.map(covers => covers.as_regex())
}

///|
/// Returns the default metrics for this script kind.
///
/// This can be used as a last resort if neither the user nor the font
/// provided those metrics.
pub fn ScriptKind::default_metrics(self : ScriptKind) -> ScriptMetrics {
  match self {
    Sub => default_subscript_metrics
    Super => default_superscript_metrics
  }
}

///|
/// Reads the script metrics from the font table for to this script kind.
pub fn ScriptKind::read_metrics(
  self : ScriptKind,
  font_metrics : FontMetrics,
) -> ScriptMetrics {
  let metrics = match self {
    Sub => font_metrics.subscript
    Super => font_metrics.superscript
  }
  metrics.unwrap_or(self.default_metrics())
}

///|
/// The corresponding OpenType feature tag (as a 4-byte string).
pub fn ScriptKind::feature(self : ScriptKind) -> String {
  match self {
    Sub => "subs"
    Super => "sups"
  }
}

///|
/// Access the spacing limits.
pub fn JustificationLimits::spacing_limits(
  self : JustificationLimits,
) -> Limits[Rel[Length]] {
  // (A match: `unwrap_or` would build the default on every call.)
  match self.spacing {
    Some(spacing) => spacing
    None => limits_spacing_default()
  }
}

///|
/// Access the tracking limits.
pub fn JustificationLimits::tracking_limits(
  self : JustificationLimits,
) -> Limits[Length] {
  match self.tracking {
    Some(tracking) => tracking
    None => limits_tracking_default()
  }
}
