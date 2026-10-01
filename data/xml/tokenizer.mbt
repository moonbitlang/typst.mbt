// Port of `roxmltree` 0.21.1 `src/tokenizer.rs`.
//
// The tokenizer works on the UTF-8 encoding of the input, exactly like the
// Rust crate, so all byte offsets match upstream. Columns of `TextPos` are
// counted in chars (see `Stream::gen_text_pos`).

// --- XmlCharExt / XmlByteExt ------------------------------------------------

///|
/// `XmlByteExt::is_xml_space`: `[ \r\n\t]`.
fn byte_is_xml_space(b : Byte) -> Bool {
  b == b' ' || b == b'\t' || b == b'\n' || b == b'\r'
}

///|
/// `XmlByteExt::is_xml_name_start`.
fn byte_is_xml_name_start(b : Byte) -> Bool {
  (b >= b'A' && b <= b'Z') || (b >= b'a' && b <= b'z') || b == b':' || b == b'_'
}

///|
/// `XmlByteExt::is_xml_name`.
fn byte_is_xml_name(b : Byte) -> Bool {
  (b >= b'A' && b <= b'Z') ||
  (b >= b'a' && b <= b'z') ||
  (b >= b'0' && b <= b'9') ||
  b == b':' ||
  b == b'_' ||
  b == b'-' ||
  b == b'.'
}

///|
/// `XmlCharExt::is_xml_name_start` for `char`.
fn char_is_xml_name_start(c : Char) -> Bool {
  let n = c.to_int()
  // Check for ASCII first.
  if n <= 128 {
    return byte_is_xml_name_start(n.to_byte())
  }
  (n >= 0xC0 && n <= 0xD6) ||
  (n >= 0xD8 && n <= 0xF6) ||
  (n >= 0xF8 && n <= 0x2FF) ||
  (n >= 0x370 && n <= 0x37D) ||
  (n >= 0x37F && n <= 0x1FFF) ||
  (n >= 0x200C && n <= 0x200D) ||
  (n >= 0x2070 && n <= 0x218F) ||
  (n >= 0x2C00 && n <= 0x2FEF) ||
  (n >= 0x3001 && n <= 0xD7FF) ||
  (n >= 0xF900 && n <= 0xFDCF) ||
  (n >= 0xFDF0 && n <= 0xFFFD) ||
  (n >= 0x10000 && n <= 0xEFFFF)
}

///|
/// `XmlCharExt::is_xml_name` for `char`.
fn char_is_xml_name(c : Char) -> Bool {
  let n = c.to_int()
  // Check for ASCII first.
  if n <= 128 {
    return byte_is_xml_name(n.to_byte())
  }
  n == 0xB7 ||
  (n >= 0xC0 && n <= 0xD6) ||
  (n >= 0xD8 && n <= 0xF6) ||
  (n >= 0xF8 && n <= 0x2FF) ||
  (n >= 0x300 && n <= 0x36F) ||
  (n >= 0x370 && n <= 0x37D) ||
  (n >= 0x37F && n <= 0x1FFF) ||
  (n >= 0x200C && n <= 0x200D) ||
  (n >= 0x203F && n <= 0x2040) ||
  (n >= 0x2070 && n <= 0x218F) ||
  (n >= 0x2C00 && n <= 0x2FEF) ||
  (n >= 0x3001 && n <= 0xD7FF) ||
  (n >= 0xF900 && n <= 0xFDCF) ||
  (n >= 0xFDF0 && n <= 0xFFFD) ||
  (n >= 0x10000 && n <= 0xEFFFF)
}

///|
/// `XmlCharExt::is_xml_char` for `char`.
fn char_is_xml_char(c : Char) -> Bool {
  let n = c.to_int()
  // Does not check for surrogate code points U+D800-U+DFFF,
  // since the input is valid UTF-8.
  if n < 0x20 {
    return byte_is_xml_space(n.to_byte())
  }
  !(n == 0xFFFF || n == 0xFFFE)
}

///|
/// `is_xml_str`: checks that the attribute value only contains XML chars.
///
/// Upstream has a separate ASCII fast path that yields identical results.
fn is_xml_str(value : StrSpan, s : Stream) -> Unit raise XmlError {
  let mut i = value.start
  while i < value.end {
    let (c, len) = decode_char(s.text, i)
    if !char_is_xml_char(c) {
      raise NonXmlChar(c, s.gen_text_pos_from(i))
    }
    i += len
  }
}

