// Port of `biblatex/src/resolve.rs`: resolving abbreviations and LaTeX
// commands.

///|
/// Fully parse a field, resolving abbreviations and LaTeX commands.
pub fn parse_field(
  key : String,
  field : Field,
  abbreviations : Map[String, Field],
) -> Result[Chunks, ParseError] {
  let chunks = []
  for e in field {
    match e.v {
      Abbreviation(s) =>
        match resolve_abbreviation(key, s, e.span, abbreviations) {
          Ok(c) => chunks.append(c)
          Err(err) => return Err(err)
        }
      Normal(s) =>
        match ContentParser::new(key, s, e.span.start).parse() {
          Ok(c) => chunks.append(c)
          Err(err) => return Err(err)
        }
    }
  }
  flatten(chunks)
  Ok(chunks)
}

///|
priv struct ContentParser {
  s : @unscanny.Scanner
  verb_field : Bool
  mut current_chunk : Chunk
  result : Chunks
  mut start : Int
  offset : Int
}

///|
fn ContentParser::new(
  key : String,
  field : String,
  offset : Int,
) -> ContentParser {
  {
    s: @unscanny.Scanner::new(field),
    verb_field: is_verbatim_field(key),
    current_chunk: default_chunk(0),
    result: [],
    start: 0,
    offset,
  }
}

///|
fn ContentParser::parse(self : ContentParser) -> Result[Chunks, ParseError] {
  let offset = self.offset
  match self.parse_impl() {
    Err(e) =>
      Err({
        ..e,
        span: { start: e.span.start + offset, end: e.span.end + offset, },
      })
    Ok(chunks) => {
      for chunk in chunks {
        chunk.span = {
          start: chunk.span.start + offset,
          end: chunk.span.end + offset,
        }
      }
      Ok(chunks)
    }
  }
}

///|
fn ContentParser::push_str(self : ContentParser, s : String) -> Unit {
  self.current_chunk = self.current_chunk.with_str(self.current_chunk.get() + s)
}

///|
fn ContentParser::push_char(self : ContentParser, c : Char) -> Unit {
  self.push_str(c.to_string())
}

///|
fn ContentParser::parse_impl(
  self : ContentParser,
) -> Result[Chunks, ParseError] {
  let mut depth = 0
  self.current_chunk = default_chunk(depth)
  while self.s.peek() is Some(c) {
    match c {
      '\\' =>
        match self.backslash() {
          Ok(sequence) => self.push_str(sequence)
          Err(e) => return Err(e)
        }
      '$' if !self.verb_field => {
        self.turnaround(depth)
        match self.math() {
          Ok(math) => self.result.push(math)
          Err(e) => return Err(e)
        }
      }
      '{' => {
        depth += 1
        self.turnaround(depth)
        self.s.eat() |> ignore
        self.start += 1
      }
      '}' => {
        if depth == 0 {
          let idx = self.s.cursor()
          self.s.eat() |> ignore
          return Err({
            span: { start: idx, end: self.s.cursor(), },
            kind: Unexpected(ClosingBrace),
          })
        }
        depth -= 1
        self.turnaround(depth)
        self.start += 1
        self.s.eat() |> ignore
      }
      '-' => {
        let mut count = 0
        let hyphens = self.s.eat_while(c => {
          let res = c == '-' && count < 3
          if res {
            count += 1
          }
          res
        })
        match count {
          1 => self.push_char('-')
          2 => self.push_char('–')
          3 => self.push_char('—')
          _ => self.push_str(hyphens)
        }
      }
      _ if @unscanny.is_whitespace(c) => {
        self.push_char(' ')
        self.s.eat_whitespace() |> ignore
      }
      _ => self.push_char(self.s.eat().unwrap())
    }
  }
  if !self.current_chunk.get().is_empty() || self.result.is_empty() {
    self.turnaround(depth)
  }
  Ok(self.result)
}

///|
fn ContentParser::turnaround(self : ContentParser, depth : Int) -> Unit {
  let chunk = self.current_chunk
  self.current_chunk = default_chunk(depth)
  self.result.push(
    Spanned::new(chunk, { start: self.start, end: self.s.cursor(), }),
  )
  self.start = self.s.cursor()
}

///|
fn ContentParser::backslash(self : ContentParser) -> Result[String, ParseError] {
  self.eat_assert('\\')
  match self.s.peek() {
    Some(c) if c != '^' && c != '~' && is_escapable(c, self.verb_field, true) => {
      self.s.eat() |> ignore
      Ok(c.to_string())
    }
    _ if self.verb_field => Ok("\\")
    Some(c) if !@unscanny.is_whitespace(c) && !@unscanny.is_control(c) =>
      self.command()
    Some(c) => Ok("\\" + c.to_string())
    None => Err({ span: self.here(), kind: UnexpectedEof, })
  }
}

