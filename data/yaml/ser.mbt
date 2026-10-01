// Port of `serde_yaml::ser` (serde_yaml 0.9.34) for the values Typst
// serializes (`impl Serialize for Value`).
//
// Typst never produces enums or tags, so the serializer's tag tracking
// (`State::CheckForTag` for single-entry maps etc.) only defers the
// mapping start event and yields the same event stream as a plain mapping.

///|
/// `serde_yaml::Serializer`: collects the emitter events.
priv struct Serializer {
  events : Array[EEvent]
  mut depth : Int
}

///|
/// `Serializer::value_start`.
fn Serializer::value_start(self : Serializer) -> Unit {
  if self.depth == 0 {
    self.events.push(EDocumentStart)
  }
  self.depth += 1
}

///|
/// `Serializer::value_end`.
fn Serializer::value_end(self : Serializer) -> Unit {
  self.depth -= 1
  if self.depth == 0 {
    self.events.push(EDocumentEnd)
  }
}

///|
/// `Serializer::emit_scalar`.
fn Serializer::emit_scalar(
  self : Serializer,
  value : String,
  style : EStyle,
) -> Unit {
  self.value_start()
  self.events.push(EScalar(@utf8.encode(value), style))
  self.value_end()
}

///|
/// `InferScalarStyle` as driven by `visit_untagged_scalar` in
/// `Serializer::serialize_str`.
fn infer_scalar_style(v : String) -> EStyle {
  if v.is_empty() || parse_null(v) {
    return SingleQuotedStyle
  }
  if parse_bool(v) is Some(_) {
    return SingleQuotedStyle
  }
  if visit_int(v) is Some(_) {
    return SingleQuotedStyle
  }
  if !digits_but_not_number(v) {
    if parse_f64(v) is Some(_) {
      return SingleQuotedStyle
    }
  }
  if digits_but_not_number(v) {
    SingleQuotedStyle
  } else {
    AnyStyle
  }
}

///|
/// `Serializer::serialize_str`.
fn Serializer::serialize_str(self : Serializer, value : String) -> Unit {
  let style = if value.contains("\n") {
    LiteralStyle
  } else {
    infer_scalar_style(value)
  }
  self.emit_scalar(value, style)
}

///|
/// `Serializer::serialize_f64`.
fn format_f64(v : Double) -> String {
  if v.is_nan() {
    ".nan"
  } else if v.is_inf() {
    if v > 0.0 {
      ".inf"
    } else {
      "-.inf"
    }
  } else {
    @serde.format_ryu(v)
  }
}

///|
/// `impl Serialize for Value` driving `serde_yaml::Serializer`.
fn Serializer::serialize(
  self : Serializer,
  value : @serde.Data,
) -> Unit raise YError {
  match value {
    None => self.emit_scalar("null", PlainStyle)
    Bool(v) => self.emit_scalar(if v { "true" } else { "false" }, PlainStyle)
    Int(v) => self.emit_scalar(v.to_string(), PlainStyle)
    Float(v) => self.emit_scalar(format_f64(v), PlainStyle)
    Str(v) => self.serialize_str(v)
    Bytes(_) => raise YError(BytesUnsupported)
    Seq(items) => {
      self.value_start()
      self.events.push(ESequenceStart)
      for item in items {
        self.serialize(item)
      }
      self.events.push(ESequenceEnd)
      self.value_end()
    }
    Map(entries) => {
      self.value_start()
      self.events.push(EMappingStart)
      for entry in entries {
        let (key, value) = entry
        self.serialize_str(key)
        self.serialize(value)
      }
      self.events.push(EMappingEnd)
      self.value_end()
    }
  }
}

///|
/// Encodes a value like upstream Typst's `yaml.encode(..)`, i.e.
/// `serde_yaml::to_string(&value)`.
pub fn to_string(value : @serde.Data) -> String raise YamlError {
  let ser : Serializer = { events: [EStreamStart], depth: 0, }
  ser.serialize(value) catch {
    err => raise err.to_public()
  }
  let output = Emitter::new(ser.events).run()
  @utf8.decode(output) catch {
    _ => abort("libyaml produced invalid UTF-8")
  }
}
