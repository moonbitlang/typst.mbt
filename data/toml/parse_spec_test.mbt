///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: toml spec examples" {
  check_parse(
    "string = \"wonderful\"\ninteger = 42\nfloat = 3.14\nboolean = true\ndate_time = 2023-02-01T15:38:57Z\ndate_time2 = 2023-02-01T15:38:57\ndate = 2023-02-01\ntime = 15:38:57\narray = [1, \"string\", 3.0, false]\ninline_table = { first = \"amazing\", second = \"greater\" }\n\n[table]\nelement = 5\nothers = [false, \"indeed\", 7]\n",
    "ok {\"string\": \"wonderful\", \"integer\": 42, \"float\": 3.14f, \"boolean\": true, \"date_time\": D(2023-02-01T15:38:57Z), \"date_time2\": D(2023-02-01T15:38:57), \"date\": D(2023-02-01), \"time\": D(15:38:57), \"array\": [1, \"string\", 3.0f, false], \"inline_table\": {\"first\": \"amazing\", \"second\": \"greater\"}, \"table\": {\"element\": 5, \"others\": [false, \"indeed\", 7]}}",
  )
  check_parse("\"only a string\"\n", "err 15..16: expected `.`, `=`")
  check_parse(
    "title = \"Secret project\"\nversion = 2\nauthors = [\"Mr Robert\", \"Miss Enola\"]\n",
    "ok {\"title\": \"Secret project\", \"version\": 2, \"authors\": [\"Mr Robert\", \"Miss Enola\"]}",
  )
  check_parse("", "ok {}")
  check_parse("   ", "ok {}")
  check_parse("\n\n", "ok {}")
  check_parse("# only comment", "ok {}")
  check_parse("\u{feff}a = 1", "ok {\"a\": 1}")
  check_parse("a = 1 # c\nb = 2\r\nc = 3", "ok {\"a\": 1, \"b\": 2, \"c\": 3}")
  check_parse(
    "str = \"I'm a string. \\\"You can quote me\\\". Name\\tJos\\u00E9\\nLocation\\tSF.\"",
    "ok {\"str\": \"I'm a string. \\\"You can quote me\\\". Name\\tJos\u{e9}\\nLocation\\tSF.\"}",
  )
  check_parse(
    "str1 = \"\"\"\nRoses are red\nViolets are blue\"\"\"", "ok {\"str1\": \"Roses are red\\nViolets are blue\"}",
  )
  check_parse(
    "str2 = \"\"\"\nThe quick brown \\\n\n\n  fox jumps over \\\n    the lazy dog.\"\"\"",
    "ok {\"str2\": \"The quick brown fox jumps over the lazy dog.\"}",
  )
  check_parse(
    "str3 = \"\"\"\\\n       The quick brown \\\n       fox jumps over \\\n       the lazy dog.\\\n       \"\"\"",
    "ok {\"str3\": \"The quick brown fox jumps over the lazy dog.\"}",
  )
  check_parse(
    "str4 = \"\"\"Here are two quotation marks: \"\". Simple enough.\"\"\"", "ok {\"str4\": \"Here are two quotation marks: \\\"\\\". Simple enough.\"}",
  )
  check_parse(
    "str5 = \"\"\"Here are three quotation marks: \"\"\\\".\"\"\"", "ok {\"str5\": \"Here are three quotation marks: \\\"\\\"\\\".\"}",
  )
  check_parse(
    "str6 = \"\"\"Here are fifteen quotation marks: \"\"\\\"\"\"\\\"\"\"\\\"\"\"\\\"\"\"\\\".\"\"\"",
    "ok {\"str6\": \"Here are fifteen quotation marks: \\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\".\"}",
  )
  check_parse(
    "str7 = \"\"\"\"This,\" she said, \"is just a pointless statement.\"\"\"\"",
    "ok {\"str7\": \"\\\"This,\\\" she said, \\\"is just a pointless statement.\\\"\"}",
  )
  check_parse(
    "winpath  = 'C:\\Users\\nodejs\\templates'\nquoted   = 'Tom \"Dubs\" Preston-Werner'\nregex    = '<\\i\\c*\\s*>'",
    "ok {\"winpath\": \"C:\\\\Users\\\\nodejs\\\\templates\", \"quoted\": \"Tom \\\"Dubs\\\" Preston-Werner\", \"regex\": \"<\\\\i\\\\c*\\\\s*>\"}",
  )
  check_parse(
    "regex2 = '''I [dw]on't need \\d{2} apples'''\nlines  = '''\nThe first newline is\ntrimmed in raw strings.\n   All other whitespace\n   is preserved.\n'''",
    "ok {\"regex2\": \"I [dw]on't need \\\\d{2} apples\", \"lines\": \"The first newline is\\ntrimmed in raw strings.\\n   All other whitespace\\n   is preserved.\\n\"}",
  )
  check_parse(
    "quot15 = '''Here are fifteen quotation marks: \"\"\"\"\"\"\"\"\"\"\"\"\"\"\"'''\napos15 = \"Here are fifteen apostrophes: '''''''''''''''\"\nstr = ''''That,' she said, 'is still pointless.''''",
    "ok {\"quot15\": \"Here are fifteen quotation marks: \\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\", \"apos15\": \"Here are fifteen apostrophes: '''''''''''''''\", \"str\": \"'That,' she said, 'is still pointless.'\"}",
  )
  check_parse("a = '''x\r\ny'''", "ok {\"a\": \"x\\ny\"}")
  check_parse("a = \"\"\"x\r\ny\"\"\"", "ok {\"a\": \"x\\ny\"}")
  check_parse("a = '''''''", "ok {\"a\": \"'\"}")
  check_parse("a = ''''''''", "ok {\"a\": \"''\"}")
  check_parse("a = \"\"\"\"\"\"\"", "ok {\"a\": \"\\\"\"}")
  check_parse("a = \"\"\"\"\"\"\"\"", "ok {\"a\": \"\\\"\\\"\"}")
  check_parse(
    "int1 = +99\nint2 = 42\nint3 = 0\nint4 = -17\nint5 = 1_000\nint6 = 5_349_221\nint7 = 53_49_221\nint8 = 1_2_3_4_5",
    "ok {\"int1\": 99, \"int2\": 42, \"int3\": 0, \"int4\": -17, \"int5\": 1000, \"int6\": 5349221, \"int7\": 5349221, \"int8\": 12345}",
  )
  check_parse(
    "hex1 = 0xDEADBEEF\nhex2 = 0xdeadbeef\nhex3 = 0xdead_beef\noct1 = 0o01234567\noct2 = 0o755\nbin1 = 0b11010110",
    "ok {\"hex1\": 3735928559, \"hex2\": 3735928559, \"hex3\": 3735928559, \"oct1\": 342391, \"oct2\": 493, \"bin1\": 214}",
  )
  check_parse(
    "a = 9223372036854775807\nb = -9223372036854775808\nc = 0x7FFFFFFFFFFFFFFF\nd = 0o777777777777777777777\ne = 0b111111111111111111111111111111111111111111111111111111111111111",
    "ok {\"a\": 9223372036854775807, \"b\": -9223372036854775808, \"c\": 9223372036854775807, \"d\": 9223372036854775807, \"e\": 9223372036854775807}",
  )
  check_parse(
    "a = -9223372036854775809", "err 4..5: number too small to fit in target type",
  )
  check_parse(
    "a = 0o1777777777777777777777", "err 4..5: number too large to fit in target type",
  )
  check_parse(
    "a = 0b1000000000000000000000000000000000000000000000000000000000000000", "err 4..5: number too large to fit in target type",
  )
  check_parse(
    "flt1 = +1.0\nflt2 = 3.1415\nflt3 = -0.01\nflt4 = 5e+22\nflt5 = 1e06\nflt6 = -2E-2\nflt7 = 6.626e-34\nflt8 = 224_617.445_991_228",
    "ok {\"flt1\": 1.0f, \"flt2\": 3.1415f, \"flt3\": -0.01f, \"flt4\": 5e22f, \"flt5\": 1000000.0f, \"flt6\": -0.02f, \"flt7\": 6.626e-34f, \"flt8\": 224617.445991228f}",
  )
  check_parse(
    "sf1 = inf\nsf2 = +inf\nsf3 = -inf\nsf4 = nan\nsf5 = +nan\nsf6 = -nan\nz1 = 0.0\nz2 = -0.0\nz3 = +0.0",
    "ok {\"sf1\": inff, \"sf2\": inff, \"sf3\": -inff, \"sf4\": NaNf, \"sf5\": NaNf, \"sf6\": NaNf, \"z1\": 0.0f, \"z2\": -0.0f, \"z3\": 0.0f}",
  )
  check_parse(
    "a = 1.7976931348623157e308\nb = 4.9e-324\nc = 2e-400\nd = 0.1e1\ne = 1E1_0",
    "ok {\"a\": 1.7976931348623157e308f, \"b\": 5e-324f, \"c\": 0.0f, \"d\": 1.0f, \"e\": 10000000000.0f}",
  )
  check_parse(
    "a = 1.", "err 6..6: invalid floating-point number\nexpected digit",
  )
  check_parse(
    "a = .5", "err 4..5: invalid floating-point number\nexpected leading digit",
  )
  check_parse(
    "a = 1.e5", "err 6..7: invalid floating-point number\nexpected digit",
  )
  check_parse("a = 1e", "err 6..6: invalid floating-point number")
  check_parse("a = 1e_5", "err 6..7: invalid floating-point number")
  check_parse("a = 1_", "err 6..6: invalid integer\nexpected digit")
  check_parse("a = _1", "err 4..5: invalid integer\nexpected leading digit")
  check_parse(
    "a = 1.5_", "err 8..8: invalid floating-point number\nexpected digit, digit",
  )
  check_parse("a = 0x", "err 6..6: invalid hexadecimal integer")
  check_parse("a = 0x_1", "err 6..7: invalid hexadecimal integer")
  check_parse("a = 0xG", "err 6..7: invalid hexadecimal integer")
  check_parse("a = 0o8", "err 6..7: invalid octal integer")
  check_parse("a = 0b2", "err 6..7: invalid binary integer")
  check_parse("a = +0x1", "err 6..7: expected newline, `#`")
  check_parse("a = 00", "err 5..6: expected newline, `#`")
  check_parse("a = -01", "err 6..7: expected newline, `#`")
  check_parse("a = 0_0", "err 5..6: expected newline, `#`")
  check_parse("a = 1e+", "err 7..7: invalid floating-point number")
  check_parse("a = 1.2.3", "err 7..8: expected newline, `#`")
  check_parse(
    "a = 3.e+20", "err 6..7: invalid floating-point number\nexpected digit",
  )
  check_parse("a = infinity", "err 7..8: expected newline, `#`")
  check_parse("a = nan1", "err 7..8: expected newline, `#`")
  check_parse("a = -inf1", "err 8..9: expected newline, `#`")
  check_parse("a = +", "err 5..5: invalid integer")
  check_parse("a = -", "err 5..5: invalid integer")
  check_parse("a = +1_", "err 7..7: invalid integer\nexpected digit")
  check_parse("a = 1__", "err 6..7: invalid integer\nexpected digit")
  check_parse(
    "a = 0.", "err 6..6: invalid floating-point number\nexpected digit",
  )
  check_parse("a = 1e5.5", "err 7..8: expected newline, `#`")
  check_parse(
    "bool1 = true\nbool2 = false", "ok {\"bool1\": true, \"bool2\": false}",
  )
  check_parse("a = truee", "err 8..9: expected newline, `#`")
  check_parse("a = fals", "err 4..5: invalid string\nexpected `\"`, `'`")
  check_parse("a = True", "err 4..5: invalid string\nexpected `\"`, `'`")
  check_parse(
    "odt1 = 1979-05-27T07:32:00Z\nodt2 = 1979-05-27T00:32:00-07:00\nodt3 = 1979-05-27T00:32:00.999999-07:00\nodt4 = 1979-05-27 07:32:00Z",
    "ok {\"odt1\": D(1979-05-27T07:32:00Z), \"odt2\": D(1979-05-27T00:32:00-07:00), \"odt3\": D(1979-05-27T00:32:00.999999-07:00), \"odt4\": D(1979-05-27T07:32:00Z)}",
  )
  check_parse(
    "ldt1 = 1979-05-27T07:32:00\nldt2 = 1979-05-27T00:32:00.999999\nld1 = 1979-05-27\nlt1 = 07:32:00\nlt2 = 00:32:00.999999",
    "ok {\"ldt1\": D(1979-05-27T07:32:00), \"ldt2\": D(1979-05-27T00:32:00.999999), \"ld1\": D(1979-05-27), \"lt1\": D(07:32:00), \"lt2\": D(00:32:00.999999)}",
  )
  check_parse("a = 1979-05-27t07:32:00z", "ok {\"a\": D(1979-05-27T07:32:00Z)}")
  check_parse("a = 1979-05-27T07:32", "err 20..20: invalid date-time")
  check_parse(
    "a = 1979-05-27T07:32:00+25:00", "err 24..25: invalid time offset\nvalue is out of range",
  )
  check_parse("a = 1979-05-27T07:32:00+05", "err 26..26: invalid time offset")
  check_parse("a = 1979-05-27T24:00:00", "err 14..15: expected newline, `#`")
  check_parse(
    "a = 1979-05-27T07:60:00", "err 18..19: invalid date-time\nvalue is out of range",
  )
  check_parse(
    "a = 1979-05-27T07:32:61", "err 21..22: invalid date-time\nvalue is out of range",
  )
  check_parse("a = 1979-05-27T07:32:60", "ok {\"a\": D(1979-05-27T07:32:60)}")
  check_parse("a = 2000-02-29", "ok {\"a\": D(2000-02-29)}")
  check_parse(
    "a = 1900-02-29", "err 12..13: invalid date-time\nvalue is out of range",
  )
  check_parse(
    "a = 2023-04-31", "err 12..13: invalid date-time\nvalue is out of range",
  )
  check_parse("a = 1979-5-27", "err 9..10: invalid date-time")
  check_parse("a = 1979-05-7", "err 12..13: invalid date-time")
  check_parse("a = 07:32", "err 9..9: invalid time")
  check_parse("a = 7:32:00", "err 5..6: expected newline, `#`")
  check_parse("a = 07:32:00.", "err 12..13: expected newline, `#`")
  check_parse("a = 07:32:00.1234567891234", "ok {\"a\": D(07:32:00.123456789)}")
  check_parse(
    "a = 1979-05-27T07:32:00.000Z", "ok {\"a\": D(1979-05-27T07:32:00Z)}",
  )
  check_parse(
    "a = 1979-05-27T07:32:00.100+00:00", "ok {\"a\": D(1979-05-27T07:32:00.1+00:00)}",
  )
  check_parse(
    "a = 1979-05-27T07:32:00-00:00", "ok {\"a\": D(1979-05-27T07:32:00+00:00)}",
  )
  check_parse("a = 1979-05-27 # c", "ok {\"a\": D(1979-05-27)}")
  check_parse("a = 1979-05-27 x", "err 15..16: expected newline, `#`")
  check_parse("a = 1979-05-27T", "err 14..15: expected newline, `#`")
  check_parse("a = 1979-05-27 ", "ok {\"a\": D(1979-05-27)}")
  check_parse("a = 1979-05-27T07:32:00Zx", "err 24..25: expected newline, `#`")
  check_parse("a = 0000-01-01", "ok {\"a\": D(0000-01-01)}")
  check_parse(
    "a = 9999-12-31T23:59:60.5+23:59", "ok {\"a\": D(9999-12-31T23:59:60.5+23:59)}",
  )
  check_parse(
    "arr1 = [ 1, 2, 3 ]\narr2 = [ \"red\", \"yellow\", \"green\" ]\narr3 = [ [ 1, 2 ], [3, 4, 5] ]\narr4 = [ \"all\", 'strings', \"\"\"are the same\"\"\", '''type''' ]\narr5 = [ [ 1, 2 ], [\"a\", \"b\", \"c\"] ]",
    "ok {\"arr1\": [1, 2, 3], \"arr2\": [\"red\", \"yellow\", \"green\"], \"arr3\": [[1, 2], [3, 4, 5]], \"arr4\": [\"all\", \"strings\", \"are the same\", \"type\"], \"arr5\": [[1, 2], [\"a\", \"b\", \"c\"]]}",
  )
  check_parse(
    "integers2 = [\n  1, 2, 3\n]\n\nintegers3 = [\n  1,\n  2, # this is ok\n]", "ok {\"integers2\": [1, 2, 3], \"integers3\": [1, 2]}",
  )
  check_parse("a = []", "ok {\"a\": []}")
  check_parse("a = [ ]", "ok {\"a\": []}")
  check_parse("a = [\n]", "ok {\"a\": []}")
  check_parse("a = [,]", "err 5..6: invalid array\nexpected `]`")
  check_parse("a = [1 2]", "err 7..8: invalid array\nexpected `]`")
  check_parse("a = [1,]", "ok {\"a\": [1]}")
  check_parse("a = [1,,]", "err 7..8: invalid array\nexpected `]`")
  check_parse("a = [", "err 5..5: invalid array\nexpected `]`")
  check_parse("a = [1", "err 6..6: invalid array\nexpected `]`")
  check_parse("a = [ # c\n 1, # d\n # e\n]", "ok {\"a\": [1]}")
  check_parse("a = [{x = 1}, {y = 2}]", "ok {\"a\": [{\"x\": 1}, {\"y\": 2}]}")
  check_parse(
    "[table-1]\nkey1 = \"some string\"\nkey2 = 123\n\n[table-2]\nkey1 = \"another string\"\nkey2 = 456",
    "ok {\"table-1\": {\"key1\": \"some string\", \"key2\": 123}, \"table-2\": {\"key1\": \"another string\", \"key2\": 456}}",
  )
  check_parse(
    "[dog.\"tater.man\"]\ntype.name = \"pug\"", "ok {\"dog\": {\"tater.man\": {\"type\": {\"name\": \"pug\"}}}}",
  )
  check_parse(
    "[a.b.c]            # this is best practice\n[ d.e.f ]          # same as [d.e.f]\n[ g .  h  . i ]    # same as [g.h.i]\n[ j . \"\u{29e}\" . 'l' ]  # same as [j.\"\u{29e}\".'l']",
    "ok {\"a\": {\"b\": {\"c\": {}}}, \"d\": {\"e\": {\"f\": {}}}, \"g\": {\"h\": {\"i\": {}}}, \"j\": {\"\u{29e}\": {\"l\": {}}}}",
  )
  check_parse(
    "# [x] you\n# [x.y] don't\n# [x.y.z] need these\n[x.y.z.w] # for this to work\n\n[x] # defining a super-table afterward is ok",
    "ok {\"x\": {\"y\": {\"z\": {\"w\": {}}}}}",
  )
  check_parse(
    "[fruit]\napple = \"red\"\n\n[fruit]\norange = \"orange\"", "err 23..24: invalid table header\nduplicate key `fruit` in document root",
  )
  check_parse(
    "[fruit]\napple = \"red\"\n\n[fruit.apple]\ntexture = \"smooth\"", "err 23..24: invalid table header\nduplicate key `apple` in table `fruit`",
  )
  check_parse(
    "[fruit]\napple.color = \"red\"\napple.taste.sweet = true\n\n[fruit.apple.texture]  # you can add sub-tables\nsmooth = true",
    "ok {\"fruit\": {\"apple\": {\"color\": \"red\", \"taste\": {\"sweet\": true}, \"texture\": {\"smooth\": true}}}}",
  )
  check_parse(
    "[fruit]\napple.color = \"red\"\napple.taste.sweet = true\n\n[fruit.apple]",
    "err 54..55: invalid table header\nduplicate key `apple` in table `fruit`",
  )
  check_parse(
    "[fruit]\napple.color = \"red\"\napple.taste.sweet = true\n\n[fruit.apple.taste]",
    "err 54..55: invalid table header\nduplicate key `taste` in table `fruit.apple`",
  )
  check_parse(
    "name = { first = \"Tom\", last = \"Preston-Werner\" }\npoint = { x = 1, y = 2 }\nanimal = { type.name = \"pug\" }",
    "ok {\"name\": {\"first\": \"Tom\", \"last\": \"Preston-Werner\"}, \"point\": {\"x\": 1, \"y\": 2}, \"animal\": {\"type\": {\"name\": \"pug\"}}}",
  )
  check_parse(
    "[product]\ntype = { name = \"Nail\" }\ntype.edible = false", "err 35..36: dotted key `type` attempted to extend non-table type (inline table)",
  )
  check_parse(
    "[product]\ntype.name = \"Nail\"\ntype = { edible = false }", "err 29..30: duplicate key `type` in table `product`",
  )
  check_parse("a = {}", "ok {\"a\": {}}")
  check_parse("a = { }", "ok {\"a\": {}}")
  check_parse("a = {a = 1 }", "ok {\"a\": {\"a\": 1}}")
  check_parse(
    "a = {a.b = 1, a.c = 2}", "ok {\"a\": {\"a\": {\"b\": 1, \"c\": 2}}}",
  )
  check_parse("a = {a.b = 1, a = 2}", "err 5..6: duplicate key `a`")
  check_parse("a = {a = {b = 1}, a.c = 2}", "err 5..6: duplicate key `a`")
  check_parse(
    "a = {a = 1, a.b = 2}", "err 5..6: dotted key `a` attempted to extend non-table type (integer)",
  )
  check_parse("a = {a = 1\n}", "err 10..11: invalid inline table\nexpected `}`")
  check_parse("a = {\na = 1}", "err 5..6: invalid inline table\nexpected `}`")
  check_parse(
    "a = {a = 1 b = 2}", "err 11..12: invalid inline table\nexpected `}`",
  )
  check_parse(
    "a = {a = 1,, b = 2}", "err 10..11: invalid inline table\nexpected `}`",
  )
  check_parse("a = {a}", "err 6..7: expected `.`, `=`")
  check_parse("a = {", "err 5..5: invalid inline table\nexpected `}`")
  check_parse("a = {a = 1", "err 10..10: invalid inline table\nexpected `}`")
  check_parse(
    "a = {a.b.c = 1, a.b.d = 2, a.e = 3}", "ok {\"a\": {\"a\": {\"b\": {\"c\": 1, \"d\": 2}, \"e\": 3}}}",
  )
  check_parse(
    "[[products]]\nname = \"Hammer\"\nsku = 738594937\n\n[[products]]  # empty table within the array\n\n[[products]]\nname = \"Nail\"\nsku = 284758393\n\ncolor = \"gray\"",
    "ok {\"products\": [{\"name\": \"Hammer\", \"sku\": 738594937}, {}, {\"name\": \"Nail\", \"sku\": 284758393, \"color\": \"gray\"}]}",
  )
  check_parse(
    "[[fruits]]\nname = \"apple\"\n\n[fruits.physical]  # subtable\ncolor = \"red\"\nshape = \"round\"\n\n[[fruits.varieties]]  # nested array of tables\nname = \"red delicious\"\n\n[[fruits.varieties]]\nname = \"granny smith\"\n\n\n[[fruits]]\nname = \"banana\"\n\n[[fruits.varieties]]\nname = \"plantain\"",
    "ok {\"fruits\": [{\"name\": \"apple\", \"physical\": {\"color\": \"red\", \"shape\": \"round\"}, \"varieties\": [{\"name\": \"red delicious\"}, {\"name\": \"granny smith\"}]}, {\"name\": \"banana\", \"varieties\": [{\"name\": \"plantain\"}]}]}",
  )
  check_parse(
    "[fruit.physical]  # subtable, but to which parent element should it belong?\ncolor = \"red\"\nshape = \"round\"\n\n[[fruit]]  # parser must throw an error upon discovering that \"fruit\" is\n           # an array rather than a table\nname = \"apple\"",
    "err 107..108: invalid table header\nduplicate key `fruit` in document root",
  )
  check_parse(
    "fruits = []\n\n[[fruits]] # Not allowed", "err 13..14: invalid table header\nduplicate key `fruits` in document root",
  )
  check_parse(
    "[[fruits]]\nname = \"apple\"\n\n[[fruits.varieties]]\nname = \"red delicious\"\n\n# INVALID: This table conflicts with the previous array of tables\n[fruits.varieties]\nname = \"granny smith\"\n\n[fruits.physical]\ncolor = \"red\"\nshape = \"round\"\n\n# INVALID: This array of tables conflicts with the previous table\n[[fruits.physical]]\ncolor = \"green\"",
    "err 138..139: invalid table header\nduplicate key `varieties` in table `fruits`",
  )
  check_parse("[a", "err 2..2: invalid table header\nexpected `.`, `]`")
  check_parse("[a]]", "err 3..4: invalid table header\nexpected newline, `#`")
  check_parse("[a.]", "err 2..3: invalid table header\nexpected `.`, `]`")
  check_parse("[]", "err 1..2: invalid key")
  check_parse("[[a]", "err 3..4: invalid table header\nexpected `.`, `]]`")
  check_parse("[[a] ]", "err 3..4: invalid table header\nexpected `.`, `]]`")
  check_parse("[[]]", "err 2..3: invalid key")
  check_parse("[ [a]]", "err 2..3: invalid key")
  check_parse(
    "[a] = 1", "err 4..5: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "[a]\n[a.b]\n[a]", "err 10..11: invalid table header\nduplicate key `a` in document root",
  )
  check_parse(
    "[a.b]\n[a]\n[a.b]", "err 10..11: invalid table header\nduplicate key `b` in table `a`",
  )
  check_parse(
    "a = 1\n[a]", "err 6..7: invalid table header\nduplicate key `a` in document root",
  )
  check_parse("[a]\nb = 1\nb = 2", "err 10..11: duplicate key `b` in table `a`")
  check_parse("[a.b]\nc = 1\n[a]\nb.d = 1", "err 16..17: duplicate key `b`")
  check_parse("key = # INVALID", "err 6..7: invalid string\nexpected `\"`, `'`")
  check_parse(
    "first = \"Tom\" last = \"Preston-Werner\" # INVALID", "err 14..15: expected newline, `#`",
  )
  check_parse("= \"no key name\"  # INVALID", "err 0..1: invalid key")
  check_parse(
    "\"\" = \"blank\"     # VALID but discouraged", "ok {\"\": \"blank\"}",
  )
  check_parse(
    "'' = 'blank'     # VALID but discouraged", "ok {\"\": \"blank\"}",
  )
  check_parse(
    "name = \"Tom\"\nname = \"Pradyun\"", "err 13..14: duplicate key `name` in document root",
  )
  check_parse(
    "spelling = \"favorite\"\n\"spelling\" = \"favourite\"", "err 22..23: duplicate key `spelling` in document root",
  )
  check_parse(
    "fruit.apple.smooth = true\nfruit.orange = 2", "ok {\"fruit\": {\"apple\": {\"smooth\": true}, \"orange\": 2}}",
  )
  check_parse(
    "fruit.apple = 1\nfruit.apple.smooth = true", "err 16..17: dotted key `fruit.apple` attempted to extend non-table type (integer)",
  )
  check_parse(
    "apple.type = \"fruit\"\norange.type = \"fruit\"\napple.skin = \"thin\"\norange.skin = \"thick\"\napple.color = \"red\"\norange.color = \"orange\"",
    "ok {\"apple\": {\"type\": \"fruit\", \"skin\": \"thin\", \"color\": \"red\"}, \"orange\": {\"type\": \"fruit\", \"skin\": \"thick\", \"color\": \"orange\"}}",
  )
  check_parse("3.14159 = \"pi\"", "ok {\"3\": {\"14159\": \"pi\"}}")
  check_parse("a.b.c = 1\na.d = 2", "ok {\"a\": {\"b\": {\"c\": 1}, \"d\": 2}}")
  check_parse("\"a.b\" = 1", "ok {\"a.b\": 1}")
  check_parse("a . b = 1", "ok {\"a\": {\"b\": 1}}")
  check_parse("a.\"b\".'c' = 1", "ok {\"a\": {\"b\": {\"c\": 1}}}")
  check_parse("a = \"\\U0001F600\"", "ok {\"a\": \"\u{1f600}\"}")
  check_parse(
    "a = \"\\U00110000\"", "err 7..8: invalid unicode 8-digit hex code\nvalue is out of range",
  )
  check_parse(
    "a = \"\\uDFFF\"", "err 7..8: invalid unicode 4-digit hex code\nvalue is out of range",
  )
  check_parse(
    "a = \"\\x41\"", "err 7..8: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse(
    "a = \"\\ \"", "err 7..8: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse("a = \"a\tb\"", "ok {\"a\": \"a\\tb\"}")
  check_parse("a = \"a\u{1}b\"", "err 6..7: invalid basic string")
  check_parse("a = 'a\u{7f}b'", "err 6..7: invalid literal string")
  check_parse("a = \"a\nb\"", "err 6..7: invalid basic string")
  check_parse("a = 'a\nb'", "err 6..7: invalid literal string")
  check_parse("a = \"\"\"a\\  \n  b\"\"\"", "ok {\"a\": \"ab\"}")
  check_parse(
    "a = \"\"\"a\\ b\"\"\"", "err 10..11: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse(
    "a = \"\"\"a\\\"\"\"", "err 10..11: invalid multiline basic string",
  )
  check_parse("a = \"\"\"", "err 7..7: invalid multiline basic string")
  check_parse("a = '''", "err 7..7: invalid multiline literal string")
  check_parse("a = \"\"\"abc", "err 10..10: invalid multiline basic string")
  check_parse("a = '''abc", "err 10..10: invalid multiline literal string")
  check_parse(
    "a = \"\"\"\u{1}\"\"\"", "err 7..8: invalid multiline basic string",
  )
  check_parse("a = '''\u{1}'''", "err 7..8: invalid multiline literal string")
  check_parse("a = 'abc", "err 8..8: invalid literal string")
  check_parse(
    "a = \"\"\"\\q\"\"\"", "err 9..10: invalid escape sequence\nexpected `b`, `f`, `n`, `r`, `t`, `u`, `U`, `\\`, `\"`",
  )
  check_parse("\"a\nb\" = 1", "err 2..3: invalid basic string")
  check_parse("'a\nb' = 1", "err 2..3: invalid literal string")
  check_parse("\"\\u0041\" = 1", "ok {\"A\": 1}")
  check_parse(
    "a = '\u{e9}\u{4e2d}\u{1f600}'", "ok {\"a\": \"\u{e9}\u{4e2d}\u{1f600}\"}",
  )
  check_parse(
    "a = \"\u{e9}\u{4e2d}\u{1f600}\"", "ok {\"a\": \"\u{e9}\u{4e2d}\u{1f600}\"}",
  )
  check_parse("\u{1f600} = 1", "err 0..4: invalid key")
  check_parse("a = 1 \u{4e2d}", "err 6..9: expected newline, `#`")
  check_parse("a = [1, \u{4e2d}]", "err 8..11: invalid array\nexpected `]`")
  check_parse("a=1\n\r", "err 4..5: ")
  check_parse("a=1\rb=2", "err 3..4: expected newline, `#`")
  check_parse("\r", "err 0..1: ")
  check_parse("\r\n", "ok {}")
  check_parse(
    "a = 1\r\n# c\r\n[b]\r\nc = 2\r\n", "ok {\"a\": 1, \"b\": {\"c\": 2}}",
  )
  check_parse("# c\u{0}", "err 3..4: ")
  check_parse("a = 1 # c\u{7f}", "err 9..10: expected newline, `#`")
  check_parse("#\r\n", "ok {}")
  check_parse("#\r", "err 1..2: ")
  check_parse("a\n= 1", "err 1..2: expected `.`, `=`")
  check_parse("a =\n1", "err 3..4: invalid string\nexpected `\"`, `'`")
  check_parse("a = 1\n  b = 2\n\t[c]", "ok {\"a\": 1, \"b\": 2, \"c\": {}}")
  check_parse("[ a ]\n[ a . b ]", "ok {\"a\": {\"b\": {}}}")
  check_parse(
    "[ \"a b\" ]\n[\"a b\"]", "err 10..11: invalid table header\nduplicate key `\"a b\"` in document root",
  )
  check_parse(
    "[a]\n[\"a b\".c]\n[\"a b\"]\n[\"a b\"]", "err 22..23: invalid table header\nduplicate key `\"a b\"` in document root",
  )
  check_parse("a = [[1], [[2]], [[[3]]]]", "ok {\"a\": [[1], [[2]], [[[3]]]]}")
  check_parse("a = {b = [1, {c = 2}]}", "ok {\"a\": {\"b\": [1, {\"c\": 2}]}}")
  check_parse("x = [{a = 1}, 2]", "ok {\"x\": [{\"a\": 1}, 2]}")
  check_parse(
    "[[a]]\nb = 1\n[a.c]\nd = 1\n[[a]]\nb = 2", "ok {\"a\": [{\"b\": 1, \"c\": {\"d\": 1}}, {\"b\": 2}]}",
  )
  check_parse(
    "[a.b.c]\nx = 1\n[a]\ny = 2\n[a.b]\nz = 3", "ok {\"a\": {\"y\": 2, \"b\": {\"c\": {\"x\": 1}, \"z\": 3}}}",
  )
  check_parse(
    "[x]\n[x.y]\n[x.y.z]\n[x.w]\n[x.y.z2]", "ok {\"x\": {\"y\": {\"z\": {}, \"z2\": {}}, \"w\": {}}}",
  )
}
