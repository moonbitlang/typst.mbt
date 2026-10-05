// Selecting text (docs/edsl-review.md, slice 2): the words of a compiled
// document in reading order, each with its origin and its piece, and
// selections of them. The preview page's layer is built from the same
// words (`OriginTable::layer`), so the page and the library select the
// same things.

///|
/// A word: glyphs of one text item that follow each other, belong to one
/// piece and have no white space between them.
priv struct Word {
  /// The page, from 1.
  page : Int
  text : String
  /// Whether the word is apart from the word before it: white space, a
  /// new line or another place on the page is between them. Words that
  /// touch are parts of one written word (the piece changes inside it).
  space : Bool
  /// The number of the origin in the table.
  origin : Int
  /// The number of the piece: text with the same span. All runs of one
  /// `Prose` and all strings of one array have the same origin, the
  /// argument; each is a piece of its own (docs/edsl-design.md, 12.2).
  piece : Int
}

///|
/// Whether a character is white space between words.
fn is_blank(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u{3000}'
}

///|
/// The words of a text item, appended to `self.words` in reading order,
/// and for each glyph the number of its word (`-1`: white space, or a
/// glyph without an origin). `apart`: the item does not continue the text
/// item before it on its line.
fn OriginTable::item_words(
  self : OriginTable,
  text : @library.TextItem,
  apart : Bool,
) -> Array[Int] {
  let glyphs = text.glyphs
  let word_of = Array::make(glyphs.length(), -1)
  // The byte offset of every character, to cut the text at glyph ranges.
  let chars = text.text.to_array()
  let offsets : Array[Int] = [0]
  for c in chars {
    let n = c.to_int()
    let width = if n < 0x80 {
      1
    } else if n < 0x800 {
      2
    } else if n < 0x10000 {
      3
    } else {
      4
    }
    offsets.push(offsets[offsets.length() - 1] + width)
  }
  let char_at = (byte : Int) => {
    match offsets.binary_search(byte) {
      Ok(index) => Some(index)
      Err(_) => Option::None
    }
  }
  // Parts of words: (first byte, end byte as character indices, origin,
  // piece, glyphs).
  let parts : Array[(Int, Int, Int, Int, Array[Int])] = []
  let mut open = false
  let mut valid = true
  for g, glyph in glyphs {
    let (from, to) = glyph.range()
    guard char_at(from) is Some(a) && char_at(to) is Some(b) && a < b else {
      // The ranges of a very long item are not reliable (they are stored
      // in 16 bits): the item is one word.
      valid = false
      break
    }
    let mut blank = true
    for c in chars[a:b] {
      blank = blank && is_blank(c)
    }
    guard !blank && self.id(glyph.span) is Some(origin) else {
      open = false
      continue
    }
    let piece = self.piece(glyph.span)
    if open &&
      parts.last() is Some((first, end, last_origin, last_piece, list)) &&
      last_origin == origin &&
      last_piece == piece &&
      (a == end || b == first || (a >= first && b <= end)) {
      // The next cluster in reading order (right-to-left text is drawn
      // from its end), or another glyph of the same cluster.
      parts[parts.length() - 1] = (
        if a < first {
          a
        } else {
          first
        },
        if b > end {
          b
        } else {
          end
        },
        origin,
        piece,
        list,
      )
      list.push(g)
    } else {
      parts.push((a, b, origin, piece, [g]))
    }
    open = true
  }
  if !valid {
    // One word with the whole text, for the origin of the first glyph
    // that has one.
    let whole = text.text.trim().to_owned()
    for glyph in glyphs {
      guard whole != "" && self.id(glyph.span) is Some(origin) else { continue }
      let number = self.words.length()
      self.words.push({
        page: self.page,
        text: whole,
        space: true,
        origin,
        piece: self.piece(glyph.span),
      })
      for g, glyph in glyphs {
        if self.id(glyph.span) is Some(_) {
          word_of[g] = number
        }
      }
      break
    }
    return word_of
  }
  // Reading order: by the place in the item's text.
  parts.sort_by((x, y) => x.0.compare(y.0))
  let mut before = -1
  for part in parts {
    let (first, end, origin, piece, list) = part
    let number = self.words.length()
    self.words.push({
      page: self.page,
      text: String::from_array(chars[first:end].to_owned()),
      space: if before < 0 {
        apart
      } else {
        first > before
      },
      origin,
      piece,
    })
    for g in list {
      word_of[g] = number
    }
    before = end
  }
  word_of
}

