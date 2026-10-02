// Port of `fancy-regex` 0.16.2 `tests/captures.rs`.

///|
fn captures(re : String, text : String) -> @fancy.Captures raise {
  let regex = @fancy.Regex::new(re)
  assert_captures(regex.captures(text))
}

///|
fn assert_captures(result : @fancy.Captures?) -> @fancy.Captures raise {
  match result {
    Some(c) => c
    None => fail("Expected captures, but was None")
  }
}

///|
fn assert_match_at(
  m : @fancy.Match?,
  expected_text : String,
  start : Int,
  end : Int,
) -> Unit raise {
  guard m is Some(m) else { fail("Expected match, but was None") }
  assert_eq(m.as_str(), expected_text)
  assert_eq(m.start(), start)
  assert_eq(m.end(), end)
}

///|
test "capture_names" {
  let regex = @fancy.Regex::new("(?<foo>)()(?P<bar>)")
  assert_eq(regex.capture_names(), [None, Some("foo"), None, Some("bar")])
}

///|
test "captures_fancy" {
  let captures = captures("\\s*(\\w+)(?=\\.)", "foo bar.")
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), " bar", 3, 7)
  assert_match_at(captures.get(1), "bar", 4, 7)
  assert_true(captures.get(2) is None)
}

///|
test "captures_fancy_named" {
  let captures = captures("\\s*(?<name>\\w+)(?=\\.)", "foo bar.")
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), " bar", 3, 7)
  assert_match_at(captures.name("name"), "bar", 4, 7)
  assert_eq(captures.at(0), " bar")
  assert_eq(captures.at_name("name"), "bar")
  assert_true(captures.get(2) is None)
}

///|
test "captures_fancy_unmatched_group" {
  let captures = captures("(\\w+)(?=\\.)|(\\w+)(?=!)", "foo! bar.")
  assert_eq(captures.len(), 3)
  assert_match_at(captures.get(0), "foo", 0, 3)
  assert_true(captures.get(1) is None)
  assert_match_at(captures.get(2), "foo", 0, 3)
}

///|
test "captures_after_lookbehind" {
  let captures = captures(
    "\\s*(?<=[() ])(@\\w+)(\\([^)]*\\))?\\s*", " @another(foo bar)   ",
  )
  assert_match_at(captures.get(1), "@another", 1, 9)
  assert_match_at(captures.get(2), "(foo bar)", 9, 18)
}

///|
test "captures_with_keepout_inside_at_end" {
  let captures = captures("\\s*(\\w+\\K)(?=\\.)", "foo bar.")
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), "", 7, 7)
  assert_match_at(captures.get(1), "bar", 4, 7)
  assert_true(captures.get(2) is None)
}

///|
test "captures_with_keepout_inside_in_middle" {
  let captures = captures("\\s*(b\\Kar)(?=\\.)", "foo bar.")
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), "ar", 5, 7)
  assert_match_at(captures.get(1), "bar", 4, 7)
  assert_true(captures.get(2) is None)
}

///|
test "captures_with_keepout_between" {
  let captures = captures("(\\w+)\\K\\s*(\\w+)(?=\\.)", "foo bar.")
  assert_eq(captures.len(), 3)
  assert_match_at(captures.get(0), " bar", 3, 7)
  assert_match_at(captures.get(1), "foo", 0, 3)
  assert_match_at(captures.get(2), "bar", 4, 7)
  assert_true(captures.get(3) is None)
}

///|
test "captures_with_nested_keepout" {
  let captures = captures("(\\w\\K)+\\s*(\\w+)(?=\\.)", "foo bar.")
  assert_eq(captures.len(), 3)
  assert_match_at(captures.get(0), " bar", 3, 7)
  assert_match_at(captures.get(1), "o", 2, 3)
  assert_match_at(captures.get(2), "bar", 4, 7)
  assert_true(captures.get(3) is None)
}

///|
test "captures_with_conditional" {
  let captures = captures("^(?((ab))c|d)$", "abc")
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), "abc", 0, 3)
  assert_match_at(captures.get(1), "ab", 0, 2)
  assert_true(captures.get(2) is None)
}

