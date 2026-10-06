// Port of `crates/typst-syntax/src/path.rs`: virtual, cross-platform
// reproducible path handling.
//
// Real (platform) paths are handled with Unix semantics, as MoonBit's native
// target only runs on Unix-like systems for now.

///|
/// A path in a specific virtual file system root.
///
/// This identifies a location in a project or package.
pub struct RootedPath {
  priv root : VirtualRoot
  priv vpath : VirtualPath
} derive(Eq, Hash)

///|
/// Create a rooted path from a root and a virtual path within the root.
pub fn RootedPath::new(root : VirtualRoot, vpath : VirtualPath) -> RootedPath {
  { root, vpath, }
}

///|
/// Turns this path into a `FileId`.
pub fn RootedPath::intern(self : RootedPath) -> FileId {
  FileId::new(self)
}

///|
/// The root this path resides in.
pub fn RootedPath::root(self : RootedPath) -> VirtualRoot {
  self.root
}

///|
/// The absolute and normalized path to the file _within_ the project or
/// package.
pub fn RootedPath::vpath(self : RootedPath) -> VirtualPath {
  self.vpath
}

///|
/// Maps the virtual path while retaining the root.
pub fn RootedPath::map(
  self : RootedPath,
  f : (VirtualPath) -> VirtualPath,
) -> RootedPath {
  RootedPath::new(self.root, f(self.vpath))
}

///|
/// Upstream `Debug for RootedPath` (typst-syntax/src/path.rs:62); the text
/// is that of the `Show` impl below.
pub impl @debug.Debug for RootedPath with fn to_repr(self) {
  @debug.Repr::literal(self.to_string())
}

///|
/// Upstream `Debug for RootedPath`.
pub impl Show for RootedPath with fn output(self, logger) {
  match self.root {
    Project => Show::output(self.vpath, logger)
    Package(package_) => logger.write_string("\{package_}\{self.vpath}")
  }
}

///|
pub extend RootedPath with Show::{to_string, output}

///|
/// The root of a virtual file system.
pub(all) enum VirtualRoot {
  /// The canonical root of the Typst project.
  ///
  /// This is what `TYPST_ROOT` defines.
  Project
  /// A root in a package.
  Package(PackageSpec)
} derive(Eq, Hash, Debug)

///|
/// An interner for rooted paths.
priv struct Interner {
  to_id : Map[RootedPath, FileId]
  from_id : Array[RootedPath]
}

///|
/// The global interner for rooted paths.
let interner : Interner = { to_id: Map([]), from_id: [], }

///|
/// The next free file id number of the interner.
fn Interner::next_num(self : Interner) -> UInt16 {
  let num = self.from_id.length() + 1
  if num > 0xFFFF {
    abort("out of file ids")
  }
  num.to_uint16()
}

///|
/// Create a new interned file specification.
///
/// This is the same as [`RootedPath::intern`].
pub fn FileId::new(path : RootedPath) -> FileId {
  // Try to find an existing entry that we can reuse.
  if interner.to_id.get(path) is Some(id) {
    return id
  }
  let id = FileId(interner.next_num())
  interner.to_id[path] = id
  interner.from_id.push(path)
  id
}

///|
/// Create a new unique ("fake") file specification, which is not accessible
/// by path.
///
/// Caution: the ID returned by this method is the *only* identifier of the
/// file, constructing a file ID with a path will *not* reuse the ID even if
/// the path is the same. This method should only be used for generating
/// "virtual" file ids such as content read from stdin.
///
/// While the returned ID is not otherwise accessible, the provided root and
/// path still matter as they define how paths within the identified file
/// will resolve.
pub fn FileId::unique(path : RootedPath) -> FileId {
  let id = FileId(interner.next_num())
  interner.from_id.push(path)
  id
}

