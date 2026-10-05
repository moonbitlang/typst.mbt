// Prose (docs/edsl-design.md, section 4.4): running text written as one
// string, with inline descriptions interpolated into it.
//
//   (
//     $|Code blocks are highlighted with a port of \{Raw("syntect")}
//     $|and Typst's bundled syntaxes:
//   ) |> Prose
//
// The string is not markup: nothing in it is parsed but white space, the
// two quote characters and the placeholders that interpolated descriptions
// leave behind.

///|
/// The first and last character of a placeholder: Unicode noncharacters,
/// which no text contains. Between them stands the decimal number of the
/// interpolated description.
const PROSE_OPEN : Char = '\u{FDD0}'

///|
const PROSE_CLOSE : Char = '\u{FDD1}'

///|
/// The descriptions that were interpolated into a string and not yet taken
/// by a `Prose`, by number. An entry lives from the interpolation to the
/// `Prose` call that consumes it, which is normally the next call. Entries
/// of strings that never reach a `Prose` (a description printed for
/// debugging, say) stay, and name the description in the error if such a
/// string is lowered; when more than `prose_table_max` are pending, the
/// oldest is dropped.
let prose_table : Map[Int64, Content] = Map([])

///|
/// The number of the next interpolation. Numbers are never reused.
let prose_serial : @ref.Ref[Int64] = { val: 0L, }

///|
/// Every pending interpolation with a number below this one that is not in
/// the table may have been dropped (rather than consumed).
let prose_dropped_below : @ref.Ref[Int64] = { val: 0L, }

///|
/// The number of pending interpolations that are kept.
let prose_table_max : Int = 65536

///|
/// Write the placeholder of a description: what `\{description}` in a
/// string is. Every interpolation is an occurrence of its own.
fn prose_placeholder(content : Content, logger : &Logger) -> Unit {
  let id = prose_serial.val
  // Numbers have at most 18 digits (`prose_token`) and are never reused:
  // past that, nothing is registered and the written token is no
  // placeholder (`Prose` rejects it as a reserved character).
  if id >= 1000000000000000000L {
    logger.write_char(PROSE_OPEN)
    logger.write_char(PROSE_CLOSE)
    return
  }
  prose_serial.val = id + 1L
  if prose_table.length() >= prose_table_max {
    // Drop the oldest pending entry (the map keeps insertion order).
    for key, _ in prose_table {
      prose_table.remove(key)
      prose_dropped_below.val = key + 1L
      break
    }
  }
  prose_table[id] = content
  logger.write_char(PROSE_OPEN)
  logger.write_string(id.to_string())
  logger.write_char(PROSE_CLOSE)
}

///|
/// The placeholder whose number starts at `chars[start]` (after the opening
/// character): its number and the index after its closing character. Only
/// the canonical spelling is a placeholder: a decimal number without
/// leading zeros and of at most 18 digits (so it cannot overflow), then
/// the closing character.
fn prose_token(chars : Array[Char], start : Int) -> (Int64, Int)? {
  let mut id = 0L
  let mut j = start
  while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
    if j - start >= 18 {
      return Option::None
    }
    id = id * 10L + (chars[j].to_int() - '0'.to_int()).to_int64()
    j += 1
  }
  let digits = j - start
  if digits == 0 || (digits > 1 && chars[start] == '0') {
    return Option::None
  }
  if j < chars.length() && chars[j] == PROSE_CLOSE {
    Some((id, j + 1))
  } else {
    Option::None
  }
}

///|
/// The kind of a description, for messages.
fn Content::kind(self : Content) -> String {
  match self.node {
    NText(_, _) => "text"
    NCall(call) => call.origin.kind
    NSeq(_, site) => site.kind
    NSetRule(set) => set.origin.kind
    NShowRule(show) => show.origin.kind
    NLabelled(_, _, site, _) => site.kind
    NKeyed(_, body) => body.kind()
    NContext(_, site) => site.kind
    NEval(node) => node.origin.kind
    NSpace(_) => "Space"
    NEngine(_) => "a view"
    NValue(_) => "a value"
    NInvalid(_, site) => site.kind
  }
}

///|
/// If `text` contains a placeholder: a message for the error, naming the
/// description that was interpolated. Strings other than the argument of
/// `Prose` must not contain placeholders.
fn prose_leak(text : String) -> String? {
  // Most strings have no placeholder.
  guard text.contains_char(PROSE_OPEN) else { return Option::None }
  let chars = text.to_array()
  for i, c in chars {
    // The opening character alone is text (an unusual one).
    guard c == PROSE_OPEN && prose_token(chars, i + 1) is Some((id, _)) else {
      continue
    }
    // A number that was never given out is not an interpolation.
    guard id < prose_serial.val else { continue }
    let what = match prose_table.get(id) {
      Some(content) => "`\{content.kind()}`"
      Option::None => "a description"
    }
    return Some(
      "\{what} was interpolated into a string that is not the text of `Prose`",
    )
  }
  Option::None
}

