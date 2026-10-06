//! The `packages` stage: compile documents that use real packages of the
//! Typst package registry and dump what the `paged` and `svg` stages dump
//! for the upstream suite.
//!
//! # Inputs
//!
//! - `docs`: the documents, `<docs>/<group>/<name>.typ` (`tests/packages/
//!   docs` of this repository; a group is named after the package its
//!   documents exercise). Every `.typ` file directly inside a group
//!   directory is a case; other files are data that the documents read.
//!   `docs` is the project root, so the main file of a case is
//!   `/<group>/<name>.typ`.
//! - `packages`: the unpacked packages, `<packages>/<namespace>/<name>/
//!   <version>/` (fetched and verified by `scripts/packages.sh` from
//!   `tests/packages/manifest.tsv`).
//!
//! Both are used as given (relative to the current directory), since file
//! errors name real paths.
//!
//! # World
//!
//! `TestWorld::packages`: what `typst compile --ignore-system-fonts
//! --creation-timestamp 0` sees. The standard library without inputs and
//! features (not the test library with its small pages), the fonts embedded
//! in the CLI (`typst_assets::fonts()`), and the fixed date of the test
//! world.
//!
//! # Output
//!
//! - `<out>/frames/<group>/<name>.txt`: `=== <name>` and the document in
//!   the `typst-frame-v1` format of the `paged` stage (see `paged.rs`). In
//!   its `diagnostics` record, every diagnostic line is followed by one
//!   line per tracepoint, `  trace <location> <kind> <name>` (see
//!   `eval::write_trace`): errors inside packages are told apart by the
//!   calls that lead to them.
//! - `<out>/svg/<group>/<name>.txt`: `=== <name>` and the SVG of the `svg`
//!   stage (see `svg.rs`: merged pages, pretty, 1pt gap), or `<error>` if
//!   there is no document.

use std::path::{Path, PathBuf};

use typst::syntax::{RootedPath, Source, VirtualPath, VirtualRoot};
use typst_library::layout::Abs;
use typst_svg::{SvgFormatOptions, SvgOptions};

use crate::paged::world_report;
use crate::world::TestWorld;

/// The cases below `docs`: `(group, name, path)`, sorted.
fn cases(docs: &Path) -> Vec<(String, String, PathBuf)> {
    let mut out = vec![];
    let mut groups: Vec<_> = std::fs::read_dir(docs)
        .unwrap_or_else(|e| panic!("cannot read {}: {e}", docs.display()))
        .map(|entry| entry.unwrap().path())
        .filter(|path| path.is_dir())
        .collect();
    groups.sort();
    for group in groups {
        let mut files: Vec<_> = std::fs::read_dir(&group)
            .unwrap()
            .map(|entry| entry.unwrap().path())
            .filter(|path| path.is_file() && path.extension().is_some_and(|e| e == "typ"))
            .collect();
        files.sort();
        for file in files {
            let name = |p: &Path| p.file_stem().unwrap().to_str().unwrap().to_string();
            out.push((
                group.file_name().unwrap().to_str().unwrap().to_string(),
                name(&file),
                file,
            ));
        }
    }
    out
}

/// Dump the frames and the SVG of every document below `docs`.
pub fn dump_packages(
    docs: &Path,
    packages: &Path,
    out: &Path,
    revision: &str,
    manifest_sha: &str,
) {
    assert!(
        packages.is_dir(),
        "{} does not exist: run scripts/packages.sh",
        packages.display()
    );
    let filter = std::env::var("ORACLE_FILTER").ok();
    let mut count = 0;
    for (group, name, file) in cases(docs) {
        let rel = format!("{group}/{name}");
        if let Some(f) = &filter
            && !rel.contains(f.as_str())
        {
            continue;
        }
        if std::env::var("ORACLE_VERBOSE").is_ok() {
            eprintln!("{rel}");
        }
        let text = std::fs::read_to_string(&file).unwrap();
        let vpath = VirtualPath::new(format!("{rel}.typ")).unwrap();
        let source =
            Source::new(RootedPath::new(VirtualRoot::Project, vpath).intern(), text);
        let world = TestWorld::packages(source, docs, packages);

        let (frames, doc) = world_report(&world, &name, revision, manifest_sha, true);
        let svg = match &doc {
            Some(doc) => {
                let options = SvgOptions {
                    format: SvgFormatOptions { pretty: Some(true) },
                    ..Default::default()
                };
                typst_svg::svg_merged(doc, &options, Abs::pt(1.0))
            }
            None => "<error>\n".into(),
        };

        for (kind, report) in [("frames", frames), ("svg", svg)] {
            let dest = out.join(kind).join(&group).join(format!("{name}.txt"));
            std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
            std::fs::write(dest, format!("=== {name}\n{report}")).unwrap();
        }
        count += 1;
    }
    eprintln!("compiled {count} package documents");
}
