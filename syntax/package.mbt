// Port of `crates/typst-syntax/src/package.rs`: package manifest parsing.
//
// Upstream deserializes manifests with serde and the `toml` crate; here a
// minimal TOML reader (`toml.mbt`) and a handwritten deserializer with
// serde's error messages are used instead. `ToolInfo` sections and unknown
// fields are kept as key lists. Errors are plain strings, like upstream's
// `EcoString` errors.

///|
/// The version of upstream Typst this is a port of (upstream
/// `typst_utils::version()`).
pub let typst_version : (Int, Int, Int) = (0, 15, 1)

///|
/// A parsed package manifest.
///
/// The `unknown_fields` contains fields which were found but not expected.
pub(all) struct PackageManifest {
  /// Details about the package itself.
  package_ : PackageInfo
  /// Details about the template, if the package is one.
  template : TemplateInfo?
  /// The tools section for third-party configuration.
  tool : ToolInfo
  /// All parsed but unknown fields, this can be used for validation.
  unknown_fields : Array[String]
}

///|
/// The `[tool]` key in the manifest. This field can be used to retrieve
/// 3rd-party tool configuration (only the section names are kept).
pub(all) struct ToolInfo {
  /// The names of the sections in the tool table.
  sections : Array[String]
}

///|
/// The `[template]` key in the manifest.
///
/// The `unknown_fields` contains fields which were found but not expected.
pub(all) struct TemplateInfo {
  /// The directory within the package that contains the files that should be
  /// copied into the user's new project directory.
  path : String
  /// A path relative to the template's path that points to the file serving
  /// as the compilation target.
  entrypoint : String
  /// A path relative to the package's root that points to a PNG or lossless
  /// WebP thumbnail for the template.
  thumbnail : String?
  /// All parsed but unknown fields, this can be used for validation.
  unknown_fields : Array[String]
}

///|
/// The `[package]` key in the manifest.
///
/// The `unknown_fields` contains fields which were found but not expected.
pub(all) struct PackageInfo {
  /// The name of the package within its namespace.
  name : String
  /// The package's version.
  version : PackageVersion
  /// The path of the entrypoint into the package.
  entrypoint : String
  /// A list of the package's authors.
  authors : Array[String]
  ///  The package's license.
  license : String?
  /// A short description of the package.
  description : String?
  /// A link to the package's web presence.
  homepage : String?
  /// A link to the repository where this package is developed.
  repository : String?
  /// An array of search keywords for the package.
  keywords : Array[String]
  /// An array with up to three of the predefined categories to help users
  /// discover the package.
  categories : Array[String]
  /// An array of disciplines defining the target audience for which the
  /// package is useful.
  disciplines : Array[String]
  /// The minimum required compiler version for the package.
  compiler : VersionBound?
  /// An array of globs specifying files that should not be part of the
  /// published bundle.
  exclude : Array[String]
  /// All parsed but unknown fields, this can be used for validation.
  unknown_fields : Array[String]
}

///|
/// Parse a manifest from TOML (upstream `toml::from_str::<PackageManifest>`).
/// The error is the `toml` crate's error message.
pub fn PackageManifest::from_toml(
  text : String,
) -> Result[PackageManifest, String] {
  try {
    let root = toml_parse(text)
    Ok(de_manifest(root))
  } catch {
    TomlError(message) => Err(message)
  }
}

///|
/// Ensure that this manifest is indeed for the specified package.
pub fn PackageManifest::validate(
  self : PackageManifest,
  spec : PackageSpec,
) -> Result[Unit, String] {
  if self.package_.name != spec.name {
    return Err(
      "package manifest contains mismatched name `\{self.package_.name}`",
    )
  }
  if self.package_.version != spec.version {
    return Err(
      "package manifest contains mismatched version \{self.package_.version}",
    )
  }
  if self.package_.compiler is Some(required) {
    let current = PackageVersion::compiler()
    if !current.matches_ge(required) {
      return Err(
        "package requires Typst \{required} or newer (current version is \{current})",
      )
    }
  }
  Ok(())
}

///|
fn de_manifest(
  root : Map[String, TomlValue],
) -> PackageManifest raise TomlError {
  let mut package_ : PackageInfo? = None
  let mut template : TemplateInfo? = None
  let mut tool = { sections: [], }
  let unknown_fields = []
  for key, value in root {
    match key {
      "package" => package_ = Some(de_package_info(value))
      "template" => template = Some(de_template_info(value))
      "tool" =>
        match value {
          TTable(t) => tool = { sections: t.keys().collect(), }
          v => raise TomlError(de_invalid_type(v, "struct ToolInfo"))
        }
      _ => unknown_fields.push(key)
    }
  }
  guard package_ is Some(package_) else { raise de_missing("package") }
  { package_, template, tool, unknown_fields, }
}

