// Port of wasmi_ir 1.0.9 `primitive.rs`.

///|
/// The sign of a value (upstream `Sign<T>`, `T` being `f32` or `f64`).
pub(all) struct Sign(Bool) derive(Eq, Hash, Debug)

///|
/// Creates a positive [`Sign`].
pub fn Sign::pos() -> Sign {
  Sign(true)
}

///|
/// Creates a negative [`Sign`].
pub fn Sign::neg() -> Sign {
  Sign(false)
}

///|
/// Upstream `From<f32> for Sign<f32>` (given as bits): positive iff the sign
/// bit is clear.
pub fn Sign::from_f32_bits(bits : UInt) -> Sign {
  Sign((bits >> 31) == 0)
}

///|
/// Upstream `From<f64> for Sign<f64>` (given as bits).
pub fn Sign::from_f64_bits(bits : UInt64) -> Sign {
  Sign((bits >> 63) == 0)
}

///|
/// Upstream `From<Sign<f32>> for f32`: `1.0` or `-1.0`.
pub fn Sign::to_f32(self : Sign) -> Float {
  if self.0 {
    1.0
  } else {
    -1.0
  }
}

///|
/// Upstream `From<Sign<f64>> for f64`: `1.0` or `-1.0`.
pub fn Sign::to_f64(self : Sign) -> Double {
  if self.0 {
    1.0
  } else {
    -1.0
  }
}

///|
/// A 16-bit signed offset for branch instructions.
///
/// This defines how much the instruction pointer is offset
/// upon taking the respective branch.
pub(all) struct BranchOffset16(Int) derive(Eq, Hash, Debug)

///|
/// Upstream `From<i16> for BranchOffset16`.
pub fn BranchOffset16::from_i16(offset : Int) -> BranchOffset16 {
  BranchOffset16(offset)
}

///|
/// Upstream `TryFrom<BranchOffset> for BranchOffset16`.
pub fn BranchOffset16::try_from(offset : BranchOffset) -> BranchOffset16 raise Error {
  let offset = offset.to_i32()
  if offset < -32768 || offset > 32767 {
    raise Error::BranchOffsetOutOfBounds
  }
  BranchOffset16(offset)
}

///|
/// Upstream `From<BranchOffset16> for BranchOffset`.
pub fn BranchOffset16::to_branch_offset(self : BranchOffset16) -> BranchOffset {
  BranchOffset(self.0)
}

///|
/// Returns `true` if the [`BranchOffset16`] has been initialized.
pub fn BranchOffset16::is_init(self : BranchOffset16) -> Bool {
  self.to_i16() != 0
}

///|
/// Initializes the [`BranchOffset16`] with a proper value, returning it
/// (upstream mutates `self` in place).
///
/// # Panics
///
/// - If the [`BranchOffset`] have already been initialized.
/// - If the given [`BranchOffset`] is not properly initialized.
///
/// # Errors
///
/// If `valid_offset` cannot be encoded as 16-bit [`BranchOffset16`].
pub fn BranchOffset16::init(
  self : BranchOffset16,
  valid_offset : BranchOffset,
) -> BranchOffset16 raise Error {
  guard valid_offset.is_init()
  guard !self.is_init()
  BranchOffset16::try_from(valid_offset)
}

///|
/// Returns the `i16` representation of the [`BranchOffset16`].
pub fn BranchOffset16::to_i16(self : BranchOffset16) -> Int {
  self.0
}

///|
/// A signed offset for branch instructions.
///
/// This defines how much the instruction pointer is offset
/// upon taking the respective branch.
pub(all) struct BranchOffset(Int) derive(Eq, Hash, Debug)

///|
/// Upstream `From<i32> for BranchOffset`.
pub fn BranchOffset::from_i32(index : Int) -> BranchOffset {
  BranchOffset(index)
}

///|
/// Creates an uninitialized [`BranchOffset`].
pub fn BranchOffset::uninit() -> BranchOffset {
  BranchOffset(0)
}

