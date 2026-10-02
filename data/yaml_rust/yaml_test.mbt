// Ports of the unit tests in yaml-rust 0.4.5 src/yaml.rs, src/lib.rs and
// src/parser.rs.

///|
fn load(s : String) -> Array[@yaml_rust.Yaml] raise @yaml_rust.ScanError {
  @yaml_rust.YamlLoader::load_from_str(s)
}

///|
test "test_coerce" {
  let s =
    #|---
    #|a: 1
    #|b: 2.2
    #|c: [1, 2]
    #|
  let out = load(s)
  let doc = out[0]
  assert_eq(doc["a"].as_i64().unwrap(), 1L)
  assert_eq(doc["b"].as_f64().unwrap(), 2.2)
  assert_eq(doc["c"][1].as_i64().unwrap(), 2L)
  assert_true(doc["d"][0].is_badvalue())
}

///|
test "test_empty_doc" {
  load("") |> ignore
  assert_eq(load("---")[0], Null)
}

///|
test "test_parser" {
  let s =
    #|
    #|# comment
    #|a0 bb: val
    #|a1:
    #|    b1: 4
    #|    b2: d
    #|a2: 4 # i'm comment
    #|a3: [1, 2, 3]
    #|a4:
    #|    - - a1
    #|      - a2
    #|    - 2
    #|a5: 'single_quoted'
    #|a6: "double_quoted"
    #|a7: 你好
    #|
  let out = load(s)
  let doc = out[0]
  assert_eq(doc["a7"].as_str().unwrap(), "你好")
}

///|
test "test_multi_doc" {
  let s =
    #|
    #|'a scalar'
    #|---
    #|'a scalar'
    #|---
    #|'a scalar'
    #|
  let out = load(s)
  assert_eq(out.length(), 3)
}

///|
test "test_anchor" {
  let s =
    #|
    #|a1: &DEFAULT
    #|    b1: 4
    #|    b2: d
    #|a2: *DEFAULT
    #|
  let out = load(s)
  let doc = out[0]
  assert_eq(doc["a2"]["b1"].as_i64().unwrap(), 4L)
}

///|
test "test_bad_anchor" {
  let s =
    #|
    #|a1: &DEFAULT
    #|    b1: 4
    #|    b2: *DEFAULT
    #|
  let out = load(s)
  let doc = out[0]
  assert_eq(doc["a1"]["b2"], BadValue)
}

///|
test "test_github_27" {
  // https://github.com/chyh1990/yaml-rust/issues/27
  let s = "&a"
  let out = load(s)
  let doc = out[0]
  assert_eq(doc.as_str().unwrap(), "")
}

///|
test "test_plain_datatype" {
  let s =
    #|
    #|- 'string'
    #|- "string"
    #|- string
    #|- 123
    #|- -321
    #|- 1.23
    #|- -1e4
    #|- ~
    #|- null
    #|- true
    #|- false
    #|- !!str 0
    #|- !!int 100
    #|- !!float 2
    #|- !!null ~
    #|- !!bool true
    #|- !!bool false
    #|- 0xFF
    #|# bad values
    #|- !!int string
    #|- !!float string
    #|- !!bool null
    #|- !!null val
    #|- 0o77
    #|- [ 0xF, 0xF ]
    #|- +12345
    #|- [ true, false ]
    #|
  let out = load(s)
  let doc = out[0]
  assert_eq(doc[0].as_str().unwrap(), "string")
  assert_eq(doc[1].as_str().unwrap(), "string")
  assert_eq(doc[2].as_str().unwrap(), "string")
  assert_eq(doc[3].as_i64().unwrap(), 123L)
  assert_eq(doc[4].as_i64().unwrap(), -321L)
  assert_eq(doc[5].as_f64().unwrap(), 1.23)
  assert_eq(doc[6].as_f64().unwrap(), -1.0e4)
  assert_true(doc[7].is_null())
  assert_true(doc[8].is_null())
  assert_eq(doc[9].as_bool().unwrap(), true)
  assert_eq(doc[10].as_bool().unwrap(), false)
  assert_eq(doc[11].as_str().unwrap(), "0")
  assert_eq(doc[12].as_i64().unwrap(), 100L)
  assert_eq(doc[13].as_f64().unwrap(), 2.0)
  assert_true(doc[14].is_null())
  assert_eq(doc[15].as_bool().unwrap(), true)
  assert_eq(doc[16].as_bool().unwrap(), false)
  assert_eq(doc[17].as_i64().unwrap(), 255L)
  assert_true(doc[18].is_badvalue())
  assert_true(doc[19].is_badvalue())
  assert_true(doc[20].is_badvalue())
  assert_true(doc[21].is_badvalue())
  assert_eq(doc[22].as_i64().unwrap(), 63L)
  assert_eq(doc[23][0].as_i64().unwrap(), 15L)
  assert_eq(doc[23][1].as_i64().unwrap(), 15L)
  assert_eq(doc[24].as_i64().unwrap(), 12345L)
  assert_true(doc[25][0].as_bool().unwrap())
  assert_true(!doc[25][1].as_bool().unwrap())
}

