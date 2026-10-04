# TODO

Status (2026-10-03): the port is complete for the upstream test suite. Every
differential stage matches upstream Typst (pinned in `UPSTREAM_REV`). See `PLAN.md` for the phase table and
`docs/p2-architecture.md`, `docs/p3-plan.md`, `docs/p4-plan.md` for design
and per-unit status. Conventions and pitfalls for contributors (and agents)
are in `AGENTS.md` — read it first.

| Stage | Result |
|---|---|
| syntax / ast / reparse | 3792/3792 |
| eval | 3792/3792 |
| realize | 3792/3792 |
| html | 508/508 |
| paged / svg / pdf-semantic / render | 2299/2299 each |
| pdftags / bundle | 133/133, 39/39 |
| font / shape / shape-hb / break / resvg / usvg | 100% |
| wasm-spec / wasm-validate | 64207/64207 (260 files; 1242 text modules skipped), 14027/14027 |
| unit tests (`moon test --target native -j16`) | 8096/8096 |

Run a stage: `moon run tests/runner --target native [--release] -- <stage>`
(use `--release` for paged/svg/render/pdf-semantic sweeps). Regenerate
goldens with `scripts/goldens.sh <stage>` (needs Rust; builds `oracle/`).

## Open work

### Features
- [x] **WASM plugins** (`library/plugin.mbt` on `wasmparser/`, `wasmi/`,
  `wasmi/core/`, `wasmi/ir/`; see AGENTS.md). Remaining: the executor is
  ~2.2-2.6x slower than upstream wasmi on plugin-heavy documents (boxed
  `Op` enum; a packed instruction encoding would close most of the gap).
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
- [ ] **Performance** (`bench/run.sh`, `bench/README.md`; M-series Mac,
  native release, embedded fonts only, upstream `--jobs 1`; 2026-10-04):

  | workload | Rust | before | memoized | ReadOnlyArray | v128 | now vs Rust |
  |---|---:|---:|---:|---:|---:|---:|
  | `--version` (process startup only) | 4.8 ms | | 6.7 ms | 3.5 ms | | 0.7× |
  | startup (`tiny.typ` → PDF) | 6.9 ms | 80 ms | 22.7 ms | 19.9 ms | 20.0 ms | 2.9× |
  | `long.typ` compile (`query`) | 103 ms | 1.32 s | 315 ms | 299 ms | 299 ms | 2.9× |
  | `long.typ` → PDF | 118 ms | 1.45 s | 451 ms | 418 ms | 428 ms | 3.6× |
  | `long.typ` → SVG | 178 ms | 1.98 s | 479 ms | 445 ms | 444 ms | 2.5× |
  | `long.typ` → PNG (24 pages) | 941 ms | 5.32 s | 2.68 s | 2.66 s | 1.37 s | 1.45× |
  | `showcase.typ` → PDF (system fonts) | 277 ms | 2.25 s | 1.35 s | 1.31 s | 1.20 s | 4.3× |
  | `showcase.typ` → PNG (system fonts) | 541 ms | | | 1.58 s | 1.06 s | 2.0× |
  | `longer.typ` compile | 478 ms | 6.58 s | 1.56 s | 1.56 s | | 3.3× |

  The "v128" column (2026-10-04, side by side with "ReadOnlyArray" = main
  at d6cd58c, re-measured) adds the SIMD export kernels (AGENTS.md: v128
  kernels): zlib loads/`compare256`/adler32, PNG filters, demultiply,
  JPEG IDCT/YCbCr/up-sampling, image resampling, pic_scale, vello_cpu
  compositing, plus pixglyph's `#valtype` `Point` and fewer deflate
  allocations. PDF/SVG of `long.typ` do not reach them. The same documents
  on the wasm targets (`moonrun`, `--ignore-system-fonts`):

  | workload | wasm before | wasm v128 | wasm-gc before | wasm-gc now |
  |---|---:|---:|---:|---:|
  | `long.typ` → PNG | 7.91 s | 4.42 s | 4.76 s | 4.54 s |
  | `showcase.typ` → PNG | 6.18 s | 2.75 s | 2.77 s | 2.10 s |

  (wasm-gc and js keep the scalar kernels: `@v128` is emulated there.)

  ("memoized" and "ReadOnlyArray" re-measured side by side on 2026-10-04,
  hyperfine, runs interleaved.) Constant tables as static `ReadOnlyArray`
  data (see AGENTS.md) shrank `moonbit_init` from 343k to 21k lines of C;
  building the hayro font maps and the 64K premultiplication table at
  startup had cost ~2.5 ms per process. Sizes and build times (release):

  | | before | ReadOnlyArray |
  |---|---:|---:|
  | native `cli.exe` | 61.62 MB | 61.19 MB |
  | – `__text` (code) | 17.20 MB | 16.08 MB |
  | – `__data` (static tables) | 0.83 MB | 1.84 MB |
  | generated `cli.c` | 255.4 MB | 233.3 MB |
  | wasm `cli.wasm` | 55.31 MB | 53.53 MB |
  | wasm-gc `cli.wasm` | 52.56 MB | 52.53 MB |
  | clean native build | 274 s | 150 s |
  | clean wasm-gc / wasm build | 18 s / 21 s | 19 s / 19 s |

  Caveat: clang inlines core's `StringBuilder::write_string` (cost 215,
  threshold 225) into all ~7.4k callers depending on unrelated changes
  elsewhere in the program, which moves `__text` by ±1.8 MB between builds.

  Remaining hot spots: allocation/RC (~35% of compile), line breaking and
  shaping (rustybuzz port), style-chain lookups (values are cast from
  `Value` on every read), grid layout; PDF: pdflite's flate (font streams);
  PNG: zlib-rs' `deflate_medium` (hash chains, scalar; ~55% of `long.typ`
  → PNG), pixglyph's line rasterization, crc32 (no PMULL in `@v128`);
  showcase: system font discovery (parses every installed face) and
  pdflite's flate (font and image streams, most of its PDF export). Not
  done: lazy embedded `FontInfo` (startup), memoizing the state sequence
  (closure identity, see AGENTS.md), typed style caches.
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

### office.mbt (pdflite, published on mooncakes)
- [x] **Push/publish**: the export package and its follow-ups landed in
  moonbitlang/office.mbt #591–#594 and ship in pdflite 0.3.4, which
  typst.mbt now imports from mooncakes (no sibling checkout needed; an
  untracked `moon.work` can still link a local office.mbt).
- [ ] Bump `moonbit-community/flate` 0.8.1 → 0.8.4 in pdflite (faster);
  requires regenerating three byte-pinned fixtures (pdflite flate
  determinism test, a docx2html cram fixture, an mbtexcel snapshot).

### Housekeeping
- [x] Leftover agent worktrees and merged branches removed (2026-10-03).
