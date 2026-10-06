// Port of wasmparser 0.228.0 `src/validator/operators/simd.rs`.

///|
fn OperatorValidatorTemp::check_simd_lane_index(
  self : OperatorValidatorTemp,
  index : Byte,
  max : Byte,
) -> Unit raise BinaryReaderError {
  if index >= max {
    bail(self.offset, "SIMD index out of bounds")
  }
}

///|
/// Checks a [`V128`] splat operator.
fn OperatorValidatorTemp::check_v128_splat(
  self : OperatorValidatorTemp,
  src_ty : ValType,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(src_ty)) |> ignore
  self.push_operand(V128)
}

///|
/// Checks a [`V128`] binary operator.
fn OperatorValidatorTemp::check_v128_binary_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
/// Checks a [`V128`] binary float operator.
fn OperatorValidatorTemp::check_v128_fbinary_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_v128_binary_op()
}

///|
/// Checks a [`V128`] unary operator.
fn OperatorValidatorTemp::check_v128_unary_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
/// Checks a [`V128`] unary float operator.
fn OperatorValidatorTemp::check_v128_funary_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_v128_unary_op()
}

///|
/// Checks a [`V128`] relaxed ternary operator.
fn OperatorValidatorTemp::check_v128_ternary_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
/// Checks a [`V128`] test operator.
fn OperatorValidatorTemp::check_v128_bitmask_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(I32)
}

///|
/// Checks a [`V128`] shift operator.
fn OperatorValidatorTemp::check_v128_shift_op(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
/// Checks a [`V128`] common load operator.
fn OperatorValidatorTemp::check_v128_load_op(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.pop_operand(Some(idx)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
// Cannot fail; visitor methods share `Result<()>`
// (wasmparser 0.228.0 src/validator/operators/simd.rs:99).
#warnings("-unused_error_type")
fn OperatorValidatorTemp::visit_v128_const(
  self : OperatorValidatorTemp,
  _value : V128,
) -> Unit raise BinaryReaderError {
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i8x16_splat(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_splat(I32)
}

///|
fn OperatorValidatorTemp::visit_i16x8_splat(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_splat(I32)
}

///|
fn OperatorValidatorTemp::visit_i32x4_splat(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_splat(I32)
}

///|
fn OperatorValidatorTemp::visit_i64x2_splat(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_splat(I64)
}

///|
fn OperatorValidatorTemp::visit_f32x4_splat(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_v128_splat(F32)
}

///|
fn OperatorValidatorTemp::visit_f64x2_splat(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_v128_splat(F64)
}

///|
fn OperatorValidatorTemp::visit_i8x16_extract_lane_s(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 16)
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i8x16_extract_lane_u(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.visit_i8x16_extract_lane_s(lane)
}

///|
fn OperatorValidatorTemp::visit_i16x8_extract_lane_s(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 8)
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i16x8_extract_lane_u(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.visit_i16x8_extract_lane_s(lane)
}

///|
fn OperatorValidatorTemp::visit_i32x4_extract_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 4)
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i8x16_replace_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 16)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i16x8_replace_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 8)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i32x4_replace_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 4)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i64x2_extract_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 2)
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::visit_i64x2_replace_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_simd_lane_index(lane, 2)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_f32x4_extract_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_simd_lane_index(lane, 4)
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(F32)
}

///|
fn OperatorValidatorTemp::visit_f32x4_replace_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_simd_lane_index(lane, 4)
  self.pop_operand(Some(F32)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_f64x2_extract_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_simd_lane_index(lane, 2)
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(F64)
}

