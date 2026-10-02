// Port of `typst-layout/src/inline/line.rs`.

///|
let line_separator : Char = '\u{2028}' // We use LS to distinguish justified breaks.

///|
/// A layouted line, consisting of a sequence of layouted inline items that
/// are mostly borrowed from the preparation phase. This type enables you to
/// measure the size of a line in a range before committing to building the
/// line's frame.
///
/// At most two inline items must be created individually for this line:
/// The first and last one since they may be broken apart by the start or
/// end of the line, respectively. But even those can partially reuse
/// previous results when the break index is safe-to-break per rustybuzz.
priv struct Line {
  /// The items the line is made of.
  items : Items
  /// The exact natural width of the line.
  width : @library.Abs
  /// Whether the line should be justified.
  justify : Bool
  /// Whether the line ends with a hyphen or dash, either naturally or
  /// through hyphenation.
  dash : Dash?
}

///|
/// Create an empty line.
fn Line::empty() -> Line {
  {
    items: Items::new(),
    width: @library.Abs::zero(),
    justify: false,
    dash: None,
  }
}

///|
/// How many glyphs are in the text where we can insert additional space
/// when encountering underfull lines.
fn Line::justifiables(self : Line) -> Int {
  let mut count = 0
  for entry in self.items.0 {
    if entry.1.item is Text(shaped) {
      count += shaped.justifiables()
    }
  }

  // CJK character at line end should not be adjusted.
  if self.items.trailing_text() is Some(s) && s.cjk_justifiable_at_last() {
    count -= 1
  }
  count
}

///|
/// How much the line can stretch.
fn Line::stretchability(self : Line) -> @library.Abs {
  let mut sum = abs_sum_start()
  for entry in self.items.0 {
    if entry.1.item is Text(s) {
      sum = sum + s.stretchability()
    }
  }
  sum
}

///|
/// How much the line can shrink.
fn Line::shrinkability(self : Line) -> @library.Abs {
  let mut sum = abs_sum_start()
  for entry in self.items.0 {
    if entry.1.item is Text(s) {
      sum = sum + s.shrinkability()
    }
  }
  sum
}

///|
/// Whether the line has items with negative width.
fn Line::has_negative_width_items(self : Line) -> Bool {
  self.items.0
  .iter()
  .any(entry => {
    match entry.1.item {
      Absolute(amount, _) => amount < @library.Abs::zero()
      Frame(frame) => frame.width() < @library.Abs::zero()
      _ => false
    }
  })
}

///|
/// The sum of fractions in the line.
fn Line::fr(self : Line) -> @library.Fr {
  let mut sum = @library.Fr::new(-0.0)
  for entry in self.items.0 {
    if entry.1.item is Fractional(fr, _) {
      sum = sum + fr
    }
  }
  sum
}

///|
/// A dash at the end of a line.
priv enum Dash {
  /// A soft hyphen added to break a word.
  Soft
  /// A regular hyphen, present in a compound word, e.g. beija-flor.
  Hard
  /// Another kind of dash. Only relevant for cost computation.
  Other
} derive(Eq)

