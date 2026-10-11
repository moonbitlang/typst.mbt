// Port of wasmparser 0.228.0 `src/readers/core/operators.rs`. The `Operator`
// enum itself is generated (`readers_core_operators_gen.mbt`).

///|
/// Represents a block type.
pub(all) enum BlockType {
  /// The block produces consumes nor produces any values.
  Empty
  /// The block produces a singular value of the given type ([] -> \[t]).
  Type(ValType)
  /// The block is described by a function type.
  ///
  /// The index is to a function type in the types section.
  FuncType(UInt)
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BlockType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BlockType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BlockType with @debug.Debug::{to_repr}

///|
/// The kind of a control flow `Frame`.
pub(all) enum FrameKind {
  /// A Wasm `block` control block.
  Block
  /// A Wasm `if` control block.
  If
  /// A Wasm `else` control block.
  Else
  /// A Wasm `loop` control block.
  Loop
  /// A Wasm `try` control block.
  ///
  /// # Note
  ///
  /// This belongs to the Wasm exception handling proposal.
  TryTable
  /// A Wasm legacy `try` control block.
  ///
  /// # Note
  ///
  /// See: `WasmFeatures::legacy_exceptions` Note in `crates/wasmparser/src/features.rs`
  LegacyTry
  /// A Wasm legacy `catch` control block.
  ///
  /// # Note
  ///
  /// See: `WasmFeatures::legacy_exceptions` Note in `crates/wasmparser/src/features.rs`
  LegacyCatch
  /// A Wasm legacy `catch_all` control block.
  ///
  /// # Note
  ///
  /// See: `WasmFeatures::legacy_exceptions` Note in `crates/wasmparser/src/features.rs`
  LegacyCatchAll
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FrameKind with @debug.Debug::{to_repr}

///|
/// Represents a memory immediate in a WebAssembly memory instruction.
pub(all) struct MemArg {
  /// Alignment, stored as `n` where the actual alignment is `2^n`
  align : Byte
  /// Maximum alignment, stored as `n` where the actual alignment is `2^n`.
  ///
  /// Note that this field is not actually read from the binary format, it
  /// will be a constant depending on which instruction this `MemArg` is a
  /// payload for.
  max_align : Byte
  /// A fixed byte-offset that this memory immediate specifies.
  ///
  /// Note that the memory64 proposal can specify a full 64-bit byte offset
  /// while otherwise only 32-bit offsets are allowed. Once validated
  /// memory immediates for 32-bit memories are guaranteed to be at most
  /// `u32::MAX` whereas 64-bit memories can use the full 64-bits.
  offset : UInt64
  /// The index of the memory this immediate points to.
  ///
  /// Note that this points within the module's own memory index space, and
  /// is always zero unless the multi-memory proposal of WebAssembly is
  /// enabled.
  memory : UInt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemArg with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemArg with @debug.Debug::{to_repr}

///|
/// A br_table entries representation.
///
/// Upstream keeps a reader over the targets; they are already decoded here.
pub(all) struct BrTable {
  priv targets : Array[UInt]
  priv default : UInt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BrTable with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BrTable with @debug.Debug::{to_repr}

///|
/// An IEEE binary32 immediate floating point value, represented as a u32
/// containing the bit pattern.
///
/// All bit patterns are allowed.
pub(all) struct Ieee32(UInt) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ieee32 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ieee32 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ieee32 with @debug.Debug::{to_repr}

///|
/// Gets the underlying bits of the 32-bit float.
pub fn Ieee32::bits(self : Ieee32) -> UInt {
  self.0
}

///|
/// An IEEE binary64 immediate floating point value, represented as a u64
/// containing the bit pattern.
///
/// All bit patterns are allowed.
pub(all) struct Ieee64(UInt64) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ieee64 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ieee64 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ieee64 with @debug.Debug::{to_repr}

///|
/// Gets the underlying bits of the 64-bit float.
pub fn Ieee64::bits(self : Ieee64) -> UInt64 {
  self.0
}

///|
/// Represents a 128-bit vector value (16 bytes, little endian).
///
/// Upstream `V128`, a reserved type name in MoonBit.
pub(all) struct V128Value(Bytes) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend V128Value with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend V128Value with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend V128Value with @debug.Debug::{to_repr}

///|
/// Gets the bytes of the 128-bit vector value.
pub fn V128Value::bytes(self : V128Value) -> Bytes {
  self.0
}

///|
/// Represents the memory ordering for atomic instructions.
///
/// For an in-depth explanation of memory orderings, see the C++ documentation
/// for [`memory_order`] or the Rust documentation for [`atomic::Ordering`].
///
/// [`memory_order`]: https://en.cppreference.com/w/cpp/atomic/memory_order
/// [`atomic::Ordering`]: https://doc.rust-lang.org/std/sync/atomic/enum.Ordering.html
pub(all) enum Ordering {
  /// For a load, it acquires; this orders all operations before the last
  /// "releasing" store. For a store, it releases; this orders all
  /// operations before it at the next "acquiring" load.
  AcqRel
  /// Like `AcqRel` but all threads see all sequentially consistent
  /// operations in the same order.
  SeqCst
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ordering with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ordering with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ordering with @debug.Debug::{to_repr}

///|
/// A reader for a core WebAssembly function's operators.
pub struct OperatorsReader {
  priv reader : BinaryReader
}

///|
fn OperatorsReader::new(reader : BinaryReader) -> OperatorsReader {
  { reader, }
}

///|
/// Determines if the reader is at the end of the operators.
pub fn OperatorsReader::eof(self : OperatorsReader) -> Bool {
  self.reader.eof()
}

///|
/// Gets the original position of the reader.
pub fn OperatorsReader::original_position(self : OperatorsReader) -> Int {
  self.reader.original_position()
}

///|
/// Ensures the reader is at the end.
///
/// This function returns an error if there is extra data after the operators.
pub fn OperatorsReader::ensure_end(
  self : OperatorsReader,
) -> Unit raise BinaryReaderError {
  if self.eof() {
    return
  }
  raise BinaryReaderError::new(
    "unexpected data at the end of operators",
    self.reader.original_position(),
  )
}

///|
/// Reads an operator from the reader.
pub fn OperatorsReader::read(
  self : OperatorsReader,
) -> Operator raise BinaryReaderError {
  self.reader.read_operator()
}

///|
/// Reads an operator with its offset.
pub fn OperatorsReader::read_with_offset(
  self : OperatorsReader,
) -> (Operator, Int) raise BinaryReaderError {
  let pos = self.reader.original_position()
  (self.read(), pos)
}

///|
/// Gets a binary reader from this operators reader.
pub fn OperatorsReader::get_binary_reader(
  self : OperatorsReader,
) -> BinaryReader {
  self.reader.clone()
}

///|
/// Returns whether there is an `end` opcode followed by eof remaining in
/// this reader.
pub fn OperatorsReader::is_end_then_eof(self : OperatorsReader) -> Bool {
  self.reader.is_end_then_eof()
}

///|
/// A `try_table` entries representation.
pub(all) struct TryTable {
  /// The block type describing the try block itself.
  ty : BlockType
  /// Outer blocks which will receive exceptions.
  catches : Array[Catch]
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TryTable with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TryTable with @debug.Debug::{to_repr}

///|
/// Catch clauses that can be specified in [`TryTable`].
pub(all) enum Catch {
  /// Equivalent of `catch`
  One(tag~ : UInt, label~ : UInt)
  /// Equivalent of `catch_ref`
  OneRef(tag~ : UInt, label~ : UInt)
  /// Equivalent of `catch_all`
  All(label~ : UInt)
  /// Equivalent of `catch_all_ref`
  AllRef(label~ : UInt)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Catch with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Catch with @debug.Debug::{to_repr}

///|
pub impl FromReader for TryTable with fn from_reader(reader) {
  let ty = reader.read_block_type()
  let n = reader.read_iter(MAX_WASM_CATCHES, "catches")
  let catches = []
  for _ in 0..<n {
    catches.push(Catch::from_reader(reader))
  }
  { ty, catches, }
}

///|
pub extend TryTable with FromReader::{from_reader}

///|
pub impl FromReader for Catch with fn from_reader(reader) {
  match reader.read_u8() {
    0x00 => {
      let tag = reader.read_var_u32()
      let label = reader.read_var_u32()
      One(tag~, label~)
    }
    0x01 => {
      let tag = reader.read_var_u32()
      let label = reader.read_var_u32()
      OneRef(tag~, label~)
    }
    0x02 => All(label=reader.read_var_u32())
    0x03 => AllRef(label=reader.read_var_u32())
    x => reader.invalid_leading_byte(x, "catch")
  }
}

///|
pub extend Catch with FromReader::{from_reader}

///|
/// A representation of dispatch tables on `resume` and `resume_throw`
/// instructions.
pub(all) struct ResumeTable {
  /// Either the outer blocks which will handle suspensions or
  /// "switch-to" handlers.
  handlers : Array[Handle]
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResumeTable with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ResumeTable with @debug.Debug::{to_repr}

///|
/// Handle clauses that can be specified in [`ResumeTable`].
pub(all) enum Handle {
  /// Equivalent of `(on $tag $lbl)`.
  OnLabel(tag~ : UInt, label~ : UInt)
  /// Equivalent of `(on $tag switch)`.
  OnSwitch(tag~ : UInt)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Handle with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Handle with @debug.Debug::{to_repr}

///|
/// Returns the number of entries in the table.
pub fn ResumeTable::len(self : ResumeTable) -> Int {
  self.handlers.length()
}

///|
pub impl FromReader for ResumeTable with fn from_reader(reader) {
  let n = reader.read_iter(MAX_WASM_HANDLERS, "resume table")
  let handlers = []
  for _ in 0..<n {
    handlers.push(Handle::from_reader(reader))
  }
  { handlers, }
}

///|
pub extend ResumeTable with FromReader::{from_reader}

///|
pub impl FromReader for Handle with fn from_reader(reader) {
  match reader.read_u8() {
    0x00 => {
      let tag = reader.read_var_u32()
      let label = reader.read_var_u32()
      OnLabel(tag~, label~)
    }
    0x01 => OnSwitch(tag=reader.read_var_u32())
    x => reader.invalid_leading_byte(x, "on clause")
  }
}

///|
pub extend Handle with FromReader::{from_reader}
