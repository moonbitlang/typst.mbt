///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: basic errors" {
  check_parse("a = ", "err 4..4: ")
  check_parse("a = x", "err 4..5: invalid string\nexpected `\"`, `'`")
  check_parse("a = tru", "err 4..5: invalid string\nexpected `\"`, `'`")
  check_parse("a = ix", "err 4..5: invalid string\nexpected `\"`, `'`")
  check_parse("# \u{1}\n", "err 2..3: ")
  check_parse("a=1\r", "err 3..4: expected newline, `#`")
  check_parse(
    "a = \"\\q\"", "err 7..8: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse("a = \"\\", "err 5..6: invalid basic string")
  check_parse("a = \"abc", "err 8..8: invalid basic string")
  check_parse("a = 01", "err 5..6: expected newline, `#`")
  check_parse("a = 1__2", "err 6..7: invalid integer\nexpected digit")
  check_parse("a = 1e400", "err 4..5: invalid floating-point number")
  check_parse("a = -1e400", "ok {\"a\": -inff}")
  check_parse(
    "[a]\n[a]", "err 4..5: invalid table header\nduplicate key `a` in document root",
  )
  check_parse("a = 1\na = 2", "err 6..7: duplicate key `a` in document root")
  check_parse("[a] x", "err 4..5: invalid table header\nexpected newline, `#`")
  check_parse("a = {b = 1, b = 2}", "err 5..6: duplicate key `b`")
  check_parse("a = [1,,2]", "err 7..8: invalid array\nexpected `]`")
  check_parse("a = {a=1,}", "err 8..9: invalid inline table\nexpected `}`")
  check_parse(
    "a = \"\\uD800\"", "err 7..8: invalid unicode 4-digit hex code\nvalue is out of range",
  )
  check_parse("a = \"\\u12\"", "err 7..8: invalid unicode 4-digit hex code")
  check_parse(
    "[a.b]\nx=1\n[c]\n[a]\ny=2", "ok {\"c\": {}, \"a\": {\"b\": {\"x\": 1}, \"y\": 2}}",
  )
  check_parse(
    "a.b = 1\n[a]", "err 8..9: invalid table header\nduplicate key `a` in document root",
  )
  check_parse("=1", "err 0..1: invalid key")
  check_parse("a.", "err 1..2: expected `.`, `=`")
  check_parse(
    "a = 1979-13-01", "err 9..10: invalid date-time\nvalue is out of range",
  )
  check_parse(
    "a = 1979-02-30", "err 12..13: invalid date-time\nvalue is out of range",
  )
  check_parse("a = 25:00:00", "err 6..7: expected newline, `#`")
  check_parse(
    "a = 0x8000000000000000", "err 4..5: number too large to fit in target type",
  )
  check_parse("a = \"\u{e9}\" x", "err 9..10: expected newline, `#`")
  check_parse("\u{e9} = 1", "err 0..2: invalid key")
  check_parse(
    "[ \"a\" ]\n[\"a\"]", "err 8..9: invalid table header\nduplicate key `a` in document root",
  )
  check_parse(
    "[a]\nb=1\n[a.b]", "err 8..9: invalid table header\nduplicate key `b` in table `a`",
  )
  check_parse(
    "a=1\n[a.b]", "err 4..5: invalid table header\ndotted key `a` attempted to extend non-table type (integer)",
  )
  check_parse(
    "[[a]]\n[a]", "err 6..7: invalid table header\nduplicate key `a` in document root",
  )
  check_parse("a = [1 # c", "err 5..6: invalid array\nexpected `]`")
}
