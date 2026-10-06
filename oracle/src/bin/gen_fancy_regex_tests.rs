//! Emits `regex/fancy/oracle_test.mbt` (and `syntect_oracle_test.mbt`):
//! MoonBit tests comparing the `regex/fancy` port with the real
//! `fancy-regex` 0.16.2 crate.
//!
//! - A hand-written corpus of patterns x haystacks (with Oniguruma mode on
//!   and off, builder options, error cases).
//! - The Oniguruma test suite bundled with the crate
//!   (`tests/oniguruma/test_utf8.c`), run like `tests/oniguruma.rs`
//!   (multi-line + Oniguruma mode).
//! - All regexes of syntect's bundled syntaxes (two-face
//!   `extra_no_newlines`), built like syntect does
//!   (`RegexBuilder::new(s).oniguruma_mode(true).build()`): every one must
//!   compile (or fail) identically; a sample is matched against code lines.
//!
//! For every haystack the description contains `is_match`, the captures of
//! `captures_from_pos` at every char boundary (at most 16) and the
//! `captures_iter` results.
//!
//! Usage: cargo run --release --bin gen_fancy_regex_tests -- <repo-root>, then
//! `moon fmt`.

use std::collections::BTreeSet;
use std::fmt::Write as _;

use fancy_regex::{Captures, Regex, RegexBuilder};

/// Builder flags: `o` Oniguruma mode, `i` case-insensitive, `m` multi-line,
/// `s` dot matches newline, `x` ignore whitespace, `b` backtrack limit 1000.
fn build(pattern: &str, flags: &str) -> Result<Regex, String> {
    let mut b = RegexBuilder::new(pattern);
    for f in flags.chars() {
        match f {
            'o' => {
                b.oniguruma_mode(true);
            }
            'i' => {
                b.case_insensitive(true);
            }
            'm' => {
                b.multi_line(true);
            }
            's' => {
                b.dot_matches_new_line(true);
            }
            'x' => {
                b.ignore_whitespace(true);
            }
            'b' => {
                b.backtrack_limit(1000);
            }
            _ => panic!("unknown flag {f}"),
        }
    }
    b.build().map_err(|e| format!("error: {e}"))
}

fn describe_caps(caps: &Captures) -> String {
    let mut out = String::from("[");
    for i in 0..caps.len() {
        if i > 0 {
            out.push(' ');
        }
        match caps.get(i) {
            Some(m) => write!(out, "{}..{}", m.start(), m.end()).unwrap(),
            None => out.push('-'),
        }
    }
    out.push(']');
    out
}

fn boundaries(hay: &str) -> Vec<usize> {
    let mut all: Vec<usize> = hay.char_indices().map(|(i, _)| i).collect();
    all.push(hay.len());
    if all.len() > 16 {
        let mut v: Vec<usize> = all[..12].to_vec();
        v.extend_from_slice(&all[all.len() - 4..]);
        v
    } else {
        all
    }
}

fn describe(re: &Regex, hay: &str) -> String {
    let mut out = String::new();
    match re.is_match(hay) {
        Ok(b) => write!(out, "m={b}").unwrap(),
        Err(e) => write!(out, "m=err:{e}").unwrap(),
    }
    for pos in boundaries(hay) {
        write!(out, " @{pos}:").unwrap();
        match re.captures_from_pos(hay, pos) {
            Ok(Some(caps)) => out.push_str(&describe_caps(&caps)),
            Ok(None) => out.push_str("none"),
            Err(e) => write!(out, "err:{e}").unwrap(),
        }
    }
    // A search on a prefix (like syntect's `&line[..end]`).
    let mid = (0..=hay.len() / 2).rev().find(|&i| hay.is_char_boundary(i)).unwrap();
    write!(out, " pre{mid}:").unwrap();
    match re.captures_from_pos(&hay[..mid], 0) {
        Ok(Some(caps)) => out.push_str(&describe_caps(&caps)),
        Ok(None) => out.push_str("none"),
        Err(e) => write!(out, "err:{e}").unwrap(),
    }
    out.push_str(" iter:");
    for (n, caps) in re.captures_iter(hay).enumerate() {
        if n >= 20 {
            out.push_str("...");
            break;
        }
        match caps {
            Ok(caps) => out.push_str(&describe_caps(&caps)),
            Err(e) => write!(out, "err:{e}").unwrap(),
        }
    }
    out
}

