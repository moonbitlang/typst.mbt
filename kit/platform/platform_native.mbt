// The native backend of the platform layer (see `platform_stub.c`).

///|
extern "C" fn ffi_last_error() -> Int = "typst_platform_last_error"

///|
extern "C" fn ffi_strerror(code : Int) -> Bytes = "typst_platform_strerror"

///|
#borrow(path)
extern "C" fn ffi_read_file(path : Bytes) -> Bytes = "typst_platform_read_file"

///|
#borrow(path)
extern "C" fn ffi_read_range(path : Bytes, offset : Int64, len : Int) -> Bytes = "typst_platform_read_range"

///|
#borrow(path)
extern "C" fn ffi_stat_kind(path : Bytes) -> Int = "typst_platform_stat_kind"

///|
#borrow(path)
extern "C" fn ffi_lstat_kind(path : Bytes) -> Int = "typst_platform_lstat_kind"

///|
#borrow(path)
extern "C" fn ffi_file_size(path : Bytes) -> Int64 = "typst_platform_file_size"

///|
#borrow(path)
extern "C" fn ffi_realpath(path : Bytes) -> Bytes = "typst_platform_realpath"

///|
#borrow(path, data)
extern "C" fn ffi_write_file(path : Bytes, data : Bytes) -> Int = "typst_platform_write_file"

///|
#borrow(path)
extern "C" fn ffi_mkdir(path : Bytes) -> Int = "typst_platform_mkdir"

///|
#borrow(data)
extern "C" fn ffi_write_fd(fd : Int, data : Bytes) -> Int = "typst_platform_write_fd"

///|
extern "C" fn ffi_flush(fd : Int) -> Int = "typst_platform_flush"

///|
extern "C" fn ffi_read_stdin() -> Bytes = "typst_platform_read_stdin"

///|
extern "C" fn ffi_isatty(fd : Int) -> Int = "typst_platform_isatty"

///|
extern "C" fn ffi_local_offset(timestamp : Int64) -> Int = "typst_platform_local_offset"

///|
extern "C" fn ffi_os() -> Int = "typst_platform_os"

///|
/// A path as a NUL-terminated C string. Like Rust's file system APIs,
/// paths with embedded NULs are rejected.
fn c_path(path : String) -> Bytes raise IoError {
  if path.contains_char('\u{0}') {
    raise IoError(InvalidInput, "file name contained an unexpected NUL byte")
  }
  @utf8.encode(path)
}

///|
/// The `io::Error` for an OS error number.
fn os_error(code : Int) -> IoError {
  let message = @utf8.decode_lossy(ffi_strerror(code))
  IoError(kind_of_errno(code), "\{message} (os error \{code})")
}

///|
fn check_last_error() -> Unit raise IoError {
  let code = ffi_last_error()
  if code != 0 {
    raise os_error(code)
  }
}

///|
/// Reads a whole file.
pub fn read_file(path : String) -> Bytes raise IoError {
  let bytes = ffi_read_file(c_path(path))
  check_last_error()
  bytes
}

///|
/// Reads up to `len` bytes at `offset` of a file.
pub fn read_range(
  path : String,
  offset : Int64,
  len : Int,
) -> Bytes raise IoError {
  let bytes = ffi_read_range(c_path(path), offset, len)
  check_last_error()
  bytes
}

///|
/// Whether ranged reads are cheap (otherwise, `read_range` reads the whole
/// file).
pub fn supports_ranged_reads() -> Bool {
  true
}

///|
/// The size of a file in bytes.
pub fn file_size(path : String) -> Int64 raise IoError {
  let size = ffi_file_size(c_path(path))
  check_last_error()
  size
}

///|
fn file_kind(code : Int) -> FileKind raise IoError {
  match code {
    1 => File
    2 => Dir
    3 => Other
    4 => Symlink
    _ => raise os_error(ffi_last_error())
  }
}

///|
/// The kind of the entry at `path`, following symlinks (`fs::metadata`).
pub fn stat_kind(path : String) -> FileKind raise IoError {
  file_kind(ffi_stat_kind(c_path(path)))
}

///|
/// The kind of the entry at `path`, not following symlinks
/// (`fs::symlink_metadata`).
pub fn lstat_kind(path : String) -> FileKind raise IoError {
  file_kind(ffi_lstat_kind(c_path(path)))
}

///|
/// Canonicalizes a path (`fs::canonicalize`).
pub fn canonicalize(path : String) -> String raise IoError {
  let bytes = ffi_realpath(c_path(path))
  check_last_error()
  let path = @utf8.decode_lossy(bytes)
  // Virtual paths are realized and virtualized with `/` separators, which
  // Windows accepts as well.
  if os() == Windows {
    path.replace_all(old="\\", new="/")
  } else {
    path
  }
}

