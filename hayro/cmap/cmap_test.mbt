// Ports of the unit tests of `hayro-cmap/src/lib.rs`.

// Note that those cmaps might not be completely valid according to the rules
// of cmap/Postscript, but since our parser is very lenient and doesn't run a
// real interpreter we can shorten them by a lot.

///|
let preamble : String =
  #|/CIDSystemInfo 3 dict dup begin
  #|  /Registry (Adobe) def
  #|  /Ordering (Japan1) def
  #|  /Supplement 0 def
  #|end def
  #|/CMapName /Test def
  #|/WMode 0 def
  #|2 begincodespacerange
  #|<00> <FF>
  #|<0000> <FFFF>
  #|endcodespacerange
  #|

///|
fn ascii_bytes(s : String) -> Bytes {
  let arr = []
  for c in s {
    arr.push(c.to_int().to_byte())
  }
  Bytes::from_array(arr)
}

///|
fn parse_str(s : String) -> @cmap.CMap? {
  @cmap.CMap::parse(ascii_bytes(s), _ => None)
}

///|
fn parse_with_preamble(body : String) -> @cmap.CMap {
  parse_str(preamble + body).unwrap()
}

///|
test "metadata_parsing" {
  let cmap = parse_str(
    (
      #|/CIDInit /ProcSet findresource begin
      #|12 dict begin
      #|begincmap
      #|/CIDSystemInfo 3 dict dup begin
      #|  /Registry (Adobe) def
      #|  /Ordering (Japan1) def
      #|  /Supplement 6 def
      #|end def
      #|/CMapName /Adobe-Japan1-H def
      #|/CMapType 1 def
      #|/WMode 0 def
      #|endcmap
    ),
  ).unwrap()
  let cc = cmap.metadata().character_collection.unwrap()
  assert_eq(cc.family, AdobeJapan1)
  assert_eq(cc.supplement, 6)
  assert_eq(cmap.metadata().name, Some(b"Adobe-Japan1-H"))
  assert_eq(cmap.metadata().writing_mode, Some(Horizontal))
}

///|
test "vertical_writing_mode" {
  let cmap = parse_str(
    (
      #|/CIDSystemInfo 3 dict dup begin
      #|  /Registry (Adobe) def
      #|  /Ordering (Japan1) def
      #|  /Supplement 6 def
      #|end def
      #|/CMapName /Adobe-Japan1-V def
      #|/WMode 1 def
    ),
  ).unwrap()
  assert_eq(cmap.metadata().writing_mode, Some(Vertical))
  assert_eq(cmap.metadata().name, Some(b"Adobe-Japan1-V"))
}

///|
test "cid_range_lookup" {
  let cmap = parse_with_preamble(
    (
      #|3 begincidrange
      #|<0000> <00FF> 0
      #|<0100> <01FF> 256
      #|<8140> <817E> 633
      #|endcidrange
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(0))
  assert_eq(cmap.lookup_cid_code(0x0042, 2), Some(0x42))
  assert_eq(cmap.lookup_cid_code(0x00FF, 2), Some(0xFF))
  assert_eq(cmap.lookup_cid_code(0x0100, 2), Some(256))
  assert_eq(cmap.lookup_cid_code(0x01FF, 2), Some(511))
  assert_eq(cmap.lookup_cid_code(0x8140, 2), Some(633))
  assert_eq(cmap.lookup_cid_code(0x817E, 2), Some(633 + 62))
}

///|
test "cid_char_lookup" {
  let cmap = parse_with_preamble(
    (
      #|3 begincidchar
      #|<03> 1
      #|<04> 2
      #|<20> 50
      #|endcidchar
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x03, 1), Some(1))
  assert_eq(cmap.lookup_cid_code(0x04, 1), Some(2))
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(50))
}

///|
test "lookup_miss" {
  let cmap = parse_with_preamble(
    (
      #|1 begincidrange
      #|<0100> <01FF> 0
      #|endcidrange
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x00FF, 2), None)
  assert_eq(cmap.lookup_cid_code(0x0200, 2), None)
  assert_eq(cmap.lookup_cid_code(0xFFFF, 2), None)
}

