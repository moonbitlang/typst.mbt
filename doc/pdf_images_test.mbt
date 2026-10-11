// The images of an exported PDF, end to end: which raster images of a
// document are one image of the file, and that what is kept by content
// between exports (decoded images, the exporter's conversions:
// `library/memo_content.mbt`) does not change a byte of it.

///|
/// The image XObjects of a PDF in the order of the file: width, height,
/// and what else their dictionaries say.
fn pdf_images(pdf : Bytes) -> Array[String] {
  // The dictionary of a stream is not compressed.
  let text = StringBuilder()
  for byte in pdf {
    text.write_char(byte.to_int().unsafe_to_char())
  }
  let text = text.to_string()
  let number = (dict : StringView, key : String) => {
    guard dict.find(key) is Some(at) else { return "?" }
    let digits = StringBuilder()
    for c in dict[at + key.length():] {
      guard c is ('0'..='9') else { break }
      digits.write_char(c)
    }
    digits.to_string()
  }
  let out = []
  let mut rest = text[:]
  while rest.find("/Subtype /Image") is Some(at) {
    let from = rest[:at].rev_find("<<").unwrap_or(0)
    let to = at + rest[at:].find(">>").unwrap_or(0)
    let dict = rest[from:to]
    let entry = StringBuilder()
    entry.write_string(number(dict, "/Width "))
    entry.write_char('x')
    entry.write_string(number(dict, "/Height "))
    if dict.contains("/DeviceGray") {
      entry.write_string(" mask")
    }
    if dict.contains("/SMask") {
      entry.write_string(" masked")
    }
    if dict.contains("/Interpolate true") {
      entry.write_string(" interpolate")
    }
    out.push(entry.to_string())
    rest = rest[to:]
  }
  out
}

///|
test "pdf: raster images are embedded once per image, not once per data" {
  let data = Bytes::makei(240, i => (i * 37 % 256).to_byte())
  let files : Map[String, Bytes] = {
    "a.raw": data,
    // The same bytes in another file.
    "b.raw": Bytes::makei(240, i => (i * 37 % 256).to_byte()),
  }
  let source =
    #|#set page(width: 200pt, height: auto, margin: 5pt)
    #|#let data = bytes(range(240).map(i => calc.rem(i * 37, 256)))
    #|#let rgb = (encoding: "rgb8", width: 10, height: 8)
    #|// The same bytes as pixels of three formats.
    #|#image(data, format: rgb, width: 60pt)
    #|#image(data, format: (encoding: "luma8", width: 20, height: 12), width: 60pt)
    #|#image(data, format: (encoding: "luma8", width: 12, height: 20), height: 40pt)
    #|#pagebreak()
    #|// The first again: at another size, smooth, and from a file.
    #|#image(data, format: rgb, width: 30pt)
    #|#image(data, format: rgb, width: 30pt, scaling: "smooth")
    #|#image("a.raw", format: rgb)
    #|// With an alpha channel, from two files of the same bytes.
    #|#image("a.raw", format: (encoding: "rgba8", width: 10, height: 6))
    #|#image("b.raw", format: (encoding: "rgba8", width: 10, height: 6), scaling: "pixelated")
    #|
  let exported = () => compile([@doc.Markup(source)], files~).pdf().unwrap()
  let first = exported()
  // What upstream embeds (the last one is the alpha channel of the image
  // before it). The exporter took all images of the same bytes for one: it
  // embedded the first and the smooth one.
  inspect(
    pdf_images(first).join("\n"),
    content=(
      #|10x8
      #|20x12
      #|12x20
      #|10x8 interpolate
      #|10x6 masked
      #|10x6 mask
    ),
  )
  // The same bytes again: from what was kept by the export before, after
  // `evict` dropped it, and without memoization.
  assert_true(exported() == first)
  @library.evict(0)
  assert_true(exported() == first)
  @library.set_layout_memo_enabled(false)
  let plain = {
    defer @library.set_layout_memo_enabled(true)
    exported()
  }
  assert_true(plain == first)
  assert_true(exported() == first)
  // One compilation exported twice.
  let report = compile([@doc.Markup(source)], files~)
  assert_true(report.pdf().unwrap() == first)
  assert_true(report.pdf().unwrap() == first)
}

