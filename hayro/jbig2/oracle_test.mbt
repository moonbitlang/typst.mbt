// Differential test against the real hayro-jbig2: decodes the files of
// `testdata/files` (written by `scripts/gen_jbig2_test_files.py`) as listed
// in `testdata/cases.tsv` and compares the result and the pushed pixels with
// `testdata/oracle.tsv` (`gen_hayro_codec_tests jbig2`).

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
/// Records the pushed pixels like the generator's `Jbig2Recorder`.
struct Recorder {
  out : @buffer.Buffer
  mut rows : Int
}

///|
impl @jbig2.Decoder for Recorder with fn push_pixel(self, black) {
  self.out.write_byte(if black { b'1' } else { b'0' })
}

///|
impl @jbig2.Decoder for Recorder with fn push_pixel_chunk(
  self,
  black,
  chunk_count,
) {
  self.out.write_string_utf8("[\{if black { 1 } else { 0 }}\{chunk_count}]")
}

///|
impl @jbig2.Decoder for Recorder with fn next_line(self) {
  self.rows += 1
  self.out.write_byte(b'\n')
}

///|
test "hayro-jbig2 matches the oracle" {
  guard module_root() is Some(root) else { return }
  let dir = root + "hayro/jbig2/testdata/"
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
    let globals = if f[1] == "-" {
      None
    } else {
      Some(@fs.read_file_to_bytes(dir + "files/" + f[1]))
    }
    let recorder = { out: @buffer.new(), rows: 0, }
    let result = try {
      if f[2] == "file" {
        @jbig2.Image::new(data[:])
      } else {
        @jbig2.Image::new_embedded(data[:], globals.map(g => g[:]))
      }
    } catch {
      e => "E \{e}"
    } noraise {
      image => {
        let size = "\{image.width()}x\{image.height()}"
        try image.decode(recorder) catch {
          e => "\{size} E \{e}"
        } noraise {
          _ => "\{size} ok"
        }
      }
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
