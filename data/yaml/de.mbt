// Port of `serde_yaml::loader` and `serde_yaml::de` (serde_yaml 0.9.34),
// specialized to what upstream Typst deserializes: `Value` via
// `deserialize_any` (`ValueVisitor`) and dictionary keys via
// `deserialize_str` (`EcoString`).

///|
/// `serde_yaml::de::Event`.
priv enum DeEvent {
  DAlias(Int)
  DScalar(tag~ : Bytes?, value~ : Bytes, style~ : ScalarStyle)
  DSequenceStart(Bytes?)
  DSequenceEnd
  DMappingStart(Bytes?)
  DMappingEnd
  Void
}

///|
/// `serde_yaml::loader::Document`.
priv struct Document {
  events : Array[(DeEvent, Mark)]
  mut error : ErrorImpl?
  /// Map from alias id to index in events.
  aliases : Map[Int, Int]
}

///|
/// `serde_yaml::loader::Loader`.
priv struct Loader {
  mut parser : Parser?
  mut document_count : Int
}

///|
/// `Loader::next_document`.
fn Loader::next_document(self : Loader) -> Document? {
  guard self.parser is Some(parser) else { return None }
  let first = self.document_count == 0
  self.document_count += 1
  let anchors : Map[Bytes, Int] = Map([])
  let document : Document = { events: [], error: None, aliases: {}, }
  let register = (anchor : Bytes?) => {
    if anchor is Some(anchor) {
      let id = anchors.length()
      anchors.set(anchor, id)
      document.aliases.set(id, document.events.length())
    }
  }
  while true {
    let event = match parser.next() {
      Ok(event) => event
      Err(err) => {
        document.error = Some(Libyaml(err))
        return Some(document)
      }
    }
    let mark = event.start_mark
    let ev = match event.data {
      StreamStartEvent => continue
      StreamEndEvent => {
        self.parser = None
        return if first {
          if document.events.is_empty() {
            document.events.push((Void, mark))
          }
          Some(document)
        } else {
          None
        }
      }
      DocumentStartEvent => continue
      DocumentEndEvent => return Some(document)
      AliasEvent(name) =>
        match anchors.get(name) {
          Some(id) => DAlias(id)
          None => {
            document.error = Some(UnknownAnchor(mark))
            return Some(document)
          }
        }
      ScalarEvent(anchor~, tag~, value~, style~) => {
        register(anchor)
        DScalar(tag~, value~, style~)
      }
      SequenceStartEvent(anchor~, tag~) => {
        register(anchor)
        DSequenceStart(tag)
      }
      SequenceEndEvent => DSequenceEnd
      MappingStartEvent(anchor~, tag~) => {
        register(anchor)
        DMappingStart(tag)
      }
      MappingEndEvent => DMappingEnd
    }
    document.events.push((ev, mark))
  }
  None
}

///|
/// `serde_yaml::path::Path`.
priv enum Path {
  Root
  Seq(Path, Int)
  MapKey(Path, String)
  Alias(Path)
  Unknown(Path)
}

///|
/// `impl Display for Path`'s `Parent` helper.
fn Path::parent(self : Path) -> String {
  match self {
    Root => ""
    path => path.to_string() + "."
  }
}

///|
/// `impl Display for Path`.
fn Path::to_string(self : Path) -> String {
  match self {
    Root => "."
    Seq(parent, index) => "\{parent.to_string()}[\{index}]"
    MapKey(parent, key) => parent.parent() + key
    Alias(parent) => parent.to_string()
    Unknown(parent) => parent.parent() + "?"
  }
}

///|
/// `serde_yaml::de::DeserializerFromEvents` (`current_enum` is always `None`
/// for Typst, whose visitor rejects enums).
priv struct De {
  document : Document
  pos : Ref[Int]
  jumpcount : Ref[Int]
  path : Path
  mut remaining_depth : Int
}

///|
/// `DeserializerFromEvents::peek_event_mark`.
fn De::peek_event_mark(self : De) -> (DeEvent, Mark) raise YError {
  if self.pos.val < self.document.events.length() {
    self.document.events[self.pos.val]
  } else {
    match self.document.error {
      Some(parse_error) => raise YError(parse_error)
      None => raise YError(EndOfStream)
    }
  }
}

///|
/// `DeserializerFromEvents::next_event_mark`.
fn De::next_event_mark(self : De) -> (DeEvent, Mark) raise YError {
  let result = self.peek_event_mark()
  self.pos.val += 1
  result
}

