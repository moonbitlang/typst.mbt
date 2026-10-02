// Port of `fancy-regex` 0.16.2 `tests/matching.rs`.

///|
fn match_text(re : String, text : String) -> Bool raise {
  let regex = @fancy.Regex::new(re)
  regex.is_match(text)
}

///|
fn assert_match(re : String, text : String) -> Unit raise {
  if !match_text(re, text) {
    fail("Expected regex '\{re}' to match text '\{text}'")
  }
}

///|
fn assert_no_match(re : String, text : String) -> Unit raise {
  if match_text(re, text) {
    fail("Expected regex '\{re}' to not match text '\{text}'")
  }
}

///|
test "control_character_escapes" {
  assert_match("\\a", "\u{07}")
  assert_match("\\e", "\u{1B}")
  assert_match("\\f", "\u{0C}")
  assert_match("\\n", "\u{0A}")
  assert_match("\\r", "\u{0D}")
  assert_match("\\t", "\u{09}")
  assert_match("\\v", "\u{0B}")
}

///|
test "character_class_escapes" {
  assert_match("[\\[]", "[")
  assert_match("[\\^]", "^")

  // The regex crate would reject the following because it's not necessary to escape them.
  // Other engines allow to escape any non-alphanumeric character.
  assert_match("[\\<]", "<")
  assert_match("[\\>]", ">")
  assert_match("[\\.]", ".")
  assert_match("[\\ ]", " ")

  // Character class escape
  assert_match("[\\d]", "1")

  // Control characters
  assert_match("[\\e]", "\u{1B}")
  assert_match("[\\n]", "\u{0A}")

  // `]` can be unescaped if it's right after `[`
  assert_match("[]]", "]")
  // `]` can be unescaped even after `[^`
  assert_match("[^]]", "a")
}

///|
test "character_class_nested" {
  assert_match("[[a][bc]]", "c")
  assert_match("[a[^b]]", "c")
}

///|
test "character_class_intersection" {
  assert_match("[\\w&&a-c]", "c")
  assert_no_match("[\\w&&a-c]", "d")
  assert_match("[[0-9]&&[^4]]", "1")
  assert_no_match("[[0-9]&&[^4]]", "4")
}

///|
test "alternation_with_empty_arm" {
  assert_match("^(a|)$", "a")
  assert_match("^(a|)$", "")
  assert_match("^(|a)$", "a")
  assert_match("^(|a)$", "")
  assert_match("a|", "a")
  assert_match("a|", "")
  assert_match("|a", "a")
  assert_match("|a", "")
  assert_no_match("^(a|)$", "b")
}

///|
test "case_insensitive_character_class" {
  assert_match("^(?i)[a-z]+$", "aB")
}

///|
test "case_insensitive_escape" {
  // `\x61` is lowercase `a`
  assert_match("(?i)\\x61", "A")

  // `\p{Ll}` is the "Letter, lowercase" category
  assert_match("(?i)\\p{Ll}", "A")
}

///|
test "atomic_group" {
  assert_match("^a(?>bc|b)c$", "abcc")
  assert_no_match("^a(?>bc|b)c$", "abc")

  // Look-ahead forces use of VM
  assert_match("^a(bc(?=d)|b)cd$", "abcd")
  assert_no_match("^a(?>bc(?=d)|b)cd$", "abcd")
}

///|
test "backtrack_limit" {
  let re = @fancy.RegexBuilder::new("(?i)(a|b|ab)*(?>c)")
    .backtrack_limit(100_000)
    .build()
  let s = "abababababababababababababababababababababababababababab"
  try re.is_match(s) catch {
    RuntimeError(BacktrackLimitExceeded) => ()
    _ => fail("Expected RuntimeError::BacktrackLimitExceeded")
  } noraise {
    _ => fail("Expected RuntimeError::BacktrackLimitExceeded")
  }
}

