// Port of `hayro-syntax/src/object/mod.rs`: parsing and reading from PDF
// objects.

///|
/// A trait for PDF objects (upstream `ObjectLike`: `TryFrom<Object>` +
/// `Readable`).
pub(open) trait ObjectLike: Readable {
  fn from_object(Object) -> Self?
}

///|
/// A primitive PDF object.
pub(all) enum Object {
  /// A null object.
  Null
  /// A boolean object.
  Boolean(Bool)
  /// A number object.
  Number(Number)
  /// A string object.
  String(PdfString)
  /// A name object.
  Name(Name)
  /// A dict object.
  Dict(Dict)
  /// An array object.
  Array(PdfArray)
  /// A stream object.
  Stream(Stream)
}

///|
pub impl Eq for Object with fn equal(a, b) {
  match (a, b) {
    (Null, Null) => true
    (Boolean(x), Boolean(y)) => x == y
    (Number(x), Number(y)) => x == y
    (String(x), String(y)) => x == y
    (Name(x), Name(y)) => x == y
    (Dict(x), Dict(y)) => x == y
    (Array(x), Array(y)) => x == y
    (Stream(x), Stream(y)) => x == y
    _ => false
  }
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Object with Eq::{not_equal, equal}

///|
/// Try casting the object to a specific subtype.
pub fn[T : ObjectLike] Object::cast(self : Object) -> T? {
  T::from_object(self)
}

///|
pub fn Object::into_dict(self : Object) -> Dict? {
  match self {
    Dict(d) => Some(d)
    _ => None
  }
}

///|
pub fn Object::into_name(self : Object) -> Name? {
  match self {
    Name(n) => Some(n)
    _ => None
  }
}

///|
pub fn Object::into_bool(self : Object) -> Bool? {
  match self {
    Boolean(b) => Some(b)
    _ => None
  }
}

///|
pub fn Object::into_string(self : Object) -> PdfString? {
  match self {
    String(s) => Some(s)
    _ => None
  }
}

///|
pub fn Object::into_stream(self : Object) -> Stream? {
  match self {
    Stream(s) => Some(s)
    _ => None
  }
}

///|
pub fn Object::into_array(self : Object) -> PdfArray? {
  match self {
    Array(a) => Some(a)
    _ => None
  }
}

///|
pub fn Object::into_number(self : Object) -> Number? {
  match self {
    Number(n) => Some(n)
    _ => None
  }
}

///|
pub fn Object::into_f32(self : Object) -> Float? {
  self.cast()
}

///|
pub fn Object::into_i32(self : Object) -> Int? {
  self.cast()
}

///|
pub impl ObjectLike for Object with fn from_object(o) {
  Some(o)
}

///|
#deprecated("call as `ObjectLike::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Object with ObjectLike::{from_object}

///|
pub impl Skippable for Object with fn skip(r, is_content_stream) {
  guard r.peek_byte() is Some(peeked) else { return None }
  match peeked {
    b'n' => skip_null(r)
    b't' | b'f' => skip_bool(r)
    b'/' => skip_name_like(r, true)
    b'<' =>
      match r.peek_bytes(2) {
        None => None
        // A stream can never appear in a dict/array, so it should never be skipped.
        Some([b'<', b'<']) => skip_dict(r, is_content_stream)
        Some(_) => skip_string(r)
      }
    b'(' => skip_string(r)
    b'.' | b'+' | b'-' | b'0'..=b'9' => skip_number(r)
    b'[' => skip_array(r, is_content_stream)
    // See test case operator-in-TJ-array-0: Be lenient and skip content operators in
    // array
    _ => skip_name_like(r, false)
  }
}

///|
pub extend Object with Skippable::{skip}

///|
pub impl Readable for Object with fn read(r, ctx) {
  guard r.peek_byte() is Some(peeked) else { return None }
  match peeked {
    b'n' => skip_null(r).map(_ => Object::Null)
    b't' | b'f' => read_bool(r).map(b => Boolean(b))
    b'/' => Name::read(r, ctx).map(n => Object::Name(n))
    b'<' =>
      match r.peek_bytes(2) {
        None => None
        Some([b'<', b'<']) => {
          let cloned = r.clone()
          guard Dict::read(cloned, ctx) is Some(dict) else { return None }
          cloned.skip_white_spaces_and_comments()
          if cloned.forward_tag(b"stream") is Some(_) {
            Stream::read(r, ctx).map(s => Object::Stream(s))
          } else {
            r.jump(cloned.offset())
            Some(Object::Dict(dict))
          }
        }
        Some(_) => PdfString::read(r, ctx).map(s => Object::String(s))
      }
    b'(' => PdfString::read(r, ctx).map(s => Object::String(s))
    b'.' | b'+' | b'-' | b'0'..=b'9' =>
      Number::read(r, ctx).map(n => Object::Number(n))
    b'[' => PdfArray::read(r, ctx).map(a => Object::Array(a))
    // See the comment in `skip`.
    _ => skip_name_like(r, false).map(_ => Object::Null)
  }
}

///|
#deprecated("call as `Readable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Object with Readable::{read}

///|
/// An identifier for a PDF object.
pub(all) struct ObjectIdentifier {
  /// The object number.
  obj_number : Int
  /// The generation number.
  gen_number : Int
} derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ObjectIdentifier with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ObjectIdentifier with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ObjectIdentifier with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ObjectIdentifier with @debug.Debug::{to_repr}

///|
/// Create a new `ObjectIdentifier`.
pub fn ObjectIdentifier::new(
  obj_number : Int,
  gen_number : Int,
) -> ObjectIdentifier {
  { obj_number, gen_number, }
}

///|
pub impl Readable for ObjectIdentifier with fn read(r, _) {
  guard (r.read_without_context() : Int?) is Some(obj_number) else {
    return None
  }
  r.skip_white_spaces_and_comments()
  guard (r.read_without_context() : Int?) is Some(gen_number) else {
    return None
  }
  r.skip_white_spaces_and_comments()
  guard r.forward_tag(b"obj") is Some(_) else { return None }
  Some({ obj_number, gen_number, })
}

///|
#deprecated("call as `Readable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ObjectIdentifier with Readable::{read}

///|
pub impl Skippable for ObjectIdentifier with fn skip(r, _) {
  guard skip_int(r) is Some(_) else { return None }
  r.skip_white_spaces_and_comments()
  guard skip_int(r) is Some(_) else { return None }
  r.skip_white_spaces_and_comments()
  r.forward_tag(b"obj")
}

///|
pub extend ObjectIdentifier with Skippable::{skip}

///|
/// A convenience function that extracts a dict and a stream from an object.
/// If the object is just a dictionary, it will return `None` for the stream.
/// If the object is a stream, it will return its dictionary as well as the
/// stream itself.
pub fn dict_or_stream(obj : Object) -> (Dict, Stream?)? {
  match obj {
    Stream(stream) => Some((stream.dict(), Some(stream)))
    Dict(dict) => Some((dict, None))
    _ => None
  }
}

///|
// ---- null and booleans (`null.rs`, `bool.rs`) ----

///|
fn skip_null(r : Reader) -> Unit? {
  r.forward_tag(b"null")
}

///|
fn skip_bool(r : Reader) -> Unit? {
  guard r.peek_byte() is Some(peeked) else { return None }
  match peeked {
    b't' => r.forward_tag(b"true")
    b'f' => r.forward_tag(b"false")
    _ => None
  }
}

///|
fn read_bool(r : Reader) -> Bool? {
  let start = r.offset()
  guard skip_bool(r) is Some(_) else { return None }
  match r.offset() - start {
    4 => Some(true)
    5 => Some(false)
    _ => None
  }
}

///|
pub impl Readable for Bool with fn read(r, _) {
  let old = r.offset()
  match read_bool(r) {
    Some(b) => Some(b)
    None => {
      r.jump(old)
      None
    }
  }
}

///|
pub impl Skippable for Bool with fn skip(r, _) {
  skip_bool(r)
}

///|
pub impl ObjectLike for Bool with fn from_object(o) {
  match o {
    Boolean(b) => Some(b)
    _ => None
  }
}
