// Port of skrifa 0.42.1 `src/outline/cff/mod.rs` (unhinted CFF outlines;
// CFF2 and PostScript hinting are not supported by this port).

///|
/// Type for loading and scaling outlines in CFF tables.
pub struct CffOutlines {
  font : FontRef
  offset_data : BytesView
  global_subrs : @ps.Index
  priv top_dict : CffTopDict
  units_per_em : Int
}

///|
/// Entries that we parse from the Top DICT that are required to support
/// charstring evaluation.
priv struct CffTopDict {
  mut charstrings : @ps.Index
  mut font_dicts : @ps.Index
  mut fd_select : @ps.FdSelect?
  mut private_dict_start : UInt64
  mut private_dict_end : UInt64
  mut font_matrix : @ps.ScaledFontMatrix?
}

///|
fn CffTopDict::new(
  table_data : BytesView,
  top_dict_data : BytesView,
) -> CffTopDict raise @ps.PsError {
  let items : CffTopDict = {
    charstrings: Empty,
    font_dicts: Empty,
    fd_select: None,
    private_dict_start: 0,
    private_dict_end: 0,
    font_matrix: None,
  }
  for entry in @ps.entries(top_dict_data) {
    match entry {
      Err(e) => raise e
      Ok(CharstringsOffset(offset)) =>
        items.charstrings = @ps.Index::new(
          get_from_or_empty(table_data, offset),
          false,
        )
      Ok(FdArrayOffset(offset)) =>
        items.font_dicts = @ps.Index::new(
          get_from_or_empty(table_data, offset),
          false,
        )
      Ok(FdSelectOffset(offset)) =>
        items.fd_select = Some(
          @ps.FdSelect::read(get_from_or_empty(table_data, offset)),
        )
      Ok(PrivateDictRange(start, end)) => {
        // `range.start as u32..range.end as u32`
        items.private_dict_start = start & 0xFFFFFFFFUL
        items.private_dict_end = end & 0xFFFFFFFFUL
      }
      // Store this matrix normalized since FT always applies normalization
      Ok(FontMatrix(matrix)) => items.font_matrix = Some(matrix.normalize())
      _ => ()
    }
  }
  items
}

///|
fn get_from_or_empty(data : BytesView, offset : Int) -> BytesView {
  if offset < 0 || offset > data.length() {
    b""[:]
  } else {
    data[offset:]
  }
}

///|
/// Creates a new scaler for the given font.
pub fn CffOutlines::new(font : FontRef) -> CffOutlines? {
  guard ok(() => font.head()) is Some(head) else { return None }
  CffOutlines::from_cff(font, head.units_per_em())
}

///|
pub fn CffOutlines::from_cff(
  font : FontRef,
  units_per_em : Int,
) -> CffOutlines? {
  guard ok(() => font.cff()) is Some(cff1) else { return None }
  // GlyphHMetrics::new: hmtx is required
  guard ok(() => font.hmtx()) is Some(_) else { return None }
  let data = cff1.offset_data()
  guard ok(() => @ps.Cff::read(data)) is Some(cff) else { return None }
  // "The Name INDEX in the CFF data must contain only one entry;
  // that is, there must be only one font in the CFF FontSet"
  // So we always pass 0 for Top DICT index when reading from an
  // OpenType font.
  guard ok(() => cff.top_dicts().get(0)) is Some(top_dict_data) else {
    return None
  }
  guard ok(() => CffTopDict::new(data, top_dict_data)) is Some(top_dict) else {
    return None
  }
  Some({
    font,
    offset_data: data,
    global_subrs: Format1(cff.global_subrs()),
    top_dict,
    units_per_em,
  })
}

///|
/// Returns the number of available glyphs.
pub fn CffOutlines::glyph_count(self : CffOutlines) -> Int {
  self.top_dict.charstrings.count()
}

///|
/// Returns the subfont (or Font DICT) index for the given glyph
/// identifier.
pub fn CffOutlines::subfont_index(
  self : CffOutlines,
  glyph_id : GlyphId,
) -> Int {
  match self.top_dict.fd_select {
    Some(select) => select.font_index(glyph_id).unwrap_or(0)
    None => 0
  }
}

///|
/// Specifies local subroutines for some subset of glyphs in a CFF table.
priv struct CffSubfont {
  scale : Fixed?
  subrs_offset : UInt64?
  font_matrix : @font_types.FontMatrix?
}

