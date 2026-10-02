// Ports of skrifa 0.42.1 `src/outline/glyf/hint/{error, value_stack,
// cow_slice, call_stack, definition, program}.rs` and the bytecode decoder
// from read-fonts 0.39.2 `src/tables/glyf/bytecode`.
//
// Values that upstream stores as `usize` (point indices etc.) are kept as
// `Int` where negative values stand for the huge results of `i32 as usize`.

// ---------------------------------------------------------------------------
// Opcodes

///|
const OP_IF : Int = 0x58

///|
const OP_ELSE : Int = 0x1B

///|
const OP_EIF : Int = 0x59

///|
const OP_FDEF : Int = 0x2C

///|
const OP_IDEF : Int = 0x89

///|
const OP_ENDF : Int = 0x2D

///|
fn opcode_is_push_words(op : Int) -> Bool {
  (op >= 0xB8 && op <= 0xBF) || op == 0x41
}

// ---------------------------------------------------------------------------
// Errors

///|
/// Errors that may occur when interpreting TrueType bytecode.
priv suberror HintErrorKind {
  UnexpectedEndOfBytecode
  UnhandledOpcode(Int)
  DefinitionInGlyphProgram
  NestedDefinition
  DefinitionTooLarge
  TooManyDefinitions
  InvalidDefinition(Int)
  ValueStackOverflow
  ValueStackUnderflow
  CallStackOverflow
  CallStackUnderflow
  InvalidStackValue(Int)
  InvalidPointIndex(Int)
  InvalidPointRange(Int, Int)
  InvalidContourIndex(Int)
  InvalidCvtIndex(Int)
  InvalidStorageIndex(Int)
  DivideByZero
  InvalidZoneIndex(Int)
  NegativeLoopCounter
  InvalidJump
  ExceededExecutionBudget
}

///|
/// `usize` display of an index stored as `Int`.
fn usize_str(v : Int) -> String {
  v.to_int64().reinterpret_as_uint64().to_string()
}

///|
fn HintErrorKind::message(self : HintErrorKind) -> String {
  match self {
    UnexpectedEndOfBytecode => "unexpected end of bytecode"
    UnhandledOpcode(opcode) =>
      "unhandled instruction opcode \{opcode_names[opcode & 0xFF]}"
    DefinitionInGlyphProgram =>
      "function or instruction definition present in glyph program"
    NestedDefinition => "nested function or instruction definition"
    DefinitionTooLarge =>
      "function or instruction definition exceeded the maximum size of 64k"
    TooManyDefinitions => "too many function or instruction definitions"
    InvalidDefinition(key) =>
      "function or instruction definition \{usize_str(key)} not found"
    ValueStackOverflow => "value stack overflow"
    ValueStackUnderflow => "value stack underflow"
    CallStackOverflow => "call stack overflow"
    CallStackUnderflow => "call stack underflow"
    InvalidStackValue(value) =>
      "stack value \{value} was invalid for the current operation"
    InvalidPointIndex(index) =>
      "point index \{usize_str(index)} was out of bounds"
    InvalidPointRange(start, end) =>
      "point range \{usize_str(start)}..\{usize_str(end)} was out of bounds"
    InvalidContourIndex(index) =>
      "contour index \{usize_str(index)} was out of bounds"
    InvalidCvtIndex(index) => "cvt index \{usize_str(index)} was out of bounds"
    InvalidStorageIndex(index) =>
      "storage area index \{usize_str(index)} was out of bounds"
    DivideByZero => "attempt to divide by 0"
    InvalidZoneIndex(index) =>
      "zone index \{index} was invalid (only 0 or 1 are permitted)"
    NegativeLoopCounter => "attempt to set the loop counter to a negative value"
    InvalidJump => "the target of a jump instruction was invalid"
    ExceededExecutionBudget => "too many instructions executed"
  }
}

///|
/// Describes the source for a piece of bytecode.
priv enum Program {
  /// Program that initializes the function and instruction tables (fpgm).
  Font
  /// Program that initializes CVT and storage (prep).
  ControlValue
  /// Glyph specified program.
  Glyph
} derive(Eq)