///|
fn de_package_info(value : TomlValue) -> PackageInfo raise TomlError {
  guard value is TTable(table) else {
    raise TomlError(de_invalid_type(value, "struct PackageInfo"))
  }
  let mut name : String? = None
  let mut version : PackageVersion? = None
  let mut entrypoint : String? = None
  let mut authors = []
  let mut license : String? = None
  let mut description : String? = None
  let mut homepage : String? = None
  let mut repository : String? = None
  let mut keywords = []
  let mut categories = []
  let mut disciplines = []
  let mut compiler : VersionBound? = None
  let mut exclude = []
  let unknown_fields = []
  for key, v in table {
    match key {
      "name" => name = Some(de_str(v))
      "version" =>
        version = match PackageVersion::from_str(de_str(v)) {
          Ok(version) => Some(version)
          Err(e) => raise TomlError(e)
        }
      "entrypoint" => entrypoint = Some(de_str(v))
      "authors" => authors = de_str_array(v)
      "license" => license = Some(de_str(v))
      "description" => description = Some(de_str(v))
      "homepage" => homepage = Some(de_str(v))
      "repository" => repository = Some(de_str(v))
      "keywords" => keywords = de_str_array(v)
      "categories" => categories = de_str_array(v)
      "disciplines" => disciplines = de_str_array(v)
      "compiler" =>
        compiler = match VersionBound::from_str(de_str(v)) {
          Ok(bound) => Some(bound)
          Err(e) => raise TomlError(e)
        }
      "exclude" => exclude = de_str_array(v)
      _ => unknown_fields.push(key)
    }
  }
  guard name is Some(name) else { raise de_missing("name") }
  guard version is Some(version) else { raise de_missing("version") }
  guard entrypoint is Some(entrypoint) else { raise de_missing("entrypoint") }
  {
    name,
    version,
    entrypoint,
    authors,
    license,
    description,
    homepage,
    repository,
    keywords,
    categories,
    disciplines,
    compiler,
    exclude,
    unknown_fields,
  }
}

///|
fn de_template_info(value : TomlValue) -> TemplateInfo raise TomlError {
  guard value is TTable(table) else {
    raise TomlError(de_invalid_type(value, "struct TemplateInfo"))
  }
  let mut path : String? = None
  let mut entrypoint : String? = None
  let mut thumbnail : String? = None
  let unknown_fields = []
  for key, v in table {
    match key {
      "path" => path = Some(de_str(v))
      "entrypoint" => entrypoint = Some(de_str(v))
      "thumbnail" => thumbnail = Some(de_str(v))
      _ => unknown_fields.push(key)
    }
  }
  guard path is Some(path) else { raise de_missing("path") }
  guard entrypoint is Some(entrypoint) else { raise de_missing("entrypoint") }
  { path, entrypoint, thumbnail, unknown_fields, }
}

///|
fn de_str(value : TomlValue) -> String raise TomlError {
  match value {
    TString(s) => s
    v => raise TomlError(de_invalid_type(v, "a string"))
  }
}

///|
fn de_str_array(value : TomlValue) -> Array[String] raise TomlError {
  match value {
    TArray(items) => items.map(de_str)
    v => raise TomlError(de_invalid_type(v, "a sequence"))
  }
}

///|
/// serde's `Error::invalid_type` message.
fn de_invalid_type(value : TomlValue, expected : String) -> String {
  "invalid type: \{value.unexpected()}, expected \{expected}"
}

///|
/// serde's `Error::missing_field`.
fn de_missing(field : String) -> TomlError {
  TomlError("missing field `\{field}`")
}

///|
/// Identifies a package.
pub(all) struct PackageSpec {
  /// The namespace the package lives in.
  namespace_ : String
  /// The name of the package within its namespace.
  name : String
  /// The package's version.
  version : PackageVersion
} derive(Eq, Hash)

///|
pub fn PackageSpec::versionless(self : PackageSpec) -> VersionlessPackageSpec {
  { namespace_: self.namespace_, name: self.name, }
}

