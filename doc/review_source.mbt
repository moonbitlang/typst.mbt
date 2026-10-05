// Source text (docs/edsl-review.md, slice 3): reading the argument that
// an origin points at in its MoonBit source file. A string literal, a
// multi-line string and an array of them are read character by character,
// each character with its line and column, so that text on the page can
// be matched with the characters that spell it (`review_locate.mbt`).
// Anything else — a variable, a call, an operator — is only named.

///|
/// A character of a source file: line and column are one-based, columns
/// count code points.
priv struct Cell {
  c : Char
  line : Int
  col : Int
}

///|
/// A character of a literal's value that is no white space, with the
/// place where the source spells it (`end`: the column behind it; an
/// escape is several columns wide).
priv struct LitChar {
  c : Char
  line : Int
  col : Int
  end : Int
  /// A number that grows by one from character to character, white space
  /// between them not counted, and by more where the literal's text does
  /// not simply go on: at a new line of the source, an interpolation, or
  /// the next element of an array. Characters with consecutive numbers are
  /// on one line with at most white space between them.
  at : Int
}

///|
/// What the source of an argument is.
priv enum ArgShape {
  /// String literals: their characters. With `holes`, something else is
  /// among them (an interpolation, an array element that is no literal).
  Literal(Array[LitChar], holes~ : Bool)
  /// One identifier.
  Binding(String)
  Expression
}

///|
/// The characters of the range of an origin in the text of its file, with
/// a line feed between lines. `None` if the range is not in the text.
fn source_cells(lines : Array[Array[Char]], origin : Origin) -> Array[Cell]? {
  guard origin.start_line >= 1 &&
    origin.start_line <= origin.end_line &&
    origin.end_line <= lines.length() else {
    return Option::None
  }
  let cells : Array[Cell] = []
  for line in origin.start_line..<(origin.end_line + 1) {
    let chars = lines[line - 1]
    let from = if line == origin.start_line {
      origin.start_column - 1
    } else {
      0
    }
    let to = if line == origin.end_line {
      origin.end_column - 1
    } else {
      chars.length()
    }
    guard from >= 0 && from <= to && to <= chars.length() else {
      return Option::None
    }
    for i in from..<to {
      cells.push({ c: chars[i], line, col: i + 1, })
    }
    if line < origin.end_line {
      cells.push({ c: '\n', line, col: chars.length() + 1, })
    }
  }
  Some(cells)
}

///|
/// The reader of an argument: the characters read so far, and the next
/// number (`LitChar::at`).
priv struct LitReader {
  cells : Array[Cell]
  chars : Array[LitChar]
  mut at : Int
  mut holes : Bool
}

///|
/// The index behind the end of the line that `i` is in.
fn LitReader::line_end(self : LitReader, i : Int, end : Int) -> Int {
  let mut j = i
  while j < end && self.cells[j].c != '\n' {
    j += 1
  }
  j
}

///|
/// The index behind white space and comments from `i`.
fn LitReader::skip_trivia(self : LitReader, i : Int, end : Int) -> Int {
  let cells = self.cells
  let mut i = i
  while i < end {
    if is_blank(cells[i].c) {
      i += 1
    } else if i + 1 < end && cells[i].c == '/' && cells[i + 1].c == '/' {
      i = self.line_end(i, end)
    } else {
      break
    }
  }
  i
}

///|
/// Whether a line of a multi-line string (`#|` or `$|`) starts at `i`.
fn LitReader::multiline_at(self : LitReader, i : Int, end : Int) -> Bool {
  i + 1 < end &&
  (self.cells[i].c == '#' || self.cells[i].c == '$') &&
  self.cells[i + 1].c == '|'
}

