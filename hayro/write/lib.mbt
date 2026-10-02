// Port of `hayro-write` 0.7.0 (`lib.rs`): converting PDF pages into either
// XObjects or new pages.
//
// Objects are written as pdflite `Indirect`s through the `put` callback
// (upstream writes a pdf-writer `Chunk`), with references allocated by
// `new_ref`.

///|
/// A type of extraction query, indicating as what kind of object you want to
/// extract the page.
pub(all) enum ExtractionQueryType {
  /// Extract the page as an `XObject`.
  XObject
  /// Extract the page as a new page.
  Page
} derive(Eq, Debug)

///|
/// An extraction query.
pub(all) struct ExtractionQuery {
  query_type : ExtractionQueryType
  page_index : Int
} derive(Eq, Debug)

///|
/// Create a new page extraction query with the given page index.
pub fn ExtractionQuery::new_page(page_index : Int) -> ExtractionQuery {
  { query_type: Page, page_index, }
}

///|
/// Create a new `XObject` extraction query with the given page index.
pub fn ExtractionQuery::new_xobject(page_index : Int) -> ExtractionQuery {
  { query_type: XObject, page_index, }
}

///|
/// An error that occurred during page extraction.
pub(all) enum ExtractionError {
  /// An invalid page index was given.
  InvalidPageIndex(Int)
} derive(Eq, Debug)

///|
/// The result of an extraction.
pub(all) struct ExtractionResult {
  /// The root references of the pages/XObject, one for each extraction query.
  root_refs : Array[Result[Int, ExtractionError]]
  /// The reference to the page tree parent that was generated.
  page_tree_parent_ref : Int
}

///|
/// The state of an extraction. Upstream creates one per `extract` call; it
/// can also be kept to extract further pages of the same document later
/// (sharing the already written objects).
pub struct ExtractionContext {
  priv pdf : @hayro_syntax.Pdf
  priv new_ref_fn : () -> Int
  priv put_fn : (Int, @export.Indirect) -> Unit
  priv visited_objects : Map[@hayro_syntax.ObjRef, Unit]
  priv to_visit_refs : Array[@hayro_syntax.ObjRef]
  priv valid_ref_cache : Map[@hayro_syntax.ObjRef, Bool]
  priv ref_map : Map[@hayro_syntax.ObjRef, Int]
  priv cached_content_streams : Map[Int, Int]
  /// The reference of the page tree parent of extracted pages.
  page_tree_parent_ref : Int
}

///|
///
/// If `page_tree_parent_ref` is given, it is used as the parent of extracted
/// pages (upstream allocates one, which krilla remaps to its page tree).
pub fn ExtractionContext::new(
  pdf : @hayro_syntax.Pdf,
  new_ref : () -> Int,
  put : (Int, @export.Indirect) -> Unit,
  page_tree_parent_ref? : Int,
) -> ExtractionContext {
  let page_tree_parent_ref = match page_tree_parent_ref {
    Some(r) => r
    None => new_ref()
  }
  {
    pdf,
    new_ref_fn: new_ref,
    put_fn: put,
    visited_objects: {},
    to_visit_refs: [],
    valid_ref_cache: {},
    ref_map: {},
    cached_content_streams: {},
    page_tree_parent_ref,
  }
}

///|
fn ExtractionContext::map_ref(
  self : ExtractionContext,
  ref_ : @hayro_syntax.ObjRef,
) -> Int {
  match self.ref_map.get(ref_) {
    Some(r) => r
    None => {
      let new_ref = self.new_ref()
      self.ref_map[ref_] = new_ref
      new_ref
    }
  }
}

///|
fn ExtractionContext::new_ref(self : ExtractionContext) -> Int {
  (self.new_ref_fn)()
}

///|
/// Apply the extraction queries to the given PDF and return the results.
pub fn extract(
  pdf : @hayro_syntax.Pdf,
  new_ref : () -> Int,
  put : (Int, @export.Indirect) -> Unit,
  queries : Array[ExtractionQuery],
) -> Result[ExtractionResult, ExtractionError] {
  let ctx = ExtractionContext::new(pdf, new_ref, put)
  let root_refs = []
  for query in queries {
    match ctx.extract_query(query) {
      Ok(r) => root_refs.push(Ok(r))
      Err(e) => return Err(e)
    }
  }

  // Now we have shallowly extracted all pages, now go through all dependencies until there aren't
  // any anymore.
  ctx.write_dependencies()
  Ok({ root_refs, page_tree_parent_ref: ctx.page_tree_parent_ref, })
}

