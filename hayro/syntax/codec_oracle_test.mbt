// Differential tests of the image filters against the real hayro-syntax:
// `testdata/codec_streams.tsv` is recorded by
// `oracle/src/bin/gen_hayro_codec_tests.rs streams` (the PDFs are listed in
// `testdata/codec_pdfs.txt`): every image stream of those PDFs decoded with
// `Stream::decoded_image` under a few `ImageDecodeParams` variants.
//
// The PDFs are read through the `target/hayro` symlink of a development
// checkout; the tests are skipped if it is missing. Set
// `HAYRO_CODEC_STREAMS=<tsv>` to check another recording instead (e.g. of
// local PDFs, with absolute paths).

///|
fn codec_module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
fn codec_cs_name(cs : @syntax.ImageColorSpace?) -> String {
  match cs {
    None => "-"
    Some(Gray) => "gray"
    Some(Rgb) => "rgb"
    Some(Cmyk) => "cmyk"
    Some(Unknown(n)) => "unknown\{n}"
  }
}

///|
fn codec_hex16(v : UInt64) -> String {
  let s = v.to_string(radix=16)
  String::make(16 - s.length(), '0') + s
}

///|
fn codec_failure_name(e : @syntax.DecodeFailure) -> String {
  match e {
    ImageDecode => "ImageDecode"
    StreamDecode => "StreamDecode"
    Decryption => "Decryption"
    Unknown => "Unknown"
  }
}

///|
/// The `ImageDecodeParams` variants of the generator.
fn codec_params(
  stream : @syntax.Stream,
  variant : String,
) -> @syntax.ImageDecodeParams {
  let dict = stream.dict()
  let width = match (dict.get("Width") : UInt?) {
    Some(w) => w
    None => (dict.get("W") : UInt?).unwrap_or(0)
  }
  let height = match (dict.get("Height") : UInt?) {
    Some(h) => h
    None => (dict.get("H") : UInt?).unwrap_or(0)
  }
  let bpc : Int? = match (dict.get("BPC") : Byte?) {
    Some(b) => Some(b.to_int())
    None => (dict.get("BitsPerComponent") : Byte?).map(b => b.to_int())
  }
  let cs_indexed = match (dict.get("ColorSpace") : @syntax.PdfArray?) {
    Some(a) =>
      match (a.iter() : Iter[@syntax.Name]).next() {
        Some(n) => n.as_str() == "Indexed" || n.as_str() == "I"
        None => false
      }
    None => false
  }
  let base : @syntax.ImageDecodeParams = {
    is_indexed: cs_indexed,
    bpc,
    num_components: None,
    target_dimension: None,
    width: width.reinterpret_as_int(),
    height: height.reinterpret_as_int(),
  }
  match variant {
    "indexed" => { ..base, is_indexed: !cs_indexed, }
    "quarter" =>
      {
        ..base,
        target_dimension: Some(
          ((width / 4).reinterpret_as_int(), (height / 4).reinterpret_as_int()),
        ),
      }
    "bpc4" => { ..base, bpc: Some(4), }
    _ => base
  }
}

///|
fn codec_result(
  stream : @syntax.Stream,
  params : @syntax.ImageDecodeParams,
) -> String {
  match stream.decoded_image(params) {
    Err(e) => "E \{codec_failure_name(e)}"
    Ok(r) => {
      let out = StringBuilder::new()
      out.write_string("\{r.data.length()}:\{codec_hex16(fnv(r.data))}")
      match r.image_data {
        None => out.write_string(" -")
        Some(i) => {
          out.write_string(
            " img \{i.width} \{i.height} \{i.bits_per_component} \{codec_cs_name(i.color_space)}",
          )
          match i.alpha {
            None => out.write_string(" -")
            Some(a) =>
              out.write_string(" \{a.length()}:\{codec_hex16(fnv(a[:]))}")
          }
        }
      }
      out.to_string()
    }
  }
}

///|
/// Check the recorded decodings of streams that use `filter`.
fn check_codec_streams(filter : @syntax.Filter) -> Unit raise {
  guard codec_module_root() is Some(root) else { return }
  let tsv = match @env.get_env_vars().get("HAYRO_CODEC_STREAMS") {
    Some(p) => p
    None => {
      guard @fs.path_exists(root + "target/hayro") else { return }
      root + "hayro/syntax/testdata/codec_streams.tsv"
    }
  }
  let expected = @fs.read_file_to_string(tsv)
  let mismatches = []
  let mut checked = 0
  let mut cur_path = ""
  let mut cur_streams : Map[String, @syntax.Stream] = Map([])
  for line in expected.split("\n") {
    let line = line.to_string()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let parts = line.split("\t").map(p => p.to_string()).to_array()
    let path = parts[0]
    if path != cur_path {
      cur_path = path
      cur_streams = Map([])
      let file = if path.has_prefix("/") { path } else { root + path }
      let data = @fs.read_file_to_bytes(file) catch {
        _ => {
          mismatches.push("\{path}: cannot read")
          continue
        }
      }
      guard @syntax.Pdf::new(data) is Ok(pdf) else {
        mismatches.push("\{path}: failed to load")
        continue
      }
      for o in pdf.objects() {
        if o is Stream(s) {
          let id = s.obj_id()
          cur_streams.set("\{id.obj_number} \{id.gen_number}", s)
        }
      }
    }
    guard cur_streams.get(parts[1]) is Some(stream) else {
      mismatches.push("\{path} \{parts[1]}: missing stream")
      continue
    }
    if !stream.filters().contains(filter) {
      continue
    }
    let actual = codec_result(stream, codec_params(stream, parts[2]))
    if actual != parts[3] {
      mismatches.push(
        "\{path} \{parts[1]} \{parts[2]}: expected \{parts[3]}, got \{actual}",
      )
    }
    checked += 1
  }
  if mismatches.length() > 0 {
    fail(
      "\{mismatches.length()}/\{checked} mismatches:\n" + mismatches.join("\n"),
    )
  }
}

///|
test "codec oracle: CCITTFaxDecode" {
  check_codec_streams(CcittFaxDecode)
}

///|
test "codec oracle: DCTDecode" {
  check_codec_streams(DctDecode)
}

///|
test "codec oracle: JBIG2Decode" {
  check_codec_streams(Jbig2Decode)
}

///|
test "codec oracle: JPXDecode" {
  check_codec_streams(JpxDecode)
}
