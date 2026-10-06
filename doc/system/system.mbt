// The system world of the EDSL (docs/edsl-design.md, section 14.3): files
// under a root directory, packages, fonts and the date of the operating
// system, built from `kit`. All OS access of the EDSL is in this package.

///|
/// An error of the system helpers.
pub suberror SystemError {
  SystemError(String)
}

///|
pub impl @builtin.Show for SystemError with fn output(self, logger) {
  let SystemError(message) = self
  logger.write_string(message)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SystemError with Show::{to_string, output}

///|
/// A world that reads project files below `root` (default: the working
/// directory) and packages from the system's package directories.
///
/// Fonts: the embedded Typst fonts and the system fonts (each unless
/// disabled) plus the fonts found under `font_paths`. `today` fixes the
/// date as `(year, month, day)`; otherwise the system date is used.
pub fn world(
  root? : String = ".",
  embedded_fonts? : Bool = true,
  system_fonts? : Bool = true,
  font_paths? : Array[String] = [],
  today? : (Int, Int, Int),
) -> @doc.DocWorld raise SystemError {
  let root = @platform.canonicalize(root) catch {
    err => raise SystemError("root directory not found (\{root}): \{err}")
  }
  let project = @kit.FsRoot::new(root)
  let packages = @kit.SystemPackages::new()
  let fonts = @kit.FontStore::new()
  if system_fonts {
    fonts.extend_all(@kit.system())
  }
  if embedded_fonts {
    fonts.extend_all(@kit.embedded())
  }
  for path in font_paths {
    fonts.extend_all(@kit.scan(path))
  }
  let date : (@library.Duration?) -> @library.Datetime? = match today {
    Some((year, month, day)) => {
      let date = @library.Datetime::from_ymd(year, month, day)
      _ => date
    }
    None => {
      let time = @kit.Time::system()
      offset => time.today(offset)
    }
  }
  @doc.DocWorld::new(
    load=id => {
      let fs_root = match id.root() {
        Project => project
        Package(spec) =>
          packages.obtain(spec) catch {
            err => raise @library.FileError::Package(err)
          }
      }
      fs_root.load(id.vpath())
    },
    book=fonts.book(),
    font=index => fonts.font(index),
    today=date,
  )
}

///|
/// Write bytes to a file.
pub fn write(path : String, bytes : Bytes) -> Unit raise SystemError {
  @platform.write_file(path, bytes) catch {
    err => raise SystemError("failed to write \{path}: \{err}")
  }
}

///|
/// Write text to a file as UTF-8.
pub fn write_text(path : String, text : String) -> Unit raise SystemError {
  write(path, @utf8.encode(text))
}

///|
/// Read a file.
pub fn read(path : String) -> Bytes raise SystemError {
  @platform.read_file(path) catch {
    err => raise SystemError("failed to read \{path}: \{err}")
  }
}

///|
/// A source provider for `CompileReport::review_text` and `review_html`:
/// reads the MoonBit source files below `root`, the root of the module
/// (source locations name files relative to it; default: the working
/// directory). A file that cannot be read or is no UTF-8 is not provided,
/// nor is a name that is not a plain relative path (an absolute path, a
/// drive, a `..`, a backslash). The names are the source locations that
/// the compiler recorded for the program; links inside the root are
/// followed like any other file.
pub fn sources(root? : String = ".") -> (String, String) -> String? {
  (file, _) => {
    guard !file.has_prefix("/") &&
      !file.contains("..") &&
      !file.contains("\\") &&
      !file.contains(":") else {
      return None
    }
    let path = if root == "." || root == "" { file } else { "\{root}/\{file}" }
    let bytes = @platform.read_file(path) catch { _ => return None }
    let text = @utf8.decode(bytes) catch { _ => return None }
    Some(text)
  }
}
