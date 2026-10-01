// Port of the Thompson NFA compiler and the PikeVM of `regex-automata`
// (`nfa/thompson/compiler.rs`, `nfa/thompson/pikevm.rs`), working on Unicode
// scalar values instead of bytes.

///|
/// An NFA state.
priv enum State {
  /// Match a char in the (non-empty) class and go to `next`.
  Ranges(FixedArray[Int], next~ : Int)
  /// An assertion.
  Look(Look, next~ : Int)
  /// Alternatives in order of preference. If `reverse`, alternatives are
  /// patched in reverse preference order (upstream `UnionReverse`).
  Union(Array[Int], reverse~ : Bool)
  /// Record the current position in a slot.
  Capture(Int, next~ : Int)
  /// An epsilon transition.
  Empty(next~ : Int)
  /// Never matches.
  Fail
  /// A match.
  Match
}

///|
/// A compiled program.
priv struct Nfa {
  states : Array[State]
  start : Int
  /// The number of capture groups (including the implicit group 0).
  group_len : Int
}

///|
/// A start and end state of a compiled sub-expression.
priv struct ThompsonRef {
  start : Int
  end : Int
}

///|
priv struct Compiler {
  states : Array[State]
}

///|
fn Compiler::add(self : Compiler, state : State) -> Int {
  self.states.push(state)
  self.states.length() - 1
}

///|
fn Compiler::add_empty(self : Compiler) -> Int {
  self.add(Empty(next=-1))
}

///|
fn Compiler::add_union(self : Compiler) -> Int {
  self.add(Union([], reverse=false))
}

///|
/// Patch the outgoing transition of `from` to point to `to`.
fn Compiler::patch(self : Compiler, from : Int, to : Int) -> Unit {
  match self.states[from] {
    Ranges(r, ..) => self.states[from] = Ranges(r, next=to)
    Look(l, ..) => self.states[from] = Look(l, next=to)
    Union(alts, reverse~) =>
      if reverse {
        alts.insert(0, to)
      } else {
        alts.push(to)
      }
    Capture(s, ..) => self.states[from] = Capture(s, next=to)
    Empty(..) => self.states[from] = Empty(next=to)
    Fail | Match => ()
  }
}

///|
fn Compiler::add_union_greedy(self : Compiler, greedy : Bool) -> Int {
  self.add(Union([], reverse=!greedy))
}

///|
fn Compiler::c(self : Compiler, hir : Hir) -> ThompsonRef {
  match hir {
    Empty => {
      let id = self.add_empty()
      { start: id, end: id, }
    }
    Literal(cs) => self.c_concat(cs.map(c => Hir::Class(Class::new([(c, c)]))))
    Class(cls) => {
      if cls.ranges.is_empty() {
        let id = self.add(Fail)
        return { start: id, end: id, }
      }
      let flat = FixedArray::make(cls.ranges.length() * 2, 0)
      for i, r in cls.ranges {
        flat[2 * i] = r.0
        flat[2 * i + 1] = r.1
      }
      let id = self.add(Ranges(flat, next=-1))
      { start: id, end: id, }
    }
    Look(look) => {
      let id = self.add(Look(look, next=-1))
      { start: id, end: id, }
    }
    Repetition(min~, max~, greedy~, sub~) =>
      match (min, max) {
        (0, Some(1)) => self.c_zero_or_one(sub, greedy)
        (min, None) => self.c_at_least(sub, greedy, min)
        (min, Some(max)) if min == max => self.c_exactly(sub, min)
        (min, Some(max)) => self.c_bounded(sub, greedy, min, max)
      }
    Capture(index~, sub~) => self.c_cap(index, sub)
    Concat(subs) => self.c_concat(subs)
    Alternation(subs) => self.c_alt(subs)
  }
}

