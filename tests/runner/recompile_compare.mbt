// What the `recompile` stage (`recompile_stage.mbt`) compares: everything a
// compilation gives its host, as the host sees it.
//
// What it guarantees:
//
// - Two compilations are equal here only if a user could not tell them
//   apart: the same files to watch, the same errors and warnings in the
//   same order at the same places with the same hints and tracepoints, the
//   same pages (every frame item, every tag with its element, every
//   glyph's place in the source), the same answers of the document's
//   introspector (the labelled elements, headings, figures and metadata:
//   where they are, how their pages are numbered), the same SVG and the
//   same PDF, byte for byte.
// - Nothing is compared that a user cannot see and that differs between a
//   file that was edited and the same text parsed from scratch:
//   span numbers. A span is written as what it points at, in the world of
//   its own compilation: file, line and column, and the byte range
//   (`recompile_place`, `encode_world_span`). A span number that the
//   world's source no longer has is written as unresolved, so a diagnostic
//   or a glyph that kept a span of an earlier parse is a difference.
//   Location hashes, which contain span numbers, are written as their
//   order of appearance (the frame dump's `keys`).
// - The dependencies are read first, before anything here asks the world
//   for a source to resolve a span in: they are what the compilation
//   accessed, not what its dump did. (Resolving a span asks the world for
//   the source of its file, as printing a diagnostic does in the CLI. For
//   the span of a source that is no change of state: the compilation
//   parsed it. A diagnostic inside a data file makes that file a source of
//   the store, here as in the CLI.)
//
// - A compilation whose sources are not what a parse of their text gives
//   is marked ([RecompileWorld::reparsed]): upstream's reparser has such
//   cases, and they are not stale results.
//
// What it does not see: values that print alike and are not alike (two
// functions with the same name, two modules), since elements are written
// with their `repr`.

///|
/// What a compilation gave.
priv struct Compiled {
  /// One string per part of [compiled_parts].
  parts : Array[String]
  /// The PDF.
  pdf : Bytes
  /// Whether the document compiled.
  ok : Bool
  /// The document, until the step after it has checked that it is still
  /// what it was (`recompile_stage.mbt`).
  mut document : @layout.PagedDocument?
  /// The sources of the compilation whose tree is not what a parse gives
  /// ([RecompileWorld::reparsed]).
  reparsed : Array[String]
}

///|
/// The parts of a compilation, in the order they are compared.
let compiled_parts : ReadOnlyArray[String] = [
  "dependencies", "diagnostics", "frames", "introspector", "svg", "pdf diagnostics",
  "pdf",
]

///|
/// The index of the frames in [compiled_parts].
let part_frames : Int = 2

///|
/// The index of the SVG in [compiled_parts].
let part_svg : Int = 4

///|
/// Where a span points in the world: `file:line:column-line:column
/// (start..end)`, lines and columns from 1 as the CLI prints them.
fn recompile_place(world : &@library.World, span : @syntax.DiagSpan) -> String {
  guard span.id() is Some(id) else { return "-" }
  let path = file_path(id)
  let source = world.source(id) catch { _ => return "\{path}:?" }
  let (start, end) = match span.get() {
    Detached => return "-"
    Number(num~, sub_range~, ..) =>
      match source.range(num, sub_range) {
        Some(range) => range
        None => return "\{path}:?"
      }
    Range(start~, end~, ..) => (start, end)
  }
  let lines = source.lines()
  let at = (byte : Int) => {
    match lines.byte_to_line_column(byte) {
      Some((line, column)) => "\{line + 1}:\{column + 1}"
      None => "?"
    }
  }
  "\{path}:\{at(start)}-\{at(end)} (\{start}..\{end})"
}

///|
/// Diagnostics with their hints and tracepoints.
fn recompile_diagnostics(
  out : StringBuilder,
  world : &@library.World,
  diagnostics : Array[@library.SourceDiagnostic],
) -> Unit {
  for diagnostic in diagnostics {
    let severity = match diagnostic.severity {
      Error => "error"
      Warning => "warning"
    }
    out.write_string(
      "\{severity} \{recompile_place(world, diagnostic.span)} \{@unicode.rust_debug_str(diagnostic.message)}\n",
    )
    for hint in diagnostic.hints {
      out.write_string(
        "  hint \{recompile_place(world, hint.span)} \{@unicode.rust_debug_str(hint.v)}\n",
      )
    }
    for point in diagnostic.trace {
      let (kind, name) = match point.v {
        Call(name) => ("call", name)
        Show(name) => ("show", Some(name))
        Import(name) => ("import", Some(name))
        Include(name) => ("include", Some(name))
      }
      let name = match name {
        Some(name) => @unicode.rust_debug_str(name)
        None => "-"
      }
      let at = recompile_place(world, @syntax.DiagSpan::from_span(point.span))
      out.write_string("  trace \{at} \{kind} \{name}\n")
    }
  }
}

