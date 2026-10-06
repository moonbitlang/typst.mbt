//! The `eval` stage: evaluate every test case like the upstream test runner
//! does (`tests/src/run.rs`, `eval::eval`) and dump the diagnostics plus the
//! `repr` of the resulting content.

use std::fmt::Write as _;
use std::path::Path;

use comemo::Track;
use ecow::EcoVec;
use rustc_hash::FxHashSet;
use typst::World;
use typst::diag::{SourceDiagnostic, SourceResult, Tracepoint, Warned};
use typst::engine::{Route, Sink, Traced};
use typst::foundations::{Content, Repr};
use typst_syntax::{DiagSpan, DiagSpanKind, FileId, VirtualRoot};

use crate::collect;
use crate::world::{TestWorld, parse_features};

/// Dump eval results for every test below `suite` (a path relative to the
/// current directory, which must be the upstream checkout).
pub fn dump_eval(suite: &Path, out: &Path) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&eval_report(&file, &test));
            count += 1;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("evaluated {count} test cases");
}

/// Evaluate a single test case.
pub fn eval_report(path: &Path, test: &collect::TestCase) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);
    let main_id = world.main();

    let mut sink = Sink::new();
    let output = eval_impl((&world as &dyn World).track(), Traced::default().track(), &mut sink)
        .map_err(deduplicate);
    let warned = Warned { output, warnings: sink.warnings() };

    let mut out = String::new();
    match &warned.output {
        Ok(content) => {
            writeln!(out, "ok {}", content.repr()).unwrap();
        }
        Err(errors) => {
            out.push_str("err\n");
            for diag in errors {
                write_diag(&mut out, &world, main_id, diag);
            }
        }
    }
    for diag in &warned.warnings {
        write_diag(&mut out, &world, main_id, diag);
    }
    out
}

fn eval_impl(
    world: comemo::Tracked<dyn World + '_>,
    traced: comemo::Tracked<Traced>,
    sink: &mut Sink,
) -> SourceResult<Content> {
    let main = world.main();
    let main = world.source(main).expect("valid main file");
    let content = typst_eval::eval(
        world,
        world.library(),
        traced,
        sink.track_mut(),
        Route::default().track(),
        &main,
    )?
    .content();
    Ok(content)
}

/// Deduplicate diagnostics (like upstream).
pub fn deduplicate(mut diags: EcoVec<SourceDiagnostic>) -> EcoVec<SourceDiagnostic> {
    let hash =
        |diag: &SourceDiagnostic| typst_utils::hash128(&(&diag.span, &diag.message));
    let mut unique = FxHashSet::default();
    diags.retain(|diag| unique.insert(hash(diag)));
    diags
}

pub fn write_diag(out: &mut String, world: &TestWorld, main: FileId, diag: &SourceDiagnostic) {
    let severity = match diag.severity {
        typst::diag::Severity::Error => "error",
        typst::diag::Severity::Warning => "warning",
    };
    writeln!(
        out,
        "{severity} {} {:?}",
        locate(world, main, diag.span.get()),
        canonical_internal_error(diag.message.as_str())
    )
    .unwrap();
    for hint in &diag.hints {
        writeln!(out, "  hint {} {:?}", locate(world, main, hint.span.get()), hint.v.as_str())
            .unwrap();
    }
}

/// The tracepoints of a diagnostic, innermost first, one line each:
/// `  trace <location> <kind> <name>` with `kind` in `call|show|import|
/// include` and the name in Rust debug format (`-` for a call of an
/// unnamed function).
pub fn write_trace(out: &mut String, world: &TestWorld, main: FileId, diag: &SourceDiagnostic) {
    for point in &diag.trace {
        let (kind, name) = match &point.v {
            Tracepoint::Call(name) => ("call", name.as_ref()),
            Tracepoint::Show(name) => ("show", Some(name)),
            Tracepoint::Import(name) => ("import", Some(name)),
            Tracepoint::Include(name) => ("include", Some(name)),
        };
        let name = match name {
            Some(name) => format!("{:?}", name.as_str()),
            None => "-".into(),
        };
        let span = DiagSpan::from(point.span);
        writeln!(out, "  trace {} {kind} {name}", locate(world, main, span.get())).unwrap();
    }
}

/// Internal errors name the Rust source location they occurred at; since the
/// oracle builds Typst from `.repos/typst`, that location is an absolute path.
/// Make it relative to the Typst repository like in upstream's test suite.
pub fn canonical_internal_error(msg: &str) -> String {
    const MARKER: &str = "(occurred at ";
    const REPO: &str = ".repos/typst/";
    if let Some(at) = msg.find(MARKER) {
        let rest = &msg[at + MARKER.len()..];
        if let Some(repo) = rest.find(REPO) {
            return format!("{}{}", &msg[..at + MARKER.len()], &rest[repo + REPO.len()..]);
        }
    }
    msg.to_string()
}

/// Render a diagnostic span as `start..end` (main file) or `path:start..end`.
/// The path of a file of a real package (the `packages` stage; the
/// packages of upstream's suite have the namespace `test`) starts with
/// `@namespace/name:version/`.
fn locate(world: &TestWorld, main: FileId, kind: DiagSpanKind) -> String {
    let (id, range) = match kind {
        DiagSpanKind::Detached => return "-".into(),
        DiagSpanKind::Number { id, num, sub_range } => {
            let Ok(source) = world.source(id) else { return "?".into() };
            match source.range(num, sub_range) {
                Some(range) => (id, range),
                None => return "?".into(),
            }
        }
        DiagSpanKind::Range { id, range } => (id, range),
    };
    if id == main {
        format!("{}..{}", range.start, range.end)
    } else {
        let path = id.vpath().get_without_slash();
        let path = match id.root() {
            VirtualRoot::Package(spec) if spec.namespace != "test" => {
                format!("@{}/{}:{}/{path}", spec.namespace, spec.name, spec.version)
            }
            _ => path.to_string(),
        };
        format!("{:?}:{}..{}", path.as_str(), range.start, range.end)
    }
}
