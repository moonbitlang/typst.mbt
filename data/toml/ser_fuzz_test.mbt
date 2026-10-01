///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: random toml.encode" {
  check_ser(Map([("z", Map([]))]), true, "[z]\n")
  check_ser(Map([("z", Map([]))]), false, "[z]\n")
  check_ser(
    Map([
      (
        "b",
        Seq([
          Seq([
            Seq([
              Map([
                (
                  "a",
                  Map([
                    ("q\"", Str("\u{e9}\u{4e2d}")),
                    ("a", Float(0.25)),
                    ("x y", Int(0L)),
                  ]),
                ),
                ("\u{e9}", None),
                ("n\nl", Float(@double.not_a_number)),
              ]),
            ]),
            Seq([
              Map([]),
              Map([
                (
                  "x y",
                  Seq([
                    Map([
                      ("x y", Float(1.0e20)),
                      ("a", Str("a\"b")),
                      ("b", Str("\u{1}")),
                    ]),
                    Map([("b", Str("\u{1}")), ("n\nl", Float(3.14159))]),
                  ]),
                ),
                ("n\nl", Seq([])),
                ("s'", Str("x'")),
              ]),
            ]),
            Seq([Seq([Str("a\"\n'b"), Str("\u{e9}\u{4e2d}")])]),
          ]),
          Str("\"'"),
          Seq([
            Seq([
              Map([]),
              Map([
                ("z", Seq([Int(1099511627776L), None, Str("a\"b")])),
                ("n\nl", Str("it's")),
              ]),
            ]),
            Str("a\\b"),
            Seq([
              Seq([
                Map([]),
                Map([("n\nl", Bool(true)), ("s'", Str("a\\b"))]),
                Map([
                  ("x y", Float(3.14159)),
                  ("s'", Float(3.14159)),
                  ("\u{e9}", Str("a\"b")),
                  ("z", Float(1.0e-09)),
                ]),
              ]),
              Seq([]),
            ]),
          ]),
        ]),
      ),
      (
        "x y",
        Seq([Map([("", Int(0L)), ("b", None), ("s'", Str("\u{e9}\u{4e2d}"))])]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "b",
        Seq([
          Seq([
            Seq([
              Map([
                (
                  "a",
                  Map([
                    ("q\"", Str("\u{e9}\u{4e2d}")),
                    ("a", Float(0.25)),
                    ("x y", Int(0L)),
                  ]),
                ),
                ("\u{e9}", None),
                ("n\nl", Float(@double.not_a_number)),
              ]),
            ]),
            Seq([
              Map([]),
              Map([
                (
                  "x y",
                  Seq([
                    Map([
                      ("x y", Float(1.0e20)),
                      ("a", Str("a\"b")),
                      ("b", Str("\u{1}")),
                    ]),
                    Map([("b", Str("\u{1}")), ("n\nl", Float(3.14159))]),
                  ]),
                ),
                ("n\nl", Seq([])),
                ("s'", Str("x'")),
              ]),
            ]),
            Seq([Seq([Str("a\"\n'b"), Str("\u{e9}\u{4e2d}")])]),
          ]),
          Str("\"'"),
          Seq([
            Seq([
              Map([]),
              Map([
                ("z", Seq([Int(1099511627776L), None, Str("a\"b")])),
                ("n\nl", Str("it's")),
              ]),
            ]),
            Str("a\\b"),
            Seq([
              Seq([
                Map([]),
                Map([("n\nl", Bool(true)), ("s'", Str("a\\b"))]),
                Map([
                  ("x y", Float(3.14159)),
                  ("s'", Float(3.14159)),
                  ("\u{e9}", Str("a\"b")),
                  ("z", Float(1.0e-09)),
                ]),
              ]),
              Seq([]),
            ]),
          ]),
        ]),
      ),
      (
        "x y",
        Seq([Map([("", Int(0L)), ("b", None), ("s'", Str("\u{e9}\u{4e2d}"))])]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Map([
                  ("b", Float(@double.not_a_number)),
                  ("\u{e9}", Seq([Float(0.25)])),
                  (
                    "n\nl",
                    Map([
                      ("q\"", Map([])),
                      ("x y", Int(-7L)),
                      ("a", Seq([Float(3.14159), Float(1.0e20)])),
                    ]),
                  ),
                ]),
                Map([
                  (
                    "x y",
                    Map([
                      ("b", Map([("", Float(3.14159)), ("z", None)])),
                      ("n\nl", Map([])),
                    ]),
                  ),
                ]),
              ]),
            ),
            (
              "z",
              Map([
                ("s'", Str("\u{e9}\u{4e2d}")),
                (
                  "z",
                  Seq([
                    Int(0L),
                    Str("a\"\n'b"),
                    Map([
                      ("x y", Str("a\"\n'b")),
                      ("q\"", Str("x")),
                      ("a", Float(@double.not_a_number)),
                      ("", Float(1.0)),
                    ]),
                  ]),
                ),
                (
                  "\u{e9}",
                  Map([
                    ("k-1", Float(1.0)),
                    (
                      "",
                      Seq([
                        Map([
                          ("\u{e9}", Str("\"'")),
                          ("n\nl", Str("a\"b")),
                          ("x y", Bool(true)),
                          ("b", Int(1099511627776L)),
                        ]),
                        Map([
                          ("x y", Float(1.0e-09)),
                          ("z", Float(0.25)),
                          ("\u{e9}", Int(0L)),
                          ("", Str("l1\nl2")),
                        ]),
                      ]),
                    ),
                    ("s'", Str("a\"b")),
                    ("b", Float(3.14159)),
                  ]),
                ),
                ("b", Seq([Map([("b", Str("x'")), ("q\"", Str("a\"b"))])])),
              ]),
            ),
          ]),
          Map([("z", Float(0.25))]),
          Map([("", Seq([])), ("s'", Map([]))]),
        ]),
      ),
      ("a", Map([])),
    ]),
    true,
    "[[k-1]]\n\n[[k-1.\"s'\"]]\nb = nan\n\"\u{e9}\" = [0.25]\n\n[k-1.\"s'\".\"n\\nl\"]\n\"x y\" = -7\na = [\n    3.14159,\n    100000000000000000000.0,\n]\n\n[k-1.\"s'\".\"n\\nl\".'q\"']\n\n[[k-1.\"s'\"]]\n\n[k-1.\"s'\".\"x y\".b]\n\"\" = 3.14159\n\n[k-1.\"s'\".\"x y\".\"n\\nl\"]\n\n[k-1.z]\n\"s'\" = \"\u{e9}\u{4e2d}\"\nz = [\n    0,\n    '''\na\"\n'b''',\n    { \"x y\" = '''\na\"\n'b''', 'q\"' = \"x\", a = nan, \"\" = 1.0 },\n]\n\n[k-1.z.\"\u{e9}\"]\nk-1 = 1.0\n\"s'\" = 'a\"b'\nb = 3.14159\n\n[[k-1.z.\"\u{e9}\".\"\"]]\n\"\u{e9}\" = \"\\\"'\"\n\"n\\nl\" = 'a\"b'\n\"x y\" = true\nb = 1099511627776\n\n[[k-1.z.\"\u{e9}\".\"\"]]\n\"x y\" = 0.000000001\nz = 0.25\n\"\u{e9}\" = 0\n\"\" = \"\"\"\nl1\nl2\"\"\"\n\n[[k-1.z.b]]\nb = \"x'\"\n'q\"' = 'a\"b'\n\n[[k-1]]\nz = 0.25\n\n[[k-1]]\n\"\" = []\n\n[k-1.\"s'\"]\n\n[a]\n",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Map([
                  ("b", Float(@double.not_a_number)),
                  ("\u{e9}", Seq([Float(0.25)])),
                  (
                    "n\nl",
                    Map([
                      ("q\"", Map([])),
                      ("x y", Int(-7L)),
                      ("a", Seq([Float(3.14159), Float(1.0e20)])),
                    ]),
                  ),
                ]),
                Map([
                  (
                    "x y",
                    Map([
                      ("b", Map([("", Float(3.14159)), ("z", None)])),
                      ("n\nl", Map([])),
                    ]),
                  ),
                ]),
              ]),
            ),
            (
              "z",
              Map([
                ("s'", Str("\u{e9}\u{4e2d}")),
                (
                  "z",
                  Seq([
                    Int(0L),
                    Str("a\"\n'b"),
                    Map([
                      ("x y", Str("a\"\n'b")),
                      ("q\"", Str("x")),
                      ("a", Float(@double.not_a_number)),
                      ("", Float(1.0)),
                    ]),
                  ]),
                ),
                (
                  "\u{e9}",
                  Map([
                    ("k-1", Float(1.0)),
                    (
                      "",
                      Seq([
                        Map([
                          ("\u{e9}", Str("\"'")),
                          ("n\nl", Str("a\"b")),
                          ("x y", Bool(true)),
                          ("b", Int(1099511627776L)),
                        ]),
                        Map([
                          ("x y", Float(1.0e-09)),
                          ("z", Float(0.25)),
                          ("\u{e9}", Int(0L)),
                          ("", Str("l1\nl2")),
                        ]),
                      ]),
                    ),
                    ("s'", Str("a\"b")),
                    ("b", Float(3.14159)),
                  ]),
                ),
                ("b", Seq([Map([("b", Str("x'")), ("q\"", Str("a\"b"))])])),
              ]),
            ),
          ]),
          Map([("z", Float(0.25))]),
          Map([("", Seq([])), ("s'", Map([]))]),
        ]),
      ),
      ("a", Map([])),
    ]),
    false,
    "[[k-1]]\n\n[[k-1.\"s'\"]]\nb = nan\n\"\u{e9}\" = [0.25]\n\n[k-1.\"s'\".\"n\\nl\"]\n\"x y\" = -7\na = [3.14159, 100000000000000000000.0]\n\n[k-1.\"s'\".\"n\\nl\".'q\"']\n\n[[k-1.\"s'\"]]\n\n[k-1.\"s'\".\"x y\".b]\n\"\" = 3.14159\n\n[k-1.\"s'\".\"x y\".\"n\\nl\"]\n\n[k-1.z]\n\"s'\" = \"\u{e9}\u{4e2d}\"\nz = [0, '''\na\"\n'b''', { \"x y\" = '''\na\"\n'b''', 'q\"' = \"x\", a = nan, \"\" = 1.0 }]\n\n[k-1.z.\"\u{e9}\"]\nk-1 = 1.0\n\"s'\" = 'a\"b'\nb = 3.14159\n\n[[k-1.z.\"\u{e9}\".\"\"]]\n\"\u{e9}\" = \"\\\"'\"\n\"n\\nl\" = 'a\"b'\n\"x y\" = true\nb = 1099511627776\n\n[[k-1.z.\"\u{e9}\".\"\"]]\n\"x y\" = 0.000000001\nz = 0.25\n\"\u{e9}\" = 0\n\"\" = \"\"\"\nl1\nl2\"\"\"\n\n[[k-1.z.b]]\nb = \"x'\"\n'q\"' = 'a\"b'\n\n[[k-1]]\nz = 0.25\n\n[[k-1]]\n\"\" = []\n\n[k-1.\"s'\"]\n\n[a]\n",
  )
  check_ser(
    Map([("a", Str("x'")), ("z", Seq([])), ("s'", Float(-0.0))]),
    true,
    "a = \"x'\"\nz = []\n\"s'\" = -0.0\n",
  )
  check_ser(
    Map([("a", Str("x'")), ("z", Seq([])), ("s'", Float(-0.0))]),
    false,
    "a = \"x'\"\nz = []\n\"s'\" = -0.0\n",
  )
  check_ser(
    Map([
      (
        "b",
        Seq([
          Map([
            ("", Seq([Float(1.0), Seq([Map([])]), Float(1.0e20)])),
            ("z", Float(@double.not_a_number)),
            (
              "\u{e9}",
              Map([
                ("b", Str("x'")),
                (
                  "z",
                  Seq([
                    Map([("\u{e9}", Float(0.25)), ("x y", Float(-0.0))]),
                    Map([]),
                    Map([
                      ("b", Str("'''")),
                      ("\u{e9}", Float(@double.not_a_number)),
                      ("", Int(1099511627776L)),
                    ]),
                  ]),
                ),
                (
                  "\u{e9}",
                  Seq([
                    Map([("x y", Str("a\"b")), ("z", Str("l1\nl2"))]),
                    Map([]),
                    Map([("x y", Float(-0.0))]),
                  ]),
                ),
              ]),
            ),
          ]),
          Seq([Seq([]), Seq([Map([])])]),
          Str("x'"),
        ]),
      ),
    ]),
    true,
    "b = [\n    { \"\" = [\n    1.0,\n    [{}],\n    100000000000000000000.0,\n], z = nan, \"\u{e9}\" = { b = \"x'\", z = [\n    { \"\u{e9}\" = 0.25, \"x y\" = -0.0 },\n    {},\n    { b = \"'''\", \"\u{e9}\" = nan, \"\" = 1099511627776 },\n], \"\u{e9}\" = [\n    { \"x y\" = 'a\"b', z = \"\"\"\nl1\nl2\"\"\" },\n    {},\n    { \"x y\" = -0.0 },\n] } },\n    [\n    [],\n    [{}],\n],\n    \"x'\",\n]\n",
  )
  check_ser(
    Map([
      (
        "b",
        Seq([
          Map([
            ("", Seq([Float(1.0), Seq([Map([])]), Float(1.0e20)])),
            ("z", Float(@double.not_a_number)),
            (
              "\u{e9}",
              Map([
                ("b", Str("x'")),
                (
                  "z",
                  Seq([
                    Map([("\u{e9}", Float(0.25)), ("x y", Float(-0.0))]),
                    Map([]),
                    Map([
                      ("b", Str("'''")),
                      ("\u{e9}", Float(@double.not_a_number)),
                      ("", Int(1099511627776L)),
                    ]),
                  ]),
                ),
                (
                  "\u{e9}",
                  Seq([
                    Map([("x y", Str("a\"b")), ("z", Str("l1\nl2"))]),
                    Map([]),
                    Map([("x y", Float(-0.0))]),
                  ]),
                ),
              ]),
            ),
          ]),
          Seq([Seq([]), Seq([Map([])])]),
          Str("x'"),
        ]),
      ),
    ]),
    false,
    "b = [{ \"\" = [1.0, [{}], 100000000000000000000.0], z = nan, \"\u{e9}\" = { b = \"x'\", z = [{ \"\u{e9}\" = 0.25, \"x y\" = -0.0 }, {}, { b = \"'''\", \"\u{e9}\" = nan, \"\" = 1099511627776 }], \"\u{e9}\" = [{ \"x y\" = 'a\"b', z = \"\"\"\nl1\nl2\"\"\" }, {}, { \"x y\" = -0.0 }] } }, [[], [{}]], \"x'\"]\n",
  )
  check_ser(
    Map([("s'", Seq([Str("\u{e9}\u{4e2d}")])), ("\u{e9}", Str("a\"\n'b"))]),
    true,
    "\"s'\" = [\"\u{e9}\u{4e2d}\"]\n\"\u{e9}\" = '''\na\"\n'b'''\n",
  )
  check_ser(
    Map([("s'", Seq([Str("\u{e9}\u{4e2d}")])), ("\u{e9}", Str("a\"\n'b"))]),
    false,
    "\"s'\" = [\"\u{e9}\u{4e2d}\"]\n\"\u{e9}\" = '''\na\"\n'b'''\n",
  )
  check_ser(
    Map([("k-1", Seq([Map([("", Str("it's")), ("z", Float(1.0))])]))]),
    true,
    "[[k-1]]\n\"\" = \"it's\"\nz = 1.0\n",
  )
  check_ser(
    Map([("k-1", Seq([Map([("", Str("it's")), ("z", Float(1.0))])]))]),
    false,
    "[[k-1]]\n\"\" = \"it's\"\nz = 1.0\n",
  )
  check_ser(Map([("n\nl", Map([]))]), true, "[\"n\\nl\"]\n")
  check_ser(Map([("n\nl", Map([]))]), false, "[\"n\\nl\"]\n")
  check_ser(
    Map([
      (
        "z",
        Map([
          ("x y", Bool(false)),
          ("n\nl", Str("\t")),
          (
            "s'",
            Map([
              ("", Seq([Bool(false), None, Float(1.0e-09)])),
              ("k-1", Str("\"'")),
              (
                "n\nl",
                Map([
                  ("x y", Str("x")),
                  (
                    "s'",
                    Map([
                      ("\u{e9}", Str("\u{1}")),
                      ("", Float(-0.0)),
                      ("a", Str("\u{e9}\u{4e2d}")),
                    ]),
                  ),
                  ("n\nl", Seq([Str("\u{e9}\u{4e2d}"), Float(1.0)])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      ("", Float(1.0e20)),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Map([
          ("x y", Bool(false)),
          ("n\nl", Str("\t")),
          (
            "s'",
            Map([
              ("", Seq([Bool(false), None, Float(1.0e-09)])),
              ("k-1", Str("\"'")),
              (
                "n\nl",
                Map([
                  ("x y", Str("x")),
                  (
                    "s'",
                    Map([
                      ("\u{e9}", Str("\u{1}")),
                      ("", Float(-0.0)),
                      ("a", Str("\u{e9}\u{4e2d}")),
                    ]),
                  ),
                  ("n\nl", Seq([Str("\u{e9}\u{4e2d}"), Float(1.0)])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      ("", Float(1.0e20)),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("\u{e9}", Str("\t")),
      ("s'", Seq([])),
      (
        "z",
        Map([
          ("q\"", Str("a\\b")),
          (
            "a",
            Seq([
              Seq([
                Map([
                  (
                    "n\nl",
                    Map([
                      ("a", Bool(false)),
                      ("", Float(0.25)),
                      ("b", Int(-7L)),
                      ("z", Str("a\"\n'b")),
                    ]),
                  ),
                  ("b", Seq([Float(@double.not_a_number)])),
                  ("q\"", Seq([Str("l1\nl2"), Float(1.0)])),
                ]),
                Map([]),
              ]),
              Seq([
                Map([("", Str("\u{1}")), ("n\nl", Float(1.0))]),
                Seq([]),
                Str("l1\nl2"),
              ]),
              Float(0.25),
            ]),
          ),
          ("x y", Int(-7L)),
        ]),
      ),
      ("n\nl", Float(1.0e20)),
    ]),
    true,
    "\"\u{e9}\" = \"\\t\"\n\"s'\" = []\n\"n\\nl\" = 100000000000000000000.0\n\n[z]\n'q\"' = 'a\\b'\na = [\n    [\n    { \"n\\nl\" = { a = false, \"\" = 0.25, b = -7, z = '''\na\"\n'b''' }, b = [nan], 'q\"' = [\n    \"\"\"\nl1\nl2\"\"\",\n    1.0,\n] },\n    {},\n],\n    [\n    { \"\" = \"\\u0001\", \"n\\nl\" = 1.0 },\n    [],\n    \"\"\"\nl1\nl2\"\"\",\n],\n    0.25,\n]\n\"x y\" = -7\n",
  )
  check_ser(
    Map([
      ("\u{e9}", Str("\t")),
      ("s'", Seq([])),
      (
        "z",
        Map([
          ("q\"", Str("a\\b")),
          (
            "a",
            Seq([
              Seq([
                Map([
                  (
                    "n\nl",
                    Map([
                      ("a", Bool(false)),
                      ("", Float(0.25)),
                      ("b", Int(-7L)),
                      ("z", Str("a\"\n'b")),
                    ]),
                  ),
                  ("b", Seq([Float(@double.not_a_number)])),
                  ("q\"", Seq([Str("l1\nl2"), Float(1.0)])),
                ]),
                Map([]),
              ]),
              Seq([
                Map([("", Str("\u{1}")), ("n\nl", Float(1.0))]),
                Seq([]),
                Str("l1\nl2"),
              ]),
              Float(0.25),
            ]),
          ),
          ("x y", Int(-7L)),
        ]),
      ),
      ("n\nl", Float(1.0e20)),
    ]),
    false,
    "\"\u{e9}\" = \"\\t\"\n\"s'\" = []\n\"n\\nl\" = 100000000000000000000.0\n\n[z]\n'q\"' = 'a\\b'\na = [[{ \"n\\nl\" = { a = false, \"\" = 0.25, b = -7, z = '''\na\"\n'b''' }, b = [nan], 'q\"' = [\"\"\"\nl1\nl2\"\"\", 1.0] }, {}], [{ \"\" = \"\\u0001\", \"n\\nl\" = 1.0 }, [], \"\"\"\nl1\nl2\"\"\"], 0.25]\n\"x y\" = -7\n",
  )
  check_ser(
    Map([
      (
        "",
        Map([
          (
            "k-1",
            Seq([
              Map([("z", Str("it's")), ("x y", Float(1.0e-09))]),
              Map([
                ("b", Str("\"'")),
                (
                  "n\nl",
                  Seq([
                    Map([
                      ("n\nl", Str("\u{e9}\u{4e2d}")),
                      ("k-1", Seq([Float(1.0e-09), Float(0.25)])),
                      (
                        "z",
                        Seq([
                          Map([]),
                          Map([
                            ("q\"", Float(3.14159)),
                            ("x y", Float(1.0)),
                            ("b", Int(1099511627776L)),
                            ("z", Str("\u{1}")),
                          ]),
                          Map([("z", Str(""))]),
                        ]),
                      ),
                    ]),
                    Map([("s'", Seq([Str("\t"), Str("a\"\n'b"), Int(0L)]))]),
                  ]),
                ),
              ]),
            ]),
          ),
          (
            "q\"",
            Seq([
              Map([
                ("", Map([])),
                ("z", Float(0.25)),
                (
                  "q\"",
                  Map([
                    ("", Seq([Float(0.25), Str("\u{1}"), Bool(false)])),
                    ("\u{e9}", Str("")),
                    ("a", Str("\t")),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      (
        "x y",
        Seq([Map([("a", Str("l1\nl2"))]), Str("\u{e9}\u{4e2d}"), Bool(true)]),
      ),
      (
        "s'",
        Seq([
          Map([
            ("s'", Str("\"'")),
            ("", Str("\t")),
            ("k-1", Float(@double.not_a_number)),
            (
              "x y",
              Seq([
                Seq([Map([("", Seq([Str("\t"), Str("x"), Float(1.0)]))])]),
                Map([]),
                None,
              ]),
            ),
          ]),
          Map([
            (
              "\u{e9}",
              Map([("", Map([])), ("n\nl", Str("\"'")), ("k-1", Float(0.25))]),
            ),
            ("b", Seq([Str("'''")])),
            (
              "k-1",
              Seq([
                Map([
                  (
                    "s'",
                    Seq([
                      Map([("x y", Str("x'"))]),
                      Seq([Str("\t"), Str("it's")]),
                    ]),
                  ),
                ]),
                Map([]),
                Map([
                  (
                    "n\nl",
                    Seq([
                      Seq([
                        Map([("b", Int(0L)), ("z", Str("\u{e9}\u{4e2d}"))]),
                        Map([("a", Float(3.14159))]),
                        Map([]),
                      ]),
                    ]),
                  ),
                  ("a", Seq([Seq([]), Map([]), Bool(true)])),
                ]),
              ]),
            ),
          ]),
          Map([
            (
              "k-1",
              Map([
                (
                  "a",
                  Seq([
                    Map([]),
                    Map([("\u{e9}", Bool(true)), ("q\"", Float(0.25))]),
                  ]),
                ),
                (
                  "\u{e9}",
                  Seq([
                    Map([]),
                    Map([
                      (
                        "",
                        Seq([
                          Map([
                            ("\u{e9}", Str("")),
                            ("z", Str("a\"b")),
                            ("n\nl", Int(-7L)),
                          ]),
                          Map([("x y", Int(0L)), ("k-1", Str("\u{1}"))]),
                          Map([
                            ("a", Str("a\"b")),
                            ("", Str("a\\b")),
                            ("n\nl", Bool(false)),
                          ]),
                        ]),
                      ),
                      ("z", Map([("a", Str("a\\b"))])),
                    ]),
                    Map([
                      (
                        "k-1",
                        Seq([Float(@double.infinity), Str("x"), Float(1.0e20)]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            (
              "x y",
              Map([
                ("s'", Map([("q\"", Seq([Float(1.0), Str("\u{1}")]))])),
                (
                  "b",
                  Map([
                    ("q\"", Str("\u{1}")),
                    (
                      "n\nl",
                      Seq([
                        Map([
                          ("b", Str("it's")),
                          ("z", Bool(true)),
                          ("\u{e9}", Str("")),
                        ]),
                        Map([]),
                        Map([("", Str("'''"))]),
                      ]),
                    ),
                  ]),
                ),
                ("a", Seq([Seq([Str("a\"b"), Str("a\"b")]), Float(3.14159)])),
                ("n\nl", Map([("q\"", Float(0.25)), ("k-1", Seq([None]))])),
              ]),
            ),
            (
              "\u{e9}",
              Seq([
                Seq([
                  Map([
                    ("b", Seq([None])),
                    ("k-1", Map([("k-1", Float(1.0e20)), ("q\"", Str("it's"))])),
                    (
                      "",
                      Seq([
                        Map([("q\"", Str("x")), ("x y", Str("x"))]),
                        Map([
                          ("q\"", Int(-7L)),
                          ("x y", Float(-0.0)),
                          ("a", Int(-7L)),
                        ]),
                        Map([
                          ("b", Str("\u{1}")),
                          ("k-1", Bool(false)),
                          ("q\"", Bool(true)),
                        ]),
                      ]),
                    ),
                  ]),
                  Map([
                    ("x y", Seq([Str("'''"), Int(0L)])),
                    (
                      "n\nl",
                      Seq([
                        Map([]),
                        Map([("", Str("x'")), ("a", Str("a\"\n'b"))]),
                        Map([]),
                      ]),
                    ),
                    ("q\"", Str("")),
                    (
                      "",
                      Seq([
                        Map([("b", Str("l1\nl2")), ("x y", Float(0.25))]),
                        Map([("n\nl", Str("x'")), ("z", Str("x"))]),
                      ]),
                    ),
                  ]),
                ]),
                Str("\u{e9}\u{4e2d}"),
                Map([("", Str("'''")), ("s'", Str("\"'"))]),
              ]),
            ),
          ]),
        ]),
      ),
      ("b", Float(0.25)),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "",
        Map([
          (
            "k-1",
            Seq([
              Map([("z", Str("it's")), ("x y", Float(1.0e-09))]),
              Map([
                ("b", Str("\"'")),
                (
                  "n\nl",
                  Seq([
                    Map([
                      ("n\nl", Str("\u{e9}\u{4e2d}")),
                      ("k-1", Seq([Float(1.0e-09), Float(0.25)])),
                      (
                        "z",
                        Seq([
                          Map([]),
                          Map([
                            ("q\"", Float(3.14159)),
                            ("x y", Float(1.0)),
                            ("b", Int(1099511627776L)),
                            ("z", Str("\u{1}")),
                          ]),
                          Map([("z", Str(""))]),
                        ]),
                      ),
                    ]),
                    Map([("s'", Seq([Str("\t"), Str("a\"\n'b"), Int(0L)]))]),
                  ]),
                ),
              ]),
            ]),
          ),
          (
            "q\"",
            Seq([
              Map([
                ("", Map([])),
                ("z", Float(0.25)),
                (
                  "q\"",
                  Map([
                    ("", Seq([Float(0.25), Str("\u{1}"), Bool(false)])),
                    ("\u{e9}", Str("")),
                    ("a", Str("\t")),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      (
        "x y",
        Seq([Map([("a", Str("l1\nl2"))]), Str("\u{e9}\u{4e2d}"), Bool(true)]),
      ),
      (
        "s'",
        Seq([
          Map([
            ("s'", Str("\"'")),
            ("", Str("\t")),
            ("k-1", Float(@double.not_a_number)),
            (
              "x y",
              Seq([
                Seq([Map([("", Seq([Str("\t"), Str("x"), Float(1.0)]))])]),
                Map([]),
                None,
              ]),
            ),
          ]),
          Map([
            (
              "\u{e9}",
              Map([("", Map([])), ("n\nl", Str("\"'")), ("k-1", Float(0.25))]),
            ),
            ("b", Seq([Str("'''")])),
            (
              "k-1",
              Seq([
                Map([
                  (
                    "s'",
                    Seq([
                      Map([("x y", Str("x'"))]),
                      Seq([Str("\t"), Str("it's")]),
                    ]),
                  ),
                ]),
                Map([]),
                Map([
                  (
                    "n\nl",
                    Seq([
                      Seq([
                        Map([("b", Int(0L)), ("z", Str("\u{e9}\u{4e2d}"))]),
                        Map([("a", Float(3.14159))]),
                        Map([]),
                      ]),
                    ]),
                  ),
                  ("a", Seq([Seq([]), Map([]), Bool(true)])),
                ]),
              ]),
            ),
          ]),
          Map([
            (
              "k-1",
              Map([
                (
                  "a",
                  Seq([
                    Map([]),
                    Map([("\u{e9}", Bool(true)), ("q\"", Float(0.25))]),
                  ]),
                ),
                (
                  "\u{e9}",
                  Seq([
                    Map([]),
                    Map([
                      (
                        "",
                        Seq([
                          Map([
                            ("\u{e9}", Str("")),
                            ("z", Str("a\"b")),
                            ("n\nl", Int(-7L)),
                          ]),
                          Map([("x y", Int(0L)), ("k-1", Str("\u{1}"))]),
                          Map([
                            ("a", Str("a\"b")),
                            ("", Str("a\\b")),
                            ("n\nl", Bool(false)),
                          ]),
                        ]),
                      ),
                      ("z", Map([("a", Str("a\\b"))])),
                    ]),
                    Map([
                      (
                        "k-1",
                        Seq([Float(@double.infinity), Str("x"), Float(1.0e20)]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            (
              "x y",
              Map([
                ("s'", Map([("q\"", Seq([Float(1.0), Str("\u{1}")]))])),
                (
                  "b",
                  Map([
                    ("q\"", Str("\u{1}")),
                    (
                      "n\nl",
                      Seq([
                        Map([
                          ("b", Str("it's")),
                          ("z", Bool(true)),
                          ("\u{e9}", Str("")),
                        ]),
                        Map([]),
                        Map([("", Str("'''"))]),
                      ]),
                    ),
                  ]),
                ),
                ("a", Seq([Seq([Str("a\"b"), Str("a\"b")]), Float(3.14159)])),
                ("n\nl", Map([("q\"", Float(0.25)), ("k-1", Seq([None]))])),
              ]),
            ),
            (
              "\u{e9}",
              Seq([
                Seq([
                  Map([
                    ("b", Seq([None])),
                    ("k-1", Map([("k-1", Float(1.0e20)), ("q\"", Str("it's"))])),
                    (
                      "",
                      Seq([
                        Map([("q\"", Str("x")), ("x y", Str("x"))]),
                        Map([
                          ("q\"", Int(-7L)),
                          ("x y", Float(-0.0)),
                          ("a", Int(-7L)),
                        ]),
                        Map([
                          ("b", Str("\u{1}")),
                          ("k-1", Bool(false)),
                          ("q\"", Bool(true)),
                        ]),
                      ]),
                    ),
                  ]),
                  Map([
                    ("x y", Seq([Str("'''"), Int(0L)])),
                    (
                      "n\nl",
                      Seq([
                        Map([]),
                        Map([("", Str("x'")), ("a", Str("a\"\n'b"))]),
                        Map([]),
                      ]),
                    ),
                    ("q\"", Str("")),
                    (
                      "",
                      Seq([
                        Map([("b", Str("l1\nl2")), ("x y", Float(0.25))]),
                        Map([("n\nl", Str("x'")), ("z", Str("x"))]),
                      ]),
                    ),
                  ]),
                ]),
                Str("\u{e9}\u{4e2d}"),
                Map([("", Str("'''")), ("s'", Str("\"'"))]),
              ]),
            ),
          ]),
        ]),
      ),
      ("b", Float(0.25)),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([("x y", Seq([Float(3.14159)])), ("n\nl", Seq([]))]),
    true,
    "\"x y\" = [3.14159]\n\"n\\nl\" = []\n",
  )
  check_ser(
    Map([("x y", Seq([Float(3.14159)])), ("n\nl", Seq([]))]),
    false,
    "\"x y\" = [3.14159]\n\"n\\nl\" = []\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Str("x"),
          Seq([
            Map([
              (
                "x y",
                Seq([
                  Seq([]),
                  Seq([
                    Map([
                      ("x y", Float(-0.0)),
                      ("", Str("it's")),
                      ("q\"", Float(1.0e-09)),
                    ]),
                    Map([("k-1", Bool(true))]),
                  ]),
                ]),
              ),
              ("z", Int(0L)),
            ]),
            Map([("b", Int(0L)), ("", Float(0.25))]),
          ]),
          Seq([Int(-7L), Map([("x y", Float(1.0e-09)), ("", Float(1.0e-09))])]),
        ]),
      ),
      (
        "b",
        Seq([
          Seq([
            Seq([
              Seq([Float(-0.0), Str("a\"b"), Str("l1\nl2")]),
              Seq([Float(3.14159)]),
              None,
            ]),
            Float(0.25),
          ]),
        ]),
      ),
      ("n\nl", Int(-7L)),
      (
        "q\"",
        Seq([
          Map([
            (
              "b",
              Seq([
                Map([("n\nl", Seq([])), ("z", Str("a\"\n'b"))]),
                Map([("k-1", Str("a\\b"))]),
                Map([
                  (
                    "x y",
                    Seq([Seq([Str("x'"), Str("")]), Seq([Str("a\"\n'b")])]),
                  ),
                ]),
              ]),
            ),
            (
              "z",
              Map([
                (
                  "a",
                  Map([
                    ("k-1", Seq([Str("x'"), Str("'''")])),
                    ("\u{e9}", Map([])),
                    (
                      "a",
                      Map([
                        ("q\"", Float(@double.infinity)),
                        ("", Str("\u{e9}\u{4e2d}")),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
          Map([]),
          Map([
            ("q\"", Seq([Str("\"'"), Str("x'")])),
            ("x y", Seq([Str("a\"\n'b")])),
            ("b", Map([("n\nl", Seq([Map([]), Map([]), Seq([Str("\"'")])]))])),
            ("k-1", Seq([Float(1.0e-09)])),
          ]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Str("x"),
          Seq([
            Map([
              (
                "x y",
                Seq([
                  Seq([]),
                  Seq([
                    Map([
                      ("x y", Float(-0.0)),
                      ("", Str("it's")),
                      ("q\"", Float(1.0e-09)),
                    ]),
                    Map([("k-1", Bool(true))]),
                  ]),
                ]),
              ),
              ("z", Int(0L)),
            ]),
            Map([("b", Int(0L)), ("", Float(0.25))]),
          ]),
          Seq([Int(-7L), Map([("x y", Float(1.0e-09)), ("", Float(1.0e-09))])]),
        ]),
      ),
      (
        "b",
        Seq([
          Seq([
            Seq([
              Seq([Float(-0.0), Str("a\"b"), Str("l1\nl2")]),
              Seq([Float(3.14159)]),
              None,
            ]),
            Float(0.25),
          ]),
        ]),
      ),
      ("n\nl", Int(-7L)),
      (
        "q\"",
        Seq([
          Map([
            (
              "b",
              Seq([
                Map([("n\nl", Seq([])), ("z", Str("a\"\n'b"))]),
                Map([("k-1", Str("a\\b"))]),
                Map([
                  (
                    "x y",
                    Seq([Seq([Str("x'"), Str("")]), Seq([Str("a\"\n'b")])]),
                  ),
                ]),
              ]),
            ),
            (
              "z",
              Map([
                (
                  "a",
                  Map([
                    ("k-1", Seq([Str("x'"), Str("'''")])),
                    ("\u{e9}", Map([])),
                    (
                      "a",
                      Map([
                        ("q\"", Float(@double.infinity)),
                        ("", Str("\u{e9}\u{4e2d}")),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
          Map([]),
          Map([
            ("q\"", Seq([Str("\"'"), Str("x'")])),
            ("x y", Seq([Str("a\"\n'b")])),
            ("b", Map([("n\nl", Seq([Map([]), Map([]), Seq([Str("\"'")])]))])),
            ("k-1", Seq([Float(1.0e-09)])),
          ]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "x y",
        Seq([
          Map([
            (
              "\u{e9}",
              Seq([
                Seq([
                  Seq([Str("\"'"), None, Int(0L)]),
                  Seq([
                    Map([]),
                    Map([("s'", Str("a\"\n'b"))]),
                    Map([
                      ("", Int(-7L)),
                      ("n\nl", Float(0.25)),
                      ("a", Str("x'")),
                      ("x y", Float(@double.not_a_number)),
                    ]),
                  ]),
                  Map([
                    ("x y", Int(1099511627776L)),
                    ("k-1", Str("a\\b")),
                    ("b", Str("a\"b")),
                  ]),
                ]),
              ]),
            ),
            (
              "a",
              Seq([
                Bool(true),
                Map([
                  (
                    "n\nl",
                    Seq([
                      Map([
                        ("b", Str("x")),
                        ("s'", Str("'''")),
                        ("a", Str("a\"b")),
                      ]),
                      Map([]),
                      Map([
                        ("x y", None),
                        ("", Str("\u{1}")),
                        ("q\"", Int(-7L)),
                        ("n\nl", Float(1.0e-09)),
                      ]),
                    ]),
                  ),
                ]),
                Seq([
                  Map([
                    (
                      "n\nl",
                      Map([
                        ("k-1", Str("\t")),
                        ("q\"", Str("x")),
                        ("", Int(1099511627776L)),
                      ]),
                    ),
                    ("z", Float(@double.infinity)),
                    ("\u{e9}", Map([("", None)])),
                  ]),
                  Map([("k-1", Map([("x y", Str("a\\b"))]))]),
                  Map([
                    ("z", Float(3.14159)),
                    ("x y", Seq([Float(1.0), Bool(false), Str("a\"\n'b")])),
                    ("a", Float(@double.not_a_number)),
                    ("q\"", Seq([Int(-7L)])),
                  ]),
                ]),
              ]),
            ),
            ("n\nl", Seq([Map([("", Str("\u{1}"))])])),
          ]),
          Map([
            (
              "\u{e9}",
              Seq([
                Map([
                  (
                    "",
                    Seq([
                      Map([
                        ("n\nl", Str("it's")),
                        ("", Str("")),
                        ("a", Str("x'")),
                      ]),
                      Map([
                        ("z", Float(1.0)),
                        ("s'", Bool(true)),
                        ("a", Map([("k-1", Str("'''")), ("b", Float(3.14159))])),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            ("n\nl", Seq([])),
            (
              "x y",
              Map([
                ("n\nl", Str("\t")),
                ("z", None),
                (
                  "b",
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([
                          ("x y", Str("'''")),
                          ("k-1", Str("a\"b")),
                          ("n\nl", Float(3.14159)),
                          ("", Float(3.14159)),
                        ]),
                        Map([
                          ("", Str("a\"\n'b")),
                          ("k-1", None),
                          ("s'", Str("x")),
                        ]),
                        Map([("q\"", Str("a\"b"))]),
                      ]),
                    ),
                    ("\u{e9}", Map([])),
                    (
                      "b",
                      Seq([
                        Map([
                          ("s'", Int(1099511627776L)),
                          ("z", Str("it's")),
                          ("q\"", Float(1.0)),
                        ]),
                      ]),
                    ),
                    ("x y", Seq([])),
                  ]),
                ),
              ]),
            ),
          ]),
        ]),
      ),
      (
        "\u{e9}",
        Map([
          (
            "a",
            Map([
              (
                "k-1",
                Map([
                  ("s'", Str("it's")),
                  (
                    "b",
                    Map([
                      ("q\"", Float(@double.not_a_number)),
                      ("n\nl", Str("'''")),
                      ("", Float(@double.infinity)),
                      ("s'", Bool(true)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          (
            "n\nl",
            Map([
              (
                "a",
                Seq([
                  Seq([
                    Map([
                      ("n\nl", Float(0.25)),
                      ("b", Str("x'")),
                      ("\u{e9}", Str("it's")),
                      ("a", Int(0L)),
                    ]),
                    Map([]),
                    Map([
                      ("n\nl", Float(@double.infinity)),
                      ("\u{e9}", Str("\u{e9}\u{4e2d}")),
                      ("z", Str("'''")),
                    ]),
                  ]),
                  Str("a\"b"),
                ]),
              ),
              ("s'", Str("x'")),
              ("n\nl", Int(1099511627776L)),
            ]),
          ),
          ("\u{e9}", Seq([Map([("z", Float(1.0e-09))])])),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "x y",
        Seq([
          Map([
            (
              "\u{e9}",
              Seq([
                Seq([
                  Seq([Str("\"'"), None, Int(0L)]),
                  Seq([
                    Map([]),
                    Map([("s'", Str("a\"\n'b"))]),
                    Map([
                      ("", Int(-7L)),
                      ("n\nl", Float(0.25)),
                      ("a", Str("x'")),
                      ("x y", Float(@double.not_a_number)),
                    ]),
                  ]),
                  Map([
                    ("x y", Int(1099511627776L)),
                    ("k-1", Str("a\\b")),
                    ("b", Str("a\"b")),
                  ]),
                ]),
              ]),
            ),
            (
              "a",
              Seq([
                Bool(true),
                Map([
                  (
                    "n\nl",
                    Seq([
                      Map([
                        ("b", Str("x")),
                        ("s'", Str("'''")),
                        ("a", Str("a\"b")),
                      ]),
                      Map([]),
                      Map([
                        ("x y", None),
                        ("", Str("\u{1}")),
                        ("q\"", Int(-7L)),
                        ("n\nl", Float(1.0e-09)),
                      ]),
                    ]),
                  ),
                ]),
                Seq([
                  Map([
                    (
                      "n\nl",
                      Map([
                        ("k-1", Str("\t")),
                        ("q\"", Str("x")),
                        ("", Int(1099511627776L)),
                      ]),
                    ),
                    ("z", Float(@double.infinity)),
                    ("\u{e9}", Map([("", None)])),
                  ]),
                  Map([("k-1", Map([("x y", Str("a\\b"))]))]),
                  Map([
                    ("z", Float(3.14159)),
                    ("x y", Seq([Float(1.0), Bool(false), Str("a\"\n'b")])),
                    ("a", Float(@double.not_a_number)),
                    ("q\"", Seq([Int(-7L)])),
                  ]),
                ]),
              ]),
            ),
            ("n\nl", Seq([Map([("", Str("\u{1}"))])])),
          ]),
          Map([
            (
              "\u{e9}",
              Seq([
                Map([
                  (
                    "",
                    Seq([
                      Map([
                        ("n\nl", Str("it's")),
                        ("", Str("")),
                        ("a", Str("x'")),
                      ]),
                      Map([
                        ("z", Float(1.0)),
                        ("s'", Bool(true)),
                        ("a", Map([("k-1", Str("'''")), ("b", Float(3.14159))])),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            ("n\nl", Seq([])),
            (
              "x y",
              Map([
                ("n\nl", Str("\t")),
                ("z", None),
                (
                  "b",
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([
                          ("x y", Str("'''")),
                          ("k-1", Str("a\"b")),
                          ("n\nl", Float(3.14159)),
                          ("", Float(3.14159)),
                        ]),
                        Map([
                          ("", Str("a\"\n'b")),
                          ("k-1", None),
                          ("s'", Str("x")),
                        ]),
                        Map([("q\"", Str("a\"b"))]),
                      ]),
                    ),
                    ("\u{e9}", Map([])),
                    (
                      "b",
                      Seq([
                        Map([
                          ("s'", Int(1099511627776L)),
                          ("z", Str("it's")),
                          ("q\"", Float(1.0)),
                        ]),
                      ]),
                    ),
                    ("x y", Seq([])),
                  ]),
                ),
              ]),
            ),
          ]),
        ]),
      ),
      (
        "\u{e9}",
        Map([
          (
            "a",
            Map([
              (
                "k-1",
                Map([
                  ("s'", Str("it's")),
                  (
                    "b",
                    Map([
                      ("q\"", Float(@double.not_a_number)),
                      ("n\nl", Str("'''")),
                      ("", Float(@double.infinity)),
                      ("s'", Bool(true)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          (
            "n\nl",
            Map([
              (
                "a",
                Seq([
                  Seq([
                    Map([
                      ("n\nl", Float(0.25)),
                      ("b", Str("x'")),
                      ("\u{e9}", Str("it's")),
                      ("a", Int(0L)),
                    ]),
                    Map([]),
                    Map([
                      ("n\nl", Float(@double.infinity)),
                      ("\u{e9}", Str("\u{e9}\u{4e2d}")),
                      ("z", Str("'''")),
                    ]),
                  ]),
                  Str("a\"b"),
                ]),
              ),
              ("s'", Str("x'")),
              ("n\nl", Int(1099511627776L)),
            ]),
          ),
          ("\u{e9}", Seq([Map([("z", Float(1.0e-09))])])),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "q\"",
        Map([
          ("", Seq([])),
          (
            "b",
            Seq([
              Map([
                ("q\"", Seq([])),
                (
                  "b",
                  Seq([
                    Map([
                      ("b", Str("a\"b")),
                      (
                        "",
                        Seq([
                          Map([
                            ("", Str("x'")),
                            ("x y", Bool(false)),
                            ("n\nl", Str("")),
                          ]),
                        ]),
                      ),
                    ]),
                    Map([
                      ("a", Float(1.0e-09)),
                      (
                        "q\"",
                        Seq([
                          Map([]),
                          Map([
                            ("n\nl", Float(1.0)),
                            ("x y", Int(-7L)),
                            ("z", Str("\u{1}")),
                            ("", Str("x'")),
                          ]),
                          Map([]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      ("\u{e9}", Map([("z", Seq([Map([])])), ("a", Map([]))])),
      ("k-1", Str("a\"b")),
      ("a", Str("\u{e9}\u{4e2d}")),
    ]),
    true,
    "k-1 = 'a\"b'\na = \"\u{e9}\u{4e2d}\"\n\n['q\"']\n\"\" = []\n\n[['q\"'.b]]\n'q\"' = []\n\n[['q\"'.b.b]]\nb = 'a\"b'\n\n[['q\"'.b.b.\"\"]]\n\"\" = \"x'\"\n\"x y\" = false\n\"n\\nl\" = \"\"\n\n[['q\"'.b.b]]\na = 0.000000001\n\n[['q\"'.b.b.'q\"']]\n\n[['q\"'.b.b.'q\"']]\n\"n\\nl\" = 1.0\n\"x y\" = -7\nz = \"\\u0001\"\n\"\" = \"x'\"\n\n[['q\"'.b.b.'q\"']]\n\n[[\"\u{e9}\".z]]\n\n[\"\u{e9}\".a]\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Map([
          ("", Seq([])),
          (
            "b",
            Seq([
              Map([
                ("q\"", Seq([])),
                (
                  "b",
                  Seq([
                    Map([
                      ("b", Str("a\"b")),
                      (
                        "",
                        Seq([
                          Map([
                            ("", Str("x'")),
                            ("x y", Bool(false)),
                            ("n\nl", Str("")),
                          ]),
                        ]),
                      ),
                    ]),
                    Map([
                      ("a", Float(1.0e-09)),
                      (
                        "q\"",
                        Seq([
                          Map([]),
                          Map([
                            ("n\nl", Float(1.0)),
                            ("x y", Int(-7L)),
                            ("z", Str("\u{1}")),
                            ("", Str("x'")),
                          ]),
                          Map([]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      ("\u{e9}", Map([("z", Seq([Map([])])), ("a", Map([]))])),
      ("k-1", Str("a\"b")),
      ("a", Str("\u{e9}\u{4e2d}")),
    ]),
    false,
    "k-1 = 'a\"b'\na = \"\u{e9}\u{4e2d}\"\n\n['q\"']\n\"\" = []\n\n[['q\"'.b]]\n'q\"' = []\n\n[['q\"'.b.b]]\nb = 'a\"b'\n\n[['q\"'.b.b.\"\"]]\n\"\" = \"x'\"\n\"x y\" = false\n\"n\\nl\" = \"\"\n\n[['q\"'.b.b]]\na = 0.000000001\n\n[['q\"'.b.b.'q\"']]\n\n[['q\"'.b.b.'q\"']]\n\"n\\nl\" = 1.0\n\"x y\" = -7\nz = \"\\u0001\"\n\"\" = \"x'\"\n\n[['q\"'.b.b.'q\"']]\n\n[[\"\u{e9}\".z]]\n\n[\"\u{e9}\".a]\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([("k-1", Str("l1\nl2")), ("x y", Seq([Str("'''"), Str("l1\nl2")]))]),
    true,
    "k-1 = \"\"\"\nl1\nl2\"\"\"\n\"x y\" = [\n    \"'''\",\n    \"\"\"\nl1\nl2\"\"\",\n]\n",
  )
  check_ser(
    Map([("k-1", Str("l1\nl2")), ("x y", Seq([Str("'''"), Str("l1\nl2")]))]),
    false,
    "k-1 = \"\"\"\nl1\nl2\"\"\"\n\"x y\" = [\"'''\", \"\"\"\nl1\nl2\"\"\"]\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Int(0L),
            Seq([
              Map([
                ("q\"", Seq([None, Bool(true)])),
                (
                  "n\nl",
                  Map([
                    ("z", Str("\u{e9}\u{4e2d}")),
                    ("s'", Int(1099511627776L)),
                    ("", Str("x'")),
                  ]),
                ),
                ("s'", Seq([Str(""), Str("x")])),
              ]),
              Map([
                ("k-1", Seq([Int(0L), Str("x'"), Float(0.25)])),
                (
                  "n\nl",
                  Seq([
                    Map([("a", Bool(false)), ("z", Str("\"'"))]),
                    Map([("b", Str("\t"))]),
                  ]),
                ),
              ]),
              Map([
                ("q\"", Seq([Str("'''")])),
                (
                  "k-1",
                  Seq([
                    Map([
                      ("\u{e9}", Float(@double.not_a_number)),
                      ("q\"", Str("")),
                      ("b", Float(3.14159)),
                      ("x y", Str("l1\nl2")),
                    ]),
                    Map([("x y", Float(@double.not_a_number))]),
                    Map([
                      ("x y", Str("\u{1}")),
                      ("", Float(@double.infinity)),
                      ("a", Str("a\"\n'b")),
                    ]),
                  ]),
                ),
              ]),
            ]),
            Str("x"),
          ]),
          Int(-7L),
          Float(@double.infinity),
        ]),
      ),
      ("q\"", Seq([Str("l1\nl2"), Str("'''"), Str("a\"b")])),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Int(0L),
            Seq([
              Map([
                ("q\"", Seq([None, Bool(true)])),
                (
                  "n\nl",
                  Map([
                    ("z", Str("\u{e9}\u{4e2d}")),
                    ("s'", Int(1099511627776L)),
                    ("", Str("x'")),
                  ]),
                ),
                ("s'", Seq([Str(""), Str("x")])),
              ]),
              Map([
                ("k-1", Seq([Int(0L), Str("x'"), Float(0.25)])),
                (
                  "n\nl",
                  Seq([
                    Map([("a", Bool(false)), ("z", Str("\"'"))]),
                    Map([("b", Str("\t"))]),
                  ]),
                ),
              ]),
              Map([
                ("q\"", Seq([Str("'''")])),
                (
                  "k-1",
                  Seq([
                    Map([
                      ("\u{e9}", Float(@double.not_a_number)),
                      ("q\"", Str("")),
                      ("b", Float(3.14159)),
                      ("x y", Str("l1\nl2")),
                    ]),
                    Map([("x y", Float(@double.not_a_number))]),
                    Map([
                      ("x y", Str("\u{1}")),
                      ("", Float(@double.infinity)),
                      ("a", Str("a\"\n'b")),
                    ]),
                  ]),
                ),
              ]),
            ]),
            Str("x"),
          ]),
          Int(-7L),
          Float(@double.infinity),
        ]),
      ),
      ("q\"", Seq([Str("l1\nl2"), Str("'''"), Str("a\"b")])),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([("q\"", Float(1.0e20)), ("b", Seq([]))]),
    true,
    "'q\"' = 100000000000000000000.0\nb = []\n",
  )
  check_ser(
    Map([("q\"", Float(1.0e20)), ("b", Seq([]))]),
    false,
    "'q\"' = 100000000000000000000.0\nb = []\n",
  )
  check_ser(
    Map([
      ("x y", Map([("q\"", Seq([Str("l1\nl2")])), ("n\nl", Seq([Bool(true)]))])),
      ("b", Bool(true)),
      ("a", Seq([])),
    ]),
    true,
    "b = true\na = []\n\n[\"x y\"]\n'q\"' = [\"\"\"\nl1\nl2\"\"\"]\n\"n\\nl\" = [true]\n",
  )
  check_ser(
    Map([
      ("x y", Map([("q\"", Seq([Str("l1\nl2")])), ("n\nl", Seq([Bool(true)]))])),
      ("b", Bool(true)),
      ("a", Seq([])),
    ]),
    false,
    "b = true\na = []\n\n[\"x y\"]\n'q\"' = [\"\"\"\nl1\nl2\"\"\"]\n\"n\\nl\" = [true]\n",
  )
  check_ser(
    Map([
      ("\u{e9}", None),
      ("z", Seq([Map([("x y", Seq([]))]), Str("a\"b")])),
      ("s'", Float(1.0e20)),
    ]),
    true,
    "z = [\n    { \"x y\" = [] },\n    'a\"b',\n]\n\"s'\" = 100000000000000000000.0\n",
  )
  check_ser(
    Map([
      ("\u{e9}", None),
      ("z", Seq([Map([("x y", Seq([]))]), Str("a\"b")])),
      ("s'", Float(1.0e20)),
    ]),
    false,
    "z = [{ \"x y\" = [] }, 'a\"b']\n\"s'\" = 100000000000000000000.0\n",
  )
  check_ser(
    Map([
      ("a", Float(3.14159)),
      ("b", Int(1099511627776L)),
      ("n\nl", Seq([Int(1099511627776L)])),
    ]),
    true,
    "a = 3.14159\nb = 1099511627776\n\"n\\nl\" = [1099511627776]\n",
  )
  check_ser(
    Map([
      ("a", Float(3.14159)),
      ("b", Int(1099511627776L)),
      ("n\nl", Seq([Int(1099511627776L)])),
    ]),
    false,
    "a = 3.14159\nb = 1099511627776\n\"n\\nl\" = [1099511627776]\n",
  )
  check_ser(
    Map([("b", Float(1.0e-09)), ("k-1", Str(""))]),
    true,
    "b = 0.000000001\nk-1 = \"\"\n",
  )
  check_ser(
    Map([("b", Float(1.0e-09)), ("k-1", Str(""))]),
    false,
    "b = 0.000000001\nk-1 = \"\"\n",
  )
  check_ser(
    Map([("x y", Float(1.0e20))]),
    true,
    "\"x y\" = 100000000000000000000.0\n",
  )
  check_ser(
    Map([("x y", Float(1.0e20))]),
    false,
    "\"x y\" = 100000000000000000000.0\n",
  )
  check_ser(
    Map([
      ("a", Seq([Float(-0.0), Seq([Map([])]), Str("\u{1}")])),
      ("b", Str("x'")),
    ]),
    true,
    "a = [\n    -0.0,\n    [{}],\n    \"\\u0001\",\n]\nb = \"x'\"\n",
  )
  check_ser(
    Map([
      ("a", Seq([Float(-0.0), Seq([Map([])]), Str("\u{1}")])),
      ("b", Str("x'")),
    ]),
    false,
    "a = [-0.0, [{}], \"\\u0001\"]\nb = \"x'\"\n",
  )
  check_ser(
    Map([
      (
        "",
        Seq([
          Map([("x y", Str("'''")), ("\u{e9}", Float(-0.0))]),
          Map([("z", Str("a\\b"))]),
          Map([]),
        ]),
      ),
    ]),
    true,
    "[[\"\"]]\n\"x y\" = \"'''\"\n\"\u{e9}\" = -0.0\n\n[[\"\"]]\nz = 'a\\b'\n\n[[\"\"]]\n",
  )
  check_ser(
    Map([
      (
        "",
        Seq([
          Map([("x y", Str("'''")), ("\u{e9}", Float(-0.0))]),
          Map([("z", Str("a\\b"))]),
          Map([]),
        ]),
      ),
    ]),
    false,
    "[[\"\"]]\n\"x y\" = \"'''\"\n\"\u{e9}\" = -0.0\n\n[[\"\"]]\nz = 'a\\b'\n\n[[\"\"]]\n",
  )
  check_ser(
    Map([
      (
        "\u{e9}",
        Map([
          (
            "a",
            Map([
              ("s'", Seq([Seq([Str("a\\b"), Float(1.0e20)])])),
              ("z", Str("x'")),
            ]),
          ),
          ("z", Seq([Seq([Float(@double.infinity)]), Float(@double.infinity)])),
          (
            "q\"",
            Map([
              (
                "b",
                Map([
                  ("a", Map([("x y", Str("\"'")), ("", Str("x"))])),
                  ("q\"", Map([("k-1", Bool(true)), ("b", Str("l1\nl2"))])),
                ]),
              ),
              ("x y", Str("\u{e9}\u{4e2d}")),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "[\"\u{e9}\"]\nz = [\n    [inf],\n    inf,\n]\n\n[\"\u{e9}\".a]\n\"s'\" = [[\n    'a\\b',\n    100000000000000000000.0,\n]]\nz = \"x'\"\n\n[\"\u{e9}\".'q\"']\n\"x y\" = \"\u{e9}\u{4e2d}\"\n\n[\"\u{e9}\".'q\"'.b.a]\n\"x y\" = \"\\\"'\"\n\"\" = \"x\"\n\n[\"\u{e9}\".'q\"'.b.'q\"']\nk-1 = true\nb = \"\"\"\nl1\nl2\"\"\"\n",
  )
  check_ser(
    Map([
      (
        "\u{e9}",
        Map([
          (
            "a",
            Map([
              ("s'", Seq([Seq([Str("a\\b"), Float(1.0e20)])])),
              ("z", Str("x'")),
            ]),
          ),
          ("z", Seq([Seq([Float(@double.infinity)]), Float(@double.infinity)])),
          (
            "q\"",
            Map([
              (
                "b",
                Map([
                  ("a", Map([("x y", Str("\"'")), ("", Str("x"))])),
                  ("q\"", Map([("k-1", Bool(true)), ("b", Str("l1\nl2"))])),
                ]),
              ),
              ("x y", Str("\u{e9}\u{4e2d}")),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "[\"\u{e9}\"]\nz = [[inf], inf]\n\n[\"\u{e9}\".a]\n\"s'\" = [['a\\b', 100000000000000000000.0]]\nz = \"x'\"\n\n[\"\u{e9}\".'q\"']\n\"x y\" = \"\u{e9}\u{4e2d}\"\n\n[\"\u{e9}\".'q\"'.b.a]\n\"x y\" = \"\\\"'\"\n\"\" = \"x\"\n\n[\"\u{e9}\".'q\"'.b.'q\"']\nk-1 = true\nb = \"\"\"\nl1\nl2\"\"\"\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Seq([Str("l1\nl2"), Seq([Str("x'"), Str("a\"\n'b")])]),
            None,
            Map([
              ("b", Seq([Str("")])),
              (
                "s'",
                Map([("\u{e9}", Bool(true)), ("b", Int(0L)), ("n\nl", Str(""))]),
              ),
            ]),
          ]),
        ]),
      ),
      (
        "a",
        Seq([
          Seq([
            Map([
              (
                "z",
                Seq([
                  Map([]),
                  Map([
                    ("n\nl", Str("\"'")),
                    ("s'", Str("a\\b")),
                    ("\u{e9}", Str("\u{1}")),
                  ]),
                ]),
              ),
            ]),
            Seq([Seq([Str(""), Float(@double.infinity)]), Int(-7L)]),
          ]),
          Seq([]),
          Map([
            ("\u{e9}", Map([("z", Seq([]))])),
            ("z", Str("l1\nl2")),
            ("a", Seq([Seq([Int(0L), Int(-7L), Float(1.0e-09)])])),
            ("k-1", Str("\u{1}")),
          ]),
        ]),
      ),
      ("q\"", Str("")),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Seq([Str("l1\nl2"), Seq([Str("x'"), Str("a\"\n'b")])]),
            None,
            Map([
              ("b", Seq([Str("")])),
              (
                "s'",
                Map([("\u{e9}", Bool(true)), ("b", Int(0L)), ("n\nl", Str(""))]),
              ),
            ]),
          ]),
        ]),
      ),
      (
        "a",
        Seq([
          Seq([
            Map([
              (
                "z",
                Seq([
                  Map([]),
                  Map([
                    ("n\nl", Str("\"'")),
                    ("s'", Str("a\\b")),
                    ("\u{e9}", Str("\u{1}")),
                  ]),
                ]),
              ),
            ]),
            Seq([Seq([Str(""), Float(@double.infinity)]), Int(-7L)]),
          ]),
          Seq([]),
          Map([
            ("\u{e9}", Map([("z", Seq([]))])),
            ("z", Str("l1\nl2")),
            ("a", Seq([Seq([Int(0L), Int(-7L), Float(1.0e-09)])])),
            ("k-1", Str("\u{1}")),
          ]),
        ]),
      ),
      ("q\"", Str("")),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Float(@double.infinity),
          Seq([
            Map([
              ("", Str("\u{e9}\u{4e2d}")),
              ("a", Seq([])),
              ("n\nl", Float(1.0e-09)),
              ("s'", Str("\u{1}")),
            ]),
          ]),
          Bool(true),
        ]),
      ),
      ("s'", Int(0L)),
    ]),
    true,
    "z = [\n    inf,\n    [{ \"\" = \"\u{e9}\u{4e2d}\", a = [], \"n\\nl\" = 0.000000001, \"s'\" = \"\\u0001\" }],\n    true,\n]\n\"s'\" = 0\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Float(@double.infinity),
          Seq([
            Map([
              ("", Str("\u{e9}\u{4e2d}")),
              ("a", Seq([])),
              ("n\nl", Float(1.0e-09)),
              ("s'", Str("\u{1}")),
            ]),
          ]),
          Bool(true),
        ]),
      ),
      ("s'", Int(0L)),
    ]),
    false,
    "z = [inf, [{ \"\" = \"\u{e9}\u{4e2d}\", a = [], \"n\\nl\" = 0.000000001, \"s'\" = \"\\u0001\" }], true]\n\"s'\" = 0\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Map([
            ("s'", Seq([Int(0L)])),
            ("q\"", Int(-7L)),
            (
              "\u{e9}",
              Seq([
                Seq([Str(""), Str("\t"), Str("a\\b")]),
                Seq([Str("x"), Int(-7L)]),
              ]),
            ),
          ]),
          Seq([]),
          Seq([
            Map([
              ("n\nl", Map([("z", Str("a\\b")), ("s'", Str("\t"))])),
              ("q\"", Map([("k-1", Float(1.0))])),
              ("z", Map([])),
            ]),
            Seq([
              Map([]),
              Map([
                (
                  "q\"",
                  Map([("\u{e9}", Str("l1\nl2")), ("q\"", Float(1.0e20))]),
                ),
                ("x y", Str("\t")),
              ]),
              Map([
                ("k-1", Str("'''")),
                ("\u{e9}", Seq([Str("\"'")])),
                ("z", Float(1.0)),
              ]),
            ]),
          ]),
        ]),
      ),
    ]),
    true,
    "'q\"' = [\n    { \"s'\" = [0], 'q\"' = -7, \"\u{e9}\" = [\n    [\n    \"\",\n    \"\\t\",\n    'a\\b',\n],\n    [\n    \"x\",\n    -7,\n],\n] },\n    [],\n    [\n    { \"n\\nl\" = { z = 'a\\b', \"s'\" = \"\\t\" }, 'q\"' = { k-1 = 1.0 }, z = {} },\n    [\n    {},\n    { 'q\"' = { \"\u{e9}\" = \"\"\"\nl1\nl2\"\"\", 'q\"' = 100000000000000000000.0 }, \"x y\" = \"\\t\" },\n    { k-1 = \"'''\", \"\u{e9}\" = [\"\\\"'\"], z = 1.0 },\n],\n],\n]\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Map([
            ("s'", Seq([Int(0L)])),
            ("q\"", Int(-7L)),
            (
              "\u{e9}",
              Seq([
                Seq([Str(""), Str("\t"), Str("a\\b")]),
                Seq([Str("x"), Int(-7L)]),
              ]),
            ),
          ]),
          Seq([]),
          Seq([
            Map([
              ("n\nl", Map([("z", Str("a\\b")), ("s'", Str("\t"))])),
              ("q\"", Map([("k-1", Float(1.0))])),
              ("z", Map([])),
            ]),
            Seq([
              Map([]),
              Map([
                (
                  "q\"",
                  Map([("\u{e9}", Str("l1\nl2")), ("q\"", Float(1.0e20))]),
                ),
                ("x y", Str("\t")),
              ]),
              Map([
                ("k-1", Str("'''")),
                ("\u{e9}", Seq([Str("\"'")])),
                ("z", Float(1.0)),
              ]),
            ]),
          ]),
        ]),
      ),
    ]),
    false,
    "'q\"' = [{ \"s'\" = [0], 'q\"' = -7, \"\u{e9}\" = [[\"\", \"\\t\", 'a\\b'], [\"x\", -7]] }, [], [{ \"n\\nl\" = { z = 'a\\b', \"s'\" = \"\\t\" }, 'q\"' = { k-1 = 1.0 }, z = {} }, [{}, { 'q\"' = { \"\u{e9}\" = \"\"\"\nl1\nl2\"\"\", 'q\"' = 100000000000000000000.0 }, \"x y\" = \"\\t\" }, { k-1 = \"'''\", \"\u{e9}\" = [\"\\\"'\"], z = 1.0 }]]]\n",
  )
  check_ser(
    Map([
      ("b", Seq([Float(3.14159), Map([])])),
      (
        "n\nl",
        Seq([
          Map([
            (
              "k-1",
              Seq([Seq([Map([("x y", Str("a\"b"))]), Int(-7L)]), Str("a\\b")]),
            ),
            ("n\nl", Int(-7L)),
          ]),
        ]),
      ),
    ]),
    true,
    "b = [\n    3.14159,\n    {},\n]\n\n[[\"n\\nl\"]]\nk-1 = [\n    [\n    { \"x y\" = 'a\"b' },\n    -7,\n],\n    'a\\b',\n]\n\"n\\nl\" = -7\n",
  )
  check_ser(
    Map([
      ("b", Seq([Float(3.14159), Map([])])),
      (
        "n\nl",
        Seq([
          Map([
            (
              "k-1",
              Seq([Seq([Map([("x y", Str("a\"b"))]), Int(-7L)]), Str("a\\b")]),
            ),
            ("n\nl", Int(-7L)),
          ]),
        ]),
      ),
    ]),
    false,
    "b = [3.14159, {}]\n\n[[\"n\\nl\"]]\nk-1 = [[{ \"x y\" = 'a\"b' }, -7], 'a\\b']\n\"n\\nl\" = -7\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Map([("z", Float(@double.infinity)), ("k-1", Str("\t"))]),
          Map([("z", Seq([])), ("k-1", Str("\u{1}"))]),
          Map([("b", Seq([])), ("n\nl", Seq([Seq([Map([])])]))]),
        ]),
      ),
      ("", Str("\"'")),
    ]),
    true,
    "\"\" = \"\\\"'\"\n\n[[z]]\nz = inf\nk-1 = \"\\t\"\n\n[[z]]\nz = []\nk-1 = \"\\u0001\"\n\n[[z]]\nb = []\n\"n\\nl\" = [[{}]]\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Map([("z", Float(@double.infinity)), ("k-1", Str("\t"))]),
          Map([("z", Seq([])), ("k-1", Str("\u{1}"))]),
          Map([("b", Seq([])), ("n\nl", Seq([Seq([Map([])])]))]),
        ]),
      ),
      ("", Str("\"'")),
    ]),
    false,
    "\"\" = \"\\\"'\"\n\n[[z]]\nz = inf\nk-1 = \"\\t\"\n\n[[z]]\nz = []\nk-1 = \"\\u0001\"\n\n[[z]]\nb = []\n\"n\\nl\" = [[{}]]\n",
  )
  check_ser(
    Map([
      ("x y", Int(0L)),
      (
        "b",
        Map([
          (
            "b",
            Seq([
              Seq([
                Map([
                  (
                    "\u{e9}",
                    Seq([Float(@double.infinity), Float(1.0), Int(-7L)]),
                  ),
                  ("x y", Float(-0.0)),
                  ("q\"", Seq([Bool(true), Str("\"'"), None])),
                ]),
              ]),
              Str("x'"),
              Int(-7L),
            ]),
          ),
          (
            "x y",
            Seq([
              Map([
                (
                  "q\"",
                  Seq([
                    Map([]),
                    Map([
                      ("s'", Str("it's")),
                      ("\u{e9}", Float(1.0e20)),
                      ("q\"", Map([])),
                    ]),
                    Map([]),
                  ]),
                ),
                (
                  "s'",
                  Seq([
                    Str("x'"),
                    Map([
                      ("q\"", Str("a\"b")),
                      ("z", Int(-7L)),
                      ("n\nl", Str("\t")),
                    ]),
                    Map([("n\nl", Str("\"'"))]),
                  ]),
                ),
              ]),
              Map([
                ("s'", Float(1.0)),
                ("z", Seq([Float(@double.infinity), Float(1.0)])),
              ]),
              Map([]),
            ]),
          ),
        ]),
      ),
      ("z", Str("it's")),
      ("q\"", Map([("b", Str("l1\nl2"))])),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("x y", Int(0L)),
      (
        "b",
        Map([
          (
            "b",
            Seq([
              Seq([
                Map([
                  (
                    "\u{e9}",
                    Seq([Float(@double.infinity), Float(1.0), Int(-7L)]),
                  ),
                  ("x y", Float(-0.0)),
                  ("q\"", Seq([Bool(true), Str("\"'"), None])),
                ]),
              ]),
              Str("x'"),
              Int(-7L),
            ]),
          ),
          (
            "x y",
            Seq([
              Map([
                (
                  "q\"",
                  Seq([
                    Map([]),
                    Map([
                      ("s'", Str("it's")),
                      ("\u{e9}", Float(1.0e20)),
                      ("q\"", Map([])),
                    ]),
                    Map([]),
                  ]),
                ),
                (
                  "s'",
                  Seq([
                    Str("x'"),
                    Map([
                      ("q\"", Str("a\"b")),
                      ("z", Int(-7L)),
                      ("n\nl", Str("\t")),
                    ]),
                    Map([("n\nl", Str("\"'"))]),
                  ]),
                ),
              ]),
              Map([
                ("s'", Float(1.0)),
                ("z", Seq([Float(@double.infinity), Float(1.0)])),
              ]),
              Map([]),
            ]),
          ),
        ]),
      ),
      ("z", Str("it's")),
      ("q\"", Map([("b", Str("l1\nl2"))])),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      ("q\"", Seq([Seq([]), Str("l1\nl2"), Seq([Float(1.0e-09)])])),
      ("s'", Seq([])),
      (
        "",
        Seq([
          Seq([Str("a\"\n'b")]),
          Seq([
            Map([
              ("z", Seq([Bool(false)])),
              ("k-1", Seq([])),
              ("\u{e9}", Str("\"'")),
              (
                "",
                Seq([
                  Map([("k-1", Int(-7L)), ("s'", Str(""))]),
                  Map([
                    ("z", Str("a\"b")),
                    ("\u{e9}", None),
                    ("n\nl", Float(0.25)),
                  ]),
                  Map([
                    ("b", Float(1.0e20)),
                    ("a", Str("\u{1}")),
                    ("n\nl", Str("a\\b")),
                    ("q\"", Str("a\"\n'b")),
                  ]),
                ]),
              ),
            ]),
            Str("l1\nl2"),
            Seq([Str("x"), Seq([]), Bool(true)]),
          ]),
          Seq([]),
        ]),
      ),
      ("b", Seq([Seq([Map([("n\nl", Float(1.0))])]), Float(@double.infinity)])),
    ]),
    true,
    "'q\"' = [\n    [],\n    \"\"\"\nl1\nl2\"\"\",\n    [0.000000001],\n]\n\"s'\" = []\n\"\" = [\n    ['''\na\"\n'b'''],\n    [\n    { z = [false], k-1 = [], \"\u{e9}\" = \"\\\"'\", \"\" = [\n    { k-1 = -7, \"s'\" = \"\" },\n    { z = 'a\"b', \"n\\nl\" = 0.25 },\n    { b = 100000000000000000000.0, a = \"\\u0001\", \"n\\nl\" = 'a\\b', 'q\"' = '''\na\"\n'b''' },\n] },\n    \"\"\"\nl1\nl2\"\"\",\n    [\n    \"x\",\n    [],\n    true,\n],\n],\n    [],\n]\nb = [\n    [{ \"n\\nl\" = 1.0 }],\n    inf,\n]\n",
  )
  check_ser(
    Map([
      ("q\"", Seq([Seq([]), Str("l1\nl2"), Seq([Float(1.0e-09)])])),
      ("s'", Seq([])),
      (
        "",
        Seq([
          Seq([Str("a\"\n'b")]),
          Seq([
            Map([
              ("z", Seq([Bool(false)])),
              ("k-1", Seq([])),
              ("\u{e9}", Str("\"'")),
              (
                "",
                Seq([
                  Map([("k-1", Int(-7L)), ("s'", Str(""))]),
                  Map([
                    ("z", Str("a\"b")),
                    ("\u{e9}", None),
                    ("n\nl", Float(0.25)),
                  ]),
                  Map([
                    ("b", Float(1.0e20)),
                    ("a", Str("\u{1}")),
                    ("n\nl", Str("a\\b")),
                    ("q\"", Str("a\"\n'b")),
                  ]),
                ]),
              ),
            ]),
            Str("l1\nl2"),
            Seq([Str("x"), Seq([]), Bool(true)]),
          ]),
          Seq([]),
        ]),
      ),
      ("b", Seq([Seq([Map([("n\nl", Float(1.0))])]), Float(@double.infinity)])),
    ]),
    false,
    "'q\"' = [[], \"\"\"\nl1\nl2\"\"\", [0.000000001]]\n\"s'\" = []\n\"\" = [['''\na\"\n'b'''], [{ z = [false], k-1 = [], \"\u{e9}\" = \"\\\"'\", \"\" = [{ k-1 = -7, \"s'\" = \"\" }, { z = 'a\"b', \"n\\nl\" = 0.25 }, { b = 100000000000000000000.0, a = \"\\u0001\", \"n\\nl\" = 'a\\b', 'q\"' = '''\na\"\n'b''' }] }, \"\"\"\nl1\nl2\"\"\", [\"x\", [], true]], []]\nb = [[{ \"n\\nl\" = 1.0 }], inf]\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Map([
            ("q\"", Map([])),
            ("k-1", Str("a\"\n'b")),
            (
              "a",
              Map([
                ("q\"", Seq([Int(-7L), Str("x'")])),
                ("x y", Bool(true)),
                ("\u{e9}", Str("")),
              ]),
            ),
          ]),
          Float(1.0),
        ]),
      ),
      ("", None),
    ]),
    true,
    "'q\"' = [\n    { 'q\"' = {}, k-1 = '''\na\"\n'b''', a = { 'q\"' = [\n    -7,\n    \"x'\",\n], \"x y\" = true, \"\u{e9}\" = \"\" } },\n    1.0,\n]\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Map([
            ("q\"", Map([])),
            ("k-1", Str("a\"\n'b")),
            (
              "a",
              Map([
                ("q\"", Seq([Int(-7L), Str("x'")])),
                ("x y", Bool(true)),
                ("\u{e9}", Str("")),
              ]),
            ),
          ]),
          Float(1.0),
        ]),
      ),
      ("", None),
    ]),
    false,
    "'q\"' = [{ 'q\"' = {}, k-1 = '''\na\"\n'b''', a = { 'q\"' = [-7, \"x'\"], \"x y\" = true, \"\u{e9}\" = \"\" } }, 1.0]\n",
  )
  check_ser(Map([("", Str("\t"))]), true, "\"\" = \"\\t\"\n")
  check_ser(Map([("", Str("\t"))]), false, "\"\" = \"\\t\"\n")
  check_ser(
    Map([
      ("q\"", Str("a\"\n'b")),
      ("z", Float(1.0e20)),
      (
        "",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Map([
                  (
                    "a",
                    Seq([
                      Map([
                        ("n\nl", Map([("x y", Str("'''"))])),
                        (
                          "b",
                          Map([
                            ("q\"", Float(1.0e-09)),
                            ("b", Str("x")),
                            ("z", Str("x")),
                            ("\u{e9}", Str("l1\nl2")),
                          ]),
                        ),
                        ("z", Seq([None, Int(-7L), Bool(true)])),
                      ]),
                      Map([
                        ("q\"", Seq([])),
                        (
                          "x y",
                          Seq([Float(0.25), Str("\u{e9}\u{4e2d}"), Str("x'")]),
                        ),
                      ]),
                    ]),
                  ),
                  ("k-1", Seq([Map([]), Seq([])])),
                  ("\u{e9}", Seq([])),
                ]),
                Map([
                  (
                    "k-1",
                    Map([
                      ("q\"", Str("a\\b")),
                      (
                        "k-1",
                        Seq([
                          Map([
                            ("s'", Str("\u{e9}\u{4e2d}")),
                            ("x y", Float(@double.not_a_number)),
                            ("a", Bool(false)),
                          ]),
                          Map([("a", Bool(false))]),
                          Map([("z", Str("\u{e9}\u{4e2d}")), ("a", Str("\"'"))]),
                        ]),
                      ),
                      ("a", Seq([Str("a\"b"), Float(@double.infinity)])),
                    ]),
                  ),
                  ("\u{e9}", Map([("\u{e9}", Map([("\u{e9}", Float(-0.0))]))])),
                ]),
                Map([("", Map([("n\nl", Float(1.0e20)), ("z", Str("x"))]))]),
              ]),
            ),
            ("", Map([("k-1", Map([("b", Float(1.0))]))])),
          ]),
          Map([
            (
              "k-1",
              Map([
                ("b", Str("\t")),
                ("x y", Seq([])),
                (
                  "",
                  Seq([
                    Map([
                      (
                        "n\nl",
                        Map([
                          ("\u{e9}", Bool(false)),
                          ("x y", Str("")),
                          ("n\nl", Str("l1\nl2")),
                        ]),
                      ),
                      ("k-1", Seq([])),
                    ]),
                    Map([("a", Float(1.0))]),
                    Map([
                      ("z", Float(1.0e20)),
                      ("", Map([("", None), ("s'", Bool(false))])),
                      ("\u{e9}", Seq([Str("a\"\n'b"), Float(1.0)])),
                      ("a", Int(-7L)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
          Map([
            (
              "z",
              Seq([
                Map([]),
                Map([
                  ("a", Map([("z", Str("a\"b")), ("", None)])),
                  ("n\nl", Float(0.25)),
                ]),
                Map([
                  (
                    "q\"",
                    Map([
                      (
                        "n\nl",
                        Seq([Str("\u{e9}\u{4e2d}"), Float(@double.not_a_number)]),
                      ),
                      ("k-1", Map([("n\nl", Bool(true))])),
                      ("\u{e9}", Float(1.0e-09)),
                      ("q\"", Float(3.14159)),
                    ]),
                  ),
                  ("z", Seq([])),
                  ("a", Float(3.14159)),
                  ("n\nl", Seq([Seq([Str("\t")]), Seq([None, Float(0.25)])])),
                ]),
              ]),
            ),
            ("x y", Seq([Float(1.0)])),
            ("s'", Str("a\"\n'b")),
            ("q\"", Map([])),
          ]),
        ]),
      ),
      ("k-1", Map([])),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("q\"", Str("a\"\n'b")),
      ("z", Float(1.0e20)),
      (
        "",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Map([
                  (
                    "a",
                    Seq([
                      Map([
                        ("n\nl", Map([("x y", Str("'''"))])),
                        (
                          "b",
                          Map([
                            ("q\"", Float(1.0e-09)),
                            ("b", Str("x")),
                            ("z", Str("x")),
                            ("\u{e9}", Str("l1\nl2")),
                          ]),
                        ),
                        ("z", Seq([None, Int(-7L), Bool(true)])),
                      ]),
                      Map([
                        ("q\"", Seq([])),
                        (
                          "x y",
                          Seq([Float(0.25), Str("\u{e9}\u{4e2d}"), Str("x'")]),
                        ),
                      ]),
                    ]),
                  ),
                  ("k-1", Seq([Map([]), Seq([])])),
                  ("\u{e9}", Seq([])),
                ]),
                Map([
                  (
                    "k-1",
                    Map([
                      ("q\"", Str("a\\b")),
                      (
                        "k-1",
                        Seq([
                          Map([
                            ("s'", Str("\u{e9}\u{4e2d}")),
                            ("x y", Float(@double.not_a_number)),
                            ("a", Bool(false)),
                          ]),
                          Map([("a", Bool(false))]),
                          Map([("z", Str("\u{e9}\u{4e2d}")), ("a", Str("\"'"))]),
                        ]),
                      ),
                      ("a", Seq([Str("a\"b"), Float(@double.infinity)])),
                    ]),
                  ),
                  ("\u{e9}", Map([("\u{e9}", Map([("\u{e9}", Float(-0.0))]))])),
                ]),
                Map([("", Map([("n\nl", Float(1.0e20)), ("z", Str("x"))]))]),
              ]),
            ),
            ("", Map([("k-1", Map([("b", Float(1.0))]))])),
          ]),
          Map([
            (
              "k-1",
              Map([
                ("b", Str("\t")),
                ("x y", Seq([])),
                (
                  "",
                  Seq([
                    Map([
                      (
                        "n\nl",
                        Map([
                          ("\u{e9}", Bool(false)),
                          ("x y", Str("")),
                          ("n\nl", Str("l1\nl2")),
                        ]),
                      ),
                      ("k-1", Seq([])),
                    ]),
                    Map([("a", Float(1.0))]),
                    Map([
                      ("z", Float(1.0e20)),
                      ("", Map([("", None), ("s'", Bool(false))])),
                      ("\u{e9}", Seq([Str("a\"\n'b"), Float(1.0)])),
                      ("a", Int(-7L)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
          Map([
            (
              "z",
              Seq([
                Map([]),
                Map([
                  ("a", Map([("z", Str("a\"b")), ("", None)])),
                  ("n\nl", Float(0.25)),
                ]),
                Map([
                  (
                    "q\"",
                    Map([
                      (
                        "n\nl",
                        Seq([Str("\u{e9}\u{4e2d}"), Float(@double.not_a_number)]),
                      ),
                      ("k-1", Map([("n\nl", Bool(true))])),
                      ("\u{e9}", Float(1.0e-09)),
                      ("q\"", Float(3.14159)),
                    ]),
                  ),
                  ("z", Seq([])),
                  ("a", Float(3.14159)),
                  ("n\nl", Seq([Seq([Str("\t")]), Seq([None, Float(0.25)])])),
                ]),
              ]),
            ),
            ("x y", Seq([Float(1.0)])),
            ("s'", Str("a\"\n'b")),
            ("q\"", Map([])),
          ]),
        ]),
      ),
      ("k-1", Map([])),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("q\"", Map([])),
      ("k-1", Str("x")),
      (
        "s'",
        Seq([
          Seq([
            Map([
              ("", Map([("q\"", Str("a\\b")), ("x y", Str("l1\nl2"))])),
              ("b", Str("l1\nl2")),
              ("\u{e9}", Float(3.14159)),
            ]),
          ]),
          Map([
            ("a", Map([("b", None), ("z", Str("'''"))])),
            (
              "n\nl",
              Seq([
                Map([
                  ("b", Float(@double.infinity)),
                  ("q\"", Seq([Str("a\"\n'b"), Str("a\"\n'b"), Int(0L)])),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    true,
    "k-1 = \"x\"\n\"s'\" = [\n    [{ \"\" = { 'q\"' = 'a\\b', \"x y\" = \"\"\"\nl1\nl2\"\"\" }, b = \"\"\"\nl1\nl2\"\"\", \"\u{e9}\" = 3.14159 }],\n    { a = { z = \"'''\" }, \"n\\nl\" = [{ b = inf, 'q\"' = [\n    '''\na\"\n'b''',\n    '''\na\"\n'b''',\n    0,\n] }] },\n]\n\n['q\"']\n",
  )
  check_ser(
    Map([
      ("q\"", Map([])),
      ("k-1", Str("x")),
      (
        "s'",
        Seq([
          Seq([
            Map([
              ("", Map([("q\"", Str("a\\b")), ("x y", Str("l1\nl2"))])),
              ("b", Str("l1\nl2")),
              ("\u{e9}", Float(3.14159)),
            ]),
          ]),
          Map([
            ("a", Map([("b", None), ("z", Str("'''"))])),
            (
              "n\nl",
              Seq([
                Map([
                  ("b", Float(@double.infinity)),
                  ("q\"", Seq([Str("a\"\n'b"), Str("a\"\n'b"), Int(0L)])),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    false,
    "k-1 = \"x\"\n\"s'\" = [[{ \"\" = { 'q\"' = 'a\\b', \"x y\" = \"\"\"\nl1\nl2\"\"\" }, b = \"\"\"\nl1\nl2\"\"\", \"\u{e9}\" = 3.14159 }], { a = { z = \"'''\" }, \"n\\nl\" = [{ b = inf, 'q\"' = ['''\na\"\n'b''', '''\na\"\n'b''', 0] }] }]\n\n['q\"']\n",
  )
  check_ser(
    Map([
      ("s'", Seq([Float(1.0e-09), Float(-0.0)])),
      ("a", Bool(true)),
      ("", Str("a\"b")),
    ]),
    true,
    "\"s'\" = [\n    0.000000001,\n    -0.0,\n]\na = true\n\"\" = 'a\"b'\n",
  )
  check_ser(
    Map([
      ("s'", Seq([Float(1.0e-09), Float(-0.0)])),
      ("a", Bool(true)),
      ("", Str("a\"b")),
    ]),
    false,
    "\"s'\" = [0.000000001, -0.0]\na = true\n\"\" = 'a\"b'\n",
  )
  check_ser(
    Map([("a", Str("it's")), ("x y", Seq([Float(@double.not_a_number)]))]),
    true,
    "a = \"it's\"\n\"x y\" = [nan]\n",
  )
  check_ser(
    Map([("a", Str("it's")), ("x y", Seq([Float(@double.not_a_number)]))]),
    false,
    "a = \"it's\"\n\"x y\" = [nan]\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("\u{e9}", Str("a\"b"))]), true, "\"\u{e9}\" = 'a\"b'\n")
  check_ser(Map([("\u{e9}", Str("a\"b"))]), false, "\"\u{e9}\" = 'a\"b'\n")
  check_ser(
    Map([
      (
        "n\nl",
        Map([
          (
            "x y",
            Map([
              ("q\"", Float(3.14159)),
              (
                "k-1",
                Map([
                  (
                    "n\nl",
                    Seq([
                      Map([("", Str("\u{1}"))]),
                      Map([
                        ("", Str("\t")),
                        ("s'", Str("a\"b")),
                        ("q\"", Float(@double.infinity)),
                      ]),
                      Map([
                        ("n\nl", None),
                        ("b", Float(@double.not_a_number)),
                        ("k-1", Str("\u{e9}\u{4e2d}")),
                      ]),
                    ]),
                  ),
                  ("z", None),
                  ("k-1", Map([])),
                  ("x y", Float(@double.not_a_number)),
                ]),
              ),
              ("a", Int(0L)),
            ]),
          ),
          (
            "s'",
            Seq([
              Seq([Map([("a", Seq([Str("")])), ("b", Float(1.0e-09))])]),
              Map([
                ("", Str("\"'")),
                ("s'", Seq([Str("\u{1}"), Str("a\\b"), Int(-7L)])),
                ("a", Float(@double.infinity)),
              ]),
              Map([]),
            ]),
          ),
          (
            "z",
            Seq([
              Map([
                ("k-1", Str("\u{1}")),
                (
                  "b",
                  Seq([
                    Map([("\u{e9}", Str("'''"))]),
                    Seq([
                      Map([("k-1", Int(-7L)), ("q\"", Float(@double.infinity))]),
                    ]),
                    Seq([
                      Map([
                        ("b", Float(-0.0)),
                        ("k-1", Float(@double.not_a_number)),
                        ("s'", Float(0.25)),
                        ("q\"", Float(1.0e-09)),
                      ]),
                    ]),
                  ]),
                ),
                ("s'", Map([])),
                (
                  "z",
                  Seq([
                    Map([
                      ("s'", Bool(false)),
                      ("a", Int(1099511627776L)),
                      ("", Str("")),
                      ("q\"", Str("it's")),
                    ]),
                  ]),
                ),
              ]),
              Map([("", Seq([])), ("q\"", Seq([]))]),
            ]),
          ),
        ]),
      ),
      ("q\"", Float(0.25)),
      ("\u{e9}", Str("l1\nl2")),
    ]),
    true,
    "'q\"' = 0.25\n\"\u{e9}\" = \"\"\"\nl1\nl2\"\"\"\n\n[\"n\\nl\"]\n\"s'\" = [\n    [{ a = [\"\"], b = 0.000000001 }],\n    { \"\" = \"\\\"'\", \"s'\" = [\n    \"\\u0001\",\n    'a\\b',\n    -7,\n], a = inf },\n    {},\n]\n\n[\"n\\nl\".\"x y\"]\n'q\"' = 3.14159\na = 0\n\n[\"n\\nl\".\"x y\".k-1]\n\"x y\" = nan\n\n[[\"n\\nl\".\"x y\".k-1.\"n\\nl\"]]\n\"\" = \"\\u0001\"\n\n[[\"n\\nl\".\"x y\".k-1.\"n\\nl\"]]\n\"\" = \"\\t\"\n\"s'\" = 'a\"b'\n'q\"' = inf\n\n[[\"n\\nl\".\"x y\".k-1.\"n\\nl\"]]\nb = nan\nk-1 = \"\u{e9}\u{4e2d}\"\n\n[\"n\\nl\".\"x y\".k-1.k-1]\n\n[[\"n\\nl\".z]]\nk-1 = \"\\u0001\"\nb = [\n    { \"\u{e9}\" = \"'''\" },\n    [{ k-1 = -7, 'q\"' = inf }],\n    [{ b = -0.0, k-1 = nan, \"s'\" = 0.25, 'q\"' = 0.000000001 }],\n]\n\n[\"n\\nl\".z.\"s'\"]\n\n[[\"n\\nl\".z.z]]\n\"s'\" = false\na = 1099511627776\n\"\" = \"\"\n'q\"' = \"it's\"\n\n[[\"n\\nl\".z]]\n\"\" = []\n'q\"' = []\n",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Map([
          (
            "x y",
            Map([
              ("q\"", Float(3.14159)),
              (
                "k-1",
                Map([
                  (
                    "n\nl",
                    Seq([
                      Map([("", Str("\u{1}"))]),
                      Map([
                        ("", Str("\t")),
                        ("s'", Str("a\"b")),
                        ("q\"", Float(@double.infinity)),
                      ]),
                      Map([
                        ("n\nl", None),
                        ("b", Float(@double.not_a_number)),
                        ("k-1", Str("\u{e9}\u{4e2d}")),
                      ]),
                    ]),
                  ),
                  ("z", None),
                  ("k-1", Map([])),
                  ("x y", Float(@double.not_a_number)),
                ]),
              ),
              ("a", Int(0L)),
            ]),
          ),
          (
            "s'",
            Seq([
              Seq([Map([("a", Seq([Str("")])), ("b", Float(1.0e-09))])]),
              Map([
                ("", Str("\"'")),
                ("s'", Seq([Str("\u{1}"), Str("a\\b"), Int(-7L)])),
                ("a", Float(@double.infinity)),
              ]),
              Map([]),
            ]),
          ),
          (
            "z",
            Seq([
              Map([
                ("k-1", Str("\u{1}")),
                (
                  "b",
                  Seq([
                    Map([("\u{e9}", Str("'''"))]),
                    Seq([
                      Map([("k-1", Int(-7L)), ("q\"", Float(@double.infinity))]),
                    ]),
                    Seq([
                      Map([
                        ("b", Float(-0.0)),
                        ("k-1", Float(@double.not_a_number)),
                        ("s'", Float(0.25)),
                        ("q\"", Float(1.0e-09)),
                      ]),
                    ]),
                  ]),
                ),
                ("s'", Map([])),
                (
                  "z",
                  Seq([
                    Map([
                      ("s'", Bool(false)),
                      ("a", Int(1099511627776L)),
                      ("", Str("")),
                      ("q\"", Str("it's")),
                    ]),
                  ]),
                ),
              ]),
              Map([("", Seq([])), ("q\"", Seq([]))]),
            ]),
          ),
        ]),
      ),
      ("q\"", Float(0.25)),
      ("\u{e9}", Str("l1\nl2")),
    ]),
    false,
    "'q\"' = 0.25\n\"\u{e9}\" = \"\"\"\nl1\nl2\"\"\"\n\n[\"n\\nl\"]\n\"s'\" = [[{ a = [\"\"], b = 0.000000001 }], { \"\" = \"\\\"'\", \"s'\" = [\"\\u0001\", 'a\\b', -7], a = inf }, {}]\n\n[\"n\\nl\".\"x y\"]\n'q\"' = 3.14159\na = 0\n\n[\"n\\nl\".\"x y\".k-1]\n\"x y\" = nan\n\n[[\"n\\nl\".\"x y\".k-1.\"n\\nl\"]]\n\"\" = \"\\u0001\"\n\n[[\"n\\nl\".\"x y\".k-1.\"n\\nl\"]]\n\"\" = \"\\t\"\n\"s'\" = 'a\"b'\n'q\"' = inf\n\n[[\"n\\nl\".\"x y\".k-1.\"n\\nl\"]]\nb = nan\nk-1 = \"\u{e9}\u{4e2d}\"\n\n[\"n\\nl\".\"x y\".k-1.k-1]\n\n[[\"n\\nl\".z]]\nk-1 = \"\\u0001\"\nb = [{ \"\u{e9}\" = \"'''\" }, [{ k-1 = -7, 'q\"' = inf }], [{ b = -0.0, k-1 = nan, \"s'\" = 0.25, 'q\"' = 0.000000001 }]]\n\n[\"n\\nl\".z.\"s'\"]\n\n[[\"n\\nl\".z.z]]\n\"s'\" = false\na = 1099511627776\n\"\" = \"\"\n'q\"' = \"it's\"\n\n[[\"n\\nl\".z]]\n\"\" = []\n'q\"' = []\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("a", Int(-7L))]), true, "a = -7\n")
  check_ser(Map([("a", Int(-7L))]), false, "a = -7\n")
  check_ser(
    Map([
      ("b", Str("x'")),
      (
        "q\"",
        Map([
          (
            "z",
            Map([("n\nl", Seq([Seq([Str("x'"), Str("a\"\n'b"), Str("it's")])]))]),
          ),
          ("b", Map([])),
          (
            "a",
            Map([
              ("b", Seq([])),
              (
                "a",
                Seq([
                  Map([
                    ("z", Map([("s'", Str("x'")), ("x y", Str("a\"\n'b"))])),
                    ("k-1", Seq([])),
                  ]),
                  Map([("s'", Float(3.14159)), ("k-1", Float(@double.infinity))]),
                  Map([("x y", Str("l1\nl2")), ("k-1", Seq([]))]),
                ]),
              ),
            ]),
          ),
          (
            "x y",
            Seq([
              Map([
                (
                  "k-1",
                  Seq([
                    Seq([Bool(true), Str("\t"), Float(1.0)]),
                    Map([("x y", Float(0.25))]),
                  ]),
                ),
                (
                  "a",
                  Map([
                    ("k-1", Seq([Str("x'"), Int(0L), Float(3.14159)])),
                    ("q\"", Str("a\"\n'b")),
                    ("s'", Map([("k-1", Float(@double.infinity))])),
                    ("\u{e9}", Float(0.25)),
                  ]),
                ),
              ]),
              Map([
                (
                  "k-1",
                  Seq([
                    Seq([
                      Map([
                        ("", Str("l1\nl2")),
                        ("a", Int(-7L)),
                        ("z", Str("x")),
                      ]),
                      Map([("s'", Float(1.0e20)), ("k-1", Str("a\"\n'b"))]),
                      Map([
                        ("a", Float(1.0e20)),
                        ("k-1", Str("'''")),
                        ("n\nl", Int(-7L)),
                        ("q\"", Float(1.0e-09)),
                      ]),
                    ]),
                  ]),
                ),
                (
                  "s'",
                  Map([
                    ("n\nl", None),
                    (
                      "k-1",
                      Seq([
                        Map([("b", Float(@double.infinity))]),
                        Map([("x y", None), ("q\"", Float(1.0e-09))]),
                      ]),
                    ),
                    ("q\"", Str("a\\b")),
                    (
                      "",
                      Map([
                        ("", Int(0L)),
                        ("b", Float(3.14159)),
                        ("x y", Float(@double.infinity)),
                      ]),
                    ),
                  ]),
                ),
                ("z", Seq([])),
              ]),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "b = \"x'\"\n\n['q\"'.z]\n\"n\\nl\" = [[\n    \"x'\",\n    '''\na\"\n'b''',\n    \"it's\",\n]]\n\n['q\"'.b]\n\n['q\"'.a]\nb = []\n\n[['q\"'.a.a]]\nk-1 = []\n\n['q\"'.a.a.z]\n\"s'\" = \"x'\"\n\"x y\" = '''\na\"\n'b'''\n\n[['q\"'.a.a]]\n\"s'\" = 3.14159\nk-1 = inf\n\n[['q\"'.a.a]]\n\"x y\" = \"\"\"\nl1\nl2\"\"\"\nk-1 = []\n\n[['q\"'.\"x y\"]]\nk-1 = [\n    [\n    true,\n    \"\\t\",\n    1.0,\n],\n    { \"x y\" = 0.25 },\n]\n\n['q\"'.\"x y\".a]\nk-1 = [\n    \"x'\",\n    0,\n    3.14159,\n]\n'q\"' = '''\na\"\n'b'''\n\"\u{e9}\" = 0.25\n\n['q\"'.\"x y\".a.\"s'\"]\nk-1 = inf\n\n[['q\"'.\"x y\"]]\nk-1 = [[\n    { \"\" = \"\"\"\nl1\nl2\"\"\", a = -7, z = \"x\" },\n    { \"s'\" = 100000000000000000000.0, k-1 = '''\na\"\n'b''' },\n    { a = 100000000000000000000.0, k-1 = \"'''\", \"n\\nl\" = -7, 'q\"' = 0.000000001 },\n]]\nz = []\n\n['q\"'.\"x y\".\"s'\"]\n'q\"' = 'a\\b'\n\n[['q\"'.\"x y\".\"s'\".k-1]]\nb = inf\n\n[['q\"'.\"x y\".\"s'\".k-1]]\n'q\"' = 0.000000001\n\n['q\"'.\"x y\".\"s'\".\"\"]\n\"\" = 0\nb = 3.14159\n\"x y\" = inf\n",
  )
  check_ser(
    Map([
      ("b", Str("x'")),
      (
        "q\"",
        Map([
          (
            "z",
            Map([("n\nl", Seq([Seq([Str("x'"), Str("a\"\n'b"), Str("it's")])]))]),
          ),
          ("b", Map([])),
          (
            "a",
            Map([
              ("b", Seq([])),
              (
                "a",
                Seq([
                  Map([
                    ("z", Map([("s'", Str("x'")), ("x y", Str("a\"\n'b"))])),
                    ("k-1", Seq([])),
                  ]),
                  Map([("s'", Float(3.14159)), ("k-1", Float(@double.infinity))]),
                  Map([("x y", Str("l1\nl2")), ("k-1", Seq([]))]),
                ]),
              ),
            ]),
          ),
          (
            "x y",
            Seq([
              Map([
                (
                  "k-1",
                  Seq([
                    Seq([Bool(true), Str("\t"), Float(1.0)]),
                    Map([("x y", Float(0.25))]),
                  ]),
                ),
                (
                  "a",
                  Map([
                    ("k-1", Seq([Str("x'"), Int(0L), Float(3.14159)])),
                    ("q\"", Str("a\"\n'b")),
                    ("s'", Map([("k-1", Float(@double.infinity))])),
                    ("\u{e9}", Float(0.25)),
                  ]),
                ),
              ]),
              Map([
                (
                  "k-1",
                  Seq([
                    Seq([
                      Map([
                        ("", Str("l1\nl2")),
                        ("a", Int(-7L)),
                        ("z", Str("x")),
                      ]),
                      Map([("s'", Float(1.0e20)), ("k-1", Str("a\"\n'b"))]),
                      Map([
                        ("a", Float(1.0e20)),
                        ("k-1", Str("'''")),
                        ("n\nl", Int(-7L)),
                        ("q\"", Float(1.0e-09)),
                      ]),
                    ]),
                  ]),
                ),
                (
                  "s'",
                  Map([
                    ("n\nl", None),
                    (
                      "k-1",
                      Seq([
                        Map([("b", Float(@double.infinity))]),
                        Map([("x y", None), ("q\"", Float(1.0e-09))]),
                      ]),
                    ),
                    ("q\"", Str("a\\b")),
                    (
                      "",
                      Map([
                        ("", Int(0L)),
                        ("b", Float(3.14159)),
                        ("x y", Float(@double.infinity)),
                      ]),
                    ),
                  ]),
                ),
                ("z", Seq([])),
              ]),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "b = \"x'\"\n\n['q\"'.z]\n\"n\\nl\" = [[\"x'\", '''\na\"\n'b''', \"it's\"]]\n\n['q\"'.b]\n\n['q\"'.a]\nb = []\n\n[['q\"'.a.a]]\nk-1 = []\n\n['q\"'.a.a.z]\n\"s'\" = \"x'\"\n\"x y\" = '''\na\"\n'b'''\n\n[['q\"'.a.a]]\n\"s'\" = 3.14159\nk-1 = inf\n\n[['q\"'.a.a]]\n\"x y\" = \"\"\"\nl1\nl2\"\"\"\nk-1 = []\n\n[['q\"'.\"x y\"]]\nk-1 = [[true, \"\\t\", 1.0], { \"x y\" = 0.25 }]\n\n['q\"'.\"x y\".a]\nk-1 = [\"x'\", 0, 3.14159]\n'q\"' = '''\na\"\n'b'''\n\"\u{e9}\" = 0.25\n\n['q\"'.\"x y\".a.\"s'\"]\nk-1 = inf\n\n[['q\"'.\"x y\"]]\nk-1 = [[{ \"\" = \"\"\"\nl1\nl2\"\"\", a = -7, z = \"x\" }, { \"s'\" = 100000000000000000000.0, k-1 = '''\na\"\n'b''' }, { a = 100000000000000000000.0, k-1 = \"'''\", \"n\\nl\" = -7, 'q\"' = 0.000000001 }]]\nz = []\n\n['q\"'.\"x y\".\"s'\"]\n'q\"' = 'a\\b'\n\n[['q\"'.\"x y\".\"s'\".k-1]]\nb = inf\n\n[['q\"'.\"x y\".\"s'\".k-1]]\n'q\"' = 0.000000001\n\n['q\"'.\"x y\".\"s'\".\"\"]\n\"\" = 0\nb = 3.14159\n\"x y\" = inf\n",
  )
  check_ser(Map([("", Str("it's"))]), true, "\"\" = \"it's\"\n")
  check_ser(Map([("", Str("it's"))]), false, "\"\" = \"it's\"\n")
  check_ser(
    Map([
      (
        "",
        Seq([
          Float(0.25),
          Seq([
            Map([
              (
                "",
                Seq([
                  Map([
                    ("k-1", Float(@double.not_a_number)),
                    ("a", Float(1.0)),
                    ("\u{e9}", Str("\u{1}")),
                  ]),
                  Float(3.14159),
                  Seq([
                    Map([("k-1", Float(@double.infinity)), ("x y", Str("it's"))]),
                    Map([
                      ("x y", Bool(true)),
                      ("\u{e9}", Str("")),
                      ("a", Str("x'")),
                    ]),
                    Map([("z", Str("x'")), ("q\"", Int(1099511627776L))]),
                  ]),
                ]),
              ),
            ]),
            Map([]),
          ]),
        ]),
      ),
      ("a", Seq([])),
      ("q\"", Bool(true)),
      ("x y", Str("a\\b")),
    ]),
    true,
    "\"\" = [\n    0.25,\n    [\n    { \"\" = [\n    { k-1 = nan, a = 1.0, \"\u{e9}\" = \"\\u0001\" },\n    3.14159,\n    [\n    { k-1 = inf, \"x y\" = \"it's\" },\n    { \"x y\" = true, \"\u{e9}\" = \"\", a = \"x'\" },\n    { z = \"x'\", 'q\"' = 1099511627776 },\n],\n] },\n    {},\n],\n]\na = []\n'q\"' = true\n\"x y\" = 'a\\b'\n",
  )
  check_ser(
    Map([
      (
        "",
        Seq([
          Float(0.25),
          Seq([
            Map([
              (
                "",
                Seq([
                  Map([
                    ("k-1", Float(@double.not_a_number)),
                    ("a", Float(1.0)),
                    ("\u{e9}", Str("\u{1}")),
                  ]),
                  Float(3.14159),
                  Seq([
                    Map([("k-1", Float(@double.infinity)), ("x y", Str("it's"))]),
                    Map([
                      ("x y", Bool(true)),
                      ("\u{e9}", Str("")),
                      ("a", Str("x'")),
                    ]),
                    Map([("z", Str("x'")), ("q\"", Int(1099511627776L))]),
                  ]),
                ]),
              ),
            ]),
            Map([]),
          ]),
        ]),
      ),
      ("a", Seq([])),
      ("q\"", Bool(true)),
      ("x y", Str("a\\b")),
    ]),
    false,
    "\"\" = [0.25, [{ \"\" = [{ k-1 = nan, a = 1.0, \"\u{e9}\" = \"\\u0001\" }, 3.14159, [{ k-1 = inf, \"x y\" = \"it's\" }, { \"x y\" = true, \"\u{e9}\" = \"\", a = \"x'\" }, { z = \"x'\", 'q\"' = 1099511627776 }]] }, {}]]\na = []\n'q\"' = true\n\"x y\" = 'a\\b'\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "\u{e9}",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Map([
                  ("q\"", Str("\u{e9}\u{4e2d}")),
                  ("a", Float(0.25)),
                  ("b", Float(0.25)),
                ]),
                Seq([
                  Map([
                    ("", Str("x'")),
                    ("a", Seq([Int(-7L), Float(@double.not_a_number)])),
                    ("n\nl", Str("it's")),
                  ]),
                  Map([
                    (
                      "a",
                      Seq([
                        Map([]),
                        Map([("k-1", Float(1.0)), ("b", Str("\t"))]),
                      ]),
                    ),
                    ("z", Seq([])),
                  ]),
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([]),
                        Map([("q\"", Float(1.0)), ("k-1", Str("l1\nl2"))]),
                        Map([("n\nl", Str("a\"\n'b")), ("", Float(-0.0))]),
                      ]),
                    ),
                  ]),
                ]),
                Seq([
                  Map([
                    (
                      "k-1",
                      Seq([
                        Map([("z", Str("it's")), ("x y", Float(1.0))]),
                        Map([
                          ("a", Float(0.25)),
                          ("k-1", Bool(true)),
                          ("z", Float(0.25)),
                        ]),
                      ]),
                    ),
                    ("", Float(0.25)),
                  ]),
                  Map([
                    (
                      "a",
                      Seq([
                        Map([
                          ("q\"", Float(@double.infinity)),
                          ("z", Float(0.25)),
                        ]),
                      ]),
                    ),
                    ("", Seq([Float(@double.infinity)])),
                    ("k-1", Seq([])),
                  ]),
                  Map([
                    (
                      "b",
                      Seq([
                        Map([
                          ("", Float(1.0e-09)),
                          ("a", Str("a\"\n'b")),
                          ("z", Float(3.14159)),
                        ]),
                      ]),
                    ),
                    ("q\"", Seq([Str("\u{1}"), Float(1.0)])),
                  ]),
                ]),
              ]),
            ),
          ]),
          Map([
            ("q\"", Int(0L)),
            (
              "b",
              Map([
                (
                  "\u{e9}",
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([
                          ("a", Float(1.0)),
                          ("b", Str("\t")),
                          ("s'", Str("a\"\n'b")),
                        ]),
                      ]),
                    ),
                    (
                      "k-1",
                      Seq([
                        Int(1099511627776L),
                        Float(1.0),
                        Str("\u{e9}\u{4e2d}"),
                      ]),
                    ),
                    ("\u{e9}", Str("")),
                  ]),
                ),
              ]),
            ),
            ("k-1", Str("a\"b")),
          ]),
        ]),
      ),
      ("a", Float(1.0e20)),
      ("x y", Float(1.0e20)),
    ]),
    true,
    "\"s'\" = []\na = 100000000000000000000.0\n\"x y\" = 100000000000000000000.0\n\n[[\"\u{e9}\"]]\n\"x y\" = [\n    { 'q\"' = \"\u{e9}\u{4e2d}\", a = 0.25, b = 0.25 },\n    [\n    { \"\" = \"x'\", a = [\n    -7,\n    nan,\n], \"n\\nl\" = \"it's\" },\n    { a = [\n    {},\n    { k-1 = 1.0, b = \"\\t\" },\n], z = [] },\n    { 'q\"' = [\n    {},\n    { 'q\"' = 1.0, k-1 = \"\"\"\nl1\nl2\"\"\" },\n    { \"n\\nl\" = '''\na\"\n'b''', \"\" = -0.0 },\n] },\n],\n    [\n    { k-1 = [\n    { z = \"it's\", \"x y\" = 1.0 },\n    { a = 0.25, k-1 = true, z = 0.25 },\n], \"\" = 0.25 },\n    { a = [{ 'q\"' = inf, z = 0.25 }], \"\" = [inf], k-1 = [] },\n    { b = [{ \"\" = 0.000000001, a = '''\na\"\n'b''', z = 3.14159 }], 'q\"' = [\n    \"\\u0001\",\n    1.0,\n] },\n],\n]\n\n[[\"\u{e9}\"]]\n'q\"' = 0\nk-1 = 'a\"b'\n\n[\"\u{e9}\".b.\"\u{e9}\"]\nk-1 = [\n    1099511627776,\n    1.0,\n    \"\u{e9}\u{4e2d}\",\n]\n\"\u{e9}\" = \"\"\n\n[[\"\u{e9}\".b.\"\u{e9}\".'q\"']]\na = 1.0\nb = \"\\t\"\n\"s'\" = '''\na\"\n'b'''\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "\u{e9}",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Map([
                  ("q\"", Str("\u{e9}\u{4e2d}")),
                  ("a", Float(0.25)),
                  ("b", Float(0.25)),
                ]),
                Seq([
                  Map([
                    ("", Str("x'")),
                    ("a", Seq([Int(-7L), Float(@double.not_a_number)])),
                    ("n\nl", Str("it's")),
                  ]),
                  Map([
                    (
                      "a",
                      Seq([
                        Map([]),
                        Map([("k-1", Float(1.0)), ("b", Str("\t"))]),
                      ]),
                    ),
                    ("z", Seq([])),
                  ]),
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([]),
                        Map([("q\"", Float(1.0)), ("k-1", Str("l1\nl2"))]),
                        Map([("n\nl", Str("a\"\n'b")), ("", Float(-0.0))]),
                      ]),
                    ),
                  ]),
                ]),
                Seq([
                  Map([
                    (
                      "k-1",
                      Seq([
                        Map([("z", Str("it's")), ("x y", Float(1.0))]),
                        Map([
                          ("a", Float(0.25)),
                          ("k-1", Bool(true)),
                          ("z", Float(0.25)),
                        ]),
                      ]),
                    ),
                    ("", Float(0.25)),
                  ]),
                  Map([
                    (
                      "a",
                      Seq([
                        Map([
                          ("q\"", Float(@double.infinity)),
                          ("z", Float(0.25)),
                        ]),
                      ]),
                    ),
                    ("", Seq([Float(@double.infinity)])),
                    ("k-1", Seq([])),
                  ]),
                  Map([
                    (
                      "b",
                      Seq([
                        Map([
                          ("", Float(1.0e-09)),
                          ("a", Str("a\"\n'b")),
                          ("z", Float(3.14159)),
                        ]),
                      ]),
                    ),
                    ("q\"", Seq([Str("\u{1}"), Float(1.0)])),
                  ]),
                ]),
              ]),
            ),
          ]),
          Map([
            ("q\"", Int(0L)),
            (
              "b",
              Map([
                (
                  "\u{e9}",
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([
                          ("a", Float(1.0)),
                          ("b", Str("\t")),
                          ("s'", Str("a\"\n'b")),
                        ]),
                      ]),
                    ),
                    (
                      "k-1",
                      Seq([
                        Int(1099511627776L),
                        Float(1.0),
                        Str("\u{e9}\u{4e2d}"),
                      ]),
                    ),
                    ("\u{e9}", Str("")),
                  ]),
                ),
              ]),
            ),
            ("k-1", Str("a\"b")),
          ]),
        ]),
      ),
      ("a", Float(1.0e20)),
      ("x y", Float(1.0e20)),
    ]),
    false,
    "\"s'\" = []\na = 100000000000000000000.0\n\"x y\" = 100000000000000000000.0\n\n[[\"\u{e9}\"]]\n\"x y\" = [{ 'q\"' = \"\u{e9}\u{4e2d}\", a = 0.25, b = 0.25 }, [{ \"\" = \"x'\", a = [-7, nan], \"n\\nl\" = \"it's\" }, { a = [{}, { k-1 = 1.0, b = \"\\t\" }], z = [] }, { 'q\"' = [{}, { 'q\"' = 1.0, k-1 = \"\"\"\nl1\nl2\"\"\" }, { \"n\\nl\" = '''\na\"\n'b''', \"\" = -0.0 }] }], [{ k-1 = [{ z = \"it's\", \"x y\" = 1.0 }, { a = 0.25, k-1 = true, z = 0.25 }], \"\" = 0.25 }, { a = [{ 'q\"' = inf, z = 0.25 }], \"\" = [inf], k-1 = [] }, { b = [{ \"\" = 0.000000001, a = '''\na\"\n'b''', z = 3.14159 }], 'q\"' = [\"\\u0001\", 1.0] }]]\n\n[[\"\u{e9}\"]]\n'q\"' = 0\nk-1 = 'a\"b'\n\n[\"\u{e9}\".b.\"\u{e9}\"]\nk-1 = [1099511627776, 1.0, \"\u{e9}\u{4e2d}\"]\n\"\u{e9}\" = \"\"\n\n[[\"\u{e9}\".b.\"\u{e9}\".'q\"']]\na = 1.0\nb = \"\\t\"\n\"s'\" = '''\na\"\n'b'''\n",
  )
  check_ser(Map([("k-1", Int(1099511627776L))]), true, "k-1 = 1099511627776\n")
  check_ser(Map([("k-1", Int(1099511627776L))]), false, "k-1 = 1099511627776\n")
  check_ser(
    Map([
      ("q\"", Str("x'")),
      (
        "k-1",
        Seq([
          Seq([
            Map([
              (
                "k-1",
                Seq([Bool(false), Seq([Map([("z", Int(-7L))])]), Seq([])]),
              ),
              ("z", Map([])),
              (
                "\u{e9}",
                Seq([
                  Seq([
                    Map([("n\nl", Str("x'"))]),
                    Map([
                      ("q\"", Str("")),
                      ("n\nl", Float(1.0e-09)),
                      ("z", Bool(true)),
                    ]),
                  ]),
                ]),
              ),
            ]),
            Map([]),
            Map([
              (
                "z",
                Seq([Seq([Float(1.0), Str("a\"b")]), Float(1.0), Float(-0.0)]),
              ),
              ("", Str("a\"\n'b")),
            ]),
          ]),
        ]),
      ),
      (
        "b",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Map([
                  ("a", Seq([])),
                  (
                    "",
                    Seq([
                      Map([("q\"", Str("\u{e9}\u{4e2d}"))]),
                      Map([
                        ("\u{e9}", Seq([])),
                        (
                          "k-1",
                          Seq([Str("\"'"), Str("x"), Float(@double.infinity)]),
                        ),
                        ("n\nl", Map([])),
                      ]),
                      Map([
                        ("q\"", Seq([None])),
                        ("n\nl", Seq([Float(1.0e-09)])),
                        ("a", Map([("s'", Int(1099511627776L))])),
                        ("s'", Float(0.25)),
                      ]),
                    ]),
                  ),
                  ("n\nl", Seq([])),
                ]),
                Map([
                  ("b", Float(@double.not_a_number)),
                  ("s'", Seq([])),
                  (
                    "n\nl",
                    Seq([Map([("x y", Str("a\"\n'b"))]), Str("\t"), Str("x")]),
                  ),
                  (
                    "z",
                    Seq([Seq([Map([("b", Str("a\\b")), ("a", Str("l1\nl2"))])])]),
                  ),
                ]),
              ]),
            ),
            ("\u{e9}", Str("it's")),
            ("k-1", Seq([])),
            (
              "q\"",
              Seq([
                Map([]),
                Map([
                  (
                    "\u{e9}",
                    Map([
                      ("s'", Map([("q\"", Str("x'"))])),
                      ("b", Map([("a", Str("a\\b")), ("\u{e9}", Str("'''"))])),
                    ]),
                  ),
                ]),
                Map([]),
              ]),
            ),
          ]),
          Map([]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("q\"", Str("x'")),
      (
        "k-1",
        Seq([
          Seq([
            Map([
              (
                "k-1",
                Seq([Bool(false), Seq([Map([("z", Int(-7L))])]), Seq([])]),
              ),
              ("z", Map([])),
              (
                "\u{e9}",
                Seq([
                  Seq([
                    Map([("n\nl", Str("x'"))]),
                    Map([
                      ("q\"", Str("")),
                      ("n\nl", Float(1.0e-09)),
                      ("z", Bool(true)),
                    ]),
                  ]),
                ]),
              ),
            ]),
            Map([]),
            Map([
              (
                "z",
                Seq([Seq([Float(1.0), Str("a\"b")]), Float(1.0), Float(-0.0)]),
              ),
              ("", Str("a\"\n'b")),
            ]),
          ]),
        ]),
      ),
      (
        "b",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Map([
                  ("a", Seq([])),
                  (
                    "",
                    Seq([
                      Map([("q\"", Str("\u{e9}\u{4e2d}"))]),
                      Map([
                        ("\u{e9}", Seq([])),
                        (
                          "k-1",
                          Seq([Str("\"'"), Str("x"), Float(@double.infinity)]),
                        ),
                        ("n\nl", Map([])),
                      ]),
                      Map([
                        ("q\"", Seq([None])),
                        ("n\nl", Seq([Float(1.0e-09)])),
                        ("a", Map([("s'", Int(1099511627776L))])),
                        ("s'", Float(0.25)),
                      ]),
                    ]),
                  ),
                  ("n\nl", Seq([])),
                ]),
                Map([
                  ("b", Float(@double.not_a_number)),
                  ("s'", Seq([])),
                  (
                    "n\nl",
                    Seq([Map([("x y", Str("a\"\n'b"))]), Str("\t"), Str("x")]),
                  ),
                  (
                    "z",
                    Seq([Seq([Map([("b", Str("a\\b")), ("a", Str("l1\nl2"))])])]),
                  ),
                ]),
              ]),
            ),
            ("\u{e9}", Str("it's")),
            ("k-1", Seq([])),
            (
              "q\"",
              Seq([
                Map([]),
                Map([
                  (
                    "\u{e9}",
                    Map([
                      ("s'", Map([("q\"", Str("x'"))])),
                      ("b", Map([("a", Str("a\\b")), ("\u{e9}", Str("'''"))])),
                    ]),
                  ),
                ]),
                Map([]),
              ]),
            ),
          ]),
          Map([]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("q\"", Seq([Int(0L)])),
      (
        "",
        Seq([
          Map([("\u{e9}", Map([("a", None)]))]),
          Map([("z", Seq([]))]),
          Map([
            (
              "z",
              Seq([
                Map([("a", Str("\u{e9}\u{4e2d}"))]),
                Seq([
                  Map([
                    ("a", Float(1.0e20)),
                    ("q\"", Float(-0.0)),
                    ("n\nl", Str("a\\b")),
                  ]),
                  None,
                ]),
              ]),
            ),
            (
              "k-1",
              Map([
                (
                  "k-1",
                  Seq([
                    Map([
                      ("", Seq([None])),
                      (
                        "b",
                        Seq([
                          Map([
                            ("q\"", Float(@double.infinity)),
                            ("s'", Str("x")),
                          ]),
                          Map([("", Float(-0.0))]),
                          Map([]),
                        ]),
                      ),
                    ]),
                    Map([
                      (
                        "a",
                        Seq([
                          Map([
                            ("s'", Str("x'")),
                            ("x y", Float(@double.not_a_number)),
                            ("z", Str("l1\nl2")),
                          ]),
                        ]),
                      ),
                      ("", Float(1.0)),
                      ("k-1", Float(1.0e-09)),
                    ]),
                    Map([("b", Str("x'")), ("n\nl", Float(1.0e-09))]),
                  ]),
                ),
                ("n\nl", Seq([])),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("q\"", Seq([Int(0L)])),
      (
        "",
        Seq([
          Map([("\u{e9}", Map([("a", None)]))]),
          Map([("z", Seq([]))]),
          Map([
            (
              "z",
              Seq([
                Map([("a", Str("\u{e9}\u{4e2d}"))]),
                Seq([
                  Map([
                    ("a", Float(1.0e20)),
                    ("q\"", Float(-0.0)),
                    ("n\nl", Str("a\\b")),
                  ]),
                  None,
                ]),
              ]),
            ),
            (
              "k-1",
              Map([
                (
                  "k-1",
                  Seq([
                    Map([
                      ("", Seq([None])),
                      (
                        "b",
                        Seq([
                          Map([
                            ("q\"", Float(@double.infinity)),
                            ("s'", Str("x")),
                          ]),
                          Map([("", Float(-0.0))]),
                          Map([]),
                        ]),
                      ),
                    ]),
                    Map([
                      (
                        "a",
                        Seq([
                          Map([
                            ("s'", Str("x'")),
                            ("x y", Float(@double.not_a_number)),
                            ("z", Str("l1\nl2")),
                          ]),
                        ]),
                      ),
                      ("", Float(1.0)),
                      ("k-1", Float(1.0e-09)),
                    ]),
                    Map([("b", Str("x'")), ("n\nl", Float(1.0e-09))]),
                  ]),
                ),
                ("n\nl", Seq([])),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([
            (
              "b",
              Map([
                ("x y", Str("a\"\n'b")),
                ("", Str("\"'")),
                ("\u{e9}", Seq([Seq([]), Float(3.14159), Str("\u{1}")])),
              ]),
            ),
            ("s'", Float(-0.0)),
            ("", Seq([Str("\t")])),
          ]),
          Map([
            ("z", Str("a\"\n'b")),
            (
              "b",
              Map([
                (
                  "s'",
                  Seq([
                    Map([
                      ("a", Str("x'")),
                      ("\u{e9}", Str("\u{1}")),
                      ("q\"", Str("a\\b")),
                    ]),
                  ]),
                ),
                ("q\"", Str("\t")),
                ("n\nl", Str("x")),
                ("b", Seq([Seq([Float(1.0)]), Float(@double.infinity)])),
              ]),
            ),
          ]),
        ]),
      ),
      ("x y", Str("it's")),
    ]),
    true,
    "\"x y\" = \"it's\"\n\n[[k-1]]\n\"s'\" = -0.0\n\"\" = [\"\\t\"]\n\n[k-1.b]\n\"x y\" = '''\na\"\n'b'''\n\"\" = \"\\\"'\"\n\"\u{e9}\" = [\n    [],\n    3.14159,\n    \"\\u0001\",\n]\n\n[[k-1]]\nz = '''\na\"\n'b'''\n\n[k-1.b]\n'q\"' = \"\\t\"\n\"n\\nl\" = \"x\"\nb = [\n    [1.0],\n    inf,\n]\n\n[[k-1.b.\"s'\"]]\na = \"x'\"\n\"\u{e9}\" = \"\\u0001\"\n'q\"' = 'a\\b'\n",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([
            (
              "b",
              Map([
                ("x y", Str("a\"\n'b")),
                ("", Str("\"'")),
                ("\u{e9}", Seq([Seq([]), Float(3.14159), Str("\u{1}")])),
              ]),
            ),
            ("s'", Float(-0.0)),
            ("", Seq([Str("\t")])),
          ]),
          Map([
            ("z", Str("a\"\n'b")),
            (
              "b",
              Map([
                (
                  "s'",
                  Seq([
                    Map([
                      ("a", Str("x'")),
                      ("\u{e9}", Str("\u{1}")),
                      ("q\"", Str("a\\b")),
                    ]),
                  ]),
                ),
                ("q\"", Str("\t")),
                ("n\nl", Str("x")),
                ("b", Seq([Seq([Float(1.0)]), Float(@double.infinity)])),
              ]),
            ),
          ]),
        ]),
      ),
      ("x y", Str("it's")),
    ]),
    false,
    "\"x y\" = \"it's\"\n\n[[k-1]]\n\"s'\" = -0.0\n\"\" = [\"\\t\"]\n\n[k-1.b]\n\"x y\" = '''\na\"\n'b'''\n\"\" = \"\\\"'\"\n\"\u{e9}\" = [[], 3.14159, \"\\u0001\"]\n\n[[k-1]]\nz = '''\na\"\n'b'''\n\n[k-1.b]\n'q\"' = \"\\t\"\n\"n\\nl\" = \"x\"\nb = [[1.0], inf]\n\n[[k-1.b.\"s'\"]]\na = \"x'\"\n\"\u{e9}\" = \"\\u0001\"\n'q\"' = 'a\\b'\n",
  )
  check_ser(
    Map([
      ("q\"", Seq([Seq([Map([("n\nl", Seq([]))])])])),
      ("k-1", Map([])),
      ("a", Float(0.25)),
      ("x y", Seq([Float(3.14159)])),
    ]),
    true,
    "'q\"' = [[{ \"n\\nl\" = [] }]]\na = 0.25\n\"x y\" = [3.14159]\n\n[k-1]\n",
  )
  check_ser(
    Map([
      ("q\"", Seq([Seq([Map([("n\nl", Seq([]))])])])),
      ("k-1", Map([])),
      ("a", Float(0.25)),
      ("x y", Seq([Float(3.14159)])),
    ]),
    false,
    "'q\"' = [[{ \"n\\nl\" = [] }]]\na = 0.25\n\"x y\" = [3.14159]\n\n[k-1]\n",
  )
  check_ser(Map([("z", Seq([]))]), true, "z = []\n")
  check_ser(Map([("z", Seq([]))]), false, "z = []\n")
  check_ser(Map([("z", Int(1099511627776L))]), true, "z = 1099511627776\n")
  check_ser(Map([("z", Int(1099511627776L))]), false, "z = 1099511627776\n")
  check_ser(
    Map([("b", Str("x'")), ("", Seq([]))]),
    true,
    "b = \"x'\"\n\"\" = []\n",
  )
  check_ser(
    Map([("b", Str("x'")), ("", Seq([]))]),
    false,
    "b = \"x'\"\n\"\" = []\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Map([("a", Int(1099511627776L))]),
            Seq([
              Map([
                (
                  "k-1",
                  Seq([
                    Map([("b", Str("it's"))]),
                    Map([
                      ("q\"", Str("'''")),
                      ("n\nl", Float(3.14159)),
                      ("s'", Int(-7L)),
                    ]),
                  ]),
                ),
              ]),
            ]),
            Seq([
              Map([
                (
                  "a",
                  Map([("z", Str("")), ("x y", Float(@double.not_a_number))]),
                ),
                ("s'", Seq([])),
                (
                  "\u{e9}",
                  Seq([
                    Map([("", Str("a\"\n'b"))]),
                    Map([
                      ("s'", Int(-7L)),
                      ("z", Str("\u{1}")),
                      ("b", Str("l1\nl2")),
                      ("q\"", Str("\"'")),
                    ]),
                    Map([]),
                  ]),
                ),
              ]),
            ]),
          ]),
          None,
          Seq([Map([("n\nl", Float(1.0))])]),
        ]),
      ),
      ("q\"", Float(0.25)),
      ("\u{e9}", Str("a\"\n'b")),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Map([("a", Int(1099511627776L))]),
            Seq([
              Map([
                (
                  "k-1",
                  Seq([
                    Map([("b", Str("it's"))]),
                    Map([
                      ("q\"", Str("'''")),
                      ("n\nl", Float(3.14159)),
                      ("s'", Int(-7L)),
                    ]),
                  ]),
                ),
              ]),
            ]),
            Seq([
              Map([
                (
                  "a",
                  Map([("z", Str("")), ("x y", Float(@double.not_a_number))]),
                ),
                ("s'", Seq([])),
                (
                  "\u{e9}",
                  Seq([
                    Map([("", Str("a\"\n'b"))]),
                    Map([
                      ("s'", Int(-7L)),
                      ("z", Str("\u{1}")),
                      ("b", Str("l1\nl2")),
                      ("q\"", Str("\"'")),
                    ]),
                    Map([]),
                  ]),
                ),
              ]),
            ]),
          ]),
          None,
          Seq([Map([("n\nl", Float(1.0))])]),
        ]),
      ),
      ("q\"", Float(0.25)),
      ("\u{e9}", Str("a\"\n'b")),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(Map([("q\"", Int(0L))]), true, "'q\"' = 0\n")
  check_ser(Map([("q\"", Int(0L))]), false, "'q\"' = 0\n")
  check_ser(
    Map([
      (
        "s'",
        Map([
          ("b", Map([])),
          ("k-1", Seq([])),
          (
            "\u{e9}",
            Seq([
              Map([("", None)]),
              Map([
                ("\u{e9}", Int(-7L)),
                ("", Float(0.25)),
                ("z", Seq([Map([("", Str("'''"))])])),
                ("x y", Str("a\"\n'b")),
              ]),
              Map([
                ("x y", Seq([Map([]), Map([("z", Str("'''"))]), Str("\"'")])),
              ]),
            ]),
          ),
        ]),
      ),
      ("b", Float(-0.0)),
      ("q\"", Map([("n\nl", Float(1.0e20)), ("k-1", Str("a\"b"))])),
    ]),
    true,
    "b = -0.0\n\n[\"s'\"]\nk-1 = []\n\n[\"s'\".b]\n\n[[\"s'\".\"\u{e9}\"]]\n\n[[\"s'\".\"\u{e9}\"]]\n\"\u{e9}\" = -7\n\"\" = 0.25\n\"x y\" = '''\na\"\n'b'''\n\n[[\"s'\".\"\u{e9}\".z]]\n\"\" = \"'''\"\n\n[[\"s'\".\"\u{e9}\"]]\n\"x y\" = [\n    {},\n    { z = \"'''\" },\n    \"\\\"'\",\n]\n\n['q\"']\n\"n\\nl\" = 100000000000000000000.0\nk-1 = 'a\"b'\n",
  )
  check_ser(
    Map([
      (
        "s'",
        Map([
          ("b", Map([])),
          ("k-1", Seq([])),
          (
            "\u{e9}",
            Seq([
              Map([("", None)]),
              Map([
                ("\u{e9}", Int(-7L)),
                ("", Float(0.25)),
                ("z", Seq([Map([("", Str("'''"))])])),
                ("x y", Str("a\"\n'b")),
              ]),
              Map([
                ("x y", Seq([Map([]), Map([("z", Str("'''"))]), Str("\"'")])),
              ]),
            ]),
          ),
        ]),
      ),
      ("b", Float(-0.0)),
      ("q\"", Map([("n\nl", Float(1.0e20)), ("k-1", Str("a\"b"))])),
    ]),
    false,
    "b = -0.0\n\n[\"s'\"]\nk-1 = []\n\n[\"s'\".b]\n\n[[\"s'\".\"\u{e9}\"]]\n\n[[\"s'\".\"\u{e9}\"]]\n\"\u{e9}\" = -7\n\"\" = 0.25\n\"x y\" = '''\na\"\n'b'''\n\n[[\"s'\".\"\u{e9}\".z]]\n\"\" = \"'''\"\n\n[[\"s'\".\"\u{e9}\"]]\n\"x y\" = [{}, { z = \"'''\" }, \"\\\"'\"]\n\n['q\"']\n\"n\\nl\" = 100000000000000000000.0\nk-1 = 'a\"b'\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([("n\nl", Str("\u{e9}\u{4e2d}")), ("x y", Seq([]))]),
    true,
    "\"n\\nl\" = \"\u{e9}\u{4e2d}\"\n\"x y\" = []\n",
  )
  check_ser(
    Map([("n\nl", Str("\u{e9}\u{4e2d}")), ("x y", Seq([]))]),
    false,
    "\"n\\nl\" = \"\u{e9}\u{4e2d}\"\n\"x y\" = []\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      ("s'", Map([])),
      (
        "",
        Seq([
          Map([("k-1", Str("a\"b")), ("x y", Seq([Str("\t")]))]),
          Map([("\u{e9}", Seq([]))]),
        ]),
      ),
      (
        "x y",
        Map([
          (
            "b",
            Seq([
              Map([
                (
                  "\u{e9}",
                  Seq([
                    Map([
                      (
                        "s'",
                        Map([
                          ("z", Str("")),
                          ("\u{e9}", Str("a\"\n'b")),
                          ("", Str("it's")),
                          ("b", Float(3.14159)),
                        ]),
                      ),
                      ("x y", Str("\"'")),
                      ("a", Map([("x y", Str("\t"))])),
                    ]),
                    Map([
                      ("x y", Str("\"'")),
                      (
                        "",
                        Seq([
                          Map([("a", Str("\"'"))]),
                          Map([("z", Int(1099511627776L))]),
                        ]),
                      ),
                      (
                        "b",
                        Map([("k-1", Str("\u{e9}\u{4e2d}")), ("q\"", Str(""))]),
                      ),
                    ]),
                  ]),
                ),
                (
                  "b",
                  Map([
                    ("\u{e9}", Float(-0.0)),
                    ("k-1", Int(-7L)),
                    ("q\"", Seq([Bool(false), Str("a\"b")])),
                    (
                      "s'",
                      Map([
                        ("\u{e9}", Float(@double.infinity)),
                        ("a", Int(0L)),
                        ("q\"", Float(0.25)),
                      ]),
                    ),
                  ]),
                ),
                (
                  "a",
                  Seq([
                    Map([("", Float(1.0e-09)), ("q\"", Str("it's"))]),
                    Map([("n\nl", Map([])), ("q\"", Str("x'")), ("", Seq([]))]),
                    Map([
                      ("q\"", Seq([Str("it's")])),
                      ("a", Str("\u{1}")),
                      ("b", Str("\u{1}")),
                    ]),
                  ]),
                ),
              ]),
            ]),
          ),
          (
            "s'",
            Map([
              (
                "b",
                Seq([
                  Seq([
                    Map([
                      ("\u{e9}", Str("x")),
                      ("n\nl", Int(-7L)),
                      ("a", Float(1.0)),
                      ("z", Str("\t")),
                    ]),
                    Map([("s'", Str("\u{e9}\u{4e2d}")), ("k-1", Int(-7L))]),
                  ]),
                ]),
              ),
              (
                "q\"",
                Seq([
                  Map([
                    (
                      "",
                      Seq([
                        Map([
                          ("\u{e9}", Float(3.14159)),
                          ("q\"", Float(@double.infinity)),
                        ]),
                        Map([("z", Int(-7L)), ("k-1", Float(0.25))]),
                        Map([("q\"", Str("x")), ("z", Str("it's"))]),
                      ]),
                    ),
                    ("s'", Int(-7L)),
                  ]),
                ]),
              ),
              ("s'", Map([("x y", Bool(false))])),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "[\"s'\"]\n\n[[\"\"]]\nk-1 = 'a\"b'\n\"x y\" = [\"\\t\"]\n\n[[\"\"]]\n\"\u{e9}\" = []\n\n[[\"x y\".b]]\n\n[[\"x y\".b.\"\u{e9}\"]]\n\"x y\" = \"\\\"'\"\n\n[\"x y\".b.\"\u{e9}\".\"s'\"]\nz = \"\"\n\"\u{e9}\" = '''\na\"\n'b'''\n\"\" = \"it's\"\nb = 3.14159\n\n[\"x y\".b.\"\u{e9}\".a]\n\"x y\" = \"\\t\"\n\n[[\"x y\".b.\"\u{e9}\"]]\n\"x y\" = \"\\\"'\"\n\n[[\"x y\".b.\"\u{e9}\".\"\"]]\na = \"\\\"'\"\n\n[[\"x y\".b.\"\u{e9}\".\"\"]]\nz = 1099511627776\n\n[\"x y\".b.\"\u{e9}\".b]\nk-1 = \"\u{e9}\u{4e2d}\"\n'q\"' = \"\"\n\n[\"x y\".b.b]\n\"\u{e9}\" = -0.0\nk-1 = -7\n'q\"' = [\n    false,\n    'a\"b',\n]\n\n[\"x y\".b.b.\"s'\"]\n\"\u{e9}\" = inf\na = 0\n'q\"' = 0.25\n\n[[\"x y\".b.a]]\n\"\" = 0.000000001\n'q\"' = \"it's\"\n\n[[\"x y\".b.a]]\n'q\"' = \"x'\"\n\"\" = []\n\n[\"x y\".b.a.\"n\\nl\"]\n\n[[\"x y\".b.a]]\n'q\"' = [\"it's\"]\na = \"\\u0001\"\nb = \"\\u0001\"\n\n[\"x y\".\"s'\"]\nb = [[\n    { \"\u{e9}\" = \"x\", \"n\\nl\" = -7, a = 1.0, z = \"\\t\" },\n    { \"s'\" = \"\u{e9}\u{4e2d}\", k-1 = -7 },\n]]\n\n[[\"x y\".\"s'\".'q\"']]\n\"s'\" = -7\n\n[[\"x y\".\"s'\".'q\"'.\"\"]]\n\"\u{e9}\" = 3.14159\n'q\"' = inf\n\n[[\"x y\".\"s'\".'q\"'.\"\"]]\nz = -7\nk-1 = 0.25\n\n[[\"x y\".\"s'\".'q\"'.\"\"]]\n'q\"' = \"x\"\nz = \"it's\"\n\n[\"x y\".\"s'\".\"s'\"]\n\"x y\" = false\n",
  )
  check_ser(
    Map([
      ("s'", Map([])),
      (
        "",
        Seq([
          Map([("k-1", Str("a\"b")), ("x y", Seq([Str("\t")]))]),
          Map([("\u{e9}", Seq([]))]),
        ]),
      ),
      (
        "x y",
        Map([
          (
            "b",
            Seq([
              Map([
                (
                  "\u{e9}",
                  Seq([
                    Map([
                      (
                        "s'",
                        Map([
                          ("z", Str("")),
                          ("\u{e9}", Str("a\"\n'b")),
                          ("", Str("it's")),
                          ("b", Float(3.14159)),
                        ]),
                      ),
                      ("x y", Str("\"'")),
                      ("a", Map([("x y", Str("\t"))])),
                    ]),
                    Map([
                      ("x y", Str("\"'")),
                      (
                        "",
                        Seq([
                          Map([("a", Str("\"'"))]),
                          Map([("z", Int(1099511627776L))]),
                        ]),
                      ),
                      (
                        "b",
                        Map([("k-1", Str("\u{e9}\u{4e2d}")), ("q\"", Str(""))]),
                      ),
                    ]),
                  ]),
                ),
                (
                  "b",
                  Map([
                    ("\u{e9}", Float(-0.0)),
                    ("k-1", Int(-7L)),
                    ("q\"", Seq([Bool(false), Str("a\"b")])),
                    (
                      "s'",
                      Map([
                        ("\u{e9}", Float(@double.infinity)),
                        ("a", Int(0L)),
                        ("q\"", Float(0.25)),
                      ]),
                    ),
                  ]),
                ),
                (
                  "a",
                  Seq([
                    Map([("", Float(1.0e-09)), ("q\"", Str("it's"))]),
                    Map([("n\nl", Map([])), ("q\"", Str("x'")), ("", Seq([]))]),
                    Map([
                      ("q\"", Seq([Str("it's")])),
                      ("a", Str("\u{1}")),
                      ("b", Str("\u{1}")),
                    ]),
                  ]),
                ),
              ]),
            ]),
          ),
          (
            "s'",
            Map([
              (
                "b",
                Seq([
                  Seq([
                    Map([
                      ("\u{e9}", Str("x")),
                      ("n\nl", Int(-7L)),
                      ("a", Float(1.0)),
                      ("z", Str("\t")),
                    ]),
                    Map([("s'", Str("\u{e9}\u{4e2d}")), ("k-1", Int(-7L))]),
                  ]),
                ]),
              ),
              (
                "q\"",
                Seq([
                  Map([
                    (
                      "",
                      Seq([
                        Map([
                          ("\u{e9}", Float(3.14159)),
                          ("q\"", Float(@double.infinity)),
                        ]),
                        Map([("z", Int(-7L)), ("k-1", Float(0.25))]),
                        Map([("q\"", Str("x")), ("z", Str("it's"))]),
                      ]),
                    ),
                    ("s'", Int(-7L)),
                  ]),
                ]),
              ),
              ("s'", Map([("x y", Bool(false))])),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "[\"s'\"]\n\n[[\"\"]]\nk-1 = 'a\"b'\n\"x y\" = [\"\\t\"]\n\n[[\"\"]]\n\"\u{e9}\" = []\n\n[[\"x y\".b]]\n\n[[\"x y\".b.\"\u{e9}\"]]\n\"x y\" = \"\\\"'\"\n\n[\"x y\".b.\"\u{e9}\".\"s'\"]\nz = \"\"\n\"\u{e9}\" = '''\na\"\n'b'''\n\"\" = \"it's\"\nb = 3.14159\n\n[\"x y\".b.\"\u{e9}\".a]\n\"x y\" = \"\\t\"\n\n[[\"x y\".b.\"\u{e9}\"]]\n\"x y\" = \"\\\"'\"\n\n[[\"x y\".b.\"\u{e9}\".\"\"]]\na = \"\\\"'\"\n\n[[\"x y\".b.\"\u{e9}\".\"\"]]\nz = 1099511627776\n\n[\"x y\".b.\"\u{e9}\".b]\nk-1 = \"\u{e9}\u{4e2d}\"\n'q\"' = \"\"\n\n[\"x y\".b.b]\n\"\u{e9}\" = -0.0\nk-1 = -7\n'q\"' = [false, 'a\"b']\n\n[\"x y\".b.b.\"s'\"]\n\"\u{e9}\" = inf\na = 0\n'q\"' = 0.25\n\n[[\"x y\".b.a]]\n\"\" = 0.000000001\n'q\"' = \"it's\"\n\n[[\"x y\".b.a]]\n'q\"' = \"x'\"\n\"\" = []\n\n[\"x y\".b.a.\"n\\nl\"]\n\n[[\"x y\".b.a]]\n'q\"' = [\"it's\"]\na = \"\\u0001\"\nb = \"\\u0001\"\n\n[\"x y\".\"s'\"]\nb = [[{ \"\u{e9}\" = \"x\", \"n\\nl\" = -7, a = 1.0, z = \"\\t\" }, { \"s'\" = \"\u{e9}\u{4e2d}\", k-1 = -7 }]]\n\n[[\"x y\".\"s'\".'q\"']]\n\"s'\" = -7\n\n[[\"x y\".\"s'\".'q\"'.\"\"]]\n\"\u{e9}\" = 3.14159\n'q\"' = inf\n\n[[\"x y\".\"s'\".'q\"'.\"\"]]\nz = -7\nk-1 = 0.25\n\n[[\"x y\".\"s'\".'q\"'.\"\"]]\n'q\"' = \"x\"\nz = \"it's\"\n\n[\"x y\".\"s'\".\"s'\"]\n\"x y\" = false\n",
  )
  check_ser(
    Map([
      ("z", Seq([Float(3.14159), Seq([Str("l1\nl2"), Str("'''")])])),
      (
        "s'",
        Seq([
          Seq([
            Seq([]),
            Seq([
              Seq([Str("\u{1}"), Int(0L)]),
              Seq([
                Map([("s'", Str("x'"))]),
                Map([
                  ("n\nl", Str("x")),
                  ("k-1", Float(1.0)),
                  ("q\"", Str("\u{1}")),
                ]),
              ]),
              Float(1.0e20),
            ]),
            Bool(false),
          ]),
          Str("a\\b"),
        ]),
      ),
      ("\u{e9}", Bool(true)),
    ]),
    true,
    "z = [\n    3.14159,\n    [\n    \"\"\"\nl1\nl2\"\"\",\n    \"'''\",\n],\n]\n\"s'\" = [\n    [\n    [],\n    [\n    [\n    \"\\u0001\",\n    0,\n],\n    [\n    { \"s'\" = \"x'\" },\n    { \"n\\nl\" = \"x\", k-1 = 1.0, 'q\"' = \"\\u0001\" },\n],\n    100000000000000000000.0,\n],\n    false,\n],\n    'a\\b',\n]\n\"\u{e9}\" = true\n",
  )
  check_ser(
    Map([
      ("z", Seq([Float(3.14159), Seq([Str("l1\nl2"), Str("'''")])])),
      (
        "s'",
        Seq([
          Seq([
            Seq([]),
            Seq([
              Seq([Str("\u{1}"), Int(0L)]),
              Seq([
                Map([("s'", Str("x'"))]),
                Map([
                  ("n\nl", Str("x")),
                  ("k-1", Float(1.0)),
                  ("q\"", Str("\u{1}")),
                ]),
              ]),
              Float(1.0e20),
            ]),
            Bool(false),
          ]),
          Str("a\\b"),
        ]),
      ),
      ("\u{e9}", Bool(true)),
    ]),
    false,
    "z = [3.14159, [\"\"\"\nl1\nl2\"\"\", \"'''\"]]\n\"s'\" = [[[], [[\"\\u0001\", 0], [{ \"s'\" = \"x'\" }, { \"n\\nl\" = \"x\", k-1 = 1.0, 'q\"' = \"\\u0001\" }], 100000000000000000000.0], false], 'a\\b']\n\"\u{e9}\" = true\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([("s'", Map([("\u{e9}", Str("\u{e9}\u{4e2d}")), ("x y", Seq([]))]))]),
    true,
    "[\"s'\"]\n\"\u{e9}\" = \"\u{e9}\u{4e2d}\"\n\"x y\" = []\n",
  )
  check_ser(
    Map([("s'", Map([("\u{e9}", Str("\u{e9}\u{4e2d}")), ("x y", Seq([]))]))]),
    false,
    "[\"s'\"]\n\"\u{e9}\" = \"\u{e9}\u{4e2d}\"\n\"x y\" = []\n",
  )
  check_ser(
    Map([
      (
        "s'",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Seq([Bool(true)]),
                Str("a\"\n'b"),
                Seq([
                  Map([("x y", Float(0.25))]),
                  Seq([Str(""), Str("x"), Str("\u{1}")]),
                  Seq([]),
                ]),
              ]),
            ),
            ("z", Map([("q\"", Int(-7L))])),
            ("q\"", Str("\u{1}")),
          ]),
          Map([
            ("x y", Map([])),
            ("n\nl", Seq([Map([])])),
            ("b", Seq([])),
            (
              "z",
              Seq([
                Seq([
                  Str("\"'"),
                  Map([
                    ("", Float(3.14159)),
                    ("s'", Str("a\"b")),
                    ("z", Str("l1\nl2")),
                  ]),
                  Seq([]),
                ]),
                Str("'''"),
              ]),
            ),
          ]),
          Map([("", Map([]))]),
        ]),
      ),
      ("b", Seq([Map([])])),
      (
        "a",
        Map([
          ("a", Str("")),
          (
            "z",
            Map([
              ("n\nl", Seq([])),
              ("q\"", Int(-7L)),
              (
                "x y",
                Map([
                  ("s'", Seq([Str("l1\nl2"), Str("a\\b")])),
                  ("k-1", Seq([Str("\u{1}")])),
                  ("x y", Map([("s'", Str(""))])),
                  ("\u{e9}", Seq([Float(3.14159), Str("\t"), Float(0.25)])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      ("z", Map([])),
    ]),
    true,
    "[[\"s'\"]]\n\"s'\" = [\n    [true],\n    '''\na\"\n'b''',\n    [\n    { \"x y\" = 0.25 },\n    [\n    \"\",\n    \"x\",\n    \"\\u0001\",\n],\n    [],\n],\n]\n'q\"' = \"\\u0001\"\n\n[\"s'\".z]\n'q\"' = -7\n\n[[\"s'\"]]\nb = []\nz = [\n    [\n    \"\\\"'\",\n    { \"\" = 3.14159, \"s'\" = 'a\"b', z = \"\"\"\nl1\nl2\"\"\" },\n    [],\n],\n    \"'''\",\n]\n\n[\"s'\".\"x y\"]\n\n[[\"s'\".\"n\\nl\"]]\n\n[[\"s'\"]]\n\n[\"s'\".\"\"]\n\n[[b]]\n\n[a]\na = \"\"\n\n[a.z]\n\"n\\nl\" = []\n'q\"' = -7\n\n[a.z.\"x y\"]\n\"s'\" = [\n    \"\"\"\nl1\nl2\"\"\",\n    'a\\b',\n]\nk-1 = [\"\\u0001\"]\n\"\u{e9}\" = [\n    3.14159,\n    \"\\t\",\n    0.25,\n]\n\n[a.z.\"x y\".\"x y\"]\n\"s'\" = \"\"\n\n[z]\n",
  )
  check_ser(
    Map([
      (
        "s'",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Seq([Bool(true)]),
                Str("a\"\n'b"),
                Seq([
                  Map([("x y", Float(0.25))]),
                  Seq([Str(""), Str("x"), Str("\u{1}")]),
                  Seq([]),
                ]),
              ]),
            ),
            ("z", Map([("q\"", Int(-7L))])),
            ("q\"", Str("\u{1}")),
          ]),
          Map([
            ("x y", Map([])),
            ("n\nl", Seq([Map([])])),
            ("b", Seq([])),
            (
              "z",
              Seq([
                Seq([
                  Str("\"'"),
                  Map([
                    ("", Float(3.14159)),
                    ("s'", Str("a\"b")),
                    ("z", Str("l1\nl2")),
                  ]),
                  Seq([]),
                ]),
                Str("'''"),
              ]),
            ),
          ]),
          Map([("", Map([]))]),
        ]),
      ),
      ("b", Seq([Map([])])),
      (
        "a",
        Map([
          ("a", Str("")),
          (
            "z",
            Map([
              ("n\nl", Seq([])),
              ("q\"", Int(-7L)),
              (
                "x y",
                Map([
                  ("s'", Seq([Str("l1\nl2"), Str("a\\b")])),
                  ("k-1", Seq([Str("\u{1}")])),
                  ("x y", Map([("s'", Str(""))])),
                  ("\u{e9}", Seq([Float(3.14159), Str("\t"), Float(0.25)])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      ("z", Map([])),
    ]),
    false,
    "[[\"s'\"]]\n\"s'\" = [[true], '''\na\"\n'b''', [{ \"x y\" = 0.25 }, [\"\", \"x\", \"\\u0001\"], []]]\n'q\"' = \"\\u0001\"\n\n[\"s'\".z]\n'q\"' = -7\n\n[[\"s'\"]]\nb = []\nz = [[\"\\\"'\", { \"\" = 3.14159, \"s'\" = 'a\"b', z = \"\"\"\nl1\nl2\"\"\" }, []], \"'''\"]\n\n[\"s'\".\"x y\"]\n\n[[\"s'\".\"n\\nl\"]]\n\n[[\"s'\"]]\n\n[\"s'\".\"\"]\n\n[[b]]\n\n[a]\na = \"\"\n\n[a.z]\n\"n\\nl\" = []\n'q\"' = -7\n\n[a.z.\"x y\"]\n\"s'\" = [\"\"\"\nl1\nl2\"\"\", 'a\\b']\nk-1 = [\"\\u0001\"]\n\"\u{e9}\" = [3.14159, \"\\t\", 0.25]\n\n[a.z.\"x y\".\"x y\"]\n\"s'\" = \"\"\n\n[z]\n",
  )
  check_ser(
    Map([
      ("\u{e9}", Str("it's")),
      (
        "x y",
        Seq([
          Map([
            (
              "z",
              Map([
                ("\u{e9}", Int(0L)),
                ("b", Float(0.25)),
                ("x y", Str("\u{1}")),
              ]),
            ),
            (
              "s'",
              Map([
                ("k-1", Float(1.0e20)),
                ("s'", Seq([Str("\"'"), Float(1.0e20), Float(1.0)])),
              ]),
            ),
            ("x y", Bool(false)),
          ]),
        ]),
      ),
      (
        "",
        Map([
          (
            "z",
            Map([
              (
                "k-1",
                Seq([
                  Seq([
                    Map([
                      ("\u{e9}", Str("x'")),
                      ("n\nl", Int(1099511627776L)),
                      ("s'", Float(1.0e20)),
                      ("q\"", Float(1.0e-09)),
                    ]),
                    Map([("", Int(-7L)), ("x y", Str("'''"))]),
                  ]),
                  Map([]),
                  Map([]),
                ]),
              ),
              ("s'", Str("it's")),
            ]),
          ),
          (
            "b",
            Seq([
              Map([("x y", Map([]))]),
              Map([("k-1", Float(1.0e-09)), ("a", Float(-0.0))]),
              Map([]),
            ]),
          ),
          (
            "",
            Seq([
              Bool(false),
              Float(@double.infinity),
              Seq([
                Map([
                  ("k-1", Seq([Float(@double.infinity), Bool(false), Int(0L)])),
                  ("x y", Float(1.0e20)),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
      ("n\nl", Seq([])),
    ]),
    true,
    "\"\u{e9}\" = \"it's\"\n\"n\\nl\" = []\n\n[[\"x y\"]]\n\"x y\" = false\n\n[\"x y\".z]\n\"\u{e9}\" = 0\nb = 0.25\n\"x y\" = \"\\u0001\"\n\n[\"x y\".\"s'\"]\nk-1 = 100000000000000000000.0\n\"s'\" = [\n    \"\\\"'\",\n    100000000000000000000.0,\n    1.0,\n]\n\n[\"\"]\n\"\" = [\n    false,\n    inf,\n    [{ k-1 = [\n    inf,\n    false,\n    0,\n], \"x y\" = 100000000000000000000.0 }],\n]\n\n[\"\".z]\nk-1 = [\n    [\n    { \"\u{e9}\" = \"x'\", \"n\\nl\" = 1099511627776, \"s'\" = 100000000000000000000.0, 'q\"' = 0.000000001 },\n    { \"\" = -7, \"x y\" = \"'''\" },\n],\n    {},\n    {},\n]\n\"s'\" = \"it's\"\n\n[[\"\".b]]\n\n[\"\".b.\"x y\"]\n\n[[\"\".b]]\nk-1 = 0.000000001\na = -0.0\n\n[[\"\".b]]\n",
  )
  check_ser(
    Map([
      ("\u{e9}", Str("it's")),
      (
        "x y",
        Seq([
          Map([
            (
              "z",
              Map([
                ("\u{e9}", Int(0L)),
                ("b", Float(0.25)),
                ("x y", Str("\u{1}")),
              ]),
            ),
            (
              "s'",
              Map([
                ("k-1", Float(1.0e20)),
                ("s'", Seq([Str("\"'"), Float(1.0e20), Float(1.0)])),
              ]),
            ),
            ("x y", Bool(false)),
          ]),
        ]),
      ),
      (
        "",
        Map([
          (
            "z",
            Map([
              (
                "k-1",
                Seq([
                  Seq([
                    Map([
                      ("\u{e9}", Str("x'")),
                      ("n\nl", Int(1099511627776L)),
                      ("s'", Float(1.0e20)),
                      ("q\"", Float(1.0e-09)),
                    ]),
                    Map([("", Int(-7L)), ("x y", Str("'''"))]),
                  ]),
                  Map([]),
                  Map([]),
                ]),
              ),
              ("s'", Str("it's")),
            ]),
          ),
          (
            "b",
            Seq([
              Map([("x y", Map([]))]),
              Map([("k-1", Float(1.0e-09)), ("a", Float(-0.0))]),
              Map([]),
            ]),
          ),
          (
            "",
            Seq([
              Bool(false),
              Float(@double.infinity),
              Seq([
                Map([
                  ("k-1", Seq([Float(@double.infinity), Bool(false), Int(0L)])),
                  ("x y", Float(1.0e20)),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
      ("n\nl", Seq([])),
    ]),
    false,
    "\"\u{e9}\" = \"it's\"\n\"n\\nl\" = []\n\n[[\"x y\"]]\n\"x y\" = false\n\n[\"x y\".z]\n\"\u{e9}\" = 0\nb = 0.25\n\"x y\" = \"\\u0001\"\n\n[\"x y\".\"s'\"]\nk-1 = 100000000000000000000.0\n\"s'\" = [\"\\\"'\", 100000000000000000000.0, 1.0]\n\n[\"\"]\n\"\" = [false, inf, [{ k-1 = [inf, false, 0], \"x y\" = 100000000000000000000.0 }]]\n\n[\"\".z]\nk-1 = [[{ \"\u{e9}\" = \"x'\", \"n\\nl\" = 1099511627776, \"s'\" = 100000000000000000000.0, 'q\"' = 0.000000001 }, { \"\" = -7, \"x y\" = \"'''\" }], {}, {}]\n\"s'\" = \"it's\"\n\n[[\"\".b]]\n\n[\"\".b.\"x y\"]\n\n[[\"\".b]]\nk-1 = 0.000000001\na = -0.0\n\n[[\"\".b]]\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Map([]),
            Map([
              ("x y", Seq([Str("\"'")])),
              ("b", Seq([Float(-0.0), Float(0.25), Str("\u{1}")])),
              (
                "z",
                Map([
                  ("b", Str("a\"\n'b")),
                  ("\u{e9}", Str("a\"\n'b")),
                  ("q\"", Str("a\\b")),
                ]),
              ),
            ]),
          ]),
        ]),
      ),
      (
        "\u{e9}",
        Map([("\u{e9}", Map([("z", Str("a\"\n'b"))])), ("q\"", Str("x'"))]),
      ),
      (
        "b",
        Seq([
          Map([
            ("\u{e9}", Seq([])),
            ("s'", Str("x")),
            (
              "n\nl",
              Seq([
                Map([("z", Int(0L)), ("\u{e9}", Float(1.0e-09))]),
                Map([("b", Map([("q\"", Str("it's"))]))]),
              ]),
            ),
          ]),
        ]),
      ),
      ("n\nl", Float(@double.not_a_number)),
    ]),
    true,
    "z = [[\n    {},\n    { \"x y\" = [\"\\\"'\"], b = [\n    -0.0,\n    0.25,\n    \"\\u0001\",\n], z = { b = '''\na\"\n'b''', \"\u{e9}\" = '''\na\"\n'b''', 'q\"' = 'a\\b' } },\n]]\n\"n\\nl\" = nan\n\n[\"\u{e9}\"]\n'q\"' = \"x'\"\n\n[\"\u{e9}\".\"\u{e9}\"]\nz = '''\na\"\n'b'''\n\n[[b]]\n\"\u{e9}\" = []\n\"s'\" = \"x\"\n\n[[b.\"n\\nl\"]]\nz = 0\n\"\u{e9}\" = 0.000000001\n\n[[b.\"n\\nl\"]]\n\n[b.\"n\\nl\".b]\n'q\"' = \"it's\"\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Seq([
            Map([]),
            Map([
              ("x y", Seq([Str("\"'")])),
              ("b", Seq([Float(-0.0), Float(0.25), Str("\u{1}")])),
              (
                "z",
                Map([
                  ("b", Str("a\"\n'b")),
                  ("\u{e9}", Str("a\"\n'b")),
                  ("q\"", Str("a\\b")),
                ]),
              ),
            ]),
          ]),
        ]),
      ),
      (
        "\u{e9}",
        Map([("\u{e9}", Map([("z", Str("a\"\n'b"))])), ("q\"", Str("x'"))]),
      ),
      (
        "b",
        Seq([
          Map([
            ("\u{e9}", Seq([])),
            ("s'", Str("x")),
            (
              "n\nl",
              Seq([
                Map([("z", Int(0L)), ("\u{e9}", Float(1.0e-09))]),
                Map([("b", Map([("q\"", Str("it's"))]))]),
              ]),
            ),
          ]),
        ]),
      ),
      ("n\nl", Float(@double.not_a_number)),
    ]),
    false,
    "z = [[{}, { \"x y\" = [\"\\\"'\"], b = [-0.0, 0.25, \"\\u0001\"], z = { b = '''\na\"\n'b''', \"\u{e9}\" = '''\na\"\n'b''', 'q\"' = 'a\\b' } }]]\n\"n\\nl\" = nan\n\n[\"\u{e9}\"]\n'q\"' = \"x'\"\n\n[\"\u{e9}\".\"\u{e9}\"]\nz = '''\na\"\n'b'''\n\n[[b]]\n\"\u{e9}\" = []\n\"s'\" = \"x\"\n\n[[b.\"n\\nl\"]]\nz = 0\n\"\u{e9}\" = 0.000000001\n\n[[b.\"n\\nl\"]]\n\n[b.\"n\\nl\".b]\n'q\"' = \"it's\"\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Seq([Float(0.25), Seq([])]),
          Seq([]),
          Map([
            (
              "n\nl",
              Map([("\u{e9}", Str("a\"b")), ("n\nl", None), ("q\"", Seq([]))]),
            ),
            (
              "z",
              Map([
                (
                  "q\"",
                  Map([
                    ("z", Float(1.0)),
                    ("n\nl", Str("l1\nl2")),
                    ("\u{e9}", Str("a\"b")),
                    ("b", Str("\u{e9}\u{4e2d}")),
                  ]),
                ),
                ("x y", Map([("x y", Float(1.0)), ("n\nl", Bool(false))])),
              ]),
            ),
            (
              "q\"",
              Map([
                ("s'", Seq([Bool(true), Str("x")])),
                ("z", Seq([])),
                ("x y", Str("x'")),
                ("a", Seq([Float(1.0e-09), Float(0.25), Str("")])),
              ]),
            ),
          ]),
        ]),
      ),
      ("n\nl", Float(1.0e20)),
    ]),
    true,
    "k-1 = [\n    [\n    0.25,\n    [],\n],\n    [],\n    { \"n\\nl\" = { \"\u{e9}\" = 'a\"b', 'q\"' = [] }, z = { 'q\"' = { z = 1.0, \"n\\nl\" = \"\"\"\nl1\nl2\"\"\", \"\u{e9}\" = 'a\"b', b = \"\u{e9}\u{4e2d}\" }, \"x y\" = { \"x y\" = 1.0, \"n\\nl\" = false } }, 'q\"' = { \"s'\" = [\n    true,\n    \"x\",\n], z = [], \"x y\" = \"x'\", a = [\n    0.000000001,\n    0.25,\n    \"\",\n] } },\n]\n\"n\\nl\" = 100000000000000000000.0\n",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Seq([Float(0.25), Seq([])]),
          Seq([]),
          Map([
            (
              "n\nl",
              Map([("\u{e9}", Str("a\"b")), ("n\nl", None), ("q\"", Seq([]))]),
            ),
            (
              "z",
              Map([
                (
                  "q\"",
                  Map([
                    ("z", Float(1.0)),
                    ("n\nl", Str("l1\nl2")),
                    ("\u{e9}", Str("a\"b")),
                    ("b", Str("\u{e9}\u{4e2d}")),
                  ]),
                ),
                ("x y", Map([("x y", Float(1.0)), ("n\nl", Bool(false))])),
              ]),
            ),
            (
              "q\"",
              Map([
                ("s'", Seq([Bool(true), Str("x")])),
                ("z", Seq([])),
                ("x y", Str("x'")),
                ("a", Seq([Float(1.0e-09), Float(0.25), Str("")])),
              ]),
            ),
          ]),
        ]),
      ),
      ("n\nl", Float(1.0e20)),
    ]),
    false,
    "k-1 = [[0.25, []], [], { \"n\\nl\" = { \"\u{e9}\" = 'a\"b', 'q\"' = [] }, z = { 'q\"' = { z = 1.0, \"n\\nl\" = \"\"\"\nl1\nl2\"\"\", \"\u{e9}\" = 'a\"b', b = \"\u{e9}\u{4e2d}\" }, \"x y\" = { \"x y\" = 1.0, \"n\\nl\" = false } }, 'q\"' = { \"s'\" = [true, \"x\"], z = [], \"x y\" = \"x'\", a = [0.000000001, 0.25, \"\"] } }]\n\"n\\nl\" = 100000000000000000000.0\n",
  )
  check_ser(
    Map([
      ("z", Map([("\u{e9}", Seq([Str("a\\b")])), ("s'", Map([("q\"", None)]))])),
      (
        "",
        Seq([
          Seq([
            Map([
              (
                "q\"",
                Map([
                  ("x y", Float(@double.not_a_number)),
                  ("a", Float(1.0)),
                  ("b", Int(-7L)),
                ]),
              ),
            ]),
          ]),
        ]),
      ),
    ]),
    true,
    "\"\" = [[{ 'q\"' = { \"x y\" = nan, a = 1.0, b = -7 } }]]\n\n[z]\n\"\u{e9}\" = ['a\\b']\n\n[z.\"s'\"]\n",
  )
  check_ser(
    Map([
      ("z", Map([("\u{e9}", Seq([Str("a\\b")])), ("s'", Map([("q\"", None)]))])),
      (
        "",
        Seq([
          Seq([
            Map([
              (
                "q\"",
                Map([
                  ("x y", Float(@double.not_a_number)),
                  ("a", Float(1.0)),
                  ("b", Int(-7L)),
                ]),
              ),
            ]),
          ]),
        ]),
      ),
    ]),
    false,
    "\"\" = [[{ 'q\"' = { \"x y\" = nan, a = 1.0, b = -7 } }]]\n\n[z]\n\"\u{e9}\" = ['a\\b']\n\n[z.\"s'\"]\n",
  )
  check_ser(
    Map([
      ("q\"", Seq([Map([("k-1", Map([("s'", Map([]))]))])])),
      ("s'", Str("\u{e9}\u{4e2d}")),
      ("", Str("")),
      ("x y", Seq([])),
    ]),
    true,
    "\"s'\" = \"\u{e9}\u{4e2d}\"\n\"\" = \"\"\n\"x y\" = []\n\n[['q\"']]\n\n['q\"'.k-1.\"s'\"]\n",
  )
  check_ser(
    Map([
      ("q\"", Seq([Map([("k-1", Map([("s'", Map([]))]))])])),
      ("s'", Str("\u{e9}\u{4e2d}")),
      ("", Str("")),
      ("x y", Seq([])),
    ]),
    false,
    "\"s'\" = \"\u{e9}\u{4e2d}\"\n\"\" = \"\"\n\"x y\" = []\n\n[['q\"']]\n\n['q\"'.k-1.\"s'\"]\n",
  )
  check_ser(
    Map([
      (
        "x y",
        Map([
          (
            "x y",
            Map([
              (
                "",
                Seq([
                  Map([
                    ("s'", Map([("s'", Str("it's"))])),
                    ("\u{e9}", Float(-0.0)),
                  ]),
                ]),
              ),
              ("n\nl", Float(3.14159)),
            ]),
          ),
          (
            "q\"",
            Seq([
              Float(1.0),
              Float(1.0),
              Seq([
                Seq([Str("'''"), Float(@double.not_a_number), Str("a\"\n'b")]),
              ]),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "[\"x y\"]\n'q\"' = [\n    1.0,\n    1.0,\n    [[\n    \"'''\",\n    nan,\n    '''\na\"\n'b''',\n]],\n]\n\n[\"x y\".\"x y\"]\n\"n\\nl\" = 3.14159\n\n[[\"x y\".\"x y\".\"\"]]\n\"\u{e9}\" = -0.0\n\n[\"x y\".\"x y\".\"\".\"s'\"]\n\"s'\" = \"it's\"\n",
  )
  check_ser(
    Map([
      (
        "x y",
        Map([
          (
            "x y",
            Map([
              (
                "",
                Seq([
                  Map([
                    ("s'", Map([("s'", Str("it's"))])),
                    ("\u{e9}", Float(-0.0)),
                  ]),
                ]),
              ),
              ("n\nl", Float(3.14159)),
            ]),
          ),
          (
            "q\"",
            Seq([
              Float(1.0),
              Float(1.0),
              Seq([
                Seq([Str("'''"), Float(@double.not_a_number), Str("a\"\n'b")]),
              ]),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "[\"x y\"]\n'q\"' = [1.0, 1.0, [[\"'''\", nan, '''\na\"\n'b''']]]\n\n[\"x y\".\"x y\"]\n\"n\\nl\" = 3.14159\n\n[[\"x y\".\"x y\".\"\"]]\n\"\u{e9}\" = -0.0\n\n[\"x y\".\"x y\".\"\".\"s'\"]\n\"s'\" = \"it's\"\n",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Seq([
          Map([
            (
              "k-1",
              Map([
                ("n\nl", Float(1.0)),
                ("b", Map([])),
                (
                  "",
                  Seq([
                    Map([("s'", Seq([]))]),
                    Map([
                      ("\u{e9}", Str("")),
                      (
                        "n\nl",
                        Map([("z", Str("")), ("q\"", Float(@double.infinity))]),
                      ),
                    ]),
                    Map([
                      ("\u{e9}", Str("\u{e9}\u{4e2d}")),
                      (
                        "x y",
                        Seq([
                          Map([]),
                          Map([("x y", Int(-7L))]),
                          Map([
                            ("s'", Float(0.25)),
                            ("a", Int(-7L)),
                            ("\u{e9}", Float(@double.not_a_number)),
                            ("x y", Str("it's")),
                          ]),
                        ]),
                      ),
                      ("n\nl", Str("'''")),
                    ]),
                  ]),
                ),
              ]),
            ),
            ("s'", Map([])),
          ]),
          Map([
            (
              "q\"",
              Map([
                (
                  "n\nl",
                  Map([
                    (
                      "s'",
                      Seq([
                        Map([]),
                        Map([("a", Bool(true))]),
                        Map([
                          ("s'", Str("x")),
                          ("q\"", Str("\u{1}")),
                          ("x y", Str("\u{1}")),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                ("k-1", Seq([Map([("x y", Float(1.0e20))]), Seq([]), None])),
                ("q\"", Int(-7L)),
              ]),
            ),
          ]),
        ]),
      ),
      ("", Float(1.0e20)),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Seq([
          Map([
            (
              "k-1",
              Map([
                ("n\nl", Float(1.0)),
                ("b", Map([])),
                (
                  "",
                  Seq([
                    Map([("s'", Seq([]))]),
                    Map([
                      ("\u{e9}", Str("")),
                      (
                        "n\nl",
                        Map([("z", Str("")), ("q\"", Float(@double.infinity))]),
                      ),
                    ]),
                    Map([
                      ("\u{e9}", Str("\u{e9}\u{4e2d}")),
                      (
                        "x y",
                        Seq([
                          Map([]),
                          Map([("x y", Int(-7L))]),
                          Map([
                            ("s'", Float(0.25)),
                            ("a", Int(-7L)),
                            ("\u{e9}", Float(@double.not_a_number)),
                            ("x y", Str("it's")),
                          ]),
                        ]),
                      ),
                      ("n\nl", Str("'''")),
                    ]),
                  ]),
                ),
              ]),
            ),
            ("s'", Map([])),
          ]),
          Map([
            (
              "q\"",
              Map([
                (
                  "n\nl",
                  Map([
                    (
                      "s'",
                      Seq([
                        Map([]),
                        Map([("a", Bool(true))]),
                        Map([
                          ("s'", Str("x")),
                          ("q\"", Str("\u{1}")),
                          ("x y", Str("\u{1}")),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                ("k-1", Seq([Map([("x y", Float(1.0e20))]), Seq([]), None])),
                ("q\"", Int(-7L)),
              ]),
            ),
          ]),
        ]),
      ),
      ("", Float(1.0e20)),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "x y",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Seq([
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([
                          ("b", Int(-7L)),
                          ("\u{e9}", Int(1099511627776L)),
                          ("a", Str("")),
                        ]),
                        Map([("\u{e9}", Str("l1\nl2")), ("n\nl", Str("a\"b"))]),
                        Map([("n\nl", Float(3.14159))]),
                      ]),
                    ),
                    ("b", Map([("", Str("")), ("\u{e9}", Str(""))])),
                    ("a", Seq([None, Int(1099511627776L), Str("\t")])),
                  ]),
                ]),
              ]),
            ),
            ("q\"", Str("a\\b")),
          ]),
          Map([
            ("a", Map([])),
            (
              "\u{e9}",
              Seq([
                Bool(true),
                Map([("k-1", Float(@double.infinity)), ("s'", Str("l1\nl2"))]),
              ]),
            ),
          ]),
          Map([
            ("s'", Map([("x y", Float(-0.0)), ("a", Float(3.14159))])),
            (
              "",
              Map([
                ("\u{e9}", Float(1.0)),
                (
                  "",
                  Seq([
                    Seq([
                      Map([
                        ("b", Float(@double.infinity)),
                        ("", Str("\t")),
                        ("n\nl", Str("x'")),
                      ]),
                      Map([
                        ("q\"", Str("\u{e9}\u{4e2d}")),
                        ("a", Float(1.0e-09)),
                      ]),
                    ]),
                  ]),
                ),
                ("k-1", Seq([Float(3.14159), Seq([]), Str("\u{e9}\u{4e2d}")])),
                ("b", Seq([Seq([Int(-7L), None, Str("a\"b")])])),
              ]),
            ),
          ]),
        ]),
      ),
      ("s'", Seq([Str("a\"b")])),
      (
        "",
        Seq([
          Float(@double.infinity),
          Seq([
            Seq([Seq([Str("'''"), Float(0.25), Str("\u{1}")])]),
            Seq([
              Map([
                (
                  "",
                  Map([
                    ("a", Str("x")),
                    ("k-1", Str("a\"\n'b")),
                    ("z", Str("a\"b")),
                    ("x y", Str("a\\b")),
                  ]),
                ),
                ("n\nl", Seq([Str("\u{1}")])),
                ("q\"", Seq([Str("\t"), Str("\u{e9}\u{4e2d}")])),
              ]),
            ]),
          ]),
          Seq([Map([("a", Float(@double.not_a_number))])]),
        ]),
      ),
      ("\u{e9}", Map([("k-1", Float(3.14159))])),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "x y",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Seq([
                  Map([
                    (
                      "q\"",
                      Seq([
                        Map([
                          ("b", Int(-7L)),
                          ("\u{e9}", Int(1099511627776L)),
                          ("a", Str("")),
                        ]),
                        Map([("\u{e9}", Str("l1\nl2")), ("n\nl", Str("a\"b"))]),
                        Map([("n\nl", Float(3.14159))]),
                      ]),
                    ),
                    ("b", Map([("", Str("")), ("\u{e9}", Str(""))])),
                    ("a", Seq([None, Int(1099511627776L), Str("\t")])),
                  ]),
                ]),
              ]),
            ),
            ("q\"", Str("a\\b")),
          ]),
          Map([
            ("a", Map([])),
            (
              "\u{e9}",
              Seq([
                Bool(true),
                Map([("k-1", Float(@double.infinity)), ("s'", Str("l1\nl2"))]),
              ]),
            ),
          ]),
          Map([
            ("s'", Map([("x y", Float(-0.0)), ("a", Float(3.14159))])),
            (
              "",
              Map([
                ("\u{e9}", Float(1.0)),
                (
                  "",
                  Seq([
                    Seq([
                      Map([
                        ("b", Float(@double.infinity)),
                        ("", Str("\t")),
                        ("n\nl", Str("x'")),
                      ]),
                      Map([
                        ("q\"", Str("\u{e9}\u{4e2d}")),
                        ("a", Float(1.0e-09)),
                      ]),
                    ]),
                  ]),
                ),
                ("k-1", Seq([Float(3.14159), Seq([]), Str("\u{e9}\u{4e2d}")])),
                ("b", Seq([Seq([Int(-7L), None, Str("a\"b")])])),
              ]),
            ),
          ]),
        ]),
      ),
      ("s'", Seq([Str("a\"b")])),
      (
        "",
        Seq([
          Float(@double.infinity),
          Seq([
            Seq([Seq([Str("'''"), Float(0.25), Str("\u{1}")])]),
            Seq([
              Map([
                (
                  "",
                  Map([
                    ("a", Str("x")),
                    ("k-1", Str("a\"\n'b")),
                    ("z", Str("a\"b")),
                    ("x y", Str("a\\b")),
                  ]),
                ),
                ("n\nl", Seq([Str("\u{1}")])),
                ("q\"", Seq([Str("\t"), Str("\u{e9}\u{4e2d}")])),
              ]),
            ]),
          ]),
          Seq([Map([("a", Float(@double.not_a_number))])]),
        ]),
      ),
      ("\u{e9}", Map([("k-1", Float(3.14159))])),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("a", Map([]))]), true, "[a]\n")
  check_ser(Map([("a", Map([]))]), false, "[a]\n")
  check_ser(
    Map([
      (
        "\u{e9}",
        Map([
          (
            "k-1",
            Seq([
              Seq([
                Seq([
                  Map([
                    ("a", Str("\u{1}")),
                    ("b", Int(-7L)),
                    ("q\"", Str("it's")),
                  ]),
                ]),
                Seq([Map([])]),
              ]),
              Seq([
                Seq([
                  Map([("n\nl", Str("'''")), ("z", Float(1.0e20))]),
                  Map([("a", Float(1.0))]),
                  Map([("q\"", Float(@double.not_a_number))]),
                ]),
                Seq([Float(1.0)]),
                Seq([Str("\u{1}")]),
              ]),
              Seq([]),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "[\"\u{e9}\"]\nk-1 = [\n    [\n    [{ a = \"\\u0001\", b = -7, 'q\"' = \"it's\" }],\n    [{}],\n],\n    [\n    [\n    { \"n\\nl\" = \"'''\", z = 100000000000000000000.0 },\n    { a = 1.0 },\n    { 'q\"' = nan },\n],\n    [1.0],\n    [\"\\u0001\"],\n],\n    [],\n]\n",
  )
  check_ser(
    Map([
      (
        "\u{e9}",
        Map([
          (
            "k-1",
            Seq([
              Seq([
                Seq([
                  Map([
                    ("a", Str("\u{1}")),
                    ("b", Int(-7L)),
                    ("q\"", Str("it's")),
                  ]),
                ]),
                Seq([Map([])]),
              ]),
              Seq([
                Seq([
                  Map([("n\nl", Str("'''")), ("z", Float(1.0e20))]),
                  Map([("a", Float(1.0))]),
                  Map([("q\"", Float(@double.not_a_number))]),
                ]),
                Seq([Float(1.0)]),
                Seq([Str("\u{1}")]),
              ]),
              Seq([]),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "[\"\u{e9}\"]\nk-1 = [[[{ a = \"\\u0001\", b = -7, 'q\"' = \"it's\" }], [{}]], [[{ \"n\\nl\" = \"'''\", z = 100000000000000000000.0 }, { a = 1.0 }, { 'q\"' = nan }], [1.0], [\"\\u0001\"]], []]\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "z",
        Map([
          ("a", Float(1.0e20)),
          ("k-1", Seq([Float(1.0e-09), Str("\"'"), Str("x'")])),
          ("n\nl", Map([("n\nl", Map([]))])),
        ]),
      ),
      ("\u{e9}", Str("it's")),
    ]),
    true,
    "\"s'\" = []\n\"\u{e9}\" = \"it's\"\n\n[z]\na = 100000000000000000000.0\nk-1 = [\n    0.000000001,\n    \"\\\"'\",\n    \"x'\",\n]\n\n[z.\"n\\nl\".\"n\\nl\"]\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "z",
        Map([
          ("a", Float(1.0e20)),
          ("k-1", Seq([Float(1.0e-09), Str("\"'"), Str("x'")])),
          ("n\nl", Map([("n\nl", Map([]))])),
        ]),
      ),
      ("\u{e9}", Str("it's")),
    ]),
    false,
    "\"s'\" = []\n\"\u{e9}\" = \"it's\"\n\n[z]\na = 100000000000000000000.0\nk-1 = [0.000000001, \"\\\"'\", \"x'\"]\n\n[z.\"n\\nl\".\"n\\nl\"]\n",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([
            ("n\nl", Seq([Str("it's"), Seq([]), Seq([])])),
            ("", Seq([])),
            ("\u{e9}", Int(1099511627776L)),
          ]),
        ]),
      ),
    ]),
    true,
    "[[k-1]]\n\"n\\nl\" = [\n    \"it's\",\n    [],\n    [],\n]\n\"\" = []\n\"\u{e9}\" = 1099511627776\n",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([
            ("n\nl", Seq([Str("it's"), Seq([]), Seq([])])),
            ("", Seq([])),
            ("\u{e9}", Int(1099511627776L)),
          ]),
        ]),
      ),
    ]),
    false,
    "[[k-1]]\n\"n\\nl\" = [\"it's\", [], []]\n\"\" = []\n\"\u{e9}\" = 1099511627776\n",
  )
  check_ser(
    Map([
      ("a", Seq([Seq([Map([("b", Map([])), ("s'", Seq([Float(1.0e20)]))])])])),
      ("z", Float(1.0e-09)),
      (
        "n\nl",
        Seq([
          Seq([
            Seq([
              Map([("z", Str("a\\b")), ("", Float(@double.not_a_number))]),
              Map([("s'", Seq([Int(0L), Float(3.14159)]))]),
              Map([("x y", Seq([]))]),
            ]),
            Seq([Str("a\"\n'b")]),
            Float(-0.0),
          ]),
          Float(0.25),
        ]),
      ),
      ("q\"", Float(-0.0)),
    ]),
    true,
    "a = [[{ b = {}, \"s'\" = [100000000000000000000.0] }]]\nz = 0.000000001\n\"n\\nl\" = [\n    [\n    [\n    { z = 'a\\b', \"\" = nan },\n    { \"s'\" = [\n    0,\n    3.14159,\n] },\n    { \"x y\" = [] },\n],\n    ['''\na\"\n'b'''],\n    -0.0,\n],\n    0.25,\n]\n'q\"' = -0.0\n",
  )
  check_ser(
    Map([
      ("a", Seq([Seq([Map([("b", Map([])), ("s'", Seq([Float(1.0e20)]))])])])),
      ("z", Float(1.0e-09)),
      (
        "n\nl",
        Seq([
          Seq([
            Seq([
              Map([("z", Str("a\\b")), ("", Float(@double.not_a_number))]),
              Map([("s'", Seq([Int(0L), Float(3.14159)]))]),
              Map([("x y", Seq([]))]),
            ]),
            Seq([Str("a\"\n'b")]),
            Float(-0.0),
          ]),
          Float(0.25),
        ]),
      ),
      ("q\"", Float(-0.0)),
    ]),
    false,
    "a = [[{ b = {}, \"s'\" = [100000000000000000000.0] }]]\nz = 0.000000001\n\"n\\nl\" = [[[{ z = 'a\\b', \"\" = nan }, { \"s'\" = [0, 3.14159] }, { \"x y\" = [] }], ['''\na\"\n'b'''], -0.0], 0.25]\n'q\"' = -0.0\n",
  )
  check_ser(
    Map([("\u{e9}", Seq([])), ("n\nl", Seq([])), ("q\"", Str("a\\b"))]),
    true,
    "\"\u{e9}\" = []\n\"n\\nl\" = []\n'q\"' = 'a\\b'\n",
  )
  check_ser(
    Map([("\u{e9}", Seq([])), ("n\nl", Seq([])), ("q\"", Str("a\\b"))]),
    false,
    "\"\u{e9}\" = []\n\"n\\nl\" = []\n'q\"' = 'a\\b'\n",
  )
  check_ser(
    Map([
      ("", Seq([Float(@double.not_a_number)])),
      ("a", Map([])),
      (
        "\u{e9}",
        Seq([
          Str("x'"),
          Str("a\"\n'b"),
          Map([
            ("z", Map([("q\"", Str("\t"))])),
            ("s'", Int(1099511627776L)),
            (
              "",
              Seq([
                Map([
                  ("n\nl", Str("l1\nl2")),
                  ("s'", Seq([Str("'''")])),
                  ("\u{e9}", Seq([Str("it's"), Str(""), Str("\"'")])),
                ]),
                Map([]),
                Map([
                  ("", Seq([Float(1.0e-09), Str("a\"\n'b")])),
                  ("q\"", Int(-7L)),
                  ("n\nl", Seq([])),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    true,
    "\"\" = [nan]\n\"\u{e9}\" = [\n    \"x'\",\n    '''\na\"\n'b''',\n    { z = { 'q\"' = \"\\t\" }, \"s'\" = 1099511627776, \"\" = [\n    { \"n\\nl\" = \"\"\"\nl1\nl2\"\"\", \"s'\" = [\"'''\"], \"\u{e9}\" = [\n    \"it's\",\n    \"\",\n    \"\\\"'\",\n] },\n    {},\n    { \"\" = [\n    0.000000001,\n    '''\na\"\n'b''',\n], 'q\"' = -7, \"n\\nl\" = [] },\n] },\n]\n\n[a]\n",
  )
  check_ser(
    Map([
      ("", Seq([Float(@double.not_a_number)])),
      ("a", Map([])),
      (
        "\u{e9}",
        Seq([
          Str("x'"),
          Str("a\"\n'b"),
          Map([
            ("z", Map([("q\"", Str("\t"))])),
            ("s'", Int(1099511627776L)),
            (
              "",
              Seq([
                Map([
                  ("n\nl", Str("l1\nl2")),
                  ("s'", Seq([Str("'''")])),
                  ("\u{e9}", Seq([Str("it's"), Str(""), Str("\"'")])),
                ]),
                Map([]),
                Map([
                  ("", Seq([Float(1.0e-09), Str("a\"\n'b")])),
                  ("q\"", Int(-7L)),
                  ("n\nl", Seq([])),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    false,
    "\"\" = [nan]\n\"\u{e9}\" = [\"x'\", '''\na\"\n'b''', { z = { 'q\"' = \"\\t\" }, \"s'\" = 1099511627776, \"\" = [{ \"n\\nl\" = \"\"\"\nl1\nl2\"\"\", \"s'\" = [\"'''\"], \"\u{e9}\" = [\"it's\", \"\", \"\\\"'\"] }, {}, { \"\" = [0.000000001, '''\na\"\n'b'''], 'q\"' = -7, \"n\\nl\" = [] }] }]\n\n[a]\n",
  )
  check_ser(Map([("", Seq([])), ("b", Map([]))]), true, "\"\" = []\n\n[b]\n")
  check_ser(Map([("", Seq([])), ("b", Map([]))]), false, "\"\" = []\n\n[b]\n")
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      ("\u{e9}", Str("a\"\n'b")),
      ("s'", Map([("q\"", Float(@double.not_a_number))])),
      ("q\"", Seq([])),
      ("x y", Seq([])),
    ]),
    true,
    "\"\u{e9}\" = '''\na\"\n'b'''\n'q\"' = []\n\"x y\" = []\n\n[\"s'\"]\n'q\"' = nan\n",
  )
  check_ser(
    Map([
      ("\u{e9}", Str("a\"\n'b")),
      ("s'", Map([("q\"", Float(@double.not_a_number))])),
      ("q\"", Seq([])),
      ("x y", Seq([])),
    ]),
    false,
    "\"\u{e9}\" = '''\na\"\n'b'''\n'q\"' = []\n\"x y\" = []\n\n[\"s'\"]\n'q\"' = nan\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Bool(true),
          Seq([
            Str("l1\nl2"),
            Float(1.0),
            Seq([Map([]), Seq([Str(""), Float(1.0e20), Float(1.0e20)])]),
          ]),
        ]),
      ),
      ("s'", Str("'''")),
    ]),
    true,
    "'q\"' = [\n    true,\n    [\n    \"\"\"\nl1\nl2\"\"\",\n    1.0,\n    [\n    {},\n    [\n    \"\",\n    100000000000000000000.0,\n    100000000000000000000.0,\n],\n],\n],\n]\n\"s'\" = \"'''\"\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Bool(true),
          Seq([
            Str("l1\nl2"),
            Float(1.0),
            Seq([Map([]), Seq([Str(""), Float(1.0e20), Float(1.0e20)])]),
          ]),
        ]),
      ),
      ("s'", Str("'''")),
    ]),
    false,
    "'q\"' = [true, [\"\"\"\nl1\nl2\"\"\", 1.0, [{}, [\"\", 100000000000000000000.0, 100000000000000000000.0]]]]\n\"s'\" = \"'''\"\n",
  )
  check_ser(
    Map([
      ("", Str("it's")),
      ("\u{e9}", Str("x")),
      (
        "b",
        Map([
          (
            "q\"",
            Map([
              ("", Map([])),
              ("q\"", Str("\u{e9}\u{4e2d}")),
              ("a", Float(1.0e-09)),
            ]),
          ),
          ("k-1", Bool(false)),
          ("a", Int(-7L)),
          ("", Str("a\\b")),
        ]),
      ),
      (
        "z",
        Map([
          (
            "a",
            Seq([
              Str("it's"),
              Str("\u{e9}\u{4e2d}"),
              Map([
                ("n\nl", Seq([])),
                (
                  "z",
                  Map([
                    ("n\nl", Float(3.14159)),
                    ("q\"", Str("'''")),
                    ("x y", Str("\"'")),
                    ("k-1", Int(0L)),
                  ]),
                ),
                ("", Float(@double.infinity)),
              ]),
            ]),
          ),
          ("s'", Seq([Map([("x y", Str("\t")), ("n\nl", Str("'''"))])])),
          ("z", Seq([Seq([Map([("a", Seq([Str("l1\nl2")]))])]), Str("\u{1}")])),
        ]),
      ),
    ]),
    true,
    "\"\" = \"it's\"\n\"\u{e9}\" = \"x\"\n\n[b]\nk-1 = false\na = -7\n\"\" = 'a\\b'\n\n[b.'q\"']\n'q\"' = \"\u{e9}\u{4e2d}\"\na = 0.000000001\n\n[b.'q\"'.\"\"]\n\n[z]\na = [\n    \"it's\",\n    \"\u{e9}\u{4e2d}\",\n    { \"n\\nl\" = [], z = { \"n\\nl\" = 3.14159, 'q\"' = \"'''\", \"x y\" = \"\\\"'\", k-1 = 0 }, \"\" = inf },\n]\nz = [\n    [{ a = [\"\"\"\nl1\nl2\"\"\"] }],\n    \"\\u0001\",\n]\n\n[[z.\"s'\"]]\n\"x y\" = \"\\t\"\n\"n\\nl\" = \"'''\"\n",
  )
  check_ser(
    Map([
      ("", Str("it's")),
      ("\u{e9}", Str("x")),
      (
        "b",
        Map([
          (
            "q\"",
            Map([
              ("", Map([])),
              ("q\"", Str("\u{e9}\u{4e2d}")),
              ("a", Float(1.0e-09)),
            ]),
          ),
          ("k-1", Bool(false)),
          ("a", Int(-7L)),
          ("", Str("a\\b")),
        ]),
      ),
      (
        "z",
        Map([
          (
            "a",
            Seq([
              Str("it's"),
              Str("\u{e9}\u{4e2d}"),
              Map([
                ("n\nl", Seq([])),
                (
                  "z",
                  Map([
                    ("n\nl", Float(3.14159)),
                    ("q\"", Str("'''")),
                    ("x y", Str("\"'")),
                    ("k-1", Int(0L)),
                  ]),
                ),
                ("", Float(@double.infinity)),
              ]),
            ]),
          ),
          ("s'", Seq([Map([("x y", Str("\t")), ("n\nl", Str("'''"))])])),
          ("z", Seq([Seq([Map([("a", Seq([Str("l1\nl2")]))])]), Str("\u{1}")])),
        ]),
      ),
    ]),
    false,
    "\"\" = \"it's\"\n\"\u{e9}\" = \"x\"\n\n[b]\nk-1 = false\na = -7\n\"\" = 'a\\b'\n\n[b.'q\"']\n'q\"' = \"\u{e9}\u{4e2d}\"\na = 0.000000001\n\n[b.'q\"'.\"\"]\n\n[z]\na = [\"it's\", \"\u{e9}\u{4e2d}\", { \"n\\nl\" = [], z = { \"n\\nl\" = 3.14159, 'q\"' = \"'''\", \"x y\" = \"\\\"'\", k-1 = 0 }, \"\" = inf }]\nz = [[{ a = [\"\"\"\nl1\nl2\"\"\"] }], \"\\u0001\"]\n\n[[z.\"s'\"]]\n\"x y\" = \"\\t\"\n\"n\\nl\" = \"'''\"\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "k-1",
        Map([
          (
            "s'",
            Seq([
              Map([
                ("", Str("a\"\n'b")),
                (
                  "n\nl",
                  Seq([
                    Map([]),
                    Map([
                      (
                        "x y",
                        Map([
                          ("b", Float(@double.infinity)),
                          ("x y", Float(@double.infinity)),
                        ]),
                      ),
                      (
                        "n\nl",
                        Seq([
                          Map([
                            ("a", Float(@double.infinity)),
                            ("n\nl", Str("a\"\n'b")),
                          ]),
                          Map([]),
                          Map([]),
                        ]),
                      ),
                      ("a", Seq([Float(@double.infinity), Int(-7L), Str("")])),
                    ]),
                  ]),
                ),
              ]),
              Map([
                (
                  "b",
                  Seq([
                    Seq([Map([("k-1", Float(@double.not_a_number))])]),
                    Float(-0.0),
                  ]),
                ),
                ("", Map([])),
                ("a", Map([("a", Seq([Str("'''")]))])),
                (
                  "s'",
                  Seq([
                    Map([
                      ("", Float(1.0e-09)),
                      ("\u{e9}", Seq([])),
                      ("z", Seq([Str(""), Int(1099511627776L)])),
                    ]),
                    Map([]),
                    Map([
                      ("", Seq([])),
                      ("b", Str("l1\nl2")),
                      ("k-1", Map([("n\nl", Str("it's"))])),
                      ("a", Seq([Int(0L)])),
                    ]),
                  ]),
                ),
              ]),
            ]),
          ),
          (
            "k-1",
            Seq([
              Seq([Float(@double.infinity)]),
              Str("x'"),
              Seq([Seq([Str("\u{e9}\u{4e2d}")])]),
            ]),
          ),
          (
            "z",
            Seq([
              Seq([]),
              Seq([
                Int(1099511627776L),
                Seq([
                  Map([("n\nl", Str("\"'")), ("a", Str("a\"b"))]),
                  Map([("a", Bool(true))]),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
      (
        "x y",
        Seq([
          Seq([
            Map([
              (
                "n\nl",
                Seq([
                  Str("'''"),
                  Str("\u{e9}\u{4e2d}"),
                  Map([("", Float(0.25))]),
                ]),
              ),
              ("a", Str("a\"\n'b")),
              ("q\"", Float(1.0)),
            ]),
            Map([
              ("\u{e9}", Str("a\\b")),
              (
                "x y",
                Seq([
                  Map([("s'", Str("it's"))]),
                  Map([
                    ("q\"", Bool(true)),
                    ("", Seq([Str("x")])),
                    ("s'", Str("a\"b")),
                  ]),
                  Map([("b", Str("\t"))]),
                ]),
              ),
              (
                "",
                Map([
                  ("x y", Map([("", Str("a\"\n'b"))])),
                  (
                    "n\nl",
                    Map([("b", Float(@double.infinity)), ("q\"", Str(""))]),
                  ),
                  ("s'", Int(1099511627776L)),
                ]),
              ),
              (
                "n\nl",
                Seq([
                  Bool(false),
                  Seq([Float(1.0), Str("x"), Str("a\"\n'b")]),
                  Seq([Str("x'"), None, Float(@double.not_a_number)]),
                ]),
              ),
            ]),
          ]),
          Str("\"'"),
          Int(1099511627776L),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "k-1",
        Map([
          (
            "s'",
            Seq([
              Map([
                ("", Str("a\"\n'b")),
                (
                  "n\nl",
                  Seq([
                    Map([]),
                    Map([
                      (
                        "x y",
                        Map([
                          ("b", Float(@double.infinity)),
                          ("x y", Float(@double.infinity)),
                        ]),
                      ),
                      (
                        "n\nl",
                        Seq([
                          Map([
                            ("a", Float(@double.infinity)),
                            ("n\nl", Str("a\"\n'b")),
                          ]),
                          Map([]),
                          Map([]),
                        ]),
                      ),
                      ("a", Seq([Float(@double.infinity), Int(-7L), Str("")])),
                    ]),
                  ]),
                ),
              ]),
              Map([
                (
                  "b",
                  Seq([
                    Seq([Map([("k-1", Float(@double.not_a_number))])]),
                    Float(-0.0),
                  ]),
                ),
                ("", Map([])),
                ("a", Map([("a", Seq([Str("'''")]))])),
                (
                  "s'",
                  Seq([
                    Map([
                      ("", Float(1.0e-09)),
                      ("\u{e9}", Seq([])),
                      ("z", Seq([Str(""), Int(1099511627776L)])),
                    ]),
                    Map([]),
                    Map([
                      ("", Seq([])),
                      ("b", Str("l1\nl2")),
                      ("k-1", Map([("n\nl", Str("it's"))])),
                      ("a", Seq([Int(0L)])),
                    ]),
                  ]),
                ),
              ]),
            ]),
          ),
          (
            "k-1",
            Seq([
              Seq([Float(@double.infinity)]),
              Str("x'"),
              Seq([Seq([Str("\u{e9}\u{4e2d}")])]),
            ]),
          ),
          (
            "z",
            Seq([
              Seq([]),
              Seq([
                Int(1099511627776L),
                Seq([
                  Map([("n\nl", Str("\"'")), ("a", Str("a\"b"))]),
                  Map([("a", Bool(true))]),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
      (
        "x y",
        Seq([
          Seq([
            Map([
              (
                "n\nl",
                Seq([
                  Str("'''"),
                  Str("\u{e9}\u{4e2d}"),
                  Map([("", Float(0.25))]),
                ]),
              ),
              ("a", Str("a\"\n'b")),
              ("q\"", Float(1.0)),
            ]),
            Map([
              ("\u{e9}", Str("a\\b")),
              (
                "x y",
                Seq([
                  Map([("s'", Str("it's"))]),
                  Map([
                    ("q\"", Bool(true)),
                    ("", Seq([Str("x")])),
                    ("s'", Str("a\"b")),
                  ]),
                  Map([("b", Str("\t"))]),
                ]),
              ),
              (
                "",
                Map([
                  ("x y", Map([("", Str("a\"\n'b"))])),
                  (
                    "n\nl",
                    Map([("b", Float(@double.infinity)), ("q\"", Str(""))]),
                  ),
                  ("s'", Int(1099511627776L)),
                ]),
              ),
              (
                "n\nl",
                Seq([
                  Bool(false),
                  Seq([Float(1.0), Str("x"), Str("a\"\n'b")]),
                  Seq([Str("x'"), None, Float(@double.not_a_number)]),
                ]),
              ),
            ]),
          ]),
          Str("\"'"),
          Int(1099511627776L),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("b", Seq([Map([("k-1", Float(1.0e20)), ("z", Str("\"'"))])])),
      ("a", Seq([Str("a\\b")])),
      ("k-1", Seq([Str("a\"\n'b")])),
    ]),
    true,
    "a = ['a\\b']\nk-1 = ['''\na\"\n'b''']\n\n[[b]]\nk-1 = 100000000000000000000.0\nz = \"\\\"'\"\n",
  )
  check_ser(
    Map([
      ("b", Seq([Map([("k-1", Float(1.0e20)), ("z", Str("\"'"))])])),
      ("a", Seq([Str("a\\b")])),
      ("k-1", Seq([Str("a\"\n'b")])),
    ]),
    false,
    "a = ['a\\b']\nk-1 = ['''\na\"\n'b''']\n\n[[b]]\nk-1 = 100000000000000000000.0\nz = \"\\\"'\"\n",
  )
  check_ser(
    Map([
      ("x y", Str("\t")),
      (
        "a",
        Seq([
          Map([("k-1", Str("it's"))]),
          Map([
            (
              "x y",
              Map([
                ("b", Str("a\\b")),
                ("", Str("\u{e9}\u{4e2d}")),
                ("n\nl", Str("a\"b")),
              ]),
            ),
          ]),
          Map([
            ("q\"", Float(1.0e-09)),
            ("k-1", Float(0.25)),
            (
              "z",
              Seq([
                Str("x"),
                Str(""),
                Seq([
                  Map([
                    (
                      "",
                      Map([
                        ("", Float(1.0e20)),
                        ("x y", Str("\t")),
                        ("k-1", Str("\"'")),
                      ]),
                    ),
                  ]),
                  Map([
                    ("x y", Seq([])),
                    ("q\"", Str("\u{e9}\u{4e2d}")),
                    ("n\nl", Seq([Str("x'")])),
                    (
                      "z",
                      Seq([
                        Map([]),
                        Map([
                          ("", Str("\t")),
                          ("a", Bool(true)),
                          ("z", Bool(true)),
                        ]),
                      ]),
                    ),
                  ]),
                  Map([("b", Int(1099511627776L)), ("x y", Str("x'"))]),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
      ("z", Str("l1\nl2")),
    ]),
    true,
    "\"x y\" = \"\\t\"\nz = \"\"\"\nl1\nl2\"\"\"\n\n[[a]]\nk-1 = \"it's\"\n\n[[a]]\n\n[a.\"x y\"]\nb = 'a\\b'\n\"\" = \"\u{e9}\u{4e2d}\"\n\"n\\nl\" = 'a\"b'\n\n[[a]]\n'q\"' = 0.000000001\nk-1 = 0.25\nz = [\n    \"x\",\n    \"\",\n    [\n    { \"\" = { \"\" = 100000000000000000000.0, \"x y\" = \"\\t\", k-1 = \"\\\"'\" } },\n    { \"x y\" = [], 'q\"' = \"\u{e9}\u{4e2d}\", \"n\\nl\" = [\"x'\"], z = [\n    {},\n    { \"\" = \"\\t\", a = true, z = true },\n] },\n    { b = 1099511627776, \"x y\" = \"x'\" },\n],\n]\n",
  )
  check_ser(
    Map([
      ("x y", Str("\t")),
      (
        "a",
        Seq([
          Map([("k-1", Str("it's"))]),
          Map([
            (
              "x y",
              Map([
                ("b", Str("a\\b")),
                ("", Str("\u{e9}\u{4e2d}")),
                ("n\nl", Str("a\"b")),
              ]),
            ),
          ]),
          Map([
            ("q\"", Float(1.0e-09)),
            ("k-1", Float(0.25)),
            (
              "z",
              Seq([
                Str("x"),
                Str(""),
                Seq([
                  Map([
                    (
                      "",
                      Map([
                        ("", Float(1.0e20)),
                        ("x y", Str("\t")),
                        ("k-1", Str("\"'")),
                      ]),
                    ),
                  ]),
                  Map([
                    ("x y", Seq([])),
                    ("q\"", Str("\u{e9}\u{4e2d}")),
                    ("n\nl", Seq([Str("x'")])),
                    (
                      "z",
                      Seq([
                        Map([]),
                        Map([
                          ("", Str("\t")),
                          ("a", Bool(true)),
                          ("z", Bool(true)),
                        ]),
                      ]),
                    ),
                  ]),
                  Map([("b", Int(1099511627776L)), ("x y", Str("x'"))]),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
      ("z", Str("l1\nl2")),
    ]),
    false,
    "\"x y\" = \"\\t\"\nz = \"\"\"\nl1\nl2\"\"\"\n\n[[a]]\nk-1 = \"it's\"\n\n[[a]]\n\n[a.\"x y\"]\nb = 'a\\b'\n\"\" = \"\u{e9}\u{4e2d}\"\n\"n\\nl\" = 'a\"b'\n\n[[a]]\n'q\"' = 0.000000001\nk-1 = 0.25\nz = [\"x\", \"\", [{ \"\" = { \"\" = 100000000000000000000.0, \"x y\" = \"\\t\", k-1 = \"\\\"'\" } }, { \"x y\" = [], 'q\"' = \"\u{e9}\u{4e2d}\", \"n\\nl\" = [\"x'\"], z = [{}, { \"\" = \"\\t\", a = true, z = true }] }, { b = 1099511627776, \"x y\" = \"x'\" }]]\n",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Map([
          (
            "s'",
            Seq([
              Map([
                (
                  "n\nl",
                  Map([
                    (
                      "",
                      Seq([
                        Map([("x y", Str("a\"b"))]),
                        Map([("k-1", Float(0.25))]),
                      ]),
                    ),
                    (
                      "a",
                      Seq([
                        Map([("x y", Str("a\"b"))]),
                        Map([("k-1", Str("a\"\n'b"))]),
                      ]),
                    ),
                    ("k-1", Int(1099511627776L)),
                  ]),
                ),
                (
                  "x y",
                  Seq([
                    Map([
                      ("k-1", Map([("q\"", Str("\u{e9}\u{4e2d}"))])),
                      (
                        "a",
                        Seq([
                          Map([("k-1", Bool(true))]),
                          Map([]),
                          Map([("z", Float(3.14159))]),
                        ]),
                      ),
                    ]),
                    Map([
                      (
                        "a",
                        Map([
                          ("q\"", Int(-7L)),
                          ("\u{e9}", Float(-0.0)),
                          ("z", Str("\t")),
                        ]),
                      ),
                      (
                        "n\nl",
                        Seq([
                          Map([
                            ("n\nl", Float(1.0e20)),
                            ("a", Float(@double.infinity)),
                          ]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                (
                  "b",
                  Seq([
                    Map([("a", Float(0.25)), ("\u{e9}", Map([("", Str("x"))]))]),
                    Map([
                      ("b", Float(@double.not_a_number)),
                      ("s'", Str("l1\nl2")),
                    ]),
                  ]),
                ),
                ("q\"", Seq([Seq([])])),
              ]),
              Map([
                ("q\"", Seq([Map([("a", Str(""))])])),
                ("\u{e9}", Seq([])),
                (
                  "",
                  Seq([
                    Seq([
                      Map([]),
                      Map([]),
                      Map([("q\"", Int(-7L)), ("x y", Str("\"'"))]),
                    ]),
                    Map([
                      ("q\"", Float(-0.0)),
                      ("n\nl", Int(1099511627776L)),
                      ("x y", Float(1.0)),
                      ("b", Str("'''")),
                    ]),
                  ]),
                ),
              ]),
              Map([("a", Seq([Str("a\"\n'b"), Str("'''")]))]),
            ]),
          ),
          (
            "n\nl",
            Seq([
              Seq([
                Map([
                  ("\u{e9}", Str("'''")),
                  ("q\"", Map([])),
                  ("z", Float(@double.infinity)),
                ]),
                Map([
                  ("a", Seq([Str("'''"), Int(1099511627776L)])),
                  (
                    "k-1",
                    Seq([
                      Map([
                        ("k-1", Str("\t")),
                        ("a", Float(3.14159)),
                        ("x y", Str("")),
                        ("b", Int(1099511627776L)),
                      ]),
                      Map([
                        ("", Str("'''")),
                        ("k-1", Str("a\\b")),
                        ("q\"", Str("x'")),
                      ]),
                      Map([]),
                    ]),
                  ),
                ]),
                Map([
                  ("b", Seq([Bool(true), Float(0.25), Float(1.0e-09)])),
                  ("s'", Float(1.0e20)),
                  (
                    "n\nl",
                    Map([
                      ("b", Bool(false)),
                      ("q\"", Str("a\\b")),
                      ("k-1", Str("x")),
                    ]),
                  ),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
      ("z", Map([])),
      ("a", Bool(false)),
    ]),
    true,
    "a = false\n\n[\"n\\nl\"]\n\"n\\nl\" = [[\n    { \"\u{e9}\" = \"'''\", 'q\"' = {}, z = inf },\n    { a = [\n    \"'''\",\n    1099511627776,\n], k-1 = [\n    { k-1 = \"\\t\", a = 3.14159, \"x y\" = \"\", b = 1099511627776 },\n    { \"\" = \"'''\", k-1 = 'a\\b', 'q\"' = \"x'\" },\n    {},\n] },\n    { b = [\n    true,\n    0.25,\n    0.000000001,\n], \"s'\" = 100000000000000000000.0, \"n\\nl\" = { b = false, 'q\"' = 'a\\b', k-1 = \"x\" } },\n]]\n\n[[\"n\\nl\".\"s'\"]]\n'q\"' = [[]]\n\n[\"n\\nl\".\"s'\".\"n\\nl\"]\nk-1 = 1099511627776\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".\"\"]]\n\"x y\" = 'a\"b'\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".\"\"]]\nk-1 = 0.25\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".a]]\n\"x y\" = 'a\"b'\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".a]]\nk-1 = '''\na\"\n'b'''\n\n[[\"n\\nl\".\"s'\".\"x y\"]]\n\n[\"n\\nl\".\"s'\".\"x y\".k-1]\n'q\"' = \"\u{e9}\u{4e2d}\"\n\n[[\"n\\nl\".\"s'\".\"x y\".a]]\nk-1 = true\n\n[[\"n\\nl\".\"s'\".\"x y\".a]]\n\n[[\"n\\nl\".\"s'\".\"x y\".a]]\nz = 3.14159\n\n[[\"n\\nl\".\"s'\".\"x y\"]]\n\n[\"n\\nl\".\"s'\".\"x y\".a]\n'q\"' = -7\n\"\u{e9}\" = -0.0\nz = \"\\t\"\n\n[[\"n\\nl\".\"s'\".\"x y\".\"n\\nl\"]]\n\"n\\nl\" = 100000000000000000000.0\na = inf\n\n[[\"n\\nl\".\"s'\".b]]\na = 0.25\n\n[\"n\\nl\".\"s'\".b.\"\u{e9}\"]\n\"\" = \"x\"\n\n[[\"n\\nl\".\"s'\".b]]\nb = nan\n\"s'\" = \"\"\"\nl1\nl2\"\"\"\n\n[[\"n\\nl\".\"s'\"]]\n\"\u{e9}\" = []\n\"\" = [\n    [\n    {},\n    {},\n    { 'q\"' = -7, \"x y\" = \"\\\"'\" },\n],\n    { 'q\"' = -0.0, \"n\\nl\" = 1099511627776, \"x y\" = 1.0, b = \"'''\" },\n]\n\n[[\"n\\nl\".\"s'\".'q\"']]\na = \"\"\n\n[[\"n\\nl\".\"s'\"]]\na = [\n    '''\na\"\n'b''',\n    \"'''\",\n]\n\n[z]\n",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Map([
          (
            "s'",
            Seq([
              Map([
                (
                  "n\nl",
                  Map([
                    (
                      "",
                      Seq([
                        Map([("x y", Str("a\"b"))]),
                        Map([("k-1", Float(0.25))]),
                      ]),
                    ),
                    (
                      "a",
                      Seq([
                        Map([("x y", Str("a\"b"))]),
                        Map([("k-1", Str("a\"\n'b"))]),
                      ]),
                    ),
                    ("k-1", Int(1099511627776L)),
                  ]),
                ),
                (
                  "x y",
                  Seq([
                    Map([
                      ("k-1", Map([("q\"", Str("\u{e9}\u{4e2d}"))])),
                      (
                        "a",
                        Seq([
                          Map([("k-1", Bool(true))]),
                          Map([]),
                          Map([("z", Float(3.14159))]),
                        ]),
                      ),
                    ]),
                    Map([
                      (
                        "a",
                        Map([
                          ("q\"", Int(-7L)),
                          ("\u{e9}", Float(-0.0)),
                          ("z", Str("\t")),
                        ]),
                      ),
                      (
                        "n\nl",
                        Seq([
                          Map([
                            ("n\nl", Float(1.0e20)),
                            ("a", Float(@double.infinity)),
                          ]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                (
                  "b",
                  Seq([
                    Map([("a", Float(0.25)), ("\u{e9}", Map([("", Str("x"))]))]),
                    Map([
                      ("b", Float(@double.not_a_number)),
                      ("s'", Str("l1\nl2")),
                    ]),
                  ]),
                ),
                ("q\"", Seq([Seq([])])),
              ]),
              Map([
                ("q\"", Seq([Map([("a", Str(""))])])),
                ("\u{e9}", Seq([])),
                (
                  "",
                  Seq([
                    Seq([
                      Map([]),
                      Map([]),
                      Map([("q\"", Int(-7L)), ("x y", Str("\"'"))]),
                    ]),
                    Map([
                      ("q\"", Float(-0.0)),
                      ("n\nl", Int(1099511627776L)),
                      ("x y", Float(1.0)),
                      ("b", Str("'''")),
                    ]),
                  ]),
                ),
              ]),
              Map([("a", Seq([Str("a\"\n'b"), Str("'''")]))]),
            ]),
          ),
          (
            "n\nl",
            Seq([
              Seq([
                Map([
                  ("\u{e9}", Str("'''")),
                  ("q\"", Map([])),
                  ("z", Float(@double.infinity)),
                ]),
                Map([
                  ("a", Seq([Str("'''"), Int(1099511627776L)])),
                  (
                    "k-1",
                    Seq([
                      Map([
                        ("k-1", Str("\t")),
                        ("a", Float(3.14159)),
                        ("x y", Str("")),
                        ("b", Int(1099511627776L)),
                      ]),
                      Map([
                        ("", Str("'''")),
                        ("k-1", Str("a\\b")),
                        ("q\"", Str("x'")),
                      ]),
                      Map([]),
                    ]),
                  ),
                ]),
                Map([
                  ("b", Seq([Bool(true), Float(0.25), Float(1.0e-09)])),
                  ("s'", Float(1.0e20)),
                  (
                    "n\nl",
                    Map([
                      ("b", Bool(false)),
                      ("q\"", Str("a\\b")),
                      ("k-1", Str("x")),
                    ]),
                  ),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
      ("z", Map([])),
      ("a", Bool(false)),
    ]),
    false,
    "a = false\n\n[\"n\\nl\"]\n\"n\\nl\" = [[{ \"\u{e9}\" = \"'''\", 'q\"' = {}, z = inf }, { a = [\"'''\", 1099511627776], k-1 = [{ k-1 = \"\\t\", a = 3.14159, \"x y\" = \"\", b = 1099511627776 }, { \"\" = \"'''\", k-1 = 'a\\b', 'q\"' = \"x'\" }, {}] }, { b = [true, 0.25, 0.000000001], \"s'\" = 100000000000000000000.0, \"n\\nl\" = { b = false, 'q\"' = 'a\\b', k-1 = \"x\" } }]]\n\n[[\"n\\nl\".\"s'\"]]\n'q\"' = [[]]\n\n[\"n\\nl\".\"s'\".\"n\\nl\"]\nk-1 = 1099511627776\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".\"\"]]\n\"x y\" = 'a\"b'\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".\"\"]]\nk-1 = 0.25\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".a]]\n\"x y\" = 'a\"b'\n\n[[\"n\\nl\".\"s'\".\"n\\nl\".a]]\nk-1 = '''\na\"\n'b'''\n\n[[\"n\\nl\".\"s'\".\"x y\"]]\n\n[\"n\\nl\".\"s'\".\"x y\".k-1]\n'q\"' = \"\u{e9}\u{4e2d}\"\n\n[[\"n\\nl\".\"s'\".\"x y\".a]]\nk-1 = true\n\n[[\"n\\nl\".\"s'\".\"x y\".a]]\n\n[[\"n\\nl\".\"s'\".\"x y\".a]]\nz = 3.14159\n\n[[\"n\\nl\".\"s'\".\"x y\"]]\n\n[\"n\\nl\".\"s'\".\"x y\".a]\n'q\"' = -7\n\"\u{e9}\" = -0.0\nz = \"\\t\"\n\n[[\"n\\nl\".\"s'\".\"x y\".\"n\\nl\"]]\n\"n\\nl\" = 100000000000000000000.0\na = inf\n\n[[\"n\\nl\".\"s'\".b]]\na = 0.25\n\n[\"n\\nl\".\"s'\".b.\"\u{e9}\"]\n\"\" = \"x\"\n\n[[\"n\\nl\".\"s'\".b]]\nb = nan\n\"s'\" = \"\"\"\nl1\nl2\"\"\"\n\n[[\"n\\nl\".\"s'\"]]\n\"\u{e9}\" = []\n\"\" = [[{}, {}, { 'q\"' = -7, \"x y\" = \"\\\"'\" }], { 'q\"' = -0.0, \"n\\nl\" = 1099511627776, \"x y\" = 1.0, b = \"'''\" }]\n\n[[\"n\\nl\".\"s'\".'q\"']]\na = \"\"\n\n[[\"n\\nl\".\"s'\"]]\na = ['''\na\"\n'b''', \"'''\"]\n\n[z]\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Map([
            ("k-1", Seq([Float(@double.infinity), Int(0L)])),
            ("q\"", Float(1.0e20)),
          ]),
          Seq([
            Map([
              ("a", Float(3.14159)),
              ("\u{e9}", Map([("n\nl", Float(@double.not_a_number))])),
              ("n\nl", Seq([Int(0L)])),
              ("z", Float(-0.0)),
            ]),
            Seq([
              Map([("", Seq([Int(0L)])), ("n\nl", Seq([]))]),
              Map([("\u{e9}", Seq([Str("\"'"), Int(0L)]))]),
            ]),
          ]),
        ]),
      ),
      ("k-1", Str("\u{1}")),
    ]),
    true,
    "z = [\n    { k-1 = [\n    inf,\n    0,\n], 'q\"' = 100000000000000000000.0 },\n    [\n    { a = 3.14159, \"\u{e9}\" = { \"n\\nl\" = nan }, \"n\\nl\" = [0], z = -0.0 },\n    [\n    { \"\" = [0], \"n\\nl\" = [] },\n    { \"\u{e9}\" = [\n    \"\\\"'\",\n    0,\n] },\n],\n],\n]\nk-1 = \"\\u0001\"\n",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Map([
            ("k-1", Seq([Float(@double.infinity), Int(0L)])),
            ("q\"", Float(1.0e20)),
          ]),
          Seq([
            Map([
              ("a", Float(3.14159)),
              ("\u{e9}", Map([("n\nl", Float(@double.not_a_number))])),
              ("n\nl", Seq([Int(0L)])),
              ("z", Float(-0.0)),
            ]),
            Seq([
              Map([("", Seq([Int(0L)])), ("n\nl", Seq([]))]),
              Map([("\u{e9}", Seq([Str("\"'"), Int(0L)]))]),
            ]),
          ]),
        ]),
      ),
      ("k-1", Str("\u{1}")),
    ]),
    false,
    "z = [{ k-1 = [inf, 0], 'q\"' = 100000000000000000000.0 }, [{ a = 3.14159, \"\u{e9}\" = { \"n\\nl\" = nan }, \"n\\nl\" = [0], z = -0.0 }, [{ \"\" = [0], \"n\\nl\" = [] }, { \"\u{e9}\" = [\"\\\"'\", 0] }]]]\nk-1 = \"\\u0001\"\n",
  )
  check_ser(
    Map([("n\nl", Str("a\\b")), ("", Str("a\\b"))]),
    true,
    "\"n\\nl\" = 'a\\b'\n\"\" = 'a\\b'\n",
  )
  check_ser(
    Map([("n\nl", Str("a\\b")), ("", Str("a\\b"))]),
    false,
    "\"n\\nl\" = 'a\\b'\n\"\" = 'a\\b'\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([]),
          Map([
            ("b", Seq([Map([("x y", Str(""))])])),
            ("\u{e9}", Seq([])),
            (
              "z",
              Map([
                ("z", Seq([Str("a\"b")])),
                (
                  "\u{e9}",
                  Map([
                    ("n\nl", Map([])),
                    ("s'", Seq([Str("it's"), Float(@double.infinity)])),
                  ]),
                ),
              ]),
            ),
            (
              "n\nl",
              Seq([
                Map([
                  ("b", Seq([Map([("\u{e9}", Str("\t"))])])),
                  ("z", Map([("z", Float(@double.not_a_number))])),
                ]),
                Map([]),
                Seq([
                  Seq([
                    Map([
                      ("b", Int(1099511627776L)),
                      ("\u{e9}", Int(1099511627776L)),
                    ]),
                    Map([("q\"", Str("x"))]),
                    Map([("a", Int(1099511627776L))]),
                  ]),
                  Map([("b", Str("\u{1}"))]),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
      ("z", Seq([])),
      (
        "x y",
        Seq([
          Float(@double.not_a_number),
          Map([
            ("x y", None),
            ("k-1", Seq([Seq([Float(3.14159)]), Str("\t"), Seq([])])),
          ]),
        ]),
      ),
    ]),
    true,
    "z = []\n\"x y\" = [\n    nan,\n    { k-1 = [\n    [3.14159],\n    \"\\t\",\n    [],\n] },\n]\n\n[[k-1]]\n\n[[k-1]]\n\"\u{e9}\" = []\n\"n\\nl\" = [\n    { b = [{ \"\u{e9}\" = \"\\t\" }], z = { z = nan } },\n    {},\n    [\n    [\n    { b = 1099511627776, \"\u{e9}\" = 1099511627776 },\n    { 'q\"' = \"x\" },\n    { a = 1099511627776 },\n],\n    { b = \"\\u0001\" },\n],\n]\n\n[[k-1.b]]\n\"x y\" = \"\"\n\n[k-1.z]\nz = ['a\"b']\n\n[k-1.z.\"\u{e9}\"]\n\"s'\" = [\n    \"it's\",\n    inf,\n]\n\n[k-1.z.\"\u{e9}\".\"n\\nl\"]\n",
  )
  check_ser(
    Map([
      (
        "k-1",
        Seq([
          Map([]),
          Map([
            ("b", Seq([Map([("x y", Str(""))])])),
            ("\u{e9}", Seq([])),
            (
              "z",
              Map([
                ("z", Seq([Str("a\"b")])),
                (
                  "\u{e9}",
                  Map([
                    ("n\nl", Map([])),
                    ("s'", Seq([Str("it's"), Float(@double.infinity)])),
                  ]),
                ),
              ]),
            ),
            (
              "n\nl",
              Seq([
                Map([
                  ("b", Seq([Map([("\u{e9}", Str("\t"))])])),
                  ("z", Map([("z", Float(@double.not_a_number))])),
                ]),
                Map([]),
                Seq([
                  Seq([
                    Map([
                      ("b", Int(1099511627776L)),
                      ("\u{e9}", Int(1099511627776L)),
                    ]),
                    Map([("q\"", Str("x"))]),
                    Map([("a", Int(1099511627776L))]),
                  ]),
                  Map([("b", Str("\u{1}"))]),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
      ("z", Seq([])),
      (
        "x y",
        Seq([
          Float(@double.not_a_number),
          Map([
            ("x y", None),
            ("k-1", Seq([Seq([Float(3.14159)]), Str("\t"), Seq([])])),
          ]),
        ]),
      ),
    ]),
    false,
    "z = []\n\"x y\" = [nan, { k-1 = [[3.14159], \"\\t\", []] }]\n\n[[k-1]]\n\n[[k-1]]\n\"\u{e9}\" = []\n\"n\\nl\" = [{ b = [{ \"\u{e9}\" = \"\\t\" }], z = { z = nan } }, {}, [[{ b = 1099511627776, \"\u{e9}\" = 1099511627776 }, { 'q\"' = \"x\" }, { a = 1099511627776 }], { b = \"\\u0001\" }]]\n\n[[k-1.b]]\n\"x y\" = \"\"\n\n[k-1.z]\nz = ['a\"b']\n\n[k-1.z.\"\u{e9}\"]\n\"s'\" = [\"it's\", inf]\n\n[k-1.z.\"\u{e9}\".\"n\\nl\"]\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      ("x y", Float(@double.infinity)),
      ("a", Float(-0.0)),
      ("q\"", Str("a\"\n'b")),
    ]),
    true,
    "\"s'\" = []\n\"x y\" = inf\na = -0.0\n'q\"' = '''\na\"\n'b'''\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      ("x y", Float(@double.infinity)),
      ("a", Float(-0.0)),
      ("q\"", Str("a\"\n'b")),
    ]),
    false,
    "\"s'\" = []\n\"x y\" = inf\na = -0.0\n'q\"' = '''\na\"\n'b'''\n",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "n\nl",
        Seq([
          Map([("\u{e9}", Float(0.25))]),
          Map([("a", Float(1.0e20))]),
          Map([
            ("k-1", Map([("n\nl", Float(1.0e20)), ("b", Seq([None]))])),
            ("n\nl", Str("x'")),
            ("x y", Str("l1\nl2")),
            (
              "b",
              Seq([
                Seq([
                  Seq([
                    Map([
                      ("s'", Float(@double.infinity)),
                      ("x y", Str("a\"b")),
                      ("", Str("\"'")),
                    ]),
                    Map([]),
                  ]),
                  Seq([
                    Map([
                      ("k-1", Bool(false)),
                      ("s'", Str("a\"\n'b")),
                      ("a", Str("a\\b")),
                    ]),
                    Map([("k-1", Str("\u{1}"))]),
                  ]),
                  Seq([Str("\u{e9}\u{4e2d}")]),
                ]),
                Seq([
                  Float(3.14159),
                  Seq([Str("\u{1}"), Str("l1\nl2")]),
                  Seq([Str("\u{e9}\u{4e2d}"), Str("\"'")]),
                ]),
                Map([("s'", Str("\u{e9}\u{4e2d}"))]),
              ]),
            ),
          ]),
        ]),
      ),
      ("", Str("a\"\n'b")),
      ("b", Str("'''")),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("s'", Seq([])),
      (
        "n\nl",
        Seq([
          Map([("\u{e9}", Float(0.25))]),
          Map([("a", Float(1.0e20))]),
          Map([
            ("k-1", Map([("n\nl", Float(1.0e20)), ("b", Seq([None]))])),
            ("n\nl", Str("x'")),
            ("x y", Str("l1\nl2")),
            (
              "b",
              Seq([
                Seq([
                  Seq([
                    Map([
                      ("s'", Float(@double.infinity)),
                      ("x y", Str("a\"b")),
                      ("", Str("\"'")),
                    ]),
                    Map([]),
                  ]),
                  Seq([
                    Map([
                      ("k-1", Bool(false)),
                      ("s'", Str("a\"\n'b")),
                      ("a", Str("a\\b")),
                    ]),
                    Map([("k-1", Str("\u{1}"))]),
                  ]),
                  Seq([Str("\u{e9}\u{4e2d}")]),
                ]),
                Seq([
                  Float(3.14159),
                  Seq([Str("\u{1}"), Str("l1\nl2")]),
                  Seq([Str("\u{e9}\u{4e2d}"), Str("\"'")]),
                ]),
                Map([("s'", Str("\u{e9}\u{4e2d}"))]),
              ]),
            ),
          ]),
        ]),
      ),
      ("", Str("a\"\n'b")),
      ("b", Str("'''")),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      ("k-1", Seq([Str("a\"\n'b"), Int(1099511627776L), Float(1.0e20)])),
      ("s'", Str("it's")),
      ("x y", Str("\t")),
    ]),
    true,
    "k-1 = [\n    '''\na\"\n'b''',\n    1099511627776,\n    100000000000000000000.0,\n]\n\"s'\" = \"it's\"\n\"x y\" = \"\\t\"\n",
  )
  check_ser(
    Map([
      ("k-1", Seq([Str("a\"\n'b"), Int(1099511627776L), Float(1.0e20)])),
      ("s'", Str("it's")),
      ("x y", Str("\t")),
    ]),
    false,
    "k-1 = ['''\na\"\n'b''', 1099511627776, 100000000000000000000.0]\n\"s'\" = \"it's\"\n\"x y\" = \"\\t\"\n",
  )
  check_ser(
    Map([("x y", Float(@double.not_a_number))]),
    true,
    "\"x y\" = nan\n",
  )
  check_ser(
    Map([("x y", Float(@double.not_a_number))]),
    false,
    "\"x y\" = nan\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      (
        "z",
        Seq([
          Map([
            (
              "\u{e9}",
              Seq([Seq([Str("\u{e9}\u{4e2d}"), Int(1099511627776L)]), None]),
            ),
            ("a", Seq([])),
          ]),
          Str("l1\nl2"),
        ]),
      ),
      ("n\nl", Seq([])),
      ("", Seq([])),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "z",
        Seq([
          Map([
            (
              "\u{e9}",
              Seq([Seq([Str("\u{e9}\u{4e2d}"), Int(1099511627776L)]), None]),
            ),
            ("a", Seq([])),
          ]),
          Str("l1\nl2"),
        ]),
      ),
      ("n\nl", Seq([])),
      ("", Seq([])),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("x y", None),
      ("", Seq([Str("a\\b"), Seq([Float(1.0), Str("")])])),
      (
        "a",
        Seq([
          Seq([
            Map([]),
            Map([
              (
                "k-1",
                Seq([
                  Map([
                    ("b", Str("a\"b")),
                    ("a", Map([("a", Str("it's"))])),
                    (
                      "z",
                      Seq([
                        Map([
                          ("q\"", Str("x")),
                          ("\u{e9}", Str("\u{1}")),
                          ("x y", Float(1.0e20)),
                        ]),
                      ]),
                    ),
                  ]),
                  Map([]),
                  Map([]),
                ]),
              ),
              ("x y", Str("\u{1}")),
              ("b", Seq([Map([("k-1", Str("\u{e9}\u{4e2d}"))]), Bool(false)])),
              (
                "\u{e9}",
                Seq([
                  Seq([
                    Map([]),
                    Map([("a", Str("a\\b")), ("s'", Float(1.0))]),
                    Map([
                      ("b", Float(1.0e-09)),
                      ("n\nl", Str("\u{1}")),
                      ("z", Str("a\"\n'b")),
                      ("", Str("a\\b")),
                    ]),
                  ]),
                ]),
              ),
            ]),
            Map([
              (
                "",
                Seq([
                  Seq([Bool(false), Bool(false), Float(3.14159)]),
                  Seq([Bool(false), Str("\"'")]),
                ]),
              ),
              (
                "n\nl",
                Map([
                  ("n\nl", Seq([Float(1.0e-09), Int(1099511627776L)])),
                  ("a", Str("\u{1}")),
                  ("b", Seq([Float(@double.infinity), Float(1.0e-09), Int(0L)])),
                ]),
              ),
            ]),
          ]),
          Str("\u{1}"),
          Seq([]),
        ]),
      ),
    ]),
    true,
    "\"\" = [\n    'a\\b',\n    [\n    1.0,\n    \"\",\n],\n]\na = [\n    [\n    {},\n    { k-1 = [\n    { b = 'a\"b', a = { a = \"it's\" }, z = [{ 'q\"' = \"x\", \"\u{e9}\" = \"\\u0001\", \"x y\" = 100000000000000000000.0 }] },\n    {},\n    {},\n], \"x y\" = \"\\u0001\", b = [\n    { k-1 = \"\u{e9}\u{4e2d}\" },\n    false,\n], \"\u{e9}\" = [[\n    {},\n    { a = 'a\\b', \"s'\" = 1.0 },\n    { b = 0.000000001, \"n\\nl\" = \"\\u0001\", z = '''\na\"\n'b''', \"\" = 'a\\b' },\n]] },\n    { \"\" = [\n    [\n    false,\n    false,\n    3.14159,\n],\n    [\n    false,\n    \"\\\"'\",\n],\n], \"n\\nl\" = { \"n\\nl\" = [\n    0.000000001,\n    1099511627776,\n], a = \"\\u0001\", b = [\n    inf,\n    0.000000001,\n    0,\n] } },\n],\n    \"\\u0001\",\n    [],\n]\n",
  )
  check_ser(
    Map([
      ("x y", None),
      ("", Seq([Str("a\\b"), Seq([Float(1.0), Str("")])])),
      (
        "a",
        Seq([
          Seq([
            Map([]),
            Map([
              (
                "k-1",
                Seq([
                  Map([
                    ("b", Str("a\"b")),
                    ("a", Map([("a", Str("it's"))])),
                    (
                      "z",
                      Seq([
                        Map([
                          ("q\"", Str("x")),
                          ("\u{e9}", Str("\u{1}")),
                          ("x y", Float(1.0e20)),
                        ]),
                      ]),
                    ),
                  ]),
                  Map([]),
                  Map([]),
                ]),
              ),
              ("x y", Str("\u{1}")),
              ("b", Seq([Map([("k-1", Str("\u{e9}\u{4e2d}"))]), Bool(false)])),
              (
                "\u{e9}",
                Seq([
                  Seq([
                    Map([]),
                    Map([("a", Str("a\\b")), ("s'", Float(1.0))]),
                    Map([
                      ("b", Float(1.0e-09)),
                      ("n\nl", Str("\u{1}")),
                      ("z", Str("a\"\n'b")),
                      ("", Str("a\\b")),
                    ]),
                  ]),
                ]),
              ),
            ]),
            Map([
              (
                "",
                Seq([
                  Seq([Bool(false), Bool(false), Float(3.14159)]),
                  Seq([Bool(false), Str("\"'")]),
                ]),
              ),
              (
                "n\nl",
                Map([
                  ("n\nl", Seq([Float(1.0e-09), Int(1099511627776L)])),
                  ("a", Str("\u{1}")),
                  ("b", Seq([Float(@double.infinity), Float(1.0e-09), Int(0L)])),
                ]),
              ),
            ]),
          ]),
          Str("\u{1}"),
          Seq([]),
        ]),
      ),
    ]),
    false,
    "\"\" = ['a\\b', [1.0, \"\"]]\na = [[{}, { k-1 = [{ b = 'a\"b', a = { a = \"it's\" }, z = [{ 'q\"' = \"x\", \"\u{e9}\" = \"\\u0001\", \"x y\" = 100000000000000000000.0 }] }, {}, {}], \"x y\" = \"\\u0001\", b = [{ k-1 = \"\u{e9}\u{4e2d}\" }, false], \"\u{e9}\" = [[{}, { a = 'a\\b', \"s'\" = 1.0 }, { b = 0.000000001, \"n\\nl\" = \"\\u0001\", z = '''\na\"\n'b''', \"\" = 'a\\b' }]] }, { \"\" = [[false, false, 3.14159], [false, \"\\\"'\"]], \"n\\nl\" = { \"n\\nl\" = [0.000000001, 1099511627776], a = \"\\u0001\", b = [inf, 0.000000001, 0] } }], \"\\u0001\", []]\n",
  )
  check_ser(
    Map([
      ("\u{e9}", Seq([Map([]), Seq([Float(1.0e-09), Str("\"'"), Map([])])])),
      (
        "q\"",
        Seq([
          Map([
            (
              "z",
              Seq([
                Map([
                  (
                    "k-1",
                    Seq([
                      Map([
                        ("z", Seq([Float(1.0)])),
                        ("k-1", Map([("a", None), ("q\"", Str("\t"))])),
                        (
                          "s'",
                          Map([
                            ("x y", Str("a\"b")),
                            ("\u{e9}", Str("\u{1}")),
                            ("b", Float(@double.infinity)),
                          ]),
                        ),
                        ("\u{e9}", Str("it's")),
                      ]),
                      Map([
                        (
                          "k-1",
                          Map([
                            ("s'", Float(3.14159)),
                            ("z", None),
                            ("a", Bool(true)),
                          ]),
                        ),
                        ("a", Float(1.0)),
                      ]),
                    ]),
                  ),
                  ("\u{e9}", Str("")),
                ]),
                Map([]),
                Map([]),
              ]),
            ),
            (
              "b",
              Seq([
                Seq([
                  Map([
                    (
                      "q\"",
                      Map([
                        ("x y", Float(@double.not_a_number)),
                        ("n\nl", Float(-0.0)),
                      ]),
                    ),
                    ("s'", Str("l1\nl2")),
                  ]),
                ]),
              ]),
            ),
            (
              "x y",
              Map([
                (
                  "n\nl",
                  Seq([
                    Map([
                      ("x y", Seq([Str("a\\b")])),
                      ("b", Str("a\"\n'b")),
                      ("s'", Map([("a", Str("a\\b")), ("\u{e9}", Int(-7L))])),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
          Map([
            ("k-1", Seq([Str("it's"), Seq([Float(0.25)]), Str("x")])),
            ("s'", Int(-7L)),
          ]),
        ]),
      ),
      (
        "a",
        Seq([
          Int(0L),
          Seq([
            Map([
              (
                "n\nl",
                Seq([
                  Map([
                    ("z", Bool(true)),
                    ("b", Seq([])),
                    (
                      "s'",
                      Map([
                        ("k-1", Str("x")),
                        ("", Int(0L)),
                        ("n\nl", Int(1099511627776L)),
                      ]),
                    ),
                    (
                      "\u{e9}",
                      Map([
                        ("k-1", Str("it's")),
                        ("\u{e9}", Str("\t")),
                        ("", Str("x")),
                      ]),
                    ),
                  ]),
                ]),
              ),
              ("a", Int(0L)),
            ]),
            Map([("b", Str("a\"\n'b")), ("x y", Str("a\"\n'b"))]),
            Map([
              (
                "b",
                Seq([
                  Seq([]),
                  Seq([
                    Str("l1\nl2"),
                    Str("l1\nl2"),
                    Float(@double.not_a_number),
                  ]),
                ]),
              ),
              (
                "s'",
                Seq([
                  Float(1.0e-09),
                  Seq([Map([]), Map([]), Map([("s'", None)])]),
                  Float(@double.not_a_number),
                ]),
              ),
            ]),
          ]),
          Seq([
            Map([
              ("a", Map([])),
              (
                "n\nl",
                Seq([
                  Map([
                    ("k-1", Seq([Str("\u{1}"), Float(1.0), Str("x")])),
                    ("q\"", Seq([])),
                    (
                      "z",
                      Seq([
                        Map([
                          ("b", Float(@double.not_a_number)),
                          ("n\nl", Float(0.25)),
                          ("x y", Int(-7L)),
                          ("\u{e9}", Str("a\"b")),
                        ]),
                        Map([]),
                        Map([("z", Str("x'"))]),
                      ]),
                    ),
                    ("s'", Float(1.0e20)),
                  ]),
                  Map([]),
                ]),
              ),
            ]),
            Map([
              ("b", Str("\u{1}")),
              (
                "k-1",
                Seq([
                  Seq([Str("it's"), Float(1.0)]),
                  Map([
                    ("n\nl", Str("a\\b")),
                    ("k-1", Float(1.0)),
                    ("a", Int(-7L)),
                  ]),
                ]),
              ),
              (
                "s'",
                Seq([
                  Map([]),
                  Map([
                    (
                      "n\nl",
                      Seq([
                        Map([
                          ("q\"", Int(1099511627776L)),
                          ("a", Str("\u{e9}\u{4e2d}")),
                        ]),
                      ]),
                    ),
                    ("k-1", Str("\"'")),
                    (
                      "x y",
                      Map([
                        ("a", Str("x'")),
                        ("q\"", Str("'''")),
                        ("k-1", Float(1.0)),
                        ("x y", Float(0.25)),
                      ]),
                    ),
                    (
                      "z",
                      Seq([
                        Str("\u{e9}\u{4e2d}"),
                        Int(1099511627776L),
                        Str("a\\b"),
                      ]),
                    ),
                  ]),
                  Map([("s'", Int(1099511627776L))]),
                ]),
              ),
              ("a", Seq([Map([])])),
            ]),
            Map([]),
          ]),
        ]),
      ),
    ]),
    true,
    "\"\u{e9}\" = [\n    {},\n    [\n    0.000000001,\n    \"\\\"'\",\n    {},\n],\n]\na = [\n    0,\n    [\n    { \"n\\nl\" = [{ z = true, b = [], \"s'\" = { k-1 = \"x\", \"\" = 0, \"n\\nl\" = 1099511627776 }, \"\u{e9}\" = { k-1 = \"it's\", \"\u{e9}\" = \"\\t\", \"\" = \"x\" } }], a = 0 },\n    { b = '''\na\"\n'b''', \"x y\" = '''\na\"\n'b''' },\n    { b = [\n    [],\n    [\n    \"\"\"\nl1\nl2\"\"\",\n    \"\"\"\nl1\nl2\"\"\",\n    nan,\n],\n], \"s'\" = [\n    0.000000001,\n    [\n    {},\n    {},\n    {},\n],\n    nan,\n] },\n],\n    [\n    { a = {}, \"n\\nl\" = [\n    { k-1 = [\n    \"\\u0001\",\n    1.0,\n    \"x\",\n], 'q\"' = [], z = [\n    { b = nan, \"n\\nl\" = 0.25, \"x y\" = -7, \"\u{e9}\" = 'a\"b' },\n    {},\n    { z = \"x'\" },\n], \"s'\" = 100000000000000000000.0 },\n    {},\n] },\n    { b = \"\\u0001\", k-1 = [\n    [\n    \"it's\",\n    1.0,\n],\n    { \"n\\nl\" = 'a\\b', k-1 = 1.0, a = -7 },\n], \"s'\" = [\n    {},\n    { \"n\\nl\" = [{ 'q\"' = 1099511627776, a = \"\u{e9}\u{4e2d}\" }], k-1 = \"\\\"'\", \"x y\" = { a = \"x'\", 'q\"' = \"'''\", k-1 = 1.0, \"x y\" = 0.25 }, z = [\n    \"\u{e9}\u{4e2d}\",\n    1099511627776,\n    'a\\b',\n] },\n    { \"s'\" = 1099511627776 },\n], a = [{}] },\n    {},\n],\n]\n\n[['q\"']]\nb = [[{ 'q\"' = { \"x y\" = nan, \"n\\nl\" = -0.0 }, \"s'\" = \"\"\"\nl1\nl2\"\"\" }]]\n\n[['q\"'.z]]\n\"\u{e9}\" = \"\"\n\n[['q\"'.z.k-1]]\nz = [1.0]\n\"\u{e9}\" = \"it's\"\n\n['q\"'.z.k-1.k-1]\n'q\"' = \"\\t\"\n\n['q\"'.z.k-1.\"s'\"]\n\"x y\" = 'a\"b'\n\"\u{e9}\" = \"\\u0001\"\nb = inf\n\n[['q\"'.z.k-1]]\na = 1.0\n\n['q\"'.z.k-1.k-1]\n\"s'\" = 3.14159\na = true\n\n[['q\"'.z]]\n\n[['q\"'.z]]\n\n[['q\"'.\"x y\".\"n\\nl\"]]\n\"x y\" = ['a\\b']\nb = '''\na\"\n'b'''\n\n['q\"'.\"x y\".\"n\\nl\".\"s'\"]\na = 'a\\b'\n\"\u{e9}\" = -7\n\n[['q\"']]\nk-1 = [\n    \"it's\",\n    [0.25],\n    \"x\",\n]\n\"s'\" = -7\n",
  )
  check_ser(
    Map([
      ("\u{e9}", Seq([Map([]), Seq([Float(1.0e-09), Str("\"'"), Map([])])])),
      (
        "q\"",
        Seq([
          Map([
            (
              "z",
              Seq([
                Map([
                  (
                    "k-1",
                    Seq([
                      Map([
                        ("z", Seq([Float(1.0)])),
                        ("k-1", Map([("a", None), ("q\"", Str("\t"))])),
                        (
                          "s'",
                          Map([
                            ("x y", Str("a\"b")),
                            ("\u{e9}", Str("\u{1}")),
                            ("b", Float(@double.infinity)),
                          ]),
                        ),
                        ("\u{e9}", Str("it's")),
                      ]),
                      Map([
                        (
                          "k-1",
                          Map([
                            ("s'", Float(3.14159)),
                            ("z", None),
                            ("a", Bool(true)),
                          ]),
                        ),
                        ("a", Float(1.0)),
                      ]),
                    ]),
                  ),
                  ("\u{e9}", Str("")),
                ]),
                Map([]),
                Map([]),
              ]),
            ),
            (
              "b",
              Seq([
                Seq([
                  Map([
                    (
                      "q\"",
                      Map([
                        ("x y", Float(@double.not_a_number)),
                        ("n\nl", Float(-0.0)),
                      ]),
                    ),
                    ("s'", Str("l1\nl2")),
                  ]),
                ]),
              ]),
            ),
            (
              "x y",
              Map([
                (
                  "n\nl",
                  Seq([
                    Map([
                      ("x y", Seq([Str("a\\b")])),
                      ("b", Str("a\"\n'b")),
                      ("s'", Map([("a", Str("a\\b")), ("\u{e9}", Int(-7L))])),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
          Map([
            ("k-1", Seq([Str("it's"), Seq([Float(0.25)]), Str("x")])),
            ("s'", Int(-7L)),
          ]),
        ]),
      ),
      (
        "a",
        Seq([
          Int(0L),
          Seq([
            Map([
              (
                "n\nl",
                Seq([
                  Map([
                    ("z", Bool(true)),
                    ("b", Seq([])),
                    (
                      "s'",
                      Map([
                        ("k-1", Str("x")),
                        ("", Int(0L)),
                        ("n\nl", Int(1099511627776L)),
                      ]),
                    ),
                    (
                      "\u{e9}",
                      Map([
                        ("k-1", Str("it's")),
                        ("\u{e9}", Str("\t")),
                        ("", Str("x")),
                      ]),
                    ),
                  ]),
                ]),
              ),
              ("a", Int(0L)),
            ]),
            Map([("b", Str("a\"\n'b")), ("x y", Str("a\"\n'b"))]),
            Map([
              (
                "b",
                Seq([
                  Seq([]),
                  Seq([
                    Str("l1\nl2"),
                    Str("l1\nl2"),
                    Float(@double.not_a_number),
                  ]),
                ]),
              ),
              (
                "s'",
                Seq([
                  Float(1.0e-09),
                  Seq([Map([]), Map([]), Map([("s'", None)])]),
                  Float(@double.not_a_number),
                ]),
              ),
            ]),
          ]),
          Seq([
            Map([
              ("a", Map([])),
              (
                "n\nl",
                Seq([
                  Map([
                    ("k-1", Seq([Str("\u{1}"), Float(1.0), Str("x")])),
                    ("q\"", Seq([])),
                    (
                      "z",
                      Seq([
                        Map([
                          ("b", Float(@double.not_a_number)),
                          ("n\nl", Float(0.25)),
                          ("x y", Int(-7L)),
                          ("\u{e9}", Str("a\"b")),
                        ]),
                        Map([]),
                        Map([("z", Str("x'"))]),
                      ]),
                    ),
                    ("s'", Float(1.0e20)),
                  ]),
                  Map([]),
                ]),
              ),
            ]),
            Map([
              ("b", Str("\u{1}")),
              (
                "k-1",
                Seq([
                  Seq([Str("it's"), Float(1.0)]),
                  Map([
                    ("n\nl", Str("a\\b")),
                    ("k-1", Float(1.0)),
                    ("a", Int(-7L)),
                  ]),
                ]),
              ),
              (
                "s'",
                Seq([
                  Map([]),
                  Map([
                    (
                      "n\nl",
                      Seq([
                        Map([
                          ("q\"", Int(1099511627776L)),
                          ("a", Str("\u{e9}\u{4e2d}")),
                        ]),
                      ]),
                    ),
                    ("k-1", Str("\"'")),
                    (
                      "x y",
                      Map([
                        ("a", Str("x'")),
                        ("q\"", Str("'''")),
                        ("k-1", Float(1.0)),
                        ("x y", Float(0.25)),
                      ]),
                    ),
                    (
                      "z",
                      Seq([
                        Str("\u{e9}\u{4e2d}"),
                        Int(1099511627776L),
                        Str("a\\b"),
                      ]),
                    ),
                  ]),
                  Map([("s'", Int(1099511627776L))]),
                ]),
              ),
              ("a", Seq([Map([])])),
            ]),
            Map([]),
          ]),
        ]),
      ),
    ]),
    false,
    "\"\u{e9}\" = [{}, [0.000000001, \"\\\"'\", {}]]\na = [0, [{ \"n\\nl\" = [{ z = true, b = [], \"s'\" = { k-1 = \"x\", \"\" = 0, \"n\\nl\" = 1099511627776 }, \"\u{e9}\" = { k-1 = \"it's\", \"\u{e9}\" = \"\\t\", \"\" = \"x\" } }], a = 0 }, { b = '''\na\"\n'b''', \"x y\" = '''\na\"\n'b''' }, { b = [[], [\"\"\"\nl1\nl2\"\"\", \"\"\"\nl1\nl2\"\"\", nan]], \"s'\" = [0.000000001, [{}, {}, {}], nan] }], [{ a = {}, \"n\\nl\" = [{ k-1 = [\"\\u0001\", 1.0, \"x\"], 'q\"' = [], z = [{ b = nan, \"n\\nl\" = 0.25, \"x y\" = -7, \"\u{e9}\" = 'a\"b' }, {}, { z = \"x'\" }], \"s'\" = 100000000000000000000.0 }, {}] }, { b = \"\\u0001\", k-1 = [[\"it's\", 1.0], { \"n\\nl\" = 'a\\b', k-1 = 1.0, a = -7 }], \"s'\" = [{}, { \"n\\nl\" = [{ 'q\"' = 1099511627776, a = \"\u{e9}\u{4e2d}\" }], k-1 = \"\\\"'\", \"x y\" = { a = \"x'\", 'q\"' = \"'''\", k-1 = 1.0, \"x y\" = 0.25 }, z = [\"\u{e9}\u{4e2d}\", 1099511627776, 'a\\b'] }, { \"s'\" = 1099511627776 }], a = [{}] }, {}]]\n\n[['q\"']]\nb = [[{ 'q\"' = { \"x y\" = nan, \"n\\nl\" = -0.0 }, \"s'\" = \"\"\"\nl1\nl2\"\"\" }]]\n\n[['q\"'.z]]\n\"\u{e9}\" = \"\"\n\n[['q\"'.z.k-1]]\nz = [1.0]\n\"\u{e9}\" = \"it's\"\n\n['q\"'.z.k-1.k-1]\n'q\"' = \"\\t\"\n\n['q\"'.z.k-1.\"s'\"]\n\"x y\" = 'a\"b'\n\"\u{e9}\" = \"\\u0001\"\nb = inf\n\n[['q\"'.z.k-1]]\na = 1.0\n\n['q\"'.z.k-1.k-1]\n\"s'\" = 3.14159\na = true\n\n[['q\"'.z]]\n\n[['q\"'.z]]\n\n[['q\"'.\"x y\".\"n\\nl\"]]\n\"x y\" = ['a\\b']\nb = '''\na\"\n'b'''\n\n['q\"'.\"x y\".\"n\\nl\".\"s'\"]\na = 'a\\b'\n\"\u{e9}\" = -7\n\n[['q\"']]\nk-1 = [\"it's\", [0.25], \"x\"]\n\"s'\" = -7\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Seq([
            Map([("", Float(@double.not_a_number)), ("s'", Bool(false))]),
            Map([("q\"", Map([("x y", Seq([Str("\t")]))])), ("", Int(0L))]),
          ]),
          Float(0.25),
          Float(@double.infinity),
        ]),
      ),
      ("\u{e9}", Str("\u{1}")),
      ("b", Float(1.0)),
      ("", Str("'''")),
    ]),
    true,
    "a = [\n    [\n    { \"\" = nan, \"s'\" = false },\n    { 'q\"' = { \"x y\" = [\"\\t\"] }, \"\" = 0 },\n],\n    0.25,\n    inf,\n]\n\"\u{e9}\" = \"\\u0001\"\nb = 1.0\n\"\" = \"'''\"\n",
  )
  check_ser(
    Map([
      (
        "a",
        Seq([
          Seq([
            Map([("", Float(@double.not_a_number)), ("s'", Bool(false))]),
            Map([("q\"", Map([("x y", Seq([Str("\t")]))])), ("", Int(0L))]),
          ]),
          Float(0.25),
          Float(@double.infinity),
        ]),
      ),
      ("\u{e9}", Str("\u{1}")),
      ("b", Float(1.0)),
      ("", Str("'''")),
    ]),
    false,
    "a = [[{ \"\" = nan, \"s'\" = false }, { 'q\"' = { \"x y\" = [\"\\t\"] }, \"\" = 0 }], 0.25, inf]\n\"\u{e9}\" = \"\\u0001\"\nb = 1.0\n\"\" = \"'''\"\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      (
        "z",
        Map([
          ("x y", Seq([])),
          ("s'", Seq([Str("\u{e9}\u{4e2d}"), Seq([])])),
          ("k-1", Str("\"'")),
        ]),
      ),
      ("a", Str("\u{e9}\u{4e2d}")),
    ]),
    true,
    "a = \"\u{e9}\u{4e2d}\"\n\n[z]\n\"x y\" = []\n\"s'\" = [\n    \"\u{e9}\u{4e2d}\",\n    [],\n]\nk-1 = \"\\\"'\"\n",
  )
  check_ser(
    Map([
      (
        "z",
        Map([
          ("x y", Seq([])),
          ("s'", Seq([Str("\u{e9}\u{4e2d}"), Seq([])])),
          ("k-1", Str("\"'")),
        ]),
      ),
      ("a", Str("\u{e9}\u{4e2d}")),
    ]),
    false,
    "a = \"\u{e9}\u{4e2d}\"\n\n[z]\n\"x y\" = []\n\"s'\" = [\"\u{e9}\u{4e2d}\", []]\nk-1 = \"\\\"'\"\n",
  )
  check_ser(
    Map([
      ("", Seq([])),
      (
        "q\"",
        Map([
          ("n\nl", Str("l1\nl2")),
          ("x y", Int(1099511627776L)),
          (
            "\u{e9}",
            Map([
              ("\u{e9}", Seq([Str(""), Str("a\"\n'b")])),
              ("b", Seq([Seq([Float(-0.0)])])),
            ]),
          ),
        ]),
      ),
      ("s'", Seq([])),
    ]),
    true,
    "\"\" = []\n\"s'\" = []\n\n['q\"']\n\"n\\nl\" = \"\"\"\nl1\nl2\"\"\"\n\"x y\" = 1099511627776\n\n['q\"'.\"\u{e9}\"]\n\"\u{e9}\" = [\n    \"\",\n    '''\na\"\n'b''',\n]\nb = [[-0.0]]\n",
  )
  check_ser(
    Map([
      ("", Seq([])),
      (
        "q\"",
        Map([
          ("n\nl", Str("l1\nl2")),
          ("x y", Int(1099511627776L)),
          (
            "\u{e9}",
            Map([
              ("\u{e9}", Seq([Str(""), Str("a\"\n'b")])),
              ("b", Seq([Seq([Float(-0.0)])])),
            ]),
          ),
        ]),
      ),
      ("s'", Seq([])),
    ]),
    false,
    "\"\" = []\n\"s'\" = []\n\n['q\"']\n\"n\\nl\" = \"\"\"\nl1\nl2\"\"\"\n\"x y\" = 1099511627776\n\n['q\"'.\"\u{e9}\"]\n\"\u{e9}\" = [\"\", '''\na\"\n'b''']\nb = [[-0.0]]\n",
  )
  check_ser(
    Map([
      (
        "\u{e9}",
        Seq([
          Str(""),
          Seq([
            Seq([Str(""), Str("'''")]),
            Map([("s'", Int(1099511627776L))]),
            Seq([Map([]), Str("l1\nl2"), Seq([Str("\u{1}"), Str("x'")])]),
          ]),
          Seq([]),
        ]),
      ),
      ("q\"", Str("a\"b")),
      (
        "a",
        Map([
          (
            "x y",
            Seq([
              Seq([
                Seq([
                  Map([
                    ("k-1", Str("x")),
                    ("n\nl", Float(3.14159)),
                    ("z", Str("\t")),
                    ("q\"", Str("\t")),
                  ]),
                  Map([("\u{e9}", Str("\t"))]),
                ]),
                Str("x"),
              ]),
              Map([]),
            ]),
          ),
          ("k-1", Str("a\"\n'b")),
          ("n\nl", Float(1.0)),
        ]),
      ),
    ]),
    true,
    "\"\u{e9}\" = [\n    \"\",\n    [\n    [\n    \"\",\n    \"'''\",\n],\n    { \"s'\" = 1099511627776 },\n    [\n    {},\n    \"\"\"\nl1\nl2\"\"\",\n    [\n    \"\\u0001\",\n    \"x'\",\n],\n],\n],\n    [],\n]\n'q\"' = 'a\"b'\n\n[a]\n\"x y\" = [\n    [\n    [\n    { k-1 = \"x\", \"n\\nl\" = 3.14159, z = \"\\t\", 'q\"' = \"\\t\" },\n    { \"\u{e9}\" = \"\\t\" },\n],\n    \"x\",\n],\n    {},\n]\nk-1 = '''\na\"\n'b'''\n\"n\\nl\" = 1.0\n",
  )
  check_ser(
    Map([
      (
        "\u{e9}",
        Seq([
          Str(""),
          Seq([
            Seq([Str(""), Str("'''")]),
            Map([("s'", Int(1099511627776L))]),
            Seq([Map([]), Str("l1\nl2"), Seq([Str("\u{1}"), Str("x'")])]),
          ]),
          Seq([]),
        ]),
      ),
      ("q\"", Str("a\"b")),
      (
        "a",
        Map([
          (
            "x y",
            Seq([
              Seq([
                Seq([
                  Map([
                    ("k-1", Str("x")),
                    ("n\nl", Float(3.14159)),
                    ("z", Str("\t")),
                    ("q\"", Str("\t")),
                  ]),
                  Map([("\u{e9}", Str("\t"))]),
                ]),
                Str("x"),
              ]),
              Map([]),
            ]),
          ),
          ("k-1", Str("a\"\n'b")),
          ("n\nl", Float(1.0)),
        ]),
      ),
    ]),
    false,
    "\"\u{e9}\" = [\"\", [[\"\", \"'''\"], { \"s'\" = 1099511627776 }, [{}, \"\"\"\nl1\nl2\"\"\", [\"\\u0001\", \"x'\"]]], []]\n'q\"' = 'a\"b'\n\n[a]\n\"x y\" = [[[{ k-1 = \"x\", \"n\\nl\" = 3.14159, z = \"\\t\", 'q\"' = \"\\t\" }, { \"\u{e9}\" = \"\\t\" }], \"x\"], {}]\nk-1 = '''\na\"\n'b'''\n\"n\\nl\" = 1.0\n",
  )
  check_ser(
    Map([("n\nl", Int(1099511627776L)), ("", Str("\"'")), ("k-1", Map([]))]),
    true,
    "\"n\\nl\" = 1099511627776\n\"\" = \"\\\"'\"\n\n[k-1]\n",
  )
  check_ser(
    Map([("n\nl", Int(1099511627776L)), ("", Str("\"'")), ("k-1", Map([]))]),
    false,
    "\"n\\nl\" = 1099511627776\n\"\" = \"\\\"'\"\n\n[k-1]\n",
  )
  check_ser(
    Map([
      ("n\nl", Int(1099511627776L)),
      ("\u{e9}", Int(1099511627776L)),
      ("q\"", Map([])),
      ("a", Seq([Map([]), Bool(false)])),
    ]),
    true,
    "\"n\\nl\" = 1099511627776\n\"\u{e9}\" = 1099511627776\na = [\n    {},\n    false,\n]\n\n['q\"']\n",
  )
  check_ser(
    Map([
      ("n\nl", Int(1099511627776L)),
      ("\u{e9}", Int(1099511627776L)),
      ("q\"", Map([])),
      ("a", Seq([Map([]), Bool(false)])),
    ]),
    false,
    "\"n\\nl\" = 1099511627776\n\"\u{e9}\" = 1099511627776\na = [{}, false]\n\n['q\"']\n",
  )
  check_ser(
    Map([
      ("s'", Int(1099511627776L)),
      ("", Map([])),
      ("q\"", Map([("z", Str("\t"))])),
    ]),
    true,
    "\"s'\" = 1099511627776\n\n[\"\"]\n\n['q\"']\nz = \"\\t\"\n",
  )
  check_ser(
    Map([
      ("s'", Int(1099511627776L)),
      ("", Map([])),
      ("q\"", Map([("z", Str("\t"))])),
    ]),
    false,
    "\"s'\" = 1099511627776\n\n[\"\"]\n\n['q\"']\nz = \"\\t\"\n",
  )
  check_ser(
    Map([("x y", Seq([])), ("a", Float(1.0))]),
    true,
    "\"x y\" = []\na = 1.0\n",
  )
  check_ser(
    Map([("x y", Seq([])), ("a", Float(1.0))]),
    false,
    "\"x y\" = []\na = 1.0\n",
  )
  check_ser(
    Map([
      (
        "x y",
        Seq([
          Map([
            (
              "q\"",
              Seq([
                Map([]),
                Map([
                  ("b", Seq([None, Str("\t"), Str("a\"b")])),
                  ("k-1", Int(0L)),
                ]),
              ]),
            ),
            ("x y", Str("l1\nl2")),
          ]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "x y",
        Seq([
          Map([
            (
              "q\"",
              Seq([
                Map([]),
                Map([
                  ("b", Seq([None, Str("\t"), Str("a\"b")])),
                  ("k-1", Int(0L)),
                ]),
              ]),
            ),
            ("x y", Str("l1\nl2")),
          ]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(Map([("b", Seq([]))]), true, "b = []\n")
  check_ser(Map([("b", Seq([]))]), false, "b = []\n")
  check_ser(
    Map([("\u{e9}", Seq([Float(3.14159)]))]),
    true,
    "\"\u{e9}\" = [3.14159]\n",
  )
  check_ser(
    Map([("\u{e9}", Seq([Float(3.14159)]))]),
    false,
    "\"\u{e9}\" = [3.14159]\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([
      (
        "b",
        Map([
          ("\u{e9}", Seq([Seq([Seq([Str("x'"), Str("it's"), Str("a\"b")])])])),
          (
            "b",
            Map([
              (
                "x y",
                Seq([
                  Map([
                    (
                      "",
                      Seq([
                        Map([("q\"", Bool(true))]),
                        Map([("\u{e9}", Str("\u{e9}\u{4e2d}"))]),
                        Map([
                          ("", Float(@double.not_a_number)),
                          ("k-1", Float(3.14159)),
                          ("\u{e9}", Float(@double.infinity)),
                        ]),
                      ]),
                    ),
                    (
                      "z",
                      Seq([
                        Map([
                          ("a", Int(0L)),
                          ("\u{e9}", Float(1.0)),
                          ("z", Int(1099511627776L)),
                        ]),
                        Map([
                          ("z", Str("\"'")),
                          ("", Int(1099511627776L)),
                          ("q\"", Str("\"'")),
                          ("\u{e9}", None),
                        ]),
                        Map([("k-1", Str("x'"))]),
                      ]),
                    ),
                    (
                      "s'",
                      Map([
                        ("n\nl", Float(1.0e-09)),
                        ("a", Str("")),
                        ("", Bool(false)),
                      ]),
                    ),
                  ]),
                  Map([
                    ("x y", Seq([])),
                    ("a", Seq([Str("l1\nl2")])),
                    ("s'", Seq([Map([("b", Str("\u{e9}\u{4e2d}"))])])),
                    ("", Seq([])),
                  ]),
                ]),
              ),
              (
                "\u{e9}",
                Seq([
                  Float(1.0),
                  Seq([Map([])]),
                  Map([
                    ("z", Str("x")),
                    ("", Str("it's")),
                    ("b", Int(1099511627776L)),
                  ]),
                ]),
              ),
            ]),
          ),
          (
            "k-1",
            Seq([
              Map([("a", Seq([])), ("s'", Str("a\\b"))]),
              Seq([Seq([Float(0.25), Str("'''"), Int(1099511627776L)])]),
              Str("\u{1}"),
            ]),
          ),
        ]),
      ),
      ("z", Float(3.14159)),
      (
        "",
        Map([
          (
            "x y",
            Map([
              ("k-1", Seq([Float(1.0), Seq([Map([]), Map([])])])),
              ("x y", Float(1.0e20)),
              ("a", Float(@double.not_a_number)),
            ]),
          ),
          ("a", Bool(true)),
          ("k-1", Seq([Str("x"), Str("a\\b")])),
        ]),
      ),
    ]),
    true,
    "z = 3.14159\n\n[b]\n\"\u{e9}\" = [[[\n    \"x'\",\n    \"it's\",\n    'a\"b',\n]]]\nk-1 = [\n    { a = [], \"s'\" = 'a\\b' },\n    [[\n    0.25,\n    \"'''\",\n    1099511627776,\n]],\n    \"\\u0001\",\n]\n\n[b.b]\n\"\u{e9}\" = [\n    1.0,\n    [{}],\n    { z = \"x\", \"\" = \"it's\", b = 1099511627776 },\n]\n\n[[b.b.\"x y\"]]\n\n[[b.b.\"x y\".\"\"]]\n'q\"' = true\n\n[[b.b.\"x y\".\"\"]]\n\"\u{e9}\" = \"\u{e9}\u{4e2d}\"\n\n[[b.b.\"x y\".\"\"]]\n\"\" = nan\nk-1 = 3.14159\n\"\u{e9}\" = inf\n\n[[b.b.\"x y\".z]]\na = 0\n\"\u{e9}\" = 1.0\nz = 1099511627776\n\n[[b.b.\"x y\".z]]\nz = \"\\\"'\"\n\"\" = 1099511627776\n'q\"' = \"\\\"'\"\n\n[[b.b.\"x y\".z]]\nk-1 = \"x'\"\n\n[b.b.\"x y\".\"s'\"]\n\"n\\nl\" = 0.000000001\na = \"\"\n\"\" = false\n\n[[b.b.\"x y\"]]\n\"x y\" = []\na = [\"\"\"\nl1\nl2\"\"\"]\n\"\" = []\n\n[[b.b.\"x y\".\"s'\"]]\nb = \"\u{e9}\u{4e2d}\"\n\n[\"\"]\na = true\nk-1 = [\n    \"x\",\n    'a\\b',\n]\n\n[\"\".\"x y\"]\nk-1 = [\n    1.0,\n    [\n    {},\n    {},\n],\n]\n\"x y\" = 100000000000000000000.0\na = nan\n",
  )
  check_ser(
    Map([
      (
        "b",
        Map([
          ("\u{e9}", Seq([Seq([Seq([Str("x'"), Str("it's"), Str("a\"b")])])])),
          (
            "b",
            Map([
              (
                "x y",
                Seq([
                  Map([
                    (
                      "",
                      Seq([
                        Map([("q\"", Bool(true))]),
                        Map([("\u{e9}", Str("\u{e9}\u{4e2d}"))]),
                        Map([
                          ("", Float(@double.not_a_number)),
                          ("k-1", Float(3.14159)),
                          ("\u{e9}", Float(@double.infinity)),
                        ]),
                      ]),
                    ),
                    (
                      "z",
                      Seq([
                        Map([
                          ("a", Int(0L)),
                          ("\u{e9}", Float(1.0)),
                          ("z", Int(1099511627776L)),
                        ]),
                        Map([
                          ("z", Str("\"'")),
                          ("", Int(1099511627776L)),
                          ("q\"", Str("\"'")),
                          ("\u{e9}", None),
                        ]),
                        Map([("k-1", Str("x'"))]),
                      ]),
                    ),
                    (
                      "s'",
                      Map([
                        ("n\nl", Float(1.0e-09)),
                        ("a", Str("")),
                        ("", Bool(false)),
                      ]),
                    ),
                  ]),
                  Map([
                    ("x y", Seq([])),
                    ("a", Seq([Str("l1\nl2")])),
                    ("s'", Seq([Map([("b", Str("\u{e9}\u{4e2d}"))])])),
                    ("", Seq([])),
                  ]),
                ]),
              ),
              (
                "\u{e9}",
                Seq([
                  Float(1.0),
                  Seq([Map([])]),
                  Map([
                    ("z", Str("x")),
                    ("", Str("it's")),
                    ("b", Int(1099511627776L)),
                  ]),
                ]),
              ),
            ]),
          ),
          (
            "k-1",
            Seq([
              Map([("a", Seq([])), ("s'", Str("a\\b"))]),
              Seq([Seq([Float(0.25), Str("'''"), Int(1099511627776L)])]),
              Str("\u{1}"),
            ]),
          ),
        ]),
      ),
      ("z", Float(3.14159)),
      (
        "",
        Map([
          (
            "x y",
            Map([
              ("k-1", Seq([Float(1.0), Seq([Map([]), Map([])])])),
              ("x y", Float(1.0e20)),
              ("a", Float(@double.not_a_number)),
            ]),
          ),
          ("a", Bool(true)),
          ("k-1", Seq([Str("x"), Str("a\\b")])),
        ]),
      ),
    ]),
    false,
    "z = 3.14159\n\n[b]\n\"\u{e9}\" = [[[\"x'\", \"it's\", 'a\"b']]]\nk-1 = [{ a = [], \"s'\" = 'a\\b' }, [[0.25, \"'''\", 1099511627776]], \"\\u0001\"]\n\n[b.b]\n\"\u{e9}\" = [1.0, [{}], { z = \"x\", \"\" = \"it's\", b = 1099511627776 }]\n\n[[b.b.\"x y\"]]\n\n[[b.b.\"x y\".\"\"]]\n'q\"' = true\n\n[[b.b.\"x y\".\"\"]]\n\"\u{e9}\" = \"\u{e9}\u{4e2d}\"\n\n[[b.b.\"x y\".\"\"]]\n\"\" = nan\nk-1 = 3.14159\n\"\u{e9}\" = inf\n\n[[b.b.\"x y\".z]]\na = 0\n\"\u{e9}\" = 1.0\nz = 1099511627776\n\n[[b.b.\"x y\".z]]\nz = \"\\\"'\"\n\"\" = 1099511627776\n'q\"' = \"\\\"'\"\n\n[[b.b.\"x y\".z]]\nk-1 = \"x'\"\n\n[b.b.\"x y\".\"s'\"]\n\"n\\nl\" = 0.000000001\na = \"\"\n\"\" = false\n\n[[b.b.\"x y\"]]\n\"x y\" = []\na = [\"\"\"\nl1\nl2\"\"\"]\n\"\" = []\n\n[[b.b.\"x y\".\"s'\"]]\nb = \"\u{e9}\u{4e2d}\"\n\n[\"\"]\na = true\nk-1 = [\"x\", 'a\\b']\n\n[\"\".\"x y\"]\nk-1 = [1.0, [{}, {}]]\n\"x y\" = 100000000000000000000.0\na = nan\n",
  )
  check_ser(
    Map([
      (
        "z",
        Map([
          (
            "q\"",
            Map([
              (
                "z",
                Seq([
                  Map([
                    (
                      "k-1",
                      Seq([
                        Map([
                          ("n\nl", Int(1099511627776L)),
                          ("x y", Str("\u{e9}\u{4e2d}")),
                          ("k-1", Str("a\"\n'b")),
                        ]),
                        Map([("z", Str("\u{1}"))]),
                      ]),
                    ),
                    ("n\nl", Str("a\"b")),
                    ("x y", Bool(true)),
                  ]),
                ]),
              ),
              ("n\nl", Float(-0.0)),
              ("q\"", Seq([Map([("b", Bool(true))]), Bool(true)])),
              (
                "b",
                Seq([
                  Seq([
                    Map([("x y", Float(1.0))]),
                    Map([("\u{e9}", Str("a\"\n'b"))]),
                  ]),
                  Seq([Map([]), Map([])]),
                ]),
              ),
            ]),
          ),
          ("x y", Map([("s'", Float(1.0))])),
          (
            "n\nl",
            Seq([
              Map([
                (
                  "z",
                  Seq([
                    Map([("\u{e9}", Str("a\"b"))]),
                    Map([
                      ("", Bool(false)),
                      ("q\"", Str("")),
                      ("z", Float(1.0)),
                      ("\u{e9}", None),
                    ]),
                  ]),
                ),
                ("a", Str("it's")),
              ]),
              Seq([Seq([Float(@double.not_a_number)]), Seq([Float(-0.0)])]),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "[z]\n\"n\\nl\" = [\n    { z = [\n    { \"\u{e9}\" = 'a\"b' },\n    { \"\" = false, 'q\"' = \"\", z = 1.0 },\n], a = \"it's\" },\n    [\n    [nan],\n    [-0.0],\n],\n]\n\n[z.'q\"']\n\"n\\nl\" = -0.0\n'q\"' = [\n    { b = true },\n    true,\n]\nb = [\n    [\n    { \"x y\" = 1.0 },\n    { \"\u{e9}\" = '''\na\"\n'b''' },\n],\n    [\n    {},\n    {},\n],\n]\n\n[[z.'q\"'.z]]\n\"n\\nl\" = 'a\"b'\n\"x y\" = true\n\n[[z.'q\"'.z.k-1]]\n\"n\\nl\" = 1099511627776\n\"x y\" = \"\u{e9}\u{4e2d}\"\nk-1 = '''\na\"\n'b'''\n\n[[z.'q\"'.z.k-1]]\nz = \"\\u0001\"\n\n[z.\"x y\"]\n\"s'\" = 1.0\n",
  )
  check_ser(
    Map([
      (
        "z",
        Map([
          (
            "q\"",
            Map([
              (
                "z",
                Seq([
                  Map([
                    (
                      "k-1",
                      Seq([
                        Map([
                          ("n\nl", Int(1099511627776L)),
                          ("x y", Str("\u{e9}\u{4e2d}")),
                          ("k-1", Str("a\"\n'b")),
                        ]),
                        Map([("z", Str("\u{1}"))]),
                      ]),
                    ),
                    ("n\nl", Str("a\"b")),
                    ("x y", Bool(true)),
                  ]),
                ]),
              ),
              ("n\nl", Float(-0.0)),
              ("q\"", Seq([Map([("b", Bool(true))]), Bool(true)])),
              (
                "b",
                Seq([
                  Seq([
                    Map([("x y", Float(1.0))]),
                    Map([("\u{e9}", Str("a\"\n'b"))]),
                  ]),
                  Seq([Map([]), Map([])]),
                ]),
              ),
            ]),
          ),
          ("x y", Map([("s'", Float(1.0))])),
          (
            "n\nl",
            Seq([
              Map([
                (
                  "z",
                  Seq([
                    Map([("\u{e9}", Str("a\"b"))]),
                    Map([
                      ("", Bool(false)),
                      ("q\"", Str("")),
                      ("z", Float(1.0)),
                      ("\u{e9}", None),
                    ]),
                  ]),
                ),
                ("a", Str("it's")),
              ]),
              Seq([Seq([Float(@double.not_a_number)]), Seq([Float(-0.0)])]),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "[z]\n\"n\\nl\" = [{ z = [{ \"\u{e9}\" = 'a\"b' }, { \"\" = false, 'q\"' = \"\", z = 1.0 }], a = \"it's\" }, [[nan], [-0.0]]]\n\n[z.'q\"']\n\"n\\nl\" = -0.0\n'q\"' = [{ b = true }, true]\nb = [[{ \"x y\" = 1.0 }, { \"\u{e9}\" = '''\na\"\n'b''' }], [{}, {}]]\n\n[[z.'q\"'.z]]\n\"n\\nl\" = 'a\"b'\n\"x y\" = true\n\n[[z.'q\"'.z.k-1]]\n\"n\\nl\" = 1099511627776\n\"x y\" = \"\u{e9}\u{4e2d}\"\nk-1 = '''\na\"\n'b'''\n\n[[z.'q\"'.z.k-1]]\nz = \"\\u0001\"\n\n[z.\"x y\"]\n\"s'\" = 1.0\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Map([
            ("z", Seq([])),
            ("", Seq([Seq([]), Str("x")])),
            ("a", Float(@double.not_a_number)),
            (
              "q\"",
              Seq([
                Map([
                  (
                    "q\"",
                    Seq([
                      Map([("s'", Str("a\"\n'b")), ("x y", Map([]))]),
                      Map([
                        ("\u{e9}", Float(@double.not_a_number)),
                        ("z", Seq([Str("a\"\n'b"), Str("x'")])),
                        ("x y", Float(-0.0)),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
          Map([]),
        ]),
      ),
    ]),
    true,
    "[['q\"']]\nz = []\n\"\" = [\n    [],\n    \"x\",\n]\na = nan\n\n[['q\"'.'q\"']]\n\n[['q\"'.'q\"'.'q\"']]\n\"s'\" = '''\na\"\n'b'''\n\n['q\"'.'q\"'.'q\"'.\"x y\"]\n\n[['q\"'.'q\"'.'q\"']]\n\"\u{e9}\" = nan\nz = [\n    '''\na\"\n'b''',\n    \"x'\",\n]\n\"x y\" = -0.0\n\n[['q\"']]\n",
  )
  check_ser(
    Map([
      (
        "q\"",
        Seq([
          Map([
            ("z", Seq([])),
            ("", Seq([Seq([]), Str("x")])),
            ("a", Float(@double.not_a_number)),
            (
              "q\"",
              Seq([
                Map([
                  (
                    "q\"",
                    Seq([
                      Map([("s'", Str("a\"\n'b")), ("x y", Map([]))]),
                      Map([
                        ("\u{e9}", Float(@double.not_a_number)),
                        ("z", Seq([Str("a\"\n'b"), Str("x'")])),
                        ("x y", Float(-0.0)),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
          Map([]),
        ]),
      ),
    ]),
    false,
    "[['q\"']]\nz = []\n\"\" = [[], \"x\"]\na = nan\n\n[['q\"'.'q\"']]\n\n[['q\"'.'q\"'.'q\"']]\n\"s'\" = '''\na\"\n'b'''\n\n['q\"'.'q\"'.'q\"'.\"x y\"]\n\n[['q\"'.'q\"'.'q\"']]\n\"\u{e9}\" = nan\nz = ['''\na\"\n'b''', \"x'\"]\n\"x y\" = -0.0\n\n[['q\"']]\n",
  )
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("z", Seq([]))]), true, "z = []\n")
  check_ser(Map([("z", Seq([]))]), false, "z = []\n")
  check_ser(
    Map([
      (
        "x y",
        Map([
          ("b", Str("x'")),
          ("s'", Float(@double.infinity)),
          ("z", Seq([Map([("s'", Map([]))])])),
        ]),
      ),
      ("a", Str("a\"b")),
    ]),
    true,
    "a = 'a\"b'\n\n[\"x y\"]\nb = \"x'\"\n\"s'\" = inf\n\n[[\"x y\".z]]\n\n[\"x y\".z.\"s'\"]\n",
  )
  check_ser(
    Map([
      (
        "x y",
        Map([
          ("b", Str("x'")),
          ("s'", Float(@double.infinity)),
          ("z", Seq([Map([("s'", Map([]))])])),
        ]),
      ),
      ("a", Str("a\"b")),
    ]),
    false,
    "a = 'a\"b'\n\n[\"x y\"]\nb = \"x'\"\n\"s'\" = inf\n\n[[\"x y\".z]]\n\n[\"x y\".z.\"s'\"]\n",
  )
  check_ser(
    Map([
      (
        "b",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Map([]),
                Map([
                  (
                    "b",
                    Map([
                      ("s'", Seq([Float(@double.not_a_number)])),
                      (
                        "z",
                        Map([
                          ("b", Str("\"'")),
                          ("\u{e9}", Str("x")),
                          ("s'", Float(1.0)),
                        ]),
                      ),
                    ]),
                  ),
                  ("x y", Map([("x y", Str("\"'"))])),
                  ("a", Seq([Seq([Float(1.0e20), Float(1.0)])])),
                ]),
                Map([
                  (
                    "n\nl",
                    Seq([
                      Seq([Str("\u{1}"), Str("a\"b")]),
                      Str("\t"),
                      Map([("a", Float(@double.infinity))]),
                    ]),
                  ),
                  ("", Map([("b", Seq([Float(3.14159), Str("a\\b")]))])),
                  (
                    "a",
                    Seq([
                      Seq([Float(@double.not_a_number), Float(1.0e-09)]),
                      Bool(false),
                      Str("x'"),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
          Map([("\u{e9}", Float(@double.infinity))]),
        ]),
      ),
      ("a", Float(@double.not_a_number)),
    ]),
    true,
    "a = nan\n\n[[b]]\n\n[[b.\"s'\"]]\n\n[[b.\"s'\"]]\na = [[\n    100000000000000000000.0,\n    1.0,\n]]\n\n[b.\"s'\".b]\n\"s'\" = [nan]\n\n[b.\"s'\".b.z]\nb = \"\\\"'\"\n\"\u{e9}\" = \"x\"\n\"s'\" = 1.0\n\n[b.\"s'\".\"x y\"]\n\"x y\" = \"\\\"'\"\n\n[[b.\"s'\"]]\n\"n\\nl\" = [\n    [\n    \"\\u0001\",\n    'a\"b',\n],\n    \"\\t\",\n    { a = inf },\n]\na = [\n    [\n    nan,\n    0.000000001,\n],\n    false,\n    \"x'\",\n]\n\n[b.\"s'\".\"\"]\nb = [\n    3.14159,\n    'a\\b',\n]\n\n[[b]]\n\"\u{e9}\" = inf\n",
  )
  check_ser(
    Map([
      (
        "b",
        Seq([
          Map([
            (
              "s'",
              Seq([
                Map([]),
                Map([
                  (
                    "b",
                    Map([
                      ("s'", Seq([Float(@double.not_a_number)])),
                      (
                        "z",
                        Map([
                          ("b", Str("\"'")),
                          ("\u{e9}", Str("x")),
                          ("s'", Float(1.0)),
                        ]),
                      ),
                    ]),
                  ),
                  ("x y", Map([("x y", Str("\"'"))])),
                  ("a", Seq([Seq([Float(1.0e20), Float(1.0)])])),
                ]),
                Map([
                  (
                    "n\nl",
                    Seq([
                      Seq([Str("\u{1}"), Str("a\"b")]),
                      Str("\t"),
                      Map([("a", Float(@double.infinity))]),
                    ]),
                  ),
                  ("", Map([("b", Seq([Float(3.14159), Str("a\\b")]))])),
                  (
                    "a",
                    Seq([
                      Seq([Float(@double.not_a_number), Float(1.0e-09)]),
                      Bool(false),
                      Str("x'"),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
          Map([("\u{e9}", Float(@double.infinity))]),
        ]),
      ),
      ("a", Float(@double.not_a_number)),
    ]),
    false,
    "a = nan\n\n[[b]]\n\n[[b.\"s'\"]]\n\n[[b.\"s'\"]]\na = [[100000000000000000000.0, 1.0]]\n\n[b.\"s'\".b]\n\"s'\" = [nan]\n\n[b.\"s'\".b.z]\nb = \"\\\"'\"\n\"\u{e9}\" = \"x\"\n\"s'\" = 1.0\n\n[b.\"s'\".\"x y\"]\n\"x y\" = \"\\\"'\"\n\n[[b.\"s'\"]]\n\"n\\nl\" = [[\"\\u0001\", 'a\"b'], \"\\t\", { a = inf }]\na = [[nan, 0.000000001], false, \"x'\"]\n\n[b.\"s'\".\"\"]\nb = [3.14159, 'a\\b']\n\n[[b]]\n\"\u{e9}\" = inf\n",
  )
  check_ser(
    Map([("x y", Float(-0.0)), ("", Float(-0.0))]),
    true,
    "\"x y\" = -0.0\n\"\" = -0.0\n",
  )
  check_ser(
    Map([("x y", Float(-0.0)), ("", Float(-0.0))]),
    false,
    "\"x y\" = -0.0\n\"\" = -0.0\n",
  )
  check_ser(
    Map([
      (
        "",
        Seq([
          Seq([
            Seq([
              Map([
                (
                  "a",
                  Seq([Float(3.14159), Str("l1\nl2"), Float(@double.infinity)]),
                ),
                ("q\"", Int(1099511627776L)),
              ]),
              Map([
                ("s'", Seq([])),
                ("x y", Map([])),
                (
                  "\u{e9}",
                  Seq([
                    Map([
                      ("b", Float(@double.infinity)),
                      ("x y", Float(1.0e-09)),
                    ]),
                    Map([("x y", Float(0.25))]),
                    Map([("n\nl", Bool(true))]),
                  ]),
                ),
                ("a", Str("\u{1}")),
              ]),
            ]),
            Int(0L),
            Seq([
              Str("\"'"),
              Float(@double.infinity),
              Seq([Str("\u{1}"), Str("a\\b")]),
            ]),
          ]),
          Seq([
            Map([
              (
                "b",
                Seq([
                  Str("\u{1}"),
                  Map([("\u{e9}", Str("\u{e9}\u{4e2d}"))]),
                  Map([("s'", Str("a\"b"))]),
                ]),
              ),
              ("k-1", Int(1099511627776L)),
            ]),
            Map([("a", Float(1.0)), ("k-1", Seq([]))]),
            Map([
              ("k-1", Seq([Float(0.25)])),
              ("s'", Float(@double.not_a_number)),
            ]),
          ]),
        ]),
      ),
    ]),
    true,
    "\"\" = [\n    [\n    [\n    { a = [\n    3.14159,\n    \"\"\"\nl1\nl2\"\"\",\n    inf,\n], 'q\"' = 1099511627776 },\n    { \"s'\" = [], \"x y\" = {}, \"\u{e9}\" = [\n    { b = inf, \"x y\" = 0.000000001 },\n    { \"x y\" = 0.25 },\n    { \"n\\nl\" = true },\n], a = \"\\u0001\" },\n],\n    0,\n    [\n    \"\\\"'\",\n    inf,\n    [\n    \"\\u0001\",\n    'a\\b',\n],\n],\n],\n    [\n    { b = [\n    \"\\u0001\",\n    { \"\u{e9}\" = \"\u{e9}\u{4e2d}\" },\n    { \"s'\" = 'a\"b' },\n], k-1 = 1099511627776 },\n    { a = 1.0, k-1 = [] },\n    { k-1 = [0.25], \"s'\" = nan },\n],\n]\n",
  )
  check_ser(
    Map([
      (
        "",
        Seq([
          Seq([
            Seq([
              Map([
                (
                  "a",
                  Seq([Float(3.14159), Str("l1\nl2"), Float(@double.infinity)]),
                ),
                ("q\"", Int(1099511627776L)),
              ]),
              Map([
                ("s'", Seq([])),
                ("x y", Map([])),
                (
                  "\u{e9}",
                  Seq([
                    Map([
                      ("b", Float(@double.infinity)),
                      ("x y", Float(1.0e-09)),
                    ]),
                    Map([("x y", Float(0.25))]),
                    Map([("n\nl", Bool(true))]),
                  ]),
                ),
                ("a", Str("\u{1}")),
              ]),
            ]),
            Int(0L),
            Seq([
              Str("\"'"),
              Float(@double.infinity),
              Seq([Str("\u{1}"), Str("a\\b")]),
            ]),
          ]),
          Seq([
            Map([
              (
                "b",
                Seq([
                  Str("\u{1}"),
                  Map([("\u{e9}", Str("\u{e9}\u{4e2d}"))]),
                  Map([("s'", Str("a\"b"))]),
                ]),
              ),
              ("k-1", Int(1099511627776L)),
            ]),
            Map([("a", Float(1.0)), ("k-1", Seq([]))]),
            Map([
              ("k-1", Seq([Float(0.25)])),
              ("s'", Float(@double.not_a_number)),
            ]),
          ]),
        ]),
      ),
    ]),
    false,
    "\"\" = [[[{ a = [3.14159, \"\"\"\nl1\nl2\"\"\", inf], 'q\"' = 1099511627776 }, { \"s'\" = [], \"x y\" = {}, \"\u{e9}\" = [{ b = inf, \"x y\" = 0.000000001 }, { \"x y\" = 0.25 }, { \"n\\nl\" = true }], a = \"\\u0001\" }], 0, [\"\\\"'\", inf, [\"\\u0001\", 'a\\b']]], [{ b = [\"\\u0001\", { \"\u{e9}\" = \"\u{e9}\u{4e2d}\" }, { \"s'\" = 'a\"b' }], k-1 = 1099511627776 }, { a = 1.0, k-1 = [] }, { k-1 = [0.25], \"s'\" = nan }]]\n",
  )
  check_ser(
    Map([
      ("k-1", Seq([Map([]), Seq([])])),
      (
        "n\nl",
        Seq([
          Map([]),
          Map([
            (
              "n\nl",
              Seq([
                Map([
                  ("b", Map([])),
                  (
                    "z",
                    Map([
                      ("b", Str("a\"\n'b")),
                      ("a", Float(1.0)),
                      ("z", Int(1099511627776L)),
                    ]),
                  ),
                  ("x y", Str("\t")),
                ]),
                Map([]),
                Map([
                  (
                    "a",
                    Seq([
                      Map([("b", Seq([Float(-0.0)])), ("k-1", Seq([None]))]),
                      Map([
                        ("s'", Seq([Str("x"), Float(1.0e-09)])),
                        (
                          "k-1",
                          Seq([Str("\u{e9}\u{4e2d}"), Float(@double.infinity)]),
                        ),
                        ("z", Str("a\"\n'b")),
                      ]),
                      Map([
                        (
                          "b",
                          Map([
                            ("a", Str("\t")),
                            ("k-1", Str("a\"b")),
                            ("x y", Float(3.14159)),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                  (
                    "k-1",
                    Seq([
                      Map([
                        ("a", Seq([Str("\u{1}"), Str("\t")])),
                        ("", Seq([Str("l1\nl2"), Str("'''"), Str("\"'")])),
                        ("x y", Float(1.0e20)),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
          Map([
            (
              "n\nl",
              Seq([
                Map([
                  ("z", Str("")),
                  (
                    "s'",
                    Seq([
                      Map([
                        ("s'", Seq([Float(1.0e-09), Str("a\\b")])),
                        ("q\"", Float(1.0e-09)),
                        ("b", Float(0.25)),
                      ]),
                      Map([]),
                      Map([("k-1", Float(@double.not_a_number))]),
                    ]),
                  ),
                  (
                    "a",
                    Seq([
                      Map([
                        ("b", None),
                        ("q\"", Float(0.25)),
                        ("x y", Str("'''")),
                        ("s'", Str("\u{e9}\u{4e2d}")),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            (
              "b",
              Map([
                ("k-1", Seq([None, Int(1099511627776L), Float(1.0e-09)])),
                ("\u{e9}", Map([])),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("k-1", Seq([Map([]), Seq([])])),
      (
        "n\nl",
        Seq([
          Map([]),
          Map([
            (
              "n\nl",
              Seq([
                Map([
                  ("b", Map([])),
                  (
                    "z",
                    Map([
                      ("b", Str("a\"\n'b")),
                      ("a", Float(1.0)),
                      ("z", Int(1099511627776L)),
                    ]),
                  ),
                  ("x y", Str("\t")),
                ]),
                Map([]),
                Map([
                  (
                    "a",
                    Seq([
                      Map([("b", Seq([Float(-0.0)])), ("k-1", Seq([None]))]),
                      Map([
                        ("s'", Seq([Str("x"), Float(1.0e-09)])),
                        (
                          "k-1",
                          Seq([Str("\u{e9}\u{4e2d}"), Float(@double.infinity)]),
                        ),
                        ("z", Str("a\"\n'b")),
                      ]),
                      Map([
                        (
                          "b",
                          Map([
                            ("a", Str("\t")),
                            ("k-1", Str("a\"b")),
                            ("x y", Float(3.14159)),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                  (
                    "k-1",
                    Seq([
                      Map([
                        ("a", Seq([Str("\u{1}"), Str("\t")])),
                        ("", Seq([Str("l1\nl2"), Str("'''"), Str("\"'")])),
                        ("x y", Float(1.0e20)),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
          Map([
            (
              "n\nl",
              Seq([
                Map([
                  ("z", Str("")),
                  (
                    "s'",
                    Seq([
                      Map([
                        ("s'", Seq([Float(1.0e-09), Str("a\\b")])),
                        ("q\"", Float(1.0e-09)),
                        ("b", Float(0.25)),
                      ]),
                      Map([]),
                      Map([("k-1", Float(@double.not_a_number))]),
                    ]),
                  ),
                  (
                    "a",
                    Seq([
                      Map([
                        ("b", None),
                        ("q\"", Float(0.25)),
                        ("x y", Str("'''")),
                        ("s'", Str("\u{e9}\u{4e2d}")),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            (
              "b",
              Map([
                ("k-1", Seq([None, Int(1099511627776L), Float(1.0e-09)])),
                ("\u{e9}", Map([])),
              ]),
            ),
          ]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("s'", Str("'''")),
      ("a", Float(@double.infinity)),
      (
        "x y",
        Seq([
          Map([
            ("", Map([("s'", Str("l1\nl2")), ("x y", Bool(true))])),
            (
              "n\nl",
              Seq([Map([("s'", Bool(false))]), Map([("b", Str("a\\b"))])]),
            ),
          ]),
          Int(-7L),
          Seq([Seq([Map([("x y", Map([("n\nl", Float(-0.0))]))])])]),
        ]),
      ),
    ]),
    true,
    "\"s'\" = \"'''\"\na = inf\n\"x y\" = [\n    { \"\" = { \"s'\" = \"\"\"\nl1\nl2\"\"\", \"x y\" = true }, \"n\\nl\" = [\n    { \"s'\" = false },\n    { b = 'a\\b' },\n] },\n    -7,\n    [[{ \"x y\" = { \"n\\nl\" = -0.0 } }]],\n]\n",
  )
  check_ser(
    Map([
      ("s'", Str("'''")),
      ("a", Float(@double.infinity)),
      (
        "x y",
        Seq([
          Map([
            ("", Map([("s'", Str("l1\nl2")), ("x y", Bool(true))])),
            (
              "n\nl",
              Seq([Map([("s'", Bool(false))]), Map([("b", Str("a\\b"))])]),
            ),
          ]),
          Int(-7L),
          Seq([Seq([Map([("x y", Map([("n\nl", Float(-0.0))]))])])]),
        ]),
      ),
    ]),
    false,
    "\"s'\" = \"'''\"\na = inf\n\"x y\" = [{ \"\" = { \"s'\" = \"\"\"\nl1\nl2\"\"\", \"x y\" = true }, \"n\\nl\" = [{ \"s'\" = false }, { b = 'a\\b' }] }, -7, [[{ \"x y\" = { \"n\\nl\" = -0.0 } }]]]\n",
  )
  check_ser(Map([("z", Str("it's"))]), true, "z = \"it's\"\n")
  check_ser(Map([("z", Str("it's"))]), false, "z = \"it's\"\n")
  check_ser(
    Map([
      ("q\"", Str("\u{1}")),
      (
        "z",
        Seq([
          Map([("q\"", Seq([Map([])]))]),
          Map([
            ("n\nl", Float(1.0)),
            (
              "k-1",
              Seq([
                Float(1.0e-09),
                Map([
                  ("k-1", Seq([Int(0L), None, Float(1.0)])),
                  ("z", Seq([Float(0.25), Str("x")])),
                  ("s'", Map([])),
                ]),
                Seq([Map([("q\"", Str("l1\nl2"))]), Map([])]),
              ]),
            ),
            ("a", None),
            ("x y", Float(1.0)),
          ]),
          Map([
            ("z", Int(1099511627776L)),
            (
              "n\nl",
              Seq([
                Map([
                  (
                    "q\"",
                    Seq([
                      Map([
                        ("", Int(0L)),
                        ("x y", Seq([Str("a\"\n'b"), Int(1099511627776L)])),
                        ("z", Str("'''")),
                      ]),
                      Map([
                        ("q\"", Seq([Str("a\"b")])),
                        (
                          "k-1",
                          Map([
                            ("s'", Str("\u{1}")),
                            ("q\"", Float(@double.infinity)),
                          ]),
                        ),
                        ("s'", Seq([Int(1099511627776L), Str("'''")])),
                      ]),
                      Map([
                        (
                          "x y",
                          Seq([
                            Map([("s'", Bool(true))]),
                            Map([("k-1", Float(1.0))]),
                          ]),
                        ),
                        ("z", Seq([])),
                      ]),
                    ]),
                  ),
                ]),
                Map([
                  (
                    "q\"",
                    Map([
                      ("q\"", Str("\u{e9}\u{4e2d}")),
                      ("\u{e9}", Str("x")),
                      ("", Str("\"'")),
                    ]),
                  ),
                  ("z", Bool(false)),
                ]),
              ]),
            ),
            ("a", Str("x")),
          ]),
        ]),
      ),
      ("\u{e9}", Seq([])),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("q\"", Str("\u{1}")),
      (
        "z",
        Seq([
          Map([("q\"", Seq([Map([])]))]),
          Map([
            ("n\nl", Float(1.0)),
            (
              "k-1",
              Seq([
                Float(1.0e-09),
                Map([
                  ("k-1", Seq([Int(0L), None, Float(1.0)])),
                  ("z", Seq([Float(0.25), Str("x")])),
                  ("s'", Map([])),
                ]),
                Seq([Map([("q\"", Str("l1\nl2"))]), Map([])]),
              ]),
            ),
            ("a", None),
            ("x y", Float(1.0)),
          ]),
          Map([
            ("z", Int(1099511627776L)),
            (
              "n\nl",
              Seq([
                Map([
                  (
                    "q\"",
                    Seq([
                      Map([
                        ("", Int(0L)),
                        ("x y", Seq([Str("a\"\n'b"), Int(1099511627776L)])),
                        ("z", Str("'''")),
                      ]),
                      Map([
                        ("q\"", Seq([Str("a\"b")])),
                        (
                          "k-1",
                          Map([
                            ("s'", Str("\u{1}")),
                            ("q\"", Float(@double.infinity)),
                          ]),
                        ),
                        ("s'", Seq([Int(1099511627776L), Str("'''")])),
                      ]),
                      Map([
                        (
                          "x y",
                          Seq([
                            Map([("s'", Bool(true))]),
                            Map([("k-1", Float(1.0))]),
                          ]),
                        ),
                        ("z", Seq([])),
                      ]),
                    ]),
                  ),
                ]),
                Map([
                  (
                    "q\"",
                    Map([
                      ("q\"", Str("\u{e9}\u{4e2d}")),
                      ("\u{e9}", Str("x")),
                      ("", Str("\"'")),
                    ]),
                  ),
                  ("z", Bool(false)),
                ]),
              ]),
            ),
            ("a", Str("x")),
          ]),
        ]),
      ),
      ("\u{e9}", Seq([])),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "b",
        Map([
          ("", Int(1099511627776L)),
          (
            "q\"",
            Seq([
              Map([
                (
                  "z",
                  Map([
                    ("x y", Float(0.25)),
                    ("a", Seq([Str("l1\nl2"), Bool(true), Str("'''")])),
                  ]),
                ),
                ("b", Seq([])),
                ("k-1", Seq([])),
              ]),
            ]),
          ),
        ]),
      ),
      (
        "a",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Float(-0.0),
                Seq([Str("a\"b"), Seq([])]),
                Map([
                  ("a", Str("a\\b")),
                  ("q\"", Map([("", None), ("z", Float(@double.not_a_number))])),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
      ("n\nl", Seq([])),
    ]),
    true,
    "\"n\\nl\" = []\n\n[b]\n\"\" = 1099511627776\n\n[[b.'q\"']]\nb = []\nk-1 = []\n\n[b.'q\"'.z]\n\"x y\" = 0.25\na = [\n    \"\"\"\nl1\nl2\"\"\",\n    true,\n    \"'''\",\n]\n\n[[a]]\n\"x y\" = [\n    -0.0,\n    [\n    'a\"b',\n    [],\n],\n    { a = 'a\\b', 'q\"' = { z = nan } },\n]\n",
  )
  check_ser(
    Map([
      (
        "b",
        Map([
          ("", Int(1099511627776L)),
          (
            "q\"",
            Seq([
              Map([
                (
                  "z",
                  Map([
                    ("x y", Float(0.25)),
                    ("a", Seq([Str("l1\nl2"), Bool(true), Str("'''")])),
                  ]),
                ),
                ("b", Seq([])),
                ("k-1", Seq([])),
              ]),
            ]),
          ),
        ]),
      ),
      (
        "a",
        Seq([
          Map([
            (
              "x y",
              Seq([
                Float(-0.0),
                Seq([Str("a\"b"), Seq([])]),
                Map([
                  ("a", Str("a\\b")),
                  ("q\"", Map([("", None), ("z", Float(@double.not_a_number))])),
                ]),
              ]),
            ),
          ]),
        ]),
      ),
      ("n\nl", Seq([])),
    ]),
    false,
    "\"n\\nl\" = []\n\n[b]\n\"\" = 1099511627776\n\n[[b.'q\"']]\nb = []\nk-1 = []\n\n[b.'q\"'.z]\n\"x y\" = 0.25\na = [\"\"\"\nl1\nl2\"\"\", true, \"'''\"]\n\n[[a]]\n\"x y\" = [-0.0, ['a\"b', []], { a = 'a\\b', 'q\"' = { z = nan } }]\n",
  )
  check_ser(Map([("k-1", Float(@double.infinity))]), true, "k-1 = inf\n")
  check_ser(Map([("k-1", Float(@double.infinity))]), false, "k-1 = inf\n")
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(
    Map([("x y", Seq([])), ("s'", Map([]))]),
    true,
    "\"x y\" = []\n\n[\"s'\"]\n",
  )
  check_ser(
    Map([("x y", Seq([])), ("s'", Map([]))]),
    false,
    "\"x y\" = []\n\n[\"s'\"]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Map([
          ("s'", Map([("k-1", Seq([Map([("z", Float(0.25))]), Bool(true)]))])),
        ]),
      ),
    ]),
    true,
    "[a.\"s'\"]\nk-1 = [\n    { z = 0.25 },\n    true,\n]\n",
  )
  check_ser(
    Map([
      (
        "a",
        Map([
          ("s'", Map([("k-1", Seq([Map([("z", Float(0.25))]), Bool(true)]))])),
        ]),
      ),
    ]),
    false,
    "[a.\"s'\"]\nk-1 = [{ z = 0.25 }, true]\n",
  )
  check_ser(
    Map([("b", Str("\u{e9}\u{4e2d}"))]),
    true,
    "b = \"\u{e9}\u{4e2d}\"\n",
  )
  check_ser(
    Map([("b", Str("\u{e9}\u{4e2d}"))]),
    false,
    "b = \"\u{e9}\u{4e2d}\"\n",
  )
  check_ser(Map([("a", Str("a\"b"))]), true, "a = 'a\"b'\n")
  check_ser(Map([("a", Str("a\"b"))]), false, "a = 'a\"b'\n")
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("s'", None)]), true, "")
  check_ser(Map([("s'", None)]), false, "")
  check_ser(Map([]), true, "")
  check_ser(Map([]), false, "")
  check_ser(Map([("b", Bool(true))]), true, "b = true\n")
  check_ser(Map([("b", Bool(true))]), false, "b = true\n")
  check_ser(
    Map([
      (
        "s'",
        Map([
          (
            "s'",
            Seq([
              Map([
                (
                  "n\nl",
                  Map([
                    ("n\nl", Seq([Map([("", Float(3.14159))])])),
                    (
                      "s'",
                      Seq([Map([("a", Str("it's")), ("\u{e9}", Float(-0.0))])]),
                    ),
                    (
                      "z",
                      Seq([
                        Map([("q\"", Int(1099511627776L))]),
                        Map([("b", Float(1.0))]),
                      ]),
                    ),
                  ]),
                ),
                ("k-1", Str("it's")),
                ("\u{e9}", Float(1.0e-09)),
              ]),
              Map([
                (
                  "q\"",
                  Map([("q\"", Seq([Str("x'"), Float(@double.infinity)]))]),
                ),
              ]),
              Map([
                (
                  "k-1",
                  Seq([
                    Map([
                      (
                        "k-1",
                        Map([("", Str("'''")), ("s'", Int(1099511627776L))]),
                      ),
                      ("\u{e9}", Str("'''")),
                    ]),
                  ]),
                ),
                (
                  "a",
                  Seq([
                    Seq([
                      Map([("k-1", Str("a\"\n'b")), ("z", Bool(false))]),
                      Map([
                        ("z", Str("\u{e9}\u{4e2d}")),
                        ("b", Float(-0.0)),
                        ("\u{e9}", Bool(true)),
                        ("x y", Float(3.14159)),
                      ]),
                    ]),
                    Seq([Str("\"'"), None]),
                    Map([
                      ("\u{e9}", Str("'''")),
                      ("z", Bool(false)),
                      ("b", Float(1.0e20)),
                    ]),
                  ]),
                ),
                ("b", Seq([Str("x")])),
              ]),
            ]),
          ),
          (
            "\u{e9}",
            Seq([
              Float(1.0e-09),
              Seq([Map([("b", None), ("s'", Float(1.0e-09))])]),
              Float(1.0e-09),
            ]),
          ),
          ("b", Str("x'")),
          (
            "",
            Map([
              (
                "b",
                Map([
                  (
                    "z",
                    Map([
                      ("\u{e9}", Str("")),
                      ("x y", Str("\t")),
                      ("", Str("a\"\n'b")),
                    ]),
                  ),
                  ("s'", Seq([])),
                  (
                    "q\"",
                    Map([
                      ("", Str("x")),
                      ("b", Str("'''")),
                      ("n\nl", Int(1099511627776L)),
                    ]),
                  ),
                ]),
              ),
              ("\u{e9}", Seq([Map([])])),
              ("q\"", Seq([])),
            ]),
          ),
        ]),
      ),
      (
        "x y",
        Seq([
          Map([
            ("k-1", Seq([])),
            ("s'", Float(@double.infinity)),
            ("\u{e9}", Float(-0.0)),
            ("a", Map([("s'", Map([("z", Str("x'"))]))])),
          ]),
          Map([
            ("z", Bool(true)),
            ("", Str("x")),
            (
              "s'",
              Seq([
                Seq([Float(1.0), Seq([Map([])])]),
                Map([("q\"", Str("\u{1}"))]),
              ]),
            ),
            ("b", Seq([Str("it's")])),
          ]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "s'",
        Map([
          (
            "s'",
            Seq([
              Map([
                (
                  "n\nl",
                  Map([
                    ("n\nl", Seq([Map([("", Float(3.14159))])])),
                    (
                      "s'",
                      Seq([Map([("a", Str("it's")), ("\u{e9}", Float(-0.0))])]),
                    ),
                    (
                      "z",
                      Seq([
                        Map([("q\"", Int(1099511627776L))]),
                        Map([("b", Float(1.0))]),
                      ]),
                    ),
                  ]),
                ),
                ("k-1", Str("it's")),
                ("\u{e9}", Float(1.0e-09)),
              ]),
              Map([
                (
                  "q\"",
                  Map([("q\"", Seq([Str("x'"), Float(@double.infinity)]))]),
                ),
              ]),
              Map([
                (
                  "k-1",
                  Seq([
                    Map([
                      (
                        "k-1",
                        Map([("", Str("'''")), ("s'", Int(1099511627776L))]),
                      ),
                      ("\u{e9}", Str("'''")),
                    ]),
                  ]),
                ),
                (
                  "a",
                  Seq([
                    Seq([
                      Map([("k-1", Str("a\"\n'b")), ("z", Bool(false))]),
                      Map([
                        ("z", Str("\u{e9}\u{4e2d}")),
                        ("b", Float(-0.0)),
                        ("\u{e9}", Bool(true)),
                        ("x y", Float(3.14159)),
                      ]),
                    ]),
                    Seq([Str("\"'"), None]),
                    Map([
                      ("\u{e9}", Str("'''")),
                      ("z", Bool(false)),
                      ("b", Float(1.0e20)),
                    ]),
                  ]),
                ),
                ("b", Seq([Str("x")])),
              ]),
            ]),
          ),
          (
            "\u{e9}",
            Seq([
              Float(1.0e-09),
              Seq([Map([("b", None), ("s'", Float(1.0e-09))])]),
              Float(1.0e-09),
            ]),
          ),
          ("b", Str("x'")),
          (
            "",
            Map([
              (
                "b",
                Map([
                  (
                    "z",
                    Map([
                      ("\u{e9}", Str("")),
                      ("x y", Str("\t")),
                      ("", Str("a\"\n'b")),
                    ]),
                  ),
                  ("s'", Seq([])),
                  (
                    "q\"",
                    Map([
                      ("", Str("x")),
                      ("b", Str("'''")),
                      ("n\nl", Int(1099511627776L)),
                    ]),
                  ),
                ]),
              ),
              ("\u{e9}", Seq([Map([])])),
              ("q\"", Seq([])),
            ]),
          ),
        ]),
      ),
      (
        "x y",
        Seq([
          Map([
            ("k-1", Seq([])),
            ("s'", Float(@double.infinity)),
            ("\u{e9}", Float(-0.0)),
            ("a", Map([("s'", Map([("z", Str("x'"))]))])),
          ]),
          Map([
            ("z", Bool(true)),
            ("", Str("x")),
            (
              "s'",
              Seq([
                Seq([Float(1.0), Seq([Map([])])]),
                Map([("q\"", Str("\u{1}"))]),
              ]),
            ),
            ("b", Seq([Str("it's")])),
          ]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("\u{e9}", Bool(false)),
      ("k-1", Seq([Bool(true), None, Int(1099511627776L)])),
      (
        "",
        Seq([
          Map([
            ("x y", Str("\u{e9}\u{4e2d}")),
            (
              "\u{e9}",
              Map([
                (
                  "",
                  Map([
                    ("s'", Map([("x y", Float(@double.not_a_number))])),
                    (
                      "a",
                      Seq([
                        Map([]),
                        Map([("q\"", Float(-0.0)), ("b", Float(-0.0))]),
                        Map([
                          ("n\nl", Str("\u{e9}\u{4e2d}")),
                          ("q\"", Float(1.0e-09)),
                          ("", Str("'''")),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                (
                  "q\"",
                  Seq([
                    Seq([
                      Map([
                        ("", Str("it's")),
                        ("x y", Bool(true)),
                        ("q\"", Float(1.0e-09)),
                        ("s'", Str("\u{e9}\u{4e2d}")),
                      ]),
                      Map([
                        ("", Str("a\"b")),
                        ("n\nl", Str("\u{e9}\u{4e2d}")),
                        ("x y", Str("it's")),
                      ]),
                      Map([
                        ("", Float(3.14159)),
                        ("n\nl", Int(1099511627776L)),
                        ("\u{e9}", Str("x'")),
                      ]),
                    ]),
                    Map([
                      ("s'", Str("a\"b")),
                      ("b", Str("\t")),
                      ("q\"", Str("a\\b")),
                    ]),
                    Seq([Float(1.0e-09), Bool(true)]),
                  ]),
                ),
                ("b", Float(1.0)),
              ]),
            ),
          ]),
          Map([
            (
              "\u{e9}",
              Seq([
                Seq([
                  Map([
                    ("k-1", Str("a\"b")),
                    ("s'", Float(@double.not_a_number)),
                  ]),
                  Map([]),
                ]),
              ]),
            ),
            (
              "a",
              Seq([
                Seq([
                  Seq([Int(0L), Float(@double.infinity), Str("a\"\n'b")]),
                  Str("'''"),
                ]),
                Seq([
                  Seq([
                    Map([]),
                    Map([("a", Str("\"'"))]),
                    Map([("x y", Float(@double.not_a_number))]),
                  ]),
                  Seq([
                    Map([("s'", Bool(true)), ("a", Str("\u{1}"))]),
                    Map([
                      ("b", Str("\"'")),
                      ("q\"", Float(1.0e-09)),
                      ("z", Str("a\"b")),
                    ]),
                  ]),
                  Seq([Str("")]),
                ]),
              ]),
            ),
            (
              "s'",
              Seq([
                Str("\u{e9}\u{4e2d}"),
                Map([("x y", Float(-0.0)), ("", Float(0.25))]),
                Seq([Str("a\"b"), Float(3.14159)]),
              ]),
            ),
            ("k-1", Seq([Map([("q\"", Float(@double.not_a_number))])])),
          ]),
        ]),
      ),
      (
        "b",
        Seq([
          Map([
            ("b", Map([("x y", Map([("q\"", Seq([]))]))])),
            (
              "",
              Seq([
                Map([
                  (
                    "n\nl",
                    Map([
                      ("q\"", Float(1.0e20)),
                      ("x y", Float(@double.not_a_number)),
                      ("n\nl", Str("x'")),
                      ("", Float(1.0)),
                    ]),
                  ),
                ]),
                Map([("n\nl", Float(1.0e20))]),
              ]),
            ),
            ("n\nl", Seq([Str("")])),
          ]),
          Map([("\u{e9}", Map([]))]),
          Map([]),
        ]),
      ),
    ]),
    true,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      ("\u{e9}", Bool(false)),
      ("k-1", Seq([Bool(true), None, Int(1099511627776L)])),
      (
        "",
        Seq([
          Map([
            ("x y", Str("\u{e9}\u{4e2d}")),
            (
              "\u{e9}",
              Map([
                (
                  "",
                  Map([
                    ("s'", Map([("x y", Float(@double.not_a_number))])),
                    (
                      "a",
                      Seq([
                        Map([]),
                        Map([("q\"", Float(-0.0)), ("b", Float(-0.0))]),
                        Map([
                          ("n\nl", Str("\u{e9}\u{4e2d}")),
                          ("q\"", Float(1.0e-09)),
                          ("", Str("'''")),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                (
                  "q\"",
                  Seq([
                    Seq([
                      Map([
                        ("", Str("it's")),
                        ("x y", Bool(true)),
                        ("q\"", Float(1.0e-09)),
                        ("s'", Str("\u{e9}\u{4e2d}")),
                      ]),
                      Map([
                        ("", Str("a\"b")),
                        ("n\nl", Str("\u{e9}\u{4e2d}")),
                        ("x y", Str("it's")),
                      ]),
                      Map([
                        ("", Float(3.14159)),
                        ("n\nl", Int(1099511627776L)),
                        ("\u{e9}", Str("x'")),
                      ]),
                    ]),
                    Map([
                      ("s'", Str("a\"b")),
                      ("b", Str("\t")),
                      ("q\"", Str("a\\b")),
                    ]),
                    Seq([Float(1.0e-09), Bool(true)]),
                  ]),
                ),
                ("b", Float(1.0)),
              ]),
            ),
          ]),
          Map([
            (
              "\u{e9}",
              Seq([
                Seq([
                  Map([
                    ("k-1", Str("a\"b")),
                    ("s'", Float(@double.not_a_number)),
                  ]),
                  Map([]),
                ]),
              ]),
            ),
            (
              "a",
              Seq([
                Seq([
                  Seq([Int(0L), Float(@double.infinity), Str("a\"\n'b")]),
                  Str("'''"),
                ]),
                Seq([
                  Seq([
                    Map([]),
                    Map([("a", Str("\"'"))]),
                    Map([("x y", Float(@double.not_a_number))]),
                  ]),
                  Seq([
                    Map([("s'", Bool(true)), ("a", Str("\u{1}"))]),
                    Map([
                      ("b", Str("\"'")),
                      ("q\"", Float(1.0e-09)),
                      ("z", Str("a\"b")),
                    ]),
                  ]),
                  Seq([Str("")]),
                ]),
              ]),
            ),
            (
              "s'",
              Seq([
                Str("\u{e9}\u{4e2d}"),
                Map([("x y", Float(-0.0)), ("", Float(0.25))]),
                Seq([Str("a\"b"), Float(3.14159)]),
              ]),
            ),
            ("k-1", Seq([Map([("q\"", Float(@double.not_a_number))])])),
          ]),
        ]),
      ),
      (
        "b",
        Seq([
          Map([
            ("b", Map([("x y", Map([("q\"", Seq([]))]))])),
            (
              "",
              Seq([
                Map([
                  (
                    "n\nl",
                    Map([
                      ("q\"", Float(1.0e20)),
                      ("x y", Float(@double.not_a_number)),
                      ("n\nl", Str("x'")),
                      ("", Float(1.0)),
                    ]),
                  ),
                ]),
                Map([("n\nl", Float(1.0e20))]),
              ]),
            ),
            ("n\nl", Seq([Str("")])),
          ]),
          Map([("\u{e9}", Map([]))]),
          Map([]),
        ]),
      ),
    ]),
    false,
    "ERR unsupported None value",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Map([
          (
            "x y",
            Map([
              (
                "k-1",
                Seq([
                  Map([]),
                  Seq([Bool(false), Bool(false), Str("it's")]),
                  Seq([
                    Map([("s'", Float(1.0e20))]),
                    Map([("n\nl", Bool(false)), ("", Str("\u{e9}\u{4e2d}"))]),
                  ]),
                ]),
              ),
              ("q\"", Seq([Map([("z", Float(3.14159))])])),
              ("\u{e9}", Map([])),
              ("s'", Float(@double.infinity)),
            ]),
          ),
        ]),
      ),
    ]),
    true,
    "[\"n\\nl\".\"x y\"]\nk-1 = [\n    {},\n    [\n    false,\n    false,\n    \"it's\",\n],\n    [\n    { \"s'\" = 100000000000000000000.0 },\n    { \"n\\nl\" = false, \"\" = \"\u{e9}\u{4e2d}\" },\n],\n]\n\"s'\" = inf\n\n[[\"n\\nl\".\"x y\".'q\"']]\nz = 3.14159\n\n[\"n\\nl\".\"x y\".\"\u{e9}\"]\n",
  )
  check_ser(
    Map([
      (
        "n\nl",
        Map([
          (
            "x y",
            Map([
              (
                "k-1",
                Seq([
                  Map([]),
                  Seq([Bool(false), Bool(false), Str("it's")]),
                  Seq([
                    Map([("s'", Float(1.0e20))]),
                    Map([("n\nl", Bool(false)), ("", Str("\u{e9}\u{4e2d}"))]),
                  ]),
                ]),
              ),
              ("q\"", Seq([Map([("z", Float(3.14159))])])),
              ("\u{e9}", Map([])),
              ("s'", Float(@double.infinity)),
            ]),
          ),
        ]),
      ),
    ]),
    false,
    "[\"n\\nl\".\"x y\"]\nk-1 = [{}, [false, false, \"it's\"], [{ \"s'\" = 100000000000000000000.0 }, { \"n\\nl\" = false, \"\" = \"\u{e9}\u{4e2d}\" }]]\n\"s'\" = inf\n\n[[\"n\\nl\".\"x y\".'q\"']]\nz = 3.14159\n\n[\"n\\nl\".\"x y\".\"\u{e9}\"]\n",
  )
}
