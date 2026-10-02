// Port of `typst-library/src/math/ir/process.rs`.

///|
/// The result of processing items for grouping.
priv enum GroupResult {
  /// Linebreaks weren't present and alignment points were pruned giving
  /// plain items.
  Flat(Array[MathItem])
  /// Linebreaks were present, and items are split into padded rows and
  /// alignment columns.
  Multiline(Array[AlignedRow])
}

///|
/// Processes raw items for grouping.
///
/// The `closing` parameter indicates whether a closing delimiter follows the
/// items. The `pad` parameter indicates whether, when linebreaks are present,
/// the resulting rows should be padded to have the same length. The `split`
/// parameter indicates whether alignment points should split the items into
/// columns, even when no linebreaks are present.
fn process_group(
  items : ArrayView[RawMathItem],
  styles : StyleChain,
  closing : Bool,
  pad : Bool,
  split : Bool,
) -> GroupResult {
  let preprocessed = preprocess(items, closing, false)
  if preprocessed.linebreaks > 0 || (split && preprocessed.has_align) {
    let row = []
    let rows = []
    let all = preprocessed.items.copy()
    all.push(RawMathItem::Linebreak)
    for item in all {
      match item {
        Linebreak => {
          rows.push(split_at_align(row[:], styles))
          row.clear()
        }
        other => row.push(other)
      }
    }
    if pad {
      let mut ncols = 0
      for row in rows {
        if row.len() > ncols {
          ncols = row.len()
        }
      }
      for row in rows {
        row.pad_to(ncols, styles)
      }
    }
    Multiline(rows)
  } else {
    let out = []
    for item in preprocessed.items {
      match item {
        Align => ()
        Item(item) => out.push(item)
        Linebreak => abort("called `Option::unwrap()` on a `None` value")
      }
    }
    Flat(out)
  }
}

///|
/// The result of processing items for a table cell.
priv struct TableCellResult {
  /// Linebreaks stripped, and items split at alignment points.
  sub_columns : AlignedRow
  /// Whether the original input contained any linebreaks.
  had_linebreaks : Bool
}

///|
/// Processes raw items for a table cell.
fn process_table_cell(
  items : ArrayView[RawMathItem],
  styles : StyleChain,
) -> TableCellResult {
  let preprocessed = preprocess(items, false, true)
  let sub_columns = if preprocessed.has_align {
    split_at_align(preprocessed.items[:], styles)
  } else {
    AlignedRow::new([
      MathItem::wrap(
        preprocessed.items.map(item => item.into_item().unwrap()),
        styles,
      ),
    ])
  }
  { sub_columns, had_linebreaks: preprocessed.had_linebreaks, }
}

///|
/// Internal result of the preprocessing logic.
priv struct Preprocessed {
  items : Array[RawMathItem]
  had_linebreaks : Bool
  has_align : Bool
  linebreaks : Int
}