///|
test "test_bad_hyphen" {
  // See: https://github.com/chyh1990/yaml-rust/issues/23
  let s = "{-"
  assert_true(load_fails(s))
}

///|
test "test_issue_65" {
  // See: https://github.com/chyh1990/yaml-rust/issues/65
  let b = "\n\"ll\\\"ll\\\r\n\"ll\\\"ll\\\r\r\r\rU\r\r\rU"
  assert_true(load_fails(b))
}

///|
test "test_bad_docstart" {
  assert_true(!load_fails("---This used to cause an infinite loop"))
  assert_eq(load("----"), [String("----")])
  assert_eq(load("--- #here goes a comment"), [Null])
  assert_eq(load("---- #here goes a comment"), [String("----")])
}

///|
test "test_plain_datatype_with_into_methods" {
  let s =
    #|
    #|- 'string'
    #|- "string"
    #|- string
    #|- 123
    #|- -321
    #|- 1.23
    #|- -1e4
    #|- true
    #|- false
    #|- !!str 0
    #|- !!int 100
    #|- !!float 2
    #|- !!bool true
    #|- !!bool false
    #|- 0xFF
    #|- 0o77
    #|- +12345
    #|- -.INF
    #|- .NAN
    #|- !!float .INF
    #|
  let out = load(s).iter()
  let doc = out.next().unwrap().into_iter()
  assert_eq(doc.next().unwrap().into_string().unwrap(), "string")
  assert_eq(doc.next().unwrap().into_string().unwrap(), "string")
  assert_eq(doc.next().unwrap().into_string().unwrap(), "string")
  assert_eq(doc.next().unwrap().into_i64().unwrap(), 123L)
  assert_eq(doc.next().unwrap().into_i64().unwrap(), -321L)
  assert_eq(doc.next().unwrap().into_f64().unwrap(), 1.23)
  assert_eq(doc.next().unwrap().into_f64().unwrap(), -1.0e4)
  assert_eq(doc.next().unwrap().into_bool().unwrap(), true)
  assert_eq(doc.next().unwrap().into_bool().unwrap(), false)
  assert_eq(doc.next().unwrap().into_string().unwrap(), "0")
  assert_eq(doc.next().unwrap().into_i64().unwrap(), 100L)
  assert_eq(doc.next().unwrap().into_f64().unwrap(), 2.0)
  assert_eq(doc.next().unwrap().into_bool().unwrap(), true)
  assert_eq(doc.next().unwrap().into_bool().unwrap(), false)
  assert_eq(doc.next().unwrap().into_i64().unwrap(), 255L)
  assert_eq(doc.next().unwrap().into_i64().unwrap(), 63L)
  assert_eq(doc.next().unwrap().into_i64().unwrap(), 12345L)
  assert_eq(doc.next().unwrap().into_f64().unwrap(), @double.neg_infinity)
  assert_true(doc.next().unwrap().into_f64() is Some(_))
  assert_eq(doc.next().unwrap().into_f64().unwrap(), @double.infinity)
}

///|
test "test_hash_order" {
  let s =
    #|---
    #|b: ~
    #|a: ~
    #|c: ~
    #|
  let out = load(s)
  let first = out.iter().next().unwrap()
  let iter = first.into_hash().unwrap().iter()
  assert_eq(
    Some((@yaml_rust.Yaml::String("b"), @yaml_rust.Yaml::Null)),
    iter.next(),
  )
  assert_eq(
    Some((@yaml_rust.Yaml::String("a"), @yaml_rust.Yaml::Null)),
    iter.next(),
  )
  assert_eq(
    Some((@yaml_rust.Yaml::String("c"), @yaml_rust.Yaml::Null)),
    iter.next(),
  )
  assert_eq(None, iter.next())
}

///|
test "test_integer_key" {
  let s =
    #|
    #|0:
    #|    important: true
    #|1:
    #|    important: false
    #|
  let out = load(s)
  let first = out.iter().next().unwrap()
  assert_eq(first[0]["important"].as_bool().unwrap(), true)
}

