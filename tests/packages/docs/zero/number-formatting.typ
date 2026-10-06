// zero 0.7.1: `num` (input forms, exponent modes sci/eng/fixed, digits, signs, base, product,
// tight, `math: false`), uncertainties in three modes and asymmetric, rounding (places,
// figures, pad, direction, ties, following the uncertainty), digit grouping, global options
// through `set-num`/`set-round`/`set-group`/`set-unit`, units and quantities (`zi`,
// `zi.declare`, `quan`, fractions, engineering prefixes).
// Engine: state-driven formatting in context, math attachments and spacing built from code,
// decimal string arithmetic, queryable metadata next to every number.
#import "@preview/zero:0.7.1": num, set-num, set-round, set-group, set-unit, quan, zi

#set page(width: 150mm, height: 190mm, margin: (x: 12mm, y: 13mm), numbering: "1")
#set text(size: 9.5pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show table.cell.where(y: 0): strong
#set table(inset: 4pt, stroke: 0.4pt)

#let demo(..rows) = table(
  columns: (1fr, 1fr),
  table.header[Call][Result],
  ..rows.pos().map(((src, res)) => (raw(src, lang: "typc"), res)).flatten(),
)

#align(center, text(14pt, weight: "bold")[Calibration Log of the Mass Comparator])

= Readings

The reference weight has a conventional mass of #zi.gram[1000.00042+-0.00015], the
room was at #zi.degreeCelsius[20.3] and #zi.Pa[101325], and the air density came
out as #zi.kg-m3[1.1987(12)]. Over the night the comparator drifted by
#quan[-3.2e-6 g/h]; the largest single step was #num[0.000012], the count of
readings #num[86400], and the buoyancy correction factor #num("1.000150(3)").

#demo(
  (`num[299792458]`.text, num[299792458]),
  (`num("6.62607015e-34")`.text, num("6.62607015e-34")),
  (`num(0.000125)`.text, num(0.000125)),
  (`num(-17)`.text, num(-17)),
  (`num[.5]`.text, num[.5]),
  (`num[1,25E4]`.text, num[1,25E4]),
  (`num[1e80]`.text, num[1e80]),
  (`num("1e80", omit-unity-mantissa: true)`.text, num("1e80", omit-unity-mantissa: true)),
  (`num("12.50", positive-sign: true)`.text, num("12.50", positive-sign: true)),
  (`num("3e4", positive-sign-exponent: true)`.text, num("3e4", positive-sign-exponent: true)),
  (`num("2.5e0", omit-zero-exponent: true)`.text, num("2.5e0", omit-zero-exponent: true)),
  (`num("7.2500", trim-zeros: true)`.text, num("7.2500", trim-zeros: true)),
  (`num("3.14159", digits: 2)`.text, num("3.14159", digits: 2)),
  (`num("3.1", digits: 4)`.text, num("3.1", digits: 4)),
  (`num("1.5e10", base: 2)`.text, num("1.5e10", base: 2)),
  (`num("4.8e5", product: sym.dot)`.text, num("4.8e5", product: sym.dot)),
  (`num("4.8+-0.2e5", tight: true)`.text, num("4.8+-0.2e5", tight: true)),
  (`num("1234.5", decimal-separator: ",")`.text, num("1234.5", decimal-separator: ",")),
  (`num("1234.5e3", math: false)`.text, num("1234.5e3", math: false)),
)

= Exponents

#demo(
  (`num("123456", exponent: "sci")`.text, num("123456", exponent: "sci")),
  (`num("0.00042", exponent: "sci")`.text, num("0.00042", exponent: "sci")),
  (`num("123456", exponent: "eng")`.text, num("123456", exponent: "eng")),
  (`num("0.00042", exponent: "eng")`.text, num("0.00042", exponent: "eng")),
  (`num("4.2e7", exponent: (fixed: 6))`.text, num("4.2e7", exponent: (fixed: 6))),
  (`num("4.2e7", exponent: (fixed: 0))`.text, num("4.2e7", exponent: (fixed: 0))),
  (`num("950", exponent: (sci: 3))`.text, num("950", exponent: (sci: 3))),
  (`num("9500", exponent: (sci: 3))`.text, num("9500", exponent: (sci: 3))),
  (`num("0.02", exponent: (sci: (-3, 4)))`.text, num("0.02", exponent: (sci: (-3, 4)))),
  (`num("20000", exponent: (sci: (-3, 4)))`.text, num("20000", exponent: (sci: (-3, 4)))),
  (`num("0", exponent: "sci")`.text, num("0", exponent: "sci")),
)

