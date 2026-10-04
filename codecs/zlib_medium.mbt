// Port of zlib-rs 0.6.8 `src/deflate/algorithm/medium.rs`,
// `src/deflate/longest_match.rs` (the non-`SLOW` variant) and
// `src/deflate/compare256.rs` (all SIMD variants compute the scalar result).
//
// `Match` fields are `u16`s upstream; arithmetic on them wraps (masked with
// 0xffff here).

///|
const EARLY_EXIT_TRIGGER_LEVEL : Int = 5

///|
/// The number of equal leading bytes of `window[a..a + 256]` and
/// `window[b..b + 256]` (upstream `compare256`).
fn compare256(window : FixedArray[Byte], a : Int, b : Int) -> Int {
  if a >= 0 &&
    b >= 0 &&
    a <= window.length() - 256 &&
    b <= window.length() - 256 {
    return compare256_unchecked(window, a, b)
  }
  for i in 0..<256 {
    if window[a + i] != window[b + i] {
      return i
    }
  }
  256
}

///|
/// Find the (length, offset) in the window of the longest match for the
/// string at offset cur_match (upstream `longest_match`). Returns the length
/// and stores the offset in `self.match_start` (what both callers do with
/// upstream's tuple; a MoonBit tuple would be allocated per call).
fn DeflateStream::longest_match(self : DeflateStream, cur_match : Int) -> Int {
  let mut cur_match = cur_match
  let mut match_start = self.match_start
  let strstart = self.strstart
  let wmask = self.w_mask()
  let window = self.window
  let prev = self.prev
  let lookahead = self.lookahead
  let match_offset = 0

  // length of the previous match (if any), hence <= STD_MAX_MATCH
  let mut best_len = if self.prev_length > 0 {
    self.prev_length
  } else {
    STD_MIN_MATCH - 1
  }

  // Calculate read offset which should only extend an extra byte to find the
  // next best match length.
  let mut offset = best_len - 1
  if best_len >= 4 {
    offset -= 2
    if best_len >= 8 {
      offset -= 4
    }
  }
  // mbase_start is the window start; mbase_end is `mbase_start + offset`.
  let mut mbase_end = offset

  // Don't waste too much time by following a chain if we already have a good
  // match
  let mut chain_length = self.max_chain_length
  if best_len >= self.good_match {
    chain_length = chain_length >> 2
  }
  let nice_match = self.nice_match

  // Stop when cur_match becomes <= limit. To simplify the code, we prevent
  // matches with the string of window index 0
  let limit = @cmp.maximum(strstart - self.max_dist(), 0)
  let early_exit = self.level < EARLY_EXIT_TRIGGER_LEVEL
  let scan_start = strstart
  let mut scan_end = strstart + offset
  guard strstart <= @cmp.maximum(self.window_size - MIN_LOOKAHEAD, 0) else {
    abort("need lookahead")
  }
  while true {
    if cur_match >= strstart {
      break
    }
    let mut len = 0
    // first, do a quick check on the start and end bytes. Go to the next item
    // in the chain if these bytes don't match.
    if best_len < 8 {
      let scan_val = read_u64_le(window, scan_start)
      while true {
        let match_val = read_u64_le(window, cur_match)
        let cmp = scan_val ^ match_val
        if cmp == 0 {
          // The first 8 bytes all matched. Additional scanning will be needed
          // (the compare256 call below) to determine the full match length.
          break
        }
        // Compute the number of leading bytes that match.
        let cmp_len = cmp.ctz() / 8
        if cmp_len > best_len {
          // The match is fully contained within the 8 bytes just compared.
          len = cmp_len
          break
        }
        // goto_next_in_chain
        chain_length -= 1
        if chain_length > 0 {
          cur_match = prev.unsafe_get(cur_match & wmask)
          if cur_match > limit {
            continue
          }
        }
        return self.set_match_start(best_len, match_start)
      }
    } else {
      while true {
        if read_u64_le(window, mbase_end + cur_match) ==
          read_u64_le(window, scan_end) &&
          read_u64_le(window, cur_match) == read_u64_le(window, scan_start) {
          break
        }
        // goto_next_in_chain
        chain_length -= 1
        if chain_length > 0 {
          cur_match = prev.unsafe_get(cur_match & wmask)
          if cur_match > limit {
            continue
          }
        }
        return self.set_match_start(best_len, match_start)
      }
    }

    // we know that there is at least some match. Now count how many bytes
    // really match
    if len == 0 {
      len = compare256(window, strstart + 2, cur_match + 2) + 2
    }
    if len > best_len {
      match_start = cur_match - match_offset

      // Do not look for better matches if the current match reaches or
      // exceeds the end of the input.
      if len >= lookahead {
        return self.set_match_start(lookahead, match_start)
      }
      best_len = len
      if best_len >= nice_match {
        return self.set_match_start(best_len, match_start)
      }
      offset = best_len - 1
      if best_len >= 4 {
        offset -= 2
        if best_len >= 8 {
          offset -= 4
        }
      }
      scan_end = strstart + offset
      mbase_end = offset
    } else if early_exit {
      // The probability of finding a match later if we here is pretty low, so
      // for performance it's best to outright stop here for the lower
      // compression levels
      break
    }

    // goto_next_in_chain
    chain_length -= 1
    if chain_length > 0 {
      cur_match = prev.unsafe_get(cur_match & wmask)
      if cur_match > limit {
        continue
      }
    }
    return self.set_match_start(best_len, match_start)
  }
  self.set_match_start(best_len, match_start)
}

