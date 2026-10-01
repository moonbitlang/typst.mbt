// Generated from the Rust `regex` crate (1.13). Do not edit.

///|
let oracle_cases : Array[(String, String, String)] = [
  (
    "\\d", "a1b22c333", "[1..2][3..4][4..5][6..7][7..8][8..9] split=\"a\",\"b\",\"\",\"c\",\"\",\"\",\"\"",
  ),
  ("\\d+", "a1b22c333", "[1..2][3..5][6..9] split=\"a\",\"b\",\"c\",\"\""),
  ("\\d*", "a1b22", "[0..0][1..2][3..5] split=\"\",\"a\",\"b\",\"\""),
  (
    "1[0-9]", "10 11 9 120", "[0..2][3..5][8..10] split=\"\",\" \",\" 9 \",\"0\"",
  ),
  (
    "whole", "the whole wholesome", "[4..9][10..15] split=\"the \",\" \",\"some\"",
  ),
  ("\\d{1,2}$", "abc 123", "[5..7] split=\"abc 1\",\"\""),
  (
    "\\(|\\)", "f(x) (y)", "[1..2][3..4][5..6][7..8] split=\"f\",\"x\",\" \",\"y\",\"\"",
  ),
  (
    "[0-9]", "hello 2 world 3", "[6..7][14..15] split=\"hello \",\" world \",\"\"",
  ),
  (
    ".", "héllo 🌍!", "[0..1][1..3][3..4][4..5][5..6][6..7][7..11][11..12] split=\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\"",
  ),
  (
    "(\\w+) (\\w+)", "hello world foo bar", "[0..11 0..5 6..11][12..19 12..15 16..19] split=\"\",\" \",\"\"",
  ),
  ("^\\d+$", "12345", "[0..5] split=\"\",\"\""),
  ("^\\d+$", "123a45", " split=\"123a45\""),
  ("^[abc]+$", "abcabc", "[0..6] split=\"\",\"\""),
  ("^[abc]$", "ab", " split=\"ab\""),
  (
    "^(newline|注释|换行newline|newline换行)$", "换行newline", "[0..13 0..13] split=\"\",\"\"",
  ),
  (
    "^(.+)\\s*(:)\\s*(.+)$", "key : value", "[0..11 0..4 4..5 6..11] split=\"\",\"\"",
  ),
  (
    "\\w+\\.?", "Hello. World again.", "[0..6][7..12][13..19] split=\"\",\" \",\" \",\"\"",
  ),
  (
    "\\w+", "Straße café naïve 東京", "[0..7][8..13][14..20][21..27] split=\"\",\" \",\" \",\" \",\"\"",
  ),
  ("\\p{Letter}", "a1β2東", "[0..1][2..4][5..8] split=\"\",\"1\",\"2\",\"\""),
  (
    "\\d{2}:\\d{2}", "at 12:34 and 5:67 or 99:00", "[3..8][21..26] split=\"at \",\" and 5:67 or \",\"\"",
  ),
  ("\\d$", "abc1\n2", "[5..6] split=\"abc1\\n\",\"\""),
  (
    "\\[|\\]", "[a] [b]", "[0..1][2..3][4..5][6..7] split=\"\",\"a\",\" \",\"b\",\"\"",
  ),
  ("\\S", "a b\tc", "[0..1][2..3][4..5] split=\"\",\" \",\"\\t\",\"\""),
  ("[mit]+e", "time mite emit", "[0..4][5..9] split=\"\",\" \",\" emit\""),
  ("[a-z]+", "ABC def GHI jkl", "[4..7][12..15] split=\"ABC \",\" GHI \",\"\""),
  ("[a-z]", "Z", " split=\"Z\""),
  ("[Tt]ys", "Typst typst tys", "[12..15] split=\"Typst typst \",\"\""),
  ("[,;]", "a,b;c", "[1..2][3..4] split=\"a\",\"b\",\"c\""),
  (
    "Who's|We've", "Who's there? We've come.", "[0..5][13..18] split=\"\",\" there? \",\" come.\"",
  ),
  ("20-FFFF", "20-FFFF", "[0..7] split=\"\",\"\""),
  (
    "(\\d+):(\\d+)", "10:20 30:40", "[0..5 0..2 3..5][6..11 6..8 9..11] split=\"\",\" \",\"\"",
  ),
  (
    "(VAR_GLOBAL|END_VAR||BOOL)", "VAR_GLOBAL x END_VAR BOOL", "[0..10 0..10][11..11 11..11][12..12 12..12][13..20 13..20][21..21 21..21][22..22 22..22][23..23 23..23][24..24 24..24][25..25 25..25] split=\"\",\" \",\"x\",\" \",\" \",\"B\",\"O\",\"O\",\"L\",\"\"",
  ),
  (
    "(Lua)?(La)?TeX", "LuaTeX LaTeX TeX LuaLaTeX", "[0..6 0..3 -][7..12 - 7..9][13..16 - -][17..25 17..20 20..22] split=\"\",\" \",\" \",\" \",\"\"",
  ),
  (
    "(?i)rust", "Rust RUST rust rUsT", "[0..4][5..9][10..14][15..19] split=\"\",\" \",\" \",\" \",\"\"",
  ),
  (
    "(?i)\\bworld\\b", "Hello World worldwide WORLD", "[6..11][22..27] split=\"Hello \",\" worldwide \",\"\"",
  ),
  ("(,\n)?\\)$", "(a,\n)", "[2..5 2..4] split=\"(a\",\"\""),
  ("", "abc", "[0..0][1..1][2..2][3..3] split=\"\",\"a\",\"b\",\"c\",\"\""),
  ("a*", "baaac", "[0..0][1..4][5..5] split=\"\",\"b\",\"c\",\"\""),
  ("a*?", "aaa", "[0..0][1..1][2..2][3..3] split=\"\",\"a\",\"a\",\"a\",\"\""),
  ("(a|ab)(c|bcd)(d*)", "abcd", "[0..4 0..1 1..4 4..4] split=\"\",\"\""),
  ("(a*)*", "b", "[0..0 0..0][1..1 1..1] split=\"\",\"b\",\"\""),
  ("(a*)+", "b", "[0..0 0..0][1..1 1..1] split=\"\",\"b\",\"\""),
  ("(a|b)*", "abab", "[0..4 3..4] split=\"\",\"\""),
  ("(a?)*?b", "aab", "[0..3 1..2] split=\"\",\"\""),
  ("x*", "xxyxx", "[0..2][3..5] split=\"\",\"y\",\"\""),
  (
    "\\b", "hello world", "[0..0][5..5][6..6][11..11] split=\"\",\"hello\",\" \",\"world\",\"\"",
  ),
  ("\\B", "ab cd", "[1..1][4..4] split=\"a\",\"b c\",\"d\""),
  ("^", "a\nb\nc", "[0..0] split=\"\",\"a\\nb\\nc\""),
  ("(?m)^", "a\nb\nc", "[0..0][2..2][4..4] split=\"\",\"a\\n\",\"b\\n\",\"c\""),
  ("(?m)$", "a\nb\nc", "[1..1][3..3][5..5] split=\"a\",\"\\nb\",\"\\nc\",\"\""),
  (
    "(?m)^\\w+$", "one\ntwo\nthree", "[0..3][4..7][8..13] split=\"\",\"\\n\",\"\\n\",\"\"",
  ),
  ("(?s).+", "a\nb", "[0..3] split=\"\",\"\""),
  (".+", "a\nb", "[0..1][2..3] split=\"\",\"\\n\",\"\""),
  ("[^a]", "abc", "[1..2][2..3] split=\"a\",\"\",\"\""),
  ("(?i)[^a]", "aAbB", "[2..3][3..4] split=\"aA\",\"\",\"\""),
  ("(?i)ǅ", "ǄǅǆDŽ", "[0..2][2..4][4..6] split=\"\",\"\",\"\",\"DŽ\""),
  ("(?i)k", "kKK", "[0..1][1..2][2..3] split=\"\",\"\",\"\",\"\""),
  ("[[:alpha:]]+", "ab12cd", "[0..2][4..6] split=\"\",\"12\",\"\""),
  ("[[:^digit:]]+", "ab12cd", "[0..2][4..6] split=\"\",\"12\",\"\""),
  ("[\\d&&[0-4]]+", "0123456789", "[0..5] split=\"\",\"56789\""),
  ("[a-z--[aeiou]]+", "hello", "[0..1][2..4] split=\"\",\"e\",\"o\""),
  ("[a-z~~[a-c]]+", "abxyz", "[2..5] split=\"ab\",\"\""),
  ("\\p{Greek}+", "abc αβγ def", "[4..10] split=\"abc \",\" def\""),
  ("\\P{L}+", "abc 123 def", "[3..8] split=\"abc\",\"def\""),
  ("\\p{gc=Lu}", "aBcD", "[1..2][3..4] split=\"a\",\"c\",\"\""),
  ("\\p{Lu}", "aBcD", "[1..2][3..4] split=\"a\",\"c\",\"\""),
  ("\\pL", "1a", "[1..2] split=\"1\",\"\""),
  ("\\p{Han}", "漢字かな", "[0..3][3..6] split=\"\",\"\",\"かな\""),
  ("\\p{sc=Hiragana}+", "漢字かな", "[6..12] split=\"漢字\",\"\""),
  ("\\p{Alphabetic}+", "a1b", "[0..1][2..3] split=\"\",\"1\",\"\""),
  ("\\p{White_Space}", "a b", "[1..2] split=\"a\",\"b\""),
  ("\\x41B\\U00000043\\x{44}", "ABCD", "[0..4] split=\"\",\"\""),
  ("\\u{1F600}", "x😀y", "[1..5] split=\"x\",\"y\""),
  ("a{2}", "aaaaa", "[0..2][2..4] split=\"\",\"\",\"a\""),
  ("a{2,}", "aaaaa", "[0..5] split=\"\",\"\""),
  ("a{2,3}", "aaaaaaa", "[0..3][3..6] split=\"\",\"\",\"a\""),
  ("a{2,3}?", "aaaaaaa", "[0..2][2..4][4..6] split=\"\",\"\",\"\",\"a\""),
  (
    "a{,3}", "aaa", "error: regex parse error:\n    a{,3}\n      ^\nerror: repetition quantifier expects a valid decimal",
  ),
  ("(?x) a b c # comment", "abc", "[0..3] split=\"\",\"\""),
  ("(?U)a+", "aaa", "[0..1][1..2][2..3] split=\"\",\"\",\"\",\"\""),
  ("(?U)a+?", "aaa", "[0..3] split=\"\",\"\""),
  (
    "(?P<year>\\d{4})-(?<month>\\d{2})", "2024-01 1999-12", "[0..7 0..4 5..7][8..15 8..12 13..15] split=\"\",\" \",\"\"",
  ),
  ("a|b|c", "xaybzc", "[1..2][3..4][5..6] split=\"x\",\"y\",\"z\",\"\""),
  ("(a)|(b)", "ab", "[0..1 0..1 -][1..2 - 1..2] split=\"\",\"\",\"\""),
  ("(?:ab)+", "ababab", "[0..6] split=\"\",\"\""),
  (
    "\\bfoo\\b", "foo foobar barfoo foo", "[0..3][18..21] split=\"\",\" foobar barfoo \",\"\"",
  ),
  ("\\b{start}\\w+", "hi there", "[0..2][3..8] split=\"\",\" \",\"\""),
  ("\\w+\\b{end}", "hi there", "[0..2][3..8] split=\"\",\" \",\"\""),
  ("\\<\\w", "hi there", "[0..1][3..4] split=\"\",\"i \",\"here\""),
  ("(", "abc", "error: regex parse error:\n    (\n    ^\nerror: unclosed group"),
  (")", "abc", "error: regex parse error:\n    )\n    ^\nerror: unopened group"),
  (
    "[", "abc", "error: regex parse error:\n    [\n    ^\nerror: unclosed character class",
  ),
  (
    "a{2,1}", "abc", "error: regex parse error:\n    a{2,1}\n     ^^^^^\nerror: invalid repetition count range, the start must be <= the end",
  ),
  (
    "\\k", "abc", "error: regex parse error:\n    \\k\n    ^^\nerror: unrecognized escape sequence",
  ),
  (
    "\\1", "abc", "error: regex parse error:\n    \\1\n    ^^\nerror: backreferences are not supported",
  ),
  (
    "(?=a)", "abc", "error: regex parse error:\n    (?=a)\n    ^^^\nerror: look-around, including look-ahead and look-behind, is not supported",
  ),
  (
    "(?i", "abc", "error: regex parse error:\n    (?i\n       ^\nerror: expected flag but got end of regex",
  ),
  (
    "(?z)", "abc", "error: regex parse error:\n    (?z)\n      ^\nerror: unrecognized flag",
  ),
  (
    "\\p{Foo}", "abc", "error: regex parse error:\n    \\p{Foo}\n    ^^^^^^^\nerror: Unicode property not found",
  ),
  (
    "\\p{gc=Foo}", "abc", "error: regex parse error:\n    \\p{gc=Foo}\n    ^^^^^^^^^^\nerror: Unicode property value not found",
  ),
  (
    "x{", "abc", "error: regex parse error:\n    x{\n     ^\nerror: unclosed counted repetition",
  ),
  (
    "*", "abc", "error: regex parse error:\n    *\n    ^\nerror: repetition operator missing expression",
  ),
  ("a**", "aaa", "[0..3] split=\"\",\"\""),
  (
    "[z-a]", "abc", "error: regex parse error:\n    [z-a]\n     ^^^\nerror: invalid character class range, the start must be <= the end",
  ),
  (
    "(?P<n>a)(?P<n>b)", "ab", "error: regex parse error:\n    (?P<n>a)(?P<n>b)\n        ^       ^\nerror: duplicate capture group name",
  ),
  ("\\xFF", "ÿ", "[0..2] split=\"\",\"\""),
  (
    "(?-u)\\xFF", "ÿ", "error: regex parse error:\n    (?-u)\\xFF\n         ^^^^\nerror: pattern can match invalid UTF-8",
  ),
  (
    "(?-u).", "a", "error: regex parse error:\n    (?-u).\n         ^\nerror: pattern can match invalid UTF-8",
  ),
  ("(?-u)\\w+", "abc é", "[0..3] split=\"\",\" é\""),
  ("[\\u{20}-\\u{FFFF}]", "a\tb", "[0..1][2..3] split=\"\",\"\\t\",\"\""),
  ("[\\u{1D49C}-\\u{1D503}]", "x𝒜y", "[1..5] split=\"x\",\"y\""),
  (
    "[🔗⛓‍💥]", "🔗 ⛓‍💥", "[0..4][5..8][8..11][11..15] split=\"\",\" \",\"\",\"\",\"\"",
  ),
  ("[^🖥️]", "a🖥️b", "[0..1][8..9] split=\"\",\"🖥\\u{fe0f}\",\"\""),
  ("\\d", "١٢٣", "[0..2][2..4][4..6] split=\"\",\"\",\"\",\"\""),
  (
    "(?i)straße", "STRASSE strasse Straße", "[16..23] split=\"STRASSE strasse \",\"\"",
  ),
  ("(?i)ß", "ẞ ß", "[0..3][4..6] split=\"\",\" \",\"\""),
  ("(?i)[a-c]+", "ABCabc", "[0..6] split=\"\",\"\""),
  ("(?i)σ", "Σσς", "[0..2][2..4][4..6] split=\"\",\"\",\"\",\"\""),
  ("é", "é", "[0..2] split=\"\",\"\""),
  ("café", "café café", "[7..12] split=\"cafe\\u{301} \",\"\""),
  ("\\s+", "a \t\n b", "[1..5] split=\"a\",\"b\""),
  ("^$", "", "[0..0] split=\"\",\"\""),
  ("^$", "a", " split=\"a\""),
  ("a$", "a\n", " split=\"a\\n\""),
  ("(?R)^a$", "a\\r\nb", " split=\"a\\\\r\\nb\""),
  ("x", "", " split=\"\""),
  ("[[:word:]]+", "foo_bar baz", "[0..7][8..11] split=\"\",\" \",\"\""),
  ("\\D+", "ab12", "[0..2] split=\"\",\"12\""),
  ("\\W+", "ab, cd!", "[2..4][6..7] split=\"ab\",\"cd\",\"\""),
  ("(?i)Δ", "δΔ", "[0..2][2..4] split=\"\",\"\",\"\""),
  ("(a)(b)?", "a", "[0..1 0..1 -] split=\"\",\"\""),
  ("(a(b)?)+", "aba", "[0..3 2..3 1..2] split=\"\",\"\""),
  (
    "a\n(", "x", "error: regex parse error:\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n1: a\n2: (\n   ^\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\nerror: unclosed group",
  ),
  (
    "(?x)a\n  [", "x", "error: regex parse error:\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n1: (?x)a\n2:   [\n     ^\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\nerror: unclosed character class",
  ),
  ("\\d*", "١a٢", "[0..2][3..5] split=\"\",\"a\",\"\""),
  ("(?i)[^k]", "kKKa", "[3..4] split=\"kKK\",\"\""),
  ("(?i)[[:upper:]]+", "abcXYZ", "[0..6] split=\"\",\"\""),
  ("(?i)\\p{Lu}+", "abcXYZ", "[0..6] split=\"\",\"\""),
  (
    "[\\p{Greek}--\\p{Lu}]+", "αΑβΒ", "[0..2][4..6] split=\"\",\"Α\",\"Β\"",
  ),
  ("\\b\\w", "über straße", "[0..2][6..7] split=\"\",\"ber \",\"traße\""),
  ("\\B\\w", "über", "[2..3][3..4][4..5] split=\"ü\",\"\",\"\",\"\""),
  ("(?u:\\w)+(?-u:\\w)+", "éa", "[0..3] split=\"\",\"\""),
  ("(a+|b+)*c", "aabbac", "[0..6 4..5] split=\"\",\"\""),
  ("(a*)(b*)", "ab", "[0..2 0..1 1..2] split=\"\",\"\""),
  ("((a)|b)+", "ab", "[0..2 1..2 0..1] split=\"\",\"\""),
  ("(?i)(?-i:a)A", "aA AA aa", "[0..2][6..8] split=\"\",\" AA \",\"\""),
  ("a(?i)b|c", "aB C", "[0..2][3..4] split=\"\",\" \",\"\""),
  ("x*?y", "xxy", "[0..3] split=\"\",\"\""),
  (".*?", "ab", "[0..0][1..1][2..2] split=\"\",\"a\",\"b\",\"\""),
  ("(?s:.)", "\n", "[0..1] split=\"\",\"\""),
  ("[^\n]+", "a\nb", "[0..1][2..3] split=\"\",\"\\n\",\"\""),
  ("\\p{Any}", "x", "[0..1] split=\"\",\"\""),
  ("\\p{Assigned}+", "ab", "[0..2] split=\"\",\"\""),
  ("\\p{Is_Greek}", "α", "[0..2] split=\"\",\"\""),
  (
    "\\p{isc}", "a", "error: regex parse error:\n    \\p{isc}\n    ^^^^^^^\nerror: Unicode property not found",
  ),
  ("\\p{scx=Greek}", "α", "[0..2] split=\"\",\"\""),
  ("[\\w&&\\d]", "a1", "[1..2] split=\"a\",\"\""),
  ("[-a]", "-a", "[0..1][1..2] split=\"\",\"\",\"\""),
  ("[a-]", "-a", "[0..1][1..2] split=\"\",\"\",\"\""),
  ("[]a]", "]a", "[0..1][1..2] split=\"\",\"\",\"\""),
  ("[^]a]", "]ab", "[2..3] split=\"]a\",\"\""),
  (
    "\\x{110000}", "a", "error: regex parse error:\n    \\x{110000}\n       ^^^^^^\nerror: hexadecimal literal is not a Unicode scalar value",
  ),
  (
    "\\u{}", "a", "error: regex parse error:\n    \\u{}\n      ^^\nerror: hexadecimal literal empty",
  ),
  (
    "(?<1a>x)", "x", "error: regex parse error:\n    (?<1a>x)\n       ^\nerror: invalid capture group character",
  ),
  (
    "(?<>x)", "x", "error: regex parse error:\n    (?<>x)\n       ^\nerror: empty capture group name",
  ),
  (
    "a{1,2", "a", "error: regex parse error:\n    a{1,2\n     ^^^^\nerror: unclosed counted repetition",
  ),
  (
    "\\b{foo}", "a", "error: regex parse error:\n    \\b{foo}\n       ^^^\nerror: unrecognized special word boundary assertion, valid choices are: start, end, start-half or end-half",
  ),
  ("\\b{2}", "a", "[0..0][1..1] split=\"\",\"a\",\"\""),
  (
    "(?i-)a", "a", "error: regex parse error:\n    (?i-)a\n       ^\nerror: dangling flag negation operator",
  ),
  (
    "(?--i)a", "a", "error: regex parse error:\n    (?--i)a\n      ^^\nerror: flag negation operator repeated",
  ),
  (
    "(?ii)a", "a", "error: regex parse error:\n    (?ii)a\n      ^^\nerror: duplicate flag",
  ),
  ("[[:alpha:]-z]", "a", "[0..1] split=\"\",\"\""),
  ("\\pZ+", "a b", "[1..2] split=\"a\",\"b\""),
  ("\\p{Zs}", "a b", "[1..2] split=\"a\",\"b\""),
  ("\\p{L}", "1", " split=\"1\""),
  (
    "\\p{Cs}", "a", "error: regex parse error:\n    \\p{Cs}\n    ^^^^^^\nerror: Unicode property value not found",
  ),
  (
    "\\p{Unknown}", "a", "error: regex parse error:\n    \\p{Unknown}\n    ^^^^^^^^^^^\nerror: Unicode property value not found",
  ),
  (
    "\\p{Katakana_Or_Hiragana}", "a", "error: regex parse error:\n    \\p{Katakana_Or_Hiragana}\n    ^^^^^^^^^^^^^^^^^^^^^^^^\nerror: Unicode property value not found",
  ),
  ("ab|a", "ab", "[0..2] split=\"\",\"\""),
  ("a|ab", "ab", "[0..1] split=\"\",\"b\""),
  (
    "(|a)+", "aa", "[0..0 0..0][1..1 1..1][2..2 2..2] split=\"\",\"a\",\"a\",\"\"",
  ),
  ("(a|)+", "aa", "[0..2 1..2] split=\"\",\"\""),
  ("(a*)*b", "aab", "[0..3 0..2] split=\"\",\"\""),
  ("(a*)+?b", "aab", "[0..3 0..2] split=\"\",\"\""),
  ("(?:a|b)*?c", "ababc", "[0..5] split=\"\",\"\""),
]

///|
test "regex oracle" {
  let failures = []
  for case in oracle_cases {
    let (pattern, hay, expected) = case
    let actual = describe(pattern, hay)
    if actual != expected {
      failures.push(
        "pattern \{@unicode.rust_debug_str(pattern)} on \{@unicode.rust_debug_str(hay)}:\n  expected \{expected}\n  actual   \{actual}",
      )
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n"))
  }
}
