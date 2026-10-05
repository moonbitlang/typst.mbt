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
/// `Prose` call that consumes it, which is normally the next call; entries
/// of strings that never reach `Prose` stay (they name the description in
/// the error if such a string is lowered), up to `prose_table_max` of them.
let prose_table : Map[Int, Content] = Map([])

///|
let prose_serial : @ref.Ref[Int] = { val: 0, }

///|
/// The number of unconsumed interpolations that are kept.
let prose_table_max : Int = 4096

///|
/// Write the placeholder of a description: what `\{description}` in a
/// string is. Every interpolation is an occurrence of its own.
fn prose_placeholder(content : Content, logger : &Logger) -> Unit {
  let id = prose_serial.val
  prose_serial.val = id + 1
  if prose_table.length() >= prose_table_max {
    // Forget the oldest entry that was never consumed.
    for key, _ in prose_table {
      prose_table.remove(key)
      break
    }
  }
  prose_table[id] = content
  logger.write_char(PROSE_OPEN)
  logger.write_string(id.to_string())
  logger.write_char(PROSE_CLOSE)
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
  let mut open = -1
  for i, c in text {
    if c == PROSE_OPEN {
      open = i
      break
    }
  }
  guard open >= 0 else { return Option::None }
  // The number after the opening character.
  let mut id = 0
  let mut digits = 0
  for c in text.view(start_offset=open + 1) {
    if c >= '0' && c <= '9' {
      id = id * 10 + (c.to_int() - '0'.to_int())
      digits += 1
    } else {
      break
    }
  }
  let what = match (digits > 0, prose_table.get(id)) {
    (true, Some(content)) => "`\{content.kind()}`"
    _ => "a description"
  }
  Some("\{what} was interpolated into a string that is not the text of `Prose`")
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
      if c == '\n' {
        gap += 1
      }
      continue
    }
    if word.is_empty() {
      separate()
    }
    if c == PROSE_OPEN {
      flush()
      let mut id = 0
      let mut digits = 0
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        id = id * 10 + (chars[i].to_int() - '0'.to_int())
        digits += 1
        i += 1
      }
      let closed = i < chars.length() && chars[i] == PROSE_CLOSE
      if closed {
        i += 1
      }
      match (digits > 0 && closed, prose_table.get(id)) {
        (true, Some(content)) => {
          prose_table.remove(id)
          match content.node {
            NSetRule(_) | NShowRule(_) =>
              problem = Some(
                "`\{content.kind()}` is a rule and cannot be interpolated into prose",
              )
            _ => children.push(content)
          }
        }
        (true, Option::None) =>
          problem = Some(
            "an interpolated description of this text was already used by another `Prose`",
          )
        _ =>
          problem = Some(
            "the text of `Prose` contains a reserved character (U+FDD0)",
          )
      }
    } else if c == PROSE_CLOSE {
      problem = Some(
        "the text of `Prose` contains a reserved character (U+FDD1)",
      )
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
