// Port of `typst-library/src/foundations/path.rs`.
//
// The `path` type is upstream's `typst_syntax::RootedPath`, stored in
// `Value::Dyn`.

///|
/// A file system path (the Typst `path` type, upstream `RootedPath`).
pub using @syntax {type RootedPath}

///|
/// Creates a path from a string (upstream `RootedPath::construct`).
fn impl_rooted_path_construct(
  path : @syntax.Spanned[PathOrStr],
) -> RootedPath raise SourceError {
  at(path.span, () => path.v.resolve_if_some(path.span.id()))
}

///|
/// The repr of a path (upstream `Repr for RootedPath`).
///
/// The package spec is hard to reasonably express, but I'm also not sure
/// whether we want to expose it. For the path itself, we always use an
/// absolute one as that's the most portable representation.
pub fn repr_rooted_path(path : RootedPath) -> String {
  "path(\{repr_str(path.vpath().get_with_slash())})"
}

///|
pub impl Reflect for RootedPath with fn input() {
  Type(Type::path())
}

///|
pub impl Reflect for RootedPath with fn output() {
  Type(Type::path())
}

///|
pub impl Reflect for RootedPath with fn castable(v) {
  v is Dyn(RootedPath(_))
}

///|
pub impl IntoValue for RootedPath with fn into_value(self) {
  Dyn(RootedPath(self))
}

///|
pub impl FromValue for RootedPath with fn from_value(v) {
  match v {
    Dyn(RootedPath(path)) => path
    v => cast_fail_with(Type(Type::path()), v)
  }
}

///|
/// A string or a path.
///
/// This type is commonly accepted by functions that read from a path.
pub(all) enum PathOrStr {
  Path(RootedPath)
  Str(String)
} derive(Eq, Hash)

///|
/// Resolves this path or string relative to the file that resides at
/// `within`.
///
/// The path string may be absolute or relative. If relative, it's resolved
/// relative to the parent directory of `within` (which should point to a file
/// rather than a directory).
pub fn PathOrStr::resolve(
  self : PathOrStr,
  within : @syntax.FileId,
) -> RootedPath raise HintedError {
  match self {
    Path(v) => v
    Str(v) => {
      let root = within.root()
      let base = within.vpath()
      let resolved = try {
        match base.parent() {
          Some(parent) => parent.join(v)
          None => base.join(v)
        }
      } catch {
        err => raise HintedError(format_resolve_error(err, root, v))
      }
      @syntax.RootedPath::new(root, resolved)
    }
  }
}

///|
/// [Resolves](Self::resolve) the path if `within` is `Some(_)` or returns an
/// error that the file system could not be accessed, otherwise.
pub fn PathOrStr::resolve_if_some(
  self : PathOrStr,
  within : @syntax.FileId?,
) -> RootedPath raise HintedError {
  match within {
    Some(within) => self.resolve(within)
    None => bail("cannot access file system from here")
  }
}

///|
pub impl Reflect for PathOrStr with fn input() {
  input_of((Ty::new() : Ty[RootedPath])).union_with(
    input_of((Ty::new() : Ty[String])),
  )
}

///|
pub impl Reflect for PathOrStr with fn output() {
  output_of((Ty::new() : Ty[RootedPath])).union_with(
    output_of((Ty::new() : Ty[String])),
  )
}

///|
pub impl Reflect for PathOrStr with fn castable(v) {
  path_castable_of((Ty::new() : Ty[RootedPath]), v) ||
  path_castable_of((Ty::new() : Ty[String]), v)
}

///|
pub impl IntoValue for PathOrStr with fn into_value(self) {
  match self {
    Path(v) => IntoValue::into_value(v)
    Str(v) => IntoValue::into_value(v)
  }
}

///|
pub extend PathOrStr with IntoValue::{into_value}

///|
pub impl FromValue for PathOrStr with fn from_value(v) {
  if path_castable_of((Ty::new() : Ty[RootedPath]), v) {
    Path(v.cast())
  } else if path_castable_of((Ty::new() : Ty[String]), v) {
    Str(v.cast())
  } else {
    raise HintedError(cast_error((Ty::new() : Ty[PathOrStr]), v))
  }
}

///|
/// Whether `v` can be cast to `T` (upstream `T::castable(v)`).
fn[T : Reflect] path_castable_of(_ : Ty[T], v : Value) -> Bool {
  T::castable(v)
}

///|
/// Format the user-facing error message for path resolving.
fn format_resolve_error(
  err : @syntax.PathError,
  root : @syntax.VirtualRoot,
  path : String,
) -> HintedString {
  match err {
    Escapes => {
      let kind = match root {
        Project => "project"
        Package(_) => "package"
      }
      let diag = HintedString::new(
        "path `\{repr_str(path)}` would escape the \{kind} root",
      ).with_hint("cannot access files outside of the \{kind} sandbox")
      if root == Project {
        diag.hint("you can adjust the project root with the `--root` argument")
      }
      diag
    }
    Backslash =>
      HintedString::new("path must not contain a backslash")
      .with_hint(
        "use forward slashes instead: `\{repr_str(path.replace_all(old="\\", new="/"))}`",
      )
      .with_hint(
        "in earlier Typst versions, backslashes indicated path separators on Windows",
      )
      .with_hint("this behavior is no longer supported as it is not portable")
  }
}

///|
/// A path in bundle output.
///
/// Unlike `PathOrStr`, a string cast through this is always an absolute path
/// instead of being resolve relative to a file. This is not used for normal
/// paths in Typst files, but rather for output file paths in bundle mode.
pub struct BundlePath(@syntax.VirtualPath) derive(Eq, Hash)

///|
/// Wraps a virtual path, ensuring it has at least one component.
pub fn BundlePath::new(
  path : @syntax.VirtualPath,
) -> BundlePath raise HintedError {
  if path.is_root() {
    bail("path must have at least one component")
  }
  BundlePath(path)
}

///|
/// Extracts the contained virtual path.
pub fn BundlePath::into_inner(self : BundlePath) -> @syntax.VirtualPath {
  self.0
}

///|
pub impl Reflect for BundlePath with fn input() {
  input_of((Ty::new() : Ty[String]))
}

///|
pub impl Reflect for BundlePath with fn output() {
  output_of((Ty::new() : Ty[String]))
}

///|
pub impl Reflect for BundlePath with fn castable(v) {
  path_castable_of((Ty::new() : Ty[String]), v)
}

///|
pub impl IntoValue for BundlePath with fn into_value(self) {
  Str(self.0.into_with_slash())
}

///|
pub impl FromValue for BundlePath with fn from_value(v) {
  let v : String = v.cast()
  let path = @syntax.VirtualPath::new(v) catch {
    err => raise HintedError(format_bundle_error(err, v))
  }
  BundlePath::new(path)
}

///|
pub extend BundlePath with FromValue::{from_value}

///|
/// Format the user-facing error message for virtual path casts.
fn format_bundle_error(err : @syntax.PathError, path : String) -> HintedString {
  match err {
    Escapes =>
      HintedString::new("path `\{repr_str(path)}` would escape the bundle root")
    Backslash =>
      HintedString::new("path must not contain a backslash").with_hint(
        "use forward slashes instead: `\{repr_str(path.replace_all(old="\\", new="/"))}`",
      )
  }
}
