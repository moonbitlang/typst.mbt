// What `cbrt.rs` uses of the `libm` crate's `support` module (0.2.16):
// `support/env.rs` (`FpResult`, `Round`, `Status`), `support/mod.rs`
// (`cold_path`), `support/float_traits.rs` (the `Float` constants and
// methods of `f64`).

///|
/// A value combined with a floating point status.
///
/// Upstream is generic (`FpResult<T>`); only `f64` results are ported, so
/// that the struct can be a value type. Nothing reads `status`, like
/// upstream outside of its `unstable-public-internals` feature
/// (`allow(dead_code)`, libm `src/math/support/env.rs:17`).
#valtype
#warnings("-unused_field")
priv struct FpResult {
  val : Double
  status : Status
}

///|
/// Return `val` with `Status::OK`.
fn FpResult::ok(val : Double) -> FpResult {
  { val, status: Status::ok(), }
}

///|
/// IEEE 754 rounding mode, excluding the optional `roundTiesToAway` version of nearest.
///
/// Integer representation comes from what CORE-MATH uses for indexing.
///
/// Only `Nearest` is constructed (upstream: `allow(dead_code)`, libm
/// `src/math/support/env.rs:38`): Rust has no floating point environment, and
/// the only caller of `cbrt_round` is `cbrt` (`src/math/cbrt.rs:13`).
#warnings("-unused_constructor")
priv enum Round {
  /// IEEE 754 nearest, `roundTiesToEven`.
  Nearest
  /// IEEE 754 `roundTowardNegative`.
  Negative
  /// IEEE 754 `roundTowardPositive`.
  Positive
  /// IEEE 754 `roundTowardZero`.
  Zero
} derive(Eq)

///|
/// `round as usize`.
fn Round::to_int(self : Round) -> Int {
  match self {
    Nearest => 0
    Negative => 1
    Positive => 2
    Zero => 3
  }
}

///|
/// IEEE 754 exception status flags.
///
/// Never read, like the `status` it is the type of (libm
/// `src/math/support/env.rs:17`).
#warnings("-unused_constructor")
priv struct Status(Int)

///|
/// Default status indicating no errors (`Status::OK`).
fn Status::ok() -> Status {
  Status(0)
}

///|
/// Hint to the compiler that the current path is cold.
fn cold_path() -> Unit {

}

///|
/// The bitwidth of the significand (`f64::SIG_BITS`).
const F64_SIG_BITS : Int = 52

///|
/// The saturated (maximum bitpattern) value of the exponent, i.e. the infinite
/// representation (`f64::EXP_SAT`).
const F64_EXP_SAT : UInt = 0x7ff

///|
/// A mask for the sign bit (`f64::SIGN_MASK`).
const F64_SIGN_MASK : UInt64 = 0x8000000000000000UL

///|
/// A mask for the significand (`f64::SIG_MASK`).
const F64_SIG_MASK : UInt64 = 0x000fffffffffffffUL

///|
/// `Float::fma`: `libm::fma`, a fused multiply-add with a single rounding
/// (the C library's on native targets, exact software elsewhere).
fn fma(x : Double, y : Double, z : Double) -> Double {
  @pxfm.fma(x, y, z)
}

///|
/// `Float::copysign`.
fn copysign(x : Double, sign : Double) -> Double {
  ((x.reinterpret_as_uint64() & F64_SIGN_MASK.lnot()) |
  (sign.reinterpret_as_uint64() & F64_SIGN_MASK)).reinterpret_as_double()
}
