// Expected values are the upstream Typst oracle outputs of `json.encode(xml(bytes(..)), pretty: false)` (see `typst_xml` in xml_test.mbt).

///|
test "oracle/xml_c2/0" {
  assert_eq(
    typst_xml("<!DOCTYPE r><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/1" {
  assert_eq(
    typst_xml("<!DOCTYPE r ><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/2" {
  assert_eq(
    typst_xml("<!DOCTYPE r []><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/3" {
  assert_eq(
    typst_xml("<!DOCTYPE r [ ] ><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/4" {
  assert_eq(
    typst_xml("<!DOCTYPE r SYSTEM 'r.dtd'><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/5" {
  assert_eq(
    typst_xml("<!DOCTYPE r PUBLIC '-//X//Y' \"r.dtd\"><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/6" {
  assert_eq(
    typst_xml("<!DOCTYPE r PUBLIC '-//X//Y'><r/>"),
    "error: failed to parse XML (expected a whitespace not '>' at 1:29 at 1:29)",
  )
}

///|
test "oracle/xml_c2/7" {
  assert_eq(
    typst_xml("<!DOCTYPE r SYSTEM><r/>"),
    "error: failed to parse XML (expected a whitespace not '>' at 1:19 at 1:19)",
  )
}

///|
test "oracle/xml_c2/8" {
  assert_eq(
    typst_xml("<!DOCTYPE r SYSTEM 'x' [<!ENTITY e 'v'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"v\"]}]",
  )
}

///|
test "oracle/xml_c2/9" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e \"text\">]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"text\"]}]",
  )
}

///|
test "oracle/xml_c2/10" {
  assert_eq(
    typst_xml("<!DOCTYPE r [\n  <!ENTITY e 'text'>\n]>\n<r>a&e;b&e;c</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"atextbtextc\"]}]",
  )
}

///|
test "oracle/xml_c2/11" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e \"<b>x</b>\">]><r>a&e;c</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a\",{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[\"x\"]},\"c\"]}]",
  )
}

///|
test "oracle/xml_c2/12" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e \"<b x='1'>x</b>y<c/>\">]><r>&e;&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[{\"namespace\":null,\"tag\":\"b\",\"attrs\":{\"x\":\"1\"},\"children\":[\"x\"]},\"y\",{\"namespace\":null,\"tag\":\"c\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"b\",\"attrs\":{\"x\":\"1\"},\"children\":[\"x\"]},\"y\",{\"namespace\":null,\"tag\":\"c\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c2/13" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY a 'A'><!ENTITY b '[&a;&a;]'>]><r>&b;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"[AA]\"]}]",
  )
}

///|
test "oracle/xml_c2/14" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [<!ENTITY a 'A'><!ENTITY b '&a;-&#66;-&lt;'>]><r x='&b;'>&b;</r>",
    ),
    "error: failed to parse XML (unescaped '<' found at 1:51 at 1:51)",
  )
}

///|
test "oracle/xml_c2/15" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&#60;b/>'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"<b/>\"]}]",
  )
}

///|
test "oracle/xml_c2/16" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&#38;#60;'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"&#60;\"]}]",
  )
}

///|
test "oracle/xml_c2/17" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x&#13;y'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"x\\ny\"]}]",
  )
}

///|
test "oracle/xml_c2/18" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x\r\ny\rz'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"x\\ny\\nz\"]}]",
  )
}

///|
test "oracle/xml_c2/19" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'a\tb\nc'>]><r x='&e;'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"a b c\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/20" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&#9;&#10;'>]><r x='&e;'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"  \"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/21" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&lt;'>]><r x='&e;'/>"),
    "error: failed to parse XML (unescaped '<' found at 1:26 at 1:26)",
  )
}

///|
test "oracle/xml_c2/22" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '<'>]><r x='&e;'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"<\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/23" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&#60;'>]><r x='&e;'/>"),
    "error: failed to parse XML (unescaped '<' found at 1:26 at 1:26)",
  )
}

///|
test "oracle/xml_c2/24" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&gt;'>]><r x='&e;'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\">\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/25" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'v'>]><r x='a&e;b' y='&e;&e;'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"avb\",\"y\":\"vv\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/26" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'v'>]><r xmlns:p='&e;'><p:c/></r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[{\"namespace\":\"v\",\"tag\":\"c\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c2/27" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'v'><!ENTITY e 'w'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"v\"]}]",
  )
}

