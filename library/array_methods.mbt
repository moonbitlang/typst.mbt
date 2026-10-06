// Port of the `#[scope] impl Array` block of
// `typst-library/src/foundations/array.rs`: the methods of the `array` type.
//
// Values taken out of an array are marked shared (upstream clones them,
// bumping reference counts). Mutating methods called in function form
// (`array.push(a, 1)`) mutate an unshared copy if needed, like upstream's
// `&mut self` on a cloned argument; `a.push(1)` is handled by the evaluator.

///|
/// Converts a value to an array.
fn impl_array_construct(value_ : ToArray) -> Arr {
  value_.0
}

///|
/// The number of values in the array.
fn impl_array_len(self_ : Arr) -> USize {
  USize(self_.len().to_int64())
}

///|
/// Returns the first item in the array. May be used on the left-hand side
/// of an assignment. Fails with an error if the array is empty.
fn impl_array_first(self_ : Arr, default_ : Value?) -> Value raise HintedError {
  match self_.items.get(0) {
    Some(v) => v.shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail(array_is_empty())
      }
  }
}

///|
/// Returns the last item in the array. May be used on the left-hand side of
/// an assignment. Fails with an error if the array is empty.
fn impl_array_last(self_ : Arr, default_ : Value?) -> Value raise HintedError {
  match self_.items.last() {
    Some(v) => v.shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail(array_is_empty())
      }
  }
}

///|
/// Returns the item at the specified index in the array. May be used on the
/// left-hand side of an assignment. Returns the default value if the index
/// is out of bounds or fails with an error if no default value was
/// specified.
fn impl_array_at(
  self_ : Arr,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  match self_.locate_opt(index_, false) {
    Some(i) => self_.items[i].shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail(out_of_bounds_no_default(index_, self_.len()))
      }
  }
}

///|
/// Adds a value to the end of the array.
fn impl_array_push(self_ : Arr, value_ : Value) -> Unit {
  self_.make_mut().items.push(value_)
}

///|
/// Removes the last item from the array and returns it. Fails with an error
/// if the array is empty.
fn impl_array_pop(self_ : Arr) -> Value raise HintedError {
  self_.make_mut().pop()
}

///|
/// Inserts a value into the array at the specified index, shifting all
/// subsequent elements to the right. Fails with an error if the index is out
/// of bounds.
fn impl_array_insert(
  self_ : Arr,
  index_ : Int64,
  value_ : Value,
) -> Unit raise HintedError {
  self_.make_mut().insert(index_, value_)
}

///|
/// Removes the value at the specified index from the array and return it.
fn impl_array_remove(
  self_ : Arr,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  let array = self_.make_mut()
  match array.locate_opt(index_, false) {
    Some(i) => array.items.remove(i)
    None =>
      match default_ {
        Some(d) => d
        None => bail(out_of_bounds_no_default(index_, array.len()))
      }
  }
}

///|
/// Default of `array.slice(end)`.
fn impl_array_slice__end_default() -> Int64? {
  None
}

///|
/// Extracts a subslice of the array. Fails with an error if the start or end
/// index is out of bounds.
fn impl_array_slice(
  self_ : Arr,
  start_ : Int64,
  end_ : Int64?,
  count_ : Int64?,
) -> Arr raise HintedError {
  if end_ is Some(_) && count_ is Some(_) {
    bail("`end` and `count` are mutually exclusive")
  }
  let start = self_.locate(start_, true)
  let end = match end_ {
    Some(e) => Some(e)
    None => count_.map(c => start.to_int64() + c)
  }
  let end = self_.locate(end.unwrap_or(self_.len().to_int64()), true)
  let end = if end < start { start } else { end }
  Arr::from_array(self_.items[start:end].iter().map(v => v.shared()).collect())
}

///|
/// Whether the array contains the specified value.
fn impl_array_contains(self_ : Arr, value_ : Value) -> Bool {
  self_.items.iter().any(v => equal(v, value_))
}

///|
/// Call a function with one value and cast the result to a boolean
/// (upstream `f.call(engine, context, [v])?.cast::<bool>().at(f.span())`).
fn call_bool_test(
  f : Func,
  engine : Engine,
  context : Context,
  value : Value,
) -> Bool raise SourceError {
  let result = f.call_values(engine, context, [value])
  at(f.span(), () => result.cast())
}