///|
fn Compiler::c_cap(self : Compiler, index : Int, sub : Hir) -> ThompsonRef {
  let start = self.add(Capture(2 * index, next=-1))
  let inner = self.c(sub)
  let end = self.add(Capture(2 * index + 1, next=-1))
  self.patch(start, inner.start)
  self.patch(inner.end, end)
  { start, end, }
}

///|
fn Compiler::c_concat(self : Compiler, subs : Array[Hir]) -> ThompsonRef {
  if subs.is_empty() {
    let id = self.add_empty()
    return { start: id, end: id, }
  }
  let first = self.c(subs[0])
  let mut end = first.end
  for i in 1..<subs.length() {
    let next = self.c(subs[i])
    self.patch(end, next.start)
    end = next.end
  }
  { start: first.start, end, }
}

///|
fn Compiler::c_alt(self : Compiler, subs : Array[Hir]) -> ThompsonRef {
  if subs.length() == 1 {
    return self.c(subs[0])
  }
  let union = self.add_union()
  let end = self.add_empty()
  for sub in subs {
    let compiled = self.c(sub)
    self.patch(union, compiled.start)
    self.patch(compiled.end, end)
  }
  { start: union, end, }
}

///|
fn Compiler::c_exactly(self : Compiler, sub : Hir, n : Int) -> ThompsonRef {
  self.c_concat(Array::make(n, sub))
}

///|
fn Compiler::c_zero_or_one(
  self : Compiler,
  sub : Hir,
  greedy : Bool,
) -> ThompsonRef {
  let union = self.add_union_greedy(greedy)
  let compiled = self.c(sub)
  let empty = self.add_empty()
  self.patch(union, compiled.start)
  self.patch(union, empty)
  self.patch(compiled.end, empty)
  { start: union, end: empty, }
}

///|
fn Compiler::c_bounded(
  self : Compiler,
  sub : Hir,
  greedy : Bool,
  min : Int,
  max : Int,
) -> ThompsonRef {
  let prefix = self.c_exactly(sub, min)
  if min == max {
    return prefix
  }
  let empty = self.add_empty()
  let mut prev_end = prefix.end
  for _ in min..<max {
    let union = self.add_union_greedy(greedy)
    let compiled = self.c(sub)
    self.patch(prev_end, union)
    self.patch(union, compiled.start)
    self.patch(union, empty)
    prev_end = compiled.end
  }
  self.patch(prev_end, empty)
  { start: prefix.start, end: empty, }
}

///|
fn Compiler::c_at_least(
  self : Compiler,
  sub : Hir,
  greedy : Bool,
  n : Int,
) -> ThompsonRef {
  if n == 0 {
    // When the expression cannot match the empty string, then we can get
    // away with something much simpler.
    if sub.minimum_len().map_or(false, len => len > 0) {
      let union = self.add_union_greedy(greedy)
      let compiled = self.c(sub)
      self.patch(union, compiled.start)
      self.patch(compiled.end, union)
      return { start: union, end: union, }
    }
    // Compile x* as (x+)? to preserve the preference order.
    let compiled = self.c(sub)
    let plus = self.add_union_greedy(greedy)
    self.patch(compiled.end, plus)
    self.patch(plus, compiled.start)
    let question = self.add_union_greedy(greedy)
    let empty = self.add_empty()
    self.patch(question, compiled.start)
    self.patch(question, empty)
    self.patch(plus, empty)
    { start: question, end: empty, }
  } else if n == 1 {
    let compiled = self.c(sub)
    let union = self.add_union_greedy(greedy)
    self.patch(compiled.end, union)
    self.patch(union, compiled.start)
    { start: compiled.start, end: union, }
  } else {
    let prefix = self.c_exactly(sub, n - 1)
    let last = self.c(sub)
    let union = self.add_union_greedy(greedy)
    self.patch(prefix.end, last.start)
    self.patch(last.end, union)
    self.patch(union, last.start)
    { start: prefix.start, end: union, }
  }
}

