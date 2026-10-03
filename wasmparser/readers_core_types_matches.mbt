// Port of wasmparser 0.228.0 `src/readers/core/types/matches.rs`:
// implementation of matching (structural subtyping) for core Wasm types.
//
// We only ever do structural matching for one link at a time in a subtype
// chain. That is, we never recurse on new `SubType`s. This is because
// subtyping relations are required to be declared, so the earlier links in the
// chain were already checked when we processed those declarations.
//
// Note that while we don't recursively *match* on each sub- and supertype field
// when checking whether a struct type matches another struct type, we do check
// that either `field_type_a == field_type b` or that it was previously
// declared that `field_type a <: field_type b`. The latter case means that we
// previously checked that they matched when we saw the declaration, and we
// don't need to match again; we just look at the declarations from now on.
//
// Upstream's `Matches for WithRecGroup<T>` impls become one function per `T`
// taking the rec group of each side.

///|
fn TypeList::matches_sub_type(
  self : TypeList,
  a : SubType,
  a_group : RecGroupId,
  b : SubType,
  b_group : RecGroupId,
) -> Bool {
  // NB: matching does not check finality and supertypes. That is checked
  // once when we define types, not repeatedly every time we check
  // matches.
  self.matches_composite_type(
    a.composite_type,
    a_group,
    b.composite_type,
    b_group,
  )
}

///|
fn TypeList::matches_composite_type(
  self : TypeList,
  a : CompositeType,
  a_group : RecGroupId,
  b : CompositeType,
  b_group : RecGroupId,
) -> Bool {
  if a.shared != b.shared {
    return false
  }
  match (a.inner, b.inner) {
    (Func(fa), Func(fb)) => self.matches_func_type(fa, a_group, fb, b_group)
    (Func(_), _) => false
    (Array(aa), Array(ab)) =>
      self.matches_field_type(aa.0, a_group, ab.0, b_group)
    (Array(_), _) => false
    (Struct(sa), Struct(sb)) =>
      self.matches_struct_type(sa, a_group, sb, b_group)
    (Struct(_), _) => false
    (Cont(ca), Cont(cb)) => self.matches_cont_type(ca, a_group, cb, b_group)
    (Cont(_), _) => false
  }
}

///|
fn TypeList::matches_func_type(
  self : TypeList,
  a : FuncType,
  a_group : RecGroupId,
  b : FuncType,
  b_group : RecGroupId,
) -> Bool {
  if a.params().length() != b.params().length() ||
    a.results().length() != b.results().length() {
    return false
  }
  // A quick recap of covariance, contravariance, and how it applies to
  // subtyping function types, because I (and almost everyone else, it
  // seems) always need a reminder:
  //
  // *Covariance* is when `a <: b` and `a' <: b'`. That is, the subtyping
  // checks on the nested things (`a'` and `b'`) goes the same way as the
  // outer things (`a` and `b`).
  //
  // *Contravariance* is when `a <: b` and `b' <: a'`. That is, the
  // subtyping on the nested things is reversed compared to the outer
  // things.
  //
  // Now, when we are checking subtyping for function types, we have the
  // following variance:
  //
  // * Parameters are contravariant: `(a -> c) <: (b -> c)` when `b <: a`.
  //
  // * Results are covariant: `(a -> b) <: (a -> c)` when `b <: c`.
  let ap = a.params()
  let bp = b.params()
  for i in 0..<ap.length() {
    // Parameters are contravariant.
    if !self.matches_val_type(bp[i], b_group, ap[i], a_group) {
      return false
    }
  }
  let ar = a.results()
  let br = b.results()
  for i in 0..<ar.length() {
    // Results are covariant.
    if !self.matches_val_type(ar[i], a_group, br[i], b_group) {
      return false
    }
  }
  true
}

///|
fn TypeList::matches_struct_type(
  self : TypeList,
  a : StructType,
  a_group : RecGroupId,
  b : StructType,
  b_group : RecGroupId,
) -> Bool {
  // Note: Struct types support width and depth subtyping.
  if a.fields.length() < b.fields.length() {
    return false
  }
  for i in 0..<b.fields.length() {
    if !self.matches_field_type(a.fields[i], a_group, b.fields[i], b_group) {
      return false
    }
  }
  true
}

///|
fn TypeList::matches_field_type(
  self : TypeList,
  a : FieldType,
  a_group : RecGroupId,
  b : FieldType,
  b_group : RecGroupId,
) -> Bool {
  // `a`'s storage type must match `b`'s storage type.
  if !self.matches_storage_type(
      a.element_type,
      a_group,
      b.element_type,
      b_group,
    ) {
    return false
  }
  // And either both fields are immutable...
  if !a.mutable && !b.mutable {
    return true
  }
  // Or both fields are mutable and `b`'s storage type must match `a`'s
  // storage type, a.k.a. they must be the exact same storage type.
  a.mutable &&
  b.mutable &&
  self.matches_storage_type(b.element_type, b_group, a.element_type, a_group)
}

///|
fn TypeList::matches_storage_type(
  self : TypeList,
  a : StorageType,
  a_group : RecGroupId,
  b : StorageType,
  b_group : RecGroupId,
) -> Bool {
  match (a, b) {
    (I8, I8) | (I16, I16) => true
    (I8 | I16, _) => false
    (Val(va), Val(vb)) => self.matches_val_type(va, a_group, vb, b_group)
    (Val(_), _) => false
  }
}

///|
fn TypeList::matches_cont_type(
  self : TypeList,
  a : ContType,
  a_group : RecGroupId,
  b : ContType,
  b_group : RecGroupId,
) -> Bool {
  a.idx == b.idx ||
  self.reftype_is_subtype_impl(
    RefType::concrete(false, a.idx),
    Some(a_group),
    RefType::concrete(false, b.idx),
    Some(b_group),
  )
}

///|
fn TypeList::matches_val_type(
  self : TypeList,
  a : ValType,
  a_group : RecGroupId,
  b : ValType,
  b_group : RecGroupId,
) -> Bool {
  match (a, b) {
    (Ref(ra), Ref(rb)) =>
      self.reftype_is_subtype_impl(ra, Some(a_group), rb, Some(b_group))
    (Ref(_), _) => false
    (I32 | I64 | F32 | F64 | V128, _) => a == b
  }
}
