// Unicode normalization (NFC, NFD, NFKC, NFKD) equivalent to the
// `unicode-normalization` crate, backed by `text_tables_gen.mbt`.

///|
const S_BASE = 0xAC00

///|
const L_BASE = 0x1100

///|
const V_BASE = 0x1161

///|
const T_BASE = 0x11A7

///|
const L_COUNT = 19

///|
const V_COUNT = 21

///|
const T_COUNT = 28

///|
const N_COUNT = 588 // V_COUNT * T_COUNT

///|
const S_COUNT = 11172 // L_COUNT * N_COUNT

///|
/// The canonical combining class of a character.
pub fn canonical_combining_class(c : Int) -> Int {
  in_valued(ccc_table, c, 0)
}

///|
/// Binary search a `[c, len, chars..., ...]` table sorted by `c`. The
/// entries have variable length, so this first builds an index lazily.
fn decomposition_index(table : ReadOnlyArray[Int]) -> Array[Int] {
  let index = []
  let mut i = 0
  while i < table.length() {
    index.push(i)
    i += 2 + table[i + 1]
  }
  index
}

///|
let canonical_index : Ref[Array[Int]?] = { val: None, }

///|
let compatible_index : Ref[Array[Int]?] = { val: None, }

///|
fn find_decomposition(
  table : ReadOnlyArray[Int],
  cache : Ref[Array[Int]?],
  c : Int,
) -> Int? {
  let index = match cache.val {
    Some(index) => index
    None => {
      let index = decomposition_index(table)
      cache.val = Some(index)
      index
    }
  }
  for lo = 0, hi = index.length(); lo < hi; {
    let mid = lo + (hi - lo) / 2
    let k = table[index[mid]]
    if c < k {
      continue lo, mid
    } else if c > k {
      continue mid + 1, hi
    } else {
      break Some(index[mid])
    }
  } nobreak {
    None
  }
}

///|
/// Push the full decomposition of `c` to `out`.
fn decompose_char(c : Int, compat : Bool, out : Array[Int]) -> Unit {
  // Hangul syllables are decomposed algorithmically.
  if c >= S_BASE && c < S_BASE + S_COUNT {
    let s = c - S_BASE
    out.push(L_BASE + s / N_COUNT)
    out.push(V_BASE + s % N_COUNT / T_COUNT)
    let t = s % T_COUNT
    if t > 0 {
      out.push(T_BASE + t)
    }
    return
  }
  let found = if compat {
    match
      find_decomposition(compatible_decomposition_table, compatible_index, c) {
      Some(i) => Some((compatible_decomposition_table, i))
      None =>
        find_decomposition(canonical_decomposition_table, canonical_index, c).map(i => {
            (canonical_decomposition_table, i)
          },
        )
    }
  } else {
    find_decomposition(canonical_decomposition_table, canonical_index, c).map(i => {
      (canonical_decomposition_table, i)
    })
  }
  match found {
    Some((table, i)) =>
      for j in (i + 2)..<(i + 2 + table[i + 1]) {
        out.push(table[j])
      }
    None => out.push(c)
  }
}

///|
/// Decompose and canonically reorder the string.
fn decompose(s : StringView, compat : Bool) -> Array[Int] {
  let out = []
  let mut i = 0
  while i < s.length() {
    let { cp: c, idx: next, } = decode_at(s, i)
    decompose_char(c, compat, out)
    i = next
  }
  // Canonical ordering: stable sort runs of non-starters by combining class.
  let mut start = 0
  while start < out.length() {
    if canonical_combining_class(out[start]) == 0 {
      start += 1
      continue
    }
    let mut end = start
    while end < out.length() && canonical_combining_class(out[end]) != 0 {
      end += 1
    }
    // Insertion sort (stable).
    for k in (start + 1)..<end {
      let x = out[k]
      let cx = canonical_combining_class(x)
      let mut j = k
      while j > start && canonical_combining_class(out[j - 1]) > cx {
        out[j] = out[j - 1]
        j -= 1
      }
      out[j] = x
    }
    start = end
  }
  out
}

///|
/// The primary composite of `a` and `b`, if any.
fn compose_pair(a : Int, b : Int) -> Int? {
  // Hangul.
  if a >= L_BASE && a < L_BASE + L_COUNT && b >= V_BASE && b < V_BASE + V_COUNT {
    return Some(S_BASE + ((a - L_BASE) * V_COUNT + (b - V_BASE)) * T_COUNT)
  }
  if a >= S_BASE &&
    a < S_BASE + S_COUNT &&
    (a - S_BASE) % T_COUNT == 0 &&
    b > T_BASE &&
    b < T_BASE + T_COUNT {
    return Some(a + (b - T_BASE))
  }
  let n = composition_table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    let x = composition_table[3 * mid]
    let y = composition_table[3 * mid + 1]
    if a < x || (a == x && b < y) {
      continue lo, mid
    } else if a > x || (a == x && b > y) {
      continue mid + 1, hi
    } else {
      break Some(composition_table[3 * mid + 2])
    }
  } nobreak {
    None
  }
}

///|
/// Canonical composition of a decomposed, reordered sequence.
fn compose(chars : Array[Int]) -> Array[Int] {
  let out = []
  let mut starter = -1
  // The combining class of the last char after the starter, or -1 if the
  // starter is the last char.
  let mut last_cc = -1
  for c in chars {
    let cc = canonical_combining_class(c)
    if starter >= 0 {
      let blocked = last_cc != -1 && (last_cc == 0 || last_cc >= cc)
      if !blocked {
        match compose_pair(out[starter], c) {
          Some(composed) => {
            out[starter] = composed
            continue
          }
          None => ()
        }
      }
    }
    if cc == 0 {
      starter = out.length()
      last_cc = -1
    } else {
      last_cc = cc
    }
    out.push(c)
  }
  out
}

///|
fn chars_to_string(chars : Array[Int]) -> String {
  let buf = StringBuilder()
  for c in chars {
    buf.write_char(c.unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Normalization Form D.
pub fn nfd(s : StringView) -> String {
  chars_to_string(decompose(s, false))
}

///|
/// Normalization Form KD.
pub fn nfkd(s : StringView) -> String {
  chars_to_string(decompose(s, true))
}

///|
/// Normalization Form C.
pub fn nfc(s : StringView) -> String {
  chars_to_string(compose(decompose(s, false)))
}

///|
/// Normalization Form KC.
pub fn nfkc(s : StringView) -> String {
  chars_to_string(compose(decompose(s, true)))
}
