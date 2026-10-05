// The `shape` and `shape-hb` stages: differential tests of the shaper
// (`shape/`, a port of rustybuzz).
//
// `shape` replays every text run upstream Typst shapes while compiling the
// paged tests (recorded by the oracle's rustybuzz tap, see
// `oracle/src/shape.rs`) and compares glyph ids, clusters, glyph flags,
// advances and offsets exactly.
//
// `shape-hb` runs rustybuzz's own test suite (HarfBuzz's shaping tests,
// extracted by `scripts/shape_hb_tests.py`; fonts from .repos/rustybuzz).

///|
let rustybuzz_dir = ".repos/rustybuzz"

///|
fn json_int(j : Json) -> Int {
  match j {
    Number(n, ..) => n.to_int()
    _ => abort("expected a number")
  }
}

///|
fn json_uint(j : Json) -> UInt {
  match j {
    Number(n, ..) => n.to_uint()
    _ => abort("expected a number")
  }
}

///|
fn json_string(j : Json) -> String {
  match j {
    String(s) => s
    _ => abort("expected a string")
  }
}

///|
fn shape_direction(s : String) -> @shape.Direction {
  match s {
    "ltr" => LeftToRight
    "rtl" => RightToLeft
    "ttb" => TopToBottom
    "btt" => BottomToTop
    _ => Invalid
  }
}

///|
/// One recorded run: shape it and encode the output like the oracle.
fn shape_run(
  fonts : Array[@library.Font],
  line : String,
) -> (String, String, String) {
  let json = @json.parse(line) catch { _ => abort("bad shape golden line") }
  guard json is Object(obj) else { abort("bad shape golden line") }
  let font = fonts[json_int(obj.get("font").unwrap())]
  let face = @shape.Face::from_slice(font.data()[:], font.index()).unwrap()
  match obj.get("coords") {
    Some(Array(coords)) if coords.length() > 0 =>
      face.ttf().set_normalized_coordinates(coords.map(json_int))
    _ => ()
  }
  let dir = shape_direction(json_string(obj.get("dir").unwrap()))
  let script = match obj.get("script") {
    Some(String(s)) => Some(@shape.Script(@otf.Tag::from_str(s)))
    _ => None
  }
  let buffer_script = match obj.get("buffer_script") {
    Some(String(s)) => Some(@shape.Script(@otf.Tag::from_str(s)))
    _ => None
  }
  let lang = match obj.get("lang") {
    Some(String(s)) => Some(@shape.Language(s))
    _ => None
  }
  let features = []
  match obj.get("features") {
    Some(Array(fs)) =>
      for f in fs {
        guard f is Array(parts) else { abort("bad feature") }
        features.push(
          @shape.Feature::new(
            @otf.Tag::from_str(json_string(parts[0])),
            json_uint(parts[1]),
            start=json_uint(parts[2]),
            end=json_uint(parts[3]),
          ),
        )
      }
    _ => ()
  }
  let text = json_string(obj.get("text").unwrap())
  let buffer = @shape.UnicodeBuffer::new()
  buffer.push_str(text)
  if lang is Some(lang) {
    buffer.set_language(lang)
  }
  if buffer_script is Some(s) {
    buffer.set_script(s)
  }
  buffer.set_direction(dir)
  buffer.set_flags(json_uint(obj.get("flags").unwrap()))
  buffer.set_cluster_level(json_int(obj.get("cluster_level").unwrap()))
  let plan = @shape.ShapePlan::new(face, dir, script, lang, features)
  let out = @shape.shape_with_plan(face, plan, buffer)
  let actual = StringBuilder()
  actual.write_char('[')
  let positions = out.glyph_positions()
  for i, info in out.glyph_infos() {
    let p = positions[i]
    if i > 0 {
      actual.write_char(',')
    }
    actual.write_string(
      "[\{info.glyph_id},\{info.cluster},\{info.mask & @shape.GLYPH_FLAG_DEFINED},\{p.x_advance},\{p.y_advance},\{p.x_offset},\{p.y_offset}]",
    )
  }
  actual.write_char(']')
  // The expected glyphs, textually.
  let start = line.find("\"glyphs\":").unwrap() + 9
  let end = line.find(",\"test\":").unwrap()
  let expected = line.unsafe_substring(start~, end~)
  let key = match script {
    Some(s) => s.tag().to_chars() |> String::from_array
    None => "none"
  }
  (key, expected, actual.to_string())
}

