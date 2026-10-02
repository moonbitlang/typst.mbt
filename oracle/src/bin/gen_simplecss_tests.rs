//! Generates `simplecss/oracle_test.mbt`: runs the real `simplecss` 0.2.2
//! over a corpus of style sheets, declaration lists and selectors, and
//! prints MoonBit tests comparing the port's output (dumped with the helpers
//! of `simplecss/helpers_test.mbt`) against upstream's.
//!
//! Usage: `gen_simplecss_tests > simplecss/oracle_test.mbt && moon fmt`

use std::fmt::Write as _;

use simplecss::{
    AttributeOperator, DeclarationTokenizer, Element, Error, PseudoClass, Selector,
    SelectorToken, SelectorTokenizer, StyleSheet, TextPos,
};

/// Escape a string as a MoonBit string literal.
fn lit(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            '\r' => out.push_str("\\r"),
            '\'' | ' ' => out.push(c),
            c if c.escape_debug().count() == 1 => out.push(c),
            c => write!(out, "\\u{{{:X}}}", c as u32).unwrap(),
        }
    }
    out.push('"');
    out
}

fn spec(s: &Selector) -> String {
    let [a, b, c] = s.specificity();
    format!("{a},{b},{c}")
}

fn dump_sheet(sheet: &StyleSheet) -> String {
    let mut out = format!("{sheet}\n--\n");
    for rule in &sheet.rules {
        write!(out, "{}|{}|", rule.selector, spec(&rule.selector)).unwrap();
        for d in &rule.declarations {
            write!(out, "{}={}{};", d.name, d.value, if d.important { "!" } else { "" })
                .unwrap();
        }
        out.push('\n');
    }
    out
}

fn dump_decls(text: &str) -> String {
    let mut out = String::new();
    let mut t = DeclarationTokenizer::from(text);
    for _ in 0..100 {
        match t.next() {
            Some(d) => writeln!(
                out,
                "{}={}{}",
                d.name,
                d.value,
                if d.important { " !important" } else { "" }
            )
            .unwrap(),
            None => break,
        }
    }
    out
}

fn fmt_op(op: &AttributeOperator) -> String {
    match op {
        AttributeOperator::Exists => String::new(),
        AttributeOperator::Matches(v) => format!("={v}"),
        AttributeOperator::Contains(v) => format!("~={v}"),
        AttributeOperator::StartsWith(v) => format!("|={v}"),
    }
}

fn fmt_token(t: &SelectorToken) -> String {
    match t {
        SelectorToken::UniversalSelector => "*".into(),
        SelectorToken::TypeSelector(s) => format!("type:{s}"),
        SelectorToken::ClassSelector(s) => format!("class:{s}"),
        SelectorToken::IdSelector(s) => format!("id:{s}"),
        SelectorToken::AttributeSelector(n, op) => format!("attr:[{n}{}]", fmt_op(op)),
        SelectorToken::PseudoClass(s) => format!("pseudo:{s}"),
        SelectorToken::LangPseudoClass(s) => format!("lang:{s}"),
        SelectorToken::DescendantCombinator => "desc".into(),
        SelectorToken::ChildCombinator => "child".into(),
        SelectorToken::AdjacentCombinator => "adj".into(),
    }
}

fn dump_sel_tokens(text: &str) -> String {
    let mut out = String::new();
    let mut t = SelectorTokenizer::from(text);
    for _ in 0..100 {
        match t.next() {
            Some(Ok(tok)) => writeln!(out, "{}", fmt_token(&tok)).unwrap(),
            Some(Err(e)) => writeln!(out, "err:{e}").unwrap(),
            None => break,
        }
    }
    out
}

fn dump_selector(text: &str) -> String {
    match Selector::parse(text) {
        Some(s) => format!("{s}|{}", spec(&s)),
        None => "None".into(),
    }
}

// A tiny element tree: (parent, name, attributes), in document order.
type NodeSpec = (Option<usize>, &'static str, &'static [(&'static str, &'static str)]);