///|
/// Creates an initialized [`BranchOffset`] from `src` to `dst`.
///
/// # Errors
///
/// If the resulting [`BranchOffset`] is out of bounds.
pub fn BranchOffset::from_src_to_dst(
  src : UInt,
  dst : UInt,
) -> BranchOffset raise Error {
  let src = src.to_uint64().reinterpret_as_int64()
  let dst = dst.to_uint64().reinterpret_as_int64()
  let offset = dst - src
  if offset < -2147483648L || offset > 2147483647L {
    raise Error::BranchOffsetOutOfBounds
  }
  BranchOffset(offset.to_int())
}

///|
/// Returns `true` if the [`BranchOffset`] has been initialized.
pub fn BranchOffset::is_init(self : BranchOffset) -> Bool {
  self.to_i32() != 0
}

///|
/// Initializes the [`BranchOffset`] with a proper value, returning it.
///
/// # Panics
///
/// - If the [`BranchOffset`] have already been initialized.
/// - If the given [`BranchOffset`] is not properly initialized.
pub fn BranchOffset::init(
  self : BranchOffset,
  valid_offset : BranchOffset,
) -> BranchOffset {
  guard valid_offset.is_init()
  guard !self.is_init()
  valid_offset
}

///|
/// Returns the `i32` representation of the [`BranchOffset`].
pub fn BranchOffset::to_i32(self : BranchOffset) -> Int {
  self.0
}

///|
/// The accumulated fuel to execute a block via [`Op::ConsumeFuel`]
/// (upstream `u32`).
pub(all) struct BlockFuel(UInt) derive(Eq, Hash, Debug)

///|
/// Upstream `From<u32> for BlockFuel`.
pub fn BlockFuel::from_u32(value : UInt) -> BlockFuel {
  BlockFuel(value)
}

///|
/// Upstream `TryFrom<u64> for BlockFuel`.
pub fn BlockFuel::try_from_u64(index : UInt64) -> BlockFuel raise Error {
  if index > 0xFFFF_FFFFUL {
    raise Error::BlockFuelOutOfBounds
  }
  BlockFuel(index.to_uint())
}

///|
/// Bump the fuel by `amount` if possible, returning the new fuel.
///
/// # Errors
///
/// If the new fuel amount after this operation is out of bounds.
pub fn BlockFuel::bump_by(self : BlockFuel, amount : UInt64) -> BlockFuel raise Error {
  let new_amount = self.to_u64() + amount
  if new_amount < amount {
    raise Error::BlockFuelOutOfBounds
  }
  BlockFuel::try_from_u64(new_amount)
}

///|
/// Returns the index value as `u64`.
pub fn BlockFuel::to_u64(self : BlockFuel) -> UInt64 {
  self.0.to_uint64()
}

///|
/// All comparators of fused compare-and-branch instructions.
pub(all) enum Comparator {
  I32Eq
  I32Ne
  I32LtS
  I32LtU
  I32LeS
  I32LeU
  I32And
  I32Or
  I32Nand
  I32Nor
  I64Eq
  I64Ne
  I64LtS
  I64LtU
  I64LeS
  I64LeU
  I64And
  I64Or
  I64Nand
  I64Nor
  F32Eq
  F32Ne
  F32Lt
  F32Le
  F32NotLt
  F32NotLe
  F64Eq
  F64Ne
  F64Lt
  F64Le
  F64NotLt
  F64NotLe
} derive(Eq, Hash, Debug)

///|
let comparators : FixedArray[Comparator] = [
  I32Eq, I32Ne, I32LtS, I32LtU, I32LeS, I32LeU, I32And, I32Or, I32Nand, I32Nor,
  I64Eq, I64Ne, I64LtS, I64LtU, I64LeS, I64LeU, I64And, I64Or, I64Nand, I64Nor,
  F32Eq, F32Ne, F32Lt, F32Le, F32NotLt, F32NotLe, F64Eq, F64Ne, F64Lt, F64Le, F64NotLt,
  F64NotLe,
]

