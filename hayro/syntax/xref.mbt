// Port of `hayro-syntax/src/xref.rs` (and `data.rs`): reading and querying
// the xref table of a PDF file.

///|
const XREF_ENTRY_LEN : Int = 20

///|
priv enum XRefError {
  Unknown
  Encryption(DecryptionError)
}

///|
/// Parse the "root" xref from the PDF.
fn root_xref(data : Bytes, password : Bytes) -> Result[XRef, XRefError] {
  let xref_map = Map([])
  guard find_last_xref_pos(data[:]) is Some(xref_pos) else { Err(Unknown) }
  guard populate_xref_impl(data[:], xref_pos, xref_map) is Some(trailer) else {
    Err(Unknown)
  }
  XRef::new(data, xref_map, TrailerDictData(trailer), false, password)
}

///|
/// Try to manually parse the PDF to build an xref table and trailer
/// dictionary.
fn fallback(data : Bytes, password : Bytes) -> XRef? {
  // xref table was invalid, trying to manually build xref table
  let (xref_map, xref_input) = fallback_xref_map(data, password)
  if xref_input is Some(xref_input) {
    XRef::new(data, xref_map, xref_input, true, password).to_option()
  } else {
    // couldn't find trailer dictionary, failed to rebuild xref table
    None
  }
}

///|
fn fallback_xref_map(
  data : Bytes,
  password : Bytes,
) -> (Map[ObjectIdentifier, EntryType], XRefInput?) {
  fallback_xref_map_inner(data, ReaderContext::dummy(), true, password)
}

