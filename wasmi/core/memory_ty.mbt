// Port of `wasmi_core/src/memory/ty.rs`.
//
// Upstream's `u128` byte sizes are `@bigint.BigInt`s.

///|
/// Internal memory type data and details.
priv struct MemoryTypeInner {
  /// The initial or minimum amount of pages.
  minimum : UInt64
  /// The optional maximum amount of pages.
  maximum : UInt64?
  /// The size of a page log2.
  page_size_log2 : Byte
  /// The index type used to address a linear memory.
  index_type : IndexType
} derive(Eq, Hash, Debug)

///|
/// A type to indicate that a size calculation has overflown.
priv suberror SizeOverflow

///|
/// Returns the minimum size, in bytes, that the linear memory must have.
///
/// # Errors
///
/// If the calculation of the minimum size overflows the maximum size.
/// This means that the linear memory can't be allocated.
/// The caller is responsible to deal with that situation.
fn MemoryTypeInner::minimum_byte_size(
  self : MemoryTypeInner,
) -> @bigint.BigInt raise SizeOverflow {
  let min = @bigint.BigInt::from_uint64(self.minimum)
  if min > self.absolute_max() {
    raise SizeOverflow
  }
  min << self.page_size_log2.to_int()
}

///|
/// Returns the maximum size, in bytes, that the linear memory must have.
///
/// # Note
///
/// If the maximum size of a memory type is not specified a concrete
/// maximum value is returned dependent on the index type of the memory type.
///
/// # Errors
///
/// If the calculation of the maximum size overflows the index type.
/// This means that the linear memory can't be allocated.
/// The caller is responsible to deal with that situation.
fn MemoryTypeInner::maximum_byte_size(
  self : MemoryTypeInner,
) -> @bigint.BigInt raise SizeOverflow {
  match self.maximum {
    Some(max) => {
      let max = @bigint.BigInt::from_uint64(max)
      if max > self.absolute_max() {
        raise SizeOverflow
      }
      max << self.page_size_log2.to_int()
    }
    None => self.max_size_based_on_index_type()
  }
}

///|
/// Returns the size of the linear memory pages in bytes.
fn MemoryTypeInner::page_size(self : MemoryTypeInner) -> UInt {
  1U << self.page_size_log2.to_int()
}

///|
/// Returns the maximum size in bytes allowed by the `index_type` of this memory type.
///
/// # Note
///
/// - This does _not_ take into account the page size.
/// - This is based _only_ on the index type used by the memory type.
fn MemoryTypeInner::max_size_based_on_index_type(
  self : MemoryTypeInner,
) -> @bigint.BigInt {
  self.index_type.max_size()
}

///|
/// Returns the absolute maximum size in pages that a linear memory is allowed to have.
fn MemoryTypeInner::absolute_max(self : MemoryTypeInner) -> @bigint.BigInt {
  self.max_size_based_on_index_type() >> self.page_size_log2.to_int()
}

