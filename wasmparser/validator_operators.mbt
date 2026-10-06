// Port of wasmparser 0.228.0 `src/validator/operators.rs`.
//
// The basic validation algorithm here is copied from the "Validation
// Algorithm" section of the WebAssembly specification -
// https://webassembly.github.io/spec/core/appendix/algorithm.html.
//
// That algorithm is followed pretty closely here, namely `push_operand`,
// `pop_operand`, `push_ctrl`, and `pop_ctrl`. If anything here is a bit
// confusing it's recommended to read over that section to see how it maps to
// the various methods here.
//
// The `VisitOperator` impl of `WasmProposalValidator` (the proposal checks)
// is generated into `validator_operators_gen.mbt`; the per-operator
// `OperatorValidatorTemp::visit_*` methods are below and in
// `validator_operators_simd.mbt` (stubs for the unported ones in
// `validator_operators_todo_gen.mbt`).

///|
struct OperatorValidator {
  locals : Locals
  local_inits : LocalInits

  // This is a list of flags for wasm features which are used to gate various
  // instructions.
  features : WasmFeatures

  // Temporary storage used during `match_stack_operands`
  popped_types_tmp : Array[MaybeType]
  /// The `control` list is the list of blocks that we're currently in.
  control : Array[Frame]
  /// The `operands` is the current type stack.
  operands : Array[MaybeType]
  /// Offset of the `end` instruction which emptied the `control` stack, which
  /// must be the end of the function.
  mut end_which_emptied_control : Int?
  /// Whether validation is happening in a shared context.
  mut shared : Bool
}

///|
/// Captures the initialization of non-defaultable locals.
priv struct LocalInits {
  /// Records if a local is already initialized.
  local_inits : Array[Bool]
  /// When `local_inits` is modified, the relevant `index` is recorded
  /// here to be undone when control pops.
  inits : Array[UInt]
  /// The index of the first non-defaultable local.
  ///
  /// # Note
  ///
  /// This is an optimization so that we only have to perform expensive
  /// look-ups for locals that have a local index equal to or higher than this.
  mut first_non_default_local : UInt
}

///|
fn LocalInits::new() -> LocalInits {
  { local_inits: [], inits: [], first_non_default_local: 0xFFFF_FFFF, }
}

///|
/// Defines new function local parameters.
fn LocalInits::define_params(self : LocalInits, count : Int) -> Unit {
  for _ in 0..<count {
    self.local_inits.push(true)
  }
}

///|
/// Defines `count` function locals of type `ty`.
fn LocalInits::define_locals(
  self : LocalInits,
  count : UInt,
  ty : ValType,
) -> Unit {
  let len = self.local_inits.length()
  let is_defaultable = ty.is_defaultable()
  if !is_defaultable && self.first_non_default_local == 0xFFFF_FFFF {
    self.first_non_default_local = len.reinterpret_as_uint()
  }
  // The total number of locals is bounded by `MAX_WASM_FUNCTION_LOCALS`
  // (checked by `Locals::define` before).
  for _ in 0U..<count {
    self.local_inits.push(is_defaultable)
  }
}

///|
/// Returns `true` if the local at `local_index` has already been initialized.
fn LocalInits::is_uninit(self : LocalInits, local_index : UInt) -> Bool {
  if local_index < self.first_non_default_local {
    return false
  }
  !self.local_inits[local_index.reinterpret_as_int()]
}

///|
/// Marks the local at `local_index` as initialized.
fn LocalInits::set_init(self : LocalInits, local_index : UInt) -> Unit {
  if self.is_uninit(local_index) {
    self.local_inits[local_index.reinterpret_as_int()] = true
    self.inits.push(local_index)
  }
}

///|
/// Registers a new control frame and returns its `height`.
fn LocalInits::push_ctrl(self : LocalInits) -> Int {
  self.inits.length()
}

///|
/// Pops a control frame via its `height`.
///
/// This uninitializes all locals that have been initialized within it.
fn LocalInits::pop_ctrl(self : LocalInits, height : Int) -> Unit {
  for i in height..<self.inits.length() {
    self.local_inits[self.inits[i].reinterpret_as_int()] = false
  }
  self.inits.truncate(height)
}

///|
/// Clears the [`LocalInits`].
///
/// After this operation `self` will be empty and ready for reuse.
fn LocalInits::clear(self : LocalInits) -> Unit {
  self.local_inits.clear()
  self.inits.clear()
  self.first_non_default_local = 0xFFFF_FFFF
}

///|
// No science was performed in the creation of this number, feel free to change
// it if you so like.
let max_locals_to_track : Int = 50

///|
struct Locals {
  // Total number of locals in the function.
  mut num_locals : UInt

  // The first MAX_LOCALS_TO_TRACK locals in a function. This is used to
  // optimize the theoretically common case where most functions don't have
  // many locals and don't need a full binary search in the entire local space
  // below.
  first : Array[ValType]

  // This is a "compressed" list of locals for this function. The list of
  // locals are represented as a list of tuples. The second element is the
  // type of the local, and the first element is monotonically increasing as
  // you visit elements of this list. The first element is the maximum index
  // of the local, after the previous index, of the type specified.
  //
  // This allows us to do a binary search on the list for a local's index for
  // `local.{get,set,tee}`. We do a binary search for the index desired, and
  // it either lies in a "hole" where the maximum index is specified later,
  // or it's at the end of the list meaning it's out of bounds.
  all : Array[(UInt, ValType)]
}

///|
/// A Wasm control flow block on the control flow stack during Wasm validation.
//
// # Dev. Note
//
// This structure corresponds to `ctrl_frame` as specified at in the validation
// appendix of the wasm spec
pub(all) struct Frame {
  /// Indicator for what kind of instruction pushed this frame.
  kind : FrameKind
  /// The type signature of this frame, represented as a singular return type
  /// or a type index pointing into the module's types.
  block_type : BlockType
  /// The index, below which, this frame cannot modify the operand stack.
  height : Int
  /// Whether this frame is unreachable so far.
  mut unreachable_ : Bool
  /// The number of initializations in the stack at the time of its creation
  init_height : Int
}

///|
/// Like `derive(Debug)`, but with upstream's field name: `unreachable` is a
/// reserved word in MoonBit, so the field itself is `unreachable_`.
pub impl Debug for Frame with fn to_repr(self) {
  Repr::record({
    "kind": Debug::to_repr(self.kind),
    "block_type": Debug::to_repr(self.block_type),
    "height": Debug::to_repr(self.height),
    "unreachable": Debug::to_repr(self.unreachable_),
    "init_height": Debug::to_repr(self.init_height),
  })
}

///|
/// `OperatorValidatorTemp`: the operator validator together with the
/// resources and the offset of the current operator.
pub struct OperatorValidatorTemp {
  priv mut offset : Int
  priv inner : OperatorValidator
  priv resources : ValidatorResources
}

///|
/// Reusable allocations of an [`OperatorValidator`].
pub struct OperatorValidatorAllocations {
  priv popped_types_tmp : Array[MaybeType]
  priv control : Array[Frame]
  priv operands : Array[MaybeType]
  priv local_inits : LocalInits
  priv locals_first : Array[ValType]
  priv locals_all : Array[(UInt, ValType)]
}

///|
pub fn OperatorValidatorAllocations::default() -> OperatorValidatorAllocations {
  {
    popped_types_tmp: [],
    control: [],
    operands: [],
    local_inits: LocalInits::new(),
    locals_first: [],
    locals_all: [],
  }
}

///|
/// Type storage within the validator.
///
/// When managing the operand stack in unreachable code, the validator may not
/// fully know an operand's type. this unknown state is known as the `bottom`
/// type in the WebAssembly specification. Validating further instructions may
/// give us more information; either partial (`PartialRef`) or fully known.
///
/// Packed into an `Int` (upstream keeps it in 4 bytes too):
/// - `Bottom`: -1
/// - `UnknownRef(None)`: -2, `UnknownRef(Some(t))`: -3 - index of `t`
/// - `Known(ty)`: `ty` encoded by `encode_val_type` (non-negative)
priv struct MaybeType(Int) derive(Eq)

///|
/// The unpacked form of a [`MaybeType`].
priv enum MaybeTypeView {
  /// The operand has no available type information due to unreachable code.
  ///
  /// This state represents "unknown" and corresponds to the `bottom` type in
  /// the WebAssembly specification. There are no constraints on what this
  /// type may be and it can match any other type during validation.
  Bottom
  /// The operand is known to be a reference and we may know its abstract
  /// type.
  ///
  /// This state is not fully `Known`, however, because its type can be
  /// interpreted as either:
  /// - `shared` or not-`shared`
  /// -  nullable or not nullable
  ///
  /// No further refinements are required for WebAssembly instructions today
  /// but this may grow in the future.
  UnknownRef(AbstractHeapType?)
  /// The operand is known to have type `T`.
  Known(ValType)
}

///|
/// `MaybeType<RefType>`.
priv enum MaybeRef {
  Bottom
  UnknownRef(AbstractHeapType?)
  Known(RefType)
}

///|
let abstract_heap_types : ReadOnlyArray[AbstractHeapType] = [
  Func,
  Extern,
  Any,
  None_,
  NoExtern,
  NoFunc,
  Eq,
  Struct,
  Array,
  I31,
  Exn,
  NoExn,
  Cont,
  NoCont,
]

