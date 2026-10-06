// Port of wasmparser 0.228.0 `src/readers/core/types.rs`.

///|
/// A packed representation of a type index.
///
/// This type is morally an `enum` of either:
///
/// 1. An index into a Wasm module's type space.
///
/// 2. A `CoreTypeId` identifier.
///
/// 3. An index into a recursion group's elements.
///
/// The latter two variants are *canonical* while the first is not. Reading
/// raw types will produce (1), while working with types after validation
/// will produce (2) and (3).
//
// This is a bit-packed `u32` with the following layout:
//
//     [ unused:u10 kind:u2 index:u20 ]
//
// It must fit in 22 bits to keep `RefType` in 24 bits and `ValType` in 32 bits,
// so the top ten bits are unused.
//
// The `index` field's interpretation depends on the `kind` field, which may be
// one of the following:
//
// * `00`: The `index` is an index into the module's type space.
//
// * `01`: The `index` is an index into the containing type's recursion group.
//
// * `10`: The `index` is a `CoreTypeId`.
pub(all) struct PackedIndex(UInt) derive(Eq, Hash, Compare, Debug)

///|
let packed_index_kind_mask : UInt = 0b11U << 20

///|
let packed_index_index_mask : UInt = (1U << 20) - 1

///|
let packed_index_module_kind : UInt = 0b00U << 20

///|
let packed_index_rec_group_kind : UInt = 0b01U << 20

///|
let packed_index_id_kind : UInt = 0b10U << 20

///|
fn PackedIndex::unchecked_from_u32(x : UInt) -> PackedIndex {
  PackedIndex(x)
}

///|
fn PackedIndex::to_u32(id : PackedIndex) -> UInt {
  id.0
}

///|
fn PackedIndex::can_represent_index(index : UInt) -> Bool {
  (index & packed_index_index_mask) == index
}

///|
fn PackedIndex::kind(self : PackedIndex) -> UInt {
  self.0 & packed_index_kind_mask
}

///|
fn PackedIndex::index(self : PackedIndex) -> UInt {
  self.0 & packed_index_index_mask
}

///|
/// Construct a `PackedIndex` from an index into a module's types space.
pub fn PackedIndex::from_module_index(index : UInt) -> PackedIndex? {
  if PackedIndex::can_represent_index(index) {
    Some(PackedIndex(packed_index_module_kind | index))
  } else {
    None
  }
}

///|
/// Construct a `PackedIndex` from an index into the index's containing
/// recursion group.
pub fn PackedIndex::from_rec_group_index(index : UInt) -> PackedIndex? {
  if PackedIndex::can_represent_index(index) {
    Some(PackedIndex(packed_index_rec_group_kind | index))
  } else {
    None
  }
}

///|
/// Construct a `PackedIndex` from the given `CoreTypeId`.
pub fn PackedIndex::from_id(id : CoreTypeId) -> PackedIndex? {
  let index = id.index
  if PackedIndex::can_represent_index(index) {
    Some(PackedIndex(packed_index_id_kind | index))
  } else {
    None
  }
}

///|
/// Is this index in canonical form?
pub fn PackedIndex::is_canonical(self : PackedIndex) -> Bool {
  let kind = self.kind()
  if kind == packed_index_rec_group_kind || kind == packed_index_id_kind {
    true
  } else if kind == packed_index_module_kind {
    false
  } else {
    abort("unreachable")
  }
}

///|
/// Uncompress this packed index into an actual `enum` that can be matched
/// on.
pub fn PackedIndex::unpack(self : PackedIndex) -> UnpackedIndex {
  let kind = self.kind()
  if kind == packed_index_module_kind {
    Module(self.index())
  } else if kind == packed_index_rec_group_kind {
    RecGroup(self.index())
  } else if kind == packed_index_id_kind {
    Id(CoreTypeId::from_index(self.index()))
  } else {
    abort("unreachable")
  }
}

///|
/// Get the underlying index into a module's types space, if any.
pub fn PackedIndex::as_module_index(self : PackedIndex) -> UInt? {
  if self.kind() == packed_index_module_kind {
    Some(self.index())
  } else {
    None
  }
}

///|
/// Get the underlying index into the containing recursion group, if any.
pub fn PackedIndex::as_rec_group_index(self : PackedIndex) -> UInt? {
  if self.kind() == packed_index_rec_group_kind {
    Some(self.index())
  } else {
    None
  }
}

///|
/// Get the underlying `CoreTypeId`, if any.
pub fn PackedIndex::as_core_type_id(self : PackedIndex) -> CoreTypeId? {
  if self.kind() == packed_index_id_kind {
    Some(CoreTypeId::from_index(self.index()))
  } else {
    None
  }
}

///|
pub impl Show for PackedIndex with fn output(self, logger) {
  self.unpack().output(logger)
}

///|
/// The uncompressed form of a `PackedIndex`.
///
/// Can be used for `match` statements.
pub(all) enum UnpackedIndex {
  /// An index into a Wasm module's types space.
  Module(UInt)
  /// An index into the containing type's recursion group.
  RecGroup(UInt)
  /// A type identifier.
  Id(CoreTypeId)
} derive(Eq, Hash, Debug)

///|
/// Compress this index into its packed form.
///
/// Returns `None` if an index is beyond implementation limits.
pub fn UnpackedIndex::pack(self : UnpackedIndex) -> PackedIndex? {
  match self {
    Module(i) => PackedIndex::from_module_index(i)
    RecGroup(i) => PackedIndex::from_rec_group_index(i)
    Id(id) => PackedIndex::from_id(id)
  }
}

///|
/// Is this index in canonical form?
pub fn UnpackedIndex::is_canonical(self : UnpackedIndex) -> Bool {
  self is (RecGroup(_) | Id(_))
}

///|
/// Get the underlying index into a module's types space, if any.
pub fn UnpackedIndex::as_module_index(self : UnpackedIndex) -> UInt? {
  if self is Module(i) {
    Some(i)
  } else {
    None
  }
}

///|
/// Get the underlying index into the containing recursion group, if any.
pub fn UnpackedIndex::as_rec_group_index(self : UnpackedIndex) -> UInt? {
  if self is RecGroup(i) {
    Some(i)
  } else {
    None
  }
}

///|
/// Get the underlying `CoreTypeId`, if any.
pub fn UnpackedIndex::as_core_type_id(self : UnpackedIndex) -> CoreTypeId? {
  if self is Id(id) {
    Some(id)
  } else {
    None
  }
}

///|
pub impl Show for UnpackedIndex with fn output(self, logger) {
  match self {
    Module(i) => logger.write_string("(module \{i})")
    RecGroup(i) => logger.write_string("(recgroup \{i})")
    Id(id) => logger.write_string("(id \{id.index})")
  }
}

///|
/// Represents a recursive type group in a WebAssembly module.
pub struct RecGroup {
  priv inner : RecGroupInner
} derive(Debug)

///|
priv enum RecGroupInner {
  Implicit(Int, SubType)
  Explicit(Array[(Int, SubType)])
} derive(Debug)

///|
fn RecGroup::explicit(types : Array[(Int, SubType)]) -> RecGroup {
  { inner: Explicit(types), }
}

