// Port of `typst-html/src/encode.rs`: encodes an HTML DOM into a string.

///|
/// Settings for HTML export (upstream `HtmlOptions<Partial>`).
pub(all) struct HtmlOptions {
  /// Format options that override the defaults set by the document.
  format : @library.PartialHtmlFormatOptions
} derive(Eq, Default)

///|
pub extend HtmlOptions with Default::{default}

///|
/// Resolved settings for HTML export (upstream `HtmlOptions<Complete>`).
pub(all) struct CompleteHtmlOptions {
  /// The resolved format options.
  format : @library.HtmlFormatOptions
} derive(Eq)

///|
/// Resolves the final options given those set by the document.
pub fn HtmlOptions::resolve(
  self : HtmlOptions,
  doc : @library.HtmlFormatOptions,
) -> CompleteHtmlOptions {
  { format: self.format.resolve(doc), }
}

///|
/// Encodes an HTML document into a string.
pub fn html(
  document : HtmlDocument,
  options : HtmlOptions,
) -> String raise @library.SourceError {
  let options = options.resolve(
    @library.HtmlFormatOptions::get(document.options()),
  )
  let link_resolver = @library.LateLinkResolver::new(
    None,
    @library.Introspector::new(document.introspector()),
  )
  html_encode(document.root(), pretty=options.format.pretty.v, link_resolver~)
}

///|
/// Encodes an HTML root element into a string as part of a bundle.
///
/// See `export_html` in `typst-bundle` for more details on why this takes the
/// root element instead of the document.
pub fn html_in_bundle(
  root : HtmlElement,
  options : CompleteHtmlOptions,
  link_resolver : @library.LateLinkResolver,
) -> String raise @library.SourceError {
  html_encode(root, pretty=options.format.pretty.v, link_resolver~)
}

///|
/// Encodes an HTML root element into a string (upstream `html_impl`, the
/// shared implementation of `html` and `html_in_bundle`).
///
/// Without a `link_resolver`, location links in frames are not resolved.
pub fn html_encode(
  root : HtmlElement,
  pretty? : Bool = false,
  link_resolver? : @library.LateLinkResolver,
) -> String raise @library.SourceError {
  let w = Writer::new(link_resolver, pretty)
  w.buf.write_string("<!DOCTYPE html>")
  write_indent(w)
  write_element(w, root)
  if w.pretty {
    w.buf.write_char('\n')
  }
  w.buf.to_string()
}

///|
/// Encodes HTML.
priv struct Writer {
  /// The output buffer.
  buf : StringBuilder
  /// The current indentation level
  mut level : Int
  /// Used to resolve links between the document and contained frames as
  /// well as cross-document links in bundle export.
  link_resolver : @library.LateLinkResolver?
  /// Whether pretty printing is enabled.
  mut pretty : Bool
}

///|
/// Creates a new writer.
fn Writer::new(
  link_resolver : @library.LateLinkResolver?,
  pretty : Bool,
) -> Writer {
  { buf: StringBuilder(), level: 0, link_resolver, pretty, }
}

///|
/// Writes a newline and indent, if pretty printing is enabled.
fn write_indent(w : Writer) -> Unit {
  if w.pretty {
    w.buf.write_char('\n')
    for _ in 0..<w.level {
      w.buf.write_string("  ")
    }
  }
}

///|
/// Encodes an HTML node into the writer.
fn write_node(
  w : Writer,
  node : HtmlNode,
  escape_text : Bool,
) -> Unit raise @library.SourceError {
  match node {
    Tag(_) => ()
    Text(text, span) => write_text(w, text, span, escape_text)
    Element(element) => write_element(w, element)
    Frame(frame) => write_frame(w, frame)
  }
}

