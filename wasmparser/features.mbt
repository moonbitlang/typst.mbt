// Port of wasmparser 0.228.0 `src/features.rs` (with the `features` cargo
// feature on): the `WasmFeatures` bitflags.

///|
/// Flags for features that are enabled for validation.
///
/// The flags are the `UInt` constants below (`MUTABLE_GLOBAL`, `SIMD`, ...,
/// upstream's `WasmFeatures::MUTABLE_GLOBAL` etc.). `WasmFeatures` is an
/// immutable value: `set`, `union`, ... return a new set.
pub(all) struct WasmFeatures {
  bits : UInt
} derive(Eq, Hash)

///|
/// The WebAssembly `mutable-global` proposal.
pub const MUTABLE_GLOBAL : UInt = 1

///|
/// The WebAssembly `saturating-float-to-int` proposal.
pub const SATURATING_FLOAT_TO_INT : UInt = 0x2

///|
/// The WebAssembly `sign-extension-ops` proposal.
pub const SIGN_EXTENSION : UInt = 0x4

///|
/// The WebAssembly reference types proposal.
pub const REFERENCE_TYPES : UInt = 0x8

///|
/// The WebAssembly multi-value proposal.
pub const MULTI_VALUE : UInt = 0x10

///|
/// The WebAssembly bulk memory operations proposal.
pub const BULK_MEMORY : UInt = 0x20

///|
/// The WebAssembly SIMD proposal.
pub const SIMD : UInt = 0x40

///|
/// The WebAssembly Relaxed SIMD proposal.
pub const RELAXED_SIMD : UInt = 0x80

///|
/// The WebAssembly threads proposal.
pub const THREADS : UInt = 0x100

///|
/// The WebAssembly shared-everything-threads proposal; includes new
/// component model built-ins.
pub const SHARED_EVERYTHING_THREADS : UInt = 0x200

///|
/// The WebAssembly tail-call proposal.
pub const TAIL_CALL : UInt = 0x400

///|
/// Whether or not floating-point instructions are enabled.
pub const FLOATS : UInt = 0x800

///|
/// The WebAssembly multi memory proposal.
pub const MULTI_MEMORY : UInt = 0x1000

///|
/// The WebAssembly exception handling proposal.
pub const EXCEPTIONS : UInt = 0x2000

///|
/// The WebAssembly memory64 proposal.
pub const MEMORY64 : UInt = 0x4000

///|
/// The WebAssembly extended_const proposal.
pub const EXTENDED_CONST : UInt = 0x8000

///|
/// The WebAssembly component model proposal.
pub const COMPONENT_MODEL : UInt = 0x10000

///|
/// The WebAssembly typed function references proposal.
pub const FUNCTION_REFERENCES : UInt = 0x20000

///|
/// The WebAssembly memory control proposal.
pub const MEMORY_CONTROL : UInt = 0x40000

///|
/// The WebAssembly gc proposal.
pub const GC : UInt = 0x80000

///|
/// The WebAssembly custom-page-sizes proposal.
pub const CUSTOM_PAGE_SIZES : UInt = 0x100000

///|
/// Support for the legacy exceptions proposal.
pub const LEGACY_EXCEPTIONS : UInt = 0x800000

///|
/// Whether or not gc types are enabled.
pub const GC_TYPES : UInt = 0x1000000

///|
/// The WebAssembly stack-switching proposal.
pub const STACK_SWITCHING : UInt = 0x2000000

///|
/// The WebAssembly wide-arithmetic proposal.
pub const WIDE_ARITHMETIC : UInt = 0x4000000

///|
/// Support for values in the component model.
pub const CM_VALUES : UInt = 0x200000

///|
/// Support for the nested namespaces and projects in component model names.
pub const CM_NESTED_NAMES : UInt = 0x400000

///|
/// Support for component model async lift/lower ABI, as well as streams,
/// futures, and errors.
pub const CM_ASYNC : UInt = 0x8000000

