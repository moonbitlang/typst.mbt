// Port of `typst-pdf/src/outline.rs`.

///|
fn build_outline(gc : GlobalContext) -> @export.Outline {
  let elems = gc.document.introspector().query(@library.heading_elem().select())
  let flat = []
  for elem in elems {
    guard @library.HeadingElem::of(elem) is Some(heading) else { continue }
    let styles = @library.StyleChain::empty()
    let level = heading.resolve_level(styles)
    let bookmarked = match heading.bookmarked(styles) {
      Custom(b) => b
      Auto => heading.outlined(styles)
    }
    let visible = match gc.options.format.pages.v {
      None => true
      Some(ranges) => {
        let page = match elem.location() {
          Some(loc) =>
            match gc.document.introspector().page(loc) {
              Some(p) => p.get().to_int()
              None => 1
            }
          None => 1
        }
        !ranges.includes_page(page)
      }
    }
    let include = bookmarked && visible
    flat.push((elem, level, include))
  }
  let tree = @library.OutlineNode::build_tree(flat[:])
  let outline = @export.Outline::new()
  for child in convert_list(tree, gc) {
    outline.push_child(child)
  }
  outline
}

///|
fn convert_list(
  nodes : Array[@library.OutlineNode[@library.Content]],
  gc : GlobalContext,
) -> Array[@export.OutlineNode] {
  let out = []
  for node in nodes {
    if convert_node(node, gc) is Some(n) {
      out.push(n)
    }
  }
  out
}

///|
fn convert_node(
  node : @library.OutlineNode[@library.Content],
  gc : GlobalContext,
) -> @export.OutlineNode? {
  let loc = node.entry.location().unwrap()
  let pos = gc.document
    .paged_introspector()
    .position(loc)
    .unwrap_or(@library.PagedPosition::origin())
  let heading = @library.HeadingElem::of(node.entry).unwrap()
  // Prepend the numbers to the title if they exist.
  let text = heading.body().plain_text()
  let title = match heading.numbers() {
    Some(num) => "\{num} \{text}"
    None => text
  }
  if pos_to_xyz(gc.page_index_converter, pos) is Some(dest) {
    let outline_node = @export.OutlineNode::new(title, dest)
    for child in convert_list(node.children, gc) {
      outline_node.push_child(child)
    }
    return Some(outline_node)
  }
  None
}
