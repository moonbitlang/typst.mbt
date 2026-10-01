//! Extracts a manifest of all `#[elem]`, `#[func]`, `#[ty]`, `#[scope]` and
//! `cast!` definitions from the upstream sources, so that the MoonBit port
//! can generate the boilerplate that Rust proc-macros produce, and detect
//! drift when upstream changes.
//!
//! Usage: `extract <crates-dir> > gen/manifest.json`

use std::path::{Path, PathBuf};

use quote::ToTokens;
use serde::Serialize;
use syn::parse::{Parse, ParseStream};
use syn::punctuated::Punctuated;
use syn::{Attribute, Expr, Ident, Token};

const CRATES: &[&str] = &[
    "typst-library",
    "typst-html",
    "typst-pdf",
    "typst-svg",
    "typst-render",
    "typst-bundle",
    "typst-layout",
    "typst-eval",
    "typst-realize",
];

#[derive(Serialize, Default)]
struct Manifest {
    elems: Vec<Elem>,
    funcs: Vec<Func>,
    types: Vec<Ty>,
    scopes: Vec<Scope>,
    casts: Vec<Cast>,
}

#[derive(Serialize)]
struct Elem {
    file: String,
    ident: String,
    name: String,
    title: String,
    scope: bool,
    keywords: Vec<String>,
    capabilities: Vec<String>,
    since: Option<String>,
    doc: String,
    fields: Vec<Field>,
}

#[derive(Serialize)]
struct Field {
    ident: String,
    name: String,
    ty: String,
    doc: String,
    positional: bool,
    required: bool,
    variadic: bool,
    fold: bool,
    internal: bool,
    external: bool,
    ghost: bool,
    synthesized: bool,
    parse: Option<String>,
    default: Option<String>,
}

#[derive(Serialize)]
struct Func {
    file: String,
    ident: String,
    /// The type of the `#[scope] impl` block this function is defined in.
    parent: Option<String>,
    name: String,
    title: String,
    scope: bool,
    contextual: bool,
    constructor: bool,
    keywords: Vec<String>,
    since: Option<String>,
    doc: String,
    deprecated: Option<String>,
    feature: Option<String>,
    self_param: Option<String>,
    engine: bool,
    context: bool,
    args: bool,
    span: bool,
    params: Vec<Param>,
    returns: String,
}

#[derive(Serialize)]
struct Param {
    ident: String,
    name: String,
    ty: String,
    doc: String,
    named: bool,
    variadic: bool,
    external: bool,
    default: Option<String>,
}

#[derive(Serialize)]
struct Ty {
    file: String,
    ident: String,
    name: String,
    title: String,
    scope: bool,
    cast: bool,
    keywords: Vec<String>,
    since: Option<String>,
    doc: String,
    kind: String,
}

#[derive(Serialize)]
struct Scope {
    file: String,
    self_ty: String,
    meta: String,
    members: Vec<ScopeMember>,
}

#[derive(Serialize)]
struct ScopeMember {
    kind: String,
    ident: String,
    attrs: Vec<String>,
    tokens: String,
}

#[derive(Serialize)]
struct Cast {
    file: String,
    ty: String,
    tokens: String,
}

fn main() {
    let dir = PathBuf::from(std::env::args().nth(1).expect("crates dir"));
    let mut manifest = Manifest::default();
    for krate in CRATES {
        let src = dir.join(krate).join("src");
        let mut files = vec![];
        walk(&src, &mut files);
        files.sort();
        for file in files {
            let rel = file.strip_prefix(&dir).unwrap().to_string_lossy().replace('\\', "/");
            let text = std::fs::read_to_string(&file).unwrap();
            let parsed = match syn::parse_file(&text) {
                Ok(f) => f,
                Err(e) => {
                    eprintln!("skip {rel}: {e}");
                    continue;
                }
            };
            visit_items(&rel, &parsed.items, &mut manifest);
        }
    }
    eprintln!(
        "elems: {}, funcs: {}, types: {}, scopes: {}, casts: {}",
        manifest.elems.len(),
        manifest.funcs.len(),
        manifest.types.len(),
        manifest.scopes.len(),
        manifest.casts.len()
    );
    println!("{}", serde_json::to_string_pretty(&manifest).unwrap());
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) {
    for entry in std::fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            walk(&path, out);
        } else if path.extension().is_some_and(|e| e == "rs") {
            out.push(path);
        }
    }
}

