// Port of `typst-layout/src/pages/collect.rs`.

///|
/// An item in page layout.
priv enum PageItem {
  /// A page run containing content. All runs will be layouted in parallel.
  Run(ArrayView[@library.Pair], @library.StyleChain, @library.Locator)
  /// Tags in between pages. These will be prepended to the first start of
  /// the next page, or appended at the very end of the final page if there
  /// is no next page.
  Tags(ArrayView[@library.Pair])
  /// An instruction to possibly add a page to bring the page number parity
  /// to the desired state. Can only be done at the end, sequentially,
  /// because it requires knowledge of the concrete page number.
  Parity(@library.Parity, @library.StyleChain, @library.Locator)
}

///|
/// Slices up the children into logical parts, processing styles and
/// handling things like tags and weak pagebreaks.
fn collect_pages(
  children : Array[@library.Pair],
  locator : @library.SplitLocator,
  initial : @library.StyleChain,
) -> Array[PageItem] {
  let mut initial = initial
  // The collected page-level items.
  let items : Array[PageItem] = []
  // When this is true, an empty page should be added to `pages` at the end.
  let mut staged_empty_page = true

  // The `children` are a flat list of flow-level items and pagebreaks. This
  // loops splits it up into pagebreaks and consecutive slices of
  // non-pagebreaks. From these pieces, we build page items that we can then
  // layout in parallel.
  let mut pos = 0
  while pos < children.length() {
    let (elem, styles) = children[pos]
    if @library.PagebreakElem::of(elem) is Some(pagebreak) {
      // Add a blank page if we encounter a strong pagebreak and there was a
      // staged empty page.
      let strong = !pagebreak.weak(styles)
      if strong && staged_empty_page {
        let locator = locator.next(elem.span())
        items.push(Run(children[0:0], initial, locator))
      }

      // Add an instruction to adjust the page parity if requested.
      if pagebreak.to(styles) is Some(parity) {
        let locator = locator.next(elem.span())
        items.push(Parity(parity, styles, locator))
      }

      // The initial styles for the next page are ours unless this is a
      // "boundary" pagebreak. Such a pagebreak is generated at the end of the
      // scope of a page set rule to ensure a page boundary. Its styles
      // correspond to the styles _before_ the page set rule, so we don't want
      // to apply it to a potential empty page.
      if !pagebreak.boundary(styles) {
        initial = styles
      }

      // Stage an empty page after a strong pagebreak.
      staged_empty_page = staged_empty_page || strong

      // Advance to the next child.
      pos += 1
    } else {
      // Find the end of the consecutive non-pagebreak run.
      let mut end = 0
      while pos + end < children.length() &&
            !children[pos + end].0.is_(@library.pagebreak_elem()) {
        end += 1
      }

      // Migrate start tags without accompanying end tags from before a
      // pagebreak to after it.
      let end = migrate_unterminated_tags(children, pos, end)
      if end == 0 {
        continue
      }

      // Advance to the rest of the children.
      let group = children[pos:pos + end]
      pos += end
      let rest = children[pos:]

      // If all that is left now are tags, then we don't want to add a page
      // just for them (since no group would have been detected in a tagless
      // layout and tags should never affect the layout). For this reason, we
      // remember them in a `PageItem::Tags` and later insert them at the
      // _very start_ of the next page, even before the header.
      //
      // We don't do this if all that's left is end boundary pagebreaks and
      // if an empty page is still staged, since then we can just
      // conceptually replace that final page with us.
      if group.iter().all(pair => pair.0.is_(@library.tag_elem())) &&
        !(staged_empty_page &&
        rest
        .iter()
        .all(pair => {
          match @library.PagebreakElem::of(pair.0) {
            Some(c) => c.boundary(pair.1)
            None => false
          }
        })) {
        items.push(Tags(group))
        continue
      }

      // Record a page run and then disregard a staged empty page because we
      // have real content now.
      let locator = locator.next(elem.span())
      items.push(Run(group, initial, locator))
      staged_empty_page = false
    }
  }

  // Flush a staged empty page.
  if staged_empty_page {
    items.push(Run(children[0:0], initial, locator.next(())))
  }
  items
}

///|
/// Migrates trailing start tags without accompanying end tags from before a
/// pagebreak to after it. Returns the position right after the last
/// non-migrated tag.
///
/// This is important because we want the positions of introspectable
/// elements that technically started before a pagebreak, but have no visible
/// content yet, to be after the pagebreak. A typical case where this happens
/// is `show heading: it => pagebreak() + it`.
///
/// The children are `children[base:]` upstream; `mid` is relative to `base`.
fn migrate_unterminated_tags(
  children : Array[@library.Pair],
  base : Int,
  mid : Int,
) -> Int {
  let len = children.length() - base
  let is_tag = (i : Int) => children[base + i].0.is_(@library.tag_elem())
  let is_pagebreak = (i : Int) => {
    children[base + i].0.is_(@library.pagebreak_elem())
  }

  // Compute the range from before the first trailing tag to after the last
  // following pagebreak.
  let mut start = mid
  while start > 0 && is_tag(start - 1) {
    start -= 1
  }
  let mut end = mid
  while end < len && is_pagebreak(end) {
    end += 1
  }

  // Determine the set of tag locations which we won't migrate (because they
  // are terminated).
  let excluded = @hashset.HashSet::new()
  for i in start..<mid {
    if @library.TagElem::of(children[base + i].0) is Some(elem) &&
      elem.tag() is End(loc, _, _) {
      excluded.add(loc)
    }
  }

  // A key function that partitions the area of interest into three groups:
  // Excluded tags (-1) | Pagebreaks (0) | Migrated tags (1).
  let key = (pair : @library.Pair) => {
    match @library.TagElem::of(pair.0) {
      Some(elem) =>
        if excluded.contains(elem.tag().location()) {
          -1
        } else {
          1
        }
      None => 0
    }
  }

  // Partition the children using a *stable* sort. While it would be possible
  // to write a more efficient direct algorithm for this, the sort version is
  // less likely to have bugs and this is absolutely not on a hot path.
  let area = children[base + start:base + end].to_array()
  stable_sort_by(area, (a, b) => key(a).compare(key(b)))
  for i, pair in area {
    children[base + start + i] = pair
  }

  // Compute the new end index, right before the pagebreaks.
  let mut count = 0
  for pair in area {
    if key(pair) != -1 {
      break
    }
    count += 1
  }
  start + count
}
