// The damaged PNGs of the oracle `png_oracle_test.mbt`: the same damage as
// `damage` in `oracle/src/bin/gen_png_golden.rs` (keep the two equal: the
// cases are matched with the expectations by their order), applied to the
// seeds of `oracle/src/bin/png_corpus.txt`.

///|
/// xorshift32
priv struct PngDamageRng {
  mut state : UInt
}

///|
fn PngDamageRng::next(self : PngDamageRng) -> UInt {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  x
}

///|
priv struct PngDamageChunk {
  ty : Bytes
  data : Bytes
}

///|
priv struct PngDamageCase {
  desc : String
  data : Bytes
  /// Decode with the limits of `png::Decoder::new` instead of `image`'s.
  direct : Bool
}

///|
fn png_damage_u32(data : Bytes, pos : Int) -> UInt {
  (data[pos].to_uint() << 24) |
  (data[pos + 1].to_uint() << 16) |
  (data[pos + 2].to_uint() << 8) |
  data[pos + 3].to_uint()
}

///|
fn png_damage_write_u32(out : Buffer, v : UInt) -> Unit {
  out.write_byte((v >> 24).to_byte())
  out.write_byte((v >> 16).to_byte())
  out.write_byte((v >> 8).to_byte())
  out.write_byte(v.to_byte())
}

///|
/// The chunks of a valid PNG.
fn png_damage_parse(seed : Bytes) -> Array[PngDamageChunk] {
  let chunks = []
  let mut pos = 8
  while pos < seed.length() {
    let len = png_damage_u32(seed, pos).reinterpret_as_int()
    chunks.push({
      ty: seed[pos + 4:pos + 8].to_owned(),
      data: seed[pos + 8:pos + 8 + len].to_owned(),
    })
    pos += 12 + len
  }
  chunks
}

///|
fn png_damage_write_chunk(out : Buffer, chunk : PngDamageChunk) -> Unit {
  png_damage_write_u32(out, chunk.data.length().reinterpret_as_uint())
  out.write_bytes(chunk.ty)
  out.write_bytes(chunk.data)
  png_damage_write_u32(out, @codecs.crc32([chunk.ty[:], chunk.data[:]]))
}

///|
/// A PNG of the chunks, with their CRCs.
fn png_damage_build(chunks : ArrayView[PngDamageChunk]) -> Bytes {
  let out = Buffer()
  out.write_bytes(b"\x89PNG\r\n\x1a\n")
  for chunk in chunks {
    png_damage_write_chunk(out, chunk)
  }
  out.to_bytes()
}

///|
/// `data` with bit `b` of byte `i` flipped.
fn png_damage_flip(data : Bytes, i : Int, b : Int) -> Bytes {
  Bytes::makei(data.length(), j => {
    if j == i {
      data[j] ^ (1 << b).to_byte()
    } else {
      data[j]
    }
  })
}

///|
/// `chunks` with chunk `k` replaced.
fn png_damage_with(
  chunks : Array[PngDamageChunk],
  k : Int,
  data : Bytes,
) -> Array[PngDamageChunk] {
  let chunks = chunks.copy()
  chunks[k] = { ty: chunks[k].ty, data, }
  chunks
}

