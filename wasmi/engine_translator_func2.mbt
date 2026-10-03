// Port of wasmi 1.0.9 `engine/translator/func/mod.rs` (part 2: fused
// cmp+branch, generic unary/binary translation, memory access).
//
// Upstream's generic routines are parameterized by Rust types `T`/`R`
// (`i32`, `u32`, `i64`, `u64`, `f32`, `f64`, `bool`) implementing traits such
// as `WasmInteger`, `TryInto<Const16<T>>` or `IntoShiftAmount`. Here values
// stay `TypedVal`s and the type is given as a [`NumTy`] descriptor.

///|
/// The Rust type `T` of a generic upstream translation routine.
pub(all) enum NumTy {
  I32
  U32
  I64
  U64
  F32
  F64
} derive(Eq, Debug)

///|
/// Upstream `<T as Typed>::TY`.
pub fn NumTy::val_type(self : NumTy) -> @wasmi_core.ValType {
  match self {
    I32 | U32 => I32
    I64 | U64 => I64
    F32 => F32
    F64 => F64
  }
}

///|
/// Upstream `TryInto<Const16<T>>` (also for `NonZero<T>`).
pub fn NumTy::const16(self : NumTy, value : @wasmi_core.TypedVal) -> @ir.Const16? {
  match self {
    I32 => @ir.Const16::try_from_i32(value.to_i32())
    U32 => @ir.Const16::try_from_u32(value.to_u32())
    I64 => @ir.Const16::try_from_i64(value.to_i64())
    U64 => @ir.Const16::try_from_u64(value.to_u64())
    F32 | F64 => None
  }
}

///|
/// Upstream `WasmInteger::is_zero`.
pub fn NumTy::is_zero(self : NumTy, value : @wasmi_core.TypedVal) -> Bool {
  match self {
    I32 | U32 => value.to_i32() == 0
    I64 | U64 => value.to_i64() == 0L
    F32 | F64 => abort("not an integer type")
  }
}

///|
/// Upstream `WasmInteger::wrapping_neg`.
pub fn NumTy::wrapping_neg(
  self : NumTy,
  value : @wasmi_core.TypedVal,
) -> @wasmi_core.TypedVal {
  match self {
    I32 => @wasmi_core.TypedVal::from_i32(0 - value.to_i32())
    U32 => @wasmi_core.TypedVal::from_u32(0U - value.to_u32())
    I64 => @wasmi_core.TypedVal::from_i64(0L - value.to_i64())
    U64 => @wasmi_core.TypedVal::from_u64(0UL - value.to_u64())
    F32 | F64 => abort("not an integer type")
  }
}

///|
/// Upstream `IntoShiftAmount::into_shift_amount` for `T`.
pub fn NumTy::shift_amount(
  self : NumTy,
  value : @wasmi_core.TypedVal,
) -> @ir.ShiftAmount? {
  match self {
    I32 => @ir.ShiftAmount::of_i32(value.to_i32())
    I64 => @ir.ShiftAmount::of_i64(value.to_i64())
    U32 => @ir.ShiftAmount::of_u32(value.to_u32(), 32)
    U64 => @ir.ShiftAmount::of_u32(value.to_u32(), 64)
    F32 | F64 => abort("not an integer type")
  }
}

///|
/// The `f32` bits of a [`TypedVal`].
fn typed_f32_bits(value : @wasmi_core.TypedVal) -> UInt {
  value.untyped().to_bits64().to_uint()
}

///|
/// The `f64` bits of a [`TypedVal`].
fn typed_f64_bits(value : @wasmi_core.TypedVal) -> UInt64 {
  value.untyped().to_bits64()
}

///|
/// A unary constant evaluation function.
pub type ConstEval1 = (@wasmi_core.TypedVal) -> @wasmi_core.TypedVal raise @wasmi_core.TrapCode

///|
/// A binary constant evaluation function.
pub type ConstEval2 = (@wasmi_core.TypedVal, @wasmi_core.TypedVal) -> @wasmi_core.TypedVal raise @wasmi_core.TrapCode

///|
/// Tries to fuse a compare instruction with a Wasm `br_if`.
fn FuncTranslator::try_fuse_branch_cmp(
  self : FuncTranslator,
  condition : Operand,
  label : LabelRef,
  negate : Bool,
) -> Bool raise WasmiError {
  guard self.instrs.last_instr() is Some(last_instr) else {
    // Case: cannot fuse without a known last instruction
    return false
  }
  guard condition is Temp(condition) else {
    // Case: cannot fuse non-temporary operands
    //  - locals have observable behavior.
    //  - immediates cannot be the result of a previous instruction.
    return false
  }
  guard condition.instr() is Some(origin) else {
    // Case: cannot fuse temporary operands without origin instruction
    return false
  }
  if last_instr != origin {
    // Case: cannot fuse if last instruction does not match origin instruction
    return false
  }
  let fused_instr = self.try_make_fused_branch_cmp_instr(
    origin, condition, label, negate,
  )
  guard fused_instr is Some(fused_instr) else {
    // Case: not possible to perform fusion with last instruction
    return false
  }
  if !self.instrs.try_replace_instr(origin, fused_instr) {
    abort("op-code fusion must suceed at this point")
  }
  true
}

