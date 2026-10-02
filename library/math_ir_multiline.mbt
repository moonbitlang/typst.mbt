// Port of `typst-library/src/math/ir/multiline.rs`.

///|
/// A row split at alignment points into grouped (single-item) columns.
pub struct AlignedRow(Array[MathItem])

///|
/// Create a row from aligned columns.
pub fn AlignedRow::new(columns : Array[MathItem]) -> AlignedRow {
  AlignedRow(columns)
}

///|
/// The number of columns in this row.
pub fn AlignedRow::len(self : AlignedRow) -> Int {
  self.0.length()
}

///|
/// Whether this row is empty.
pub fn AlignedRow::is_empty(self : AlignedRow) -> Bool {
  self.0.is_empty()
}

///|
/// Pad the row with empty group items until its length reaches `length`.
fn AlignedRow::pad_to(
  self : AlignedRow,
  length : Int,
  styles : StyleChain,
) -> Unit {
  while self.0.length() < length {
    self.0.push(MathItem::wrap([], styles))
  }
}

///|
/// Returns an iterator over the math items.
pub fn AlignedRow::iter(self : AlignedRow) -> Iter[MathItem] {
  self.0.iter()
}

///|
/// Returns the item at the given index.
pub fn AlignedRow::get(self : AlignedRow, index : Int) -> MathItem? {
  self.0.get(index)
}

///|
/// The columns (upstream `IntoIterator for AlignedRow`).
pub fn AlignedRow::items(self : AlignedRow) -> Array[MathItem] {
  self.0
}

///|
/// Splits a fenced item's body by alignment points and linebreaks into
/// segments.
fn expand_multiline_fence(
  rows : Array[AlignedRow],
  open : MathItem?,
  close : MathItem?,
  styles : StyleChain,
  span : @syntax.Span,
) -> Array[RawMathItem] {
  let nrows = rows.length()
  let bodies = []
  let row_lengths = []
  for row in rows {
    row_lengths.push(row.len())
    bodies.append(row.0)
  }
  let sizing = SharedFenceSizing::new(bodies, styles)
  let mut open = open
  let mut close = close
  let result = []
  let mut body_idx = 0
  for row_idx, ncols in row_lengths {
    if row_idx > 0 {
      result.push(RawMathItem::Linebreak)
    }
    for col_idx in 0..<ncols {
      if col_idx > 0 {
        result.push(RawMathItem::Align)
      }
      let is_first = row_idx == 0 && col_idx == 0
      let is_last = row_idx + 1 == nrows && col_idx + 1 == ncols
      let o = if is_first {
        let o = open
        open = None
        o
      } else {
        None
      }
      let c = if is_last {
        let c = close
        close = None
        c
      } else {
        None
      }
      result.push(
        RawMathItem::Item(
          FencedItem::create(
            o,
            c,
            FencedBody::shared(body_idx, sizing),
            true,
            styles,
            span,
          ),
        ),
      )
      body_idx += 1
    }
  }
  result
}

///|
/// Splits preprocessed items at alignment point markers into columns,
/// marking items which should have their spacing moved in different columns
/// of a (right-aligned, left-aligned) pair to the right-aligned column.
fn split_at_align(
  items : ArrayView[RawMathItem],
  styles : StyleChain,
) -> AlignedRow {
  let cols : Array[Array[MathItem]] = [[]]
  let mut at_boundary = false
  for raw in items {
    match raw {
      Align => {
        cols.push([])
        at_boundary = true
      }
      Linebreak => abort("unreachable")
      Item(item) => {
        // If we just passed an alignment point, check if this item is
        // semantically infix.
        if at_boundary && !item.is_ignorant() {
          if cols.length() % 2 == 0 &&
            item.class() is (Relation | Binary) &&
            item is Comp(comp) {
            comp.props.align_form_infix = true
          }
          at_boundary = false
        }
        cols.last().unwrap().push(item)
      }
    }
  }
  AlignedRow::new(cols.map(col => MathItem::wrap(col, styles)))
}
