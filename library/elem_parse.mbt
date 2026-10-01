// Custom `#[parse(..)]` argument parsing of element fields (upstream: the
// `#[parse]` attributes on the fields of the respective elements).

///|
/// [Args::named] casting to the type of an element field.
fn named_as(
  args : Args,
  name : String,
  elem : Element,
  id : Int,
) -> Value? raise SourceError {
  args.named_with(name, elem.field(id).unwrap().cast)
}

///|
/// [Args::find] casting to the type of an element field.
fn find_as(args : Args, elem : Element, id : Int) -> Value? raise SourceError {
  let field = elem.field(id).unwrap()
  args.find_with(field.castable, field.cast)
}

///|
/// [Args::find] casting to the type of an element field whose type is not
/// ported yet, with upstream's castability check for that type.
fn find_castable_as(
  args : Args,
  castable : (Value) -> Bool,
  elem : Element,
  id : Int,
) -> Value? raise SourceError {
  args.find_with(castable, elem.field(id).unwrap().cast)
}

///|
fn or_else(value : Value?, other : Value?) -> Value? {
  match value {
    Some(_) => value
    None => other
  }
}

// layout/container.rs: BlockElem

///|
fn block_elem_above_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let spacing = named_as(args, "spacing", block_elem(), block_elem_above)
  locals.set("spacing", spacing)
  or_else(named_as(args, "above", block_elem(), block_elem_above), spacing)
}

///|
fn block_elem_below_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(
    named_as(args, "below", block_elem(), block_elem_below),
    locals.get("spacing"),
  )
}

// layout/grid/mod.rs: GridElem, GridCell

///|
fn grid_elem_column_gutter_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let gutter = named_as(args, "gutter", grid_elem(), grid_elem_column_gutter)
  locals.set("gutter", gutter)
  or_else(
    named_as(args, "column-gutter", grid_elem(), grid_elem_column_gutter),
    gutter,
  )
}

///|
fn grid_elem_row_gutter_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(
    named_as(args, "row-gutter", grid_elem(), grid_elem_row_gutter),
    locals.get("gutter"),
  )
}

///|
fn grid_cell_elem_is_repeated_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  Some(Bool(false))
}

// model/table.rs: TableElem, TableCell

///|
fn table_elem_column_gutter_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let gutter = named_as(args, "gutter", table_elem(), table_elem_column_gutter)
  locals.set("gutter", gutter)
  or_else(
    named_as(args, "column-gutter", table_elem(), table_elem_column_gutter),
    gutter,
  )
}

///|
fn table_elem_row_gutter_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(
    named_as(args, "row-gutter", table_elem(), table_elem_row_gutter),
    locals.get("gutter"),
  )
}

///|
fn table_elem_summary_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  None
}

///|
fn table_cell_elem_kind_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  Some(Auto)
}

///|
fn table_cell_elem_is_repeated_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  Some(Bool(false))
}

// layout/pad.rs: PadElem

///|
fn pad_elem_left_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let elem = pad_elem()
  // Upstream: `args.named("rest")?.or(args.find()?)` evaluates both.
  let rest = named_as(args, "rest", elem, pad_elem_left)
  let found = find_as(args, elem, pad_elem_left)
  let all = or_else(rest, found)
  let x = or_else(named_as(args, "x", elem, pad_elem_left), all)
  let y = or_else(named_as(args, "y", elem, pad_elem_top), all)
  locals.set("x", x)
  locals.set("y", y)
  or_else(named_as(args, "left", elem, pad_elem_left), x)
}

///|
fn pad_elem_top_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(named_as(args, "top", pad_elem(), pad_elem_top), locals.get("y"))
}

///|
fn pad_elem_right_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(named_as(args, "right", pad_elem(), pad_elem_right), locals.get("x"))
}

///|
fn pad_elem_bottom_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(
    named_as(args, "bottom", pad_elem(), pad_elem_bottom),
    locals.get("y"),
  )
}

// layout/page.rs: PagebreakElem

///|
fn pagebreak_elem_boundary_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  None
}

// layout/spacing.rs: VElem

///|
fn v_elem_attach_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  Some(Bool(false))
}

// layout/transform.rs: ScaleElem

///|
fn scale_elem_x_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  // `Smart<ScaleAmount>`: auto, ratio or length.
  let all = find_castable_as(
    args,
    v => v is (Auto | Ratio(_) | Length(_)),
    scale_elem(),
    scale_elem_x,
  )
  locals.set("all", all)
  or_else(named_as(args, "x", scale_elem(), scale_elem_x), all)
}

