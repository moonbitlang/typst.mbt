// Port of wasmi 1.0.9 `engine/translator/func/stack/{mod,operand,operands,locals,control}.rs`.

// ---------------------------------------------------------------------------
// operand.rs

///|
/// An operand on the [`Stack`].
pub(all) enum Operand {
  /// A local variable operand.
  Local(LocalOperand)
  /// A temporary operand.
  Temp(TempOperand)
  /// An immediate value operand.
  Immediate(ImmediateOperand)
}

///|
/// A local variable on the [`Stack`].
pub(all) struct LocalOperand {
  /// The index of the operand.
  operand_index : OperandIdx
  /// The index of the local variable.
  local_index : LocalIdx
  /// The type of the local variable.
  ty : @wasmi_core.ValType
}

///|
/// A temporary on the [`Stack`].
pub(all) struct TempOperand {
  /// The index of the operand.
  operand_index : OperandIdx
  /// The type of the temporary.
  ty : @wasmi_core.ValType
  /// The instruction which created this [`TempOperand`] as its result if any.
  instr : Instr?
}

///|
/// An immediate value on the [`Stack`].
pub(all) struct ImmediateOperand {
  /// The index of the operand.
  operand_index : OperandIdx
  /// The value and type of the immediate value.
  val : @wasmi_core.TypedVal
}

///|
fn Operand::new(index : OperandIdx, operand : StackOperand) -> Operand {
  match operand {
    Local(link) =>
      Local({
        operand_index: index,
        local_index: link.local_index,
        ty: link.ty,
      })
    Temp(ty~, instr~) => Temp({ operand_index: index, ty, instr, })
    Immediate(val~) => Immediate({ operand_index: index, val, })
  }
}

///|
/// Returns `true` if `self` and `other` evaluate to the same value.
pub fn Operand::is_same(self : Operand, other : Operand) -> Bool {
  match (self, other) {
    (Local(lhs), Local(rhs)) => lhs.local_index == rhs.local_index
    (Temp(lhs), Temp(rhs)) => lhs.operand_index == rhs.operand_index
    (Immediate(lhs), Immediate(rhs)) => lhs.val == rhs.val
    _ => false
  }
}

///|
/// Returns `true` if `self` is an [`Operand::Temp`].
pub fn Operand::is_temp(self : Operand) -> Bool {
  self is Temp(_)
}

///|
/// Returns the [`OperandIdx`] of the [`Operand`].
pub fn Operand::index(self : Operand) -> OperandIdx {
  match self {
    Local(operand) => operand.operand_index
    Temp(operand) => operand.operand_index
    Immediate(operand) => operand.operand_index
  }
}

///|
/// Returns the type of the [`Operand`].
pub fn Operand::ty(self : Operand) -> @wasmi_core.ValType {
  match self {
    Local(operand) => operand.ty
    Temp(operand) => operand.ty
    Immediate(operand) => operand.val.ty()
  }
}

///|
pub fn LocalOperand::operand_index(self : LocalOperand) -> OperandIdx {
  self.operand_index
}

///|
pub fn LocalOperand::local_index(self : LocalOperand) -> LocalIdx {
  self.local_index
}

///|
pub fn TempOperand::operand_index(self : TempOperand) -> OperandIdx {
  self.operand_index
}

///|
pub fn TempOperand::instr(self : TempOperand) -> Instr? {
  self.instr
}

///|
pub fn ImmediateOperand::operand_index(self : ImmediateOperand) -> OperandIdx {
  self.operand_index
}

///|
pub fn ImmediateOperand::val(self : ImmediateOperand) -> @wasmi_core.TypedVal {
  self.val
}

///|
pub fn ImmediateOperand::ty(self : ImmediateOperand) -> @wasmi_core.ValType {
  self.val.ty()
}

// ---------------------------------------------------------------------------
// operands.rs

///|
/// A [`StackOperand`] or [`Operand`] index on the operand stack.
pub(all) struct OperandIdx(Int) derive(Eq, Debug)

