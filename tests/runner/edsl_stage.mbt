// The `edsl` stage (docs/edsl-design.md, sections 16 and 17): every twin of
// `doc/twins` is an EDSL document and a functional Typst source. Both are
// compiled in the same world and must be equivalent
//
// - structurally: the lowered content and the evaluated content have the
//   same structural dump (elements with their identity, all stored fields,
//   labels, styles in order with their `liftable` flag; no spans);
// - by layout: the paged documents have the same `typst-frame-v1` dump
//   with spans and glyph span offsets erased (locations are numbered by
//   first occurrence), with memoization on and off;
// - by export: the SVG of every page and the PDF bytes are equal;
// - in their diagnostics: the same warnings (message and hints).
//
// The world is rooted at `bench/` (the assets of the showcase) and has the
// embedded fonts only.

///|
/// `--edsl-dump=<dir>`: where the two sides of a failed comparison are
/// written (`<check>.edsl.txt`, `<check>.typst.txt`), for diffing.
let edsl_dump_dir : Ref[String?] = { val: None, }

///|
/// The world of a Typst twin: the base world plus the main source.
priv struct TwinWorld {
  base : &@library.World
  main : @syntax.Source
}

///|
impl @library.World for TwinWorld with fn library(self) {
  self.base.library()
}

///|
impl @library.World for TwinWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for TwinWorld with fn source(self, id) {
  if id == self.main.id() {
    self.main
  } else {
    self.base.source(id)
  }
}

///|
impl @library.World for TwinWorld with fn file(self, id) {
  if id == self.main.id() {
    @utf8.encode(self.main.text())
  } else {
    self.base.file(id)
  }
}

///|
impl @library.World for TwinWorld with fn book(self) {
  self.base.book()
}

///|
impl @library.World for TwinWorld with fn font(self, index) {
  self.base.font(index)
}

///|
impl @library.World for TwinWorld with fn today(self, offset) {
  self.base.today(offset)
}

///|
/// The main file of a twin: a project-root file, like the EDSL's virtual
/// files, so that paths resolve alike.
fn twin_main(text : String, dir~ : String = "") -> @syntax.Source {
  let path = if dir == "" { "twin.typ" } else { dir + "/twin.typ" }
  let id = @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new(path) catch {
      _ => panic()
    },
  ).intern()
  @syntax.Source::new(id, text)
}

///|
/// The structural dump of content: see the head of this file.
priv struct StructDumper {
  /// The distinct elements in order of first occurrence (shared by the two
  /// documents of a comparison).
  elems : Array[@library.Element]
  /// For realized content (the elements of frame tags): the locations in
  /// order of first occurrence, per document. `None` for evaluated
  /// content, which has none.
  locations : Map[@library.Location, Int]?
}

///|
/// The number of a location: its position in the order of first
/// occurrence.
fn StructDumper::loc(self : StructDumper, loc : @library.Location) -> String {
  guard self.locations is Some(locations) else { return "#?" }
  match locations.get(loc) {
    Some(n) => "#\{n}"
    None => {
      let n = locations.length()
      locations[loc] = n
      "#\{n}"
    }
  }
}

///|
fn StructDumper::elem(self : StructDumper, elem : @library.Element) -> String {
  let mut index = -1
  for i, e in self.elems {
    if e == elem {
      index = i
      break
    }
  }
  if index < 0 {
    index = self.elems.length()
    self.elems.push(elem)
  }
  "\{elem.name()}@\{index}"
}

///|
fn StructDumper::content(
  self : StructDumper,
  content : @library.Content,
) -> String {
  let label = match content.label() {
    // The name as a string literal, so that no name can imitate the
    // encoding of other content.
    Some(label) => " <\{@library.repr_str(label.resolve())}>"
    None => ""
  }
  if content.to_sequence() is Some(children) {
    return "[" + children.map(c => self.content(c)).join(", ") + "]" + label
  }
  if content.is_(@library.styled_elem()) {
    let styles = self.styles(@library.StyledElem::styles(content))
    let child = self.content(@library.StyledElem::child(content))
    return "styled(\{styles}; \{child})" + label
  }
  // Tags of realized content: their locations are hashes, compared by
  // their order of first occurrence.
  if @library.TagElem::of(content) is Some(tag) {
    return match tag.tag() {
      Start(elem, _) =>
        "tag.start(\{self.loc(elem.location().unwrap())}, \{self.elem(elem.elem())})"
      End(loc, _, _) => "tag.end(\{self.loc(loc)})"
    }
  }
  let elem = content.elem()
  let fields = []
  for info in elem.fields() {
    if content.field_raw(info.id) is Some(value) {
      if @library.RawElem::of(content) is Some(raw) &&
        info.id == @library.raw_elem_text {
        fields.push("\{info.name}: \{raw_text_dump(raw)}")
        continue
      }
      fields.push("\{info.name}: \{self.value(value)}")
    }
  }
  let location = match (self.locations, content.location()) {
    (Some(_), Some(loc)) => " " + self.loc(loc)
    _ => ""
  }
  "\{self.elem(elem)}(\{fields.join(", ")})" + location + label
}

