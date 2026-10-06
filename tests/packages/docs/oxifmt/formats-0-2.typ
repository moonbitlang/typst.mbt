// oxifmt 0.2.1: the older strfmt (positional/named arguments, repr mode,
// fill/alignment/width, sign, zero padding, radix, precision, scientific
// notation, decimal separator), used to build a fixed-width report.
// Stresses its string code under the current compiler (type checks on
// values, regex, UTF-8 aware padding), raw blocks built from formatted
// lines, results in a table.
#import "@preview/oxifmt:0.2.1": strfmt

#set page(width: 15cm, height: 20cm, margin: 1.3cm, numbering: "1")
#set text(size: 9pt)
#show raw: set text(size: 8pt)

= Weather station log

#let readings = (
  (station: "Skagen", t: 4.25, p: 1013.2, wind: 17, dir: "NW", gust: 31.5),
  (station: "Tórshavn", t: -1.5, p: 987.65, wind: 42, dir: "SSW", gust: 68.0),
  (station: "Ærø", t: 11.0, p: 1021.0, wind: 3, dir: "E", gust: 5.25),
  (station: "Þingvellir", t: -12.75, p: 1002.4, wind: 0, dir: "-", gust: 0.0),
)

== A fixed-width report

#raw(
  block: true,
  (
    strfmt("{:<12}{:>8}{:>10}{:>6}{:^7}{:>8}", "station", "temp", "pressure", "wind", "dir", "gust"),
    strfmt("{:=<51}", ""),
    ..readings.map(r => strfmt(
      "{station:.<12}{t:>+8.1}{p:>10.2}{wind:>6}{dir:^7}{gust:>8.1}",
      ..r,
    )),
    strfmt("{:=<51}", ""),
    strfmt(
      "{:<12}{:>+8.2}{:>10.2}{:>6}",
      "mean",
      readings.map(r => r.t).sum() / readings.len(),
      readings.map(r => r.p).sum() / readings.len(),
      calc.round(readings.map(r => r.wind).sum() / readings.len()),
    ),
  ).join("\n"),
)

== Format by format

#let show-case(fmt, ..args) = (
  raw(fmt),
  raw((args.pos().map(repr) + args.named().pairs().map(((k, v)) => k + ": " + repr(v))).join(", "), lang: "typc"),
  raw("|" + strfmt(fmt, ..args) + "|"),
)

#table(
  columns: (auto, auto, auto),
  stroke: 0.4pt + gray,
  inset: 4pt,
  table.header[*Format*][*Arguments*][*Result*],
  ..show-case("{} hPa at {}", 1013.2, "Skagen"),
  ..show-case("{1}, {0}, {1}", "low", "high"),
  ..show-case("{a}-{b}-{a}", a: "x", b: 2),
  ..show-case("{{}} {} {{ {} }}", 1, 2),
  ..show-case("{:?} {:?} {}", "gale", <warn>, <warn>),
  ..show-case("{} {} {}", true, none, (1, 2)),
  ..show-case("{:_<9}|{:_>9}|{:_^9}", "ab", "cd", "ef"),
  ..show-case("{:ø^9}", "Ærø"),
  ..show-case("{:+} {:+} {:+.1}", 3, -3, 0.25),
  ..show-case("{:06} {:06} {:06.1}", 17, -17, 2.5),
  ..show-case("{0:b} {0:o} {0:x} {0:X}", 987),
  ..show-case("{0:#b} {0:#o} {0:#x}", 31),
  ..show-case("{:#010x} {:+#b}", 1013, 5),
  ..show-case("{:.0} {:.2} {:.4}", 0.5, 2.345, 1),
  ..show-case("{:e} {:E} {:.2e}", 101320.0, 0.0042, 68),
  ..show-case("{:10.2e}|{:<10.1e}|", 987.65, 987.65),
  ..show-case("{} {:.3} {:e}", 4.25, 4.25, 4.25, fmt-decimal-separator: ","),
  ..show-case("{} {}", 1e15, 0.1 + 0.7),
)

== In running text

#for r in readings [
  - #strfmt("At {station} it is {t:+.1} °C with {wind:02} kn from {dir:?}; gusts {gust:.0}.", ..r)
]

The lowest pressure, in other bases:
#{
  let low = calc.min(..readings.map(r => int(calc.round(r.p))))
  strfmt("{0} = {0:#x} = {0:#o} = {0:#b}", low)
}
