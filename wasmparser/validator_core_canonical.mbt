// Port of wasmparser 0.228.0 `src/validator/core/canonical.rs`:
// canonicalization of types.
//
// The unit of canonicalization is a recursion group. Having "unnecessary"
// types in a recursion group can "break" canonicalization of other types
// within that same recursion group, as can reordering types within a recursion
// group.
//
// It is an invariant that all types defined before the recursion group we are
// currently canonicalizing have already been canonicalized themselves.
//
// Canonicalizing a recursion group then proceeds as follows:
//
// * First we walk each of its `SubType` elements and put their type references
//   (i.e. their `PackedIndex`es) into canonical form. Canonicalizing a
//   `PackedIndex` means switching it from indexing into the Wasm module's
//   types space into either
//
//   1. Referencing an already-canonicalized type, for types outside of this
//      recursion group. Because inter-group type references can only go
//      towards types defined before this recursion group, we know the type is
//      already canonicalized and we have a `CoreTypeId` for each of those
//      types. This updates the `PackedIndex` into a `CoreTypeId`.
//
//   2. Indexing into the current recursion group, for intra-group type
//      references.
//
//   Note that (2) has the effect of making the "same" structure of mutual type
//   recursion look identical across recursion groups.
//
// * Now that the recursion group's elements are in canonical form, we can
//   "simply" hash cons whole rec groups at a time.
//
// Upstream's `InternRecGroup` trait has a single implementor in core wasm
// (`Module`), so its provided methods are `Module` methods here.

///|
fn Module::canonicalize_and_intern_rec_group(
  self : Module,
  features : WasmFeatures,
  types : TypeList,
  rec_group : RecGroup,
  offset : Int,
) -> Unit raise BinaryReaderError {
  if rec_group.is_explicit_rec_group() && !features.gc() {
    bail(offset, "rec group usage requires `gc` proposal to be enabled")
  }
  if features.needs_type_canonicalization() {
    TypeCanonicalizer::new(self, offset)
    ..with_features(features)
    .canonicalize_rec_group(rec_group)
  }
  let (is_new, rec_group_id) = types.intern_canonical_rec_group(
    features.needs_type_canonicalization(),
    rec_group,
  )
  let (start, end) = types.rec_group_range(rec_group_id)
  for i in start.index..<end.index {
    let id = CoreTypeId::from_index(i)
    self.add_type_id(id)
    if is_new {
      self.check_subtype(rec_group_id, id, features, types, offset)
    }
  }
}

///|
fn Module::check_subtype(
  self : Module,
  rec_group : RecGroupId,
  id : CoreTypeId,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  let ty = types.get_core(id)
  if !features.gc() && (!ty.is_final || ty.supertype_idx is Some(_)) {
    bail(offset, "gc proposal must be enabled to use subtypes")
  }
  self.check_composite_type(ty.composite_type, features, types, offset)
  let depth = if ty.supertype_idx is Some(supertype_index) {
    let sup_id = self.at_packed_index(types, rec_group, supertype_index, offset)
    if types.get_core(sup_id).is_final {
      bail(offset, "sub type cannot have a final super type")
    }
    if !types.matches(id, sup_id) {
      bail(offset, "sub type must match super type")
    }
    let depth = types.get_subtyping_depth(sup_id) + 1
    if depth > MAX_WASM_SUBTYPING_DEPTH {
      bail(
        offset,
        "sub type hierarchy too deep: found depth \{depth}, cannot exceed depth \{MAX_WASM_SUBTYPING_DEPTH}",
      )
    }
    depth
  } else {
    0
  }
  types.set_subtyping_depth(id, depth)
}

///|
fn Module::check_composite_type(
  _self : Module,
  ty : CompositeType,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  let check = (ty : ValType, shared : Bool) => {
    if features.check_value_type(ty) is Some(e) {
      raise BinaryReaderError::new(e, offset)
    }
    if shared && !types.valtype_is_shared(ty) {
      raise BinaryReaderError::new(
        "shared composite type must contain shared types", offset,
      )
      // The other cases are fine:
      // - both shared or unshared: good to go
      // - the func type is unshared, `ty` is shared: though
      //   odd, we _can_ in fact use shared values in
      //   unshared composite types (e.g., functions).
    }
  }
  if !features.shared_everything_threads() && ty.shared {
    raise BinaryReaderError::new(
      "shared composite types require the shared-everything-threads proposal", offset,
    )
  }
  match ty.inner {
    Func(t) => {
      for vt in t.params() {
        check(vt, ty.shared)
      }
      for vt in t.results() {
        check(vt, ty.shared)
      }
      if t.results().length() > 1 && !features.multi_value() {
        raise BinaryReaderError::new(
          "func type returns multiple values but the multi-value feature is not enabled",
          offset,
        )
      }
    }
    Array(t) => {
      if !features.gc() {
        bail(offset, "array indexed types not supported without the gc feature")
      }
      if !features.gc_types() {
        bail(offset, "cannot define array types when gc types are disabled")
      }
      match t.0.element_type {
        I8 | I16 => ()
        // Note: scalar types are always `shared`.
        Val(value_type) => check(value_type, ty.shared)
      }
    }
    Struct(t) => {
      if !features.gc() {
        bail(
          offset, "struct indexed types not supported without the gc feature",
        )
      }
      if !features.gc_types() {
        bail(offset, "cannot define struct types when gc types are disabled")
      }
      for ft in t.fields {
        match ft.element_type {
          I8 | I16 => ()
          // Note: scalar types are always `shared`.
          Val(value_type) => check(value_type, ty.shared)
        }
      }
    }
    Cont(t) => {
      if !features.stack_switching() {
        bail(
          offset, "cannot define continuation types when stack switching is disabled",
        )
      }
      if !features.gc_types() {
        bail(
          offset, "cannot define continuation types when gc types are disabled",
        )
      }
      // Check that the type index points to a valid function type.
      let id = t.idx.as_core_type_id().unwrap()
      match types.get_core(id).composite_type.inner {
        Func(_) => ()
        _ => bail(offset, "non-function type \{id.index}")
      }
    }
  }
}