///|
/// Create a line which spans the given range.
fn line(
  engine : @library.Engine,
  p : Preparation,
  start : Int,
  end : Int,
  breakpoint : @linebreak.Breakpoint,
  pred : Line?,
) -> Line {
  // The line's full text.
  let full = p.text.slice(start, end)

  // Whether the line is justified.
  let justify = full.ends_with_char(line_separator) ||
    (p.config.justify && breakpoint != Mandatory)

  // Process dashes.
  let dash = if breakpoint.is_hyphen() || full.ends_with_char(shy_char) {
    Some(Soft)
  } else if full.ends_with_char(hyphen_char) {
    Some(Hard)
  } else if full.ends_with_char('–') || full.ends_with_char('—') {
    Some(Other)
  } else {
    None
  }

  // Trim the line at the end, if necessary for this breakpoint.
  let trim = breakpoint.trim(start, full.to_string())
  let trimmed_start = start
  let trimmed_end = trim.layout

  // Collect the items for the line.
  let items = Items::new()
  collect_items(items, engine, p, start, end, trim)

  // Add a hyphen at the line start, if a previous dash should be repeated.
  if pred is Some(pred) &&
    pred.dash == Some(Hard) &&
    pred.items.trailing_text() is Some(pred_text) &&
    should_repeat_hyphen(pred_text.lang, full) &&
    items.leading_text_indexed() is Some((base_idx, base)) &&
    ShapedText::hyphen(engine, p.config.fallback, base, trim.shaping, false)
    is Some(hyphen) {
    items.prepend(ItemEntry::owned(Text(hyphen)), base_idx - 1)
  }

  // Add a hyphen at the line end, if we ended on a soft hyphen.
  if dash == Some(Soft) &&
    items.trailing_text_indexed() is Some((base_idx, base)) &&
    ShapedText::hyphen(engine, p.config.fallback, base, trim.shaping, true)
    is Some(hyphen) {
    items.push(ItemEntry::owned(Text(hyphen)), base_idx + 1)
  }

  // Ensure that there is no weak spacing at the start and end of the line.
  trim_weak_spacing(items)

  // Deal with CJ characters at line boundaries.
  // Use the trimmed range for robust boundary checks.
  adjust_cj_at_line_boundaries(p, trimmed_start, trimmed_end, items)

  // Deal with stretchability of glyphs at the end of the line.
  adjust_glyph_stretch_at_line_end(p, items)

  // Compute the line's width.
  let mut width = abs_sum_start()
  for entry in items.0 {
    width = width + entry.1.item.natural_width()
  }
  { items, width, justify, dash, }
}

///|
/// Collects / reshapes all items for the line with the given `range`.
///
/// The `trim` defines an end position to which text items are trimmed. For
/// example, the `range` may span "hello\n", but the `trim` specifies that
/// the linebreak is trimmed.
///
/// We do not factor the `trim` directly into the `range` because we still
/// want to keep non-text items after the trim (e.g. tags).
fn collect_items(
  items : Items,
  engine : @library.Engine,
  p : Preparation,
  start : Int,
  end : Int,
  trim : @linebreak.Trim,
) -> Unit {
  let fallback : Ref[(Int, ItemEntry)?] = Ref(None)

  // Collect the items for each consecutively ordered run.
  reorder(p, start, end, (s, e, rtl) => {
    let from = items.0.length()
    collect_range(engine, p, s, e, trim, items, fallback)
    if rtl {
      items.reorder(from)
    }
  })

  // Add fallback text to expand the line height, if necessary.
  if !items.0.iter().any(entry => entry.1.item is Text(_)) &&
    fallback.val is Some((idx, fallback)) {
    items.push(fallback, idx)
  }
}

///|
/// Trims weak spacing from the start and end of the line.
fn trim_weak_spacing(items : Items) -> Unit {
  // Trim weak spacing at the start of the line.
  let mut prefix = 0
  while prefix < items.0.length() && items.0[prefix].1.item is Absolute(_, true) {
    prefix += 1
  }
  if prefix > 0 {
    items.0.drain(0, prefix) |> ignore
  }

  // Trim weak spacing at the end of the line.
  while items.0.last() is Some((_, entry)) && entry.item is Absolute(_, true) {
    items.0.pop() |> ignore
  }
}

///|
/// Calls `f` for the BiDi-reordered ranges of a line.
fn reorder(
  p : Preparation,
  start : Int,
  end : Int,
  f : (Int, Int, Bool) -> Unit,
) -> Unit {
  // If there is nothing bidirectional going on, skip reordering.
  guard p.bidi is Some(bidi) else { f(start, end, p.config.dir == RTL) }

  // The bidi crate panics for empty lines.
  if start == end {
    f(start, end, p.config.dir == RTL)
    return
  }

  // Find the paragraph that contains the line.
  let para = bidi.paragraphs
    .iter()
    .find_first(para => para.range.contains(start))
    .unwrap()

  // Compute the reordered ranges in visual order (left to right).
  let (levels, runs) = bidi.visual_runs(para, { start, end, })

  // Call `f` for each run.
  for run in runs {
    let rtl = levels[run.start].is_rtl()
    f(run.start, run.end, rtl)
  }
}

