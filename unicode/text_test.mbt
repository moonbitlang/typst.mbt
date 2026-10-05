///|
test "case conversion" {
  inspect(@unicode.to_uppercase("Ελλάδα"), content="ΕΛΛΆΔΑ")
  inspect(@unicode.to_uppercase("straße"), content="STRASSE")
  inspect(@unicode.to_lowercase("ΟΔΥΣΣΕΥΣ"), content="οδυσσευς")
  inspect(@unicode.to_lowercase("Are MEMES great?"), content="are memes great?")
}

///|
test "normalization" {
  inspect(@unicode.nfc("e\u{0301}"), content="é")
  inspect(@unicode.nfd("é") == "e\u{0301}", content="true")
  inspect(@unicode.nfkc("ſ\u{0301}"), content="ś")
  inspect(@unicode.nfkd("ſ\u{0301}") == "s\u{0301}", content="true")
  inspect(@unicode.nfc("\u{1100}\u{1161}\u{11A8}"), content="각")
  inspect(@unicode.nfd("각").length(), content="3")
  // Reordering: a + dot below (220) + dot above (230) in reverse order.
  inspect(
    @unicode.nfd("a\u{0307}\u{0323}") == "a\u{0323}\u{0307}",
    content="true",
  )
  inspect(@unicode.nfc("a\u{0307}\u{0323}") == "ạ\u{0307}", content="true")
}

///|
test "properties" {
  inspect(
    @unicode.canonical_general_category("letter"),
    content=(
      #|Some(Letter)
    ),
  )
  inspect(
    @unicode.canonical_general_category("l"),
    content=(
      #|Some(Letter)
    ),
  )
  inspect(
    @unicode.canonical_script("greek"),
    content=(
      #|Some(Greek)
    ),
  )
  inspect(
    @unicode.canonical_property_name("whitespace"),
    content=(
      #|Some(White_Space)
    ),
  )
  let letter = @unicode.general_category_ranges("Letter").unwrap()
  inspect(letter[0], content="(65, 90)")
  let lu = @unicode.general_category_ranges("Uppercase_Letter").unwrap()
  inspect(lu[0], content="(65, 90)")
  let cn = @unicode.general_category_ranges("Unassigned").unwrap()
  inspect(cn[0], content="(888, 889)")
  inspect(@unicode.script_ranges("Greek").unwrap()[0], content="(880, 883)")
  inspect(
    @unicode.bool_property_ranges("White_Space").unwrap()[0],
    content="(9, 13)",
  )
  inspect(@unicode.simple_fold_next('k'.to_int()), content="Some(8490)")
  inspect(@unicode.simple_fold_next(8490), content="Some(75)")
  inspect(
    @unicode.chars_with_case_variants('a'.to_int(), 'c'.to_int()),
    content="[97, 98, 99]",
  )
  inspect(@unicode.is_word_character('é'.to_int()), content="true")
}

///|
test "discard_space_between" {
  // Discard
  assert_true(@unicode.discard_space_between("漢", "漢"))
  assert_true(@unicode.discard_space_between("1", "漢"))
  assert_true(@unicode.discard_space_between("漢", "A"))
  assert_true(@unicode.discard_space_between("漢。", "A"))
  assert_true(@unicode.discard_space_between("A", "（漢"))
  assert_true(@unicode.discard_space_between("A。", "B"))
  assert_true(@unicode.discard_space_between("A", "（B"))
  // Keep
  assert_false(@unicode.discard_space_between("A", "B"))
  assert_false(@unicode.discard_space_between("1", "2"))
  assert_false(@unicode.discard_space_between("end.", "Begin"))
  assert_false(@unicode.discard_space_between("가", "각"))
  // Empty strings
  assert_true(@unicode.discard_space_between("漢", ""))
  assert_true(@unicode.discard_space_between("", "漢"))
  assert_false(@unicode.discard_space_between("", ""))
  assert_false(@unicode.discard_space_between("A", ""))
  assert_false(@unicode.discard_space_between("", "A"))
  // Spaces themselves don't get special treatment
  assert_true(@unicode.discard_space_between("漢", " "))
  assert_true(@unicode.discard_space_between(" ", "漢"))
  assert_false(@unicode.discard_space_between(" ", " "))
  assert_false(@unicode.discard_space_between("1", "㊗"))
  assert_true(@unicode.discard_space_between("1", "㊕"))
  assert_true(@unicode.discard_space_between("A", "\u{3099}"))
}
