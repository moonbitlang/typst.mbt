// The origin registry (docs/edsl-design.md, section 12): an append-only
// table of the constructor calls that were lowered in a session. Its text
// form, the origin listing, is a virtual source file, so engine spans are
// real byte ranges of a real file.

///|
/// The largest byte offset a range span can hold (`Span::from_range`
/// saturates above it).
let span_range_max : Int = 8388607

///|
/// The maximum number of distinct markup snippets of a session.
let snippet_slot_max : Int = 4096

///|
/// The longest string whose glyph span offsets are exact (they are 16-bit).
let text_offset_max : Int = 65535

///|
/// The file of the origin listing: a project-root file, so that relative
/// paths of arguments resolve against the project root.
let origins_file : @syntax.FileId = @syntax.RootedPath::new(
  Project,
  @syntax.VirtualPath::new("<edsl-origins>") catch {
    _ => panic()
  },
).intern()

///|
/// The file of the markup snippet in slot `slot`.
fn snippet_file(slot : Int) -> @syntax.FileId {
  @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new("<edsl-markup-\{slot}>") catch {
      _ => panic()
    },
  ).intern()
}

///|
/// One origin: a constructor call (site) plus the keys of the enclosing
/// `Keyed` wrappers.
priv struct Entry {
  /// The call's location (`file:line:col-line:col@module`).
  loc : String
  /// The constructor's name.
  kind : String
  /// The occurrence keys, outermost first.
  keys : Array[String]
  /// The byte range of the entry's line in the listing (without newline).
  start : Int
  end : Int
  /// Per declared parameter: its location and the byte range of its token
  /// in the listing.
  args : Array[(String, Int, Int)?]
  /// Whether a text of more than 65,535 bytes was lowered with this origin,
  /// so that glyph offsets are not reliable.
  mut long_text : Bool
}

///|
/// A markup or math snippet evaluated by the front end.
priv struct Snippet {
  /// The entry of the `Markup`/`Equation` call.
  entry : Int
  mode : @syntax.SyntaxMode
  text : String
  id : @syntax.FileId
  mut source : @syntax.Source?
}

///|
priv struct Registry {
  entries : Array[Entry]
  /// Deduplication: site location and key path to entry index.
  index : Map[String, Int]
  /// The origin listing.
  listing : StringBuilder
  /// The length of the listing in bytes.
  mut len : Int
  snippets : Array[Snippet]
  snippet_index : Map[String, Int]
  /// The parsed listing (for `World::source`), invalidated by appends.
  mut source : @syntax.Source?
}

///|
fn Registry::new() -> Registry {
  {
    entries: [],
    index: {},
    listing: StringBuilder(),
    len: 0,
    snippets: [],
    snippet_index: {},
    source: None,
  }
}

///|
/// An error diagnostic without a span.
fn detached_error(message : String, hint : String) -> @library.SourceError {
  @library.SourceError([
    @library.SourceDiagnostic::error(@syntax.DiagSpan::detached(), message).with_hint(
      hint,
    ),
  ])
}

///|
/// The entry of an origin, registering it on first use. Existing entries
/// (and their lines) never change.
fn Registry::entry(
  self : Registry,
  site : Site,
  keys : Array[String],
) -> Int raise @library.SourceError {
  let ArgsLoc(arg_locs) = site.args
  self.entry_of(
    site.loc.to_string(),
    site.kind,
    arg_locs.map(arg => arg.map(arg => arg.to_string())),
    keys,
  )
}

///|
/// The entry of the same call as `entry` under other keys.
fn Registry::rekeyed(
  self : Registry,
  entry : Int,
  keys : Array[String],
) -> Int raise @library.SourceError {
  let e = self.entries[entry]
  self.entry_of(e.loc, e.kind, e.args.map(arg => arg.map(arg => arg.0)), keys)
}

