// Port of `icu_segmenter 2.3.0`: `provider/v1.rs` (`RuleBreakData`,
// `BreakState`). The data lives in `tables_gen.mbt`.

///|
/// The struct that stores the break property data of a rule-based
/// segmenter.
// `sot_property` is only read by the `unstable` line segmenter and by the
// other rule segmenters (icu_segmenter 2.3.0 line/v3.rs:303,
// rule_segmenter_v1.rs:89), neither of which is ported.
#warnings("-unused_field")
priv struct RuleBreakData {
  /// Property table: code point -> property value (ranges `[lo, hi, v]`).
  property_table : ReadOnlyArray[Int32]
  /// Break state table (ULE bytes).
  break_state_table : ReadOnlyArray[Int32]
  /// Number of properties; should be the square root of the length of `break_state_table`.
  property_count : Int32
  /// The index of the last simple state for `break_state_table`. (A simple state has no
  /// `intermediate` nor `index` states.)
  last_codepoint_property : Int32
  /// The index of SOT (start of text) state for `break_state_table`.
  sot_property : Int32
  /// The index of EOT (end of text) state for `break_state_table`.
  eot_property : Int32
  /// The index of "SA" state (or 127 if the complex language isn't handled) for
  /// `break_state_table`.
  complex_property : Int32
}

///|
fn RuleBreakData::new(
  property_table : ReadOnlyArray[Int32],
  break_state_table : ReadOnlyArray[Int32],
  params : (Int32, Int32, Int32, Int32, Int32),
) -> RuleBreakData {
  let (
    property_count,
    last_codepoint_property,
    sot_property,
    eot_property,
    complex_property,
  ) = params
  {
    property_table,
    break_state_table,
    property_count,
    last_codepoint_property,
    sot_property,
    eot_property,
    complex_property,
  }
}

///|
/// The baked `SegmenterBreakLineV1` data.
let line_data : RuleBreakData = RuleBreakData::new(
  line_property_table, line_break_state_table, line_params,
)

///|
/// `SegmenterBreakLineV1` from Typst's custom CJ blob
/// (`typst_assets::icu::ICU_CJ_SEGMENT`).
let cj_line_data : RuleBreakData = RuleBreakData::new(
  cj_line_property_table, cj_line_break_state_table, cj_line_params,
)

///|
/// `property_table.get32(cp)`.
fn RuleBreakData::get32(self : RuleBreakData, c : Int32) -> Int32 {
  let table = self.property_table
  let n = table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if c < table[3 * mid] {
      continue lo, mid
    } else if c > table[3 * mid + 1] {
      continue mid + 1, hi
    } else {
      break table[3 * mid + 2]
    }
  } nobreak {
    0
  }
}

///|
fn RuleBreakData::get_break_state_from_table(
  self : RuleBreakData,
  left : Int32,
  right : Int32,
) -> BreakState {
  let idx = left * self.property_count + right
  // We use unwrap_or to fall back to the base case and prevent panics on bad data.
  if idx >= 0 && idx < self.break_state_table.length() {
    BreakState::from_unaligned(self.break_state_table[idx])
  } else {
    Keep
  }
}

///|
/// The struct that stores the break state.
priv enum BreakState {
  /// Break
  Break
  /// Keep rule
  Keep
  /// Non-matching rule
  NoMatch
  /// We have to look ahead one more character.
  Intermediate(Int32)
  /// Index of a state.
  Index(Int32)
} derive(Eq)

///|
fn BreakState::from_unaligned(unaligned : Int32) -> BreakState {
  match unaligned {
    253 => Break
    255 => Keep
    254 => NoMatch
    i if i >= 120 && i < 253 => Intermediate(i - 120)
    i => Index(i)
  }
}

///|
// Line break properties (`RuleBreakData::LINE_PROPERTY_*` in `line/v1.rs`).
const LINE_PROPERTY_AI : Int32 = 1

///|
const LINE_PROPERTY_AL : Int32 = 3

///|
const LINE_PROPERTY_BA : Int32 = 8

///|
const LINE_PROPERTY_BK : Int32 = 10

///|
const LINE_PROPERTY_CJ : Int32 = 12

///|
const LINE_PROPERTY_CM : Int32 = 14

///|
const LINE_PROPERTY_CR : Int32 = 16

///|
const LINE_PROPERTY_EX : Int32 = 19

///|
const LINE_PROPERTY_H2 : Int32 = 21

///|
const LINE_PROPERTY_H3 : Int32 = 22

///|
const LINE_PROPERTY_HY : Int32 = 24

///|
const LINE_PROPERTY_ID : Int32 = 25

///|
const LINE_PROPERTY_IN : Int32 = 27

///|
const LINE_PROPERTY_JL : Int32 = 29

///|
const LINE_PROPERTY_JT : Int32 = 30

///|
const LINE_PROPERTY_JV : Int32 = 31

///|
const LINE_PROPERTY_LF : Int32 = 32

///|
const LINE_PROPERTY_NL : Int32 = 33

///|
const LINE_PROPERTY_NS : Int32 = 34

///|
const LINE_PROPERTY_NU : Int32 = 35

///|
const LINE_PROPERTY_PO_EAW : Int32 = 39

///|
const LINE_PROPERTY_PR_EAW : Int32 = 41

///|
const LINE_PROPERTY_SP : Int32 = 47

///|
const LINE_PROPERTY_ZW : Int32 = 53

///|
const LINE_PROPERTY_ZWJ : Int32 = 54
