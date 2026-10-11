// Port of flate2 1.1.10's `write::ZlibEncoder` (`src/zlib/write.rs`,
// `src/zio.rs` `Writer`, `src/mem.rs` `Compress`) over the zlib-rs backend
// (`src/ffi/zlib_rs.rs`), writing into an in-memory buffer.
//
// The block boundaries of the compressed stream depend on how the input is
// fed to `deflate` and on the output buffer size, so the streaming pattern is
// reproduced: every `deflate` call gets the 32 KiB spare capacity of the
// writer's internal buffer, which is drained into the sink before each call.

///|
/// The capacity of `zio::Writer`'s internal buffer
/// (`Vec::with_capacity(32 * 1024)`).
const ZIO_BUF_CAPACITY : Int = 32768

///|
/// A zlib encoder writing into an in-memory buffer (upstream
/// `flate2::write::ZlibEncoder<Vec<u8>>`).
pub struct ZlibEncoder {
  priv data : DeflateStream
  priv obj : OutBuf
}

///|
/// Creates a new encoder with the given compression level (upstream
/// `ZlibEncoder::new(Vec::new(), Compression::new(level))`).
///
/// Only the levels handled by zlib-rs's `deflate_medium` (3..=6) are ported.
pub fn ZlibEncoder::new(level : Int) -> ZlibEncoder {
  { data: DeflateStream::new(level), obj: OutBuf::new(), }
}

///|
/// Upstream `Writer::write_with_status`: compresses as much of the input
/// (`array[off..off + len]`, or `view` if `array` is `None`) as possible and
/// returns the number of bytes consumed.
fn ZlibEncoder::write(
  self : ZlibEncoder,
  view : BytesView,
  array : FixedArray[Byte]?,
  off : Int,
  len : Int,
) -> Int {
  // miniz isn't guaranteed to actually write any of the buffer provided, it
  // may be in a flushing mode where it's just giving us data before we're
  // actually giving it any data. We don't want to spuriously return `Ok(0)`
  // when possible as it will cause calls to write_all() to fail. As a result
  // we execute this in a loop to ensure that we try our darndest to write the
  // data.
  while true {
    let r = self.data.compress(
      view,
      array,
      off,
      len,
      self.obj,
      ZIO_BUF_CAPACITY,
      FLUSH_NO,
    )
    guard r.ret >= 0 || r.ret == Z_BUF_ERROR else {
      abort("corrupt deflate stream")
    }
    if len != 0 && r.consumed == 0 && r.ret != Z_STREAM_END {
      continue
    }
    return r.consumed
  }
  0
}

///|
/// Writes all of `buf` into the encoder (upstream `Write::write_all`).
pub fn ZlibEncoder::write_all(self : ZlibEncoder, buf : BytesView) -> Unit {
  let mut buf = buf
  while buf.length() > 0 {
    let n = self.write(buf, None, 0, buf.length())
    guard n > 0 else { abort("failed to write whole buffer") }
    buf = buf[n:]
  }
}

///|
/// [ZlibEncoder::write_all] of `array[off..off + len]` (without copying it
/// into a `Bytes`).
fn ZlibEncoder::write_all_array(
  self : ZlibEncoder,
  array : FixedArray[Byte],
  off : Int,
  len : Int,
) -> Unit {
  let mut off = off
  let mut len = len
  while len > 0 {
    let n = self.write(b""[:], Some(array), off, len)
    guard n > 0 else { abort("failed to write whole buffer") }
    off += n
    len -= n
  }
}

///|
/// Finishes the stream and returns the compressed data (upstream
/// `ZlibEncoder::finish`).
pub fn ZlibEncoder::finish(self : ZlibEncoder) -> Bytes {
  while true {
    let before = self.data.total_out
    let r = self.data.compress(
      b""[:],
      None,
      0,
      0,
      self.obj,
      ZIO_BUF_CAPACITY,
      FLUSH_FINISH,
    )
    guard r.ret >= 0 || r.ret == Z_BUF_ERROR else {
      abort("corrupt deflate stream")
    }
    if before == self.data.total_out {
      break
    }
  }
  self.obj.to_bytes()
}

///|
/// Compresses `data` into a zlib stream with the given level (3..=6), as
/// upstream `ZlibEncoder::new(Vec::new(), Compression::new(level))` followed
/// by `write_all(data)` and `finish()`.
pub fn zlib_compress(data : BytesView, level~ : Int = 6) -> Bytes {
  let encoder = ZlibEncoder::new(level)
  encoder.write_all(data)
  encoder.finish()
}