///|
test "captures_iter" {
  let text = "11 21 33"
  let mut i = 0
  for
    captures in @fancy.Regex::new("(?P<num>\\d)\\d").captures_iter(text).iter() {
    let captures = captures.unwrap()
    match i {
      0 => {
        assert_eq(captures.len(), 2)
        assert_match_at(captures.get(0), "11", 0, 2)
        assert_match_at(captures.name("num"), "1", 0, 1)
      }
      1 => {
        assert_eq(captures.len(), 2)
        assert_match_at(captures.get(0), "21", 3, 5)
        assert_match_at(captures.name("num"), "2", 3, 4)
      }
      2 => {
        assert_eq(captures.len(), 2)
        assert_match_at(captures.get(0), "33", 6, 8)
        assert_match_at(captures.name("num"), "3", 6, 7)
      }
      i => fail("Expected 3 captures, got \{i + 1}")
    }
    i += 1
  }
}

///|
test "captures_iter_attributes" {
  let text = "11 21 33"
  let regex = @fancy.Regex::new("(?P<num>\\d)\\d")
  let all_captures = regex.captures_iter(text)
  assert_eq(all_captures.text(), text)
  assert_eq(regex.as_str(), all_captures.regex().as_str())
}

///|
test "captures_from_pos" {
  let text = "11 21 33"
  let regex = @fancy.Regex::new("(\\d)\\d")
  let captures = assert_captures(regex.captures_from_pos(text, 3))
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), "21", 3, 5)
  assert_match_at(captures.get(1), "2", 3, 4)
  let matches : Array[@fancy.Match?] = captures.iter().collect()
  assert_eq(matches.length(), 2)
  assert_match_at(matches[0], "21", 3, 5)
  assert_match_at(matches[1], "2", 3, 4)
  for re in ["(\\d+)\\1", "(?P<foo>\\d+)\\k<foo>", "(?P<foo>\\d+)(?P=foo)"] {
    let regex = @fancy.Regex::new(re)
    let captures = assert_captures(regex.captures_from_pos(text, 3))
    assert_eq(captures.len(), 2)
    assert_match_at(captures.get(0), "33", 6, 8)
    assert_match_at(captures.get(1), "3", 6, 7)
    if re != "(\\d+)\\1" {
      assert_match_at(captures.name("foo"), "3", 6, 7)
    }
    let matches : Array[@fancy.Match?] = captures.iter().collect()
    assert_eq(matches.length(), 2)
    assert_match_at(matches[0], "33", 6, 8)
    assert_match_at(matches[1], "3", 6, 7)
  }
}

///|
test "captures_from_pos_looking_left" {
  let regex = @fancy.Regex::new("\\b(\\w)")

  // This should *not* match because `\b` doesn't match between a and x
  let result = regex.captures_from_pos("ax", 1)
  assert_true(result is None)
  let captures = assert_captures(regex.captures_from_pos(".x", 1))
  assert_eq(captures.len(), 2)
  assert_match_at(captures.get(0), "x", 1, 2)
  assert_match_at(captures.get(1), "x", 1, 2)
}

///|
test "captures_iter_collect_when_backtrack_limit_hit" {
  let r = @fancy.RegexBuilder::new("(x+x+)+(?>y)").backtrack_limit(1).build()
  let result : Array[Result[@fancy.Captures, @fancy.FancyError]] = r
    .captures_iter("xxxxxxxxxxy")
    .iter()
    .collect()
  assert_eq(result.length(), 1)
  assert_true(result[0] is Err(_))
}

///|
fn assert_expansion(
  cap : @fancy.Captures,
  replacement : String,
  text : String,
) -> Unit raise {
  let buf = StringBuilder()
  buf.write_string("before")
  cap.expand(replacement, buf)
  assert_eq(buf.to_string(), "before\{text}")
}

///|
fn assert_python_expansion(
  cap : @fancy.Captures,
  replacement : String,
  text : String,
) -> Unit raise {
  assert_eq(@fancy.Expander::python().expansion(replacement, cap), text)
}