///|
fn fallback_xref_map_inner(
  data : Bytes,
  dummy_ctx : ReaderContext,
  recurse : Bool,
  password : Bytes,
) -> (Map[ObjectIdentifier, EntryType], XRefInput?) {
  let mut dummy_ctx = dummy_ctx
  let mut xref_map : Map[ObjectIdentifier, EntryType] = Map([])
  let trailer_dicts : Array[Dict] = []
  let mut root_ref : ObjectIdentifier? = None
  let mut r = Reader::new(data[:])
  let mut last_obj_num : ObjectIdentifier? = None
  while true {
    let cur_pos = r.offset()
    let old_r = r.clone()

    // First try to check if we have an object identifier.
    if r.peek_byte() is Some(b) && b is (b'0'..=b'9') {
      let obj_id : ObjectIdentifier? = r.read(dummy_ctx)
      if obj_id is Some(obj_id) {
        let cloned = r.clone()
        // Check that the object following it is actually valid before inserting it.
        cloned.skip_white_spaces_and_comments()
        if cloned.skip(Object::skip, false) is Some(_) {
          xref_map[obj_id] = Normal(cur_pos)
          last_obj_num = Some(obj_id)
          dummy_ctx = dummy_ctx.with_obj_number(obj_id)
        }
      } else {
        // There must be a white space before the next object number.
        r.forward_while(b => !is_white_space_character(b))
      }
    } else {
      // Then, try to check whether we have a dictionary, in particular a trailer
      // dictionary.
      let probe_reader = r.clone()
      let probe = if r.peek_bytes(2) is Some([b'<', b'<']) {
        probe_dict(probe_reader, dummy_ctx, Some(b"<<"), b">>")
      } else {
        None
      }
      if probe is Some(probe) {
        r = probe_reader
        if probe.has_root || probe.has_type {
          let dict_reader = Reader::new(probe.data)
          let dict : Dict? = dict_reader.read_with_context(dummy_ctx)
          if dict is Some(dict) {
            if probe.has_root && dict.contains_key("Root") {
              trailer_dicts.push(dict)
            }
            let ty : Name? = dict.get("Type")
            if ty is Some(n) && n.as_str() == "Catalog" {
              root_ref = last_obj_num
            }
            let stream : Stream? = old_r.read(dummy_ctx)
            if stream is Some(stream) &&
              ty is Some(Name("ObjStm")) &&
              stream.decoded() is Ok(data) &&
              last_obj_num is Some(last_obj_num) &&
              ObjectStream::new(stream, data, dummy_ctx) is Some(obj_stream) {
              for idx, entry in obj_stream.offsets {
                let id = ObjectIdentifier::new(entry.0.reinterpret_as_int(), 0)
                // If we already found an entry for that object number that was not
                // inside an object stream. Somewhat arbitrary and maybe
                // we can do better, but that seems to work for the current
                // set of tests.
                let existing_normal = match xref_map.get(id) {
                  Some(Normal(_)) => true
                  _ => false
                }
                if !existing_normal {
                  xref_map[id] = ObjStream(
                    last_obj_num.obj_number.reinterpret_as_uint(),
                    idx.reinterpret_as_uint(),
                  )
                }
              }
            }
          }
        }
      } else {
        // We can skip everything until the next white space character,
        // as there cannot possibly be any new dictionary/object identifier
        // until then.
        let old_pos = r.offset
        r.forward_while(b => !is_white_space_character(b))
        if r.offset == old_pos {
          r.read_byte() |> ignore
        }
      }
    }
    if r.at_end() {
      break
    }
  }

  // Try to choose the right trailer dict by doing basic validation.
  let mut trailer_dict : Dict? = None
  for dict in trailer_dicts {
    let root_id : MaybeRef[Dict]? = dict.get_raw("Root")
    if root_id is Some(root_id) {
      let check = (dict : Dict) => dict.contains_key("Pages")
      match root_id {
        Ref(r) =>
          match xref_map.get(r.to_id()) {
            Some(Normal(offset)) => {
              let reader = Reader::new(data[offset:])
              let obj : IndirectObject[Dict]? = reader.read_with_context(
                dummy_ctx,
              )
              if obj is Some(obj) && check(obj.get()) {
                trailer_dict = Some(dict)
              }
            }
            Some(ObjStream(obj_num, idx)) =>
              if xref_map.get(
                  ObjectIdentifier::new(obj_num.reinterpret_as_int(), 0),
                )
                is Some(Normal(offset)) {
                let reader = Reader::new(data[offset:])
                let stream : IndirectObject[Stream]? = reader.read_with_context(
                  dummy_ctx,
                )
                if stream is Some(stream) {
                  let stream = stream.get()
                  let ok = if stream.decoded() is Ok(data) &&
                    ObjectStream::new(stream, data, dummy_ctx)
                    is Some(object_stream) &&
                    (object_stream.get(idx) : Dict?) is Some(obj) {
                    check(obj)
                  } else {
                    false
                  }
                  if ok {
                    trailer_dict = Some(dict)
                  }
                }
              }
            _ => ()
          }
        NotRef(d) => if check(d) { trailer_dict = Some(dict) }
      }
    }
  }
  let has_encryption = match trailer_dict {
    Some(t) => t.contains_key("Encrypt")
    None => false
  }
  if has_encryption && recurse {
    // The problem is that in this case, we have used a dummy reader context which does not have
    // a decryptor. Therefore, we were unable to decrypt any of the object streams and missed
    // all objects that are inside of such a stream. Therefore, we need to redo the process
    // using a `ReaderContext` that does have the ability to decrypt.
    if XRef::new(
        data,
        xref_map.copy(),
        TrailerDictData(trailer_dict.unwrap().data()),
        true,
        password,
      )
      is Ok(xref) {
      let ctx = ReaderContext::new(xref, false)
      let (patched_map, _) = fallback_xref_map_inner(data, ctx, false, password)
      xref_map = patched_map
    }
  }
  if trailer_dict is Some(trailer_dict) {
    (xref_map, Some(TrailerDictData(trailer_dict.data())))
  } else if root_ref is Some(root_ref) {
    (xref_map, Some(RootRef(root_ref)))
  } else {
    (xref_map, None)
  }
}