///|
/// Try to return a fused cmp+branch [`Op`] from the given parameters.
///
/// # Note
///
/// - The `instr` parameter refers to the to-be-fused cmp instruction.
/// - Returns `Ok(Some)` if cmp+branch fusion was successful.
/// - Returns `Ok(None)`, otherwise.
fn FuncTranslator::try_make_fused_branch_cmp_instr(
  self : FuncTranslator,
  instr : Instr,
  condition : TempOperand,
  label : LabelRef,
  negate : Bool,
) -> @ir.Op? raise WasmiError {
  let cmp_instr = self.instrs.get(instr)
  guard compare_result(cmp_instr) is Some(result) else {
    // Note: cannot fuse non-cmp instructions or cmp-instructions without result.
    return None
  }
  if self.layout.stack_space(result) is Local {
    // Note: cannot fuse cmp instructions with observable semantics.
    return None
  }
  if result != self.layout.temp_to_reg(condition.operand_index()) {
    // Note: cannot fuse cmp instruction with a result that differs
    //       from the condition operand.
    return None
  }
  let cmp_instr = if negate {
    match negate_cmp_instr(cmp_instr) {
      Some(negated) => negated
      None =>
        // Note: cannot negate cmp instruction, thus not possible to fuse.
        return None
    }
  } else {
    cmp_instr
  }
  let offset = self.labels.try_resolve_label(label, instr)
  guard try_into_cmp_branch_instr(cmp_instr, offset, self.layout)
    is Some(fused) else {
    abort("cmp+branch fusion must succeed")
  }
  Some(fused)
}

///|
/// Translates a unary Wasm instruction to Wasmi bytecode.
fn FuncTranslator::translate_unary(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Slot) -> @ir.Op,
  consteval : ConstEval1,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let input = self.stack.pop()
  if input is Immediate(input) {
    let value = consteval(input.val()) catch {
      _ => abort("infallible unary consteval trapped")
    }
    self.stack.push_immediate(value) |> ignore
    return
  }
  let input = self.layout.operand_to_reg(input)
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr(result, input) },
    fuel_base,
  )
}

///|
/// Translates a fallible unary Wasm instruction to Wasmi bytecode.
fn FuncTranslator::translate_unary_fallible(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Slot) -> @ir.Op,
  consteval : ConstEval1,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let input = self.stack.pop()
  if input is Immediate(input) {
    let input = input.val()
    match (try? consteval(input)) {
      Ok(result) => self.stack.push_immediate(result) |> ignore
      Err(trap) => self.translate_trap(trap)
    }
    return
  }
  let input = self.layout.operand_to_reg(input)
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr(result, input) },
    fuel_base,
  )
}

///|
/// Translate a generic Wasm reinterpret-like operation.
///
/// # Note
///
/// This Wasm operation is a no-op. Ideally we only have to change the types on the stack.
fn FuncTranslator::translate_reinterpret(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  consteval : ConstEval1,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  match self.stack.pop() {
    Local(input) => self.stack.push_local(input.local_index(), result_ty) |> ignore
    Temp(_) => self.stack.push_temp(result_ty, None) |> ignore
    Immediate(input) => {
      let value = consteval(input.val()) catch {
        _ => abort("infallible reinterpret trapped")
      }
      self.stack.push_immediate(value) |> ignore
    }
  }
}

///|
/// Creates an [`Input16`] from the given `value`.
pub fn FuncTranslator::make_imm16(
  self : FuncTranslator,
  ty : NumTy,
  value : @wasmi_core.TypedVal,
) -> Input[@ir.Const16] raise WasmiError {
  match ty.const16(value) {
    Some(rhs) => Immediate(rhs)
    None => {
      let rhs = self.layout.const_to_reg(value.untyped())
      Slot(rhs)
    }
  }
}

///|
/// Converts the `operand` into an [`Input`], using `f` for immediates.
fn[R] FuncTranslator::make_input(
  self : FuncTranslator,
  operand : Operand,
  f : (FuncTranslator, @wasmi_core.TypedVal) -> Input[R] raise WasmiError,
) -> Input[R] raise WasmiError {
  let reg = match operand {
    Local(operand) => self.layout.local_to_reg(operand.local_index())
    Temp(operand) => self.layout.temp_to_reg(operand.operand_index())
    Immediate(operand) => return f(self, operand.val())
  }
  Slot(reg)
}

///|
/// Converts the `operand` (a 32-bit or 64-bit index) into a 16-bit index input.
pub fn FuncTranslator::make_index16(
  self : FuncTranslator,
  operand : Operand,
  index_type : @wasmi_core.IndexType,
) -> Input[@ir.Const16] raise WasmiError {
  let value = match operand {
    Immediate(value) => value.val()
    operand => {
      let reg = self.layout.operand_to_reg(operand)
      return Slot(reg)
    }
  }
  match index_type {
    I64 =>
      if @ir.Const16::try_from_u64(value.to_u64()) is Some(value) {
        return Immediate(value)
      }
    I32 =>
      if @ir.Const16::try_from_u32(value.to_u32()) is Some(value) {
        return Immediate(value.cast())
      }
  }
  let reg = self.layout.const_to_reg(value.untyped())
  Slot(reg)
}

