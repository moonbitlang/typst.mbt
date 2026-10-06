// Lints (docs/edsl-ports.md, section 6): checks of the EDSL that the
// engine does not make. They are not diagnostics of the engine (those
// stay `errors` and `warnings`, upstream's): a lint says that a document
// that compiles is probably not what its author meant. A report has them
// in `lints`; `lints=false` on `compile*` turns them off.
//
// Here: the shape of a lint, and L1, adjacent inline items, which reads
// the description tree. The lints of section 6 that read the frames (L2,
// L3) and L4 are later steps.

///|
/// What a lint checks. Later checks add cases: a `match` on the kind
/// needs a wildcard case.
pub(all) enum LintKind {
  /// L1: two neighbours in the array of a `Document` or `Seq` are text
  /// (two `Prose`, or any text where the array also holds a block): the
  /// two are typeset as one paragraph with nothing between them.
  AdjacentInline
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LintKind with Eq::{not_equal, equal}

///|
/// The name of the check, as `render` writes it (`adjacent-inline`).
pub fn LintKind::name(self : LintKind) -> String {
  match self {
    AdjacentInline => "adjacent-inline"
  }
}

///|
/// A finding of a lint.
pub struct Lint {
  kind : LintKind
  message : String
  /// What to do about it, and further places it concerns (a hint with a
  /// location).
  hints : Array[Hint]
  /// Where it is. For L1 the argument that has the text of the item: the
  /// origin that the review loop gives for that text on the page, so
  /// `ReviewText::origin_positions` finds its boxes (there are none if
  /// all of a `Prose` is interpolated descriptions, which have origins of
  /// their own). `None` if a lint cannot name a place.
  location : Location?
}

///|
/// The lint as text: its kind and message, its location and its hints,
/// in the form of `Diagnostic::render`.
pub fn Lint::render(self : Lint) -> String {
  let out = StringBuilder()
  out.write_string("lint[")
  out.write_string(self.kind.name())
  out.write_string("]: ")
  out.write_string(self.message)
  if self.location is Some(location) {
    out.write_string("\n  at ")
    out.write_string(location.describe())
  }
  for hint in self.hints {
    out.write_string("\n  hint: ")
    out.write_string(hint.message)
    if hint.location is Some(location) {
      out.write_string(" (")
      out.write_string(location.describe())
      out.write_string(")")
    }
  }
  out.to_string()
}

///|
/// The origin of a call site as the review loop reports it
/// (`Origins::resolve`), without a registry: the call, or its parameter
/// `param` if the call has the location of that argument; under the keys
/// of the enclosing `Keyed` wrappers.
fn Site::origin(self : Site, keys : Array[String], param : Int?) -> Origin {
  let ArgsLoc(arg_locs) = self.args
  // (Inside a composite: the parameter of the composite, `Site::param`.)
  let (loc, param) = match param.map(p => self.param(p)) {
    Some(p) if p >= 0 && p < arg_locs.length() && arg_locs[p] is Some(arg) =>
      (arg.to_string(), Some(p))
    _ => (self.loc.to_string(), Option::None)
  }
  let (file, module_name, start_line, start_column, end_line, end_column) = parse_loc(
    loc,
  )
  {
    file,
    module_name,
    start_line,
    start_column,
    end_line,
    end_column,
    kind: self.origin_kind(),
    keys: keys.copy(),
    param,
    text_range: Option::None,
  }
}

// L1: adjacent inline items.
//
// What an author writes as two paragraphs,
//
//   Document([Heading("Results"), Prose("One ends here."), Prose("Two starts here.")])
//
// is one paragraph that reads "One ends here.Two starts here.": `Prose`,
// strings and `Text` are inline content, and a sequence puts nothing
// between its items (finding S1 of the ports).
//
// The rule, on the description tree as the author built it:
//
// - It looks at the item arrays of `Document` and `Seq`, wherever they
//   are in the tree, but not inside callbacks (their results do not exist
//   before layout), the generic `Call` and call values, `Markup` and
//   `Equation`, and engine content (views).
// - An item is *text* if it is a string, a `Prose`, or a `Text`,
//   `Strong`, `Emph` or `Link` whose body is text. `Keyed` and a label do
//   not change what an item is. Nothing else is text: not an empty
//   string, not a `Lit` (the translator of `doc/convert` writes markup as
//   a stream of `Lit`s and spaces between `Parbreak`s, which is one
//   paragraph by intent), not `Raw`, a `Box`, a `Symbol`, `Quoted` or a
//   nested `Seq`.
// - An item is a *block* if it is one of the constructors of
//   `is_block_call` (below): what the engine lays out as a block of the
//   flow or what ends a paragraph, whatever its arguments are.
// - Two neighbours of an array that are both text are reported
//   (a) if both are a `Prose` itself (not one inside `Text`, `Strong`,
//       `Emph` or `Link`), in any array; or
//   (b) if the array also holds a block.
//   Neighbours are adjacent items of the array: with a rule (or anything
//   else) between them, two items are not neighbours. A pair is not
//   reported if a block is interpolated at its seam (the first is a
//   `Prose` that ends with one, or the second starts with one): that
//   block separates the two.
//
// (a): a `Prose` drops the white space at its edges, so two in a row
// never have anything between them, and nobody means "here.Two". No
// document of the tests, the twins or the ports has such a pair but the
// ones that show the defect.
//
// (b): for the other kinds the block is the evidence that the array is a
// flow of blocks, in which a run of text is a paragraph of its own; an
// array without one may be the body of a paragraph, where
// `["Typeset with ", Emph("care"), "."]` is the way to write it. So the
// lint has false negatives by design (strings and wrapped text in an
// array without a block), and it reports a correct document only where an
// author composes one paragraph from several text items directly between
// blocks, which reads better as one `Par(Seq([..]))`.

///|
/// Whether a call makes a block: an element that the engine lays out as a
/// block of the flow, or that ends a paragraph, so that it cannot be part
/// of a paragraph and the array that has it holds flow content. The list
/// is what the show rules of `layout/rules.mbt` wrap in a `BlockElem`
/// unconditionally (upstream `typst-layout/src/rules.rs`), the elements
/// of the flow itself, the items that realization groups into a list,
/// and `align`, whose style interrupts a paragraph (`realize.mbt`,
/// `finish_interrupted`); `raw`, `quote` and equations only with a
/// literal `block=true`. (A `Para` is a block, too: `is_block`.)
/// `doc/lint_wbtest.mbt` checks every entry, and that the other
/// constructors of the generator's element table are not blocks, against
/// what the engine does with them between two strings.
fn is_block_call(call : CallNode) -> Bool {
  guard call.func is FElem(elem) else { return false }
  // Model.
  elem == @library.heading_elem() ||
  elem == @library.par_elem() ||
  elem == @library.parbreak_elem() ||
  elem == @library.list_elem() ||
  elem == @library.list_item_elem() ||
  elem == @library.enum_elem() ||
  elem == @library.enum_item_elem() ||
  elem == @library.terms_elem() ||
  elem == @library.term_item_elem() ||
  elem == @library.figure_elem() ||
  elem == @library.table_elem() ||
  elem == @library.outline_elem() ||
  elem == @library.title_elem() ||
  elem == @library.bibliography_elem() ||
  // Layout.
  elem == @library.block_elem() ||
  elem == @library.align_elem() ||
  elem == @library.page_elem() ||
  elem == @library.pagebreak_elem() ||
  elem == @library.colbreak_elem() ||
  elem == @library.v_elem() ||
  elem == @library.place_elem() ||
  elem == @library.pad_elem() ||
  elem == @library.stack_elem() ||
  elem == @library.grid_elem() ||
  elem == @library.columns_elem() ||
  elem == @library.repeat_elem() ||
  elem == @library.move_elem() ||
  elem == @library.rotate_elem() ||
  elem == @library.scale_elem() ||
  elem == @library.skew_elem() ||
  // Visualize.
  elem == @library.image_elem() ||
  elem == @library.line_elem() ||
  elem == @library.rect_elem() ||
  elem == @library.square_elem() ||
  elem == @library.ellipse_elem() ||
  elem == @library.circle_elem() ||
  elem == @library.polygon_elem() ||
  elem == @library.curve_elem() ||
  // Inline unless the call says `block=true`.
  (
    (elem == @library.raw_elem() || elem == @library.quote_elem()) &&
    says_block(call.args)
  )
}

///|
/// Whether the arguments have a literal `block: true` (the last one
/// wins, as in Typst).
fn says_block(args : Array[ArgNode]) -> Bool {
  let mut block = false
  for arg in args {
    if arg.name is Some("block") {
      block = arg.value.val is VBool(true)
    }
  }
  block
}

///|
/// Whether a description is a block (`is_block_call`), also with a label
/// or a key, a display equation, or a `Para`.
fn is_block(content : Content) -> Bool {
  match content.node {
    NKeyed(_, body) | NLabelled(body, _, _, _) | NComposite(body, _) =>
      is_block(body)
    NCall(call) => is_block_call(call)
    NEval(node) => node.mode is Math && says_block(node.args)
    // A `Para`: its text is between two paragraph breaks.
    NSeq(_, site) => site.kind == "Para"
    _ => false
  }
}

///|
/// The body argument of a call of `Text`, `Strong`, `Emph` or `Link`
/// (`None` for other calls, and for a link without a body): the first
/// positional argument, after the destination for a link.
fn wrapper_body(call : CallNode) -> ArgNode? {
  guard call.func is FElem(elem) else { return Option::None }
  let at = if elem == @library.link_elem() {
    1
  } else if elem == @library.text_elem() ||
    elem == @library.strong_elem() ||
    elem == @library.emph_elem() {
    0
  } else {
    return Option::None
  }
  let mut n = 0
  for arg in call.args {
    guard arg.name is Option::None else { continue }
    if n == at {
      return Some(arg)
    }
    n += 1
  }
  Option::None
}

///|
/// Whether a description is text for L1: a string, a `Prose`, or a
/// `Text`, `Strong`, `Emph` or `Link` whose body is one, also with a
/// label or a key.
fn is_text_item(content : Content) -> Bool {
  match content.node {
    NKeyed(_, body) | NLabelled(body, _, _, _) | NComposite(body, _) =>
      is_text_item(body)
    // (An empty string is nothing on the page.)
    NText(text, Option::None) => text != ""
    NSeq(_, site) => site.kind == "Prose"
    NCall(call) =>
      wrapper_body(call) is Some({ value: { val: VContent(body), }, .. }) &&
      is_text_item(body)
    _ => false
  }
}

///|
/// The origin of the text of a text item (`is_text_item`), as the review
/// loop gives it for that text on the page (`Origins::resolve`): the text
/// argument of a `Prose`, and for a plain string the argument that it is
/// in: parameter `param` of `site`, which is the array
/// for an item and the body for a string in `Text`, `Strong`, `Emph` or
/// `Link`; under the keys of the `Keyed` wrappers.
fn text_origin(
  content : Content,
  site : Site,
  param : Int,
  keys : Array[String],
) -> Origin {
  match content.node {
    NKeyed(key, body) => {
      let keys = keys.copy()
      keys.push(key)
      text_origin(body, site, param, keys)
    }
    // (A label of a constructor is on a call, which has its own origin;
    // the body of `Labelled(body, label)` is that call's first argument.)
    NLabelled(body, _, own, _) => text_origin(body, own, 0, keys)
    // (The result of a composite is its call.)
    NComposite(body, own) => text_origin(body, own, -1, keys)
    NSeq(_, own) => own.origin(keys, Some(0))
    NCall(call) =>
      match wrapper_body(call) {
        Some({ value: { val: VContent(body), }, param: at, .. }) =>
          text_origin(body, call.origin, at, keys)
        _ => call.origin.origin(keys, Option::None)
      }
    _ => site.origin(keys, Some(param))
  }
}

///|
/// Whether the last (`last`) or first piece of a text item is a block: a
/// `Prose` that ends or starts with an interpolated block (`is_block`),
/// which ends the paragraph there.
fn block_at_edge(content : Content, last : Bool) -> Bool {
  match content.node {
    NKeyed(_, body) | NLabelled(body, _, _, _) | NComposite(body, _) =>
      block_at_edge(body, last)
    NSeq(children, _) =>
      children.length() > 0 &&
      is_block(if last { children[children.length() - 1] } else { children[0] })
    NCall(call) =>
      match wrapper_body(call) {
        Some({ value: { val: VContent(body), }, .. }) =>
          block_at_edge(body, last)
        _ => false
      }
    _ => false
  }
}

///|
/// How many characters of each text a message shows at the seam.
const SEAM_CHARS : Int = 16

///|
/// The text at an edge of a text item, for the message: its last (`last`)
/// or first characters, with an ellipsis where the text goes on. `None`
/// where the text at the edge is not known (an interpolated description
/// or a quote at the edge of a `Prose`).
fn edge_text(content : Content, last : Bool) -> String? {
  match content.node {
    NKeyed(_, body) | NLabelled(body, _, _, _) | NComposite(body, _) =>
      edge_text(body, last)
    NText(text, _) => Some(clip_text(text.to_array(), last, false))
    // A `Prose`: its words and the spaces between them, from the edge up
    // to a piece that is something else.
    NSeq(children, _) => {
      let mut chars : Array[Char] = []
      let n = children.length()
      let mut taken = 0
      while taken < n && chars.length() < SEAM_CHARS {
        let child = if last { children[n - 1 - taken] } else { children[taken] }
        let piece = match child.node {
          NText(text, Option::None) => text.to_array()
          NSpace(_) => [' ']
          _ => break
        }
        if last {
          piece.append(chars)
          chars = piece
        } else {
          chars.append(piece)
        }
        taken += 1
      }
      guard chars.length() > 0 else { return Option::None }
      Some(clip_text(chars, last, taken < n))
    }
    NCall(call) =>
      match wrapper_body(call) {
        Some({ value: { val: VContent(body), }, .. }) => edge_text(body, last)
        _ => Option::None
      }
    _ => Option::None
  }
}

///|
/// The last (`last`) or first `SEAM_CHARS` characters of a text, with an
/// ellipsis where it is cut or where `more` says that the text goes on.
fn clip_text(chars : Array[Char], last : Bool, more : Bool) -> String {
  // (A message is one line: a line break of the text is shown as a space.)
  let chars = chars.map(c => {
    if c == '\n' || c == '\r' || c == '\t' {
      ' '
    } else {
      c
    }
  })
  let count = SEAM_CHARS
  if chars.length() <= count {
    let text = String::from_array(chars)
    return if !more { text } else if last { "…" + text } else { text + "…" }
  }
  if last {
    "…" + String::from_array(chars[chars.length() - count:])
  } else {
    String::from_array(chars[:count]) + "…"
  }
}

///|
/// The state of a lint run over a description tree.
priv struct Linter {
  lints : Array[Lint]
  /// What was reported, by the source locations of its two texts: a
  /// description that is used in several places, or built by a function
  /// for every row of some data (under `Keyed` or not), is reported once,
  /// with the keys of its first occurrence.
  seen : Map[String, Unit]
}

///|
/// The source location of an origin (without its keys), for `seen`.
fn place_key(origin : Origin) -> String {
  let param = match origin.param {
    Some(p) => p
    Option::None => -1
  }
  "\{origin.file}\u{0}\{origin.module_name}\u{0}\{origin.start_line}:\{origin.start_column}-\{origin.end_line}:\{origin.end_column}\u{0}\{param}"
}

///|
/// Whether a description is a `Prose` itself, also with a label or a key.
fn is_prose(content : Content) -> Bool {
  match content.node {
    NKeyed(_, body) | NLabelled(body, _, _, _) | NComposite(body, _) =>
      is_prose(body)
    NSeq(_, site) => site.kind == "Prose"
    _ => false
  }
}

///|
/// L1 for one array: every pair of neighbours that are both a `Prose`,
/// and, if the array holds a block, every pair of neighbours that are
/// text.
fn Linter::adjacent(
  self : Linter,
  children : Array[Content],
  array : Site,
  keys : Array[String],
) -> Unit {
  let mut flow = false
  for child in children {
    if is_block(child) {
      flow = true
      break
    }
  }
  for i in 1..<children.length() {
    let before = children[i - 1]
    let item = children[i]
    guard is_text_item(before) && is_text_item(item) else { continue }
    guard flow || (is_prose(before) && is_prose(item)) else { continue }
    // A block that is interpolated at the seam separates the two.
    guard !block_at_edge(before, true) && !block_at_edge(item, false) else {
      continue
    }
    let first = text_origin(before, array, 0, keys)
    let second = text_origin(item, array, 0, keys)
    let key = "\{place_key(first)}\u{1}\{place_key(second)}"
    guard !self.seen.contains(key) else { continue }
    self.seen[key] = ()
    // What the page reads, where the text at the seam is known.
    let seam = match (edge_text(before, true), edge_text(item, false)) {
      (Some(a), Some(b)) => ": \"" + a + b + "\""
      _ => ""
    }
    self.lints.push({
      kind: AdjacentInline,
      message: "this text and the text before it are typeset as one paragraph with nothing between them\{seam}",
      hints: [
        { message: "the text before it", location: Some(Edsl(first)), },
        {
          message: "a paragraph of text is `Para(..)`; pieces of one paragraph go in one `Par(Seq([..]))`",
          location: Option::None,
        },
      ],
      location: Some(Edsl(second)),
    })
  }
}

///|
/// Run the lints of the description tree on `content`, under the keys of
/// the enclosing `Keyed` wrappers.
fn Linter::content(
  self : Linter,
  content : Content,
  keys : Array[String],
) -> Unit {
  match content.node {
    NSeq(children, site) => {
      if site.kind == "Document" || site.kind == "Seq" {
        self.adjacent(children, site, keys)
      }
      for child in children {
        self.content(child, keys)
      }
    }
    NPieces(children) =>
      for child in children {
        self.content(child, keys)
      }
    // The generic `Call` is not looked through: its arguments are values
    // of a function that the lint knows nothing about.
    NCall(call) => if !(call.func is FPath(_)) { self.args(call.args, keys) }
    // The arguments of a set rule, also of the generic `Set`: they are
    // stored descriptions like those of `SetPage(header=..)`.
    NSetRule(set) => self.args(set.args, keys)
    NShowRule(show) =>
      match show.transform {
        // A callback's result does not exist before layout.
        TFunc(_) => ()
        TStyle(set) => self.args(set.args, keys)
        TValue(value) => self.value(value, keys)
      }
    NLabelled(body, _, _, _) | NComposite(body, _) => self.content(body, keys)
    NKeyed(key, body) => {
      let keys = keys.copy()
      keys.push(key)
      self.content(body, keys)
    }
    NValue(value) => self.value(value, keys)
    // Callbacks, Typst source, engine content, and what has no children.
    NContext(_, _)
    | NEval(_)
    | NEngine(_)
    | NText(_, _)
    | NSpace(_)
    | NInvalid(_, _, _) => ()
  }
}

///|
fn Linter::args(
  self : Linter,
  args : Array[ArgNode],
  keys : Array[String],
) -> Unit {
  for arg in args {
    self.value(arg.value, keys)
  }
}

///|
/// The descriptions inside a value: content, the items of arrays and
/// dictionaries and the operands of operators. Call values are not looked
/// through.
fn Linter::value(self : Linter, value : Value, keys : Array[String]) -> Unit {
  match value.val {
    VContent(content) => self.content(content, keys)
    VAdd(a, b) | VSub(a, b) | VMul(a, b) | VDiv(a, b) => {
      self.value(a, keys)
      self.value(b, keys)
    }
    VNeg(a) => self.value(a, keys)
    VArray(items) =>
      for item in items {
        self.value(item, keys)
      }
    VDict(pairs) =>
      for pair in pairs {
        self.value(pair.1, keys)
      }
    VSpread(inner) => self.value(inner, keys)
    _ => ()
  }
}

///|
/// The lints of the description tree of a document, in document order.
fn Document::lint_tree(self : Document) -> Array[Lint] {
  let linter : Linter = { lints: [], seen: Map([]), }
  linter.content(self.content, [])
  linter.lints
}
