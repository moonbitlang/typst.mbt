// Port of `wasmi_core/src/host_error.rs`.

///|
/// Trait that allows the host to return custom error.
///
/// It should be useful for representing custom traps,
/// troubles at instantiation time or other host specific conditions.
///
/// # Note
///
/// Upstream `HostError` is a `dyn Any + Display` trait object that is
/// downcast to the concrete error type. MoonBit's [`Error`] already is such
/// an open, pattern-matchable type: a host error is any MoonBit error, its
/// `Show` implementation serves as upstream's `Display`, and downcasting is
/// a pattern match (`trap.downcast_ref() is Some(MyError(..))`).
pub type HostError = Error
