// Port of wasmparser 0.228.0 `src/limits.rs`.
//
// The following limits are imposed by wasmparser on WebAssembly modules.
// The limits are agreed upon with other engines for consistency.

///|
pub const MAX_WASM_TYPES : Int = 1_000_000

///|
pub const MAX_WASM_SUPERTYPES : Int = 1

///|
pub const MAX_WASM_FUNCTIONS : Int = 1_000_000

///|
pub const MAX_WASM_IMPORTS : Int = 1_000_000

///|
pub const MAX_WASM_EXPORTS : Int = 1_000_000

///|
pub const MAX_WASM_GLOBALS : Int = 1_000_000

///|
pub const MAX_WASM_ELEMENT_SEGMENTS : Int = 100_000

///|
pub const MAX_WASM_DATA_SEGMENTS : Int = 100_000

///|
pub const MAX_WASM_STRING_SIZE : Int = 100_000

///|
pub const MAX_WASM_FUNCTION_SIZE : Int = 128 * 1024

///|
pub const MAX_WASM_FUNCTION_LOCALS : Int = 50000

///|
pub const MAX_WASM_FUNCTION_PARAMS : Int = 1000

///|
pub const MAX_WASM_FUNCTION_RETURNS : Int = 1000

///|
pub const MAX_WASM_TABLE_ENTRIES : Int = 10_000_000

///|
pub const MAX_WASM_TABLES : Int = 100

///|
pub const MAX_WASM_MEMORIES : Int = 100

///|
pub const MAX_WASM_TAGS : Int = 1_000_000

///|
pub const MAX_WASM_BR_TABLE_SIZE : Int = MAX_WASM_FUNCTION_SIZE

///|
pub const MAX_WASM_STRUCT_FIELDS : Int = 10_000

///|
pub const MAX_WASM_CATCHES : Int = 10_000

///|
pub const MAX_WASM_SUBTYPING_DEPTH : Int = 63

///|
pub const MAX_WASM_HANDLERS : Int = 10_000

///|
pub const MAX_WASM_TYPE_SIZE : UInt = 1_000_000

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