///|
/// What the introspector of a document answers, asked directly (a host
/// asks it for `typst query`, for the outline of a preview, for a jump):
/// the labelled elements, the headings, the figures and the metadata in
/// the order it gives them, each with its label, its position, the
/// numbering and the supplement of its page, its place in the source and
/// what it prints as.
fn recompile_introspector(
  world : &@library.World,
  doc : @layout.PagedDocument,
) -> String {
  let introspector = @library.Output::introspector(doc)
  let out = StringBuilder()
  let dump = (kind : String, elems : Array[@library.Content]) => {
    for elem in elems {
      let label = match elem.label() {
        Some(label) => label.repr()
        None => "-"
      }
      out.write_string("\{kind} \{elem.elem().name()} \{label}")
      if elem.location() is Some(location) {
        match introspector.position(location) {
          Some(Paged(position)) =>
            out.write_string(
              " page \{position.page.0} \{point_enc(position.point)}",
            )
          _ => out.write_string(" nowhere")
        }
        match introspector.page_numbering(location) {
          Some(numbering) =>
            out.write_string(
              " numbering \{@library.IntoValue::into_value(numbering).repr()}",
            )
          None => ()
        }
        match introspector.page_supplement(location) {
          Some(supplement) =>
            out.write_string(" supplement \{supplement.repr()}")
          None => ()
        }
      }
      let place = recompile_place(
        world,
        @syntax.DiagSpan::from_span(elem.span()),
      )
      out.write_string(" at \{place} :: \{elem.repr()}\n")
    }
  }
  dump("labelled", introspector.query_labelled())
  dump("heading", introspector.query(Elem(@library.heading_elem(), None)))
  dump("figure", introspector.query(Elem(@library.figure_elem(), None)))
  dump("metadata", introspector.query(Elem(@library.metadata_elem(), None)))
  out.to_string()
}

///|
/// The SVG of a document, as the stage exports it.
fn recompile_svg(doc : @layout.PagedDocument) -> String {
  @svg.svg_merged(
    doc,
    { render_bleed: false, format: { pretty: Some(true), }, },
    @library.Abs::pt(1.0),
  )
}

///|
/// Compiles the world as it is and dumps what came out. Also returns the
/// dependencies as ids.
fn recompile_compile(
  world : RecompileWorld,
) -> (Compiled, Array[@syntax.FileId]) {
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  // Before the dump touches the world.
  let ids = world.files.dependencies()
  let dependencies = world.dependencies().join("\n")
  let reparsed = world.reparsed()
  let dyn_world = world as &@library.World
  let diagnostics = StringBuilder()
  let mut frames = ""
  let mut introspector = ""
  let mut svg = ""
  let pdf_diagnostics = StringBuilder()
  let mut pdf : Bytes = b""
  let document = match warned.output {
    Ok(doc) => {
      diagnostics.write_string("ok\n")
      recompile_diagnostics(diagnostics, dyn_world, warned.warnings)
      // (A span is looked up in its file's tree: once per span, not once
      // per glyph.)
      let places : Map[@syntax.Span, String] = Map([])
      let enc = FrameEncoder::new(span => {
        match places.get(span) {
          Some(place) => place
          None => {
            let place = encode_world_span(dyn_world, span)
            places[span] = place
            place
          }
        }
      })
      enc.document(doc)
      frames = enc.out.to_string()
      introspector = recompile_introspector(dyn_world, doc)
      svg = recompile_svg(doc)
      let exported = make_live(doc)
      match exported.output {
        Ok(bytes) => {
          pdf_diagnostics.write_string("ok\n")
          pdf = bytes
        }
        Err(errors) => {
          pdf_diagnostics.write_string("err\n")
          recompile_diagnostics(pdf_diagnostics, dyn_world, errors)
        }
      }
      recompile_diagnostics(pdf_diagnostics, dyn_world, exported.warnings)
      Some(doc)
    }
    Err(errors) => {
      diagnostics.write_string("err\n")
      recompile_diagnostics(diagnostics, dyn_world, errors)
      recompile_diagnostics(diagnostics, dyn_world, warned.warnings)
      None
    }
  }
  let compiled = {
    parts: [
      dependencies,
      diagnostics.to_string(),
      frames,
      introspector,
      svg,
      pdf_diagnostics.to_string(),
      "\{pdf.length()} bytes, sha256 \{sha256_hex(pdf[:])}",
    ],
    pdf,
    ok: document is Some(_),
    document,
    reparsed,
  }
  (compiled, ids)
}

///|
/// One number for everything a compilation gave (for a comparison across
/// processes).
fn Compiled::digest(self : Compiled) -> String {
  let all = StringBuilder()
  for i, part in compiled_parts[:] {
    all.write_string("\{part} \{sha256_hex(@utf8.encode(self.parts[i])[:])}\n")
  }
  sha256_hex(@utf8.encode(all.to_string())[:])
}

///|
/// The parts in which two compilations differ, and what differs in the
/// first of them.
fn Compiled::difference(
  expected : Compiled,
  actual : Compiled,
) -> (Array[String], String)? {
  let parts = []
  let mut detail = ""
  for i, part in compiled_parts[:] {
    let equal = if part == "pdf" {
      expected.pdf == actual.pdf
    } else {
      expected.parts[i] == actual.parts[i]
    }
    if equal {
      continue
    }
    if parts.is_empty() {
      detail = if part == "pdf" {
        let n = @cmp.minimum(expected.pdf.length(), actual.pdf.length())
        let mut at = 0
        while at < n && expected.pdf[at] == actual.pdf[at] {
          at += 1
        }
        "  - \{expected.parts[i]}\n  + \{actual.parts[i]}\n  (first difference at byte \{at})"
      } else {
        first_diff(expected.parts[i], actual.parts[i])
      }
    }
    parts.push(part)
  }
  if parts.is_empty() {
    None
  } else {
    Some((parts, detail))
  }
}
