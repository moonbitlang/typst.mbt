// From the source to the page (docs/edsl-review.md, slice 4): where on the
// pages is what a source line produced. The direction of upstream's
// `jump_from_cursor`, for a line (and column) of a MoonBit source file.

///|
/// An affine map `x' = a x + c y + e`, `y' = b x + d y + f` (the order of
/// an SVG `matrix`), in points: from a frame's coordinates to the page's.
priv struct Mat {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
let mat_identity : Mat = { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0, }

///|
/// `self`, then inside it a translation by `(x, y)` and the transform
/// `ts`: the map of a group at `(x, y)` in a frame with the map `self`.
fn Mat::group(
  self : Mat,
  x : Double,
  y : Double,
  ts : @library.Transform,
) -> Mat {
  // Translation, then the group's own transform.
  let (a, b, c, d) = (ts.sx.get(), ts.ky.get(), ts.kx.get(), ts.sy.get())
  let (e, f) = (ts.tx.to_pt() + x, ts.ty.to_pt() + y)
  {
    a: self.a * a + self.c * b,
    b: self.b * a + self.d * b,
    c: self.a * c + self.c * d,
    d: self.b * c + self.d * d,
    e: self.a * e + self.c * f + self.e,
    f: self.b * e + self.d * f + self.f,
  }
}

///|
/// A rectangle on a page, in points from the page's top left corner.
pub struct Region {
  /// The page, from 1.
  page : Int
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
/// A box of the layer on its page: of a word (`word`), of a gap between
/// words or of a shape or an image (`word` is `-1`), with its origin.
priv struct PageBox {
  origin : Int
  word : Int
  region : Region
}

///|
/// The bounding box of some points (at least one): left, top, right,
/// bottom.
fn bounds(points : Array[(Double, Double)]) -> (Double, Double, Double, Double) {
  let mut left = points[0].0
  let mut right = points[0].0
  let mut top = points[0].1
  let mut bottom = points[0].1
  for p in points {
    left = if p.0 < left { p.0 } else { left }
    right = if p.0 > right { p.0 } else { right }
    top = if p.1 < top { p.1 } else { top }
    bottom = if p.1 > bottom { p.1 } else { bottom }
  }
  (left, top, right, bottom)
}

///|
/// Note the box `x0..x1`, `y0..y1` of a frame with the map `mat`: its
/// bounding box on the page.
fn OriginTable::note_box(
  self : OriginTable,
  mat : Mat,
  origin : Int,
  word : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let (left, top, right, bottom) = bounds(
    [(x0, y0), (x1, y0), (x1, y1), (x0, y1)].map(corner => {
      (
        mat.a * corner.0 + mat.c * corner.1 + mat.e,
        mat.b * corner.0 + mat.d * corner.1 + mat.f,
      )
    }),
  )
  self.boxes.push({
    origin,
    word,
    region: {
      page: self.page,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    },
  })
}

///|
/// The bounding box of a shape at `(x, y)` in its frame: of its geometry
/// (for a curve, of its points and control points), widened by half the
/// stroke.
fn shape_box(
  shape : @library.Shape,
  x : Double,
  y : Double,
) -> (Double, Double, Double, Double) {
  let points : Array[(Double, Double)] = [(0.0, 0.0)]
  let point = (p : @library.Point) => points.push((p.x.to_pt(), p.y.to_pt()))
  match shape.geometry {
    Line(to) => point(to)
    Rect(size) => points.push((size.x.to_pt(), size.y.to_pt()))
    Curve(curve) => {
      points.clear()
      for item in curve.items() {
        match item {
          Move(p) | Line(p) => point(p)
          Cubic(p1, p2, p3) => {
            point(p1)
            point(p2)
            point(p3)
          }
          Close => ()
        }
      }
      if points.is_empty() {
        points.push((0.0, 0.0))
      }
    }
  }
  let pad = match shape.stroke {
    Some(stroke) => stroke.thickness.to_pt() / 2.0
    None => 0.0
  }
  let (left, top, right, bottom) = bounds(points)
  (x + left - pad, y + top - pad, x + right + pad, y + bottom + pad)
}

///|
/// What a line of a source file produced: the words that are spelled on
/// the line, and the origins whose content is found as a whole.
///
/// An origin is a candidate if its location (the argument, or the call)
/// has the line — with a column, the position — and its file is `file`.
/// A candidate with source characters (tier 3) gives the words that have
/// some on the line (at the column). Another candidate gives everything
/// it produced, unless a narrower candidate lies inside its location: the
/// line of an argument does not light up the whole call around it.
fn ReviewText::line_hits(
  self : ReviewText,
  file : String,
  line : Int,
  column : Int?,
) -> (Array[Int], Array[Int]) {
  let has = (o : Origin) => {
    o.file == file &&
    o.start_line <= line &&
    line <= o.end_line &&
    (match column {
      Some(column) =>
        (o.start_line < line || o.start_column <= column) &&
        (line < o.end_line || column < o.end_column)
      None => true
    })
  }
  // `b` lies inside `a`, and is narrower.
  let inside = (b : Origin, a : Origin) => {
    let starts = b.start_line > a.start_line ||
      (b.start_line == a.start_line && b.start_column >= a.start_column)
    let ends = b.end_line < a.end_line ||
      (b.end_line == a.end_line && b.end_column <= a.end_column)
    let same = b.start_line == a.start_line &&
      b.start_column == a.start_column &&
      b.end_line == a.end_line &&
      b.end_column == a.end_column
    starts && ends && !same
  }
  let candidates : Array[Int] = []
  for id, origin in self.origins {
    if has(origin) {
      candidates.push(id)
    }
  }
  let exact : Map[Int, Unit] = Map([])
  let whole : Array[Int] = []
  for id in candidates {
    if self.infos[id].tier == 3 {
      exact[id] = ()
    } else if !candidates
      .iter()
      .any(other => inside(self.origins[other], self.origins[id])) {
      whole.push(id)
    }
  }
  let words : Array[Int] = []
  if !exact.is_empty() {
    for number, word in self.words {
      guard exact.contains(word.origin) else { continue }
      for seg in self.segs[number] {
        if seg.line == line &&
          (match column {
            Some(column) => seg.start <= column && column < seg.end
            None => true
          }) {
          words.push(number)
          break
        }
      }
    }
  }
  (words, whole)
}

///|
/// Where on the pages is what a line of a source file produced (the
/// direction of upstream's `jump_from_cursor`): the boxes of the words
/// that the line spells — for arguments whose source characters are known
/// (`review_text(sources=..)`) — and of everything else whose location is
/// on the line, in the order of the pages. `file` is the file of an origin
/// (`Origin::file`), `line` and `column` are one-based; with a `column`
/// only what is at that position.
pub fn ReviewText::positions(
  self : ReviewText,
  file : String,
  line : Int,
  column? : Int,
) -> Array[Region] {
  let (words, whole) = self.line_hits(file, line, column)
  let regions : Array[Region] = []
  for box in self.boxes {
    if (box.word >= 0 && words.binary_search(box.word) is Ok(_)) ||
      whole.contains(box.origin) {
      regions.push(box.region)
    }
  }
  regions
}

///|
/// Where on the pages is what an origin produced: the boxes of its words,
/// shapes and images, in the order of the pages. (An origin of another
/// document has none.)
pub fn ReviewText::origin_positions(
  self : ReviewText,
  origin : Origin,
) -> Array[Region] {
  guard self.origin_number(origin) is Some(id) else { return [] }
  self.boxes.filter(box => box.origin == id).map(box => box.region)
}