///|
/// Compile a HIR into an NFA, wrapping it in capture group 0.
fn compile(hir : Hir, group_len : Int) -> Nfa {
  let c : Compiler = { states: [], }
  let inner = c.c_cap(0, hir)
  let m = c.add(Match)
  c.patch(inner.end, m)
  { states: c.states, start: inner.start, group_len, }
}

// The PikeVM.

///|
/// A haystack: the chars of a string with their UTF-8 byte offsets.
priv struct Haystack {
  chars : Array[Int]
  /// UTF-8 byte offset of each char position (length `chars.length() + 1`).
  bytes : Array[Int]
  /// UTF-16 offset of each char position (length `chars.length() + 1`).
  utf16 : Array[Int]
}

///|
fn Haystack::new(s : String) -> Haystack {
  let chars = []
  let bytes = [0]
  let utf16 = [0]
  let mut i = 0
  let mut b = 0
  while i < s.length() {
    let (c, next) = @unicode.decode_at(s, i)
    chars.push(c)
    b += if c < 0x80 {
      1
    } else if c < 0x800 {
      2
    } else if c < 0x10000 {
      3
    } else {
      4
    }
    bytes.push(b)
    utf16.push(next)
    i = next
  }
  { chars, bytes, utf16, }
}

///|
/// The char position of a UTF-8 byte offset, if it is a char boundary.
fn Haystack::char_pos(self : Haystack, byte : Int) -> Int? {
  for lo = 0, hi = self.bytes.length(); lo < hi; {
    let mid = lo + (hi - lo) / 2
    let k = self.bytes[mid]
    if byte < k {
      continue lo, mid
    } else if byte > k {
      continue mid + 1, hi
    } else {
      break Some(mid)
    }
  } nobreak {
    None
  }
}

///|
fn is_word_ascii(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
/// Whether the assertion holds at char position `at`.
fn Haystack::look_matches(self : Haystack, look : Look, at : Int) -> Bool {
  let len = self.chars.length()
  let before = (f : (Int) -> Bool) => at > 0 && f(self.chars[at - 1])
  let after = (f : (Int) -> Bool) => at < len && f(self.chars[at])
  let uni = @unicode.is_word_character
  match look {
    Start => at == 0
    End => at == len
    StartLF => at == 0 || self.chars[at - 1] == '\n'
    EndLF => at == len || self.chars[at] == '\n'
    StartCRLF =>
      at == 0 ||
      self.chars[at - 1] == '\n' ||
      (self.chars[at - 1] == '\r' && (at >= len || self.chars[at] != '\n'))
    EndCRLF =>
      at == len ||
      self.chars[at] == '\r' ||
      (self.chars[at] == '\n' && (at == 0 || self.chars[at - 1] != '\r'))
    WordAscii => before(is_word_ascii) != after(is_word_ascii)
    WordAsciiNegate => before(is_word_ascii) == after(is_word_ascii)
    WordUnicode => before(uni) != after(uni)
    WordUnicodeNegate => before(uni) == after(uni)
    WordStartAscii => !before(is_word_ascii) && after(is_word_ascii)
    WordEndAscii => before(is_word_ascii) && !after(is_word_ascii)
    WordStartUnicode => !before(uni) && after(uni)
    WordEndUnicode => before(uni) && !after(uni)
    WordStartHalfAscii => !before(is_word_ascii)
    WordEndHalfAscii => !after(is_word_ascii)
    WordStartHalfUnicode => !before(uni)
    WordEndHalfUnicode => !after(uni)
  }
}

///|
fn ranges_contain(ranges : FixedArray[Int], c : Int) -> Bool {
  let n = ranges.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if c < ranges[2 * mid] {
      continue lo, mid
    } else if c > ranges[2 * mid + 1] {
      continue mid + 1, hi
    } else {
      break true
    }
  } nobreak {
    false
  }
}

