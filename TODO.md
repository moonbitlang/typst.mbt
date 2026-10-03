# TODO

Status (2026-10-03): the port is complete for the upstream test suite. Every
differential stage matches upstream Typst (pinned in `UPSTREAM_REV`) except
the 10 WASM plugin tests. See `PLAN.md` for the phase table and
`docs/p2-architecture.md`, `docs/p3-plan.md`, `docs/p4-plan.md` for design
and per-unit status. Conventions and pitfalls for contributors (and agents)
are in `AGENTS.md` — read it first.

| Stage | Result |
|---|---|
| syntax / ast / reparse | 3792/3792 |
| eval | 3782/3792 (10 × `foundations/plugin.typ`) |
| realize | 3788/3792 (4 × `foundations/plugin.typ`) |
| html | 508/508 |
| paged / svg / pdf-semantic / render | 2299/2299 each |
| pdftags / bundle | 133/133, 39/39 |
| font / shape / shape-hb / break / resvg / usvg | 100% |
| unit tests (`moon test --target native -j16`) | 7818/7818 |

Run a stage: `moon run tests/runner --target native [--release] -- <stage>`
(use `--release` for paged/svg/render/pdf-semantic sweeps). Regenerate
goldens with `scripts/goldens.sh <stage>` (needs Rust; builds `oracle/`).

## Open work

### Features
- [ ] **WASM plugins** (`foundations/plugin.typ`, 10 eval + 4 realize
  cases): port a WebAssembly runtime equivalent to upstream's `wasmi` plus
  `typst-library/src/foundations/plugin.rs`.
- [x] **CLI and a real file-system `World`** (`cli/`, `kit/`; see README):
  `compile`/`eval`/`query`/`fonts`/`info`/`init` on native, wasm-gc and
  wasm, checked against the upstream CLI. Remaining:
  - [ ] package downloads from Typst Universe (needs an HTTP client; today a
    missing `@preview` package is reported as not found), and `init` of
    unversioned `@preview` templates (needs the package index);
  - [ ] `watch` (needs file system events or polling + sleep), the HTTP
    server, `--open`, `--timings`, `completions`, `update`;
  - [ ] wasm: system font discovery reads whole files byte by byte through
    moonrun's host API (~15 s for macOS' fonts; ranged reads would need a
    host API), no symlink detection (duplicate faces, no cycle protection),
    no local time zone (UTC), no binary stdout, no `realpath`: paths are
    only made absolute (`..` is left to the host), so spellings that differ
    by symlinks (`/etc` vs. `/private/etc`) are not recognized as the same
    root, `..` after a symlink inside an explicit `--root` is resolved
    lexically by `VirtualPath`, and diagnostics may show `dir/../file.typ`
    where native shows `file.typ`;
  - [ ] clap's "similar value/argument" tips in argument errors; colored
    greeting; `--deps` lists dependencies in first-access order (upstream:
    hash map order);
  - [ ] Linux fontconfig: only `<dir>`/`<include>`/`<reset-dirs>` are
    interpreted; Windows support of `kit/platform` is untested and uses the
    narrow (ANSI code page) C file APIs, so non-ASCII paths need wide APIs.
- [x] **PDF image filters in `hayro/syntax`**: DCT (zune-jpeg port in
  `codecs/`), JPX (`hayro/jpeg2000`), JBIG2 (`hayro/jbig2`) and CCITT
  (`hayro/ccitt`); the 36 previously skipped corpus files render and convert
  bit-identically (render/svg oracles). hayro-jbig2's own conformance
  suite (downloaded by its `sync.py`) has not been run; JBIG2 coverage
  comes from the corpus, synthetic fixtures and local PDFs.
- [ ] **skrifa**: no variable-font / CFF2 support (only used by hayro for
  PDF-embedded fonts).

### Quality / performance
- [ ] **Benchmark** against upstream (compile times per stage, memory); use
  `moon run --profile --target native --release`. Known hot spots to watch:
  shaping-face/plan caches (`layout/inline_shaping.mbt`), frame COW, content
  hashing (`library/value_hash.mbt`).
- [ ] **Build times**: the `library` package dominates (serial compile,
  ~80–95 s release rebuild). Consider splitting it into several packages
  along upstream module lines so `-j` parallelizes builds.
- [ ] **Raw hash parity for SVG** is already exact; **PDF** is compared
  semantically (`pdf-semantic`, `pdftags`) — byte parity with krilla is not
  a goal.

### Documented deviations worth revisiting
- [ ] `Derived<S, D>` fields store the source plus an internal
  `<field>-derived` companion (see `scripts/elemgen.py`, `DynValue::Loaded`);
  only image `source`/`icc` use the companion so far — bibliography
  `sources`/`style`, cite `style`, raw `syntaxes`/`theme` and `pdf.attach`
  `path` still re-derive from the source (caches keyed by bytes).
- [ ] `Source` is edited in place (upstream: copy-on-write) — callers that
  need the old tree must `deep_clone`.
- [ ] `sorted()` comparison order differs from upstream's glidesort, so the
  "cannot compare" error can name different values for mixed-type arrays.
- [ ] `int.to-bytes` with sizes > 2³¹ (upstream would try to allocate).
- [ ] Minimal TOML reader in `syntax/toml.mbt` (package manifests) has gaps
  noted in review (repeated table headers, hex/oct/bin ints, CRLF in
  multiline strings, `\u` scalar validation, `[tool]` value validation) —
  switch it to the full `data/toml` port.

### office.mbt (sibling repo `~/git/office.mbt`, used via `moon.work`)
- [ ] **Push/publish**: office.mbt `main` is 11 commits ahead of
  `origin/main` (pdflite `export` package for typst.mbt's PDF exporter:
  glyph-ID text, subsetting, color spaces, shadings, Type 3 glyphs, tagged
  PDF, external XObjects, PNG passthrough; `moonbitlang/x` 0.5.5). Nothing
  has been pushed or published — needs the owner's go-ahead. After
  publishing, typst.mbt can depend on the published pdflite instead of
  `moon.work`.
- [ ] Bump `moonbit-community/flate` 0.8.1 → 0.8.4 in pdflite (faster);
  requires regenerating three byte-pinned fixtures (pdflite flate
  determinism test, a docx2html cram fixture, an mbtexcel snapshot).

### Housekeeping
- [ ] Remove leftover agent worktrees under `.claude/worktrees/` (finished;
  ~18 GB, mostly `_build`), e.g. `git worktree list` then
  `git worktree remove --force <path>` for merged branches.
- [ ] Delete merged local branches (`git branch --merged main`).
