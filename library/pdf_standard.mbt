// Port of `PdfStandards`/`PdfStandard` and the `AttachElem` hooks of
// `typst-pdf/src/format.rs`, plus the parts of krilla's
// `configure::{version, validate}` that validate a configuration of PDF
// standards (`PdfVersion`, `Archival`, `Accessibility`, `Validator`,
// `Validators`, `ConfigurationBuilder::finish`).

// krilla `configure`.

///|
/// The version of a PDF document (krilla `PdfVersion`).
pub(all) enum PdfVersion {
  Pdf14
  Pdf15
  Pdf16
  Pdf17
  Pdf20
} derive(Eq, Hash, Compare, Debug)

///|
pub impl Default for PdfVersion with fn default() {
  Pdf17
}

///|
let pdf_version_min : PdfVersion = Pdf14

///|
let pdf_version_max : PdfVersion = Pdf20

///|
pub fn PdfVersion::as_str(self : PdfVersion) -> String {
  match self {
    Pdf14 => "PDF 1.4"
    Pdf15 => "PDF 1.5"
    Pdf16 => "PDF 1.6"
    Pdf17 => "PDF 1.7"
    Pdf20 => "PDF 2.0"
  }
}

///|
/// A PDF/A standard (krilla `Archival`).
pub(all) enum Archival {
  A1_A
  A1_B
  A2_A
  A2_B
  A2_U
  A3_A
  A3_B
  A3_U
  A4
  A4F
  A4E
} derive(Eq, Hash, Debug)

///|
pub fn Archival::as_str(self : Archival) -> String {
  match self {
    A1_A => "PDF/A-1a"
    A1_B => "PDF/A-1b"
    A2_A => "PDF/A-2a"
    A2_B => "PDF/A-2b"
    A2_U => "PDF/A-2u"
    A3_A => "PDF/A-3a"
    A3_B => "PDF/A-3b"
    A3_U => "PDF/A-3u"
    A4 => "PDF/A-4"
    A4F => "PDF/A-4f"
    A4E => "PDF/A-4e"
  }
}

///|
/// The minimum PDF version this standard supports.
pub fn Archival::min(self : Archival) -> PdfVersion? {
  match self {
    // PDF/A-1 through 3 require XMP `/Metadata` streams, which require PDF 1.4.
    A1_A | A1_B => Some(Pdf14)
    A2_A | A2_B | A2_U => Some(Pdf14)
    A3_A | A3_B | A3_U => Some(Pdf14)
    A4 | A4F | A4E => Some(Pdf20)
  }
}

///|
/// The maximum PDF version this standard supports.
pub fn Archival::max(self : Archival) -> PdfVersion {
  match self {
    A1_A | A1_B => Pdf14
    A2_A | A2_B | A2_U | A3_A | A3_B | A3_U => Pdf17
    A4 | A4F | A4E => Pdf20
  }
}

///|
/// A PDF/UA standard (krilla `Accessibility`).
pub(all) enum Accessibility {
  UA1
} derive(Eq, Hash, Debug)

///|
pub fn Accessibility::as_str(self : Accessibility) -> String {
  match self {
    UA1 => "PDF/UA-1"
  }
}

///|
pub fn Accessibility::min(self : Accessibility) -> PdfVersion? {
  match self {
    // PDF/UA-1 requires Tagged PDF and XMP `/Metadata` streams, which both
    // require PDF 1.4.
    UA1 => Some(Pdf14)
  }
}

///|
pub fn Accessibility::max(self : Accessibility) -> PdfVersion {
  match self {
    // PDF/UA-1 is specified against PDF 1.7.
    UA1 => Pdf17
  }
}

///|
/// A PDF validator for a specific conformance standard (krilla `Validator`).
pub(all) enum Validator {
  /// A PDF/A validator.
  A(Archival)
  /// A PDF/UA accessibility validator.
  Ua(Accessibility)
} derive(Eq, Hash, Debug)

///|
pub fn Validator::min(self : Validator) -> PdfVersion? {
  match self {
    A(a) => a.min()
    Ua(ua) => ua.min()
  }
}