///|
/// A set of active states with a slot table (upstream `ActiveStates`).
priv struct ActiveStates {
  /// The states in insertion order.
  dense : Array[Int]
  /// Whether a state is in the set.
  present : FixedArray[Bool]
  /// The capture slots of each state.
  slots : FixedArray[FixedArray[Int]]
}

///|
fn ActiveStates::new(nstates : Int, nslots : Int) -> ActiveStates {
  {
    dense: [],
    present: FixedArray::make(nstates, false),
    slots: FixedArray::makei(nstates, _ => FixedArray::make(nslots, -1)),
  }
}

///|
fn ActiveStates::clear(self : ActiveStates) -> Unit {
  for s in self.dense {
    self.present[s] = false
  }
  self.dense.clear()
}

///|
fn ActiveStates::insert(self : ActiveStates, sid : Int) -> Bool {
  if self.present[sid] {
    return false
  }
  self.present[sid] = true
  self.dense.push(sid)
  true
}

///|
priv enum FollowEpsilon {
  Explore(Int)
  RestoreCapture(Int, Int)
}

///|
/// Compute the epsilon closure of `sid` at position `at` into `next`.
fn Nfa::epsilon_closure(
  self : Nfa,
  hay : Haystack,
  stack : Array[FollowEpsilon],
  curr_slots : FixedArray[Int],
  next : ActiveStates,
  at : Int,
  sid : Int,
) -> Unit {
  stack.push(Explore(sid))
  while stack.pop() is Some(frame) {
    match frame {
      RestoreCapture(slot, offset) => curr_slots[slot] = offset
      Explore(sid) => {
        let mut sid = sid
        while true {
          if !next.insert(sid) {
            break
          }
          match self.states[sid] {
            Fail | Match | Ranges(_, ..) => {
              let dst = next.slots[sid]
              for i in 0..<curr_slots.length() {
                dst[i] = curr_slots[i]
              }
              break
            }
            Look(look, next~) => {
              if !hay.look_matches(look, at) {
                break
              }
              sid = next
            }
            Union(alts, ..) => {
              if alts.is_empty() {
                break
              }
              for i = alts.length() - 1; i >= 1; i = i - 1 {
                stack.push(Explore(alts[i]))
              }
              sid = alts[0]
            }
            Capture(slot, next~) => {
              stack.push(RestoreCapture(slot, curr_slots[slot]))
              curr_slots[slot] = at
              sid = next
            }
            Empty(next~) => sid = next
          }
        }
      }
    }
  }
}

///|
/// Search for the leftmost-first match starting at char position `start`.
/// Returns the capture slots (char positions, -1 if unset).
fn Nfa::search(self : Nfa, hay : Haystack, start : Int) -> FixedArray[Int]? {
  let n = self.states.length()
  let nslots = 2 * self.group_len
  let curr = ActiveStates::new(n, nslots)
  let next = ActiveStates::new(n, nslots)
  let mut curr = curr
  let mut next = next
  let stack = []
  let scratch = FixedArray::make(nslots, -1)
  let mut matched : FixedArray[Int]? = None
  let len = hay.chars.length()
  for at = start; at <= len; at = at + 1 {
    if curr.dense.is_empty() && matched is Some(_) {
      break
    }
    // Simulate the unanchored `(?s:.)*?` prefix.
    if matched is None {
      scratch.fill(-1)
      self.epsilon_closure(hay, stack, scratch, curr, at, self.start)
    }
    // Step over the char at `at`.
    for sid in curr.dense {
      match self.states[sid] {
        Match => {
          matched = Some(curr.slots[sid].copy())
          break
        }
        Ranges(ranges, next=to) =>
          if at < len && ranges_contain(ranges, hay.chars[at]) {
            let slots = curr.slots[sid]
            self.epsilon_closure(hay, stack, slots, next, at + 1, to)
          }
        _ => ()
      }
    }
    let tmp = curr
    curr = next
    next = tmp
    next.clear()
  }
  matched
}