///|
/// Writes a whole file (`fs::write`).
pub fn write_file(path : String, data : Bytes) -> Unit raise IoError {
  let code = ffi_write_file(c_path(path), data)
  if code != 0 {
    raise os_error(code)
  }
}

///|
/// Creates a single directory (`fs::create_dir`).
pub fn create_dir(path : String) -> Unit raise IoError {
  let code = ffi_mkdir(c_path(path))
  if code != 0 {
    raise os_error(code)
  }
}

///|
/// Lists the names of the entries of a directory (`fs::read_dir`).
pub fn read_dir(path : String) -> Array[String] raise IoError {
  match ffi_stat_kind(c_path(path)) {
    2 => ()
    0 => raise os_error(ffi_last_error())
    _ => raise os_error(20)
  }
  let entries = @fs.read_dir(path) catch {
    @fs.IOError(message) => raise IoError(Other, message)
  }
  entries.to_owned()
}

///|
/// Whether a path exists (`Path::exists`).
pub fn exists(path : String) -> Bool {
  let path = c_path(path) catch { _ => return false }
  ffi_stat_kind(path) != 0
}

///|
/// Writes bytes to stdout.
pub fn write_stdout(data : Bytes) -> Unit raise IoError {
  let code = ffi_write_fd(1, data)
  if code != 0 {
    raise os_error(code)
  }
  // Buffered write errors only surface when flushing.
  let code = ffi_flush(1)
  if code != 0 {
    raise os_error(code)
  }
}

///|
/// Writes bytes to stdout without flushing (like writing to Rust's locked,
/// line-buffered stdout: errors of the buffered remainder only surface when
/// it is flushed at exit, where they are ignored).
pub fn write_stdout_buffered(data : Bytes) -> Unit raise IoError {
  let code = ffi_write_fd(1, data)
  if code != 0 {
    raise os_error(code)
  }
}

///|
/// Whether arbitrary (non-UTF-8) bytes can be written to stdout.
pub fn supports_binary_stdout() -> Bool {
  true
}

///|
/// Writes text to stdout (and flushes it).
pub fn print_stdout(text : String) -> Unit raise IoError {
  write_stdout(@utf8.encode(text))
}

///|
/// Writes text to stderr.
pub fn print_stderr(text : String) -> Unit {
  ffi_write_fd(2, @utf8.encode(text)) |> ignore
}

///|
/// Flushes stdout.
pub fn flush_stdout() -> Unit {
  ffi_flush(1) |> ignore
}

///|
/// Flushes stderr.
pub fn flush_stderr() -> Unit {
  ffi_flush(2) |> ignore
}

///|
/// Reads all of stdin.
pub fn read_stdin() -> Bytes raise IoError {
  let bytes = ffi_read_stdin()
  check_last_error()
  bytes
}

///|
/// Whether stderr is a terminal.
pub fn stderr_is_terminal() -> Bool {
  ffi_isatty(2) != 0
}

///|
/// The local UTC offset in seconds (east positive) at a UNIX timestamp.
pub fn local_offset(timestamp : Int64) -> Int {
  ffi_local_offset(timestamp)
}

///|
/// Whether the local time zone is known (otherwise, UTC is assumed).
pub fn knows_local_time_zone() -> Bool {
  true
}

///|
/// The operating system.
pub fn os() -> Os {
  match ffi_os() {
    1 => MacOs
    2 => Windows
    _ => Linux
  }
}

///|
extern "C" fn ffi_arch() -> Int = "typst_platform_arch"

///|
/// The CPU architecture (Rust's `std::env::consts::ARCH`).
pub fn arch() -> String {
  match ffi_arch() {
    0 => "x86_64"
    1 => "aarch64"
    2 => "x86"
    3 => "arm"
    4 => "riscv64"
    _ => "unknown"
  }
}

///|
#borrow(code)
extern "C" fn ffi_error_kind_name(code : Int) -> Bytes = "typst_platform_error_kind_name"

///|
/// Rust's `Debug` for an `io::Error` (`Os { code: .., kind: .., message: ..
/// }` for OS errors, `Custom { kind: .., error: .. }` otherwise).
pub fn rust_debug(err : IoError) -> String {
  let IoError(_, text) = err
  match text.rev_find(" (os error ") {
    Some(i) if text.has_suffix(")") => {
      let digits = text[i + 11:text.length() - 1].to_owned()
      let mut code = 0
      for c in digits {
        code = code * 10 + (c.to_int() - '0'.to_int())
      }
      let kind = @utf8.decode_lossy(ffi_error_kind_name(code))
      let message = text[:i].to_owned()
      "Os { code: \{code}, kind: \{kind}, message: \{rust_debug_str(message)} }"
    }
    _ =>
      "Custom { kind: \{kind_name(err.kind())}, error: \{rust_debug_str(text)} }"
  }
}
