// Port of the forward word boundary iterator of `unicode-segmentation 1.12`
// (`word.rs`: `UWordBounds::next`, `split_word_bounds`, `unicode_words`).
// The tables live in `word_tables_gen.mbt`.

///|
/// Word break categories (as in unicode-segmentation 1.12).
priv enum WordCat {
  Any
  ALetter
  CR
  Double_Quote
  Extend
  ExtendNumLet
  Format
  Hebrew_Letter
  Katakana
  LF
  MidLetter
  MidNum
  MidNumLet
  Newline
  Numeric
  Regional_Indicator
  Single_Quote
  WSegSpace
  ZWJ
} derive(Eq)

///|
let word_cats : ReadOnlyArray[WordCat] = word_cat_names.map(fn(name) {
  match name {
    "WC_ALetter" => ALetter
    "WC_CR" => CR
    "WC_Double_Quote" => Double_Quote
    "WC_Extend" => Extend
    "WC_ExtendNumLet" => ExtendNumLet
    "WC_Format" => Format
    "WC_Hebrew_Letter" => Hebrew_Letter
    "WC_Katakana" => Katakana
    "WC_LF" => LF
    "WC_MidLetter" => MidLetter
    "WC_MidNum" => MidNum
    "WC_MidNumLet" => MidNumLet
    "WC_Newline" => Newline
    "WC_Numeric" => Numeric
    "WC_Regional_Indicator" => Regional_Indicator
    "WC_Single_Quote" => Single_Quote
    "WC_WSegSpace" => WSegSpace
    "WC_ZWJ" => ZWJ
    _ => Any
  }
})

///|
fn word_category(c : Int) -> WordCat {
  word_cats[in_valued(word_cat_table, c, 0)]
}

///|
fn is_emoji(c : Int) -> Bool {
  in_valued(emoji_cat_table, c, 0) == 1
}

///|
/// unicode-segmentation's `util::is_alphanumeric` (`Alphabetic` or `N`).
fn seg_is_alphanumeric(c : Int) -> Bool {
  if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') {
    return true
  }
  in_valued(seg_alphabetic_table, c, 0) == 1 ||
  in_valued(seg_n_table, c, 0) == 1
}

///|
// state machine for word boundary rules
priv enum WordBoundsState {
  Start
  Letter
  HLetter
  Numeric
  Katakana
  ExtendNumLet
  Regional(RegionalState)
  FormatExtend(FormatExtendType)
  Zwj
  Emoji
  WSegSpace
} derive(Eq)

///|
// subtypes for FormatExtend state in UWordBoundsState
// (`AcceptAny` is never constructed and omitted.)
priv enum FormatExtendType {
  AcceptNone
  RequireLetter
  RequireHLetter
  AcceptQLetter
  RequireNumeric
} derive(Eq)

///|
// (`Unknown` only occurs on backward iteration, which is not ported.)
priv enum RegionalState {
  Half
  Full
} derive(Eq)

