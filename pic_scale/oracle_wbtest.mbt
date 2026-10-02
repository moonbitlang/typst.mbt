// Differential tests against the real `pic-scale` 0.7.12 crate run the way
// hayro calls it (`testdata/oracle.tsv`, generated on aarch64 with FEAT_RDM
// by `oracle/src/bin/gen_pic_scale_tests.rs`). The input images are
// regenerated here from the recorded seeds with the same SplitMix64
// generator; outputs are compared by length and FNV-1a-64 hash. `sort` rows
// check the port of `sort_unstable_by` (hence a white-box test).

///|
fn module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
priv struct SplitMix {
  mut state : UInt64
}

///|
fn SplitMix::next(self : SplitMix) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
fn SplitMix::below(self : SplitMix, n : UInt64) -> UInt64 {
  (self.next() >> 32) % n
}

///|
fn fnv1a64(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
fn hex64(v : UInt64) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder()
  for i = 15; i >= 0; i = i - 1 {
    buf.write_char(digits[((v >> (i * 4)) & 0xf).to_int()].unsafe_to_char())
  }
  buf.to_string()
}

///|
fn head_hex(data : Bytes) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder()
  for i in 0..<@cmp.minimum(16, data.length()) {
    let b = data[i].to_int()
    buf.write_char(digits[b >> 4].unsafe_to_char())
    buf.write_char(digits[b & 15].unsafe_to_char())
  }
  if buf.is_empty() {
    "-"
  } else {
    buf.to_string()
  }
}

///|
fn parse_hex64(s : String) -> UInt64 {
  let mut v = 0UL
  for c in s {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      c.to_int() - 'a'.to_int() + 10
    }
    v = (v << 4) | d.to_uint64()
  }
  v
}

///|
/// Generates an `n`-channel image (must match `gen_image` in
/// `oracle/src/bin/gen_pic_scale_tests.rs`).
fn gen_image(
  n : Int,
  w : Int,
  h : Int,
  color : String,
  alpha : String,
  seed : UInt64,
) -> Bytes {
  let rng = { state: seed, }
  let consts = FixedArray::make(4, 0)
  for c in 0..<4 {
    consts[c] = (rng.next() >> 56).to_int()
  }
  let wd = @cmp.maximum(w, 2) - 1
  let hd = @cmp.maximum(h, 2) - 1
  let sd = @cmp.maximum(w + h, 3) - 2
  let out = FixedArray::make(w * h * n, b'\x00')
  let mut i = 0
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<n {
        let v = if n == 4 && c == 3 {
          match alpha {
            "opaque" => 255
            "zero" => 0
            "const" => consts[3]
            "rand" => (rng.next() >> 56).to_int()
            "mixed" => {
              let r = rng.next()
              match (r >> 62).to_int() {
                0 => 0
                1 => 255
                _ => ((r >> 8) & 0xffUL).to_int()
              }
            }
            "grad" => x * 255 / wd
            _ => abort("alpha mode \{alpha}")
          }
        } else {
          match color {
            "rand" => (rng.next() >> 56).to_int()
            "const" => consts[c]
            "ext" => if rng.next() >> 63 == 1UL { 255 } else { 0 }
            "grad" =>
              match c % 3 {
                0 => x * 255 / wd
                1 => y * 255 / hd
                _ => (x + y) * 255 / sd
              }
            _ => abort("color mode \{color}")
          }
        }
        out[i] = (v & 0xff).to_byte()
        i += 1
      }
    }
  }
  Bytes::from_array(out)
}

///|
fn sort_case(len : Int, key_mod : UInt64, seed : UInt64) -> Bytes {
  let r = { state: seed, }
  let keys = FixedArray::make(len, 0.0)
  for i in 0..<len {
    keys[i] = r.below(key_mod).to_double() - (key_mod / 2UL).to_double()
  }
  let order = Array::makei(len, i => i)
  sort_unstable_by(order, fn(a, b) { keys[b].abs() < keys[a].abs() })
  let out = FixedArray::make(len * 4, b'\x00')
  for i, v in order {
    out[i * 4] = (v & 0xff).to_byte()
    out[i * 4 + 1] = ((v >> 8) & 0xff).to_byte()
    out[i * 4 + 2] = ((v >> 16) & 0xff).to_byte()
    out[i * 4 + 3] = ((v >> 24) & 0xff).to_byte()
  }
  Bytes::from_array(out)
}

///|
test "pic-scale matches the oracle" {
  guard module_root() is Some(root) else { return }
  let tsv = @fs.read_file_to_string(root + "pic_scale/testdata/oracle.tsv")
  let mut total = 0
  let failures = []
  for line in tsv.split("\n") {
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let f = line.split("\t").map(s => s.to_owned()).collect()
    let plan = f[0]
    let sw = @string.parse_int(f[1])
    let sh = @string.parse_int(f[2])
    let dw = @string.parse_int(f[3])
    let dh = @string.parse_int(f[4])
    let seed = parse_hex64(f[7])
    let expected_len = @string.parse_int(f[8])
    let expected_hash = f[9]
    let res = match plan {
      "sort" => sort_case(sw, sh.to_uint64(), seed)
      "planar" =>
        resize_planar_u8(gen_image(1, sw, sh, f[5], f[6], seed), sw, sh, dw, dh)
      "rgb" =>
        resize_rgb_u8(gen_image(3, sw, sh, f[5], f[6], seed), sw, sh, dw, dh)
      _ =>
        resize_rgba_u8_premultiplied(
          gen_image(4, sw, sh, f[5], f[6], seed),
          sw,
          sh,
          dw,
          dh,
        )
    }
    total += 1
    if res.length() != expected_len || hex64(fnv1a64(res)) != expected_hash {
      failures.push(
        "\{line}\n  got len \{res.length()} \{hex64(fnv1a64(res))} \{head_hex(res)}",
      )
    }
  }
  if failures.length() > 0 {
    let msg = StringBuilder()
    msg.write_string(
      "\{failures.length()} of \{total} pic-scale oracle cases differ:\n",
    )
    for i in 0..<@cmp.minimum(40, failures.length()) {
      msg.write_string(failures[i])
      msg.write_char('\n')
    }
    fail(msg.to_string())
  }
  assert_true(total > 1000)
}
