// Port of the memory operations of `wasmi_core/src/simd.rs`.

///|
/// Executes a Wasm `v128.store` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn v128_store(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : V128,
) -> Unit raise TrapCode {
  store_u128_at(memory, memory_len, effective_address(ptr, offset), value)
}

///|
/// Executes a Wasm `v128.store` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn v128_store_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : V128,
) -> Unit raise TrapCode {
  store_u128_at(memory, memory_len, address, value)
}

///|
/// Executes a Wasm `v128_store8_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn v128_store8_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : V128,
  imm : ImmLaneIdx16,
) -> Unit raise TrapCode {
  v128_store8_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value,
    imm,
  )
}

///|
/// Executes a Wasm `v128_store16_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn v128_store16_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : V128,
  imm : ImmLaneIdx8,
) -> Unit raise TrapCode {
  v128_store16_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value,
    imm,
  )
}

///|
/// Executes a Wasm `v128_store32_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn v128_store32_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : V128,
  imm : ImmLaneIdx4,
) -> Unit raise TrapCode {
  v128_store32_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value,
    imm,
  )
}

///|
/// Executes a Wasm `v128_store64_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn v128_store64_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : V128,
  imm : ImmLaneIdx2,
) -> Unit raise TrapCode {
  v128_store64_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value,
    imm,
  )
}

///|
/// Executes a Wasm `v128_store8_lane_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn v128_store8_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : V128,
  imm : ImmLaneIdx16,
) -> Unit raise TrapCode {
  store_u8_at(
    memory,
    memory_len,
    address,
    value.lane_bits(8, imm.to_u8().to_int()).to_byte(),
  )
}

///|
/// Executes a Wasm `v128_store16_lane_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn v128_store16_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : V128,
  imm : ImmLaneIdx8,
) -> Unit raise TrapCode {
  store_u16_at(
    memory,
    memory_len,
    address,
    value.lane_bits(16, imm.to_u8().to_int()).to_int(),
  )
}

///|
/// Executes a Wasm `v128_store32_lane_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn v128_store32_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : V128,
  imm : ImmLaneIdx4,
) -> Unit raise TrapCode {
  store_u32_at(
    memory,
    memory_len,
    address,
    value.lane_bits(32, imm.to_u8().to_int()).to_uint(),
  )
}

///|
/// Executes a Wasm `v128_store64_lane_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn v128_store64_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : V128,
  imm : ImmLaneIdx2,
) -> Unit raise TrapCode {
  store_u64_at(
    memory,
    memory_len,
    address,
    value.lane_bits(64, imm.to_u8().to_int()),
  )
}

///|
/// Executes a Wasmi `v128.load` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  load_u128_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `v128.load` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_u128_at(memory, memory_len, address)
}

///|
/// Executes a Wasm `v128_load32_zero` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load32_zero(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load32_zero_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load64_zero` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load64_zero(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load64_zero_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load32_zero_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load32_zero_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  let bits = load_u32_at(memory, memory_len, address)
  { lo: bits.to_uint64(), hi: 0, }
}

///|
/// Executes a Wasm `v128_load64_zero_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load64_zero_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  let bits = load_u64_at(memory, memory_len, address)
  { lo: bits, hi: 0, }
}

///|
/// Executes a Wasm `v128_load8_splat` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load8_splat(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load8_splat_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load16_splat` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load16_splat(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load16_splat_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load32_splat` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load32_splat(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load32_splat_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load64_splat` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load64_splat(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load64_splat_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load8_splat_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load8_splat_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  i8x16_splat(load_u8_at(memory, memory_len, address).to_int())
}

///|
/// Executes a Wasm `v128_load16_splat_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load16_splat_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  i16x8_splat(load_u16_at(memory, memory_len, address))
}

///|
/// Executes a Wasm `v128_load32_splat_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load32_splat_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  i32x4_splat(load_u32_at(memory, memory_len, address).reinterpret_as_int())
}

///|
/// Executes a Wasm `v128_load64_splat_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load64_splat_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  let v = load_u64_at(memory, memory_len, address)
  { lo: v, hi: v, }
}

