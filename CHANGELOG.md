# Changelog

Changes to the public API of `moonbitlang/typst`, newest first. "Public API"
is what the `pkg.generated.mbti` files show; each section is taken from
their differences between two releases, so a rename or a changed signature
that is not listed here did not happen. Packages are named by their path in
the module (`library` is `moonbitlang/typst/library`).

## Unreleased

Since 0.1.4 (commit 7d2ee18).

### Breaking: renamed

MoonBit keywords and reserved words used as names get a trailing underscore
(like the existing `extend_`, `type_`); nothing else about these items
changed.

| package | before | now |
| --- | --- | --- |
| `library` | `Scope::define` | `Scope::define_` |
| `library` | `Type::module()` | `Type::module_()` |
| `library` | `Type::constructor` | `Type::constructor_` |
| `eval` | `Vm::define` | `Vm::define_` |
| `syntax` | field `PackageSpec.namespace` | `PackageSpec.namespace_` |
| `syntax` | field `VersionlessPackageSpec.namespace` | `VersionlessPackageSpec.namespace_` |
| `syntax` | field `PackageManifest.package` | `PackageManifest.package_` |
| `data/xml` | `Attribute::namespace()` | `Attribute::namespace_()` |
| `data/xml` | `ExpandedName::namespace()` | `ExpandedName::namespace_()` |
| `wasmi` | field `ImportName.module`, `ImportName::module()` | `module_`, `ImportName::module_()` |
| `wasmi` | `ImportType::module()` | `ImportType::module_()` |
| `wasmi` | `Linker::define` | `Linker::define_` |
| `wasmparser` | field `Frame.unreachable` | `Frame.unreachable_` |

Typst-level names (`type`, `module`, the `namespace` of a package spec in
Typst source) are unchanged.

### Breaking: changed

- `syntect`: `SyntaxSet::from_compact(String, ReadOnlyArray[String])` is
  now `from_compact(String, (Int) -> String)`: the contexts are given as a
  function of the syntax index (the embedded data is stored in pieces and
  joined when a syntax is first used).
- `wasmi`: `DedupFuncType` is an opaque struct (it was `pub(all) struct
  DedupFuncType(Int)`). It now records the engine it belongs to, and
  resolving it with another engine panics like upstream.
- `library`: the `pub(all)` structs `Closure` and `Tiling` have a new field
  each (`hash`, `frame_hash`, both `LazyFingerprint`); code that builds them
  with a struct literal must supply it (`LazyFingerprint::new()`).
- `hayro/interpret`: `GraphicsState` and `TextState`, `hayro/svg`:
  `SvgRenderer`, `otf`: `CffIndex` are no longer exported. They were
  abstract types that no public function accepted or returned.
- `doc`: `Stroke(dash=..)` takes a `Dash` (it was a `Value`): write a
  preset (`Dotted`, `Dashed`, ..), `Pattern([..], phase=..)`, or
  `RawValue(v)` for the value passed before.
- `doc`: the argument indices of origins (`Origin.param`, the ranges of
  `ArgsLoc`) shift where parameters were added: by two from `lang` on in
  `Text`/`SetText` and from `extent` on in `Highlight`/`SetHighlight`
  (`top_edge`, `bottom_edge`), by one from `fill` on in `Box`/`SetBox`
  (`baseline`).
- `doc`: `Size` (the result of `Ctx::measure`) has a third field,
  `baseline`; a pattern that names only `width` and `height` needs `..`.

### Changed: `Debug` output

These types print with core's `Debug` (`@debug.to_string`, `debug_inspect`,
inside derived `Debug` of other types) what upstream Typst prints for
`{:?}`, instead of a derived record:

| package | type | before | now |
| --- | --- | --- | --- |
| `syntax` | `PackageSpec` | `{ namespace: "preview", name: "foo", version: { major: 0, minor: 1, patch: 0 } }` (broken over lines) | `@preview/foo:0.1.0` |
| `syntax` | `VersionlessPackageSpec` | `{ namespace: "preview", name: "foo" }` | `@preview/foo` |
| `syntax` | `PackageVersion` | `{ major: 0, minor: 1, patch: 0 }` | `0.1.0` |
| `syntax` | `VersionBound` | `{ major: 0, minor: Some(1), patch: None }` | `0.1` |
| `syntax` | `FileId` | `FileId(1)` | `"/main.typ"`, in a package `@preview/foo:0.1.0"/lib.typ"` |

`Debug` of a `FileId` that was never interned now panics, as upstream's
does. `Show` of the package types is unchanged (`FileId` has none).

Without a change of output: `wasmparser`'s `Frame` implements `Debug` by
hand (it still prints the field as `unreachable`), and `wasmi/ir`'s
`OutOfBoundsConst` and `wasmi`'s `Any` implement `Show` by hand instead of
deriving it.

### Added

- `syntax`: `Debug` for `RootedPath` and `VirtualPath` (the text their
  `Show` already had, upstream's `Debug`).
- `syntax`: the trait `NodeHasher` (`write_u64`, `write_str`) and
  `SyntaxNode::hash_into`.
- `library`: `LazyFingerprint` (`new`, `reset`, `write`, `write_cached`,
  `flags`; `Eq`, `Hash`); `Fingerprint` for `Binding`, `Category`, `Color`, `ColorSpace`,
  `Curve`, `Datetime`, `Destination`, `FixedStroke`, `Font`, `FontInstance`,
  `Frame`, `FrameItem`, `Glyph`, `Gradient`, `GroupItem`, `Image`, `Module`,
  `Paint`, `ProcessColor`, `Scope`, `Shape`, `SpotColorant`, `Stroke`,
  `Symbol`, `TextItem`, `Tiling`, `Transform`; `NodeHasher` for
  `SipHasher128`; `Tiling::frame_fingerprint_flags`.
- `read_fonts`: the `hdmx` table: `FontRef::hdmx`; `Hdmx` (`read`,
  `version`, `num_records`, `size_device_record`, `record_for_size`);
  `DeviceRecord` (fields and accessors `pixel_size`, `max_width`,
  `widths`). `skrifa` uses it for the advance of hinted glyphs, like
  upstream.

- `doc`: `Layout` (the size of the enclosing region, with `LayoutSize`);
  `Size.baseline`; `Box(baseline=)`; `top_edge`/`bottom_edge` (`TopEdge`,
  `BottomEdge`) on `Text`, `SetText`, `Highlight`, `SetHighlight`; `Dash`
  and `DashLen`; colour operations on `Paint` (`transparentize`, `lighten`,
  `darken`, `mix` with `ColorSpace`); `Length::sizing`, `Length::spacing`;
  `Upper`, `Lower`; `Sides::zero`. See `docs/edsl-ports.md` and
  `docs/edsl-guide.md`.

### Not a change for users

- Type parameters that a type never used are written `_` in the interface:
  `library` `Ty[_]`; `otf` `LazyArray16[_]`, `LazyArray32[_]`,
  `LazyOffsetArray16[_]`, `RecordList[_]`, `LookupSubtablesIter[_]`,
  `ExtendedStateTable[_]`; `wasmparser` `SectionLimited[_]`. Uses such as
  `LazyArray16[UInt16]` are unaffected.
- `hayro/interpret`: `DummyDevice` is shown as an empty struct (its unused
  private field is gone); `DummyDevice::new()` is unchanged.
