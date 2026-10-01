///|
/// Format the node like Rust's pretty debug output (`{:#?}`) of upstream's
/// `SyntaxNode`. Used for differential testing against upstream.
pub fn SyntaxNode::debug_tree(self : SyntaxNode) -> String {
  let buf = StringBuilder()
  write_debug_data(buf, self.data, "")
  buf.to_string()
}

///|
fn write_debug_data(buf : StringBuilder, data : Node, indent : String) -> Unit {
  let inner_indent = indent + "    "
  match data {
    Leaf(text, kind, _) => {
      buf.write_string(kind.debug_name())
      buf.write_string(": ")
      buf.write_string(@unicode.rust_debug_str(text))
    }
    Inner(inner, kind) => {
      buf.write_string(kind.debug_name())
      buf.write_string(": ")
      buf.write_string(inner.len.to_string())
      if inner.children.length() > 0 {
        buf.write_string(" [\n")
        for child in inner.children {
          buf.write_string(inner_indent)
          write_debug_data(buf, child.data, inner_indent)
          buf.write_string(",\n")
        }
        buf.write_string(indent)
        buf.write_string("]")
      }
    }
    Error(err) =>
      if err.text.is_empty() && err.hints.is_empty() {
        buf.write_string("Error: ")
        buf.write_string(@unicode.rust_debug_str(err.message))
      } else {
        buf.write_string("Error: {\n")
        buf.write_string(inner_indent)
        buf.write_string("text: ")
        buf.write_string(@unicode.rust_debug_str(err.text))
        buf.write_string(",\n")
        buf.write_string(inner_indent)
        buf.write_string("message: ")
        buf.write_string(@unicode.rust_debug_str(err.message))
        buf.write_string(",\n")
        for hint in err.hints {
          let (message, sub_range) = hint
          buf.write_string(inner_indent)
          write_field_name(buf, "hint", err.text, sub_range)
          buf.write_string(": ")
          buf.write_string(@unicode.rust_debug_str(message))
          buf.write_string(",\n")
        }
        buf.write_string(indent)
        buf.write_string("}")
      }
    Warning(w, _) => {
      let full_text = { data: w.child, span: Span::detached(), }.full_text()
      buf.write_string("Warning: {\n")
      buf.write_string(inner_indent)
      write_field_name(buf, "message", full_text, w.sub_range)
      buf.write_string(": ")
      buf.write_string(@unicode.rust_debug_str(w.message))
      buf.write_string(",\n")
      for hint in w.hints {
        let (message, sub_range) = hint
        buf.write_string(inner_indent)
        write_field_name(buf, "hint", full_text, sub_range)
        buf.write_string(": ")
        buf.write_string(@unicode.rust_debug_str(message))
        buf.write_string(",\n")
      }
      buf.write_string(inner_indent)
      write_debug_data(buf, w.child, inner_indent)
      buf.write_string(",\n")
      buf.write_string(indent)
      buf.write_string("}")
    }
  }
}

///|
/// Write `name` or `name @("selected")` for a field with an optional
/// sub-range (byte offsets into `text`).
fn write_field_name(
  buf : StringBuilder,
  name : String,
  text : String,
  sub_range : SubRange?,
) -> Unit {
  buf.write_string(name)
  if sub_range is Some(sr) {
    buf.write_string(" @(")
    buf.write_string(
      @unicode.rust_debug_str(utf8_slice(text, sr.start, sr.end)),
    )
    buf.write_string(")")
  }
}

///|
/// Slice a string by UTF-8 byte offsets.
pub fn utf8_slice(text : String, start : Int, end : Int) -> String {
  let a = utf8_to_utf16(text, start)
  let b = utf8_to_utf16(text, end)
  text.unsafe_substring(start=a, end=b)
}

///|
/// Convert a UTF-8 byte offset into a UTF-16 index (clamped to the string).
pub fn utf8_to_utf16(text : String, offset : Int) -> Int {
  let mut bytes = 0
  let mut i = 0
  while i < text.length() && bytes < offset {
    let (c, next) = @unicode.decode_at(text, i)
    bytes += if c < 0x80 {
      1
    } else if c < 0x800 {
      2
    } else if c < 0x10000 {
      3
    } else {
      4
    }
    i = next
  }
  i
}
