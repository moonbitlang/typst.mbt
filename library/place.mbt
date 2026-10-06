// Port of the castable value types of `typst-library/src/layout/place.rs`.

///|
/// Relative to which containing scope something shall be placed.
pub(all) enum PlacementScope {
  /// Place into the current column.
  Column
  /// Place relative to the parent, letting the content span over all
  /// columns.
  Parent
} derive(Eq, Hash, Debug)

///|
pub impl Default for PlacementScope with fn default() {
  Column
}

///|
let placement_scope_names : ReadOnlyArray[String] = ["column", "parent"]

///|
pub impl Reflect for PlacementScope with fn input() {
  str_names_input(placement_scope_names)
}

///|
pub impl Reflect for PlacementScope with fn output() {
  PlacementScope::input()
}

///|
pub impl Reflect for PlacementScope with fn castable(v) {
  str_names_find(placement_scope_names, v) is Some(_)
}

///|
pub extend PlacementScope with Reflect::{output, input, castable}

///|
pub impl IntoValue for PlacementScope with fn into_value(self) {
  match self {
    Column => Str("column")
    Parent => Str("parent")
  }
}

///|
pub extend PlacementScope with IntoValue::{into_value}

///|
pub impl FromValue for PlacementScope with fn from_value(v) {
  match str_names_find(placement_scope_names, v) {
    Some(0) => Column
    Some(_) => Parent
    None => raise HintedError(PlacementScope::input().error(v))
  }
}

///|
fn place_elem_scope_default() -> Value {
  PlacementScope::default().into_value()
}

///|
fn figure_elem_scope_default() -> Value {
  PlacementScope::default().into_value()
}
