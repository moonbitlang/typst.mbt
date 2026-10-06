// Port of `hayro-syntax/src/object/dict.rs`: dictionaries.

///|
/// A dictionary, which is a key-value map, keys being names, and values
/// being any PDF object or object reference.
///
/// Entries are parsed lazily: the dictionary stores its raw data and the
/// offsets of the values.
pub struct Dict {
  priv data : BytesView
  priv offsets : Map[String, Int]?
  priv ctx : ReaderContext
}

///|
// Note that this is not structural equality, i.e. two dictionaries with the same
// items are still considered different if they have different whitespaces.
pub impl Eq for Dict with fn equal(a, b) {
  a.data() == b.data()
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Dict with Eq::{not_equal, equal}

///|
pub impl Default for Dict with fn default() {
  Dict::empty()
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Dict with Default::{default}

///|
/// Create a new empty dictionary.
pub fn Dict::empty() -> Dict {
  { data: b""[:], offsets: None, ctx: ReaderContext::dummy_ref(), }
}

///|
/// Get the raw bytes underlying to the dictionary.
pub fn Dict::data(self : Dict) -> BytesView {
  self.data
}

///|
/// Returns the number of entries in the dictionary.
pub fn Dict::len(self : Dict) -> Int {
  match self.offsets {
    Some(o) => o.length()
    None => 0
  }
}

///|
/// Return whether the dictionary is empty.
pub fn Dict::is_empty(self : Dict) -> Bool {
  self.len() == 0
}

///|
/// Checks whether the dictionary contains an entry with a specific key.
pub fn Dict::contains_key(self : Dict, key : String) -> Bool {
  match self.offsets {
    Some(o) => o.contains(key)
    None => false
  }
}

///|
/// Returns the entry of a key as a specific object, or try to resolve it in
/// case it's an object reference.
pub fn[T : ObjectLike] Dict::get(self : Dict, key : String) -> T? {
  guard (self.get_raw(key) : MaybeRef[T]?) is Some(raw) else { return None }
  raw.resolve(self.ctx)
}

///|
/// Returns the entry of a key as an array of exactly `n` items (upstream
/// `get::<[T; C]>`).
pub fn[T : ObjectLike] Dict::get_fixed(
  self : Dict,
  key : String,
  n : Int,
) -> Array[T]? {
  guard (self.get(key) : Object?) is Some(obj) else { return None }
  fixed_from_object(obj, n)
}

///|
/// Get the object reference linked to a key.
pub fn Dict::get_ref(self : Dict, key : String) -> ObjRef? {
  guard self.offsets is Some(offsets) && offsets.get(key) is Some(offset) else {
    return None
  }
  Reader::new(self.data[offset:]).read_with_context(self.ctx)
}

///|
/// Returns all keys in the dictionary (in no particular order).
pub fn Dict::keys(self : Dict) -> Array[Name] {
  match self.offsets {
    Some(o) => o.keys().map(k => Name::from_string(k)).collect()
    None => []
  }
}

///|
/// All entries in the dictionary, sorted by key.
pub fn Dict::entries(self : Dict) -> Array[(Name, MaybeRef[Object])] {
  let sorted_keys = self.keys()
  sorted_keys.sort_by((a, b) => compare_latin1(a.0, b.0))
  sorted_keys.map(k => {
    let obj : MaybeRef[Object] = self.get_raw(k.0).unwrap()
    (k, obj)
  })
}

///|
/// Return the object identifier of the dict, if it's an indirect object.
pub fn Dict::obj_id(self : Dict) -> ObjectIdentifier? {
  self.ctx.obj_number()
}

///|
/// Return the raw entry for a specific key.
pub fn[T : Readable] Dict::get_raw(self : Dict, key : String) -> MaybeRef[T]? {
  guard self.offsets is Some(offsets) && offsets.get(key) is Some(offset) else {
    return None
  }
  Reader::new(self.data[offset:]).read_with_context(self.ctx)
}

///|
pub fn Dict::ctx(self : Dict) -> ReaderContext {
  self.ctx
}

///|
pub impl Show for Dict with fn output(self, logger) {
  logger.write_string("Dict(")
  logger.write_string(@utf8.decode_lossy(self.data))
  logger.write_string(")")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Dict with Show::{to_string, output}

///|
fn skip_dict(r : Reader, is_content_stream : Bool) -> Unit? {
  guard r.forward_tag(b"<<") is Some(_) else { return None }
  while true {
    r.skip_white_spaces_and_comments()
    if r.forward_tag(b">>") is Some(_) {
      return Some(())
    } else {
      guard r.skip(fn(r, c) { Name::skip(r, c) }, is_content_stream) is Some(_) else {
        // In case there is garbage in-between, be lenient and just try to skip it.
        guard r.skip(Object::skip, is_content_stream) is Some(_) else {
          return None
        }
        continue
      }
      r.skip_white_spaces_and_comments()
      if is_content_stream {
        guard r.skip(Object::skip, is_content_stream) is Some(_) else {
          return None
        }
      } else {
        guard r.skip(skip_maybe_ref_object, is_content_stream) is Some(_) else {
          return None
        }
      }
    }
  }
  None
}

///|
pub impl Skippable for Dict with fn skip(r, c) {
  skip_dict(r, c)
}

///|
#deprecated("call as `Skippable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Dict with Skippable::{skip}

///|
pub impl Readable for Dict with fn read(r, ctx) {
  read_dict_inner(r, ctx, Some(b"<<"), b">>")
}

///|
pub extend Dict with Readable::{read}

///|
pub impl ObjectLike for Dict with fn from_object(o) {
  match o {
    Dict(d) => Some(d)
    _ => None
  }
}

///|
#deprecated("call as `ObjectLike::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Dict with ObjectLike::{from_object}

///|
fn read_dict_inner(
  r : Reader,
  ctx : ReaderContext,
  start_tag : Bytes?,
  end_tag : Bytes,
) -> Dict? {
  let offsets = Map([], capacity=8)
  let data = parse_dict_with(r, ctx, start_tag, end_tag, fn(name, offset, _) {
    offsets[name.0] = offset
    Some(())
  })
  guard data is Some(data) else { return None }
  Some({ data, offsets: Some(offsets), ctx, })
}

///|
priv struct DictProbe {
  data : BytesView
  has_root : Bool
  has_type : Bool
}

///|
// We use that method during fallback xref parsing, so that we can search for
// the dictionaries we need without allocating the whole hash map.
fn probe_dict(
  r : Reader,
  ctx : ReaderContext,
  start_tag : Bytes?,
  end_tag : Bytes,
) -> DictProbe? {
  let mut has_root = false
  let mut has_type = false
  let data = parse_dict_with(r, ctx, start_tag, end_tag, fn(name, _, _) {
    if name.0 == "Root" {
      has_root = true
    } else if name.0 == "Type" {
      has_type = true
    }
    Some(())
  })
  guard data is Some(data) else { return None }
  Some({ data, has_root, has_type, })
}

///|
fn parse_dict_with(
  r : Reader,
  ctx : ReaderContext,
  start_tag : Bytes?,
  end_tag : Bytes,
  on_entry : (Name, Int, Reader) -> Unit?,
) -> BytesView? {
  guard r.tail() is Some(dict_data) else { return None }
  let start_offset = r.offset()

  // Inline image dictionaries don't start with '<<'.
  if start_tag is Some(start_tag) {
    guard r.forward_tag(start_tag) is Some(_) else { return None }
  }
  while true {
    r.skip_white_spaces_and_comments()

    // Normal dictionaries end with '>>', inline image dictionaries end with BD.
    if r.peek_tag(end_tag) is Some(_) {
      guard r.forward_tag(end_tag) is Some(_) else { return None }
      let end_offset = r.offset() - start_offset
      return Some(dict_data[:end_offset])
    } else {
      let name : Name? = r.read_without_context()
      guard name is Some(name) else {
        if start_tag is Some(_) {
          // In case there is garbage in-between, be lenient and just try to skip it.
          // But only do this if we are parsing a proper dictionary as opposed to an
          // inline dictionary.
          guard (r.read(ctx) : Object?) is Some(_) else { return None }
          continue
        } else {
          return None
        }
      }
      r.skip_white_spaces_and_comments()
      let offset = r.offset() - start_offset
      // Do note that we are including objects in our dictionary even if they
      // are the null object, meaning that a call to `contains_key` will return `true`
      // even if the object is the null object.
      guard on_entry(name, offset, r) is Some(_) else { return None }
      if ctx.in_content_stream() {
        guard r.skip(Object::skip, ctx.in_content_stream()) is Some(_) else {
          return None
        }
      } else {
        guard r.skip(skip_maybe_ref_object, ctx.in_content_stream()) is Some(_) else {
          return None
        }
      }
    }
  }
  None
}

///|
/// The dictionary of an inline image (ends with `ID`).
pub(all) struct InlineImageDict(Dict)

///|
pub fn InlineImageDict::get_dict(self : InlineImageDict) -> Dict {
  self.0
}

///|
pub impl Readable for InlineImageDict with fn read(r, ctx) {
  read_dict_inner(r, ctx, None, b"ID").map(d => InlineImageDict(d))
}

///|
#deprecated("call as `Readable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InlineImageDict with Readable::{read}
