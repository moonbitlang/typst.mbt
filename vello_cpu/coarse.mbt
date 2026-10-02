// Port of `vello_cpu/src/record.rs` and `vello_cpu/src/coarse/` (recording
// rendering commands and bucketing them per strip row).
//
// Not ported (unused by hayro): filter layers, layer clip paths, and the
// depth buffer. The depth buffer only culls work hidden behind opaque fills
// (which overwrite the pixels below them), so skipping it renders the same
// pixels.

///|
/// A recorded command.
priv enum RecordedCmd {
  /// A path fill command.
  Fill(
    strip_start~ : Int,
    strip_end~ : Int,
    paint~ : Paint,
    blend_mode~ : BlendMode,
    mask~ : Mask?
  )
  /// Push a new (non-filter) layer to the layer stack.
  PushLayer(Int)
  /// Pop the last (non-filter) layer from the layer stack.
  PopLayer
}

///|
priv struct LayerProps {
  blend_mode : BlendMode
  opacity : Float
  mask : Mask?
}

///|
priv struct CommandRecorder {
  /// The commands of the root layer.
  root_cmds : Array[RecordedCmd]
  /// Data about recorded layers, indexed by their ID.
  layers : Array[LayerProps]
  /// Stack of currently pushed layers.
  layer_stack : Array[Int]
}

///|
fn CommandRecorder::new() -> CommandRecorder {
  { root_cmds: [], layers: [], layer_stack: [] }
}

///|
fn CommandRecorder::has_layers(self : CommandRecorder) -> Bool {
  !self.layer_stack.is_empty()
}

///|
fn CommandRecorder::push_fill(
  self : CommandRecorder,
  strip_start : Int,
  strip_end : Int,
  paint : Paint,
  blend_mode : BlendMode,
  mask : Mask?,
) -> Unit {
  self.root_cmds.push(Fill(strip_start~, strip_end~, paint~, blend_mode~, mask~))
}

///|
fn CommandRecorder::push_layer(self : CommandRecorder, props : LayerProps) -> Unit {
  let id = self.layers.length()
  self.layers.push(props)
  self.root_cmds.push(PushLayer(id))
  self.layer_stack.push(id)
}

///|
fn CommandRecorder::pop_layer(self : CommandRecorder) -> Unit {
  guard self.layer_stack.pop() is Some(_) else {
    abort("called `Option::unwrap()` on a `None` value")
  }
  self.root_cmds.push(PopLayer)
}

///|
/// A horizontal span in pixel coordinates.
priv struct Span {
  /// The horizontal start position in pixels.
  x : Int
  /// The horizontal span width in pixels.
  width : Int
} derive(Eq)

///|
/// Returns the exclusive horizontal end position in pixels.
fn Span::pixel_end(self : Span) -> Int {
  u16_sat_add(self.x, self.width)
}

///|
/// Extends this span to include another span.
fn Span::extend(self : Span, other : Span) -> Span {
  let x = min_int(self.x, other.x)
  let end = max_int(self.pixel_end(), other.pixel_end())
  { x, width: u16_sat_sub(end, x) }
}

///|
/// Returns the intersection of this span with another span.
fn Span::intersect(self : Span, other : Span) -> Span? {
  let x = max_int(self.x, other.x)
  let end = min_int(self.pixel_end(), other.pixel_end())
  if x < end {
    Some({ x, width: end - x })
  } else {
    None
  }
}

///|
/// A bucketed render command.
priv enum RenderCmd {
  /// Fill a span with the given paint and optionally some alpha coverage.
  PaintFill(span~ : Span, alpha_idx~ : Int?, attrs_idx~ : Int)
  /// Push a new temporary layer buffer.
  PushBuf(Span?)
  /// Pop the last temporary layer buffer.
  PopBuf
  /// Composite a span from the current temporary layer buffer into the
  /// parent buffer and optionally apply some alpha coverage.
  LayerFill(span~ : Span, alpha_idx~ : Int?, attrs_idx~ : Int)
}

///|
priv struct PaintFillAttrs {
  paint : Paint
  blend_mode : BlendMode
  mask : Mask?
}

///|
priv struct LayerFillAttrs {
  blend_mode : BlendMode
  opacity : Float
  mask : Mask?
}

