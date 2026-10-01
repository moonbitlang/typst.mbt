// Port of `typst-html/src/introspect.rs`.

///|
/// An introspector implementation for HTML documents.
pub struct HtmlIntrospector {
  /// The underlying target-agnostic introspector used for most queries.
  priv elements : @library.ElementIntrospector[@library.HtmlPosition]
  /// Locations that are linked to via `FrameItem::Link`.
  priv frame_link_targets : @hashset.HashSet[@library.Location]
  /// Maps from element locations to assigned HTML link anchors. This is used
  /// to support intra-doc links.
  priv mut anchors : Map[@library.Location, String]
}

///|
/// Creates an introspector for an HTML document.
pub fn HtmlIntrospector::new(output : ArrayView[HtmlNode]) -> HtmlIntrospector {
  let builder = HtmlIntrospectorBuilder::new()
  builder.discover_nodes(output, [])
  builder.finish()
}

///|
/// The underlying element introspector.
pub fn HtmlIntrospector::elements(
  self : HtmlIntrospector,
) -> @library.ElementIntrospector[@library.HtmlPosition] {
  self.elements
}

///|
/// Resolves the position in the DOM of an element.
pub fn HtmlIntrospector::html_position(
  self : HtmlIntrospector,
  location : @library.Location,
) -> @library.HtmlPosition? {
  self.elements.position(location)
}

///|
/// Computes all locations that are referenced by intra-doc links of any
/// kind.
pub fn HtmlIntrospector::link_targets(
  self : HtmlIntrospector,
) -> @hashset.HashSet[@library.Location] {
  let set = @hashset.HashSet([])
  for loc in @library.LinkElem::find_destinations(self) {
    set.add(loc)
  }
  for loc in self.frame_link_targets {
    set.add(loc)
  }
  set
}

///|
/// Returns the locations that the HTML document links to via
/// `FrameItem::Link`.
pub fn HtmlIntrospector::frame_link_targets(
  self : HtmlIntrospector,
) -> @hashset.HashSet[@library.Location] {
  self.frame_link_targets
}

///|
/// Enriches an existing introspector with HTML link anchors, which were
/// assigned to the DOM in a post-processing step.
pub fn HtmlIntrospector::set_anchors(
  self : HtmlIntrospector,
  anchors : Map[@library.Location, String],
) -> Unit {
  self.anchors = anchors
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn query(
  self,
  selector,
) {
  self.elements.query(selector)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn query_first(
  self,
  selector,
) {
  self.elements.query_first(selector)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn query_unique(
  self,
  selector,
) {
  self.elements.query_unique(selector)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn query_label(
  self,
  label,
) {
  self.elements.query_label(label)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn query_labelled(
  self,
) {
  self.elements.query_labelled()
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn query_count_before(
  self,
  selector,
  end,
) {
  self.elements.query_count_before(selector, end)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn label_count(
  self,
  label,
) {
  self.elements.label_count(label)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn locator(
  self,
  key,
  base,
) {
  self.elements.locator(key, base)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn pages(_, _) {
  None
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn page(_, _) {
  None
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn position(
  self,
  location,
) {
  self.html_position(location).map(p => @library.DocumentPosition::Html(p))
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn page_numbering(
  _,
  _,
) {
  None
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn page_supplement(
  _,
  _,
) {
  None
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn anchor(
  self,
  location,
) {
  self.anchors.get(location)
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn document(
  _,
  _,
) {
  None
}

///|
pub impl @library.IntrospectorBackend for HtmlIntrospector with fn path(_, _) {
  None
}

///|
/// Upstream `Debug for HtmlIntrospector`.
pub impl Show for HtmlIntrospector with fn output(_, logger) {
  logger.write_string("HtmlIntrospector(..)")
}

///|
/// Constructs the [HtmlIntrospector].
priv struct HtmlIntrospectorBuilder {
  elements : @library.ElementIntrospectorBuilder[@library.HtmlPosition]
  frame_link_targets : @hashset.HashSet[@library.Location]
}

///|
fn HtmlIntrospectorBuilder::new() -> HtmlIntrospectorBuilder {
  {
    elements: @library.ElementIntrospectorBuilder::new(),
    frame_link_targets: @hashset.HashSet([]),
  }
}

///|
/// Returns the resulting introspector.
fn HtmlIntrospectorBuilder::finish(
  self : HtmlIntrospectorBuilder,
) -> HtmlIntrospector {
  {
    elements: self.elements.finalize(),
    frame_link_targets: self.frame_link_targets,
    anchors: {},
  }
}

///|
/// Discovers introspectibles in a collection of HTML nodes.
fn HtmlIntrospectorBuilder::discover_nodes(
  self : HtmlIntrospectorBuilder,
  nodes : ArrayView[HtmlNode],
  current_position : Array[Int],
) -> Unit {
  for pair in iter_with_dom_indices(nodes) {
    let (node, dom_index) = pair
    match node {
      Tag(tag) => {
        current_position.push(dom_index)
        self.elements.discover_tag(
          tag,
          @library.HtmlPosition::new(current_position.copy()),
        )
        current_position.pop() |> ignore
      }
      Text(_, _) => ()
      Element(elem) => {
        let is_root = elem.tag == @library.tag_html
        if !is_root {
          current_position.push(dom_index)
        }
        match elem.parent {
          Some(parent) => {
            self.elements.start_insertion()
            self.discover_nodes(elem.children, current_position)
            self.elements.end_insertion(parent)
          }
          None => self.discover_nodes(elem.children, current_position)
        }
        if !is_root {
          current_position.pop() |> ignore
        }
      }
      Frame(frame) => {
        current_position.push(dom_index)
        self.discover_frame(frame.inner, current_position)
        current_position.pop() |> ignore
      }
    }
  }
}

///|
/// Discovers introspectibles in a frame.
///
/// TODO: Upstream walks the frame's items (with their transforms): tags are
/// discovered at `HtmlPosition::new(current_position).in_frame(point)`,
/// groups with a parent are wrapped in an insertion, and
/// `FrameItem::Link(Destination::Location(loc))` adds `loc` to
/// `frame_link_targets`. Frames are placeholders without items until layout
/// is ported.
fn HtmlIntrospectorBuilder::discover_frame(
  _self : HtmlIntrospectorBuilder,
  _frame : @library.Frame,
  _current_position : Array[Int],
) -> Unit {
  ()
}
