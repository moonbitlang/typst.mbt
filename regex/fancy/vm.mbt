// Port of `fancy-regex` 0.16.2 `src/vm.rs`: the backtracking VM for
// implementing fancy regexes.
//
// Read <https://swtch.com/~rsc/regexp/regexp2.html> for a good introduction
// for how this works.
//
// The VM executes a sequence of instructions (a program) against an input
// string. It keeps track of a program counter (PC) and an index into the
// string (IX). Execution can have one or more threads.
//
// One of the basic instructions is `Lit`, which matches a string against the
// input. If it matches, the PC advances to the next instruction and the IX to
// the position after the matched string. If not, the current thread is
// stopped because it failed.
//
// If execution reaches an `End` instruction, the program is successful
// because a match was found. If there are no more threads to execute, the
// program has failed to match.
//
// The `Split` instruction causes execution to split into two threads. The
// first thread is executed with the current string index. If it fails, we
// reset the string index and resume execution with the second thread. That is
// what "backtracking" refers to. In order to do that, we keep a stack of
// threads (PC and IX) to try.
//
// Deviation: upstream works on UTF-8 byte offsets of a `&str`. Here IX is a
// char (Unicode scalar value) index into a `@regex.Haystack`; since every
// instruction moves by whole chars this is equivalent, and positions are
// converted to byte offsets at the API boundary.

///|
/// Enable tracing of VM execution. Only for debugging/investigating.
const OPTION_TRACE : Int = 1

///|
/// When iterating over all matches within a text (e.g. with `find_iter`),
/// empty matches need to be handled specially. If we kept matching at the
/// same position, we'd never stop. So what we do after we've had an empty
/// match, is to advance the position where matching is attempted. If `\G` is
/// used in the pattern, that means it no longer matches. If we didn't tell
/// the VM about the fact that we skipped because of an empty match, it would
/// still treat `\G` as matching. So this option is for communicating that to
/// the VM. Phew.
const OPTION_SKIPPED_EMPTY_MATCH : Int = 2

///|
// TODO: make configurable
const MAX_STACK : Int = 1_000_000

///|
/// Delegate matching to the regex crate
pub struct Delegate {
  /// The regex
  inner : @regex.Regex
  /// The regex pattern as a string
  pattern : String
  /// The first group number that this regex captures (if it contains groups)
  start_group : Int
  /// The last group number
  end_group : Int
  /// Reusable slot buffer for searches.
  priv slots : FixedArray[Int]
}

///|
/// Instruction of the VM.
pub(all) enum Insn {
  /// Successful end of program
  End
  /// Match any character (including newline)
  Any
  /// Match any character (not including newline)
  AnyNoNL
  /// Assertions
  Assertion(Assertion)
  /// Match the literal string at the current index
  Lit(String)
  /// Split execution into two threads. The two fields are positions of
  /// instructions. Execution first tries the first thread. If that fails, the
  /// second position is tried.
  Split(Int, Int)
  /// Jump to instruction at position
  Jmp(Int)
  /// Save the current string index into the specified slot
  Save(Int)
  /// Save `0` into the specified slot
  Save0(Int)
  /// Set the string index to the value that was saved in the specified slot
  Restore(Int)
  /// Repeat greedily (match as much as possible)
  RepeatGr(lo~ : Int, hi~ : Int, next~ : Int, repeat~ : Int)
  /// Repeat non-greedily (prefer matching as little as possible)
  RepeatNg(lo~ : Int, hi~ : Int, next~ : Int, repeat~ : Int)
  /// Repeat greedily and prevent infinite loops from empty matches
  RepeatEpsilonGr(lo~ : Int, next~ : Int, repeat~ : Int, check~ : Int)
  /// Repeat non-greedily and prevent infinite loops from empty matches
  RepeatEpsilonNg(lo~ : Int, next~ : Int, repeat~ : Int, check~ : Int)
  /// Negative look-around failed
  FailNegativeLookAround
  /// Set IX back by the specified number of characters
  GoBack(Int)
  /// Back reference to a group number to check (`slot`: the save slot
  /// representing the start of the capture group)
  Backref(slot~ : Int, casei~ : Bool)
  /// Begin of atomic group
  BeginAtomic
  /// End of atomic group
  EndAtomic
  /// Delegate matching to the regex crate
  Delegate(Delegate)
  /// Anchor to match at the position where the previous match ended
  ContinueFromPreviousMatchEnd
  /// Continue only if the specified capture group has already been populated
  /// as part of the match
  BackrefExistsCondition(Int)
}

