// Tests for the roxmltree port.
//
// `typst_xml` mirrors what upstream Typst does with a document
// (`typst_library::loading::xml::convert_xml` followed by
// `json.encode(.., pretty: false)`) and how it reports errors for a bytes
// source (`format_xml_like_error` + ` at ROW:COL`), so that the expected
// values of the generated `oracle*_test.mbt` files can be taken verbatim from
// the upstream Typst oracle.

///|
fn json_str(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      '\u{8}' => buf.write_string("\\b")
      '\u{c}' => buf.write_string("\\f")
      _ =>
        if c.to_int() < 0x20 {
          let hex = "0123456789abcdef"
          buf.write_string("\\u00")
          buf.write_char(hex.get_char(c.to_int() >> 4).unwrap())
          buf.write_char(hex.get_char(c.to_int() & 0xF).unwrap())
        } else {
          buf.write_char(c)
        }
    }
  }
  buf.write_char('"')
}

///|
/// `convert_xml` of upstream Typst, directly serialized as compact JSON.
fn convert_xml(buf : StringBuilder, node : @xml.Node) -> Unit {
  if node.is_text() {
    json_str(buf, node.text().unwrap_or(""))
    return
  }
  let children = node.children()
  fn write_children(buf : StringBuilder, children : Array[@xml.Node]) {
    buf.write_char('[')
    for i, child in children {
      if i > 0 {
        buf.write_char(',')
      }
      convert_xml(buf, child)
    }
    buf.write_char(']')
  }

  if node.is_root() {
    write_children(buf, children)
    return
  }
  buf.write_string("{\"namespace\":")
  match node.tag_name().namespace() {
    Some(ns) => json_str(buf, ns)
    None => buf.write_string("null")
  }
  buf.write_string(",\"tag\":")
  json_str(buf, node.tag_name().name())
  buf.write_string(",\"attrs\":{")
  // Typst collects the attributes into a `Dict` (an `IndexMap`): a repeated
  // key keeps its first position but takes the last value.
  let keys : Array[String] = []
  let values : Map[String, String] = Map([])
  for attr in node.attributes() {
    if !values.contains(attr.name()) {
      keys.push(attr.name())
    }
    values[attr.name()] = attr.value()
  }
  for i, key in keys {
    if i > 0 {
      buf.write_char(',')
    }
    json_str(buf, key)
    buf.write_char(':')
    json_str(buf, values[key])
  }
  buf.write_string("},\"children\":")
  write_children(buf, children)
  buf.write_char('}')
}

///|
/// `format_xml_like_error("XML", error)` of upstream Typst.
fn format_xml_error(error : @xml.XmlError) -> String {
  let format = "XML"
  match error {
    UnexpectedCloseTag(expected, actual, _) =>
      "failed to parse \{format} (found closing tag '\{actual}' instead of '\{expected}')"
    UnknownEntityReference(entity, _) =>
      "failed to parse \{format} (unknown entity '\{entity}')"
    DuplicatedAttribute(attr, _) =>
      "failed to parse \{format} (duplicate attribute '\{attr}')"
    NoRootNode => "failed to parse \{format} (missing root node)"
    err => "failed to parse \{format} (\{err.to_string()})"
  }
}

///|
/// Parses like upstream Typst's `xml` function and renders the result like
/// the oracle probes (`json.encode(xml(bytes(..)), pretty: false)`).
fn typst_xml(text : String) -> String {
  let opts : @xml.ParsingOptions = {
    allow_dtd: true,
    nodes_limit: @xml.ParsingOptions::default().nodes_limit,
  }
  let doc = @xml.Document::parse_with_options(text, opts) catch {
    e => {
      let pos = e.pos()
      // `within` replaces the trailing `)` with ` at ROW:COL)`.
      let msg = format_xml_error(e)
      let msg = msg.view(end_offset=msg.length() - 1)
      return "error: \{msg} at \{pos.row}:\{pos.col})"
    }
  }
  let buf = StringBuilder()
  convert_xml(buf, doc.root())
  buf.to_string()
}