///|
/// The links of a local variable operand on the operand stack.
priv struct LocalLink {
  /// The index of the local variable.
  local_index : LocalIdx
  /// The type of the local variable.
  ty : @wasmi_core.ValType
  /// The previous local on the stack with the same local index.
  mut prev_local : OperandIdx?
  /// The next local on the stack with the same local index.
  mut next_local : OperandIdx?
}

///|
/// An operand on the [`OperandStack`].
priv enum StackOperand {
  /// A local variable.
  Local(LocalLink)
  /// A temporary value on the [`Stack`].
  Temp(ty~ : @wasmi_core.ValType, instr~ : Instr?)
  /// An immediate value on the [`Stack`].
  Immediate(val~ : @wasmi_core.TypedVal)
}

///|
fn StackOperand::ty(self : StackOperand) -> @wasmi_core.ValType {
  match self {
    Temp(ty~, ..) => ty
    Immediate(val~) => val.ty()
    Local(link) => link.ty
  }
}

///|
/// The Wasm operand (or value) stack.
priv struct OperandStack {
  /// The current set of operands on the [`OperandStack`].
  operands : Array[StackOperand]
  /// Stores the first operand for every local on the [`OperandStack`].
  ///
  /// Upstream `LocalsHead` (locals.rs).
  local_heads : Array[OperandIdx?]
  /// The maximum height of the [`OperandStack`].
  mut max_height : Int
  /// The number of locals on the [`OperandStack`].
  mut len_locals : Int
}

///|
fn OperandStack::new() -> OperandStack {
  { operands: [], local_heads: [], max_height: 0, len_locals: 0, }
}

///|
// Upstream resets recycled allocations (`impl Reset`, stack/operands.rs:87,
// stack/control.rs:92; `Stack::new`, stack/mod.rs:88); this port builds a
// fresh stack per function and does not recycle.
#warnings("-unused_value")
fn OperandStack::reset(self : OperandStack) -> Unit {
  self.operands.clear()
  self.local_heads.clear()
  self.max_height = 0
  self.len_locals = 0
}

///|
/// Register `amount` local variables of common type `ty`.
fn OperandStack::register_locals(self : OperandStack, amount : Int) -> Unit {
  for _ in 0..<amount {
    self.local_heads.push(None)
  }
}

///|
/// Replaces the first operand of the local at `index` (upstream
/// `LocalsHead::replace_first`), returning the old one.
fn OperandStack::replace_first(
  self : OperandStack,
  index : LocalIdx,
  first_operand : OperandIdx?,
) -> OperandIdx? {
  let index = index.0.reinterpret_as_int()
  let old = self.local_heads[index]
  self.local_heads[index] = first_operand
  old
}

///|
fn OperandStack::height(self : OperandStack) -> Int {
  self.operands.length()
}

///|
fn OperandStack::max_height(self : OperandStack) -> Int {
  self.max_height
}

///|
fn OperandStack::update_max_stack_height(self : OperandStack) -> Unit {
  if self.height() > self.max_height {
    self.max_height = self.height()
  }
}

///|
fn OperandStack::next_index(self : OperandStack) -> OperandIdx {
  OperandIdx(self.operands.length())
}

///|
fn OperandStack::depth_to_index(self : OperandStack, depth : Int) -> OperandIdx {
  OperandIdx(self.height() - depth - 1)
}

///|
fn OperandStack::push_operand(
  self : OperandStack,
  operand : Operand,
) -> OperandIdx {
  match operand {
    Local(operand) => self.push_local(operand.local_index, operand.ty)
    Temp(operand) => self.push_temp(operand.ty, operand.instr)
    Immediate(operand) => self.push_immediate(operand.val)
  }
}

///|
fn OperandStack::push_local(
  self : OperandStack,
  local_index : LocalIdx,
  ty : @wasmi_core.ValType,
) -> OperandIdx {
  let operand_index = self.next_index()
  let next_local = self.replace_first(local_index, Some(operand_index))
  if next_local is Some(next_local) {
    self.update_prev_local(next_local, Some(operand_index))
  }
  self.operands.push(Local({ local_index, ty, prev_local: None, next_local, }))
  self.update_max_stack_height()
  self.len_locals += 1
  operand_index
}

