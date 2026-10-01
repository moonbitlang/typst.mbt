// `toml_edit::parser::{document, table}` and `parse_document`.

///|
/// `table = std-table / array-table`
fn table(i : Input, state : ParseState) -> Unit raise ErrMode {
  context(
    i,
    i => {
      if i.starts_with("[[") {
        array_table(i, state)
      } else {
        std_table(i, state)
      }
    },
    [Label("table header")],
  )
}

///|
/// `std-table = std-table-open key *( table-key-sep key) std-table-close`
fn std_table(i : Input, state : ParseState) -> Unit raise ErrMode {
  let start = i.pos
  byte(i, '[')
  let path = cut_err(i, key)
  context(i, i => cut_err(i, i => byte(i, ']')), [
    Expected(CharLiteral('.')),
    Expected(StringLiteral("]")),
  ])
  context(i, i => cut_err(i, line_trailing), [
    Expected(CharLiteral('\n')),
    Expected(CharLiteral('#')),
  ])
  match state.on_std_header(path) {
    Ok(_) => ()
    Err(cause) => raise map_failure(i, start, Some(cause))
  }
}

///|
/// `array-table = array-table-open key *( table-key-sep key) array-table-close`
fn array_table(i : Input, state : ParseState) -> Unit raise ErrMode {
  let start = i.pos
  literal(i, "[[")
  let path = cut_err(i, key)
  context(i, i => cut_err(i, i => literal(i, "]]")), [
    Expected(CharLiteral('.')),
    Expected(StringLiteral("]]")),
  ])
  context(i, i => cut_err(i, line_trailing), [
    Expected(CharLiteral('\n')),
    Expected(CharLiteral('#')),
  ])
  match state.on_array_header(path) {
    Ok(_) => ()
    Err(cause) => raise map_failure(i, start, Some(cause))
  }
}

///|
/// `document`:
/// `toml = expression *( newline expression )`,
/// `expression = ( ws comment ) / ( ws keyval ws [ comment ] ) /
///               ( ws table ws [ comment ] ) / ws`
fn document(i : Input, state : ParseState) -> Unit raise ErrMode {
  // Remove BOM if present
  if i.byte_at(0) == 0xEF && i.byte_at(1) == 0xBB && i.byte_at(2) == 0xBF {
    i.pos += 3
  }
  ws(i)
  repeat0(i, i => {
    match peek_any(i) {
      '#' =>
        cut_err(i, i => {
          comment(i)
          line_ending(i)
        })
      '[' => cut_err(i, i => table(i, state))
      '\n' | '\r' => newline(i)
      _ => cut_err(i, i => keyval(i, state))
    }
    ws(i)
  })
  eof(i)
}

///|
/// `keyval` of `document`: `parse_keyval.try_map(|(p, kv)| state.on_keyval(p, kv))`
fn keyval(i : Input, state : ParseState) -> Unit raise ErrMode {
  let start = i.pos
  let (path, k, v) = parse_keyval(i)
  match state.on_keyval(path, k, v) {
    Ok(_) => ()
    Err(cause) => raise map_failure(i, start, Some(cause))
  }
}

///|
/// `keyval = key keyval-sep val`
fn parse_keyval(i : Input) -> (Array[String], String, TValue) raise ErrMode {
  let path = key(i)
  let v = cut_err(i, i => {
    context(i, i => byte(i, '='), [
      Expected(CharLiteral('.')),
      Expected(CharLiteral('=')),
    ])
    ws(i)
    let v = value(i)
    context(i, line_trailing, [
      Expected(CharLiteral('\n')),
      Expected(CharLiteral('#')),
    ])
    v
  })
  let k = path.pop().unwrap()
  (path, k, v)
}

///|
/// `parse_document`: parses the document into its root table.
fn parse_document(bytes : Bytes) -> Table raise TomlError {
  let i = Input::new(bytes)
  let state = ParseState::new()
  try {
    document(i, state)
    // `Parser::parse` checks for `eof` once more.
    eof(i)
  } catch {
    e => raise toml_error_at(bytes, i.pos, e.inner())
  }
  state.into_document()
}
