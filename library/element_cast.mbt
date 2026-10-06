// Casts of `Element` (upstream `typst-library/src/foundations/content/element.rs`)
// and `Depth` (upstream `typst-library/src/foundations/styles.rs`).

///|
/// A depth that is summed up when folded (upstream `Depth`, an internal
/// field type without casts; stored as an integer).
pub(all) struct Depth(Int64) derive(Eq, Hash, Default)

///|
pub extend Depth with Default::{default}

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
pub extend Depth with IntoValue::{into_value}

///|
pub impl FromValue for Depth with fn from_value(v) {
  Depth(FromValue::from_value(v))
}
