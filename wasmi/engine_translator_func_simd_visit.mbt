// Port of the mechanical SIMD `visit_*` methods of wasmi 1.0.9
// `engine/translator/func/simd/visit.rs` (converted from upstream).

///|
fn FuncTranslator::visit_v128_load(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load,
    @ir.Op::v128_load_offset16,
    @ir.Op::v128_load_at,
  )
}

///|
fn FuncTranslator::visit_v128_load8x8_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load8x8_s,
    @ir.Op::v128_load8x8_s_offset16,
    @ir.Op::v128_load8x8_s_at,
  )
}

///|
fn FuncTranslator::visit_v128_load8x8_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load8x8_u,
    @ir.Op::v128_load8x8_u_offset16,
    @ir.Op::v128_load8x8_u_at,
  )
}

///|
fn FuncTranslator::visit_v128_load16x4_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load16x4_s,
    @ir.Op::v128_load16x4_s_offset16,
    @ir.Op::v128_load16x4_s_at,
  )
}

///|
fn FuncTranslator::visit_v128_load16x4_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load16x4_u,
    @ir.Op::v128_load16x4_u_offset16,
    @ir.Op::v128_load16x4_u_at,
  )
}

///|
fn FuncTranslator::visit_v128_load32x2_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load32x2_s,
    @ir.Op::v128_load32x2_s_offset16,
    @ir.Op::v128_load32x2_s_at,
  )
}

///|
fn FuncTranslator::visit_v128_load32x2_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load32x2_u,
    @ir.Op::v128_load32x2_u_offset16,
    @ir.Op::v128_load32x2_u_at,
  )
}

///|
fn FuncTranslator::visit_v128_load8_splat(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load8_splat,
    @ir.Op::v128_load8_splat_offset16,
    @ir.Op::v128_load8_splat_at,
  )
}

///|
fn FuncTranslator::visit_v128_load16_splat(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load16_splat,
    @ir.Op::v128_load16_splat_offset16,
    @ir.Op::v128_load16_splat_at,
  )
}

///|
fn FuncTranslator::visit_v128_load32_splat(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load32_splat,
    @ir.Op::v128_load32_splat_offset16,
    @ir.Op::v128_load32_splat_at,
  )
}

///|
fn FuncTranslator::visit_v128_load64_splat(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load64_splat,
    @ir.Op::v128_load64_splat_offset16,
    @ir.Op::v128_load64_splat_at,
  )
}

///|
fn FuncTranslator::visit_v128_load32_zero(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load32_zero,
    @ir.Op::v128_load32_zero_offset16,
    @ir.Op::v128_load32_zero_at,
  )
}

///|
fn FuncTranslator::visit_v128_load64_zero(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    V128,
    @ir.Op::v128_load64_zero,
    @ir.Op::v128_load64_zero_offset16,
    @ir.Op::v128_load64_zero_at,
  )
}

///|
fn FuncTranslator::visit_v128_store(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_store(
    memarg,
    @ir.Op::v128_store,
    @ir.Op::v128_store_offset16,
    @ir.Op::v128_store_at,
  )
}

///|
fn FuncTranslator::visit_i8x16_swizzle(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_swizzle, @wasmi_core.i8x16_swizzle)
}

///|
fn FuncTranslator::visit_i8x16_splat(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_splat(@ir.Op::i8x16_splat, fn(v) {
    @wasmi_core.i8x16_splat(v.to_i32())
  })
}

///|
fn FuncTranslator::visit_i16x8_splat(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_splat(@ir.Op::i16x8_splat, fn(v) {
    @wasmi_core.i16x8_splat(v.to_i32())
  })
}

///|
fn FuncTranslator::visit_i32x4_splat(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_splat(@ir.Op::i32x4_splat, fn(v) {
    @wasmi_core.i32x4_splat(v.to_i32())
  })
}

///|
fn FuncTranslator::visit_i64x2_splat(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_splat(@ir.Op::i64x2_splat, fn(v) {
    @wasmi_core.i64x2_splat(v.to_i64())
  })
}

///|
fn FuncTranslator::visit_f32x4_splat(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_splat(@ir.Op::f32x4_splat, fn(v) {
    @wasmi_core.f32x4_splat(v.to_f32())
  })
}

///|
fn FuncTranslator::visit_f64x2_splat(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_splat(@ir.Op::f64x2_splat, fn(v) {
    @wasmi_core.f64x2_splat(v.to_f64())
  })
}