///|
fn ContentParser::command(self : ContentParser) -> Result[String, ParseError] {
  let pos = self.s.cursor()
  let valid_start = match self.s.peek() {
    Some(c) => !@unscanny.is_whitespace(c) && !@unscanny.is_control(c)
    None => false
  }
  if !valid_start {
    return Err({
      span: { start: pos, end: self.s.cursor(), },
      kind: MalformedCommand,
    })
  }
  if !is_single_char_func(self.s.eat().unwrap(), false) {
    self.s.eat_while(is_id_continue) |> ignore
  }
  let command = self.s.from(pos)
  let ws = !self.s.eat_whitespace().is_empty()
  let first_char = @unscanny.first_char(command).unwrap()
  let arg : String? = if self.s.peek() != Some('{') &&
    @unscanny.char_count(command) == 1 &&
    first_char != '-' &&
    is_single_char_func(first_char, ws) {
    let idx = self.s.cursor()
    self.s.eat() |> ignore
    Some(self.s.from(idx))
  } else if !ws && self.s.eat_if('{') {
    let mut depth = 1
    let idx = self.s.cursor()
    while true {
      self.s.eat_until_any(['{', '}']) |> ignore
      match self.s.eat() {
        Some('{') => depth += 1
        Some('}') => {
          depth -= 1
          if depth == 0 {
            break
          }
        }
        Some(_) => abort("unreachable")
        None => return Err({ span: self.here(), kind: UnexpectedEof, })
      }
    }
    let arg = self.s.from(idx)
    // Strip the closing brace.
    let arg = arg[:arg.length() - 1].to_owned()
    match ContentParser::new("", arg, idx).parse() {
      Ok(chunks) => Some(format_verbatim(chunks))
      Err(e) => return Err(e)
    }
  } else {
    None
  }
  Ok(execute_command(command, arg))
}

///|
fn ContentParser::math(
  self : ContentParser,
) -> Result[Spanned[Chunk], ParseError] {
  self.eat_assert('$')
  let idx = self.s.cursor()
  let res = self.s.eat_until_char('$')
  let span = { start: idx, end: self.s.cursor(), }
  if self.s.done() {
    return Err({ span: self.here(), kind: UnexpectedEof, })
  }
  self.s.eat() |> ignore
  self.start = self.s.cursor()
  Ok(Spanned::new(Chunk::Math(res), span))
}

///|
fn ContentParser::eat_assert(self : ContentParser, c : Char) -> Unit {
  if self.s.eat() != Some(c) {
    abort("assertion failed: expected '\{c}'")
  }
}

///|
fn ContentParser::here(self : ContentParser) -> Span {
  { start: self.s.cursor(), end: self.s.cursor(), }
}

///|
fn default_chunk(depth : Int) -> Chunk {
  if depth > 0 {
    Verbatim("")
  } else {
    Normal("")
  }
}

///|
/// Resolves `Chunk::Abbreviation` items to their respective string values.
fn resolve_abbreviation(
  key : String,
  abbr : String,
  span : Span,
  map : Map[String, Field],
) -> Result[Chunks, ParseError] {
  match map.get(abbr) {
    Some(fields) => parse_field(key, fields, map)
    None =>
      match get_month_for_abbr(abbr) {
        Some(month) => Ok([Spanned::new(Chunk::Normal(month.0), span)])
        None => Err({ span, kind: UnknownAbbreviation(abbr), })
      }
  }
}

///|
fn last_char_combine(v : String?, combine : Char) -> String {
  match v {
    Some(v) =>
      if v.is_empty() {
        match combine {
          '\u{302}' => "^"
          '\u{303}' => "~"
          _ => combine.to_string()
        }
      } else {
        let cs = @unscanny.chars(v)
        let last = cs.pop().unwrap()
        // Account for legacy TeX behavior of requiring an uncapped i or
        // j to add another diacritic.
        let last = match last {
          'ı' => 'i'
          'ȷ' => 'j'
          c => c
        }
        let combined = @unscanny.compose(last, combine)
        let res = StringBuilder()
        for c in cs {
          res.write_char(c)
        }
        res.write_char(combined.unwrap_or(last))
        if combined is None {
          res.write_char(combine)
        }
        res.to_string()
      }
    None => combine.to_string()
  }
}

