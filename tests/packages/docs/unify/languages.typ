// unify 0.8.1: language-dependent unit tables: Russian (`set text(lang: "ru")`), English
// inside a Russian document, fallback to English for a language without tables, decimal
// commas, `add-unit` registered per language.
// Engine: `text.lang` read in context, state keyed by language, Cyrillic text in math
// (font fallback for upright letters), `eval` of generated math.
#import "@preview/unify:0.8.1": num, unit, qty, numrange, qtyrange, add-unit

#set page(width: 140mm, height: 150mm, margin: (x: 12mm, y: 13mm))
#set text(size: 10pt)
#show table.cell.where(y: 0): strong

#let samples = (
  ("1,5", "kilo meter"),
  ("72", "km/h"),
  ("9,81", "meter per second squared"),
  ("220+-10", "V"),
  ("3,6e6", "J"),
  ("0,75", "kW"),
  ("25", "micro second"),
  ("101325", "Pa"),
  ("2,5", "l/min"),
  ("18", "year"),
)

#let column(lang) = samples.map(((value, name)) => text(lang: lang, qty(value, name)))

= One table, three languages

The same calls are evaluated under different text languages. German has
no tables in the package and falls back to the English ones.

#table(
  columns: (auto, auto, 1fr, 1fr, 1fr),
  align: (right, left, left, left, left),
  table.header[Value][Unit][`en`][`ru`][`de` (fallback)],
  ..range(samples.len())
    .map(i => (
      raw(samples.at(i).at(0)),
      raw(samples.at(i).at(1)),
      column("en").at(i),
      column("ru").at(i),
      column("de").at(i),
    ))
    .flatten(),
)

#set text(lang: "ru")

= Русский раздел

Насос подаёт #qty("12,5", "m^3/h") при напоре #qty("6,2", "m") и потребляет
#qty("370", "W") от сети #qty("230", "V"), #qty("50", "Hz"). Сопротивление обмотки
равно #qty("38,4+-0,5", "ohm"), ёмкость конденсатора --- #qty("8", "uF"). Диапазон
температур: #qtyrange("-10", "110", "dC"); давление до #qty("1,0e6", "Pa").
Единицы отдельно: #unit("kg m/s^2"), #unit("joule per mole per kelvin", per: "fraction-short"),
#unit("kilo watt hour"), #unit("giga byte").

$ P = rho g Q H = qty("998", "kg/m^3") dot qty("9,81", "m/s^2") dot qty("3,47e-3", "m^3/s") dot qty("6,2", "m")
  approx qty("211", "W") $

#add-unit("oborot", "ob", "upright(\"об\")")
После регистрации новой единицы: #qty("2850", "ob/min"), #qty("47,5", "oborot per second").
In an English phrase inside this section the tables switch back:
#text(lang: "en")[#qty("2850", "1/min", rawunit: true), #qty("0.37", "kW"), #qty("5.8", "kg")], и снова
по-русски: #qty("5,8", "kg"), #numrange("1,5e3", "2,5e3"), #num("1234567,891").
