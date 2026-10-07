# typst.mbt

A port of the [Typst](https://github.com/typst/typst) typesetting engine to
MoonBit. See [PLAN.md](PLAN.md) for scope, architecture and status.

## Layout

| Path | Contents |
| --- | --- |
| `syntax/` | Port of `typst-syntax`: lexer, parser, syntax nodes, spans, `Lines`, paths and file ids (`path.rs`), packages and manifests (`package.rs`) |
| `syntax/ast/` | Typed AST over the syntax tree (`ast.rs`) |
| `unicode/` | Unicode property tables generated from the Rust crates upstream uses |
| `codecs/` | Image codecs upstream gets from crates: PNG decode/encode (`png`, `fdeflate`), JPEG/GIF/WebP headers (`zune-jpeg`, `gif`, `image-webp`), EXIF (`kamadak-exif`), inflate |
| `svg/` | Port of `typst-svg` (so far: `WebImage` data URLs) |
| `oracle/` | Rust crate dumping upstream reference outputs (goldens) |
| `tests/runner/` | Differential runner comparing the port against the goldens |
| `tests/packages/` | Documents that use real packages of the Typst package registry (pinned in `manifest.tsv`), for the `packages` stage |
| `kit/`, `kit/platform/` | Port of `typst-kit` (files, packages, fonts, diagnostics) and OS access for native and wasm |
| `cli/` | Port of `typst-cli`: the `typst` command line |
| `typst_assets/fonts/` | The fonts embedded into the CLI (generated) |
| `doc/fonts/` | IBM Plex Sans, the sans-serif family of the EDSL's worlds (generated the same way; the CLI does not load it) |
| `scripts/` | `upstream.sh` (pinned checkout), `goldens.sh` (regenerate goldens) |

## Command-line interface

`cli/` is a port of `typst-cli` (on `kit/`, a port of `typst-kit`) that
compiles documents from the file system. It builds for `native`, `wasm-gc`
and `wasm` (the wasm builds run in `moonrun`):

```sh
moon run cli --target native --release -- compile input.typ output.pdf
moon run cli --target wasm-gc -- compile input.typ 'page-{p}.svg'
moon run cli --target native -- compile --format html --features html in.typ
moon run cli --target native -- eval 'query(heading).len()' --in input.typ
moon run cli --target native -- fonts --variants
moon run cli --target native --release -- watch input.typ output.pdf
```

Supported: `compile`/`c` (PDF, PNG, SVG, HTML, bundle; `--root`, `--input`,
`--font-path`, `--ignore-system-fonts`, `--ignore-embedded-fonts`,
`--pages`, `--ppi`, `--pretty`, `--pdf-standard`, `--pdf-tagged`,
`--creation-timestamp`/`SOURCE_DATE_EPOCH`, `--features`, `--deps`,
`--diagnostic-format`, `-` for stdin/stdout), `watch`/`w` (native and wasm;
`--no-fullscreen`), `eval`, `query`, `fonts`,
`info`, `init` (templates from local package directories) and the
environment variables of upstream. Packages are served from the package
data (`@local`, …) and cache directories; downloading packages from Typst
Universe, `update`, `completions`, `--open`, `--timings` and the HTTP
server of `watch` for HTML export (pass `--no-serve`) are
not supported; `--jobs` is accepted for compatibility and has no effect
(compilation is single-threaded). The embedded fonts are those of upstream
(Libertinus Serif,
New Computer Modern, DejaVu Sans Mono). On wasm, system font discovery
reads every font file through moonrun's host API (slow; use
`--ignore-system-fonts`), symlinks cannot be detected, the local time zone
is UTC and only text can be written to stdout.

