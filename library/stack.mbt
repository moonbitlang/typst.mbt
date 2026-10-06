// Port of the castable value types of `typst-library/src/layout/stack.rs`.

///|
/// A child of a stack element.
pub(all) enum StackChild {
  /// Spacing between other children.
  Spacing(Spacing)
  /// Arbitrary block-level content.
  Block(Content)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StackChild with Eq::{not_equal, equal}

///|
pub impl Reflect for StackChild with fn input() {
  Spacing::input().union_with(Content::input())
}

///|
pub impl Reflect for StackChild with fn output() {
  StackChild::input()
}

///|
pub impl Reflect for StackChild with fn castable(v) {
  Spacing::castable(v) || Content::castable(v)
}

///|
pub extend StackChild with Reflect::{output, input, castable}

///|
pub impl IntoValue for StackChild with fn into_value(self) {
  match self {
    Spacing(spacing) => spacing.into_value()
    Block(content) => Content(content)
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StackChild with IntoValue::{into_value}

///|
pub impl FromValue for StackChild with fn from_value(v) {
  if Spacing::castable(v) {
    return Spacing(Spacing::from_value(v))
  }
  if Content::castable(v) {
    return Block(Content::from_value(v))
  }
  raise HintedError(StackChild::input().error(v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StackChild with FromValue::{from_value}
