// The PDF standard font substitutes of `typst-assets` (`typst_assets::pdf`):
// Foxit fonts (CFF programs, despite their `.pfb` names) used by hayro to
// render the 14 standard fonts of PDF. The data is generated into
// `fonts_gen.mbt` by `scripts/gen_hayro_tables.py`.

///|
/// Decode an embedded base64 asset once.
fn load(cell : Ref[Bytes?], b64 : String) -> Bytes {
  match cell.val {
    Some(b) => b
    None => {
      let clean = StringBuilder::new()
      for c in b64 {
        if c != '\n' {
          clean.write_char(c)
        }
      }
      let b = @base64.decode(clean.to_string()) catch {
        _ => abort("invalid embedded asset")
      }
      cell.val = Some(b)
      b
    }
  }
}