///|
/// The text of a raw element: the lines of raw syntax (the evaluator's
/// `RawContent::Lines`), or the string of the `raw` function
/// (`RawContent::Text`), which highlighting splits at newlines. Both are
/// encoded as the lines that highlighting sees: the two forms are equal
/// when they have the same lines, and a raw without lines (` `` `) differs
/// from `raw("")`, which has one empty line.
fn raw_text_dump(raw : @library.RawElem) -> String {
  let lines = match raw.text() {
    Lines(lines) => lines.map(line => line.0)
    Text(text) => @syntax.split_newlines(text)
  }
  "lines(" + lines.map(line => @library.repr_str(line)).join(", ") + ")"
}

///|
fn StructDumper::value(self : StructDumper, value : @library.Value) -> String {
  match value {
    Content(c) => self.content(c)
    Array(a) => "(" + a.items.map(v => self.value(v)).join(", ") + ")"
    Dict(d) => {
      let pairs = []
      for key, v in d.map {
        // The key as a string literal: `("a: 1, b": 2)` is not
        // `(a: 1, b: 2)`.
        pairs.push("\{@library.repr_str(key)}: \{self.value(v)}")
      }
      // `(:)` is not `()`, the empty array.
      if pairs.is_empty() {
        "(:)"
      } else {
        "(" + pairs.join(", ") + ")"
      }
    }
    Styles(styles) => "styles(\{self.styles(styles)})"
    Func(f) => f.repr()
    v => v.repr()
  }
}

///|
fn StructDumper::styles(
  self : StructDumper,
  styles : @library.Styles,
) -> String {
  styles.iter().map(s => self.style(s)).collect().join(", ")
}

///|
fn StructDumper::style(self : StructDumper, style : @library.Style) -> String {
  match style {
    Property(p) => {
      let name = match p.elem.field(p.id) {
        Some(info) => info.name
        None => "#\{p.id}"
      }
      let liftable = if p.liftable { "^" } else { "" }
      "\{self.elem(p.elem)}.\{name}=\{self.value(p.value)}\{liftable}"
    }
    Recipe(recipe) => {
      let selector = match recipe.selector {
        Some(s) => s.repr()
        None => "none"
      }
      let transform = match recipe.transform {
        Content(c) => self.content(c)
        Func(f) => f.repr()
        Style(s) => "set(\{self.styles(s)})"
      }
      "show \{selector}: \{transform}"
    }
    Revocation(index) => "revoke(\{index})"
  }
}

///|
/// Diagnostics as messages with their hints, and whether each is located.
fn diagnostic_lines(diags : Array[@library.SourceDiagnostic]) -> String {
  let out = StringBuilder()
  for diag in @typst.deduplicate(diags) {
    let severity = match diag.severity {
      Error => "error"
      Warning => "warning"
    }
    let located = if diag.span.id() is Some(_) { "located" } else { "detached" }
    out.write_string("\{severity} \{located} \{diag.message}\n")
    for hint in diag.hints {
      out.write_string("  hint \{hint.v}\n")
    }
  }
  out.to_string()
}

///|
/// The normalized frame dump of a document.
fn normalized_frames(
  doc : @layout.PagedDocument,
  tag_names_only~ : Bool = false,
) -> String {
  let enc = FrameEncoder::new(
    _ => "null",
    zero_span_offsets=true,
    tag_names_only~,
  )
  enc.document(doc)
  enc.out.to_string()
}

