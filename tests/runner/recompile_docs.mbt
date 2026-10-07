// The documents of the `recompile` stage (`recompile_stage.mbt`).
//
// What it guarantees: the list is fixed (no directory is scanned for the
// default run, so its size is the number in `scripts/ci/stages.tsv`), and a
// listed document that is not found is a document that fails.
//
// Four kinds, chosen for what a compilation could keep of them:
//
// - `bench/*.typ`: the documents whose recompilation is measured.
// - Tests of upstream's suite that compute pages from the document
//   (counters, state, queries, outline, bibliography, footnotes, page
//   numbering, `context`, `measure`, `layout`), that import and include
//   other files, or that load data (JSON, CSV, TOML, YAML, XML, CBOR, text,
//   images of every kind, syntaxes and themes of `raw`, bibliographies,
//   plugins, a package). Their main file is the body of the test, in
//   upstream's test world; the files they name are those of the upstream
//   checkout. A few fail on purpose.
// - `tests/recompile/docs/*`: projects of several files, which the suite
//   does not have (its tests are one file and at most one import deep).
// - `tests/packages/docs`: documents that use real packages, if the
//   packages are there (the `packages` stage's world).

///|
/// A document.
priv struct Document {
  /// `<kind>/<path>`.
  name : String
  flavor : Flavor
  main : @syntax.FileId
  /// The files on disk.
  base : (@syntax.FileId) -> Bytes raise @library.FileError
  /// The files that are in memory from the start.
  files : Array[(@syntax.FileId, Bytes)]
}

///|
/// The id of a file of the project.
fn project_file(path : String) -> @syntax.FileId {
  let vpath = @syntax.VirtualPath::new(path) catch { e => abort(e.to_string()) }
  @syntax.RootedPath::new(Project, vpath).intern()
}

///|
/// The files of this repository (the project root is the repository's).
fn repository_load(id : @syntax.FileId) -> Bytes raise @library.FileError {
  match id.root() {
    Project => @kit.FsRoot::new(".").load(id.vpath())
    Package(spec) =>
      raise @library.FileError::Package(@library.PackageError::NotFound(spec))
  }
}

///|
/// The tests of upstream's suite: a file and the names of its tests.
let recompile_suite : ReadOnlyArray[(String, ReadOnlyArray[String])] = [
  // Counters, state, queries, locations.
  (
    "introspection/counter.typ",
    [
      "counter-basic-1", "counter-heading", "counter-page", "counter-display-at",
      "counter-display-matching-numbering-full", "counter-figure",
    ],
  ),
  ("introspection/state.typ", ["state-basic", "state-nested"]),
  (
    "introspection/query.typ",
    [
      "query-running-header", "query-list-of-figures", "query-complex", "query-within",
    ],
  ),
  (
    "introspection/locate.typ",
    ["locate-between-pages", "locate-start-of-par", "locate-missing-label"],
  ),
  (
    "introspection/convergence.typ",
    [
      "convergence-query", "convergence-page", "convergence-state", "convergence-counter",
      "convergence-measure", "converge-bibliography-1",
    ],
  ),
  // Outline, bibliography, citations, footnotes, figures, references.
  (
    "model/outline.typ",
    [
      "outline-entry-complex", "outline-heading-start-of-page", "outline-indent-auto-mixed-prefix",
      "outline-bookmark", "outline-bad-element",
    ],
  ),
  (
    "model/bibliography.typ",
    [
      "bibliography-basic", "bibliography-multiple-files", "bibliography-before-content",
      "bibliography-csl-display", "bibliography-duplicate-key",
    ],
  ),
  (
    "model/cite.typ",
    [
      "cite-supplements-and-ibid", "issue-785-cite-locate", "issue-3481-cite-location",
      "cite-group", "cite-unknown",
    ],
  ),
  (
    "layout/flow/footnote.typ",
    [
      "footnote-in-columns", "issue-1433-footnote-in-list", "issue-5435-footnote-migration-in-floats",
      "footnote-break-across-pages", "footnote-ref-multiple",
    ],
  ),
  ("model/figure.typ", ["figure-basic", "figure-theorem"]),
  ("model/ref.typ", ["ref-supplements"]),
  // Page numbering.
  (
    "layout/page.typ",
    [
      "page-numbering-pdf-label", "issue-2631-page-header-ordering", "page-marginals",
    ],
  ),
  ("layout/pagebreak.typ", ["issue-2095-pagebreak-numbering"]),
  // `context`, `measure`, `layout`.
  (
    "foundations/context.typ",
    ["context-in-show-rule", "context-delayed-warning"],
  ),
  (
    "layout/measure.typ",
    [
      "measure-counter-width", "measure-citation-in-flow", "measure-counter-multiple-times",
      "measure-given-area",
    ],
  ),
  (
    "layout/layout.typ",
    [
      "layout-in-page-call", "issue-6822-layout-multiple", "layout-in-fixed-size-block",
    ],
  ),
  ("layout/container.typ", ["box-baseline-context"]),
  // Imports and includes.
  (
    "scripting/import.typ",
    [
      "import-basic", "import-nested-item", "import-from-file-renamed", "import-source-field-access",
      "import-from-file-items-renamed-mixed", "import-cyclic-in-other-file", "import-file-not-found-invalid",
      "import-from-package-items", "import-from-package-bare",
    ],
  ),
  (
    "scripting/include.typ",
    ["include-file", "include-path", "include-file-not-found"],
  ),
  ("visualize/rect.typ", ["rect-stroke-variations-with-radius"]),
  // Data.
  ("loading/json.typ", ["json", "json-decode-number", "json-invalid"]),
  ("loading/csv.typ", ["csv", "csv-row-type-dict", "csv-file-not-found"]),
  (
    "loading/read.typ",
    ["read-text", "read-through-package", "read-file-not-found"],
  ),
  ("loading/toml.typ", ["toml"]),
  ("loading/yaml.typ", ["yaml"]),
  ("loading/xml.typ", ["xml"]),
  ("loading/cbor.typ", ["cbor-decode-integer"]),
  ("foundations/bytes.typ", ["bytes-basic"]),
  (
    "foundations/plugin.typ",
    [
      "plugin-basic", "plugin-func", "plugin-import", "plugin-transition", "plugin-error",
    ],
  ),
  (
    "text/raw.typ",
    [
      "raw-syntaxes", "raw-theme", "raw-theme-types", "raw-highlight-cpp", "raw-line-scripting",
    ],
  ),
  (
    "visualize/image.typ",
    [
      "image-png", "image-jpg", "image-sizing", "image-svg-complex", "image-svg-text",
      "image-svg-linked-many-formats", "image-pixmap-rgba8", "image-scaling-methods",
      "image-decode-detect-format", "image-exif-rotation", "image-pdf-basic", "image-pdf-multiple-pages",
      "image-bad-svg",
    ],
  ),
  ("text/coma.typ", ["coma"]),
  // The date.
  ("foundations/datetime.typ", ["datetime-display"]),
  ("model/document.typ", ["document-set-author-date"]),
]