///|
fn OperandStack::push_temp(
  self : OperandStack,
  ty : @wasmi_core.ValType,
  instr : Instr?,
) -> OperandIdx {
  let idx = self.next_index()
  self.operands.push(Temp(ty~, instr~))
  self.update_max_stack_height()
  idx
}

///|
fn OperandStack::push_immediate(
  self : OperandStack,
  value : @wasmi_core.TypedVal,
) -> OperandIdx {
  let idx = self.next_index()
  self.operands.push(Immediate(val=value))
  self.update_max_stack_height()
  idx
}

///|
/// Returns the top-most `n` operands (bottom to top).
fn OperandStack::peek(self : OperandStack, n : Int) -> Array[Operand] {
  let len_operands = self.operands.length()
  let first_index = len_operands - n
  let out = []
  if first_index < 0 {
    return out
  }
  for i in first_index..<len_operands {
    out.push(Operand::new(OperandIdx(i), self.operands[i]))
  }
  out
}

///|
fn OperandStack::pop(self : OperandStack) -> Operand {
  guard self.operands.pop() is Some(operand) else {
    abort("tried to pop operand from empty stack")
  }
  let index = self.next_index()
  self.try_unlink_local(operand)
  Operand::new(index, operand)
}

///|
fn OperandStack::get(self : OperandStack, depth : Int) -> Operand {
  let index = self.depth_to_index(depth)
  let operand = self.get_at(index)
  Operand::new(index, operand)
}

///|
fn OperandStack::get_at(
  self : OperandStack,
  index : OperandIdx,
) -> StackOperand {
  self.operands[index.0]
}

///|
fn OperandStack::operand_to_temp(self : OperandStack, depth : Int) -> Operand {
  let index = self.depth_to_index(depth)
  let operand = self.operand_to_temp_at(index)
  Operand::new(index, operand)
}

///|
fn OperandStack::operand_to_temp_at(
  self : OperandStack,
  index : OperandIdx,
) -> StackOperand {
  let operand = self.get_at(index)
  let ty = operand.ty()
  self.try_unlink_local(operand)
  self.operands[index.0] = Temp(ty~, instr=None)
  operand
}

///|
/// Preserves all locals on the [`OperandStack`] that refer to `local_index`
/// (upstream `PreservedLocalsIter`, evaluated eagerly).
fn OperandStack::preserve_locals(
  self : OperandStack,
  local_index : LocalIdx,
) -> Array[OperandIdx] {
  let out = []
  let mut index = self.replace_first(local_index, None)
  while index is Some(idx) {
    let operand = self.operand_to_temp_at(idx)
    index = match operand {
      Local(link) => link.next_local
      _ => abort("expected `StackOperand::Local`")
    }
    out.push(idx)
  }
  out
}

///|
/// Preserves all locals on the [`OperandStack`] (upstream
/// `PreservedAllLocalsIter`, evaluated eagerly from the top of the stack).
fn OperandStack::preserve_all_locals(self : OperandStack) -> Array[Operand] {
  let out = []
  let mut index = self.operands.length()
  while self.len_locals != 0 {
    // find_next_local
    let mut found = None
    while index > 0 {
      index -= 1
      if self.operands[index] is Local(_) {
        found = Some(index)
        break
      }
    }
    guard found is Some(i) else { break }
    index = i
    let operand = self.operand_to_temp_at(OperandIdx(i))
    out.push(Operand::new(OperandIdx(i), operand))
  }
  out
}

///|
fn OperandStack::try_unlink_local(
  self : OperandStack,
  operand : StackOperand,
) -> Unit {
  guard operand is Local(link) else { return }
  self.unlink_local(link.local_index, link.prev_local, link.next_local)
}

///|
fn OperandStack::unlink_local(
  self : OperandStack,
  local_index : LocalIdx,
  prev_local : OperandIdx?,
  next_local : OperandIdx?,
) -> Unit {
  match prev_local {
    Some(prev_local) => self.update_next_local(prev_local, next_local)
    None => self.replace_first(local_index, next_local) |> ignore
  }
  if next_local is Some(next_local) {
    self.update_prev_local(next_local, prev_local)
  }
  self.len_locals -= 1
}

