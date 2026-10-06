// Casts of `Element` (upstream `typst-library/src/foundations/content/element.rs`)
// and `Depth` (upstream `typst-library/src/foundations/styles.rs`).

///|
/// A depth that is summed up when folded (upstream `Depth`, an internal
/// field type without casts; stored as an integer).
pub(all) struct Depth(Int64) derive(Eq, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Depth with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Depth with Hash::{hash, hash_combine}

///|
pub extend Depth with Default::{default}

///|
pub impl Fold for Depth with fn fold(self, outer) {
  Depth(outer.0 + self.0)
}

///|
#deprecated("call as `Fold::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Depth with Fold::{fold}

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
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Depth with Reflect::{output, input, castable}

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

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Depth with FromValue::{from_value}
