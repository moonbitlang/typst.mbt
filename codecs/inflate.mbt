// DEFLATE decompression with zlib (RFC 1950) and gzip (RFC 1952) framing, on
// top of `moonbit-community/flate`. Upstream uses the `png` crate (IDAT; it
// ignores the Adler-32 checksum by default), `fdeflate::decompress_to_vec_
// bounded` (PNG `iCCP` chunks) and `flate2`'s `GzDecoder` (SVGZ files);
// decompression is deterministic, so any conforming inflater yields the same
// bytes.

///|
/// A decompression error.
pub(all) suberror InflateError {
  InflateError(String)
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InflateError with @debug.Debug::{to_repr}

///|
/// Decompresses a zlib stream. With `verify_checksum`, the Adler-32 trailer
/// must match and no bytes may hide between the DEFLATE body and the trailer;
/// without it (like the `png` crate's default for image data), the DEFLATE
/// payload is decoded and anything after its final block is ignored.
pub fn zlib_decompress(
  data : BytesView,
  verify_checksum? : Bool = true,
) -> Bytes raise InflateError {
  if verify_checksum {
    @zlib.zlib_decompress(data.to_owned()) catch {
      @zlib.ZlibError(_, msg) => raise InflateError(msg)
    }
  } else {
    if data.length() < 2 {
      raise InflateError("unexpected end of stream")
    }
    let cmf = data[0].to_int()
    let flg = data[1].to_int()
    if (cmf & 0x0F) != 8 || (cmf * 256 + flg) % 31 != 0 || (flg & 0x20) != 0 {
      raise InflateError("invalid zlib header")
    }
    @flate.inflate_all(data[2:].to_owned()) catch {
      @flate.InflateError(_, msg) => raise InflateError(msg)
    }
  }
}

///|
/// Decompresses a zlib (or, if `!zlib`, a raw DEFLATE) stream like
/// `flate2`'s `read_to_end` (used by hayro-syntax): input that ends
/// prematurely yields the output decoded so far (a truncated stream is not an
/// error), while corrupt data and a wrong checksum are errors.
pub fn inflate_read_to_end(
  data : BytesView,
  zlib~ : Bool,
) -> Bytes raise InflateError {
  let mut input = data
  if zlib {
    if data.length() < 2 {
      return b""
    }
    let cmf = data[0].to_int()
    let flg = data[1].to_int()
    if (cmf & 0x0F) != 8 || (cmf * 256 + flg) % 31 != 0 || (flg & 0x20) != 0 {
      raise InflateError("invalid zlib header")
    }
    input = data[2:]
  }
  let inflater = @flate.Inflater::Inflater()
  let out = Buffer()
  let chunk = FixedArray::make(65536, b'\x00')
  let mut done = false
  while true {
    let status = inflater.step_into(input, chunk) catch {
      @flate.InflateError(_, msg) => raise InflateError(msg)
    }
    for i in 0..<inflater.last_produced() {
      out.write_byte(chunk[i])
    }
    input = input[inflater.last_consumed():]
    match status {
      Done => {
        done = true
        break
      }
      NeedMoreOutput => continue
      // Truncated stream: keep what was decoded.
      NeedMoreInput => break
    }
  }
  let out = out.to_bytes()
  if zlib && done && input.length() >= 4 {
    let checksum = Adler32::new()
    checksum.write(out[:])
    if checksum.finish() != u32_be(input, 0) {
      raise InflateError("wrong checksum")
    }
  }
  out
}

///|
/// Decompresses a gzip stream, validating the CRC-32 and the size.
pub fn gzip_decompress(data : BytesView) -> Bytes raise InflateError {
  @gzip.gunzip(data.to_owned()) catch {
    @gzip.GzipError(_, msg) => raise InflateError(msg)
  }
}
