// Tests ported from `hypher 0.1.8` (`lib.rs`).

///|
fn check(lang : @hypher.Lang, hyphenated : String) -> Unit raise {
  let word = hyphenated.replace_all(old="-", new="")
  assert_eq(@hypher.hyphenate(word, lang).join("-"), hyphenated)
}

///|
test "empty" {
  assert_eq(@hypher.hyphenate("", English), [])
}

///|
test "exact" {
  assert_eq(@hypher.hyphenate("hello", English).length(), 1)
  assert_eq(@hypher.hyphenate("extensive", English).length(), 3)
}

///|
test "alloc" {
  let long_word = "thisisaverylongstringwithanunrealisticwordlengthforenglishbutitmightbepossibleinanotherlanguage"
  assert_eq(
    @hypher.hyphenate(long_word.view(end_offset=44).to_owned(), English).length(),
    13,
  )
  assert_eq(
    @hypher.hyphenate(long_word.view(end_offset=45).to_owned(), English).length(),
    12,
  )
  assert_eq(
    @hypher.hyphenate(long_word.view(end_offset=46).to_owned(), English).length(),
    12,
  )
  assert_eq(@hypher.hyphenate(long_word, English).length(), 25)
}

///|
test "english" {
  check(English, "")
  check(English, "hi")
  check(English, "wel-come")
  check(English, "walk-ing")
  check(English, "cap-tiVe")
  check(English, "pur-sue")
  check(English, "wHaT-eVeR")
  check(English, "bro-ken")
  check(English, "ex-ten-sive")
  check(English, "Prob-a-bil-ity")
  check(English, "rec-og-nize")
}

///|
test "german" {
  check(German, "")
  check(German, "Baum")
  check(German, "ge-hen")
  check(German, "Ap-fel")
  check(German, "To-ma-te")
  check(German, "Ein-ga-be-auf-for-de-rung")
  check(German, "Fort-pflan-zungs-lem-ma")
  check(German, "stra-te-gie-er-hal-ten-den")
  check(German, "hübsch")
  check(German, "häss-lich")
  check(German, "über-zeu-gen-der")
}

///|
test "finnish" {
  check(Finnish, "ää-ni-oi-keus")
  check(Finnish, "yli-o-pis-to")
  check(Finnish, "ra-vin-to-la")
  check(Finnish, "kah-vi")
  check(Finnish, "sa-na-kir-ja")
  check(Finnish, "lai-va")
  check(Finnish, "tie-to-ko-ne")
  check(Finnish, "kaa-ri")
}

///|
test "others" {
  check(Greek, "δια-με-ρί-σμα-τα")
  check(Greek, "λα-τρευ-τός")
  check(Greek, "κά-τοι-κος")
  check(Georgian, "თა-რო")
  check(Georgian, "შეყ-ვა-ნა")
  check(Georgian, "კარ-ტო-ფი-ლი")
  check(Polish, "wy-kształ-ciu-chy")
  check(Czech, "po-ví-dá-me")
  check(Czech, "nej-ja-s-něj-ší")
  check(Czech, "br-něn-ský")
  check(Malayalam, "വി-ദ്യാർ-ത്ഥി")
  check(Malayalam, "പഠി-ക്കുക")
  check(Hindi, "वि-द्या-र्थी")
  check(Hindi, "पढ़-ना")
  assert_eq(@hypher.Lang::from_iso("nb"), Some(Norwegian))
  assert_eq(@hypher.Lang::from_iso("xx"), None)
}