///|
/// Upstream `TryFrom<u32> for Comparator`.
pub fn Comparator::try_from_u32(value : UInt) -> Comparator raise Error {
  if value >= comparators.length().reinterpret_as_uint() {
    raise Error::ComparatorOutOfBounds
  }
  comparators[value.reinterpret_as_int()]
}

///|
/// Upstream `From<Comparator> for u32` (`cmp as u32`).
pub fn Comparator::to_u32(self : Comparator) -> UInt {
  let mut i = 0
  while i < comparators.length() {
    if comparators[i] == self {
      return i.reinterpret_as_uint()
    }
    i += 1
  }
  abort("unreachable")
}

///|
/// Encodes the parameters for the [`Op::BranchCmpFallback`] instruction.
pub(all) struct ComparatorAndOffset {
  /// Encodes the actual binary operator for the conditional branch.
  cmp : Comparator
  /// Encodes the 32-bit branching offset.
  offset : BranchOffset
} derive(Eq, Debug)

///|
/// Create a new [`ComparatorAndOffset`].
pub fn ComparatorAndOffset::new(
  cmp : Comparator,
  offset : BranchOffset,
) -> ComparatorAndOffset {
  { cmp, offset }
}

///|
/// Creates a new [`ComparatorAndOffset`] from the given `u64` value.
///
/// Returns `None` if the `value` is not a valid [`ComparatorAndOffset`] encoding.
pub fn ComparatorAndOffset::from_u64(value : UInt64) -> ComparatorAndOffset? {
  let hi = (value >> 32).to_uint()
  let lo = (value & 0xFFFF_FFFFUL).to_uint()
  let cmp = Comparator::try_from_u32(hi) catch { _ => return None }
  let offset = BranchOffset::from_i32(lo.reinterpret_as_int())
  Some({ cmp, offset })
}

///|
/// Converts the [`ComparatorAndOffset`] into an `u64` value.
pub fn ComparatorAndOffset::as_u64(self : ComparatorAndOffset) -> UInt64 {
  let hi = self.cmp.to_u32().to_uint64()
  let lo = self.offset.to_i32().to_int64().reinterpret_as_uint64()
  (hi << 32) | lo
}

///|
/// A typed shift amount for shift and rotate instructions (upstream
/// `ShiftAmount<T>`, a [`Const16`]).
pub(all) struct ShiftAmount(Const16) derive(Eq, Hash, Debug)

///|
/// Upstream `From<ShiftAmount<T>> for T` (`i32`).
pub fn ShiftAmount::to_i32(self : ShiftAmount) -> Int {
  self.0.to_i32()
}

///|
/// Upstream `From<ShiftAmount<i64>> for i64`.
pub fn ShiftAmount::to_i64(self : ShiftAmount) -> Int64 {
  self.0.to_i64()
}

///|
/// Upstream `From<ShiftAmount<u32>> for u32`.
pub fn ShiftAmount::to_u32(self : ShiftAmount) -> UInt {
  self.0.to_u32()
}

///|
/// Upstream `IntoShiftAmount for i32`: the shift amount `input % 32`, `None`
/// if it is zero.
pub fn ShiftAmount::of_i32(input : Int) -> ShiftAmount? {
  let value = input % 32
  if value == 0 {
    return None
  }
  Some(ShiftAmount(Const16::from_i16(value)))
}

///|
/// Upstream `IntoShiftAmount for i64`: the shift amount `input % 64`, `None`
/// if it is zero.
pub fn ShiftAmount::of_i64(input : Int64) -> ShiftAmount? {
  let value = (input % 64L).to_int()
  if value == 0 {
    return None
  }
  Some(ShiftAmount(Const16::from_i16(value)))
}

