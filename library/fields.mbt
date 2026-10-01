// Port of `typst-library/src/foundations/fields.rs`.

///|
/// Try to access a field on a value (for values without a scope or element
/// fields).
pub fn fields_field(value : Value, field : String) -> Value raise HintedError {
  let ty = value.ty()
  match value {
    Version(version) =>
      Int(
        version.component(field) catch {
          _ => bail(missing_field(ty, field))
        },
      )
    Length(length) =>
      match field {
        "em" => Float(length.em.get())
        "abs" => Length(Length::from_abs(length.abs))
        _ => bail(missing_field(ty, field))
      }
    Relative(rel) =>
      match field {
        "ratio" => Ratio(rel.rel)
        "length" => Length(rel.abs)
        _ => bail(missing_field(ty, field))
      }
    Dyn(dynamic) =>
      match dynamic.field(field) {
        Some(Some(v)) => v
        Some(None) => bail(missing_field(ty, field))
        None => bail(no_fields(ty))
      }
    _ => bail(no_fields(ty))
  }
}

///|
fn no_fields(ty : Type) -> String {
  "cannot access fields on type \{ty}"
}

///|
fn missing_field(ty : Type, field : String) -> String {
  "\{ty} does not contain field \"\{field}\""
}