///|
fn Program::index(self : Program) -> Int {
  match self {
    Font => 0
    ControlValue => 1
    Glyph => 2
  }
}

///|
/// Hinting error with additional context.
priv suberror HintError {
  HintError(
    program~ : Program,
    glyph_id~ : GlyphId?,
    pc~ : Int,
    opcode~ : Int?,
    kind~ : HintErrorKind
  )
}

///|
fn HintError::message(self : HintError) -> String {
  let HintError(program~, glyph_id~, pc~, opcode~, kind~) = self
  let sb = StringBuilder()
  sb.write_string(
    match program {
      ControlValue => "prep"
      Font => "fpgm"
      Glyph => "glyf"
    },
  )
  if glyph_id is Some(gid) {
    sb.write_string("[\{gid.to_u32()}]")
  }
  let (opcode, colon) = match opcode {
    Some(op) => (opcode_names[op & 0xFF], ":")
    None => ("", "")
  }
  sb.write_string("@\{usize_str(pc)}:\{opcode}\{colon} \{kind.message()}")
  sb.to_string()
}

// ---------------------------------------------------------------------------
// Decoder

///|
/// Decoded TrueType instruction.
priv struct Instruction {
  opcode : Int
  /// Inline operand bytes (push instructions only).
  operands : BytesView
  is_words : Bool
  /// Offset into the bytecode where this instruction was decoded.
  pc : Int
}

///|
fn Instruction::operand_count(self : Instruction) -> Int {
  if self.is_words {
    self.operands.length() / 2
  } else {
    self.operands.length()
  }
}

///|
fn Instruction::operand(self : Instruction, i : Int) -> Int {
  if self.is_words {
    let w = (self.operands[i * 2].to_int() << 8) |
      self.operands[i * 2 + 1].to_int()
    w << 16 >> 16
  } else {
    self.operands[i].to_int()
  }
}

///|
/// Decodes instructions from TrueType bytecode.
priv struct Decoder {
  mut bytecode : BytesView
  mut pc : Int
}

///|
/// Decodes the next instruction. Returns `None` at the end of the bytecode
/// stream and `Some(None)` on a decode error.
fn Decoder::decode(self : Decoder) -> Instruction?? {
  let pc = self.pc
  if pc < 0 || pc >= self.bytecode.length() {
    return None
  }
  let opcode = self.bytecode[pc].to_int()
  let mut opcode_len = opcode_lengths[opcode]
  let mut count_len = 0
  // If the opcode length is negative the next byte contains the number
  // of inline operands and |opcode_len| is the size of each operand.
  if opcode_len < 0 {
    if pc + 1 >= self.bytecode.length() {
      return Some(None)
    }
    let inline_count = self.bytecode[pc + 1].to_int()
    opcode_len = -opcode_len * inline_count + 2
    count_len = 1
  }
  let next_pc = pc + opcode_len
  // Skip opcode and potential inline operand count byte.
  let inline_start = pc + 1 + count_len
  let inline_size = next_pc - inline_start
  let mut operands = b""[:]
  let mut is_words = false
  if inline_size > 0 {
    if inline_start + inline_size > self.bytecode.length() {
      return Some(None)
    }
    operands = self.bytecode[inline_start:inline_start + inline_size]
    is_words = opcode_is_push_words(opcode)
  }
  self.pc = pc + opcode_len
  Some(Some({ opcode, operands, is_words, pc, }))
}

// ---------------------------------------------------------------------------
// Value stack

///|
/// Value stack for the TrueType interpreter.
priv struct ValueStack {
  values : FixedArray[Int]
  mut len : Int
  is_pedantic : Bool
}

///|
fn ValueStack::new(size : Int, is_pedantic : Bool) -> ValueStack {
  { values: FixedArray::make(size, 0), len: 0, is_pedantic, }
}

///|
fn ValueStack::push(self : ValueStack, value : Int) -> Unit raise HintErrorKind {
  if self.len >= self.values.length() {
    raise ValueStackOverflow
  }
  self.values[self.len] = value
  self.len += 1
}

