// Port of `unsafe-libyaml` 0.2.11 `reader.rs` for UTF-8 string input.
//
// serde_yaml fixes the encoding to UTF-8, so no BOM detection happens here.
// The raw buffer is modelled as the window `input[raw_pos..raw_last]` of at
// most `INPUT_RAW_BUFFER_SIZE` bytes; decoding a raw chunk validates it and
// makes it available to the scanner. Validation therefore happens chunk by
// chunk exactly like upstream, which determines when reader errors surface.

///|
/// `INPUT_RAW_BUFFER_SIZE`.
const INPUT_RAW_BUFFER_SIZE : Int = 16384

///|
/// `yaml_parser_set_reader_error`.
fn Parser::set_reader_error(
  self : Parser,
  problem : String,
  offset : Int,
) -> Fail {
  self.error = ReaderError
  self.problem = problem
  self.problem_offset = offset
  Fail
}

///|
/// `yaml_parser_update_raw_buffer` with `yaml_string_read_handler`.
fn Parser::update_raw_buffer(self : Parser) -> Unit {
  let len = self.raw_last - self.raw_pos
  if len == INPUT_RAW_BUFFER_SIZE {
    return
  }
  if self.eof {
    return
  }
  let available = self.input.length() - self.raw_last
  let size = INPUT_RAW_BUFFER_SIZE - len
  let size_read = if available < size { available } else { size }
  self.raw_last += size_read
  if size_read == 0 {
    self.eof = true
  }
}

///|
/// `yaml_parser_update_buffer`.
fn Parser::update_buffer(self : Parser, length : Int) -> Unit raise Fail {
  if self.eof && self.raw_pos == self.raw_last {
    return
  }
  if self.unread >= length {
    return
  }
  let mut first = true
  while self.unread < length {
    if !first || self.raw_pos == self.raw_last {
      self.update_raw_buffer()
    }
    first = false
    while self.raw_pos != self.raw_last {
      let raw_unread = self.raw_last - self.raw_pos
      let mut octet = self.input[self.raw_pos].to_int()
      let width = if (octet & 0x80) == 0 {
        1
      } else if (octet & 0xE0) == 0xC0 {
        2
      } else if (octet & 0xF0) == 0xE0 {
        3
      } else if (octet & 0xF8) == 0xF0 {
        4
      } else {
        0
      }
      if width == 0 {
        raise self.set_reader_error("invalid leading UTF-8 octet", self.raw_pos)
      }
      if width > raw_unread {
        if self.eof {
          raise self.set_reader_error(
            "incomplete UTF-8 octet sequence",
            self.raw_pos,
          )
        }
        break
      }
      let mut value = if (octet & 0x80) == 0 {
        octet & 0x7F
      } else if (octet & 0xE0) == 0xC0 {
        octet & 0x1F
      } else if (octet & 0xF0) == 0xE0 {
        octet & 0xF
      } else {
        octet & 0x7
      }
      for k in 1..<width {
        octet = self.input[self.raw_pos + k].to_int()
        if (octet & 0xC0) != 0x80 {
          raise self.set_reader_error(
            "invalid trailing UTF-8 octet",
            self.raw_pos + k,
          )
        }
        value = (value << 6) + (octet & 0x3F)
      }
      if !(width == 1 ||
        (width == 2 && value >= 0x80) ||
        (width == 3 && value >= 0x800) ||
        (width == 4 && value >= 0x10000)) {
        raise self.set_reader_error(
          "invalid length of a UTF-8 sequence",
          self.raw_pos,
        )
      }
      if (value >= 0xD800 && value <= 0xDFFF) || value > 0x10FFFF {
        raise self.set_reader_error("invalid Unicode character", self.raw_pos)
      }
      if !(value == 0x9 ||
        value == 0xA ||
        value == 0xD ||
        (value >= 0x20 && value <= 0x7E) ||
        value == 0x85 ||
        (value >= 0xA0 && value <= 0xD7FF) ||
        (value >= 0xE000 && value <= 0xFFFD) ||
        (value >= 0x10000 && value <= 0x10FFFF)) {
        raise self.set_reader_error(
          "control characters are not allowed",
          self.raw_pos,
        )
      }
      self.raw_pos += width
      self.unread += 1
    }
    if self.eof {
      // The terminating NUL character.
      self.unread += 1
      return
    }
  }
}

///|
/// `CACHE`.
fn Parser::cache(self : Parser, length : Int) -> Unit raise Fail {
  if self.unread < length {
    self.update_buffer(length)
  }
}

// Buffer access macros (`macros.rs`). Bytes past the decoded part of the
// buffer read as NUL (the terminating NUL once the input is exhausted).

///|
fn Parser::at(self : Parser, k : Int) -> Int {
  let p = self.ptr + k
  if p < self.raw_pos {
    self.input[p].to_int()
  } else {
    0
  }
}

///|
/// `CHECK_AT`.
fn Parser::check_at(self : Parser, c : Int, k : Int) -> Bool {
  self.at(k) == c
}

///|
/// `CHECK`.
fn Parser::check(self : Parser, c : Int) -> Bool {
  self.at(0) == c
}

///|
/// `IS_ALPHA`.
fn Parser::is_alpha(self : Parser) -> Bool {
  let c = self.at(0)
  (c >= '0' && c <= '9') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  c == '_' ||
  c == '-'
}

