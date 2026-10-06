// Port of `biblatex/src/raw.rs`: low-level representation of a bibliography
// file.

///|
/// A literal representation of a bibliography entry field.
pub(all) enum RawChunk {
  /// A normal field value.
  Normal(String)
  /// A field with strings and abbreviations.
  Abbreviation(String)
} derive(Eq, Debug)

///|
/// The content of a field or abbreviation.
pub type Field = Array[Spanned[RawChunk]]

///|
/// A literal representation of a bibliography file, with abbreviations not
/// yet resolved.
pub(all) struct RawBibliography {
  /// TeX commands to be prepended to the document, only supported by BibTeX.
  mut preamble : String
  /// The collection of citation keys and bibliography entries.
  entries : Array[Spanned[RawEntry]]
  /// A map of reusable abbreviations, only supported by BibTeX.
  abbreviations : Array[Pair]
}

///|
/// A raw extracted entry, with abbreviations not yet resolved.
pub(all) struct RawEntry {
  /// The citation key.
  key : Spanned[String]
  /// Denotes the type of bibliographic item (e.g., `article`).
  kind : Spanned[String]
  /// Maps from field names to their values.
  fields : Array[Pair]
}

///|
/// The keys for fields and their values.
pub(all) struct Pair {
  /// The key.
  key : Spanned[String]
  /// The value.
  value : Spanned[Field]
}

///|
/// An error that might occur during initial parsing of the bibliography.
pub(all) struct ParseError {
  /// Where in the source the error occurred.
  span : Span
  /// What kind of error occurred.
  kind : ParseErrorKind
} derive(Eq, Debug)

///|
pub fn ParseError::new(span : Span, kind : ParseErrorKind) -> ParseError {
  { span, kind, }
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  logger.write_string("\{self.kind}: \{self.span.start}-\{self.span.end}")
}

///|
/// Error conditions that might occur during initial parsing of the
/// bibliography.
pub(all) enum ParseErrorKind {
  /// The file ended prematurely.
  UnexpectedEof
  /// An unexpected token was encountered.
  Unexpected(Token)
  /// A token was expected, but not found.
  Expected(Token)
  /// A field contained an abbreviation that was not defined.
  UnknownAbbreviation(String)
  /// A TeX command was malformed.
  MalformedCommand
  /// A duplicate citation key was found.
  DuplicateKey(String)
  /// A type error occurred while trying to resolve cross-references.
  ResolutionError(TypeErrorKind)
} derive(Eq, Debug)

///|
/// A token that can be encountered during parsing.
pub(all) enum Token {
  /// An identifier for a field key, citation type, abbreviation, or citation
  /// key.
  Identifier
  /// An opening brace: `{`.
  OpeningBrace
  /// A closing brace: `}`.
  ClosingBrace
  /// A comma: `,`.
  Comma
  /// A quotation mark: `"`.
  QuotationMark
  /// An equals sign: `=`.
  Equals
  /// A decimal point: `.`.
  DecimalPoint
} derive(Eq, Debug)

///|
pub impl Show for ParseErrorKind with fn output(self, logger) {
  match self {
    UnexpectedEof => logger.write_string("unexpected end of file")
    Expected(token) => logger.write_string("expected \{token}")
    Unexpected(token) => logger.write_string("unexpected \{token}")
    UnknownAbbreviation(s) =>
      logger.write_string("unknown abbreviation \{@unicode.rust_debug_str(s)}")
    MalformedCommand => logger.write_string("malformed command")
    DuplicateKey(s) =>
      logger.write_string("duplicate key \{@unicode.rust_debug_str(s)}")
    ResolutionError(e) =>
      logger.write_string(
        "type error occurred during crossref resolution: \{e}",
      )
  }
}

///|
pub impl Show for Token with fn output(self, logger) {
  logger.write_string(
    match self {
      Identifier => "identifier"
      OpeningBrace => "opening brace"
      ClosingBrace => "closing brace"
      Comma => "comma"
      QuotationMark => "double quote"
      Equals => "equals"
      DecimalPoint => "decimal point"
    },
  )
}

