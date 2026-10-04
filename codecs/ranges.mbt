// Range checks shared by the kernels (`*_v128.mbt` and their scalar
// twins).

///|
/// Whether `[off, off + len)` lies within `[0, total)`, computed without
/// `Int` overflow (the `@v128` loads and stores are not bounds checked).
#inline
fn in_range(off : Int, len : Int64, total : Int) -> Bool {
  off >= 0 && len >= 0L && off.to_int64() + len <= total.to_int64()
}