///|
fn abstract_heap_type_index(t : AbstractHeapType) -> Int {
  match t {
    Func => 0
    Extern => 1
    Any => 2
    None_ => 3
    NoExtern => 4
    NoFunc => 5
    Eq => 6
    Struct => 7
    Array => 8
    I31 => 9
    Exn => 10
    NoExn => 11
    Cont => 12
    NoCont => 13
  }
}

///|
fn encode_val_type(ty : ValType) -> Int {
  match ty {
    I32 => 0
    I64 => 1
    F32 => 2
    F64 => 3
    V128 => 4
    Ref(r) => (r.0.reinterpret_as_int() << 3) | 5
  }
}

///|
let maybe_bottom : MaybeType = MaybeType(-1)

///|
fn MaybeType::known(ty : ValType) -> MaybeType {
  MaybeType(encode_val_type(ty))
}

///|
fn MaybeType::unknown_ref(ty : AbstractHeapType?) -> MaybeType {
  match ty {
    None => MaybeType(-2)
    Some(t) => MaybeType(-3 - abstract_heap_type_index(t))
  }
}

///|
fn MaybeType::from_ref(ty : MaybeRef) -> MaybeType {
  match ty {
    Bottom => maybe_bottom
    UnknownRef(t) => MaybeType::unknown_ref(t)
    Known(t) => MaybeType::known(Ref(t))
  }
}

///|
fn MaybeType::view(self : MaybeType) -> MaybeTypeView {
  let x = self.0
  if x >= 0 {
    Known(
      match x & 7 {
        0 => I32
        1 => I64
        2 => F32
        3 => F64
        4 => V128
        _ => Ref(RefType((x >> 3).reinterpret_as_uint()))
      },
    )
  } else if x == -1 {
    Bottom
  } else if x == -2 {
    UnknownRef(None)
  } else {
    UnknownRef(Some(abstract_heap_types[-3 - x]))
  }
}

///|
fn MaybeRef::as_non_null(self : MaybeRef) -> MaybeRef {
  match self {
    Bottom => Bottom
    UnknownRef(ty) => UnknownRef(ty)
    Known(ty) => Known(ty.as_non_null())
  }
}

///|
fn MaybeRef::is_maybe_shared(
  self : MaybeRef,
  resources : ValidatorResources,
) -> Bool? {
  match self {
    Bottom => None
    UnknownRef(_) => None
    Known(ty) => Some(resources.is_shared(ty))
  }
}

///|
fn OperatorValidator::new(
  features : WasmFeatures,
  allocs : OperatorValidatorAllocations,
) -> OperatorValidator {
  {
    locals: {
      num_locals: 0,
      first: allocs.locals_first,
      all: allocs.locals_all,
    },
    local_inits: allocs.local_inits,
    features,
    popped_types_tmp: allocs.popped_types_tmp,
    operands: allocs.operands,
    control: allocs.control,
    end_which_emptied_control: None,
    shared: false,
  }
}

///|
/// Creates a new operator validator which will be used to validate a
/// function whose type is the `ty` index specified.
///
/// The `resources` are used to learn about the function type underlying
/// `ty`.
fn OperatorValidator::new_func(
  ty : UInt,
  offset : Int,
  features : WasmFeatures,
  resources : ValidatorResources,
  allocs : OperatorValidatorAllocations,
) -> OperatorValidator raise BinaryReaderError {
  let ret = OperatorValidator::new(features, allocs)
  ret.control.push({
    kind: Block,
    block_type: FuncType(ty),
    height: 0,
    unreachable_: false,
    init_height: 0,
  })

  // Retrieve the function's type via index (`ty`); the `offset` is
  // necessary due to `sub_type_at`'s error messaging.
  let sub_ty = { offset, inner: ret, resources, }.sub_type_at(ty)

  // Set up the function's locals.
  if sub_ty.composite_type.inner is Func(func_ty) {
    for ty in func_ty.params() {
      ret.locals.define_(1, ty) |> ignore
    }
    ret.local_inits.define_params(func_ty.params().length())
  } else {
    bail(offset, "expected func type at index \{ty}, found \{sub_ty}")
  }

  // If we're in a shared function, ensure we do not access unshared
  // objects.
  if sub_ty.composite_type.shared {
    ret.shared = true
  }
  ret
}

///|
/// Creates a new operator validator which will be used to validate an
/// `init_expr` constant expression which should result in the `ty`
/// specified.
fn OperatorValidator::new_const_expr(
  features : WasmFeatures,
  ty : ValType,
  allocs : OperatorValidatorAllocations,
) -> OperatorValidator {
  let ret = OperatorValidator::new(features, allocs)
  ret.control.push({
    kind: Block,
    block_type: Type(ty),
    height: 0,
    unreachable_: false,
    init_height: 0,
  })
  ret
}

///|
fn OperatorValidator::define_locals(
  self : OperatorValidator,
  offset : Int,
  count : UInt,
  ty : ValType,
  resources : ValidatorResources,
) -> Unit raise BinaryReaderError {
  let ty = resources.check_value_type(ty, self.features, offset)
  if count == 0 {
    return
  }
  if !self.locals.define_(count, ty) {
    raise BinaryReaderError::new(
      "too many locals: locals exceed maximum", offset,
    )
  }
  self.local_inits.define_locals(count, ty)
}

///|
/// Returns the current operands stack height.
pub fn OperatorValidator::operand_stack_height(self : OperatorValidator) -> Int {
  self.operands.length()
}

///|
/// Returns the optional value type of the value operand at the given
/// `depth` from the top of the operand stack.
///
/// - Returns `None` if the `depth` is out of bounds.
/// - Returns `Some(None)` if there is a value with unknown type
/// at the given `depth`.
///
/// # Note
///
/// A `depth` of 0 will refer to the last operand on the stack.
pub fn OperatorValidator::peek_operand_at(
  self : OperatorValidator,
  depth : Int,
) -> ValType?? {
  let n = self.operands.length()
  if depth < 0 || depth >= n {
    return None
  }
  match self.operands[n - 1 - depth].view() {
    Known(t) => Some(Some(t))
    Bottom | UnknownRef(_) => Some(None)
  }
}

///|
/// Returns the number of frames on the control flow stack.
pub fn OperatorValidator::control_stack_height(self : OperatorValidator) -> Int {
  self.control.length()
}

///|
pub fn OperatorValidator::get_frame(
  self : OperatorValidator,
  depth : Int,
) -> Frame? {
  let n = self.control.length()
  if depth < 0 || depth >= n {
    None
  } else {
    Some(self.control[n - 1 - depth])
  }
}

///|
/// Create a temporary [`OperatorValidatorTemp`] for validation.
fn OperatorValidator::with_resources(
  self : OperatorValidator,
  resources : ValidatorResources,
  offset : Int,
) -> WasmProposalValidator {
  WasmProposalValidator({ offset, inner: self, resources, })
}

///|
pub fn OperatorValidator::finish(
  self : OperatorValidator,
  offset : Int,
) -> Unit raise BinaryReaderError {
  if self.control.length() > 0 {
    bail(
      offset, "control frames remain at end of function: END opcode expected",
    )
  }

  // The `end` opcode is one byte which means that the `offset` here
  // should point just beyond the `end` opcode which emptied the control
  // stack. If not that means more instructions were present after the
  // control stack was emptied.
  if offset != self.end_which_emptied_control.unwrap() + 1 {
    raise self.err_beyond_end(offset)
  }
}

///|
fn OperatorValidator::err_beyond_end(
  _self : OperatorValidator,
  offset : Int,
) -> BinaryReaderError {
  BinaryReaderError::new("operators remaining after end of function", offset)
}

///|
fn OperatorValidator::into_allocations(
  self : OperatorValidator,
) -> OperatorValidatorAllocations {
  self.popped_types_tmp.clear()
  self.control.clear()
  self.operands.clear()
  self.local_inits.clear()
  self.locals.first.clear()
  self.locals.all.clear()
  {
    popped_types_tmp: self.popped_types_tmp,
    control: self.control,
    operands: self.operands,
    local_inits: self.local_inits,
    locals_first: self.locals.first,
    locals_all: self.locals.all,
  }
}

///|
/// Pushes a type onto the operand stack.
///
/// This is used by instructions to represent a value that is pushed to the
/// operand stack. This can fail, but only if `Type` is feature gated.
/// Otherwise the push operation always succeeds.
fn OperatorValidatorTemp::push_operand(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit {
  self.inner.operands.push(MaybeType::known(ty))
}

///|
fn OperatorValidatorTemp::push_maybe_operand(
  self : OperatorValidatorTemp,
  ty : MaybeType,
) -> Unit {
  self.inner.operands.push(ty)
}

///|
fn OperatorValidatorTemp::push_concrete_ref(
  self : OperatorValidatorTemp,
  nullable : Bool,
  type_index : UInt,
) -> Unit raise BinaryReaderError {
  let heap_ty = HeapType::Concrete(Module(type_index))

  // Canonicalize the module index into an id.
  let heap_ty = self.resources.check_heap_type(heap_ty, self.offset)
  let ref_ty = match RefType::new(nullable, heap_ty) {
    Some(t) => t
    None => bail(self.offset, "implementation limit: type index too large")
  }
  self.push_operand(Ref(ref_ty))
}

///|
fn OperatorValidatorTemp::pop_concrete_ref(
  self : OperatorValidatorTemp,
  nullable : Bool,
  type_index : UInt,
) -> MaybeType raise BinaryReaderError {
  let heap_ty = HeapType::Concrete(Module(type_index))

  // Canonicalize the module index into an id.
  let heap_ty = self.resources.check_heap_type(heap_ty, self.offset)
  let ref_ty = match RefType::new(nullable, heap_ty) {
    Some(t) => t
    None => bail(self.offset, "implementation limit: type index too large")
  }
  self.pop_operand(Some(Ref(ref_ty)))
}

///|
/// Pop the given label types, checking that they are indeed present on the
/// stack, and then push them back on again.
fn OperatorValidatorTemp::pop_push_label_types(
  self : OperatorValidatorTemp,
  label_types : ArrayView[ValType],
) -> Unit raise BinaryReaderError {
  for i = label_types.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(label_types[i])) |> ignore
  }
  for ty in label_types {
    self.push_operand(ty)
  }
}