= Uncertainties

#demo(
  (`num[2.3(4)]`.text, num[2.3(4)]),
  (`num[2.3+-0.4]`.text, num[2.3+-0.4]),
  (`num("1.23+-.04e2")`.text, num("1.23+-.04e2")),
  (`num("1.23+0.02-0.01")`.text, num("1.23+0.02-0.01")),
  (`num("1.23+0.02-0.01e-5")`.text, num("1.23+0.02-0.01e-5")),
  (`num("9.80665(12)", uncertainty-mode: "compact")`.text, num("9.80665(12)", uncertainty-mode: "compact")),
  (`num("12.3+-1.5", uncertainty-mode: "compact")`.text, num("12.3+-1.5", uncertainty-mode: "compact")),
  (
    `num("12.3+-1.5", uncertainty-mode: "compact-separator")`.text,
    num("12.3+-1.5", uncertainty-mode: "compact-separator"),
  ),
  (`num("1000.00042(15)", uncertainty-mode: "separate")`.text, num("1000.00042(15)", uncertainty-mode: "separate")),
)

= Rounding

#demo(
  (`num("2.71828", round: (precision: 2))`.text, num("2.71828", round: (precision: 2))),
  (`num("2.71828", round: (mode: "figures", precision: 2))`.text, num("2.71828", round: (mode: "figures", precision: 2))),
  (`num("1234.5", round: (precision: -2))`.text, num("1234.5", round: (precision: -2))),
  (`num("0.5", round: (precision: 3))`.text, num("0.5", round: (precision: 3))),
  (`num("0.5", round: (precision: 3, pad: false))`.text, num("0.5", round: (precision: 3, pad: false))),
  (`num("2.5", round: (precision: 0))`.text, num("2.5", round: (precision: 0))),
  (`num("2.5", round: (precision: 0, ties: "to-even"))`.text, num("2.5", round: (precision: 0, ties: "to-even"))),
  (`num("3.5", round: (precision: 0, ties: "to-odd"))`.text, num("3.5", round: (precision: 0, ties: "to-odd"))),
  (`num("-2.5", round: (precision: 0, ties: "towards-infinity"))`.text, num("-2.5", round: (precision: 0, ties: "towards-infinity"))),
  (`num("2.31", round: (precision: 1, direction: "towards-infinity"))`.text, num("2.31", round: (precision: 1, direction: "towards-infinity"))),
  (`num("-2.39", round: (precision: 1, direction: "towards-zero"))`.text, num("-2.39", round: (precision: 1, direction: "towards-zero"))),
  (`num("2.31", round: (precision: 1, direction: "away-from-zero"))`.text, num("2.31", round: (precision: 1, direction: "away-from-zero"))),
  (`num("9.99951", round: (precision: 3))`.text, num("9.99951", round: (precision: 3))),
  (`num("1.23456+-0.0234", round: (uncertainty-precision: 1))`.text, num("1.23456+-0.0234", round: (uncertainty-precision: 1))),
  (`num("1.23456+-0.0234", round: (uncertainty-precision: 2))`.text, num("1.23456+-0.0234", round: (uncertainty-precision: 2))),
  (
    `num("1.23456+-0.0234", round: (follow-uncertainty: false, precision: 1))`.text,
    num("1.23456+-0.0234", round: (follow-uncertainty: false, precision: 1)),
  ),
)

= Grouping

