// Port of `wasmi_core/src/memory/mod.rs`.
//
// Upstream `usize` sizes and offsets are `UInt64` (a 64-bit `usize`).

///|
/// A Wasm linear memory.
pub struct Memory {
  /// The underlying buffer that stores the bytes of the memory.
  priv bytes : ByteBuffer
  /// The underlying type of the memory.
  priv memory_type : MemoryType
}

///|
/// `u64::MAX + 1` (`usize::MAX + 1`).
fn bigint_two_pow_64() -> @bigint.BigInt {
  @bigint.BigInt::from_int(1) << 64
}

///|
/// Creates a new [`Memory`] with the given `memory_type`.
///
/// # Errors
///
/// If creation of the linear memory fails or is disallowed by the `limiter`.
pub fn Memory::new(
  memory_type : MemoryType,
  limiter : ResourceLimiterRef,
) -> Memory raise MemoryError {
  Memory::new_impl(memory_type, limiter, ByteBuffer::new)
}

///|
/// Creates a new static [`Memory`] with the given `memory_type`.
///
/// # Note
///
/// This uses `buffer` to store its bytes and won't perform heap allocations.
///
/// # Errors
///
/// If creation of the linear memory fails or is disallowed by the `limiter`.
pub fn Memory::new_static(
  memory_type : MemoryType,
  limiter : ResourceLimiterRef,
  buffer : FixedArray[Byte],
) -> Memory raise MemoryError {
  Memory::new_impl(memory_type, limiter, initial_size => {
    ByteBuffer::new_static(buffer, initial_size)
  })
}

///|
#warnings("-fragile_catch_all")
fn Memory::new_impl(
  memory_type : MemoryType,
  limiter : ResourceLimiterRef,
  make_buffer : (UInt64) -> ByteBuffer raise MemoryError,
) -> Memory raise MemoryError {
  let min_size = memory_type.minimum_byte_size() catch {
    _ => raise MinimumSizeOverflow
  }
  if min_size >= bigint_two_pow_64() {
    raise MinimumSizeOverflow
  }
  let min_size = min_size.to_uint64()
  let max_size = match memory_type.maximum() {
    Some(max) => {
      let max = @bigint.BigInt::from_uint64(max)
      if max > memory_type.absolute_max() {
        raise MaximumSizeOverflow
      }
      // Note: We have to clip `max_size` at `usize::MAX` since we do not want to
      //       error if the system limits are overflown here. This is because Wasm
      //       memories grow lazily and thus creation of memories which have a max
      //       size that overflows system limits are valid as long as they do not
      //       grow beyond those limits.
      let max_size = max << memory_type.page_size_log2().to_int()
      Some(
        if max_size >= bigint_two_pow_64() {
          0xFFFF_FFFF_FFFF_FFFFUL
        } else {
          max_size.to_uint64()
        },
      )
    }
    None => None
  }
  if limiter.as_resource_limiter() is Some(limiter) {
    let growing = limiter.memory_growing(0, min_size, max_size) catch {
      error => raise MemoryError::from_limiter_error(error)
    }
    if !growing {
      raise ResourceLimiterDeniedAllocation
    }
  }
  let bytes = make_buffer(min_size) catch {
    error => {
      if limiter.as_resource_limiter() is Some(limiter) {
        limiter.memory_grow_failed(LimiterError::from_memory_error(error))
      }
      raise error
    }
  }
  { bytes, memory_type, }
}

///|
/// Returns the memory type of the linear memory.
pub fn Memory::ty(self : Memory) -> MemoryType {
  self.memory_type
}

///|
/// Returns the dynamic [`MemoryType`] of the [`Memory`].
///
/// # Note
///
/// This respects the current size of the [`Memory`] as
/// its minimum size and is useful for import subtyping checks.
pub fn Memory::dynamic_ty(self : Memory) -> MemoryType {
  let current_pages = self.size()
  let maximum_pages = self.ty().maximum()
  let page_size_log2 = self.ty().page_size_log2()
  let is_64 = self.ty().is_64()
  let b = MemoryType::builder()
  b.min(current_pages) |> ignore
  b.max(maximum_pages) |> ignore
  b.page_size_log2(page_size_log2) |> ignore
  b.memory64(is_64) |> ignore
  b.build() catch {
    _ => abort("must result in valid memory type due to invariants")
  }
}

///|
/// Returns the size, in WebAssembly pages, of this Wasm linear memory.
pub fn Memory::size(self : Memory) -> UInt64 {
  self.bytes.len.to_uint64() >> self.memory_type.page_size_log2().to_int()
}

///|
/// Returns the size of this Wasm linear memory in bytes.
fn Memory::size_in_bytes(self : Memory) -> UInt64 {
  // Note: `pages * bytes_per_page` cannot overflow since the buffer length
  // is a multiple of the page size.
  let pages = self.size()
  let bytes_per_page = self.memory_type.page_size().to_uint64()
  pages * bytes_per_page
}

///|
/// Returns the maximum size of this Wasm linear memory in bytes if any.
fn Memory::max_size_in_bytes(self : Memory) -> UInt64? {
  guard self.memory_type.maximum() is Some(max_pages) else { return None }
  let bytes_per_page = self.memory_type.page_size().to_uint64()
  if bytes_per_page != 1 && max_pages > 0xFFFF_FFFF_FFFF_FFFFUL / bytes_per_page {
    abort(
      "unexpected out of bounds linear memory maximum size: (max_pages = \{max_pages}, bytes_per_page = \{bytes_per_page})",
    )
  }
  Some(max_pages * bytes_per_page)
}

