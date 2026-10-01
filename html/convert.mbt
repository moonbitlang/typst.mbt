// Port of `typst-html/src/convert.rs`.

///|
/// What and how to convert.
pub(all) enum ConversionLevel {
  /// Converts the top-level nodes or children of a block-level element. The
  /// conversion has its own local smart quoting state and space protection.
  Block
  /// Converts the children of an inline-level HTML element as part of a
  /// larger context with shared smart quoting state and shared space
  /// protection.
  Inline(@library.SmartQuoter)
}

///|
/// How to emit whitespace.
pub(all) enum Whitespace {
  /// Ensures that whitespace that would otherwise be collapsed by HTML
  /// rendering engines[^1] is protected by spans with `white-space:
  /// pre-wrap`. The affected by whitespace are ASCII spaces and ASCII tabs.
  ///
  /// Tries to emit spans only when necessary.
  /// - ASCII tabs and consecutive sequences of spaces and/or tabs are always
  ///   wrapped in spans in this mode. This happens directly during
  ///   conversion.
  /// - Single ASCII spaces are only wrapped if they aren't supported by
  ///   normal elements on both sides. This happens in a separate pass that
  ///   runs for the whole block-level context as doing this properly needs
  ///   lookahead and lookbehind across different levels of the element
  ///   hierarchy.
  ///
  /// [^1]: <https://www.w3.org/TR/css-text-3/#white-space-rules>
  Normal
  /// The whitespace is emitted as-is. This happens in
  /// - `<pre>` elements as they already have `white-space: pre`,
  /// - raw and escapable raw text elements as normal white space rules do not
  ///   apply to them.
  Pre
} derive(Eq, Hash, Debug)

///|
/// Converts realized content into HTML nodes.
pub fn convert_to_nodes(
  engine : @library.Engine,
  locator : @library.SplitLocator,
  children : ArrayView[@library.Pair],
  level : ConversionLevel,
  whitespace : Whitespace,
) -> Array[HtmlNode] raise @library.SourceError {
  let block = level is Block
  let converter : Converter = {
    engine,
    locator,
    quoter: match level {
      Inline(quoter) => quoter
      Block => @library.SmartQuoter::new()
    },
    whitespace,
    output: [],
    trailing: None,
  }
  for pair in children {
    let (child, styles) = pair
    handle(converter, child, styles)
  }
  let nodes = converter.finish()
  if block && whitespace == Normal {
    protect_spaces(nodes)
  }
  nodes
}

///|
/// Converts one element into HTML node(s).
fn handle(
  converter : Converter,
  child : @library.Content,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  if @library.TagElem::of(child) is Some(elem) {
    converter.push(Tag(elem.tag()))
  } else if @library.HtmlElem::of(child) is Some(elem) {
    handle_html_elem(converter, elem, styles)
  } else if child.is_(@library.space_elem()) {
    converter.push(HtmlNode::text(" ", child.span()))
  } else if @library.TextElem::of(child) is Some(elem) {
    let text = match @library.TextElem::case_in(styles) {
      Some(case) => case.apply(elem.text())
      None => elem.text()
    }
    handle_text(converter, text, child.span())
  } else if @library.HElem::of(child) is Some(elem) && elem.amount().is_zero() {
    // Nothing to do for zero-sized spacing. This is sometimes used to
    // destruct spaces, e.g. in footnotes. See [`HElem::hole`].
  } else if @library.LinebreakElem::of(child) is Some(_) {
    converter.push(
      match converter.whitespace {
        Normal =>
          Element(HtmlElement::new(@library.tag_br).spanned(child.span()))
        Pre => HtmlNode::text("\n", child.span())
      },
    )
  } else if @library.SmartQuoteElem::of(child) is Some(elem) {
    let double = elem.double(styles)
    let quote = if elem.enabled(styles) {
      let before = last_char(converter.output)
      let quotes = @library.SmartQuotes::get(
        elem.quotes(styles),
        @library.TextElem::lang_in(styles),
        @library.TextElem::region_in(styles),
        elem.alternative(styles),
      )
      converter.quoter.quote(before, quotes, double)
    } else {
      @library.SmartQuotes::fallback(double)
    }
    handle_text(converter, quote, child.span())
  } else if @library.BoxElem::of(child) is Some(elem) {
    handle_box(converter, elem, styles)
  } else if @library.BlockElem::of(child) is Some(elem) {
    handle_block(converter, elem, styles)
  } else if @library.FrameElem::of(child) is Some(elem) {
    let span = child.span()
    let locator = converter.locator.next(span)
    let style = @library.TargetElem::set_target(@library.Target::Paged)
    let frame = (converter.engine.library.routines.layout_frame)(
      converter.engine,
      elem.body(),
      locator,
      styles.chain_one(style),
      @library.LayoutRegion::new(
        @library.Axes::splat(@library.Abs::inf()),
        @library.Axes::splat(false),
      ),
    )
    let node = Frame(HtmlFrame::new(frame, styles, span))
    // A frame is block-level by default like a Typst `image`. It can
    // be wrapped in a `box` to omit the `display` annotation.
    make_block_level(node).unwrap()
    converter.push(node)
  } else {
    converter.engine.sink.warn(
      @library.SourceDiagnostic::warning_at(
        child.span(),
        "\{child.elem().name()} was ignored during HTML export",
      ),
    )
  }
}