`watch` recompiles when a file that the last compilation read changes
(sources, imported and included files, data files, images, package files),
is replaced, removed or created, like upstream's, and prints the same
status. Every recompilation starts from scratch (upstream reuses the
results of the previous one). It watches files through
[`moonbitlang/async`](https://github.com/moonbitlang/async), which only
the CLI links: the wasm-gc build has no file system events and reports
that `watch` is not supported. On macOS a watched file is an open file
(kqueue): the native build raises its limit of open files to the hard
limit, the wasm build runs with the limit of the shell (`ulimit -n`). On
Linux every directory with watched files takes an inotify instance
(`fs.inotify.max_user_instances`). The directory of a watched file must be
readable. The wasm build cannot tell a symbolic link: it does not notice
when the file that a link points to is replaced (written in place, it
does).

## Documents as MoonBit code (experimental)

The `doc` package builds documents with typed MoonBit constructors and
compiles them with the same engine, without Typst markup. The API is
experimental and may change between releases; the design is in
`docs/edsl-design.md`.

```moonbit
fn report() -> @doc.Document {
  @doc.Document([
    @doc.SetPage(paper="a5", margin=@doc.Sides(all=@doc.Cm(1.8))),
    @doc.SetHeading(numbering=@doc.Numbering("1.")),
    @doc.Heading("Build times"),
    (
      $|Running text is a multiline string; inline elements such as
      $|\{@doc.Emph("emphasis")} and \{@doc.Raw("code")} are interpolated.
    )
    |> @doc.Prose,
    @doc.Equation("sum_(k=1)^n k = (n(n+1))/2", block=true),
  ])
}

fn run() -> Unit raise {
  let world = @system.world(root=".", system_fonts=false, today=(2026, 10, 5))
  let compiled = report().compile_paged(world)
  @system.write("report.pdf", compiled.pdf().unwrap())
}
```

Import `moonbitlang/typst/doc` and `moonbitlang/typst/doc/system` (file
and font access). Plain strings are literal text and are never parsed as
markup; `Markup(..)` and `Equation(..)` are the explicit escape hatches.
Besides Typst's embedded fonts the worlds of the EDSL have a sans-serif
family, IBM Plex Sans (`SetText(font=["IBM Plex Sans"])`).

`compiled.review_html()` writes a self-contained preview page for
reviewing a document: clicking or selecting rendered text shows the MoonBit
call that produced it (file, line, and the source characters for string
literals and `Prose` blocks), a comment can be attached, and the packaged
feedback copied for the author. `Keyed(key, ..)` names the data row of
loop-built content. See `docs/edsl-review.md`.

## Testing

```sh
scripts/upstream.sh            # checkout upstream at UPSTREAM_REV
scripts/goldens.sh             # needs Rust; or `scripts/goldens.sh syntax ast`
moon run tests/runner --target native -- syntax [filter] [-v]
moon run tests/runner --target native -- ast [filter] [-v]
```

The stages (`scripts/ci/stages.tsv` lists them with their case counts, and
`scripts/ci/stages.py` runs them all): `syntax`, `ast`, `reparse`, `eval`,
`realize`, `html`, `bundle`, `paged` (laid-out frames), `svg`, `svg-replay`,
`pdf-semantic`, `pdf-semantic-replay`, `pdftags`, `render`, `font`, `shape`,
`shape-hb`, `break`, `usvg`, `usvg-images`, `resvg`, `wasm-validate`,
`wasm-spec`, `edsl` and `packages`. Most of them run on upstream's own test
suite (some on the suites of the crates upstream uses). `packages` compiles documents that use real packages of the
Typst package registry (touying, cetz, fletcher, codly, glossarium, mitex,
cmarker, templates, ...; see [tests/packages](tests/packages/README.md)) and
compares frames, SVG and diagnostics with upstream:

```sh
scripts/packages.sh            # fetch the pinned packages into .repos/typst-packages
scripts/goldens.sh packages    # needs Rust
moon run tests/runner --target native --release -- packages [filter] [-v]
scripts/packages_cli.py        # the same through the two CLIs: stderr, PNG pixels, times
```