///|
/// Pushes values that have been decoded from the instruction stream.
fn ValueStack::push_inline_operands(
  self : ValueStack,
  ins : Instruction,
) -> Unit raise HintErrorKind {
  let push_count = ins.operand_count()
  let stack_base = self.len
  if stack_base + push_count > self.values.length() {
    raise ValueStackOverflow
  }
  for i in 0..<push_count {
    self.values[stack_base + i] = ins.operand(i)
  }
  self.len += push_count
}

///|
fn ValueStack::peek(self : ValueStack) -> Int? {
  if self.len > 0 {
    Some(self.values[self.len - 1])
  } else {
    None
  }
}

///|
fn ValueStack::pop(self : ValueStack) -> Int raise HintErrorKind {
  if self.peek() is Some(value) {
    self.len -= 1
    value
  } else if self.is_pedantic {
    raise ValueStackUnderflow
  } else {
    0
  }
}

///|
/// Convenience method for popping a value intended as a count.
fn ValueStack::pop_count_checked(self : ValueStack) -> Int raise HintErrorKind {
  let value = self.pop()
  if value < 0 && self.is_pedantic {
    raise InvalidStackValue(value)
  } else if value < 0 {
    0
  } else {
    value
  }
}

///|
fn ValueStack::apply_unary(
  self : ValueStack,
  op : (Int) -> Int,
) -> Unit raise HintErrorKind {
  let a = self.pop()
  self.push(op(a))
}

///|
fn ValueStack::apply_binary(
  self : ValueStack,
  op : (Int, Int) -> Int raise HintErrorKind,
) -> Unit raise HintErrorKind {
  let b = self.pop()
  let a = self.pop()
  self.push(op(a, b))
}

///|
fn ValueStack::clear(self : ValueStack) -> Unit {
  self.len = 0
}

///|
fn ValueStack::dup(self : ValueStack) -> Unit raise HintErrorKind {
  if self.peek() is Some(value) {
    self.push(value)
  } else if self.is_pedantic {
    raise ValueStackUnderflow
  } else {
    self.push(0)
  }
}

///|
fn ValueStack::swap(self : ValueStack) -> Unit raise HintErrorKind {
  let a = self.pop()
  let b = self.pop()
  self.push(a)
  self.push(b)
}

///|
/// Copy the indexed element to the top of the stack (CINDEX).
fn ValueStack::copy_index(self : ValueStack) -> Unit raise HintErrorKind {
  if self.len == 0 {
    raise ValueStackUnderflow
  }
  let top_ix = self.len - 1
  let index = self.values[top_ix]
  if index < 0 || index > top_ix {
    raise ValueStackUnderflow
  }
  let element_ix = top_ix - index
  self.values[top_ix] = self.values[element_ix]
}

///|
/// Moves the indexed element to the top of the stack (MINDEX).
fn ValueStack::move_index(self : ValueStack) -> Unit raise HintErrorKind {
  if self.len == 0 {
    raise ValueStackUnderflow
  }
  let top_ix = self.len - 1
  let index = self.values[top_ix]
  if index < 0 || index > top_ix {
    raise ValueStackUnderflow
  }
  let element_ix = top_ix - index
  if top_ix == 0 {
    raise ValueStackUnderflow
  }
  let new_top_ix = top_ix - 1
  let value = self.values[element_ix]
  for i in element_ix..<(self.len - 1) {
    self.values[i] = self.values[i + 1]
  }
  self.values[new_top_ix] = value
  self.len -= 1
}

///|
/// Roll the top three stack elements (ROLL).
fn ValueStack::roll(self : ValueStack) -> Unit raise HintErrorKind {
  let a = self.pop()
  let b = self.pop()
  let c = self.pop()
  self.push(b)
  self.push(a)
  self.push(c)
}

// ---------------------------------------------------------------------------
// Copy-on-write CVT / storage

