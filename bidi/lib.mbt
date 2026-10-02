// Port of `unicode-bidi 0.3.18`: `lib.rs` (the UTF-8 `BidiInfo` API).
//
// This package implements the [Unicode Bidirectional Algorithm][tr9] for
// display of mixed right-to-left and left-to-right text. All indices are
// UTF-8 byte offsets into the text, exactly like the Rust crate's.
//
// [tr9]: <http://www.unicode.org/reports/tr9/>

///|
/// A half-open range of byte indices (`Range<usize>`).
pub(all) struct Range {
  start : Int
  end : Int
} derive(Eq, Compare, Hash, Debug)

///|
pub fn Range::len(self : Range) -> Int {
  self.end - self.start
}

///|
pub fn Range::is_empty(self : Range) -> Bool {
  !(self.start < self.end)
}

///|
pub fn Range::contains(self : Range, i : Int) -> Bool {
  self.start <= i && i < self.end
}

///|
/// A maximal substring of characters with the same embedding level.
///
/// Represented as a range of byte indices.

///|
pub(all) enum Direction {
  Ltr
  Rtl
  Mixed
} derive(Eq, Debug)

///|
/// Bidi information about a single paragraph
pub(all) struct ParagraphInfo {
  /// The paragraphs boundaries within the text, as byte indices.
  range : Range
  /// The paragraph embedding level.
  ///
  /// <http://www.unicode.org/reports/tr9/#BD4>
  level : Level
} derive(Eq, Debug)

///|
/// Gets the length of the paragraph in the source text.
pub fn ParagraphInfo::len(self : ParagraphInfo) -> Int {
  self.range.end - self.range.start
}

///|
/// Initial bidi information of the text.
///
/// Contains the text paragraphs and `BidiClass` of its characters.
pub struct InitialInfo {
  /// The text
  text : String
  /// The BidiClass of the character at each byte in the text.
  /// If a character is multiple bytes, its class will appear multiple times in the vector.
  original_classes : Array[BidiClass]
  /// The boundaries and level of each paragraph within the text.
  paragraphs : Array[ParagraphInfo]
}

///|
/// Find the paragraphs and BidiClasses in a string of text.
///
/// <http://www.unicode.org/reports/tr9/#The_Paragraph_Level>
///
/// Also sets the class for each First Strong Isolate initiator (FSI) to LRI or RLI if a strong
/// character is found before the matching PDI.  If no strong character is found, the class will
/// remain FSI, and it's up to later stages to treat these as LRI when needed.
pub fn InitialInfo::new(
  text : String,
  default_para_level : Level?,
) -> InitialInfo {
  let utf8 = Utf8Text::new(text)
  let paragraphs = []
  let flags = []
  let (original_classes, _, _, _) = compute_initial_info(
    utf8.view(),
    default_para_level,
    Some((paragraphs, flags)),
  )
  { text, original_classes, paragraphs, }
}

///|
/// Parallel to paragraphs, records whether each paragraph is "pure LTR" that
/// requires no further bidi processing (i.e. there are no RTL characters or bidi
/// control codes present), and whether any bidi isolation controls are present.
priv struct ParagraphInfoFlags {
  is_pure_ltr : Bool
  has_isolate_controls : Bool
}

