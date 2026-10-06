// The subset of `linked_hash_map::LinkedHashMap` (linked-hash-map 0.5.6)
// that `yaml_rust::yaml::Hash` users need.

///|
/// A hash map that iterates in insertion order. Inserting an existing key
/// replaces its value and moves the entry to the end, like upstream.
/// Equality, hashing and ordering are order-sensitive (they compare the entry
/// sequences), like upstream.
pub struct LinkedHashMap[K, V] {
  priv map : Map[K, V]
}

///|
pub fn[K : Hash + Eq, V] LinkedHashMap::new() -> LinkedHashMap[K, V] {
  { map: {}, }
}

///|
/// Inserts a key-value pair, returning the old value if the key was present.
/// An existing entry is moved to the end.
pub fn[K : Hash + Eq, V] LinkedHashMap::insert(
  self : LinkedHashMap[K, V],
  k : K,
  v : V,
) -> V? {
  let old = self.map.get(k)
  if old is Some(_) {
    self.map.remove(k)
  }
  self.map.set(k, v)
  old
}

///|
pub fn[K : Hash + Eq, V] LinkedHashMap::get(
  self : LinkedHashMap[K, V],
  k : K,
) -> V? {
  self.map.get(k)
}

///|
pub fn[K : Hash + Eq, V] LinkedHashMap::contains_key(
  self : LinkedHashMap[K, V],
  k : K,
) -> Bool {
  self.map.contains(k)
}

///|
pub fn[K : Hash + Eq, V] LinkedHashMap::remove(
  self : LinkedHashMap[K, V],
  k : K,
) -> V? {
  let old = self.map.get(k)
  if old is Some(_) {
    self.map.remove(k)
  }
  old
}

///|
pub fn[K, V] LinkedHashMap::len(self : LinkedHashMap[K, V]) -> Int {
  self.map.length()
}

///|
pub fn[K, V] LinkedHashMap::is_empty(self : LinkedHashMap[K, V]) -> Bool {
  self.map.is_empty()
}

///|
/// Iterates the entries in insertion order.
pub fn[K, V] LinkedHashMap::iter(self : LinkedHashMap[K, V]) -> Iter[(K, V)] {
  self.map.iter()
}

///|
pub fn[K, V] LinkedHashMap::iter2(self : LinkedHashMap[K, V]) -> Iter2[K, V] {
  self.map.iter2()
}

///|
pub fn[K, V] LinkedHashMap::keys(self : LinkedHashMap[K, V]) -> Iter[K] {
  self.map.keys()
}

///|
pub fn[K, V] LinkedHashMap::values(self : LinkedHashMap[K, V]) -> Iter[V] {
  self.map.values()
}

///|
pub fn[K, V] LinkedHashMap::to_array(
  self : LinkedHashMap[K, V],
) -> Array[(K, V)] {
  self.map.to_array()
}

///|
/// A shallow copy.
pub fn[K, V] LinkedHashMap::copy(
  self : LinkedHashMap[K, V],
) -> LinkedHashMap[K, V] {
  { map: self.map.copy(), }
}

///|
pub impl[K : Eq, V : Eq] Eq for LinkedHashMap[K, V] with fn equal(self, other) {
  if self.map.length() != other.map.length() {
    return false
  }
  let a = self.map.iter()
  let b = other.map.iter()
  while a.next() is Some((ka, va)) {
    guard b.next() is Some((kb, vb)) else { return false }
    if ka != kb || va != vb {
      return false
    }
  }
  true
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinkedHashMap with Eq::{not_equal, equal}

///|
pub impl[K : Hash, V : Hash] Hash for LinkedHashMap[K, V] with fn hash_combine(
  self,
  hasher,
) {
  for k, v in self.map {
    hasher.combine(k)
    hasher.combine(v)
  }
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinkedHashMap with Hash::{hash, hash_combine}

///|
/// Lexicographic comparison of the entry sequences.
pub impl[K : Compare, V : Compare] Compare for LinkedHashMap[K, V] with fn compare(
  self,
  other,
) {
  let a = self.map.iter()
  let b = other.map.iter()
  while true {
    match (a.next(), b.next()) {
      (None, None) => return 0
      (None, Some(_)) => return -1
      (Some(_), None) => return 1
      (Some((ka, va)), Some((kb, vb))) => {
        let c = ka.compare(kb)
        if c != 0 {
          return c
        }
        let c = va.compare(vb)
        if c != 0 {
          return c
        }
      }
    }
  }
  0
}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinkedHashMap with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
/// Rust's `{:?}` (`debug_map`) format: `{k: v, k2: v2}`.
pub impl[K : Show, V : Show] Show for LinkedHashMap[K, V] with fn output(
  self,
  logger,
) {
  logger.write_char('{')
  let mut first = true
  for k, v in self.map {
    if !first {
      logger.write_string(", ")
    }
    first = false
    k.output(logger)
    logger.write_string(": ")
    v.output(logger)
  }
  logger.write_char('}')
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinkedHashMap with Show::{to_string, output}

///|
pub impl[K : Debug, V : Debug] Debug for LinkedHashMap[K, V] with fn to_repr(
  self,
) {
  Repr(self.map)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinkedHashMap with @debug.Debug::{to_repr}
