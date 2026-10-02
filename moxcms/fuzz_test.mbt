// Differential tests of parsing / validation on corrupted profiles: each
// fixture is mutated deterministically (the oracle's `mutate`), parsed and,
// when parsing succeeds, transformed; the oracle hashes all result lines.

///|
/// Rust `{:?}` formatting of `CmsError`.
fn rust_debug(e : @moxcms.CmsError) -> String {
  match e {
    LaneSizeMismatch => "LaneSizeMismatch"
    LaneMultipleOfChannels => "LaneMultipleOfChannels"
    InvalidProfile => "InvalidProfile"
    InvalidTrcCurve => "InvalidTrcCurve"
    InvalidCicp => "InvalidCicp"
    CurveLutIsTooLarge => "CurveLutIsTooLarge"
    ParametricCurveZeroDivision => "ParametricCurveZeroDivision"
    InvalidRenderingIntent => "InvalidRenderingIntent"
    DivisionByZero => "DivisionByZero"
    UnsupportedColorPrimaries(v) => "UnsupportedColorPrimaries(\{v})"
    UnsupportedTrc(v) => "UnsupportedTrc(\{v})"
    InvalidLayout => "InvalidLayout"
    UnsupportedProfileConnection => "UnsupportedProfileConnection"
    BuildTransferFunction => "BuildTransferFunction"
    UnsupportedChannelConfiguration => "UnsupportedChannelConfiguration"
    UnknownTag(t) => "UnknownTag(\{t})"
    UnknownTagTypeDefinition(t) => "UnknownTagTypeDefinition(\{t})"
    UnsupportedLutRenderingIntent(i) => "UnsupportedLutRenderingIntent(\{i})"
    InvalidAtoBLut => "InvalidAtoBLut"
    OverflowingError => "OverflowingError"
    LUTTablesInvalidKind => "LUTTablesInvalidKind"
    MalformedClut(s) =>
      "MalformedClut(MalformedSize { size: \{s.size}, expected: \{s.expected} })"
    MalformedCurveLutTable(s) =>
      "MalformedCurveLutTable(MalformedSize { size: \{s.size}, expected: \{s.expected} })"
    InvalidInksCountForProfile => "InvalidInksCountForProfile"
    MalformedTrcCurve(s) => "MalformedTrcCurve(\"\{s}\")"
    OutOfMemory(n) => "OutOfMemory(\{n})"
    IncorrectlyFormedLut(s) => "IncorrectlyFormedLut(\"\{s}\")"
  }
}

///|
fn be32(d : Array[Byte], i : Int) -> UInt {
  (d[i].to_uint() << 24) |
  (d[i + 1].to_uint() << 16) |
  (d[i + 2].to_uint() << 8) |
  d[i + 3].to_uint()
}

///|
fn urem(a : UInt, b : Int) -> Int {
  (a % b.reinterpret_as_uint()).reinterpret_as_int()
}

///|
/// Deterministic profile corruption (same as the oracle's `mutate`).
fn mutate(data : Bytes, idx : UInt) -> Bytes {
  let rng = { state: (seed ^ (idx * 0x9E3779B9U)) | 1U, }
  let orig = data.to_array()
  let d = data.to_array()
  let len = d.length()
  let tcount = if len >= 132 {
    let t = be32(orig, 128).to_uint64()
    let lim = ((len - 132) / 12).to_uint64()
    @cmp.minimum((if t < lim { t } else { lim }).to_int(), 64)
  } else {
    0
  }
  let kind = rng.next() % 6U
  match kind {
    0U => {
      let l = urem(rng.next(), len + 1)
      d.truncate(l)
    }
    1U => {
      let k = 1U + rng.next() % 4U
      for _ in 0U..<k {
        let p = urem(rng.next(), len)
        d[p] = rng.byte()
      }
    }
    2U => {
      let lim = @cmp.minimum(len, 132 + 12 * tcount)
      let k = 1U + rng.next() % 3U
      for _ in 0U..<k {
        let p = urem(rng.next(), lim)
        d[p] = rng.byte()
      }
    }
    3U =>
      if tcount > 0 {
        let t = urem(rng.next(), tcount)
        let field = 132 + 12 * t + 4 + 4 * urem(rng.next(), 2)
        let v = if rng.next() % 2U == 0U {
          rng.next() % (len.reinterpret_as_uint() + 64U)
        } else {
          rng.next()
        }
        for i in 0..<4 {
          d[field + i] = (v >> (24 - 8 * i)).to_byte()
        }
      }
    _ =>
      if tcount > 0 {
        let t = urem(rng.next(), tcount)
        let off = be32(orig, 132 + 12 * t + 4).to_uint64()
        let size = be32(orig, 132 + 12 * t + 8).to_uint64()
        if off < len.to_uint64() && size > 0UL {
          let rest = len.to_uint64() - off
          let span = (if size < rest { size } else { rest }).to_int()
          let off = off.to_int()
          let k = 1U + rng.next() % 3U
          for _ in 0U..<k {
            let p = if kind == 4U {
              off + urem(rng.next(), span)
            } else {
              off + @cmp.minimum(8 + urem(rng.next(), 8), span - 1)
            }
            d[p] = rng.byte()
          }
        }
      }
  }
  Bytes::from_array(d[:])
}