///|
/// Implementation of initial-info computation for both BidiInfo and ParagraphBidiInfo.
/// To treat the text as (potentially) multiple paragraphs, the caller should pass the
/// pair of optional outparam arrays to receive the ParagraphInfo and pure-ltr flags
/// for each paragraph. Passing None for split_paragraphs will ignore any paragraph-
/// separator characters in the text, treating it just as a single paragraph.
/// Returns the array of BidiClass values for each code unit of the text, along with
/// the embedding level and pure-ltr flag for the *last* (or only) paragraph.
fn compute_initial_info(
  text : TextSlice,
  default_para_level : Level?,
  split_paragraphs : (Array[ParagraphInfo], Array[ParagraphInfoFlags])?,
) -> (Array[BidiClass], Level, Bool, Bool) {
  let original_classes : Array[BidiClass] = Array(capacity=text.len())

  // The stack contains the starting code unit index for each nested isolate we're inside.
  let isolate_stack : Array[Int] = []
  let mut para_start = 0
  let mut para_level = default_para_level

  // Per-paragraph flag: can subsequent processing be skipped? Set to false if any
  // RTL characters or bidi control characters are encountered in the paragraph.
  let mut is_pure_ltr = true
  // Set to true if any bidi isolation controls are present in the paragraph.
  let mut has_isolate_controls = false
  for pair in text.char_indices() {
    let (i, c) = pair
    let class = bidi_class_of(c)
    let len = utf8_char_len(c)
    for _ in 0..<len {
      original_classes.push(class)
    }
    match class {
      B =>
        if split_paragraphs is Some((paragraphs, flags)) {
          // P1. Split the text into separate paragraphs. The paragraph separator is kept
          // with the previous paragraph.
          let para_end = i + len
          paragraphs.push({
            range: { start: para_start, end: para_end, },
            // P3. If no character is found in p2, set the paragraph level to zero.
            level: para_level.unwrap_or(ltr_level),
          })
          flags.push({ is_pure_ltr, has_isolate_controls, })
          // Reset state for the start of the next paragraph.
          para_start = para_end
          // TODO: Support defaulting to direction of previous paragraph
          //
          // <http://www.unicode.org/reports/tr9/#HL1>
          para_level = default_para_level
          is_pure_ltr = true
          has_isolate_controls = false
          isolate_stack.clear()
        }
      L | R | AL => {
        if class != L {
          is_pure_ltr = false
        }
        match isolate_stack.last() {
          Some(start) =>
            if original_classes[start] == FSI {
              // X5c. If the first strong character between FSI and its matching
              // PDI is R or AL, treat it as RLI. Otherwise, treat it as LRI.
              for j in 0..<utf8_char_len(char_fsi) {
                original_classes[start + j] = if class == L { LRI } else { RLI }
              }
            }
          None =>
            if para_level is None {
              // P2. Find the first character of type L, AL, or R, while skipping
              // any characters between an isolate initiator and its matching
              // PDI.
              para_level = Some(if class != L { rtl_level } else { ltr_level })
            }
        }
      }
      AN | LRE | RLE | LRO | RLO => is_pure_ltr = false
      RLI | LRI | FSI => {
        is_pure_ltr = false
        has_isolate_controls = true
        isolate_stack.push(i)
      }
      PDI => ignore(isolate_stack.pop())
      _ => ()
    }
  }
  if split_paragraphs is Some((paragraphs, flags)) {
    if para_start < text.len() {
      paragraphs.push({
        range: { start: para_start, end: text.len(), },
        level: para_level.unwrap_or(ltr_level),
      })
      flags.push({ is_pure_ltr, has_isolate_controls, })
    }
  }
  (
    original_classes,
    para_level.unwrap_or(ltr_level),
    is_pure_ltr,
    has_isolate_controls,
  )
}

///|
/// Bidi information of the text.
///
/// The `original_classes` and `levels` vectors are indexed by byte offsets into the text.  If a
/// character is multiple bytes wide, then its class and level will appear multiple times in these
/// vectors.
pub struct BidiInfo {
  /// The text
  text : String
  /// The text, indexed by UTF-8 byte offsets.
  utf8 : Utf8Text
  /// The BidiClass of the character at each byte in the text.
  original_classes : Array[BidiClass]
  /// The directional embedding level of each byte in the text.
  levels : Array[Level]
  /// The boundaries and paragraph embedding level of each paragraph within the text.
  paragraphs : Array[ParagraphInfo]
}

///|
/// Split the text into paragraphs and determine the bidi embedding levels for each paragraph.
pub fn BidiInfo::new(text : String, default_para_level : Level?) -> BidiInfo {
  let utf8 = Utf8Text::new(text)
  let paragraphs = []
  let flags = []
  let (original_classes, _, _, _) = compute_initial_info(
    utf8.view(),
    default_para_level,
    Some((paragraphs, flags)),
  )
  let levels : Array[Level] = Array(capacity=utf8.len())
  let processing_classes = original_classes.copy()
  for k, para in paragraphs {
    let flags : ParagraphInfoFlags = flags[k]
    let text = utf8.view().subrange(para.range.start, para.range.end)
    let original_classes = original_classes[para.range.start:para.range.end]
    compute_bidi_info_for_para(
      para,
      flags.is_pure_ltr,
      flags.has_isolate_controls,
      text,
      original_classes,
      processing_classes,
      levels,
    )
  }
  { text, utf8, original_classes, paragraphs, levels, }
}