///|
pub fn Validator::max(self : Validator) -> PdfVersion {
  match self {
    A(a) => a.max()
    Ua(ua) => ua.max()
  }
}

///|
pub fn Validator::as_str(self : Validator) -> String {
  match self {
    A(a) => a.as_str()
    Ua(ua) => ua.as_str()
  }
}

///|
/// The set of validators of a configuration (krilla `Validators`).
pub(all) struct Validators {
  a : Archival?
  ua : Accessibility?
} derive(Eq, Hash, Debug)

///|
pub fn Validators::is_empty(self : Validators) -> Bool {
  self.a is None && self.ua is None
}

///|
pub fn Validators::to_array(self : Validators) -> Array[Validator] {
  let out = []
  if self.a is Some(a) {
    out.push(Validator::A(a))
  }
  if self.ua is Some(ua) {
    out.push(Validator::Ua(ua))
  }
  out
}

///|
/// The maximum PDF version allowed by all validators.
pub fn Validators::max(self : Validators) -> PdfVersion {
  let a = match self.a {
    Some(v) => v.max()
    None => pdf_version_max
  }
  let ua = match self.ua {
    Some(v) => v.max()
    None => pdf_version_max
  }
  if a < ua {
    a
  } else {
    ua
  }
}

///|
/// The minimum PDF version required by all validators.
pub fn Validators::min(self : Validators) -> PdfVersion? {
  // Rust's `Option::max`: `None` is smaller than any `Some`.
  let a = self.a.bind(v => v.min())
  let ua = self.ua.bind(v => v.min())
  match (a, ua) {
    (Some(x), Some(y)) => Some(if x > y { x } else { y })
    (Some(x), None) | (None, Some(x)) => Some(x)
    (None, None) => None
  }
}

///|
/// Formats the validators into a comma separated list with a conjunction
/// before the last item (if more than one item exists). Uses Oxford commas.
/// (upstream `ValidatorsExt::to_and_list`)
fn Validators::to_and_list(self : Validators) -> String {
  let names = self.to_array().map(v => v.as_str())
  match names.length() {
    0 => ""
    1 => names[0]
    2 => "\{names[0]} and \{names[1]}"
    n => {
      let buf = StringBuilder()
      for i in 0..<(n - 1) {
        buf.write_string("\{names[i]}, ")
      }
      buf.write_string("and \{names[n - 1]}")
      buf.to_string()
    }
  }
}

///|
/// A configuration of validators and PDF version (krilla `Configuration`).
pub(all) struct PdfConfiguration {
  validators : Validators
  version : PdfVersion
} derive(Eq, Hash, Debug)

///|
/// An error that occurred while building a configuration (krilla
/// `ConfigurationError`).
priv enum PdfConfigurationError {
  /// The selected validators have no overlapping valid PDF version range.
  NoOverlappingValidatorsRange(Validators)
  /// The explicitly set PDF version falls outside the range allowed by the
  /// validators.
  VersionDoesNotMatchValidatorsRange(PdfVersion, Validators)
}

///|
/// Build the configuration, returning an error if the validators and version
/// are incompatible (krilla `ConfigurationBuilder::finish`).
fn pdf_configuration_finish(
  version : PdfVersion?,
  validators : Validators,
) -> Result[PdfConfiguration, PdfConfigurationError] {
  // `ValidatorsBuilder::finish`
  if validators.min().unwrap_or(pdf_version_min) > validators.max() {
    return Err(NoOverlappingValidatorsRange(validators))
  }
  let range_min = validators.min().unwrap_or(pdf_version_min)
  let range_max = validators.max()
  match version {
    Some(version) if range_min <= version && version <= range_max =>
      Ok({ validators, version, })
    Some(version) =>
      Err(VersionDoesNotMatchValidatorsRange(version, validators))
    None if !validators.is_empty() => Ok({ validators, version: range_max, })
    None => Ok({ validators, version: PdfVersion::default(), })
  }
}

// typst-pdf `format.rs`.