///|
/// Converts the `operand` (a 32-bit or 64-bit index) into a 32-bit index input.
pub fn FuncTranslator::make_index32(
  self : FuncTranslator,
  operand : Operand,
  index_type : @wasmi_core.IndexType,
) -> Input[@ir.Const32] raise WasmiError {
  let value = match operand {
    Immediate(value) => value.val()
    operand => {
      let reg = self.layout.operand_to_reg(operand)
      return Slot(reg)
    }
  }
  match index_type {
    I64 =>
      if @ir.Const32::try_from_u64(value.to_u64()) is Some(value) {
        return Immediate(value)
      }
    I32 => {
      let value32 = @ir.Const32::from_u32(value.to_u32())
      return Immediate(value32.cast())
    }
  }
  let reg = self.layout.const_to_reg(value.untyped())
  Slot(reg)
}

///|
/// Evaluates the constants and pushes the proper result to the value stack.
fn FuncTranslator::translate_binary_consteval_fallible(
  self : FuncTranslator,
  lhs : ImmediateOperand,
  rhs : ImmediateOperand,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  let lhs = lhs.val()
  let rhs = rhs.val()
  match (try? consteval(lhs, rhs)) {
    Ok(value) => self.stack.push_immediate(value) |> ignore
    Err(trap) => self.translate_trap(trap)
  }
}

///|
/// Evaluates the constants and pushes the proper result to the value stack.
fn FuncTranslator::translate_binary_consteval(
  self : FuncTranslator,
  lhs : ImmediateOperand,
  rhs : ImmediateOperand,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  self.translate_binary_consteval_fallible(lhs, rhs, consteval)
}

///|
/// Upstream `no_opt_ri`: no optimization for `(reg, imm)` operands.
fn no_opt_ri(
  _self : FuncTranslator,
  _lhs : Operand,
  _rhs : @wasmi_core.TypedVal,
) -> Bool raise WasmiError {
  false
}

