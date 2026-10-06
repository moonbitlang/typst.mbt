// Debugging aid: an optional trace of the public drawing calls, in the same
// format as a logging build of upstream tiny-skia, to locate differences.

///|
/// When set, every public drawing call on a `Pixmap` is reported.
pub let trace_hook : Ref[((String) -> Unit)?] = Ref(None)

///|
fn trace_fnv(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
fn hex32(x : UInt) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for i = 7; i >= 0; i = i - 1 {
    sb.write_char(
      digits[((x >> (i * 4)) & 0xF).reinterpret_as_int()].unsafe_to_char(),
    )
  }
  sb.to_string()
}

///|
fn hex64(x : UInt64) -> String {
  hex32((x >> 32).to_uint()) + hex32(x.to_uint())
}

///|
fn fbits(x : Float) -> String {
  hex32(x.reinterpret_as_uint())
}

///|
fn trace_ts(t : @path.Transform) -> String {
  "\{fbits(t.sx)},\{fbits(t.ky)},\{fbits(t.kx)},\{fbits(t.sy)},\{fbits(t.tx)},\{fbits(t.ty)}"
}

///|
fn trace_path(p : @path.Path) -> String {
  let sb = StringBuilder()
  for v in p.verbs() {
    sb.write_char(
      match v {
        Move => 'M'
        Line => 'L'
        Quad => 'Q'
        Cubic => 'C'
        Close => 'Z'
      },
    )
  }
  let buf = Buffer()
  for pt in p.points() {
    buf.write_uint_le(pt.x.reinterpret_as_uint())
    buf.write_uint_le(pt.y.reinterpret_as_uint())
  }
  "\{sb.to_string()} \{hex64(trace_fnv(buf.to_bytes()))}"
}

///|
fn trace_paint(p : Paint) -> String {
  let sh = match p.shader {
    SolidColor(c) =>
      "solid \{fbits(c.r)},\{fbits(c.g)},\{fbits(c.b)},\{fbits(c.a)}"
    Pattern(pt) =>
      "pattern \{pt.pixmap.width()}x\{pt.pixmap.height()} \{hex64(trace_fnv(pt.pixmap.data()))} \{quality_name(pt.quality)} \{spread_name(pt.spread_mode)} \{fbits(pt.opacity)} \{trace_ts(pt.transform)}"
    _ => "gradient"
  }
  "\{sh} \{blend_name(p.blend_mode)} aa=\{p.anti_alias}"
}

///|
fn trace_mask(m : Mask?) -> String {
  match m {
    Some(m) =>
      "mask \{hex64(trace_fnv(Bytes::makei(m.data.length(), i => m.data[i])))}"
    None => "nomask"
  }
}

///|
fn Pixmap::trace_result(self : Pixmap) -> Unit {
  if trace_hook.val is Some(f) {
    f("TSK -> \{hex64(trace_fnv(self.data()))}")
  }
}

///|
fn quality_name(q : FilterQuality) -> String {
  match q {
    Nearest => "Nearest"
    Bilinear => "Bilinear"
    Bicubic => "Bicubic"
  }
}

///|
fn spread_name(s : SpreadMode) -> String {
  match s {
    Pad => "Pad"
    Reflect => "Reflect"
    Repeat => "Repeat"
  }
}

///|
fn blend_name(b : BlendMode) -> String {
  match b {
    Clear => "Clear"
    Source => "Source"
    Destination => "Destination"
    SourceOver => "SourceOver"
    DestinationOver => "DestinationOver"
    SourceIn => "SourceIn"
    DestinationIn => "DestinationIn"
    SourceOut => "SourceOut"
    DestinationOut => "DestinationOut"
    SourceAtop => "SourceAtop"
    DestinationAtop => "DestinationAtop"
    Xor => "Xor"
    Plus => "Plus"
    Modulate => "Modulate"
    Screen => "Screen"
    Overlay => "Overlay"
    Darken => "Darken"
    Lighten => "Lighten"
    ColorDodge => "ColorDodge"
    ColorBurn => "ColorBurn"
    HardLight => "HardLight"
    SoftLight => "SoftLight"
    Difference => "Difference"
    Exclusion => "Exclusion"
    Multiply => "Multiply"
    Hue => "Hue"
    Saturation => "Saturation"
    Color => "Color"
    Luminosity => "Luminosity"
  }
}