///|
/// The first line at which two dumps differ.
fn first_difference(a : String, b : String) -> String {
  let xs = a.split("\n").map(l => l.to_owned()).collect()
  let ys = b.split("\n").map(l => l.to_owned()).collect()
  let n = if xs.length() < ys.length() { xs.length() } else { ys.length() }
  let clip = (s : String) => {
    if s.length() > 600 {
      s.unsafe_substring(start=0, end=600) + "..."
    } else {
      s
    }
  }
  for i in 0..<n {
    if xs[i] != ys[i] {
      // Skip the common prefix of the lines.
      let x = xs[i]
      let y = ys[i]
      let mut k = 0
      while k < x.length() && k < y.length() && x[k] == y[k] {
        k += 1
      }
      let from = if k > 80 { k - 80 } else { 0 }
      return "line \{i + 1}, column \{k + 1}\n      edsl:  \{clip(x.unsafe_substring(start=from, end=x.length()))}\n      typst: \{clip(y.unsafe_substring(start=from, end=y.length()))}"
    }
  }
  "lengths differ: \{xs.length()} and \{ys.length()} lines"
}

///|
/// Compare one twin; returns the failed checks.
fn check_twin(twin : @twins.Twin, base : &@library.World) -> Array[String] {
  check_pair(
    (twin.build)(),
    twin_main(twin.typst, dir=twin.dir),
    base,
    structural=true,
  )
}

///|
/// Compare an EDSL document with a Typst main file; returns the failed
/// checks. With `structural`, the Typst source is a functional twin: the
/// lowered and the evaluated content must have the same structural dump,
/// and the tags of the frames are compared with their elements. Otherwise
/// the source is markup that the document was converted from: element
/// bodies differ in how text is split, so the structure is not compared
/// and tags are compared by element name and location.
fn check_pair(
  document : @doc.Document,
  main : @syntax.Source,
  base : &@library.World,
  structural~ : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  let differ = (what : String, edsl : String, typst : String) => {
    if edsl != typst {
      failures.push("\{what}: \{first_difference(edsl, typst)}")
      if edsl_dump_dir.val is Some(dir) {
        let stem = "\{dir}/\{what.replace_all(old=" ", new="-")}"
        @fs.write_string_to_file(stem + ".edsl.txt", edsl) catch {
          _ => ()
        }
        @fs.write_string_to_file(stem + ".typst.txt", typst) catch {
          _ => ()
        }
      }
    }
  }
  let world : TwinWorld = { base, main, }

  // Structure.
  if structural {
    let dumper : StructDumper = { elems: [], locations: None, }
    let lowered = document.lower(base)
    let sink = @library.Sink::new()
    let evaluated = try
      @eval.eval_source(
        world,
        base.library(),
        @library.Traced::new(),
        sink,
        @library.Route::root(),
        main,
      )
    catch {
      @library.SourceError(errors) => Err(errors)
    } noraise {
      module_ => Ok(module_.content())
    }
    match (lowered.output(), evaluated) {
      (Some(edsl), Ok(typst)) =>
        differ("structure", dumper.content(edsl), dumper.content(typst))
      (None, Ok(_)) =>
        failures.push(
          "structure: the EDSL document does not lower: " +
          lowered.errors.map(e => e.render()).join("; "),
        )
      (_, Err(errors)) =>
        failures.push(
          "structure: the Typst twin does not evaluate: " +
          diagnostic_lines(errors),
        )
    }
  }
  let tag_names_only = !structural

  // Layout and export, with memoization on and off.
  for memo in [true, false] {
    @library.set_layout_memo_enabled(memo)
    let mode = if memo { "" } else { " (memoization off)" }
    let edsl = document.compile_paged(base)
    let typst : @library.Warned[
      Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
    ] = @typst.compile(world)
    @library.set_layout_memo_enabled(true)
    differ(
      "warnings" + mode,
      diagnostic_lines(edsl.warnings.map(w => w.raw)),
      diagnostic_lines(typst.warnings),
    )
    match (edsl.output(), typst.output) {
      (Some(a), Ok(b)) => {
        differ(
          "layout" + mode,
          normalized_frames(a, tag_names_only~),
          normalized_frames(b, tag_names_only~),
        )
        if memo {
          let svg_options = @svg.SvgOptions::default().resolve(
            @svg.SvgFormatOptions::get(b.options()),
          )
          let svg_a = edsl.svg_pages().output().unwrap_or([]).join("\n")
          let svg_b = b
            .pages()
            .map(page => @svg.svg(page, svg_options))
            .join("\n")
          differ("svg", svg_a, svg_b)
          let pdf_a = edsl.pdf().output()
          let pdf_b = match @pdf.pdf(b, @pdf.PdfOptions::default()).output {
            Ok(bytes) => Some(bytes)
            Err(_) => None
          }
          match (pdf_a, pdf_b) {
            (Some(x), Some(y)) =>
              if x != y {
                failures.push(
                  "pdf: the bytes differ (\{x.length()} and \{y.length()} bytes)",
                )
              }
            _ => failures.push("pdf: export failed")
          }
          // Pixels: both documents rendered with the same resolved
          // options, and the EDSL report's PNG export.
          let png_options : @render.RenderOptions = {
            render_bleed: false,
            format: { ppi: None, },
          }
          let png_options = png_options.resolve(
            @render.PngFormatOptions::get(b.options()),
          )
          let exported = edsl.png_pages().output().unwrap_or([])
          if a.pages().length() != b.pages().length() ||
            exported.length() != b.pages().length() {
            failures.push("png: the page counts differ")
          } else {
            for i, page in b.pages() {
              let pixels = try {
                let x = @render.render(a.pages()[i], png_options)
                let y = @render.render(page, png_options)
                if x.width() != y.width() || x.height() != y.height() {
                  Some("the sizes differ")
                } else if x.data() != y.data() {
                  Some("the pixels differ")
                } else if exported[i] != y.encode_png() {
                  Some("the exported PNG differs")
                } else {
                  None
                }
              } catch {
                @render.RenderPanic(message) => Some(message)
              }
              if pixels is Some(message) {
                failures.push("png: page \{i + 1}: \{message}")
              }
            }
          }
        }
      }
      (None, Ok(_)) =>
        failures.push(
          "layout\{mode}: the EDSL document does not compile: " +
          edsl.errors.map(e => e.render()).join("; "),
        )
      (_, Err(errors)) =>
        failures.push(
          "layout\{mode}: the Typst twin does not compile: " +
          diagnostic_lines(errors),
        )
    }
  }
  failures
}

