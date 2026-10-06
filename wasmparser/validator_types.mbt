// Port of wasmparser 0.228.0 `src/validator/types.rs` (core types only).
//
// Deviation: upstream's `SnapshotList` (an append-only list that is
// "committed" into `Arc`-shared snapshots) is a plain growable array here;
// `commit` shares it. Within the validation of one module no types are added
// after the code section starts (when upstream takes its snapshot), so this
// is not observable.

///|
/// Represents a unique identifier for a core type type known to a
/// [`crate::Validator`].
pub(all) struct CoreTypeId {
  index : UInt
} derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CoreTypeId with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CoreTypeId with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CoreTypeId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CoreTypeId with @debug.Debug::{to_repr}

///|
fn CoreTypeId::from_index(index : UInt) -> CoreTypeId {
  { index, }
}

///|
/// The index of this id in the type list.
pub fn CoreTypeId::index(self : CoreTypeId) -> Int {
  self.index.reinterpret_as_int()
}

///|
/// Represents a unique identifier for a recursion group type known to a
/// [`crate::Validator`].
pub(all) struct RecGroupId {
  index : UInt
} derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RecGroupId with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RecGroupId with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RecGroupId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RecGroupId with @debug.Debug::{to_repr}

///|
fn RecGroupId::from_index(index : UInt) -> RecGroupId {
  { index, }
}

///|
/// The index of this id in the type list.
pub fn RecGroupId::index(self : RecGroupId) -> Int {
  self.index.reinterpret_as_int()
}

///|
/// Metadata about a type and its transitive structure.
///
/// Currently contains two properties:
///
/// * The "size" of a type - a proxy to the recursive size of a type if
///   everything in the type were unique (e.g. no shared references). Not an
///   approximation of runtime size, but instead of type-complexity size if
///   someone were to visit each element of the type individually. For
///   example `u32` has size 1 and `(list u32)` has size 2 (roughly). Used
///   to prevent massive trees of types.
///
/// * Whether or not a type contains a "borrow" transitively inside of it. For
///   example `(borrow $t)` and `(list (borrow $t))` both contain borrows, but
///   `(list u32)` does not. Used to validate that component function results do
///   not contain borrows.
///
/// Currently this is represented as a compact 32-bit integer to ensure that
/// `TypeId`, which this is stored in, remains relatively small. The maximum
/// type size allowed in wasmparser is 1M at this time which is 20 bits of
/// information, and then one more bit is used for whether or not a borrow is
/// used. Currently this uses the low 24 bits for the type size and the MSB for
/// the borrow bit.
priv struct TypeInfo(UInt)

///|
/// Creates a new blank set of type information.
///
/// Defaults to size 1 to ensure that this consumes space in the final type
/// structure.
fn TypeInfo::new() -> TypeInfo {
  TypeInfo::new_(1, false)
}

///|
/// Creates a new blank set of information about a leaf "core" type which
/// has the size `size`.
fn TypeInfo::core(size : UInt) -> TypeInfo {
  TypeInfo::new_(size, false)
}

///|
fn TypeInfo::new_(size : UInt, contains_borrow : Bool) -> TypeInfo {
  if !(size < 1U << 24) {
    abort("assertion failed: size < 1U << 24")
  }
  TypeInfo(size | ((if contains_borrow { 1U } else { 0 }) << 31))
}

///|
fn TypeInfo::size(self : TypeInfo) -> UInt {
  self.0 & 0xffffff
}

///|
fn SubType::type_info(self : SubType) -> TypeInfo {
  // TODO(#1036): calculate actual size for func, array, struct.
  let size = 1U +
    (match self.composite_type.inner {
      Func(ty) =>
        1U +
        (ty.params().length() + ty.results().length()).reinterpret_as_uint()
      Array(_) => 2
      Struct(ty) => 1U + 2U * ty.fields.length().reinterpret_as_uint()
      Cont(_) => 1
    })
  TypeInfo::core(size)
}

