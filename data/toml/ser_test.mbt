///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: toml.encode" {
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("a", Int(1L))]), true, "a = 1\n")
  check_ser(Map([("a", Int(1L))]), false, "a = 1\n")
  check_ser(
    Map([
      ("a", Int(1L)),
      ("b", Seq([Int(1L), Int(2L)])),
      ("c", Map([("x", Int(1L)), ("y", Map([("z", Str("q"))]))])),
      ("d", Seq([Map([("k", Int(1L))]), Map([("k", Int(2L))])])),
      ("e", Map([])),
      ("f", Float(1.5)),
      ("g", Str("it's")),
      ("h", Str("a\"b")),
      ("i", Str("a\nb")),
    ]),
    true,
    "a = 1\nb = [\n    1,\n    2,\n]\nf = 1.5\ng = \"it's\"\nh = 'a\"b'\ni = \"\"\"\na\nb\"\"\"\n\n[c]\nx = 1\n\n[c.y]\nz = \"q\"\n\n[[d]]\nk = 1\n\n[[d]]\nk = 2\n\n[e]\n",
  )
  check_ser(
    Map([
      ("a", Int(1L)),
      ("b", Seq([Int(1L), Int(2L)])),
      ("c", Map([("x", Int(1L)), ("y", Map([("z", Str("q"))]))])),
      ("d", Seq([Map([("k", Int(1L))]), Map([("k", Int(2L))])])),
      ("e", Map([])),
      ("f", Float(1.5)),
      ("g", Str("it's")),
      ("h", Str("a\"b")),
      ("i", Str("a\nb")),
    ]),
    false,
    "a = 1\nb = [1, 2]\nf = 1.5\ng = \"it's\"\nh = 'a\"b'\ni = \"\"\"\na\nb\"\"\"\n\n[c]\nx = 1\n\n[c.y]\nz = \"q\"\n\n[[d]]\nk = 1\n\n[[d]]\nk = 2\n\n[e]\n",
  )
  check_ser(Map([("a", None)]), true, "")
  check_ser(Map([("a", None)]), false, "")
  check_ser(
    Map([("a", Seq([Int(1L), None]))]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([("a", Seq([Int(1L), None]))]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([("a", Map([("b", None), ("c", Int(1L))]))]),
    true,
    "[a]\nc = 1\n",
  )
  check_ser(
    Map([("a", Map([("b", None), ("c", Int(1L))]))]),
    false,
    "[a]\nc = 1\n",
  )
  check_ser(Map([("a", Seq([Map([("b", None)])]))]), true, "[[a]]\n")
  check_ser(Map([("a", Seq([Map([("b", None)])]))]), false, "[[a]]\n")
  check_ser(
    Map([("a", Seq([Seq([None])]))]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([("a", Seq([Seq([None])]))]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("a", Seq([Int(1L), Seq([Int(2L), Int(3L)]), Seq([]), Seq([Int(4L)])])),
    ]),
    true,
    "a = [\n    1,\n    [\n    2,\n    3,\n],\n    [],\n    [4],\n]\n",
  )
  check_ser(
    Map([
      ("a", Seq([Int(1L), Seq([Int(2L), Int(3L)]), Seq([]), Seq([Int(4L)])])),
    ]),
    false,
    "a = [1, [2, 3], [], [4]]\n",
  )
  check_ser(
    Map([("a", Seq([Seq([Int(1L), Int(2L)]), Seq([Int(3L), Int(4L)])]))]),
    true,
    "a = [\n    [\n    1,\n    2,\n],\n    [\n    3,\n    4,\n],\n]\n",
  )
  check_ser(
    Map([("a", Seq([Seq([Int(1L), Int(2L)]), Seq([Int(3L), Int(4L)])]))]),
    false,
    "a = [[1, 2], [3, 4]]\n",
  )
  check_ser(Map([("a", Seq([Int(1L)]))]), true, "a = [1]\n")
  check_ser(Map([("a", Seq([Int(1L)]))]), false, "a = [1]\n")
  check_ser(Map([("a", Seq([]))]), true, "a = []\n")
  check_ser(Map([("a", Seq([]))]), false, "a = []\n")
  check_ser(
    Map([("a", Seq([Map([("x", Int(1L))]), Int(2L)]))]),
    true,
    "a = [\n    { x = 1 },\n    2,\n]\n",
  )
  check_ser(
    Map([("a", Seq([Map([("x", Int(1L))]), Int(2L)]))]),
    false,
    "a = [{ x = 1 }, 2]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([Int(2L), Map([("x", Int(1L)), ("y", Seq([Int(1L), Int(2L)]))])]),
      ),
    ]),
    true,
    "a = [\n    2,\n    { x = 1, y = [\n    1,\n    2,\n] },\n]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([Int(2L), Map([("x", Int(1L)), ("y", Seq([Int(1L), Int(2L)]))])]),
      ),
    ]),
    false,
    "a = [2, { x = 1, y = [1, 2] }]\n",
  )
  check_ser(Map([("a", Seq([Map([])]))]), true, "[[a]]\n")
  check_ser(Map([("a", Seq([Map([])]))]), false, "[[a]]\n")
  check_ser(Map([("a", Seq([Map([]), Map([])]))]), true, "[[a]]\n\n[[a]]\n")
  check_ser(Map([("a", Seq([Map([]), Map([])]))]), false, "[[a]]\n\n[[a]]\n")
  check_ser(
    Map([("a", Map([("b", Map([("c", Map([]))]))]))]),
    true,
    "[a.b.c]\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([("c", Map([]))]))]))]),
    false,
    "[a.b.c]\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([("c", Map([("d", Int(1L))]))]))]))]),
    true,
    "[a.b.c]\nd = 1\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([("c", Map([("d", Int(1L))]))]))]))]),
    false,
    "[a.b.c]\nd = 1\n",
  )
  check_ser(
    Map([
      ("a", Map([("b", Int(1L)), ("c", Map([("d", Int(2L))]))])),
      ("e", Int(3L)),
    ]),
    true,
    "e = 3\n\n[a]\nb = 1\n\n[a.c]\nd = 2\n",
  )
  check_ser(
    Map([
      ("a", Map([("b", Int(1L)), ("c", Map([("d", Int(2L))]))])),
      ("e", Int(3L)),
    ]),
    false,
    "e = 3\n\n[a]\nb = 1\n\n[a.c]\nd = 2\n",
  )
  check_ser(
    Map([("t", Map([("x", Int(1L))])), ("v", Int(2L))]),
    true,
    "v = 2\n\n[t]\nx = 1\n",
  )
  check_ser(
    Map([("t", Map([("x", Int(1L))])), ("v", Int(2L))]),
    false,
    "v = 2\n\n[t]\nx = 1\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Map([("b", Seq([Map([("c", Int(1L))]), Map([("c", Int(2L))])]))]),
          Map([("b", Seq([]))]),
        ]),
      ),
    ]),
    true,
    "[[a]]\n\n[[a.b]]\nc = 1\n\n[[a.b]]\nc = 2\n\n[[a]]\nb = []\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Map([("b", Seq([Map([("c", Int(1L))]), Map([("c", Int(2L))])]))]),
          Map([("b", Seq([]))]),
        ]),
      ),
    ]),
    false,
    "[[a]]\n\n[[a.b]]\nc = 1\n\n[[a.b]]\nc = 2\n\n[[a]]\nb = []\n",
  )
  check_ser(
    Map([("a", Seq([Map([("b", Map([("c", Int(1L))]))])]))]),
    true,
    "[[a]]\n\n[a.b]\nc = 1\n",
  )
  check_ser(
    Map([("a", Seq([Map([("b", Map([("c", Int(1L))]))])]))]),
    false,
    "[[a]]\n\n[a.b]\nc = 1\n",
  )
  check_ser(
    Map([("a", Map([("x", Seq([Map([("y", Int(1L))])]))]))]),
    true,
    "[[a.x]]\ny = 1\n",
  )
  check_ser(
    Map([("a", Map([("x", Seq([Map([("y", Int(1L))])]))]))]),
    false,
    "[[a.x]]\ny = 1\n",
  )
  check_ser(
    Map([
      (
        "f",
        Seq([
          Float(0.0),
          Float(-0.0),
          Float(1.0),
          Float(-1.0),
          Float(1.5),
          Float(0.1),
          Float(1.0e300),
          Float(1.0e-300),
          Float(1.0e16),
          Float(1000000000000000.0),
          Float(123456789.0),
          Float(1.0e-07),
          Float(2.5e-05),
          Float(@double.infinity),
          Float(@double.neg_infinity),
          Float(@double.not_a_number),
        ]),
      ),
    ]),
    true,
    "f = [\n    0.0,\n    -0.0,\n    1.0,\n    -1.0,\n    1.5,\n    0.1,\n    1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.0,\n    0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001,\n    10000000000000000.0,\n    1000000000000000.0,\n    123456789.0,\n    0.0000001,\n    0.000025,\n    inf,\n    -inf,\n    nan,\n]\n",
  )
  check_ser(
    Map([
      (
        "f",
        Seq([
          Float(0.0),
          Float(-0.0),
          Float(1.0),
          Float(-1.0),
          Float(1.5),
          Float(0.1),
          Float(1.0e300),
          Float(1.0e-300),
          Float(1.0e16),
          Float(1000000000000000.0),
          Float(123456789.0),
          Float(1.0e-07),
          Float(2.5e-05),
          Float(@double.infinity),
          Float(@double.neg_infinity),
          Float(@double.not_a_number),
        ]),
      ),
    ]),
    false,
    "f = [0.0, -0.0, 1.0, -1.0, 1.5, 0.1, 1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.0, 0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001, 10000000000000000.0, 1000000000000000.0, 123456789.0, 0.0000001, 0.000025, inf, -inf, nan]\n",
  )
  check_ser(Map([("f", Float(1.0e21))]), true, "f = 1000000000000000000000.0\n")
  check_ser(
    Map([("f", Float(1.0e21))]),
    false,
    "f = 1000000000000000000000.0\n",
  )
  check_ser(Map([("f", Float(-0.0))]), true, "f = -0.0\n")
  check_ser(Map([("f", Float(-0.0))]), false, "f = -0.0\n")
  check_ser(
    Map([
      (
        "n",
        Seq([
          Int(0L),
          Int(-1L),
          Int(9223372036854775807L),
          Int(-9223372036854775807L - 1L),
        ]),
      ),
    ]),
    true,
    "n = [\n    0,\n    -1,\n    9223372036854775807,\n    -9223372036854775808,\n]\n",
  )
  check_ser(
    Map([
      (
        "n",
        Seq([
          Int(0L),
          Int(-1L),
          Int(9223372036854775807L),
          Int(-9223372036854775807L - 1L),
        ]),
      ),
    ]),
    false,
    "n = [0, -1, 9223372036854775807, -9223372036854775808]\n",
  )
  check_ser(
    Map([("b", Seq([Bool(true), Bool(false)]))]),
    true,
    "b = [\n    true,\n    false,\n]\n",
  )
  check_ser(
    Map([("b", Seq([Bool(true), Bool(false)]))]),
    false,
    "b = [true, false]\n",
  )
  check_ser(
    Map([
      (
        "s",
        Seq([
          Str(""),
          Str("abc"),
          Str("a b"),
          Str("it's"),
          Str("a\"b"),
          Str("a\\b"),
          Str("a'b\"c"),
          Str("a'''b\"c"),
          Str("a\"b'"),
          Str("'a\"b"),
          Str("''a\""),
          Str("a\tb"),
          Str("a\u{1}b"),
          Str("a\u{7f}b"),
          Str("a\rb"),
          Str("a\u{8}\u{c}"),
          Str("\u{e9}\u{4e2d}\u{1f600}"),
          Str("a\"\n'b"),
          Str("line1\nline2"),
          Str("a\"\n'''b"),
          Str("\n"),
          Str("\""),
          Str("\\"),
          Str("'"),
          Str("''"),
          Str("x\"''"),
          Str("a\"\u{1}b"),
        ]),
      ),
    ]),
    true,
    "s = [\n    \"\",\n    \"abc\",\n    \"a b\",\n    \"it's\",\n    'a\"b',\n    'a\\b',\n    '''a'b\"c''',\n    \"a'''b\\\"c\",\n    \"a\\\"b'\",\n    ''''a\"b''',\n    '''''a\"''',\n    \"a\\tb\",\n    \"a\\u0001b\",\n    \"a\\u007Fb\",\n    \"a\\rb\",\n    \"a\\b\\f\",\n    \"\u{e9}\u{4e2d}\u{1f600}\",\n    '''\na\"\n'b''',\n    \"\"\"\nline1\nline2\"\"\",\n    \"\"\"\na\\\"\n'''b\"\"\",\n    \"\"\"\n\n\"\"\",\n    '\"',\n    '\\',\n    \"'\",\n    \"''\",\n    \"x\\\"''\",\n    \"a\\\"\\u0001b\",\n]\n",
  )
  check_ser(
    Map([
      (
        "s",
        Seq([
          Str(""),
          Str("abc"),
          Str("a b"),
          Str("it's"),
          Str("a\"b"),
          Str("a\\b"),
          Str("a'b\"c"),
          Str("a'''b\"c"),
          Str("a\"b'"),
          Str("'a\"b"),
          Str("''a\""),
          Str("a\tb"),
          Str("a\u{1}b"),
          Str("a\u{7f}b"),
          Str("a\rb"),
          Str("a\u{8}\u{c}"),
          Str("\u{e9}\u{4e2d}\u{1f600}"),
          Str("a\"\n'b"),
          Str("line1\nline2"),
          Str("a\"\n'''b"),
          Str("\n"),
          Str("\""),
          Str("\\"),
          Str("'"),
          Str("''"),
          Str("x\"''"),
          Str("a\"\u{1}b"),
        ]),
      ),
    ]),
    false,
    "s = [\"\", \"abc\", \"a b\", \"it's\", 'a\"b', 'a\\b', '''a'b\"c''', \"a'''b\\\"c\", \"a\\\"b'\", ''''a\"b''', '''''a\"''', \"a\\tb\", \"a\\u0001b\", \"a\\u007Fb\", \"a\\rb\", \"a\\b\\f\", \"\u{e9}\u{4e2d}\u{1f600}\", '''\na\"\n'b''', \"\"\"\nline1\nline2\"\"\", \"\"\"\na\\\"\n'''b\"\"\", \"\"\"\n\n\"\"\", '\"', '\\', \"'\", \"''\", \"x\\\"''\", \"a\\\"\\u0001b\"]\n",
  )
  check_ser(
    Map([
      ("", Int(1L)),
      ("a b", Int(2L)),
      ("a.b", Int(3L)),
      ("\u{e9}", Int(4L)),
      ("a\"b", Int(5L)),
      ("a\\b", Int(6L)),
      ("a'b", Int(7L)),
      ("a\nb", Int(8L)),
      ("\u{4e2d}\"", Int(9L)),
      ("\u{e9}\"", Int(10L)),
      ("-_aZ09", Int(11L)),
      ("a\tb", Int(12L)),
      ("a\"\u{1}", Int(13L)),
    ]),
    true,
    "\"\" = 1\n\"a b\" = 2\n\"a.b\" = 3\n\"\u{e9}\" = 4\n'a\"b' = 5\n'a\\b' = 6\n\"a'b\" = 7\n\"a\\nb\" = 8\n\"\u{4e2d}\\\"\" = 9\n'\u{e9}\"' = 10\n-_aZ09 = 11\n\"a\\tb\" = 12\n\"a\\\"\\u0001\" = 13\n",
  )
  check_ser(
    Map([
      ("", Int(1L)),
      ("a b", Int(2L)),
      ("a.b", Int(3L)),
      ("\u{e9}", Int(4L)),
      ("a\"b", Int(5L)),
      ("a\\b", Int(6L)),
      ("a'b", Int(7L)),
      ("a\nb", Int(8L)),
      ("\u{4e2d}\"", Int(9L)),
      ("\u{e9}\"", Int(10L)),
      ("-_aZ09", Int(11L)),
      ("a\tb", Int(12L)),
      ("a\"\u{1}", Int(13L)),
    ]),
    false,
    "\"\" = 1\n\"a b\" = 2\n\"a.b\" = 3\n\"\u{e9}\" = 4\n'a\"b' = 5\n'a\\b' = 6\n\"a'b\" = 7\n\"a\\nb\" = 8\n\"\u{4e2d}\\\"\" = 9\n'\u{e9}\"' = 10\n-_aZ09 = 11\n\"a\\tb\" = 12\n\"a\\\"\\u0001\" = 13\n",
  )
  check_ser(
    Map([
      ("x y", Map([("z w", Map([("q", Int(1L))]))])),
      ("arr t", Seq([Map([("k k", Int(1L))])])),
    ]),
    true,
    "[\"x y\".\"z w\"]\nq = 1\n\n[[\"arr t\"]]\n\"k k\" = 1\n",
  )
  check_ser(
    Map([
      ("x y", Map([("z w", Map([("q", Int(1L))]))])),
      ("arr t", Seq([Map([("k k", Int(1L))])])),
    ]),
    false,
    "[\"x y\".\"z w\"]\nq = 1\n\n[[\"arr t\"]]\n\"k k\" = 1\n",
  )
  check_ser(
    Map([("a", Str("x")), ("b", Map([("c", Str("y"))])), ("d", Str("z"))]),
    true,
    "a = \"x\"\nd = \"z\"\n\n[b]\nc = \"y\"\n",
  )
  check_ser(
    Map([("a", Str("x")), ("b", Map([("c", Str("y"))])), ("d", Str("z"))]),
    false,
    "a = \"x\"\nd = \"z\"\n\n[b]\nc = \"y\"\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([]))])), ("c", Int(1L))]),
    true,
    "c = 1\n\n[a.b]\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([]))])), ("c", Int(1L))]),
    false,
    "c = 1\n\n[a.b]\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([])), ("c", Map([("d", Int(1L))]))]))]),
    true,
    "[a.b]\n\n[a.c]\nd = 1\n",
  )
  check_ser(
    Map([("a", Map([("b", Map([])), ("c", Map([("d", Int(1L))]))]))]),
    false,
    "[a.b]\n\n[a.c]\nd = 1\n",
  )
  check_ser(
    Map([("a", Map([("b", Seq([Map([("c", Map([]))])]))]))]),
    true,
    "[[a.b]]\n\n[a.b.c]\n",
  )
  check_ser(
    Map([("a", Map([("b", Seq([Map([("c", Map([]))])]))]))]),
    false,
    "[[a.b]]\n\n[a.b.c]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Map([
            ("b", Int(1L)),
            ("c", Map([("d", Seq([Int(1L), Int(2L), Int(3L)]))])),
          ]),
        ]),
      ),
    ]),
    true,
    "[[a]]\nb = 1\n\n[a.c]\nd = [\n    1,\n    2,\n    3,\n]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Map([
            ("b", Int(1L)),
            ("c", Map([("d", Seq([Int(1L), Int(2L), Int(3L)]))])),
          ]),
        ]),
      ),
    ]),
    false,
    "[[a]]\nb = 1\n\n[a.c]\nd = [1, 2, 3]\n",
  )
  check_ser(
    Map([
      ("a", Map([("b", Seq([Int(1L), Map([("c", Seq([Int(1L), Int(2L)]))])]))])),
    ]),
    true,
    "[a]\nb = [\n    1,\n    { c = [\n    1,\n    2,\n] },\n]\n",
  )
  check_ser(
    Map([
      ("a", Map([("b", Seq([Int(1L), Map([("c", Seq([Int(1L), Int(2L)]))])]))])),
    ]),
    false,
    "[a]\nb = [1, { c = [1, 2] }]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Seq([Map([("x", Int(1L))]), Map([("y", Int(2L))])]),
          Seq([Map([("z", Int(3L))])]),
        ]),
      ),
    ]),
    true,
    "a = [\n    [\n    { x = 1 },\n    { y = 2 },\n],\n    [{ z = 3 }],\n]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Seq([Map([("x", Int(1L))]), Map([("y", Int(2L))])]),
          Seq([Map([("z", Int(3L))])]),
        ]),
      ),
    ]),
    false,
    "a = [[{ x = 1 }, { y = 2 }], [{ z = 3 }]]\n",
  )
  check_ser(Map([("a", Map([("x", None)]))]), true, "[a]\n")
  check_ser(Map([("a", Map([("x", None)]))]), false, "[a]\n")
  check_ser(
    Map([("a", Seq([Map([("x", None)]), Map([("y", Int(1L))])]))]),
    true,
    "[[a]]\n\n[[a]]\ny = 1\n",
  )
  check_ser(
    Map([("a", Seq([Map([("x", None)]), Map([("y", Int(1L))])]))]),
    false,
    "[[a]]\n\n[[a]]\ny = 1\n",
  )
  check_ser(
    Map([("k", Str("multi\nline\"quote"))]),
    true,
    "k = '''\nmulti\nline\"quote'''\n",
  )
  check_ser(
    Map([("k", Str("multi\nline\"quote"))]),
    false,
    "k = '''\nmulti\nline\"quote'''\n",
  )
  check_ser(Map([("k", Str("trailing'"))]), true, "k = \"trailing'\"\n")
  check_ser(Map([("k", Str("trailing'"))]), false, "k = \"trailing'\"\n")
  check_ser(Map([("k", Str("x'''y"))]), true, "k = \"x'''y\"\n")
  check_ser(Map([("k", Str("x'''y"))]), false, "k = \"x'''y\"\n")
  check_ser(Map([("k", Str("x''y\\"))]), true, "k = '''x''y\\'''\n")
  check_ser(Map([("k", Str("x''y\\"))]), false, "k = '''x''y\\'''\n")
  check_ser(Map([("k", Str("\\\n"))]), true, "k = '''\n\\\n'''\n")
  check_ser(Map([("k", Str("\\\n"))]), false, "k = '''\n\\\n'''\n")
}
