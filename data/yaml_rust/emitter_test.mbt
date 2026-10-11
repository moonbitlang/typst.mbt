// Ports of the tests in yaml-rust 0.4.5 src/emitter.rs,
// tests/test_round_trip.rs and `test_mapvec_legal` of tests/spec_test.rs.

///|
fn dump(doc : @yaml_rust.Yaml, compact~ : Bool = true) -> String {
  let writer = StringBuilder()
  let emitter = @yaml_rust.YamlEmitter::new(writer)
  emitter.compact(compact)
  emitter.dump(doc)
  writer.to_string()
}

///|
test "test_emit_simple" {
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
    #|    - [a1, a2]
    #|    - 2
    #|
  let docs = load(s)
  let doc = docs[0]
  let writer = dump(doc)
  let docs_new = load(writer)
  let doc_new = docs_new[0]
  assert_eq(doc, doc_new)
}

///|
test "test_emit_complex" {
  let s =
    #|
    #|cataloge:
    #|  product: &coffee   { name: Coffee,    price: 2.5  ,  unit: 1l  }
    #|  product: &cookies  { name: Cookies!,  price: 3.40 ,  unit: 400g}
    #|
    #|products:
    #|  *coffee:
    #|    amount: 4
    #|  *cookies:
    #|    amount: 4
    #|  [1,2,3,4]:
    #|    array key
    #|  2.4:
    #|    real key
    #|  true:
    #|    bool key
    #|  {}:
    #|    empty hash key
    #|
  let docs = load(s)
  let doc = docs[0]
  let writer = dump(doc)
  let docs_new = load(writer)
  let doc_new = docs_new[0]
  assert_eq(doc, doc_new)
}

///|
test "test_emit_avoid_quotes" {
  let s =
    #|---
    #|a7: 你好
    #|boolean: "true"
    #|boolean2: "false"
    #|date: 2014-12-31
    #|empty_string: ""
    #|empty_string1: " "
    #|empty_string2: "    a"
    #|empty_string3: "    a "
    #|exp: "12e7"
    #|field: ":"
    #|field2: "{"
    #|field3: "\\"
    #|field4: "\n"
    #|field5: "can't avoid quote"
    #|float: "2.6"
    #|int: "4"
    #|nullable: "null"
    #|nullable2: "~"
    #|products:
    #|  "*coffee":
    #|    amount: 4
    #|  "*cookies":
    #|    amount: 4
    #|  ".milk":
    #|    amount: 1
    #|  "2.4": real key
    #|  "[1,2,3,4]": array key
    #|  "true": bool key
    #|  "{}": empty hash key
    #|x: test
    #|y: avoid quoting here
    #|z: string with spaces
  let docs = load(s)
  let doc = docs[0]
  let writer = dump(doc)
  assert_eq(s, writer)
}

///|
test "emit_quoted_bools" {
  let input =
    #|---
    #|string0: yes
    #|string1: no
    #|string2: "true"
    #|string3: "false"
    #|string4: "~"
    #|null0: ~
    #|[true, false]: real_bools
    #|[True, TRUE, False, FALSE, y,Y,yes,Yes,YES,n,N,no,No,NO,on,On,ON,off,Off,OFF]: false_bools
    #|bool0: true
    #|bool1: false
  let expected =
    #|---
    #|string0: "yes"
    #|string1: "no"
    #|string2: "true"
    #|string3: "false"
    #|string4: "~"
    #|null0: ~
    #|? - true
    #|  - false
    #|: real_bools
    #|? - "True"
    #|  - "TRUE"
    #|  - "False"
    #|  - "FALSE"
    #|  - y
    #|  - Y
    #|  - "yes"
    #|  - "Yes"
    #|  - "YES"
    #|  - n
    #|  - N
    #|  - "no"
    #|  - "No"
    #|  - "NO"
    #|  - "on"
    #|  - "On"
    #|  - "ON"
    #|  - "off"
    #|  - "Off"
    #|  - "OFF"
    #|: false_bools
    #|bool0: true
    #|bool1: false
  let docs = load(input)
  let doc = docs[0]
  let writer = dump(doc)
  assert_eq(expected, writer)
}

