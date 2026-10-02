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
/// Decompresses a gzip stream, validating the CRC-32 and the size.
pub fn gzip_decompress(data : BytesView) -> Bytes raise InflateError {
  @gzip.gunzip(data.to_owned()) catch {
    @gzip.GzipError(_, msg) => raise InflateError(msg)
  }
}