///|
/// The hint of [prose_leak] errors.
let prose_leak_hint : String = "only `Prose(..)` takes strings with interpolated descriptions; elsewhere use `Seq([..])`"

///|
/// Running text: `text` with the descriptions interpolated into it
/// (`\{Emph("x")}`), as inline content.
///
/// - White space (spaces, tabs, line breaks) between words is one space,
///   as in Typst markup; a line break of the string is a space too. A blank
///   line is a paragraph break. White space at the start and the end is
///   dropped.
/// - `"` and `'` are smart quotes, which the engine resolves by language
///   and nesting (`quotes=false`: they are text).
/// - An interpolated description is the description; an interpolated
///   string or number is text like the rest. Interpolate `Lit(s)` to insert
///   a string verbatim (no quotes, white space kept).
/// - Everything else is literal text: no markup is parsed.
///
/// Twin: the content block with one `#"word"` per word, markup's white
/// space between them and `#smartquote(double: ..)` for the quotes:
/// `Prose("a \"b\" \{Emph("c")}")` is
/// `[#"a" #smartquote(double: true)#"b"#smartquote(double: true) #emph[#"c"]]`.
pub struct Prose {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Prose::Prose(
  text : String,
  quotes? : Bool = true,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Prose {
  let site = Site::new("Prose", loc, args_loc)
  let children : Array[Content] = []
  let word = StringBuilder()
  // The white space before the next piece: the number of line breaks in
  // it, or -1 if there is none.
  let mut gap = -1
  let mut problem : String? = Option::None
  let flush = () => {
    if !word.is_empty() {
      children.push(Content::of(NText(word.to_string(), Option::None)))
      word.reset()
    }
  }
  // The gap before a piece that is no text: a paragraph break or a space.
  let separate = () => {
    if gap >= 0 && !children.is_empty() {
      if gap >= 2 {
        children.push(
          Content::of(
            NCall({
              func: FElem(@library.parbreak_elem()),
              args: [],
              origin: site,
            }),
          ),
        )
      } else {
        children.push(Content::of(NSpace(gap == 1)))
      }
    }
    gap = -1
  }
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    i += 1
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      flush()
      if gap < 0 {
        gap = 0
      }
      // A line break is a line feed, a carriage return, or the two
      // together, as in markup.
      if c == '\n' {
        gap += 1
      } else if c == '\r' {
        gap += 1
        if i < chars.length() && chars[i] == '\n' {
          i += 1
        }
      }
      continue
    }
    if word.is_empty() {
      separate()
    }
    if c == PROSE_OPEN {
      flush()
      match prose_token(chars, i) {
        Some((id, after)) => {
          i = after
          match prose_table.get(id) {
            Some(content) => {
              prose_table.remove(id)
              match content.node {
                NSetRule(_) | NShowRule(_) =>
                  problem = Some(
                    "`\{content.kind()}` is a rule and cannot be interpolated into prose",
                  )
                _ => children.push(content)
              }
            }
            Option::None =>
              problem = Some(
                if id >= prose_serial.val {
                  // Not a number that an interpolation was given.
                  "the text of `Prose` contains a reserved character (U+FDD0)"
                } else if id < prose_dropped_below.val {
                  // Consumed, or dropped at the cap: the table cannot
                  // tell which.
                  "an interpolated description of this text was already used by another `Prose`, or dropped because more than \{prose_table_max} descriptions were interpolated since"
                } else {
                  "an interpolated description of this text was already used by another `Prose`"
                },
              )
          }
        }
        Option::None =>
          problem = Some(
            "the text of `Prose` contains a reserved character (U+FDD0)",
          )
      }
    } else if c == PROSE_CLOSE {
      if problem is Option::None {
        problem = Some(
          "the text of `Prose` contains a reserved character (U+FDD1)",
        )
      }
    } else if quotes && (c == '"' || c == '\'') {
      flush()
      children.push(
        Content::of(
          NCall({
            func: FElem(@library.smart_quote_elem()),
            args: [
              { name: Some("double"), value: Value::bool(c == '"'), param: 0, },
            ],
            origin: site,
          }),
        ),
      )
    } else {
      word.write_char(c)
    }
  }
  flush()
  {
    content: match problem {
      Some(message) => Content::of(NInvalid(message, site))
      Option::None => Content::of(NSeq(children, site))
    },
  }
}

///|
pub impl IntoContent for Prose with fn into_content(self) {
  self.content
}

// Interpolation: `\{description}` writes a placeholder (`Show`).

///|
pub impl @builtin.Show for Content with fn output(self, logger) {
  prose_placeholder(self, logger)
}

///|
pub impl @builtin.Show for Prose with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Seq with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Lit with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Labelled with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Keyed with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Space with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Symbol with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Quoted with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Markup with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Equation with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Call with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for Context with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for CounterStep with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for CounterUpdate with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
pub impl @builtin.Show for ContentView with fn output(self, logger) {
  prose_placeholder(self.into_content(), logger)
}