///|
/// Shallowly extract one page (without its dependencies, see
/// `write_dependencies`) and return its root reference.
pub fn ExtractionContext::extract_query(
  self : ExtractionContext,
  query : ExtractionQuery,
) -> Result[Int, ExtractionError] {
  let pages = self.pdf.pages()
  guard pages.get(query.page_index) is Some(_) else {
    return Err(InvalidPageIndex(query.page_index))
  }
  let root_ref = self.new_ref()
  self.extract_query_into(query, root_ref).map(_ => root_ref)
}

///|
/// Shallowly extract one page as the object `root_ref` (krilla remaps the
/// root references of an extraction to its own references; here they are
/// written directly).
pub fn ExtractionContext::extract_query_into(
  self : ExtractionContext,
  query : ExtractionQuery,
  root_ref : Int,
) -> Result[Unit, ExtractionError] {
  let pages = self.pdf.pages()
  guard pages.get(query.page_index) is Some(page) else {
    return Err(InvalidPageIndex(query.page_index))
  }
  match query.query_type {
    XObject => write_xobject(page, root_ref, self)
    Page => write_page(page, root_ref, query.page_index, self)
  }
  Ok(())
}

///|
/// Write all objects the extracted pages depend on.
pub fn ExtractionContext::write_dependencies(self : ExtractionContext) -> Unit {
  while self.to_visit_refs.pop() is Some(ref_) {
    // Don't visit objects twice!
    if self.visited_objects.contains(ref_) {
      continue
    }
    let object : @hayro_syntax.Object? = self.pdf.xref().get(ref_.to_id())
    if object is Some(object) {
      let new_ref = self.map_ref(ref_)
      write_indirect(object, new_ref, self)
      self.visited_objects[ref_] = ()
    } else {
      // failed to extract object with ref
      ()
    }
  }
}

///|
fn write_page(
  page : @hayro_syntax.Page,
  page_ref : Int,
  page_idx : Int,
  ctx : ExtractionContext,
) -> Unit {
  // Note: We can cache content stream references, but _not_ the page references themselves.
  // Acrobat for some reason doesn't like duplicate page references in the page tree.
  let stream_ref = match ctx.cached_content_streams.get(page_idx) {
    Some(cached) => cached
    None => {
      let stream_ref = ctx.new_ref()
      let data = match page.page_stream() {
        Some(s) => s
        None => b""[:]
      }
      (ctx.put_fn)(
        stream_ref,
        Stream([("Filter", Name("FlateDecode"))], deflate_encode(data)),
      )
      ctx.cached_content_streams[page_idx] = stream_ref
      stream_ref
    }
  }
  let entries : Array[(String, @export.Obj)] = [("Type", Name("Page"))]
  entries.push(("MediaBox", convert_rect(page.media_box())))
  entries.push(("CropBox", convert_rect(page.crop_box())))
  entries.push(
    (
      "Rotate",
      Int(
        match page.rotation() {
          NoRotation => 0
          Horizontal => 90
          Flipped => 180
          FlippedHorizontal => 270
        },
      ),
    ),
  )
  entries.push(("Parent", Ref(ctx.page_tree_parent_ref)))
  entries.push(("Contents", Ref(stream_ref)))
  let raw_dict = page.raw()
  let group : @hayro_syntax.MaybeRef[@hayro_syntax.Object]? = raw_dict.get_raw(
    "Group",
  )
  if group is Some(group) {
    entries.push(("Group", write_direct_maybe_ref(group, ctx)))
  }
  entries.push(("Resources", serialize_resources(page.resources(), ctx)))
  (ctx.put_fn)(page_ref, Plain(Dict(entries)))
}