///|
fn Memory::notify_limiter(
  limiter : ResourceLimiterRef,
  err : MemoryError,
) -> UInt64 raise MemoryError {
  if limiter.as_resource_limiter() is Some(limiter) {
    limiter.memory_grow_failed(LimiterError::from_memory_error(err))
  }
  raise err
}

///|
/// Grows the linear memory by the given amount of new pages.
///
/// Returns the amount of pages before the operation upon success.
///
/// # Errors
///
/// - If the linear memory cannot be grown to the target size.
/// - If the `limiter` denies the growth operation.
pub fn Memory::grow(
  self : Memory,
  additional : UInt64,
  fuel : Fuel?,
  limiter : ResourceLimiterRef,
) -> UInt64 raise MemoryError {
  if additional == 0 {
    return self.size()
  }
  let current_byte_size = self.size_in_bytes()
  let maximum_byte_size = self.max_size_in_bytes()
  let current_size = self.size()
  let desired_size = current_size + additional
  if desired_size < current_size {
    raise OutOfBoundsGrowth
  }
  if @bigint.BigInt::from_uint64(desired_size) > self.memory_type.absolute_max() {
    raise OutOfBoundsGrowth
  }
  if self.memory_type.maximum() is Some(maximum_size) {
    if desired_size > maximum_size {
      raise OutOfBoundsGrowth
    }
  }
  let bytes_per_page = self.memory_type.page_size().to_uint64()
  if bytes_per_page != 1 &&
    desired_size > 0xFFFF_FFFF_FFFF_FFFFUL / bytes_per_page {
    raise OutOfBoundsGrowth
  }
  let desired_byte_size = desired_size * bytes_per_page

  // The `ResourceLimiter` gets first look at the request.
  if limiter.as_resource_limiter() is Some(limiter) {
    let allowed = limiter.memory_growing(
      current_byte_size, desired_byte_size, maximum_byte_size,
    ) catch {
      error => raise MemoryError::from_limiter_error(error)
    }
    if !allowed {
      raise OutOfBoundsGrowth
    }
  }

  // Optionally check if there is enough fuel for the operation.
  //
  // This is deliberately done right before the actual growth operation in order to
  // not charge fuel if there is any other deterministic failure preventing the expensive
  // growth operation.
  if fuel is Some(fuel) {
    // Note: "additional size is within [min, max) page bounds"
    let additional_bytes = additional * bytes_per_page
    fuel.consume_fuel_if(costs => costs.fuel_for_copying_bytes(additional_bytes)) catch {
      OutOfFuel(required_fuel~) =>
        return Memory::notify_limiter(limiter, OutOfFuel(required_fuel~))
      FuelMeteringDisabled => ()
    }
  }
  // At this point all checks passed to grow the linear memory:
  //
  // 1. The resource limiter validated the memory consumption.
  // 2. The growth is within bounds.
  // 3. There is enough fuel for the operation.
  //
  // Only the actual growing of the underlying byte buffer may now fail.
  self.bytes.grow(desired_byte_size) catch {
    error => return Memory::notify_limiter(limiter, error)
  }
  current_size
}

///|
/// Returns a shared slice to the bytes underlying to the byte buffer.
///
/// # Note
///
/// The returned buffer may be longer than the memory: only the first
/// [`Memory::data_size`] bytes belong to it. The buffer is replaced when the
/// memory grows beyond its capacity, so it must be fetched again after
/// [`Memory::grow`].
pub fn Memory::data(self : Memory) -> FixedArray[Byte] {
  self.bytes.data
}

///|
/// Returns an exclusive slice to the bytes underlying to the byte buffer.
///
/// See [`Memory::data`].
pub fn Memory::data_mut(self : Memory) -> FixedArray[Byte] {
  self.bytes.data
}

///|
/// Returns the byte length of this [`Memory`].
///
/// The returned value will be a multiple of the wasm page size, 64k.
pub fn Memory::data_size(self : Memory) -> Int {
  self.bytes.len
}

///|
/// Returns the index span for the memory access at `start..(start+len)`
/// if it lies within the memory.
fn Memory::access_span(
  self : Memory,
  start : UInt64,
  len : Int,
) -> Int raise MemoryError {
  let end = start + len.to_uint64()
  if end < start {
    raise OutOfBoundsAccess
  }
  if end > self.bytes.len.to_uint64() {
    raise OutOfBoundsAccess
  }
  start.to_int()
}

///|
/// Reads `n` bytes from `memory[offset..offset+n]` into `buffer`
/// where `n` is the length of `buffer`.
///
/// # Errors
///
/// If this operation accesses out of bounds linear memory.
pub fn Memory::read(
  self : Memory,
  offset : UInt64,
  buffer : FixedArray[Byte],
) -> Unit raise MemoryError {
  let start = self.access_span(offset, buffer.length())
  self.bytes.data.blit_to(buffer, len=buffer.length(), src_offset=start)
}

///|
/// Writes `n` bytes to `memory[offset..offset+n]` from `buffer`
/// where `n` if the length of `buffer`.
///
/// # Errors
///
/// If this operation accesses out of bounds linear memory.
pub fn Memory::write(
  self : Memory,
  offset : UInt64,
  buffer : BytesView,
) -> Unit raise MemoryError {
  let start = self.access_span(offset, buffer.length())
  self.bytes.data.blit_from_bytesview(start, buffer)
}