///|
/// Gates the "stackful ABI" in the component model async proposal.
pub const CM_ASYNC_STACKFUL : UInt = 0x10000000

///|
/// Gates some intrinsics being marked with `async` in the component model
/// async proposal.
pub const CM_ASYNC_BUILTINS : UInt = 0x20000000

///|
/// All flags (`bitflags`' `all()`).
let all_feature_bits : UInt = MUTABLE_GLOBAL |
  SATURATING_FLOAT_TO_INT |
  SIGN_EXTENSION |
  REFERENCE_TYPES |
  MULTI_VALUE |
  BULK_MEMORY |
  SIMD |
  RELAXED_SIMD |
  THREADS |
  SHARED_EVERYTHING_THREADS |
  TAIL_CALL |
  FLOATS |
  MULTI_MEMORY |
  EXCEPTIONS |
  MEMORY64 |
  EXTENDED_CONST |
  COMPONENT_MODEL |
  FUNCTION_REFERENCES |
  MEMORY_CONTROL |
  GC |
  CUSTOM_PAGE_SIZES |
  LEGACY_EXCEPTIONS |
  GC_TYPES |
  STACK_SWITCHING |
  WIDE_ARITHMETIC |
  CM_VALUES |
  CM_NESTED_NAMES |
  CM_ASYNC |
  CM_ASYNC_STACKFUL |
  CM_ASYNC_BUILTINS

///|
pub fn WasmFeatures::empty() -> WasmFeatures {
  { bits: 0, }
}

///|
pub fn WasmFeatures::all() -> WasmFeatures {
  { bits: all_feature_bits, }
}

///|
pub fn WasmFeatures::from_bits_truncate(bits : UInt) -> WasmFeatures {
  { bits: bits & all_feature_bits, }
}

///|
pub fn WasmFeatures::bits(self : WasmFeatures) -> UInt {
  self.bits
}

///|
/// The default set of features (each flag's documented default).
pub fn WasmFeatures::default() -> WasmFeatures {
  let mut f = WasmFeatures::empty()
  f = f.set(MUTABLE_GLOBAL, true)
  f = f.set(SATURATING_FLOAT_TO_INT, true)
  f = f.set(SIGN_EXTENSION, true)
  f = f.set(REFERENCE_TYPES, true)
  f = f.set(MULTI_VALUE, true)
  f = f.set(BULK_MEMORY, true)
  f = f.set(SIMD, true)
  f = f.set(RELAXED_SIMD, true)
  f = f.set(THREADS, true)
  f = f.set(SHARED_EVERYTHING_THREADS, false)
  f = f.set(TAIL_CALL, true)
  f = f.set(FLOATS, true)
  f = f.set(MULTI_MEMORY, true)
  f = f.set(EXCEPTIONS, true)
  f = f.set(MEMORY64, true)
  f = f.set(EXTENDED_CONST, true)
  f = f.set(COMPONENT_MODEL, true)
  f = f.set(FUNCTION_REFERENCES, true)
  f = f.set(MEMORY_CONTROL, false)
  f = f.set(GC, true)
  f = f.set(CUSTOM_PAGE_SIZES, false)
  f = f.set(LEGACY_EXCEPTIONS, false)
  f = f.set(GC_TYPES, true)
  f = f.set(STACK_SWITCHING, false)
  f = f.set(WIDE_ARITHMETIC, false)
  f = f.set(CM_VALUES, false)
  f = f.set(CM_NESTED_NAMES, false)
  f = f.set(CM_ASYNC, false)
  f = f.set(CM_ASYNC_STACKFUL, false)
  f = f.set(CM_ASYNC_BUILTINS, false)
  f
}

///|
/// Returns the set with the `flags` inserted (`enable`) or removed.
pub fn WasmFeatures::set(
  self : WasmFeatures,
  flags : UInt,
  enable : Bool,
) -> WasmFeatures {
  if enable {
    { bits: self.bits | flags, }
  } else {
    { bits: self.bits & flags.lnot(), }
  }
}

