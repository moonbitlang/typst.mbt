// Port of `hayro-syntax/src/trivia.rs`: comments and white spaces.

///|
pub fn is_white_space_character(char : Byte) -> Bool {
  char is (b'\x00' | b'\t' | b'\n' | b'\x0c' | b'\r' | b' ')
}

///|
pub fn is_regular_character(char : Byte) -> Bool {
  !(is_white_space_character(char) || is_delimiter_character(char))
}

///|
fn is_delimiter_character(char : Byte) -> Bool {
  char is (b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'{' | b'}' | b'/' | b'%')
}

///|
pub fn is_eol_character(char : Byte) -> Bool {
  char is (b'\n' | b'\r')
}

///|
/// Skip a comment (`Comment::skip`).
fn skip_comment(r : Reader) -> Unit? {
  guard r.forward_tag(b"%") is Some(_) else { return None }
  r.forward_while(b => !is_eol_character(b))
  Some(())
}

///|
pub fn Reader::skip_white_spaces(self : Reader) -> Unit {
  while self.peek_byte() is Some(b) {
    if is_white_space_character(b) {
      self.forward()
    } else {
      return
    }
  }
}

///|
pub fn Reader::read_white_space(self : Reader) -> Unit? {
  guard self.peek_byte() is Some(b) else { return None }
  if is_white_space_character(b) {
    guard self.read_byte() is Some(w) else { return None }
    if w == b'\r' && self.peek_byte() is Some(b'\n') {
      guard self.read_byte() is Some(_) else { return None }
    }
    return Some(())
  }
  None
}

///|
pub fn Reader::skip_eol_characters(self : Reader) -> Unit {
  while self.peek_byte() is Some(b) {
    if is_eol_character(b) {
      self.forward()
    } else {
      return
    }
  }
}

///|
pub fn Reader::skip_white_spaces_and_comments(self : Reader) -> Unit {
  while self.peek_byte() is Some(b) {
    if is_white_space_character(b) {
      self.skip_white_spaces()
    } else if b == b'%' {
      skip_comment(self) |> ignore
    } else {
      return
    }
  }
}
