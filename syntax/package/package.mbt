// Port of the package specification parts of
// `crates/typst-syntax/src/package.rs`.
//
// Not ported (yet): `PackageManifest`, `ToolInfo`, `TemplateInfo`,
// `PackageInfo` (they need a TOML deserializer) and
// `PackageVersion::compiler` (needs the compiler version from typst-utils).
// Errors are plain strings, like upstream's `EcoString` errors.

///|
/// Identifies a package.
pub(all) struct PackageSpec {
  /// The namespace the package lives in.
  namespace : String
  /// The name of the package within its namespace.
  name : String
  /// The package's version.
  version : PackageVersion
} derive(Eq, Hash, Debug)

///|
pub fn PackageSpec::versionless(self : PackageSpec) -> VersionlessPackageSpec {
  { namespace: self.namespace, name: self.name, }
}

///|
/// Parse a package specification like `@preview/example:0.1.0`.
pub fn PackageSpec::from_str(s : String) -> Result[PackageSpec, String] {
  let s = Scanner::{ text: s, cursor: 0, }
  let namespace = match parse_namespace(s) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let name = match parse_name(s) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let version = match parse_version(s) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ namespace, name, version, })
}

///|
pub impl Show for PackageSpec with fn output(self, logger) {
  logger.write_string("@\{self.namespace}/\{self.name}:\{self.version}")
}

///|
/// Identifies a package, but not a specific version of it.
pub(all) struct VersionlessPackageSpec {
  /// The namespace the package lives in.
  namespace : String
  /// The name of the package within its namespace.
  name : String
} derive(Eq, Hash, Debug)

///|
/// Fill in the `version` to get a complete [`PackageSpec`].
pub fn VersionlessPackageSpec::at(
  self : VersionlessPackageSpec,
  version : PackageVersion,
) -> PackageSpec {
  { namespace: self.namespace, name: self.name, version, }
}

///|
/// Parse a versionless package specification like `@preview/example`.
pub fn VersionlessPackageSpec::from_str(
  s : String,
) -> Result[VersionlessPackageSpec, String] {
  let s = Scanner::{ text: s, cursor: 0, }
  let namespace = match parse_namespace(s) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let name = match parse_name(s) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if !s.done() {
    return Err("unexpected version in versionless package specification")
  }
  Ok({ namespace, name, })
}

///|
pub impl Show for VersionlessPackageSpec with fn output(self, logger) {
  logger.write_string("@\{self.namespace}/\{self.name}")
}

///|
/// A minimal string scanner (the parts of `unscanny::Scanner` used here).
priv struct Scanner {
  text : String
  mut cursor : Int
}

///|
fn Scanner::done(self : Scanner) -> Bool {
  self.cursor >= self.text.length()
}

///|
fn Scanner::eat_if(self : Scanner, c : Char) -> Bool {
  if self.cursor < self.text.length() &&
    self.text.code_unit_at(self.cursor).to_int() == c.to_int() {
    self.cursor += 1
    true
  } else {
    false
  }
}

///|
fn Scanner::eat_until(self : Scanner, c : Char) -> String {
  let start = self.cursor
  while self.cursor < self.text.length() &&
        self.text.code_unit_at(self.cursor).to_int() != c.to_int() {
    self.cursor += 1
  }
  self.text.unsafe_substring(start~, end=self.cursor)
}

///|
fn Scanner::after(self : Scanner) -> String {
  self.text.unsafe_substring(start=self.cursor, end=self.text.length())
}

///|
fn parse_namespace(s : Scanner) -> Result[String, String] {
  if !s.eat_if('@') {
    return Err("package specification must start with '@'")
  }
  let namespace = s.eat_until('/')
  if namespace.is_empty() {
    Err("package specification is missing namespace")
  } else if !@syntax.is_ident(namespace) {
    Err("`\{namespace}` is not a valid package namespace")
  } else {
    Ok(namespace)
  }
}

///|
fn parse_name(s : Scanner) -> Result[String, String] {
  s.eat_if('/') |> ignore
  let name = s.eat_until(':')
  if name.is_empty() {
    Err("package specification is missing name")
  } else if !@syntax.is_ident(name) {
    Err("`\{name}` is not a valid package name")
  } else {
    Ok(name)
  }
}

///|
fn parse_version(s : Scanner) -> Result[PackageVersion, String] {
  s.eat_if(':') |> ignore
  let version = s.after()
  if version.is_empty() {
    return Err("package specification is missing version")
  }
  PackageVersion::from_str(version)
}

///|
/// A package's version.
pub(all) struct PackageVersion {
  /// The package's major version.
  major : UInt
  /// The package's minor version.
  minor : UInt
  /// The package's patch version.
  patch : UInt
} derive(Eq, Compare, Hash, Debug)

