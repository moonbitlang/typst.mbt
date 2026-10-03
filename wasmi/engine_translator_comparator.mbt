// Port of wasmi 1.0.9 `engine/translator/comparator.rs`.
//
// The large match tables were converted mechanically from upstream.

///|
/// Types able to allocate function local constant values.
///
/// # Note
///
/// This allows to cheaply convert immediate values to [`Slot`]s.
pub(open) trait AllocConst {
  /// Allocates a new function local constant value and returns its [`Slot`].
  ///
  /// # Note
  ///
  /// Constant values allocated this way are deduplicated and return shared [`Slot`].
  fn alloc_const(Self, @wasmi_core.UntypedVal) -> @ir.Slot raise WasmiError
}

///|
/// Returns the result [`Slot`] of `instr` if it is a comparison instruction
/// (upstream `CompareResult::compare_result`).
pub fn compare_result(instr : @ir.Op) -> @ir.Slot? {
  match instr {
    I32BitAnd(result~, ..)
    | I32BitAndImm16(result~, ..)
    | I32BitOr(result~, ..)
    | I32BitOrImm16(result~, ..)
    | I32BitXor(result~, ..)
    | I32BitXorImm16(result~, ..)
    | I32And(result~, ..)
    | I32AndImm16(result~, ..)
    | I32Or(result~, ..)
    | I32OrImm16(result~, ..)
    | I32Nand(result~, ..)
    | I32NandImm16(result~, ..)
    | I32Nor(result~, ..)
    | I32NorImm16(result~, ..)
    | I32Eq(result~, ..)
    | I32EqImm16(result~, ..)
    | I32Ne(result~, ..)
    | I32NeImm16(result~, ..)
    | I32LtS(result~, ..)
    | I32LtSImm16Lhs(result~, ..)
    | I32LtSImm16Rhs(result~, ..)
    | I32LtU(result~, ..)
    | I32LtUImm16Lhs(result~, ..)
    | I32LtUImm16Rhs(result~, ..)
    | I32LeS(result~, ..)
    | I32LeSImm16Lhs(result~, ..)
    | I32LeSImm16Rhs(result~, ..)
    | I32LeU(result~, ..)
    | I32LeUImm16Lhs(result~, ..)
    | I32LeUImm16Rhs(result~, ..)
    | I64BitAnd(result~, ..)
    | I64BitAndImm16(result~, ..)
    | I64BitOr(result~, ..)
    | I64BitOrImm16(result~, ..)
    | I64BitXor(result~, ..)
    | I64BitXorImm16(result~, ..)
    | I64And(result~, ..)
    | I64AndImm16(result~, ..)
    | I64Or(result~, ..)
    | I64OrImm16(result~, ..)
    | I64Nand(result~, ..)
    | I64NandImm16(result~, ..)
    | I64Nor(result~, ..)
    | I64NorImm16(result~, ..)
    | I64Eq(result~, ..)
    | I64EqImm16(result~, ..)
    | I64Ne(result~, ..)
    | I64NeImm16(result~, ..)
    | I64LtS(result~, ..)
    | I64LtSImm16Lhs(result~, ..)
    | I64LtSImm16Rhs(result~, ..)
    | I64LtU(result~, ..)
    | I64LtUImm16Lhs(result~, ..)
    | I64LtUImm16Rhs(result~, ..)
    | I64LeS(result~, ..)
    | I64LeSImm16Lhs(result~, ..)
    | I64LeSImm16Rhs(result~, ..)
    | I64LeU(result~, ..)
    | I64LeUImm16Lhs(result~, ..)
    | I64LeUImm16Rhs(result~, ..)
    | F32Eq(result~, ..)
    | F32Ne(result~, ..)
    | F32Lt(result~, ..)
    | F32Le(result~, ..)
    | F32NotLt(result~, ..)
    | F32NotLe(result~, ..)
    | F64Eq(result~, ..)
    | F64Ne(result~, ..)
    | F64Lt(result~, ..)
    | F64Le(result~, ..)
    | F64NotLt(result~, ..)
    | F64NotLe(result~, ..) => Some(result)
    _ => None
  }
}

///|
/// Returns `true` if `instr` is a comparison instruction.
pub fn is_compare_instr(instr : @ir.Op) -> Bool {
  compare_result(instr) is Some(_)
}

///|
/// Returns `instr` with its result replaced by `new_result` if `instr` is a
/// comparison instruction (upstream `ReplaceCmpResult::replace_cmp_result`).
pub fn replace_cmp_result(instr : @ir.Op, new_result : @ir.Slot) -> @ir.Op? {
  if !is_compare_instr(instr) {
    return None
  }
  instr.set_result(new_result)
}