///|
/// Collects / reshapes all items for the given `subrange` with continuous
/// direction.
fn collect_range(
  engine : @library.Engine,
  p : Preparation,
  start : Int,
  end : Int,
  trim : @linebreak.Trim,
  items : Items,
  fallback : Ref[(Int, ItemEntry)?],
) -> Unit {
  for i in p.slice(start, end) {
    let (sub_start, sub_end, item) = p.items[i]
    let idx = logical_index_from_item_index(i)

    // All non-text items are just kept, they can't be split.
    guard item is Text(shaped) else {
      items.push(ItemEntry::borrowed(item), idx)
      continue
    }

    // The intersection range of the item, the subrange, and the line's
    // trimming.
    let sliced_start = @cmp.maximum(start, sub_start)
    let sliced_end = @cmp.minimum(@cmp.minimum(end, sub_end), trim.shaping)

    // Whether the item is split by the line.
    let split = sub_start < sliced_start || sliced_end < sub_end
    if sliced_start >= sliced_end {
      // When there is no text, still keep this as a fallback item, which
      // we can use to force a non-zero line-height when the line doesn't
      // contain any other text.
      fallback.val = Some((idx, ItemEntry::owned(Text(shaped.empty()))))
      continue
    }
    let item = if split {
      // When the item is split in half, reshape it.
      let reshaped = shaped.reshape(engine, sliced_start, sliced_end)
      ItemEntry::owned(Text(reshaped))
    } else {
      // When the item is fully contained, just keep it.
      ItemEntry::borrowed(item)
    }

    // Trim end-of-line whitespace glyphs.
    if trim.layout < end {
      let shaped = item.text_mut().unwrap()
      // Make sure not to trim glyphs that have overlapping ranges, for
      // example due to zero width spaces included in the cluster.
      // Otherwise these glyphs would protrude into the margin.
      let layout = trim.layout
      shaped.glyphs.trim(glyph => glyph.range_start >= layout)
    }
    items.push(item, idx)
  }
}

///|
/// Add spacing around punctuation marks for CJ glyphs at line boundaries.
///
/// See Requirements for Chinese Text Layout, Section 3.1.6.3 Compression of
/// punctuation marks at line start or line end.
///
/// The `range` should only contain regular texts, with linebreaks trimmed.
fn adjust_cj_at_line_boundaries(
  p : Preparation,
  start : Int,
  end : Int,
  items : Items,
) -> Unit {
  let text = p.text.slice(start, end)
  let first = text.first_char()
  let last = text.last_char()
  if (first is Some(c) && begin_punct_pat.contains(char_of(c))) ||
    (
      p.config.cjk_latin_spacing &&
      first is Some(c) &&
      is_of_cj_script(char_of(c))
    ) {
    adjust_cj_at_line_start(p, items)
  }
  if (last is Some(c) && end_punct_pat.contains(char_of(c))) ||
    (
      p.config.cjk_latin_spacing &&
      last is Some(c) &&
      is_of_cj_script(char_of(c))
    ) {
    adjust_cj_at_line_end(p, items)
  }
}

///|
/// Remove stretchability from the last glyph in the line to avoid trailing
/// space after a glyph due to glyph-level justification.
fn adjust_glyph_stretch_at_line_end(p : Preparation, items : Items) -> Unit {
  let glyph_limits = p.config.justification_limits.tracking_limits()
  if glyph_limits.min.is_zero() && glyph_limits.max.is_zero() {
    return
  }

  // This is not perfect (ignores clusters and is not particularly fast),
  // but it is good enough for now. The adjustability handling in general
  // needs a cleanup.
  guard items.trailing_text_mut() is Some(shaped) else { return }
  guard shaped.glyphs.to_mut().last() is Some(glyph) else { return }
  glyph.adjustability = Adjustability::default()
}

///|
/// Add spacing around punctuation marks for CJ glyphs at the line start.
fn adjust_cj_at_line_start(p : Preparation, items : Items) -> Unit {
  guard items.leading_text_mut() is Some(shaped) else { return }
  guard shaped.glyphs.kept().get(0) is Some(glyph) else { return }
  if glyph.is_cjk_right_aligned_punctuation() {
    // If the first glyph is a CJK punctuation, we want to shrink it.
    let glyph = shaped.glyphs.to_mut()[0]
    let shrink = glyph.shrinkability().0
    glyph.shrink_left(shrink)
  } else if p.config.cjk_latin_spacing &&
    glyph.is_cj_script() &&
    glyph.x_offset > @library.Em::zero() {
    // If the first glyph is a CJK character adjusted by
    // [`add_cjk_latin_spacing`], restore the original width.
    let glyph = shaped.glyphs.to_mut()[0]
    let shrink = glyph.x_offset
    glyph.x_advance = glyph.x_advance - shrink
    glyph.x_offset = @library.Em::zero()
    let (_, r) = glyph.adjustability.shrinkability
    glyph.adjustability = {
      ..glyph.adjustability,
      shrinkability: (@library.Em::zero(), r),
    }
  }
}