///|
/// An xref table.
pub struct XRef {
  priv inner : SomeRepr?
}

///|
priv struct SomeRepr {
  /// The data of the PDF.
  data : Bytes
  /// Decoded object streams (upstream `Data`).
  decoded : Map[ObjectIdentifier, BytesView?]
  mut xref_map : Map[ObjectIdentifier, EntryType]
  mut repaired : Bool
  mut decryptor : Decryptor
  mut has_ocgs : Bool
  password : Bytes
  mut trailer_data : TrailerData
}

///|
let dummy_xref : XRef = { inner: None, }

///|
fn XRef::new(
  data : Bytes,
  xref_map : Map[ObjectIdentifier, EntryType],
  input : XRefInput,
  repaired : Bool,
  password : Bytes,
) -> Result[XRef, XRefError] {
  // This is a bit hacky, but the problem is we can't read the resolved trailer dictionary
  // before we actually created the xref struct. So we first create it using dummy data
  // and then populate the data.
  let repr : SomeRepr = {
    data,
    decoded: Map([]),
    xref_map,
    repaired,
    decryptor: NoDecryptor,
    has_ocgs: false,
    password,
    trailer_data: TrailerData::dummy(),
  }
  let xref = { inner: Some(repr), }

  // We read the trailer twice, once to determine the encryption used and then a second
  // time to resolve the catalog dictionary, etc. This allows us to support catalog dictionaries
  // that are stored in an encrypted object stream.
  let decryptor : Decryptor = match input {
    TrailerDictData(trailer_dict_data) => {
      let r = Reader::new(trailer_dict_data)
      let trailer_dict : Dict? = r.read_with_context(
        ReaderContext::new(xref, false),
      )
      guard trailer_dict is Some(trailer_dict) else { return Err(Unknown) }
      match get_decryptor(trailer_dict, password) {
        Ok(d) => d
        Err(e) => return Err(e)
      }
    }
    RootRef(_) => NoDecryptor
  }
  repr.decryptor = decryptor
  let (trailer_data, has_ocgs) = match input {
    TrailerDictData(trailer_dict_data) => {
      let r = Reader::new(trailer_dict_data)
      let trailer_dict : Dict? = r.read_with_context(
        ReaderContext::new(xref, false),
      )
      guard trailer_dict is Some(trailer_dict) else { return Err(Unknown) }
      guard trailer_dict.get_ref("Root") is Some(root_ref) else {
        return Err(Unknown)
      }
      let root : Dict? = trailer_dict.get("Root")
      guard root is Some(root) else { return Err(Unknown) }
      guard root.get_ref("Pages") is Some(pages_ref) else {
        return Err(Unknown)
      }
      let has_ocgs = (root.get("OCProperties") : Dict?) is Some(_)
      let version = match (root.get("Version") : Name?) {
        Some(v) => PdfVersion::from_bytes(v.as_bytes()[:])
        None => None
      }
      let td : TrailerData = {
        pages_ref: pages_ref.to_id(),
        root_ref: root_ref.to_id(),
        version,
      }
      (td, has_ocgs)
    }
    RootRef(root_ref) => {
      let root : Dict? = xref.get(root_ref)
      guard root is Some(root) else { return Err(Unknown) }
      guard root.get_ref("Pages") is Some(pages_ref) else {
        return Err(Unknown)
      }
      let td : TrailerData = {
        pages_ref: pages_ref.to_id(),
        root_ref,
        version: None,
      }
      (td, false)
    }
  }
  repr.trailer_data = trailer_data
  repr.has_ocgs = has_ocgs
  Ok(xref)
}

///|
fn XRef::is_repaired(self : XRef) -> Bool {
  match self.inner {
    None => false
    Some(r) => r.repaired
  }
}

///|
pub fn XRef::dummy() -> XRef {
  dummy_xref
}

///|
/// The number of entries in the xref table.
pub fn XRef::len(self : XRef) -> Int {
  match self.inner {
    None => 0
    Some(r) => r.xref_map.length()
  }
}

