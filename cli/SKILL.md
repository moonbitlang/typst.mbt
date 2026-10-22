---
name: typst
description: Compile Typst documents and inspect their contents using the MoonBit port of Typst through moonx.
---

# typst.mbt

Run this port with `moonx moonbitlang/typst/cli -- ...`. A separately
installed `typst` executable may be a different implementation.
Read the CLI help for commands, arguments and examples:

```sh
moonx moonbitlang/typst/cli -- --help
moonx moonbitlang/typst/cli -- <command> --help
```

## Limits not explained by the upstream help

- `--open`, `--timings`, `update` and `completions` are not implemented.
- Package downloads from Typst Universe are not implemented. Imports and
  `init` require packages already present in local package or cache directories.
- Compilation is single-threaded; `--jobs` is accepted but has no effect.
- HTML watching requires `--no-serve`; the built-in HTTP server is unavailable.
- `moonx` runs this CLI on Wasm, where stdout supports text only. Write PDF
  and PNG output to files.
- On Wasm, system font discovery reads every font file through the host API
  and can be slow. Use `--ignore-system-fonts` when embedded fonts suffice,
  or combine it with `--font-path` for explicit fonts.
- On Wasm, the local time zone is UTC, and file watching cannot detect
  replacement of a symlink's target.