///|
/// The documents of the suite. A test that is not found becomes a document
/// without a main file (which fails to compile: the fresh compilations
/// agree, so the caller checks `missing`).
fn suite_documents(missing : Array[String]) -> Array[Document] {
  let out = []
  for entry in recompile_suite[:] {
    let (rel, names) = entry
    let tests = split_tests(read(suite_dir + "/" + rel))
    for name in names[:] {
      guard tests.iter().find_first(tc => tc.name == name) is Some(tc) else {
        missing.push("suite/\{rel}/\{name}")
        continue
      }
      let main = TestWorld::main_source("tests/suite/" + rel, "").id()
      out.push({
        name: "suite/\{rel}/\{name}",
        flavor: Suite(parse_features(tc.attrs)),
        main,
        base: test_files_load,
        files: [(main, @utf8.encode(tc.body))],
      })
    }
  }
  out
}

///|
/// The documents of this repository: the benchmarks and the projects of
/// `tests/recompile/docs`.
let recompile_repository : ReadOnlyArray[(String, String)] = [
  ("bench/tiny", "bench/tiny.typ"),
  ("bench/long", "bench/long.typ"),
  ("bench/showcase", "bench/showcase.typ"),
  ("project/book", "tests/recompile/docs/book/main.typ"),
  ("project/chain", "tests/recompile/docs/chain/main.typ"),
  ("project/notes", "tests/recompile/docs/notes/main.typ"),
]

///|
/// The same for `--all`: `bench/long.typ` with five times the chapters,
/// which takes five times as long and has nothing else.
let recompile_repository_all : ReadOnlyArray[(String, String)] = [
  ("bench/longer", "bench/longer.typ"),
]

///|
fn repository_documents(missing : Array[String], all : Bool) -> Array[Document] {
  let out = []
  let entries = recompile_repository[:].to_owned()
  if all {
    entries.append(recompile_repository_all[:].to_owned())
  }
  for entry in entries {
    let (name, path) = entry
    if !@fs.path_exists(path) {
      missing.push(name)
      continue
    }
    out.push({
      name,
      flavor: Plain,
      main: project_file(path),
      base: repository_load,
      files: [],
    })
  }
  out
}

///|
/// The documents with real packages of the default run: a deck (touying:
/// state, counters and many closure calls), a book template with a
/// bibliography (ilm) and a plugin that reads a Markdown file (cmarker).
let recompile_packages : ReadOnlyArray[String] = [
  "touying/minimal-default", "ilm/glasshouse-notes", "cmarker/allotment-notes",
]

///|
/// The documents with real packages: those of [recompile_packages], or
/// with `all` every document of the `packages` stage.
fn package_documents(missing : Array[String], all : Bool) -> Array[Document] {
  let names = if all {
    packages_cases().map(c => "\{c.0}/\{c.1}")
  } else {
    recompile_packages[:].to_owned()
  }
  let out = []
  for name in names {
    let path = name + ".typ"
    if !@fs.path_exists(packages_docs_dir + "/" + path) {
      missing.push("packages/" + name)
      continue
    }
    out.push({
      name: "packages/" + name,
      flavor: Packages,
      main: project_file(path),
      base: packages_files_load,
      files: [],
    })
  }
  out
}