///|
/// Negates the compare (`cmp`) instruction (upstream
/// `NegateCmpInstr::negate_cmp_instr`).
pub fn negate_cmp_instr(instr : @ir.Op) -> @ir.Op? {
  let negated = match instr {
    // i32
    I32Eq(result~, lhs~, rhs~) => @ir.Op::i32_ne(result, lhs, rhs)
    I32Ne(result~, lhs~, rhs~) => @ir.Op::i32_eq(result, lhs, rhs)
    I32LeS(result~, lhs~, rhs~) => @ir.Op::i32_lt_s(result, rhs, lhs)
    I32LeU(result~, lhs~, rhs~) => @ir.Op::i32_lt_u(result, rhs, lhs)
    I32LtS(result~, lhs~, rhs~) => @ir.Op::i32_le_s(result, rhs, lhs)
    I32LtU(result~, lhs~, rhs~) => @ir.Op::i32_le_u(result, rhs, lhs)
    I32EqImm16(result~, lhs~, rhs~) => @ir.Op::i32_ne_imm16(result, lhs, rhs)
    I32NeImm16(result~, lhs~, rhs~) => @ir.Op::i32_eq_imm16(result, lhs, rhs)
    I32LeSImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_lt_s_imm16_lhs(result, rhs, lhs)
    I32LeUImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_lt_u_imm16_lhs(result, rhs, lhs)
    I32LtSImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_le_s_imm16_lhs(result, rhs, lhs)
    I32LtUImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_le_u_imm16_lhs(result, rhs, lhs)
    I32LeSImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_lt_s_imm16_rhs(result, rhs, lhs)
    I32LeUImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_lt_u_imm16_rhs(result, rhs, lhs)
    I32LtSImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_le_s_imm16_rhs(result, rhs, lhs)
    I32LtUImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i32_le_u_imm16_rhs(result, rhs, lhs)
    // i32 (and, or, xor)
    I32BitAnd(result~, lhs~, rhs~) => @ir.Op::i32_nand(result, lhs, rhs)
    I32BitOr(result~, lhs~, rhs~) => @ir.Op::i32_nor(result, lhs, rhs)
    I32BitXor(result~, lhs~, rhs~) => @ir.Op::i32_eq(result, lhs, rhs)
    I32BitAndImm16(result~, lhs~, rhs~) =>
      @ir.Op::i32_nand_imm16(result, lhs, rhs)
    I32BitOrImm16(result~, lhs~, rhs~) =>
      @ir.Op::i32_nor_imm16(result, lhs, rhs)
    I32BitXorImm16(result~, lhs~, rhs~) =>
      @ir.Op::i32_eq_imm16(result, lhs, rhs)
    I32And(result~, lhs~, rhs~) => @ir.Op::i32_nand(result, lhs, rhs)
    I32Or(result~, lhs~, rhs~) => @ir.Op::i32_nor(result, lhs, rhs)
    I32AndImm16(result~, lhs~, rhs~) => @ir.Op::i32_nand_imm16(result, lhs, rhs)
    I32OrImm16(result~, lhs~, rhs~) => @ir.Op::i32_nor_imm16(result, lhs, rhs)
    I32Nand(result~, lhs~, rhs~) => @ir.Op::i32_and(result, lhs, rhs)
    I32Nor(result~, lhs~, rhs~) => @ir.Op::i32_or(result, lhs, rhs)
    I32NandImm16(result~, lhs~, rhs~) => @ir.Op::i32_and_imm16(result, lhs, rhs)
    I32NorImm16(result~, lhs~, rhs~) => @ir.Op::i32_or_imm16(result, lhs, rhs)
    // i64
    I64Eq(result~, lhs~, rhs~) => @ir.Op::i64_ne(result, lhs, rhs)
    I64Ne(result~, lhs~, rhs~) => @ir.Op::i64_eq(result, lhs, rhs)
    I64LeS(result~, lhs~, rhs~) => @ir.Op::i64_lt_s(result, rhs, lhs)
    I64LeU(result~, lhs~, rhs~) => @ir.Op::i64_lt_u(result, rhs, lhs)
    I64LtS(result~, lhs~, rhs~) => @ir.Op::i64_le_s(result, rhs, lhs)
    I64LtU(result~, lhs~, rhs~) => @ir.Op::i64_le_u(result, rhs, lhs)
    I64EqImm16(result~, lhs~, rhs~) => @ir.Op::i64_ne_imm16(result, lhs, rhs)
    I64NeImm16(result~, lhs~, rhs~) => @ir.Op::i64_eq_imm16(result, lhs, rhs)
    I64LeSImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_lt_s_imm16_lhs(result, rhs, lhs)
    I64LeUImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_lt_u_imm16_lhs(result, rhs, lhs)
    I64LtSImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_le_s_imm16_lhs(result, rhs, lhs)
    I64LtUImm16Rhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_le_u_imm16_lhs(result, rhs, lhs)
    I64LeSImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_lt_s_imm16_rhs(result, rhs, lhs)
    I64LeUImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_lt_u_imm16_rhs(result, rhs, lhs)
    I64LtSImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_le_s_imm16_rhs(result, rhs, lhs)
    I64LtUImm16Lhs(result~, lhs~, rhs~) =>
      @ir.Op::i64_le_u_imm16_rhs(result, rhs, lhs)
    // i64 (and, or, xor)
    I64BitAnd(result~, lhs~, rhs~) => @ir.Op::i64_nand(result, lhs, rhs)
    I64BitOr(result~, lhs~, rhs~) => @ir.Op::i64_nor(result, lhs, rhs)
    I64BitXor(result~, lhs~, rhs~) => @ir.Op::i64_eq(result, lhs, rhs)
    I64BitAndImm16(result~, lhs~, rhs~) =>
      @ir.Op::i64_nand_imm16(result, lhs, rhs)
    I64BitOrImm16(result~, lhs~, rhs~) =>
      @ir.Op::i64_nor_imm16(result, lhs, rhs)
    I64BitXorImm16(result~, lhs~, rhs~) =>
      @ir.Op::i64_eq_imm16(result, lhs, rhs)
    I64And(result~, lhs~, rhs~) => @ir.Op::i64_nand(result, lhs, rhs)
    I64Or(result~, lhs~, rhs~) => @ir.Op::i64_nor(result, lhs, rhs)
    I64AndImm16(result~, lhs~, rhs~) => @ir.Op::i64_nand_imm16(result, lhs, rhs)
    I64OrImm16(result~, lhs~, rhs~) => @ir.Op::i64_nor_imm16(result, lhs, rhs)
    I64Nand(result~, lhs~, rhs~) => @ir.Op::i64_and(result, lhs, rhs)
    I64Nor(result~, lhs~, rhs~) => @ir.Op::i64_or(result, lhs, rhs)
    I64NandImm16(result~, lhs~, rhs~) => @ir.Op::i64_and_imm16(result, lhs, rhs)
    I64NorImm16(result~, lhs~, rhs~) => @ir.Op::i64_or_imm16(result, lhs, rhs)
    // f32
    F32Eq(result~, lhs~, rhs~) => @ir.Op::f32_ne(result, lhs, rhs)
    F32Ne(result~, lhs~, rhs~) => @ir.Op::f32_eq(result, lhs, rhs)
    F32Le(result~, lhs~, rhs~) => @ir.Op::f32_not_le(result, lhs, rhs)
    F32Lt(result~, lhs~, rhs~) => @ir.Op::f32_not_lt(result, lhs, rhs)
    F32NotLe(result~, lhs~, rhs~) => @ir.Op::f32_le(result, lhs, rhs)
    F32NotLt(result~, lhs~, rhs~) => @ir.Op::f32_lt(result, lhs, rhs)
    // f64
    F64Eq(result~, lhs~, rhs~) => @ir.Op::f64_ne(result, lhs, rhs)
    F64Ne(result~, lhs~, rhs~) => @ir.Op::f64_eq(result, lhs, rhs)
    F64Le(result~, lhs~, rhs~) => @ir.Op::f64_not_le(result, lhs, rhs)
    F64Lt(result~, lhs~, rhs~) => @ir.Op::f64_not_lt(result, lhs, rhs)
    F64NotLe(result~, lhs~, rhs~) => @ir.Op::f64_le(result, lhs, rhs)
    F64NotLt(result~, lhs~, rhs~) => @ir.Op::f64_lt(result, lhs, rhs)
    _ => return None
  }
  Some(negated)
}