///|
/// Creates a new subfont for the given index and size.
fn CffOutlines::subfont(
  self : CffOutlines,
  index : Int,
  size : Float?,
) -> CffSubfont raise @ps.PsError {
  let (pd_start, pd_end, sub_matrix) = self.parse_font_dict(index)
  // PrivateDict::new
  let len = self.offset_data.length().to_uint64()
  if pd_start > pd_end || pd_end > len {
    raise @ps.PsError::Read(OutOfBounds)
  }
  let private_dict_data = self.offset_data[pd_start.to_int():pd_end.to_int()]
  let mut subrs_offset : UInt64? = None
  for entry in @ps.entries(private_dict_data) {
    match entry {
      Err(e) => raise e
      // Subrs offset is relative to the private DICT
      Ok(SubrsOffset(offset)) => {
        let sum = pd_start + offset.to_uint64()
        if sum < pd_start {
          raise @ps.PsError::Read(OutOfBounds)
        }
        subrs_offset = Some(sum)
      }
      _ => ()
    }
  }
  let upem = self.units_per_em
  let mut scale = match size {
    // Note: we do an intermediate scale to 26.6 to ensure we
    // match FreeType
    Some(ppem) if upem > 0 =>
      Some(Fixed::from_bits((ppem * 64.0).to_int()) / Fixed::from_bits(upem))
    _ => None
  }
  // Compute our font matrix and adjusted UPEM
  let font_matrix = match self.top_dict.font_matrix {
    Some(top_matrix) =>
      // We have a top dict matrix. Now check for a font dict matrix.
      match sub_matrix {
        Some(sub_matrix) => {
          let scaling = if top_matrix.scale > 1 && sub_matrix.scale > 1 {
            if top_matrix.scale < sub_matrix.scale {
              top_matrix.scale
            } else {
              sub_matrix.scale
            }
          } else {
            1
          }
          // Concatenate and scale
          let matrix = @ps.combine_scaled(
            top_matrix.matrix,
            sub_matrix.matrix,
            scaling,
          )
          let upem = Fixed::from_bits(sub_matrix.scale).mul_div(
            Fixed::from_bits(top_matrix.scale),
            Fixed::from_bits(scaling),
          )
          // Then normalize
          Some(
            @ps.ScaledFontMatrix::{ matrix, scale: upem.to_bits(), }.normalize(),
          )
        }
        // Top matrix was already normalized on load
        None => Some(top_matrix)
      }
    // Just normalize if we have a subfont matrix
    None =>
      match sub_matrix {
        Some(m) => Some(m.normalize())
        None => None
      }
  }
  // Now adjust our scale factor if necessary
  let mut font_matrix = match font_matrix {
    Some(matrix) => {
      // If the scaling factor from our matrix does not equal the nominal
      // UPEM of the font then adjust the scale.
      if matrix.scale != upem {
        // In this case, we need to force a scale for "unscaled"
        // requests in order to apply the adjusted UPEM from the
        // font matrix.
        let original_scale = scale.unwrap_or(Fixed::from_i32(64))
        scale = Some(
          original_scale.mul_div(
            Fixed::from_bits(upem),
            Fixed::from_bits(matrix.scale),
          ),
        )
      }
      Some(matrix.matrix)
    }
    None => None
  }
  if font_matrix is Some(m) && m == @font_types.FontMatrix::identity() {
    // Let's not waste time applying an identity matrix.
    font_matrix = None
  }
  { scale, subrs_offset, font_matrix, }
}

///|
fn CffOutlines::parse_font_dict(
  self : CffOutlines,
  subfont_index : Int,
) -> (UInt64, UInt64, @ps.ScaledFontMatrix?) raise @ps.PsError {
  if self.top_dict.font_dicts.count() != 0 {
    // If we have a font dict array, extract the private dict range
    // from the font dict at the given index.
    let font_dict_data = self.top_dict.font_dicts.get(subfont_index)
    let mut range : (UInt64, UInt64)? = None
    let mut font_matrix : @ps.ScaledFontMatrix? = None
    for entry in @ps.entries(font_dict_data) {
      match entry {
        Err(e) => raise e
        Ok(PrivateDictRange(s, e)) => range = Some((s, e))
        // We store this matrix unnormalized since FreeType
        // concatenates this with the top dict matrix (if present)
        // before normalizing
        Ok(FontMatrix(matrix)) => font_matrix = Some(matrix)
        _ => ()
      }
    }
    guard range is Some((s, e)) else { raise MissingPrivateDict }
    (s, e, font_matrix)
  } else {
    // Use the private dict range from the top dict.
    (self.top_dict.private_dict_start, self.top_dict.private_dict_end, None)
  }
}

///|
/// Loads and scales an outline for the given subfont instance and glyph
/// identifier (unhinted).
fn CffOutlines::draw(
  self : CffOutlines,
  subfont : CffSubfont,
  glyph_id : GlyphId,
  pen : &OutlinePen,
) -> Unit raise @ps.PsError {
  let cff_data = self.offset_data
  let charstrings = self.top_dict.charstrings
  let charstring_data = charstrings.get(glyph_id.to_int())
  let subrs = match subfont.subrs_offset {
    Some(offset) => {
      let index_data = if offset > cff_data.length().to_uint64() {
        b""[:]
      } else {
        cff_data[offset.to_int():]
      }
      @ps.Index::new(index_data, false)
    }
    None => Empty
  }
  let ctx = @ps.CffContext::new(cff_data, charstrings, self.global_subrs, subrs)
  let pen_sink = @ps.PenSink::new(pen)
  let simplifying_adapter = @ps.NopFilterSink::new(pen_sink)
  let matrix = match subfont.font_matrix {
    Some(m) => m
    None => @font_types.FontMatrix::identity()
  }
  let transform_sink = @ps.TransformSink::from_matrix_scale(
    simplifying_adapter,
    matrix,
    subfont.scale,
  )
  ignore(@ps.evaluate(ctx, charstring_data, transform_sink))
}
