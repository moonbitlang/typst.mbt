// Port of `serde_yaml::error` (serde_yaml 0.9.34) and
// `serde_yaml::libyaml::error`.

///|
/// A position as reported by `serde_yaml::Location`: the byte index of the
/// error (libyaml's `mark.index`) and its 1-based line and column.
pub(all) struct Location {
  index : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// `serde_yaml::Error` as Typst sees it: `message` is exactly its `Display`
/// output and `location` is `error.location()`.
pub(all) suberror YamlError {
  YamlError(message~ : String, location~ : Location?)
} derive(Eq, Debug)

///|
/// A libyaml `yaml_mark_t`: 0-based byte index, line and column.
priv struct Mark {
  index : Int
  line : Int
  column : Int
}

///|
let zero_mark : Mark = { index: 0, line: 0, column: 0, }

///|
/// `impl Display for serde_yaml::libyaml::error::Mark`.
fn Mark::display(self : Mark) -> String {
  if self.line != 0 || self.column != 0 {
    "line \{self.line + 1} column \{self.column + 1}"
  } else {
    "position \{self.index}"
  }
}

///|
/// `serde_yaml::Location::from_mark`.
fn Mark::to_location(self : Mark) -> Location {
  { index: self.index, line: self.line + 1, column: self.column + 1, }
}

///|
/// `serde_yaml::libyaml::error::Error` (only what `Display` and `mark` need).
priv struct LibyamlError {
  problem : String
  problem_offset : Int
  problem_mark : Mark
  context : String?
  context_mark : Mark
}

///|
/// `impl Display for serde_yaml::libyaml::error::Error`.
fn LibyamlError::display(self : LibyamlError) -> String {
  let buf = StringBuilder()
  buf.write_string(self.problem)
  if self.problem_mark.line != 0 || self.problem_mark.column != 0 {
    buf.write_string(" at ")
    buf.write_string(self.problem_mark.display())
  } else if self.problem_offset != 0 {
    buf.write_string(" at position \{self.problem_offset}")
  }
  if self.context is Some(context) {
    buf.write_string(", ")
    buf.write_string(context)
    if (self.context_mark.line != 0 || self.context_mark.column != 0) &&
      (
        self.context_mark.line != self.problem_mark.line ||
        self.context_mark.column != self.problem_mark.column
      ) {
      buf.write_string(" at ")
      buf.write_string(self.context_mark.display())
    }
  }
  buf.to_string()
}

///|
/// `serde_yaml::error::ErrorImpl` (the variants reachable from Typst).
priv enum ErrorImpl {
  /// A serde error message, with the mark and path where it was raised once
  /// `fix_mark` filled them in.
  Message(String, (Mark, String)?)
  Libyaml(LibyamlError)
  EndOfStream
  MoreThanOneDocument
  RecursionLimitExceeded(Mark)
  RepetitionLimitExceeded
  BytesUnsupported
  UnknownAnchor(Mark)
}

///|
/// `serde_yaml::Error`.
priv suberror YError {
  YError(ErrorImpl)
}

///|
/// `serde::de::Error::custom`.
fn custom(msg : String) -> YError {
  YError(Message(msg, None))
}

///|
/// `serde_yaml::error::fix_mark`.
fn fix_mark(error : YError, mark : Mark, path : Path) -> YError {
  match error {
    YError(Message(msg, None)) =>
      YError(Message(msg, Some((mark, path.to_string()))))
    _ => error
  }
}

///|
/// `ErrorImpl::mark`.
fn ErrorImpl::mark(self : ErrorImpl) -> Mark? {
  match self {
    Message(_, Some((mark, _)))
    | RecursionLimitExceeded(mark)
    | UnknownAnchor(mark) => Some(mark)
    Libyaml(err) => Some(err.problem_mark)
    _ => None
  }
}

///|
/// `ErrorImpl::message_no_mark`.
fn ErrorImpl::message_no_mark(self : ErrorImpl) -> String {
  match self {
    Message(msg, None) => msg
    Message(msg, Some((_, path))) =>
      if path != "." {
        path + ": " + msg
      } else {
        msg
      }
    Libyaml(_) => abort("unreachable")
    EndOfStream => "EOF while parsing a value"
    MoreThanOneDocument =>
      "deserializing from YAML containing more than one document is not supported"
    RecursionLimitExceeded(_) => "recursion limit exceeded"
    RepetitionLimitExceeded => "repetition limit exceeded"
    BytesUnsupported =>
      "serialization and deserialization of bytes in YAML is not implemented"
    UnknownAnchor(_) => "unknown anchor"
  }
}

///|
/// `ErrorImpl::display`.
fn ErrorImpl::display(self : ErrorImpl) -> String {
  match self {
    Libyaml(err) => err.display()
    _ => {
      let msg = self.message_no_mark()
      match self.mark() {
        Some(mark) if mark.line != 0 || mark.column != 0 =>
          msg + " at " + mark.display()
        _ => msg
      }
    }
  }
}

///|
/// Converts an internal error into the public `YamlError`.
fn YError::to_public(self : YError) -> YamlError {
  let YError(inner) = self
  YamlError(
    message=inner.display(),
    location=inner.mark().map(fn(m) { m.to_location() }),
  )
}

///|
/// `serde::de::Unexpected` (the variants that can occur).
priv enum Unexpected {
  Str(String)
  Bytes
  Seq
  Map
  Enum
}

///|
/// `impl Display for serde::de::Unexpected`.
fn Unexpected::display(self : Unexpected) -> String {
  match self {
    Str(s) => "string " + @unicode.rust_debug_str(s)
    Bytes => "byte array"
    Seq => "sequence"
    Map => "map"
    Enum => "enum"
  }
}

///|
/// `serde::de::Error::invalid_type`.
fn invalid_type(unexp : Unexpected, exp : String) -> YError {
  custom("invalid type: \{unexp.display()}, expected \{exp}")
}

///|
/// `serde::de::Error::invalid_value`.
fn invalid_value(unexp : Unexpected, exp : String) -> YError {
  custom("invalid value: \{unexp.display()}, expected \{exp}")
}
