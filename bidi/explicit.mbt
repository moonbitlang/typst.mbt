// Port of `unicode-bidi 0.3.18`: `explicit.rs`.
//
// 3.3.2 Explicit Levels and Directions
//
// <http://www.unicode.org/reports/tr9/#Explicit_Levels_and_Directions>

///|
/// Compute explicit embedding levels for one paragraph of text (X1-X8), and identify
/// level runs (BD7) for use when determining Isolating Run Sequences (X10).
///
/// `processing_classes[i]` must contain the `BidiClass` of the char at byte index `i`,
/// for each char in `text`.
///
/// `runs` returns the list of level runs (BD7) of the text.
fn explicit_compute(
  text : TextSlice,
  para_level : Level,
  original_classes : ArrayView[BidiClass],
  levels : MutArrayView[Level],
  processing_classes : MutArrayView[BidiClass],
  runs : Array[Range],
) -> Unit {
  guard text.len() == original_classes.length() else {
    abort("assertion failed: text.len() == original_classes.len()")
  }

  // <http://www.unicode.org/reports/tr9/#X1>
  let stack : Array[Status] = [{ level: para_level, status: Neutral, }]
  let mut overflow_isolate_count = 0
  let mut overflow_embedding_count = 0
  let mut valid_isolate_count = 0
  let mut current_run_level = Level::ltr()
  let mut current_run_start = 0
  for pair in text.char_indices() {
    let (i, c) = pair
    let len = utf8_char_len(c)
    let last = stack.last().unwrap()
    match original_classes[i] {
      // Rules X2-X5c
      RLE | LRE | RLO | LRO | RLI | LRI | FSI => {
        // <https://www.unicode.org/reports/tr9/#Retaining_Explicit_Formatting_Characters>
        levels[i] = last.level

        // X5a-X5c: Isolate initiators get the level of the last entry on the stack.
        let is_isolate = original_classes[i] is (RLI | LRI | FSI)
        if is_isolate {
          // Redundant due to "Retaining explicit formatting characters" step.
          // levels[i] = last.level;
          match last.status {
            RTL => processing_classes[i] = R
            LTR => processing_classes[i] = L
            _ => ()
          }
        }
        let new_level = if is_rtl(original_classes[i]) {
          last.level.new_explicit_next_rtl()
        } else {
          last.level.new_explicit_next_ltr()
        }
        if new_level is Ok(new_level) &&
          overflow_isolate_count == 0 &&
          overflow_embedding_count == 0 {
          stack.push({
            level: new_level,
            status: match original_classes[i] {
              RLO => RTL
              LRO => LTR
              RLI | LRI | FSI => Isolate
              _ => Neutral
            },
          })
          if is_isolate {
            valid_isolate_count += 1
          } else {
            // The spec doesn't explicitly mention this step, but it is necessary.
            // See the reference implementations for comparison.
            levels[i] = new_level
          }
        } else if is_isolate {
          overflow_isolate_count += 1
        } else if overflow_isolate_count == 0 {
          overflow_embedding_count += 1
        }
        if !is_isolate {
          // X9 +
          // <https://www.unicode.org/reports/tr9/#Retaining_Explicit_Formatting_Characters>
          // (PDF handled below)
          processing_classes[i] = BN
        }
      }

      // <http://www.unicode.org/reports/tr9/#X6a>
      PDI => {
        if overflow_isolate_count > 0 {
          overflow_isolate_count -= 1
        } else if valid_isolate_count > 0 {
          overflow_embedding_count = 0
          while true {
            match stack.pop() {
              None | Some({ status: Isolate, .. }) => break
              _ => ()
            }
          }
          valid_isolate_count -= 1
        }
        let last = stack.last().unwrap()
        levels[i] = last.level
        match last.status {
          RTL => processing_classes[i] = R
          LTR => processing_classes[i] = L
          _ => ()
        }
      }

      // <http://www.unicode.org/reports/tr9/#X7>
      PDF => {
        if overflow_isolate_count > 0 {
          // do nothing
        } else if overflow_embedding_count > 0 {
          overflow_embedding_count -= 1
        } else if last.status != Isolate && stack.length() >= 2 {
          ignore(stack.pop())
        }

        // <https://www.unicode.org/reports/tr9/#Retaining_Explicit_Formatting_Characters>
        levels[i] = stack.last().unwrap().level
        // X9 part of retaining explicit formatting characters.
        processing_classes[i] = BN
      }

      // Nothing.
      // BN case moved down to X6, see <https://www.unicode.org/reports/tr9/#Retaining_Explicit_Formatting_Characters>
      B => ()

      // <http://www.unicode.org/reports/tr9/#X6>
      _ => {
        levels[i] = last.level

        // This condition is not in the spec, but I am pretty sure that is a spec bug.
        // https://www.unicode.org/L2/L2023/23014-amd-to-uax9.pdf
        if original_classes[i] != BN {
          match last.status {
            RTL => processing_classes[i] = R
            LTR => processing_classes[i] = L
            _ => ()
          }
        }
      }
    }

    // Handle multi-byte characters.
    for j in 1..<len {
      levels[i + j] = levels[i]
      processing_classes[i + j] = processing_classes[i]
    }

    // Identify level runs to be passed to prepare::isolating_run_sequences().
    if i == 0 {
      // Initialize for the first (or only) run.
      current_run_level = levels[i]
    } else if !removed_by_x9(original_classes[i]) &&
      levels[i] != current_run_level {
      // Check if we need to start a new level run.
      // <https://www.unicode.org/reports/tr9/#BD7>
      // End the last run and start a new one.
      runs.push({ start: current_run_start, end: i, })
      current_run_level = levels[i]
      current_run_start = i
    }
  }

  // Append the trailing level run, if non-empty.
  if levels.length() > current_run_start {
    runs.push({ start: current_run_start, end: levels.length(), })
  }
}

///|
/// Entries in the directional status stack:
priv struct Status {
  level : Level
  status : OverrideStatus
}

///|
priv enum OverrideStatus {
  Neutral
  RTL
  LTR
  Isolate
} derive(Eq)
