// The `bundle` stage: compile every `bundle` test to a `Bundle`, export it
// like the upstream test runner (`tests/src/output.rs`, `impl OutputType for
// Bundle`) and dump the files in the oracle's format (see
// `oracle/src/bundle.rs`).

///|
/// With `--stub-binary`, PDF and PNG documents are "exported" to empty files
/// and compared without their sizes and hashes, which checks everything but
/// the PDF and PNG exporters themselves.
let bundle_stub_binary : Ref[Bool] = Ref::new(false)

///|
/// The export options of the upstream test runner (PNG export is not wired
/// up yet, see `bundle/export.mbt`).
fn bundle_options() -> @bundle.BundleOptions {
  let (pdf, png) : (@bundle.PdfExport?, @bundle.PngExport?) = if bundle_stub_binary.val {
    (Some((_, _, _) => { output: Ok(b""), warnings: [], }), Some(_ => b""))
  } else {
    let pdf_options : @pdf.PdfOptions = {
      ..@pdf.PdfOptions::default(),
      creator: Custom(Some("Typst Test Runner")),
      format: { ..@pdf.PartialPdfFormatOptions::default(), standard: None, },
    }
    (
      Some((doc, anchors, resolver) => {
        @pdf.pdf_in_bundle(doc, pdf_options, anchors, resolver)
      }),
      None,
    )
  }
  {
    html: { format: { pretty: Some(true), }, },
    pdf,
    png,
    svg: { render_bleed: false, format: { pretty: Some(true), }, },
  }
}

///|
/// Compile a test case to a bundle in the oracle's report format.
fn bundle_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let main_id = source.id()
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let warned : @library.Warned[
    Result[@bundle.Bundle, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  let warnings = warned.warnings.copy()
  let out = StringBuilder()
  match warned.output {
    Ok(bundle) => {
      let exported = @bundle.export_bundle(bundle, bundle_options())
      warnings.append(exported.warnings)
      match exported.output {
        Ok(fs) => {
          out.write_string("ok\n")
          for path, data in fs {
            let kind = match bundle.files.get(path) {
              Some(Asset(_)) => "asset"
              Some(Document(Html(_))) => "html"
              Some(Document(Paged(_, extras))) =>
                match extras.format {
                  Pdf => "pdf"
                  Png => "png"
                  Svg => "svg"
                }
              None => "?"
            }
            let bytes = data.as_slice()
            out.write_string(
              "--- \{path.get_without_slash()} (\{kind}, \{bytes.length()} bytes, sha256 \{sha256_hex(bytes)})\n",
            )
            let text = match kind {
              "html" | "svg" | "asset" => data.as_str()
              _ => None
            }
            if text is Some(text) {
              out.write_string(text)
              if !text.has_suffix("\n") {
                out.write_char('\n')
              }
            }
          }
        }
        Err(errors) => {
          out.write_string("err\n")
          for diag in @typst.deduplicate(errors) {
            write_source_diag(out, world, main_id, diag)
          }
        }
      }
    }
    Err(errors) => {
      out.write_string("err\n")
      for diag in errors {
        write_source_diag(out, world, main_id, diag)
      }
    }
  }
  for diag in @typst.deduplicate(warnings) {
    write_source_diag(out, world, main_id, diag)
  }
  out.to_string()
}

///|
/// Canonicalizes a bundle report for comparison: SVG documents are compared
/// by their text after canonically renaming the hash-derived `<defs>` IDs
/// (like the `svg` stage), so their size and hash are dropped. The same
/// holds for PDF documents, and with `--stub-binary` for PNG documents.
fn canonicalize_bundle(report : String) -> String {
  let out = StringBuilder()
  // PDF files are not expected to be byte-identical to upstream's (the
  // exporter is checked by the `pdf-semantic` stage).
  let kinds = if bundle_stub_binary.val {
    ["svg", "pdf", "png"]
  } else {
    ["svg", "pdf"]
  }
  for line in report.split("\n") {
    let kind = kinds.search_by(k => line.find(" (\{k}, ") is Some(_))
    if line.has_prefix("--- ") && kind is Some(k) && line.has_suffix(")") {
      let at = line.find(" (\{kinds[k]}, ").unwrap()
      out.write_string(line[:at].to_string())
      out.write_string(" (\{kinds[k]})")
    } else {
      out.write_string(line.to_string())
    }
    out.write_char('\n')
  }
  canonicalize_svg_ids(out.to_string())
}