///|
/// Decodes the UTF-8 encoded char starting at byte `pos` of `text`.
///
/// Returns the char and its encoded length. `text` is always valid UTF-8 and
/// `pos` always on a char boundary.
fn decode_char(text : Bytes, pos : Int) -> (Char, Int) {
  let b0 = text[pos].to_int()
  if b0 < 0x80 {
    (b0.unsafe_to_char(), 1)
  } else if b0 < 0xE0 {
    let c = ((b0 & 0x1F) << 6) | (text[pos + 1].to_int() & 0x3F)
    (c.unsafe_to_char(), 2)
  } else if b0 < 0xF0 {
    let c = ((b0 & 0x0F) << 12) |
      ((text[pos + 1].to_int() & 0x3F) << 6) |
      (text[pos + 2].to_int() & 0x3F)
    (c.unsafe_to_char(), 3)
  } else {
    let c = ((b0 & 0x07) << 18) |
      ((text[pos + 1].to_int() & 0x3F) << 12) |
      ((text[pos + 2].to_int() & 0x3F) << 6) |
      (text[pos + 3].to_int() & 0x3F)
    (c.unsafe_to_char(), 4)
  }
}

///|
/// Decodes the byte range `start..end` of `text` (always valid UTF-8).
fn slice_str(text : Bytes, start : Int, end : Int) -> String {
  @utf8.decode_lossy(text[start:end])
}

// --- StrSpan ------------------------------------------------------------------

///|
/// A string slice (upstream `StrSpan`).
///
/// Like `&str`, but also contains the position in the input XML from which
/// it was parsed. Since external entity resolution is not supported, every
/// span refers to the document text.
priv struct StrSpan {
  start : Int
  end : Int
}

// --- Tokens -----------------------------------------------------------------

///|
/// A byte range `start..end` (upstream `Range<usize>`).
priv struct Range {
  start : Int
  end : Int
}

///|
/// Upstream `tokenizer::Token`.
priv enum Token {
  // <?target content?>
  ProcessingInstruction(String, String?, Range)
  // <!-- text -->
  Comment(String, Range)
  // <!ENTITY ns_extend "http://test.com">
  EntityDeclaration(String, StrSpan)
  // <ns:elem
  ElementStart(String, String, Int)
  // ns:attr="value"
  Attribute(Range, Int, Int, String, String, StrSpan)
  ElementEnd(ElementEnd, Range)
  // Contains text between elements including whitespaces.
  // Basically everything between `>` and `<`.
  // Except `]]>`, which is not allowed and will lead to an error.
  Text(String, Range)
  // <![CDATA[text]]>
  Cdata(String, Range)
}

///|
/// Upstream `tokenizer::ElementEnd`.
priv enum ElementEnd {
  /// Indicates `>`
  Open
  /// Indicates `</ns:name>`
  Close(String, String)
  /// Indicates `/>`
  Empty
}

// --- Parsing ----------------------------------------------------------------

///|
/// `tokenizer::parse`.
///
/// document ::= prolog element Misc*
fn tokenize(
  text : Bytes,
  allow_dtd : Bool,
  events : Context,
) -> Unit raise XmlError {
  let s = Stream::new(text)
  parse_declaration(s)
  parse_misc(s, events)
  s.skip_spaces()
  if s.starts_with("<!DOCTYPE") {
    if !allow_dtd {
      raise DtdDetected
    }
    parse_doctype(s, events)
    parse_misc(s, events)
  }
  s.skip_spaces()
  if !s.at_end() && s.curr_byte_unchecked() == b'<' {
    parse_element(s, events)
  }
  parse_misc(s, events)
  if !s.at_end() {
    raise UnknownToken(s.gen_text_pos())
  }
}

///|
/// `parse_misc`.
///
/// Misc ::= Comment | PI | S
fn parse_misc(s : Stream, events : Context) -> Unit raise XmlError {
  while !s.at_end() {
    s.skip_spaces()
    if s.starts_with("<!--") {
      parse_comment(s, events)
    } else if s.starts_with("<?") {
      parse_pi(s, events)
    } else {
      break
    }
  }
}