///|
/// Searches for an item for which the given function returns `{true}` and
/// returns the first match or `{none}` if there is no match.
fn impl_array_find(
  self_ : Arr,
  engine : Engine,
  context : Context,
  searcher_ : Func,
) -> Value? raise SourceError {
  for item in self_.items {
    if call_bool_test(searcher_, engine, context, item.shared()) {
      return Some(item.shared())
    }
  }
  None
}

///|
/// Searches for an item for which the given function returns `{true}` and
/// returns the index of the first match or `{none}` if there is no match.
fn impl_array_position(
  self_ : Arr,
  engine : Engine,
  context : Context,
  searcher_ : Func,
) -> Int64? raise SourceError {
  for i, item in self_.items {
    if call_bool_test(searcher_, engine, context, item.shared()) {
      return Some(i.to_int64())
    }
  }
  None
}

///|
/// Default of `range(start)`.
fn impl_array_range__start_default() -> Int64 {
  0L
}

///|
/// Default of `range(step:)`: `NonZeroI64::new(1).unwrap()`.
fn impl_array_range__step_default() -> NonZeroI64 {
  NonZeroI64(1L)
}

///|
/// Create an array consisting of a sequence of numbers.
fn impl_array_range(
  args : Args,
  inclusive_ : Bool,
  step_ : NonZeroI64,
) -> Arr raise SourceError {
  let first : Int64 = args.expect("end")
  let (start, end) = match (args.eat() : Int64?) {
    Some(second) => (first, second)
    None => (0L, first)
  }
  let step = step_.get()
  // `Ordering` as -1, 0 or 1.
  let ordering = (a : Int64, b : Int64) => {
    if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  }
  let step_dir = ordering(0L, step)
  let mut x = start
  let array = Arr::new()
  let in_bounds = (x : Int64) => {
    if inclusive_ {
      // `x` must not exceed `end`.
      ordering(x, end) != -step_dir
    } else {
      // `x` must stay strictly before `end`.
      ordering(x, end) == step_dir
    }
  }
  while in_bounds(x) {
    array.items.push(Int(x))
    match i64_checked_add(x, step) {
      Some(next) => x = next
      // `end` must have been exceeded this iteration, so we yield.
      None => break
    }
  }
  array
}

///|
/// Produces a new array with only the items from the original one for which
/// the given function returns `{true}`.
fn impl_array_filter(
  self_ : Arr,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Arr raise SourceError {
  let kept = []
  for item in self_.items {
    if call_bool_test(test_, engine, context, item.shared()) {
      kept.push(item.shared())
    }
  }
  Arr::from_array(kept)
}

///|
/// Produces a new array in which all items from the original one were
/// transformed with the given function.
fn impl_array_map(
  self_ : Arr,
  engine : Engine,
  context : Context,
  mapper_ : Func,
) -> Arr raise SourceError {
  let out = []
  for item in self_.items {
    out.push(mapper_.call_values(engine, context, [item.shared()]))
  }
  Arr::from_array(out)
}

///|
/// Returns a new array with the values alongside their indices.
fn impl_array_enumerate(self_ : Arr, start_ : Int64) -> Arr raise HintedError {
  let out = []
  for i, value in self_.items {
    let index = match i64_checked_add(start_, i.to_int64()) {
      Some(index) => index
      None => bail("array index is too large")
    }
    out.push(Array(Arr::from_array([Int(index), value.shared()])))
  }
  Arr::from_array(out)
}

///|
/// Zips the array with other arrays.
fn impl_array_zip(
  self_ : Arr,
  args : Args,
  exact_ : Bool,
) -> Arr raise SourceError {
  let remaining = args.remaining()

  // Fast path for one array.
  if remaining == 0 {
    return Arr::from_array(
      self_.items.map(item => Array(Arr::from_array([item.shared()]))),
    )
  }

  // Fast path for just two arrays.
  if remaining == 1 {
    let { v: other, span: other_span, } : @syntax.Spanned[Arr] = args.expect_spanned(
      "others",
    )
    if exact_ && self_.len() != other.len() {
      bail_at(
        other_span,
        "second array has different length (\{other.len()}) from first array (\{self_.len()})",
      )
    }
    let out = []
    for
      i in 0..<(if self_.len() < other.len() {
        self_.len()
      } else {
        other.len()
      }) {
      out.push(
        Array(
          Arr::from_array([self_.items[i].shared(), other.items[i].shared()]),
        ),
      )
    }
    return Arr::from_array(out)
  }

  // If there is more than one array, we use the manual method.
  let out = []
  let arrays : Array[@syntax.Spanned[Arr]] = args.all_spanned()
  if exact_ {
    let errs = []
    for sp in arrays {
      if sp.v.len() != self_.len() {
        errs.push(
          SourceDiagnostic::error_at(
            sp.span,
            "array has different length (\{sp.v.len()}) from first array (\{self_.len()})",
          ),
        )
      }
    }
    if !errs.is_empty() {
      raise SourceError(errs)
    }
  }
  for i, this in self_.items {
    let row = [this.shared()]
    for array in arrays {
      match array.v.items.get(i) {
        Some(item) => row.push(item.shared())
        None => return Arr::from_array(out)
      }
    }
    out.push(Array(Arr::from_array(row)))
  }
  Arr::from_array(out)
}

///|
/// Folds all items into a single value using an accumulator function.
fn impl_array_fold(
  self_ : Arr,
  engine : Engine,
  context : Context,
  init_ : Value,
  folder_ : Func,
) -> Value raise SourceError {
  let mut acc = init_
  for item in self_.items {
    acc = folder_.call_values(engine, context, [acc, item.shared()])
  }
  acc
}

///|
/// Sums all items (works for all types that can be added).
fn impl_array_sum(self_ : Arr, default_ : Value?) -> Value raise HintedError {
  let mut acc = match self_.items.get(0) {
    Some(v) => v.shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail("cannot calculate sum of empty array with no default")
      }
  }
  for i in 1..<self_.len() {
    acc = add(acc, self_.items[i].shared())
  }
  acc
}

