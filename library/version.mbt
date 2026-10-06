// Port of `typst-library/src/foundations/version.rs`.

///|
/// A version with an arbitrary number of components.
///
/// The first three components have names that can be used as fields:
/// `major`, `minor`, `patch`. All following components do not have names.
///
/// The list of components is semantically extended by an infinite list of
/// zeros. This means that, for example, `0.8` is the same as `0.8.0`. As a
/// special case, the empty version (that has no components at all) is the
/// same as `0`, `0.0`, `0.0.0`, and so on.
pub struct Version(Array[UInt]) derive(Hash)

///|
/// The names of the first three components.
let version_components : ReadOnlyArray[String] = ["major", "minor", "patch"]

///|
/// Create a new (empty) version.
pub fn Version::new() -> Version {
  Version([])
}

///|
/// Get a named component of a version.
///
/// Always non-negative. Returns `0` if the version isn't specified to the
/// necessary length.
pub fn Version::component(
  self : Version,
  name : String,
) -> Int64 raise HintedError {
  for i, c in self.0 {
    if i < version_components.length() && version_components[i] == name {
      return c.to_uint64().reinterpret_as_int64()
    }
  }
  bail("unknown version component")
}

///|
/// Push a component to the end of this version.
pub fn Version::push(self : Version, component : UInt) -> Unit {
  self.0.push(component)
}

///|
/// The values of the version.
pub fn Version::values(self : Version) -> Array[UInt] {
  self.0
}

///|
/// Creates a new version (upstream `Version::construct`).
///
/// It can have any number of components (even zero).
fn impl_version_construct(components_ : Array[VersionComponents]) -> Version {
  let version = Version::new()
  for c in components_ {
    match c {
      Single(v) => version.push(v)
      Multiple(values) =>
        for v in values {
          version.push(v)
        }
    }
  }
  version
}

///|
/// Retrieves a component of a version (upstream `Version::at`).
///
/// The returned integer is always non-negative. Returns `0` if the version
/// isn't specified to the necessary length.
fn impl_version_at(self_ : Version, index_ : Int64) -> Int64 raise HintedError {
  let mut index = index_
  if index < 0L {
    let len = self_.0.length().to_int64()
    // `checked_add` cannot overflow for a negative index.
    let pos_index = len + index
    if pos_index >= 0L {
      index = pos_index
    } else {
      bail(
        "component index out of bounds (index: \{index}, len: \{self_.0.length()})",
      )
    }
  }
  if index < self_.0.length().to_int64() {
    self_.0[index.to_int()].to_uint64().reinterpret_as_int64()
  } else {
    0L
  }
}

///|
/// Versions compare as if extended by an infinite list of zeros.
pub impl Compare for Version with fn compare(self, other) {
  let max_len = if self.0.length() > other.0.length() {
    self.0.length()
  } else {
    other.0.length()
  }
  for i in 0..<max_len {
    let l = self.0.get(i).unwrap_or(0U)
    let r = other.0.get(i).unwrap_or(0U)
    let ord = l.compare(r)
    if ord != 0 {
      return ord
    }
  }
  0
}

///|
pub extend Version with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub impl Eq for Version with fn equal(self, other) {
  self.compare(other) == 0
}

///|
/// Upstream `Display for Version`: components separated by dots.
pub fn Version::to_string(self : Version) -> String {
  self.0.map(c => c.to_string()).join(".")
}

///|
pub impl Show for Version with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Upstream `Repr for Version`.
pub fn Version::repr(self : Version) -> String {
  let parts = self.0.map(c => c.to_string())
  "version" + pretty_array_like(parts, false)
}

///|
/// One or multiple version components.
pub(all) enum VersionComponents {
  Single(UInt)
  Multiple(Array[UInt])
}

///|
pub impl Reflect for VersionComponents with fn input() {
  Union([Type(Type::int()), Type(Type::array())])
}

///|
pub impl Reflect for VersionComponents with fn output() {
  Union([Type(Type::int()), Type(Type::array())])
}

///|
pub impl Reflect for VersionComponents with fn castable(v) {
  v is (Int(_) | Array(_))
}

///|
pub extend VersionComponents with Reflect::{output, input, castable}

///|
pub impl FromValue for VersionComponents with fn from_value(v) {
  match v {
    Int(_) => {
      let c : U32 = v.cast()
      Single(c.0.to_int().reinterpret_as_uint())
    }
    Array(_) => {
      let values : Array[U32] = v.cast()
      Multiple(values.map(c => c.0.to_int().reinterpret_as_uint()))
    }
    v => raise HintedError(VersionComponents::input().error(v))
  }
}

///|
pub impl Reflect for Version with fn input() {
  Type(Type::version())
}

///|
pub impl Reflect for Version with fn output() {
  Type(Type::version())
}

///|
pub impl Reflect for Version with fn castable(v) {
  v is Version(_)
}

///|
pub extend Version with Reflect::{input, castable}

///|
pub impl IntoValue for Version with fn into_value(self) {
  Version(self)
}

///|
pub impl FromValue for Version with fn from_value(v) {
  match v {
    Version(version) => version
    v => raise HintedError(Version::input().error(v))
  }
}