///|
/// Converts comparison instructions into their logical form (upstream
/// `LogicalizeCmpInstr::logicalize_cmp_instr`).
///
/// # Note
///
/// - Bitwise operators like `bitand`, `bitor` and `bitxor` are converted
///   into their logical equivalents `and`, `or` and `xor`.
/// - Logical operators are returned as is.
pub fn logicalize_cmp_instr(instr : @ir.Op) -> @ir.Op? {
  let logicalized = match instr {
    // Bitwise -> Logical: i32
    I32BitAnd(result~, lhs~, rhs~) => @ir.Op::i32_and(result, lhs, rhs)
    I32BitOr(result~, lhs~, rhs~) => @ir.Op::i32_or(result, lhs, rhs)
    I32BitXor(result~, lhs~, rhs~) => @ir.Op::i32_ne(result, lhs, rhs)
    I32BitAndImm16(result~, lhs~, rhs~) =>
      @ir.Op::i32_and_imm16(result, lhs, rhs)
    I32BitOrImm16(result~, lhs~, rhs~) => @ir.Op::i32_or_imm16(result, lhs, rhs)
    I32BitXorImm16(result~, lhs~, rhs~) =>
      @ir.Op::i32_ne_imm16(result, lhs, rhs)
    // Bitwise -> Logical: i64
    I64BitAnd(result~, lhs~, rhs~) => @ir.Op::i64_and(result, lhs, rhs)
    I64BitOr(result~, lhs~, rhs~) => @ir.Op::i64_or(result, lhs, rhs)
    I64BitXor(result~, lhs~, rhs~) => @ir.Op::i64_ne(result, lhs, rhs)
    I64BitAndImm16(result~, lhs~, rhs~) =>
      @ir.Op::i64_and_imm16(result, lhs, rhs)
    I64BitOrImm16(result~, lhs~, rhs~) => @ir.Op::i64_or_imm16(result, lhs, rhs)
    I64BitXorImm16(result~, lhs~, rhs~) =>
      @ir.Op::i64_ne_imm16(result, lhs, rhs)
    // Logical -> Logical
    I32Eq(..)
    | I32Ne(..)
    | I32LeS(..)
    | I32LeU(..)
    | I32LtS(..)
    | I32LtU(..)
    | I32EqImm16(..)
    | I32NeImm16(..)
    | I32LeSImm16Rhs(..)
    | I32LeUImm16Rhs(..)
    | I32LtSImm16Rhs(..)
    | I32LtUImm16Rhs(..)
    | I32LeSImm16Lhs(..)
    | I32LeUImm16Lhs(..)
    | I32LtSImm16Lhs(..)
    | I32LtUImm16Lhs(..)
    | I32And(..)
    | I32Or(..)
    | I32AndImm16(..)
    | I32OrImm16(..)
    | I32Nand(..)
    | I32Nor(..)
    | I32NandImm16(..)
    | I32NorImm16(..)
    | I64Eq(..)
    | I64Ne(..)
    | I64LeS(..)
    | I64LeU(..)
    | I64LtS(..)
    | I64LtU(..)
    | I64EqImm16(..)
    | I64NeImm16(..)
    | I64LeSImm16Rhs(..)
    | I64LeUImm16Rhs(..)
    | I64LtSImm16Rhs(..)
    | I64LtUImm16Rhs(..)
    | I64LeSImm16Lhs(..)
    | I64LeUImm16Lhs(..)
    | I64LtSImm16Lhs(..)
    | I64LtUImm16Lhs(..)
    | I64And(..)
    | I64Or(..)
    | I64AndImm16(..)
    | I64OrImm16(..)
    | I64Nand(..)
    | I64Nor(..)
    | I64NandImm16(..)
    | I64NorImm16(..)
    | F32Eq(..)
    | F32Ne(..)
    | F32Lt(..)
    | F32Le(..)
    | F32NotLt(..)
    | F32NotLe(..)
    | F64Eq(..)
    | F64Ne(..)
    | F64Lt(..)
    | F64Le(..)
    | F64NotLt(..)
    | F64NotLe(..) => instr
    _ => return None
  }
  Some(logicalized)
}