///|
priv struct RowLayerState {
  /// The index in the command stream where the `PushBuf` command of the
  /// corresponding layer lives.
  push_cmd_idx : Int
  /// The horizontal span of the layer.
  mut span : Span?
}

///|
/// State for a single row of strips.
priv struct RowState {
  render_cmds : Array[RenderCmd]
  /// Current layer depth.
  mut layer_depth : Int
  layer_stack : Array[RowLayerState]
}

///|
fn RowState::new() -> RowState {
  { render_cmds: [], layer_depth: 0, layer_stack: [] }
}

///|
fn RowState::push_cmd(self : RowState, cmd : RenderCmd) -> Unit {
  match cmd {
    PaintFill(span~, ..) | LayerFill(span~, ..) => self.include_current_span(span)
    PushBuf(_) | PopBuf => ()
  }
  self.render_cmds.push(cmd)
}

///|
fn RowState::push_buf(self : RowState) -> Unit {
  let push_cmd_idx = self.render_cmds.length()
  self.render_cmds.push(PushBuf(None))
  self.layer_stack.push({ push_cmd_idx, span: None })
  self.layer_depth += 1
}

///|
fn RowState::pop_buf(self : RowState) -> Unit {
  guard self.layer_stack.pop() is Some(layer) else {
    abort("called `Option::unwrap()` on a `None` value")
  }
  self.render_cmds[layer.push_cmd_idx] = PushBuf(layer.span)
  self.render_cmds.push(PopBuf)
  self.layer_depth -= 1
}

///|
fn RowState::include_current_span(self : RowState, span : Span) -> Unit {
  if self.layer_stack.last() is Some(layer) {
    layer.span = match layer.span {
      Some(layer_span) => Some(layer_span.extend(span))
      None => Some(span)
    }
  }
}

///|
/// Metadata about the currently active layer.
priv struct ActiveLayer {
  mask : Mask?
  blend_mode : BlendMode
  opacity : Float
  span : Span
  /// Which rows have been drawn into and thus contain lazily-allocated
  /// `PushBuf` instructions.
  occupied_rows : Array[Int]
}

///|
/// A bucketer that groups commands into strip-row-sized buckets.
priv struct CommandBucketer {
  /// The currently active stack of clip bboxes (only the viewport, as layer
  /// clips are not supported).
  clip_bboxes : Array[RectU16]
  /// The actual render commands for each strip row.
  rows : Array[RowState]
  paint_fill_attrs : Array[PaintFillAttrs]
  layer_fill_attrs : Array[LayerFillAttrs]
  /// Keeping track of currently active layers to enable lazy layer pushing.
  active_layers : Array[ActiveLayer]
}

///|
fn CommandBucketer::from_wh(width : Int, height : Int) -> CommandBucketer {
  // It's _very_ important that we snap to tile coordinates. Fine
  // rasterization assumes that the width is a multiple of the tile width.
  let viewport = RectU16::new(0, 0, width, height).snap_to_tile_coordinates()
  let clip_bbox = RectU16::new(0, 0, viewport.width(), viewport.height())
  let num_rows = clip_bbox.height() / TILE_HEIGHT
  {
    clip_bboxes: [clip_bbox],
    rows: Array::makei(num_rows, _ => RowState::new()),
    paint_fill_attrs: [],
    layer_fill_attrs: [],
    active_layers: [],
  }
}

///|
fn bbox_span(bbox : RectU16) -> Span {
  { x: bbox.x0, width: u16_sat_sub(bbox.x1, bbox.x0) }
}

///|
fn CommandBucketer::width(self : CommandBucketer) -> Int {
  self.clip_bboxes[0].width()
}

///|
fn CommandBucketer::ensure_row_layers(self : CommandBucketer, row_idx : Int) -> Unit {
  let row = self.rows[row_idx]
  let layer_depth = row.layer_depth
  if layer_depth == self.active_layers.length() {
    return
  }
  for layer_idx in layer_depth..<self.active_layers.length() {
    row.push_buf()
    self.active_layers[layer_idx].occupied_rows.push(row_idx)
  }
}

///|
fn CommandBucketer::bucket_commands(
  self : CommandBucketer,
  cmds : Array[RecordedCmd],
  layers : Array[LayerProps],
  strips : Array[Strip],
) -> Unit {
  for cmd in cmds {
    match cmd {
      Fill(strip_start~, strip_end~, paint~, blend_mode~, mask~) => {
        let attrs = { paint, blend_mode, mask }
        self.generate_fill(strips, strip_start, strip_end, attrs)
      }
      PushLayer(id) => self.push_layer(layers[id])
      PopLayer => self.pop_layer()
    }
  }
}