///|
/// Add spacing around punctuation marks for CJ glyphs at the line end.
fn adjust_cj_at_line_end(p : Preparation, items : Items) -> Unit {
  guard items.trailing_text_mut() is Some(shaped) else { return }
  guard shaped.glyphs.kept().last() is Some(glyph) else { return }

  // Deal with CJK punctuation at line ends.
  let style = cjk_punct_style(shaped.lang, shaped.region)
  if glyph.is_cjk_left_aligned_punctuation(style) {
    // If the last glyph is a CJK punctuation, we want to shrink it.
    let shrink = glyph.shrinkability().1
    let punct = shaped.glyphs.to_mut().last().unwrap()
    punct.shrink_right(shrink)
  } else if p.config.cjk_latin_spacing &&
    glyph.is_cj_script() &&
    glyph.x_advance - glyph.x_offset > @library.Em::one() {
    // If the last glyph is a CJK character adjusted by
    // [`add_cjk_latin_spacing`], restore the original width.
    let shrink = glyph.x_advance - glyph.x_offset - @library.Em::one()
    let glyph = shaped.glyphs.to_mut().last().unwrap()
    glyph.x_advance = glyph.x_advance - shrink
    let (l, _) = glyph.adjustability.shrinkability
    glyph.adjustability = {
      ..glyph.adjustability,
      shrinkability: (l, @library.Em::zero()),
    }
  }
}

///|
/// Whether a hyphen should be repeated at the start of the line in the
/// given language, when the following text is the given one.
fn should_repeat_hyphen(
  lang : @library.Lang,
  following_text : Utf8Slice,
) -> Bool {
  match lang.as_str() {
    // - Lower Sorbian: see https://dolnoserbski.de/ortografija/psawidla/K3
    // - Czech: see https://prirucka.ujc.cas.cz/?id=164
    // - Croatian: see http://pravopis.hr/pravilo/spojnica/68/
    // - Polish: see https://www.ortograf.pl/zasady-pisowni/lacznik-zasady-pisowni
    // - Portuguese: see https://www2.senado.leg.br/bdsf/bitstream/handle/id/508145/000997415.pdf (Base XX)
    // - Slovak: see https://www.zones.sk/studentske-prace/gramatika/10620-pravopis-rozdelovanie-slov/
    "dsb" | "cs" | "hr" | "pl" | "pt" | "sk" => true

    // In Spanish the hyphen is required only if the word next to hyphen is
    // not capitalized. Otherwise, the hyphen must not be repeated.
    //
    // See § 4.1.1.1.2.e on the "Ortografía de la lengua española"
    // https://www.rae.es/ortografía/como-signo-de-división-de-palabras-a-final-de-línea
    "es" =>
      match following_text.first_char() {
        Some(c) => !@unicode.is_uppercase(char_of(c))
        None => false
      }
    _ => false
  }
}

///|
/// Apply the current baseline shift and italic compensation to a frame.
fn apply_shift(
  world : &@library.World,
  frame : @library.Frame,
  styles : @library.StyleChain,
) -> Unit {
  let mut baseline = @library.TextElem::baseline_in(styles).resolve(styles)
  let mut compensation = @library.Abs::zero()
  if @library.TextElem::shift_settings_in(styles) is Some(scripts) {
    let variant = @library.variant(styles)
    let size = @library.TextElem::size_in(styles).resolve(styles)
    let variations = @library.TextElem::variations_in(styles)
    let mut font : @library.FontInstance? = None
    for family in @library.families(styles) {
      if world.book().select(family.as_str(), variant) is Some(id) &&
        world.font(id) is Some(f) {
        font = Some(f.instantiate(variant, size, variations))
        break
      }
    }
    let font_metrics = match font {
      None => scripts.kind.default_metrics()
      Some(f) => scripts.kind.read_metrics(f.metrics())
    }
    let shift = match scripts.shift {
      Custom(v) => v
      Auto => font_metrics.vertical_offset
    }
    baseline = baseline - shift.at(size)
    compensation = compensation + font_metrics.horizontal_offset.at(size)
  }
  frame.translate(@library.Point::new(compensation, baseline))
}

