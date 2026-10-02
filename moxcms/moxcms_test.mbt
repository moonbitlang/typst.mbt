// Differential tests against `moxcms` 0.8.1 (aarch64, default features).
//
// For each profile and mode the oracle (see moxcms/README.mbt.md) transforms
// a fixed set of inputs to sRGB the way hayro does (`Gray`/`Rgb`/`Rgba` source
// layouts for 1/3/4 components, `Rgb` destination) and reports an FNV-1a hash
// of the output bytes (`f32` outputs as little-endian bits).

///|
priv struct Rng {
  mut state : UInt
}

///|
fn Rng::next(self : Rng) -> UInt {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  x
}

///|
fn Rng::byte(self : Rng) -> Byte {
  (self.next() >> 24).to_byte()
}

///|
fn Rng::float(self : Rng) -> Float {
  let v = self.next() >> 10
  Float::from_uint(v) / 4194304.0 * 1.5 - 0.25
}

///|
let seed : UInt = 2463534242U

///|
fn special_floats() -> Array[Float] {
  let nan = Float::from_double(0.0 / 0.0)
  let inf = Float::from_double(1.0 / 0.0)
  [
    -1.0,
    -0.5,
    -0.01,
    0.0,
    1.0e-6,
    0.001,
    0.25,
    0.5,
    0.75,
    0.999,
    1.0,
    1.001,
    1.5,
    2.0,
    nan,
    inf,
    -inf,
  ]
}

///|
fn inputs_u8(n : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  let rng = { state: seed, }
  match n {
    1 => {
      for i in 0..<256 {
        out.push(i.to_byte())
      }
      for _ in 0..<4096 {
        out.push(rng.byte())
      }
    }
    3 => {
      for r in 0..<52 {
        for g in 0..<52 {
          for b in 0..<52 {
            out.push((r * 5).to_byte())
            out.push((g * 5).to_byte())
            out.push((b * 5).to_byte())
          }
        }
      }
      for _ in 0..<(50000 * 3) {
        out.push(rng.byte())
      }
    }
    _ => {
      let l = Array::makei(17, i => if i == 16 { 255 } else { i * 16 })
      for c in l {
        for m in l {
          for y in l {
            for k in l {
              out.push(c.to_byte())
              out.push(m.to_byte())
              out.push(y.to_byte())
              out.push(k.to_byte())
            }
          }
        }
      }
      for _ in 0..<(50000 * 4) {
        out.push(rng.byte())
      }
    }
  }
  out
}

///|
fn inputs_f32(n : Int) -> Array[Float] {
  let out : Array[Float] = []
  let rng = { state: seed, }
  let sf = special_floats()
  match n {
    1 => {
      for i in 0..<=4096 {
        out.push(Float::from_int(i) / 4096.0)
      }
      for s in sf {
        out.push(s)
      }
      for _ in 0..<4096 {
        out.push(rng.float())
      }
    }
    3 => {
      let l = Array::makei(17, i => Float::from_int(i) / 16.0)
      for r in l {
        for g in l {
          for b in l {
            out.push(r)
            out.push(g)
            out.push(b)
          }
        }
      }
      for s in sf {
        out.push(s)
        out.push(s)
        out.push(s)
        out.push(s)
        out.push(0.5)
        out.push(0.25)
        out.push(0.75)
        out.push(s)
        out.push(0.5)
        out.push(0.25)
        out.push(0.5)
        out.push(s)
      }
      for _ in 0..<(50000 * 3) {
        out.push(rng.float())
      }
    }
    _ => {
      let l = Array::makei(9, i => Float::from_int(i) / 8.0)
      for c in l {
        for m in l {
          for y in l {
            for k in l {
              out.push(c)
              out.push(m)
              out.push(y)
              out.push(k)
            }
          }
        }
      }
      for s in sf {
        for v in ([s, s, s, s] : Array[Float]) {
          out.push(v)
        }
        for v in ([s, 0.5, 0.25, 0.125] : Array[Float]) {
          out.push(v)
        }
        for v in ([0.75, s, 0.5, 0.25] : Array[Float]) {
          out.push(v)
        }
        for v in ([0.25, 0.5, s, 0.75] : Array[Float]) {
          out.push(v)
        }
        for v in ([0.25, 0.5, 0.125, s] : Array[Float]) {
          out.push(v)
        }
      }
      for _ in 0..<(50000 * 4) {
        out.push(rng.float())
      }
    }
  }
  out
}

///|
priv struct Fnv {
  mut h : UInt64
}