///|
/// Handles an HTML element.
fn handle_html_elem(
  converter : Converter,
  elem : @library.HtmlElem,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  let tag = elem.tag()
  let span = elem.pack().span()

  // See the docs of `HtmlElem::role` for why we filter out roles for `<p>`
  // elements.
  let role = @library.HtmlElem::role_in(styles).filter(_ => {
    tag != @library.tag_p
  })
  let mut children = []
  if elem.body(styles) is Some(body) {
    let whitespace = if converter.whitespace == Pre ||
      tag == @library.tag_pre ||
      tag.is_raw() ||
      tag.is_escapable_raw() {
      Pre
    } else {
      Normal
    }

    // The `role` attribute should only apply to the first element in the
    // hierarchy. Thus, we unset it for children if it is currently set.
    let styles = if role is Some(_) {
      styles.chain_one(@library.HtmlElem::set_role(None))
    } else {
      styles
    }
    if @library.CssDisplay::default_for(tag) == Some(Block) {
      children = html_block_fragment(
        converter.engine,
        body,
        converter.locator.next(span),
        styles,
        whitespace,
      )

      // Block-level elements reset the inline state. This part is
      // unfortunately untested as it's currently not possible to
      // create inline-level content next to block-level content
      // without a paragraph automatically appearing.
      converter.quoter.reset()
    } else if tag.is_mathml() {
      children = html_math_fragment(
        converter.engine,
        body,
        converter.locator,
        converter.quoter,
        styles,
        whitespace,
      )
    } else {
      children = html_inline_fragment(
        converter.engine,
        body,
        converter.locator,
        converter.quoter,
        styles,
        whitespace,
      )
    }
  }
  let attrs = elem.attrs(styles).copy()
  if role is Some(role) {
    attrs.push(@library.attr_role, role)
  }
  converter.push(
    Element({
      tag,
      attrs,
      css: elem.css(styles).copy(),
      children,
      parent: elem.parent(),
      span,
      pre_span: false,
    }),
  )
}

///|
/// Special kinds of characters.
priv enum Kind {
  /// ASCII space.
  Space
  /// ASCII tab.
  Tab
  /// CR, LF, or CR + LF.
  Newline
  /// A Unicode default-ignorable. Does not protect spaces from
  /// collapsing.
  Ignorable
} derive(Eq)

///|
fn Kind::of(c : Char) -> Kind? {
  match c {
    ' ' => Some(Space)
    '\t' => Some(Tab)
    '\r' | '\n' => Some(Newline)
    c if @unicode.is_default_ignorable(c) => Some(Ignorable)
    _ => None
  }
}