///|
/// The damaged files of a seed, in the order of the expectations.
fn png_damage(seed : Bytes, seed_index : Int) -> Array[PngDamageCase] {
  let cases : Array[PngDamageCase] = []
  fn add(desc : String, data : Bytes) {
    cases.push({ desc, data, direct: false, })
  }

  let len = seed.length()
  let rng = {
    state: 0x9E3779B9U ^ ((seed_index + 1).reinterpret_as_uint() * 0x85EBCA6BU),
  }

  // Every single-bit flip in the first 64 bytes, and a sample in the rest.
  for i in 0..<@cmp.minimum(len, 64) {
    for b in 0..<8 {
      add("flip \{i}.\{b}", png_damage_flip(seed, i, b))
    }
  }
  if len > 64 {
    let step = @cmp.maximum((len - 64) / 96, 1)
    for i = 64; i < len; i = i + step {
      let b = (rng.next() % 8).reinterpret_as_int()
      add("flip \{i}.\{b}", png_damage_flip(seed, i, b))
    }
  }

  // Truncation at every length (of a long file: at the first 200, the
  // last 100 and a hundred lengths between).
  let step = if len <= 400 { 1 } else { @cmp.maximum((len - 300) / 100, 1) }
  let mut n = 0
  while n < len {
    add("trunc \{n}", seed[:n].to_owned())
    n += if n < 200 || n + 100 >= len { 1 } else { step }
  }

  // Bit flips in the data of every chunk, with the right CRC: every bit
  // of a chunk of up to 13 bytes, two bits of every byte of one of up to
  // 40 bytes, and of the first and the last 8 bytes and of 24 bytes
  // between of a longer one.
  let chunks = png_damage_parse(seed)
  for k, c in chunks {
    let m = c.data.length()
    let name = @utf8.decode_lossy(c.ty)
    let positions : Array[Int] = []
    if m <= 40 {
      for p in 0..<m {
        positions.push(p)
      }
    } else {
      for p in 0..<8 {
        positions.push(p)
      }
      let step = @cmp.maximum((m - 16) / 24, 1)
      let mut p = 8
      while p < m - 8 && positions.length() < 32 {
        positions.push(p)
        p += step
      }
      for p in (m - 8)..<m {
        positions.push(p)
      }
    }
    for p in positions {
      let bits : Array[Int] = if m <= 13 {
        [0, 1, 2, 3, 4, 5, 6, 7]
      } else {
        let b = (rng.next() % 8).reinterpret_as_int()
        [b, (b + 1 + (rng.next() % 7).reinterpret_as_int()) % 8]
      }
      for b in bits {
        add(
          "fix \{k}:\{name} \{p}.\{b}",
          png_damage_build(
            png_damage_with(chunks, k, png_damage_flip(c.data, p, b))[:],
          ),
        )
      }
    }
  }

  // The chunk structure.
  let n = chunks.length()
  for k in 0..<n {
    let name = @utf8.decode_lossy(chunks[k].ty)
    // A wrong CRC.
    let out = Buffer()
    out.write_bytes(b"\x89PNG\r\n\x1a\n")
    let mut crc_at = 0
    for j, c in chunks {
      png_damage_write_chunk(out, c)
      if j == k {
        crc_at = out.length() - 1
      }
    }
    add("badcrc \{k}:\{name}", png_damage_flip(out.to_bytes(), crc_at, 0))
    // Without the chunk.
    let c = chunks.copy()
    let _ = c.remove(k)
    add("del \{k}:\{name}", png_damage_build(c[:]))
    // The chunk twice.
    let c = chunks.copy()
    c.insert(k, chunks[k])
    add("dup \{k}:\{name}", png_damage_build(c[:]))
    // The chunk and the next one in the other order.
    if k + 1 < n {
      let c = chunks.copy()
      c.swap(k, k + 1)
      add("swap \{k}:\{name}", png_damage_build(c[:]))
    }
    // The chunk right after the header.
    if k >= 2 {
      let c = chunks.copy()
      let moved = c.remove(k)
      c.insert(1, moved)
      add("first \{k}:\{name}", png_damage_build(c[:]))
    }
    // The chunk after the end.
    if k + 1 < n {
      let c = chunks.copy()
      let moved = c.remove(k)
      c.push(moved)
      add("last \{k}:\{name}", png_damage_build(c[:]))
    }
    // The chunk without data.
    add(
      "empty \{k}:\{name}",
      png_damage_build(png_damage_with(chunks, k, b"")[:]),
    )
    // The chunk with one more byte.
    add(
      "grow \{k}:\{name}",
      png_damage_build(png_damage_with(chunks, k, chunks[k].data + b"\x00")[:]),
    )
  }
  // Eight and seven zero bytes instead of the last chunk; bytes after it.
  let without_last = png_damage_build(chunks[:n - 1])
  add("tail8", without_last + Bytes::make(8, 0))
  add("tail7", without_last + Bytes::make(7, 0))
  add("garbage", seed + Bytes::make(64, 0xAA))
  // The image data: the chunks before and after it, and its bytes.
  let mut first = -1
  let mut last = -1
  for k, c in chunks {
    if c.ty == b"IDAT" {
      if first < 0 {
        first = k
      }
      last = k
    }
  }
  let idat = {
    let out = Buffer()
    for k in first..<=last {
      out.write_bytes(chunks[k].data)
    }
    out.to_bytes()
  }
  fn chunk(ty : Bytes, data : Bytes) -> PngDamageChunk {
    { ty, data, }
  }

  fn with_idat(parts : Array[PngDamageChunk]) -> Bytes {
    let c = chunks[:first].to_owned()
    c.append(parts)
    c.append(chunks[last + 1:].to_owned())
    png_damage_build(c[:])
  }

  // In chunks of one byte, and in one chunk.
  add(
    "idat1",
    with_idat(
      Array::makei(idat.length(), i => chunk(b"IDAT", idat[i:i + 1].to_owned())),
    ),
  )
  add("idatall", with_idat([chunk(b"IDAT", idat)]))
  // Empty chunks of image data around it.
  add(
    "idat0",
    with_idat([chunk(b"IDAT", b""), chunk(b"IDAT", idat), chunk(b"IDAT", b"")]),
  )
  // Another chunk in the middle of the image data.
  let half = idat.length() / 2
  add(
    "idatsep",
    with_idat([
      chunk(b"IDAT", idat[:half].to_owned()),
      chunk(b"tEXt", b"k\x00v"),
      chunk(b"IDAT", idat[half:].to_owned()),
    ]),
  )
  // A wrong Adler-32: one bit, and all of it.
  let end = idat.length()
  add("adler", with_idat([chunk(b"IDAT", png_damage_flip(idat, end - 1, 0))]))
  add(
    "adler0",
    with_idat([chunk(b"IDAT", idat[:end - 4].to_owned() + Bytes::make(4, 0))]),
  )
  // The zlib stream cut (by 2, 5 and 9 bytes and to its half) and
  // followed by more bytes.
  for cut in [2, 5, 9, end - half] {
    add("zcut \{cut}", with_idat([chunk(b"IDAT", idat[:end - cut].to_owned())]))
  }
  add("zextra", with_idat([chunk(b"IDAT", idat + Bytes::make(16, 0x55))]))
  // Bit flips in the zlib stream (with the right CRC): two bits of every
  // byte, of three hundred bytes of a long stream.
  let step = @cmp.maximum(end / 300, 1)
  for p = 0; p < end; p = p + step {
    let b = (rng.next() % 8).reinterpret_as_int()
    for b in [b, (b + 1 + (rng.next() % 7).reinterpret_as_int()) % 8] {
      add(
        "z \{p}.\{b}",
        with_idat([chunk(b"IDAT", png_damage_flip(idat, p, b))]),
      )
    }
  }
  // Unknown chunks after the header: a critical one and an ancillary one.
  for ty in [b"ABCD", b"abCd"] {
    let c = chunks.copy()
    c.insert(1, chunk(ty, b"xy"))
    add("unknown \{@utf8.decode_lossy(ty)}", png_damage_build(c[:]))
  }
  // Every byte in a chunk type (the first seed only): the type is printed
  // in the error of a critical chunk.
  if seed_index == 0 {
    for pos in 0..<2 {
      for v in 0..<256 {
        let ty = Bytes::makei(4, j => {
          if j == pos {
            v.to_byte()
          } else {
            b"ABCD"[j]
          }
        })
        let c = chunks.copy()
        c.insert(1, chunk(ty, b"xy"))
        add("type \{pos}:\{v}", png_damage_build(c[:]))
      }
    }
  }

  // Other dimensions in the header (with the right CRC). An interlaced
  // image is not made wider than 2^24 + 1 pixels: upstream fills a buffer
  // of a row of the full width before it reads the first row.
  let ihdr = chunks[0].data
  let width = png_damage_u32(ihdr, 0)
  let height = png_damage_u32(ihdr, 4)
  let interlaced = ihdr[12] != 0
  let dims : Array[(UInt, UInt)] = [
    (0, height),
    (width, 0),
    (1, 1),
    (width + 1, height),
    (width, height + 1),
    (width - 1, height),
    (width, height - 1),
    (2 * width, height),
    (width, 2 * height),
    (65536, 65536),
    ((1U << 24) + 1, height),
    (width, 0x7FFFFFFF),
    (width, 0xFFFFFFFF),
    (1U << 20, 1U << 20),
    (0xFFFFFFFF, 0xFFFFFFFF),
  ]
  if !interlaced {
    dims.push((0x7FFFFFFF, height))
    dims.push((0x80000000, 1))
    dims.push((0x7FFFFFFF, 0x7FFFFFFF))
  }
  for dim in dims {
    let (w, h) = dim
    let out = Buffer()
    png_damage_write_u32(out, w)
    png_damage_write_u32(out, h)
    out.write_bytesview(ihdr[8:])
    let data = png_damage_build(png_damage_with(chunks, 0, out.to_bytes())[:])
    cases.push({ desc: "dims \{w}x\{h}", data, direct: false, })
    cases.push({ desc: "dims \{w}x\{h} direct", data, direct: true, })
  }
  cases
}

