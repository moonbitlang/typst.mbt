# P2 architecture: library, eval, elements

This document fixes the runtime design for porting `typst-library` and
`typst-eval`. It follows upstream closely; deviations are listed explicitly.

## Packages

One MoonBit package per upstream crate, so the dependency graph matches
upstream and there are no cycles:

| MoonBit package | Upstream crate | Notes |
| --- | --- | --- |
| `syntax`, `syntax/ast` | typst-syntax | done / in progress |
| `library` | typst-library | **one package**: foundations, layout primitives, visualize, text, model, math, introspection, loading. Mutually recursive Value/Content/Styles/elements stay together. |
| `eval` | typst-eval | tree-walking VM |
| `realize` | typst-realize | |
| `layout` | typst-layout | |
| `svg`, `pdf`, `html` | exporters | |
| `typst` | typst | `compile`, `Routines` table, convergence loop |

Upstream's `Routines` (function-pointer table that lets typst-library call
into eval/realize/layout without depending on them) is ported as a struct of
closures, filled in by the `typst` package.

File names inside `library` mirror upstream module paths (`value.mbt`,
`heading.mbt`, ...); on basename collisions (`color.rs`, `item.rs`, `raw.rs`,
`resolve.rs`, `tag.rs`) prefix with the module (`text_raw.mbt`).

## Errors

Upstream result aliases map to MoonBit checked errors:

| Upstream | MoonBit |
| --- | --- |
| `StrResult<T>`, `HintedStrResult<T>` | `T raise HintedError` (message + hints) |
| `SourceResult<T>` | `T raise SourceError` (`Array[SourceDiagnostic]`) |
| `.at(span)` | `at(span, () => ...)` helper converting `HintedError` → `SourceError` |
| `bail!(span, ..)` / `error!` | `raise SourceError([...])` helpers |

Keeping the two error types distinct preserves upstream's static guarantee
that a span is attached before an error reaches the user.

Control flow in the evaluator (`break`/`continue`/`return`) uses the VM's
`FlowEvent` state like upstream, not exceptions.

## Values

`Value` is an enum with the same variants as upstream. Leaf types
(`Length`, `Color`, `Str`, ...) live in `library`. `Value::Dyn` holds a
trait object `&NativeDyn` (repr, eq, hash, ty) for internal native types
(e.g. `Counter`, `State`, `Location`, `Stroke`, `Alignment`).

Typst `str` has UTF-8 byte-index semantics: `Str` wraps a MoonBit `String`
plus byte-offset helpers; all user-visible indices (`len`, `at`, `slice`,
`position`, regex match offsets) are bytes. Graphemes come from `unicode`.

### Casting

Upstream's `Reflect`/`FromValue`/`IntoValue` traits become MoonBit traits
with static methods (`T::input()`, `T::from_value(v)`), including generic
impls (`Option[T]`, `Smart[T]`, `Array[T]`, `Sides[T]`, ...). `CastInfo`
is ported verbatim because its `error()` produces the "expected X or Y,
found Z" messages the test suite checks. `cast!` blocks are ported by hand,
using `gen/manifest.json` as the checklist.

## Elements and Content (generated)

`scripts/elemgen.py` reads `gen/manifest.json` plus a Rust→MoonBit type map
and generates `library/*_gen.mbt`:

* One struct per element with upstream field semantics:
  required → `T`, synthesized → `T?`, settable → `T?` (unset = `None`),
  ghost/external fields have no storage.
* `Content` = shared header (span, label, location, lifecycle bitset) +
  `ElemData`, a closed enum with one variant per element (Codex review:
  typed payloads instead of Value-backed fields; closed because MoonBit has
  no `Any` downcasting). `content.to_packed_heading()` etc. replace
  `Packed<E>` downcasts.
* An `Element` descriptor per element (name, title, field table with
  `CastInfo`, defaults, flags, capability flags, local names, scope) and the
  generic glue: `field_by_id`/`field_by_name` (→ `Value`), `set_field`,
  `has`, `materialize`, `fields()`, `repr`, equality/hash.
* `construct`/`set` from `Args` exactly as the macro generates them
  (`args.expect`/`find`/`named`/`all`), unless the element has a custom
  `Construct`/`Set` capability, in which case a handwritten hook is called.
* Style properties: `Property { elem, id, value : PropValue, span,
  liftable, outside }` where `PropValue` is a generated closed enum with one
  variant per distinct settable field type, so `StyleChain` getters are
  typed and need no casts. `#[fold]` fields fold through a `Fold` trait.
* Capabilities (`Show`, `ShowSet`, `Synthesize`, `LocalName`, `Locatable`,
  `Tagged`, `Count`, `Refable`, `Outlinable`, `Mathy`, ...) are flags in the
  descriptor plus handwritten function-pointer hooks registered per element.

Functions (`#[func]`) and types (`#[ty]`, `#[scope]`) are generated the same
way: a `NativeFuncData` with param infos (name, CastInfo, named, variadic,
default) and a closure that pulls typed args via `Args` and calls a
handwritten MoonBit implementation with the upstream name.

## Introspection and memoization

No comemo. The convergence loop records the introspection queries made
during an iteration together with their results and re-validates them
against the next iteration's introspector (what comemo's constraint
validation does upstream); non-convergence is reported like upstream.
Caching for speed is deferred.

## Testing

* `syntax` stage: tree + diagnostics (done).
* `ast` stage: typed AST semantics.
* `eval` stage: diagnostics + `repr` of the evaluated content for all 3792
  test cases (`oracle eval`). This is the P2 metric.