///|
/// Takes the given `RawMathItem`s and processes the spacing between them.
///
/// The `closing` parameter indicates whether a closing delimiter follows the
/// items. The `strip_linebreaks` parameter indicates whether linebreaks
/// should be discarded.
///
/// The behavior of spacing around alignment points is subtle and differs
/// from the `align` environment in amsmath. The current policy is:
/// > always put the correct spacing between items separated by an alignment
/// > point, and move the spacing between items in different columns of a
/// > (right-aligned, left-aligned) pair to the right-aligned column
///
/// This is handled in the `split_at_align` function.
fn preprocess(
  items : ArrayView[RawMathItem],
  closing : Bool,
  strip_linebreaks : Bool,
) -> Preprocessed {
  let resolved : Array[RawMathItem] = Array(capacity=items.length())
  let mut last : Int? = None
  let mut space : MathItem? = None
  let mut had_linebreaks = false
  let mut has_align = false
  let mut linebreaks = 0
  for raw in items {
    let item = match raw {
      // Tags don't affect layout.
      Item(Tag(_)) => {
        resolved.push(raw)
        continue
      }
      // Keep space only if supported by spaced items.
      Item(Space as item) => {
        if last is Some(_) {
          space = Some(item)
        }
        continue
      }

      // Explicit spacing disables automatic spacing.
      Item(Spacing(width, font_size, weak)) => {
        last = None
        space = None
        if weak {
          guard math_buffer_last_index(resolved) is Some(idx) else { continue }
          if resolved[idx] is Item(Spacing(prev_width, prev_font_size, true)) {
            if prev_width.at(prev_font_size) < width.at(font_size) {
              resolved[idx] = Item(Spacing(width, font_size, true))
            }
            continue
          }
        }
        resolved.push(raw)
        continue
      }

      // Alignment points are resolved later.
      Align => {
        has_align = true
        resolved.push(raw)
        continue
      }

      // New line, new things.
      Linebreak => {
        had_linebreaks = true
        if strip_linebreaks {
          continue
        }
        linebreaks += 1
        resolved.push(raw)
        space = None
        last = None
        continue
      }
      Item(item) => item
    }

    // Convert variable operators into binary operators if something precedes
    // them and they are not preceded by a operator or comparator.
    if item.class() == Vary &&
      last is Some(i) &&
      resolved[i] is Item(prev) &&
      prev.class() is (Normal | Alphabetic | Closing | Fence) {
      item.set_class(Binary)
    }

    // Insert spacing between the last and this non-ignorant item.
    if !item.is_ignorant() {
      if last is Some(i) && resolved[i] is Item(prev) {
        let taken = space
        space = None
        if math_spacing_between(prev, taken, item) is Some(s) {
          resolved.insert(i + 1, Item(s))
        }
      }
      last = Some(resolved.length())
    }
    resolved.push(Item(item))
  }

  // Apply closing punctuation spacing if applicable.
  let last_item = match math_buffer_last_index(resolved) {
    Some(idx) => Some(resolved[idx])
    None => None
  }
  if closing &&
    last_item is Some(Item(item)) &&
    item.rclass() == Punctuation &&
    (match item.size() {
      None => true
      Some(s) => s > MathSize::Script
    }) {
    item.set_rspace(Some(math_thin))
  } else if math_buffer_last_index(resolved) is Some(idx) &&
    resolved[idx] is Item(Spacing(_, _, true)) {
    resolved.remove(idx) |> ignore
  }

  // Strip final trailing linebreak.
  if !closing &&
    math_buffer_last_index(resolved) is Some(idx) &&
    resolved[idx] is Linebreak {
    resolved.remove(idx) |> ignore
    linebreaks -= 1
  }
  { items: resolved, had_linebreaks, has_align, linebreaks, }
}

///|
/// Computes the spacing between two adjacent math items.
fn math_spacing_between(
  l : MathItem,
  space : MathItem?,
  r : MathItem,
) -> MathItem? {
  let script = (f : MathItem) => {
    match f.size() {
      Some(s) => s <= MathSize::Script
      None => false
    }
  }
  match (l.rclass(), r.lclass()) {
    // No spacing before punctuation; thin spacing after punctuation, unless
    // in script size.
    (_, Punctuation) => ()
    (Punctuation, _) if !script(l) => l.set_rspace(Some(math_thin))

    // No spacing after opening delimiters and before closing delimiters.
    (Opening, _) | (_, Closing) => ()

    // Thick spacing around relations, unless followed by a another relation
    // or in script size.
    (Relation, Relation) => ()
    (Relation, _) if !script(l) => l.set_rspace(Some(math_thick))
    (_, Relation) if !script(r) => r.set_lspace(Some(math_thick))

    // Medium spacing around binary operators, unless in script size.
    (Binary, _) if !script(l) => l.set_rspace(Some(math_medium))
    (_, Binary) if !script(r) => r.set_lspace(Some(math_medium))

    // Thin spacing around large operators, unless to the left of an opening
    // delimiter. TeXBook, p170
    (Large, Opening | Fence) => ()
    (Large, _) => l.set_rspace(Some(math_thin))
    (_, Large) => r.set_lspace(Some(math_thin))

    // Spacing around spaced frames.
    _ if l.is_spaced() || r.is_spaced() => return space
    _ => ()
  }
  None
}

///|
/// Returns the physical index of the last non-ignorant item (upstream
/// `MathBuffer::last_index`/`last_mut`).
fn math_buffer_last_index(buffer : Array[RawMathItem]) -> Int? {
  for i = buffer.length() - 1; i >= 0; i = i - 1 {
    if !buffer[i].is_ignorant() {
      return Some(i)
    }
  }
  None
}
