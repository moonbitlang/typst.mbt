///|
// Examples from the documentation of `codex::styling`.
test "MathStyle::select" {
  assert_true(
    @library.MathStyle::select('α', Some(Fraktur), true, None) is BoldItalic,
  )
  assert_true(
    @library.MathStyle::select('R', Some(DoubleStruck), true, Some(true))
    is DoubleStruck,
  )
  assert_true(@library.MathStyle::select('x', None, false, None) is Italic)
  assert_true(@library.MathStyle::select('A', None, false, None) is Italic)
  assert_true(@library.MathStyle::select('Γ', None, false, None) is Plain)
  assert_true(@library.MathStyle::select('1', None, true, None) is Bold)
}

///|
test "to_style" {
  inspect(@library.to_style('ظ', Looped), content="𞺚")
  inspect(@library.to_style('Q', Chancery), content="𝒬\u{fe00}")
  let s = StringBuilder()
  for c in "xγΩAذح1∑س" {
    s.write_string(@library.to_style(c, DoubleStruck))
  }
  inspect(s.to_string(), content="𝕩ℽΩ𝔸𞺸𞺧𝟙⅀𞺮")
  inspect(@library.to_style('h', Italic), content="ℎ")
}
