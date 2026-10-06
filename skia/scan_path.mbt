// Port of `tiny-skia/src/scan/mod.rs` and `tiny-skia/src/scan/path.rs`.

///|
fn scan_fill_rect(
  rect : @path.Rect,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  if rect.round() is Some(rect) {
    scan_fill_int_rect(rect, clip, blitter)
  }
}

///|
fn scan_fill_int_rect(
  rect : @path.IntRect,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  guard rect.intersect(clip.to_int_rect()) is Some(rect) else { // everything was clipped out
    return
  }
  guard int_rect_to_screen_int_rect(rect) is Some(rect) else { return }
  blitter.blit_rect(rect)
}

///|
fn scan_fill_rect_aa(
  rect : @path.Rect,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  hairline_aa_fill_rect(rect, clip, blitter)
}

///|
fn scan_path_fill_path(
  path : @path.Path,
  fill_rule : FillRule,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  guard conservative_round_to_int(path.bounds()) is Some(ir) else { return }
  let path_contained_in_clip = match int_rect_to_screen_int_rect(ir) {
    Some(bounds) => clip.contains(bounds)
    // If bounds cannot be converted into ScreenIntRect,
    // the path is out of clip.
    None => false
  }

  // TODO: SkScanClipper
  scan_fill_path_impl(
    path,
    fill_rule,
    clip,
    ir.y(),
    ir.bottom(),
    0,
    path_contained_in_clip,
    blitter,
  )
}

///|
/// Conservative rounding function, which effectively nudges the int-rect to
/// be slightly larger than Rect::round() might have produced. This is a
/// safety-net for the scan-converter, which inspects the returned int-rect,
/// and may disable clipping (for speed) if it thinks all of the edges will
/// fit inside the clip's bounds. The scan-converter introduces slight
/// numeric errors due to accumulated += of the slope, so this function is
/// used to return a conservatively large int-bounds, and thus we will only
/// disable clipping if we're sure the edges will stay in-bounds.
fn conservative_round_to_int(src : @path.Rect) -> @path.IntRect? {
  // We must use `from_ltrb`, otherwise rounding will be incorrect.
  @path.IntRect::from_ltrb(
    round_down_to_int(src.left()),
    round_down_to_int(src.top()),
    round_up_to_int(src.right()),
    round_up_to_int(src.bottom()),
  )
}

///|
/// Bias used for conservative rounding of float rects to int rects, to nudge
/// the irects a little larger, so we don't "think" a path's bounds are inside
/// a clip, when (due to numeric drift in the scan-converter) we might walk
/// beyond the predicted limits.
///
/// This value has been determined trial and error: pick the smallest value
/// (after the 0.5) that fixes any problematic cases (e.g. crbug.com/844457)
/// NOTE: cubics appear to be the main reason for needing this slop. If we
/// could (perhaps) have a more accurate walker for cubics, we may be able to
/// reduce this fudge factor.
let conservative_round_bias : Double = 0.5 + 1.5 / fdot6_one.to_double()

///|
/// Round the value down. This is used to round the top and left of a
/// rectangle, and corresponds to the way the scan converter treats the top
/// and left edges. It has a slight bias to make the "rounded" int smaller
/// than a normal round, to create a more conservative int-bounds (larger)
/// from a float rect.
fn round_down_to_int(x : Float) -> Int {
  let xx = x.to_double() - conservative_round_bias
  i32_saturate_from_f64(xx.ceil())
}

///|
/// Round the value up. This is used to round the right and bottom of a
/// rectangle. It has a slight bias to make the "rounded" int smaller than a
/// normal round, to create a more conservative int-bounds (larger) from a
/// float rect.
fn round_up_to_int(x : Float) -> Int {
  let xx = x.to_double() + conservative_round_bias
  i32_saturate_from_f64(xx.floor())
}

