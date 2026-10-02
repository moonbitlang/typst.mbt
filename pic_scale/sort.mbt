// Port of Rust's `slice::sort_unstable_by` (core `slice::sort::unstable`,
// "ipnsort", as of Rust 1.97) for `[usize]`, used by `quantize_kernel` to
// order the taps by magnitude. Ties are common there (symmetric kernels),
// and which tap absorbs the rounding residual depends on the exact order
// the algorithm leaves equal elements in, so the algorithm is reproduced
// step by step: insertion sort up to 20 elements, otherwise ipnsort
// (existing-run detection, quicksort with glidesort's pivot selection,
// branchless cyclic Lomuto partitioning, `small_sort_network` for up to 32
// elements since `usize` is `Freeze + Copy` and 8 bytes, heapsort fallback).
//
// Slices are `(base, len)` ranges of `v`.

///|
priv struct Sorter {
  v : Array[Int]
  is_less : (Int, Int) -> Bool
}

///|
/// `slice::sort_unstable_by(|a, b| ..)` where `is_less(a, b)` is
/// `compare(a, b) == Ordering::Less`.
fn sort_unstable_by(v : Array[Int], is_less : (Int, Int) -> Bool) -> Unit {
  let len = v.length()
  if len < 2 {
    return
  }
  let s = { v, is_less, }
  // MAX_LEN_ALWAYS_INSERTION_SORT
  if len <= 20 {
    s.insertion_sort_shift_left(0, len, 1)
    return
  }
  s.ipnsort(0, len)
}

///|
fn Sorter::swap(self : Sorter, a : Int, b : Int) -> Unit {
  let t = self.v[a]
  self.v[a] = self.v[b]
  self.v[b] = t
}

///|
/// `ipnsort`.
fn Sorter::ipnsort(self : Sorter, base : Int, len : Int) -> Unit {
  let (run_len, was_reversed) = self.find_existing_run(base, len)
  if run_len == len {
    if was_reversed {
      let mut i = base
      let mut j = base + len - 1
      while i < j {
        self.swap(i, j)
        i += 1
        j -= 1
      }
    }
    return
  }
  // Limit the number of imbalanced partitions to `2 * floor(log2(len))`.
  let limit = 2 * ilog2(len | 1)
  self.quicksort(base, len, None, limit)
}

///|
fn ilog2(x : Int) -> Int {
  31 - x.clz()
}

///|
/// `find_existing_run`.
fn Sorter::find_existing_run(
  self : Sorter,
  base : Int,
  len : Int,
) -> (Int, Bool) {
  if len < 2 {
    return (len, false)
  }
  let v = self.v
  let mut run_len = 2
  let strictly_descending = (self.is_less)(v[base + 1], v[base])
  if strictly_descending {
    while run_len < len &&
          (self.is_less)(v[base + run_len], v[base + run_len - 1]) {
      run_len += 1
    }
  } else {
    while run_len < len &&
          !(self.is_less)(v[base + run_len], v[base + run_len - 1]) {
      run_len += 1
    }
  }
  (run_len, strictly_descending)
}

///|
/// `quicksort` (unstable). `ancestor_pivot` is the value of the pivot of the
/// parent partition, if this slice is its right side.
fn Sorter::quicksort(
  self : Sorter,
  base : Int,
  len : Int,
  ancestor_pivot : Int?,
  limit : Int,
) -> Unit {
  let mut base = base
  let mut len = len
  let mut ancestor_pivot = ancestor_pivot
  let mut limit = limit
  while true {
    // SMALL_SORT_NETWORK_THRESHOLD
    if len <= 32 {
      self.small_sort_network(base, len)
      return
    }
    if limit == 0 {
      self.heapsort(base, len)
      return
    }
    limit -= 1
    let pivot_pos = self.choose_pivot(base, len)
    if ancestor_pivot is Some(p) {
      if !(self.is_less)(p, self.v[base + pivot_pos]) {
        let is_less = self.is_less
        let eq = { v: self.v, is_less: fn(a, b) { !is_less(b, a) }, }
        let num_lt = eq.partition(base, len, pivot_pos)
        base = base + num_lt + 1
        len = len - num_lt - 1
        ancestor_pivot = None
        continue
      }
    }
    let num_lt = self.partition(base, len, pivot_pos)
    let pivot = self.v[base + num_lt]
    self.quicksort(base, num_lt, ancestor_pivot, limit)
    base = base + num_lt + 1
    len = len - num_lt - 1
    ancestor_pivot = Some(pivot)
  }
}

