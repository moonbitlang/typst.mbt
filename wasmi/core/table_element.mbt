// Port of `wasmi_core/src/table/element.rs`.

///|
/// A Wasm [`ElementSegment`].
pub struct ElementSegment {
  /// The [`ValType`] of elements of this [`ElementSegment`].
  priv ty : ValType
  /// Pre-resolved items of the Wasm element segment.
  priv mut items : FixedArray[UntypedVal]
}

///|
/// Creates a new [`ElementSegment`].
///
/// # Panics
///
/// If the length of `items` exceeds `u32`.
pub fn ElementSegment::new(
  ty : ValType,
  items : ArrayView[UntypedVal],
) -> ElementSegment {
  let items = FixedArray::from_array(items)
  { ty, items, }
}

///|
/// Returns `self` as [`ElementSegmentRef`].
pub fn ElementSegment::as_ref(self : ElementSegment) -> ElementSegmentRef {
  { ty: self.ty, items: self.items, }
}

///|
/// Returns the [`ValType`] of elements in the [`ElementSegment`].
pub fn ElementSegment::ty(self : ElementSegment) -> ValType {
  self.ty
}

///|
/// Returns the items of the [`ElementSegment`].
pub fn ElementSegment::items(self : ElementSegment) -> ArrayView[UntypedVal] {
  self.items[:]
}

///|
/// Returns the number of items in the [`ElementSegment`].
pub fn ElementSegment::size(self : ElementSegment) -> UInt {
  self.as_ref().size()
}

///|
/// Drops the items of the [`ElementSegment`].
pub fn ElementSegment::drop_items(self : ElementSegment) -> Unit {
  self.items = []
}

///|
/// A shared reference to a Wasm [`ElementSegment`].
pub struct ElementSegmentRef {
  /// The [`ValType`] of elements of this [`ElementSegment`].
  priv ty : ValType
  /// The items of the Wasm element segment.
  priv items : FixedArray[UntypedVal]
}

///|
/// Returns the [`ValType`] of elements in the [`ElementSegment`].
pub fn ElementSegmentRef::ty(self : ElementSegmentRef) -> ValType {
  self.ty
}

///|
/// Returns the items of the [`ElementSegment`].
pub fn ElementSegmentRef::items(
  self : ElementSegmentRef,
) -> ArrayView[UntypedVal] {
  self.items[:]
}

///|
/// Returns the number of items in the [`ElementSegment`].
pub fn ElementSegmentRef::size(self : ElementSegmentRef) -> UInt {
  self.items.length().reinterpret_as_uint()
}