///|
pub fn WasmFeatures::insert(self : WasmFeatures, flags : UInt) -> WasmFeatures {
  { bits: self.bits | flags, }
}

///|
pub fn WasmFeatures::remove(self : WasmFeatures, flags : UInt) -> WasmFeatures {
  { bits: self.bits & flags.lnot(), }
}

///|
/// Whether all of `flags` are set.
pub fn WasmFeatures::contains(self : WasmFeatures, flags : UInt) -> Bool {
  (self.bits & flags) == flags
}

///|
pub fn WasmFeatures::union(
  self : WasmFeatures,
  other : WasmFeatures,
) -> WasmFeatures {
  { bits: self.bits | other.bits, }
}

///|
pub fn WasmFeatures::mutable_global(self : WasmFeatures) -> Bool {
  self.contains(MUTABLE_GLOBAL)
}

///|
pub fn WasmFeatures::saturating_float_to_int(self : WasmFeatures) -> Bool {
  self.contains(SATURATING_FLOAT_TO_INT)
}

///|
pub fn WasmFeatures::sign_extension(self : WasmFeatures) -> Bool {
  self.contains(SIGN_EXTENSION)
}

///|
pub fn WasmFeatures::reference_types(self : WasmFeatures) -> Bool {
  self.contains(REFERENCE_TYPES)
}

///|
pub fn WasmFeatures::multi_value(self : WasmFeatures) -> Bool {
  self.contains(MULTI_VALUE)
}

///|
pub fn WasmFeatures::bulk_memory(self : WasmFeatures) -> Bool {
  self.contains(BULK_MEMORY)
}

///|
pub fn WasmFeatures::simd(self : WasmFeatures) -> Bool {
  self.contains(SIMD)
}

///|
pub fn WasmFeatures::relaxed_simd(self : WasmFeatures) -> Bool {
  self.contains(RELAXED_SIMD)
}

///|
pub fn WasmFeatures::threads(self : WasmFeatures) -> Bool {
  self.contains(THREADS)
}

///|
pub fn WasmFeatures::shared_everything_threads(self : WasmFeatures) -> Bool {
  self.contains(SHARED_EVERYTHING_THREADS)
}

///|
pub fn WasmFeatures::tail_call(self : WasmFeatures) -> Bool {
  self.contains(TAIL_CALL)
}

///|
pub fn WasmFeatures::floats(self : WasmFeatures) -> Bool {
  self.contains(FLOATS)
}

///|
pub fn WasmFeatures::multi_memory(self : WasmFeatures) -> Bool {
  self.contains(MULTI_MEMORY)
}

///|
pub fn WasmFeatures::exceptions(self : WasmFeatures) -> Bool {
  self.contains(EXCEPTIONS)
}

///|
pub fn WasmFeatures::memory64(self : WasmFeatures) -> Bool {
  self.contains(MEMORY64)
}

///|
pub fn WasmFeatures::extended_const(self : WasmFeatures) -> Bool {
  self.contains(EXTENDED_CONST)
}

///|
pub fn WasmFeatures::component_model(self : WasmFeatures) -> Bool {
  self.contains(COMPONENT_MODEL)
}

///|
pub fn WasmFeatures::function_references(self : WasmFeatures) -> Bool {
  self.contains(FUNCTION_REFERENCES)
}

///|
pub fn WasmFeatures::memory_control(self : WasmFeatures) -> Bool {
  self.contains(MEMORY_CONTROL)
}

///|
pub fn WasmFeatures::gc(self : WasmFeatures) -> Bool {
  self.contains(GC)
}

///|
pub fn WasmFeatures::custom_page_sizes(self : WasmFeatures) -> Bool {
  self.contains(CUSTOM_PAGE_SIZES)
}

