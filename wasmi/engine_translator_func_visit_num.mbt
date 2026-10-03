// Port of the numeric `visit_*` methods of wasmi 1.0.9
// `engine/translator/func/visit.rs` (converted mechanically from upstream).

///|
fn FuncTranslator::visit_i32_eq(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_eq,
    @ir.Op::i32_eq_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_eq(a.to_i32(), b.to_i32()),
      )
    },
    FuncTranslator::fuse_eqz,
  )
}

///|
fn FuncTranslator::visit_i32_ne(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_ne,
    @ir.Op::i32_ne_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_ne(a.to_i32(), b.to_i32()),
      )
    },
    FuncTranslator::fuse_nez,
  )
}

///|
fn FuncTranslator::visit_i32_lt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I32,
    I32,
    @ir.Op::i32_lt_s,
    @ir.Op::i32_lt_s_imm16_rhs,
    @ir.Op::i32_lt_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_lt_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_lt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U32,
    I32,
    @ir.Op::i32_lt_u,
    @ir.Op::i32_lt_u_imm16_rhs,
    @ir.Op::i32_lt_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_lt_u(a.to_u32(), b.to_u32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_gt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I32,
    I32,
    fn(r, a, b) { @ir.Op::i32_lt_s(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_lt_s_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_lt_s_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_gt_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_gt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U32,
    I32,
    fn(r, a, b) { @ir.Op::i32_lt_u(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_lt_u_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_lt_u_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_gt_u(a.to_u32(), b.to_u32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_le_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I32,
    I32,
    @ir.Op::i32_le_s,
    @ir.Op::i32_le_s_imm16_rhs,
    @ir.Op::i32_le_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_le_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_le_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U32,
    I32,
    @ir.Op::i32_le_u,
    @ir.Op::i32_le_u_imm16_rhs,
    @ir.Op::i32_le_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_le_u(a.to_u32(), b.to_u32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_ge_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I32,
    I32,
    fn(r, a, b) { @ir.Op::i32_le_s(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_le_s_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_le_s_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_ge_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_ge_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U32,
    I32,
    fn(r, a, b) { @ir.Op::i32_le_u(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_le_u_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i32_le_u_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i32_ge_u(a.to_u32(), b.to_u32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_eq(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I32,
    @ir.Op::i64_eq,
    @ir.Op::i64_eq_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_eq(a.to_i64(), b.to_i64()),
      )
    },
    FuncTranslator::fuse_eqz,
  )
}

///|
fn FuncTranslator::visit_i64_ne(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I32,
    @ir.Op::i64_ne,
    @ir.Op::i64_ne_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_ne(a.to_i64(), b.to_i64()),
      )
    },
    FuncTranslator::fuse_nez,
  )
}

///|
fn FuncTranslator::visit_i64_lt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I64,
    I32,
    @ir.Op::i64_lt_s,
    @ir.Op::i64_lt_s_imm16_rhs,
    @ir.Op::i64_lt_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_lt_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_lt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U64,
    I32,
    @ir.Op::i64_lt_u,
    @ir.Op::i64_lt_u_imm16_rhs,
    @ir.Op::i64_lt_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_lt_u(a.to_u64(), b.to_u64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_gt_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I64,
    I32,
    fn(r, a, b) { @ir.Op::i64_lt_s(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_lt_s_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_lt_s_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_gt_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_gt_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U64,
    I32,
    fn(r, a, b) { @ir.Op::i64_lt_u(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_lt_u_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_lt_u_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_gt_u(a.to_u64(), b.to_u64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_le_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I64,
    I32,
    @ir.Op::i64_le_s,
    @ir.Op::i64_le_s_imm16_rhs,
    @ir.Op::i64_le_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_le_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_le_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U64,
    I32,
    @ir.Op::i64_le_u,
    @ir.Op::i64_le_u_imm16_rhs,
    @ir.Op::i64_le_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_le_u(a.to_u64(), b.to_u64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_ge_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    I64,
    I32,
    fn(r, a, b) { @ir.Op::i64_le_s(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_le_s_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_le_s_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_ge_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_ge_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary(
    U64,
    I32,
    fn(r, a, b) { @ir.Op::i64_le_u(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_le_u_imm16_lhs(r, b, a) },
    fn(r, a, b) { @ir.Op::i64_le_u_imm16_rhs(r, b, a) },
    fn(a, b) {
      @wasmi_core.TypedVal::from_bool(
        @wasmi_core.i64_ge_u(a.to_u64(), b.to_u64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_f32_eq(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f32_eq, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f32_eq(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_ne(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f32_ne, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f32_ne(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_lt(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f32_lt, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f32_lt(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_gt(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, fn(r, a, b) { @ir.Op::f32_lt(r, b, a) }, fn(
    a,
    b,
  ) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f32_gt(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_le(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f32_le, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f32_le(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_ge(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, fn(r, a, b) { @ir.Op::f32_le(r, b, a) }, fn(
    a,
    b,
  ) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f32_ge(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f64_eq(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f64_eq, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f64_eq(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_ne(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f64_ne, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f64_ne(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_lt(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f64_lt, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f64_lt(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_gt(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, fn(r, a, b) { @ir.Op::f64_lt(r, b, a) }, fn(
    a,
    b,
  ) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f64_gt(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_le(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, @ir.Op::f64_le, fn(a, b) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f64_le(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_ge(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_fbinary(I32, fn(r, a, b) { @ir.Op::f64_le(r, b, a) }, fn(
    a,
    b,
  ) {
    @wasmi_core.TypedVal::from_bool(@wasmi_core.f64_ge(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i32_clz(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_clz, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_clz(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_i32_ctz(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_ctz, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_ctz(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_i32_popcnt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_popcnt, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_popcnt(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_i32_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_add,
    @ir.Op::i32_add_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_add(a.to_i32(), b.to_i32()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i32_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_isub(
    I32,
    @ir.Op::i32_sub,
    @ir.Op::i32_add_imm16,
    @ir.Op::i32_sub_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_sub(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_mul,
    @ir.Op::i32_mul_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_mul(a.to_i32(), b.to_i32()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i32_div_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    I32,
    @ir.Op::i32_div_s,
    @ir.Op::i32_div_s_imm16_rhs,
    @ir.Op::i32_div_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_div_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_div_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    U32,
    @ir.Op::i32_div_u,
    @ir.Op::i32_div_u_imm16_rhs,
    @ir.Op::i32_div_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_u32(
        @wasmi_core.i32_div_u(a.to_u32(), b.to_u32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_rem_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    I32,
    @ir.Op::i32_rem_s,
    @ir.Op::i32_rem_s_imm16_rhs,
    @ir.Op::i32_rem_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_rem_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_rem_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    U32,
    @ir.Op::i32_rem_u,
    @ir.Op::i32_rem_u_imm16_rhs,
    @ir.Op::i32_rem_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_u32(
        @wasmi_core.i32_rem_u(a.to_u32(), b.to_u32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_and(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_bitand,
    @ir.Op::i32_bitand_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_bitand(a.to_i32(), b.to_i32()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i32_or(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_bitor,
    @ir.Op::i32_bitor_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_bitor(a.to_i32(), b.to_i32()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i32_xor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I32,
    I32,
    @ir.Op::i32_bitxor,
    @ir.Op::i32_bitxor_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_bitxor(a.to_i32(), b.to_i32()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i32_shl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I32,
    @ir.Op::i32_shl,
    @ir.Op::i32_shl_by,
    @ir.Op::i32_shl_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_shl(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_shr_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I32,
    @ir.Op::i32_shr_s,
    @ir.Op::i32_shr_s_by,
    @ir.Op::i32_shr_s_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_shr_s(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_shr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I32,
    @ir.Op::i32_shr_u,
    @ir.Op::i32_shr_u_by,
    @ir.Op::i32_shr_u_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_shr_u(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_rotl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I32,
    @ir.Op::i32_rotl,
    @ir.Op::i32_rotl_by,
    @ir.Op::i32_rotl_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_rotl(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_rotr(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I32,
    @ir.Op::i32_rotr,
    @ir.Op::i32_rotr_by,
    @ir.Op::i32_rotr_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i32(
        @wasmi_core.i32_rotr(a.to_i32(), b.to_i32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_clz(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_clz, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_clz(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i64_ctz(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_ctz, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_ctz(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i64_popcnt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_popcnt, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_popcnt(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i64_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I64,
    @ir.Op::i64_add,
    @ir.Op::i64_add_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_add(a.to_i64(), b.to_i64()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i64_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_isub(
    I64,
    @ir.Op::i64_sub,
    @ir.Op::i64_add_imm16,
    @ir.Op::i64_sub_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_sub(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I64,
    @ir.Op::i64_mul,
    @ir.Op::i64_mul_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_mul(a.to_i64(), b.to_i64()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i64_div_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    I64,
    @ir.Op::i64_div_s,
    @ir.Op::i64_div_s_imm16_rhs,
    @ir.Op::i64_div_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_div_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_div_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    U64,
    @ir.Op::i64_div_u,
    @ir.Op::i64_div_u_imm16_rhs,
    @ir.Op::i64_div_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_u64(
        @wasmi_core.i64_div_u(a.to_u64(), b.to_u64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_rem_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    I64,
    @ir.Op::i64_rem_s,
    @ir.Op::i64_rem_s_imm16_rhs,
    @ir.Op::i64_rem_s_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_rem_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_rem_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_divrem(
    U64,
    @ir.Op::i64_rem_u,
    @ir.Op::i64_rem_u_imm16_rhs,
    @ir.Op::i64_rem_u_imm16_lhs,
    fn(a, b) {
      @wasmi_core.TypedVal::from_u64(
        @wasmi_core.i64_rem_u(a.to_u64(), b.to_u64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_and(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I64,
    @ir.Op::i64_bitand,
    @ir.Op::i64_bitand_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_bitand(a.to_i64(), b.to_i64()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i64_or(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I64,
    @ir.Op::i64_bitor,
    @ir.Op::i64_bitor_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_bitor(a.to_i64(), b.to_i64()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i64_xor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_binary_commutative(
    I64,
    I64,
    @ir.Op::i64_bitxor,
    @ir.Op::i64_bitxor_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_bitxor(a.to_i64(), b.to_i64()),
      )
    },
    no_opt_ri,
  )
}

///|
fn FuncTranslator::visit_i64_shl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I64,
    @ir.Op::i64_shl,
    @ir.Op::i64_shl_by,
    @ir.Op::i64_shl_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_shl(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_shr_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I64,
    @ir.Op::i64_shr_s,
    @ir.Op::i64_shr_s_by,
    @ir.Op::i64_shr_s_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_shr_s(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_shr_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I64,
    @ir.Op::i64_shr_u,
    @ir.Op::i64_shr_u_by,
    @ir.Op::i64_shr_u_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_shr_u(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_rotl(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I64,
    @ir.Op::i64_rotl,
    @ir.Op::i64_rotl_by,
    @ir.Op::i64_rotl_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_rotl(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i64_rotr(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_shift(
    I64,
    @ir.Op::i64_rotr,
    @ir.Op::i64_rotr_by,
    @ir.Op::i64_rotr_imm16,
    fn(a, b) {
      @wasmi_core.TypedVal::from_i64(
        @wasmi_core.i64_rotr(a.to_i64(), b.to_i64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_f32_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_abs, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_abs(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_neg, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_neg(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_ceil(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_ceil, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_ceil(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_floor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_floor, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_floor(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_trunc(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_trunc, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_trunc(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_nearest(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_nearest, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_nearest(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_sqrt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_sqrt, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_sqrt(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F32, @ir.Op::f32_add, fn(a, b) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_add(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F32, @ir.Op::f32_sub, fn(a, b) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_sub(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F32, @ir.Op::f32_mul, fn(a, b) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_mul(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_div(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F32, @ir.Op::f32_div, fn(a, b) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_div(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_min(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F32, @ir.Op::f32_min, fn(a, b) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_min(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_max(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F32, @ir.Op::f32_max, fn(a, b) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_max(a.to_f32(), b.to_f32()))
  })
}

///|
fn FuncTranslator::visit_f32_copysign(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fcopysign(
    F32,
    @ir.Op::f32_copysign,
    @ir.Op::f32_copysign_imm,
    fn(a, b) {
      @wasmi_core.TypedVal::from_f32(
        @wasmi_core.f32_copysign(a.to_f32(), b.to_f32()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_f64_abs(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_abs, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_abs(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_neg(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_neg, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_neg(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_ceil(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_ceil, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_ceil(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_floor(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_floor, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_floor(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_trunc(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_trunc, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_trunc(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_nearest(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_nearest, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_nearest(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_sqrt(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_sqrt, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_sqrt(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_add(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F64, @ir.Op::f64_add, fn(a, b) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_add(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_sub(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F64, @ir.Op::f64_sub, fn(a, b) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_sub(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_mul(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F64, @ir.Op::f64_mul, fn(a, b) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_mul(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_div(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F64, @ir.Op::f64_div, fn(a, b) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_div(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_min(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F64, @ir.Op::f64_min, fn(a, b) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_min(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_max(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fbinary(F64, @ir.Op::f64_max, fn(a, b) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_max(a.to_f64(), b.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_copysign(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_fcopysign(
    F64,
    @ir.Op::f64_copysign,
    @ir.Op::f64_copysign_imm,
    fn(a, b) {
      @wasmi_core.TypedVal::from_f64(
        @wasmi_core.f64_copysign(a.to_f64(), b.to_f64()),
      )
    },
  )
}

///|
fn FuncTranslator::visit_i32_wrap_i64(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_wrap_i64, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_wrap_i64(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_f32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I32, @ir.Op::i32_trunc_f32_s, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_trunc_f32_s(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_f32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I32, @ir.Op::i32_trunc_f32_u, fn(a) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i32_trunc_f32_u(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_f64_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I32, @ir.Op::i32_trunc_f64_s, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_trunc_f64_s(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_f64_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I32, @ir.Op::i32_trunc_f64_u, fn(a) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i32_trunc_f64_u(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i64_extend_i32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_extend32_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_extend_i32_s(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_i64_extend_i32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_reinterpret(I64, fn(a) {
    @wasmi_core.TypedVal::from_u64(@wasmi_core.i64_extend_i32_u(a.to_u32()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_f32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I64, @ir.Op::i64_trunc_f32_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_trunc_f32_s(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_f32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I64, @ir.Op::i64_trunc_f32_u, fn(a) {
    @wasmi_core.TypedVal::from_u64(@wasmi_core.i64_trunc_f32_u(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_f64_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I64, @ir.Op::i64_trunc_f64_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_trunc_f64_s(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_f64_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary_fallible(I64, @ir.Op::i64_trunc_f64_u, fn(a) {
    @wasmi_core.TypedVal::from_u64(@wasmi_core.i64_trunc_f64_u(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f32_convert_i32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_convert_i32_s, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_convert_i32_s(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_f32_convert_i32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_convert_i32_u, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_convert_i32_u(a.to_u32()))
  })
}

///|
fn FuncTranslator::visit_f32_convert_i64_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_convert_i64_s, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_convert_i64_s(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_f32_convert_i64_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_convert_i64_u, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_convert_i64_u(a.to_u64()))
  })
}

///|
fn FuncTranslator::visit_f32_demote_f64(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F32, @ir.Op::f32_demote_f64, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_demote_f64(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f64_convert_i32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_convert_i32_s, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_convert_i32_s(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_f64_convert_i32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_convert_i32_u, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_convert_i32_u(a.to_u32()))
  })
}

///|
fn FuncTranslator::visit_f64_convert_i64_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_convert_i64_s, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_convert_i64_s(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_f64_convert_i64_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_convert_i64_u, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_convert_i64_u(a.to_u64()))
  })
}

///|
fn FuncTranslator::visit_f64_promote_f32(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(F64, @ir.Op::f64_promote_f32, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_promote_f32(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i32_reinterpret_f32(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_reinterpret(I32, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_reinterpret_f32(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i64_reinterpret_f64(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_reinterpret(I64, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_reinterpret_f64(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_f32_reinterpret_i32(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_reinterpret(F32, fn(a) {
    @wasmi_core.TypedVal::from_f32(@wasmi_core.f32_reinterpret_i32(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_f64_reinterpret_i64(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_reinterpret(F64, fn(a) {
    @wasmi_core.TypedVal::from_f64(@wasmi_core.f64_reinterpret_i64(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i32_extend8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_extend8_s, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_extend8_s(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_i32_extend16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_extend16_s, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_extend16_s(a.to_i32()))
  })
}

///|
fn FuncTranslator::visit_i64_extend8_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_extend8_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_extend8_s(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i64_extend16_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_extend16_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_extend16_s(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i64_extend32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_extend32_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_extend32_s(a.to_i64()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_sat_f32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_trunc_sat_f32_s, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_trunc_sat_f32_s(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_sat_f32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_trunc_sat_f32_u, fn(a) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i32_trunc_sat_f32_u(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_sat_f64_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_trunc_sat_f64_s, fn(a) {
    @wasmi_core.TypedVal::from_i32(@wasmi_core.i32_trunc_sat_f64_s(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i32_trunc_sat_f64_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I32, @ir.Op::i32_trunc_sat_f64_u, fn(a) {
    @wasmi_core.TypedVal::from_u32(@wasmi_core.i32_trunc_sat_f64_u(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_sat_f32_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_trunc_sat_f32_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_trunc_sat_f32_s(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_sat_f32_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_trunc_sat_f32_u, fn(a) {
    @wasmi_core.TypedVal::from_u64(@wasmi_core.i64_trunc_sat_f32_u(a.to_f32()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_sat_f64_s(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_trunc_sat_f64_s, fn(a) {
    @wasmi_core.TypedVal::from_i64(@wasmi_core.i64_trunc_sat_f64_s(a.to_f64()))
  })
}

///|
fn FuncTranslator::visit_i64_trunc_sat_f64_u(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  self.translate_unary(I64, @ir.Op::i64_trunc_sat_f64_u, fn(a) {
    @wasmi_core.TypedVal::from_u64(@wasmi_core.i64_trunc_sat_f64_u(a.to_f64()))
  })
}
