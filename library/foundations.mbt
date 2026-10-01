// Port of the functions in `typst-library/src/foundations/mod.rs`: `panic`
// and the `assert` family. (`repr` is in `repr.mbt`.)

///|
/// Fails with an error.
fn impl_panic(values_ : Array[Value]) -> Unit raise HintedError {
  let msg = StringBuilder()
  msg.write_string("panicked")
  if !values_.is_empty() {
    msg.write_string(" with: ")
    for i, value in values_ {
      if i > 0 {
        msg.write_string(", ")
      }
      match value {
        Str(s) => msg.write_string(s)
        _ => msg.write_string(value.repr())
      }
    }
  }
  bail(msg.to_string())
}

///|
/// Ensures that a condition is fulfilled.
fn impl_assert(condition_ : Bool, message_ : String?) -> Unit raise HintedError {
  if !condition_ {
    match message_ {
      Some(message) => bail("assertion failed: \{message}")
      None => bail("assertion failed")
    }
  }
}

///|
/// Ensures that two values are equal.
fn impl_assert_eq(
  left_ : Value,
  right_ : Value,
  message_ : String?,
) -> Unit raise HintedError {
  if !equal(left_, right_) {
    match message_ {
      Some(message) => bail("equality assertion failed: \{message}")
      None =>
        bail(
          "equality assertion failed: value \{left_.repr()} was not equal to \{right_.repr()}",
        )
    }
  }
}

///|
/// Ensures that two values are not equal.
fn impl_assert_ne(
  left_ : Value,
  right_ : Value,
  message_ : String?,
) -> Unit raise HintedError {
  if equal(left_, right_) {
    match message_ {
      Some(message) => bail("inequality assertion failed: \{message}")
      None =>
        bail(
          "inequality assertion failed: value \{left_.repr()} was equal to \{right_.repr()}",
        )
    }
  }
}
