// Port of wasmparser 0.228.0 `src/readers/core/elements.rs`.

///|
/// Represents a core WebAssembly element segment.
pub(all) struct Element {
  /// The kind of the element segment.
  kind : ElementKind
  /// The initial elements of the element segment.
  items : ElementItems
  /// The range of the the element segment.
  range : Range
}

///|
/// The kind of element segment.
pub(all) enum ElementKind {
  /// The element segment is passive.
  Passive
  /// The element segment is active.
  Active(table_index~ : UInt?, offset_expr~ : ConstExpr)
  /// The element segment is declared.
  Declared
}

///|
/// Represents the items of an element segment.
pub(all) enum ElementItems {
  /// This element contains function indices.
  Functions(SectionLimited[UInt])
  /// This element contains constant expressions used to initialize the table.
  Expressions(RefType, SectionLimited[ConstExpr])
}

///|
pub impl FromReader for Element with fn from_reader(reader) {
  let elem_start = reader.original_position()
  // The current handling of the flags is largely specified in the `bulk-memory` proposal,
  // which at the time this commend is written has been merged to the main specification
  // draft.
  //
  // Notably, this proposal allows multiple different encodings of the table index 0. `00`
  // and `02 00` are both valid ways to specify the 0-th table. However it also makes
  // another encoding of the 0-th memory `80 00` no longer valid.
  //
  // We, however maintain this support by parsing `flags` as a LEB128 integer. In that case,
  // `80 00` encoding is parsed out as `0` and is therefore assigned a `tableidx` 0, even
  // though the current specification draft does not allow for this.
  //
  // See also https://github.com/WebAssembly/spec/issues/1439
  let flags = reader.read_var_u32()
  if (flags & 0b111U.lnot()) != 0 {
    raise BinaryReaderError::new(
      "invalid flags byte in element segment",
      reader.original_position() - 1,
    )
  }
  let kind : ElementKind = if (flags & 0b001) != 0 {
    if (flags & 0b010) != 0 {
      Declared
    } else {
      Passive
    }
  } else {
    let table_index = if (flags & 0b010) == 0 {
      None
    } else {
      Some(reader.read_var_u32())
    }
    let offset_expr = ConstExpr::from_reader(reader)
    Active(table_index~, offset_expr~)
  }
  let exprs = (flags & 0b100) != 0
  let ty = if (flags & 0b011) != 0 {
    if exprs {
      Some(RefType::from_reader(reader))
    } else {
      match ExternalKind::from_reader(reader) {
        Func => None
        _ =>
          raise BinaryReaderError::new(
            "only the function external type is supported in elem segment",
            reader.original_position() - 1,
          )
      }
    }
  } else {
    None
  }
  // FIXME(#188) ideally wouldn't have to do skips here
  let data = reader.skip(reader => {
    let items_count = reader.read_var_u32()
    if exprs {
      for _ in 0U..<items_count {
        reader.skip_const_expr()
      }
    } else {
      for _ in 0U..<items_count {
        reader.read_var_u32() |> ignore
      }
    }
  })
  let items : ElementItems = if exprs {
    Expressions(ty.unwrap_or(reftype_funcref), SectionLimited::new(data))
  } else {
    if !(ty is None) {
      abort("assertion failed: ty is None")
    }
    Functions(SectionLimited::new(data))
  }
  let elem_end = reader.original_position()
  let range = { start: elem_start, end: elem_end, }
  { kind, items, range, }
}