///|
/// Commit to a line and build its frame.
fn commit(
  engine : @library.Engine,
  p : Preparation,
  line : Line,
  width : @library.Abs,
  full : @library.Abs,
  locator : @library.SplitLocator,
) -> @library.Frame raise @library.SourceError {
  let mut remaining = width - line.width - p.config.hanging_indent
  let mut offset = @library.Abs::zero()

  // We always build the line from left to right. In an LTR paragraph, we
  // must thus add the hanging indent to the offset. In an RTL paragraph,
  // the hanging indent arises naturally due to the line width.
  if p.config.dir == LTR {
    offset = offset + p.config.hanging_indent
  }

  // Handle hanging punctuation to the left.
  if line.items.leading_text() is Some(text) &&
    text.glyphs.kept().get(0) is Some(glyph) &&
    !text.dir.is_positive() &&
    @library.TextElem::overhang_in(text.styles) &&
    (line.items.0.length() > 1 || text.glyphs.kept().length() > 1) {
    let amount = overhang(glyph)
    offset = offset - amount
    remaining = remaining + amount
  }

  // Handle hanging punctuation to the right.
  if line.items.trailing_text() is Some(text) &&
    text.glyphs.kept().last() is Some(glyph) &&
    text.dir.is_positive() &&
    @library.TextElem::overhang_in(text.styles) &&
    (line.items.0.length() > 1 || text.glyphs.kept().length() > 1) {
    let amount = overhang(glyph)
    remaining = remaining + amount
  }

  // Determine how much additional space is needed. The justification_ratio
  // is for the first step justification, extra_justification is for the
  // last step. For more info on multi-step justification, see Procedures
  // for Inter- Character Space Expansion in W3C document Chinese Layout
  // Requirements.
  let fr = line.fr()
  let mut justification_ratio = 0.0
  let mut extra_justification = @library.Abs::zero()
  let shrinkability = line.shrinkability()
  let stretchability = line.stretchability()
  if remaining < @library.Abs::zero() && shrinkability > @library.Abs::zero() {
    // Attempt to reduce the length of the line, using shrinkability.
    justification_ratio = f64_max(
      remaining.to_raw() / shrinkability.to_raw(),
      -1.0,
    )
    remaining = (remaining + shrinkability).min(@library.Abs::zero())
  } else if line.justify && @library.is_zero(fr) {
    // Attempt to increase the length of the line, using stretchability.
    if stretchability > @library.Abs::zero() {
      justification_ratio = f64_min(
        remaining.to_raw() / stretchability.to_raw(),
        1.0,
      )
      remaining = (remaining - stretchability).max(@library.Abs::zero())
    }
    let justifiables = line.justifiables()
    if justifiables > 0 && remaining > @library.Abs::zero() {
      // Underfull line, distribute the extra space.
      extra_justification = remaining.div_by(justifiables.to_double())
      remaining = @library.Abs::zero()
    }
  }
  let mut top = @library.Abs::zero()
  let mut bottom = @library.Abs::zero()

  // Build the frames and determine the height and baseline.
  let frames : Array[(@library.Abs, @library.Frame, Int)] = []
  let push = (frame : @library.Frame, idx : Int) => {
    let width = frame.width()
    top = top.max(frame.baseline())
    bottom = bottom.max(frame.size().y - frame.baseline())
    frames.push((offset, frame, idx))
    offset = offset + width
  }
  for entry in line.items.0 {
    let (idx, item) = entry
    match item.item {
      Absolute(v, _) => offset = offset + v
      Fractional(v, elem) => {
        let amount = v.share(fr, remaining)
        if elem is Some((elem, loc, styles)) {
          let region = @library.Axes::new(amount, full)
          let frame = layout_and_modify(styles, styles => {
            layout_box(elem, engine, loc.relayout(), styles, region)
          })
          apply_shift(engine.world, frame, styles)
          push(frame, idx)
        } else {
          offset = offset + amount
        }
      }
      Text(shaped) => {
        let frame = shaped.build(
          engine,
          p.spans,
          justification_ratio,
          extra_justification,
        )
        push(frame, idx)
      }
      Frame(frame) => push(frame.clone(), idx)
      Tag(tag) => {
        let frame = @library.Frame::soft(@library.Axes::zero_size())
        frame.push(@library.Point::zero(), Tag(tag))
        frames.push((offset, frame, idx))
      }
      Skip(_) => ()
    }
  }

  // Remaining space is distributed now.
  if !@library.is_zero(fr) {
    remaining = @library.Abs::zero()
  }
  let size = @library.Axes::new(width, top + bottom)
  let output = @library.Frame::soft(size)
  output.set_baseline(top)
  if p.config.numbering_marker is Some(marker) {
    add_par_line_marker(output, marker, engine, locator, top)
  }

  // Ensure that the final frame's items are in logical order rather than in
  // visual order. This is important because it affects the order of
  // elements during introspection and thus things like counters.
  frames.sort_by_key(entry => entry.2)

  // Construct the line's frame.
  for entry in frames {
    let (offset, frame, _) = entry
    let x = offset + p.config.align.position(remaining)
    let y = top - frame.baseline()
    output.push_frame(@library.Point::new(x, y), frame)
  }
  output
}