///|
/// See [Registry::entry]: `arg_locs` are the locations of the call's
/// arguments, per declared parameter.
fn Registry::entry_of(
  self : Registry,
  loc : String,
  kind : String,
  arg_locs : Array[String?],
  keys : Array[String],
) -> Int raise @library.SourceError {
  // The deduplication key is unambiguous for any keys: each is prefixed
  // with its length.
  let dedup = if keys.is_empty() {
    loc
  } else {
    let dedup = StringBuilder()
    dedup.write_string(loc)
    for key in keys {
      dedup.write_string("\u{0}\{key.length()}:")
      dedup.write_string(key)
    }
    dedup.to_string()
  }
  if self.index.get(dedup) is Some(i) {
    return i
  }
  // Build the line.
  let line = StringBuilder()
  line.write_string(loc)
  line.write_char(' ')
  line.write_string(kind)
  for key in keys {
    line.write_string(" key=")
    line.write_string(@library.repr_str(key))
  }
  let start = self.len
  let args : Array[(String, Int, Int)?] = []
  for i, arg in arg_locs {
    match arg {
      None => args.push(None)
      Some(arg) => {
        line.write_char(' ')
        let token_start = start + @syntax.utf8_len(line.to_string())
        line.write_string("a\{i}=")
        line.write_string(arg)
        let token_end = start + @syntax.utf8_len(line.to_string())
        args.push(Some((arg, token_start, token_end)))
      }
    }
  }
  let text = line.to_string()
  let end = start + @syntax.utf8_len(text)
  if end > span_range_max {
    raise detached_error(
      "too many distinct origins", "the origin table of a document is limited to 8 MiB; many distinct `Keyed` keys are the usual cause",
    )
  }
  self.listing.write_string(text)
  self.listing.write_char('\n')
  self.len = end + 1
  self.source = None
  let i = self.entries.length()
  self.entries.push({
    loc,
    kind,
    keys: keys.copy(),
    start,
    end,
    args,
    long_text: false,
  })
  self.index[dedup] = i
  i
}

///|
/// The span of an entry: its line.
fn Registry::span(self : Registry, entry : Int) -> @syntax.Span {
  let e = self.entries[entry]
  @syntax.Span::from_range(origins_file, e.start, e.end)
}

///|
/// The span of a parameter of an entry: its token, or the entry's line if
/// the argument has no location.
fn Registry::arg_span(
  self : Registry,
  entry : Int,
  param : Int,
) -> @syntax.Span {
  let e = self.entries[entry]
  if param >= 0 && param < e.args.length() && e.args[param] is Some((_, s, t)) {
    @syntax.Span::from_range(origins_file, s, t)
  } else {
    @syntax.Span::from_range(origins_file, e.start, e.end)
  }
}

///|
/// Record that a text too long for exact glyph offsets was lowered with the
/// origin of `span`.
fn Registry::mark_long_text(self : Registry, span : @syntax.Span) -> Unit {
  if self.locate(span) is Some((entry, _)) {
    self.entries[entry].long_text = true
  }
}

///|
/// The entry whose line contains a span of the origin listing, and the
/// parameter whose token the span is (`-1` for the entry's own span).
fn Registry::locate(self : Registry, span : @syntax.Span) -> (Int, Int)? {
  guard span.get() is Range(id~, start~, end~) && id == origins_file else {
    return None
  }
  // Entries are sorted by their start: find the last one at or before it.
  let mut lo = 0
  let mut hi = self.entries.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if self.entries[mid].start <= start {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  guard lo > 0 else { return None }
  let e = self.entries[lo - 1]
  guard start <= e.end else { return None }
  for i, arg in e.args {
    if arg is Some((_, s, t)) && s == start && t == end {
      return Some((lo - 1, i))
    }
  }
  Some((lo - 1, -1))
}

///|
/// The span for locationless content (a plain string) inside `Keyed`
/// wrappers: the argument or call of `span` under `keys`, so that the
/// occurrences resolve to distinct origins with the same location.
fn Registry::keyed_span(
  self : Registry,
  span : @syntax.Span,
  keys : Array[String],
) -> @syntax.Span raise @library.SourceError {
  guard self.locate(span) is Some((entry, param)) else { return span }
  let keyed = self.rekeyed(entry, keys)
  if param >= 0 {
    self.arg_span(keyed, param)
  } else {
    self.span(keyed)
  }
}

///|
/// The slot of a snippet, registering it on first use.
fn Registry::snippet(
  self : Registry,
  entry : Int,
  mode : @syntax.SyntaxMode,
  text : String,
  span : @syntax.Span,
) -> @syntax.FileId raise @library.SourceError {
  let mode_key = match mode {
    Markup => "m"
    Math => "$"
    Code => "c"
  }
  let dedup = "\{entry}\u{0}\{mode_key}\u{0}\{text}"
  if self.snippet_index.get(dedup) is Some(slot) {
    return self.snippets[slot].id
  }
  let slot = self.snippets.length()
  if slot >= snippet_slot_max {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        span, "too many distinct markup fragments",
      ).with_hint(
        "a document is limited to \{snippet_slot_max} distinct `Markup` and `Equation` sources",
      ),
    ])
  }
  if @syntax.utf8_len(text) > span_range_max {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(span, "markup fragment is too large").with_hint(
        "a fragment is limited to 8 MiB",
      ),
    ])
  }
  let id = snippet_file(slot)
  self.snippets.push({ entry, mode, text, id, source: None, })
  self.snippet_index[dedup] = slot
  id
}