///|
#inline
fn DeflateStream::set_match_start(
  self : DeflateStream,
  len : Int,
  match_start : Int,
) -> Int {
  self.match_start = match_start
  len
}

///|
priv struct Match {
  mut match_start : Int
  mut match_length : Int
  mut strstart : Int
  mut orgstart : Int
}

///|
fn Match::assign(self : Match, other : Match) -> Unit {
  self.match_start = other.match_start
  self.match_length = other.match_length
  self.strstart = other.strstart
  self.orgstart = other.orgstart
}

///|
/// Upstream `deflate_medium`.
fn DeflateStream::deflate_medium(
  self : DeflateStream,
  flush : Int,
) -> BlockState {
  // For levels below 5, don't check the next position for a better match
  let early_exit = self.level < 5
  let current_match : Match = {
    match_start: 0,
    match_length: 0,
    strstart: 0,
    orgstart: 0,
  }
  let next_match : Match = {
    match_start: 0,
    match_length: 0,
    strstart: 0,
    orgstart: 0,
  }
  // A scratch copy (upstream passes the `Copy` match by value; reusing it
  // avoids an allocation per match).
  let scratch : Match = {
    match_start: 0,
    match_length: 0,
    strstart: 0,
    orgstart: 0,
  }
  while true {
    // Make sure that we always have enough lookahead, except at the end of
    // the input file. We need STD_MAX_MATCH bytes for the next match, plus
    // WANT_MIN_MATCH bytes to insert the string following the next match.
    if self.lookahead < MIN_LOOKAHEAD {
      self.fill_window()
      if self.lookahead < MIN_LOOKAHEAD && flush == FLUSH_NO {
        return NeedMore
      }
      if self.lookahead == 0 {
        break // flush the current block
      }
      next_match.match_length = 0
    }

    // Insert the string window[strstart .. strstart+2] in the dictionary, and
    // set hash_head to the head of the hash chain:

    // If we already have a future match from a previous round, just use that
    if !early_exit && next_match.match_length > 0 {
      current_match.assign(next_match)
      next_match.match_length = 0
    } else {
      let mut hash_head = 0
      if self.lookahead >= WANT_MIN_MATCH {
        hash_head = self.quick_insert_string(self.strstart)
      }
      current_match.strstart = self.strstart & 0xffff
      current_match.orgstart = current_match.strstart

      // Find the longest match, discarding those <= prev_length. At this
      // point we have always match_length < WANT_MIN_MATCH
      let dist = self.strstart - hash_head
      if dist <= self.max_dist() && dist > 0 && hash_head != 0 {
        // To simplify the code, we prevent matches with the string of window
        // index 0 (in particular we have to avoid a match of the string with
        // itself at the start of the input file).
        let match_length = self.longest_match(hash_head)
        current_match.match_length = match_length & 0xffff
        current_match.match_start = self.match_start
        if current_match.match_length < WANT_MIN_MATCH {
          current_match.match_length = 1
        }
        if current_match.match_start >= current_match.strstart {
          // this can happen due to some restarts
          current_match.match_length = 1
        }
      } else {
        // Set up the match to be a 1 byte literal
        current_match.match_start = 0
        current_match.match_length = 1
      }
    }
    scratch.assign(current_match)
    self.insert_match(scratch)

    // now, look ahead one
    if !early_exit &&
      self.lookahead > MIN_LOOKAHEAD &&
      ((current_match.strstart + current_match.match_length) & 0xffff) <
      self.window_size - MIN_LOOKAHEAD {
      self.strstart = (current_match.strstart + current_match.match_length) &
        0xffff
      let hash_head = self.quick_insert_string(self.strstart)
      next_match.strstart = self.strstart & 0xffff
      next_match.orgstart = next_match.strstart

      // Find the longest match, discarding those <= prev_length. At this
      // point we have always match_length < WANT_MIN_MATCH
      let dist = self.strstart - hash_head
      if dist <= self.max_dist() && dist > 0 && hash_head != 0 {
        let match_length = self.longest_match(hash_head)
        next_match.match_length = match_length & 0xffff
        next_match.match_start = self.match_start
        if next_match.match_start >= next_match.strstart {
          // this can happen due to some restarts
          next_match.match_length = 1
        }
        if next_match.match_length < WANT_MIN_MATCH {
          next_match.match_length = 1
        } else {
          fizzle_matches(
            self.window,
            self.max_dist(),
            current_match,
            next_match,
          )
        }
      } else {
        // Set up the match to be a 1 byte literal
        next_match.match_start = 0
        next_match.match_length = 1
      }
      self.strstart = current_match.strstart
    } else {
      next_match.match_length = 0
    }

    // now emit the current match
    let bflush = self.emit_match(current_match)

    // move the "cursor" forward
    self.strstart += current_match.match_length
    if bflush {
      self.flush_block_only(false)
      if self.avail_out == 0 {
        return NeedMore
      }
    }
  }
  self.insert = @cmp.minimum(self.strstart, STD_MIN_MATCH - 1)
  if flush == FLUSH_FINISH {
    self.flush_block_only(true)
    if self.avail_out == 0 {
      return FinishStarted
    }
    return FinishDone
  }
  if !self.sym_buf.is_empty() {
    self.flush_block_only(false)
    if self.avail_out == 0 {
      return NeedMore
    }
  }
  BlockDone
}