///|
/// `parse_declaration`.
///
/// XMLDecl ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
///
/// We don't actually return a token for the XML declaration and only
/// validate it.
fn parse_declaration(s : Stream) -> Unit raise XmlError {
  // Skip UTF-8 BOM.
  if s.end - s.pos >= 3 &&
    s.text[s.pos] == b'\xEF' &&
    s.text[s.pos + 1] == b'\xBB' &&
    s.text[s.pos + 2] == b'\xBF' {
    s.advance(3)
  }
  if !s.starts_with("<?xml ") {
    return
  }
  fn consume_spaces(s : Stream) -> Unit raise XmlError {
    if s.starts_with_space() {
      s.skip_spaces()
    } else if !s.starts_with("?>") && !s.at_end() {
      raise InvalidChar2(
        "a whitespace",
        s.curr_byte_unchecked(),
        s.gen_text_pos(),
      )
    }
  }

  s.advance(5) // <?xml
  consume_spaces(s)

  // The `version` "attribute" is mandatory.
  if !s.starts_with("version") {
    // Will trigger the InvalidString error, which is what we want.
    s.skip_string("version")
    return
  }
  let _ = parse_attribute(s)
  consume_spaces(s)
  if s.starts_with("encoding") {
    let _ = parse_attribute(s)
    consume_spaces(s)
  }
  if s.starts_with("standalone") {
    let _ = parse_attribute(s)
  }
  s.skip_spaces()
  s.skip_string("?>")
}

///|
/// `parse_comment`.
///
/// '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
fn parse_comment(s : Stream, events : Context) -> Unit raise XmlError {
  let start = s.pos
  s.advance(4)
  let text = s.consume_chars(fn(s, c) { !(c == '-' && s.starts_with("-->")) })
  s.skip_string("-->")
  if text.contains("--") {
    raise InvalidComment(s.gen_text_pos_from(start))
  }
  if text.has_suffix("-") {
    raise InvalidComment(s.gen_text_pos_from(start))
  }
  let range = s.range_from(start)
  events.token(Comment(text, range))
}

///|
/// `parse_pi`.
///
/// PI       ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
/// PITarget ::= Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
fn parse_pi(s : Stream, events : Context) -> Unit raise XmlError {
  if s.starts_with("<?xml ") {
    raise UnexpectedDeclaration(s.gen_text_pos())
  }
  let start = s.pos
  s.advance(2)
  let target = s.consume_name()
  s.skip_spaces()
  let content = s.consume_chars(fn(s, c) { !(c == '?' && s.starts_with("?>")) })
  let content = if !content.is_empty() { Some(content) } else { None }
  s.skip_string("?>")
  let range = s.range_from(start)
  events.token(ProcessingInstruction(target, content, range))
}

///|
/// `parse_doctype`.
fn parse_doctype(s : Stream, events : Context) -> Unit raise XmlError {
  let start = s.pos
  parse_doctype_start(s)
  s.skip_spaces()
  if !s.at_end() && s.curr_byte_unchecked() == b'>' {
    s.advance(1)
    return
  }
  s.advance(1) // [
  while !s.at_end() {
    s.skip_spaces()
    if s.starts_with("<!ENTITY") {
      parse_entity_decl(s, events)
    } else if s.starts_with("<!--") {
      parse_comment(s, events)
    } else if s.starts_with("<?") {
      parse_pi(s, events)
    } else if s.starts_with("]") {
      // DTD ends with ']' S? '>', therefore we have to skip possible spaces.
      s.advance(1)
      s.skip_spaces()
      if s.at_end() {
        raise UnexpectedEndOfStream
      }
      let c = s.curr_byte_unchecked()
      if c == b'>' {
        s.advance(1)
        break
      } else {
        raise InvalidChar2("'>'", c, s.gen_text_pos())
      }
    } else if s.starts_with("<!ELEMENT") ||
      s.starts_with("<!ATTLIST") ||
      s.starts_with("<!NOTATION") {
      let ok = try {
        consume_decl(s)
        true
      } catch {
        _ => false
      }
      if !ok {
        let pos = s.gen_text_pos_from(start)
        raise UnknownToken(pos)
      }
    } else {
      raise UnknownToken(s.gen_text_pos())
    }
  }
}

