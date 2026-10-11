// Port of `wasmi_core/src/memory/access.rs`.
//
// Upstream's linear memory accessors take the memory as a byte slice
// `&[u8]`. Here a slice is passed as the pair `memory : FixedArray[Byte]`
// (the backing buffer, see [`Memory::data`]) and `memory_len : Int`, the
// accessible length (`memory.len()` upstream, [`Memory::data_size`]); the
// buffer may be longer than `memory_len` (spare capacity for growth). The
// bounds checks are those of the slice accesses upstream
// (`memory.get(address..).and_then(|slice| slice.get(..N))`). Upstream's
// `usize` addresses are `UInt64` (a 64-bit `usize`).

///|
/// Calculates the effective address of a linear memory access.
///
/// # Errors
///
/// If the resulting effective address overflows.
fn effective_address(ptr : UInt64, offset : UInt64) -> UInt64 raise TrapCode {
  let address = ptr + offset
  if address < ptr {
    raise MemoryOutOfBounds
  }
  address
}

///|
/// Returns `address` as an index into the buffer if `memory[address..][..n]`
/// is in bounds.
fn access_index(
  memory_len : Int,
  address : UInt64,
  n : Int,
) -> Int raise TrapCode {
  let len = memory_len.to_uint64()
  if address > len || len - address < n.to_uint64() {
    raise MemoryOutOfBounds
  }
  address.to_int()
}

///|
fn load_u8_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Byte raise TrapCode {
  let i = access_index(memory_len, address, 1)
  memory[i]
}

///|
fn load_u16_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int raise TrapCode {
  let i = access_index(memory_len, address, 2)
  memory[i].to_int() | (memory[i + 1].to_int() << 8)
}

///|
fn load_u32_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> UInt raise TrapCode {
  let i = access_index(memory_len, address, 4)
  memory[i].to_uint() |
  (memory[i + 1].to_uint() << 8) |
  (memory[i + 2].to_uint() << 16) |
  (memory[i + 3].to_uint() << 24)
}

///|
fn read_u64_le(memory : FixedArray[Byte], i : Int) -> UInt64 {
  memory[i].to_uint64() |
  (memory[i + 1].to_uint64() << 8) |
  (memory[i + 2].to_uint64() << 16) |
  (memory[i + 3].to_uint64() << 24) |
  (memory[i + 4].to_uint64() << 32) |
  (memory[i + 5].to_uint64() << 40) |
  (memory[i + 6].to_uint64() << 48) |
  (memory[i + 7].to_uint64() << 56)
}

///|
fn write_u64_le(memory : FixedArray[Byte], i : Int, value : UInt64) -> Unit {
  memory[i] = value.to_byte()
  memory[i + 1] = (value >> 8).to_byte()
  memory[i + 2] = (value >> 16).to_byte()
  memory[i + 3] = (value >> 24).to_byte()
  memory[i + 4] = (value >> 32).to_byte()
  memory[i + 5] = (value >> 40).to_byte()
  memory[i + 6] = (value >> 48).to_byte()
  memory[i + 7] = (value >> 56).to_byte()
}

///|
fn load_u64_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> UInt64 raise TrapCode {
  let i = access_index(memory_len, address, 8)
  read_u64_le(memory, i)
}

///|
fn load_u128_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> V128Value raise TrapCode {
  let i = access_index(memory_len, address, 16)
  { lo: read_u64_le(memory, i), hi: read_u64_le(memory, i + 8), }
}

///|
fn store_u8_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Byte,
) -> Unit raise TrapCode {
  let i = access_index(memory_len, address, 1)
  memory[i] = value
}

///|
fn store_u16_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Int,
) -> Unit raise TrapCode {
  let i = access_index(memory_len, address, 2)
  memory[i] = value.to_byte()
  memory[i + 1] = (value >> 8).to_byte()
}

///|
fn store_u32_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : UInt,
) -> Unit raise TrapCode {
  let i = access_index(memory_len, address, 4)
  memory[i] = value.to_byte()
  memory[i + 1] = (value >> 8).to_byte()
  memory[i + 2] = (value >> 16).to_byte()
  memory[i + 3] = (value >> 24).to_byte()
}

///|
fn store_u64_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : UInt64,
) -> Unit raise TrapCode {
  let i = access_index(memory_len, address, 8)
  write_u64_le(memory, i, value)
}

///|
fn store_u128_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : V128Value,
) -> Unit raise TrapCode {
  let i = access_index(memory_len, address, 16)
  write_u64_le(memory, i, value.lo)
  write_u64_le(memory, i + 8, value.hi)
}