///|
/// The memory type of a linear memory.
pub struct MemoryType {
  priv inner : MemoryTypeInner
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemoryType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemoryType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemoryType with @debug.Debug::{to_repr}

///|
/// A builder for [`MemoryType`]s.
///
/// Constructed via [`MemoryType::builder`] or via [`MemoryTypeBuilder::default`].
/// Allows to incrementally build-up a [`MemoryType`]. When done, finalize creation
/// via a call to [`MemoryTypeBuilder::build`].
pub struct MemoryTypeBuilder {
  priv mut inner : MemoryTypeInner
}

///|
pub impl Default for MemoryTypeBuilder with fn default() {
  {
    inner: {
      minimum: 0,
      maximum: None,
      page_size_log2: memory_type_default_page_size_log2,
      index_type: IndexType::I32,
    },
  }
}

///|
/// Set whether this is a 64-bit memory type or not.
///
/// By default a memory is a 32-bit, a.k.a. `false`.
///
/// 64-bit memories are part of the [Wasm `memory64` proposal].
///
/// [Wasm `memory64` proposal]: https://github.com/WebAssembly/memory64
pub fn MemoryTypeBuilder::memory64(
  self : MemoryTypeBuilder,
  memory64 : Bool,
) -> MemoryTypeBuilder {
  self.inner = {
    ..self.inner,
    index_type: if memory64 {
      IndexType::I64
    } else {
      IndexType::I32
    },
  }
  self
}

///|
/// Sets the minimum number of pages the built [`MemoryType`] supports.
///
/// The default minimum is `0`.
pub fn MemoryTypeBuilder::min(
  self : MemoryTypeBuilder,
  minimum : UInt64,
) -> MemoryTypeBuilder {
  self.inner = { ..self.inner, minimum, }
  self
}

///|
/// Sets the optional maximum number of pages the built [`MemoryType`] supports.
///
/// A value of `None` means that there is no maximum number of pages.
///
/// The default maximum is `None`.
pub fn MemoryTypeBuilder::max(
  self : MemoryTypeBuilder,
  maximum : UInt64?,
) -> MemoryTypeBuilder {
  self.inner = { ..self.inner, maximum, }
  self
}

///|
/// Sets the log2 page size in bytes, for the built [`MemoryType`].
///
/// The default value is 16, which results in the default Wasm page size of 64KiB (aka 2^16 or 65536).
///
/// Currently, the only allowed values are 0 (page size of 1) or 16 (the default).
/// Future Wasm proposal extensions might change this limitation.
///
/// Non-default page sizes are part of the [`custom-page-sizes proposal`]
/// for WebAssembly which is not fully standardized yet.
///
/// [`custom-page-sizes proposal`]: https://github.com/WebAssembly/custom-page-sizes
pub fn MemoryTypeBuilder::page_size_log2(
  self : MemoryTypeBuilder,
  page_size_log2 : Byte,
) -> MemoryTypeBuilder {
  self.inner = { ..self.inner, page_size_log2, }
  self
}

///|
/// Finalize the construction of the [`MemoryType`].
///
/// # Errors
///
/// If the chosen configuration for the constructed [`MemoryType`] is invalid.
pub fn MemoryTypeBuilder::build(
  self : MemoryTypeBuilder,
) -> MemoryType raise MemoryError {
  self.validate()
  { inner: self.inner, }
}

///|
/// Validates the configured [`MemoryType`] of the [`MemoryTypeBuilder`].
///
/// # Errors
///
/// If the chosen configuration for the constructed [`MemoryType`] is invalid.
fn MemoryTypeBuilder::validate(
  self : MemoryTypeBuilder,
) -> Unit raise MemoryError {
  match self.inner.page_size_log2 {
    0 | 16 => ()
    _ =>
      // Case: currently, pages sizes log2 can only be 0 or 16.
      // Note: Future Wasm extensions might allow more values.
      raise InvalidMemoryType
  }
  let _ = self.inner.minimum_byte_size() catch {
    // Case: the minimum size overflows a `absolute_max`
    _ => raise InvalidMemoryType
  }
  if self.inner.maximum is Some(max) {
    let _ = self.inner.maximum_byte_size() catch {
      // Case: the maximum size overflows a `absolute_max`
      _ => raise InvalidMemoryType
    }
    if self.inner.minimum > max {
      // Case: maximum size must be at least as large as minimum size
      raise InvalidMemoryType
    }
  }
}

///|
/// The default memory page size in KiB.
let memory_type_default_page_size_log2 : Byte = 16 // 2^16 KiB = 64 KiB

///|
/// Returns a [`MemoryTypeBuilder`] to incrementally construct a [`MemoryType`].
pub fn MemoryType::builder() -> MemoryTypeBuilder {
  MemoryTypeBuilder::default()
}

///|
/// Returns `true` if this is a 64-bit [`MemoryType`].
///
/// 64-bit memories are part of the Wasm `memory64` proposal.
pub fn MemoryType::is_64(self : MemoryType) -> Bool {
  self.index_ty().is_64()
}

///|
/// Returns the [`IndexType`] used by the [`MemoryType`].
pub fn MemoryType::index_ty(self : MemoryType) -> IndexType {
  self.inner.index_type
}

///|
/// Returns the minimum pages of the memory type.
pub fn MemoryType::minimum(self : MemoryType) -> UInt64 {
  self.inner.minimum
}

///|
/// Returns the maximum pages of the memory type.
///
/// Returns `None` if there is no limit set.
pub fn MemoryType::maximum(self : MemoryType) -> UInt64? {
  self.inner.maximum
}

///|
/// Returns the page size of the [`MemoryType`] in bytes.
pub fn MemoryType::page_size(self : MemoryType) -> UInt {
  self.inner.page_size()
}

///|
/// Returns the page size of the [`MemoryType`] in log2(bytes).
pub fn MemoryType::page_size_log2(self : MemoryType) -> Byte {
  self.inner.page_size_log2
}

///|
/// Returns the minimum size, in bytes, that the linear memory must have.
///
/// # Errors
///
/// If the calculation of the minimum size overflows the maximum size.
/// This means that the linear memory can't be allocated.
/// The caller is responsible to deal with that situation.
fn MemoryType::minimum_byte_size(
  self : MemoryType,
) -> @bigint.BigInt raise SizeOverflow {
  self.inner.minimum_byte_size()
}

///|
/// Returns the absolute maximum size in pages that a linear memory is allowed to have.
fn MemoryType::absolute_max(self : MemoryType) -> @bigint.BigInt {
  self.inner.absolute_max()
}

///|
/// Returns `true` if the [`MemoryType`] is a subtype of the `other` [`MemoryType`].
///
/// # Note
///
/// This implements the [subtyping rules] according to the WebAssembly spec.
///
/// [import subtyping]:
/// https://webassembly.github.io/spec/core/valid/types.html#import-subtyping
pub fn MemoryType::is_subtype_of(self : MemoryType, other : MemoryType) -> Bool {
  if self.is_64() != other.is_64() {
    return false
  }
  if self.page_size() != other.page_size() {
    return false
  }
  if self.minimum() < other.minimum() {
    return false
  }
  match (self.maximum(), other.maximum()) {
    (_, None) => true
    (Some(max), Some(other_max)) => max <= other_max
    _ => false
  }
}
