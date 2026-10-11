// Differential tests against `wasmi_core` 1.0.9 (features `simd`, no `std`).
// The expected results are recorded in `testdata/oracle.tsv` by
// `oracle/src/bin/gen_wasmi_core_tests.rs` (see there for the format and the
// regeneration command).

///|
fn oracle_module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
fn parse_hex(s : StringView) -> UInt64 {
  let mut v = 0UL
  for c in s {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      c.to_int() - 'a'.to_int() + 10
    }
    v = (v << 4) | d.to_uint64()
  }
  v
}

///|
fn hex_n(v : UInt64, digits : Int) -> String {
  let chars = "0123456789abcdef"
  let buf = StringBuilder()
  for i = digits - 1; i >= 0; i = i - 1 {
    buf.write_char(chars[((v >> (i * 4)) & 0xFUL).to_int()].unsafe_to_char())
  }
  buf.to_string()
}

///|
fn h32(v : UInt) -> String {
  hex_n(v.to_uint64(), 8)
}

///|
fn h32i(v : Int) -> String {
  h32(v.reinterpret_as_uint())
}

///|
fn h64(v : UInt64) -> String {
  hex_n(v, 16)
}

///|
fn h64i(v : Int64) -> String {
  h64(v.reinterpret_as_uint64())
}

///|
fn hf32(v : Float) -> String {
  h32(v.reinterpret_as_uint())
}

///|
fn hf64(v : Double) -> String {
  h64(v.reinterpret_as_uint64())
}

///|
fn hv(v : V128Value) -> String {
  hex_n(v.hi, 16) + hex_n(v.lo, 16)
}

///|
fn hb(v : Bool) -> String {
  if v {
    "1"
  } else {
    "0"
  }
}

///|
fn hmem(m : FixedArray[Byte], len : Int) -> String {
  let buf = StringBuilder()
  for i in 0..<len {
    buf.write_string(hex_n(m[i].to_uint64(), 2))
  }
  buf.to_string()
}

///|
fn trap_str(t : TrapCode) -> String {
  "!\{t.to_u8().to_int()}"
}

///|
fn a_u32(s : String) -> UInt {
  parse_hex(s).to_uint()
}

///|
fn a_i32(s : String) -> Int {
  parse_hex(s).to_uint().reinterpret_as_int()
}

///|
fn a_u64(s : String) -> UInt64 {
  parse_hex(s)
}

///|
fn a_i64(s : String) -> Int64 {
  parse_hex(s).reinterpret_as_int64()
}

///|
fn a_f32(s : String) -> Float {
  Float::reinterpret_from_uint(a_u32(s))
}

///|
fn a_f64(s : String) -> Double {
  a_u64(s).reinterpret_as_double()
}

///|
fn a_v128(s : String) -> V128Value {
  {
    hi: parse_hex(s.view(end_offset=16)),
    lo: parse_hex(s.view(start_offset=16)),
  }
}

///|
type OracleFn = (Array[String]) -> String

///|
fn ii_i(f : (Int, Int) -> Int) -> OracleFn {
  a => h32i(f(a_i32(a[0]), a_i32(a[1])))
}

///|
fn ii_t(f : (Int, Int) -> Int raise TrapCode) -> OracleFn {
  a => h32i(f(a_i32(a[0]), a_i32(a[1]))) catch { t => trap_str(t) }
}

///|
fn uu_t(f : (UInt, UInt) -> UInt raise TrapCode) -> OracleFn {
  a => h32(f(a_u32(a[0]), a_u32(a[1]))) catch { t => trap_str(t) }
}

///|
fn ii_b(f : (Int, Int) -> Bool) -> OracleFn {
  a => hb(f(a_i32(a[0]), a_i32(a[1])))
}

///|
fn uu_b(f : (UInt, UInt) -> Bool) -> OracleFn {
  a => hb(f(a_u32(a[0]), a_u32(a[1])))
}

///|
fn ll_l(f : (Int64, Int64) -> Int64) -> OracleFn {
  a => h64i(f(a_i64(a[0]), a_i64(a[1])))
}

///|
fn ll_t(f : (Int64, Int64) -> Int64 raise TrapCode) -> OracleFn {
  a => h64i(f(a_i64(a[0]), a_i64(a[1]))) catch { t => trap_str(t) }
}

///|
fn qq_t(f : (UInt64, UInt64) -> UInt64 raise TrapCode) -> OracleFn {
  a => h64(f(a_u64(a[0]), a_u64(a[1]))) catch { t => trap_str(t) }
}

///|
fn ll_b(f : (Int64, Int64) -> Bool) -> OracleFn {
  a => hb(f(a_i64(a[0]), a_i64(a[1])))
}

///|
fn qq_b(f : (UInt64, UInt64) -> Bool) -> OracleFn {
  a => hb(f(a_u64(a[0]), a_u64(a[1])))
}

///|
fn ff_f(f : (Float, Float) -> Float) -> OracleFn {
  a => hf32(f(a_f32(a[0]), a_f32(a[1])))
}

///|
fn ff_b(f : (Float, Float) -> Bool) -> OracleFn {
  a => hb(f(a_f32(a[0]), a_f32(a[1])))
}

///|
fn dd_d(f : (Double, Double) -> Double) -> OracleFn {
  a => hf64(f(a_f64(a[0]), a_f64(a[1])))
}

///|
fn dd_b(f : (Double, Double) -> Bool) -> OracleFn {
  a => hb(f(a_f64(a[0]), a_f64(a[1])))
}

///|
fn v_v(f : (V128Value) -> V128Value) -> OracleFn {
  a => hv(f(a_v128(a[0])))
}

///|
fn vv_v(f : (V128Value, V128Value) -> V128Value) -> OracleFn {
  a => hv(f(a_v128(a[0]), a_v128(a[1])))
}

///|
fn vvv_v(f : (V128Value, V128Value, V128Value) -> V128Value) -> OracleFn {
  a => hv(f(a_v128(a[0]), a_v128(a[1]), a_v128(a[2])))
}

///|
fn vu_v(f : (V128Value, UInt) -> V128Value) -> OracleFn {
  a => hv(f(a_v128(a[0]), a_u32(a[1])))
}

///|
/// The 40 byte test memory, with spare capacity beyond its length.
fn mem_init() -> FixedArray[Byte] {
  FixedArray::makei(48, i => if i < 40 { (i * 37 + 11).to_byte() } else { 0 })
}

///|
let mem_len : Int = 40

///|
fn load(
  f : (FixedArray[Byte], Int, UInt64, UInt64) -> String raise TrapCode,
) -> OracleFn {
  a => {
    f(mem_init(), mem_len, a_u64(a[0]), a_u64(a[1])) catch {
      t => trap_str(t)
    }
  }
}

///|
fn load_at(
  f : (FixedArray[Byte], Int, UInt64) -> String raise TrapCode,
) -> OracleFn {
  a => f(mem_init(), mem_len, a_u64(a[0])) catch { t => trap_str(t) }
}

///|
fn store(
  f : (FixedArray[Byte], Int, UInt64, UInt64, String) -> Unit raise TrapCode,
) -> OracleFn {
  a => {
    let m = mem_init()
    f(m, mem_len, a_u64(a[0]), a_u64(a[1]), a[2]) catch {
      t => return trap_str(t) + ":" + hmem(m, mem_len)
    }
    hmem(m, mem_len)
  }
}

///|
fn store_at(
  f : (FixedArray[Byte], Int, UInt64, String) -> Unit raise TrapCode,
) -> OracleFn {
  a => {
    let m = mem_init()
    f(m, mem_len, a_u64(a[0]), a[1]) catch {
      t => return trap_str(t) + ":" + hmem(m, mem_len)
    }
    hmem(m, mem_len)
  }
}

///|
fn lane2(s : String) -> ImmLaneIdx2 {
  ImmLaneIdx2(a_u32(s).to_byte())
}

///|
fn lane4(s : String) -> ImmLaneIdx4 {
  ImmLaneIdx4(a_u32(s).to_byte())
}

///|
fn lane8(s : String) -> ImmLaneIdx8 {
  ImmLaneIdx8(a_u32(s).to_byte())
}

///|
fn lane16(s : String) -> ImmLaneIdx16 {
  ImmLaneIdx16(a_u32(s).to_byte())
}

