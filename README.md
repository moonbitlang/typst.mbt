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
| `kit/`, `kit/platform/` | Port of `typst-kit` (files, packages, fonts, diagnostics) and OS access for native and wasm |
| `cli/` | Port of `typst-cli`: the `typst` command line |
| `typst_assets/fonts/` | The fonts embedded into the CLI (generated) |
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
```

Supported: `compile`/`c` (PDF, PNG, SVG, HTML, bundle; `--root`, `--input`,
`--font-path`, `--ignore-system-fonts`, `--ignore-embedded-fonts`,
`--pages`, `--ppi`, `--pretty`, `--pdf-standard`, `--pdf-tagged`,
`--creation-timestamp`/`SOURCE_DATE_EPOCH`, `--features`, `--deps`,
`--diagnostic-format`, `-` for stdin/stdout), `eval`, `query`, `fonts`,
`info`, `init` (templates from local package directories) and the
environment variables of upstream. Packages are served from the package
data (`@local`, …) and cache directories; downloading packages from Typst
Universe, `watch`, `update`, `completions`, `--open` and `--timings` are
not supported. The embedded fonts are those of upstream (Libertinus Serif,
New Computer Modern, DejaVu Sans Mono). On wasm, system font discovery
reads every font file through moonrun's host API (slow; use
`--ignore-system-fonts`), symlinks cannot be detected, the local time zone
is UTC and only text can be written to stdout.

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
