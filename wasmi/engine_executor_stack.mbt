// Port of wasmi 1.0.9 `engine/executor/stack/{mod,calls,values}.rs`.
//
// Representation notes:
//
// - The value stack stores each 128-bit `UntypedVal` cell as two parallel
//   `FixedArray[UInt64]` (low and high 64 bits) plus a length; the capacity
//   grows like a Rust `Vec`. The accounting of `extend_by`, `drop`,
//   `truncate`, `drain` and `alloc_call_frame` is upstream's exactly since
//   stack exhaustion (`TrapCode::StackOverflow`) is observable.
// - Upstream's raw `FrameSlots` pointers and `ValueStackOffset`s are plain
//   `Int` cell indices. Since indices stay valid when the cells are moved to
//   a larger allocation, upstream's `on_resize` callbacks (which re-derive
//   `FrameSlots` pointers) are not needed; the executor instead re-fetches
//   its cached cell arrays after operations that may reallocate them.
// - `CallFrame`s are mutable objects pooled by the `CallStack` (a pushed
//   frame is copied into the pool), so that calls do not allocate.

///|
/// Returns a [`TrapCode`] signalling a stack overflow.
fn err_stack_overflow() -> @wasmi_core.TrapCode {
  StackOverflow
}

// ---------------------------------------------------------------------------
// stack/mod.rs

///|
/// Data structure that combines both value stack and call stack.
struct Stack {
  /// The call stack.
  calls : CallStack
  /// The value stack.
  values : ValueStack
}

///|
/// Creates a new [`Stack`] given the [`Config`].
fn Stack::new(config : StackConfig) -> Stack {
  let calls = CallStack::new(config.max_recursion_depth())
  let values = ValueStack::new(
    config.min_stack_height(),
    config.max_stack_height(),
  )
  { calls, values, }
}

///|
/// Resets the [`Stack`] for clean reuse.
fn Stack::reset(self : Stack) -> Unit {
  self.calls.reset()
  self.values.reset()
}

///|
/// Returns the capacity of the [`Stack`].
fn Stack::capacity(self : Stack) -> Int {
  self.values.capacity()
}

///|
/// Merge the two top-most [`CallFrame`] with respect to a tail call.
///
/// Returns the [`Instance`] popped together with the caller frame, if any.
///
/// # Panics (Debug)
///
/// - If the two top-most [`CallFrame`] do not have matching `results`.
/// - If there are not at least two [`CallFrame`] on the [`CallStack`].
///
/// # Note
///
/// Any cell index allocated within the range `from..to` on the [`ValueStack`]
/// may be invalidated by this operation. It is the caller's responsibility to
/// reinstantiate all such indices.
fn Stack::merge_call_frames(self : Stack, callee : CallFrame) -> Instance? {
  guard self.calls.pop() is Some(caller) else {
    abort("caller call frame must exist")
  }
  let instance = self.calls.popped_instance()
  // Safety:
  //
  // We only drain cells of the second top-most call frame on the value stack.
  // Therefore only value stack offsets of the top-most call frame on the
  // value stack are going to be invalidated which we ensure to adjust and
  // reinstantiate after this operation.
  let len_drained = self.values.drain(
    caller.frame_offset(),
    callee.frame_offset(),
  )
  callee.move_down(len_drained)
  instance
}

///|
/// Stacks to hold and distribute reusable [`Stack`]s (upstream `EngineStacks`).
fn engine_stacks_reuse_or_new(
  stacks : Array[Stack],
  config : StackConfig,
) -> Stack {
  match stacks.pop() {
    Some(stack) => stack
    None => Stack::new(config)
  }
}

///|
/// Disose and recycle the `stack` (upstream `EngineStacks::recycle`).
fn engine_stacks_recycle(
  stacks : Array[Stack],
  config : StackConfig,
  stack : Stack,
) -> Unit {
  if stack.capacity() > 0 && stacks.length() < config.max_cached_stacks {
    stacks.push(stack)
  }
}

// ---------------------------------------------------------------------------
// stack/calls.rs

///|
/// The stack of nested function calls.
priv struct CallStack {
  /// The stack of nested function call frames (pooled: only the first `len`
  /// entries are live).
  frames : Array[CallFrame]
  /// The number of live call frames.
  mut len : Int
  /// The [`Instance`] used at certain frame stack heights.
  instances : Array[Instance]
  /// The maximum allowed recursion depth.
  ///
  /// # Note
  ///
  /// A [`TrapCode::StackOverflow`] is raised if the recursion limit is exceeded.
  recursion_limit : Int
  /// The [`Instance`] popped by the last [`CallStack::pop`] (upstream returns
  /// it together with the popped frame).
  mut popped_instance : Instance?
}

