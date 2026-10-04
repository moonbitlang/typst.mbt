// Ports of the unit tests of `codex::numeral_systems`.

///|
fn rep(system : NamedNumeralSystem, n : UInt64) -> String {
  match system.system().represent(n) {
    Ok(s) => s
    Err(_) => "<err>"
  }
}

///|
test "shorthands are one" {
  for named in NamedNumeralSystem::all() {
    if named.shorthand() is Some(shorthand) {
      assert_eq(rep(named, 1), shorthand)
    }
  }
}

///|
test "arabic numerals" {
  for n in 0UL..<=9999UL {
    assert_eq(rep(Arabic, n), n.to_string())
  }
}

///|
test "latin" {
  assert_eq(rep(LowerLatin, 1), "a")
  assert_eq(rep(LowerLatin, 26), "z")
  assert_eq(rep(LowerLatin, 27), "aa")
  assert_eq(rep(UpperLatin, 28), "AB")
  assert_eq(rep(LowerLatin, 26 + 26 * 26), "zz")
  assert_eq(rep(LowerLatin, 26 + 26 * 26 + 1), "aaa")
  assert_eq(rep(LowerLatin, 0), "<err>")
}

///|
test "roman" {
  let expected = [
    "n", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii",
    "xiii", "xiv", "xv", "xvi", "xvii", "xviii", "xix", "xx", "xxi", "xxii", "xxiii",
    "xxiv", "xxv", "xxvi", "xxvii", "xxviii", "xxix", "xxx", "xxxi", "xxxii", "xxxiii",
    "xxxiv", "xxxv", "xxxvi", "xxxvii", "xxxviii", "xxxix", "xl", "xli", "xlii",
    "xliii", "xliv", "xlv", "xlvi",
  ]
  for n, expect in expected {
    assert_eq(rep(LowerRoman, n.to_uint64()), expect)
    assert_eq(rep(UpperRoman, n.to_uint64()), expect.to_upper())
  }
}

///|
test "symbolic" {
  let expected = ["a", "b", "aa", "bb", "aaa", "bbb", "aaaa", "bbbb"]
  for i, r in expected {
    let s = NumeralSystem::Symbolic(["a", "b"]).represent(i.to_uint64() + 1)
    assert_eq(s, Ok(r))
  }
}

///|
test "fixed systems" {
  let symbols = ["a", "b", "c", "d", "e", "f", "g"]
  for n in 0..<symbols.length() {
    for i in 0..<n {
      let sub = ReadOnlyArray::from_array(symbols[0:n])
      assert_eq(
        NumeralSystem::Fixed(sub).represent(i.to_uint64()),
        Ok(symbols[i]),
      )
      assert_eq(
        NumeralSystem::ZerolessFixed(sub).represent(i.to_uint64() + 1),
        Ok(symbols[i]),
      )
    }
  }
}

///|
test "chinese" {
  assert_eq(rep(LowerSimplifiedChinese, 0), "零")
  assert_eq(rep(LowerSimplifiedChinese, 10), "十")
  assert_eq(rep(LowerSimplifiedChinese, 110), "一百一十")
  assert_eq(rep(LowerSimplifiedChinese, 10012), "一万零一十二")
  assert_eq(rep(UpperTraditionalChinese, 120034), "拾貳萬零參拾肆")
}