///|
/// Encodes plain text into the writer.
fn write_text(
  w : Writer,
  text : String,
  span : @syntax.Span,
  escape : Bool,
) -> Unit raise @library.SourceError {
  for c in text {
    if escape || !@library.charsets_is_valid_in_normal_element_text(c) {
      @library.at(span, () => write_escape(w, c))
    } else {
      w.buf.write_char(c)
    }
  }
}

///|
/// Encodes one element into the writer.
fn write_element(
  w : Writer,
  element : HtmlElement,
) -> Unit raise @library.SourceError {
  w.buf.write_char('<')
  w.buf.write_string(element.tag.resolve())
  for pair in element.attrs.pairs() {
    let (attr, value) = pair
    w.buf.write_char(' ')
    w.buf.write_string(attr.resolve())

    // If the string is empty, we can use shorthand syntax.
    // `<elem attr="">..</div` is equivalent to `<elem attr>..</div>`
    if !value.is_empty() {
      w.buf.write_char('=')
      w.buf.write_char('"')
      for c in value {
        if @library.charsets_is_valid_in_attribute_value(c) {
          w.buf.write_char(c)
        } else {
          @library.at(element.span, () => write_escape(w, c))
        }
      }
      w.buf.write_char('"')
    }
  }
  if element.tag.is_foreign_self_closing() {
    w.buf.write_char('/')
  }
  w.buf.write_char('>')
  if element.tag.is_void() || element.tag.is_foreign_self_closing() {
    if !element.children.is_empty() {
      @library.bail_at(
        element.span,
        "HTML void elements must not have children",
      )
    }
    return
  }

  // See HTML spec § 13.1.2.5.
  if (element.tag == @library.tag_pre || element.tag == @library.tag_textarea) &&
    starts_with_newline(element) {
    w.buf.write_char('\n')
  }
  if element.tag.is_raw() {
    write_raw(w, element)
  } else if element.tag.is_escapable_raw() {
    write_escapable_raw(w, element)
  } else if !element.children.is_empty() {
    write_children(w, element)
  }
  w.buf.write_string("</")
  w.buf.write_string(element.tag.resolve())
  w.buf.write_char('>')
}

///|
/// Encodes the children of an element.
fn write_children(
  w : Writer,
  element : HtmlElement,
) -> Unit raise @library.SourceError {
  let pretty = w.pretty
  let pretty_inside = allows_pretty_inside(element.tag) &&
    element.children
    .iter()
    .any(node => {
      match node {
        Element(child) => wants_pretty_around(child)
        Frame(_) => true
        _ => false
      }
    })
  w.pretty = w.pretty && pretty_inside
  let mut indent = w.pretty
  w.level += 1
  for c in element.children {
    let pretty_around = match c {
      Tag(_) => continue
      Element(child) => w.pretty && wants_pretty_around(child)
      Text(_, _) | Frame(_) => false
    }
    let take_indent = indent
    indent = false
    if take_indent || pretty_around {
      write_indent(w)
    }
    write_node(w, c, element.pre_span)
    indent = pretty_around
  }
  w.level -= 1
  write_indent(w)
  w.pretty = pretty
}

///|
/// Whether the first character in the element is a newline.
fn starts_with_newline(element : HtmlElement) -> Bool {
  for child in element.children {
    match child {
      Tag(_) => ()
      Text(text, _) => return text.has_prefix("\n") || text.has_prefix("\r")
      _ => return false
    }
  }
  false
}

///|
/// Encodes the contents of a raw text element.
fn write_raw(
  w : Writer,
  element : HtmlElement,
) -> Unit raise @library.SourceError {
  let text = collect_raw_text(element)
  if find_closing_tag(text, element.tag) is Some(closing) {
    @library.bail_at(
      element.span,
      "HTML raw text element cannot contain its own closing tag",
      hints=["the sequence `\{closing}` appears in the raw text"],
    )
  }
  let mode = if w.pretty { RawMode::of(element, text) } else { Keep }
  match mode {
    Keep => w.buf.write_string(text)
    Wrap => {
      w.buf.write_char('\n')
      w.buf.write_string(text)
      write_indent(w)
    }
    Indent => {
      w.level += 1
      for line in rust_lines(text) {
        write_indent(w)
        w.buf.write_string(line)
      }
      w.level -= 1
      write_indent(w)
    }
  }
}

