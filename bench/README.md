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

What an edit of a source costs (`Source::edit`, `Source::replace`, beside
a parse) is measured by `moon run tests/edit_bench --target native
--release`; its header says how to count the allocations of one edit.

What a PDF export costs, and the next one in the same process (what
`typst watch` pays after every edit), is measured by `tests/pdf_bench`: it
compiles and exports a document several times and prints the two times of
every round. The document for it is an image deck, which is not in the
repository but generated: `mkdeck.py` writes 28 screenshots of 1440 x 900
pixels, half of them with an alpha channel, on 43 pages.

```sh
python3 bench/mkdeck.py _build/deck
moon run tests/pdf_bench --target native --release -- _build/deck/deck.typ 3
```

[hyperfine]: https://github.com/sharkdp/hyperfine
