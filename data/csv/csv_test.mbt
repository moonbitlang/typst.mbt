// Expected outputs were produced by upstream Typst (csv 1.4.0).

///|
fn read_all(
  data : Bytes,
  delimiter? : Byte = b',',
  headers? : Bool = false,
) -> String {
  let reader = @csv.Reader::new(data, delimiter~, has_headers=headers)
  let out = StringBuilder()
  try {
    if headers {
      out.write_string("headers [\{reader.headers().join(", ")}]\n")
    }
    while reader.read_record() is Some(record) {
      out.write_string("[\{record.join(", ")}]\n")
    }
  } catch {
    @csv.CsvError(kind) => out.write_string("error \{fmt_kind(kind)}\n")
  }
  out.to_string()
}

///|
fn fmt_pos(pos : @csv.Position?) -> String {
  match pos {
    Some(p) => "Some({byte: \{p.byte}, line: \{p.line}, record: \{p.record}})"
    None => "None"
  }
}

///|
fn fmt_kind(kind : @csv.ErrorKind) -> String {
  match kind {
    Utf8(pos~, field~, valid_up_to~) =>
      "Utf8(pos=\{fmt_pos(pos)}, field=\{field}, valid_up_to=\{valid_up_to})"
    UnequalLengths(pos~, expected_len~, len~) =>
      "UnequalLengths(pos=\{fmt_pos(pos)}, expected_len=\{expected_len}, len=\{len})"
  }
}

///|
test "records" {
  inspect(
    read_all(b"a,b\r\n\r\n1,\"x\"\"y\"\n\n\"q\"z,\"multi\nline\"\r\n,\n"),
    content=(
      #|[a, b]
      #|[1, x"y]
      #|[qz, multi
      #|line]
      #|[, ]
      #|
    ),
  )
  inspect(
    read_all(b"\xef\xbb\xbfa;b\n1;2", delimiter=b';'),
    content=(
      #|[a, b]
      #|[1, 2]
      #|
    ),
  )
  inspect(
    read_all(b"\"a\"b,\"c\nd\"\re,f"),
    content=(
      #|[ab, c
      #|d]
      #|[e, f]
      #|
    ),
  )
  inspect(read_all(b""), content="")
  inspect(read_all(b"", headers=true), content="headers []\n")
  inspect(
    read_all(b"a,b\n1,2\n3,4", headers=true),
    content=(
      #|headers [a, b]
      #|[1, 2]
      #|[3, 4]
      #|
    ),
  )
}

///|
test "errors" {
  // The positions point at the start of the record (after the previous
  // record's terminator).
  inspect(
    read_all(b"a,b\r\n1,2,3\n"),
    content=(
      #|[a, b]
      #|error UnequalLengths(pos=Some({byte: 4, line: 1, record: 1}), expected_len=2, len=3)
      #|
    ),
  )
  inspect(
    read_all(b"a,b\n\n\n1,2,3\n", headers=true),
    content=(
      #|headers [a, b]
      #|error UnequalLengths(pos=Some({byte: 4, line: 2, record: 1}), expected_len=2, len=3)
      #|
    ),
  )
  inspect(
    read_all(b"A,B\n1,2\n3,4,5\n6,7\n"),
    content=(
      #|[A, B]
      #|[1, 2]
      #|error UnequalLengths(pos=Some({byte: 8, line: 3, record: 2}), expected_len=2, len=3)
      #|
    ),
  )
  inspect(
    read_all(b"a,\xff\n1,2"),
    content=(
      #|error Utf8(pos=Some({byte: 0, line: 1, record: 0}), field=1, valid_up_to=0)
      #|
    ),
  )
  inspect(
    read_all(b"a,b\n1,\xff", headers=true),
    content=(
      #|headers [a, b]
      #|error Utf8(pos=Some({byte: 4, line: 2, record: 1}), field=1, valid_up_to=0)
      #|
    ),
  )
  inspect(
    read_all(b"a,\xff\n1,2", headers=true),
    content=(
      #|error Utf8(pos=Some({byte: 0, line: 1, record: 0}), field=1, valid_up_to=0)
      #|
    ),
  )
  inspect(
    read_all(b"1,2\n3\n"),
    content=(
      #|[1, 2]
      #|error UnequalLengths(pos=Some({byte: 4, line: 2, record: 1}), expected_len=2, len=1)
      #|
    ),
  )
}