///|
/// Best-effort evaluation of LaTeX commands with a focus on diacritics.
/// Will dump the command arguments if evaluation is not possible.
/// Nested commands are not supported.
fn execute_command(command : String, arg : String?) -> String {
  match command {
    "LaTeX" => "LaTeX"
    "TeX" => "TeX"
    "textendash" => "–"
    "textemdash" => "—"
    "textquotesingle" => "'"
    "textquotedblleft" => "“"
    "textquotedblright" => "”"
    "textquoteleft" => "‘"
    "textquoteright" => "’"
    "textquotestraightdblbase" | "quotedblbase" => "„"
    "textquotestraightbase" | "quotesinglbase" => "‚"
    "textquotedbl" => "\""
    "textasciicircum" => "^"
    "textasciigrave" => "`"
    "textasciitilde" => "~"
    "textasteriskcentered" => "⁎"
    "textbackslash" => "\\"
    "textbar" => "|"
    "textbraceleft" => "{"
    "textbraceright" => "}"
    "textbullet" => "•"
    "textdagger" => "†"
    "textdaggerdbl" => "‡"
    "textdollar" => "$"
    "textless" => "<"
    "textgreater" => ">"
    "textexclamdown" => "¡"
    "textquestiondown" => "¿"
    "textordfeminine" => "ª"
    "textordmasculine" => "º"
    "textperiodcentered" => "·"
    "textregistered" => "®"
    "texttrademark" => "™"
    "textsection" => "§"
    "textunderscore" => "_"
    "textvisiblespace" => "␣"
    "guillemotleft" => "«"
    "guillemotright" => "»"
    "guilsinglleft" => "‹"
    "guilsinglright" => "›"
    "aa" => "å"
    "AA" => "Å"
    "ae" => "æ"
    "AE" => "Æ"
    "dh" => "ð"
    "DH" => "Ð"
    "dj" => "đ"
    "DJ" => "Đ"
    "ng" => "ŋ"
    "NG" => "Ŋ"
    "l" => "ł"
    "L" => "Ł"
    "i" => "ı"
    "oe" => "œ"
    "OE" => "Œ"
    "o" if arg is None => "ø"
    "O" => "Ø"
    "ss" => "ß"
    "SS" => "ẞ"
    "th" => "þ"
    "TH" => "Þ"
    "P" | "textparagraph" => "¶"
    "S" => "§"
    "copyright" =>
      match arg {
        Some(arg) => "©" + arg
        None => "©"
      }
    "ddag" => "‡"
    "dots" | "textellipsis" => "…"
    "pounds" => "£"
    "`" => last_char_combine(arg, '\u{300}')
    "´" => last_char_combine(arg, '\u{301}')
    "'" => last_char_combine(arg, '\u{301}')
    "^" => last_char_combine(arg, '\u{302}')
    "~" => last_char_combine(arg, '\u{303}')
    "=" => last_char_combine(arg, '\u{304}')
    "u" => last_char_combine(arg, '\u{306}')
    "." => last_char_combine(arg, '\u{307}')
    "\"" => last_char_combine(arg, '\u{308}')
    "r" => last_char_combine(arg, '\u{30A}')
    "H" => last_char_combine(arg, '\u{30B}')
    "v" => last_char_combine(arg, '\u{30C}')
    "d" => last_char_combine(arg, '\u{323}')
    "c" => last_char_combine(arg, '\u{327}')
    "k" => last_char_combine(arg, '\u{328}')
    "b" => last_char_combine(arg, '\u{332}')
    "o" => last_char_combine(arg, '\u{338}')
    "-" => ""
    _ =>
      match arg {
        Some(arg) => "\\\{command}{\{arg}}"
        None => "\\\{command} "
      }
  }
}

///|
/// Simplifies a chunk vector by collapsing neighboring Normal or Verbatim
/// chunks.
fn flatten(chunks : Chunks) -> Unit {
  let mut i = 1
  while i < chunks.length() {
    let merge = match (chunks[i - 1].v, chunks[i].v) {
      (Normal(_), Normal(_)) | (Verbatim(_), Verbatim(_)) => true
      _ => false
    }
    if merge {
      let redundant = chunks[i]
      chunks[i - 1].v = chunks[i - 1].v.with_str(
        chunks[i - 1].v.get() + redundant.v.get(),
      )
      chunks[i - 1].span = { ..chunks[i - 1].span, end: redundant.span.end, }
      chunks.remove(i) |> ignore
    } else {
      i += 1
    }
  }
}

///|
/// Characters that can be escaped.
///
/// In read mode (`read_char = true`), colons are also converted to an
/// unescaped string to keep compatibility with Zotero. Zotero escapes colons
/// when exporting verbatim fields. This crate doesn't escape colons when
/// exporting.
pub fn is_escapable(c : Char, verb : Bool, read_char : Bool) -> Bool {
  match c {
    '{' | '}' | '\\' => true
    '~' | '^' | '#' | '&' | '%' | '$' | '_' if !verb => true
    ':' if read_char => true
    _ => false
  }
}

///|
/// Characters that are the name of a single-char command that automatically
/// terminates.
fn is_single_char_func(c : Char, ws : Bool) -> Bool {
  c is ('"' | '´' | '`' | '\'' | '^' | '~' | '=' | '.' | '\\' | '-') ||
  (ws && c is ('b' | 'c' | 'd' | 'H' | 'k' | 'r' | 'u' | 'v'))
}
