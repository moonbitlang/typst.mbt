// Port of `wasmi_core/src/hint.rs` (optimizer hints; no-ops here).

///|
/// Indicates that the calling scope is unlikely to be executed.
pub fn cold() -> Unit {

}

///|
/// Indicates that the condition is likely `true`.
pub fn likely(condition : Bool) -> Bool {
  condition
}

///|
/// Indicates that the condition is unlikely `true`.
pub fn unlikely(condition : Bool) -> Bool {
  condition
}
