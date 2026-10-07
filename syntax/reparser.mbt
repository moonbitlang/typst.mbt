// Port of `crates/typst-syntax/src/reparser.rs`.
//
// All ranges are UTF-8 byte ranges like upstream. Upstream passes the new
// text as `&str`; here the [Lines] of the new text are passed instead, since
// the parser works on UTF-16 indices and the byte ranges handed to
// [reparse_block] and [reparse_markup] must be converted.
//
// Upstream edits the tree through `&mut SyntaxNode`: the nodes it writes to
// are made unique by `Arc::make_mut` on the way (`children_mut`,
// `update_parent`, `replace_children` and `numberize` all go through
// `inner_and_span_mut`, node.rs:85), so a tree that somebody else holds is
// left as it was. Here [reparse] returns the new root and the tree it was
// given stays as it is: it works on copies of the nodes it writes to (the
// root, and each child before [try_reparse] descends into it), which is the
// rule in the header of `node.mbt`. A reparse that fails halfway has written
// to copies only.

///|
/// Refresh the given syntax node with as little parsing as possible.
///
/// Takes the new text, the range `replaced_start..replaced_end` in the old
/// text that was replaced and the length of the replacement and returns the
/// range in the new text that was ultimately reparsed.
///
/// The high-level API for this function is [Source::edit].
///
/// Upstream takes `root: &mut SyntaxNode` (reparser.rs:13). Here `root` is
/// not written to: the refreshed tree is returned with the range, and it
/// shares with `root` every node that the edit did not have to write to.
fn reparse(
  root : SyntaxNode,
  text : Lines,
  replaced_start : Int,
  replaced_end : Int,
  replacement_len : Int,
) -> (SyntaxNode, (Int, Int)) {
  // Upstream writes to the root's record through `node.children_mut()`
  // (reparser.rs:64), which copies it if it is shared.
  let node = root.make_mut()
  match
    try_reparse(
      text,
      replaced_start,
      replaced_end,
      replacement_len,
      None,
      node,
      0,
    ) {
    Some(range) => (node, range)
    None => {
      let id = root.span().id()
      let root = parse(text.text())
      if id is Some(id) {
        root.numberize(id, span_full_start, span_full_end) catch {
          _ => abort("failed to number reparsed source")
        }
      }
      (root, (0, text.len_bytes()))
    }
  }
}

///|
/// Convert a UTF-8 byte index of the new text into the parser's UTF-16 index.
fn reparse_utf16(text : Lines, byte_idx : Int) -> Int {
  guard text.byte_to_utf16(byte_idx) is Some(i) else {
    abort("reparse range out of bounds")
  }
  i
}