///|
/// The length (in UTF-16 code units) of the next word-bound segment of
/// `s`, and the category to cache for the next call (`UWordBounds::next`).
fn next_word_bound(s : StringView, cached : WordCat?) -> (Int, WordCat?) {
  let mut self_cat = cached
  let mut take_curr = true
  let mut take_cat = true
  let mut idx = 0
  let mut saveidx = 0
  let mut state : WordBoundsState = Start
  let mut cat : WordCat = Any
  let mut savecat : WordCat = Any
  let len = s.length()

  // The category of the char after the one at `idx`.
  fn get_next_cat(s : StringView, idx : Int) -> WordCat? {
    let { idx: nidx, .. } = decode_at(s, idx)
    if nidx < s.length() {
      let { cp: nch, .. } = decode_at(s, nidx)
      Some(word_category(nch))
    } else {
      None
    }
  }

  // If extend/format/zwj were skipped. Handles precedence of WB3d over WB4
  let mut skipped_format_extend = false
  let mut curr = 0
  while curr < len {
    let { cp: ch, idx: next, } = decode_at(s, curr)
    idx = curr
    curr = next
    // Whether or not the previous category was ZWJ
    // ZWJs get collapsed, so this handles precedence of WB3c over WB4
    let prev_zwj = cat == ZWJ
    // if there's a category cached, grab it
    cat = match self_cat {
      None => word_category(ch)
      Some(c) => {
        self_cat = None
        c
      }
    }
    take_cat = true

    // handle rule WB4
    // just skip all format, extend, and zwj chars
    // note that Start is a special case: if there's a bunch of Format | Extend
    // characters at the beginning of a block of text, dump them out as one unit.
    //
    // (This is not obvious from the wording of UAX#29, but if you look at the
    // test cases http://www.unicode.org/Public/UNIDATA/auxiliary/WordBreakTest.txt
    // then the "correct" interpretation of WB4 becomes apparent.)
    if state != Start {
      match cat {
        Extend | Format | ZWJ => {
          skipped_format_extend = true
          continue
        }
        _ => ()
      }
    }

    // rule WB3c
    // WB4 makes all ZWJs collapse into the previous state
    // but you can still be in a Zwj state if you started with Zwj
    //
    // This means that an EP + Zwj will collapse into EP, which is wrong,
    // since EP+EP is not a boundary but EP+ZWJ+EP is
    //
    // Thus, we separately keep track of whether or not the last character
    // was a ZWJ. This is an additional bit of state tracked outside of the
    // state enum; the state enum represents the last non-zwj state encountered.
    // When prev_zwj is true, for the purposes of WB3c, we are in the Zwj state,
    // however we are in the previous state for the purposes of all other rules.
    if prev_zwj && is_emoji(ch) {
      state = Emoji
      continue
    }
    // Don't use `continue` in this match without updating `cat`
    state = match state {
      Start if cat == CR => {
        idx += match get_next_cat(s, idx) {
          Some(LF) => 1 // rule WB3
          _ => 0
        }
        break // rule WB3a
      }
      Start =>
        match cat {
          ALetter => Letter // rule WB5, WB6, WB9, WB13a
          Hebrew_Letter => HLetter // rule WB5, WB6, WB7a, WB7b, WB9, WB13a
          WordCat::Numeric => Numeric // rule WB8, WB10, WB12, WB13a
          WordCat::Katakana => Katakana // rule WB13, WB13a
          WordCat::ExtendNumLet => ExtendNumLet // rule WB13a, WB13b
          Regional_Indicator => Regional(Half) // rule WB13c
          LF | Newline => break // rule WB3a
          ZWJ => Zwj // rule WB3c
          WordCat::WSegSpace => WSegSpace // rule WB3d
          _ => {
            if get_next_cat(s, idx) is Some(ncat) {
              // rule WB4
              if ncat == Format || ncat == Extend || ncat == ZWJ {
                state = FormatExtend(AcceptNone)
                self_cat = Some(ncat)
                continue
              }
            }
            break // rule WB999
          }
        }
      WSegSpace =>
        match cat {
          WordCat::WSegSpace if !skipped_format_extend => WSegSpace
          _ => {
            take_curr = false
            break
          }
        }
      Zwj => {
        // We already handle WB3c above.
        take_curr = false
        break
      }
      Letter | HLetter =>
        match cat {
          ALetter => Letter // rule WB5
          Hebrew_Letter => HLetter // rule WB5
          WordCat::Numeric => Numeric // rule WB9
          WordCat::ExtendNumLet => ExtendNumLet // rule WB13a
          Double_Quote if state == HLetter => {
            savecat = cat
            saveidx = idx
            FormatExtend(RequireHLetter) // rule WB7b
          }
          Single_Quote if state == HLetter => FormatExtend(AcceptQLetter) // rule WB7a
          MidLetter | MidNumLet | Single_Quote => {
            savecat = cat
            saveidx = idx
            FormatExtend(RequireLetter) // rule WB6
          }
          _ => {
            take_curr = false
            break
          }
        }
      Numeric =>
        match cat {
          WordCat::Numeric => Numeric // rule WB8
          ALetter => Letter // rule WB10
          Hebrew_Letter => HLetter // rule WB10
          WordCat::ExtendNumLet => ExtendNumLet // rule WB13a
          MidNum | MidNumLet | Single_Quote => {
            savecat = cat
            saveidx = idx
            FormatExtend(RequireNumeric) // rule WB12
          }
          _ => {
            take_curr = false
            break
          }
        }
      Katakana =>
        match cat {
          WordCat::Katakana => Katakana // rule WB13
          WordCat::ExtendNumLet => ExtendNumLet // rule WB13a
          _ => {
            take_curr = false
            break
          }
        }
      ExtendNumLet =>
        match cat {
          WordCat::ExtendNumLet => ExtendNumLet // rule WB13a
          ALetter => Letter // rule WB13b
          Hebrew_Letter => HLetter // rule WB13b
          WordCat::Numeric => Numeric // rule WB13b
          WordCat::Katakana => Katakana // rule WB13b
          _ => {
            take_curr = false
            break
          }
        }
      Regional(Full) => {
        // if it reaches here we've gone too far,
        // a full flag can only compose with ZWJ/Extend/Format
        // proceeding it.
        take_curr = false
        break
      }
      Regional(Half) =>
        match cat {
          Regional_Indicator => Regional(Full) // rule WB13c
          _ => {
            take_curr = false
            break
          }
        }
      Emoji => {
        // We already handle WB3c above. If you've reached this point, the emoji sequence is over.
        take_curr = false
        break
      }
      FormatExtend(t) =>
        // handle FormatExtends depending on what type
        match t {
          RequireNumeric if cat == WordCat::Numeric => Numeric // rule WB11
          RequireLetter | AcceptQLetter if cat == ALetter => Letter // rule WB7
          RequireLetter | AcceptQLetter if cat == Hebrew_Letter => HLetter // WB7a
          RequireHLetter if cat == Hebrew_Letter => HLetter // rule WB7b
          AcceptNone | AcceptQLetter => {
            take_curr = false // emit all the Format|Extend characters
            take_cat = false
            break
          }
          _ => break // rewind (in if statement below)
        }
    }
  }
  if state is FormatExtend(t) {
    // we were looking for something and didn't find it; we have to back up
    if t == RequireLetter || t == RequireHLetter || t == RequireNumeric {
      idx = saveidx
      cat = savecat
      take_curr = false
    }
  }
  let next_cat = if take_curr {
    let { idx: next, .. } = decode_at(s, idx)
    idx = next
    None
  } else if take_cat {
    Some(cat)
  } else {
    None
  }
  (idx, next_cat)
}

///|
/// Returns the substrings of `s` separated on UAX#29 word boundaries
/// (unicode-segmentation's `split_word_bounds`). Concatenated, they yield
/// the original string.
pub fn split_word_bounds(s : StringView) -> Array[StringView] {
  let out = []
  let mut rest = s
  let mut cat = None
  while rest.length() > 0 {
    let (len, next_cat) = next_word_bound(rest, cat)
    out.push(rest.view(end_offset=len))
    rest = rest.view(start_offset=len)
    cat = next_cat
  }
  out
}

///|
/// The words of `s` according to UAX#29 word boundaries, i.e. the word-bound
/// segments that contain an alphanumeric character (unicode-segmentation's
/// `unicode_words`).
pub fn unicode_words(s : StringView) -> Array[StringView] {
  split_word_bounds(s).filter(w => {
    for i = 0; i < w.length(); {
      let { cp: c, idx: next, } = decode_at(w, i)
      if seg_is_alphanumeric(c) {
        return true
      }
      continue next
    }
    false
  })
}
