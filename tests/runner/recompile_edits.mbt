// The edits of the `recompile` stage (`recompile_stage.mbt`): what happens
// to a project between two compilations.
//
// What it guarantees:
//
// - An edit is a function of the generator's state and of the files as
//   they are: the same seed, document and sequence give the same edits, on
//   every platform (the `Rng` of the `reparse` stage, no library's; no
//   clock; files are chosen from a list in a fixed order).
// - Edits only go through [Project::set] and [Project::variant]: bytes of
//   files and the four things that are not files. Nothing here touches
//   the engine or a world.
// - Every content a file had is kept ([Project::versions]), so that a file
//   can go back to one (A, B, A).
//
// The files that can be edited are the main file and every file that an
// incremental compilation reported as a dependency ([Project::note]),
// which is what a watcher learns too. A file that was looked for and not
// found is a dependency: an edit of it creates it.
//
// Edits of Typst files are of two kinds. The plausible ones are made where
// the syntax tree says they are harmless (inside text, at the end of a
// paragraph, a digit of a number, a number of a set rule): the document
// usually still compiles, and its layout changes.
// The others are made anywhere and usually break it; the edit after one of
// those is likely to undo it, because a project that stays broken tests
// little.

///|
/// True `percent` times in a hundred.
fn Rng::chance(self : Rng, percent : Int) -> Bool {
  self.below(100) < percent
}

///|
fn[T] Rng::pick(self : Rng, items : ArrayView[T]) -> T {
  items[self.below(items.length())]
}

///|
/// The seed of a sequence: the run's seed, the document's name and the
/// number of the sequence (FNV-1a over them).
fn sequence_seed(seed : Int, document : String, sequence : Int) -> UInt64 {
  let mut h = 0xCBF29CE484222325UL
  let mix = (v : UInt64) => h = (h ^ v) * 0x100000001B3UL
  mix(seed.to_uint64())
  for i in 0..<document.length() {
    mix(document.code_unit_at(i).to_int().to_uint64())
  }
  mix(sequence.to_uint64())
  h
}

///|
/// A project under edits.
priv struct Project {
  files : FileSet
  mut variant : Variant
  /// The main file of the document.
  origin : @syntax.FileId
  /// The files that can be edited, in the order they were learned.
  known : Array[@syntax.FileId]
  known_set : Map[@syntax.FileId, Unit]
  /// The contents a file had before its current one, oldest first.
  versions : Map[@syntax.FileId, Array[Bytes?]]
  /// The file that the last edit probably broke, with what it held before.
  mut broken : (@syntax.FileId, Bytes?)?
  /// Counts inserted pieces, so that they differ.
  mut counter : Int
}

///|
fn Project::new(files : FileSet, variant : Variant) -> Project {
  {
    files,
    variant,
    origin: variant.main,
    known: [variant.main],
    known_set: Map([(variant.main, ())]),
    versions: Map([]),
    broken: None,
    counter: 0,
  }
}

///|
/// Learns the dependencies of a compilation.
fn Project::note(self : Project, ids : Array[@syntax.FileId]) -> Unit {
  let ids = ids.copy()
  ids.sort_by((a, b) => @library.compare_str(file_path(a), file_path(b)))
  for id in ids {
    if !self.known_set.contains(id) {
      self.known_set[id] = ()
      self.known.push(id)
    }
  }
}

///|
/// The content of a file, `None` if it is not there.
fn Project::content(self : Project, id : @syntax.FileId) -> Bytes? {
  match self.files.get(id) {
    Ok(bytes) => Some(bytes)
    Err(_) => None
  }
}

///|
/// Gives a file a content (`None`: removes it).
fn Project::set(self : Project, id : @syntax.FileId, content : Bytes?) -> Unit {
  let before = self.content(id)
  if before != content {
    match self.versions.get(id) {
      Some(versions) => versions.push(before)
      None => self.versions[id] = [before]
    }
  }
  self.files.set(id, content)
}

///|
fn is_typ(id : @syntax.FileId) -> Bool {
  id.vpath().extension() is Some("typ")
}

