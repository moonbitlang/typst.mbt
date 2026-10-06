// Port of `typst-bundle/src/introspect.rs`.

///|
/// An introspector implementation for bundles.
pub struct BundleIntrospector {
  /// The paths of and introspectors for all bundle documents. Does not
  /// include assets.
  priv children : Array[
    (@syntax.VirtualPath, ChildIntrospector, @library.Location),
  ]
  /// The underlying target-agnostic introspector used for most queries.
  /// The positions are indices into `children` (upstream: off-by-one
  /// `NonZeroUsize` indices).
  priv elements : @library.ElementIntrospector[Int?]
  /// Maps from element locations to assigned link anchors. This is used to
  /// support intra-doc links. Link anchors are local to the relevant
  /// document.
  priv mut anchors : Map[@library.Location, String]
}

///|
/// Creates an introspector for a bundle.
fn BundleIntrospector::new(items : Array[Item]) -> BundleIntrospector {
  let builder = BundleIntrospectorBuilder::new()
  for item in items {
    builder.discover_item(item)
  }
  builder.finish()
}

///|
/// Computes all locations that are referenced by intra-doc links of any kind
/// and returns them organized by the document they are in.
pub fn BundleIntrospector::link_targets(
  self : BundleIntrospector,
) -> Map[@syntax.VirtualPath, @hashset.HashSet[@library.Location]] {
  let map : Map[@syntax.VirtualPath, @hashset.HashSet[@library.Location]] = Map([],
  )
  let targets = @library.LinkElem::find_destinations(self)
  for child in self.children {
    for target in child.1.frame_link_targets() {
      targets.push(target)
    }
  }
  for target in targets {
    guard @library.IntrospectorBackend::path(self, target) is Some(path) else {
      continue
    }
    match map.get(path) {
      Some(set) => set.add(target)
      None => {
        let set = @hashset.HashSet([])
        set.add(target)
        map[path] = set
      }
    }
  }
  map
}

///|
/// Enriches an existing introspector with HTML link anchors, which were
/// assigned to the DOM in a post-processing step.
pub fn BundleIntrospector::set_anchors(
  self : BundleIntrospector,
  anchors : Map[@library.Location, String],
) -> Unit {
  self.anchors = anchors
}

