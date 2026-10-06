// Port of `typst-library/src/foundations/target.rs`.

///|
/// A compilation output for a particular target.
///
/// Has a 1-1 relationship with the variants of [Target].
pub(open) trait Output {
  /// The target associated with the output.
  fn target() -> Target
  /// Creates the output.
  fn create(Engine, Content, StyleChain) -> Self raise SourceError
  /// Get the output's introspector.
  fn introspector(Self) -> Introspector
}

///|
/// The compilation target.
pub(all) enum Target {
  /// The target that is used for paged, fully laid-out content.
  Paged
  /// The target that is used for HTML export.
  Html
  /// The target for _bundle_ export. This export target can produce multiple
  /// [documents]($document) and [assets]($asset) from a single Typst project.
  Bundle
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Target with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Target with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Target with @debug.Debug::{to_repr}

///|
/// The default target (`Paged`).
pub fn Target::default() -> Target {
  Paged
}

///|
/// Upstream `Debug for Target`.
pub impl Show for Target with fn output(self, logger) {
  logger.write_string(
    match self {
      Paged => "Paged"
      Html => "Html"
      Bundle => "Bundle"
    },
  )
}

///|
// `output` is not named here: the `extend` of `Reflect` makes it a method of the type.
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Target with Show::{to_string}

///|
/// Whether this is the HTML target.
pub fn Target::is_html(self : Target) -> Bool {
  self == Html
}

///|
pub impl Fingerprint for Target with fn fingerprint(self, state) {
  state.write_discriminant(
    match self {
      Paged => 0
      Html => 1
      Bundle => 2
    },
  )
}

///|
#deprecated("call as `Fingerprint::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Target with Fingerprint::{fingerprint}

///|
pub impl Reflect for Target with fn input() {
  Union([
    Value(
      Str("paged"),
      "The target that is used for paged, fully laid-out content.",
    ),
    Value(Str("html"), "The target that is used for HTML export."),
    Value(
      Str("bundle"),
      "The target for _bundle_ export. This export target can produce multiple\n[documents]($document) and [assets]($asset) from a single Typst project.",
    ),
  ])
}

///|
pub impl Reflect for Target with fn output() {
  Target::input()
}

///|
pub impl Reflect for Target with fn castable(v) {
  v is Str("paged" | "html" | "bundle")
}

///|
pub extend Target with Reflect::{output, input, castable}

///|
pub impl IntoValue for Target with fn into_value(self) {
  match self {
    Paged => Str("paged")
    Html => Str("html")
    Bundle => Str("bundle")
  }
}

///|
pub extend Target with IntoValue::{into_value}

///|
pub impl FromValue for Target with fn from_value(v) {
  match v {
    Str("paged") => Paged
    Str("html") => Html
    Str("bundle") => Bundle
    v => raise HintedError(Target::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Target with FromValue::{from_value}

///|
/// `Default::default()` of `Target` (`TargetElem.target`).
fn target_elem_target_default() -> Value {
  Target::default().into_value()
}

///|
/// Returns the current export target.
///
/// This function returns
/// - `{"paged"}` in PDF, PNG, and SVG export, or within an HTML frame
/// - `{"html"}` in HTML export
/// - `{"bundle"}` in bundle export
fn impl_target(context : Context) -> Target raise HintedError {
  TargetElem::target_in(context.get_styles())
}
