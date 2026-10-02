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

// TODO(arabic merge): temporary bridge for the USE shaper
// (`ot_shaper_use.mbt`), which calls these two functions of
// `ot_shaper_arabic.rs`. Delete this section when the Arabic port lands; its
// `data_create_arabic`/`setup_masks_inner` replace these stubs (rename the
// calls in `ot_shaper_use.mbt` if the port names them differently).

///|
fn data_create_arabic(_plan : ShapePlan) -> ArabicShapePlan {
  ArabicShapePlan::{ }
}

///|
fn setup_masks_inner(
  _arabic_plan : ArabicShapePlan,
  _script : Script?,
  _buffer : Buffer,
) -> Unit {

}

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