///|
test "pdf: an image kept by one export is the same bytes in the next, whatever the standard" {
  // What an export keeps of an image is its compressed samples
  // (`pdf/image.mbt`, `convert_raster`). The standard, the version and the
  // errors of a document are not part of that: the exports below share the
  // kept images.
  let source =
    #|#set page(width: 200pt, height: auto, margin: 5pt)
    #|#set document(date: datetime(year: 2026, month: 10, day: 11))
    #|#let n = 48 * 32
    #|#let rgba = bytes(range(n * 4).map(i => calc.rem(calc.quo(i, 9) * 37 + calc.rem(i, 4) * 11, 256)))
    #|#let luma = bytes(range(n).map(i => calc.rem(calc.quo(i, 5) * 13, 256)))
    #|#let with-alpha = (encoding: "rgba8", width: 48, height: 32)
    #|#image(rgba, format: with-alpha, width: 96pt)
    #|#image(rgba, format: (encoding: "rgb8", width: 64, height: 32), width: 96pt)
    #|#image(luma, format: (encoding: "luma8", width: 48, height: 32), width: 96pt)
    #|#image(rgba, format: (encoding: "lumaa8", width: 96, height: 32), width: 96pt)
    #|#pagebreak()
    #|#image(rgba, format: with-alpha, width: 48pt)
    #|#image(luma, format: (encoding: "luma8", width: 48, height: 32), width: 48pt)
    #|
  let smooth =
    #|#pagebreak()
    #|#image(rgba, format: with-alpha, width: 48pt, scaling: "smooth")
    #|
  let options = (standards : Array[@library.PdfStandard]) => @pdf.PdfOptions::{
    ..@pdf.PdfOptions::default(),
    format: {
      ..@pdf.PartialPdfFormatOptions::default(),
      standard: Some(@library.PdfStandards::new(standards)),
    },
  }
  // What an export gives: the file, or its errors.
  let exported = (text : String, standards : Array[@library.PdfStandard]) => {
    let report = compile([@doc.Markup(text)]).pdf(options=options(standards))
    match report.output() {
      Some(bytes) => Ok(bytes)
      // With their places: a kept image is drawn at other places in other
      // documents.
      None => Err(report.errors.map(e => e.render()).join("\n"))
    }
  }
  let cases : Array[(String, Array[@library.PdfStandard])] = [
    (source, []),
    (source, [V_1_4]),
    (source + smooth, [V_1_7]),
    (source, [V_2_0]),
    (source, [A_2b]),
    // PDF/A-1 has no transparency and PDF/A no interpolation: errors of a
    // document, which the next one does not inherit.
    (source, [A_1b]),
    ("// The same images,\n// two lines further down.\n" + source, [A_1b]),
    (source + smooth, [A_3b]),
    (source + smooth, [V_2_0]),
    (source, [A_4]),
  ]
  // The reference: every document from nothing and without memoization
  // (the exporter is given samples and compresses them for the document).
  @library.evict(0)
  @library.set_layout_memo_enabled(false)
  let reference : Array[Result[Bytes, String]] = {
    defer @library.set_layout_memo_enabled(true)
    cases.map(c => exported(c.0, c.1))
  }
  inspect(
    reference
    .map(r => {
      match r {
        Ok(_) => "ok"
        Err(message) => message
      }
    })
    .join("\n"),
    content=(
      #|ok
      #|ok
      #|ok
      #|ok
      #|ok
      #|error: PDF/A-1b error: the image contains transparency
      #|  at doc/pdf_images_test.mbt:143:27 (Markup, bytes 364..408 of the source string)
      #|  hint: try exporting with a different standard that supports transparency
      #|  hint: or convert the image to a non-transparent one
      #|  hint: you might have to convert SVGs into non-transparent bitmap images
      #|error: PDF/A-1b error: the image contains transparency
      #|  at doc/pdf_images_test.mbt:143:27 (Markup, bytes 565..642 of the source string)
      #|  hint: try exporting with a different standard that supports transparency
      #|  hint: or convert the image to a non-transparent one
      #|  hint: you might have to convert SVGs into non-transparent bitmap images
      #|error: PDF/A-1b error: the image contains transparency
      #|  at doc/pdf_images_test.mbt:143:27 (Markup, bytes 411..455 of the source string)
      #|  hint: try exporting with a different standard that supports transparency
      #|  hint: or convert the image to a non-transparent one
      #|  hint: you might have to convert SVGs into non-transparent bitmap images
      #|error: PDF/A-1b error: the image contains transparency
      #|  at doc/pdf_images_test.mbt:143:27 (Markup, bytes 612..689 of the source string)
      #|  hint: try exporting with a different standard that supports transparency
      #|  hint: or convert the image to a non-transparent one
      #|  hint: you might have to convert SVGs into non-transparent bitmap images
      #|error: PDF/A-3b error: the image has smooth scaling
      #|  at doc/pdf_images_test.mbt:143:27 (Markup, bytes 794..857 of the source string)
      #|  hint: set the `scaling` attribute to `pixelated`
      #|ok
      #|ok
    ),
  )
  // One after the other with what the exports before kept, in both orders,
  // and with everything dropped after each.
  for round in 0..<3 {
    for i in 0..<cases.length() {
      let i = if round == 1 { cases.length() - 1 - i } else { i }
      assert_true(exported(cases[i].0, cases[i].1) == reference[i])
      if round == 2 {
        @library.evict(0)
      }
    }
  }
}
