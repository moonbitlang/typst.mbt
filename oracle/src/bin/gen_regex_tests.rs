//! Emits `regex/oracle_wbtest.mbt`, a MoonBit test comparing the regex port
//! with the Rust `regex` crate on the cases in `oracle/regex_corpus.tsv`
//! (`pattern<TAB>haystack` per line; `\n` and `\t` are unescaped).
//!
//! Usage: `gen_regex_tests oracle/regex_corpus.tsv > regex/oracle_wbtest.mbt`

fn describe(pattern: &str, hay: &str) -> String {
    let re = match regex::Regex::new(pattern) {
        Ok(re) => re,
        Err(err) => return format!("error: {err}"),
    };
    let mut out = String::new();
    for caps in re.captures_iter(hay) {
        out.push('[');
        for (i, g) in caps.iter().enumerate() {
            if i > 0 {
                out.push(' ');
            }
            match g {
                Some(m) => out.push_str(&format!("{}..{}", m.start(), m.end())),
                None => out.push('-'),
            }
        }
        out.push(']');
    }
    out.push_str(" split=");
    let parts: Vec<String> = re.split(hay).map(|s| format!("{s:?}")).collect();
    out.push_str(&parts.join(","));
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
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{{{:x}}}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn main() {
    let src = std::fs::read_to_string(std::env::args().nth(1).unwrap()).unwrap();
    let mut cases = Vec::new();
    for line in src.lines() {
        if line.is_empty() {
            continue;
        }
        let (p, h) = line.split_once('\t').unwrap();
        let unesc = |s: &str| s.replace("\\n", "\n").replace("\\t", "\t");
        let (p, h) = (unesc(p), unesc(h));
        let d = describe(&p, &h);
        cases.push(format!("    ({}, {}, {}),", mbt_str(&p), mbt_str(&h), mbt_str(&d)));
    }
    println!("// Generated from the Rust `regex` crate (1.13). Do not edit.\n");
    println!("///|\nlet oracle_cases : Array[(String, String, String)] = [");
    for c in cases {
        println!("{c}");
    }
    println!("]\n");
    print!("{}", TEST);
}

const TEST: &str = r#"///|
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
"#;
