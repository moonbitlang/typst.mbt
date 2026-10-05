// Feedback (docs/edsl-review.md, slices 2 and 3): a selection and a
// comment as a record for the author of the document, with excerpts of
// the source, as JSON and as a block of text that explains itself when it
// is pasted somewhere. The preview page
// builds the same record in its script (`doc/review_page/page.js`); the
// page carries records made here, and its self-test compares.

///|
/// One source location of a feedback record.
pub struct FeedbackOrigin {
  /// The constructor call, and the argument if the location is narrower.
  origin : Origin
  /// The selected text of each selected piece of the argument, in reading
  /// order. Pieces of one argument (the runs of a `Prose`, the strings of
  /// an array) share the origin: the location is the argument as a whole,
  /// and the texts say which parts of it are meant.
  pieces : Array[String]
  /// The selected text of this origin (`…` where text of another origin
  /// is between two parts).
  rendered : String
  /// How narrow the location is. 3: `source_ranges` are the characters of
  /// the source that spell the selected text (the argument is a literal,
  /// and it is the text on the page). 2: the argument as a whole. 1: the
  /// constructor call.
  tier : Int
  /// Why the location is not narrower (empty for tier 3).
  why : String
  source_ranges : Array[SourceSpan]
  /// Lines of the source file (number and text): those of the source
  /// characters, or else of the location; at most six. `more` lines were
  /// left out. Empty if the source file was not read.
  excerpt : Array[(Int, String)]
  more : Int
}

///|
/// A review comment with the source locations of what it is about.
pub struct Feedback {
  /// The document's title.
  document : String
  comment : String
  /// The selected text as it is rendered (empty for a shape or an image).
  selected_text : String
  /// The pages of the selection, from 1.
  pages : Array[Int]
  /// The origins of the selection, each once, in reading order.
  origins : Array[FeedbackOrigin]
}

///|
/// The feedback record for a selection of text.
pub fn ReviewText::feedback(
  self : ReviewText,
  selection : Selection,
  comment : String,
) -> Feedback {
  let pages : Array[Int] = []
  // Per origin, in the order of first use: the texts of its pieces, its
  // own text, and the last word that was added to it.
  let order : Array[Int] = []
  let found : Map[Int, (Array[StringBuilder], StringBuilder, Int)] = Map([])
  // The selected words of each origin.
  let chosen : Map[Int, Array[Int]] = Map([])
  // Per piece: its place among the pieces of its origin, and its last
  // word.
  let places : Map[Int, (Int, Int)] = Map([])
  // What joins a word to the text it continues: nothing if it touches the
  // word before it, a gap if other words are between.
  let joint = (last : Int, i : Int, word : Word) => {
    if last != i - 1 {
      " … "
    } else if word.space {
      " "
    } else {
      ""
    }
  }
  // (A selection of another text is cut to this one.)
  let to = if selection.to < self.words.length() {
    selection.to
  } else {
    self.words.length() - 1
  }
  for i in selection.from..<(to + 1) {
    let word = self.words[i]
    if !pages.contains(word.page) {
      pages.push(word.page)
    }
    let (pieces, rendered, last) = match found.get(word.origin) {
      Some(entry) => entry
      None => {
        order.push(word.origin)
        ([], StringBuilder(), -1)
      }
    }
    if last >= 0 {
      rendered.write_string(joint(last, i, word))
    }
    rendered.write_string(word.text)
    found[word.origin] = (pieces, rendered, i)
    match chosen.get(word.origin) {
      Some(words) => words.push(i)
      None => chosen[word.origin] = [i]
    }
    match places.get(word.piece) {
      Some((place, last)) => {
        pieces[place].write_string(joint(last, i, word))
        pieces[place].write_string(word.text)
        places[word.piece] = (place, i)
      }
      None => {
        places[word.piece] = (pieces.length(), i)
        let text = StringBuilder()
        text.write_string(word.text)
        pieces.push(text)
      }
    }
  }
  {
    document: self.title,
    comment,
    selected_text: self.selected_text(selection),
    pages,
    origins: order.map(id => {
      let (pieces, rendered, _) = found.get(id).unwrap()
      self.origin_entry(
        id,
        pieces.map(piece => piece.to_string()),
        rendered.to_string(),
        chosen.get(id).unwrap(),
      )
    }),
  }
}

///|
/// The entry of the origin `id` in a record: its selected text, and what
/// its source says for the selected words `words`.
fn ReviewText::origin_entry(
  self : ReviewText,
  id : Int,
  pieces : Array[String],
  rendered : String,
  words : Array[Int],
) -> FeedbackOrigin {
  let info = self.infos[id]
  let source_ranges = self.spans(id, words)
  let (excerpt, more) = self.excerpt(id, source_ranges)
  {
    origin: self.origins[id],
    pieces,
    rendered,
    tier: info.tier,
    why: info.why,
    source_ranges,
    excerpt,
    more,
  }
}