///|
fn Fnv::byte(self : Fnv, b : UInt64) -> Unit {
  self.h = (self.h ^ b) * 0x100000001b3UL
}

///|
fn error_name(e : @moxcms.CmsError) -> String {
  match e {
    InvalidProfile => "InvalidProfile"
    InvalidLayout => "InvalidLayout"
    UnsupportedProfileConnection => "UnsupportedProfileConnection"
    BuildTransferFunction => "BuildTransferFunction"
    InvalidAtoBLut => "InvalidAtoBLut"
    InvalidTrcCurve => "InvalidTrcCurve"
    OverflowingError => "OverflowingError"
    e => "\{e}"
  }
}

///|
fn layout_for(n : Int) -> @moxcms.Layout {
  match n {
    1 => Gray
    3 => Rgb
    _ => Rgba
  }
}

///|
fn hex(v : UInt64) -> String {
  let s = v.to_string(radix=16)
  "0x" + String::make(16 - s.length(), '0') + s
}

///|
/// Runs one oracle case; `raw` receives the output bytes.
fn run_case(data : Bytes, n : Int, mode : String, raw : Array[Byte]) -> String {
  let profile = @moxcms.ColorProfile::new_from_slice(data) catch {
    e => return "PARSE_ERR \{error_name(e)}"
  }
  let dst = @moxcms.ColorProfile::new_srgb()
  let options = @moxcms.TransformOptions::default()
  if mode == "u8" {
    let t = profile.create_transform_8bit(layout_for(n), dst, Rgb, options) catch {
      e => return "CREATE_ERR \{error_name(e)}"
    }
    let src = inputs_u8(n)
    let count = src.length() / n
    let out = FixedArray::make(count * 3, b'\x00')
    t.transform(src[:], out) catch {
      e => return "TRANSFORM_ERR \{error_name(e)}"
    }
    let h = { h: 0xcbf29ce484222325UL, }
    for b in out {
      h.byte(b.to_uint64())
      raw.push(b)
    }
    "OK count=\{count} hash=\{hex(h.h)}"
  } else {
    let t = profile.create_transform_f32(layout_for(n), dst, Rgb, options) catch {
      e => return "CREATE_ERR \{error_name(e)}"
    }
    let src = inputs_f32(n)
    let count = src.length() / n
    let out = FixedArray::make(count * 3, Float::from_int(0))
    t.transform(src[:], out) catch {
      e => return "TRANSFORM_ERR \{error_name(e)}"
    }
    let h = { h: 0xcbf29ce484222325UL, }
    for v in out {
      let bits = v.reinterpret_as_uint().to_uint64()
      for i in 0..<4 {
        let b = (bits >> (8 * i)) & 0xffUL
        h.byte(b)
        raw.push(b.to_byte())
      }
    }
    "OK count=\{count} hash=\{hex(h.h)}"
  }
}

///|
fn read_fixture(name : String) -> Bytes? {
  for dir in ["moxcms/testdata/", "testdata/", "../moxcms/testdata/"] {
    let data = @fs.read_file_to_bytes(dir + name) catch { _ => continue }
    return Some(data)
  }
  None
}

