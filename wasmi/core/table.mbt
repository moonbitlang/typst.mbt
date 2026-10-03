// Port of `wasmi_core/src/table/mod.rs`.
//
// Upstream `usize` sizes and indices are `UInt64` (a 64-bit `usize`).
// MoonBit arrays are indexed by `Int`: a table larger than
// [`max_table_len`] elements cannot be allocated, which is reported like a
// failed allocation upstream (`TableError::OutOfSystemMemory`).

///|
/// The maximum number of elements of a [`Table`].
let max_table_len : UInt64 = 0x7FFF_FFFF

///|
/// A Wasm table entity.
pub struct Table {
  priv ty : TableType
  priv elements : Array[UntypedVal]
}

///|
/// Creates a new table entity with the given resizable limits.
///
/// # Errors
///
/// If `init` does not match the [`TableType`] element type.
pub fn Table::new(
  ty : TableType,
  init : TypedVal,
  limiter : ResourceLimiterRef,
) -> Table raise TableError {
  ty.ensure_element_type_matches(init.ty())
  let min_size = ty.minimum()
  let max_size = ty.maximum()
  if limiter.as_resource_limiter() is Some(limiter) {
    let allowed = limiter.table_growing(0, min_size, max_size) catch {
      error => raise TableError::from_limiter_error(error)
    }
    if !allowed {
      raise ResourceLimiterDeniedAllocation
    }
  }
  if min_size > max_table_len {
    let error = TableError::OutOfSystemMemory
    if limiter.as_resource_limiter() is Some(limiter) {
      limiter.table_grow_failed(LimiterError::from_table_error(error))
    }
    raise error
  }
  let elements = Array::make(min_size.to_int(), init.untyped())
  { ty, elements, }
}

///|
/// Returns the resizable limits of the table.
pub fn Table::ty(self : Table) -> TableType {
  self.ty
}

///|
/// Returns the dynamic [`TableType`] of the [`Table`].
///
/// # Note
///
/// This respects the current size of the [`Table`]
/// as its minimum size and is useful for import subtyping checks.
pub fn Table::dynamic_ty(self : Table) -> TableType {
  TableType::new_impl(
    self.ty().element(),
    self.ty().index_ty(),
    self.size(),
    self.ty().maximum(),
  )
}

///|
/// Returns the current size of the [`Table`].
pub fn Table::size(self : Table) -> UInt64 {
  self.elements.length().to_uint64()
}

///|
/// Grows the table by the given amount of elements.
///
/// Returns the old size of the [`Table`] upon success.
///
/// # Note
///
/// The newly added elements are initialized to the `init` [`TypedVal`].
///
/// # Errors
///
/// - If the table is grown beyond its maximum limits.
/// - If `value` does not match the [`Table`] element type.
pub fn Table::grow(
  self : Table,
  delta : UInt64,
  init : TypedVal,
  fuel : Fuel?,
  limiter : ResourceLimiterRef,
) -> UInt64 raise TableError {
  self.ty().ensure_element_type_matches(init.ty())
  self.grow_untyped(delta, init.untyped(), fuel, limiter)
}

///|
fn Table::notify_limiter(
  limiter : ResourceLimiterRef,
  error : TableError,
) -> UInt64 raise TableError {
  if limiter.as_resource_limiter() is Some(limiter) {
    limiter.table_grow_failed(LimiterError::from_table_error(error))
  }
  raise error
}

///|
/// Grows the table by the given amount of elements.
///
/// Returns the old size of the [`Table`] upon success.
///
/// # Note
///
/// This is an internal API that exists for efficiency purposes.
///
/// The newly added elements are initialized to the `init` [`TypedVal`].
///
/// # Errors
///
/// If the table is grown beyond its maximum limits.
pub fn Table::grow_untyped(
  self : Table,
  delta : UInt64,
  init : UntypedVal,
  fuel : Fuel?,
  limiter : ResourceLimiterRef,
) -> UInt64 raise TableError {
  if delta == 0 {
    return self.size()
  }
  let desired = self.size() + delta
  if desired < delta {
    raise GrowOutOfBounds
  }
  let max_size = self.ty.index_ty().max_size()
  if @bigint.BigInt::from_uint64(desired) >= max_size {
    raise GrowOutOfBounds
  }
  let current = self.size()
  let maximum = self.ty.maximum()

  // ResourceLimiter gets first look at the request.
  if limiter.as_resource_limiter() is Some(limiter) {
    let allowed = limiter.table_growing(current, desired, maximum) catch {
      _ => raise ResourceLimiterDeniedAllocation
    }
    if !allowed {
      raise GrowOutOfBounds
    }
  }
  if maximum is Some(maximum) {
    if desired > maximum {
      return Table::notify_limiter(limiter, GrowOutOfBounds)
    }
  }
  if fuel is Some(fuel) {
    let _ = fuel.consume_fuel(costs => costs.fuel_for_copying_values(delta)) catch {
      FuelMeteringDisabled => 0
      OutOfFuel(required_fuel~) =>
        return Table::notify_limiter(limiter, OutOfFuel(required_fuel~))
    }
  }
  if desired > max_table_len {
    return Table::notify_limiter(limiter, OutOfSystemMemory)
  }
  let size_before = self.size()
  let desired = desired.to_int()
  while self.elements.length() < desired {
    self.elements.push(init)
  }
  size_before
}