///|
fn OperandStack::update_prev_local(
  self : OperandStack,
  local_index : OperandIdx,
  prev_index : OperandIdx?,
) -> Unit {
  match self.operands[local_index.0] {
    Local(link) => link.prev_local = prev_index
    _ => abort("expected `StackOperand::Local`")
  }
}

///|
fn OperandStack::update_next_local(
  self : OperandStack,
  local_index : OperandIdx,
  next_index : OperandIdx?,
) -> Unit {
  match self.operands[local_index.0] {
    Local(link) => link.next_local = next_index
    _ => abort("expected `StackOperand::Local`")
  }
}

// ---------------------------------------------------------------------------
// control.rs

///|
/// The common data of a non-unreachable control frame (upstream
/// `{Block,Loop,If,Else}ControlFrame` fields).
pub(all) struct FrameBase {
  /// The block type of the control frame.
  ty : BlockType
  /// The value stack height upon entering the control frame.
  height : Int
  /// This is `true` if there is at least one branch to this frame.
  mut is_branched_to : Bool
  /// The frame's fuel consumption instruction, if fuel metering is enabled.
  consume_fuel : Instr?
  /// The label used to branch to the control frame.
  label : LabelRef
  /// `true` for a `loop` frame (branches carry the block parameters).
  is_loop : Bool
}

///|
/// The reachability of the `if` control flow frame.
pub(all) enum IfReachability {
  /// Both, `then` and `else` blocks of the `if` are reachable.
  Both(else_label~ : LabelRef)
  /// Only the `then` block of the `if` is reachable.
  OnlyThen
  /// Only the `else` block of the `if` is reachable.
  OnlyElse
}

///|
/// The reachability of the `else` control flow frame.
pub(all) enum ElseReachability {
  /// Both, `then` and `else` blocks of the `if` are reachable.
  Both(is_end_of_then_reachable~ : Bool)
  /// Only the `then` block of the `if` is reachable.
  OnlyThen(is_end_of_then_reachable~ : Bool)
  /// Only the `else` block of the `if` is reachable.
  OnlyElse
}

///|
/// A Wasm `if` control frame including its `then` part.
pub(all) struct IfControlFrame {
  base : FrameBase
  /// The reachability of the `then` and `else` blocks.
  reachability : IfReachability
}

///|
/// A Wasm `else` control frame part of Wasm `if`.
pub(all) struct ElseControlFrame {
  base : FrameBase
  /// The reachability of the `then` and `else` blocks.
  reachability : ElseReachability
}

///|
/// The kind of a control frame.
pub(all) enum ControlFrameKind {
  Block
  Loop
  If
  Else
} derive(Eq, Debug)

///|
/// An entry on the [`ControlStack`].
pub(all) enum ControlFrame {
  /// A Wasm `block` control frame.
  Block(FrameBase)
  /// A Wasm `loop` control frame.
  Loop(FrameBase)
  /// A Wasm `if` control frame.
  If(IfControlFrame)
  /// A Wasm `else` control frame.
  Else(ElseControlFrame)
  /// A generic unreachable control frame.
  Unreachable(ControlFrameKind)
}

///|
/// Returns the common data of the control frame.
pub fn ControlFrame::base(self : ControlFrame) -> FrameBase {
  match self {
    Block(frame) => frame
    Loop(frame) => frame
    If(frame) => frame.base
    Else(frame) => frame.base
    Unreachable(_) => abort("invalid query for unreachable control frame")
  }
}

///|
/// Returns the [`BlockType`] of the control frame.
pub fn FrameBase::ty(self : FrameBase) -> BlockType {
  self.ty
}

///|
/// Returns the height of the control frame.
pub fn FrameBase::height(self : FrameBase) -> Int {
  self.height
}

///|
/// Returns the branch label of the control frame.
pub fn FrameBase::label(self : FrameBase) -> LabelRef {
  self.label
}

///|
/// Returns `true` if branches to the control frame exist.
pub fn FrameBase::is_branched_to(self : FrameBase) -> Bool {
  self.is_branched_to
}

///|
/// Makes the control frame aware that there is a branch to it.
pub fn FrameBase::branch_to(self : FrameBase) -> Unit {
  self.is_branched_to = true
}

