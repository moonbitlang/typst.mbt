///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: random documents" {
  check_parse("=+#", "err 0..1: invalid key")
  check_parse("\\x\u{1}07:32:00'\r\n\u{0}\"q k\"Z", "err 0..1: invalid key")
  check_parse("a\\xe1\r0b1\"q k\"", "err 1..2: expected `.`, `=`")
  check_parse("\"q k\"", "err 5..5: expected `.`, `=`")
  check_parse(
    "b07:32:00\"\"\"\\n\"q k\"k = [1, 2]\n'''\\U0001F600x = 1\n1false", "err 3..4: expected `.`, `=`",
  )
  check_parse("'''\u{e9}1e5c.d", "err 2..3: expected `.`, `=`")
  check_parse("\r\n,1e5#nan[t]\n\\n", "err 2..3: invalid key")
  check_parse(".0x1F1.5x = 1\n[t]\n+01:00'l'\u{7f}-", "err 0..1: invalid key")
  check_parse(
    ".5\\}1979-05-27T\n\\U0001F600[[t]]\n\r]]a.b = 2\n+01:00", "err 0..1: invalid key",
  )
  check_parse("\u{0}\"q k\"\u{1} 0o7+01:00", "err 0..1: invalid key")
  check_parse("{{[t]\n1b\"1.5[[t]]\nfalsetru", "err 0..1: invalid key")
  check_parse("eaZ[[t]]\n# c\na.b = 2\n'\\n", "err 3..4: expected `.`, `=`")
  check_parse("\u{7f}", "err 0..1: invalid key")
  check_parse("\"[t]\n:\u{0}tru\\", "err 4..5: invalid basic string")
  check_parse(
    "ak = {x = 1}\nnan\u{e9}\"q k\"1", "err 16..18: expected `.`, `=`",
  )
  check_parse("},\n+'l' = \nc.d\\xbE", "err 0..1: invalid key")
  check_parse("e\t,false", "err 2..3: expected `.`, `=`")
  check_parse("={]]+k = [1, 2]\n", "err 0..1: invalid key")
  check_parse("e1e5\u{e9}", "err 4..6: expected `.`, `=`")
  check_parse(
    "infx = 1\n\u{1}\t\"q k\"0o7Ztrue\\._\r", "err 9..10: invalid key",
  )
  check_parse("[[t]]\n'\\u00e9c.d'''", "err 17..18: expected `.`, `=`")
  check_parse("+01:00", "err 0..1: invalid key")
  check_parse("'l']]\\x", "err 3..4: expected `.`, `=`")
  check_parse(
    "[t]\n\\n'''a.b = 2\n\\x'''k = [1, 2]\n\"q k\"+01:00inf\\n=", "err 4..5: invalid key",
  )
  check_parse(
    "0x1F# c\n\"\"\" 0o7 =  = 0o70x1F]]\\+", "err 4..5: expected `.`, `=`",
  )
  check_parse("b'l'\"\"\"", "err 1..2: expected `.`, `=`")
  check_parse(
    "\u{e9}{[[t]]\n'l'07:32:00\"false\r\n'\\u00e9", "err 0..2: invalid key",
  )
  check_parse(".x = 1\n\rZ1e5[t]\nx = 1\nc.dinf.5", "err 0..1: invalid key")
  check_parse("c.d]]\"inf[", "err 3..4: expected `.`, `=`")
  check_parse("\\n\"\"\"e\r\n07:32:00false", "err 0..1: invalid key")
  check_parse(
    "k = {x = 1}\n\u{0}k = {x = 1}\n0= \n[{{k = {x = 1}\n", "err 12..13: invalid key",
  )
  check_parse("enan[t]\n+", "err 4..5: expected `.`, `=`")
  check_parse("truetrue\t1e50\u{0}", "err 9..10: expected `.`, `=`")
  check_parse("\rinf ", "err 0..1: ")
  check_parse(" = 07:32:00]# c\ntrue\t07:32:00", "err 1..2: invalid key")
  check_parse("'''\n", "err 2..3: expected `.`, `=`")
  check_parse("1979-05-271e5k = {x = 1}\n\t\u{e9}", "err 26..28: invalid key")
  check_parse("\r 1e5bb", "err 0..1: ")
  check_parse(":\t", "err 0..1: invalid key")
  check_parse(".", "err 0..1: invalid key")
  check_parse("\\]]\t\\x", "err 0..1: invalid key")
  check_parse("0]]\r", "err 1..2: expected `.`, `=`")
  check_parse("07:32:001e5+\u{7f}0b1\r\n'", "err 2..3: expected `.`, `=`")
  check_parse(
    "0b1 \"q k\"b1e50b1\\x+01:000b1.5=", "err 4..5: expected `.`, `=`",
  )
  check_parse("0b1\u{e9}", "err 3..5: expected `.`, `=`")
  check_parse("+\"\"\"", "err 0..1: invalid key")
  check_parse("\u{1}tru_,'0o7\"-1979-05-27\n", "err 0..1: invalid key")
  check_parse("\n\\x\ntrue1", "err 1..2: invalid key")
  check_parse("0o7 inf,0b10x1F-", "err 4..5: expected `.`, `=`")
  check_parse("\r\n\n-'''c.d-", "err 4..5: expected `.`, `=`")
  check_parse(" = e =  = c.db1e5", "err 1..2: invalid key")
  check_parse("x = 1\n\u{1}[[\r\n[t]\ninf", "err 6..7: invalid key")
  check_parse("[[t]]\n}", "err 6..7: invalid key")
  check_parse("[[]0b1", "err 2..3: invalid key")
  check_parse("\r[[t]]\n1e5# c\n'", "err 0..1: ")
  check_parse("'l'0b1'", "err 3..4: expected `.`, `=`")
  check_parse("0x1F\\u00e9k = {x = 1}\n", "err 4..5: expected `.`, `=`")
  check_parse(" -+", "err 2..3: expected `.`, `=`")
  check_parse("\\x\\u00e9", "err 0..1: invalid key")
  check_parse(
    "+\\U0001F600k = {x = 1}\n\u{e9}b+01:00true{_", "err 0..1: invalid key",
  )
  check_parse("\"q k\"\\c.d=tru[# c\n[", "err 5..6: expected `.`, `=`")
  check_parse("E+01:00.5}\n", "err 1..2: expected `.`, `=`")
  check_parse("\u{0}a}k = [1, 2]\n", "err 0..1: invalid key")
  check_parse("[t]\n\\U0001F600'''00b1x = 1\n", "err 4..5: invalid key")
  check_parse("\u{7f}''':trueE'''  = [[t]]\nT]]", "err 0..1: invalid key")
  check_parse("'0o70x1F0x1FT{\u{4e2d}\n#", "err 17..18: invalid literal string")
  check_parse(
    "[[t]]\n07:32:00}[[+\\n\"\"\" x = 1\n+01:00", "err 8..9: expected `.`, `=`",
  )
  check_parse(
    "falseZ[[t]]\n{ k = [1, 2]\n\n+\r\ne\n[", "err 6..7: expected `.`, `=`",
  )
  check_parse(
    "\n\\U0001F600007:32:00\\u00e9+01:00{inf\\U0001F600# c\n", "err 1..2: invalid key",
  )
  check_parse(
    "\u{0}\"\"\"#\\u00e9k = {x = 1}\n:#1e5E-", "err 0..1: invalid key",
  )
  check_parse("a.k = [1, 2]\n\\U0001F600c.d\"q k\"-", "err 13..14: invalid key")
  check_parse("'}1.5]\"", "err 7..7: invalid literal string")
  check_parse("0o7+\\x{tru", "err 3..4: expected `.`, `=`")
  check_parse("\\#'Z'1.5\r\"q k\"", "err 0..1: invalid key")
  check_parse("b1e5", "err 4..4: expected `.`, `=`")
  check_parse(
    "[ = [t]\nT0o7\\u00e9[t]\ntruk = [1, 2]\ninfa", "err 2..3: invalid key",
  )
  check_parse("\\U0001F600\\x", "err 0..1: invalid key")
  check_parse("0o7.5truex = 1\n\t07:32:00", "err 18..19: expected `.`, `=`")
  check_parse(
    "'aE[[t]]\n\"\u{4e2d}a.b = 2\n", "err 8..9: invalid literal string",
  )
  check_parse(
    "0o7{\\xk = [1, 2]\n\"1979-05-27k = [1, 2]\n", "err 3..4: expected `.`, `=`",
  )
  check_parse("Z", "err 1..1: expected `.`, `=`")
  check_parse("\\n.5true=x = 1\n-1e5c.d:[[", "err 0..1: invalid key")
  check_parse("+01:00e} = bfalse_:0x1F[[\u{4e2d}", "err 0..1: invalid key")
  check_parse("\u{0}{\u{4e2d}[[t]]\n ", "err 0..1: invalid key")
  check_parse("[[t]]\n\r\n\\n=tru", "err 8..9: invalid key")
  check_parse("\\U0001F600c.d", "err 0..1: invalid key")
  check_parse("[t]\n]]\n", "err 4..5: invalid key")
  check_parse("E0x1F'k = [1, 2]\n'0nan", "err 5..6: expected `.`, `=`")
  check_parse("= = a.b = 2\nT\u{4e2d}", "err 0..1: invalid key")
  check_parse(" {0x1Fetru1+01:00.5}", "err 1..2: invalid key")
  check_parse("_nan'''_-\"q k\".50b1", "err 4..5: expected `.`, `=`")
  check_parse("-e. = {\\U0001F600]", "err 2..3: expected `.`, `=`")
  check_parse(
    "_\u{e9}k = [1, 2]\n]][[\\U0001F6001979-05-270o7.5", "err 1..3: expected `.`, `=`",
  )
  check_parse("\t'0o7=", "err 6..6: invalid literal string")
  check_parse("1+01:00", "err 1..2: expected `.`, `=`")
  check_parse("x = 1\n\r\n, =c.d", "err 8..9: invalid key")
  check_parse(
    "'l'x = 1\nk = [1, 2]\n\\U0001F600", "err 3..4: expected `.`, `=`",
  )
  check_parse("E#}\r\n'''.5", "err 1..2: expected `.`, `=`")
  check_parse("x = 1\n\\x07:32:00{", "err 6..7: invalid key")
  check_parse("01.5\u{4e2d}Z", "err 4..7: expected `.`, `=`")
  check_parse("\\x_nanx = 1\n", "err 0..1: invalid key")
  check_parse("\t\"\"\"\n ba\u{7f}0b1Z1.5", "err 3..4: expected `.`, `=`")
  check_parse(".5]][[\"q k\"", "err 0..1: invalid key")
  check_parse("Z", "err 1..1: expected `.`, `=`")
  check_parse("=07:32:00+", "err 0..1: invalid key")
  check_parse("\n\u{4e2d}0x1F", "err 1..4: invalid key")
  check_parse("'l'", "err 3..3: expected `.`, `=`")
  check_parse("=k = [1, 2]\n# c\n E#\\u00e9\n.", "err 0..1: invalid key")
  check_parse("x = 1\n", "ok {\"x\": 1}")
  check_parse("# c\nE.\\xZnane_--=", "err 5..6: expected `.`, `=`")
  check_parse(
    "}false\\na.b = 2\n=tru:k = {x = 1}\n\"k = {x = 1}\n", "err 0..1: invalid key",
  )
  check_parse("=e = +}\r\n[[", "err 0..1: invalid key")
  check_parse("'", "err 1..1: invalid literal string")
  check_parse("  \n[[t]]\n\u{1}[t]\nT", "err 9..10: invalid key")
  check_parse("0b1 ", "err 4..4: expected `.`, `=`")
  check_parse("k = {x = 1}\n'l'\\U0001F600", "err 15..16: expected `.`, `=`")
  check_parse(
    "# c\n+01:00\\x\"q k\"k = [1, 2]\ne\n+inf\n0x1F", "err 4..5: invalid key",
  )
  check_parse("Z", "err 1..1: expected `.`, `=`")
  check_parse("_", "err 1..1: expected `.`, `=`")
  check_parse("# c\n_07:32:00\t0x1F\r\n", "err 7..8: expected `.`, `=`")
  check_parse("-[t]\n'nantrue[[t]]\n+01:00", "err 1..2: expected `.`, `=`")
  check_parse(
    "\u{7f}\r# c\n\\xk = [1, 2]\na.b = 2\nk = {x = 1}\n\"q k\"1e5]]", "err 0..1: invalid key",
  )
  check_parse("TZa.b = 2\ninf", "err 13..13: expected `.`, `=`")
  check_parse(":false", "err 0..1: invalid key")
  check_parse("= 0x1F", "err 0..1: invalid key")
  check_parse(
    "k = {x = 1}\n0b1\\0x1F0b1trueinfa.b = 2\n[t]\nb", "err 15..16: expected `.`, `=`",
  )
  check_parse("#[[0b1infinf=\\xE\u{7f}", "err 16..17: ")
  check_parse(
    "1979-05-2707:32:00\n=[ k = [1, 2]\n\u{0}", "err 12..13: expected `.`, `=`",
  )
  check_parse(
    "+-true1979-05-27T.50o7\u{4e2d}truek = {x = 1}\n", "err 0..1: invalid key",
  )
  check_parse("{\"q k\"]+'''[\t,:", "err 0..1: invalid key")
  check_parse(
    " \r\ne\r'_=k = [1, 2]\n\n = \"\"\"}", "err 4..5: expected `.`, `=`",
  )
  check_parse("\\u00e9c.dT\u{0}1.5'''\"x = 1\n0", "err 0..1: invalid key")
  check_parse("\\x1979-05-27.\u{7f} = +:", "err 0..1: invalid key")
  check_parse("bk = {x = 1}\n07:32:00[[t]]\n", "err 15..16: expected `.`, `=`")
  check_parse(" = .5[[t]]\n\\n tru\u{e9}a", "err 1..2: invalid key")
  check_parse("0x1Fa#0x1F", "err 5..6: expected `.`, `=`")
  check_parse(
    "0b11.5k = [1, 2]\n:a.b = 2\n:0o7\\x0x1F", "err 17..18: invalid key",
  )
  check_parse("[t]\n\\U0001F600[", "err 4..5: invalid key")
  check_parse("]]+b\\n'l'T\\.51.5", "err 0..1: invalid key")
  check_parse("c.d\n\naZe\u{4e2d}eT\u{7f}true", "err 3..4: expected `.`, `=`")
  check_parse("\u{e9}\t\u{7f}tru]\\]", "err 0..2: invalid key")
  check_parse("}", "err 0..1: invalid key")
  check_parse("T# c\n1.5:_", "err 1..2: expected `.`, `=`")
  check_parse(
    "1.5\\E\\u00e9nan\u{0}\"\"\"\u{0}.5", "err 3..4: expected `.`, `=`",
  )
  check_parse("\\n\n=# c\n'[[1\"q k\"\r+[[\u{7f}", "err 0..1: invalid key")
  check_parse(".5,", "err 0..1: invalid key")
  check_parse("\n", "ok {}")
  check_parse(" \"\"\"k = {x = 1}\n\\nfalse \r", "err 3..4: expected `.`, `=`")
  check_parse("\\#_E}\u{7f} \"\"\"\nZ#\\x", "err 0..1: invalid key")
  check_parse("[[t]]\nx = 1\n+01:00\t\u{7f}", "err 12..13: invalid key")
  check_parse("[[Z", "err 3..3: invalid table header\nexpected `.`, `]]`")
  check_parse(
    "\"{a.b = 2\n+\\k = {x = 1}\n1.5x = 1\n\"\"\"true", "err 9..10: invalid basic string",
  )
  check_parse("\rbfalsee=\\U0001F6000x1F\r\n", "err 0..1: ")
  check_parse("[[t]]\nEe-", "err 9..9: expected `.`, `=`")
  check_parse("]# c\n+.:=k = {x = 1}\n", "err 0..1: invalid key")
  check_parse("[[t]]\n[[:eE\u{7f}0o7e\u{0}\"\"\"", "err 8..9: invalid key")
  check_parse("T\u{1}0true},\\xk = {x = 1}\n", "err 1..2: expected `.`, `=`")
  check_parse("=[t]\ninf", "err 0..1: invalid key")
  check_parse(
    "[\"\"\"0b1x = 1\n\u{7f}nan## c\n[", "err 3..4: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "+'''\nk = {x = 1}\n }\t'''\"[t]\n0o7\\n", "err 0..1: invalid key",
  )
  check_parse("ac.d0o7'''\n'''", "err 7..8: expected `.`, `=`")
  check_parse("trueea.b = 2\n07:32:00c.d", "err 15..16: expected `.`, `=`")
  check_parse("nanfalse", "err 8..8: expected `.`, `=`")
  check_parse("\t+]", "err 1..2: invalid key")
  check_parse(
    " false = \n\r0x1F0b1-ek = [1, 2]\n ", "err 9..10: invalid string\nexpected `\"`, `'`",
  )
  check_parse("\"q k\"\n[.5T0", "err 5..6: expected `.`, `=`")
  check_parse("nanE", "err 4..4: expected `.`, `=`")
  check_parse("[[t]]\n", "ok {\"t\": [{}]}")
  check_parse("\ttru# c\ne.5\n", "err 4..5: expected `.`, `=`")
  check_parse(
    "k = [1, 2]\n\u{1}\\k = {x = 1}\n+01:000x1F'''0x1F[ [[t]]\n", "err 11..12: invalid key",
  )
  check_parse("}0", "err 0..1: invalid key")
  check_parse("\\u00e9Ec.d+", "err 0..1: invalid key")
  check_parse("ek = [1, 2]\n_\u{1}# c\n.5\rT=", "err 13..14: expected `.`, `=`")
  check_parse(
    "1979-05-27[t]\n\"q k\"0o7\\x# c\n[[ = ]\"\"\"\u{7f}", "err 10..11: expected `.`, `=`",
  )
  check_parse(
    "1979-05-271e5]][[07:32:00\\U0001F600", "err 13..14: expected `.`, `=`",
  )
  check_parse("#]e1e5bk = {x = 1}\nb", "err 20..20: expected `.`, `=`")
  check_parse(
    "# c\n07:32:00\r\n\u{e9}\"q k\"\\u00e9\\nET:.5", "err 6..7: expected `.`, `=`",
  )
  check_parse("\u{4e2d} \r\n\u{1}'l'a \t[k = [1, 2]\n", "err 0..3: invalid key")
  check_parse("truetru\u{1}-0\rtru]]", "err 7..8: expected `.`, `=`")
  check_parse(" 0b1", "err 4..4: expected `.`, `=`")
  check_parse("false+=\\u00e9\\07:32:00tru", "err 5..6: expected `.`, `=`")
  check_parse("true\\U0001F6000a.b = 2\n]", "err 4..5: expected `.`, `=`")
  check_parse("true", "err 4..4: expected `.`, `=`")
  check_parse("\t[[t]]\n}\u{0}true#c.d\u{7f}'Z}", "err 7..8: invalid key")
  check_parse("1\r\n-nannan-\u{4e2d}", "err 1..2: expected `.`, `=`")
  check_parse(
    "\u{1}Tx = 1\n.\\u00e9\\U0001F600.5#\u{0}e# c\n[[", "err 0..1: invalid key",
  )
  check_parse("07:32:00", "err 2..3: expected `.`, `=`")
  check_parse("\r\"q k\" = ,\u{e9}07:32:00[t]\n", "err 0..1: ")
  check_parse("[[[[k = [1, 2]\n\r+", "err 2..3: invalid key")
  check_parse("\u{4e2d}", "err 0..3: invalid key")
  check_parse("1k = {x = 1}\n+01:00a-\\n]]", "err 13..14: invalid key")
  check_parse(
    "}true0 = k = {x = 1}\n]]}07:32:00c.d[[t]]\n\"\"\"", "err 0..1: invalid key",
  )
  check_parse(
    "0 a.b = 2\n.[t]\nk = {x = 1}\n = ", "err 2..3: expected `.`, `=`",
  )
  check_parse("+01:00\u{4e2d}# ", "err 0..1: invalid key")
  check_parse("\n\r\n\u{7f} a.b = 2\n0b", "err 3..4: invalid key")
  check_parse("0o7", "err 3..3: expected `.`, `=`")
  check_parse("E\\{[0b1k = {x = 1}\n\\x[t]\n", "err 1..2: expected `.`, `=`")
  check_parse("{+01:00Z\"x = 1\nE1979-05-27", "err 0..1: invalid key")
  check_parse("_E}", "err 2..3: expected `.`, `=`")
  check_parse(
    "\n1979-05-27true]_++falseZE\u{4e2d}b", "err 15..16: expected `.`, `=`",
  )
  check_parse("# c\n+'''", "err 4..5: invalid key")
  check_parse(" = k = {x = 1}\n\"\\n", "err 1..2: invalid key")
  check_parse(
    "0[\u{e9}+01:00\"\n = [[=\"q k\".507:32:00", "err 1..2: expected `.`, `=`",
  )
  check_parse("[# c\nk = {x = 1}\n = 007:32:00[", "err 1..2: invalid key")
  check_parse("\"+01:00tru}'''", "err 14..14: invalid basic string")
  check_parse("]false\u{0}k = {x = 1}\n1e5", "err 0..1: invalid key")
  check_parse("[[t]]\n0x1F", "err 10..10: expected `.`, `=`")
  check_parse("\u{4e2d}c.d1e5\r", "err 0..3: invalid key")
  check_parse("T\\U0001F600+= 0b1]]# c\n\r\t", "err 1..2: expected `.`, `=`")
  check_parse("-'[t]\n[t]\n+01:00#\"\"\"", "err 1..2: expected `.`, `=`")
  check_parse("a.b = 2\n[+a#\"07:32:00", "err 9..10: invalid key")
  check_parse("\u{7f}1e'l'{[t]\n1:E\\.5", "err 0..1: invalid key")
  check_parse("x = 1\n\r\n# c\n,c.d", "err 12..13: invalid key")
  check_parse(
    " \u{0}\"\"\"+01:00k = {x = 1}\ntrue-\r\n", "err 1..2: invalid key",
  )
  check_parse(" \\n", "err 1..2: invalid key")
  check_parse(".}[t]\n.[[t]]\nZa.b = 2\n1979-05-27", "err 0..1: invalid key")
  check_parse("11979-05-27=true", "ok {\"11979-05-27\": true}")
  check_parse("\u{e9}", "err 0..2: invalid key")
  check_parse("}", "err 0..1: invalid key")
  check_parse("1.5\u{1} ", "err 3..4: expected `.`, `=`")
  check_parse("[t]\n=+01:00\n.5[[t]]\n0x1F+01:00etru", "err 4..5: invalid key")
  check_parse(" \u{7f}c.d\\n0x1F0b1[[E", "err 1..2: invalid key")
  check_parse("1979-05-27\\", "err 10..11: expected `.`, `=`")
  check_parse(
    "a.b = 2\n\"q k\"\t'l'k = [1, 2]\nb\r\n", "err 14..15: expected `.`, `=`",
  )
  check_parse("trueT'l'T = \u{0}", "err 5..6: expected `.`, `=`")
  check_parse("\n\\xnan[t]\na]]inf1979-05-27\"\"\"]]", "err 1..2: invalid key")
  check_parse("\r.50b1[[t]]\n\\1979-05-27true_T'l'", "err 0..1: ")
  check_parse("=-_+01:001.5\n = {e:\n# c\n", "err 0..1: invalid key")
  check_parse("_0'\r\nE", "err 2..3: expected `.`, `=`")
  check_parse(
    "\u{7f} [[t]]\n0x1F' = 0b1true1e5a.b = 2\n['l'", "err 0..1: invalid key",
  )
  check_parse(
    "1979-05-27'l'\"q k\"0b1\\]] k = [1, 2]\n", "err 10..11: expected `.`, `=`",
  )
  check_parse(",\"1\t# c\n[t]\n#", "err 0..1: invalid key")
  check_parse(
    "e\u{e9}\"=1979-05-27\u{e9}nantru'''bb\u{0}", "err 1..3: expected `.`, `=`",
  )
  check_parse("{", "err 0..1: invalid key")
  check_parse(" b1\nk = [1, 2]\n", "err 3..4: expected `.`, `=`")
  check_parse("'l'k = [1, 2]\n\"", "err 3..4: expected `.`, `=`")
  check_parse("\\U0001F6001.5-\u{0}", "err 0..1: invalid key")
  check_parse("Tinf+01:00 = .,.0x1F\\n", "err 4..5: expected `.`, `=`")
  check_parse(
    "\u{1}1979-05-27c.d\u{0}c.d\r\\u00e9truetrue = ", "err 0..1: invalid key",
  )
  check_parse(
    "\\.[[t]]\nx = 1\n[t]\n\u{7f}\\x\u{1}{ek = [1, 2]\n", "err 0..1: invalid key",
  )
  check_parse("+01:00_+0o7b", "err 0..1: invalid key")
  check_parse(
    " \u{e9}\u{e9}tru1[[t]]\n\\U0001F600'\u{1}nan", "err 1..3: invalid key",
  )
  check_parse("]Z\\u00e9 \ttrub+ 0o707:32:00b", "err 0..1: invalid key")
  check_parse("true0o7 '\nnan", "err 8..9: expected `.`, `=`")
  check_parse("=# c\n", "err 0..1: invalid key")
  check_parse(
    "1e5:true1\"q k\",[t]\n1979-05-270x1F1e507:32:00\\", "err 3..4: expected `.`, `=`",
  )
  check_parse("\u{4e2d} = \":1 0'''-", "err 0..3: invalid key")
  check_parse(
    "+01:0007:32:00'[[0x1F1979-05-27a0o7\\U0001F600x = 1\n{]", "err 0..1: invalid key",
  )
  check_parse("T", "err 1..1: expected `.`, `=`")
  check_parse("true[[t]]\n\u{0}0b1\t1e5E", "err 4..5: expected `.`, `=`")
  check_parse("b0o7\n\u{0}\t[t]\n'''", "err 4..5: expected `.`, `=`")
  check_parse(
    "_\\u00e9T1 \r[[t]]\n[[t]]\n[[t]]\n]]", "err 1..2: expected `.`, `=`",
  )
  check_parse("1e5 =", "err 5..5: ")
  check_parse("a=\\nc.d", "err 2..3: invalid string\nexpected `\"`, `'`")
  check_parse("=b", "err 0..1: invalid key")
  check_parse("k = {x = 1}\n", "ok {\"k\": {\"x\": 1}}")
  check_parse("nanc.db\"\"\"\u{1}\"", "err 7..8: expected `.`, `=`")
  check_parse("1e5a.b = 2\n+1,", "err 11..12: invalid key")
  check_parse("+01:00=0\\x", "err 0..1: invalid key")
  check_parse("nan", "err 3..3: expected `.`, `=`")
  check_parse(":#c.d,[t]\n\n", "err 0..1: invalid key")
  check_parse("\"\"\"'''}", "err 2..3: expected `.`, `=`")
  check_parse("\r\n=0b1]=", "err 2..3: invalid key")
  check_parse(
    "[[1 1.5false=\n\\U0001F600", "err 4..5: invalid table header\nexpected `.`, `]]`",
  )
  check_parse("1,#=", "err 1..2: expected `.`, `=`")
  check_parse(" \t\n'''", "err 5..6: expected `.`, `=`")
  check_parse("+k = [1, 2]\n\\n-'l'", "err 0..1: invalid key")
  check_parse(
    "+.inffalsetru\u{e9}07:32:00Z\n\\n-\u{0}", "err 0..1: invalid key",
  )
  check_parse("}\t0 = \\u00e9E", "err 0..1: invalid key")
  check_parse(
    "0x1FnanT:\u{e9}1979-05-27tru0b1+01:00", "err 8..9: expected `.`, `=`",
  )
  check_parse("[[t]]\nc.dT# c\n0x1F{0x1F# c\n", "err 10..11: expected `.`, `=`")
  check_parse("[[{\u{e9}[[[]]\n+0", "err 2..3: invalid key")
  check_parse("0b1{E\u{1}0o7 = ", "err 3..4: expected `.`, `=`")
  check_parse(
    "[[tru\\x\r[[0b1=", "err 5..6: invalid table header\nexpected `.`, `]]`",
  )
  check_parse(
    ",\u{7f}k = {x = 1}\n'l' .tru1979-05-27[t]\ntru[t]\n", "err 0..1: invalid key",
  )
  check_parse("Ttrue#,07:32:00'l'e'=-0x1F", "err 5..6: expected `.`, `=`")
  check_parse(".5-1979-05-27 11e5", "err 0..1: invalid key")
  check_parse("a\"\r\n['''T[t]\ne]]]1 = ", "err 1..2: expected `.`, `=`")
  check_parse(
    "[[t]]\n[[t]]\n\\u00e9\\U0001F600[[t]]\n", "err 12..13: invalid key",
  )
  check_parse(",[[t]]\ntru\"\\u00e9 = E'", "err 0..1: invalid key")
  check_parse("]['c.d", "err 0..1: invalid key")
  check_parse("\u{0}1979-05-27,", "err 0..1: invalid key")
  check_parse("1979-05-27", "err 10..10: expected `.`, `=`")
  check_parse("0\"\"\"", "err 1..2: expected `.`, `=`")
  check_parse("\\U0001F600\"", "err 0..1: invalid key")
  check_parse(
    "true{c.d\"\"\"0b1\u{7f}'l' 1979-05-27x = 1\n", "err 4..5: expected `.`, `=`",
  )
  check_parse("false[\u{0}=[[t]]\n0b10o70b1\n", "err 5..6: expected `.`, `=`")
  check_parse("true\\ = _=infc.d,", "err 4..5: expected `.`, `=`")
  check_parse("'''0b1_+0o7\u{0}", "err 2..3: expected `.`, `=`")
  check_parse("b1e5]]1e5 \t\\u00e9", "err 4..5: expected `.`, `=`")
  check_parse("\"\"\"Etrux = 1\n1.5+}", "err 2..3: expected `.`, `=`")
  check_parse("]tru\r\n+01:00trua.b = 2\n", "err 0..1: invalid key")
  check_parse(
    ".+01:00\\x[[\u{7f}-'l'-\n = 'l'a.b = 2\n", "err 0..1: invalid key",
  )
  check_parse(
    "\u{1}\u{7f}infa.b = 2\n{x = 1\n+01:00bZ", "err 0..1: invalid key",
  )
  check_parse("\\x{T Ttru\\U0001F60000x1F", "err 0..1: invalid key")
  check_parse("\\U0001F600tru", "err 0..1: invalid key")
  check_parse("]][\\U0001F600 ", "err 0..1: invalid key")
  check_parse("true}\u{0}\u{7f}b1", "err 4..5: expected `.`, `=`")
  check_parse("=\\U0001F600]][[t]]\n'.5\u{4e2d}#0b1_", "err 0..1: invalid key")
  check_parse("{nan# c\n", "err 0..1: invalid key")
  check_parse(
    "x.y.z = 1\nx.w = \"s\"x.v]\nq [[t]]\n= 2\n", "err 19..20: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\"[[t]]\n\nmtruel\\\n str\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"[[t]]\\n\\nmtruelstr\", \"l\": \"lit\"}",
  )
  check_parse(
    "x.y.z = 1\nx.w= \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:0Z\n",
    "err 67..68: invalid date-time",
  )
  check_parse(
    "n = [0x1F, a.b = 2\n0o7, 0b1, 1_000, -1.5e-3,inf, nan]\n", "err 11..12: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"\"\n[x}.v]\nq 1e5= 2\n", "err 21..22: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "a = 1\nb= = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[\r[arr]]\ne = 1979-05-27T07:32:00\n",
    "err 9..10: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n:", "err 47..48: invalid key",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00\\n0, -1.5-3, inf, nan]\n", "err 25..26: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F 0o7,\"\"\" 0b1, 1_.00, -1.5e-3, inf, nan]\n", "err 10..11: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0\u{e9}x1inf 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 6..8: invalid array\nexpected `]`",
  )
  check_parse(
    " = \"\"\"\nml\\\n  str\"\"\"\nl = '''lt'''\n", "err 1..2: invalid key",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\nl ='''lit''\n", "err 32..32: invalid multiline basic string",
  )
  check_parse(
    "x.y.z k = {x = 1}\n= 1\nx.w = \"s\"[x.v]\nq = 2\n", "err 6..7: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1,+01:00 1_000, -1.5e-3true inf, nan]\u{4e2d}\n", "err 22..23: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w =- \"s\"\n[x.v]\nq = 2\n", "err 16..17: invalid integer",
  )
  check_parse(
    "a =1\nb= \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "ok {\"a\": 1, \"b\": \"x\", \"t\": {\"c\": [1, 2, {\"d\": 3}]}, \"arr\": [{\"e\": D(1979-05-27T07:32:00Z)}]}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"0b1\"\nl = Z'lit'''\n", "err 36..36: invalid multiline basic string",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.vfalse]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"vfalse\": {\"q\": 2}}}",
  )
  check_parse(
    "x.y.0b1 = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"0b1\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan\r\n\n", "err 48..48: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1000, -1.5e-3, inf, nan]\n", "ok {\"n\": [31, 7, 1, 1000, -0.0015f, inff, NaNf]}",
  )
  check_parse(
    "n = [0x}1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 7..8: invalid hexadecimal integer",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl =a.b = 2\n '''lit'''\n", "err 24..25: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n str\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"mlstr\", \"l\": \"lit\"}",
  )
  check_parse(
    "x.y.z =a.b = 2\n 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "err 7..8: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "x.y.z = \nx.w = \"s\"\n[x.v]\nq = 2\n", "err 8..9: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "x.y.z = 1\nx.w =\u{0} \"s\"\n[x.v]\nq = 2\n", "err 15..16: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "a = 1\nb = \"\"\n[t]\nc = [1, 2 {d = 3}]\n[[arr]]\ne = 1979-05-27T]07:32:00Z\n",
    "err 27..28: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[xZv]\nq = \n", "err 30..31: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]", "ok {\"n\": [31, 7, 1, 1000, -0.0015f, inff, NaNf]}",
  )
  check_parse(
    "a = 1\nb = \"x\"\t[t]\nc = [1, 2, {d = 3}]\n[arr]]\ne = 1979-05-27T07:32:0Z\n",
    "err 14..15: expected newline, `#`",
  )
  check_parse(
    "n = [0a.b = 2\nx1F, 0o7, 0b1, 1_000, -1.5e-3, inf, naEn]\n", "err 6..7: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.Zv]'\nq = 2\n", "err 26..27: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "x.y.z = 1x.w = \"s\"\n[x.v]\nq = 2\n", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = \\U0001F6001979-05-27T07:32:00Z\n",
    "err 50..51: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = k = [1, 2]\n1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 22..23: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-E5-27T07:32:00Z\n",
    "err 55..56: invalid date-time",
  )
  check_parse(
    "n = [0x1F, 0o7,T 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 15..16: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -.5e-3, [t]\ninf, nan]\n", "err 28..29: invalid array\nexpected `]`",
  )
  check_parse(
    "s =\"\"\"\nml\\\n  st#r\"\"\"\nl = ''c.dlit'''\n", "err 27..28: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\"\nm\\\n  str\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"mstr\", \"l\": \"lit\"}",
  )
  check_parse(
    "n\\u00e9 = [t]\n0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o7,a.b = 2\n0b1, 1_00b100, -1.5e-3, i:nf, nan]\n", "err 15..16: invalid array\nexpected `]`",
  )
  check_parse(
    "n = 0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 8..9: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 9..10: expected `.`, `=`",
  )
  check_parse(
    "x.y.z= 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 5..6: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\"q k\"\nb = \"x\"\n[t]\nc = [1, 2, {d = \u{7f}}]\n[[arr]]\ne = 1979+01:00-05-27T07:32:00Z\n",
    "err 5..6: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0inf1, 1_000, -1.5e-3, inf, nan]\n", "err 17..18: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5-, inf, nan]\n", "err 32..33: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b,1+01:00, 1_000, -1.5e-3, inf, nan]\n", "err 18..19: invalid binary integer",
  )
  check_parse(
    "n= [0x1F, 0o7, 0b1, 1_000, -1.5e-3\u{7f}, inf, nan]\n0o7", "err 34..35: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z =_1\nx.w = \"s\"0x1F\n[x.v]\nq = 2\n", "err 7..8: invalid integer\nexpected leading digit",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2\u{e9}", "err 31..33: expected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27infT07:32:0Z\n",
    "err 60..61: expected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1,= 2, {d =[t]\n 3}]\n[[arr]]\ne = 1979-05-7T07:32:00Z\n",
    "err 25..26: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"k = [1, 2]\nx\"\n[t]\nc = [1, 2, {d = 3}]\n[[a\\xrr]]\ne = 179-05-27T07:32:00Z\n",
    "err 21..22: invalid basic string",
  )
  check_parse(
    "s   \"\"\"0o7\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 4..5: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1x.w = \"s\"\n[x.v]\nq = 2\n", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3,=in, nan]\n", "err 36..37: invalid array\nexpected `]`",
  )
  check_parse(
    "s1.5 = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "ok {\"s1\": {\"5\": \"mlstr\"}, \"l\": \"lit\"}",
  )
  check_parse(
    "n = [0x1F, o7, 0b1, 1_000,=-1.5e-3, inf, nan]\n", "err 11..12: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\n''' = [1, 2, {d = 3}]\n[[arr]][[t]]\ne = 1979\\05-27T07:32:00Z\n",
    "err 20..21: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.]\nq = 2\n", "err 22..23: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "n = [0x1Fa.b = 2\n, 0o, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 10..11: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1a.5e-3, inf, nan]\n", "err 30..31: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o07:32:007, 1e50b1, 1_000, -1.5e-3, inf, nan]\n", "err 15..16: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-\"q k\"27T07:32:00Z\n",
    "err 16..17: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "n = [0\\u00e91F, 0\r\no7 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 6..7: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T0732:00Z\n",
    "err 60..61: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3\"q k\" inf nan]\n", "err 35..36: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = \nx.w = \"s\"\n[x.v]\r\n\nq = 2\n", "err 8..9: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \r\"\\ns[[\"\n[x.v]\nq = 2\n", "err 16..17: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "s\r\n = \"\"\"\nml\\\n  str\"\"\nl\r\n = '''lit'''\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t+01:00]\nc = [1, 2, {d = 3}]\n[[arr]]\ne  1979-05-27T07:32:00Z\n",
    "err 16..17: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5-3, inf, nan]\n", "err 32..33: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 10..11: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "s tru\"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 2..3: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''tru\n", "err 34..35: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl-= '''lit'''\n", "ok {\"s\": \"mlstr\", \"l-\": \"lit\"}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  \"\"\"tr\"\"0o7\nl = '''lit'''", "err 17..18: expected newline, `#`",
  )
  check_parse(
    "+s = \"\"\"\nml\\\n s\nr\"\"\"\nl = '''lit'''\n", "err 0..1: invalid key",
  )
  check_parse(
    "s = \"\"\nml\\\n str\"\"\"\nl = '''lit'''\n", "err 9..10: expected `.`, `=`",
  )
  check_parse(
    "x..5y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[1e5[ar]]\ne = 1979-05-27T07:\\x2:00Z\n",
    "err 42..43: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[\u{e9}t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 15..17: invalid key",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc =\t [, 2, {d = 3}]\n[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 24..25: invalid array\nexpected `]`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  ste\"\"\nl = '''lit'''\n", "err 34..34: invalid multiline basic string",
  )
  check_parse(
    "a = 1\nb =\"x\"\n[t]\nc = [1, 2, {d = 3}]\n[arr]]\ne = 1979-0-27T07:32:00Z\n",
    "err 42..43: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "a =1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "ok {\"a\": 1, \"b\": \"x\", \"t\": {\"c\": [1, 2, {\"d\": 3}]}, \"arr\": [{\"e\": D(1979-05-27T07:32:00Z)}]}",
  )
  check_parse(
    "\"q k\".y.z = 1\nx.w}= \"s\"\n[x.v]\nq = 2\n", "err 17..18: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]c = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 17..18: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3]\n[[arr]]\ne = 979-05-27T07:32:00\n",
    "err 35..36: invalid inline table\nexpected `}`",
  )
  check_parse(
    "n = [0x1F, 0o7, 01, 1_000, -1.5e\u{4e2d}-3, inf, nan]\n", "err 17..18: invalid array\nexpected `]`",
  )
  check_parse(
    "n0b1 = [0x1F, 0o7, 0b1, 1_00, -1.5e-3, inf nan]\n", "err 43..44: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\nx.v]\nq = 2\n", "err 23..24: expected `.`, `=`",
  )
  check_parse(
    "n = 'l'[0xZ1F, 0o7, 0b1, 1_000, -1.5e-3, [t]\ninf, nan]\n", "err 7..8: expected newline, `#`",
  )
  check_parse(
    "s  \"\"\"\nml\\\n  str\"\"\"0x1F\nl = '''lit''\n", "err 3..4: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''k = {x = 1}\n\n", "err 34..35: expected newline, `#`",
  )
  check_parse(
    "x.y.z= 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]bq = 2\n", "err 25..26: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "x.\\u00e9y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o\r7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 13..14: invalid octal integer",
  )
  check_parse(
    "n = 0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 8..9: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5\\u00e9e-3,inf, nan]\n", "err 32..33: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00, -1.5e-3, nf, nan]\n", "err 36..37: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]\ne = 1979-05-27T07:32:00Z\n",
    "err 43..44: invalid table header\nexpected `.`, `]]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -.e-3, inf, nan]\n", "err 28..29: invalid array\nexpected `]`",
  )
  check_parse(
    "a = \nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:0nan0Z\n",
    "err 4..5: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "x.y.z = 1\n0o7x.w = \"s\"\n[x.]\nq\u{0} = 2\n", "err 25..26: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\nl = '''lit'''\n", "err 34..34: invalid multiline basic string",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]{\n[[arr]]\ne = 1979-05-27T07:3'''2:00Z\n",
    "err 37..38: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00\\x0, -1.5e-3, inf, \rnan]\n", "err 25..26: invalid array\nexpected `]`",
  )
  check_parse(
    "n ['l'x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 2..3: expected `.`, `=`",
  )
  check_parse(
    "xtrue.y.z = 1\nx.w ''' \"s\"\n[x.v]\nq = true2\n", "err 18..19: expected `.`, `=`",
  )
  check_parse(
    "s =\"\"\"\nml1\n  str\"\"\"\nl = '''lit''\n", "err 33..33: invalid multiline literal string",
  )
  check_parse(
    "k = [1, 2]\na = 1b = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 16..17: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq= 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n07:32:00 str\"\"\"\nl = ''lit''\\U0001F600\n", "err 34..35: expected newline, `#`",
  )
  check_parse(
    "n= [0x1F, 0o7, 0b1, 1_000, 1.5e-3, inf, nan]\n", "ok {\"n\": [31, 7, 1, 1000, 0.0015f, inff, NaNf]}",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000,-1.5e-3, inf, nan]\n", "ok {\"n\": [31, 7, 1, 1000, -0.0015f, inff, NaNf]}",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x\u{e9}v]\n1.5q = 2\n", "err 22..24: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "n = [0x1F, 0o7 0b1, 1k = [1, 2]\n_00, -1.5e-3, inf, nan]\n", "err 15..16: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d ]]= 3}]\n[[arr]]\ne =1979-05-27T07:32:00Z\n",
    "err 32..33: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o7 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 15..16: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 11..12: invalid array\nexpected `]`",
  )
  check_parse(
    "n =[0x1F, 0o7, 0b1, 1_000, -1.5e-'3, inf, nan]\"q k\"\n", "err 33..34: invalid floating-point number",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"Zl = '''it'''\n", "err 33..33: invalid multiline basic string",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1\\u00e9000, -1.5e-3, nf, nan\\u00e9\n", "err 22..23: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[07:32:00.v]\nq = 2\n", "err 23..24: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\n\tc = [1, 2, {d = 3}]\n[[}arr]]\ne = 1979-05-27T07:3200Z\n",
    "err 41..42: invalid key",
  )
  check_parse(
    "x.y.z = 1\n[x.w = \"s\"\n[x.v]\nq = 2\n", "err 15..16: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "n \"q k\"= [0x1F, 0o7, 0b1, 1_000, -1.e-3, inf, nan]\n", "err 2..3: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nm\\\n  str\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"mstr\", \"l\": \"lit\"}",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5\\ne-3, \u{7f}nf, nan]\n", "err 32..33: invalid array\nexpected `]`",
  )
  check_parse(
    "s =\u{1} \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 3..4: invalid string\nexpected `\"`, `'`",
  )
  check_parse(".y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "err 0..1: invalid key")
  check_parse(
    "x.y.z = 1\nx..5w = \"s\"\n[x.v]\nq = 2", "err 11..12: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"l =+01:00'''lt'''\n", "err 20..21: expected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]c.d]\ne 1e5= 197905-27T07:32:00Z\n",
    "err 43..44: invalid table header\nexpected `.`, `]]`",
  )
  check_parse(
    "a = 1\n\\xb = \"#x\"\n[t]\nc = [1, 2, {d = 3}]\n[[+01:00rr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 6..7: invalid key",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\nfalse",
    "err 76..76: expected `.`, `=`",
  )
  check_parse(
    "x..z = 1\nx.w = \"s\":\n[x.v]\nq = 2\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "x.+01:00y.z = 1\nx.w = \"s\"\n[x.v]\nq = +2:", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\n# c\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00'l'0, -1.5e-3, in]]f, nan]\n", "err 25..26: invalid array\nexpected `]`",
  )
  check_parse("\r = \"\"\"\nml\\\n  str\"\"\nl = '''lit'''\n", "err 0..1: ")
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -.5e-3, inf, nan]\n", "err 28..29: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w  \"s\"\n[x.v]\nq = 2\n", "err 15..16: expected `.`, `=`",
  )
  check_parse(
    "a = \t\nb = \"x\"\n[t]\n\t = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 5..6: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2,{d = 3}]\n[[arr]]\ne = 1979-05-27T07{32:00Z\n",
    "err 59..60: expected newline, `#`",
  )
  check_parse(
    "s =0x1F\"\"\"\nml\\\n  str\"\"\" = \nl = {''lit'''\n", "err 7..8: expected newline, `#`",
  )
  check_parse(
    "a = 1\n0o7b = \"\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "ok {\"a\": 1, \"0o7b\": \"\", \"t\": {\"c\": [1, 2, {\"d\": 3}]}, \"arr\": [{\"e\": D(1979-05-27T07:32:00Z)}]}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  tr\"\"\"\nl ='''lit'''\n", "ok {\"s\": \"mltr\", \"l\": \"lit\"}",
  )
  check_parse(
    "x.y.z [[ 1\nx.w = \"s\"\n[x.\\x]\nq = 2\"q k\"", "err 6..7: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl  '''lit'''\n", "err 24..25: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1a\nx.w\u{7f} = \"s\"\n[x.v]\nq = 2\n", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\"trueml\\\n  str\"\"\"\nl = '\\U0001F600'lit'''\n", "err 40..41: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n st\"\"\"\nl = '''lit''\n", "err 32..32: invalid multiline literal string",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit['''\n", "ok {\"s\": \"mlstr\", \"l\": \"lit[\"}",
  )
  check_parse(
    "n = [Ex1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 5..6: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F 0o7, 0b1, 1_000, -\"\"\".5e-3, inf, nan]\n", "err 10..11: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "s= \"\"\"\nml\\\n  st[[r\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"mlst[[r\", \"l\": \"lit\"}",
  )
  check_parse(
    "n}= [0x1F, 0o7, 0b1, 1_000, -1.5e-, inf, nan\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nqT = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"qT\": 2}}}",
  )
  check_parse(
    "true.y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"true\": {\"y\": {\"z\": 1}}, \"x\": {\"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  stE\"\"\"\nl\\u00e9 = ''lit'''\n", "err 22..23: expected `.`, `=`",
  )
  check_parse(
    "xy. = 1\nx.w = \"s\"\n[x.v]\nq = 1.5\n", "err 2..3: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq \\n 2\n", "err 28..29: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx = 1\n.w = \"s\"\n[x.v]:\nq = 2\n", "err 10..11: duplicate key `x` in document root",
  )
  check_parse(
    "x.y.z = \nx.w = \"s\"[x.v]\nq = 2\n", "err 8..9: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "s = \"\"\"\na.b = 2\nml\\\n  str\"\"\nl = '''lit'''\n", "err 42..42: invalid multiline basic string",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T071e52:00Z\n",
    "err 60..61: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1x.w = nan\"s\"\n[x.v]\nq = 2\n", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "n  [0x1F, 0o70b1 0b1, 1_000, -1.Z5e-3, inf, nan]\n", "err 3..4: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"inf[tfalse\nc = [1, 2, {d = 3}]\n[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 13..14: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[0.v]\nq = 2", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\"}, \"0\": {\"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [0x1F,E0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 10..11: invalid array\nexpected `]`",
  )
  check_parse(
    "x.\ty.z = 1\nx.w = \"s \"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s \", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [0x1F, 0o7 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 15..16: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o\n7, 0b1,.5 1_000, -1.5e-3, in, nan]\n", "err 13..14: invalid octal integer",
  )
  check_parse(".y.z = 1\nx.w = \"s\"\n[x.v]q = 2\\", "err 0..1: invalid key")
  check_parse(
    "s = \"\"\"\nml\\\\x\n  str\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"ml\\\\x\\n  str\", \"l\": \"lit\"}",
  )
  check_parse(
    "n =+ [01F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 4..5: invalid integer",
  )
  check_parse(
    "x.by.z = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"by\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl ='''lit'''\n", "ok {\"s\": \"mlstr\", \"l\": \"lit\"}",
  )
  check_parse(
    "s = \"\"\"\nml\\\n str\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"mlstr\", \"l\": \"lit\"}",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00a0, -1.5}e-3,''' inf, nan]\n", "err 25..26: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc  [1, 2, {d = 3}]\n[[arr]]\ne = .1979-05nan-27T07:32:00Z\n",
    "err 21..22: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'Z''\n", "err 36..36: invalid multiline literal string",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"''']\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"''']\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "xy.z = 1\nxw = \"s\n[x.v]\nq = 2\n", "err 16..17: invalid basic string",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2,{d =3]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 33..34: invalid inline table\nexpected `}`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T070x1F32:00Z\n",
    "err 60..61: expected newline, `#`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str_\"\"\nl1.5 = '''lit'''\n", "err 38..38: invalid multiline basic string",
  )
  check_parse(
    "n = 0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 8..9: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, - .5e-3, inf, nan]\n", "err 28..29: invalid array\nexpected `]`",
  )
  check_parse(
    "x = 1\n = \"\"\"\nml\\\n  str\"\"\"\nl = ''\\u00e9lit'''\n", "err 7..8: invalid key",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, i.nf, nan]+01:00\n", "err 37..38: invalid array\nexpected `]`",
  )
  check_parse(
    "s = \"]]\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 11..12: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl =''#'lit'''\n", "ok {\"s\": \"mlstr\", \"l\": \"\"}",
  )
  check_parse(
    "x.y.z = 1\nx.w \u{7f} \"s\"\n[x.v]\nq = 2\n", "err 14..15: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nn]\n", "err 42..43: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]\ne =\u{7f} 1979-05{27T07:32:00Z\n",
    "err 43..44: invalid table header\nexpected `.`, `]]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "x.y.z =1\nx.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne= 1979-05-27T07:32:00Z\n",
    "ok {\"a\": 1, \"b\": \"x\", \"t\": {\"c\": [1, 2, {\"d\": 3}]}, \"arr\": [{\"e\": D(1979-05-27T07:32:00Z)}]}",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"]\n[x.v]\nq = 2\n", "err 19..20: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nex.w = \"s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"v\": {\"q\": 2}}, \"ex\": {\"w\": \"s\"}}",
  )
  check_parse(
    "x.y.z = 1\nx.]] = \"s\"\n[x.v]\nq = 2\n", "err 11..12: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00\u{0}0, -1.5e-3, inf, nan]\n", "err 25..26: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.- = 1x.w= \"s\"\n[x.v]\nq = 2\n", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1=\nx.w = \"s\"\n[xtruv]\nq = 2", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "n = [0x1#F, 0o7, 0b1, 1_000, -1.5e-3''' inf, nan]\n", "err 50..50: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, ,1_000,-+01:001.5e-3, inf, nan]\n", "err 21..22: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne\u{4e2d}= 1979-05-27T07:32:00Z\n",
    "err 47..50: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\u{7f}\nx.w = \"s\"\n[x.v]\nq =tru 2", "err 9..10: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nx.w  \"s\"\n[x.v]\nq = 2\n", "err 15..16: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 20x1F, [[t]]\nd = 3}]\n[[arr]]\ne = 1979-05-27T007:32:007:32:00Z\n",
    "err 28..29: invalid array\nexpected `]`",
  )
  check_parse(
    "\u{e9}.yz = 1\nx.w = \"s\"\n\\n[x.v]\nq = 2\n", "err 0..2: invalid key",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  s{tr\"\"\"\nl = '''lit''\n", "err 35..35: invalid multiline literal string",
  )
  check_parse(
    "n\u{0} = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  sbtr\"\"\"\nl = ''it'''\n", "err 28..29: expected newline, `#`",
  )
  check_parse(
    "a = [\nb = \"x\"\n[t]\nc = [1,0b1 2, {d = 3}]\n[[arr]]\ne = 1979-}5-27T07:32:00Z\n",
    "err 6..7: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 10..11: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [ = 0x1F, 0o7, 0b1, 1000, -1.5e-3, inf, n\u{7f}n]\n", "err 6..7: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1{5e-3, inf, nan]\n", "err 30..31: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[0x1Fx.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \"s\"}, \"0x1Fx\": {\"v\": {\"q\": 2}}}",
  )
  check_parse(
    "n = [0x1F, 0o, 0b1, 1_000, -1.5e-3,0'l'nf, nan]\n", "err 13..14: invalid octal integer",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit''\u{e9}'\n", "err 37..37: invalid multiline literal string",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]c = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 17..18: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "s = \"1979-05-27\"\nml\\\n\u{4e2d} str\"\"\"\nl = '''lit'''\n", "err 19..20: expected `.`, `=`",
  )
  check_parse(
    " = 1\nb = \"x\"\n[t]\nc = [1, 2T, {d = 3}]\n[[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 1..2: invalid key",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf,na]\n", "err 41..42: invalid array\nexpected `]`",
  )
  check_parse(
    "s\u{4e2d} = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 1..4: expected `.`, `=`",
  )
  check_parse(
    "s  \"-\"\"\nml\\\n  str\"\"\"\nl = '''lit'''e", "err 3..4: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 199-05-27T07:32:00Z\n",
    "err 53..54: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_00, -1.5e-3, inf, nan]\n", "ok {\"n\": [31, 7, 1, 100, -0.0015f, inff, NaNf]}",
  )
  check_parse(
    "n = [0x1F, 0o7\\u00e9, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 14..15: invalid array\nexpected `]`",
  )
  check_parse(
    "\u{1} = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 0..1: invalid key",
  )
  check_parse(
    "x.y.- = 1.5x.w = \"s\"\n[x.v]\nq = 2\n", "err 11..12: expected newline, `#`",
  )
  check_parse(
    "x.y.z = E\t1\nx.w = \"s\"\n[.v]\nq = 2\n", "err 8..9: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "b = \\u00e9\"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 4..5: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000,\\x -1.5e-3, inf, nn]\n", "err 27..28: invalid array\nexpected `]`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\nl = '''li'''\n", "err 33..33: invalid multiline basic string",
  )
  check_parse(
    "-.ya.\u{4e2d}z = 1\nx.w = \"s\"\n[x.v]\nq = 2\n", "err 4..5: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx]].w E= \"s\"\n[x.v]Zq = 2\n", "err 11..12: expected `.`, `=`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, d = 3}]\n[[arr]\ne = 1979-05-27T07:32:00Z\n",
    "err 29..30: invalid array\nexpected `]`",
  )
  check_parse(
    "n = [trux1F 0o7, 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 5..6: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "x.y.+z = 1\nx.w = \"s\"\n[x.v]\nq= 2\u{e9}\n", "err 3..4: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl \\u00e9= '''lit' = ''\n", "err 23..24: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x\\xx = 1\n.v]\nq = 2\n", "err 22..23: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  :tr\"\"\"\nl = '''lit'''\n", "ok {\"s\": \"ml:tr\", \"l\": \"lit\"}",
  )
  check_parse(
    "x.y.z = 1\nx.w = \" s\"\n[x.v]\nq = 2\n", "ok {\"x\": {\"y\": {\"z\": 1}, \"w\": \" s\", \"v\": {\"q\": 2}}}",
  )
  check_parse(
    "x.y.z =1\nx.w = \"s\"x.v]\nq = 2\n", "err 18..19: expected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq -]=1979-05-272\n", "err 28..29: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"\"\n[[t]]\nml\\\n = str\"\"\"\nl =\\u00e9'''lit'''\n", "err 31..32: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "s = \"\"\"\nml\\\n str\"\"\"\nl  '''lit''\n", "err 23..24: expected `.`, `=`",
  )
  check_parse(
    "n = [0x1F, 0o7,0b1, 1_000 -1.5e-=3, inf, nan]\n", "err 26..27: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z] = 1\nx.w = s\"\n[[.v]\nq = 2\n", "err 5..6: expected `.`, `=`",
  )
  check_parse(
    "a = 1\u{e9}\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 199-05-27T07:32:00Z\n",
    "err 5..7: expected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\nZ\u{7f}[[rr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 39..40: expected `.`, `=`",
  )
  check_parse(
    "s = \"\"'-\"b\nml\\\n  str\"\"\"\nl = '''lit'''\n", "err 6..7: expected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o\"\"\", 0b1, 1_000, -1.5e-3, inf, nan]\n", "err 13..14: invalid octal integer",
  )
  check_parse(
    "s = \"\"\"\nml\\\n 07:32:00 str\"\"\"\nl = '''l[[t]]\nit'''\n", "ok {\"s\": \"ml07:32:00 str\", \"l\": \"l[[t]]\\nit\"}",
  )
  check_parse(
    "a =1\nb = \"x\"\n[t]\nc = [1, 2\\, {d = 3}]\n[\\x[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 26..27: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]q = 1e5\n", "err 25..26: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "s = \"\"\"#\nml\\\n  str\"\"\"\nl = '''littru''\n", "err 38..38: invalid multiline literal string",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.Z]\n  2\n", "err 29..30: expected `.`, `=`",
  )
  check_parse(
    "n = ]]0x1F, 0o7, 0b1, 1_000, -1.5e3, inf, nan]\n", "err 4..5: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]c = [1, 2\u{4e2d}, {d = 3}]\n[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 17..18: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000,\"\"\" -1.5e-3, inf, falsenan]\n", "err 55..55: invalid multiline basic string",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''l\u{1}it'''\n", "err 29..30: invalid multiline literal string",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"1.5\nl = ''lt'''\n", "err 20..21: expected newline, `#`",
  )
  check_parse("x.y.z = 1\n.w = \"s\"\nx.v]\nq = :\n", "err 10..11: invalid key")
  check_parse(
    "a = 1\nb = \"x\"\n[t]c = 07:32:00[1, 2, {d = 3}]\n[[arr]]\ne = 197905-27T07:32:00Z\n",
    "err 17..18: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s#\n[x.v]q = 2\n", "err 19..20: invalid basic string",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3 inf, nan]\n\\", "err 36..37: invalid array\nexpected `]`",
  )
  check_parse(
    "x.y.z = 1\n\\u00e9x.w = \"s\"\n[x.v]\nq = 2\n", "err 10..11: invalid key",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]0o7\ne = 1979-05-27T07:32:00Z\n",
    "err 45..46: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}\"\"\"]\n[[arr]]\ne = 1979-0527T07:32:00Z\n",
    "err 36..37: invalid array\nexpected `]`",
  )
  check_parse(
    "s = \"'l'\"\nml\\\n  str\"true\nl = '''lit'''\n", "err 12..13: expected `.`, `=`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v\nq = 2\n", "err 24..25: invalid table header\nexpected `.`, `]`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b, 1_000, -1.5e-3, inf, nan]\n", "err 18..19: invalid binary integer",
  )
  check_parse(
    "s = \"\"\"\nml\\\n  str\"\"\"\nl = '''lit'''c.d\n", "err 34..35: expected newline, `#`",
  )
  check_parse(
    "n = [01F, 0o7, 0b1, 1_000, -\"q k\".5e-3, inZf, nan]\n", "err 6..7: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"\"\"\"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]:]\ne = 1979-05-27T07:32:00Z\n",
    "err 75..75: invalid multiline basic string",
  )
  check_parse(
    " = [0x1F, 0o7, 0b1,1_000, -1.5-3, inf, nan]\n", "err 1..2: invalid key",
  )
  check_parse(
    "a = 1\nb = \"\"\n[t]\nc = [1, 2, {d = 3}]\n[[arr]]\ne = 1979-051e5-27T07:32:00Z\n",
    "err 56..57: invalid date-time",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1\"000, -1.5e-3, inf, nan]\n", "err 22..23: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[[ar\r\nr]]\n = 1979-05-27T07:32:00Z\n",
    "err 42..43: invalid table header\nexpected `.`, `]]`",
  )
  check_parse(
    "x..z = 1\n.w = \"s\"\nx.v]\nq = 2\n", "err 1..2: expected `.`, `=`",
  )
  check_parse(
    "s = \u{4e2d}\"\"\"\nml\\\n  str\"\"\"\nl = '''lit1979-05-27k = [1, 2]\n'''\n",
    "err 4..7: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "n = [0x1F, 0o7, 0b1, 1_000, -1.5e-3, inf, n]n]\n", "err 42..43: invalid array\nexpected `]`",
  )
  check_parse(
    "a = 1\nb = \"x\"\n[t]\nc = [1, 2, {d = 3}]\n[arr]]\ne = 1979-05-27T07:32:00Z\n",
    "err 43..44: invalid table header\nexpected newline, `#`",
  )
  check_parse(
    "x.y.z = \u{e9}1\nx.w = \"s\"\n[x.v]\nq = 2\n", "err 8..10: invalid string\nexpected `\"`, `'`",
  )
  check_parse(
    "x.y.z = 1\nx.w = \"s\"\n[x.v]\nq = 2Z\n", "err 31..32: expected newline, `#`",
  )
}
