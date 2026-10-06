// Port of `svgtypes` 0.16.1 `src/paint_order.rs`.

///|
/// [`paint-order`] property variants.
///
/// [`paint-order`]: https://www.w3.org/TR/SVG2/painting.html#PaintOrder
pub(all) enum PaintOrderKind {
  Fill
  Stroke
  Markers
} derive(Eq, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PaintOrderKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PaintOrderKind with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PaintOrderKind with Hash::{hash, hash_combine}

///|
/// Representation of the [`paint-order`] property.
///
/// [`paint-order`]: https://www.w3.org/TR/SVG2/painting.html#PaintOrder
pub(all) struct PaintOrder {
  /// The order (always 3 elements).
  ///
  /// Guarantee to not have duplicates.
  order : FixedArray[PaintOrderKind]
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PaintOrder with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PaintOrder with @debug.Debug::{to_repr}

///|
pub impl Default for PaintOrder with fn default() {
  { order: [Fill, Stroke, Markers], }
}

///|
pub extend PaintOrder with Default::{default}

///|
/// `From<[PaintOrderKind; 3]>`.
pub fn PaintOrder::from_array(order : FixedArray[PaintOrderKind]) -> PaintOrder {
  { order, }
}

///|
/// Parses `PaintOrder` from a string.
///
/// Never returns an error and fallbacks to the default value instead
/// (upstream's `FromStr` has `Err = ()` and never fails).
pub fn PaintOrder::from_str(text : String) -> PaintOrder {
  let order : Array[PaintOrderKind] = []
  let left : Array[PaintOrderKind] = [Fill, Stroke, Markers]
  let s = Stream::from(text)
  while !s.at_end() && order.length() < 3 {
    s.skip_spaces()
    let name = s.consume_ascii_ident()
    s.skip_spaces()
    let name = match name {
      // `normal` is the special value that should short-circuit.
      "normal" => return PaintOrder::default()
      "fill" => PaintOrderKind::Fill
      "stroke" => PaintOrderKind::Stroke
      "markers" => PaintOrderKind::Markers
      _ => return PaintOrder::default()
    }
    if left.search(name) is Some(index) {
      left.remove(index) |> ignore
    }
    order.push(name)
  }
  s.skip_spaces()
  if !s.at_end() {
    // Any trailing data is an error.
    return PaintOrder::default()
  }
  if order.is_empty() {
    return PaintOrder::default()
  }

  // Any missing values should be added in the original order.
  while order.length() < 3 && !left.is_empty() {
    order.push(left.remove(0))
  }

  // Any duplicates is an error.
  if order[0] == order[1] || order[0] == order[2] || order[1] == order[2] {
    // Any trailing data is an error.
    return PaintOrder::default()
  }
  { order: [order[0], order[1], order[2]], }
}