///|
test "end_of_hard_expression_cannot_be_delegated" {
  assert_match("(?!x)(?:a|ab)c", "abc")
  // If `(?:a|ab)` is delegated, there's no backtracking and `a` matches and `ab` is never tried.
  assert_match("((?!x)(?:a|ab))c", "abc")
}

///|
test "issue103" {
  assert_no_match("(([ab]+)\\1b)", "babab")
}

///|
test "backreference_validity_checker" {
  assert_match("(a)(?(1))", "a")
  assert_match("(?<group1>a)(?('group1'))b", "ab")
  assert_match("(a)(b)?(?(2))", "ab")
  assert_no_match("(a)(b)?(?(2))", "a")
  assert_match("(a)(b?)(?(2))", "a")
}

///|
test "conditional_with_backref_validity" {
  assert_match("(a)?b(?(1)c|d)", "bd")
  assert_match("(a)?b(?(1)c|d)", "abc")
  assert_match("(?<group1>a)?b(?(<group1>)c|d)", "abc")
  assert_no_match("(a)?b(?(1)c|d)", "bc")
  assert_no_match("^(a)?b(?(1)c|d)$", "abd")
}

///|
test "conditional_with_consuming_condition" {
  assert_match("^(?(ab)c|d)$", "abc")
  assert_no_match("^(?(ab)c|d)$", "abd")
  assert_no_match("^(?(ab)c|d)$", "ad")
  assert_match("^(?(\\d)abc|\\d!)$", "5abc")
  assert_no_match("^(?(\\d)abc|\\d!)$", "5!")
}

///|
test "conditional_with_lookaround_condition" {
  assert_match("^(?((?=\\d))\\w+|!)$", "!")
  assert_match("^(?((?=\\d))\\w+|!)$", "5abc")
  assert_match("^(?((?=\\d))abc)$", "")
  assert_match("^(?((?=\\w))abc)$", "abc")
  assert_no_match("^(?((?=\\d))\\wabc|\\d!)$", "5!")
}

///|
test "backrefs" {
  assert_match("(abc)\\1", "abcabc")
  assert_match("(abc|def)\\1", "abcabc")
  assert_no_match("(abc|def)\\1", "abcdef")
  assert_match("(abc|def)\\1", "defdef")
  assert_no_match("(abc|def)\\1", "abcABC")
  assert_match("(abc|def)(?i:\\1)", "abcABC")
  assert_match("(abc|def)(?i:\\1)", "abcAbc")
  assert_no_match("(abc|def)(?i:\\1)", "abcAB")
  assert_no_match("(abc|def)(?i:\\1)", "abcdef")
  assert_match("(δ)(?i:\\1)", "δΔ")
  assert_no_match("(δ)\\1", "δΔ")
  assert_no_match("(δδ)\\1", "δΔfoo")
  assert_no_match("(δδ)\\1", "δΔ")
  assert_match("(.)(?i:\\1)", "\\\\")
  assert_match("(.)(?i:\\1)", "((")
  assert_match("(.)(?i:\\1)", "įĮ")
  assert_no_match("(.)(?i:\\1)", "įi")
  assert_no_match("(.)(?i:\\1)", "įĖ")
  assert_match("(?i)(?<word>\\w+)\\s+\\k<word>", "Greek : δ Δ")
}

///|
test "easy_trailing_positive_lookaheads" {
  assert_match("(?=c)", "abcabc")
  assert_match("abc(?=abc)", "abcabc")
  assert_no_match("abc(?=abc)", "abcdef")
  assert_match("abc(?=a|b)", "abcabc")
  assert_no_match("abc(?=a|f)", "f")
}

///|
test "hard_trailing_positive_lookaheads" {
  assert_match("(abc|def)(?=\\1)", "defdef")
  assert_match("(abc|def)(?=a(?!b))", "abca")
  assert_match("(abc|def)(?=a(?!b))", "abcaa")
  assert_no_match("(abc|def)(?=a(?!b))", "abcabc")
}