///|
/// Encodes the contents of an escapable raw text element.
fn write_escapable_raw(
  w : Writer,
  element : HtmlElement,
) -> Unit raise @library.SourceError {
  walk_raw_text(element, (piece, span) => write_text(w, piece, span, false))
}

///|
/// Collects the textual contents of a raw text element.
fn collect_raw_text(element : HtmlElement) -> String raise @library.SourceError {
  let text = StringBuilder()
  walk_raw_text(element, (piece, span) => {
    for c in piece {
      if !@library.charsets_is_w3c_text_char(c) {
        @library.bail_at(span, unencodable(c))
      }
    }
    text.write_string(piece)
  })
  text.to_string()
}

///|
/// Iterates over the textual contents of a raw text element.
fn walk_raw_text(
  element : HtmlElement,
  f : (String, @syntax.Span) -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  for c in element.children {
    match c {
      Tag(_) => ()
      Text(text, span) => f(text, span)
      Element({ span, .. }) | Frame({ span, .. }) =>
        @library.bail_at(
          span, "HTML raw text element cannot have non-text children",
        )
    }
  }
}

///|
/// Finds a closing sequence for the given tag in the text, if it exists.
///
/// See HTML spec § 13.1.2.6.
fn find_closing_tag(text : String, tag : @library.HtmlTag) -> String? {
  let s = tag.resolve()
  let len = s.length()
  let mut i = 0
  while i + 2 <= text.length() {
    if text.code_unit_at(i) == '<' && text.code_unit_at(i + 1) == '/' {
      let rest = i + 2
      // Tag names are ASCII, so comparing UTF-16 code units is equivalent
      // to upstream's byte-wise comparison (a non-ASCII character in the
      // compared range never matches).
      if rest + len <= text.length() {
        let mut eq = true
        for k in 0..<len {
          if ascii_lower(text.code_unit_at(rest + k)) !=
            ascii_lower(s.code_unit_at(k)) {
            eq = false
            break
          }
        }
        if eq &&
          rest + len < text.length() &&
          text.code_unit_at(rest + len)
          is ('\t' | '\n' | '\u{c}' | '\r' | ' ' | '>' | '/') {
          return Some(text.unsafe_substring(start=i, end=rest + len))
        }
      }
    }
    i += 1
  }
  None
}

///|
/// Lowercases an ASCII code unit.
fn ascii_lower(c : UInt16) -> UInt16 {
  if c >= 'A' && c <= 'Z' {
    c + 32
  } else {
    c
  }
}

///|
/// Rust's `str::lines`: splits at `\n` (dropping a preceding `\r`); a final
/// empty line is not yielded.
fn rust_lines(text : String) -> Array[String] {
  let lines = []
  let mut start = 0
  let n = text.length()
  while start < n {
    let mut end = start
    while end < n && text.code_unit_at(end) != '\n' {
      end += 1
    }
    let mut line_end = end
    if end < n && line_end > start && text.code_unit_at(line_end - 1) == '\r' {
      line_end -= 1
    }
    lines.push(text.unsafe_substring(start~, end=line_end))
    start = end + 1
  }
  lines
}

///|
/// How to format the contents of a raw text element.
priv enum RawMode {
  /// Just don't touch it.
  Keep
  /// Newline after the opening and newline + indent before the closing tag.
  Wrap
  /// Newlines after opening and before closing tag and each line indented.
  Indent
}