///|
fn DeflateStream::emit_match(self : DeflateStream, m : Match) -> Bool {
  let mut bflush = false
  // matches that are not long enough we need to emit as literals
  if m.match_length < WANT_MIN_MATCH {
    for i in 0..<m.match_length {
      bflush = self.tally_lit(self.window[self.strstart + i].to_int()) || bflush
    }
  } else {
    bflush = self.tally_dist(
        (m.strstart - m.match_start) & 0xffff,
        m.match_length - STD_MIN_MATCH,
      ) ||
      bflush
  }
  self.lookahead -= m.match_length
  bflush
}

///|
fn DeflateStream::insert_match(self : DeflateStream, m : Match) -> Unit {
  if self.lookahead <= m.match_length + WANT_MIN_MATCH {
    return
  }

  // matches that are not long enough we need to emit as literals
  if m.match_length < WANT_MIN_MATCH {
    m.strstart = (m.strstart + 1) & 0xffff
    m.match_length = (m.match_length - 1) & 0xffff
    if m.match_length > 0 && m.strstart >= m.orgstart {
      if ((m.strstart + m.match_length) & 0xffff) > m.orgstart {
        self.insert_string(m.strstart, m.match_length)
      } else {
        self.insert_string(m.strstart, (m.orgstart - m.strstart + 1) & 0xffff)
      }
    }
    return
  }

  // Insert new strings in the hash table only if the match length is not too
  // large. This saves time but degrades compression.
  if m.match_length <= 16 * self.max_insert_length() &&
    self.lookahead >= WANT_MIN_MATCH {
    m.match_length = (m.match_length - 1) & 0xffff // string at strstart already in table
    m.strstart = (m.strstart + 1) & 0xffff
    if m.strstart >= m.orgstart {
      if ((m.strstart + m.match_length) & 0xffff) > m.orgstart {
        self.insert_string(m.strstart, m.match_length)
      } else {
        self.insert_string(m.strstart, (m.orgstart - m.strstart + 1) & 0xffff)
      }
    } else if m.orgstart < ((m.strstart + m.match_length) & 0xffff) {
      self.insert_string(
        m.orgstart,
        (m.strstart + m.match_length - m.orgstart) & 0xffff,
      )
    }
  } else {
    m.strstart = (m.strstart + m.match_length) & 0xffff
    m.match_length = 0
    if m.strstart >= STD_MIN_MATCH - 2 {
      self.quick_insert_string(m.strstart + 2 - STD_MIN_MATCH) |> ignore
    }
    // If lookahead < WANT_MIN_MATCH, ins_h is garbage, but it does not matter
    // since it will be recomputed at next deflate call.
  }
}

///|
fn fizzle_matches(
  window : FixedArray[Byte],
  max_dist : Int,
  current : Match,
  next : Match,
) -> Unit {
  // step zero: sanity checks
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

  // quick exit check.. if this fails then don't bother with anything else
  if window[m] != window[orig] {
    return
  }

  // step one: try to move the "next" match to the left as much as possible
  let limit = @cmp.maximum(next.strstart - (max_dist & 0xffff), 0)
  // Upstream walks `window[..n.match_start]` and `window[..n.strstart]`
  // backwards on copies `c`/`n` of the matches, moving `n` left by one per
  // equal byte pair until `c.match_length < 1`, `n.strstart <= limit`,
  // `n.match_length >= 256` or `n.match_start <= 1`. Those stop conditions
  // only depend on the number of steps taken, so they bound it up front; the
  // pairs read before that bound are in the window (never the exhausted
  // iterators' `None`).
  let steps = @cmp.minimum(
    @cmp.minimum(current.match_length, next.strstart - limit),
    @cmp.minimum(256 - next.match_length, next.match_start - 1),
  )
  guard next.match_start <= window.length() && next.strstart <= window.length() else {
    abort("index out of bounds")
  }
  let mut changed = 0
  while changed < steps &&
        window.unsafe_get(next.match_start - 1 - changed) ==
        window.unsafe_get(next.strstart - 1 - changed) {
    changed += 1
  }
  if changed == 0 {
    return
  }
  if current.match_length - changed <= 1 && next.match_length + changed != 2 {
    next.orgstart = (next.orgstart + 1) & 0xffff
    next.strstart -= changed
    next.match_start -= changed
    next.match_length += changed
    current.match_length -= changed
  }
}