///|
/// The outcome of a fused cmp+select.
pub(all) enum CmpSelectFusion {
  /// The cmp+select fusion was applied and may require swapping operands.
  Applied(fused~ : @ir.Op, swap_operands~ : Bool)
  /// The cmp+select fusion was _not_ applied.
  Unapplied
}

///|
/// Returns `true` if a `cmp+select` fused instruction required to swap its operands.
fn cmp_select_swap_operands(instr : @ir.Op) -> Bool {
  match instr {
    I32Ne(..)
    | I32NeImm16(..)
    | I32LeSImm16Lhs(..)
    | I32LeUImm16Lhs(..)
    | I32LtSImm16Lhs(..)
    | I32LtUImm16Lhs(..)
    | I32BitXor(..)
    | I32BitXorImm16(..)
    | I64BitXor(..)
    | I64BitXorImm16(..)
    | I32Nand(..)
    | I32Nor(..)
    | I32NandImm16(..)
    | I32NorImm16(..)
    | I64Ne(..)
    | I64NeImm16(..)
    | I64LeSImm16Lhs(..)
    | I64LeUImm16Lhs(..)
    | I64LtSImm16Lhs(..)
    | I64LtUImm16Lhs(..)
    | I64Nand(..)
    | I64Nor(..)
    | I64NandImm16(..)
    | I64NorImm16(..)
    | F32Ne(..)
    | F64Ne(..)
    | F32NotLt(..)
    | F32NotLe(..)
    | F64NotLt(..)
    | F64NotLe(..) => true
    _ => false
  }
}

///|
/// Tries to fuse a compare instruction with a Wasm `select` instruction
/// (upstream `TryIntoCmpSelectInstr::try_into_cmp_select_instr`).
pub fn try_into_cmp_select_instr(
  instr : @ir.Op,
  get_result : () -> @ir.Slot raise WasmiError,
) -> CmpSelectFusion raise WasmiError {
  if !is_compare_instr(instr) {
    return Unapplied
  }
  let swap_operands = cmp_select_swap_operands(instr)
  let result = get_result()
  let fused = match instr {
    // i32
    I32Eq(lhs~, rhs~, ..) => @ir.Op::select_i32_eq(result, lhs, rhs)
    I32Ne(lhs~, rhs~, ..) => @ir.Op::select_i32_eq(result, lhs, rhs)
    I32LeS(lhs~, rhs~, ..) => @ir.Op::select_i32_le_s(result, lhs, rhs)
    I32LeU(lhs~, rhs~, ..) => @ir.Op::select_i32_le_u(result, lhs, rhs)
    I32LtS(lhs~, rhs~, ..) => @ir.Op::select_i32_lt_s(result, lhs, rhs)
    I32LtU(lhs~, rhs~, ..) => @ir.Op::select_i32_lt_u(result, lhs, rhs)
    I32EqImm16(lhs~, rhs~, ..) => @ir.Op::select_i32_eq_imm16(result, lhs, rhs)
    I32NeImm16(lhs~, rhs~, ..) => @ir.Op::select_i32_eq_imm16(result, lhs, rhs)
    I32LeSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_lt_s_imm16_rhs(result, rhs, lhs)
    I32LeUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_lt_u_imm16_rhs(result, rhs, lhs)
    I32LtSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_le_s_imm16_rhs(result, rhs, lhs)
    I32LtUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_le_u_imm16_rhs(result, rhs, lhs)
    I32LeSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_le_s_imm16_rhs(result, lhs, rhs)
    I32LeUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_le_u_imm16_rhs(result, lhs, rhs)
    I32LtSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_lt_s_imm16_rhs(result, lhs, rhs)
    I32LtUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_lt_u_imm16_rhs(result, lhs, rhs)
    // i32 (and, or, xor)
    I32BitAnd(lhs~, rhs~, ..) => @ir.Op::select_i32_and(result, lhs, rhs)
    I32BitOr(lhs~, rhs~, ..) => @ir.Op::select_i32_or(result, lhs, rhs)
    I32BitXor(lhs~, rhs~, ..) => @ir.Op::select_i32_eq(result, lhs, rhs)
    I32And(lhs~, rhs~, ..) => @ir.Op::select_i32_and(result, lhs, rhs)
    I32Or(lhs~, rhs~, ..) => @ir.Op::select_i32_or(result, lhs, rhs)
    I32Nand(lhs~, rhs~, ..) => @ir.Op::select_i32_and(result, lhs, rhs)
    I32Nor(lhs~, rhs~, ..) => @ir.Op::select_i32_or(result, lhs, rhs)
    I32BitAndImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_and_imm16(result, lhs, rhs)
    I32BitOrImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_or_imm16(result, lhs, rhs)
    I32BitXorImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_eq_imm16(result, lhs, rhs)
    I32AndImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_and_imm16(result, lhs, rhs)
    I32OrImm16(lhs~, rhs~, ..) => @ir.Op::select_i32_or_imm16(result, lhs, rhs)
    I32NandImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i32_and_imm16(result, lhs, rhs)
    I32NorImm16(lhs~, rhs~, ..) => @ir.Op::select_i32_or_imm16(result, lhs, rhs)
    // i64
    I64Eq(lhs~, rhs~, ..) => @ir.Op::select_i64_eq(result, lhs, rhs)
    I64Ne(lhs~, rhs~, ..) => @ir.Op::select_i64_eq(result, lhs, rhs)
    I64LeS(lhs~, rhs~, ..) => @ir.Op::select_i64_le_s(result, lhs, rhs)
    I64LeU(lhs~, rhs~, ..) => @ir.Op::select_i64_le_u(result, lhs, rhs)
    I64LtS(lhs~, rhs~, ..) => @ir.Op::select_i64_lt_s(result, lhs, rhs)
    I64LtU(lhs~, rhs~, ..) => @ir.Op::select_i64_lt_u(result, lhs, rhs)
    I64EqImm16(lhs~, rhs~, ..) => @ir.Op::select_i64_eq_imm16(result, lhs, rhs)
    I64NeImm16(lhs~, rhs~, ..) => @ir.Op::select_i64_eq_imm16(result, lhs, rhs)
    I64LeSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_lt_s_imm16_rhs(result, rhs, lhs)
    I64LeUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_lt_u_imm16_rhs(result, rhs, lhs)
    I64LtSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_le_s_imm16_rhs(result, rhs, lhs)
    I64LtUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_le_u_imm16_rhs(result, rhs, lhs)
    I64LeSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_le_s_imm16_rhs(result, lhs, rhs)
    I64LeUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_le_u_imm16_rhs(result, lhs, rhs)
    I64LtSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_lt_s_imm16_rhs(result, lhs, rhs)
    I64LtUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_lt_u_imm16_rhs(result, lhs, rhs)
    // i64 (and, or, xor)
    I64BitAnd(lhs~, rhs~, ..) => @ir.Op::select_i64_and(result, lhs, rhs)
    I64BitOr(lhs~, rhs~, ..) => @ir.Op::select_i64_or(result, lhs, rhs)
    I64BitXor(lhs~, rhs~, ..) => @ir.Op::select_i64_eq(result, lhs, rhs)
    I64And(lhs~, rhs~, ..) => @ir.Op::select_i64_and(result, lhs, rhs)
    I64Or(lhs~, rhs~, ..) => @ir.Op::select_i64_or(result, lhs, rhs)
    I64Nand(lhs~, rhs~, ..) => @ir.Op::select_i64_and(result, lhs, rhs)
    I64Nor(lhs~, rhs~, ..) => @ir.Op::select_i64_or(result, lhs, rhs)
    I64BitAndImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_and_imm16(result, lhs, rhs)
    I64BitOrImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_or_imm16(result, lhs, rhs)
    I64BitXorImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_eq_imm16(result, lhs, rhs)
    I64AndImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_and_imm16(result, lhs, rhs)
    I64OrImm16(lhs~, rhs~, ..) => @ir.Op::select_i64_or_imm16(result, lhs, rhs)
    I64NandImm16(lhs~, rhs~, ..) =>
      @ir.Op::select_i64_and_imm16(result, lhs, rhs)
    I64NorImm16(lhs~, rhs~, ..) => @ir.Op::select_i64_or_imm16(result, lhs, rhs)
    // f32
    F32Eq(lhs~, rhs~, ..) => @ir.Op::select_f32_eq(result, lhs, rhs)
    F32Ne(lhs~, rhs~, ..) => @ir.Op::select_f32_eq(result, lhs, rhs)
    F32Lt(lhs~, rhs~, ..) => @ir.Op::select_f32_lt(result, lhs, rhs)
    F32Le(lhs~, rhs~, ..) => @ir.Op::select_f32_le(result, lhs, rhs)
    F32NotLt(lhs~, rhs~, ..) => @ir.Op::select_f32_lt(result, lhs, rhs)
    F32NotLe(lhs~, rhs~, ..) => @ir.Op::select_f32_le(result, lhs, rhs)
    // f64
    F64Eq(lhs~, rhs~, ..) => @ir.Op::select_f64_eq(result, lhs, rhs)
    F64Ne(lhs~, rhs~, ..) => @ir.Op::select_f64_eq(result, lhs, rhs)
    F64Lt(lhs~, rhs~, ..) => @ir.Op::select_f64_lt(result, lhs, rhs)
    F64Le(lhs~, rhs~, ..) => @ir.Op::select_f64_le(result, lhs, rhs)
    F64NotLt(lhs~, rhs~, ..) => @ir.Op::select_f64_lt(result, lhs, rhs)
    F64NotLe(lhs~, rhs~, ..) => @ir.Op::select_f64_le(result, lhs, rhs)
    _ => abort("expected to successfully fuse cmp+select")
  }
  Applied(fused~, swap_operands~)
}

