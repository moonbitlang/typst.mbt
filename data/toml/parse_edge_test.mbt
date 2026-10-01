///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: edge cases" {
  check_parse(
    "a = [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",
    "ok {\"a\": [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]}",
  )
  check_parse(
    "a = [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",
    "ok {\"a\": [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]}",
  )
  check_parse(
    "a = [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",
    "err 83..84: recursion limit exceeded",
  )
  check_parse(
    "a = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = 1}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}",
    "ok {\"a\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": 1}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}",
  )
  check_parse(
    "a = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = {b = 1}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}",
    "ok {\"a\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": {\"b\": 1}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}",
  )
  check_parse(
    "k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k = 1",
    "ok {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": 1}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}",
  )
  check_parse(
    "k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k = 1",
    "err 0..1: recursion limit exceeded",
  )
  check_parse(
    "[k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k]",
    "err 1..2: invalid table header\nrecursion limit exceeded",
  )
  check_parse(
    "[k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k]",
    "ok {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {\"k\": {}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}",
  )
  check_parse(
    "a = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = []}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]",
    "ok {\"a\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": [{\"b\": []}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}",
  )
  check_parse(
    "a = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = [{b = []}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]}]",
    "err 239..240: recursion limit exceeded",
  )
  check_parse("a = \u{4e2d}", "err 4..7: invalid string\nexpected `\"`, `'`")
  check_parse("a = \u{e9}", "err 4..6: invalid string\nexpected `\"`, `'`")
  check_parse(
    "a = \"\\\u{e9}\"", "err 6..8: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse("a = 1\u{e9}", "err 5..7: expected newline, `#`")
  check_parse("[\u{4e2d}]", "err 1..4: invalid key")
  check_parse(
    "[a\u{4e2d}]", "err 2..5: invalid table header\nexpected `.`, `]`",
  )
  check_parse("a = [1,\u{e9}]", "err 7..9: invalid array\nexpected `]`")
  check_parse(
    "a = {\u{4e2d} = 1}", "err 5..8: invalid inline table\nexpected `}`",
  )
  check_parse(
    "a = 1979-05-27T07:32:00\u{e9}", "err 23..25: expected newline, `#`",
  )
  check_parse("a = \"\\u00e9\\U0001f600\"", "ok {\"a\": \"\u{e9}\u{1f600}\"}")
  check_parse("a = \"\\u00E9\"", "ok {\"a\": \"\u{e9}\"}")
  check_parse("a = \"\\uZZZZ\"", "err 7..8: invalid unicode 4-digit hex code")
  check_parse(
    "a = \"\\U0000004\"", "err 7..8: invalid unicode 8-digit hex code",
  )
  check_parse("a = \"\\u", "err 7..7: invalid unicode 4-digit hex code")
  check_parse("\u{feff}\u{feff}a = 1", "err 3..6: invalid key")
  check_parse("\u{feff}", "ok {}")
  check_parse("\u{feff}# c", "ok {}")
  check_parse(
    "a = 1\nb = 2 # c\n\n\n[t] # c\n  x = 1  \n\t\n[[aot]] # c\n[[aot]]\ny = 'z'\n",
    "ok {\"a\": 1, \"b\": 2, \"t\": {\"x\": 1}, \"aot\": [{}, {\"y\": \"z\"}]}",
  )
  check_parse(
    "a.b.c = 1\n[a.d]\ne = 2", "ok {\"a\": {\"b\": {\"c\": 1}, \"d\": {\"e\": 2}}}",
  )
  check_parse(
    "[a.d]\ne = 2\n[a]\nb.c = 1", "ok {\"a\": {\"d\": {\"e\": 2}, \"b\": {\"c\": 1}}}",
  )
  check_parse(
    "[a]\nb.c = 1\n[a.b]", "err 12..13: invalid table header\nduplicate key `b` in table `a`",
  )
  check_parse(
    "[a]\nb.c = 1\n[a.b.d]\nx = 1", "ok {\"a\": {\"b\": {\"c\": 1, \"d\": {\"x\": 1}}}}",
  )
  check_parse(
    "a = {b = 1}\n[a.c]", "err 12..13: invalid table header\ndotted key `a` attempted to extend non-table type (inline table)",
  )
  check_parse(
    "a = [1]\n[[a]]", "err 8..9: invalid table header\nduplicate key `a` in document root",
  )
  check_parse("[[a.b]]\n[a]\nc = 1", "ok {\"a\": {\"b\": [{}], \"c\": 1}}")
  check_parse(
    "[[a.b]]\n[a]\nb = 1", "err 12..13: duplicate key `b` in table `a`",
  )
  check_parse(
    "[[a]]\n[[a.b]]\n[a.b.c]\nd = 1\n[[a.b]]\n[[a]]", "ok {\"a\": [{\"b\": [{\"c\": {\"d\": 1}}, {}]}, {}]}",
  )
  check_parse(
    "[a]\n[[a.b]]\n[[a]]", "err 12..13: invalid table header\nduplicate key `a` in document root",
  )
  check_parse(
    "x = 1\n\"x\" = 2", "err 6..7: duplicate key `x` in document root",
  )
  check_parse("x = 1\n'x' = 2", "err 6..7: duplicate key `x` in document root")
  check_parse(
    "[t]\n'x' = 1\n\"x\" = 2", "err 12..13: duplicate key `x` in table `t`",
  )
  check_parse(
    "[\"t\".'u']\nx = 1\nx = 2", "err 16..17: duplicate key `x` in table `t.u`",
  )
  check_parse(
    "[t]\n[t.u]\nv = 1\n[t]", "err 16..17: invalid table header\nduplicate key `t` in document root",
  )
  check_parse(
    "a = {x = 1}\na.y = 2", "err 12..13: dotted key `a` attempted to extend non-table type (inline table)",
  )
  check_parse(
    "a.y = 2\na = {x = 1}", "err 8..9: duplicate key `a` in document root",
  )
  check_parse("a = {x.y = 1, x = {z = 2}}", "err 5..6: duplicate key `x`")
  check_parse("a = {x = {z = 2}, x.y = 1}", "err 5..6: duplicate key `x`")
  check_parse(
    "a = {x = 1, x.y.z = 1}", "err 5..6: dotted key `x` attempted to extend non-table type (integer)",
  )
  check_parse("a = {b = {}, b.c = 1}", "err 5..6: duplicate key `b`")
  check_parse("a = 1 #", "ok {\"a\": 1}")
  check_parse("a = 1 # \t comment \u{e9}", "ok {\"a\": 1}")
  check_parse("a = 1\t\t\n", "ok {\"a\": 1}")
  check_parse("\t\ta = 1", "ok {\"a\": 1}")
  check_parse("a\t=\t1", "ok {\"a\": 1}")
  check_parse("a = \"x\" \"y\"", "err 8..9: expected newline, `#`")
  check_parse("a = \"\"\"\n\"\"\"", "ok {\"a\": \"\"}")
  check_parse("a = \"\"\"\r\n\"\"\"", "ok {\"a\": \"\"}")
  check_parse("a = '''\r\nx'''", "ok {\"a\": \"x\"}")
  check_parse("a = \"\"\"a\\\n\n\n\"\"\"", "ok {\"a\": \"a\"}")
  check_parse("a = \"\"\"a\\\r\n  b\"\"\"", "ok {\"a\": \"ab\"}")
  check_parse(
    "a = \"\"\"\\\r\"\"\"", "err 9..10: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse("a = '''a'''b'''", "err 11..12: expected newline, `#`")
  check_parse("a = \"\"\"a\"\"\"b\"\"\"", "err 11..12: expected newline, `#`")
  check_parse("a = '''''", "err 7..8: invalid multiline literal string")
  check_parse("a = \"\"\"\"\"\"\"\"\"", "err 12..13: expected newline, `#`")
  check_parse("a = 0b", "err 6..6: invalid binary integer")
  check_parse("a = 0o", "err 6..6: invalid octal integer")
  check_parse(
    "a = 0x1_", "err 8..8: invalid hexadecimal integer\nexpected digit",
  )
  check_parse("a = 0b1__0", "err 8..9: invalid binary integer\nexpected digit")
  check_parse("a = 0xF_F", "ok {\"a\": 255}")
  check_parse("a = 1_0.0_1e1_0", "ok {\"a\": 100100000000.0f}")
  check_parse("a = -0", "ok {\"a\": 0}")
  check_parse("a = +0", "ok {\"a\": 0}")
  check_parse("a = -0.0e0", "ok {\"a\": -0.0f}")
  check_parse("a = 1E+2", "ok {\"a\": 100.0f}")
  check_parse("a = 1e-2_0", "ok {\"a\": 1e-20f}")
  check_parse(
    "a = 179769313486231570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.0",
    "ok {\"a\": 1.797693134862316e302f}",
  )
  check_parse(
    "a = 179769313486231580000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.0",
    "ok {\"a\": 1.797693134862316e302f}",
  )
  check_parse(
    "a = 2.2250738585072011e-308", "ok {\"a\": 2.225073858507201e-308f}",
  )
  check_parse("a = 2.4703282292062327e-324", "ok {\"a\": 0.0f}")
  check_parse("a = 2.4703282292062328e-324", "ok {\"a\": 5e-324f}")
  check_parse("a = 0.30000000000000004", "ok {\"a\": 0.30000000000000004f}")
  check_parse("a = 9007199254740993.0", "ok {\"a\": 9007199254740992.0f}")
  check_parse("a = 1e23", "ok {\"a\": 1e23f}")
  check_parse(
    "a = 1979-05-27T07:32:00.123456789123Z", "ok {\"a\": D(1979-05-27T07:32:00.123456789Z)}",
  )
  check_parse(
    "a = 1979-05-27T07:32:00.000000001", "ok {\"a\": D(1979-05-27T07:32:00.000000001)}",
  )
  check_parse(
    "a = 1979-05-27T07:32:00.1000000000", "ok {\"a\": D(1979-05-27T07:32:00.1)}",
  )
  check_parse(
    "a = 1979-05-27T07:32:00+00:60", "err 27..28: invalid time offset\nvalue is out of range",
  )
  check_parse(
    "a = 1979-05-27T07:32:00+24:00", "err 24..25: invalid time offset\nvalue is out of range",
  )
  check_parse(
    "a = 1979-05-27T07:32:00+-1:00", "err 24..25: invalid time offset",
  )
  check_parse("a = 1979-05-27T07:32:00 Z", "err 24..25: expected newline, `#`")
  check_parse(
    "a = 1979-05-27 07:32:00.5 # c", "ok {\"a\": D(1979-05-27T07:32:00.5)}",
  )
  check_parse("a = 1979-05-27T", "err 14..15: expected newline, `#`")
  check_parse("a = 1979-05-27 07", "err 15..16: expected newline, `#`")
  check_parse("a = 1979-05-27 07:", "err 18..18: invalid date-time")
  check_parse("a = 1979-05-27 07:3", "err 18..19: invalid date-time")
  check_parse("a = 1979-05-27T07:32:00.", "err 23..24: expected newline, `#`")
  check_parse("a = 12:00:00Z", "err 12..13: expected newline, `#`")
  check_parse("a = 12:00:00+01:00", "err 12..13: expected newline, `#`")
  check_parse(
    "a = 1979-00-01", "err 9..10: invalid date-time\nvalue is out of range",
  )
  check_parse(
    "a = 1979-01-00", "err 12..13: invalid date-time\nvalue is out of range",
  )
  check_parse(
    "a = 1979-01-32", "err 12..13: invalid date-time\nvalue is out of range",
  )
  check_parse("a = 1979-01-1", "err 12..13: invalid date-time")
  check_parse("a = 197-01-01", "err 7..8: expected newline, `#`")
  check_parse("a = 19790-01-01", "err 9..10: expected newline, `#`")
  check_parse("a = 1979--01-01", "err 9..10: invalid date-time")
  check_parse("a = [1,\n2,\n# c\n]", "ok {\"a\": [1, 2]}")
  check_parse("a = [\r\n1\r\n]", "ok {\"a\": [1]}")
  check_parse("a = [1\n,2]", "ok {\"a\": [1, 2]}")
  check_parse("a = [1 # c\n, 2]", "ok {\"a\": [1, 2]}")
  check_parse("a = [1, # c\n 2 # d\n]", "ok {\"a\": [1, 2]}")
  check_parse(
    "a = [\"a\", 'b', \"\"\"c\"\"\", '''d''', 1, 1.5, true, 1979-05-27, [], {}]",
    "ok {\"a\": [\"a\", \"b\", \"c\", \"d\", 1, 1.5f, true, D(1979-05-27), [], {}]}",
  )
  check_parse(
    "a = {b = 1, c = [1, 2], d = {e = 'f'}}", "ok {\"a\": {\"b\": 1, \"c\": [1, 2], \"d\": {\"e\": \"f\"}}}",
  )
  check_parse("a = { b = 1 , c = 2 }", "ok {\"a\": {\"b\": 1, \"c\": 2}}")
  check_parse("a = {b=1,c=2}", "ok {\"a\": {\"b\": 1, \"c\": 2}}")
  check_parse(
    "a = {b = 1,\nc = 2}", "err 10..11: invalid inline table\nexpected `}`",
  )
  check_parse("a = {b = [\n1,\n2\n]}", "ok {\"a\": {\"b\": [1, 2]}}")
  check_parse("a = {'b' = 1, \"c\" = 2}", "ok {\"a\": {\"b\": 1, \"c\": 2}}")
}
