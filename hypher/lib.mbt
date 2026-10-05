// Port of `hypher 0.1.8` (`lib.rs`): hypher separates words into syllables.
//
// Hyphenation patterns are embedded as efficiently encoded finite automata
// (the very same `tries/*.bin` files as the crate's, see `tries_gen.mbt`).
// Offsets are UTF-8 byte based like the crate's; syllables are returned as
// views into the word (upstream's `Syllables` iterator of `&str`).

///|
/// Segment a word into syllables.
///
/// Returns the syllables.
///
/// This uses the default [bounds](Lang::bounds) for the language.
pub fn hyphenate(word : StringView, lang : Lang) -> Array[StringView] {
  let (left_min, right_min) = lang.bounds()
  hyphenate_bounded(word, lang, left_min, right_min)
}

///|
/// Segment a word into syllables, but forbid breaking between the given number
/// of chars to each side.
pub fn hyphenate_bounded(
  word : StringView,
  lang : Lang,
  left_min : Int,
  right_min : Int,
) -> Array[StringView] {
  // The UTF-8 length of the word (`word.len()`).
  let len = utf8_str_len(word)

  // Initialize the trie state for the language.
  let root = lang.root()

  // Lowercase and add dots before and after the word..
  let dotted = lowercase_and_dot(word, len)

  // Convert char bounds to byte bounds in the dotted word.
  let min_idx = char_to_byte_min(word, left_min)
  let max_idx = char_to_byte_max(word, right_min, len)

  // The levels between each two inner bytes of the word.
  let levels = FixedArray::make(if len > 1 { len - 1 } else { 0 }, 0)

  // Start pattern matching at each character boundary.
  // The trie is walked with plain addresses instead of `State` objects
  // (upstream: `State` is a cheap borrowed view; allocating one per
  // transition dominated hyphenation time).
  let data = root.data
  for start in 0..<dotted.length() {
    if !is_char_boundary(dotted[start]) {
      continue
    }
    let mut addr = root.addr
    for k in start..<dotted.length() {
      let next = transition_addr(data, addr, dotted[k])
      if next < 0 {
        break
      }
      addr = next
      // The levels of the new state.
      let mut pos = addr
      let b = data[pos].to_int()
      if b >> 7 == 0 {
        continue
      }
      pos += 1
      if (b & 31) == 31 {
        pos += 1
      }
      let levels_at = (data[pos].to_int() << 4) | (data[pos + 1].to_int() >> 4)
      let levels_len = data[pos + 1].to_int() & 15
      let mut offset = 0
      for j in 0..<levels_len {
        let packed = data[levels_at + j].to_int()
        offset += packed / 10
        let level = packed % 10
        let split = start + offset
        if split >= min_idx && split <= max_idx {
          let slot = split - 2
          if level > levels[slot] {
            levels[slot] = level
          }
        }
      }
    }
  }

  // Break into segments at odd levels (upstream `Syllables`): level `i`
  // splits after byte `i + 1`. Upstream slices `&word[start..end]`, so the
  // splits are char boundaries; they are found by walking the chars.
  let syllables = []
  let mut start = 0
  let mut byte = 0
  for i = 0; i < word.length(); {
    let { cp, idx, } = @unicode.decode_at(word, i)
    byte += utf8_len(cp)
    if byte < len && levels[byte - 1] % 2 == 1 {
      syllables.push(word.view(start_offset=start, end_offset=idx))
      start = idx
    }
    continue idx
  }
  if start < word.length() {
    syllables.push(word.view(start_offset=start))
  }
  syllables
}

///|
/// The UTF-8 length of a string.
fn utf8_str_len(s : StringView) -> Int {
  let mut n = 0
  for i = 0; i < s.length(); {
    let { cp, idx, } = @unicode.decode_at(s, i)
    n += utf8_len(cp)
    continue idx
  }
  n
}