///|
test "oracle/xml_c2/28" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY % p 'x'>]><r>&p;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"x\"]}]",
  )
}

///|
test "oracle/xml_c2/29" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY % p SYSTEM 'p.ent'>]><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/30" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e SYSTEM 'e.ent'>]><r>&e;</r>"),
    "error: failed to parse XML (unknown entity 'e' at 1:45)",
  )
}

///|
test "oracle/xml_c2/31" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e PUBLIC 'pub' 'e.ent'>]><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/32" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e SYSTEM 'e.ent' NDATA gif>]><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/33" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e SYS>]><r/>"),
    "error: failed to parse XML (invalid ExternalID at 1:25 at 1:25)",
  )
}

///|
test "oracle/xml_c2/34" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e x>]><r/>"),
    "error: failed to parse XML (expected a quote, SYSTEM or PUBLIC not 'x' at 1:25 at 1:25)",
  )
}

///|
test "oracle/xml_c2/35" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x'x>]><r/>"),
    "error: failed to parse XML (expected '>' not 'x' at 1:28 at 1:28)",
  )
}

///|
test "oracle/xml_c2/36" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x'\n]><r/>"),
    "error: failed to parse XML (expected '>' not ']' at 2:1 at 2:1)",
  )
}

///|
test "oracle/xml_c2/37" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY 1e 'x'>]><r/>"),
    "error: failed to parse XML (invalid name token at 1:23 at 1:23)",
  )
}

///|
test "oracle/xml_c2/38" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITYe 'x'>]><r/>"),
    "error: failed to parse XML (expected a whitespace not 'e' at 1:22 at 1:22)",
  )
}

///|
test "oracle/xml_c2/39" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x>]><r/>"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c2/40" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [<!ELEMENT r (#PCDATA)><!ATTLIST r a CDATA #IMPLIED><!NOTATION n SYSTEM 'x'>]><r/>",
    ),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/41" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!-- c --><?pi x?>]><r/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/42" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!FOO>]><r/>"),
    "error: failed to parse XML (unknown token at 1:14 at 1:14)",
  )
}

///|
test "oracle/xml_c2/43" {
  assert_eq(
    typst_xml("\n<!DOCTYPE r [\n<!ELEMENT r"),
    "error: failed to parse XML (unknown token at 2:1 at 2:1)",
  )
}

///|
test "oracle/xml_c2/44" {
  assert_eq(
    typst_xml("<!DOCTYPE r [ ] x><r/>"),
    "error: failed to parse XML (expected '>' not 'x' at 1:17 at 1:17)",
  )
}

///|
test "oracle/xml_c2/45" {
  assert_eq(
    typst_xml("<!DOCTYPE r [ ]"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c2/46" {
  assert_eq(
    typst_xml("<!DOCTYPE r ["),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c2/47" {
  assert_eq(
    typst_xml("<!DOCTYPE r x><r/>"),
    "error: failed to parse XML (expected '[' or '>' not 'x' at 1:13 at 1:13)",
  )
}

///|
test "oracle/xml_c2/48" {
  assert_eq(
    typst_xml("<!DOCTYPE r"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c2/49" {
  assert_eq(
    typst_xml("<!DOCTYPE"),
    "error: failed to parse XML (unexpected end of stream at 1:1)",
  )
}

///|
test "oracle/xml_c2/50" {
  assert_eq(
    typst_xml("<!DOCTYPE r>"),
    "error: failed to parse XML (missing root node at 1:1)",
  )
}

///|
test "oracle/xml_c2/51" {
  assert_eq(
    typst_xml("<!DOCTYPEr><r/>"),
    "error: failed to parse XML (expected a whitespace not 'r' at 1:10 at 1:10)",
  )
}

///|
test "oracle/xml_c2/52" {
  assert_eq(
    typst_xml("<!DOCTYPE 1r><r/>"),
    "error: failed to parse XML (invalid name token at 1:11 at 1:11)",
  )
}

///|
test "oracle/xml_c2/53" {
  assert_eq(
    typst_xml("<!DOCTYPE r><!DOCTYPE r><r/>"),
    "error: failed to parse XML (invalid name token at 1:14 at 1:14)",
  )
}

///|
test "oracle/xml_c2/54" {
  assert_eq(
    typst_xml("<r/><!DOCTYPE r>"),
    "error: failed to parse XML (unknown token at 1:5 at 1:5)",
  )
}

///|
test "oracle/xml_c2/55" {
  assert_eq(
    typst_xml("<!-- c --><!DOCTYPE r><!-- d --><r/>"),
    "[{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/56" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '</p>'>]><r>&e;</r>"),
    "error: failed to parse XML (unexpected close tag at 1:26 at 1:26)",
  )
}

///|
test "oracle/xml_c2/57" {
  assert_eq(
    typst_xml("<!DOCTYPE p [<!ENTITY p '<p></p></p>'>]><p>&p;&p;"),
    "error: failed to parse XML (unexpected close tag at 1:33 at 1:33)",
  )
}

///|
test "oracle/xml_c2/58" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '<b>'>]><r>&e;</r>"),
    "error: failed to parse XML (found closing tag 'r' instead of 'b' at 1:39)",
  )
}

///|
test "oracle/xml_c2/59" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '<b>'>]><r>&e;</b></r>"),
    "error: failed to parse XML (unknown token at 1:43 at 1:43)",
  )
}

