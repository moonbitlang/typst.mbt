///|
test "format_num" {
  // Integers use `itoa`, everything else `ryu` after rounding to nine
  // decimal places.
  inspect(@svg.format_num(0.0), content="0")
  inspect(@svg.format_num(-0.0), content="0")
  inspect(@svg.format_num(2.0), content="2")
  inspect(@svg.format_num(-12.5), content="-12.5")
  inspect(@svg.format_num(0.1), content="0.1")
  inspect(@svg.format_num(1.0 / 3.0), content="0.333333333")
  inspect(@svg.format_num(248.586456693), content="248.586456693")
  inspect(@svg.format_num(0.00001), content="0.00001")
  inspect(@svg.format_num(0.000001234), content="1.234e-6")
  inspect(@svg.format_num(0.000000001), content="1e-9")
  inspect(@svg.format_num(0.0000000004), content="0")
  inspect(@svg.format_num(-0.00000000049), content="0")
  inspect(@svg.format_num(12345678.5), content="12345678.5")
}