///|
/// Tries to convert `instr` into a fused cmp+branch instruction (upstream
/// `TryIntoCmpBranchInstr::try_into_cmp_branch_instr`).
pub fn[S : AllocConst] try_into_cmp_branch_instr(
  instr : @ir.Op,
  offset : @ir.BranchOffset,
  stack : S,
) -> @ir.Op? raise WasmiError {
  let offset = @ir.BranchOffset16::try_from(offset) catch {
    _ => return try_into_cmp_branch_fallback_instr(instr, offset, stack)
  }
  let cmp_branch_instr = match instr {
    // i32
    I32Eq(lhs~, rhs~, ..) => @ir.Op::branch_i32_eq(lhs, rhs, offset)
    I32Ne(lhs~, rhs~, ..) => @ir.Op::branch_i32_ne(lhs, rhs, offset)
    I32LeS(lhs~, rhs~, ..) => @ir.Op::branch_i32_le_s(lhs, rhs, offset)
    I32LeU(lhs~, rhs~, ..) => @ir.Op::branch_i32_le_u(lhs, rhs, offset)
    I32LtS(lhs~, rhs~, ..) => @ir.Op::branch_i32_lt_s(lhs, rhs, offset)
    I32LtU(lhs~, rhs~, ..) => @ir.Op::branch_i32_lt_u(lhs, rhs, offset)
    I32EqImm16(lhs~, rhs~, ..) => @ir.Op::branch_i32_eq_imm16(lhs, rhs, offset)
    I32NeImm16(lhs~, rhs~, ..) => @ir.Op::branch_i32_ne_imm16(lhs, rhs, offset)
    I32LeSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_le_s_imm16_lhs(lhs, rhs, offset)
    I32LeUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_le_u_imm16_lhs(lhs, rhs, offset)
    I32LtSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_lt_s_imm16_lhs(lhs, rhs, offset)
    I32LtUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_lt_u_imm16_lhs(lhs, rhs, offset)
    I32LeSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_le_s_imm16_rhs(lhs, rhs, offset)
    I32LeUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_le_u_imm16_rhs(lhs, rhs, offset)
    I32LtSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_lt_s_imm16_rhs(lhs, rhs, offset)
    I32LtUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_lt_u_imm16_rhs(lhs, rhs, offset)
    // i32 (and, or, xor)
    I32BitAnd(lhs~, rhs~, ..) => @ir.Op::branch_i32_and(lhs, rhs, offset)
    I32BitOr(lhs~, rhs~, ..) => @ir.Op::branch_i32_or(lhs, rhs, offset)
    I32BitXor(lhs~, rhs~, ..) => @ir.Op::branch_i32_ne(lhs, rhs, offset)
    I32And(lhs~, rhs~, ..) => @ir.Op::branch_i32_and(lhs, rhs, offset)
    I32Or(lhs~, rhs~, ..) => @ir.Op::branch_i32_or(lhs, rhs, offset)
    I32Nand(lhs~, rhs~, ..) => @ir.Op::branch_i32_nand(lhs, rhs, offset)
    I32Nor(lhs~, rhs~, ..) => @ir.Op::branch_i32_nor(lhs, rhs, offset)
    I32BitAndImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_and_imm16(lhs, rhs, offset)
    I32BitOrImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_or_imm16(lhs, rhs, offset)
    I32BitXorImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_ne_imm16(lhs, rhs, offset)
    I32AndImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_and_imm16(lhs, rhs, offset)
    I32OrImm16(lhs~, rhs~, ..) => @ir.Op::branch_i32_or_imm16(lhs, rhs, offset)
    I32NandImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_nand_imm16(lhs, rhs, offset)
    I32NorImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i32_nor_imm16(lhs, rhs, offset)
    // i64
    I64Eq(lhs~, rhs~, ..) => @ir.Op::branch_i64_eq(lhs, rhs, offset)
    I64Ne(lhs~, rhs~, ..) => @ir.Op::branch_i64_ne(lhs, rhs, offset)
    I64LeS(lhs~, rhs~, ..) => @ir.Op::branch_i64_le_s(lhs, rhs, offset)
    I64LeU(lhs~, rhs~, ..) => @ir.Op::branch_i64_le_u(lhs, rhs, offset)
    I64LtS(lhs~, rhs~, ..) => @ir.Op::branch_i64_lt_s(lhs, rhs, offset)
    I64LtU(lhs~, rhs~, ..) => @ir.Op::branch_i64_lt_u(lhs, rhs, offset)
    I64EqImm16(lhs~, rhs~, ..) => @ir.Op::branch_i64_eq_imm16(lhs, rhs, offset)
    I64NeImm16(lhs~, rhs~, ..) => @ir.Op::branch_i64_ne_imm16(lhs, rhs, offset)
    I64LeSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_le_s_imm16_lhs(lhs, rhs, offset)
    I64LeUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_le_u_imm16_lhs(lhs, rhs, offset)
    I64LtSImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_lt_s_imm16_lhs(lhs, rhs, offset)
    I64LtUImm16Lhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_lt_u_imm16_lhs(lhs, rhs, offset)
    I64LeSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_le_s_imm16_rhs(lhs, rhs, offset)
    I64LeUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_le_u_imm16_rhs(lhs, rhs, offset)
    I64LtSImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_lt_s_imm16_rhs(lhs, rhs, offset)
    I64LtUImm16Rhs(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_lt_u_imm16_rhs(lhs, rhs, offset)
    // i64 (and, or, xor)
    I64BitAnd(lhs~, rhs~, ..) => @ir.Op::branch_i64_and(lhs, rhs, offset)
    I64BitOr(lhs~, rhs~, ..) => @ir.Op::branch_i64_or(lhs, rhs, offset)
    I64BitXor(lhs~, rhs~, ..) => @ir.Op::branch_i64_ne(lhs, rhs, offset)
    I64And(lhs~, rhs~, ..) => @ir.Op::branch_i64_and(lhs, rhs, offset)
    I64Or(lhs~, rhs~, ..) => @ir.Op::branch_i64_or(lhs, rhs, offset)
    I64Nand(lhs~, rhs~, ..) => @ir.Op::branch_i64_nand(lhs, rhs, offset)
    I64Nor(lhs~, rhs~, ..) => @ir.Op::branch_i64_nor(lhs, rhs, offset)
    I64BitAndImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_and_imm16(lhs, rhs, offset)
    I64BitOrImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_or_imm16(lhs, rhs, offset)
    I64BitXorImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_ne_imm16(lhs, rhs, offset)
    I64AndImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_and_imm16(lhs, rhs, offset)
    I64OrImm16(lhs~, rhs~, ..) => @ir.Op::branch_i64_or_imm16(lhs, rhs, offset)
    I64NandImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_nand_imm16(lhs, rhs, offset)
    I64NorImm16(lhs~, rhs~, ..) =>
      @ir.Op::branch_i64_nor_imm16(lhs, rhs, offset)
    // f32
    F32Eq(lhs~, rhs~, ..) => @ir.Op::branch_f32_eq(lhs, rhs, offset)
    F32Ne(lhs~, rhs~, ..) => @ir.Op::branch_f32_ne(lhs, rhs, offset)
    F32Lt(lhs~, rhs~, ..) => @ir.Op::branch_f32_lt(lhs, rhs, offset)
    F32Le(lhs~, rhs~, ..) => @ir.Op::branch_f32_le(lhs, rhs, offset)
    F32NotLt(lhs~, rhs~, ..) => @ir.Op::branch_f32_not_lt(lhs, rhs, offset)
    F32NotLe(lhs~, rhs~, ..) => @ir.Op::branch_f32_not_le(lhs, rhs, offset)
    // f64
    F64Eq(lhs~, rhs~, ..) => @ir.Op::branch_f64_eq(lhs, rhs, offset)
    F64Ne(lhs~, rhs~, ..) => @ir.Op::branch_f64_ne(lhs, rhs, offset)
    F64Lt(lhs~, rhs~, ..) => @ir.Op::branch_f64_lt(lhs, rhs, offset)
    F64Le(lhs~, rhs~, ..) => @ir.Op::branch_f64_le(lhs, rhs, offset)
    F64NotLt(lhs~, rhs~, ..) => @ir.Op::branch_f64_not_lt(lhs, rhs, offset)
    F64NotLe(lhs~, rhs~, ..) => @ir.Op::branch_f64_not_le(lhs, rhs, offset)
    _ => return None
  }
  Some(cmp_branch_instr)
}

///|
/// Tries to convert `instr` into a cmp+branch fallback instruction (upstream
/// `TryIntoCmpBranchFallbackInstr::try_into_cmp_branch_fallback_instr`).
pub fn[S : AllocConst] try_into_cmp_branch_fallback_instr(
  instr : @ir.Op,
  offset : @ir.BranchOffset,
  stack : S,
) -> @ir.Op? raise WasmiError {
  guard try_into_cmp_br_comparator(instr) is Some(comparator) else {
    return None
  }
  let (lhs, rhs) = match instr {
    BranchI32And(lhs~, rhs~, ..)
    | BranchI32Or(lhs~, rhs~, ..)
    | BranchI32Nand(lhs~, rhs~, ..)
    | BranchI32Nor(lhs~, rhs~, ..)
    | BranchI32Eq(lhs~, rhs~, ..)
    | BranchI32Ne(lhs~, rhs~, ..)
    | BranchI32LtS(lhs~, rhs~, ..)
    | BranchI32LtU(lhs~, rhs~, ..)
    | BranchI32LeS(lhs~, rhs~, ..)
    | BranchI32LeU(lhs~, rhs~, ..)
    | BranchI64And(lhs~, rhs~, ..)
    | BranchI64Or(lhs~, rhs~, ..)
    | BranchI64Nand(lhs~, rhs~, ..)
    | BranchI64Nor(lhs~, rhs~, ..)
    | BranchI64Eq(lhs~, rhs~, ..)
    | BranchI64Ne(lhs~, rhs~, ..)
    | BranchI64LtS(lhs~, rhs~, ..)
    | BranchI64LtU(lhs~, rhs~, ..)
    | BranchI64LeS(lhs~, rhs~, ..)
    | BranchI64LeU(lhs~, rhs~, ..)
    | BranchF32Eq(lhs~, rhs~, ..)
    | BranchF32Ne(lhs~, rhs~, ..)
    | BranchF32Lt(lhs~, rhs~, ..)
    | BranchF32Le(lhs~, rhs~, ..)
    | BranchF32NotLt(lhs~, rhs~, ..)
    | BranchF32NotLe(lhs~, rhs~, ..)
    | BranchF64Eq(lhs~, rhs~, ..)
    | BranchF64Ne(lhs~, rhs~, ..)
    | BranchF64Lt(lhs~, rhs~, ..)
    | BranchF64Le(lhs~, rhs~, ..)
    | BranchF64NotLt(lhs~, rhs~, ..)
    | BranchF64NotLe(lhs~, rhs~, ..) => (lhs, rhs)
    BranchI32AndImm16(lhs~, rhs~, ..)
    | BranchI32OrImm16(lhs~, rhs~, ..)
    | BranchI32NandImm16(lhs~, rhs~, ..)
    | BranchI32NorImm16(lhs~, rhs~, ..)
    | BranchI32EqImm16(lhs~, rhs~, ..)
    | BranchI32NeImm16(lhs~, rhs~, ..)
    | BranchI32LtSImm16Rhs(lhs~, rhs~, ..)
    | BranchI32LeSImm16Rhs(lhs~, rhs~, ..) => {
      let rhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_i32(rhs.to_i32()),
      )
      (lhs, rhs)
    }
    BranchI32LtSImm16Lhs(lhs~, rhs~, ..)
    | BranchI32LeSImm16Lhs(lhs~, rhs~, ..) => {
      let lhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_i32(lhs.to_i32()),
      )
      (lhs, rhs)
    }
    BranchI32LtUImm16Rhs(lhs~, rhs~, ..)
    | BranchI32LeUImm16Rhs(lhs~, rhs~, ..) => {
      let rhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_u32(rhs.to_u32()),
      )
      (lhs, rhs)
    }
    BranchI32LtUImm16Lhs(lhs~, rhs~, ..)
    | BranchI32LeUImm16Lhs(lhs~, rhs~, ..) => {
      let lhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_u32(lhs.to_u32()),
      )
      (lhs, rhs)
    }
    BranchI64AndImm16(lhs~, rhs~, ..)
    | BranchI64OrImm16(lhs~, rhs~, ..)
    | BranchI64NandImm16(lhs~, rhs~, ..)
    | BranchI64NorImm16(lhs~, rhs~, ..)
    | BranchI64EqImm16(lhs~, rhs~, ..)
    | BranchI64NeImm16(lhs~, rhs~, ..)
    | BranchI64LtSImm16Rhs(lhs~, rhs~, ..)
    | BranchI64LeSImm16Rhs(lhs~, rhs~, ..) => {
      let rhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_i64(rhs.to_i64()),
      )
      (lhs, rhs)
    }
    BranchI64LtSImm16Lhs(lhs~, rhs~, ..)
    | BranchI64LeSImm16Lhs(lhs~, rhs~, ..) => {
      let lhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_i64(lhs.to_i64()),
      )
      (lhs, rhs)
    }
    BranchI64LtUImm16Rhs(lhs~, rhs~, ..)
    | BranchI64LeUImm16Rhs(lhs~, rhs~, ..) => {
      let rhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_u64(rhs.to_u64()),
      )
      (lhs, rhs)
    }
    BranchI64LtUImm16Lhs(lhs~, rhs~, ..)
    | BranchI64LeUImm16Lhs(lhs~, rhs~, ..) => {
      let lhs = stack.alloc_const(
        @wasmi_core.UntypedVal::from_u64(lhs.to_u64()),
      )
      (lhs, rhs)
    }
    _ => return None
  }
  let params = stack.alloc_const(
    @wasmi_core.UntypedVal::from_u64(
      @ir.ComparatorAndOffset::new(comparator, offset).as_u64(),
    ),
  )
  Some(@ir.Op::branch_cmp_fallback(lhs, rhs, params))
}

