// Port of the castable types of `typst-bundle/src/format.rs` (`AssetData`).

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