///|
test "multiple_sections" {
  let cmap = parse_with_preamble(
    (
      #|2 begincidrange
      #|<0000> <00FF> 0
      #|<0100> <01FF> 256
      #|endcidrange
      #|1 begincidchar
      #|<0200> 600
      #|endcidchar
      #|1 begincidrange
      #|<8140> <817E> 633
      #|endcidrange
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(0))
  assert_eq(cmap.lookup_cid_code(0x0100, 2), Some(256))
  assert_eq(cmap.lookup_cid_code(0x0200, 2), Some(600))
  assert_eq(cmap.lookup_cid_code(0x8140, 2), Some(633))
}

///|
test "single_byte_codes" {
  let cmap = parse_with_preamble(
    (
      #|2 begincidrange
      #|<00> <7F> 0
      #|<80> <FF> 200
      #|endcidrange
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x00, 1), Some(0))
  assert_eq(cmap.lookup_cid_code(0x41, 1), Some(0x41))
  assert_eq(cmap.lookup_cid_code(0x80, 1), Some(200))
  assert_eq(cmap.lookup_cid_code(0xFF, 1), Some(200 + 127))
}

///|
test "dict_style_cidsysteminfo" {
  let cmap = parse_str(
    (
      #|/CIDInit /ProcSet findresource begin
      #|10 dict begin
      #|begincmap
      #|/CIDSystemInfo
      #|<< /Registry (Adobe)
      #|/Ordering (UCS)
      #|/Supplement 0
      #|>> def
      #|/CMapName /Adobe-Identity-UCS def
      #|/CMapType 2 def
      #|1 begincodespacerange
      #|<0000> <FFFF>
      #|endcodespacerange
      #|2 beginbfchar
      #|<001F> <F049>
      #|<002A> <F055>
      #|endbfchar
      #|endcmap
      #|CMapName currentdict /CMap defineresource pop
      #|end
      #|end
    ),
  ).unwrap()
  let cc = cmap.metadata().character_collection.unwrap()
  assert_eq(cc.family, Custom(registry=b"Adobe", ordering=b"UCS"))
  assert_eq(cc.supplement, 0)
  assert_eq(cmap.metadata().name, Some(b"Adobe-Identity-UCS"))
  assert_eq(cmap.lookup_bf_string(0x001F), Some(Char('\u{F049}')))
  assert_eq(cmap.lookup_bf_string(0x002A), Some(Char('\u{F055}')))
}

///|
let usecmap_base : String =
  #|/CIDSystemInfo 3 dict dup begin
  #|  /Registry (Adobe) def
  #|  /Ordering (Japan1) def
  #|  /Supplement 0 def
  #|end def
  #|/CMapName /Base def
  #|/WMode 0 def
  #|1 begincodespacerange
  #|<0000> <FFFF>
  #|endcodespacerange
  #|1 begincidrange
  #|<0000> <00FF> 0
  #|endcidrange

///|
fn usecmap_child(range : String) -> String {
  (
    #|/Base usecmap
    #|/CIDSystemInfo 3 dict dup begin
    #|  /Registry (Adobe) def
    #|  /Ordering (Japan1) def
    #|  /Supplement 0 def
    #|end def
    #|/CMapName /Child def
    #|/WMode 0 def
    #|1 begincodespacerange
    #|<0000> <FFFF>
    #|endcodespacerange
    #|1 begincidrange
    #|
  ) +
  range +
  "\nendcidrange\n"
}

///|
fn resolve_base(name : @cmap.CMapName) -> Bytes? {
  if name.to_bytes() == b"Base" {
    Some(ascii_bytes(usecmap_base))
  } else {
    None
  }
}

///|
test "usecmap_chaining" {
  let cmap = @cmap.CMap::parse(
    ascii_bytes(usecmap_child("<0100> <01FF> 256")),
    resolve_base,
  ).unwrap()
  assert_eq(cmap.lookup_cid_code(0x0100, 2), Some(256))
  assert_eq(cmap.lookup_cid_code(0x01FF, 2), Some(511))
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(0))
  assert_eq(cmap.lookup_cid_code(0x00FF, 2), Some(0xFF))
  assert_eq(cmap.lookup_cid_code(0x0200, 2), None)
}

///|
test "usecmap_partial_override" {
  let cmap = @cmap.CMap::parse(
    ascii_bytes(usecmap_child("<0040> <007F> 500")),
    resolve_base,
  ).unwrap()
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(0))
  assert_eq(cmap.lookup_cid_code(0x003F, 2), Some(0x3F))
  assert_eq(cmap.lookup_cid_code(0x0040, 2), Some(500))
  assert_eq(cmap.lookup_cid_code(0x007F, 2), Some(563))
  assert_eq(cmap.lookup_cid_code(0x0080, 2), Some(0x80))
  assert_eq(cmap.lookup_cid_code(0x00FF, 2), Some(0xFF))
}