///|
/// The index behind the bracketed group that starts at `i`, with strings,
/// character literals, comments and nested groups skipped. `None` if it
/// does not end before `end`.
fn LitReader::skip_group(self : LitReader, i : Int, end : Int) -> Int? {
  let cells = self.cells
  let close = match cells[i].c {
    '(' => ')'
    '[' => ']'
    _ => '}'
  }
  let mut j = i + 1
  while j < end {
    let c = cells[j].c
    if c == close {
      return Some(j + 1)
    } else if c == '(' || c == '[' || c == '{' {
      guard self.skip_group(j, end) is Some(after) else { return Option::None }
      j = after
    } else if c == '"' {
      guard self.string(j, end, false) is Some(after) else {
        return Option::None
      }
      j = after
    } else if c == '\'' &&
      j + 2 < end &&
      cells[j + 1].c != '\\' &&
      cells[j + 2].c == '\'' {
      j += 3
    } else if c == '\'' && j + 1 < end && cells[j + 1].c == '\\' {
      // An escaped character literal: up to its closing quote.
      j += 3
      while j < end && cells[j].c != '\'' && cells[j].c != '\n' {
        j += 1
      }
      j += 1
    } else if self.multiline_at(j, end) ||
      (j + 1 < end && c == '/' && cells[j + 1].c == '/') {
      j = self.line_end(j, end)
    } else {
      j += 1
    }
  }
  Option::None
}

///|
/// The value of a hexadecimal digit.
fn hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    Option::None
  }
}

///|
/// Read the escape whose backslash is at `i`: its character and the index
/// behind it. `None` for an escape that this reader does not know.
fn LitReader::escape(self : LitReader, i : Int, end : Int) -> (Char, Int)? {
  let cells = self.cells
  guard i + 1 < end else { return Option::None }
  match cells[i + 1].c {
    'n' => Some(('\n', i + 2))
    'r' => Some(('\r', i + 2))
    't' => Some(('\t', i + 2))
    'b' => Some(('\b', i + 2))
    '\\' => Some(('\\', i + 2))
    '"' => Some(('"', i + 2))
    '\'' => Some(('\'', i + 2))
    'u' => {
      // `\u{..}` with hexadecimal digits, or `\u` and four of them.
      let mut j = i + 2
      let braces = j < end && cells[j].c == '{'
      if braces {
        j += 1
      }
      let mut code = 0
      let mut digits = 0
      while j < end &&
            hex_digit(cells[j].c) is Some(d) &&
            (braces || digits < 4) &&
            digits < 6 {
        code = code * 16 + d
        digits += 1
        j += 1
      }
      if braces {
        guard j < end && cells[j].c == '}' else { return Option::None }
        j += 1
      }
      guard digits > 0 &&
        (braces || digits == 4) &&
        code <= 0x10FFFF &&
        !(code >= 0xD800 && code <= 0xDFFF) else {
        return Option::None
      }
      Some((Int::unsafe_to_char(code), j))
    }
    _ => Option::None
  }
}

///|
/// Add a character of the literal's value that the source spells in the
/// cells `i..j`.
fn LitReader::push(self : LitReader, c : Char, i : Int, j : Int) -> Unit {
  guard !is_blank(c) else { return }
  let cell = self.cells[i]
  self.chars.push({
    c,
    line: cell.line,
    col: cell.col,
    end: cell.col + (j - i),
    at: self.at,
  })
  self.at += 1
}

///|
/// What is not literal text is in the literal here: the numbers do not go
/// on.
fn LitReader::gap(self : LitReader, hole : Bool) -> Unit {
  self.at += 1
  if hole {
    self.holes = true
  }
}

///|
/// The index behind the string literal whose opening quote is at `i`;
/// with `keep`, its characters are added. `None` if it does not end, or
/// has an escape that this reader does not know.
fn LitReader::string(self : LitReader, i : Int, end : Int, keep : Bool) -> Int? {
  let cells = self.cells
  let mut j = i + 1
  while j < end {
    let c = cells[j].c
    if c == '"' {
      return Some(j + 1)
    } else if c == '\n' {
      return Option::None
    } else if c == '\\' && j + 1 < end && cells[j + 1].c == '{' {
      // An interpolation.
      guard self.skip_group(j + 1, end) is Some(after) else {
        return Option::None
      }
      if keep {
        self.gap(true)
      }
      j = after
    } else if c == '\\' {
      guard self.escape(j, end) is Some((value, after)) else {
        // (Skipping needs no value: the character behind the backslash
        // is not a quote that ends the string.)
        guard !keep else { return Option::None }
        j += 2
        continue
      }
      if keep {
        self.push(value, j, after)
      }
      j = after
    } else {
      if keep {
        self.push(c, j, j + 1)
      }
      j += 1
    }
  }
  Option::None
}

