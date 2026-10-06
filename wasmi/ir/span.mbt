// Port of wasmi_ir 1.0.9 `span.rs`.

///|
/// A [`SlotSpan`] of contiguous [`Slot`] indices.
///
/// # Note
///
/// - Represents an amount of contiguous [`Slot`] indices.
/// - For the sake of space efficiency the actual number of [`Slot`]
///   of the [`SlotSpan`] is stored externally and provided in
///   [`SlotSpan::iter`] when there is a need to iterate over
///   the [`Slot`] of the [`SlotSpan`].
///
/// The caller is responsible for providing the correct length.
/// Due to Wasm validation guided bytecode construction we assert
/// that the externally stored length is valid.
pub(all) struct SlotSpan(Slot) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SlotSpan with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SlotSpan with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SlotSpan with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SlotSpan with @debug.Debug::{to_repr}

///|
/// Creates a new [`SlotSpan`] starting with the given `start` [`Slot`].
pub fn SlotSpan::new(head : Slot) -> SlotSpan {
  SlotSpan(head)
}

///|
/// Returns a [`SlotSpanIter`] yielding `len` [`Slot`]s.
pub fn SlotSpan::iter_sized(self : SlotSpan, len : Int) -> SlotSpanIter {
  SlotSpanIter::new(self.0, len)
}

///|
/// Returns a [`SlotSpanIter`] yielding `len` [`Slot`]s.
pub fn SlotSpan::iter(self : SlotSpan, len : Int) -> SlotSpanIter {
  SlotSpanIter::new_u16(self.0, len)
}

///|
/// Returns the head [`Slot`] of the [`SlotSpan`].
pub fn SlotSpan::head(self : SlotSpan) -> Slot {
  self.0
}

///|
/// Returns `true` if copying from `values` to `results` with `len` would
/// overwrite values that are still to be copied.
pub fn SlotSpan::has_overlapping_copies(
  results : SlotSpan,
  values : SlotSpan,
  len : Int,
) -> Bool {
  SlotSpanIter::has_overlapping_copies(results.iter(len), values.iter(len))
}

///|
/// A [`SlotSpan`] with a statically known number of [`Slot`] (upstream
/// `FixedSlotSpan<N>`; only `N = 2` is used by Wasmi's instructions).
pub(all) struct FixedSlotSpan(SlotSpan) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FixedSlotSpan with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FixedSlotSpan with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FixedSlotSpan with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FixedSlotSpan with @debug.Debug::{to_repr}

///|
/// Returns an array of the results represented by `self` (`N = 2`).
pub fn FixedSlotSpan::to_array(self : FixedSlotSpan) -> (Slot, Slot) {
  let fst = self.0.head()
  let snd = fst.next()
  (fst, snd)
}

///|
/// Creates a new [`FixedSlotSpan`] of length `n` from the given [`SlotSpan`].
///
/// # Errors
///
/// If `span` cannot hold `n` slots (overflowing slot indices).
pub fn FixedSlotSpan::new(
  span : SlotSpan,
  n : Int,
) -> FixedSlotSpan raise IrError {
  let head = span.head()
  if head.0 >= head.next_n(n).0 {
    raise IrError::StackSlotOutOfBounds
  }
  FixedSlotSpan(span)
}

///|
/// Creates a [`FixedSlotSpan`] without checks (used when relinking).
pub fn FixedSlotSpan::from_span_unchecked(span : SlotSpan) -> FixedSlotSpan {
  FixedSlotSpan(span)
}

///|
/// Returns a [`SlotSpanIter`] yielding the 2 [`Slot`]s.
pub fn FixedSlotSpan::iter(self : FixedSlotSpan) -> SlotSpanIter {
  self.0.iter(self.len())
}

///|
/// Converts this [`FixedSlotSpan`] to its [`BoundedSlotSpan`] equivalent.
pub fn FixedSlotSpan::bounded(self : FixedSlotSpan) -> BoundedSlotSpan {
  BoundedSlotSpan::new(self.0, 2)
}

///|
/// Returns the underlying [`SlotSpan`] of the [`FixedSlotSpan`].
pub fn FixedSlotSpan::span(self : FixedSlotSpan) -> SlotSpan {
  self.0
}

///|
/// Returns `true` if the [`Slot`] is contained in `self`.
pub fn FixedSlotSpan::contains(self : FixedSlotSpan, slot : Slot) -> Bool {
  let min = self.0.head()
  let max = min.next_n(2)
  min.0 <= slot.0 && slot.0 < max.0
}

///|
/// Returns the number of [`Slot`]s in `self`.
pub fn FixedSlotSpan::len(_self : FixedSlotSpan) -> Int {
  2
}

