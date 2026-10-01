// Expected values are the upstream Typst oracle outputs of `json.encode(xml(bytes(..)), pretty: false)` (see `typst_xml` in xml_test.mbt).

///|
test "oracle/xml_c1/0" {
  assert_eq(
    typst_xml("<a x='1'>t<!--c--><?pi v?><b/></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"1\"},\"children\":[\"t\",{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c1/1" {
  assert_eq(
    typst_xml(
      "<data>\n  <hello name=\"hi\">1</hello>\n  <data>\n    <hello>World</hello>\n    <hello>World</hello>\n  </data>\n</data>\n",
    ),
    "[{\"namespace\":null,\"tag\":\"data\",\"attrs\":{},\"children\":[\"\\n  \",{\"namespace\":null,\"tag\":\"hello\",\"attrs\":{\"name\":\"hi\"},\"children\":[\"1\"]},\"\\n  \",{\"namespace\":null,\"tag\":\"data\",\"attrs\":{},\"children\":[\"\\n    \",{\"namespace\":null,\"tag\":\"hello\",\"attrs\":{},\"children\":[\"World\"]},\"\\n    \",{\"namespace\":null,\"tag\":\"hello\",\"attrs\":{},\"children\":[\"World\"]},\"\\n  \"]},\"\\n\"]}]",
  )
}

///|
test "oracle/xml_c1/2" {
  assert_eq(
    typst_xml(
      "<data xmlns=\"http://example.org\" xmlns:foo=\"urn:foo\">\n  <hello name=\"hi\">1</hello>\n  <foo:hello>World</foo:hello>\n</data>",
    ),
    "[{\"namespace\":\"http://example.org\",\"tag\":\"data\",\"attrs\":{},\"children\":[\"\\n  \",{\"namespace\":\"http://example.org\",\"tag\":\"hello\",\"attrs\":{\"name\":\"hi\"},\"children\":[\"1\"]},\"\\n  \",{\"namespace\":\"urn:foo\",\"tag\":\"hello\",\"attrs\":{},\"children\":[\"World\"]},\"\\n\"]}]",
  )
}

///|
test "oracle/xml_c1/3" {
  assert_eq(
    typst_xml("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root/>"),
    "[{\"namespace\":null,\"tag\":\"root\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/4" {
  assert_eq(
    typst_xml("<?xml version='1.0' standalone='yes' ?><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/5" {
  assert_eq(
    typst_xml(
      "<?xml version='1.0' encoding='utf-8' standalone='no'?>\n<!-- top -->\n<?top pi?>\n<r/>\n<!-- after -->\n<?after?>\n",
    ),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/6" {
  assert_eq(
    typst_xml("\u{feff}<r>bom</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"bom\"]}]",
  )
}

///|
test "oracle/xml_c1/7" {
  assert_eq(
    typst_xml("  \n<r/>  \n "),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/8" {
  assert_eq(
    typst_xml("<r></r >"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/9" {
  assert_eq(
    typst_xml("<r><a></a><b/><c x='1' y=\"2\" /></r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"c\",\"attrs\":{\"x\":\"1\",\"y\":\"2\"},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c1/10" {
  assert_eq(
    typst_xml("<a><![CDATA[<x>&amp;]]></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"<x>&amp;\"]}]",
  )
}

///|
test "oracle/xml_c1/11" {
  assert_eq(
    typst_xml("<a>x<![CDATA[y]]>z</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"xyz\"]}]",
  )
}

///|
test "oracle/xml_c1/12" {
  assert_eq(
    typst_xml("<a><![CDATA[]]></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"\"]}]",
  )
}

///|
test "oracle/xml_c1/13" {
  assert_eq(
    typst_xml("<a><![CDATA[a\r\nb\rc\n]]></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"a\\nb\\nc\\n\"]}]",
  )
}

///|
test "oracle/xml_c1/14" {
  assert_eq(
    typst_xml("<a>&#65;&#x42;&lt;&gt;&amp;&quot;&apos;</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"AB<>&\\\"'\"]}]",
  )
}

///|
test "oracle/xml_c1/15" {
  assert_eq(
    typst_xml("<a>&#x1F600;&#128512;</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"😀😀\"]}]",
  )
}

///|
test "oracle/xml_c1/16" {
  assert_eq(
    typst_xml("<a>&#xD800;</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"�\"]}]",
  )
}

///|
test "oracle/xml_c1/17" {
  assert_eq(
    typst_xml("<a>&#x110000;</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"�\"]}]",
  )
}

///|
test "oracle/xml_c1/18" {
  assert_eq(
    typst_xml("<a>&#0;</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/19" {
  assert_eq(
    typst_xml("<a>&#x;</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/20" {
  assert_eq(
    typst_xml("<a>&#X41;</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/21" {
  assert_eq(
    typst_xml("<a>&#xZZ;</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/22" {
  assert_eq(
    typst_xml("<a>&#65</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/23" {
  assert_eq(
    typst_xml("<a>&;</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/24" {
  assert_eq(
    typst_xml("<a>& b</a>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/25" {
  assert_eq(
    typst_xml("<a>&unknown;</a>"),
    "error: failed to parse XML (unknown entity 'unknown' at 1:4)",
  )
}

///|
test "oracle/xml_c1/26" {
  assert_eq(
    typst_xml("<a>a\r\nb\rc\n\rd\r</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"a\\nb\\nc\\n\\nd\\n\"]}]",
  )
}

///|
test "oracle/xml_c1/27" {
  assert_eq(
    typst_xml("<a>a&amp;\r\nb</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"a&\\nb\"]}]",
  )
}

///|
test "oracle/xml_c1/28" {
  assert_eq(
    typst_xml("<a>x&#13;y&#13;&#10;z</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"x\\ry\\r\\nz\"]}]",
  )
}

///|
test "oracle/xml_c1/29" {
  assert_eq(
    typst_xml("<a>x\r&#10;</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"x\\r\\n\"]}]",
  )
}

///|
test "oracle/xml_c1/30" {
  assert_eq(
    typst_xml("<a>]]></a>"),
    "error: failed to parse XML (']]>' at 1:7 is not allowed inside a character data at 1:7)",
  )
}

///|
test "oracle/xml_c1/31" {
  assert_eq(
    typst_xml("<a>]]</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"]]\"]}]",
  )
}

///|
test "oracle/xml_c1/32" {
  assert_eq(
    typst_xml("<a>></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\">\"]}]",
  )
}

///|
test "oracle/xml_c1/33" {
  assert_eq(
    typst_xml("<a>\u{1}</a>"),
    "error: failed to parse XML (a non-XML character '\\u{1}' found at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/34" {
  assert_eq(
    typst_xml("<a>x\u{fffe}y</a>"),
    "error: failed to parse XML (a non-XML character '\\u{fffe}' found at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/35" {
  assert_eq(
    typst_xml("<a>\u{0}</a>"),
    "error: failed to parse XML (a non-XML character '\\0' found at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/36" {
  assert_eq(
    typst_xml("<a>\t\n</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"\\t\\n\"]}]",
  )
}

///|
test "oracle/xml_c1/37" {
  assert_eq(
    typst_xml("<a>ä日本😀</a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"ä日本😀\"]}]",
  )
}

///|
test "oracle/xml_c1/38" {
  assert_eq(
    typst_xml("<ä ö='ü'>日本</ä>"),
    "[{\"namespace\":null,\"tag\":\"ä\",\"attrs\":{\"ö\":\"ü\"},\"children\":[\"日本\"]}]",
  )
}

///|
test "oracle/xml_c1/39" {
  assert_eq(
    typst_xml("<a x='a\tb\nc\r\nd\re'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"a b c d e\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/40" {
  assert_eq(
    typst_xml("<a x='&#9;&#10;&#13;&#32;'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"\\t\\n\\r \"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/41" {
  assert_eq(
    typst_xml("<a x='&lt;&amp;&#60;'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"<&<\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/42" {
  assert_eq(
    typst_xml("<a x='\"' y=\"'\"/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"\\\"\",\"y\":\"'\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/43" {
  assert_eq(
    typst_xml("<a x = '1'\n y\t=\t\"2\"/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"1\",\"y\":\"2\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/44" {
  assert_eq(
    typst_xml("<a x='1' x='2'/>"),
    "error: failed to parse XML (duplicate attribute 'x' at 1:10)",
  )
}

///|
test "oracle/xml_c1/45" {
  assert_eq(
    typst_xml("<a xmlns:n1='u' xmlns:n2='u' n1:x='1' n2:x='2'/>"),
    "error: failed to parse XML (duplicate attribute 'x' at 1:39)",
  )
}

///|
test "oracle/xml_c1/46" {
  assert_eq(
    typst_xml("<a xmlns:n1='u' n1:x='1' x='2'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"x\":\"2\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/47" {
  assert_eq(
    typst_xml("<a x='<'/>"),
    "error: failed to parse XML (expected ''' not '<' at 1:7 at 1:7)",
  )
}

///|
test "oracle/xml_c1/48" {
  assert_eq(
    typst_xml("<a x='1'y='2'/>"),
    "error: failed to parse XML (expected a whitespace not 'y' at 1:9 at 1:9)",
  )
}

///|
test "oracle/xml_c1/49" {
  assert_eq(
    typst_xml("<a x=1/>"),
    "error: failed to parse XML (expected a quote not '1' at 1:6 at 1:6)",
  )
}

///|
test "oracle/xml_c1/50" {
  assert_eq(
    typst_xml("<a x/>"),
    "error: failed to parse XML (expected '=' not '/' at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/51" {
  assert_eq(
    typst_xml("<a x='\u{1}'/>"),
    "error: failed to parse XML (a non-XML character '\\u{1}' found at 1:7 at 1:7)",
  )
}

///|
test "oracle/xml_c1/52" {
  assert_eq(
    typst_xml("<a x='a\u{fffe}'/>"),
    "error: failed to parse XML (a non-XML character '\\u{fffe}' found at 1:8 at 1:8)",
  )
}

///|
test "oracle/xml_c1/53" {
  assert_eq(
    typst_xml("<a x='&e;'/>"),
    "error: failed to parse XML (unknown entity 'e' at 1:7)",
  )
}

///|
test "oracle/xml_c1/54" {
  assert_eq(
    typst_xml("<a x='&#0;'/>"),
    "error: failed to parse XML (malformed entity reference at 1:7 at 1:7)",
  )
}

///|
test "oracle/xml_c1/55" {
  assert_eq(
    typst_xml("<a x='& '/>"),
    "error: failed to parse XML (malformed entity reference at 1:7 at 1:7)",
  )
}

///|
test "oracle/xml_c1/56" {
  assert_eq(
    typst_xml("<a xml:lang='en'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"lang\":\"en\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/57" {
  assert_eq(
    typst_xml("<a xml:x='1' xml:x='2'/>"),
    "error: failed to parse XML (duplicate attribute 'x' at 1:14)",
  )
}

///|
test "oracle/xml_c1/58" {
  assert_eq(
    typst_xml("<a:b/>"),
    "error: failed to parse XML (an unknown namespace prefix 'a' at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c1/59" {
  assert_eq(
    typst_xml(
      "<x:a xmlns:x='urn:x'><x:b/><b/><y:c xmlns:y='urn:y' y:at='1' x:at='2' at='3'/></x:a>",
    ),
    "[{\"namespace\":\"urn:x\",\"tag\":\"a\",\"attrs\":{},\"children\":[{\"namespace\":\"urn:x\",\"tag\":\"b\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[]},{\"namespace\":\"urn:y\",\"tag\":\"c\",\"attrs\":{\"at\":\"3\"},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c1/60" {
  assert_eq(
    typst_xml("<a xmlns='urn:d'><b xmlns=''><c/></b><d/></a>"),
    "[{\"namespace\":\"urn:d\",\"tag\":\"a\",\"attrs\":{},\"children\":[{\"namespace\":\"\",\"tag\":\"b\",\"attrs\":{},\"children\":[{\"namespace\":\"\",\"tag\":\"c\",\"attrs\":{},\"children\":[]}]},{\"namespace\":\"urn:d\",\"tag\":\"d\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c1/61" {
  assert_eq(
    typst_xml("<a xmlns='urn:d' x='1'/>"),
    "[{\"namespace\":\"urn:d\",\"tag\":\"a\",\"attrs\":{\"x\":\"1\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/62" {
  assert_eq(
    typst_xml("<xmlns:a/>"),
    "error: failed to parse XML (the 'xmlns' prefix is used at 1:2, but it must not be at 1:2)",
  )
}

///|
test "oracle/xml_c1/63" {
  assert_eq(
    typst_xml("<xml:a/>"),
    "error: failed to parse XML (an unknown namespace prefix 'xml' at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c1/64" {
  assert_eq(
    typst_xml("<a xmlns:xml='http://www.w3.org/XML/1998/namespace'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/65" {
  assert_eq(
    typst_xml("<a xmlns:xml='foo'/>"),
    "error: failed to parse XML ('xml' namespace prefix mapped to wrong URI at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/66" {
  assert_eq(
    typst_xml("<a xmlns:x='http://www.w3.org/XML/1998/namespace'/>"),
    "error: failed to parse XML (the 'xml' namespace URI is used for not 'xml' prefix at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/67" {
  assert_eq(
    typst_xml("<a xmlns='http://www.w3.org/XML/1998/namespace'/>"),
    "error: failed to parse XML (the 'xml' namespace URI is used for not 'xml' prefix at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/68" {
  assert_eq(
    typst_xml("<a xmlns='http://www.w3.org/2000/xmlns/'/>"),
    "error: failed to parse XML (the 'xmlns' URI is used at 1:4, but it must not be declared at 1:4)",
  )
}

///|
test "oracle/xml_c1/69" {
  assert_eq(
    typst_xml("<a xmlns:x='http://www.w3.org/2000/xmlns/'/>"),
    "error: failed to parse XML (the 'xmlns' URI is used at 1:4, but it must not be declared at 1:4)",
  )
}

///|
test "oracle/xml_c1/70" {
  assert_eq(
    typst_xml("<a xmlns:x='u' xmlns:x='v'/>"),
    "error: failed to parse XML (namespace 'x' at 1:16 is already defined at 1:16)",
  )
}

///|
test "oracle/xml_c1/71" {
  assert_eq(
    typst_xml("<a xmlns='u' xmlns='v'/>"),
    "[{\"namespace\":\"u\",\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/72" {
  assert_eq(
    typst_xml("<a xmlns:x='u'><b xmlns:x='v'><x:c/></b><x:d/></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[{\"namespace\":\"v\",\"tag\":\"c\",\"attrs\":{},\"children\":[]}]},{\"namespace\":\"u\",\"tag\":\"d\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c1/73" {
  assert_eq(
    typst_xml("<a xmlns:x='u'></x:a>"),
    "error: failed to parse XML (found closing tag 'x:a' instead of 'a' at 1:16)",
  )
}

///|
test "oracle/xml_c1/74" {
  assert_eq(
    typst_xml("<x:a xmlns:x='u'></a>"),
    "error: failed to parse XML (found closing tag 'a' instead of 'x:a' at 1:18)",
  )
}

///|
test "oracle/xml_c1/75" {
  assert_eq(
    typst_xml("<x:a xmlns:x='u'></y:a>"),
    "error: failed to parse XML (found closing tag 'y:a' instead of 'x:a' at 1:18)",
  )
}

///|
test "oracle/xml_c1/76" {
  assert_eq(
    typst_xml("<a b:c:d='1'/>"),
    "error: failed to parse XML (invalid name token at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/77" {
  assert_eq(
    typst_xml("<a:b:c/>"),
    "error: failed to parse XML (invalid name token at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c1/78" {
  assert_eq(
    typst_xml("<:a/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/79" {
  assert_eq(
    typst_xml("<a:/>"),
    "error: failed to parse XML (invalid name token at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c1/80" {
  assert_eq(
    typst_xml("<a xmlns:x='&amp;'><x:b/></a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[{\"namespace\":\"&\",\"tag\":\"b\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c1/81" {
  assert_eq(
    typst_xml(""),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c1/82" {
  assert_eq(
    typst_xml("   "),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c1/83" {
  assert_eq(
    typst_xml("<a>"),
    "error: failed to parse XML (the root node was opened but never closed at 1:1)",
  )
}

///|
test "oracle/xml_c1/84" {
  assert_eq(
    typst_xml("<a"),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c1/85" {
  assert_eq(
    typst_xml("<a "),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c1/86" {
  assert_eq(
    typst_xml("<a x='1' "),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c1/87" {
  assert_eq(
    typst_xml("<a x='1"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c1/88" {
  assert_eq(
    typst_xml("<a x"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c1/89" {
  assert_eq(
    typst_xml("<a></b>"),
    "error: failed to parse XML (found closing tag 'b' instead of 'a' at 1:4)",
  )
}

///|
test "oracle/xml_c1/90" {
  assert_eq(
    typst_xml("<a><b></a>"),
    "error: failed to parse XML (found closing tag 'a' instead of 'b' at 1:7)",
  )
}

///|
test "oracle/xml_c1/91" {
  assert_eq(
    typst_xml("<data>\n  <hello>\n</data>"),
    "error: failed to parse XML (found closing tag 'data' instead of 'hello' at 3:1)",
  )
}

///|
test "oracle/xml_c1/92" {
  assert_eq(
    typst_xml("<a/><b/>"),
    "error: failed to parse XML (unknown token at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/93" {
  assert_eq(
    typst_xml("<a/>text"),
    "error: failed to parse XML (unknown token at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/94" {
  assert_eq(
    typst_xml("</a>"),
    "error: failed to parse XML (invalid name token at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c1/95" {
  assert_eq(
    typst_xml("<1a/>"),
    "error: failed to parse XML (invalid name token at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c1/96" {
  assert_eq(
    typst_xml("<a>text"),
    "error: failed to parse XML (the root node was opened but never closed at 1:1)",
  )
}

///|
test "oracle/xml_c1/97" {
  assert_eq(
    typst_xml("<a><b>"),
    "error: failed to parse XML (the root node was opened but never closed at 1:1)",
  )
}

///|
test "oracle/xml_c1/98" {
  assert_eq(
    typst_xml("<a></a><!-- x"),
    "error: failed to parse XML (expected '-->' at 1:14 at 1:14)",
  )
}

///|
test "oracle/xml_c1/99" {
  assert_eq(
    typst_xml("<a><!-- x"),
    "error: failed to parse XML (expected '-->' at 1:10 at 1:10)",
  )
}

///|
test "oracle/xml_c1/100" {
  assert_eq(
    typst_xml("<a><![CDATA[x</a>"),
    "error: failed to parse XML (expected ']]>' at 1:18 at 1:18)",
  )
}

///|
test "oracle/xml_c1/101" {
  assert_eq(
    typst_xml("<a><!x></a>"),
    "error: failed to parse XML (unknown token at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/102" {
  assert_eq(
    typst_xml("<a><"),
    "error: failed to parse XML (unknown token at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c1/103" {
  assert_eq(
    typst_xml("<a>x<"),
    "error: failed to parse XML (unknown token at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/104" {
  assert_eq(
    typst_xml("<a></"),
    "error: failed to parse XML (invalid name token at 1:6 at 1:6)",
  )
}

///|
test "oracle/xml_c1/105" {
  assert_eq(
    typst_xml("<a><b/"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c1/106" {
  assert_eq(
    typst_xml("<?xml version='1.0'?><?xml version='1.0'?><a/>"),
    "error: failed to parse XML (unexpected XML declaration at 1:22 at 1:22)",
  )
}

///|
test "oracle/xml_c1/107" {
  assert_eq(
    typst_xml("<a/><?xml version='1.0'?>"),
    "error: failed to parse XML (unexpected XML declaration at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/108" {
  assert_eq(
    typst_xml("<?xml encoding='x'?><a/>"),
    "error: failed to parse XML (expected 'version' at 1:7 at 1:7)",
  )
}

///|
test "oracle/xml_c1/109" {
  assert_eq(
    typst_xml("<?xml version='1.0'><a/>"),
    "error: failed to parse XML (expected a whitespace not '>' at 1:20 at 1:20)",
  )
}

///|
test "oracle/xml_c1/110" {
  assert_eq(
    typst_xml("<?xml version='1.0' foo='bar'?><a/>"),
    "error: failed to parse XML (expected '?>' at 1:21 at 1:21)",
  )
}

///|
test "oracle/xml_c1/111" {
  assert_eq(
    typst_xml("<?xml version='1.0'encoding='x'?><a/>"),
    "error: failed to parse XML (expected a whitespace not 'e' at 1:20 at 1:20)",
  )
}

///|
test "oracle/xml_c1/112" {
  assert_eq(
    typst_xml("<?xml version='1<'?><a/>"),
    "error: failed to parse XML (expected ''' not '<' at 1:17 at 1:17)",
  )
}

///|
test "oracle/xml_c1/113" {
  assert_eq(
    typst_xml("<?xml\tversion='1.0'?><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/114" {
  assert_eq(
    typst_xml("<?xml?><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/115" {
  assert_eq(
    typst_xml("<?xml version='1.0'?>"),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c1/116" {
  assert_eq(
    typst_xml("<!-- c -->"),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c1/117" {
  assert_eq(
    typst_xml("<!-- a -- b --><a/>"),
    "error: failed to parse XML (comment at 1:1 contains '--' at 1:1)",
  )
}

///|
test "oracle/xml_c1/118" {
  assert_eq(
    typst_xml("<!-- a ---><a/>"),
    "error: failed to parse XML (comment at 1:1 contains '--' at 1:1)",
  )
}

///|
test "oracle/xml_c1/119" {
  assert_eq(
    typst_xml("<!----><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/120" {
  assert_eq(
    typst_xml("<!---><a/>"),
    "error: failed to parse XML (expected '-->' at 1:11 at 1:11)",
  )
}

///|
test "oracle/xml_c1/121" {
  assert_eq(
    typst_xml("<?pi?><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/122" {
  assert_eq(
    typst_xml("<?pi x?y ?><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/123" {
  assert_eq(
    typst_xml("<?pi"),
    "error: failed to parse XML (expected '?>' at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c1/124" {
  assert_eq(
    typst_xml("<?pi x"),
    "error: failed to parse XML (expected '?>' at 1:7 at 1:7)",
  )
}

///|
test "oracle/xml_c1/125" {
  assert_eq(
    typst_xml("<?1pi?><a/>"),
    "error: failed to parse XML (invalid name token at 1:3 at 1:3)",
  )
}

///|
test "oracle/xml_c1/126" {
  assert_eq(
    typst_xml("<?a-b c?><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/127" {
  assert_eq(
    typst_xml("<?a/b?><a/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c1/128" {
  assert_eq(
    typst_xml("<a/>\n<b"),
    "error: failed to parse XML (unknown token at 2:1 at 2:1)",
  )
}

///|
test "oracle/xml_c1/129" {
  assert_eq(
    typst_xml("<a/>\näö"),
    "error: failed to parse XML (unknown token at 2:1 at 2:1)",
  )
}

///|
test "oracle/xml_c1/130" {
  assert_eq(
    typst_xml("ä\n  日本<a></b>"),
    "error: failed to parse XML (unknown token at 1:1 at 1:1)",
  )
}

///|
test "oracle/xml_c1/131" {
  assert_eq(
    typst_xml("<ä>\n日本</b>"),
    "error: failed to parse XML (found closing tag 'b' instead of 'ä' at 2:3)",
  )
}

///|
test "oracle/xml_c1/132" {
  assert_eq(
    typst_xml("<a>\n\tää</b>"),
    "error: failed to parse XML (found closing tag 'b' instead of 'a' at 2:4)",
  )
}