///|
/// Attempts to pop a type from the operand stack.
///
/// This function is used to remove types from the operand stack. The
/// `expected` argument can be used to indicate that a type is required, or
/// simply that something is needed to be popped.
///
/// If `expected` is `Some(T)` then this will be guaranteed to return
/// `T`, and it will only return success if the current block is
/// unreachable or if `T` was found at the top of the operand stack.
///
/// If `expected` is `None` then it indicates that something must be on the
/// operand stack, but it doesn't matter what's on the operand stack. This
/// is useful for polymorphic instructions like `select`.
///
/// If `Some(T)` is returned then `T` was popped from the operand stack and
/// matches `expected`. If `None` is returned then it means that `None` was
/// expected and a type was successfully popped, but its exact type is
/// indeterminate because the current block is unreachable.
fn OperatorValidatorTemp::pop_operand(
  self : OperatorValidatorTemp,
  expected : ValType?,
) -> MaybeType raise BinaryReaderError {
  // This method is one of the hottest methods in the validator so to
  // improve codegen this method contains a fast-path success case where
  // if the top operand on the stack is as expected it's returned
  // immediately. This is the most common case where the stack will indeed
  // have the expected type and all we need to do is pop it off.
  //
  // Note that this still has to be careful to be correct, though. For
  // efficiency an operand is unconditionally popped and on success it is
  // matched against the state of the world to see if we could actually
  // pop it. If we shouldn't have popped it then it's passed to the slow
  // path to get pushed back onto the stack.
  let operands = self.inner.operands
  let popped = operands.pop()
  if popped is Some(actual) && actual.0 >= 0 {
    if expected is Some(e) && encode_val_type(e) == actual.0 {
      let control = self.inner.control
      if control.length() > 0 &&
        operands.length() >= control[control.length() - 1].height {
        return actual
      }
    }
  }
  self.pop_operand_slow(expected, popped)
}

///|
// This is the "real" implementation of `pop_operand` which is 100%
// spec-compliant with little attention paid to efficiency since this is the
// slow-path from the actual `pop_operand` function above.
fn OperatorValidatorTemp::pop_operand_slow(
  self : OperatorValidatorTemp,
  expected : ValType?,
  popped : MaybeType?,
) -> MaybeType raise BinaryReaderError {
  if popped is Some(p) {
    self.inner.operands.push(p)
  }
  let control = match self.inner.control.last() {
    Some(c) => c
    None => raise self.inner.err_beyond_end(self.offset)
  }
  let actual = if self.inner.operands.length() == control.height &&
    control.unreachable_ {
    maybe_bottom
  } else if self.inner.operands.length() == control.height {
    let desc = match expected {
      Some(ty) => ty_to_str(ty)
      None => "a type"
    }
    bail(self.offset, "type mismatch: expected \{desc} but nothing on stack")
  } else {
    self.inner.operands.pop().unwrap()
  }
  if expected is Some(expected) {
    match (actual.view(), expected) {
      // The bottom type matches all expectations
      (Bottom, _) => ()

      // The "heap bottom" type only matches other references types,
      // but not any integer types. Note that if the heap bottom is
      // known to have a specific abstract heap type then a subtype
      // check is performed against hte expected type.
      (UnknownRef(actual_ty), Ref(expected)) =>
        if actual_ty is Some(actual) {
          let expected_shared = self.resources.is_shared(expected)
          let actual = RefType::new(
            false,
            Abstract(shared=expected_shared, ty=actual),
          ).unwrap()
          if !self.resources.is_subtype(Ref(actual), Ref(expected)) {
            bail(
              self.offset,
              "type mismatch: expected \{ty_to_str(Ref(expected))}, found \{ty_to_str(Ref(actual))}",
            )
          }
        }

      // Use the `is_subtype` predicate to test if a found type matches
      // the expectation.
      (Known(actual), expected) =>
        if !self.resources.is_subtype(actual, expected) {
          bail(
            self.offset,
            "type mismatch: expected \{ty_to_str(expected)}, found \{ty_to_str(actual)}",
          )
        }

      // A "heap bottom" type cannot match any numeric types.
      (UnknownRef(_), I32 | I64 | F32 | F64 | V128) =>
        bail(
          self.offset,
          "type mismatch: expected \{ty_to_str(expected)}, found heap type",
        )
    }
  }
  actual
}

///|
/// Match expected vs. actual operand.
fn OperatorValidatorTemp::match_operand(
  self : OperatorValidatorTemp,
  actual : ValType,
  expected : ValType,
) -> Unit raise BinaryReaderError {
  self.push_operand(actual)
  self.pop_operand(Some(expected)) |> ignore
}

///|
/// Match a type sequence to the top of the stack.
fn OperatorValidatorTemp::match_stack_operands(
  self : OperatorValidatorTemp,
  expected_tys : ArrayView[ValType],
) -> Unit raise BinaryReaderError {
  let tmp = self.inner.popped_types_tmp
  for i = expected_tys.length() - 1; i >= 0; i = i - 1 {
    let actual_ty = self.pop_operand(Some(expected_tys[i]))
    tmp.push(actual_ty)
  }
  for i = tmp.length() - 1; i >= 0; i = i - 1 {
    self.inner.operands.push(tmp[i])
  }
  tmp.clear()
}

///|
/// Pop a reference type from the operand stack.
fn OperatorValidatorTemp::pop_ref(
  self : OperatorValidatorTemp,
  expected : RefType?,
) -> MaybeRef raise BinaryReaderError {
  let expected = match expected {
    Some(t) => Some(ValType::Ref(t))
    None => None
  }
  match self.pop_operand(expected).view() {
    Bottom => UnknownRef(None)
    UnknownRef(ty) => UnknownRef(ty)
    Known(Ref(rt)) => Known(rt)
    Known(ty) =>
      bail(
        self.offset,
        "type mismatch: expected ref but found \{ty_to_str(ty)}",
      )
  }
}

///|
/// Pop a reference type from the operand stack, checking if it is a subtype
/// of a nullable type of `expected` or the shared version of `expected`.
///
/// This function returns the popped reference type and its `shared`-ness,
/// saving extra lookups for concrete types.
fn OperatorValidatorTemp::pop_maybe_shared_ref(
  self : OperatorValidatorTemp,
  expected : AbstractHeapType,
) -> MaybeRef raise BinaryReaderError {
  let actual = match self.pop_ref(None) {
    Bottom => return Bottom
    UnknownRef(None) => return UnknownRef(None)
    UnknownRef(Some(actual)) => {
      if !actual.is_subtype_of(expected) {
        bail(
          self.offset,
          "type mismatch: expected subtype of \{expected.as_str(false)}, found \{actual.as_str(false)}",
        )
      }
      return UnknownRef(Some(actual))
    }
    Known(ty) => ty
  }
  // Change our expectation based on whether we're dealing with an actual
  // shared or unshared type.
  let is_actual_shared = self.resources.is_shared(actual)
  let expected = RefType::new(
    true,
    Abstract(shared=is_actual_shared, ty=expected),
  ).unwrap()

  // Check (again) that the actual type is a subtype of the expected type.
  // Note that `_pop_operand` already does this kind of thing but we leave
  // that for a future refactoring (TODO).
  if !self.resources.is_subtype(Ref(actual), Ref(expected)) {
    bail(
      self.offset,
      "type mismatch: expected subtype of \{expected}, found \{actual}",
    )
  }
  Known(actual)
}

///|
/// Fetches the type for the local at `idx`, returning an error if it's out
/// of bounds.
fn OperatorValidatorTemp::local_(
  self : OperatorValidatorTemp,
  idx : UInt,
) -> ValType raise BinaryReaderError {
  match self.inner.locals.get(idx) {
    Some(ty) => ty
    None => bail(self.offset, "unknown local \{idx}: local index out of bounds")
  }
}

///|
/// Flags the current control frame as unreachable, additionally truncating
/// the currently active operand stack.
fn OperatorValidatorTemp::unreachable_(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  let control = match self.inner.control.last() {
    Some(frame) => frame
    None => raise self.inner.err_beyond_end(self.offset)
  }
  control.unreachable_ = true
  let new_height = control.height
  self.inner.operands.truncate(new_height)
}

///|
/// Pushes a new frame onto the control stack.
///
/// This operation is used when entering a new block such as an if, loop,
/// or block itself. The `kind` of block is specified which indicates how
/// breaks interact with this block's type. Additionally the type signature
/// of the block is specified by `ty`.
fn OperatorValidatorTemp::push_ctrl(
  self : OperatorValidatorTemp,
  kind : FrameKind,
  ty : BlockType,
) -> Unit raise BinaryReaderError {
  // Push a new frame which has a snapshot of the height of the current
  // operand stack.
  let height = self.inner.operands.length()
  let init_height = self.inner.local_inits.push_ctrl()
  self.inner.control.push({
    kind,
    block_type: ty,
    height,
    unreachable_: false,
    init_height,
  })
  // All of the parameters are now also available in this control frame,
  // so we push them here in order.
  for ty in self.params(ty) {
    self.push_operand(ty)
  }
}