///|
fn pair_hex(p : (Int64, Int64)) -> String {
  h64i(p.0) + h64i(p.1)
}

///|
fn oracle_scalar_ops(ops : Map[String, OracleFn]) -> Unit {
  ops["i32_add"] = ii_i(i32_add)
  ops["i32_sub"] = ii_i(i32_sub)
  ops["i32_mul"] = ii_i(i32_mul)
  ops["i32_bitand"] = ii_i(i32_bitand)
  ops["i32_bitor"] = ii_i(i32_bitor)
  ops["i32_bitxor"] = ii_i(i32_bitxor)
  ops["i32_shl"] = ii_i(i32_shl)
  ops["i32_shr_s"] = ii_i(i32_shr_s)
  ops["i32_shr_u"] = ii_i(i32_shr_u)
  ops["i32_rotl"] = ii_i(i32_rotl)
  ops["i32_rotr"] = ii_i(i32_rotr)
  ops["i32_div_s"] = ii_t(i32_div_s)
  ops["i32_div_u"] = uu_t(i32_div_u)
  ops["i32_rem_s"] = ii_t(i32_rem_s)
  ops["i32_rem_u"] = uu_t(i32_rem_u)
  ops["i32_eq"] = ii_b(i32_eq)
  ops["i32_ne"] = ii_b(i32_ne)
  ops["i32_lt_s"] = ii_b(i32_lt_s)
  ops["i32_lt_u"] = uu_b(i32_lt_u)
  ops["i32_le_s"] = ii_b(i32_le_s)
  ops["i32_le_u"] = uu_b(i32_le_u)
  ops["i32_gt_s"] = ii_b(i32_gt_s)
  ops["i32_gt_u"] = uu_b(i32_gt_u)
  ops["i32_ge_s"] = ii_b(i32_ge_s)
  ops["i32_ge_u"] = uu_b(i32_ge_u)
  ops["i64_add"] = ll_l(i64_add)
  ops["i64_sub"] = ll_l(i64_sub)
  ops["i64_mul"] = ll_l(i64_mul)
  ops["i64_bitand"] = ll_l(i64_bitand)
  ops["i64_bitor"] = ll_l(i64_bitor)
  ops["i64_bitxor"] = ll_l(i64_bitxor)
  ops["i64_shl"] = ll_l(i64_shl)
  ops["i64_shr_s"] = ll_l(i64_shr_s)
  ops["i64_shr_u"] = ll_l(i64_shr_u)
  ops["i64_rotl"] = ll_l(i64_rotl)
  ops["i64_rotr"] = ll_l(i64_rotr)
  ops["i64_div_s"] = ll_t(i64_div_s)
  ops["i64_div_u"] = qq_t(i64_div_u)
  ops["i64_rem_s"] = ll_t(i64_rem_s)
  ops["i64_rem_u"] = qq_t(i64_rem_u)
  ops["i64_eq"] = ll_b(i64_eq)
  ops["i64_ne"] = ll_b(i64_ne)
  ops["i64_lt_s"] = ll_b(i64_lt_s)
  ops["i64_lt_u"] = qq_b(i64_lt_u)
  ops["i64_le_s"] = ll_b(i64_le_s)
  ops["i64_le_u"] = qq_b(i64_le_u)
  ops["i64_gt_s"] = ll_b(i64_gt_s)
  ops["i64_gt_u"] = qq_b(i64_gt_u)
  ops["i64_ge_s"] = ll_b(i64_ge_s)
  ops["i64_ge_u"] = qq_b(i64_ge_u)
  ops["i32_clz"] = a => h32i(i32_clz(a_i32(a[0])))
  ops["i32_ctz"] = a => h32i(i32_ctz(a_i32(a[0])))
  ops["i32_popcnt"] = a => h32i(i32_popcnt(a_i32(a[0])))
  ops["i32_eqz"] = a => hb(i32_eqz(a_i32(a[0])))
  ops["i32_extend8_s"] = a => h32i(i32_extend8_s(a_i32(a[0])))
  ops["i32_extend16_s"] = a => h32i(i32_extend16_s(a_i32(a[0])))
  ops["i64_extend_i32_s"] = a => h64i(i64_extend_i32_s(a_i32(a[0])))
  ops["i64_extend_i32_u"] = a => h64(i64_extend_i32_u(a_u32(a[0])))
  ops["f32_convert_i32_s"] = a => hf32(f32_convert_i32_s(a_i32(a[0])))
  ops["f32_convert_i32_u"] = a => hf32(f32_convert_i32_u(a_u32(a[0])))
  ops["f64_convert_i32_s"] = a => hf64(f64_convert_i32_s(a_i32(a[0])))
  ops["f64_convert_i32_u"] = a => hf64(f64_convert_i32_u(a_u32(a[0])))
  ops["f32_reinterpret_i32"] = a => hf32(f32_reinterpret_i32(a_i32(a[0])))
  ops["i64_clz"] = a => h64i(i64_clz(a_i64(a[0])))
  ops["i64_ctz"] = a => h64i(i64_ctz(a_i64(a[0])))
  ops["i64_popcnt"] = a => h64i(i64_popcnt(a_i64(a[0])))
  ops["i64_eqz"] = a => hb(i64_eqz(a_i64(a[0])))
  ops["i64_extend8_s"] = a => h64i(i64_extend8_s(a_i64(a[0])))
  ops["i64_extend16_s"] = a => h64i(i64_extend16_s(a_i64(a[0])))
  ops["i64_extend32_s"] = a => h64i(i64_extend32_s(a_i64(a[0])))
  ops["i32_wrap_i64"] = a => h32i(i32_wrap_i64(a_i64(a[0])))
  ops["f64_reinterpret_i64"] = a => hf64(f64_reinterpret_i64(a_i64(a[0])))
  ops["f32_convert_i64_s"] = a => hf32(f32_convert_i64_s(a_i64(a[0])))
  ops["f32_convert_i64_u"] = a => hf32(f32_convert_i64_u(a_u64(a[0])))
  ops["f64_convert_i64_s"] = a => hf64(f64_convert_i64_s(a_i64(a[0])))
  ops["f64_convert_i64_u"] = a => hf64(f64_convert_i64_u(a_u64(a[0])))
  ops["i64_add128"] = a => {
    pair_hex(i64_add128(a_i64(a[0]), a_i64(a[1]), a_i64(a[2]), a_i64(a[3])))
  }
  ops["i64_sub128"] = a => {
    pair_hex(i64_sub128(a_i64(a[0]), a_i64(a[1]), a_i64(a[2]), a_i64(a[3])))
  }
  ops["i64_mul_wide_s"] = a => {
    pair_hex(i64_mul_wide_s(a_i64(a[0]), a_i64(a[1])))
  }
  ops["i64_mul_wide_u"] = a => {
    pair_hex(i64_mul_wide_u(a_i64(a[0]), a_i64(a[1])))
  }
}