///|
/// Construct from a raw number.
///
/// Should only be used with numbers retrieved via
/// [`into_raw`](Self::into_raw). Misuse may results in panics.
pub fn FileId::from_raw(v : UInt16) -> FileId {
  FileId(v)
}

///|
/// Get the interned rooted path.
pub fn FileId::get(self : FileId) -> RootedPath {
  interner.from_id[self.0.to_int() - 1]
}

///|
/// The root the file resides in (upstream via `Deref<Target = RootedPath>`).
pub fn FileId::root(self : FileId) -> VirtualRoot {
  self.get().root
}

///|
/// The virtual path of the file (upstream via `Deref<Target = RootedPath>`).
pub fn FileId::vpath(self : FileId) -> VirtualPath {
  self.get().vpath
}

///|
/// A path in a virtual file system.
pub struct VirtualPath {
  priv segments : Segments
} derive(Eq, Hash)

///|
/// Creates a new virtual path.
pub fn VirtualPath::new(path : String) -> VirtualPath raise PathError {
  let segments = Segments::new()
  segments.push_components(path)
  { segments, }
}

///|
/// Creates a virtual path from a real path and a real root.
///
/// Returns an error if the file path is not contained in the root (i.e. if
/// `root_path` is not a lexical prefix of `path`). No file system operations
/// are performed.
///
/// This is the single function that translates from a real path to a virtual
/// path. Its counterpart is [`VirtualPath::realize`].
pub fn VirtualPath::virtualize(
  root_path : String,
  path : String,
) -> VirtualPath raise VirtualizeError {
  let path = match
    strip_prefix(real_components(path), real_components(root_path)) {
    Some(rest) => rest
    None => raise VirtualizeError::Path(Escapes)
  }
  let segments = Segments::new()
  for c in path {
    let comp = match c {
      RootDir => Component::Root
      CurDir => Current
      ParentDir => Parent
      Normal(string) =>
        match Segment::new(string) {
          Ok(segment) => Normal(segment)
          Err(s) => raise VirtualizeError::Invalid(s)
        }
    }
    segments.push_component(comp) catch {
      e => raise VirtualizeError::Path(e)
    }
  }
  { segments, }
}

///|
/// Turns the virtual path into an actual file system path (where the project
/// or package resides). You need to provide the appropriate `root` path,
/// relative to which this path will be resolved.
///
/// This is the single function that translates from a virtual path to a real
/// path. Its counterpart is [`VirtualPath::virtualize`].
pub fn VirtualPath::realize(
  self : VirtualPath,
  root : String,
) -> String raise RealizeError {
  let mut out = root
  for s in self.segments.iter() {
    out = path_push(out, s.realize())
  }
  out
}

///|
/// Extracts the path with a leading slash.
pub fn VirtualPath::into_with_slash(self : VirtualPath) -> String {
  self.segments.text
}

///|
/// Returns the path with a leading slash.
pub fn VirtualPath::get_with_slash(self : VirtualPath) -> String {
  self.segments.text
}

///|
/// Returns the path without a leading slash.
pub fn VirtualPath::get_without_slash(self : VirtualPath) -> String {
  self.segments.get_without_slash()
}

///|
/// Whether this is the path `/`.
pub fn VirtualPath::is_root(self : VirtualPath) -> Bool {
  self.segments.is_empty()
}

///|
/// Returns the file name portion of the path.
pub fn VirtualPath::file_name(self : VirtualPath) -> String? {
  self.segments.last().map(s => s.get())
}

///|
/// Returns the file name portion of the path without the extension.
pub fn VirtualPath::file_stem(self : VirtualPath) -> String? {
  guard self.segments.last() is Some(last) else { return None }
  let (before, after) = last.split_dot()
  if before is Some(_) {
    before
  } else {
    after
  }
}

///|
/// Returns the file extension of the path.
pub fn VirtualPath::extension(self : VirtualPath) -> String? {
  guard self.segments.last() is Some(last) else { return None }
  let (before, after) = last.split_dot()
  if before is Some(_) {
    after
  } else {
    None
  }
}

