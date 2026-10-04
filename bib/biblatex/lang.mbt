// Port of `biblatex/src/types/lang.rs`.

///|
/// The languages supported by biblatex
pub(all) enum Language {
  Basque
  Bulgarian
  Catalan
  Croatian
  Czech
  Danish
  Dutch
  EnglishUS
  EnglishUK
  EnglishCA
  EnglishAUS
  EnglishNZ
  Estonian
  Finnish
  French
  German
  GermanAT
  GermanCH
  GermanNew
  GermanATNew
  GermanCHNew
  Greek
  Hungarian
  Icelandic
  Italian
  Latvian
  Lithuanian
  Marathi
  NorwegianBokmal
  NorwegainNynorsk
  Polish
  PortugueseBR
  Portuguese
  Romanian
  Russian
  SerbianLatin
  SerbianCyrillic
  Slovak
  Slovene
  Spanish
  Swedish
  Turkish
  Ukrainian
} derive(Eq, Debug)

///|
/// `(variant, display name, serializations)`.
let languages : ReadOnlyArray[(Language, String, ReadOnlyArray[String])] = [
  (Basque, "Basque", ["basque"]),
  (Bulgarian, "Bulgarian", ["bulgarian"]),
  (Catalan, "Catalan", ["catalan"]),
  (Croatian, "Croatian", ["croatian"]),
  (Czech, "Czech", ["czech"]),
  (Danish, "Danish", ["danish"]),
  (Dutch, "Dutch", ["dutch"]),
  (EnglishUS, "American English", ["american", "USenglish", "english"]),
  (EnglishUK, "British English", ["british", "UKenglish"]),
  (EnglishCA, "Canadian English", ["canadian"]),
  (EnglishAUS, "Australian English", ["australian"]),
  (EnglishNZ, "New Zealand English", ["newzealand"]),
  (Estonian, "Estonian", ["estonian"]),
  (Finnish, "Finnish", ["finnish"]),
  (French, "French", ["french"]),
  (German, "German", ["german"]),
  (GermanAT, "Austrian", ["austrian"]),
  (GermanCH, "Swiss German", ["swissgerman"]),
  (GermanNew, "New German", ["ngerman"]),
  (GermanATNew, "New Austrian", ["naustrian"]),
  (GermanCHNew, "New Swiss German", ["nswissgerman"]),
  (Greek, "Greek", ["greek"]),
  (Hungarian, "Hungarian", ["magyar", "hungarian"]),
  (Icelandic, "Icelandic", ["icelandic"]),
  (Italian, "Italian", ["italian"]),
  (Latvian, "Latvian", ["latvian"]),
  (Lithuanian, "Lithuanian", ["lithuanian"]),
  (Marathi, "Marathi", ["marathi"]),
  (NorwegianBokmal, "Norwegian (Bokmål)", ["norsk"]),
  (NorwegainNynorsk, "Norwegian (Nynorsk)", ["nynorsk"]),
  (Polish, "Polish", ["polish"]),
  (PortugueseBR, "Brazilian Portuguese", ["brazil"]),
  (Portuguese, "Portuguese", ["portuguese", "portuges"]),
  (Romanian, "Romanian", ["romanian"]),
  (Russian, "Russian", ["russian"]),
  (SerbianLatin, "Serbian (Latin)", ["serbian"]),
  (SerbianCyrillic, "Serbian (Cyrillic)", ["serbianc"]),
  (Slovak, "Slovak", ["slovak"]),
  (Slovene, "Slovene", ["slovene", "slovenian"]),
  (Spanish, "Spanish", ["spanish"]),
  (Swedish, "Swedish", ["swedish"]),
  (Turkish, "Turkish", ["turkish"]),
  (Ukrainian, "Ukrainian", ["ukrainian"]),
]

///|
pub impl Show for Language with fn output(self, logger) {
  for l in languages[:] {
    if l.0 == self {
      logger.write_string(l.1)
      return
    }
  }
}

///|
/// Strum's `FromStr` (the display name and all serializations).
pub fn Language::from_str(s : String) -> Language? {
  for l in languages[:] {
    if l.1 == s || l.2.contains(s) {
      return Some(l.0)
    }
  }
  None
}

///|
/// `impl Type for Language`.
pub fn parse_language(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Language, TypeError] {
  let span = chunks_span(chunks)
  match Language::from_str(format_verbatim(chunks)) {
    Some(l) => Ok(l)
    None => Err({ span, kind: UnknownLangId, })
  }
}

///|
/// `impl From<Language> for LanguageIdentifier`, as the identifier string.
pub fn Language::to_langid(self : Language) -> String {
  match self {
    Basque => "eu"
    Bulgarian => "bg"
    Catalan => "ca"
    Croatian => "hr"
    Czech => "cs"
    Danish => "da"
    Dutch => "nl"
    EnglishUS => "en-US"
    EnglishUK => "en-UK"
    EnglishCA => "en-CA"
    EnglishAUS => "en-AU"
    EnglishNZ => "en-NZ"
    Estonian => "et"
    Finnish => "fi"
    French => "fr"
    German | GermanNew => "de"
    GermanAT | GermanATNew => "de-AT"
    GermanCH | GermanCHNew => "de-CH"
    Greek => "el"
    Hungarian => "hu"
    Icelandic => "is"
    Italian => "it"
    Latvian => "lv"
    Lithuanian => "lt"
    Marathi => "mr"
    NorwegianBokmal => "nb"
    NorwegainNynorsk => "nn"
    Polish => "pl"
    PortugueseBR => "pt-BR"
    Portuguese => "pt-PT"
    Romanian => "ro"
    Russian => "ru"
    SerbianLatin => "sr-Latn"
    SerbianCyrillic => "sr-Cyrl"
    Slovak => "sk"
    Slovene => "sl"
    Spanish => "es"
    Swedish => "sv"
    Turkish => "tr"
    Ukrainian => "uk"
  }
}
