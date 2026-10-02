// Port of `typst-layout/src/inline/collect.rs`.

// The characters by which spacing, inline content and pins are replaced in
// the full text.

///|
let spacing_replace : String = " " // Space

///|
let obj_replace : String = "\u{FFFC}" // Object Replacement Character

// Unicode BiDi control characters.

///|
let ltr_embedding : String = "\u{202A}"

///|
let rtl_embedding : String = "\u{202B}"

///|
let pop_embedding : String = "\u{202C}"

///|
let ltr_isolate : String = "\u{2066}"

///|
let pop_isolate : String = "\u{2069}"

///|
/// A prepared item in a inline layout.
priv enum InlineItem {
  /// A shaped text run with consistent style and direction.
  Text(ShapedText)
  /// Absolute spacing between other items, and whether it is weak.
  Absolute(@library.Abs, Bool)
  /// Fractional spacing between other items.
  Fractional(
    @library.Fr,
    (@library.BoxElem, @library.Locator, @library.StyleChain)?
  )
  /// Layouted inline-level content.
  Frame(@library.Frame)
  /// A tag.
  Tag(@library.Tag)
  /// An item that is invisible and needs to be skipped, e.g. a Unicode
  /// isolate.
  Skip(String)
}

///|
/// If this a text item, return it.
fn InlineItem::text(self : InlineItem) -> ShapedText? {
  match self {
    Text(shaped) => Some(shaped)
    _ => None
  }
}

///|
/// Whether this item can be skipped for the purposes of finding a leading
/// or trailing item.
fn InlineItem::is_skippable(self : InlineItem) -> Bool {
  match self {
    Text(text) => text.glyphs.kept().length() == 0
    Tag(_) => true
    Skip(_) => true
    _ => false
  }
}

///|
/// Return the textual representation of this item: Either just itself (for
/// a text item) or a replacement string (for any other item).
fn InlineItem::textual(self : InlineItem) -> String {
  match self {
    Text(shaped) => shaped.text.to_string()
    Absolute(_, _) | Fractional(_, _) => spacing_replace
    Frame(_) => obj_replace
    Tag(_) => ""
    Skip(s) => s
  }
}

///|
/// The text length of the item (in UTF-8 bytes).
fn InlineItem::textual_len(self : InlineItem) -> Int {
  match self {
    Text(shaped) => shaped.text.len()
    Absolute(_, _) | Fractional(_, _) => 1
    Frame(_) => 3
    Tag(_) => 0
    Skip(s) => utf8_str_len(s)
  }
}

///|
/// The natural layouted width of the item.
fn InlineItem::natural_width(self : InlineItem) -> @library.Abs {
  match self {
    Text(shaped) => shaped.width()
    Absolute(v, _) => v
    Frame(frame) => frame.width()
    Fractional(_, _) | Tag(_) => @library.Abs::zero()
    Skip(_) => @library.Abs::zero()
  }
}

///|
/// An item or not-yet shaped text. We can't shape text until we have
/// collected all items because only then we can compute BiDi, and we need
/// to split shape runs at level boundaries.
priv enum Segment {
  /// One or multiple collapsed text children. Stores how long the segment
  /// is (in bytes of the full text string).
  Text(Int, @library.StyleChain)
  /// An already prepared item.
  Item(InlineItem)
}

///|
/// The text length of the item.
fn Segment::textual_len(self : Segment) -> Int {
  match self {
    Text(len, _) => len
    Item(item) => item.textual_len()
  }
}