///|
/// Returns a modified path with an adjusted extension.
///
/// Panics if the resulting path segment would be invalid, e.g. because the
/// extension contains a forward or backslash.
pub fn VirtualPath::with_extension(
  self : VirtualPath,
  ext : String,
) -> VirtualPath {
  guard self.file_stem() is Some(stem) else { return self }
  let buf = "\{stem}.\{ext}"
  let segment = match Segment::new(buf) {
    Ok(segment) => segment
    Err(_) => abort("extension is invalid")
  }
  let segments = self.segments.copy()
  segments.pop() |> ignore
  segments.push(segment)
  { segments, }
}

///|
/// Returns the path with its final component removed.
///
/// Returns `None` if the path is already at the root.
pub fn VirtualPath::parent(self : VirtualPath) -> VirtualPath? {
  let segments = self.segments.copy()
  if !segments.pop() {
    return None
  }
  Some({ segments, })
}

///|
/// Joins the given `path` to `self`.
pub fn VirtualPath::join(
  self : VirtualPath,
  path : String,
) -> VirtualPath raise PathError {
  let segments = self.segments.copy()
  segments.push_components(path)
  { segments, }
}

///|
/// Expresses this path as a relative path from the given base path.
pub fn VirtualPath::relative_from(
  self : VirtualPath,
  base : VirtualPath,
) -> String {
  // Adapted from rustc's `path_relative_from` function (MIT).
  // Copyright 2012-2015 The Rust Project Developers.
  let ita = self.segments.iter()
  let itb = base.segments.iter()
  let buf : Array[String] = []
  let mut i = 0
  let mut j = 0
  while true {
    let a = ita.get(i)
    let b = itb.get(j)
    i += 1
    j += 1
    match (a, b) {
      (None, None) => break
      (Some(a), None) => {
        buf.push(a.get())
        for k in i..<ita.length() {
          buf.push(ita[k].get())
        }
        break
      }
      (None, Some(_)) => buf.push("..")
      (Some(a), Some(b)) if buf.is_empty() && a == b => ()
      (Some(a), Some(_)) => {
        for _ in 0..<(1 + itb.length() - j) {
          buf.push("..")
        }
        buf.push(a.get())
        for k in i..<ita.length() {
          buf.push(ita[k].get())
        }
        break
      }
    }
  }
  buf.join("/")
}

///|
/// Upstream `Debug for VirtualPath` (typst-syntax/src/path.rs:386); the
/// text is that of the `Show` impl below.
pub impl @debug.Debug for VirtualPath with fn to_repr(self) {
  @debug.Repr::literal(self.to_string())
}

///|
/// Upstream `Debug for VirtualPath`: the path with slash, debug-quoted.
pub impl Show for VirtualPath with fn output(self, logger) {
  logger.write_string(@unicode.rust_debug_str(self.get_with_slash()))
}

///|
pub extend VirtualPath with Show::{to_string, output}

///|
/// A component in a virtual path.
priv enum Component {
  Root
  Current
  Parent
  Normal(Segment)
}

///|
// Special symbols in virtual paths.
let path_separator : String = "/"

///|
let path_current : String = "."

///|
let path_parent : String = ".."

///|
/// Splits a user-supplied path into its constituent parts and passes them to
/// `f` one by one (upstream returns a lazy iterator; errors must surface in
/// order).
///
/// This only splits and recognizes special segments. It does not check the
/// validity of normal segments.
fn components(
  path : String,
  f : (Component) -> Unit raise PathError,
) -> Unit raise PathError {
  for i, s in path.split(path_separator).collect() {
    let s = s.to_owned()
    let comp = match s {
      // A leading separator indicates an absolute path.
      "" if i == 0 && !path.is_empty() => Component::Root
      // Consecutive separators have no effect.
      "" => Current
      "." => Current
      ".." => Parent
      other =>
        match Segment::new(other) {
          Ok(segment) => Normal(segment)
          Err("\\") => raise Backslash
          Err(_) => abort("unreachable")
        }
    }
    f(comp)
  }
}