///|
/// Translates a commutative binary Wasm operator to Wasmi bytecode.
fn FuncTranslator::translate_binary_commutative(
  self : FuncTranslator,
  ty : NumTy,
  result_ty : @wasmi_core.ValType,
  make_rr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_ri : (@ir.Slot, @ir.Slot, @ir.Const16) -> @ir.Op,
  consteval : ConstEval2,
  opt_ri : (FuncTranslator, Operand, @wasmi_core.TypedVal) -> Bool raise WasmiError,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  match self.stack.pop2() {
    (Immediate(lhs), Immediate(rhs)) =>
      self.translate_binary_consteval(lhs, rhs, consteval)
    (val, Immediate(imm)) | (Immediate(imm), val) => {
      let rhs = imm.val()
      if opt_ri(self, val, rhs) {
        return
      }
      let lhs = self.layout.operand_to_reg(val)
      let rhs16 = self.make_imm16(ty, rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match rhs16 {
            Immediate(rhs) => make_ri(result, lhs, rhs)
            Slot(rhs) => make_rr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (lhs, rhs) =>
      self.push_binary_instr_with_result(result_ty, lhs, rhs, make_rr, fuel_base)
  }
}

///|
/// Translates integer division and remainder Wasm operators to Wasmi bytecode.
fn FuncTranslator::translate_divrem(
  self : FuncTranslator,
  ty : NumTy,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_instr_imm16_rhs : (@ir.Slot, @ir.Slot, @ir.Const16) -> @ir.Op,
  make_instr_imm16_lhs : (@ir.Slot, @ir.Const16, @ir.Slot) -> @ir.Op,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let result_ty = ty.val_type()
  match self.stack.pop2() {
    (Immediate(lhs), Immediate(rhs)) =>
      self.translate_binary_consteval_fallible(lhs, rhs, consteval)
    (lhs, Immediate(rhs)) => {
      let lhs = self.layout.operand_to_reg(lhs)
      let rhs = rhs.val()
      if ty.is_zero(rhs) {
        // Optimization: division by zero always traps
        return self.translate_trap(IntegerDivisionByZero)
      }
      let rhs16 = self.make_imm16(ty, rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match rhs16 {
            Immediate(rhs) => make_instr_imm16_rhs(result, lhs, rhs)
            Slot(rhs) => make_instr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (Immediate(lhs), rhs) => {
      let lhs = lhs.val()
      let lhs16 = self.make_imm16(ty, lhs)
      let rhs = self.layout.operand_to_reg(rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match lhs16 {
            Immediate(lhs) => make_instr_imm16_lhs(result, lhs, rhs)
            Slot(lhs) => make_instr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (lhs, rhs) =>
      self.push_binary_instr_with_result(
        result_ty, lhs, rhs, make_instr, fuel_base,
      )
  }
}

///|
/// Translates binary non-commutative Wasm operators to Wasmi bytecode.
fn FuncTranslator::translate_binary(
  self : FuncTranslator,
  ty : NumTy,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_instr_imm16_rhs : (@ir.Slot, @ir.Slot, @ir.Const16) -> @ir.Op,
  make_instr_imm16_lhs : (@ir.Slot, @ir.Const16, @ir.Slot) -> @ir.Op,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  match self.stack.pop2() {
    (Immediate(lhs), Immediate(rhs)) =>
      self.translate_binary_consteval(lhs, rhs, consteval)
    (lhs, Immediate(rhs)) => {
      let lhs = self.layout.operand_to_reg(lhs)
      let rhs = rhs.val()
      let rhs16 = self.make_imm16(ty, rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match rhs16 {
            Immediate(rhs) => make_instr_imm16_rhs(result, lhs, rhs)
            Slot(rhs) => make_instr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (Immediate(lhs), rhs) => {
      let lhs = lhs.val()
      let lhs16 = self.make_imm16(ty, lhs)
      let rhs = self.layout.operand_to_reg(rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match lhs16 {
            Immediate(lhs) => make_instr_imm16_lhs(result, lhs, rhs)
            Slot(lhs) => make_instr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (lhs, rhs) =>
      self.push_binary_instr_with_result(
        result_ty, lhs, rhs, make_instr, fuel_base,
      )
  }
}

///|
/// Translates Wasm integer subtraction.
///
/// # Note
///
/// Subtraction of a constant `rhs` is encoded as addition of `-rhs`.
fn FuncTranslator::translate_isub(
  self : FuncTranslator,
  ty : NumTy,
  make_sub_rr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_add_ri : (@ir.Slot, @ir.Slot, @ir.Const16) -> @ir.Op,
  make_sub_ir : (@ir.Slot, @ir.Const16, @ir.Slot) -> @ir.Op,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let result_ty = ty.val_type()
  match self.stack.pop2() {
    (Immediate(lhs), Immediate(rhs)) =>
      self.translate_binary_consteval(lhs, rhs, consteval)
    (lhs, Immediate(rhs)) => {
      let lhs = self.layout.operand_to_reg(lhs)
      let rhs = rhs.val()
      let rhs16 : Input[@ir.Const16] = match ty.const16(ty.wrapping_neg(rhs)) {
        Some(rhs) => Immediate(rhs)
        None => {
          let rhs = self.layout.const_to_reg(rhs.untyped())
          Slot(rhs)
        }
      }
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match rhs16 {
            Immediate(rhs) => make_add_ri(result, lhs, rhs)
            Slot(rhs) => make_sub_rr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (Immediate(lhs), rhs) => {
      let lhs = lhs.val()
      let lhs16 = self.make_imm16(ty, lhs)
      let rhs = self.layout.operand_to_reg(rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match lhs16 {
            Immediate(lhs) => make_sub_ir(result, lhs, rhs)
            Slot(lhs) => make_sub_rr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (lhs, rhs) =>
      self.push_binary_instr_with_result(
        result_ty, lhs, rhs, make_sub_rr, fuel_base,
      )
  }
}

///|
/// Translates a Wasm shift or rotate instruction to Wasmi bytecode.
fn FuncTranslator::translate_shift(
  self : FuncTranslator,
  ty : NumTy,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_instr_imm16_rhs : (@ir.Slot, @ir.Slot, @ir.ShiftAmount) -> @ir.Op,
  make_instr_imm16_lhs : (@ir.Slot, @ir.Const16, @ir.Slot) -> @ir.Op,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let result_ty = ty.val_type()
  match self.stack.pop2() {
    (Immediate(lhs), Immediate(rhs)) =>
      self.translate_binary_consteval(lhs, rhs, consteval)
    (lhs, Immediate(rhs)) => {
      guard ty.shift_amount(rhs.val()) is Some(rhs) else {
        // Optimization: Shifting or rotating by zero bits is a no-op.
        self.stack.push_operand(lhs) |> ignore
        return
      }
      let lhs = self.layout.operand_to_reg(lhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) { make_instr_imm16_rhs(result, lhs, rhs) },
        fuel_base,
      )
    }
    (Immediate(lhs), rhs) => {
      let lhs = lhs.val()
      if ty.is_zero(lhs) {
        // Optimization: Shifting or rotating a zero value is a no-op.
        self.stack.push_immediate(lhs) |> ignore
        return
      }
      let lhs16 = self.make_imm16(ty, lhs)
      let rhs = self.layout.operand_to_reg(rhs)
      self.push_instr_with_result(
        result_ty,
        fn(result) {
          match lhs16 {
            Immediate(lhs) => make_instr_imm16_lhs(result, lhs, rhs)
            Slot(lhs) => make_instr(result, lhs, rhs)
          }
        },
        fuel_base,
      )
    }
    (lhs, rhs) =>
      self.push_binary_instr_with_result(
        result_ty, lhs, rhs, make_instr, fuel_base,
      )
  }
}

///|
/// Translate a generic Wasm floating point binary operator.
fn FuncTranslator::translate_fbinary(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (lhs, rhs) = self.stack.pop2()
  if (lhs, rhs) is (Immediate(lhs), Immediate(rhs)) {
    return self.translate_binary_consteval(lhs, rhs, consteval)
  }
  self.push_binary_instr_with_result(result_ty, lhs, rhs, make_instr, fuel_base)
}

///|
/// Translate Wasm `{f32,f64}.copysign` instructions.
fn FuncTranslator::translate_fcopysign(
  self : FuncTranslator,
  ty : NumTy,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_instr_imm : (@ir.Slot, @ir.Slot, @ir.Sign) -> @ir.Op,
  consteval : ConstEval2,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let result_ty = ty.val_type()
  match self.stack.pop2() {
    (Immediate(lhs), Immediate(rhs)) =>
      self.translate_binary_consteval(lhs, rhs, consteval)
    (lhs, Immediate(rhs)) => {
      let lhs = self.layout.operand_to_reg(lhs)
      let sign = match ty {
        F32 => @ir.Sign::from_f32_bits(typed_f32_bits(rhs.val()))
        _ => @ir.Sign::from_f64_bits(typed_f64_bits(rhs.val()))
      }
      self.push_instr_with_result(
        result_ty,
        fn(result) { make_instr_imm(result, lhs, sign) },
        fuel_base,
      )
    }
    (lhs, rhs) => {
      if lhs.is_same(rhs) {
        // Optimization: `copysign x x` is always just `x`
        self.stack.push_operand(lhs) |> ignore
        return
      }
      self.push_binary_instr_with_result(
        result_ty, lhs, rhs, make_instr, fuel_base,
      )
    }
  }
}

///|
/// Translates a Wasm `trap` (or an always-trapping operation).
fn FuncTranslator::translate_trap(
  self : FuncTranslator,
  trap : @wasmi_core.TrapCode,
) -> Unit raise WasmiError {
  self.push_instr(@ir.Op::trap(trap), fuel_base) |> ignore
  self.reachable = false
}

///|
/// Translates a Wasm `select` or `select <ty>` instruction.
fn FuncTranslator::translate_select(
  self : FuncTranslator,
  _type_hint : @wasmi_core.ValType?,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (true_val, false_val, condition) = self.stack.pop3()
  let ty = true_val.ty()
  if true_val.is_same(false_val) {
    // Optimization: both `lhs` and `rhs` either are the same register or constant values and
    //               thus `select` will always yield this same value irrespective of the condition.
    self.stack.push_operand(true_val) |> ignore
    return
  }
  if condition is Immediate(condition) {
    // Optimization: since condition is a constant value we can const-fold the `select`
    //               instruction and simply push the selected value back to the provider stack.
    let condition = condition.val().to_i32() != 0
    let selected = if condition { true_val } else { false_val }
    if selected is Temp(selected) {
      // Case: the selected operand is a temporary which needs to be copied
      //       if it was the `false_val` since it changed its index. This is
      //       not the case for the `true_val` since `true_val` is the first
      //       value popped from the stack.
      if !condition {
        let selected = self.layout.temp_to_reg(selected.operand_index())
        self.push_instr_with_result(
          ty,
          fn(result) { @ir.Op::copy(result, selected) },
          fuel_base,
        )
        return
      }
    }
    self.stack.push_operand(selected) |> ignore
    return
  }
  let condition = self.layout.operand_to_reg(condition)
  let mut true_val = self.immediate_to_reg(true_val)
  let mut false_val = self.immediate_to_reg(false_val)
  match self.instrs.try_fuse_select(ty, condition, self.layout, self.stack) {
    Some(swap_operands) =>
      if swap_operands {
        let t = true_val
        true_val = false_val
        false_val = t
      }
    None => {
      self.push_instr_with_result(
        ty,
        fn(result) {
          @ir.Op::select_i32_eq_imm16(result, condition, @ir.Const16::from_i16(0))
        },
        fuel_base,
      )
      let t = true_val
      true_val = false_val
      false_val = t
    }
  }
  self.push_param(@ir.Op::slot2_ext(true_val, false_val))
}

///|
/// Create either [`Op::CallIndirectParams`] or [`Op::CallIndirectParamsImm16`]
/// depending on the inputs.
fn FuncTranslator::call_indirect_params(
  self : FuncTranslator,
  index : Operand,
  table_index : UInt,
) -> @ir.Op raise WasmiError {
  let table_type = self.module.get_type_of_table(
    TableIdx(table_index.reinterpret_as_int()),
  )
  let index = self.make_index16(index, table_type.index_ty())
  match index {
    Slot(index) =>
      @ir.Op::call_indirect_params(
        index,
        @ir.Table(table_index.reinterpret_as_int()),
      )
    Immediate(index) =>
      @ir.Op::call_indirect_params_imm16(
        index,
        @ir.Table(table_index.reinterpret_as_int()),
      )
  }
}

///|
/// Tries to fuse a Wasm `i32.eqz` (or `i32.eq` with 0 `rhs` value) instruction.
pub fn FuncTranslator::fuse_eqz(
  self : FuncTranslator,
  lhs : Operand,
  rhs : @wasmi_core.TypedVal,
) -> Bool raise WasmiError {
  self.fuse_commutative_cmp_with(lhs, rhs, negate_cmp_instr)
}

///|
/// Tries to fuse a Wasm `i32.ne` instruction with 0 `rhs` value.
pub fn FuncTranslator::fuse_nez(
  self : FuncTranslator,
  lhs : Operand,
  rhs : @wasmi_core.TypedVal,
) -> Bool raise WasmiError {
  self.fuse_commutative_cmp_with(lhs, rhs, logicalize_cmp_instr)
}

///|
/// Tries to fuse a `i{32,64}`.{eq,ne}` instruction with `rhs` of zero.
///
/// Returns `true` if fusion was successful, `false` otherwise.
fn FuncTranslator::fuse_commutative_cmp_with(
  self : FuncTranslator,
  lhs : Operand,
  rhs : @wasmi_core.TypedVal,
  try_fuse : (@ir.Op) -> @ir.Op?,
) -> Bool raise WasmiError {
  if rhs.untyped().to_bits64() != 0UL {
    // Case: cannot fuse with non-zero `rhs`
    return false
  }
  guard self.instrs.last_instr() is Some(last_instr) else {
    // Case: cannot fuse without registered last instruction
    return false
  }
  guard lhs is Temp(lhs) else {
    // Case: cannot fuse non-temporary operands
    //  - locals have observable behavior.
    //  - immediates cannot be the result of a previous instruction.
    return false
  }
  guard lhs.instr() is Some(origin) else {
    // Case: `lhs` has no origin instruciton, thus not possible to fuse.
    return false
  }
  if origin != last_instr {
    // Case: `lhs`'s origin instruction does not match the last instruction
    return false
  }
  let lhs_reg = self.layout.temp_to_reg(lhs.operand_index())
  let last_instruction = self.instrs.get(last_instr)
  guard compare_result(last_instruction) is Some(result) else {
    // Case: cannot fuse non-cmp instructions
    return false
  }
  if result != lhs_reg {
    // Case: the `cmp` instruction does not feed into the `eqz` and cannot be fused
    return false
  }
  guard try_fuse(last_instruction) is Some(negated) else {
    // Case: the `cmp` instruction cannot be negated
    return false
  }
  // Need to push back `lhs` but with its type adjusted to be `i32`
  // since that's the return type of `i{32,64}.{eqz,eq,ne}`.
  let result_idx = self.stack.push_temp(I32, lhs.instr())
  // Need to replace `cmp` instruction result register since it might
  // have been misaligned if `lhs` originally referred to the zero operand.
  let new_result = self.layout.temp_to_reg(result_idx)
  guard replace_cmp_result(negated, new_result) is Some(negated) else {
    abort("`negated` has been asserted as `cmp` instruction")
  }
  if !self.instrs.try_replace_instr(last_instr, negated) {
    abort("`negated` has been asserted to be `last_instr`")
  }
  true
}

///|
/// Translates a Wasm `load` instruction to Wasmi bytecode.
fn FuncTranslator::translate_load(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  loaded_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Offset64Lo) -> @ir.Op,
  make_instr_offset16 : (@ir.Slot, @ir.Slot, @ir.Offset16) -> @ir.Op,
  make_instr_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (memory, offset) = FuncTranslator::decode_memarg(memarg)
  let ptr = self.stack.pop()
  let (ptr, offset) = match ptr {
    Immediate(ptr) => {
      let ptr = ptr.val()
      guard self.effective_address(memory, ptr, offset) is Some(address) else {
        return self.translate_trap(MemoryOutOfBounds)
      }
      if @ir.Address32::try_from_address(address) is Some(address) {
        self.push_instr_with_result(
          loaded_ty,
          fn(result) { make_instr_at(result, address) },
          fuel_load,
        )
        if !memory.is_default() {
          self.push_param(@ir.Op::memory_index(memory))
        }
        return
      }
      // Case: we cannot use specialized encoding and thus have to fall back
      //       to the general case where `ptr` is zero and `offset` stores the
      //       `ptr+offset` address value.
      let zero_ptr = self.layout.const_to_reg(@wasmi_core.UntypedVal::from_u64(0))
      (zero_ptr, address.to_u64())
    }
    ptr => {
      let ptr = self.layout.operand_to_reg(ptr)
      (ptr, offset)
    }
  }
  if memory.is_default() {
    if @ir.Offset16::try_from_u64(offset) is Some(offset) {
      self.push_instr_with_result(
        loaded_ty,
        fn(result) { make_instr_offset16(result, ptr, offset) },
        fuel_load,
      )
      return
    }
  }
  let (offset_hi, offset_lo) = @ir.Offset64::split(offset)
  self.push_instr_with_result(
    loaded_ty,
    fn(result) { make_instr(result, offset_lo) },
    fuel_load,
  )
  self.push_param(@ir.Op::slot_and_offset_hi(ptr, offset_hi))
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
/// Upstream `FuelCostsProvider::load`.
fn fuel_load(costs : @wasmi_core.FuelCostsProvider) -> UInt64 {
  costs.load()
}

///|
/// Upstream `FuelCostsProvider::store`.
fn fuel_store(costs : @wasmi_core.FuelCostsProvider) -> UInt64 {
  costs.store()
}

///|
/// Upstream `T::Param::try_from(T::Value::from(value).wrap())`: the store
/// immediate if the (wrapped) `value` fits the operator's immediate type.
fn store_param_of(
  op : StoreWrapOperator,
  value : @wasmi_core.TypedVal,
) -> Int? {
  match op.kind {
    I32 => {
      let v = value.to_i32()
      if v >= -32768 && v <= 32767 {
        Some(v)
      } else {
        None
      }
    }
    I64 => {
      let v = value.to_i64()
      if v >= -32768L && v <= 32767L {
        Some(v.to_int())
      } else {
        None
      }
    }
    I32Wrap8 => Some(((value.to_i32() & 0xFF) << 24) >> 24)
    I32Wrap16 => Some(((value.to_i32() & 0xFFFF) << 16) >> 16)
    I64Wrap8 => Some(((value.to_i64().to_int() & 0xFF) << 24) >> 24)
    I64Wrap16 => Some(((value.to_i64().to_int() & 0xFFFF) << 16) >> 16)
    I64Wrap32 => {
      let v = value.to_i64().to_int()
      if v >= -32768 && v <= 32767 {
        Some(v)
      } else {
        None
      }
    }
  }
}

///|
/// Upstream `Into<AnyConst16>` of the store operator's `Param` type.
fn store_param_any16(op : StoreWrapOperator, value : Int) -> @ir.AnyConst16 {
  match op.kind {
    I32Wrap8 | I64Wrap8 => @ir.AnyConst16::from_i8(value)
    _ => @ir.AnyConst16::from_i16(value)
  }
}

///|
/// Translates Wasm integer `store` and `storeN` instructions to Wasmi bytecode.
fn FuncTranslator::translate_istore_wrap(
  self : FuncTranslator,
  op : StoreWrapOperator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (ptr, value) = self.stack.pop2()
  self.encode_istore_wrap(op, memarg, ptr, value)
}

///|
/// Encodes Wasm integer `store` and `storeN` instructions as Wasmi bytecode.
fn FuncTranslator::encode_istore_wrap(
  self : FuncTranslator,
  op : StoreWrapOperator,
  memarg : @wasmparser.MemArg,
  ptr : Operand,
  value : Operand,
) -> Unit raise WasmiError {
  let (memory, offset) = FuncTranslator::decode_memarg(memarg)
  let (ptr, offset) = match ptr {
    Immediate(ptr) => {
      let ptr = ptr.val()
      guard self.effective_address(memory, ptr, offset) is Some(address) else {
        return self.translate_trap(MemoryOutOfBounds)
      }
      if @ir.Address32::try_from_address(address) is Some(address) {
        return self.encode_istore_wrap_at(op, memory, address, value)
      }
      // Case: we cannot use specialized encoding and thus have to fall back
      //       to the general case where `ptr` is zero and `offset` stores the
      //       `ptr+offset` address value.
      let zero_ptr = self.layout.const_to_reg(@wasmi_core.UntypedVal::from_u64(0))
      (zero_ptr, address.to_u64())
    }
    ptr => {
      let ptr = self.layout.operand_to_reg(ptr)
      (ptr, offset)
    }
  }
  if memory.is_default() {
    if self.encode_istore_wrap_mem0(op, ptr, offset, value) is Some(_instr) {
      return
    }
  }
  let (offset_hi, offset_lo) = @ir.Offset64::split(offset)
  let (instr, param) = match value {
    Immediate(value) => {
      let value = value.val()
      match store_param_of(op, value) {
        Some(param) =>
          (
            (op.store_imm)(ptr, offset_lo),
            @ir.Op::imm16_and_offset_hi(store_param_any16(op, param), offset_hi),
          )
        None =>
          (
            (op.store)(ptr, offset_lo),
            @ir.Op::slot_and_offset_hi(
              self.layout.const_to_reg(value.untyped()),
              offset_hi,
            ),
          )
      }
    }
    value => {
      let value = self.layout.operand_to_reg(value)
      ((op.store)(ptr, offset_lo), @ir.Op::slot_and_offset_hi(value, offset_hi))
    }
  }
  self.push_instr(instr, fuel_store) |> ignore
  self.push_param(param)
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
/// Encodes a Wasm `store` instruction with immediate address as Wasmi bytecode.
fn FuncTranslator::encode_istore_wrap_at(
  self : FuncTranslator,
  op : StoreWrapOperator,
  memory : @ir.Memory,
  address : @ir.Address32,
  value : Operand,
) -> Unit raise WasmiError {
  match value {
    Immediate(value) => {
      let value = value.val()
      match store_param_of(op, value) {
        Some(param) => self.push_instr((op.store_at_imm)(param, address), fuel_store) |> ignore
        None => {
          let value = self.layout.const_to_reg(value.untyped())
          self.push_instr((op.store_at)(value, address), fuel_store) |> ignore
        }
      }
    }
    value => {
      let value = self.layout.operand_to_reg(value)
      self.push_instr((op.store_at)(value, address), fuel_store) |> ignore
    }
  }
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
/// Encodes a Wasm `store` instruction for the default memory with a 16-bit offset.
///
/// Returns `None` if the `offset` does not fit 16 bits.
fn FuncTranslator::encode_istore_wrap_mem0(
  self : FuncTranslator,
  op : StoreWrapOperator,
  ptr : @ir.Slot,
  offset : UInt64,
  value : Operand,
) -> Instr? raise WasmiError {
  guard @ir.Offset16::try_from_u64(offset) is Some(offset16) else {
    return None
  }
  let instr = match value {
    Immediate(value) => {
      let value = value.val()
      match store_param_of(op, value) {
        Some(param) =>
          self.push_instr((op.store_offset16_imm)(ptr, offset16, param), fuel_store)
        None => {
          let value = self.layout.const_to_reg(value.untyped())
          self.push_instr((op.store_offset16)(ptr, offset16, value), fuel_store)
        }
      }
    }
    value => {
      let value = self.layout.operand_to_reg(value)
      self.push_instr((op.store_offset16)(ptr, offset16, value), fuel_store)
    }
  }
  Some(instr)
}

///|
/// Translates a general Wasm `store` instruction to Wasmi bytecode.
///
/// # Note
///
/// This chooses the most efficient encoding for the given `store` instruction.
/// If `ptr+offset` is a constant value the address is pre-calculated.
fn FuncTranslator::translate_store(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  store : (@ir.Slot, @ir.Offset64Lo) -> @ir.Op,
  store_offset16 : (@ir.Slot, @ir.Offset16, @ir.Slot) -> @ir.Op,
  store_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (memory, offset) = FuncTranslator::decode_memarg(memarg)
  let (ptr, value) = self.stack.pop2()
  let (ptr, offset) = match ptr {
    Immediate(ptr) => {
      guard self.effective_address(memory, ptr.val(), offset) is Some(address) else {
        return self.translate_trap(MemoryOutOfBounds)
      }
      if @ir.Address32::try_from_address(address) is Some(address) {
        return self.encode_fstore_at(memory, address, value, store_at)
      }
      let zero_ptr = self.layout.const_to_reg(@wasmi_core.UntypedVal::from_u64(0))
      (zero_ptr, address.to_u64())
    }
    ptr => {
      let ptr = self.layout.operand_to_reg(ptr)
      (ptr, offset)
    }
  }
  let (offset_hi, offset_lo) = @ir.Offset64::split(offset)
  let value = self.layout.operand_to_reg(value)
  if memory.is_default() {
    if @ir.Offset16::try_from_u64(offset) is Some(offset) {
      self.push_instr(store_offset16(ptr, offset, value), fuel_store) |> ignore
      return
    }
  }
  self.push_instr(store(ptr, offset_lo), fuel_store) |> ignore
  self.push_param(@ir.Op::slot_and_offset_hi(value, offset_hi))
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
/// Encodes a Wasm `store` instruction with immediate address.
fn FuncTranslator::encode_fstore_at(
  self : FuncTranslator,
  memory : @ir.Memory,
  address : @ir.Address32,
  value : Operand,
  make_instr_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
) -> Unit raise WasmiError {
  let value = self.layout.operand_to_reg(value)
  self.push_instr(make_instr_at(value, address), fuel_store) |> ignore
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
/// Returns the linear `memory` index and `offset` of the `memarg`.
fn FuncTranslator::decode_memarg(memarg : @wasmparser.MemArg) -> (@ir.Memory, UInt64) {
  let memory = @ir.Memory(memarg.memory.reinterpret_as_int())
  (memory, memarg.offset)
}

///|
/// Returns the effective address `ptr+offset` if it is valid.
fn FuncTranslator::effective_address(
  self : FuncTranslator,
  mem : @ir.Memory,
  ptr : @wasmi_core.TypedVal,
  offset : UInt64,
) -> @ir.Address? {
  let memory_type = self.module.get_type_of_memory(MemoryIdx(mem.0))
  let ptr = if memory_type.is_64() {
    ptr.to_u64()
  } else {
    ptr.to_u32().to_uint64()
  }
  let address = ptr + offset
  if address < ptr {
    // Case: address overflows any legal memory index.
    return None
  }
  if memory_type.maximum() is Some(max) {
    // The memory's maximum size in bytes.
    let max_size = max << memory_type.page_size_log2().to_int()
    if address > max_size {
      // Case: address overflows the memory's maximum size.
      return None
    }
  }
  if !memory_type.is_64() && address >= 0x1_0000_0000UL {
    // Case: address overflows the 32-bit memory index.
    return None
  }
  @ir.Address::try_from_u64(address)
}
