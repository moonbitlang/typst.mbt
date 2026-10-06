// Port of `hayro-write/src/primitive.rs`: writing PDF objects.

///|
/// Keys that are not copied (they refer to document-level structures).
fn is_ignored_key(key : String) -> Bool {
  key
  is ("Metadata"
  | "StructParent"
  | "OC"
  | "AF"
  | "PtData"
  | "Ref"
  | "LastModified"
  | "PieceInfo"
  | "StructParents"
  | "OPI")
}

///|
fn write_direct_ref(
  r : @hayro_syntax.ObjRef,
  ctx : ExtractionContext,
) -> @export.Obj {
  // Check whether the object is actually valid/exists. Otherwise, we need to write a null
  // object instead. If we don't, we might end up with dangling object references that
  // don't actually exist in the PDF chunk, which will lead to a panic in krilla when renumbering.
  let valid = match ctx.valid_ref_cache.get(r) {
    Some(v) => v
    None => {
      let obj : @hayro_syntax.Object? = ctx.pdf.xref().get(r.to_id())
      let v = obj is Some(_)
      ctx.valid_ref_cache[r] = v
      v
    }
  }
  if valid {
    ctx.to_visit_refs.push(r)
    let mapped_ref = ctx.map_ref(r)
    Ref(mapped_ref)
  } else {
    Null
  }
}

///|
fn write_direct_number(n : @hayro_syntax.Number) -> @export.Obj {
  let float_num = n.as_f64()
  if float_num == float_num.floor() && !float_num.is_inf() {
    Int(f64_to_i32_sat(float_num))
  } else {
    Real(Float::from_double(float_num).to_double())
  }
}

///|
/// Rust's saturating `f64 as i32`.
fn f64_to_i32_sat(v : Double) -> Int {
  if v.is_nan() {
    0
  } else if v >= 2147483647.0 {
    2147483647
  } else if v <= -2147483648.0 {
    -2147483648
  } else {
    v.to_int()
  }
}

///|
fn write_direct_maybe_ref(
  m : @hayro_syntax.MaybeRef[@hayro_syntax.Object],
  ctx : ExtractionContext,
) -> @export.Obj {
  match m {
    Ref(r) => write_direct_ref(r, ctx)
    NotRef(o) => write_direct(o, ctx)
  }
}

///|
fn write_dict(
  hayro_dict : @hayro_syntax.Dict,
  ctx : ExtractionContext,
  is_stream : Bool,
) -> Array[(String, @export.Obj)] {
  let out = []
  for entry in hayro_dict.entries() {
    let name = entry.0.raw()
    if is_stream && name == "Length" {
      continue
    }
    if !is_ignored_key(name) {
      out.push((name, write_direct_maybe_ref(entry.1, ctx)))
    }
  }
  out
}

///|
fn write_direct(
  obj : @hayro_syntax.Object,
  ctx : ExtractionContext,
) -> @export.Obj {
  match obj {
    Null => Null
    Boolean(b) => Bool(b)
    Number(n) => write_direct_number(n)
    String(s) => Str(s.as_bytes())
    Name(n) => Name(n.raw())
    Dict(d) => Dict(write_dict(d, ctx, false))
    Array(a) => {
      let items = []
      for item in a.raw_iter() {
        items.push(write_direct_maybe_ref(item, ctx))
      }
      Arr(items)
    }
    Stream(_) => abort("unreachable")
  }
}

///|
fn write_indirect(
  obj : @hayro_syntax.Object,
  id : Int,
  ctx : ExtractionContext,
) -> Unit {
  match obj {
    // TODO: Handle `Crypt` filter
    Stream(s) => {
      let data = s.raw_data().to_owned()
      let dict = write_dict(s.dict(), ctx, true)
      (ctx.put_fn)(id, Stream(dict, data))
    }
    _ => (ctx.put_fn)(id, Plain(write_direct(obj, ctx)))
  }
}