///|
/// `parse_doctype_start`.
///
/// doctypedecl ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
fn parse_doctype_start(s : Stream) -> Unit raise XmlError {
  s.advance(9)
  s.consume_spaces()
  s.skip_name()
  s.skip_spaces()
  let _ = parse_external_id(s)
  s.skip_spaces()
  let c = s.curr_byte()
  if c != b'[' && c != b'>' {
    raise InvalidChar2("'[' or '>'", c, s.gen_text_pos())
  }
}

///|
/// `parse_external_id`.
///
/// ExternalID ::= 'SYSTEM' S SystemLiteral | 'PUBLIC' S PubidLiteral S SystemLiteral
fn parse_external_id(s : Stream) -> (String?, String)? raise XmlError {
  if s.starts_with("SYSTEM") || s.starts_with("PUBLIC") {
    let start = s.pos
    s.advance(6)
    let id = s.slice_back(start)
    s.consume_spaces()
    let quote = s.consume_quote()
    let first = s.consume_bytes(fn(c) { c != quote })
    s.consume_byte(quote)
    if id == "SYSTEM" {
      Some((None, first))
    } else {
      s.consume_spaces()
      let quote = s.consume_quote()
      let second = s.consume_bytes(fn(c) { c != quote })
      s.consume_byte(quote)
      Some((Some(first), second))
    }
  } else {
    None
  }
}

///|
/// `parse_entity_decl`.
///
/// EntityDecl  ::= GEDecl | PEDecl
/// GEDecl      ::= '<!ENTITY' S Name S EntityDef S? '>'
/// PEDecl      ::= '<!ENTITY' S '%' S Name S PEDef S? '>'
fn parse_entity_decl(s : Stream, events : Context) -> Unit raise XmlError {
  s.advance(8)
  s.consume_spaces()
  let is_ge = if s.try_consume_byte(b'%') {
    s.consume_spaces()
    false
  } else {
    true
  }
  let name = s.consume_name()
  s.consume_spaces()
  if parse_entity_def(s, events, is_ge) is Some(definition) {
    events.token(EntityDeclaration(name, definition))
  }
  s.skip_spaces()
  s.consume_byte(b'>')
}

///|
/// `parse_entity_def`.
///
/// EntityDef   ::= EntityValue | (ExternalID NDataDecl?)
/// PEDef       ::= EntityValue | ExternalID
/// EntityValue ::= '"' ([^%&"] | PEReference | Reference)* '"' |  "'" ([^%&']
///                             | PEReference | Reference)* "'"
/// ExternalID  ::= 'SYSTEM' S SystemLiteral | 'PUBLIC' S PubidLiteral S SystemLiteral
/// NDataDecl   ::= S 'NDATA' S Name
fn parse_entity_def(
  s : Stream,
  events : Context,
  is_ge : Bool,
) -> StrSpan? raise XmlError {
  let c = s.curr_byte()
  match c {
    b'"' | b'\'' => {
      let quote = s.consume_quote()
      let start = s.pos
      s.skip_bytes(fn(c) { c != quote })
      let value = s.slice_back_span(start)
      s.consume_byte(quote)
      Some(value)
    }
    b'S' | b'P' =>
      if parse_external_id(s) is Some((pub_id, uri)) {
        if is_ge {
          s.skip_spaces()
          if s.starts_with("NDATA") {
            s.advance(5)
            s.consume_spaces()
            s.skip_name()
            // TODO: NDataDecl is not supported
          }
        }
        // `events.resolve_entity(pub_id, uri)`: no entity resolver is
        // supported, so the default resolver yields `None` and the entity is
        // discarded.
        ignore(events)
        ignore(pub_id)
        ignore(uri)
        None
      } else {
        raise InvalidExternalID(s.gen_text_pos())
      }
    _ => {
      let pos = s.gen_text_pos()
      raise InvalidChar2("a quote, SYSTEM or PUBLIC", c, pos)
    }
  }
}

///|
/// `consume_decl`.
fn consume_decl(s : Stream) -> Unit raise XmlError {
  s.skip_bytes(fn(c) { c != b'>' })
  s.consume_byte(b'>')
}

