// The wasm / wasm-gc backend of the platform layer, on top of
// `moonbitlang/x/fs` and moonrun's (unstable) host imports
// `__moonbit_io_unstable` (stdin, character output) and
// `__moonbit_sys_unstable` (`is_windows`).
//
// Limitations compared to the native backend: no ranged reads (files are
// read whole), no symlink detection or real canonicalization (paths are
// normalized lexically), no binary stdout (only UTF-8 text can be written),
// no terminal detection and no local time zone (UTC is assumed).

///|
#external
priv type ExternByteArray

///|
#external
priv type ByteArrayReadHandle

///|
fn ffi_read_bytes_from_stdin() -> ExternByteArray = "__moonbit_io_unstable" "read_bytes_from_stdin"

///|
fn ffi_write_char(fd : Int, c : Int) = "__moonbit_io_unstable" "write_char"

///|
fn ffi_flush(fd : Int) = "__moonbit_io_unstable" "flush"

///|
fn ffi_is_windows() -> Int = "__moonbit_sys_unstable" "is_windows"

///|
fn ffi_begin_read_byte_array(s : ExternByteArray) -> ByteArrayReadHandle = "__moonbit_fs_unstable" "begin_read_byte_array"

///|
fn ffi_byte_array_read_byte(handle : ByteArrayReadHandle) -> Int = "__moonbit_fs_unstable" "byte_array_read_byte"

///|
fn ffi_finish_read_byte_array(handle : ByteArrayReadHandle) = "__moonbit_fs_unstable" "finish_read_byte_array"

///|
/// Maps an `x/fs` error (moonrun reports Rust's `io::Error` display text,
/// e.g. `No such file or directory (os error 2)`) to an `IoError`.
fn fs_error(message : String, path : String) -> IoError {
  // moonrun appends the path to the message.
  let suffix = ": " + path
  let message = if message.has_suffix(suffix) {
    message[:message.length() - suffix.length()].to_owned()
  } else {
    message
  }
  let kind = match message.find("(os error ") {
    Some(i) => {
      let rest = message[i + 10:]
      let mut code = 0
      for c in rest {
        if c >= '0' && c <= '9' {
          code = code * 10 + (c.to_int() - '0'.to_int())
        } else {
          break
        }
      }
      kind_of_errno(code)
    }
    None =>
      if message.contains("No such file") || message.contains("not found") {
        NotFound
      } else if message.contains("ermission denied") {
        PermissionDenied
      } else {
        Other
      }
  }
  IoError(kind, message)
}

///|
/// Like Rust's file system APIs, rejects paths with embedded NULs.
fn check_path(path : String) -> Unit raise IoError {
  if path.contains_char('\u{0}') {
    raise IoError(InvalidInput, "file name contained an unexpected NUL byte")
  }
}