///|
fn OperatorValidatorTemp::visit_f64x2_replace_lane(
  self : OperatorValidatorTemp,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_simd_lane_index(lane, 2)
  self.pop_operand(Some(F64)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_f32x4_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_lt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_gt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_le(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_ge(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_lt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_gt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_le(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_ge(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_div(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_min(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_max(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_pmin(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_pmax(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_div(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_min(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_max(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_pmin(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_pmax(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_fbinary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_lt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_lt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_gt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_gt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_le_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_le_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_ge_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_ge_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_lt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_lt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_gt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_gt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_le_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_le_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_ge_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_ge_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_lt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_lt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_gt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_gt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_le_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_le_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_ge_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_ge_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_lt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_gt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_le_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_ge_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_and(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_andnot(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_or(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_xor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_add_sat_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_add_sat_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_sub_sat_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_sub_sat_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_min_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_min_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_max_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_max_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_add_sat_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_add_sat_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_sub_sat_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_sub_sat_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_min_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_min_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_max_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_max_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_min_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_min_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_max_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_max_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_dot_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_avgr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_avgr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_narrow_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_narrow_i16x8_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_narrow_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_narrow_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extmul_low_i8x16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extmul_high_i8x16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extmul_low_i8x16_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extmul_high_i8x16_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extmul_low_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extmul_high_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extmul_low_i16x8_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extmul_high_i16x8_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extmul_low_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extmul_high_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extmul_low_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extmul_high_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_q15mulr_sat_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_ceil(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_floor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_trunc(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_nearest(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_ceil(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_floor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_trunc(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_nearest(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_sqrt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_sqrt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_demote_f64x2_zero(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_promote_low_f32x4(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_convert_low_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_convert_low_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_trunc_sat_f32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_trunc_sat_f32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_trunc_sat_f64x2_s_zero(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_trunc_sat_f64x2_u_zero(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_convert_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_convert_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_funary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_not(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_popcnt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extend_low_i8x16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extend_high_i8x16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extend_low_i8x16_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extend_high_i8x16_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extend_low_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extend_high_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extend_low_i16x8_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extend_high_i16x8_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extend_low_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extend_high_i32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extend_low_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_extend_high_i32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extadd_pairwise_i8x16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_extadd_pairwise_i8x16_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extadd_pairwise_i16x8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_extadd_pairwise_i16x8_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_bitselect(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i8x16_relaxed_swizzle(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i32x4_relaxed_trunc_f32x4_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_relaxed_trunc_f32x4_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_relaxed_trunc_f64x2_s_zero(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_relaxed_trunc_f64x2_u_zero(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_unary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_relaxed_madd(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_relaxed_nmadd(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_relaxed_madd(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_relaxed_nmadd(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_relaxed_laneselect(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_relaxed_laneselect(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_relaxed_laneselect(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_relaxed_laneselect(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_relaxed_min(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_f32x4_relaxed_max(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_relaxed_min(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_f64x2_relaxed_max(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_relaxed_q15mulr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_relaxed_dot_i8x16_i7x16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_binary_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_relaxed_dot_i8x16_i7x16_add_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_ternary_op()
}

///|
fn OperatorValidatorTemp::visit_v128_any_true(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_all_true(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_bitmask(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_all_true(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_bitmask(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_all_true(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_bitmask(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_all_true(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_bitmask(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_bitmask_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_shl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_shr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_shr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_shl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_shr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i16x8_shr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_shl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_shr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i32x4_shr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_shl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_shr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i64x2_shr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_v128_shift_op()
}

///|
fn OperatorValidatorTemp::visit_i8x16_swizzle(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_i8x16_shuffle(
  self : OperatorValidatorTemp,
  lanes : FixedArray[Byte],
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(V128)) |> ignore
  for i in lanes {
    self.check_simd_lane_index(i, 32)
  }
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load8_splat(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load16_splat(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load32_splat(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load32_zero(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.visit_v128_load32_splat(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load64_splat(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load64_zero(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load8x8_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load8x8_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load16x4_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load16x4_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load32x2_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load32x2_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_v128_load_op(memarg)
}

///|
fn OperatorValidatorTemp::visit_v128_load8_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 16)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load16_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 8)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load32_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 4)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_load64_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 2)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
  self.push_operand(V128)
}

///|
fn OperatorValidatorTemp::visit_v128_store8_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 16)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_v128_store16_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 8)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_v128_store32_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 4)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_v128_store64_lane(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  lane : Byte,
) -> Unit raise BinaryReaderError {
  let idx = self.check_memarg(memarg)
  self.check_simd_lane_index(lane, 2)
  self.pop_operand(Some(V128)) |> ignore
  self.pop_operand(Some(idx)) |> ignore
}