///|
fn FuncTranslator::visit_i8x16_eq(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_eq, @wasmi_core.i8x16_eq)
}

///|
fn FuncTranslator::visit_i8x16_ne(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_ne, @wasmi_core.i8x16_ne)
}

///|
fn FuncTranslator::visit_i8x16_lt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_lt_s, @wasmi_core.i8x16_lt_s)
}

///|
fn FuncTranslator::visit_i8x16_lt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_lt_u, @wasmi_core.i8x16_lt_u)
}

///|
fn FuncTranslator::visit_i8x16_gt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i8x16_lt_s(r, b, a) },
    @wasmi_core.i8x16_gt_s,
  )
}

///|
fn FuncTranslator::visit_i8x16_gt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i8x16_lt_u(r, b, a) },
    @wasmi_core.i8x16_gt_u,
  )
}

///|
fn FuncTranslator::visit_i8x16_le_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_le_s, @wasmi_core.i8x16_le_s)
}

///|
fn FuncTranslator::visit_i8x16_le_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_le_u, @wasmi_core.i8x16_le_u)
}

///|
fn FuncTranslator::visit_i8x16_ge_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i8x16_le_s(r, b, a) },
    @wasmi_core.i8x16_ge_s,
  )
}

///|
fn FuncTranslator::visit_i8x16_ge_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i8x16_le_u(r, b, a) },
    @wasmi_core.i8x16_ge_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_eq(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_eq, @wasmi_core.i16x8_eq)
}

///|
fn FuncTranslator::visit_i16x8_ne(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_ne, @wasmi_core.i16x8_ne)
}

///|
fn FuncTranslator::visit_i16x8_lt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_lt_s, @wasmi_core.i16x8_lt_s)
}

///|
fn FuncTranslator::visit_i16x8_lt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_lt_u, @wasmi_core.i16x8_lt_u)
}

///|
fn FuncTranslator::visit_i16x8_gt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i16x8_lt_s(r, b, a) },
    @wasmi_core.i16x8_gt_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_gt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i16x8_lt_u(r, b, a) },
    @wasmi_core.i16x8_gt_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_le_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_le_s, @wasmi_core.i16x8_le_s)
}

///|
fn FuncTranslator::visit_i16x8_le_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_le_u, @wasmi_core.i16x8_le_u)
}

///|
fn FuncTranslator::visit_i16x8_ge_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i16x8_le_s(r, b, a) },
    @wasmi_core.i16x8_ge_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_ge_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i16x8_le_u(r, b, a) },
    @wasmi_core.i16x8_ge_u,
  )
}

///|
fn FuncTranslator::visit_i32x4_eq(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_eq, @wasmi_core.i32x4_eq)
}

///|
fn FuncTranslator::visit_i32x4_ne(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_ne, @wasmi_core.i32x4_ne)
}

///|
fn FuncTranslator::visit_i32x4_lt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_lt_s, @wasmi_core.i32x4_lt_s)
}

///|
fn FuncTranslator::visit_i32x4_lt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_lt_u, @wasmi_core.i32x4_lt_u)
}

///|
fn FuncTranslator::visit_i32x4_gt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i32x4_lt_s(r, b, a) },
    @wasmi_core.i32x4_gt_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_gt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i32x4_lt_u(r, b, a) },
    @wasmi_core.i32x4_gt_u,
  )
}

///|
fn FuncTranslator::visit_i32x4_le_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_le_s, @wasmi_core.i32x4_le_s)
}

///|
fn FuncTranslator::visit_i32x4_le_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_le_u, @wasmi_core.i32x4_le_u)
}

///|
fn FuncTranslator::visit_i32x4_ge_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i32x4_le_s(r, b, a) },
    @wasmi_core.i32x4_ge_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_ge_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i32x4_le_u(r, b, a) },
    @wasmi_core.i32x4_ge_u,
  )
}

///|
fn FuncTranslator::visit_i64x2_eq(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_eq, @wasmi_core.i64x2_eq)
}

///|
fn FuncTranslator::visit_i64x2_ne(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_ne, @wasmi_core.i64x2_ne)
}

///|
fn FuncTranslator::visit_i64x2_lt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_lt_s, @wasmi_core.i64x2_lt_s)
}