///|
/// `partition` with `partition_lomuto_branchless_cyclic` (`usize` is small).
fn Sorter::partition(self : Sorter, base : Int, len : Int, pivot : Int) -> Int {
  if len == 0 {
    return 0
  }
  // Place the pivot at the beginning of slice.
  self.swap(base, base + pivot)
  let pivot_value = self.v[base]
  let num_lt = self.partition_lomuto_branchless_cyclic(
    base + 1,
    len - 1,
    pivot_value,
  )
  // Place the pivot between the two partitions.
  self.swap(base, base + num_lt)
  num_lt
}

///|
/// `partition_lomuto_branchless_cyclic`. The (unrolled) loop processes the
/// elements `1..len` in order and finally the saved first element (the
/// "gap" value), moving each through the cyclic permutation.
fn Sorter::partition_lomuto_branchless_cyclic(
  self : Sorter,
  base : Int,
  len : Int,
  pivot : Int,
) -> Int {
  if len == 0 {
    return 0
  }
  let v = self.v
  let gap_value = v[base]
  let mut gap_pos = base
  let mut num_lt = 0
  for right in 1..<=len {
    let elem = if right == len { gap_value } else { v[base + right] }
    let right_is_lt = (self.is_less)(elem, pivot)
    let left = base + num_lt
    v[gap_pos] = v[left]
    v[left] = elem
    gap_pos = base + right
    if right_is_lt {
      num_lt += 1
    }
  }
  num_lt
}

///|
/// `choose_pivot`: median of 3 or recursive pseudo-median (glidesort).
fn Sorter::choose_pivot(self : Sorter, base : Int, len : Int) -> Int {
  let len_div_8 = len / 8
  let a = base
  let b = base + len_div_8 * 4
  let c = base + len_div_8 * 7
  // PSEUDO_MEDIAN_REC_THRESHOLD
  if len < 64 {
    self.median3(a, b, c) - base
  } else {
    self.median3_rec(a, b, c, len_div_8) - base
  }
}

///|
fn Sorter::median3_rec(
  self : Sorter,
  a : Int,
  b : Int,
  c : Int,
  n : Int,
) -> Int {
  let mut a = a
  let mut b = b
  let mut c = c
  if n * 8 >= 64 {
    let n8 = n / 8
    a = self.median3_rec(a, a + n8 * 4, a + n8 * 7, n8)
    b = self.median3_rec(b, b + n8 * 4, b + n8 * 7, n8)
    c = self.median3_rec(c, c + n8 * 4, c + n8 * 7, n8)
  }
  self.median3(a, b, c)
}

///|
fn Sorter::median3(self : Sorter, a : Int, b : Int, c : Int) -> Int {
  let v = self.v
  let x = (self.is_less)(v[a], v[b])
  let y = (self.is_less)(v[a], v[c])
  if x == y {
    let z = (self.is_less)(v[b], v[c])
    if z != x {
      c
    } else {
      b
    }
  } else {
    a
  }
}

///|
/// `heapsort`.
fn Sorter::heapsort(self : Sorter, base : Int, len : Int) -> Unit {
  let mut i = len + len / 2 - 1
  while i >= 0 {
    let sift_idx = if i >= len {
      i - len
    } else {
      self.swap(base, base + i)
      0
    }
    self.sift_down(base, if i < len { i } else { len }, sift_idx)
    i -= 1
  }
}

///|
fn Sorter::sift_down(self : Sorter, base : Int, len : Int, node : Int) -> Unit {
  let v = self.v
  let mut node = node
  while true {
    let mut child = 2 * node + 1
    if child >= len {
      break
    }
    if child + 1 < len && (self.is_less)(v[base + child], v[base + child + 1]) {
      child += 1
    }
    if !(self.is_less)(v[base + node], v[base + child]) {
      break
    }
    self.swap(base + node, base + child)
    node = child
  }
}

///|
/// `insertion_sort_shift_left`: sorts `v[base..base + len]` assuming the
/// first `offset` elements are sorted.
fn Sorter::insertion_sort_shift_left(
  self : Sorter,
  base : Int,
  len : Int,
  offset : Int,
) -> Unit {
  for tail in (base + offset)..<(base + len) {
    self.insert_tail(base, tail)
  }
}

///|
/// `insert_tail`: sorts `[begin, tail]` assuming `[begin, tail)` is sorted.
fn Sorter::insert_tail(self : Sorter, begin : Int, tail : Int) -> Unit {
  let v = self.v
  let mut sift = tail - 1
  if !(self.is_less)(v[tail], v[sift]) {
    return
  }
  let tmp = v[tail]
  let mut gap = tail
  while true {
    v[gap] = v[sift]
    gap = sift
    if sift == begin {
      break
    }
    sift -= 1
    if !(self.is_less)(tmp, v[sift]) {
      break
    }
  }
  v[gap] = tmp
}