///|
/// The feedback record for something that is no text: a shape or an image
/// with the given origin (`CompileReport::origin_at`) on a page.
pub fn ReviewText::origin_feedback(
  self : ReviewText,
  origin : Origin,
  page : Int,
  comment : String,
) -> Feedback {
  let entry = match self.origin_number(origin) {
    Some(id) => self.origin_entry(id, [], "", [])
    // An origin that is not of this document's page layers.
    None =>
      {
        origin,
        pieces: [],
        rendered: "",
        tier: if origin.param is Some(_) {
          2
        } else {
          1
        },
        why: "the source of this location was not read",
        source_ranges: [],
        excerpt: [],
        more: 0,
      }
  }
  {
    document: self.title,
    comment,
    selected_text: "",
    pages: [page],
    origins: [entry],
  }
}

///|
/// The number of an origin in the table, by what the table tells apart.
/// `None` for an origin that is not of this document's page layers.
fn ReviewText::origin_number(self : ReviewText, origin : Origin) -> Int? {
  self.origins.search_by(o => {
    o.file == origin.file &&
    o.module_name == origin.module_name &&
    o.kind == origin.kind &&
    o.start_line == origin.start_line &&
    o.start_column == origin.start_column &&
    o.end_line == origin.end_line &&
    o.end_column == origin.end_column &&
    o.param == origin.param &&
    o.keys == origin.keys
  })
}

///|
/// The name of the record's format, in the JSON.
const FEEDBACK_FORMAT : String = "typst.mbt review feedback 2"

///|
/// The record as JSON:
///
/// ```json
/// { "format": "typst.mbt review feedback 2", "document": "..",
///   "comment": "..", "selected_text": "..", "pages": [1],
///   "origins": [ { "file": "..", "module": "..", "constructor": "Heading",
///     "parameter": 1, "keys": [".."], "start": [line, column],
///     "end": [line, column], "rendered_text": "..", "pieces": [".."],
///     "tier": 3, "why": "..",
///     "source_ranges": [ { "line": 12, "start": 14, "end": 22, "text": ".." } ],
///     "excerpt": [ { "line": 12, "text": ".." } ], "excerpt_more": 2 } ] }
/// ```
///
/// Lines and columns are one-based, columns count code points, the end is
/// exclusive. `parameter` is the one-based position of the argument among
/// the constructor's parameters and is left out if the location is the
/// call; `keys` is left out without a `Keyed` wrapper. `tier` is 3 if
/// `source_ranges` are the source characters of the selected text, 2 if
/// the location is the argument as a whole, 1 if it is the call; `why`
/// (left out for tier 3) says why it is not narrower. `excerpt_more` is
/// left out if the excerpt is complete.
pub fn Feedback::to_json(self : Feedback) -> Json {
  let int = (n : Int) => Json::number(n.to_double())
  let fields : Map[String, Json] = Map([])
  fields["format"] = Json::string(FEEDBACK_FORMAT)
  fields["document"] = Json::string(self.document)
  fields["comment"] = Json::string(self.comment)
  fields["selected_text"] = Json::string(self.selected_text)
  fields["pages"] = Json::array(self.pages.map(int))
  fields["origins"] = Json::array(
    self.origins.map(entry => {
      let origin = entry.origin
      let fields : Map[String, Json] = Map([])
      fields["file"] = Json::string(origin.file)
      fields["module"] = Json::string(origin.module_name)
      fields["constructor"] = Json::string(origin.kind)
      if origin.param is Some(param) {
        fields["parameter"] = int(param + 1)
      }
      if !origin.keys.is_empty() {
        fields["keys"] = Json::array(origin.keys.map(Json::string))
      }
      fields["start"] = Json::array([
        int(origin.start_line),
        int(origin.start_column),
      ])
      fields["end"] = Json::array([int(origin.end_line), int(origin.end_column)])
      fields["rendered_text"] = Json::string(entry.rendered)
      fields["pieces"] = Json::array(entry.pieces.map(Json::string))
      fields["tier"] = int(entry.tier)
      if entry.why != "" {
        fields["why"] = Json::string(entry.why)
      }
      fields["source_ranges"] = Json::array(
        entry.source_ranges.map(span => {
          let fields : Map[String, Json] = Map([])
          fields["line"] = int(span.line)
          fields["start"] = int(span.start)
          fields["end"] = int(span.end)
          fields["text"] = Json::string(span.text)
          Json::object(fields)
        }),
      )
      fields["excerpt"] = Json::array(
        entry.excerpt.map(line => {
          let fields : Map[String, Json] = Map([])
          fields["line"] = int(line.0)
          fields["text"] = Json::string(line.1)
          Json::object(fields)
        }),
      )
      if entry.more > 0 {
        fields["excerpt_more"] = int(entry.more)
      }
      Json::object(fields)
    }),
  )
  Json::object(fields)
}