///|
fn FuncTranslator::visit_i64x2_gt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i64x2_lt_s(r, b, a) },
    @wasmi_core.i64x2_gt_s,
  )
}

///|
fn FuncTranslator::visit_i64x2_le_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_le_s, @wasmi_core.i64x2_le_s)
}

///|
fn FuncTranslator::visit_i64x2_ge_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::i64x2_le_s(r, b, a) },
    @wasmi_core.i64x2_ge_s,
  )
}

///|
fn FuncTranslator::visit_f32x4_eq(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_eq, @wasmi_core.f32x4_eq)
}

///|
fn FuncTranslator::visit_f32x4_ne(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_ne, @wasmi_core.f32x4_ne)
}

///|
fn FuncTranslator::visit_f32x4_lt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_lt, @wasmi_core.f32x4_lt)
}

///|
fn FuncTranslator::visit_f32x4_gt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::f32x4_lt(r, b, a) },
    @wasmi_core.f32x4_gt,
  )
}

///|
fn FuncTranslator::visit_f32x4_le(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_le, @wasmi_core.f32x4_le)
}

///|
fn FuncTranslator::visit_f32x4_ge(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::f32x4_le(r, b, a) },
    @wasmi_core.f32x4_ge,
  )
}

///|
fn FuncTranslator::visit_f64x2_eq(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_eq, @wasmi_core.f64x2_eq)
}

///|
fn FuncTranslator::visit_f64x2_ne(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_ne, @wasmi_core.f64x2_ne)
}

///|
fn FuncTranslator::visit_f64x2_lt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_lt, @wasmi_core.f64x2_lt)
}

///|
fn FuncTranslator::visit_f64x2_gt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::f64x2_lt(r, b, a) },
    @wasmi_core.f64x2_gt,
  )
}

///|
fn FuncTranslator::visit_f64x2_le(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_le, @wasmi_core.f64x2_le)
}

///|
fn FuncTranslator::visit_f64x2_ge(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    fn(r, a, b) { @ir.Op::f64x2_le(r, b, a) },
    @wasmi_core.f64x2_ge,
  )
}

///|
fn FuncTranslator::visit_v128_not(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::v128_not, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.v128_not(v))
  })
}

///|
fn FuncTranslator::visit_v128_and(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::v128_and, @wasmi_core.v128_and)
}

///|
fn FuncTranslator::visit_v128_andnot(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::v128_andnot, @wasmi_core.v128_andnot)
}

///|
fn FuncTranslator::visit_v128_or(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::v128_or, @wasmi_core.v128_or)
}

///|
fn FuncTranslator::visit_v128_xor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::v128_xor, @wasmi_core.v128_xor)
}

///|
fn FuncTranslator::visit_v128_bitselect(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_ternary(
    @ir.Op::v128_bitselect,
    @wasmi_core.v128_bitselect,
  )
}

///|
fn FuncTranslator::visit_v128_any_true(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::v128_any_true, fn(v) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.v128_any_true(v))
  })
}

///|
fn FuncTranslator::visit_i8x16_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i8x16_abs, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i8x16_abs(v))
  })
}

///|
fn FuncTranslator::visit_i8x16_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i8x16_neg, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i8x16_neg(v))
  })
}

///|
fn FuncTranslator::visit_i8x16_popcnt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i8x16_popcnt, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i8x16_popcnt(v))
  })
}

///|
fn FuncTranslator::visit_i8x16_all_true(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i8x16_all_true, fn(v) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.i8x16_all_true(v))
  })
}

///|
fn FuncTranslator::visit_i8x16_bitmask(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i8x16_bitmask, fn(v) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i8x16_bitmask(v))
  })
}

///|
fn FuncTranslator::visit_i8x16_narrow_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i8x16_narrow_i16x8_s,
    @wasmi_core.i8x16_narrow_i16x8_s,
  )
}

///|
fn FuncTranslator::visit_i8x16_narrow_i16x8_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i8x16_narrow_i16x8_u,
    @wasmi_core.i8x16_narrow_i16x8_u,
  )
}

///|
fn FuncTranslator::visit_i8x16_shl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    8,
    @ir.Op::i8x16_shl,
    @ir.Op::i8x16_shl_by,
    @wasmi_core.i8x16_shl,
  )
}

///|
fn FuncTranslator::visit_i8x16_shr_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    8,
    @ir.Op::i8x16_shr_s,
    @ir.Op::i8x16_shr_s_by,
    @wasmi_core.i8x16_shr_s,
  )
}

