///|
/// Grapheme cluster break categories (as in unicode-segmentation 1.12).
priv enum GraphemeCat {
  Any
  Control
  LF
  CR
  ExtendedPictographic
  Extend
  Prepend
  SpacingMark
  InCBConsonant
  L
  V
  T
  ZWJ
  LV
  LVT
  RegionalIndicator
} derive(Eq)

///|
let grapheme_cats : ReadOnlyArray[GraphemeCat] = grapheme_cat_names.map(
  cat_of_name,
)

///|
fn grapheme_cat(c : Int) -> GraphemeCat {
  if c < 0x7F && c >= 0x20 {
    return Any
  }
  grapheme_cats[in_valued(grapheme_cat_table, c, 0)]
}

///|
fn cat_of_name(name : String) -> GraphemeCat {
  match name {
    "GC_Control" => Control
    "GC_LF" => LF
    "GC_CR" => CR
    "GC_Extended_Pictographic" => ExtendedPictographic
    "GC_Extend" => Extend
    "GC_Prepend" => Prepend
    "GC_SpacingMark" => SpacingMark
    "GC_InCB_Consonant" => InCBConsonant
    "GC_L" => L
    "GC_V" => V
    "GC_T" => T
    "GC_ZWJ" => ZWJ
    "GC_LV" => LV
    "GC_LVT" => LVT
    "GC_Regional_Indicator" => RegionalIndicator
    _ => Any
  }
}

///|
fn is_incb_linker(c : Int) -> Bool {
  c == 0x94D ||
  c == 0x9CD ||
  c == 0xACD ||
  c == 0xB4D ||
  c == 0xC4D ||
  c == 0xD4D
}

///|
priv enum PairResult {
  NotBreak
  Break
  InCbConsonant
  Regional
  Emoji
}

///|
/// GB rules for a pair of categories in extended mode.
fn check_pair(before : GraphemeCat, after : GraphemeCat) -> PairResult {
  match (before, after) {
    (CR, LF) => NotBreak // GB3
    (Control | CR | LF, _) => Break // GB4
    (_, Control | CR | LF) => Break // GB5
    (L, L | V | LV | LVT) => NotBreak // GB6
    (LV | V, V | T) => NotBreak // GB7
    (LVT | T, T) => NotBreak // GB8
    (_, Extend | ZWJ) => NotBreak // GB9
    (_, SpacingMark) => NotBreak // GB9a
    (Prepend, _) => NotBreak // GB9b
    (_, InCBConsonant) => InCbConsonant // GB9c
    (ZWJ, ExtendedPictographic) => Emoji // GB11
    (RegionalIndicator, RegionalIndicator) => Regional // GB12, GB13
    (_, _) => Break // GB999
  }
}

///|
/// Decode the scalar value starting at UTF-16 index `i`. Returns the code
/// point and the index after it. Lone surrogates decode as themselves.
pub fn decode_at(s : StringView, i : Int) -> (Int, Int) {
  let c = s.code_unit_at(i).to_int()
  if c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length() {
    let d = s.code_unit_at(i + 1).to_int()
    if d >= 0xDC00 && d <= 0xDFFF {
      return ((c - 0xD800) * 0x400 + (d - 0xDC00) + 0x10000, i + 2)
    }
  }
  (c, i + 1)
}

///|
/// Decode the scalar value ending right before UTF-16 index `i`. Returns the
/// code point and the index where it starts.
pub fn decode_before(s : StringView, i : Int) -> (Int, Int) {
  let d = s.code_unit_at(i - 1).to_int()
  if d >= 0xDC00 && d <= 0xDFFF && i >= 2 {
    let c = s.code_unit_at(i - 2).to_int()
    if c >= 0xD800 && c <= 0xDBFF {
      return ((c - 0xD800) * 0x400 + (d - 0xDC00) + 0x10000, i - 2)
    }
  }
  (d, i - 1)
}

///|
/// Decide a break that depends on context before position `pos`.
fn lookback(s : StringView, pos : Int, kind : PairResult) -> Bool {
  match kind {
    InCbConsonant => {
      let mut linkers = 0
      let mut i = pos
      while i > 0 {
        let (c, prev) = decode_before(s, i)
        if is_incb_linker(c) {
          linkers += 1
        } else if !in_ranges(incb_extend_table, c) {
          return !(linkers > 0 && grapheme_cat(c) == InCBConsonant)
        }
        i = prev
      }
      true
    }
    Regional => {
      let mut count = 0
      let mut i = pos
      while i > 0 {
        let (c, prev) = decode_before(s, i)
        if grapheme_cat(c) != RegionalIndicator {
          break
        }
        count += 1
        i = prev
      }
      count % 2 == 0
    }
    Emoji => {
      // The character before `pos` is a ZWJ.
      let (_, start) = decode_before(s, pos)
      let mut i = start
      while i > 0 {
        let (c, prev) = decode_before(s, i)
        match grapheme_cat(c) {
          Extend => ()
          ExtendedPictographic => return false
          _ => return true
        }
        i = prev
      }
      true
    }
    _ => true
  }
}

///|
/// The UTF-16 index of the end of the extended grapheme cluster starting at
/// `start`. Returns `start` if `start` is at the end of the string.
pub fn grapheme_end(s : StringView, start : Int) -> Int {
  let len = s.length()
  if start >= len {
    return start
  }
  let (c0, next) = decode_at(s, start)
  let mut before = grapheme_cat(c0)
  let mut pos = next
  while pos < len {
    let (c, after_pos) = decode_at(s, pos)
    let after = grapheme_cat(c)
    let is_break = match check_pair(before, after) {
      NotBreak => false
      Break => true
      kind => lookback(s, pos, kind)
    }
    if is_break {
      break
    }
    before = after
    pos = after_pos
  }
  pos
}

///|
/// The UTF-16 index of the start of the extended grapheme cluster ending at
/// `end`. Returns `end` if `end` is `0`.
pub fn grapheme_start(s : StringView, end : Int) -> Int {
  if end <= 0 {
    return 0
  }
  // Walk backwards to a safe boundary candidate, then scan forwards.
  let mut start = 0
  let mut i = 0
  while i < end {
    let e = grapheme_end(s, i)
    if e >= end {
      start = i
      break
    }
    i = e
  }
  start
}

///|
/// Split a string into its extended grapheme clusters.
pub fn graphemes(s : StringView) -> Array[StringView] {
  let out = []
  let mut i = 0
  while i < s.length() {
    let e = grapheme_end(s, i)
    out.push(s.view(start_offset=i, end_offset=e))
    i = e
  }
  out
}
