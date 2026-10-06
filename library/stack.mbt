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
pub impl FromValue for StackChild with fn from_value(v) {
  if Spacing::castable(v) {
    return Spacing(Spacing::from_value(v))
  }
  if Content::castable(v) {
    return Block(Content::from_value(v))
  }
  raise HintedError(StackChild::input().error(v))
}
