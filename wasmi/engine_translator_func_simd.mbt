// Port of wasmi 1.0.9 `engine/translator/func/simd/{mod,op}.rs` and the
// non-mechanical part of `simd/visit.rs`. The mechanical `visit_*` methods
// are in engine_translator_func_simd_visit.mbt.

///|
/// Upstream `FuelCostsProvider::simd`.
fn fuel_simd(costs : @wasmi_core.FuelCostsProvider) -> UInt64 {
  costs.simd()
}

///|
/// The lane type `T` of SIMD lane operations (upstream `IntoLaneIdx`).
pub(all) enum LaneTy {
  I8
  U8
  I16
  U16
  I32
  I64
  F32
  F64
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LaneTy with Eq::{not_equal, equal}

///|
/// The number of lanes of a [`LaneTy`].
fn LaneTy::lanes(self : LaneTy) -> Int {
  match self {
    I8 | U8 => 16
    I16 | U16 => 8
    I32 | F32 => 4
    I64 | F64 => 2
  }
}

///|
/// Upstream `<T::LaneIdx>::try_from(lane)`: checks the lane index.
fn LaneTy::lane_idx(self : LaneTy, lane : Int) -> @ir.ImmLaneIdx {
  if lane < 0 || lane >= self.lanes() {
    abort("encountered out of bounds lane index: \{lane}")
  }
  @ir.ImmLaneIdx(lane)
}

///|
/// Converts an immediate [`TypedVal`] into a [`V128`].
fn typed_v128(value : @wasmi_core.TypedVal) -> @wasmi_core.V128Value {
  value.untyped().read_v128()
}

///|
/// Converts a [`V128`] into an immediate [`TypedVal`].
fn v128_typed(value : @wasmi_core.V128Value) -> @wasmi_core.TypedVal {
  @wasmi_core.TypedVal::from_v128(value)
}

///|
/// Pushes `value` as an immediate and pops it back as [`Operand`].
fn FuncTranslator::immediate_to_operand(
  self : FuncTranslator,
  value : @wasmi_core.TypedVal,
) -> Operand raise WasmiError {
  self.stack.push_immediate(value) |> ignore
  self.stack.pop()
}

///|
/// Generically translate any of the Wasm `simd` splat instructions.
fn FuncTranslator::translate_simd_splat(
  self : FuncTranslator,
  make_instr : (@ir.Slot, @ir.Slot) -> @ir.Op,
  const_eval : (@wasmi_core.TypedVal) -> @wasmi_core.V128Value,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let value = self.stack.pop()
  if value is Immediate(value) {
    let result = const_eval(value.val())
    self.stack.push_immediate(v128_typed(result)) |> ignore
    return
  }
  let value = self.layout.operand_to_reg(value)
  self.push_instr_with_result(
    V128,
    fn(result) { make_instr(result, value) },
    fuel_simd,
  )
}

///|
/// Generically translate any of the Wasm `simd` extract lane instructions.
fn FuncTranslator::translate_extract_lane(
  self : FuncTranslator,
  lane_ty : LaneTy,
  lane : Int,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Slot, @ir.ImmLaneIdx) -> @ir.Op,
  const_eval : (@wasmi_core.V128Value, Int) -> @wasmi_core.TypedVal,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let lane = lane_ty.lane_idx(lane)
  let input = self.stack.pop()
  if input is Immediate(input) {
    let result = const_eval(typed_v128(input.val()), lane.0)
    self.stack.push_immediate(result) |> ignore
    return
  }
  let input = self.layout.operand_to_reg(input)
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr(result, input, lane) },
    fuel_simd,
  )
}

///|
/// A Wasm `replace_lane` operator (upstream `SimdReplaceLane`).
priv struct SimdReplaceLane {
  item_ty : LaneTy
  const_eval : (@wasmi_core.V128Value, Int, @wasmi_core.TypedVal) -> @wasmi_core.V128Value
  replace_lane : (@ir.Slot, @ir.Slot, @ir.ImmLaneIdx) -> @ir.Op
  replace_lane_imm : (@ir.Slot, @ir.Slot, @ir.ImmLaneIdx, @wasmi_core.TypedVal) -> @ir.Op
  replace_lane_imm_param : (@wasmi_core.TypedVal) -> @ir.Op?
  /// Upstream `value_to_imm`: whether the item value can be an immediate.
  value_to_imm : (@wasmi_core.TypedVal) -> Bool
}