const TREE: &[NodeSpec] = &[
    (None, "svg", &[("id", "root")]),
    (Some(0), "g", &[("id", "g1"), ("class", "a b")]),
    (Some(1), "rect", &[("id", "r1"), ("class", "a"), ("lang", "en")]),
    (Some(1), "circle", &[("id", "c1"), ("fill", "red")]),
    (Some(1), "rect", &[("id", "r2"), ("lang", "en-US"), ("hover", "")]),
    (Some(0), "g", &[("id", "g2")]),
    (Some(5), "text", &[("id", "t1"), ("class", "b  c")]),
    (Some(6), "tspan", &[("id", "s1")]),
    (Some(6), "tspan", &[("id", "s2"), ("class", "a")]),
    (Some(6), "g", &[("id", "g3"), ("class", "a")]),
    (Some(9), "rect", &[("id", "r4"), ("fill", "blue")]),
    (Some(0), "rect", &[("id", "r3"), ("lang", "fr")]),
];

#[derive(Clone, Copy)]
struct Node(usize);

impl Element for Node {
    fn parent_element(&self) -> Option<Self> {
        TREE[self.0].0.map(Node)
    }

    fn prev_sibling_element(&self) -> Option<Self> {
        let parent = TREE[self.0].0?;
        (0..self.0).rev().find(|&i| TREE[i].0 == Some(parent)).map(Node)
    }

    fn has_local_name(&self, name: &str) -> bool {
        TREE[self.0].1 == name
    }

    fn attribute_matches(&self, local_name: &str, operator: AttributeOperator<'_>) -> bool {
        match TREE[self.0].2.iter().find(|(k, _)| *k == local_name) {
            Some((_, v)) => operator.matches(v),
            None => false,
        }
    }

    fn pseudo_class_matches(&self, class: PseudoClass<'_>) -> bool {
        match class {
            PseudoClass::FirstChild => self.prev_sibling_element().is_none(),
            PseudoClass::Lang(l) => {
                self.attribute_matches("lang", AttributeOperator::StartsWith(l))
            }
            PseudoClass::Hover => self.attribute_matches("hover", AttributeOperator::Exists),
            _ => false,
        }
    }
}

fn dump_match(text: &str) -> String {
    match Selector::parse(text) {
        Some(s) => {
            let ids: Vec<&str> = (0..TREE.len())
                .filter(|&i| s.matches(&Node(i)))
                .map(|i| TREE[i].2[0].1)
                .collect();
            ids.join(",")
        }
        None => "None".into(),
    }
}

fn op_code(op: &AttributeOperator) -> String {
    match op {
        AttributeOperator::Exists => "@simplecss.Exists".into(),
        AttributeOperator::Matches(v) => format!("@simplecss.Matches({})", lit(v)),
        AttributeOperator::Contains(v) => format!("@simplecss.Contains({})", lit(v)),
        AttributeOperator::StartsWith(v) => format!("@simplecss.StartsWith({})", lit(v)),
    }
}

fn pos_code(p: TextPos) -> String {
    format!("@simplecss.TextPos::new({}, {})", p.row, p.col)
}

fn err_code(e: &Error) -> String {
    match *e {
        Error::UnexpectedEndOfStream => "@simplecss.UnexpectedEndOfStream".into(),
        Error::InvalidIdent(p) => format!("@simplecss.InvalidIdent({})", pos_code(p)),
        Error::InvalidComment(p) => format!("@simplecss.InvalidComment({})", pos_code(p)),
        Error::InvalidValue(p) => format!("@simplecss.InvalidValue({})", pos_code(p)),
        Error::InvalidByte { expected, actual, pos } => format!(
            "@simplecss.InvalidByte(expected=b'\\x{expected:02X}', actual=b'\\x{actual:02X}', pos={})",
            pos_code(pos)
        ),
        Error::SelectorMissing => "@simplecss.SelectorMissing".into(),
        Error::UnexpectedSelector => "@simplecss.UnexpectedSelector".into(),
        Error::UnexpectedCombinator => "@simplecss.UnexpectedCombinator".into(),
        Error::InvalidAttributeSelector => "@simplecss.InvalidAttributeSelector".into(),
        Error::InvalidLanguagePseudoClass => "@simplecss.InvalidLanguagePseudoClass".into(),
    }
}