///|
fn XRef::trailer_data(self : XRef) -> TrailerData {
  match self.inner {
    None => abort("dummy xref has no trailer data")
    Some(r) => r.trailer_data
  }
}

///|
/// Return the object ID of the root dictionary.
pub fn XRef::root_id(self : XRef) -> ObjectIdentifier {
  self.trailer_data().root_ref
}

///|
/// Whether the PDF has optional content groups.
pub fn XRef::has_optional_content_groups(self : XRef) -> Bool {
  match self.inner {
    None => false
    Some(r) => r.has_ocgs
  }
}

///|
/// All objects of the file, in the order they appear in the file.
pub fn XRef::objects(self : XRef) -> Array[Object] {
  guard self.inner is Some(r) else { abort("unimplemented") }
  let elements = []
  for id, e in r.xref_map {
    let offset = match e {
      Normal(o) => (o.to_int64(), 0)
      ObjStream(id, index) =>
        match
          r.xref_map.get(ObjectIdentifier::new(id.reinterpret_as_int(), 0)) {
          Some(Normal(offset)) =>
            (offset.to_int64(), index.reinterpret_as_int())
          _ => (@int64.MAX_VALUE, 0)
        }
    }
    elements.push((id, offset))
  }
  // Try to yield in the order the objects appeared in the PDF.
  let indexed = elements.mapi((i, e) => (e, i))
  indexed.sort_by((a, b) => {
    let c = a.0.1.compare(b.0.1)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  let out = []
  for e in indexed {
    let obj : Object? = self.get_with(e.0.0, ReaderContext::new(self, false))
    if obj is Some(obj) {
      out.push(obj)
    }
  }
  out
}

///|
fn XRef::repair(self : XRef) -> Unit {
  guard self.inner is Some(r) else { abort("unreachable") }
  let (xref_map, _) = fallback_xref_map(r.data, r.password)
  r.xref_map = xref_map
  r.repaired = true
}

///|
pub fn XRef::needs_decryption(self : XRef, ctx : ReaderContext) -> Bool {
  match self.inner {
    None => false
    Some(r) =>
      if r.decryptor is NoDecryptor {
        false
      } else {
        !ctx.in_content_stream() && !ctx.in_object_stream()
      }
  }
}

///|
pub fn XRef::decrypt(
  self : XRef,
  id : ObjectIdentifier,
  data : BytesView,
  target : DecryptionTarget,
) -> Bytes? {
  match self.inner {
    None => Some(data.to_owned())
    Some(r) => r.decryptor.decrypt(id, data, target)
  }
}

///|
/// Return the object with the given identifier.
pub fn[T : ObjectLike] XRef::get(self : XRef, id : ObjectIdentifier) -> T? {
  let ctx = ReaderContext::new(self, false)
  self.get_with(id, ctx)
}

///|
/// Return the object with the given identifier.
pub fn[T : ObjectLike] XRef::get_with(
  self : XRef,
  id : ObjectIdentifier,
  ctx : ReaderContext,
) -> T? {
  guard self.inner is Some(repr) else { return None }
  let r = Reader::new(repr.data[:])
  // An indirect reference to an undefined object shall not be considered an error by a PDF processor; it
  // shall be treated as a reference to the null object.
  guard repr.xref_map.get(id) is Some(entry) else { return None }
  let ctx = ctx.with_obj_number(id).with_in_content_stream(false)
  match entry {
    Normal(offset) => {
      let ctx = ctx.with_in_object_stream(false)
      r.jump(offset)
      let object : IndirectObject[T]? = r.read_with_context(ctx)
      if object is Some(object) {
        if object.id() == id {
          return Some(object.get())
        }
      } else if r.skip(fn(r, _) { skip_indirect(r, Object::skip) }, false)
        is Some(_) {
        // There is a valid object at the offset, it's just not of the type the caller
        // expected, which is fine.
        return None
      }

      // The xref table is broken, try to repair if not already repaired.
      if self.is_repaired() {
        // attempt was made at repairing xref, but object still couldn't be read
        None
      } else {
        // broken xref, attempting to repair
        self.repair()
        // Now try reading again.
        self.get_with(id, ctx)
      }
    }
    ObjStream(obj_stream_num, index) => {
      // Generation number is implicitly 0.
      let obj_stream_id = ObjectIdentifier::new(
        obj_stream_num.reinterpret_as_int(),
        0,
      )
      if obj_stream_id == id {
        // cycle detected in object stream
        return None
      }
      guard (self.get_with(obj_stream_id, ctx) : Stream?) is Some(stream) else {
        return None
      }
      guard self.decoded_object_stream(repr, obj_stream_id, ctx) is Some(data) else {
        return None
      }
      guard ObjectStream::new(stream, data, ctx) is Some(object_stream) else {
        return None
      }
      object_stream.get(index)
    }
  }
}

///|
/// Get access to the data of a decoded object stream (upstream
/// `Data::get_with`).
fn XRef::decoded_object_stream(
  self : XRef,
  repr : SomeRepr,
  id : ObjectIdentifier,
  ctx : ReaderContext,
) -> BytesView? {
  match repr.decoded.get(id) {
    Some(d) => d
    None => {
      let stream : Stream? = self.get_with(id, ctx)
      let decoded = match stream {
        Some(stream) => stream.decoded().to_option().map(d => d.to_owned()[:])
        None => None
      }
      repr.decoded[id] = decoded
      decoded
    }
  }
}

///|
/// An input that is passed to the xref constructor so that we can fully
/// resolve the PDF.
priv enum XRefInput {
  /// This option is going to be uesd in 99.999% of the case. It contains the
  /// raw data of the trailer dictionary which is then going to be processed.
  TrailerDictData(BytesView)
  /// In case the trailer dictionary could not be read (for example because
  /// it is cut-off), we just pass the object ID of the root dictionary
  /// in case we have found one, and try our best to build the PDF just
  /// with the information we have there.
  RootRef(ObjectIdentifier)
}

///|
fn find_last_xref_pos(data : BytesView) -> Int? {
  let needle = b"startxref"
  guard findr_needle(data, needle) is Some(pos) else { return None }
  let finder = Reader::new(data)
  finder.jump(pos)
  guard finder.forward_tag(needle) is Some(_) else { return None }
  finder.skip_white_spaces_and_comments()
  guard (finder.read_without_context() : Int?) is Some(v) else { return None }
  if v >= 0 {
    Some(v)
  } else {
    None
  }
}

///|
/// A type of xref entry.
priv enum EntryType {
  /// An indirect object that is at a specific offset in the original data.
  Normal(Int)
  /// An indirect object that is part of an object stream. First number indicates the object
  /// number of the _object stream_ (the generation number is always 0), the second number indicates
  /// the index in the object stream.
  ObjStream(UInt, UInt)
}

///|
priv struct TrailerData {
  pages_ref : ObjectIdentifier
  root_ref : ObjectIdentifier
  version : PdfVersion?
}

///|
fn TrailerData::dummy() -> TrailerData {
  {
    pages_ref: ObjectIdentifier::new(0, 0),
    root_ref: ObjectIdentifier::new(0, 0),
    version: None,
  }
}

///|
fn parse_u32_digits(data : BytesView) -> UInt? {
  let mut accum : UInt64 = 0
  for byte in data {
    accum = accum * 10
    match byte {
      b'0'..=b'9' => accum = accum + (byte.to_int() - 48).to_uint64()
      _ => return None
    }
    if accum > 0xFFFFFFFFUL {
      return None
    }
  }
  Some(accum.to_uint())
}

///|
fn populate_xref_impl(
  data : BytesView,
  pos : Int,
  xref_map : Map[ObjectIdentifier, EntryType],
) -> BytesView? {
  let visited = @hashset.HashSet([])
  populate_xref_impl_inner(data, pos, xref_map, visited)
}

///|
/// Maximum number of allowed xref `Prev` pointers before we abort.
const MAX_XREF_CHAIN_DEPTH : Int = 256

///|
fn populate_xref_impl_inner(
  data : BytesView,
  pos : Int,
  xref_map : Map[ObjectIdentifier, EntryType],
  visited : @hashset.HashSet[Int],
) -> BytesView? {
  if visited.contains(pos) {
    // circular xref PREV chain detected
    return None
  }
  visited.add(pos)
  if visited.length() > MAX_XREF_CHAIN_DEPTH {
    // xref PREV chain exceeds maximum depth
    return None
  }
  let reader = Reader::new(data)
  reader.jump(pos)
  // In case the position points to before the object number of a xref stream.
  reader.skip_white_spaces_and_comments()
  let r2 = reader.clone()
  let id : ObjectIdentifier? = reader.clone().read_without_context()
  if id is Some(_) {
    populate_from_xref_stream(data, r2, xref_map, visited)
  } else {
    populate_from_xref_table(data, r2, xref_map, visited)
  }
}

///|
fn read_subsection_header(r : Reader) -> (UInt, UInt)? {
  let old = r.offset()
  let res = (fn() -> (UInt, UInt)? {
    r.skip_white_spaces()
    guard (r.read_without_context() : UInt?) is Some(start) else { return None }
    r.skip_white_spaces()
    guard (r.read_without_context() : UInt?) is Some(num_entries) else {
      return None
    }
    r.skip_white_spaces()
    Some((start, num_entries))
  })()
  if res is None {
    r.jump(old)
  }
  res
}

///|
/// Populate the xref table, and return the trailer dict.
fn populate_from_xref_table(
  data : BytesView,
  reader : Reader,
  insert_map : Map[ObjectIdentifier, EntryType],
  visited : @hashset.HashSet[Int],
) -> BytesView? {
  guard read_xref_table_trailer(reader.clone(), ReaderContext::dummy())
    is Some(trailer) else {
    return None
  }
  reader.skip_white_spaces()
  guard reader.forward_tag(b"xref") is Some(_) else { return None }
  reader.skip_white_spaces()
  let prev : Int? = trailer.get("Prev")
  if prev is Some(prev) {
    // First insert the entries from any previous xref tables.
    guard populate_xref_impl_inner(data, prev, insert_map, visited) is Some(_) else {
      return None
    }
  }

  // In hybrid files, entries in `XRefStm` should have higher priority, therefore we insert them
  // after looking at `PREV`.
  let xref_stm : Int? = trailer.get("XRefStm")
  if xref_stm is Some(xref_stm) {
    guard populate_xref_impl_inner(data, xref_stm, insert_map, visited)
      is Some(_) else {
      return None
    }
  }
  while read_subsection_header(reader) is Some((start, num_entries)) {
    reader.skip_white_spaces()
    let start = start.to_uint64()
    let end = start + num_entries.to_uint64()
    if end > 0xFFFFFFFFUL {
      return None
    }
    let mut obj_number = start
    while obj_number < end {
      guard reader.read_bytes(XREF_ENTRY_LEN) is Some(bytes) else {
        return None
      }
      guard parse_u32_digits(bytes[0:10]) is Some(offset) else { return None }
      guard parse_u32_digits(bytes[11:16]) is Some(gen_number) else {
        return None
      }
      if gen_number > 0x7FFFFFFFU {
        return None
      }
      let used = bytes[17] == b'n'

      // Specification says we should ignore any object number > SIZE, but probably
      // not important?
      if used {
        let id = ObjectIdentifier::new(
          obj_number.to_int(),
          gen_number.reinterpret_as_int(),
        )
        insert_map[id] = Normal(offset.reinterpret_as_int())
      }
      obj_number += 1
    }
  }
  Some(trailer.data())
}

///|
fn populate_from_xref_stream(
  data : BytesView,
  reader : Reader,
  insert_map : Map[ObjectIdentifier, EntryType],
  visited : @hashset.HashSet[Int],
) -> BytesView? {
  guard (
      reader.read_with_context(ReaderContext::dummy()) : IndirectObject[Stream]?)
    is Some(stream) else {
    return None
  }
  let stream = stream.get()
  let prev : Int? = stream.dict().get("Prev")
  if prev is Some(prev) {
    // First insert the entries from any previous xref tables.
    guard populate_xref_impl_inner(data, prev, insert_map, visited) is Some(_) else {
      return None
    }
  }
  guard (stream.dict().get("Size") : UInt?) is Some(size) else { return None }
  guard (stream.dict().get_fixed("W", 3) : Array[Byte]?) is Some(w) else {
    return None
  }
  let f1_len = w[0].to_int()
  let f2_len = w[1].to_int()
  let f3_len = w[2].to_int()
  if f2_len > 8 {
    // xref offset length is larger than the allowed limit
    return None
  }
  guard stream.decoded().to_option() is Some(xref_data) else { return None }
  let xref_reader = Reader::new(xref_data)
  let index : PdfArray? = stream.dict().get("Index")
  if index is Some(arr) {
    let iter = arr.flex_iter()
    while true {
      let start : UInt? = iter.next()
      guard start is Some(start) else { break }
      let num_elements : UInt? = iter.next()
      guard num_elements is Some(num_elements) else { break }
      guard xref_stream_subsection(
          xref_reader, start, num_elements, f1_len, f2_len, f3_len, insert_map,
        )
        is Some(_) else {
        return None
      }
    }
  } else {
    guard xref_stream_subsection(
        xref_reader, 0, size, f1_len, f2_len, f3_len, insert_map,
      )
      is Some(_) else {
      return None
    }
  }
  Some(stream.dict().data())
}

///|
fn xref_stream_num(data : BytesView) -> UInt? {
  match data.length() {
    0 => None
    1 => Some(data[0].to_uint())
    2 => Some((data[0].to_uint() << 8) | data[1].to_uint())
    3 =>
      Some(
        (data[0].to_uint() << 16) | (data[1].to_uint() << 8) | data[2].to_uint(),
      )
    4 =>
      Some(
        (data[0].to_uint() << 24) |
        (data[1].to_uint() << 16) |
        (data[2].to_uint() << 8) |
        data[3].to_uint(),
      )
    8 => {
      let mut v : UInt64 = 0
      for b in data {
        v = (v << 8) | b.to_uint64()
      }
      if v <= 0xFFFFFFFFUL {
        Some(v.to_uint())
      } else {
        // xref stream number is too large
        None
      }
    }
    _ =>
      // invalid xref stream number
      None
  }
}

///|
fn xref_stream_subsection(
  xref_reader : Reader,
  start : UInt,
  num_elements : UInt,
  f1_len : Int,
  f2_len : Int,
  f3_len : Int,
  insert_map : Map[ObjectIdentifier, EntryType],
) -> Unit? {
  let mut i : UInt = 0
  while i < num_elements {
    let f_type = if f1_len == 0 {
      1
    } else {
      // We assume a length of 1.
      guard xref_reader.read_bytes(1) is Some(b) else { return None }
      b[0].to_int()
    }
    let obj_number = (start + i).reinterpret_as_int()
    match f_type {
      // We don't care about free objects.
      0 => if xref_reader.skip_bytes(f2_len + f3_len) is None { return None }
      1 => {
        let offset = if f2_len > 0 {
          guard xref_reader.read_bytes(f2_len) is Some(d) else { return None }
          guard xref_stream_num(d) is Some(v) else { return None }
          v
        } else {
          0
        }
        let gen_number = if f3_len > 0 {
          guard xref_reader.read_bytes(f3_len) is Some(d) else { return None }
          guard xref_stream_num(d) is Some(v) else { return None }
          v
        } else {
          0
        }
        let id = ObjectIdentifier::new(
          obj_number,
          gen_number.reinterpret_as_int(),
        )
        insert_map[id] = Normal(offset.reinterpret_as_int())
      }
      2 => {
        guard xref_reader.read_bytes(f2_len) is Some(d) else { return None }
        guard xref_stream_num(d) is Some(obj_stream_number) else { return None }
        let index = if f3_len > 0 {
          guard xref_reader.read_bytes(f3_len) is Some(d) else { return None }
          guard xref_stream_num(d) is Some(v) else { return None }
          v
        } else {
          0
        }
        insert_map[ObjectIdentifier::new(obj_number, 0)] = ObjStream(
          obj_stream_number, index,
        )
      }
      _ =>
        // xref has unknown field type
        return None
    }
    i += 1
  }
  Some(())
}

///|
fn read_xref_table_trailer(reader : Reader, ctx : ReaderContext) -> Dict? {
  reader.skip_white_spaces()
  guard reader.forward_tag(b"xref") is Some(_) else { return None }
  reader.skip_white_spaces()
  while read_subsection_header(reader) is Some((_, num_entries)) {
    let len = XREF_ENTRY_LEN.to_int64() * num_entries.to_int64()
    let target = reader.offset().to_int64() + len
    if target > 0x7FFFFFFFL {
      return None
    }
    reader.jump(target.to_int())
  }
  reader.skip_white_spaces()
  guard reader.forward_tag(b"trailer") is Some(_) else { return None }
  reader.skip_white_spaces()
  reader.read_with_context(ctx)
}

///|
fn get_decryptor(
  trailer_dict : Dict,
  password : Bytes,
) -> Result[Decryptor, XRefError] {
  let encryption_dict : Dict? = trailer_dict.get("Encrypt")
  if encryption_dict is Some(encryption_dict) {
    let id_arr : PdfArray? = trailer_dict.get("ID")
    let id = match id_arr {
      Some(a) =>
        match (a.flex_iter().next() : PdfString?) {
          Some(id) => id.as_bytes()
          // Assume an empty ID entry.
          None => b""
        }
      None => b""
    }
    match get_crypt_decryptor(encryption_dict, id, password) {
      Ok(d) => Ok(d)
      Err(e) => Err(Encryption(e))
    }
  } else {
    Ok(NoDecryptor)
  }
}

///|
priv struct ObjectStream {
  data : BytesView
  ctx : ReaderContext
  offsets : Array[(UInt, Int)]
}

///|
fn ObjectStream::new(
  inner : Stream,
  data : BytesView,
  ctx : ReaderContext,
) -> ObjectStream? {
  guard (inner.dict().get("N") : UInt64?) is Some(num_objects) else {
    return None
  }
  guard (inner.dict().get("First") : UInt64?) is Some(first_offset) else {
    return None
  }
  let r = Reader::new(data)
  let offsets = []
  let mut n = 0UL
  while n < num_objects {
    r.skip_white_spaces_and_comments()
    // Skip object number
    guard (r.read_without_context() : UInt?) is Some(obj_num) else {
      return None
    }
    r.skip_white_spaces_and_comments()
    guard (r.read_without_context() : UInt64?) is Some(relative_offset) else {
      return None
    }
    offsets.push((obj_num, (first_offset + relative_offset).to_int()))
    n += 1
  }
  let ctx = ctx.with_in_object_stream(true)
  Some({ data, ctx, offsets, })
}

///|
fn[T : ObjectLike] ObjectStream::get(self : ObjectStream, index : UInt) -> T? {
  let index = index.reinterpret_as_int()
  if index < 0 || index >= self.offsets.length() {
    return None
  }
  let offset = self.offsets[index].1
  let r = Reader::new(self.data)
  r.jump(offset)
  r.skip_white_spaces_and_comments()
  r.read_with_context(self.ctx)
}