///|
fn run_shape_stage(filter : String?, verbose : Bool) -> Unit {
  let fonts = test_fonts()
  let dir = golden_dir + "/shape"
  let files = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
  files.sort_by((a, b) => compare_str(a, b))
  let mut passed = 0
  let mut failed = 0
  let by_font : Array[(String, Int, Int)] = []
  let by_script : Map[String, (Int, Int)] = {}
  for file in files {
    let mut fp = 0
    let mut ff = 0
    for line in read(dir + "/" + file).split("\n") {
      let line = line.to_owned()
      if line.is_empty() {
        continue
      }
      if filter is Some(f) && !file.contains(f) && !line.contains(f) {
        continue
      }
      let (script, expected, actual) = shape_run(fonts, line)
      let (sp, sf) = by_script.get(script).unwrap_or((0, 0))
      if expected == actual {
        passed += 1
        fp += 1
        by_script[script] = (sp + 1, sf)
      } else {
        failed += 1
        ff += 1
        by_script[script] = (sp, sf + 1)
        if verbose {
          println("FAIL \{file} :: \{line}")
          println("  actual: \{actual}")
        }
      }
    }
    by_font.push((file, fp, ff))
  }
  for entry in by_font {
    let (file, fp, ff) = entry
    if fp + ff > 0 {
      println("  \{file}: \{fp}/\{fp + ff}")
    }
  }
  for script, counts in by_script {
    println("  script \{script}: \{counts.0}/\{counts.0 + counts.1}")
  }
  println("shape: \{passed} passed, \{failed} failed")
}

///|
/// Rust string ordering (code points).
fn compare_str(a : String, b : String) -> Int {
  let a = a.to_array()
  let b = b.to_array()
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return a[i].to_int() - b[i].to_int()
    }
  }
  a.length() - b.length()
}

///|
/// Parsed hb-shape style options of a rustybuzz test.
priv struct HbArgs {
  mut face_index : UInt
  mut font_ptem : Float?
  mut variations : Array[String]
  mut direction : @shape.Direction?
  mut language : @shape.Language?
  mut script : @shape.Script?
  mut remove_default_ignorables : Bool
  mut unsafe_to_concat : Bool
  mut not_found_variation_selector_glyph : UInt?
  mut cluster_level : Int
  mut features : Array[String]
  mut pre_context : Array[Int]?
  mut post_context : Array[Int]?
  mut no_glyph_names : Bool
  mut no_positions : Bool
  mut no_advances : Bool
  mut no_clusters : Bool
  mut show_extents : Bool
  mut show_flags : Bool
  mut ned : Bool
  mut bot : Bool
  mut eot : Bool
}

///|
fn parse_unicodes(s : String) -> Array[Int] {
  s
  .split(",")
  .map(p => {
    let p = p.to_owned()
    let p = if p.has_prefix("U+") {
      p.unsafe_substring(start=2, end=p.length())
    } else {
      p
    }
    @string.parse_int(p, base=16) catch {
      _ => 0
    }
  })
  .to_array()
}