///|
fn parse_err(text : String, allow_dtd? : Bool = true) -> String {
  let opts : @xml.ParsingOptions = {
    allow_dtd,
    nodes_limit: @xml.ParsingOptions::default().nodes_limit,
  }
  try @xml.Document::parse_with_options(text, opts) catch {
    e => "\{e.to_string()} @ \{e.pos()}"
  } noraise {
    _ => "ok"
  }
}

///|
test "typst suite: xml" {
  let src =
    #|<data>
    #|  <hello name="hi">1</hello>
    #|  <data>
    #|    <hello>World</hello>
    #|    <hello>World</hello>
    #|  </data>
    #|</data>
    #|
  let doc = @xml.Document::parse_with_options(src, {
    allow_dtd: true,
    nodes_limit: 0xFFFF_FFFFU,
  })
  let root = doc.root()
  assert_true(root.is_root())
  let children = root.children()
  assert_eq(children.length(), 1)
  let data = children[0]
  assert_true(data.is_element())
  assert_eq(data.tag_name().name(), "data")
  assert_eq(data.tag_name().namespace(), None)
  let kids = data.children()
  assert_eq(kids.length(), 5)
  assert_true(kids[0].is_text())
  assert_eq(kids[0].text(), Some("\n  "))
  let hello = kids[1]
  assert_eq(hello.tag_name().name(), "hello")
  let attrs = hello.attributes()
  assert_eq(attrs.length(), 1)
  assert_eq(attrs[0].name(), "name")
  assert_eq(attrs[0].value(), "hi")
  assert_eq(attrs[0].namespace(), None)
  assert_eq(hello.text(), Some("1"))
  assert_eq(hello.attribute("name"), Some("hi"))
  assert_eq(kids[4].text(), Some("\n"))
}

///|
test "typst suite: xml-invalid (bad.xml)" {
  let src =
    #|<data>
    #|  <hello>
    #|</data>
    #|
  let e = try
    @xml.Document::parse_with_options(src, {
      allow_dtd: true,
      nodes_limit: 0xFFFF_FFFFU,
    })
  catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  assert_eq(e.pos(), @xml.TextPos::new(3, 1))
  assert_eq(e.to_string(), "expected 'hello' tag, not 'data' at 3:1")
  assert_eq(
    format_xml_error(e),
    "failed to parse XML (found closing tag 'data' instead of 'hello')",
  )
}

///|
test "node kinds and text" {
  let doc = @xml.Document::parse(
    "<?xml version='1.0'?><!--top--><?t v?><r>a<!--c-->b<?p?><e/>tail<![CDATA[x]]>y</r>",
  )
  let top = doc.root().children()
  assert_eq(top.length(), 3)
  assert_true(top[0].is_comment())
  assert_eq(top[0].text(), Some("top"))
  assert_eq(top[0].tag_name().name(), "")
  assert_eq(top[0].tag_name().namespace(), None)
  assert_true(top[1].is_pi())
  assert_eq(top[1].text(), None)
  assert_eq(top[1].pi(), Some({ target: "t", value: Some("v"), }))
  assert_eq(top[1].tag_name().name(), "")
  let r = top[2]
  assert_eq(doc.root_element(), r)
  assert_eq(doc.root().text(), None)
  assert_eq(doc.root().tag_name().name(), "")
  assert_eq(r.text(), Some("a"))
  let kids = r.children()
  assert_eq(kids.length(), 6)
  assert_eq(kids[2].text(), Some("b"))
  assert_eq(kids[3].pi(), Some({ target: "p", value: None, }))
  assert_true(kids[4].is_element())
  assert_eq(kids[4].tail(), Some("tail" + "x" + "y"))
  // CDATA is merged with the surrounding text.
  assert_eq(kids[5].text(), Some("tailxy"))
}

///|
test "children, siblings and descendants" {
  let doc = @xml.Document::parse("<a><b><c/></b>t<d/></a>")
  let a = doc.root_element()
  assert_eq(a.children().map(fn(n) { n.tag_name().name() }), ["b", "", "d"])
  let b = a.first_child().unwrap()
  assert_eq(b.next_sibling().unwrap().text(), Some("t"))
  assert_eq(b.next_sibling_element().unwrap().tag_name().name(), "d")
  assert_eq(a.last_child().unwrap().tag_name().name(), "d")
  assert_eq(a.last_child().unwrap().prev_sibling().unwrap().text(), Some("t"))
  assert_eq(b.first_child().unwrap().parent_element(), Some(b))
  assert_eq(b.first_child().unwrap().next_sibling(), None)
  assert_eq(doc.descendants().length(), 6)
  assert_eq(b.descendants().length(), 2)
  assert_true(b.has_children())
  assert_true(b.has_siblings())
  assert_eq(a.first_child().unwrap().range(), (3, 14))
  assert_eq(a.range(), (0, 23))
}

