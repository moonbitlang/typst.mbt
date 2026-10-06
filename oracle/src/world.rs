//! The upstream test world, adapted from `.repos/typst/tests/src/world.rs`
//! (Apache-2.0, Copyright Typst contributors). Kept as close to upstream as
//! possible so that evaluation results match the upstream test suite.
//!
//! All relative paths are resolved against the current working directory,
//! which must be the upstream checkout (`.repos/typst`).

use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::sync::{Arc, OnceLock};

use comemo::Tracked;
use parking_lot::Mutex;
use rustc_hash::FxHashMap;
use typst::diag::{
    FileError, FileResult, PackageError, SourceResult, StrResult, bail,
};
use typst::engine::Engine;
use typst::foundations::{
    Array, Bytes, Content, Context, Datetime, Deprecation, Duration, IntoValue, Module,
    NativeElement, NoneValue, Packed, Repr, Scope, Smart, StyleChain, Value, elem, func,
    scope,
};
use typst::introspection::Locator;
use typst::layout::{Abs, BlockElem, Fragment, Margin, PageElem, Regions};
use typst::model::{Numbering, NumberingPattern};
use typst::syntax::{FileId, Source, Span};
use typst::text::{Font, FontBook, TextElem, TextSize};
use typst::utils::{LazyHash, singleton};
use typst::visualize::Color;
use typst::{Feature, Features, Library, LibraryExt, World};
use typst_kit::datetime::Time;
use typst_kit::files::{FileLoader, FileStore};
use typst_layout::layout_fragment;
use typst_syntax::package::PackageSpec;
use typst_syntax::{RootedPath, VirtualPath, VirtualRoot};
use unscanny::Scanner;

#[derive(Clone)]
pub struct TestWorld {
    main: Source,
    library: Arc<LazyHash<Library>>,
    base: &'static TestBase,
}

impl TestWorld {
    pub fn new(source: Source, features: Option<Features>) -> Self {
        let base = singleton!(TestBase, TestBase::default());
        let library = base.lib.with_features(features);
        Self { main: source, library, base }
    }

    /// The world of the `packages` stage (see `packages.rs`): the library
    /// and the fonts of `typst compile --ignore-system-fonts` (no inputs,
    /// no features, the embedded fonts), the project rooted at `root` and
    /// packages read from `<packages>/<namespace>/<name>/<version>`. The
    /// first call fixes both directories for the process.
    pub fn packages(source: Source, root: &Path, packages: &Path) -> Self {
        static BASE: OnceLock<TestBase> = OnceLock::new();
        let base = BASE.get_or_init(|| TestBase::packages(root, packages));
        let library = Arc::clone(&base.lib.base);
        Self { main: source, library, base }
    }

    /// Create the main source for a test body at a path relative to the
    /// upstream checkout, like upstream `parse_test_body`.
    pub fn main_source(path: &Path, body: String) -> Source {
        let vpath = VirtualPath::virtualize(Path::new(""), path).unwrap();
        Source::new(RootedPath::new(VirtualRoot::Project, vpath).intern(), body)
    }
}

impl World for TestWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.base.book
    }

    fn main(&self) -> FileId {
        self.main.id()
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.main.id() {
            Ok(self.main.clone())
        } else {
            self.base.files.source(id)
        }
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        if id == self.main.id() {
            Ok(Bytes::from_string(self.main.clone()))
        } else {
            self.base.files.file(id)
        }
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.base.fonts.get(index).cloned()
    }

    fn today(&self, offset: Option<Duration>) -> Option<Datetime> {
        let datetime = Datetime::from_ymd_hms(1970, 1, 1, 12, 0, 0).unwrap();
        Time::fixed(datetime).unwrap().today(offset)
    }
}

struct TestBase {
    lib: Libraries,
    book: LazyHash<FontBook>,
    fonts: Vec<Font>,
    files: FileStore<TestFiles>,
}

impl Default for TestBase {
    fn default() -> Self {
        let fonts: Vec<_> = typst_assets::fonts()
            .chain(typst_dev_assets::fonts())
            .flat_map(|data| Font::iter(Bytes::new(data)))
            .collect();

        Self {
            lib: Libraries::new(library()),
            book: LazyHash::new(FontBook::from_fonts(&fonts)),
            fonts,
            files: FileStore::new(TestFiles::Suite),
        }
    }
}

