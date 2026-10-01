///|
/// A Typst source file containing the full source text and the parsed,
/// numbered syntax tree.
pub struct Source {
  id : FileId
  text : String
  root : SyntaxNode
}

///|
/// Create a new source file.
pub fn Source::new(id : FileId, text : String) -> Source {
  let root = parse(text)
  root.numberize(id, span_full_start, span_full_end) catch {
    _ => abort("failed to number source file")
  }
  { id, text, root, }
}

///|
/// Create a source file without a real id, usually for testing.
pub fn Source::detached(text : String) -> Source {
  Source::new(FileId(1), text)
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
  self.text
}

///|
/// Find the node with the given span.
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