///|
/// Extracts the [`Comparator`] of a cmp+branch instruction.
fn try_into_cmp_br_comparator(instr : @ir.Op) -> @ir.Comparator? {
  let comparator : @ir.Comparator = match instr {
    // i32
    BranchI32Eq(..) | BranchI32EqImm16(..) => @ir.Comparator::I32Eq
    BranchI32Ne(..) | BranchI32NeImm16(..) => @ir.Comparator::I32Ne
    BranchI32LtS(..) | BranchI32LtSImm16Lhs(..) | BranchI32LtSImm16Rhs(..) =>
      @ir.Comparator::I32LtS
    BranchI32LtU(..) | BranchI32LtUImm16Lhs(..) | BranchI32LtUImm16Rhs(..) =>
      @ir.Comparator::I32LtU
    BranchI32LeS(..) | BranchI32LeSImm16Lhs(..) | BranchI32LeSImm16Rhs(..) =>
      @ir.Comparator::I32LeS
    BranchI32LeU(..) | BranchI32LeUImm16Lhs(..) | BranchI32LeUImm16Rhs(..) =>
      @ir.Comparator::I32LeU
    // i32 (and,or,xor)
    BranchI32And(..) => @ir.Comparator::I32And
    BranchI32Or(..) => @ir.Comparator::I32Or
    BranchI32Nand(..) => @ir.Comparator::I32Nand
    BranchI32Nor(..) => @ir.Comparator::I32Nor
    // i64
    BranchI64Eq(..) | BranchI64EqImm16(..) => @ir.Comparator::I64Eq
    BranchI64Ne(..) | BranchI64NeImm16(..) => @ir.Comparator::I64Ne
    BranchI64LtS(..) | BranchI64LtSImm16Lhs(..) | BranchI64LtSImm16Rhs(..) =>
      @ir.Comparator::I64LtS
    BranchI64LtU(..) | BranchI64LtUImm16Lhs(..) | BranchI64LtUImm16Rhs(..) =>
      @ir.Comparator::I64LtU
    BranchI64LeS(..) | BranchI64LeSImm16Lhs(..) | BranchI64LeSImm16Rhs(..) =>
      @ir.Comparator::I64LeS
    BranchI64LeU(..) | BranchI64LeUImm16Lhs(..) | BranchI64LeUImm16Rhs(..) =>
      @ir.Comparator::I64LeU
    // f32
    BranchF32Eq(..) => @ir.Comparator::F32Eq
    BranchF32Ne(..) => @ir.Comparator::F32Ne
    BranchF32Lt(..) => @ir.Comparator::F32Lt
    BranchF32Le(..) => @ir.Comparator::F32Le
    BranchF32NotLt(..) => @ir.Comparator::F32NotLt
    BranchF32NotLe(..) => @ir.Comparator::F32NotLe
    // f64
    BranchF64Eq(..) => @ir.Comparator::F64Eq
    BranchF64Ne(..) => @ir.Comparator::F64Ne
    BranchF64Lt(..) => @ir.Comparator::F64Lt
    BranchF64Le(..) => @ir.Comparator::F64Le
    BranchF64NotLt(..) => @ir.Comparator::F64NotLt
    BranchF64NotLe(..) => @ir.Comparator::F64NotLe
    _ => return None
  }
  Some(comparator)
}

