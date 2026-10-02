// Port of `codex::styling` (typst/codex `src/styling.rs`, rev pinned in
// `oracle/Cargo.toml`): styling of mathematical symbols in Unicode.
//
// `MathVariant` (the base styles used in Typst) lives in `math_funcs.mbt`
// because it is stored in `EquationElem::variant`.

///|
/// A style for mathematical symbols.
///
/// Notation in mathematics uses a basic set of characters which can be
/// styled. See the upstream documentation for the supported characters of
/// each style.
pub(all) enum MathStyle {
  /// Unstyled default. May be serif or sans-serif depending on the font.
  Plain
  /// Bold style. May be serif or sans-serif depending on the font.
  Bold
  /// Italic style. May be serif or sans-serif depending on the font.
  Italic
  /// Bold italic style. May be serif or sans-serif depending on the font.
  BoldItalic
  /// Script style. May be chancery or roundhand depending on the font.
  Script
  /// Bold script style. May be chancery or roundhand depending on the font.
  BoldScript
  /// Fraktur style. Also known as black-letter style.
  Fraktur
  /// Bold fraktur style. Also known as bold black-letter style.
  BoldFraktur
  /// Sans-serif style.
  SansSerif
  /// Bold sans-serif style.
  SansSerifBold
  /// Italic sans-serif style.
  SansSerifItalic
  /// Bold italic sans-serif style.
  SansSerifBoldItalic
  /// Monospace style.
  Monospace
  /// Isolated style.
  Isolated
  /// Initial style.
  Initial
  /// Tailed style.
  Tailed
  /// Stretched style.
  Stretched
  /// Looped style.
  Looped
  /// Double-struck style. Also known as open-face style or blackboard-bold
  /// style.
  DoubleStruck
  /// Italic double-struck style.
  DoubleStruckItalic
  /// Chancery variant of script style.
  Chancery
  /// Chancery variant of bold script style.
  BoldChancery
  /// Roundhand variant of script style.
  Roundhand
  /// Roundhand variant of bold script style.
  BoldRoundhand
  /// Hebrew letterlike math symbols.
  Hebrew
} derive(Eq, Hash, Debug)

///|
/// Selects an appropriate `MathStyle` for the given `char`.
///
/// If `variant` is `None`, then `Plain` is used. If `italic` is `None`, then
/// the TeX auto-italic rules are followed: only Latin and lowercase Greek are
/// italicized.
///
/// If the combination of inputs leads to a style which does not support the
/// given `char`, then fallback occurs, prioritizing the `MathVariant` given.
pub fn MathStyle::select(
  c : Char,
  variant : MathVariant?,
  bold : Bool,
  italic : Bool?,
) -> MathStyle {
  match (variant.unwrap_or(Plain), bold, italic) {
    (SansSerif, false, Some(false)) if styling_is_latin(c) => SansSerif
    (SansSerif, false, _) if styling_is_latin(c) => SansSerifItalic
    (SansSerif, true, Some(false)) if styling_is_latin(c) => SansSerifBold
    (SansSerif, true, _) if styling_is_latin(c) => SansSerifBoldItalic
    (SansSerif, false, _) if styling_is_digit(c) => SansSerif
    (SansSerif, true, _) if styling_is_digit(c) => SansSerifBold
    (SansSerif, _, Some(false)) if styling_is_greek(c) => SansSerifBold
    (SansSerif, _, Some(true)) if styling_is_greek(c) => SansSerifBoldItalic
    (SansSerif, _, None) if styling_is_upper_greek(c) => SansSerifBold
    (SansSerif, _, None) if styling_is_lower_greek(c) => SansSerifBoldItalic
    (Fraktur, false, _) if styling_is_latin(c) => Fraktur
    (Fraktur, true, _) if styling_is_latin(c) => BoldFraktur
    (Monospace, _, _) if styling_is_digit(c) || styling_is_latin(c) => Monospace
    (DoubleStruck, _, Some(true)) if c is ('D' | 'd' | 'e' | 'i' | 'j') =>
      DoubleStruckItalic
    (DoubleStruck, _, _) if styling_is_digit(c) ||
      styling_is_latin(c) ||
      c is ('∑' | 'Γ' | 'Π' | 'γ' | 'π') => DoubleStruck
    (Chancery, false, _) if styling_is_latin(c) => Chancery
    (Chancery, true, _) if styling_is_latin(c) => BoldChancery
    (Roundhand, false, _) if styling_is_latin(c) => Roundhand
    (Roundhand, true, _) if styling_is_latin(c) => BoldRoundhand
    (_, false, Some(true)) if styling_is_latin(c) || styling_is_greek(c) =>
      Italic
    (_, false, None) if styling_is_latin(c) || styling_is_lower_greek(c) =>
      Italic
    (_, true, Some(false)) if styling_is_latin(c) || styling_is_greek(c) => Bold
    (_, true, Some(true)) if styling_is_latin(c) || styling_is_greek(c) =>
      BoldItalic
    (_, true, None) if styling_is_latin(c) || styling_is_lower_greek(c) =>
      BoldItalic
    (_, true, None) if styling_is_upper_greek(c) => Bold
    (_, true, _) if styling_is_digit(c) || c is ('Ϝ' | 'ϝ') => Bold
    (_, _, Some(true) | None) if c is ('ı' | 'ȷ' | 'ħ') => Italic
    (_, _, Some(true) | None) if styling_is_hebrew(c) => Hebrew
    _ => Plain
  }
}

