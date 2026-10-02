// The `svg` stage (see `oracle/src/svg.rs`): compile every paged test (same
// selection as the `paged` stage) and export it like the upstream test
// harness does (`tests/src/output.rs`): `svg_merged` with pretty printing and
// a 1pt gap between pages.
//
// # Comparison
//
// The goldens are upstream's raw SVGs. Their `<defs>` IDs (`g…`, `c…`, `f…`,
// `r…`, `s…`, `t…`, `p…` followed by uppercase hex digits) are derived from
// `typst_utils::hash128` of upstream's `Hash` impls. The port reproduces
// these hash streams (`svg/hash.mbt`), but a hash also changes with any
// last-bit difference of a hashed float that the printed output rounds away.
// The comparison therefore canonicalizes both sides with
// [canonicalize_svg_ids] first: every defined ID and all of its references
// are renamed to `<kind>_<n>` in order of first occurrence in the document
// ("canonical SVG parity": geometry, paints, element order and labels are
// compared as is). The runner additionally reports how many outputs are
// byte-identical without canonicalization ("raw parity").

///|
/// Compile a single test case and export it to SVG.
fn svg_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  match warned.output {
    Ok(doc) =>
      @svg.svg_merged(
        doc,
        { render_bleed: false, format: { pretty: Some(true), }, },
        @library.Abs::pt(1.0),
      )
    Err(_) => "<error>\n"
  }
}

///|
/// Whether `c` is an uppercase hexadecimal digit.
fn is_upper_hex(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F')
}

///|
/// Whether `c` is the kind prefix of a deduplicated `<defs>` ID.
///
/// `'\u{0}'` is the kind of glyph references written while rendering
/// tilings after the glyph definitions (an upstream quirk, see
/// `SVGRenderer::write_glyph_defs`); they refer to the glyph `g<hash>`.
fn is_dedup_kind(c : Char) -> Bool {
  c is ('g' | 'c' | 'f' | 'r' | 's' | 't' | 'p' | '\u{0}')
}

///|
/// The length of a deduplicated ID (kind + hex digits) starting at `i`, if
/// any.
fn dedup_id_len(s : String, i : Int) -> Int? {
  if i >= s.length() || !is_dedup_kind(s.unsafe_get(i).unsafe_to_char()) {
    return None
  }
  let mut j = i + 1
  while j < s.length() && is_upper_hex(s.unsafe_get(j).unsafe_to_char()) {
    j += 1
  }
  Some(j - i)
}

///|
/// Canonically renames the hash-derived `<defs>` IDs of an SVG and their
/// references (`id="…"`, `#…"` and `url(#…)`) to `<kind>_<n>`, numbered in
/// order of first occurrence.
fn canonicalize_svg_ids(svg : String) -> String {
  // Collect the defined IDs.
  let defined : Map[String, Unit] = {}
  let id_attr = "id=\""
  let mut i = 0
  while svg.view(start_offset=i).find(id_attr) is Some(at) {
    let start = i + at + id_attr.length()
    if dedup_id_len(svg, start) is Some(len) &&
      start + len < svg.length() &&
      svg.unsafe_get(start + len) == '"' {
      defined[svg.unsafe_substring(start~, end=start + len)] = ()
    }
    i = start
  }
  if defined.is_empty() {
    return svg
  }
  // Rename definitions and references in order of first occurrence.
  let names : Map[String, String] = {}
  let counters : Map[Char, Int] = {}
  let out = StringBuilder()
  let mut last = 0
  let mut i = 0
  while i < svg.length() {
    let c = svg.unsafe_get(i)
    let start = if c == '#' {
      Some(i + 1)
    } else if c == 'i' &&
      i > 0 &&
      svg.unsafe_get(i - 1) == ' ' &&
      svg.view(start_offset=i).has_prefix(id_attr) {
      Some(i + id_attr.length())
    } else {
      None
    }
    guard start is Some(start) else {
      i += 1
      continue
    }
    match dedup_id_len(svg, start) {
      Some(len) if start + len < svg.length() &&
        (
          svg.unsafe_get(start + len) == '"' ||
          svg.unsafe_get(start + len) == ')'
        ) => {
        let raw = svg.unsafe_substring(start~, end=start + len)
        let nul = raw.unsafe_get(0) == '\u{0}'
        let id = if nul {
          "g" + raw.unsafe_substring(start=1, end=raw.length())
        } else {
          raw
        }
        if defined.contains(id) {
          let name = match names.get(id) {
            Some(n) => n
            None => {
              let kind = id.unsafe_get(0).unsafe_to_char()
              let n = counters.get(kind).unwrap_or(0) + 1
              counters[kind] = n
              let name = "\{kind}_\{n}"
              names[id] = name
              name
            }
          }
          out.write_string(svg.unsafe_substring(start=last, end=start))
          if nul {
            out.write_char('\u{0}')
            out.write_string(name.unsafe_substring(start=1, end=name.length()))
          } else {
            out.write_string(name)
          }
          last = start + len
        }
        i = start + len
      }
      _ => i = start
    }
  }
  out.write_string(svg.unsafe_substring(start=last, end=svg.length()))
  out.to_string()
}
