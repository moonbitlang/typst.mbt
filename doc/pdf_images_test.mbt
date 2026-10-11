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
      guard c is ('0'..<='9') else { break }
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