///|
fn Module::at_packed_index(
  self : Module,
  types : TypeList,
  rec_group : RecGroupId,
  index : PackedIndex,
  offset : Int,
) -> CoreTypeId raise BinaryReaderError {
  match index.unpack() {
    Id(id) => id
    Module(idx) => self.type_id_at(idx, offset)
    RecGroup(idx) => types.rec_group_local_id(rec_group, idx, offset)
  }
}

///|
priv enum CanonicalizationMode {
  /// Standard canonicalization: turns module indices into either (1)
  /// `CoreTypeId`s for inter-group references or (2) rec-group-local indices
  /// for intra-group references.
  HashConsing
  /// Turns all type reference indices into `CoreTypeId`s, even from within
  /// the same rec group. Not useful for hash consing, but useful when
  /// exposing types to end users so they don't have to deal with
  /// rec-group-local indices.
  OnlyIds
} derive(Eq)

///|
priv struct TypeCanonicalizer {
  module_ : Module
  mut features : WasmFeatures?
  mut rec_group_start : UInt
  mut rec_group_len : UInt
  offset : Int
  mode : CanonicalizationMode
  within_rec_group : (CoreTypeId, CoreTypeId)?
}

///|
fn TypeCanonicalizer::new(module_ : Module, offset : Int) -> TypeCanonicalizer {
  // These defaults will work for when we are canonicalizing types from
  // outside of a rec group definition, forcing all `PackedIndex`es to be
  // canonicalized to `CoreTypeId`s.
  let rec_group_start = 0xFFFF_FFFFU
  let rec_group_len = 0U
  {
    module_,
    features: None,
    rec_group_start,
    rec_group_len,
    offset,
    mode: HashConsing,
    within_rec_group: None,
  }
}

///|
fn TypeCanonicalizer::with_features(
  self : TypeCanonicalizer,
  features : WasmFeatures,
) -> Unit {
  self.features = Some(features)
}

///|
fn TypeCanonicalizer::allow_gc(self : TypeCanonicalizer) -> Bool {
  match self.features {
    None => true
    Some(f) => f.gc()
  }
}

///|
fn TypeCanonicalizer::canonicalize_rec_group(
  self : TypeCanonicalizer,
  rec_group : RecGroup,
) -> Unit raise BinaryReaderError {
  // Re-initialize these fields so that we properly canonicalize
  // intra-rec-group type references into indices into the rec group
  // rather than as `CoreTypeId`s.
  self.rec_group_start = self.module_.types_len()
  self.rec_group_len = rec_group.len().reinterpret_as_uint()
  for rec_group_local_index in 0..<rec_group.len() {
    let ty = rec_group.get(rec_group_local_index)
    let type_index = self.rec_group_start +
      rec_group_local_index.reinterpret_as_uint()
    if ty.supertype_idx is Some(sup) {
      if sup.as_module_index() is Some(i) && i >= type_index {
        bail(self.offset, "supertypes must be defined before subtypes")
      }
    }
    ty.remap_indices(idx => self.canonicalize_type_index(idx))
  }
}

///|
fn TypeCanonicalizer::canonicalize_type_index(
  self : TypeCanonicalizer,
  ty : PackedIndex,
) -> PackedIndex raise BinaryReaderError {
  match ty.unpack() {
    Id(_) => ty
    Module(index) => {
      if index < self.rec_group_start || self.mode == OnlyIds {
        let id = self.module_.type_id_at(index, self.offset)
        match PackedIndex::from_id(id) {
          Some(id) => return id
          None =>
            bail(
              self.offset,
              "implementation limit: too many types in `TypeList`",
            )
        }
      }

      // When GC is not enabled the `rec_group_len == 1` so any rec group
      // local type references will be direct self references. But any kind of
      // type recursion, including self references, is not allowed in the
      // typed function references proposal, only the GC proposal.
      let local = index - self.rec_group_start
      if local < self.rec_group_len {
        if self.allow_gc() {
          match PackedIndex::from_rec_group_index(local) {
            Some(id) => return id
            None =>
              bail(
                self.offset,
                "implementation limit: too many types in a recursion group",
              )
          }
        } else {
          bail(
            self.offset,
            "unknown type \{index}: type index out of bounds because the GC proposal is disabled",
          )
        }
      }
      bail(self.offset, "unknown type \{index}: type index out of bounds")
    }
    RecGroup(local_index) =>
      match self.mode {
        HashConsing => ty
        OnlyIds => {
          let (start, end) = self.within_rec_group.unwrap()
          let rec_group_len = end.index - start.index
          guard local_index < rec_group_len
          let id = CoreTypeId::from_index(start.index + local_index)
          PackedIndex::from_id(id).unwrap()
        }
      }
  }
}