///|
fn FuncTranslator::visit_i8x16_shr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    8,
    @ir.Op::i8x16_shr_u,
    @ir.Op::i8x16_shr_u_by,
    @wasmi_core.i8x16_shr_u,
  )
}

///|
fn FuncTranslator::visit_i8x16_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_add, @wasmi_core.i8x16_add)
}

///|
fn FuncTranslator::visit_i8x16_add_sat_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i8x16_add_sat_s,
    @wasmi_core.i8x16_add_sat_s,
  )
}

///|
fn FuncTranslator::visit_i8x16_add_sat_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i8x16_add_sat_u,
    @wasmi_core.i8x16_add_sat_u,
  )
}

///|
fn FuncTranslator::visit_i8x16_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_sub, @wasmi_core.i8x16_sub)
}

///|
fn FuncTranslator::visit_i8x16_sub_sat_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i8x16_sub_sat_s,
    @wasmi_core.i8x16_sub_sat_s,
  )
}

///|
fn FuncTranslator::visit_i8x16_sub_sat_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i8x16_sub_sat_u,
    @wasmi_core.i8x16_sub_sat_u,
  )
}

///|
fn FuncTranslator::visit_i8x16_min_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_min_s, @wasmi_core.i8x16_min_s)
}

///|
fn FuncTranslator::visit_i8x16_min_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_min_u, @wasmi_core.i8x16_min_u)
}

///|
fn FuncTranslator::visit_i8x16_max_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_max_s, @wasmi_core.i8x16_max_s)
}

///|
fn FuncTranslator::visit_i8x16_max_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_max_u, @wasmi_core.i8x16_max_u)
}

///|
fn FuncTranslator::visit_i8x16_avgr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i8x16_avgr_u, @wasmi_core.i8x16_avgr_u)
}

///|
fn FuncTranslator::visit_i16x8_extadd_pairwise_i8x16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_extadd_pairwise_i8x16_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(
      @wasmi_core.i16x8_extadd_pairwise_i8x16_s(v),
    )
  })
}

///|
fn FuncTranslator::visit_i16x8_extadd_pairwise_i8x16_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_extadd_pairwise_i8x16_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(
      @wasmi_core.i16x8_extadd_pairwise_i8x16_u(v),
    )
  })
}

///|
fn FuncTranslator::visit_i16x8_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_abs, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i16x8_abs(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_neg, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i16x8_neg(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_q15mulr_sat_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_q15mulr_sat_s,
    @wasmi_core.i16x8_q15mulr_sat_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_all_true(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i16x8_all_true, fn(v) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.i16x8_all_true(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_bitmask(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i16x8_bitmask, fn(v) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i16x8_bitmask(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_narrow_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_narrow_i32x4_s,
    @wasmi_core.i16x8_narrow_i32x4_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_narrow_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_narrow_i32x4_u,
    @wasmi_core.i16x8_narrow_i32x4_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_extend_low_i8x16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_extend_low_i8x16_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i16x8_extend_low_i8x16_s(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_extend_high_i8x16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_extend_high_i8x16_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i16x8_extend_high_i8x16_s(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_extend_low_i8x16_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_extend_low_i8x16_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i16x8_extend_low_i8x16_u(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_extend_high_i8x16_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i16x8_extend_high_i8x16_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i16x8_extend_high_i8x16_u(v))
  })
}

///|
fn FuncTranslator::visit_i16x8_shl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    16,
    @ir.Op::i16x8_shl,
    @ir.Op::i16x8_shl_by,
    @wasmi_core.i16x8_shl,
  )
}

///|
fn FuncTranslator::visit_i16x8_shr_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    16,
    @ir.Op::i16x8_shr_s,
    @ir.Op::i16x8_shr_s_by,
    @wasmi_core.i16x8_shr_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_shr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    16,
    @ir.Op::i16x8_shr_u,
    @ir.Op::i16x8_shr_u_by,
    @wasmi_core.i16x8_shr_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_add, @wasmi_core.i16x8_add)
}

///|
fn FuncTranslator::visit_i16x8_add_sat_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_add_sat_s,
    @wasmi_core.i16x8_add_sat_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_add_sat_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_add_sat_u,
    @wasmi_core.i16x8_add_sat_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_sub, @wasmi_core.i16x8_sub)
}

