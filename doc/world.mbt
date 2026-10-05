// Worlds (docs/edsl-design.md, section 14.3). `compile_*` takes any
// `&@library.World`; `DocWorld` is a ready-made one without OS access (the
// system world is in `doc/system`).

///|
/// A world built from callbacks: project files, fonts and the date.
pub struct DocWorld {
  priv library : @library.Library
  priv load : (@syntax.FileId) -> Bytes raise @library.FileError
  priv sources : Map[@syntax.FileId, @syntax.Source]
  priv book : @library.FontBook
  priv font : (Int) -> @library.Font?
  priv today : (@library.Duration?) -> @library.Datetime?
}

///|
/// The standard library with the PDF, SVG and PNG formats.
pub fn standard_library() -> @library.Library {
  @typst.library([
    @library.pdf_format(),
    @library.svg_format(),
    @library.png_format(),
  ])
}

///|
/// A world from its parts: `load` reads a file by id (project files have
/// the root `Project`; the path is `id.vpath()`), `book` and `font` provide
/// the fonts, `today` the date.
pub fn DocWorld::new(
  load~ : (@syntax.FileId) -> Bytes raise @library.FileError,
  book~ : @library.FontBook,
  font~ : (Int) -> @library.Font?,
  today? : (@library.Duration?) -> @library.Datetime? = _ => None,
) -> DocWorld {
  { library: standard_library(), load, sources: Map([]), book, font, today, }
}

///|
/// The embedded Typst fonts (Libertinus Serif, New Computer Modern, DejaVu
/// Sans Mono).
pub fn typst_fonts() -> Array[@library.Font] {
  let fonts : Array[@library.Font] = []
  for data in @assets_fonts.fonts() {
    fonts.append(@library.Font::iter(data))
  }
  fonts
}

///|
/// A world without OS access: `files` are the project files by
/// root-relative path (`"assets/chart.png"`), `fonts` are font files, to
/// which the embedded Typst fonts are added unless `embedded_fonts` is
/// false; `today` is the date as `(year, month, day)`.
pub fn DocWorld::in_memory(
  files? : Map[String, Bytes] = {},
  fonts? : Array[Bytes] = [],
  embedded_fonts? : Bool = true,
  today? : (Int, Int, Int),
) -> DocWorld {
  let all : Array[@library.Font] = []
  for data in fonts {
    all.append(@library.Font::iter(data))
  }
  if embedded_fonts {
    all.append(typst_fonts())
  }
  let book = @library.FontBook::from_fonts(all)
  // Normalize the keys to virtual paths without the leading slash.
  let by_path : Map[String, Bytes] = Map([])
  for path, data in files {
    let key = try @syntax.VirtualPath::new(path) catch {
      _ => path
    } noraise {
      vpath => vpath.get_without_slash()
    }
    by_path[key] = data
  }
  let date = match today {
    Some((year, month, day)) => @library.Datetime::from_ymd(year, month, day)
    None => None
  }
  DocWorld::new(
    load=id => {
      let path = id.vpath().get_without_slash()
      guard id.root() is Project && by_path.get(path) is Some(data) else {
        raise @library.FileError::NotFound(path)
      }
      data
    },
    book~,
    font=index => all.get(index),
    today=_ => date,
  )
}

///|
pub impl @library.World for DocWorld with fn library(self) {
  self.library
}

///|
pub impl @library.World for DocWorld with fn main(_) {
  origins_file
}

///|
pub impl @library.World for DocWorld with fn source(self, id) {
  if self.sources.get(id) is Some(source) {
    return source
  }
  let bytes = (self.load)(id)
  // Strip a UTF-8 BOM.
  let view = if bytes.length() >= 3 &&
    bytes[0] == b'\xEF' &&
    bytes[1] == b'\xBB' &&
    bytes[2] == b'\xBF' {
    bytes[3:]
  } else {
    bytes[:]
  }
  let text = @utf8.decode(view) catch {
    _ => raise @library.FileError::InvalidUtf8
  }
  let source = @syntax.Source::new(id, text)
  self.sources[id] = source
  source
}

///|
pub impl @library.World for DocWorld with fn file(self, id) {
  (self.load)(id)
}

///|
pub impl @library.World for DocWorld with fn book(self) {
  self.book
}

///|
pub impl @library.World for DocWorld with fn font(self, index) {
  (self.font)(index)
}

///|
pub impl @library.World for DocWorld with fn today(self, offset) {
  (self.today)(offset)
}