///|
/// Returns the number of operands required for branching to the control frame.
pub fn FrameBase::len_branch_params(
  self : FrameBase,
  engine : EngineWeak,
) -> Int {
  if self.is_loop {
    self.ty.len_params(engine)
  } else {
    self.ty.len_results(engine)
  }
}

///|
/// Returns a reference to the [`Op::ConsumeFuel`] of the control frame.
pub fn FrameBase::consume_fuel_instr(self : FrameBase) -> Instr? {
  self.consume_fuel
}

///|
pub fn IfControlFrame::reachability(self : IfControlFrame) -> IfReachability {
  self.reachability
}

///|
/// Returns `true` if the `else` branch is reachable.
pub fn IfControlFrame::is_else_reachable(self : IfControlFrame) -> Bool {
  match self.reachability {
    Both(_) | OnlyElse => true
    OnlyThen => false
  }
}

///|
pub fn ElseControlFrame::reachability(
  self : ElseControlFrame,
) -> ElseReachability {
  self.reachability
}

///|
/// Returns `true` if the end of the `then` branch is reachable.
pub fn ElseControlFrame::is_end_of_then_reachable(
  self : ElseControlFrame,
) -> Bool {
  match self.reachability {
    Both(is_end_of_then_reachable~) | OnlyThen(is_end_of_then_reachable~) =>
      is_end_of_then_reachable
    OnlyElse => false
  }
}

///|
/// The `else` operands of `if` control frames (upstream `ElseOperands`).
priv struct ElseOperands {
  /// The end indices of each `else` operands.
  ends : Array[Int]
  /// All operands of all allocated `else` control frames.
  operands : Array[Operand]
}

///|
/// The Wasm control stack.
// `orphaned_else_operands` is only read by `debug_assert!`s upstream
// (wasmi 1.0.9 translator/func/stack/control.rs:121-245).
#warnings("-unused_field")
priv struct ControlStack {
  /// The stack of control frames.
  frames : Array[ControlFrame]
  /// The current top-most [`Op::ConsumeFuel`] on the stack.
  mut consume_fuel_instr : Instr?
  /// Special operand stack to memorize operands for `else` control frames.
  else_operands : ElseOperands
  /// This is `true` if an `if` with else providers was just popped from the stack.
  mut orphaned_else_operands : Bool
}

///|
fn ControlStack::new() -> ControlStack {
  {
    frames: [],
    consume_fuel_instr: None,
    else_operands: { ends: [], operands: [], },
    orphaned_else_operands: false,
  }
}

///|
// Upstream resets recycled allocations (`impl Reset`, stack/operands.rs:87,
// stack/control.rs:92; `Stack::new`, stack/mod.rs:88); this port builds a
// fresh stack per function and does not recycle.
#warnings("-unused_value")
fn ControlStack::reset(self : ControlStack) -> Unit {
  self.frames.clear()
  self.else_operands.ends.clear()
  self.else_operands.operands.clear()
  self.orphaned_else_operands = false
}

///|
fn ControlStack::height(self : ControlStack) -> Int {
  self.frames.length()
}

///|
fn ControlStack::is_empty(self : ControlStack) -> Bool {
  self.height() == 0
}

///|
fn ControlStack::push_frame(
  self : ControlStack,
  frame : ControlFrame,
  consume_fuel : Instr?,
) -> Unit {
  self.frames.push(frame)
  self.consume_fuel_instr = consume_fuel
}

///|
fn ControlStack::pop(self : ControlStack) -> ControlFrame? {
  guard self.frames.pop() is Some(frame) else { return None }
  if !(frame is Block(_) || frame is Unreachable(_)) {
    // Need to replace the cached top-most `consume_fuel_instr`.
    self.consume_fuel_instr = match self.frames.last() {
      Some(top) => top.base().consume_fuel_instr()
      None => None
    }
  }
  self.orphaned_else_operands = match frame {
    If(frame) => frame.reachability is Both(_)
    _ => false
  }
  Some(frame)
}