///|
fn FuncTranslator::visit_i16x8_sub_sat_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_sub_sat_s,
    @wasmi_core.i16x8_sub_sat_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_sub_sat_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_sub_sat_u,
    @wasmi_core.i16x8_sub_sat_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_mul, @wasmi_core.i16x8_mul)
}

///|
fn FuncTranslator::visit_i16x8_min_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_min_s, @wasmi_core.i16x8_min_s)
}

///|
fn FuncTranslator::visit_i16x8_min_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_min_u, @wasmi_core.i16x8_min_u)
}

///|
fn FuncTranslator::visit_i16x8_max_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_max_s, @wasmi_core.i16x8_max_s)
}

///|
fn FuncTranslator::visit_i16x8_max_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_max_u, @wasmi_core.i16x8_max_u)
}

///|
fn FuncTranslator::visit_i16x8_avgr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i16x8_avgr_u, @wasmi_core.i16x8_avgr_u)
}

///|
fn FuncTranslator::visit_i16x8_extmul_low_i8x16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_extmul_low_i8x16_s,
    @wasmi_core.i16x8_extmul_low_i8x16_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_extmul_high_i8x16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_extmul_high_i8x16_s,
    @wasmi_core.i16x8_extmul_high_i8x16_s,
  )
}

///|
fn FuncTranslator::visit_i16x8_extmul_low_i8x16_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_extmul_low_i8x16_u,
    @wasmi_core.i16x8_extmul_low_i8x16_u,
  )
}

///|
fn FuncTranslator::visit_i16x8_extmul_high_i8x16_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_extmul_high_i8x16_u,
    @wasmi_core.i16x8_extmul_high_i8x16_u,
  )
}

///|
fn FuncTranslator::visit_i32x4_extadd_pairwise_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_extadd_pairwise_i16x8_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(
      @wasmi_core.i32x4_extadd_pairwise_i16x8_s(v),
    )
  })
}

///|
fn FuncTranslator::visit_i32x4_extadd_pairwise_i16x8_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_extadd_pairwise_i16x8_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(
      @wasmi_core.i32x4_extadd_pairwise_i16x8_u(v),
    )
  })
}

///|
fn FuncTranslator::visit_i32x4_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_abs, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_abs(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_neg, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_neg(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_all_true(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i32x4_all_true, fn(v) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.i32x4_all_true(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_bitmask(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i32x4_bitmask, fn(v) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i32x4_bitmask(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_extend_low_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_extend_low_i16x8_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_extend_low_i16x8_s(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_extend_high_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_extend_high_i16x8_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_extend_high_i16x8_s(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_extend_low_i16x8_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_extend_low_i16x8_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_extend_low_i16x8_u(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_extend_high_i16x8_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_extend_high_i16x8_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_extend_high_i16x8_u(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_shl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    32,
    @ir.Op::i32x4_shl,
    @ir.Op::i32x4_shl_by,
    @wasmi_core.i32x4_shl,
  )
}

///|
fn FuncTranslator::visit_i32x4_shr_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    32,
    @ir.Op::i32x4_shr_s,
    @ir.Op::i32x4_shr_s_by,
    @wasmi_core.i32x4_shr_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_shr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    32,
    @ir.Op::i32x4_shr_u,
    @ir.Op::i32x4_shr_u_by,
    @wasmi_core.i32x4_shr_u,
  )
}

///|
fn FuncTranslator::visit_i32x4_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_add, @wasmi_core.i32x4_add)
}

///|
fn FuncTranslator::visit_i32x4_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_sub, @wasmi_core.i32x4_sub)
}

///|
fn FuncTranslator::visit_i32x4_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_mul, @wasmi_core.i32x4_mul)
}

///|
fn FuncTranslator::visit_i32x4_min_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_min_s, @wasmi_core.i32x4_min_s)
}

///|
fn FuncTranslator::visit_i32x4_min_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_min_u, @wasmi_core.i32x4_min_u)
}

///|
fn FuncTranslator::visit_i32x4_max_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_max_s, @wasmi_core.i32x4_max_s)
}

///|
fn FuncTranslator::visit_i32x4_max_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i32x4_max_u, @wasmi_core.i32x4_max_u)
}