///|
/// Copy-on-write buffer for the CVT and storage area.
priv struct CowSlice {
  data : FixedArray[Int]
  data_mut : FixedArray[Int]
  mut use_mut : Bool
}

///|
fn CowSlice::new(data : FixedArray[Int]) -> CowSlice {
  { data, data_mut: FixedArray::make(data.length(), 0), use_mut: false, }
}

///|
fn CowSlice::new_mut(data_mut : FixedArray[Int]) -> CowSlice {
  { data: [], data_mut, use_mut: true, }
}

///|
fn CowSlice::get(self : CowSlice, index : Int) -> Int? {
  let d = if self.use_mut { self.data_mut } else { self.data }
  if index < 0 || index >= d.length() {
    None
  } else {
    Some(d[index])
  }
}

///|
fn CowSlice::set(self : CowSlice, index : Int, value : Int) -> Bool {
  // Copy from immutable to mutable buffer if we haven't already
  if !self.use_mut {
    for i in 0..<self.data.length() {
      self.data_mut[i] = self.data[i]
    }
    self.use_mut = true
  }
  if index < 0 || index >= self.data_mut.length() {
    false
  } else {
    self.data_mut[index] = value
    true
  }
}

///|
fn CowSlice::len(self : CowSlice) -> Int {
  if self.use_mut {
    self.data_mut.length()
  } else {
    self.data.length()
  }
}

///|
fn CowSlice::cvt_get(self : CowSlice, index : Int) -> Int raise HintErrorKind {
  match self.get(index) {
    Some(v) => v
    None => raise InvalidCvtIndex(index)
  }
}

///|
fn CowSlice::cvt_set(
  self : CowSlice,
  index : Int,
  value : Int,
) -> Unit raise HintErrorKind {
  if !self.set(index, value) {
    raise InvalidCvtIndex(index)
  }
}

///|
fn CowSlice::storage_get(
  self : CowSlice,
  index : Int,
) -> Int raise HintErrorKind {
  match self.get(index) {
    Some(v) => v
    None => raise InvalidStorageIndex(index)
  }
}

///|
fn CowSlice::storage_set(
  self : CowSlice,
  index : Int,
  value : Int,
) -> Unit raise HintErrorKind {
  if !self.set(index, value) {
    raise InvalidStorageIndex(index)
  }
}

// ---------------------------------------------------------------------------
// Definitions

///|
/// Code range and properties for a function or instruction definition.
priv struct Definition {
  start : Int
  end : Int
  /// The function number for an FDEF or opcode for an IDEF.
  key : Int
  program : Int
  is_active : Bool
}

///|
fn Definition::default() -> Definition {
  { start: 0, end: 0, key: 0, program: 0, is_active: false, }
}

///|
fn Definition::new(
  program : Program,
  start : Int,
  end : Int,
  key : Int,
) -> Definition {
  { program: program.index(), start, end, key, is_active: true, }
}

///|
fn Definition::program(self : Definition) -> Program {
  match self.program {
    0 => Font
    1 => ControlValue
    _ => Glyph
  }
}

///|
/// Map of function number or opcode to code definitions.
priv struct DefinitionMap {
  defs : Array[Definition]
  is_mut : Bool
}

///|
/// Attempts to allocate a new definition entry with the given key and
/// returns its index.
fn DefinitionMap::allocate(
  self : DefinitionMap,
  key : Int,
) -> Int raise HintErrorKind {
  if !self.is_mut {
    raise DefinitionInGlyphProgram
  }
  let defs = self.defs
  // First, see if we can use key as an index.
  let ix = if key >= 0 &&
    key < defs.length() &&
    (!defs[key].is_active || defs[key].key == key) {
    key
  } else {
    // Otherwise, walk backward looking for an active entry with
    // a matching key. Keep track of the inactive entry with the
    // highest index.
    let mut last_inactive_ix : Int? = None
    for i = defs.length() - 1; i >= 0; i = i - 1 {
      let def = defs[i]
      if def.is_active {
        if def.key == key {
          last_inactive_ix = Some(i)
          break
        }
      } else if last_inactive_ix is None {
        last_inactive_ix = Some(i)
      }
    }
    match last_inactive_ix {
      Some(i) => i
      None => raise TooManyDefinitions
    }
  }
  defs[ix] = Definition::new(Font, 0, 0, key)
  ix
}