///|
fn RecGroup::implicit(offset : Int, ty : SubType) -> RecGroup {
  { inner: Implicit(offset, ty), }
}

///|
/// Is this an explicit recursion group?
pub fn RecGroup::is_explicit_rec_group(self : RecGroup) -> Bool {
  self.inner is Explicit(_)
}

///|
/// Returns the list of subtypes in the recursive type group.
pub fn RecGroup::types(self : RecGroup) -> Array[SubType] {
  match self.inner {
    Implicit(_, ty) => [ty]
    Explicit(types) => types.map(t => t.1)
  }
}

///|
/// The number of types in the group.
pub fn RecGroup::len(self : RecGroup) -> Int {
  match self.inner {
    Implicit(_, _) => 1
    Explicit(types) => types.length()
  }
}

///|
/// The `i`-th type of the group.
pub fn RecGroup::get(self : RecGroup, i : Int) -> SubType {
  match self.inner {
    Implicit(_, ty) => {
      if !(i == 0) {
        abort("assertion failed: i == 0")
      }
      ty
    }
    Explicit(types) => types[i].1
  }
}

///|
/// Return an iterator over the types in this rec group (upstream
/// `into_types`).
pub fn RecGroup::into_types(self : RecGroup) -> Array[SubType] {
  self.types()
}

///|
/// Return an iterator over the types in this rec group (with their offsets).
pub fn RecGroup::into_types_and_offsets(
  self : RecGroup,
) -> Array[(Int, SubType)] {
  match self.inner {
    Implicit(offset, ty) => [(offset, ty)]
    Explicit(types) => types
  }
}

///|
pub impl Eq for RecGroup with fn equal(self, other) {
  let n = self.len()
  if n != other.len() {
    return false
  }
  for i in 0..<n {
    if self.get(i) != other.get(i) {
      return false
    }
  }
  true
}

///|
pub impl Hash for RecGroup with fn hash_combine(self, hasher) {
  let n = self.len()
  hasher.combine_int(n)
  for i in 0..<n {
    hasher.combine(self.get(i))
  }
}

///|
/// Represents a subtype of possible other types in a WebAssembly module.
pub(all) struct SubType {
  /// Is the subtype final.
  is_final : Bool
  /// The list of supertype indexes. As of GC MVP, there can be at most one
  /// supertype.
  mut supertype_idx : PackedIndex?
  /// The composite type of the subtype.
  composite_type : CompositeType
} derive(Eq, Hash, Debug)

///|
pub impl Show for SubType with fn output(self, logger) {
  if self.is_final && self.supertype_idx is None {
    self.composite_type.output(logger)
  } else {
    logger.write_string("(sub ")
    if self.is_final {
      logger.write_string("final ")
    }
    if self.supertype_idx is Some(idx) {
      logger.write_string("\{idx} ")
    }
    self.composite_type.output(logger)
    logger.write_string(")")
  }
}

///|
/// Unwrap an `ArrayType` or panic.
pub fn SubType::unwrap_array(self : SubType) -> ArrayType {
  self.composite_type.unwrap_array()
}

///|
/// Construct a function `SubType`.
pub fn SubType::func(signature : FuncType, shared : Bool) -> SubType {
  {
    is_final: true,
    supertype_idx: None,
    composite_type: { inner: Func(signature), shared, },
  }
}

///|
/// Unwrap an `FuncType` or panic.
pub fn SubType::unwrap_func(self : SubType) -> FuncType {
  self.composite_type.unwrap_func()
}

///|
/// Unwrap an `StructType` or panic.
pub fn SubType::unwrap_struct(self : SubType) -> StructType {
  self.composite_type.unwrap_struct()
}

///|
/// Unwrap an `ContType` or panic.
pub fn SubType::unwrap_cont(self : SubType) -> ContType {
  self.composite_type.unwrap_cont()
}

///|
/// Maps any `UnpackedIndex` via the specified closure.
fn SubType::remap_indices(
  self : SubType,
  f : (PackedIndex) -> PackedIndex raise BinaryReaderError,
) -> Unit raise BinaryReaderError {
  if self.supertype_idx is Some(idx) {
    self.supertype_idx = Some(f(idx))
  }
  match self.composite_type.inner {
    Func(ty) =>
      for i in 0..<ty.params_results.length() {
        ty.params_results[i] = ty.params_results[i].remap_indices(f)
      }
    Array(ty) => ty.0.remap_indices(f)
    Struct(ty) =>
      for field in ty.fields {
        field.remap_indices(f)
      }
    Cont(ty) => ty.remap_indices(f)
  }
}

///|
/// Represents a composite type in a WebAssembly module.
pub(all) struct CompositeType {
  /// The type defined inside the composite type.
  inner : CompositeInnerType
  /// Is the composite type shared? This is part of the
  /// shared-everything-threads proposal.
  shared : Bool
} derive(Eq, Hash, Debug)

///|
/// A [`CompositeType`] can contain one of these types.
pub(all) enum CompositeInnerType {
  /// The type is for a function.
  Func(FuncType)
  /// The type is for an array.
  Array(ArrayType)
  /// The type is for a struct.
  Struct(StructType)
  /// The type is for a continuation.
  Cont(ContType)
} derive(Eq, Hash, Debug)

///|
pub impl Show for CompositeType with fn output(self, logger) {
  if self.shared {
    logger.write_string("(shared ")
  }
  match self.inner {
    Array(_) => logger.write_string("(array ...)")
    Func(_) => logger.write_string("(func ...)")
    Struct(_) => logger.write_string("(struct ...)")
    Cont(_) => logger.write_string("(cont ...)")
  }
  if self.shared {
    logger.write_string(")")
  }
}

///|
/// Unwrap a `FuncType` or panic.
pub fn CompositeType::unwrap_func(self : CompositeType) -> FuncType {
  match self.inner {
    Func(f) => f
    _ => abort("not a func")
  }
}

///|
/// Unwrap a `ArrayType` or panic.
pub fn CompositeType::unwrap_array(self : CompositeType) -> ArrayType {
  match self.inner {
    Array(a) => a
    _ => abort("not a array")
  }
}

///|
/// Unwrap a `StructType` or panic.
pub fn CompositeType::unwrap_struct(self : CompositeType) -> StructType {
  match self.inner {
    Struct(s) => s
    _ => abort("not a struct")
  }
}

///|
/// Unwrap a `ContType` or panic.
pub fn CompositeType::unwrap_cont(self : CompositeType) -> ContType {
  match self.inner {
    Cont(c) => c
    _ => abort("not a cont")
  }
}

///|
/// Represents a type of a function in a WebAssembly module.
pub struct FuncType {
  /// The combined parameters and result types.
  priv params_results : Array[ValType]
  /// The number of parameter types.
  priv len_params : Int
} derive(Eq, Hash, Debug)

///|
pub impl Show for FuncType with fn output(self, logger) {
  logger.write_string("FuncType { params: [")
  for i, ty in self.params() {
    if i > 0 {
      logger.write_string(", ")
    }
    ty.output(logger)
  }
  logger.write_string("], results: [")
  for i, ty in self.results() {
    if i > 0 {
      logger.write_string(", ")
    }
    ty.output(logger)
  }
  logger.write_string("] }")
}

