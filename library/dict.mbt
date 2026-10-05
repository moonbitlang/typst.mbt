// Core of `typst-library/src/foundations/dict.rs`: the dictionary value type.
// Methods exposed to Typst live in `dict_methods.mbt`.

///|
/// A map from string keys to values (insertion ordered). Value semantics as
/// for [Arr].
pub struct Dict {
  /// The pairs.
  map : Map[String, Value]
  /// Whether another reference to this dictionary may exist.
  mut shared : Bool
}

///|
/// Create a new, empty dictionary.
pub fn Dict::new() -> Dict {
  { map: {}, shared: false, }
}

///|
/// Create a dictionary from pairs.
pub fn Dict::from_pairs(pairs : ArrayView[(String, Value)]) -> Dict {
  let map = {}
  for pair in pairs {
    map[pair.0] = pair.1
  }
  { map, shared: false, }
}

///|
/// A fresh, unshared copy (values are marked shared).
pub fn Dict::copy(self : Dict) -> Dict {
  let map = {}
  for k, v in self.map {
    map[k] = v.shared()
  }
  { map, shared: false, }
}

///|
/// The dictionary to mutate (see [Arr::make_mut]).
pub fn Dict::make_mut(self : Dict) -> Dict {
  if self.shared {
    self.copy()
  } else {
    self
  }
}

///|
/// Whether the dictionary is empty.
pub fn Dict::is_empty(self : Dict) -> Bool {
  self.map.is_empty()
}

///|
/// The number of pairs.
pub fn Dict::len(self : Dict) -> Int {
  self.map.length()
}

///|
/// Borrow the value at the given key.
pub fn Dict::get(self : Dict, key : String) -> Value raise HintedError {
  match self.map.get(key) {
    Some(v) => v
    None => bail(missing_key(key))
  }
}

///|
/// Whether the dictionary contains a specific key.
pub fn Dict::contains(self : Dict, key : String) -> Bool {
  self.map.contains(key)
}

///|
/// Insert a pair (the dictionary must be unshared).
pub fn Dict::insert(self : Dict, key : String, value : Value) -> Unit {
  self.map[key] = value
}

///|
/// Whether all keys of the dictionary are among `expected`. Then the
/// copy-take-finish casting pattern (`dict.copy()`, `take` each key,
/// `finish(expected)`) cannot fail with unexpected keys, and casts may read
/// the keys without copying the dictionary (performance). The `expected`
/// keys must be distinct.
pub fn Dict::keys_within(self : Dict, expected : ArrayView[String]) -> Bool {
  let mut n = 0
  for key in expected {
    if self.map.contains(key) {
      n += 1
    }
  }
  n == self.map.length()
}

///|
/// Remove the value if the dictionary contains the given key.
pub fn Dict::take(self : Dict, key : String) -> Value raise HintedError {
  match self.map.get(key) {
    Some(v) => {
      self.map.remove(key)
      v
    }
    None => bail(missing_key(key))
  }
}

///|
/// Iterate over pairs.
pub fn Dict::iter(self : Dict) -> Iter2[String, Value] {
  self.map.iter2()
}

///|
/// Upstream `Repr for Dict`.
pub fn Dict::repr(self : Dict) -> String {
  if self.is_empty() {
    return "(:)"
  }
  let max = 40
  let pieces = []
  let mut i = 0
  for key, value in self.map {
    if i >= max {
      break
    }
    if @syntax.is_ident(key) {
      pieces.push("\{key}: \{value.repr()}")
    } else {
      pieces.push("\{repr_str(key)}: \{value.repr()}")
    }
    i += 1
  }
  if self.len() > max {
    pieces.push(".. (\{self.len() - max} pairs omitted)")
  }
  pretty_array_like(pieces, false)
}

///|
/// Merge two dictionaries (upstream `Add for Dict`).
pub fn Dict::merge(self : Dict, other : Dict) -> Dict {
  let out = self.copy()
  for k, v in other.map {
    out.map[k] = v.shared()
  }
  out
}

///|
/// The missing key access error message.
pub fn missing_key(key : String) -> String {
  "dictionary does not contain key \{repr_str(key)}"
}

///|
/// The missing key access error message when no default was given.
pub fn missing_key_no_default(key : String) -> String {
  "dictionary does not contain key \{repr_str(key)} and no default value was specified"
}

///|
/// Removes a pair from the dictionary and returns the value.
pub fn Dict::remove(
  self : Dict,
  key : String,
  default : Value?,
) -> Value raise HintedError {
  match self.map.get(key) {
    Some(v) => {
      self.map.remove(key)
      v
    }
    None =>
      match default {
        Some(d) => d
        None => bail(missing_key(key))
      }
  }
}

///|
/// Check if there is any remaining pair, and if so return an
/// "unexpected key" error.
pub fn Dict::finish(
  self : Dict,
  expected : ArrayView[String],
) -> Unit raise HintedError {
  if self.is_empty() {
    return
  }
  let unexpected = self.map.keys().collect()
  bail(Dict::unexpected_keys(unexpected, Some(expected)))
}

///|
/// Return an "unexpected key" error string.
pub fn Dict::unexpected_keys(
  unexpected : ArrayView[String],
  hint_expected : ArrayView[String]?,
) -> String {
  let format_as_list = (arr : ArrayView[String]) => {
    separated_list(arr.map(s => "\"\{s}\""), "and")
  }
  let msg = StringBuilder()
  msg.write_string(
    match unexpected.length() {
      1 => "unexpected key "
      _ => "unexpected keys "
    },
  )
  msg.write_string(format_as_list(unexpected))
  if hint_expected is Some(expected) {
    msg.write_string(", valid keys are ")
    msg.write_string(format_as_list(expected))
  }
  msg.to_string()
}
