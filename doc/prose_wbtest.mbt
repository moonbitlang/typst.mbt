// White-box tests of the placeholder table of `Prose` (docs/edsl-design.md,
// section 4.4): the limits that only show with many interpolations.

///|
test "prose table: pending entries are dropped oldest first at the cap" {
  // One interpolation that is consumed, and one that stays pending and is
  // dropped: both end up below the cutoff.
  let used = "\{Emph("used")}"
  ignore(Prose(used))
  let first = "\{Emph("first")}"
  for _ in 0..<prose_table_max {
    ignore("\{Emph("x")}")
  }
  // `first` was dropped, `used` was consumed: below the cutoff the table
  // cannot tell which, and says so.
  let message = "an interpolated description of this text was already used by another `Prose` or `Para`, or dropped because more than \{prose_table_max} descriptions were interpolated since"
  guard Prose(first).content.node is NInvalid(text, _) else {
    fail("the dropped entry was found")
  }
  assert_eq(text, message)
  guard Prose(used).content.node is NInvalid(text, _) else {
    fail("the consumed entry was found")
  }
  assert_eq(text, message)
  // A new interpolation is unaffected.
  assert_true(Prose("\{Emph("new")}").content.node is NSeq(_, _))
  prose_table.clear()
}

///|
test "prose table: numbers stop before they could exceed 18 digits" {
  let saved = prose_serial.val
  prose_serial.val = 999999999999999999L
  // The last number is a placeholder.
  assert_true(Prose("\{Emph("last")}").content.node is NSeq(_, _))
  // Past it nothing is registered: the token is no placeholder.
  let text = "\{Emph("none")}"
  assert_eq(text, "\u{FDD0}\u{FDD1}")
  guard Prose(text).content.node is NInvalid(message, _) else {
    fail("an exhausted number was accepted")
  }
  assert_eq(
    message, "the text of `Prose` contains a reserved character (U+FDD0)",
  )
  assert_true(prose_leak(text) is Option::None)
  prose_serial.val = saved
}