///|
/// Expected oracle results: (fixture, components, mode, result).
let expected : Array[(String, Int, String, String)] = [
  ("srgb_v2_curv.icc", 1, "u8", "CREATE_ERR InvalidLayout"),
  ("srgb_v2_curv.icc", 1, "f32", "CREATE_ERR InvalidLayout"),
  ("srgb_v2_curv.icc", 3, "u8", "OK count=190608 hash=0x8ec34341eecdd704"),
  ("srgb_v2_curv.icc", 3, "f32", "OK count=54981 hash=0x6c8eb937112f9cc6"),
  ("srgb_v2_curv.icc", 4, "u8", "OK count=133521 hash=0x73d705e68b52c292"),
  ("srgb_v2_curv.icc", 4, "f32", "OK count=56646 hash=0x133fc8131da85614"),
  ("cgats001compat_v2_micro.icc", 1, "u8", "CREATE_ERR InvalidLayout"),
  ("cgats001compat_v2_micro.icc", 3, "f32", "CREATE_ERR InvalidLayout"),
  (
    "cgats001compat_v2_micro.icc", 4, "u8", "OK count=133521 hash=0xcc412110d9b40fb7",
  ),
  (
    "cgats001compat_v2_micro.icc", 4, "f32", "OK count=56646 hash=0x1ddeebe9f7a800ee",
  ),
  ("gray_v4_para.icc", 1, "u8", "OK count=4352 hash=0x294e4bccc1e24bb9"),
  ("gray_v4_para.icc", 1, "f32", "OK count=8210 hash=0xdd362c790c9ae84a"),
  ("gray_v4_para.icc", 3, "u8", "CREATE_ERR InvalidLayout"),
  ("gray_v4_para.icc", 4, "f32", "CREATE_ERR InvalidLayout"),
  ("diagrams_skia_v4.icc", 1, "u8", "CREATE_ERR InvalidLayout"),
  ("diagrams_skia_v4.icc", 3, "u8", "OK count=190608 hash=0x8ec34341eecdd704"),
  ("diagrams_skia_v4.icc", 3, "f32", "OK count=54981 hash=0x81da1d6e398012bf"),
  ("diagrams_skia_v4.icc", 4, "u8", "OK count=133521 hash=0x73d705e68b52c292"),
  ("diagrams_skia_v4.icc", 4, "f32", "OK count=56646 hash=0x2dd64a886517bb11"),
  ("gray_v2_curv.icc", 1, "u8", "OK count=4352 hash=0x81239cc4eacda1c9"),
  ("gray_v2_curv.icc", 1, "f32", "OK count=8210 hash=0x1b32b59d2564d99c"),
  ("gray_v2_curv.icc", 3, "u8", "CREATE_ERR InvalidLayout"),
  ("rgb_v2_curv.icc", 3, "u8", "OK count=190608 hash=0x8ec34341eecdd704"),
  ("rgb_v2_curv.icc", 3, "f32", "OK count=54981 hash=0x6c8eb937112f9cc6"),
  ("rgb_v2_curv.icc", 4, "u8", "OK count=133521 hash=0x73d705e68b52c292"),
  ("rgb_v2_curv.icc", 4, "f32", "OK count=56646 hash=0x133fc8131da85614"),
  ("cmyk_broken.icc", 4, "u8", "PARSE_ERR InvalidProfile"),
  ("rgb_mab_v4.icc", 1, "u8", "CREATE_ERR InvalidLayout"),
  ("rgb_mab_v4.icc", 3, "u8", "OK count=190608 hash=0xf4a3af7132a2b624"),
  ("rgb_mab_v4.icc", 3, "f32", "OK count=54981 hash=0xc8bfe673ba6da650"),
  ("rgb_mab_v4.icc", 4, "u8", "OK count=133521 hash=0x0a6f5a8b034f7e82"),
  ("rgb_mab_v4.icc", 4, "f32", "OK count=56646 hash=0xd4e92fa90c114e72"),
  ("gray_v2_curv_2.icc", 1, "u8", "OK count=4352 hash=0x294e4bccc1e24bb9"),
  ("gray_v2_curv_2.icc", 1, "f32", "OK count=8210 hash=0x2d04836e2ffabadd"),
  ("gray_v2_curv_2.icc", 3, "f32", "CREATE_ERR InvalidLayout"),
  ("gray_broken.icc", 1, "u8", "PARSE_ERR InvalidProfile"),
  ("lab.icc", 1, "u8", "CREATE_ERR InvalidLayout"),
  ("lab.icc", 3, "u8", "OK count=190608 hash=0xb2b614466941214c"),
  ("lab.icc", 3, "f32", "OK count=54981 hash=0x7e551f3625fedec1"),
  ("lab.icc", 4, "u8", "OK count=133521 hash=0x59e24601bd7403e5"),
  ("lab.icc", 4, "f32", "OK count=56646 hash=0x57e7a2da3530b6c9"),
  ("star_typst_v4.icc", 1, "f32", "CREATE_ERR InvalidLayout"),
  ("star_typst_v4.icc", 3, "u8", "OK count=190608 hash=0x19693a140c88302f"),
  ("star_typst_v4.icc", 3, "f32", "OK count=54981 hash=0xca4a50b12de45b21"),
  ("star_typst_v4.icc", 4, "u8", "OK count=133521 hash=0xf11a0a348819e417"),
  ("star_typst_v4.icc", 4, "f32", "OK count=56646 hash=0xc697cac5dd0b3760"),
]

///|
test "transforms match moxcms" {
  let failures = []
  for case in expected {
    let (name, n, mode, want) = case
    guard read_fixture(name) is Some(data) else { continue }
    let got = run_case(data, n, mode, [])
    if got != want {
      failures.push("\{name} \{n} \{mode}: got `\{got}`, want `\{want}`")
    }
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}
