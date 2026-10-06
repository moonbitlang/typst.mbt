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

  | workload | Rust | before | memoized | ReadOnlyArray | allocations | v128 | deflate | now vs Rust |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|
  | `--version` (process startup only) | 4.8 ms | | 6.7 ms | 3.5 ms | | | | 0.7× |
  | startup (`tiny.typ` → PDF) | 7.7 ms | 80 ms | 22.7 ms | 19.5 ms | 18.0 ms | 18.2 ms | | 2.3× |
  | `long.typ` compile (`query`) | 102 ms | 1.32 s | 315 ms | 305 ms | 225 ms | 227 ms | | 2.2× |
  | `long.typ` → PDF | 119 ms | 1.45 s | 451 ms | 431 ms | 352 ms | 356 ms | | 3.0× |
  | `long.typ` → SVG | 183 ms | 1.98 s | 479 ms | 457 ms | 377 ms | 381 ms | | 2.1× |
  | `long.typ` → PNG (24 pages) | 913 ms | 5.32 s | 2.68 s | 2.65 s | 2.58 s | 1.25 s | 976 ms | 1.06× |
  | `showcase.typ` → PDF (system fonts) | 287 ms | 2.25 s | 1.35 s | 1.30 s | 1.30 s | 1.21 s | | 4.2× |
  | `showcase.typ` → PNG (system fonts) | 540 ms | | | | 1.60 s | 1.06 s | 1.02 s | 1.9× |
  | `longer.typ` compile | 481 ms | 6.58 s | 1.56 s | 1.51 s | 1.12 s | | | 2.3× |

  "v128" (2026-10-04, hyperfine side by side with "allocations" = main at
  bfdf8ca and Rust): the SIMD export kernels (AGENTS.md: v128 kernels):
  zlib loads/`compare256`/adler32, PNG filters, demultiply, JPEG
  IDCT/YCbCr/up-sampling, image resampling, pic_scale, vello_cpu
  compositing, plus pixglyph's `#valtype` `Point` (curve flattening
  allocated a dozen points per step) and fewer deflate allocations. PDF/SVG of `long.typ` do not
  reach them (unchanged within noise). The same documents on the wasm
  targets (`moonrun`, `--ignore-system-fonts`; wasm-gc and js keep the
  scalar kernels, `@v128` is emulated there):

  | workload | wasm before | wasm v128 | wasm deflate | wasm-gc before | wasm-gc v128 | wasm-gc deflate |
  |---|---:|---:|---:|---:|---:|---:|
  | `long.typ` → PNG | 7.57 s | 4.20 s (4.00 s) | 2.98 s | 4.80 s | 4.24 s (4.27 s) | 4.10 s |
  | `showcase.typ` → PNG | 6.17 s | 2.81 s (2.69 s) | 2.61 s | 2.80 s | 2.08 s (2.04 s) | 2.05 s |

  "deflate" (2026-10-04, hyperfine side by side with "v128" = main at
  fd575dd, in parentheses on wasm, and Rust): the zlib-rs port's hash
  tables as `u16` like upstream (half the cache footprint; on wasm a byte
  array with a v128 `slide_hash`), no tuple allocations per match and no
  `Bytes` copies per row, the braided CRC-32 of zlib-rs, `compress_block` with the bit
  buffer in locals, `fizzle_matches` bounded up front, the adaptive filter
  keeping its best row, and pixglyph's float helpers inlined.
  `encode_png_balanced` of three `long.typ` pages: 85 -> 60 ms (png 0.18.1
  + zlib-rs 0.6.8 in Rust: 54 ms); rasterizing 1405 glyphs: 10.7 -> 9.1 ms
  (pixglyph: 7.2 ms). `long.typ` → PNG now spends less time exporting than
  upstream; the remaining gap is the compilation. The upstream binary in
  `.repos/typst` locks zlib-rs 0.5.1 (the oracle 0.6.8, which the port and
  the goldens follow), so its PNGs differ from ours in the deflate stream
  only. The showcase is dominated by system font scanning and JPEG
  decoding, not the PNG path.

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

  "allocations" (2026-10-04, hyperfine side by side with "ReadOnlyArray"
  and Rust): fewer allocations and refcounting in the compile path (see
  the allocation note in AGENTS.md): `query long.typ heading` allocates
  7.7M objects instead of 15.9M, and memory management (malloc, drop,
  cycle scan) fell from 36% of the samples (1120 of 3110 for 120
  chapters of `longer.typ`) to 28% (648 of 2291).

  Remaining hot spots: allocation/RC (~28% of compile: frames, content and
  values, style casts, rustybuzz lookups), line breaking and
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
- [x] Location keys (`prepare` in `realize/`: `hash128(elem)`, as upstream)
  use the port's fingerprints (`library/value_hash.mbt`,
  `library/visualize_hash.mbt`), which now cover what upstream's `Hash`
  covers for every value: gradients (stops, geometry, space, relative,
  anti-aliasing), tilings (the laid-out frame: groups, text items with
  glyphs and spans, shapes, images, links, tags; hashed once per tiling),
  strokes and the other dynamic values (spot colorants, paths, CSS), colours
  (component bits), symbols (all variants, also those ruled out by the
  applied modifiers), modules (whole scope, hashed once per module) and
  closures (the syntax tree, defaults, captured bindings with spans and
  kinds, hashed once per closure). No `Fingerprint` marks itself lossy
  anymore, so memoized results with such values in recorded reads are
  replayed across introspectors, and laid-out frames with tiling paints are
  reused. Two located elements that are equal including their spans and
  differ only in such a value used to share a key where upstream's differ,
  which measurement observes (`Introspector::locator`):
  `typst/oracle_wbtest.mbt` (`scripts/gen_typst_oracle.py`, group "location
  keys") records upstream's answers, e.g. 10pt, 20pt, 30pt for
  `(1.001pt, 1.002pt, 1.003pt).map(s => [#rect(stroke: s)<r>])` under
  `#show <r>: it => context box(width: c.at(it.location()).first() * 10pt)`
  (10pt three times before), and closures of one `eval` call with the same
  text but different trees. Remaining differences in kind, not in what is
  told apart: the hash values are not upstream's (payload encodings; only
  the SVG exporter's inputs are byte-exact), decimals, alignments and
  directions are written as their repr plus the builtin 32-bit hash
  (`write_leaf`; these reprs show all data, unlike those of symbols,
  datetimes and durations, which are hashed structurally), native
  functions by name, title and docs (upstream: identity;
  `typst/fingerprint_wbtest.mbt` checks they are distinct), the
  documentation of a captured library binding lacks upstream's `since`,
  `keywords` and `def_site` (not ported; name, title and docs are hashed),
  and frames have no `LazyHash` (they are mutable; a frame is hashed per
  call, owners cache). The caches (`LazyFingerprint`) rely on closures,
  modules and tiling frames not being modified after they were built, which
  holds for evaluation but is not enforced by the public API.
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
  moonbitlang/office.mbt #591–#594 and ship in pdflite 0.3.4; font subsetting (subsetter 0.2.6 port, #598)
  ships in pdflite 0.3.5, which typst.mbt now imports from mooncakes (no sibling checkout needed; an
  untracked `moon.work` can still link a local office.mbt).
- [ ] Bump `moonbit-community/flate` 0.8.1 → 0.8.4 in pdflite (faster);
  requires regenerating three byte-pinned fixtures (pdflite flate
  determinism test, a docx2html cram fixture, an mbtexcel snapshot).

### Housekeeping
- [x] Leftover agent worktrees and merged branches removed (2026-10-03).