///|
/// The text of a compiled document as the review loop sees it: its words
/// in reading order (the order in which the engine placed the text), with
/// their origins.
pub struct ReviewText {
  priv title : String
  priv origins : Array[Origin]
  priv words : Array[Word]
}

///|
/// A selection of text: the words from one word to another, in reading
/// order.
pub struct Selection {
  priv from : Int
  priv to : Int
}

///|
/// The text of a compiled document for selecting (`title`: as in
/// `review_html`). Raises the errors of a failed compilation.
pub fn CompileReport::review_text(
  self : CompileReport[@layout.PagedDocument],
  title? : String,
) -> ReviewText raise DocError {
  let document = self.unwrap()
  let (table, _) = self.review_layers(document)
  {
    title: review_title(document, title),
    origins: table.list,
    words: table.words,
  }
}

///|
/// The number of words.
pub fn ReviewText::length(self : ReviewText) -> Int {
  self.words.length()
}

///|
/// The words `from..=to` as text: words that are apart are joined with a
/// space.
fn ReviewText::join(self : ReviewText, from : Int, to : Int) -> String {
  let out = StringBuilder()
  let to = if to < self.words.length() { to } else { self.words.length() - 1 }
  for i in from..<(to + 1) {
    if i > from && self.words[i].space {
      out.write_char(' ')
    }
    out.write_string(self.words[i].text)
  }
  out.to_string()
}

///|
/// The whole text.
pub fn ReviewText::text(self : ReviewText) -> String {
  self.join(0, self.words.length() - 1)
}

///|
/// The words `from..=to` (numbers of words in reading order, from 0), in
/// either order; `None` if there is no such word.
pub fn ReviewText::range(self : ReviewText, from : Int, to : Int) -> Selection? {
  let (from, to) = if from <= to { (from, to) } else { (to, from) }
  guard from >= 0 && to < self.words.length() else { return None }
  Some({ from, to, })
}

///|
/// The selection of the words that the `nth` occurrence of `needle` in
/// the text touches (white space in `needle` stands for any gap between
/// words). `None` if there is none.
pub fn ReviewText::find(
  self : ReviewText,
  needle : String,
  nth? : Int = 0,
) -> Selection? {
  // The needle with single spaces.
  let wanted : Array[Char] = []
  for c in needle {
    if !is_blank(c) {
      wanted.push(c)
    } else if wanted.last() is Some(last) && last != ' ' {
      wanted.push(' ')
    }
  }
  if wanted.last() is Some(' ') {
    wanted.pop() |> ignore
  }
  guard wanted.length() > 0 && nth >= 0 else { return None }
  // The text, and the word of each of its characters (`-1`: a space).
  let stream : Array[Char] = []
  let word_at : Array[Int] = []
  for i, word in self.words {
    if i > 0 && word.space {
      stream.push(' ')
      word_at.push(-1)
    }
    for c in word.text {
      stream.push(if is_blank(c) { ' ' } else { c })
      word_at.push(i)
    }
  }
  let mut seen = 0
  for at in 0..<(stream.length() - wanted.length() + 1) {
    guard stream[at:at + wanted.length()] == wanted[:] else { continue }
    if seen == nth {
      let mut from = -1
      let mut to = -1
      for k in at..<(at + wanted.length()) {
        if word_at[k] >= 0 {
          if from < 0 {
            from = word_at[k]
          }
          to = word_at[k]
        }
      }
      guard from >= 0 else { return None }
      return Some({ from, to, })
    }
    seen += 1
  }
  None
}

///|
/// The text of a selection.
pub fn ReviewText::selected_text(
  self : ReviewText,
  selection : Selection,
) -> String {
  self.join(selection.from, selection.to)
}