///|
/// A [`SlotSpan`] with a known number of [`Slot`]s.
pub(all) struct BoundedSlotSpan {
  /// The first [`Slot`] in `self`.
  span : SlotSpan
  /// The number of [`Slot`] in `self` (upstream `u16`).
  len : Int
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BoundedSlotSpan with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BoundedSlotSpan with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BoundedSlotSpan with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BoundedSlotSpan with @debug.Debug::{to_repr}

///|
/// Creates a new [`BoundedSlotSpan`] from the given `span` and `len`.
pub fn BoundedSlotSpan::new(span : SlotSpan, len : Int) -> BoundedSlotSpan {
  { span, len, }
}

///|
/// Returns a [`SlotSpanIter`] yielding `len` [`Slot`]s.
pub fn BoundedSlotSpan::iter(self : BoundedSlotSpan) -> SlotSpanIter {
  self.span.iter(self.len)
}

///|
/// Returns the underlying [`SlotSpan`] of `self`.
pub fn BoundedSlotSpan::span(self : BoundedSlotSpan) -> SlotSpan {
  self.span
}

///|
/// Returns `true` if the [`Slot`] is contained in `self`.
pub fn BoundedSlotSpan::contains(self : BoundedSlotSpan, reg : Slot) -> Bool {
  if self.is_empty() {
    return false
  }
  let min = self.span.head()
  let max = min.next_n(self.len)
  min.0 <= reg.0 && reg.0 < max.0
}

///|
/// Returns the number of [`Slot`] in `self`.
pub fn BoundedSlotSpan::len(self : BoundedSlotSpan) -> Int {
  self.len
}

///|
/// Returns `true` if `self` is empty.
pub fn BoundedSlotSpan::is_empty(self : BoundedSlotSpan) -> Bool {
  self.len == 0
}

///|
/// A [`SlotSpanIter`] iterator yielding contiguous [`Slot`].
pub(all) struct SlotSpanIter {
  /// The next [`Slot`] in the [`SlotSpanIter`].
  mut next : Int
  /// The last [`Slot`] in the [`SlotSpanIter`].
  mut last : Int
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SlotSpanIter with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SlotSpanIter with @debug.Debug::{to_repr}

///|
/// Creates a [`SlotSpanIter`] from then given raw `start` and `end` [`Slot`].
pub fn SlotSpanIter::from_raw_parts(start : Slot, end : Slot) -> SlotSpanIter {
  { next: start.0, last: end.0, }
}

///|
/// Creates a new [`SlotSpanIter`] for the given `start` [`Slot`] and length `len`.
///
/// # Panics
///
/// If the `start..end` [`Slot`] span indices are out of bounds.
fn SlotSpanIter::new(start : Slot, len : Int) -> SlotSpanIter {
  if len < 0 || len > 0xFFFF {
    abort("out of bounds length for register span: \{len}")
  }
  SlotSpanIter::new_u16(start, len)
}

///|
/// Creates a new [`SlotSpanIter`] for the given `start` [`Slot`] and length `len`.
///
/// # Panics
///
/// If the `start..end` [`Slot`] span indices are out of bounds.
fn SlotSpanIter::new_u16(start : Slot, len : Int) -> SlotSpanIter {
  let last = start.0 + len
  if last > 32767 {
    abort("overflowing register index for register span")
  }
  { next: start.0, last, }
}

///|
/// Returns the [`SlotSpan`] this [`SlotSpanIter`] is iterating over.
pub fn SlotSpanIter::span(self : SlotSpanIter) -> SlotSpan {
  SlotSpan(Slot(self.next))
}

///|
/// Returns the remaining number of [`Slot`]s yielded by the [`SlotSpanIter`].
pub fn SlotSpanIter::len_as_u16(self : SlotSpanIter) -> Int {
  (self.last - self.next).abs()
}

///|
/// Returns the remaining number of [`Slot`]s yielded by the [`SlotSpanIter`].
pub fn SlotSpanIter::len(self : SlotSpanIter) -> Int {
  self.len_as_u16()
}

///|
/// Returns `true` if `self` yields no more [`Slot`]s.
pub fn SlotSpanIter::is_empty(self : SlotSpanIter) -> Bool {
  self.len_as_u16() == 0
}

///|
/// Upstream `Iterator::next`.
pub fn SlotSpanIter::next(self : SlotSpanIter) -> Slot? {
  if self.next == self.last {
    return None
  }
  let reg = self.next
  self.next = Slot::Slot(self.next).next().0
  Some(Slot::Slot(reg))
}

///|
/// Upstream `DoubleEndedIterator::next_back`.
pub fn SlotSpanIter::next_back(self : SlotSpanIter) -> Slot? {
  if self.next == self.last {
    return None
  }
  self.last = Slot::Slot(self.last).prev().0
  Some(Slot::Slot(self.last))
}

///|
/// Returns a copy of the iterator (upstream `SlotSpanIter: Copy`).
pub fn SlotSpanIter::copy(self : SlotSpanIter) -> SlotSpanIter {
  { next: self.next, last: self.last, }
}

///|
/// Returns `true` if `copy_span results <- values` has overlapping copies.
///
/// # Examples
///
/// - `[ ]`: empty never overlaps
/// - `[ 1 <- 0 ]`: single element never overlaps
/// - `[ 0 <- 1, 1 <- 2, 2 <- 3 ]`: no overlap
/// - `[ 1 <- 0, 2 <- 1 ]`: overlaps!
pub fn SlotSpanIter::has_overlapping_copies(
  results : SlotSpanIter,
  values : SlotSpanIter,
) -> Bool {
  if results.len() != values.len() {
    abort("cannot copy between different sized register spans")
  }
  let len = results.len()
  if len <= 1 {
    // Empty spans or single-element spans can never overlap.
    return false
  }
  let first_value = values.span().head()
  let first_result = results.span().head()
  if first_value.0 >= first_result.0 {
    // This case can never result in overlapping copies.
    return false
  }
  let values = values.copy()
  let last_value = match values.next_back() {
    Some(v) => v
    None => abort("span is non empty and thus must return")
  }
  last_value.0 >= first_result.0
}
