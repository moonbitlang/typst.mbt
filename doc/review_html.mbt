// The preview page of the review loop (docs/edsl-review.md, slices 1 and
// 2): the pages as the SVG that `svg_pages` exports, unchanged, and over
// each page a layer of invisible shapes, one per word, shape and image,
// that carry the number of their origin and, for text, of their word. The
// browser's own hit testing finds what is under the pointer; a script
// selects words, shows the origins and packages the feedback. The style
// sheet, the script and the markup around the pages are
// `doc/review_page/page.{css,js,html}` (`review_page_gen.mbt`).

///|
/// A number for an SVG attribute: at most four decimals, no negative zero.
fn svg_num(x : Double) -> String {
  let rounded = (x * 10000.0).round() / 10000.0
  if rounded == 0.0 {
    "0"
  } else {
    rounded.to_string()
  }
}

///|
/// Escape for HTML text and attribute values.
fn html_escape(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// The path data of a curve at `(x, y)`, in points.
fn path_data(curve : @library.Curve, x : Double, y : Double) -> String {
  let out = StringBuilder()
  let point = (p : @library.Point) => {
    out.write_string(svg_num(x + p.x.to_pt()))
    out.write_char(' ')
    out.write_string(svg_num(y + p.y.to_pt()))
    out.write_char(' ')
  }
  // A curve starts at its origin unless it moves first (as the exporter
  // and the click search read it).
  if !(curve.items().get(0) is Some(Move(_))) {
    out.write_string("M\{svg_num(x)} \{svg_num(y)} ")
  }
  for item in curve.items() {
    match item {
      Move(p) => {
        out.write_char('M')
        point(p)
      }
      Line(p) => {
        out.write_char('L')
        point(p)
      }
      Cubic(p1, p2, p3) => {
        out.write_char('C')
        point(p1)
        point(p2)
        point(p3)
      }
      Close => out.write_string("Z ")
    }
  }
  out.to_string()
}

///|
/// The origins of a page layer: each distinct origin once, in the order of
/// first use. The location inside a `Markup`/`Equation` source is left
/// out: the layer names the call.
priv struct OriginTable {
  origins : Origins
  list : Array[Origin]
  index : Map[String, Int]
  /// The number of clip paths written so far (their ids).
  mut clips : Int
  /// The words of the text, in reading order (`review_select.mbt`), the
  /// numbers of the pieces (spans), and the page that is being written.
  words : Array[Word]
  pieces : Map[@syntax.Span, Int]
  mut page : Int
  /// Whether the last text item was the hyphen of a line break: the next
  /// word is the rest of the word before it.
  mut hyphen : Bool
}

///|
/// The number of the piece with the given span.
fn OriginTable::piece(self : OriginTable, span : @syntax.Span) -> Int {
  match self.pieces.get(span) {
    Some(piece) => piece
    None => {
      let piece = self.pieces.length()
      self.pieces[span] = piece
      piece
    }
  }
}

///|
/// The number of the origin of a span, if it has one.
fn OriginTable::id(self : OriginTable, span : @syntax.Span) -> Int? {
  guard self.origins.resolve(span) is Some(origin) else { return Option::None }
  Some(self.number(origin))
}

///|
/// The number of an origin, entered on first use.
fn OriginTable::number(self : OriginTable, origin : Origin) -> Int {
  let key = StringBuilder()
  key.write_string(
    "\{origin.file}\u{0}\{origin.module_name}\u{0}\{origin.kind}\u{0}\{origin.start_line}:\{origin.start_column}-\{origin.end_line}:\{origin.end_column}\u{0}\{origin.param.unwrap_or(-1)}",
  )
  for k in origin.keys {
    key.write_string("\u{0}\{k.length()}:\{k}")
  }
  let key = key.to_string()
  match self.index.get(key) {
    Some(id) => id
    None => {
      let id = self.list.length()
      self.list.push(origin)
      self.index[key] = id
      id
    }
  }
}

///|
/// The answers of `origin_at` for a grid of points on every page, as
/// `[page, x, y, origin]` (`-1`: nothing): the page's self-test
/// (`#selftest` in its address) asks the browser for the shape of the
/// layer at each point and compares. The grid has at most 24 by 32 points
/// per page and about 4,000 points in all, so the work is bounded for a
/// document of any length (each point is one search of its page).
fn CompileReport::probes(
  self : CompileReport[@layout.PagedDocument],
  document : @layout.PagedDocument,
  table : OriginTable,
) -> Json {
  let probes : Array[Json] = []
  let number = (x : Double) => Json::number((x * 100.0).round() / 100.0)
  let pages = document.pages()
  // Three columns for four rows, like a page.
  let mut columns = 24
  while columns > 1 && columns * (columns * 4 / 3) * pages.length() > 4096 {
    columns -= 1
  }
  let rows = if columns * 4 / 3 > 1 { columns * 4 / 3 } else { 1 }
  for i, page in pages {
    let size = page.frame.size()
    for row in 0..<rows {
      for column in 0..<columns {
        // Off the round coordinates at which boxes tend to end.
        let x = ((column.to_double() + 0.37) *
          size.x.to_pt() /
          columns.to_double() *
          100.0).round() /
          100.0
        let y = ((row.to_double() + 0.61) *
          size.y.to_pt() /
          rows.to_double() *
          100.0).round() /
          100.0
        let id = match self.origin_at(i + 1, x, y) {
          Some(origin) => table.number(origin)
          None => -1
        }
        probes.push(
          Json::array([
            Json::number((i + 1).to_double()),
            number(x),
            number(y),
            Json::number(id.to_double()),
          ]),
        )
      }
    }
  }
  Json::array(probes)
}

///|
/// The table as JSON, for the page's script.
fn OriginTable::json(self : OriginTable) -> Json {
  Json::array(
    self.list.map(origin => {
      let fields : Map[String, Json] = Map([])
      fields["file"] = Json::string(origin.file)
      fields["module"] = Json::string(origin.module_name)
      fields["kind"] = Json::string(origin.kind)
      fields["range"] = Json::array(
        [
          origin.start_line,
          origin.start_column,
          origin.end_line,
          origin.end_column,
        ].map(n => Json::number(n.to_double())),
      )
      if origin.param is Some(param) {
        fields["param"] = Json::number(param.to_double())
      }
      if !origin.keys.is_empty() {
        fields["keys"] = Json::array(origin.keys.map(Json::string))
      }
      Json::object(fields)
    }),
  )
}

///|
/// Write the layer of a frame: for each item, in paint order, a shape with
/// the geometry that `CompileReport::click_in_frame` tests and the number
/// of its origin (`data-o`); the box of a word also has the number of the
/// word (`data-i`). Text without an origin, and shapes and images without
/// one, are left out, so that the pointer reaches what is under them, as
/// in `origin_at`; so are links.
fn OriginTable::layer(
  self : OriginTable,
  frame : @library.Frame,
  out : StringBuilder,
) -> Unit {
  // The text item before the current item, if the text can go on after
  // it: where its pen ends, and its baseline.
  let mut before : (Double, Double)? = Option::None
  for entry in frame.items() {
    let (pos, item) = entry
    let x = pos.x.to_pt()
    let y = pos.y.to_pt()
    let previous = before
    if !(item is Tag(_)) {
      before = Option::None
    }
    match item {
      Group(group) => {
        // The clip applies at the group's position, before its transform
        // (the click search tests it there).
        out.write_string(
          "<g transform=\"translate(\{svg_num(x)} \{svg_num(y)})\"",
        )
        if group.clip is Some(clip) {
          let id = "rv-clip-\{self.clips}"
          self.clips += 1
          out.write_string(
            " clip-path=\"url(#\{id})\"><clipPath id=\"\{id}\"><path d=\"\{path_data(clip, 0.0, 0.0)}\"/></clipPath",
          )
        }
        // (The coefficients are not rounded: nested scales multiply.)
        let ts = group.transform
        out.write_string(
          "><g transform=\"matrix(\{ts.sx.get()} \{ts.ky.get()} \{ts.kx.get()} \{ts.sy.get()} \{ts.tx.to_pt()} \{ts.ty.to_pt()})\">",
        )
        self.layer(group.frame, out)
        out.write_string("</g></g>")
      }
      Text(text) => {
        // The words of the item. The item continues the one before it if
        // it starts where that one ended, on the same baseline, and no
        // white space is at the seam: then its first word can be the rest
        // of a word (the style changes inside it).
        let chars = text.text.to_array()
        let apart = !self.hyphen &&
          !(previous is Some((px, py)) &&
          (px - x).abs() < 0.05 &&
          (py - y).abs() < 0.01 &&
          chars.get(0) is Some(first) &&
          !is_blank(first))
        // The hyphen that the engine adds where it breaks a word is a text
        // item of its own, a soft hyphen: it is no word, and the text goes
        // on with the rest of the word.
        self.hyphen = text.text == "\u{ad}"
        let word_of = if self.hyphen {
          Array::make(text.glyphs.length(), -1)
        } else {
          self.item_words(text, apart)
        }
        // One box per run of glyphs of the same word (or, between words,
        // of the same origin) whose boxes follow each other: the union of
        // the glyphs' boxes. A glyph with a negative advance has no box
        // (the click search finds nothing in it) and moves the pen back,
        // so the next box starts a new run, which can overlap an earlier
        // one. The search takes the first glyph that contains the point:
        // the boxes are written in reverse order, the first on top.
        let size = text.size.to_pt()
        let boxes : Array[(Int, Int, Double, Double)] = []
        let mut at = x
        for g, glyph in text.glyphs {
          let width = glyph.x_advance.at(text.size).to_pt()
          if width >= 0.0 && self.id(glyph.span) is Some(id) {
            match boxes.last() {
              Some((last, word, from, to)) if last == id &&
                word == word_of[g] &&
                to == at =>
                boxes[boxes.length() - 1] = (id, word, from, at + width)
              _ => boxes.push((id, word_of[g], at, at + width))
            }
          }
          at = at + width
        }
        for k = boxes.length() - 1; k >= 0; k = k - 1 {
          let (id, word, from, to) = boxes[k]
          // (`data-g`: a gap between words, which has an origin but is
          // nothing to select.)
          out.write_string("<rect data-o=\"\{id}\"")
          out.write_string(
            if word >= 0 {
              " data-i=\"\{word}\""
            } else {
              " data-g=\"\""
            },
          )
          out.write_string(
            " x=\"\{svg_num(from)}\" y=\"\{svg_num(y - size)}\" width=\"\{svg_num(to - from)}\" height=\"\{svg_num(size)}\"/>",
          )
        }
        if chars.last() is Some(last) && !is_blank(last) {
          before = Some((at, y))
        }
      }
      Shape(shape, span) => {
        guard self.id(span) is Some(id) else { continue }
        // Which part of the shape is hit: the interior of a filled shape
        // (not of a line), the stroke of a stroked one.
        let filled = shape.fill is Some(_) && !(shape.geometry is Line(_))
        let stroked = shape.stroke is Some(stroke) &&
          !stroke.thickness.approx_empty()
        guard filled || stroked else { continue }
        let events = if filled && stroked {
          "all"
        } else if filled {
          "fill"
        } else {
          "stroke"
        }
        let data = match shape.geometry {
          Line(to) =>
            "M\{svg_num(x)} \{svg_num(y)} L\{svg_num(x + to.x.to_pt())} \{svg_num(y + to.y.to_pt())}"
          Rect(size) => path_data(@library.Curve::rect(size), x, y)
          Curve(curve) => path_data(curve, x, y)
        }
        out.write_string(
          "<path data-o=\"\{id}\" d=\"\{data}\" pointer-events=\"\{events}\"",
        )
        if shape.fill_rule is EvenOdd {
          out.write_string(" fill-rule=\"evenodd\"")
        }
        if shape.stroke is Some(stroke) && stroked {
          let cap = match stroke.cap {
            Butt => "butt"
            Round => "round"
            Square => "square"
          }
          let join = match stroke.join {
            Miter => "miter"
            Round => "round"
            Bevel => "bevel"
          }
          out.write_string(
            " stroke-width=\"\{svg_num(stroke.thickness.to_pt())}\" stroke-linecap=\"\{cap}\" stroke-linejoin=\"\{join}\" stroke-miterlimit=\"\{svg_num(stroke.miter_limit.get())}\"",
          )
        }
        out.write_string("/>")
      }
      Image(_, size, span) => {
        guard self.id(span) is Some(id) else { continue }
        out.write_string(
          "<rect data-o=\"\{id}\" x=\"\{svg_num(x)}\" y=\"\{svg_num(y)}\" width=\"\{svg_num(size.x.to_pt())}\" height=\"\{svg_num(size.y.to_pt())}\"/>",
        )
      }
      _ => ()
    }
  }
}

///|
/// The name of a document in the review: the given one, or its title.
fn review_title(document : @layout.PagedDocument, title : String?) -> String {
  match (title, document.info().title) {
    (Some(title), _) => title
    (None, Some(title)) => title
    (None, None) => "Document"
  }
}

///|
/// The layer of every page (the content of its `svg` element), with the
/// table of origins and the words that the layers refer to.
fn[T] CompileReport::review_layers(
  self : CompileReport[T],
  document : @layout.PagedDocument,
) -> (OriginTable, Array[String]) {
  let table : OriginTable = {
    origins: self.origins,
    list: [],
    index: Map([]),
    clips: 0,
    words: [],
    pieces: Map([]),
    page: 0,
    hyphen: false,
  }
  let layers = document
    .pages()
    .mapi((i, page) => {
      let out = StringBuilder()
      table.page = i + 1
      table.layer(page.frame, out)
      out.to_string()
    })
  (table, layers)
}

///|
/// Records of the library for the page's self-test: the feedback for some
/// selections of words (`[from, to, record, text]`) and, where the grid of
/// probes found a shape or an image, for one of those (`[origin, page,
/// record, text]` in `objects`).
fn ReviewText::samples(self : ReviewText) -> (Json, Json) {
  let int = (n : Int) => Json::number(n.to_double())
  let samples : Array[Json] = []
  let count = self.words.length()
  // Selections of 1, 2, 7 and 40 words at places spread over the text.
  for k in 0..<24 {
    let from = if count == 0 { 0 } else { k * 7919 % count }
    let to = from + [0, 1, 6, 39][k % 4]
    guard self.range(from, if to < count { to } else { count - 1 })
      is Some(selection) else {
      continue
    }
    let feedback = self.feedback(selection, "self-test \{k}")
    samples.push(
      Json::array([
        int(selection.from),
        int(selection.to),
        feedback.to_json(),
        Json::string(feedback.to_text()),
      ]),
    )
  }
  let objects : Array[Json] = []
  for id, origin in self.origins {
    guard id % 7 == 0 else { continue }
    let feedback = self.origin_feedback(origin, 1, "")
    objects.push(
      Json::array([
        int(id),
        int(1),
        feedback.to_json(),
        Json::string(feedback.to_text()),
      ]),
    )
  }
  (Json::array(samples), Json::array(objects))
}

///|
/// Export the preview page of the review loop: one self-contained HTML
/// document with every page as the SVG that `svg_pages` exports and, over
/// it, the origin of every word, shape and image. In the page, words are
/// selected by dragging or clicking; a panel shows the constructor calls
/// (file, line and column range, constructor, parameter) that produced the
/// selection, takes a comment, and gives the feedback record as text and
/// as JSON to copy (`ReviewText::feedback` builds the same record).
///
/// The export reads the compiled document and changes nothing of it.
/// `title` names the document in the page (default: the document's title).
pub fn CompileReport::review_html(
  self : CompileReport[@layout.PagedDocument],
  title? : String,
) -> ExportReport[String] {
  guard self.output is Some(document) else { return self.failed() }
  let title = review_title(document, title)
  let options = @svg.SvgOptions::default().resolve(
    @svg.SvgFormatOptions::get(document.options()),
  )
  let (table, layers) = self.review_layers(document)
  let out = StringBuilder()
  out.write_string(
    "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n",
  )
  out.write_string("<title>\{html_escape(title)} review</title>\n<style>\n")
  out.write_string(review_page_css)
  out.write_string("</style>\n</head>\n<body>\n")
  out.write_string(
    review_page_body.replace(old="{{TITLE}}", new=html_escape(title)),
  )
  out.write_string("<main id=\"pages\" class=\"pages\">\n")
  for i, page in document.pages() {
    let size = page.frame.size()
    let width = svg_num(size.x.to_pt())
    let height = svg_num(size.y.to_pt())
    // The exporter's SVG is inert: a link in it can be neither focused
    // nor followed, so nothing leads out of the page.
    out.write_string(
      "<section class=\"page\" style=\"aspect-ratio: \{width} / \{height}\" aria-label=\"Page \{i + 1}\">\n<div class=\"art\" inert>",
    )
    out.write_string(@svg.svg(page, options))
    out.write_string(
      "</div>\n<svg class=\"hit\" data-page=\"\{i + 1}\" viewBox=\"0 0 \{width} \{height}\" xmlns=\"http://www.w3.org/2000/svg\">",
    )
    out.write_string(layers[i])
    out.write_string("</svg>\n</section>\n")
  }
  out.write_string("</main>\n")
  out.write_string(review_page_tail)
  // The data: the words (`[page, text, apart, origin, piece]`), the
  // library's answers for the self-test, and the table of origins (after
  // the probes, which can add an origin that no box has).
  let text : ReviewText = { title, origins: table.list, words: table.words, }
  let data : Map[String, Json] = Map([])
  data["title"] = Json::string(title)
  data["words"] = Json::array(
    table.words.map(word => {
      Json::array([
        Json::number(word.page.to_double()),
        Json::string(word.text),
        Json::number(if word.space { 1.0 } else { 0.0 }),
        Json::number(word.origin.to_double()),
        Json::number(word.piece.to_double()),
      ])
    }),
  )
  data["probes"] = self.probes(document, table)
  let (samples, objects) = text.samples()
  data["samples"] = samples
  data["objects"] = objects
  data["origins"] = table.json()
  // `<` cannot end the script element or start a comment.
  out.write_string("<script type=\"application/json\" id=\"review-data\">")
  out.write_string(
    Json::object(data).stringify().replace_all(old="<", new="\\u003c"),
  )
  out.write_string("</script>\n<script>\n")
  out.write_string(review_page_js)
  out.write_string("</script>\n</body>\n</html>\n")
  {
    output: Some(out.to_string()),
    errors: [],
    warnings: self.warnings,
    origins: self.origins,
  }
}
