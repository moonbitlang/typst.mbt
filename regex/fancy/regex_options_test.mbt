// Port of `fancy-regex` 0.16.2 `tests/regex_options.rs`.

///|
fn is_match_or_false(regex : @fancy.Regex, text : String) -> Bool {
  regex.is_match(text) catch {
    _ => false
  }
}

///|
test "check_casing_option" {
  let regex = @fancy.RegexBuilder::new("TEST foo")
    .case_insensitive(false)
    .build()
  assert_true(is_match_or_false(regex, "TEST foo"))
  assert_true(!is_match_or_false(regex, "test foo"))
}

///|
test "check_override_casing_option" {
  let regex = @fancy.RegexBuilder::new("FOO(?i:bar)quux")
    .case_insensitive(false)
    .build()
  assert_true(!is_match_or_false(regex, "FoObarQuUx"))
  assert_true(!is_match_or_false(regex, "fooBARquux"))
  assert_true(is_match_or_false(regex, "FOObarquux"))
}

///|
test "check_casing_insensitive_option" {
  let regex = @fancy.RegexBuilder::new("TEST FOO")
    .case_insensitive(true)
    .build()
  assert_true(is_match_or_false(regex, "test foo"))
}

///|
test "check_multi_line_option" {
  let test_text = "test\nhugo\ntest"
  let regex = @fancy.RegexBuilder::new("^test$").multi_line(true).build()
  assert_true(is_match_or_false(regex, test_text))
}

///|
test "check_ignore_whitespace_option" {
  let regex = @fancy.RegexBuilder::new("test    foo")
    .ignore_whitespace(true)
    .build()
  assert_true(is_match_or_false(regex, "testfoo"))
}

///|
test "check_dot_matches_new_line_option" {
  let regex = @fancy.RegexBuilder::new("<div>(.*?)<\\/div>")
    .dot_matches_new_line(true)
    .build()
  let test_text = "<div>\n    hello</div>"
  assert_true(is_match_or_false(regex, test_text))
}

///|
test "check_casing_insensitive_option_hard" {
  let regex = @fancy.RegexBuilder::new("[a-z](?<=[^f])")
    .case_insensitive(true)
    .build()
  assert_true(is_match_or_false(regex, "J"))
  assert_true(!is_match_or_false(regex, "F"))
  assert_true(is_match_or_false(regex, "j"))
}

///|
test "check_ignore_whitespace_option_fancy" {
  let regex = @fancy.RegexBuilder::new("(?=test    foo)")
    .ignore_whitespace(true)
    .build()
  assert_true(is_match_or_false(regex, "testfoo"))
}

///|
test "check_ignore_whitespace_with_lookahead_matches" {
  let regex = @fancy.RegexBuilder::new("(?=test    foo)")
    .ignore_whitespace(true)
    .build()
  assert_true(!is_match_or_false(regex, "test    foo"))
}

///|
test "check_verbose_mode_option" {
  let pattern = "\ntest  foo #hugo\n"
  let regex = @fancy.RegexBuilder::new(pattern).verbose_mode(true).build()
  assert_true(!is_match_or_false(regex, "test    foo"))
}

///|
test "issue_163_fancy_email_test" {
  let pattern = "^(?!\\.)(?!.*\\.\\.)([a-z0-9_'+\\-\\.]*)[a-z0-9_'+\\-]@([a-z0-9][a-z0-9\\-]*\\.)+[a-z]{2,}$"
  let regex = @fancy.RegexBuilder::new(pattern).case_insensitive(true).build()
  assert_true(regex.is_match("VALID@domain.com"))
}

///|
test "check_oniguruma_mode_changes_wordbounds" {
  fn find_all_matches(regex : @fancy.Regex, text : String) -> Array[String] {
    regex.find_iter(text).iter().map(m => m.unwrap().as_str()).collect()
  }

  let pattern = "\\<prefix_\\w*\\>"
  let test_text = "not_prefix_oops prefix_with_suffix <prefix_>"

  // By default the pattern is interpretted as a left word-bound followed by the literal "prefix_"
  // followed by any number of word characters ending on a right word-bound
  let default_mode = @fancy.Regex::new(pattern)
  let default_matches = find_all_matches(default_mode, test_text)
  assert_eq(default_matches, ["prefix_with_suffix", "prefix_"])

  // When Oniguruma-mode is used the pattern is instead a literal "<prefix_" followed by any
  // number of word characters followed by a literal ">"
  let oniguruma_mode = @fancy.RegexBuilder::new(pattern)
    .oniguruma_mode(true)
    .build()
  let oniguruma_matches = find_all_matches(oniguruma_mode, test_text)
  assert_eq(oniguruma_matches, ["<prefix_>"])
}

///|
test "oniguruma_mode_doc_example" {
  let haystack = "turbo::<Fish>"
  let regex = "\\<\\w*\\>"
  let word_bounds_regex = @fancy.Regex::new(regex)
  let word_bounds = word_bounds_regex.find(haystack).unwrap()
  assert_eq(word_bounds.as_str(), "turbo")
  let literals_regex = @fancy.RegexBuilder::new(regex)
    .oniguruma_mode(true)
    .build()
  let literals = literals_regex.find(haystack).unwrap()
  assert_eq(literals.as_str(), "<Fish>")
}