///|
/// Produce the levels for this paragraph as needed for reordering, one level per *byte*
/// in the paragraph. The returned vector includes bytes that are not included
/// in the `line`, but will not adjust them.
///
/// This runs [Rule L1], you can run
/// [Rule L2] by calling [`Self::reorder_visual()`].
///
/// [Rule L1]: https://www.unicode.org/reports/tr9/#L1
/// [Rule L2]: https://www.unicode.org/reports/tr9/#L2
pub fn BidiInfo::reordered_levels(
  self : BidiInfo,
  para : ParagraphInfo,
  line : Range,
) -> Array[Level] {
  guard line.start <= self.levels.length() else { abort("line.start") }
  guard line.end <= self.levels.length() else { abort("line.end") }
  let levels = self.levels.copy()
  let line_classes = self.original_classes[line.start:line.end]
  let line_levels = levels.mut_view(start=line.start, end=line.end)
  reorder_levels(
    line_classes,
    line_levels,
    self.utf8.view().subrange(line.start, line.end),
    para.level,
  )
  levels
}

///|
/// Produce the levels for this paragraph as needed for reordering, one level per *character*
/// in the paragraph. The returned vector includes characters that are not included
/// in the `line`, but will not adjust them.
pub fn BidiInfo::reordered_levels_per_char(
  self : BidiInfo,
  para : ParagraphInfo,
  line : Range,
) -> Array[Level] {
  let levels = self.reordered_levels(para, line)
  self.utf8.char_indices().map(p => levels[p.0])
}

///|
/// Re-order a line based on resolved levels and return the line in display order.
///
/// This does not apply [Rule L3] or [Rule L4] around combining characters or mirroring.
///
/// [Rule L3]: https://www.unicode.org/reports/tr9/#L3
/// [Rule L4]: https://www.unicode.org/reports/tr9/#L4
pub fn BidiInfo::reorder_line(
  self : BidiInfo,
  para : ParagraphInfo,
  line : Range,
) -> String {
  if !has_rtl(self.levels[line.start:line.end]) {
    return self.utf8.slice(line.start, line.end)
  }
  let (levels, runs) = self.visual_runs(para, line)
  reorder_line(self.utf8, line, levels, runs)
}

///|
/// Reorders pre-calculated levels of a sequence of characters.
///
/// the index map will result in `indexMap[visualIndex]==logicalIndex`.
///
/// This only runs [Rule L2](http://www.unicode.org/reports/tr9/#L2) as it does not have
/// information about the actual text.
pub fn BidiInfo::reorder_visual(levels : ArrayView[Level]) -> Array[Int] {
  reorder_visual(levels)
}

///|
/// Find the level runs within a line and return them in visual order.
///
/// `line` is a range of bytes indices within `levels`.
///
/// The first return value is a vector of levels used by the reordering algorithm,
/// i.e. the result of [Rule L1]. The second return value is a vector of level runs,
/// the result of [Rule L2], showing the visual order that each level run (a run of text with the
/// same level) should be displayed. Within each run, the display order can be checked
/// against the Level vector.
///
/// This does not handle [Rule L3] (combining characters) or [Rule L4] (mirroring),
/// as that should be handled by the engine using this API.
///
/// <http://www.unicode.org/reports/tr9/#Reordering_Resolved_Levels>
///
/// [Rule L1]: https://www.unicode.org/reports/tr9/#L1
/// [Rule L2]: https://www.unicode.org/reports/tr9/#L2
/// [Rule L3]: https://www.unicode.org/reports/tr9/#L3
/// [Rule L4]: https://www.unicode.org/reports/tr9/#L4
pub fn BidiInfo::visual_runs(
  self : BidiInfo,
  para : ParagraphInfo,
  line : Range,
) -> (Array[Level], Array[Range]) {
  let levels = self.reordered_levels(para, line)
  visual_runs_for_line(levels, line)
}