///|
/// The index behind the lines of a multi-line string that starts at `i`
/// (`#|` lines are raw, `$|` lines can interpolate); their characters are
/// added. `None` for a `$|` line with a backslash that starts no
/// interpolation (an escape there is deprecated, and its meaning is not
/// assumed).
fn LitReader::multiline(self : LitReader, i : Int, end : Int) -> Int? {
  let cells = self.cells
  let mut i = i
  while self.multiline_at(i, end) {
    let raw = cells[i].c == '#'
    let stop = self.line_end(i, end)
    let mut j = i + 2
    while j < stop {
      if !raw && cells[j].c == '\\' {
        guard j + 1 < stop &&
          cells[j + 1].c == '{' &&
          self.skip_group(j + 1, stop) is Some(after) else {
          return Option::None
        }
        self.gap(true)
        j = after
      } else {
        self.push(cells[j].c, j, j + 1)
        j += 1
      }
    }
    // The next line of the literal, if the string goes on.
    self.gap(false)
    let next = self.skip_trivia(stop, end)
    guard self.multiline_at(next, end) else { return Some(stop) }
    i = next
  }
  Some(i)
}

///|
/// Read one literal that fills `start..end` exactly: a string or a
/// multi-line string. `false` if the range is something else.
fn LitReader::literal(self : LitReader, start : Int, end : Int) -> Bool {
  let before = self.chars.length()
  let holes = self.holes
  let read = if start < end && self.cells[start].c == '"' {
    self.string(start, end, true)
  } else if self.multiline_at(start, end) {
    self.multiline(start, end)
  } else {
    Option::None
  }
  if read == Some(end) {
    true
  } else {
    // Nothing of a range that is no literal is kept.
    while self.chars.length() > before {
      self.chars.pop() |> ignore
    }
    self.holes = holes
    false
  }
}

///|
/// The range without the white space and comments around it and without
/// parentheses that enclose all of it.
fn LitReader::strip(self : LitReader, start : Int, end : Int) -> (Int, Int) {
  let cells = self.cells
  let mut start = self.skip_trivia(start, end)
  let mut end = end
  while true {
    while end > start && is_blank(cells[end - 1].c) {
      end -= 1
    }
    guard start < end &&
      cells[start].c == '(' &&
      self.skip_group(start, end) == Some(end) else {
      break
    }
    start = self.skip_trivia(start + 1, end - 1)
    end -= 1
  }
  (start, end)
}

///|
/// What the source of an argument is: its literal characters if it is a
/// string, a multi-line string or an array with such elements.
fn arg_shape(cells : Array[Cell]) -> ArgShape {
  let reader : LitReader = { cells, chars: [], at: 0, holes: false, }
  let (start, end) = reader.strip(0, cells.length())
  guard start < end else { return Expression }
  if reader.literal(start, end) {
    return Literal(reader.chars, holes=reader.holes)
  }
  if cells[start].c == '[' && reader.skip_group(start, end) == Some(end) {
    // The elements, between the commas of the array itself.
    let mut from = start + 1
    let mut j = start + 1
    let element = (from : Int, to : Int) => {
      let (a, b) = reader.strip(from, to)
      if a < b && !reader.literal(a, b) {
        reader.holes = true
      }
      reader.gap(false)
    }
    while j < end - 1 {
      let c = cells[j].c
      if c == ',' {
        element(from, j)
        from = j + 1
        j += 1
      } else if c == '(' || c == '[' || c == '{' {
        guard reader.skip_group(j, end - 1) is Some(after) else {
          return Expression
        }
        j = after
      } else if c == '"' {
        guard reader.string(j, end - 1, false) is Some(after) else {
          return Expression
        }
        j = after
      } else if reader.multiline_at(j, end - 1) ||
        (j + 1 < end - 1 && c == '/' && cells[j + 1].c == '/') {
        j = reader.line_end(j, end - 1)
      } else {
        j += 1
      }
    }
    element(from, end - 1)
    return Literal(reader.chars, holes=reader.holes)
  }
  // One identifier (also a path: `@pkg.name`, `self.field`).
  let mut name = true
  for k in start..<end {
    let c = cells[k].c
    name = name &&
      (
        c == '_' ||
        c == '.' ||
        c == '@' ||
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9' && k > start)
      )
  }
  if name {
    Binding(String::from_array(cells[start:end].map(cell => cell.c)))
  } else {
    Expression
  }
}
