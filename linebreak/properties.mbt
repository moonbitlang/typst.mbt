// The `Line_Break` property of `icu_properties 2.3.0`
// (`CodePointMapData::<LineBreak>`), as used by upstream Typst's
// `LINEBREAK_DATA`. The data lives in `tables_gen.mbt`.

///|
/// Enumerated property `Line_Break`, in the order of the ICU4C `ULineBreak`
/// values.
pub(all) enum LineBreak {
  Unknown // XX
  Ambiguous // AI
  Alphabetic // AL
  BreakBoth // B2
  BreakAfter // BA
  BreakBefore // BB
  MandatoryBreak // BK
  ContingentBreak // CB
  ClosePunctuation // CL
  CombiningMark // CM
  CarriageReturn // CR
  Exclamation // EX
  Glue // GL
  Hyphen // HY
  Ideographic // ID
  Inseparable // IN
  InfixNumeric // IS
  LineFeed // LF
  Nonstarter // NS
  Numeric // NU
  OpenPunctuation // OP
  PostfixNumeric // PO
  PrefixNumeric // PR
  Quotation // QU
  ComplexContext // SA
  Surrogate // SG
  Space // SP
  BreakSymbols // SY
  ZWSpace // ZW
  NextLine // NL
  WordJoiner // WJ
  H2 // H2
  H3 // H3
  JL // JL
  JT // JT
  JV // JV
  CloseParenthesis // CP
  ConditionalJapaneseStarter // CJ
  HebrewLetter // HL
  RegionalIndicator // RI
  EBase // EB
  EModifier // EM
  ZWJ // ZWJ
  Aksara // AK
  AksaraPrebase // AP
  AksaraStart // AS
  ViramaFinal // VF
  Virama // VI
  UnambiguousHyphen // HH
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LineBreak with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LineBreak with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LineBreak with @debug.Debug::{to_repr}

///|
let line_break_values : ReadOnlyArray[LineBreak] = [
  Unknown,
  Ambiguous,
  Alphabetic,
  BreakBoth,
  BreakAfter,
  BreakBefore,
  MandatoryBreak,
  ContingentBreak,
  ClosePunctuation,
  CombiningMark,
  CarriageReturn,
  Exclamation,
  Glue,
  Hyphen,
  Ideographic,
  Inseparable,
  InfixNumeric,
  LineFeed,
  Nonstarter,
  Numeric,
  OpenPunctuation,
  PostfixNumeric,
  PrefixNumeric,
  Quotation,
  ComplexContext,
  Surrogate,
  Space,
  BreakSymbols,
  ZWSpace,
  NextLine,
  WordJoiner,
  H2,
  H3,
  JL,
  JT,
  JV,
  CloseParenthesis,
  ConditionalJapaneseStarter,
  HebrewLetter,
  RegionalIndicator,
  EBase,
  EModifier,
  ZWJ,
  Aksara,
  AksaraPrebase,
  AksaraStart,
  ViramaFinal,
  Virama,
  UnambiguousHyphen,
]

///|
/// The short name of a `Line_Break` value (e.g. `BK`).
pub fn LineBreak::short_name(self : LineBreak) -> String {
  for i, v in line_break_values[:] {
    if v == self {
      return line_break_names[i]
    }
  }
  "XX"
}

///|
/// The `Line_Break` property of a code point.
pub fn line_break(c : Int) -> LineBreak {
  let table = line_break_table
  let n = table.length() / 3
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if c < table[3 * mid] {
      continue lo, mid
    } else if c > table[3 * mid + 1] {
      continue mid + 1, hi
    } else {
      break line_break_values[table[3 * mid + 2]]
    }
  } nobreak {
    Unknown
  }
}
