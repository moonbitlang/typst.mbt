// White-box tests of the deflate internals that were restructured for
// performance, against straightforward ports of upstream's code.

///|
/// Upstream's `fizzle_matches` loop as written (reverse iterators over
/// `window[..n.match_start]` and `window[..n.strstart]` on copies `c`/`n`).
fn ref_fizzle_matches(
  window : FixedArray[Byte],
  max_dist : Int,
  current : Match,
  next : Match,
) -> Unit {
  if current.match_length <= 1 {
    return
  }
  if current.match_length > ((1 + next.match_start) & 0xffff) {
    return
  }
  if current.match_length > ((1 + next.strstart) & 0xffff) {
    return
  }
  let m = -current.match_length + 1 + next.match_start
  let orig = -current.match_length + 1 + next.strstart
  if window[m] != window[orig] {
    return
  }
  let limit = @cmp.maximum(next.strstart - (max_dist & 0xffff), 0)
  let c : Match = { ..current, }
  let n : Match = { ..next, }
  let mut mi = n.match_start
  let mut oi = n.strstart
  let mut changed = 0
  while true {
    let mv = if mi > 0 {
      mi -= 1
      window[mi].to_int()
    } else {
      -1
    }
    let ov = if oi > 0 {
      oi -= 1
      window[oi].to_int()
    } else {
      -1
    }
    if mv != ov {
      break
    }
    if c.match_length < 1 {
      break
    }
    if n.strstart <= limit {
      break
    }
    if n.match_length >= 256 {
      break
    }
    if n.match_start <= 1 {
      break
    }
    n.strstart -= 1
    n.match_start -= 1
    n.match_length += 1
    c.match_length -= 1
    changed += 1
  }
  if changed == 0 {
    return
  }
  if c.match_length <= 1 && n.match_length != 2 {
    n.orgstart = (n.orgstart + 1) & 0xffff
    current.assign(c)
    next.assign(n)
  }
}

///|
test "fizzle_matches matches upstream's loop at every stop condition" {
  // A window of runs of a few byte values, so that backward walks of all
  // lengths occur; every combination of the stop conditions is reached by
  // sweeping the positions, lengths and the distance limit.
  let mut x = 12345U
  let window = FixedArray::makei(700, _ => {
    x = x * 1103515245U + 12345U
    if x >> 28 < 13 {
      b'a'
    } else {
      (b'a'.to_int() + (x >> 30).reinterpret_as_int()).to_byte()
    }
  })
  let mut checked = 0
  let mut moved = 0
  for next_start in [0, 1, 2, 3, 5, 40, 300, 600] {
    for gap in [1, 2, 3, 7, 100] {
      let match_start = next_start - gap
      if match_start < 0 {
        continue
      }
      for cur_len in [0, 1, 2, 3, 4, 9, 40, 300] {
        for next_len in [1, 3, 4, 100, 254, 255, 256] {
          for max_dist in [1, 2, 50, 32506] {
            let cur : Match = {
              match_start: 0,
              match_length: cur_len,
              strstart: 0,
              orgstart: 0,
            }
            let nxt : Match = {
              match_start,
              match_length: next_len,
              strstart: next_start,
              orgstart: next_start,
            }
            let c1 = { ..cur, }
            let n1 = { ..nxt, }
            let c2 = { ..cur, }
            let n2 = { ..nxt, }
            fizzle_matches(window, max_dist, c1, n1)
            ref_fizzle_matches(window, max_dist, c2, n2)
            assert_eq(c1.match_length, c2.match_length)
            assert_eq(n1.match_start, n2.match_start)
            assert_eq(n1.match_length, n2.match_length)
            assert_eq(n1.strstart, n2.strstart)
            assert_eq(n1.orgstart, n2.orgstart)
            checked += 1
            if n1.strstart != next_start {
              moved += 1
            }
          }
        }
      }
    }
  }
  assert_true(checked > 1000)
  // The walk moved the next match in a good share of the cases.
  assert_true(moved > 50)
}