///|
/// Encapsulates a list of compatible PDF standards.
pub(all) struct PdfStandards {
  config : PdfConfiguration
} derive(Eq, Hash)

///|
pub impl Show for PdfStandards with fn output(_self, logger) {
  logger.write_string("PdfStandards(..)")
}

///|
pub impl Default for PdfStandards with fn default() {
  { config: { validators: { a: None, ua: None, }, version: Pdf17, }, }
}

///|
fn pdf_format_elem_standard_default() -> Value {
  PdfStandards::default().into_value()
}

///|
/// Validates a list of PDF standards for compatibility and returns their
/// encapsulated representation.
pub fn PdfStandards::new(
  list : ArrayView[PdfStandard],
) -> PdfStandards raise HintedError {
  let mut version : PdfVersion? = None
  let set_version = (v : PdfVersion) => {
    if version is Some(prev) {
      bail(
        "PDF cannot conform to \{prev.as_str()} and \{v.as_str()} at the same time",
      )
    }
    version = Some(v)
  }
  let mut archival_validator : Archival? = None
  let set_archival_validator = (a : Archival) => {
    if archival_validator is Some(_) {
      bail("choose at most one PDF/A standard")
    }
    archival_validator = Some(a)
  }
  let mut accessibility_validator : Accessibility? = None
  let set_accessibility_validator = (ua : Accessibility) => {
    if accessibility_validator is Some(_) {
      bail("choose at most one PDF/UA standard")
    }
    accessibility_validator = Some(ua)
  }
  for standard in list {
    match standard {
      V_1_4 => set_version(Pdf14)
      V_1_5 => set_version(Pdf15)
      V_1_6 => set_version(Pdf16)
      V_1_7 => set_version(Pdf17)
      V_2_0 => set_version(Pdf20)
      A_1b => set_archival_validator(A1_B)
      A_1a => set_archival_validator(A1_A)
      A_2b => set_archival_validator(A2_B)
      A_2u => set_archival_validator(A2_U)
      A_2a => set_archival_validator(A2_A)
      A_3b => set_archival_validator(A3_B)
      A_3u => set_archival_validator(A3_U)
      A_3a => set_archival_validator(A3_A)
      A_4 => set_archival_validator(A4)
      A_4f => set_archival_validator(A4F)
      A_4e => set_archival_validator(A4E)
      UA_1 => set_accessibility_validator(UA1)
    }
  }
  let validators : Validators = {
    a: archival_validator,
    ua: accessibility_validator,
  }
  match pdf_configuration_finish(version, validators) {
    Ok(config) => { config, }
    Err(e) => {
      let (message, validators) = match e {
        NoOverlappingValidatorsRange(validators) => {
          let list = validators.to_and_list()
          let message = "\{list} are mutually incompatible because they do not have any overlapping PDF versions"
          (message, validators)
        }
        VersionDoesNotMatchValidatorsRange(version, validators) => {
          let list = validators.to_and_list()
          let message = "\{version.as_str()} is not compatible with \{list}"
          (message, validators)
        }
      }
      let hinted = HintedString::new(message)
      for v in validators.to_array() {
        hinted.hint(pdf_version_hint(v))
      }
      raise HintedError(hinted)
    }
  }
}

///|
/// Returns the PDF standards.
pub fn PdfStandards::standards(self : PdfStandards) -> Array[PdfStandard] {
  [PdfStandard::from_version(self.config.version)] +
  self.config.validators.to_array().map(PdfStandard::from_validator)
}

///|
/// A hint specifying which PDF version a validator is compatible with.
fn pdf_version_hint(validator : Validator) -> String {
  let max = validator.max()
  match validator.min() {
    Some(min) =>
      if min == max {
        "\{validator.as_str()} requires version \{min.as_str()}"
      } else {
        "\{validator.as_str()} requires a version between \{min.as_str()} and \{max.as_str()}"
      }
    None => "\{validator.as_str()} requires at least \{max.as_str()}"
  }
}

///|
pub impl Reflect for PdfStandards with fn input() {
  PdfStandard::input().union_with(Type(Type::array()))
}

