// Port of rustybuzz 0.20.1 `src/hb/unicode.rs`.
//
// Codepoints are `Int`s. General categories use rustybuzz's `hb_gc`
// numbering (`GC_*` below). The properties come from the `unicode` package
// (generated from the crates rustybuzz uses).

// hb_gc

///|
pub const GC_CONTROL : Int = 0

///|
pub const GC_FORMAT : Int = 1

///|
pub const GC_UNASSIGNED : Int = 2

///|
pub const GC_PRIVATE_USE : Int = 3

///|
pub const GC_SURROGATE : Int = 4

///|
pub const GC_LOWERCASE_LETTER : Int = 5

///|
pub const GC_MODIFIER_LETTER : Int = 6

///|
pub const GC_OTHER_LETTER : Int = 7

///|
pub const GC_TITLECASE_LETTER : Int = 8

///|
pub const GC_UPPERCASE_LETTER : Int = 9

///|
pub const GC_SPACING_MARK : Int = 10

///|
pub const GC_ENCLOSING_MARK : Int = 11

///|
pub const GC_NON_SPACING_MARK : Int = 12

///|
pub const GC_DECIMAL_NUMBER : Int = 13

///|
pub const GC_LETTER_NUMBER : Int = 14

///|
pub const GC_OTHER_NUMBER : Int = 15

///|
pub const GC_CONNECT_PUNCTUATION : Int = 16

///|
pub const GC_DASH_PUNCTUATION : Int = 17

///|
pub const GC_CLOSE_PUNCTUATION : Int = 18

///|
pub const GC_FINAL_PUNCTUATION : Int = 19

///|
pub const GC_INITIAL_PUNCTUATION : Int = 20

///|
pub const GC_OTHER_PUNCTUATION : Int = 21

///|
pub const GC_OPEN_PUNCTUATION : Int = 22

///|
pub const GC_CURRENCY_SYMBOL : Int = 23

///|
pub const GC_MODIFIER_SYMBOL : Int = 24

///|
pub const GC_MATH_SYMBOL : Int = 25

///|
pub const GC_OTHER_SYMBOL : Int = 26

///|
pub const GC_LINE_SEPARATOR : Int = 27

///|
pub const GC_PARAGRAPH_SEPARATOR : Int = 28

///|
pub const GC_SPACE_SEPARATOR : Int = 29

///|
fn gc_is_mark(gc : Int) -> Bool {
  gc == GC_SPACING_MARK || gc == GC_ENCLOSING_MARK || gc == GC_NON_SPACING_MARK
}

///|
fn gc_is_letter(gc : Int) -> Bool {
  gc == GC_LOWERCASE_LETTER ||
  gc == GC_MODIFIER_LETTER ||
  gc == GC_OTHER_LETTER ||
  gc == GC_TITLECASE_LETTER ||
  gc == GC_UPPERCASE_LETTER
}

// Space estimates based on:
// https://unicode.org/charts/PDF/U2000.pdf
// https://docs.microsoft.com/en-us/typography/develop/character-design-standards/whitespace
// (hb_unicode_funcs_t::space_t)

///|
const NOT_SPACE : Int = 0

///|
const SPACE_EM : Int = 1

///|
const SPACE_EM_2 : Int = 2

///|
const SPACE_EM_3 : Int = 3

///|
const SPACE_EM_4 : Int = 4

///|
const SPACE_EM_5 : Int = 5

///|
const SPACE_EM_6 : Int = 6

///|
const SPACE_EM_16 : Int = 16

///|
/// 4/18th of an EM!
const SPACE_4_EM_18 : Int = 17

///|
const SPACE : Int = 18

///|
const SPACE_FIGURE : Int = 19

///|
const SPACE_PUNCTUATION : Int = 20

///|
const SPACE_NARROW : Int = 21

