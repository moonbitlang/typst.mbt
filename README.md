# typst.mbt

A port of the [Typst](https://github.com/typst/typst) typesetting engine to
MoonBit. See [PLAN.md](PLAN.md) for scope, architecture and status.

## Layout

| Path | Contents |
| --- | --- |
| `syntax/` | Port of `typst-syntax`: lexer, parser, syntax nodes, spans |
| `unicode/` | Unicode property tables generated from the Rust crates upstream uses |
| `oracle/` | Rust crate dumping upstream reference outputs (goldens) |
| `tests/runner/` | Differential runner comparing the port against the goldens |
| `scripts/` | `upstream.sh` (pinned checkout), `goldens.sh` (regenerate goldens) |

## Testing

```sh
scripts/upstream.sh            # checkout upstream at UPSTREAM_REV
scripts/goldens.sh syntax      # needs Rust
moon run tests/runner --target native -- syntax [filter] [-v]
```
