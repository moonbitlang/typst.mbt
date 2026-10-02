// TODO: placeholders for the complex shapers that are not ported yet. Each
// is replaced wholesale by its port (`ot_shaper_<name>.mbt`).

///|
fn placeholder_shaper(name : String) -> OtShaper {
  { ..default_shaper, name, }
}

///|
let universal_shaper : OtShaper = placeholder_shaper("universal")

///|
priv struct UniversalShapePlan {}
