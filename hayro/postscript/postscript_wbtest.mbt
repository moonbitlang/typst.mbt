// Ports of the unit tests of `hayro-postscript`.

// lib.rs

///|
test "cmap_snippet" {
  let input =
    #|/CIDInit /ProcSet findresource begin
    #|12 dict begin
    #|begincmap
    #|/CMapName /Test-H def
    #|1 begincodespacerange
    #|<00> <FF>
    #|endcodespacerange
    #|2 beginbfchar
    #|<03> <0041>
    #|<04> <0042>
    #|endbfchar
    #|endcmap
  let input = @utf8.encode(input)
  let s = Scanner::new(input)
  assert_eq(s.parse_name().unwrap(), Name::new(b"CIDInit", true))
  assert_eq(s.parse_name().unwrap(), Name::new(b"ProcSet", true))
  assert_eq(s.parse_name().unwrap(), Name::new(b"findresource", false))
  assert_eq(s.parse_name().unwrap(), Name::new(b"begin", false))
  assert_eq(s.parse_number().unwrap(), Integer(12))
  assert_eq(s.parse_name().unwrap(), Name::new(b"dict", false))
  assert_eq(s.parse_name().unwrap(), Name::new(b"begin", false))
  assert_eq(s.parse_name().unwrap(), Name::new(b"begincmap", false))
  assert_eq(s.parse_name().unwrap(), Name::new(b"CMapName", true))
  assert_eq(s.parse_name().unwrap(), Name::new(b"Test-H", true))
  assert_eq(s.parse_name().unwrap(), Name::new(b"def", false))
  assert_eq(s.parse_number().unwrap(), Integer(1))
  assert_eq(s.parse_name().unwrap(), Name::new(b"begincodespacerange", false))
  assert_eq(s.parse_string().unwrap(), PsString::from_hex(b"00"))
  assert_eq(s.parse_string().unwrap(), PsString::from_hex(b"FF"))
  assert_eq(s.parse_name().unwrap(), Name::new(b"endcodespacerange", false))
  assert_eq(s.parse_number().unwrap(), Integer(2))
  assert_eq(s.parse_name().unwrap(), Name::new(b"beginbfchar", false))
  assert_eq(s.parse_string().unwrap(), PsString::from_hex(b"03"))
  assert_eq(s.parse_string().unwrap(), PsString::from_hex(b"0041"))
  assert_eq(s.parse_string().unwrap(), PsString::from_hex(b"04"))
  assert_eq(s.parse_string().unwrap(), PsString::from_hex(b"0042"))
  assert_eq(s.parse_name().unwrap(), Name::new(b"endbfchar", false))
  assert_eq(s.parse_name().unwrap(), Name::new(b"endcmap", false))
  assert_true(s.at_end())
}

///|
test "array_round_trip" {
  let scanner = Scanner::new(b"[123 /abc (xyz)]")
  let arr = scanner.parse_array().unwrap()
  assert_true(scanner.at_end())
  let inner = arr.objects()
  assert_eq(inner.parse_number().unwrap(), Integer(123))
  assert_eq(inner.parse_name().unwrap(), Name::new(b"abc", true))
  assert_eq(inner.parse_string().unwrap(), PsString::from_literal(b"xyz"))
  assert_true(inner.at_end())
}

///|
test "comments_skipped" {
  let scanner = Scanner::new(b"% comment\n42 % another\n/Name")
  assert_eq(scanner.parse_number().unwrap(), Integer(42))
  assert_eq(scanner.parse_name().unwrap(), Name::new(b"Name", true))
  assert_true(scanner.at_end())
}

///|
test "wrong_type_is_error" {
  let scanner = Scanner::new(b"42 ")
  assert_true(scanner.parse_name() is Err(_))
}

// number.rs

///|
fn read_num(input : Bytes) -> Result[Number, PsError] {
  read_number(Reader::new(input))
}

///|
test "signed_integers" {
  assert_eq(read_num(b"123 ").unwrap(), Integer(123))
  assert_eq(read_num(b"-98 ").unwrap(), Integer(-98))
  assert_eq(read_num(b"43445 ").unwrap(), Integer(43445))
  assert_eq(read_num(b"0 ").unwrap(), Integer(0))
  assert_eq(read_num(b"+17 ").unwrap(), Integer(17))
}