///|
test "usecmap_unresolved_and_cycle" {
  // An unresolvable `usecmap` fails the whole parse.
  assert_true(
    @cmap.CMap::parse(ascii_bytes(usecmap_child("<0040> <007F> 500")), _ => None)
    is None,
  )
  // Circular references stop at the nesting limit.
  let cyclic = ascii_bytes("/Base usecmap\n")
  assert_true(@cmap.CMap::parse(cyclic, _ => Some(cyclic)) is None)
}

///|
test "notdef_char_lookup" {
  let cmap = parse_with_preamble(
    (
      #|2 beginnotdefchar
      #|<03> 10
      #|<20> 20
      #|endnotdefchar
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x03, 1), Some(10))
  assert_eq(cmap.lookup_cid_code(0x20, 1), Some(20))
  assert_eq(cmap.lookup_cid_code(0x04, 1), None)
}

///|
test "notdef_range_lookup" {
  let cmap = parse_with_preamble(
    (
      #|1 beginnotdefrange
      #|<0000> <001F> 100
      #|endnotdefrange
    ),
  )
  assert_eq(cmap.lookup_cid_code(0x0000, 2), Some(100))
  assert_eq(cmap.lookup_cid_code(0x0001, 2), Some(100))
  assert_eq(cmap.lookup_cid_code(0x001F, 2), Some(100))
  assert_eq(cmap.lookup_cid_code(0x0020, 2), None)
}

///|
test "bfchar_lookup" {
  let cmap = parse_with_preamble(
    (
      #|2 beginbfchar
      #|<0041> <0048>
      #|<0042> <0065>
      #|endbfchar
    ),
  )
  assert_eq(cmap.lookup_bf_string(0x0041), Some(Char('H')))
  assert_eq(cmap.lookup_bf_string(0x0042), Some(Char('e')))
  assert_eq(cmap.lookup_bf_string(0x0043), None)
}

///|
test "bfchar_ligature" {
  let cmap = parse_with_preamble(
    (
      #|1 beginbfchar
      #|<005F> <00660066>
      #|endbfchar
    ),
  )
  assert_eq(cmap.lookup_bf_string(0x005F), Some(String("ff")))
}

///|
test "bfchar_surrogate_pair" {
  let cmap = parse_with_preamble(
    (
      #|1 beginbfchar
      #|<3A51> <D840DC3E>
      #|endbfchar
    ),
  )
  assert_eq(cmap.lookup_bf_string(0x3A51), Some(Char('\u{2003E}')))
}

///|
test "bfrange_incrementing" {
  let cmap = parse_with_preamble(
    (
      #|1 beginbfrange
      #|<0000> <0004> <0041>
      #|endbfrange
    ),
  )
  assert_eq(cmap.lookup_bf_string(0x0000), Some(Char('A')))
  assert_eq(cmap.lookup_bf_string(0x0001), Some(Char('B')))
  assert_eq(cmap.lookup_bf_string(0x0004), Some(Char('E')))
  assert_eq(cmap.lookup_bf_string(0x0005), None)
}

///|
test "bfrange_array" {
  let cmap = parse_with_preamble(
    (
      #|1 beginbfrange
      #|<005F> <0061> [<00660066> <00660069> <0066006C>]
      #|endbfrange
    ),
  )
  // ff, fi, fl ligatures
  assert_eq(cmap.lookup_bf_string(0x005F), Some(String("ff")))
  assert_eq(cmap.lookup_bf_string(0x0060), Some(String("fi")))
  assert_eq(cmap.lookup_bf_string(0x0061), Some(String("fl")))
}

///|
test "unicode_lookup_miss" {
  let cmap = parse_with_preamble(
    (
      #|1 beginbfchar
      #|<0041> <0048>
      #|endbfchar
    ),
  )
  assert_eq(cmap.lookup_bf_string(0x0000), None)
  assert_eq(cmap.lookup_bf_string(0x0042), None)
}

