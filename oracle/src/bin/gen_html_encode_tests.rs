//! Generates `html/encode_gen_test.mbt`: hand-built HTML DOMs encoded by
//! upstream's `typst_html` encoder (pretty and non-pretty), as MoonBit tests
//! that build the same DOMs and compare the exact output or error.
//!
//! Usage: `gen_html_encode_tests > html/encode_gen_test.mbt && moon fmt`

use std::fmt::Write as _;

use comemo::Track;
use ecow::EcoString;
use typst_html::{
    HtmlAttr, HtmlElement, HtmlFormatOptions, HtmlIntrospector, HtmlNode, HtmlOptions,
    HtmlTag, attr, tag,
};
use typst_library::format::{Complete, SpannedValue};
use typst_library::model::LateLinkResolver;
use typst_syntax::Span;

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

/// MoonBit code building the same element with the helpers of
/// `html/encode_test.mbt`.
fn code(elem: &HtmlElement) -> String {
    let attrs: Vec<_> = elem
        .attrs
        .0
        .iter()
        .map(|(k, v)| format!("({}, {})", lit(&k.resolve()), lit(v)))
        .collect();
    let children: Vec<_> = elem
        .children
        .iter()
        .map(|c| match c {
            HtmlNode::Text(t, _) => format!("txt({})", lit(t)),
            HtmlNode::Element(e) => code(e),
            _ => unreachable!(),
        })
        .collect();
    let mut out = format!("el({}", lit(&elem.tag.resolve()));
    if !attrs.is_empty() {
        write!(out, ", attrs=[{}]", attrs.join(", ")).unwrap();
    }
    if !children.is_empty() {
        write!(out, ", children=[{}]", children.join(", ")).unwrap();
    }
    if elem.pre_span {
        out.push_str(", pre_span=true");
    }
    out.push(')');
    out
}

/// Encodes like `typst_html::html`, rendering errors as text.
fn encode(root: &HtmlElement, pretty: bool) -> String {
    let introspector = HtmlIntrospector::new(&[]);
    let resolver = LateLinkResolver::new(None, &introspector);
    let options = HtmlOptions::<Complete> {
        format: HtmlFormatOptions { pretty: SpannedValue::detached(pretty) },
    };
    match typst_html::html_in_bundle(root, &options, resolver.track()) {
        Ok(s) => s,
        Err(errors) => {
            let mut out = String::new();
            for (i, e) in errors.iter().enumerate() {
                if i > 0 {
                    out.push('\n');
                }
                write!(out, "error: {}", e.message).unwrap();
                for h in &e.hints {
                    write!(out, "\nhint: {}", h.v).unwrap();
                }
            }
            out
        }
    }
}

fn t(s: &str) -> HtmlNode {
    HtmlNode::text(s, Span::detached())
}

fn e(tag: HtmlTag, children: Vec<HtmlNode>) -> HtmlElement {
    HtmlElement::new(tag).with_children(children.into_iter().collect())
}

fn n(elem: HtmlElement) -> HtmlNode {
    elem.into()
}

fn a(name: &str) -> HtmlAttr {
    HtmlAttr::intern(name).unwrap()
}

fn custom(name: &str) -> HtmlTag {
    HtmlTag::intern(name).unwrap()
}

fn doc(body: Vec<HtmlNode>) -> HtmlElement {
    e(
        tag::html,
        vec![
            n(e(
                tag::head,
                vec![
                    n(HtmlElement::new(tag::meta).with_attr(attr::charset, "utf-8")),
                    n(HtmlElement::new(tag::meta)
                        .with_attr(attr::name, "viewport")
                        .with_attr(attr::content, "width=device-width, initial-scale=1")),
                    n(e(tag::title, vec![t("A & <B>")])),
                ],
            )),
            n(e(tag::body, body)),
        ],
    )
    .with_attr(attr::lang, "en")
}

