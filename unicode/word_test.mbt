///|
test "split_word_bounds" {
  let s = "The quick (\"brown\")  fox can't jump 32.3 feet, right?"
  let w = @unicode.split_word_bounds(s).map(v => v.to_owned())
  assert_eq(w, [
    "The", " ", "quick", " ", "(", "\"", "brown", "\"", ")", "  ", "fox", " ", "can't",
    " ", "jump", " ", "32.3", " ", "feet", ",", " ", "right", "?",
  ])
  let u = @unicode.unicode_words(s).map(v => v.to_owned())
  assert_eq(u, [
    "The", "quick", "brown", "fox", "can't", "jump", "32.3", "feet", "right",
  ])
}