///|
test "test_indentation_equality" {
  let four_spaces = load(
      (
        #|
        #|hash:
        #|    with:
        #|        indentations
        #|
      ),
    )[0]
  let two_spaces = load(
      (
        #|
        #|hash:
        #|  with:
        #|    indentations
        #|
      ),
    )[0]
  let one_space = load(
      (
        #|
        #|hash:
        #| with:
        #|  indentations
        #|
      ),
    )[0]
  let mixed_spaces = load(
      (
        #|
        #|hash:
        #|     with:
        #|               indentations
        #|
      ),
    )[0]
  assert_eq(four_spaces, two_spaces)
  assert_eq(two_spaces, one_space)
  assert_eq(four_spaces, mixed_spaces)
}

///|
test "test_two_space_indentations" {
  // https://github.com/kbknapp/clap-rs/issues/965
  let s =
    #|
    #|subcommands:
    #|  - server:
    #|    about: server related commands
    #|subcommands2:
    #|  - server:
    #|      about: server related commands
    #|subcommands3:
    #| - server:
    #|    about: server related commands
    #|
  let out = load(s)
  let doc = out.iter().next().unwrap()
  assert_eq(doc["subcommands"][0]["server"], Null)
  assert_true(doc["subcommands2"][0]["server"].as_hash() is Some(_))
  assert_true(doc["subcommands3"][0]["server"].as_hash() is Some(_))
}

///|
test "test_recursion_depth_check_objects" {
  let s = "{a:".repeat(10_000) + "}".repeat(10_000)
  assert_true(load_fails(s))
}

///|
test "test_recursion_depth_check_arrays" {
  let s = "[".repeat(10_000) + "]".repeat(10_000)
  assert_true(load_fails(s))
}

///|
/// src/lib.rs
test "test_api" {
  let s =
    #|
    #|# from yaml-cpp example
    #|- name: Ogre
    #|  position: [0, 5, 0]
    #|  powers:
    #|    - name: Club
    #|      damage: 10
    #|    - name: Fist
    #|      damage: 8
    #|- name: Dragon
    #|  position: [1, 0, 10]
    #|  powers:
    #|    - name: Fire Breath
    #|      damage: 25
    #|    - name: Claws
    #|      damage: 15
    #|- name: Wizard
    #|  position: [5, -3, 0]
    #|  powers:
    #|    - name: Acid Rain
    #|      damage: 50
    #|    - name: Staff
    #|      damage: 3
    #|
  let docs = load(s)
  let doc = docs[0]
  assert_eq(doc[0]["name"].as_str().unwrap(), "Ogre")
  let writer = StringBuilder()
  let emitter = @yaml_rust.YamlEmitter::new(writer)
  emitter.dump(doc)
  assert_true(!writer.is_empty())
}

///|
/// src/lib.rs
test "test_fail" {
  let s =
    #|
    #|# syntax error
    #|scalar
    #|key: [1, 2]]
    #|key1:a2
    #|
  assert_true(load_fails(s))
}

///|
/// src/parser.rs
test "test_peek_eq_parse" {
  let s =
    #|
    #|a0 bb: val
    #|a1: &x
    #|    b1: 4
    #|    b2: d
    #|a2: 4
    #|a3: [1, 2, 3]
    #|a4:
    #|    - [a1, a2]
    #|    - 2
    #|a5: *x
    #|
  let p = @yaml_rust.Parser::new(s)
  while true {
    let event_peek = p.peek()
    let event = p.next()
    assert_eq(event, event_peek)
    if event.0 == StreamEnd {
      break
    }
  }
}

///|
test "scan error display and marker" {
  try load("a: 'b") catch {
    e => {
      inspect(
        e,
        content="while scanning a quoted scalar, found unexpected end of stream at line 1 column 4",
      )
      let m = e.marker()
      assert_eq((m.index(), m.line(), m.col()), (3, 1, 3))
      assert_eq(
        e.info(),
        "while scanning a quoted scalar, found unexpected end of stream",
      )
    }
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "debug format and hash api" {
  let docs = load("b: [1, 2.5, \"x\\ty\", true, ~]\n")
  inspect(
    debug_docs(docs),
    content=(
      #|[Hash({String("b"): Array([Integer(1), Real("2.5"), String("x\ty"), Boolean(true), Null])})]
    ),
  )
  let h = docs[0].as_hash().unwrap()
  assert_eq(h.len(), 1)
  assert_true(h.get(String("b")) is Some(Array(_)))
  let h2 = @yaml_rust.new_hash()
  h2.insert(String("a"), Integer(1L)) |> ignore
  h2.insert(String("b"), Integer(2L)) |> ignore
  assert_eq(h2.insert(String("a"), Integer(3L)), Some(Integer(1L)))
  inspect(
    @yaml_rust.Yaml::Hash(h2),
    content=(
      #|Hash({String("b"): Integer(2), String("a"): Integer(3)})
    ),
  )
}