fn visit_items(file: &str, items: &[syn::Item], m: &mut Manifest) {
    for item in items {
        match item {
            syn::Item::Struct(s) => {
                if let Some(attr) = find_attr(&s.attrs, "elem") {
                    m.elems.push(parse_elem(file, attr, s));
                }
                if let Some(attr) = find_attr(&s.attrs, "ty") {
                    m.types.push(parse_ty(file, attr, &s.ident, &s.attrs, "struct"));
                }
            }
            syn::Item::Enum(e) => {
                if let Some(attr) = find_attr(&e.attrs, "ty") {
                    m.types.push(parse_ty(file, attr, &e.ident, &e.attrs, "enum"));
                }
            }
            syn::Item::Type(t) => {
                if let Some(attr) = find_attr(&t.attrs, "ty") {
                    m.types.push(parse_ty(file, attr, &t.ident, &t.attrs, "alias"));
                }
            }
            syn::Item::Verbatim(tokens) => {
                // Bare type declarations: `#[ty(..)] type Foo;`
                if let Ok(bare) = syn::parse2::<BareType>(tokens.clone())
                    && let Some(attr) = find_attr(&bare.attrs, "ty")
                {
                    m.types.push(parse_ty(file, attr, &bare.ident, &bare.attrs, "bare"));
                }
            }
            syn::Item::Fn(f) => {
                if let Some(attr) = find_attr(&f.attrs, "func") {
                    m.funcs.push(parse_func(file, attr, &f.attrs, &f.sig, None));
                }
            }
            syn::Item::Impl(imp) => {
                if let Some(attr) = find_attr(&imp.attrs, "scope") {
                    let self_ty = tokens(&imp.self_ty);
                    let mut members = vec![];
                    for child in &imp.items {
                        match child {
                            syn::ImplItem::Fn(f) => {
                                if let Some(fattr) = find_attr(&f.attrs, "func") {
                                    m.funcs.push(parse_func(
                                        file,
                                        fattr,
                                        &f.attrs,
                                        &f.sig,
                                        Some(self_ty.clone()),
                                    ));
                                }
                                members.push(ScopeMember {
                                    kind: "fn".into(),
                                    ident: f.sig.ident.to_string(),
                                    attrs: attr_strings(&f.attrs),
                                    tokens: String::new(),
                                });
                            }
                            syn::ImplItem::Const(c) => members.push(ScopeMember {
                                kind: "const".into(),
                                ident: c.ident.to_string(),
                                attrs: attr_strings(&c.attrs),
                                tokens: tokens(&c.expr),
                            }),
                            syn::ImplItem::Type(t) => members.push(ScopeMember {
                                kind: "type".into(),
                                ident: t.ident.to_string(),
                                attrs: attr_strings(&t.attrs),
                                tokens: tokens(&t.ty),
                            }),
                            syn::ImplItem::Verbatim(v) => members.push(ScopeMember {
                                kind: "verbatim".into(),
                                ident: String::new(),
                                attrs: vec![],
                                tokens: normalize(&v.to_string()),
                            }),
                            _ => {}
                        }
                    }
                    m.scopes.push(Scope {
                        file: file.into(),
                        self_ty,
                        meta: attr_args(attr),
                        members,
                    });
                }
            }
            syn::Item::Macro(mac) => {
                if mac.mac.path.is_ident("cast") {
                    let ts = mac.mac.tokens.to_string();
                    let ty = ts.split(',').next().unwrap_or("").trim().to_string();
                    m.casts.push(Cast {
                        file: file.into(),
                        ty: normalize(&ty),
                        tokens: normalize(&ts),
                    });
                }
            }
            syn::Item::Mod(module) => {
                if let Some((_, items)) = &module.content {
                    visit_items(file, items, m);
                }
            }
            syn::Item::Const(c) => {
                // `const _: () = { ... };` blocks may contain items.
                if let Expr::Block(block) = c.expr.as_ref() {
                    let items: Vec<syn::Item> = block
                        .block
                        .stmts
                        .iter()
                        .filter_map(|s| match s {
                            syn::Stmt::Item(i) => Some(i.clone()),
                            _ => None,
                        })
                        .collect();
                    visit_items(file, &items, m);
                }
            }
            _ => {}
        }
    }
}