///|
/// A core WebAssembly entity type.
pub(all) enum EntityType {
  /// The entity is a function.
  Func(CoreTypeId)
  /// The entity is a table.
  Table(TableType)
  /// The entity is a memory.
  Memory(MemoryType)
  /// The entity is a global.
  Global(GlobalType)
  /// The entity is a tag.
  Tag(CoreTypeId)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EntityType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EntityType with @debug.Debug::{to_repr}

///|
fn EntityType::info(self : EntityType, types : TypeList) -> TypeInfo {
  match self {
    Func(id) | Tag(id) => types.get_core(id).type_info()
    Table(_) | Memory(_) | Global(_) => TypeInfo::new()
  }
}

///|
/// A list of types ("snapshot" of the validator's type arena).
pub struct TypeList {
  // Core Wasm types.
  //
  // A primary map from `CoreTypeId` to `SubType`.
  priv core_types : Array[SubType]
  // The id of each core Wasm type's rec group.
  //
  // A secondary map from `CoreTypeId` to `RecGroupId`.
  priv core_type_to_rec_group : Array[RecGroupId]
  // The supertype of each core type.
  //
  // A secondary map from `CoreTypeId` to `Option<CoreTypeId>`.
  priv core_type_to_supertype : Array[CoreTypeId?]
  // The subtyping depth of each core type. We use `u8::MAX` as a sentinel for
  // an uninitialized entry.
  //
  // A secondary map from `CoreTypeId` to `u8`.
  priv core_type_to_depth : Map[CoreTypeId, Int]
  // A primary map from `RecGroupId` to the range of the rec group's elements
  // within `core_types`.
  priv rec_group_elements : Array[(CoreTypeId, CoreTypeId)]
  // A hash map from rec group elements to their canonical `RecGroupId`.
  priv canonical_rec_groups : Map[RecGroup, RecGroupId]
}

///|
fn TypeList::new() -> TypeList {
  {
    core_types: [],
    core_type_to_rec_group: [],
    core_type_to_supertype: [],
    core_type_to_depth: {},
    rec_group_elements: [],
    canonical_rec_groups: {},
  }
}

///|
/// The core type with the given id (`types[id]`).
pub fn TypeList::get_core(self : TypeList, id : CoreTypeId) -> SubType {
  self.core_types[id.index.reinterpret_as_int()]
}

///|
/// The core type with the given id, if any.
pub fn TypeList::get(self : TypeList, id : CoreTypeId) -> SubType? {
  let i = id.index.reinterpret_as_int()
  if i >= 0 && i < self.core_types.length() {
    Some(self.core_types[i])
  } else {
    None
  }
}

///|
/// The number of core types.
pub fn TypeList::len(self : TypeList) -> Int {
  self.core_types.length()
}

///|
/// The range of the elements of the rec group `id` (`types[id]`).
fn TypeList::rec_group_range(
  self : TypeList,
  id : RecGroupId,
) -> (CoreTypeId, CoreTypeId) {
  self.rec_group_elements[id.index.reinterpret_as_int()]
}

///|
/// Intern the given recursion group (that has already been canonicalized)
/// and return its associated id and whether this was a new recursion group
/// or not.
///
/// If the `needs_type_canonicalization` flag is provided then the type will
/// be intern'd here and its indices will be canonicalized to `CoreTypeId`
/// from the previous `RecGroup`-based indices.
///
/// If the `needs_type_canonicalization` flag is `false` then it must be
/// required that `RecGroup` doesn't have any rec-group-relative references
/// and it will additionally not be intern'd.
fn TypeList::intern_canonical_rec_group(
  self : TypeList,
  needs_type_canonicalization : Bool,
  rec_group : RecGroup,
) -> (Bool, RecGroupId) {
  let rec_group_id = RecGroupId::from_index(
    self.rec_group_elements.length().reinterpret_as_uint(),
  )
  if needs_type_canonicalization {
    match self.canonical_rec_groups.get(rec_group) {
      Some(id) => return (false, id)
      None => self.canonical_rec_groups.set(rec_group, rec_group_id)
    }
  }
  let start = CoreTypeId::from_index(
    self.core_types.length().reinterpret_as_uint(),
  )
  for ty in rec_group.into_types() {
    // The key in `canonical_rec_groups` must not be modified: work on a
    // copy (upstream clones the key and then consumes the group).
    let ty = ty.deep_copy()
    let supertype = match ty.supertype_idx {
      None => None
      Some(idx) =>
        match idx.unpack() {
          RecGroup(offset) => Some(CoreTypeId::from_index(start.index + offset))
          Id(id) => Some(id)
          // Only invalid wasm has this, at this point, so defer the
          // error to later.
          Module(_) => None
        }
    }
    self.core_type_to_supertype.push(supertype)
    ty.remap_indices(index => {
      // Note that `UnpackedIndex::Id` is unmodified and
      // `UnpackedIndex::Module` means that this is invalid wasm which
      // will get an error returned later.
      if index.unpack() is RecGroup(offset) {
        UnpackedIndex::Id(CoreTypeId::from_index(start.index + offset))
        .pack()
        .unwrap()
      } else {
        index
      }
    }) catch {
      _ => abort("cannot fail")
    }
    self.core_types.push(ty)
    self.core_type_to_rec_group.push(rec_group_id)
  }
  let end = CoreTypeId::from_index(
    self.core_types.length().reinterpret_as_uint(),
  )
  self.rec_group_elements.push((start, end))
  (true, rec_group_id)
}

///|
/// A copy of this sub type whose mutable parts are not shared.
fn SubType::deep_copy(self : SubType) -> SubType {
  let inner : CompositeInnerType = match self.composite_type.inner {
    Func(f) =>
      Func(FuncType::from_raw_parts(f.params_results.copy(), f.len_params))
    Array(ArrayType(ft)) =>
      Array(ArrayType({ element_type: ft.element_type, mutable: ft.mutable, }))
    Struct(st) =>
      Struct({
        fields: st.fields.map(ft => {
          element_type: ft.element_type,
          mutable: ft.mutable,
        }),
      })
    Cont(c) => Cont({ idx: c.idx, })
  }
  {
    is_final: self.is_final,
    supertype_idx: self.supertype_idx,
    composite_type: { inner, shared: self.composite_type.shared, },
  }
}

///|
/// Helper for interning a sub type as a rec group; see
/// [`Self::intern_canonical_rec_group`].
// Only called under the `component-model` feature upstream
// (validator/types.rs:957, validator/component.rs).
#warnings("-unused_value")
fn TypeList::intern_sub_type(
  self : TypeList,
  sub_ty : SubType,
  offset : Int,
) -> CoreTypeId {
  let (_, group_id) = self.intern_canonical_rec_group(
    false,
    RecGroup::implicit(offset, sub_ty),
  )
  self.rec_group_range(group_id).0
}

///|
/// Get the `CoreTypeId` for a local index into a rec group.
fn TypeList::rec_group_local_id(
  self : TypeList,
  rec_group : RecGroupId,
  index : UInt,
  offset : Int,
) -> CoreTypeId raise BinaryReaderError {
  let (start, end) = self.rec_group_range(rec_group)
  let len = end.index - start.index
  if index < len {
    CoreTypeId::from_index(start.index + index)
  } else {
    bail(offset, "unknown type \{index}: type index out of rec group bounds")
  }
}

///|
/// Get the id of the rec group that the given type id was defined within.
pub fn TypeList::rec_group_id_of(
  self : TypeList,
  id : CoreTypeId,
) -> RecGroupId {
  self.core_type_to_rec_group[id.index.reinterpret_as_int()]
}

///|
/// Get the super type of the given type id, if any.
pub fn TypeList::supertype_of(self : TypeList, id : CoreTypeId) -> CoreTypeId? {
  self.core_type_to_supertype[id.index.reinterpret_as_int()]
}

///|
/// Get the subtyping depth of the given type. A type without any supertype
/// has depth 0.
fn TypeList::get_subtyping_depth(self : TypeList, id : CoreTypeId) -> Int {
  self.core_type_to_depth.get(id).unwrap()
}

///|
/// Set the subtyping depth of the given type. This may only be done once
/// per type.
fn TypeList::set_subtyping_depth(
  self : TypeList,
  id : CoreTypeId,
  depth : Int,
) -> Unit {
  self.core_type_to_depth.set(id, depth)
}

///|
/// Get the `CoreTypeId` for a canonicalized `UnpackedIndex`.
///
/// Panics when given a non-canonicalized `UnpackedIndex`.
fn TypeList::at_canonicalized_unpacked_index(
  self : TypeList,
  rec_group : RecGroupId,
  index : UnpackedIndex,
  offset : Int,
) -> CoreTypeId raise BinaryReaderError {
  match index {
    Module(_) => abort("not canonicalized")
    Id(id) => id
    RecGroup(idx) => self.rec_group_local_id(rec_group, idx, offset)
  }
}

///|
/// Does `a` structurally match `b`?
fn TypeList::matches(self : TypeList, a : CoreTypeId, b : CoreTypeId) -> Bool {
  let a_group = self.rec_group_id_of(a)
  let b_group = self.rec_group_id_of(b)
  self.matches_sub_type(self.get_core(a), a_group, self.get_core(b), b_group)
}

///|
/// Is `a == b` or was `a` declared (potentially transitively) to be a
/// subtype of `b`?
fn TypeList::id_is_subtype(
  self : TypeList,
  a : CoreTypeId,
  b : CoreTypeId,
) -> Bool {
  let mut a = a
  while true {
    if a == b {
      return true
    }

    // TODO: maintain supertype vectors and implement this check in O(1)
    // instead of O(n) time.
    a = match self.supertype_of(a) {
      Some(a) => a
      None => return false
    }
  }
  false
}

///|
/// Like `id_is_subtype` but for `RefType`s.
///
/// Both `a` and `b` must be canonicalized already.
pub fn TypeList::reftype_is_subtype(
  self : TypeList,
  a : RefType,
  b : RefType,
) -> Bool {
  // NB: Don't need `RecGroupId`s since we are calling from outside of the
  // rec group, and so any `PackedIndex`es we encounter have already been
  // canonicalized to `CoreTypeId`s directly.
  self.reftype_is_subtype_impl(a, None, b, None)
}

///|
/// Implementation of `RefType` and `HeapType` subtyping.
///
/// Panics if we need rec groups but aren't given them. Rec groups only need
/// to be passed in when checking subtyping of `RefType`s that we encounter
/// while validating a rec group itself.
fn TypeList::reftype_is_subtype_impl(
  self : TypeList,
  a : RefType,
  a_group : RecGroupId?,
  b : RefType,
  b_group : RecGroupId?,
) -> Bool {
  if a == b && a_group == b_group {
    return true
  }
  if a.is_nullable() && !b.is_nullable() {
    return false
  }
  let core_type_id = (group : RecGroupId?, index : UnpackedIndex) => {
    if index.as_core_type_id() is Some(id) {
      id
    } else {
      self.at_canonicalized_unpacked_index(group.unwrap(), index, -1) catch {
        _ => abort("type references are checked during canonicalization")
      }
    }
  }
  let subtype = (group : RecGroupId?, index : UnpackedIndex) => {
    let id = core_type_id(group, index)
    self.get_core(id)
  }
  match (a.heap_type(), b.heap_type()) {
    (a, b) if a == b => true
    (Abstract(shared=a_shared, ty=a_ty), Abstract(shared=b_shared, ty=b_ty)) =>
      a_shared == b_shared && a_ty.is_subtype_of(b_ty)
    (Concrete(a), Abstract(shared~, ty~)) => {
      let a_ty = subtype(a_group, a).composite_type
      if a_ty.shared != shared {
        return false
      }
      match ty {
        Any | Eq => a_ty.inner is (Array(_) | Struct(_))
        Struct => a_ty.inner is Struct(_)
        Array => a_ty.inner is Array(_)
        Func => a_ty.inner is Func(_)
        Cont => a_ty.inner is Cont(_)
        // Nothing else matches. (Avoid full wildcard matches so
        // that adding/modifying variants is easier in the future.)
        Extern | Exn | I31 | None_ | NoFunc | NoExtern | NoExn | NoCont => false
      }
    }
    (Abstract(shared~, ty~), Concrete(b)) => {
      let b_ty = subtype(b_group, b).composite_type
      if shared != b_ty.shared {
        return false
      }
      match ty {
        None_ => b_ty.inner is (Array(_) | Struct(_))
        NoFunc => b_ty.inner is Func(_)
        NoCont => b_ty.inner is Cont(_)
        // Nothing else matches. (Avoid full wildcard matches so
        // that adding/modifying variants is easier in the future.)
        Cont
        | Func
        | Extern
        | Exn
        | Any
        | Eq
        | Array
        | I31
        | Struct
        | NoExtern
        | NoExn => false
      }
    }
    (Concrete(a), Concrete(b)) =>
      self.id_is_subtype(core_type_id(a_group, a), core_type_id(b_group, b))
  }
}

///|
/// Like `id_is_subtype` but for `RefType`s.
///
/// Both `a` and `b` must be canonicalized already.
pub fn TypeList::valtype_is_subtype(
  self : TypeList,
  a : ValType,
  b : ValType,
) -> Bool {
  match (a, b) {
    (a, b) if a == b => true
    (Ref(a), Ref(b)) => self.reftype_is_subtype(a, b)
    (Ref(_), _) | (I32, _) | (I64, _) | (F32, _) | (F64, _) | (V128, _) => false
  }
}

///|
/// Is `ty` shared?
pub fn TypeList::valtype_is_shared(self : TypeList, ty : ValType) -> Bool {
  match ty {
    I32 | I64 | F32 | F64 | V128 => true
    Ref(rt) => self.reftype_is_shared(rt)
  }
}

///|
/// Is the reference type `ty` shared?
///
/// This is complicated by concrete heap types whose shared-ness must be
/// checked by looking at the type they point to.
pub fn TypeList::reftype_is_shared(self : TypeList, ty : RefType) -> Bool {
  match ty.heap_type() {
    Abstract(shared~, ..) => shared
    Concrete(index) =>
      self.get_core(index.as_core_type_id().unwrap()).composite_type.shared
  }
}

///|
/// Get the top type of the given heap type.
///
/// Concrete types must have had their indices canonicalized to core type
/// ids, otherwise this method will panic.
pub fn TypeList::top_type(self : TypeList, heap_type : HeapType) -> HeapType {
  match heap_type {
    Concrete(idx) => {
      let ty = self.get_core(idx.as_core_type_id().unwrap()).composite_type
      let shared = ty.shared
      match ty.inner {
        Func(_) => Abstract(shared~, ty=Func)
        Array(_) | Struct(_) => Abstract(shared~, ty=Any)
        Cont(_) => Abstract(shared~, ty=Cont)
      }
    }
    Abstract(shared~, ty~) => {
      let ty : AbstractHeapType = match ty {
        Func | NoFunc => Func
        Extern | NoExtern => Extern
        Any | Eq | Struct | Array | I31 | None_ => Any
        Exn | NoExn => Exn
        Cont | NoCont => Cont
      }
      Abstract(shared~, ty~)
    }
  }
}

///|
/// The type information returned by `Validator::end`/`validate_all` (upstream
/// `Types`, `TypesRef`).
pub struct Types {
  priv id : ValidatorId
  priv list : TypeList
  priv module_ : Module
}

///|
/// The id of the validator that created this.
pub fn Types::id(self : Types) -> ValidatorId {
  self.id
}

///|
/// The core type with the given id.
pub fn Types::get(self : Types, id : CoreTypeId) -> SubType? {
  self.list.get(id)
}

///|
/// Gets a core WebAssembly type id from a type index.
///
/// Note that this is not to be confused with
/// [`TypesRef::component_type_at`] which gets a component type from its
/// index, nor [`TypesRef::core_type_count_in_component`] which is not for
/// components.
///
/// # Panics
///
/// This will panic if the `index` provided is out of bounds.
pub fn Types::core_type_at_in_module(self : Types, index : UInt) -> CoreTypeId {
  self.module_.types[index.reinterpret_as_int()]
}

///|
/// Returns the number of core types defined so far.
pub fn Types::core_type_count_in_module(self : Types) -> UInt {
  self.module_.types.length().reinterpret_as_uint()
}

///|
/// Gets the type of a table at the given table index.
pub fn Types::table_at(self : Types, index : UInt) -> TableType {
  self.module_.tables[index.reinterpret_as_int()]
}

///|
/// Returns the number of tables defined so far.
pub fn Types::table_count(self : Types) -> UInt {
  self.module_.tables.length().reinterpret_as_uint()
}

///|
/// Gets the type of a memory at the given memory index.
pub fn Types::memory_at(self : Types, index : UInt) -> MemoryType {
  self.module_.memories[index.reinterpret_as_int()]
}

///|
/// Returns the number of memories defined so far.
pub fn Types::memory_count(self : Types) -> UInt {
  self.module_.memories.length().reinterpret_as_uint()
}

///|
/// Gets the type of a global at the given global index.
pub fn Types::global_at(self : Types, index : UInt) -> GlobalType {
  self.module_.globals[index.reinterpret_as_int()]
}

///|
/// Returns the number of globals defined so far.
pub fn Types::global_count(self : Types) -> UInt {
  self.module_.globals.length().reinterpret_as_uint()
}

///|
/// Gets the type of a tag at the given tag index.
pub fn Types::tag_at(self : Types, index : UInt) -> CoreTypeId {
  self.module_.tags[index.reinterpret_as_int()]
}

///|
/// Returns the number of tags defined so far.
pub fn Types::tag_count(self : Types) -> UInt {
  self.module_.tags.length().reinterpret_as_uint()
}

///|
/// Gets the type of a core function at the given function index.
pub fn Types::core_function_at(self : Types, index : UInt) -> CoreTypeId {
  self.module_.types[self.module_.functions[index.reinterpret_as_int()].reinterpret_as_int()]
}

///|
/// Gets the count of core functions defined so far.
pub fn Types::function_count(self : Types) -> UInt {
  self.module_.functions.length().reinterpret_as_uint()
}

///|
/// Gets the type of an element segment at the given element segment index.
pub fn Types::element_at(self : Types, index : UInt) -> RefType {
  self.module_.element_types[index.reinterpret_as_int()]
}

///|
/// Returns the number of elements defined so far.
pub fn Types::element_count(self : Types) -> UInt {
  self.module_.element_types.length().reinterpret_as_uint()
}
