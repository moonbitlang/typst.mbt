// Core of `typst-library/src/foundations/array.rs`: the array value type.
// Methods exposed to Typst live in `array_methods.mbt`.

///|
/// A sequence of values (upstream `Array`, named `Arr` to avoid clashing
/// with MoonBit's `Array`).
///
/// Arrays have value semantics: `shared` is set whenever a second reference
/// to the array is created (see [Value::shared]); mutation through
/// [Arr::make_mut] copies a shared array first.
pub struct Arr {
  /// The items.
  items : Array[Value]
  /// Whether another reference to this array may exist.
  mut shared : Bool
}

///|
/// Create a new, empty array.
pub fn Arr::new() -> Arr {
  { items: [], shared: false, }
}

///|
/// Create an array taking ownership of the given values.
pub fn Arr::from_array(items : Array[Value]) -> Arr {
  { items, shared: false, }
}

///|
/// A fresh, unshared copy of this array (items are marked shared).
pub fn Arr::copy(self : Arr) -> Arr {
  { items: self.items.map(v => v.shared()), shared: false, }
}

///|
/// The array to mutate: either this one, or an unshared copy if it may be
/// referenced elsewhere. Callers must store the result back.
pub fn Arr::make_mut(self : Arr) -> Arr {
  if self.shared {
    self.copy()
  } else {
    self
  }
}

///|
/// Whether the array is empty.
pub fn Arr::is_empty(self : Arr) -> Bool {
  self.items.is_empty()
}

///|
/// The length of the array.
pub fn Arr::len(self : Arr) -> Int {
  self.items.length()
}

///|
/// Iterate over the items.
pub fn Arr::iter(self : Arr) -> Iter[Value] {
  self.items.iter()
}

///|
/// Resolve an index or return an out-of-bounds error.
pub fn Arr::locate(
  self : Arr,
  index : Int64,
  end_ok : Bool,
) -> Int raise HintedError {
  match self.locate_opt(index, end_ok) {
    Some(i) => i
    None => bail(out_of_bounds(index, self.len()))
  }
}

///|
/// Resolve an index, if it is within bounds. `index == len` is considered in
/// bounds if and only if `end_ok` is true.
pub fn Arr::locate_opt(self : Arr, index : Int64, end_ok : Bool) -> Int? {
  let len = self.len().to_int64()
  let wrapped = if index >= 0L { index } else { len + index }
  let limit = len + (if end_ok { 1L } else { 0L })
  if wrapped >= 0L && wrapped < limit {
    Some(wrapped.to_int())
  } else {
    None
  }
}

///|
/// Borrow the value at the given index (for mutable access the array must
/// already be unshared).
pub fn Arr::at_index(self : Arr, index : Int64) -> Value raise HintedError {
  let i = match self.locate_opt(index, false) {
    Some(i) => i
    None => bail(out_of_bounds_no_default(index, self.len()))
  }
  self.items[i]
}

///|
/// Upstream `Repr for Array`.
pub fn Arr::repr(self : Arr) -> String {
  let max = 40
  let pieces = []
  for i, value in self.items {
    if i >= max {
      break
    }
    pieces.push(value.repr())
  }
  if self.len() > max {
    pieces.push(".. (\{self.len() - max} items omitted)")
  }
  pretty_array_like(pieces, self.len() == 1)
}

///|
/// Repeat this array `n` times.
pub fn Arr::repeat(self : Arr, n : Int64) -> Arr raise HintedError {
  let count = self.len().to_int64() * n
  if (n > 0L && count / n != self.len().to_int64()) || count > 0x7FFFFFFFL {
    bail("cannot repeat this array \{n} times")
  }
  let out = []
  for _ in 0L..<n {
    for v in self.items {
      out.push(v.shared())
    }
  }
  Arr::from_array(out)
}

///|
/// Concatenate two arrays.
pub fn Arr::concat(self : Arr, other : Arr) -> Arr {
  let out = self.items.map(v => v.shared())
  for v in other.items {
    out.push(v.shared())
  }
  Arr::from_array(out)
}

///|
/// The error message when the array is empty.
pub fn array_is_empty() -> String {
  "array is empty"
}

///|
/// The out of bounds access error message.
pub fn out_of_bounds(index : Int64, len : Int) -> String {
  "array index out of bounds (index: \{index}, len: \{len})"
}

///|
/// The out of bounds access error message when no default value was given.
pub fn out_of_bounds_no_default(index : Int64, len : Int) -> String {
  "array index out of bounds (index: \{index}, len: \{len}) and no default value was specified"
}

///|
/// Remove the last item from the array and return it.
pub fn Arr::pop(self : Arr) -> Value raise HintedError {
  match self.items.pop() {
    Some(v) => v
    None => bail(array_is_empty())
  }
}

///|
/// Insert a value into the array at the specified index.
pub fn Arr::insert(
  self : Arr,
  index : Int64,
  value : Value,
) -> Unit raise HintedError {
  let i = self.locate(index, true)
  self.items.insert(i, value)
}

///|
/// Remove the value at the specified index from the array and return it.
pub fn Arr::remove(
  self : Arr,
  index : Int64,
  default : Value?,
) -> Value raise HintedError {
  match self.locate_opt(index, false) {
    Some(i) => self.items.remove(i)
    None =>
      match default {
        Some(d) => d
        None => bail(out_of_bounds_no_default(index, self.len()))
      }
  }
}