///|
fn oracle_float_ops(ops : Map[String, OracleFn]) -> Unit {
  ops["f32_add"] = ff_f(f32_add)
  ops["f32_sub"] = ff_f(f32_sub)
  ops["f32_mul"] = ff_f(f32_mul)
  ops["f32_div"] = ff_f(f32_div)
  ops["f32_min"] = ff_f(f32_min)
  ops["f32_max"] = ff_f(f32_max)
  ops["f32_copysign"] = ff_f(f32_copysign)
  ops["f32_eq"] = ff_b(f32_eq)
  ops["f32_ne"] = ff_b(f32_ne)
  ops["f32_lt"] = ff_b(f32_lt)
  ops["f32_le"] = ff_b(f32_le)
  ops["f32_gt"] = ff_b(f32_gt)
  ops["f32_ge"] = ff_b(f32_ge)
  ops["f64_add"] = dd_d(f64_add)
  ops["f64_sub"] = dd_d(f64_sub)
  ops["f64_mul"] = dd_d(f64_mul)
  ops["f64_div"] = dd_d(f64_div)
  ops["f64_min"] = dd_d(f64_min)
  ops["f64_max"] = dd_d(f64_max)
  ops["f64_copysign"] = dd_d(f64_copysign)
  ops["f64_eq"] = dd_b(f64_eq)
  ops["f64_ne"] = dd_b(f64_ne)
  ops["f64_lt"] = dd_b(f64_lt)
  ops["f64_le"] = dd_b(f64_le)
  ops["f64_gt"] = dd_b(f64_gt)
  ops["f64_ge"] = dd_b(f64_ge)
  ops["f32_abs"] = a => hf32(f32_abs(a_f32(a[0])))
  ops["f32_neg"] = a => hf32(f32_neg(a_f32(a[0])))
  ops["f32_ceil"] = a => hf32(f32_ceil(a_f32(a[0])))
  ops["f32_floor"] = a => hf32(f32_floor(a_f32(a[0])))
  ops["f32_trunc"] = a => hf32(f32_trunc(a_f32(a[0])))
  ops["f32_nearest"] = a => hf32(f32_nearest(a_f32(a[0])))
  ops["f32_sqrt"] = a => hf32(f32_sqrt(a_f32(a[0])))
  ops["f64_promote_f32"] = a => hf64(f64_promote_f32(a_f32(a[0])))
  ops["i32_reinterpret_f32"] = a => h32i(i32_reinterpret_f32(a_f32(a[0])))
  ops["i32_trunc_f32_s"] = a => {
    h32i(i32_trunc_f32_s(a_f32(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i32_trunc_f32_u"] = a => {
    h32(i32_trunc_f32_u(a_f32(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i64_trunc_f32_s"] = a => {
    h64i(i64_trunc_f32_s(a_f32(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i64_trunc_f32_u"] = a => {
    h64(i64_trunc_f32_u(a_f32(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i32_trunc_sat_f32_s"] = a => h32i(i32_trunc_sat_f32_s(a_f32(a[0])))
  ops["i32_trunc_sat_f32_u"] = a => h32(i32_trunc_sat_f32_u(a_f32(a[0])))
  ops["i64_trunc_sat_f32_s"] = a => h64i(i64_trunc_sat_f32_s(a_f32(a[0])))
  ops["i64_trunc_sat_f32_u"] = a => h64(i64_trunc_sat_f32_u(a_f32(a[0])))
  ops["f64_abs"] = a => hf64(f64_abs(a_f64(a[0])))
  ops["f64_neg"] = a => hf64(f64_neg(a_f64(a[0])))
  ops["f64_ceil"] = a => hf64(f64_ceil(a_f64(a[0])))
  ops["f64_floor"] = a => hf64(f64_floor(a_f64(a[0])))
  ops["f64_trunc"] = a => hf64(f64_trunc(a_f64(a[0])))
  ops["f64_nearest"] = a => hf64(f64_nearest(a_f64(a[0])))
  ops["f64_sqrt"] = a => hf64(f64_sqrt(a_f64(a[0])))
  ops["f32_demote_f64"] = a => hf32(f32_demote_f64(a_f64(a[0])))
  ops["i64_reinterpret_f64"] = a => h64i(i64_reinterpret_f64(a_f64(a[0])))
  ops["i32_trunc_f64_s"] = a => {
    h32i(i32_trunc_f64_s(a_f64(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i32_trunc_f64_u"] = a => {
    h32(i32_trunc_f64_u(a_f64(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i64_trunc_f64_s"] = a => {
    h64i(i64_trunc_f64_s(a_f64(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i64_trunc_f64_u"] = a => {
    h64(i64_trunc_f64_u(a_f64(a[0]))) catch {
      t => trap_str(t)
    }
  }
  ops["i32_trunc_sat_f64_s"] = a => h32i(i32_trunc_sat_f64_s(a_f64(a[0])))
  ops["i32_trunc_sat_f64_u"] = a => h32(i32_trunc_sat_f64_u(a_f64(a[0])))
  ops["i64_trunc_sat_f64_s"] = a => h64i(i64_trunc_sat_f64_s(a_f64(a[0])))
  ops["i64_trunc_sat_f64_u"] = a => h64(i64_trunc_sat_f64_u(a_f64(a[0])))
}

///|
fn oracle_simd_ops(ops : Map[String, OracleFn]) -> Unit {
  let unary : Array[(String, (V128Value) -> V128Value)] = [
    ("i64x2_neg", i64x2_neg),
    ("i32x4_neg", i32x4_neg),
    ("i16x8_neg", i16x8_neg),
    ("i8x16_neg", i8x16_neg),
    ("i8x16_abs", i8x16_abs),
    ("i16x8_abs", i16x8_abs),
    ("i32x4_abs", i32x4_abs),
    ("i64x2_abs", i64x2_abs),
    ("v128_not", v128_not),
    ("i8x16_popcnt", i8x16_popcnt),
    ("f32x4_neg", f32x4_neg),
    ("f64x2_neg", f64x2_neg),
    ("f32x4_abs", f32x4_abs),
    ("f64x2_abs", f64x2_abs),
    ("f32x4_sqrt", f32x4_sqrt),
    ("f64x2_sqrt", f64x2_sqrt),
    ("f32x4_ceil", f32x4_ceil),
    ("f64x2_ceil", f64x2_ceil),
    ("f32x4_floor", f32x4_floor),
    ("f64x2_floor", f64x2_floor),
    ("f32x4_trunc", f32x4_trunc),
    ("f64x2_trunc", f64x2_trunc),
    ("f32x4_nearest", f32x4_nearest),
    ("f64x2_nearest", f64x2_nearest),
    ("f32x4_convert_i32x4_s", f32x4_convert_i32x4_s),
    ("f32x4_convert_i32x4_u", f32x4_convert_i32x4_u),
    ("i32x4_trunc_sat_f32x4_s", i32x4_trunc_sat_f32x4_s),
    ("i32x4_trunc_sat_f32x4_u", i32x4_trunc_sat_f32x4_u),
    ("i16x8_extend_low_i8x16_s", i16x8_extend_low_i8x16_s),
    ("i16x8_extend_low_i8x16_u", i16x8_extend_low_i8x16_u),
    ("i32x4_extend_low_i16x8_s", i32x4_extend_low_i16x8_s),
    ("i32x4_extend_low_i16x8_u", i32x4_extend_low_i16x8_u),
    ("i64x2_extend_low_i32x4_s", i64x2_extend_low_i32x4_s),
    ("i64x2_extend_low_i32x4_u", i64x2_extend_low_i32x4_u),
    ("f64x2_convert_low_i32x4_s", f64x2_convert_low_i32x4_s),
    ("f64x2_convert_low_i32x4_u", f64x2_convert_low_i32x4_u),
    ("f64x2_promote_low_f32x4", f64x2_promote_low_f32x4),
    ("i16x8_extend_high_i8x16_s", i16x8_extend_high_i8x16_s),
    ("i16x8_extend_high_i8x16_u", i16x8_extend_high_i8x16_u),
    ("i32x4_extend_high_i16x8_s", i32x4_extend_high_i16x8_s),
    ("i32x4_extend_high_i16x8_u", i32x4_extend_high_i16x8_u),
    ("i64x2_extend_high_i32x4_s", i64x2_extend_high_i32x4_s),
    ("i64x2_extend_high_i32x4_u", i64x2_extend_high_i32x4_u),
    ("i16x8_extadd_pairwise_i8x16_s", i16x8_extadd_pairwise_i8x16_s),
    ("i16x8_extadd_pairwise_i8x16_u", i16x8_extadd_pairwise_i8x16_u),
    ("i32x4_extadd_pairwise_i16x8_s", i32x4_extadd_pairwise_i16x8_s),
    ("i32x4_extadd_pairwise_i16x8_u", i32x4_extadd_pairwise_i16x8_u),
    ("i32x4_trunc_sat_f64x2_s_zero", i32x4_trunc_sat_f64x2_s_zero),
    ("i32x4_trunc_sat_f64x2_u_zero", i32x4_trunc_sat_f64x2_u_zero),
    ("f32x4_demote_f64x2_zero", f32x4_demote_f64x2_zero),
    ("i32x4_relaxed_trunc_f32x4_s", i32x4_relaxed_trunc_f32x4_s),
    ("i32x4_relaxed_trunc_f32x4_u", i32x4_relaxed_trunc_f32x4_u),
    ("i32x4_relaxed_trunc_f64x2_s_zero", i32x4_relaxed_trunc_f64x2_s_zero),
    ("i32x4_relaxed_trunc_f64x2_u_zero", i32x4_relaxed_trunc_f64x2_u_zero),
  ]
  for p in unary {
    ops[p.0] = v_v(p.1)
  }
  let to_bool : Array[(String, (V128Value) -> Bool)] = [
    ("i8x16_all_true", i8x16_all_true),
    ("i16x8_all_true", i16x8_all_true),
    ("i32x4_all_true", i32x4_all_true),
    ("i64x2_all_true", i64x2_all_true),
    ("v128_any_true", v128_any_true),
  ]
  for p in to_bool {
    let f = p.1
    ops[p.0] = a => hb(f(a_v128(a[0])))
  }
  let to_u32 : Array[(String, (V128Value) -> UInt)] = [
    ("i8x16_bitmask", i8x16_bitmask),
    ("i16x8_bitmask", i16x8_bitmask),
    ("i32x4_bitmask", i32x4_bitmask),
    ("i64x2_bitmask", i64x2_bitmask),
  ]
  for p in to_u32 {
    let f = p.1
    ops[p.0] = a => h32(f(a_v128(a[0])))
  }
  let binary : Array[(String, (V128Value, V128Value) -> V128Value)] = [
    ("i8x16_swizzle", i8x16_swizzle),
    ("i8x16_relaxed_swizzle", i8x16_relaxed_swizzle),
    ("i64x2_add", i64x2_add),
    ("i32x4_add", i32x4_add),
    ("i16x8_add", i16x8_add),
    ("i8x16_add", i8x16_add),
    ("i64x2_sub", i64x2_sub),
    ("i32x4_sub", i32x4_sub),
    ("i16x8_sub", i16x8_sub),
    ("i8x16_sub", i8x16_sub),
    ("i64x2_mul", i64x2_mul),
    ("i32x4_mul", i32x4_mul),
    ("i16x8_mul", i16x8_mul),
    ("i8x16_mul", i8x16_mul),
    ("i8x16_add_sat_s", i8x16_add_sat_s),
    ("i8x16_add_sat_u", i8x16_add_sat_u),
    ("i16x8_add_sat_s", i16x8_add_sat_s),
    ("i16x8_add_sat_u", i16x8_add_sat_u),
    ("i8x16_sub_sat_s", i8x16_sub_sat_s),
    ("i8x16_sub_sat_u", i8x16_sub_sat_u),
    ("i16x8_sub_sat_s", i16x8_sub_sat_s),
    ("i16x8_sub_sat_u", i16x8_sub_sat_u),
    ("i16x8_q15mulr_sat_s", i16x8_q15mulr_sat_s),
    ("i16x8_relaxed_q15mulr_s", i16x8_relaxed_q15mulr_s),
    ("i8x16_min_s", i8x16_min_s),
    ("i8x16_min_u", i8x16_min_u),
    ("i16x8_min_s", i16x8_min_s),
    ("i16x8_min_u", i16x8_min_u),
    ("i32x4_min_s", i32x4_min_s),
    ("i32x4_min_u", i32x4_min_u),
    ("i8x16_max_s", i8x16_max_s),
    ("i8x16_max_u", i8x16_max_u),
    ("i16x8_max_s", i16x8_max_s),
    ("i16x8_max_u", i16x8_max_u),
    ("i32x4_max_s", i32x4_max_s),
    ("i32x4_max_u", i32x4_max_u),
    ("i8x16_avgr_u", i8x16_avgr_u),
    ("i16x8_avgr_u", i16x8_avgr_u),
    ("v128_and", v128_and),
    ("v128_or", v128_or),
    ("v128_xor", v128_xor),
    ("v128_andnot", v128_andnot),
    ("f32x4_min", f32x4_min),
    ("f64x2_min", f64x2_min),
    ("f32x4_max", f32x4_max),
    ("f64x2_max", f64x2_max),
    ("f32x4_relaxed_min", f32x4_relaxed_min),
    ("f32x4_relaxed_max", f32x4_relaxed_max),
    ("f64x2_relaxed_min", f64x2_relaxed_min),
    ("f64x2_relaxed_max", f64x2_relaxed_max),
    ("f32x4_pmin", f32x4_pmin),
    ("f64x2_pmin", f64x2_pmin),
    ("f32x4_pmax", f32x4_pmax),
    ("f64x2_pmax", f64x2_pmax),
    ("f32x4_add", f32x4_add),
    ("f64x2_add", f64x2_add),
    ("f32x4_sub", f32x4_sub),
    ("f64x2_sub", f64x2_sub),
    ("f32x4_div", f32x4_div),
    ("f64x2_div", f64x2_div),
    ("f32x4_mul", f32x4_mul),
    ("f64x2_mul", f64x2_mul),
    ("i8x16_eq", i8x16_eq),
    ("i16x8_eq", i16x8_eq),
    ("i32x4_eq", i32x4_eq),
    ("i64x2_eq", i64x2_eq),
    ("f32x4_eq", f32x4_eq),
    ("f64x2_eq", f64x2_eq),
    ("i8x16_ne", i8x16_ne),
    ("i16x8_ne", i16x8_ne),
    ("i32x4_ne", i32x4_ne),
    ("i64x2_ne", i64x2_ne),
    ("f32x4_ne", f32x4_ne),
    ("f64x2_ne", f64x2_ne),
    ("i8x16_lt_s", i8x16_lt_s),
    ("i8x16_lt_u", i8x16_lt_u),
    ("i16x8_lt_s", i16x8_lt_s),
    ("i16x8_lt_u", i16x8_lt_u),
    ("i32x4_lt_s", i32x4_lt_s),
    ("i32x4_lt_u", i32x4_lt_u),
    ("i64x2_lt_s", i64x2_lt_s),
    ("f32x4_lt", f32x4_lt),
    ("f64x2_lt", f64x2_lt),
    ("i8x16_le_s", i8x16_le_s),
    ("i8x16_le_u", i8x16_le_u),
    ("i16x8_le_s", i16x8_le_s),
    ("i16x8_le_u", i16x8_le_u),
    ("i32x4_le_s", i32x4_le_s),
    ("i32x4_le_u", i32x4_le_u),
    ("i64x2_le_s", i64x2_le_s),
    ("f32x4_le", f32x4_le),
    ("f64x2_le", f64x2_le),
    ("i8x16_gt_s", i8x16_gt_s),
    ("i8x16_gt_u", i8x16_gt_u),
    ("i16x8_gt_s", i16x8_gt_s),
    ("i16x8_gt_u", i16x8_gt_u),
    ("i32x4_gt_s", i32x4_gt_s),
    ("i32x4_gt_u", i32x4_gt_u),
    ("i64x2_gt_s", i64x2_gt_s),
    ("f32x4_gt", f32x4_gt),
    ("f64x2_gt", f64x2_gt),
    ("i8x16_ge_s", i8x16_ge_s),
    ("i8x16_ge_u", i8x16_ge_u),
    ("i16x8_ge_s", i16x8_ge_s),
    ("i16x8_ge_u", i16x8_ge_u),
    ("i32x4_ge_s", i32x4_ge_s),
    ("i32x4_ge_u", i32x4_ge_u),
    ("i64x2_ge_s", i64x2_ge_s),
    ("f32x4_ge", f32x4_ge),
    ("f64x2_ge", f64x2_ge),
    ("i16x8_extmul_low_i8x16_s", i16x8_extmul_low_i8x16_s),
    ("i16x8_extmul_low_i8x16_u", i16x8_extmul_low_i8x16_u),
    ("i32x4_extmul_low_i16x8_s", i32x4_extmul_low_i16x8_s),
    ("i32x4_extmul_low_i16x8_u", i32x4_extmul_low_i16x8_u),
    ("i64x2_extmul_low_i32x4_s", i64x2_extmul_low_i32x4_s),
    ("i64x2_extmul_low_i32x4_u", i64x2_extmul_low_i32x4_u),
    ("i16x8_extmul_high_i8x16_s", i16x8_extmul_high_i8x16_s),
    ("i16x8_extmul_high_i8x16_u", i16x8_extmul_high_i8x16_u),
    ("i32x4_extmul_high_i16x8_s", i32x4_extmul_high_i16x8_s),
    ("i32x4_extmul_high_i16x8_u", i32x4_extmul_high_i16x8_u),
    ("i64x2_extmul_high_i32x4_s", i64x2_extmul_high_i32x4_s),
    ("i64x2_extmul_high_i32x4_u", i64x2_extmul_high_i32x4_u),
    ("i8x16_narrow_i16x8_s", i8x16_narrow_i16x8_s),
    ("i8x16_narrow_i16x8_u", i8x16_narrow_i16x8_u),
    ("i16x8_narrow_i32x4_s", i16x8_narrow_i32x4_s),
    ("i16x8_narrow_i32x4_u", i16x8_narrow_i32x4_u),
    ("i32x4_dot_i16x8_s", i32x4_dot_i16x8_s),
    ("i16x8_relaxed_dot_i8x16_i7x16_s", i16x8_relaxed_dot_i8x16_i7x16_s),
  ]
  for p in binary {
    ops[p.0] = vv_v(p.1)
  }
  let ternary : Array[(String, (V128Value, V128Value, V128Value) -> V128Value)] = [
    ("v128_bitselect", v128_bitselect),
    ("i8x16_relaxed_laneselect", i8x16_relaxed_laneselect),
    ("i16x8_relaxed_laneselect", i16x8_relaxed_laneselect),
    ("i32x4_relaxed_laneselect", i32x4_relaxed_laneselect),
    ("i64x2_relaxed_laneselect", i64x2_relaxed_laneselect),
    ("i32x4_relaxed_dot_i8x16_i7x16_add_s", i32x4_relaxed_dot_i8x16_i7x16_add_s),
    ("f32x4_relaxed_madd", f32x4_relaxed_madd),
    ("f32x4_relaxed_nmadd", f32x4_relaxed_nmadd),
    ("f64x2_relaxed_madd", f64x2_relaxed_madd),
    ("f64x2_relaxed_nmadd", f64x2_relaxed_nmadd),
  ]
  for p in ternary {
    ops[p.0] = vvv_v(p.1)
  }
  let shifts : Array[(String, (V128Value, UInt) -> V128Value)] = [
    ("i8x16_shl", i8x16_shl),
    ("i16x8_shl", i16x8_shl),
    ("i32x4_shl", i32x4_shl),
    ("i64x2_shl", i64x2_shl),
    ("i8x16_shr_s", i8x16_shr_s),
    ("i8x16_shr_u", i8x16_shr_u),
    ("i16x8_shr_s", i16x8_shr_s),
    ("i16x8_shr_u", i16x8_shr_u),
    ("i32x4_shr_s", i32x4_shr_s),
    ("i32x4_shr_u", i32x4_shr_u),
    ("i64x2_shr_s", i64x2_shr_s),
    ("i64x2_shr_u", i64x2_shr_u),
  ]
  for p in shifts {
    ops[p.0] = vu_v(p.1)
  }
  ops["i64x2_splat"] = a => hv(i64x2_splat(a_i64(a[0])))
  ops["i32x4_splat"] = a => hv(i32x4_splat(a_i32(a[0])))
  ops["i16x8_splat"] = a => hv(i16x8_splat(a_i32(a[0])))
  ops["i8x16_splat"] = a => hv(i8x16_splat(a_i32(a[0])))
  ops["f32x4_splat"] = a => hv(f32x4_splat(a_f32(a[0])))
  ops["f64x2_splat"] = a => hv(f64x2_splat(a_f64(a[0])))
  ops["i8x16_extract_lane_s"] = a => {
    h32i(i8x16_extract_lane_s(a_v128(a[0]), lane16(a[1])))
  }
  ops["i8x16_extract_lane_u"] = a => {
    h32(i8x16_extract_lane_u(a_v128(a[0]), lane16(a[1])))
  }
  ops["i8x16_replace_lane"] = a => {
    hv(i8x16_replace_lane(a_v128(a[0]), lane16(a[1]), a_i32(a[2])))
  }
  ops["i16x8_extract_lane_s"] = a => {
    h32i(i16x8_extract_lane_s(a_v128(a[0]), lane8(a[1])))
  }
  ops["i16x8_extract_lane_u"] = a => {
    h32(i16x8_extract_lane_u(a_v128(a[0]), lane8(a[1])))
  }
  ops["i16x8_replace_lane"] = a => {
    hv(i16x8_replace_lane(a_v128(a[0]), lane8(a[1]), a_i32(a[2])))
  }
  ops["i32x4_extract_lane"] = a => {
    h32i(i32x4_extract_lane(a_v128(a[0]), lane4(a[1])))
  }
  ops["f32x4_extract_lane"] = a => {
    hf32(f32x4_extract_lane(a_v128(a[0]), lane4(a[1])))
  }
  ops["i32x4_replace_lane"] = a => {
    hv(i32x4_replace_lane(a_v128(a[0]), lane4(a[1]), a_i32(a[2])))
  }
  ops["f32x4_replace_lane"] = a => {
    hv(f32x4_replace_lane(a_v128(a[0]), lane4(a[1]), a_f32(a[2])))
  }
  ops["i64x2_extract_lane"] = a => {
    h64i(i64x2_extract_lane(a_v128(a[0]), lane2(a[1])))
  }
  ops["f64x2_extract_lane"] = a => {
    hf64(f64x2_extract_lane(a_v128(a[0]), lane2(a[1])))
  }
  ops["i64x2_replace_lane"] = a => {
    hv(i64x2_replace_lane(a_v128(a[0]), lane2(a[1]), a_i64(a[2])))
  }
  ops["f64x2_replace_lane"] = a => {
    hv(f64x2_replace_lane(a_v128(a[0]), lane2(a[1]), a_f64(a[2])))
  }
  ops["i8x16_shuffle"] = a => {
    let sel = FixedArray::makei(16, i => {
      let b = parse_hex(a[2].view(start_offset=2 * i, end_offset=2 * i + 2))
      ImmLaneIdx32::try_from(b.to_byte()) catch {
        _ => abort("bad lane")
      }
    })
    hv(i8x16_shuffle(a_v128(a[0]), a_v128(a[1]), sel))
  }
  ops["lane_idx"] = a => {
    let lane = a_u32(a[1]).to_byte()
    let ok = try {
      match a[0] {
        "2" => ImmLaneIdx2::try_from(lane) |> ignore
        "4" => ImmLaneIdx4::try_from(lane) |> ignore
        "8" => ImmLaneIdx8::try_from(lane) |> ignore
        "16" => ImmLaneIdx16::try_from(lane) |> ignore
        _ => ImmLaneIdx32::try_from(lane) |> ignore
      }
      true
    } catch {
      _ => false
    }
    hb(ok)
  }
}

///|
fn oracle_memory_ops(ops : Map[String, OracleFn]) -> Unit {
  ops["i32_load8_s"] = load((m, l, p, o) => h32i(i32_load8_s(m, l, p, o)))
  ops["i32_load8_s_at"] = load_at((m, l, a) => h32i(i32_load8_s_at(m, l, a)))
  ops["i32_load8_u"] = load((m, l, p, o) => h32i(i32_load8_u(m, l, p, o)))
  ops["i32_load8_u_at"] = load_at((m, l, a) => h32i(i32_load8_u_at(m, l, a)))
  ops["i32_load16_s"] = load((m, l, p, o) => h32i(i32_load16_s(m, l, p, o)))
  ops["i32_load16_s_at"] = load_at((m, l, a) => h32i(i32_load16_s_at(m, l, a)))
  ops["i32_load16_u"] = load((m, l, p, o) => h32i(i32_load16_u(m, l, p, o)))
  ops["i32_load16_u_at"] = load_at((m, l, a) => h32i(i32_load16_u_at(m, l, a)))
  ops["i64_load8_s"] = load((m, l, p, o) => h64i(i64_load8_s(m, l, p, o)))
  ops["i64_load8_s_at"] = load_at((m, l, a) => h64i(i64_load8_s_at(m, l, a)))
  ops["i64_load8_u"] = load((m, l, p, o) => h64i(i64_load8_u(m, l, p, o)))
  ops["i64_load8_u_at"] = load_at((m, l, a) => h64i(i64_load8_u_at(m, l, a)))
  ops["i64_load16_s"] = load((m, l, p, o) => h64i(i64_load16_s(m, l, p, o)))
  ops["i64_load16_s_at"] = load_at((m, l, a) => h64i(i64_load16_s_at(m, l, a)))
  ops["i64_load16_u"] = load((m, l, p, o) => h64i(i64_load16_u(m, l, p, o)))
  ops["i64_load16_u_at"] = load_at((m, l, a) => h64i(i64_load16_u_at(m, l, a)))
  ops["i64_load32_s"] = load((m, l, p, o) => h64i(i64_load32_s(m, l, p, o)))
  ops["i64_load32_s_at"] = load_at((m, l, a) => h64i(i64_load32_s_at(m, l, a)))
  ops["i64_load32_u"] = load((m, l, p, o) => h64i(i64_load32_u(m, l, p, o)))
  ops["i64_load32_u_at"] = load_at((m, l, a) => h64i(i64_load32_u_at(m, l, a)))
  ops["load32"] = load((m, l, p, o) => h32(load32(m, l, p, o)))
  ops["load32_at"] = load_at((m, l, a) => h32(load32_at(m, l, a)))
  ops["load64"] = load((m, l, p, o) => h64(load64(m, l, p, o)))
  ops["load64_at"] = load_at((m, l, a) => h64(load64_at(m, l, a)))
  let simd_loads : Array[
    (
      String,
      (FixedArray[Byte], Int, UInt64, UInt64) -> V128Value raise TrapCode,
      (FixedArray[Byte], Int, UInt64) -> V128Value raise TrapCode,
    ),
  ] = [
    ("v128_load", v128_load, v128_load_at),
    ("v128_load32_zero", v128_load32_zero, v128_load32_zero_at),
    ("v128_load64_zero", v128_load64_zero, v128_load64_zero_at),
    ("v128_load8_splat", v128_load8_splat, v128_load8_splat_at),
    ("v128_load16_splat", v128_load16_splat, v128_load16_splat_at),
    ("v128_load32_splat", v128_load32_splat, v128_load32_splat_at),
    ("v128_load64_splat", v128_load64_splat, v128_load64_splat_at),
    ("v128_load8x8_s", v128_load8x8_s, v128_load8x8_s_at),
    ("v128_load8x8_u", v128_load8x8_u, v128_load8x8_u_at),
    ("v128_load16x4_s", v128_load16x4_s, v128_load16x4_s_at),
    ("v128_load16x4_u", v128_load16x4_u, v128_load16x4_u_at),
    ("v128_load32x2_s", v128_load32x2_s, v128_load32x2_s_at),
    ("v128_load32x2_u", v128_load32x2_u, v128_load32x2_u_at),
  ]
  for p in simd_loads {
    let (name, f, f_at) = p
    ops[name] = load((m, l, ptr, o) => hv(f(m, l, ptr, o)))
    ops[name + "_at"] = load_at((m, l, a) => hv(f_at(m, l, a)))
  }
  ops["v128_load8_lane"] = a => {
    hv(
      v128_load8_lane(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_u64(a[1]),
        a_v128(a[2]),
        lane16(a[3]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load8_lane_at"] = a => {
    hv(
      v128_load8_lane_at(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_v128(a[1]),
        lane16(a[2]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load16_lane"] = a => {
    hv(
      v128_load16_lane(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_u64(a[1]),
        a_v128(a[2]),
        lane8(a[3]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load16_lane_at"] = a => {
    hv(
      v128_load16_lane_at(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_v128(a[1]),
        lane8(a[2]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load32_lane"] = a => {
    hv(
      v128_load32_lane(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_u64(a[1]),
        a_v128(a[2]),
        lane4(a[3]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load32_lane_at"] = a => {
    hv(
      v128_load32_lane_at(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_v128(a[1]),
        lane4(a[2]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load64_lane"] = a => {
    hv(
      v128_load64_lane(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_u64(a[1]),
        a_v128(a[2]),
        lane2(a[3]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["v128_load64_lane_at"] = a => {
    hv(
      v128_load64_lane_at(
        mem_init(),
        mem_len,
        a_u64(a[0]),
        a_v128(a[1]),
        lane2(a[2]),
      ),
    ) catch {
      t => trap_str(t)
    }
  }
  ops["i32_store8"] = store((m, l, p, o, v) => i32_store8(m, l, p, o, a_i32(v)))
  ops["i32_store8_at"] = store_at((m, l, a, v) => {
    i32_store8_at(m, l, a, a_i32(v))
  })
  ops["i32_store16"] = store((m, l, p, o, v) => {
    i32_store16(m, l, p, o, a_i32(v))
  })
  ops["i32_store16_at"] = store_at((m, l, a, v) => {
    i32_store16_at(m, l, a, a_i32(v))
  })
  ops["i64_store8"] = store((m, l, p, o, v) => i64_store8(m, l, p, o, a_i64(v)))
  ops["i64_store8_at"] = store_at((m, l, a, v) => {
    i64_store8_at(m, l, a, a_i64(v))
  })
  ops["i64_store16"] = store((m, l, p, o, v) => {
    i64_store16(m, l, p, o, a_i64(v))
  })
  ops["i64_store16_at"] = store_at((m, l, a, v) => {
    i64_store16_at(m, l, a, a_i64(v))
  })
  ops["i64_store32"] = store((m, l, p, o, v) => {
    i64_store32(m, l, p, o, a_i64(v))
  })
  ops["i64_store32_at"] = store_at((m, l, a, v) => {
    i64_store32_at(m, l, a, a_i64(v))
  })
  ops["store32"] = store((m, l, p, o, v) => store32(m, l, p, o, a_u32(v)))
  ops["store32_at"] = store_at((m, l, a, v) => store32_at(m, l, a, a_u32(v)))
  ops["store64"] = store((m, l, p, o, v) => store64(m, l, p, o, a_u64(v)))
  ops["store64_at"] = store_at((m, l, a, v) => store64_at(m, l, a, a_u64(v)))
  ops["v128_store"] = store((m, l, p, o, v) => v128_store(m, l, p, o, a_v128(v)))
  ops["v128_store_at"] = store_at((m, l, a, v) => {
    v128_store_at(m, l, a, a_v128(v))
  })
  let lane_store = (
    f : (FixedArray[Byte], Int, UInt64, UInt64, V128Value, String) -> Unit raise TrapCode,
  ) => {
    (a : Array[String]) => {
      let m = mem_init()
      f(m, mem_len, a_u64(a[0]), a_u64(a[1]), a_v128(a[2]), a[3]) catch {
        t => return trap_str(t) + ":" + hmem(m, mem_len)
      }
      hmem(m, mem_len)
    }
  }
  let lane_store_at = (
    f : (FixedArray[Byte], Int, UInt64, V128Value, String) -> Unit raise TrapCode,
  ) => {
    (a : Array[String]) => {
      let m = mem_init()
      f(m, mem_len, a_u64(a[0]), a_v128(a[1]), a[2]) catch {
        t => return trap_str(t) + ":" + hmem(m, mem_len)
      }
      hmem(m, mem_len)
    }
  }
  ops["v128_store8_lane"] = lane_store((m, l, p, o, v, i) => {
    v128_store8_lane(m, l, p, o, v, lane16(i))
  })
  ops["v128_store8_lane_at"] = lane_store_at((m, l, a, v, i) => {
    v128_store8_lane_at(m, l, a, v, lane16(i))
  })
  ops["v128_store16_lane"] = lane_store((m, l, p, o, v, i) => {
    v128_store16_lane(m, l, p, o, v, lane8(i))
  })
  ops["v128_store16_lane_at"] = lane_store_at((m, l, a, v, i) => {
    v128_store16_lane_at(m, l, a, v, lane8(i))
  })
  ops["v128_store32_lane"] = lane_store((m, l, p, o, v, i) => {
    v128_store32_lane(m, l, p, o, v, lane4(i))
  })
  ops["v128_store32_lane_at"] = lane_store_at((m, l, a, v, i) => {
    v128_store32_lane_at(m, l, a, v, lane4(i))
  })
  ops["v128_store64_lane"] = lane_store((m, l, p, o, v, i) => {
    v128_store64_lane(m, l, p, o, v, lane2(i))
  })
  ops["v128_store64_lane_at"] = lane_store_at((m, l, a, v, i) => {
    v128_store64_lane_at(m, l, a, v, lane2(i))
  })
}

// Scenarios.

///|
fn opt_str(v : UInt64?) -> String {
  match v {
    Some(v) => v.to_string()
    None => "-"
  }
}

///|
fn parse_opt(s : String) -> UInt64? {
  if s == "-" {
    None
  } else {
    Some(parse_dec(s))
  }
}

///|
fn parse_dec(s : StringView) -> UInt64 {
  let mut v = 0UL
  for c in s {
    v = v * 10 + (c.to_int() - '0'.to_int()).to_uint64()
  }
  v
}

///|
priv struct TestLimiter {
  limit : UInt64
  error : Bool
  log : Array[String]
}

///|
impl ResourceLimiter for TestLimiter with fn memory_growing(
  self,
  current,
  desired,
  maximum,
) {
  self.log.push("mg(\{current},\{desired},\{opt_str(maximum)})")
  if desired <= self.limit {
    true
  } else if self.error {
    raise LimiterError::ResourceLimiterDeniedAllocation
  } else {
    false
  }
}

///|
impl ResourceLimiter for TestLimiter with fn table_growing(
  self,
  current,
  desired,
  maximum,
) {
  self.log.push("tg(\{current},\{desired},\{opt_str(maximum)})")
  if desired <= self.limit {
    true
  } else if self.error {
    raise LimiterError::OutOfBoundsGrowth
  } else {
    false
  }
}

///|
impl ResourceLimiter for TestLimiter with fn memory_grow_failed(self, error) {
  self.log.push("mgf(\{error})")
}

///|
impl ResourceLimiter for TestLimiter with fn table_grow_failed(self, error) {
  self.log.push("tgf(\{error})")
}

///|
impl ResourceLimiter for TestLimiter with fn instances(_self) {
  1
}

///|
impl ResourceLimiter for TestLimiter with fn tables(_self) {
  1
}

///|
impl ResourceLimiter for TestLimiter with fn memories(_self) {
  1
}

///|
fn limiter_of(spec : String) -> TestLimiter? {
  guard spec.split(":").collect() is [limit, mode] else { return None }
  Some({ limit: parse_dec(limit), error: mode == "err", log: [], })
}

///|
fn limiter_ref(lim : TestLimiter?) -> ResourceLimiterRef {
  match lim {
    Some(l) => ResourceLimiterRef::from_limiter(l)
    None => ResourceLimiterRef::default()
  }
}

///|
fn drain(lim : TestLimiter?, t : Array[String]) -> Unit {
  if lim is Some(l) {
    t.append(l.log)
    l.log.clear()
  }
}

///|
fn run_memory(a : Array[String]) -> String {
  let t : Array[String] = []
  let b = MemoryType::builder()
  b.min(parse_dec(a[0])) |> ignore
  b.max(parse_opt(a[1])) |> ignore
  b.page_size_log2(parse_dec(a[2]).to_byte()) |> ignore
  b.memory64(a[3] == "1") |> ignore
  let ty = b.build() catch { e => return "ty!\{e}" }
  t.push(
    "ty(\{ty.minimum()},\{opt_str(ty.maximum())},\{ty.page_size()},\{hb(ty.is_64())})",
  )
  let lim = limiter_of(a[4])
  let mem = Memory::new(ty, limiter_ref(lim)) catch {
    e => {
      drain(lim, t)
      t.push("new!\{e}")
      return t.join(";")
    }
  }
  drain(lim, t)
  t.push("new=\{mem.size()}")
  let ops = if a[5] == "" { [] } else { a[5].split(",").collect() }
  for op in ops {
    let p = op.split(":").map(s => s.to_owned()).collect()
    let res = match p[0] {
      "g" =>
        try mem.grow(parse_dec(p[1]), None, limiter_ref(lim)) catch {
          e => "g!\{e}"
        } noraise {
          old => "g=\{old}"
        }
      "gf" => {
        let fuel = Fuel::new(true, FuelCostsProvider::default())
        fuel.set_fuel(parse_dec(p[2])) catch {
          _ => abort("set_fuel")
        }
        try mem.grow(parse_dec(p[1]), Some(fuel), limiter_ref(lim)) catch {
          e => "g!\{e}"
        } noraise {
          old => "g=\{old},fuel=\{try! fuel.get_fuel()}"
        }
      }
      "r" => {
        let buf = FixedArray::make(parse_dec(p[2]).to_int(), (0 : Byte))
        try mem.read(parse_dec(p[1]), buf) catch {
          e => "r!\{e}"
        } noraise {
          _ => "r=\{hmem(buf, buf.length())}"
        }
      }
      "w" => {
        let len = parse_dec(p[2]).to_int()
        let buf = Bytes::makei(len, i => (i * 13 + 5).to_byte())
        try mem.write(parse_dec(p[1]), buf[:]) catch {
          e => "w!\{e}"
        } noraise {
          _ => "w"
        }
      }
      _ => abort("unknown memory op")
    }
    drain(lim, t)
    t.push(res)
    t.push("sz=\{mem.size()},\{mem.data_size()}")
  }
  let dt = mem.dynamic_ty()
  t.push("dyn(\{dt.minimum()},\{opt_str(dt.maximum())})")
  t.join(";")
}

///|
fn val_type(s : StringView) -> ValType {
  match s {
    "i32" => I32
    "i64" => I64
    "f32" => F32
    "f64" => F64
    "v128" => V128
    "func" => FuncRef
    _ => ExternRef
  }
}

///|
fn typed_val(s : StringView) -> TypedVal {
  guard s.split("=").collect() is [ty, v] else { abort("bad typed value") }
  TypedVal::new(val_type(ty), UntypedVal::from_u64(parse_dec(v)))
}

///|
fn table_dump(table : Table) -> String {
  let parts = []
  for i in 0UL..<table.size() {
    parts.push(table.get_untyped(i).unwrap().to_bits64().to_string())
  }
  parts.join(" ")
}

///|
fn run_table(a : Array[String]) -> String {
  let t : Array[String] = []
  let min = parse_dec(a[0])
  let max = parse_opt(a[1])
  let ty = if a[2] == "1" {
    TableType::new64(FuncRef, min, max)
  } else {
    TableType::new(FuncRef, min.to_uint(), max.map(UInt64::to_uint))
  }
  let lim = limiter_of(a[3])
  let table = Table::new(ty, typed_val(a[4]), limiter_ref(lim)) catch {
    e => {
      drain(lim, t)
      t.push("new!\{e}")
      return t.join(";")
    }
  }
  drain(lim, t)
  t.push("new=\{table.size()}")
  let segment = ElementSegment::new(FuncRef, [
    UntypedVal::from_u64(100),
    UntypedVal::from_u64(101),
    UntypedVal::from_u64(102),
    UntypedVal::from_u64(103),
    UntypedVal::from_u64(104),
  ])
  let extern_segment = ElementSegment::new(ExternRef, [UntypedVal::from_u64(9)])
  let other = try! Table::new(
    TableType::new(FuncRef, 4, None),
    typed_val("func=50"),
    ResourceLimiterRef::default(),
  )
  for i, v in [50UL, 51, 52, 53] {
    try! other.set_untyped(i.to_uint64(), UntypedVal::from_u64(v))
  }
  let ops = if a[5] == "" { [] } else { a[5].split(",").collect() }
  for op in ops {
    let p = op.split(":").map(s => s.to_owned()).collect()
    let num = (i : Int) => parse_dec(p[i])
    let res = match p[0] {
      "g" =>
        try table.grow(num(1), typed_val(p[2]), None, limiter_ref(lim)) catch {
          e => "g!\{e}"
        } noraise {
          old => "g=\{old}"
        }
      "gf" => {
        let fuel = Fuel::new(true, FuelCostsProvider::default())
        try! fuel.set_fuel(num(2))
        try
          table.grow_untyped(
            num(1),
            UntypedVal::from_u64(77),
            Some(fuel),
            limiter_ref(lim),
          )
        catch {
          e => "g!\{e}"
        } noraise {
          old => "g=\{old},fuel=\{try! fuel.get_fuel()}"
        }
      }
      "s" =>
        try table.set(num(1), typed_val(p[2])) catch {
          e => "s!\{e}"
        } noraise {
          _ => "s"
        }
      "G" =>
        match table.get(num(1)) {
          Some(v) => "G=\{v.ty()},\{v.untyped().to_bits64()}"
          None => "G=-"
        }
      "f" =>
        try table.fill(num(1), typed_val(p[2]), num(3), None) catch {
          e => "f!\{e}"
        } noraise {
          _ => "f"
        }
      "c" =>
        try table.copy_within(num(1), num(2), num(3), None) catch {
          e => "c!\{e}"
        } noraise {
          _ => "c"
        }
      "C" =>
        try Table::copy(table, num(1), other, num(2), num(3), None) catch {
          e => "C!\{e}"
        } noraise {
          _ => "C"
        }
      "i" =>
        try
          table.init(
            segment.as_ref(),
            num(1),
            num(2).to_uint(),
            num(3).to_uint(),
            None,
          )
        catch {
          e => "i!\{e}"
        } noraise {
          _ => "i"
        }
      "ie" =>
        try table.init(extern_segment.as_ref(), num(1), 0, 1, None) catch {
          e => "i!\{e}"
        } noraise {
          _ => "i"
        }
      "if" => {
        let fuel = Fuel::new(true, FuelCostsProvider::default())
        try! fuel.set_fuel(num(4))
        try
          table.init(
            segment.as_ref(),
            num(1),
            num(2).to_uint(),
            num(3).to_uint(),
            Some(fuel),
          )
        catch {
          e => "i!\{e}"
        } noraise {
          _ => "i,fuel=\{try! fuel.get_fuel()}"
        }
      }
      _ => abort("unknown table op")
    }
    drain(lim, t)
    t.push(res)
    t.push("[\{table_dump(table)}]")
  }
  let dt = table.dynamic_ty()
  t.push("dyn(\{dt.minimum()},\{opt_str(dt.maximum())})")
  t.join(";")
}

///|
fn oracle_scenario_ops(ops : Map[String, OracleFn]) -> Unit {
  ops["memory_type"] = a => {
    let b = MemoryType::builder()
    b.min(parse_dec(a[0])) |> ignore
    b.max(parse_opt(a[1])) |> ignore
    b.page_size_log2(parse_dec(a[2]).to_byte()) |> ignore
    b.memory64(a[3] == "1") |> ignore
    try b.build() catch {
      e => "err(\{e})"
    } noraise {
      ty => "ok(\{ty.minimum()},\{opt_str(ty.maximum())},\{ty.page_size()})"
    }
  }
  let mem_ty = (a : ArrayView[String]) => {
    let b = MemoryType::builder()
    b.min(parse_dec(a[0])) |> ignore
    b.max(parse_opt(a[1])) |> ignore
    b.page_size_log2(parse_dec(a[2]).to_byte()) |> ignore
    b.memory64(a[3] == "1") |> ignore
    try! b.build()
  }
  ops["memory_subtype"] = a => hb(mem_ty(a[0:4]).is_subtype_of(mem_ty(a[4:8])))
  ops["memory"] = run_memory
  ops["table"] = run_table
  let table_ty = (a : ArrayView[String]) => {
    let min = parse_dec(a[1])
    let max = parse_opt(a[2])
    if a[3] == "1" {
      TableType::new64(val_type(a[0]), min, max)
    } else {
      TableType::new(val_type(a[0]), min.to_uint(), max.map(UInt64::to_uint))
    }
  }
  ops["table_subtype"] = a => {
    hb(table_ty(a[0:4]).is_subtype_of(table_ty(a[4:8])))
  }
}

///|
fn oracle_display_ops(ops : Map[String, OracleFn]) -> Unit {
  ops["trap_code"] = a => {
    let code = parse_dec(a[0]).to_byte()
    try TrapCode::try_from_u8(code) catch {
      _ => "invalid"
    } noraise {
      t => "\{t}|\{Trap::from_trap_code(t)}"
    }
  }
  ops["trap_message"] = _ => Trap::new("custom message").to_string()
  ops["trap_exit"] = a => Trap::i32_exit(parse_dec(a[0]).to_int()).to_string()
  let memory_errors : Array[MemoryError] = [
    OutOfSystemMemory,
    OutOfBoundsGrowth,
    OutOfBoundsAccess,
    InvalidMemoryType,
    InvalidStaticBufferSize,
    ResourceLimiterDeniedAllocation,
    MinimumSizeOverflow,
    MaximumSizeOverflow,
    OutOfFuel(required_fuel=42),
  ]
  ops["memory_error"] = a => {
    Show::to_string(memory_errors[parse_dec(a[0]).to_int()])
  }
  let table_errors : Array[TableError] = [
    OutOfSystemMemory,
    MinimumSizeOverflow,
    MaximumSizeOverflow,
    ResourceLimiterDeniedAllocation,
    GrowOutOfBounds,
    InitOutOfBounds,
    FillOutOfBounds,
    SetOutOfBounds,
    CopyOutOfBounds,
    ElementTypeMismatch,
    OutOfFuel(required_fuel=7),
  ]
  ops["table_error"] = a => {
    Show::to_string(table_errors[parse_dec(a[0]).to_int()])
  }
  let limiter_errors : Array[LimiterError] = [
    OutOfSystemMemory,
    OutOfBoundsGrowth,
    ResourceLimiterDeniedAllocation,
    OutOfFuel(required_fuel=5),
  ]
  ops["limiter_error"] = a => {
    Show::to_string(limiter_errors[parse_dec(a[0]).to_int()])
  }
  let fuel_errors : Array[FuelError] = [
    FuelMeteringDisabled,
    OutOfFuel(required_fuel=9),
  ]
  ops["fuel_error"] = a => {
    Show::to_string(fuel_errors[parse_dec(a[0]).to_int()])
  }
  let func_type_errors : Array[FuncTypeError] = [
    TooManyFunctionParams,
    TooManyFunctionResults,
  ]
  ops["func_type_error"] = a => {
    Show::to_string(func_type_errors[parse_dec(a[0]).to_int()])
  }
  let global_errors : Array[GlobalError] = [ImmutableWrite, TypeMismatch]
  ops["global_error"] = a => {
    Show::to_string(global_errors[parse_dec(a[0]).to_int()])
  }
  ops["untyped_error"] = _ => Show::to_string(UntypedError::invalid_len())
  ops["func_type"] = a => {
    let all : Array[ValType] = [I32, I64, F32, F64, V128, FuncRef, ExternRef]
    let np = parse_dec(a[0]).to_int()
    let nr = parse_dec(a[1]).to_int()
    let params = Array::makei(np, i => all[(i * 3 + 1) % 7])
    let results = Array::makei(nr, i => all[(i * 5 + 2) % 7])
    try FuncType::new(params, results) catch {
      e => "err \{e}"
    } noraise {
      ft => {
        let dbg = Show::to_string(ft)
        if dbg.length() > 200 {
          "ok \{ft.len_params()} \{ft.len_results()} \{dbg.length()}"
        } else {
          "ok \{ft.len_params()} \{ft.len_results()} \{dbg}"
        }
      }
    }
  }
  ops["f32_fmt"] = a => {
    let f = F32::from_bits(a_u32(a[0]))
    "\{f}|\{Repr(f)}"
  }
  ops["f64_fmt"] = a => {
    let f = F64::from_bits(a_u64(a[0]))
    "\{f}|\{Repr(f)}"
  }
}

///|
test "wasmi_core oracle" {
  guard oracle_module_root() is Some(root) else { return }
  let path = root + "wasmi/core/testdata/oracle.tsv"
  guard @fs.path_exists(path) else { return }
  let data = @fs.read_file_to_string(path)
  let ops : Map[String, OracleFn] = Map([])
  oracle_scalar_ops(ops)
  oracle_float_ops(ops)
  oracle_simd_ops(ops)
  oracle_memory_ops(ops)
  oracle_scenario_ops(ops)
  oracle_display_ops(ops)
  let mut total = 0
  let mut failed = 0
  let failures : Map[String, Int] = Map([])
  let examples : Array[String] = []
  for line in data.split("\n") {
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let fields = line.split("\t").map(s => s.to_owned()).collect()
    let op = fields[0]
    let expected = fields[fields.length() - 1]
    let args = fields[1:fields.length() - 1].to_owned()
    guard ops.get(op) is Some(f) else { fail("unknown oracle op \{op}") }
    total += 1
    let actual = f(args)
    if actual != expected {
      failed += 1
      failures[op] = failures.get(op).unwrap_or(0) + 1
      if examples.length() < 40 {
        examples.push(
          "\{op} \{args.join(" ")} => \{actual} (expected \{expected})",
        )
      }
    }
  }
  if failed > 0 {
    let by_op = failures.iter().map(p => "\{p.0}: \{p.1}").collect().join(", ")
    fail(
      "\{failed} of \{total} oracle cases failed (\{by_op})\n" +
      examples.join("\n"),
    )
  }
  println("wasmi_core oracle: \{total} cases passed")
}
