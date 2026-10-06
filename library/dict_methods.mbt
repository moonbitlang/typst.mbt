// Port of the `#[scope] impl Dict` block of
// `typst-library/src/foundations/dict.rs`: the methods of the `dictionary`
// type. Mutating methods follow the conventions in `array_methods.mbt`.

///|
/// Converts a value into a dictionary.
// Cannot fail; upstream returns `SourceResult` and only `Ok`
// (typst-library/src/foundations/dict.rs:186).
#warnings("-unused_error_type")
fn impl_dict_construct(
  engine : Engine,
  value_ : @syntax.Spanned[ToDict],
) -> Dict raise SourceError {
  let ToDict(module_) = value_.v
  let dict = Dict::new()
  // Filter out values that are in feature gated bindings and ignore any
  // deprecation warnings that are emitted.
  let guard_ = BindingGuard::silent(engine.library.features)
  for entry in module_.scope().iter() {
    let (key, binding) = entry
    let value = binding.read(guard_, "") catch { _ => continue }
    dict.insert(key, value.shared())
  }
  dict
}

///|
/// The number of pairs in the dictionary.
fn impl_dict_len(self_ : Dict) -> USize {
  USize(self_.len().to_int64())
}

///|
/// Returns the value associated with the specified key in the dictionary.
/// May be used on the left-hand side of an assignment if the key is already
/// present in the dictionary. Returns the default value if the key is not
/// part of the dictionary or fails with an error if no default value was
/// specified.
fn impl_dict_at(
  self_ : Dict,
  key_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  match self_.map.get(key_) {
    Some(v) => v.shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail(missing_key_no_default(key_))
      }
  }
}

///|
/// Inserts a new pair into the dictionary. If the dictionary already
/// contains this key, the value is updated.
fn impl_dict_insert(self_ : Dict, key_ : String, value_ : Value) -> Unit {
  self_.make_mut().insert(key_, value_)
}

///|
/// Removes a pair from the dictionary by key and return the value.
fn impl_dict_remove(
  self_ : Dict,
  key_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  self_.make_mut().remove(key_, default_)
}

///|
/// Returns the keys of the dictionary as an array in insertion order.
fn impl_dict_keys(self_ : Dict) -> Arr {
  Arr::from_array(self_.map.keys().map(k => Value::Str(k)).collect())
}

///|
/// Returns the values of the dictionary as an array in insertion order.
fn impl_dict_values(self_ : Dict) -> Arr {
  Arr::from_array(self_.map.values().map(v => v.shared()).collect())
}

///|
/// Returns the keys and values of the dictionary as an array of pairs. Each
/// pair is represented as an array of length two.
fn impl_dict_pairs(self_ : Dict) -> Arr {
  let out = []
  for k, v in self_.map {
    out.push(Array(Arr::from_array([Str(k), v.shared()])))
  }
  Arr::from_array(out)
}

///|
/// Produces a new dictionary with only the pairs from the original one for
/// which the given function returns `{true}`.
fn impl_dict_filter(
  self_ : Dict,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Dict raise SourceError {
  let out = Dict::new()
  for k, v in self_.map {
    if call_bool_test(test_, engine, context, v.shared()) {
      out.insert(k, v.shared())
    }
  }
  out
}

///|
/// Produces a new dictionary in which all pairs' values were transformed
/// with the given function.
fn impl_dict_map(
  self_ : Dict,
  engine : Engine,
  context : Context,
  mapper_ : Func,
) -> Dict raise SourceError {
  let out = Dict::new()
  for k, v in self_.map {
    out.insert(k, mapper_.call_values(engine, context, [v.shared()]))
  }
  out
}

///|
/// A value that can be cast to a dictionary.
pub(all) struct ToDict(Module)

///|
pub impl Reflect for ToDict with fn input() {
  Type(Type::module_())
}

///|
pub impl Reflect for ToDict with fn output() {
  ToDict::input()
}

///|
pub impl Reflect for ToDict with fn castable(v) {
  v is Module(_)
}

///|
pub extend ToDict with Reflect::{output, input, castable}

///|
pub impl FromValue for ToDict with fn from_value(v) {
  match v {
    Module(m) => ToDict(m)
    v => raise HintedError(ToDict::input().error(v))
  }
}
