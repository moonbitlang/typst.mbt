// Port of `crates/typst-syntax/src/source.rs`.
//
// Upstream `Source` is a reference-counted, copy-on-write handle. Here it is a
// mutable object: [Source::edit] and [Source::replace] update the text, the
// line metadata and the syntax tree in place (the root node object is kept,
// see [reparse]). Callers that need the previous tree must
// [SyntaxNode::deep_clone] it before editing.

///|
/// A Typst source file containing the full source text, a mapping from byte
/// indices to lines/columns, and the parsed syntax tree.
///
/// All line and column indices start at zero, just like byte indices. Only for
/// user-facing display, you should add 1 to them.
pub struct Source {
  priv id : FileId
  priv root : SyntaxNode
  priv lines : Lines
}

///|
/// Create a new source file.
pub fn Source::new(id : FileId, text : String) -> Source {
  let root = parse(text)
  root.numberize(id, span_full_start, span_full_end) catch {
    _ => abort("failed to number source file")
  }
  { id, lines: Lines::new(text), root, }
}

///|
/// Create a source file without a real id and path, usually for testing.
pub fn Source::detached(text : String) -> Source {
  let vpath = VirtualPath::new("main.typ") catch { _ => abort("unreachable") }
  Source::new(RootedPath::new(Project, vpath).intern(), text)
}

///|
/// Create a new source file with an already created syntax tree.
pub fn Source::with_root(
  id : FileId,
  text : String,
  root : SyntaxNode,
) -> Source {
  { id, lines: Lines::new(text), root, }
}

///|
/// The root node of the file's untyped syntax tree.
pub fn Source::root(self : Source) -> SyntaxNode {
  self.root
}

///|
/// The id of the source file.
pub fn Source::id(self : Source) -> FileId {
  self.id
}

///|
/// The whole source text.
pub fn Source::text(self : Source) -> String {
  self.lines.text()
}

///|
/// An acceleration structure for conversion of UTF-8, UTF-16 and
/// line/column indices.
pub fn Source::lines(self : Source) -> Lines {
  self.lines
}

///|
/// Fully replace the source text.
///
/// This performs a naive (suffix/prefix-based) diff of the old and new text
/// to produce the smallest single edit that transforms old into new and
/// then calls [Source::edit] with it.
///
/// Returns the (UTF-8 byte) range in the new source that was ultimately
/// reparsed.
pub fn Source::replace(self : Source, new : String) -> (Int, Int) {
  guard self.lines.replacement_range(new) is Some((prefix, suffix)) else {
    return (0, 0)
  }
  let old_len = self.lines.len_bytes()
  let replacement = utf8_slice(new, prefix, utf8_len(new) - suffix)
  self.edit(prefix, old_len - suffix, replacement)
}

///|
/// Edit the source file by replacing the given (UTF-8 byte) range
/// `start..end` with `replacement`.
///
/// Returns the range in the new source that was ultimately reparsed.
///
/// Aborts if the range is out of bounds.
pub fn Source::edit(
  self : Source,
  start : Int,
  end : Int,
  replacement : String,
) -> (Int, Int) {
  // Update the text and lines.
  self.lines.edit(start, end, replacement)

  // Incrementally reparse the replaced range.
  reparse(self.root, self.lines, start, end, utf8_len(replacement))
}

///|
/// Find the node with the given span.
///
/// Returns `None` if the span does not point into this source file.
pub fn Source::find(self : Source, span : Span) -> LinkedNode? {
  if span.id() != Some(self.id) {
    return None
  }
  LinkedNode::new(self.root).find(span)
}

///|
/// Get the UTF-8 byte range for the given span number (and optional
/// sub-range) in this file.
pub fn Source::range(
  self : Source,
  num : SpanNumber,
  sub_range : SubRange?,
) -> (Int, Int)? {
  guard LinkedNode::new(self.root).find_number(num) is Some(node) else {
    return None
  }
  let (start, end) = node.range()
  match sub_range {
    Some(sr) => {
      let (s, e) = sr.to_absolute(start)
      guard e <= end
      Some((s, e))
    }
    None => Some((start, end))
  }
}