///|
/// A segment in a normalized path.
///
/// A segments is never empty, `.`, or `..` and it never contains back- or
/// forward slashes.
priv struct Segment(String) derive(Eq)

///|
fn Segment::new(segment : String) -> Result[Segment, String] {
  // These invariants are important to avoid the path from escaping the root
  // after being realized, in particular the `..` part.
  if segment == "" || segment == path_current || segment == path_parent {
    return Err(segment)
  }

  // Interior separators or backslashes are not allowed.
  for c in segment {
    if c == '/' || c == '\\' {
      return Err(c.to_string())
    }
  }
  Ok(Segment(segment))
}

///|
fn Segment::get(self : Segment) -> String {
  self.0
}

///|
fn Segment::split_dot(self : Segment) -> (String?, String?) {
  match self.0.rev_find(".") {
    None => (None, Some(self.0))
    Some(0) => (Some(self.0), None)
    Some(i) =>
      (
        Some(self.0.unsafe_substring(start=0, end=i)),
        Some(self.0.unsafe_substring(start=i + 1, end=self.0.length())),
      )
  }
}

///|
/// Ensures that this segment can be joined to an existing platform-specific
/// path without lexically escaping the root formed by that path.
///
/// On Unix, the segment must correspond to exactly one normal path component
/// (upstream checks this through `Path::components`).
fn Segment::realize(self : Segment) -> String raise RealizeError {
  let s = self.0
  if s == "" || s == path_current || s == path_parent || s.contains("/") {
    raise RealizeError::Invalid(s)
  }
  s
}

///|
/// Stores a sequence of path segments as a string.
///
/// The underlying string always represents a normalized absolute path and is
/// guaranteed to start with a slash. Segments are never empty, `.`, or `..`
/// and they never contain back- or forward slashes.
priv struct Segments {
  mut text : String
} derive(Eq, Hash)

///|
fn Segments::new() -> Segments {
  { text: path_separator, }
}

///|
fn Segments::copy(self : Segments) -> Segments {
  { text: self.text, }
}

///|
/// Pushes all components of a user-supplied path (upstream
/// `Segments::normalize`).
fn Segments::push_components(
  self : Segments,
  path : String,
) -> Unit raise PathError {
  components(path, c => self.push_component(c))
}

///|
fn Segments::is_empty(self : Segments) -> Bool {
  self.text.length() == 1
}

///|
fn Segments::get_without_slash(self : Segments) -> String {
  self.text.unsafe_substring(start=1, end=self.text.length())
}

///|
fn Segments::clear(self : Segments) -> Unit {
  self.text = path_separator
}

///|
fn Segments::push_component(
  self : Segments,
  component : Component,
) -> Unit raise PathError {
  match component {
    // Root component resets the path.
    Component::Root => self.clear()
    // Current component has no effect.
    Current => ()
    // Parent component removes the last segment. If there is no segment,
    // this indicates that the path would escape the root. In this case, we
    // return an error.
    Parent => if !self.pop() { raise Escapes }
    Normal(segment) => self.push(segment)
  }
}

///|
fn Segments::push(self : Segments, segment : Segment) -> Unit {
  if self.is_empty() {
    self.text = self.text + segment.0
  } else {
    self.text = self.text + path_separator + segment.0
  }
}

///|
fn Segments::pop(self : Segments) -> Bool {
  if self.is_empty() {
    return false
  }
  let i = self.text.rev_find(path_separator).unwrap()
  let end = if i < 1 { 1 } else { i }
  self.text = self.text.unsafe_substring(start=0, end~)
  true
}

///|
fn Segments::last(self : Segments) -> Segment? {
  self.iter().last()
}