impl TestBase {
    /// The base of [`TestWorld::packages`].
    fn packages(root: &Path, packages: &Path) -> Self {
        // Like `typst-cli` with `--ignore-system-fonts`: the embedded fonts
        // only.
        let fonts: Vec<_> = typst_assets::fonts()
            .flat_map(|data| Font::iter(Bytes::new(data)))
            .collect();
        // The library of `typst-cli` without inputs and features.
        let lib = Library::builder([
            typst_html::FORMAT,
            typst_pdf::FORMAT,
            typst_svg::FORMAT,
            typst_render::FORMAT,
            typst_bundle::FORMAT,
        ])
        .build();

        Self {
            lib: Libraries::new(lib),
            book: LazyHash::new(FontBook::from_fonts(&fonts)),
            fonts,
            files: FileStore::new(TestFiles::Packages {
                root: root.to_path_buf(),
                packages: packages.to_path_buf(),
            }),
        }
    }
}

struct Libraries {
    base: Arc<LazyHash<Library>>,
    overrides: Mutex<FxHashMap<Features, Arc<LazyHash<Library>>>>,
}

impl Libraries {
    fn new(base: Library) -> Self {
        Self {
            base: Arc::new(LazyHash::new(base)),
            overrides: Mutex::new(FxHashMap::default()),
        }
    }

    fn with_features(&self, features: Option<Features>) -> Arc<LazyHash<Library>> {
        let Some(features) = features else {
            return Arc::clone(&self.base);
        };

        let mut overrides = self.overrides.lock();
        let lib = overrides.entry(features.clone()).or_insert_with(|| {
            let mut lib = Library::clone(&*self.base);
            lib.features = features;
            Arc::new(LazyHash::new(lib))
        });
        Arc::clone(lib)
    }
}

/// Parse the parameter list of a `features(...)` test attribute.
pub fn parse_features(params: &str) -> Features {
    if params.trim().is_empty() {
        return Features::none();
    }
    params
        .split(',')
        .map(str::trim)
        .filter_map(|p| Feature::from_str(p).ok())
        .collect()
}

pub enum TestFiles {
    /// The files of upstream's test world.
    Suite,
    /// The files of the `packages` stage: a project directory and a
    /// directory of unpacked packages
    /// (`<packages>/<namespace>/<name>/<version>`).
    Packages { root: PathBuf, packages: PathBuf },
}

impl TestFiles {
    pub fn resolve(&self, id: FileId) -> FileResult<PathBuf> {
        let root = match (self, id.root()) {
            (Self::Suite, VirtualRoot::Project) => PathBuf::new(),
            (Self::Suite, VirtualRoot::Package(spec)) => {
                assert_eq!(spec.namespace, "test");
                format!("tests/packages/{}-{}", spec.name, spec.version).into()
            }
            (Self::Packages { root, .. }, VirtualRoot::Project) => root.clone(),
            (Self::Packages { packages, .. }, VirtualRoot::Package(spec)) => {
                let dir = packages
                    .join(spec.namespace.as_str())
                    .join(spec.name.as_str())
                    .join(spec.version.to_string());
                // Like `typst-kit`'s package storage: a package that is not
                // there is a package error, not a missing file.
                if !dir.is_dir() {
                    return Err(FileError::Package(PackageError::NotFound(
                        spec.clone(),
                    )));
                }
                dir
            }
        };
        id.vpath().realize(&root).map_err(Into::into)
    }

    #[allow(dead_code)]
    pub fn rooted_path(path: &str) -> RootedPath {
        let mut s = Scanner::new(path);
        let root = if s.eat_if("tests/packages/") {
            let name = s.eat_until('-');
            s.expect('-');
            let version = s.eat_until('/');
            s.expect('/');
            VirtualRoot::Package(PackageSpec {
                namespace: "test".into(),
                name: name.into(),
                version: version.parse().unwrap(),
            })
        } else {
            VirtualRoot::Project
        };
        let vpath = VirtualPath::new(s.after()).unwrap();
        RootedPath::new(root, vpath)
    }
}

impl FileLoader for TestFiles {
    fn load(&self, id: FileId) -> FileResult<Bytes> {
        let path = self.resolve(id)?;

        if matches!(self, Self::Suite)
            && let Ok(suffix) = path.strip_prefix("assets/")
        {
            return typst_dev_assets::get(&suffix.to_string_lossy())
                .map(Bytes::new)
                .ok_or_else(|| FileError::NotFound(path));
        }

        let f = |e| FileError::from_io(e, &path);
        if fs::metadata(&path).map_err(f)?.is_dir() {
            Err(FileError::IsDirectory)
        } else {
            fs::read(&path).map(Bytes::new).map_err(f)
        }
    }
}

