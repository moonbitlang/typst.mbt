///|
fn ggg_test_bytes(words : Array[Int]) -> BytesView {
  let bytes : Array[Byte] = []
  for w in words {
    bytes.push((w >> 8).to_byte())
    bytes.push(w.to_byte())
  }
  Bytes::from_array(bytes)[:]
}

///|
/// A synthetic GSUB 1.1 with an extension lookup, a mark filtering set and
/// feature variations.
fn ggg_test_gsub() -> BytesView {
  ggg_test_bytes([
    // header @0
    1, 1, 14, 16, 30, 0, 68,
    // ScriptList @14
     0,
    // FeatureList @16: 'liga' -> 8
     1, 0x6c69, 0x6761, 8,
    // Feature @24
     0, 1, 0,
    // LookupList @30
     1, 4,
    // Lookup @34: extension, UseMarkFilteringSet, 1 subtable @10, set 5
     7, 0x0010, 1, 10, 5,
    // Extension @44: format 1, type 1, offset32 8
     1, 1, 0, 8,
    // SingleSubst @52: format 1, coverage @6, delta 3
     1, 6, 3,
    // Coverage @58: format 2, 1 range 10..20 -> 0
     2, 1, 10, 20, 0,
    // FeatureVariations @68
     1, 0, 0, 1, 0, 16, 0, 30,
    // ConditionSet @84
     1, 0, 6,
    // Condition @90: axis 0, 0.5..1.0
     1, 0, 0x2000, 0x4000,
    // FeatureTableSubstitution @98
     1, 0, 1, 0, 0, 12,
    // Feature @110
     0, 2, 0, 7,
  ])
}

///|
test "layout table with extension lookup and feature variations" {
  let t = LayoutTable::parse(ggg_test_gsub()).unwrap()
  inspect(t.scripts.len(), content="0")
  inspect(t.features.len(), content="1")
  @debug.debug_inspect(
    t.features.index(Tag::from_str("liga")),
    content="Some(0)",
  )
  inspect(t.features.find(Tag::from_str("kern")) is None, content="true")
  let feature = t.features.find(Tag::from_str("liga")).unwrap()
  @debug.debug_inspect(feature.lookup_indices.iter().collect(), content="[0]")
  let lookup = t.lookups.get(0).unwrap()
  inspect(lookup.flags.use_mark_filtering_set(), content="true")
  @debug.debug_inspect(lookup.mark_filtering_set, content="Some(5)")
  inspect(lookup.subtables.len(), content="1")
  let sub : SubstitutionSubtable = lookup.subtables.get(0).unwrap()
  guard sub is Single(Format1(coverage~, delta~)) else { fail("not single") }
  inspect(delta, content="3")
  @debug.debug_inspect(coverage.get(GlyphId(9)), content="None")
  @debug.debug_inspect(coverage.get(GlyphId(15)), content="Some(5)")
  @debug.debug_inspect(coverage.get(GlyphId(21)), content="None")
  let v = t.variations.unwrap()
  @debug.debug_inspect(v.find_index([]), content="None")
  @debug.debug_inspect(
    v.find_index([NormalizedCoordinate::from_i16(10000)]),
    content="Some(0)",
  )
  @debug.debug_inspect(
    v.find_index([NormalizedCoordinate::from_i16(-10000)]),
    content="None",
  )
  let f = v.find_substitute(0, 0).unwrap()
  inspect(f.tag, content="DFLT")
  @debug.debug_inspect(f.lookup_indices.iter().collect(), content="[0, 7]")
  inspect(v.find_substitute(1, 0) is None, content="true")
}

///|
test "class definition and lookup flags" {
  let c = ClassDefinition::parse(ggg_test_bytes([1, 5, 3, 1, 2, 3])).unwrap()
  inspect(c.get(GlyphId(4)), content="0")
  inspect(c.get(GlyphId(5)), content="1")
  inspect(c.get(GlyphId(7)), content="3")
  inspect(c.get(GlyphId(8)), content="0")
  inspect(ClassDefinition::Empty.get(GlyphId(1)), content="0")
  let flags = LookupFlags(0x0309)
  inspect(flags.right_to_left(), content="true")
  inspect(flags.ignore_marks(), content="true")
  inspect(flags.ignore_flags(), content="true")
  inspect(flags.ignore_ligatures(), content="false")
  inspect(flags.mark_attachment_type(), content="b'\\x03'")
}
