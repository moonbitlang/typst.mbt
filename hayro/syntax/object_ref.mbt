// Port of `hayro-syntax/src/object/ref.rs` and `object/indirect.rs`: object
// references and indirect objects.

///|
/// A reference to an object.
pub(all) struct ObjRef {
  /// The object number.
  obj_number : Int
  /// The generation number.
  gen_number : Int
} derive(Eq, Hash, Debug, Compare)

///|
/// Create a new object reference.
pub fn ObjRef::new(obj_number : Int, gen_number : Int) -> ObjRef {
  { obj_number, gen_number, }
}

///|
pub fn ObjRef::to_id(self : ObjRef) -> ObjectIdentifier {
  ObjectIdentifier::new(self.obj_number, self.gen_number)
}

///|
pub fn ObjectIdentifier::to_ref(self : ObjectIdentifier) -> ObjRef {
  ObjRef::new(self.obj_number, self.gen_number)
}

///|
fn skip_obj_ref(r : Reader, _ : Bool) -> Unit? {
  guard skip_int(r) is Some(_) else { return None }
  r.skip_white_spaces()
  guard skip_int(r) is Some(_) else { return None }
  r.skip_white_spaces()
  r.forward_tag(b"R")
}

///|
pub impl Skippable for ObjRef with fn skip(r, c) {
  skip_obj_ref(r, c)
}

///|
pub impl Readable for ObjRef with fn read(r, _) {
  guard (r.read_without_context() : Int?) is Some(obj_ref) else { return None }
  r.skip_white_spaces()
  guard (r.read_without_context() : Int?) is Some(gen_num) else { return None }
  r.skip_white_spaces()
  guard r.forward_tag(b"R") is Some(_) else { return None }
  Some(ObjRef::new(obj_ref, gen_num))
}

///|
/// A struct that is either an object or a reference to an object.
pub(all) enum MaybeRef[T] {
  /// A reference to an object.
  Ref(ObjRef)
  /// An object.
  NotRef(T)
}

///|
/// If the object is an object reference, return it.
pub fn[T] MaybeRef::as_obj_ref(self : MaybeRef[T]) -> ObjRef? {
  match self {
    Ref(r) => Some(r)
    NotRef(_) => None
  }
}

///|
/// Resolve the `MaybeRef` object with the given xref table.
pub fn[T : ObjectLike] MaybeRef::resolve(
  self : MaybeRef[T],
  ctx : ReaderContext,
) -> T? {
  match self {
    Ref(r) => ctx.xref().get_with(r.to_id(), ctx)
    NotRef(t) => Some(t)
  }
}

///|
/// Skip an object reference or something skipped by `skip`
/// (`MaybeRef<T>::skip`).
fn skip_maybe_ref(
  r : Reader,
  skip : (Reader, Bool) -> Unit?,
  is_content_stream : Bool,
) -> Unit? {
  match r.skip(skip_obj_ref, is_content_stream) {
    Some(_) => Some(())
    None => r.skip(skip, is_content_stream).map(_ => ())
  }
}

///|
pub impl[T : Skippable] Skippable for MaybeRef[T] with fn skip(
  r,
  is_content_stream,
) {
  skip_maybe_ref(r, fn(r, c) { T::skip(r, c) }, is_content_stream)
}

///|
pub impl[T : Readable] Readable for MaybeRef[T] with fn read(r, ctx) {
  let obj : ObjRef? = r.read(ctx)
  if obj is Some(obj) {
    Some(Ref(obj))
  } else {
    r.read(ctx).map(v => NotRef(v))
  }
}

///|
/// An indirect object.
pub struct IndirectObject[T] {
  priv id : ObjectIdentifier
  priv inner : T
}

///|
pub fn[T] IndirectObject::get(self : IndirectObject[T]) -> T {
  self.inner
}

///|
pub fn[T] IndirectObject::id(self : IndirectObject[T]) -> ObjectIdentifier {
  self.id
}

///|
pub impl[T : Readable] Readable for IndirectObject[T] with fn read(r, ctx) {
  guard (r.read_without_context() : ObjectIdentifier?) is Some(id) else {
    return None
  }
  if ctx.parent_chain_contains(id) {
    // cycle detected in indirect object
    return None
  }
  let ctx = ctx.with_obj_number(id).with_parent(id)
  r.skip_white_spaces_and_comments()
  guard (r.read_with_context(ctx) : T?) is Some(inner) else { return None }
  r.skip_white_spaces_and_comments()
  // We are lenient and don't require it.
  r.forward_tag(b"endobj") |> ignore
  Some({ id, inner, })
}

///|
/// Skip an indirect object whose body is skipped by `skip`.
fn skip_indirect(r : Reader, skip : (Reader, Bool) -> Unit?) -> Unit? {
  guard r.skip(fn(r, c) { ObjectIdentifier::skip(r, c) }, false) is Some(_) else {
    return None
  }
  r.skip_white_spaces_and_comments()
  guard r.skip(skip, false) is Some(_) else { return None }
  r.skip_white_spaces_and_comments()
  // We are lenient and don't require it.
  r.forward_tag(b"endobj") |> ignore
  Some(())
}

///|
pub impl[T : Skippable] Skippable for IndirectObject[T] with fn skip(r, _) {
  skip_indirect(r, fn(r, c) { T::skip(r, c) })
}
