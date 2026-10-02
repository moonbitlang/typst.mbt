// Port of `fancy-regex` 0.16.2 `src/expand.rs`.

///|
/// A set of options for expanding a template string using the contents of
/// capture groups.
pub struct Expander {
  sub_char : Char
  open : String
  close : String
  allow_undelimited_name : Bool
} derive(Debug)

///|
/// Returns the default expander used by `Captures::expand`.
///
/// To write a literal `$` use `$$`.
pub fn Expander::default() -> Expander {
  { sub_char: '$', open: "{", close: "}", allow_undelimited_name: true }
}

///|
/// Returns an expander that uses Python-compatible syntax.
///
/// Expands all instances of `\num` or `\g<name>` in `replacement` to the
/// corresponding capture group `num` or `name`.
///
/// To write a literal `\` use `\\`.
pub fn Expander::python() -> Expander {
  { sub_char: '\\', open: "g<", close: ">", allow_undelimited_name: false }
}

///|
priv enum Step {
  Char(Char)
  GroupName(String)
  GroupNum(Int)
  Error
}

///|
/// Checks `template` for errors. The following conditions are checked for:
///
/// - A reference to a numbered group that does not exist in `regex`
/// - A reference to a numbered group (other than 0) when `regex` contains
///   named groups
/// - A reference to a named group that does not occur in `regex`
/// - An opening group name delimiter without a closing delimiter
/// - Using an empty string as a group name
pub fn Expander::check(
  self : Expander,
  template : String,
  regex : Regex,
) -> Unit raise FancyError {
  let on_group_num = (num : Int) => if num == 0 {
    ()
  } else if !regex.named_groups.is_empty() {
    raise FancyError::CompileError(NamedBackrefOnly)
  } else if num < regex.captures_len() {
    ()
  } else {
    raise FancyError::CompileError(InvalidBackref(num))
  }
  self.exec(template, step => match step {
    Char(_) => ()
    GroupName(name) =>
      if regex.named_groups.contains(name) {
        ()
      } else if parse_usize(name) is Some(num) {
        on_group_num(num)
      } else {
        raise FancyError::CompileError(InvalidGroupNameBackref(name))
      }
    GroupNum(num) => on_group_num(num)
    Error =>
      raise FancyError::ParseError(
        0,
        GeneralParseError("parse error in template while expanding"),
      )
  })
}

///|
/// Escapes the substitution character in `text` so it appears literally in
/// the output of `expansion`.
pub fn Expander::escape(self : Expander, text : String) -> String {
  if text.contains_char(self.sub_char) {
    let quoted = "\{self.sub_char}\{self.sub_char}"
    text.replace_all(old=self.sub_char.to_string(), new=quoted)
  } else {
    text
  }
}

///|
/// Expands the template string `template` using the syntax defined by this
/// expander and the values of capture groups from `captures`.
pub fn Expander::expansion(
  self : Expander,
  template : String,
  captures : Captures,
) -> String {
  let buf = StringBuilder()
  self.append_expansion(buf, template, captures)
  buf.to_string()
}

///|
/// Appends the expansion produced by `expansion` to `dst`.
pub fn Expander::append_expansion(
  self : Expander,
  dst : StringBuilder,
  template : String,
  captures : Captures,
) -> Unit {
  self.exec(template, step => match step {
    Char(c) => dst.write_char(c)
    GroupName(name) =>
      if captures.name(name) is Some(m) {
        dst.write_string(m.as_str())
      } else if parse_usize(name) is Some(num) && captures.get(num) is Some(m) {
        dst.write_string(m.as_str())
      }
    GroupNum(num) =>
      if captures.get(num) is Some(m) {
        dst.write_string(m.as_str())
      }
    Error => ()
  }) catch {
    _ => ()
  }
}

///|
fn Expander::exec(
  self : Expander,
  template : String,
  f : (Step) -> Unit raise FancyError,
) -> Unit raise FancyError {
  let bytes = @utf8.encode(template)
  let mut i = 0
  while i < bytes.length() {
    let (c, n) = decode_utf8(bytes, i)
    let c = Int::unsafe_to_char(c)
    i += n
    if c == self.sub_char {
      let tail = i
      let skip = if i < bytes.length() &&
        decode_utf8(bytes, i).0 == self.sub_char.to_int() {
        f(Char(self.sub_char))
        1
      } else if (match parse_id(bytes, tail, self.open, self.close, false) {
          Some(p) => Some(p)
          None =>
            if self.allow_undelimited_name {
              parse_id(bytes, tail, "", "", false)
            } else {
              None
            }
        })
        is Some({ id, relative: None, skip }) {
        f(GroupName(id))
        skip
      } else if parse_decimal(bytes, tail) is Some((end, num)) {
        f(GroupNum(num))
        end - tail
      } else {
        f(Error)
        f(Char(self.sub_char))
        0
      }
      i = tail + skip
    } else {
      f(Char(c))
    }
  }
}
