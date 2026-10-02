// The `pdf-semantic-replay` stage: tests the PDF exporter independently of
// layout. Like `svg-replay`, it decodes upstream's laid-out document from
// the `paged` goldens, exports it to PDF and compares the result with the
// `pdf-semantic` goldens.
//
// The decoded document has no document info, format options or
// introspection data (headings, element positions), so only the page
// content is compared (see [pdf_replay_canonicalize]): pages, text, paths,
// images, shadings and annotation rectangles with their URI targets.
// Documents with export errors upstream (which depend on the document's
// format options) are skipped.

///|
/// Decode a document from its `typst-frame-v1` records and export it.
fn pdf_replay_report(rel : String, tc : TestCase) -> String {
  let golden = paged_golden(rel).get(tc.name).unwrap_or("")
  let records = []
  for line in golden.split("\n") {
    if line.is_empty() {
      continue
    }
    let json = @json.parse(line.to_owned()) catch {
      _ => return "<unsupported: malformed frame record>\n"
    }
    guard json is Array(fields) && fields.length() > 0 else {
      return "<unsupported: malformed frame record>\n"
    }
    records.push(fields)
  }
  let decoder = FrameDecoder::new()
  for rec in records {
    if rec[0] is String("diagnostics") && rec[1] is String("err") {
      return "<error>\n"
    }
  }
  if records.is_empty() {
    return "<unsupported: missing paged golden>\n"
  }
  let doc = decoder.document(records) catch {
    Unsupported(msg) => return "<unsupported: \{msg}>\n"
  }
  // Export errors depend on the document's format options, which the
  // decoded document lacks.
  if pdf_semantic_golden(rel)
    .get(tc.name)
    .unwrap_or("")
    .has_prefix("export-error") {
    return "export-error\n"
  }
  doc.info_mut().title = Some(tc.name)
  let warned = make_live(doc)
  match warned.output {
    Err(_) => "export-error\n"
    Ok(bytes) => pdf_extract(bytes)
  }
}

///|
/// Keep the page content lines of a dump (see the module docs).
fn pdf_replay_canonicalize(dump : String) -> String {
  if dump.has_prefix("<") {
    return dump
  }
  let out = StringBuilder()
  let mut export_error = false
  for line in dump.split("\n") {
    let line = line.to_string()
    if line == "export-error" {
      export_error = true
    }
    if line.has_prefix("page ") ||
      line.has_prefix("  text ") ||
      line.has_prefix("  path ") ||
      line.has_prefix("  image ") ||
      line.has_prefix("  shading ") {
      out.write_string(line)
      out.write_char('\n')
    } else if line.has_prefix("  annot ") {
      // Keep the subtype, rectangle and URI targets.
      let line = match line.find(" contents ") {
        Some(i) => line.unsafe_substring(start=0, end=i)
        None => line
      }
      match line.find("] ") {
        Some(i) => {
          let head = line.unsafe_substring(start=0, end=i + 1)
          let target = line.unsafe_substring(start=i + 2, end=line.length())
          out.write_string(head)
          if target.has_prefix("uri ") {
            out.write_string(" \{target}")
          }
          out.write_char('\n')
        }
        None => {
          out.write_string(line)
          out.write_char('\n')
        }
      }
    }
  }
  if export_error {
    "<skipped: export error>\n"
  } else {
    out.to_string()
  }
}
