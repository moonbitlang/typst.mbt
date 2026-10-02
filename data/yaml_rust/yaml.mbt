// Port of `yaml_rust::yaml` (yaml-rust 0.4.5).

///|
/// A YAML node is stored as this `Yaml` enumeration, which provides an easy way to
/// access your YAML document.
///
/// `Show` produces Rust's `{:?}` (derived `Debug`) text, e.g.
/// `Hash({String("a"): Integer(1)})`.
pub(all) enum Yaml {
  /// Float types are stored as String and parsed on demand.
  Real(String)
  /// YAML int is stored as i64.
  Integer(Int64)
  /// YAML scalar.
  String(String)
  /// YAML bool, e.g. `true` or `false`.
  Boolean(Bool)
  /// YAML array, can be accessed as an `Array`.
  Array(Array[Yaml])
  /// YAML hash, can be accessed as a `LinkedHashMap`.
  ///
  /// Insertion order will match the order of insertion into the map.
  Hash(LinkedHashMap[Yaml, Yaml])
  /// Alias, not fully supported yet.
  Alias(Int)
  /// YAML null, e.g. `null` or `~`.
  Null
  /// Accessing a nonexistent node via indexing returns `BadValue`. This
  /// simplifies error handling in the calling code. Invalid type conversion also
  /// returns `BadValue`.
  BadValue
} derive(Eq, Hash, Debug)

///|
/// `yaml_rust::yaml::Hash`.
pub fn new_hash() -> LinkedHashMap[Yaml, Yaml] {
  LinkedHashMap::new()
}

///|
/// parse f64 as Core schema
/// See: https://github.com/chyh1990/yaml-rust/issues/51
fn parse_f64(v : String) -> Double? {
  match v {
    ".inf" | ".Inf" | ".INF" | "+.inf" | "+.Inf" | "+.INF" =>
      Some(@double.infinity)
    "-.inf" | "-.Inf" | "-.INF" => Some(@double.neg_infinity)
    ".nan" | "NaN" | ".NAN" => Some(@double.not_a_number)
    _ => rust_parse_f64(v)
  }
}

///|
pub struct YamlLoader {
  priv docs : Array[Yaml]
  // states
  // (current node, anchor_id) tuple
  priv doc_stack : Array[(Yaml, Int)]
  priv key_stack : Array[Yaml]
  priv anchor_map : Map[Int, Yaml]
}

///|
pub impl MarkedEventReceiver for YamlLoader with fn on_event(self, ev, _) {
  match ev {
    DocumentStart => () // do nothing
    DocumentEnd =>
      match self.doc_stack.length() {
        // empty document
        0 => self.docs.push(BadValue)
        1 => self.docs.push(self.doc_stack.unsafe_pop().0)
        _ => panic()
      }
    SequenceStart(aid) => self.doc_stack.push((Array([]), aid))
    SequenceEnd => {
      let node = self.doc_stack.unsafe_pop()
      self.insert_new_node(node)
    }
    MappingStart(aid) => {
      self.doc_stack.push((Hash(LinkedHashMap::new()), aid))
      self.key_stack.push(BadValue)
    }
    MappingEnd => {
      self.key_stack.unsafe_pop() |> ignore
      let node = self.doc_stack.unsafe_pop()
      self.insert_new_node(node)
    }
    Scalar(v, style, aid, tag) => {
      let node = if style != Plain {
        String(v)
      } else if tag is Some(Tag(handle, suffix)) {
        // XXX tag:yaml.org,2002:
        if handle == "!!" {
          match suffix {
            "bool" =>
              // "true" or "false"
              match v {
                "true" => Boolean(true)
                "false" => Boolean(false)
                _ => BadValue
              }
            "int" =>
              match i64_from_str_radix(v, 10) {
                None => BadValue
                Some(v) => Integer(v)
              }
            "float" =>
              match parse_f64(v) {
                Some(_) => Real(v)
                None => BadValue
              }
            "null" =>
              match v {
                "~" | "null" => Null
                _ => BadValue
              }
            _ => String(v)
          }
        } else {
          String(v)
        }
      } else {
        // Datatype is not specified, or unrecognized
        Yaml::from_str(v)
      }
      self.insert_new_node((node, aid))
    }
    Alias(id) => {
      let n = match self.anchor_map.get(id) {
        Some(v) => v
        None => BadValue
      }
      self.insert_new_node((n, 0))
    }
    _ => () // ignore
  }
}