///|
fn ControlStack::pop_else_operands(self : ControlStack) -> Array[Operand] {
  guard self.else_operands.ends.pop() is Some(end) else {
    abort("missing `else` operands")
  }
  let start = match self.else_operands.ends.last() {
    Some(s) => s
    None => 0
  }
  let out = []
  for i in start..<end {
    out.push(self.else_operands.operands[i])
  }
  self.else_operands.operands.truncate(start)
  self.orphaned_else_operands = false
  out
}

///|
fn ControlStack::get(self : ControlStack, depth : Int) -> ControlFrame {
  let height = self.height()
  if depth >= height {
    abort(
      "out of bounds control frame at depth (=\{depth}) for stack of height (=\{height})",
    )
  }
  self.frames[height - 1 - depth]
}

///|
/// Returns `true` if `depth` refers to the function body block.
fn ControlStack::is_root(self : ControlStack, depth : Int) -> Bool {
  if self.frames.is_empty() {
    return false
  }
  depth == self.height() - 1
}

///|
/// A branch target acquired from the control stack.
pub(all) enum AcquiredTarget {
  /// The branch targets the function enclosing `block` and therefore is a `return`.
  Return(FrameBase)
  /// The branch targets a regular [`ControlFrame`].
  Branch(FrameBase)
}

///|
/// Returns the targeted control frame.
pub fn AcquiredTarget::control_frame(self : AcquiredTarget) -> FrameBase {
  match self {
    Return(frame) => frame
    Branch(frame) => frame
  }
}

// ---------------------------------------------------------------------------
// mod.rs

///|
/// The Wasm value stack during translation from Wasm to Wasmi bytecode.
pub(all) struct TranslatorStack {
  /// The underlying [`Engine`].
  priv engine : EngineWeak
  /// The Wasm value stack.
  priv operands : OperandStack
  /// The Wasm control stack.
  priv controls : ControlStack
}

///|
pub fn TranslatorStack::new(engine : EngineWeak) -> TranslatorStack {
  { engine, operands: OperandStack::new(), controls: ControlStack::new(), }
}

///|
/// Register `amount` local variables.
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:101).
#warnings("-unused_error_type")
pub fn TranslatorStack::register_locals(
  self : TranslatorStack,
  amount : Int,
) -> Unit raise WasmiError {
  self.operands.register_locals(amount)
}

///|
/// Returns `true` if the control stack is empty.
pub fn TranslatorStack::is_control_empty(self : TranslatorStack) -> Bool {
  self.controls.is_empty()
}

///|
/// Returns the current height of the [`Stack`].
pub fn TranslatorStack::height(self : TranslatorStack) -> Int {
  self.operands.height()
}

///|
/// Returns the maximum height of the [`Stack`].
pub fn TranslatorStack::max_height(self : TranslatorStack) -> Int {
  self.operands.max_height()
}

///|
/// Truncates `self` to the target `height`.
pub fn TranslatorStack::trunc(self : TranslatorStack, height : Int) -> Unit {
  while self.height() > height {
    self.pop() |> ignore
  }
}

///|
/// Pushes the function enclosing Wasm `block` onto the [`Stack`].
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:157).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_func_block(
  self : TranslatorStack,
  ty : BlockType,
  label : LabelRef,
  consume_fuel : Instr?,
) -> Unit raise WasmiError {
  self.controls.push_frame(
    Block({
      ty,
      height: 0,
      is_branched_to: false,
      consume_fuel,
      label,
      is_loop: false,
    }),
    consume_fuel,
  )
}

///|
/// Pushes a Wasm `block` onto the [`Stack`].
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:178).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_block(
  self : TranslatorStack,
  ty : BlockType,
  label : LabelRef,
) -> Unit raise WasmiError {
  let len_params = ty.len_params(self.engine)
  let block_height = self.height() - len_params
  let consume_fuel = self.consume_fuel_instr()
  self.controls.push_frame(
    Block({
      ty,
      height: block_height,
      is_branched_to: false,
      consume_fuel,
      label,
      is_loop: false,
    }),
    consume_fuel,
  )
}

///|
/// Pushes a Wasm `loop` onto the [`Stack`].
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:198).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_loop(
  self : TranslatorStack,
  ty : BlockType,
  label : LabelRef,
  consume_fuel : Instr?,
) -> Unit raise WasmiError {
  let len_params = ty.len_params(self.engine)
  let block_height = self.height() - len_params
  self.controls.push_frame(
    Loop({
      ty,
      height: block_height,
      is_branched_to: false,
      consume_fuel,
      label,
      is_loop: true,
    }),
    consume_fuel,
  )
}