///|
/// A stable merge sort (Rust's `slice::sort_by`).
fn[T] stable_sort_by(arr : Array[T], cmp : (T, T) -> Int) -> Unit {
  let n = arr.length()
  if n < 2 {
    return
  }
  let tmp = arr.copy()
  let mut width = 1
  let mut src = arr
  let mut dst = tmp
  while width < n {
    let mut lo = 0
    while lo < n {
      let mid = if lo + width < n { lo + width } else { n }
      let hi = if lo + 2 * width < n { lo + 2 * width } else { n }
      let mut i = lo
      let mut j = mid
      let mut k = lo
      while k < hi {
        if i < mid && (j >= hi || cmp(src[i], src[j]) <= 0) {
          dst[k] = src[i]
          i += 1
        } else {
          dst[k] = src[j]
          j += 1
        }
        k += 1
      }
      lo += 2 * width
    }
    let t = src
    src = dst
    dst = t
    width *= 2
  }
  if !physical_equal(src, arr) {
    for i in 0..<n {
      arr[i] = src[i]
    }
  }
}

///|
fn scan_fill_path_impl(
  path : @path.Path,
  fill_rule : FillRule,
  clip_rect : ScreenIntRect,
  start_y : Int,
  stop_y : Int,
  shift_edges_up : Int,
  path_contained_in_clip : Bool,
  blitter : &Blitter,
) -> Unit {
  guard ShiftedIntRect::new(clip_rect, shift_edges_up) is Some(shifted_clip) else {
    return
  }
  let clip = if path_contained_in_clip { None } else { Some(shifted_clip) }
  guard BasicEdgeBuilder::build_edges(path, clip, shift_edges_up) is Some(edges) else { // no edges to render, just return
    return
  }
  stable_sort_by(edges, (a, b) => {
    let mut value_a = a.first_y
    let mut value_b = b.first_y
    if value_a == value_b {
      value_a = a.x
      value_b = b.x
    }
    value_a.compare(value_b)
  })
  for i in 0..<edges.length() {
    // 0 will be set later, so start with 1.
    edges[i].prev = i + 0
    edges[i].next = i + 2
  }
  let edge_head_y = -2147483648
  let edge_tail_y = 2147483647
  let head = Edge::line_default()
  head.prev = -1
  head.next = 1
  head.x = -2147483648
  head.first_y = edge_head_y
  edges.insert(0, head)
  let tail = Edge::line_default()
  tail.prev = edges.length() - 1
  tail.next = -1
  tail.first_y = edge_tail_y
  edges.push(tail)
  let mut start_y = left_shift(start_y, shift_edges_up)
  let mut stop_y = left_shift(stop_y, shift_edges_up)
  let top = shifted_clip.shifted.y()
  if !path_contained_in_clip && start_y < top {
    start_y = top
  }
  let bottom = shifted_clip.shifted.bottom()
  if !path_contained_in_clip && stop_y > bottom {
    stop_y = bottom
  }
  if start_y < 0 || stop_y < 0 {
    return
  }

  // TODO: walk_simple_edges
  walk_edges(
    fill_rule,
    start_y,
    stop_y,
    shifted_clip.shifted.right(),
    edges,
    blitter,
  )
}

///|
/// TODO: simplify!
fn walk_edges(
  fill_rule : FillRule,
  start_y : Int,
  stop_y : Int,
  right_clip : Int,
  edges : Array[Edge],
  blitter : &Blitter,
) -> Unit {
  let mut curr_y = start_y
  let winding_mask = if fill_rule == EvenOdd { 1 } else { -1 }
  while true {
    let mut w = 0
    let mut left = 0
    let mut prev_x = edges[0].x
    let mut curr_idx = edges[0].next
    while edges[curr_idx].first_y <= curr_y {
      let x = fdot16_round_to_i32(edges[curr_idx].x) // TODO: check
      if (w & winding_mask) == 0 {
        // we're starting interval
        left = x
      }
      w += edges[curr_idx].winding
      if (w & winding_mask) == 0 {
        // we finished an interval
        let width = x - left
        if width != 0 {
          blitter.blit_h(left, curr_y, width)
        }
      }
      let next_idx = edges[curr_idx].next
      let edge = edges[curr_idx]
      if edge.last_y == curr_y {
        // are we done with this edge?
        match edge.kind {
          Line => remove_edge(curr_idx, edges)
          Quadratic =>
            if edge.curve_count > 0 && edge.update_quadratic() {
              let new_x = edge.x
              if new_x < prev_x {
                // ripple current edge backwards until it is x-sorted
                backward_insert_edge_based_on_x(curr_idx, edges)
              } else {
                prev_x = new_x
              }
            } else {
              remove_edge(curr_idx, edges)
            }
          Cubic =>
            if edge.curve_count < 0 && edge.update_cubic() {
              let new_x = edge.x
              if new_x < prev_x {
                // ripple current edge backwards until it is x-sorted
                backward_insert_edge_based_on_x(curr_idx, edges)
              } else {
                prev_x = new_x
              }
            } else {
              remove_edge(curr_idx, edges)
            }
        }
      } else {
        let new_x = edge.x + edge.dx
        edge.x = new_x
        if new_x < prev_x {
          // ripple current edge backwards until it is x-sorted
          backward_insert_edge_based_on_x(curr_idx, edges)
        } else {
          prev_x = new_x
        }
      }
      curr_idx = next_idx
    }
    if (w & winding_mask) != 0 {
      // was our right-edge culled away?
      let width = right_clip - left
      if width != 0 {
        blitter.blit_h(left, curr_y, width)
      }
    }
    curr_y += 1
    if curr_y >= stop_y {
      break
    }

    // now current edge points to the first edge with a Yint larger than
    // curr_y
    insert_new_edges(curr_idx, curr_y, edges)
  }
}