///|
/// Returns the styled conversion of a `char`, as specified by `style`, as
/// one or more `char`s (upstream `to_style`, collected into a string).
pub fn to_style(c : Char, style : MathStyle) -> String {
  let (first, second) : (Char, Char?) = match style {
    Plain => (c, None)
    Bold => (styling_to_bold(c), None)
    Italic => (styling_to_italic(c), None)
    BoldItalic => (styling_to_bold_italic(c), None)
    Script => (styling_to_script(c), None)
    BoldScript => (styling_to_bold_script(c), None)
    Fraktur => (styling_to_fraktur(c), None)
    BoldFraktur => (styling_to_bold_fraktur(c), None)
    SansSerif => (styling_to_sans_serif(c), None)
    SansSerifBold => (styling_to_sans_serif_bold(c), None)
    SansSerifItalic => (styling_to_sans_serif_italic(c), None)
    SansSerifBoldItalic => (styling_to_sans_serif_bold_italic(c), None)
    Monospace => (styling_to_monospace(c), None)
    Isolated => (styling_to_isolated(c), None)
    Initial => (styling_to_initial(c), None)
    Tailed => (styling_to_tailed(c), None)
    Stretched => (styling_to_stretched(c), None)
    Looped => (styling_to_looped(c), None)
    DoubleStruck => (styling_to_double_struck(c), None)
    DoubleStruckItalic => (styling_to_double_struck_italic(c), None)
    Chancery => styling_with_selector(styling_to_script(c), c, '\u{FE00}')
    BoldChancery =>
      styling_with_selector(styling_to_bold_script(c), c, '\u{FE00}')
    Roundhand => styling_with_selector(styling_to_script(c), c, '\u{FE01}')
    BoldRoundhand =>
      styling_with_selector(styling_to_bold_script(c), c, '\u{FE01}')
    Hebrew => (styling_to_hebrew(c), None)
  }
  match second {
    Some(s) => "\{first}\{s}"
    None => first.to_string()
  }
}

///|
/// Standardized Variation Sequences (Latin script characters).
fn styling_with_selector(
  styled : Char,
  c : Char,
  selector : Char,
) -> (Char, Char?) {
  (styled, if styling_is_latin(c) { Some(selector) } else { None })
}

// Functions which convert a `char` to its specified styled form (upstream
// `codex::styling::conversions`).