///|
/// Pops a frame from the control stack.
///
/// This function is used when exiting a block and leaves a block scope.
/// Internally this will validate that blocks have the correct result type.
fn OperatorValidatorTemp::pop_ctrl(
  self : OperatorValidatorTemp,
) -> Frame raise BinaryReaderError {
  // Read the expected type and expected height of the operand stack the
  // end of the frame.
  let frame = match self.inner.control.last() {
    Some(f) => f
    None => raise self.inner.err_beyond_end(self.offset)
  }
  let ty = frame.block_type
  let height = frame.height
  let init_height = frame.init_height

  // reset_locals in the spec
  self.inner.local_inits.pop_ctrl(init_height)

  // Pop all the result types, in reverse order, from the operand stack.
  // These types will, possibly, be transferred to the next frame.
  let results = self.results(ty)
  for i = results.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(results[i])) |> ignore
  }

  // Make sure that the operand stack has returned to is original
  // height...
  if self.inner.operands.length() != height {
    bail(
      self.offset,
      "type mismatch: values remaining on stack at end of block",
    )
  }

  // And then we can remove it!
  self.inner.control.pop().unwrap()
}

///|
/// Validates a relative jump to the `depth` specified.
///
/// Returns the type signature of the block that we're jumping to as well
/// as the kind of block if the jump is valid. Otherwise returns an error.
fn OperatorValidatorTemp::jump(
  self : OperatorValidatorTemp,
  depth : UInt,
) -> (BlockType, FrameKind) raise BinaryReaderError {
  let control = self.inner.control
  if control.length() == 0 {
    raise self.inner.err_beyond_end(self.offset)
  }
  let last = (control.length() - 1).reinterpret_as_uint()
  if depth <= last {
    let frame = control[(last - depth).reinterpret_as_int()]
    (frame.block_type, frame.kind)
  } else {
    bail(self.offset, "unknown label: branch depth too large")
  }
}

///|
/// Validates that `memory_index` is valid in this module, and returns the
/// type of address used to index the memory specified.
fn OperatorValidatorTemp::check_memory_index(
  self : OperatorValidatorTemp,
  memory_index : UInt,
) -> ValType raise BinaryReaderError {
  match self.resources.memory_at(memory_index) {
    Some(mem) => mem.index_type()
    None => bail(self.offset, "unknown memory \{memory_index}")
  }
}

///|
/// Validates a `memarg for alignment and such (also the memory it
/// references), and returns the type of index used to address the memory.
fn OperatorValidatorTemp::check_memarg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> ValType raise BinaryReaderError {
  let index_ty = self.check_memory_index(memarg.memory)
  if memarg.align > memarg.max_align {
    bail(
      self.offset,
      "malformed memop alignment: alignment must not be larger than natural",
    )
  }
  if index_ty == I32 && memarg.offset > 0xFFFF_FFFFUL {
    bail(self.offset, "offset out of range: must be <= 2**32")
  }
  index_ty
}

///|
fn OperatorValidatorTemp::check_floats_enabled(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  if !self.inner.features.floats() {
    bail(self.offset, "floating-point instruction disallowed")
  }
}

///|
fn OperatorValidatorTemp::check_shared_memarg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> ValType raise BinaryReaderError {
  if memarg.align != memarg.max_align {
    bail(
      self.offset,
      "atomic instructions must always specify maximum alignment",
    )
  }
  self.check_memory_index(memarg.memory)
}

///|
/// Validates a block type, primarily with various in-flight proposals.
fn OperatorValidatorTemp::check_block_type(
  self : OperatorValidatorTemp,
  ty : BlockType,
) -> BlockType raise BinaryReaderError {
  match ty {
    Empty => ty
    Type(t) =>
      Type(self.resources.check_value_type(t, self.inner.features, self.offset))
    FuncType(idx) => {
      if !self.inner.features.multi_value() {
        bail(
          self.offset,
          "blocks, loops, and ifs may only produce a resulttype when multi-value is not enabled",
        )
      }
      self.func_type_at(idx) |> ignore
      ty
    }
  }
}

///|
/// Returns the corresponding function type for the `func` item located at
/// `function_index`.
fn OperatorValidatorTemp::type_of_function(
  self : OperatorValidatorTemp,
  function_index : UInt,
) -> FuncType raise BinaryReaderError {
  if self.resources.type_index_of_function(function_index) is Some(type_index) {
    self.func_type_at(type_index)
  } else {
    bail(
      self.offset,
      "unknown function \{function_index}: function index out of bounds",
    )
  }
}

///|
/// Checks a call-style instruction which will be invoking the function `ty`
/// specified.
///
/// This will pop parameters from the operand stack for the function's
/// parameters and then push the results of the function on the stack.
fn OperatorValidatorTemp::check_call_ty(
  self : OperatorValidatorTemp,
  ty : FuncType,
) -> Unit raise BinaryReaderError {
  let params = ty.params()
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }
  for ty in ty.results() {
    self.push_operand(ty)
  }
}

///|
/// Similar to `check_call_ty` except used for tail-call instructions.
fn OperatorValidatorTemp::check_return_call_ty(
  self : OperatorValidatorTemp,
  ty : FuncType,
) -> Unit raise BinaryReaderError {
  self.check_func_type_same_results(ty)
  let params = ty.params()
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }

  // Match the results with this function's, but don't include in pop/push counts.
  for ty in ty.results() {
    self.push_operand(ty)
  }
  self.check_return()
}

///|
/// Checks the immediate `type_index` of a `call_ref`-style instruction
/// (also `return_call_ref`).
///
/// This will validate that the value on the stack is a `(ref type_index)`
/// or a subtype. This will then return the corresponding function type used
/// for this call (to be used with `check_call_ty` or
/// `check_return_call_ty`).
fn OperatorValidatorTemp::check_call_ref_ty(
  self : OperatorValidatorTemp,
  type_index : UInt,
) -> FuncType raise BinaryReaderError {
  let unpacked_index = UnpackedIndex::Module(type_index)
  let hty = HeapType::Concrete(unpacked_index)
  let hty = self.resources.check_heap_type(hty, self.offset)
  let expected = RefType::new(true, hty).unwrap()
  self.pop_ref(Some(expected)) |> ignore
  self.func_type_at(type_index)
}

///|
/// Validates the immediate operands of a `call_indirect` or
/// `return_call_indirect` instruction.
///
/// This will validate that `table_index` is valid and a funcref table. It
/// will additionally pop the index argument which is used to index into the
/// table.
///
/// The return value of this function is the function type behind
/// `type_index` which must then be passed to `check_{call,return_call}_ty`.
fn OperatorValidatorTemp::check_call_indirect_ty(
  self : OperatorValidatorTemp,
  type_index : UInt,
  table_index : UInt,
) -> FuncType raise BinaryReaderError {
  let tab = self.table_type_at(table_index)
  if !self.resources.is_subtype(Ref(tab.element_type), valtype_funcref) {
    bail(
      self.offset,
      "type mismatch: indirect calls must go through a table with type <= funcref",
    )
  }
  self.pop_operand(Some(tab.index_type())) |> ignore
  self.func_type_at(type_index)
}

///|
/// Validates a `return` instruction, popping types from the operand
/// stack that the function needs.
fn OperatorValidatorTemp::check_return(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  if self.inner.control.length() == 0 {
    raise self.inner.err_beyond_end(self.offset)
  }
  let results = self.results(self.inner.control[0].block_type)
  for i = results.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(results[i])) |> ignore
  }
  self.unreachable_()
}

///|
/// Check that the given type has the same result types as the current
/// function's results.
fn OperatorValidatorTemp::check_func_type_same_results(
  self : OperatorValidatorTemp,
  callee_ty : FuncType,
) -> Unit raise BinaryReaderError {
  if self.inner.control.length() == 0 {
    raise self.inner.err_beyond_end(self.offset)
  }
  let caller_rets = self.results(self.inner.control[0].block_type)
  let callee_rets = callee_ty.results()
  let mut ok = callee_rets.length() == caller_rets.length()
  if ok {
    for i in 0..<caller_rets.length() {
      if !self.resources.is_subtype(callee_rets[i], caller_rets[i]) {
        ok = false
        break
      }
    }
  }
  if !ok {
    let caller_rets = caller_rets.iter().map(ty => ty.to_string()).join(" ")
    let callee_rets = callee_rets.iter().map(ty => ty.to_string()).join(" ")
    bail(
      self.offset,
      "type mismatch: current function requires result type [\{caller_rets}] but callee returns [\{callee_rets}]",
    )
  }
}

///|
/// Checks the validity of a common comparison operator.
fn OperatorValidatorTemp::check_cmp_op(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I32)
}

///|
/// Checks the validity of a common float comparison operator.
fn OperatorValidatorTemp::check_fcmp_op(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_cmp_op(ty)
}

///|
/// Checks the validity of a common unary operator.
fn OperatorValidatorTemp::check_unary_op(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(ty)
}

///|
/// Checks the validity of a common unary float operator.
fn OperatorValidatorTemp::check_funary_op(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_unary_op(ty)
}

///|
/// Checks the validity of a common conversion operator.
fn OperatorValidatorTemp::check_conversion_op(
  self : OperatorValidatorTemp,
  into : ValType,
  from : ValType,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(from)) |> ignore
  self.push_operand(into)
}

