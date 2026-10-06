// Port of `wasmi_core` 1.0.9 (`wasmi_core/src/lib.rs`) with the `simd`
// feature and without `std`: core primitives for the wasmi WebAssembly
// interpreter (Typst's plugin runtime).
//
// Module layout: `wasm.rs` -> `wasm.mbt`, `simd.rs` -> `simd*.mbt`,
// `memory/*.rs` -> `memory*.mbt`, `table/*.rs` -> `table*.mbt`, ...; all
// public items live in this one package (upstream's `wasm::` and `simd::`
// modules are flat here, their function names do not collide).
//
// Float semantics are bit-exact with upstream as compiled for aarch64 (where
// the oracle runs), on every MoonBit backend: `libm.mbt` ports the `libm`
// routines (`no_std` float paths) and `arm_nan.mbt` reproduces the Arm NaN
// propagation of the hardware float instructions.

///|
pub extend UntypedVal with Default::{default}

///|
pub extend FuelCostsProvider with Default::{default}

///|
pub extend MemoryTypeBuilder with Default::{default}

///|
pub extend ResourceLimiterRef with Default::{default}