#demo(
  (`num[1234]`.text, num[1234]),
  (`num[12345.678901]`.text, num[12345.678901]),
  (`num("1234", group: (threshold: 4))`.text, num("1234", group: (threshold: 4))),
  (`num("1234567.1234567", group: (separator: "'"))`.text, num("1234567.1234567", group: (separator: "'"))),
  (`num("1234567.1234567", group: (size: 2))`.text, num("1234567.1234567", group: (size: 2))),
  (
    `num("1234567.1234567", group: (threshold: (integer: 5, fractional: calc.inf)))`.text,
    num("1234567.1234567", group: (threshold: (integer: 5, fractional: calc.inf))),
  ),
  (`num("1234567", group: (threshold: calc.inf))`.text, num("1234567", group: (threshold: calc.inf))),
)

= Document-wide options

Up to here the defaults were in force. From now on the product is a dot, spacing
is tight, uncertainties are compact, groups are separated by an apostrophe from
four digits on, and everything is rounded to three significant figures.

#set-num(product: math.dot, tight: true, uncertainty-mode: "compact")
#set-group(separator: "'", threshold: 4)
#set-round(mode: "figures", precision: 3)

The same readings again: #num[299792458], #num("6.62607015e-34"), #num[1234],
#num[86400], #num[0.000012345], #num("1.000150(3)"), #num("4.8+-0.2e5"), and in a
formula
$ m_"air" = rho V = num("1.1987") dot num("124.31e-6") = num("1.49010e-4"). $

#set-num(product: sym.times, tight: false, uncertainty-mode: "separate", exponent: "eng")
#set-group(separator: sym.space.nobreak.narrow, threshold: 5)
#set-round(mode: "places", precision: auto)

With engineering exponents as the default, quantities pick a metric prefix:
#zi.m[2e4], #zi.gram[0.00042], #zi.Hz[2.45e9], #zi.W[1.2e-5], #zi.m(prefix: none)[2e4].

#set-num(exponent: auto)

= Units

#let N-mm2 = zi.declare("N/mm^2")
#let ppm = zi.declare("ppm", alt: "parts per million")
#let sun = zi.declare($M_dot.o$, ("yr", -1), alt: "solar masses per year")

#demo(
  (`zi.m-s[299792458]`.text, zi.m-s[299792458]),
  (`zi.kg-m3[7.85e3]`.text, zi.kg-m3[7.85e3]),
  (`zi.Hz()`.text, zi.Hz()),
  (`zi.ohm[47+-2]`.text, zi.ohm[47+-2]),
  (`zi.degree[12.5]`.text, zi.degree[12.5]),
  (`zi.percent[99.7]`.text, zi.percent[99.7]),
  (`zi.liter[0.75]`.text, zi.liter[0.75]),
  (`zi.declare("N/mm^2")[210e3]`.text, N-mm2[210e3]),
  (`zi.declare("ppm", alt: ..)[1.5(2)]`.text, ppm[1.5(2)]),
  (`zi.declare($M_dot.o$, ("yr", -1), alt: ..)[3e-6]`.text, sun[3e-6]),
  (`zi.m-s2(fraction: "fraction")[9.81]`.text, zi.m-s2(fraction: "fraction")[9.81]),
  (`zi.m-s2(fraction: "inline")[9.81]`.text, zi.m-s2(fraction: "inline")[9.81]),
  (`zi.kWh(unit-separator: sym.dot)[3.6]`.text, zi.kWh(unit-separator: sym.dot)[3.6]),
  (`quan[1.2 m/s]`.text, quan[1.2 m/s]),
  (`quan[-2.0+-.4e3 m/s]`.text, quan[-2.0+-.4e3 m/s]),
  (`quan[GHz]`.text, quan[GHz]),
  (`quan[600us]`.text, quan[600us]),
  (`quan("9.81 kg m/s^2")`.text, quan("9.81 kg m/s^2")),
)

#set-unit(fraction: "inline", lowercase-liter: true)

After `set-unit(fraction: "inline", lowercase-liter: true)`: #zi.m-s[12.5],
#zi.kg-m3[998.2], #zi.J-K[1.380649e-23], #zi.liter[2.5], #zi.mL[250], #quan[60 km/h].