///|
/// Checks the validity of a common float conversion operator.
fn OperatorValidatorTemp::check_fconversion_op(
  self : OperatorValidatorTemp,
  into : ValType,
  from : ValType,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_conversion_op(into, from)
}

///|
/// Checks the validity of a common binary operator.
fn OperatorValidatorTemp::check_binary_op(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(ty)
}

///|
/// Checks the validity of a common binary float operator.
fn OperatorValidatorTemp::check_fbinary_op(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.check_binary_op(ty)
}

///|
/// Checks the validity of an atomic load operator.
fn OperatorValidatorTemp::check_atomic_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  load_ty : ValType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_shared_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(load_ty)
}

///|
/// Checks the validity of an atomic store operator.
fn OperatorValidatorTemp::check_atomic_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  store_ty : ValType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_shared_memarg(memarg)
  self.pop_operand(Some(store_ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
/// Checks the validity of atomic binary operator on memory.
fn OperatorValidatorTemp::check_atomic_binary_memory_op(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  op_ty : ValType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_shared_memarg(memarg)
  self.pop_operand(Some(op_ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(op_ty)
}

///|
/// Checks the validity of an atomic compare exchange operator on memories.
fn OperatorValidatorTemp::check_atomic_binary_memory_cmpxchg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
  op_ty : ValType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_shared_memarg(memarg)
  self.pop_operand(Some(op_ty)) |> ignore
  self.pop_operand(Some(op_ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(op_ty)
}

///|
fn OperatorValidatorTemp::element_type_at(
  self : OperatorValidatorTemp,
  elem_index : UInt,
) -> RefType raise BinaryReaderError {
  match self.resources.element_type_at(elem_index) {
    Some(ty) => ty
    None =>
      bail(
        self.offset,
        "unknown elem segment \{elem_index}: segment index out of bounds",
      )
  }
}

///|
fn OperatorValidatorTemp::sub_type_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> SubType raise BinaryReaderError {
  match self.resources.sub_type_at(at) {
    Some(t) => t
    None => bail(self.offset, "unknown type: type index out of bounds")
  }
}

///|
fn OperatorValidatorTemp::struct_type_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> StructType raise BinaryReaderError {
  let sub_ty = self.sub_type_at(at)
  if sub_ty.composite_type.inner is Struct(struct_ty) {
    if self.inner.shared && !sub_ty.composite_type.shared {
      bail(self.offset, "shared functions cannot access unshared structs")
    }
    struct_ty
  } else {
    bail(self.offset, "expected struct type at index \{at}, found \{sub_ty}")
  }
}

///|
fn OperatorValidatorTemp::struct_field_at(
  self : OperatorValidatorTemp,
  struct_type_index : UInt,
  field_index : UInt,
) -> FieldType raise BinaryReaderError {
  let fields = self.struct_type_at(struct_type_index).fields
  if field_index < fields.length().reinterpret_as_uint() {
    fields[field_index.reinterpret_as_int()]
  } else {
    raise BinaryReaderError::new(
      "unknown field: field index out of bounds",
      self.offset,
    )
  }
}

///|
fn OperatorValidatorTemp::mutable_struct_field_at(
  self : OperatorValidatorTemp,
  struct_type_index : UInt,
  field_index : UInt,
) -> FieldType raise BinaryReaderError {
  let field = self.struct_field_at(struct_type_index, field_index)
  if !field.mutable {
    bail(self.offset, "invalid struct modification: struct field is immutable")
  }
  field
}

///|
fn OperatorValidatorTemp::array_type_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> FieldType raise BinaryReaderError {
  let sub_ty = self.sub_type_at(at)
  if sub_ty.composite_type.inner is Array(array_ty) {
    if self.inner.shared && !sub_ty.composite_type.shared {
      bail(self.offset, "shared functions cannot access unshared arrays")
    }
    array_ty.0
  } else {
    bail(self.offset, "expected array type at index \{at}, found \{sub_ty}")
  }
}

///|
fn OperatorValidatorTemp::mutable_array_type_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> FieldType raise BinaryReaderError {
  let field = self.array_type_at(at)
  if !field.mutable {
    bail(self.offset, "invalid array modification: array is immutable")
  }
  field
}

///|
fn OperatorValidatorTemp::func_type_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> FuncType raise BinaryReaderError {
  let sub_ty = self.sub_type_at(at)
  if sub_ty.composite_type.inner is Func(func_ty) {
    if self.inner.shared && !sub_ty.composite_type.shared {
      bail(self.offset, "shared functions cannot access unshared functions")
    }
    func_ty
  } else {
    bail(self.offset, "expected func type at index \{at}, found \{sub_ty}")
  }
}

///|
fn OperatorValidatorTemp::tag_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> FuncType raise BinaryReaderError {
  match self.resources.tag_at(at) {
    Some(t) => t
    None => bail(self.offset, "unknown tag \{at}: tag index out of bounds")
  }
}

///|
// Similar to `tag_at`, but checks that the result type is
// empty. This is necessary when enabling the stack switching
// feature as it allows non-empty result types on tags.
fn OperatorValidatorTemp::exception_tag_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> FuncType raise BinaryReaderError {
  let func_ty = self.tag_at(at)
  if func_ty.results().length() != 0 {
    bail(self.offset, "invalid exception type: non-empty tag result type")
  }
  func_ty
}

///|
fn OperatorValidatorTemp::global_type_at(
  self : OperatorValidatorTemp,
  at : UInt,
) -> GlobalType raise BinaryReaderError {
  if self.resources.global_at(at) is Some(ty) {
    if self.inner.shared && !ty.shared {
      bail(self.offset, "shared functions cannot access unshared globals")
    }
    ty
  } else {
    bail(self.offset, "unknown global: global index out of bounds")
  }
}

///|
/// Validates that the `table` is valid and returns the type it points to.
fn OperatorValidatorTemp::table_type_at(
  self : OperatorValidatorTemp,
  table : UInt,
) -> TableType raise BinaryReaderError {
  match self.resources.table_at(table) {
    Some(ty) => {
      if self.inner.shared && !ty.shared {
        bail(self.offset, "shared functions cannot access unshared tables")
      }
      ty
    }
    None =>
      bail(self.offset, "unknown table \{table}: table index out of bounds")
  }
}

///|
let no_val_types : Array[ValType] = []

///|
fn OperatorValidatorTemp::params(
  self : OperatorValidatorTemp,
  ty : BlockType,
) -> ArrayView[ValType] raise BinaryReaderError {
  match ty {
    Empty | Type(_) => no_val_types[:]
    FuncType(t) => self.func_type_at(t).params()
  }
}

///|
fn OperatorValidatorTemp::results(
  self : OperatorValidatorTemp,
  ty : BlockType,
) -> ArrayView[ValType] raise BinaryReaderError {
  match ty {
    Empty => no_val_types[:]
    Type(t) => [t][:]
    FuncType(t) => self.func_type_at(t).results()
  }
}

///|
fn OperatorValidatorTemp::label_types(
  self : OperatorValidatorTemp,
  ty : BlockType,
  kind : FrameKind,
) -> ArrayView[ValType] raise BinaryReaderError {
  match kind {
    Loop => self.params(ty)
    _ => self.results(ty)
  }
}

///|
fn OperatorValidatorTemp::check_data_segment(
  self : OperatorValidatorTemp,
  data_index : UInt,
) -> Unit raise BinaryReaderError {
  match self.resources.data_count() {
    None => bail(self.offset, "data count section required")
    Some(count) if data_index < count => ()
    Some(_) => bail(self.offset, "unknown data segment \{data_index}")
  }
}

///|
fn OperatorValidatorTemp::check_binop128(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(I64)) |> ignore
  self.push_operand(I64)
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::check_i64_mul_wide(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(I64)) |> ignore
  self.push_operand(I64)
  self.push_operand(I64)
}

///|
/// The error of the stubs for operators whose validation is not ported.
fn OperatorValidatorTemp::not_ported(
  self : OperatorValidatorTemp,
  visit : String,
) -> BinaryReaderError {
  BinaryReaderError::new(
    "wasmparser port: `\{visit}` is not supported",
    self.offset,
  )
}

///|
pub fn ty_to_str(ty : ValType) -> String {
  match ty {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
    V128 => "v128"
    Ref(r) => r.wat()
  }
}

///|
/// A wrapper "visitor" around the real operator validator internally which
/// exists to check that the required wasm feature is enabled to proceed with
/// validation.
///
/// This validator is macro-generated to ensure that the proposal listed in this
/// crate's macro matches the one that's validated here. Each instruction's
/// visit method validates the specified proposal is enabled and then delegates
/// to `OperatorValidatorTemp` to perform the actual opcode validation.
pub struct WasmProposalValidator(OperatorValidatorTemp)

///|
fn WasmProposalValidator::check_enabled(
  self : WasmProposalValidator,
  flag : Bool,
  desc : String,
) -> Unit raise BinaryReaderError {
  if flag {
    return
  }
  bail(self.0.offset, "\{desc} support is not enabled")
}

///|
/// Sets the offset of the operator being validated (for error messages).
pub fn WasmProposalValidator::set_offset(
  self : WasmProposalValidator,
  offset : Int,
) -> Unit {
  self.0.offset = offset
}

// --- `impl VisitOperator for OperatorValidatorTemp` ---

///|
// Cannot fail; visitor methods share `Result<()>`
// (wasmparser 0.228.0 src/validator/operators.rs:1819).
#warnings("-unused_error_type")
fn OperatorValidatorTemp::visit_nop(
  _self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  ()
}

///|
fn OperatorValidatorTemp::visit_unreachable(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.unreachable_()
}

///|
fn OperatorValidatorTemp::visit_block(
  self : OperatorValidatorTemp,
  ty : BlockType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_block_type(ty)
  let params = self.params(ty)
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }
  self.push_ctrl(Block, ty)
}

///|
fn OperatorValidatorTemp::visit_loop(
  self : OperatorValidatorTemp,
  ty : BlockType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_block_type(ty)
  let params = self.params(ty)
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }
  self.push_ctrl(Loop, ty)
}

///|
fn OperatorValidatorTemp::visit_if(
  self : OperatorValidatorTemp,
  ty : BlockType,
) -> Unit raise BinaryReaderError {
  let ty = self.check_block_type(ty)
  self.pop_operand(Some(I32)) |> ignore
  let params = self.params(ty)
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }
  self.push_ctrl(If, ty)
}

///|
fn OperatorValidatorTemp::visit_else(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  let frame = self.pop_ctrl()
  if frame.kind != If {
    bail(self.offset, "else found outside of an `if` block")
  }
  self.push_ctrl(Else, frame.block_type)
}

///|
fn OperatorValidatorTemp::visit_try_table(
  self : OperatorValidatorTemp,
  ty : TryTable,
) -> Unit raise BinaryReaderError {
  let block_ty = self.check_block_type(ty.ty)
  let params = self.params(block_ty)
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }
  let exn_type = ValType::Ref(reftype_exn)
  for catch_ in ty.catches {
    match catch_ {
      One(tag~, label~) => {
        let tag = self.exception_tag_at(tag)
        let (ty, kind) = self.jump(label)
        let params = tag.params()
        let types = self.label_types(ty, kind)
        if params.length() != types.length() {
          bail(
            self.offset,
            "type mismatch: catch label must have same number of types as tag",
          )
        }
        for i in 0..<types.length() {
          self.match_operand(params[i], types[i])
        }
      }
      OneRef(tag~, label~) => {
        let tag = self.exception_tag_at(tag)
        let (ty, kind) = self.jump(label)
        let tag_params = tag.params()
        let label_types = self.label_types(ty, kind)
        if tag_params.length() + 1 != label_types.length() {
          bail(
            self.offset,
            "type mismatch: catch_ref label must have one more type than tag types",
          )
        }
        for i in 0..<label_types.length() {
          let actual = if i < tag_params.length() {
            tag_params[i]
          } else {
            exn_type
          }
          self.match_operand(actual, label_types[i])
        }
      }
      All(label~) => {
        let (ty, kind) = self.jump(label)
        if self.label_types(ty, kind).length() != 0 {
          bail(
            self.offset,
            "type mismatch: catch_all label must have no result types",
          )
        }
      }
      AllRef(label~) => {
        let (ty, kind) = self.jump(label)
        let types = self.label_types(ty, kind)
        let ty = if types.length() == 1 {
          types[0]
        } else {
          bail(
            self.offset,
            "type mismatch: catch_all_ref label must have exactly one result type",
          )
        }
        if !self.resources.is_subtype(exn_type, ty) {
          bail(
            self.offset,
            "type mismatch: catch_all_ref label must a subtype of (ref exn)",
          )
        }
      }
    }
  }
  self.push_ctrl(TryTable, block_ty)
}

