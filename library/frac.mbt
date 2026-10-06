// Port of the types of `typst-library/src/math/frac.rs` (`FracStyle`) and
// the `FracElem` field defaults. The elements are generated.

///|
fn frac_elem_style_default() -> Value {
  FracStyle::Vertical.into_value()
}

///|
/// Fraction style
pub(all) enum FracStyle {
  /// Stacked numerator and denominator with a bar.
  Vertical
  /// Numerator and denominator separated by a slash.
  Skewed
  /// Numerator and denominator placed inline and parentheses are not
  /// absorbed.
  Horizontal
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FracStyle with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FracStyle with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FracStyle with @debug.Debug::{to_repr}

///|
pub impl Default for FracStyle with fn default() {
  Vertical
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FracStyle with Default::{default}

///|
pub impl Reflect for FracStyle with fn input() {
  Union([
    Value(Str("vertical"), "Stacked numerator and denominator with a bar."),
    Value(Str("skewed"), "Numerator and denominator separated by a slash."),
    Value(
      Str("horizontal"),
      "Numerator and denominator placed inline and parentheses are not absorbed.",
    ),
  ])
}

///|
pub impl Reflect for FracStyle with fn output() {
  FracStyle::input()
}

///|
pub impl Reflect for FracStyle with fn castable(v) {
  v is Str("vertical" | "skewed" | "horizontal")
}

///|
pub extend FracStyle with Reflect::{output, input, castable}

///|
pub impl IntoValue for FracStyle with fn into_value(self) {
  match self {
    Vertical => Str("vertical")
    Skewed => Str("skewed")
    Horizontal => Str("horizontal")
  }
}

///|
pub extend FracStyle with IntoValue::{into_value}

///|
pub impl FromValue for FracStyle with fn from_value(v) {
  match v {
    Str("vertical") => Vertical
    Str("skewed") => Skewed
    Str("horizontal") => Horizontal
    v => raise HintedError(FracStyle::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FracStyle with FromValue::{from_value}

///|
/// How much padding to add around each side of a fraction (upstream
/// `FRAC_PADDING`).
pub let frac_padding : Em = Em::new(0.1)
