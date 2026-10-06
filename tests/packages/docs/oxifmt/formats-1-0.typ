// oxifmt 1.0.0: strfmt with positional, indexed and named arguments, escaped
// braces, repr mode, fill/alignment/width (also from arguments), sign, zero
// padding, radix with prefixes, precision, scientific notation, decimals,
// inf/NaN, decimal and thousands separators (fixed and variable groups).
// Stresses string code: regex matching, codepoint slicing, float and decimal
// to string conversion, repr of many value types; results shown in tables.
#import "@preview/oxifmt:1.0.0": strfmt

#set page(width: 18cm, height: 22cm, margin: 1.2cm, numbering: "1")
#set text(size: 9pt)
#show raw: set text(size: 7.5pt)
#set heading(numbering: "1.")

// Each case is (format, positional arguments, named arguments). The result
// is shown between bars so that padding is visible.
#let cases(..list) = table(
  columns: (auto, auto, auto),
  stroke: 0.4pt + gray,
  inset: 4pt,
  table.header[*Format*][*Arguments*][*Result*],
  ..list
    .pos()
    .map(c => {
      let (fmt, pos, ..) = c
      let named = c.at(2, default: (:))
      let shown = (pos.map(repr) + named.pairs().map(((k, v)) => k + ": " + repr(v))).join(", ")
      (raw(fmt), raw(shown, lang: "typc"), raw("|" + strfmt(fmt, ..pos, ..named) + "|"))
    })
    .flatten(),
)

= The harbour office prints its ledgers

== Plain replacement

#cases(
  ("{} tons of {} for {}", (14, "coal", "the Marta")),
  ("{1} before {0}, then {1} again", ("ebb", "flood")),
  ("{ship} berths at {quay}", (), (ship: "Marta", quay: 4)),
  ("{} and {name} and {}", ("a", "b"), (name: "n")),
  ("{{literal}} braces, {} value", (3.5,)),
  ("{} {} {} {}", (true, none, auto, <berth>)),
  ("{:?} {:?} {:?}", ("quoted", <label>, 2.0)),
  ("{} | {:?}", ((1, "two", 3.0), (tide: "high", m: 4.2))),
  ("{:?}", ([*bold* content],)),
  ("Größe: {}, λιμάνι: {}, порт: {}", ("über", "Πειραιάς", "Одеса")),
)

== Fill, alignment and width

#cases(
  ("{:8}", ("left",)),
  ("{:>8}", ("right",)),
  ("{:^8}", ("mid",)),
  ("{:^9}", ("odd",)),
  ("{:*<10}", ("stars",)),
  ("{:->10}", (42,)),
  ("{:~^11}", ("wave",)),
  ("{:{<6}{:}>6}", ("a", "b")),
  ("{:é^7}", ("ü",)),
  ("{:_^3$}", (88, 0, 0, 6)),
  ("{:>w$}|{:<w$}", ("ab", "cd"), (w: 5)),
  ("{:#>8?}", ("q",)),
  ("{:2}", ("longer than the width",)),
)

== Signs and zero padding

#cases(
  ("{:+} {:+} {:+}", (7, -7, 0)),
  ("{:+} {:+}", (2.5, -2.5)),
  ("{:05} {:05} {:05}", (42, -42, 123456)),
  ("{:+06}", (42,)),
  ("{:08.3}", (3.14159,)),
  ("{:+09.2}", (-3.14159,)),
  ("{:_>+8}", (512,)),
  ("{:0w$}", (9,), (w: 4)),
)

== Radix

#cases(
  ("{0} {0:b} {0:o} {0:x} {0:X}", (2024,)),
  ("{0:#b} {0:#o} {0:#x} {0:#X}", (255,)),
  ("{:#010b}", (37,)),
  ("{:#06x} {:06X}", (48879, 48879)),
  ("{:+#x} {:x}", (255, -255)),
  ("{:>12b}|{:<12o}|", (1000, 1000)),
  ("{:x}", (9223372036854775807,)),
)

#pagebreak()

== Precision and scientific notation