///|
/// If processed text has any computed RTL levels
///
/// This information is usually used to skip re-ordering of text when no RTL level is present
pub fn BidiInfo::has_rtl(self : BidiInfo) -> Bool {
  has_rtl(self.levels[:])
}

///|
/// Return a line of the text in display order based on resolved levels.
fn reorder_line(
  text : Utf8Text,
  line : Range,
  levels : Array[Level],
  runs : Array[Range],
) -> String {
  // If all isolating run sequences are LTR, no reordering is needed
  if runs.iter().all(run => levels[run.start].is_ltr()) {
    return text.slice(line.start, line.end)
  }
  let result = StringBuilder()
  for run in runs {
    if levels[run.start].is_rtl() {
      let chars = text.view().subrange(run.start, run.end).chars()
      for k = chars.length() - 1; k >= 0; k = k - 1 {
        result.write_char(Int::unsafe_to_char(chars[k]))
      }
    } else {
      result.write_string(text.slice(run.start, run.end))
    }
  }
  result.to_string()
}

///|
/// Find the level runs within a line and return them in visual order.
///
/// `line` is a range of code-unit indices within `levels`.
fn visual_runs_for_line(
  levels : Array[Level],
  line : Range,
) -> (Array[Level], Array[Range]) {
  // Find consecutive level runs.
  let runs : Array[Range] = []
  let mut start = line.start
  let mut run_level = levels[start]
  let mut min_level = run_level
  let mut max_level = run_level
  for i in (start + 1)..<line.end {
    let new_level = levels[i]
    if new_level != run_level {
      // End of the previous run, start of a new one.
      runs.push({ start, end: i, })
      start = i
      run_level = new_level
      min_level = if run_level < min_level { run_level } else { min_level }
      max_level = if run_level > max_level { run_level } else { max_level }
    }
  }
  runs.push({ start, end: line.end, })
  let run_count = runs.length()

  // Re-order the odd runs.
  // <http://www.unicode.org/reports/tr9/#L2>

  // Stop at the lowest *odd* level.
  min_level = expect_level(min_level.new_lowest_ge_rtl(), "Level error")
  // This loop goes through contiguous chunks of level runs that have a level
  // ≥ max_level and reverses their contents, reducing max_level by 1 each time.
  while max_level >= min_level {
    // Look for the start of a sequence of consecutive runs of max_level or higher.
    let mut seq_start = 0
    while seq_start < run_count {
      if levels[runs[seq_start].start] < max_level {
        seq_start += 1
        continue
      }

      // Found the start of a sequence. Now find the end.
      let mut seq_end = seq_start + 1
      while seq_end < run_count {
        if levels[runs[seq_end].start] < max_level {
          break
        }
        seq_end += 1
      }
      // Reverse the runs within this sequence.
      reverse_range(runs, seq_start, seq_end)
      seq_start = seq_end
    }
    max_level = expect_level(
      max_level.lower(1),
      "Lowering embedding level below zero",
    )
  }
  (levels, runs)
}

///|
fn[T] reverse_range(arr : Array[T], start : Int, end : Int) -> Unit {
  let mut a = start
  let mut b = end - 1
  while a < b {
    let t = arr[a]
    arr[a] = arr[b]
    arr[b] = t
    a += 1
    b -= 1
  }
}