///|
let i8x16_replace_lane_op : SimdReplaceLane = {
  item_ty: I8,
  const_eval: fn(input, lane, value) {
    @wasmi_core.i8x16_replace_lane(
      input,
      @wasmi_core.ImmLaneIdx16(lane.to_byte()),
      value.to_i32(),
    )
  },
  replace_lane: @ir.Op::i8x16_replace_lane,
  replace_lane_imm: fn(result, input, lane, value) {
    @ir.Op::i8x16_replace_lane_imm(
      result,
      input,
      lane,
      (value.to_i32() & 0xFF) << 24 >> 24,
    )
  },
  replace_lane_imm_param: fn(_) { None },
  value_to_imm: fn(_) { true },
}

///|
let i16x8_replace_lane_op : SimdReplaceLane = {
  item_ty: I16,
  const_eval: fn(input, lane, value) {
    @wasmi_core.i16x8_replace_lane(
      input,
      @wasmi_core.ImmLaneIdx8(lane.to_byte()),
      value.to_i32(),
    )
  },
  replace_lane: @ir.Op::i16x8_replace_lane,
  replace_lane_imm: fn(result, input, lane, _value) {
    @ir.Op::i16x8_replace_lane_imm(result, input, lane)
  },
  replace_lane_imm_param: fn(value) {
    Some(
      @ir.Op::const32(
        @ir.AnyConst32::from_i32((value.to_i32() & 0xFFFF) << 16 >> 16),
      ),
    )
  },
  value_to_imm: fn(_) { true },
}

///|
let i32x4_replace_lane_op : SimdReplaceLane = {
  item_ty: I32,
  const_eval: fn(input, lane, value) {
    @wasmi_core.i32x4_replace_lane(
      input,
      @wasmi_core.ImmLaneIdx4(lane.to_byte()),
      value.to_i32(),
    )
  },
  replace_lane: @ir.Op::i32x4_replace_lane,
  replace_lane_imm: fn(result, input, lane, _value) {
    @ir.Op::i32x4_replace_lane_imm(result, input, lane)
  },
  replace_lane_imm_param: fn(value) {
    Some(@ir.Op::const32(@ir.AnyConst32::from_i32(value.to_i32())))
  },
  value_to_imm: fn(_) { true },
}

///|
let i64x2_replace_lane_op : SimdReplaceLane = {
  item_ty: I64,
  const_eval: fn(input, lane, value) {
    @wasmi_core.i64x2_replace_lane(
      input,
      @wasmi_core.ImmLaneIdx2(lane.to_byte()),
      value.to_i64(),
    )
  },
  replace_lane: @ir.Op::i64x2_replace_lane,
  replace_lane_imm: fn(result, input, lane, _value) {
    @ir.Op::i64x2_replace_lane_imm32(result, input, lane)
  },
  replace_lane_imm_param: fn(value) {
    match @ir.Const32::try_from_i64(value.to_i64()) {
      Some(c) => Some(@ir.Op::i64const32(c))
      None => abort("unreachable")
    }
  },
  value_to_imm: fn(value) {
    @ir.Const32::try_from_i64(value.to_i64()) is Some(_)
  },
}

///|
let f32x4_replace_lane_op : SimdReplaceLane = {
  item_ty: F32,
  const_eval: fn(input, lane, value) {
    @wasmi_core.f32x4_replace_lane(
      input,
      @wasmi_core.ImmLaneIdx4(lane.to_byte()),
      value.to_f32(),
    )
  },
  replace_lane: @ir.Op::f32x4_replace_lane,
  replace_lane_imm: fn(result, input, lane, _value) {
    @ir.Op::f32x4_replace_lane_imm(result, input, lane)
  },
  replace_lane_imm_param: fn(value) {
    Some(@ir.Op::const32(@ir.AnyConst32::from_f32_bits(typed_f32_bits(value))))
  },
  value_to_imm: fn(_) { true },
}