///|
fn remove_edge(curr_idx : Int, edges : Array[Edge]) -> Unit {
  let prev = edges[curr_idx].prev
  let next = edges[curr_idx].next
  edges[prev].next = next
  edges[next].prev = prev
}

///|
fn backward_insert_edge_based_on_x(curr_idx : Int, edges : Array[Edge]) -> Unit {
  let x = edges[curr_idx].x
  let mut prev_idx = edges[curr_idx].prev
  while prev_idx != 0 {
    if edges[prev_idx].x > x {
      prev_idx = edges[prev_idx].prev
    } else {
      break
    }
  }
  let next_idx = edges[prev_idx].next
  if next_idx != curr_idx {
    remove_edge(curr_idx, edges)
    insert_edge_after(curr_idx, prev_idx, edges)
  }
}

///|
fn insert_edge_after(
  curr_idx : Int,
  after_idx : Int,
  edges : Array[Edge],
) -> Unit {
  edges[curr_idx].prev = after_idx
  edges[curr_idx].next = edges[after_idx].next
  let after_next_idx = edges[after_idx].next
  edges[after_next_idx].prev = curr_idx
  edges[after_idx].next = curr_idx
}

///|
/// Start from the right side, searching backwards for the point to begin the
/// new edge list insertion, marching forwards from here. The implementation
/// could have started from the left of the prior insertion, and search to
/// the right, or with some additional caching, binary search the starting
/// point. More work could be done to determine optimal new edge insertion.
fn backward_insert_start(prev_idx : Int, x : Int, edges : Array[Edge]) -> Int {
  let mut prev_idx = prev_idx
  while edges[prev_idx].prev != -1 {
    prev_idx = edges[prev_idx].prev
    if edges[prev_idx].x <= x {
      break
    }
  }
  prev_idx
}

///|
fn insert_new_edges(new_idx : Int, curr_y : Int, edges : Array[Edge]) -> Unit {
  let mut new_idx = new_idx
  if edges[new_idx].first_y != curr_y {
    return
  }
  let prev_idx = edges[new_idx].prev
  if edges[prev_idx].x <= edges[new_idx].x {
    return
  }

  // find first x pos to insert
  let mut start_idx = backward_insert_start(prev_idx, edges[new_idx].x, edges)
  // insert the lot, fixing up the links as we go
  while true {
    let next_idx = edges[new_idx].next
    let mut keep_edge = false
    while true {
      let after_idx = edges[start_idx].next
      if after_idx == new_idx {
        keep_edge = true
        break
      }
      if edges[after_idx].x >= edges[new_idx].x {
        break
      }
      start_idx = after_idx
    }
    if !keep_edge {
      remove_edge(new_idx, edges)
      insert_edge_after(new_idx, start_idx, edges)
    }
    start_idx = new_idx
    new_idx = next_idx
    if edges[new_idx].first_y != curr_y {
      break
    }
  }
}