///|
test "error display and positions" {
  // Variants that Typst special-cases (their Display is never shown there).
  assert_eq(parse_err("<a></b>"), "expected 'a' tag, not 'b' at 1:4 @ 1:4")
  assert_eq(
    parse_err("<x:a xmlns:x='u'></x:b>"),
    "expected 'x:a' tag, not 'x:b' at 1:18 @ 1:18",
  )
  assert_eq(
    parse_err("<a>\n &e;</a>"),
    "unknown entity reference 'e' at 2:2 @ 2:2",
  )
  assert_eq(
    parse_err("<a x='1' x='2'/>"),
    "attribute 'x' at 1:10 is already defined @ 1:10",
  )
  assert_eq(parse_err(""), "the document does not have a root node @ 1:1")
  assert_eq(parse_err("<a>"), "the root node was opened but never closed @ 1:1")
  // DTDs are rejected by default.
  assert_eq(
    parse_err("<!DOCTYPE r><r/>", allow_dtd=false),
    "XML with DTD detected @ 1:1",
  )
  assert_eq(parse_err("<!DOCTYPE r><r/>"), "ok")
  assert_eq(parse_err("<r/>", allow_dtd=false), "ok")
  // Not reachable through parsing.
  let pos = @xml.TextPos::new(2, 3)
  assert_eq(
    @xml.XmlError::EntityResolver(pos, "boom").to_string(),
    "entity resolver failed at 2:3: boom",
  )
  assert_eq(@xml.XmlError::EntityResolver(pos, "boom").pos(), pos)
  assert_eq(
    @xml.XmlError::AttributesLimitReached.to_string(),
    "more than 2^32 attributes were parsed",
  )
  assert_eq(
    @xml.XmlError::NamespacesLimitReached.to_string(),
    "more than 2^16 unique namespaces were parsed",
  )
  assert_eq(
    @xml.XmlError::NamespacesLimitReached.pos(),
    @xml.TextPos::new(1, 1),
  )
  assert_eq(@xml.XmlError::UnexpectedEndOfStream.pos(), @xml.TextPos::new(1, 1))
  assert_eq(
    @xml.XmlError::InvalidChar(b'a', b'\xC3', pos).to_string(),
    "expected 'a' not '\u{C3}' at 2:3",
  )
  assert_eq(
    @xml.XmlError::NonXmlChar('\u{FFFF}', pos).to_string(),
    "a non-XML character '\\u{ffff}' found at 2:3",
  )
  assert_eq(
    @xml.XmlError::NonXmlChar('\u{1F}', pos).to_string(),
    "a non-XML character '\\u{1f}' found at 2:3",
  )
  // Show prints the Display message.
  assert_eq("\{@xml.XmlError::UnknownToken(pos)}", "unknown token at 2:3")
  assert_eq("\{pos}", "2:3")
}

///|
test "multi-byte chars count as one column" {
  // Columns count chars, rows count `\n` only.
  assert_eq(
    parse_err("<\u{e4}>\u{65e5}\u{1F600}</b>"),
    "expected '\u{e4}' tag, not 'b' at 1:6 @ 1:6",
  )
  assert_eq(
    parse_err("<a>\r\n\r\u{e4}</b>"),
    "expected 'a' tag, not 'b' at 2:3 @ 2:3",
  )
  // Non-ASCII byte in an "expected char" error is shown as Latin-1.
  assert_eq(
    parse_err("<a x='1'\u{e4}/>"),
    "expected a whitespace not '\u{C3}' at 1:9 @ 1:9",
  )
}

