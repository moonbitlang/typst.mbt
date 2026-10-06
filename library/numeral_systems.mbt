// Port of `codex::numeral_systems` (typst/codex, rev 2e43ab9) and the parts
// of the `chinese-number` crate (0.7.8) it uses: various ways of displaying
// non-negative integers.

///|
/// A list of named numeral systems.
///
/// The underlying system of a named numeral system can be obtained with the
/// [NamedNumeralSystem::system] method.
pub(all) enum NamedNumeralSystem {
  /// Decimal positional notation using Western Arabic numerals.
  Arabic
  /// Circled decimal positional notation using Western Arabic numerals.
  CircledArabic
  /// Double circled decimal positional notation using Western Arabic
  /// numerals.
  DoubleCircledArabic
  /// Lowercase Latin letters.
  LowerLatin
  /// Uppercase Latin letters.
  UpperLatin
  /// Lowercase Roman numerals.
  LowerRoman
  /// Uppercase Roman numerals.
  UpperRoman
  /// Lowercase Greek numerals.
  LowerGreek
  /// Uppercase Greek numerals.
  UpperGreek
  /// Lowercase Armenian numerals.
  LowerArmenian
  /// Uppercase Armenian numerals.
  UpperArmenian
  /// Hebrew alphabetic numerals without a gershayim or geresh.
  Hebrew
  /// Everyday ordinary simplified Chinese numerals.
  LowerSimplifiedChinese
  /// Financial ("capital") ordinary simplified Chinese numerals.
  UpperSimplifiedChinese
  /// Everyday ordinary traditional Chinese numerals.
  LowerTraditionalChinese
  /// Financial ("capital") ordinary traditional Chinese numerals.
  UpperTraditionalChinese
  /// Hiragana in the gojūon order. Includes n but excludes wi and we.
  HiraganaAiueo
  /// Hiragana in the iroha order. Includes wi and we but excludes n.
  HiraganaIroha
  /// Katakana in the gojūon order. Includes n but excludes wi and we.
  KatakanaAiueo
  /// Katakana in the iroha order. Includes wi and we but excludes n.
  KatakanaIroha
  /// Korean jamo.
  KoreanJamo
  /// Korean syllables.
  KoreanSyllable
  /// Decimal positional notation using Eastern Arabic numerals.
  EasternArabic
  /// Arabic abjad numerals.
  ArabicAbjad
  /// Decimal positional notation using Persian numerals.
  Persian
  /// Decimal positional notation using Devanagari numerals.
  Devanagari
  /// Decimal positional notation using Tibetan numerals.
  Tibetan
  /// Decimal positional notation using Bengali numerals.
  Bengali
  /// Bengali letters.
  BengaliLetters
  /// Symbols: `*`, `†`, `‡`, `§`, `¶`, `‖`.
  Symbols
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NamedNumeralSystem with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NamedNumeralSystem with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NamedNumeralSystem with @debug.Debug::{to_repr}

///|
/// All named numeral systems, in declaration order.
pub fn NamedNumeralSystem::all() -> Array[NamedNumeralSystem] {
  [
    Arabic,
    CircledArabic,
    DoubleCircledArabic,
    LowerLatin,
    UpperLatin,
    LowerRoman,
    UpperRoman,
    LowerGreek,
    UpperGreek,
    LowerArmenian,
    UpperArmenian,
    Hebrew,
    LowerSimplifiedChinese,
    UpperSimplifiedChinese,
    LowerTraditionalChinese,
    UpperTraditionalChinese,
    HiraganaAiueo,
    HiraganaIroha,
    KatakanaAiueo,
    KatakanaIroha,
    KoreanJamo,
    KoreanSyllable,
    EasternArabic,
    ArabicAbjad,
    Persian,
    Devanagari,
    Tibetan,
    Bengali,
    BengaliLetters,
    Symbols,
  ]
}

///|
/// Returns the name of a named numeral system.
pub fn NamedNumeralSystem::name(self : NamedNumeralSystem) -> String {
  match self {
    Arabic => "arabic"
    CircledArabic => "arabic.o"
    DoubleCircledArabic => "arabic.oo"
    LowerLatin => "latin"
    UpperLatin => "Latin"
    LowerRoman => "roman"
    UpperRoman => "Roman"
    LowerGreek => "greek"
    UpperGreek => "Greek"
    LowerArmenian => "armenian"
    UpperArmenian => "Armenian"
    Hebrew => "hebrew"
    LowerSimplifiedChinese => "chinese.simple"
    UpperSimplifiedChinese => "Chinese.simple"
    LowerTraditionalChinese => "chinese.trad"
    UpperTraditionalChinese => "Chinese.trad"
    HiraganaAiueo => "hiragana.aiueo"
    HiraganaIroha => "hiragana.iroha"
    KatakanaAiueo => "katakana.aiueo"
    KatakanaIroha => "katakana.iroha"
    KoreanJamo => "korean.jamo"
    KoreanSyllable => "korean.syllable"
    EasternArabic => "arabic.eastern"
    ArabicAbjad => "arabic.abjad"
    Persian => "persian"
    Devanagari => "devanagari"
    Tibetan => "tibetan"
    Bengali => "bengali"
    BengaliLetters => "bengali.letter"
    Symbols => "symbol"
  }
}

///|
/// Returns the named numeral system associated with a name, if any.
pub fn NamedNumeralSystem::from_name(name : String) -> NamedNumeralSystem? {
  for system in NamedNumeralSystem::all() {
    if system.name() == name {
      return Some(system)
    }
  }
  None
}

///|
/// Returns the optional shorthand for a named numeral system.
///
/// A shorthand is a short string that identifies a named numeral system,
/// such as `"I"` for upper Roman numerals. Usually, this is the number one
/// represented in the system.
pub fn NamedNumeralSystem::shorthand(self : NamedNumeralSystem) -> String? {
  match self {
    Arabic => Some("1")
    CircledArabic => Some("①")
    DoubleCircledArabic => Some("⓵")
    LowerLatin => Some("a")
    UpperLatin => Some("A")
    LowerRoman => Some("i")
    UpperRoman => Some("I")
    LowerGreek => Some("α")
    UpperGreek => Some("Α")
    LowerArmenian => Some("ա")
    UpperArmenian => Some("Ա")
    Hebrew => Some("א")
    LowerSimplifiedChinese => Some("一")
    UpperSimplifiedChinese => Some("壹")
    LowerTraditionalChinese => None
    UpperTraditionalChinese => None
    HiraganaAiueo => Some("あ")
    HiraganaIroha => Some("い")
    KatakanaAiueo => Some("ア")
    KatakanaIroha => Some("イ")
    KoreanJamo => Some("ㄱ")
    KoreanSyllable => Some("가")
    EasternArabic => Some("١")
    ArabicAbjad => Some("أ")
    Persian => Some("۱")
    Devanagari => Some("१")
    Tibetan => Some("༡")
    Bengali => Some("১")
    BengaliLetters => Some("ক")
    Symbols => Some("*")
  }
}

///|
/// Returns the named numeral system associated with a shorthand.
pub fn NamedNumeralSystem::from_shorthand(
  shorthand : String,
) -> NamedNumeralSystem? {
  shorthand_systems.get(shorthand)
}

///|
/// The systems by shorthand (the first system with a given shorthand wins,
/// like upstream's linear search over all systems).
let shorthand_systems : Map[String, NamedNumeralSystem] = {
  let map = Map([])
  for system in NamedNumeralSystem::all() {
    if system.shorthand() is Some(shorthand) && !map.contains(shorthand) {
      map[shorthand] = system
    }
  }
  map
}

///|
let positional_arabic : ReadOnlyArray[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
]

///|
let fixed_circled_arabic : ReadOnlyArray[String] = [
  "⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩", "⑪",
  "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳", "㉑", "㉒", "㉓",
  "㉔", "㉕", "㉖", "㉗", "㉘", "㉙", "㉚", "㉛", "㉜", "㉝", "㉞", "㉟",
  "㊱", "㊲", "㊳", "㊴", "㊵", "㊶", "㊷", "㊸", "㊹", "㊺", "㊻", "㊼",
  "㊽", "㊾", "㊿",
]

///|
let zeroless_double_circled_arabic : ReadOnlyArray[String] = [
  "⓵", "⓶", "⓷", "⓸", "⓹", "⓺", "⓻", "⓼", "⓽", "⓾",
]

///|
let bijective_lower_latin : ReadOnlyArray[String] = [
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
  "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
]

///|
let bijective_upper_latin : ReadOnlyArray[String] = [
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
  "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]

///|
let additive_lower_roman : ReadOnlyArray[(String, UInt64)] = [
  ("m̅", 1000000),
  ("d̅", 500000),
  ("c̅", 100000),
  ("l̅", 50000),
  ("x̅", 10000),
  ("v̅", 5000),
  ("i̅v̅", 4000),
  ("m", 1000),
  ("cm", 900),
  ("d", 500),
  ("cd", 400),
  ("c", 100),
  ("xc", 90),
  ("l", 50),
  ("xl", 40),
  ("x", 10),
  ("ix", 9),
  ("v", 5),
  ("iv", 4),
  ("i", 1),
  ("n", 0),
]

///|
let additive_upper_roman : ReadOnlyArray[(String, UInt64)] = [
  ("M̅", 1000000),
  ("D̅", 500000),
  ("C̅", 100000),
  ("L̅", 50000),
  ("X̅", 10000),
  ("V̅", 5000),
  ("I̅V̅", 4000),
  ("M", 1000),
  ("CM", 900),
  ("D", 500),
  ("CD", 400),
  ("C", 100),
  ("XC", 90),
  ("L", 50),
  ("XL", 40),
  ("X", 10),
  ("IX", 9),
  ("V", 5),
  ("IV", 4),
  ("I", 1),
  ("N", 0),
]

///|
let additive_lower_greek : ReadOnlyArray[(String, UInt64)] = [
  ("͵θ", 9000),
  ("͵η", 8000),
  ("͵ζ", 7000),
  ("͵ϛ", 6000),
  ("͵ε", 5000),
  ("͵δ", 4000),
  ("͵γ", 3000),
  ("͵β", 2000),
  ("͵α", 1000),
  ("ϡ", 900),
  ("ω", 800),
  ("ψ", 700),
  ("χ", 600),
  ("φ", 500),
  ("υ", 400),
  ("τ", 300),
  ("σ", 200),
  ("ρ", 100),
  ("ϟ", 90),
  ("π", 80),
  ("ο", 70),
  ("ξ", 60),
  ("ν", 50),
  ("μ", 40),
  ("λ", 30),
  ("κ", 20),
  ("ι", 10),
  ("θ", 9),
  ("η", 8),
  ("ζ", 7),
  ("στ", 6),
  ("ε", 5),
  ("δ", 4),
  ("γ", 3),
  ("β", 2),
  ("α", 1),
  ("𐆊", 0),
]

///|
let additive_upper_greek : ReadOnlyArray[(String, UInt64)] = [
  ("͵Θ", 9000),
  ("͵Η", 8000),
  ("͵Ζ", 7000),
  ("͵Ϛ", 6000),
  ("͵Ε", 5000),
  ("͵Δ", 4000),
  ("͵Γ", 3000),
  ("͵Β", 2000),
  ("͵Α", 1000),
  ("Ϡ", 900),
  ("Ω", 800),
  ("Ψ", 700),
  ("Χ", 600),
  ("Φ", 500),
  ("Υ", 400),
  ("Τ", 300),
  ("Σ", 200),
  ("Ρ", 100),
  ("Ϟ", 90),
  ("Π", 80),
  ("Ο", 70),
  ("Ξ", 60),
  ("Ν", 50),
  ("Μ", 40),
  ("Λ", 30),
  ("Κ", 20),
  ("Ι", 10),
  ("Θ", 9),
  ("Η", 8),
  ("Ζ", 7),
  ("ΣΤ", 6),
  ("Ε", 5),
  ("Δ", 4),
  ("Γ", 3),
  ("Β", 2),
  ("Α", 1),
  ("𐆊", 0),
]

///|
let additive_lower_armenian : ReadOnlyArray[(String, UInt64)] = [
  ("ք", 9000),
  ("փ", 8000),
  ("ւ", 7000),
  ("ց", 6000),
  ("ր", 5000),
  ("տ", 4000),
  ("վ", 3000),
  ("ս", 2000),
  ("ռ", 1000),
  ("ջ", 900),
  ("պ", 800),
  ("չ", 700),
  ("ո", 600),
  ("շ", 500),
  ("ն", 400),
  ("յ", 300),
  ("մ", 200),
  ("ճ", 100),
  ("ղ", 90),
  ("ձ", 80),
  ("հ", 70),
  ("կ", 60),
  ("ծ", 50),
  ("խ", 40),
  ("լ", 30),
  ("ի", 20),
  ("ժ", 10),
  ("թ", 9),
  ("ը", 8),
  ("է", 7),
  ("զ", 6),
  ("ե", 5),
  ("դ", 4),
  ("գ", 3),
  ("բ", 2),
  ("ա", 1),
]

///|
let additive_upper_armenian : ReadOnlyArray[(String, UInt64)] = [
  ("Ք", 9000),
  ("Փ", 8000),
  ("Ւ", 7000),
  ("Ց", 6000),
  ("Ր", 5000),
  ("Տ", 4000),
  ("Վ", 3000),
  ("Ս", 2000),
  ("Ռ", 1000),
  ("Ջ", 900),
  ("Պ", 800),
  ("Չ", 700),
  ("Ո", 600),
  ("Շ", 500),
  ("Ն", 400),
  ("Յ", 300),
  ("Մ", 200),
  ("Ճ", 100),
  ("Ղ", 90),
  ("Ձ", 80),
  ("Հ", 70),
  ("Կ", 60),
  ("Ծ", 50),
  ("Խ", 40),
  ("Լ", 30),
  ("Ի", 20),
  ("Ժ", 10),
  ("Թ", 9),
  ("Ը", 8),
  ("Է", 7),
  ("Զ", 6),
  ("Ե", 5),
  ("Դ", 4),
  ("Գ", 3),
  ("Բ", 2),
  ("Ա", 1),
]

///|
let additive_hebrew : ReadOnlyArray[(String, UInt64)] = [
  ("ת", 400),
  ("ש", 300),
  ("ר", 200),
  ("ק", 100),
  ("צ", 90),
  ("פ", 80),
  ("ע", 70),
  ("ס", 60),
  ("נ", 50),
  ("מ", 40),
  ("ל", 30),
  ("כ", 20),
  ("יט", 19),
  ("יח", 18),
  ("יז", 17),
  ("טז", 16),
  ("טו", 15),
  ("י", 10),
  ("ט", 9),
  ("ח", 8),
  ("ז", 7),
  ("ו", 6),
  ("ה", 5),
  ("ד", 4),
  ("ג", 3),
  ("ב", 2),
  ("א", 1),
]

///|
let bijective_hiragana_aiueo : ReadOnlyArray[String] = [
  "あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ", "さ", "し",
  "す", "せ", "そ", "た", "ち", "つ", "て", "と", "な", "に", "ぬ", "ね",
  "の", "は", "ひ", "ふ", "へ", "ほ", "ま", "み", "む", "め", "も", "や",
  "ゆ", "よ", "ら", "り", "る", "れ", "ろ", "わ", "を", "ん",
]

///|
let bijective_hiragana_iroha : ReadOnlyArray[String] = [
  "い", "ろ", "は", "に", "ほ", "へ", "と", "ち", "り", "ぬ", "る", "を",
  "わ", "か", "よ", "た", "れ", "そ", "つ", "ね", "な", "ら", "む", "う",
  "ゐ", "の", "お", "く", "や", "ま", "け", "ふ", "こ", "え", "て", "あ",
  "さ", "き", "ゆ", "め", "み", "し", "ゑ", "ひ", "も", "せ", "す",
]

///|
let bijective_katakana_aiueo : ReadOnlyArray[String] = [
  "ア", "イ", "ウ", "エ", "オ", "カ", "キ", "ク", "ケ", "コ", "サ", "シ",
  "ス", "セ", "ソ", "タ", "チ", "ツ", "テ", "ト", "ナ", "ニ", "ヌ", "ネ",
  "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "マ", "ミ", "ム", "メ", "モ", "ヤ",
  "ユ", "ヨ", "ラ", "リ", "ル", "レ", "ロ", "ワ", "ヲ", "ン",
]

///|
let bijective_katakana_iroha : ReadOnlyArray[String] = [
  "イ", "ロ", "ハ", "ニ", "ホ", "ヘ", "ト", "チ", "リ", "ヌ", "ル", "ヲ",
  "ワ", "カ", "ヨ", "タ", "レ", "ソ", "ツ", "ネ", "ナ", "ラ", "ム", "ウ",
  "ヰ", "ノ", "オ", "ク", "ヤ", "マ", "ケ", "フ", "コ", "エ", "テ", "ア",
  "サ", "キ", "ユ", "メ", "ミ", "シ", "ヱ", "ヒ", "モ", "セ", "ス",
]

///|
let bijective_korean_jamo : ReadOnlyArray[String] = [
  "ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ",
  "ㅍ", "ㅎ",
]

///|
let bijective_korean_syllable : ReadOnlyArray[String] = [
  "가", "나", "다", "라", "마", "바", "사", "아", "자", "차", "카", "타",
  "파", "하",
]

///|
let positional_eastern_arabic : ReadOnlyArray[String] = [
  "٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩",
]

///|
let bijective_arabic_abjad : ReadOnlyArray[String] = [
  "أ", "ب", "ج", "د", "ه\u{200D}", "و", "ز", "ح", "ط", "ي", "ك", "ل",
  "م", "ن", "س", "ع", "ف", "ص", "ق", "ر", "ش", "ت", "ث", "خ", "ذ", "ض",
  "ظ", "غ",
]

///|
let positional_persian : ReadOnlyArray[String] = [
  "۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹",
]

///|
let positional_devanagari : ReadOnlyArray[String] = [
  "०", "१", "२", "३", "४", "५", "६", "७", "८", "९",
]

///|
let positional_tibetan : ReadOnlyArray[String] = [
  "༠", "༡", "༢", "༣", "༤", "༥", "༦", "༧", "༨", "༩",
]

///|
let positional_bengali : ReadOnlyArray[String] = [
  "০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯",
]

///|
let bijective_bengali_letters : ReadOnlyArray[String] = [
  "ক", "খ", "গ", "ঘ", "ঙ", "চ", "ছ", "জ", "ঝ", "ঞ", "ট", "ঠ",
  "ড", "ঢ", "ণ", "ত", "থ", "দ", "ধ", "ন", "প", "ফ", "ব", "ভ",
  "ম", "য", "র", "ল", "শ", "ষ", "স", "হ",
]

///|
let symbolic_symbols : ReadOnlyArray[String] = [
  "*", "†", "‡", "§", "¶", "‖",
]

///|
/// Returns the underlying numeral system of a named numeral system.
pub fn NamedNumeralSystem::system(self : NamedNumeralSystem) -> NumeralSystem {
  match self {
    Arabic => Positional(positional_arabic)
    CircledArabic => Fixed(fixed_circled_arabic)
    DoubleCircledArabic => ZerolessFixed(zeroless_double_circled_arabic)
    LowerLatin => Bijective(bijective_lower_latin)
    UpperLatin => Bijective(bijective_upper_latin)
    LowerRoman => Additive(additive_lower_roman)
    UpperRoman => Additive(additive_upper_roman)
    LowerGreek => Additive(additive_lower_greek)
    UpperGreek => Additive(additive_upper_greek)
    LowerArmenian => Additive(additive_lower_armenian)
    UpperArmenian => Additive(additive_upper_armenian)
    Hebrew => Additive(additive_hebrew)
    LowerSimplifiedChinese => Chinese(Simple, Lower)
    UpperSimplifiedChinese => Chinese(Simple, Upper)
    LowerTraditionalChinese => Chinese(Traditional, Lower)
    UpperTraditionalChinese => Chinese(Traditional, Upper)
    HiraganaAiueo => Bijective(bijective_hiragana_aiueo)
    HiraganaIroha => Bijective(bijective_hiragana_iroha)
    KatakanaAiueo => Bijective(bijective_katakana_aiueo)
    KatakanaIroha => Bijective(bijective_katakana_iroha)
    KoreanJamo => Bijective(bijective_korean_jamo)
    KoreanSyllable => Bijective(bijective_korean_syllable)
    EasternArabic => Positional(positional_eastern_arabic)
    ArabicAbjad => Bijective(bijective_arabic_abjad)
    Persian => Positional(positional_persian)
    Devanagari => Positional(positional_devanagari)
    Tibetan => Positional(positional_tibetan)
    Bengali => Positional(positional_bengali)
    BengaliLetters => Bijective(bijective_bengali_letters)
    Symbols => Symbolic(symbolic_symbols)
  }
}

///|
/// The Chinese script variant (upstream `chinese_variant::ChineseVariant`).
pub(all) enum ChineseVariant {
  Traditional
  Simple
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ChineseVariant with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ChineseVariant with @debug.Debug::{to_repr}

///|
/// Upper or lower case Chinese numerals (upstream
/// `chinese_number::ChineseCase`).
pub(all) enum ChineseCase {
  Upper
  Lower
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ChineseCase with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ChineseCase with @debug.Debug::{to_repr}

///|
/// A numeral system.
pub(all) enum NumeralSystem {
  /// A positional numeral system with the given digits, from zero upwards.
  Positional(ReadOnlyArray[String])
  /// A bijective numeral system with the given digits, from one upwards.
  Bijective(ReadOnlyArray[String])
  /// An additive numeral system with the given numerals and their weights,
  /// in decreasing order of weight.
  Additive(ReadOnlyArray[(String, UInt64)])
  /// A symbolic numeral system: symbols are repeated to count past their
  /// number.
  Symbolic(ReadOnlyArray[String])
  /// A fixed set of symbols, from zero upwards.
  Fixed(ReadOnlyArray[String])
  /// A fixed set of symbols, from one upwards.
  ZerolessFixed(ReadOnlyArray[String])
  /// Chinese numerals.
  Chinese(ChineseVariant, ChineseCase)
}

///|
/// An error that occurs when representing a number in a numeral system.
pub(all) enum RepresentationError {
  /// Zero cannot be represented.
  Zero
  /// The number is too large.
  TooLarge
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RepresentationError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RepresentationError with @debug.Debug::{to_repr}

///|
/// Represents the number in this numeral system.
pub fn NumeralSystem::represent(
  self : NumeralSystem,
  number : UInt64,
) -> Result[String, RepresentationError] {
  match self {
    Positional(_) | Chinese(_, _) => ()
    Bijective(_) | Symbolic(_) => if number == 0 { return Err(Zero) }
    Additive(numerals) =>
      if number == 0 && !(numerals.last() is Some((_, 0))) {
        return Err(Zero)
      }
    Fixed(symbols) =>
      if number >= symbols.length().to_uint64() {
        return Err(TooLarge)
      }
    ZerolessFixed(symbols) => {
      if number == 0 {
        return Err(Zero)
      }
      if number > symbols.length().to_uint64() {
        return Err(TooLarge)
      }
    }
  }
  Ok(represent_number(self, number))
}

///|
/// Rust's `u64::ilog`.
fn ilog_u64(n : UInt64, base : UInt64) -> UInt {
  let mut n = n
  let mut log = 0U
  while n >= base {
    n = n / base
    log += 1
  }
  log
}

///|
/// Rust's `u64::pow` (wrapping).
fn pow_u64(base : UInt64, exp : UInt) -> UInt64 {
  let mut out = 1UL
  for _ in 0U..<exp {
    out = out * base
  }
  out
}

///|
/// Writes the digits of `n` (of the given size) positionally.
fn write_positional(
  f : StringBuilder,
  digits : ReadOnlyArray[String],
  n : UInt64,
  size : UInt,
) -> Unit {
  let radix = digits.length().to_uint64()
  let mut n = n
  // The place value of the most significant digit. For a number of size 1,
  // the MSD's place is the ones place, hence `- 1`.
  let mut msd_place = pow_u64(radix, size - 1)
  for _ in 0U..<size {
    let msd = n / msd_place
    f.write_string(digits[msd.to_int()])
    n -= msd * msd_place
    msd_place /= radix
  }
}

///|
fn represent_number(system : NumeralSystem, number : UInt64) -> String {
  let f = StringBuilder()
  match system {
    Positional(digits) => {
      let n = number
      if n == 0 {
        return digits[0]
      }
      let radix = digits.length().to_uint64()
      let size = ilog_u64(n, radix) + 1
      write_positional(f, digits, n, size)
    }
    Bijective(digits) => {
      let mut n = number
      let radix = digits.length().to_uint64()
      // Number of digits when representing `n` in this system.
      let size = ilog_u64((n + 1) * (radix - 1), radix)
      // Remove from `n` the number consisting of `size - 1` ones in
      // base-`radix`, and the print the result using the symbols as a
      // positional numeral system.
      n -= (pow_u64(radix, size) - 1) / (radix - 1)
      write_positional(f, digits, n, size)
    }
    Additive(numerals) => {
      let mut n = number
      if n == 0 {
        match numerals.last() {
          Some((numeral, 0)) => return numeral
          _ => abort("unreachable")
        }
      }
      // Greedily add any symbol that fits.
      for pair in numerals[:] {
        let (numeral, weight) = pair
        if weight == 0 || weight > n {
          continue
        }
        let reps = n / weight
        for _ in 0UL..<reps {
          f.write_string(numeral)
        }
        n -= weight * reps
      }
    }
    Symbolic(symbols) => {
      let n = number
      let symbol_count = symbols.length().to_uint64()
      let count = (n + symbol_count - 1) / symbol_count
      for _ in 0UL..<count {
        f.write_string(symbols[((n - 1) % symbol_count).to_int()])
      }
    }
    Fixed(symbols) => f.write_string(symbols[number.to_int()])
    ZerolessFixed(symbols) => f.write_string(symbols[(number - 1).to_int()])
    Chinese(variant, case_) =>
      f.write_string(
        unsigned_integer_to_chinese_ten_thousand(variant, case_, false, number),
      )
  }
  f.to_string()
}

// Port of `chinese-number`'s number-to-Chinese conversion (`chinese_characters.rs`,
// `number_to_chinese/functions.rs`).

///|
/// `ChineseNumber` digits 零..十.
fn chinese_number_str(
  ordinal : UInt64,
  variant : ChineseVariant,
  case_ : ChineseCase,
) -> String {
  match ordinal {
    0 => "零"
    1 =>
      match case_ {
        Upper => "壹"
        Lower => "一"
      }
    2 =>
      match case_ {
        Upper =>
          match variant {
            Traditional => "貳"
            Simple => "贰"
          }
        Lower => "二"
      }
    3 =>
      match case_ {
        Upper =>
          match variant {
            Traditional => "參"
            Simple => "叁"
          }
        Lower => "三"
      }
    4 =>
      match case_ {
        Upper => "肆"
        Lower => "四"
      }
    5 =>
      match case_ {
        Upper => "伍"
        Lower => "五"
      }
    6 =>
      match case_ {
        Upper =>
          match variant {
            Traditional => "陸"
            Simple => "陆"
          }
        Lower => "六"
      }
    7 =>
      match case_ {
        Upper => "柒"
        Lower => "七"
      }
    8 =>
      match case_ {
        Upper => "捌"
        Lower => "八"
      }
    9 =>
      match case_ {
        Upper => "玖"
        Lower => "九"
      }
    _ =>
      match case_ {
        Upper => "拾"
        Lower => "十"
      }
  }
}

///|
/// `ChineseExponent` ordinals: 分 角 個 十 百 千 萬 億 兆 京 垓 秭 穰 溝 澗 正 載 極.
let chinese_exponent_shi : Int = 3

///|
let chinese_exponent_bai : Int = 4

///|
let chinese_exponent_wan : Int = 6

///|
fn chinese_exponent_str(
  ordinal : Int,
  variant : ChineseVariant,
  case_ : ChineseCase,
) -> String {
  let trad = variant is Traditional
  match ordinal {
    0 => "分"
    1 => "角"
    2 => if trad { "個" } else { "个" }
    3 =>
      match case_ {
        Upper => "拾"
        Lower => "十"
      }
    4 =>
      match case_ {
        Upper => "佰"
        Lower => "百"
      }
    5 =>
      match case_ {
        Upper => "仟"
        Lower => "千"
      }
    6 => if trad { "萬" } else { "万" }
    7 => if trad { "億" } else { "亿" }
    8 => "兆"
    9 => "京"
    10 => "垓"
    11 => "秭"
    12 => "穰"
    13 => if trad { "溝" } else { "沟" }
    14 => if trad { "澗" } else { "涧" }
    15 => "正"
    16 => if trad { "載" } else { "载" }
    _ => if trad { "極" } else { "极" }
  }
}

///|
fn unsigned_integer_to_chinese_low(
  variant : ChineseVariant,
  case_ : ChineseCase,
  dependent : Bool,
  value : UInt64,
) -> String {
  let mut value = value
  let mut s = ""
  let mut lower_d = value % 10
  value /= 10
  if lower_d > 0 {
    s = s + chinese_number_str(lower_d, variant, case_)
  } else if value == 0 {
    return chinese_number_str(0, variant, case_)
  }
  let d = value % 10
  value /= 10
  if d > 0 {
    s = chinese_exponent_str(chinese_exponent_shi, variant, case_) + s
    if value > 0 || dependent || d > 1 {
      s = chinese_number_str(d, variant, case_) + s
    }
  }
  if value == 0 {
    return s
  }
  lower_d = d
  let mut i = chinese_exponent_bai
  while true {
    let d = value % 10
    value /= 10
    if d > 0 {
      if lower_d < 1 && !s.is_empty() {
        s = chinese_number_str(0, variant, case_) + s
      }
      s = chinese_exponent_str(i, variant, case_) + s
      s = chinese_number_str(d, variant, case_) + s
    }
    if value == 0 {
      break
    }
    lower_d = d
    i += 1
  }
  s
}

///|
fn unsigned_integer_to_chinese_ten_thousand(
  variant : ChineseVariant,
  case_ : ChineseCase,
  dependent : Bool,
  value : UInt64,
) -> String {
  let mut value = value
  let mut lower_d = value % 10000
  value /= 10000
  let mut has_more = value > 0
  let mut s = if lower_d > 0 {
    unsigned_integer_to_chinese_low(
      variant,
      case_,
      dependent || has_more,
      lower_d,
    )
  } else if value == 0 {
    return chinese_number_str(0, variant, case_)
  } else {
    ""
  }
  if !has_more {
    return s
  }
  let mut i = chinese_exponent_wan
  while true {
    let d = value % 10000
    value /= 10000
    has_more = value > 0
    if d > 0 {
      if lower_d < 1000 && !s.is_empty() {
        s = chinese_number_str(0, variant, case_) + s
      }
      s = chinese_exponent_str(i, variant, case_) + s
      s = unsigned_integer_to_chinese_low(
          variant,
          case_,
          dependent || has_more,
          d,
        ) +
        s
    }
    if !has_more {
      break
    }
    lower_d = d
    i += 1
  }
  s
}