///|
/// What the decoder makes of a PNG, in the terms of `decode_image` and
/// `decode_direct` in `gen_png_golden.rs` (like `image_case`).
fn png_damage_outcome_of(data : Bytes, direct : Bool) -> String {
  let (info, buf) = try {
    if direct {
      @codecs.decode_png(data, limits=Default)
    } else {
      @codecs.decode_png(data)
    }
  } catch {
    @codecs.ImageError(msg) => return "error: \{msg}"
  }
  let h = webp_fnv1a(buf).to_string(radix=16)
  let color = match info.color {
    L8 => "L8"
    La8 => "La8"
    Rgb8 => "Rgb8"
    Rgba8 => "Rgba8"
    L16 => "L16"
    La16 => "La16"
    Rgb16 => "Rgb16"
    Rgba16 => "Rgba16"
  }
  let icc = match info.icc {
    Some(icc) if !icc.is_empty() => icc.length().to_string()
    _ => "none"
  }
  "\{info.width}x\{info.height} \{color} \{String::make(16 - h.length(), '0')}\{h} icc=\{icc}"
}

///|
/// 24 bits of the FNV-1a hash of an outcome, as four characters.
fn png_damage_short_hash(outcome : String) -> String {
  let mut h = 0x811c9dc5U
  for b in @utf8.encode(outcome) {
    h = h ^ b.to_uint()
    h = h * 0x01000193U
  }
  let h = (h ^ (h >> 24)) & 0xFFFFFF
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  let out = StringBuilder()
  for i in 0..<4 {
    out.write_char(
      alphabet
      .get_char(((h >> (18 - 6 * i)) & 63).reinterpret_as_int())
      .unwrap(),
    )
  }
  out.to_string()
}