///|
fn YamlLoader::insert_new_node(self : YamlLoader, node : (Yaml, Int)) -> Unit {
  // valid anchor id starts from 1
  if node.1 > 0 {
    self.anchor_map.set(node.1, node.0)
  }
  if self.doc_stack.is_empty() {
    self.doc_stack.push(node)
  } else {
    let parent = self.doc_stack[self.doc_stack.length() - 1]
    match parent {
      (Array(v), _) => v.push(node.0)
      (Hash(h), _) => {
        let last = self.key_stack.length() - 1
        let cur_key = self.key_stack[last]
        // current node is a key
        if cur_key.is_badvalue() {
          self.key_stack[last] = node.0
          // current node is a value
        } else {
          self.key_stack[last] = BadValue
          h.insert(cur_key, node.0) |> ignore
        }
      }
      _ => panic()
    }
  }
}

///|
/// Loads all documents of `source`.
pub fn YamlLoader::load_from_str(
  source : String,
) -> Array[Yaml] raise ScanError {
  let loader : YamlLoader = {
    docs: [],
    doc_stack: [],
    key_stack: [],
    anchor_map: {},
  }
  let parser = Parser::new(source)
  parser.load(loader, true)
  loader.docs
}

///|
pub fn Yaml::as_bool(self : Yaml) -> Bool? {
  match self {
    Boolean(v) => Some(v)
    _ => None
  }
}

///|
pub fn Yaml::as_i64(self : Yaml) -> Int64? {
  match self {
    Integer(v) => Some(v)
    _ => None
  }
}

///|
pub fn Yaml::as_str(self : Yaml) -> String? {
  match self {
    String(v) => Some(v)
    _ => None
  }
}

///|
pub fn Yaml::as_hash(self : Yaml) -> LinkedHashMap[Yaml, Yaml]? {
  match self {
    Hash(v) => Some(v)
    _ => None
  }
}

///|
pub fn Yaml::as_vec(self : Yaml) -> Array[Yaml]? {
  match self {
    Array(v) => Some(v)
    _ => None
  }
}

///|
pub fn Yaml::into_bool(self : Yaml) -> Bool? {
  self.as_bool()
}

///|
pub fn Yaml::into_i64(self : Yaml) -> Int64? {
  self.as_i64()
}

///|
pub fn Yaml::into_string(self : Yaml) -> String? {
  self.as_str()
}

///|
pub fn Yaml::into_hash(self : Yaml) -> LinkedHashMap[Yaml, Yaml]? {
  self.as_hash()
}

///|
pub fn Yaml::into_vec(self : Yaml) -> Array[Yaml]? {
  self.as_vec()
}

///|
pub fn Yaml::is_null(self : Yaml) -> Bool {
  self is Null
}

///|
pub fn Yaml::is_badvalue(self : Yaml) -> Bool {
  self is BadValue
}

///|
pub fn Yaml::is_array(self : Yaml) -> Bool {
  self is Array(_)
}

///|
pub fn Yaml::as_f64(self : Yaml) -> Double? {
  match self {
    Real(v) => parse_f64(v)
    _ => None
  }
}

///|
pub fn Yaml::into_f64(self : Yaml) -> Double? {
  self.as_f64()
}

///|
/// Not implementing FromStr because there is no possibility of Error.
/// This function falls back to Yaml::String if nothing else matches.
pub fn Yaml::from_str(v : String) -> Yaml {
  if v.has_prefix("0x") {
    if i64_from_str_radix(v.unsafe_substring(start=2, end=v.length()), 16)
      is Some(i) {
      return Integer(i)
    }
  }
  if v.has_prefix("0o") {
    if i64_from_str_radix(v.unsafe_substring(start=2, end=v.length()), 8)
      is Some(i) {
      return Integer(i)
    }
  }
  if v.has_prefix("+") {
    if i64_from_str_radix(v.unsafe_substring(start=1, end=v.length()), 10)
      is Some(i) {
      return Integer(i)
    }
  }
  match v {
    "~" | "null" => Null
    "true" => Boolean(true)
    "false" => Boolean(false)
    _ =>
      if i64_from_str_radix(v, 10) is Some(i) {
        Integer(i)
      } else if parse_f64(v) is Some(_) {
        // try parsing as f64
        Real(v)
      } else {
        String(v)
      }
  }
}

