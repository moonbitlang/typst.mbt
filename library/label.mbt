// Port of `typst-library/src/foundations/label.rs`.

///|
/// A label for an element.
///
/// Inserting a label into content attaches it to the closest preceding
/// element that is not a space. The preceding element must be in the same
/// scope as the label, which means that `[Hello #[[World]] <label>]`, for
/// instance, wouldn't work.
///
/// A labelled element can be referenced, queried for, and styled through
/// its label.
///
/// Once constructed, you can get the name of a label using `str`.
pub(all) struct Label(String) derive(Eq, Hash, Compare)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Label with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Label with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Label with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
/// Creates a label from a string (upstream `Label::new`). Returns `None` for
/// an empty name.
pub fn Label::new(name : String) -> Label? {
  if name.is_empty() {
    None
  } else {
    Some(Label(name))
  }
}

///|
/// Resolves the label to a string.
pub fn Label::resolve(self : Label) -> String {
  self.0
}

///|
/// Creates a label from a string.
fn impl_label_construct(name_ : String) -> Label raise HintedError {
  if name_.is_empty() {
    bail("label name must not be empty")
  }
  Label(name_)
}

///|
pub fn Label::repr(self : Label) -> String {
  let resolved = self.resolve()
  if @syntax.is_valid_label_literal_id(resolved) {
    "<\{resolved}>"
  } else {
    "label(\{repr_str(resolved)})"
  }
}