///|
let f64x2_replace_lane_op : SimdReplaceLane = {
  item_ty: F64,
  const_eval: fn(input, lane, value) {
    @wasmi_core.f64x2_replace_lane(
      input,
      @wasmi_core.ImmLaneIdx2(lane.to_byte()),
      value.to_f64(),
    )
  },
  replace_lane: @ir.Op::f64x2_replace_lane,
  replace_lane_imm: fn(result, input, lane, _value) {
    @ir.Op::f64x2_replace_lane_imm32(result, input, lane)
  },
  replace_lane_imm_param: fn(value) {
    match @ir.Const32::try_from_f64_bits(typed_f64_bits(value)) {
      Some(c) => Some(@ir.Op::f64const32(c))
      None => abort("unreachable")
    }
  },
  value_to_imm: fn(value) {
    @ir.Const32::try_from_f64_bits(typed_f64_bits(value)) is Some(_)
  },
}

///|
/// Generically translate a Wasm `replace_lane` instruction.
fn FuncTranslator::translate_replace_lane(
  self : FuncTranslator,
  op : SimdReplaceLane,
  lane : Int,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let lane = op.item_ty.lane_idx(lane)
  let (input, value) = self.stack.pop2()
  if (input, value) is (Immediate(x), Immediate(item)) {
    let result = (op.const_eval)(typed_v128(x.val()), lane.0, item.val())
    self.stack.push_immediate(v128_typed(result)) |> ignore
    return
  }
  let input = self.layout.operand_to_reg(input)
  let value : Input[@wasmi_core.TypedVal] = self.make_input(value, fn(
    this,
    value,
  ) raise WasmiError {
    if (op.value_to_imm)(value) {
      Immediate(value)
    } else {
      let imm = this.layout.const_to_reg(value.untyped())
      Slot(imm)
    }
  })
  let param = match value {
    Slot(value) => Some(@ir.Op::slot(value))
    Immediate(value) => (op.replace_lane_imm_param)(value)
  }
  let item_ty = match op.item_ty {
    F32 => @wasmi_core.ValType::F32
    F64 => F64
    I64 => I64
    _ => I32
  }
  // Note: upstream pushes the result typed as the lane item type
  // (`<T::Item as Typed>::TY`).
  self.push_instr_with_result(
    item_ty,
    fn(result) {
      match value {
        Slot(_) => (op.replace_lane)(result, input, lane)
        Immediate(value) => (op.replace_lane_imm)(result, input, lane, value)
      }
    },
    fuel_simd,
  )
  if param is Some(param) {
    self.push_param(param)
  }
}

///|
/// Generically translate a Wasm unary SIMD instruction.
fn FuncTranslator::translate_simd_unary(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot, @ir.Slot) -> @ir.Op,
  const_eval : (@wasmi_core.V128Value) -> @wasmi_core.TypedVal,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let input = self.stack.pop()
  if input is Immediate(input) {
    // Case: the input is an immediate so we can const-eval the result.
    let result = const_eval(typed_v128(input.val()))
    self.stack.push_immediate(result) |> ignore
    return
  }
  let input = self.layout.operand_to_reg(input)
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr(result, input) },
    fuel_simd,
  )
}

///|
/// Generically translate a Wasm binary SIMD instruction.
fn FuncTranslator::translate_simd_binary(
  self : FuncTranslator,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  const_eval : (@wasmi_core.V128Value, @wasmi_core.V128Value) -> @wasmi_core.V128Value,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (lhs, rhs) = self.stack.pop2()
  if (lhs, rhs) is (Immediate(lhs), Immediate(rhs)) {
    // Case: both inputs are immediates so we can const-eval the result.
    let result = const_eval(typed_v128(lhs.val()), typed_v128(rhs.val()))
    self.stack.push_immediate(v128_typed(result)) |> ignore
    return
  }
  let lhs = self.layout.operand_to_reg(lhs)
  let rhs = self.layout.operand_to_reg(rhs)
  self.push_instr_with_result(
    V128,
    fn(result) { make_instr(result, lhs, rhs) },
    fuel_simd,
  )
}

