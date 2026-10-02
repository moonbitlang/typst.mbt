// TODO: placeholders for the complex shapers that are not ported yet. Each
// is replaced wholesale by its port (`ot_shaper_<name>.mbt`).

///|
fn placeholder_shaper(name : String) -> OtShaper {
  { ..default_shaper, name, }
}

///|
let arabic_shaper : OtShaper = placeholder_shaper("arabic")

///|
priv struct ArabicShapePlan {}

///|
let thai_shaper : OtShaper = placeholder_shaper("thai")

///|
let hangul_shaper : OtShaper = placeholder_shaper("hangul")

///|
let hebrew_shaper : OtShaper = placeholder_shaper("hebrew")

///|
let indic_shaper : OtShaper = placeholder_shaper("indic")

///|
priv struct IndicShapePlan {}

///|
let khmer_shaper : OtShaper = placeholder_shaper("khmer")

///|
priv struct KhmerShapePlan {}

///|
let myanmar_shaper : OtShaper = placeholder_shaper("myanmar")

///|
let myanmar_zawgyi_shaper : OtShaper = placeholder_shaper("myanmar_zawgyi")

///|
let universal_shaper : OtShaper = placeholder_shaper("universal")

///|
priv struct UniversalShapePlan {}