///|
/// Updates the [`BranchOffset`] of a branch instruction to `new_offset`,
/// returning the updated instruction (upstream
/// `UpdateBranchOffset::update_branch_offset`).
///
/// # Note
///
/// Converts a cmp+branch instruction into its fallback variant if
/// `new_offset` does not fit into 16 bits.
pub fn[S : AllocConst] update_branch_offset(
  instr : @ir.Op,
  stack : S,
  new_offset : @ir.BranchOffset,
) -> @ir.Op raise WasmiError {
  match instr {
    Branch(offset~) => return Branch(offset=offset.init(new_offset))
    BranchTableTarget(results~, offset~) =>
      return BranchTableTarget(results~, offset=offset.init(new_offset))
    _ => ()
  }
  guard instr.branch_offset16() is Some(offset) else {
    abort(
      "expected a Wasmi `cmp`+`branch` instruction but found: \{instr.name()}",
    )
  }
  let updated = try? offset.init(new_offset)
  match updated {
    Ok(offset16) =>
      match instr.set_branch_offset16(offset16) {
        Some(instr) => instr
        None => abort("unreachable")
      }
    Err(_) => {
      // Case: we need to convert `self` into its cmp+branch fallback instruction variant
      //       since adjusting the 16-bit offset failed.
      guard try_into_cmp_branch_fallback_instr(instr, new_offset, stack)
        is Some(fallback) else {
        abort(
          "failed to create cmp+branch fallback instruction for: \{instr.name()}",
        )
      }
      fallback
    }
  }
}
