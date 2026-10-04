// Port of `unicode-bidi 0.3.18`: `char_data/mod.rs`, `data_source.rs` and
// `format_chars.rs`. The tables live in `tables_gen.mbt`.

///|
/// Represents values of the Unicode character property
/// [`Bidi_Class`](http://www.unicode.org/reports/tr44/#Bidi_Class), also
/// known as the *bidirectional character type*.
///
/// * <http://www.unicode.org/reports/tr9/#Bidirectional_Character_Types>
/// * <http://www.unicode.org/reports/tr44/#Bidi_Class_Values>
pub(all) enum BidiClass {
  AL
  AN
  B
  BN
  CS
  EN
  ES
  ET
  FSI
  L
  LRE
  LRI
  LRO
  NSM
  ON
  PDF
  PDI
  R
  RLE
  RLI
  RLO
  S
  WS
} derive(Eq, Hash, Debug)

///|
let bidi_classes : ReadOnlyArray[BidiClass] = [
  AL,
  AN,
  B,
  BN,
  CS,
  EN,
  ES,
  ET,
  FSI,
  L,
  LRE,
  LRI,
  LRO,
  NSM,
  ON,
  PDF,
  PDI,
  R,
  RLE,
  RLI,
  RLO,
  S,
  WS,
]

///|
/// Find the `BidiClass` of a single char.
pub fn bidi_class(c : Char) -> BidiClass {
  bidi_class_of(c.to_int())
}

///|
/// `bsearch_range_value_table` over `bidi_class_table`.
fn bidi_class_of(c : Int) -> BidiClass {
  let table = bidi_class_table
  let n = table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if c < table[3 * mid] {
      continue lo, mid
    } else if c > table[3 * mid + 1] {
      continue mid + 1, hi
    } else {
      break bidi_classes[table[3 * mid + 2]]
    }
  } nobreak {
    L
  }
  // UCD/extracted/DerivedBidiClass.txt: "All code points not explicitly listed
  // for Bidi_Class have the value Left_To_Right (L)."
}

///|
pub(all) struct BidiMatchedOpeningBracket {
  /// The corresponding opening bracket in this bracket pair, normalized
  ///
  /// In case of opening brackets, this will be the bracket itself, except for when the bracket
  /// is not normalized, in which case it will be the normalized form.
  opening : Int
  /// Whether or not the requested bracket was an opening bracket. True for opening
  is_open : Bool
} derive(Eq, Debug)

///|
/// If this character is a bracket according to BidiBrackets.txt,
/// return the corresponding *normalized* *opening bracket* of the pair,
/// and whether or not it itself is an opening bracket.
pub fn bidi_matched_opening_bracket(c : Int) -> BidiMatchedOpeningBracket? {
  let table = bidi_pairs_table
  for k = 0; k < table.length(); k = k + 3 {
    if table[k] == c || table[k + 1] == c {
      let skeleton = if table[k + 2] >= 0 { table[k + 2] } else { table[k] }
      return Some({ opening: skeleton, is_open: table[k] == c, })
    }
  }
  None
}

///|
pub fn is_rtl(bidi_class : BidiClass) -> Bool {
  bidi_class is (RLE | RLO | RLI)
}

///|
/// Directional formatting characters (`format_chars.rs`).
pub let char_alm : Int = 0x061C

///|
pub let char_lrm : Int = 0x200E

///|
pub let char_rlm : Int = 0x200F

///|
pub let char_lri : Int = 0x2066

///|
pub let char_rli : Int = 0x2067

///|
pub let char_fsi : Int = 0x2068

///|
pub let char_pdi : Int = 0x2069

///|
pub let char_lre : Int = 0x202A

///|
pub let char_rle : Int = 0x202B

///|
pub let char_pdf : Int = 0x202C

///|
pub let char_lro : Int = 0x202D

///|
pub let char_rlo : Int = 0x202E