///|
/// Upstream `IntoShiftAmount for u8/u16/u32/u64` with `bits` the bit width of
/// the type: the shift amount `input % bits`, `None` if it is zero.
pub fn ShiftAmount::of_u32(input : UInt, bits : UInt) -> ShiftAmount? {
  let value = (input % bits).reinterpret_as_int()
  if value == 0 {
    return None
  }
  Some(ShiftAmount(Const16::from_u16(value)))
}

///|
/// A 64-bit memory address offset.
pub(all) struct Offset64(UInt64) derive(Eq, Hash, Debug)

///|
/// The high 32 bits of an [`Offset64`].
pub(all) struct Offset64Hi(UInt) derive(Eq, Hash, Debug)

///|
/// The low 32 bits of an [`Offset64`].
pub(all) struct Offset64Lo(UInt) derive(Eq, Hash, Debug)

///|
/// Creates a new [`Offset64`] lo-hi pair from the given `offset`.
pub fn Offset64::split(offset : UInt64) -> (Offset64Hi, Offset64Lo) {
  let offset_lo = (offset & 0xFFFF_FFFFUL).to_uint()
  let offset_hi = (offset >> 32).to_uint()
  (Offset64Hi(offset_hi), Offset64Lo(offset_lo))
}

///|
/// Combines the given [`Offset64`] lo-hi pair into an [`Offset64`].
pub fn Offset64::combine(hi : Offset64Hi, lo : Offset64Lo) -> Offset64 {
  Offset64((hi.0.to_uint64() << 32) | lo.0.to_uint64())
}

///|
/// Upstream `From<Offset64> for u64`.
pub fn Offset64::to_u64(self : Offset64) -> UInt64 {
  self.0
}

///|
/// An 8-bit encoded load or store address offset.
pub(all) struct Offset8(Int) derive(Eq, Hash, Debug)

///|
/// Upstream `TryFrom<u64> for Offset8`.
pub fn Offset8::try_from_u64(address : UInt64) -> Offset8? {
  if address <= 0xFFUL {
    Some(Offset8(address.to_int()))
  } else {
    None
  }
}

///|
/// Upstream `From<Offset8> for Offset64`.
pub fn Offset8::to_u64(self : Offset8) -> UInt64 {
  self.0.to_uint64()
}

///|
/// A 16-bit encoded load or store address offset (upstream `Const16<u64>`).
pub(all) struct Offset16(Int) derive(Eq, Hash, Debug)

///|
/// Upstream `TryFrom<u64> for Offset16`.
pub fn Offset16::try_from_u64(address : UInt64) -> Offset16? {
  if address <= 0xFFFFUL {
    Some(Offset16(address.to_int()))
  } else {
    None
  }
}

///|
/// Upstream `From<Offset16> for Offset64`.
pub fn Offset16::to_u64(self : Offset16) -> UInt64 {
  self.0.to_uint64()
}

///|
/// A 64-bit memory address used for some load and store instructions.
pub(all) struct Address(UInt64) derive(Eq, Hash, Debug)

///|
/// Upstream `TryFrom<u64> for Address` (`usize` is 64-bit).
pub fn Address::try_from_u64(address : UInt64) -> Address? {
  Some(Address(address))
}

///|
/// Upstream `From<Address> for u64`.
pub fn Address::to_u64(self : Address) -> UInt64 {
  self.0
}

///|
/// A 32-bit memory address used for some load and store instructions.
pub(all) struct Address32(UInt) derive(Eq, Hash, Debug)

///|
/// Upstream `TryFrom<Address> for Address32`.
pub fn Address32::try_from_address(address : Address) -> Address32? {
  if address.0 > 0xFFFF_FFFFUL {
    None
  } else {
    Some(Address32(address.0.to_uint()))
  }
}

///|
/// Upstream `From<Address32> for usize`/`u64`.
pub fn Address32::to_u64(self : Address32) -> UInt64 {
  self.0.to_uint64()
}

///|
/// A SIMD lane index immediate (upstream `ImmLaneIdx<N>`).
pub(all) struct ImmLaneIdx(Int) derive(Eq, Hash, Debug)