///|
/// Creates a new [`FuncType`] from the given `params` and `results`.
pub fn FuncType::new(
  params : Array[ValType],
  results : Array[ValType],
) -> FuncType {
  let buffer = params.copy()
  let len_params = buffer.length()
  buffer.push_iter(results.iter())
  { params_results: buffer, len_params, }
}

///|
fn FuncType::from_raw_parts(
  params_results : Array[ValType],
  len_params : Int,
) -> FuncType {
  if !(len_params <= params_results.length()) {
    abort("assertion failed: len_params <= params_results.length()")
  }
  { params_results, len_params, }
}

///|
/// Returns a shared slice to the parameter types of the [`FuncType`].
pub fn FuncType::params(self : FuncType) -> ArrayView[ValType] {
  self.params_results[:self.len_params]
}

///|
/// Returns a shared slice to the result types of the [`FuncType`].
pub fn FuncType::results(self : FuncType) -> ArrayView[ValType] {
  self.params_results[self.len_params:]
}

///|
/// Represents a type of an array in a WebAssembly module.
pub(all) struct ArrayType(FieldType) derive(Eq, Hash, Debug)

///|
/// Represents a field type of an array or a struct.
pub(all) struct FieldType {
  /// Array element type.
  mut element_type : StorageType
  /// Are elements mutable.
  mutable : Bool
} derive(Eq, Hash, Debug)

///|
fn FieldType::remap_indices(
  self : FieldType,
  f : (PackedIndex) -> PackedIndex raise BinaryReaderError,
) -> Unit raise BinaryReaderError {
  match self.element_type {
    I8 | I16 => ()
    Val(ty) => self.element_type = Val(ty.remap_indices(f))
  }
}

///|
/// Represents storage types introduced in the GC spec for array and struct
/// fields.
pub(all) enum StorageType {
  /// The storage type is i8.
  I8
  /// The storage type is i16.
  I16
  /// The storage type is a value type.
  Val(ValType)
} derive(Eq, Hash, Debug)

///|
pub impl Show for StorageType with fn output(self, logger) {
  match self {
    I8 => logger.write_string("i8")
    I16 => logger.write_string("i16")
    Val(v) => v.output(logger)
  }
}

///|
/// Is this a packed storage type, i.e. one that must be sign- or
/// zero-extended when converted to a `ValType`?
pub fn StorageType::is_packed(self : StorageType) -> Bool {
  self is (I8 | I16)
}

///|
/// Unpack this storage type into the valtype that it is represented as on
/// the operand stack.
pub fn StorageType::unpack(self : StorageType) -> ValType {
  match self {
    Val(ty) => ty
    I8 | I16 => I32
  }
}

///|
/// Represents a type of a struct in a WebAssembly module.
pub(all) struct StructType {
  /// Struct fields.
  fields : Array[FieldType]
} derive(Eq, Hash, Debug)

///|
/// Represents a type of a continuation in a WebAssembly module.
pub(all) struct ContType {
  mut idx : PackedIndex
} derive(Eq, Hash, Debug)

///|
fn ContType::remap_indices(
  self : ContType,
  map : (PackedIndex) -> PackedIndex raise BinaryReaderError,
) -> Unit raise BinaryReaderError {
  self.idx = map(self.idx)
}

///|
/// Represents the types of values in a WebAssembly module.
pub(all) enum ValType {
  /// The value type is i32.
  I32
  /// The value type is i64.
  I64
  /// The value type is f32.
  F32
  /// The value type is f64.
  F64
  /// The value type is v128.
  V128
  /// The value type is a reference.
  Ref(RefType)
} derive(Eq, Hash, Debug)

///|
pub impl Show for ValType with fn output(self, logger) {
  match self {
    I32 => logger.write_string("i32")
    I64 => logger.write_string("i64")
    F32 => logger.write_string("f32")
    F64 => logger.write_string("f64")
    V128 => logger.write_string("v128")
    Ref(r) => r.output(logger)
  }
}

///|
/// Alias for the wasm `funcref` type.
pub let valtype_funcref : ValType = Ref(reftype_funcref)

///|
/// Alias for the wasm `externref` type.
pub let valtype_externref : ValType = Ref(reftype_externref)

///|
/// Alias for the wasm `exnref` type.
pub let valtype_exnref : ValType = Ref(reftype_exnref)

///|
/// Alias for the wasm `contref` type.
pub let valtype_contref : ValType = Ref(reftype_contref)

///|
/// Returns whether this value type is a "reference type".
///
/// Only reference types are allowed in tables, for example, and with some
/// instructions. Current reference types include `funcref` and `externref`.
pub fn ValType::is_reference_type(self : ValType) -> Bool {
  self is Ref(_)
}

///|
/// Get the underlying reference type, if this value type is a reference
/// type.
pub fn ValType::as_reference_type(self : ValType) -> RefType? {
  match self {
    Ref(r) => Some(r)
    I32 | I64 | F32 | F64 | V128 => None
  }
}

///|
/// Whether the type is defaultable, i.e. it is not a non-nullable reference
/// type.
pub fn ValType::is_defaultable(self : ValType) -> Bool {
  match self {
    I32 | I64 | F32 | F64 | V128 => true
    Ref(rt) => rt.is_nullable()
  }
}

///|
fn ValType::remap_indices(
  self : ValType,
  map : (PackedIndex) -> PackedIndex raise BinaryReaderError,
) -> ValType raise BinaryReaderError {
  match self {
    Ref(r) =>
      if r.type_index() is Some(idx) {
        let idx = map(idx)
        Ref(RefType::concrete(r.is_nullable(), idx))
      } else {
        self
      }
    I32 | I64 | F32 | F64 | V128 => self
  }
}

///|
/// A reference type.
///
/// The reference types proposal first introduced `externref` and
/// `funcref`.
///
/// The function references proposal introduced typed function
/// references.
///
/// The GC proposal introduces heap types: any, eq, i31, struct, array,
/// nofunc, noextern, none.
//
// RefType is a bit-packed enum that fits in a `u24` aka `[u8; 3]`. Note that
// its content is opaque (and subject to change), but its API is stable.
//
// It has the following internal structure:
//
// ```
// [nullable:u1 concrete==1:u1 index:u22]
// [nullable:u1 concrete==0:u1 shared:u1 abstype:u4 (unused):u17]
// ```
//
// Where
//
// - `nullable` determines nullability of the ref,
//
// - `concrete` determines if the ref is of a dynamically defined type with an
//   index (encoded in a following bit-packing section) or of a known fixed
//   type,
//
// - `index` is the type index,
//
// - `shared` determines if the ref is shared, but only if it is not concrete in
//   which case we would need to examine the type at the concrete index,
//
// - `abstype` is an enumeration of abstract types:
//
//   ```
//   1111 = any
//
//   1101 = eq
//   1000 = i31
//   1001 = struct
//   1100 = array
//
//   0101 = func
//   0100 = nofunc
//
//   0011 = extern
//   0010 = noextern
//
//   0111 = cont
//   0110 = nocont
//
//   0001 = exn
//
//   0000 = none
//   ```
pub(all) struct RefType(UInt) derive(Eq, Hash, Debug)

