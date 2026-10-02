// Operating-system access for the CLI and `kit`, with a native backend (C
// stub, `platform_native.mbt`) and a wasm / wasm-gc backend (moonrun host
// imports and `moonbitlang/x/fs`, `platform_wasm.mbt`).
//
// Errors carry the kind and the display text of the corresponding Rust
// `io::Error` (e.g. `No such file or directory (os error 2)`), so that
// upstream messages built from `io::Error`s can be reproduced.

///|
/// The kind of an I/O error (the subset of Rust's `io::ErrorKind` the CLI
/// distinguishes).
pub(all) enum ErrorKind {
  NotFound
  PermissionDenied
  AlreadyExists
  IsADirectory
  InvalidInput
  Unsupported
  Other
} derive(Eq, Debug)

///|
/// An I/O error: its kind and the display text of Rust's `io::Error`.
pub(all) suberror IoError {
  IoError(ErrorKind, String)
} derive(Debug)

///|
pub impl Show for IoError with fn output(self, logger) {
  let IoError(_, message) = self
  logger.write_string(message)
}

///|
/// The kind of an I/O error.
pub fn IoError::kind(self : IoError) -> ErrorKind {
  let IoError(kind, _) = self
  kind
}

///|
/// The type of a file system entry.
pub(all) enum FileKind {
  File
  Dir
  Symlink
  Other
} derive(Eq, Debug)

///|
/// The operating system the program runs on.
pub(all) enum Os {
  Linux
  MacOs
  Windows
} derive(Eq, Debug)

///|
/// The error kind of an OS error number (POSIX numbering).
fn kind_of_errno(code : Int) -> ErrorKind {
  match code {
    2 => NotFound
    1 | 13 => PermissionDenied
    17 => AlreadyExists
    21 => IsADirectory
    _ => Other
  }
}

///|
/// Creates a directory and all of its missing parents (Rust's
/// `fs::create_dir_all`).
pub fn create_dir_all(path : String) -> Unit raise IoError {
  if path == "" {
    return
  }
  if is_dir(path) {
    return
  }
  if parent(path) is Some(p) && p != "" {
    create_dir_all(p)
  }
  create_dir(path) catch {
    IoError(AlreadyExists, _) as e => if !is_dir(path) { raise e }
    e => raise e
  }
}

///|
/// Whether a path is an existing directory (following symlinks).
pub fn is_dir(path : String) -> Bool {
  (stat_kind(path) catch { _ => Other }) == Dir
}

///|
/// The parent of a path (Rust's `Path::parent`, for `/`-separated paths):
/// `None` for the root and for the empty path.
pub fn parent(path : String) -> String? {
  let trimmed = trim_trailing_separators(path)
  if trimmed == "" || trimmed == "/" {
    return None
  }
  match last_separator(trimmed) {
    None => Some("")
    Some(0) => Some("/")
    Some(i) => Some(trim_trailing_separators(trimmed[:i].to_owned()))
  }
}

///|
/// The final component of a path (Rust's `Path::file_name`, ignoring `..`).
pub fn file_name(path : String) -> String? {
  let trimmed = trim_trailing_separators(path)
  let name = match last_separator(trimmed) {
    None => trimmed
    Some(i) => trimmed[i + 1:].to_owned()
  }
  if name == "" || name == ".." {
    None
  } else {
    Some(name)
  }
}

///|
/// Joins two paths (Rust's `Path::join`: an absolute `rhs` replaces `lhs`).
pub fn join(lhs : String, rhs : String) -> String {
  if is_absolute(rhs) || lhs == "" {
    rhs
  } else if is_separator(lhs.code_unit_at(lhs.length() - 1).to_int()) {
    lhs + rhs
  } else {
    lhs + separator() + rhs
  }
}

///|
/// Whether a path is absolute.
pub fn is_absolute(path : String) -> Bool {
  if path.has_prefix("/") {
    return true
  }
  if os() == Windows && path.length() >= 3 {
    let c = path.code_unit_at(0).to_int()
    let is_letter = (c >= 'a'.to_int() && c <= 'z'.to_int()) ||
      (c >= 'A'.to_int() && c <= 'Z'.to_int())
    return is_letter &&
      path.code_unit_at(1) == ':' &&
      is_separator(path.code_unit_at(2).to_int())
  }
  path.has_prefix("\\\\")
}

///|
/// The preferred path separator.
pub fn separator() -> String {
  if os() == Windows {
    "\\"
  } else {
    "/"
  }
}

///|
fn is_separator(c : Int) -> Bool {
  c == '/'.to_int() || (c == '\\'.to_int() && os() == Windows)
}

///|
fn last_separator(path : String) -> Int? {
  for i = path.length() - 1; i >= 0; i = i - 1 {
    if is_separator(path.code_unit_at(i).to_int()) {
      return Some(i)
    }
  }
  None
}

///|
fn trim_trailing_separators(path : String) -> String {
  let mut end = path.length()
  while end > 1 && is_separator(path.code_unit_at(end - 1).to_int()) {
    end -= 1
  }
  path[:end].to_owned()
}

///|
/// Makes a path absolute against the current directory and removes `.` and
/// empty components. Used where the platform cannot canonicalize (wasm: no
/// symlink resolution). `..` components are kept, since a preceding
/// component may be a symlink: the host resolves them when the path is
/// accessed.
pub fn absolutize(path : String) -> String {
  let base = if is_absolute(path) {
    path
  } else {
    join(current_dir().unwrap_or("/"), path)
  }
  let parts : Array[String] = []
  let normalized = if os() == Windows {
    base.replace_all(old="\\", new="/")
  } else {
    base
  }
  let (prefix, rest) = if normalized.has_prefix("/") {
    ("/", normalized[1:].to_owned())
  } else {
    match normalized.find("/") {
      Some(i) => (normalized[:i + 1].to_owned(), normalized[i + 1:].to_owned())
      None => ("", normalized)
    }
  }
  for part in rest.split("/") {
    let part = part.to_owned()
    match part {
      "" | "." => ()
      _ => parts.push(part)
    }
  }
  prefix + parts.join("/")
}

///|
/// The current working directory.
pub fn current_dir() -> String? {
  @env.current_dir()
}

///|
/// An environment variable.
pub fn env_var(key : String) -> String? {
  @env.get_env_var(key)
}

///|
/// The command line arguments, without the program name.
pub fn args() -> Array[String] {
  let all = @env.args()
  if all.length() > 0 {
    all[1:].to_owned()
  } else {
    []
  }
}

///|
/// The current time in milliseconds since the UNIX epoch.
pub fn now_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
/// Exits the process with the given code (flushing the standard streams).
pub fn exit(code : Int) -> Unit {
  flush_stdout()
  flush_stderr()
  @sys.exit(code)
}
