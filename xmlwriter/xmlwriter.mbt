// A simple, streaming, partially-validating XML writer that writes XML data
// into an internal buffer.
//
// Port of the `xmlwriter` 0.1.0 crate. Upstream's `fmt::Display`/
// `fmt::Arguments` parameters become pre-formatted strings here: callers
// format values exactly like Rust's `Display` would (see
// `@library.rust_display_f32`/`rust_display_f64` for floats).

///|
/// An XML node indention.
pub(all) enum Indent {
  /// Disable indention and new lines.
  None
  /// Indent with spaces. Preferred range is 0..4.
  Spaces(Int)
  /// Indent with tabs.
  Tabs
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Indent with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Indent with @debug.Debug::{to_repr}

///|
/// An XML writing options.
pub(all) struct Options {
  /// Use single quote marks instead of double quote.
  use_single_quote : Bool
  /// Set XML nodes indention.
  indent : Indent
  /// Set XML attributes indention.
  attributes_indent : Indent
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Options with @debug.Debug::{to_repr}

///|
pub impl Default for Options with fn default() {
  { use_single_quote: false, indent: Spaces(4), attributes_indent: None, }
}

///|
pub extend Options with Default::{default}

///|
priv enum State {
  Empty
  Document
  Attributes
} derive(Eq)

///|
priv struct DepthData {
  /// The element name (upstream keeps its byte range in the buffer and
  /// copies it from there when the element ends, lib.rs:155 and :508).
  name : String
  mut has_children : Bool
}

///|
/// An XML writer.
pub struct XmlWriter {
  priv buf : @buffer.Buffer
  priv mut state : State
  priv mut preserve_whitespaces : Bool
  priv depth_stack : Array[DepthData]
  priv opt : Options
}

///|
/// Creates a new `XmlWriter`.
pub fn XmlWriter::new(opt : Options) -> XmlWriter {
  {
    buf: Buffer(),
    state: Empty,
    preserve_whitespaces: false,
    depth_stack: [],
    opt,
  }
}

///|
/// Writes an XML declaration.
///
/// `<?xml version="1.0" encoding="UTF-8" standalone="no"?>`
///
/// # Panics
///
/// - When called twice.
pub fn XmlWriter::write_declaration(self : XmlWriter) -> Unit {
  if self.state != Empty {
    abort("declaration was already written")
  }

  // Pretend that we are writing an element.
  self.state = Attributes

  // <?xml version='1.0' encoding='UTF-8' standalone='yes'?>
  self.push_str("<?xml")
  self.write_attribute("version", "1.0")
  self.write_attribute("encoding", "UTF-8")
  self.write_attribute("standalone", "no")
  self.push_str("?>")
  self.state = Document
}

///|
/// Writes a comment string.
pub fn XmlWriter::write_comment(self : XmlWriter, text : String) -> Unit {
  if self.state == Attributes {
    self.write_open_element()
  }
  if self.state != Empty {
    self.write_new_line()
  }
  self.write_node_indent()

  // <!--text-->
  self.push_str("<!--")
  self.push_str(text) // TODO: check content
  self.push_str("-->")
  if self.state == Attributes {
    self.depth_stack.push({ name: "", has_children: false, })
  }
  self.state = Document
}

///|
/// Starts writing a new element.
///
/// This method writes only the `<tag-name` part.
pub fn XmlWriter::start_element(self : XmlWriter, name : String) -> Unit {
  if self.state == Attributes {
    self.write_open_element()
  }
  if self.state != Empty {
    self.write_new_line()
  }
  if !self.preserve_whitespaces {
    self.write_node_indent()
  }
  self.push_byte(b'<')
  self.push_str(name)
  self.depth_stack.push({ name, has_children: false, })
  self.state = Attributes
}

///|
/// Writes an attribute (upstream `write_attribute`/`write_attribute_fmt`
/// with the value already formatted).
///
/// Quotes in the value will be escaped.
///
/// # Panics
///
/// - When called before `start_element()`.
/// - When called after `close_element()`.
pub fn XmlWriter::write_attribute(
  self : XmlWriter,
  name : String,
  value : String,
) -> Unit {
  if self.state != Attributes {
    abort("must be called after start_element()")
  }
  self.write_attribute_prefix(name)
  self.write_escaped_attribute_value(value)
  self.write_quote()
}

///|
fn XmlWriter::write_attribute_prefix(self : XmlWriter, name : String) -> Unit {
  if self.opt.attributes_indent == None {
    self.push_byte(b' ')
  } else {
    self.push_byte(b'\n')
    let depth = self.depth_stack.length()
    if depth > 0 {
      self.write_indent(depth - 1, self.opt.indent)
    }
    self.write_indent(1, self.opt.attributes_indent)
  }
  self.push_str(name)
  self.push_byte(b'=')
  self.write_quote()
}

///|
/// Writes the value, escaping the quote character (upstream
/// `escape_attribute_value`).
fn XmlWriter::write_escaped_attribute_value(
  self : XmlWriter,
  value : String,
) -> Unit {
  let quote = if self.opt.use_single_quote { '\'' } else { '"' }
  let escaped = if self.opt.use_single_quote { "&apos;" } else { "&quot;" }
  for c in value {
    if c == quote {
      self.push_str(escaped)
    } else {
      self.buf.write_char_utf8(c)
    }
  }
}

///|
/// Sets the preserve whitespaces flag.
///
/// - If set, text nodes will be written as is.
/// - If not set, text nodes will be indented.
///
/// Can be set at any moment.
pub fn XmlWriter::set_preserve_whitespaces(
  self : XmlWriter,
  preserve : Bool,
) -> Unit {
  self.preserve_whitespaces = preserve
}

///|
/// Writes a text node.
///
/// `<` will be escaped.
///
/// # Panics
///
/// - When called not after `start_element()`.
pub fn XmlWriter::write_text(self : XmlWriter, text : String) -> Unit {
  if self.state == Empty || self.depth_stack.is_empty() {
    abort("must be called after start_element()")
  }
  if self.state == Attributes {
    self.write_open_element()
  }
  if self.state != Empty {
    self.write_new_line()
  }
  self.write_node_indent()
  for c in text {
    if c == '<' {
      self.push_str("&lt;")
    } else {
      self.buf.write_char_utf8(c)
    }
  }
  if self.state == Attributes {
    self.depth_stack.push({ name: "", has_children: false, })
  }
  self.state = Document
}

///|
/// Closes an open element.
pub fn XmlWriter::end_element(self : XmlWriter) -> Unit {
  if self.depth_stack.pop() is Some(depth) {
    if depth.has_children {
      if !self.preserve_whitespaces {
        self.write_new_line()
        self.write_node_indent()
      }
      self.push_str("</")
      self.push_str(depth.name)
      self.push_byte(b'>')
    } else {
      self.push_str("/>")
    }
  }
  self.state = Document
}

///|
/// Closes all open elements and returns an internal XML buffer.
pub fn XmlWriter::end_document(self : XmlWriter) -> String {
  while !self.depth_stack.is_empty() {
    self.end_element()
  }
  self.write_new_line()

  // The only way it can fail is if an invalid data
  // was written via `write_attribute_raw()`.
  @utf8.decode_lossy(self.buf.to_bytes())
}

///|
fn XmlWriter::push_byte(self : XmlWriter, c : Byte) -> Unit {
  self.buf.write_byte(c)
}

///|
fn XmlWriter::push_str(self : XmlWriter, text : String) -> Unit {
  for c in text {
    self.buf.write_char_utf8(c)
  }
}

///|
fn XmlWriter::write_quote(self : XmlWriter) -> Unit {
  self.push_byte(if self.opt.use_single_quote { b'\'' } else { b'"' })
}

///|
fn XmlWriter::write_open_element(self : XmlWriter) -> Unit {
  if self.depth_stack.last() is Some(depth) {
    depth.has_children = true
    self.push_byte(b'>')
    self.state = Document
  }
}

///|
fn XmlWriter::write_node_indent(self : XmlWriter) -> Unit {
  self.write_indent(self.depth_stack.length(), self.opt.indent)
}

///|
fn XmlWriter::write_indent(
  self : XmlWriter,
  depth : Int,
  indent : Indent,
) -> Unit {
  if indent == None || self.preserve_whitespaces {
    return
  }
  for _ in 0..<depth {
    match indent {
      None => ()
      Spaces(n) =>
        for _ in 0..<n {
          self.push_byte(b' ')
        }
      Tabs => self.push_byte(b'\t')
    }
  }
}

///|
fn XmlWriter::write_new_line(self : XmlWriter) -> Unit {
  if self.opt.indent != None && !self.preserve_whitespaces {
    self.push_byte(b'\n')
  }
}

///|
test "xmlwriter example" {
  let w = XmlWriter::new({ ..Options::default(), use_single_quote: true, })
  w.start_element("svg")
  w.write_attribute("xmlns", "http://www.w3.org/2000/svg")
  w.write_attribute("viewBox", "0 0 128 128")
  w.start_element("text")
  w.write_attribute("x", "10")
  w.write_attribute("y", "20")
  w.write_text("length is 5")
  assert_eq(
    w.end_document(),
    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 128'>\n    <text x='10' y='20'>\n        length is 5\n    </text>\n</svg>\n",
  )
}
