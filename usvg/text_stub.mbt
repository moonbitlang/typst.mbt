// TEMPORARY: placeholders for the text modules (replaced by the port of
// `src/text/*` and `src/parser/text.rs`).

///|
pub(all) struct FontResolver {
  priv dummy : Int
}

///|
pub impl Default for FontResolver with fn default() {
  { dummy: 0, }
}

///|
priv struct BitmapImage {
  dummy : Int
}

///|
pub struct LayoutSpan {
  priv mut fill : Fill?
  priv mut stroke : Stroke?
  priv overline : Path?
  priv underline : Path?
  priv line_through : Path?
}

///|
fn LayoutSpan::clone(self : LayoutSpan) -> LayoutSpan {
  { ..self, }
}

///|
fn text_convert(
  _node : SvgNode,
  _state : State,
  _cache : Cache,
  _parent : Group,
) -> Unit {
  ()
}

///|
fn RefCounter::text(self : RefCounter, text : Text) -> Unit {
  for chunk in text.chunks {
    for span in chunk.spans {
      self.fill(span.fill)
      self.stroke(span.stroke)
      for
        deco in [
          span.decoration.underline,
          span.decoration.overline,
          span.decoration.line_through,
        ] {
        if deco is Some(deco) {
          self.fill(deco.fill)
          self.stroke(deco.stroke)
        }
      }
    }
  }
  for span in text.layouted {
    self.fill(span.fill)
    self.stroke(span.stroke)
    for path in [span.overline, span.underline, span.line_through] {
      if path is Some(path) {
        self.fill(path.fill)
        self.stroke(path.stroke)
      }
    }
  }
  self.group(text.flattened)
}

///|
fn Cache::extra_ref_roots(self : Cache, counter : RefCounter) -> Unit {
  ignore(self)
  ignore(counter)
}