///|
pub impl Reflect for PdfStandards with fn output() {
  PdfStandard::output().union_with(Type(Type::array()))
}

///|
pub impl Reflect for PdfStandards with fn castable(v) {
  PdfStandard::castable(v) || v is Array(_)
}

///|
pub extend PdfStandards with Reflect::{input, castable}

///|
pub impl IntoValue for PdfStandards with fn into_value(self) {
  Array(Arr::from_array(self.standards().map(s => s.into_value())))
}

///|
pub extend PdfStandards with IntoValue::{into_value}

///|
pub impl FromValue for PdfStandards with fn from_value(v) {
  match v {
    v if PdfStandard::castable(v) => PdfStandards::new([v.cast()])
    Array(values) => {
      let list : Array[PdfStandard] = []
      for value in values.iter() {
        list.push(value.cast())
      }
      PdfStandards::new(list)
    }
    v => raise HintedError(PdfStandards::input().error(v))
  }
}

///|
/// A PDF standard that Typst can enforce conformance with.
///
/// Support for more standards is planned.
pub(all) enum PdfStandard {
  /// PDF 1.4.
  V_1_4
  /// PDF 1.5.
  V_1_5
  /// PDF 1.6.
  V_1_6
  /// PDF 1.7.
  V_1_7
  /// PDF 2.0.
  V_2_0
  /// PDF/A-1b.
  A_1b
  /// PDF/A-1a.
  A_1a
  /// PDF/A-2b.
  A_2b
  /// PDF/A-2u.
  A_2u
  /// PDF/A-2a.
  A_2a
  /// PDF/A-3b.
  A_3b
  /// PDF/A-3u.
  A_3u
  /// PDF/A-3a.
  A_3a
  /// PDF/A-4.
  A_4
  /// PDF/A-4f.
  A_4f
  /// PDF/A-4e.
  A_4e
  /// PDF/UA-1.
  UA_1
} derive(Eq, Hash, Debug)

///|
let pdf_standard_casts : ReadOnlyArray[(String, PdfStandard, String)] = [
  ("1.4", V_1_4, "PDF 1.4."),
  ("1.5", V_1_5, "PDF 1.5."),
  ("1.6", V_1_6, "PDF 1.6."),
  ("1.7", V_1_7, "PDF 1.7."),
  ("2.0", V_2_0, "PDF 2.0."),
  ("a-1b", A_1b, "PDF/A-1b."),
  ("a-1a", A_1a, "PDF/A-1a."),
  ("a-2b", A_2b, "PDF/A-2b."),
  ("a-2u", A_2u, "PDF/A-2u."),
  ("a-2a", A_2a, "PDF/A-2a."),
  ("a-3b", A_3b, "PDF/A-3b."),
  ("a-3u", A_3u, "PDF/A-3u."),
  ("a-3a", A_3a, "PDF/A-3a."),
  ("a-4", A_4, "PDF/A-4."),
  ("a-4f", A_4f, "PDF/A-4f."),
  ("a-4e", A_4e, "PDF/A-4e."),
  ("ua-1", UA_1, "PDF/UA-1."),
]

///|
fn PdfStandard::from_version(value : PdfVersion) -> PdfStandard {
  match value {
    Pdf14 => V_1_4
    Pdf15 => V_1_5
    Pdf16 => V_1_6
    Pdf17 => V_1_7
    Pdf20 => V_2_0
  }
}

///|
fn PdfStandard::from_validator(value : Validator) -> PdfStandard {
  match value {
    A(archival) =>
      match archival {
        A1_A => A_1a
        A1_B => A_1b
        A2_A => A_2a
        A2_B => A_2b
        A2_U => A_2u
        A3_A => A_3a
        A3_B => A_3b
        A3_U => A_3u
        A4 => A_4
        A4F => A_4f
        A4E => A_4e
      }
    Ua(accessibility) =>
      match accessibility {
        UA1 => UA_1
      }
  }
}

