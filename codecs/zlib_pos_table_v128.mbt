// The deflate hash chain tables on wasm: `u16` entries in a byte array so
// that `slide_hash` uses v128 saturating subtraction (15x faster than the
// scalar loop there). `zlib_pos_table_scalar.mbt` is the counterpart for the
// other targets; on native it is as fast as v128 (clang vectorizes the loop,
// which is memory bound) and `FixedArray[UInt16]` indexing keeps the
// `longest_match` chain walk one instruction shorter.

///|
/// A `head`/`prev` table of `u16` positions (upstream `Pos`), stored
/// little-endian in a byte array so that [slide_hash_chain] runs on v128 lanes
/// (`FixedArray[UInt16]` cannot be loaded as v128).
#valtype
priv struct PosTable {
  bytes : FixedArray[Byte]
}

///|
fn PosTable::make(n : Int) -> PosTable {
  { bytes: FixedArray::make(2 * n, b'\x00'), }
}

///|
fn PosTable::length(self : PosTable) -> Int {
  self.bytes.length() >> 1
}

///|
/// Entry `i` (`0 <= i < length`, unchecked).
#inline
fn PosTable::unsafe_get(self : PosTable, i : Int) -> Int {
  @v128.i16x8_extract_lane_u(@v128.v128_load16_splat(self.bytes, 2 * i), 0).reinterpret_as_int()
}

///|
/// Sets entry `i` (`0 <= i < length`, unchecked) to `v & 0xffff`.
#inline
fn PosTable::unsafe_set(self : PosTable, i : Int, v : Int) -> Unit {
  @v128.v128_store16_lane(
    self.bytes,
    2 * i,
    @v128.i16x8_splat(v.to_uint16()),
    0,
  )
}

///|
fn PosTable::fill_zero(self : PosTable) -> Unit {
  self.bytes.fill(b'\x00')
}

///|
/// `m.saturating_sub(wsize)` for every entry (upstream's NEON/wasm
/// `slide_hash_chain` uses the same saturating `u16` lanes).
fn slide_hash_chain(table : PosTable, wsize : Int) -> Unit {
  let bytes = table.bytes
  let w = @v128.i16x8_splat(wsize.to_uint16())
  let len = bytes.length()
  let mut i = 0
  // 64 bytes per iteration (like upstream's 32-entry chunks).
  while i <= len - 64 {
    let a0 = @v128.v128_load(bytes, i)
    let a1 = @v128.v128_load(bytes, i + 16)
    let a2 = @v128.v128_load(bytes, i + 32)
    let a3 = @v128.v128_load(bytes, i + 48)
    @v128.v128_store(bytes, i, @v128.i16x8_sub_sat_u(a0, w))
    @v128.v128_store(bytes, i + 16, @v128.i16x8_sub_sat_u(a1, w))
    @v128.v128_store(bytes, i + 32, @v128.i16x8_sub_sat_u(a2, w))
    @v128.v128_store(bytes, i + 48, @v128.i16x8_sub_sat_u(a3, w))
    i += 64
  }
  for j in (i >> 1)..<table.length() {
    let m = table.unsafe_get(j)
    table.unsafe_set(j, if m >= wsize { m - wsize } else { 0 })
  }
}
