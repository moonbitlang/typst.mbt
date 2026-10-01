// Port of the serde impls of Typst values (upstream `impl Serialize for
// Value` / `impl Deserialize for Value` in `foundations/value.rs`, and the
// impls for `Bytes`, `Symbol`, `Content`, `NoneValue`, `Array` and `Dict`).
// The data formats exchange values as an `@serde.Data` tree.

///|
/// Serialize a value into the serde data model (upstream `impl Serialize for
/// Value`). `human_readable` is the serializer's `is_human_readable()`.
pub fn Value::to_serde(self : Value, human_readable : Bool) -> @serde.Data {
  match self {
    None => None
    Bool(v) => Bool(v)
    Int(v) => Int(v)
    Float(v) => Float(v)
    Str(v) => Str(v)
    // Upstream `impl Serialize for Bytes`.
    Bytes(v) => if human_readable { Str(v.repr()) } else { Bytes(v.0) }
    // Upstream `impl Serialize for Symbol`.
    Symbol(v) => Str(v.get())
    // Upstream `impl Serialize for Content`.
    Content(v) => {
      let entries = [("func", @serde.Data::Str(v.func().name()))]
      for key, value in v.fields().iter() {
        entries.push((key, value.to_serde(human_readable)))
      }
      Map(entries)
    }
    Array(v) => Seq(v.items.map(item => item.to_serde(human_readable)))
    Dict(v) => {
      let entries = []
      for key, value in v.iter() {
        entries.push((key, value.to_serde(human_readable)))
      }
      Map(entries)
    }
    // Fall back to repr() for other things.
    other => Str(other.repr())
  }
}

///|
/// Serialize a dictionary into the serde data model (upstream `impl
/// Serialize for Dict`).
pub fn Dict::to_serde(self : Dict, human_readable : Bool) -> @serde.Data {
  Value::Dict(self).to_serde(human_readable)
}

///|
/// Deserialize a value from the serde data model (upstream `ValueVisitor`).
pub fn Value::from_serde(data : @serde.Data) -> Value {
  match data {
    None => None
    Bool(v) => Bool(v)
    Int(v) => Int(v)
    Float(v) => Float(v)
    Str(v) => Str(v)
    Bytes(v) => Bytes(BytesValue(v))
    Seq(items) => Array(Arr::from_array(items.map(Value::from_serde)))
    Map(entries) => {
      let dict = Dict::from_serde_entries(entries)
      match Datetime::from_toml_dict(dict) {
        None => Dict(dict)
        Some(datetime) => Datetime(datetime)
      }
    }
  }
}

///|
/// Deserialize a dictionary from serde map entries (upstream `impl
/// Deserialize for Dict`: an `IndexMap` where later duplicates replace the
/// value but keep the position of the first occurrence).
pub fn Dict::from_serde_entries(entries : Array[(String, @serde.Data)]) -> Dict {
  let dict = Dict::new()
  for entry in entries {
    let (key, value) = entry
    dict.insert(key, Value::from_serde(value))
  }
  dict
}
