// Port of wasmparser 0.228.0 `src/limits.rs`.
//
// The following limits are imposed by wasmparser on WebAssembly modules.
// The limits are agreed upon with other engines for consistency.

///|
pub const MAX_WASM_TYPES : Int32 = 1_000_000

///|
pub const MAX_WASM_SUPERTYPES : Int32 = 1

///|
pub const MAX_WASM_FUNCTIONS : Int32 = 1_000_000

///|
pub const MAX_WASM_IMPORTS : Int32 = 1_000_000

///|
pub const MAX_WASM_EXPORTS : Int32 = 1_000_000

///|
pub const MAX_WASM_GLOBALS : Int32 = 1_000_000

///|
pub const MAX_WASM_ELEMENT_SEGMENTS : Int32 = 100_000

///|
pub const MAX_WASM_DATA_SEGMENTS : Int32 = 100_000

///|
pub const MAX_WASM_STRING_SIZE : Int32 = 100_000

///|
pub const MAX_WASM_FUNCTION_SIZE : Int32 = 128 * 1024

///|
pub const MAX_WASM_FUNCTION_LOCALS : Int32 = 50000

///|
pub const MAX_WASM_FUNCTION_PARAMS : Int32 = 1000

///|
pub const MAX_WASM_FUNCTION_RETURNS : Int32 = 1000

///|
pub const MAX_WASM_TABLE_ENTRIES : Int32 = 10_000_000

///|
pub const MAX_WASM_TABLES : Int32 = 100

///|
pub const MAX_WASM_MEMORIES : Int32 = 100

///|
pub const MAX_WASM_TAGS : Int32 = 1_000_000

///|
pub const MAX_WASM_BR_TABLE_SIZE : Int32 = MAX_WASM_FUNCTION_SIZE

///|
pub const MAX_WASM_STRUCT_FIELDS : Int32 = 10_000

///|
pub const MAX_WASM_CATCHES : Int32 = 10_000

///|
pub const MAX_WASM_SUBTYPING_DEPTH : Int32 = 63

///|
pub const MAX_WASM_HANDLERS : Int32 = 10_000

///|
pub const MAX_WASM_TYPE_SIZE : UInt32 = 1_000_000

///|
pub const DEFAULT_WASM_PAGE_SIZE : UInt64 = 65536

///|
pub fn max_wasm_memory32_pages(page_size : UInt64) -> UInt64 {
  if !(page_size.popcnt() == 1 && page_size <= DEFAULT_WASM_PAGE_SIZE) {
    abort(
      "assertion failed: page_size.popcnt() == 1 && page_size <= DEFAULT_WASM_PAGE_SIZE",
    )
  }
  (1UL << 32) / page_size
}

///|
pub fn max_wasm_memory64_pages(page_size : UInt64) -> UInt64 {
  if !(page_size.popcnt() == 1 && page_size <= DEFAULT_WASM_PAGE_SIZE) {
    abort(
      "assertion failed: page_size.popcnt() == 1 && page_size <= DEFAULT_WASM_PAGE_SIZE",
    )
  }
  // `u64::try_from((1_u128 << 64) / u128::from(page_size)).unwrap_or(u64::MAX)`
  if page_size == 1 {
    0xFFFF_FFFF_FFFF_FFFFUL
  } else {
    // 2**64 / 2**k = 2**(64 - k)
    1UL << (64 - page_size.ctz())
  }
}