///|
/// A text in quotes, shortened to 240 characters.
fn quoted(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  let mut count = 0
  for c in text {
    if count == 240 {
      out.write_char('…')
      break
    }
    count += 1
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      _ => out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// The record as a block of text to paste into a message for the author:
/// what it is, the comment, the selected text, and each source location
/// with what was rendered from it.
pub fn Feedback::to_text(self : Feedback) -> String {
  let out = StringBuilder()
  out.write_string(
    "Review comment on \{quoted(self.document)} (a document rendered from MoonBit source by typst.mbt)\n",
  )
  out.write_string(
    "Comment: \{if self.comment == "" { "(none)" } else { self.comment }}\n",
  )
  let pages = (if self.pages.length() == 1 { "page " } else { "pages " }) +
    self.pages.map(page => page.to_string()).join(", ")
  out.write_string(
    if self.selected_text == "" {
      "Selected: a shape or an image (\{pages})\n"
    } else {
      "Selected text: \{quoted(self.selected_text)} (\{pages})\n"
    },
  )
  for i, entry in self.origins {
    let origin = entry.origin
    out.write_string(
      "Source \{i + 1} of \{self.origins.length()}: \{origin.file}:\{origin.start_line}:\{origin.start_column}-\{origin.end_line}:\{origin.end_column}, \{origin.kind}(..)",
    )
    if origin.param is Some(param) {
      out.write_string(", parameter \{param + 1}")
    }
    if !origin.keys.is_empty() {
      out.write_string(", data key \{origin.keys.map(quoted).join(" / ")}")
    }
    out.write_char('\n')
    if entry.rendered != "" {
      out.write_string("  rendered: \{quoted(entry.rendered)}\n")
    }
    if entry.tier == 3 {
      out.write_string(
        "  source characters: \{entry.source_ranges.map(span => "\{span.line}:\{span.start}-\{span.line}:\{span.end}").join(", ")}\n",
      )
    } else {
      if entry.pieces.length() > 1 {
        out.write_string(
          "  \{entry.pieces.length()} pieces of this argument are selected; they share this location, which is the argument as a whole.\n",
        )
      }
      out.write_string("  note: \{entry.why}\n")
    }
    // The excerpt, with the source characters (or a location that is on
    // one line) marked under each line.
    for line in entry.excerpt {
      let number = line.0.to_string()
      out.write_string(
        "\{" ".repeat(if number.length() < 6 { 6 - number.length() } else { 0 })}\{number} | \{line.1}\n",
      )
      let marks = entry.marks(line.0)
      if !marks.is_empty() {
        // Under each marked column a `^`; before it what keeps the columns
        // aligned (a tab under a tab).
        out.write_string("       | ")
        let mut column = 1
        for c in line.1 {
          guard marks.last() is Some(last) && column < last.1 else { break }
          let marked = marks.iter().any(m => m.0 <= column && column < m.1)
          out.write_char(
            if marked {
              '^'
            } else if c == '\t' {
              '\t'
            } else {
              ' '
            },
          )
          column += 1
        }
        out.write_char('\n')
      }
    }
    if entry.more > 0 {
      out.write_string("       | … \{entry.more} more lines\n")
    }
  }
  out.write_string(
    "Locations are constructor calls and their arguments in the MoonBit source (line:column, columns in code points). Source characters are given only where the literal at a location is the text on the page.\n",
  )
  out.to_string()
}

///|
/// What is marked on a line of the excerpt: the source characters on the
/// line or, without source characters, a location that is on this one
/// line. As column ranges (`end` exclusive) in ascending order that do
/// not touch: a selection that goes over two copies of a text on the page
/// has runs that overlap in the source.
fn FeedbackOrigin::marks(
  self : FeedbackOrigin,
  line : Int,
) -> Array[(Int, Int)] {
  let ranges : Array[(Int, Int)] = []
  for span in self.source_ranges {
    if span.line == line && span.end > span.start {
      ranges.push((span.start, span.end))
    }
  }
  let origin = self.origin
  if self.source_ranges.is_empty() &&
    origin.start_line == line &&
    origin.end_line == line &&
    origin.end_column > origin.start_column {
    ranges.push((origin.start_column, origin.end_column))
  }
  ranges.sort_by((a, b) => a.0.compare(b.0))
  let out : Array[(Int, Int)] = []
  for range in ranges {
    match out.last() {
      Some(last) if range.0 <= last.1 =>
        out[out.length() - 1] = (
          last.0,
          if range.1 > last.1 {
            range.1
          } else {
            last.1
          },
        )
      _ => out.push(range)
    }
  }
  out
}