///|
fn OperatorValidatorTemp::visit_throw(
  self : OperatorValidatorTemp,
  index : UInt,
) -> Unit raise BinaryReaderError {
  // Check values associated with the exception.
  let ty = self.exception_tag_at(index)
  let params = ty.params()
  for i = params.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(params[i])) |> ignore
  }
  self.unreachable_()
}

///|
fn OperatorValidatorTemp::visit_throw_ref(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(valtype_exnref)) |> ignore
  self.unreachable_()
}

///|
fn OperatorValidatorTemp::visit_end(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  let mut frame = self.pop_ctrl()

  // Note that this `if` isn't included in the appendix right
  // now, but it's used to allow for `if` statements that are
  // missing an `else` block which have the same parameter/return
  // types on the block (since that's valid).
  if frame.kind == If {
    self.push_ctrl(Else, frame.block_type)
    frame = self.pop_ctrl()
  }
  for ty in self.results(frame.block_type) {
    self.push_operand(ty)
  }
  if self.inner.control.length() == 0 &&
    self.inner.end_which_emptied_control is None {
    if !(self.offset != 0) {
      abort("assertion failed: self.offset != 0")
    }
    self.inner.end_which_emptied_control = Some(self.offset)
  }
}

///|
fn OperatorValidatorTemp::visit_br(
  self : OperatorValidatorTemp,
  relative_depth : UInt,
) -> Unit raise BinaryReaderError {
  let (ty, kind) = self.jump(relative_depth)
  let types = self.label_types(ty, kind)
  for i = types.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(types[i])) |> ignore
  }
  self.unreachable_()
}

///|
fn OperatorValidatorTemp::visit_br_if(
  self : OperatorValidatorTemp,
  relative_depth : UInt,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I32)) |> ignore
  let (ty, kind) = self.jump(relative_depth)
  let label_types = self.label_types(ty, kind)
  self.pop_push_label_types(label_types)
}

///|
fn OperatorValidatorTemp::visit_br_table(
  self : OperatorValidatorTemp,
  table : BrTable,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I32)) |> ignore
  let default = self.jump(table.default())
  let default_types = self.label_types(default.0, default.1)
  for relative_depth in table.targets() {
    let block = self.jump(relative_depth)
    let label_tys = self.label_types(block.0, block.1)
    if label_tys.length() != default_types.length() {
      bail(
        self.offset,
        "type mismatch: br_table target labels have different number of types",
      )
    }
    self.match_stack_operands(label_tys)
  }
  for i = default_types.length() - 1; i >= 0; i = i - 1 {
    self.pop_operand(Some(default_types[i])) |> ignore
  }
  self.unreachable_()
}

///|
fn OperatorValidatorTemp::visit_return(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_return()
}

///|
fn OperatorValidatorTemp::visit_call(
  self : OperatorValidatorTemp,
  function_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.type_of_function(function_index)
  self.check_call_ty(ty)
}

///|
fn OperatorValidatorTemp::visit_return_call(
  self : OperatorValidatorTemp,
  function_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.type_of_function(function_index)
  self.check_return_call_ty(ty)
}

///|
fn OperatorValidatorTemp::visit_call_ref(
  self : OperatorValidatorTemp,
  type_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_call_ref_ty(type_index)
  self.check_call_ty(ty)
}

///|
fn OperatorValidatorTemp::visit_return_call_ref(
  self : OperatorValidatorTemp,
  type_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_call_ref_ty(type_index)
  self.check_return_call_ty(ty)
}

///|
fn OperatorValidatorTemp::visit_call_indirect(
  self : OperatorValidatorTemp,
  type_index : UInt,
  table_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_call_indirect_ty(type_index, table_index)
  self.check_call_ty(ty)
}

///|
fn OperatorValidatorTemp::visit_return_call_indirect(
  self : OperatorValidatorTemp,
  type_index : UInt,
  table_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_call_indirect_ty(type_index, table_index)
  self.check_return_call_ty(ty)
}

///|
fn OperatorValidatorTemp::visit_drop(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(None) |> ignore
}

///|
fn OperatorValidatorTemp::visit_select(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I32)) |> ignore
  let ty1 = self.pop_operand(None)
  let ty2 = self.pop_operand(None)
  let ty = match (ty1.view(), ty2.view()) {
    // All heap-related types aren't allowed with the `select`
    // instruction
    (UnknownRef(_), _)
    | (_, UnknownRef(_))
    | (Known(Ref(_)), _)
    | (_, Known(Ref(_))) =>
      bail(self.offset, "type mismatch: select only takes integral types")

    // If one operand is the "bottom" type then whatever the other
    // operand is is the result of the `select`
    (Bottom, _) => ty2
    (_, Bottom) => ty1

    // Otherwise these are two integral types and they must match for
    // `select` to typecheck.
    (Known(t1), Known(t2)) => {
      if t1 != t2 {
        bail(self.offset, "type mismatch: select operands have different types")
      }
      ty1
    }
  }
  self.push_maybe_operand(ty)
}

///|
fn OperatorValidatorTemp::visit_typed_select(
  self : OperatorValidatorTemp,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  let ty = self.resources.check_value_type(ty, self.inner.features, self.offset)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(ty)
}

///|
fn OperatorValidatorTemp::visit_local_get(
  self : OperatorValidatorTemp,
  local_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.local_(local_index)
  if self.inner.local_inits.is_uninit(local_index) {
    bail(self.offset, "uninitialized local: \{local_index}")
  }
  self.push_operand(ty)
}

///|
fn OperatorValidatorTemp::visit_local_set(
  self : OperatorValidatorTemp,
  local_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.local_(local_index)
  self.pop_operand(Some(ty)) |> ignore
  self.inner.local_inits.set_init(local_index)
}

///|
fn OperatorValidatorTemp::visit_local_tee(
  self : OperatorValidatorTemp,
  local_index : UInt,
) -> Unit raise BinaryReaderError {
  let expected_ty = self.local_(local_index)
  self.pop_operand(Some(expected_ty)) |> ignore
  self.inner.local_inits.set_init(local_index)
  self.push_operand(expected_ty)
}

///|
fn OperatorValidatorTemp::visit_global_get(
  self : OperatorValidatorTemp,
  global_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.global_type_at(global_index).content_type
  self.push_operand(ty)
}

