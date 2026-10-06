// Port of `hayro-interpret/src/context.rs`.

///|
/// Maximum nesting depth for interpreting `XObject`'s/patterns/streams.
let max_nested_interpretation_depth : Int = 50

///|
/// A cache used by the interpreter.
///
/// Ideally, such a cache should be constructed once per PDF and then reused
/// across multiple interpreter invocations on the same document.
pub struct InterpreterCache {
  priv font_cache : Map[U128, Font?]
  priv object_cache : Cache
}

///|
/// Create a new interpreter cache.
pub fn InterpreterCache::new() -> InterpreterCache {
  { font_cache: {}, object_cache: Cache::new(), }
}

///|
pub impl Default for InterpreterCache with fn default() {
  InterpreterCache::new()
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InterpreterCache with Default::{default}

///|
/// A per-page interpretation context that borrows shared data from an
/// [InterpreterCache].
pub struct Context {
  priv states : Array[State]
  priv path : @kurbo.BezPath
  priv mut sub_path_start : @kurbo.Point
  priv mut last_point : @kurbo.Point
  priv mut clip : FillRule?
  priv root_transforms : Array[@kurbo.Affine]
  priv bbox : Array[@kurbo.Rect]
  priv settings : InterpreterSettings
  priv interpreter_cache : InterpreterCache
  priv xref : @hayro_syntax.XRef
  priv ocg_state : OcgState
  priv mut nesting_depth : Int
}

///|
/// Create a new context.
pub fn Context::new(
  initial_transform : @kurbo.Affine,
  bbox : @kurbo.Rect,
  cache : InterpreterCache,
  xref : @hayro_syntax.XRef,
  settings : InterpreterSettings,
) -> Context {
  let state = State::new(initial_transform)
  Context::new_with(initial_transform, bbox, cache, xref, settings, state, 0)
}

///|
fn Context::new_with(
  initial_transform : @kurbo.Affine,
  bbox : @kurbo.Rect,
  cache : InterpreterCache,
  xref : @hayro_syntax.XRef,
  settings : InterpreterSettings,
  state : State,
  nesting_depth : Int,
) -> Context {
  let ocg_state = {
    let root_ref = xref.root_id()
    match (xref.get(root_ref) : @hayro_syntax.Dict?) {
      Some(catalog) => OcgState::from_catalog(catalog)
      None => OcgState::default()
    }
  }
  {
    states: [state],
    settings,
    xref,
    root_transforms: [initial_transform],
    last_point: @kurbo.point_zero,
    sub_path_start: @kurbo.point_zero,
    clip: None,
    bbox: [bbox],
    path: @kurbo.BezPath::new(),
    interpreter_cache: cache,
    ocg_state,
    nesting_depth,
  }
}

///|
fn Context::save_state(self : Context) -> Unit {
  guard self.states.last() is Some(cur) else {
    // warn!("attempted to save state without existing state");
    return
  }
  self.states.push(cur.clone())
}

///|
fn Context::bbox(self : Context) -> @kurbo.Rect {
  match self.bbox.last() {
    Some(b) => b
    None =>
      // warn!("failed to get a bbox");
      @kurbo.Rect::new(0.0, 0.0, 1.0, 1.0)
  }
}

///|
fn Context::push_bbox(self : Context, bbox : @kurbo.Rect) -> Unit {
  let new = self.bbox().intersect(bbox)
  self.bbox.push(new)
}

///|
fn Context::push_clip_path(
  self : Context,
  clip_path : @kurbo.BezPath,
  fill : FillRule,
  device : &Device,
) -> Unit {
  if path_as_rect(clip_path) is Some(clip_rect) {
    let cur_bbox = self.bbox()

    // If the clip path is a rect and completely covers the current bbox, don't emit it.
    if f64_is_nearly_greater_or_equal(cur_bbox.min_x(), clip_rect.min_x()) &&
      f64_is_nearly_greater_or_equal(cur_bbox.min_y(), clip_rect.min_y()) &&
      f64_is_nearly_less_or_equal(cur_bbox.max_x(), clip_rect.max_x()) &&
      f64_is_nearly_less_or_equal(cur_bbox.max_y(), clip_rect.max_y()) {
      self.get().clips.push(Dummy)
      return
    }
    device.push_clip_rect(clip_rect)
    self.push_bbox(clip_rect)
    self.get().clips.push(Real)
    return
  }
  let bbox = clip_path.bounding_box()
  device.push_clip_path({ path: clip_path, fill, })
  self.push_bbox(bbox)
  self.get().clips.push(Real)
}

///|
fn Context::pop_clip(self : Context, device : &Device) -> Unit {
  if self.get().clips.pop() is Some(Real) {
    device.pop_clip()
    self.pop_bbox()
  }
}

///|
fn Context::pop_bbox(self : Context) -> Unit {
  let _ = self.bbox.pop()
}

///|
fn Context::push_root_transform(self : Context) -> Unit {
  self.root_transforms.push(self.get().ctm)
}

///|
fn Context::pop_root_transform(self : Context) -> Unit {
  let _ = self.root_transforms.pop()
}

///|
fn Context::root_transform(self : Context) -> @kurbo.Affine {
  self.root_transforms.last().unwrap_or(@kurbo.Affine::identity())
}

///|
fn Context::restore_state(self : Context, device : &Device) -> Unit {
  let idx = if self.states.length() >= 2 { self.states.length() - 2 } else { 0 }
  guard self.states.get(idx) is Some(target) else {
    // warn!("underflowed graphics state");
    return
  }
  let target_clips = target.clips.length()
  while self.get().clips.length() > target_clips {
    self.pop_clip(device)
  }

  // The first state should never be popped.
  if self.states.length() > 1 {
    let _ = self.states.pop()
  }
}

///|
fn Context::draw_props(self : Context, is_stroke : Bool) -> DrawProps {
  {
    transform: self.get().ctm,
    paint: self.get_paint(is_stroke),
    soft_mask: self.get().graphics_state.soft_mask,
    blend_mode: self.get().graphics_state.blend_mode,
  }
}

///|
fn Context::get_paint(self : Context, is_stroke : Bool) -> Paint {
  let data = if is_stroke {
    self.get().stroke_data()
  } else {
    self.get().non_stroke_data()
  }
  if data.color_space.is_pattern() || data.pattern is Some(_) {
    if data.pattern is Some(pattern) {
      let pattern = match data.transfer_function {
        Some(tf) => pattern.with_transfer_function(tf)
        None => pattern
      }
      Pattern(pattern.pre_concat_transform(self.root_transform()))
    } else {
      // Pattern was likely invalid, use transparent paint.
      Color(Color::new(ColorSpace::device_gray(), [0.0], 0.0))
    }
  } else {
    let color = Color::new(data.color_space, data.color, data.alpha)
    match data.transfer_function {
      Some(tf) => Color(Color::from_rgba(tf.apply(color.to_rgba())))
      None => Color(color)
    }
  }
}

///|
fn Context::get(self : Context) -> State {
  self.states[self.states.length() - 1]
}

///|
fn Context::pre_concat_affine(
  self : Context,
  transform : @kurbo.Affine,
) -> Unit {
  let st = self.get()
  st.ctm = st.ctm * transform
}

///|
fn Context::get_color_space(
  self : Context,
  resources : @hayro_syntax.Resources,
  name : @hayro_syntax.Name,
) -> ColorSpace? {
  guard resources.get_color_space(name) is Some(cs_object) else { return None }
  self.interpreter_cache.object_cache.get_or_insert_color_space(
    CacheKey::cache_key(cs_object),
    () => ColorSpace::new(cs_object, self.interpreter_cache.object_cache),
  )
}

///|
fn Context::stroke_props(self : Context) -> StrokeProps {
  self.get().graphics_state.stroke_props
}

///|
fn Context::num_states(self : Context) -> Int {
  self.states.length()
}

///|
fn Context::nesting_depth(self : Context) -> Int {
  self.nesting_depth
}

///|
fn Context::begin_nested_interpretation(self : Context) -> Bool {
  if self.nesting_depth >= max_nested_interpretation_depth {
    // warn!("interpreter nesting depth exceeded");
    return false
  }
  self.nesting_depth += 1
  true
}

///|
fn Context::end_nested_interpretation(self : Context) -> Unit {
  if self.nesting_depth > 0 {
    self.nesting_depth -= 1
  }
}

///|
fn Context::resolve_font(
  self : Context,
  font_dict : @hayro_syntax.Dict,
) -> TextStateFont? {
  let cache_key = CacheKey::cache_key(font_dict)
  let resolved = match self.interpreter_cache.font_cache.get(cache_key) {
    Some(r) => r
    None => {
      let r = Font::new(
        font_dict,
        self.settings.font_resolver,
        self.settings.cmap_resolver,
      )
      self.interpreter_cache.font_cache[cache_key] = r
      r
    }
  }
  match resolved {
    Some(resolved) => Some(Font(resolved))
    None =>
      match Font::new_standard(Helvetica, self.settings.font_resolver) {
        Some(f) => Some(Fallback(f))
        None => None
      }
  }
}

///|
fn path_as_rect(path : @kurbo.BezPath) -> @kurbo.Rect? {
  // One MoveTo, three LineTo, one ClosePath
  if path.elements().length() != 5 {
    return None
  }
  let bbox = fast_bounding_box(path)
  let (min_x, min_y, max_x, max_y) = (
    bbox.min_x(),
    bbox.min_y(),
    bbox.max_x(),
    bbox.max_y(),
  )
  let corners = [false, false, false, false]
  let check_point = (p : @kurbo.Point) => {
    corners[0] = corners[0] ||
      (f64_is_nearly_equal(p.x, min_x) && f64_is_nearly_equal(p.y, min_y))
    corners[1] = corners[1] ||
      (f64_is_nearly_equal(p.x, min_x) && f64_is_nearly_equal(p.y, max_y))
    corners[2] = corners[2] ||
      (f64_is_nearly_equal(p.x, max_x) && f64_is_nearly_equal(p.y, min_y))
    corners[3] = corners[3] ||
      (f64_is_nearly_equal(p.x, max_x) && f64_is_nearly_equal(p.y, max_y))
  }
  for idx, el in path.elements() {
    match el {
      MoveTo(p) => {
        if idx != 0 {
          return None
        }
        check_point(p)
      }
      LineTo(l) => check_point(l)
      QuadTo(_, _) => return None
      CurveTo(_, _, _) => return None
      ClosePath => ()
    }
  }
  if corners[0] && corners[1] && corners[2] && corners[3] {
    Some(bbox)
  } else {
    None
  }
}