///|
/// `DeserializerFromEvents::jump`.
fn De::jump(self : De, id : Int) -> De raise YError {
  self.jumpcount.val += 1
  if self.jumpcount.val > self.document.events.length() * 100 {
    raise YError(RepetitionLimitExceeded)
  }
  match self.document.aliases.get(id) {
    Some(found) =>
      {
        document: self.document,
        pos: Ref(found),
        jumpcount: self.jumpcount,
        path: Alias(self.path),
        remaining_depth: self.remaining_depth,
      }
    None => abort("unresolved alias: \{id}")
  }
}

///|
/// A child deserializer sharing the position (`SeqAccess`/`MapAccess`).
fn De::child(self : De, path : Path) -> De {
  {
    document: self.document,
    pos: self.pos,
    jumpcount: self.jumpcount,
    path,
    remaining_depth: self.remaining_depth,
  }
}

///|
/// `serde_yaml::de::parse_tag`: the tag of an enum, if any.
fn parse_tag(libyaml_tag : Bytes?) -> String? {
  guard libyaml_tag is Some(bytes) else { return None }
  if bytes.length() > 0 && bytes[0] == b'!' {
    let bytes = if bytes.length() > 1 { bytes[1:] } else { bytes[:] }
    try @utf8.decode(bytes) catch {
      _ => None
    } noraise {
      s => Some(s)
    }
  } else {
    None
  }
}