///|
fn OperatorValidatorTemp::visit_global_set(
  self : OperatorValidatorTemp,
  global_index : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.global_type_at(global_index)
  if !ty.mutable {
    bail(self.offset, "global is immutable: cannot modify it with `global.set`")
  }
  self.pop_operand(Some(ty.content_type)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i32_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i64_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::visit_f32_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(F32)
}

///|
fn OperatorValidatorTemp::visit_f64_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(F64)
}

///|
fn OperatorValidatorTemp::visit_i32_load8_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_load8_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.visit_i32_load8_s(memarg)
}

///|
fn OperatorValidatorTemp::visit_i32_load16_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_load16_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.visit_i32_load16_s(memarg)
}

///|
fn OperatorValidatorTemp::visit_i64_load8_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_load8_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.visit_i64_load8_s(memarg)
}

///|
fn OperatorValidatorTemp::visit_i64_load16_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_load16_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.visit_i64_load16_s(memarg)
}

///|
fn OperatorValidatorTemp::visit_i64_load32_s(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_load32_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.visit_i64_load32_s(memarg)
}

///|
fn OperatorValidatorTemp::visit_i32_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i64_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_f32_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(F32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_f64_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(F64)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i32_store8(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i32_store16(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i64_store8(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i64_store16(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i64_store32(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memarg(memarg)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_memory_size(
  self : OperatorValidatorTemp,
  mem : UInt,
) -> Unit raise BinaryReaderError {
  let index_ty = self.check_memory_index(mem)
  self.push_operand(index_ty)
}

///|
fn OperatorValidatorTemp::visit_memory_grow(
  self : OperatorValidatorTemp,
  mem : UInt,
) -> Unit raise BinaryReaderError {
  let index_ty = self.check_memory_index(mem)
  self.pop_operand(Some(index_ty)) |> ignore
  self.push_operand(index_ty)
}

///|
// Cannot fail; visitor methods share `Result<()>`
// (wasmparser 0.228.0 src/validator/operators.rs:2364).
#warnings("-unused_error_type")
fn OperatorValidatorTemp::visit_i32_const(
  self : OperatorValidatorTemp,
  _value : Int,
) -> Unit raise BinaryReaderError {
  self.push_operand(I32)
}

///|
// Cannot fail; visitor methods share `Result<()>`
// (wasmparser 0.228.0 src/validator/operators.rs:2368).
#warnings("-unused_error_type")
fn OperatorValidatorTemp::visit_i64_const(
  self : OperatorValidatorTemp,
  _value : Int64,
) -> Unit raise BinaryReaderError {
  self.push_operand(I64)
}

///|
fn OperatorValidatorTemp::visit_f32_const(
  self : OperatorValidatorTemp,
  _value : Ieee32,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.push_operand(F32)
}

///|
fn OperatorValidatorTemp::visit_f64_const(
  self : OperatorValidatorTemp,
  _value : Ieee64,
) -> Unit raise BinaryReaderError {
  self.check_floats_enabled()
  self.push_operand(F64)
}

///|
fn OperatorValidatorTemp::visit_i32_eqz(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I32)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_lt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_lt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_gt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_gt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_le_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_le_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_ge_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_ge_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i64_eqz(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_operand(Some(I64)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_i64_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_lt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_lt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_gt_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_gt_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_le_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_le_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_ge_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_ge_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_cmp_op(I64)
}

///|
fn OperatorValidatorTemp::visit_f32_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_lt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_gt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_le(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_ge(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f64_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_ne(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_lt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_gt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_le(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_ge(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fcmp_op(F64)
}

///|
fn OperatorValidatorTemp::visit_i32_clz(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_ctz(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_popcnt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_div_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_div_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_rem_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_rem_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_and(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_or(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_xor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_shl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_shr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_shr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_rotl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_rotr(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i64_clz(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_ctz(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_popcnt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_div_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_div_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_rem_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_rem_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_and(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_or(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_xor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_shl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_shr_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_shr_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_rotl(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_rotr(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_f32_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_ceil(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_floor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_trunc(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_nearest(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_sqrt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_div(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_min(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_max(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f32_copysign(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F32)
}

///|
fn OperatorValidatorTemp::visit_f64_abs(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_neg(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_ceil(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_floor(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_trunc(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_nearest(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_sqrt(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_funary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_add(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_sub(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_mul(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_div(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_min(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_max(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_f64_copysign(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fbinary_op(F64)
}

///|
fn OperatorValidatorTemp::visit_i32_wrap_i64(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, I64)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_f32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F32)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_f32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F32)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_f64_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F64)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_f64_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F64)
}

///|
fn OperatorValidatorTemp::visit_i64_extend_i32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, I32)
}

///|
fn OperatorValidatorTemp::visit_i64_extend_i32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, I32)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_f32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F32)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_f32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F32)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_f64_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F64)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_f64_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F64)
}

///|
fn OperatorValidatorTemp::visit_f32_convert_i32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F32, I32)
}

///|
fn OperatorValidatorTemp::visit_f32_convert_i32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F32, I32)
}

///|
fn OperatorValidatorTemp::visit_f32_convert_i64_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F32, I64)
}

///|
fn OperatorValidatorTemp::visit_f32_convert_i64_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F32, I64)
}

///|
fn OperatorValidatorTemp::visit_f32_demote_f64(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F32, F64)
}

///|
fn OperatorValidatorTemp::visit_f64_convert_i32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F64, I32)
}

///|
fn OperatorValidatorTemp::visit_f64_convert_i32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F64, I32)
}

///|
fn OperatorValidatorTemp::visit_f64_convert_i64_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F64, I64)
}

///|
fn OperatorValidatorTemp::visit_f64_convert_i64_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F64, I64)
}

///|
fn OperatorValidatorTemp::visit_f64_promote_f32(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F64, F32)
}

///|
fn OperatorValidatorTemp::visit_i32_reinterpret_f32(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F32)
}

///|
fn OperatorValidatorTemp::visit_i64_reinterpret_f64(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F64)
}

///|
fn OperatorValidatorTemp::visit_f32_reinterpret_i32(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F32, I32)
}

///|
fn OperatorValidatorTemp::visit_f64_reinterpret_i64(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_fconversion_op(F64, I64)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_sat_f32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F32)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_sat_f32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F32)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_sat_f64_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F64)
}

///|
fn OperatorValidatorTemp::visit_i32_trunc_sat_f64_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I32, F64)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_sat_f32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F32)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_sat_f32_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F32)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_sat_f64_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F64)
}

///|
fn OperatorValidatorTemp::visit_i64_trunc_sat_f64_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_conversion_op(I64, F64)
}

///|
fn OperatorValidatorTemp::visit_i32_extend8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i32_extend16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I32)
}