///|
fn parse_hb_args(options : String) -> HbArgs {
  let args : HbArgs = {
    face_index: 0,
    font_ptem: None,
    variations: [],
    direction: None,
    language: None,
    script: None,
    remove_default_ignorables: false,
    unsafe_to_concat: false,
    not_found_variation_selector_glyph: None,
    cluster_level: 0,
    features: [],
    pre_context: None,
    post_context: None,
    no_glyph_names: false,
    no_positions: false,
    no_advances: false,
    no_clusters: false,
    show_extents: false,
    show_flags: false,
    ned: false,
    bot: false,
    eot: false,
  }
  let tokens = options
    .split(" ")
    .filter(s => !s.is_empty())
    .map(s => s.to_owned())
    .to_array()
  let mut i = 0
  while i < tokens.length() {
    let tok = tokens[i]
    // `--key=value` or `--key value`.
    let (key, value) = match tok.find("=") {
      Some(eq) => {
        let v = tok.unsafe_substring(start=eq + 1, end=tok.length())
        // pico-args (eq-separator) strips surrounding quotes.
        let v = if v.length() >= 2 &&
          (
            (v.has_prefix("\"") && v.has_suffix("\"")) ||
            (v.has_prefix("'") && v.has_suffix("'"))
          ) {
          v.unsafe_substring(start=1, end=v.length() - 1)
        } else {
          v
        }
        (tok.unsafe_substring(start=0, end=eq), Some(v))
      }
      None => (tok, None)
    }
    let take_value = () => {
      match value {
        Some(v) => v
        None => {
          i += 1
          tokens[i]
        }
      }
    }
    match key {
      "--face-index" =>
        args.face_index = @string.parse_int(take_value()).reinterpret_as_uint() catch {
          _ => 0
        }
      "--font-ptem" =>
        args.font_ptem = Some(
          Float::from_double(
            @string.parse_double(take_value()) catch {
              _ => 0.0
            },
          ),
        )
      "--variations" =>
        args.variations = take_value()
          .split(",")
          .map(s => s.to_owned())
          .to_array()
      "--direction" => args.direction = @shape.Direction::from_str(take_value())
      "--language" => args.language = @shape.Language::from_str(take_value())
      "--script" => args.script = @shape.Script::from_str(take_value())
      "--remove-default-ignorables" => args.remove_default_ignorables = true
      "--unsafe-to-concat" => args.unsafe_to_concat = true
      "--not-found-variation-selector-glyph" =>
        args.not_found_variation_selector_glyph = Some(
          (@string.parse_int(take_value()) catch { _ => 0 }).reinterpret_as_uint(),
        )
      "--cluster-level" =>
        args.cluster_level = @string.parse_int(take_value()) catch { _ => 0 }
      "--features" =>
        args.features = take_value()
          .split(",")
          .map(s => s.to_owned())
          .to_array()
      "--unicodes-before" =>
        args.pre_context = Some(parse_unicodes(take_value()))
      "--unicodes-after" =>
        args.post_context = Some(parse_unicodes(take_value()))
      "--no-glyph-names" => args.no_glyph_names = true
      "--no-positions" => args.no_positions = true
      "--no-advances" => args.no_advances = true
      "--no-clusters" => args.no_clusters = true
      "--show-extents" => args.show_extents = true
      "--show-flags" => args.show_flags = true
      "--ned" => args.ned = true
      "--bot" => args.bot = true
      "--eot" => args.eot = true
      "--font-funcs" => ignore(take_value())
      _ => ()
    }
    i += 1
  }
  args
}

