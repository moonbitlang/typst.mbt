// Port of `typst-library/src/text/lorem.rs`, including the parts of the
// `lipsum` crate (MIT, Copyright (c) 2017 Martin Geisler) and of the
// `rand`/`rand_chacha` crates it relies on, so that the generated text is
// identical to upstream.

///|
/// Creates blind text.
fn impl_lorem(words_ : USize) -> String raise HintedError {
  lorem_impl(words_.0)
}

///|
/// Generates `n` words of Lorem Ipsum text, treating `--` as a non-word
/// separator that is replaced with an en-dash (`–`).
fn lorem_impl(n : Int64) -> String {
  if n == 0L {
    return ""
  }
  let chain = lorem_chain()
  let iter = chain.iter_from(("Lorem", "ipsum"))
  let sentence = StringBuilder()
  let mut word_count = 0L
  let mut needs_cap = false
  while word_count < n {
    guard iter.next() is Some(word) else { break }
    if word_count > 0L {
      sentence.write_char(' ')
    }

    // Skip `--` without counting it as a word; append an en-dash to the
    // output instead.
    if word == "--" {
      sentence.write_char('\u{2013}')
      continue
    }
    if needs_cap {
      // Capitalize the first character of the word (the texts are ASCII).
      sentence.write_string(ascii_capitalize(word))
    } else {
      sentence.write_string(word)
    }
    // The sentence now ends with the word just written.
    needs_cap = ends_with_sentence_punct(word)
    word_count += 1L
  }
  let mut text = sentence.to_string()

  // Ensure the sentence ends with either one of ".!?".
  if !ends_with_sentence_punct(text) {
    // Trim all trailing punctuation characters to avoid adding '.' after a
    // ',' or similar.
    let mut end = text.length()
    while end > 0 && is_ascii_punctuation(text.unsafe_get(end - 1).to_int()) {
      end -= 1
    }
    text = text.unsafe_substring(start=0, end~) + "."
  }
  text
}

///|
fn ends_with_sentence_punct(s : String) -> Bool {
  s.has_suffix(".") || s.has_suffix("!") || s.has_suffix("?")
}

///|
fn is_ascii_punctuation(c : Int) -> Bool {
  (c >= 0x21 && c <= 0x2F) ||
  (c >= 0x3A && c <= 0x40) ||
  (c >= 0x5B && c <= 0x60) ||
  (c >= 0x7B && c <= 0x7E)
}

///|
fn ascii_capitalize(word : String) -> String {
  if word.is_empty() {
    return word
  }
  let c = word.unsafe_get(0).to_int()
  if c >= 0x61 && c <= 0x7A {
    Int::unsafe_to_char(c - 32).to_string() +
    word.unsafe_substring(start=1, end=word.length())
  } else {
    word
  }
}

// lipsum's Markov chain.

///|
priv struct MarkovChain {
  map : Map[(String, String), Array[String]]
  mut keys : Array[(String, String)]
}

///|
let lorem_chain_cell : Ref[MarkovChain?] = { val: None, }

///|
fn lorem_chain() -> MarkovChain {
  match lorem_chain_cell.val {
    Some(chain) => chain
    None => {
      let chain = { map: {}, keys: [], }
      chain.learn(lorem_ipsum_text)
      chain.learn(liber_primus_text)
      lorem_chain_cell.val = Some(chain)
      chain
    }
  }
}

