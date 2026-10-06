// The pixels of a compiled page, for what the frames do not show: how an
// outline and the fills beside it come out of the rasterizer. The pages of
// these tests are grey, so a pixel is one number, 0 (black) to 255.

///|
/// A rendered page.
priv struct Pixels {
  width : Int
  height : Int
  /// Pixels per point.
  scale : Double
  rgba : Bytes
}

///|
/// Page `page` (from 1) of a compiled document at `ppi` pixels per inch,
/// through the PNG that `png_pages` exports.
fn pixels(
  report : @doc.CompileReport[@layout.PagedDocument],
  page? : Int = 1,
  ppi? : Double = 110.0,
) -> Pixels raise {
  let png = report.png_pages(ppi~).unwrap()[page - 1]
  let (info, data) = @codecs.decode_png(png)
  {
    width: info.width.reinterpret_as_int(),
    height: info.height.reinterpret_as_int(),
    scale: ppi / 72.0,
    rgba: @codecs.to_rgba8(info.width, info.height, info.color, data),
  }
}

///|
/// The grey of the pixel in column `x` of row `y`.
fn Pixels::at(self : Pixels, x : Int, y : Int) -> Int {
  self.rgba[(y * self.width + x) * 4].to_int()
}

///|
/// The pixel that holds the point `at` (in points) of an axis.
fn Pixels::pixel(self : Pixels, at : Double) -> Int {
  (at * self.scale).floor().to_int()
}

///|
/// The pixels of row `y` from column `from` up to `to`.
fn Pixels::across(self : Pixels, y : Int, from : Int, to : Int) -> String {
  let out : Array[String] = []
  for x in from..<to {
    out.push(self.at(x, y).to_string())
  }
  out.join(" ")
}

///|
/// Where the outline of a box differs between two renderings of pages of
/// one size: the pixels within `reach` pixels of the four sides of the box
/// `(x, y, w, h)` (in points), corners included, without the rows that
/// `skip` names (in points, as `(from, to)`). One line for each pixel that
/// differs, `x,y: a b`; `""` if none does.
fn outline_differences(
  a : Pixels,
  b : Pixels,
  frame : (Double, Double, Double, Double),
  skip? : Array[(Double, Double)] = [],
  reach? : Int = 3,
) -> String {
  guard a.width == b.width && a.height == b.height else {
    return "pages of \{a.width}x\{a.height} and \{b.width}x\{b.height} pixels"
  }
  let (x, y, w, h) = frame
  let left = a.pixel(x)
  let right = a.pixel(x + w)
  let top = a.pixel(y)
  let bottom = a.pixel(y + h)
  let near = (at : Int, side : Int) => (at - side).abs() <= reach
  let out : Array[String] = []
  for py in (top - reach)..<=(bottom + reach) {
    if skip
      .iter()
      .any(rows => py >= a.pixel(rows.0) - 1 && py <= a.pixel(rows.1) + 1) {
      continue
    }
    for px in (left - reach)..<=(right + reach) {
      guard near(px, left) ||
        near(px, right) ||
        near(py, top) ||
        near(py, bottom) else {
        continue
      }
      if a.at(px, py) != b.at(px, py) {
        out.push("\{px},\{py}: \{a.at(px, py)} \{b.at(px, py)}")
      }
    }
  }
  out.join("\n")
}
