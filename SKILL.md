---
name: typst
description: Compile Typst documents to PDF, PNG, SVG or HTML, evaluate Typst expressions, inspect document metadata, list fonts, or initialize local templates using the MoonBit port of Typst through moonx.
---

# typst.mbt

Use `moonx moonbitlang/typst/cli -- ...` to run the MoonBit port of Typst.
Do not assume a separately installed `typst` executable is this port.

| Command | Use |
| --- | --- |
| `moonx moonbitlang/typst/cli -- compile input.typ output.pdf` | Compile to PDF. |
| `moonx moonbitlang/typst/cli -- compile input.typ 'page-{p}.png' --ppi 144` | Render each page as PNG. |
| `moonx moonbitlang/typst/cli -- compile input.typ 'page-{p}.svg'` | Export each page as SVG. |
| `moonx moonbitlang/typst/cli -- compile input.typ output.html --features html` | Export HTML with the experimental HTML feature. |
| `moonx moonbitlang/typst/cli -- watch input.typ output.pdf --no-fullscreen` | Recompile when input dependencies change. |
| `moonx moonbitlang/typst/cli -- eval '1 + 2'` | Evaluate a Typst expression; output defaults to JSON. |
| `moonx moonbitlang/typst/cli -- eval 'query(heading)' --in input.typ` | Extract document metadata; prefer this to the deprecated `query` command. |
| `moonx moonbitlang/typst/cli -- fonts --variants` | List available font families and variants. |
| `moonx moonbitlang/typst/cli -- init '@local/template:0.1.0' ./report` | Create a project from a template already present in local package directories. |
| `moonx moonbitlang/typst/cli -- info --format json` | Print build and environment information. |
| `moonx moonbitlang/typst/cli -- compile --help` | Inspect compile options; replace `compile` to inspect another command. |

`compile` and `watch` have aliases `c` and `w`. The output extension selects
the format; without an output path, compilation writes a PDF beside the input.
Use `--format` when the path does not identify the format. Multi-page PNG and
SVG export needs a page placeholder: `{p}` for the page number or `{0p}` for a
zero-padded number; `{t}` adds the total page count. Quote these paths in the
shell. Use `--pages 1` to export just one page to a plain image filename.

## Common options

Pass these after the subcommand where applicable:

| Option | Meaning |
| --- | --- |
| `--root <DIR>` | Set the project root used to resolve Typst's absolute paths. |
| `--input key=value`, `-i key=value` | Add a string to `sys.inputs`; repeat for multiple keys. |
| `--font-path <DIR>` | Recursively search an additional font directory. |
| `--ignore-system-fonts` | Skip system font discovery; explicit `--font-path` directories are still searched. |
| `--ignore-embedded-fonts` | Exclude the embedded fonts. |
| `--package-path <DIR>` | Set the local package directory. |
| `--package-cache-path <DIR>` | Set the package cache directory. |
| `--pages '1,3-5'` | Export selected physical pages, numbered from 1. |
| `--ppi <NUMBER>` | Set PNG resolution; defaults to 144. |
| `--creation-timestamp <SECONDS>` | Set the creation date as a Unix timestamp; also available through `SOURCE_DATE_EPOCH`. |
| `--pdf-standard <STANDARD>` | Request a PDF version or conformance standard; consult `compile --help` for values. |
| `--pdf-tagged=false` | Disable PDF tagging; `--pages` implies this and cannot be combined with `--pdf-tagged=true`. |
| `--deps <PATH>` | Write compilation dependencies; `--deps-format` accepts `json`, `zero` or `make`. |
| `--diagnostic-format short` | Emit compact compiler diagnostics. |

For `eval`, use `--format json`, `yaml` or `raw`; `raw` accepts only strings
and bytes, and `--pretty` formats JSON. Quote expressions to keep the shell
from interpreting them.

## Fonts, packages and runtime limits

`moonx` runs this CLI on Wasm. System font discovery can be slow because it
reads every font file through the host API. Use `--ignore-system-fonts` when
embedded fonts suffice, or combine it with `--font-path ./fonts` for explicit
fonts. Embedded families are Libertinus Serif, New Computer Modern and
DejaVu Sans Mono. Supply suitable fonts for scripts these do not cover.

Package downloads from Typst Universe are not implemented. Imports and `init`
require packages already present under the package or cache directory, in
`<namespace>/<name>/<version>/` layout. `init` refuses an existing destination.

The upstream help also lists options this port does not implement:
`--open`, `--timings`, `update` and `completions`. Compilation is single-threaded;
`--jobs` is accepted but has no effect. HTML watching requires `--no-serve`
because the built-in HTTP server is unavailable.

On Wasm, stdout supports text only: write PDF and PNG to files. `-` can read
Typst source from stdin; specify an output path when doing so. The local time
zone is UTC, and file watching cannot detect replacement of a symlink's target.