///|
/// Lowercase a word and add dots before and after it.
///
/// The dots enable patterns that match based on whether they are at the edges
/// of the word.
fn lowercase_and_dot(word : StringView, len : Int) -> FixedArray[Int] {
  let dotted = FixedArray::make(len + 2, 0)
  dotted[0] = '.'.to_int()

  // Add the lowercased chars.
  let mut offset = 1
  for i = 0; i < word.length(); {
    let { cp, idx: next, } = @unicode.decode_at(word, i)
    let mut c = cp
    if cp < 0x80 {
      // ASCII lowercases to a single ASCII char (fast path).
      if cp >= 'A' && cp <= 'Z' {
        c = cp + 32
      }
    } else {
      let lower = @unicode.char_to_lowercase(Int::unsafe_to_char(cp))
      let { cp: l, idx: lnext, } = @unicode.decode_at(lower, 0)
      if lnext == lower.length() && utf8_len(l) == utf8_len(c) {
        c = l
      }
    }
    offset = encode_char(dotted, offset, c)
    continue next
  }
  dotted[offset] = '.'.to_int()
  dotted
}

///|
/// Convert char bounds to byte bounds in the dotted word (upstream
/// `char_to_byte_bounds`, split in two to not collect the chars): the
/// minimum split index.
fn char_to_byte_min(word : StringView, left_min : Int) -> Int {
  // It makes no sense to split outside the word.
  let left_min = if left_min > 1 { left_min } else { 1 }

  // Convert from chars to byte indices in the dotted word.
  let mut left = 0
  let mut taken = 0
  for i = 0; i < word.length() && taken < left_min; {
    let { cp, idx, } = @unicode.decode_at(word, i)
    left += utf8_len(cp)
    taken += 1
    continue idx
  }
  1 + left
}

///|
/// The maximum split index (see [char_to_byte_min]); `len` is the UTF-8
/// length of the word.
fn char_to_byte_max(word : StringView, right_min : Int, len : Int) -> Int {
  let right_min = if right_min > 1 { right_min } else { 1 }
  let mut right = 0
  let mut taken = 0
  for i = word.length(); i > 0 && taken < right_min; {
    let { cp, idx, } = @unicode.decode_before(word, i)
    right += utf8_len(cp)
    taken += 1
    continue idx
  }
  1 + len - right
}

///|
/// A state in a trie traversal.
priv struct State {
  data : Bytes
  addr : Int
  stride : Int
  /// `(offset, len)` of the levels in `data`.
  levels_at : Int
  levels_len : Int
  /// `(offset, count)` of the transitions in `data`.
  trans_at : Int
  count : Int
  /// Offset of the targets in `data`.
  targets_at : Int
}

///|
/// Create a new state at the root node.
fn State::root(data : Bytes) -> State {
  let addr = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  State::at(data, addr)
}

///|
/// Create a new state at the given node address.
fn State::at(data : Bytes, addr : Int) -> State {
  let mut pos = addr

  // Decode whether the state has levels and the transition count.
  let b = data[pos].to_int()
  let has_levels = b >> 7 != 0
  let stride = (b >> 5) & 3
  let mut count = b & 31
  pos += 1

  // Possibly decode high transition count.
  if count == 31 {
    count = data[pos].to_int()
    pos += 1
  }

  // Decode the levels.
  let mut levels_at = 0
  let mut levels_len = 0
  if has_levels {
    let offset_hi = data[pos].to_int() << 4
    let offset_lo = data[pos + 1].to_int() >> 4
    levels_at = offset_hi | offset_lo
    levels_len = data[pos + 1].to_int() & 15
    pos += 2
  }

  // Decode the transitions.
  let trans_at = pos
  pos += count

  // Decode the targets.
  let targets_at = pos
  { data, addr, stride, levels_at, levels_len, trans_at, count, targets_at, }
}

