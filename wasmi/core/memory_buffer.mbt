// Port of `wasmi_core/src/memory/buffer.rs`.
//
// Upstream's `ByteBuffer` is a `Vec<u8>` (or a `&'static mut [u8]`) split
// into pointer, length and capacity. Here it is a `FixedArray[Byte]` whose
// length is the capacity plus the accessible length `len`. Growing a
// vector-backed buffer beyond its capacity reallocates with amortized
// doubling like `Vec::try_reserve`.
//
// MoonBit arrays are indexed by `Int`, so a buffer cannot be larger than
// [`max_byte_buffer_len`] bytes; requesting more fails like a failed
// allocation upstream (`MemoryError::OutOfSystemMemory`).

///|
/// The maximum length of a [`ByteBuffer`] (the largest MoonBit array length).
let max_byte_buffer_len : UInt64 = 0x7FFF_FFFF

///|
/// A byte buffer implementation.
priv struct ByteBuffer {
  /// The underlying byte buffer (its length is the capacity).
  mut data : FixedArray[Byte]
  /// The current length of the byte buffer.
  ///
  /// # Note
  ///
  /// - **Vec:** `vec.len()`
  /// - **Static:** The accessible subslice of the entire underlying static byte buffer.
  mut len : Int
  /// Whether the [`ByteBuffer`] was initialized from a `&'static [u8]` or a `Vec<u8>`.
  is_static : Bool
}

///|
/// Creates a new byte buffer with the given initial `size` in bytes.
///
/// # Errors
///
/// If the requested amount of heap bytes could not be allocated.
fn ByteBuffer::new(size : UInt64) -> ByteBuffer raise MemoryError {
  if size > max_byte_buffer_len {
    raise OutOfSystemMemory
  }
  let size = size.to_int()
  { data: FixedArray::make(size, 0), len: size, is_static: false, }
}

///|
/// Creates a new static byte buffer with the given `size` in bytes.
///
/// This will zero all the bytes in `buffer[0..initial_len`].
///
/// # Errors
///
/// If `size` is greater than the length of `buffer`.
fn ByteBuffer::new_static(
  buffer : FixedArray[Byte],
  size : UInt64,
) -> ByteBuffer raise MemoryError {
  if size > buffer.length().to_uint64() {
    raise InvalidStaticBufferSize
  }
  let size = size.to_int()
  buffer.fill(0, start=0, end=size)
  { data: buffer, len: size, is_static: true, }
}

///|
/// Grows the byte buffer to the given `new_size`.
///
/// The newly added bytes will be zero initialized.
///
/// # Panics
///
/// - If the current size of the [`ByteBuffer`] is larger than `new_size`.
///
/// # Errors
///
/// - If it is not possible to grow the [`ByteBuffer`] to `new_size`.
///     - `vec`: If the system allocator ran out of memory to allocate.
///     - `static`: If `new_size` is larger than it's the static buffer capacity.
fn ByteBuffer::grow(
  self : ByteBuffer,
  new_size : UInt64,
) -> Unit raise MemoryError {
  if !(self.len.to_uint64() <= new_size) {
    abort("assertion failed: self.len() <= new_size")
  }
  if self.is_static {
    self.grow_static(new_size)
  } else {
    self.grow_vec(new_size)
  }
}

///|
/// Grow the byte buffer to the given `new_size` when backed by a `Vec`.
fn ByteBuffer::grow_vec(
  self : ByteBuffer,
  new_size : UInt64,
) -> Unit raise MemoryError {
  if new_size > max_byte_buffer_len {
    raise OutOfSystemMemory
  }
  let new_size = new_size.to_int()
  let capacity = self.data.length()
  if new_size > capacity {
    // `RawVec` amortized growth: `max(2 * capacity, required)`.
    let doubled = capacity.to_uint64() * 2
    let new_capacity = if doubled > new_size.to_uint64() {
      if doubled > max_byte_buffer_len {
        max_byte_buffer_len.to_int()
      } else {
        doubled.to_int()
      }
    } else {
      new_size
    }
    let data = FixedArray::make(new_capacity, (0 : Byte))
    self.data.blit_to(data, len=self.len)
    self.data = data
  } else {
    self.data.fill(0, start=self.len, end=new_size)
  }
  self.len = new_size
}

///|
/// Grow the byte buffer to the given `new_size` when backed by a `&'static [u8]`.
fn ByteBuffer::grow_static(
  self : ByteBuffer,
  new_size : UInt64,
) -> Unit raise MemoryError {
  if self.data.length().to_uint64() < new_size {
    raise InvalidStaticBufferSize
  }
  let new_size = new_size.to_int()
  self.data.fill(0, start=self.len, end=new_size)
  self.len = new_size
}