///|
/// Index types of `Yaml` (upstream's `Index<&str>` and `Index<usize>`).
pub(open) trait YamlIndex {
  fn index_into(Self, Yaml) -> Yaml
}

///|
/// `yaml[key]`: the value of `Yaml::String(key)` in a hash, else `BadValue`.
pub impl YamlIndex for String with fn index_into(self, yaml) {
  let key = Yaml::String(self)
  match yaml.as_hash() {
    Some(h) => h.get(key).unwrap_or(BadValue)
    None => BadValue
  }
}

///|
/// `yaml[idx]`: the element of an array, or the value of `Yaml::Integer(idx)`
/// in a hash, else `BadValue`.
pub impl YamlIndex for Int with fn index_into(self, yaml) {
  if yaml.as_vec() is Some(v) {
    if self >= 0 && self < v.length() {
      v[self]
    } else {
      BadValue
    }
  } else if yaml.as_hash() is Some(v) {
    let key = Yaml::Integer(self.to_int64())
    v.get(key).unwrap_or(BadValue)
  } else {
    BadValue
  }
}

///|
/// `yaml["key"]` / `yaml[0]`; never fails, returns `BadValue` instead.
#alias("_[_]")
pub fn[I : YamlIndex] Yaml::at(self : Yaml, idx : I) -> Yaml {
  idx.index_into(self)
}

///|
/// `IntoIterator for Yaml`: the elements of an array, else nothing.
pub fn Yaml::into_iter(self : Yaml) -> Iter[Yaml] {
  self.into_vec().unwrap_or([]).iter()
}

///|
/// Rust's derived `Debug`.
pub impl Show for Yaml with fn output(self, logger) {
  match self {
    Real(v) => {
      logger.write_string("Real(")
      logger.write_string(@unicode.rust_debug_str(v))
      logger.write_char(')')
    }
    Integer(v) => logger.write_string("Integer(\{v})")
    String(v) => {
      logger.write_string("String(")
      logger.write_string(@unicode.rust_debug_str(v))
      logger.write_char(')')
    }
    Boolean(v) => logger.write_string("Boolean(\{v})")
    Array(v) => {
      logger.write_string("Array([")
      for i, x in v {
        if i > 0 {
          logger.write_string(", ")
        }
        Show::output(x, logger)
      }
      logger.write_string("])")
    }
    Hash(h) => {
      logger.write_string("Hash(")
      Show::output(h, logger)
      logger.write_char(')')
    }
    Alias(v) => logger.write_string("Alias(\{v})")
    Null => logger.write_string("Null")
    BadValue => logger.write_string("BadValue")
  }
}

///|
fn Yaml::variant_index(self : Yaml) -> Int {
  match self {
    Real(_) => 0
    Integer(_) => 1
    String(_) => 2
    Boolean(_) => 3
    Array(_) => 4
    Hash(_) => 5
    Alias(_) => 6
    Null => 7
    BadValue => 8
  }
}

///|
/// Rust's derived `Ord` (variant order, then fields; strings compare by code
/// point like Rust's `str`).
pub impl Compare for Yaml with fn compare(self, other) {
  match (self, other) {
    (Real(a), Real(b)) | (String(a), String(b)) => compare_str(a, b)
    (Integer(a), Integer(b)) => a.compare(b)
    (Boolean(a), Boolean(b)) => a.compare(b)
    (Array(a), Array(b)) => {
      let n = if a.length() < b.length() { a.length() } else { b.length() }
      for i in 0..<n {
        let c = Compare::compare(a[i], b[i])
        if c != 0 {
          return c
        }
      }
      a.length().compare(b.length())
    }
    (Hash(a), Hash(b)) => Compare::compare(a, b)
    (Alias(a), Alias(b)) => a.compare(b)
    _ => self.variant_index().compare(other.variant_index())
  }
}

///|
/// Rust `str` ordering (by code point).
fn compare_str(a : String, b : String) -> Int {
  let ia = a.iter()
  let ib = b.iter()
  while true {
    match (ia.next(), ib.next()) {
      (None, None) => return 0
      (None, Some(_)) => return -1
      (Some(_), None) => return 1
      (Some(x), Some(y)) => if x != y { return x.compare(y) }
    }
  }
  0
}