///|
test "expand" {
  let regex = @fancy.Regex::new("(a)(b)(?<π>c)(?P<x>d)")
  let cap = regex.captures("abcd").unwrap()
  assert_expansion(cap, "$0", "abcd")
  assert_expansion(cap, "$1", "a")
  assert_expansion(cap, "$2", "b")
  assert_expansion(cap, "$3", "c")
  assert_expansion(cap, "$4", "d")
  assert_expansion(cap, "$π", "c")
  assert_expansion(cap, "$x", "d")
  assert_expansion(cap, "$0π", "")
  assert_expansion(cap, "$1π", "")
  assert_expansion(cap, "$2π", "")
  assert_expansion(cap, "$3π", "")
  assert_expansion(cap, "$4π", "")
  assert_expansion(cap, "$ππ", "")
  assert_expansion(cap, "$xπ", "")
  assert_expansion(cap, "${0}π", "abcdπ")
  assert_expansion(cap, "${1}π", "aπ")
  assert_expansion(cap, "${2}π", "bπ")
  assert_expansion(cap, "${3}π", "cπ")
  assert_expansion(cap, "${4}π", "dπ")
  assert_expansion(cap, "${π}π", "cπ")
  assert_expansion(cap, "${x}π", "dπ")
  assert_expansion(cap, "$", "$")
  assert_expansion(cap, "$π√", "c√")
  assert_expansion(cap, "$x√", "d√")
  assert_expansion(cap, "$$π", "$π")
  assert_expansion(cap, "${π", "${π")
  assert_python_expansion(cap, "\\0", "abcd")
  assert_python_expansion(cap, "\\1", "a")
  assert_python_expansion(cap, "\\2", "b")
  assert_python_expansion(cap, "\\3", "c")
  assert_python_expansion(cap, "\\4", "d")
  assert_python_expansion(cap, "\\π", "\\π")
  assert_python_expansion(cap, "\\x", "\\x")
  assert_python_expansion(cap, "\\0π", "abcdπ")
  assert_python_expansion(cap, "\\1π", "aπ")
  assert_python_expansion(cap, "\\2π", "bπ")
  assert_python_expansion(cap, "\\3π", "cπ")
  assert_python_expansion(cap, "\\4π", "dπ")
  assert_python_expansion(cap, "\\ππ", "\\ππ")
  assert_python_expansion(cap, "\\xπ", "\\xπ")
  assert_python_expansion(cap, "\\g<0>π", "abcdπ")
  assert_python_expansion(cap, "\\g<1>π", "aπ")
  assert_python_expansion(cap, "\\g<2>π", "bπ")
  assert_python_expansion(cap, "\\g<3>π", "cπ")
  assert_python_expansion(cap, "\\g<4>π", "dπ")
  assert_python_expansion(cap, "\\g<π>π", "cπ")
  assert_python_expansion(cap, "\\g<x>π", "dπ")
  assert_python_expansion(cap, "\\", "\\")
  assert_python_expansion(cap, "\\\\π", "\\π")
  assert_python_expansion(cap, "\\g<π", "\\g<π")
}

///|
test "expander_escape" {
  assert_eq(@fancy.Expander::default().escape("hello"), "hello")
  assert_eq(@fancy.Expander::default().escape("a$b\\c"), "a$$b\\c")
  assert_eq(@fancy.Expander::python().escape("a$b\\c"), "a$b\\\\c")
}

///|
fn check_err(
  exp : @fancy.Expander,
  template : String,
  regex : @fancy.Regex,
) -> @fancy.FancyError? {
  try exp.check(template, regex) catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
test "expander_errors" {
  let with_names = @fancy.Regex::new("(?<x>a)")
  let without_names = @fancy.Regex::new("(a)")
  let exp = @fancy.Expander::default()

  // Substitution char at end of template.
  assert_true(check_err(exp, "$", with_names) is Some(ParseError(_, _)))

  // Substitution char not followed by a name or number.
  assert_true(check_err(exp, "$.", with_names) is Some(ParseError(_, _)))

  // Empty delimiter pair.
  assert_true(check_err(exp, "${}", with_names) is Some(ParseError(_, _)))

  // Unterminated delimiter pair.
  assert_true(check_err(exp, "${", with_names) is Some(ParseError(_, _)))

  // Group 0 is always OK.
  assert_true(check_err(exp, "$0", with_names) is None)
  assert_true(check_err(exp, "$0", without_names) is None)

  // Can't use numbers with named groups.
  assert_true(
    check_err(exp, "$1", with_names) is Some(CompileError(NamedBackrefOnly)),
  )
  assert_true(
    check_err(exp, "${1}", with_names) is Some(CompileError(NamedBackrefOnly)),
  )

  // Unmatched group number.
  assert_true(
    check_err(exp, "$2", without_names) is Some(CompileError(InvalidBackref(2))),
  )
  assert_true(
    check_err(exp, "${2}", without_names)
    is Some(CompileError(InvalidBackref(2))),
  )

  // Unmatched group name.
  assert_true(
    check_err(exp, "$xx", with_names)
    is Some(CompileError(InvalidGroupNameBackref("xx"))),
  )
  assert_true(
    check_err(exp, "${xx}", with_names)
    is Some(CompileError(InvalidGroupNameBackref("xx"))),
  )
}
