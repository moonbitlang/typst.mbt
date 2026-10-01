//! The `realize` stage: evaluate every test case, then run upstream
//! realization (`typst_realize::realize`) on the resulting content, once as a
//! document and once as a fragment, and dump the realized pairs.
//!
//! To test realization in isolation, the library only has the base native
//! show rules (`NativeRuleMap::new()`, without the layout and HTML rules),
//! the introspector is empty and the base styles are empty (plus the paged
//! target). Locations are numbered in order of appearance since their hashes
//! are not comparable across implementations.

use std::fmt::Write as _;
use std::path::Path;

use comemo::Track;
use rustc_hash::FxHashMap;
use typst::World;
use typst::diag::SourceDiagnostic;
use typst::engine::{Engine, Route, Sink, Traced};
use typst::foundations::{
    Content, NativeRuleMap, Repr, SequenceElem, Smart, Style, StyleChain, StyledElem,
    Styles, Target, TargetElem, Transformation, Value,
};
use typst::format::DocumentFormatOptions;
use typst::introspection::{EmptyIntrospector, Location, Locator, Tag, TagElem};
use typst::model::DocumentInfo;
use typst::routines::{Arenas, FragmentKind, RealizationKind};
use typst::utils::{LazyHash, Protected};
use typst_syntax::FileId;

use crate::collect;
use crate::eval::{deduplicate, write_diag};
use crate::world::{TestWorld, parse_features};

/// Dump realization results for every test below `suite`.
pub fn dump_realize(suite: &Path, out: &Path) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&realize_report(&file, &test));
            count += 1;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("realized {count} test cases");
}

/// Evaluate and realize a single test case.
pub fn realize_report(path: &Path, test: &collect::TestCase) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);
    let main_id = world.main();

    // The library with only the base native show rules.
    let mut lib: typst::Library = (**world.library()).clone();
    lib.rules = NativeRuleMap::new();
    let library = LazyHash::new(lib);

    let tracked = (&world as &dyn World).track();
    let traced = Traced::default();
    let mut sink = Sink::new();
    let main = world.source(main_id).unwrap();
    let content = match typst_eval::eval(
        tracked,
        &library,
        traced.track(),
        sink.track_mut(),
        Route::default().track(),
        &main,
    ) {
        Ok(module) => module.content(),
        Err(_) => return "eval error\n".into(),
    };

    let mut out = String::new();
    for fragment in [false, true] {
        let mut dumper = Dumper::default();
        let mut subsink = Sink::new();
        let introspector = EmptyIntrospector;
        let mut engine = Engine {
            library: &library,
            world: tracked,
            introspector: Protected::new(introspector.track()),
            traced: traced.track(),
            sink: subsink.track_mut(),
            route: Route::default(),
        };
        let arenas = Arenas::default();
        let mut info = DocumentInfo::default();
        let mut options = DocumentFormatOptions::new(&library.formats);
        let mut fragment_kind = FragmentKind::Block;
        let kind = if fragment {
            RealizationKind::Fragment { kind: &mut fragment_kind }
        } else {
            RealizationKind::Document { info: &mut info, options: &mut options }
        };
        let base = Styles::new();
        let target = TargetElem::target.set(Target::Paged).wrap();
        let styles = StyleChain::new(&base);
        let styles = styles.chain(&target);
        let mut locator = Locator::root().split();
        let result =
            typst_realize::realize(kind, &mut engine, &mut locator, &arenas, &content, styles);

        if fragment {
            out.push_str("--- fragment\n");
        } else {
            out.push_str("--- document\n");
        }
        match result {
            Ok(pairs) => {
                for (content, styles) in pairs {
                    let c = dumper.content(content);
                    let s = dumper.chain(styles);
                    writeln!(out, "{c} @ {s}").unwrap();
                }
            }
            Err(errors) => {
                out.push_str("err\n");
                for diag in deduplicate(errors) {
                    write_diag(&mut out, &world, main_id, &diag);
                }
            }
        }
        if fragment {
            let kind = match fragment_kind {
                FragmentKind::Inline => "inline",
                FragmentKind::Block => "block",
            };
            writeln!(out, "kind {kind}").unwrap();
        } else {
            out.push_str(&info_line(&info));
        }
        write_diags(&mut out, &world, main_id, "delayed", subsink.delayed());
        let warnings: Vec<_> = subsink.warnings().into_iter().collect();
        write_diags(&mut out, &world, main_id, "warnings", warnings.into());
    }
    out
}

fn write_diags(
    out: &mut String,
    world: &TestWorld,
    main: FileId,
    what: &str,
    diags: ecow::EcoVec<SourceDiagnostic>,
) {
    if diags.is_empty() {
        return;
    }
    writeln!(out, "{what}").unwrap();
    for diag in deduplicate(diags) {
        write_diag(out, world, main, &diag);
    }
}