///|
pub impl Reflect for PdfStandard with fn input() {
  let mut info : CastInfo? = None
  for entry in pdf_standard_casts[:] {
    let next = CastInfo::Value(Str(entry.0), entry.2)
    info = Some(
      match info {
        None => next
        Some(info) => info.union_with(next)
      },
    )
  }
  info.unwrap()
}

///|
pub impl Reflect for PdfStandard with fn output() {
  PdfStandard::input()
}

///|
pub impl Reflect for PdfStandard with fn castable(v) {
  match v {
    Str(s) => pdf_standard_casts.iter().any(entry => entry.0 == s)
    _ => false
  }
}

///|
pub extend PdfStandard with Reflect::{output, input, castable}

///|
pub impl IntoValue for PdfStandard with fn into_value(self) {
  for entry in pdf_standard_casts[:] {
    if entry.1 == self {
      return Str(entry.0)
    }
  }
  abort("unreachable")
}

///|
pub extend PdfStandard with IntoValue::{into_value}

///|
pub impl FromValue for PdfStandard with fn from_value(v) {
  if v is Str(s) {
    for entry in pdf_standard_casts[:] {
      if entry.0 == s {
        return entry.1
      }
    }
  }
  raise HintedError(PdfStandard::input().error(v))
}

// AttachElem

///|
/// `#[parse]` of `AttachElem::path`. The resolved path and the path's span
/// are shared with the parser of `data` (upstream binds them as locals).
fn pdf_attach_elem_path_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let { v: path, span, } : @syntax.Spanned[PathOrStr] = args.expect_spanned(
    "path",
  )
  let resolved = at(span, () => path.resolve_if_some(span.id()))
  locals.set("resolved", Some(Dyn(RootedPath(resolved))))
  locals.set("span", Some(Int(span.0.reinterpret_as_int64())))
  // The derived part (the virtual-root-relative resolved path) is not stored.
  Some(path.into_value())
}

///|
/// `#[parse]` of `AttachElem::data`.
fn pdf_attach_elem_data_parse(
  engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  match args.eat() {
    Some((data : BytesValue)) => Some(Bytes(data))
    None => {
      guard locals.get("resolved") is Some(Dyn(RootedPath(resolved))) &&
        locals.get("span") is Some(Int(span)) else {
        abort("attach: path must be parsed before data")
      }
      let span = @syntax.Span(span.reinterpret_as_uint64())
      let data = at(span, () => {
        engine.world.file(resolved.intern()) catch {
          error => bail(error.to_string())
        }
      })
      Some(Bytes(BytesValue(data)))
    }
  }
}

///|
/// The relationship of an attached file with the document.
pub(all) enum AttachedFileRelationship {
  /// The PDF document was created from the source file.
  Source
  /// The file was used to derive a visual presentation in the PDF.
  Data
  /// An alternative representation of the document.
  Alternative
  /// Additional resources for the document.
  Supplement
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for AttachedFileRelationship with fn input() {
  Union([
    Value(Str("source"), "The PDF document was created from the source file."),
    Value(
      Str("data"),
      "The file was used to derive a visual presentation in the PDF.",
    ),
    Value(Str("alternative"), "An alternative representation of the document."),
    Value(Str("supplement"), "Additional resources for the document."),
  ])
}

///|
pub impl Reflect for AttachedFileRelationship with fn output() {
  AttachedFileRelationship::input()
}

///|
pub impl Reflect for AttachedFileRelationship with fn castable(v) {
  v is Str("source" | "data" | "alternative" | "supplement")
}

///|
pub extend AttachedFileRelationship with Reflect::{output, input, castable}

///|
pub impl IntoValue for AttachedFileRelationship with fn into_value(self) {
  match self {
    Source => Str("source")
    Data => Str("data")
    Alternative => Str("alternative")
    Supplement => Str("supplement")
  }
}

///|
pub impl FromValue for AttachedFileRelationship with fn from_value(v) {
  match v {
    Str("source") => Source
    Str("data") => Data
    Str("alternative") => Alternative
    Str("supplement") => Supplement
    v => raise HintedError(AttachedFileRelationship::input().error(v))
  }
}