fn main() {
    let many_classes = format!("{} {{ x: y }} a {{ z: w }}", ".a".repeat(260));
    let many_ids = format!("{} {{ x: y }}", "#i".repeat(300));
    let many_types = format!("{} {{ x: y }}", vec!["a"; 270].join(" > "));
    let sheets: Vec<Vec<&str>> = vec![
        // tests/stylesheet.rs
        vec![""],
        vec!["a {}"],
        vec!["a { color:red }"],
        vec!["/**/"],
        vec!["a { color:red } /**/"],
        vec!["a, b { color:red }"],
        vec!["a, { color:red }"],
        vec!["a,, { color:red }"],
        vec!["a,,b { color:red }"],
        vec![",a { color:red }"],
        vec!["@import \"subs.css\";\na { color:red }"],
        vec!["@media screen {\n    p:before { content: 'Hello'; }\n}\na { color:red }"],
        vec!["a > { color:red }"],
        vec!["p { color:green; color }"],
        vec!["p { color; color:green }"],
        vec!["p { color:green; color: }"],
        vec!["p { color:green; color:; color:red; }"],
        vec!["p { color:green; color{;color:maroon} }"],
        vec!["p { color{;color:maroon} color:green; }"],
        vec!["        h1 { color: green }\n        h2 & h3 { color: red }\n        h4 { color: black }\n    "],
        vec![":le>*"],
        // Extra cases.
        vec!["a { color:red } b { color: blue !important; fill: #fff }"],
        vec!["#id { a: 1 } .cls { b: 2 } * { c: 3 } div { d: 4 } div.cls { e: 5 } div#id.cls:first-child { f: 6 }"],
        vec!["p { x: 1 } p { y: 2 } * { z: 0 } p { w: 3 } .q { v: 4 } p { u: 5 }"],
        vec!["a > b + c d { color: red }"],
        vec!["[x] [y=z] [a~='b c'] [l|=en] { q: 1 }"],
        vec![":lang(en) { a: b } :lang( fr ) { c: d } :lang() { e: f } :hover:focus:active:link:visited { g: h } :unknown { i: j } k { l: m }"],
        vec!["a { color: red; } /* unclosed"],
        vec!["/* unclosed"],
        vec!["a { width: 5px; height: -1.5em; margin: +.5% 10%; content: 'x\\'y' \"a\" }"],
        vec!["a { font: 12px/1.5 serif; b: c }"],
        vec!["@media screen { a { b: c } } d { e: f }"],
        vec!["@font-face { font-family: x; } @charset \"utf-8\"; a{b:c}"],
        vec!["@ a { b: c } d { e: f }"],
        vec!["@media"],
        vec!["@x y"],
        vec!["a { b: c"],
        vec!["a { b: url(x.png) no-repeat; c: rgb(1, 2, 3) }"],
        vec!["é { a: b } ☃ { c: d } a { ☃: é }"],
        vec!["a\n{\n  b : c ;\n}\n"],
        vec!["a{b:c}}d{e:f}"],
        vec!["a b { c: d !important; e: f ! important; g: h !imp; i: j !/**/important }"],
        vec!["*{a:b}"],
        vec!["> a {b:c} d {e:f}"],
        vec!["a ,b , c{d:e}"],
        vec!["a /* x */ b { c: d }"],
        vec!["a/**/b { c: d }"],
        vec!["a / b { c: d } e { f: g }"],
        vec!["[a=] {b:c} x {y:z}"],
        vec!["[a!=b] {c:d} x {y:z}"],
        vec!["[a~b] {c:d} x {y:z}"],
        vec!["[=b] {c:d} x {y:z}"],
        vec![".{a:b} x {y:z}"],
        vec!["#1{a:b} x {y:z}"],
        vec!["a..b{c:d} x {y:z}"],
        vec!["a { -webkit-x: 1; --custom: 2; _y: 3; -: 4 }"],
        vec!["a { color: #12345g; b: #-x; c: # }"],
        vec!["a { b: 'unterminated }"],
        vec!["a { b: c; ; d: e }"],
        vec!["a { : c; d: e }"],
        vec!["a { b: \u{3000}; c: d }"],
        vec!["a { b: c\u{3000} }"],
        vec!["a { b: \u{00A0}c }"],
        vec!["a { b: \u{2003}c\u{2003} d }"],
        vec!["html|a { b: c }"],
        vec!["a:first-child > b + c ~ d { e: f } g { h: i }"],
        vec!["a, > b, c { d: e }"],
        vec!["a,{b:c}"],
        vec!["a\n,\nb\n{\nc\n:\nd\n}"],
        vec!["a { b: c } /**/ /* x */ d { e: f }"],
        vec!["a { b: fn(1, 2) 3 }"],
        vec!["a { b: fn(1, 2 }"],
        vec!["a { b: c !important !important }"],
        vec!["a { b: c; } }"],
        vec!["}}} a { b: c }"],
        vec!["{ a: b } c { d: e }"],
        vec!["a { b { c: d } e: f }"],
        vec!["\t\r\n\x0Ca\x0C{\x0Cb\x0C:\x0Cc\x0C}"],
        vec!["a{b:1.2.3}"],
        vec!["a{b:--}"],
        vec!["a{b:.}"],
        vec!["a{b:1e3}"],
        vec!["a{b:\"x\\\"y\"}"],
        vec!["a{b:c,d , e}"],
        vec!["a.b.c#d[e][f=g]:hover { h: i } a b c d e { f: g } #x #y { z: w }"],
        vec![&many_classes],
        vec![&many_ids],
        vec![&many_types],
        // parse_more over several texts.
        vec!["b { x: 1 }", "a { y: 2 }", "#i { z: 3 }", ".c { w: 4 }"],
        vec!["* {a:b}", "c {d:e}", "* {f:g}", "c {h:i}"],
        vec!["/* x", "a { b: c }"],
        vec!["a { b: c", "d { e: f }"],
    ];

    let decls: &[&str] = &[
        // tests/declaration_tokenizer.rs
        "",
        " ",
        "/**/",
        "color:red",
        "color:red;",
        "color:red ",
        " color: red; ",
        "  color  :  red  ; ",
        "  color:red;;;;color:red; ",
        "background: url(\"img.png\");",
        "background: url(\"{}\");",
        "color: red ! important",
        "color: red !important",
        "color: red!important",
        "color: red !/**/important",
        "border: 1em solid blue",
        "background: navy url(support/diamond.png) -2em -2em no-repeat",
        "/**/color:red",
        "/* *\\/*/color: red;",
        "/**/color/**/:/**/red/**/;/**/",
        "\ncolor\n:\nred\n;\n",
        "{color:red}",
        "(color:red)",
        "[color:red]",
        "color:",
        "value:\"text\"",
        "value:'text'",
        "color:#fff",
        "color:0.5",
        "color:.5",
        "color:#FFF",
        "content: counter(chapno, upper-roman) \". \"",
        "font-family:'Noto Serif','DejaVu Serif',serif",
        "*zoom:1;",
        "@unsupported { splines: reticulating } color: green",
        "/*\\*/*/color: red;",
        // Extra cases.
        "a:b; c",
        "a:b;c:d!important;e:'f'",
        "color:red; /* unclosed",
        "a: 1 2 3",
        "a:b}c:d",
        "x: y; z",
        "a:b;;",
        "*a:b",
        "**a:b",
        "a:-",
        "a:+5",
        "a:#",
        "a:#-",
        "a:'x",
        "a:fn(x",
        "a: url( x ) b",
        "a:b !important c",
        "a:b !importantc",
        "a:b !impo",
        ":b",
        "é:b",
        "a:é",
        "a:☃",
        "a: \u{3000}x",
        "a: x\u{3000}",
        "fill:red;stroke:blue;stroke-width:2px",
        "fill: rgb(10%, 20%, 30%); opacity: .5",
        "font-family: \"Times New Roman\", serif; font-size: 12pt",
        "marker-start: url(#m1)",
        "a:b c:d",
        "a:b/c",
        "a:1px/2px",
        "a:b\n;c:d",
        "a:b /* c */ d",
        "a:b /* c",
        "a:b;/**/",
        "-a:b",
        "--a:b",
        "-1:b",
        "a:-1",
        "a:1%",
        "a:1.%",
        "a:+.5e",
        "a:inherit !important;b:c",
    ];

    let sel_tokens: &[&str] = &[
        // tests/selector_tokenizer.rs
        "*", "div", "#div", ".div", "[id]", "[id=test]", "[id~=test]", "[id|=test]",
        "[id='test']", "[id=\"test\"]", "[id='te\\'st']", "[id=\"te\\\"st\"]",
        "div:first-child", ":first-child", "div p", "div p a", "div>p", "div >p", "div> p",
        "div > p", "div .p", "div *", "div #p", "div [id]", "div :link", "div+p", "div +p",
        "div+ p", "div + p", "div {", "div,", "div{", "div ,", "div.test", "div.test.warn",
        "div#id", "*[id]", "*.test", "*#id", "div * p", "div[id=test][color=red]",
        "a.external:visited", ":lang(en)", "a\nb", ".warn :first-child", "/* comment */a",
        "a /**/ b", "a /**/b", "a/**/ b", "a/**/ /**/b", "a /**/ /**/ b", "a /**//**/ b",
        // Extra cases.
        "", " ", "a >", "> a", "a > > b", "a + + b", "a b > c", "a,b", "a{", ":foo",
        ":lang()", ":lang( )", ":lang( en-US )", ":lang(en", "[x", "[x=", "[x!y]", "[x~y]",
        "[x|y]", "[x='y'", "[x='y", "[x=y z]", "[]", "*.a", "a*", "**", "a.b#c[d]:hover",
        "/* c */ a", "a /* c */", "a /", "a /x", "a  /* c */ > b", "a /* c", "a/", "a/x",
        "é", "a é", "☃.☃", "a\n\n  /* x", "a ~ b", "a\t>\tb", "a\r\nb", ".-a", ".-",
        ".-1", "#-", "a:-b", "a::before", ":", ".", "#", "[", "[a~é]", "[a|é]", "a\n[b~=]",
        "a b c d e f", "  a", "a  ", "a , b", "a{b}", "a > b, c",
    ];

    let selectors: &[&str] = &[
        "*", "li", "ul li", "ul ol + li", "h1 + *[rel=up]", "ul ol li.red", "li.red.level",
        "#x34y", "a > b", "", " ", "a >", "> a", "a > > b", "a + + b", "a b > c", "a,b",
        "a{", ":foo", ":lang()", ":lang(en)", "[x", "[x=", "[x!y]", "*.a", "a*",
        "a.b#c[d]:hover", "/* c */ a", "a /* c */", "a /", "a /x", "a  /* c */ > b", "é",
        "a é", "☃.☃", ".a.b.c", "#a#b", "[id=x]", "[id]", "a [id=x] .b", "*:first-child",
        ":first-child:hover", "a:link:visited:active:focus", "a:lang(de):lang(fr)",
        ":lang(en) > a", "a + b > c d", "a /* x */ + b", "#a > .b + c [d|=e]",
        "a ~ b", "a::before", "a > b,", ".x:unknown", "[a~='b c']", "[a='']",
    ];

    let match_selectors: &[&str] = &[
        "*", "rect", "g rect", "g > rect", "svg > rect", "svg rect", "rect + circle",
        "circle + rect", "rect + rect", ".a", ".b", ".c", ".a.b", "g.a", "#r1", "rect#r1",
        "[fill]", "[fill=red]", "[class~=c]", "[class~='']", "[lang|=en]", "[lang=en]",
        ":first-child", "rect:first-child", ":lang(en)", ":lang(en-US)", ":lang(fr)",
        ":hover", ":focus", ":link", "svg g text tspan", "svg > g > text > tspan + tspan.a",
        "g * tspan", "* *", "* > *", "g > * > tspan", "text tspan:first-child", "svg tspan",
        "svg > tspan", "g + g", "g + g + rect", "g + rect", "* + *", "g rect + rect",
        "svg > g rect", "g g rect", "g > g > rect", ".a .a", ".a > .a", ".a + .a",
        "[id] [id] [id] [id]", "text > g rect[fill=blue]", "#g2 rect", "#g1 > *:hover",
        "tspan + g", "tspan + g > rect", "svg", "svg:first-child", "#root rect + g",
        "nonexistent", "g nonexistent", "[class|=a]", "[class=a]",
    ];

    let attr_ops: Vec<(AttributeOperator, &str)> = vec![
        (AttributeOperator::Exists, ""),
        (AttributeOperator::Exists, "x"),
        (AttributeOperator::Matches("a"), "a"),
        (AttributeOperator::Matches("a"), "ab"),
        (AttributeOperator::Matches(""), ""),
        (AttributeOperator::Contains("b"), "a b c"),
        (AttributeOperator::Contains("b"), "a  b"),
        (AttributeOperator::Contains("b"), "abc"),
        (AttributeOperator::Contains(""), "a  b"),
        (AttributeOperator::Contains(""), "a b"),
        (AttributeOperator::Contains(""), ""),
        (AttributeOperator::Contains("a b"), "a b"),
        (AttributeOperator::Contains("b"), "a\tb"),
        (AttributeOperator::StartsWith("en"), "en"),
        (AttributeOperator::StartsWith("en"), "en-US"),
        (AttributeOperator::StartsWith("en"), "enx"),
        (AttributeOperator::StartsWith("en"), "en-"),
        (AttributeOperator::StartsWith("en"), "e"),
        (AttributeOperator::StartsWith("en"), "fr-en"),
        (AttributeOperator::StartsWith(""), "-x"),
        (AttributeOperator::StartsWith(""), "x"),
        (AttributeOperator::StartsWith(""), ""),
        (AttributeOperator::StartsWith("é"), "é-x"),
        (AttributeOperator::StartsWith("é"), "éx"),
        (AttributeOperator::StartsWith("☃"), "☃-"),
    ];

    let errors: Vec<Error> = vec![
        Error::UnexpectedEndOfStream,
        Error::InvalidIdent(TextPos::new(1, 2)),
        Error::InvalidComment(TextPos::new(3, 4)),
        Error::InvalidValue(TextPos::new(10, 20)),
        Error::InvalidByte { expected: b'=', actual: b']', pos: TextPos::new(1, 5) },
        Error::InvalidByte { expected: b')', actual: 0xC3, pos: TextPos::new(2, 1) },
        Error::InvalidByte { expected: b'*', actual: 0x80, pos: TextPos::new(2, 1) },
        Error::SelectorMissing,
        Error::UnexpectedSelector,
        Error::UnexpectedCombinator,
        Error::InvalidAttributeSelector,
        Error::InvalidLanguagePseudoClass,
    ];

    let mut out = String::new();
    out.push_str(
        "// Generated by oracle/src/bin/gen_simplecss_tests.rs from the real\n\
         // `simplecss` 0.2.2 crate. Do not edit.\n\n",
    );

    // The element tree.
    out.push_str("///|\nlet tree_spec : Array[(Int, String, Array[(String, String)])] = [\n");
    for (parent, name, attrs) in TREE {
        let attrs: Vec<String> =
            attrs.iter().map(|(k, v)| format!("({}, {})", lit(k), lit(v))).collect();
        writeln!(
            out,
            "  ({}, {}, [{}]),",
            parent.map(|p| p as i64).unwrap_or(-1),
            lit(name),
            attrs.join(", ")
        )
        .unwrap();
    }
    out.push_str("]\n\n");

    out.push_str("///|\ntest \"stylesheet\" {\n");
    for texts in &sheets {
        let mut sheet = StyleSheet::new();
        for t in texts {
            sheet.parse_more(t);
        }
        let texts: Vec<String> = texts.iter().map(|t| lit(t)).collect();
        writeln!(out, "  check_sheet([{}], {})", texts.join(", "), lit(&dump_sheet(&sheet)))
            .unwrap();
    }
    out.push_str("}\n\n");

    out.push_str("///|\ntest \"declaration_tokenizer\" {\n");
    for t in decls {
        writeln!(out, "  check_decls({}, {})", lit(t), lit(&dump_decls(t))).unwrap();
    }
    out.push_str("}\n\n");

    out.push_str("///|\ntest \"selector_tokenizer\" {\n");
    for t in sel_tokens {
        writeln!(out, "  check_sel_tokens({}, {})", lit(t), lit(&dump_sel_tokens(t))).unwrap();
    }
    out.push_str("}\n\n");

    out.push_str("///|\ntest \"selector_parse\" {\n");
    for t in selectors {
        writeln!(out, "  check_selector({}, {})", lit(t), lit(&dump_selector(t))).unwrap();
    }
    out.push_str("}\n\n");

    out.push_str("///|\ntest \"selector_matches\" {\n");
    for t in match_selectors {
        writeln!(out, "  check_match({}, {})", lit(t), lit(&dump_match(t))).unwrap();
    }
    out.push_str("}\n\n");

    out.push_str("///|\ntest \"attribute_operator_matches\" {\n");
    for (op, v) in &attr_ops {
        writeln!(out, "  check_attr_op({}, {}, {})", op_code(op), lit(v), op.matches(v)).unwrap();
    }
    out.push_str("}\n\n");

    out.push_str("///|\ntest \"error_display\" {\n");
    for e in &errors {
        writeln!(out, "  check_error({}, {})", err_code(e), lit(&e.to_string())).unwrap();
    }
    for p in [
        PseudoClass::FirstChild,
        PseudoClass::Link,
        PseudoClass::Visited,
        PseudoClass::Hover,
        PseudoClass::Active,
        PseudoClass::Focus,
        PseudoClass::Lang("en-US"),
    ] {
        let code = match p {
            PseudoClass::Lang(l) => format!("@simplecss.Lang({})", lit(l)),
            _ => format!("@simplecss.{:?}", p),
        };
        writeln!(out, "  check_display({}, {})", code, lit(&p.to_string())).unwrap();
    }
    writeln!(out, "  check_display({}, {})", pos_code(TextPos::new(7, 9)), lit(&TextPos::new(7, 9).to_string())).unwrap();
    out.push_str("}\n");

    print!("{out}");
}