///|
/// Pushes a Wasm `if` onto the [`Stack`].
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:226).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_if(
  self : TranslatorStack,
  ty : BlockType,
  label : LabelRef,
  reachability : IfReachability,
  consume_fuel : Instr?,
) -> Unit raise WasmiError {
  let len_params = ty.len_params(self.engine)
  let block_height = self.height() - len_params
  let else_operands = self.operands.peek(len_params)
  self.controls.frames.push(
    If({
      base: {
        ty,
        height: block_height,
        is_branched_to: false,
        consume_fuel,
        label,
        is_loop: false,
      },
      reachability,
    }),
  )
  if reachability is Both(_) {
    for operand in else_operands {
      self.controls.else_operands.operands.push(operand)
    }
    self.controls.else_operands.ends.push(
      self.controls.else_operands.operands.length(),
    )
  }
  self.controls.consume_fuel_instr = consume_fuel
}

///|
/// Pushes a Wasm `else` onto the [`Stack`].
pub fn TranslatorStack::push_else(
  self : TranslatorStack,
  if_frame : IfControlFrame,
  is_end_of_then_reachable : Bool,
  consume_fuel : Instr?,
) -> Unit raise WasmiError {
  self.push_else_operands(if_frame)
  let reachability : ElseReachability = match if_frame.reachability {
    Both(_) => Both(is_end_of_then_reachable~)
    OnlyThen => OnlyThen(is_end_of_then_reachable~)
    OnlyElse => OnlyElse
  }
  let base = if_frame.base
  self.controls.push_frame(
    Else({
      base: {
        ty: base.ty,
        height: base.height,
        is_branched_to: base.is_branched_to,
        consume_fuel,
        label: base.label,
        is_loop: false,
      },
      reachability,
    }),
    consume_fuel,
  )
}

///|
/// Pushes an unreachable Wasm control onto the [`Stack`].
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:277).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_unreachable(
  self : TranslatorStack,
  kind : ControlFrameKind,
) -> Unit raise WasmiError {
  self.controls.frames.push(Unreachable(kind))
}

///|
/// Pops the top-most control frame from the control stack and returns it.
pub fn TranslatorStack::pop_control(self : TranslatorStack) -> ControlFrame {
  match self.controls.pop() {
    Some(frame) => frame
    None => abort("tried to pop control from empty control stack")
  }
}

///|
/// Pushes the top-most `else` operands from the control stack onto the operand stack.
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:298).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_else_operands(
  self : TranslatorStack,
  frame : IfControlFrame,
) -> Unit raise WasmiError {
  match frame.reachability {
    Both(_) => ()
    OnlyThen | OnlyElse => return
  }
  self.trunc(frame.base.height)
  for else_operand in self.controls.pop_else_operands() {
    self.operands.push_operand(else_operand) |> ignore
  }
}

///|
/// Returns a shared reference to the [`ControlFrame`] at `depth`.
pub fn TranslatorStack::peek_control(
  self : TranslatorStack,
  depth : Int,
) -> ControlFrame {
  self.controls.get(depth)
}

///|
/// Returns an exclusive reference to the [`ControlFrame`] at `depth`.
pub fn TranslatorStack::peek_control_mut(
  self : TranslatorStack,
  depth : Int,
) -> AcquiredTarget {
  let is_root = self.controls.is_root(depth)
  let frame = self.controls.get(depth).base()
  if is_root {
    Return(frame)
  } else {
    Branch(frame)
  }
}

///|
/// Pushes the [`Operand`] back to the [`Stack`].
// Cannot fail; keeps upstream's `Result<OperandIdx, Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:342).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_operand(
  self : TranslatorStack,
  operand : Operand,
) -> OperandIdx raise WasmiError {
  self.operands.push_operand(operand)
}

