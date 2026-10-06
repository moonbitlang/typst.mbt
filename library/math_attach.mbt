// Parts of `typst-library/src/math/attach.rs` (the elements are generated).

///|
/// Describes in which situation a frame should use limits for attachments
/// (upstream `math::Limits`; `Limits` is taken by `par.mbt`).
pub(all) enum MathLimits {
  /// Always scripts.
  Never
  /// Display limits only in `display` math.
  Display
  /// Always limits.
  Always
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathLimits with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MathLimits with @debug.Debug::{to_repr}

///|
/// The default limit configuration if the given character is the base.
pub fn MathLimits::for_char(c : Char) -> MathLimits {
  MathLimits::for_char_with_class(c, @unicode.default_math_class(c))
}

///|
/// The default limit configuration for a character with a known default
/// class.
pub fn MathLimits::for_char_with_class(
  c : Char,
  class : @unicode.MathClass?,
) -> MathLimits {
  match class {
    Some(Large) =>
      if is_integral_char(c) {
        MathLimits::Never
      } else {
        MathLimits::Display
      }
    Some(Relation) => Always
    _ => Never
  }
}

///|
/// The default limit configuration for a math class.
pub fn MathLimits::for_class(class : @unicode.MathClass) -> MathLimits {
  match class {
    Large => MathLimits::Display
    Relation => Always
    _ => Never
  }
}

///|
/// Whether limits should be displayed in this context.
pub fn MathLimits::active(self : MathLimits, styles : StyleChain) -> Bool {
  match self {
    Always => true
    Display => EquationElem::size_in(styles) == MathSize::Display
    Never => false
  }
}

///|
/// Determines if the character is one of a variety of integral signs.
fn is_integral_char(c : Char) -> Bool {
  c is ('∫'..='∳') || c is ('⨋'..='⨜')
}
