// Casts of `Element` (upstream `typst-library/src/foundations/content/element.rs`)
// and `Depth` (upstream `typst-library/src/foundations/styles.rs`).

///|
pub impl Reflect for Element with fn input() {
  Type(Type::func())
}

///|
pub impl Reflect for Element with fn output() {
  Type(Type::func())
}

///|
pub impl Reflect for Element with fn castable(v) {
  Func::castable(v)
}

///|
pub impl IntoValue for Element with fn into_value(self) {
  Func(Func::element(self))
}

///|
pub impl FromValue for Element with fn from_value(v) {
  let func : Func = FromValue::from_value(v)
  match func.to_element() {
    Some(elem) => elem
    None => bail("expected element")
  }
}

///|
/// A depth that is summed up when folded (upstream `Depth`, an internal
/// field type without casts; stored as an integer).
pub(all) struct Depth(Int64) derive(Eq, Hash, Default)

///|
pub impl Fold for Depth with fn fold(self, outer) {
  Depth(outer.0 + self.0)
}

///|
pub impl Reflect for Depth with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for Depth with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for Depth with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for Depth with fn into_value(self) {
  Int(self.0)
}

///|
pub impl FromValue for Depth with fn from_value(v) {
  Depth(FromValue::from_value(v))
}
