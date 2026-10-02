// Unicode properties used by the shaper (`shape/`, a port of rustybuzz),
// from the exact crates rustybuzz uses (see shaping_tables_gen.mbt).

///|
/// General_Category of a codepoint (unicode-properties) in rustybuzz's
/// `hb_gc` numbering (0 = Control, 1 = Format, 2 = Unassigned, ...,
/// 29 = SpaceSeparator).
pub fn rb_general_category(cp : Int) -> Int {
  in_valued(rb_gc_table, cp, 2)
}

///|
/// The ISO 15924 tag of a codepoint's script (unicode-script), as rustybuzz's
/// `CharExt::script` maps it (scripts it doesn't know become `"Zzzz"`).
pub fn rb_script_tag(cp : Int) -> String {
  rb_script_tags[in_valued(rb_script_table, cp, 0)]
}

///|
/// Canonical_Combining_Class of a codepoint (unicode-ccc).
pub fn rb_combining_class(cp : Int) -> Int {
  in_valued(rb_ccc_table, cp, 0)
}

///|
/// Bidi_Mirroring_Glyph of a codepoint (unicode-bidi-mirroring).
pub fn rb_mirrored(cp : Int) -> Int? {
  let table = rb_mirroring_table
  let n = table.length() / 2
  for lo = 0, hi = n; lo < hi; {
    let mid = lo + (hi - lo) / 2
    if cp < table[2 * mid] {
      continue lo, mid
    } else if cp > table[2 * mid] {
      continue mid + 1, hi
    } else {
      break Some(table[2 * mid + 1])
    }
  } nobreak {
    None
  }
}
