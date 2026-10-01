// `toml_edit::parser::key`.

///|
/// `RecursionCheck`'s limit (feature `unbounded` is off).
let recursion_limit : Int = 80

///|
/// `key = simple-key / dotted-key`,
/// `dotted-key = simple-key 1*( dot-sep simple-key )`
fn key(i : Input) -> Array[String] raise ErrMode {
  let start = i.pos
  let keys = context(
    i,
    i => {
      separated1(
        i,
        i => {
          ws(i)
          let k = simple_key(i)
          ws(i)
          k
        },
        i => byte(i, '.'),
      )
    },
    [Label("key")],
  )
  // Inserting the key will require recursion down the line
  if recursion_limit <= keys.length() {
    raise map_failure(i, start, Some(recursion_limit_exceeded))
  }
  keys
}

///|
/// `simple-key = quoted-key / unquoted-key`,
/// `quoted-key = basic-string / literal-string`
fn simple_key(i : Input) -> String raise ErrMode {
  match peek_any(i) {
    '"' => basic_string(i)
    '\'' => literal_string(i)
    _ => unquoted_key(i)
  }
}

///|
/// `unquoted-key = 1*( ALPHA / DIGIT / %x2D / %x5F )`
fn unquoted_key(i : Input) -> String raise ErrMode {
  let start = take_while1(i, is_unquoted_char)
  i.slice(start, i.pos)
}

///|
/// `is_unquoted_char`: `A-Z / a-z / 0-9 / - / _`
fn is_unquoted_char(b : Int) -> Bool {
  (b >= 'A' && b <= 'Z') ||
  (b >= 'a' && b <= 'z') ||
  is_digit(b) ||
  b == '-' ||
  b == '_'
}
