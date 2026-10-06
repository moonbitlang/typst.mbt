// The subset of the serde data model that Typst's data loading formats use to
// exchange values with the library (upstream: `serde::{Serialize,
// Deserialize}` impls of `typst_library::foundations::Value`).
//
// Deserializers (`json`, `toml`, `yaml`, `cbor`) produce a `Data` tree in the
// shape upstream's `ValueVisitor` would observe it; serializers consume one
// produced from a `Value` the way upstream's `impl Serialize for Value` drives
// a serializer.

///|
/// A value in the serde data model.
pub(all) enum Data {
  /// `serialize_none` / `serialize_unit` / `visit_none` / `visit_unit`.
  None
  /// A boolean.
  Bool(Bool)
  /// An integer that fits into `i64`.
  Int(Int64)
  /// A floating-point number. Deserializers also produce this for integers
  /// that do not fit into `i64` (upstream's `IntoValue` for `u64`/`i128`/
  /// `u128` falls back to `f64` in that case).
  Float(Double)
  /// A string.
  Str(String)
  /// A byte string.
  Bytes(Bytes)
  /// A sequence.
  Seq(Array[Data])
  /// A map with string keys, in insertion order.
  Map(Array[(String, Data)])
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with @debug.Debug::{to_repr}

///|
/// The map key under which the `toml` crate exposes datetimes to
/// `deserialize_any` (upstream `toml_datetime::__unstable::FIELD`).
pub let toml_datetime_field : String = "$__toml_private_datetime"

///|
/// Converts an unsigned 64-bit integer the way upstream's `IntoValue for u64`
/// does: as an `Int` if it fits into `i64`, otherwise as a `Float`.
pub fn Data::from_u64(v : UInt64) -> Data {
  if v <= 0x7FFF_FFFF_FFFF_FFFFUL {
    Int(v.reinterpret_as_int64())
  } else {
    Float(v.to_double())
  }
}