///|
/// Returns the [`Table`] element value at `index`.
///
/// Returns `None` if `index` is out of bounds.
pub fn Table::get(self : Table, index : UInt64) -> TypedVal? {
  guard self.get_untyped(index) is Some(untyped) else { return None }
  let value = TypedVal::new(self.ty().element(), untyped)
  Some(value)
}

///|
/// Returns the untyped [`Table`] element value at `index`.
///
/// Returns `None` if `index` is out of bounds.
///
/// # Note
///
/// This is a more efficient version of [`Table::get`] for
/// internal use only.
pub fn Table::get_untyped(self : Table, index : UInt64) -> UntypedVal? {
  if index >= self.size() {
    return None
  }
  Some(self.elements[index.to_int()])
}

///|
/// Sets the [`TypedVal`] of this [`Table`] at `index`.
///
/// # Errors
///
/// - If `index` is out of bounds.
/// - If `value` does not match the [`Table`] element type.
pub fn Table::set(
  self : Table,
  index : UInt64,
  value : TypedVal,
) -> Unit raise TableError {
  self.ty().ensure_element_type_matches(value.ty())
  self.set_untyped(index, value.untyped())
}

///|
/// Returns the [`UntypedVal`] of the [`Table`] at `index`.
///
/// # Errors
///
/// If `index` is out of bounds.
pub fn Table::set_untyped(
  self : Table,
  index : UInt64,
  value : UntypedVal,
) -> Unit raise TableError {
  if index >= self.size() {
    raise SetOutOfBounds
  }
  self.elements[index.to_int()] = value
}

///|
/// Returns the start of `items[index..][..len]` if it is in bounds.
fn sub_range_start(items_len : Int, index : UInt64, len : UInt64) -> Int? {
  let n = items_len.to_uint64()
  if index > n || n - index < len {
    return None
  }
  Some(index.to_int())
}

///|
/// Initialize `len` elements from `src_element[src_index..]` into `self[dst_index..]`.
///
/// # Errors
///
/// Returns an error if the range is out of bounds of either the source or destination tables.
///
/// # Panics
///
/// If the [`ElementSegment`] element type does not match the [`Table`] element type.
/// Note: This is a panic instead of an error since it is asserted at Wasm validation time.
pub fn Table::init(
  self : Table,
  element : ElementSegmentRef,
  dst_index : UInt64,
  src_index : UInt,
  len : UInt,
  fuel : Fuel?,
) -> Unit raise TableError {
  let table_type = self.ty()
  if !table_type.element().is_ref() {
    abort("table.init currently only works on reftypes")
  }
  self.ty().ensure_element_type_matches(element.ty())
  // Perform bounds check before anything else.
  guard sub_range_start(self.elements.length(), dst_index, len.to_uint64())
    is Some(dst_start) else {
    raise InitOutOfBounds
  }
  guard sub_range_start(
      element.items.length(),
      src_index.to_uint64(),
      len.to_uint64(),
    )
    is Some(src_start) else {
    raise InitOutOfBounds
  }
  if len == 0 {
    // Bail out early if nothing needs to be initialized.
    // The Wasm spec demands to still perform the bounds check
    // so we cannot bail out earlier.
    return
  }
  if fuel is Some(fuel) {
    fuel.consume_fuel_if(costs => costs.fuel_for_copying_values(len.to_uint64())) catch {
      error => raise TableError::from_fuel_error(error)
    }
  }
  // Perform the actual table initialization.
  for i in 0..<len.reinterpret_as_int() {
    self.elements[dst_start + i] = element.items[src_start + i]
  }
}