///|
fn FuncTranslator::visit_i32x4_dot_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i32x4_dot_i16x8_s,
    @wasmi_core.i32x4_dot_i16x8_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_extmul_low_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i32x4_extmul_low_i16x8_s,
    @wasmi_core.i32x4_extmul_low_i16x8_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_extmul_high_i16x8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i32x4_extmul_high_i16x8_s,
    @wasmi_core.i32x4_extmul_high_i16x8_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_extmul_low_i16x8_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i32x4_extmul_low_i16x8_u,
    @wasmi_core.i32x4_extmul_low_i16x8_u,
  )
}

///|
fn FuncTranslator::visit_i32x4_extmul_high_i16x8_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i32x4_extmul_high_i16x8_u,
    @wasmi_core.i32x4_extmul_high_i16x8_u,
  )
}

///|
fn FuncTranslator::visit_i64x2_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i64x2_abs, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i64x2_abs(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i64x2_neg, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i64x2_neg(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_all_true(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i64x2_all_true, fn(v) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.i64x2_all_true(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_bitmask(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(I32, @ir.Op::i64x2_bitmask, fn(v) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i64x2_bitmask(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_extend_low_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i64x2_extend_low_i32x4_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i64x2_extend_low_i32x4_s(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_extend_high_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i64x2_extend_high_i32x4_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i64x2_extend_high_i32x4_s(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_extend_low_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i64x2_extend_low_i32x4_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i64x2_extend_low_i32x4_u(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_extend_high_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i64x2_extend_high_i32x4_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i64x2_extend_high_i32x4_u(v))
  })
}

///|
fn FuncTranslator::visit_i64x2_shl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    64,
    @ir.Op::i64x2_shl,
    @ir.Op::i64x2_shl_by,
    @wasmi_core.i64x2_shl,
  )
}

///|
fn FuncTranslator::visit_i64x2_shr_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    64,
    @ir.Op::i64x2_shr_s,
    @ir.Op::i64x2_shr_s_by,
    @wasmi_core.i64x2_shr_s,
  )
}

///|
fn FuncTranslator::visit_i64x2_shr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_shift(
    64,
    @ir.Op::i64x2_shr_u,
    @ir.Op::i64x2_shr_u_by,
    @wasmi_core.i64x2_shr_u,
  )
}

///|
fn FuncTranslator::visit_i64x2_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_add, @wasmi_core.i64x2_add)
}

///|
fn FuncTranslator::visit_i64x2_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_sub, @wasmi_core.i64x2_sub)
}

///|
fn FuncTranslator::visit_i64x2_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::i64x2_mul, @wasmi_core.i64x2_mul)
}

///|
fn FuncTranslator::visit_i64x2_extmul_low_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i64x2_extmul_low_i32x4_s,
    @wasmi_core.i64x2_extmul_low_i32x4_s,
  )
}

///|
fn FuncTranslator::visit_i64x2_extmul_high_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i64x2_extmul_high_i32x4_s,
    @wasmi_core.i64x2_extmul_high_i32x4_s,
  )
}

///|
fn FuncTranslator::visit_i64x2_extmul_low_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i64x2_extmul_low_i32x4_u,
    @wasmi_core.i64x2_extmul_low_i32x4_u,
  )
}

///|
fn FuncTranslator::visit_i64x2_extmul_high_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i64x2_extmul_high_i32x4_u,
    @wasmi_core.i64x2_extmul_high_i32x4_u,
  )
}

///|
fn FuncTranslator::visit_f32x4_ceil(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_ceil, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_ceil(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_floor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_floor, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_floor(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_trunc(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_trunc, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_trunc(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_nearest(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_nearest, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_nearest(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_abs, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_abs(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_neg, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_neg(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_sqrt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_sqrt, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_sqrt(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_add, @wasmi_core.f32x4_add)
}

///|
fn FuncTranslator::visit_f32x4_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_sub, @wasmi_core.f32x4_sub)
}

///|
fn FuncTranslator::visit_f32x4_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_mul, @wasmi_core.f32x4_mul)
}

///|
fn FuncTranslator::visit_f32x4_div(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_div, @wasmi_core.f32x4_div)
}

///|
fn FuncTranslator::visit_f32x4_min(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_min, @wasmi_core.f32x4_min)
}

///|
fn FuncTranslator::visit_f32x4_max(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_max, @wasmi_core.f32x4_max)
}

///|
fn FuncTranslator::visit_f32x4_pmin(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_pmin, @wasmi_core.f32x4_pmin)
}

