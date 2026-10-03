// Differential test against the real hayro-ccitt: decodes the streams of
// `testdata/files` (written by `scripts/gen_ccitt_test_files.py`) with the
// settings of `testdata/cases.tsv` and compares the result and the pushed
// pixels with `testdata/oracle.tsv` (`gen_hayro_codec_tests ccitt`).

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
fn fnv1a64(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = (h ^ b.to_uint64()) * 0x100000001b3UL
  }
  h
}

///|
fn hex16(v : UInt64) -> String {
  let s = v.to_string(radix=16)
  String::make(16 - s.length(), '0') + s
}

///|
/// Records the pushed pixels like the generator's `CcittRecorder`.
struct Recorder {
  out : @buffer.Buffer
  mut rows : Int
}

///|
impl Decoder for Recorder with fn push_pixel(self, white) {
  self.out.write_byte(if white { b'1' } else { b'0' })
}

///|
impl Decoder for Recorder with fn push_pixel_chunk(self, white, chunk_count) {
  let b = if white { b'1' } else { b'0' }
  for _ in 0..<(chunk_count.reinterpret_as_int() * 8) {
    self.out.write_byte(b)
  }
}

///|
impl Decoder for Recorder with fn next_line(self) {
  self.rows += 1
  self.out.write_byte(b'\n')
}

///|
test "hayro-ccitt matches the oracle" {
  guard module_root() is Some(root) else { return }
  let dir = root + "hayro/ccitt/testdata/"
  let cases = @fs.read_file_to_string(dir + "cases.tsv")
  let expected = @fs.read_file_to_string(dir + "oracle.tsv")
    .split("\n")
    .filter(l => !l.is_empty() && !l.has_prefix("#"))
    .map(l => l.to_string())
    .to_array()
  let mismatches = []
  let mut index = 0
  for line in cases.split("\n") {
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let f = line.split("\t").map(p => p.to_string()).to_array()
    let data = @fs.read_file_to_bytes(dir + "files/" + f[0])
    let k = @string.parse_int(f[3])
    let settings : DecodeSettings = {
      columns: @string.parse_int(f[1]).reinterpret_as_uint(),
      rows: @string.parse_int(f[2]).reinterpret_as_uint(),
      end_of_line: f[4] == "1",
      rows_are_byte_aligned: f[5] == "1",
      end_of_block: f[6] == "1",
      encoding: if k < 0 {
        Group4
      } else if k == 0 {
        Group3_1D
      } else {
        Group3_2D(k=k.reinterpret_as_uint())
      },
      invert_black: f[7] == "1",
    }
    let recorder = { out: @buffer.new(), rows: 0, }
    let ctx = DecoderContext::new(settings)
    let result = try decode(data[:], recorder, ctx) catch {
      e => "E \{e}"
    } noraise {
      n => "ok \{n}"
    }
    let pixels = recorder.out.to_bytes()
    let actual = "\{f[0]}\t\{index}\t\{result}\t\{recorder.rows} \{pixels.length()}:\{hex16(fnv1a64(pixels))}"
    if actual != expected[index] {
      mismatches.push("expected \{expected[index]}\n     got \{actual}")
    }
    index += 1
  }
  assert_eq(index, expected.length())
  if mismatches.length() > 0 {
    fail(
      "\{mismatches.length()}/\{index} mismatches:\n" + mismatches.join("\n"),
    )
  }
}
