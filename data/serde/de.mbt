// Helpers reproducing `serde`'s (serde_core 1.0.228) deserialization error
// messages.

///|
/// Upstream `serde::de::Unexpected`'s `Display` for a float:
/// "floating point `1.0`" (via `WithDecimalPoint`).
pub fn with_decimal_point(f : Double) -> String {
  let s = format_display(f)
  if !f.is_nan() && !f.is_inf() && !s.contains(".") {
    s + ".0"
  } else {
    s
  }
}

///|
/// Upstream `serde::de::Error::invalid_type`'s message.
pub fn invalid_type(unexpected : String, expected : String) -> String {
  "invalid type: \{unexpected}, expected \{expected}"
}

///|
/// The `expecting` text of Typst's `ValueVisitor`.
pub let expecting_typst_value : String = "a Typst value"

///|
test "with_decimal_point" {
  inspect(with_decimal_point(1.0), content="1.0")
  inspect(with_decimal_point(1.5), content="1.5")
  inspect(with_decimal_point(1.0e20), content="100000000000000000000.0")
  inspect(with_decimal_point(1.0 / 0.0), content="inf")
  inspect(with_decimal_point(0.0 / 0.0), content="NaN")
}