///|
/// Modified combining classes (`MODIFIED_COMBINING_CLASS`): the identity,
/// except for the Hebrew, Arabic, Telugu, Thai, Lao and Tibetan permutations
/// documented in rustybuzz's `modified_combining_class` module.
let modified_combining_class_table : FixedArray[Int] = {
  let t = FixedArray::makei(256, i => i)
  // Hebrew
  //
  // We permute the "fixed-position" classes 10-26 into the order
  // described in the SBL Hebrew manual:
  //
  // https://www.sbl-site.org/Fonts/SBLHebrewUserManual1.5x.pdf
  //
  // (as recommended by:
  //  https://forum.fontlab.com/archive-old-microsoft-volt-group/vista-and-diacritic-ordering/msg22823/)
  //
  // More details here:
  // https://bugzilla.mozilla.org/show_bug.cgi?id=662055
  t[10] = 22 // sheva
  t[11] = 15 // hataf segol
  t[12] = 16 // hataf patah
  t[13] = 17 // hataf qamats
  t[14] = 23 // hiriq
  t[15] = 18 // tsere
  t[16] = 19 // segol
  t[17] = 20 // patah
  t[18] = 21 // qamats & qamats qatan
  t[19] = 14 // holam & holam haser for vav
  t[20] = 24 // qubuts
  t[21] = 12 // dagesh
  t[22] = 25 // meteg
  t[23] = 13 // rafe
  t[24] = 10 // shin dot
  t[25] = 11 // sin dot
  t[26] = 26 // point varika

  // Arabic
  //
  // Modify to move Shadda (ccc=33) before other marks.  See:
  // https://unicode.org/faq/normalization.html#8
  // https://unicode.org/faq/normalization.html#9
  t[27] = 28 // fathatan
  t[28] = 29 // dammatan
  t[29] = 30 // kasratan
  t[30] = 31 // fatha
  t[31] = 32 // damma
  t[32] = 33 // kasra
  t[33] = 27 // shadda
  t[34] = 34 // sukun
  t[35] = 35 // superscript alef

  // Syriac
  t[36] = 36 // superscript alaph

  // Telugu
  //
  // Modify Telugu length marks (ccc=84, ccc=91).
  // These are the only matras in the main Indic scripts range that have
  // a non-zero ccc.  That makes them reorder with the Halant that is
  // ccc=9.  Just zero them, we don't need them in our Indic shaper.
  t[84] = 0 // length mark
  t[91] = 0 // ai length mark

  // Thai
  //
  // Modify U+0E38 and U+0E39 (ccc=103) to be reordered before U+0E3A (ccc=9).
  // Assign 3, which is unassigned otherwise.
  // Uniscribe does this reordering too.
  t[103] = 3 // sara u / sara uu
  t[107] = 107 // mai *

  // Lao
  t[118] = 118 // sign u / sign uu
  t[122] = 122 // mai *

  // Tibetan
  //
  // In case of multiple vowel-signs, use u first (but after achung)
  // this allows Dzongkha multi-vowel shortcuts to render correctly
  t[129] = 129 // sign aa
  t[130] = 132 // sign i
  t[132] = 131 // sign u
  t
}

///|
/// The rustybuzz script of a codepoint (`CharExt::script`).
fn char_script(u : Int) -> Script {
  Script(@otf.Tag::from_str(@unicode.rb_script_tag(u)))
}

///|
fn char_general_category(u : Int) -> Int {
  @unicode.rb_general_category(u)
}

///|
fn char_space_fallback(u : Int) -> Int {
  // All GC=Zs chars that can use a fallback.
  match u {
    0x0020 => SPACE // SPACE
    0x00A0 => SPACE // NO-BREAK SPACE
    0x2000 => SPACE_EM_2 // EN QUAD
    0x2001 => SPACE_EM // EM QUAD
    0x2002 => SPACE_EM_2 // EN SPACE
    0x2003 => SPACE_EM // EM SPACE
    0x2004 => SPACE_EM_3 // THREE-PER-EM SPACE
    0x2005 => SPACE_EM_4 // FOUR-PER-EM SPACE
    0x2006 => SPACE_EM_6 // SIX-PER-EM SPACE
    0x2007 => SPACE_FIGURE // FIGURE SPACE
    0x2008 => SPACE_PUNCTUATION // PUNCTUATION SPACE
    0x2009 => SPACE_EM_5 // THIN SPACE
    0x200A => SPACE_EM_16 // HAIR SPACE
    0x202F => SPACE_NARROW // NARROW NO-BREAK SPACE
    0x205F => SPACE_4_EM_18 // MEDIUM MATHEMATICAL SPACE
    0x3000 => SPACE_EM // IDEOGRAPHIC SPACE
    _ => NOT_SPACE // OGHAM SPACE MARK
  }
}