///|
fn OperatorValidatorTemp::visit_i64_extend8_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_extend16_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i64_extend32_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_unary_op(I64)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_load16_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_load8_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_load(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_load32_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_load16_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_load8_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_load(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_store16(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_store8(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_store(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_store32(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_store16(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_store8(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_store(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_add(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_sub(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_and(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_or(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_xor(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_add_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_sub_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_and_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_or_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_xor_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_add_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_sub_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_and_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_or_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_xor_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_add(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_sub(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_and(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_or(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_xor(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_add_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_sub_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_and_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_or_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_xor_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_add_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_sub_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_and_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_or_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_xor_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_add_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_sub_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_and_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_or_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_xor_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_xchg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_xchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_xchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw_cmpxchg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw16_cmpxchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i32_atomic_rmw8_cmpxchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_xchg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_xchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_xchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_xchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw_cmpxchg(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw32_cmpxchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw16_cmpxchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_i64_atomic_rmw8_cmpxchg_u(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_cmpxchg(memarg, I64)
}

///|
fn OperatorValidatorTemp::visit_memory_atomic_notify(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  self.check_atomic_binary_memory_op(memarg, I32)
}

///|
fn OperatorValidatorTemp::visit_memory_atomic_wait32(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_shared_memarg(memarg)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_memory_atomic_wait64(
  self : OperatorValidatorTemp,
  memarg : MemArg,
) -> Unit raise BinaryReaderError {
  let ty = self.check_shared_memarg(memarg)
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(I64)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
  self.push_operand(I32)
}

///|
// Cannot fail; visitor methods share `Result<()>`
// (wasmparser 0.228.0 src/validator/operators.rs:3002).
#warnings("-unused_error_type")
fn OperatorValidatorTemp::visit_atomic_fence(
  _self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  ()
}

///|
fn OperatorValidatorTemp::visit_ref_null(
  self : OperatorValidatorTemp,
  heap_type : HeapType,
) -> Unit raise BinaryReaderError {
  if RefType::new(true, heap_type) is Some(ty) {
    match self.inner.features.check_ref_type(ty) {
      None => ()
      Some(e) => raise BinaryReaderError::new(e, self.offset)
    }
  }
  let heap_type = self.resources.check_heap_type(heap_type, self.offset)
  let ty = ValType::Ref(RefType::new(true, heap_type).unwrap())
  self.push_operand(ty)
}

///|
fn OperatorValidatorTemp::visit_ref_as_non_null(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  let ty = self.pop_ref(None).as_non_null()
  self.push_maybe_operand(MaybeType::from_ref(ty))
}

///|
fn OperatorValidatorTemp::visit_br_on_null(
  self : OperatorValidatorTemp,
  relative_depth : UInt,
) -> Unit raise BinaryReaderError {
  let ref_ty = self.pop_ref(None).as_non_null()
  let (ft, kind) = self.jump(relative_depth)
  let label_types = self.label_types(ft, kind)
  self.pop_push_label_types(label_types)
  self.push_maybe_operand(MaybeType::from_ref(ref_ty))
}

///|
fn OperatorValidatorTemp::visit_br_on_non_null(
  self : OperatorValidatorTemp,
  relative_depth : UInt,
) -> Unit raise BinaryReaderError {
  let (ft, kind) = self.jump(relative_depth)
  let label_types = self.label_types(ft, kind)
  let n = label_types.length()
  let expected = if n == 0 {
    bail(self.offset, "type mismatch: br_on_non_null target has no label types")
  } else {
    match label_types[n - 1] {
      Ref(ty) => ty
      _ =>
        bail(
          self.offset,
          "type mismatch: br_on_non_null target does not end with heap type",
        )
    }
  }
  self.pop_ref(Some(expected.nullable())) |> ignore
  self.pop_push_label_types(label_types[:n - 1])
}

///|
fn OperatorValidatorTemp::visit_ref_is_null(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.pop_ref(None) |> ignore
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_ref_func(
  self : OperatorValidatorTemp,
  function_index : UInt,
) -> Unit raise BinaryReaderError {
  let type_id = match self.resources.type_id_of_function(function_index) {
    Some(id) => id
    None =>
      bail(
        self.offset,
        "unknown function \{function_index}: function index out of bounds",
      )
  }
  if !self.resources.is_function_referenced(function_index) {
    bail(self.offset, "undeclared function reference")
  }
  let index = UnpackedIndex::Id(type_id)
  let ty = match RefType::new(false, Concrete(index)) {
    Some(t) => ValType::Ref(t)
    None =>
      raise BinaryReaderError::new(
        "implementation limit: type index too large",
        self.offset,
      )
  }
  self.push_operand(ty)
}

///|
fn OperatorValidatorTemp::visit_ref_eq(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  let a = self.pop_maybe_shared_ref(Eq)
  let b = self.pop_maybe_shared_ref(Eq)
  let a_is_shared = a.is_maybe_shared(self.resources)
  let b_is_shared = b.is_maybe_shared(self.resources)
  match (a_is_shared, b_is_shared) {
    // One or both of the types are from unreachable code; assume
    // the shared-ness matches.
    (None, Some(_)) | (Some(_), None) | (None, None) => ()
    (Some(is_a_shared), Some(is_b_shared)) =>
      if is_a_shared != is_b_shared {
        bail(
          self.offset,
          "type mismatch: expected `ref.eq` types to match `shared`-ness",
        )
      }
  }
  self.push_operand(I32)
}

///|
fn OperatorValidatorTemp::visit_memory_init(
  self : OperatorValidatorTemp,
  segment : UInt,
  mem : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memory_index(mem)
  self.check_data_segment(segment)
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_data_drop(
  self : OperatorValidatorTemp,
  segment : UInt,
) -> Unit raise BinaryReaderError {
  self.check_data_segment(segment)
}

///|
fn OperatorValidatorTemp::visit_memory_copy(
  self : OperatorValidatorTemp,
  dst : UInt,
  src : UInt,
) -> Unit raise BinaryReaderError {
  let dst_ty = self.check_memory_index(dst)
  let src_ty = self.check_memory_index(src)

  // The length operand here is the smaller of src/dst, which is
  // i32 if one is i32
  self.pop_operand(
    Some(
      match src_ty {
        I32 => I32
        _ => dst_ty
      },
    ),
  )
  |> ignore

  // ... and the offset into each memory is required to be
  // whatever the indexing type is for that memory
  self.pop_operand(Some(src_ty)) |> ignore
  self.pop_operand(Some(dst_ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_memory_fill(
  self : OperatorValidatorTemp,
  mem : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memory_index(mem)
  self.pop_operand(Some(ty)) |> ignore
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_memory_discard(
  self : OperatorValidatorTemp,
  mem : UInt,
) -> Unit raise BinaryReaderError {
  let ty = self.check_memory_index(mem)
  self.pop_operand(Some(ty)) |> ignore
  self.pop_operand(Some(ty)) |> ignore
}

///|
fn OperatorValidatorTemp::visit_table_init(
  self : OperatorValidatorTemp,
  segment : UInt,
  table : UInt,
) -> Unit raise BinaryReaderError {
  let table = self.table_type_at(table)
  let segment_ty = self.element_type_at(segment)
  if !self.resources.is_subtype(Ref(segment_ty), Ref(table.element_type)) {
    bail(self.offset, "type mismatch")
  }
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(I32)) |> ignore
  self.pop_operand(Some(table.index_type())) |> ignore
}

///|
fn OperatorValidatorTemp::visit_elem_drop(
  self : OperatorValidatorTemp,
  segment : UInt,
) -> Unit raise BinaryReaderError {
  self.element_type_at(segment) |> ignore
}

///|
fn OperatorValidatorTemp::visit_table_copy(
  self : OperatorValidatorTemp,
  dst_table : UInt,
  src_table : UInt,
) -> Unit raise BinaryReaderError {
  let src = self.table_type_at(src_table)
  let dst = self.table_type_at(dst_table)
  if !self.resources.is_subtype(Ref(src.element_type), Ref(dst.element_type)) {
    bail(self.offset, "type mismatch")
  }

  // The length operand here is the smaller of src/dst, which is
  // i32 if one is i32
  self.pop_operand(
    Some(
      match src.index_type() {
        I32 => I32
        _ => dst.index_type()
      },
    ),
  )
  |> ignore

  // ... and the offset into each table is required to be
  // whatever the indexing type is for that table
  self.pop_operand(Some(src.index_type())) |> ignore
  self.pop_operand(Some(dst.index_type())) |> ignore
}

///|
fn OperatorValidatorTemp::visit_table_get(
  self : OperatorValidatorTemp,
  table : UInt,
) -> Unit raise BinaryReaderError {
  let table = self.table_type_at(table)
  self.pop_operand(Some(table.index_type())) |> ignore
  self.push_operand(Ref(table.element_type))
}

///|
fn OperatorValidatorTemp::visit_table_set(
  self : OperatorValidatorTemp,
  table : UInt,
) -> Unit raise BinaryReaderError {
  let table = self.table_type_at(table)
  self.pop_operand(Some(Ref(table.element_type))) |> ignore
  self.pop_operand(Some(table.index_type())) |> ignore
}

///|
fn OperatorValidatorTemp::visit_table_grow(
  self : OperatorValidatorTemp,
  table : UInt,
) -> Unit raise BinaryReaderError {
  let table = self.table_type_at(table)
  self.pop_operand(Some(table.index_type())) |> ignore
  self.pop_operand(Some(Ref(table.element_type))) |> ignore
  self.push_operand(table.index_type())
}

///|
fn OperatorValidatorTemp::visit_table_size(
  self : OperatorValidatorTemp,
  table : UInt,
) -> Unit raise BinaryReaderError {
  let table = self.table_type_at(table)
  self.push_operand(table.index_type())
}

///|
fn OperatorValidatorTemp::visit_table_fill(
  self : OperatorValidatorTemp,
  table : UInt,
) -> Unit raise BinaryReaderError {
  let table = self.table_type_at(table)
  self.pop_operand(Some(table.index_type())) |> ignore
  self.pop_operand(Some(Ref(table.element_type))) |> ignore
  self.pop_operand(Some(table.index_type())) |> ignore
}

///|
fn OperatorValidatorTemp::visit_i64_add128(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binop128()
}

///|
fn OperatorValidatorTemp::visit_i64_sub128(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_binop128()
}

///|
fn OperatorValidatorTemp::visit_i64_mul_wide_s(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_i64_mul_wide()
}

///|
fn OperatorValidatorTemp::visit_i64_mul_wide_u(
  self : OperatorValidatorTemp,
) -> Unit raise BinaryReaderError {
  self.check_i64_mul_wide()
}

///|
/// Defines another group of `count` local variables of type `ty`.
///
/// Returns `true` if the definition was successful. Local variable
/// definition is unsuccessful in case the amount of total variables
/// after definition exceeds the allowed maximum number.
fn Locals::define_(self : Locals, count : UInt, ty : ValType) -> Bool {
  let n = self.num_locals.to_uint64() + count.to_uint64()
  if n > 0xFFFF_FFFFUL {
    return false
  }
  self.num_locals = n.to_uint()
  if self.num_locals > MAX_WASM_FUNCTION_LOCALS.reinterpret_as_uint() {
    return false
  }
  for _ in 0U..<count {
    if self.first.length() >= max_locals_to_track {
      break
    }
    self.first.push(ty)
  }
  self.all.push((self.num_locals - 1, ty))
  true
}

///|
/// Returns the number of defined local variables.
pub fn Locals::len_locals(self : Locals) -> UInt {
  self.num_locals
}

///|
/// Returns the type of the local variable at the given index if any.
pub fn Locals::get(self : Locals, idx : UInt) -> ValType? {
  if idx < self.first.length().reinterpret_as_uint() {
    Some(self.first[idx.reinterpret_as_int()])
  } else {
    self.get_bsearch(idx)
  }
}

///|
fn Locals::get_bsearch(self : Locals, idx : UInt) -> ValType? {
  // `binary_search_by_key(&idx, |(idx, _)| *idx)`: the first entry whose
  // maximum index is `>= idx`. If this index would be inserted at the end
  // of the list, then the index is out of bounds.
  let all = self.all
  let mut lo = 0
  let mut hi = all.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if all[mid].0 < idx {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo == all.length() {
    None
  } else {
    Some(all[lo].1)
  }
}
