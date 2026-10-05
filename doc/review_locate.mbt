// Source characters (docs/edsl-review.md, slice 3): for each origin, how
// far its location can be narrowed (the tier), and for each word of text
// whose argument is a literal that is the text on the page, the source
// characters that spell the word.

///|
/// A run of source characters on one line: columns `start..end` (one
/// based, in code points, `end` exclusive). `from..to` are the numbers of
/// its characters in the literal (`LitChar::at`): two runs with `to` of
/// the first equal to `from` of the second are on one line with only
/// white space between them.
priv struct Seg {
  line : Int
  start : Int
  end : Int
  from : Int
  to : Int
}

///|
/// What is known of an origin's source.
priv struct SourceInfo {
  /// 3: the argument is a literal that is the text on the page, so words
  /// have source characters. 2: the argument, as a whole. 1: the call.
  tier : Int
  /// Why the location is not narrower (empty for tier 3).
  why : String
  /// The file's number among the files that were read (`-1`: none).
  file : Int
}

///|
/// The lines of the source files that were read, by file.
priv struct SourceFiles {
  provider : ((String, String) -> String?)?
  index : Map[String, Int]
  lines : Array[Array[Array[Char]]]
}

///|
/// The number of an origin's file, read on first use (`-1`: there is no
/// provider, or it does not have the file).
fn SourceFiles::file(self : SourceFiles, origin : Origin) -> Int {
  guard self.provider is Some(provider) else { return -1 }
  let key = "\{origin.file}\u{0}\{origin.module_name}"
  if self.index.get(key) is Some(number) {
    return number
  }
  let number = match provider(origin.file, origin.module_name) {
    Some(text) => {
      self.lines.push(
        text
        .split("\n")
        .map(line => {
          let chars = line.to_owned().to_array()
          if chars.last() is Some('\r') {
            chars.pop() |> ignore
          }
          chars
        })
        .collect(),
      )
      self.lines.length() - 1
    }
    None => -1
  }
  self.index[key] = number
  number
}

///|
/// Characters that are compared as equal: a quotation mark of the source
/// and the typographic one that `Prose` and `Quoted` set for it.
fn same_char(c : Char) -> Char {
  match c {
    '“' | '”' | '„' | '‟' | '«' | '»' => '"'
    '‘' | '’' | '‚' | '‛' | '‹' | '›' => '\''
    _ => c
  }
}

///|
/// Whether a character counts when text is compared: white space does not
/// (the page breaks lines and `Prose` reflows), nor does a soft hyphen or
/// a directional formatting character.
fn counts(c : Char) -> Bool {
  let n = c.to_int()
  !is_blank(c) &&
  c != '\u{ad}' &&
  // (The characters that embed and isolate text of another direction:
  // the engine adds them around such text.)
  !(n >= 0x202A && n <= 0x202E) &&
  !(n >= 0x2066 && n <= 0x2069)
}

///|
/// The source characters of the words of one origin whose argument is the
/// literal `literal`: for each word (in `words`, numbers of
/// `self.words`), its runs. `None` unless **all the text that the origin
/// has on the page is the literal's text**, one or more times over,
/// character by character (white space aside): then the position of a
/// character on the page is its position in the literal.
fn ReviewText::match_literal(
  self : ReviewText,
  words : Array[Int],
  literal : Array[LitChar],
) -> Array[Array[Seg]]? {
  let literal = literal.filter(c => counts(c.c))
  let count = literal.length()
  guard count > 0 else { return None }
  let out : Array[Array[Seg]] = []
  let mut at = 0
  for number in words {
    let segs : Array[Seg] = []
    for c in self.words[number].text {
      guard counts(c) else { continue }
      let source = literal[at % count]
      guard same_char(c) == same_char(source.c) else { return None }
      at += 1
      match segs.last() {
        Some(last) if last.to == source.at =>
          segs[segs.length() - 1] = {
            ..last,
            end: source.end,
            to: source.at + 1,
          }
        _ =>
          segs.push({
            line: source.line,
            start: source.col,
            end: source.end,
            from: source.at,
            to: source.at + 1,
          })
      }
    }
    out.push(segs)
  }
  // Every copy of the literal is complete.
  guard at > 0 && at % count == 0 else { return None }
  Some(out)
}