///|
/// Generically translate a Wasm ternary SIMD instruction.
fn FuncTranslator::translate_simd_ternary(
  self : FuncTranslator,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  const_eval : (
    @wasmi_core.V128Value,
    @wasmi_core.V128Value,
    @wasmi_core.V128Value,
  ) -> @wasmi_core.V128Value,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (a, b, c) = self.stack.pop3()
  if (a, b, c) is (Immediate(lhs), Immediate(rhs), Immediate(c)) {
    // Case: all inputs are immediates so we can const-eval the result.
    let result = const_eval(
      typed_v128(lhs.val()),
      typed_v128(rhs.val()),
      typed_v128(c.val()),
    )
    self.stack.push_immediate(v128_typed(result)) |> ignore
    return
  }
  let lhs = self.layout.operand_to_reg(a)
  let rhs = self.layout.operand_to_reg(b)
  let selector = self.layout.operand_to_reg(c)
  self.push_instr_with_result(
    V128,
    fn(result) { make_instr(result, lhs, rhs) },
    fuel_simd,
  )
  self.push_param(@ir.Op::slot(selector))
}

///|
/// Generically translate a Wasm SIMD shift instruction (`T` given by its
/// lane bit width `bits` for upstream's `IntoShiftAmount`).
fn FuncTranslator::translate_simd_shift(
  self : FuncTranslator,
  bits : UInt,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  make_instr_imm : (@ir.Slot, @ir.Slot, @ir.ShiftAmount) -> @ir.Op,
  const_eval : (@wasmi_core.V128Value, UInt) -> @wasmi_core.V128Value,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (lhs, rhs) = self.stack.pop2()
  if (lhs, rhs) is (Immediate(lhs), Immediate(rhs)) {
    // Case: both inputs are immediates so we can const-eval the result.
    let result = const_eval(typed_v128(lhs.val()), rhs.val().to_u32())
    self.stack.push_immediate(v128_typed(result)) |> ignore
    return
  }
  if rhs is Immediate(rhs) {
    guard @ir.ShiftAmount::of_u32(rhs.val().to_u32(), bits) is Some(rhs) else {
      // Case: the shift operation is a no-op
      self.stack.push_operand(lhs) |> ignore
      return
    }
    let lhs = self.layout.operand_to_reg(lhs)
    self.push_instr_with_result(
      V128,
      fn(result) { make_instr_imm(result, lhs, rhs) },
      fuel_simd,
    )
    return
  }
  let lhs = self.layout.operand_to_reg(lhs)
  let rhs = self.layout.operand_to_reg(rhs)
  self.push_instr_with_result(
    V128,
    fn(result) { make_instr(result, lhs, rhs) },
    fuel_simd,
  )
}

///|
/// Translates a Wasm `v128.loadN_lane` instruction.
fn FuncTranslator::translate_v128_load_lane(
  self : FuncTranslator,
  lane_ty : LaneTy,
  memarg : @wasmparser.MemArg,
  lane : Int,
  make_instr : (@ir.Slot, @ir.Offset64Lo) -> @ir.Op,
  make_instr_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (memory, offset) = FuncTranslator::decode_memarg(memarg)
  let lane = lane_ty.lane_idx(lane)
  let (ptr, x) = self.stack.pop2()
  let x = self.layout.operand_to_reg(x)
  // Note: upstream pushes the result typed as the lane type `<T as Typed>::TY`.
  let result_ty : @wasmi_core.ValType = match lane_ty {
    I64 => I64
    _ => I32
  }
  let (ptr, offset) = match ptr {
    Immediate(ptr) => {
      guard self.effective_address(memory, ptr.val(), offset) is Some(address) else {
        return self.translate_trap(MemoryOutOfBounds)
      }
      if @ir.Address32::try_from_address(address) is Some(address) {
        return self.translate_v128_load_lane_at(
          result_ty, memory, x, lane, address, make_instr_at,
        )
      }
      let zero_ptr = self.layout.const_to_reg(
        @wasmi_core.UntypedVal::from_u64(0),
      )
      (zero_ptr, address.to_u64())
    }
    ptr => {
      let ptr = self.layout.operand_to_reg(ptr)
      (ptr, offset)
    }
  }
  let (offset_hi, offset_lo) = @ir.Offset64::split(offset)
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr(result, offset_lo) },
    fuel_load,
  )
  self.push_param(@ir.Op::slot_and_offset_hi(ptr, offset_hi))
  self.push_param(@ir.Op::slot_and_lane(x, lane.0))
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
fn FuncTranslator::translate_v128_load_lane_at(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  memory : @ir.Memory,
  x : @ir.Slot,
  lane : @ir.ImmLaneIdx,
  address : @ir.Address32,
  make_instr_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
) -> Unit raise WasmiError {
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr_at(result, address) },
    fuel_load,
  )
  self.push_param(@ir.Op::slot_and_lane(x, lane.0))
  if !memory.is_default() {
    self.push_param(@ir.Op::memory_index(memory))
  }
}

