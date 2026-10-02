// Port of `hayro-postscript/src/reader.rs`.

///|
priv struct Reader {
  data : BytesView
  mut offset : Int
}

///|
fn Reader::new(data : BytesView) -> Reader {
  { data, offset: 0, }
}

///|
fn Reader::clone(self : Reader) -> Reader {
  { data: self.data, offset: self.offset, }
}

///|
fn Reader::jump(self : Reader, offset : Int) -> Unit {
  self.offset = offset
}

///|
/// `data.get(start..end)`.
fn Reader::range(self : Reader, start : Int, end : Int) -> BytesView? {
  if start >= 0 && start <= end && end <= self.data.length() {
    Some(self.data[start:end])
  } else {
    None
  }
}

///|
fn Reader::offset(self : Reader) -> Int {
  self.offset
}

///|
fn Reader::read_bytes(self : Reader, len : Int) -> BytesView? {
  guard self.peek_bytes(len) is Some(v) else { return None }
  self.offset += len
  Some(v)
}

///|
fn Reader::read_byte(self : Reader) -> Byte? {
  guard self.peek_byte() is Some(v) else { return None }
  self.offset += 1
  Some(v)
}

///|
fn Reader::peek_bytes(self : Reader, len : Int) -> BytesView? {
  self.range(self.offset, self.offset + len)
}

///|
fn Reader::peek_byte(self : Reader) -> Byte? {
  if self.offset >= 0 && self.offset < self.data.length() {
    Some(self.data[self.offset])
  } else {
    None
  }
}

///|
fn Reader::eat(self : Reader, f : (Byte) -> Bool) -> Byte? {
  guard self.peek_byte() is Some(val) else { return None }
  if f(val) {
    self.forward()
    Some(val)
  } else {
    None
  }
}

///|
fn Reader::forward(self : Reader) -> Unit {
  self.offset += 1
}

///|
fn Reader::forward_while(self : Reader, f : (Byte) -> Bool) -> Unit {
  while self.peek_byte() is Some(b) {
    if f(b) {
      self.forward()
    } else {
      break
    }
  }
}

///|
fn Reader::forward_tag(self : Reader, tag : Bytes) -> Unit? {
  guard self.peek_tag(tag) is Some(_) else { return None }
  self.offset += tag.length()
  Some(())
}

///|
fn Reader::peek_tag(self : Reader, tag : Bytes) -> Unit? {
  let cloned = self.clone()
  for b in tag {
    if cloned.peek_byte() == Some(b) {
      cloned.forward()
    } else {
      return None
    }
  }
  Some(())
}

///|
fn Reader::skip_eol(self : Reader) -> Unit {
  while self.peek_byte() is Some(b) {
    if is_eol(b) {
      self.forward()
    } else {
      return
    }
  }
}

///|
fn is_whitespace(b : Byte) -> Bool {
  b is (b'\x00' | b'\x09' | b'\x0a' | b'\x0c' | b'\x0d' | b'\x20')
}

///|
fn is_delimiter(b : Byte) -> Bool {
  b is (b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'{' | b'}' | b'/' | b'%')
}

///|
fn is_regular(b : Byte) -> Bool {
  !is_whitespace(b) && !is_delimiter(b)
}

///|
fn is_eol(b : Byte) -> Bool {
  b is (b'\x0a' | b'\x0d')
}