///|
/// Handles arbitrary text while taking care that no whitespace within will
/// be collapsed by browsers.
fn handle_text(
  converter : Converter,
  text : String,
  span : @syntax.Span,
) -> Unit {
  if converter.whitespace == Pre {
    converter.push(Text(text, span))
    return
  }
  let len = text.length()
  let mut emitted = 0
  let mut prev_kind : Kind?? = None
  let mut i = 0
  while i < len {
    let c = text.get_char(i).unwrap()
    let c_len = if c.to_int() > 0xFFFF { 2 } else { 1 }
    let kind = Kind::of(c)
    let prev = prev_kind
    prev_kind = Some(kind)
    guard kind is Some(kind) else {
      i += c_len
      continue
    }

    // A space that is surrounded by normal (i.e. not special) characters is
    // already protected and doesn't need further treatment.
    if kind == Space &&
      prev is Some(None) &&
      text.get_char(i + 1) is Some(after) &&
      Kind::of(after) is None {
      i += c_len
      continue
    }

    // Emit the unspecial text up to the special character.
    if emitted < i {
      converter.push_text(text.unsafe_substring(start=emitted, end=i), span)
      emitted = i
    }

    // Process the special character.
    match kind {
      Space => converter.push_text(" ", span)
      Tab => converter.push_text("\t", span)
      Newline => {
        if c == '\r' && text.get_char(i + 1) is Some('\n') {
          // Skip the CR because the LF will already turn into
          // a `<br>`.
          emitted += 1
          i += c_len
          continue
        }
        converter.push(Element(HtmlElement::new(@library.tag_br).spanned(span)))
      }
      Ignorable => converter.push_text(c.to_string(), span)
    }
    emitted += c_len
    i += c_len
  }

  // Push the remaining unspecial text.
  if emitted < len {
    converter.push_text(
      if emitted == 0 {
        text
      } else {
        text.unsafe_substring(start=emitted, end=len)
      },
      span,
    )
  }
}

///|
/// Processes a box element.
fn handle_box(
  converter : Converter,
  elem : @library.BoxElem,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  let mut children = []
  if elem.body(styles) is Some(body) {
    children = html_inline_fragment(
      converter.engine,
      body,
      converter.locator,
      converter.quoter,
      styles,
      converter.whitespace,
    )
    if to_lone_element(children) is Some(i) {
      make_inline_level(children[i])
      converter.extend_nodes(children)
      return
    }
  }
  converter.push(
    // TODO: This is rather incomplete.
    Element(
      HtmlElement::new(@library.tag_span)
      .with_css(@library.CssProperties::new().with_("display", "inline-block"))
      .with_children(children)
      .spanned(elem.pack().span()),
    ),
  )
}

///|
/// Ensures a lone HTML element/frame renders inline.
///
/// Paragraphs only allow "Phrasing content". The default display properties
/// that exists for valid phrasing content are `none`, `inline`,
/// `inline-block`, `contents`, `ruby`, and `inline math`. These can all be
/// left as-is.
///
/// If, however, the `display` property was set to something like `block`
/// through a Typst `block` element, we need to unset it. Further, if a math
/// element has its `display` attribute set to `block`, then we need to
/// override it.
fn make_inline_level(node : HtmlNode) -> Unit {
  let mode : @library.CssDisplay? = if node is Element(element) &&
    element.tag == @library.tag_mathml_math &&
    element.attrs.get(@library.attr_mathml_display) is Some("block") {
    Some(InlineMath)
  } else {
    None
  }
  set_display(node, mode)
}

///|
/// Processes a block element.
fn handle_block(
  converter : Converter,
  elem : @library.BlockElem,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  let body = match elem.body(styles) {
    None => None
    Some(Content(body)) => Some(body)
    // Upstream bails for `BlockBody::SingleLayouter` and `MultiLayouter`
    // ("blocks with layout routines should not occur in HTML export – this
    // is a bug"); these are only generated by native `typst-layout` show
    // rules and not ported.
  }
  let mut children = []
  if body is Some(body) {
    children = html_block_fragment(
      converter.engine,
      body,
      converter.locator.next(elem.pack().span()),
      styles,
      converter.whitespace,
    )
    if to_lone_element(children) is Some(i) &&
      make_block_level(children[i]) is Ok(_) {
      converter.extend_nodes(children)
      return
    }
  }
  converter.push(
    // TODO: This is rather incomplete.
    Element(
      HtmlElement::new(@library.tag_div)
      .with_children(children)
      .spanned(elem.pack().span()),
    ),
  )
}