///|
/// Collects all text into one string and a collection of segments that
/// correspond to pieces of that string. This also performs string-level
/// preprocessing like case transformations.
fn collect_inline(
  children : ArrayView[@library.Pair],
  engine : @library.Engine,
  locator : @library.SplitLocator,
  config : InlineConfig,
  region : @library.Axes[@library.Abs],
) -> (String, Array[Segment], SpanMapper) raise @library.SourceError {
  let collector = InlineCollector::new()
  let quoter = @library.SmartQuoter::new()
  if !config.first_line_indent.is_zero() {
    collector.push_item(Absolute(config.first_line_indent, false))
    collector.spans.push(1, @syntax.Span::detached())
  }
  if !config.hanging_indent.is_zero() {
    collector.push_item(Absolute(-config.hanging_indent, false))
    collector.spans.push(1, @syntax.Span::detached())
  }
  for pair in children {
    let (child, styles) = pair
    let prev_len = collector.len
    if child.is_(@library.space_elem()) {
      collector.push_text(" ", styles)
    } else if @library.TextElem::of(child) is Some(elem) {
      let dir = @library.TextElem::dir_in(styles).resolve(styles)
      let buf = StringBuilder()
      if dir != config.dir {
        // Insert "Explicit Directional Embedding".
        match dir {
          LTR => buf.write_string(ltr_embedding)
          RTL => buf.write_string(rtl_embedding)
          _ => ()
        }
      }
      match @library.TextElem::case_in(styles) {
        Some(case) => buf.write_string(case.apply(elem.text()))
        None => buf.write_string(elem.text())
      }
      if dir != config.dir {
        // Insert "Pop Directional Formatting".
        buf.write_string(pop_embedding)
      }
      collector.push_text(buf.to_string(), styles)
    } else if @library.HElem::of(child) is Some(elem) {
      let amount = elem.amount()
      let is_zero = match amount {
        Rel(rel) => rel.is_zero()
        Fr(fr) => @library.is_zero(fr)
      }
      if is_zero {
        continue
      }
      collector.push_item(
        match amount {
          Fr(fr) => Fractional(fr, None)
          Rel(rel) =>
            Absolute(
              rel.resolve(styles).relative_to(region.x),
              elem.weak(styles),
            )
        },
      )
    } else if @library.LinebreakElem::of(child) is Some(elem) {
      collector.push_text(
        if elem.justify(styles) {
          "\u{2028}"
        } else {
          "\n"
        },
        styles,
      )
    } else if @library.SmartQuoteElem::of(child) is Some(elem) {
      let double = elem.double(styles)
      if elem.enabled(styles) {
        let quotes = @library.SmartQuotes::get(
          elem.quotes(styles),
          @library.TextElem::lang_in(styles),
          @library.TextElem::region_in(styles),
          elem.alternative(styles),
        )
        let before = collector.last_visible
        let quote = quoter.quote(before, quotes, double)
        collector.push_text(quote, styles)
      } else {
        collector.push_text(@library.SmartQuotes::fallback(double), styles)
      }
    } else if @library.InlineElem::of(child) is Some(elem) {
      collector.push_item(Skip(ltr_isolate))
      for
        item in elem.layout(engine, locator.next(child.span()), styles, region) {
        match item {
          Space(space, weak) => collector.push_item(Absolute(space, weak))
          Frame(frame) => {
            FrameModify::modify(frame, FrameModifiers::get_in(styles))
            apply_shift(engine.world, frame, styles)
            collector.push_item(Frame(frame))
          }
        }
      }
      collector.push_item(Skip(pop_isolate))
    } else if @library.BoxElem::of(child) is Some(elem) {
      let loc = locator.next(child.span())
      if elem.width(styles) is Fr(v) {
        collector.push_item(Fractional(v, Some((elem, loc, styles))))
      } else {
        let frame = layout_and_modify(styles, styles => {
          layout_box(elem, engine, loc, styles, region)
        })
        apply_shift(engine.world, frame, styles)
        collector.push_item(Frame(frame))
      }
    } else if @library.TagElem::of(child) is Some(elem) {
      collector.push_item(Tag(elem.tag()))
    } else {
      // Non-paragraph inline layout should never trigger this since it
      // only won't be triggered if we see any non-inline content.
      engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          child.span(),
          "\{child.func().name()} may not occur inside of a paragraph and was ignored",
        ),
      )
    }
    let len = collector.len - prev_len
    collector.spans.push(len, child.span())
  }
  (collector.full.to_string(), collector.segments, collector.spans)
}

///|
/// Collects segments.
priv struct InlineCollector {
  full : StringBuilder
  /// The length of `full` in UTF-8 bytes.
  mut len : Int
  /// The last char of `full` that is not default ignorable (for smart
  /// quotes).
  mut last_visible : Char?
  segments : Array[Segment]
  spans : SpanMapper
}

///|
fn InlineCollector::new() -> InlineCollector {
  {
    full: StringBuilder(),
    len: 0,
    last_visible: None,
    segments: [],
    spans: SpanMapper::new(),
  }
}

///|
/// Append a string to the full text.
fn InlineCollector::push_str(self : InlineCollector, text : String) -> Unit {
  self.full.write_string(text)
  for c in text {
    self.len += utf8_char_len(c.to_int())
    if !@unicode.is_default_ignorable(c) {
      self.last_visible = Some(c)
    }
  }
}

///|
fn InlineCollector::push_text(
  self : InlineCollector,
  text : String,
  styles : @library.StyleChain,
) -> Unit {
  let prev = self.len
  self.push_str(text)
  let segment_len = self.len - prev

  // Merge adjacent text segments with the same styles.
  if self.segments.last() is Some(Text(last_len, last_styles)) &&
    last_styles == styles {
    self.segments[self.segments.length() - 1] = Text(
      last_len + segment_len,
      last_styles,
    )
    return
  }
  self.segments.push(Text(segment_len, styles))
}

///|
fn InlineCollector::push_item(
  self : InlineCollector,
  item : InlineItem,
) -> Unit {
  match (self.segments.last(), item) {
    // Merge adjacent weak spacing by taking the maximum.
    (Some(Item(Absolute(prev_amount, true))), Absolute(amount, true)) =>
      self.segments[self.segments.length() - 1] = Item(
        Absolute(prev_amount.max(amount), true),
      )
    _ => {
      self.push_str(item.textual())
      self.segments.push(Item(item))
    }
  }
}

///|
/// Maps byte offsets back to spans.
priv struct SpanMapper {
  entries : Array[(Int, @syntax.Span)]
}

///|
/// Create a new span mapper.
fn SpanMapper::new() -> SpanMapper {
  { entries: [], }
}

///|
/// Push a span for a segment with the given length.
fn SpanMapper::push(self : SpanMapper, len : Int, span : @syntax.Span) -> Unit {
  self.entries.push((len, span))
}

///|
/// Determine the span at the given byte offset.
///
/// May return a detached span.
fn SpanMapper::span_at(
  self : SpanMapper,
  offset : Int,
) -> (@syntax.Span, UInt16) {
  let mut cursor = 0
  for entry in self.entries {
    let (len, span) = entry
    if offset >= cursor && offset < cursor + len {
      let d = offset - cursor
      return (span, if d > 65535 { 0 } else { d.to_uint16() })
    }
    cursor += len
  }
  (@syntax.Span::detached(), 0)
}