///|
/// Creates a new [`CallStack`] using the given recursion limit.
fn CallStack::new(recursion_limit : Int) -> CallStack {
  { frames: [], len: 0, instances: [], recursion_limit, popped_instance: None, }
}

///|
/// Clears the [`CallStack`] entirely.
///
/// # Note
///
/// The [`CallStack`] can sometimes be left in a non-empty state upon
/// executing a function, for example when a trap is encountered. We
/// reset the [`CallStack`] before executing the next function to
/// provide a clean slate for all executions.
fn CallStack::reset(self : CallStack) -> Unit {
  self.len = 0
  self.instances.clear()
  self.popped_instance = None
}

///|
/// Returns the number of [`CallFrame`]s on the [`CallStack`].
fn CallStack::len(self : CallStack) -> Int {
  self.len
}

///|
/// Returns the currently used [`Instance`].
fn CallStack::instance(self : CallStack) -> Instance? {
  self.instances.last()
}

///|
/// Returns the currently used [`Instance`].
///
/// # Panics
///
/// If there is no currently used [`Instance`].
/// This happens if the [`CallStack`] is empty.
fn CallStack::instance_expect(self : CallStack) -> Instance {
  match self.instance() {
    Some(instance) => instance
    None => abort("the currently used instance must be present")
  }
}

///|
/// Pushes a [`CallFrame`] onto the [`CallStack`].
///
/// The fields of `call` are copied into the pooled frame.
///
/// # Errors
///
/// If the recursion limit has been reached.
fn CallStack::push(
  self : CallStack,
  call : CallFrame,
  instance : Instance?,
) -> Unit raise @wasmi_core.TrapCode {
  if self.len() == self.recursion_limit {
    raise err_stack_overflow()
  }
  let changed_instance = match instance {
    Some(instance) => self.push_instance(instance)
    None => false
  }
  if self.len < self.frames.length() {
    self.frames.unsafe_get(self.len).assign(call)
  } else {
    self.frames.push(call.copy())
  }
  self.frames.unsafe_get(self.len).changed_instance = changed_instance
  self.len += 1
}

///|
/// Pushes the `instance` onto the internal instances stack.
///
/// Returns `true` if the [`Instance`] stack has been adjusted.
fn CallStack::push_instance(self : CallStack, instance : Instance) -> Bool {
  if self.instances.last() is Some(last) {
    if instance == last {
      return false
    }
  }
  self.instances.push(instance)
  true
}

///|
/// Pops the last [`CallFrame`] from the [`CallStack`] if any.
///
/// The [`Instance`] popped together with the frame in case the popped
/// [`CallFrame`] introduced a new [`Instance`] on the [`CallStack`] is
/// available via [`CallStack::popped_instance`] afterwards.
///
/// # Note
///
/// The returned frame is pooled: it stays valid until the next push.
fn CallStack::pop(self : CallStack) -> CallFrame? {
  if self.len == 0 {
    return None
  }
  self.len -= 1
  let frame = self.frames.unsafe_get(self.len)
  self.popped_instance = if frame.changed_instance {
    self.instances.pop()
  } else {
    None
  }
  Some(frame)
}

///|
/// Returns the [`Instance`] popped by the last [`CallStack::pop`].
fn CallStack::popped_instance(self : CallStack) -> Instance? {
  self.popped_instance
}

///|
/// Peeks the last [`CallFrame`] of the [`CallStack`] if any.
fn CallStack::peek(self : CallStack) -> CallFrame? {
  if self.len == 0 {
    return None
  }
  Some(self.frames.unsafe_get(self.len - 1))
}

///|
/// Peeks the second top-most [`CallFrame`] of the [`CallStack`] if any.
///
/// # Note
///
/// Upstream `peek_2` returns `(callee, caller?)`; the callee is
/// [`CallStack::peek`] and the caller is returned here.
fn CallStack::peek_caller(self : CallStack) -> CallFrame? {
  if self.len < 2 {
    return None
  }
  Some(self.frames.unsafe_get(self.len - 2))
}