///|
fn fnv_bytes(bytes : ArrayView[Byte]) -> UInt64 {
  let h = { h: 0xcbf29ce484222325UL, }
  for b in bytes {
    h.byte(b.to_uint64())
  }
  h.h
}

///|
/// Same as the oracle's `fuzz_case`.
fn fuzz_case(d : Bytes, idx : UInt) -> String {
  let profile = @moxcms.ColorProfile::new_from_slice(d) catch {
    e => return "PARSE_ERR \{rust_debug(e)}"
  }
  let n = match profile.color_space {
    Gray => 1
    Cmyk | Color4 => 4
    _ => 3
  }
  let dst = @moxcms.ColorProfile::new_srgb()
  let out = StringBuilder()
  out.write_string("OK n=\{n}")
  let rng = { state: seed ^ idx, }
  let options = @moxcms.TransformOptions::default()
  try profile.create_transform_8bit(layout_for(n), dst, Rgb, options) catch {
    e => out.write_string(" u8:ERR \{rust_debug(e)}")
  } noraise {
    t => {
      let src = Array::makei(64 * n, _ => rng.byte())
      let o = FixedArray::make(64 * 3, b'\x00')
      try t.transform(src[:], o) catch {
        e => out.write_string(" u8:TERR \{rust_debug(e)}")
      } noraise {
        _ => {
          let arr = Array::from_fixed_array(o)
          out.write_string(" u8:\{hex(fnv_bytes(arr[:]))}")
        }
      }
    }
  }
  if idx % 10U == 0U {
    try profile.create_transform_f32(layout_for(n), dst, Rgb, options) catch {
      e => out.write_string(" f32:ERR \{rust_debug(e)}")
    } noraise {
      t => {
        let src = Array::makei(64 * n, _ => rng.float())
        let o = FixedArray::make(64 * 3, Float::from_int(0))
        try t.transform(src[:], o) catch {
          e => out.write_string(" f32:TERR \{rust_debug(e)}")
        } noraise {
          _ => {
            let raw = []
            for v in o {
              let bits = v.reinterpret_as_uint()
              for i in 0..<4 {
                raw.push((bits >> (8 * i)).to_byte())
              }
            }
            out.write_string(" f32:\{hex(fnv_bytes(raw[:]))}")
          }
        }
      }
    }
  }
  out.to_string()
}

///|
fn fuzz_lines(data : Bytes, count : Int) -> Array[String] {
  Array::makei(count, i => {
    let idx = i.reinterpret_as_uint()
    fuzz_case(mutate(data, idx), idx)
  })
}

///|
fn fuzz_hash(lines : Array[String]) -> String {
  let s = StringBuilder()
  for l in lines {
    s.write_string(l)
    s.write_char('\n')
  }
  let arr = @utf8.encode(s.to_string()).to_array()
  hex(fnv_bytes(arr[:]))
}

///|
/// Oracle hashes of 300 corrupted variants per fixture.
let fuzz_expected : Array[(String, String)] = [
  ("cgats001compat_v2_micro.icc", "0x218b9aa951e5dbfe"),
  ("cmyk_broken.icc", "0x6e9ee41bcf231009"),
  ("diagrams_skia_v4.icc", "0x1909971f0d8d04be"),
  ("gray_broken.icc", "0x9c32cb8f2e67df14"),
  ("gray_v2_curv.icc", "0x95c8cb82e1d14cb2"),
  ("gray_v2_curv_2.icc", "0xe2afe86c7e966504"),
  ("gray_v4_para.icc", "0xb3c651dfb307271d"),
  ("lab.icc", "0xc16d6b0323b72e0f"),
  ("rgb_mab_v4.icc", "0xf3e01d4d6cc33b72"),
  ("rgb_v2_curv.icc", "0x49f9987599bfc2f5"),
  ("srgb_v2_curv.icc", "0x79870768324fabce"),
  ("star_typst_v4.icc", "0x822caa49fffa8031"),
]

///|
test "parsing and validation of corrupted profiles matches moxcms" {
  let failures = []
  for case in fuzz_expected {
    let (name, want) = case
    guard read_fixture(name) is Some(data) else { continue }
    let got = fuzz_hash(fuzz_lines(data, 300))
    if got != want {
      failures.push("\{name}: got \{got}, want \{want}")
    }
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}