///|
/// The known files that are Typst files (or not).
fn Project::known_files(self : Project, typ : Bool) -> Array[@syntax.FileId] {
  self.known.filter(id => is_typ(id) == typ)
}

///|
/// `bytes` with `start..end` replaced.
fn splice(bytes : Bytes, start : Int, end : Int, replacement : Bytes) -> Bytes {
  let n = replacement.length()
  Bytes::makei(bytes.length() - (end - start) + n, i => {
    if i < start {
      bytes[i]
    } else if i < start + n {
      replacement[i - start]
    } else {
      bytes[i - n + (end - start)]
    }
  })
}

///|
/// An offset in `0..=bytes.length()` that is not inside a UTF-8 sequence.
fn char_boundary(rng : Rng, bytes : Bytes) -> Int {
  let mut k = rng.below(bytes.length() + 1)
  while k > 0 && k < bytes.length() && (bytes[k].to_int() & 0xC0) == 0x80 {
    k -= 1
  }
  k
}

///|
/// The places of a Typst file where an edit is harmless (UTF-8 byte
/// offsets and lengths).
priv struct Sites {
  /// The `Text` leaves.
  text : Array[(Int, Int)]
  /// Where paragraphs end.
  parbreaks : Array[Int]
  /// The number literals.
  numbers : Array[(Int, Int)]
  /// The number literals of set rules.
  set_numbers : Array[(Int, Int)]
  /// The string literals.
  strings : Array[(Int, Int)]
}

///|
fn Sites::of(text : String) -> Sites {
  let sites : Sites = {
    text: [],
    parbreaks: [],
    numbers: [],
    set_numbers: [],
    strings: [],
  }
  fn walk(node : @syntax.SyntaxNode, offset : Int, in_set : Bool) {
    let len = node.len()
    match node.kind() {
      Text => if len > 0 { sites.text.push((offset, len)) }
      Parbreak => sites.parbreaks.push(offset)
      Int | Float | Numeric => {
        sites.numbers.push((offset, len))
        if in_set {
          sites.set_numbers.push((offset, len))
        }
      }
      Str => sites.strings.push((offset, len))
      kind => {
        let in_set = in_set || kind is SetRule
        let mut offset = offset
        for child in node.children() {
          walk(child, offset, in_set)
          offset += child.len()
        }
      }
    }
  }

  walk(@syntax.parse(text), 0, false)
  sites
}

///|
/// Words to insert.
let edit_words : ReadOnlyArray[String] = [
  "also", "quite", "rather long words", "x", "indeed", "typesetting", "and so on",
  "wider", "WWWW", "à la carte", "数字", "fin",
]

///|
/// What an edit puts at the end of a paragraph (`N` is a number).
let edit_blocks : ReadOnlyArray[String] = [
  "Added paragraph N.", "= Added heading N", "== Added section N", "#pagebreak()",
  "Text with a note.#footnote[Added note N.]", "#figure([Added N], caption: [Added figure N])",
  "$ x_N + y^2 $", "- item N\n- item two", "#lorem(30)", "#context counter(heading).get()",
  "#context here().page()", "+ numbered N",
]

///|
/// The set rules an edit puts at the start of a file.
let edit_set_rules : ReadOnlyArray[String] = [
  "#set text(size: 9pt)", "#set par(justify: true)", "#set page(numbering: \"1\")",
  "#set heading(numbering: \"1.1\")", "#set text(fill: blue)", "#set par(leading: 0.5em)",
  "#set page(margin: 12pt)", "#set text(lang: \"de\")", "#set page(columns: 2)",
  "#set math.equation(numbering: \"(1)\")",
]

///|
/// What an edit that does not care about syntax inserts.
let edit_breakers : ReadOnlyArray[String] = [
  "#", "(", ")", "[", "]", "{", "}", "\"", "$", "*", "_", "`", "#let", "#import \"nope.typ\"",
  "#include \"nope.typ\"", "#unknown-fn()", "#panic(\"boom\")", "#(1/0)", "<lbl>",
  "@nope", "//", "/*", "\\", "#show: it => it.nope", "#context nope", "#assert(false)",
  "#import \"nope.typ\": *", "#read(\"nope.txt\")", "#set text(size: -1pt)", "#for x in (1,) {",
]

