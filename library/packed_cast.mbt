// Casts for `Packed<T>` of plain elements (upstream `Packed<T>`'s
// `Reflect`/`IntoValue` impls in `foundations/cast.rs` and
// `impl<T: NativeElement> IntoValue for T`).
//
// Upstream plain elements only implement `IntoValue` (as content); fields of
// type `Packed<T>` of such elements are synthesized or internal and never
// cast from user values. Here, casting back checks that the content is of
// the element `T`.

///|
/// Whether the value is content of the given element.
fn packed_castable(elem : Element, v : Value) -> Bool {
  v is Content(c) && c.is_(elem)
}

///|
/// Cast a value to content of the given element.
fn packed_from_value(elem : Element, v : Value) -> Content raise HintedError {
  match v {
    Content(c) if c.is_(elem) => c
    v => raise HintedError(CastInfo::Type(Type::content()).error(v))
  }
}

///|
pub impl Reflect for OutlineElem with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for OutlineElem with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for OutlineElem with fn castable(v) {
  packed_castable(outline_elem(), v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutlineElem with Reflect::{output, input, castable}

///|
pub impl IntoValue for OutlineElem with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutlineElem with IntoValue::{into_value}

///|
pub impl FromValue for OutlineElem with fn from_value(v) {
  OutlineElem(packed_from_value(outline_elem(), v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutlineElem with FromValue::{from_value}

// cast! {
//     OutlineEntry,
//     v: Content => v.unpack::<Self>().map_err(|_| "expected outline entry")?
// }

///|
pub impl Reflect for OutlineEntry with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for OutlineEntry with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for OutlineEntry with fn castable(v) {
  castable_of((Ty::new() : Ty[Content]), v)
}

///|
pub extend OutlineEntry with Reflect::{output, input, castable}

///|
pub impl IntoValue for OutlineEntry with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutlineEntry with IntoValue::{into_value}

///|
pub impl FromValue for OutlineEntry with fn from_value(v) {
  if castable_of((Ty::new() : Ty[Content]), v) {
    let content : Content = v.cast()
    match OutlineEntry::of(content) {
      Some(entry) => entry
      None => bail("expected outline entry")
    }
  } else {
    raise HintedError(OutlineEntry::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutlineEntry with FromValue::{from_value}

///|
pub impl Reflect for CiteElem with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for CiteElem with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for CiteElem with fn castable(v) {
  packed_castable(cite_elem(), v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CiteElem with Reflect::{output, input, castable}

///|
pub impl IntoValue for CiteElem with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CiteElem with IntoValue::{into_value}

///|
pub impl FromValue for CiteElem with fn from_value(v) {
  CiteElem(packed_from_value(cite_elem(), v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CiteElem with FromValue::{from_value}

///|
pub impl Reflect for RawLine with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for RawLine with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for RawLine with fn castable(v) {
  packed_castable(raw_line_elem(), v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawLine with Reflect::{output, input, castable}

///|
pub impl IntoValue for RawLine with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawLine with IntoValue::{into_value}

///|
pub impl FromValue for RawLine with fn from_value(v) {
  RawLine(packed_from_value(raw_line_elem(), v))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RawLine with FromValue::{from_value}
