// Port of the unit tests in upstream `lines.rs`.

///|
let lines_test_text = "ä\tcde\nf💛g\r\nhi\rjkl"

///|
/// The `(byte_idx, utf16_idx)` of every line start.
fn line_starts(lines : Lines) -> Array[(Int, Int)] {
  lines.lines.map(line => (line.byte_idx, line.utf16_idx))
}

///|
test "source file new" {
  let lines = Lines::new(lines_test_text)
  assert_eq(line_starts(lines), [(0, 0), (7, 6), (15, 12), (18, 15)])
}

///|
test "source file pos to line" {
  let lines = Lines::new(lines_test_text)
  assert_eq(lines.byte_to_line(0), Some(0))
  assert_eq(lines.byte_to_line(2), Some(0))
  assert_eq(lines.byte_to_line(6), Some(0))
  assert_eq(lines.byte_to_line(7), Some(1))
  assert_eq(lines.byte_to_line(8), Some(1))
  assert_eq(lines.byte_to_line(12), Some(1))
  assert_eq(lines.byte_to_line(21), Some(3))
  assert_eq(lines.byte_to_line(22), None)
}

///|
test "source file pos to column" {
  let lines = Lines::new(lines_test_text)
  assert_eq(lines.byte_to_column(0), Some(0))
  assert_eq(lines.byte_to_column(2), Some(1))
  assert_eq(lines.byte_to_column(6), Some(5))
  assert_eq(lines.byte_to_column(7), Some(0))
  assert_eq(lines.byte_to_column(8), Some(1))
  assert_eq(lines.byte_to_column(12), Some(2))
}

///|
test "source file utf16" {
  fn roundtrip(lines : Lines, byte_idx : Int, utf16_idx : Int) raise {
    let middle = lines.byte_to_utf16(byte_idx).unwrap()
    let result = lines.utf16_to_byte(middle).unwrap()
    assert_eq(middle, utf16_idx)
    assert_eq(result, byte_idx)
  }

  let lines = Lines::new(lines_test_text)
  roundtrip(lines, 0, 0)
  roundtrip(lines, 2, 1)
  roundtrip(lines, 3, 2)
  roundtrip(lines, 8, 7)
  roundtrip(lines, 12, 9)
  roundtrip(lines, 21, 18)
  assert_eq(lines.byte_to_utf16(22), None)
  assert_eq(lines.utf16_to_byte(19), None)
}

///|
test "source file roundtrip" {
  fn roundtrip(lines : Lines, byte_idx : Int) raise {
    let line = lines.byte_to_line(byte_idx).unwrap()
    let column = lines.byte_to_column(byte_idx).unwrap()
    let result = lines.line_column_to_byte(line, column).unwrap()
    assert_eq(result, byte_idx)
  }

  let lines = Lines::new(lines_test_text)
  roundtrip(lines, 0)
  roundtrip(lines, 7)
  roundtrip(lines, 12)
  roundtrip(lines, 21)
}

///|
test "source file edit" {
  // This tests only the non-parser parts. The reparsing itself is
  // tested separately.
  fn test_edit(
    prev : String,
    start : Int,
    end : Int,
    replacement : String,
    after : String,
  ) raise {
    let reference = Lines::new(after)
    let edited = Lines::new(prev)
    edited.edit(start, end, replacement)
    assert_eq(edited.text(), reference.text())
    assert_eq(line_starts(edited), line_starts(reference))
    assert_eq(edited.len_bytes(), reference.len_bytes())
    let replaced = Lines::new(prev)
    let new = utf8_slice(prev, 0, start) +
      replacement +
      utf8_slice(prev, end, utf8_len(prev))
    assert_true(replaced.replace(new))
    assert_eq(replaced.text(), reference.text())
    assert_eq(line_starts(replaced), line_starts(reference))
    assert_eq(replaced.len_bytes(), reference.len_bytes())
  }

  // Test inserting at the beginning.
  test_edit("abc\n", 0, 0, "hi\n", "hi\nabc\n")
  test_edit("\nabc", 0, 0, "hi\r", "hi\r\nabc")

  // Test editing in the middle.
  test_edit(lines_test_text, 4, 16, "❌", "ä\tc❌i\rjkl")

  // Test appending.
  test_edit("abc\ndef", 7, 7, "hi", "abc\ndefhi")
  test_edit("abc\ndef\n", 8, 8, "hi", "abc\ndef\nhi")

  // Test appending with adjoining \r and \n.
  test_edit("abc\ndef\r", 8, 8, "\nghi", "abc\ndef\r\nghi")

  // Test removing everything.
  test_edit(lines_test_text, 0, 21, "", "")
}

///|
test "replacement range" {
  let lines = Lines::new("ä💛b")
  assert_eq(lines.replacement_range("ä💛b"), None)
  // The common prefix/suffix must not split the multi-byte chars.
  assert_eq(lines.replacement_range("ä💚b"), Some((2, 1)))
  assert_eq(lines.replace("ä💛b"), false)
}