///|
/// Parse a raw bibliography from a source string.
pub fn RawBibliography::parse(
  src : String,
) -> Result[RawBibliography, ParseError] {
  let p = BiblatexParser::new(src)
  p.parse()
}

///|
/// Backing struct for parsing a Bib(La)TeX file into a [`RawBibliography`].
priv struct BiblatexParser {
  s : @unscanny.Scanner
  res : RawBibliography
}

///|
priv suberror PErr {
  PErr(ParseError)
}

///|
fn BiblatexParser::new(src : String) -> BiblatexParser {
  {
    s: @unscanny.Scanner::new(src),
    res: { preamble: "", entries: [], abbreviations: [], },
  }
}

///|
fn BiblatexParser::parse(
  self : BiblatexParser,
) -> Result[RawBibliography, ParseError] {
  try {
    while !self.s.done() {
      self.s.eat_whitespace() |> ignore
      match self.s.peek() {
        Some('@') => self.entry()
        // Handle comments outside of entry
        Some('%') => self.comment()
        Some(_) => self.s.eat() |> ignore
        None => break
      }
    }
    Ok(self.res)
  } catch {
    PErr(e) => Err(e)
  }
}

///|
fn BiblatexParser::err(self : BiblatexParser, kind : ParseErrorKind) -> PErr {
  PErr(ParseError::{ span: self.here(), kind, })
}

///|
/// Eat a comma.
fn BiblatexParser::comma(self : BiblatexParser) -> Unit raise PErr {
  if !self.s.eat_if(',') {
    raise self.err(Expected(Comma))
  }
}

///|
/// Eat a delimiter.
fn BiblatexParser::brace(self : BiblatexParser, open : Bool) -> Unit raise PErr {
  let (brace, token) = if open {
    ('{', Token::OpeningBrace)
  } else {
    ('}', Token::ClosingBrace)
  }
  let peeked = self.s.peek()
  if peeked == Some(brace) || peeked == Some('"') {
    self.s.eat() |> ignore
  } else {
    raise self.err(Expected(token))
  }
}

///|
/// Eat a quote.
fn BiblatexParser::quote(self : BiblatexParser) -> Unit raise PErr {
  if !self.s.eat_if('"') {
    raise self.err(Expected(QuotationMark))
  }
}

///|
/// Eat an equals sign.
fn BiblatexParser::equals(self : BiblatexParser) -> Unit raise PErr {
  if !self.s.eat_if('=') {
    raise self.err(Expected(Equals))
  }
}

///|
/// Eat a string.
fn BiblatexParser::string(self : BiblatexParser) -> Spanned[String] raise PErr {
  self.quote()
  let idx = self.s.cursor()
  while self.s.peek() is Some(c) {
    match c {
      '"' => {
        let res = self.s.from(idx)
        let span = { start: idx, end: self.s.cursor(), }
        self.quote()
        return Spanned::new(res, span)
      }
      '\\' => {
        self.s.eat() |> ignore
        self.s.eat() |> ignore
      }
      _ => self.s.eat() |> ignore
    }
  }
  raise self.err(UnexpectedEof)
}

///|
/// Eat a number.
fn BiblatexParser::number(self : BiblatexParser) -> String raise PErr {
  let idx = self.s.cursor()
  let mut has_dot = false
  while self.s.peek() is Some(c) {
    let start = self.s.cursor()
    match c {
      '0'..='9' => self.s.eat() |> ignore
      '.' =>
        if !has_dot {
          self.s.eat() |> ignore
          has_dot = true
        } else {
          raise PErr(ParseError::{
            span: { start, end: self.s.cursor(), },
            kind: Unexpected(DecimalPoint),
          })
        }
      _ => return self.s.from(idx)
    }
  }
  raise self.err(UnexpectedEof)
}