///|
fn test_empty_and_nested_flag(compact : Bool) -> Unit raise {
  let s = if compact {
    (
      #|---
      #|a:
      #|  b:
      #|    c: hello
      #|  d: {}
      #|e:
      #|  - f
      #|  - g
      #|  - h: []
    )
  } else {
    (
      #|---
      #|a:
      #|  b:
      #|    c: hello
      #|  d: {}
      #|e:
      #|  - f
      #|  - g
      #|  -
      #|    h: []
    )
  }
  let docs = load(s)
  let doc = docs[0]
  let writer = dump(doc, compact~)
  assert_eq(s, writer)
}

///|
test "test_empty_and_nested" {
  test_empty_and_nested_flag(false)
}

///|
test "test_empty_and_nested_compact" {
  test_empty_and_nested_flag(true)
}

///|
test "test_nested_arrays" {
  let s =
    #|---
    #|a:
    #|  - b
    #|  - - c
    #|    - d
    #|    - - e
    #|      - f
  let docs = load(s)
  assert_eq(s, dump(docs[0]))
}

///|
test "test_deeply_nested_arrays" {
  let s =
    #|---
    #|a:
    #|  - b
    #|  - - c
    #|    - d
    #|    - - e
    #|      - - f
    #|      - - e
  let docs = load(s)
  assert_eq(s, dump(docs[0]))
}

///|
test "test_nested_hashes" {
  let s =
    #|---
    #|a:
    #|  b:
    #|    c:
    #|      d:
    #|        e: f
  let docs = load(s)
  assert_eq(s, dump(docs[0]))
}

///|
fn roundtrip(original : @yaml_rust.Yaml) -> Unit raise {
  let emitted = dump(original)
  let documents = load(emitted)
  assert_eq(documents.length(), 1)
  assert_eq(documents[0], original)
}

///|
fn double_roundtrip(original : String) -> Unit raise {
  let parsed = load(original)
  let serialized = dump(parsed[0])
  let reparsed = load(serialized)
  assert_eq(parsed, reparsed)
}

///|
test "test_escape_character" {
  let y = @yaml_rust.Yaml::String("\u{1b}")
  roundtrip(y)
}

///|
test "test_colon_in_string" {
  let y = @yaml_rust.Yaml::String("x: %")
  roundtrip(y)
}

///|
test "test_numberlike_strings" {
  let docs = [
    "x: \"1234\"", "x: \"01234\"", "\"1234\"", "\"01234\"", "\" 01234\"", "\"0x1234\"",
    "\" 0x1234\"",
  ]
  for doc in docs {
    roundtrip(String(doc))
    double_roundtrip(doc)
  }
}

///|
/// Example from https://github.com/chyh1990/yaml-rust/issues/133
test "test_issue133" {
  let doc = load("\"0x123\"").pop().unwrap()
  assert_eq(doc, String("0x123"))
  let out_str = dump(doc)
  let doc2 = load(out_str).pop().unwrap()
  assert_eq(doc, doc2) // This failed because the type has changed to a number now
}

///|
test "test_mapvec_legal" {
  // Emitting a `map<map<seq<_>>, _>` should result in legal yaml that
  // we can parse.
  let key : Array[@yaml_rust.Yaml] = [Integer(1), Integer(2), Integer(3)]
  let keyhash = @yaml_rust.new_hash()
  keyhash.insert(String("key"), Array(key)) |> ignore
  let val : Array[@yaml_rust.Yaml] = [Integer(4), Integer(5), Integer(6)]
  let hash = @yaml_rust.new_hash()
  hash.insert(Hash(keyhash), Array(val)) |> ignore
  let out_str = dump(Hash(hash))
  load(out_str) |> ignore
}