///|
/// Copy `len` elements from `src_table[src_index..]` into
/// `dst_table[dst_index..]`.
///
/// # Errors
///
/// Returns an error if the range is out of bounds of either the source or
/// destination tables.
pub fn Table::copy(
  dst_table : Table,
  dst_index : UInt64,
  src_table : Table,
  src_index : UInt64,
  len : UInt64,
  fuel : Fuel?,
) -> Unit raise TableError {
  dst_table.ty().ensure_element_type_matches(src_table.ty().element())
  // Perform bounds check before anything else.
  guard sub_range_start(dst_table.elements.length(), dst_index, len)
    is Some(dst_start) else {
    raise CopyOutOfBounds
  }
  guard sub_range_start(src_table.elements.length(), src_index, len)
    is Some(src_start) else {
    raise CopyOutOfBounds
  }
  if fuel is Some(fuel) {
    fuel.consume_fuel_if(costs => costs.fuel_for_copying_values(len)) catch {
      error => raise TableError::from_fuel_error(error)
    }
  }
  // Finally, copy elements in-place for the table.
  Table::move_elements(
    dst_table.elements,
    dst_start,
    src_table.elements,
    src_start,
    len.to_int(),
  )
}

///|
/// `copy_within` / `copy_from_slice` (handles overlapping ranges).
fn Table::move_elements(
  dst : Array[UntypedVal],
  dst_start : Int,
  src : Array[UntypedVal],
  src_start : Int,
  len : Int,
) -> Unit {
  if physical_equal(dst, src) && dst_start > src_start {
    for i = len - 1; i >= 0; i = i - 1 {
      dst[dst_start + i] = src[src_start + i]
    }
  } else {
    for i in 0..<len {
      dst[dst_start + i] = src[src_start + i]
    }
  }
}

///|
/// Copy `len` elements from `self[src_index..]` into `self[dst_index..]`.
///
/// # Errors
///
/// Returns an error if the range is out of bounds of the table.
pub fn Table::copy_within(
  self : Table,
  dst_index : UInt64,
  src_index : UInt64,
  len : UInt64,
  fuel : Fuel?,
) -> Unit raise TableError {
  // These accesses just perform the bounds checks required by the Wasm spec.
  let max_offset = if dst_index > src_index { dst_index } else { src_index }
  let end = max_offset + len
  if end < max_offset || end > self.size() {
    raise CopyOutOfBounds
  }
  if fuel is Some(fuel) {
    fuel.consume_fuel_if(costs => costs.fuel_for_copying_values(len)) catch {
      error => raise TableError::from_fuel_error(error)
    }
  }
  // Finally, copy elements in-place for the table.
  Table::move_elements(
    self.elements,
    dst_index.to_int(),
    self.elements,
    src_index.to_int(),
    len.to_int(),
  )
}

///|
/// Fill `table[dst..(dst + len)]` with the given value.
///
/// # Errors
///
/// - If `val` has a type mismatch with the element type of the [`Table`].
/// - If the region to be filled is out of bounds for the [`Table`].
/// - If `val` originates from a different [`Store`] than the [`Table`].
pub fn Table::fill(
  self : Table,
  dst : UInt64,
  val : TypedVal,
  len : UInt64,
  fuel : Fuel?,
) -> Unit raise TableError {
  self.ty().ensure_element_type_matches(val.ty())
  self.fill_untyped(dst, val.untyped(), len, fuel)
}

///|
/// Fill `table[dst..(dst + len)]` with the given value.
///
/// # Note
///
/// This is an API for internal use only and exists for efficiency reasons.
///
/// # Errors
///
/// - If the region to be filled is out of bounds for the [`Table`].
pub fn Table::fill_untyped(
  self : Table,
  dst : UInt64,
  val : UntypedVal,
  len : UInt64,
  fuel : Fuel?,
) -> Unit raise TableError {
  guard sub_range_start(self.elements.length(), dst, len) is Some(start) else {
    raise FillOutOfBounds
  }
  if fuel is Some(fuel) {
    fuel.consume_fuel_if(costs => costs.fuel_for_copying_values(len)) catch {
      error => raise TableError::from_fuel_error(error)
    }
  }
  for i in 0..<len.to_int() {
    self.elements[start + i] = val
  }
}