fn cases() -> Vec<(&'static str, HtmlElement)> {
    let mut pre_span = e(tag::span, vec![t(" A\tB  ")]);
    pre_span.pre_span = true;
    vec![
        ("empty", HtmlElement::new(tag::html)),
        ("document", doc(vec![n(e(tag::p, vec![t("Hello")]))])),
        (
            "attrs",
            e(tag::div, vec![t("x")])
                .with_attr(attr::id, "a&b")
                .with_attr(attr::title, "say \"hi\" <there> 'you'")
                .with_attr(attr::hidden, "")
                .with_attr(a("data-x"), "\u{a0}é\u{1F600}"),
        ),
        ("text-escape", e(tag::p, vec![t("a & b < c > d \"e\" 'f' é\u{1F600}\u{a0}")])),
        ("text-tab-newline", e(tag::p, vec![t("a\tb\nc")])),
        ("text-cr", e(tag::p, vec![t("a\rb")])),
        ("text-control", e(tag::p, vec![t("a\u{1}b")])),
        ("text-nonchar", e(tag::p, vec![t("a\u{fdd0}b")])),
        ("text-nonchar-ffff", e(tag::p, vec![t("a\u{1FFFF}b")])),
        ("text-c1-control", e(tag::p, vec![t("a\u{85}b")])),
        ("attr-control", HtmlElement::new(tag::div).with_attr(attr::title, "a\u{7}b")),
        ("attr-tab-newline", HtmlElement::new(tag::div).with_attr(attr::title, "a\tb\nc\rd")),
        ("pre-span", e(tag::p, vec![t("A"), n(pre_span), t("B")])),
        ("void", e(tag::p, vec![t("A"), n(HtmlElement::new(tag::br)), t("B")])),
        ("void-img", HtmlElement::new(tag::img).with_attr(attr::src, "a.png")),
        ("void-children", e(tag::img, vec![t("Hello")])),
        ("void-children-element", e(tag::br, vec![n(HtmlElement::new(tag::span))])),
        (
            "foreign-self-closing",
            e(
                tag::mathml::math,
                vec![n(HtmlElement::new(tag::mathml::mspace).with_attr(attr::width, "1em"))],
            ),
        ),
        ("foreign-self-closing-children", e(tag::mathml::mprescripts, vec![t("x")])),
        ("pre-newline", e(tag::pre, vec![t("\nA  B")])),
        ("pre-cr", e(tag::pre, vec![t("\r\nA")])),
        ("pre-no-newline", e(tag::pre, vec![t("A\n")])),
        ("pre-element-first", e(tag::pre, vec![n(e(tag::span, vec![t("\nA")]))])),
        ("textarea-newline", e(tag::textarea, vec![t("\nA  B <&>")])),
        ("textarea-closing", e(tag::textarea, vec![t("</textarea>")])),
        ("title-escapable", e(tag::title, vec![t("A "), t("& <B>")])),
        ("title-element", e(tag::title, vec![n(HtmlElement::new(tag::span))])),
        ("title-nonchar", e(tag::title, vec![t("\u{fdd0}")])),
        ("script", e(tag::script, vec![t("let x = 1;\nlet y = x < 2 && true;")])),
        ("script-crlf", e(tag::script, vec![t("a\r\nb\r\n\nc\n")])),
        ("script-backtick", e(tag::script, vec![t("let x = `a\n  b`;")])),
        (
            "script-module",
            e(tag::script, vec![t("let x = 1;\nlet y = 2;")]).with_attr(attr::r#type, "module"),
        ),
        (
            "script-js-type",
            e(tag::script, vec![t("let x = 1;\nlet y = 2;")])
                .with_attr(attr::r#type, "text/javascript"),
        ),
        ("script-empty", HtmlElement::new(tag::script).with_attr(attr::src, "a.js")),
        ("script-empty-text", e(tag::script, vec![t("")])),
        ("style", e(tag::style, vec![t("p {\n  color: red;\n}")])),
        ("style-closing", e(tag::style, vec![t("a </style> b")])),
        ("style-closing-upper", e(tag::style, vec![t("a </STYLE\tb")])),
        ("style-closing-slash", e(tag::style, vec![t("a </style/")])),
        ("style-closing-end", e(tag::style, vec![t("a </style")])),
        ("style-closing-longer", e(tag::style, vec![t("a </styles> </sty")])),
        ("style-closing-non-ascii", e(tag::style, vec![t("a </styl\u{e9}> </é")])),
        ("script-closing-split", e(tag::script, vec![t("a </scr"), t("ipt>")])),
        ("style-element", e(tag::style, vec![t("a"), n(HtmlElement::new(tag::span))])),
        ("style-nonchar", e(tag::style, vec![t("a"), t("\u{fdd0}")])),
        ("style-control", e(tag::style, vec![t("a\u{1}")])),
        ("style-amp", e(tag::style, vec![t("a & b < c")])),
        (
            "mixed-flow",
            e(
                tag::body,
                vec![
                    n(e(tag::div, vec![t("A"), n(e(tag::div, vec![t("B")]))])),
                    n(e(tag::div, vec![n(e(tag::div, vec![t("A")])), t("B")])),
                ],
            ),
        ),
        (
            "inline",
            e(
                tag::div,
                vec![n(e(tag::p, vec![t("A "), n(e(tag::strong, vec![t("B")])), t(" C")]))],
            ),
        ),
        (
            "inline-only",
            e(tag::div, vec![t("A "), n(e(tag::span, vec![t("B")]))]),
        ),
        (
            "list",
            e(
                tag::ul,
                vec![
                    n(e(tag::li, vec![t("A")])),
                    n(e(tag::li, vec![n(e(tag::p, vec![t("B")])), n(e(tag::ol, vec![n(e(tag::li, vec![t("C")]))]))])),
                ],
            ),
        ),
        (
            "table",
            e(
                tag::table,
                vec![
                    n(e(tag::thead, vec![n(e(tag::tr, vec![n(e(tag::th, vec![t("A")]))]))])),
                    n(e(
                        tag::tbody,
                        vec![n(e(
                            tag::tr,
                            vec![n(e(tag::td, vec![t("B")])), n(e(tag::td, vec![]))],
                        ))],
                    )),
                ],
            ),
        ),
        (
            "pre-pretty",
            e(tag::div, vec![n(e(tag::pre, vec![t("A\n  B")])), n(e(tag::pre, vec![n(e(tag::div, vec![t("C")]))]))]),
        ),
        (
            "head-meta",
            e(
                tag::head,
                vec![
                    n(HtmlElement::new(tag::link).with_attr(attr::rel, "stylesheet")),
                    n(e(tag::style, vec![t("p { color: red; }\n\n  a {}")])),
                    n(e(tag::script, vec![t("x()")])),
                    n(e(tag::noscript, vec![t("no")])),
                ],
            ),
        ),
        (
            "script-in-body",
            e(tag::body, vec![n(e(tag::p, vec![t("A")])), n(e(tag::script, vec![t("a\nb")]))]),
        ),
        (
            "math",
            e(
                tag::p,
                vec![
                    t("A "),
                    n(e(tag::mathml::math, vec![n(e(tag::mathml::mi, vec![t("x")]))])),
                    n(e(
                        tag::mathml::math,
                        vec![n(e(
                            tag::mathml::mrow,
                            vec![
                                n(e(tag::mathml::mi, vec![t("x")])),
                                n(e(tag::mathml::mo, vec![t("+")])),
                                n(e(tag::mathml::mfrac, vec![n(e(tag::mathml::mn, vec![t("1")])), n(e(tag::mathml::mn, vec![t("2")]))])),
                            ],
                        ))],
                    )
                    .with_attr(attr::mathml::display, "block")),
                ],
            ),
        ),
        (
            "math-in-div",
            e(
                tag::div,
                vec![
                    n(e(tag::mathml::math, vec![n(e(tag::mathml::mi, vec![t("x")]))])),
                    n(e(tag::mathml::math, vec![n(e(tag::mathml::mi, vec![t("y")]))])
                        .with_attr(attr::mathml::display, "block")),
                ],
            ),
        ),
        (
            "custom-elements",
            e(
                tag::div,
                vec![
                    n(e(custom("my-element"), vec![n(e(tag::div, vec![t("A")]))])),
                    n(e(tag::details, vec![n(e(tag::summary, vec![t("S")])), t("B")])),
                    n(e(tag::figure, vec![n(HtmlElement::new(tag::img)), n(e(tag::figcaption, vec![t("C")]))])),
                ],
            ),
        ),
        (
            "nested-deep",
            e(
                tag::section,
                vec![n(e(
                    tag::article,
                    vec![
                        n(e(tag::h2, vec![t("T")])),
                        n(e(tag::blockquote, vec![n(e(tag::p, vec![t("Q")]))])),
                        n(e(tag::hr, vec![])),
                    ],
                ))],
            ),
        ),
        (
            "empty-text-nodes",
            e(tag::div, vec![t(""), n(e(tag::div, vec![])), t("")]),
        ),
        (
            "textarea-in-div",
            e(tag::div, vec![n(e(tag::textarea, vec![t("A  B")])), n(e(tag::p, vec![t("C")]))]),
        ),
    ]
}

fn main() {
    let _: Option<EcoString> = None;
    let mut out = String::new();
    out.push_str(
        "// Generated by `oracle/src/bin/gen_html_encode_tests.rs` from upstream's\n\
         // `typst_html` encoder. Do not edit.\n\n",
    );
    for (name, elem) in cases() {
        let c = code(&elem);
        for pretty in [false, true] {
            let mode = if pretty { "pretty" } else { "compact" };
            writeln!(
                out,
                "///|\ntest {} {{\n  check_encode({c}, pretty={pretty}, {})\n}}\n",
                lit(&format!("encode/{name}/{mode}")),
                lit(&encode(&elem, pretty)),
            )
            .unwrap();
        }
    }
    print!("{out}");
}