///|
fn run_edsl_stage(filter : String?, verbose : Bool) -> Unit {
  let base = @system.world(root="bench", system_fonts=false, today=(2026, 1, 1)) catch {
    err => {
      println("edsl: cannot create the world: \{err}")
      @sys.exit(1)
      return
    }
  }
  let mut passed = 0
  let mut failed = 0
  for twin in @twins.all() {
    if filter is Some(f) && !twin.name.contains(f) {
      continue
    }
    let failures = check_twin(twin, base)
    if failures.is_empty() {
      passed += 1
      if verbose {
        println("ok   \{twin.name}")
      }
    } else {
      failed += 1
      println("FAIL \{twin.name}")
      for failure in failures {
        println("    \{failure}")
      }
    }
  }
  // The documents of `bench/` against the Typst files they were converted
  // from.
  let mut with_system_fonts : &@library.World? = None
  for original in @twins.originals() {
    let name = "original/" + original.name
    if filter is Some(f) && !name.contains(f) {
      continue
    }
    let world : &@library.World = if original.system_fonts {
      match with_system_fonts {
        Some(world) => world
        None => {
          let world = @system.world(root="bench", today=(2026, 1, 1)) catch {
            err => {
              println("edsl: cannot create the world: \{err}")
              @sys.exit(1)
              return
            }
          }
          with_system_fonts = Some(world)
          world
        }
      }
    } else {
      base
    }
    let id = @syntax.RootedPath::new(
      Project,
      @syntax.VirtualPath::new(original.path) catch {
        _ => panic()
      },
    ).intern()
    let failures = try world.source(id) catch {
      _ => ["the original `bench/\{original.path}` cannot be read"]
    } noraise {
      main => check_pair((original.build)(), main, world, structural=false)
    }
    if failures.is_empty() {
      passed += 1
      if verbose {
        println("ok   \{name}")
      }
    } else {
      failed += 1
      println("FAIL \{name}")
      for failure in failures {
        println("    \{failure}")
      }
    }
  }
  // The curated sample of translator output against its sources, as
  // functional twins.
  for entry in @sample.all() {
    let (sample_name, path, build) = entry
    let name = "converted/" + sample_name
    if filter is Some(f) && !name.contains(f) {
      continue
    }
    let world : &@library.World = match with_system_fonts {
      Some(world) => world
      None => {
        let world = @system.world(root="bench", today=(2026, 1, 1)) catch {
          err => {
            println("edsl: cannot create the world: \{err}")
            @sys.exit(1)
            return
          }
        }
        with_system_fonts = Some(world)
        world
      }
    }
    let failures = check_pair(
      build(),
      twin_main(read(path)),
      world,
      structural=true,
    )
    if failures.is_empty() {
      passed += 1
      if verbose {
        println("ok   \{name}")
      }
    } else {
      failed += 1
      println("FAIL \{name}")
      for failure in failures {
        println("    \{failure}")
      }
    }
  }
  println("edsl: \{passed} passed, \{failed} failed")
  if failed > 0 {
    @sys.exit(1)
  }
}