///|
/// A single frame of a called [`EngineFunc`].
///
/// # Note
///
/// Upstream's `InstructionPtr` is a raw pointer into the instructions of the
/// compiled function; here it is the pair (`instrs`, `ip`). Upstream's
/// `StackOffsets` (`base` and `frame`) are stored inline.
priv struct CallFrame {
  /// The instructions of the called function.
  mut instrs : FixedArray[@ir.Op]
  /// The index of the [`Op`] that is executed next.
  mut ip : Int
  /// Offset to the first mutable cell of a [`CallFrame`].
  mut base : Int
  /// Offset to the first cell of a [`CallFrame`].
  mut frame : Int
  /// Span of registers were the caller expects them in its [`CallFrame`].
  mut results : @ir.SlotSpan
  /// Is `true` if this [`CallFrame`] changed the currently used [`Instance`].
  ///
  /// - This flag is an optimization to reduce the amount of accesses on the
  ///   instance stack of the [`CallStack`] for the common case where this is
  ///   not needed.
  /// - This flag is private to the [`CallStack`] and shall not be observable
  ///   from the outside.
  mut changed_instance : Bool
}

///|
/// Creates a new [`CallFrame`].
fn CallFrame::new(
  instrs : FixedArray[@ir.Op],
  ip : Int,
  offsets_base : Int,
  offsets_frame : Int,
  results : @ir.SlotSpan,
) -> CallFrame {
  {
    instrs,
    ip,
    base: offsets_base,
    frame: offsets_frame,
    results,
    changed_instance: false,
  }
}

///|
/// Re-initializes `self` like [`CallFrame::new`] (used for the executor's
/// scratch frame).
fn CallFrame::init(
  self : CallFrame,
  instrs : FixedArray[@ir.Op],
  ip : Int,
  offsets_base : Int,
  offsets_frame : Int,
  results : @ir.SlotSpan,
) -> Unit {
  self.instrs = instrs
  self.ip = ip
  self.base = offsets_base
  self.frame = offsets_frame
  self.results = results
  self.changed_instance = false
}

///|
/// Copies all fields of `other` into `self`.
fn CallFrame::assign(self : CallFrame, other : CallFrame) -> Unit {
  self.instrs = other.instrs
  self.ip = other.ip
  self.base = other.base
  self.frame = other.frame
  self.results = other.results
  self.changed_instance = other.changed_instance
}

///|
/// Returns a copy of `self`.
fn CallFrame::copy(self : CallFrame) -> CallFrame {
  {
    instrs: self.instrs,
    ip: self.ip,
    base: self.base,
    frame: self.frame,
    results: self.results,
    changed_instance: self.changed_instance,
  }
}

///|
/// Moves the [`ValueStack`] offsets of the [`CallFrame`] down by `delta`.
///
/// # Note
///
/// This is used for the implementation of tail calls.
fn CallFrame::move_down(self : CallFrame, delta : Int) -> Unit {
  // StackOffsets::move_down
  self.base = self.base - delta
  self.frame = self.frame - delta
}

///|
/// Updates the instruction pointer of the [`CallFrame`].
///
/// This is required before dispatching a nested function call to update
/// the instruction pointer of the caller so that it can continue at that
/// position when the called function returns.
fn CallFrame::update_instr_ptr(self : CallFrame, new_instr_ptr : Int) -> Unit {
  self.ip = new_instr_ptr
}

///|
/// Returns the frame value stack offset of the [`CallFrame`].
fn CallFrame::frame_offset(self : CallFrame) -> Int {
  self.frame
}

///|
/// Returns the base value stack offset of the [`CallFrame`].
fn CallFrame::base_offset(self : CallFrame) -> Int {
  self.base
}

///|
/// Returns the [`SlotSpan`] of the [`CallFrame`].
///
/// # Note
///
/// The registers yielded by the returned [`SlotSpan`]
/// refer to the [`CallFrame`] of the caller of this [`CallFrame`].
fn CallFrame::results(self : CallFrame) -> @ir.SlotSpan {
  self.results
}

// ---------------------------------------------------------------------------
// stack/values.rs

///|
/// The value stack (cells of 128-bit [`UntypedVal`]s).
priv struct ValueStack {
  /// The low 64 bits of the cells on the [`ValueStack`].
  mut lo : FixedArray[UInt64]
  /// The high 64 bits of the cells on the [`ValueStack`].
  mut hi : FixedArray[UInt64]
  /// The number of live cells.
  mut len : Int
  /// Maximal possible `sp` value.
  max_len : Int
}