fn mbt_str(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 || c == '\u{7f}' => {
                out.push_str(&format!("\\u{{{:x}}}", c as u32))
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// (pattern, flags, haystacks)
fn corpus() -> Vec<(&'static str, &'static str, Vec<&'static str>)> {
    let words = vec!["foo foo", "foo bar foo", "", "a", "mirror mirror on the wall"];
    let digits = vec!["11 21 33", "1122 33", " 1122 33", "ab1c2", "x"];
    let mixed = vec![
        "héllo wörld",
        "δ Δ δδ",
        "foo 🎯 test bar BaR",
        "abc\ndef\n\nghi\n",
        "a\naaa\n",
        "\u{1F431}\u{1F436}\u{1F431}\u{1F436}",
    ];
    let code = vec![
        "fn main() { let x = 42; }",
        "  // comment here",
        "<div class=\"a\">text</div>",
        "def foo(bar, baz=1):",
        "\"str \\\"esc\\\" end\" 'c'",
        "0x1F 3.14e-10 1_000",
        "turbo::<Fish>",
    ];
    let mut v: Vec<(&'static str, &'static str, Vec<&'static str>)> = vec![];
    let both = |v: &mut Vec<_>, p: &'static str, h: &Vec<&'static str>| {
        v.push((p, "", h.clone()));
        v.push((p, "o", h.clone()));
    };
    // backrefs
    for p in [
        r"^(\w+) (\1)$",
        r"(\w+) \1",
        r"(\d)\1",
        r"(\d+)\1",
        r"(?P<foo>\d+)\k<foo>",
        r"(?P<foo>\d+)(?P=foo)",
        r"(?<n>\w)\k'n'",
        r"(a)?\1",
        r"(.+)\1+",
        r"(abc|def)\1",
        r"(abc|def)(?i:\1)",
        r"(?i)(?<word>\w+)\s+\k<word>",
        r"(.)(?i:\1)",
        r"(x|xy)\1",
        r"((?i:x|xy))\1",
        r"(([ab]+)\1b)",
        r"(..)(?<=\1\1)",
        r"\k<-1>",
        r"(a)\k<-1>",
        r"(a)(b)\k<-2>",
        r"(a)\k<+1>",
        r"(a)\k<1+0>",
        r"\1(.)",
        r"(.)\2",
        r"(?<a>.)\1",
        r"(a)\g<1>",
        r"(?<x>a)\g<x>",
        r"\g<x>(?<x>a)",
        r"\g<y>(?<x>a)",
        r"\g'0'",
        r"(?P>x)(?<x>a)",
        r"(.)(?(1)a|b)",
    ] {
        both(&mut v, p, &words);
        both(&mut v, p, &digits);
        v.push((p, "", mixed.clone()));
    }
    // look-around
    for p in [
        r"\w+(?=!)",
        r"(?<!AU)\$(\d+)",
        r"(?<=x|a)",
        r"(?<=a|bc)",
        r"(?<!a|bc)x",
        r"(?<=^a)",
        r"(?<=a(?:b|cd))",
        r"(?<=a+b+)",
        r"(?=x|a)",
        r"(?=(?!x)a(?:b|B)c)",
        r"a(?=\b)",
        r"a(?=\b|_)",
        r"(?!a(?=b)|x)",
        r"(?!`(?:[^`]+(?=`)|x)`)",
        r"\d*(?=[a-z])",
        r"\d*(?=é)",
        r"[a-z]{2}(?=[a-z])",
        r"(?=c)",
        r"abc(?=abc)",
        r"abc(?=a|b)",
        r"(abc|def)(?=\1)",
        r"(abc|def)(?=a(?!b))",
        r".(?=a)",
        r".(?=\ba+)",
        r"\s*(\w+)(?=\.)",
        r"(\w+)(?=\.)|(\w+)(?=!)",
        r"\s*(?<=[() ])(@\w+)(\([^)]*\))?\s*",
        r"(?<=\d)(?=(\d\d\d)+$)",
        r"(?<!\\)(\\\\)*\K\$",
        r"(?<=[^f])",
        r"(?<!^)\b",
    ] {
        both(&mut v, p, &code);
        v.push((p, "", digits.clone()));
        v.push((p, "", mixed.clone()));
        v.push((p, "", vec!["foo bar.", "foo! bar.", "so fancy! even with! iterators!", "abcabc", "abca", "abcaa", "xxa", "xxbc", "bcxx", "`a`", "ab", "a.", " @another(foo bar)   ", "1234567"]));
    }
    // atomic, possessive, repeats
    for p in [
        r"^a(?>bc|b)c$",
        r"^a(bc(?=d)|b)cd$",
        r"^a(?>bc(?=d)|b)cd$",
        r"(?>a+)b",
        r"a++b",
        r"a*+a",
        r"a?+a",
        r"a{1,3}+a",
        r"(?:ab)*+",
        r"(a(?=a)){2,}?",
        r"(a(?=a)){2}?a",
        r"(a(?=b)|)+?",
        r"(a(?=b)|)+?x",
        r"(?m)(?:^|a)+",
        r"(?m)(?:^|a)(?:^|a)*",
        r"(?m)(?>)(?:^|a)+",
        r"(?m)(?:^|a)+?",
        r"(?m)(?:^|a)+?$",
        r"(?m)(?>)(?:^|a)(?:^|a)*?$",
        r"(a|b|ab)*(?>c)",
        r"(x+x+)+(?>y)",
        r"a{2}(?=a)",
        r"a{2,}(?=a)",
        r"a{,3}(?=a)",
        r"a{ 2 , 3 }(?=a)",
        r"a{2,3}?(?=a)",
        r"a{3,2}",
        r"a{",
        r"a{1",
        r"a{1,",
        r"a{x}",
        r"x{2}{3}",
        r"(?U)a+(?=a)",
        r"(?U)a+?(?=a)",
        r"(?:a|())*(?=b)",
        r"(?:(a)|b)*\1",
        r"(a*)*b(?<=b)",
        r"(a*)+$(?<=a)",
        r"(?:a*?)*?b(?=b)",
    ] {
        both(&mut v, p, &vec!["abcc", "abc", "abcd", "aaa", "aaab", "ab", "a\naaa\n", "xxxxxxxxxxy", "abababababababababababababc", "aaaa{2}", "a{1,3}", "bb", "aab"]);
    }
    v.push((r"(a|b|ab)*(?>c)", "b", vec!["abababababababababababababababababababababababababab"]));
    v.push((r"(?i)(a|b|ab)*(?>c)", "b", vec!["abababababababababababababababababababababababababab"]));
    v.push((r"(x+x+)+(?>y)", "b", vec!["xxxxxxxxxxy", "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]));
    // conditionals
    for p in [
        r"(a)(?(1))",
        r"(?<group1>a)(?('group1'))b",
        r"(a)(b)?(?(2))",
        r"(a)(b?)(?(2))",
        r"(a)?b(?(1)c|d)",
        r"(?<group1>a)?b(?(<group1>)c|d)",
        r"^(a)?b(?(1)c|d)$",
        r"^(?(ab)c|d)$",
        r"^(?(\d)abc|\d!)$",
        r"^(?((?=\d))\w+|!)$",
        r"^(?((?=\d))abc)$",
        r"^(?((?=\w))abc)$",
        r"^(?((?=\d))\wabc|\d!)$",
        r"^(?((ab))c|d)$",
        r"(?(ab)c|d)",
        r"(?(ab)c|d|e)",
        r"(?(ab))",
        r"(?(1)a|b)",
        r"(?(+1)a|b)(c)",
        r"(?(-1)a|b)",
        r"(?(",
        r"(?(1",
        r"(([ab]+?)(?(1)\1| )c)+",
    ] {
        both(&mut v, p, &vec!["a", "ab", "abc", "abd", "ad", "bd", "bc", "5abc", "5!", "!", "", "acd", "aba c", "ab abc"]);
    }
    // \G, \K, \Z, \A, \z, \b, \B, \<, \>, \h, \e, \O
    for p in [
        r"\G(\d)\d",
        r"\G\d*",
        r"\G",
        r"a\Kb",
        r".+\Kb",
        r"(?:aaa\K)b",
        r"(?<=a\Kb)c",
        r"(?<!a\Kb)c",
        r"a(?=b\Kc)",
        r"a(?=b\Kc)..",
        r"a(?!b\Kc)",
        r"\s*(\w+\K)(?=\.)",
        r"\s*(b\Kar)(?=\.)",
        r"(\w+)\K\s*(\w+)(?=\.)",
        r"(\w\K)+\s*(\w+)(?=\.)",
        r"\Z",
        r"a\Z",
        r"\n\Z",
        r"\Aab",
        r"ab\z",
        r"\bfoo\b",
        r"\Boo\B",
        r"\<\w*\>",
        r"\<prefix_\w*\>",
        r"\h+",
        r"\H+",
        r"[\h_]+",
        r"\e",
        r"\O+",
        r"\b{start}",
        r"\B{x}",
        r"(?m)^\d+$(?=\n)",
        r"(?m:^)(\d+)",
        r"\$(?!\d)",
    ] {
        both(&mut v, p, &vec!["1122 33", " 1122 33", "aaab", "abc", "axc", "abx", "foo bar.", "hello\nworld\n\n\n", "ab", "ab\n", "foo food foo", "turbo::<Fish>", "not_prefix_oops prefix_with_suffix <prefix_>", "0xdeadBEEF g", "\u{1b}[0m", "a\nb", "1 test 123\n2 foo"]);
    }
    // escapes, classes, literals, unicode, case-insensitivity
    for p in [
        r"\a\f\n\r\t\v",
        r"[\[]",
        r"[\^]",
        r"[\<\>\.\ ]+",
        r"[\d]",
        r"[\e\n]",
        r"[]]",
        r"[^]]",
        r"[[a][bc]]",
        r"[a[^b]]",
        r"[\w&&a-c]",
        r"[[0-9]&&[^4]]",
        r"[a-z&&[^aeiou]]+",
        r"[[:alpha:]]+",
        r"[[:^digit:][:space:]]+",
        r"[\x41-\x5A]+",
        r"[\u0041-\u{5A}]+",
        r"\x41\u0042\U00000043\x{44}",
        r"\x{110000}",
        r"\x{D800}",
        r"\x",
        r"\xZZ",
        r"\u",
        r"\U",
        r"\x{}",
        r"\x{123456789}",
        r"\p{L}+",
        r"\pL+",
        r"\PL+",
        r"\p{Greek}+",
        r"\p{Lu}",
        r"(?i)\p{Ll}",
        r"\p{",
        r"\p",
        r"\q",
        r"\c",
        r"\ ",
        r"\#\%\-\&\~",
        r"(?i)[a-z]+",
        r"^(?i)[a-z]+$",
        r"(?i)\x61",
        r"(?i)straße",
        r"(?i)δ",
        r"(?i:ss)",
        r"(?i:ß)",
        r"(?i)ǅ",
        r"(?i)k",
        r"FOO(?i:bar)quux",
        r"(?i)foo(?-i)bar",
        r"(?i-i)a",
        r"(?-)a",
        r"(?)a",
        r"(?-u)a",
        r"(?u)a",
        r"(?z)a",
        r"(?i",
        r"(?#comment)a",
        r"(?#unclosed",
        r"(?x) a b # comment\n c",
        "(?x)\n  a # first\n  b # second\n",
        r"(?x)a\ b",
        r"(?x)[a b]",
        r"(?s:.)+",
        r".+",
        r"(?s).+",
        r"(?m)^.+$",
        r"(?m)$",
        r"$",
        r"^",
        "a|",
        "|a",
        "^(a|)$",
        "^(|a)$",
        r"a**",
        r"*a",
        r"a|*",
        r"(?=a)*",
        r"\b+",
        r"(?=a){2}",
        r"\K?",
        r"(a",
        r"a)",
        r"(?<name",
        r"(?<>a)",
        r"(?<1a>a)",
        r"(?<a-1>a)",
        r"(?P<name>a)(?P=name)",
        r"(?P=nope)",
        r"(?P<na",
        r"\k<nope>",
        r"\k<>",
        r"\k",
        r"\9",
        r"\0",
        r".\0",
        r"(.)\0\1",
        r"aa\1",
        r"a(a)\2",
        r"(a)\1(?<n>b)",
        r"(?<n>b)\1",
        r"\",
        r"a\",
        r"[a",
        r"[",
        r"[a-]",
        r"[\w-z]",
        r"[z-a]",
        r"[\b]",
        r"[\A]",
        r"[\Z]",
        r"[\K]",
        r"[\g]",
        r"[\x41]",
        r"[\k<a>]",
        r"[\1]",
        r"\g",
        r"\g<",
        r"\g<1",
        r"(((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((a)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))",
    ] {
        both(&mut v, p, &vec!["\u{7}\u{c}\n\r\t\u{b}", "[^]<>. ", "1", "\u{1b}\n", "]", "a", "c", "d", "4", "hello World", "ABCDE", "αβγ ΑΒΓ", "Straße STRASSE", "SS ß ẞ", "Δδ", "ǅǄǆ", "K k K", "FOObarquux FoObarQuUx FOOBARquux", "#%-&~", "a b c abc", "a\nb\n", "", "**a", "foo\nbar", "a\u{0}b"]);
    }
    // case-insensitive backrefs (byte-length based comparison upstream)
    for p in [
        r"(.)(?i:\1)",
        r"(..)(?i:\1)",
        r"(?i)(\w+)\s+\1",
        r"(?i)(.)\1",
        r"(?i)(\S+)-\1",
    ] {
        both(&mut v, p, &vec!["kK", "K k", "\u{212A}k", "k\u{212A}", "\u{212A}k\u{3b4}x", "\u{212A}\u{212A}", "\u{17f}s", "s\u{17f}", "\u{df}\u{1e9e}", "\u{1e9e}\u{df}", "\u{3a3}\u{3c3}\u{3c2}", "\u{3c2}\u{3a3}", "Greek : \u{3b4} \u{394}", "abc-ABC", "\u{e9}\u{c9}-\u{c9}\u{e9}", "\u{1c5}\u{1c4}\u{1c6}", "ab\u{e9}-AB\u{c9}"]);
    }
    // builder options
    for (p, f) in [
        (r"TEST foo", "i"),
        (r"TEST FOO", "i"),
        (r"FOO(?i:bar)quux", ""),
        (r"^test$", "m"),
        (r"test    foo", "x"),
        (r"<div>(.*?)<\/div>", "s"),
        (r"[a-z](?<=[^f])", "i"),
        (r"(?=test    foo)", "x"),
        ("\ntest  foo #hugo\n", "x"),
        (r"^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_'+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$", "i"),
        (r"\<prefix_\w*\>", ""),
        (r"\<prefix_\w*\>", "o"),
        (r"(\w)\1", "i"),
        (r"a.c", "s"),
        (r"(?-s)a.c", "s"),
        (r"(?=a.c)", "s"),
        (r"^b", "m"),
        (r"(?=^b)", "m"),
        (r"x$(?<=x)", "m"),
        (r"a b(?=c)", "x"),
        (r"[a b]+(?=c)", "x"),
        (r"a\ b(?=c)", "x"),
    ] {
        v.push((p, f, vec!["TEST foo", "test foo", "FOObarquux", "FoObarQuUx", "test\nhugo\ntest", "testfoo", "test    foo", "<div>\n    hello</div>", "J", "F", "j", "VALID@domain.com", "not_prefix_oops prefix_with_suffix <prefix_>", "Aa aa", "a\nc abc", "a\nb", "x\ny", "abc", "a bc", "aa bbc", "a c"]));
    }
    // syntect-style regexes
    for p in [
        r"(?x)
          (?:
            (?<![\w$])            # not preceded by a word char
            (?:0[xX]\h+)          # hex
          | (?:\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)  # decimal
          )
          (?![\w$])",
        r#"(?x)\b(fn)\s+([[:alpha:]_][[:alnum:]_]*)\s*(?=\()"#,
        r#""(?:[^"\\]|\\.)*""#,
        r"'(?:[^'\\]|\\.)'",
        r"(//).*$\n?",
        r"/\*(?:.|\n)*?\*/",
        r"\b(?:if|else|while|for|return|let|fn)\b",
        r"(?<=\.)\s*([A-Za-z_]\w*)",
        r"^\s*(#)\s*\b(include|define)\b",
        r"(?i)\b(select|from|where)\b",
        r"(<)([a-zA-Z0-9:.-]+)(?=[^>]*>)",
        r#"\s+([a-z-]+)(=)(")"#,
        r"(?<![\w.])\d+\.?(?!\.)",
        r"(\$)(\{)",
        r"\\(?:[nrt\\'\x22]|x\h{2}|u\{\h{1,6}\})",
        r"(?=\S)",
        r"$\n?",
        r"^(?!\s*$)",
        r"\s*\Z",
        r"(?:\G|^)\s*([a-z]+)",
        r"[[:upper:]][[:lower:]]*",
        r"\b(?i:true|false|null)\b",
        r"(?<=^|\s)#(?!\{).*$",
        r"([\w-]+)(?=\s*:)",
        r"(?:(?<=[^\w])|^)(@)(\w+)",
        r"((?:[a-z]+::)*)(<)",
        r"(?x:\s*([+-]?)\s*(\d+))",
        r"(?:(?:\+|-)?\b(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?)",
        r"(?<!\w)'(?=(?:[^'\\]|\\.)*')",
    ] {
        both(&mut v, p, &code);
    }
    v
}

/// Parse the Oniguruma tests like `tests/oniguruma.rs` (returns pattern and
/// text).
fn oniguruma_tests(source: &str) -> Vec<(String, String)> {
    let c_string = r#""((?:\\\\|\\"|[^"])*)""#;
    let re = regex::Regex::new(&format!(
        r"(?m)((?:^  //.*\n)*)^\s*((x2|x3|n)\({},\s*{},?([^\)]+)\);)",
        c_string, c_string
    ))
    .unwrap();
    let mut out = vec![];
    for caps in re.captures_iter(source) {
        out.push((
            unescape(caps.get(4).unwrap().as_str()),
            unescape(caps.get(5).unwrap().as_str()),
        ));
    }
    out
}

fn unescape(escaped: &str) -> String {
    let mut s: Vec<u8> = Vec::new();
    let mut chars = escaped.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => {
                let next = chars.next().unwrap();
                match next {
                    '\\' => s.push(b'\\'),
                    '"' => s.push(b'"'),
                    '?' => s.push(b'?'),
                    'n' => s.push(b'\n'),
                    'r' => s.push(b'\r'),
                    '0' => {
                        let mut octal = String::new();
                        octal.push(chars.next().unwrap());
                        octal.push(chars.next().unwrap());
                        s.push(u8::from_str_radix(&octal, 8).unwrap());
                    }
                    'x' => {
                        let mut hex = String::new();
                        hex.push(chars.next().unwrap());
                        hex.push(chars.next().unwrap());
                        s.push(u8::from_str_radix(&hex, 16).unwrap());
                    }
                    _ => unimplemented!("Unknown escaped character {next} in {escaped}"),
                }
            }
            _ => s.append(&mut c.to_string().into_bytes()),
        }
    }
    String::from_utf8_lossy(&s).to_string()
}

fn find_crate_dir() -> std::path::PathBuf {
    let home = std::env::var("CARGO_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::path::PathBuf::from(std::env::var("HOME").unwrap()).join(".cargo"));
    for entry in std::fs::read_dir(home.join("registry/src")).unwrap() {
        let p = entry.unwrap().path().join("fancy-regex-0.16.2");
        if p.exists() {
            return p;
        }
    }
    panic!("fancy-regex-0.16.2 sources not found in the cargo registry");
}

/// Lines of code to match syntect regexes against.
const CODE_LINES: &[&str] = &[
    "fn main() { let x = 42; }",
    "  // comment here",
    "<div class=\"a\">text</div>",
    "def foo(bar, baz=1):",
    "\"str \\\"esc\\\" end\" 'c'",
    "#include <stdio.h>",
    "SELECT * FROM t WHERE a = 'b';",
    "x = 0x1F + 3.14e-10 - 1_000",
    "@media screen { .a { color: #fff; } }",
    "$ echo \"${HOME}\" | grep -v foo",
];

/// Emitted lines per `oracle_cases_<i>` array (`moon fmt` expands them about
/// threefold; a top-level segment must stay below 16384 lines).
const CASE_LINES_PER_PART: usize = 2000;

fn main() {
    let root = std::path::PathBuf::from(std::env::args().nth(1).expect("repo root"));

    // Hand-written corpus and the Oniguruma suite.
    let mut cases: Vec<(String, String, Vec<String>)> = vec![];
    for (p, f, hs) in corpus() {
        cases.push((p.to_string(), f.to_string(), hs.iter().map(|s| s.to_string()).collect()));
    }
    let onig = std::fs::read_to_string(find_crate_dir().join("tests/oniguruma/test_utf8.c")).unwrap();
    let mut seen = BTreeSet::new();
    for (pattern, text) in oniguruma_tests(&onig) {
        if seen.insert((pattern.clone(), text.clone())) {
            cases.push((pattern, "om".to_string(), vec![text]));
        }
    }
    let mut out = String::new();
    out.push_str("// Generated by `oracle/src/bin/gen_fancy_regex_tests.rs` from the Rust\n");
    out.push_str("// `fancy-regex` crate (0.16.2). Do not edit.\n\n");
    // The cases are split into several top-level arrays: one array of all of
    // them is a text segment beyond the compiler's line limit
    // (`text_segment_excceed`).
    let mut parts: Vec<String> = vec![String::new()];
    let mut part_lines = 0;
    for (p, f, hs) in &cases {
        if part_lines >= CASE_LINES_PER_PART {
            parts.push(String::new());
            part_lines = 0;
        }
        let part = parts.last_mut().unwrap();
        match build(p, f) {
            Err(e) => {
                writeln!(part, "  ({}, {}, {}, []),", mbt_str(p), mbt_str(f), mbt_str(&e)).unwrap();
                part_lines += 1;
            }
            Ok(re) => {
                writeln!(part, "  ({}, {}, \"ok\", [", mbt_str(p), mbt_str(f)).unwrap();
                for h in hs {
                    writeln!(part, "    ({}, {}),", mbt_str(h), mbt_str(&describe(&re, h))).unwrap();
                }
                part.push_str("  ]),\n");
                part_lines += hs.len() + 2;
            }
        }
    }
    for (i, part) in parts.iter().enumerate() {
        writeln!(out, "///|\nlet oracle_cases_{i} : Array[(String, String, String, Array[(String, String)])] = [").unwrap();
        out.push_str(part);
        out.push_str("]\n\n");
    }
    out.push_str("///|\n/// (pattern, builder flags, [(haystack, description)]); the build error\n/// is in place of the haystacks when building fails.\n");
    out.push_str("let oracle_cases : Array[(String, String, String, Array[(String, String)])] = [\n");
    for i in 0..parts.len() {
        writeln!(out, "  ..oracle_cases_{i},").unwrap();
    }
    out.push_str("]\n");
    std::fs::write(root.join("regex/fancy/oracle_data_test.mbt"), out).unwrap();

    // Syntect regexes.
    let ss = two_face::syntax::extra_no_newlines();
    let builder = ss.into_builder();
    let mut regexes = BTreeSet::new();
    for syntax in builder.syntaxes() {
        for context in syntax.contexts.values() {
            for pattern in &context.patterns {
                if let syntect::parsing::syntax_definition::Pattern::Match(m) = pattern {
                    regexes.insert(m.regex.regex_str().to_string());
                }
            }
        }
    }
    let mut out = String::new();
    out.push_str("// Generated by `oracle/src/bin/gen_fancy_regex_tests.rs` from the Rust\n");
    out.push_str("// `fancy-regex` crate (0.16.2) and the regexes of syntect's syntaxes\n");
    out.push_str("// (two-face `extra_no_newlines`). Do not edit.\n\n");
    out.push_str("///|\n/// Every regex with its build result (\"ok\" or the error).\n");
    out.push_str("let syntect_regexes : Array[(String, String)] = [\n");
    let mut ok = vec![];
    for r in &regexes {
        let res = match build(r, "o") {
            Ok(re) => {
                ok.push((r.clone(), re));
                "ok".to_string()
            }
            Err(e) => e,
        };
        writeln!(out, "  ({}, {}),", mbt_str(r), mbt_str(&res)).unwrap();
    }
    out.push_str("]\n\n");
    out.push_str("///|\nlet syntect_lines : Array[String] = [\n");
    for l in CODE_LINES {
        writeln!(out, "  {},", mbt_str(l)).unwrap();
    }
    out.push_str("]\n\n");
    // Match a sample: every 8th compiled regex against all lines, with
    // `captures_from_pos(&line[..end], pos)` for `(pos, end)` in
    // `(0, len)`, `(mid, len)` and `(0, mid)` (`mid`: the middle char
    // boundary).
    out.push_str("///|\n/// (regex, [description per line])\n");
    out.push_str("let syntect_matches : Array[(String, Array[String])] = [\n");
    for (i, (r, re)) in ok.iter().enumerate() {
        if i % 8 != 0 {
            continue;
        }
        writeln!(out, "  ({}, [", mbt_str(r)).unwrap();
        for l in CODE_LINES {
            let mid = (0..=l.len() / 2).rev().find(|&i| l.is_char_boundary(i)).unwrap();
            let mut d = String::new();
            for (pos, end) in [(0, l.len()), (mid, l.len()), (0, mid)] {
                match re.captures_from_pos(&l[..end], pos) {
                    Ok(Some(caps)) => d.push_str(&describe_caps(&caps)),
                    Ok(None) => d.push_str("none"),
                    Err(e) => write!(d, "err:{e}").unwrap(),
                }
                d.push(' ');
            }
            writeln!(out, "    {},", mbt_str(&d)).unwrap();
        }
        out.push_str("  ]),\n");
    }
    out.push_str("]\n");
    std::fs::write(root.join("regex/fancy/syntect_data_test.mbt"), out).unwrap();
    eprintln!(
        "{} corpus cases, {} syntect regexes ({} ok)",
        cases.len(),
        regexes.len(),
        ok.len()
    );
}