///|
/// The rustybuzz test harness `shape` (tests/shaping/main.rs).
fn hb_shape(font_path : String, text : Array[Int], options : String) -> String? {
  let args = parse_hb_args(options)
  let data = @fs.read_file_to_bytes(font_path) catch { _ => return None }
  let face = @shape.Face::from_slice(data[:], args.face_index).unwrap()
  face.set_points_per_em(args.font_ptem)
  if !args.variations.is_empty() {
    let variations = args.variations.map(s => {
      @shape.Variation::from_str(s).unwrap()
    })
    face.set_variations(variations)
  }
  let buffer = @shape.UnicodeBuffer::new()
  if args.pre_context is Some(pre) {
    buffer.set_pre_context(pre)
  }
  let s = StringBuilder()
  for c in text {
    s.write_char(c.unsafe_to_char())
  }
  buffer.push_str(s.to_string())
  if args.post_context is Some(post) {
    buffer.set_post_context(post)
  }
  if args.direction is Some(d) {
    buffer.set_direction(d)
  }
  if args.not_found_variation_selector_glyph is Some(g) {
    buffer.set_not_found_variation_selector_glyph(g)
  }
  if args.language is Some(lang) {
    buffer.set_language(lang)
  }
  if args.script is Some(script) {
    buffer.set_script(script)
  }
  let mut flags : UInt = 0
  if args.bot {
    flags = flags | @shape.BUFFER_FLAG_BEGINNING_OF_TEXT
  }
  if args.eot {
    flags = flags | @shape.BUFFER_FLAG_END_OF_TEXT
  }
  if args.unsafe_to_concat {
    flags = flags | @shape.BUFFER_FLAG_PRODUCE_UNSAFE_TO_CONCAT
  }
  if args.remove_default_ignorables {
    flags = flags | @shape.BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES
  }
  buffer.set_flags(flags)
  buffer.set_cluster_level(args.cluster_level)
  buffer.reset_clusters()
  let features = args.features.map(s => @shape.Feature::from_str(s).unwrap())
  let glyph_buffer = @shape.shape(face, features, buffer)
  let mut format_flags = 0
  if args.no_glyph_names {
    format_flags = format_flags | @shape.SERIALIZE_NO_GLYPH_NAMES
  }
  if args.no_clusters || args.ned {
    format_flags = format_flags | @shape.SERIALIZE_NO_CLUSTERS
  }
  if args.no_positions {
    format_flags = format_flags | @shape.SERIALIZE_NO_POSITIONS
  }
  if args.no_advances || args.ned {
    format_flags = format_flags | @shape.SERIALIZE_NO_ADVANCES
  }
  if args.show_extents {
    format_flags = format_flags | @shape.SERIALIZE_GLYPH_EXTENTS
  }
  if args.show_flags {
    format_flags = format_flags | @shape.SERIALIZE_GLYPH_FLAGS
  }
  Some(glyph_buffer.serialize(face, format_flags))
}

///|
fn run_shape_hb_stage(filter : String?, verbose : Bool) -> Unit {
  let dir = golden_dir + "/shape-hb"
  let files = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
  files.sort_by((a, b) => compare_str(a, b))
  let mut passed = 0
  let mut failed = 0
  let mut skipped = 0
  let by_prefix : Map[String, (Int, Int)] = {}
  for file in files {
    for line in read(dir + "/" + file).split("\n") {
      let line = line.to_owned()
      if line.is_empty() {
        continue
      }
      let parts = line.split("\t").map(s => s.to_owned()).to_array()
      let name = parts[0]
      if filter is Some(f) && !name.contains(f) {
        continue
      }
      if trace_tests.val {
        println("TRACE \{name}")
      }
      let font = if parts[1].has_prefix("/") {
        parts[1]
      } else {
        rustybuzz_dir + "/" + parts[1]
      }
      let text = if parts[2].is_empty() { [] } else { parse_unicodes(parts[2]) }
      let expected = parts[4]
      // Group by test name prefix (e.g. `arabic`, `indic`).
      let prefix = match name.find("_") {
        Some(i) => name.unsafe_substring(start=0, end=i)
        None => name
      }
      match hb_shape(font, text, parts[3]) {
        None => skipped += 1
        Some(actual) => {
          let (p, f) = by_prefix.get(prefix).unwrap_or((0, 0))
          if actual == expected {
            passed += 1
            by_prefix[prefix] = (p + 1, f)
          } else {
            failed += 1
            by_prefix[prefix] = (p, f + 1)
            if verbose {
              println("FAIL \{file} :: \{name} [\{parts[3]}]")
              println("  expected: \{expected}")
              println("  actual:   \{actual}")
            }
          }
        }
      }
    }
  }
  for prefix, counts in by_prefix {
    println("  \{prefix}: \{counts.0}/\{counts.0 + counts.1}")
  }
  println(
    "shape-hb: \{passed} passed, \{failed} failed, \{skipped} skipped (missing fonts)",
  )
}
