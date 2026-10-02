// Port of `hayro-syntax/src/reader.rs`: reading bytes and PDF objects from
// data.

///|
/// Something that can be read from a [`Reader`].
pub(open) trait Readable {
  fn read(Reader, ReaderContext) -> Self?
}

///|
/// Something that can be skipped by a [`Reader`].
pub(open) trait Skippable {
  fn skip(Reader, Bool) -> Unit?
}

///|
/// Read an object, restoring the offset if reading fails.
pub fn[T : Readable] Reader::read(self : Reader, ctx : ReaderContext) -> T? {
  let old_offset = self.offset
  match T::read(self, ctx) {
    Some(v) => Some(v)
    None => {
      self.offset = old_offset
      None
    }
  }
}

///|
pub fn[T : Readable] Reader::read_with_context(
  self : Reader,
  ctx : ReaderContext,
) -> T? {
  self.read(ctx)
}

///|
pub fn[T : Readable] Reader::read_without_context(self : Reader) -> T? {
  self.read(ReaderContext::dummy_ref())
}

///|
/// Skip an object with the given skip function (upstream
/// `r.skip::<T>(is_content_stream)`), restoring the offset if skipping
/// fails. Returns the skipped bytes.
pub fn Reader::skip(
  self : Reader,
  skip : (Reader, Bool) -> Unit?,
  is_content_stream : Bool,
) -> BytesView? {
  let old_offset = self.offset
  match skip(self, is_content_stream) {
    Some(_) => self.range(old_offset, self.offset)
    None => {
      self.offset = old_offset
      None
    }
  }
}

///|
/// Context for reading PDF objects.
///
/// Upstream's context is either shared data or a dummy; setters on a dummy
/// context are no-ops (except `set_in_content_stream`).
pub struct ReaderContext {
  priv xref : XRef
  priv dummy : Bool
  priv in_content_stream : Bool
  priv in_object_stream : Bool
  priv obj_number : ObjectIdentifier?
  priv parent_chain : Array[ObjectIdentifier]
}

///|
pub fn ReaderContext::new(
  xref : XRef,
  in_content_stream : Bool,
) -> ReaderContext {
  {
    xref,
    dummy: false,
    in_content_stream,
    in_object_stream: false,
    obj_number: None,
    parent_chain: [],
  }
}

///|
pub fn ReaderContext::dummy() -> ReaderContext {
  {
    xref: XRef::dummy(),
    dummy: true,
    in_content_stream: false,
    in_object_stream: false,
    obj_number: None,
    parent_chain: [],
  }
}

///|
let dummy_ref_ctx : ReaderContext = {
  xref: XRef::dummy(),
  dummy: true,
  in_content_stream: true,
  in_object_stream: false,
  obj_number: None,
  parent_chain: [],
}

///|
pub fn ReaderContext::dummy_ref() -> ReaderContext {
  dummy_ref_ctx
}

///|
pub fn ReaderContext::xref(self : ReaderContext) -> XRef {
  self.xref
}

///|
pub fn ReaderContext::in_content_stream(self : ReaderContext) -> Bool {
  self.in_content_stream
}

///|
pub fn ReaderContext::in_object_stream(self : ReaderContext) -> Bool {
  !self.dummy && self.in_object_stream
}

///|
pub fn ReaderContext::obj_number(self : ReaderContext) -> ObjectIdentifier? {
  if self.dummy {
    None
  } else {
    self.obj_number
  }
}

///|
/// `set_obj_number` on a copy.
pub fn ReaderContext::with_obj_number(
  self : ReaderContext,
  id : ObjectIdentifier,
) -> ReaderContext {
  if self.dummy {
    self
  } else {
    { ..self, obj_number: Some(id), }
  }
}

///|
/// `set_in_content_stream` on a copy.
pub fn ReaderContext::with_in_content_stream(
  self : ReaderContext,
  val : Bool,
) -> ReaderContext {
  { ..self, in_content_stream: val, }
}

///|
/// `set_in_object_stream` on a copy.
pub fn ReaderContext::with_in_object_stream(
  self : ReaderContext,
  val : Bool,
) -> ReaderContext {
  if self.dummy {
    self
  } else {
    { ..self, in_object_stream: val, }
  }
}

///|
pub fn ReaderContext::parent_chain_contains(
  self : ReaderContext,
  id : ObjectIdentifier,
) -> Bool {
  !self.dummy && self.parent_chain.contains(id)
}

///|
/// `parent_chain_push` on a copy.
pub fn ReaderContext::with_parent(
  self : ReaderContext,
  id : ObjectIdentifier,
) -> ReaderContext {
  if self.dummy {
    self
  } else {
    let chain = self.parent_chain.copy()
    chain.push(id)
    { ..self, parent_chain: chain, }
  }
}

///|
/// Read an object from bytes (`FromBytes::from_bytes`).
pub fn[T : Readable] from_bytes(b : BytesView) -> T? {
  let r = Reader::new(b)
  T::read(r, ReaderContext::dummy())
}