///|
fn Segments::iter(self : Segments) -> Array[Segment] {
  if self.is_empty() {
    return []
  }
  self
  .get_without_slash()
  .split(path_separator)
  .map(s => Segment(s.to_owned()))
  .collect()
}

///|
/// An error that can occur on construction or modification of a
/// [`VirtualPath`].
pub(all) suberror PathError {
  /// The constructed or modified path would escape the root. This would for
  /// instance, when trying to join `..` to the path `/`.
  ///
  /// Note that a path might still escape through symlinks.
  Escapes
  /// The path contains a backslash. This is not allowed as it leads to
  /// cross-platform compatibility hazards (since Windows uses backslashes as
  /// a path separator).
  Backslash
} derive(Eq, Hash, Debug)

///|
pub impl Show for PathError with fn output(self, logger) {
  match self {
    Escapes => logger.write_string("path escapes project root")
    Backslash => logger.write_string("path contains backslash")
  }
}

///|
pub extend PathError with Show::{to_string, output}

///|
/// An error that can occur in [`VirtualPath::virtualize`].
pub(all) suberror VirtualizeError {
  /// A normal path error.
  Path(PathError)
  /// A path component contained an invalid string. This should almost never
  /// occur under normal circumstances, but it could happen if some OS allows
  /// forward slashes or dots in path components.
  Invalid(String)
  /// The file path contains non-UTF-8 encodable bytes.
  Utf8
} derive(Eq, Hash, Debug)

///|
pub impl Show for VirtualizeError with fn output(self, logger) {
  match self {
    Path(inner) => Show::output(inner, logger)
    Invalid(component) =>
      logger.write_string(
        "path contains invalid component `\{@unicode.rust_debug_str(component)}`",
      )
    Utf8 => logger.write_string("path contains non-UTF-8 bytes")
  }
}

///|
pub extend VirtualizeError with Show::{to_string, output}

///|
/// An error that can occur in [`VirtualPath::realize`].
pub(all) suberror RealizeError {
  /// A virtual path component was of a form that would be specially
  /// interpreted on the current platform as opposed to designating just a
  /// file or directory.
  Invalid(String)
} derive(Eq, Hash, Debug)

///|
pub impl Show for RealizeError with fn output(self, logger) {
  match self {
    Invalid(component) =>
      logger.write_string(
        "path contains invalid component `\{@unicode.rust_debug_str(component)}`",
      )
  }
}

// Unix semantics of Rust's `std::path` used by `virtualize` and `realize`.

///|
/// A component of a real (platform) path (upstream `std::path::Component`).
priv enum RealComponent {
  RootDir
  CurDir
  ParentDir
  Normal(String)
} derive(Eq)

///|
/// Rust's `Path::components` on Unix: repeated separators and interior `.`
/// are skipped, a leading `.` is kept as `CurDir`.
fn real_components(path : String) -> Array[RealComponent] {
  let out = []
  let rooted = path.has_prefix("/")
  if rooted {
    out.push(RootDir)
  }
  for i, part in path.split("/").collect() {
    let part = part.to_owned()
    match part {
      "" => ()
      "." => if i == 0 && !rooted { out.push(CurDir) }
      ".." => out.push(ParentDir)
      p => out.push(Normal(p))
    }
  }
  out
}

///|
/// Rust's `Path::strip_prefix` on components.
fn strip_prefix(
  path : Array[RealComponent],
  base : Array[RealComponent],
) -> Array[RealComponent]? {
  if base.length() > path.length() {
    return None
  }
  for i, c in base {
    if path[i] != c {
      return None
    }
  }
  Some(path[base.length():].to_owned())
}

///|
/// Rust's `PathBuf::push` on Unix for a relative, single-component `seg`.
fn path_push(path : String, seg : String) -> String {
  if path.is_empty() || path.has_suffix("/") {
    path + seg
  } else {
    path + "/" + seg
  }
}
