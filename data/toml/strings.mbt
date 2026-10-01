// `toml_edit::parser::strings`.

///|
/// `string = ml-basic-string / basic-string / ml-literal-string / literal-string`
fn string(i : Input) -> String raise ErrMode {
  alt(i, [ml_basic_string, basic_string, ml_literal_string, literal_string])
}

///|
/// `basic-string = quotation-mark *basic-char quotation-mark`
fn basic_string(i : Input) -> String raise ErrMode {
  byte(i, '"')
  let buf = StringBuilder()
  while opt(i, basic_chars) is Some(s) {
    buf.write_string(s)
  }
  context(i, i => cut_err(i, i => byte(i, '"')), [Label("basic string")])
  buf.to_string()
}

///|
/// `basic-unescaped = wschar / %x21 / %x23-5B / %x5D-7E / non-ascii`
/// (also `mlb-unescaped`)
fn is_basic_unescaped(b : Int) -> Bool {
  is_wschar(b) ||
  b == 0x21 ||
  (b >= 0x23 && b <= 0x5B) ||
  (b >= 0x5D && b <= 0x7E) ||
  is_non_ascii(b)
}

///|
/// `basic-char = basic-unescaped / escaped`
fn basic_chars(i : Input) -> String raise ErrMode {
  alt(i, [
    i => {
      let start = take_while1(i, is_basic_unescaped)
      i.slice(start, i.pos)
    },
    i => escaped(i).to_string(),
  ])
}

///|
/// `escaped = escape escape-seq-char`
fn escaped(i : Input) -> Char raise ErrMode {
  byte(i, '\\')
  escape_seq_char(i)
}

///|
/// `escape-seq-char`
fn escape_seq_char(i : Input) -> Char raise ErrMode {
  match any(i) {
    'b' => '\u{8}'
    'f' => '\u{c}'
    'n' => '\n'
    'r' => '\r'
    't' => '\t'
    'u' =>
      context(i, i => cut_err(i, i => hexescape(i, 4)), [
        Label("unicode 4-digit hex code"),
      ])
    'U' =>
      context(i, i => cut_err(i, i => hexescape(i, 8)), [
        Label("unicode 8-digit hex code"),
      ])
    '\\' => '\\'
    '"' => '"'
    _ =>
      context(i, i => cut_err(i, _ => raise backtrack()), [
        Label("escape sequence"),
        Expected(CharLiteral('b')),
        Expected(CharLiteral('f')),
        Expected(CharLiteral('n')),
        Expected(CharLiteral('r')),
        Expected(CharLiteral('t')),
        Expected(CharLiteral('u')),
        Expected(CharLiteral('U')),
        Expected(CharLiteral('\\')),
        Expected(CharLiteral('"')),
      ])
  }
}

///|
/// `HEXDIG = DIGIT / "A" / "B" / "C" / "D" / "E" / "F"` (either case)
fn is_hexdig(b : Int) -> Bool {
  is_digit(b) || (b >= 'A' && b <= 'F') || (b >= 'a' && b <= 'f')
}

///|
fn hex_value(b : Int) -> Int {
  if is_digit(b) {
    b - '0'
  } else if b >= 'a' {
    b - 'a' + 10
  } else {
    b - 'A' + 10
  }
}

///|
/// `hexescape::<N>`
fn hexescape(i : Input, n : Int) -> Char raise ErrMode {
  let start = take_while_m_n(i, 0, n, is_hexdig)
  if i.pos - start != n {
    raise map_failure(i, start, None)
  }
  let mut h = 0U
  for k in start..<i.pos {
    h = h * 16 + hex_value(i.bytes[k].to_int()).reinterpret_as_uint()
  }
  if h > 0x10FFFF || (h >= 0xD800 && h <= 0xDFFF) {
    raise map_failure(i, start, Some(out_of_range))
  }
  h.reinterpret_as_int().unsafe_to_char()
}

///|
/// `ml-basic-string = ml-basic-string-delim [ newline ] ml-basic-body
///                    ml-basic-string-delim`
fn ml_basic_string(i : Input) -> String raise ErrMode {
  literal(i, "\"\"\"")
  let body = context(
    i,
    i => {
      ignore(opt(i, newline))
      cut_err(i, ml_basic_body)
    },
    [Label("multiline basic string")],
  )
  context(i, i => cut_err(i, i => literal(i, "\"\"\"")), [
    Label("multiline basic string"),
  ])
  body
}