///|
test "oracle/xml_c2/60" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '</b>'>]><r><b>&e;</r>"),
    "error: failed to parse XML (unexpected close tag at 1:26 at 1:26)",
  )
}

///|
test "oracle/xml_c2/61" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '<b></c>'>]><r>&e;</r>"),
    "error: failed to parse XML (found closing tag 'c' instead of 'b' at 1:29)",
  )
}

///|
test "oracle/xml_c2/62" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY a '&b;'><!ENTITY b '&a;'>]><r>&a;</r>"),
    "error: failed to parse XML (a possible entity reference loop is detected at 1:46 at 1:46)",
  )
}

///|
test "oracle/xml_c2/63" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY a '&b;'><!ENTITY b '&a;'>]><r x='&a;'/>"),
    "error: failed to parse XML (a possible entity reference loop is detected at 1:46 at 1:46)",
  )
}

///|
test "oracle/xml_c2/64" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY a '&a;'>]><r>x&a;</r>"),
    "error: failed to parse XML (a possible entity reference loop is detected at 1:29 at 1:29)",
  )
}

///|
test "oracle/xml_c2/65" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [\n<!ENTITY lol \"lol\">\n<!ENTITY lol1 \"&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;\">\n<!ENTITY lol2 \"&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;\">\n<!ENTITY lol3 \"&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;\">\n]>\n<r>&lol3;</r>",
    ),
    "error: failed to parse XML (a possible entity reference loop is detected at 3:66 at 3:66)",
  )
}

///|
test "oracle/xml_c2/66" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [\n<!ENTITY lol \"lol\">\n<!ENTITY lol1 \"&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;\">\n<!ENTITY lol2 \"&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;\">\n<!ENTITY lol3 \"&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;\">\n]>\n<r a='&lol3;'/>",
    ),
    "error: failed to parse XML (a possible entity reference loop is detected at 3:66 at 3:66)",
  )
}

///|
test "oracle/xml_c2/67" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [\n<!ENTITY lol \"lol\">\n<!ENTITY lol1 \"&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;\">\n<!ENTITY lol2 \"&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;\">\n]>\n<r>&lol2;&lol2;</r>",
    ),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"lollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollol\"]}]",
  )
}

///|
test "oracle/xml_c2/68" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [<!ENTITY e1 '&e2;'><!ENTITY e2 '&e3;'><!ENTITY e3 '&e4;'><!ENTITY e4 '&e5;'><!ENTITY e5 '&e6;'><!ENTITY e6 '&e7;'><!ENTITY e7 '&e8;'><!ENTITY e8 '&e9;'><!ENTITY e9 '&e10;'><!ENTITY e10 'x'>]><r>&e1;</r>",
    ),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"x\"]}]",
  )
}