///|
/// Try to reparse inside the given node, returning the range that was
/// ultimately reparsed.
///
/// We start by doing a depth-first search for the innermost node or nodes which
/// fully surround the replaced range. This can be a single node that is a
/// code/content block or one or more nodes that are markup expressions and are
/// directly inside a markup block or the top-level markup. In either case, we
/// call the parser and succeed only if the parsed text has balanced delimiters
/// with the same delimiter nesting level as before. Otherwise, we expand the
/// set of markup expressions outwards or return upwards until we either get a
/// parse that does succeed or we parse the entire text.
///
/// Note that we currently only reparse markup expressions at the top-level or
/// directly inside a markup block. E.g. we don't reparse markup expressions
/// inside lists or headings, etc. In the past we did reparse those, but the
/// implementation was very buggy due to edge cases surrounding indentation and
/// newlines, and was eventually removed without much performance impact. It's
/// still potentially desireable to handle some of those cases (individual list
/// items can get quite long in practice), but only if the implementation can be
/// easily reasoned as correct and shows a measured performance improvement.
///
/// We also do not currently reparse math in any capacity, but it would not be
/// too difficult to include equations as another kind of block, or reparse math
/// expressions similarly to markup expressions.
///
/// `node` is written to: it must be a copy that this edit made
/// ([SyntaxNode::make_mut]). Its children are those of the tree before the
/// edit until they are replaced here.
fn try_reparse(
  text : Lines,
  replaced_start : Int,
  replaced_end : Int,
  replacement_len : Int,
  parent_kind : SyntaxKind?,
  node : SyntaxNode,
  offset : Int,
) -> (Int, Int)? {
  guard overlapping_children(node, replaced_start, replaced_end, offset)
    is Some((overlap_start, overlap_end, start_offset)) else {
    return None
  }
  let node_kind = node.kind()
  let children = node.children_mut()
  if overlap_end - overlap_start == 1 {
    let child = children[overlap_start]
    if start_offset < replaced_start &&
      replaced_end < start_offset + child.len() &&
      child.is_inner() {
      // A single child fully surrounds the edit. We either reparse within the
      // child, or reparse the child itself (if the child is a block).
      let prev_len = child.len()
      let prev_desc = child.descendants()
      let new_len = prev_len + replacement_len - (replaced_end - replaced_start)
      let new_range = (start_offset, start_offset + new_len)

      // Not upstream: the recursive call writes to the child, which is of
      // the tree before the edit, so it gets a copy that takes the child's
      // place in `node` (whose children array is this edit's). Upstream's
      // call copies the child's record itself, in its `children_mut()`
      // (reparser.rs:64), which it always reaches: an inner child that
      // surrounds the edit has overlapping children.
      let child = child.make_mut()
      children[overlap_start] = child

      // Recursively descend and try to reparse at a lower level.
      if try_reparse(
          text,
          replaced_start,
          replaced_end,
          replacement_len,
          Some(node_kind),
          child,
          start_offset,
        )
        is Some(range) {
        // A lower level reparse succeeded! Update this node and return the
        // reparsed range.
        guard child.len() == new_len else {
          abort("reparsed child has unexpected length")
        }
        let new_desc = child.descendants()
        node.update_parent(prev_len, new_len, prev_desc, new_desc)
        return Some(range)
      }

      // This is the innermost block which fully surrounds the text (and
      // hasn't failed at reparsing yet), reparse!
      if child.kind().is_block() &&
        reparse_block(
          text.text(),
          reparse_utf16(text, new_range.0),
          reparse_utf16(text, new_range.1),
        )
        is Some(reparsed) {
        // Reparsing succeeded, but we can still fail if we're out of span
        // numbers to assign to nodes (this is rare).
        let ok = try
          node.replace_children(overlap_start, overlap_end, [reparsed])
        catch {
          Unnumberable => false
        } noraise {
          _ => true
        }
        return if ok { Some(new_range) } else { None }
      }
    }
  }
  if node_kind == Markup &&
    (parent_kind is None || parent_kind is Some(ContentBlock)) {
    expand_and_reparse_markup(
      text,
      replaced_start,
      replaced_end,
      replacement_len,
      node,
      overlap_start,
      overlap_end,
      offset,
      parent_kind is None,
    )
  } else {
    None
  }
}

