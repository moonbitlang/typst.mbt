///|
/// The category index of an operator info (`a` = 0), as in the generated
/// expectations (the first matching category, so `ForceDefault` reads as
/// `Default`).
fn info_letter(info : OperatorInfo) -> Char {
  for i, candidate in category_infos[:] {
    if candidate == info {
      return ('a'.to_int() + i).unsafe_to_char()
    }
  }
  abort("unknown info")
}

///|
test "OperatorInfo::of matches typst-assets" {
  for entry in test_infos {
    let (form, explicit, expected) = entry
    let actual = StringBuilder()
    for content in test_contents {
      actual.write_char(info_letter(OperatorInfo::of(content, form, explicit)))
    }
    assert_eq(actual.to_string(), expected)
  }
}

///|
fn flags(f : (String) -> Bool) -> String {
  let out = StringBuilder()
  for content in test_contents {
    out.write_char(if f(content) { '1' } else { '0' })
  }
  out.to_string()
}

///|
test "fence, separator, stretch axis and auto transform match typst-assets" {
  assert_eq(flags(is_fence), test_fence)
  assert_eq(flags(is_separator), test_separator)
  assert_eq(
    flags(content => {
      match single_char(content) {
        Some(c) => is_stretch_axis_inline(c)
        None => false
      }
    }),
    test_stretch_axis_inline,
  )
  assert_eq(flags(will_auto_transform), test_auto_transform)
}

///|
test "upstream unit tests" {
  // `test_fence`
  assert_true(is_fence("\u{201D}"))
  assert_true(is_fence("\u{27E7}"))
  assert_true(is_fence("||"))
  assert_false(is_fence("=="))
  assert_false(is_fence(""))
  // `test_separator`
  assert_true(is_separator("\u{2063}"))
  assert_false(is_separator("!="))
  // `test_stretch_axis_is_inline`
  assert_true(is_stretch_axis_inline('\u{1EEF0}'))
  assert_false(is_stretch_axis_inline('\u{1EEF2}'))
  assert_false(is_stretch_axis_inline('\u{003C}'))
}