///|
/// What the port gives where upstream panics: `create_rgba_palette` indexes
/// out of range for a palette whose length is not a multiple of three (a
/// `PLTE` chunk of 3 to 768 bytes is accepted). The port reports the error
/// of a `PLTE` chunk of any other wrong length.
let png_damage_instead_of_panic : String = "error: Format error decoding Png: Chunk length wrong: ChunkType { type: PLTE, critical: true, private: false, reserved: false, safecopy: false }"

///|
/// What the port gives where upstream aborts: it allocates the frame that
/// the header claims (`vec![0; total_bytes]`) before it reads a row, and a
/// frame of 2^62 bytes and more (up to `isize::MAX`, above which it reports
/// a limit) cannot be allocated. The port reads rows first and reports
/// what upstream reports for the frames that it can allocate.
let png_damage_instead_of_abort : String = "error: Format error decoding Png: IDAT or fDAT chunk does not have enough data for image."

///|
/// Checks the damaged copies of a seed against the oracle: `expected` holds
/// four characters per case of [png_damage].
fn png_damage_seed(
  seed_index : Int,
  b64 : String,
  valid : String,
  count : Int,
  expected : String,
) -> Unit raise {
  let seed = @base64.decode(b64)
  assert_eq(png_damage_outcome_of(seed, false), valid)
  let cases = png_damage(seed, seed_index)
  assert_eq(cases.length(), count)
  assert_eq(expected.length(), 4 * count)
  let failures = StringBuilder()
  let mut failed = 0
  for i, case in cases {
    let outcome = png_damage_outcome_of(case.data, case.direct)
    let want = expected[4 * i:4 * i + 4].to_owned()
    let ok = match want {
      "!!!!" => outcome == png_damage_instead_of_panic
      "####" => outcome == png_damage_instead_of_abort
      _ => png_damage_short_hash(outcome) == want
    }
    if !ok {
      failed += 1
      if failed <= 20 {
        failures.write_string("\n  \{i} \{case.desc}: \{outcome} (\{want})")
      }
    }
  }
  if failed > 0 {
    fail("\{failed} of \{count} cases differ from the oracle:\{failures}")
  }
}

///|
/// Checks one case with its whole outcome.
fn png_damage_outcome(
  seed_index : Int,
  b64 : String,
  index : Int,
  desc : String,
  outcome : String,
) -> Unit raise {
  let case = png_damage(@base64.decode(b64), seed_index)[index]
  assert_eq(case.desc, desc)
  let want = match outcome {
    "panic" => png_damage_instead_of_panic
    "abort" => png_damage_instead_of_abort
    _ => outcome
  }
  assert_eq(png_damage_outcome_of(case.data, case.direct), want)
}