///|
/// Calculates the product of all items (works for all types that can be
/// multiplied).
fn impl_array_product(
  self_ : Arr,
  default_ : Value?,
) -> Value raise HintedError {
  let mut acc = match self_.items.get(0) {
    Some(v) => v.shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail("cannot calculate product of empty array with no default")
      }
  }
  for i in 1..<self_.len() {
    acc = mul(acc, self_.items[i].shared())
  }
  acc
}

///|
/// Whether the given function returns `{true}` for any item in the array.
fn impl_array_any(
  self_ : Arr,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Bool raise SourceError {
  for item in self_.items {
    if call_bool_test(test_, engine, context, item.shared()) {
      return true
    }
  }
  false
}

///|
/// Whether the given function returns `{true}` for all items in the array.
fn impl_array_all(
  self_ : Arr,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Bool raise SourceError {
  for item in self_.items {
    if !call_bool_test(test_, engine, context, item.shared()) {
      return false
    }
  }
  true
}

///|
/// Combine all nested arrays into a single flat one.
fn impl_array_flatten(self_ : Arr) -> Arr {
  Arr::from_array(array_flatten(self_))
}

///|
/// Flatten nested arrays recursively.
fn array_flatten(array : Arr) -> Array[Value] {
  let flat = []
  for item in array.items {
    match item {
      Array(nested) => flat.append(array_flatten(nested))
      _ => flat.push(item.shared())
    }
  }
  flat
}

///|
/// Return a new array with the same items, but in reverse order.
fn impl_array_rev(self_ : Arr) -> Arr {
  let out = self_.items.map(v => v.shared())
  out.rev_in_place()
  Arr::from_array(out)
}

///|
/// Split the array at occurrences of the specified value.
fn impl_array_split(self_ : Arr, at_ : Value) -> Arr {
  // Rust's `slice::split`: always yields at least one (possibly empty)
  // subslice.
  let out = []
  let mut current = []
  for value in self_.items {
    if equal(value, at_) {
      out.push(Array(Arr::from_array(current)))
      current = []
    } else {
      current.push(value.shared())
    }
  }
  out.push(Array(Arr::from_array(current)))
  Arr::from_array(out)
}

///|
/// Default of `array.join(separator)`.
fn impl_array_join__separator_default() -> Value? {
  None
}

///|
/// Default of `array.join(default:)`.
fn impl_array_join__default_default() -> Value? {
  None
}

///|
/// Combine all items in the array into one.
fn impl_array_join(
  self_ : Arr,
  separator_ : Value?,
  last_ : Value?,
  default_ : Value?,
) -> Value raise HintedError {
  let len = self_.len()
  if default_ is Some(result) && len == 0 {
    return result
  }
  let separator = separator_.unwrap_or(None)
  let mut last = last_
  let mut result : Value = None
  for i, value in self_.items {
    if i > 0 {
      if i + 1 == len && last is Some(l) {
        last = None
        result = join(result, l)
      } else {
        result = join(result, separator.shared())
      }
    }
    result = join(result, value.shared())
  }
  result
}

///|
/// Returns an array with a copy of the separator value placed between
/// adjacent elements.
fn impl_array_intersperse(self_ : Arr, separator_ : Value) -> Arr {
  let vec = []
  for i, value in self_.items {
    if i > 0 {
      vec.push(separator_.shared())
    }
    vec.push(value.shared())
  }
  Arr::from_array(vec)
}

///|
/// Splits an array into non-overlapping chunks, starting at the beginning,
/// ending with a single remainder chunk.
fn impl_array_chunks(
  self_ : Arr,
  chunk_size_ : NonZeroUSize,
  exact_ : Bool,
) -> Arr {
  let size = chunk_size_.get()
  let len = self_.len().to_int64()
  let out = []
  let mut start = 0L
  while start < len {
    let end = if len - start < size { len } else { start + size }
    if exact_ && end - start < size {
      break
    }
    out.push(
      Array(
        Arr::from_array(
          self_.items[start.to_int():end.to_int()]
          .iter()
          .map(v => v.shared())
          .collect(),
        ),
      ),
    )
    start = end
  }
  Arr::from_array(out)
}

///|
/// Returns sliding windows of `window-size` elements over an array.
fn impl_array_windows(self_ : Arr, window_size_ : NonZeroUSize) -> Arr {
  let size = window_size_.get()
  let len = self_.len().to_int64()
  let out = []
  if size <= len {
    let size = size.to_int()
    for start in 0..<=(len.to_int() - size) {
      out.push(
        Array(
          Arr::from_array(
            self_.items[start:start + size]
            .iter()
            .map(v => v.shared())
            .collect(),
          ),
        ),
      )
    }
  }
  Arr::from_array(out)
}

///|
/// Return a sorted version of this array, optionally by a given key
/// function. The sorting algorithm used is stable.
fn impl_array_sorted(
  self_ : Arr,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  key_ : Func?,
  by_ : Func?,
) -> Arr raise SourceError {
  // Upstream relies on `comemo`'s memoization of function evaluation to not
  // excessively reevaluate the key; we cache the keys explicitly.
  let items = self_.items.map(v => v.shared())
  let keys : Array[Value?] = Array::make(items.length(), None)
  let key_of = (i : Int) => {
    match keys[i] {
      Some(k) => k
      None => {
        let k = match key_ {
          Some(f) => f.call_values(engine, context, [items[i].shared()])
          None => items[i].shared()
        }
        keys[i] = Some(k)
        k
      }
    }
  }
  let order = match by_ {
    Some(by) => {
      let are_in_order = (i : Int, j : Int) => {
        let x = key_of(i)
        let y = key_of(j)
        match by.call_values(engine, context, [x.shared(), y.shared()]) {
          Bool(b) => b
          x =>
            bail_at(span, "expected boolean from `by` function, got \{x.ty()}")
        }
      }
      stable_sort_indices(items.length(), (i, j) => {
        // Because we use booleans for the comparison function, in order to
        // keep the sort stable, we need to compare in the right order.
        if i == j {
          0
        } else if i < j {
          // If `x` and `y` appear in this order in the original array,
          // then we should change their order iff `y` is strictly less than
          // `x` (i.e., `compare(x, y)` returns `false`).
          if are_in_order(i, j) {
            -1
          } else {
            1
          }
        } else if are_in_order(j, i) {
          // If `x` and `y` appear in the opposite order in the original
          // array, then we should change their order iff `x` is strictly
          // less than `y` (i.e., `compare(y, x)` returns `false`).
          1
        } else {
          -1
        }
      })
    }
    None =>
      stable_sort_indices(items.length(), (i, j) => {
        let a = key_of(i)
        let b = key_of(j)
        compare(a, b) catch {
          HintedError(err) => {
            err.hint(
              match key_ {
                None =>
                  "consider choosing a `key` or defining the comparison with `by`"
                Some(_) =>
                  "consider defining the comparison with `by` or choosing a different `key`"
              },
            )
            raise SourceError([err.into_error_at(span)])
          }
        }
      })
  }
  Arr::from_array(order.map(i => items[i]))
}

///|
/// Sort the indices `0..n` stably by a fallible three-way comparison
/// (`cmp(a, b) < 0` iff `a` must come before `b`). Upstream uses
/// `glidesort`; we use binary insertion sort on small inputs and a merge
/// sort on larger ones, always comparing a later element against an
/// earlier one first, so the first error matches upstream on small inputs.
fn stable_sort_indices(
  n : Int,
  cmp : (Int, Int) -> Int raise SourceError,
) -> Array[Int] raise SourceError {
  let idx = Array::makei(n, i => i)
  sort_range(idx, 0, n, cmp)
  idx
}

///|
fn sort_range(
  idx : Array[Int],
  lo : Int,
  hi : Int,
  cmp : (Int, Int) -> Int raise SourceError,
) -> Unit raise SourceError {
  if hi - lo <= 32 {
    // Binary insertion sort.
    for i in (lo + 1)..<hi {
      let x = idx[i]
      let mut left = lo
      let mut right = i
      while left < right {
        let mid = left + (right - left) / 2
        if cmp(x, idx[mid]) < 0 {
          right = mid
        } else {
          left = mid + 1
        }
      }
      let mut j = i
      while j > left {
        idx[j] = idx[j - 1]
        j -= 1
      }
      idx[left] = x
    }
    return
  }
  let mid = lo + (hi - lo) / 2
  sort_range(idx, lo, mid, cmp)
  sort_range(idx, mid, hi, cmp)
  let merged = []
  let mut i = lo
  let mut j = mid
  while i < mid && j < hi {
    if cmp(idx[j], idx[i]) < 0 {
      merged.push(idx[j])
      j += 1
    } else {
      merged.push(idx[i])
      i += 1
    }
  }
  while i < mid {
    merged.push(idx[i])
    i += 1
  }
  while j < hi {
    merged.push(idx[j])
    j += 1
  }
  for k, v in merged {
    idx[lo + k] = v
  }
}

///|
/// Deduplicates all items in the array.
fn impl_array_dedup(
  self_ : Arr,
  engine : Engine,
  context : Context,
  key_ : Func?,
) -> Arr raise SourceError {
  let out = []
  // Keys of the items in `out` (upstream relies on `comemo`'s memoization).
  let out_keys = []
  let key_of = (x : Value) => {
    match key_ {
      Some(f) => f.call_values(engine, context, [x])
      None => x
    }
  }

  // This algorithm is O(N^2) because we cannot rely on `HashSet` since:
  // 1. We would like to preserve the order of the elements.
  // 2. We cannot hash arbitrary `Value`.
  for value in self_.items {
    let key = key_of(value.shared())
    if out_keys.iter().any(second => equal(key, second)) {
      continue
    }
    out.push(value.shared())
    out_keys.push(key)
  }
  Arr::from_array(out)
}

///|
/// Converts an array of pairs into a dictionary.
fn impl_array_to_dict(self_ : Arr) -> Dict raise HintedError {
  let dict = Dict::new()
  for value in self_.items {
    let pair = match value {
      Array(pair) => pair
      _ => bail("expected (str, any) pairs, found \{value.ty()}")
    }
    if pair.len() != 2 {
      bail("expected pairs of length 2, found length \{pair.len()}")
    }
    let key = pair.items[0]
    let key : String = key.cast() catch {
      _ => bail("expected key of type string, found \{key.ty()}")
    }
    dict.insert(key, pair.items[1].shared())
  }
  dict
}

///|
/// Reduces the elements to a single one, by repeatedly applying a reducing
/// operation.
fn impl_array_reduce(
  self_ : Arr,
  engine : Engine,
  context : Context,
  reducer_ : Func,
) -> Value raise SourceError {
  let mut acc : Value = match self_.items.get(0) {
    Some(v) => v.shared()
    None => None
  }
  for i in 1..<self_.len() {
    acc = reducer_.call_values(engine, context, [acc, self_.items[i].shared()])
  }
  acc
}

///|
/// A value that can be cast to an array.
pub(all) struct ToArray(Arr)

///|
pub impl Reflect for ToArray with fn input() {
  CastInfo::Type(Type::array())
  .union_with(Type(Type::bytes()))
  .union_with(Type(Type::version()))
}

///|
pub impl Reflect for ToArray with fn output() {
  ToArray::input()
}

///|
pub impl Reflect for ToArray with fn castable(v) {
  v is (Array(_) | Bytes(_) | Version(_))
}

///|
pub extend ToArray with Reflect::{output, input, castable}

///|
pub impl FromValue for ToArray with fn from_value(v) {
  match v {
    Array(v) => ToArray(v)
    Bytes(v) => {
      let bytes = v.as_slice()
      ToArray(
        Arr::from_array(
          Array::makei(bytes.length(), i => Int(bytes[i].to_int64())),
        ),
      )
    }
    Version(v) =>
      ToArray(Arr::from_array(v.values().map(c => Int(c.to_int64()))))
    v => raise HintedError(ToArray::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ToArray with FromValue::{from_value}