///|
fn FuncTranslator::visit_f32x4_pmax(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f32x4_pmax, @wasmi_core.f32x4_pmax)
}

///|
fn FuncTranslator::visit_f64x2_ceil(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_ceil, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_ceil(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_floor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_floor, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_floor(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_trunc(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_trunc, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_trunc(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_nearest(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_nearest, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_nearest(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_abs, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_abs(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_neg, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_neg(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_sqrt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_sqrt, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_sqrt(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_add, @wasmi_core.f64x2_add)
}

///|
fn FuncTranslator::visit_f64x2_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_sub, @wasmi_core.f64x2_sub)
}

///|
fn FuncTranslator::visit_f64x2_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_mul, @wasmi_core.f64x2_mul)
}

///|
fn FuncTranslator::visit_f64x2_div(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_div, @wasmi_core.f64x2_div)
}

///|
fn FuncTranslator::visit_f64x2_min(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_min, @wasmi_core.f64x2_min)
}

///|
fn FuncTranslator::visit_f64x2_max(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_max, @wasmi_core.f64x2_max)
}

///|
fn FuncTranslator::visit_f64x2_pmin(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_pmin, @wasmi_core.f64x2_pmin)
}

///|
fn FuncTranslator::visit_f64x2_pmax(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(@ir.Op::f64x2_pmax, @wasmi_core.f64x2_pmax)
}

///|
fn FuncTranslator::visit_i32x4_trunc_sat_f32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_trunc_sat_f32x4_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_trunc_sat_f32x4_s(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_trunc_sat_f32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_trunc_sat_f32x4_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_trunc_sat_f32x4_u(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_convert_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_convert_i32x4_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_convert_i32x4_s(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_convert_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_convert_i32x4_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_convert_i32x4_u(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_trunc_sat_f64x2_s_zero(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_trunc_sat_f64x2_s_zero, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_trunc_sat_f64x2_s_zero(v))
  })
}

///|
fn FuncTranslator::visit_i32x4_trunc_sat_f64x2_u_zero(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::i32x4_trunc_sat_f64x2_u_zero, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.i32x4_trunc_sat_f64x2_u_zero(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_convert_low_i32x4_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_convert_low_i32x4_s, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_convert_low_i32x4_s(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_convert_low_i32x4_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_convert_low_i32x4_u, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_convert_low_i32x4_u(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_demote_f64x2_zero(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f32x4_demote_f64x2_zero, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f32x4_demote_f64x2_zero(v))
  })
}

///|
fn FuncTranslator::visit_f64x2_promote_low_f32x4(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_unary(V128, @ir.Op::f64x2_promote_low_f32x4, fn(v) {
    @wasmi_core.TypedVal::from_v128(@wasmi_core.f64x2_promote_low_f32x4(v))
  })
}

///|
fn FuncTranslator::visit_f32x4_relaxed_madd(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_ternary(
    @ir.Op::f32x4_relaxed_madd,
    @wasmi_core.f32x4_relaxed_madd,
  )
}

///|
fn FuncTranslator::visit_f32x4_relaxed_nmadd(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_ternary(
    @ir.Op::f32x4_relaxed_nmadd,
    @wasmi_core.f32x4_relaxed_nmadd,
  )
}

///|
fn FuncTranslator::visit_f64x2_relaxed_madd(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_ternary(
    @ir.Op::f64x2_relaxed_madd,
    @wasmi_core.f64x2_relaxed_madd,
  )
}

///|
fn FuncTranslator::visit_f64x2_relaxed_nmadd(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_ternary(
    @ir.Op::f64x2_relaxed_nmadd,
    @wasmi_core.f64x2_relaxed_nmadd,
  )
}

///|
fn FuncTranslator::visit_i16x8_relaxed_dot_i8x16_i7x16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_binary(
    @ir.Op::i16x8_relaxed_dot_i8x16_i7x16_s,
    @wasmi_core.i16x8_relaxed_dot_i8x16_i7x16_s,
  )
}

///|
fn FuncTranslator::visit_i32x4_relaxed_dot_i8x16_i7x16_add_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_simd_ternary(
    @ir.Op::i32x4_relaxed_dot_i8x16_i7x16_add_s,
    @wasmi_core.i32x4_relaxed_dot_i8x16_i7x16_add_s,
  )
}