///|
/// `swap_if_less`.
fn Sorter::swap_if_less(self : Sorter, a : Int, b : Int) -> Unit {
  if (self.is_less)(self.v[b], self.v[a]) {
    self.swap(a, b)
  }
}

///|
/// `sort9_optimal` (optimal sorting network).
fn Sorter::sort9_optimal(self : Sorter, b : Int) -> Unit {
  let pairs = [
    (0, 3),
    (1, 7),
    (2, 5),
    (4, 8),
    (0, 7),
    (2, 4),
    (3, 8),
    (5, 6),
    (0, 2),
    (1, 3),
    (4, 5),
    (7, 8),
    (1, 4),
    (3, 6),
    (5, 7),
    (0, 1),
    (2, 4),
    (3, 5),
    (6, 8),
    (2, 3),
    (4, 5),
    (6, 7),
    (1, 2),
    (3, 4),
    (5, 6),
  ]
  for p in pairs {
    self.swap_if_less(b + p.0, b + p.1)
  }
}

///|
/// `sort13_optimal` (optimal sorting network).
fn Sorter::sort13_optimal(self : Sorter, b : Int) -> Unit {
  let pairs = [
    (0, 12),
    (1, 10),
    (2, 9),
    (3, 7),
    (5, 11),
    (6, 8),
    (1, 6),
    (2, 3),
    (4, 11),
    (7, 9),
    (8, 10),
    (0, 4),
    (1, 2),
    (3, 6),
    (7, 8),
    (9, 10),
    (11, 12),
    (4, 6),
    (5, 9),
    (8, 11),
    (10, 12),
    (0, 5),
    (3, 8),
    (4, 7),
    (6, 11),
    (9, 10),
    (0, 1),
    (2, 5),
    (6, 9),
    (7, 8),
    (10, 11),
    (1, 3),
    (2, 4),
    (5, 6),
    (9, 10),
    (1, 2),
    (3, 4),
    (5, 7),
    (6, 8),
    (2, 3),
    (4, 5),
    (6, 7),
    (8, 9),
    (3, 4),
    (5, 6),
  ]
  for p in pairs {
    self.swap_if_less(b + p.0, b + p.1)
  }
}

///|
/// `small_sort_network`.
fn Sorter::small_sort_network(self : Sorter, base : Int, len : Int) -> Unit {
  if len < 2 {
    return
  }
  let len_div_2 = len / 2
  let no_merge = len < 18
  let mut region_base = base
  let mut region_len = if no_merge { len } else { len_div_2 }
  while true {
    let presorted_len = if region_len >= 13 {
      self.sort13_optimal(region_base)
      13
    } else if region_len >= 9 {
      self.sort9_optimal(region_base)
      9
    } else {
      1
    }
    self.insertion_sort_shift_left(region_base, region_len, presorted_len)
    if no_merge {
      return
    }
    if region_base != base {
      break
    }
    region_base = base + len_div_2
    region_len = len - len_div_2
  }
  let src = FixedArray::make(len, 0)
  for i in 0..<len {
    src[i] = self.v[base + i]
  }
  let dst = FixedArray::make(len, 0)
  bidirectional_merge(src, dst, self.is_less)
  for i in 0..<len {
    self.v[base + i] = dst[i]
  }
}

///|
/// `bidirectional_merge`: merges the sorted halves `v[..len / 2]` and
/// `v[len / 2..]` into `dst` from both ends (`merge_up` / `merge_down`).
fn bidirectional_merge(
  v : FixedArray[Int],
  dst : FixedArray[Int],
  is_less : (Int, Int) -> Bool,
) -> Unit {
  let len = v.length()
  let len_div_2 = len / 2
  let mut left = 0
  let mut right = len_div_2
  let mut d = 0
  let mut left_rev = len_div_2 - 1
  let mut right_rev = len - 1
  let mut d_rev = len - 1
  for _ in 0..<len_div_2 {
    // merge_up
    let is_l = !is_less(v[right], v[left])
    dst[d] = if is_l { v[left] } else { v[right] }
    if is_l {
      left += 1
    } else {
      right += 1
    }
    d += 1
    // merge_down
    let is_l = !is_less(v[right_rev], v[left_rev])
    dst[d_rev] = if is_l { v[right_rev] } else { v[left_rev] }
    if is_l {
      right_rev -= 1
    } else {
      left_rev -= 1
    }
    d_rev -= 1
  }
  let left_end = left_rev + 1
  // Odd length, so one element is left unconsumed in the input.
  if len % 2 != 0 {
    let left_nonempty = left < left_end
    dst[d] = if left_nonempty { v[left] } else { v[right] }
  }
}