///|
/// Reorders pre-calculated levels of a sequence of characters.
fn reorder_visual(levels : ArrayView[Level]) -> Array[Int] {
  // Gets the next range of characters after start_index with a level greater
  // than or equal to `max`
  fn next_range(levels : ArrayView[Level], start_index : Int, max : Level) {
    if levels.is_empty() || start_index >= levels.length() {
      return (start_index, start_index)
    }
    let mut start_index = start_index
    while start_index < levels.length() {
      if levels[start_index] >= max {
        break
      }
      start_index += 1
    }
    if start_index >= levels.length() {
      // If at the end of the array, adding one will
      // produce an out-of-range end element
      return (start_index, start_index)
    }
    let mut end_index = start_index + 1
    while end_index < levels.length() {
      if levels[end_index] < max {
        return (start_index, end_index)
      }
      end_index += 1
    }
    (start_index, end_index)
  }

  // This implementation is similar to the L2 implementation in `visual_runs()`
  // but it cannot benefit from a precalculated LevelRun vector so needs to be different.
  if levels.is_empty() {
    return []
  }

  // Get the min and max levels
  let mut min = levels[0]
  let mut max = levels[0]
  for l in levels {
    min = if l < min { l } else { min }
    max = if l > max { l } else { max }
  }

  // Initialize an index map
  let result = Array::makei(levels.length(), i => i)
  if min == max && min.is_ltr() {
    // Everything is LTR and at the same level, do nothing
    return result
  }

  // Stop at the lowest *odd* level, since everything below that
  // is LTR and does not need further reordering
  min = expect_level(min.new_lowest_ge_rtl(), "Level error")

  // For each max level, take all contiguous chunks of
  // levels ≥ max and reverse them
  //
  // We can do this check with the original levels instead of checking reorderings because all
  // prior reorderings will have been for contiguous chunks of levels >> max, which will
  // be a subset of these chunks anyway.
  while min <= max {
    let mut range = (0, 0)
    while true {
      range = next_range(levels, range.1, max)
      reverse_range(result, range.0, range.1)
      if range.1 >= levels.length() {
        break
      }
    }
    max = expect_level(max.lower(1), "Level error")
  }
  result
}

///|
/// The core of BidiInfo initialization, factored out into a function that both
/// the utf-8 and utf-16 versions of BidiInfo can use.
fn compute_bidi_info_for_para(
  para : ParagraphInfo,
  is_pure_ltr : Bool,
  has_isolate_controls : Bool,
  text : TextSlice,
  original_classes : ArrayView[BidiClass],
  processing_classes : Array[BidiClass],
  levels : Array[Level],
) -> Unit {
  for _ in 0..<para.range.len() {
    levels.push(para.level)
  }
  if para.level == ltr_level && is_pure_ltr {
    return
  }
  let processing_classes = processing_classes.mut_view(
    start=para.range.start,
    end=para.range.end,
  )
  let levels = levels.mut_view(start=para.range.start, end=para.range.end)
  let level_runs : Array[Range] = []
  explicit_compute(
    text,
    para.level,
    original_classes,
    levels,
    processing_classes,
    level_runs,
  )
  let sequences : Array[IsolatingRunSequence] = []
  isolating_run_sequences(
    para.level,
    original_classes,
    levels,
    level_runs,
    has_isolate_controls,
    sequences,
  )
  for sequence in sequences {
    resolve_weak(text, sequence, processing_classes)
    resolve_neutral(
      text, sequence, levels, original_classes, processing_classes,
    )
  }
  ignore(resolve_levels(processing_classes, levels))
  assign_levels_to_removed_chars(para.level, original_classes, levels)
}

///|
/// Produce the levels for this paragraph as needed for reordering, one level per *code unit*
/// in the paragraph. The returned vector includes code units that are not included
/// in the `line`, but will not adjust them.
///
/// This runs [Rule L1]
///
/// [Rule L1]: https://www.unicode.org/reports/tr9/#L1
fn reorder_levels(
  line_classes : ArrayView[BidiClass],
  line_levels : MutArrayView[Level],
  line_text : TextSlice,
  para_level : Level,
) -> Unit {
  // Reset some whitespace chars to paragraph level.
  // <http://www.unicode.org/reports/tr9/#L1>
  let mut reset_from : Int? = Some(0)
  let mut reset_to : Int? = None
  let mut prev_level = para_level
  for pair in line_text.char_indices() {
    let (i, c) = pair
    let length = utf8_char_len(c)
    match line_classes[i] {
      // Segment separator, Paragraph separator
      B | S => {
        guard reset_to is None else {
          abort("assertion failed: reset_to == None")
        }
        reset_to = Some(i + utf8_char_len(c))
        if reset_from is None {
          reset_from = Some(i)
        }
      }
      // Whitespace, isolate formatting
      WS | FSI | LRI | RLI | PDI =>
        if reset_from is None {
          reset_from = Some(i)
        }
      // <https://www.unicode.org/reports/tr9/#Retaining_Explicit_Formatting_Characters>
      // same as above + set the level
      RLE | LRE | RLO | LRO | PDF | BN => {
        if reset_from is None {
          reset_from = Some(i)
        }
        // also set the level to previous
        for k in i..<(i + length) {
          line_levels[k] = prev_level
        }
      }
      _ => reset_from = None
    }
    if (reset_from, reset_to) is (Some(from), Some(to)) {
      for k in from..<to {
        line_levels[k] = para_level
      }
      reset_from = None
      reset_to = None
    }
    prev_level = line_levels[i]
  }
  if reset_from is Some(from) {
    for k in from..<line_levels.length() {
      line_levels[k] = para_level
    }
  }
}