///|
/// Translates a Wasm `v128.storeN_lane` instruction.
fn FuncTranslator::translate_v128_store_lane(
  self : FuncTranslator,
  lane_ty : LaneTy,
  memarg : @wasmparser.MemArg,
  lane : Int,
  make_instr : (@ir.Slot, @ir.Offset64Lo) -> @ir.Op,
  make_instr_offset8 : (@ir.Slot, @ir.Slot, @ir.Offset8, @ir.ImmLaneIdx) -> @ir.Op,
  make_instr_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
  translate_imm : (
    FuncTranslator,
    @wasmparser.MemArg,
    Operand,
    Int,
    @wasmi_core.V128Value,
  ) -> Unit raise WasmiError,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let lane = lane_ty.lane_idx(lane)
  let (ptr, v128) = self.stack.pop2()
  let v128 = match v128 {
    Immediate(v128) =>
      // Case: with `v128` being an immediate value we can extract its
      //       lane value and translate as a more efficient non-SIMD operation.
      return translate_imm(self, memarg, ptr, lane.0, typed_v128(v128.val()))
    v128 => self.layout.operand_to_reg(v128)
  }
  let (memory, offset) = FuncTranslator::decode_memarg(memarg)
  let (ptr, offset) = match ptr {
    Immediate(ptr) => {
      guard self.effective_address(memory, ptr.val(), offset) is Some(address) else {
        return self.translate_trap(MemoryOutOfBounds)
      }
      if @ir.Address32::try_from_address(address) is Some(address) {
        return self.translate_v128_store_lane_at(
          memory, address, v128, lane, make_instr_at,
        )
      }
      // Case: we cannot use specialized encoding and thus have to fall back
      //       to the general case where `ptr` is zero and `offset` stores the
      //       `ptr+offset` address value.
      let zero_ptr = self.layout.const_to_reg(
        @wasmi_core.UntypedVal::from_u64(0),
      )
      (zero_ptr, address.to_u64())
    }
    ptr => {
      let ptr = self.layout.operand_to_reg(ptr)
      (ptr, offset)
    }
  }
  if (self.translate_v128_store_lane_mem0(
      memory, ptr, offset, v128, lane, make_instr_offset8,
    ) catch {
      _ => None
    })
    is Some(_) {
    return
  }
  let (offset_hi, offset_lo) = @ir.Offset64::split(offset)
  let instr = make_instr(ptr, offset_lo)
  let param = @ir.Op::slot_and_offset_hi(v128, offset_hi)
  let param2 = @ir.Op::lane_and_memory_index(lane.0, memory)
  self.push_instr(instr, fuel_store) |> ignore
  self.push_param(param)
  self.push_param(param2)
}

///|
fn FuncTranslator::translate_v128_store_lane_at(
  self : FuncTranslator,
  memory : @ir.Memory,
  address : @ir.Address32,
  value : @ir.Slot,
  lane : @ir.ImmLaneIdx,
  make_instr_at : (@ir.Slot, @ir.Address32) -> @ir.Op,
) -> Unit raise WasmiError {
  self.push_instr(make_instr_at(value, address), fuel_store) |> ignore
  self.push_param(@ir.Op::lane_and_memory_index(lane.0, memory))
}

///|
fn FuncTranslator::translate_v128_store_lane_mem0(
  self : FuncTranslator,
  memory : @ir.Memory,
  ptr : @ir.Slot,
  offset : UInt64,
  value : @ir.Slot,
  lane : @ir.ImmLaneIdx,
  make_instr_offset8 : (@ir.Slot, @ir.Slot, @ir.Offset8, @ir.ImmLaneIdx) -> @ir.Op,
) -> Instr? raise WasmiError {
  if !memory.is_default() {
    return None
  }
  guard @ir.Offset8::try_from_u64(offset) is Some(offset8) else { return None }
  let instr = self.push_instr(
    make_instr_offset8(ptr, value, offset8, lane),
    fuel_store,
  )
  Some(instr)
}