///|
/// Pushes a local variable with index `local_idx` to the [`Stack`].
// Cannot fail; keeps upstream's `Result<OperandIdx, Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:352).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_local(
  self : TranslatorStack,
  local_index : LocalIdx,
  ty : @wasmi_core.ValType,
) -> OperandIdx raise WasmiError {
  self.operands.push_local(local_index, ty)
}

///|
/// Pushes a temporary with type `ty` on the [`Stack`].
// Cannot fail; keeps upstream's `Result<OperandIdx, Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:362).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_temp(
  self : TranslatorStack,
  ty : @wasmi_core.ValType,
  instr : Instr?,
) -> OperandIdx raise WasmiError {
  self.operands.push_temp(ty, instr)
}

///|
/// Pushes an immediate `value` on the [`Stack`].
// Cannot fail; keeps upstream's `Result<OperandIdx, Error>`
// (wasmi 1.0.9 translator/func/stack/mod.rs:372).
#warnings("-unused_error_type")
pub fn TranslatorStack::push_immediate(
  self : TranslatorStack,
  value : @wasmi_core.TypedVal,
) -> OperandIdx raise WasmiError {
  self.operands.push_immediate(value)
}

///|
/// Peeks the [`Operand`] at `depth`.
pub fn TranslatorStack::peek(self : TranslatorStack, depth : Int) -> Operand {
  self.operands.get(depth)
}

///|
/// Peeks the 2 top-most [`Operand`]s.
pub fn TranslatorStack::peek2(self : TranslatorStack) -> (Operand, Operand) {
  let v0 = self.peek(1)
  let v1 = self.peek(0)
  (v0, v1)
}

///|
/// Peeks the 3 top-most [`Operand`]s.
pub fn TranslatorStack::peek3(
  self : TranslatorStack,
) -> (Operand, Operand, Operand) {
  let v0 = self.peek(2)
  let v1 = self.peek(1)
  let v2 = self.peek(0)
  (v0, v1, v2)
}

///|
/// Returns the top-most `len` operands from the stack (bottom to top).
pub fn TranslatorStack::peek_n(
  self : TranslatorStack,
  len : Int,
) -> Array[Operand] {
  self.operands.peek(len)
}

///|
/// Pops the top-most [`Operand`] from the [`Stack`].
pub fn TranslatorStack::pop(self : TranslatorStack) -> Operand {
  self.operands.pop()
}

///|
/// Pops the two top-most [`Operand`] from the [`Stack`].
pub fn TranslatorStack::pop2(self : TranslatorStack) -> (Operand, Operand) {
  let o2 = self.pop()
  let o1 = self.pop()
  (o1, o2)
}

///|
/// Pops the three top-most [`Operand`] from the [`Stack`].
pub fn TranslatorStack::pop3(
  self : TranslatorStack,
) -> (Operand, Operand, Operand) {
  let o3 = self.pop()
  let o2 = self.pop()
  let o1 = self.pop()
  (o1, o2, o3)
}

///|
/// Pops `len` operands from the stack and store them into `buffer`.
pub fn TranslatorStack::pop_n(
  self : TranslatorStack,
  len : Int,
  buffer : Array[Operand],
) -> Unit {
  buffer.clear()
  for _ in 0..<len {
    buffer.push(self.pop())
  }
  buffer.rev_in_place()
}

///|
/// Preserve all locals on the [`Stack`] that refer to `local_index`.
pub fn TranslatorStack::preserve_locals(
  self : TranslatorStack,
  local_index : LocalIdx,
) -> Array[OperandIdx] {
  self.operands.preserve_locals(local_index)
}

///|
/// Preserve all locals on the [`Stack`].
pub fn TranslatorStack::preserve_all_locals(
  self : TranslatorStack,
) -> Array[Operand] {
  self.operands.preserve_all_locals()
}

///|
/// Converts and returns the [`Operand`] at `depth` into a [`Operand::Temp`].
pub fn TranslatorStack::operand_to_temp(
  self : TranslatorStack,
  depth : Int,
) -> Operand {
  self.operands.operand_to_temp(depth)
}

///|
/// Returns the current [`Op::ConsumeFuel`] if fuel metering is enabled.
pub fn TranslatorStack::consume_fuel_instr(self : TranslatorStack) -> Instr? {
  self.controls.consume_fuel_instr
}