///|
/// Contains a reference of `BidiInfo` and one of its `paragraphs`.
/// And it supports all operation in the `Paragraph` that needs also its
/// `BidiInfo` such as `direction`.
pub struct Paragraph {
  info : BidiInfo
  para : ParagraphInfo
}

///|
pub fn Paragraph::new(info : BidiInfo, para : ParagraphInfo) -> Paragraph {
  { info, para, }
}

///|
/// Returns if the paragraph is Left direction, right direction or mixed.
pub fn Paragraph::direction(self : Paragraph) -> Direction {
  para_direction(self.info.levels[self.para.range.start:self.para.range.end])
}

///|
/// Returns the `Level` of a certain character in the paragraph.
pub fn Paragraph::level_at(self : Paragraph, pos : Int) -> Level {
  let actual_position = self.para.range.start + pos
  self.info.levels[actual_position]
}

///|
/// Return the directionality of the paragraph (Left, Right or Mixed) from its levels.
fn para_direction(levels : ArrayView[Level]) -> Direction {
  let mut ltr = false
  let mut rtl = false
  for level in levels {
    if level.is_ltr() {
      ltr = true
      if rtl {
        return Mixed
      }
    }
    if level.is_rtl() {
      rtl = true
      if ltr {
        return Mixed
      }
    }
  }
  if ltr {
    return Ltr
  }
  Rtl
}

///|
/// Assign levels to characters removed by rule X9.
///
/// The levels assigned to these characters are not specified by the algorithm.  This function
/// assigns each one the level of the previous character, to avoid breaking level runs.
fn assign_levels_to_removed_chars(
  para_level : Level,
  classes : ArrayView[BidiClass],
  levels : MutArrayView[Level],
) -> Unit {
  for i in 0..<levels.length() {
    if removed_by_x9(classes[i]) {
      levels[i] = if i > 0 { levels[i - 1] } else { para_level }
    }
  }
}

///|
/// Get the base direction of the text provided according to the Unicode Bidirectional Algorithm.
///
/// See rules P2 and P3.
///
/// The base direction is derived from the first character in the string with bidi character type
/// L, R, or AL. If the first such character has type L, Direction::Ltr is returned. If the first
/// such character has type R or AL, Direction::Rtl is returned.
///
/// If the string does not contain any character of these types (outside of embedded isolate runs),
/// then Direction::Mixed is returned (but should be considered as meaning "neutral" or "unknown",
/// not in fact mixed directions).
///
/// If the text contains paragraph separators, this function considers only the first paragraph.
pub fn get_base_direction(text : String) -> Direction {
  get_base_direction_impl(text, false)
}

///|
/// Get the base direction of the text provided according to the Unicode Bidirectional Algorithm,
/// considering the full text if the first paragraph is all-neutral.
pub fn get_base_direction_full(text : String) -> Direction {
  get_base_direction_impl(text, true)
}

///|
fn get_base_direction_impl(text : String, use_full_text : Bool) -> Direction {
  let mut isolate_level = 0
  for i = 0; i < text.length(); {
    let (c, next) = @unicode.decode_at(text, i)
    match bidi_class_of(c) {
      LRI | RLI | FSI => isolate_level += 1
      PDI if isolate_level > 0 => isolate_level -= 1
      L if isolate_level == 0 => return Ltr
      R | AL if isolate_level == 0 => return Rtl
      B if !use_full_text => break
      B if use_full_text => isolate_level = 0
      _ => ()
    }
    continue next
  }
  // If no strong char was found, return Mixed. Normally this will be treated as Ltr by callers
  // (see rule P3), but we don't map this to Ltr here so that a caller that wants to apply other
  // heuristics to an all-neutral paragraph can tell the difference.
  Mixed
}