///|
fn CommandBucketer::push_layer(self : CommandBucketer, props : LayerProps) -> Unit {
  let parent_bbox = self.clip_bboxes[self.clip_bboxes.length() - 1]
  // Once again, this need to be snapped because fine rasterization assumes
  // tile-alignment.
  let bbox = parent_bbox.snap_to_tile_coordinates()
  self.active_layers.push({
    mask: props.mask,
    blend_mode: props.blend_mode,
    opacity: props.opacity,
    span: bbox_span(bbox),
    occupied_rows: [],
  })
  // If the blend mode is destructive, we need to eagerly push to all rows
  // in the clip bbox.
  if props.blend_mode.is_destructive() {
    let row_start = bbox.y0 / TILE_HEIGHT
    let row_end = min_int(div_ceil(bbox.y1, TILE_HEIGHT), self.rows.length())
    for row_idx in row_start..<row_end {
      self.ensure_row_layers(row_idx)
    }
  }
}

///|
fn CommandBucketer::pop_layer(self : CommandBucketer) -> Unit {
  guard self.active_layers.pop() is Some(layer) else {
    abort("called `Option::unwrap()` on a `None` value")
  }
  let attrs_idx = self.layer_fill_attrs.length()
  self.layer_fill_attrs.push({
    blend_mode: layer.blend_mode,
    opacity: layer.opacity,
    mask: layer.mask,
  })
  for row_idx in layer.occupied_rows {
    let row = self.rows[row_idx]
    row.push_cmd(LayerFill(span=layer.span, alpha_idx=None, attrs_idx~))
    row.pop_buf()
  }
}

///|
fn CommandBucketer::generate_fill(
  self : CommandBucketer,
  strips : Array[Strip],
  strip_start : Int,
  strip_end : Int,
  attrs : PaintFillAttrs,
) -> Unit {
  if strip_start == strip_end {
    return
  }
  let attrs_idx = self.paint_fill_attrs.length()
  self.paint_fill_attrs.push(attrs)
  let clip_bbox = self.clip_bboxes[self.clip_bboxes.length() - 1]
  // Note: Those will always be aligned to tile coordinates.
  let clip_x0 = clip_bbox.x0
  let clip_x1 = min_int(clip_bbox.x1, self.width())
  let viewport_y1 = clip_bbox.y1
  for i in strip_start..<(strip_end - 1) {
    let strip = strips[i]
    // Skip strips that are outside the viewport vertically.
    if strip.y >= viewport_y1 {
      break
    }
    let strip_y = strip.y / TILE_HEIGHT
    let row_y = u16_sat_mul(strip_y, TILE_HEIGHT)
    if row_y < clip_bbox.y0 {
      continue
    }
    if row_y >= clip_bbox.y1 {
      break
    }
    let row_idx = strip_y
    let next_strip = strips[i + 1]
    let strip_width = strip.width_to(next_strip)
    let x0 = strip.x
    let x1 = u16_sat_add(x0, strip_width)
    // Clip strips that are outside the viewport horizontally.
    let clipped_x0 = max_int(x0, clip_x0)
    let clipped_x1 = min_int(x1, clip_x1)
    if clipped_x0 < clipped_x1 {
      self.ensure_row_layers(row_idx)
      self.rows[row_idx].push_cmd(
        PaintFill(
          span={ x: clipped_x0, width: clipped_x1 - clipped_x0 },
          alpha_idx=Some(strip.alpha_idx() + (clipped_x0 - x0) * TILE_HEIGHT),
          attrs_idx~,
        ),
      )
    }
    if next_strip.fill_gap() && next_strip.y == strip.y {
      let fill_x0 = max_int(x1, clip_x0)
      let fill_x1 = min_int(next_strip.x, clip_x1)
      if fill_x0 < fill_x1 {
        self.ensure_row_layers(row_idx)
        self.rows[row_idx].push_cmd(
          PaintFill(
            span={ x: fill_x0, width: fill_x1 - fill_x0 },
            alpha_idx=None,
            attrs_idx~,
          ),
        )
      }
    }
  }
}