///|
/// The listing as a source file.
fn Registry::listing_source(self : Registry) -> @syntax.Source {
  match self.source {
    Some(source) => source
    None => {
      let source = @syntax.Source::new(origins_file, self.listing.to_string())
      self.source = Some(source)
      source
    }
  }
}

///|
/// The virtual source file with the given id, if it belongs to the session.
fn Registry::virtual_source(
  self : Registry,
  id : @syntax.FileId,
) -> @syntax.Source? {
  if id == origins_file {
    return Some(self.listing_source())
  }
  for snippet in self.snippets {
    if snippet.id == id {
      return match snippet.source {
        Some(source) => Some(source)
        None => {
          let source = @syntax.Source::new(id, snippet.text)
          snippet.source = Some(source)
          Some(source)
        }
      }
    }
  }
  None
}

// Snapshots and resolution.

///|
/// A resolved source location of the EDSL program.
pub struct Origin {
  /// The source file as the compiler recorded it.
  file : String
  /// The module of the source file.
  module_name : String
  /// One-based line and column of the start and (exclusive) end.
  start_line : Int
  start_column : Int
  end_line : Int
  end_column : Int
  /// The constructor that was called.
  kind : String
  /// The occurrence keys of the enclosing `Keyed` wrappers, outermost first.
  keys : Array[String]
  /// The index of the constructor parameter the location refers to, if it
  /// is narrower than the call.
  param : Int?
  /// For locations inside a `Markup`/`Equation` source: the byte range in
  /// that source string.
  text_range : (Int, Int)?
}

///|
/// `file:line:column`.
pub fn Origin::position(self : Origin) -> String {
  "\{self.file}:\{self.start_line}:\{self.start_column}"
}

///|
/// `file:line:column (Constructor)`, with keys and the argument if any.
pub fn Origin::describe(self : Origin) -> String {
  let out = StringBuilder()
  out.write_string(self.position())
  out.write_string(" (")
  out.write_string(self.kind)
  if self.param is Some(param) {
    out.write_string(", argument \{param + 1}")
  }
  for key in self.keys {
    out.write_string(", key ")
    out.write_string(@library.repr_str(key))
  }
  if self.text_range is Some((start, end)) {
    out.write_string(", bytes \{start}..\{end} of the source string")
  }
  out.write_string(")")
  out.to_string()
}

