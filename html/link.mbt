// Port of `typst-html/src/link.rs`.

///|
/// Attaches IDs to nodes produced by link targets to make them linkable.
///
/// The `targets` set should contain the locations of all elements in the HTML
/// document that are linked to from somewhere.
///
/// May produce `<span>`s for link targets that turned into text nodes or no
/// nodes at all. See the `LinkElem` documentation for more details.
///
/// Anchor ID generation attempts to use existing HTML element IDs and Typst
/// labels to generate human-readable fragment names. If a label occurs
/// multiple times, it's disambiguated with a suffix. This disambiguation is
/// per document, even in bundle output. It uses the document's own
/// introspector.
pub fn create_link_anchors(
  document : HtmlDocument,
  targets : @hashset.HashSet[@library.Location],
) -> Map[@library.Location, String] {
  if targets.is_empty() {
    // Nothing to do.
    return {}
  }

  // Assign IDs to all link targets.
  let work = Work::new()
  let introspector = document.introspector()
  traverse(
    work,
    targets,
    @library.AnchorGenerator::new(introspector),
    document.root_mut().children,
  )
  work.ids
}

///|
/// Traverses a list of nodes.
fn traverse(
  work : Work,
  targets : @hashset.HashSet[@library.Location],
  generator : @library.AnchorGenerator,
  nodes : Array[HtmlNode],
) -> Unit {
  let mut i = 0
  while i < nodes.length() {
    let node = nodes[i]
    match node {
      // When visiting a start tag, we check whether the element needs an ID
      // and if so, add it to the queue, so that its first child node
      // receives an ID.
      Tag(Start(elem, _)) => {
        let loc = elem.location().unwrap()
        if targets.contains(loc) {
          work.enqueue(loc, elem.label())
        }
      }

      // When we reach an end tag, we check whether it closes an element that
      // is still in our queue. If so, that means the element produced no
      // nodes and we need to insert an empty span.
      Tag(End(loc, _, _)) =>
        work.remove(loc, label => {
          let element = HtmlElement::new(@library.tag_span)
          let id = assign(generator, element, label)
          nodes.insert(i + 1, Element(element))
          id
        })

      // When visiting an element and the queue is non-empty, we assign an
      // ID. Then, we traverse its children.
      Element(element) => {
        work.drain(label => assign(generator, element, label))
        traverse(work, targets, generator, element.children)
      }

      // When visiting text and the queue is non-empty, we generate a span and
      // assign an ID.
      Text(_, _) =>
        work.drain(label => {
          let element = HtmlElement::new(@library.tag_span).with_children([node])
          let id = assign(generator, element, label)
          nodes[i] = Element(element)
          id
        })

      // When visiting a frame and the queue is non-empty, we assign an ID to
      // it (will be added to the resulting SVG element).
      Frame(frame) => {
        work.drain(label => {
          match frame.id {
            Some(id) => id
            None => {
              let id = generator.identify(label)
              frame.id = Some(id)
              id
            }
          }
        })
        traverse_frame(work, targets, generator, frame.inner, frame.anchors)
      }
    }
    i += 1
  }
}

///|
/// Traverses a frame embedded in HTML.
///
/// TODO: Upstream walks the frame's items: for a start tag of a targeted
/// element whose position is `InnerHtmlPosition::Frame(point)`, it assigns
/// `generator.identify(elem.label())` as the element's ID and pushes
/// `(point, id)` to `anchors`, recursing into groups. Frames are
/// placeholders without items until layout is ported.
fn traverse_frame(
  _work : Work,
  _targets : @hashset.HashSet[@library.Location],
  _generator : @library.AnchorGenerator,
  _frame : @library.Frame,
  _anchors : Array[(@library.Point, String)],
) -> Unit {
  ()
}

///|
/// Keeps track of the work to be done during ID generation.
priv struct Work {
  /// The locations and labels of elements we need to assign an ID to right
  /// now.
  queue : Array[(@library.Location, @library.Label?)]
  /// The resulting mapping from element location's to HTML IDs.
  ids : Map[@library.Location, String]
}

///|
/// Sets up.
fn Work::new() -> Work {
  { queue: [], ids: {}, }
}

///|
/// Marks the element with the given location and label as in need of an ID.
/// A subsequent call to `drain` will call `f`.
fn Work::enqueue(
  self : Work,
  loc : @library.Location,
  label : @library.Label?,
) -> Unit {
  self.queue.push((loc, label))
}

///|
/// If one or multiple elements are in need of an ID, calls `f` to generate
/// an ID and apply it to the current node with `f`, and then establishes a
/// mapping from the elements' locations to that ID.
fn Work::drain(self : Work, f : (@library.Label?) -> String) -> Unit {
  if self.queue.get(0) is Some((_, label)) {
    let id = f(label)
    for pair in self.queue {
      self.ids[pair.0] = id
    }
    self.queue.clear()
  }
}

///|
/// Similar to `drain`, but only for a specific given location.
fn Work::remove(
  self : Work,
  loc : @library.Location,
  f : (@library.Label?) -> String,
) -> Unit {
  if self.queue.search_by(pair => pair.0 == loc) is Some(i) {
    let (_, label) = self.queue.remove(i)
    let id = f(label)
    self.ids[loc] = id
  }
}

///|
/// Assigns an ID to an element or reuses an existing ID (upstream
/// `AnchorGeneratorExt::assign`).
fn assign(
  generator : @library.AnchorGenerator,
  element : HtmlElement,
  label : @library.Label?,
) -> String {
  match element.attrs.get(@library.attr_id) {
    Some(id) => id
    None => {
      let id = generator.identify(label)
      element.attrs = element.attrs.copy()
      element.attrs.push_front(@library.attr_id, id)
      id
    }
  }
}