///|
test "real_numbers" {
  assert_eq(read_num(b"-.002 ").unwrap(), Real(-0.002))
  assert_eq(read_num(b"34.5 ").unwrap(), Real(34.5))
  assert_eq(read_num(b"-3.62 ").unwrap(), Real(-3.62))
  assert_eq(read_num(b"123.6e10 ").unwrap(), Real(123.6e10))
  assert_eq(read_num(b"1.0E-5 ").unwrap(), Real(1.0E-5))
  assert_eq(read_num(b"1E6 ").unwrap(), Real(1.0E6))
  assert_eq(read_num(b"-1. ").unwrap(), Real(-1.0))
  assert_eq(read_num(b"0.0 ").unwrap(), Real(0.0))
}

///|
test "radix_numbers" {
  assert_eq(read_num(b"8#1777 ").unwrap(), Integer(0o1777))
  assert_eq(read_num(b"16#FFFE ").unwrap(), Integer(0xFFFE))
  assert_eq(read_num(b"2#1000 ").unwrap(), Integer(0b1000))
}

///|
test "invalid numbers" {
  assert_true(read_num(b"abc") is Err(_))
  assert_true(read_num(b"+abc") is Err(_))
  assert_true(read_num(b"1a") is Err(_))
}

///|
test "number edge cases" {
  // Rust's `str::parse` rejects these.
  assert_true(read_num(b". ") is Err(_))
  assert_true(read_num(b"1e ") is Err(_))
  assert_true(read_num(b"1e+ ") is Err(_))
  assert_true(read_num(b"2147483648 ") is Err(_))
  assert_eq(read_num(b"-2147483648 ").unwrap(), Integer(-2147483648))
  assert_true(read_num(b"16#FFFFFFFF ") is Err(_))
  assert_true(read_num(b"37#1 ") is Err(_))
  assert_true(read_num(b"8#8 ") is Err(_))
  assert_eq(read_num(b"1e40 ").unwrap(), Real(Float::from_double(1.0e40)))
  assert_eq(read_num(b"1e400 ").unwrap(), Real(Float::from_double(1.0e400)))
  assert_eq(read_num(b"-1e-400 ").unwrap(), Real(-0.0))
  assert_eq(Real(3.9e9).as_i32(), 2147483647)
  assert_eq(Real(-2.5).as_i32(), -2)
}

// object.rs

///|
fn read_one(input : Bytes) -> Result[Object, PsError] {
  read_object(Reader::new(input))
}

///|
test "object integer" {
  assert_eq(read_one(b"42 ").unwrap(), Number(Integer(42)))
}

///|
test "object negative_integer" {
  assert_eq(read_one(b"-7 ").unwrap(), Number(Integer(-7)))
}

///|
test "object literal_name" {
  assert_eq(
    read_one(b"/CMapName ").unwrap(),
    Name(Name::new(b"CMapName", true)),
  )
}

///|
test "object executable_name" {
  assert_eq(
    read_one(b"beginbfchar ").unwrap(),
    Name(Name::new(b"beginbfchar", false)),
  )
}

///|
test "object literal_string" {
  assert_eq(
    read_one(b"(Hello)").unwrap(),
    String(PsString::from_literal(b"Hello")),
  )
}

///|
test "object hex_string" {
  assert_eq(
    read_one(b"<48656C6C6F>").unwrap(),
    String(PsString::from_hex(b"48656C6C6F")),
  )
}

///|
test "object ascii85_string" {
  assert_eq(
    read_one(b"<~87cURDZ~>").unwrap(),
    String(PsString::from_ascii85(b"87cURDZ")),
  )
}

///|
test "object array_simple" {
  assert_eq(read_one(b"[1 2 3]").unwrap(), Array(PsArray::new(b"1 2 3")))
}

///|
test "object stray_close_bracket" {
  assert_eq(read_one(b"]").unwrap_err(), SyntaxError)
}

///|
test "object stray_gt" {
  assert_eq(read_one(b">x").unwrap_err(), SyntaxError)
}

///|
test "object skips_whitespace" {
  assert_eq(read_one(b"  \t\n 42 ").unwrap(), Number(Integer(42)))
}

///|
test "object skips_comments" {
  assert_eq(read_one(b"% this is a comment\n42 ").unwrap(), Number(Integer(42)))
}