///|
test "nodes limit" {
  let src = "<a><b/>t</a>"
  // The root node counts too: root, a, b, text.
  assert_eq(
    @xml.Document::parse_with_options(src, { allow_dtd: false, nodes_limit: 4, })
    .descendants()
    .length(),
    4,
  )
  for limit in [0U, 1, 2, 3] {
    let r = try
      @xml.Document::parse_with_options(src, {
        allow_dtd: false,
        nodes_limit: limit,
      })
    catch {
      e => e.to_string()
    } noraise {
      _ => "ok"
    }
    assert_eq(r, "nodes limit reached")
  }
}

///|
test "namespaces api" {
  let doc = @xml.Document::parse(
    "<x:a xmlns:x='urn:x' xmlns='urn:d' x:p='1' q='2' xml:lang='en'><b xmlns:y='urn:y'/></x:a>",
  )
  let a = doc.root_element()
  assert_eq(a.tag_name().namespace(), Some("urn:x"))
  assert_eq(a.tag_name().name(), "a")
  assert_eq("\{a.tag_name()}", "{urn:x}a")
  let attrs = a.attributes()
  assert_eq(attrs.map(fn(at) { at.name() }), ["p", "q", "lang"])
  assert_eq(attrs.map(fn(at) { at.namespace() }), [
    Some("urn:x"),
    None,
    Some(@xml.NS_XML_URI),
  ])
  assert_eq(attrs.map(fn(at) { at.value() }), ["1", "2", "en"])
  assert_eq(a.attribute("p"), Some("1"))
  assert_eq(a.attribute("p", ns="urn:x"), Some("1"))
  assert_eq(a.attribute("p", ns="urn:z"), None)
  assert_true(a.has_attribute("lang", ns=@xml.NS_XML_URI))
  assert_eq(attrs[0].range(), (35, 42))
  assert_eq(attrs[0].range_qname(), (35, 38))
  assert_eq(attrs[0].range_value(), (40, 41))
  assert_eq(a.default_namespace(), Some("urn:d"))
  assert_eq(a.lookup_prefix("urn:x"), Some("x"))
  assert_eq(a.lookup_prefix(@xml.NS_XML_URI), Some("xml"))
  assert_eq(a.lookup_namespace_uri(Some("x")), Some("urn:x"))
  assert_eq(a.lookup_namespace_uri(None), Some("urn:d"))
  assert_true(a.has_tag_name("a"))
  assert_true(a.has_tag_name("a", ns="urn:x"))
  assert_true(!a.has_tag_name("a", ns="urn:d"))
  let b = a.first_child().unwrap()
  assert_eq(b.tag_name().namespace(), Some("urn:d"))
  // Child namespaces: own declarations first, then inherited ones.
  assert_eq(b.namespaces().map(fn(ns) { (ns.name(), ns.uri()) }), [
    (Some("y"), "urn:y"),
    (Some("x"), "urn:x"),
    (None, "urn:d"),
  ])
  assert_eq(doc.root().namespaces().length(), 0)
  assert_eq(doc.root().attributes().length(), 0)
}

///|
test "text merging across references, cdata and entities" {
  let doc = @xml.Document::parse_with_options(
    "<!DOCTYPE r [<!ENTITY e 'E'><!ENTITY t '<i>I</i>'>]><r>a&e;b<![CDATA[c]]>&#100;&t;f</r>",
    { allow_dtd: true, nodes_limit: 0xFFFF_FFFFU, },
  )
  let r = doc.root_element()
  let kids = r.children()
  assert_eq(kids.length(), 3)
  assert_eq(kids[0].text(), Some("aEbcd"))
  assert_eq(kids[1].tag_name().name(), "i")
  assert_eq(kids[1].text(), Some("I"))
  assert_eq(kids[2].text(), Some("f"))
  assert_eq(r.text(), Some("aEbcd"))
  assert_eq(kids[1].tail(), Some("f"))
}

///|
test "input text and text_pos_at" {
  let doc = @xml.Document::parse("<!-- comment -->\n<e/>")
  assert_eq(doc.text_pos_at(10), @xml.TextPos::new(1, 11))
  assert_eq(doc.text_pos_at(9999), @xml.TextPos::new(2, 5))
  assert_eq(doc.input_text(), "<!-- comment -->\n<e/>")
  assert_eq(doc.get_node(1).unwrap().is_comment(), true)
  assert_eq(doc.get_node(4), None)
}