///|
pub impl Show for RefType with fn output(self, logger) {
  let heap_type = self.heap_type()
  match heap_type {
    // All abstract types follow the same general pattern.
    Abstract(shared~, ty~) => {
      let nullable = self.is_nullable()
      let name = ty.as_str(nullable)
      match (nullable, shared) {
        // Print the shortened form if nullable; i.e., `*ref`.
        (true, true) => logger.write_string("(shared \{name}ref)")
        (true, false) => logger.write_string("\{name}ref")
        // Print the long form otherwise; i.e., `(ref *)`.
        (false, true) => logger.write_string("(ref (shared \{name}))")
        (false, false) => logger.write_string("(ref \{name})")
      }
    }
    // Handle concrete types separately; they always use the long form
    // and don't show `shared`-ness.
    Concrete(index) =>
      if self.is_nullable() {
        logger.write_string("(ref null \{index})")
      } else {
        logger.write_string("(ref \{index})")
      }
  }
}

// These bits are valid for all `RefType`s.

///|
let reftype_nullable_bit : UInt = 1U << 23

///|
let reftype_concrete_bit : UInt = 1U << 22

// The `abstype` field is valid only when `concrete == 0`.

///|
let reftype_shared_bit : UInt = 1U << 21

///|
let reftype_abstype_mask : UInt = 0b1111U << 17

///|
let reftype_any_abstype : UInt = 0b1111U << 17

///|
let reftype_eq_abstype : UInt = 0b1101U << 17

///|
let reftype_i31_abstype : UInt = 0b1000U << 17

///|
let reftype_struct_abstype : UInt = 0b1001U << 17

///|
let reftype_array_abstype : UInt = 0b1100U << 17

///|
let reftype_func_abstype : UInt = 0b0101U << 17

///|
let reftype_nofunc_abstype : UInt = 0b0100U << 17

///|
let reftype_extern_abstype : UInt = 0b0011U << 17

///|
let reftype_noextern_abstype : UInt = 0b0010U << 17

///|
let reftype_exn_abstype : UInt = 0b0001U << 17

///|
let reftype_noexn_abstype : UInt = 0b1110U << 17

///|
let reftype_none_abstype : UInt = 0b0000U << 17

///|
let reftype_cont_abstype : UInt = 0b0111U << 17

///|
let reftype_nocont_abstype : UInt = 0b0110U << 17

///|
// The `index` is valid only when `concrete == 1`.
let reftype_index_mask : UInt = (1U << 22) - 1