///|
/// Executes a Wasm `v128_load8_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load8_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  x : V128,
  lane : ImmLaneIdx16,
) -> V128 raise TrapCode {
  v128_load8_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    x,
    lane,
  )
}

///|
/// Executes a Wasm `v128_load16_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load16_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  x : V128,
  lane : ImmLaneIdx8,
) -> V128 raise TrapCode {
  v128_load16_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    x,
    lane,
  )
}

///|
/// Executes a Wasm `v128_load32_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load32_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  x : V128,
  lane : ImmLaneIdx4,
) -> V128 raise TrapCode {
  v128_load32_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    x,
    lane,
  )
}

///|
/// Executes a Wasm `v128_load64_lane` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load64_lane(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  x : V128,
  lane : ImmLaneIdx2,
) -> V128 raise TrapCode {
  v128_load64_lane_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    x,
    lane,
  )
}

///|
/// Executes a Wasm `v128_load8_lane_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load8_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  x : V128,
  lane : ImmLaneIdx16,
) -> V128 raise TrapCode {
  let value = load_u8_at(memory, memory_len, address)
  x.with_lane_bits(8, lane.to_u8().to_int(), value.to_uint64())
}

///|
/// Executes a Wasm `v128_load16_lane_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load16_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  x : V128,
  lane : ImmLaneIdx8,
) -> V128 raise TrapCode {
  let value = load_u16_at(memory, memory_len, address)
  x.with_lane_bits(16, lane.to_u8().to_int(), value.to_uint64())
}

///|
/// Executes a Wasm `v128_load32_lane_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load32_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  x : V128,
  lane : ImmLaneIdx4,
) -> V128 raise TrapCode {
  let value = load_u32_at(memory, memory_len, address)
  x.with_lane_bits(32, lane.to_u8().to_int(), value.to_uint64())
}

///|
/// Executes a Wasm `v128_load64_lane_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load64_lane_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  x : V128,
  lane : ImmLaneIdx2,
) -> V128 raise TrapCode {
  let value = load_u64_at(memory, memory_len, address)
  x.with_lane_bits(64, lane.to_u8().to_int(), value)
}

///|
/// `V128::load_nxm`: interprets `bits` as array of `bits / 2`-wide narrow
/// items (`narrow` bits each) and distributes the (sign) extended items.
fn load_nxm(bits : UInt64, narrow : Int, signed : Bool) -> V128 {
  let src : V128 = { lo: bits, hi: 0, }
  if narrow == 32 {
    let ext = (j : Int) => {
      if signed {
        src.i32_lane(j).to_int64().reinterpret_as_uint64()
      } else {
        src.lane_bits(32, j)
      }
    }
    return { lo: ext(0), hi: ext(1), }
  }
  small_from_fn(narrow * 2, i => {
    ext_small(src.lane_bits(narrow, i), narrow, signed)
  })
}

///|
/// Executes a Wasm `v128_load8x8_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load8x8_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load8x8_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load8x8_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load8x8_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load8x8_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load16x4_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load16x4_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load16x4_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load16x4_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load16x4_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load16x4_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load32x2_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load32x2_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load32x2_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load32x2_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn v128_load32x2_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> V128 raise TrapCode {
  v128_load32x2_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasm `v128_load8x8_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load8x8_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_nxm(load_u64_at(memory, memory_len, address), 8, true)
}

///|
/// Executes a Wasm `v128_load8x8_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load8x8_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_nxm(load_u64_at(memory, memory_len, address), 8, false)
}

///|
/// Executes a Wasm `v128_load16x4_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load16x4_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_nxm(load_u64_at(memory, memory_len, address), 16, true)
}

///|
/// Executes a Wasm `v128_load16x4_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load16x4_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_nxm(load_u64_at(memory, memory_len, address), 16, false)
}

///|
/// Executes a Wasm `v128_load32x2_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load32x2_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_nxm(load_u64_at(memory, memory_len, address), 32, true)
}

///|
/// Executes a Wasm `v128_load32x2_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn v128_load32x2_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128 raise TrapCode {
  load_nxm(load_u64_at(memory, memory_len, address), 32, false)
}
