// Port of `hayro-syntax/src/object/array.rs`: arrays.

///|
/// An array of PDF objects.
pub struct PdfArray {
  priv data : BytesView
  priv ctx : ReaderContext
}

///|
// Note that this is not structural equality, i.e. two arrays with the same
// items are still considered different if they have different whitespaces.
pub impl Eq for PdfArray with fn equal(a, b) {
  a.data == b.data
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PdfArray with Eq::{not_equal, equal}

///|
/// An empty array.
pub fn PdfArray::empty() -> PdfArray {
  { data: b""[:], ctx: ReaderContext::dummy(), }
}

///|
/// Returns an iterator over the (unresolved) objects of the array.
pub fn PdfArray::raw_iter(self : PdfArray) -> Iter[MaybeRef[Object]] {
  let reader = Reader::new(self.data)
  let ctx = self.ctx
  Iter::new(fn() {
    reader.skip_white_spaces_and_comments()
    if !reader.at_end() {
      // Objects are already guaranteed to be valid.
      let item : MaybeRef[Object] = reader.read_with_context(ctx).unwrap()
      Some(item)
    } else {
      None
    }
  })
}

///|
/// Returns an iterator over the resolved objects of the array. Iteration
/// stops at the first item that cannot be read as a `T`.
pub fn[T : ObjectLike] PdfArray::iter(self : PdfArray) -> Iter[T] {
  let flex = self.flex_iter()
  Iter::new(fn() { flex.next() })
}

///|
/// Collect the resolved objects of the array (upstream `iter().collect()`).
pub fn[T : ObjectLike] PdfArray::to_vec(self : PdfArray) -> Array[T] {
  self.iter().collect()
}

///|
/// Return a flex iterator over the items in the array.
pub fn PdfArray::flex_iter(self : PdfArray) -> FlexArrayIter {
  { reader: Reader::new(self.data), ctx: self.ctx, }
}

///|
/// Return the raw data of the array.
pub fn PdfArray::data(self : PdfArray) -> BytesView {
  self.data
}

///|
pub impl Show for PdfArray with fn output(self, logger) {
  logger.write_string("Array(")
  logger.write_string(@utf8.decode_lossy(self.data))
  logger.write_string(")")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PdfArray with Show::{to_string, output}

///|
fn skip_array(r : Reader, is_content_stream : Bool) -> Unit? {
  guard r.forward_tag(b"[") is Some(_) else { return None }
  while true {
    r.skip_white_spaces_and_comments()
    if r.forward_tag(b"]") is Some(_) {
      return Some(())
    } else if is_content_stream {
      guard r.skip(Object::skip, true) is Some(_) else { return None }
    } else {
      guard r.skip(skip_maybe_ref_object, false) is Some(_) else { return None }
    }
  }
  None
}

///|
/// `MaybeRef<Object>::skip`.
fn skip_maybe_ref_object(r : Reader, is_content_stream : Bool) -> Unit? {
  skip_maybe_ref(r, Object::skip, is_content_stream)
}

///|
pub impl Skippable for PdfArray with fn skip(r, c) {
  skip_array(r, c)
}

///|
#deprecated("call as `Skippable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PdfArray with Skippable::{skip}

///|
pub impl Readable for PdfArray with fn read(r, ctx) {
  guard r.skip(skip_array, ctx.in_content_stream()) is Some(bytes) else {
    return None
  }
  Some({ data: bytes[1:bytes.length() - 1], ctx, })
}

///|
pub extend PdfArray with Readable::{read}

///|
pub impl ObjectLike for PdfArray with fn from_object(o) {
  match o {
    Array(a) => Some(a)
    _ => None
  }
}

///|
#deprecated("call as `ObjectLike::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PdfArray with ObjectLike::{from_object}

///|
/// An iterator over the array that allows reading a different object each
/// time.
pub struct FlexArrayIter {
  priv reader : Reader
  priv ctx : ReaderContext
}

///|
/// Try reading the next item as a specific object from the array.
pub fn[T : ObjectLike] FlexArrayIter::next(self : FlexArrayIter) -> T? {
  self.reader.skip_white_spaces_and_comments()
  if !self.reader.at_end() {
    guard (self.reader.read_with_context(self.ctx) : MaybeRef[T]?) is Some(item) else {
      return None
    }
    return match item {
      Ref(r) => self.ctx.xref().get_with(r.to_id(), self.ctx)
      NotRef(i) => Some(i)
    }
  }
  None
}

///|
/// Read exactly `n` items of type `T` (upstream `[T; C]: TryFrom<Array>`).
pub fn[T : ObjectLike] PdfArray::to_fixed(
  self : PdfArray,
  n : Int,
) -> Array[T]? {
  let iter = self.flex_iter()
  let val = []
  for _ in 0..<n {
    guard iter.next() is Some(v) else { return None }
    val.push(v)
  }
  let excess : T? = iter.next()
  if excess is Some(_) {
    // found excess elements in array
    return None
  }
  Some(val)
}

///|
/// A vector of objects (upstream `Vec<T>: ObjectLike`).
pub(all) struct Vector[T](Array[T])

///|
pub impl[T : ObjectLike] Readable for Vector[T] with fn read(r, ctx) {
  guard PdfArray::read(r, ctx) is Some(array) else { return None }
  Some(Vector(array.to_vec()))
}

///|
#deprecated("call as `Readable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector with Readable::{read}

///|
pub impl[T : ObjectLike] ObjectLike for Vector[T] with fn from_object(o) {
  match o {
    Array(a) => Some(Vector(a.to_vec()))
    _ => None
  }
}

///|
#deprecated("call as `ObjectLike::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector with ObjectLike::{from_object}

///|
/// A fixed-size array of objects (upstream `[T; C]: ObjectLike`); `n` is
/// checked by `Dict::get_fixed`.
fn[T : ObjectLike] fixed_from_object(o : Object, n : Int) -> Array[T]? {
  match o {
    Array(a) => a.to_fixed(n)
    _ => None
  }
}
