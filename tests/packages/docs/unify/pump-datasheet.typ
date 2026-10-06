// unify 0.8.1: `num`, `unit`, `qty`, `numrange`, `qtyrange` in running text, tables and
// display math: prefixes (words and shorthand), per modes (symbol, fraction, fraction-short),
// symmetric and asymmetric uncertainties, exponents, separators, multipliers, raw units,
// angle/money/binary units, `add-unit`, `add-prefix`.
// Engine: regex captures, csv data of the package, state read in context, `eval` of math
// markup strings built at run time.
#import "@preview/unify:0.8.1": num, unit, qty, numrange, qtyrange, add-unit, add-prefix

#set page(width: 150mm, height: 185mm, margin: (x: 13mm, y: 14mm), numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show table.cell.where(y: 0): strong

#align(center)[
  #text(14pt, weight: "bold")[Circulation Pump CP-40 --- Data Sheet] \
  revision 7, for the heating circuit of the east wing
]

= Ratings

The pump delivers #qty("12.5", "m^3/h") against a head of #qty("6.2", "m") and
draws #qty("370", "W") from a #qty("230", "V") supply at #qty("50", "Hz"). Its
rotor turns at #qty("2850", "1/min", rawunit: true), that is
#qty("47.5", "per second"), and the housing is rated for #qty("1.0e6", "Pa")
or #qty("10", "bar"). The motor winding has #qty("38.4+-0.5", "ohm") and
#qty("0.214+0.006-0.004", "henry"); the run capacitor is #qty("8", "uF"), written
out #qty("8", "micro farad"). The number alone can be typeset as well:
#num("2850"), #num("12500"), #num("123456.789012"), #num("-0.00012345"),
#num("6.02214076e23"), #num("e-9"), #num(1234567), #num[9.81].

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header[Quantity][Minimum][Nominal][Maximum],
    [Flow], [#qty("2.0", "m^3/h")], [#qty("12.5", "m^3/h")], [#qty("17.0", "m^3/h")],
    [Head], [#qty("0.8", "m")], [#qty("6.2", "m")], [#qty("7.4", "m")],
    [Fluid temperature], [#qty("-10", "dC")], [#qty("60", "celsius")], [#qty("110", "dC")],
    [Supply voltage], [#qty("207", "V")], [#qty("230", "V")], [#qty("253", "V")],
    [Input power], [#qty("95", "W")], [#qty("0.37", "kW")], [#qty("410", "W")],
    [Sound pressure], [---], [#qty("43", "dB")], [#qty("47+-2", "dB")],
    [Mass], [---], [#qty("5.80+-0.05", "kg")], [---],
  ),
  caption: [Operating window, #qtyrange("2", "17", "m^3/h") at #qtyrange("0.8", "7.4", "m")],
)

= How derived units are written

The same unit in the three `per` modes, from words and from shorthand:

#table(
  columns: (1fr, auto, auto, auto),
  align: (left, center, center, center),
  table.header[Input][symbol][fraction][fraction-short],
  [`"meter per second squared"`],
  unit("meter per second squared"),
  unit("meter per second squared", per: "fraction"),
  unit("meter per second squared", per: "fraction-short"),
  [`"kg m^2/s^3/A"`],
  unit("kg m^2/s^3/A"),
  unit("kg m^2/s^3/A", per: "/"),
  unit("kg m^2/s^3/A", per: "\\/"),
  [`"joule per mole per kelvin"`],
  unit("joule per mole per kelvin"),
  unit("joule per mole per kelvin", per: "fraction"),
  unit("joule per mole per kelvin", per: "fraction-short"),
  [`"kilo watt hour"`],
  unit("kilo watt hour"),
  unit("kilo watt hour", per: "fraction"),
  unit("kilo watt hour", per: "fraction-short"),
  [`"mm²/s"`],
  unit("mm²/s"),
  unit("mm²/s", per: "fraction"),
  unit("mm²/s", per: "fraction-short"),
  [`"per centi meter cubed"`],
  unit("per centi meter cubed"),
  unit("per centi meter cubed", per: "fraction"),
  unit("per centi meter cubed", per: "fraction-short"),
)

Spacing is adjustable: #qty("9.81", "m/s^2"), tighter #qty("9.81", "m/s^2", num-unit-space: "#h(0.05em)"),
wider #qty("9.81", "kg m/s^2", space: "#h(2mm)", num-unit-space: "#h(1mm)"), and with a dot between the
units #qty("3.6", "N m", space: "dot.c"). Angles attach directly: the impeller blades are set at
#qty("22.5", "deg") with a tolerance of #qty("30", "arcminute"), next to #qty("0.39", "rad"). Prices and
storage use the same machinery: #qty("184.90", "eur"), #qty("215", "dollar"), #qty("512", "kibi byte"),
#qty("2", "MiB"), #qty("1.5", "Mb/s"), #qty("95", "percent").

= Numbers

#table(
  columns: (auto, 1fr, auto, 1fr),
  table.header[Input][Result][Input][Result],
  [`"1234567.891"`], [#num("1234567.891")], [thousandsep `","`], [#num("1234567.891", thousandsep: ",")],
  [`"1234,5678"`], [#num("1234,5678")], [thousandsep `"."`], [#num("1234567,125", thousandsep: ".")],
  [`"4.2+-0.3"`], [#num("4.2+-0.3")], [`"4.2±0.3e-3"`], [#num("4.2±0.3e-3")],
  [`"1.32+0.50-0.27"`], [#num("1.32+0.50-0.27")], [`"1.32+0.50-0.27e6"`], [#num("1.32+0.50-0.27e6")],
  [`"3e8"`], [#num("3e8")], [multiplier `"times"`], [#num("2.998e8", multiplier: "times")],
  [`"-7.5E-4"`], [#num("-7.5E-4")], [thousandsep `"space"`], [#num("29979245800", thousandsep: "space")],
)

Ranges factor out a common exponent: #numrange("1.5e3", "2.5e3"), keep different ones apart:
#numrange("5e-3", "2e2"), and take another delimiter: #numrange("20", "80", delimiter: "\"to\""),
#numrange("0,25", "0,75", delimiter: "dots.h", space: "#h(1mm)"). With units:
#qtyrange("20", "80", "dC"), #qtyrange("1e3", "2e3", "meter per second squared", per: "/", delimiter: "\"to\""),
#qtyrange("0.37e3", "1.1e3", "W", multiplier: "times"), #qtyrange("4", "12", "l/min", space: "#h(0.1em)").

= In formulas

The hydraulic power follows from flow and head,
$ P_"hyd" = rho g Q H = qty("998", "kg/m^3") dot qty("9.81", "m/s^2") dot qty("3.47e-3", "m^3/s") dot qty("6.2", "m")
  approx qty("211", "W"), $
so the efficiency is $eta = qty("211", "W") slash qty("370", "W") = num("0.57")$, or #qty("57+-2", "percent").
The specific speed, with its uncertainty,
$ n_q = n sqrt(Q) / H^(3 slash 4) = num("42.6+1.8-1.1"), quad
  "Re" = (v d) / nu = (qty("2.76", "m/s") dot qty("40", "mm")) / qty("0.474e-6", "m^2/s") = num("2.33e5"). $

= Units of our own

#add-unit("revolution", "rev", "upright(\"rev\")")
#add-unit("flowunit", "FU", "upright(\"FU\")", space: false)
#add-prefix("myria", "my", "upright(\"my\")")

After registering them, #qty("2850", "rev/min") and #qty("47.5", "revolution per second") work, a unit
may ask for no space before it (#qty("3", "FU")), and a new prefix combines with old units:
#qty("1.2", "myria meter"), #qty("4", "mym").