///|
pub fn WasmFeatures::legacy_exceptions(self : WasmFeatures) -> Bool {
  self.contains(LEGACY_EXCEPTIONS)
}

///|
pub fn WasmFeatures::gc_types(self : WasmFeatures) -> Bool {
  self.contains(GC_TYPES)
}

///|
pub fn WasmFeatures::stack_switching(self : WasmFeatures) -> Bool {
  self.contains(STACK_SWITCHING)
}

///|
pub fn WasmFeatures::wide_arithmetic(self : WasmFeatures) -> Bool {
  self.contains(WIDE_ARITHMETIC)
}

///|
pub fn WasmFeatures::cm_values(self : WasmFeatures) -> Bool {
  self.contains(CM_VALUES)
}

///|
pub fn WasmFeatures::cm_nested_names(self : WasmFeatures) -> Bool {
  self.contains(CM_NESTED_NAMES)
}

///|
pub fn WasmFeatures::cm_async(self : WasmFeatures) -> Bool {
  self.contains(CM_ASYNC)
}

///|
pub fn WasmFeatures::cm_async_stackful(self : WasmFeatures) -> Bool {
  self.contains(CM_ASYNC_STACKFUL)
}

///|
pub fn WasmFeatures::cm_async_builtins(self : WasmFeatures) -> Bool {
  self.contains(CM_ASYNC_BUILTINS)
}

// The feature sets of the WebAssembly specification versions.

///|
/// The feature set associated with the 1.0 version of the WebAssembly
/// specification circa 2017.
///
/// Note that the features listed here are the wasmparser-specific built-in
/// features such as "floats" and "gc-types". These don't actually correspond
/// to any wasm proposals themselves and instead just gate constructs in
/// wasm. They're listed here so they otherwise don't have to be listed
/// below, but for example wasm with `externref` will be rejected due to lack
/// of `externref` first.
pub let wasm_features_mvp : WasmFeatures = { bits: FLOATS | GC_TYPES, }

///|
/// The feature set associated with the 1.0 version of the WebAssembly
/// specification circa 2017, with the mutable-global proposal.
pub let wasm_features_wasm1 : WasmFeatures = {
  bits: FLOATS | GC_TYPES | MUTABLE_GLOBAL,
}

///|
/// The feature set associated with the 2.0 version of the WebAssembly
/// specification circa 2022.
pub let wasm_features_wasm2 : WasmFeatures = {
  bits: wasm_features_wasm1.bits |
  BULK_MEMORY |
  REFERENCE_TYPES |
  SIGN_EXTENSION |
  SATURATING_FLOAT_TO_INT |
  MULTI_VALUE |
  SIMD,
}

///|
/// The feature set associated with the 3.0 version of the WebAssembly
/// specification.
pub let wasm_features_wasm3 : WasmFeatures = {
  bits: wasm_features_wasm2.bits |
  GC |
  TAIL_CALL |
  EXTENDED_CONST |
  FUNCTION_REFERENCES |
  MULTI_MEMORY |
  RELAXED_SIMD |
  THREADS |
  EXCEPTIONS |
  MEMORY64,
}

///|
fn WasmFeatures::needs_type_canonicalization(self : WasmFeatures) -> Bool {
  // Types from the function-references proposal and beyond (namely
  // GC) need type canonicalization for inter-type references and for
  // rec-groups to work. Prior proposals have no such inter-type
  // references structurally and as such can hit various fast paths in
  // the validator to do a bit less work when processing the type
  // section.
  //
  // None of these proposals below support inter-type references. If
  // `self` contains any proposal outside of this set then it requires
  // type canonicalization.
  let fast_validation_features = wasm_features_wasm2.bits |
    CUSTOM_PAGE_SIZES |
    EXTENDED_CONST |
    MEMORY64 |
    MULTI_MEMORY |
    RELAXED_SIMD |
    TAIL_CALL |
    THREADS |
    WIDE_ARITHMETIC
  (self.bits & fast_validation_features.lnot()) != 0
}