///|
/// Creates a new empty [`ValueStack`].
///
/// # Panics
///
/// - If the `initial_len` is zero.
/// - If the `initial_len` is greater than `maximum_len`.
fn ValueStack::new(initial_len : Int, maximum_len : Int) -> ValueStack {
  if !(initial_len > 0) {
    abort("cannot initialize the value stack with zero length")
  }
  if !(initial_len <= maximum_len) {
    abort(
      "initial value stack length is greater than maximum value stack length",
    )
  }
  {
    lo: FixedArray::make(initial_len, 0),
    hi: FixedArray::make(initial_len, 0),
    len: 0,
    max_len: maximum_len,
  }
}

///|
/// Creates an empty [`ValueStack`] that does not allocate heap memory.
///
/// # Note
///
/// This is required for resumable functions in order to replace their
/// proper stack with a cheap dummy one.
fn ValueStack::empty() -> ValueStack {
  { lo: [], hi: [], len: 0, max_len: 0, }
}

///|
/// Resets the [`ValueStack`] for reuse.
///
/// # Note
///
/// The [`ValueStack`] can sometimes be left in a non-empty state upon
/// executing a function, for example when a trap is encountered. We
/// reset the [`ValueStack`] before executing the next function to
/// provide a clean slate for all executions.
fn ValueStack::reset(self : ValueStack) -> Unit {
  self.len = 0
}

///|
/// Returns the capacity of the [`ValueStack`].
fn ValueStack::capacity(self : ValueStack) -> Int {
  self.lo.length()
}

///|
/// Reserves capacity for at least `additional` more cells (Rust's
/// `Vec::reserve` amortized growth).
fn ValueStack::reserve(self : ValueStack, additional : Int) -> Unit {
  let required = self.len + additional
  let capacity = self.capacity()
  if required <= capacity {
    return
  }
  let doubled = capacity * 2
  let mut new_capacity = if doubled > required { doubled } else { required }
  // Rust's `MIN_NON_ZERO_CAP` for 16-byte elements.
  if new_capacity < 4 {
    new_capacity = 4
  }
  let lo = FixedArray::make(new_capacity, 0UL)
  let hi = FixedArray::make(new_capacity, 0UL)
  FixedArray::unsafe_blit(lo, 0, self.lo, 0, self.len)
  FixedArray::unsafe_blit(hi, 0, self.hi, 0, self.len)
  self.lo = lo
  self.hi = hi
}

///|
/// Reserves enough space for `additional` cells on the [`ValueStack`].
///
/// Returns the index of the first of the `additional` new (uninitialized)
/// cells.
///
/// This may heap allocate in case the [`ValueStack`] ran out of preallocated
/// memory, invalidating previously fetched cell arrays.
///
/// # Errors
///
/// When trying to grow the [`ValueStack`] over its maximum size limit.
fn ValueStack::extend_by(
  self : ValueStack,
  additional : Int,
) -> Int raise @wasmi_core.TrapCode {
  if additional >= self.max_len() - self.len() {
    raise err_stack_overflow()
  }
  self.reserve(additional)
  let spare = self.len
  self.len = self.len + additional
  spare
}

///|
/// Returns the current length of the [`ValueStack`].
fn ValueStack::len(self : ValueStack) -> Int {
  self.len
}

///|
/// Returns the maximum length of the [`ValueStack`].
fn ValueStack::max_len(self : ValueStack) -> Int {
  self.max_len
}

///|
/// Drop the last `amount` cells of the [`ValueStack`].
///
/// # Panics (Debug)
///
/// If `amount` is greater than the [`ValueStack`] height.
fn ValueStack::drop(self : ValueStack, amount : Int) -> Unit {
  if !(self.len() >= amount) {
    abort("assertion failed: self.len() >= amount")
  }
  self.len = self.len - amount
}

///|
/// Drop the last `amount` cells of the [`ValueStack`] and returns the index
/// of the first dropped cell (the dropped cells stay readable until the
/// stack grows again).
///
/// # Panics (Debug)
///
/// If `amount` is greater than the [`ValueStack`] height.
fn ValueStack::drop_return(self : ValueStack, amount : Int) -> Int {
  let len = self.len()
  let dropped = len - amount
  self.drop(amount)
  dropped
}

///|
/// Shrink the [`ValueStack`] to the offset `new_len`.
///
/// # Panics (Debug)
///
/// If `new_len` is greater than the current [`ValueStack`] length.
fn ValueStack::truncate(self : ValueStack, new_len : Int) -> Unit {
  if !(new_len <= self.len()) {
    abort("assertion failed: new_len <= self.len()")
  }
  self.len = new_len
}