///|
/// Indicates that an element can be made block-level with a `display`
/// property.
priv struct Unblockable(Unit)

///|
/// Ensures a lone HTML element/frame renders as its own block.
///
/// Configures the `display` property of the HTML node (if it is an element
/// or frame).
fn make_block_level(node : HtmlNode) -> Result[Unit, Unblockable] {
  let default : @library.CssDisplay? = match node {
    // A math element's default display property depends on its `display`
    // attribute.
    Element(element) if element.tag == @library.tag_mathml_math &&
      element.attrs.get(@library.attr_mathml_display) is Some("block") =>
      Some(BlockMath)
    Element(element) => @library.CssDisplay::default_for(element.tag)
    Frame(_) => Some(Inline)
    _ => return Err(Unblockable(()))
  }
  let mode : @library.CssDisplay? = match default {
    // These can be left unchanged / have `display` unset because they are
    // either invisible or already render in a block-level way.
    Some(None_ | Block | Table | ListItem | Contents | BlockMath) => None

    // These must be promoted to `block`.
    None | Some(Inline | InlineBlock) => Some(Block)
    Some(InlineMath) => Some(BlockMath)

    // These can't be promoted. They are instead wrapped in a `<div>`.
    _ => return Err(Unblockable(()))
  }
  set_display(node, mode)
  Ok(())
}

///|
/// Whether, apart from tags, the nodes comprise a single element or frame.
/// Returns the index of that node.
fn to_lone_element(nodes : Array[HtmlNode]) -> Int? {
  let mut start = 0
  while start < nodes.length() && nodes[start] is Tag(_) {
    start += 1
  }
  let mut end = nodes.length()
  while end > start && nodes[end - 1] is Tag(_) {
    end -= 1
  }
  if end - start == 1 && nodes[start] is (Element(_) | Frame(_)) {
    Some(start)
  } else {
    None
  }
}

///|
/// Sets the CSS `display` property for an element or frame.
fn set_display(node : HtmlNode, display : @library.CssDisplay?) -> Unit {
  let css = match node {
    Element(element) => {
      element.css = element.css.copy()
      element.css
    }
    Frame(frame) => {
      frame.css = frame.css.copy()
      frame.css
    }
    _ => return
  }
  match display {
    Some(display) => css.push("display", display.as_str())
    None => css.remove("display")
  }
}

///|
/// State during conversion.
priv struct Converter {
  engine : @library.Engine
  locator : @library.SplitLocator
  quoter : @library.SmartQuoter
  whitespace : Whitespace
  output : Array[HtmlNode]
  mut trailing : TrailingWhitespace?
}

///|
/// Keeps track of a trailing whitespace in the output.
priv struct TrailingWhitespace {
  /// If `true`, the trailing whitespace consists of exactly one ASCII space.
  mut single : Bool
  /// The trailing whitespace starts at `output[from..]`.
  from : Int
}

///|
/// Returns the converted nodes.
fn Converter::finish(self : Converter) -> Array[HtmlNode] {
  self.flush_whitespace()
  self.output
}

///|
/// Pushes a node, taking care to protect consecutive whitespace.
fn Converter::push(self : Converter, node : HtmlNode) -> Unit {
  if node is Text(text, _) && (text == " " || text == "\t") {
    match self.trailing {
      Some(ws) => ws.single = false
      None =>
        self.trailing = Some({
          single: text == " ",
          from: self.output.length(),
        })
    }
  } else if !(node is Tag(_)) {
    self.flush_whitespace()
  }
  self.output.push(node)
}

///|
/// Pushes multiples nodes.
fn Converter::extend_nodes(self : Converter, nodes : Array[HtmlNode]) -> Unit {
  for node in nodes {
    self.push(node)
  }
}

///|
/// Shorthand for pushing a text node.
fn Converter::push_text(
  self : Converter,
  text : String,
  span : @syntax.Span,
) -> Unit {
  self.push(Text(text, span))
}

