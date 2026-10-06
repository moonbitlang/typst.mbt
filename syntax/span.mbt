///|
/// An interned version of [RootedPath] (see `path.mbt`; non-zero, 16 bits).
pub struct FileId(UInt16) derive(Eq, Hash, Compare)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileId with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileId with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
/// Upstream `Debug for FileId` is that of its rooted path
/// (typst-syntax/src/path.rs:183).
pub impl @debug.Debug for FileId with fn to_repr(self) {
  @debug.Debug::to_repr(self.get())
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileId with @debug.Debug::{to_repr}

///|
pub fn FileId::into_raw(self : FileId) -> UInt16 {
  self.0
}

///|
/// Defines a range of text in a Typst source file.
///
/// Laid out with the high 16 bits as the file id and the low 48 bits as the
/// span number:
/// - Detached: 1 (file id is 0, otherwise non-zero)
/// - Typst source file:           2 ..= 2^47-1      (one 47-bit number)
/// - External file start:      2^47 ..= 2^47+2^46-1 (one 46-bit number)
/// - Internal range span: 2^47+2^46 ..= 2^48-1      (two 23-bit numbers)
pub(all) struct Span(UInt64) derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Span with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Span with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Span with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Span with @debug.Debug::{to_repr}

///|
/// The unique number of a span within its source.
pub(all) struct SpanNumber(UInt64) derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpanNumber with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpanNumber with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpanNumber with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpanNumber with @debug.Debug::{to_repr}

///|
/// The possible kinds of span.
pub(all) enum SpanKind {
  /// A span that does not point into any file.
  Detached
  /// A numbered span.
  Number(id~ : FileId, num~ : SpanNumber)
  /// A raw byte range in a file.
  Range(id~ : FileId, start~ : Int, end~ : Int)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpanKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpanKind with @debug.Debug::{to_repr}

///|
/// The full range of numbers available for source file span numbering.
let span_full_start : UInt64 = 2

///|
let span_full_end : UInt64 = 1UL << 47

///|
let span_number_bits : Int = 48

///|
let span_range_bits : Int = 46

///|
let span_number_mask : UInt64 = (1UL << span_number_bits) - 1

///|
let span_external_base : UInt64 = span_full_end

///|
let span_external_value_max : UInt64 = (1UL << span_range_bits) - 1

///|
let span_range_base : UInt64 = span_external_base + (1UL << span_range_bits)

///|
let span_range_value_bits : Int = 23

///|
let span_range_value_max : UInt64 = (1UL << span_range_value_bits) - 1

///|
/// The detached span that does not point into any file.
pub fn Span::detached() -> Span {
  Span(1)
}

///|
fn Span::pack(id : FileId, low : UInt64) -> Span {
  Span((id.0.to_uint64() << span_number_bits) | low)
}

///|
/// Create a new span from a file id and a span number.
pub fn Span::from_number(id : FileId, num : SpanNumber) -> Span {
  Span::pack(id, num.0)
}

///|
fn saturate(value : Int, max : UInt64) -> UInt64 {
  let v = value.to_uint64()
  if v > max {
    max
  } else {
    v
  }
}

///|
/// Create a new span from a raw byte range instead of a span number. Parts
/// exceeding `2^23-1` are saturated.
pub fn Span::from_range(id : FileId, start : Int, end : Int) -> Span {
  let start = saturate(start, span_range_value_max)
  let end = saturate(end, span_range_value_max)
  Span::pack(id, span_range_base + ((start << span_range_value_bits) | end))
}

///|
/// Whether the span is detached.
pub fn Span::is_detached(self : Span) -> Bool {
  self.0 == 1
}

///|
/// The id of the file the span points into.
pub fn Span::id(self : Span) -> FileId? {
  let raw = (self.0 >> span_number_bits).to_int()
  if raw == 0 {
    None
  } else {
    Some(FileId(raw.to_uint16()))
  }
}

///|
/// The unique number of the span within its source.
pub fn Span::number(self : Span) -> UInt64 {
  self.0 & span_number_mask
}

///|
/// Unpack the span into the variants of a [SpanKind].
pub fn Span::get(self : Span) -> SpanKind {
  guard self.id() is Some(id) else { return Detached }
  let num = self.number()
  if num >= span_range_base {
    let packed = num - span_range_base
    Range(
      id~,
      start=(packed >> span_range_value_bits).to_int(),
      end=(packed & span_range_value_max).to_int(),
    )
  } else {
    Number(id~, num=SpanNumber(num))
  }
}

///|
/// Return `other` if `self` is detached and `self` otherwise.
pub fn Span::or(self : Span, other : Span) -> Span {
  if self.is_detached() {
    other
  } else {
    self
  }
}

///|
/// A non-empty range targeting a smaller part of a spanned section of text.
pub(all) struct SubRange {
  start : Int
  end : Int
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SubRange with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SubRange with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SubRange with @debug.Debug::{to_repr}

///|
/// Create a new sub-range. Returns `None` if the range is empty.
pub fn SubRange::new(start : Int, end : Int) -> SubRange? {
  if start < end {
    Some({ start, end, })
  } else {
    None
  }
}

///|
/// Convert to a normal range relative to the spanned range.
pub fn SubRange::to_relative(self : SubRange) -> (Int, Int) {
  (self.start, self.end)
}

///|
/// Convert to a normal range at an offset.
pub fn SubRange::to_absolute(self : SubRange, offset : Int) -> (Int, Int) {
  (self.start + offset, self.end + offset)
}

///|
/// The span of a diagnostic message: either from a Typst source file (with an
/// optional sub-range) or from a loaded external file.
pub(all) struct DiagSpan {
  span : Span
  extra : UInt64
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpan with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpan with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpan with @debug.Debug::{to_repr}

///|
/// The possible kinds of a diagnostic span.
pub(all) enum DiagSpanKind {
  /// A span that does not point into any file.
  Detached
  /// A numbered span with an optional sub-range.
  Number(id~ : FileId, num~ : SpanNumber, sub_range~ : SubRange?)
  /// A raw byte range in a file.
  Range(id~ : FileId, start~ : Int, end~ : Int)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpanKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpanKind with @debug.Debug::{to_repr}

///|
/// The detached diagnostic span.
pub fn DiagSpan::detached() -> DiagSpan {
  { span: Span::detached(), extra: 0, }
}

///|
/// Create a diagnostic span from an external file's byte range.
pub fn DiagSpan::from_range(id : FileId, start : Int, end : Int) -> DiagSpan {
  let start = saturate(start, span_external_value_max)
  let end = saturate(end, span_external_value_max)
  { span: Span::pack(id, span_external_base + start), extra: end, }
}

///|
/// Create a diagnostic span from a source span and optional sub-range.
pub fn DiagSpan::from_span(span : Span, sub_range? : SubRange) -> DiagSpan {
  let extra = match sub_range {
    Some(sr) => (sr.start.to_uint64() << 32) | sr.end.to_uint64()
    None => 0
  }
  { span, extra, }
}

///|
/// Whether the diagnostic span is detached.
pub fn DiagSpan::is_detached(self : DiagSpan) -> Bool {
  self.span.is_detached()
}

///|
/// The id of the file the span points into.
pub fn DiagSpan::id(self : DiagSpan) -> FileId? {
  self.span.id()
}

///|
/// Return `other` if `self` is detached and `self` otherwise.
pub fn DiagSpan::or(self : DiagSpan, other : DiagSpan) -> DiagSpan {
  if self.is_detached() {
    other
  } else {
    self
  }
}

///|
fn DiagSpan::extra_sub_range(self : DiagSpan) -> SubRange? {
  let end = (self.extra & 0xFFFFFFFF).to_int()
  if end == 0 {
    None
  } else {
    Some({ start: (self.extra >> 32).to_int(), end, })
  }
}

///|
/// Unpack the diagnostic span into the variants of a [DiagSpanKind].
pub fn DiagSpan::get(self : DiagSpan) -> DiagSpanKind {
  match self.span.get() {
    Detached => Detached
    Number(id~, num~) =>
      if num.0 >= span_external_base {
        Range(
          id~,
          start=(num.0 - span_external_base).to_int(),
          end=self.extra.to_int(),
        )
      } else {
        Number(id~, num~, sub_range=self.extra_sub_range())
      }
    Range(id~, start~, end~) =>
      match self.extra_sub_range() {
        Some(sr) => {
          let (s, e) = sr.to_absolute(start)
          Range(id~, start=s, end=e)
        }
        None => Range(id~, start~, end~)
      }
  }
}

///|
/// A value with a span locating it in the source code.
pub(all) struct Spanned[T] {
  v : T
  span : Span
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Spanned with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Spanned with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Spanned with @debug.Debug::{to_repr}

///|
/// A value with a diagnostic span.
pub(all) struct DiagSpanned[T] {
  v : T
  span : DiagSpan
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpanned with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpanned with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagSpanned with @debug.Debug::{to_repr}