///|
/// Allocates a new [`EngineFunc`] on the [`ValueStack`].
///
/// Returns the frame offset of the allocated [`EngineFunc`]; its base offset
/// is the frame offset plus the number of function local constants.
/// `params` is set to the uninitialized parameter and local cells.
///
/// # Note
///
/// - All previously fetched cell arrays might be invalidated.
/// - The parameters of the allocated [`EngineFunc`] are set to zero
///   and require proper initialization after this call.
///
/// # Errors
///
/// When trying to grow the [`ValueStack`] over its maximum size limit.
fn ValueStack::alloc_call_frame(
  self : ValueStack,
  func : CompiledFuncEntity,
  params : FrameParams,
) -> Int raise @wasmi_core.TrapCode {
  let len_stack_slots = func.len_stack_slots()
  let consts = func.consts()
  let len_consts = consts.length()
  let len = self.len()
  let spare = self.extend_by(len_stack_slots)
  let lo = self.lo
  let hi = self.hi
  for i in 0..<len_consts {
    let const_value = consts.unsafe_get(i)
    lo.unsafe_set(spare + i, const_value.to_bits64())
    hi.unsafe_set(spare + i, const_value.hi64())
  }
  params.init(self, spare + len_consts, spare + len_stack_slots)
  len
}

///|
/// Removes the cells `from..to` from the [`ValueStack`].
///
/// Returns the number of drained [`ValueStack`] cells.
///
/// # Note
///
/// - This invalidates all cell indices within the range `from..` and the
///   caller has to make sure to properly reinstantiate them.
fn ValueStack::drain(self : ValueStack, from : Int, to : Int) -> Int {
  let len_drained = to - from
  let tail = self.len - to
  FixedArray::unsafe_blit(self.lo, from, self.lo, to, tail)
  FixedArray::unsafe_blit(self.hi, from, self.hi, to, tail)
  self.len = self.len - len_drained
  len_drained
}

///|
/// Returns the [`UntypedVal`] of the cell at `index`.
fn ValueStack::get(self : ValueStack, index : Int) -> @wasmi_core.UntypedVal {
  @wasmi_core.UntypedVal::from_v128(
    @wasmi_core.V128::from_lo_hi(
      self.lo.unsafe_get(index),
      self.hi.unsafe_get(index),
    ),
  )
}

///|
/// Sets the cell at `index` to `value`.
fn ValueStack::set(
  self : ValueStack,
  index : Int,
  value : @wasmi_core.UntypedVal,
) -> Unit {
  self.lo.unsafe_set(index, value.to_bits64())
  self.hi.unsafe_set(index, value.hi64())
}

///|
/// Uninitialized parameters of a [`CallFrame`]: the cells `start..end`.
priv struct FrameParams {
  /// The value stack holding the cells.
  mut values : ValueStack
  /// The next cell to initialize.
  mut start : Int
  /// The end of the parameter and local cells.
  mut end : Int
}

///|
/// Creates a new (empty) [`FrameParams`].
fn FrameParams::new() -> FrameParams {
  { values: ValueStack::empty(), start: 0, end: 0, }
}

///|
/// Sets `self` to the cells `start..end` of `values`.
fn FrameParams::init(
  self : FrameParams,
  values : ValueStack,
  start : Int,
  end : Int,
) -> Unit {
  self.values = values
  self.start = start
  self.end = end
}

///|
/// Sets the value of the next cell to `value`.
fn FrameParams::init_next(
  self : FrameParams,
  value : @wasmi_core.UntypedVal,
) -> Unit {
  self.values.set(self.start, value)
  self.start = self.start + 1
}

///|
/// Sets the value of the next cell to the raw `lo`/`hi` bits.
fn FrameParams::init_next_bits(
  self : FrameParams,
  lo : UInt64,
  hi : UInt64,
) -> Unit {
  let start = self.start
  self.values.lo.unsafe_set(start, lo)
  self.values.hi.unsafe_set(start, hi)
  self.start = start + 1
}

///|
/// Zero-initialize the remaining locals and parameters.
fn FrameParams::init_zeroes(self : FrameParams) -> Unit {
  let lo = self.values.lo
  let hi = self.values.hi
  for i in self.start..<self.end {
    lo.unsafe_set(i, 0)
    hi.unsafe_set(i, 0)
  }
  self.start = self.end
}