///|
fn char_modified_combining_class(u : Int) -> Int {
  // Reorder SAKOT to ensure it comes after any tone marks.
  if u == 0x1A60 {
    return 254
  }

  // Reorder PADMA to ensure it comes after any vowel marks.
  if u == 0x0FC6 {
    return 254
  }

  // Reorder TSA -PHRU to reorder before U+0F74
  if u == 0x0F39 {
    return 127
  }
  modified_combining_class_table[@unicode.rb_combining_class(u)]
}

///|
fn char_mirrored(u : Int) -> Int? {
  @unicode.rb_mirrored(u)
}

///|
fn char_is_emoji_extended_pictographic(u : Int) -> Bool {
  // Generated by scripts/gen-unicode-is-emoji-ext-pict.py
  let table = emoji_extended_pictographic_table
  let n = table.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if u < table[2 * mid] {
      continue lo, mid
    } else if u > table[2 * mid + 1] {
      continue mid + 1, hi
    } else {
      break true
    }
  } nobreak {
    false
  }
}

///|
/// Default_Ignorable codepoints:
///
/// Note: While U+115F, U+1160, U+3164 and U+FFA0 are Default_Ignorable,
/// we do NOT want to hide them, as the way Uniscribe has implemented them
/// is with regular spacing glyphs, and that's the way fonts are made to work.
/// As such, we make exceptions for those four.
/// Also ignoring U+1BCA0..1BCA3. https://github.com/harfbuzz/harfbuzz/issues/503
fn char_is_default_ignorable(ch : Int) -> Bool {
  let plane = ch >> 16
  if plane == 0 {
    // BMP
    let page = ch >> 8
    match page {
      0x00 => ch == 0x00AD
      0x03 => ch == 0x034F
      0x06 => ch == 0x061C
      0x17 => ch >= 0x17B4 && ch <= 0x17B5
      0x18 => ch >= 0x180B && ch <= 0x180E
      0x20 =>
        (ch >= 0x200B && ch <= 0x200F) ||
        (ch >= 0x202A && ch <= 0x202E) ||
        (ch >= 0x2060 && ch <= 0x206F)
      0xFE => (ch >= 0xFE00 && ch <= 0xFE0F) || ch == 0xFEFF
      0xFF => ch >= 0xFFF0 && ch <= 0xFFF8
      _ => false
    }
  } else {
    // Other planes
    match plane {
      0x01 => ch >= 0x1D173 && ch <= 0x1D17A
      0x0E => ch >= 0xE0000 && ch <= 0xE0FFF
      _ => false
    }
  }
}

///|
fn char_is_variation_selector(ch : Int) -> Bool {
  // U+180B..180D, U+180F MONGOLIAN FREE VARIATION SELECTORs are handled in the
  // Arabic shaper. No need to match them here.
  (ch >= 0x0FE00 && ch <= 0x0FE0F) || // VARIATION SELECTOR - 1..16
  (ch >= 0xE0100 && ch <= 0xE01EF) // VARIATION SELECTOR - 17..256
}