///|
/// Read the sources of the origins: the tier of each origin, and the
/// source characters of the words that have them (`self.infos`,
/// `self.segs`). `provider` gives the text of a source file (by the file
/// and the module of an origin), or `None`.
fn ReviewText::locate(
  self : ReviewText,
  provider : ((String, String) -> String?)?,
) -> Unit {
  let files : SourceFiles = { provider, index: Map([]), lines: self.lines, }
  // The words of each origin, in reading order.
  let words : Array[Array[Int]] = self.origins.map(_ => [])
  for number, word in self.words {
    words[word.origin].push(number)
    self.segs.push([])
  }
  for id, origin in self.origins {
    let file = files.file(origin)
    let info = (tier : Int, why : String) => { tier, why, file, }
    guard origin.param is Some(_) else {
      self.infos.push(
        info(
          1, "the location is the constructor call: what was selected is not the text of one of its arguments",
        ),
      )
      continue
    }
    guard file >= 0 else {
      self.infos.push(
        info(
          2, "the location is the argument as a whole: its source file was not read when this was made",
        ),
      )
      continue
    }
    guard source_cells(self.lines[file], origin) is Some(cells) else {
      self.infos.push(
        info(
          2, "the location is the argument as a whole: the source file that was read does not have this location (it is not the file that the document was compiled from)",
        ),
      )
      continue
    }
    self.infos.push(
      match arg_shape(cells) {
        Binding(name) =>
          info(
            2,
            "the argument is the variable `\{name}`: the text comes from a binding, not from a literal at this location",
          )
        Expression =>
          info(
            2, "the argument is an expression, not a literal: the text is computed, not written at this location",
          )
        Literal(literal, holes~) =>
          match self.match_literal(words[id], literal) {
            Some(segs) => {
              for k, number in words[id] {
                self.segs[number] = segs[k]
              }
              info(3, "")
            }
            None =>
              info(
                2,
                if words[id].is_empty() {
                  "the location is the argument as a whole: what was selected is not text"
                } else if holes {
                  "the location is the argument as a whole: its literal is not all of the text on the page (an interpolation or a computed element adds text, or the text was changed, is drawn in another order, or is not all shown)"
                } else {
                  "the location is the argument as a whole: its literal is not the text on the page as it is written (the text was changed on the way, is drawn in another order, or is not all shown)"
                },
              )
          }
      },
    )
  }
}

///|
/// A run of source characters of a feedback record.
pub struct SourceSpan {
  /// The line, from 1.
  line : Int
  /// The columns, from 1, in code points; `end` is exclusive.
  start : Int
  end : Int
  /// The source text of the run (as written: with its escapes).
  text : String
}

///|
/// The source characters of the words `words` (numbers in reading order,
/// of one origin): the runs of the words, joined where one goes on where
/// the one before it ended.
fn ReviewText::spans(
  self : ReviewText,
  origin : Int,
  words : Array[Int],
) -> Array[SourceSpan] {
  let file = self.infos[origin].file
  guard file >= 0 else { return [] }
  let runs : Array[Seg] = []
  for number in words {
    for seg in self.segs[number] {
      match runs.last() {
        Some(last) if last.to == seg.from =>
          runs[runs.length() - 1] = { ..last, end: seg.end, to: seg.to, }
        _ => runs.push(seg)
      }
    }
  }
  runs.map(run => {
    let line = self.lines[file][run.line - 1]
    {
      line: run.line,
      start: run.start,
      end: run.end,
      text: String::from_array(line[run.start - 1:run.end - 1].to_owned()),
    }
  })
}

///|
/// The most lines that an excerpt shows.
const EXCERPT_LINES : Int = 6

///|
/// The excerpt of an origin's source for a feedback record: the lines of
/// the source characters, or without those the lines of the location, at
/// most `EXCERPT_LINES` of them; and how many lines were left out.
fn ReviewText::excerpt(
  self : ReviewText,
  origin : Int,
  spans : Array[SourceSpan],
) -> (Array[(Int, String)], Int) {
  let file = self.infos[origin].file
  guard file >= 0 else { return ([], 0) }
  // The lines, each once, in the order of first use, as far as the file
  // has them.
  let count = self.lines[file].length()
  let lines : Array[Int] = []
  if spans.is_empty() {
    let o = self.origins[origin]
    for line in o.start_line..<(o.end_line + 1) {
      if line >= 1 && line <= count {
        lines.push(line)
      }
    }
  } else {
    let seen : Map[Int, Unit] = Map([])
    for span in spans {
      if !seen.contains(span.line) {
        seen[span.line] = ()
        lines.push(span.line)
      }
    }
  }
  let shown : Array[(Int, String)] = []
  for line in lines {
    guard shown.length() < EXCERPT_LINES else { break }
    shown.push((line, String::from_array(self.lines[file][line - 1])))
  }
  (shown, lines.length() - shown.length())
}