///|
/// Adds a paragraph line marker to a paragraph line's output frame if line
/// numbering is not `None` at this point. Ensures other style properties,
/// namely number margin, number align and number clearance, are stored in
/// the marker as well.
///
/// The `top` parameter is used to ensure the marker, and thus the line's
/// number in the margin, is aligned to the line's baseline.
fn add_par_line_marker(
  output : @library.Frame,
  marker : @library.Content,
  engine : @library.Engine,
  locator : @library.SplitLocator,
  top : @library.Abs,
) -> Unit {
  // Elements in tags must have a location for introspection to work. We do
  // the work here instead of going through all of the realization process
  // just for this, given we don't need to actually place the marker as we
  // manually search for it in the frame later (when building a root flow,
  // where line numbers can be displayed), so we just need it to be in a tag
  // and to be valid (to have a location).
  let key = @library.hash128(marker)
  let loc = locator.next_location(engine, key, marker.span())
  let marker = marker.located(loc)

  // Create start and end tags through which we can search for this line's
  // marker later. The 'x' coordinate is not important, just the 'y'
  // coordinate, as that's what is used for line numbers. We will place the
  // tags among other subframes in the line such that it is aligned with
  // the line's general baseline. However, the line number will still need
  // to manually adjust its own 'y' position based on its own baseline.
  let pos = @library.Point::with_y(top)
  let flags : @library.TagFlags = { introspectable: false, tagged: false, }
  output.push(pos, Tag(Start(marker, flags)))
  output.push(pos, Tag(End(loc, key, flags)))
}

///|
/// How much a glyph should hang into the end margin.
fn overhang(glyph : ShapedGlyph) -> @library.Abs {
  // Note: Binary search is not currently worth it, but can be used if this
  // grows larger.
  for entry in font_overhang_table(glyph.font) {
    let (id, factor) = entry
    if id == glyph.glyph_id {
      return glyph.x_advance.at(glyph.size).times(factor)
    }
  }
  @library.Abs::zero()
}

///|
let overhang_tables : Map[@library.FontInstance, Array[(Int, Double)]] = {}

///|
/// Generates a sorted table with overhang ratios indexed by glyph ID for a
/// particular font.
fn font_overhang_table(font : @library.FontInstance) -> Array[(Int, Double)] {
  match overhang_tables.get(font) {
    Some(table) => table
    None => {
      let table = []
      if font.ttf() is Some(ttf) {
        for entry in default_overhang_table {
          let (c, factor) = entry
          if ttf.glyph_index(c) is Some(id) {
            table.push((id.0.to_int(), factor))
          }
        }
      }
      // A stable sort keeps the table order among glyphs with equal IDs.
      stable_sort_by(table, (a, b) => a.0.compare(b.0))
      overhang_tables[font] = table
      table
    }
  }
}

///|
/// How much a character should hang into the end margin.
///
/// For more discussion, see:
/// <https://recoveringphysicist.com/21/>
let default_overhang_table : Array[(Char, Double)] = [
  // Dashes.
  ('–', 0.2),
  ('—', 0.2),
  ('-', 0.55),
  ('\u{ad}', 0.55),
  // Punctuation.
  ('.', 0.8),
  (',', 0.8),
  (';', 0.3),
  (':', 0.3),
  // Arabic
  ('\u{60C}', 0.4),
  ('\u{6D4}', 0.4),
]

