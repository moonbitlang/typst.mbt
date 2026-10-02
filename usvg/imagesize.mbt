// The parts of `imagesize` 0.14.0 that usvg uses: `image_type` (only
// whether the data is a JPEG, PNG, GIF or WebP matters to usvg) and
// `blob_size` for those four formats.
//
// Deviation: `blob_size` of data in any other format (BMP, TIFF, ...)
// returns `None`, whereas upstream reports its size. usvg only calls it for
// images it classified as JPEG/PNG/GIF/WebP (by MIME type or magic bytes).

///|
priv enum ImageSizeType {
  Jpeg
  Png
  Gif
  Webp
  Other
} derive(Eq)

///|
fn imagesize_image_type(data : Bytes) -> ImageSizeType? {
  // `read_exact` of a 12-byte header.
  if data.length() < 12 {
    return None
  }
  let starts_with = (prefix : Array[Byte]) => {
    for i, b in prefix {
      if data[i] != b {
        return false
      }
    }
    true
  }
  if starts_with([b'\xFF', b'\xD8', b'\xFF']) {
    Some(Jpeg)
  } else if starts_with([b'\x89', b'P', b'N', b'G']) {
    Some(Png)
  } else if starts_with([b'G', b'I', b'F', b'8']) {
    Some(Gif)
  } else if starts_with([b'R', b'I', b'F', b'F']) &&
    data[8] == b'W' &&
    data[9] == b'E' &&
    data[10] == b'B' &&
    data[11] == b'P' {
    Some(Webp)
  } else {
    Some(Other)
  }
}

///|
/// `imagesize::blob_size`: the `(width, height)` of an image.
fn imagesize_blob_size(data : Bytes) -> (Int, Int)? {
  let n = data.length()
  let u16_be = (pos : Int) => if pos + 2 <= n {
    Some((data[pos].to_int() << 8) | data[pos + 1].to_int())
  } else {
    None
  }
  let u16_le = (pos : Int) => if pos + 2 <= n {
    Some((data[pos + 1].to_int() << 8) | data[pos].to_int())
  } else {
    None
  }
  let u24_le = (pos : Int) => if pos + 3 <= n {
    Some(
      (data[pos + 2].to_int() << 16) |
      (data[pos + 1].to_int() << 8) |
      data[pos].to_int(),
    )
  } else {
    None
  }
  let u32_be = (pos : Int) => if pos + 4 <= n {
    Some(
      (data[pos].to_uint() << 24) |
      (data[pos + 1].to_uint() << 16) |
      (data[pos + 2].to_uint() << 8) |
      data[pos + 3].to_uint(),
    )
  } else {
    None
  }
  let u32_le = (pos : Int) => if pos + 4 <= n {
    Some(
      (data[pos + 3].to_uint() << 24) |
      (data[pos + 2].to_uint() << 16) |
      (data[pos + 1].to_uint() << 8) |
      data[pos].to_uint(),
    )
  } else {
    None
  }
  match imagesize_image_type(data)? {
    Png => {
      let w = u32_be(0x10)?
      let h = u32_be(0x14)?
      Some((w.reinterpret_as_int(), h.reinterpret_as_int()))
    }
    Gif => Some((u16_le(6)?, u16_le(8)?))
    Jpeg => {
      let mut pos = 2
      let mut depth = 0
      while true {
        if pos + 2 > n {
          return None
        }
        let marker0 = data[pos]
        let page = data[pos + 1].to_int()
        pos += 2
        if marker0 != b'\xFF' {
          return None
        }
        if (page >= 0xC0 && page <= 0xC3) ||
          (page >= 0xC5 && page <= 0xC7) ||
          (page >= 0xC9 && page <= 0xCB) ||
          (page >= 0xCD && page <= 0xCF) {
          if depth == 0 {
            pos += 3
            break
          }
        } else if page == 0xD8 {
          depth += 1
        } else if page == 0xD9 {
          depth -= 1
          if depth < 0 {
            return None
          }
        }
        let page_size = u16_be(pos)?
        pos += 2
        pos = pos + page_size - 2
        if pos < 0 {
          return None
        }
      }
      let h = u16_be(pos)?
      let w = u16_be(pos + 2)?
      Some((w, h))
    }
    Webp => {
      if n < 16 {
        return None
      }
      match data[15] {
        b' ' => Some((u16_le(0x1A)?, u16_le(0x1C)?))
        b'L' => {
          let dims = u32_le(0x15)?
          Some(
            (
              (dims & 0x3FFF).reinterpret_as_int() + 1,
              ((dims >> 14) & 0x3FFF).reinterpret_as_int() + 1,
            ),
          )
        }
        b'X' => Some((u24_le(0x18)? + 1, u24_le(0x1B)? + 1))
        _ => None
      }
    }
    Other => None
  }
}