///|
fn Project::next_number(self : Project) -> Int {
  self.counter += 1
  self.counter
}

///|
/// A number literal with one digit changed (the literal as a whole if it is
/// not decimal).
fn changed_number(rng : Rng, literal : String) -> String {
  let digits = []
  for i in 0..<literal.length() {
    let c = literal.code_unit_at(i).to_int()
    if c >= '0' && c <= '9' {
      digits.push(i)
    }
  }
  if digits.is_empty() ||
    literal.has_prefix("0x") ||
    literal.has_prefix("0b") ||
    literal.has_prefix("0o") {
    return (rng.below(9) + 1).to_string()
  }
  let at = rng.pick(digits[:])
  let old = literal.code_unit_at(at).to_int() - '0'
  let new = (old + 1 + rng.below(8)) % 10
  let new = if new == 0 { 1 } else { new }
  let out = StringBuilder()
  out.write_string(literal.unsafe_substring(start=0, end=at))
  out.write_string(new.to_string())
  out.write_string(literal.unsafe_substring(start=at + 1, end=literal.length()))
  out.to_string()
}

///|
/// The text of a file, if it is one.
fn decoded(bytes : Bytes) -> String? {
  try @utf8.decode(bytes[:]) catch {
    _ => None
  } noraise {
    text => Some(text)
  }
}

