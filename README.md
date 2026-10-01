# typst.mbt

A port of the [Typst](https://github.com/typst/typst) typesetting engine to
MoonBit. See [PLAN.md](PLAN.md) for scope, architecture and status.

## Layout

| Path | Contents |
| --- | --- |
| `syntax/` | Port of `typst-syntax`: lexer, parser, syntax nodes, spans, `Lines` |
| `syntax/ast/` | Typed AST over the syntax tree (`ast.rs`) |
| `syntax/package/` | Package specifications (`package.rs`, without the manifest) |
| `unicode/` | Unicode property tables generated from the Rust crates upstream uses |
| `oracle/` | Rust crate dumping upstream reference outputs (goldens) |
| `tests/runner/` | Differential runner comparing the port against the goldens |
| `scripts/` | `upstream.sh` (pinned checkout), `goldens.sh` (regenerate goldens) |

## Testing

```sh
scripts/upstream.sh            # checkout upstream at UPSTREAM_REV
scripts/goldens.sh             # needs Rust; or `scripts/goldens.sh syntax ast`
moon run tests/runner --target native -- syntax [filter] [-v]
moon run tests/runner --target native -- ast [filter] [-v]
```