/// `#[ty] type Foo;` bare type declarations.
struct BareType {
    attrs: Vec<Attribute>,
    ident: Ident,
}

impl Parse for BareType {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let attrs = input.call(Attribute::parse_outer)?;
        input.parse::<Token![type]>()?;
        let ident = input.parse()?;
        input.parse::<Token![;]>()?;
        Ok(Self { attrs, ident })
    }
}

fn find_attr<'a>(attrs: &'a [Attribute], name: &str) -> Option<&'a Attribute> {
    attrs.iter().find(|a| a.path().is_ident(name))
}

fn has_attr(attrs: &[Attribute], name: &str) -> bool {
    find_attr(attrs, name).is_some()
}

fn attr_args(attr: &Attribute) -> String {
    match &attr.meta {
        syn::Meta::List(list) => normalize(&list.tokens.to_string()),
        syn::Meta::NameValue(nv) => normalize(&nv.value.to_token_stream().to_string()),
        syn::Meta::Path(_) => String::new(),
    }
}

fn attr_strings(attrs: &[Attribute]) -> Vec<String> {
    attrs
        .iter()
        .filter(|a| !a.path().is_ident("doc"))
        .map(|a| normalize(&a.to_token_stream().to_string()))
        .collect()
}

fn tokens<T: ToTokens>(t: &T) -> String {
    normalize(&t.to_token_stream().to_string())
}

/// Normalize token spacing to something closer to rustfmt output.
fn normalize(s: &str) -> String {
    let mut out = s.to_string();
    for (from, to) in [
        (" < ", "<"),
        ("< ", "<"),
        (" >", ">"),
        (" :: ", "::"),
        (":: ", "::"),
        (" ::", "::"),
        (" ,", ","),
        ("& ", "&"),
        (" (", "("),
        ("( ", "("),
        (" )", ")"),
        (" . ", "."),
        (" [", "["),
        ("[ ", "["),
        (" ]", "]"),
        (" ;", ";"),
        ("! (", "!("),
        ("# [", "#["),
    ] {
        while out.contains(from) {
            out = out.replace(from, to);
        }
    }
    out
}

fn doc_of(attrs: &[Attribute]) -> String {
    let mut lines = vec![];
    for attr in attrs {
        if !attr.path().is_ident("doc") {
            continue;
        }
        if let syn::Meta::NameValue(nv) = &attr.meta
            && let Expr::Lit(lit) = &nv.value
            && let syn::Lit::Str(s) = &lit.lit
        {
            lines.push(s.value());
        }
    }
    // Keep only the first paragraph.
    let mut out = vec![];
    for line in lines {
        let t = line.trim();
        if t.is_empty() {
            if !out.is_empty() {
                break;
            }
            continue;
        }
        out.push(t.to_string());
    }
    out.join(" ")
}

/// Generic parser for `#[elem(..)]`, `#[func(..)]`, `#[ty(..)]` metadata:
/// a comma-separated list of flags, `key = value` pairs and bare idents.
#[derive(Default)]
struct Meta {
    flags: Vec<String>,
    pairs: Vec<(String, String)>,
    lists: Vec<(String, Vec<String>)>,
}

