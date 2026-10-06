// Port of `biblatex/src/chunk.rs`.

///|
/// A byte range in the source (upstream `std::ops::Range<usize>`).
pub(all) struct Span {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Span with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Span with @debug.Debug::{to_repr}

///|
pub fn Span::new(start : Int, end : Int) -> Span {
  { start, end, }
}

///|
/// Whether the span is empty.
pub fn Span::is_empty(self : Span) -> Bool {
  self.start >= self.end
}

///|
/// The detached marker (upstream `usize::MAX`).
pub const DETACHED : Int = 2147483647

///|
/// Saturating addition of span offsets.
fn sat_add(a : Int, b : Int) -> Int {
  if a >= DETACHED - b {
    DETACHED
  } else {
    a + b
  }
}

///|
/// A value with the span it corresponds to in the source code.
///
/// Spans can be _detached,_ this means that they deliberately do not point
/// into the source code.
pub(all) struct Spanned[T] {
  /// The spanned value.
  mut v : T
  /// The location in source code of the value.
  mut span : Span
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Spanned with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Spanned with @debug.Debug::{to_repr}

///|
/// Create a new instance from a value and its span.
pub fn[T] Spanned::new(v : T, span : Span) -> Spanned[T] {
  { v, span, }
}

///|
/// Create a new instance with a value and a zero-length span.
pub fn[T] Spanned::zero(v : T) -> Spanned[T] {
  { v, span: { start: 0, end: 0, }, }
}

///|
/// Create a new instance with a detached span.
pub fn[T] Spanned::detached(v : T) -> Spanned[T] {
  { v, span: { start: DETACHED, end: DETACHED, }, }
}

///|
/// Whether the span is detached.
pub fn[T] Spanned::is_detached(self : Spanned[T]) -> Bool {
  self.span.start == DETACHED
}

///|
/// Represents one part of a field value.
pub(all) enum Chunk {
  /// Normal values within quotes or single braces subject to
  /// capitalization formatting.
  Normal(String)
  /// Values nested in braces that are to be printed like specified
  /// in the file. Escapes keywords.
  ///
  /// Example: `"Inside {NASA}"` or `{Memes are {gReAT}}`.
  Verbatim(String)
  /// Values nested in dollar signs.
  Math(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Chunk with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Chunk with @debug.Debug::{to_repr}

///|
/// A vector of chunks.
pub type Chunks = Array[Spanned[Chunk]]

///|
/// Get the string contained in the chunk.
pub fn Chunk::get(self : Chunk) -> String {
  match self {
    Normal(s) | Verbatim(s) | Math(s) => s
  }
}

///|
/// Get the string contained in the chunk and whether it is verbatim.
fn Chunk::get_and_verb(self : Chunk) -> (String, Bool) {
  match self {
    Normal(s) => (s, false)
    Verbatim(s) => (s, true)
    Math(s) => (s, false)
  }
}

///|
/// Replace the string contained in the chunk.
fn Chunk::with_str(self : Chunk, s : String) -> Chunk {
  match self {
    Normal(_) => Normal(s)
    Verbatim(_) => Verbatim(s)
    Math(_) => Math(s)
  }
}

///|
/// Get the string contained in the chunk with the characters escaped.
pub fn Chunk::to_biblatex_string(self : Chunk, is_verbatim : Bool) -> String {
  let s = StringBuilder()
  for c in self.get() {
    if is_escapable(c, is_verbatim, false) {
      s.write_char('\\')
    }
    s.write_char(c)
  }
  s.to_string()
}

///|
/// Format the chunks in sentence case.
pub fn format_sentence(chunks : ArrayView[Spanned[Chunk]]) -> String {
  let out = StringBuilder()
  let mut first = true
  let mut prev_was_whitespace = false
  for val in chunks {
    match val.v {
      Normal(s) =>
        for c0 in s {
          let mut c = c0
          if c == '\n' || c == '\r' {
            if prev_was_whitespace {
              continue
            } else {
              c = ' '
            }
          }
          if first {
            out.write_string(@unscanny.char_to_uppercase(c))
          } else {
            out.write_string(@unscanny.char_to_lowercase(c))
          }
          first = false
          prev_was_whitespace = @unscanny.is_whitespace(c)
        }
      Verbatim(s) => {
        out.write_string(s)
        prev_was_whitespace = match @unscanny.last_char(s) {
          Some(c) => @unscanny.is_whitespace(c)
          None => false
        }
      }
      Math(s) => {
        out.write_char('$')
        out.write_string(s)
        out.write_char('$')
      }
    }
    first = false
  }
  out.to_string()
}

///|
/// Format the chunks verbatim.
pub fn format_verbatim(chunks : ArrayView[Spanned[Chunk]]) -> String {
  let out = StringBuilder()
  let mut prev_was_whitespace = false
  for val in chunks {
    match val.v {
      Normal(s) =>
        for c0 in s {
          let mut c = c0
          if c == '\n' || c == '\r' {
            if prev_was_whitespace {
              continue
            } else {
              c = ' '
            }
          }
          out.write_char(c)
          prev_was_whitespace = @unscanny.is_whitespace(c)
        }
      Verbatim(s) => {
        out.write_string(s)
        prev_was_whitespace = match @unscanny.last_char(s) {
          Some(c) => @unscanny.is_whitespace(c)
          None => false
        }
      }
      Math(s) => {
        out.write_char('$')
        out.write_string(s)
        out.write_char('$')
      }
    }
  }
  out.to_string()
}

///|
/// Output a span for all chunks in the collection.
pub fn chunks_span(chunks : ArrayView[Spanned[Chunk]]) -> Span {
  let start = if chunks.length() > 0 { chunks[0].span.start } else { 0 }
  let end = if chunks.length() > 0 {
    chunks[chunks.length() - 1].span.end
  } else {
    start
  }
  { start, end, }
}

///|
/// Serialize the chunks into a BibLaTeX string.
pub fn chunks_to_biblatex_string(
  chunks : ArrayView[Spanned[Chunk]],
  is_verbatim : Bool,
) -> String {
  let res = StringBuilder()
  res.write_char('{')
  let mut extra_brace = false
  for chunk in chunks {
    match chunk.v {
      Verbatim(_) if !extra_brace => {
        res.write_char('{')
        extra_brace = true
      }
      Normal(_) if extra_brace => {
        res.write_char('}')
        extra_brace = false
      }
      Math(_) => res.write_char('$')
      _ => ()
    }
    res.write_string(chunk.v.to_biblatex_string(is_verbatim))
    if chunk.v is Math(_) {
      res.write_char('$')
    }
  }
  for _ in 0..<(if extra_brace { 2 } else { 1 }) {
    res.write_char('}')
  }
  res.to_string()
}

///|
/// The characters in each chunk, indicating whether they are verbatim or
/// not.
pub fn chunk_chars(chunks : ArrayView[Spanned[Chunk]]) -> Array[(Char, Bool)] {
  let out = []
  for chunk in chunks {
    let (s, verbatim) = chunk.v.get_and_verb()
    for c in s {
      out.push((c, verbatim))
    }
  }
  out
}

///|
/// Clone a chunk vector (chunks are mutable records).
pub fn clone_chunks(chunks : ArrayView[Spanned[Chunk]]) -> Chunks {
  chunks.map(c => Spanned::new(c.v, c.span))
}

///|
/// Combines the chunks, interlacing with the separator.
pub fn join_chunk_list(
  chunks : ArrayView[Spanned[Chunk]],
  sep : String,
) -> Chunks {
  let res = []
  let mut first = true
  for chunk in chunks {
    if first {
      first = false
    } else {
      res.push(
        Spanned::new(Chunk::Normal(sep), {
          start: chunk.span.start,
          end: chunk.span.start,
        }),
      )
    }
    res.push(Spanned::new(chunk.v, chunk.span))
  }
  res
}

///|
/// Splits chunk vectors that are a token lists as defined per the BibLaTeX
/// Manual p. 16 along occurrences of the keyword.
pub fn split_token_lists(
  vals : ArrayView[Spanned[Chunk]],
  keyword : String,
) -> Array[Chunks] {
  let out = []
  let mut latest = []
  let kw_len = @unscanny.len_utf8(keyword)
  for val in vals {
    if val.v is Normal(s) {
      let mut target : String = s
      let mut start = val.span.start
      while target.find(keyword) is Some(pos16) {
        let pos = @unscanny.len_utf8(target[:pos16])
        let first = @unscanny.trim_end(target[:pos16])
        latest.push(
          Spanned::new(Chunk::Normal(first), { start, end: start + pos, }),
        )
        out.push(latest)
        latest = []
        target = @unscanny.trim_start(target[pos16 + keyword.length():])
        start += pos + kw_len
      }
      latest.push(
        Spanned::new(Chunk::Normal(target), { start, end: val.span.end, }),
      )
    } else {
      latest.push(Spanned::new(val.v, val.span))
    }
  }
  out.push(latest)
  out
}

///|
/// Split the token list based on a keyword surrounded by whitespace
///
/// For Normal Chunks,
/// - The leading/trailing keyword is not considered as a valid split
///   (regardless of whether the keyword is preceded/followed by some
///   whitespace).
/// - If there are consecutive keywords, the characters between two
///   consecutive keywords (whether only whitespace or not) will be considered
///   as a valid split.
pub fn split_token_lists_with_kw(
  vals : ArrayView[Spanned[Chunk]],
  keyword : String,
) -> Array[Chunks] {
  let out = []
  let mut latest : Chunks = []

  // Trim the beginning and the end of the parsed field
  fn sanitize_latest(latest : Chunks) -> Unit {
    if latest.is_empty() {
      return
    }
    let mut diff = 0
    if latest[0].v is Normal(s) {
      let trimmed = @unscanny.trim_start(s)
      diff = @unscanny.len_utf8(s) - @unscanny.len_utf8(trimmed)
      latest[0].v = Chunk::Normal(trimmed)
    }
    if !latest[0].is_detached() {
      latest[0].span = { ..latest[0].span, start: latest[0].span.start + diff, }
    }
    let mut new_len = 0
    let end = latest.length() - 1
    if latest[end].v is Normal(s) {
      let trimmed = @unscanny.trim_end(s)
      new_len = @unscanny.len_utf8(trimmed)
      latest[end].v = Chunk::Normal(trimmed)
    }
    if !latest[end].is_detached() {
      latest[end].span = {
        ..latest[end].span,
        end: latest[end].span.start + new_len,
      }
    }
  }

  for chunk_idx, chunk in vals {
    if chunk.v is Normal(s0) {
      let mut start = chunk.span.start

      // If the first chunk is normal -> leading keyword
      let s = if chunk_idx == 0 {
        let new_s = @unscanny.trim_start(s0)
        if !chunk.is_detached() {
          // Offset the span start by the number of characters trimmed
          start = chunk.span.start +
            @unscanny.len_utf8(s0) -
            @unscanny.len_utf8(new_s)
        }
        new_s
      } else {
        s0
      }

      // If the last chunk is normal -> trailing keyword
      let s = if chunk_idx == vals.length() - 1 {
        @unscanny.trim_end(s)
      } else {
        s
      }
      let splits = @unscanny.split(s, keyword)
      // guaranteed to have a value
      let mut prev = splits[0]
      let cur = StringBuilder()
      for i in 1..<splits.length() {
        let split = splits[i]
        let prev_ws = match @unscanny.last_char(prev) {
          Some(c) => @unscanny.is_whitespace(c)
          None => false
        }
        let split_ws = match @unscanny.first_char(split) {
          Some(c) => @unscanny.is_whitespace(c)
          None => false
        }
        if prev_ws && split_ws {
          cur.write_string(prev)
          let cur_s = cur.to_string()
          cur.reset()
          let end = if chunk.is_detached() {
            DETACHED
          } else {
            start + @unscanny.len_utf8(cur_s)
          }
          latest.push(Spanned::new(Chunk::Normal(cur_s), { start, end, }))
          sanitize_latest(latest)
          out.push(latest)
          latest = []
          start = end
          prev = split
          continue
        }
        cur.write_string(prev)
        cur.write_string(keyword)
        prev = split
      }
      cur.write_string(prev)
      let cur_s = cur.to_string()
      let end = if chunk.is_detached() {
        DETACHED
      } else {
        start + @unscanny.len_utf8(cur_s)
      }
      latest.push(Spanned::new(Chunk::Normal(cur_s), { start, end, }))
    } else {
      latest.push(Spanned::new(chunk.v, chunk.span))
    }
  }
  sanitize_latest(latest)
  out.push(latest)
  out
}

///|
/// Splits a chunk vector into two at the first occurrence of the character
/// `c`. `omit` controls whether the output will contain `c`.
pub fn split_at_normal_char(
  src : ArrayView[Spanned[Chunk]],
  c : Char,
  omit : Bool,
) -> (Chunks, Chunks) {
  let mut search_result = None
  for chunk_idx, val in src {
    if val.v is Normal(s) {
      if s.find(c.to_string()) is Some(i16) {
        search_result = Some((chunk_idx, @unscanny.len_utf8(s[:i16])))
        break
      }
    }
  }
  match search_result {
    Some((chunk_idx, str_idx)) => {
      let (v1, v2) = split_values(src, chunk_idx, str_idx)
      if omit {
        if v2[0].v is Normal(s) {
          // Remove the first char and trim.
          let rest = match @unscanny.first_char(s) {
            Some(fc) => s[fc.utf16_len():].to_owned()
            None => s
          }
          v2[0].v = Normal(@unscanny.trim_start(rest))
        }
        v2[0].span = {
          ..v2[0].span,
          start: v2[0].span.end - @unscanny.len_utf8(v2[0].v.get()),
        }
      }
      (v1, v2)
    }
    None => (clone_chunks(src), [])
  }
}

///|
/// Convert a UTF-8 byte index into a UTF-16 index of `s`.
fn byte_to_utf16(s : String, byte : Int) -> Int {
  let mut b = 0
  let mut i = 0
  while i < s.length() && b < byte {
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    b += @unscanny.char_len_utf8(Int::unsafe_to_char(c))
    i = next
  }
  i
}

///|
/// Returns two chunk vectors with `src` split at some chunk index and
/// the string byte index `str_idx` within that chunk.
pub fn split_values(
  src : ArrayView[Spanned[Chunk]],
  chunk_idx : Int,
  str_idx : Int,
) -> (Chunks, Chunks) {
  let src = clone_chunks(src)
  let new = []
  if chunk_idx >= src.length() {
    return (src, new)
  }
  if chunk_idx + 1 < src.length() {
    for i in (chunk_idx + 1)..<src.length() {
      new.push(src[i])
    }
    src.truncate(chunk_idx + 1)
  }
  let item = src[src.length() - 1]
  let content = item.v.get()
  let i16 = byte_to_utf16(content, str_idx)
  let s1 = content[:i16]
  let s2 = content[i16:]
  let boundary = sat_add(item.span.start, str_idx)
  item.span = { start: item.span.start, end: boundary, }
  let new_span = {
    start: boundary,
    end: sat_add(boundary, @unscanny.len_utf8(s2)),
  }
  let s1 = @unscanny.trim_end(s1)
  let s2 = @unscanny.trim_start(s2)
  item.v = item.v.with_str(s1)
  let first : Chunk = match item.v {
    Normal(_) => Normal(s2)
    Verbatim(_) => Verbatim(s2)
    Math(_) => Math(s2)
  }
  new.insert(0, Spanned::new(first, new_span))
  (src, new)
}

///|
/// Returns the number of characters in the chunks.
pub fn count_num_char(chunks : ArrayView[Spanned[Chunk]], c : Char) -> Int {
  let mut n = 0
  for val in chunks {
    if val.v is Normal(s) {
      n += @unscanny.count_char(s, c)
    }
  }
  n
}