///|
/// Parse a package specification like `@preview/example:0.1.0`.
pub fn PackageSpec::from_str(s : String) -> Result[PackageSpec, String] {
  let s = PkgScanner::{ text: s, cursor: 0, }
  let namespace_ = match parse_namespace(s) {
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
  Ok({ namespace_, name, version, })
}

///|
/// Upstream `Debug for PackageSpec` is its `Display`
/// (typst-syntax/src/package.rs:256).
pub impl @debug.Debug for PackageSpec with fn to_repr(self) {
  @debug.Repr::literal(self.to_string())
}

///|
pub impl Show for PackageSpec with fn output(self, logger) {
  logger.write_string("@\{self.namespace_}/\{self.name}:\{self.version}")
}

///|
pub extend PackageSpec with Show::{to_string, output}

///|
/// Identifies a package, but not a specific version of it.
pub(all) struct VersionlessPackageSpec {
  /// The namespace the package lives in.
  namespace_ : String
  /// The name of the package within its namespace.
  name : String
} derive(Eq, Hash)

///|
/// Fill in the `version` to get a complete [`PackageSpec`].
pub fn VersionlessPackageSpec::at(
  self : VersionlessPackageSpec,
  version : PackageVersion,
) -> PackageSpec {
  { namespace_: self.namespace_, name: self.name, version, }
}

///|
/// Parse a versionless package specification like `@preview/example`.
pub fn VersionlessPackageSpec::from_str(
  s : String,
) -> Result[VersionlessPackageSpec, String] {
  let s = PkgScanner::{ text: s, cursor: 0, }
  let namespace_ = match parse_namespace(s) {
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
  Ok({ namespace_, name, })
}

///|
/// Upstream `Debug for VersionlessPackageSpec` is its `Display`
/// (typst-syntax/src/package.rs:302).
pub impl @debug.Debug for VersionlessPackageSpec with fn to_repr(self) {
  @debug.Repr::literal(self.to_string())
}

///|
pub impl Show for VersionlessPackageSpec with fn output(self, logger) {
  logger.write_string("@\{self.namespace_}/\{self.name}")
}

///|
pub extend VersionlessPackageSpec with Show::{to_string, output}

///|
/// A minimal string scanner (the parts of `unscanny::Scanner` used here).
priv struct PkgScanner {
  text : String
  mut cursor : Int
}

///|
fn PkgScanner::done(self : PkgScanner) -> Bool {
  self.cursor >= self.text.length()
}

///|
fn PkgScanner::eat_if(self : PkgScanner, c : Char) -> Bool {
  if self.cursor < self.text.length() &&
    self.text.code_unit_at(self.cursor).to_int() == c.to_int() {
    self.cursor += 1
    true
  } else {
    false
  }
}

///|
fn PkgScanner::eat_until(self : PkgScanner, c : Char) -> String {
  let start = self.cursor
  while self.cursor < self.text.length() &&
        self.text.code_unit_at(self.cursor).to_int() != c.to_int() {
    self.cursor += 1
  }
  self.text.unsafe_substring(start~, end=self.cursor)
}

///|
fn PkgScanner::after(self : PkgScanner) -> String {
  self.text.unsafe_substring(start=self.cursor, end=self.text.length())
}

///|
fn parse_namespace(s : PkgScanner) -> Result[String, String] {
  if !s.eat_if('@') {
    return Err("package specification must start with '@'")
  }
  let namespace_ = s.eat_until('/')
  if namespace_.is_empty() {
    Err("package specification is missing namespace")
  } else if !is_ident(namespace_) {
    Err("`\{namespace_}` is not a valid package namespace")
  } else {
    Ok(namespace_)
  }
}

///|
fn parse_name(s : PkgScanner) -> Result[String, String] {
  s.eat_if('/') |> ignore
  let name = s.eat_until(':')
  if name.is_empty() {
    Err("package specification is missing name")
  } else if !is_ident(name) {
    Err("`\{name}` is not a valid package name")
  } else {
    Ok(name)
  }
}

///|
fn parse_version(s : PkgScanner) -> Result[PackageVersion, String] {
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
} derive(Eq, Compare, Hash)

///|
/// The current compiler version.
pub fn PackageVersion::compiler() -> PackageVersion {
  let (major, minor, patch) = typst_version
  {
    major: major.reinterpret_as_uint(),
    minor: minor.reinterpret_as_uint(),
    patch: patch.reinterpret_as_uint(),
  }
}

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
/// Upstream `Debug for PackageVersion` is its `Display`
/// (typst-syntax/src/package.rs:457).
pub impl @debug.Debug for PackageVersion with fn to_repr(self) {
  @debug.Repr::literal(self.to_string())
}

///|
pub impl Show for PackageVersion with fn output(self, logger) {
  logger.write_string("\{self.major}.\{self.minor}.\{self.patch}")
}

///|
pub extend PackageVersion with Show::{to_string, output}

///|
/// A version bound for compatibility specification.
pub(all) struct VersionBound {
  /// The bounds's major version.
  major : UInt
  /// The bounds's minor version.
  minor : UInt?
  /// The bounds's patch version. Can only be present if minor is too.
  patch : UInt?
} derive(Eq, Compare, Hash)

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
/// Upstream `Debug for VersionBound` is its `Display`
/// (typst-syntax/src/package.rs:520).
pub impl @debug.Debug for VersionBound with fn to_repr(self) {
  @debug.Repr::literal(self.to_string())
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
pub extend VersionBound with Show::{to_string, output}

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