impl Meta {
    fn flag(&self, name: &str) -> bool {
        self.flags.iter().any(|f| f == name)
    }
    fn get(&self, name: &str) -> Option<String> {
        self.pairs.iter().find(|(k, _)| k == name).map(|(_, v)| v.clone())
    }
    fn list(&self, name: &str) -> Vec<String> {
        self.lists
            .iter()
            .find(|(k, _)| k == name)
            .map(|(_, v)| v.clone())
            .unwrap_or_default()
    }
}

impl Parse for Meta {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let mut meta = Meta::default();
        let items = Punctuated::<syn::Meta, Token![,]>::parse_terminated(input)?;
        for item in items {
            match item {
                syn::Meta::Path(p) => meta.flags.push(tokens(&p)),
                syn::Meta::NameValue(nv) => {
                    let key = tokens(&nv.path);
                    match &nv.value {
                        Expr::Lit(syn::ExprLit { lit: syn::Lit::Str(s), .. }) => {
                            meta.pairs.push((key, s.value()))
                        }
                        Expr::Array(arr) => meta.lists.push((
                            key,
                            arr.elems
                                .iter()
                                .map(|e| match e {
                                    Expr::Lit(syn::ExprLit {
                                        lit: syn::Lit::Str(s), ..
                                    }) => s.value(),
                                    other => tokens(other),
                                })
                                .collect(),
                        )),
                        other => meta.pairs.push((key, tokens(other))),
                    }
                }
                syn::Meta::List(l) => meta.pairs.push((tokens(&l.path), tokens(&l.tokens))),
            }
        }
        Ok(meta)
    }
}

fn parse_meta(attr: &Attribute) -> Meta {
    match &attr.meta {
        syn::Meta::List(list) => syn::parse2(list.tokens.clone()).unwrap_or_else(|e| {
            panic!("bad attribute {}: {e}", tokens(attr));
        }),
        _ => Meta::default(),
    }
}

/// `heck::ToKebabCase` for the identifiers we encounter.
fn kebab(s: &str) -> String {
    // heck drops leading and trailing underscores (`where_` -> `where`).
    let s = s.trim_matches('_');
    let mut out = String::new();
    let chars: Vec<char> = s.chars().collect();
    for (i, &c) in chars.iter().enumerate() {
        if c == '_' {
            out.push('-');
        } else if c.is_uppercase() {
            let prev_lower = i > 0 && (chars[i - 1].is_lowercase() || chars[i - 1].is_numeric());
            let next_lower = chars.get(i + 1).is_some_and(|n| n.is_lowercase());
            let prev_upper = i > 0 && chars[i - 1].is_uppercase();
            if i > 0 && !out.ends_with('-') && (prev_lower || (prev_upper && next_lower)) {
                out.push('-');
            }
            out.extend(c.to_lowercase());
        } else {
            out.push(c);
        }
    }
    // Like heck, drop empty words (e.g. the trailing `_` of `where_`).
    out.split('-').filter(|w| !w.is_empty()).collect::<Vec<_>>().join("-")
}