///|
/// Eat a braced value.
fn BiblatexParser::braced(
  self : BiblatexParser,
) -> Spanned[RawChunk] raise PErr {
  self.brace(true)
  let idx = self.s.cursor()
  let mut braces = 0
  while self.s.peek() is Some(c) {
    match c {
      '{' => {
        self.brace(true)
        braces += 1
      }
      '}' => {
        let res = self.s.from(idx)
        let span = { start: idx, end: self.s.cursor(), }
        self.brace(false)
        if braces == 0 {
          return Spanned::new(RawChunk::Normal(res), span)
        }
        braces -= 1
      }
      '\\' => {
        self.s.eat() |> ignore
        self.s.eat() |> ignore
      }
      _ => self.s.eat() |> ignore
    }
  }
  raise self.err(UnexpectedEof)
}

///|
/// Eat an element of an abbreviation.
fn BiblatexParser::abbr_element(
  self : BiblatexParser,
) -> Spanned[RawChunk] raise PErr {
  let start = self.s.cursor()
  let res : RawChunk = match self.s.peek() {
    Some(c) if c.is_ascii_digit() => Normal(self.number())
    Some(c) if is_id_start(c) => Abbreviation(self.ident().v)
    _ => return self.single_field()
  }
  Spanned::new(res, { start, end: self.s.cursor(), })
}

///|
/// Eat an abbreviation field.
fn BiblatexParser::abbr_field(
  self : BiblatexParser,
) -> Spanned[Field] raise PErr {
  let start = self.s.cursor()
  let elems = []
  while true {
    elems.push(self.abbr_element())
    self.s.eat_whitespace() |> ignore
    if !self.s.eat_if('#') {
      break
    }
    self.s.eat_whitespace() |> ignore
  }
  Spanned::new(elems, { start, end: self.s.cursor(), })
}

///|
/// Eat a field.
fn BiblatexParser::field(
  self : BiblatexParser,
) -> (Spanned[String], Spanned[Field]) raise PErr {
  let key = self.ident()
  self.s.eat_whitespace() |> ignore
  self.equals()
  self.s.eat_whitespace() |> ignore
  let value = self.abbr_field()

  // Handle inline comments before closing brace at end of entry:
  //     @article{foo,
  //         title={bar},
  //         year={2025}  % A comment
  //     }
  self.s.eat_whitespace() |> ignore
  self.comment()
  (key, value)
}

///|
fn BiblatexParser::single_field(
  self : BiblatexParser,
) -> Spanned[RawChunk] raise PErr {
  match self.s.peek() {
    Some('{') => self.braced()
    Some('"') => {
      let s = self.string()
      Spanned::new(RawChunk::Normal(s.v), s.span)
    }
    _ => raise self.err(UnexpectedEof)
  }
}

///|
/// Eat fields.
fn BiblatexParser::fields(self : BiblatexParser) -> Array[Pair] raise PErr {
  let fields = []
  while !self.s.done() {
    self.s.eat_whitespace() |> ignore
    if self.s.peek() == Some('}') {
      return fields
    }
    let (key, value) = self.field()
    self.s.eat_whitespace() |> ignore
    fields.push({ key, value, })
    match self.s.peek() {
      Some(',') => {
        self.comma()

        // Handle inline comments after comma at end of field
        //     @article{foo,
        //         title={bar},  % A comment
        //         year={2025}
        //     }
        self.s.eat_whitespace() |> ignore
        self.comment()
      }
      Some('}') => return fields
      _ => raise self.err(Expected(Comma))
    }
  }
  raise self.err(UnexpectedEof)
}

///|
/// Eat an entry key.
fn BiblatexParser::key(self : BiblatexParser) -> Spanned[String] {
  let idx = self.s.cursor()
  self.s.eat_while(is_key) |> ignore
  Spanned::new(self.s.from(idx), { start: idx, end: self.s.cursor(), })
}

