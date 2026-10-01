///|
test "case conversion" {
  inspect(to_uppercase("Ελλάδα"), content="ΕΛΛΆΔΑ")
  inspect(to_uppercase("straße"), content="STRASSE")
  inspect(to_lowercase("ΟΔΥΣΣΕΥΣ"), content="οδυσσευς")
  inspect(to_lowercase("Are MEMES great?"), content="are memes great?")
}

///|
test "normalization" {
  inspect(nfc("e\u{0301}"), content="é")
  inspect(nfd("é") == "e\u{0301}", content="true")
  inspect(nfkc("ſ\u{0301}"), content="ś")
  inspect(nfkd("ſ\u{0301}") == "s\u{0301}", content="true")
  inspect(nfc("\u{1100}\u{1161}\u{11A8}"), content="각")
  inspect(nfd("각").length(), content="3")
  // Reordering: a + dot below (220) + dot above (230) in reverse order.
  inspect(nfd("a\u{0307}\u{0323}") == "a\u{0323}\u{0307}", content="true")
  inspect(nfc("a\u{0307}\u{0323}") == "ạ\u{0307}", content="true")
}

///|
test "properties" {
  inspect(
    canonical_general_category("letter"),
    content=(
      #|Some(Letter)
    ),
  )
  inspect(
    canonical_general_category("l"),
    content=(
      #|Some(Letter)
    ),
  )
  inspect(
    canonical_script("greek"),
    content=(
      #|Some(Greek)
    ),
  )
  inspect(
    canonical_property_name("whitespace"),
    content=(
      #|Some(White_Space)
    ),
  )
  let letter = general_category_ranges("Letter").unwrap()
  inspect(letter[0], content="(65, 90)")
  let lu = general_category_ranges("Uppercase_Letter").unwrap()
  inspect(lu[0], content="(65, 90)")
  let cn = general_category_ranges("Unassigned").unwrap()
  inspect(cn[0], content="(888, 889)")
  inspect(script_ranges("Greek").unwrap()[0], content="(880, 883)")
  inspect(bool_property_ranges("White_Space").unwrap()[0], content="(9, 13)")
  inspect(simple_fold_next('k'.to_int()), content="Some(8490)")
  inspect(simple_fold_next(8490), content="Some(75)")
  inspect(
    chars_with_case_variants('a'.to_int(), 'c'.to_int()),
    content="[97, 98, 99]",
  )
  inspect(is_word_character('é'.to_int()), content="true")
}
