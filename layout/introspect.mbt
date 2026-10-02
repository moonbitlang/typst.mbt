// Port of `typst-layout/src/introspect.rs`.

///|
/// An introspector implementation for paged documents.
pub struct PagedIntrospector {
  /// The underlying target-agnostic introspector used for most queries.
  priv elements : @library.ElementIntrospector[@library.PagedPosition]
  /// Locations that are linked to via `FrameItem::Link`.
  priv frame_link_targets : @hashset.HashSet[@library.Location]
  /// The number of pages in the document.
  priv pages : Int
  /// The page numberings, indexed by page number minus 1.
  priv page_numberings : Array[@library.Numbering?]
  /// The page supplements, indexed by page number minus 1.
  priv page_supplements : Array[@library.Content]
}

///|
/// Creates an introspector for a paged document.
pub fn PagedIntrospector::new(pages : ArrayView[Page]) -> PagedIntrospector {
  let builder = PagedIntrospectorBuilder::new()
  let page_numberings = []
  let page_supplements = []

  // Discover all elements.
  for i, page in pages {
    let nr = @library.NonZeroUSize((1 + i).to_int64())
    page_numberings.push(page.numbering)
    page_supplements.push(page.supplement)
    builder.discover_frame(page.frame, @library.Transform::identity(), point => {
      page: nr,
      point,
    })
  }
  builder.finish(
    if pages.length() > 0 {
      pages.length()
    } else {
      1
    },
    page_numberings,
    page_supplements,
  )
}

///|
/// Resolves the position of the location in the pages.
pub fn PagedIntrospector::position(
  self : PagedIntrospector,
  location : @library.Location,
) -> @library.PagedPosition? {
  self.elements.position(location)
}

///|
/// The underlying element introspector.
pub fn PagedIntrospector::elements(
  self : PagedIntrospector,
) -> @library.ElementIntrospector[@library.PagedPosition] {
  self.elements
}

///|
/// Returns the locations that the paged document links to via
/// `FrameItem::Link`.
pub fn PagedIntrospector::frame_link_targets(
  self : PagedIntrospector,
) -> @hashset.HashSet[@library.Location] {
  self.frame_link_targets
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn query(
  self,
  selector,
) {
  self.elements.query(selector)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn query_first(
  self,
  selector,
) {
  self.elements.query_first(selector)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn query_unique(
  self,
  selector,
) {
  self.elements.query_unique(selector)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn query_label(
  self,
  label,
) {
  self.elements.query_label(label)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn query_labelled(
  self,
) {
  self.elements.query_labelled()
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn query_count_before(
  self,
  selector,
  end,
) {
  self.elements.query_count_before(selector, end)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn label_count(
  self,
  label,
) {
  self.elements.label_count(label)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn locator(
  self,
  key,
  base,
) {
  self.elements.locator(key, base)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn pages(
  self,
  _,
) {
  Some(@library.NonZeroUSize(self.pages.to_int64()))
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn page(
  self,
  location,
) {
  self.elements.position(location).map(pos => pos.page)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn position(
  self,
  location,
) {
  self.elements.position(location).map(p => @library.DocumentPosition::Paged(p))
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn page_numbering(
  self,
  location,
) {
  let page = @library.IntrospectorBackend::page(self, location)
  guard page is Some(page) else { return None }
  match self.page_numberings.get(page.0.to_int() - 1) {
    Some(numbering) => numbering
    None => None
  }
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn page_supplement(
  self,
  location,
) {
  let page = @library.IntrospectorBackend::page(self, location)
  guard page is Some(page) else { return None }
  self.page_supplements.get(page.0.to_int() - 1)
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn anchor(_, _) {
  None
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn document(
  _,
  _,
) {
  None
}

///|
pub impl @library.IntrospectorBackend for PagedIntrospector with fn path(_, _) {
  None
}

///|
/// Upstream `Debug for PagedIntrospector`.
pub impl Show for PagedIntrospector with fn output(_, logger) {
  logger.write_string("PagedIntrospector(..)")
}

///|
/// Builds the introspector.
priv struct PagedIntrospectorBuilder {
  elements : @library.ElementIntrospectorBuilder[@library.PagedPosition]
  frame_link_targets : @hashset.HashSet[@library.Location]
}

///|
fn PagedIntrospectorBuilder::new() -> PagedIntrospectorBuilder {
  {
    elements: @library.ElementIntrospectorBuilder::new(),
    frame_link_targets: @hashset.HashSet::new(),
  }
}

///|
/// Build a complete introspector with all acceleration structures from a
/// list of top-level pairs.
fn PagedIntrospectorBuilder::finish(
  self : PagedIntrospectorBuilder,
  pages : Int,
  page_numberings : Array[@library.Numbering?],
  page_supplements : Array[@library.Content],
) -> PagedIntrospector {
  {
    elements: self.elements.finalize(),
    frame_link_targets: self.frame_link_targets,
    pages,
    page_numberings,
    page_supplements,
  }
}

///|
/// Discovers introspectibles in a frame.
fn PagedIntrospectorBuilder::discover_frame(
  self : PagedIntrospectorBuilder,
  frame : @library.Frame,
  ts : @library.Transform,
  to_pos : (@library.Point) -> @library.PagedPosition,
) -> Unit {
  for entry in frame.items() {
    let (pos, item) = entry
    match item {
      Tag(tag) => self.elements.discover_tag(tag, to_pos(pos.transform(ts)))
      Group(group) => {
        let ts = ts
          .pre_concat(@library.Transform::translate(pos.x, pos.y))
          .pre_concat(group.transform)
        if group.parent is Some(parent) {
          self.elements.start_insertion()
          self.discover_frame(group.frame, ts, to_pos)
          self.elements.end_insertion(parent.location)
        } else {
          self.discover_frame(group.frame, ts, to_pos)
        }
      }
      Link(dest, _) =>
        if dest is Location(loc) {
          self.frame_link_targets.add(loc)
        }
      Text(_) | Shape(_, _) | Image(_, _, _) => ()
    }
  }
}