///|
fn scale_elem_y_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(named_as(args, "y", scale_elem(), scale_elem_y), locals.get("all"))
}

// text/space.rs: SpaceElem

///|
fn space_elem_had_newline_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  Some(Bool(false))
}

// text/mod.rs: TextElem

///|
fn text_elem_size_parse(
  _engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  match named_as(args, "size", text_elem(), text_elem_size) {
    Some(value) => Some(value)
    // `TextSize` is cast from a length.
    None =>
      find_castable_as(args, v => v is Length(_), text_elem(), text_elem_size)
  }
}

///|
fn text_elem_fill_parse(
  _engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  // TODO: reject gradients and tilings relative to `self` ("gradients and
  // tilings on text must be relative to the parent") once `Paint` is ported.
  match named_as(args, "fill", text_elem(), text_elem_fill) {
    Some(value) => Some(value)
    // `Paint` is a color, gradient or tiling.
    None =>
      find_castable_as(
        args,
        v => v is (Color(_) | Gradient(_) | Tiling(_)),
        text_elem(),
        text_elem_fill,
      )
  }
}

// math/frac.rs: FracElem, BinomElem

///|
fn frac_elem_num_deparenthesized_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  None
}

///|
fn frac_elem_denom_deparenthesized_parse(
  _engine : Engine,
  _args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  None
}

///|
fn binom_elem_lower_parse(
  _engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let values : Array[@syntax.Spanned[Value]] = args.all_spanned()
  if values.is_empty() {
    bail_at(args.span, "missing argument: lower")
  }
  Some(Array(Arr::from_array(values.map(s => Content(s.v.display())))))
}

// math/matrix.rs: MatElem

///|
fn mat_elem_row_gap_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let gap = named_as(args, "gap", mat_elem(), mat_elem_row_gap)
  locals.set("gap", gap)
  or_else(named_as(args, "row-gap", mat_elem(), mat_elem_row_gap), gap)
}

///|
fn mat_elem_column_gap_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  or_else(
    named_as(args, "column-gap", mat_elem(), mat_elem_column_gap),
    locals.get("gap"),
  )
}

///|
fn mat_elem_rows_parse(
  _engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let mut rows : Array[Array[Content]] = []
  let mut width = 0
  let values : Array[@syntax.Spanned[Value]] = args.all_spanned()
  if values.iter().any(s => s.v is Array(_)) {
    for spanned in values {
      let array : Arr = at(spanned.span, () => spanned.v.cast())
      let row = array.items.map(v => v.display())
      width = if row.length() > width { row.length() } else { width }
      rows.push(row)
    }
  } else {
    rows = [values.map(s => s.v.display())]
  }
  for row in rows {
    while row.length() < width {
      row.push(Content::empty())
    }
  }
  Some(
    Array(
      Arr::from_array(
        rows.map(row => Array(Arr::from_array(row.map(c => Content(c))))),
      ),
    ),
  )
}

// model/link.rs: LinkElem

///|
/// Cast a value to a link target (upstream `LinkTarget`, `Destination` and
/// `Url` casts).
fn cast_link_target(value : Value) -> Value raise HintedError {
  match value {
    Str(url) => {
      if @syntax.utf8_len(url) > 8000 {
        bail("URL is too long")
      } else if url.is_empty() {
        bail("URL must not be empty")
      }
      value
    }
    // TODO: validate `PagedPosition` dictionaries once ported.
    Dict(_) | Dyn(Location(_)) | Label(_) => value
    _ =>
      raise HintedError(
        CastInfo::Union([
          Type(Type::str()),
          Type(Type::dict()),
          Type(Type::location()),
          Type(Type::label()),
        ]).error(value),
      )
  }
}

///|
fn link_elem_dest_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let dest = args.expect_with("destination", cast_link_target)
  locals.set("dest", Some(dest))
  Some(dest)
}

///|
fn link_elem_body_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  match locals.get("dest") {
    Some(Str(url)) =>
      match args.eat() {
        Some(body) => Some(Content(body))
        None => Some(Content(body_from_url(url)))
      }
    _ => Some(Content(args.expect("body")))
  }
}

///|
/// The default link body for a URL: without a `mailto:` or `tel:` scheme.
fn body_from_url(url : String) -> Content {
  TextElem::packed(link_body_from_url(url))
}