/// The document info as a line.
fn info_line(info: &DocumentInfo) -> String {
    let opt = |s: &Option<ecow::EcoString>| match s {
        Some(s) => format!("{:?}", s.as_str()),
        None => "none".into(),
    };
    let list = |l: &[ecow::EcoString]| {
        let items: Vec<String> = l.iter().map(|s| format!("{:?}", s.as_str())).collect();
        format!("[{}]", items.join(", "))
    };
    let date = match &info.date {
        Smart::Auto => "auto".to_string(),
        Smart::Custom(None) => "none".to_string(),
        Smart::Custom(Some(d)) => d.repr().to_string(),
    };
    let locale = match &info.locale {
        Smart::Auto => "auto".to_string(),
        Smart::Custom(l) => l.rfc_3066().to_string(),
    };
    format!(
        "info title={} author={} description={} keywords={} date={} locale={}\n",
        opt(&info.title),
        list(&info.author),
        opt(&info.description),
        list(&info.keywords),
        date,
        locale,
    )
}

/// Dumps content and styles, numbering locations in order of appearance.
#[derive(Default)]
struct Dumper {
    locations: FxHashMap<Location, usize>,
}

impl Dumper {
    fn loc(&mut self, loc: Location) -> String {
        let n = self.locations.len();
        let id = *self.locations.entry(loc).or_insert(n);
        format!("#{id}")
    }

    fn content(&mut self, content: &Content) -> String {
        if let Some(seq) = content.to_packed::<SequenceElem>() {
            let items: Vec<String> = seq.children.iter().map(|c| self.content(c)).collect();
            return format!("[{}]", items.join(", "));
        }
        if let Some(styled) = content.to_packed::<StyledElem>() {
            let styles = self.styles(&styled.styles);
            let child = self.content(&styled.child);
            return format!("styled({styles}; {child})");
        }
        if let Some(tag) = content.to_packed::<TagElem>() {
            return match &tag.tag {
                Tag::Start(elem, _) => {
                    let loc = self.loc(elem.location().unwrap());
                    format!("tag.start({loc}, {})", elem.elem().name())
                }
                Tag::End(loc, _, _) => {
                    let loc = self.loc(*loc);
                    format!("tag.end({loc})")
                }
            };
        }
        let mut fields = vec![];
        for (name, value) in content.fields() {
            let v = self.value(&value);
            fields.push(format!("{}: {v}", name.as_str()));
        }
        let mut out = format!("{}({})", content.elem().name(), fields.join(", "));
        if let Some(loc) = content.location() {
            out.push(' ');
            out.push_str(&self.loc(loc));
        }
        if content.is_prepared() {
            out.push('!');
        }
        out
    }

    fn value(&mut self, value: &Value) -> String {
        match value {
            Value::Content(c) => self.content(c),
            Value::Array(a) => {
                let items: Vec<String> = a.iter().map(|v| self.value(v)).collect();
                format!("({})", items.join(", "))
            }
            v => v.repr().to_string(),
        }
    }

    fn styles(&mut self, styles: &Styles) -> String {
        let items: Vec<String> = styles.iter().map(|s| self.style(s)).collect();
        items.join(", ")
    }

    fn style(&mut self, style: &Style) -> String {
        match style {
            Style::Property(property) => {
                let elem = style.element().unwrap();
                let id = (0..=255u8).find(|&id| property.is(elem, id)).unwrap();
                let name = elem.field_name(id).unwrap_or("internal");
                let value = elem.settable_field_accessor(name).map(|accessor| {
                    let single = Styles::from(style.clone());
                    accessor(StyleChain::new(&single))
                });
                let v = match value {
                    Some(v) => self.value(&v),
                    None => "?".into(),
                };
                format!("{}.{name}={v}", elem.name())
            }
            Style::Recipe(recipe) => {
                let selector = match recipe.selector() {
                    Some(s) => s.repr().to_string(),
                    None => "none".into(),
                };
                let transform = match recipe.transform() {
                    Transformation::Content(c) => self.content(c),
                    Transformation::Func(f) => f.repr().to_string(),
                    Transformation::Style(s) => format!("set({})", self.styles(s)),
                };
                format!("show {selector}: {transform}")
            }
            Style::Revocation(index) => format!("revoke({})", index.0),
        }
    }

    fn chain(&mut self, chain: StyleChain) -> String {
        let mut links: Vec<&[LazyHash<Style>]> = chain.links().collect();
        links.reverse();
        let items: Vec<String> = links
            .into_iter()
            .map(|link| {
                let items: Vec<String> = link.iter().map(|s| self.style(&**s)).collect();
                format!("{{{}}}", items.join(", "))
            })
            .collect();
        items.join(" ")
    }
}