///|
fn RawMode::of(element : HtmlElement, text : String) -> RawMode {
  if element.tag == @library.tag_script &&
    !element.attrs
    .pairs()
    .iter()
    .any(pair => pair.0 == @library.attr_type && pair.1 != "text/javascript") {
    // Template literals can be multi-line, so indent may change
    // the semantics of the JavaScript.
    if text.contains_char('`') {
      Wrap
    } else {
      Indent
    }
  } else if element.tag == @library.tag_style {
    Indent
  } else {
    Keep
  }
}

///|
/// Whether we are allowed to add an extra newline at the start and end of
/// the element's contents.
///
/// Technically, users can change CSS `display` properties such that the
/// insertion of whitespace may actually impact the visual output. For
/// example, <https://www.w3.org/TR/css-text-3/#example-af2745cd> shows how
/// adding CSS rules to `<p>` can make it sensitive to whitespace. For this
/// reason, we should also respect the `style` tag in the future.
fn allows_pretty_inside(tag : @library.HtmlTag) -> Bool {
  if tag.is_mathml() && !tag.is_mathml_token() {
    return true
  }
  guard @library.CssDisplay::default_for(tag) is Some(display) else {
    return false
  }
  (display == Block && tag != @library.tag_pre) ||
  display.is_tabular() ||
  display == ListItem ||
  tag == @library.tag_head
}

///|
/// Whether newlines should be added before and after the element if the
/// parent allows it.
///
/// In contrast to `allows_pretty_inside`, which is purely spec-driven, this
/// is more subjective and depends on preference.
fn wants_pretty_around(element : HtmlElement) -> Bool {
  let t = element.tag
  if t == @library.tag_mathml_math {
    element.attrs.get(@library.attr_mathml_display) == Some("block")
  } else if t.is_mathml() {
    true
  } else if t == @library.tag_pre {
    true
  } else if t.is_metadata_content() {
    true
  } else {
    allows_pretty_inside(t)
  }
}

///|
/// Escape a character.
fn write_escape(w : Writer, c : Char) -> Unit raise @library.HintedError {
  // See <https://html.spec.whatwg.org/multipage/syntax.html#syntax-charref>
  match c {
    '&' => w.buf.write_string("&amp;")
    '<' => w.buf.write_string("&lt;")
    '>' => w.buf.write_string("&gt;")
    '"' => w.buf.write_string("&quot;")
    '\'' => w.buf.write_string("&apos;")
    c if @library.charsets_is_w3c_text_char(c) && c != '\r' => {
      w.buf.write_string("&#x")
      w.buf.write_string(c.to_int().to_string(radix=16))
      w.buf.write_char(';')
    }
    _ => @library.bail(unencodable(c))
  }
}

///|
/// The error message for a character that cannot be encoded.
fn unencodable(c : Char) -> String {
  "the character `\{@library.repr_str(c.to_string())}` cannot be encoded in HTML"
}

///|
/// Encode a laid out frame into the writer.
fn write_frame(w : Writer, frame : HtmlFrame) -> Unit {
  let svg = @svg.svg_in_html(
    frame.inner,
    frame.text_size,
    w.pretty,
    frame.id,
    frame.css.to_inline(),
    frame.anchors,
    w.link_resolver,
  )
  if w.pretty {
    // Indent the SVG after generation. This ensures the frame is cached no
    // matter the current indentation of the outer HTML.
    for i, line in svg_lines(svg) {
      if i != 0 {
        write_indent(w)
      }
      w.buf.write_string(line)
    }
  } else {
    w.buf.write_string(svg)
  }
}

///|
/// Rust's `str::lines`: split at `\n` (dropping a preceding `\r`), without
/// a trailing empty line.
fn svg_lines(s : String) -> Array[String] {
  let lines = s.split("\n").map(l => l.to_owned()).collect()
  if lines.last() is Some("") {
    lines.pop() |> ignore
  }
  lines.map(l => {
    if l.has_suffix("\r") {
      l.unsafe_substring(start=0, end=l.length() - 1)
    } else {
      l
    }
  })
}
