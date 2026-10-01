// `toml_edit::parser::trivia`.

///|
/// `wschar = ( %x20 / %x09 )`
fn is_wschar(b : Int) -> Bool {
  b == ' ' || b == '\t'
}

///|
/// `non-ascii = %x80-D7FF / %xE000-10FFFF` (as bytes: `0x80..=0xff`)
fn is_non_ascii(b : Int) -> Bool {
  b >= 0x80 && b <= 0xff
}

///|
/// `non-eol = %x09 / %x20-7E / non-ascii`
fn is_non_eol(b : Int) -> Bool {
  b == 0x09 || (b >= 0x20 && b <= 0x7E) || is_non_ascii(b)
}

///|
/// `ws = *wschar`
fn ws(i : Input) -> Unit {
  ignore(take_while0(i, is_wschar))
}

///|
/// `comment = comment-start-symbol *non-eol`
fn comment(i : Input) -> Unit raise ErrMode {
  byte(i, '#')
  ignore(take_while0(i, is_non_eol))
}

///|
/// `newline = ( %x0A / %x0D.0A )`
fn newline(i : Input) -> Unit raise ErrMode {
  match any(i) {
    '\n' => ()
    '\r' => byte(i, '\n')
    _ => raise backtrack()
  }
}

///|
/// `ws-newline = *( wschar / newline )`
fn ws_newline(i : Input) -> Unit raise ErrMode {
  repeat0(i, i => alt(i, [newline, i => ignore(take_while1(i, is_wschar))]))
}

///|
/// `ws-newlines = newline *( wschar / newline )`
fn ws_newlines(i : Input) -> Unit raise ErrMode {
  newline(i)
  ws_newline(i)
}

///|
/// `ws-comment-newline = *( ws-newline-nonempty / comment )`
fn ws_comment_newline(i : Input) -> Unit raise ErrMode {
  let mut start = i.pos
  for ;; {
    ws(i)
    match i.byte_at(0) {
      '#' => {
        comment(i)
        newline(i)
      }
      '\n' | '\r' => newline(i)
      _ => break
    }
    let end = i.pos
    if start == end {
      break
    }
    start = end
  }
}

///|
/// `line-ending = newline / eof`
fn line_ending(i : Input) -> Unit raise ErrMode {
  alt(i, [newline, eof])
}

///|
/// `line-trailing = ws [comment] skip-line-ending`
fn line_trailing(i : Input) -> Unit raise ErrMode {
  ws(i)
  ignore(opt(i, comment))
  line_ending(i)
}