///|
test "oracle/xml_c2/69" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [<!ENTITY e1 '&e2;'><!ENTITY e2 '&e3;'><!ENTITY e3 '&e4;'><!ENTITY e4 '&e5;'><!ENTITY e5 '&e6;'><!ENTITY e6 '&e7;'><!ENTITY e7 '&e8;'><!ENTITY e8 '&e9;'><!ENTITY e9 '&e10;'><!ENTITY e10 '&e11;'><!ENTITY e11 'x'>]><r>&e1;</r>",
    ),
    "error: failed to parse XML (a possible entity reference loop is detected at 1:205 at 1:205)",
  )
}

///|
test "oracle/xml_c2/70" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&unknown;'>]><r>&e;</r>"),
    "error: failed to parse XML (unknown entity 'unknown' at 1:26)",
  )
}

///|
test "oracle/xml_c2/71" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&#0;'>]><r>&e;</r>"),
    "error: failed to parse XML (malformed entity reference at 1:26 at 1:26)",
  )
}

///|
test "oracle/xml_c2/72" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'a]]>b'>]><r>&e;</r>"),
    "error: failed to parse XML (']]>' at 1:31 is not allowed inside a character data at 1:31)",
  )
}

///|
test "oracle/xml_c2/73" {
  assert_eq(
    typst_xml(
      "<!DOCTYPE r [<!ENTITY e '<!-- c -->x<?p?><![CDATA[y]]>'>]><r>a&e;b</r>",
    ),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a\",{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},\"x\",{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},\"yb\"]}]",
  )
}

///|
test "oracle/xml_c2/74" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '<x:b/>'>]><r xmlns:x='u'>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[{\"namespace\":\"u\",\"tag\":\"b\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c2/75" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '<x:b/>'>]><r>&e;</r>"),
    "error: failed to parse XML (an unknown namespace prefix 'x' at 1:27 at 1:27)",
  )
}

///|
test "oracle/xml_c2/76" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e ''>]><r>a&e;b</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"ab\"]}]",
  )
}

///|
test "oracle/xml_c2/77" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e ''>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/78" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x'>]><r>&e;<b/>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"x\",{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[]},\"x\"]}]",
  )
}

///|
test "oracle/xml_c2/79" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'ä日'>]><r>ö&e;ü</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"öä日ü\"]}]",
  )
}

///|
test "oracle/xml_c2/80" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x\u{1}'>]><r/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/81" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'x'>]>\n<r>\n  &e;\n  &f;</r>"),
    "error: failed to parse XML (unknown entity 'f' at 4:3)",
  )
}

///|
test "oracle/xml_c2/82" {
  assert_eq(
    typst_xml("<!DOCTYPE r [\n<!ENTITY e 'a\n&f;'>\n]>\n<r>&e;</r>"),
    "error: failed to parse XML (unknown entity 'f' at 3:1)",
  )
}

///|
test "oracle/xml_c2/83" {
  assert_eq(
    typst_xml("<!DOCTYPE r [\n<!ENTITY e 'a\n&#0;'>\n]>\n<r x='&e;'/>"),
    "error: failed to parse XML (malformed entity reference at 3:1 at 3:1)",
  )
}

///|
test "oracle/xml_c2/84" {
  assert_eq(
    typst_xml("<!DOCTYPE r [\n<!ENTITY e '\n&lt;'>\n]>\n<r x='&e;'/>"),
    "error: failed to parse XML (unescaped '<' found at 3:1 at 3:1)",
  )
}

///|
test "oracle/xml_c2/85" {
  assert_eq(
    typst_xml("<!DOCTYPE r [\n<!ENTITY e '\n</r>'>\n]>\n<r>&e;</r>"),
    "error: failed to parse XML (unexpected close tag at 3:1 at 3:1)",
  )
}

///|
test "oracle/xml_c2/86" {
  assert_eq(
    typst_xml("<!DOCTYPE r [\n<!ENTITY e '\n<b>]]></b>'>\n]>\n<r>&e;</r>"),
    "error: failed to parse XML (']]>' at 3:7 is not allowed inside a character data at 3:7)",
  )
}

///|
test "oracle/xml_c2/87" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&e2;'><!ENTITY e2 'z'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"z\"]}]",
  )
}

///|
test "oracle/xml_c2/88" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'a&amp;b'>]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a&b\"]}]",
  )
}

