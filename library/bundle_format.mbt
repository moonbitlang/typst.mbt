// Port of `typst-bundle/src/format.rs`: the castable `AssetData`, the
// `BundleFormat` constructor and the bundle-specific native rules. (The
// `BundleFormat` and `AssetElem` descriptors are generated into
// `elems_gen.mbt`; the format itself is `bundle_format()` in `format.mbt`.)

///|
/// `impl Construct for BundleFormat`.
fn bundle_format_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_engine, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}

///|
/// Registers show rules for bundle specific elements (upstream
/// `typst_bundle::format::register`).
pub fn bundle_register(rules : NativeRuleMap) -> Unit {
  for target in [Target::Paged, Html] {
    rules.replace(target, bundle_document_unsupported_rule)
    rules.register(target, asset_unsupported_rule)
  }
}

///|
/// The native show rule of documents outside of the bundle target (upstream
/// `typst_bundle::format::DOCUMENT_UNSUPPORTED_RULE`).
pub fn bundle_document_unsupported_rule(
  elem : DocumentElem,
  _engine : Engine,
  _styles : StyleChain,
) -> Content raise SourceError {
  bail_at(
    elem.pack().span(),
    "constructing a document is only supported in the bundle target",
    // TODO: Support for CLI-specific hints would be nice.
    hints=[
      "try enabling the bundle target", "or use a `set document(..)` rule to configure metadata",
    ],
  )
}

///|
/// The native show rule of assets outside of the bundle target (upstream
/// `ASSET_UNSUPPORTED_RULE`).
pub fn asset_unsupported_rule(
  elem : AssetElem,
  _engine : Engine,
  _styles : StyleChain,
) -> Content raise SourceError {
  bail_at(
    elem.pack().span(),
    "assets are only supported in the bundle target",
    // TODO: Support for CLI-specific hints would be nice.
    hints=["try enabling the bundle target"],
  )
}

///|
/// The raw data for an asset.
pub(all) struct AssetData(BytesValue) derive(Eq, Hash)

///|
pub impl Reflect for AssetData with fn input() {
  CastInfo::Type(Type::str()).union_with(Type(Type::bytes()))
}

///|
pub impl Reflect for AssetData with fn output() {
  CastInfo::Type(Type::str()).union_with(Type(Type::bytes()))
}

///|
pub impl Reflect for AssetData with fn castable(v) {
  castable_of((Ty::new() : Ty[String]), v) || v is Bytes(_)
}

///|
pub impl IntoValue for AssetData with fn into_value(self) {
  Bytes(self.0)
}

///|
pub impl FromValue for AssetData with fn from_value(v) {
  if castable_of((Ty::new() : Ty[String]), v) {
    AssetData(BytesValue::from_string(v.cast()))
  } else if v is Bytes(b) {
    AssetData(b)
  } else {
    raise HintedError(AssetData::input().error(v))
  }
}
