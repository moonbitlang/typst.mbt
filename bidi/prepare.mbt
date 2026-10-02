// Port of `unicode-bidi 0.3.18`: `prepare.rs`.
//
// 3.3.3 Preparations for Implicit Processing
//
// <http://www.unicode.org/reports/tr9/#Preparations_for_Implicit_Processing>

///|
/// Output of `isolating_run_sequences` (steps X9-X10)
priv struct IsolatingRunSequence {
  runs : Array[Range]
  mut sos : BidiClass // Start-of-sequence type.
  mut eos : BidiClass // End-of-sequence type.
}

///|
fn max_level(a : Level, b : Level) -> Level {
  if a >= b {
    a
  } else {
    b
  }
}

///|
/// Compute the set of isolating run sequences.
///
/// An isolating run sequence is a maximal sequence of level runs such that for all level runs
/// except the last one in the sequence, the last character of the run is an isolate initiator
/// whose matching PDI is the first character of the next level run in the sequence.
///
/// Note: This function does *not* return the sequences in order by their first characters.
fn isolating_run_sequences(
  para_level : Level,
  original_classes : ArrayView[BidiClass],
  levels : MutArrayView[Level],
  runs : Array[Range],
  has_isolate_controls : Bool,
  isolating_run_sequences : Array[IsolatingRunSequence],
) -> Unit {
  // Per http://www.unicode.org/reports/tr9/#BD13:
  // "In the absence of isolate initiators, each isolating run sequence in a paragraph
  //  consists of exactly one level run, and each level run constitutes a separate
  //  isolating run sequence."
  // We can take a simplified path to handle this case.
  if !has_isolate_controls {
    for run in runs {
      // Determine the `sos` and `eos` class for the sequence.
      // <http://www.unicode.org/reports/tr9/#X10>
      let seq_level = levels[run.start +
        position(original_classes, run.start, run.end, not_removed_by_x9).unwrap_or(
          0,
        )]
      let end_level = levels[run.start +
        rposition(original_classes, run.start, run.end, not_removed_by_x9).unwrap_or(
          run.end - run.start - 1,
        )]

      // Get the level of the last non-removed char before the run.
      let pred_level = match
        rposition(original_classes, 0, run.start, not_removed_by_x9) {
        Some(idx) => levels[idx]
        None => para_level
      }

      // Get the level of the next non-removed char after the run.
      let succ_level = match
        position(
          original_classes,
          run.end,
          original_classes.length(),
          not_removed_by_x9,
        ) {
        Some(idx) => levels[run.end + idx]
        None => para_level
      }
      isolating_run_sequences.push({
        runs: [run],
        sos: max_level(seq_level, pred_level).bidi_class(),
        eos: max_level(end_level, succ_level).bidi_class(),
      })
    }
    return
  }

  // Compute the set of isolating run sequences.
  // <http://www.unicode.org/reports/tr9/#BD13>
  let sequences : Array[Array[Range]] = Array(capacity=runs.length())

  // When we encounter an isolate initiator, we push the current sequence onto the
  // stack so we can resume it after the matching PDI.
  let stack : Array[Array[Range]] = [[]]
  for run in runs {
    guard !run.is_empty() else { abort("assertion failed: !run.is_empty()") }
    guard !stack.is_empty() else {
      abort("assertion failed: !stack.is_empty()")
    }
    let start_class = original_classes[run.start]
    // > In rule X10, [..] skip over any BNs when [..].
    // > Do the same when determining if the last character of the sequence is an isolate initiator.
    //
    // <https://www.unicode.org/reports/tr9/#Retaining_Explicit_Formatting_Characters>
    let end_class = match
      rposition(original_classes, run.start, run.end, not_removed_by_x9) {
      Some(k) => original_classes[run.start + k]
      None => start_class
    }
    let sequence = if start_class == PDI && stack.length() > 1 {
      // Continue a previous sequence interrupted by an isolate.
      stack.pop().unwrap()
    } else {
      // Start a new sequence.
      []
    }
    sequence.push(run)
    if end_class is (RLI | LRI | FSI) {
      // Resume this sequence after the isolate.
      stack.push(sequence)
    } else {
      // This sequence is finished.
      sequences.push(sequence)
    }
  }
  // Pop any remaining sequences off the stack.
  for k = stack.length() - 1; k >= 0; k = k - 1 {
    if !stack[k].is_empty() {
      sequences.push(stack[k])
    }
  }

  // Determine the `sos` and `eos` class for each sequence.
  // <http://www.unicode.org/reports/tr9/#X10>
  for sequence in sequences {
    guard !sequence.is_empty() else {
      abort("assertion failed: !sequence.is_empty()")
    }
    let start_of_seq = sequence[0].start
    let runs_len = sequence.length()
    let end_of_seq = sequence[runs_len - 1].end
    let result : IsolatingRunSequence = { runs: sequence, sos: L, eos: L, }

    // > (not counting characters removed by X9)
    let seq_level = levels[result
      .iter_forwards_from(start_of_seq, 0)
      .find_first(i => not_removed_by_x9(original_classes[i]))
      .unwrap_or(start_of_seq)]

    // XXXManishearth the spec talks of a start and end level,
    // but for a given IRS the two should be equivalent, yes?
    let end_level = levels[result
      .iter_backwards_from(end_of_seq, runs_len - 1)
      .find_first(i => not_removed_by_x9(original_classes[i]))
      .unwrap_or(end_of_seq - 1)]

    // Get the level of the last non-removed char before the runs.
    let pred_level = match
      rposition(original_classes, 0, start_of_seq, not_removed_by_x9) {
      Some(idx) => levels[idx]
      None => para_level
    }

    // Get the last non-removed character to check if it is an isolate initiator.
    // The spec calls for an unmatched one, but matched isolate initiators
    // will never be at the end of a level run (otherwise there would be more to the run).
    // We unwrap_or(BN) because BN marks removed classes and it won't matter for the check.
    let last_non_removed = match
      rposition(original_classes, 0, end_of_seq, not_removed_by_x9) {
      Some(idx) => original_classes[idx]
      None => BN
    }

    // Get the level of the next non-removed char after the runs.
    let succ_level = if last_non_removed is (RLI | LRI | FSI) {
      para_level
    } else {
      match
        position(
          original_classes,
          end_of_seq,
          original_classes.length(),
          not_removed_by_x9,
        ) {
        Some(idx) => levels[end_of_seq + idx]
        None => para_level
      }
    }
    result.sos = max_level(seq_level, pred_level).bidi_class()
    result.eos = max_level(end_level, succ_level).bidi_class()
    isolating_run_sequences.push(result)
  }
}