///|
test "oracle/xml_c2/89" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'a&amp;b'>]><r x='&e;'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"a&b\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/90" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'a&b'>]><r>x</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"x\"]}]",
  )
}

///|
test "oracle/xml_c2/91" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e 'a&b'>]><r>&e;</r>"),
    "error: failed to parse XML (malformed entity reference at 1:27 at 1:27)",
  )
}

///|
test "oracle/xml_c2/92" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e \"it's\">]><r>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"it's\"]}]",
  )
}

///|
test "oracle/xml_c2/93" {
  assert_eq(
    typst_xml("<!DOCTYPE r [<!ENTITY e '&#x1F600;'>]><r x='&e;'>&e;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"😀\"},\"children\":[\"😀\"]}]",
  )
}

///|
test "oracle/xml_c2/94" {
  assert_eq(
    typst_xml("<r>\r\n</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/95" {
  assert_eq(
    typst_xml("<r>&#13;\n</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\r\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/96" {
  assert_eq(
    typst_xml("<r>\r&#13;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\r\\r\"]}]",
  )
}

///|
test "oracle/xml_c2/97" {
  assert_eq(
    typst_xml("<r>&#13;\r</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\r\\r\"]}]",
  )
}

///|
test "oracle/xml_c2/98" {
  assert_eq(
    typst_xml("<r>a\r</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/99" {
  assert_eq(
    typst_xml("<r>a&amp;\r</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a&\\r\"]}]",
  )
}

///|
test "oracle/xml_c2/100" {
  assert_eq(
    typst_xml("<r>a&amp;\r\r\n</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a&\\n\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/101" {
  assert_eq(
    typst_xml("<r>\r\n<!---->\r\n</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\n\",{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},\"\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/102" {
  assert_eq(
    typst_xml("<r x='\r\n'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\" \"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/103" {
  assert_eq(
    typst_xml("<r x='&amp;\r\n\r'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"&  \"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/104" {
  assert_eq(
    typst_xml("<r x='&#13;&#10;\r'/>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{\"x\":\"\\r\\n \"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/105" {
  assert_eq(
    typst_xml("<r>&amp;&#10;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"&\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/106" {
  assert_eq(
    typst_xml("<r>&#10;x</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\nx\"]}]",
  )
}

///|
test "oracle/xml_c2/107" {
  assert_eq(
    typst_xml("<r>&#x41;\r\n</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"A\\n\"]}]",
  )
}

///|
test "oracle/xml_c2/108" {
  assert_eq(
    typst_xml("<r>é&#233;é</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"ééé\"]}]",
  )
}

///|
test "oracle/xml_c2/109" {
  assert_eq(
    typst_xml("<r>&#x7F;&#x80;&#x9F;&#xFFFD;&#xFFFE;</r>"),
    "error: failed to parse XML (malformed entity reference at 1:30 at 1:30)",
  )
}

///|
test "oracle/xml_c2/110" {
  assert_eq(
    typst_xml("<r>&#xFFFF;</r>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c2/111" {
  assert_eq(
    typst_xml("<r>&#x10FFFF;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"􏿿\"]}]",
  )
}

///|
test "oracle/xml_c2/112" {
  assert_eq(
    typst_xml("<r>&#4294967295;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"�\"]}]",
  )
}

///|
test "oracle/xml_c2/113" {
  assert_eq(
    typst_xml("<r>&#4294967296;</r>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c2/114" {
  assert_eq(
    typst_xml("<r>&#x00000041;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"A\"]}]",
  )
}

///|
test "oracle/xml_c2/115" {
  assert_eq(
    typst_xml("<r>&#9;</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"\\t\"]}]",
  )
}

///|
test "oracle/xml_c2/116" {
  assert_eq(
    typst_xml("<r>&#1;</r>"),
    "error: failed to parse XML (malformed entity reference at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c2/117" {
  assert_eq(
    typst_xml("<a>\u{85} </a>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{},\"children\":[\"\u{85} \"]}]",
  )
}

///|
test "oracle/xml_c2/118" {
  assert_eq(
    typst_xml("<a b='ä' äb='2' _c='3' d.e-f='4'/>"),
    "[{\"namespace\":null,\"tag\":\"a\",\"attrs\":{\"b\":\"ä\",\"äb\":\"2\",\"_c\":\"3\",\"d.e-f\":\"4\"},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/119" {
  assert_eq(
    typst_xml("<a·/>"),
    "[{\"namespace\":null,\"tag\":\"a·\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/120" {
  assert_eq(
    typst_xml("<·a/>"),
    "error: failed to parse XML (invalid name token at 1:2 at 1:2)",
  )
}

///|
test "oracle/xml_c2/121" {
  assert_eq(
    typst_xml("<a ·='1'/>"),
    "error: failed to parse XML (invalid name token at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c2/122" {
  assert_eq(
    typst_xml("<😀/>"),
    "[{\"namespace\":null,\"tag\":\"😀\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/123" {
  assert_eq(
    typst_xml("<a𐀀/>"),
    "[{\"namespace\":null,\"tag\":\"a𐀀\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/124" {
  assert_eq(
    typst_xml("<r/><!-- x -- y -->"),
    "error: failed to parse XML (comment at 1:5 contains '--' at 1:5)",
  )
}

///|
test "oracle/xml_c2/125" {
  assert_eq(
    typst_xml("<r/>\n<?xml version='1.0'?>"),
    "error: failed to parse XML (unexpected XML declaration at 2:1 at 2:1)",
  )
}

///|
test "oracle/xml_c2/126" {
  assert_eq(
    typst_xml("<r/>\n\n  <!-- ok --> <?p q?>  \n"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"\",\"attrs\":{},\"children\":[]}]",
  )
}

///|
test "oracle/xml_c2/127" {
  assert_eq(
    typst_xml("<r><![CDATA[a]]]></r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a]\"]}]",
  )
}

///|
test "oracle/xml_c2/128" {
  assert_eq(
    typst_xml("<r><![CDATA[a]]]]></r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"a]]\"]}]",
  )
}

///|
test "oracle/xml_c2/129" {
  assert_eq(
    typst_xml("<r><![CDATA[\u{1}]]></r>"),
    "error: failed to parse XML (a non-XML character '\\u{1}' found at 1:13 at 1:13)",
  )
}

///|
test "oracle/xml_c2/130" {
  assert_eq(
    typst_xml("<r><!-- \u{1} --></r>"),
    "error: failed to parse XML (a non-XML character '\\u{1}' found at 1:9 at 1:9)",
  )
}

///|
test "oracle/xml_c2/131" {
  assert_eq(
    typst_xml("<r><?p \u{1}?></r>"),
    "error: failed to parse XML (a non-XML character '\\u{1}' found at 1:8 at 1:8)",
  )
}

///|
test "oracle/xml_c2/132" {
  assert_eq(
    typst_xml("<r>a<![CDATA[]]>b</r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[\"ab\"]}]",
  )
}

///|
test "oracle/xml_c2/133" {
  assert_eq(
    typst_xml("<r><![cdata[x]]></r>"),
    "error: failed to parse XML (unknown token at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c2/134" {
  assert_eq(
    typst_xml("<r><!DOCTYPE x></r>"),
    "error: failed to parse XML (unknown token at 1:4 at 1:4)",
  )
}

///|
test "oracle/xml_c2/135" {
  assert_eq(
    typst_xml("<r><a xmlns='u'/><b/></r>"),
    "[{\"namespace\":null,\"tag\":\"r\",\"attrs\":{},\"children\":[{\"namespace\":\"u\",\"tag\":\"a\",\"attrs\":{},\"children\":[]},{\"namespace\":null,\"tag\":\"b\",\"attrs\":{},\"children\":[]}]}]",
  )
}

///|
test "oracle/xml_c2/136" {
  assert_eq(
    typst_xml("<a><b></b></a>\n\n</c>"),
    "error: failed to parse XML (unknown token at 3:1 at 3:1)",
  )
}

///|
test "oracle/xml_c2/137" {
  assert_eq(
    typst_xml("<a></a></a>"),
    "error: failed to parse XML (unknown token at 1:8 at 1:8)",
  )
}

///|
test "oracle/xml_c2/138" {
  assert_eq(
    typst_xml("<a>\n<b>\n<c>\n</c>\n</b>\n<d>\n</e>"),
    "error: failed to parse XML (found closing tag 'e' instead of 'd' at 7:1)",
  )
}