///|
/// Returns the definition with the given key.
fn DefinitionMap::get(
  self : DefinitionMap,
  key : Int,
) -> Definition raise HintErrorKind {
  let defs = self.defs
  // Fast path, try to use key as index.
  if key >= 0 && key < defs.length() {
    let def = defs[key]
    if def.is_active && def.key == key {
      return def
    }
  }
  // Otherwise, walk backward doing a linear search.
  for i = defs.length() - 1; i >= 0; i = i - 1 {
    let def = defs[i]
    if def.is_active && def.key == key {
      return def
    }
  }
  raise InvalidDefinition(key)
}

///|
/// If the map is mutable, resets all definitions to the default value.
fn DefinitionMap::reset(self : DefinitionMap) -> Unit {
  if self.is_mut {
    for i in 0..<self.defs.length() {
      self.defs[i] = Definition::default()
    }
  }
}

// ---------------------------------------------------------------------------
// Call stack and program state

///|
/// Record of an active invocation of a function or instruction definition.
priv struct CallRecord {
  caller_program : Program
  return_pc : Int
  mut current_count : Int
  definition : Definition
}

///|
// FreeType provides a call stack with a depth of 32.
const MAX_CALL_DEPTH : Int = 32

///|
/// State for managing active programs and decoding instructions.
priv struct ProgramState {
  /// Bytecode for each of the three program types, indexed by `Program`.
  bytecode : FixedArray[BytesView]
  /// The initial program when execution begins.
  mut initial : Program
  /// The currently active program.
  mut current : Program
  /// Instruction decoder for the currently active program.
  decoder : Decoder
  /// Tracks nested function and instruction invocations.
  call_stack : Array[CallRecord]
}

///|
fn ProgramState::new(
  font_code : BytesView,
  cv_code : BytesView,
  glyph_code : BytesView,
  initial_program : Program,
) -> ProgramState {
  let bytecode : FixedArray[BytesView] = [font_code, cv_code, glyph_code]
  {
    bytecode,
    initial: initial_program,
    current: initial_program,
    decoder: { bytecode: bytecode[initial_program.index()], pc: 0, },
    call_stack: [],
  }
}

///|
/// Resets the state for execution of the given program.
fn ProgramState::reset(self : ProgramState, program : Program) -> Unit {
  self.initial = program
  self.current = program
  self.decoder.bytecode = self.bytecode[program.index()]
  self.decoder.pc = 0
  self.call_stack.clear()
}

///|
/// Jumps to the code in the given definition and sets it up for execution
/// `count` times.
fn ProgramState::enter(
  self : ProgramState,
  definition : Definition,
  count : Int,
) -> Unit raise HintErrorKind {
  let program = definition.program()
  let pc = definition.start
  let bytecode = self.bytecode[program.index()]
  if self.call_stack.length() >= MAX_CALL_DEPTH {
    raise CallStackOverflow
  }
  self.call_stack.push({
    caller_program: self.current,
    return_pc: self.decoder.pc,
    current_count: count,
    definition,
  })
  self.current = program
  self.decoder.bytecode = bytecode
  self.decoder.pc = pc
}

///|
/// Leaves the code from the definition on the top of the stack.
fn ProgramState::leave(self : ProgramState) -> Unit raise HintErrorKind {
  guard self.call_stack.pop() is Some(record) else { raise CallStackUnderflow }
  if record.current_count.reinterpret_as_uint() > 1U {
    // This is a loop call with some iterations remaining.
    record.current_count -= 1
    self.decoder.pc = record.definition.start
    self.call_stack.push(record)
  } else {
    self.current = record.caller_program
    // Reset the decoder to the calling program and program counter.
    self.decoder.bytecode = self.bytecode[record.caller_program.index()]
    self.decoder.pc = record.return_pc
  }
}