///|
test "identity_h" {
  let cmap = @cmap.CMap::identity_h()
  assert_eq(cmap.metadata().name, Some(b"Identity-H"))
  assert_eq(cmap.metadata().writing_mode, Some(Horizontal))
  assert_eq(cmap.lookup_cid_code(0x0041, 2), Some(0x0041))
  assert_eq(cmap.lookup_cid_code(0x1234, 2), Some(0x1234))
  assert_eq(cmap.lookup_cid_code(0xFFFF, 2), Some(0xFFFF))
  assert_eq(cmap.lookup_cid_code(0x0041, 1), None)
  assert_eq(cmap.lookup_cid_code(0x0041, 3), None)
}

///|
test "identity_v" {
  let cmap = @cmap.CMap::identity_v()
  assert_eq(cmap.metadata().name, Some(b"Identity-V"))
  assert_eq(cmap.metadata().writing_mode, Some(Vertical))
  assert_eq(cmap.lookup_cid_code(0x0041, 2), Some(0x0041))
  assert_eq(cmap.lookup_cid_code(0xFFFF, 2), Some(0xFFFF))
}

///|
test "minimal_cmap_no_name_no_wmode" {
  // Extracted from corpus PDF 0500013.
  let cmap = parse_str(
    (
      #|/CIDInit /ProcSet findresource begin
      #|12 dict begin
      #|begincmap
      #|/CMapType 2 def
      #|1 begincodespacerange
      #|<00><ff>
      #|endcodespacerange
      #|1 beginbfrange
      #|<01><01><0020>
      #|endbfrange
      #|endcmap
    ),
  ).unwrap()
  assert_eq(cmap.metadata().name, None)
  assert_eq(cmap.metadata().character_collection, None)
  assert_eq(cmap.metadata().writing_mode, None)
  assert_eq(cmap.lookup_bf_string(0x01), Some(Char(' ')))
}

///|
test "registry_as_name" {
  // Extracted from corpus PDF 0875241, uses names instead of strings for
  // strings for metadata.
  let cmap = parse_str(
    (
      #|/CIDSystemInfo
      #|<< /Registry /ABCDEF+SimSun
      #|/Ordering (pdfbeaninc)
      #|/Supplement 0
      #|>> def
      #|/CMapName /ABCDEF+SimSun def
      #|/CMapType 2 def
      #|1 begincodespacerange
      #|<0000> <FFFF>
      #|endcodespacerange
      #|1 beginbfrange
      #|<0000> <0000> <6881>
      #|endbfrange
    ),
  ).unwrap()
  let cc = cmap.metadata().character_collection.unwrap()
  assert_eq(
    cc.family,
    Custom(registry=b"ABCDEF+SimSun", ordering=b"pdfbeaninc"),
  )
  assert_eq(cc.supplement, 0)
  assert_eq(cmap.lookup_bf_string(0x0000), Some(Char('\u{6881}')))
}

///|
test "single_byte_bfrange_destination" {
  // See for example corpus test case 0625248.
  let cmap = parse_with_preamble(
    (
      #|1 beginbfrange
      #|<00> <7f> <00>
      #|endbfrange
    ),
  )
  assert_eq(cmap.lookup_bf_string(0x00), Some(Char('\u{0000}')))
  assert_eq(cmap.lookup_bf_string(0x41), Some(Char('A')))
  assert_eq(cmap.lookup_bf_string(0x7f), Some(Char('\u{007F}')))
}

///|
test "cmap names" {
  assert_eq(@cmap.CMapName::from_bytes(b"Identity-H"), IdentityH)
  assert_eq(@cmap.CMapName::from_bytes(b"90ms-RKSJ-V"), N90msRksjV)
  assert_eq(@cmap.CMapName::from_bytes(b"V"), V)
  assert_eq(@cmap.CMapName::from_bytes(b"Foo"), Custom(b"Foo"[:]))
  assert_eq(@cmap.CMapName::UniKsUtf16H.to_bytes(), b"UniKS-UTF16-H"[:])
  assert_eq(@cmap.CidFamily::from_registry_ordering(b"Adobe", b"GB1"), AdobeGB1)
  assert_eq(
    @cmap.CidFamily::AdobeKorea1.unicode_cmap(),
    Some(@cmap.CMapName::UniKsUtf16H),
  )
  assert_eq(
    @cmap.CidFamily::AdobeCNS1.ucs2_cmap(),
    Some(@cmap.CMapName::AdobeCns1Ucs2),
  )
  assert_eq(@cmap.CidFamily::AdobeIdentity.ucs2_cmap(), None)
  assert_true(@cmap.load_embedded(H) is None)
}
