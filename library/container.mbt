// Port of the castable value types of `typst-library/src/layout/container.rs`
// (`BlockBody`, `BaselinePos`) and the `BoxElem`/`BlockElem` field defaults.
// `Sizing` lives in `spacing.mbt`.

///|
/// The contents of a block.
pub(all) enum BlockBody {
  /// The block contains normal content.
  Content(Content)
  // TODO: `SingleLayouter` and `MultiLayouter` callbacks (created by
  // layout code, cast to `auto`).
} derive(Eq)

///|
pub impl Default for BlockBody with fn default() {
  Content(Content::empty())
}

///|
pub impl Reflect for BlockBody with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for BlockBody with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for BlockBody with fn castable(v) {
  Content::castable(v)
}

///|
pub impl IntoValue for BlockBody with fn into_value(self) {
  match self {
    Content(content) => Content(content)
  }
}

///|
pub impl FromValue for BlockBody with fn from_value(v) {
  Content(FromValue::from_value(v))
}

///|
/// Defines how to determine the baseline of a box.
///
/// Here `None` means unspecified and fields set to it are inherited.
pub(all) struct BaselinePos {
  /// Baseline's reference position relative to the height of the box's
  /// contents.
  at : Smart[VAlignment]?
  /// Amount to shift the baseline by.
  shift : Rel[Length]?
} derive(Eq, Hash)

///|
pub impl Default for BaselinePos with fn default() {
  { at: Some(Auto), shift: Some(Rel::zero()), }
}

///|
/// Baseline position relative to frame height, or `auto` to align with the
/// inner baseline.
pub fn BaselinePos::at(self : BaselinePos) -> Smart[VAlignment] {
  self.at.unwrap_or(Auto)
}

///|
/// Amount to shift by, with default resolved.
pub fn BaselinePos::shift(self : BaselinePos) -> Rel[Length] {
  self.shift.unwrap_or(Rel::zero())
}

///|
pub impl Fold for BaselinePos with fn fold(self, outer) {
  { at: self.at |> opt_or(outer.at), shift: self.shift |> opt_or(outer.shift), }
}

///|
pub impl Reflect for BaselinePos with fn input() {
  input_of((Ty::new() : Ty[Smart[VAlignment]]))
  .union_with(Type(Type::relative()))
  .union_with(Type(Type::dict()))
}

///|
pub impl Reflect for BaselinePos with fn output() {
  BaselinePos::input()
}

///|
pub impl Reflect for BaselinePos with fn castable(v) {
  v is Auto ||
  VAlignment::castable(v) ||
  v is (Relative(_) | Length(_) | Ratio(_) | Dict(_))
}

///|
pub impl IntoValue for BaselinePos with fn into_value(self) {
  let dict = Dict::new()
  if self.at is Some(at) {
    dict.insert("at", at.into_value())
  }
  if self.shift is Some(shift) {
    dict.insert("shift", shift.into_value())
  }
  Dict(dict)
}

///|
pub impl FromValue for BaselinePos with fn from_value(v) {
  if v is Auto || VAlignment::castable(v) {
    let at : Smart[VAlignment] = FromValue::from_value(v)
    return { at: Some(at), shift: None, }
  }
  match v {
    Relative(_) | Length(_) | Ratio(_) => {
      let shift : Rel[Length] = FromValue::from_value(v)
      { at: None, shift: Some(shift), }
    }
    Dict(dict) => {
      // Get a value by key, accepting either non-existence or something
      // convertible to type T.
      let dict = dict.copy()
      let at = dict_take_cast(dict, "at")
      let shift = dict_take_cast(dict, "shift")
      dict.finish(["at", "shift"])
      { at, shift, }
    }
    v => raise HintedError(BaselinePos::input().error(v))
  }
}

///|
fn box_elem_baseline_default() -> Value {
  BaselinePos::default().into_value()
}