fn title_case(name: &str) -> String {
    name.split('-')
        .map(|w| {
            let mut c = w.chars();
            match c.next() {
                Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn parse_elem(file: &str, attr: &Attribute, s: &syn::ItemStruct) -> Elem {
    let meta = parse_meta(attr);
    let ident = s.ident.to_string();
    let base = ident.trim_end_matches("Elem");
    let name = meta.get("name").unwrap_or_else(|| kebab(base));
    let title = meta.get("title").unwrap_or_else(|| title_case(&name));
    let mut fields = vec![];
    if let syn::Fields::Named(named) = &s.fields {
        for f in &named.named {
            let fident = f.ident.as_ref().unwrap().to_string();
            let variadic = has_attr(&f.attrs, "variadic");
            let required = has_attr(&f.attrs, "required") || variadic;
            let positional = has_attr(&f.attrs, "positional") || required;
            fields.push(Field {
                name: kebab(&fident),
                ident: fident,
                ty: tokens(&f.ty),
                doc: doc_of(&f.attrs),
                positional,
                required,
                variadic,
                fold: has_attr(&f.attrs, "fold"),
                internal: has_attr(&f.attrs, "internal"),
                external: has_attr(&f.attrs, "external"),
                ghost: has_attr(&f.attrs, "ghost"),
                synthesized: has_attr(&f.attrs, "synthesized"),
                parse: find_attr(&f.attrs, "parse").map(attr_args),
                default: find_attr(&f.attrs, "default").map(attr_args),
            });
        }
    }
    // Upstream sorts fields so that internal ones come last (stable sort).
    fields.sort_by_key(|f| f.internal);
    Elem {
        file: file.into(),
        ident,
        name,
        title,
        scope: meta.flag("scope"),
        keywords: meta.list("keywords"),
        capabilities: meta
            .flags
            .iter()
            .filter(|f| f.as_str() != "scope")
            .cloned()
            .collect(),
        since: meta.get("since"),
        doc: doc_of(&s.attrs),
        fields,
    }
}

fn parse_func(
    file: &str,
    attr: &Attribute,
    attrs: &[Attribute],
    sig: &syn::Signature,
    parent: Option<String>,
) -> Func {
    let meta = parse_meta(attr);
    let ident = sig.ident.to_string();
    let name = meta.get("name").unwrap_or_else(|| kebab(&ident));
    let title = meta.get("title").unwrap_or_else(|| title_case(&name));
    let mut func = Func {
        file: file.into(),
        ident,
        parent: meta.get("parent").or(parent),
        name,
        title,
        scope: meta.flag("scope"),
        contextual: meta.flag("contextual"),
        constructor: meta.flag("constructor"),
        keywords: meta.list("keywords"),
        since: meta.get("since"),
        doc: doc_of(attrs),
        deprecated: find_attr(attrs, "deprecated").map(attr_args),
        feature: find_attr(attrs, "feature").map(attr_args),
        self_param: None,
        engine: false,
        context: false,
        args: false,
        span: false,
        params: vec![],
        returns: match &sig.output {
            syn::ReturnType::Default => "()".into(),
            syn::ReturnType::Type(_, ty) => tokens(ty),
        },
    };
    for input in &sig.inputs {
        match input {
            syn::FnArg::Receiver(recv) => {
                func.self_param = Some(
                    match (recv.reference.is_some(), recv.mutability.is_some()) {
                        (true, true) => "&mut self",
                        (true, false) => "&self",
                        _ => "self",
                    }
                    .into(),
                );
            }
            syn::FnArg::Typed(typed) => {
                let pname = match typed.pat.as_ref() {
                    syn::Pat::Ident(p) => p.ident.to_string(),
                    other => tokens(other),
                };
                match pname.as_str() {
                    "engine" => func.engine = true,
                    "context" => func.context = true,
                    "args" => func.args = true,
                    "span" => func.span = true,
                    _ => func.params.push(Param {
                        name: kebab(&pname),
                        ident: pname,
                        ty: tokens(&typed.ty),
                        doc: doc_of(&typed.attrs),
                        named: has_attr(&typed.attrs, "named"),
                        variadic: has_attr(&typed.attrs, "variadic"),
                        external: has_attr(&typed.attrs, "external"),
                        default: find_attr(&typed.attrs, "default").map(|a| {
                            let s = attr_args(a);
                            if s.is_empty() { "Default::default()".into() } else { s }
                        }),
                    }),
                }
            }
        }
    }
    func
}

fn parse_ty(file: &str, attr: &Attribute, ident: &Ident, attrs: &[Attribute], kind: &str) -> Ty {
    let meta = parse_meta(attr);
    let name = meta.get("name").unwrap_or_else(|| kebab(&ident.to_string()));
    let title = meta.get("title").unwrap_or_else(|| title_case(&name));
    Ty {
        file: file.into(),
        ident: ident.to_string(),
        name,
        title,
        scope: meta.flag("scope"),
        cast: meta.flag("cast"),
        keywords: meta.list("keywords"),
        since: meta.get("since"),
        doc: doc_of(attrs),
        kind: kind.into(),
    }
}