///|
/// `ml-basic-body = *mlb-content *( mlb-quotes 1*mlb-content ) [ mlb-quotes ]`
fn ml_basic_body(i : Input) -> String raise ErrMode {
  let c = StringBuilder()
  while opt(i, mlb_content) is Some(ci) {
    c.write_string(ci)
  }
  while opt(i, i => mlb_quotes(i, '"', i => ignore(none_of_quote(i, '"'))))
        is Some(qi) {
    if opt(i, mlb_content) is Some(ci) {
      c.write_string(qi)
      c.write_string(ci)
      while opt(i, mlb_content) is Some(ci) {
        c.write_string(ci)
      }
    } else {
      break
    }
  }
  if opt(i, i => mlb_quotes(i, '"', i => literal(i, "\"\"\""))) is Some(qi) {
    c.write_string(qi)
  }
  c.to_string()
}

///|
/// `none_of(q)`.
fn none_of_quote(i : Input, q : Int) -> Int raise ErrMode {
  one_of(i, b => b != q)
}

///|
/// `mlb-content = mlb-char / newline / mlb-escaped-nl`
fn mlb_content(i : Input) -> String raise ErrMode {
  alt(i, [
    i => {
      let start = take_while1(i, is_basic_unescaped)
      i.slice(start, i.pos)
    },
    i => {
      mlb_escaped_nl(i)
      ""
    },
    i => escaped(i).to_string(),
    i => {
      newline(i)
      "\n"
    },
  ])
}

///|
/// `mlb-quotes = 1*2quotation-mark` / `mll-quotes = 1*2apostrophe`: two quotes
/// then one, each followed by `term`.
fn mlb_quotes(
  i : Input,
  q : Int,
  term : (Input) -> Unit raise ErrMode,
) -> String raise ErrMode {
  let start = i.pos
  let quote = q.unsafe_to_char().to_string()
  try {
    byte(i, q)
    byte(i, q)
    peek(i, term)
    quote + quote
  } catch {
    Backtrack(_) => {
      i.pos = start
      byte(i, q)
      peek(i, term)
      quote
    }
    e => raise e
  }
}

///|
/// `mlb-escaped-nl = escape ws newline *( wschar / newline )`
fn mlb_escaped_nl(i : Input) -> Unit raise ErrMode {
  repeat1(i, i => {
    byte(i, '\\')
    ws(i)
    ws_newlines(i)
  })
}

///|
/// `literal-char = %x09 / %x20-26 / %x28-7E / non-ascii` (also `mll-char`)
fn is_literal_char(b : Int) -> Bool {
  b == 0x09 ||
  (b >= 0x20 && b <= 0x26) ||
  (b >= 0x28 && b <= 0x7E) ||
  is_non_ascii(b)
}

///|
/// `literal-string = apostrophe *literal-char apostrophe`
fn literal_string(i : Input) -> String raise ErrMode {
  context(
    i,
    i => {
      byte(i, '\'')
      let start = take_while0(i, is_literal_char)
      let end = i.pos
      cut_err(i, i => byte(i, '\''))
      i.slice(start, end)
    },
    [Label("literal string")],
  )
}

///|
/// `ml-literal-string = ml-literal-string-delim [ newline ] ml-literal-body
///                      ml-literal-string-delim`
fn ml_literal_string(i : Input) -> String raise ErrMode {
  literal(i, "'''")
  ignore(opt(i, newline))
  let body = context(
    i,
    i => {
      cut_err(i, i => {
        let t = ml_literal_body(i)
        t.replace_all(old="\r\n", new="\n")
      })
    },
    [Label("multiline literal string")],
  )
  context(i, i => cut_err(i, i => literal(i, "'''")), [
    Label("multiline literal string"),
  ])
  body
}

///|
/// `ml-literal-body = *mll-content *( mll-quotes 1*mll-content ) [ mll-quotes ]`
fn ml_literal_body(i : Input) -> String raise ErrMode {
  let start = i.pos
  repeat0(i, mll_content)
  repeat0(i, i => {
    ignore(mlb_quotes(i, '\'', i => ignore(none_of_quote(i, '\''))))
    repeat1(i, mll_content)
  })
  ignore(opt(i, i => mlb_quotes(i, '\'', i => literal(i, "'''"))))
  i.slice(start, i.pos)
}

///|
/// `mll-content = mll-char / newline`
fn mll_content(i : Input) -> Unit raise ErrMode {
  alt(i, [i => ignore(one_of(i, is_literal_char)), newline])
}
