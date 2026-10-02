// Port of `hayro-svg/src/clip.rs`.

///|
priv enum CachedClipPath {
  Path(path~ : @kurbo.BezPath, fill_rule~ : @interpret.FillRule, parent~ : Id?)
  Rect(rect~ : @kurbo.Rect, parent~ : Id?)
}

///|
fn SvgRenderer::write_clip_path_defs(self : SvgRenderer) -> Unit {
  if self.clip_paths.is_empty() {
    return
  }
  self.xml.start_element("defs")
  self.xml.write_attribute("id", "clip-path")
  for item in self.clip_paths.iter() {
    let (id, clip_path) = item
    self.xml.start_element("clipPath")
    self.xml.write_attribute("id", id.to_string())
    match clip_path {
      Path(path~, fill_rule~, parent~) => {
        if parent is Some(parent) {
          self.xml.write_attribute("clip-path", "url(#\{parent})")
        }
        self.xml.start_element("path")
        self.xml.write_attribute("d", to_svg_f32(path))
        if fill_rule == EvenOdd {
          self.xml.write_attribute("clip-rule", "evenodd")
        }
        self.xml.end_element()
      }
      Rect(rect~, parent~) => {
        if parent is Some(parent) {
          self.xml.write_attribute("clip-path", "url(#\{parent})")
        }
        self.xml.start_element("rect")
        self.xml.write_attribute("x", f64_str(rect.x0))
        self.xml.write_attribute("y", f64_str(rect.y0))
        self.xml.write_attribute("width", f64_str(rect.width()))
        self.xml.write_attribute("height", f64_str(rect.height()))
        self.xml.end_element()
      }
    }
    self.xml.end_element()
  }
  self.xml.end_element()
}