///|
/// Parse a decimal number.
fn parse_int(s : StringView) -> Int {
  let mut n = 0
  for c in s {
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  n
}

///|
/// Parse `file:line:col-line:col@module` (the format of `SourceLoc`).
fn parse_loc(repr : String) -> (String, String, Int, Int, Int, Int) {
  // The module follows the last `@`, the range the last two `:` groups
  // around `-`.
  let (rest, module_name) = match repr.rev_find("@") {
    Some(i) =>
      (repr.view(end_offset=i), repr.view(start_offset=i + 1).to_owned())
    None => (repr.view(), "")
  }
  let parts = rest.split(":").map(p => p.to_owned()).collect()
  let n = parts.length()
  if n < 4 {
    return (rest.to_owned(), module_name, 0, 0, 0, 0)
  }
  // parts: file segments..., start_line, "start_col-end_line", end_col
  let end_column = parse_int(parts[n - 1])
  let middle = parts[n - 2]
  let (start_column, end_line) = match middle.find("-") {
    Some(i) =>
      (
        parse_int(middle.view(end_offset=i)),
        parse_int(middle.view(start_offset=i + 1)),
      )
    None => (parse_int(middle), 0)
  }
  let start_line = parse_int(parts[n - 3])
  let file = parts[0:n - 3].join(":")
  (file, module_name, start_line, start_column, end_line, end_column)
}

///|
/// An immutable snapshot of a session's origins: the origin listing, its
/// entries and the markup snippets. It resolves spans without a world.
pub struct Origins {
  priv entries : Array[Entry]
  priv listing : String
  priv snippets : Array[Snippet]
}

///|
fn Registry::freeze(self : Registry) -> Origins {
  {
    entries: self.entries.map(e => {
      loc: e.loc,
      kind: e.kind,
      keys: e.keys,
      start: e.start,
      end: e.end,
      args: e.args.copy(),
      long_text: e.long_text,
    }),
    listing: self.listing.to_string(),
    snippets: self.snippets.map(s => {
      entry: s.entry,
      mode: s.mode,
      text: s.text,
      id: s.id,
      source: None,
    }),
  }
}

///|
/// The number of distinct origins.
pub fn Origins::length(self : Origins) -> Int {
  self.entries.length()
}

///|
/// The origin listing: one line per origin.
pub fn Origins::listing(self : Origins) -> String {
  self.listing
}

///|
/// The source text of a virtual file of the session (the origin listing or
/// a markup snippet).
pub fn Origins::source_text(self : Origins, id : @syntax.FileId) -> String? {
  if id == origins_file {
    return Some(self.listing)
  }
  for snippet in self.snippets {
    if snippet.id == id {
      return Some(snippet.text)
    }
  }
  None
}

///|
fn Origins::entry_at(self : Origins, offset : Int) -> Int? {
  // Binary search for the last entry starting at or before `offset`.
  let mut lo = 0
  let mut hi = self.entries.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if self.entries[mid].start <= offset {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo == 0 {
    return None
  }
  let e = self.entries[lo - 1]
  if offset <= e.end {
    Some(lo - 1)
  } else {
    None
  }
}

///|
fn Origins::origin_of(
  self : Origins,
  entry : Int,
  param : Int?,
  text_range : (Int, Int)?,
) -> Origin {
  let e = self.entries[entry]
  let loc = match param {
    Some(p) if p < e.args.length() && e.args[p] is Some((loc, _, _)) => loc
    _ => e.loc
  }
  let (file, module_name, start_line, start_column, end_line, end_column) = parse_loc(
    loc,
  )
  {
    file,
    module_name,
    start_line,
    start_column,
    end_line,
    end_column,
    kind: e.kind,
    keys: e.keys,
    param,
    text_range,
  }
}

///|
/// The origin an engine span refers to: the constructor call (and argument)
/// for spans of the origin listing, the `Markup`/`Equation` call and the
/// byte range in its source for spans of a snippet. `None` for detached
/// spans and spans of other files.
pub fn Origins::resolve(self : Origins, span : @syntax.Span) -> Origin? {
  self.resolve_range(@syntax.DiagSpan::from_span(span))
}

///|
/// [Origins::resolve] for diagnostic spans.
pub fn Origins::resolve_range(
  self : Origins,
  span : @syntax.DiagSpan,
) -> Origin? {
  match span.get() {
    Range(id~, start~, end~) =>
      if id == origins_file {
        guard self.entry_at(start) is Some(entry) else { return None }
        let e = self.entries[entry]
        let mut param : Int? = Option::None
        for i, arg in e.args {
          if arg is Some((_, s, t)) && s == start && t == end {
            param = Some(i)
            break
          }
        }
        Some(self.origin_of(entry, param, None))
      } else {
        for snippet in self.snippets {
          if snippet.id == id {
            return Some(self.origin_of(snippet.entry, None, Some((start, end))))
          }
        }
        None
      }
    Number(id~, num~, sub_range~) => {
      // Numbered spans only occur in snippets that were parsed as sources.
      for snippet in self.snippets {
        if snippet.id == id {
          let source = match snippet.source {
            Some(source) => source
            None => {
              let source = @syntax.Source::new(id, snippet.text)
              snippet.source = Some(source)
              source
            }
          }
          let range = source.range(num, sub_range)
          return Some(self.origin_of(snippet.entry, None, range))
        }
      }
      None
    }
    Detached => None
  }
}

///|
/// The provenance of a glyph (docs/edsl-design.md, section 12.1).
pub struct TextOrigin {
  /// The constructor call the glyph's text comes from (exact).
  origin : Origin
  /// The glyph's span offset as the engine recorded it: a hint for
  /// narrowing within the node's text, never claimed exact (the engine may
  /// have preprocessed the text). `None` where it is known to be
  /// unreliable: the origin lowered a text of more than 65,535 bytes.
  engine_offset : Int?
}

///|
/// Resolve the span and span offset of a glyph.
pub fn Origins::resolve_glyph(
  self : Origins,
  span : @syntax.Span,
  offset : Int,
) -> TextOrigin? {
  guard self.resolve(span) is Some(origin) else { return None }
  let long_text = match @syntax.DiagSpan::from_span(span).get() {
    Range(id~, start~, ..) =>
      id == origins_file &&
      (match self.entry_at(start) {
        Some(entry) => self.entries[entry].long_text
        None => false
      })
    _ => false
  }
  Some({ origin, engine_offset: if long_text { None } else { Some(offset) }, })
}