///|
/// Eat an identifier.
fn BiblatexParser::ident(self : BiblatexParser) -> Spanned[String] raise PErr {
  let idx = self.s.cursor()
  let is_start = match self.s.peek() {
    Some(c) => is_id_start(c)
    None => false
  }
  if is_start {
    self.s.eat() |> ignore
    self.s.eat_while(is_id_continue) |> ignore
    Spanned::new(self.s.from(idx), { start: idx, end: self.s.cursor(), })
  } else {
    raise self.err(Expected(Identifier))
  }
}

///|
/// Eat an entry.
fn BiblatexParser::entry(self : BiblatexParser) -> Unit raise PErr {
  let start = self.s.cursor()
  if self.s.eat() != Some('@') {
    abort("must not call entry when not at an '@'")
  }
  let entry_type = self.ident()
  self.s.eat_whitespace() |> ignore
  self.brace(true)
  self.s.eat_whitespace() |> ignore
  match @unscanny.to_ascii_lowercase(entry_type.v) {
    "string" => self.strings()
    "preamble" => self.preamble()
    "comment" => self.s.eat_until_char('}') |> ignore
    _ => self.body(entry_type, start)
  }
  self.s.eat_whitespace() |> ignore
  self.brace(false)
}

///|
/// Eat the body of a strings entry.
fn BiblatexParser::strings(self : BiblatexParser) -> Unit raise PErr {
  let fields = self.fields()
  self.res.abbreviations.append(fields)
}

///|
/// Eat the body of a preamble entry.
fn BiblatexParser::preamble(self : BiblatexParser) -> Unit raise PErr {
  let idx = self.s.cursor()
  self.string() |> ignore
  let string = self.s.from(idx)
  if !self.res.preamble.is_empty() {
    self.res.preamble = self.res.preamble + " # "
  }
  self.res.preamble = self.res.preamble + string
}

///|
/// Eat the body of an entry.
fn BiblatexParser::body(
  self : BiblatexParser,
  kind : Spanned[String],
  start : Int,
) -> Unit raise PErr {
  let key = self.key()
  self.s.eat_whitespace() |> ignore
  self.comma()

  // Handle inline comments after entry key
  //     @article{foo,  % A comment
  //         title={bar},
  //         year={2025}
  //     }
  self.s.eat_whitespace() |> ignore
  self.comment()
  self.s.eat_whitespace() |> ignore
  let fields = self.fields()
  self.res.entries.push(
    Spanned::new({ key, kind, fields, }, { start, end: self.s.cursor(), }),
  )
}

///|
/// Eat an inline comment.
// Cannot fail; keeps upstream's `Result<(), ParseError>`
// (biblatex 0.12.0 src/raw.rs:526).
#warnings("-unused_error_type")
fn BiblatexParser::comment(self : BiblatexParser) -> Unit raise PErr {
  if self.s.eat_if('%') {
    self.s.eat_until_char('\n') |> ignore
  }
}

///|
fn BiblatexParser::here(self : BiblatexParser) -> Span {
  { start: self.s.cursor(), end: self.s.cursor(), }
}

///|
/// Whether a character is allowed in an entry key
pub fn is_key(c : Char) -> Bool {
  !(c is (',' | '}')) && !@unscanny.is_control(c) && !@unscanny.is_whitespace(c)
}

///|
/// Whether a character can start an identifier.
pub fn is_id_start(c : Char) -> Bool {
  !(c is (':' | '<' | '-' | '>')) && is_id_continue(c)
}

///|
/// Whether a character can continue an identifier.
pub fn is_id_continue(c : Char) -> Bool {
  !(c
  is ('@'
  | '{'
  | '}'
  | '"'
  | '#'
  | '\''
  | '('
  | ')'
  | ','
  | '='
  | '%'
  | '\\'
  | '~')) &&
  !@unscanny.is_control(c) &&
  !@unscanny.is_whitespace(c)
}