///|
fn char_vertical(u : Int) -> Int? {
  match u >> 8 {
    0x20 =>
      match u {
        0x2013 => Some(0xfe32) // EN DASH
        0x2014 => Some(0xfe31) // EM DASH
        0x2025 => Some(0xfe30) // TWO DOT LEADER
        0x2026 => Some(0xfe19) // HORIZONTAL ELLIPSIS
        _ => None
      }
    0x30 =>
      match u {
        0x3001 => Some(0xfe11) // IDEOGRAPHIC COMMA
        0x3002 => Some(0xfe12) // IDEOGRAPHIC FULL STOP
        0x3008 => Some(0xfe3f) // LEFT ANGLE BRACKET
        0x3009 => Some(0xfe40) // RIGHT ANGLE BRACKET
        0x300a => Some(0xfe3d) // LEFT DOUBLE ANGLE BRACKET
        0x300b => Some(0xfe3e) // RIGHT DOUBLE ANGLE BRACKET
        0x300c => Some(0xfe41) // LEFT CORNER BRACKET
        0x300d => Some(0xfe42) // RIGHT CORNER BRACKET
        0x300e => Some(0xfe43) // LEFT WHITE CORNER BRACKET
        0x300f => Some(0xfe44) // RIGHT WHITE CORNER BRACKET
        0x3010 => Some(0xfe3b) // LEFT BLACK LENTICULAR BRACKET
        0x3011 => Some(0xfe3c) // RIGHT BLACK LENTICULAR BRACKET
        0x3014 => Some(0xfe39) // LEFT TORTOISE SHELL BRACKET
        0x3015 => Some(0xfe3a) // RIGHT TORTOISE SHELL BRACKET
        0x3016 => Some(0xfe17) // LEFT WHITE LENTICULAR BRACKET
        0x3017 => Some(0xfe18) // RIGHT WHITE LENTICULAR BRACKET
        _ => None
      }
    0xfe =>
      match u {
        0xfe4f => Some(0xfe34) // WAVY LOW LINE
        _ => None
      }
    0xff =>
      match u {
        0xff01 => Some(0xfe15) // FULLWIDTH EXCLAMATION MARK
        0xff08 => Some(0xfe35) // FULLWIDTH LEFT PARENTHESIS
        0xff09 => Some(0xfe36) // FULLWIDTH RIGHT PARENTHESIS
        0xff0c => Some(0xfe10) // FULLWIDTH COMMA
        0xff1a => Some(0xfe13) // FULLWIDTH COLON
        0xff1b => Some(0xfe14) // FULLWIDTH SEMICOLON
        0xff1f => Some(0xfe16) // FULLWIDTH QUESTION MARK
        0xff3b => Some(0xfe47) // FULLWIDTH LEFT SQUARE BRACKET
        0xff3d => Some(0xfe48) // FULLWIDTH RIGHT SQUARE BRACKET
        0xff3f => Some(0xfe33) // FULLWIDTH LOW LINE
        0xff5b => Some(0xfe37) // FULLWIDTH LEFT CURLY BRACKET
        0xff5d => Some(0xfe38) // FULLWIDTH RIGHT CURLY BRACKET
        _ => None
      }
    _ => None
  }
}

///|
const S_BASE : Int = 0xAC00

///|
const L_BASE : Int = 0x1100

///|
const V_BASE : Int = 0x1161

///|
const T_BASE : Int = 0x11A7

///|
const L_COUNT : Int = 19

///|
const V_COUNT : Int = 21

///|
const T_COUNT : Int = 28

///|
const N_COUNT : Int = 588 // V_COUNT * T_COUNT

///|
const S_COUNT : Int = 11172 // L_COUNT * N_COUNT

///|
fn compose(a : Int, b : Int) -> Int? {
  if compose_hangul(a, b) is Some(ab) {
    return Some(ab)
  }
  let table = composition_table
  let n = table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    let ma = table[3 * mid]
    let mb = table[3 * mid + 1]
    if a < ma || (a == ma && b < mb) {
      continue lo, mid
    } else if a > ma || (a == ma && b > mb) {
      continue mid + 1, hi
    } else {
      break Some(table[3 * mid + 2])
    }
  } nobreak {
    None
  }
}

///|
fn compose_hangul(a : Int, b : Int) -> Int? {
  let l = a
  let v = b
  if L_BASE <= l && l < L_BASE + L_COUNT && V_BASE <= v && v < V_BASE + V_COUNT {
    let r = S_BASE + (l - L_BASE) * N_COUNT + (v - V_BASE) * T_COUNT
    Some(r)
  } else if S_BASE <= l &&
    l <= S_BASE + S_COUNT - T_COUNT &&
    T_BASE <= v &&
    v < T_BASE + T_COUNT &&
    (l - S_BASE) % T_COUNT == 0 {
    let r = l + (v - T_BASE)
    Some(r)
  } else {
    None
  }
}

///|
/// Decomposes `ab` into `(a, b)` (`b` is 0 for singleton decompositions).
fn decompose(ab : Int) -> (Int, Int)? {
  if decompose_hangul(ab) is Some(ab) {
    return Some(ab)
  }
  let table = decomposition_table
  let n = table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    let m = table[3 * mid]
    if ab < m {
      continue lo, mid
    } else if ab > m {
      continue mid + 1, hi
    } else {
      break Some((table[3 * mid + 1], table[3 * mid + 2]))
    }
  } nobreak {
    None
  }
}

///|
fn decompose_hangul(ab : Int) -> (Int, Int)? {
  let si = ab - S_BASE
  if si < 0 || si >= S_COUNT {
    return None
  }
  if si % T_COUNT != 0 {
    // LV,T
    Some((S_BASE + si / T_COUNT * T_COUNT, T_BASE + si % T_COUNT))
  } else {
    // L,V
    Some((L_BASE + si / N_COUNT, V_BASE + si % N_COUNT / T_COUNT))
  }
}