///|
test "object eof" {
  assert_true(read_one(b"") is Err(_))
  assert_true(read_one(b"   ") is Err(_))
  assert_true(read_one(b"% comment only\n") is Err(_))
}

///|
test "object procedure unsupported" {
  assert_eq(read_one(b"{ 1 }").unwrap_err(), UnsupportedType)
  assert_eq(read_one(b"<< /A 1 >>").unwrap(), Name(Name::new(b"A", true)))
}

// string.rs

///|
fn decode_literal(input : Bytes) -> Result[Bytes, PsError] {
  let r = Reader::new(input)
  guard parse_literal(r) is Some(data) else { return Err(SyntaxError) }
  PsString::from_literal(data).decode()
}

///|
test "literal strings" {
  assert_eq(decode_literal(b"()").unwrap(), b"")
  assert_eq(decode_literal(b"(Hello)").unwrap(), b"Hello")
  assert_eq(decode_literal(b"(Hi (()) there)").unwrap(), b"Hi (()) there")
  assert_eq(decode_literal(b"(a\\nb)").unwrap(), b"a\nb")
  assert_eq(decode_literal(b"(a\\rb)").unwrap(), b"a\rb")
  assert_eq(decode_literal(b"(a\\tb)").unwrap(), b"a\tb")
  assert_eq(decode_literal(b"(a\\bb)").unwrap(), b"a\x08b")
  assert_eq(decode_literal(b"(a\\fb)").unwrap(), b"a\x0Cb")
  assert_eq(decode_literal(b"(a\\\\b)").unwrap(), b"a\\b")
  assert_eq(decode_literal(b"(Hi \\()").unwrap(), b"Hi (")
  assert_eq(decode_literal(b"(\\053)").unwrap(), b"+")
  assert_eq(decode_literal(b"(\\36)").unwrap(), b"\x1e")
  assert_eq(decode_literal(b"(\\3)").unwrap(), b"\x03")
  assert_eq(decode_literal(b"(Hi \\\nthere)").unwrap(), b"Hi there")
  assert_eq(decode_literal(b"(Hi \\\rthere)").unwrap(), b"Hi there")
  assert_eq(decode_literal(b"(Hi \\\r\nthere)").unwrap(), b"Hi there")
  assert_eq(decode_literal(b"(a\nb)").unwrap(), b"a\nb")
  assert_eq(decode_literal(b"(a\rb)").unwrap(), b"a\nb")
  assert_eq(decode_literal(b"(a\r\nb)").unwrap(), b"a\nb")
  // `u8::from_str_radix` fails for values above 255.
  assert_eq(decode_literal(b"(a\\777b)").unwrap(), b"ab")
}

///|
fn decode_hex(input : Bytes) -> Result[Bytes, PsError] {
  let r = Reader::new(input)
  guard parse_hex(r) is Some(data) else { return Err(SyntaxError) }
  PsString::from_hex(data).decode()
}

///|
test "hex strings" {
  assert_eq(decode_hex(b"<48656C6C6F>").unwrap(), b"Hello")
  assert_eq(decode_hex(b"<48 65 6C 6C 6F>").unwrap(), b"Hello")
  assert_eq(decode_hex(b"<ABC>").unwrap(), b"\xAB\xC0")
  assert_eq(decode_hex(b"<>").unwrap(), b"")
  assert_eq(decode_hex(b"<abcd>").unwrap(), b"\xAB\xCD")
  assert_eq(decode_hex(b"<aB3E>").unwrap(), b"\xAB\x3E")
  assert_true(decode_hex(b"<aG>") is Err(_))
  assert_eq(decode_hex(b"<a b c>").unwrap(), b"\xAB\xC0")
}

///|
fn decode_a85(input : Bytes) -> Result[Bytes, PsError] {
  let r = Reader::new(input)
  guard parse_ascii85(r) is Some(data) else { return Err(SyntaxError) }
  PsString::from_ascii85(data).decode()
}