// ---------------------------------------------------------------------------
// simd/visit.rs (non-mechanical part)

///|
fn FuncTranslator::visit_v128_load8_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_load_lane(
    I8,
    memarg,
    lane,
    @ir.Op::v128_load8_lane,
    @ir.Op::v128_load8_lane_at,
  )
}

///|
fn FuncTranslator::visit_v128_load16_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_load_lane(
    I16,
    memarg,
    lane,
    @ir.Op::v128_load16_lane,
    @ir.Op::v128_load16_lane_at,
  )
}

///|
fn FuncTranslator::visit_v128_load32_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_load_lane(
    I32,
    memarg,
    lane,
    @ir.Op::v128_load32_lane,
    @ir.Op::v128_load32_lane_at,
  )
}

///|
fn FuncTranslator::visit_v128_load64_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_load_lane(
    I64,
    memarg,
    lane,
    @ir.Op::v128_load64_lane,
    @ir.Op::v128_load64_lane_at,
  )
}

///|
fn FuncTranslator::visit_v128_store8_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_store_lane(
    I8,
    memarg,
    lane,
    @ir.Op::v128_store8_lane,
    @ir.Op::v128_store8_lane_offset8,
    @ir.Op::v128_store8_lane_at,
    fn(this, memarg, ptr, lane, v128) raise WasmiError {
      let value = @wasmi_core.i8x16_extract_lane_s(
        v128,
        @wasmi_core.ImmLaneIdx16(lane.to_byte()),
      )
      let value = this.immediate_to_operand(
        @wasmi_core.TypedVal::from_i32(value),
      )
      this.encode_istore_wrap(i32_store8_op, memarg, ptr, value)
    },
  )
}

///|
fn FuncTranslator::visit_v128_store16_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_store_lane(
    I16,
    memarg,
    lane,
    @ir.Op::v128_store16_lane,
    @ir.Op::v128_store16_lane_offset8,
    @ir.Op::v128_store16_lane_at,
    fn(this, memarg, ptr, lane, v128) raise WasmiError {
      let value = @wasmi_core.i16x8_extract_lane_s(
        v128,
        @wasmi_core.ImmLaneIdx8(lane.to_byte()),
      )
      let value = this.immediate_to_operand(
        @wasmi_core.TypedVal::from_i32(value),
      )
      this.encode_istore_wrap(i32_store16_op, memarg, ptr, value)
    },
  )
}

///|
fn FuncTranslator::visit_v128_store32_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_store_lane(
    I32,
    memarg,
    lane,
    @ir.Op::v128_store32_lane,
    @ir.Op::v128_store32_lane_offset8,
    @ir.Op::v128_store32_lane_at,
    fn(this, memarg, ptr, lane, v128) raise WasmiError {
      let value = @wasmi_core.i32x4_extract_lane(
        v128,
        @wasmi_core.ImmLaneIdx4(lane.to_byte()),
      )
      let value = this.immediate_to_operand(
        @wasmi_core.TypedVal::from_i32(value),
      )
      this.encode_istore_wrap(i32_store_op, memarg, ptr, value)
    },
  )
}

///|
fn FuncTranslator::visit_v128_store64_lane(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_v128_store_lane(
    I64,
    memarg,
    lane,
    @ir.Op::v128_store64_lane,
    @ir.Op::v128_store64_lane_offset8,
    @ir.Op::v128_store64_lane_at,
    fn(this, memarg, ptr, lane, v128) raise WasmiError {
      let value = @wasmi_core.i64x2_extract_lane(
        v128,
        @wasmi_core.ImmLaneIdx2(lane.to_byte()),
      )
      let value = this.immediate_to_operand(
        @wasmi_core.TypedVal::from_i64(value),
      )
      this.encode_istore_wrap(i64_store_op, memarg, ptr, value)
    },
  )
}

///|
fn FuncTranslator::visit_v128_const(
  self : FuncTranslator,
  bytes : FixedArray[Byte],
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let v128 = @wasmi_core.V128Value::from_le_bytes(bytes[:])
  self.stack.push_immediate(v128_typed(v128)) |> ignore
}