///|
/// The index (relative to `start`) of the first class in `start..end`
/// satisfying `pred`.
fn position(
  classes : ArrayView[BidiClass],
  start : Int,
  end : Int,
  pred : (BidiClass) -> Bool,
) -> Int? {
  for i in start..<end {
    if pred(classes[i]) {
      return Some(i - start)
    }
  }
  None
}

///|
/// The index (relative to `start`) of the last class in `start..end`
/// satisfying `pred`.
fn rposition(
  classes : ArrayView[BidiClass],
  start : Int,
  end : Int,
  pred : (BidiClass) -> Bool,
) -> Int? {
  for i = end - 1; i >= start; i = i - 1 {
    if pred(classes[i]) {
      return Some(i - start)
    }
  }
  None
}

///|
/// Given a text-relative position `pos` and an index of the level run it is in,
/// produce an iterator of all characters after and pos (`pos..`) that are in this
/// run sequence
fn IsolatingRunSequence::iter_forwards_from(
  self : IsolatingRunSequence,
  pos : Int,
  level_run_index : Int,
) -> Iter[Int] {
  // (pos..runs[0].end).chain(runs[1..].iter().flat_map(Clone::clone))
  let runs = self.runs
  let mut k = level_run_index
  let mut i = pos
  Iter::new(() => {
    while k < runs.length() {
      if i < runs[k].end {
        let r = i
        i += 1
        return Some(r)
      }
      k += 1
      if k < runs.length() {
        i = runs[k].start
      }
    }
    None
  })
}

///|
/// Given a text-relative position `pos` and an index of the level run it is in,
/// produce an iterator of all characters before and excludingpos (`..pos`) that are in this
/// run sequence
fn IsolatingRunSequence::iter_backwards_from(
  self : IsolatingRunSequence,
  pos : Int,
  level_run_index : Int,
) -> Iter[Int] {
  // (current.start..pos).rev().chain(prev_runs.iter().rev().flat_map(Clone::clone))
  //
  // Note that the previous runs are visited in reverse order, but each of them
  // front to back.
  let runs = self.runs
  let current_start = runs[level_run_index].start
  let mut i = pos
  let mut k = level_run_index - 1
  let mut j = if k >= 0 { runs[k].start } else { 0 }
  Iter::new(() => {
    if i > current_start {
      i -= 1
      return Some(i)
    }
    while k >= 0 {
      if j < runs[k].end {
        let r = j
        j += 1
        return Some(r)
      }
      k -= 1
      if k >= 0 {
        j = runs[k].start
      }
    }
    None
  })
}

///|
/// Should this character be ignored in steps after X9?
///
/// <http://www.unicode.org/reports/tr9/#X9>
pub fn removed_by_x9(class : BidiClass) -> Bool {
  class is (RLE | LRE | RLO | LRO | PDF | BN)
}

///|
// For use as a predicate for `position` / `rposition`
fn not_removed_by_x9(class : BidiClass) -> Bool {
  !removed_by_x9(class)
}