///|
/// A collection of owned or borrowed inline items, with the logical
/// indices that define their logical order.
priv struct Items(Array[(Int, ItemEntry)])

///|
/// Create empty items.
fn Items::new() -> Items {
  Items([])
}

///|
/// Push a new item.
fn Items::push(self : Items, entry : ItemEntry, idx : Int) -> Unit {
  self.0.push((idx, entry))
}

///|
/// Insert a new item at the start of the line.
fn Items::prepend(self : Items, entry : ItemEntry, idx : Int) -> Unit {
  self.0.insert(0, (idx, entry))
}

///|
/// The position of the first unskippable item.
fn Items::leading_pos(self : Items) -> Int? {
  for i, entry in self.0 {
    if !entry.1.item.is_skippable() {
      return Some(i)
    }
  }
  None
}

///|
/// The position of the last unskippable item.
fn Items::trailing_pos(self : Items) -> Int? {
  for i = self.0.length() - 1; i >= 0; i = i - 1 {
    if !self.0[i].1.item.is_skippable() {
      return Some(i)
    }
  }
  None
}

///|
/// Access the first unskippable item, if it is text.
fn Items::leading_text(self : Items) -> ShapedText? {
  guard self.leading_pos() is Some(i) else { return None }
  self.0[i].1.item.text()
}

///|
/// Access the first unskippable item alongside its index, if it is text.
fn Items::leading_text_indexed(self : Items) -> (Int, ShapedText)? {
  guard self.leading_pos() is Some(i) else { return None }
  let (idx, entry) = self.0[i]
  guard entry.item.text() is Some(text) else { return None }
  Some((idx, text))
}

///|
/// Access the first unskippable item mutably, if it is text.
fn Items::leading_text_mut(self : Items) -> ShapedText? {
  guard self.leading_pos() is Some(i) else { return None }
  self.0[i].1.text_mut()
}

///|
/// Access the last unskippable item, if it is text.
fn Items::trailing_text(self : Items) -> ShapedText? {
  guard self.trailing_pos() is Some(i) else { return None }
  self.0[i].1.item.text()
}

///|
/// Access the last unskippable item alongside its index, if it is text.
fn Items::trailing_text_indexed(self : Items) -> (Int, ShapedText)? {
  guard self.trailing_pos() is Some(i) else { return None }
  let (idx, entry) = self.0[i]
  guard entry.item.text() is Some(text) else { return None }
  Some((idx, text))
}

///|
/// Access the last unskippable item mutably, if it is text.
fn Items::trailing_text_mut(self : Items) -> ShapedText? {
  guard self.trailing_pos() is Some(i) else { return None }
  self.0[i].1.text_mut()
}

///|
/// Reorder the items starting at the given index to RTL.
fn Items::reorder(self : Items, from : Int) -> Unit {
  let mut i = from
  let mut j = self.0.length() - 1
  while i < j {
    self.0.swap(i, j)
    i += 1
    j -= 1
  }
}

///|
/// We use indices to remember the logical (as opposed to visual) order of
/// items. During line building, the items are stored in visual
/// (BiDi-reordered) order. When committing to a line and building its
/// frame, we sort by logical index.
///
/// Normal items have their position in `p.items` times two plus one, so
/// that there is always a space before the first, between two and after
/// the last one (for hyphens, `idx - 1` and `idx + 1`).
fn logical_index_from_item_index(i : Int) -> Int {
  2 * i + 1
}

///|
/// A reference to or a boxed item.
priv struct ItemEntry {
  mut item : InlineItem
  /// Whether the item is owned by this entry (upstream `ItemEntry::Box`)
  /// rather than borrowed from the preparation (`ItemEntry::Ref`).
  mut owned : Bool
}

///|
fn ItemEntry::owned(item : InlineItem) -> ItemEntry {
  { item, owned: true, }
}

///|
fn ItemEntry::borrowed(item : InlineItem) -> ItemEntry {
  { item, owned: false, }
}

///|
fn ItemEntry::text_mut(self : ItemEntry) -> ShapedText? {
  guard self.item is Text(text) else { return None }
  if !self.owned {
    let text = text.clone()
    self.item = Text(text)
    self.owned = true
    Some(text)
  } else {
    Some(text)
  }
}
