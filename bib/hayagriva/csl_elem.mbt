// Port of `hayagriva/src/csl/elem.rs`.

///|
/// A container for elements with useful methods.
pub(all) struct Elem {
  /// The children of this element.
  mut children : ElemChildren
  /// The inline or block display of this element.
  display : @citationberg.Display?
  /// The CSL construct that created this element.
  meta : ElemMeta?
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with @debug.Debug::{to_repr}

///|
fn Elem::str_len(self : Elem) -> Int {
  let mut n = 0
  for c in self.children.0 {
    n += c.str_len()
  }
  n
}

///|
fn[W : FmtWrite] Elem::write_buf(
  self : Elem,
  w : W,
  format : BufWriteFormat,
) -> Unit {
  match (format, self.display) {
    (Html, Some(Block)) => w.write_str("<div>")
    (Html, Some(Indent)) => w.write_str("<div style=\"padding-left: 4em;\">")
    (Html, Some(LeftMargin)) => w.write_str("<div style=\"float: left;\">")
    (Html, Some(RightInline)) =>
      w.write_str("<div style=\"float: right; clear: both;\">")
    (_, Some(Block)) => w.write_char('\n')
    (_, _) => ()
  }
  for child in self.children.0 {
    child.write_buf(w, format)
  }
  match (format, self.display) {
    (Html, Some(_)) => w.write_str("</div>")
    (_, Some(Block)) => w.write_char('\n')
    (_, _) => ()
  }
}

///|
fn Elem::is_empty(self : Elem) -> Bool {
  self.children.is_empty()
}

///|
fn Elem::has_content(self : Elem) -> Bool {
  self.children.has_content()
}

///|
fn Elem::simplify(self : Elem) -> Elem {
  { ..self, children: simplify_children(self.children), }
}

///|
fn Elem::may_inline(self : Elem) -> Bool {
  self.display is None && self.meta is None
}

///|
/// A deep copy.
pub fn Elem::copy(self : Elem) -> Elem {
  { children: self.children.copy(), display: self.display, meta: self.meta, }
}

///|
pub impl Show for Elem with fn output(self, logger) {
  logger.write_string(fmt_to_string(b => self.write_buf(b, VT100)))
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with Show::{to_string, output}

///|
/// Merge adjacent text nodes with the same formatting.
pub fn simplify_children(children : ElemChildren) -> ElemChildren {
  // Upstream consumes its argument; copy it so that merging text in place
  // cannot affect shared nodes.
  let children = children.copy()
  let acc : Array[ElemChild] = []
  for child in children.0 {
    match (child, acc.last()) {
      (Text(t), Some(Text(last))) if last.formatting == t.formatting =>
        last.text = last.text + t.text
      (Elem(e), _) if e.may_inline() => acc.append(e.children.0)
      (Elem(e), _) => acc.push(Elem(e.simplify()))
      (child, _) => acc.push(child)
    }
  }
  ElemChildren(acc)
}

///|
/// Which CSL construct created an element.
pub(all) enum ElemMeta {
  /// The element is the output of `cs:names` with the names of the
  /// corresponding variables for this elem.
  Names(Array[(Array[Person], @citationberg.NameVariable)])
  /// The element is the output of `cs:date`.
  Date
  /// The element is the output of `cs:text`.
  Text
  /// The element is the output of `cs:number`.
  Number
  /// The element is the output of `cs:label`.
  Label
  /// The element is the output of `cs:number (variable="citation-number")`.
  CitationNumber
  /// The element is the output of a single name. It notes which name
  /// variable was used and the index within the variable.
  Name(@citationberg.NameVariable, Int)
  /// The entry corresponds to a citation item.
  Entry(Int)
  /// The element is the output of `cs:text` with a `variable` set to
  /// `citation-label`.
  CitationLabel
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemMeta with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemMeta with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemMeta with @debug.Debug::{to_repr}

///|
/// A container for element children with useful methods.
pub(all) struct ElemChildren(Array[ElemChild]) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChildren with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChildren with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChildren with @debug.Debug::{to_repr}

///|
/// Create an empty `ElemChildren`.
pub fn ElemChildren::new() -> ElemChildren {
  ElemChildren([])
}

///|
/// A deep copy.
pub fn ElemChildren::copy(self : ElemChildren) -> ElemChildren {
  ElemChildren(self.0.map(c => c.copy()))
}

///|
/// Whether this container is empty.
pub fn ElemChildren::is_empty(self : ElemChildren) -> Bool {
  self.0.iter().all(e => e.is_empty())
}

///|
/// Whether this container has any content other than whitespace.
pub fn ElemChildren::has_content(self : ElemChildren) -> Bool {
  self.0.iter().any(e => e.has_content())
}

///|
/// Retrieve a reference to the first child with a matching meta by DFS.
pub fn ElemChildren::find_meta(self : ElemChildren, meta : ElemMeta) -> Elem? {
  self.find_elem_by(e => e.meta == Some(meta))
}

///|
/// Retrieve a reference to the first child with a names meta by DFS.
pub fn ElemChildren::find_names(self : ElemChildren) -> Elem? {
  self.find_elem_by(e => e.meta is Some(Names(_)))
}

///|
/// Retrieve a mutable reference to the first child with a names meta by
/// DFS.
pub fn ElemChildren::find_names_mut(self : ElemChildren) -> Elem? {
  for c in self.0 {
    if c is Elem(e) {
      if e.meta is Some(Names(_)) {
        return Some(e)
      }
      if e.children.find_names_mut() is Some(r) {
        return Some(r)
      }
    }
  }
  None
}

///|
/// Retrieve a reference to the first child matching the predicate by DFS.
pub fn ElemChildren::find_elem_by(
  self : ElemChildren,
  f : (Elem) -> Bool,
) -> Elem? {
  for child in self.0 {
    match child {
      Elem(e) if f(e) => return Some(e)
      Elem(e) => if e.children.find_elem_by(f) is Some(r) { return Some(r) }
      _ => ()
    }
  }
  None
}

///|
/// Remove the first child with any meta by DFS.
pub fn ElemChildren::remove_any_meta(self : ElemChildren) -> ElemChild? {
  for i in 0..<self.0.length() {
    if self.0[i] is Elem(e) {
      if e.meta is Some(_) {
        return Some(self.0.remove(i))
      }
      if e.children.remove_any_meta() is Some(elem) {
        return Some(elem)
      }
    }
  }
  None
}

///|
/// Write the children to the given buffer.
pub fn[W : FmtWrite] ElemChildren::write_buf(
  self : ElemChildren,
  w : W,
  format : BufWriteFormat,
) -> Unit {
  for child in self.0 {
    child.write_buf(w, format)
  }
}

///|
/// Get the last text leaf.
pub fn ElemChildren::last_text(self : ElemChildren) -> Formatted? {
  last_text_child(self.0)
}

///|
fn last_text_child(children : Array[ElemChild]) -> Formatted? {
  match children.last() {
    Some(Text(t)) => Some(t)
    Some(Elem(e)) => last_text_child(e.children.0)
    _ => None
  }
}

///|
pub impl Show for ElemChildren with fn output(self, logger) {
  logger.write_string(fmt_to_string(b => self.write_buf(b, VT100)))
}

///|
pub extend ElemChildren with Show::{to_string, output}

///|
/// The plain text of the children.
pub fn ElemChildren::to_plain(self : ElemChildren) -> String {
  fmt_to_string(b => self.write_buf(b, Plain))
}

///|
/// Various formattable elements.
pub(all) enum ElemChild {
  /// This is some text.
  Text(Formatted)
  /// A child element.
  Elem(Elem)
  /// This should be processed by Typst.
  Markup(String)
  /// This is a link.
  Link(text~ : Formatted, url~ : String)
  /// A transparent element that must be replaced by the consumer.
  Transparent(cite_idx~ : Int, format~ : Formatting)
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChild with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChild with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChild with @debug.Debug::{to_repr}

///|
/// A deep copy.
pub fn ElemChild::copy(self : ElemChild) -> ElemChild {
  match self {
    Text(t) => Text({ text: t.text, formatting: t.formatting, })
    Elem(e) => Elem(e.copy())
    Markup(m) => Markup(m)
    Link(text~, url~) =>
      Link(text={ text: text.text, formatting: text.formatting, }, url~)
    Transparent(..) => self
  }
}

///|
/// Write the child to a buffer.
pub fn[W : FmtWrite] ElemChild::write_buf(
  self : ElemChild,
  w : W,
  format : BufWriteFormat,
) -> Unit {
  match self {
    Text(t) => {
      t.formatting.write_start(w, format)
      w.write_str(t.text)
      t.formatting.write_end(w, format)
    }
    Elem(e) => e.write_buf(w, format)
    Markup(m) => w.write_str(m)
    Link(text~, url~) if format == Html => {
      w.write_str("<a href=\"")
      w.write_str(url)
      w.write_str("\">")
      text.formatting.write_start(w, format)
      w.write_str(text.text)
      text.formatting.write_end(w, format)
      w.write_str("</a>")
    }
    Link(text~, ..) => {
      text.formatting.write_start(w, format)
      w.write_str(text.text)
      text.formatting.write_end(w, format)
    }
    Transparent(..) => ()
  }
}

///|
fn ElemChild::str_len(self : ElemChild) -> Int {
  match self {
    Text(t) => t.text.length()
    Elem(e) => e.str_len()
    Markup(m) => m.length()
    Link(text~, ..) => text.text.length()
    Transparent(..) => 0
  }
}

///|
fn ElemChild::has_content(self : ElemChild) -> Bool {
  match self {
    Text({ text, .. }) | Markup(text) =>
      text.iter().any(c => !@unscanny.is_whitespace(c))
    Elem(e) => e.has_content()
    Link(..) => true
    Transparent(..) => true
  }
}

///|
fn ElemChild::is_empty(self : ElemChild) -> Bool {
  match self {
    Text({ text, .. }) | Markup(text) => text.is_empty()
    Elem(e) => e.is_empty()
    Link(text~, ..) => text.text.is_empty()
    Transparent(..) => false
  }
}

///|
pub impl Show for ElemChild with fn output(self, logger) {
  logger.write_string(fmt_to_string(b => self.write_buf(b, VT100)))
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ElemChild with Show::{to_string, output}

///|
/// The format with which to write an element.
pub(all) enum BufWriteFormat {
  /// Just write text.
  Plain
  /// Write with terminal colors.
  VT100
  /// Write HTML.
  Html
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BufWriteFormat with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BufWriteFormat with @debug.Debug::{to_repr}

///|
/// A piece of formatted text.
pub(all) struct Formatted {
  /// The text.
  mut text : String
  /// The formatting.
  formatting : Formatting
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Formatted with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Formatted with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Formatted with @debug.Debug::{to_repr}

///|
/// Some formatting information.
pub(all) struct Formatting {
  /// Whether the text is italic.
  font_style : @citationberg.FontStyle
  /// Whether the text is small caps.
  font_variant : @citationberg.FontVariant
  /// The font weight.
  font_weight : @citationberg.FontWeight
  /// Whether the text is underlined.
  text_decoration : @citationberg.TextDecoration
  /// Whether the text is superscript or subscript.
  vertical_align : @citationberg.VerticalAlign
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Formatting with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Formatting with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Formatting with @debug.Debug::{to_repr}

///|
pub impl Default for Formatting with fn default() {
  {
    font_style: Normal,
    font_variant: Normal,
    font_weight: Normal,
    text_decoration: None_,
    vertical_align: None_,
  }
}

///|
pub extend Formatting with Default::{default}

///|
pub fn Formatting::add_text(self : Formatting, text : String) -> Formatted {
  { text, formatting: self, }
}

///|
/// Apply a partial formatting on top of this formatting.
pub fn Formatting::apply(
  self : Formatting,
  other : @citationberg.Formatting,
) -> Formatting {
  {
    font_style: other.font_style.unwrap_or(self.font_style),
    font_variant: other.font_variant.unwrap_or(self.font_variant),
    font_weight: other.font_weight.unwrap_or(self.font_weight),
    text_decoration: other.text_decoration.unwrap_or(self.text_decoration),
    vertical_align: other.vertical_align.unwrap_or(self.vertical_align),
  }
}

///|
fn[W : FmtWrite] Formatting::write_vt100(self : Formatting, buf : W) -> Unit {
  if self.font_style == Italic {
    buf.write_str("\u{1b}[3m")
  }
  if self.font_weight == Bold {
    buf.write_str("\u{1b}[1m")
  } else if self.font_weight == Light {
    buf.write_str("\u{1b}[2m")
  }
  if self.text_decoration == Underline {
    buf.write_str("\u{1b}[4m")
  }
}

///|
fn[W : FmtWrite] Formatting::write_css(self : Formatting, buf : W) -> Unit {
  if self.font_style == Italic {
    buf.write_str("font-style: italic;")
  }
  match self.font_weight {
    Bold => buf.write_str("font-weight: bold;")
    Light => buf.write_str("font-weight: lighter;")
    _ => ()
  }
  if self.text_decoration == Underline {
    buf.write_str("text-decoration: underline;")
  }
  if self.font_variant == SmallCaps {
    buf.write_str("font-variant: small-caps;")
  }
  match self.vertical_align {
    Sub => buf.write_str("vertical-align: sub;")
    Sup => buf.write_str("vertical-align: super;")
    _ => ()
  }
}

///|
fn[W : FmtWrite] Formatting::write_start(
  self : Formatting,
  buf : W,
  format : BufWriteFormat,
) -> Unit {
  match format {
    Plain => ()
    VT100 => self.write_vt100(buf)
    Html => {
      let is_default = self == Formatting::default()
      if !is_default {
        buf.write_str("<span style=\"")
        self.write_css(buf)
        buf.write_str("\">")
      }
    }
  }
}

///|
fn[W : FmtWrite] Formatting::write_end(
  self : Formatting,
  buf : W,
  format : BufWriteFormat,
) -> Unit {
  match format {
    Plain => ()
    VT100 => buf.write_str("\u{1b}[0m")
    Html => {
      let is_default = self == Formatting::default()
      if !is_default {
        buf.write_str("</span>")
      }
    }
  }
}

///|
priv struct NonEmptyStack[T] {
  head : Array[T]
  mut last : T
}

///|
fn[T] NonEmptyStack::new(last : T) -> NonEmptyStack[T] {
  { head: [], last, }
}

///|
fn[T] NonEmptyStack::first(self : NonEmptyStack[T]) -> T {
  match self.head.get(0) {
    Some(x) => x
    None => self.last
  }
}

///|
/// Find the last item matching the predicate.
fn[T] NonEmptyStack::last_predicate(
  self : NonEmptyStack[T],
  predicate : (T) -> Bool,
) -> T? {
  let len = self.len()
  let mut x = len - 1
  while x >= 0 {
    let item = self.get(x)
    if predicate(item) {
      return Some(item)
    }
    x -= 1
  }
  None
}

///|
fn[T] NonEmptyStack::get(self : NonEmptyStack[T], idx : Int) -> T {
  if idx + 1 == self.len() {
    self.last
  } else {
    self.head[idx]
  }
}

///|
fn[T] NonEmptyStack::len(self : NonEmptyStack[T]) -> Int {
  self.head.length() + 1
}

///|
fn[T] NonEmptyStack::push(self : NonEmptyStack[T], elem : T) -> Unit {
  self.head.push(self.last)
  self.last = elem
}

///|
fn[T] NonEmptyStack::pop(self : NonEmptyStack[T]) -> T? {
  match self.head.pop() {
    Some(new_last) => {
      let old = self.last
      self.last = new_last
      Some(old)
    }
    None => None
  }
}

///|
/// Drops all elements including and after the given index.
fn[T] NonEmptyStack::drain(self : NonEmptyStack[T], idx : Int) -> Unit {
  // `idx` is the length of the stack before the elements were pushed.
  self.last = self.head[idx - 1]
  self.head.truncate(idx - 1)
}

///|
fn[T] NonEmptyStack::items(self : NonEmptyStack[T]) -> Array[T] {
  [..self.head, self.last]
}

///|
fn[T] NonEmptyStack::finish(self : NonEmptyStack[T]) -> T {
  if !self.head.is_empty() {
    abort("NonEmptyStack::finish called with non-empty stack")
  }
  self.last
}
