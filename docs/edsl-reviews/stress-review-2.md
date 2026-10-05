The original counterexamples are fixed, but findings 4 and 6 remain incomplete.

- **MAJOR — [tests/runner/edsl_stage.mbt:177](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/edsl_stage.mbt:177): dictionary encoding still permits false equality.** `#metadata(("a: 1, b": 2))` and `#metadata((a: 1, b: 2))` both dump as `(a: 1, b: 2)`. Queries differ; upstream SVG/PDF/PNG bytes are identical. **Fix:** encode keys with `@library.repr_str(key)` and add this comparator regression.

- **MAJOR — [tests/runner/edsl_suite.mbt:513](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/tests/runner/edsl_suite.mbt:513): empty selections still pass vacuously.** With a populated registry, `edsl-suite __review_no_such_case_580d2a5__` returned exit 0 and `0 passed, 0 failed`. Missing corpus enumeration can likewise escape detection; §8’s manifest validation remains absent. **Fix:** reject zero selected cases and validate selected case identities against the manifest and registry.

- **MINOR — [doc/convert/translate.mbt:381](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/convert/translate.mbt:381): the new wrapper is unbound in generated packages.** `a#"b"c` with `--prose` emits `Content("b")`, but neither generated import list includes `Content`. The regenerated manifest records this compilation failure for `show-text-regex-case-insensitive`. **Fix:** emit `@doc.Content(...)`, or add `Content` to both import lists.

- **MINOR — [doc/convert/code.mbt:267](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/convert/code.mbt:267): inserted strings still share origins.** `#"a"<x><y>#"b"<z><w>` produces two upstream “content labelled multiple times” warnings; translated bare strings share the array span, collapsing them to one. **Fix:** emit `Lit(...)` for string literals and translated string variables in `Tr::content`; keep argument translation separate.

- **MINOR — [doc/lower.mbt:401](/Users/dii/git/typst.mbt/.claude/worktrees/agent-ab7f0b101467f17ea/doc/lower.mbt:401): argument-span exhaustion still silently reuses the base.** For a base span of length `L`, argument index `16*L` necessarily fails the range guard. A `color.mix` call with that many explicit invalid pairs again loses diagnostics. **Fix:** allocate registered occurrence ranges after exhausting sub-ranges, rather than returning `base`.

Validation: all 16 translator snapshots passed using the existing binary; no fresh rebuild in the read-only workspace.

VERDICT: REQUEST CHANGES