///|
fn write_xobject(
  page : @hayro_syntax.Page,
  xobj_ref : Int,
  ctx : ExtractionContext,
) -> Unit {
  let data = match page.page_stream() {
    Some(s) => s
    None => b""[:]
  }
  let encoded_stream = deflate_encode(data)
  let entries : Array[(String, @export.Obj)] = [
    ("Type", Name("XObject")),
    ("Subtype", Name("Form")),
    ("Filter", Name("FlateDecode")),
  ]
  let bbox = page.crop_box()
  let initial_transform = page.initial_transform(false)
  entries.push(
    (
      "BBox",
      Arr([
        f32_obj(bbox.x0),
        f32_obj(bbox.y0),
        f32_obj(bbox.x1),
        f32_obj(bbox.y1),
      ]),
    ),
  )
  let i = initial_transform.as_coeffs()
  entries.push(
    (
      "Matrix",
      Arr([
        f32_obj(i[0]),
        f32_obj(i[1]),
        f32_obj(i[2]),
        f32_obj(i[3]),
        f32_obj(i[4]),
        f32_obj(i[5]),
      ]),
    ),
  )
  entries.push(("Resources", serialize_resources(page.resources(), ctx)))
  let raw_dict = page.raw()
  let group : @hayro_syntax.MaybeRef[@hayro_syntax.Object]? = raw_dict.get_raw(
    "Group",
  )
  if group is Some(group) {
    entries.push(("Group", write_direct_maybe_ref(group, ctx)))
  }
  (ctx.put_fn)(xobj_ref, Stream(entries, encoded_stream))
}

///|
/// A real number written as an `f32` (pdf-writer's `Rect`/matrix entries).
fn f32_obj(v : Double) -> @export.Obj {
  Real(v.to_float().to_double())
}

///|
fn serialize_resources(
  resources : @hayro_syntax.Resources,
  ctx : ExtractionContext,
) -> @export.Obj {
  let ext_g_states = collect_resources(resources, r => r.ext_g_states)
  let shadings = collect_resources(resources, r => r.shadings)
  let patterns = collect_resources(resources, r => r.patterns)
  let x_objects = collect_resources(resources, r => r.x_objects)
  let color_spaces = collect_resources(resources, r => r.color_spaces)
  let fonts = collect_resources(resources, r => r.fonts)
  let properties = collect_resources(resources, r => r.properties)

  // Resource dictionary is always required (unless it can be inherited), so
  // let's just be safe and always write it.
  let entries : Array[(String, @export.Obj)] = []
  let write = (
    map : Array[
      (@hayro_syntax.Name, @hayro_syntax.MaybeRef[@hayro_syntax.Object]),
    ],
    key : String,
  ) => {
    if !map.is_empty() {
      let dict = []
      for entry in map {
        dict.push((entry.0.raw(), write_direct_maybe_ref(entry.1, ctx)))
      }
      entries.push((key, Dict(dict)))
    }
  }
  write(ext_g_states, "ExtGState")
  write(shadings, "Shading")
  write(patterns, "Pattern")
  write(x_objects, "XObject")
  write(color_spaces, "ColorSpace")
  write(fonts, "Font")
  write(properties, "Properties")
  Dict(entries)
}

///|
/// Collect the entries of a resource dictionary along the parent chain,
/// sorted by name (upstream `BTreeMap`).
fn collect_resources(
  resources : @hayro_syntax.Resources,
  get_dict : (@hayro_syntax.Resources) -> @hayro_syntax.Dict,
) -> Array[(@hayro_syntax.Name, @hayro_syntax.MaybeRef[@hayro_syntax.Object])] {
  let map : Map[String, @hayro_syntax.MaybeRef[@hayro_syntax.Object]] = {}
  collect_resources_inner(resources, get_dict, map)
  let keys = map.keys().collect()
  keys.sort_by(@hayro_syntax.compare_latin1)
  keys.map(k => (@hayro_syntax.Name::from_string(k), map[k]))
}

///|
fn collect_resources_inner(
  resources : @hayro_syntax.Resources,
  get_dict : (@hayro_syntax.Resources) -> @hayro_syntax.Dict,
  map : Map[String, @hayro_syntax.MaybeRef[@hayro_syntax.Object]],
) -> Unit {
  // Process parents first, so that duplicates get overridden by the current dictionary.
  // Since for inheritance, the current dictionary always has priority over entries in the
  // parent dictionary.
  if resources.parent() is Some(parent) {
    collect_resources_inner(parent, get_dict, map)
  }
  let dict = get_dict(resources)
  for entry in dict.entries() {
    map[entry.0.raw()] = entry.1
  }
}

///|
fn deflate_encode(data : BytesView) -> Bytes {
  let c = @codecs.Compressor::new()
  c.write_data(data)
  c.finish()
}

///|
fn convert_rect(r : @hayro_syntax.Rect) -> @export.Obj {
  Arr([f32_obj(r.x0), f32_obj(r.y0), f32_obj(r.x1), f32_obj(r.y1)])
}