///|
fn ascii(bytes : Bytes, start : Int, len : Int) -> String {
  let out = StringBuilder()
  for i in start..<(start + len) {
    out.write_char(bytes[i].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
/// A plausible edit of a Typst file. Returns the new bytes and what was
/// done, or `None` if the file has no place for one.
fn Project::plausible(
  self : Project,
  rng : Rng,
  bytes : Bytes,
) -> (Bytes, String)? {
  guard decoded(bytes) is Some(text) else { return None }
  let sites = Sites::of(text)
  let utf8 = (s : String) => @utf8.encode(s)
  for _ in 0..<4 {
    let roll = rng.below(100)
    match (if roll < 2 { 9 } else { roll % 9 }) {
      // A byte order mark at the start comes or goes (rarely).
      9 =>
        return if bytes.length() >= 3 &&
          bytes[0] == b'\xef' &&
          bytes[1] == b'\xbb' &&
          bytes[2] == b'\xbf' {
          Some((splice(bytes, 0, 3, b""), "remove-bom"))
        } else {
          Some((splice(bytes, 0, 0, b"\xef\xbb\xbf"), "add-bom"))
        }
      // Words inside text.
      0 | 1 if !sites.text.is_empty() => {
        let (start, len) = rng.pick(sites.text[:])
        let mut at = start + rng.below(len + 1)
        while at > start &&
              at < bytes.length() &&
              (bytes[at].to_int() & 0xC0) == 0x80 {
          at -= 1
        }
        let word = " " + rng.pick(edit_words[:]) + " "
        return Some((splice(bytes, at, at, utf8(word)), "insert-text @\{at}"))
      }
      // Text that goes away, or becomes other text.
      2 if !sites.text.is_empty() => {
        let (start, len) = rng.pick(sites.text[:])
        return if rng.chance(50) {
          Some(
            (splice(bytes, start, start + len, b""), "delete-text @\{start}"),
          )
        } else {
          let word = rng.pick(edit_words[:])
          Some(
            (
              splice(bytes, start, start + len, utf8(word)),
              "replace-text @\{start}",
            ),
          )
        }
      }
      // Something new at the end of a paragraph (or of the file).
      3 | 4 => {
        let at = if sites.parbreaks.is_empty() || rng.chance(20) {
          bytes.length()
        } else {
          rng.pick(sites.parbreaks[:])
        }
        let n = self.next_number()
        let block = rng
          .pick(edit_blocks[:])
          .replace_all(old="N", new=n.to_string())
        return Some(
          (splice(bytes, at, at, utf8("\n\n" + block)), "append-block @\{at}"),
        )
      }
      // A number.
      5 | 6 if !sites.numbers.is_empty() => {
        let (start, len) = rng.pick(sites.numbers[:])
        let number = changed_number(rng, ascii(bytes, start, len))
        return Some(
          (
            splice(bytes, start, start + len, utf8(number)),
            "change-number @\{start}",
          ),
        )
      }
      // The value of a set rule, or a new set rule.
      7 | 8 =>
        if !sites.set_numbers.is_empty() && rng.chance(60) {
          let (start, len) = rng.pick(sites.set_numbers[:])
          let number = changed_number(rng, ascii(bytes, start, len))
          return Some(
            (
              splice(bytes, start, start + len, utf8(number)),
              "change-set-rule @\{start}",
            ),
          )
        } else {
          let rule = rng.pick(edit_set_rules[:])
          return Some((splice(bytes, 0, 0, utf8(rule + "\n")), "add-set-rule"))
        }
      _ => continue
    }
  }
  None
}

///|
/// An edit of a Typst file that does not look at its syntax (or that
/// changes the letters of a string, which is a path more often than not).
fn implausible(rng : Rng, bytes : Bytes) -> (Bytes, String) {
  match rng.below(14) {
    12 | 13 => {
      let strings = match decoded(bytes) {
        Some(text) => Sites::of(text).strings
        None => []
      }
      if strings.is_empty() {
        (splice(bytes, 0, 0, b"#"), "insert-breaker @0")
      } else {
        let (start, len) = rng.pick(strings[:])
        // Before the closing quote.
        let at = start + len - 1
        (splice(bytes, at, at, b"x"), "change-string @\{at}")
      }
    }
    0..=5 => {
      let at = char_boundary(rng, bytes)
      let breaker = rng.pick(edit_breakers[:])
      (splice(bytes, at, at, @utf8.encode(breaker)), "insert-breaker @\{at}")
    }
    6 | 7 => {
      let start = char_boundary(rng, bytes)
      let mut end = start + 1 + rng.below(40)
      if end > bytes.length() {
        end = bytes.length()
      }
      while end < bytes.length() && (bytes[end].to_int() & 0xC0) == 0x80 {
        end += 1
      }
      (splice(bytes, start, end, b""), "delete-range @\{start}..\{end}")
    }
    8 | 9 => {
      // A whole line.
      let at = char_boundary(rng, bytes)
      let mut start = at
      while start > 0 && bytes[start - 1] != b'\n' {
        start -= 1
      }
      let mut end = at
      while end < bytes.length() && bytes[end] != b'\n' {
        end += 1
      }
      if end < bytes.length() {
        end += 1
      }
      (splice(bytes, start, end, b""), "delete-line @\{start}..\{end}")
    }
    10 => {
      let at = char_boundary(rng, bytes)
      (splice(bytes, at, bytes.length(), b""), "truncate @\{at}")
    }
    _ => {
      // Not UTF-8 any more.
      let at = char_boundary(rng, bytes)
      (splice(bytes, at, at, b"\xff"), "insert-invalid-utf8 @\{at}")
    }
  }
}

///|
/// An edit of a file that is not a Typst file after which it is probably
/// still what its readers expect: a digit, the content of another file of
/// its kind, a letter. `None` if the file has no place for one.
fn Project::data_plausible(
  self : Project,
  rng : Rng,
  id : @syntax.FileId,
  bytes : Bytes,
) -> (Bytes, String)? {
  let digits = []
  let letters = []
  if decoded(bytes) is Some(_) {
    for i in 0..<bytes.length() {
      let c = bytes[i].to_int()
      if c >= '0' && c <= '9' {
        digits.push(i)
      } else if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
        letters.push(i)
      }
    }
  }
  // The other known files of the same kind with another content.
  let same = self.known.filter(other => {
    other != id &&
    other.vpath().extension() == id.vpath().extension() &&
    self.content(other) is Some(content) &&
    content != bytes
  })
  if !same.is_empty() && (digits.is_empty() || rng.chance(40)) {
    let other = rng.pick(same[:])
    if self.content(other) is Some(content) {
      return Some((content, "content-of \{file_path(other)}"))
    }
  }
  if !digits.is_empty() && (letters.is_empty() || rng.chance(75)) {
    let at = rng.pick(digits[:])
    // Another digit, not 0 (a number with a leading zero is none in JSON).
    let old = bytes[at].to_int() - '0'
    let new = 1 + (old + rng.below(8)) % 9
    let digit = Bytes::makei(1, _ => (new + '0').to_byte())
    return Some((splice(bytes, at, at + 1, digit), "change-digit @\{at}"))
  }
  if !letters.is_empty() {
    // Another letter.
    let at = rng.pick(letters[:])
    let old = (bytes[at].to_int() | 0x20) - 'a'
    let new = (old + 1 + rng.below(25)) % 26
    let letter = Bytes::makei(1, _ => (new + 'a').to_byte())
    return Some((splice(bytes, at, at + 1, letter), "change-letter @\{at}"))
  }
  None
}

///|
/// An edit of a file that is not a Typst file which does not care what the
/// file is.
fn data_implausible(rng : Rng, bytes : Bytes) -> (Bytes, String) {
  if bytes.length() == 0 {
    return (b"\x00", "one-byte")
  }
  let at = rng.below(bytes.length())
  match rng.below(5) {
    0 | 1 => {
      let bit = (1 << rng.below(8)).to_byte()
      let flipped = Bytes::makei(1, _ => bytes[at] ^ bit)
      (splice(bytes, at, at + 1, flipped), "flip-bit @\{at}")
    }
    2 | 3 => (splice(bytes, at, bytes.length(), b""), "truncate @\{at}")
    _ => (b"", "empty")
  }
}

///|
/// A file that is not there appears.
fn Project::create(self : Project, rng : Rng, id : @syntax.FileId) -> String {
  let n = self.next_number()
  let content : Bytes = if is_typ(id) {
    @utf8.encode("#let nope = \{n}\nCreated file \{n}.\n")
  } else if rng.chance(50) {
    @utf8.encode(n.to_string())
  } else {
    b""
  }
  self.set(id, Some(content))
  "create \{file_path(id)}"
}

///|
/// A known file to edit: the main file half of the time if it is of the
/// wanted kind, any other otherwise. `None` if there is none but `not`.
fn Project::pick_file(
  self : Project,
  rng : Rng,
  typ : Bool,
  not : @syntax.FileId?,
) -> @syntax.FileId? {
  let main = self.variant.main
  if is_typ(main) == typ && not != Some(main) && rng.chance(45) {
    return Some(main)
  }
  let files = self.known.filter(id => is_typ(id) == typ && not != Some(id))
  if files.is_empty() {
    None
  } else {
    Some(rng.pick(files[:]))
  }
}

///|
/// One edit of one file's bytes (not `not`). Returns what was done and to
/// which file, or `None` if nothing could be.
fn Project::file_edit(
  self : Project,
  rng : Rng,
  not : @syntax.FileId?,
) -> (String, @syntax.FileId)? {
  let roll = rng.below(100)
  // A file goes back to a content it had.
  if roll < 12 {
    let files = self.known.filter(id => {
      not != Some(id) && self.versions.get(id) is Some(_)
    })
    if !files.is_empty() {
      let id = rng.pick(files[:])
      let versions = self.versions[id]
      let version = if rng.chance(60) {
        versions[versions.length() - 1]
      } else {
        rng.pick(versions[:])
      }
      self.set(id, version)
      return Some(("revert \{file_path(id)}", id))
    }
  }
  // A file goes away.
  if roll < 16 {
    let files = self.known.filter(id => {
      not != Some(id) && self.content(id) is Some(_)
    })
    if !files.is_empty() {
      let id = rng.pick(files[:])
      self.broken = Some((id, self.content(id)))
      self.set(id, None)
      return Some(("remove \{file_path(id)}", id))
    }
  }
  // A third of the edits are of data, if there is any.
  let typ = self.known_files(false).is_empty() || rng.chance(65)
  guard self.pick_file(rng, typ, not) is Some(id) else { return None }
  let path = file_path(id)
  guard self.content(id) is Some(bytes) else {
    return Some((self.create(rng, id), id))
  }
  // A quarter of the edits do not care what the file is.
  let edited = if !rng.chance(75) {
    None
  } else if typ {
    self.plausible(rng, bytes)
  } else {
    self.data_plausible(rng, id, bytes)
  }
  let (new, what) = match edited {
    Some(edited) => edited
    None => {
      self.broken = Some((id, Some(bytes)))
      if typ {
        implausible(rng, bytes)
      } else {
        data_implausible(rng, bytes)
      }
    }
  }
  self.set(id, Some(new))
  Some(("\{what} \{path}", id))
}

///|
/// The next edit of a random sequence: changes the project and says what
/// it did.
fn Project::edit(self : Project, rng : Rng) -> String {
  // What the last edit broke is probably repaired.
  if self.broken is Some((id, before)) {
    self.broken = None
    if rng.chance(75) {
      self.set(id, before)
      return "repair \{file_path(id)}"
    }
  }
  // Away from the document's main file, the way back is likely.
  if self.variant.main != self.origin && rng.chance(34) {
    self.variant = { ..self.variant, main: self.origin, }
    return "main-back \{file_path(self.origin)}"
  }
  let roll = rng.below(100)
  if roll < 4 {
    return "nothing"
  }
  if roll < 8 {
    // The same bytes, written again.
    let id = rng.pick(self.known[:])
    self.files.set(id, self.content(id))
    return "touch \{file_path(id)}"
  }
  if roll < 14 {
    let day = match rng.below(10) {
      0..=4 => self.variant.day + 1
      5..=7 => 0
      _ => rng.below(20000)
    }
    self.variant = { ..self.variant, day, }
    return "today \{day}"
  }
  if roll < 20 {
    let inputs = (
        self.variant.inputs + 1 + rng.below(recompile_inputs.length() - 1)
      ) %
      recompile_inputs.length()
    self.variant = { ..self.variant, inputs, }
    return "inputs \{inputs}"
  }
  if roll < 23 {
    let fonts = 1 - self.variant.fonts
    self.variant = { ..self.variant, fonts, }
    return "fonts \{fonts}"
  }
  if roll < 28 {
    // Another file of the project becomes the main file.
    let files = self.known.filter(id => {
      is_typ(id) && id != self.variant.main && id.root() is Project
    })
    if !files.is_empty() {
      let main = rng.pick(files[:])
      self.variant = { ..self.variant, main, }
      return "main \{file_path(main)}"
    }
  }
  if roll < 38 {
    // Two files at once.
    if self.file_edit(rng, None) is Some((first, id)) {
      // The repair of a step undoes one file: the first's.
      let broken = self.broken
      return match self.file_edit(rng, Some(id)) {
        Some((second, _)) => {
          if broken is Some(_) {
            self.broken = broken
          }
          "\{first} + \{second}"
        }
        None => first
      }
    }
  }
  match self.file_edit(rng, None) {
    Some((what, _)) => what
    None => "nothing"
  }
}

///|
/// The sweep: the sequence that changes, one after the other, everything a
/// compilation can depend on while the rest stays as it is. A result that
/// is kept and that depends on something its key does not hold is found
/// here, without luck: the date and `sys.inputs` (each only if a known
/// file reads it), the fonts, the main file, then every other known file
/// (at most `files` of them, spread over the list from a place that the
/// seed chooses), each with a plausible edit, and at the end everything
/// back to what it was at first. A change after which the document does
/// not compile is undone with the next one, so that everything is changed
/// in a document that works.
priv struct Sweep {
  /// How many of the other files are edited at most.
  files : Int
  /// Whether the fonts change.
  fonts : Bool
  mut stage : Int
  /// The other files, once the sweep gets to them.
  mut plan : Array[@syntax.FileId]
  mut at : Int
  /// What the last step changed, to undo it.
  mut last : SweepUndo?
}

///|
/// What undoes a step of the sweep.
priv enum SweepUndo {
  /// A file and what it held before.
  File(@syntax.FileId, Bytes?)
  /// What was not a file before.
  Variant(Variant)
}

///|
fn Sweep::new(files : Int, fonts : Bool) -> Sweep {
  { files, fonts, stage: 0, plan: [], at: 0, last: None, }
}

///|
/// Whether a known file contains `word`.
fn Project::mentions(self : Project, word : Bytes) -> Bool {
  let n = word.length()
  for id in self.known {
    guard self.content(id) is Some(bytes) else { continue }
    for i in 0..<=(bytes.length() - n) {
      let mut k = 0
      while k < n && bytes[i + k] == word[k] {
        k += 1
      }
      if k == n {
        return true
      }
    }
  }
  false
}

///|
/// A plausible edit of a file whatever it is.
fn Project::careful_edit(
  self : Project,
  rng : Rng,
  id : @syntax.FileId,
) -> String {
  guard self.content(id) is Some(bytes) else { return self.create(rng, id) }
  let edited = if is_typ(id) {
    self.plausible(rng, bytes)
  } else {
    self.data_plausible(rng, id, bytes)
  }
  let (new, what) = match edited {
    Some(edited) => edited
    None =>
      if is_typ(id) {
        implausible(rng, bytes)
      } else {
        data_implausible(rng, bytes)
      }
  }
  self.set(id, Some(new))
  "\{what} \{file_path(id)}"
}

///|
/// The next edit of the sweep, `None` when it is over. `ok` says whether
/// the document compiled after the last one.
fn Project::sweep(
  self : Project,
  rng : Rng,
  sweep : Sweep,
  ok : Bool,
) -> String? {
  // A change that broke the document is undone together with the next.
  let undo = match sweep.last {
    Some(File(id, before)) if !ok => {
      self.set(id, before)
      "undo \{file_path(id)} + "
    }
    Some(Variant(before)) if !ok => {
      self.variant = before
      "undo + "
    }
    _ => ""
  }
  sweep.last = None
  let vary = (variant : Variant, what : String) => {
    sweep.last = Some(Variant(self.variant))
    self.variant = variant
    Some(undo + what)
  }
  if sweep.stage == 0 {
    sweep.stage = 1
    if self.mentions(b"today(") {
      let day = self.variant.day + 1
      return vary({ ..self.variant, day, }, "today \{day}")
    }
  }
  if sweep.stage == 1 {
    sweep.stage = 2
    if self.mentions(b"sys.inputs") {
      return vary({ ..self.variant, inputs: 1, }, "inputs 1")
    }
  }
  if sweep.stage == 2 {
    sweep.stage = 3
    if sweep.fonts {
      return vary({ ..self.variant, fonts: 1, }, "fonts 1")
    }
  }
  let edit = (id : @syntax.FileId) => {
    sweep.last = Some(File(id, self.content(id)))
    Some(undo + self.careful_edit(rng, id))
  }
  if sweep.stage == 3 {
    sweep.stage = 4
    return edit(self.origin)
  }
  if sweep.stage == 4 {
    if sweep.at == 0 {
      let others = self.known.filter(id => id != self.origin)
      let n = @cmp.minimum(others.length(), sweep.files)
      // If not all are edited, which ones depends on the seed.
      let first = if n < others.length() {
        rng.below(others.length())
      } else {
        0
      }
      sweep.plan = Array::makei(n, i => {
        others[(first + i * others.length() / n) % others.length()]
      })
    }
    if sweep.at < sweep.plan.length() {
      let id = sweep.plan[sweep.at]
      sweep.at += 1
      return edit(id)
    }
    sweep.stage = 5
  }
  if sweep.stage == 5 {
    sweep.stage = 6
    let ids = self.versions.keys().to_array()
    for id in ids {
      self.set(id, self.versions[id][0])
    }
    self.variant = { main: self.origin, inputs: 0, day: 0, fonts: 0, }
    return Some("everything-back")
  }
  None
}