///|
fn FuncTranslator::visit_i8x16_shuffle(
  self : FuncTranslator,
  lanes : FixedArray[Byte],
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let selector = FixedArray::makei(16, fn(i) {
    if lanes[i].to_int() >= 32 {
      abort("encountered out of bounds lane at index \{i}: \{lanes[i]}")
    }
    @wasmi_core.ImmLaneIdx32(lanes[i])
  })
  let (lhs, rhs) = self.stack.pop2()
  if (lhs, rhs) is (Immediate(lhs), Immediate(rhs)) {
    let result = @wasmi_core.i8x16_shuffle(
      typed_v128(lhs.val()),
      typed_v128(rhs.val()),
      selector,
    )
    self.stack.push_immediate(v128_typed(result)) |> ignore
    return
  }
  let lhs = self.layout.operand_to_reg(lhs)
  let rhs = self.layout.operand_to_reg(rhs)
  let selector = self.layout.const_to_reg(
    @wasmi_core.UntypedVal::from_v128(
      @wasmi_core.V128Value::from_le_bytes(lanes[:]),
    ),
  )
  self.push_instr_with_result(
    V128,
    fn(result) { @ir.Op::i8x16_shuffle(result, lhs, rhs) },
    fuel_simd,
  )
  self.push_param(@ir.Op::slot(selector))
}

///|
fn FuncTranslator::visit_i8x16_extract_lane_s(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(I8, lane, I32, @ir.Op::i8x16_extract_lane_s, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_i32(
      @wasmi_core.i8x16_extract_lane_s(v, @wasmi_core.ImmLaneIdx16(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_i8x16_extract_lane_u(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(U8, lane, I32, @ir.Op::i8x16_extract_lane_u, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_u32(
      @wasmi_core.i8x16_extract_lane_u(v, @wasmi_core.ImmLaneIdx16(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_i16x8_extract_lane_s(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(I16, lane, I32, @ir.Op::i16x8_extract_lane_s, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_i32(
      @wasmi_core.i16x8_extract_lane_s(v, @wasmi_core.ImmLaneIdx8(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_i16x8_extract_lane_u(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(U16, lane, I32, @ir.Op::i16x8_extract_lane_u, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_u32(
      @wasmi_core.i16x8_extract_lane_u(v, @wasmi_core.ImmLaneIdx8(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_i32x4_extract_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(I32, lane, I32, @ir.Op::i32x4_extract_lane, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_i32(
      @wasmi_core.i32x4_extract_lane(v, @wasmi_core.ImmLaneIdx4(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_i64x2_extract_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(I64, lane, I64, @ir.Op::i64x2_extract_lane, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_i64(
      @wasmi_core.i64x2_extract_lane(v, @wasmi_core.ImmLaneIdx2(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_f32x4_extract_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(F32, lane, F32, @ir.Op::f32x4_extract_lane, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_f32(
      @wasmi_core.f32x4_extract_lane(v, @wasmi_core.ImmLaneIdx4(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_f64x2_extract_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_extract_lane(F64, lane, F64, @ir.Op::f64x2_extract_lane, fn(
    v,
    l,
  ) {
    @wasmi_core.TypedVal::from_f64(
      @wasmi_core.f64x2_extract_lane(v, @wasmi_core.ImmLaneIdx2(l.to_byte())),
    )
  })
}

///|
fn FuncTranslator::visit_i8x16_replace_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_replace_lane(i8x16_replace_lane_op, lane)
}

///|
fn FuncTranslator::visit_i16x8_replace_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_replace_lane(i16x8_replace_lane_op, lane)
}

///|
fn FuncTranslator::visit_i32x4_replace_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_replace_lane(i32x4_replace_lane_op, lane)
}

///|
fn FuncTranslator::visit_i64x2_replace_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_replace_lane(i64x2_replace_lane_op, lane)
}

///|
fn FuncTranslator::visit_f32x4_replace_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_replace_lane(f32x4_replace_lane_op, lane)
}

///|
fn FuncTranslator::visit_f64x2_replace_lane(
  self : FuncTranslator,
  lane : Int,
) -> Unit raise WasmiError {
  self.translate_replace_lane(f64x2_replace_lane_op, lane)
}