///|
/// Reads a whole file.
pub fn read_file(path : String) -> Bytes raise IoError {
  match stat_kind(path) {
    Dir => raise IoError(IsADirectory, "Is a directory (os error 21)")
    _ => ()
  }
  @fs.read_file_to_bytes(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
}

///|
/// The file most recently read by `read_range` (files can only be read
/// whole here).
let range_cache : Ref[(String, Bytes)?] = { val: None, }

///|
/// Reads up to `len` bytes at `offset` of a file.
pub fn read_range(
  path : String,
  offset : Int64,
  len : Int,
) -> Bytes raise IoError {
  let data = match range_cache.val {
    Some((p, data)) if p == path => data
    _ => {
      let data = read_file(path)
      range_cache.val = Some((path, data))
      data
    }
  }
  let start = if offset > data.length().to_int64() {
    data.length()
  } else {
    offset.to_int()
  }
  let end = if start + len > data.length() {
    data.length()
  } else {
    start + len
  }
  data[start:end].to_owned()
}

///|
/// Whether ranged reads are cheap (otherwise, `read_range` reads the whole
/// file).
pub fn supports_ranged_reads() -> Bool {
  false
}

///|
/// The size of a file in bytes.
pub fn file_size(path : String) -> Int64 raise IoError {
  read_range(path, 0L, 0) |> ignore
  match range_cache.val {
    Some((_, data)) => data.length().to_int64()
    None => 0L
  }
}

///|
/// The kind of the entry at `path`, following symlinks (`fs::metadata`).
pub fn stat_kind(path : String) -> FileKind raise IoError {
  check_path(path)
  // `is_dir` reports the host's error (e.g. not found, not a directory).
  let is_dir = @fs.is_dir(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
  let is_file = @fs.is_file(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
  if is_dir {
    Dir
  } else if is_file {
    File
  } else {
    Other
  }
}

///|
/// The kind of the entry at `path`, not following symlinks. Symlinks
/// cannot be detected here, so this is `stat_kind`.
pub fn lstat_kind(path : String) -> FileKind raise IoError {
  stat_kind(path)
}

///|
/// Canonicalizes a path. The host offers no `realpath`, so symlinks cannot
/// be resolved here: the path is made absolute and `.` components are
/// removed, but `..` components are kept for the host to resolve (see
/// `absolutize`).
pub fn canonicalize(path : String) -> String raise IoError {
  stat_kind(path) |> ignore
  absolutize(path)
}

///|
/// Writes a whole file (`fs::write`).
pub fn write_file(path : String, data : Bytes) -> Unit raise IoError {
  check_path(path)
  @fs.write_bytes_to_file(path, data) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
}

///|
/// Creates a single directory (`fs::create_dir`).
pub fn create_dir(path : String) -> Unit raise IoError {
  check_path(path)
  if @fs.path_exists(path) {
    raise IoError(AlreadyExists, "File exists (os error 17)")
  }
  @fs.create_dir(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
}

///|
/// Lists the names of the entries of a directory (`fs::read_dir`).
pub fn read_dir(path : String) -> Array[String] raise IoError {
  match stat_kind(path) {
    Dir => ()
    _ => raise IoError(Other, "Not a directory (os error 20)")
  }
  let entries = @fs.read_dir(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
  entries.to_owned()
}

///|
/// Whether a path exists (`Path::exists`).
pub fn exists(path : String) -> Bool {
  !path.contains_char('\u{0}') && @fs.path_exists(path)
}

///|
/// Writes bytes to stdout. Only UTF-8 text can be written here.
pub fn write_stdout(data : Bytes) -> Unit raise IoError {
  let text = @utf8.decode(data) catch {
    _ =>
      raise IoError(
        Unsupported,
        "binary data cannot be written to stdout on this platform",
      )
  }
  write_text(1, text)
  ffi_flush(1)
}

///|
/// Writes bytes to stdout without flushing. Only UTF-8 text can be written
/// here.
pub fn write_stdout_buffered(data : Bytes) -> Unit raise IoError {
  write_stdout(data)
}

///|
/// Whether arbitrary (non-UTF-8) bytes can be written to stdout.
pub fn supports_binary_stdout() -> Bool {
  false
}

///|
fn write_text(fd : Int, text : String) -> Unit {
  for c in text {
    ffi_write_char(fd, c.to_int())
  }
}

///|
/// Writes text to stdout (and flushes it). Output errors are not reported
/// by the host.
#warnings("-unused_error_type")
pub fn print_stdout(text : String) -> Unit raise IoError {
  write_text(1, text)
  ffi_flush(1)
}

///|
/// Writes text to stderr.
pub fn print_stderr(text : String) -> Unit {
  write_text(2, text)
}

///|
/// Flushes stdout.
pub fn flush_stdout() -> Unit {
  ffi_flush(1)
}

///|
/// Flushes stderr.
pub fn flush_stderr() -> Unit {
  ffi_flush(2)
}

///|
/// Reads all of stdin.
#warnings("-unused_error_type")
pub fn read_stdin() -> Bytes raise IoError {
  let array = ffi_read_bytes_from_stdin()
  let buf = @buffer.Buffer()
  let handle = ffi_begin_read_byte_array(array)
  while true {
    let b = ffi_byte_array_read_byte(handle)
    if b == -1 {
      break
    }
    buf.write_byte(b.to_byte())
  }
  ffi_finish_read_byte_array(handle)
  buf.to_bytes()
}

///|
/// Whether stderr is a terminal (unknown here, so `false`).
pub fn stderr_is_terminal() -> Bool {
  false
}

///|
/// The local UTC offset in seconds at a UNIX timestamp (unknown here, so
/// UTC).
pub fn local_offset(_timestamp : Int64) -> Int {
  0
}

///|
/// Whether the local time zone is known (otherwise, UTC is assumed).
pub fn knows_local_time_zone() -> Bool {
  false
}

///|
let os_cell : Ref[Os?] = { val: None, }

///|
/// The operating system. moonrun only tells whether it is Windows; macOS
/// is recognized by its system directories.
pub fn os() -> Os {
  match os_cell.val {
    Some(os) => os
    None => {
      let os = if ffi_is_windows() != 0 {
        Windows
      } else if @fs.path_exists("/System/Library/CoreServices") {
        MacOs
      } else {
        Linux
      }
      os_cell.val = Some(os)
      os
    }
  }
}

///|
/// The CPU architecture (Rust's `std::env::consts::ARCH`).
pub fn arch() -> String {
  "wasm32"
}