///|
/// `IS_DIGIT`.
fn Parser::is_digit(self : Parser) -> Bool {
  let c = self.at(0)
  c >= '0' && c <= '9'
}

///|
/// `IS_HEX_AT`.
fn Parser::is_hex_at(self : Parser, k : Int) -> Bool {
  let c = self.at(k)
  (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')
}

///|
/// `AS_HEX_AT`.
fn Parser::as_hex_at(self : Parser, k : Int) -> Int {
  let c = self.at(k)
  if c >= 'A' && c <= 'F' {
    c - 'A' + 10
  } else if c >= 'a' && c <= 'f' {
    c - 'a' + 10
  } else {
    c - '0'
  }
}

///|
/// `IS_Z_AT`.
fn Parser::is_z_at(self : Parser, k : Int) -> Bool {
  self.at(k) == 0
}

///|
/// `IS_BOM`.
fn Parser::is_bom(self : Parser) -> Bool {
  self.at(0) == 0xEF && self.at(1) == 0xBB && self.at(2) == 0xBF
}

///|
/// `IS_SPACE_AT`.
fn Parser::is_space_at(self : Parser, k : Int) -> Bool {
  self.at(k) == ' '
}

///|
/// `IS_TAB_AT`.
fn Parser::is_tab_at(self : Parser, k : Int) -> Bool {
  self.at(k) == '\t'
}

///|
/// `IS_BLANK_AT`.
fn Parser::is_blank_at(self : Parser, k : Int) -> Bool {
  self.is_space_at(k) || self.is_tab_at(k)
}

///|
/// `IS_BREAK_AT`.
fn Parser::is_break_at(self : Parser, k : Int) -> Bool {
  let c = self.at(k)
  c == '\r' ||
  c == '\n' ||
  (c == 0xC2 && self.at(k + 1) == 0x85) ||
  (c == 0xE2 && self.at(k + 1) == 0x80 && self.at(k + 2) == 0xA8) ||
  (c == 0xE2 && self.at(k + 1) == 0x80 && self.at(k + 2) == 0xA9)
}

///|
/// `IS_CRLF`.
fn Parser::is_crlf(self : Parser) -> Bool {
  self.at(0) == '\r' && self.at(1) == '\n'
}

///|
/// `IS_BREAKZ_AT`.
fn Parser::is_breakz_at(self : Parser, k : Int) -> Bool {
  self.is_break_at(k) || self.is_z_at(k)
}

///|
/// `IS_BLANKZ_AT`.
fn Parser::is_blankz_at(self : Parser, k : Int) -> Bool {
  self.is_blank_at(k) || self.is_breakz_at(k)
}

///|
/// `WIDTH`.
fn Parser::width(self : Parser) -> Int {
  let c = self.at(0)
  if (c & 0x80) == 0x00 {
    1
  } else if (c & 0xE0) == 0xC0 {
    2
  } else if (c & 0xF0) == 0xE0 {
    3
  } else if (c & 0xF8) == 0xF0 {
    4
  } else {
    0
  }
}

///|
/// `SKIP`.
fn Parser::skip(self : Parser) -> Unit {
  let width = self.width()
  self.mark_index += width
  self.mark_column += 1
  self.unread -= 1
  self.ptr += width
}

///|
/// `SKIP_LINE`.
fn Parser::skip_line(self : Parser) -> Unit {
  if self.is_crlf() {
    self.mark_index += 2
    self.mark_column = 0
    self.mark_line += 1
    self.unread -= 2
    self.ptr += 2
  } else if self.is_break_at(0) {
    let width = self.width()
    self.mark_index += width
    self.mark_column = 0
    self.mark_line += 1
    self.unread -= 1
    self.ptr += width
  }
}

///|
/// `READ`: copies the current character into `string`.
fn Parser::read(self : Parser, string : Array[Byte]) -> Unit {
  let width = self.width()
  for k in 0..<width {
    string.push(self.at(k).to_byte())
  }
  self.ptr += width
  self.mark_index += width
  self.mark_column += 1
  self.unread -= 1
}

///|
/// `READ_LINE`: copies the current line break into `string`, normalizing
/// CR, CRLF and NEL to LF.
fn Parser::read_line(self : Parser, string : Array[Byte]) -> Unit {
  if self.check_at('\r', 0) && self.check_at('\n', 1) {
    string.push(b'\n')
    self.ptr += 2
    self.mark_index += 2
    self.mark_column = 0
    self.mark_line += 1
    self.unread -= 2
  } else if self.check_at('\r', 0) || self.check_at('\n', 0) {
    string.push(b'\n')
    self.ptr += 1
    self.mark_index += 1
    self.mark_column = 0
    self.mark_line += 1
    self.unread -= 1
  } else if self.check_at(0xC2, 0) && self.check_at(0x85, 1) {
    string.push(b'\n')
    self.ptr += 2
    self.mark_index += 2
    self.mark_column = 0
    self.mark_line += 1
    self.unread -= 1
  } else if self.check_at(0xE2, 0) &&
    self.check_at(0x80, 1) &&
    (self.check_at(0xA8, 2) || self.check_at(0xA9, 2)) {
    string.push(self.at(0).to_byte())
    string.push(self.at(1).to_byte())
    string.push(self.at(2).to_byte())
    self.ptr += 3
    self.mark_index += 3
    self.mark_column = 0
    self.mark_line += 1
    self.unread -= 1
  }
}