///|
/// `parse_element`.
///
/// element ::= EmptyElemTag | STag content ETag
/// '<' Name (S Attribute)* S? '>'
fn parse_element(s : Stream, events : Context) -> Unit raise XmlError {
  let start = s.pos
  s.advance(1) // <
  let (prefix, local_name) = s.consume_qname()
  events.token(ElementStart(prefix, local_name, start))
  let mut open = false
  while !s.at_end() {
    let has_space = s.starts_with_space()
    s.skip_spaces()
    let start = s.pos
    match s.curr_byte() {
      b'/' => {
        s.advance(1)
        s.consume_byte(b'>')
        let range = s.range_from(start)
        events.token(ElementEnd(Empty, range))
        break
      }
      b'>' => {
        s.advance(1)
        let range = s.range_from(start)
        events.token(ElementEnd(Open, range))
        open = true
        break
      }
      _ => {
        // An attribute must be preceded with a whitespace.
        if !has_space {
          // Will always trigger an error. Which is what we want.
          s.consume_spaces()
        }
        let (prefix, local_name) = s.consume_qname()
        let qname_end = s.pos
        let qname_len = min_int(qname_end - start, 0xFFFF)
        s.consume_eq()
        let eq_len = min_int(s.pos - qname_end, 0xFF)
        let quote = s.consume_quote()
        // The attribute value must not contain the < character.
        let value_start = s.pos
        s.advance_until2(quote, b'<')
        let value = s.slice_back_span(value_start)
        is_xml_str(value, s)
        s.consume_byte(quote)
        let end = s.pos
        events.token(
          Attribute(
            { start, end, },
            qname_len,
            eq_len,
            prefix,
            local_name,
            value,
          ),
        )
      }
    }
  }
  if open {
    parse_content(s, events)
  }
}

///|
/// `parse_attribute` (only used for the XML declaration).
///
/// Attribute ::= Name Eq AttValue
fn parse_attribute(s : Stream) -> (String, String, StrSpan) raise XmlError {
  let (prefix, local_name) = s.consume_qname()
  s.consume_eq()
  let quote = s.consume_quote()
  let quote_c = quote.to_int().unsafe_to_char()
  // The attribute value must not contain the < character.
  let value_start = s.pos
  s.skip_chars(fn(_, c) { c != quote_c && c != '<' })
  let value = s.slice_back_span(value_start)
  s.consume_byte(quote)
  (prefix, local_name, value)
}

///|
/// `parse_content`.
///
/// content ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
fn parse_content(s : Stream, events : Context) -> Unit raise XmlError {
  while !s.at_end() {
    let c = s.curr_byte_unchecked()
    if c == b'<' {
      if s.pos + 1 >= s.end {
        raise UnknownToken(s.gen_text_pos())
      }
      match s.text[s.pos + 1] {
        b'!' =>
          if s.starts_with("<!--") {
            parse_comment(s, events)
          } else if s.starts_with("<![CDATA[") {
            parse_cdata(s, events)
          } else {
            raise UnknownToken(s.gen_text_pos())
          }
        b'?' => parse_pi(s, events)
        b'/' => {
          parse_close_element(s, events)
          break
        }
        _ => parse_element(s, events)
      }
    } else {
      parse_text(s, events)
    }
  }
}

///|
/// `parse_cdata`.
///
/// CDSect  ::= CDStart CData CDEnd
/// CDStart ::= '<![CDATA['
/// CData   ::= (Char* - (Char* ']]>' Char*))
/// CDEnd   ::= ']]>'
fn parse_cdata(s : Stream, events : Context) -> Unit raise XmlError {
  let start = s.pos
  s.advance(9) // <![CDATA[
  let text = s.consume_chars(fn(s, c) { !(c == ']' && s.starts_with("]]>")) })
  s.skip_string("]]>")
  let range = s.range_from(start)
  events.token(Cdata(text, range))
}

///|
/// `parse_close_element`.
///
/// '</' Name S? '>'
fn parse_close_element(s : Stream, events : Context) -> Unit raise XmlError {
  let start = s.pos
  s.advance(2) // </
  let (prefix, tag_name) = s.consume_qname()
  s.skip_spaces()
  s.consume_byte(b'>')
  let range = s.range_from(start)
  events.token(ElementEnd(Close(prefix, tag_name), range))
}

