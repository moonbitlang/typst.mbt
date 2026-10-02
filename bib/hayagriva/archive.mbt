// Port of `hayagriva/src/csl/archive.rs` (the handwritten parts; the style
// list and the embedded data are generated into `archive_gen.mbt` by
// `oracle/src/bin/gen_csl_archive.rs`).

///|
let style_cache : Map[ArchivedStyle, @citationberg.Style] = Map([])

///|
/// Retrieve the style.
pub fn ArchivedStyle::get(self : ArchivedStyle) -> @citationberg.Style {
  match style_cache.get(self) {
    Some(s) => s
    None => {
      let style = match @citationberg.Style::from_xml(self.xml()) {
        Ok(s) => s
        Err(e) => abort("archived style failed to parse: \{e}")
      }
      style_cache.set(self, style)
      style
    }
  }
}

///|
let locales_cache : Ref[Array[@citationberg.Locale]?] = { val: None, }

///|
/// Retrieve all CSL locales.
pub fn locales() -> Array[@citationberg.Locale] {
  match locales_cache.val {
    Some(l) => l
    None => {
      let res = locales_xml.map(xml => {
        match @citationberg.LocaleFile::from_xml(xml) {
          Ok(f) => f.to_locale()
          Err(e) => abort("archived locale failed to parse: \{e}")
        }
      })
      locales_cache.val = Some(res)
      res
    }
  }
}