///|
/// `str::from_utf8`.
fn from_utf8(b : Bytes) -> String? {
  try @utf8.decode(b) catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
/// `ValueVisitor::expecting`.
const TYPST_VALUE : String = "a Typst value"

///|
/// `impl Deserializer for &mut DeserializerFromEvents { fn deserialize_any }`
/// with Typst's `ValueVisitor`.
fn De::deserialize_any(self : De) -> @serde.Data raise YError {
  let (next, mark) = self.next_event_mark()
  self.deserialize_any_event(next, mark) catch {
    err => raise fix_mark(err, mark, self.path)
  }
}

///|
fn De::deserialize_any_event(
  self : De,
  next : DeEvent,
  mark : Mark,
) -> @serde.Data raise YError {
  match next {
    DAlias(id) => self.jump(id).deserialize_any()
    DScalar(tag~, value~, style~) => {
      if parse_tag(tag) is Some(_) {
        // `visitor.visit_enum(..)`, which `ValueVisitor` does not support.
        self.pos.val -= 1
        raise invalid_type(Enum, TYPST_VALUE)
      }
      visit_scalar(tag, value, style)
    }
    DSequenceStart(tag) => {
      if parse_tag(tag) is Some(_) {
        self.pos.val -= 1
        raise invalid_type(Enum, TYPST_VALUE)
      }
      self.visit_sequence(mark)
    }
    DMappingStart(tag) => {
      if parse_tag(tag) is Some(_) {
        self.pos.val -= 1
        raise invalid_type(Enum, TYPST_VALUE)
      }
      self.visit_mapping(mark)
    }
    DSequenceEnd => abort("unexpected end of sequence")
    DMappingEnd => abort("unexpected end of mapping")
    Void => None
  }
}

///|
/// `impl Deserializer for &mut DeserializerFromEvents { fn deserialize_str }`
/// with `EcoString`'s visitor (Typst's dictionary keys).
fn De::deserialize_str(self : De) -> String raise YError {
  let (next, mark) = self.next_event_mark()
  self.deserialize_str_event(next) catch {
    err => raise fix_mark(err, mark, self.path)
  }
}

///|
fn De::deserialize_str_event(self : De, next : DeEvent) -> String raise YError {
  let exp = "a string"
  match next {
    DScalar(value~, ..) =>
      match from_utf8(value) {
        Some(v) => v
        None => raise invalid_type(Bytes, exp)
      }
    DAlias(id) => self.jump(id).deserialize_str()
    DSequenceStart(_) => raise invalid_type(Seq, exp)
    DMappingStart(_) => raise invalid_type(Map, exp)
    Void => raise YError(EndOfStream)
    DSequenceEnd => abort("unexpected end of sequence")
    DMappingEnd => abort("unexpected end of mapping")
  }
}

///|
/// `DeserializerFromEvents::recursion_check` (entry part).
fn De::enter(self : De, mark : Mark) -> Int raise YError {
  let previous_depth = self.remaining_depth
  if previous_depth == 0 {
    raise YError(RecursionLimitExceeded(mark))
  }
  self.remaining_depth = previous_depth - 1
  previous_depth
}

///|
/// `DeserializerFromEvents::visit_sequence` with `ValueVisitor::visit_seq`.
fn De::visit_sequence(self : De, mark : Mark) -> @serde.Data raise YError {
  let previous_depth = self.enter(mark)
  let items = []
  let mut len = 0
  while true {
    match self.peek_event_mark() {
      (DSequenceEnd, _) | (Void, _) => break
      _ => ()
    }
    let element_de = self.child(Seq(self.path, len))
    len += 1
    items.push(element_de.deserialize_any())
  }
  self.remaining_depth = previous_depth
  // `end_sequence`: all elements were consumed.
  match self.next_event_mark() {
    (DSequenceEnd, _) | (Void, _) => ()
    _ => abort("expected a SequenceEnd event")
  }
  Seq(items)
}

///|
/// `DeserializerFromEvents::visit_mapping` with `ValueVisitor::visit_map`
/// (entries in document order, including duplicates).
fn De::visit_mapping(self : De, mark : Mark) -> @serde.Data raise YError {
  let previous_depth = self.enter(mark)
  let entries = []
  while true {
    let key_bytes = match self.peek_event_mark() {
      (DMappingEnd, _) | (Void, _) => break
      (DScalar(value~, ..), _) => Some(value)
      _ => None
    }
    let key = self.deserialize_str()
    let path = match key_bytes.bind(from_utf8) {
      Some(key) => MapKey(self.path, key)
      None => Unknown(self.path)
    }
    let value_de = self.child(path)
    entries.push((key, value_de.deserialize_any()))
  }
  self.remaining_depth = previous_depth
  // `end_mapping`: all entries were consumed.
  match self.next_event_mark() {
    (DMappingEnd, _) | (Void, _) => ()
    _ => abort("expected a MappingEnd event")
  }
  Map(entries)
}

///|
/// `serde_yaml::libyaml::tag::Tag` constants.
let tag_null : Bytes = b"tag:yaml.org,2002:null"

///|
let tag_bool : Bytes = b"tag:yaml.org,2002:bool"

///|
let tag_int : Bytes = b"tag:yaml.org,2002:int"

///|
let tag_float : Bytes = b"tag:yaml.org,2002:float"

///|
/// `serde_yaml::de::visit_scalar` with `ValueVisitor` (never tagged
/// already).
fn visit_scalar(
  tag : Bytes?,
  value : Bytes,
  style : ScalarStyle,
) -> @serde.Data raise YError {
  guard from_utf8(value) is Some(v) else {
    raise invalid_type(Bytes, TYPST_VALUE)
  }
  if tag is Some(tag) {
    if tag == tag_bool {
      return match parse_bool(v) {
        Some(b) => Bool(b)
        None => raise invalid_value(Str(v), "a boolean")
      }
    } else if tag == tag_int {
      return match visit_int(v) {
        Some(int) => int
        None => raise invalid_value(Str(v), "an integer")
      }
    } else if tag == tag_float {
      return match parse_f64(v) {
        Some(f) => Float(f)
        None => raise invalid_value(Str(v), "a float")
      }
    } else if tag == tag_null {
      return if parse_null(v) {
        None
      } else {
        raise invalid_value(Str(v), "null")
      }
    } else if tag.length() > 0 && tag[0] == b'!' && style == Plain {
      return visit_untagged_scalar(v)
    }
  } else if style == Plain {
    return visit_untagged_scalar(v)
  }
  Str(v)
}

///|
/// `serde_yaml::de::parse_null`.
fn parse_null(scalar : String) -> Bool {
  scalar is ("null" | "Null" | "NULL" | "~")
}

///|
/// `serde_yaml::de::parse_bool`.
fn parse_bool(scalar : String) -> Bool? {
  match scalar {
    "true" | "True" | "TRUE" => Some(true)
    "false" | "False" | "FALSE" => Some(false)
    _ => None
  }
}

///|
/// `str::strip_prefix`.
fn strip_prefix(s : String, prefix : String) -> String? {
  if s.has_prefix(prefix) {
    Some(s.unsafe_substring(start=prefix.length(), end=s.length()))
  } else {
    None
  }
}

///|
/// `s.starts_with(['+', '-'])`.
fn starts_with_sign(s : String) -> Bool {
  s.has_prefix("+") || s.has_prefix("-")
}

///|
/// `serde_yaml::de::parse_unsigned_int`, generic over the radix parser.
fn[T] parse_unsigned_int(
  scalar : String,
  from_str_radix : (String, Int) -> T?,
) -> T? {
  let unpositive = strip_prefix(scalar, "+").unwrap_or(scalar)
  for prefix_radix in [("0x", 16), ("0o", 8), ("0b", 2)] {
    let (prefix, radix) = prefix_radix
    if strip_prefix(unpositive, prefix) is Some(rest) {
      if starts_with_sign(rest) {
        return None
      }
      if from_str_radix(rest, radix) is Some(int) {
        return Some(int)
      }
    }
  }
  if starts_with_sign(unpositive) {
    return None
  }
  if digits_but_not_number(scalar) {
    return None
  }
  from_str_radix(unpositive, 10)
}

///|
/// `serde_yaml::de::parse_negative_int`, generic over the radix parser.
fn[T] parse_negative_int(
  scalar : String,
  from_str_radix : (String, Int) -> T?,
) -> T? {
  for prefix_radix in [("-0x", 16), ("-0o", 8), ("-0b", 2)] {
    let (prefix, radix) = prefix_radix
    if strip_prefix(scalar, prefix) is Some(rest) {
      let negative = "-" + rest
      if from_str_radix(negative, radix) is Some(int) {
        return Some(int)
      }
    }
  }
  if digits_but_not_number(scalar) {
    return None
  }
  from_str_radix(scalar, 10)
}

///|
/// `serde_yaml::de::parse_f64`.
fn parse_f64(scalar : String) -> Double? {
  let unpositive = match strip_prefix(scalar, "+") {
    Some(unpositive) => {
      if starts_with_sign(unpositive) {
        return None
      }
      unpositive
    }
    None => scalar
  }
  if unpositive is (".inf" | ".Inf" | ".INF") {
    return Some(@double.infinity)
  }
  if scalar is ("-.inf" | "-.Inf" | "-.INF") {
    return Some(@double.neg_infinity)
  }
  if scalar is (".nan" | ".NaN" | ".NAN") {
    return Some(@double.not_a_number)
  }
  if rust_parse_f64(unpositive) is Some(float) {
    if !float.is_inf() && !float.is_nan() {
      return Some(float)
    }
  }
  None
}

///|
/// `serde_yaml::de::digits_but_not_number`.
fn digits_but_not_number(scalar : String) -> Bool {
  // Leading zero(s) followed by numeric characters is a string according to
  // the YAML 1.2 spec. https://yaml.org/spec/1.2/spec.html#id2761292
  let scalar = if starts_with_sign(scalar) {
    scalar.unsafe_substring(start=1, end=scalar.length())
  } else {
    scalar
  }
  if scalar.length() <= 1 || !scalar.has_prefix("0") {
    return false
  }
  for i in 1..<scalar.length() {
    let c = scalar.code_unit_at(i)
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
/// `serde_yaml::de::visit_int` with Typst's `IntoValue` conversions.
fn visit_int(v : String) -> @serde.Data? {
  if parse_unsigned_int(v, u64_from_str_radix) is Some(int) {
    return Some(@serde.Data::from_u64(int))
  }
  if parse_negative_int(v, i64_from_str_radix) is Some(int) {
    return Some(Int(int))
  }
  if parse_unsigned_int(v, u128_from_str_radix) is Some(int) {
    return Some(int.into_data())
  }
  if parse_negative_int(v, i128_from_str_radix) is Some(int) {
    return Some(int.into_data())
  }
  None
}

///|
/// `serde_yaml::de::visit_untagged_scalar` with `ValueVisitor`.
fn visit_untagged_scalar(v : String) -> @serde.Data {
  if v.is_empty() || parse_null(v) {
    return None
  }
  if parse_bool(v) is Some(boolean) {
    return Bool(boolean)
  }
  if visit_int(v) is Some(int) {
    return int
  }
  if !digits_but_not_number(v) {
    if parse_f64(v) is Some(float) {
      return Float(float)
    }
  }
  Str(v)
}

///|
/// `serde_yaml::from_slice::<Value>` (`Deserializer::de` with
/// `deserialize_any`).
fn from_slice(input : Bytes) -> @serde.Data raise YError {
  let loader : Loader = { parser: Some(Parser::new(input)), document_count: 0, }
  let document = match loader.next_document() {
    Some(document) => document
    None => raise YError(EndOfStream)
  }
  let de : De = {
    document,
    pos: Ref(0),
    jumpcount: Ref(0),
    path: Root,
    remaining_depth: 128,
  }
  let t = de.deserialize_any()
  if document.error is Some(parse_error) {
    raise YError(parse_error)
  }
  if loader.next_document() is None {
    t
  } else {
    raise YError(MoreThanOneDocument)
  }
}

///|
/// Parses YAML like upstream Typst's `yaml(..)`, i.e.
/// `serde_yaml::from_slice::<Value>(input)`, producing the data Typst's
/// `ValueVisitor` observes. Mapping entries are returned in document order,
/// including duplicate keys (later ones replace earlier ones upstream).
pub fn parse(input : Bytes) -> @serde.Data raise YamlError {
  from_slice(input) catch {
    err => raise err.to_public()
  }
}