///|
/// `parse_text`.
fn parse_text(s : Stream, events : Context) -> Unit raise XmlError {
  let start = s.pos
  let text = s.consume_chars(fn(_, c) { c != '<' })

  // According to the spec, `]]>` must not appear inside a Text node.
  // https://www.w3.org/TR/xml/#syntax
  //
  // Search for `>` first, since it's a bit faster than looking for `]]>`.
  if text.contains_char('>') && text.contains("]]>") {
    raise InvalidCharacterData(s.gen_text_pos())
  }
  let range = s.range_from(start)
  events.token(Text(text, range))
}

///|
/// Representation of the [Reference](https://www.w3.org/TR/xml/#NT-Reference)
/// value (upstream `tokenizer::Reference`).
priv enum Reference {
  /// An entity reference.
  ///
  /// <https://www.w3.org/TR/xml/#NT-EntityRef>
  Entity(String)
  /// A character reference.
  ///
  /// <https://www.w3.org/TR/xml/#NT-CharRef>
  Char(Char)
}

// --- Stream -----------------------------------------------------------------

///|
/// Upstream `tokenizer::Stream`: a byte cursor over (a fragment of) the
/// UTF-8 encoded input.
priv struct Stream {
  mut pos : Int
  end : Int
  text : Bytes
}

///|
fn Stream::new(text : Bytes) -> Stream {
  { pos: 0, end: text.length(), text, }
}

///|
fn Stream::from_substr(text : Bytes, fragment : Range) -> Stream {
  { pos: fragment.start, end: fragment.end, text, }
}

///|
fn Stream::at_end(self : Stream) -> Bool {
  self.pos >= self.end
}

///|
fn Stream::curr_byte(self : Stream) -> Byte raise XmlError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  self.curr_byte_unchecked()
}

///|
fn Stream::curr_byte_unchecked(self : Stream) -> Byte {
  self.text[self.pos]
}

///|
fn Stream::advance(self : Stream, n : Int) -> Unit {
  self.pos += n
}