///|
/// Return the state reached by following the transition labelled `b`.
/// Returns `None` if there is no such state.
/// The address of the state reached from the state at `addr` with byte `b`,
/// or `-1` if there is no such transition (`State::transition` on
/// addresses).
fn transition_addr(data : Bytes, addr : Int, b : Int) -> Int {
  let mut pos = addr
  let head = data[pos].to_int()
  let stride = (head >> 5) & 3
  let mut count = head & 31
  pos += 1
  if count == 31 {
    count = data[pos].to_int()
    pos += 1
  }
  if head >> 7 != 0 {
    pos += 2
  }
  let trans_at = pos
  let targets_at = pos + count
  for idx in 0..<count {
    if data[trans_at + idx].to_int() == b {
      return addr + from_be_bytes(data, targets_at + stride * idx, stride)
    }
  }
  -1
}

///|
/// Decode a signed number with 1, 2 or 3 bytes.
fn from_be_bytes(buf : Bytes, at : Int, len : Int) -> Int {
  match len {
    1 => {
      let v = buf[at].to_int()
      if v >= 128 {
        v - 256
      } else {
        v
      }
    }
    2 => {
      let v = (buf[at].to_int() << 8) | buf[at + 1].to_int()
      if v >= 32768 {
        v - 65536
      } else {
        v
      }
    }
    3 => {
      let first = buf[at].to_int() << 16
      let second = buf[at + 1].to_int() << 8
      let third = buf[at + 2].to_int()
      let unsigned = first | second | third
      unsigned - (1 << 23)
    }
    _ => abort("invalid stride")
  }
}

///|
/// Whether a byte is a character boundary.
fn is_char_boundary(b : Int) -> Bool {
  // (b as i8) >= -0x40
  b < 0x80 || b >= 0xC0
}

///|
/// The decoded tries, indexed by `Lang::index`.
let trie_cache : FixedArray[Bytes?] = FixedArray::make(tries.length(), None)

///|
fn Lang::root(self : Lang) -> State {
  let idx = self.index()
  let data = match trie_cache[idx] {
    Some(data) => data
    None => {
      let data = decode_base64(tries[idx])
      trie_cache[idx] = Some(data)
      data
    }
  }
  State::root(data)
}

///|
fn utf8_len(c : Int) -> Int {
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// Write the UTF-8 encoding of `c` at `offset`, returning the new offset.
fn encode_char(out : FixedArray[Int], offset : Int, c : Int) -> Int {
  if c < 0x80 {
    out[offset] = c
    offset + 1
  } else if c < 0x800 {
    out[offset] = 0xC0 | (c >> 6)
    out[offset + 1] = 0x80 | (c & 0x3F)
    offset + 2
  } else if c < 0x10000 {
    out[offset] = 0xE0 | (c >> 12)
    out[offset + 1] = 0x80 | ((c >> 6) & 0x3F)
    out[offset + 2] = 0x80 | (c & 0x3F)
    offset + 3
  } else {
    out[offset] = 0xF0 | (c >> 18)
    out[offset + 1] = 0x80 | ((c >> 12) & 0x3F)
    out[offset + 2] = 0x80 | ((c >> 6) & 0x3F)
    out[offset + 3] = 0x80 | (c & 0x3F)
    offset + 4
  }
}

///|
/// Decode base64 data, ignoring newlines.
fn decode_base64(s : String) -> Bytes {
  fn value(c : Int) -> Int {
    if c >= 'A' && c <= 'Z' {
      c - 'A'
    } else if c >= 'a' && c <= 'z' {
      c - 'a' + 26
    } else if c >= '0' && c <= '9' {
      c - '0' + 52
    } else if c == '+' {
      62
    } else if c == '/' {
      63
    } else {
      -1
    }
  }

  let out = FixedArray::make(s.length() / 4 * 3 + 3, b'\x00')
  let mut len = 0
  let mut acc = 0
  let mut bits = 0
  for i in 0..<s.length() {
    let v = value(s.code_unit_at(i).to_int())
    if v < 0 {
      continue
    }
    acc = ((acc << 6) | v) & 0xFFFFFF
    bits += 6
    if bits >= 8 {
      bits -= 8
      out[len] = ((acc >> bits) & 0xFF).to_byte()
      len += 1
    }
  }
  Bytes::from_array(out[:len])
}