fn library() -> Library {
    let mut lib = Library::builder([
        typst_html::FORMAT,
        typst_pdf::FORMAT,
        typst_svg::FORMAT,
        typst_render::FORMAT,
        typst_bundle::FORMAT,
    ])
    .with_features(Features::all())
    .build();

    lib.global.scope_mut().define("check", check_module());
    lib.global.scope_mut().define_func::<test>();
    lib.global.scope_mut().define_func::<test_repr>();
    lib.global.scope_mut().define_func::<print>();
    lib.global.scope_mut().define_func::<lines>();
    lib.global.scope_mut().define_func::<bounds>();
    lib.global
        .scope_mut()
        .define("conifer", Color::from_u8(0x9f, 0xEB, 0x52, 0xFF));
    lib.global
        .scope_mut()
        .define("forest", Color::from_u8(0x43, 0xA1, 0x27, 0xFF));

    lib.styles.set(PageElem::width, Smart::Custom(Abs::pt(120.0).into()));
    lib.styles.set(PageElem::height, Smart::Auto);
    lib.styles.set(
        PageElem::margin,
        Smart::Custom(Margin::splat(Some(Smart::Custom(Abs::pt(10.0).into())))),
    );
    lib.styles.set(TextElem::size, TextSize(Abs::pt(10.0).into()));

    lib
}

fn check_module() -> Module {
    let mut check = Scope::new();
    check
        .define("deprecated", Value::None)
        .with_deprecation(Deprecation::new().with_message("this value is useless"));
    check.define("gated", Value::None).with_feature(Feature::Html);
    check.define("red", Color::RED);
    Module::new("check", check)
}

#[func(scope)]
fn test(lhs: Value, rhs: Value) -> StrResult<NoneValue> {
    if lhs != rhs {
        bail!("Assertion failed: {} != {}", lhs.repr(), rhs.repr());
    }
    Ok(NoneValue)
}

#[scope]
impl test {
    #[func]
    #[deprecated(message = "this function is useless")]
    fn deprecated() -> StrResult<Value> {
        Ok(Value::None)
    }

    #[func]
    #[feature = Html]
    fn gated() -> StrResult<Value> {
        Ok(Value::None)
    }
}

#[func]
fn test_repr(lhs: Value, rhs: Value) -> StrResult<NoneValue> {
    if lhs.repr() != rhs.repr() {
        bail!("Assertion failed: {} != {}", lhs.repr(), rhs.repr());
    }
    Ok(NoneValue)
}

/// Upstream prints to stdout; the oracle stays silent so that its own output
/// is not polluted.
#[func]
fn print(#[variadic] values: Vec<Value>) -> NoneValue {
    let _ = values;
    NoneValue
}

/// Generates `count` lines of text based on the numbering.
#[func]
fn lines(
    engine: &mut Engine,
    context: Tracked<Context>,
    span: Span,
    count: u64,
    #[default(Numbering::Pattern(NumberingPattern::from_str("A").unwrap()))]
    numbering: Numbering,
) -> SourceResult<Value> {
    (1..=count)
        .map(|n| numbering.apply(engine, context, span, &[n]))
        .collect::<SourceResult<Array>>()?
        .join(Some('\n'.into_value()), None, None)
        .at(span)
}

/// Display boundaries and the baseline around some content's frames.
#[func]
fn bounds(content: Content) -> SourceResult<Content> {
    Ok(BlockElem::multi_layouter(Packed::new(BoundsElem::new(content)), layout_bounds)
        .pack())
}

#[elem]
struct BoundsElem {
    #[positional]
    #[required]
    body: Content,
}

fn layout_bounds(
    elem: &Packed<BoundsElem>,
    engine: &mut Engine,
    locator: Locator,
    styles: StyleChain,
    regions: Regions,
) -> SourceResult<Fragment> {
    let mut fragment = layout_fragment(engine, &elem.body, locator, styles, regions)?;
    for frame in &mut fragment {
        frame.mark_box_in_place();
    }

    Ok(fragment)
}

use typst::diag::At;
