// `toml_edit::parser::{value, array, inline_table}`.

///|
/// The contexts `value` attaches to the string-like dispatch arms.
fn string_expected() -> Array[StrContext] {
  [Label("string"), Expected(CharLiteral('"')), Expected(CharLiteral('\''))]
}

///|
/// `val = string / boolean / array / inline-table / date-time / float / integer`
fn value(i : Input) -> TValue raise ErrMode {
  match peek_any(i) {
    '"' | '\'' => VString(string(i))
    '[' => VArray(check_recursion(i, array))
    '{' => VInlineTable(check_recursion(i, inline_table))
    // Date/number starts
    '+' | '-' | '0'..='9' =>
      alt(i, [
        i => VDatetime(date_time(i)),
        i => VFloat(float(i)),
        i => VInteger(integer(i)),
      ])
    // Report as if they were numbers because its most likely a typo
    '_' =>
      context(i, i => VInteger(integer(i)), [
        Expected(Description("leading digit")),
      ])
    // Report as if they were numbers because its most likely a typo
    '.' =>
      context(i, i => VFloat(float(i)), [Expected(Description("leading digit"))])
    't' => context(i, i => VBoolean(true_(i)), string_expected())
    'f' => context(i, i => VBoolean(false_(i)), string_expected())
    'i' => context(i, i => VFloat(inf(i)), string_expected())
    'n' => context(i, i => VFloat(nan(i)), string_expected())
    _ => context(i, _ => raise backtrack(), string_expected())
  }
}

///|
/// `check_recursion(parser)`.
fn[T] check_recursion(
  i : Input,
  p : (Input) -> T raise ErrMode,
) -> T raise ErrMode {
  i.depth += 1
  if recursion_limit <= i.depth {
    raise Cut(ContextError::external(recursion_limit_exceeded))
  }
  defer {
    i.depth -= 1
  }
  p(i)
}

///|
/// `array = array-open array-values array-close`
fn array(i : Input) -> Array[TValue] raise ErrMode {
  byte(i, '[')
  let values = cut_err(i, array_values)
  context(i, i => cut_err(i, i => byte(i, ']')), [
    Label("array"),
    Expected(CharLiteral(']')),
  ])
  values
}

///|
/// `array-values = ws-comment-newline val ws-comment-newline array-sep
/// array-values / ws-comment-newline val ws-comment-newline [ array-sep ]`
fn array_values(i : Input) -> Array[TValue] raise ErrMode {
  if i.byte_at(0) == ']' {
    // Optimize for empty arrays, avoiding `value` from being expected to fail
    return []
  }
  let array = separated0(i, array_value, i => byte(i, ','))
  if !array.is_empty() {
    ignore(opt(i, i => byte(i, ',')))
  }
  ws_comment_newline(i)
  array
}

///|
/// `array_value`: `ws-comment-newline val ws-comment-newline`
fn array_value(i : Input) -> TValue raise ErrMode {
  ws_comment_newline(i)
  let v = value(i)
  ws_comment_newline(i)
  v
}

///|
/// `inline-table = inline-table-open inline-table-keyvals inline-table-close`
fn inline_table(i : Input) -> InlineTable raise ErrMode {
  byte(i, '{')
  let table = cut_err(i, i => {
    let start = i.pos
    let kv = inline_table_keyvals(i)
    match table_from_pairs(kv) {
      Ok(t) => t
      Err(cause) => raise map_failure(i, start, Some(cause))
    }
  })
  context(i, i => cut_err(i, i => byte(i, '}')), [
    Label("inline table"),
    Expected(CharLiteral('}')),
  ])
  table
}

///|
/// `table_from_pairs`
fn table_from_pairs(
  v : Array[(Array[String], String, TValue)],
) -> Result[InlineTable, String] {
  let root = InlineTable::new()
  for kv in v {
    let (path, key, value) = kv
    let table = match descend_inline_path(root, path) {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    // "Likewise, using dotted keys to redefine tables already defined in
    // [table] form is not allowed"
    let mixed_table_types = table.dotted == path.is_empty()
    if mixed_table_types {
      return Err(duplicate_key_error(key, None))
    }
    if table.items.contains(key) {
      return Err(duplicate_key_error(key, None))
    }
    table.items[key] = value
  }
  Ok(root)
}

///|
/// `inline_table::descend_path`
fn descend_inline_path(
  table : InlineTable,
  path : Array[String],
) -> Result[InlineTable, String] {
  let dotted = !path.is_empty()
  let mut table = table
  for i, key in path {
    let entry = match table.items.get(key) {
      Some(e) => e
      None => {
        let new_table = InlineTable::new()
        new_table.implicit = dotted
        new_table.dotted = dotted
        let e = VInlineTable(new_table)
        table.items[key] = e
        e
      }
    }
    match entry {
      VInlineTable(child) => {
        // Since tables cannot be defined more than once, redefining such
        // tables using a [table] header is not allowed. Likewise, using
        // dotted keys to redefine tables already defined in [table] form is
        // not allowed.
        if dotted && !child.implicit {
          return Err(duplicate_key_error(key, None))
        }
        table = child
      }
      v => return Err(extend_wrong_type(path, i, v.type_name()))
    }
  }
  Ok(table)
}

///|
/// `inline-table-keyvals = [ inline-table-keyvals-non-empty ]`
fn inline_table_keyvals(
  i : Input,
) -> Array[(Array[String], String, TValue)] raise ErrMode {
  let kvs = separated0(i, inline_keyval, i => byte(i, ','))
  ws(i)
  kvs
}

///|
/// `keyval` of `inline_table`: `key keyval-sep val` with surrounding `ws`.
fn inline_keyval(i : Input) -> (Array[String], String, TValue) raise ErrMode {
  let path = key(i)
  let v = cut_err(i, i => {
    context(i, i => byte(i, '='), [
      Expected(CharLiteral('.')),
      Expected(CharLiteral('=')),
    ])
    ws(i)
    let v = value(i)
    ws(i)
    v
  })
  let k = path.pop().unwrap()
  (path, k, v)
}