///|
pub impl Show for Insn with fn output(self, logger) {
  match self {
    End => logger.write_string("End")
    Any => logger.write_string("Any")
    AnyNoNL => logger.write_string("AnyNoNL")
    Assertion(a) => logger.write_string("Assertion(\{Repr(a)})")
    Lit(s) => logger.write_string("Lit(\{@unicode.rust_debug_str(s)})")
    Split(x, y) => logger.write_string("Split(\{x}, \{y})")
    Jmp(x) => logger.write_string("Jmp(\{x})")
    Save(x) => logger.write_string("Save(\{x})")
    Save0(x) => logger.write_string("Save0(\{x})")
    Restore(x) => logger.write_string("Restore(\{x})")
    RepeatGr(lo~, hi~, next~, repeat~) =>
      logger.write_string(
        "RepeatGr { lo: \{lo}, hi: \{hi}, next: \{next}, repeat: \{repeat} }",
      )
    RepeatNg(lo~, hi~, next~, repeat~) =>
      logger.write_string(
        "RepeatNg { lo: \{lo}, hi: \{hi}, next: \{next}, repeat: \{repeat} }",
      )
    RepeatEpsilonGr(lo~, next~, repeat~, check~) =>
      logger.write_string(
        "RepeatEpsilonGr { lo: \{lo}, next: \{next}, repeat: \{repeat}, check: \{check} }",
      )
    RepeatEpsilonNg(lo~, next~, repeat~, check~) =>
      logger.write_string(
        "RepeatEpsilonNg { lo: \{lo}, next: \{next}, repeat: \{repeat}, check: \{check} }",
      )
    FailNegativeLookAround => logger.write_string("FailNegativeLookAround")
    GoBack(x) => logger.write_string("GoBack(\{x})")
    Backref(slot~, casei~) =>
      logger.write_string("Backref { slot: \{slot}, casei: \{casei} }")
    BeginAtomic => logger.write_string("BeginAtomic")
    EndAtomic => logger.write_string("EndAtomic")
    Delegate(d) =>
      logger.write_string(
        "Delegate(Delegate { pattern: \{@unicode.rust_debug_str(d.pattern)}, start_group: \{d.start_group}, end_group: \{d.end_group} })",
      )
    ContinueFromPreviousMatchEnd =>
      logger.write_string("ContinueFromPreviousMatchEnd")
    BackrefExistsCondition(x) =>
      logger.write_string("BackrefExistsCondition(\{x})")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Insn with Show::{to_string, output}

///|
/// Sequence of instructions for the VM to execute.
pub struct Prog {
  /// Instructions of the program
  body : Array[Insn]
  priv n_saves : Int
  /// The chars of each `Lit` instruction (indexed by pc).
  priv lits : Array[FixedArray[Int]]
  /// The reusable VM state.
  priv state : Ref[State?]
}

///|
fn Prog::new(body : Array[Insn], n_saves : Int) -> Prog {
  let lits = body.map(insn => {
    match insn {
      Lit(s) => {
        let cs = []
        for c in s {
          cs.push(c.to_int())
        }
        FixedArray::from_array(cs)
      }
      _ => []
    }
  })
  { body, n_saves, lits, state: { val: None, }, }
}

///|
/// Print the program (for debugging).
pub fn Prog::debug_print(self : Prog, writer : StringBuilder) -> Unit {
  for i, insn in self.body {
    let n = i.to_string()
    writer.write_string(" ".repeat(3 - n.length()) + n)
    writer.write_string(": \{insn}\n")
  }
}

///|
priv struct State {
  /// Saved values indexed by slot. Mostly indices to s, but can be repeat
  /// values etc. Always contains the saves of the current state.
  saves : Array[Int]
  /// Stack of backtrack branches (pc, ix, nsave).
  stack_pc : Array[Int]
  stack_ix : Array[Int]
  stack_nsave : Array[Int]
  /// Old saves (slot, value)
  oldsave_slot : Array[Int]
  oldsave_value : Array[Int]
  /// Number of saves at the end of `oldsave` that need to be restored to
  /// `saves` on pop
  mut nsave : Int
  explicit_sp : Int
  /// Maximum size of the stack. If the size would be exceeded during
  /// execution, a `StackOverflow` error is raised.
  max_stack : Int
  /// Scratch for `backtrack_cut`: the stamp at which a slot was last seen.
  seen : Array[Int]
  mut stamp : Int
}

// Each element in the stack conceptually represents the entire state
// of the machine: the pc (index into prog), the index into the
// string, and the entire vector of saves. However, copying the save
// vector on every push/pop would be inefficient, so instead we use a
// copy-on-write approach for each slot within the save vector. The
// top `nsave` elements in `oldsave` represent the delta from the
// current machine state to the top of stack.

///|
fn State::new(n_saves : Int, max_stack : Int) -> State {
  {
    saves: Array::make(n_saves, USIZE_MAX),
    stack_pc: [],
    stack_ix: [],
    stack_nsave: [],
    oldsave_slot: [],
    oldsave_value: [],
    nsave: 0,
    explicit_sp: n_saves,
    max_stack,
    seen: [],
    stamp: 0,
  }
}

///|
/// Reset to the state of `State::new`.
fn State::reset(self : State) -> Unit {
  self.saves.truncate(self.explicit_sp)
  self.saves.fill(USIZE_MAX)
  self.stack_pc.clear()
  self.stack_ix.clear()
  self.stack_nsave.clear()
  self.oldsave_slot.clear()
  self.oldsave_value.clear()
  self.nsave = 0
}

///|
/// push a backtrack branch
fn State::push(self : State, pc : Int, ix : Int) -> Unit raise FancyError {
  if self.stack_pc.length() < self.max_stack {
    self.stack_pc.push(pc)
    self.stack_ix.push(ix)
    self.stack_nsave.push(self.nsave)
    self.nsave = 0
  } else {
    raise FancyError::RuntimeError(StackOverflow)
  }
}

///|
/// pop a backtrack branch
fn State::pop(self : State) -> (Int, Int) {
  for _ in 0..<self.nsave {
    let slot = self.oldsave_slot.unsafe_pop()
    let value = self.oldsave_value.unsafe_pop()
    self.saves[slot] = value
  }
  let pc = self.stack_pc.unsafe_pop()
  let ix = self.stack_ix.unsafe_pop()
  self.nsave = self.stack_nsave.unsafe_pop()
  (pc, ix)
}

///|
fn State::save(self : State, slot : Int, val : Int) -> Unit {
  let len = self.oldsave_slot.length()
  for i in 0..<self.nsave {
    // could avoid this iteration with some overhead; worth it?
    if self.oldsave_slot[len - i - 1] == slot {
      // already saved, just update
      self.saves[slot] = val
      return
    }
  }
  self.oldsave_slot.push(slot)
  self.oldsave_value.push(self.saves[slot])
  self.nsave += 1
  self.saves[slot] = val
}

///|
fn State::get(self : State, slot : Int) -> Int {
  self.saves[slot]
}

///|
/// push a value onto the explicit stack; note: the entire contents of
/// the explicit stack is saved and restored on backtrack.
fn State::stack_push(self : State, val : Int) -> Unit {
  if self.saves.length() == self.explicit_sp {
    self.saves.push(self.explicit_sp + 1)
  }
  let explicit_sp = self.explicit_sp
  let sp = self.get(explicit_sp)
  if self.saves.length() == sp {
    self.saves.push(val)
  } else {
    self.save(sp, val)
  }
  self.save(explicit_sp, sp + 1)
}

///|
/// pop a value from the explicit stack
fn State::stack_pop(self : State) -> Int {
  let explicit_sp = self.explicit_sp
  let sp = self.get(explicit_sp) - 1
  let result = self.get(sp)
  self.save(explicit_sp, sp)
  result
}

///|
/// Get the current number of backtrack branches
fn State::backtrack_count(self : State) -> Int {
  self.stack_pc.length()
}

///|
/// Discard backtrack branches that were pushed since the call to
/// `backtrack_count`.
///
/// What we want:
/// * Keep the current `saves` as they are
/// * Only keep `count` backtrack branches on `stack`, discard the rest
/// * Keep the first `oldsave` for each slot, discard the rest (multiple
///   pushes might have happened with saves to the same slot)
fn State::backtrack_cut(self : State, count : Int) -> Unit {
  if self.stack_pc.length() == count {
    // no backtrack branches to discard, all good
    return
  }
  // start and end indexes of old saves for the branch we're cutting to
  let mut oldsave_end = self.oldsave_slot.length() - self.nsave
  for i in (count + 1)..<self.stack_nsave.length() {
    oldsave_end -= self.stack_nsave[i]
  }
  let oldsave_start = oldsave_end - self.stack_nsave[count]
  self.stamp += 1
  let stamp = self.stamp
  while self.seen.length() < self.saves.length() {
    self.seen.push(0)
  }
  // keep all the old saves of our branch (they're all for different slots)
  for i in oldsave_start..<oldsave_end {
    self.seen[self.oldsave_slot[i]] = stamp
  }
  let mut oldsave_ix = oldsave_end
  // for other old saves, keep them only if they're for a slot that we haven't saved yet
  for ix in oldsave_end..<self.oldsave_slot.length() {
    let slot = self.oldsave_slot[ix]
    if self.seen[slot] != stamp {
      self.seen[slot] = stamp
      // put the save we want to keep (ix) after the ones we already have (oldsave_ix)
      // note that it's fine if the indexes are the same (then swapping is a no-op)
      self.oldsave_slot.swap(oldsave_ix, ix)
      self.oldsave_value.swap(oldsave_ix, ix)
      oldsave_ix += 1
    }
  }
  self.stack_pc.truncate(count)
  self.stack_ix.truncate(count)
  self.stack_nsave.truncate(count)
  self.oldsave_slot.truncate(oldsave_ix)
  self.oldsave_value.truncate(oldsave_ix)
  self.nsave = oldsave_ix - oldsave_start
}

///|
/// Whether the chars of `literal` occur in `s` at `ix`.
fn matches_literal(
  s : @regex.Haystack,
  ix : Int,
  literal : FixedArray[Int],
) -> Bool {
  let n = literal.length()
  if ix + n > s.char_len() {
    return false
  }
  for i in 0..<n {
    if s.char_at(ix + i) != literal[i] {
      return false
    }
  }
  true
}

///|
/// Whether the text of the chars `lo..hi` of `s` occurs at `ix`.
fn matches_backref(s : @regex.Haystack, ix : Int, lo : Int, hi : Int) -> Bool {
  let n = hi - lo
  if ix + n > s.char_len() {
    return false
  }
  for i in 0..<n {
    if s.char_at(ix + i) != s.char_at(lo + i) {
      return false
    }
  }
  true
}

///|
/// Case-insensitive backref check (upstream `matches_literal_casei` with
/// `literal = &s[lo..hi]` and `end = ix + literal.len()` in bytes). Returns
/// the char position of `end` on success.
fn matches_literal_casei(
  s : @regex.Haystack,
  ix : Int,
  lo : Int,
  hi : Int,
) -> Int? {
  let literal_bytes = s.byte_offset(hi) - s.byte_offset(lo)
  let end_byte = s.byte_offset(ix) + literal_bytes
  if end_byte > s.byte_len() {
    return None
  }
  if matches_backref(s, ix, lo, hi) {
    return Some(ix + (hi - lo))
  }
  guard s.char_pos(end_byte) is Some(end) else { return None }
  let mut ascii = true
  for i in ix..<end {
    if s.char_at(i) >= 0x80 {
      ascii = false
      break
    }
  }
  if ascii {
    // `eq_ignore_ascii_case` compares bytewise.
    if end - ix != hi - lo {
      return None
    }
    for i in 0..<(end - ix) {
      if ascii_lower(s.char_at(ix + i)) != ascii_lower(s.char_at(lo + i)) {
        return None
      }
    }
    return Some(end)
  }

  // text captured and being backreferenced is not ascii, so we utilize
  // case insensitive matching of the regex engine
  let pattern = StringBuilder()
  escape_into(s.substring(lo, hi), pattern)
  let re = @regex.Regex::new_with(pattern.to_string(), case_insensitive=true) catch {
    _ => abort("literal hir should get built successfully")
  }
  if re.is_match(s.substring(ix, end)) {
    Some(end)
  } else {
    None
  }
}

///|
fn ascii_lower(c : Int) -> Int {
  if c >= 'A' && c <= 'Z' {
    c + 32
  } else {
    c
  }
}

///|
fn is_word_char_at(s : @regex.Haystack, i : Int) -> Bool {
  i >= 0 && i < s.char_len() && @unicode.is_word_character(s.char_at(i))
}

///|
/// Whether `assertion` holds at char position `ix` (upstream: the
/// `regex_automata` `LookMatcher`).
fn assertion_matches(
  s : @regex.Haystack,
  assertion : Assertion,
  ix : Int,
) -> Bool {
  let len = s.char_len()
  match assertion {
    StartText => ix == 0
    EndText => ix == len
    StartLine(crlf=false) => ix == 0 || s.char_at(ix - 1) == '\n'
    StartLine(crlf=true) =>
      ix == 0 ||
      s.char_at(ix - 1) == '\n' ||
      (s.char_at(ix - 1) == '\r' && (ix >= len || s.char_at(ix) != '\n'))
    EndLine(crlf=false) => ix == len || s.char_at(ix) == '\n'
    EndLine(crlf=true) =>
      ix == len ||
      s.char_at(ix) == '\r' ||
      (s.char_at(ix) == '\n' && (ix == 0 || s.char_at(ix - 1) != '\r'))
    LeftWordBoundary => !is_word_char_at(s, ix - 1) && is_word_char_at(s, ix)
    RightWordBoundary => is_word_char_at(s, ix - 1) && !is_word_char_at(s, ix)
    WordBoundary => is_word_char_at(s, ix - 1) != is_word_char_at(s, ix)
    NotWordBoundary => is_word_char_at(s, ix - 1) == is_word_char_at(s, ix)
  }
}

///|
/// Run the program with options. `pos` is a char position; the returned
/// saves are char positions (`USIZE_MAX` if unset).
fn run(
  prog : Prog,
  s : @regex.Haystack,
  pos : Int,
  option_flags : Int,
  options : RegexOptions,
) -> Array[Int]? raise FancyError {
  let state = match prog.state.val {
    Some(state) => {
      state.reset()
      state
    }
    None => {
      let state = State::new(prog.n_saves, MAX_STACK)
      prog.state.val = Some(state)
      state
    }
  }
  let trace = (option_flags & OPTION_TRACE) != 0
  if trace {
    println("pos\tinstruction")
  }
  let body = prog.body
  let len = s.char_len()
  let mut backtrack_count = 0
  let mut pc = 0
  let mut ix = pos
  while true {
    // break from this loop to fail, causes stack to pop
    while true {
      if trace {
        println("\{ix}\t\{pc} \{body[pc]}")
      }
      match body[pc] {
        End => {
          // save of end position into slot 1 is now done
          // with an explicit group; we might want to
          // optimize that.
          if state.saves.length() > 1 {
            let slot1 = state.saves[1]
            // With some features like keep out (\K), the match start can be after
            // the match end. Cap the start to <= end.
            if state.get(0) > slot1 {
              state.save(0, slot1)
            }
          }
          return Some(state.saves.copy())
        }
        Any => if ix < len { ix += 1 } else { break }
        AnyNoNL =>
          if ix < len && s.char_at(ix) != '\n' {
            ix += 1
          } else {
            break
          }
        Lit(_) => {
          let lit = prog.lits[pc]
          if !matches_literal(s, ix, lit) {
            break
          }
          ix = ix + lit.length()
        }
        Assertion(assertion) =>
          if !assertion_matches(s, assertion, ix) {
            break
          }
        Split(x, y) => {
          state.push(y, ix)
          pc = x
          continue
        }
        Jmp(target) => {
          pc = target
          continue
        }
        Save(slot) => state.save(slot, ix)
        Save0(slot) => state.save(slot, 0)
        Restore(slot) => ix = state.get(slot)
        RepeatGr(lo~, hi~, next~, repeat~) => {
          let repcount = state.get(repeat)
          if repcount == hi {
            pc = next
            continue
          }
          state.save(repeat, repcount + 1)
          if repcount >= lo {
            state.push(next, ix)
          }
        }
        RepeatNg(lo~, hi~, next~, repeat~) => {
          let repcount = state.get(repeat)
          if repcount == hi {
            pc = next
            continue
          }
          state.save(repeat, repcount + 1)
          if repcount >= lo {
            state.push(pc + 1, ix)
            pc = next
            continue
          }
        }
        RepeatEpsilonGr(lo~, next~, repeat~, check~) => {
          let repcount = state.get(repeat)
          if repcount > 0 && state.get(check) == ix {
            // zero-length match on repeat, then move to next instruction
            pc = next
            continue
          }
          state.save(repeat, repcount + 1)
          if repcount >= lo {
            state.save(check, ix)
            state.push(next, ix)
          }
        }
        RepeatEpsilonNg(lo~, next~, repeat~, check~) => {
          let repcount = state.get(repeat)
          if repcount > 0 && state.get(check) == ix {
            // zero-length match on repeat, then move to next instruction
            pc = next
            continue
          }
          state.save(repeat, repcount + 1)
          if repcount >= lo {
            state.save(check, ix)
            state.push(pc + 1, ix)
            pc = next
            continue
          }
        }
        GoBack(count) => {
          let mut ok = true
          for _ in 0..<count {
            if ix == 0 {
              ok = false
              break
            }
            ix -= 1
          }
          if !ok {
            break
          }
        }
        FailNegativeLookAround => {
          // Reaching this instruction means that the body of the
          // look-around matched. Because it's a *negative* look-around,
          // that means the look-around itself should fail (not match).
          // But before, we need to discard all the states that have
          // been pushed with the look-around, because we don't want to
          // explore them.
          while true {
            let (popped_pc, _) = state.pop()
            if popped_pc == pc + 1 {
              // We've reached the state that would jump us to
              // after the look-around (in case the look-around
              // succeeded). That means we popped enough states.
              break
            }
          }
          break
        }
        Backref(slot~, casei~) => {
          let lo = state.get(slot)
          if lo == USIZE_MAX {
            // Referenced group hasn't matched, so the backref doesn't match either
            break
          }
          let hi = state.get(slot + 1)
          if hi == USIZE_MAX || lo > hi {
            // Referenced group hasn't matched, so the backref doesn't match either
            break
          }
          if casei {
            match matches_literal_casei(s, ix, lo, hi) {
              Some(end) => ix = end
              None => break
            }
          } else {
            if !matches_backref(s, ix, lo, hi) {
              break
            }
            ix = ix + (hi - lo)
          }
        }
        BackrefExistsCondition(group) => {
          let lo = state.get(group * 2)
          if lo == USIZE_MAX {
            // Referenced group hasn't matched, so the backref doesn't match either
            break
          }
        }
        BeginAtomic => {
          let count = state.backtrack_count()
          state.stack_push(count)
        }
        EndAtomic => {
          let count = state.stack_pop()
          state.backtrack_cut(count)
        }
        Delegate(d) => {
          let inner_slots = d.slots
          if !d.inner.search_slots(s, ix, anchored=true, inner_slots) {
            break
          }
          if d.start_group != d.end_group {
            for i in 0..<(d.end_group - d.start_group) {
              let slot = (d.start_group + i) * 2
              let start = inner_slots[(i + 1) * 2]
              if start >= 0 {
                let end = inner_slots[(i + 1) * 2 + 1]
                state.save(slot, start)
                state.save(slot + 1, end)
              } else {
                state.save(slot, USIZE_MAX)
                state.save(slot + 1, USIZE_MAX)
              }
            }
          }
          ix = inner_slots[1]
        }
        ContinueFromPreviousMatchEnd =>
          if ix > pos || (option_flags & OPTION_SKIPPED_EMPTY_MATCH) != 0 {
            break
          }
      }
      pc += 1
    }
    if trace {
      println("fail")
    }
    // "break 'fail" goes here
    if state.stack_pc.is_empty() {
      return None
    }
    backtrack_count += 1
    if backtrack_count > options.backtrack_limit {
      raise FancyError::RuntimeError(BacktrackLimitExceeded)
    }
    let (newpc, newix) = state.pop()
    pc = newpc
    ix = newix
  }
  None
}

///|
/// Run the program with trace printing for debugging (`pos` is a char
/// position).
pub fn run_trace(
  prog : Prog,
  s : @regex.Haystack,
  pos : Int,
) -> Array[Int]? raise FancyError {
  run(prog, s, pos, OPTION_TRACE, RegexOptions::default())
}

///|
/// Run the program with default options (`pos` is a char position).
pub fn run_default(
  prog : Prog,
  s : @regex.Haystack,
  pos : Int,
) -> Array[Int]? raise FancyError {
  run(prog, s, pos, 0, RegexOptions::default())
}