///|
/// Add new text to the Markov chain.
fn MarkovChain::learn(self : MarkovChain, sentence : String) -> Unit {
  let words = split_whitespace(sentence)
  for i in 0..<(words.length() - 2) {
    let key = (words[i], words[i + 1])
    match self.map.get(key) {
      Some(list) => list.push(words[i + 2])
      None => self.map[key] = [words[i + 2]]
    }
  }
  let keys = self.map.keys().to_array()
  // Byte-wise lexicographic order like Rust's `&str` ordering (the texts are
  // ASCII, so UTF-16 code unit order agrees).
  keys.sort_by((a, b) => {
    let c = a.0.compare(b.0)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  self.keys = keys
}

///|
fn split_whitespace(s : String) -> Array[String] {
  let words = []
  let mut start = -1
  for i, c in s.to_array() {
    if @unicode.is_whitespace(c) {
      if start >= 0 {
        words.push(s.unsafe_substring(start~, end=i))
        start = -1
      }
    } else if start < 0 {
      start = i
    }
  }
  if start >= 0 {
    words.push(s.unsafe_substring(start~, end=s.length()))
  }
  words
}

///|
priv struct Words {
  chain : MarkovChain
  rng : ChaCha20Rng
  mut state : (String, String)
}

///|
fn MarkovChain::iter_from(self : MarkovChain, from : (String, String)) -> Words {
  { chain: self, rng: ChaCha20Rng::seed_from_u64(97UL), state: from, }
}

///|
fn Words::next(self : Words) -> String? {
  if self.chain.map.is_empty() {
    return None
  }
  let result = self.state.0
  while !self.chain.map.contains(self.state) {
    self.state = self.chain.keys[self.rng.gen_index(self.chain.keys.length())]
  }
  let next_words = self.chain.map[self.state]
  let next = next_words[self.rng.gen_index(next_words.length())]
  self.state = (self.state.1, next)
  Some(result)
}

// `rand_chacha::ChaCha20Rng` with `rand_core::SeedableRng::seed_from_u64`
// and `rand`'s `SliceRandom::choose`.

///|
priv struct ChaCha20Rng {
  key : FixedArray[UInt]
  mut counter : UInt64
  buf : FixedArray[UInt]
  mut index : Int
}

///|
fn ChaCha20Rng::seed_from_u64(state : UInt64) -> ChaCha20Rng {
  // PCG32 fills the 32-byte seed in 4-byte little-endian chunks.
  let key = FixedArray::make(8, 0U)
  let mut state = state
  for i in 0..<8 {
    state = state * 6364136223846793005UL + 11634580027462260723UL
    let xorshifted = (((state >> 18) ^ state) >> 27).to_uint()
    let rot = (state >> 59).to_int()
    key[i] = rotr32(xorshifted, rot)
  }
  { key, counter: 0UL, buf: FixedArray::make(16, 0U), index: 16, }
}

///|
fn ChaCha20Rng::refill(self : ChaCha20Rng) -> Unit {
  let s = FixedArray::make(16, 0U)
  s[0] = 0x61707865U
  s[1] = 0x3320646eU
  s[2] = 0x79622d32U
  s[3] = 0x6b206574U
  for i in 0..<8 {
    s[4 + i] = self.key[i]
  }
  s[12] = self.counter.to_uint()
  s[13] = (self.counter >> 32).to_uint()
  s[14] = 0U
  s[15] = 0U
  let x = s.copy()
  for _ in 0..<10 {
    chacha_quarter(x, 0, 4, 8, 12)
    chacha_quarter(x, 1, 5, 9, 13)
    chacha_quarter(x, 2, 6, 10, 14)
    chacha_quarter(x, 3, 7, 11, 15)
    chacha_quarter(x, 0, 5, 10, 15)
    chacha_quarter(x, 1, 6, 11, 12)
    chacha_quarter(x, 2, 7, 8, 13)
    chacha_quarter(x, 3, 4, 9, 14)
  }
  for i in 0..<16 {
    self.buf[i] = x[i] + s[i]
  }
  self.counter += 1UL
  self.index = 0
}

///|
fn chacha_quarter(
  x : FixedArray[UInt],
  a : Int,
  b : Int,
  c : Int,
  d : Int,
) -> Unit {
  x[a] = x[a] + x[b]
  x[d] = rotl32(x[d] ^ x[a], 16)
  x[c] = x[c] + x[d]
  x[b] = rotl32(x[b] ^ x[c], 12)
  x[a] = x[a] + x[b]
  x[d] = rotl32(x[d] ^ x[a], 8)
  x[c] = x[c] + x[d]
  x[b] = rotl32(x[b] ^ x[c], 7)
}

///|
fn ChaCha20Rng::next_u32(self : ChaCha20Rng) -> UInt {
  if self.index >= 16 {
    self.refill()
  }
  let v = self.buf[self.index]
  self.index += 1
  v
}

///|
/// `rand::seq::gen_index`: `rng.gen_range(0..ubound as u32)` using
/// `UniformInt::<u32>::sample_single_inclusive`.
fn ChaCha20Rng::gen_index(self : ChaCha20Rng, ubound : Int) -> Int {
  let range = ubound.reinterpret_as_uint()
  let zone = (range << range.clz()) - 1U
  for ;; {
    let v = self.next_u32()
    let m = v.to_uint64() * range.to_uint64()
    let hi = (m >> 32).to_uint()
    let lo = m.to_uint()
    if lo <= zone {
      return hi.reinterpret_as_int()
    }
  }
}

///|
fn rotl32(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

///|
fn rotr32(x : UInt, n : Int) -> UInt {
  if n == 0 {
    x
  } else {
    (x >> n) | (x << (32 - n))
  }
}