///|
/// Reparse a range of markup expressions, expanding the range exponentially on
/// each iteration.
fn expand_and_reparse_markup(
  text : Lines,
  replaced_start : Int,
  replaced_end : Int,
  replacement_len : Int,
  node : SyntaxNode,
  overlap_start : Int,
  overlap_end : Int,
  offset : Int,
  top_level : Bool,
) -> (Int, Int)? {
  let children = node.children()

  // Reparse a segment. Retries until it works, taking exponentially more
  // children into account.
  let mut expansion = 1
  while true {
    // Add slack in both directions.
    let slack = if expansion > 2 { expansion } else { 2 }
    let mut start = if overlap_start > slack {
      overlap_start - slack
    } else {
      0
    }
    let mut end = if overlap_end + expansion < children.length() {
      overlap_end + expansion
    } else {
      children.length()
    }

    // Expand to the left.
    while start > 0 && expand(children[start]) {
      start -= 1
    }

    // Expand to the right.
    while end < children.length() && expand(children[end]) {
      end += 1
    }

    // Also take hash.
    if start > 0 && children[start - 1].kind() == Hash {
      start -= 1
    }

    // Synthesize what `at_start` and `nesting` would be at the start of the
    // reparse.
    let mut prefix_len = 0
    let nesting : Ref[Int] = { val: 0, }
    let at_start : Ref[Bool] = { val: true, }
    for child in children[:start] {
      prefix_len += child.len()
      next_at_start(child, at_start)
      next_nesting(child, nesting)
    }

    // Determine what `at_start` will have to be at the end of the reparse.
    let mut prev_len = 0
    let prev_at_start_after : Ref[Bool] = { val: at_start.val, }
    let prev_nesting_after : Ref[Int] = { val: nesting.val, }
    for child in children[start:end] {
      prev_len += child.len()
      next_at_start(child, prev_at_start_after)
      next_nesting(child, prev_nesting_after)
    }

    // Determine the range in the new text that we want to reparse.
    let shifted = offset + prefix_len
    let new_len = prev_len + replacement_len - (replaced_end - replaced_start)
    let new_range = (shifted, shifted + new_len)
    let at_end = end == children.length()

    // Reparse!
    let reparsed = reparse_markup(
      text.text(),
      reparse_utf16(text, new_range.0),
      reparse_utf16(text, new_range.1),
      at_start,
      nesting,
      top_level,
    )
    if reparsed is Some(newborns) {
      // If more children follow, at_start must match its previous value.
      // Similarly, if we children follow or we not top-level the nesting
      // must match its previous value.
      if (at_end || at_start.val == prev_at_start_after.val) &&
        ((at_end && top_level) || nesting.val == prev_nesting_after.val) {
        // Reparsing succeeded, but we can still fail if we're out of
        // span numbers to assign to nodes (this is rare).
        let ok = try node.replace_children(start, end, newborns) catch {
          Unnumberable => false
        } noraise {
          _ => true
        }
        return if ok { Some(new_range) } else { None }
      }
    }

    // If it didn't even work with all children, we give up.
    if start == 0 && at_end {
      break
    }

    // Exponential expansion to both sides.
    expansion *= 2
  }
  None
}

///|
/// The indices `(start, end)` and start offset of the children which overlap a
/// replaced range. Returns `None` if the children don't fully cover the range.
/// Will never return an empty range if it returns `Some`.
///
/// Note that the returned index range is the range of children in the
/// parent, but the returned offset is a byte offset in the source text.
fn overlapping_children(
  node : SyntaxNode,
  range_start : Int,
  range_end : Int,
  offset : Int,
) -> (Int, Int, Int)? {
  if !node.is_inner() || offset > range_start || range_end > offset + node.len() {
    // No set of children will fully cover the range, no need to search.
    return None
  }
  let mut offset = offset
  let mut index = 0
  let mut start = 0
  let mut start_offset = offset
  for child in node.children() {
    if offset < range_start {
      start = index
      start_offset = offset
    }
    offset += child.len()
    index += 1
    if range_end < offset {
      break
    }
  }
  Some((start, index, start_offset))
}

///|
/// Whether the selection should be expanded beyond a node of this kind.
fn expand(node : SyntaxNode) -> Bool {
  let kind = node.kind()
  kind.is_trivia() ||
  kind.is_error() ||
  kind == Semicolon ||
  node.leaf_text() == "/" ||
  node.leaf_text() == ":"
}

///|
/// Whether `at_start` would still be true after this node given the
/// previous value of the property.
fn next_at_start(node : SyntaxNode, at_start : Ref[Bool]) -> Unit {
  let kind = node.kind()
  if kind.is_trivia() {
    at_start.val = at_start.val || kind is (Parbreak | SpaceWithNewline)
  } else {
    at_start.val = false
  }
}

///|
/// Update `nesting` based on the node.
fn next_nesting(node : SyntaxNode, nesting : Ref[Int]) -> Unit {
  if node.kind() == Text {
    match node.leaf_text() {
      "[" => nesting.val += 1
      "]" if nesting.val > 0 => nesting.val -= 1
      _ => ()
    }
  }
}
