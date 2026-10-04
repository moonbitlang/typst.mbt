# Benchmarks

Documents for comparing the MoonBit CLI (`cli/`) with upstream Typst:

| File | Contents |
| --- | --- |
| `tiny.typ` | one line of text (process startup, font discovery) |
| `long.typ` | 24 pages: outline, numbered headings, justified lorem, math, tables |
| `longer.typ` | `long.typ` with 5× the chapters (for profiling) |
| `showcase.typ` | images (JPEG, SVG, PDF), bibliography, gradients, Arabic and Chinese text (uses the macOS system fonts Geeza Pro and PingFang SC) |

`run.sh` builds the native release CLI and runs [hyperfine] for each
workload against the upstream binary (`.repos/typst/target/release/typst`,
or `$TYPST_RS`; run single-threaded with `--jobs 1`):

```sh
bench/run.sh                     # all but longer
bench/run.sh --no-build compile  # just `query long.typ heading`
bench/run.sh --runs 20 pdf svg
```

Workloads: `startup` (`tiny.typ` → PDF), `compile` (`query long.typ
heading`: compile without export), `pdf`, `svg`, `png` (`long.typ` to one
file per page), `showcase` (→ PDF, with system fonts), `showcase-png`
(→ PNG: JPEG decoding, image resampling, PDF and SVG images), `longer`.
All but the showcase pass `--ignore-system-fonts`, so only the embedded
fonts are used.

To profile, run e.g. `moon run --profile --target native --release cli --
query --ignore-system-fonts bench/longer.typ heading` (macOS: needs Xcode's
`xctrace`).

[hyperfine]: https://github.com/sharkdp/hyperfine