///|
/// `starts_with` for an ASCII pattern.
fn Stream::starts_with(self : Stream, text : String) -> Bool {
  let n = text.length()
  if self.end - self.pos < n {
    return false
  }
  for i in 0..<n {
    if self.text[self.pos + i].to_int() != text.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn Stream::consume_byte(self : Stream, c : Byte) -> Unit raise XmlError {
  let curr = self.curr_byte()
  if curr != c {
    raise InvalidChar(c, curr, self.gen_text_pos())
  }
  self.advance(1)
}

///|
/// Unlike `consume_byte()` will not return any errors.
fn Stream::try_consume_byte(self : Stream, c : Byte) -> Bool {
  if !self.at_end() && self.curr_byte_unchecked() == c {
    self.advance(1)
    true
  } else {
    false
  }
}

///|
fn Stream::skip_string(self : Stream, text : String) -> Unit raise XmlError {
  if !self.starts_with(text) {
    let pos = self.gen_text_pos()
    raise InvalidString(text, pos)
  }
  self.advance(text.length())
}

///|
fn Stream::consume_bytes(self : Stream, f : (Byte) -> Bool) -> String {
  let start = self.pos
  self.skip_bytes(f)
  self.slice_back(start)
}

///|
fn Stream::skip_bytes(self : Stream, f : (Byte) -> Bool) -> Unit {
  while !self.at_end() && f(self.curr_byte_unchecked()) {
    self.advance(1)
  }
}

///|
fn Stream::consume_chars(
  self : Stream,
  f : (Stream, Char) -> Bool,
) -> String raise XmlError {
  let start = self.pos
  self.skip_chars(f)
  self.slice_back(start)
}

///|
fn Stream::skip_chars(
  self : Stream,
  f : (Stream, Char) -> Bool,
) -> Unit raise XmlError {
  while !self.at_end() {
    let (c, len) = decode_char(self.text, self.pos)
    if !char_is_xml_char(c) {
      raise NonXmlChar(c, self.gen_text_pos())
    } else if f(self, c) {
      self.advance(len)
    } else {
      break
    }
  }
}

///|
/// `advance_until2`: advances to the first occurrence of either needle.
fn Stream::advance_until2(
  self : Stream,
  needle1 : Byte,
  needle2 : Byte,
) -> Unit raise XmlError {
  let mut i = self.pos
  while i < self.end {
    let b = self.text[i]
    if b == needle1 || b == needle2 {
      self.pos = i
      return
    }
    i += 1
  }
  raise UnexpectedEndOfStream
}

///|
fn Stream::slice_back(self : Stream, pos : Int) -> String {
  slice_str(self.text, pos, self.pos)
}

///|
fn Stream::slice_back_span(self : Stream, pos : Int) -> StrSpan {
  { start: pos, end: self.pos, }
}

///|
fn Stream::range_from(self : Stream, start : Int) -> Range {
  { start, end: self.pos, }
}

///|
fn Stream::skip_spaces(self : Stream) -> Unit {
  while self.starts_with_space() {
    self.advance(1)
  }
}

///|
fn Stream::starts_with_space(self : Stream) -> Bool {
  !self.at_end() && byte_is_xml_space(self.curr_byte_unchecked())
}

///|
/// Like `skip_spaces()`, but checks that first char is actually a space.
fn Stream::consume_spaces(self : Stream) -> Unit raise XmlError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  if !self.starts_with_space() {
    raise InvalidChar2(
      "a whitespace",
      self.curr_byte_unchecked(),
      self.gen_text_pos(),
    )
  }
  self.skip_spaces()
}

///|
/// Consumes according to: <https://www.w3.org/TR/xml/#NT-Reference>
fn Stream::consume_reference(self : Stream) -> Reference? {
  if !self.try_consume_byte(b'&') {
    return None
  }
  let reference = if self.try_consume_byte(b'#') {
    let start = self.pos
    let radix = if self.try_consume_byte(b'x') {
      self.skip_bytes(fn(c) { is_ascii_hexdigit(c) })
      16
    } else {
      self.skip_bytes(fn(c) { c >= b'0' && c <= b'9' })
      10
    }
    let digits_start = if radix == 16 { start + 1 } else { start }
    let n = match u32_from_str_radix(self.text, digits_start, self.pos, radix) {
      Some(n) => n
      None => return None
    }
    let c = char_from_u32(n)
    if !char_is_xml_char(c) {
      return None
    }
    Reference::Char(c)
  } else {
    let name = self.consume_name() catch { _ => return None }
    match name {
      "quot" => Reference::Char('"')
      "amp" => Reference::Char('&')
      "apos" => Reference::Char('\'')
      "lt" => Reference::Char('<')
      "gt" => Reference::Char('>')
      _ => Reference::Entity(name)
    }
  }
  if !self.try_consume_byte(b';') {
    return None
  }
  Some(reference)
}

///|
fn is_ascii_hexdigit(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  (c >= b'a' && c <= b'f') ||
  (c >= b'A' && c <= b'F')
}

///|
/// `u32::from_str_radix` over the ASCII digits `text[start..end]` (which only
/// contains valid digits of `radix`).
fn u32_from_str_radix(
  text : Bytes,
  start : Int,
  end : Int,
  radix : Int,
) -> UInt64? {
  if start >= end {
    return None
  }
  let mut n = 0UL
  for i in start..<end {
    let b = text[i].to_int()
    let d = if b >= '0'.to_int() && b <= '9'.to_int() {
      b - '0'.to_int()
    } else if b >= 'a'.to_int() && b <= 'f'.to_int() {
      b - 'a'.to_int() + 10
    } else {
      b - 'A'.to_int() + 10
    }
    n = n * radix.to_uint64() + d.to_uint64()
    if n > 0xFFFF_FFFFUL {
      return None
    }
  }
  Some(n)
}

///|
/// `char::from_u32(n).unwrap_or('\u{FFFD}')`.
fn char_from_u32(n : UInt64) -> Char {
  if n > 0x10FFFFUL || (n >= 0xD800UL && n <= 0xDFFFUL) {
    '\u{FFFD}'
  } else {
    n.to_int().unsafe_to_char()
  }
}

///|
/// Consumes according to: <https://www.w3.org/TR/xml/#NT-Name>
fn Stream::consume_name(self : Stream) -> String raise XmlError {
  let start = self.pos
  self.skip_name()
  let name = self.slice_back(start)
  if name.is_empty() {
    raise InvalidName(self.gen_text_pos_from(start))
  }
  name
}

///|
/// The same as `consume_name()`, but does not return a consumed name.
fn Stream::skip_name(self : Stream) -> Unit raise XmlError {
  let start = self.pos
  if !self.at_end() {
    let (c, len) = decode_char(self.text, self.pos)
    if char_is_xml_name_start(c) {
      self.advance(len)
    } else {
      raise InvalidName(self.gen_text_pos_from(start))
    }
  }
  while !self.at_end() {
    let (c, len) = decode_char(self.text, self.pos)
    if char_is_xml_name(c) {
      self.advance(len)
    } else {
      break
    }
  }
}

///|
/// Consumes a qualified XML name and returns it.
///
/// Consumes according to: <https://www.w3.org/TR/xml-names/#ns-qualnames>
fn Stream::consume_qname(self : Stream) -> (String, String) raise XmlError {
  let start = self.pos
  let mut splitter : Int? = None
  while !self.at_end() {
    // Check for ASCII first for performance reasons.
    let b = self.curr_byte_unchecked()
    if b < b'\x80' {
      if b == b':' {
        if splitter is None {
          splitter = Some(self.pos)
          self.advance(1)
        } else {
          // Multiple `:` is an error.
          raise InvalidName(self.gen_text_pos_from(start))
        }
      } else if byte_is_xml_name(b) {
        self.advance(1)
      } else {
        break
      }
    } else {
      // Fallback to Unicode code point.
      let (c, len) = decode_char(self.text, self.pos)
      if char_is_xml_name(c) {
        self.advance(len)
      } else {
        break
      }
    }
  }
  let (prefix, local_name) = match splitter {
    Some(splitter) =>
      (slice_str(self.text, start, splitter), self.slice_back(splitter + 1))
    None =>
      // Slice an empty prefix. This way we can preserve attribute start position.
      ("", self.slice_back(start))
  }
  fn is_name_start(name : String) -> Bool {
    if name.is_empty() {
      return false
    }
    char_is_xml_name_start(name.get_char(0).unwrap())
  }

  // Prefix must be empty or start with a `NameStartChar`.
  if !prefix.is_empty() && !is_name_start(prefix) {
    raise InvalidName(self.gen_text_pos_from(start))
  }
  // Local name must start with a `NameStartChar`.
  if !is_name_start(local_name) {
    raise InvalidName(self.gen_text_pos_from(start))
  }
  (prefix, local_name)
}

///|
fn Stream::consume_eq(self : Stream) -> Unit raise XmlError {
  self.skip_spaces()
  self.consume_byte(b'=')
  self.skip_spaces()
}

///|
fn Stream::consume_quote(self : Stream) -> Byte raise XmlError {
  let c = self.curr_byte()
  if c == b'\'' || c == b'"' {
    self.advance(1)
    c
  } else {
    raise InvalidChar2("a quote", c, self.gen_text_pos())
  }
}

///|
/// Calculates a current absolute position.
///
/// This operation is very expensive. Use only for errors.
fn Stream::gen_text_pos(self : Stream) -> TextPos {
  let text = self.text
  let end = self.pos
  let row = Stream::calc_curr_row(text, end)
  let col = Stream::calc_curr_col(text, end)
  { row, col, }
}

///|
/// Calculates an absolute position at `pos`.
///
/// This operation is very expensive. Use only for errors.
fn Stream::gen_text_pos_from(self : Stream, pos : Int) -> TextPos {
  let s : Stream = {
    pos: min_int(pos, self.text.length()),
    end: self.end,
    text: self.text,
  }
  s.gen_text_pos()
}

///|
fn Stream::calc_curr_row(text : Bytes, end : Int) -> Int {
  let mut row = 1
  for i in 0..<end {
    if text[i] == b'\n' {
      row += 1
    }
  }
  row
}

///|
/// Counts the chars (not bytes) since the last `\n`.
fn Stream::calc_curr_col(text : Bytes, end : Int) -> Int {
  let mut col = 1
  let mut i = end - 1
  while i >= 0 {
    let b = text[i]
    if b == b'\n' {
      break
    }
    if (b.to_int() & 0xC0) != 0x80 {
      col += 1
    }
    i -= 1
  }
  col
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
