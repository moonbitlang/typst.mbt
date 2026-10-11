// Port of `crates/typst-syntax/src/source.rs`.
//
// Upstream `Source` is a reference-counted, copy-on-write handle
// (`Arc<LazyHash<SourceInner>>`, source.rs:24): `edit` and `replace` take
// `&mut self` and write through `Arc::make_mut` (:107), so a `Source` that
// was cloned before keeps its text, its lines and its tree. The port has no
// reference count to ask, so a `Source` never changes: [Source::edit] and
// [Source::replace] return the edited source, and the one they were called
// on stays what it was, for whoever holds it. That is what a clone taken
// before the edit is upstream; the holder of upstream's `&mut Source` (a
// file slot of a world) keeps the returned source instead.
//
// An edited source shares with the one before every syntax node that the
// edit did not write to (the header of `node.mbt` says which it copies:
// the ancestors of what is replaced, and the neighbours it has to
// renumber), so those nodes keep their span numbers, and a closure or a
// module that holds nodes of the old tree is not affected by the edit.

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
  /// The number of the source ([Source::serial]).
  priv serial : Int
  /// Whether the tree is the one [Source::new] made of the text
  /// ([Source::is_pristine]).
  priv pristine : Bool
  /// Two words that a caller keeps with the source ([Source::set_memo]).
  priv mut memo : Bool
  priv mut memo_hi : UInt64
  priv mut memo_lo : UInt64
}

///|
/// The number of sources made so far ([Source::serial]).
let source_serials : Ref[Int] = { val: 0, }

///|
fn next_source_serial() -> Int {
  source_serials.val += 1
  source_serials.val
}

///|
/// Create a new source file.
pub fn Source::new(id : FileId, text : String) -> Source {
  let root = parse(text)
  root.numberize(id, span_full_start, span_full_end) catch {
    _ => abort("failed to number source file")
  }
  {
    id,
    lines: Lines::new(text),
    root,
    serial: next_source_serial(),
    pristine: true,
    memo: false,
    memo_hi: 0,
    memo_lo: 0,
  }
}

///|
/// Create a source file without a real id and path, usually for testing.
pub fn Source::detached(text : String) -> Source {
  let vpath = VirtualPath::new("main.typ") catch { _ => abort("unreachable") }
  Source::new(RootedPath::new(Project, vpath).intern(), text)
}

///|
/// Create a new source file with an already created syntax tree.
///
/// This publishes the tree (see the header of `node.mbt`): the caller must
/// not write to it afterwards.
pub fn Source::with_root(
  id : FileId,
  text : String,
  root : SyntaxNode,
) -> Source {
  {
    id,
    lines: Lines::new(text),
    root,
    serial: next_source_serial(),
    pristine: false,
    memo: false,
    memo_hi: 0,
    memo_lo: 0,
  }
}

///|
/// The number of this source (not upstream, whose `Source` is a value
/// behind a `LazyHash`: two sources with one hash are one). No other
/// source of the process has it: a source never changes, and an edit
/// returns another source with another number. It identifies the text and
/// the numbered tree without hashing the tree.
pub fn Source::serial(self : Source) -> Int {
  self.serial
}

///|
/// Whether the source is what [Source::new] made of its text: its tree,
/// span numbers included, is then a function of the id and the text
/// (parsing and numbering are deterministic). The result of an edit is
/// not: a reparse keeps the numbers of the nodes it does not touch, so the
/// same text can have other numbers. Nor is a source made around a tree
/// that was given ([Source::with_root]).
pub fn Source::is_pristine(self : Source) -> Bool {
  self.pristine
}

///|
/// Whether [Source::set_memo] was called for the source.
pub fn Source::has_memo(self : Source) -> Bool {
  self.memo
}

///|
/// The two words kept by [Source::set_memo] (zero without).
pub fn Source::memo_hi(self : Source) -> UInt64 {
  self.memo_hi
}

///|
pub fn Source::memo_lo(self : Source) -> UInt64 {
  self.memo_lo
}

///|
/// Keeps two words with the source: for a hash of it, which this package
/// cannot compute (upstream: the `LazyHash` around `SourceInner`). A
/// source never changes, so what is kept is about it for its lifetime.
pub fn Source::set_memo(self : Source, hi : UInt64, lo : UInt64) -> Unit {
  self.memo = true
  self.memo_hi = hi
  self.memo_lo = lo
}

///|
/// The root node of the file's untyped syntax tree.
///
/// For reading: the nodes of a source are immutable (see the header of
/// `node.mbt`).
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
/// Returns the source with the new text and the (UTF-8 byte) range in it
/// that was ultimately reparsed. `self` is unchanged (upstream edits `self`
/// and returns the range); if the text is the same, `self` is returned with
/// the range `(0, 0)`.
pub fn Source::replace(self : Source, new : String) -> (Source, (Int, Int)) {
  guard self.lines.replacement_range(new) is Some((prefix, suffix)) else {
    return (self, (0, 0))
  }
  let old_len = self.lines.len_bytes()
  let replacement = utf8_slice(new, prefix, utf8_len(new) - suffix)
  self.edit(prefix, old_len - suffix, replacement)
}

///|
/// Edit the source file by replacing the given (UTF-8 byte) range
/// `start..end` with `replacement`.
///
/// Returns the edited source and the range in it that was ultimately
/// reparsed. `self` is unchanged (upstream edits `self` and returns the
/// range): the new source has its own lines and its own root. Its tree
/// shares with the tree of `self` the nodes that the edit did not write to:
/// all but the nodes that were replaced, their ancestors (copies with the
/// same span numbers) and, where the span numbers around the replacement
/// ran out, the neighbours that were renumbered (copies with new numbers,
/// although their text was not reparsed).
///
/// Aborts if the range is out of bounds.
pub fn Source::edit(
  self : Source,
  start : Int,
  end : Int,
  replacement : String,
) -> (Source, (Int, Int)) {
  // Upstream: `let inner = &mut **Arc::make_mut(&mut self.0);`
  // (source.rs:107), a copy of the record if the source is shared. Here the
  // record is always a new one, made below.

  // Update the text and lines.
  let lines = self.lines.edit(start, end, replacement)

  // Incrementally reparse the replaced range.
  let (root, range) = reparse(
    self.root,
    lines,
    start,
    end,
    utf8_len(replacement),
  )
  (
    {
      id: self.id,
      root,
      lines,
      serial: next_source_serial(),
      pristine: false,
      memo: false,
      memo_hi: 0,
      memo_lo: 0,
    },
    range,
  )
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
      // Upstream: `assert!(range.end <= overall.end)`.
      guard! e <= end
      Some((s, e))
    }
    None => Some((start, end))
  }
}
