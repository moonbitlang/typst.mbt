// The deflate hash chain tables on native, wasm-gc and js (see
// `zlib_pos_table_v128.mbt` for wasm).

///|
/// A `head`/`prev` table of `u16` positions (upstream `Pos`).
#valtype
priv struct PosTable {
  array : FixedArray[UInt16]
}

///|
fn PosTable::make(n : Int) -> PosTable {
  { array: FixedArray::make(n, 0), }
}

///|
/// Entry `i` (`0 <= i < length`, unchecked).
#inline
fn PosTable::unsafe_get(self : PosTable, i : Int) -> Int {
  self.array.unsafe_get(i).to_int()
}

///|
/// Sets entry `i` (`0 <= i < length`, unchecked) to `v & 0xffff`.
#inline
fn PosTable::unsafe_set(self : PosTable, i : Int, v : Int) -> Unit {
  self.array.unsafe_set(i, v.to_uint16())
}

///|
fn PosTable::fill_zero(self : PosTable) -> Unit {
  self.array.fill(0)
}

///|
/// `m.saturating_sub(wsize)` for every entry.
fn slide_hash_chain(table : PosTable, wsize : Int) -> Unit {
  let array = table.array
  let wsize = wsize.to_uint16()
  for i in 0..<array.length() {
    let m = array.unsafe_get(i)
    array.unsafe_set(i, if m >= wsize { m - wsize } else { 0 })
  }
}