///|
/// If there is trailing whitespace in need of protection, protects it.
///
/// Does not protect single ASCII spaces. Those are handled in a separate
/// pass as they are more complex and require lookahead. See the
/// documentation of [Whitespace] for more information.
fn Converter::flush_whitespace(self : Converter) -> Unit {
  if self.whitespace == Normal {
    let trailing = self.trailing
    self.trailing = None
    if trailing is Some({ single: false, from, }) {
      let nodes = self.output[from:].to_owned()
      self.output.truncate(from)
      self.output.push(Element(pre_wrap(nodes)))
    }
  }
}

///|
/// Protects all spaces in the given block-level `nodes` against collapsing.
///
/// Does not recurse into block-level elements as those are separate contexts
/// with their own space protection.
fn protect_spaces(nodes : Array[HtmlNode]) -> Unit {
  let p = Protector::new()
  p.visit_nodes(nodes)
  p.collapsing()
}

///|
/// A state machine for whitespace protection.
priv enum ProtectorState {
  Collapsing
  Supportive
  /// A single space: the node at the index in the array.
  Space(Array[HtmlNode], Int)
}

///|
priv struct Protector {
  mut state : ProtectorState
}

///|
/// Creates a new protector.
fn Protector::new() -> Protector {
  { state: Collapsing, }
}

///|
/// Visits the given nodes and protects single spaces that need to be saved
/// from collapsing.
fn Protector::visit_nodes(self : Protector, nodes : Array[HtmlNode]) -> Unit {
  for i in 0..<nodes.length() {
    match nodes[i] {
      Tag(_) => ()
      Text(text, _) =>
        if text == " " {
          match self.state {
            Collapsing => {
              protect_space(nodes, i)
              self.state = Supportive
            }
            Supportive => self.state = Space(nodes, i)
            Space(prev, j) => {
              protect_space(prev, j)
              self.state = Space(nodes, i)
            }
          }
        } else if text.iter().any(c => !@unicode.is_default_ignorable(c)) {
          self.supportive()
        }
      Element(element) =>
        if element.tag.is_whitespace_collapsing() {
          self.collapsing()
        } else if element.tag.is_replaced() {
          self.supportive()
        } else if !element.pre_span {
          // Recursively visit the children of inline-level elements while
          // making sure to not revisit pre-wrapped spans that we've
          // generated ourselves.
          self.visit_nodes(element.children)
        }
      Frame(_) => self.supportive()
    }
  }
}

///|
/// Called when visiting an element that would collapse adjacent single
/// spaces. A preceding, if any, and succeeding, if any, single space will
/// then be protected .
fn Protector::collapsing(self : Protector) -> Unit {
  let state = self.state
  self.state = Collapsing
  if state is Space(nodes, i) {
    protect_space(nodes, i)
  }
}

///|
/// Called when visiting an element that supports adjacent single spaces.
fn Protector::supportive(self : Protector) -> Unit {
  self.state = Supportive
}

///|
/// Protects a single spaces against collapsing.
fn protect_space(nodes : Array[HtmlNode], i : Int) -> Unit {
  nodes[i] = Element(pre_wrap([nodes[i]]))
}

///|
/// Wraps a collection of whitespace nodes in a
/// `<span style="white-space: pre-wrap">..</span>` to avoid them being
/// collapsed by HTML rendering engines.
fn pre_wrap(nodes : Array[HtmlNode]) -> HtmlElement {
  let mut span = @syntax.Span::detached()
  for node in nodes {
    let s = node.span()
    if !s.is_detached() {
      span = s
      break
    }
  }
  let elem = HtmlElement::new(@library.tag_span)
    .with_css(@library.CssProperties::new().with_("white-space", "pre-wrap"))
    .with_children(nodes)
    .spanned(span)
  elem.pre_span = true
  elem
}

///|
/// Returns the last non-default ignorable character from the passed nodes.
fn last_char(nodes : ArrayView[HtmlNode]) -> Char? {
  for i = nodes.length() - 1; i >= 0; i = i - 1 {
    let c = match nodes[i] {
      Text(s, _) => {
        let mut found = None
        for c in s.rev_iter() {
          if !@unicode.is_default_ignorable(c) {
            found = Some(c)
            break
          }
        }
        found
      }
      Element(e) => last_char(e.children)
      _ => None
    }
    if c is Some(_) {
      return c
    }
  }
  None
}