///|
fn styling_is_digit(c : Char) -> Bool {
  c is ('0'..='9')
}

///|
fn styling_is_latin(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z')
}

///|
fn styling_is_greek(c : Char) -> Bool {
  styling_is_upper_greek(c) || styling_is_lower_greek(c)
}

///|
fn styling_is_upper_greek(c : Char) -> Bool {
  c is ('Α'..='Ω' | '∇' | 'ϴ')
}

///|
fn styling_is_lower_greek(c : Char) -> Bool {
  c is ('α'..='ω' | '∂' | 'ϵ' | 'ϑ' | 'ϰ' | 'ϕ' | 'ϱ' | 'ϖ')
}

///|
fn styling_is_hebrew(c : Char) -> Bool {
  c is ('א'..='ד')
}

///|
/// The character given by adding `delta` to the codepoint of `c`.
fn styling_apply_delta(c : Char, delta : Int) -> Char {
  (c.to_int() + delta).unsafe_to_char()
}

///|
fn styling_to_bold(c : Char) -> Char {
  let delta = match c {
    // Mathematical Alphanumeric Symbols Block (U+1D400..U+1D7FF)
    // Bold symbols (U+1D400..U+1D433)
    'A'..='Z' => 0x1D3BF
    'a'..='z' => 0x1D3B9
    // Bold Greek symbols (U+1D6A8..U+1D6DA)
    'Α'..='Ρ' => 0x1D317
    'ϴ' => 0x1D2C5
    'Σ'..='Ω' => 0x1D317
    '∇' => 0x1B4BA
    'α'..='ω' => 0x1D311
    // Additional bold Greek symbols (U+1D6DB..U+1D6E1)
    '∂' => 0x1B4D9
    'ϵ' => 0x1D2E7
    'ϑ' => 0x1D30C
    'ϰ' => 0x1D2EE
    'ϕ' => 0x1D30A
    'ϱ' => 0x1D2EF
    'ϖ' => 0x1D30B
    // Additional bold Greek symbols (U+1D7CA..U+1D7CB)
    'Ϝ'..='ϝ' => 0x1D3EE
    // Bold digits (U+1D7CE..U+1D7D7)
    '0'..='9' => 0x1D79E
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_italic(c : Char) -> Char {
  let delta = match c {
    // Letterlike Symbols Block (U+2100..U+214F)
    // Letterlike symbols (U+2100..U+2134)
    'h' => 0x20A6
    'ħ' => 0x1FE8
    // Mathematical Alphanumeric Symbols Block (U+1D400..U+1D7FF)
    // Italic symbols (U+1D434..U+1D467)
    'A'..='Z' => 0x1D3F3
    'a'..='z' => 0x1D3ED
    // Dotless symbols (U+1D6A4..U+1D6A5)
    'ı' => 0x1D573
    'ȷ' => 0x1D46E
    // Italic Greek symbols (U+1D6E2..U+1D714)
    'Α'..='Ρ' => 0x1D351
    'ϴ' => 0x1D2FF
    'Σ'..='Ω' => 0x1D351
    '∇' => 0x1B4F4
    'α'..='ω' => 0x1D34B
    // Additional italic Greek symbols (U+1D715..U+1D71B)
    '∂' => 0x1B513
    'ϵ' => 0x1D321
    'ϑ' => 0x1D346
    'ϰ' => 0x1D328
    'ϕ' => 0x1D344
    'ϱ' => 0x1D329
    'ϖ' => 0x1D345
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_bold_italic(c : Char) -> Char {
  let delta = match c {
    // Bold italic symbols (U+1D468..U+1D49B)
    'A'..='Z' => 0x1D427
    'a'..='z' => 0x1D421
    // Bold italic Greek symbols (U+1D71C..U+1D74E)
    'Α'..='Ρ' => 0x1D38B
    'ϴ' => 0x1D339
    'Σ'..='Ω' => 0x1D38B
    '∇' => 0x1B52E
    'α'..='ω' => 0x1D385
    // Additional bold italic Greek symbols (U+1D74F..U+1D755)
    '∂' => 0x1B54D
    'ϵ' => 0x1D35B
    'ϑ' => 0x1D380
    'ϰ' => 0x1D362
    'ϕ' => 0x1D37E
    'ϱ' => 0x1D363
    'ϖ' => 0x1D37F
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_script(c : Char) -> Char {
  let delta = match c {
    // Letterlike symbols (U+2100..U+2134)
    'g' => 0x20A3
    'H' => 0x20C3
    'I' => 0x20C7
    'L' => 0x20C6
    'R' => 0x20C9
    'B' => 0x20EA
    'e' => 0x20CA
    'E'..='F' => 0x20EB
    'M' => 0x20E6
    'o' => 0x20C5
    // Script symbols (U+1D49C..U+1D4CF)
    'A'..='Z' => 0x1D45B
    'a'..='z' => 0x1D455
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_bold_script(c : Char) -> Char {
  let delta = match c {
    // Bold script symbols (U+1D4D0..U+1D503)
    'A'..='Z' => 0x1D48F
    'a'..='z' => 0x1D489
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_fraktur(c : Char) -> Char {
  let delta = match c {
    // Letterlike symbols (U+2100..U+2134)
    'H' => 0x20C4
    'I' => 0x20C8
    'R' => 0x20CA
    'Z' => 0x20CE
    'C' => 0x20EA
    // Fraktur symbols (U+1D504..U+1D537)
    'A'..='Z' => 0x1D4C3
    'a'..='z' => 0x1D4BD
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_bold_fraktur(c : Char) -> Char {
  let delta = match c {
    // Bold Fraktur symbols (U+1D56C..U+1D59F)
    'A'..='Z' => 0x1D52B
    'a'..='z' => 0x1D525
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_sans_serif(c : Char) -> Char {
  let delta = match c {
    // Sans-serif symbols (U+1D5A0..U+1D5D3)
    'A'..='Z' => 0x1D55F
    'a'..='z' => 0x1D559
    // Sans-serif digits (U+1D7E2..U+1D7EB)
    '0'..='9' => 0x1D7B2
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_sans_serif_bold(c : Char) -> Char {
  let delta = match c {
    // Sans-serif bold symbols (U+1D5D4..U+1D607)
    'A'..='Z' => 0x1D593
    'a'..='z' => 0x1D58D
    // Sans-serif bold Greek symbols (U+1D756..U+1D788)
    'Α'..='Ρ' => 0x1D3C5
    'ϴ' => 0x1D373
    'Σ'..='Ω' => 0x1D3C5
    '∇' => 0x1B568
    'α'..='ω' => 0x1D3BF
    // Additional sans-serif bold Greek symbols (U+1D789..U+1D78F)
    '∂' => 0x1B587
    'ϵ' => 0x1D395
    'ϑ' => 0x1D3BA
    'ϰ' => 0x1D39C
    'ϕ' => 0x1D3B8
    'ϱ' => 0x1D39D
    'ϖ' => 0x1D3B9
    // Sans-serif bold digits (U+1D7EC..U+1D7F5)
    '0'..='9' => 0x1D7BC
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_sans_serif_italic(c : Char) -> Char {
  let delta = match c {
    // Sans-serif italic symbols (U+1D608..U+1D63B)
    'A'..='Z' => 0x1D5C7
    'a'..='z' => 0x1D5C1
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_sans_serif_bold_italic(c : Char) -> Char {
  let delta = match c {
    // Sans-serif bold italic symbols (U+1D63C..U+1D66F)
    'A'..='Z' => 0x1D5FB
    'a'..='z' => 0x1D5F5
    // Sans-serif bold italic Greek symbols (U+1D790..U+1D7C2)
    'Α'..='Ρ' => 0x1D3FF
    'ϴ' => 0x1D3AD
    'Σ'..='Ω' => 0x1D3FF
    '∇' => 0x1B5A2
    'α'..='ω' => 0x1D3F9
    // Additional sans-serif bold italic Greek symbols (U+1D7C3..U+1D7C9)
    '∂' => 0x1B5C1
    'ϵ' => 0x1D3CF
    'ϑ' => 0x1D3F4
    'ϰ' => 0x1D3D6
    'ϕ' => 0x1D3F2
    'ϱ' => 0x1D3D7
    'ϖ' => 0x1D3F3
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_monospace(c : Char) -> Char {
  let delta = match c {
    // Monospace symbols (U+1D670..U+1D6A3)
    'A'..='Z' => 0x1D62F
    'a'..='z' => 0x1D629
    // Monospace digits (U+1D7F6..U+1D7FF)
    '0'..='9' => 0x1D7C6
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_isolated(c : Char) -> Char {
  let delta = match c {
    // Arabic Mathematical Alphabetic Symbols Block (U+1EE00..U+1EEFF)
    // Isolated symbols (U+1EE00..U+1EE1F)
    'ا'..='ب' => 0x1E7D9
    'ج' => 0x1E7D6
    'د' => 0x1E7D4
    'و' => 0x1E7BD
    'ز' => 0x1E7D4
    'ح' => 0x1E7DA
    'ط' => 0x1E7D1
    'ي' => 0x1E7BF
    'ك'..='ن' => 0x1E7C7
    'س' => 0x1E7DB
    'ع' => 0x1E7D6
    'ف' => 0x1E7CF
    'ص' => 0x1E7DC
    'ق' => 0x1E7D0
    'ر' => 0x1E7E2
    'ش' => 0x1E7E0
    'ت'..='ث' => 0x1E7EB
    'خ' => 0x1E7E9
    'ذ' => 0x1E7E8
    'ض' => 0x1E7E3
    'ظ' => 0x1E7E2
    'غ' => 0x1E7E1
    'ٮ' => 0x1E7AE
    'ں' => 0x1E763
    'ڡ' => 0x1E77D
    'ٯ' => 0x1E7B0
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_initial(c : Char) -> Char {
  let delta = match c {
    // Initial symbols (U+1EE21..U+1EE3B)
    'ب' => 0x1E7F9
    'ج' => 0x1E7F6
    'ه' => 0x1E7DD
    'ح' => 0x1E7FA
    'ي' => 0x1E7DF
    'ك'..='ن' => 0x1E7E7
    'س' => 0x1E7FB
    'ع' => 0x1E7F6
    'ف' => 0x1E7EF
    'ص' => 0x1E7FC
    'ق' => 0x1E7F0
    'ش' => 0x1E800
    'ت'..='ث' => 0x1E80B
    'خ' => 0x1E809
    'ض' => 0x1E803
    'غ' => 0x1E801
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_tailed(c : Char) -> Char {
  let delta = match c {
    // Tailed symbols (U+1EE42..U+1EE5F)
    'ج' => 0x1E816
    'ح' => 0x1E81A
    'ي' => 0x1E7FF
    'ل' => 0x1E807
    'ن' => 0x1E807
    'س' => 0x1E81B
    'ع' => 0x1E816
    'ص' => 0x1E81C
    'ق' => 0x1E810
    'ش' => 0x1E820
    'خ' => 0x1E829
    'ض' => 0x1E823
    'غ' => 0x1E821
    'ں' => 0x1E7A3
    'ٯ' => 0x1E7F0
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_stretched(c : Char) -> Char {
  let delta = match c {
    // Stretched symbols (U+1EE61..U+1EE7E)
    'ب' => 0x1E839
    'ج' => 0x1E836
    'ه' => 0x1E81D
    'ح' => 0x1E83A
    'ط' => 0x1E831
    'ي' => 0x1E81F
    'ك' => 0x1E827
    'م'..='ن' => 0x1E827
    'س' => 0x1E83B
    'ع' => 0x1E836
    'ف' => 0x1E82F
    'ص' => 0x1E83C
    'ق' => 0x1E830
    'ش' => 0x1E840
    'ت'..='ث' => 0x1E84B
    'خ' => 0x1E849
    'ض' => 0x1E843
    'ظ' => 0x1E842
    'غ' => 0x1E841
    'ٮ' => 0x1E80E
    'ڡ' => 0x1E7DD
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_looped(c : Char) -> Char {
  let delta = match c {
    // Looped symbols (U+1EE80..U+1EE9B)
    'ا'..='ب' => 0x1E859
    'ج' => 0x1E856
    'د' => 0x1E854
    // Upstream uses the exclusive range `'ه'..'و'`.
    'ه' => 0x1E83D
    'ز' => 0x1E854
    'ح' => 0x1E85A
    'ط' => 0x1E851
    'ي' => 0x1E83F
    'ل'..='ن' => 0x1E847
    'س' => 0x1E85B
    'ع' => 0x1E856
    'ف' => 0x1E84F
    'ص' => 0x1E85C
    'ق' => 0x1E850
    'ر' => 0x1E862
    'ش' => 0x1E860
    'ت'..='ث' => 0x1E86B
    'خ' => 0x1E869
    'ذ' => 0x1E868
    'ض' => 0x1E863
    'ظ' => 0x1E862
    'غ' => 0x1E861
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_double_struck(c : Char) -> Char {
  let delta = match c {
    // Letterlike symbols (U+2100..U+2134)
    'C' => 0x20BF
    'H' => 0x20C5
    'N' => 0x20C7
    'P'..='Q' => 0x20C9
    'R' => 0x20CB
    'Z' => 0x20CA
    // Additional letterlike symbols (U+2139..U+213F)
    'π' => 0x1D7C
    'γ' => 0x1D8A
    'Γ' => 0x1DAB
    'Π' => 0x1D9F
    // Double-struck large operator (U+2140)
    '∑' => return '⅀' // delta is negative
    // Double-struck symbols (U+1D538..U+1D56B)
    'A'..='Z' => 0x1D4F7
    'a'..='z' => 0x1D4F1
    // Double-struck digits (U+1D7D8..U+1D7E1)
    '0'..='9' => 0x1D7A8
    // Arabic Mathematical Alphabetic Symbols Block (U+1EE00..U+1EEFF)
    // Double-struck symbols (U+1EEA1..U+1EEBB)
    'ب' => 0x1E879
    'ج' => 0x1E876
    'د' => 0x1E874
    'و' => 0x1E85D
    'ز' => 0x1E874
    'ح' => 0x1E87A
    'ط' => 0x1E871
    'ي' => 0x1E85F
    'ل'..='ن' => 0x1E867
    'س' => 0x1E87B
    'ع' => 0x1E876
    'ف' => 0x1E86F
    'ص' => 0x1E87C
    'ق' => 0x1E870
    'ر' => 0x1E882
    'ش' => 0x1E880
    'ت'..='ث' => 0x1E88B
    'خ' => 0x1E889
    'ذ' => 0x1E888
    'ض' => 0x1E883
    'ظ' => 0x1E882
    'غ' => 0x1E881
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_double_struck_italic(c : Char) -> Char {
  let delta = match c {
    // Double-struck italic math symbols (U+2145..U+2149)
    'D' => 0x2101
    'd'..='e' => 0x20E2
    'i'..='j' => 0x20DF
    _ => return c
  }
  styling_apply_delta(c, delta)
}

///|
fn styling_to_hebrew(c : Char) -> Char {
  let delta = match c {
    // Hebrew letterlike math symbols (U+2135..U+2138)
    'א'..='ד' => 0x1B65
    _ => return c
  }
  styling_apply_delta(c, delta)
}