#cases(
  ("{:.0} {:.1} {:.3}", (2.5, 2.25, 1.0)),
  ("{:.2} {:.2}", (0.005, 1.995)),
  ("{:.3}", (12,)),
  ("{0:.p$} {0:.1$}", (2.718281828, 4), (p: 2)),
  ("{:10.3}|{:<10.3}|{:^10.3}|", (1.5, 1.5, 1.5)),
  ("{:e} {:E}", (1234.5, 0.00012)),
  ("{:.2e} {:.4E}", (299792458, 6.62607015e-34)),
  ("{:e} {:e}", (0, 1)),
  ("{:+.1e}", (-98765.4321,)),
  ("{:12.3e}|", (0.000123456,)),
  ("{} {} {}", (float.inf, -float.inf, float.nan)),
  ("{:8} {:+} {:.2}", (float.inf, float.inf, float.nan)),
  ("{} {}", (1e21, 1e-7)),
  ("{} {}", (0.1 + 0.2, 1 / 3)),
)

== Decimals

#cases(
  ("{} {}", (decimal("12.50"), decimal("-0.001"))),
  ("{:.1} {:.4}", (decimal("2.25"), decimal("2.25"))),
  ("{:e} {:.2e}", (decimal("1234.5678"), decimal("0.00042"))),
  ("{:+010.3}", (decimal("3.14159"),)),
  ("{}", (decimal("123456789012345678.123456789"),)),
)

== Separators

#let sep-cases(..list) = table(
  columns: (auto, auto, auto, auto),
  stroke: 0.4pt + gray,
  inset: 4pt,
  table.header[*Format*][*Value*][*Options*][*Result*],
  ..list
    .pos()
    .map(((fmt, value, opts)) => (
      raw(fmt),
      raw(repr(value)),
      raw(opts.pairs().map(((k, v)) => k.replace("fmt-", "") + ": " + repr(v)).join(", ")),
      raw("|" + strfmt(fmt, value, ..opts) + "|"),
    ))
    .flatten(),
)

#sep-cases(
  ("{}", 3.75, (fmt-decimal-separator: ",")),
  ("{:.3}", 1234.5, (fmt-decimal-separator: ",")),
  ("{:.2e}", 1234.5, (fmt-decimal-separator: "·")),
  ("{}", 1234567, (fmt-thousands-separator: ",")),
  ("{}", -1234567, (fmt-thousands-separator: " ")),
  ("{}", 999, (fmt-thousands-separator: ",")),
  ("{:.2}", 9876543.21, (fmt-thousands-separator: ".", fmt-decimal-separator: ",")),
  ("{}", 12345678, (fmt-thousands-separator: "_", fmt-thousands-count: 2)),
  ("{}", 12345678, (fmt-thousands-separator: ",", fmt-thousands-count: (3, 2))),
  ("{}", 123456789, (fmt-thousands-separator: "'", fmt-thousands-count: (4, 3, 1))),
  ("{:x}", 3735928559, (fmt-thousands-separator: "_", fmt-thousands-count: 4)),
  ("{:#b}", 2024, (fmt-thousands-separator: "_", fmt-thousands-count: 4)),
  ("{:012}", 1234567, (fmt-thousands-separator: ",")),
  ("{:>14}", 1234567, (fmt-thousands-separator: ",")),
  ("{}", decimal("1234567.891"), (fmt-thousands-separator: " ", fmt-decimal-separator: ",")),
)

== A ledger page

#let de = strfmt.with(fmt-decimal-separator: ",", fmt-thousands-separator: ".")
#let ledger = (
  ("Marta", "coal", 1420.5, 38.2),
  ("Sæl", "salt fish", 86.25, 912.0),
  ("Kittiwake", "timber", 12750, 4.75),
  ("Øresund", "grain", 230.125, 61.4),
)

#table(
  columns: (auto, auto, auto, auto, auto),
  align: (left, left, right, right, right),
  table.header[Ship][Cargo][Tons][Rate][Due],
  ..ledger
    .map(((ship, cargo, tons, rate)) => (
      strfmt("{:.<12}", ship),
      upper(strfmt("{:^11}", cargo)),
      de("{:.3}", tons),
      de("{:>8.2}", rate),
      de("{:+.2}", tons * rate),
    ))
    .flatten()
    .map(raw),
  table.cell(colspan: 4, align: right)[Total],
  raw(de("{:.2}", ledger.map(r => r.at(2) * r.at(3)).sum())),
)

#for (i, row) in ledger.enumerate() [
  #strfmt("Entry {:03}: {ship:?} carried {cargo} ({tons:e} t).", i + 1, ship: row.at(0), cargo: row.at(1), tons: row.at(2)) \
]
