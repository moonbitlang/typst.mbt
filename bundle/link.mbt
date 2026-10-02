// Port of `typst-bundle/src/link.rs`.

///|
/// Creates link anchors for all linked-to elements.
///
/// The `targets` map should contain the locations of all elements that are
/// linked to sharded by the path of the document they are contained in.
///
/// Returns the assigned anchors for all locations in the sets in `targets`.
/// The anchors are local to the file. Also creates empty anchors for the
/// documents and assets themselves, so that they become linkable, too.
fn create_link_anchors(
  items : Array[Item],
  targets : Map[@syntax.VirtualPath, @hashset.HashSet[@library.Location]],
) -> Map[@library.Location, String] {
  let empty : @hashset.HashSet[@library.Location] = @hashset.HashSet([])
  let anchors : Map[@library.Location, String] = Map([])
  for item in items {
    guard item is Document(path, doc, _) else { continue }
    let targets = targets.get(path).unwrap_or(empty)
    match doc {
      // Mutates the DOM in place to insert IDs as necessary.
      Html(doc) =>
        for loc, anchor in @html.create_link_anchors(doc, targets) {
          anchors[loc] = anchor
        }
      Paged(doc, extras) => {
        // Mutates the export options so that named destinations are
        // generated (if supported by the format).
        extras.anchors = create_paged_link_anchors(doc, targets)
        for pair in extras.anchors {
          anchors[pair.0] = pair.1
        }
      }
    }
  }

  // Create empty anchors for assets and documents so that we can also link
  // directly to them.
  for item in items {
    let loc = match item {
      Tag(_) => continue
      Asset(_, _, loc) => loc
      Document(_, _, loc) => loc
    }
    anchors[loc] = ""
  }
  anchors
}

///|
/// Creates link anchors for a paged document.
///
/// The `targets` set should contain the locations of all elements in the
/// paged document that are linked to from somewhere.
fn create_paged_link_anchors(
  doc : @layout.PagedDocument,
  targets : @hashset.HashSet[@library.Location],
) -> Array[(@library.Location, String)] {
  let introspector = doc.paged_introspector()
  let elements = introspector.elements()
  let generator = @library.AnchorGenerator::new(introspector)
  let anchors = []
  // Sorted by element index (unique among the found elements; missing ones
  // are skipped below, so the unstable sort is fine).
  let targets = targets.iter().collect()
  targets.sort_by_key(loc => elements.loc_index(loc))
  for target in targets {
    if elements.get_by_loc(target) is Some(elem) {
      let anchor = generator.identify(elem.label())
      anchors.push((target, anchor))
    }
  }
  anchors
}
