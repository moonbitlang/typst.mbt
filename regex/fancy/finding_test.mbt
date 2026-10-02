// Port of `fancy-regex` 0.16.2 `tests/finding.rs`.

///|
fn find_match(re : String, text : String) -> @fancy.Match? raise {
  let regex = @fancy.Regex::new(re)
  regex.find(text)
}

///|
fn find(re : String, text : String) -> (Int, Int)? raise {
  find_match(re, text).map(m => (m.start(), m.end()))
}

///|
fn is_err(re : String) -> Bool {
  try @fancy.Regex::new(re) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
/// The (start, end) of all matches of `find_iter`.
fn find_all(re : String, text : String) -> Array[(Int, Int)] raise {
  let out = []
  for m in @fancy.Regex::new(re).find_iter(text).iter() {
    let m = m.unwrap_or_error()
    out.push((m.start(), m.end()))
  }
  out
}

///|
test "match_api" {
  let m = find_match("(\\w+)", "... test").unwrap()
  assert_eq(m.range(), (4, 8))
  assert_eq(m.as_str(), "test")
}

///|
test "find_wrap" {
  assert_eq(find("(\\w+)", "... test"), Some((4, 8)))
  assert_eq(find("(?m)^yes$", "foo\nyes\n"), Some((4, 7)))
}

///|
test "find_fancy_case_insensitive" {
  assert_eq(find("(x|xy)\\1", "XX"), None)
  assert_eq(find("(x|xy)\\1", "xx"), Some((0, 2)))
  assert_eq(find("((?i:x|xy))\\1", "XX"), Some((0, 2)))
}

///|
test "lookahead_grouping_single_expression" {
  // These would fail if the delegate expression was `^x|a` (if we didn't
  // group as `^(?:x|a)`).
  assert_eq(find("(?=x|a)", "a"), Some((0, 0)))
  assert_eq(find("(?=x|a)", "bbba"), Some((3, 3)))
}

///|
test "lookahead_grouping_multiple_expressions" {
  // These would fail if the delegate expression was `^ab|Bc` (if we didn't
  // preserve grouping of `(?:b|B)`).
  assert_eq(find("(?=(?!x)a(?:b|B)c)", "aBc"), Some((0, 0)))
  assert_eq(find("(?=(?!x)a(?:b|B)c)", "Bc"), None)
}

///|
test "lookbehind_grouping_single_expression" {
  assert_eq(find("(?<=x|a)", "a"), Some((1, 1)))
  assert_eq(find("(?<=x|a)", "ba"), Some((2, 2)))
  assert_eq(find("(?<=^a)", "a"), Some((1, 1)))
  assert_eq(find("(?<=^a)", "ba"), None)
}

///|
test "lookbehind_variable_sized_alt" {
  assert_eq(find("(?<=a|bc)", "xxa"), Some((3, 3)))
  assert_eq(find("(?<=a|bc)", "xxbc"), Some((4, 4)))
  assert_eq(find("(?<=a|bc)", "xx"), None)
  assert_eq(find("(?<=a|bc)", "xxb"), None)
  assert_eq(find("(?<=a|bc)", "xxc"), None)
  assert_true(is_err("(?<=a(?:b|cd))"))
  assert_true(is_err("(?<=a+b+))"))
}

///|
test "negative_lookbehind_variable_sized_alt" {
  assert_eq(find("(?<!a|bc)x", "axx"), Some((2, 3)))
  assert_eq(find("(?<!a|bc)x", "bcxx"), Some((3, 4)))
  assert_eq(find("(?<!a|bc)x", "x"), Some((0, 1)))
  assert_eq(find("(?<!a|bc)x", "bx"), Some((1, 2)))
  assert_eq(find("(?<!a|bc)x", "cx"), Some((1, 2)))
  assert_eq(find("(?<!a|bc)x", "ax"), None)
  assert_eq(find("(?<!a|bc)x", "bcx"), None)
  assert_true(is_err("(?<!a(?:b|cd))"))
  assert_true(is_err("(?<!a+b+)"))
}

///|
test "lookbehind_containing_const_size_backref" {
  assert_eq(find("(..)(?<=\\1\\1)", "yyxxxx"), Some((4, 6)))
}

///|
test "lookahead_looks_left" {
  assert_eq(find("a(?=\\b)", "ab"), None)
  assert_eq(find("a(?=\\b)", "a."), Some((0, 1)))
  assert_eq(find("a(?=\\b|_)", "a."), Some((0, 1)))
  assert_eq(find("a(?=_|\\b)", "a."), Some((0, 1)))
}

///|
test "negative_lookahead_fail" {
  // This was a tricky one. There's a negative lookahead that contains a
  // "hard" alternative (because of the lookahead). When the VM gets to the
  // point where the body of the negative lookahead matched, it needs to fail
  // the negative lookahead match. That means it needs to pop the stack until
  // before the negative lookahead, and then fail. But how many times it has
  // to pop is not fixed, it depends on the body/VM state.
  assert_eq(find("(?!a(?=b)|x)", "ab"), Some((1, 1)))
  assert_eq(find("(?!`(?:[^`]+(?=`)|x)`)", "`a`"), Some((1, 1)))
}

///|
test "backref_for_unmatched_group" {
  assert_eq(find("(a)?\\1", "bb"), None)
}

///|
test "backref_with_multibyte" {
  assert_eq(
    find("(.+)\\1+", "x\u{1F431}\u{1F436}\u{1F431}\u{1F436}"),
    Some((1, 17)),
  )
}

///|
test "case_insensitive_backref_with_non_ascii" {
  assert_eq(
    find("(?i)(?<word>\\w+)\\s+\\k<word>", "Greek : δ Δ"),
    Some((8, 13)),
  )
  assert_eq(
    find("(?i)(?<word>\\w+)\\s+\\k<word>", "foo 🎯 test bar BaR"),
    Some((14, 21)),
  )
}

///|
test "repeat_non_greedy" {
  // (?=a) to make it fancy and use VM
  assert_eq(find("(a(?=a)){2,}?", "aaa"), Some((0, 2)))
  assert_eq(find("(a(?=a)){2}?a", "aaa"), Some((0, 3)))
}

///|
test "empty_repeat_non_greedy" {
  // (?=b) to make it fancy and use VM
  assert_eq(find("(a(?=b)|)+?", "ab"), Some((0, 1)))
  // This tests the "prevent zero-length match on repeat" logic
  assert_eq(find("(a(?=b)|)+?x", "ab"), None)
}

///|
test "any_match_unicode_scalar_value" {
  assert_eq(find("(.)\\1", "\u{1F60A}\u{1F60A}"), Some((0, 8)))
  assert_eq(find("(?s)(.)\\1", "\u{1F60A}\u{1F60A}"), Some((0, 8)))
}

///|
test "delegates_match_unicode_scalar_value" {
  assert_eq(find(".(?=a)", "\u{1F60A}a"), Some((0, 4)))
  assert_eq(find(".(?=\\ba+)", "\u{1F60A}a"), Some((0, 4)))
}

///|
test "keepout_matches_in_correct_place" {
  assert_eq(find("a\\Kb", "aaab"), Some((3, 4)))
  assert_eq(find(".+\\Kb", "aaab"), Some((3, 4)))
  assert_eq(find("(?:aaa\\K)b", "aaab"), Some((3, 4)))
}

///|
test "keepout_in_lookarounds_match_in_correct_place" {
  assert_eq(find("(?<=a\\Kb)c", "abc"), Some((1, 3)))
  assert_eq(find("(?<!a\\Kb)c", "axc"), Some((2, 3)))
  assert_eq(find("a(?=b\\Kc)", "abc"), Some((1, 1)))
  assert_eq(find("a(?=b\\Kc)..", "abc"), Some((2, 3)))
  assert_eq(find("a(?!b\\Kc)", "abx"), Some((0, 1)))
}

///|
test "find_no_matches_when_continuing_from_previous_match_end_and_no_match_at_start_of_text" {
  assert_eq(find("\\G(\\d)\\d", " 1122 33"), None)
}

///|
test "find_iter" {
  assert_eq(find_all("(\\d)\\d", "11 22 33"), [(0, 2), (3, 5), (6, 8)])
}

///|
test "find_iter_overlapping_lookahead" {
  assert_eq(find_all("[a-z]{2}(?=[a-z])", "abcdef"), [(0, 2), (2, 4)])
}

///|
test "find_iter_zero_length" {
  assert_eq(find_all("\\d*(?=[a-z])", "ab1c2"), [(0, 0), (1, 1), (2, 3)])
}

///|
test "find_iter_zero_length_longer_codepoint" {
  assert_eq(find_all("\\d*(?=é)", "é1é"), [(0, 0), (2, 3)])
}

///|
test "find_iter_continue_from_previous_match_end" {
  assert_eq(find_all("\\G(\\d)\\d", "1122 33"), [(0, 2), (2, 4)])
}

///|
test "find_iter_continue_from_previous_match_end_with_zero_width_match" {
  assert_eq(find_all("\\G\\d*", "1122 33"), [(0, 4)])
}

///|
test "find_iter_attributes" {
  let text = "ab1c2"
  let regex = @fancy.Regex::new("\\d*(?=[a-z])")
  let matches = regex.find_iter(text)
  assert_eq(matches.text(), text)
  assert_eq(regex.as_str(), matches.regex().as_str())
}

///|
test "find_iter_empty_repeat_issue70" {
  for
    pattern in [
      "(?m)(?:^|a)+", "(?m)(?:^|a)(?:^|a)*", "(?m)(?>)(?:^|a)+", "(?m)(?>)(?:^|a)(?:^|a)*",
    ] {
    assert_eq(find_all(pattern, "a\naaa\n"), [(0, 0), (2, 2), (3, 5), (6, 6)])
  }
}

///|
test "find_iter_empty_repeat_non_greedy_issue70" {
  for
    pattern in [
      "(?m)(?:^|a)+?", "(?m)(?:^|a)(?:^|a)*?", "(?m)(?>)(?:^|a)+?", "(?m)(?>)(?:^|a)(?:^|a)*?",
    ] {
    assert_eq(find_all(pattern, "a\naaa\n"), [
      (0, 0),
      (2, 2),
      (3, 4),
      (4, 5),
      (6, 6),
    ])
  }
}

///|
test "find_iter_empty_repeat_anchored_non_greedy_issue70" {
  for
    pattern in [
      "(?m)(?:^|a)+?$", "(?m)(?:^|a)(?:^|a)*?$", "(?m)(?>)(?:^|a)+?$", "(?m)(?>)(?:^|a)(?:^|a)*?$",
    ] {
    assert_eq(find_all(pattern, "a\naaa\n"), [(0, 1), (2, 5), (6, 6)])
  }
}

///|
test "find_iter_collect_when_backtrack_limit_hit" {
  let r = @fancy.RegexBuilder::new("(x+x+)+(?>y)").backtrack_limit(1).build()
  let result : Array[Result[@fancy.Match, @fancy.FancyError]] = r
    .find_iter("xxxxxxxxxxy")
    .iter()
    .collect()
  assert_eq(result.length(), 1)
  assert_true(result[0] is Err(RuntimeError(BacktrackLimitExceeded)))
}

///|
test "find_conditional" {
  assert_eq(find("(?(ab)c|d)", "acd"), Some((2, 3)))
  assert_eq(find("(a)?b(?(1)c|d)", "abc"), Some((0, 3)))
  assert_eq(find("(a)?b(?(1)c|d)", "abd"), Some((1, 3)))
}

///|
test "find_endtext_before_newlines" {
  assert_eq(find("\\Z", "hello\nworld\n\n\n"), Some((11, 11)))
}

///|
test "incomplete_escape_sequences" {
  // See GH-76
  assert_true(is_err("\\u"))
  assert_true(is_err("\\U"))
  assert_true(is_err("\\x"))
}

///|
test "find_from_pos" {
  let re = @fancy.Regex::new("(?m:^)(\\d+)")
  let text = "1 test 123\n2 foo"
  let mat = re.find_from_pos(text, 7).unwrap()
  assert_eq(mat.start(), 11)
  assert_eq(mat.end(), 12)
  let captures = re.captures_from_pos(text, 7).unwrap()
  let group = captures.get(1).unwrap()
  assert_eq(group.as_str(), "2")
  assert_eq(group.start(), 11)
  assert_eq(group.end(), 12)
  let captures = re.captures(text.view(start_offset=7).to_owned()).unwrap()
  assert_eq(captures.get(1).unwrap().as_str(), "123")
}