///|
/// A nullable untyped function reference aka `(ref null func)` aka
/// `funcref` aka `anyfunc`.
pub let reftype_funcref : RefType = RefType(
  reftype_func_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to an extern object aka `(ref null extern)` aka
/// `externref`.
pub let reftype_externref : RefType = RefType(
  reftype_extern_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to any object aka `(ref null any)` aka `anyref`.
pub let reftype_anyref : RefType = RefType(
  reftype_any_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to no object aka `(ref null none)` aka `nullref`.
pub let reftype_nullref : RefType = RefType(
  reftype_none_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to a noextern object aka `(ref null noextern)` aka
/// `nullexternref`.
pub let reftype_nullexternref : RefType = RefType(
  reftype_noextern_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to a nofunc object aka `(ref null nofunc)` aka
/// `nullfuncref`.
pub let reftype_nullfuncref : RefType = RefType(
  reftype_nofunc_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to an eq object aka `(ref null eq)` aka `eqref`.
pub let reftype_eqref : RefType = RefType(
  reftype_eq_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to a struct aka `(ref null struct)` aka
/// `structref`.
pub let reftype_structref : RefType = RefType(
  reftype_struct_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to an array aka `(ref null array)` aka `arrayref`.
pub let reftype_arrayref : RefType = RefType(
  reftype_array_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to an i31 object aka `(ref null i31)` aka `i31ref`.
pub let reftype_i31ref : RefType = RefType(
  reftype_i31_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to an exception object aka `(ref null exn)` aka
/// `exnref`.
pub let reftype_exnref : RefType = RefType(
  reftype_exn_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to a noexn object aka `(ref null noexn)` aka
/// `nullexnref`.
pub let reftype_nullexnref : RefType = RefType(
  reftype_noexn_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to a cont object aka `(ref null cont)` aka
/// `contref`.
pub let reftype_contref : RefType = RefType(
  reftype_cont_abstype | reftype_nullable_bit,
)

///|
/// A nullable reference to a nocont object aka `(ref null nocont)` aka
/// `nullcontref`.
pub let reftype_nullcontref : RefType = RefType(
  reftype_nocont_abstype | reftype_nullable_bit,
)

///|
/// A non-nullable untyped function reference aka `(ref func)`.
pub let reftype_func : RefType = RefType(reftype_func_abstype)

///|
/// A non-nullable reference to an extern object aka `(ref extern)`.
pub let reftype_extern : RefType = RefType(reftype_extern_abstype)

///|
/// A non-nullable reference to any object aka `(ref any)`.
pub let reftype_any : RefType = RefType(reftype_any_abstype)

///|
/// A non-nullable reference to no object aka `(ref none)`.
pub let reftype_none : RefType = RefType(reftype_none_abstype)

///|
/// A non-nullable reference to a noextern object aka `(ref noextern)`.
pub let reftype_noextern : RefType = RefType(reftype_noextern_abstype)

///|
/// A non-nullable reference to a nofunc object aka `(ref nofunc)`.
pub let reftype_nofunc : RefType = RefType(reftype_nofunc_abstype)

///|
/// A non-nullable reference to an eq object aka `(ref eq)`.
pub let reftype_eq : RefType = RefType(reftype_eq_abstype)

///|
/// A non-nullable reference to a struct aka `(ref struct)`.
pub let reftype_struct : RefType = RefType(reftype_struct_abstype)

///|
/// A non-nullable reference to an array aka `(ref array)`.
pub let reftype_array : RefType = RefType(reftype_array_abstype)

///|
/// A non-nullable reference to an i31 object aka `(ref i31)`.
pub let reftype_i31 : RefType = RefType(reftype_i31_abstype)

///|
/// A non-nullable reference to an exn object aka `(ref exn)`.
pub let reftype_exn : RefType = RefType(reftype_exn_abstype)

///|
/// A non-nullable reference to a noexn object aka `(ref noexn)`.
pub let reftype_noexn : RefType = RefType(reftype_noexn_abstype)

///|
/// A non-nullable reference to a cont object aka `(ref cont)`.
pub let reftype_cont : RefType = RefType(reftype_cont_abstype)

///|
/// A non-nullable reference to a nocont object aka `(ref nocont)`.
pub let reftype_nocont : RefType = RefType(reftype_nocont_abstype)

///|
// Only used by a `debug_assert!` upstream (readers/core/types.rs:1204).
#warnings("-unused_value")
fn RefType::can_represent_type_index(index : UInt) -> Bool {
  (index & reftype_index_mask) == index
}

///|
fn RefType::as_u32(self : RefType) -> UInt {
  self.0
}

///|
fn RefType::from_u32(x : UInt) -> RefType {
  RefType(x)
}

///|
/// Create a reference to a concrete Wasm-defined type at the given
/// index.
///
/// Returns `None` when the type index is beyond this crate's
/// implementation limits and therefore is not representable.
pub fn RefType::concrete(nullable : Bool, index : PackedIndex) -> RefType {
  let index : UInt = PackedIndex::to_u32(index)
  let nullable32 = if nullable { reftype_nullable_bit } else { 0 }
  RefType::from_u32(nullable32 | reftype_concrete_bit | index)
}

///|
/// Create a new `RefType`.
///
/// Returns `None` when the heap type's type index (if any) is beyond this
/// crate's implementation limits and therefore is not representable.
pub fn RefType::new(nullable : Bool, heap_type : HeapType) -> RefType? {
  let base32 = if nullable { reftype_nullable_bit } else { 0 }
  match heap_type {
    Concrete(index) =>
      match index.pack() {
        Some(p) => Some(RefType::concrete(nullable, p))
        None => None
      }
    Abstract(shared~, ty~) => {
      let base32 = base32 | (if shared { reftype_shared_bit } else { 0 })
      let abstype = match ty {
        Func => reftype_func_abstype
        Extern => reftype_extern_abstype
        Any => reftype_any_abstype
        None_ => reftype_none_abstype
        NoExtern => reftype_noextern_abstype
        NoFunc => reftype_nofunc_abstype
        Eq => reftype_eq_abstype
        Struct => reftype_struct_abstype
        Array => reftype_array_abstype
        I31 => reftype_i31_abstype
        Exn => reftype_exn_abstype
        NoExn => reftype_noexn_abstype
        Cont => reftype_cont_abstype
        NoCont => reftype_nocont_abstype
      }
      Some(RefType::from_u32(base32 | abstype))
    }
  }
}

///|
/// Compute the [type difference] between the two given ref types.
///
/// [type difference]: https://webassembly.github.io/gc/core/valid/conventions.html#aux-reftypediff
pub fn RefType::difference(a : RefType, b : RefType) -> RefType {
  RefType::new(
    if b.is_nullable() {
      false
    } else {
      a.is_nullable()
    },
    a.heap_type(),
  ).unwrap()
}

///|
/// Is this a reference to an concrete type?
pub fn RefType::is_concrete_type_ref(self : RefType) -> Bool {
  (self.as_u32() & reftype_concrete_bit) != 0
}

///|
/// If this is a reference to a concrete Wasm-defined type, get its
/// type index.
pub fn RefType::type_index(self : RefType) -> PackedIndex? {
  if self.is_concrete_type_ref() {
    let index = self.as_u32() & reftype_index_mask
    Some(PackedIndex::unchecked_from_u32(index))
  } else {
    None
  }
}

///|
fn RefType::abstype(self : RefType) -> UInt {
  self.as_u32() & reftype_abstype_mask
}

///|
/// Is this the abstract untyped function reference type aka `(ref
/// null func)` aka `funcref` aka `anyfunc`?
pub fn RefType::is_func_ref(self : RefType) -> Bool {
  !self.is_concrete_type_ref() && self.abstype() == reftype_func_abstype
}

///|
/// Is this the abstract external reference type aka `(ref null
/// extern)` aka `externref`?
pub fn RefType::is_extern_ref(self : RefType) -> Bool {
  !self.is_concrete_type_ref() && self.abstype() == reftype_extern_abstype
}

///|
/// Is this the abstract untyped array reference type aka `(ref null
/// array)` aka `arrayref`?
pub fn RefType::is_array_ref(self : RefType) -> Bool {
  !self.is_concrete_type_ref() && self.abstype() == reftype_array_abstype
}

///|
/// Is this the abstract untyped struct reference type aka `(ref null
/// struct)` aka `structref`?
pub fn RefType::is_struct_ref(self : RefType) -> Bool {
  !self.is_concrete_type_ref() && self.abstype() == reftype_struct_abstype
}

///|
/// Is this the abstract untyped continuation reference type aka `(ref
/// null cont)` aka `contref`?
pub fn RefType::is_cont_ref(self : RefType) -> Bool {
  !self.is_concrete_type_ref() && self.abstype() == reftype_cont_abstype
}

///|
/// Is this ref type nullable?
pub fn RefType::is_nullable(self : RefType) -> Bool {
  (self.as_u32() & reftype_nullable_bit) != 0
}

///|
/// Get the non-nullable version of this ref type.
pub fn RefType::as_non_null(self : RefType) -> RefType {
  RefType::from_u32(self.as_u32() & reftype_nullable_bit.lnot())
}

///|
/// Get the nullable version of this ref type.
pub fn RefType::nullable(self : RefType) -> RefType {
  RefType::from_u32(self.as_u32() | reftype_nullable_bit)
}

///|
/// Get the shared version of this ref type as long as it is abstract.
pub fn RefType::shared(self : RefType) -> RefType? {
  if self.is_concrete_type_ref() {
    None
  } else {
    Some(RefType::from_u32(self.as_u32() | reftype_shared_bit))
  }
}

///|
/// Get the heap type that this is a reference to.
pub fn RefType::heap_type(self : RefType) -> HeapType {
  let s = self.as_u32()
  if self.is_concrete_type_ref() {
    Concrete(self.type_index().unwrap().unpack())
  } else {
    let shared = (s & reftype_shared_bit) != 0
    let abstype = s & reftype_abstype_mask
    let ty : AbstractHeapType = if abstype == reftype_func_abstype {
      Func
    } else if abstype == reftype_extern_abstype {
      Extern
    } else if abstype == reftype_any_abstype {
      Any
    } else if abstype == reftype_none_abstype {
      None_
    } else if abstype == reftype_noextern_abstype {
      NoExtern
    } else if abstype == reftype_nofunc_abstype {
      NoFunc
    } else if abstype == reftype_eq_abstype {
      Eq
    } else if abstype == reftype_struct_abstype {
      Struct
    } else if abstype == reftype_array_abstype {
      Array
    } else if abstype == reftype_i31_abstype {
      I31
    } else if abstype == reftype_exn_abstype {
      Exn
    } else if abstype == reftype_noexn_abstype {
      NoExn
    } else if abstype == reftype_cont_abstype {
      Cont
    } else if abstype == reftype_nocont_abstype {
      NoCont
    } else {
      abort("unreachable")
    }
    Abstract(shared~, ty~)
  }
}

///|
// Note that this is similar to `Display for RefType` except that it has
// the indexes stubbed out.
fn RefType::wat(self : RefType) -> String {
  let nullable = self.is_nullable()
  match self.heap_type() {
    Abstract(shared~, ty~) => {
      let name = ty.as_str(nullable)
      match (shared, nullable) {
        // Shared and nullable.
        (true, true) => "(shared \{name}ref)"
        // Unshared but nullable.
        (false, true) => "\{name}ref"
        // Shared but not nullable.
        (true, false) => "(ref (shared \{name}))"
        // Neither shared nor nullable.
        (false, false) => "(ref \{name})"
      }
    }
    Concrete(_) => if nullable { "(ref null $type)" } else { "(ref $type)" }
  }
}

///|
/// A heap type.
pub(all) enum HeapType {
  /// An abstract heap type; e.g., `anyref`.
  Abstract(shared~ : Bool, ty~ : AbstractHeapType)
  /// A concrete, user-defined type.
  ///
  /// Introduced in the function-references proposal.
  Concrete(UnpackedIndex)
} derive(Eq, Hash, Debug)

///|
/// Alias for an unshared `func` heap type.
pub let heaptype_func : HeapType = Abstract(shared=false, ty=Func)

///|
/// Alias for an unshared `extern` heap type.
pub let heaptype_extern : HeapType = Abstract(shared=false, ty=Extern)

///|
/// An abstract heap type.
pub(all) enum AbstractHeapType {
  /// The abstract, untyped (any) function.
  ///
  /// Introduced in the references-types proposal.
  Func
  /// The abstract, external heap type.
  ///
  /// Introduced in the references-types proposal.
  Extern
  /// The abstract `any` heap type.
  ///
  /// The common supertype (a.k.a. top) of all internal types.
  ///
  /// Introduced in the GC proposal.
  Any
  /// The abstract `none` heap type.
  ///
  /// The common subtype (a.k.a. bottom) of all internal types.
  ///
  /// Introduced in the GC proposal.
  ///
  /// (Upstream `None`; renamed since `None` is `Option`'s constructor.)
  None_
  /// The abstract `noextern` heap type.
  ///
  /// The common subtype (a.k.a. bottom) of all external types.
  ///
  /// Introduced in the GC proposal.
  NoExtern
  /// The abstract `nofunc` heap type.
  ///
  /// The common subtype (a.k.a. bottom) of all function types.
  ///
  /// Introduced in the GC proposal.
  NoFunc
  /// The abstract `eq` heap type.
  ///
  /// The common supertype of all referenceable types on which comparison
  /// (ref.eq) is allowed.
  ///
  /// Introduced in the GC proposal.
  Eq
  /// The abstract `struct` heap type.
  ///
  /// The common supertype of all struct types.
  ///
  /// Introduced in the GC proposal.
  Struct
  /// The abstract `array` heap type.
  ///
  /// The common supertype of all array types.
  ///
  /// Introduced in the GC proposal.
  Array
  /// The unboxed `i31` heap type.
  ///
  /// Introduced in the GC proposal.
  I31
  /// The abstraction `exception` heap type.
  ///
  /// Introduced in the exception-handling proposal.
  Exn
  /// The abstract `noexn` heap type.
  ///
  /// The common subtype (a.k.a. bottom) of all exception types.
  ///
  /// Introduced in the exception-handling proposal.
  NoExn
  /// The abstract `cont` heap type.
  ///
  /// The common supertype (a.k.a. top) of all continuation types.
  ///
  /// Introduced in the stack-switching proposal.
  Cont
  /// The abstract `nocont` heap type.
  ///
  /// The common subtype (a.k.a. bottom) of all continuation types.
  ///
  /// Introduced in the stack-switching proposal.
  NoCont
} derive(Eq, Hash, Debug)

///|
fn AbstractHeapType::as_str(self : AbstractHeapType, nullable : Bool) -> String {
  match (nullable, self) {
    (_, Any) => "any"
    (true, None_) => "null"
    (false, None_) => "none"
    (true, NoExtern) => "nullextern"
    (false, NoExtern) => "noextern"
    (true, NoFunc) => "nullfunc"
    (false, NoFunc) => "nofunc"
    (_, Eq) => "eq"
    (_, Struct) => "struct"
    (_, Array) => "array"
    (_, I31) => "i31"
    (_, Extern) => "extern"
    (_, Func) => "func"
    (_, Exn) => "exn"
    (true, NoExn) => "nullexn"
    (false, NoExn) => "noexn"
    (_, Cont) => "cont"
    (true, NoCont) => "nullcont"
    (false, NoCont) => "nocont"
  }
}

///|
fn AbstractHeapType::is_subtype_of(
  self : AbstractHeapType,
  other : AbstractHeapType,
) -> Bool {
  match (self, other) {
    (a, b) if a == b => true
    (Eq | I31 | Struct | Array | None_, Any) => true
    (I31 | Struct | Array | None_, Eq) => true
    (NoExtern, Extern) => true
    (NoFunc, Func) => true
    (None_, I31 | Array | Struct) => true
    (NoExn, Exn) => true
    (NoCont, Cont) => true
    // Nothing else matches. (Avoid full wildcard matches so
    // that adding/modifying variants is easier in the
    // future.)
    (
      Func
      | Extern
      | Exn
      | Any
      | Eq
      | Array
      | I31
      | Struct
      | Cont
      | None_
      | NoFunc
      | NoExtern
      | NoExn
      | NoCont,
      _,
    ) => false
  }
}

///|
pub impl FromReader for StorageType with fn from_reader(reader) {
  // NB: See `FromReader<'a> for ValType` for a table of how this
  // interacts with other value encodings.
  match reader.peek() {
    0x78 => {
      reader.read_u8() |> ignore
      I8
    }
    0x77 => {
      reader.read_u8() |> ignore
      I16
    }
    _ => Val(ValType::from_reader(reader))
  }
}

///|
pub impl FromReader for ValType with fn from_reader(reader) {
  // Decoding value types is sort of subtle because the space of what's
  // being decoded here is actually spread out across an number of
  // locations. This comment here is intended to serve as a bit of a
  // reference to what's being decoded here and how it interacts with
  // other locations.
  //
  // Note that all value types are encoded as canonical-form negative
  // numbers in the sleb128 encoding scheme. Currently in the wasm spec
  // sleb128 isn't actually used but it looks to be modelled to allow it
  // one day. In the meantime the current values used are:
  //
  // | sleb128 | decimal | type         | notes                        |
  // |---------|---------|--------------|------------------------------|
  // | 0x7F    | -1      | i32          |                              |
  // | 0x7E    | -2      | i64          |                              |
  // | 0x7D    | -3      | f32          |                              |
  // | 0x7C    | -4      | f64          |                              |
  // | 0x7B    | -5      | v128         | simd proposal                |
  // | 0x78    | -8      | i8           | gc proposal, in `FieldType`  |
  // | 0x77    | -9      | i16          | gc proposal, in `FieldType`  |
  // | 0x75    | -11     | nocont       | stack switching proposal     |
  // | 0x74    | -12     | noexn        | gc + exceptions proposal     |
  // | 0x73    | -13     | nofunc       | gc proposal                  |
  // | 0x72    | -14     | noextern     | gc proposal                  |
  // | 0x71    | -15     | nullref      | gc proposal                  |
  // | 0x70    | -16     | func         | reference types proposal     |
  // | 0x6F    | -17     | extern       | reference types proposal     |
  // | 0x6E    | -18     | any          | gc proposal                  |
  // | 0x6D    | -19     | eq           | gc proposal                  |
  // | 0x6C    | -20     | i31          | gc proposal                  |
  // | 0x6B    | -21     | struct       | gc proposal                  |
  // | 0x6A    | -22     | array        | gc proposal                  |
  // | 0x69    | -23     | exnref       | gc + exceptions proposal     |
  // | 0x68    | -24     | contref      | stack switching proposal     |
  // | 0x65    | -27     | shared $t    | shared-everything proposal   |
  // | 0x64    | -28     | ref $t       | gc proposal, prefix byte     |
  // | 0x63    | -29     | ref null $t  | gc proposal, prefix byte     |
  // | 0x60    | -32     | func $t      | prefix byte                  |
  // | 0x5f    | -33     | struct $t    | gc proposal, prefix byte     |
  // | 0x5e    | -34     | array $t     | gc proposal, prefix byte     |
  // | 0x5d    | -35     | cont $t      | stack switching proposal     |
  // | 0x50    | -48     | sub $t       | gc proposal, prefix byte     |
  // | 0x4F    | -49     | sub final $t | gc proposal, prefix byte     |
  // | 0x4E    | -50     | rec $t       | gc proposal, prefix byte     |
  // | 0x40    | -64     | ε            | empty block type             |
  //
  // Note that not all of these encodings are parsed here, for example
  // 0x78 as the encoding for `i8` is parsed only in `FieldType`. The
  // parsing of `FieldType` will delegate here without actually consuming
  // anything though so the encoding 0x78 still must be disjoint and not
  // read here otherwise.
  match reader.peek() {
    0x7F => {
      reader.position += 1
      I32
    }
    0x7E => {
      reader.position += 1
      I64
    }
    0x7D => {
      reader.position += 1
      F32
    }
    0x7C => {
      reader.position += 1
      F64
    }
    0x7B => {
      reader.position += 1
      V128
    }
    _ => {
      // Reclassify errors as invalid value types here because
      // that's the "root" of what was being parsed rather than
      // reference types.
      let refty = RefType::from_reader(reader) catch {
        e =>
          if e.kind() is Invalid {
            raise e.with_message("invalid value type")
          } else {
            raise e
          }
      }
      Ref(refty)
    }
  }
}

///|
pub impl FromReader for RefType with fn from_reader(reader) {
  // NB: See `FromReader<'a> for ValType` for a table of how this
  // interacts with other value encodings.
  let pos = reader.original_position()
  match reader.peek() {
    0x63 | 0x64 => {
      let nullable = reader.read_u8() == 0x63
      match RefType::new(nullable, HeapType::from_reader(reader)) {
        Some(t) => t
        None => raise BinaryReaderError::new("type index too large", pos)
      }
    }
    _ => {
      // Reclassify errors as invalid reference types here because
      // that's the "root" of what was being parsed rather than
      // heap types.
      let hty = HeapType::from_reader(reader) catch {
        e =>
          if e.kind() is Invalid {
            raise e.with_message("malformed reference type")
          } else {
            raise e
          }
      }
      match RefType::new(true, hty) {
        Some(t) => t
        None => raise BinaryReaderError::new("type index too large", pos)
      }
    }
  }
}

///|
pub impl FromReader for HeapType with fn from_reader(reader) {
  // Unconditionally read a `s33` value. If it's positive then that means
  // it fits in a `u32` meaning that this is a valid concrete type index.
  // If it's negative, however, then it must be an abstract heap type due
  // to how non-concrete types are encoded (see `ValType` comments). In
  // that situation "rewind" the reader and go back to the original bytes
  // to parse them as an abstract heap type.
  let clone = reader.clone()
  let s33 = clone.read_var_s33()
  if s33 >= 0L && s33 <= 0xFFFF_FFFFL {
    // Be sure to update `reader` with the state after the s33 was
    // read.
    reader.assign(clone)
    let idx = match
      PackedIndex::from_module_index(s33.to_int().reinterpret_as_uint()) {
      Some(idx) => idx
      None =>
        raise BinaryReaderError::new(
          "type index greater than implementation limits",
          reader.original_position(),
        )
    }
    Concrete(idx.unpack())
  } else {
    match reader.peek() {
      0x65 => {
        reader.read_u8() |> ignore
        let ty = AbstractHeapType::from_reader(reader)
        Abstract(shared=true, ty~)
      }
      _ => {
        // Reclassify errors as "invalid heap type" here because
        // that's the "root" of what was being parsed rather than
        // abstract heap types.
        let ty = AbstractHeapType::from_reader(reader) catch {
          e =>
            if e.kind() is Invalid {
              raise e.with_message("invalid heap type")
            } else {
              raise e
            }
        }
        Abstract(shared=false, ty~)
      }
    }
  }
}

///|
pub impl FromReader for AbstractHeapType with fn from_reader(reader) {
  match reader.read_u8() {
    0x70 => Func
    0x6F => Extern
    0x6E => Any
    0x71 => None_
    0x72 => NoExtern
    0x73 => NoFunc
    0x6D => Eq
    0x6B => Struct
    0x6A => Array
    0x6C => I31
    0x69 => Exn
    0x74 => NoExn
    0x68 => Cont
    0x75 => NoCont
    _ =>
      raise BinaryReaderError::invalid(
        "invalid abstract heap type",
        reader.original_position() - 1,
      )
  }
}

///|
/// Represents a table's type.
pub(all) struct TableType {
  /// The table's element type.
  mut element_type : RefType
  /// Whether or not this is a 64-bit table.
  ///
  /// This is part of the memory64 proposal in WebAssembly.
  table64 : Bool
  /// Initial size of this table, in elements.
  ///
  /// For 32-bit tables (when `table64` is `false`) this is guaranteed to
  /// be at most `u32::MAX` for valid types.
  initial : UInt64
  /// Optional maximum size of the table, in elements.
  ///
  /// For 32-bit tables (when `table64` is `false`) this is guaranteed to
  /// be at most `u32::MAX` for valid types.
  maximum : UInt64?
  /// Whether this table is shared or not.
  ///
  /// This is included the shared-everything-threads proposal.
  shared : Bool
} derive(Eq, Debug)

///|
/// Gets the index type for the table.
pub fn TableType::index_type(self : TableType) -> ValType {
  if self.table64 {
    I64
  } else {
    I32
  }
}

///|
/// Represents a memory's type.
pub(all) struct MemoryType {
  /// Whether or not this is a 64-bit memory, using i64 as an index. If this
  /// is false it's a 32-bit memory using i32 as an index.
  ///
  /// This is part of the memory64 proposal in WebAssembly.
  memory64 : Bool
  /// Whether or not this is a "shared" memory, indicating that it should be
  /// send-able across threads and the `maximum` field is always present for
  /// valid types.
  ///
  /// This is part of the threads proposal in WebAssembly.
  shared : Bool
  /// Initial size of this memory, in wasm pages.
  ///
  /// For 32-bit memories (when `memory64` is `false`) this is guaranteed to
  /// be at most `u32::MAX` for valid types.
  initial : UInt64
  /// Optional maximum size of this memory, in wasm pages.
  ///
  /// For 32-bit memories (when `memory64` is `false`) this is guaranteed to
  /// be at most `u32::MAX` for valid types. This field is always present for
  /// valid wasm memories when `shared` is `true`.
  maximum : UInt64?
  /// The log base 2 of the memory's custom page size.
  ///
  /// Memory pages are, by default, 64KiB large (i.e. 2<sup>16</sup> or
  /// `65536`).
  ///
  /// [The custom-page-sizes proposal] allows changing it to other values.
  ///
  /// [The custom-page-sizes proposal]: https://github.com/WebAssembly/custom-page-sizes
  page_size_log2 : UInt?
} derive(Eq, Debug)

///|
/// Gets the index type for the memory.
pub fn MemoryType::index_type(self : MemoryType) -> ValType {
  if self.memory64 {
    I64
  } else {
    I32
  }
}

///|
/// Represents a global's type.
pub(all) struct GlobalType {
  /// The global's type.
  mut content_type : ValType
  /// Whether or not the global is mutable.
  mutable : Bool
  /// Whether or not the global is shared.
  shared : Bool
} derive(Eq, Debug)

///|
/// Represents a tag kind.
pub(all) enum TagKind {
  /// The tag is an exception type.
  Exception
} derive(Eq, Debug)

///|
/// A tag's type.
pub(all) struct TagType {
  /// The kind of tag
  kind : TagKind
  /// The function type this tag uses.
  func_type_idx : UInt
} derive(Eq, Debug)

///|
/// A reader for the type section of a WebAssembly module.
pub type TypeSectionReader = SectionLimited[RecGroup]

///|
/// Returns an iterator over this type section which will only yield
/// function types and any usage of GC types from the GC proposal will
/// be translated into an error.
pub fn TypeSectionReader::into_iter_err_on_gc_types(
  self : TypeSectionReader,
) -> Array[FuncType] raise BinaryReaderError {
  let iter = self.into_iter()
  let out = []
  while iter.next_with_offset() is Some((offset, group)) {
    let types = group.into_types()
    let ty = if types.length() == 1 {
      types[0]
    } else {
      bail(offset, "gc proposal not supported")
    }
    if !ty.is_final || ty.supertype_idx is Some(_) {
      bail(offset, "gc proposal not supported")
    }
    match ty.composite_type.inner {
      Func(f) => out.push(f)
      Array(_) | Struct(_) => bail(offset, "gc proposal not supported")
      Cont(_) => bail(offset, "stack switching proposal not supported")
    }
  }
  out
}

///|
pub impl FromReader for CompositeType with fn from_reader(reader) {
  read_composite_type(reader.read_u8(), reader)
}

///|
fn read_composite_type(
  opcode : Byte,
  reader : BinaryReader,
) -> CompositeType raise BinaryReaderError {
  // NB: See `FromReader<'a> for ValType` for a table of how this
  // interacts with other value encodings.
  let (shared, opcode) = if opcode == 0x65 {
    (true, reader.read_u8())
  } else {
    (false, opcode)
  }
  let inner : CompositeInnerType = match opcode {
    0x60 => Func(FuncType::from_reader(reader))
    0x5e => Array(ArrayType::from_reader(reader))
    0x5f => Struct(StructType::from_reader(reader))
    0x5d => Cont(ContType::from_reader(reader))
    x => reader.invalid_leading_byte(x, "type")
  }
  { shared, inner, }
}

///|
pub impl FromReader for RecGroup with fn from_reader(reader) {
  // NB: See `FromReader<'a> for ValType` for a table of how this
  // interacts with other value encodings.
  match reader.peek() {
    0x4e => {
      reader.read_u8() |> ignore
      let n = reader.read_iter(MAX_WASM_TYPES, "rec group types")
      let types = []
      let mut offset = reader.original_position()
      for _ in 0..<n {
        let ty = SubType::from_reader(reader)
        types.push((offset, ty))
        offset = reader.original_position()
      }
      RecGroup::explicit(types)
    }
    _ => {
      let offset = reader.original_position()
      RecGroup::implicit(offset, SubType::from_reader(reader))
    }
  }
}

///|
pub impl FromReader for SubType with fn from_reader(reader) {
  let pos = reader.original_position()
  // NB: See `FromReader<'a> for ValType` for a table of how this
  // interacts with other value encodings.
  match reader.read_u8() {
    0x4f | 0x50 as opcode => {
      let n = reader.read_iter(MAX_WASM_SUPERTYPES, "supertype idxs")
      let idxs = []
      for _ in 0..<n {
        idxs.push(reader.read_var_u32())
      }
      if idxs.length() > 1 {
        raise BinaryReaderError::new("multiple supertypes not supported", pos)
      }
      let supertype_idx = if idxs.length() > 0 {
        match PackedIndex::from_module_index(idxs[0]) {
          Some(idx) => Some(idx)
          None =>
            raise BinaryReaderError::new(
              "type index greater than implementation limits",
              reader.original_position(),
            )
        }
      } else {
        None
      }
      {
        is_final: opcode == 0x4f,
        supertype_idx,
        composite_type: read_composite_type(reader.read_u8(), reader),
      }
    }
    opcode =>
      {
        is_final: true,
        supertype_idx: None,
        composite_type: read_composite_type(opcode, reader),
      }
  }
}

///|
pub impl FromReader for FuncType with fn from_reader(reader) {
  let n = reader.read_iter(MAX_WASM_FUNCTION_PARAMS, "function params")
  let params_results = []
  for _ in 0..<n {
    params_results.push(ValType::from_reader(reader))
  }
  let len_params = params_results.length()
  let n = reader.read_iter(MAX_WASM_FUNCTION_RETURNS, "function returns")
  for _ in 0..<n {
    params_results.push(ValType::from_reader(reader))
  }
  FuncType::from_raw_parts(params_results, len_params)
}

///|
pub impl FromReader for FieldType with fn from_reader(reader) {
  let element_type = StorageType::from_reader(reader)
  let mutable = reader.read_u8()
  {
    element_type,
    mutable: match mutable {
      0 => false
      1 => true
      _ =>
        bail(
          reader.original_position(),
          "malformed mutability byte for field type",
        )
    },
  }
}

///|
pub impl FromReader for ArrayType with fn from_reader(reader) {
  ArrayType(FieldType::from_reader(reader))
}

///|
pub impl FromReader for StructType with fn from_reader(reader) {
  let n = reader.read_iter(MAX_WASM_STRUCT_FIELDS, "struct fields")
  let fields = []
  for _ in 0..<n {
    fields.push(FieldType::from_reader(reader))
  }
  { fields, }
}

///|
pub impl FromReader for ContType with fn from_reader(reader) {
  let s33 = reader.read_var_s33()
  let idx = if s33 >= 0L && s33 <= 0xFFFF_FFFFL {
    s33.to_int().reinterpret_as_uint()
  } else {
    bail(reader.original_position(), "invalid continuation type")
  }
  let idx = match PackedIndex::from_module_index(idx) {
    Some(idx) => idx
    None =>
      raise BinaryReaderError::new(
        "type index greater than implementation limits",
        reader.original_position(),
      )
  }
  { idx, }
}