///|
/// Performs an `==` match with the given version bound. Version elements
/// missing in the bound are ignored.
pub fn PackageVersion::matches_eq(
  self : PackageVersion,
  bound : VersionBound,
) -> Bool {
  self.major == bound.major &&
  (bound.minor is None || (bound.minor is Some(minor) && self.minor == minor)) &&
  (bound.patch is None || (bound.patch is Some(patch) && self.patch == patch))
}

///|
/// Performs a `>` match with the given version bound. The match only
/// succeeds if some version element in the bound is actually greater than
/// that of the version.
pub fn PackageVersion::matches_gt(
  self : PackageVersion,
  bound : VersionBound,
) -> Bool {
  if self.major != bound.major {
    return self.major > bound.major
  }
  guard bound.minor is Some(minor) else { return false }
  if self.minor != minor {
    return self.minor > minor
  }
  guard bound.patch is Some(patch) else { return false }
  if self.patch != patch {
    return self.patch > patch
  }
  false
}

///|
/// Performs a `<` match with the given version bound. The match only
/// succeeds if some version element in the bound is actually less than that
/// of the version.
pub fn PackageVersion::matches_lt(
  self : PackageVersion,
  bound : VersionBound,
) -> Bool {
  if self.major != bound.major {
    return self.major < bound.major
  }
  guard bound.minor is Some(minor) else { return false }
  if self.minor != minor {
    return self.minor < minor
  }
  guard bound.patch is Some(patch) else { return false }
  if self.patch != patch {
    return self.patch < patch
  }
  false
}

///|
/// Performs a `>=` match with the given versions. The match succeeds when
/// either a `==` or `>` match does.
pub fn PackageVersion::matches_ge(
  self : PackageVersion,
  bound : VersionBound,
) -> Bool {
  self.matches_eq(bound) || self.matches_gt(bound)
}

///|
/// Performs a `<=` match with the given versions. The match succeeds when
/// either a `==` or `<` match does.
pub fn PackageVersion::matches_le(
  self : PackageVersion,
  bound : VersionBound,
) -> Bool {
  self.matches_eq(bound) || self.matches_lt(bound)
}

///|
/// Parse a version like `0.1.0`.
pub fn PackageVersion::from_str(s : String) -> Result[PackageVersion, String] {
  let parts = s.split(".").map(p => p.to_owned())
  fn next(kind : String) -> Result[UInt, String] {
    match parts.next() {
      Some(part) if !part.is_empty() =>
        match parse_u32(part) {
          Some(v) => Ok(v)
          None => Err("`\{part}` is not a valid \{kind} version")
        }
      _ => Err("version number is missing \{kind} version")
    }
  }

  let major = match next("major") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let minor = match next("minor") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let patch = match next("patch") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if parts.next() is Some(rest) {
    return Err("version number has unexpected fourth component: `\{rest}`")
  }
  Ok({ major, minor, patch, })
}

///|
pub impl Show for PackageVersion with fn output(self, logger) {
  logger.write_string("\{self.major}.\{self.minor}.\{self.patch}")
}

///|
/// A version bound for compatibility specification.
pub(all) struct VersionBound {
  /// The bounds's major version.
  major : UInt
  /// The bounds's minor version.
  minor : UInt?
  /// The bounds's patch version. Can only be present if minor is too.
  patch : UInt?
} derive(Eq, Compare, Hash, Debug)

///|
/// Parse a version bound like `0`, `0.1` or `0.1.0`.
pub fn VersionBound::from_str(s : String) -> Result[VersionBound, String] {
  let parts = s.split(".").map(p => p.to_owned())
  fn next(kind : String) -> Result[UInt?, String] {
    match parts.next() {
      Some(part) =>
        match parse_u32(part) {
          Some(v) => Ok(Some(v))
          None => Err("`\{part}` is not a valid \{kind} version bound")
        }
      None => Ok(None)
    }
  }

  let major = match next("major") {
    Ok(Some(v)) => v
    Ok(None) => return Err("version bound is missing major version")
    Err(e) => return Err(e)
  }
  let minor = match next("minor") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let patch = match next("patch") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if parts.next() is Some(rest) {
    return Err("version bound has unexpected fourth component: `\{rest}`")
  }
  Ok({ major, minor, patch, })
}

///|
pub impl Show for VersionBound with fn output(self, logger) {
  logger.write_string(self.major.to_string())
  if self.minor is Some(minor) {
    logger.write_string(".\{minor}")
  }
  if self.patch is Some(patch) {
    logger.write_string(".\{patch}")
  }
}

///|
/// Parse an unsigned 32-bit integer like Rust's `u32::from_str`: decimal
/// digits with an optional leading `+`.
fn parse_u32(s : String) -> UInt? {
  let mut i = 0
  if s.has_prefix("+") {
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut v = 0UL
  while i < s.length() {
    let c = s.code_unit_at(i).to_int()
    guard c >= '0' && c <= '9' else { return None }
    v = v * 10UL + (c - '0').to_uint64()
    if v > 0xFFFFFFFFUL {
      return None
    }
    i += 1
  }
  Some(v.to_uint())
}