///|
test "ascii85 strings" {
  // "Hello" in ASCII85 is "87cURDZ"
  assert_eq(decode_a85(b"<~87cURDZ~>").unwrap(), b"Hello")
  assert_eq(decode_a85(b"<~~>").unwrap(), b"")
  assert_eq(decode_a85(b"<~z~>").unwrap(), b"\x00\x00\x00\x00")
  assert_eq(decode_a85(b"<~87~>").unwrap().length(), 1)
  assert_eq(decode_a85(b"<~87cU RDZ~>").unwrap(), b"Hello")
  assert_true(decode_a85(b"<~uuuuu~>") is Err(_))
  assert_true(decode_a85(b"<~8~>") is Err(_))
}

// array.rs

///|
fn parse_array_bytes(input : Bytes) -> Result[BytesView, PsError] {
  parse_array(Reader::new(input))
}

///|
test "arrays" {
  assert_eq(parse_array_bytes(b"[]").unwrap(), b""[:])
  assert_eq(parse_array_bytes(b"[1 2 3]").unwrap(), b"1 2 3"[:])
  assert_eq(parse_array_bytes(b"[1 [2 3] 4]").unwrap(), b"1 [2 3] 4"[:])
  // The ']' inside the string should not close the array.
  assert_eq(parse_array_bytes(b"[1 (str]) 2]").unwrap(), b"1 (str]) 2"[:])
  assert_eq(parse_array_bytes(b"[<48> /name]").unwrap(), b"<48> /name"[:])
  assert_eq(parse_array_bytes(b"[<~87cURDZ~> 1]").unwrap(), b"<~87cURDZ~> 1"[:])
  assert_eq(
    parse_array_bytes(b"[1 % comment with ]\n2]").unwrap(),
    b"1 % comment with ]\n2"[:],
  )
  assert_eq(parse_array_bytes(b"[1 2").unwrap_err(), SyntaxError)
  assert_eq(parse_array_bytes(b"1 2]").unwrap_err(), SyntaxError)
}

// name.rs

///|
fn read_literal_name(input : Bytes) -> Name? {
  parse_literal_name(Reader::new(input)).map(d => Name::new(d, true))
}

///|
fn read_executable_name(input : Bytes) -> Name? {
  parse_executable_name(Reader::new(input)).map(d => Name::new(d, false))
}

///|
test "names" {
  let n = read_literal_name(b"/Name1").unwrap()
  assert_eq(n.as_str().unwrap(), "Name1")
  assert_true(n.is_literal())
  let n = read_literal_name(b"/").unwrap()
  assert_eq(n.as_str().unwrap(), "")
  assert_true(n.is_literal())
  let n = read_literal_name(b"/lime#20Green").unwrap()
  assert_eq(n.as_str().unwrap(), "lime#20Green")
  assert_eq(n.decode().unwrap(), b"lime Green")
  let n = read_literal_name(b"/paired#28#29parentheses").unwrap()
  assert_eq(n.decode().unwrap(), b"paired()parentheses")
  let n = read_literal_name(b"/A;Name_With-Various***Characters?").unwrap()
  assert_eq(n.as_str().unwrap(), "A;Name_With-Various***Characters?")
  let r = Reader::new(b"/Name(rest")
  assert_eq(parse_literal_name(r).unwrap(), b"Name"[:])
  assert_eq(r.peek_byte(), Some(b'('))
  let r = Reader::new(b"/Name rest")
  assert_eq(parse_literal_name(r).unwrap(), b"Name"[:])
  assert_eq(r.peek_byte(), Some(b' '))
  assert_true(read_literal_name(b"Name") is None)
  let n = read_executable_name(b"beginbfchar ").unwrap()
  assert_eq(n.as_str().unwrap(), "beginbfchar")
  assert_true(!n.is_literal())
  let r = Reader::new(b"def/name")
  assert_eq(parse_executable_name(r).unwrap(), b"def"[:])
  assert_eq(r.peek_byte(), Some(b'/'))
  let n = read_executable_name(b"endcmap").unwrap()
  assert_eq(n.as_str().unwrap(), "endcmap")
  assert_true(read_executable_name(b"") is None)
  assert_true(read_executable_name(b"(foo)") is None)
  assert_eq(Name::new(b"simple", true).decode().unwrap(), b"simple")
  assert_eq(Name::new(b"lime#20Green", true).decode().unwrap(), b"lime Green")
  assert_true(Name::new(b"bad#2", true).decode() is Err(_))
  assert_true(Name::new(b"\xff", true).as_str() is None)
}