///|
/// Retrieves the child introspector for the given location.
///
/// Returns `None` if the location is not within a document.
fn BundleIntrospector::child(
  self : BundleIntrospector,
  location : @library.Location,
) -> &@library.IntrospectorBackend? {
  guard self.elements.position(location) is Some(Some(index)) else {
    return None
  }
  Some(self.children[index].1.backend())
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn query(
  self,
  selector,
) {
  self.elements.query(selector)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn query_first(
  self,
  selector,
) {
  self.elements.query_first(selector)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn query_unique(
  self,
  selector,
) {
  self.elements.query_unique(selector)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn query_label(
  self,
  label,
) {
  self.elements.query_label(label)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn query_labelled(
  self,
) {
  self.elements.query_labelled()
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn query_count_before(
  self,
  selector,
  end,
) {
  self.elements.query_count_before(selector, end)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn label_count(
  self,
  label,
) {
  self.elements.label_count(label)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn locator(
  self,
  key,
  base,
) {
  self.elements.locator(key, base)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn pages(
  self,
  location,
) {
  guard self.child(location) is Some(child) else { return None }
  child.pages(location)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn page(
  self,
  location,
) {
  guard self.child(location) is Some(child) else { return None }
  child.page(location)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn position(
  self,
  location,
) {
  guard self.child(location) is Some(child) else { return None }
  child.position(location)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn page_numbering(
  self,
  location,
) {
  guard self.child(location) is Some(child) else { return None }
  child.page_numbering(location)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn page_supplement(
  self,
  location,
) {
  guard self.child(location) is Some(child) else { return None }
  child.page_supplement(location)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn anchor(
  self,
  location,
) {
  self.anchors.get(location)
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn document(
  self,
  location,
) {
  guard self.elements.position(location) is Some(index) else { return None }
  if index is Some(index) {
    return Some(self.children[index].2)
  }
  guard self.elements.get_by_loc(location) is Some(content) else { return None }
  @library.DocumentElem::of(content).map(doc => doc.pack().location().unwrap())
}

///|
pub impl @library.IntrospectorBackend for BundleIntrospector with fn path(
  self,
  location,
) {
  // Check whether the location is that of an element within one of the
  // bundle documents.
  guard self.elements.position(location) is Some(index) else { return None }
  if index is Some(index) {
    return Some(self.children[index].0)
  }

  // Check whether the location is that of a document or asset itself.
  guard self.elements.get_by_loc(location) is Some(content) else { return None }
  if @library.DocumentElem::of(content) is Some(doc) {
    Some(doc.path().into_inner())
  } else if @library.AssetElem::of(content) is Some(asset) {
    Some(asset.path().into_inner())
  } else {
    None
  }
}

///|
#deprecated("call as `IntrospectorBackend::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BundleIntrospector with @library.IntrospectorBackend::{
  document,
  query_label,
  path,
  query_unique,
  anchor,
  page,
  query_labelled,
  page_supplement,
  query_count_before,
  query,
  page_numbering,
  position,
  query_first,
  label_count,
  locator,
  pages,
}

///|
/// Upstream `Debug for BundleIntrospector`.
pub impl Show for BundleIntrospector with fn output(_, logger) {
  logger.write_string("BundleIntrospector(..)")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BundleIntrospector with Show::{to_string, output}

///|
/// An introspector for a bundle document.
priv enum ChildIntrospector {
  Paged(@layout.PagedIntrospector)
  Html(@html.HtmlIntrospector)
}

///|
/// Returns the locations that the underlying document links to via
/// `FrameItem::Link`.
fn ChildIntrospector::frame_link_targets(
  self : ChildIntrospector,
) -> @hashset.HashSet[@library.Location] {
  match self {
    Paged(introspector) => introspector.frame_link_targets()
    Html(introspector) => introspector.frame_link_targets()
  }
}

///|
/// The underlying introspector (upstream `Deref for ChildIntrospector`).
fn ChildIntrospector::backend(
  self : ChildIntrospector,
) -> &@library.IntrospectorBackend {
  match self {
    Paged(introspector) => introspector as &@library.IntrospectorBackend
    Html(introspector) => introspector as &@library.IntrospectorBackend
  }
}

///|
/// Constructs the [BundleIntrospector].
priv struct BundleIntrospectorBuilder {
  subdocuments : Array[
    (@syntax.VirtualPath, ChildIntrospector, @library.Location),
  ]
  elements : @library.ElementIntrospectorBuilder[Int?]
}

///|
fn BundleIntrospectorBuilder::new() -> BundleIntrospectorBuilder {
  { subdocuments: [], elements: @library.ElementIntrospectorBuilder::new(), }
}

///|
/// Returns the resulting introspector.
fn BundleIntrospectorBuilder::finish(
  self : BundleIntrospectorBuilder,
) -> BundleIntrospector {
  {
    children: self.subdocuments,
    elements: self.elements.finalize(),
    anchors: {},
  }
}

///|
/// Discovers introspectibles in a bundle item.
fn BundleIntrospectorBuilder::discover_item(
  self : BundleIntrospectorBuilder,
  item : Item,
) -> Unit {
  match item {
    Tag(tag) => self.elements.discover_tag(tag, None)
    Asset(_, _, _) => ()
    Document(path, doc, loc) => self.discover_document(path, doc, loc)
  }
}

///|
/// Discovers introspectibles in a bundle document.
fn BundleIntrospectorBuilder::discover_document(
  self : BundleIntrospectorBuilder,
  path : @syntax.VirtualPath,
  doc : BundleDocument,
  loc : @library.Location,
) -> Unit {
  let pos = Some(self.subdocuments.length())
  let subintrospector = match doc {
    Paged(doc, _) => {
      let introspector = doc.paged_introspector()
      self.elements.discover_elements(introspector.elements(), _ => pos)
      ChildIntrospector::Paged(introspector)
    }
    Html(doc) => {
      let introspector = doc.introspector()
      self.elements.discover_elements(introspector.elements(), _ => pos)
      ChildIntrospector::Html(introspector)
    }
  }
  self.subdocuments.push((path, subintrospector, loc))
}
