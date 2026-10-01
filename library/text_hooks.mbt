// Custom capabilities of `TextElem`, `SymbolElem` and `SpaceElem`
// (upstream `text/mod.rs`, `foundations/symbol.rs`, `text/space.rs`).

///|
fn text_like(c : Content, id : Int) -> String {
  match c.field_raw(id) {
    Some(Str(s)) => s
    _ => ""
  }
}

///|
fn text_elem_init(e : Element) -> Unit {
  e.hooks().repr = Some(c => "[\{text_like(c, text_elem_text)}]")
  e.hooks().plain_text = Some((c, out) => {
    out.write_string(text_like(c, text_elem_text))
  })
  // The text constructor is special: It doesn't create a text element.
  // Instead, it leaves the passed argument structurally unchanged, but styles
  // all text in it.
  e.hooks().construct = Some((engine, args) => {
    let styles = e.set_fields(engine, args)
    let body : Content = args.expect("body")
    body.styled_with_map(styles)
  })
}

///|
fn symbol_elem_init(e : Element) -> Unit {
  e.hooks().repr = Some(c => "[\{text_like(c, symbol_elem_text)}]")
  e.hooks().plain_text = Some((c, out) => {
    out.write_string(text_like(c, symbol_elem_text))
  })
}

///|
fn space_elem_init(e : Element) -> Unit {
  e.hooks().repr = Some(_ => "[ ]")
  e.hooks().eq = Some((_, _) => true)
  e.hooks().plain_text = Some((_, out) => out.write_char(' '))
}
